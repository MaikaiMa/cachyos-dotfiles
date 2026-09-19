#!/bin/sh
# Install the prerequisites for automatic GZ302 rear-window colour syncing.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
dmi_root=${Z13_DMI_ROOT:-/sys/devices/virtual/dmi/id}
rule_source="$repo_root/system/udev/70-z13-window.rules"
rule_target=${Z13_UDEV_RULE_TARGET:-/etc/udev/rules.d/70-z13-window.rules}
z13ctl_command=${Z13CTL_COMMAND:-z13ctl}

is_target() {
	[ -r "$dmi_root/product_family" ] &&
		[ -r "$dmi_root/board_name" ] &&
		[ "$(cat "$dmi_root/product_family")" = "ROG Flow Z13" ] &&
		case $(cat "$dmi_root/board_name") in
		GZ302*) return 0 ;;
		*) return 1 ;;
		esac
}

if [ "${1:-}" = "--check" ]; then
	is_target
	exit
fi

if ! is_target; then
	printf '%s\n' 'Skipping Z13 window setup: this is not a GZ302 Flow Z13.'
	exit 0
fi

if [ "${1:-}" = "--dry-run" ]; then
	if ! command -v "$z13ctl_command" >/dev/null 2>&1; then
		printf '%s\n' '+ paru/yay -S --needed --noconfirm z13ctl-bin'
	fi
	printf '+ install %s as %s\n' "$rule_source" "$rule_target"
	printf '%s\n' '+ reload udev rules and retrigger hidraw devices'
	exit 0
fi

if [ "$#" -ne 0 ]; then
	printf 'Usage: %s [--check|--dry-run]\n' "${0##*/}" >&2
	exit 2
fi

if ! command -v "$z13ctl_command" >/dev/null 2>&1; then
	if [ "$(id -u)" -eq 0 ]; then
		printf '%s\n' 'Install z13ctl-bin as a regular user, not as root.' >&2
		exit 1
	fi
	if command -v paru >/dev/null 2>&1; then
		paru -S --needed --noconfirm z13ctl-bin
	elif command -v yay >/dev/null 2>&1; then
		yay -S --needed --noconfirm z13ctl-bin
	else
		printf '%s\n' 'z13ctl is missing and neither paru nor yay is available.' >&2
		exit 1
	fi
	if ! command -v "$z13ctl_command" >/dev/null 2>&1; then
		printf '%s\n' 'z13ctl-bin installation completed without providing z13ctl.' >&2
		exit 1
	fi
fi

for tool in install udevadm; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Required command is missing: %s\n' "$tool" >&2
		exit 1
	fi
done

if [ "$(id -u)" -eq 0 ]; then
	install -Dm644 "$rule_source" "$rule_target"
	udevadm control --reload-rules
	udevadm trigger --subsystem-match=hidraw --action=change
	udevadm settle
else
	if ! command -v sudo >/dev/null 2>&1; then
		printf '%s\n' 'sudo is required to install the Z13 udev rule.' >&2
		exit 1
	fi
	sudo install -Dm644 "$rule_source" "$rule_target"
	sudo udevadm control --reload-rules
	sudo udevadm trigger --subsystem-match=hidraw --action=change
	sudo udevadm settle
fi

printf '%s\n' 'Z13 rear-window prerequisites are ready.'
