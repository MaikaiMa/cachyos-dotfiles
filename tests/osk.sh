#!/bin/sh
# Exercise osk against fake busctl and systemctl commands.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_osk
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

fake_bin=$test_dir/bin
calls=$test_dir/calls
running=$test_dir/running
visible=$test_dir/visible
mkdir -p "$fake_bin"

# Variables in these strings expand when the generated fakes run.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'[ "$1" = --user ] || exit 64' \
	'shift' \
	'case "$*" in' \
	'"status sm.puri.OSK0") [ -e "$RUNNING_FILE" ] ;;' \
	'"get-property sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 Visible") printf "b %s\n" "$(cat "$VISIBLE_FILE")" ;;' \
	'"call sm.puri.OSK0 /sm/puri/OSK0 sm.puri.OSK0 SetVisible b "*)' \
	'    printf "%s\n" "SetVisible $7" >>"$CALLS_FILE"' \
	'    printf "%s\n" "$7" >"$VISIBLE_FILE" ;;' \
	'*) exit 64 ;;' \
	'esac' >"$fake_bin/busctl"

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'[ "$*" = "--user start mobi.phosh.OSK.service" ] || exit 64' \
	'printf "%s\n" "start" >>"$CALLS_FILE"' \
	': >"$RUNNING_FILE"' \
	'printf "%s\n" false >"$VISIBLE_FILE"' >"$fake_bin/systemctl"

chmod +x "$fake_bin/busctl" "$fake_bin/systemctl"

run_helper() {
	PATH=$fake_bin:$PATH \
		CALLS_FILE=$calls \
		RUNNING_FILE=$running \
		VISIBLE_FILE=$visible \
		"$helper" "$@"
}

: >"$calls"
[ "$(run_helper status)" = hidden ] || fail 'A stopped keyboard must be hidden.'
run_helper hide
[ ! -s "$calls" ] || fail 'Hiding a stopped keyboard must not start it.'

run_helper toggle
[ "$(run_helper status)" = visible ] || fail 'Toggle must show a hidden keyboard.'
run_helper toggle
[ "$(run_helper status)" = hidden ] || fail 'Toggle must hide a visible keyboard.'
run_helper show
run_helper hide

printf '%s\n' start 'SetVisible true' 'SetVisible false' 'SetVisible true' \
	'SetVisible false' >"$test_dir/expected-calls"
diff -u "$test_dir/expected-calls" "$calls" ||
	fail 'osk made the wrong D-Bus calls.'

monitor_events=$test_dir/monitor-events
watch_output=$test_dir/watch-output
mkfifo "$monitor_events"
: >"$watch_output"

# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'[ "$*" = "monitor --session --dest sm.puri.OSK0 --object-path /sm/puri/OSK0" ] || exit 64' \
	'printf "%s\n" "Monitoring signals on object /sm/puri/OSK0 owned by sm.puri.OSK0"' \
	'exec cat "$MONITOR_EVENTS"' >"$fake_bin/gdbus"
chmod +x "$fake_bin/gdbus"

wait_for_lines() {
	attempts=0
	while [ "$(wc -l <"$watch_output")" -lt "$1" ]; do
		attempts=$((attempts + 1))
		[ "$attempts" -le 50 ] || fail "Timed out waiting for $1 watch lines."
		sleep 0.1
	done
}

changed() {
	printf "/sm/puri/OSK0: org.freedesktop.DBus.Properties.PropertiesChanged ('sm.puri.OSK0', {'Visible': <%s>}, @as [])\n" "$1"
}

printf '%s\n' false >"$visible"
MONITOR_EVENTS=$monitor_events run_helper watch >"$watch_output" &
watch_pid=$!
exec 4>"$monitor_events"

printf '%s\n' 'The name sm.puri.OSK0 is owned by :1.42' >&4
wait_for_lines 1
changed true >&4
wait_for_lines 2
changed true >&4
changed false >&4
wait_for_lines 3
changed true >&4
wait_for_lines 4
rm -f "$running"
printf '%s\n' 'The name sm.puri.OSK0 does not have an owner' >&4
wait_for_lines 5
: >"$running"
printf '%s\n' true >"$visible"
printf '%s\n' 'The name sm.puri.OSK0 is owned by :1.43' >&4
wait_for_lines 6
exec 4>&-
wait "$watch_pid"

printf '%s\n' hidden visible hidden visible hidden visible >"$test_dir/expected-watch"
diff -u "$test_dir/expected-watch" "$watch_output" ||
	fail 'osk watch reported the wrong visibility changes.'

printf '%s\n' 'osk tests passed.'
