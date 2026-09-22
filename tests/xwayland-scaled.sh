#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_xwayland-scaled
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

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "$*" >> "$CALLS_FILE.xprop-calls"' \
	'exit "${XPROP_EXIT:-0}"' >"$fake_bin/xprop"
chmod +x "$fake_bin/xprop"

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "$*" > "$CALLS_FILE.args"' >"$fake_bin/test-app"
chmod +x "$fake_bin/test-app"

: >"$calls.xprop-calls"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	DISPLAY=:9 \
	NIRI_OUTPUT='{"logical": {"scale": 1.75}}' \
	"$helper" test-app one two
grep -qx -- "-root -f RESOURCE_MANAGER 8s -set RESOURCE_MANAGER Xft.dpi:	192" "$calls.xprop-calls"
grep -qx 'one two' "$calls.args"

: >"$calls.xprop-calls"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	DISPLAY=:9 \
	NIRI_OUTPUT='{"logical": {"scale": 1.25}}' \
	"$helper" test-app one two
grep -qx -- "-root -f RESOURCE_MANAGER 8s -set RESOURCE_MANAGER Xft.dpi:	96" "$calls.xprop-calls"

: >"$calls.xprop-calls"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	DISPLAY=:9 \
	NIRI_OUTPUT='{"logical": {"scale": 2.0}}' \
	"$helper" test-app one two
grep -qx -- "-root -f RESOURCE_MANAGER 8s -set RESOURCE_MANAGER Xft.dpi:	192" "$calls.xprop-calls"

: >"$calls.xprop-calls"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	DISPLAY=:9 \
	NIRI_OUTPUT='{"logical": {"scale": 0.5}}' \
	"$helper" test-app one two
grep -qx -- "-root -f RESOURCE_MANAGER 8s -set RESOURCE_MANAGER Xft.dpi:	96" "$calls.xprop-calls"

warning=$test_dir/warning
: >"$calls.xprop-calls"
: >"$calls.args"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	DISPLAY=:9 \
	NIRI_FAIL=1 \
	"$helper" test-app 2>"$warning"
[ ! -s "$calls.xprop-calls" ]
[ -s "$calls.args" ]
[ -s "$warning" ]

warning=$test_dir/warning
: >"$calls.xprop-calls"
: >"$calls.args"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	"$helper" test-app 2>"$warning"
[ ! -s "$calls.xprop-calls" ]
[ -s "$calls.args" ]
[ -s "$warning" ]

warning=$test_dir/warning
: >"$calls.xprop-calls"
: >"$calls.args"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	DISPLAY=:9 \
	NIRI_OUTPUT='{"logical": {"scale": 1.75}}' \
	XPROP_EXIT=1 \
	"$helper" test-app 2>"$warning"
[ -s "$calls.xprop-calls" ]
[ -s "$calls.args" ]
[ -s "$warning" ]

status=0
"$helper" >/dev/null 2>&1 || status=$?
[ "$status" -eq 2 ]

printf '%s\n' 'xwayland-scaled tests passed.'
