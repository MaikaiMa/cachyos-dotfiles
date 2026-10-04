# ADR-0025: Guard system updates with a helper behind the DMS updater

- Status: Accepted; amended 2026-10-04 (fragile-package prompt and agent report, see below)
- Date: 2026-10-03
- Amends: [ADR-0011](ADR-0011-declare-noctalia-plugins-and-show-updates-in-the-bar.md)
  (a repository update script was rejected there as duplication; it now adds
  the checks that were missing), [ADR-0023](ADR-0023-own-the-greeter-session-list-and-hand-steam-over-to-niri.md)
  (its `pacman.conf.pacnew` warning gets an automatic reminder)

## Context

CachyOS is a rolling release: 80 to 200 package updates arrive every few
days. Reading the changelogs of all of them is not possible and not useful,
because almost all are library rebuilds and point releases. The bar widget
("Update All" in the DMS `systemUpdate` popout) ran a plain `paru -Syu` plus
`flatpak update`, which is also what the maintenance guide documented.

Updating blind is acceptable on this machine because the installer set up
`snap-pac` and `limine-snapper-sync`: every pacman transaction gets a pre and
post Btrfs snapshot of root, and the snapshots are bootable from the Limine
menu. A broken update is undone by booting the previous snapshot.

Three things are not covered by snapshots and were being skipped:

1. Arch news posts that require manual intervention. They are rare, a few
   per year, but they are the one case where a blind `paru -Syu` breaks the
   system or leaves it half-upgraded. `paru` can print unread news before an
   upgrade (`NewsOnUpgrade`), but the CachyOS `/etc/paru.conf` leaves it off.
2. `.pacnew` files. Seven had accumulated unnoticed, including
   `/etc/pacman.conf.pacnew`, which ADR-0023 flags because the greeter session
   list depends on a line in that file. Nothing in the desktop shows them.
3. Updates to the kernel, Mesa, niri, Quickshell, DMS, systemd, or the greeter
   keep the old code running until a reboot or a greeter re-sync; "the desktop
   is weird after updating" usually traces back to this.

## Decision

- `chezmoi/dot_local/bin/executable_system-update` is a POSIX `sh` helper
  that runs the update as one guarded sequence: confirm that paru will print
  unread Arch news, list what is pending, run `paru -Syu`, run `flatpak update`,
  then report unmerged `.pacnew` files with the merge command, remind about
  `scripts/setup-sessions.sh` when `pacman.conf.pacnew` is among them, remind
  about `scripts/setup-greetd.sh` when the greeter package was updated, and
  list the updated packages that need a reboot. A failing `paru -Syu` stops the
  run before Flatpak and the report.
- The DMS updater runs this helper instead of its built-in command:
  `dms/look.json` sets `updaterUseCustomCommand` and
  `updaterCustomCommand: "system-update"`. DMS wraps the command in `sh -c`
  inside the configured terminal and waits for Enter before closing, so the
  report stays readable. Manual updates use the same helper from any
  terminal.
- `chezmoi/dot_config/paru/paru.conf` enables `NewsOnUpgrade`, which makes
  `paru -Syu` print unread news itself, inside the helper and in a manual run.
  The helper does not fetch the feed a second time with `paru -Pw`: two
  fetches per run got the feed rate-limited (`429 Too Many Requests`). It
  only warns when the effective paru configuration lacks the option. `paru`
  uses only the first configuration file it finds, so the user file repeats
  the CachyOS defaults instead of overriding one option.
- The checks are reports, not gates. The helper never merges `.pacnew` files
  or reboots by itself; both remain visible, manual actions.

### Amendment 2026-10-04

Two days of use showed two gaps. The fragile packages were only named after
the upgrade, when the old code was already replaced, and the report scrolled
away in the updater terminal as soon as Enter was pressed, so there was
nothing to hand to someone (or an agent) who could read release notes and
`.pacnew` diffs. [ADR-0027](ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)
adds a repository-owned Quickshell bar that treats DMS as an external
interface, which makes a DMS, Quickshell, or niri update worth one look
before it runs.

- **One gate, before the upgrade.** The helper lists the pending fragile
  packages (the reboot pattern plus the greeter package) with their version
  jump and, when that list is not empty and stdin is a terminal, asks once
  whether to continue. `--yes` or a non-interactive run skips the question.
  On a normal day the list is empty and nothing is asked, so the one-click
  bar action is unchanged. Everything after the upgrade stays a report.
- **A report file for a second reader.** After the upgrade the helper
  writes `~/.local/state/system-update/last-report.md` (overwritten per run,
  `SYSTEM_UPDATE_STATE_DIR` overrides the directory for tests): the fragile
  packages, every package that was pending, each `.pacnew` with a unified
  diff against the live file, the follow-up reminders, and a fixed "For an
  agent" section asking for release-note checks per fragile package, a
  merge or drop verdict per `.pacnew` hunk, and a post-reboot checklist,
  with the instruction to run nothing. When there is a follow-up or a
  fragile package was updated, the terminal ends with the one-line prompt
  that points an agent at the report. The agent advises; merging,
  re-syncing the greeter, and rebooting remain the user's actions.
- The helper still does not capture paru's own output. The Arch news paru
  prints during `-Syu` is not copied into the report, because the only way
  to get it a second time is a second feed fetch, which the rate limit above
  rules out. The report says so and points at the news site instead.
- **A read-only listing for the own bar.** `system-update --pending` prints
  one tab-separated line per pending package (`source`, `name`, old
  version, new version, `fragile` as 0 or 1; source is `repo`, `aur` or
  `flatpak`) and exits 0. It checks no news, asks nothing, upgrades nothing
  and writes no report, so the bar's Updates service can run it every 30
  minutes instead of asking DMS's updater, whose status call starts a check.

## Consequences

- Updating from the bar stays a one-click action and is now "guarded" rather
  than "blind": the only reading required is whatever the helper prints after
  the upgrade, which is empty on a normal day.
- `pacman-contrib` is recorded in `packages/pacman.txt` for `checkupdates`
  and `pacdiff`; `snap-pac` and `limine-snapper-sync` stay unrecorded as
  installer-owned (ADR-0009), but the safety argument above depends on them.
- The helper does not update Neovim plugins, `mise` toolchains, or Fish
  plugins; those remain manual as before.
- The reboot list is a pattern match on package names, not an analysis of
  what changed. It may ask for a reboot that is not strictly necessary.
- The news check needs network access and is subject to archlinux.org's rate
  limit; paru reports a failed fetch and continues with the upgrade.

## Alternatives considered

- **Keep updating blind:** works most days thanks to the snapshots, but the
  `.pacnew` backlog and the ADR-0023 interaction show that silent drift does
  happen.
- **Reading every changelog:** not feasible at this volume and not what the
  Arch model asks for; the news feed is the intended channel.
- **`informant` (AUR) as a pacman hook that blocks upgrades on unread news:**
  does the first check well, but adds an AUR dependency, blocks `pacman` in
  scripts, and covers neither `.pacnew` files nor reboots.
- **topgrade:** rejected in ADR-0011 for the same reasons; it adds sources
  without adding the missing checks.
- **A DMS plugin showing `.pacnew` files in the bar:** more visible, but the
  files only appear as a result of an update, so reporting right after the
  update reaches the same eyes at the right moment with far less code.
