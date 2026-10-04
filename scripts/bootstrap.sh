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
vicinae_command=${VICINAE_COMMAND:-vicinae}
ollama_command=${OLLAMA_COMMAND:-ollama}
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

# Before niri's power-key handling is disabled by the applied config, so a
# short press never falls back to logind's default power-off.
if [ "$dry_run" = true ]; then
	"$repo_root/scripts/setup-power-key.sh" --dry-run
else
	"$repo_root/scripts/setup-power-key.sh"
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

if command -v "$vicinae_command" >/dev/null 2>&1; then
	if [ "$dry_run" = true ]; then
		"$repo_root/scripts/build-vicinae-extensions.sh" --dry-run ||
			printf '%s\n' 'Previewing the Vicinae extension build failed; see the message above.' >&2
	elif ! "$repo_root/scripts/build-vicinae-extensions.sh"; then
		printf '%s\n' 'Building the Vicinae extensions failed; run scripts/build-vicinae-extensions.sh yourself.' >&2
	fi
fi

# The writing model is about 16 GB, so bootstrap only reports when it is missing.
if command -v "$ollama_command" >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
	writing_model=$(jq -r '.preferences[] | select(.name == "ollamaModel") | .default' \
		"$repo_root/extensions/vicinae-writing/package.json")
	if ! installed_models=$("$ollama_command" list 2>/dev/null); then
		printf 'Ollama is not running; start ollama.service and pull %s if it is missing (docs/writing.md).\n' "$writing_model" >&2
	elif ! printf '%s\n' "$installed_models" | awk -v model="$writing_model" 'NR > 1 && $1 == model { found = 1 } END { exit !found }'; then
		printf 'The writing model is not installed; pull it with: ollama pull %s\n' "$writing_model" >&2
	fi
fi
