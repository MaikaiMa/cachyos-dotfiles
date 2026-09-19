# CachyOS / Niri dotfiles

This is the reproducible, Linux-native source repository for Maikel's
user-level CachyOS configuration. Git versions the repository and
[chezmoi](https://www.chezmoi.io/) applies selected files into the home
directory. The live configuration—such as `~/.config/niri`—is never edited
directly by repository maintenance.

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
tests/                    repository validation
```

`chezmoi/.chezmoiignore` excludes the tracked `.keep` placeholders. Review the
chezmoi diff before every explicit deployment.

Noctalia's built-in Niri template generates `~/.config/niri/noctalia.kdl`
from the active palette. This generated, wallpaper-dependent file is runtime
state and is intentionally not stored in Git; see ADR-0002.

On a 2025 ROG Flow Z13 (`GZ302*`), the Noctalia user template also sends that
same primary color to the rear window light through `z13ctl`. The helper is a
no-op on other hardware and always targets `lightbar`, never the keyboard; see
ADR-0004.

## Prerequisites

Install Git, chezmoi, Fish, ShellCheck, and shfmt from the official repositories:

```fish
sudo pacman -S git chezmoi fish shellcheck shfmt
```

General package manifests are not installed automatically. The one
hardware-specific exception is `z13ctl-bin` on a detected GZ302 Flow Z13;
this dependency is justified in `packages/aur.txt` and installed by bootstrap.

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

Review the repository first, then validate and preview the source tree:

```fish
cd /home/maikel/Projects/dotfiles
./tests/validate.sh
./scripts/bootstrap.sh --dry-run
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
