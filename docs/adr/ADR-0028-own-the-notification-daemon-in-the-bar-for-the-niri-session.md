# ADR-0028: Own the notification daemon in the bar for the Niri session

- Status: Accepted
- Date: 2026-10-08
- Amends: [ADR-0027](ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)
  (decision 1 "DMS keeps notifications" is withdrawn for the Niri session;
  everything else in that ADR stands)

## Context

The own bar (ADR-0027) is the daily bar since 2026-10-07, but its
notifications are second-hand. DMS owns the freedesktop notification
daemon, so the bar can only read DMS's history file
(`~/.cache/DankMaterialShell/notification_history.json`) and emulate the
rest: popups are DMS-styled and appear outside the bar's design, dismiss is
remembered in a state file because DMS's IPC cannot remove a history entry,
actions and inline reply are unreachable, and do not disturb is a `dms ipc`
call whose state the bell only mirrors. Every other surface the bar shows
is its own; notifications are the last piece that still looks and behaves
like DMS.

Facts verified on 2026-10-07 by reading the shipped QML and units, and
re-checked on 2026-10-08 against the installed DMS 1.6.2 and Quickshell
0.3.1:

- DMS cannot be told to give up `org.freedesktop.Notifications`. Its
  `NotificationServer` is created unconditionally, with no setting and no
  IPC to disable it. The name is claimed with Qt's `registerService`,
  which neither queues nor replaces: the first process to register wins
  while it lives. The loser logs "Could not register notification server
  at org.freedesktop.Notifications, presumably because one is already
  registered" and runs on, but Quickshell retries when the name frees
  ("Registration will be attempted again if the active service is
  unregistered"). That is true of DMS as much as of the bar, because DMS
  is Quickshell too. Verified on 2026-10-10 from the bar's journal and a
  live `busctl --user status` after a bar restart. This replaces the first
  reading of 2026-10-07, which held that the loser never gets the name.
- The packaged `dms.service` is `Type=dbus` with
  `BusName=org.freedesktop.Notifications`, so systemd treats DMS as
  started only once it holds the name. `quickshell-bar.service` is
  `After=dms.service` today (for the palette file), so DMS always wins.
- Quickshell's `NotificationServer` offers what the specification has:
  actions with icons, inline reply, images, markup, urgency, transient and
  resident hints, expire timeouts, tracked notifications, dismiss and
  expire with close reasons. It offers nothing above the specification: no
  persistence, no timers, no do not disturb, no sounds. A bar that owns
  the daemon must add those itself.
- What DMS loses when it loses the name: its popups, its history file
  (the bar's only source today, `services/Notifications.qml`), do not
  disturb and its IPC, notification sounds, and its per-app notification
  rules. DMS's lock-screen notifications are off by DMS's own default
  (`lockScreenNotificationMode` 0 in its SettingsData; `dms/look.json` does
  not override it), so the lock loses nothing visible.
- DMS is also a notification client. The Go side of the `dms` binary
  calls `Notify`, keeps the returned id and listens for `ActionInvoked`
  (strings in the shipped binary), so DMS's own notifications (updates,
  network, Bluetooth and similar prompts) will arrive at whichever daemon
  holds the name and their actions must find their way back to DMS.
  Quickshell's server emits `ActionInvoked` for any sender.
- No D-Bus activation file for `org.freedesktop.Notifications` exists on
  the system (only GNOME's own `org.gnome.Shell.Notifications`), so
  nothing gets auto-spawned in the gap before the daemon is up; a `Notify`
  in that gap fails exactly as it does today before DMS is up.
- The Steam session (ADR-0022, ADR-0023) runs gamescope without DMS and
  without the bar; it handles its own notifications and is untouched by
  anything here.
- The repository already manages systemd drop-ins for packaged units
  (`mobi.phosh.OSK.service.d`, `gamescope-xbindkeys.service.d`), so a
  drop-in for `dms.service` follows an existing pattern.

The constraints from ADR-0013 and ADR-0027 stand: no fork of DMS or
Quickshell, official packages, the DMS bar must stay available as the
fallback in one step. Decisions already taken with the user on
2026-10-08: popups appear as island peeks in the manner of the now-playing
peek, the right-island bell keeps its role, and do not disturb moves into
the bar.

## Decision

1. **In the Niri session the bar is the notification daemon.** The bar's
   `Notifications` service becomes a `Quickshell.Services.Notifications`
   `NotificationServer` instead of a reader of DMS's history file. The
   decision is scoped to the Niri session where the own bar runs: the
   Steam session is out of scope, and the lock screen and greeter get
   their own ADR. Whatever that later ADR decides, notifications on the
   lock screen are private: none, or a count at most, never content.
2. **The D-Bus name moves with the systemd readiness, not by racing, and
   the bar never dies for it.** `quickshell-bar.service` stays
   `Type=simple`, gets `Before=dms.service`, and waits for the name in a
   non-fatal readiness step:

   ```
   ExecStartPost=-gdbus wait --session --timeout 30 org.freedesktop.Notifications
   ```

   A chezmoi-managed drop-in `dms.service.d/` makes `dms.service`
   `Type=simple`; its packaged `BusName=` stays, because systemd rejects an
   empty `BusName=` ("Invalid bus name, ignoring", verified with
   `systemd-analyze --user verify` on 2026-10-08) and only `Type=dbus`
   waits for the name anyway. With the wait step and the ordering, systemd
   does not fork DMS before the bar holds the name (or thirty seconds have
   passed), so a normal login is deterministic. The drop-in also sets
   `PartOf=quickshell-bar.service` (added 2026-10-10): a stop or restart
   of the bar propagates to DMS, and with `Before=` DMS stops before the
   bar stops and starts again after the bar holds the name, so
   `systemctl --user restart quickshell-bar.service` keeps the name with
   the bar. If the bar cannot register (a QML
   error, DMS already holding the name after an unusual restart order),
   the leading `-` ignores the wait's failure, DMS starts and claims the
   name as before, and the bar keeps running as a bar: the failure mode
   is the old behaviour, never a session without a bar. `Type=dbus` on
   the bar unit was rejected for exactly that reason: it would fail the
   unit when the name is taken, and `Restart=on-failure` would exhaust the
   start limit and leave the session without a bar. The bar's
   `After=dms.service` for the palette file goes; the bar already watches
   that file and must keep tolerating it arriving later. Whether
   Quickshell's `NotificationServer` registers the name the moment it is
   created is a C++ detail not read for this ADR; the wait step covers
   either answer, but the build must confirm it with `busctl --user
   status org.freedesktop.Notifications` on a cold login.
3. **`scripts/bar-switch.sh` owns the order of restarts.** `own` stops
   DMS, restarts the bar (a bar that started after DMS holds no name, so
   starting it is not enough), then starts DMS; `dms` stops the bar and
   restarts DMS so the DMS bar gets its daemon back. The drop-in stays
   installed in both modes: with the bar stopped, DMS registers the name
   exactly as today, only systemd's notion of "started" changes. `status`
   reports which process owns the name (`busctl --user status`), because
   the bar cannot easily tell you itself. Recovery from any state is
   `scripts/bar-switch.sh dms`, one command, documented in
   `docs/shell.md`. `PartOf=` does not cover an automatic restart after a
   bar crash (`Restart=on-failure` is not a restart job that propagates):
   after a crash DMS may take the name in the gap and keeps it until
   `scripts/bar-switch.sh own` is run, which restores the order. `status`
   shows the owner, `quickshell` or `dms` (DMS's process is called `qs`,
   so the script reads its command line).
4. **The bar adds what the specification does not give.** Before the daily
   switch the bar must have: its own history in
   `$XDG_STATE_HOME/dotfiles-bar/` (the existing dismiss state file grows
   into the history file; the DMS history is not imported), expiry timers
   that honour `expireTimeout` and urgency, do not disturb held in the bar
   with the bell's right click and an IPC function for keybinds (critical
   notifications still peek), and popups as island peeks with the real
   actions, inline reply where the sender asks for it, and a real dismiss
   that closes the notification with the proper reason, and action
   routing that works for every sender, DMS's own Go side included. Sounds
   and per-app rules are not carried over; they return as separate changes if they are
   missed in use.
5. **The peek, the history and the DND rules are specified in
   `docs/shell-design.md` before they are built**, as every other bar
   surface was: which notifications peek, for how long, how they stack,
   what happens while a panel is open, the bar is hidden, reduce motion is
   on, or the session is locked (no peeks, the count waits for the
   unlock). Acceptance before `bar-switch.sh own` becomes the daily state
   with the daemon: a cold login lands the name in the bar, a notification
   with actions works end to end, a notification sent by DMS itself (for
   example an update prompt) shows in the bar and its action reaches DMS,
   dismiss removes it from the list without
   a state file workaround, `bar-switch.sh dms` brings DMS popups back
   without a re-login, and a bar that cannot register the name still comes
   up as a bar while `bar-switch.sh status` and the journal say who holds
   it.

## Consequences

- `docs/shell.md`'s interface table loses the line that reads the DMS
  history file and gains the daemon, the history path and the drop-in;
  `docs/dms.md` records that DMS no longer owns notifications in the Niri
  session; the hotkey overlay title for any do-not-disturb bind changes
  with it. Each lands in the change that implements it, not up front.
- The `dms.service` drop-in is a new external interface with the packaged
  unit. If a DMS update moves to a replace-or-queue registration, adds a
  setting for the server, or stops when it loses the name, the drop-in and
  this ADR are revisited. `dms-shell` is already a fragile package in the
  update report (ADR-0025), so the report flags every DMS update.
- Switching modes now restarts DMS, which it never did before. The
  wallpaper, the polkit agent, the dash and the DMS lock trigger are gone
  for a second or two during a switch. Accepted: the switch is a rare,
  deliberate act, never something the session does on its own.
- DMS's notification history on disk stays untouched and simply stops
  growing in the Niri session; nothing deletes it. The bar's history starts
  empty at the switch.
- The bar process carries one more responsibility that must not crash: a
  bar crash now also drops the daemon until `Restart=on-failure` brings it
  back two seconds later, and senders see a transient failure in between.
  That is the same exposure DMS has today.
- Amended 2026-10-10: the first version of this ADR assumed that a loser
  never gets the name, so a plain `systemctl --user restart
  quickshell-bar.service` looked safe. It was not. DMS is Quickshell and
  retries registration when the name frees, so the bar's restart handed
  the name to DMS in the gap, the bar could not get it back, and
  notifications went to DMS popups. The fix is the `PartOf=` line in the
  drop-in (decision 2): a bar restart now restarts DMS with it, DMS
  comes up after the bar holds the name, and the wallpaper and polkit
  agent blink for a second. A crash restart stays uncovered, see decision
  3.
- Nothing in this ADR touches the Niri `input`, `output`, `cursor` or
  `debug` sections, so the greeter does not need `setup-greetd.sh`.

## Alternatives considered

- **Keep reading the DMS history file.** Rejected: it is the status quo
  the context describes, and it cannot give actions, a real dismiss or
  own-styled popups however well the bar polishes the list.
- **A third daemon (mako, swaync, dunst) beside DMS.** Rejected: it hits
  the same first-registrant rule as the bar, its popups are foreign to the
  design, and it adds a package to replace one Quickshell component the
  bar already has access to.
- **Make DMS give up the name through a setting or IPC.** Not available in
  DMS 1.6.2; patching it in is the fork ADR-0013 ruled out.
- **Race the bar ahead of DMS with `Before=` alone.** Rejected: with both
  units `Type=simple` and no readiness step, `Before=` only orders the
  forks, and the bigger process losing the race is likely but not
  guaranteed. The `gdbus wait` step makes it a guarantee at no cost.
- **`Type=dbus` with the bus name on the bar unit.** The first draft of
  this ADR. Rejected after review: it ties the bar's liveness to winning
  the name, so any state where DMS already holds it ends with a failed
  unit, an exhausted start limit and no bar at all.
- **Take the daemon over together with the lock screen.** This was the
  plan in ADR-0027's interface table. Separated because the two have
  nothing in common beyond the word "notification": the daemon is a Niri
  session matter decided here, the lock's privacy rule is one line, and
  waiting for the lock work would keep the daily bar on second-hand
  notifications for weeks.
