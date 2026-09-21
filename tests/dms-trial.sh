#!/bin/sh
# Exercise scripts/dms-trial.sh against stubbed systemctl, sudo, pacman, dms,
# and a real-noctalia stand-in, all under a temporary HOME.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
dms_trial="$repo_root/scripts/dms-trial.sh"
shim_marker='# dms-trial shim: translates Noctalia keybind commands to DMS IPC; managed by scripts/dms-trial.sh'

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT HUP INT TERM

base_path=$PATH

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

assert_contains() {
	grep -Fq -- "$2" "$1" || fail "Expected '$2' in $1"
}

assert_not_contains() {
	if grep -Fq -- "$2" "$1"; then
		fail "Did not expect '$2' in $1"
	fi
}

assert_line_order() {
	first=$(grep -Fn -- "$2" "$1" | head -n1 | cut -d: -f1)
	second=$(grep -Fn -- "$3" "$1" | head -n1 | cut -d: -f1)
	if [ -z "$first" ] || [ -z "$second" ] || [ "$first" -ge "$second" ]; then
		fail "Expected '$2' before '$3' in $1"
	fi
}

# --- stub scripts ------------------------------------------------------

write_stub_systemctl() {
	cat >"$1/systemctl" <<'EOF'
#!/bin/sh
printf '%s\n' "systemctl $*" >>"$STUB_CALLS"
state_file="$STUB_STATE/active-services"
touch "$state_file"
case "$1 $2" in
'--user is-active')
	service=$3
	if grep -Fqx "$service" "$state_file"; then
		printf 'active\n'
		exit 0
	fi
	printf 'inactive\n'
	exit 3
	;;
'--user start')
	service=$3
	grep -Fqx "$service" "$state_file" || printf '%s\n' "$service" >>"$state_file"
	exit 0
	;;
'--user stop')
	service=$3
	grep -Fvx "$service" "$state_file" >"$state_file.tmp" || :
	mv "$state_file.tmp" "$state_file"
	exit 0
	;;
*)
	exit 0
	;;
esac
EOF
	chmod +x "$1/systemctl"
}

write_stub_dms() {
	cat >"$1/dms" <<'EOF'
#!/bin/sh
printf 'dms %s\n' "$*" >>"$STUB_CALLS"
exit 0
EOF
	chmod +x "$1/dms"
}

write_stub_sudo() {
	cat >"$1/sudo" <<'EOF'
#!/bin/sh
printf 'sudo %s\n' "$*" >>"$STUB_CALLS"
exec "$@"
EOF
	chmod +x "$1/sudo"
}

write_stub_pacman() {
	cat >"$1/pacman" <<'EOF'
#!/bin/sh
printf 'pacman %s\n' "$*" >>"$STUB_CALLS"
exit 0
EOF
	chmod +x "$1/pacman"
}

write_stub_noctalia() {
	cat >"$1/noctalia" <<'EOF'
#!/bin/sh
printf 'real-noctalia %s\n' "$*" >>"$STUB_CALLS"
exit 0
EOF
	chmod +x "$1/noctalia"
}

stub_dir_full="$test_root/stub-full"
stub_dir_no_dms="$test_root/stub-no-dms"
mkdir -p "$stub_dir_full" "$stub_dir_no_dms"

write_stub_systemctl "$stub_dir_full"
write_stub_dms "$stub_dir_full"
write_stub_sudo "$stub_dir_full"
write_stub_pacman "$stub_dir_full"
write_stub_noctalia "$stub_dir_full"

write_stub_systemctl "$stub_dir_no_dms"
write_stub_sudo "$stub_dir_no_dms"
write_stub_pacman "$stub_dir_no_dms"
write_stub_noctalia "$stub_dir_no_dms"

new_home() {
	mktemp -d "$test_root/home.XXXXXX"
}

new_calls() {
	mktemp "$test_root/calls.XXXXXX"
}

new_state() {
	state=$(mktemp -d "$test_root/state.XXXXXX")
	: >"$state/active-services"
	printf '%s\n' "$state"
}

# --- scenario 1: full start -> mapping -> stop lifecycle ---------------

s1_home=$(new_home)
s1_state=$(new_state)
printf '%s\n' 'noctalia.service' >"$s1_state/active-services"
s1_calls=$(new_calls)

if HOME="$s1_home" STUB_CALLS="$s1_calls" STUB_STATE="$s1_state" \
	PATH="$stub_dir_full:$base_path" "$dms_trial" start >"$s1_home/start.out" 2>&1; then
	s1_start_status=0
else
	s1_start_status=$?
fi
[ "$s1_start_status" -eq 0 ] || fail "start failed on a clean trial: $(cat "$s1_home/start.out")"

assert_line_order "$s1_calls" 'stop noctalia.service' 'start dms.service'

s1_shim="$s1_home/.local/bin/noctalia"
[ -f "$s1_shim" ] || fail 'start did not install the shim'
[ -x "$s1_shim" ] || fail 'the installed shim is not executable'
assert_contains "$s1_shim" "$shim_marker"

s1_calls_again=$(new_calls)
if HOME="$s1_home" STUB_CALLS="$s1_calls_again" STUB_STATE="$s1_state" \
	PATH="$stub_dir_full:$base_path" "$dms_trial" start >"$s1_home/start2.out" 2>&1; then
	s1_start2_status=0
else
	s1_start2_status=$?
fi
[ "$s1_start2_status" -eq 0 ] || fail "running start twice must be a no-op: $(cat "$s1_home/start2.out")"
assert_contains "$s1_shim" "$shim_marker"

# --- mapping coverage: every msg command via the installed shim --------

mapping_file="$test_root/mappings"
cat >"$mapping_file" <<'EOF'
panel-toggle wallpaper|dms ipc call dash toggle wallpaper
panel-toggle maikel/quick-controls:panel|dms ipc call widget toggle dotfilesDashboard
settings-toggle|dms ipc call settings toggle
panel-toggle launcher|dms ipc call spotlight toggle
panel-toggle clipboard|dms ipc call clipboard toggle
session lock|dms ipc call lock lock
panel-toggle session|dms ipc call powermenu toggle
volume-up|dms ipc call audio increment 5
volume-down|dms ipc call audio decrement 5
volume-mute|dms ipc call audio mute
mic-mute|dms ipc call audio micmute
media next|dms ipc call mpris next
media previous|dms ipc call mpris previous
media play|dms ipc call mpris playPause
media stop|dms ipc call mpris pause
brightness-up|dms ipc call brightness increment 5
brightness-down|dms ipc call brightness decrement 5
EOF

mapping_calls=$(new_calls)
while IFS='|' read -r input expected; do
	[ -n "$input" ] || continue
	: >"$mapping_calls"
	# Word-splitting the mapped command is intentional here.
	# shellcheck disable=SC2086
	if HOME="$s1_home" STUB_CALLS="$mapping_calls" STUB_STATE="$s1_state" \
		PATH="$stub_dir_full:$base_path" "$s1_shim" msg $input; then
		:
	else
		fail "shim exited non-zero for 'msg $input'"
	fi
	if [ "$(cat "$mapping_calls")" != "$expected" ]; then
		fail "mapping for 'msg $input' produced '$(cat "$mapping_calls")', expected '$expected'"
	fi
done <"$mapping_file"

# --- unmapped msg command exits 1 ---------------------------------------

unmapped_calls=$(new_calls)
if HOME="$s1_home" STUB_CALLS="$unmapped_calls" STUB_STATE="$s1_state" \
	PATH="$stub_dir_full:$base_path" "$s1_shim" msg does-not-exist \
	>"$s1_home/unmapped.out" 2>"$s1_home/unmapped.err"; then
	fail 'an unmapped msg command must exit non-zero'
fi
assert_contains "$s1_home/unmapped.err" 'noctalia msg does-not-exist is not mapped for the DMS trial'

# --- a non-msg command reaches the real noctalia stand-in ---------------

passthrough_calls=$(new_calls)
if ! HOME="$s1_home" STUB_CALLS="$passthrough_calls" STUB_STATE="$s1_state" \
	PATH="$stub_dir_full:$base_path" "$s1_shim" config validate somepath \
	>"$s1_home/passthrough.out" 2>&1; then
	fail "a non-msg command must reach the real noctalia stand-in: $(cat "$s1_home/passthrough.out")"
fi
if [ "$(cat "$passthrough_calls")" != 'real-noctalia config validate somepath' ]; then
	fail "non-msg passthrough produced '$(cat "$passthrough_calls")'"
fi

# --- stop removes the shim and starts noctalia --------------------------

s1_stop_calls=$(new_calls)
if HOME="$s1_home" STUB_CALLS="$s1_stop_calls" STUB_STATE="$s1_state" \
	PATH="$stub_dir_full:$base_path" "$dms_trial" stop >"$s1_home/stop.out" 2>&1; then
	s1_stop_status=0
else
	s1_stop_status=$?
fi
[ "$s1_stop_status" -eq 0 ] || fail "stop failed: $(cat "$s1_home/stop.out")"
if [ -f "$s1_shim" ]; then
	fail 'stop did not remove the shim'
fi
assert_line_order "$s1_stop_calls" 'stop dms.service' 'start noctalia.service'

s1_stop_calls_again=$(new_calls)
if HOME="$s1_home" STUB_CALLS="$s1_stop_calls_again" STUB_STATE="$s1_state" \
	PATH="$stub_dir_full:$base_path" "$dms_trial" stop >"$s1_home/stop2.out" 2>&1; then
	s1_stop2_status=0
else
	s1_stop2_status=$?
fi
[ "$s1_stop2_status" -eq 0 ] || fail "running stop twice must be a no-op: $(cat "$s1_home/stop2.out")"

# --- scenario 2: a foreign ~/.local/bin/noctalia is left untouched ------

s2_home=$(new_home)
s2_state=$(new_state)
s2_calls=$(new_calls)
mkdir -p "$s2_home/.local/bin"
foreign_content='#!/bin/sh
echo not managed by the dms trial
'
printf '%s' "$foreign_content" >"$s2_home/.local/bin/noctalia"
chmod +x "$s2_home/.local/bin/noctalia"
foreign_before=$(cat "$s2_home/.local/bin/noctalia")

if HOME="$s2_home" STUB_CALLS="$s2_calls" STUB_STATE="$s2_state" \
	PATH="$stub_dir_full:$base_path" "$dms_trial" start >"$s2_home/start.out" 2>"$s2_home/start.err"; then
	fail 'start must refuse to overwrite a foreign ~/.local/bin/noctalia'
fi
if [ "$(cat "$s2_home/.local/bin/noctalia")" != "$foreign_before" ]; then
	fail 'start modified a foreign ~/.local/bin/noctalia'
fi
assert_not_contains "$s2_calls" 'start dms.service'

# --- scenario 3: start refuses when dms is missing from PATH ------------

s3_home=$(new_home)
s3_state=$(new_state)
s3_calls=$(new_calls)

if HOME="$s3_home" STUB_CALLS="$s3_calls" STUB_STATE="$s3_state" \
	PATH="$stub_dir_no_dms" "$dms_trial" start >"$s3_home/start.out" 2>"$s3_home/start.err"; then
	fail 'start must refuse to run when dms is missing from PATH'
fi
assert_contains "$s3_home/start.err" 'dms'
if [ -s "$s3_calls" ]; then
	fail 'start must not touch services before checking for dms'
fi
if [ -f "$s3_home/.local/bin/noctalia" ]; then
	fail 'start must not install the shim before checking for dms'
fi

# --- install is a no-op once dms is already on PATH ---------------------

s4_home=$(new_home)
s4_calls=$(new_calls)
if ! HOME="$s4_home" STUB_CALLS="$s4_calls" \
	PATH="$stub_dir_full:$base_path" "$dms_trial" install >"$s4_home/install.out" 2>&1; then
	fail "install must succeed when DMS is already installed: $(cat "$s4_home/install.out")"
fi
assert_not_contains "$s4_calls" 'pacman'

printf '%s\n' 'DMS trial helper tests passed.'
