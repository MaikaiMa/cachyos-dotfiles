#!/bin/sh
# Exercise bootstrap against an isolated home without touching the live machine.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
bootstrap=$repo_root/scripts/bootstrap.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

test_home=$test_root/home
dmi_root=$test_root/dmi
rule_target=$test_root/system/70-z13-window.rules
mkdir -p "$test_home" "$dmi_root"

printf '%s\n' 'Not a Z13' >"$dmi_root/product_family"
printf '%s\n' 'OTHER' >"$dmi_root/board_name"

run_bootstrap() {
	HOME=$test_home \
		XDG_CONFIG_HOME=$test_home/.config \
		XDG_CACHE_HOME=$test_home/.cache \
		XDG_STATE_HOME=$test_home/.local/state \
		Z13_DMI_ROOT=$dmi_root \
		Z13_UDEV_RULE_TARGET=$rule_target \
		"$bootstrap" "$@"
}

run_bootstrap --dry-run --no-pager >/dev/null
if [ -e "$test_home/.config/niri/config.kdl" ]; then
	printf '%s\n' 'Bootstrap dry-run changed the isolated home.' >&2
	exit 1
fi

printf '%s\n' 'ROG Flow Z13' >"$dmi_root/product_family"
printf '%s\n' 'GZ302EA' >"$dmi_root/board_name"
z13_dry_run=$(Z13CTL_COMMAND=missing-z13ctl run_bootstrap --dry-run --no-pager)
case $z13_dry_run in
*'+ paru/yay -S --needed --noconfirm z13ctl-bin'*'+ reload udev rules and retrigger hidraw devices'*) ;;
*)
	printf '%s\n' 'Z13 bootstrap dry-run did not report its system operations.' >&2
	exit 1
	;;
esac
if [ -e "$rule_target" ]; then
	printf '%s\n' 'Z13 bootstrap dry-run installed the udev rule.' >&2
	exit 1
fi

printf '%s\n' 'Not a Z13' >"$dmi_root/product_family"
printf '%s\n' 'OTHER' >"$dmi_root/board_name"
run_bootstrap --no-pager

for path in \
	.config/niri/config.kdl \
	.config/noctalia/audio-glow.toml \
	.config/noctalia/bar.toml \
	.config/noctalia/lockscreen.toml \
	.config/noctalia/templates.toml \
	.local/share/noctalia/plugins/quick-controls/plugin.toml \
	.local/share/noctalia/plugins/quick-controls/panel.luau \
	.local/bin/focus-or-spawn \
	.local/bin/noctalia-dashboard-state \
	.local/bin/sync-noctalia-audio-glow \
	.local/bin/sync-z13-window-color; do
	if [ ! -f "$test_home/$path" ]; then
		printf 'Bootstrap did not create expected file: %s\n' "$path" >&2
		exit 1
	fi
done

for path in \
	.local/bin/focus-or-spawn \
	.local/bin/sync-noctalia-audio-glow \
	.local/bin/sync-z13-window-color; do
	if [ ! -x "$test_home/$path" ]; then
		printf 'Bootstrap did not make helper executable: %s\n' "$path" >&2
		exit 1
	fi
done

if find "$test_home" -name .keep -print -quit | grep -q .; then
	printf '%s\n' 'Bootstrap deployed a repository-only .keep file.' >&2
	exit 1
fi

second_dry_run=$(run_bootstrap --dry-run --no-pager)
if [ -n "$second_dry_run" ]; then
	printf '%s\n' 'Bootstrap is not idempotent; second dry-run produced output:' >&2
	printf '%s\n' "$second_dry_run" >&2
	exit 1
fi

printf '%s\n' 'Bootstrap isolation and idempotence tests passed.'
