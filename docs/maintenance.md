# Maintenance workflow

This guide is the shared workflow for human and AI-assisted changes. The
repository remains the source of truth; live files are deployment targets and
must not be edited as a substitute for changing `chezmoi/`.

## Responsibilities

- `README.md` documents installation, scope, and normal use.
- `AGENTS.md` defines mandatory working boundaries for AI agents; `CLAUDE.md`
  only imports it for Claude Code.
- This guide defines the shared change, review, and verification workflow.
- `docs/adr/` records durable architectural decisions and their trade-offs.
- Package manifests record every non-base dependency needed by managed
  configuration, helpers, validation, or documented setup.

Update the relevant documentation in the same change as the implementation.
Do not duplicate detailed feature explanations across files; link to the
authoritative guide or ADR instead.

## Change workflow

Start by confirming that the worktree and the live home contain only expected
changes:

```fish
git status --short
chezmoi status
```

Make one focused change in the repository. Add or update its dependencies,
tests, user documentation, and ADR when applicable. Then run:

```fish
git diff --check
./tests/validate.sh
./scripts/bootstrap.sh --dry-run --no-pager
```

Review the code and the complete dry-run:

```fish
git diff
```

Do not run the live bootstrap until the dry-run is understood and the user has
explicitly approved deployment. A real bootstrap installs the logind
power-key drop-in when it differs (ADR-0021), and on a detected Z13 it may
also install the recorded AUR dependency and update the repository-owned udev
rule, in addition to applying chezmoi.

## Definition of done

A change is ready for review when all applicable items are true:

- Managed home files live under `chezmoi/`, not only in the live home.
- Required official and AUR packages are recorded in the correct manifest.
- Secrets, generated files, and machine-local state are excluded.
- Changed POSIX shell scripts pass ShellCheck and `shfmt -d`.
- Changed Fish scripts pass `fish -n`.
- Niri and other supported configuration syntax is validated.
- Behavior-changing helpers have focused tests.
- Every new or changed `I18n.trFor` string in a DMS plugin has a Dutch entry
  in that plugin's `translations/nl.json`. DMS follows the system locale, but
  the catalogues are kept complete so the interface can be switched back to
  Dutch.
- Bootstrap succeeds from an isolated empty home and remains idempotent.
- Required files are tracked by Git.
- README, feature documentation, and the ADR index are current.
- A new system-wide architectural decision has an ADR.
- `git diff --check`, `tests/validate.sh`, and the real-home bootstrap dry-run
  pass.
- The handoff states what still needs to be verified on the physical machine.

## Updating the machine

The DMS bar shows pending pacman, AUR, and Flatpak updates through its
built-in `systemUpdate` widget, which hides itself while nothing is pending
(`hideWhenIdle`). Clicking the widget opens the update popout. The check
interval (`updaterIntervalSeconds`, 30 minutes by default) is a DMS setting;
the repository sets `updaterCheckOnStart` and the update command in
`dms/look.json`.

"Update All" in that popout runs the managed helper `system-update` in the
terminal, and so does this from any shell:

```fish
system-update
```

The helper is the guarded version of `paru -Syu; and flatpak update`
(ADR-0025). Before it upgrades anything it lists the fragile pending packages
with their version jump: kernels, Mesa, niri, Quickshell, DMS (`dms-shell`),
systemd, greetd, and `greetd-dms-greeter-bin`. When that list is not empty and
the helper runs in a terminal, it asks `Continue with the upgrade? [Y/n]` once;
Enter continues, anything else cancels before anything is installed.
`system-update --yes` skips the question, and so does running the helper
without a terminal. On a normal day the list is empty and nothing is asked.
The own Quickshell bar reads the pending packages through
`system-update --pending`, which only prints one tab-separated line per
package (source, name, old and new version, fragile) and changes nothing.

paru then prints unread Arch news (`NewsOnUpgrade`), and the helper upgrades
the repositories, the AUR, and Flatpak, and reports what a plain upgrade leaves
silent:

- unmerged `.pacnew` files, with the `pacdiff` command to merge them;
- a reminder to re-run `scripts/setup-sessions.sh` when
  `/etc/pacman.conf.pacnew` is among them (ADR-0023);
- a reminder to re-sync the greeter when `greetd-dms-greeter-bin` was updated;
- the updated packages that keep running old code until a reboot: kernels,
  Mesa, niri, Quickshell, DMS, systemd, greetd.

On a normal day that report is one line saying nothing needs attention. The
same information goes to a Markdown report at
`~/.local/state/system-update/last-report.md`, overwritten on every run: the
fragile packages, every package that was pending, each unmerged `.pacnew` with
a unified diff against the live file, the follow-up reminders, and a fixed
"For an agent" section with instructions for an AI agent (check the upstream
release notes of the fragile packages, advise per `.pacnew` hunk, give a
post-reboot checklist, run nothing). When there is a follow-up or a fragile
package was updated, the terminal ends with a line to paste into an agent:

```text
Read ~/.local/state/system-update/last-report.md and follow its "For an agent" section.
```

The terminal of the DMS updater waits for Enter before it closes, so the line
can be copied from there. The agent only advises; merging `.pacnew` files,
re-syncing the greeter, and rebooting stay manual.

Daily or weekly makes no difference to the risk; the package count only
reflects the days since the last run. The real protection is `snap-pac`: every
pacman transaction gets a Btrfs snapshot that Limine can boot. Never install a
single package without a full upgrade, and prefer updating at the end of the
day so the reboot is cheap.

Merge `.pacnew` files when the helper lists them. `m` in `pacdiff` needs the
previous package in the pacman cache and fails with "Unable to find an older
package to base merge on" after a cache clean; use `v` to view and then `o`
(overwrite), `r` (remove the pacnew), or `s` (skip):

```fish
sudo DIFFPROG='nvim -d' pacdiff
```

The news check lives in the managed `~/.config/paru/paru.conf`
(`NewsOnUpgrade`), so a manual `paru -Syu` shows it too; the helper only
warns when that option is missing. `paru` reads only the first configuration
it finds, so that file replaces `/etc/paru.conf` and repeats its defaults.
archlinux.org rate-limits the news feed (`429 Too Many Requests`) when it is
fetched repeatedly in a short time; the message is harmless and paru carries on.

Neovim plugins are not part of this; update them with `:Lazy update` and copy
the lockfile back as described in [docs/editor.md](editor.md#updating-plugins-and-the-lockfile).

Afterwards confirm that the manifests still match the machine:

```fish
./scripts/check-packages.sh
```

After an upgrade of `greetd-dms-greeter-bin`, and after changing Niri input,
output, cursor, or debug configuration, re-sync the greeter:

```fish
./scripts/setup-greetd.sh
```

See [docs/greeter.md](greeter.md) for what the sync does and why it is
needed again after those changes.

After merging a `/etc/pacman.conf.pacnew`, re-apply the greeter session list,
which keeps its `NoExtract` line in that file:

```fish
./scripts/setup-sessions.sh
```

See [docs/gaming.md](gaming.md) and ADR-0023.

## Deployment and machine verification

After explicit approval, deploy from the reviewed worktree:

```fish
./scripts/bootstrap.sh
```

Run a second preview to detect unexpected drift:

```fish
./scripts/bootstrap.sh --dry-run --no-pager
```

Check that the machine still provides every recorded package:

```fish
./scripts/check-packages.sh
```

Greetd and the login screen are not part of `scripts/bootstrap.sh`. Installing
or switching the greeter, and changing its session list with
`scripts/setup-sessions.sh`, are separate steps that need their own explicit
approval; see [docs/greeter.md](greeter.md) and [docs/gaming.md](gaming.md).

Repository tests cannot prove hardware and desktop behavior. After deployment,
manually verify the affected Niri behavior, that the DMS bar and its plugins
load (`dms-reset`, then check the bar and `Mod+S`), that a wallpaper change
re-renders the Z13 rear-window color (see `docs/dms.md`), spelling
integration, and any feature-specific restart requirements. Record a failed
assumption in the relevant guide or ADR before trying a different
architectural approach.
