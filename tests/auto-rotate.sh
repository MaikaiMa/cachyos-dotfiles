#!/bin/sh
# Exercise auto-rotate's lock and rotation loop against fake niri, sensor,
# and keyboard-detection commands.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_auto-rotate
test_dir=$(mktemp -d)
run_pid=
cleanup() {
	if [ -n "$run_pid" ]; then
		kill "$run_pid" 2>/dev/null || true
	fi
	rm -rf "$test_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

fake_bin=$test_dir/bin
state_home=$test_dir/state
runtime_dir=$test_dir/runtime
calls=$test_dir/calls
keyboard_events=$test_dir/keyboard-events
sensor_events=$test_dir/sensor-events
lock_file=$state_home/dotfiles/rotation-lock
mkdir -p "$fake_bin" "$runtime_dir"
: >"$calls"

# Variables in these strings expand when the generated fakes run.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'if [ "$*" = "msg --json outputs" ]; then' \
	'    printf "%s\n" "{\"HDMI-A-1\": {\"logical\": {\"transform\": \"Normal\"}}, \"eDP-1\": {\"logical\": {\"transform\": \"Normal\"}}}"' \
	'else' \
	'    printf "%s\n" "$*" >>"$CALLS_FILE"' \
	'fi' >"$fake_bin/niri"

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'[ "$*" = "--accel" ] || exit 64' \
	'printf "%s\n" "    Waiting for iio-sensor-proxy to appear"' \
	'printf "%s\n" "=== Has accelerometer (orientation: undefined, tilt: undefined)"' \
	'exec cat "$SENSOR_EVENTS"' >"$fake_bin/monitor-sensor"

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'case $1 in' \
	'supported) exit 0 ;;' \
	'watch) exec cat "$KEYBOARD_EVENTS" ;;' \
	'esac' \
	'exit 64' >"$fake_bin/tablet-mode"

chmod +x "$fake_bin/niri" "$fake_bin/monitor-sensor" "$fake_bin/tablet-mode"

run_helper() {
	PATH=$fake_bin:$PATH \
		XDG_STATE_HOME=$state_home \
		XDG_RUNTIME_DIR=$runtime_dir \
		CALLS_FILE=$calls \
		SENSOR_EVENTS=$sensor_events \
		KEYBOARD_EVENTS=$keyboard_events \
		exec "$helper" "$@"
}

assert_equal() {
	[ "$1" = "$2" ] || fail "Expected $2, got $1"
}

wait_for_calls() {
	attempts=0
	while [ "$(wc -l <"$calls")" -lt "$1" ]; do
		attempts=$((attempts + 1))
		[ "$attempts" -le 50 ] || fail "Timed out waiting for $1 niri calls."
		sleep 0.1
	done
}

assert_equal "$(run_helper lock)" unlocked
assert_equal "$(run_helper lock toggle)" locked
assert_equal "$(cat "$lock_file")" locked
assert_equal "$(run_helper lock status)" locked
assert_equal "$(run_helper lock off)" unlocked
assert_equal "$(run_helper lock on)" locked
assert_equal "$(run_helper lock toggle)" unlocked
if (run_helper lock sideways) 2>/dev/null; then
	fail 'An unknown lock action must fail.'
fi

mkfifo "$keyboard_events" "$sensor_events"
run_helper run &
run_pid=$!
exec 4>"$keyboard_events"
exec 5>"$sensor_events"

printf '%s\n' laptop >&4
printf '%s\n' '    Accelerometer orientation changed: left-up' >&5
sleep 0.3
[ ! -s "$calls" ] || fail 'An attached keyboard must keep the panel upright.'

printf '%s\n' tablet >&4
wait_for_calls 1

(run_helper lock on) >/dev/null
printf '%s\n' '    Accelerometer orientation changed: right-up' >&5
sleep 0.3
printf '%s\n' laptop >&4
wait_for_calls 2

printf '%s\n' tablet >&4
sleep 0.3
(run_helper lock off) >/dev/null
wait_for_calls 3

printf '%s\n' '    Accelerometer orientation changed: bottom-up' >&5
wait_for_calls 4
printf '%s\n' laptop >&4
wait_for_calls 5

printf '%s\n' \
	'msg output eDP-1 transform 90' \
	'msg output eDP-1 transform normal' \
	'msg output eDP-1 transform 270' \
	'msg output eDP-1 transform 180' \
	'msg output eDP-1 transform normal' >"$test_dir/expected-calls"
diff -u "$test_dir/expected-calls" "$calls" ||
	fail 'auto-rotate sent the wrong transforms to niri.'

kill "$run_pid"
status=0
wait "$run_pid" || status=$?
run_pid=
assert_equal "$status" 143
[ ! -e "$runtime_dir/auto-rotate.events" ] ||
	fail 'auto-rotate must remove its event FIFO on exit.'
exec 4>&- 5>&-

printf '%s\n' 'auto-rotate tests passed.'
