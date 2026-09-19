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

required_paths='AGENTS.md README.md chezmoi/.chezmoiignore chezmoi/dot_config/niri/cfg/animation.kdl chezmoi/dot_config/niri/cfg/autostart.kdl chezmoi/dot_config/niri/cfg/input.kdl chezmoi/dot_config/niri/cfg/keybinds.kdl chezmoi/dot_config/niri/cfg/layout.kdl chezmoi/dot_config/niri/cfg/misc.kdl chezmoi/dot_config/niri/cfg/rules.kdl chezmoi/dot_config/noctalia/templates.toml packages/pacman.txt packages/aur.txt docs/adr/README.md docs/adr/ADR-0001-use-chezmoi-for-dotfile-management.md docs/adr/ADR-0002-use-noctalia-for-dynamic-niri-colors.md scripts/bootstrap.sh tests/validate.fish'
for path in $required_paths; do
	if [ ! -f "$path" ]; then
		printf 'Missing required file: %s\n' "$path" >&2
		exit 1
	fi
done

for tool in niri shellcheck shfmt; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Missing required validation tool: %s\n' "$tool" >&2
		exit 1
	fi
done

niri validate --config chezmoi/dot_config/niri/cfg/animation.kdl
niri validate --config chezmoi/dot_config/niri/cfg/autostart.kdl
niri validate --config chezmoi/dot_config/niri/cfg/input.kdl
niri validate --config chezmoi/dot_config/niri/cfg/keybinds.kdl
niri validate --config chezmoi/dot_config/niri/cfg/layout.kdl
niri validate --config chezmoi/dot_config/niri/cfg/misc.kdl
niri validate --config chezmoi/dot_config/niri/cfg/rules.kdl
shellcheck scripts/*.sh tests/*.sh
shfmt -d scripts/*.sh tests/*.sh

printf '%s\n' 'Repository validation passed.'
