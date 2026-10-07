#!/bin/sh
# Exercise dms-settings against fake dms, niri, and sleep commands.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_dms-settings
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

fake_bin=$test_dir/bin
calls=$test_dir/calls
mkdir -p "$fake_bin"

# FAKE_WINDOW_BEFORE: the window exists before any dms call.
# FAKE_WINDOW_AFTER: the window appears after a settings call (unless
# FAKE_NEEDS_NUDGE is set, then only after the toast call).
# Variables in these strings expand when the generated fakes run.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "dms $*" >>"$FAKE_CALLS"' \
	'case $3 in' \
	'settings) [ -n "${FAKE_NEEDS_NUDGE:-}" ] || : >"$FAKE_STATE/window" ;;' \
	'toast) [ "$4" != info ] || : >"$FAKE_STATE/window" ;;' \
	'esac' >"$fake_bin/dms-test"
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "niri $*" >>"$FAKE_CALLS"' \
	'if [ -e "$FAKE_STATE/window" ]; then' \
	'printf "%s\n" "[{\"app_id\":\"other\",\"title\":\"x\"},{\"app_id\":\"com.danklinux.dms\",\"title\":\"Settings\"}]"' \
	'else' \
	'printf "%s\n" "[{\"app_id\":\"other\",\"title\":\"x\"}]"' \
	'fi' >"$fake_bin/niri-test"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$fake_bin/sleep-test"
chmod +x "$fake_bin"/*
state=$test_dir/state

run_helper() {
	rm -rf "$state"
	mkdir -p "$state"
	[ -z "${FAKE_WINDOW_BEFORE:-}" ] || : >"$state/window"
	: >"$calls"
	PATH=$fake_bin:$PATH \
		DMS_COMMAND=dms-test \
		NIRI_COMMAND=niri-test \
		SLEEP_COMMAND=sleep-test \
		FAKE_STATE=$state \
		FAKE_CALLS=$calls \
		"$helper" "$@"
}

dms_calls() {
	grep '^dms ' "$calls" || true
}

# The window appears immediately: no nudge.
run_helper
[ "$(dms_calls)" = 'dms ipc call settings open' ] || fail "Unexpected calls: $(dms_calls)"

run_helper network_wifi
[ "$(dms_calls)" = 'dms ipc call settings openWith network_wifi' ] || fail "Unexpected calls: $(dms_calls)"

# The window never appears until the nudge: exactly one toast info, then hide.
FAKE_NEEDS_NUDGE=1 run_helper network_wifi
expected=$(printf '%s\n' 'dms ipc call settings openWith network_wifi' 'dms ipc call toast info  ' 'dms ipc call toast hide')
[ "$(dms_calls)" = "$expected" ] || fail "Unexpected nudge calls: $(dms_calls)"

FAKE_NEEDS_NUDGE=1 run_helper --toggle
expected=$(printf '%s\n' 'dms ipc call settings focusOrToggle' 'dms ipc call toast info  ' 'dms ipc call toast hide')
[ "$(dms_calls)" = "$expected" ] || fail "Unexpected toggle nudge calls: $(dms_calls)"

# Already open with --toggle: the call may hide it, so never nudge.
FAKE_WINDOW_BEFORE=1 FAKE_NEEDS_NUDGE=1 run_helper --toggle
[ "$(dms_calls)" = 'dms ipc call settings focusOrToggle' ] || fail "Open window was nudged: $(dms_calls)"

# --toggle with a TAB opens that tab.
run_helper --toggle network_wifi
[ "$(dms_calls)" = 'dms ipc call settings openWith network_wifi' ] || fail "Unexpected calls: $(dms_calls)"

# Bad arguments exit 2 without calling dms.
for bad in "--nope" "one two"; do
	status=0
	# shellcheck disable=SC2086
	run_helper $bad 2>/dev/null || status=$?
	[ "$status" -eq 2 ] || fail "Arguments '$bad' exited with $status, not 2"
	[ -z "$(dms_calls)" ] || fail "Bad arguments called dms: $(dms_calls)"
done

# A missing prerequisite fails clearly.
status=0
message=$(
	rm -rf "$state"
	mkdir -p "$state"
	: >"$calls"
	PATH=$fake_bin:/nonexistent DMS_COMMAND=dms-test NIRI_COMMAND=niri-test \
		FAKE_STATE=$state FAKE_CALLS=$calls "$helper" 2>&1
) || status=$?
[ "$status" -eq 1 ] || fail "Missing jq exited with $status, not 1"
case $message in
*'Required command is missing: jq'*) ;;
*) fail "Missing jq message is unclear: $message" ;;
esac

printf '%s\n' 'dms-settings tests passed.'
