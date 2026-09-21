# Desktop migration: Noctalia to DMS, Quickshell lock screen, greetd

This plan implements [ADR-0013](adr/ADR-0013-replace-noctalia-with-dms-and-quickshell-surfaces.md)
and [ADR-0014](adr/ADR-0014-replace-sddm-with-greetd-and-the-quickshell-greeter.md).
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
| Niri keybinds and includes | `chezmoi/dot_config/niri/` | `~/.config/niri/` | 2, 4 |
| matugen config and templates | `chezmoi/dot_config/matugen/` | `~/.config/matugen/` | 2 |
| Z13 rear-window color helper | `chezmoi/dot_local/bin/executable_sync-z13-window-color` | `~/.local/bin/` | 2 |
| Repository plugins for DMS | `chezmoi/dot_config/DankMaterialShell/plugins/` | `~/.config/DankMaterialShell/plugins/` | 3 |
| Lock screen and greeter QML | `chezmoi/dot_config/quickshell/session/` | `~/.config/quickshell/session/` | 4, 5 |
| Locker and idle user units | `chezmoi/dot_config/systemd/user/` | `~/.config/systemd/user/` | 4 |
| greetd, Niri greeter config, PAM | `system/greetd/`, `system/pam.d/greetd` | `/etc/greetd/`, `/etc/pam.d/greetd` | 5 |
| greetd installer | `scripts/setup-greetd.sh` | runs with sudo | 5 |
| Greeter theme sync helper | `chezmoi/dot_local/bin/executable_sync-greeter-theme` | `/var/lib/greeter/` | 5 |
| Packages | `packages/pacman.txt`, `packages/aur.txt` | pacman, paru | 2, 4, 5 |

Generated files never enter Git: matugen output, DMS runtime state, the
synced wallpaper and palette under `/var/lib/greeter/`, and the extracted
DMS shell tree.

## Phase 0: decision records

Done in the same change as this plan: ADR-0013, ADR-0014, and this document.
No configuration changes.

## Phase 1: DMS trial next to Noctalia

Goal: decide whether DMS feels right before touching the repository.

Agent provides the temporary `scripts/dms-trial.sh`, with a keybind shim
installed at `~/.local/bin/noctalia` that forwards the existing Noctalia
keybinds to DMS IPC calls. `~/.local/bin` is first in the PATH Niri uses to
spawn keybind commands, so the shim intercepts `noctalia msg ...` without
touching the Niri config. Both the script and the shim are removed in
phase 2.

You: install and switch services for the trial. Do not run `dms setup` or
`dms sync`; they write into the live Niri configuration.

```fish
./scripts/dms-trial.sh install
```

```fish
./scripts/dms-trial.sh start
```

The wallpaper keybind opens the DMS settings wallpaper tab as a best-effort
mapping; every other keybind maps directly to the equivalent DMS surface.

Switch back at any time:

```fish
./scripts/dms-trial.sh stop
```

Done when, after about a week: the bar, control center, launcher, and
notifications feel good enough to build on; wallpaper theming works; the
Niri workspace integration behaves; and nothing blocks daily work. Note every
irritation, and separate "plugin can fix this" from "DMS built-in". The
built-in lock screen is not part of the verdict; phase 4 replaces it.

Verdict: passes, phase 2 starts. Fails, the trial is reverted with the
command above and ADR-0013 is amended with the reasons before any other
approach is tried.

## Phase 2: move the shell into the repository

Goal: a fresh bootstrap yields DMS, not Noctalia, and this machine converges
to the same state.

Agent delivers:

- `packages/pacman.txt`: add `dms-shell-niri`, `quickshell`, `matugen`,
  and `cava` (DMS's optional audio visualizer). Remove the `noctalia` line;
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
- `chezmoi/dot_config/niri/cfg/keybinds.kdl`: every `noctalia msg` bind
  becomes the `dms ipc` equivalent. The lock bind keeps calling DMS until
  phase 4.
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

## Phase 4: repository-owned lock screen

Goal: a lock screen with the layout and look of the target design, that
cannot lock you out.

Agent delivers:

- `chezmoi/dot_config/quickshell/session/` with shared components (palette
  loader for the matugen output, clock, media card, user card, session info),
  a `lock/shell.qml` entry using `WlSessionLock` and `PamContext`, and a
  `greeter/shell.qml` entry that phase 5 wires up.
- A matugen template that renders the palette to
  `~/.config/quickshell/session/generated/palette.json`; the directory is
  ignored by chezmoi.
- `chezmoi/dot_config/systemd/user/session-lock.service` with
  `Restart=on-failure`, started on demand. `swayidle` (or DMS's idle hook if
  it accepts a custom lock command; the agent verifies which) triggers it on
  idle and before sleep.
- Keybinds: `Mod+Alt+L` starts the unit and carries `allow-when-locked=true`
  so it also relaunches the locker on the solid-color screen. DMS's own lock
  is disabled in the seed settings.
- `packages/pacman.txt`: `swaylock` as the recorded fallback, `swayidle` if
  used.
- Docs: `docs/lockscreen.md` with the recovery drill; `tests/validate.sh`
  runs `qmllint` over the session tree.

You: apply, then run the tests that need a person present. Lock and unlock
with the keyboard; press a physical key on the lock screen; close and open
the lid; leave it to sleep overnight; and run the recovery drill once: kill
the locker from a TTY, confirm the screen stays locked, press `Mod+Alt+L`,
confirm the locker returns, and unlock.

```fish
systemctl --user start session-lock.service
```

Fallback from a TTY if the locker will not start:

```fish
env WAYLAND_DISPLAY=wayland-1 swaylock
```

Done when: all tests above pass twice on separate days.

## Phase 5: greetd with the repository greeter

Goal: the login screen is the lock screen with a session picker.

Agent delivers:

- `system/greetd/config.toml`, `system/greetd/niri.kdl` (minimal Niri config
  that spawns the greeter entry point and exits with it), and
  `system/pam.d/greetd` carrying the `pam_gnome_keyring.so` lines from
  `/etc/pam.d/sddm`.
- `scripts/setup-greetd.sh`: idempotent, `--dry-run` capable; installs the
  files, copies `~/.config/quickshell/session/` to
  `/etc/greetd/quickshell/session/`, creates `/var/lib/greeter/` owned by
  the `greeter` group, adds the user to that group, validates the Niri
  config and runs `qmllint` on the copied tree, and only then disables SDDM
  and enables greetd. It never removes SDDM.
- `executable_sync-greeter-theme`: copies the current wallpaper and palette
  into `/var/lib/greeter/`; invoked after a palette change, and the
  maintenance guide lists it.
- `packages/pacman.txt`: `greetd`. `tests/setup-greetd.sh` exercising the
  dry-run against a temporary root.
- Docs: `docs/greeter.md` including the rollback from a TTY and the Big
  Picture session note.

You: dry-run first, read it completely, then install and reboot. Before the
reboot, make sure you can reach a TTY and have the rollback in front of you.

```fish
sudo ./scripts/setup-greetd.sh --dry-run
```

```fish
sudo ./scripts/setup-greetd.sh
```

Rollback from a TTY:

```fish
sudo systemctl disable greetd; and sudo systemctl enable sddm; and sudo reboot
```

Done when: login works with the keyboard, GNOME Keyring is unlocked after
login (an SSH signature does not prompt for the keyring), the last session
is remembered, and, once `gamescope-session-cachyos` is installed, the Big
Picture session appears in the picker.

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
