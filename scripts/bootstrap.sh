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

if ! command -v chezmoi >/dev/null 2>&1; then
	printf '%s\n' 'chezmoi is required; install it with pacman first.' >&2
	exit 1
fi

chezmoi init --source "$source_dir"
exec chezmoi apply "$@"
