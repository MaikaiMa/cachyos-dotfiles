#!/bin/sh
# Build the repository's Vicinae extensions and install them where Vicinae
# loads them. An extension whose sources match the last build is skipped.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
extensions_source=${VICINAE_EXTENSIONS_SOURCE:-$repo_root/extensions}
extensions_target="${XDG_DATA_HOME:-$HOME/.local/share}/vicinae/extensions"
npm_command=${NPM_COMMAND:-npm}
node_command=${NODE_COMMAND:-node}
stamp_name=.dotfiles-source-hash
dry_run=0
force=0

usage() {
	printf 'Usage: %s [--dry-run] [--force]\n' "${0##*/}" >&2
}

for arg in "$@"; do
	case "$arg" in
	--dry-run | -n)
		dry_run=1
		;;
	--force)
		force=1
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

for tool in jq sha256sum "$node_command" "$npm_command"; do
	command -v "$tool" >/dev/null 2>&1 || {
		printf 'build-vicinae-extensions: %s is required but not installed (pacman: jq coreutils nodejs npm)\n' "$tool" >&2
		exit 1
	}
done

# The hash covers everything vici build reads; node_modules and the generated
# vicinae-env.d.ts are left out because they do not change the output.
source_hash() {
	(
		cd -- "$1"
		find . -path ./node_modules -prune -o -type f ! -name vicinae-env.d.ts -print |
			LC_ALL=C sort |
			while IFS= read -r file; do
				sha256sum -- "$file"
			done |
			sha256sum |
			cut -d ' ' -f 1
	)
}

for manifest in "$extensions_source"/*/package.json; do
	[ -f "$manifest" ] || continue
	extension_dir=${manifest%/package.json}
	name=$(jq -r '.name // empty' "$manifest")
	if [ -z "$name" ]; then
		printf 'build-vicinae-extensions: %s has no name\n' "$manifest" >&2
		exit 1
	fi
	target="$extensions_target/$name"
	wanted_hash=$(source_hash "$extension_dir")
	installed_hash=$(cat -- "$target/$stamp_name" 2>/dev/null || true)

	if [ "$force" -eq 0 ] && [ "$wanted_hash" = "$installed_hash" ]; then
		continue
	fi

	if [ "$dry_run" -eq 1 ]; then
		printf '+ npm ci and vici build in %s, installing %s\n' "$extension_dir" "$target"
		continue
	fi

	printf 'build-vicinae-extensions: building %s\n' "$name"
	(
		cd -- "$extension_dir"
		"$npm_command" ci --no-audit --no-fund
		"$npm_command" run build
	)
	if [ ! -f "$target/package.json" ]; then
		printf 'build-vicinae-extensions: the build did not install %s\n' "$target" >&2
		exit 1
	fi
	printf '%s\n' "$wanted_hash" >"$target/$stamp_name"
done
