# ADR-0021: Let logind handle the power key

- Status: Accepted
- Date: 2026-09-24

## Context

niri takes logind's `handle-power-key` inhibitor and suspends on a short
power-key press itself. After a resume, niri also receives the press that
woke the system and suspends again straight away (upstream
[niri-wm/niri#2233](https://github.com/niri-wm/niri/issues/2233), open; the
candidate fix, PR #3773, is not merged). The journal shows every wake as
"Power key pressed short" followed in the same second by a suspend request
from niri. With the Z13 keyboard detached the power button is the only way to
wake the device, so it loops; with the keyboard attached it only stays awake
while keys are pressed.

logind's default for a short press is `HandlePowerKey=poweroff`, so disabling
niri's handling alone would turn a short press into a shutdown.

## Decision

- `disable-power-key-handling` in niri's `input` section
  (`chezmoi/dot_config/niri/cfg/input.kdl`) stops niri from taking the
  inhibitor and reacting to the key.
- A logind drop-in, `system/logind.conf.d/50-power-key.conf`, sets
  `HandlePowerKey=suspend` and nothing else. logind does not act on the press
  that woke the system, which is the workaround confirmed in the upstream
  issue.
- `scripts/setup-power-key.sh` installs the drop-in in
  `/etc/systemd/logind.conf.d/` and reloads logind, never restarts it, since a
  restart can end the running session. `scripts/bootstrap.sh` runs it before
  applying chezmoi, so the niri change never lands without the drop-in.
- The greeter's niri gets the same `input` section through
  `./scripts/setup-greetd.sh`, so logind also suspends at the login screen.

## Consequences

- A short press suspends everywhere, handled by logind; a long press keeps
  logind's default.
- The drop-in is a system file outside chezmoi; bootstrap's dry-run reports
  when it would be installed.
- Both halves are a workaround. Remove `disable-power-key-handling` and the
  drop-in once niri fixes #2233, then re-sync the greeter.

## Alternatives considered

- **Patched niri with PR #3773**: fixes the cause, but means pinning a custom
  niri build, rejected for the same reasons as in ADR-0020.
- **`disable-power-key-handling` alone**: a short press would power off.
- **`HandlePowerKey=ignore` with a niri bind**: niri would still see the
  wake press through the bind and suspend again.
