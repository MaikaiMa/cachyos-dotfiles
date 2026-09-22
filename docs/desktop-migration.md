# Desktop migration: Noctalia to DMS, greetd with the DMS greeter

This plan implements [ADR-0013](adr/ADR-0013-replace-noctalia-with-dms-and-quickshell-surfaces.md)
and [ADR-0015](adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md).
DMS's own built-in lock screen stays; there is no repository-owned Quickshell
lock screen. The login screen is greetd running the DMS greeter
(`dms-greeter`), not repository-owned greeter QML; see
[docs/greeter.md](greeter.md).

It is written for a split workflow: an AI agent prepares every repository
change, the user reviews the diff, runs the privileged or session-affecting
commands, tests on the machine, and commits. Each phase is one reviewable
change and ends in a state the desktop can stay in.

Rules that apply to every phase:

- The agent changes only the repository. Nothing is applied, installed,
  enabled, or committed by the agent.
- Every phase ends with `git diff --check`, `tests/validate.sh`, and
  `scripts/bootstrap.sh --dry-run --no-pager`. The agent reports the dry-run
  output verbatim.
- Removals go through `chezmoi/.chezmoiremove` so a fresh machine and this
  machine converge. Nothing is deleted from the live home by hand.
- New QML passes `qmllint` and a `qs -c <dir>` load test before review.
- Packages are recorded in the manifests in the same change that starts to
  depend on them.

## Where everything lives

| Piece | Repository path | Live path | Phase |
| --- | --- | --- | --- |
| DMS settings seed and plugin lock | `chezmoi/dot_config/DankMaterialShell/` | `~/.config/DankMaterialShell/` | 2 |
| DMS service wiring | `chezmoi/dot_config/systemd/user/niri.service.wants/symlink_dms.service` | `~/.config/systemd/user/niri.service.wants/dms.service` | 2 |
| Noctalia removals | `chezmoi/.chezmoiremove` | Noctalia files and service symlink | 2 |
| Niri keybinds and includes | `chezmoi/dot_config/niri/` | `~/.config/niri/` | 2 |
| matugen config and templates | `chezmoi/dot_config/matugen/` | `~/.config/matugen/` | 2 |
| Z13 rear-window color helper | `chezmoi/dot_local/bin/executable_sync-z13-window-color` | `~/.local/bin/` | 2 |
| Repository plugins for DMS | `chezmoi/dot_config/DankMaterialShell/plugins/` | `~/.config/DankMaterialShell/plugins/` | 3 |
| greetd config | `system/greetd/config.toml` | `/etc/greetd/config.toml` | 5 |
| greetd PAM stack | `system/pam.d/greetd` | `/etc/pam.d/greetd` | 5 |
| Quiet Niri session entry | `system/wayland-sessions/niri.desktop` | `/usr/local/share/wayland-sessions/niri.desktop` | 5 |
| Quiet Niri session wrapper | `system/local/bin/niri-session-quiet` | `/usr/local/bin/niri-session-quiet` | 5 |
| greetd and dms-greeter installer | `scripts/setup-greetd.sh` | runs as the user, escalates with sudo per step | 5 |
| greetd installer test | `tests/setup-greetd.sh` | n/a | 5 |
| Login screen guide | `docs/greeter.md` | n/a | 5 |
| Packages | `packages/pacman.txt`, `packages/aur.txt` | pacman, paru | 2, 5 |

Generated files never enter Git: matugen output, DMS runtime state, the
`dms-greeter` cache and per-user symlinks under `/var/cache/dms-greeter/`,
the extracted Niri greeter config under `/etc/greetd/niri/`, and the
extracted DMS shell tree.

## Phase 0: decision records

Done in the same change as this plan: ADR-0013, ADR-0014, and this document.
No configuration changes.

## Phase 1: polish DMS, then evaluate

Done (2026-09-22): the polished look and the two plugins were accepted after
evaluation; see ADR-0013's 2026-09-22 update.

Goal: bring DMS to a state that can be judged fairly against the previous
desktop before the user works in it. The order of the first attempt, a week
in an unconfigured shell, is recorded as a mistake in ADR-0013's review.

Agent delivers, in parallel and outside the chezmoi tree until accepted:

- `dms/look.json` and `scripts/dms-apply-look.sh`: DMS settings for the
  mat-glass look, corner radius, bar widget layout mirroring the previous
  bar, audio visualizer, Niri layout overrides off, wallpaper theming;
  documented in `docs/dms.md` so values can change on feedback.
- Plugin `dotfilesApps`: application icons with a primary-color running dot
  and a red notification dot, replacing the built-in running-apps widget.
- Plugin `dotfilesDashboard`: the previous dashboard as a DMS popout.
- The temporary `scripts/dms-trial.sh` with its keybind shim stays until
  phase 2 replaces the keybinds.

You: switch with the trial script, then judge the polished result and give
feedback per surface. Do not run `dms setup` or `dms sync`; they write into
the live Niri configuration.

```fish
./scripts/dms-trial.sh start
```

```fish
./scripts/dms-trial.sh stop
```

Done when: the bar, dashboard and indicators are close enough to the
reference to live with, or the ceiling of ADR-0013 is confirmed as
unacceptable. Passes, phase 2 starts. Fails, the trial is reverted with
`stop` and the follow-up decision gets its own ADR.

## Phase 2: move the shell into the repository

Done (2026-09-22): DMS is the deployed shell from a fresh bootstrap; the
Noctalia configuration this phase replaced is preserved only as the
`noctalia-final` Git tag.

Goal: a fresh bootstrap yields DMS, not Noctalia, and this machine converges
to the same state.

Agent delivers:

- `packages/pacman.txt`: add `dms-shell-niri`, `quickshell`, `matugen`,
  `cava` (DMS's optional audio visualizer), and `kimageformats` (extra Qt
  image formats for wallpapers). Remove the `noctalia` line;
  the binary stays through the profile meta package. Review `playerctl`,
  `imagemagick`, and `noto-fonts` against what still references them and
  remove the ones nothing needs.
- `chezmoi/dot_config/DankMaterialShell/settings.json` seeded from the
  trial's live file after review, and `plugins.lock.json`. DMS rewrites
  `settings.json`; per ADR-0008 that drift is reviewed and promoted or
  reverted, not ignored.
- `chezmoi/dot_config/systemd/user/niri.service.wants/symlink_dms.service`
  pointing at the packaged `/usr/lib/systemd/user/dms.service`. Delete
  `noctalia.service` and its wants symlink from the source tree.
- `chezmoi/.chezmoiremove` listing the Noctalia service symlink, the
  `~/.config/noctalia/` files, the Luau plugin, the generated
  `~/.config/niri/noctalia.kdl`, and the helpers `noctalia-dashboard-state`
  and `sync-noctalia-audio-glow`.
- `chezmoi/dot_config/matugen/config.toml` and templates for the Niri colors
  (rendered to `~/.config/niri/matugen.kdl`) and the Z13 rear-window color.
  `config.kdl` includes `matugen.kdl` instead of `noctalia.kdl`.
- `executable_sync-z13-window-color` reads the matugen output; its test is
  updated. `scripts/bootstrap.sh` drops the `noctalia msg templates-apply`
  step.
- `config.kdl` gains `include optional=true "dms/layout.kdl"`. DMS's settings
  window appends that include itself when it is missing and backs up the
  file, which showed up as chezmoi drift during the trial. The seed
  settings set gaps mode to Off (`niriLayoutGapsOverride` -2) and the
  window radius override to 20 so the generated file does not fight
  `cfg/layout.kdl` and `cfg/rules.kdl`.
- `chezmoi/dot_config/niri/cfg/keybinds.kdl`: every `noctalia msg` bind
  becomes the `dms ipc` equivalent, including the lock bind, which stays on
  DMS's own built-in lock screen (see ADR-0015).
- Fish: `noctalia-reset.fish` becomes a `dms-reset.fish` with the equivalent
  restart, or is dropped if `dms` already offers it.
- `tests/validate.sh`: remove the `noctalia` tool requirement and the
  Noctalia validation lines, update the required-files list, add `qmllint`
  over `chezmoi/dot_config/DankMaterialShell/plugins/` (empty until phase 3).
  Remove `tests/noctalia-audio-glow.sh`.
- Docs: README desktop sections, `docs/maintenance.md` verification list,
  ADR-0002/0004/0005/0006/0007/0011 status lines set to
  "Superseded by ADR-0013", and `docs/noctalia-lockscreen.md` and
  `docs/noctalia-quick-controls.md` removed.
- Remove `scripts/dms-trial.sh` and `tests/dms-trial.sh`; the shim does not
  need a `.chezmoiremove` entry because `./scripts/dms-trial.sh stop` already
  removes it. The trial's `start` must not be active on this machine when
  phase 2 is applied.

You:

```fish
./scripts/bootstrap.sh --dry-run --no-pager
```

Review the dry-run, especially the removals, then apply and switch:

```fish
./scripts/bootstrap.sh; and systemctl --user daemon-reload
```

```fish
systemctl --user stop noctalia.service; and systemctl --user start dms.service
```

```fish
./scripts/check-packages.sh
```

Done when: `chezmoi status` is clean apart from DMS-written drift, the Niri
keybinds work, the Niri focus ring and the Z13 rear window follow a wallpaper
change, and a re-login starts DMS without Noctalia.

Rollback: `git stash` the change, run the bootstrap again, start
`noctalia.service`. Nothing in this phase touches system files.

## Phase 3: repository plugins for DMS

Done (2026-09-22): all four plugins (`dotfilesLauncher`, `dotfilesWorkspaces`,
`dotfilesApps`, `dotfilesDashboard`) are built, enabled, and deployed. A code
review pass over the plugin QML remains.

Goal: the two features that Noctalia could not provide and DMS can host.

Agent delivers, under `chezmoi/dot_config/DankMaterialShell/plugins/`:

- `dotfiles-apps`: a bar widget plugin that lists running and pinned
  applications with a primary-color dot under running apps and a red dot
  above apps that have an entry in the notification list. It replaces DMS's
  built-in taskbar widget in the bar layout; the built-in stays available.
- `dotfiles-dashboard`: a control-center panel with the media, brightness,
  audio, quick-toggle, battery, and power-profile controls of the former
  Noctalia dashboard, reading state through DMS services instead of the old
  helper script.
- Both declare `requires_dms` at the version installed, ship a `README.md`,
  and are listed in `plugins.lock.json`. `tests/validate.sh` runs `qmllint`
  on them.
- A check whether DMS's built-in cava visualizer widget in the bar covers the
  audio-glow role of ADR-0005. If it does, enable it in the seed settings; if
  not, note the gap in the README rather than building an underlay.

You: apply, reload plugins, and judge the visuals:

```fish
./scripts/bootstrap.sh; and dms ipc call plugins reload dotfiles-apps
```

Expect several short rounds here; the agent can inspect Niri screenshots,
but the final look is your call.

Done when: both plugins load after a DMS restart, indicators match the
notification list, and the dashboard shows real state for every control.

## Phase 4: repository-owned lock screen (dropped, 2026-09-22)

DMS's own built-in lock screen is acceptable as is. The only things a
repository-owned locker would have bought were the clock-to-input spacing and
a compact media row, and both are hard-coded in DMS's embedded QML, out of
reach without forking it. A custom `WlSessionLock` implementation was judged
too much to build and maintain for that gain. See
[ADR-0015](adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md).

## Phase 5: greetd with the DMS greeter

Done (2026-09-22): the repository pieces are delivered; switching the boot
path is a user step, done per machine.

Goal: the login screen matches the desktop's look and keyboard layout, without
building a second implementation of the lock screen. [ADR-0015](adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md)
replaces the repository-owned greeter QML of ADR-0014 with `dms-greeter`
(AUR `greetd-dms-greeter-bin`), which renders DMS's own greeter UI and syncs
itself from the live DMS and Niri configuration; see
[docs/greeter.md](greeter.md) for the mechanism and the full walkthrough.

Agent delivers:

- `system/greetd/config.toml`: starts `dms-greeter` as the `greeter` user
  under its own Niri session.
- `system/pam.d/greetd`: Arch's default `greetd` PAM stack plus the
  `pam_gnome_keyring.so` auth/password/session lines from `/etc/pam.d/sddm`,
  authoritative because `dms/look.json` sets `greeterPamExternallyManaged`.
- `scripts/setup-greetd.sh` (`--dry-run`, `--switch`): idempotent; installs
  `greetd`, `acl`, and `greetd-dms-greeter-bin` when missing, installs the
  two system files when they differ, runs `dms-greeter sync --yes`,
  validates the generated Niri greeter config, and prints
  `dms-greeter status`. Only `--switch` disables SDDM and enables greetd,
  and never with `--now`.
- `tests/setup-greetd.sh`, exercised by `tests/validate.sh`, against fake
  binaries.
- `packages/pacman.txt`: `greetd`, `acl`. `packages/aur.txt`:
  `greetd-dms-greeter-bin`.
- Docs: `docs/greeter.md` with the install order, the verification
  checklist, the rollback, and known limits.

You: follow the order in [docs/greeter.md](greeter.md) — apply the look if it
changed, dry-run, read it, run it for real, log out and back in once, preview
with `dms-greeter run`, then switch and reboot with the rollback line ready
on a second device.

```fish
./scripts/setup-greetd.sh --dry-run
```

```fish
./scripts/setup-greetd.sh
```

```fish
./scripts/setup-greetd.sh --switch
```

Rollback from a TTY:

```fish
sudo systemctl disable greetd; and sudo systemctl enable sddm; and sudo reboot
```

Done when: the verification checklist in `docs/greeter.md` passes after the
first reboot into greetd.

## Phase 6: cleanup

Goal: nothing Noctalia-specific remains that a fresh machine would not need.

Agent delivers: a sweep of the manifests with `scripts/check-packages.sh`,
removal of references to Noctalia from README and guides except the
superseded ADRs, and a final read of `tests/validate.sh` for stale
required files.

You:

```fish
./scripts/check-packages.sh
```

Done when: validation passes, the dry-run is empty, and the README describes
the desktop as it is.
