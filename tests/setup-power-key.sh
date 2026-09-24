#!/bin/sh
# Exercise setup-power-key against a throwaway target with fake sudo and systemctl.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script=$repo_root/scripts/setup-power-key.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin=$test_root/bin
target=$test_root/etc/systemd/logind.conf.d/50-power-key.conf
calls=$test_root/calls
mkdir -p "$fake_bin"
: >"$calls"

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

# The test doubles expand their arguments when they run, not here.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'exec "$@"' >"$fake_bin/sudo"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "systemctl $*" >>"$POWER_KEY_CALLS"' >"$fake_bin/systemctl"
chmod +x "$fake_bin/sudo" "$fake_bin/systemctl"

run_setup() {
	PATH=$fake_bin:$PATH \
		LOGIND_POWER_KEY_DROPIN_TARGET=$target \
		POWER_KEY_CALLS=$calls \
		"$script" "$@"
}

dry_run=$(run_setup --dry-run)
case $dry_run in
*"+ install "*"as $target"*'+ reload systemd-logind'*) ;;
*) fail "Dry run did not report the install and reload: $dry_run" ;;
esac
[ ! -e "$target" ] || fail 'The dry run installed the drop-in.'
[ ! -s "$calls" ] || fail 'The dry run touched systemd-logind.'

run_setup >/dev/null
cmp "$repo_root/system/logind.conf.d/50-power-key.conf" "$target" ||
	fail 'The drop-in was not installed verbatim.'
[ "$(cat "$calls")" = 'systemctl reload systemd-logind.service' ] ||
	fail 'Setup must reload, never restart, systemd-logind.'
grep -qx 'HandlePowerKey=suspend' "$target" ||
	fail 'The drop-in must set HandlePowerKey=suspend.'

run_setup >/dev/null
[ "$(wc -l <"$calls")" -eq 1 ] || fail 'An unchanged drop-in must not reload logind.'
[ -z "$(run_setup --dry-run)" ] ||
	fail 'An installed drop-in must leave nothing to preview.'

printf '%s\n' 'setup-power-key tests passed.'
