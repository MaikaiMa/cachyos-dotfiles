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
untracked_required=false

for tool in chezmoi fish git grep niri noctalia shellcheck shfmt; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Missing required validation tool: %s\n' "$tool" >&2
		exit 1
	fi
done

require_files() {
	for path in "$@"; do
		if [ ! -f "$path" ]; then
			printf 'Missing required file: %s\n' "$path" >&2
			exit 1
		fi
		if ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
			printf 'Required file is not tracked by Git yet: %s\n' "$path" >&2
			untracked_required=true
		fi
	done
}

require_files \
	AGENTS.md \
	CLAUDE.md \
	README.md \
	packages/pacman.txt \
	packages/aur.txt \
	packages/flatpak.txt

require_files \
	chezmoi/.chezmoiignore \
	chezmoi/dot_config/chezmoi/chezmoi.toml.tmpl \
	chezmoi/dot_config/systemd/user/default.target.wants/symlink_protonmail-bridge.service \
	chezmoi/dot_config/systemd/user/noctalia.service \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_noctalia.service \
	chezmoi/dot_config/niri/config.kdl \
	chezmoi/dot_config/niri/cfg/*.kdl \
	chezmoi/dot_config/noctalia/config.toml \
	chezmoi/dot_config/noctalia/bar.toml \
	chezmoi/dot_config/noctalia/audio-glow.toml \
	chezmoi/dot_config/noctalia/lockscreen.toml \
	chezmoi/dot_config/noctalia/templates.toml \
	chezmoi/dot_config/noctalia/templates/z13-window-color \
	chezmoi/dot_local/private_share/noctalia/plugins/quick-controls/plugin.toml \
	chezmoi/dot_local/private_share/noctalia/plugins/quick-controls/panel.luau \
	chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_noctalia-dashboard-state \
	chezmoi/dot_local/bin/executable_sync-noctalia-audio-glow \
	chezmoi/dot_local/bin/executable_sync-z13-window-color \
	chezmoi/dot_config/fish/conf.d/dotfiles.fish \
	chezmoi/dot_config/fish/functions/noctalia-reset.fish \
	chezmoi/dot_config/alacritty/alacritty.toml \
	chezmoi/dot_config/zed/settings.json \
	chezmoi/dot_config/mimeapps.list \
	chezmoi/dot_gitconfig \
	chezmoi/dot_config/environment.d/10-ssh-agent.conf \
	chezmoi/private_dot_ssh/private_config \
	chezmoi/dot_config/git/allowed_signers

require_files \
	docs/adr/README.md \
	docs/adr/ADR-0001-use-chezmoi-for-dotfile-management.md \
	docs/adr/ADR-0002-use-noctalia-for-dynamic-niri-colors.md \
	docs/adr/ADR-0003-reproducible-bilingual-spelling.md \
	docs/adr/ADR-0004-sync-z13-window-color-with-noctalia.md \
	docs/adr/ADR-0005-layer-noctalia-audio-glow-behind-bar.md \
	docs/adr/ADR-0006-use-a-noctalia-dashboard-plugin.md \
	docs/adr/ADR-0007-start-noctalia-as-a-systemd-user-service.md \
	docs/adr/ADR-0008-manage-application-configuration-selectively.md \
	docs/adr/ADR-0009-scope-package-manifests-to-the-cachyos-profile.md \
	docs/adr/ADR-0010-adopt-hylki-as-mail-client-via-flatpak.md \
	docs/adr/ADR-0011-declare-noctalia-plugins-and-show-updates-in-the-bar.md \
	docs/adr/ADR-0012-use-gnome-keyring-and-1password-for-secrets.md \
	docs/adr/ADR-0013-replace-noctalia-with-dms-and-quickshell-surfaces.md \
	docs/adr/ADR-0014-replace-sddm-with-greetd-and-the-quickshell-greeter.md \
	docs/mail.md \
	docs/secrets.md \
	docs/noctalia-lockscreen.md \
	docs/noctalia-quick-controls.md \
	docs/maintenance.md \
	docs/desktop-migration.md \
	docs/dms.md \
	dms/look.json \
	scripts/bootstrap.sh \
	scripts/check-packages.sh \
	scripts/setup-z13-window.sh \
	scripts/dms-trial.sh \
	scripts/dms-apply-look.sh \
	system/udev/70-z13-window.rules \
	tests/bootstrap.sh \
	tests/check-packages.sh \
	tests/fish-docs.sh \
	tests/focus-or-spawn.sh \
	tests/setup-z13-window.sh \
	tests/noctalia-audio-glow.sh \
	tests/sync-z13-window-color.sh \
	tests/dms-trial.sh \
	tests/validate.fish

require_files \
	chezmoi/dot_config/DankMaterialShell/plugins/dotfilesApps/plugin.json \
	chezmoi/dot_config/DankMaterialShell/plugins/dotfilesApps/DotfilesApps.qml

for adr in docs/adr/ADR-*.md; do
	adr_name=${adr##*/}
	if ! grep -Fq "($adr_name)" docs/adr/README.md; then
		printf 'ADR is missing from docs/adr/README.md: %s\n' "$adr_name" >&2
		exit 1
	fi
done

if grep -R -n -F '/home/maikel' README.md docs; then
	printf '%s\n' 'Shareable documentation contains a hard-coded home path.' >&2
	exit 1
fi

for config in chezmoi/dot_config/niri/cfg/*.kdl; do
	niri validate --config "$config"
done

niri validate --config chezmoi/dot_config/niri/config.kdl
noctalia config validate chezmoi/dot_config/noctalia
noctalia plugins lint chezmoi/dot_local/private_share/noctalia/plugins/quick-controls
shellcheck scripts/*.sh tests/*.sh
fish -n tests/*.fish chezmoi/dot_config/fish/conf.d/*.fish chezmoi/dot_config/fish/functions/*.fish
tests/fish-docs.sh

shellcheck chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_noctalia-dashboard-state \
	chezmoi/dot_local/bin/executable_sync-noctalia-audio-glow \
	chezmoi/dot_local/bin/executable_sync-z13-window-color

shfmt -d scripts/*.sh tests/*.sh \
	chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_noctalia-dashboard-state \
	chezmoi/dot_local/bin/executable_sync-noctalia-audio-glow \
	chezmoi/dot_local/bin/executable_sync-z13-window-color

chezmoi --source chezmoi execute-template \
	<chezmoi/dot_config/chezmoi/chezmoi.toml.tmpl >/dev/null

tests/check-packages.sh
tests/focus-or-spawn.sh
tests/noctalia-audio-glow.sh
tests/setup-z13-window.sh
tests/sync-z13-window-color.sh
tests/dms-trial.sh
tests/bootstrap.sh

if [ "$untracked_required" = true ]; then
	printf '%s\n' 'Validation used untracked required files; add them before committing.' >&2
fi

printf '%s\n' 'Repository validation passed.'
