# CachyOS / Niri dotfiles

This is the reproducible, Linux-native source repository for Maikel's
user-level CachyOS configuration. Git versions the repository and
[chezmoi](https://www.chezmoi.io/) applies selected files into the home
directory. The live configuration—such as `~/.config/niri`—is never edited
directly by repository maintenance.

## Scope

The repository currently reproduces only the user-level features that have
been deliberately migrated. It is not yet a complete CachyOS installer and
does not recreate the operating system, drivers, accounts, secrets, or every
installed application.

## Structure

```text
chezmoi/                  chezmoi source tree for home-directory files
  dot_config/niri/        managed ~/.config/niri fragments
  dot_config/DankMaterialShell/ DMS plugins and plugin settings
  dot_config/matugen/     matugen config and templates (Niri colors, Z13 window color)
  dot_config/systemd/user/ managed ~/.config/systemd/user units
  dot_config/environment.d/ session environment (SSH agent socket)
  dot_config/git/         allowed signers for SSH commit signatures
  dot_config/fish/        Fish helpers (conf.d, functions)
  dot_config/alacritty/   terminal configuration
  dot_config/zed/         editor settings
  dot_config/mimeapps.list default applications
  dot_config/wallpapers/  wallpaper repositories cloned by wallpaper-favorites
  dot_gitconfig           Git credential helper
  private_dot_ssh/        SSH client configuration
  dot_local/bin/          deployed helper scripts
dms/look.json              DMS settings for the mat-glass look; see docs/dms.md
scripts/                  idempotent operational helpers
system/                   explicitly installed system integration files
packages/                 official, AUR, and Flatpak package manifests
docs/adr/                 architecture decision records
docs/maintenance.md       shared change and verification workflow
docs/dms.md               DMS shell: what is deployed, the look, plugins, matugen, idle/lock
docs/greeter.md           login screen: greetd running the DMS greeter
docs/pictures.md          ~/Pictures layout, wallpaper favourites, screenshots, viewers
docs/desktop-migration.md phased plan for the Noctalia to DMS / greetd migration (ADR-0013, ADR-0015)
tests/                    repository validation
```

`chezmoi/.chezmoiignore` excludes the tracked `.keep` placeholders. Review the
chezmoi diff before every explicit deployment.

DankMaterialShell (DMS) writes `dms/layout.kdl` and `dms/colors.kdl` from the
active wallpaper palette; the managed `config.kdl` includes both optionally, so
the Niri focus ring width and color follow DMS's theme on every change. These
generated, wallpaper-dependent files are runtime state and are intentionally
not stored in Git.

DMS is deployed with the mat-glass bar look from `dms/look.json`, applied by
`scripts/dms-apply-look.sh`: a launcher button, workspace pills that turn red
on a notification, and application icons with a focus highlight and
notification dot replace the built-in bar widgets. The [Dotfiles
Dashboard](chezmoi/dot_config/DankMaterialShell/plugins/dotfilesDashboard/README.md)
plugin rebuilds the former Noctalia dashboard as a centered popout on
`Mod+S`, with the original DMS Control Center and Settings still reachable
from its header. DMS's own built-in lock screen stays; see
[ADR-0015](docs/adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md).
All of this, including how to iterate on the look, restart the shell, and
reload a plugin, is documented in [docs/dms.md](docs/dms.md). The login
screen, greetd running the DMS greeter, is documented in
[docs/greeter.md](docs/greeter.md).

The former Noctalia configuration is preserved only as the `noctalia-final`
Git tag; ADR-0002, ADR-0004, ADR-0005, ADR-0006, ADR-0007, and ADR-0011
describe it and are superseded by
[ADR-0013](docs/adr/ADR-0013-replace-noctalia-with-dms-and-quickshell-surfaces.md).

On a 2025 ROG Flow Z13 (`GZ302*`), the matugen `z13_window` template also
sends the primary color to the rear window light through `z13ctl`. The helper
is a no-op on other hardware and always targets `lightbar`, never the
keyboard; see [docs/dms.md](docs/dms.md#z13-rear-window-color).

## Packages

The baseline is a CachyOS installation with the "Niri / Noctalia" desktop
profile, which installs `cachyos-niri-noctalia` and with it Niri, the cursor
theme, and the desktop portals. That profile stays the baseline for those
pieces even though DMS, not Noctalia, is the deployed shell; Noctalia remains
on disk unused. `packages/pacman.txt` records only what the managed
configuration, helpers, validation, and documented setup need on top of or
from within that baseline — including `dms-shell-niri`, `quickshell`,
`matugen`, and `cava`. Kernel, bootloader, driver, and other installer-owned
packages are deliberately not recorded; see ADR-0009.

Pending updates from all three sources show in the bar through the
`yuuto/arch-updater` plugin; see the maintenance guide for the update
command. Compare the manifests with the machine at any time:

```fish
./scripts/check-packages.sh
```

It lists packages that are missing and packages that are installed only as a
dependency of something else, which an orphan cleanup could remove. Mark the
latter as explicitly installed with:

```fish
./scripts/check-packages.sh --mark-explicit
```

Install the recorded official packages on a fresh machine with:

```fish
sudo pacman -S --needed (sed 's/#.*//' packages/pacman.txt | string trim | string match --invert '')
```

`packages/aur.txt` lists the unavoidable AUR packages with their rationale.
Install them individually with `paru`; bootstrap installs `z13ctl-bin` itself
on a detected GZ302 Flow Z13 and nothing on other hardware. The login screen
(`greetd`, `acl`, and the AUR `greetd-dms-greeter-bin`) is not installed by
bootstrap either; it is a separate, explicitly approved step run with
`./scripts/setup-greetd.sh`, see [docs/greeter.md](docs/greeter.md).

`packages/flatpak.txt` is the last-resort tier for software without an official
or AUR package; each entry names the guide that documents its installation.

## Gaming

Install the recorded CachyOS gaming stack with:

```fish
sudo pacman -S --needed cachyos-gaming-meta cachyos-gaming-applications
```

This is equivalent to selecting `Install Gaming packages` in CachyOS Hello. It
installs the gaming libraries and applications maintained by CachyOS, including
Steam. Steam downloads, account state, compatibility data, and shader caches
remain machine-local and are not managed by this repository.

On a detected 2025 Z13, `scripts/bootstrap.sh` automatically installs
`z13ctl-bin` with `paru` or `yay`, installs the narrowly scoped lightbar udev
rule, applies the dotfiles, and applies the DMS look. No logout or separate
activation step is required. Other hardware skips the entire Z13 setup.

## DMS startup

DMS is started by its own packaged systemd user unit, `dms.service`, which is
bound to `niri.service` and enabled through a chezmoi-managed symlink in
`niri.service.wants/`. Niri's autostart fragment does not spawn DMS as well.
Restart the shell with:

```fish
dms-reset
```

## Wallpaper favourites

The DMS wallpaper picker reads one flat folder, so `~/Pictures/Wallpapers`
holds only symlinks. `wallpaper-favorites` creates them from the images
starred in Files (Nautilus) under `~/Pictures/Libraries`, and the
chezmoi-enabled `wallpaper-favorites.path` user unit runs it whenever a star
changes. After the first deployment the unit needs one manual start:

```fish
systemctl --user daemon-reload
systemctl --user start wallpaper-favorites.path
wallpaper-favorites pull
```

See [docs/pictures.md](docs/pictures.md) and
[ADR-0016](docs/adr/ADR-0016-mirror-nautilus-stars-into-the-dms-wallpaper-folder.md).

## Shell, terminal, editor and defaults

The repository manages DMS's plugins and plugin settings (see
[docs/dms.md](docs/dms.md)), Fish helpers under `conf.d/` and `functions/`,
the Alacritty configuration, Zed settings, the default-application handlers in
`mimeapps.list`, and a `.gitconfig` that uses the GitHub CLI as credential
helper and signs commits and tags with the SSH key from 1Password. Git
identity is not managed; set it per repository or locally.

Files that CachyOS installs from `/etc/skel` and that are unchanged, such as
`config.fish`, `.zshrc`, and the Micro settings, are deliberately not managed.
Zed and the XDG MIME database rewrite their own files; review the resulting
`chezmoi status` drift and promote or revert it. See ADR-0008.

Restart the shell with the managed Fish function:

```fish
dms-reset
```

## Secrets

GNOME Keyring provides the Secret Service, the 1Password agent provides SSH,
and commits are signed with the SSH key from 1Password. Setup and the one-time
GitHub step are in [docs/secrets.md](docs/secrets.md); see ADR-0012.

## Mail

[Hylki](docs/mail.md) is the managed mail client, installed as a Flatpak and
reachable with `Mod3+M`. It reads the Proton account through the Bridge below
and Google accounts through GNOME Online Accounts; see ADR-0010.

## Proton Mail Bridge

The package manifest records `protonmail-bridge-core`. Chezmoi enables the
package-provided `protonmail-bridge.service` for the systemd user session, so
Bridge starts automatically after login. The repository does not copy the
service unit; package updates remain authoritative for its implementation.

Proton credentials, Bridge account configuration, generated certificates, and
mail-client passwords remain machine-local. Log in once with
`protonmail-bridge-core` before deploying the dotfiles. After deployment, check
the service with:

```fish
systemctl --user status protonmail-bridge.service
```

## Dutch and English spelling

The package manifest includes the shared spelling prerequisites. After a fresh
installation, follow [the spelling setup guide](docs/spelling.md) to install and
verify them. This provides Dutch and US English dictionaries for supporting
applications; it does not automatically select both languages in every app.
Application-specific spelling preferences are not yet managed.

## Bootstrap

Clone over HTTPS so a fresh machine does not need an SSH key:

```fish
git clone https://github.com/MaikaiMa/cachyos-dotfiles.git "$HOME/Projects/dotfiles"
cd "$HOME/Projects/dotfiles"
```

Review the repository, then validate and preview the source tree:

```fish
./tests/validate.sh
./scripts/bootstrap.sh --dry-run --no-pager
```

These are POSIX `sh` scripts and can be run directly from Fish because their
shebang selects `sh`. If an explicit Fish command is preferred, use
`fish tests/validate.fish`; do not invoke `fish tests/validate.sh`.

When the source tree contains reviewed configuration, apply it explicitly. On
a Z13 this one command also completes the rear-window setup:

```fish
./scripts/bootstrap.sh
```

The first bootstrap also renders `~/.config/chezmoi/chezmoi.toml` with the
repository's source directory, so plain chezmoi commands work afterwards:

```fish
chezmoi status
chezmoi diff
```

Deployment still goes through `scripts/bootstrap.sh`, which passes the source
explicitly and handles the Z13 steps.

Before adding existing live Niri files, compare them with the proposed
chezmoi source and make a small, reviewed migration. Do not copy credentials,
machine-specific display data, or other personal data into this repository.

## Ongoing maintenance

Edit files in this repository, validate them, and inspect the dry-run before
requesting a live apply. The completion checklist and the division between
automatic and machine-level checks are documented in
[the maintenance guide](docs/maintenance.md).
