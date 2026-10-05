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
apply_look_calls="$test_root/apply-look-calls"
look="$test_root/look.json"
mkdir -p "$fake_bin" "$state"
# The repository file records whichever bar is in use; the test starts from the DMS bar.
jq --indent 2 '.barConfigs[0].enabled = true | .osdVolumeEnabled = true | .osdMicMuteEnabled = true | .osdBrightnessEnabled = true' "$repo_root/dms/look.json" >"$look"
: >"$systemctl_calls"
: >"$apply_look_calls"

# The stub keeps the unit's enabled and active state as marker files.
cat >"$fake_bin/systemctl" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >>"$SYSTEMCTL_STUB_CALLS"
case "$*" in
'--user show-environment') [ -z "${SYSTEMCTL_STUB_UNREACHABLE:-}" ] ;;
'--user is-enabled quickshell-bar.service')
	if [ -e "$SYSTEMCTL_STUB_STATE/enabled" ]; then
		echo enabled
	else
		echo disabled
		exit 1
	fi
	;;
'--user is-active --quiet quickshell-bar.service') [ -e "$SYSTEMCTL_STUB_STATE/active" ] ;;
'--user is-active quickshell-bar.service')
	if [ -e "$SYSTEMCTL_STUB_STATE/active" ]; then
		echo active
	else
		echo inactive
		exit 3
	fi
	;;
'--user daemon-reload') ;;
'--user enable --now quickshell-bar.service') touch "$SYSTEMCTL_STUB_STATE/enabled" "$SYSTEMCTL_STUB_STATE/active" ;;
'--user disable --now quickshell-bar.service') rm -f "$SYSTEMCTL_STUB_STATE/enabled" "$SYSTEMCTL_STUB_STATE/active" ;;
*) exit 1 ;;
esac
STUB
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "dms-apply-look $*" >>"$APPLY_LOOK_STUB_CALLS"' >"$fake_bin/dms-apply-look"
chmod +x "$fake_bin/systemctl" "$fake_bin/dms-apply-look"

run_switch() {
	LOOK_JSON="$look" \
		SYSTEMCTL_COMMAND="$fake_bin/systemctl" \
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
	grep -E -- '--user (enable|disable|daemon-reload)' "$systemctl_calls" || true
}

reset_calls() {
	: >"$systemctl_calls"
	: >"$apply_look_calls"
}

cp "$look" "$test_root/before.json"
dry_run=$(run_switch --dry-run own)
case $dry_run in
*'would set barConfigs[0].enabled and the DMS volume, microphone and brightness OSDs to false'*'would enable and start quickshell-bar.service'*) ;;
*) fail "dry-run own did not preview the switch: $dry_run" ;;
esac
cmp -s "$look" "$test_root/before.json" || fail 'dry-run own changed look.json.'
[ -z "$(changing_calls)" ] || fail 'dry-run own enabled or disabled a unit.'
[ "$(cat "$apply_look_calls")" = 'dms-apply-look --dry-run' ] || fail 'dry-run own did not pass --dry-run to dms-apply-look.'
[ ! -e "$state/enabled" ] || fail 'dry-run own enabled the unit.'

reset_calls
run_switch own >/dev/null
[ "$(bar_flag)" = false ] || fail 'own did not set barConfigs[0].enabled to false.'
[ "$(osd_flags)" = '[false,false,false]' ] || fail 'own did not turn the DMS volume, microphone and brightness OSDs off.'
[ "$(cat "$apply_look_calls")" = 'dms-apply-look ' ] || fail 'own did not run dms-apply-look once without arguments.'
grep -qx -- '--user enable --now quickshell-bar.service' "$systemctl_calls" || fail 'own did not enable the bar unit.'
jq --indent 2 . "$look" | cmp -s - "$look" || fail 'own did not keep the two-space indentation of look.json.'

status=$(run_switch status)
case $status in
*'records the own bar'*'quickshell-bar.service is enabled and active'*) ;;
*) fail "status did not report the own bar: $status" ;;
esac

reset_calls
apply_output=$(run_switch --apply)
case $apply_output in
*'already enabled and running'*) ;;
*) fail "--apply did not report the running unit: $apply_output" ;;
esac
[ -z "$(changing_calls)" ] || fail '--apply changed the unit although it already matched.'

reset_calls
run_switch dms >/dev/null
[ "$(bar_flag)" = true ] || fail 'dms did not set barConfigs[0].enabled to true.'
[ "$(osd_flags)" = '[true,true,true]' ] || fail 'dms did not turn the DMS volume, microphone and brightness OSDs back on.'
grep -qx -- '--user disable --now quickshell-bar.service' "$systemctl_calls" || fail 'dms did not disable the bar unit.'

status=$(run_switch status)
case $status in
*'records the dms bar'*'quickshell-bar.service is disabled and inactive'*) ;;
*) fail "status did not report the DMS bar: $status" ;;
esac

reset_calls
run_switch >/dev/null
run_switch --apply >/dev/null
[ -z "$(changing_calls)" ] || fail '--apply changed the unit although it already matched.'

touch "$state/enabled" "$state/active"
reset_calls
run_switch --apply >/dev/null
grep -qx -- '--user disable --now quickshell-bar.service' "$systemctl_calls" || fail '--apply did not stop a bar unit that look.json does not want.'

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
