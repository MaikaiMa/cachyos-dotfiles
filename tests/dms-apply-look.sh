#!/bin/sh
# Exercise dms-apply-look against an isolated home with a stub systemctl.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/scripts/dms-apply-look.sh"
repo_plugins="$repo_root/dms/plugin_settings.json"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin="$test_root/bin"
calls="$test_root/calls"
mkdir -p "$fake_bin"

# The stub reports dms.service inactive, so the script never asks a real dms over IPC.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' \
	'[ "$1 $2" = "--user is-active" ] && exit 1' \
	'printf "%s\n" "$*" >>"$SYSTEMCTL_STUB_CALLS"' >"$fake_bin/systemctl"
chmod +x "$fake_bin/systemctl"

run_apply() {
	apply_home=$1
	shift
	PATH="$fake_bin:$PATH" \
		HOME="$apply_home" \
		XDG_STATE_HOME="$apply_home/.local/state" \
		SYSTEMCTL_STUB_CALLS="$calls" \
		"$script" "$@"
}

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

plugin_value() {
	jq -c "$2" "$1/.config/DankMaterialShell/plugin_settings.json"
}

home="$test_root/home"
live_plugins="$home/.config/DankMaterialShell/plugin_settings.json"
mkdir -p "$(dirname "$live_plugins")"
cat >"$live_plugins" <<'EOF'
{
  "commandRunner": {
    "enabled": false,
    "terminal": "kitty",
    "history": ["private-history-command"]
  },
  "webSearch": {
    "enabled": true,
    "searchEngines": [{"id": "private-engine"}],
    "disabledEngines": ["duckduckgo"]
  },
  "handInstalled": {
    "enabled": true
  }
}
EOF
cp "$live_plugins" "$test_root/before.json"
: >"$calls"

dry_run=$(run_apply "$home" --dry-run)
case $dry_run in
*'dms-apply-look: dry run, applying would restart dms.service'*'"pluginSettings"'*) ;;
*) fail "dry-run did not preview the plugin settings: $dry_run" ;;
esac
case $dry_run in
*private-history-command* | *private-engine*) fail 'dry-run printed plugin state that the repository does not pin.' ;;
esac
cmp -s "$live_plugins" "$test_root/before.json" || fail 'dry-run changed plugin_settings.json.'
[ ! -e "$home/.config/DankMaterialShell/settings.json" ] || fail 'dry-run wrote settings.json.'
[ ! -s "$calls" ] || fail 'dry-run stopped or started dms.service.'

run_apply "$home" >/dev/null
[ "$(plugin_value "$home" '.commandRunner.enabled')" = true ] || fail 'repository enabled flag did not win.'
[ "$(plugin_value "$home" '.commandRunner.terminal')" = '"ghostty"' ] || fail 'repository terminal did not win.'
[ "$(plugin_value "$home" '.commandRunner.history')" = '["private-history-command"]' ] ||
	fail 'commandRunner history was not preserved.'
[ "$(plugin_value "$home" '.webSearch.searchEngines')" = '[{"id":"private-engine"}]' ] ||
	fail 'webSearch searchEngines were not preserved.'
[ "$(plugin_value "$home" '.webSearch.disabledEngines')" = '["duckduckgo"]' ] ||
	fail 'webSearch disabledEngines were not preserved.'
[ "$(plugin_value "$home" '.handInstalled')" = '{"enabled":true}' ] ||
	fail 'a plugin missing from the repository was not preserved.'
[ "$(stat -c %a "$home/.config/DankMaterialShell/settings.json")" = 640 ] ||
	fail 'apply did not leave settings.json at mode 640 for the greeter.'
[ "$(stat -c %a "$home/.local/state/DankMaterialShell/session.json")" = 640 ] ||
	fail 'apply did not leave session.json at mode 640 for the greeter.'
grep -q 'stop dms.service' "$calls" || fail 'apply did not stop dms.service before writing.'
grep -q 'start dms.service' "$calls" || fail 'apply did not start dms.service after writing.'

cp "$live_plugins" "$test_root/applied.json"
: >"$calls"
second_run=$(run_apply "$home")
case $second_run in
*'already match'*) ;;
*) fail "second run was not a no-op: $second_run" ;;
esac
cmp -s "$live_plugins" "$test_root/applied.json" || fail 'second run changed plugin_settings.json.'
[ ! -s "$calls" ] || fail 'second run restarted dms.service.'

fresh_home="$test_root/fresh"
mkdir -p "$fresh_home"
run_apply "$fresh_home" >/dev/null
[ "$(plugin_value "$fresh_home" '.')" = "$(jq -c . "$repo_plugins")" ] ||
	fail 'a missing plugin_settings.json was not created from the repository file.'

printf '%s\n' 'dms-apply-look tests passed.'
