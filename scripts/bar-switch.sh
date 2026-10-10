#!/bin/sh
# Switch between the DMS bar and the repository-owned Quickshell bar (ADR-0027,
# ADR-0028: the own bar owns the notification daemon).
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
look_json=${LOOK_JSON:-$repo_root/dms/look.json}
systemctl_command=${SYSTEMCTL_COMMAND:-systemctl}
dms_apply_look_command=${DMS_APPLY_LOOK_COMMAND:-$repo_root/scripts/dms-apply-look.sh}
unit=quickshell-bar.service
dms_unit=dms.service
notification_name=org.freedesktop.Notifications
busctl_command=${BUSCTL_COMMAND:-busctl}
dry_run=0
action=

usage() {
	printf 'Usage: %s [--dry-run] [own | dms | status | --apply]\n' "${0##*/}"
}

set_action() {
	if [ -n "$action" ]; then
		usage >&2
		exit 2
	fi
	action=$1
}

for arg in "$@"; do
	case $arg in
	--dry-run) dry_run=1 ;;
	-h | --help)
		usage
		exit 0
		;;
	own | dms | status) set_action "$arg" ;;
	--apply) set_action apply ;;
	*)
		usage >&2
		exit 2
		;;
	esac
done
action=${action:-apply}

command -v jq >/dev/null 2>&1 || {
	printf 'bar-switch: jq is required but not installed\n' >&2
	exit 1
}
[ -f "$look_json" ] || {
	printf 'bar-switch: %s not found\n' "$look_json" >&2
	exit 1
}

# DMS treats a missing enabled flag as true, so only an explicit false hands the bar over.
recorded_bar() {
	jq -r 'if .barConfigs[0].enabled == false then "own" else "dms" end' "$look_json"
}

record_bar() {
	if [ "$(recorded_bar)" = "$1" ]; then
		printf 'bar-switch: %s already records the %s bar\n' "$look_json" "$1"
		return 0
	fi
	if [ "$1" = own ]; then
		enabled=false
	else
		enabled=true
	fi
	if [ "$dry_run" -eq 1 ]; then
		printf 'bar-switch: dry run, would set barConfigs[0].enabled and the DMS volume, microphone and brightness OSDs to %s in %s\n' "$enabled" "$look_json"
		return 0
	fi
	tmp_look=$(mktemp)
	trap 'rm -f "$tmp_look"' EXIT HUP INT TERM
	# The own bar draws its own OSD for these keys; DMS would show a second one.
	jq --indent 2 --argjson enabled "$enabled" \
		'.barConfigs[0].enabled = $enabled | .osdVolumeEnabled = $enabled | .osdMicMuteEnabled = $enabled | .osdBrightnessEnabled = $enabled' \
		"$look_json" >"$tmp_look"
	cat "$tmp_look" >"$look_json"
	printf 'bar-switch: set barConfigs[0].enabled and the DMS volume, microphone and brightness OSDs to %s in %s\n' "$enabled" "$look_json"
}

apply_look() {
	if [ "$dry_run" -eq 1 ]; then
		"$dms_apply_look_command" --dry-run
	else
		"$dms_apply_look_command"
	fi
}

user_manager_reachable() {
	"$systemctl_command" --user show-environment >/dev/null 2>&1
}

unit_enabled() {
	case $("$systemctl_command" --user is-enabled "$unit" 2>/dev/null || true) in
	enabled*) return 0 ;;
	*) return 1 ;;
	esac
}

unit_active() {
	"$systemctl_command" --user is-active --quiet "${1:-$unit}"
}

# Who holds org.freedesktop.Notifications: quickshell, dms, nobody, unknown
# (no busctl or no session bus), or the process name of any other owner. DMS is
# Quickshell too and its process is called qs, so qs counts as dms when its
# command line is the DMS runtime (qs -p /run/user/<uid>/danklinux-shell/...).
name_owner() {
	if ! command -v "$busctl_command" >/dev/null 2>&1; then
		echo unknown
		return 0
	fi
	if ! owner_status=$("$busctl_command" --user status "$notification_name" 2>/dev/null); then
		if "$busctl_command" --user list --no-legend >/dev/null 2>&1; then
			echo nobody
		else
			echo unknown
		fi
		return 0
	fi
	owner_comm=$(printf '%s\n' "$owner_status" | sed -n 's/^Comm=//p' | sed -n 1p)
	owner_cmdline=$(printf '%s\n' "$owner_status" | sed -n 's/^CommandLine=//p' | sed -n 1p)
	case $owner_comm in
	qs)
		case $owner_cmdline in
		*danklinux-shell* | *dms*) owner_comm=dms ;;
		esac
		;;
	esac
	echo "${owner_comm:-unknown}"
}

run_systemctl() {
	"$systemctl_command" --user "$@"
}

# The bar must hold the notification name before DMS starts (ADR-0028), and a
# bar that started after DMS holds no name, so a start is not enough: stop DMS,
# restart the bar (its readiness wait returns once it owns the name), start DMS.
# The drop-in's PartOf= makes the bar's restart restart DMS as well; the final
# start is then a no-op, and it still covers a drop-in that is not installed yet.
# When the bar already owns the name and DMS runs there is nothing to do.
apply_own() {
	if unit_enabled && unit_active && unit_active "$dms_unit" && [ "$(name_owner)" = quickshell ]; then
		printf 'bar-switch: %s is already enabled and running and owns the notification name\n' "$unit"
		return 0
	fi
	if [ "$dry_run" -eq 1 ]; then
		printf 'bar-switch: dry run, would enable %s, stop %s, restart %s, then start %s\n' "$unit" "$dms_unit" "$unit" "$dms_unit"
		return 0
	fi
	# chezmoi may have installed the unit files moments ago.
	run_systemctl daemon-reload
	run_systemctl enable "$unit"
	run_systemctl stop "$dms_unit"
	run_systemctl restart "$unit"
	run_systemctl start "$dms_unit"
	printf 'bar-switch: enabled %s and started it before %s; the bar now owns the notification name\n' "$unit" "$dms_unit"
}

# Going back needs DMS to take the name from the stopped bar. Stopping the bar
# already stops DMS (PartOf=), so the restart is what brings DMS back and lets
# it register the name. When the bar is off and DMS owns the name there is
# nothing to do.
apply_dms() {
	if ! unit_enabled && ! unit_active && unit_active "$dms_unit" && [ "$(name_owner)" = dms ]; then
		printf 'bar-switch: %s is already disabled and stopped and DMS owns the notification name\n' "$unit"
		return 0
	fi
	if [ "$dry_run" -eq 1 ]; then
		printf 'bar-switch: dry run, would disable and stop %s, then restart %s\n' "$unit" "$dms_unit"
		return 0
	fi
	run_systemctl disable --now "$unit"
	run_systemctl restart "$dms_unit"
	printf 'bar-switch: disabled and stopped %s and restarted %s; DMS now owns the notification name\n' "$unit" "$dms_unit"
}

apply_unit() {
	if ! user_manager_reachable; then
		printf 'bar-switch: the systemd user manager is not reachable; skipping %s\n' "$unit"
		return 0
	fi
	if [ "$1" = own ]; then
		apply_own
	else
		apply_dms
	fi
}

print_status() {
	printf 'bar-switch: %s records the %s bar\n' "$look_json" "$(recorded_bar)"
	if ! user_manager_reachable; then
		printf 'bar-switch: the systemd user manager is not reachable\n'
		return 0
	fi
	enabled_state=$("$systemctl_command" --user is-enabled "$unit" 2>/dev/null || true)
	active_state=$("$systemctl_command" --user is-active "$unit" 2>/dev/null || true)
	printf 'bar-switch: %s is %s and %s\n' "$unit" "${enabled_state:-unknown}" "${active_state:-unknown}"
	printf 'bar-switch: %s is held by %s\n' "$notification_name" "$(name_owner)"
}

case $action in
own | dms)
	record_bar "$action"
	apply_look
	apply_unit "$action"
	;;
apply) apply_unit "$(recorded_bar)" ;;
status) print_status ;;
esac
