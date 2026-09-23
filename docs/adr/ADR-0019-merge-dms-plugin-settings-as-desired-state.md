# ADR-0019: Merge DMS plugin settings as desired state

- Status: Accepted
- Date: 2026-09-23
- Amends: ADR-0008

## Context

ADR-0008 keeps files that applications rewrite under chezmoi as whole files
and treats the resulting drift as a review signal.
`~/.config/DankMaterialShell/plugin_settings.json` was managed that way. DMS
plugins write their own state into it on normal use: `commandRunner` saves its
command history and `webSearch` its edited engine lists. The file therefore
drifted after nearly every session, and chezmoi then asks whether to overwrite
it. Without a TTY that prompt fails, so `scripts/bootstrap.sh`, including its
`--dry-run`, stopped with exit status 1. Overwriting would also throw away the
history and engines, which are machine-local state, not configuration.

DMS reads the file only at startup (its `FileView` watches the file but does
not reload it), so a change needs a `dms.service` restart to take effect.

## Decision

`plugin_settings.json` is no longer managed by chezmoi. `dms/plugin_settings.json`
holds only the keys the repository pins (per plugin `enabled`, and
`commandRunner`'s `terminal` and `execFlag`). `scripts/dms-apply-look.sh`
deep-merges it into the live file per plugin, with the repository winning on
its keys and every other key preserved, in the same run and with the same
stop, write, start sequence as `dms/look.json` and `dms/session.json`. This is
the pattern ADR-0013 decision 2 already uses for the plugin lockfile.

## Consequences

- Bootstrap and its dry-run no longer stop on plugin state; command history
  and search engines survive every apply.
- Plugin settings changed in the DMS UI stay machine-local unless copied into
  `dms/plugin_settings.json` on purpose; `chezmoi status` no longer shows
  them as drift.
- Removing a pinned key from the repository file does not remove it from the
  live file; delete it there by hand if needed.
- Removing the source file does not delete the live file; chezmoi only
  removes targets listed in `.chezmoiremove` or inside `exact_` directories.

## Alternatives considered

- **Keep whole-file management and accept the drift:** blocks
  non-interactive bootstraps and discards plugin state on apply.
- **`chezmoi modify_` script:** keeps the merge inside chezmoi, but chezmoi
  would then rewrite the file while DMS runs and can overwrite it again from
  memory; the restart logic already lives in `dms-apply-look.sh`.
- **Ignore the file in `.chezmoiignore`:** stops the prompt but leaves a fresh
  machine without enabled plugins or the Ghostty `commandRunner` terminal.
