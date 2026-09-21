# ADR-0009: Scope package manifests to the CachyOS profile baseline

- Status: Accepted
- Date: 2026-09-21

## Context

The machine has about 190 explicitly installed packages, almost all of them
placed by the CachyOS installer: base system, kernels, Limine, Plymouth, AMD
firmware and drivers, filesystem tools, Snapper, and the selected desktop
profile `cachyos-niri-noctalia`. The manifest recorded a much smaller set, and
several packages the managed configuration depends on were installed only as
dependencies of unrelated packages (`jq` via `scx-scheds`, `imagemagick` via
`zbar`, `enchant` via `webkit2gtk`, `niri` and `noctalia` via the profile
meta). Removing such a parent and running an orphan cleanup would silently
remove helpers' runtime dependencies.

Applications launched by the managed keybinds and the cursor theme referenced
in the Niri configuration were not recorded at all.

## Decision

Treat "a CachyOS installation with the Niri / Noctalia desktop profile" as the
baseline and do not record installer-owned packages. Record in
`packages/pacman.txt` and `packages/aur.txt` only what the managed
configuration, helpers, validation, or documented setup reference, including
packages the profile happens to provide, so the dependency is explicit even if
the profile changes.

Provide `scripts/check-packages.sh` to compare the manifests with the local
pacman database. It reports packages that are missing or installed only as a
dependency and, with `--mark-explicit`, changes the install reason of the
latter. Changing the install reason is metadata only; it installs, removes, and
updates nothing.

Bootstrap continues to install nothing from the general manifests. Installing
the manifest on a fresh machine remains an explicit, documented command.

## Consequences

- The manifest is portable: applying it on other hardware does not install a
  kernel, bootloader, or drivers.
- Config-referenced packages survive orphan cleanups once marked explicit.
- Packages not referenced by the repository (development tools, Docker, ROG
  utilities) are out of scope for these manifests; a separate optional list
  could record them later.
- The check depends on pacman's English `Install Reason` output and forces
  `LC_ALL=C` for that reason.

## Alternatives considered

- **Record every explicit package:** complete, but hardware-specific and
  dangerous to replay on another machine.
- **Record only the profile meta package:** compact, but a profile change
  upstream would silently drop a dependency such as the cursor theme.
- **Install the manifest from bootstrap:** convenient, but couples a
  configuration apply to package installation and privilege escalation.
