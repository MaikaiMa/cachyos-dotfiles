#!/bin/sh
# Install the DMS registry plugins pinned in dms/plugins.lock.json.
# Restore runs without --prune so plugins installed by hand survive.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
lock_json=${DMS_PLUGIN_LOCKFILE:-$repo_root/dms/plugins.lock.json}
dms_dir="${XDG_CONFIG_HOME:-$HOME/.config}/DankMaterialShell"
plugins_dir="$dms_dir/plugins"
live_lock_json="$dms_dir/plugins.lock.json"
dms_command=${DMS_COMMAND:-dms}
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

for tool in jq "$dms_command"; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf 'dms-restore-plugins: %s is required but not installed\n' "$tool" >&2
		exit 1
	}
done

[ -f "$lock_json" ] || {
	printf 'dms-restore-plugins: %s not found\n' "$lock_json" >&2
	exit 1
}

# Mirrors the checks DMS 1.6.2 applies in PluginLockfile.Validate.
# shellcheck disable=SC2016
validate_filter='
  (.lockfileVersion == 1)
  and (.plugins | type == "object")
  and all(.plugins | to_entries[];
      (.key | test("^[A-Za-z0-9._-]+$"))
      and (.value.repo | type == "string" and length > 0)
      and (.value.commit | type == "string" and test("^[0-9a-fA-F]{40}$"))
      and ((.value.path // "") | (type == "string") and ((startswith("/") or . == ".." or startswith("../")) | not)))
  and ([.plugins[] | {repo, commit: (.commit | ascii_downcase)}] | unique | group_by(.repo) | all(length == 1))
'
jq -e "$validate_filter" "$lock_json" >/dev/null 2>&1 || {
	printf 'dms-restore-plugins: %s is not a valid DMS plugin lockfile\n' "$lock_json" >&2
	exit 1
}

tmp_live=$(mktemp)
tmp_installed=$(mktemp)
trap 'rm -f "$tmp_live" "$tmp_installed"' EXIT HUP INT TERM

if [ -f "$live_lock_json" ]; then
	jq -e '.plugins | type == "object"' "$live_lock_json" >/dev/null 2>&1 || {
		printf 'dms-restore-plugins: %s is not valid JSON\n' "$live_lock_json" >&2
		exit 1
	}
	cp "$live_lock_json" "$tmp_live"
else
	printf '{"plugins": {}}\n' >"$tmp_live"
fi

for manifest in "$plugins_dir"/*/plugin.json; do
	[ -f "$manifest" ] || continue
	jq -r '.id // empty' "$manifest" 2>/dev/null || true
done >"$tmp_installed"

# shellcheck disable=SC2016
plan_filter='
  $live[0].plugins as $current
  | ($installed | split("\n") | map(select(length > 0))) as $ids
  | .plugins | to_entries[]
  | .key as $id | .value as $want | ($current[$id]) as $have
  | ($want.commit[0:7]) as $short
  | ($want.repo + (if ($want.path // "") != "" then " " + $want.path else "" end)) as $source
  | if ($ids | index($id)) == null then
      "install \($id) at \($short) from \($source)"
    elif $have == null then
      "conflict \($id): installed outside the DMS lockfile, dms may refuse to restore it"
    elif $have.repo != $want.repo or ($have.path // "") != ($want.path // "") then
      "reinstall \($id) at \($short) from \($source)"
    elif ($have.commit | ascii_downcase) != ($want.commit | ascii_downcase) then
      "update \($id) \($have.commit[0:7]) -> \($short)"
    else
      empty
    end
'
plan=$(jq -r --slurpfile live "$tmp_live" --rawfile installed "$tmp_installed" "$plan_filter" "$lock_json")

if [ -z "$plan" ]; then
	printf 'dms-restore-plugins: plugins already match %s\n' "$lock_json"
	exit 0
fi

if [ "$dry_run" -eq 1 ]; then
	printf 'dms-restore-plugins: dry run, restoring would change:\n'
	printf '%s\n' "$plan" | sed 's/^/  /'
	exit 0
fi

printf 'dms-restore-plugins: restoring:\n'
printf '%s\n' "$plan" | sed 's/^/  /'

if ! "$dms_command" plugins restore "$lock_json"; then
	printf 'dms-restore-plugins: dms plugins restore failed for %s\n' "$lock_json" >&2
	exit 1
fi

printf 'dms-restore-plugins: restored plugins from %s\n' "$lock_json"

if systemctl --user is-active --quiet dms.service; then
	printf 'dms-restore-plugins: restart DMS to load the new plugins: dms-reset\n'
fi
