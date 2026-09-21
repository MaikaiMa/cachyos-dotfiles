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
  dot_config/noctalia/    declarative Noctalia configuration
  dot_config/systemd/user/ managed ~/.config/systemd/user units
  dot_config/environment.d/ session environment (SSH agent socket)
  dot_config/git/         allowed signers for SSH commit signatures
  dot_config/fish/        Fish helpers (conf.d, functions)
  dot_config/alacritty/   terminal configuration
  dot_config/zed/         editor settings
  dot_config/mimeapps.list default applications
  dot_gitconfig           Git credential helper
  private_dot_ssh/        SSH client configuration
  dot_local/bin/          deployed helper scripts
scripts/                  idempotent operational helpers
system/                   explicitly installed system integration files
packages/                 official, AUR, and Flatpak package manifests
docs/adr/                 architecture decision records
docs/maintenance.md       shared change and verification workflow
docs/desktop-migration.md phased plan for the Noctalia to DMS / greetd migration (ADR-0013, ADR-0014)
tests/                    repository validation
```

`chezmoi/.chezmoiignore` excludes the tracked `.keep` placeholders. Review the
chezmoi diff before every explicit deployment.

Noctalia's built-in Niri template generates `~/.config/niri/noctalia.kdl`
from the active palette. This generated, wallpaper-dependent file is runtime
state and is intentionally not stored in Git; see ADR-0002.

The managed Noctalia configuration also provides a `dotfiles` bar and keeps
the built-in `default` bar available as a disabled fallback. Bootstrap deploys
and activates `dotfiles`. To switch locally, enable `default` and disable
`dotfiles` in Noctalia Settings; those GUI overrides intentionally remain
machine-local in `~/.local/state/noctalia/settings.toml`.

While the `dotfiles` bar is active, Noctalia's native PipeWire spectrum is
placed behind it as a subtle theme-colored glow. The placement is generated
from the effective bar and Niri output geometry, including the bar thickness,
padding, radius, and margins, so connector names and display dimensions remain
machine-local. It synchronizes when Noctalia starts. After a
display or bar-layout change during the session, refresh it with:

```fish
sync-noctalia-audio-glow
```

The generated `~/.config/noctalia/desktop-audio-glow.generated.toml` is runtime
state and must not be committed. Disabling the `dotfiles` bar and running the
helper removes the glow while leaving the fallback bar unchanged; see ADR-0005.

The local [Noctalia Dashboard plugin](docs/noctalia-quick-controls.md) provides
a compact, status-aware `Mod+S` control surface without patching Noctalia. The
original Control Center and complete Settings remain available from its header.

The managed [Noctalia lock screen](docs/noctalia-lockscreen.md) keeps a small
stock composition of native time, date, and login widgets. It follows the
active wallpaper palette without maintaining custom lock-screen code.

On a 2025 ROG Flow Z13 (`GZ302*`), the Noctalia user template also sends that
same primary color to the rear window light through `z13ctl`. The helper is a
no-op on other hardware and always targets `lightbar`, never the keyboard; see
ADR-0004.

## Packages

The baseline is a CachyOS installation with the "Niri / Noctalia" desktop
profile, which installs `cachyos-niri-noctalia` and with it Niri, Noctalia,
the cursor theme, and the desktop portals. `packages/pacman.txt` records only
what the managed configuration, helpers, validation, and documented setup need
on top of or from within that baseline. Kernel, bootloader, driver, and other
installer-owned packages are deliberately not recorded; see ADR-0009.

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
on a detected GZ302 Flow Z13 and nothing on other hardware.

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
rule, applies the dotfiles, and asks a running Noctalia instance to refresh its
templates. No logout or separate activation step is required. Other hardware
skips the entire Z13 setup.

## Noctalia startup

Noctalia is started by the managed systemd user unit `noctalia.service`, which
is bound to `niri.service` and enabled through a chezmoi-managed symlink in
`niri.service.wants/`. Niri's autostart fragment deliberately does not spawn
Noctalia as well; see ADR-0007. Restart the shell with:

```fish
systemctl --user restart noctalia.service
```

## Shell, terminal, editor and defaults

The repository manages Noctalia's shell options (`config.toml`, polkit agent),
Fish helpers under `conf.d/` and `functions/`, the Alacritty configuration, Zed
settings, the default-application handlers in `mimeapps.list`, and a
`.gitconfig` that uses the GitHub CLI as credential helper and signs commits
and tags with the SSH key from 1Password. Git identity is not managed; set it
per repository or locally.

Files that CachyOS installs from `/etc/skel` and that are unchanged, such as
`config.fish`, `.zshrc`, and the Micro settings, are deliberately not managed.
Zed and the XDG MIME database rewrite their own files; review the resulting
`chezmoi status` drift and promote or revert it. See ADR-0008.

Restart the shell with the managed Fish function:

```fish
noctalia-reset
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
