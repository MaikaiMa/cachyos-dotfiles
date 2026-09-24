#!/bin/sh
# Exercise setup-sessions against throwaway pacman.conf and session directories.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script=$repo_root/scripts/setup-sessions.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin=$test_root/bin
mkdir -p "$fake_bin"

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

# The test double expands its arguments when it runs, not here.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'exec "$@"' >"$fake_bin/sudo"
printf '%s\n' '#!/bin/sh' >"$fake_bin/start-gamescope-session"
chmod +x "$fake_bin/sudo" "$fake_bin/start-gamescope-session"

ours='usr/share/wayland-sessions/niri.desktop
usr/share/wayland-sessions/gamescope-session.desktop
usr/share/wayland-sessions/gnome.desktop'

# Each case gets a fresh machine: a pacman.conf, the three packaged entries.
new_machine() {
	machine=$test_root/$1
	mkdir -p "$machine/usr/share/wayland-sessions"
	for name in niri.desktop gamescope-session.desktop gnome.desktop; do
		printf '%s\n' '[Desktop Entry]' "Name=packaged $name" >"$machine/usr/share/wayland-sessions/$name"
	done
	cat >"$machine/pacman.conf"
}

run_setup() {
	PATH=$fake_bin:$PATH \
		SESSIONS_PACMAN_CONF=$machine/pacman.conf \
		SESSIONS_PACKAGE_DIR=$machine/usr/share/wayland-sessions \
		SESSIONS_LOCAL_DIR=$machine/usr/local/share/wayland-sessions \
		SESSIONS_STEAM_WRAPPER_TARGET=$machine/usr/local/bin/steam-session \
		SESSIONS_GAMESCOPE_COMMAND=${gamescope_command:-$fake_bin/start-gamescope-session} \
		"$script" "$@"
}

noextract() {
	pacman-conf --config "$machine/pacman.conf" NoExtract
}

backups() {
	find "$machine" -maxdepth 1 -name 'pacman.conf.backup-*' | wc -l
}

new_machine fresh <<'EOF'
[options]
HoldPkg     = pacman glibc
#NoUpgrade   =
#NoExtract   =
Architecture = auto

[core]
Include = /dev/null
EOF
cp "$machine/pacman.conf" "$test_root/fresh.orig"

dry_run=$(run_setup --dry-run)
case $dry_run in
*'add under [options]: NoExtract'*'install -Dm644 '*niri.desktop*'install -Dm644 '*steam.desktop*'install -Dm755 '*steam-session*'rm '*gnome.desktop*) ;;
*) fail "Dry run did not report every change: $dry_run" ;;
esac
cmp -s "$test_root/fresh.orig" "$machine/pacman.conf" || fail 'The dry run edited pacman.conf.'
[ ! -e "$machine/usr/local" ] || fail 'The dry run installed session entries.'
[ -e "$machine/usr/share/wayland-sessions/gnome.desktop" ] || fail 'The dry run removed a packaged entry.'

run_setup >/dev/null
[ "$(noextract)" = "$ours" ] || fail "NoExtract does not cover the packaged entries: $(noextract)"
[ "$(backups)" -eq 1 ] || fail 'Editing pacman.conf must keep one backup.'
[ "$(diff "$test_root/fresh.orig" "$machine/pacman.conf" | grep -c '^[<>]')" -eq 2 ] ||
	fail 'Only the comment and the NoExtract line may be added to pacman.conf.'
sed -n 6p "$machine/pacman.conf" | grep -q '^NoExtract = ' ||
	fail 'The NoExtract line must follow the commented NoExtract template.'
for name in niri.desktop steam.desktop; do
	cmp -s "$repo_root/system/wayland-sessions/$name" "$machine/usr/local/share/wayland-sessions/$name" ||
		fail "$name was not installed verbatim."
done
[ -x "$machine/usr/local/bin/steam-session" ] || fail 'The steam-session wrapper is not executable.'
[ -z "$(ls -A "$machine/usr/share/wayland-sessions")" ] || fail 'A packaged session entry was left behind.'

cp "$machine/pacman.conf" "$test_root/fresh.done"
[ "$(run_setup)" = 'The greeter session list is already up to date.' ] ||
	fail 'An up-to-date machine must report nothing to do.'
cmp -s "$test_root/fresh.done" "$machine/pacman.conf" || fail 'A second run edited pacman.conf again.'
[ "$(backups)" -eq 1 ] || fail 'A second run made another backup.'
[ -z "$(run_setup --dry-run)" ] || fail 'An up-to-date machine must leave nothing to preview.'

printf '%s\n' '[Desktop Entry]' >"$machine/usr/share/wayland-sessions/niri.desktop"
case $(run_setup --dry-run) in
"+ sudo rm $machine/usr/share/wayland-sessions/niri.desktop") ;;
*) fail 'A reinstalled packaged entry must only be removed again.' ;;
esac

new_machine existing <<'EOF'
[options]
NoExtract = usr/share/doc/* usr/share/wayland-sessions/gnome.desktop
Architecture = auto
EOF
run_setup >/dev/null
grep -qx 'NoExtract = usr/share/doc/\* usr/share/wayland-sessions/gnome.desktop' "$machine/pacman.conf" ||
	fail 'An existing NoExtract line must be kept as it is.'
grep -qx 'NoExtract = usr/share/wayland-sessions/niri.desktop usr/share/wayland-sessions/gamescope-session.desktop' "$machine/pacman.conf" ||
	fail 'Only the entries not yet covered may be added.'
[ "$(sed -n 4p "$machine/pacman.conf")" = 'NoExtract = usr/share/wayland-sessions/niri.desktop usr/share/wayland-sessions/gamescope-session.desktop' ] ||
	fail 'The addition must follow the existing NoExtract line.'

new_machine nosteam <<'EOF'
[options]
Architecture = auto
EOF
output=$(gamescope_command=$test_root/missing run_setup)
case $output in
*'skipping the Steam session'*) ;;
*) fail "Setup did not say it skipped the Steam session: $output" ;;
esac
[ -f "$machine/usr/local/share/wayland-sessions/niri.desktop" ] || fail 'The Niri entry must not depend on gamescope.'
[ ! -e "$machine/usr/local/share/wayland-sessions/steam.desktop" ] || fail 'The Steam entry was installed without gamescope.'
[ ! -e "$machine/usr/local/bin/steam-session" ] || fail 'The wrapper was installed without gamescope.'

new_machine nooptions <<'EOF'
[core]
Include = /dev/null
EOF
cp "$machine/pacman.conf" "$test_root/nooptions.orig"
if run_setup >/dev/null 2>&1; then
	fail 'A pacman.conf without [options] must fail.'
fi
cmp -s "$test_root/nooptions.orig" "$machine/pacman.conf" || fail 'A failed run edited pacman.conf.'
[ "$(backups)" -eq 0 ] || fail 'A failed run left a backup.'
[ -e "$machine/usr/share/wayland-sessions/niri.desktop" ] ||
	fail 'Packaged entries must stay until NoExtract is in effect.'

printf '%s\n' 'setup-sessions tests passed.'
