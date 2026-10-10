# ADR-0029: Structure the own bar: primitives, service helpers and qs imports

- Status: Accepted
- Date: 2026-10-10
- Amends: [ADR-0027](ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)
  (the layout and the rules for adding to the bar; the decision to own the
  bar and to keep DMS as the service layer stands)

## Context

The own bar was built in seven steps between 2026-10-04 and 2026-10-07 and
has been the daily bar since 2026-10-05 (ADR-0027, ADR-0028). On
2026-10-10 the owner declared it done and asked for a review of its
structure: is it split correctly, does it match the current Quickshell
documentation, is it readable, is it what a senior developer would write.
Five independent reviews of the 69 files (15 048 lines at commit 3fe7615)
agreed on the diagnosis:

- The directory layout (tokens, services, islands, panels, components) and
  the rule "services own data, panels present it" were right and held.
- Below the components there was no layer of shared primitives, so the
  same code had been written by hand at every site: the crossfade
  `Behavior` 66 times, the font triplet 55 times, the focus ring and the
  Space/Return/Enter handler 9 times each, the keyed ListModel diff up to
  five times, hover tints with seven different literal alphas. The copies
  had drifted: two fades ran linear, four buttons could not be reached
  from the keyboard, three Wi-Fi signal mappings disagreed.
- Every command-backed service had its own spawn, collect, parse and poll
  loop with small differences, and the differences were where the bugs
  were: dropped writes, refreshes lost while a read ran, polls that kept
  running with nothing on screen, a leak of transient notifications.
- Four files held several features each (`CentreIsland` 916 lines,
  `RightIsland` 875, `Notifications` 701, `SettingsPanel` 479), the islands
  reparented items into windows they did not own, and adding a panel took
  four parallel edits.
- The bar used relative `"../services"` imports and hand-written `qmldir`
  files. Quickshell 0.3.1's guide prefers `import qs.<dir>` module imports
  as "much more LSP friendly". Verified on 2026-10-10: `import qs` and
  `import qs.services` work without `qmldir` files, and qmllint resolves
  them when the lint gets an import root that holds a `qs` symlink to the
  bar directory while the hand-written `qmldir` files stay.
- `Theme` had become a catch-all for feature flags, fixed colours, DMS
  calibrated durations and behaviour constants next to the sizes, and the
  documented reduce-motion switch had no source.

## Decision

1. **A primitive layer under the components.** `components/` holds shared,
   service-free pieces, and every new widget is built from them: text is a
   `Label`; anything clickable is a `Pressable`, an `IconButton` or a
   `PillButton` with a `FocusRing`; fades are `Crossfade`, `ColorCrossfade`
   or an `Appear`; morphs use `MorphAnimation`; lists that must keep their
   delegates use `KeyedListModel`; fields, scroll hints, section headers,
   icon discs, fill tracks, chevron zones and rounded images have one
   component each. Interaction colours are tokens in `Colors`
   (`hovered()`, `hoverSurface`, `selectedSurface`, `subtleFill`, the error
   and outline tints), opacities and the type scale are tokens in `Theme`.
   A literal alpha, font block or animation block in a widget is a review
   finding.
2. **One service shape.** A service is a `pragma Singleton` that owns data
   and actions. Commands run through `Command` (one shot, exit code and
   output together), `CommandReader` (single flight, re-run when asked
   mid-run, optional interval, `active` gate, one warning per failure),
   `CommandWriter` (newest value wins) or `LineWatcher` (long-lived, retry
   after a delay). Paths come from `Paths`. Every service that depends on
   what is on screen exposes `active`, and `Shell` binds all of them in one
   place; no service reads the centre state itself. Service timeouts are
   named properties of the service, not Motion or Theme tokens.
3. **Tokens mean one thing each.** `Colors` holds colours, `Theme` sizes,
   fonts, opacities and behaviour steps, `Motion` durations and curves.
   Runtime switches (wave, reduce motion, peeks, crossfade, the weather
   fallback) live in `Settings`, a `FileView` with a `JsonAdapter` over
   `$XDG_STATE_HOME/dotfiles-bar/settings.json`, and are reachable over the
   `bar` IPC. The theme-switching service is `Appearance`, so that `Theme`
   can keep its name for the design tokens.
4. **Composition over size.** An island or panel composes named parts with
   narrow interfaces; a part that lives in another window is created by
   that window and bound to geometry the island exposes, never reparented
   out of the island. Every panel is a `Panel` and the host takes its size
   from the current one, so a panel is one file and one line. Feature parts
   with one owner live next to that owner (`islands/`, `panels/`,
   `windows/`), or in `components/<feature>/` when a directory would grow
   past about twenty files.
5. **Quickshell module imports.** Files import `qs`, `qs.services`,
   `qs.components`, `qs.islands`, `qs.panels` and `qs.windows`. The
   hand-written `qmldir` files stay, complete, because Quickshell honours
   them and qmllint needs them; `tests/quickshell-bar.sh` lints through a
   temporary import root with a `qs` symlink. `objectName` is not used as a
   matter of course; the few that code reads say why.

## Consequences

- The cleanup landed as six commits on 2026-10-10 (bugs, primitives,
  service shape, islands and panels, notification split and naming, layout
  and imports), each validated with qmllint, the repository tests and a
  bootstrap dry-run, and reviewed by the owner before the next started.
  `docs/shell.md` "Adding a widget" states the rules above; new code is
  measured against them.
- The bar is smaller and each file is one thing, at the price of more
  files and of the primitives' own API to learn. The reviewers' reports
  and the consolidated review of 2026-10-10 are the record of why each
  piece exists; the ADR does not repeat them.
- Behaviour was meant to stay identical except where a bug was fixed.
  The live checks the owner runs after applying are listed in
  `docs/shell.md` "Running it by hand". Two measurements are deliberately
  open: `Island`'s always-on layer and shadow during music, and
  `TopWave`'s Canvas render strategy; both are decided only with `Frames`
  numbers.

## Alternatives considered

- **Leave the structure, fix only the bugs.** Rejected: the bugs came from
  the copies, so the next feature would have produced the next drift.
- **Nest or split the Theme tokens** (`Theme.notificationPeek.rowHeight`,
  or one file per area). Rejected for now: 224 of 283 tokens have one
  consumer and the prefixes already act as namespaces; nesting would touch
  about 700 references for a cosmetic gain. Theme stays flat with area
  headers that follow the design contract's tables.
- **Rename `Theme` to `Metrics`** instead of `Theming` to `Appearance`.
  Rejected: about 1000 references against 16 for the same clarity; it
  remains an option once Theme holds only sizes.
- **Generic poller or a DMS socket client.** Rejected: every poll is a
  `Timer` with a sensible gate already, and the bar keeps to DMS's public
  `dms ipc` surface (ADR-0027).
