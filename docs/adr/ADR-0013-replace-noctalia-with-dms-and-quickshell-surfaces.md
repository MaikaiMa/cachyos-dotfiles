# ADR-0013: Replace Noctalia with DankMaterialShell and repository-owned Quickshell surfaces

- Status: Accepted (2026-09-22); DMS is the deployed shell
- Date: 2026-09-21
- Supersedes: ADR-0002, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0011

## Context

The CachyOS "Niri / Noctalia" profile ships Noctalia 5, a native C++ shell
configured through TOML and extended through a Luau plugin API. Everything the
API does not expose is unreachable without a fork. After ADR-0002 through
ADR-0011 the repository carries roughly 1600 lines of Noctalia configuration,
a 765-line Luau dashboard panel, and three helper scripts, and every one of
the remaining wishes still sits outside the API:

- a lock screen with stacked, content-sized components instead of absolute
  placement;
- notification and running-app indicators on the bar's application icons;
- capsule styling inside a capsule group, and a bar background that reacts to
  playing audio rather than a desktop-layer underlay (ADR-0005);
- a session greeter with a session picker that matches the lock screen and
  derives its palette from the wallpaper.

The constraints for a replacement are fixed: no fork of anything, small
repository-owned components are acceptable, official Arch or CachyOS packages
where possible, wallpaper-derived colors everywhere, and the whole desktop must
be reproducible from this repository on a fresh machine.

Facts that drove the choice (verified 2026-09-21):

- DankMaterialShell (DMS) 1.6.2 is packaged in the official Arch `extra`
  repository as `dms-shell` with a `dms-shell-niri` variant. It is a Quickshell
  configuration with a Go daemon, has native Niri IPC, a control center,
  notifications, launcher, OSD, clipboard, polkit agent, and wallpaper theming
  through matugen. Its plugins are QML and may add bar widgets, control-center
  panels, launcher items, desktop widgets, and daemons. Plugins are additive;
  they cannot replace or hide built-in widgets.
- Since 1.6 the stable DMS package embeds its QML tree in the binary. The
  official override, `-c <dir>` or `DMS_SHELL_DIR`, expects a complete shell
  tree. Patching one component therefore means carrying the whole tree and
  rebasing it on every release; DMS released three times in September 2026.
- Quickshell 0.3.1 is in `extra` and ships the modules a lock screen and a
  greeter need: `Quickshell.Services.Pam`, `Quickshell.Services.Greetd`,
  `Quickshell.Wayland` (session lock), `Mpris`, `UPower`, `Notifications`,
  and `Pipewire`. It releases about twice a year; 0.3 was announced as
  non-breaking and migration guides are promised before 1.0.
- Niri enforces the lock through `ext-session-lock`. If the lock client dies,
  the session stays locked and shows a solid color. A crashing locker can
  therefore lock the user out but never exposes the session.
- Open DMS issues on Niri cluster around its built-in lock screen and
  sleep/resume; the bar, control center, and Niri integration are stable.

## Decision

1. **DMS is the desktop shell.** Install `dms-shell-niri` from `extra`. It
   owns the bar, control center, notifications, launcher, OSD, clipboard
   history, and the polkit agent. It starts from its packaged systemd user
   unit, wanted by `niri.service` in the same way ADR-0007 wired Noctalia.
2. **Extend DMS only through its plugin API.** Repository-owned QML plugins
   provide the application-icon indicators (running dot in the primary color
   below, notification dot above) and the dashboard panel. Plugins declare
   `requires_dms` and live under the chezmoi-managed plugin directory together
   with DMS's `plugins.lock.json`. Overriding the embedded QML tree is
   rejected as a fork.
3. **Lock screen and greeter are repository-owned Quickshell configurations.**
   A single source directory, `~/.config/quickshell/session/`, contains the
   shared components plus a `lock` and a `greeter` entry point. The lock uses
   Quickshell's session-lock and PAM modules; the greeter uses its greetd
   module and is deployed to a system path by ADR-0014. DMS's built-in lock
   screen and greeter are not used. Idle management points at this locker.
4. **matugen is the single palette source.** DMS drives matugen from the
   wallpaper; repository-owned matugen templates render the Niri colors
   (replacing the Noctalia `niri` template of ADR-0002), the Z13 rear-window
   color (replacing ADR-0004), and a palette file consumed by the lock and
   greeter. Wallpaper paths and rendered palettes stay out of Git.
5. **Stay on the CachyOS profile baseline.** `cachyos-niri-noctalia` remains
   installed because it provides the portals, `xwayland-satellite`, fonts,
   and GTK theme (ADR-0009). Noctalia itself stays on disk unused; chezmoi
   removes its user-service wiring and all managed Noctalia files through
   `.chezmoiremove` so a fresh machine and this machine converge.
6. **Everything reproducible from the repository.** User-level pieces are
   chezmoi-managed. System-level pieces (greetd, PAM) live under `system/`
   with idempotent scripts that the user runs with sudo. Packages are recorded
   in the manifests. Fallbacks (`swaylock`) are recorded as well.

## Consequences

- The visual freedom that Noctalia lacked exists exactly where it was needed:
  lock screen, greeter, and the two plugin surfaces. The DMS bar container and
  built-in widgets keep DMS's Material look; a bar background that reacts to
  audio is limited to what DMS's own cava visualizer widget offers.
- DMS releases weekly and gives no stability guarantee on its plugin API. The
  repository plugins are the piece most likely to need small fixes after an
  update. Quickshell changes are rare and come with migration guides.
- A crash in the repository locker leaves the screen locked with a solid
  color. Mitigations are mandatory: a `Restart=on-failure` user unit, a Niri
  bind with `allow-when-locked=true` that restarts it, and `swaylock` as a
  recorded fallback reachable from a TTY.
- Two Quickshell processes run when the screen is locked (DMS and the
  locker); memory cost is modest and accepted.
- ADR-0002, 0004, 0005, 0006, 0007, and 0011 become Superseded once phase 2
  of the migration lands. Their files stay for history.
- `tests/validate.sh` loses its `noctalia` tool requirement and gains
  `qmllint` for the QML directories.
- Phase 1 of the plan is the go/no-go for phase 2; the trial runs outside
  the repository and is reversible with one service switch.

## Alternatives considered

- **Stay on Noctalia and add `noctalia-greeter`:** solves the login screen
  from the CachyOS repository within an hour, but none of the shell limits.
- **DMS with a patched QML tree via `DMS_SHELL_DIR`:** officially supported
  switch, but it is a full-tree fork rebased weekly.
- **A complete custom Quickshell shell:** maximum freedom, months of work,
  single maintainer. Kept as the escape hatch for one surface at a time,
  which is what decision 3 does for lock and greeter.
- **Keep Noctalia's lock screen or DMS's lock screen:** both are the surface
  with the most limits and, for DMS on Niri, the most open issues.
- **Remove `cachyos-niri-noctalia`:** would require recording its
  dependencies by hand and moves the machine away from the profile baseline
  for no functional gain.

## Review after the first evening (2026-09-21)

The stock DMS trial solved none of the listed problems and looked less like
the desired desktop than the Noctalia setup it replaced. That was expected
for an unconfigured shell, but the plan asked the user to work in it for a
week before anything was built. That order was wrong: nothing is evaluated on
the live desktop before it is polished to a testable state.

The recommendation itself also had a flaw in its reasoning, recorded here so
it is not repeated:

- The constraints (simple, no fork, close to CachyOS) were used as the first
  filter and the requirement list as the second. Constraints describe how a
  solution may look; they do not make a partial solution better than keeping
  what worked. The requirement list is the goal and filters first.
- The first advice assumed DMS's QML is editable on disk. It is embedded in
  the binary since 1.6. When that surfaced, the decision was adjusted around
  the new fact instead of reopened.
- The user had said the Noctalia bar and dashboard were already good. An
  option that gives those up to gain other items had to be presented as a
  trade-off for the user to weigh, not as a net gain.

Consequences of the review:

- DMS stays as the interim shell and is configured and extended first
  (settings for the mat-glass look, an application-icon widget with running
  and notification dots, a dashboard popout). The user evaluates only the
  polished result.
- The known ceiling stands: the bar container, the built-in lock screen and
  the panel styling cannot be changed without a fork. If that ceiling is
  unacceptable after evaluation, the follow-up is a repository-owned
  Quickshell shell, the option this record dismissed as too large. That
  decision, if taken, gets its own ADR and supersedes this one.

## Update 2026-09-22

The polished DMS setup from phase 1 was accepted after evaluation: the bar,
dashboard, and application indicators are close enough to the reference to
live with. Phase 2 of `docs/desktop-migration.md` makes DMS the deployed
default, moving the shell, its plugins, and matugen theming into the
chezmoi-managed tree; the Noctalia configuration this ADR describes is no
longer deployed and is preserved only as the `noctalia-final` Git tag. A
repository-owned lock screen and greeter (ADR-0014) remain the next steps.
The ceiling noted in the review above still stands: the DMS bar container,
its built-in lock screen, and its panel styling cannot be changed without a
fork.
