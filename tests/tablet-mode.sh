#!/bin/sh
# Exercise tablet-mode against fake DMI, USB sysfs, and udev event streams.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_tablet-mode
test_dir=$(mktemp -d)
watch_pid=
cleanup() {
	if [ -n "$watch_pid" ]; then
		kill "$watch_pid" 2>/dev/null || true
	fi
	rm -rf "$test_dir"
}
trap cleanup EXIT HUP INT TERM

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

dmi=$test_dir/dmi
usb=$test_dir/usb
fake_bin=$test_dir/bin
events=$test_dir/udev-events
watch_output=$test_dir/watch-output
mkdir -p "$dmi" "$usb/3-5" "$fake_bin"
printf '%s\n' 0b05 >"$usb/3-5/idVendor"
printf '%s\n' 18c6 >"$usb/3-5/idProduct"

set_machine() {
	printf '%s\n' "$1" >"$dmi/product_family"
	printf '%s\n' "$2" >"$dmi/board_name"
}

attach_keyboard() {
	mkdir -p "$usb/3-4"
	printf '%s\n' 0b05 >"$usb/3-4/idVendor"
	printf '%s\n' 1a30 >"$usb/3-4/idProduct"
}

detach_keyboard() {
	rm -rf "$usb/3-4"
}

run_helper() {
	PATH=$fake_bin:$PATH \
		Z13_DMI_ROOT=$dmi \
		TABLET_MODE_USB_ROOT=$usb \
		TABLET_MODE_SETTLE_SECONDS=0 \
		UDEV_EVENTS=$events \
		"$helper" "$@"
}

assert_status() {
	expected_output=$1
	expected_status=$2
	status=0
	output=$(run_helper status) || status=$?
	[ "$output" = "$expected_output" ] ||
		fail "Expected status output $expected_output, got $output"
	[ "$status" -eq "$expected_status" ] ||
		fail "Expected status exit $expected_status, got $status"
}

wait_for_lines() {
	attempts=0
	while [ "$(wc -l <"$watch_output")" -lt "$1" ]; do
		attempts=$((attempts + 1))
		[ "$attempts" -le 50 ] || fail "Timed out waiting for $1 watch lines."
		sleep 0.1
	done
}

set_machine 'ROG Flow Z13' GZ302EA
attach_keyboard
run_helper supported || fail 'A GZ302 Flow Z13 must be supported.'
assert_status laptop 1

detach_keyboard
assert_status tablet 0

set_machine 'ROG Zephyrus G14' GA403UV
run_helper supported && fail 'Other hardware must not be supported.'
assert_status laptop 1

set_machine 'ROG Flow Z13' GZ302EA
attach_keyboard

# Variables in these strings expand when the generated fake runs.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'[ "$*" = "monitor --udev --subsystem-match=usb" ] || exit 64' \
	'printf "%s\n" "monitor will print the received events for:"' \
	'exec cat "$UDEV_EVENTS"' >"$fake_bin/udevadm"
chmod +x "$fake_bin/udevadm"
mkfifo "$events"
: >"$watch_output"

run_helper watch >"$watch_output" &
watch_pid=$!
exec 4>"$events"

wait_for_lines 1
detach_keyboard
printf '%s\n' 'UDEV  [10.0] remove   /devices/usb3/3-4 (usb)' >&4
wait_for_lines 2
printf '%s\n' 'UDEV  [10.1] remove   /devices/usb3/3-4/3-4:1.0 (usb)' >&4
attach_keyboard
printf '%s\n' 'UDEV  [20.0] add      /devices/usb3/3-4 (usb)' >&4
wait_for_lines 3
exec 4>&-
wait "$watch_pid"
watch_pid=

printf '%s\n' laptop tablet laptop >"$test_dir/expected-watch"
diff -u "$test_dir/expected-watch" "$watch_output" ||
	fail 'tablet-mode watch reported the wrong transitions.'

printf '%s\n' 'tablet-mode tests passed.'
