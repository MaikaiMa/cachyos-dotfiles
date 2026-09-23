#!/bin/sh
# Apply this repository's chezmoi source (or preview it).
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
source_dir="$repo_root/chezmoi"
dms_command=${DMS_COMMAND:-dms}
dry_run=false

for arg in "$@"; do
	case $arg in
	--dry-run | -n) dry_run=true ;;
	esac
done

if ! command -v chezmoi >/dev/null 2>&1; then
	printf '%s\n' 'chezmoi is required; install it with pacman first.' >&2
	exit 1
fi

if "$repo_root/scripts/setup-z13-window.sh" --check; then
	if [ "$dry_run" = true ]; then
		"$repo_root/scripts/setup-z13-window.sh" --dry-run
	else
		"$repo_root/scripts/setup-z13-window.sh"
	fi
fi

chezmoi --source "$source_dir" apply "$@"

if command -v "$dms_command" >/dev/null 2>&1; then
	if [ "$dry_run" = true ]; then
		"$repo_root/scripts/dms-restore-plugins.sh" --dry-run
	elif ! "$repo_root/scripts/dms-restore-plugins.sh"; then
		printf '%s\n' 'Restoring the DMS plugins failed; run scripts/dms-restore-plugins.sh yourself.' >&2
	fi

	if [ "$dry_run" = true ]; then
		"$repo_root/scripts/dms-apply-look.sh" --dry-run
	elif ! "$repo_root/scripts/dms-apply-look.sh"; then
		printf '%s\n' 'Applying the DMS look failed; run scripts/dms-apply-look.sh yourself.' >&2
	fi
fi
