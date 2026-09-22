#!/bin/sh
# Install greetd with the DMS greeter and, with --switch, make it the display manager.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
config_source="$repo_root/system/greetd/config.toml"
pam_source="$repo_root/system/pam.d/greetd"
session_source="$repo_root/system/wayland-sessions/niri.desktop"
session_wrapper_source="$repo_root/system/local/bin/niri-session-quiet"
config_target=${GREETD_CONFIG_TARGET:-/etc/greetd/config.toml}
pam_target=${GREETD_PAM_TARGET:-/etc/pam.d/greetd}
session_target=${GREETD_SESSION_TARGET:-/usr/local/share/wayland-sessions/niri.desktop}
session_wrapper_target=${GREETD_SESSION_WRAPPER_TARGET:-/usr/local/bin/niri-session-quiet}
niri_config=${GREETD_NIRI_CONFIG:-/etc/greetd/niri/config.kdl}
greeter_command=${DMS_GREETER_COMMAND:-dms-greeter}
settings_json=${DMS_SETTINGS_PATH:-$HOME/.config/DankMaterialShell/settings.json}
dry_run=false
switch=false

usage() {
	printf 'Usage: %s [--dry-run] [--switch]\n' "${0##*/}"
}

for arg in "$@"; do
	case "$arg" in
	--dry-run)
		dry_run=true
		;;
	--switch)
		switch=true
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
done

if [ "$(id -u)" -eq 0 ]; then
	printf '%s\n' 'Run setup-greetd.sh as your regular user; dms-greeter sync escalates with sudo itself.' >&2
	exit 1
fi

for tool in cmp install jq niri pacman stat sudo; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Required command is missing: %s\n' "$tool" >&2
		exit 1
	fi
done

service_is_enabled() {
	[ "$(systemctl is-enabled "$1" 2>/dev/null || true)" = enabled ]
}

report_display_manager() {
	if service_is_enabled greetd; then
		printf '%s\n' 'greetd is the display manager; nothing to switch.'
	else
		printf '%s\n' 'SDDM stays the display manager; --switch performs the change.'
	fi
}

config_ownership_is_wrong() {
	[ -f "$config_target" ] || return 1
	[ "$(stat -c '%U:%G %a' "$config_target" 2>/dev/null)" != 'root:root 644' ]
}

greetd_missing=false
if ! pacman -Q greetd >/dev/null 2>&1; then
	greetd_missing=true
fi

greeter_missing=false
if ! command -v "$greeter_command" >/dev/null 2>&1; then
	greeter_missing=true
fi

if [ "$greeter_missing" = true ] && ! command -v paru >/dev/null 2>&1; then
	printf '%s\n' 'dms-greeter is missing and paru is not available.' >&2
	exit 1
fi

if ! jq -e '.greeterPamExternallyManaged == true' "$settings_json" >/dev/null 2>&1; then
	printf 'The DMS setting greeterPamExternallyManaged is not enabled in %s.\n' "$settings_json" >&2
	printf '%s\n' 'Run scripts/dms-apply-look.sh first; it applies dms/look.json, which sets that key. Nothing is changed until then.' >&2
	exit 1
fi

config_differs=true
if cmp -s "$config_source" "$config_target"; then
	config_differs=false
fi

pam_differs=true
if cmp -s "$pam_source" "$pam_target"; then
	pam_differs=false
fi

session_differs=true
if cmp -s "$session_source" "$session_target"; then
	session_differs=false
fi

session_wrapper_differs=true
if cmp -s "$session_wrapper_source" "$session_wrapper_target"; then
	session_wrapper_differs=false
fi

if [ "$dry_run" = true ]; then
	if [ "$greetd_missing" = true ]; then
		printf '%s\n' '+ sudo pacman -S --needed --noconfirm greetd acl'
	fi
	if [ "$greeter_missing" = true ]; then
		printf '%s\n' '+ paru -S --needed --noconfirm greetd-dms-greeter-bin'
	fi
	if [ "$config_differs" = true ]; then
		printf '+ sudo install -Dm644 %s %s\n' "$config_source" "$config_target"
	fi
	if [ "$pam_differs" = true ]; then
		printf '+ sudo install -Dm644 %s %s\n' "$pam_source" "$pam_target"
	fi
	if [ "$session_wrapper_differs" = true ]; then
		printf '+ sudo install -Dm755 %s %s\n' "$session_wrapper_source" "$session_wrapper_target"
	fi
	if [ "$session_differs" = true ]; then
		printf '+ sudo install -Dm644 %s %s\n' "$session_source" "$session_target"
	fi
	printf '+ %s sync --yes\n' "$greeter_command"
	if config_ownership_is_wrong; then
		printf '+ sudo chown root:root %s\n' "$config_target"
		printf '+ sudo chmod 644 %s\n' "$config_target"
	fi
	printf '+ niri validate --config %s\n' "$niri_config"
	printf '+ %s status\n' "$greeter_command"
	if [ "$switch" = true ]; then
		if service_is_enabled sddm; then
			printf '%s\n' '+ sudo systemctl disable sddm'
		fi
		if ! service_is_enabled greetd; then
			printf '%s\n' '+ sudo systemctl enable greetd'
		fi
	else
		report_display_manager
	fi
	exit 0
fi

if [ "$greetd_missing" = true ]; then
	sudo pacman -S --needed --noconfirm greetd acl
fi

if [ "$greeter_missing" = true ]; then
	paru -S --needed --noconfirm greetd-dms-greeter-bin
	if ! command -v "$greeter_command" >/dev/null 2>&1; then
		printf '%s\n' 'greetd-dms-greeter-bin installation completed without providing dms-greeter.' >&2
		exit 1
	fi
fi

if [ "$config_differs" = true ]; then
	sudo install -Dm644 "$config_source" "$config_target"
fi

if [ "$pam_differs" = true ]; then
	sudo install -Dm644 "$pam_source" "$pam_target"
fi

if [ "$session_wrapper_differs" = true ]; then
	sudo install -Dm755 "$session_wrapper_source" "$session_wrapper_target"
fi

if [ "$session_differs" = true ]; then
	sudo install -Dm644 "$session_source" "$session_target"
fi

"$greeter_command" sync --yes

if [ ! -f "$niri_config" ]; then
	printf 'dms-greeter sync did not produce %s\n' "$niri_config" >&2
	exit 1
fi

# dms-greeter 1.6.2 appends -C by moving a temp file owned by the invoking user.
if config_ownership_is_wrong; then
	sudo chown root:root "$config_target"
	sudo chmod 644 "$config_target"
fi

niri validate --config "$niri_config"

"$greeter_command" status

if [ "$switch" = false ]; then
	report_display_manager
	exit 0
fi

if service_is_enabled sddm; then
	sudo systemctl disable sddm
fi

if ! service_is_enabled greetd; then
	enable_status=0
	sudo systemctl enable greetd || enable_status=$?
	if [ "$enable_status" -ne 0 ]; then
		# Leaving both units disabled would strand the machine at a TTY.
		if sudo systemctl enable sddm; then
			printf '%s\n' 'Enabling greetd failed; sddm was re-enabled and stays the display manager.' >&2
		else
			printf '%s\n' 'Enabling greetd failed and re-enabling sddm failed too; enable a display manager from a TTY.' >&2
		fi
		exit 1
	fi
fi

printf '%s\n' 'Reboot to log in through greetd.'
printf '%s\n' 'Rollback from a TTY: sudo systemctl disable greetd; and sudo systemctl enable sddm; and sudo reboot'
