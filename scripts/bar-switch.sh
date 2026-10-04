#!/bin/sh
# Switch between the DMS bar and the repository-owned Quickshell bar (ADR-0027).
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
		printf 'bar-switch: dry run, would set barConfigs[0].enabled to %s in %s\n' "$enabled" "$look_json"
		return 0
	fi
	tmp_look=$(mktemp)
	trap 'rm -f "$tmp_look"' EXIT HUP INT TERM
	jq --indent 2 --argjson enabled "$enabled" '.barConfigs[0].enabled = $enabled' "$look_json" >"$tmp_look"
	cat "$tmp_look" >"$look_json"
	printf 'bar-switch: set barConfigs[0].enabled to %s in %s\n' "$enabled" "$look_json"
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
	"$systemctl_command" --user is-active --quiet "$unit"
}

apply_unit() {
	if ! user_manager_reachable; then
		printf 'bar-switch: the systemd user manager is not reachable; skipping %s\n' "$unit"
		return 0
	fi
	if [ "$1" = own ]; then
		if unit_enabled && unit_active; then
			printf 'bar-switch: %s is already enabled and running\n' "$unit"
		elif [ "$dry_run" -eq 1 ]; then
			printf 'bar-switch: dry run, would enable and start %s\n' "$unit"
		else
			# chezmoi may have installed the unit file moments ago.
			"$systemctl_command" --user daemon-reload
			"$systemctl_command" --user enable --now "$unit"
			printf 'bar-switch: enabled and started %s\n' "$unit"
		fi
	else
		if ! unit_enabled && ! unit_active; then
			printf 'bar-switch: %s is already disabled and stopped\n' "$unit"
		elif [ "$dry_run" -eq 1 ]; then
			printf 'bar-switch: dry run, would disable and stop %s\n' "$unit"
		else
			"$systemctl_command" --user disable --now "$unit"
			printf 'bar-switch: disabled and stopped %s\n' "$unit"
		fi
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
