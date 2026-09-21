#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script=$repo_root/scripts/check-packages.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin=$test_root/bin
packages_dir=$test_root/packages
db=$test_root/db
calls=$test_root/calls
mkdir -p "$fake_bin" "$packages_dir"

# The doubles expand their variables when they run, not here.
# shellcheck disable=SC2016
printf '%s\n' \
	'#!/bin/sh' \
	'if [ "$1" = "-D" ]; then' \
	'    printf "%s\n" "$*" >> "$FAKE_PACMAN_CALLS"' \
	'    exit 0' \
	'fi' \
	'name=$3' \
	'reason=$(awk -v name="$name" '"'"'$1 == name { $1 = ""; sub(/^ /, ""); print; exit }'"'"' "$FAKE_PACMAN_DB")' \
	'[ -n "$reason" ] || exit 1' \
	'printf "Name            : %s\n" "$name"' \
	'printf "Install Reason  : %s\n" "$reason"' >"$fake_bin/pacman-test"
# shellcheck disable=SC2016
printf '%s\n' '#!/bin/sh' 'exec "$@"' >"$fake_bin/sudo"
chmod +x "$fake_bin/pacman-test" "$fake_bin/sudo"

cat >"$packages_dir/pacman.txt" <<'MANIFEST'
# Comment line
explicit-pkg # inline comment
dependency-pkg
missing-pkg
MANIFEST
printf '%s\n' 'aur-explicit' >"$packages_dir/aur.txt"
cat >"$db" <<'DB'
explicit-pkg Explicitly installed
dependency-pkg Installed as a dependency for another package
aur-explicit Explicitly installed
DB

run_check() {
	PATH="$fake_bin:$PATH" \
		PACMAN_COMMAND=pacman-test \
		PACKAGES_DIR="$packages_dir" \
		FAKE_PACMAN_DB="$db" \
		FAKE_PACMAN_CALLS="$calls" \
		"$script" "$@"
}

: >"$calls"
if output=$(run_check); then
	printf '%s\n' 'A manifest with missing packages must fail the check.' >&2
	exit 1
fi
case $output in
*'missing-pkg'*'dependency-pkg'*) ;;
*)
	printf 'Report did not list the missing and dependency-only packages:\n%s\n' "$output" >&2
	exit 1
	;;
esac
case $output in
*'explicit-pkg'* | *'aur-explicit'*)
	printf 'Report listed an explicitly installed package:\n%s\n' "$output" >&2
	exit 1
	;;
esac
if [ -s "$calls" ]; then
	printf '%s\n' 'A plain report must not change install reasons.' >&2
	exit 1
fi

run_check --mark-explicit >/dev/null 2>&1 || true
if [ "$(cat "$calls")" != '-D --asexplicit dependency-pkg' ]; then
	printf 'Unexpected pacman call: %s\n' "$(cat "$calls")" >&2
	exit 1
fi

sed -i '/^missing-pkg$/d' "$packages_dir/pacman.txt"
printf '%s\n' 'dependency-pkg Explicitly installed' >>"$db"
sed -i '/dependency for another/d' "$db"
: >"$calls"
run_check >/dev/null
if [ -s "$calls" ]; then
	printf '%s\n' 'A clean manifest must not call pacman -D.' >&2
	exit 1
fi

printf '%s\n' 'Package manifest check tests passed.'
