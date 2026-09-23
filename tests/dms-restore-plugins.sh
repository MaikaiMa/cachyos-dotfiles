#!/bin/sh
# Exercise dms-restore-plugins against an isolated config with a stub dms.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/scripts/dms-restore-plugins.sh"
repo_lock="$repo_root/dms/plugins.lock.json"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

config_home="$test_root/config"
dms_dir="$config_home/DankMaterialShell"
live_lock="$dms_dir/plugins.lock.json"
fake_bin="$test_root/bin"
calls="$test_root/calls"
mkdir -p "$fake_bin" "$dms_dir/plugins"
: >"$calls"

# The stub records its arguments and installs the lockfile the way DMS would.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' \
	'printf "%s\n" "$*" >>"$DMS_STUB_CALLS"' \
	'[ "$1 $2" = "plugins restore" ] || exit 0' \
	'dir="$XDG_CONFIG_HOME/DankMaterialShell"' \
	'cp "$3" "$dir/plugins.lock.json"' \
	'for id in $(jq -r ".plugins | keys[]" "$3"); do' \
	'	mkdir -p "$dir/plugins/$id"' \
	'	printf "{\"id\": \"%s\"}\n" "$id" >"$dir/plugins/$id/plugin.json"' \
	'done' >"$fake_bin/dms"
chmod +x "$fake_bin/dms"

# The systemctl stub reports dms.service active/inactive via SYSTEMCTL_ACTIVE.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' \
	'[ "$1 $2 $3 $4" = "--user is-active --quiet dms.service" ] || exit 0' \
	'[ "${SYSTEMCTL_ACTIVE:-0}" -eq 1 ]' >"$fake_bin/systemctl"
chmod +x "$fake_bin/systemctl"

run_restore() {
	PATH="$fake_bin:$PATH" \
		HOME="$test_root" \
		XDG_CONFIG_HOME="$config_home" \
		DMS_STUB_CALLS="$calls" \
		SYSTEMCTL_ACTIVE="${SYSTEMCTL_ACTIVE:-0}" \
		"$script" "$@"
}

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

plugin_count=$(jq '.plugins | length' "$repo_lock")

dry_run=$(run_restore --dry-run)
case $dry_run in
*'dry run, restoring would change:'*'install dankLauncherKeys at '*) ;;
*) fail "Dry-run did not list the plugins to install: $dry_run" ;;
esac
if [ "$(printf '%s\n' "$dry_run" | grep -c '^  install ')" -ne "$plugin_count" ]; then
	fail 'Dry-run must list every locked plugin as an install on an empty config.'
fi
[ -s "$calls" ] && fail 'Dry-run must not call dms.'
[ -e "$live_lock" ] && fail 'Dry-run wrote the live lockfile.'

run_restore >/dev/null
if [ "$(cat "$calls")" != "plugins restore $repo_lock" ]; then
	fail "Restore must call dms plugins restore with the repo lockfile and no --prune, got: $(cat "$calls")"
fi

second_run=$(run_restore)
case $second_run in
*'plugins already match'*) ;;
*) fail "A second restore is not idempotent: $second_run" ;;
esac
[ "$(wc -l <"$calls")" -eq 1 ] || fail 'An up-to-date config must not call dms again.'

jq '.plugins.webSearch.commit = "0000000000000000000000000000000000000000"' "$repo_lock" >"$live_lock"
case $(run_restore --dry-run) in
*'update webSearch 0000000 -> '*) ;;
*) fail 'Dry-run did not report a changed commit.' ;;
esac

case $(SYSTEMCTL_ACTIVE=1 run_restore --dry-run) in
*'restart DMS'*) fail 'Dry-run printed the DMS restart notice.' ;;
*) ;;
esac

jq '.plugins.webSearch.commit = "0000000000000000000000000000000000000000"' "$repo_lock" >"$live_lock"
restore_out=$(SYSTEMCTL_ACTIVE=1 run_restore)
case $restore_out in
*'restart DMS to load the new plugins: dms-reset'*) ;;
*) fail "Restore did not print a DMS restart notice when something changed and dms.service is active: $restore_out" ;;
esac

jq '.plugins.webSearch.commit = "0000000000000000000000000000000000000000"' "$repo_lock" >"$live_lock"
restore_out=$(SYSTEMCTL_ACTIVE=0 run_restore)
case $restore_out in
*'restart DMS'*) fail "Restore printed the DMS restart notice while dms.service is inactive: $restore_out" ;;
*) ;;
esac

restore_out=$(SYSTEMCTL_ACTIVE=1 run_restore)
case $restore_out in
*'plugins already match'*) ;;
*) fail "A third restore is not idempotent: $restore_out" ;;
esac
case $restore_out in
*'restart DMS'*) fail "Restore printed the DMS restart notice when nothing changed: $restore_out" ;;
*) ;;
esac

rm -f "$live_lock"
case $(run_restore --dry-run) in
*'conflict webSearch: installed outside the DMS lockfile'*) ;;
*) fail 'Dry-run did not report a plugin installed outside the lockfile.' ;;
esac

expect_invalid() {
	jq "$1" "$repo_lock" >"$test_root/invalid.json"
	if DMS_PLUGIN_LOCKFILE="$test_root/invalid.json" run_restore --dry-run >/dev/null 2>&1; then
		fail "An invalid lockfile was accepted: $1"
	fi
}
expect_invalid '.lockfileVersion = 2'
expect_invalid '.plugins.webSearch.commit = "main"'
expect_invalid '.plugins.webSearch.repo = ""'
expect_invalid '.plugins.converter.path = "../escape"'
expect_invalid '.plugins.dankGifSearch.commit = "1111111111111111111111111111111111111111"'

if PATH="$fake_bin:$PATH" DMS_COMMAND=missing-dms "$script" --dry-run >/dev/null 2>&1; then
	fail 'A missing dms command must fail.'
fi

printf '%s\n' 'DMS plugin restore tests passed.'
