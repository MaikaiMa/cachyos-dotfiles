# ADR-0011: Declare Noctalia plugins and show updates in the bar

- Status: Accepted
- Date: 2026-09-21

## Context

Packages arrive from three sources: official repositories and AUR through
`paru`, and Flatpak for Hylki. Nothing on the desktop showed that updates
were pending; 127 official updates had accumulated in three days without
being noticed.

ADR-0006 treated Noctalia's enabled-plugin list as machine-local state and
documented a manual `noctalia msg plugins enable` step. Noctalia v5 reads a
declarative `[plugins] enabled` list from the config directory and writes a
state override only when the Settings UI disagrees.

## Decision

Enable the community plugin `yuuto/arch-updater` and place its bar widget
between the system capsule and the notification widget of the `dotfiles`
bar. It checks pacman through `checkupdates`, AUR through `paru -Qua`, and
Flatpak through `remote-ls --updates`, and runs upgrades in a terminal on
request. Updating stays a manual, visible action: `paru -Syu` followed by
`flatpak update`.

Declare both plugins, `maikel/quick-controls` and `yuuto/arch-updater`, in
the managed `config.toml` instead of documenting a manual enable step. This
supersedes the machine-local assumption in ADR-0006.

Plugin-level settings have no supported declarative section in the shell
config, so they remain plugin state. Widget-level settings (glyph, count,
hide when empty) are set in `bar.toml`.

## Consequences

- Pending updates from all three sources are visible in the bar with a count.
- A fresh deployment activates both plugins; the community plugin is fetched
  from Noctalia's community source on first start and therefore needs network
  access once.
- `noctalia config validate` resolves the plugin widget type only after the
  plugin has been materialized in the state directory; on a machine that has
  never enabled it, `tests/validate.sh` reports a warning, not an error.
- The automatic check interval defaults to off and is set once per machine
  from the widget's settings.
- Aggregators such as topgrade were considered unnecessary while only these
  three sources exist; `mise` and Fish plugins remain manual.

## Alternatives considered

- **topgrade:** one command across many sources, but an AUR dependency that
  also touches toolchains and shell plugins that are not managed here.
- **A repository update script:** would duplicate two commands without adding
  the missing visibility.
- **Built-in Noctalia widget:** none exists for package updates.
