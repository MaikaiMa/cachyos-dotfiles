#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/scripts/setup-greetd.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin="$test_root/bin"
root_bin="$test_root/root-bin"
calls="$test_root/calls"
marker="$test_root/greetd-installed"
state="$test_root/unit"
config_target="$test_root/etc/greetd/config.toml"
pam_target="$test_root/etc/pam.d/greetd"
niri_config="$test_root/etc/greetd/niri/config.kdl"
settings_json="$test_root/settings.json"
path_prefix=
mkdir -p "$fake_bin" "$root_bin" "$test_root/etc/greetd/niri"

printf '%s\n' '{"greeterPamExternallyManaged": true}' >"$settings_json"
printf '%s\n' 'output "eDP-1" {}' >"$niri_config"
printf '%s\n' enabled >"$state.sddm"
printf '%s\n' disabled >"$state.greetd"
: >"$calls"

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

# The test doubles expand their arguments when they run, not here.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "sudo %s\n" "$*" >> "$GREETD_SETUP_CALLS"' 'exec "$@"' >"$fake_bin/sudo"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'if [ "$1" = -Q ]; then' '	test -e "$GREETD_TEST_MARKER"' '	exit' 'fi' \
	'printf "pacman %s\n" "$*" >> "$GREETD_SETUP_CALLS"' >"$fake_bin/pacman"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "paru %s\n" "$*" >> "$GREETD_SETUP_CALLS"' >"$fake_bin/paru"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "dms-greeter %s\n" "$*" >> "$GREETD_SETUP_CALLS"' >"$fake_bin/dms-greeter"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'unit_state="$GREETD_TEST_STATE.$2"' 'if [ "$1" = is-enabled ]; then' \
	'	if [ "$(cat "$unit_state" 2>/dev/null)" = enabled ]; then' '		printf "enabled\n"' '		exit 0' '	fi' \
	'	printf "disabled\n"' '	exit 1' 'fi' 'printf "systemctl %s\n" "$*" >> "$GREETD_SETUP_CALLS"' \
	'case "$1" in' 'enable) printf "enabled\n" > "$unit_state" ;;' 'disable) printf "disabled\n" > "$unit_state" ;;' \
	'esac' >"$fake_bin/systemctl"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "niri %s\n" "$*" >> "$GREETD_SETUP_CALLS"' >"$fake_bin/niri"
# The real chown and chmod would fail for a test that runs as the user.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "chown %s\n" "$*" >> "$GREETD_SETUP_CALLS"' >"$fake_bin/chown"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "chmod %s\n" "$*" >> "$GREETD_SETUP_CALLS"' >"$fake_bin/chmod"
printf '%s\n' '#!/bin/sh' 'printf "0\n"' >"$root_bin/id"
chmod +x "$fake_bin/sudo" "$fake_bin/pacman" "$fake_bin/paru" "$fake_bin/dms-greeter" \
	"$fake_bin/systemctl" "$fake_bin/niri" "$fake_bin/chown" "$fake_bin/chmod" "$root_bin/id"

run_setup() {
	PATH="$path_prefix$fake_bin:$PATH" \
		GREETD_CONFIG_TARGET="$config_target" \
		GREETD_PAM_TARGET="$pam_target" \
		GREETD_NIRI_CONFIG="$niri_config" \
		DMS_SETTINGS_PATH="$settings_json" \
		GREETD_SETUP_CALLS="$calls" \
		GREETD_TEST_MARKER="$marker" \
		GREETD_TEST_STATE="$state" \
		"$script" "$@"
}

count_calls() {
	grep -c "$1" "$calls" || true
}

expect_no_changes() {
	if [ -s "$calls" ]; then
		fail "$1"
	fi
	if [ -e "$config_target" ] || [ -e "$pam_target" ]; then
		fail "$1"
	fi
}

expect_guard_message() {
	case $1 in
	*'greeterPamExternallyManaged is not enabled'*) ;;
	*) fail 'The settings guard must name the missing DMS setting.' ;;
	esac
}

dry_run_output=$(run_setup --dry-run)
case $dry_run_output in
*'+ sudo pacman -S --needed --noconfirm greetd acl'*) ;;
*) fail 'A dry run must report the missing greetd package.' ;;
esac
case $dry_run_output in
*"+ niri validate --config $niri_config"*) ;;
*) fail 'A dry run must report the greeter Niri validation.' ;;
esac
expect_no_changes 'A dry run must not change anything.'

switch_dry_run_output=$(run_setup --dry-run --switch)
case $switch_dry_run_output in
*'+ sudo systemctl disable sddm'*) ;;
*) fail 'A --switch dry run must report disabling sddm.' ;;
esac
case $switch_dry_run_output in
*'+ sudo systemctl enable greetd'*) ;;
*) fail 'A --switch dry run must report enabling greetd.' ;;
esac
expect_no_changes 'A --switch dry run must not change anything.'

usage_status=0
run_setup --nope >/dev/null 2>&1 || usage_status=$?
if [ "$usage_status" -ne 2 ]; then
	fail 'An unknown argument must exit 2.'
fi

: >"$marker"

printf '%s\n' '{}' >"$settings_json"
if guard_dry_run_output=$(run_setup --dry-run 2>&1); then
	fail 'A dry run must refuse to plan without greeterPamExternallyManaged.'
fi
expect_guard_message "$guard_dry_run_output"
expect_no_changes 'The settings guard must stop a dry run before any output.'

if guard_output=$(run_setup 2>&1); then
	fail 'Setup must refuse to run without greeterPamExternallyManaged.'
fi
expect_guard_message "$guard_output"
expect_no_changes 'The settings guard must stop setup before any call.'
printf '%s\n' '{"greeterPamExternallyManaged": true}' >"$settings_json"

: >"$calls"
run_setup >/dev/null

cmp "$repo_root/system/greetd/config.toml" "$config_target"
cmp "$repo_root/system/pam.d/greetd" "$pam_target"
if [ "$(count_calls '^sudo install ')" -ne 2 ]; then
	fail 'The first run must install both greetd files.'
fi
grep -q '^dms-greeter sync --yes$' "$calls" || fail 'The first run must sync the greeter.'
grep -q "^niri validate --config $niri_config\$" "$calls" || fail 'The first run must validate the greeter Niri config.'
grep -q '^dms-greeter status$' "$calls" || fail 'The first run must report the greeter status.'
if [ "$(count_calls "^sudo chown root:root $config_target\$")" -ne 1 ]; then
	fail 'The first run must restore root ownership of the greetd config once.'
fi
if [ "$(count_calls "^sudo chmod 644 $config_target\$")" -ne 1 ]; then
	fail 'The first run must restore mode 644 on the greetd config once.'
fi
if grep -Eq '^systemctl (disable|enable) ' "$calls"; then
	fail 'A run without --switch must not change any service.'
fi

: >"$calls"
run_setup >/dev/null
if grep -q '^sudo install ' "$calls"; then
	fail 'Unchanged files must not be installed again.'
fi
grep -q '^dms-greeter sync --yes$' "$calls" || fail 'Every run must sync the greeter.'

: >"$calls"
run_setup --switch >/dev/null
if [ "$(count_calls '^systemctl disable sddm$')" -ne 1 ]; then
	fail 'The --switch run must disable sddm exactly once.'
fi
if [ "$(count_calls '^systemctl enable greetd$')" -ne 1 ]; then
	fail 'The --switch run must enable greetd exactly once.'
fi
disable_line=$(grep -n '^systemctl disable sddm$' "$calls" | cut -d: -f1)
enable_line=$(grep -n '^systemctl enable greetd$' "$calls" | cut -d: -f1)
if [ "$disable_line" -gt "$enable_line" ]; then
	fail 'sddm must be disabled before greetd is enabled.'
fi

: >"$calls"
run_setup --switch >/dev/null
if grep -Eq '^systemctl (disable|enable) ' "$calls"; then
	fail 'A repeated --switch run must leave the services alone.'
fi

: >"$calls"
ownership_dry_run_output=$(run_setup --dry-run)
case $ownership_dry_run_output in
*"+ sudo chown root:root $config_target"*) ;;
*) fail 'A dry run must report a wrongly owned greetd config.' ;;
esac
case $ownership_dry_run_output in
*"+ sudo chmod 644 $config_target"*) ;;
*) fail 'A dry run must report a wrong mode on the greetd config.' ;;
esac
if [ -s "$calls" ]; then
	fail 'A dry run must not change the greetd config ownership.'
fi

path_prefix="$root_bin:"
if root_output=$(run_setup 2>&1); then
	fail 'Setup must refuse to run as root.'
fi
case $root_output in
*'as your regular user'*) ;;
*) fail 'The root refusal must explain that setup runs as the regular user.' ;;
esac
path_prefix=

printf '%s\n' 'greetd setup tests passed.'
