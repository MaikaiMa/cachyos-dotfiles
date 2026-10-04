#!/bin/sh
# Exercise build-vicinae-extensions with a stub npm against an isolated home; no network.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script=$repo_root/scripts/build-vicinae-extensions.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin=$test_root/bin
test_home=$test_root/home
source_root=$test_root/extensions
calls=$test_root/calls
installed=$test_home/.local/share/vicinae/extensions/writing-tools
mkdir -p "$fake_bin" "$test_home" "$source_root/vicinae-writing/src"
cp "$repo_root/extensions/vicinae-writing/package.json" "$source_root/vicinae-writing/"
printf '%s\n' 'export {};' >"$source_root/vicinae-writing/src/writing-tools.tsx"

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

# The stub expands its variables when it runs, not here. "run build" installs
# the way vici build does: the whole extension directory is replaced.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s %s\n" "${PWD##*/}" "$*" >>"$FAKE_NPM_CALLS"' \
	'if [ "$1" = run ] && [ "$2" = build ]; then' \
	'    target=$XDG_DATA_HOME/vicinae/extensions/writing-tools' \
	'    rm -rf "$target"' \
	'    mkdir -p "$target"' \
	'    cp package.json "$target/"' \
	'fi' >"$fake_bin/npm"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$fake_bin/node"
chmod +x "$fake_bin/npm" "$fake_bin/node"

run_build() {
	HOME=$test_home XDG_DATA_HOME=$test_home/.local/share \
		VICINAE_EXTENSIONS_SOURCE=$source_root FAKE_NPM_CALLS=$calls \
		PATH=$fake_bin:$PATH "$script" "$@"
}

missing_output=$(NPM_COMMAND=missing-npm run_build 2>&1) && fail 'The build ran without npm.'
case $missing_output in
*'missing-npm is required but not installed'*) ;;
*) fail "Missing npm was not reported clearly: $missing_output" ;;
esac

dry_output=$(run_build --dry-run)
case $dry_output in
*"+ npm ci and vici build in $source_root/vicinae-writing, installing $installed"*) ;;
*) fail "Dry run did not preview the build: $dry_output" ;;
esac
if [ -e "$calls" ] || [ -e "$test_home/.local" ]; then
	fail 'Dry run ran npm or wrote to the home.'
fi

run_build >/dev/null
expected='vicinae-writing ci --no-audit --no-fund
vicinae-writing run build'
[ "$(cat "$calls")" = "$expected" ] || fail "Unexpected npm calls: $(cat "$calls")"
[ -s "$installed/.dotfiles-source-hash" ] || fail 'The build did not record the source hash.'

: >"$calls"
run_build >/dev/null
[ ! -s "$calls" ] || fail 'An unchanged extension was rebuilt.'
[ -z "$(run_build --dry-run)" ] || fail 'Dry run reported work for an unchanged extension.'

mkdir -p "$source_root/vicinae-writing/node_modules"
printf '%s\n' 'generated' >"$source_root/vicinae-writing/vicinae-env.d.ts"
printf '%s\n' 'dependency' >"$source_root/vicinae-writing/node_modules/dependency.js"
[ -z "$(run_build --dry-run)" ] || fail 'Generated files or node_modules changed the source hash.'

printf '%s\n' 'export const changed = true;' >>"$source_root/vicinae-writing/src/writing-tools.tsx"
run_build >/dev/null
[ "$(cat "$calls")" = "$expected" ] || fail 'A changed extension was not rebuilt.'

: >"$calls"
run_build --force >/dev/null
[ "$(cat "$calls")" = "$expected" ] || fail '--force did not rebuild.'

# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "%s %s\n" "${PWD##*/}" "$*" >>"$FAKE_NPM_CALLS"' >"$fake_bin/npm"
rm -rf "$installed"
run_build >/dev/null 2>&1 && fail 'A build that installed nothing was reported as success.'

printf '%s\n' 'Vicinae extension build tests passed.'
