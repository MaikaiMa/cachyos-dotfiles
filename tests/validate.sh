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

for tool in chezmoi fish ghostty git grep jq niri nvim shellcheck shfmt; do
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
	chezmoi/.chezmoiremove \
	chezmoi/dot_config/chezmoi/chezmoi.toml.tmpl \
	chezmoi/dot_config/systemd/user/default.target.wants/symlink_protonmail-bridge.service \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_dms.service \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_app-com.mitchellh.ghostty.service \
	chezmoi/dot_config/systemd/user/default.target.wants/symlink_wallpaper-favorites.path \
	chezmoi/dot_config/systemd/user/wallpaper-favorites.service \
	chezmoi/dot_config/systemd/user/wallpaper-favorites.path \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_auto-rotate.service \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_mobi.phosh.OSK.service \
	chezmoi/dot_config/systemd/user/auto-rotate.service \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_vicinae.service \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_handy.service \
	chezmoi/dot_config/systemd/user/handy.service \
	chezmoi/dot_config/systemd/user/niri.service.wants/symlink_ollama.service \
	chezmoi/dot_config/systemd/user/ollama.service \
	chezmoi/dot_config/systemd/user/quickshell-bar.service \
	chezmoi/dot_config/quickshell/bar/shell.qml \
	chezmoi/dot_config/quickshell/bar/Colors.qml \
	chezmoi/dot_config/quickshell/bar/Theme.qml \
	chezmoi/dot_config/quickshell/bar/Motion.qml \
	chezmoi/dot_config/quickshell/bar/qmldir \
	chezmoi/dot_config/quickshell/bar/services/Shell.qml \
	chezmoi/dot_config/quickshell/bar/services/Niri.qml \
	chezmoi/dot_config/quickshell/bar/services/Battery.qml \
	chezmoi/dot_config/quickshell/bar/services/Audio.qml \
	chezmoi/dot_config/quickshell/bar/services/Brightness.qml \
	chezmoi/dot_config/quickshell/bar/services/Network.qml \
	chezmoi/dot_config/quickshell/bar/services/Bluetooth.qml \
	chezmoi/dot_config/quickshell/bar/services/Dms.qml \
	chezmoi/dot_config/quickshell/bar/services/Notifications.qml \
	chezmoi/dot_config/quickshell/bar/services/Music.qml \
	chezmoi/dot_config/quickshell/bar/services/Cava.qml \
	chezmoi/dot_config/quickshell/bar/services/Tray.qml \
	chezmoi/dot_config/quickshell/bar/services/Weather.qml \
	chezmoi/dot_config/quickshell/bar/services/System.qml \
	chezmoi/dot_config/quickshell/bar/services/Updates.qml \
	chezmoi/dot_config/quickshell/bar/services/Session.qml \
	chezmoi/dot_config/quickshell/bar/services/Tablet.qml \
	chezmoi/dot_config/quickshell/bar/services/Wallpapers.qml \
	chezmoi/dot_config/quickshell/bar/services/qmldir \
	chezmoi/dot_config/quickshell/bar/islands/LeftIsland.qml \
	chezmoi/dot_config/quickshell/bar/islands/CentreIsland.qml \
	chezmoi/dot_config/quickshell/bar/islands/RightIsland.qml \
	chezmoi/dot_config/quickshell/bar/islands/qmldir \
	chezmoi/dot_config/quickshell/bar/panels/SettingsPanel.qml \
	chezmoi/dot_config/quickshell/bar/panels/HomePanel.qml \
	chezmoi/dot_config/quickshell/bar/panels/UpdatesPanel.qml \
	chezmoi/dot_config/quickshell/bar/panels/PlayerPanel.qml \
	chezmoi/dot_config/quickshell/bar/panels/PowerPanel.qml \
	chezmoi/dot_config/quickshell/bar/panels/ThemePanel.qml \
	chezmoi/dot_config/quickshell/bar/panels/WallpaperPanel.qml \
	chezmoi/dot_config/quickshell/bar/components/Orb.qml \
	chezmoi/dot_config/quickshell/bar/components/RimLight.qml \
	chezmoi/dot_config/quickshell/bar/components/TopWave.qml \
	chezmoi/dot_config/quickshell/bar/components/Carousel.qml \
	chezmoi/dot_config/quickshell/bar/components/Osd.qml \
	chezmoi/dot_config/quickshell/bar/panels/qmldir \
	chezmoi/dot_config/quickshell/bar/components/Island.qml \
	chezmoi/dot_config/quickshell/bar/components/IslandAnimation.qml \
	chezmoi/dot_config/quickshell/bar/components/Hairline.qml \
	chezmoi/dot_config/quickshell/bar/components/Clock.qml \
	chezmoi/dot_config/quickshell/bar/components/Icon.qml \
	chezmoi/dot_config/quickshell/bar/components/Tile.qml \
	chezmoi/dot_config/quickshell/bar/components/CapsuleSlider.qml \
	chezmoi/dot_config/quickshell/bar/components/NotificationRow.qml \
	chezmoi/dot_config/quickshell/bar/components/WeatherIcon.qml \
	chezmoi/dot_config/quickshell/bar/components/BatteryIcon.qml \
	chezmoi/dot_config/quickshell/bar/components/SegmentedControl.qml \
	chezmoi/dot_config/quickshell/bar/components/TimeTile.qml \
	chezmoi/dot_config/quickshell/bar/components/WeatherTile.qml \
	chezmoi/dot_config/quickshell/bar/components/PerformanceTile.qml \
	chezmoi/dot_config/quickshell/bar/components/PowerTile.qml \
	chezmoi/dot_config/quickshell/bar/components/qmldir \
	chezmoi/dot_config/quickshell/bar/README.md \
	chezmoi/dot_config/DankMaterialShell/modify_clsettings.json \
	chezmoi/dot_config/vicinae/modify_settings.json \
	chezmoi/dot_config/vicinae/dotfiles.json \
	chezmoi/dot_config/systemd/user/mobi.phosh.OSK.service.d/niri.conf \
	chezmoi/dot_config/systemd/user/gamescope-xbindkeys.service.d/xbindkeysrc.conf \
	chezmoi/dot_config/gamescope/xbindkeysrc \
	chezmoi/dot_config/niri/config.kdl \
	chezmoi/dot_config/niri/cfg/*.kdl \
	chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_sync-z13-window-color \
	chezmoi/dot_local/bin/executable_wallpaper-favorites \
	chezmoi/dot_local/bin/executable_xwayland-scaled \
	chezmoi/dot_local/bin/executable_tablet-mode \
	chezmoi/dot_local/bin/executable_auto-rotate \
	chezmoi/dot_local/bin/executable_osk \
	chezmoi/dot_local/bin/executable_system-update \
	chezmoi/dot_config/paru/paru.conf \
	chezmoi/dot_local/share/applications/net.blip.Blip.desktop \
	chezmoi/dot_local/share/applications/dev.noctalia.Noctalia.desktop \
	chezmoi/dot_config/wallpapers/libraries \
	chezmoi/dot_config/matugen/templates/niri-backdrop \
	chezmoi/dot_config/matugen/templates/ghostty-background \
	chezmoi/dot_config/matugen/templates/zen-colors \
	chezmoi/dot_config/matugen/templates/vicinae-theme \
	chezmoi/dot_config/private_zen/dms-userChrome.css \
	chezmoi/dot_config/fish/config.fish \
	chezmoi/dot_config/fish/conf.d/dotfiles.fish \
	chezmoi/dot_config/fish/functions/dms-reset.fish \
	chezmoi/dot_config/ghostty/config.ghostty \
	chezmoi/dot_config/alacritty/alacritty.toml \
	chezmoi/dot_config/nvim/init.lua \
	chezmoi/dot_config/nvim/lazy-lock.json \
	chezmoi/dot_config/nvim/stylua.toml \
	chezmoi/dot_config/nvim/lua/config/lazy.lua \
	chezmoi/dot_config/nvim/lua/config/options.lua \
	chezmoi/dot_config/nvim/lua/config/keymaps.lua \
	chezmoi/dot_config/nvim/lua/config/autocmds.lua \
	chezmoi/dot_config/nvim/lua/plugins/colorscheme.lua \
	chezmoi/dot_config/zed/settings.json \
	chezmoi/dot_config/mimeapps.list \
	chezmoi/dot_config/xdg-terminals.list \
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
	docs/adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md \
	docs/adr/ADR-0016-mirror-nautilus-stars-into-the-dms-wallpaper-folder.md \
	docs/adr/ADR-0017-use-ghostty-as-the-terminal.md \
	docs/adr/ADR-0018-use-neovim-with-lazyvim-as-the-terminal-editor.md \
	docs/adr/ADR-0019-merge-dms-plugin-settings-as-desired-state.md \
	docs/adr/ADR-0020-use-stock-niri-with-squeekboard-and-detach-gated-rotation.md \
	docs/adr/ADR-0021-let-logind-handle-the-power-key.md \
	docs/adr/ADR-0022-add-a-steam-big-picture-session-with-gamescope-session-cachyos.md \
	docs/adr/ADR-0023-own-the-greeter-session-list-and-hand-steam-over-to-niri.md \
	docs/adr/ADR-0024-replace-dms-spotlight-with-vicinae-and-add-handy-dictation.md \
	docs/adr/ADR-0025-guard-system-updates-with-a-helper-behind-the-dms-updater.md \
	docs/adr/ADR-0026-local-first-writing-tools-with-ollama-and-claude-on-request.md \
	docs/adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md \
	docs/mail.md \
	docs/secrets.md \
	docs/maintenance.md \
	docs/desktop-migration.md \
	docs/greeter.md \
	docs/dms.md \
	docs/shell.md \
	docs/shell-design.md \
	docs/design/bar-prototype.html \
	docs/pictures.md \
	docs/terminal.md \
	docs/editor.md \
	docs/tablet.md \
	docs/gaming.md \
	docs/launcher.md \
	docs/writing.md \
	dms/look.json \
	dms/plugin_settings.json \
	dms/plugins.lock.json \
	dms/session.json \
	scripts/bootstrap.sh \
	scripts/check-packages.sh \
	scripts/setup-greetd.sh \
	scripts/setup-z13-window.sh \
	scripts/dms-apply-look.sh \
	scripts/bar-switch.sh \
	scripts/dms-restore-plugins.sh \
	scripts/dms-link-zen-theme.sh \
	scripts/setup-power-key.sh \
	scripts/setup-sessions.sh \
	scripts/build-vicinae-extensions.sh \
	system/greetd/config.toml \
	system/pam.d/greetd \
	system/local/bin/niri-session \
	system/local/bin/steam-session \
	system/wayland-sessions/niri.desktop \
	system/wayland-sessions/steam.desktop \
	system/udev/70-z13-window.rules \
	system/logind.conf.d/50-power-key.conf \
	tests/bootstrap.sh \
	tests/check-packages.sh \
	tests/dms-apply-look.sh \
	tests/bar-switch.sh \
	tests/quickshell-bar.sh \
	tests/dms-restore-plugins.sh \
	tests/dms-link-zen-theme.sh \
	tests/dms-clipboard-settings.sh \
	tests/vicinae-settings.sh \
	tests/fish-docs.sh \
	tests/focus-or-spawn.sh \
	tests/setup-greetd.sh \
	tests/setup-z13-window.sh \
	tests/sync-z13-window-color.sh \
	tests/wallpaper-favorites.sh \
	tests/xwayland-scaled.sh \
	tests/tablet-mode.sh \
	tests/auto-rotate.sh \
	tests/osk.sh \
	tests/setup-power-key.sh \
	tests/setup-sessions.sh \
	tests/system-update.sh \
	tests/build-vicinae-extensions.sh \
	tests/validate.fish

require_files \
	extensions/vicinae-writing/.gitignore \
	extensions/vicinae-writing/package.json \
	extensions/vicinae-writing/package-lock.json \
	extensions/vicinae-writing/tsconfig.json \
	extensions/vicinae-writing/assets/icon.png \
	extensions/vicinae-writing/src/writing-tools.tsx \
	extensions/vicinae-writing/src/prompts.ts \
	extensions/vicinae-writing/src/ollama.ts \
	extensions/vicinae-writing/src/claude.ts

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

validate_ghostty_config() {
	ghostty_config_home=$(mktemp -d)
	# DMS renders the dankcolors theme and the ghostty_background matugen
	# template at runtime; stubs keep validation independent of the live home.
	mkdir -p "$ghostty_config_home/ghostty/themes"
	: >"$ghostty_config_home/ghostty/themes/dankcolors"
	: >"$ghostty_config_home/ghostty/dank-background"
	ghostty_status=0
	XDG_CONFIG_HOME=$ghostty_config_home ghostty +validate-config \
		--config-file=chezmoi/dot_config/ghostty/config.ghostty || ghostty_status=$?
	rm -rf -- "$ghostty_config_home"
	if [ "$ghostty_status" -ne 0 ]; then
		printf '%s\n' 'Ghostty rejected chezmoi/dot_config/ghostty/config.ghostty.' >&2
		exit 1
	fi
}

validate_nvim_lua() {
	nvim_home=$(mktemp -d)
	cat >"$nvim_home/check.lua" <<'EOF'
local failed = false
for _, path in ipairs(arg) do
  local _, err = loadfile(path)
  if err then
    io.stderr:write(err, "\n")
    failed = true
  end
end
os.exit(failed and 1 or 0)
EOF
	nvim_status=0
	XDG_CONFIG_HOME=$nvim_home XDG_DATA_HOME=$nvim_home XDG_STATE_HOME=$nvim_home \
		XDG_CACHE_HOME=$nvim_home find chezmoi/dot_config/nvim -name '*.lua' \
		-exec nvim --clean -l "$nvim_home/check.lua" {} + || nvim_status=$?
	rm -rf -- "$nvim_home"
	if [ "$nvim_status" -ne 0 ]; then
		printf '%s\n' 'Neovim rejected a Lua file under chezmoi/dot_config/nvim.' >&2
		exit 1
	fi
}

# Validation stays offline: the TypeScript checks need the dependencies that
# scripts/build-vicinae-extensions.sh (or npm ci) installs, so they only run
# where node_modules already exists.
check_vicinae_extensions() {
	for extension in extensions/*/; do
		extension=${extension%/}
		if [ ! -x "$extension/node_modules/.bin/tsc" ] || [ ! -x "$extension/node_modules/.bin/vici" ]; then
			printf 'Skipping the type check of %s: run npm ci there first.\n' "$extension"
			continue
		fi
		if ! (cd "$extension" && node_modules/.bin/tsc --noEmit && node_modules/.bin/vici lint >/dev/null); then
			printf 'The Vicinae extension %s failed its type check or manifest lint.\n' "$extension" >&2
			exit 1
		fi
	done
}

for config in chezmoi/dot_config/niri/cfg/*.kdl; do
	niri validate --config "$config"
done

niri validate --config chezmoi/dot_config/niri/config.kdl
validate_ghostty_config
validate_nvim_lua

for catalogue in dms/*.json \
	chezmoi/dot_config/nvim/lazy-lock.json chezmoi/dot_config/vicinae/dotfiles.json \
	extensions/*/package.json extensions/*/package-lock.json extensions/*/tsconfig.json; do
	jq empty "$catalogue"
done
check_vicinae_extensions
shellcheck scripts/*.sh tests/*.sh
fish -n tests/*.fish chezmoi/dot_config/fish/config.fish chezmoi/dot_config/fish/conf.d/*.fish chezmoi/dot_config/fish/functions/*.fish
tests/fish-docs.sh

shellcheck chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_sync-z13-window-color \
	chezmoi/dot_local/bin/executable_wallpaper-favorites \
	chezmoi/dot_local/bin/executable_xwayland-scaled \
	chezmoi/dot_local/bin/executable_tablet-mode \
	chezmoi/dot_local/bin/executable_auto-rotate \
	chezmoi/dot_local/bin/executable_osk \
	chezmoi/dot_local/bin/executable_system-update \
	chezmoi/dot_config/DankMaterialShell/modify_clsettings.json \
	chezmoi/dot_config/vicinae/modify_settings.json \
	system/local/bin/niri-session \
	system/local/bin/steam-session

shfmt -d scripts/*.sh tests/*.sh \
	chezmoi/dot_local/bin/executable_focus-or-spawn \
	chezmoi/dot_local/bin/executable_sync-z13-window-color \
	chezmoi/dot_local/bin/executable_wallpaper-favorites \
	chezmoi/dot_local/bin/executable_xwayland-scaled \
	chezmoi/dot_local/bin/executable_tablet-mode \
	chezmoi/dot_local/bin/executable_auto-rotate \
	chezmoi/dot_local/bin/executable_osk \
	chezmoi/dot_local/bin/executable_system-update \
	chezmoi/dot_config/DankMaterialShell/modify_clsettings.json \
	chezmoi/dot_config/vicinae/modify_settings.json \
	system/local/bin/niri-session \
	system/local/bin/steam-session

chezmoi --source chezmoi execute-template \
	<chezmoi/dot_config/chezmoi/chezmoi.toml.tmpl >/dev/null

tests/check-packages.sh
tests/dms-apply-look.sh
tests/bar-switch.sh
tests/quickshell-bar.sh
tests/dms-restore-plugins.sh
tests/dms-link-zen-theme.sh
tests/dms-clipboard-settings.sh
tests/vicinae-settings.sh
tests/focus-or-spawn.sh
tests/setup-greetd.sh
tests/setup-z13-window.sh
tests/sync-z13-window-color.sh
tests/wallpaper-favorites.sh
tests/xwayland-scaled.sh
tests/tablet-mode.sh
tests/auto-rotate.sh
tests/osk.sh
tests/setup-power-key.sh
tests/setup-sessions.sh
tests/system-update.sh
tests/build-vicinae-extensions.sh
tests/bootstrap.sh

if [ "$untracked_required" = true ]; then
	printf '%s\n' 'Validation used untracked required files; add them before committing.' >&2
fi

printf '%s\n' 'Repository validation passed.'
