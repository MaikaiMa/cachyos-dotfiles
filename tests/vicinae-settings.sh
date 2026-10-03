#!/bin/sh
# Exercise the chezmoi modify script that points Vicinae at the managed import.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/chezmoi/dot_config/vicinae/modify_settings.json"
import_file="$repo_root/chezmoi/dot_config/vicinae/dotfiles.json"

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

normalized() {
	sh "$script" | sed '/^[[:space:]]*\/\//d' | jq -S -c .
}

[ "$(printf '' | normalized)" = '{"imports":["./dotfiles.json"]}' ] ||
	fail 'A missing settings.json did not become an import of dotfiles.json.'

# shellcheck disable=SC2016 # $schema is a literal JSON key.
vicinae_written='// Learn more about configuration at https://docs.vicinae.com/config

{
   "$schema": "https://vicinae.com/schemas/config.json",
   "theme": {
      "dark": {
         "name": "tokyo-night",
         "icon_theme": "Papirus"
      }
   },
   "favicon_service": "google", // trailing comment
   /* block comment */
   "telemetry": {
      "system_info": false
   }
}'
# shellcheck disable=SC2016
expected='{"$schema":"https://vicinae.com/schemas/config.json","favicon_service":"google","imports":["./dotfiles.json"],"telemetry":{"system_info":false},"theme":{"dark":{"icon_theme":"Papirus"}}}'
[ "$(printf '%s\n' "$vicinae_written" | normalized)" = "$expected" ] ||
	fail 'Vicinae-written JSONC did not keep its own keys while dropping the theme name.'

[ "$(printf '%s\n' "$vicinae_written" | sh "$script" | head -n 1)" = '// Learn more about configuration at https://docs.vicinae.com/config' ] ||
	fail 'The Vicinae header comment was not kept.'

once=$(printf '%s\n' "$vicinae_written" | sh "$script")
[ "$(printf '%s\n' "$once" | sh "$script")" = "$once" ] ||
	fail 'A second run rewrote an already converged file.'

owned_by_import=$(jq -c '[paths(scalars)] | reduce .[] as $path ({}; setpath($path; "settings.json value"))' "$import_file")
leftover=$(printf '%s' "$owned_by_import" | normalized | jq -c '[paths(scalars)] - [["imports", 0]]')
[ "$leftover" = '[]' ] ||
	fail "Keys owned by dotfiles.json stayed in settings.json: $leftover"

[ "$(printf '%s' '{"imports":["./keybinds.json"]}' | normalized)" = '{"imports":["./keybinds.json","./dotfiles.json"]}' ] ||
	fail 'An existing import was not kept.'

if printf '%s' 'not json' | sh "$script" >/dev/null 2>&1; then
	fail 'Invalid JSON was accepted.'
fi

if printf '%s' '[]' | sh "$script" >/dev/null 2>&1; then
	fail 'A JSON value that is not an object was accepted.'
fi

printf '%s\n' 'Vicinae settings tests passed.'
