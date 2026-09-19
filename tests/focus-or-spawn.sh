#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_focus-or-spawn
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

fake_bin=$test_dir/bin
calls=$test_dir/calls
runtime_dir=$test_dir/runtime
window_open=$test_dir/window-open
mkdir -p "$fake_bin" "$runtime_dir"

# Variables in these strings expand when the generated fake runs.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'set -eu' \
	'if [ "$*" = "msg --json windows" ]; then' \
	'    if [ -e "$WINDOW_OPEN_FILE" ]; then' \
	'        printf "%s\n" "[{\"id\": 44, \"app_id\": \"zen\", \"is_focused\": true, \"focus_timestamp\": null}]"' \
	'    else' \
	'        printf "%s\n" "$NIRI_WINDOWS"' \
	'    fi' \
	'else' \
	'    printf "niri %s\n" "$*" >> "$CALLS_FILE"' \
	'fi' >"$fake_bin/niri"

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "app %s\n" "$*" >> "$CALLS_FILE"' \
	'sleep "${APP_DELAY:-0}"' \
	': > "$WINDOW_OPEN_FILE"' >"$fake_bin/test-app"

chmod +x "$fake_bin/niri" "$fake_bin/test-app"

: >"$calls"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	WINDOW_OPEN_FILE=$window_open \
	XDG_RUNTIME_DIR=$runtime_dir \
	NIRI_WINDOWS='[]' \
	"$helper" zen test-app --new
grep -qx 'app --new' "$calls"

: >"$calls"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	WINDOW_OPEN_FILE=$test_dir/not-open \
	XDG_RUNTIME_DIR=$runtime_dir \
	NIRI_WINDOWS='[
        {"id": 11, "app_id": "zen", "is_focused": false, "focus_timestamp": {"secs": 10, "nanos": 0}},
        {"id": 22, "app_id": "zen", "is_focused": false, "focus_timestamp": {"secs": 20, "nanos": 0}},
        {"id": 33, "app_id": "Alacritty", "is_focused": true, "focus_timestamp": {"secs": 30, "nanos": 0}}
    ]' \
	"$helper" zen test-app
grep -qx 'niri msg action focus-window --id 22' "$calls"

: >"$calls"
PATH=$fake_bin:$PATH \
	CALLS_FILE=$calls \
	WINDOW_OPEN_FILE=$test_dir/not-open \
	XDG_RUNTIME_DIR=$runtime_dir \
	NIRI_WINDOWS='[
        {"id": 11, "app_id": "zen", "is_focused": true, "focus_timestamp": {"secs": 10, "nanos": 0}},
        {"id": 22, "app_id": "zen", "is_focused": false, "focus_timestamp": {"secs": 20, "nanos": 0}}
    ]' \
	"$helper" zen test-app
grep -qx 'niri msg action focus-window --id 11' "$calls"

: >"$calls"
concurrent_window=$test_dir/concurrent-window
PATH=$fake_bin:$PATH \
	APP_DELAY=0.2 \
	CALLS_FILE=$calls \
	WINDOW_OPEN_FILE=$concurrent_window \
	XDG_RUNTIME_DIR=$runtime_dir \
	NIRI_WINDOWS='[]' \
	"$helper" zen test-app &
first_pid=$!
PATH=$fake_bin:$PATH \
	APP_DELAY=0.2 \
	CALLS_FILE=$calls \
	WINDOW_OPEN_FILE=$concurrent_window \
	XDG_RUNTIME_DIR=$runtime_dir \
	NIRI_WINDOWS='[]' \
	"$helper" zen test-app &
second_pid=$!
wait "$first_pid" "$second_pid"
[ "$(grep -c '^app ' "$calls")" -eq 1 ]

printf '%s\n' 'focus-or-spawn tests passed.'
