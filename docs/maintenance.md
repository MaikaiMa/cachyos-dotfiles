# Maintenance workflow

This guide is the shared workflow for human and AI-assisted changes. The
repository remains the source of truth; live files are deployment targets and
must not be edited as a substitute for changing `chezmoi/`.

## Responsibilities

- `README.md` documents installation, scope, and normal use.
- `AGENTS.md` defines mandatory working boundaries for AI agents; `CLAUDE.md`
  only imports it for Claude Code.
- This guide defines the shared change, review, and verification workflow.
- `docs/adr/` records durable architectural decisions and their trade-offs.
- Package manifests record every non-base dependency needed by managed
  configuration, helpers, validation, or documented setup.

Update the relevant documentation in the same change as the implementation.
Do not duplicate detailed feature explanations across files; link to the
authoritative guide or ADR instead.

## Change workflow

Start by confirming that the worktree and the live home contain only expected
changes:

```fish
git status --short
chezmoi status
```

Make one focused change in the repository. Add or update its dependencies,
tests, user documentation, and ADR when applicable. Then run:

```fish
git diff --check
./tests/validate.sh
./scripts/bootstrap.sh --dry-run --no-pager
```

Review the code and the complete dry-run:

```fish
git diff
```

Do not run the live bootstrap until the dry-run is understood and the user has
explicitly approved deployment. On a detected Z13, a real bootstrap may install
the recorded AUR dependency and update the repository-owned udev rule in
addition to applying chezmoi.

## Definition of done

A change is ready for review when all applicable items are true:

- Managed home files live under `chezmoi/`, not only in the live home.
- Required official and AUR packages are recorded in the correct manifest.
- Secrets, generated files, and machine-local state are excluded.
- Changed POSIX shell scripts pass ShellCheck and `shfmt -d`.
- Changed Fish scripts pass `fish -n`.
- Niri and other supported configuration syntax is validated.
- Behavior-changing helpers have focused tests.
- Bootstrap succeeds from an isolated empty home and remains idempotent.
- Required files are tracked by Git.
- README, feature documentation, and the ADR index are current.
- A new system-wide architectural decision has an ADR.
- `git diff --check`, `tests/validate.sh`, and the real-home bootstrap dry-run
  pass.
- The handoff states what still needs to be verified on the physical machine.

## Updating the machine

The `dotfiles` bar shows pending pacman, AUR, and Flatpak updates through the
`yuuto/arch-updater` plugin; left click lists them, right click checks now.
The plugin's own settings, such as the automatic check interval, are plugin
state edited from its widget (middle click), not repository configuration.

Update everything from a terminal with:

```fish
paru -Syu; and flatpak update
```

Afterwards confirm that the manifests still match the machine:

```fish
./scripts/check-packages.sh
```

## Deployment and machine verification

After explicit approval, deploy from the reviewed worktree:

```fish
./scripts/bootstrap.sh
```

Run a second preview to detect unexpected drift:

```fish
./scripts/bootstrap.sh --dry-run --no-pager
```

Check that the machine still provides every recorded package:

```fish
./scripts/check-packages.sh
```

Repository tests cannot prove hardware and desktop behavior. After deployment,
manually verify the affected Niri behavior, that the DMS bar and its plugins
load (`dms-reset`, then check the bar and `Mod+S`), that a wallpaper change
re-renders the Z13 rear-window color (see `docs/dms.md`), spelling
integration, and any feature-specific restart requirements. Record a failed
assumption in the relevant guide or ADR before trying a different
architectural approach.
