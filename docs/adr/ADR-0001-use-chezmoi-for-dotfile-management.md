# ADR-0001: Use chezmoi for dotfile management

- Status: Accepted
- Date: 2026-09-18

## Context

The Niri/CachyOS setup needs a reproducible, Git-versioned way to manage
user-level configuration while keeping the live home directory separate from
the repository. The workflow must support safe previews, incremental adoption
of existing files, templates when genuinely needed, and clear automation for
future AI-assisted changes.

## Decision

Use chezmoi with `chezmoi/` as this repository's source directory. Managed
files will mirror their target home-directory paths using chezmoi naming (for
example, `dot_config/niri` for `~/.config/niri`). Git remains the versioned
source of truth. Changes are reviewed in the repository and deployed only by
an explicit chezmoi command.

## Consequences

- The live home directory and the repository remain separate by design.
- `chezmoi diff` and `chezmoi apply --dry-run` can be used before deployment.
- Existing configuration must be migrated deliberately, one reviewed subset at
  a time.
- Contributors need chezmoi in addition to Git.
- Secret or machine-specific material must not enter the source tree; use
  documented local mechanisms only when such needs arise.

## Alternatives considered

- **Bare Git repository in `$HOME`:** fewer tools, but weak separation from
  live state and easy to misuse.
- **GNU Stow:** simple symlink management, but less suitable for controlled
  templating, diffing, and staged application.
- **yadm:** capable, but chezmoi has a focused source-tree model and a clear
  apply/diff workflow for this use case.
- **Manual copies:** no reliable drift detection or reproducible deployment.
