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
settings_json="$HOME/.config/DankMaterialShell/settings.json"
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

[ -f "$settings_json" ] || {
	printf 'dms-apply-look: %s not found; run DMS at least once first\n' "$settings_json" >&2
	exit 1
}

jq empty "$look_json" 2>/dev/null || {
	printf 'dms-apply-look: %s is not valid JSON\n' "$look_json" >&2
	exit 1
}

tmp_merged=$(mktemp)
trap 'rm -f "$tmp_merged"' EXIT HUP INT TERM

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
jq -s "$merge_filter" "$settings_json" "$look_json" >"$tmp_merged"

# shellcheck disable=SC2016
restrict_filter='($look[0] | keys_unsorted) as $keys | ($obj[0] | with_entries(select(.key as $k | $keys | index($k))))'
before_touched=$(jq -n --slurpfile look "$look_json" --slurpfile obj "$settings_json" "$restrict_filter")
after_touched=$(jq -n --slurpfile look "$look_json" --slurpfile obj "$tmp_merged" "$restrict_filter")

if [ "$before_touched" = "$after_touched" ]; then
	printf 'dms-apply-look: settings already match %s\n' "$look_json"
	exit 0
fi

if [ "$dry_run" -eq 1 ]; then
	printf 'dms-apply-look: dry run, would change:\n'
	jq -n --argjson before "$before_touched" --argjson after "$after_touched" \
		'{before: $before, after: $after}'
	exit 0
fi

printf 'dms-apply-look: applying changes:\n'
jq -n --argjson before "$before_touched" --argjson after "$after_touched" \
	'{before: $before, after: $after}'

if [ ! -e "$backup_json" ]; then
	cp -p "$settings_json" "$backup_json"
fi

if ! systemctl --user stop dms.service; then
	printf 'dms-apply-look: failed to stop dms.service\n' >&2
	exit 1
fi

mv "$tmp_merged" "$settings_json"

if ! systemctl --user start dms.service; then
	printf 'dms-apply-look: failed to start dms.service; settings were written, start it manually\n' >&2
	exit 1
fi

printf 'dms-apply-look: applied %s to %s (backup: %s)\n' "$look_json" "$settings_json" "$backup_json"
