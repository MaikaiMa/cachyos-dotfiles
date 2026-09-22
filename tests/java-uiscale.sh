#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_java-uiscale
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

fake_bin=$test_dir/bin
calls=$test_dir/calls
mkdir -p "$fake_bin"

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'set -eu' \
	'if [ "$*" = "msg --json focused-output" ]; then' \
	'    if [ "${NIRI_FAIL:-0}" = "1" ]; then' \
	'        exit 1' \
	'    fi' \
	'    printf "%s\n" "$NIRI_OUTPUT"' \
	'fi' >"$fake_bin/niri"
chmod +x "$fake_bin/niri"

# Variables in these strings expand when the generated fake runs.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "$JAVA_TOOL_OPTIONS" > "$CALLS_FILE.options"' \
	'printf "%s\n" "$*" > "$CALLS_FILE.args"' >"$fake_bin/test-app"
chmod +x "$fake_bin/test-app"

PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	NIRI_OUTPUT='{"logical": {"scale": 1.75}}' \
	"$helper" test-app one two
grep -qx -- '-Dsun.java2d.uiScale=2' "$calls.options"
grep -qx 'one two' "$calls.args"

PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	NIRI_OUTPUT='{"logical": {"scale": 1.75}}' \
	JAVA_TOOL_OPTIONS='-Xmx1g' \
	"$helper" test-app
grep -qx -- '-Xmx1g -Dsun.java2d.uiScale=2' "$calls.options"

PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	NIRI_OUTPUT='{"logical": {"scale": 1.25}}' \
	"$helper" test-app one two
grep -qx -- '-Dsun.java2d.uiScale=1' "$calls.options"

PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	NIRI_OUTPUT='{"logical": {"scale": 2.0}}' \
	"$helper" test-app one two
grep -qx -- '-Dsun.java2d.uiScale=2' "$calls.options"

PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	NIRI_OUTPUT='{"logical": {"scale": 0.5}}' \
	"$helper" test-app one two
grep -qx -- '-Dsun.java2d.uiScale=1' "$calls.options"

warning=$test_dir/warning
: >"$calls.options"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	NIRI_FAIL=1 \
	"$helper" test-app 2>"$warning"
[ -z "$(cat "$calls.options")" ]
[ -s "$warning" ]

status=0
"$helper" >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ]

printf '%s\n' 'java-uiscale tests passed.'
