# ADR-0007: Start Noctalia as a systemd user service

- Status: Accepted
- Date: 2026-09-21

## Context

Niri runs as `niri.service` in the systemd user session on CachyOS, started by
`niri-session` from SDDM. Noctalia was started twice: once through
`spawn-at-startup "noctalia"` in the managed Niri configuration and once
through an unmanaged `~/.config/systemd/user/noctalia.service` wanted by
`niri.service`. Whichever instance started second failed with "noctalia is
already running", and the service entered a short restart loop until it won.
The `noctalia` package does not ship a user unit of its own.

## Decision

Start Noctalia only from a repository-owned systemd user unit,
`~/.config/systemd/user/noctalia.service`, enabled through a chezmoi-managed
relative symlink in `niri.service.wants/`. The unit is bound to `niri.service`
so it starts after Niri has notified readiness and stops with the compositor,
and it restarts Noctalia on failure. The Niri `autostart.kdl` fragment no
longer spawns Noctalia.

## Consequences

- One Noctalia instance per session; no startup failures in the journal.
- Crashes are recovered by systemd and logs are available through
  `journalctl --user -u noctalia.service`.
- Restarting the shell is `systemctl --user restart noctalia.service`; the
  ad-hoc `noctalia-reset` shell function that killed the process and ran
  `noctalia --daemon` conflicts with the unit and must be replaced.
- Noctalia's `started` hook and IPC behave as before; only the launcher
  changed.
- Sessions that start Niri outside systemd (a plain `niri` binary without
  `niri-session`) will not start Noctalia automatically.

## Alternatives considered

- **Keep `spawn-at-startup` only:** simplest, but no crash recovery or
  journal integration, and the shell dies silently when it exits.
- **Keep both:** works by accident because Noctalia refuses to start twice,
  but produces failures and a restart loop on every login.
- **`WantedBy=graphical-session.target`:** the conventional target for
  session services, but binding to `niri.service` directly matches how the
  CachyOS Niri session is wired and stops Noctalia precisely with Niri.
