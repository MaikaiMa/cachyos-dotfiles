# ADR-0002: Use Noctalia for dynamic Niri colors

- Status: Accepted
- Date: 2026-09-19

## Context

The active Niri focus indicator should follow Noctalia's selected palette,
including palettes generated from the current wallpaper. Hard-coding a color
in the dotfiles would drift from the shell theme, while rendering the color at
chezmoi apply time would not react to later wallpaper or palette changes.

Noctalia ships a built-in `niri` template. It renders palette roles into
`~/.config/niri/noctalia.kdl` and maintains the corresponding include in
Niri's live `config.kdl`.

## Decision

Enable Noctalia's built-in `niri` template through a chezmoi-managed
`~/.config/noctalia/templates.toml`.

Noctalia owns the generated `~/.config/niri/noctalia.kdl` file and the live
include that loads it. Neither is committed to Git. Chezmoi continues to own
the stable Niri behavior and geometry, such as focus-ring width, gaps, and
struts. The active palette source and wallpaper remain runtime choices rather
than repository data.

This is a documented exception to the usual rule that live Niri configuration
is changed only through chezmoi: the repository declares the integration, and
Noctalia performs its documented generation and cleanup lifecycle.

## Consequences

- Niri colors update when Noctalia's resolved palette changes.
- Wallpaper-derived colors and wallpaper paths do not enter Git.
- A fresh setup requires Noctalia with its built-in Niri template.
- The generated file must not be edited manually because Noctalia will replace
  it.
- Disabling the template may remove the generated file and Noctalia-owned
  include; the stable Niri configuration remains usable with its defaults.
- Validation of generated colors happens after Noctalia has rendered the
  template on the target machine.

## Alternatives considered

- **Static color in `layout.kdl`:** simple and fully declarative, but does not
  follow the active palette.
- **Chezmoi template:** reproducible at apply time, but does not automatically
  react to wallpaper changes.
- **Custom palette script or hook:** flexible, but duplicates behavior already
  maintained by Noctalia.
- **Commit the rendered `noctalia.kdl`:** makes generated, wallpaper-specific
  state part of Git and would create frequent noise and drift.
