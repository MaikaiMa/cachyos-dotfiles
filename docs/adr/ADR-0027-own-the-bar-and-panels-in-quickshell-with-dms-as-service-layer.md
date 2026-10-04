# ADR-0027: Own the bar and panels in Quickshell, keep DMS as the service layer

- Status: Accepted
- Date: 2026-10-04
- Amends: [ADR-0013](ADR-0013-replace-noctalia-with-dms-and-quickshell-surfaces.md)
  (decision 2 "extend DMS only through its plugin API" no longer covers the
  bar; decision 3 is revived in a new form),
  [ADR-0015](ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md)
  (the DMS lock screen and dms-greeter stay for now but are declared
  replaceable, in a later phase)

## Context

Two weeks of living with DMS (ADR-0013) and five repository-owned plugins
have shown where the plugin API ends. The remaining wishes are not cosmetic
points inside one widget but the shape of the shell itself:

- a cleaner bar whose components animate and change shape with their state
  (a capsule that grows into a media card, workspace pills that morph);
- panels that open from and visually belong to the bar instead of DMS's
  fixed control center and popouts;
- a lock screen and a greeter that are one design, where the lock has the
  richer context (media player, Niri state) and the greeter has the live
  Niri/Steam session switch instead of a dropdown.

None of this is reachable through DMS plugins. Plugins are additive: they add
widgets next to the built-in ones, cannot restyle or replace the bar frame,
cannot replace the control center, and cannot draw on the lock layer
(ADR-0013, ADR-0015). ADR-0015 rejected a custom locker as disproportionate
for two cosmetic wishes; that argument does not hold for the list above.

Facts verified on 2026-10-04 against the installed DMS 1.6.2 and Quickshell
0.3.1:

- Each entry in DMS's `barConfigs` has `enabled` and `visible` flags. The
  bar window is only created when both are true (`bc.enabled ?? true`); with
  `enabled: false` DMS runs without a bar while notifications, OSD, the
  control center, the lock screen, the polkit agent, the wallpaper dash, the
  matugen pipeline, and the whole `dms ipc` surface stay up. The flag is a
  normal settings key and goes through the existing `dms/look.json` merge
  (`scripts/dms-apply-look.sh`, ADR-0019).
- `dms ipc call bar hide|reveal|toggle` exists for runtime hiding, but it is
  not persistent; the settings flag is.
- DMS writes its palette to `~/.cache/DankMaterialShell/dms-colors.json`
  and runs matugen with user templates (`runUserMatugenTemplates`), so a
  second Quickshell process gets the same wallpaper colours without owning
  the theming pipeline.
- DMS has `customPowerActionLock` for an external locker, and Quickshell
  ships `Quickshell.Wayland` session lock, `Quickshell.Services.Pam` and
  `Quickshell.Services.Greetd`. Niri keeps the session locked when a locker
  crashes.
- Switching from Niri to the Steam session means ending the Niri session.
  A lock screen can only lock the session it runs in; the session choice
  belongs to the greeter. ADR-0023 already hands Steam back to Niri inside
  one login through a wrapper that `exec`s `niri-session` when gamescope
  exits.

The constraints from ADR-0013 stand: no fork of DMS or Quickshell, official
packages where possible, wallpaper-derived colours everywhere, everything
reproducible from this repository. The user's added constraints: no big
bang, and the old and the new bar must be swappable in one step while the
new one matures.

## Decision

1. **DMS stays installed and running as the service layer.** It keeps
   notifications, OSD, control center, clipboard-free launcher remnants,
   polkit, the wallpaper dash, matugen theming, the idle policy, and for
   now the lock screen. Nothing in this ADR removes a DMS feature until the
   repository-owned replacement exists and has been used.
2. **The bar and its panels become a repository-owned Quickshell
   configuration.** It lives in `chezmoi/dot_config/quickshell/bar/` as a
   separate Quickshell instance with its own systemd user unit
   (`quickshell-bar.service`, wanted by `niri.service` like `dms.service`).
   It reads the DMS palette file and must never require a patched DMS or
   Quickshell. Panels are Quickshell popups anchored to bar widgets. Where a
   panel is not written yet, the widget calls the matching `dms ipc`
   function, so the migration happens per widget, not per bar.
3. **One switch flips between the bars.** `scripts/bar-switch.sh own|dms`
   sets `barConfigs[].enabled` through the `look.json` merge and starts or
   stops `quickshell-bar.service`. `dms/look.json` carries the chosen state,
   so a fresh bootstrap reproduces it. The existing bar plugins stay in the
   repository until the own bar has replaced their function, then they are
   deleted in the same change that documents the replacement.
4. **Lock screen and greeter follow later as one codebase.** A second
   Quickshell tree, `chezmoi/dot_config/quickshell/session/`, with shared
   components and two entry points. The lock replaces DMS's through
   `customPowerActionLock`; the greeter replaces `greetd-dms-greeter-bin`
   (the only AUR package in that chain) through `Quickshell.Services.Greetd`
   and the ADR-0014 deployment model. The greeter carries the Niri/Steam
   switch. The lock shows the same switch, but it means "log out into
   Steam": after PAM succeeds it leaves a marker and quits Niri, and a
   session wrapper mirroring ADR-0023 starts gamescope in the same login.
   If that wrapper proves fragile, the lock shows the switch disabled. This
   phase gets its own ADR with the verified facts before work starts; this
   decision only fixes the direction so the bar work does not paint it in.
5. **Order of work.** Bar scaffold with the switch script and one or two
   widgets first, used for real before any panel is written; then panels;
   then the session tree. Each phase lands as a normal change with docs,
   tests and the maintenance checklist, never as one merge.

## Consequences

- Breakage in the bar moves from "wait for a DMS release" to "fix it
  yourself". Quickshell releases about twice a year and announced 0.3 as
  non-breaking, so the platform under it is calm; DMS updates can still
  rename a palette key or an IPC function, which the own bar must treat as
  an external interface and the update report (ADR-0025) flags because
  `dms-shell` is a fragile package.
- Two Quickshell processes run instead of one. Memory cost is in the tens
  of megabytes; it is accepted for the swappability it buys.
- The five existing plugins (`dotfilesApps`, `dotfilesDashboard`,
  `dotfilesKeyboard`, `dotfilesLauncher`, `dotfilesWorkspaces`) are
  rewritten as plain components. What is lost is the plugin boilerplate,
  not the logic.
- Niri keybinds keep calling `dms ipc` for everything the own bar does not
  own yet; `docs/dms.md` and the hotkey overlay titles are updated per
  phase, not up front.
- `docs/shell.md` (new, written with the bar scaffold) becomes the index for
  the own bar: layout, how to switch, how colours arrive, how to add a
  widget. `docs/dms.md` keeps describing the service layer.

## Alternatives considered

- **Stay on DMS and accept the ceiling.** Rejected: the wish list is the
  shell's shape, which no setting or plugin reaches, and it has not shrunk
  after two weeks of use.
- **Fork DMS through `DMS_SHELL_DIR`.** Rejected again as in ADR-0013: a
  full tree rebased on a project that released three times in one month.
- **Replace DMS entirely with an own shell in one go.** Rejected: it means
  owning notifications, OSD, polkit, theming, and idle handling before the
  bar even exists, with no way back except reinstalling the old setup.
- **Hide the DMS bar at runtime with `dms ipc call bar hide`.** Rejected as
  the switch mechanism: it does not survive a DMS restart and DMS still
  creates the layer surface; the settings flag is persistent and removes
  the window.
- **Put the session switch on the lock screen only.** Rejected: a lock
  cannot start another session, and a cold boot still needs the greeter to
  offer the choice. The switch belongs in both with different semantics.
