#!/bin/sh
# Exercise system-update against fake paru, checkupdates, flatpak, and pacdiff.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_system-update
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

fake_bin=$test_dir/bin
calls=$test_dir/calls
mkdir -p "$fake_bin"

# Variables in these strings expand when the generated fakes run.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "paru $*" >>"$FAKE_CALLS"' \
	'case $1 in' \
	'-Qua) [ -n "${FAKE_AUR:-}" ] || exit 1; printf "%s\n" "$FAKE_AUR" ;;' \
	'-Syu) exit "${FAKE_SYU_STATUS:-0}" ;;' \
	'esac' >"$fake_bin/paru-test"
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "checkupdates" >>"$FAKE_CALLS"' \
	'[ -n "${FAKE_REPO:-}" ] || exit 2' \
	'printf "%s\n" "$FAKE_REPO"' >"$fake_bin/checkupdates-test"
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "flatpak $*" >>"$FAKE_CALLS"' >"$fake_bin/flatpak-test"
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'printf "%s\n" "pacdiff $*" >>"$FAKE_CALLS"' \
	'[ -n "${FAKE_PACNEW:-}" ] || exit 0' \
	'printf "%s\n" "$FAKE_PACNEW"' >"$fake_bin/pacdiff-test"
chmod +x "$fake_bin"/*
paru_conf=$test_dir/paru.conf
printf '%s\n' '[options]' 'NewsOnUpgrade' >"$paru_conf"
state_dir=$test_dir/state
report=$state_dir/last-report.md
newline='
'

run_update() {
	: >"$calls"
	PATH=$fake_bin:$PATH \
		PARU_COMMAND=paru-test \
		CHECKUPDATES_COMMAND=checkupdates-test \
		FLATPAK_COMMAND=flatpak-test \
		PACDIFF_COMMAND=pacdiff-test \
		PARU_CONF=${PARU_CONF_OVERRIDE:-$paru_conf} \
		SYSTEM_UPDATE_STATE_DIR=$state_dir \
		FAKE_CALLS=$calls \
		"$helper" "$@"
}

output=$(
	FAKE_REPO=$(printf '%s\n' 'linux-cachyos 7.2.8-1 -> 7.2.9-1' 'fish 4.1.0-1 -> 4.1.1-1' 'mesa 25.3.1-1 -> 25.3.2-1') \
	FAKE_AUR=$(printf '%s\n' 'greetd-dms-greeter-bin 1.6.1-1 -> 1.6.2-1') \
	FAKE_PACNEW=$(printf '%s\n' '/etc/pacman.conf.pacnew' '/etc/pacman.d/mirrorlist.pacnew') \
		run_update </dev/null
)
[ "$(cat "$calls")" = "$(printf '%s\n' checkupdates 'paru -Qua' 'paru -Syu' 'flatpak update' 'pacdiff -o')" ] ||
	fail "Unexpected command sequence: $(cat "$calls")"
case $output in
*'4 package(s)'*) ;;
*) fail "The pending count is wrong: $output" ;;
esac
case $output in
*'/etc/pacman.conf.pacnew'*'setup-sessions.sh'*) ;;
*) fail "pacman.conf.pacnew must point at setup-sessions.sh: $output" ;;
esac
case $output in
*'setup-greetd.sh'*) ;;
*) fail "A greeter update must ask for the greeter sync: $output" ;;
esac
case $output in
*'Reboot soon'*'linux-cachyos'*'mesa'*) ;;
*) fail "Kernel and Mesa updates must ask for a reboot: $output" ;;
esac
case $output in
*'  fish'*) fail "fish must not be listed as a reboot reason: $output" ;;
esac
case $output in
*'== Fragile packages =='*'  linux-cachyos 7.2.8-1 -> 7.2.9-1'*'== Repositories and AUR =='*) ;;
*) fail "The fragile list must show linux-cachyos with its version jump: $output" ;;
esac
fragile_section=${output#*== Fragile packages ==}
fragile_section=${fragile_section%%== Repositories and AUR ==*}
case $fragile_section in
*fish*) fail "fish must not be listed as fragile: $output" ;;
esac
case $output in
*'Continue with the upgrade?'*) fail "Without a terminal on stdin the run must not ask: $output" ;;
esac
[ -f "$report" ] || fail 'The run must write a report.'
report_text=$(cat "$report")
for expected in '## Arch news' 'archlinux.org/news' '## Fragile packages' '- linux-cachyos 7.2.8-1 -> 7.2.9-1' '### /etc/pacman.conf.pacnew' '## For an agent'; do
	case $report_text in
	*"$expected"*) ;;
	*) fail "The report lacks $expected: $report_text" ;;
	esac
done
case $output in
*"Report written to $report."*'Hand the report to an agent with:'*"Read $report and follow its"*) ;;
*) fail "The run must point at the report and the agent prompt: $output" ;;
esac

output=$(run_update 2>&1)
case $output in
*'Nothing pending'*'No .pacnew files and nothing that needs a reboot.'*) ;;
*) fail "An idle run must say so: $output" ;;
esac
case $output in
*'Hand the report to an agent'*) fail "An idle run must not suggest an agent hand-off: $output" ;;
esac
case $(cat "$report") in
*"## Fragile packages$newline${newline}None."*) ;;
*) fail "An idle report must list no fragile packages: $(cat "$report")" ;;
esac
case $output in
*'NewsOnUpgrade in '*) ;;
*) fail "The run must say that paru prints the news: $output" ;;
esac

printf '%s\n' '[options]' '#NewsOnUpgrade' >"$test_dir/paru-off.conf"
output=$(PARU_CONF_OVERRIDE=$test_dir/paru-off.conf run_update 2>&1)
case $output in
*'NewsOnUpgrade is off'*'Nothing pending'*) ;;
*) fail "A paru configuration without NewsOnUpgrade must warn and continue: $output" ;;
esac

if FAKE_SYU_STATUS=3 run_update >/dev/null 2>&1; then
	fail 'A failed paru -Syu must fail the run.'
fi
case $(cat "$calls") in
*flatpak* | *pacdiff*) fail 'After a failed paru -Syu nothing else may run.' ;;
esac

run_update --yes </dev/null >/dev/null || fail '--yes must be accepted.'

mkdir -p "$test_dir/etc"
printf '%s\n' 'setting = old' >"$test_dir/etc/foo.conf"
printf '%s\n' 'setting = new' >"$test_dir/etc/foo.conf.pacnew"
FAKE_PACNEW=$test_dir/etc/foo.conf.pacnew run_update >/dev/null
case $(cat "$report") in
*"### $test_dir/etc/foo.conf.pacnew"*'```diff'*'+setting = new'*'```'*) ;;
*) fail "A readable .pacnew must get a diff block: $(cat "$report")" ;;
esac

run_update --help >/dev/null || fail '--help must succeed.'
if run_update --bogus >/dev/null 2>&1; then
	fail 'Unknown options must be rejected.'
fi

printf '%s\n' 'system-update tests passed.'
