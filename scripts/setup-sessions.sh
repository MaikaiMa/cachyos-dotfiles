#!/bin/sh
# Make the greeter list exactly "Niri" and then "Steam" (ADR-0023): pacman
# stops extracting the packaged session entries, and repository-owned entries
# in /usr/local/share/wayland-sessions take their place.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
sessions_source=$repo_root/system/wayland-sessions
steam_wrapper_source=$repo_root/system/local/bin/steam-session
pacman_conf=${SESSIONS_PACMAN_CONF:-/etc/pacman.conf}
package_sessions_dir=${SESSIONS_PACKAGE_DIR:-/usr/share/wayland-sessions}
local_sessions_dir=${SESSIONS_LOCAL_DIR:-/usr/local/share/wayland-sessions}
steam_wrapper_target=${SESSIONS_STEAM_WRAPPER_TARGET:-/usr/local/bin/steam-session}
gamescope_command=${SESSIONS_GAMESCOPE_COMMAND:-/usr/bin/start-gamescope-session}
package_sessions='niri.desktop gamescope-session.desktop gnome.desktop'

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

for tool in awk cmp pacman-conf; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Required command is missing: %s\n' "$tool" >&2
		exit 1
	fi
done

if [ ! -f "$pacman_conf" ]; then
	printf 'pacman configuration not found: %s\n' "$pacman_conf" >&2
	exit 1
fi

# NoExtract paths are relative to pacman's root, independent of the test
# overrides above.
missing_noextract() {
	current=$(pacman-conf --config "$pacman_conf" NoExtract) || {
		printf 'pacman-conf could not read %s\n' "$pacman_conf" >&2
		exit 1
	}
	missing=
	for name in $package_sessions; do
		if ! printf '%s\n' "$current" | grep -Fqx "usr/share/wayland-sessions/$name"; then
			missing="$missing usr/share/wayland-sessions/$name"
		fi
	done
	printf '%s\n' "${missing# }"
}

steam_available=false
if [ -x "$gamescope_command" ]; then
	steam_available=true
fi

session_names=niri.desktop
if [ "$steam_available" = true ]; then
	session_names="$session_names steam.desktop"
fi

sessions_to_install=
for name in $session_names; do
	if ! cmp -s "$sessions_source/$name" "$local_sessions_dir/$name"; then
		sessions_to_install="$sessions_to_install $name"
	fi
done

wrapper_differs=false
if [ "$steam_available" = true ] && ! cmp -s "$steam_wrapper_source" "$steam_wrapper_target"; then
	wrapper_differs=true
fi

package_copies=
for name in $package_sessions; do
	if [ -e "$package_sessions_dir/$name" ]; then
		package_copies="$package_copies $name"
	fi
done

noextract_missing=$(missing_noextract)

if [ "$steam_available" = false ]; then
	printf '%s not found; skipping the Steam session until gamescope-session-cachyos is installed.\n' "$gamescope_command"
fi

if [ -z "$noextract_missing" ] && [ -z "$sessions_to_install" ] &&
	[ "$wrapper_differs" = false ] && [ -z "$package_copies" ]; then
	if [ "$dry_run" = false ]; then
		printf '%s\n' 'The greeter session list is already up to date.'
	fi
	exit 0
fi

if [ "$dry_run" = true ]; then
	if [ -n "$noextract_missing" ]; then
		printf '+ back up %s and add under [options]: NoExtract = %s\n' "$pacman_conf" "$noextract_missing"
	fi
	for name in $sessions_to_install; do
		printf '+ sudo install -Dm644 %s %s\n' "$sessions_source/$name" "$local_sessions_dir/$name"
	done
	if [ "$wrapper_differs" = true ]; then
		printf '+ sudo install -Dm755 %s %s\n' "$steam_wrapper_source" "$steam_wrapper_target"
	fi
	for name in $package_copies; do
		printf '+ sudo rm %s\n' "$package_sessions_dir/$name"
	done
	exit 0
fi

for tool in date install mktemp rm; do
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
		printf '%s\n' 'sudo is required to change the greeter session list.' >&2
		exit 1
	fi
}

add_noextract() {
	edited=$(mktemp)
	# Inserted after the last NoExtract line of [options], commented or not,
	# so the addition sits where pacman.conf documents the option.
	awk -v entry="NoExtract = $noextract_missing" '
		NR == FNR {
			header = $0
			sub(/[ \t]+$/, "", header)
			if (header ~ /^\[/) in_options = (header == "[options]")
			if (in_options && (header == "[options]" || $0 ~ /^#?[ \t]*NoExtract[ \t]*=/)) anchor = FNR
			next
		}
		{ print }
		FNR == anchor {
			print "# dotfiles: keep the greeter session list repository-owned (ADR-0023)."
			print entry
		}
		END { if (!anchor) exit 1 }
	' "$pacman_conf" "$pacman_conf" >"$edited" || {
		rm -f "$edited"
		printf '%s has no [options] section; nothing was changed.\n' "$pacman_conf" >&2
		exit 1
	}
	run_as_root cp -p "$pacman_conf" "$pacman_conf.backup-$(date +%Y%m%d-%H%M%S)"
	run_as_root install -m644 "$edited" "$pacman_conf"
	rm -f "$edited"
}

if [ -n "$noextract_missing" ]; then
	add_noextract
	if [ -n "$(missing_noextract)" ]; then
		printf 'NoExtract is still not in effect in %s; the packaged session entries were left in place.\n' "$pacman_conf" >&2
		exit 1
	fi
fi

for name in $sessions_to_install; do
	run_as_root install -Dm644 "$sessions_source/$name" "$local_sessions_dir/$name"
done

if [ "$wrapper_differs" = true ]; then
	run_as_root install -Dm755 "$steam_wrapper_source" "$steam_wrapper_target"
fi

for name in $package_copies; do
	run_as_root rm -f "$package_sessions_dir/$name"
done

printf '%s\n' 'The greeter now lists the repository-owned session entries; it picks them up on its next start.'
