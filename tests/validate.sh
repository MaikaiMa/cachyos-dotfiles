#!/bin/sh
# Validate the repository's structural and shell-script conventions.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
cd "$repo_root"

require_files() {
	for path in "$@"; do
		if [ ! -f "$path" ]; then
			printf 'Missing required file: %s\n' "$path" >&2
			exit 1
		fi
	done
}

require_files \
	AGENTS.md \
	README.md \
	packages/pacman.txt \
	packages/aur.txt

require_files \
	chezmoi/.chezmoiignore \
	chezmoi/dot_config/niri/config.kdl \
	chezmoi/dot_config/niri/cfg/*.kdl \
	chezmoi/dot_config/noctalia/templates.toml \
	chezmoi/dot_config/noctalia/templates/z13-window-color \
	chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_configure-chatgpt-spelling \
	chezmoi/dot_local/bin/executable_sync-z13-window-color

require_files \
	docs/adr/README.md \
	docs/adr/ADR-0001-use-chezmoi-for-dotfile-management.md \
	docs/adr/ADR-0002-use-noctalia-for-dynamic-niri-colors.md \
	docs/adr/ADR-0004-sync-z13-window-color-with-noctalia.md \
	scripts/bootstrap.sh \
	scripts/setup-z13-window.sh \
	system/udev/70-z13-window.rules \
	tests/focus-or-spawn.sh \
	tests/validate.fish

for tool in niri shellcheck shfmt; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Missing required validation tool: %s\n' "$tool" >&2
		exit 1
	fi
done

for config in chezmoi/dot_config/niri/cfg/*.kdl; do
	niri validate --config "$config"
done

niri validate --config chezmoi/dot_config/niri/config.kdl
shellcheck scripts/*.sh tests/*.sh

shellcheck chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_configure-chatgpt-spelling \
	chezmoi/dot_local/bin/executable_sync-z13-window-color

shfmt -d scripts/*.sh tests/*.sh \
	chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_configure-chatgpt-spelling \
	chezmoi/dot_local/bin/executable_sync-z13-window-color

tests/focus-or-spawn.sh
tests/setup-z13-window.sh
tests/sync-z13-window-color.sh

printf '%s\n' 'Repository validation passed.'
