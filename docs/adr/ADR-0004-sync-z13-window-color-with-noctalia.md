# ADR-0004: Sync the Z13 window color with Noctalia

- Status: Accepted
- Date: 2026-09-19

## Context

The Niri focus indicator already follows Noctalia's active `primary` palette
color. The rear window light on the 2025 ROG Flow Z13 should use that same
color after a wallpaper- or palette-driven theme change, without changing the
detachable keyboard lighting.

`asusctl` can control the GZ302 keyboard but cannot address its chassis
lightbar. `z13ctl` implements the GZ302 Aura HID protocol and can explicitly
target only the `lightbar` device.

## Decision

Add a Noctalia user template that renders `colors.primary.default`, matching
the color used by Noctalia's built-in Niri template. After every successful
render, run a chezmoi-managed helper with the rendered RGB value.

The helper verifies both the `ROG Flow Z13` DMI product family and a `GZ302*`
board name before invoking `z13ctl`. It always passes `--device lightbar` and
uses a static effect, so it never intentionally addresses the keyboard. On all
other hardware it exits without making a change.

Record `z13ctl-bin` in the AUR package manifest. On a detected GZ302, the
bootstrap installs it through `paru` or `yay` when needed and installs a udev
`uaccess` rule restricted to the rear-window USB device (`0b05:18c6`). It then
applies chezmoi and requests an immediate Noctalia template refresh. This is a
hardware-specific exception to the otherwise user-level bootstrap; the dry-run
path reports these operations without changing the system.

## Consequences

- The rear window follows the same primary RGB color as Niri after Noctalia
  reapplies its templates.
- The integration is restricted to supported 2025 Z13 (`GZ302*`) boards.
- Keyboard lighting remains outside this integration.
- A fresh setup needs only the normal bootstrap command; it installs
  `z13ctl-bin` and grants the active local session access without a logout.
- The helper safely becomes a no-op when these dotfiles are used on other
  hardware.

## Alternatives considered

- **`asusctl`:** already present, but current GZ302 support covers the keyboard
  rather than the rear chassis lightbar.
- **OpenRGB:** does not currently support the GZ302 lightbar.
- **A repository-owned raw HID implementation:** avoids an AUR dependency but
  duplicates a hardware protocol and its ongoing maintenance.
- **Change both Aura devices together:** simpler, but violates the requirement
  to leave the keyboard unchanged.
