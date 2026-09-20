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
  dot_config/systemd/user/ future ~/.config/systemd/user units
scripts/                  idempotent operational helpers
system/                   explicitly installed system integration files
packages/                 explicit official and AUR package manifests
docs/adr/                 architecture decision records
docs/maintenance.md       shared change and verification workflow
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

On a 2025 ROG Flow Z13 (`GZ302*`), the Noctalia user template also sends that
same primary color to the rear window light through `z13ctl`. The helper is a
no-op on other hardware and always targets `lightbar`, never the keyboard; see
ADR-0004.

## Prerequisites

Install the repository, desktop, and validation prerequisites from the
official Arch or CachyOS repositories:

```fish
sudo pacman -S --needed git chezmoi fish shellcheck shfmt diffutils niri noctalia power-profiles-daemon jq util-linux paru
```

The complete currently recorded package set is maintained in
`packages/pacman.txt`, but general package manifests are not installed
automatically. The one
hardware-specific exception is `z13ctl-bin` on a detected GZ302 Flow Z13;
this dependency is justified in `packages/aur.txt` and installed by bootstrap.

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

Before adding existing live Niri files, compare them with the proposed
chezmoi source and make a small, reviewed migration. Do not copy credentials,
machine-specific display data, or other personal data into this repository.

## Ongoing maintenance

Edit files in this repository, validate them, and inspect the dry-run before
requesting a live apply. The completion checklist and the division between
automatic and machine-level checks are documented in
[the maintenance guide](docs/maintenance.md).
