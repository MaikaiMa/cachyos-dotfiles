#!/bin/sh
# Exercise bar-notifications against stub systemctl and busctl that record their calls.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/chezmoi/dot_local/bin/executable_bar-notifications"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin="$test_root/bin"
runtime="$test_root/runtime"
systemctl_calls="$test_root/systemctl-calls"
busctl_calls="$test_root/busctl-calls"
marker="$runtime/bar-notifications.restart-dms"
mkdir -p "$fake_bin" "$runtime"

# STUB_DMS_ACTIVE, STUB_LOCKED, STUB_NRESTARTS and STUB_OWNER select the answers.
cat >"$fake_bin/systemctl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$SYSTEMCTL_STUB_CALLS"
case "$*" in
'--user is-active --quiet dms.service') [ -n "${STUB_DMS_ACTIVE:-}" ] ;;
'--user show quickshell-bar.service -p NRestarts --value') echo "${STUB_NRESTARTS:-0}" ;;
'--user stop dms.service' | '--user start --no-block dms.service') ;;
*) exit 1 ;;
esac
STUB
cat >"$fake_bin/busctl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$BUSCTL_STUB_CALLS"
case "$*" in
'--system get-property org.freedesktop.login1 /org/freedesktop/login1/user/self org.freedesktop.login1.User Display')
	printf '(so) "2" "/org/freedesktop/login1/session/_32"\n'
	;;
'--system get-property org.freedesktop.login1 /org/freedesktop/login1/session/_32 org.freedesktop.login1.Session LockedHint')
	if [ -n "${STUB_LOCKED:-}" ]; then echo 'b true'; else echo 'b false'; fi
	;;
'--user status org.freedesktop.Notifications')
	case ${STUB_OWNER:-} in
	'') exit 1 ;;
	quickshell) printf 'PID=4242\nComm=quickshell\nCommandLine=quickshell -c bar -n\n' ;;
	dms) printf 'PID=4243\nComm=qs\nCommandLine=qs -p /run/user/1000/danklinux-shell/0123abcd\n' ;;
	qs-other) printf 'PID=4244\nComm=qs\nCommandLine=qs -c something-else\n' ;;
	*) printf 'PID=4245\nComm=%s\nCommandLine=%s --run\n' "$STUB_OWNER" "$STUB_OWNER" ;;
	esac
	;;
'--user list --no-legend') [ -z "${STUB_NO_BUS:-}" ] ;;
*) exit 1 ;;
esac
STUB
chmod +x "$fake_bin/systemctl" "$fake_bin/busctl"

run_helper() {
	SYSTEMCTL_COMMAND="$fake_bin/systemctl" \
		BUSCTL_COMMAND="${BUSCTL_COMMAND_OVERRIDE:-$fake_bin/busctl}" \
		XDG_RUNTIME_DIR="$runtime" \
		SYSTEMCTL_STUB_CALLS="$systemctl_calls" \
		BUSCTL_STUB_CALLS="$busctl_calls" \
		"$script" "$@"
}

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

reset() {
	: >"$systemctl_calls"
	: >"$busctl_calls"
	rm -f "$marker"
}

expect_systemctl() {
	printf '%s\n' "$@" >"$test_root/expected"
	[ "$(grep -E -- '--user (stop|start)' "$systemctl_calls" || true)" = "$(cat "$test_root/expected")" ] ||
		fail "unexpected systemctl stop or start calls, wanted:
$(cat "$test_root/expected")
got:
$(cat "$systemctl_calls")"
}

expect_no_change() {
	if grep -E -- '--user (stop|start)' "$systemctl_calls" >/dev/null; then
		fail "$1: DMS was stopped or started."
	fi
	[ ! -e "$marker" ] || fail "$1: left a marker."
}

# release stops DMS and leaves the marker.
reset
out=$(STUB_DMS_ACTIVE=1 run_helper release)
expect_systemctl '--user stop dms.service'
[ -e "$marker" ] || fail 'release did not leave the marker.'
case $out in
*'stopped dms.service'*) ;;
*) fail "release did not say it stopped DMS: $out" ;;
esac

# release with DMS not running does nothing.
reset
run_helper release >/dev/null
expect_no_change 'release without DMS'

# release while the session is locked does nothing and says why.
reset
out=$(STUB_DMS_ACTIVE=1 STUB_LOCKED=1 run_helper release)
expect_no_change 'release while locked'
case $out in
*'locked, DMS keeps the notification name'*) ;;
*) fail "release did not print the lock line: $out" ;;
esac
grep -qx -- '--system get-property org.freedesktop.login1 /org/freedesktop/login1/session/_32 org.freedesktop.login1.Session LockedHint' "$busctl_calls" ||
	fail 'release did not read LockedHint of the display session.'

# release in a restart loop does nothing; NRestarts 2 is still fine.
reset
out=$(STUB_DMS_ACTIVE=1 STUB_NRESTARTS=3 run_helper release)
expect_no_change 'release with NRestarts 3'
case $out in
*'restart loop'*) ;;
*) fail "release did not mention the restart loop: $out" ;;
esac
grep -qx -- '--user show quickshell-bar.service -p NRestarts --value' "$systemctl_calls" || fail 'release did not read NRestarts.'
reset
STUB_DMS_ACTIVE=1 STUB_NRESTARTS=2 run_helper release >/dev/null
expect_systemctl '--user stop dms.service'

# claim with the marker starts DMS without blocking and removes the marker.
reset
touch "$marker"
run_helper claim
expect_systemctl '--user start --no-block dms.service'
[ ! -e "$marker" ] || fail 'claim did not remove the marker.'

# claim without the marker does nothing.
reset
run_helper claim
expect_no_change 'claim without marker'

# status maps the owner of the name.
[ "$(STUB_OWNER=quickshell run_helper status)" = quickshell ] || fail 'status did not report quickshell.'
[ "$(STUB_OWNER=dms run_helper status)" = dms ] || fail 'status did not map qs with the danklinux path to dms.'
[ "$(STUB_OWNER=qs-other run_helper status)" = qs ] || fail 'status reported a qs that is not DMS as something else.'
[ "$(STUB_OWNER=other run_helper status)" = other ] || fail 'status did not name a foreign owner.'
[ "$(run_helper status)" = nobody ] || fail 'status did not report an unowned name.'
[ "$(STUB_NO_BUS=1 run_helper status)" = unknown ] || fail 'status did not degrade without a session bus.'
[ "$(BUSCTL_COMMAND_OVERRIDE="$fake_bin/no-such-busctl" run_helper status)" = unknown ] || fail 'status did not degrade without busctl.'

# release and claim never fail the bar start, even when systemctl errors.
printf '%s\n' '#!/bin/sh' 'exit 1' >"$fake_bin/broken"
chmod +x "$fake_bin/broken"
touch "$marker"
SYSTEMCTL_COMMAND="$fake_bin/broken" XDG_RUNTIME_DIR="$runtime" "$script" claim >/dev/null 2>&1 || fail 'claim failed when systemctl failed.'
SYSTEMCTL_COMMAND="$fake_bin/broken" XDG_RUNTIME_DIR="$runtime" "$script" release >/dev/null 2>&1 || fail 'release failed when systemctl failed.'

for bad in bogus '' 'release claim'; do
	bad_status=0
	# shellcheck disable=SC2086
	run_helper $bad >/dev/null 2>&1 || bad_status=$?
	[ "$bad_status" -eq 2 ] || fail "bar-notifications '$bad' exited $bad_status instead of 2."
done

printf '%s\n' 'bar-notifications tests passed.'
