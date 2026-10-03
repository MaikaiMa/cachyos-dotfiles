# ADR-0024: Replace DMS Spotlight with Vicinae and add Handy dictation

- Status: Accepted
- Date: 2026-10-03
- Amends: [ADR-0013](ADR-0013-replace-noctalia-with-dms-and-quickshell-surfaces.md)
  (DMS no longer provides the launcher or clipboard history),
  [ADR-0017](ADR-0017-use-ghostty-as-the-terminal.md) and
  [ADR-0019](ADR-0019-merge-dms-plugin-settings-as-desired-state.md)
  (`commandRunner` is gone)

## Context

The user is replacing a macOS Raycast workflow. The requirements are: fast,
stable, a minimal and modern interface, open source and privacy-friendly where
possible, no stack of paid subscriptions, and staying in flow: results are
pasted or typed into the app that has focus, without switching windows, and
each task takes as few steps as possible.

DMS Spotlight was set up with ten registry plugins (`commandRunner`,
`converter`, `dankGifSearch`, `dankLauncherKeys`, `dankTranslate`,
`emojiLauncher`, `obsidianSearch`, `personalDictionary`, `svglSearch`,
`webSearch`) and used. Most plugins only answer after their own trigger
prefix, and several copy a result instead of inserting it, so a conversion,
an emoji or a GIF takes more keystrokes than in Raycast and the prefixes have
to be remembered. After use, that trigger-per-plugin model was judged too
clumsy. Running Vicinae next to Spotlight as a trial was considered and
rejected by the user: two launchers with two sets of keys is exactly the kind
of friction the change is meant to remove.

Dictation is part of the same workflow and is not covered by DMS at all.

## Decision

1. **Vicinae is the launcher** (0.29.1, GPL-3.0, AUR `vicinae-bin`): root
   search without prefixes (Qalculate calculator and unit conversion, apps,
   files), clipboard history, emoji, quicklinks with `{argument}`, script
   commands, and access to the Raycast extension store. It pastes results
   into the focused window and knows Niri as a window manager. Its launcher
   is a layer-shell surface, so no Niri window rule is needed. The packaged
   `vicinae.service` is enabled through a symlink in `niri.service.wants/`,
   the pattern of [ADR-0007](ADR-0007-start-noctalia-as-a-systemd-user-service.md)
   and ADR-0017.
   - `Mod+Space` runs `vicinae toggle`.
   - `Mod+V` runs `vicinae vicinae://launch/clipboard/history?toggle=true`.
   - The `dotfilesLauncher` bar button runs `vicinae toggle` on a click.
2. **Handy is the dictation tool** (0.9.8, MIT, AUR `handy-bin`): offline
   push-to-talk with Whisper or Parakeet models, typed into the focused
   window with `wtype`. Handy ships no unit, so a repository-owned
   `handy.service` starts it hidden with its tray icon (settings and model
   downloads stay reachable) and is linked into `niri.service.wants/`.
   `Mod+D` runs `handy --toggle-transcription`, which a running instance
   receives through its single-instance plugin. Handy's own shortcut
   recording is not used: global shortcuts of that kind are unreliable on
   Wayland, and Niri binds keep all shortcuts in one file.
3. **The DMS registry plugins are removed.** `dms/plugins.lock.json` keeps
   the format with an empty `plugins` object, so `scripts/dms-restore-plugins.sh`
   and the lockfile mechanism of ADR-0013 stay available for a future
   plugin; `dms/plugin_settings.json` pins only the repository's own
   plugins. Restore does not prune, so the installed plugins are removed
   once by hand (docs/launcher.md). Their runtime packages
   (`translate-shell`, `xdg-utils`) leave the manifest.
4. **DMS's clipboard history is switched off**, so only Vicinae watches and
   stores the clipboard. DMS reads `disabled` from
   `~/.config/DankMaterialShell/clsettings.json` and reloads that file when
   it changes. A chezmoi `modify_` script sets that one key and keeps every
   other key DMS writes. ADR-0019 rejected `modify_` for
   `plugin_settings.json` because DMS reads that file only at startup and
   rewrites it from memory; `clsettings.json` is watched and written only
   from the clipboard settings page, so the merge is safe here. DMS's
   screenshot copy (`dms screenshot --no-file`) uses its own clipboard
   process and is unaffected.

Vicinae and Handy settings are not managed yet; which of them the repository
should own is decided once they have settled.

The setup is accepted when all of the following hold over a few days of
normal work (the checklist is in [docs/launcher.md](../launcher.md#acceptance-checks)):

- `5m to km` and `5km in m` resolve in Vicinae's root search without a prefix;
- an emoji, a clipboard-history entry, and a GIF from a Raycast-store
  extension land directly in the focused app;
- file search finds files in the home directory;
- quicklinks with `{argument}` open a folder, a web page, and a site search;
- dictation works in Dutch and English into Zen and Ghostty;
- both stay fast and stable, without crashes or noticeable lag.

If they do not hold, the change is rolled back with `git revert` of the
commit that introduced it, followed by a bootstrap and the steps in
[docs/launcher.md](../launcher.md#rolling-back). Own Vicinae extensions
(React and TypeScript) for AI translation and writing on the Claude API and
for colour preview and conversion come later.

## Consequences

- Two more AUR packages. Both are `-bin` repackagings of upstream releases,
  so updates depend on the AUR maintainers following upstream.
- Vicinae is 0.x and changes quickly; configuration keys and behaviour may
  change between releases. Its `vicinae-bin` install script gives the
  snippet input server `cap_dac_override` to read `/dev/input`, and loads
  `uinput` (also at boot through `/usr/lib/modules-load.d/vicinae.conf`) for
  pasting. That is a wider privilege than DMS needed.
- Vicinae sends opt-out telemetry (system information once a day) and checks
  GitHub for new releases; telemetry is switched off by hand at first start.
  Raycast-store extensions are downloaded and run on Vicinae's Node runtime.
- Clipboard history now lives in Vicinae's data directory; DMS's existing
  history stays on disk in `~/.cache/DankMaterialShell/clipboard` until it
  is cleared.
- Vicinae does not follow the DMS/matugen colours yet. Upstream publishes a
  matugen template (`extra/matugen.toml`) that the package does not install;
  wiring it in is a follow-up.
- Global shortcuts come from Niri binds. Vicinae's own global shortcuts need
  the `ext-hotkey-v1` protocol, which Niri does not ship yet
  (niri-wm/niri#4145).
- Running shell commands from the launcher (formerly `commandRunner` in
  Ghostty) is not configured; Vicinae script commands can do that later.
- Handy downloads its speech models on first use (hundreds of MB to over a
  GB per model) into its data directory; transcription itself is offline.
  Its built-in updater is disabled in the unit because pacman owns the
  installation.
- AI writing and translation still have to be built. Work texts may only go
  to an AI service the employer has approved; API keys live in 1Password or
  the GNOME keyring, never in this repository (see
  [ADR-0012](ADR-0012-use-gnome-keyring-and-1password-for-secrets.md)).

## Alternatives considered

- **DMS Spotlight with registry plugins**: deployed and integrated with the
  shell's look, but the trigger-per-plugin model was clumsy in use, and
  several plugins copy instead of inserting.
- **A side-by-side trial of Vicinae next to Spotlight**: lower risk, but two
  launchers on two keys; rejected by the user. `git revert` gives the same
  way back.
- **A purpose-built app per task** (for example Dialect for translation, a
  separate emoji picker and clipboard manager): good individual apps, but
  each is its own window and shortcut, which means context switching and
  more keys to remember.
- **A Raycast-like hub (Vicinae)**: one surface, root search without
  prefixes, pasting into the focused app, an extension model close to
  Raycast's. Chosen.
- **Removing the plugin lockfile and `dms-restore-plugins.sh`**: less code,
  but a future registry plugin would need the mechanism rebuilt; an empty
  lockfile costs nothing at bootstrap.
- **Keeping DMS's clipboard history as well**: harmless functionally, but
  two watchers keep two copies of everything copied, including secrets.
- **Dictation alternatives**: Voxtype, whisper-dictate, and nerd-dictation
  were considered briefly. Handy combines offline Parakeet and Whisper
  models, a settings UI with model management, typing through `wtype`, and a
  CLI toggle that a Niri bind can call, with the least setup.
