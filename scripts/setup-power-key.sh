#!/bin/sh
# Let logind suspend on a short power-key press, because niri's own handling
# is disabled for niri-wm/niri#2233.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
dropin_source="$repo_root/system/logind.conf.d/50-power-key.conf"
dropin_target=${LOGIND_POWER_KEY_DROPIN_TARGET:-/etc/systemd/logind.conf.d/50-power-key.conf}

usage() {
	printf 'Usage: %s [--dry-run]\n' "${0##*/}"
}

dry_run=false
case ${1:-} in
'') ;;
--dry-run) dry_run=true ;;
-h | --help)
	usage
	exit 0
	;;
*)
	usage >&2
	exit 2
	;;
esac

if ! command -v cmp >/dev/null 2>&1; then
	printf '%s\n' 'Required command is missing: cmp' >&2
	exit 1
fi

if cmp -s "$dropin_source" "$dropin_target"; then
	if [ "$dry_run" = false ]; then
		printf '%s\n' 'logind already suspends on a short power-key press.'
	fi
	exit 0
fi

if [ "$dry_run" = true ]; then
	printf '+ install %s as %s\n' "$dropin_source" "$dropin_target"
	printf '%s\n' '+ reload systemd-logind (a reload, not a restart)'
	exit 0
fi

for tool in install systemctl; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Required command is missing: %s\n' "$tool" >&2
		exit 1
	fi
done

run_as_root() {
	if [ "$(id -u)" -eq 0 ]; then
		"$@"
	elif command -v sudo >/dev/null 2>&1; then
		sudo "$@"
	else
		printf '%s\n' 'sudo is required to install the logind drop-in.' >&2
		exit 1
	fi
}

run_as_root install -Dm644 "$dropin_source" "$dropin_target"
# A reload re-reads logind.conf.d without ending sessions; a restart of
# systemd-logind can take the running graphical session down with it.
if ! run_as_root systemctl reload systemd-logind.service; then
	printf '%s\n' 'Reloading systemd-logind failed; reboot to apply the drop-in.' >&2
	exit 0
fi

printf '%s\n' 'logind now suspends on a short power-key press.'
