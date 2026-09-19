#!/bin/sh
# Initialise this repository as the chezmoi source and apply it (or preview it).
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
source_dir="$repo_root/chezmoi"
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

chezmoi init --source "$source_dir"

z13_target=false
if "$repo_root/scripts/setup-z13-window.sh" --check; then
	z13_target=true
	if [ "$dry_run" = true ]; then
		"$repo_root/scripts/setup-z13-window.sh" --dry-run
	else
		"$repo_root/scripts/setup-z13-window.sh"
	fi
fi

chezmoi apply "$@"

if [ "$z13_target" = true ] && [ "$dry_run" = false ]; then
	if command -v noctalia >/dev/null 2>&1; then
		if ! noctalia msg templates-apply; then
			printf '%s\n' 'Noctalia is not running; it will apply the Z13 template on its next start.' >&2
		fi
	else
		printf '%s\n' 'Noctalia is not installed; Z13 color syncing will start when it becomes available.' >&2
	fi
fi
