#!/bin/sh
# Exercise the chezmoi modify script that keeps DMS's clipboard history off.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/chezmoi/dot_config/DankMaterialShell/modify_clsettings.json"

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

[ "$(printf '' | sh "$script" | jq -c .)" = '{"disabled":true}' ] ||
	fail 'A missing clsettings.json did not become {"disabled": true}.'

[ "$(printf '%s' '{"maxHistory":50,"disabled":false}' | sh "$script" | jq -c .)" = '{"maxHistory":50,"disabled":true}' ] ||
	fail 'Disabling the history did not keep the other DMS keys.'

already='{"maxPinned": 25, "disabled": true}'
[ "$(printf '%s' "$already" | sh "$script")" = "$already" ] ||
	fail 'An already disabled file was rewritten.'

if printf '%s' 'not json' | sh "$script" >/dev/null 2>&1; then
	fail 'Invalid JSON was accepted.'
fi

printf '%s\n' 'DMS clipboard settings tests passed.'
