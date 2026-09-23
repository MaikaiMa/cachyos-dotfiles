# ADR-0008: Manage application configuration selectively

- Status: Accepted; amended by [ADR-0019](ADR-0019-merge-dms-plugin-settings-as-desired-state.md)
- Date: 2026-09-21

## Context

Several files that make the desktop usable lived only in the live home:
Noctalia's shell options, Fish helpers, the Alacritty and Zed configuration,
the default-application handlers, and the Git credential helper. A fresh
machine would boot into Niri and Noctalia but without a working polkit agent,
terminal preferences, or default browser.

Not every file under `~/.config` is worth managing. CachyOS installs
defaults from `/etc/skel` (Fish, Zsh, Bash, Micro) that a fresh install
recreates unchanged, applications such as Zed and the XDG MIME database
rewrite their own files, and some handlers pointed at applications that are
no longer installed.

## Decision

Manage a file only when it is one of:

- required for the managed desktop to function (Noctalia `config.toml`);
- deliberately changed from the CachyOS default (`alacritty.toml`);
- a repository-owned helper (Fish `conf.d/` and `functions/`);
- a curated set of defaults whose targets are installed (`mimeapps.list`,
  `.gitconfig`).

Files identical to `/etc/skel` are left unmanaged and are documented as
CachyOS defaults. Files that applications rewrite are still managed; the
resulting chezmoi drift is reviewed and either promoted into the repository
or reverted by the next apply. Handlers for uninstalled applications are
dropped rather than preserved.

## Consequences

- A fresh bootstrap yields a working terminal, editor, default browser, polkit
  agent, and GitHub credential helper.
- `chezmoi status` may show `mimeapps.list` and Zed `settings.json` after
  in-app changes; that drift is the review signal, not an error.
- Fish universal variables (`fish_variables`), prompt themes, and Micro syntax
  files remain machine-local.
- Packages behind managed configuration are recorded in `packages/pacman.txt`.

## Alternatives considered

- **Manage all of `~/.config`:** captures everything but versions profiles,
  caches, and credentials.
- **Manage nothing that applications rewrite:** avoids drift but leaves the
  default browser and editor unreproducible.
- **Copy skel files into the repository:** duplicates packaged defaults and
  hides upstream updates behind a stale copy.

## Update 2026-09-23 (ADR-0019)

DMS's `plugin_settings.json` is no longer managed as a whole file: plugins
write history and other state into it, so the drift blocked non-interactive
bootstraps. A desired-state subset in `dms/plugin_settings.json` is merged
into it instead. The rest of this decision is unchanged. See
[ADR-0019](ADR-0019-merge-dms-plugin-settings-as-desired-state.md).
