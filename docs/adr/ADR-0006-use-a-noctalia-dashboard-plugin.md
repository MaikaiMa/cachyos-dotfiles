# ADR-0006: Use a Noctalia dashboard plugin

- Status: Accepted
- Date: 2026-09-20

## Context

Noctalia's built-in Control Center Home tab spends most of its space on
session information, while the frequently used brightness, audio, media,
battery, and power-profile controls live on separate tabs. The built-in tab
order and Home composition are not configurable without maintaining a patch.

The custom entry point must preserve the full Control Center and Settings,
use real system state for every toggle it shows, and remain compatible with
ordinary Noctalia upgrades.

## Decision

Install a local declarative-UI plugin named `maikel/quick-controls`. Its
centered floating panel is the `Mod+S` Dashboard and provides compact media,
brightness, audio, quick-toggle, battery, and power-profile controls. Header
buttons open the built-in Home tab, notification tab, and Settings window.

Noctalia IPC remains the authority for shell mutations. A short-lived,
read-only helper collects system state while the panel is open. It reads audio
through WirePlumber, media through Playerctl, power and battery through their
standard Linux interfaces, and Noctalia's public status IPC where available.
Caffeine is derived from Noctalia's own logind idle inhibitor so it remains
correct when another Noctalia surface changes it.

Night Light is omitted until Noctalia exposes both scheduled and forced runtime
state to plugins or IPC. Showing an action without authoritative state would
violate the dashboard's status-aware contract.

Use Noctalia's native panel animation with a modest global 1.15 speed factor,
glass transparency, and a centered panel shadow. Do not add a fullscreen blur
overlay: it cannot currently animate in sync through the supported plugin API.

## Consequences

- `Mod+S` opens the compact Dashboard; the original Home and every other
  Control Center tab remain reachable.
- The helper and Playerctl run only while Noctalia refreshes the open panel.
- Controls disappear when their status cannot be established rather than
  presenting a misleading toggle.
- Animation speed and shadow direction are global Noctalia shell settings, so
  other animated shell surfaces inherit the same tuning.
- The implementation uses public plugin, IPC, MPRIS, logind, sysfs, and
  PipeWire interfaces and requires no Noctalia patch.

## Alternatives considered

- **Patch the built-in Home tab:** gives the deepest integration but creates a
  permanent fork and upgrade burden.
- **Only link to built-in tabs:** keeps maintenance minimal but does not create
  the requested at-a-glance dashboard.
- **Fullscreen dim or blur overlay:** can be approximated with an extra layer
  surface, but it does not synchronize cleanly with the supported panel close
  animation and adds focus and GPU-cost risks.
