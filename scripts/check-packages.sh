#!/bin/sh
# Compare the package manifests with the local pacman database.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
packages_dir=${PACKAGES_DIR:-$repo_root/packages}
pacman_command=${PACMAN_COMMAND:-pacman}
mark_explicit=false

usage() {
	printf 'Usage: %s [--mark-explicit]\n' "${0##*/}"
	printf '%s\n' 'Report manifest packages that are missing or installed only as a dependency.'
	printf '%s\n' '  --mark-explicit  mark dependency-only manifest packages as explicitly installed'
}

for arg in "$@"; do
	case $arg in
	--mark-explicit) mark_explicit=true ;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
done

if ! command -v "$pacman_command" >/dev/null 2>&1; then
	printf 'Required command is missing: %s\n' "$pacman_command" >&2
	exit 1
fi

list_packages() {
	sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$@" | grep -v '^$'
}

missing=
dependency_only=
for package in $(list_packages "$packages_dir/pacman.txt" "$packages_dir/aur.txt"); do
	reason=$(LC_ALL=C "$pacman_command" -Qi -- "$package" 2>/dev/null |
		awk -F': *' '/^Install Reason/ { print $2; exit }')
	case $reason in
	'') missing="$missing $package" ;;
	'Explicitly installed') ;;
	*) dependency_only="$dependency_only $package" ;;
	esac
done

status=0
if [ -n "$missing" ]; then
	printf '%s\n' 'Manifest packages not installed on this machine:'
	for package in $missing; do
		printf '  %s\n' "$package"
	done
	status=1
fi

if [ -n "$dependency_only" ]; then
	if [ "$mark_explicit" = true ]; then
		# The list is deliberately word-split into separate package names.
		# shellcheck disable=SC2086
		if [ "$(id -u)" -eq 0 ]; then
			"$pacman_command" -D --asexplicit $dependency_only
		else
			if ! command -v sudo >/dev/null 2>&1; then
				printf '%s\n' 'sudo is required to change install reasons.' >&2
				exit 1
			fi
			sudo "$pacman_command" -D --asexplicit $dependency_only
		fi
	else
		printf '%s\n' 'Manifest packages installed only as a dependency (orphan cleanup could remove them):'
		for package in $dependency_only; do
			printf '  %s\n' "$package"
		done
		printf '%s\n' 'Mark them explicit with: scripts/check-packages.sh --mark-explicit'
		status=1
	fi
fi

if [ "$status" -eq 0 ]; then
	printf '%s\n' 'All manifest packages are installed and explicit.'
fi
exit "$status"
