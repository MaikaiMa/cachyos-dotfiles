#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/scripts/setup-z13-window.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

dmi_root="$test_root/dmi"
fake_bin="$test_root/bin"
rule_target="$test_root/etc/udev/rules.d/70-z13-window.rules"
calls="$test_root/calls"
mkdir -p "$dmi_root" "$fake_bin"

printf '%s\n' 'Not a Z13' >"$dmi_root/product_family"
printf '%s\n' 'OTHER' >"$dmi_root/board_name"
if Z13_DMI_ROOT="$dmi_root" "$script" --check; then
	printf '%s\n' 'Non-Z13 hardware must not pass the setup check.' >&2
	exit 1
fi

printf '%s\n' 'ROG Flow Z13' >"$dmi_root/product_family"
printf '%s\n' 'GZ302EA' >"$dmi_root/board_name"
Z13_DMI_ROOT="$dmi_root" "$script" --check

# The test doubles expand their arguments when they run, not here.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'exec "$@"' >"$fake_bin/sudo"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'printf "%s\n" "$*" >> "$Z13_SETUP_CALLS"' >"$fake_bin/udevadm"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$fake_bin/z13ctl"
chmod +x "$fake_bin/sudo" "$fake_bin/udevadm" "$fake_bin/z13ctl"

PATH="$fake_bin:$PATH" \
	Z13_DMI_ROOT="$dmi_root" \
	Z13_UDEV_RULE_TARGET="$rule_target" \
	Z13_SETUP_CALLS="$calls" \
	"$script"

cmp "$repo_root/system/udev/70-z13-window.rules" "$rule_target"
if [ "$(wc -l <"$calls")" -ne 3 ]; then
	printf '%s\n' 'Expected udev reload, trigger, and settle calls.' >&2
	exit 1
fi

printf '%s\n' 'Z13 setup tests passed.'
