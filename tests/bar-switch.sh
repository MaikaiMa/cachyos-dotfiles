#!/bin/sh
# Exercise bar-switch against a copy of look.json with a stateful stub systemctl.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/scripts/bar-switch.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin="$test_root/bin"
state="$test_root/state"
systemctl_calls="$test_root/systemctl-calls"
busctl_calls="$test_root/busctl-calls"
apply_look_calls="$test_root/apply-look-calls"
look="$test_root/look.json"
mkdir -p "$fake_bin" "$state"
# The repository file records whichever bar is in use; the test starts from the DMS bar.
jq --indent 2 '.barConfigs[0].enabled = true | .osdVolumeEnabled = true | .osdMicMuteEnabled = true | .osdBrightnessEnabled = true' "$repo_root/dms/look.json" >"$look"
: >"$systemctl_calls"
: >"$apply_look_calls"

# The stub keeps both units' enabled and active state and the owner of the
# notification name as marker files. Names are claimed first come, first served,
# like on the session bus: a unit that starts while the other owns the name gets none.
# The dms.service drop-in has PartOf=quickshell-bar.service, so a stop or restart
# of the bar also stops or restarts DMS; the stub models that and records it in
# the propagated file. It does not model Before= ordering beyond what the
# sequence needs: on a bar restart DMS goes down first and comes up after the bar
# holds the name. A crash restart (Restart=on-failure) is not modelled.
cat >"$fake_bin/systemctl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$SYSTEMCTL_STUB_CALLS"
s=$SYSTEMCTL_STUB_STATE
claim() { [ -e "$s/owner" ] || printf '%s\n' "$1" >"$s/owner"; }
release() { [ "$(cat "$s/owner" 2>/dev/null)" != "$1" ] || rm -f "$s/owner"; }
case "$*" in
'--user show-environment') [ -z "${SYSTEMCTL_STUB_UNREACHABLE:-}" ] ;;
'--user is-enabled quickshell-bar.service')
	if [ -e "$s/enabled" ]; then
		echo enabled
	else
		echo disabled
		exit 1
	fi
	;;
'--user is-active --quiet quickshell-bar.service') [ -e "$s/active" ] ;;
'--user is-active --quiet dms.service') [ -e "$s/dms-active" ] ;;
'--user is-active quickshell-bar.service')
	if [ -e "$s/active" ]; then
		echo active
	else
		echo inactive
		exit 3
	fi
	;;
'--user daemon-reload') ;;
'--user enable quickshell-bar.service') touch "$s/enabled" ;;
'--user restart quickshell-bar.service')
	dms_was_active=
	[ ! -e "$s/dms-active" ] || dms_was_active=1
	if [ -n "$dms_was_active" ]; then
		rm -f "$s/dms-active"
		release dms
		echo restart >>"$s/propagated"
	fi
	release quickshell
	touch "$s/active"
	claim quickshell
	if [ -n "$dms_was_active" ]; then
		touch "$s/dms-active"
		claim dms
	fi
	;;
'--user disable --now quickshell-bar.service')
	rm -f "$s/enabled" "$s/active"
	release quickshell
	if [ -e "$s/dms-active" ]; then
		rm -f "$s/dms-active"
		release dms
		echo stop >>"$s/propagated"
	fi
	;;
'--user stop dms.service')
	rm -f "$s/dms-active"
	release dms
	;;
'--user start dms.service')
	touch "$s/dms-active"
	claim dms
	;;
'--user restart dms.service')
	release dms
	touch "$s/dms-active"
	claim dms
	;;
*) exit 1 ;;
esac
STUB
cat >"$fake_bin/busctl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$BUSCTL_STUB_CALLS"
case "$*" in
'--user status org.freedesktop.Notifications')
	[ -e "$BUSCTL_STUB_STATE/owner" ] || exit 1
	# DMS is Quickshell too: its process is qs, started with the danklinux runtime path.
	case $(cat "$BUSCTL_STUB_STATE/owner") in
	quickshell) printf 'PID=4242\nComm=quickshell\nCommandLine=quickshell -c bar -n\n' ;;
	dms) printf 'PID=4243\nComm=qs\nCommandLine=qs -p /run/user/1000/danklinux-shell/0123abcd\n' ;;
	qs-other) printf 'PID=4244\nComm=qs\nCommandLine=qs -c something-else\n' ;;
	*) printf 'PID=4245\nComm=%s\nCommandLine=%s --run\n' "$(cat "$BUSCTL_STUB_STATE/owner")" "$(cat "$BUSCTL_STUB_STATE/owner")" ;;
	esac
	;;
'--user list --no-legend') [ -z "${BUSCTL_STUB_NO_BUS:-}" ] ;;
*) exit 1 ;;
esac
STUB
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "dms-apply-look $*" >>"$APPLY_LOOK_STUB_CALLS"' >"$fake_bin/dms-apply-look"
chmod +x "$fake_bin/systemctl" "$fake_bin/busctl" "$fake_bin/dms-apply-look"

run_switch() {
	LOOK_JSON="$look" \
		SYSTEMCTL_COMMAND="$fake_bin/systemctl" \
		BUSCTL_COMMAND="${BUSCTL_COMMAND_OVERRIDE:-$fake_bin/busctl}" \
		BUSCTL_STUB_CALLS="$busctl_calls" \
		BUSCTL_STUB_STATE="$state" \
		DMS_APPLY_LOOK_COMMAND="$fake_bin/dms-apply-look" \
		SYSTEMCTL_STUB_CALLS="$systemctl_calls" \
		SYSTEMCTL_STUB_STATE="$state" \
		APPLY_LOOK_STUB_CALLS="$apply_look_calls" \
		"$script" "$@"
}

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

bar_flag() {
	jq -c '.barConfigs[0].enabled' "$look"
}

# The DMS volume, microphone and brightness OSDs follow the DMS bar.
osd_flags() {
	jq -c '[.osdVolumeEnabled, .osdMicMuteEnabled, .osdBrightnessEnabled]' "$look"
}

changing_calls() {
	grep -E -- '--user (enable|disable|daemon-reload|stop|start|restart)' "$systemctl_calls" || true
}

reset_calls() {
	: >"$systemctl_calls"
	: >"$apply_look_calls"
}

expect_calls() {
	printf '%s\n' "$@" >"$test_root/expected-calls"
	[ "$(changing_calls)" = "$(cat "$test_root/expected-calls")" ] || fail "unexpected systemctl calls, wanted:
$(cat "$test_root/expected-calls")
got:
$(changing_calls)"
}

owner() {
	cat "$state/owner" 2>/dev/null || echo nobody
}

# A normal DMS session: DMS runs and owns the notification name, the bar is off.
touch "$state/dms-active"
echo dms >"$state/owner"

cp "$look" "$test_root/before.json"
dry_run=$(run_switch --dry-run own)
case $dry_run in
*'would set barConfigs[0].enabled and the DMS volume, microphone and brightness OSDs to false'*'would enable quickshell-bar.service, stop dms.service, restart quickshell-bar.service, then start dms.service'*) ;;
*) fail "dry-run own did not preview the switch: $dry_run" ;;
esac
cmp -s "$look" "$test_root/before.json" || fail 'dry-run own changed look.json.'
[ -z "$(changing_calls)" ] || fail 'dry-run own enabled, stopped or started a unit.'
[ "$(cat "$apply_look_calls")" = 'dms-apply-look --dry-run' ] || fail 'dry-run own did not pass --dry-run to dms-apply-look.'
[ ! -e "$state/enabled" ] || fail 'dry-run own enabled the unit.'

reset_calls
run_switch own >/dev/null
[ "$(bar_flag)" = false ] || fail 'own did not set barConfigs[0].enabled to false.'
[ "$(osd_flags)" = '[false,false,false]' ] || fail 'own did not turn the DMS volume, microphone and brightness OSDs off.'
[ "$(cat "$apply_look_calls")" = 'dms-apply-look ' ] || fail 'own did not run dms-apply-look once without arguments.'
expect_calls '--user daemon-reload' \
	'--user enable quickshell-bar.service' \
	'--user stop dms.service' \
	'--user restart quickshell-bar.service' \
	'--user start dms.service'
[ "$(owner)" = quickshell ] || fail "own left the notification name with $(owner)."
[ -e "$state/dms-active" ] || fail 'own left DMS stopped.'
jq --indent 2 . "$look" | cmp -s - "$look" || fail 'own did not keep the two-space indentation of look.json.'

status=$(run_switch status)
case $status in
*'records the own bar'*'quickshell-bar.service is enabled and active'*'org.freedesktop.Notifications is held by quickshell'*) ;;
*) fail "status did not report the own bar: $status" ;;
esac

reset_calls
own_again=$(run_switch own)
case $own_again in
*'already enabled and running and owns the notification name'*) ;;
*) fail "own did not report the settled state: $own_again" ;;
esac
[ -z "$(changing_calls)" ] || fail 'own touched a unit although the bar owns the name and DMS runs.'

reset_calls
apply_output=$(run_switch --apply)
case $apply_output in
*'already enabled and running'*) ;;
*) fail "--apply did not report the running unit: $apply_output" ;;
esac
[ -z "$(changing_calls)" ] || fail '--apply changed the unit although it already matched.'

# A bar that started after DMS runs without the name: own must redo the sequence.
echo dms >"$state/owner"
reset_calls
run_switch own >/dev/null
expect_calls '--user daemon-reload' \
	'--user enable quickshell-bar.service' \
	'--user stop dms.service' \
	'--user restart quickshell-bar.service' \
	'--user start dms.service'
[ "$(owner)" = quickshell ] || fail "own did not take the name back from DMS, owner is $(owner)."

# DMS stopped while the bar owns the name: the sequence also brings DMS back.
rm -f "$state/dms-active"
reset_calls
run_switch own >/dev/null
expect_calls '--user daemon-reload' \
	'--user enable quickshell-bar.service' \
	'--user stop dms.service' \
	'--user restart quickshell-bar.service' \
	'--user start dms.service'
[ -e "$state/dms-active" ] || fail 'own did not start DMS.'

# A plain bar restart restarts DMS with it and the name stays with the bar.
reset_calls
rm -f "$state/propagated"
SYSTEMCTL_STUB_CALLS="$systemctl_calls" SYSTEMCTL_STUB_STATE="$state" "$fake_bin/systemctl" --user restart quickshell-bar.service
[ "$(cat "$state/propagated")" = restart ] || fail 'a bar restart did not restart DMS (PartOf=).'
[ "$(owner)" = quickshell ] || fail "a bar restart left the name with $(owner)."

reset_calls
dry_dms=$(run_switch --dry-run dms)
case $dry_dms in
*'would disable and stop quickshell-bar.service, then restart dms.service'*) ;;
*) fail "dry-run dms did not preview the switch: $dry_dms" ;;
esac
[ -z "$(changing_calls)" ] || fail 'dry-run dms changed a unit.'

reset_calls
rm -f "$state/propagated"
run_switch dms >/dev/null
[ "$(cat "$state/propagated" 2>/dev/null)" = stop ] || fail 'dms did not stop DMS with the bar (PartOf=).'
[ "$(bar_flag)" = true ] || fail 'dms did not set barConfigs[0].enabled to true.'
[ "$(osd_flags)" = '[true,true,true]' ] || fail 'dms did not turn the DMS volume, microphone and brightness OSDs back on.'
expect_calls '--user disable --now quickshell-bar.service' \
	'--user restart dms.service'
[ "$(owner)" = dms ] || fail "dms left the notification name with $(owner)."

status=$(run_switch status)
case $status in
*'records the dms bar'*'quickshell-bar.service is disabled and inactive'*'org.freedesktop.Notifications is held by dms'*) ;;
*) fail "status did not report the DMS bar: $status" ;;
esac

reset_calls
dms_again=$(run_switch dms)
case $dms_again in
*'already disabled and stopped and DMS owns the notification name'*) ;;
*) fail "dms did not report the settled state: $dms_again" ;;
esac
[ -z "$(changing_calls)" ] || fail 'dms touched a unit although DMS owns the name and the bar is off.'

reset_calls
run_switch >/dev/null
run_switch --apply >/dev/null
[ -z "$(changing_calls)" ] || fail '--apply changed the unit although it already matched.'

touch "$state/enabled" "$state/active"
reset_calls
run_switch --apply >/dev/null
grep -qx -- '--user disable --now quickshell-bar.service' "$systemctl_calls" || fail '--apply did not stop a bar unit that look.json does not want.'

# The owner line degrades instead of failing.
rm -f "$state/owner"
case $(run_switch status) in
*'is held by nobody'*) ;;
*) fail 'status did not report an unowned notification name.' ;;
esac
case $(BUSCTL_STUB_NO_BUS=1 run_switch status) in
*'is held by unknown'*) ;;
*) fail 'status did not degrade without a session bus.' ;;
esac
case $(BUSCTL_COMMAND_OVERRIDE="$fake_bin/no-such-busctl" run_switch status) in
*'is held by unknown'*) ;;
*) fail 'status did not degrade without busctl.' ;;
esac
echo other >"$state/owner"
case $(run_switch status) in
*'is held by other'*) ;;
*) fail 'status did not name a foreign owner.' ;;
esac
echo qs-other >"$state/owner"
case $(run_switch status) in
*'is held by qs'*) ;;
*) fail 'status reported a qs that is not DMS as something else.' ;;
esac
echo dms >"$state/owner"
case $(run_switch status) in
*'is held by dms'*) ;;
*) fail 'status did not report DMS (Comm=qs, danklinux-shell) as dms.' ;;
esac

reset_calls
unreachable=$(SYSTEMCTL_STUB_UNREACHABLE=1 run_switch --apply)
case $unreachable in
*'not reachable'*) ;;
*) fail "--apply did not skip an unreachable user manager: $unreachable" ;;
esac
[ -z "$(changing_calls)" ] || fail '--apply called systemctl without a reachable user manager.'

for bad in bogus 'own dms' --force; do
	bad_status=0
	# shellcheck disable=SC2086
	run_switch $bad >/dev/null 2>&1 || bad_status=$?
	[ "$bad_status" -eq 2 ] || fail "bar-switch $bad exited $bad_status instead of 2."
done

printf '%s\n' 'bar-switch tests passed.'
