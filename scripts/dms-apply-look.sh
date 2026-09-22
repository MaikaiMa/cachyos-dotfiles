#!/bin/sh
# DMS 1.6.2 `settings set` IPC rejects arrays, so barConfigs forces a settings.json merge.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
look_json="$repo_root/dms/look.json"
session_look_json="$repo_root/dms/session.json"
settings_json="$HOME/.config/DankMaterialShell/settings.json"
session_json="${XDG_STATE_HOME:-$HOME/.local/state}/DankMaterialShell/session.json"
backup_json="$settings_json.before-look"
dry_run=0

usage() {
	printf 'Usage: %s [--dry-run]\n' "${0##*/}" >&2
}

for arg in "$@"; do
	case "$arg" in
	--dry-run)
		dry_run=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage
		exit 1
		;;
	esac
done

command -v jq >/dev/null 2>&1 || {
	printf 'dms-apply-look: jq is required but not installed\n' >&2
	exit 1
}

[ -f "$look_json" ] || {
	printf 'dms-apply-look: %s not found\n' "$look_json" >&2
	exit 1
}

for source in "$look_json" "$session_look_json"; do
	jq empty "$source" 2>/dev/null || {
		printf 'dms-apply-look: %s is not valid JSON\n' "$source" >&2
		exit 1
	}
done

tmp_merged=$(mktemp)
tmp_settings=$(mktemp)
tmp_session=$(mktemp)
tmp_session_merged=$(mktemp)
trap 'rm -f "$tmp_merged" "$tmp_settings" "$tmp_session" "$tmp_session_merged"' EXIT HUP INT TERM

copy_or_empty() {
	if [ -f "$1" ]; then
		cp "$1" "$2"
	else
		printf '{}\n' >"$2"
	fi
}

copy_or_empty "$settings_json" "$tmp_settings"
copy_or_empty "$session_json" "$tmp_session"

# DMS drops keys that equal their default from settings.json, so the effective value comes from IPC.
fill_effective_defaults() {
	command -v dms >/dev/null 2>&1 || return 0
	systemctl --user is-active --quiet dms.service || return 0
	for key in $(jq -r 'del(.barConfigs) | keys_unsorted[]' "$look_json"); do
		if jq -e --arg key "$key" 'has($key)' "$tmp_settings" >/dev/null; then
			continue
		fi
		value=$(dms ipc call settings get "$key" 2>/dev/null) || continue
		case "$value" in
		"" | *[!0-9.a-zA-Z-]*) continue ;;
		esac
		jq --arg key "$key" --arg value "$value" \
			'.[$key] = ($value | if . == "true" then true elif . == "false" then false elif test("^-?[0-9]+(\\.[0-9]+)?$") then tonumber else . end)' \
			"$tmp_settings" >"$tmp_settings.next" && mv "$tmp_settings.next" "$tmp_settings"
	done
}

fill_effective_defaults

# shellcheck disable=SC2016
merge_filter='
  .[0] as $settings
  | .[1] as $look
  | reduce ($look | to_entries[]) as $e (
      $settings;
      if $e.key == "barConfigs" then
        ($e.value[0].id // "default") as $id
        | .barConfigs = (
            if (.barConfigs // []) | any(.id == $id) then
              (.barConfigs // []) | map(if .id == $id then . * $e.value[0] else . end)
            else
              (.barConfigs // []) + [$e.value[0]]
            end
          )
      else
        .[$e.key] = $e.value
      end
    )
'
jq -s "$merge_filter" "$tmp_settings" "$look_json" >"$tmp_merged"
jq -s '.[0] * .[1]' "$tmp_session" "$session_look_json" >"$tmp_session_merged"

# shellcheck disable=SC2016
restrict_filter='($look[0] | keys_unsorted) as $keys | ($obj[0] | with_entries(select(.key as $k | $keys | index($k))))'
before_touched=$(jq -n --slurpfile look "$look_json" --slurpfile obj "$tmp_settings" "$restrict_filter")
after_touched=$(jq -n --slurpfile look "$look_json" --slurpfile obj "$tmp_merged" "$restrict_filter")
session_before=$(jq -n --slurpfile look "$session_look_json" --slurpfile obj "$tmp_session" "$restrict_filter")
session_after=$(jq -n --slurpfile look "$session_look_json" --slurpfile obj "$tmp_session_merged" "$restrict_filter")

if [ "$before_touched" = "$after_touched" ] && [ "$session_before" = "$session_after" ]; then
	printf 'dms-apply-look: settings already match %s and %s\n' "$look_json" "$session_look_json"
	exit 0
fi

if [ "$dry_run" -eq 1 ]; then
	printf 'dms-apply-look: dry run, applying would restart dms.service and change:\n'
	jq -n --argjson before "$before_touched" --argjson after "$after_touched" \
		--argjson sessionBefore "$session_before" --argjson sessionAfter "$session_after" \
		'{before: $before, after: $after, session: {before: $sessionBefore, after: $sessionAfter}}'
	exit 0
fi

printf 'dms-apply-look: applying changes:\n'
jq -n --argjson before "$before_touched" --argjson after "$after_touched" \
	--argjson sessionBefore "$session_before" --argjson sessionAfter "$session_after" \
	'{before: $before, after: $after, session: {before: $sessionBefore, after: $sessionAfter}}'

mkdir -p "$(dirname "$settings_json")" "$(dirname "$session_json")"

if [ -f "$settings_json" ] && [ ! -e "$backup_json" ]; then
	cp -p "$settings_json" "$backup_json"
fi

if ! systemctl --user stop dms.service; then
	printf 'dms-apply-look: failed to stop dms.service\n' >&2
	exit 1
fi

mv "$tmp_merged" "$settings_json"
mv "$tmp_session_merged" "$session_json"

if ! systemctl --user start dms.service; then
	printf 'dms-apply-look: failed to start dms.service; settings were written, start it manually\n' >&2
	exit 1
fi

if [ -e "$backup_json" ]; then
	printf 'dms-apply-look: applied %s to %s (backup: %s)\n' "$look_json" "$settings_json" "$backup_json"
else
	printf 'dms-apply-look: applied %s to %s\n' "$look_json" "$settings_json"
fi
