#!/bin/sh
# Temporary helper for phase 1 of docs/desktop-migration.md ("DMS trial next
# to Noctalia"). Installs DankMaterialShell, switches the noctalia.service
# and dms.service user units, and installs a keybind shim at
# ~/.local/bin/noctalia that forwards the existing Noctalia keybinds to DMS
# IPC calls so the Niri config does not need to change for the trial. This
# script and tests/dms-trial.sh are removed in phase 2.
set -eu

shim_path="$HOME/.local/bin/noctalia"
shim_marker='# dms-trial shim: translates Noctalia keybind commands to DMS IPC; managed by scripts/dms-trial.sh'

usage() {
	printf 'Usage: %s {install|start|stop|status}\n' "${0##*/}"
}

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		printf 'Required command not found: %s\n' "$1" >&2
		exit 1
	fi
}

service_is_active() {
	systemctl --user is-active "$1" >/dev/null 2>&1
}

print_service_status() {
	status=$(systemctl --user is-active "$1" 2>/dev/null) || :
	printf '%s: %s\n' "$1" "$status"
}

print_statuses() {
	print_service_status noctalia.service
	print_service_status dms.service
}

install_shim() {
	shim_dir=$(dirname -- "$shim_path")
	mkdir -p -- "$shim_dir"

	if [ -e "$shim_path" ] && ! grep -Fqx "$shim_marker" "$shim_path" 2>/dev/null; then
		printf 'Refusing to overwrite unmanaged file: %s\n' "$shim_path" >&2
		printf 'Remove it yourself if it should not be there.\n' >&2
		exit 1
	fi

	tmp_shim=$(mktemp "$shim_dir/.noctalia.XXXXXX")
	cat >"$tmp_shim" <<'SHIM_EOF'
#!/bin/sh
# dms-trial shim: translates Noctalia keybind commands to DMS IPC; managed by scripts/dms-trial.sh
set -eu

resolve_path() {
	dir=$(CDPATH= cd -- "$(dirname -- "$1")" 2>/dev/null && pwd) || return 1
	printf '%s/%s\n' "$dir" "$(basename -- "$1")"
}

if [ "${1-}" != "msg" ]; then
	self=$(resolve_path "$0") || self=$0
	old_ifs=$IFS
	IFS=:
	for dir in $PATH; do
		IFS=$old_ifs
		[ -n "$dir" ] || continue
		candidate=$dir/noctalia
		if [ -x "$candidate" ]; then
			resolved=$(resolve_path "$candidate") || resolved=$candidate
			if [ "$resolved" != "$self" ]; then
				exec "$candidate" "$@"
			fi
		fi
	done
	IFS=$old_ifs
	exec /usr/bin/noctalia "$@"
fi
shift

case "$*" in
'panel-toggle wallpaper')
	exec dms ipc call settings toggleWith wallpaper
	;;
'panel-toggle maikel/quick-controls:panel')
	exec dms ipc call control-center toggle
	;;
'settings-toggle')
	exec dms ipc call settings toggle
	;;
'panel-toggle launcher')
	exec dms ipc call spotlight toggle
	;;
'panel-toggle clipboard')
	exec dms ipc call clipboard toggle
	;;
'session lock')
	exec dms ipc call lock lock
	;;
'panel-toggle session')
	exec dms ipc call powermenu toggle
	;;
'volume-up')
	exec dms ipc call audio increment 5
	;;
'volume-down')
	exec dms ipc call audio decrement 5
	;;
'volume-mute')
	exec dms ipc call audio mute
	;;
'mic-mute')
	exec dms ipc call audio micmute
	;;
'media next')
	exec dms ipc call mpris next
	;;
'media previous')
	exec dms ipc call mpris previous
	;;
'media play')
	exec dms ipc call mpris playPause
	;;
'media stop')
	exec dms ipc call mpris pause
	;;
'brightness-up')
	exec dms ipc call brightness increment 5
	;;
'brightness-down')
	exec dms ipc call brightness decrement 5
	;;
*)
	printf 'noctalia msg %s is not mapped for the DMS trial\n' "$*" >&2
	exit 1
	;;
esac
SHIM_EOF

	chmod 0755 "$tmp_shim"
	mv -- "$tmp_shim" "$shim_path"
}

remove_shim() {
	if [ -f "$shim_path" ] && grep -Fqx "$shim_marker" "$shim_path" 2>/dev/null; then
		rm -f -- "$shim_path"
	fi
}

cmd_install() {
	if command -v dms >/dev/null 2>&1; then
		printf 'DMS is already installed.\n'
		return 0
	fi

	require_command sudo
	require_command pacman

	printf '%s\n' 'sudo pacman -S --needed dms-shell-niri'
	sudo pacman -S --needed dms-shell-niri
}

cmd_start() {
	require_command dms
	require_command systemctl

	if service_is_active noctalia.service; then
		systemctl --user stop noctalia.service
	fi

	install_shim

	systemctl --user start dms.service

	print_statuses
	printf 'Switch back with: %s stop\n' "${0##*/}"
}

cmd_stop() {
	require_command systemctl

	if service_is_active dms.service; then
		systemctl --user stop dms.service
	fi

	remove_shim

	systemctl --user start noctalia.service

	print_statuses
}

cmd_status() {
	require_command systemctl

	print_statuses
	if [ -f "$shim_path" ] && grep -Fqx "$shim_marker" "$shim_path" 2>/dev/null; then
		printf 'shim: installed (%s)\n' "$shim_path"
	else
		printf 'shim: not installed\n'
	fi
}

if [ $# -ne 1 ]; then
	usage >&2
	exit 2
fi

case "$1" in
install) cmd_install ;;
start) cmd_start ;;
stop) cmd_stop ;;
status) cmd_status ;;
*)
	usage >&2
	exit 2
	;;
esac
