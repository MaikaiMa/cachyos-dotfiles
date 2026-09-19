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
packages/                 explicit official and AUR package manifests
docs/adr/                 architecture decision records
tests/                    repository validation
```

`chezmoi/.chezmoiignore` excludes the tracked `.keep` placeholders. Review the
chezmoi diff before every explicit deployment.

Noctalia's built-in Niri template generates `~/.config/niri/noctalia.kdl`
from the active palette. This generated, wallpaper-dependent file is runtime
state and is intentionally not stored in Git; see ADR-0002.

## Prerequisites

Install Git, chezmoi, ShellCheck, and shfmt from the official repositories:

```sh
sudo pacman -S git chezmoi shellcheck shfmt
```

No package is installed automatically by this repository. AUR packages, if
ever needed, must be explicitly justified in `packages/aur.txt`.

## Bootstrap

Review the repository first, then validate and preview the source tree:

```sh
cd /home/maikel/Projects/dotfiles
./tests/validate.sh
./scripts/bootstrap.sh --dry-run
```

These are POSIX `sh` scripts and can be run directly from Fish because their
shebang selects `sh`. If an explicit Fish command is preferred, use
`fish tests/validate.fish`; do not invoke `fish tests/validate.sh`.

When the source tree contains reviewed configuration, apply it explicitly:

```sh
./scripts/bootstrap.sh
```

Before adding existing live Niri files, compare them with the proposed
chezmoi source and make a small, reviewed migration. Do not copy credentials,
machine-specific display data, or other personal data into this repository.
