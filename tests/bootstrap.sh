#!/bin/sh
# Exercise bootstrap against an isolated home without touching the live machine.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
bootstrap=$repo_root/scripts/bootstrap.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

test_home=$test_root/home
dmi_root=$test_root/dmi
rule_target=$test_root/system/70-z13-window.rules
mkdir -p "$test_home" "$dmi_root"

printf '%s\n' 'Not a Z13' >"$dmi_root/product_family"
printf '%s\n' 'OTHER' >"$dmi_root/board_name"

run_bootstrap() {
	HOME=$test_home \
		XDG_CONFIG_HOME=$test_home/.config \
		XDG_CACHE_HOME=$test_home/.cache \
		XDG_STATE_HOME=$test_home/.local/state \
		Z13_DMI_ROOT=$dmi_root \
		Z13_UDEV_RULE_TARGET=$rule_target \
		DMS_COMMAND=${DMS_COMMAND:-missing-dms} \
		"$bootstrap" "$@"
}

run_bootstrap --dry-run --no-pager >/dev/null
if [ -e "$test_home/.config/niri/config.kdl" ]; then
	printf '%s\n' 'Bootstrap dry-run changed the isolated home.' >&2
	exit 1
fi

printf '%s\n' 'ROG Flow Z13' >"$dmi_root/product_family"
printf '%s\n' 'GZ302EA' >"$dmi_root/board_name"
z13_dry_run=$(Z13CTL_COMMAND=missing-z13ctl run_bootstrap --dry-run --no-pager)
case $z13_dry_run in
*'+ paru/yay -S --needed --noconfirm z13ctl-bin'*'+ reload udev rules and retrigger hidraw devices'*) ;;
*)
	printf '%s\n' 'Z13 bootstrap dry-run did not report its system operations.' >&2
	exit 1
	;;
esac
if [ -e "$rule_target" ]; then
	printf '%s\n' 'Z13 bootstrap dry-run installed the udev rule.' >&2
	exit 1
fi

printf '%s\n' 'Not a Z13' >"$dmi_root/product_family"
printf '%s\n' 'OTHER' >"$dmi_root/board_name"
run_bootstrap --no-pager

for path in \
	.config/niri/config.kdl \
	.config/fish/conf.d/dotfiles.fish \
	.config/fish/functions/dms-reset.fish \
	.config/alacritty/alacritty.toml \
	.config/zed/settings.json \
	.config/mimeapps.list \
	.gitconfig \
	.config/environment.d/10-ssh-agent.conf \
	.ssh/config \
	.config/git/allowed_signers \
	.config/DankMaterialShell/plugin_settings.json \
	.config/DankMaterialShell/plugins/dotfilesApps/plugin.json \
	.config/DankMaterialShell/plugins/dotfilesDashboard/plugin.json \
	.config/DankMaterialShell/plugins/dotfilesLauncher/plugin.json \
	.config/DankMaterialShell/plugins/dotfilesWorkspaces/plugin.json \
	.local/bin/focus-or-spawn \
	.local/bin/sync-z13-window-color; do
	if [ ! -f "$test_home/$path" ]; then
		printf 'Bootstrap did not create expected file: %s\n' "$path" >&2
		exit 1
	fi
done

for path in \
	.local/bin/focus-or-spawn \
	.local/bin/sync-z13-window-color; do
	if [ ! -x "$test_home/$path" ]; then
		printf 'Bootstrap did not make helper executable: %s\n' "$path" >&2
		exit 1
	fi
done

ssh_dir_mode=$(stat -c %a "$test_home/.ssh")
if [ "$ssh_dir_mode" != 700 ]; then
	printf 'Bootstrap deployed ~/.ssh with mode %s, expected 700.\n' "$ssh_dir_mode" >&2
	exit 1
fi
ssh_config_mode=$(stat -c %a "$test_home/.ssh/config")
if [ "$ssh_config_mode" != 600 ]; then
	printf 'Bootstrap deployed ~/.ssh/config with mode %s, expected 600.\n' "$ssh_config_mode" >&2
	exit 1
fi

if ! grep -Fq "sourceDir = \"$repo_root/chezmoi\"" "$test_home/.config/chezmoi/chezmoi.toml"; then
	printf '%s\n' 'Bootstrap did not render the chezmoi source directory into chezmoi.toml.' >&2
	exit 1
fi

wants_link=$test_home/.config/systemd/user/niri.service.wants/dms.service
if [ ! -L "$wants_link" ] || [ "$(readlink "$wants_link")" != "/usr/lib/systemd/user/dms.service" ]; then
	printf '%s\n' 'Bootstrap did not enable dms.service for niri.service.' >&2
	exit 1
fi
if grep -q 'spawn-at-startup "dms"' "$test_home/.config/niri/cfg/autostart.kdl"; then
	printf '%s\n' 'Niri autostart still spawns the shell; see ADR-0007.' >&2
	exit 1
fi

if find "$test_home" -name .keep -print -quit | grep -q .; then
	printf '%s\n' 'Bootstrap deployed a repository-only .keep file.' >&2
	exit 1
fi

second_dry_run=$(run_bootstrap --dry-run --no-pager)
if [ -n "$second_dry_run" ]; then
	printf '%s\n' 'Bootstrap is not idempotent; second dry-run produced output:' >&2
	printf '%s\n' "$second_dry_run" >&2
	exit 1
fi

dms_stub_dir=$test_root/stub
mkdir -p "$dms_stub_dir"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$dms_stub_dir/dms"
chmod +x "$dms_stub_dir/dms"

look_dry_run=$(PATH="$dms_stub_dir:$PATH" DMS_COMMAND=dms run_bootstrap --dry-run --no-pager)
case $look_dry_run in
*'dms-restore-plugins: dry run, restoring would change:'*'install dankLauncherKeys'*'dms-apply-look: dry run, applying would restart dms.service'*) ;;
*)
	printf '%s\n' 'Bootstrap dry-run did not preview the DMS plugins and look:' >&2
	printf '%s\n' "$look_dry_run" >&2
	exit 1
	;;
esac
if [ -e "$test_home/.config/DankMaterialShell/settings.json" ]; then
	printf '%s\n' 'Bootstrap dry-run wrote the DMS settings file.' >&2
	exit 1
fi
if [ -e "$test_home/.config/DankMaterialShell/plugins.lock.json" ]; then
	printf '%s\n' 'Bootstrap dry-run wrote the DMS plugin lockfile.' >&2
	exit 1
fi

printf '%s\n' 'Bootstrap isolation and idempotence tests passed.'
