#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/chezmoi/dot_local/bin/executable_sync-z13-window-color"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

dmi_root="$test_root/dmi"
fake_bin="$test_root/bin"
calls="$test_root/calls"
mkdir -p "$dmi_root" "$fake_bin"

# The generated test double expands these variables when it runs, not here.
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' \
	'printf "%s\n" "$*" >> "$Z13CTL_CALLS"' >"$fake_bin/z13ctl"
chmod +x "$fake_bin/z13ctl"

printf '%s\n' 'Not a Z13' >"$dmi_root/product_family"
printf '%s\n' 'OTHER' >"$dmi_root/board_name"
PATH="$fake_bin:$PATH" Z13CTL_CALLS="$calls" Z13_DMI_ROOT="$dmi_root" \
	"$script" 112233
if [ -e "$calls" ]; then
	printf '%s\n' 'Non-Z13 hardware must not call z13ctl.' >&2
	exit 1
fi

printf '%s\n' 'ROG Flow Z13' >"$dmi_root/product_family"
printf '%s\n' 'GZ302EA' >"$dmi_root/board_name"
PATH="$fake_bin:$PATH" Z13CTL_CALLS="$calls" Z13_DMI_ROOT="$dmi_root" \
	"$script" a1B2c3

expected='apply --device lightbar --mode static --color a1B2c3 --brightness high'
if [ "$(cat "$calls")" != "$expected" ]; then
	printf 'Unexpected z13ctl call: %s\n' "$(cat "$calls")" >&2
	exit 1
fi

if Z13_DMI_ROOT="$dmi_root" "$script" invalid >/dev/null 2>&1; then
	printf '%s\n' 'Invalid colours must be rejected.' >&2
	exit 1
fi

printf '%s\n' 'Z13 window colour tests passed.'
