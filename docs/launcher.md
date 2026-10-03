# Launcher and dictation: Vicinae and Handy

Vicinae is the launcher, a Raycast-like hub with root search, clipboard
history, emoji, quicklinks, and Raycast-store extensions. Handy is offline
push-to-talk dictation. They replace DMS Spotlight and its registry plugins.
Why, what they replaced, and the acceptance checks are recorded in
[ADR-0024](adr/ADR-0024-replace-dms-spotlight-with-vicinae-and-add-handy-dictation.md).

## What runs

| | Vicinae | Handy |
| --- | --- | --- |
| Package | AUR `vicinae-bin` | AUR `handy-bin` |
| Started by | the packaged `/usr/lib/systemd/user/vicinae.service` (`vicinae server --replace`) | the repository's `~/.config/systemd/user/handy.service` (`handy --start-hidden`) |
| Enabled through | `niri.service.wants/vicinae.service` | `niri.service.wants/handy.service` |
| Settings (unmanaged) | `~/.config/vicinae/settings.json`; data in `~/.local/share/vicinae` | `~/.local/share/com.pais.handy/settings_store.json`; models and logs in the same directory |

Both units follow the pattern of `dms.service` and Ghostty: they start with
the Niri session and stop with it, and they do not start in the Steam
session. Vicinae's launcher is a layer-shell surface, so it needs no Niri
window rule; its settings window is an ordinary window on the current
workspace. Vicinae requests blur itself, and the existing
`honor-xdg-activation-with-invalid-serial` debug option lets the windows it
opens take focus. `Terminal=true` applications open in Ghostty through
`~/.config/xdg-terminals.list`; see
[docs/terminal.md](terminal.md#terminal-for-vicinae).

## Keys

| Key | Command | Does |
| --- | --- | --- |
| `Mod+Space` | `vicinae toggle` | Open or close the launcher. The `dotfilesLauncher` bar button does the same. |
| `Mod+V` | `vicinae vicinae://launch/clipboard/history?toggle=true` | Open or close the clipboard history. |
| `Mod+D` | `handy --toggle-transcription` | Start dictation; press again to stop and type the text into the focused window. |

Handy types with `wtype` on Niri (recorded in `packages/pacman.txt`). The
`Mod+D` bind only reaches a running Handy: when none runs, the same command
starts Handy with its window open instead of recording, and the next press
records. Handy's own shortcut recorder is not used; Niri owns the shortcut.
The unit sets `HANDY_DISABLE_UPDATER=1`, so Handy does not offer its own
updates; `paru` updates it like any other AUR package.

DMS no longer records the clipboard: the managed
`modify_clsettings.json` keeps `disabled` set in
`~/.config/DankMaterialShell/clsettings.json`, so Vicinae is the only
clipboard history. Screenshot binds still copy to the clipboard; DMS does
that with its own process.

## Installing

Install both packages; `vicinae-bin`'s install script also loads the
`uinput` module and gives the snippet helper permission to read input
devices:

```fish
paru -S --needed vicinae-bin handy-bin
```

Apply the dotfiles as described in the [maintenance guide](maintenance.md),
then start both for the current session (a new login does the same):

```fish
systemctl --user daemon-reload
systemctl --user start vicinae.service handy.service
```

Check that both run:

```fish
systemctl --user status vicinae.service handy.service
```

The Niri binds take effect on the config reload that the apply triggers.

## Removing the old DMS plugins

`scripts/dms-restore-plugins.sh` installs what `dms/plugins.lock.json` lists
but never removes anything, so the ten former launcher plugins stay installed
on a machine that had them. Remove them once, then restart DMS so the bar
and the plugin list reload:

```fish
for id in commandRunner converter dankGifSearch dankLauncherKeys dankTranslate emojiLauncher obsidianSearch personalDictionary svglSearch webSearch
    dms plugins uninstall $id
end
dms-reset
```

Their old settings stay in `~/.config/DankMaterialShell/plugin_settings.json`
and do nothing; DMS's old clipboard history stays in
`~/.cache/DankMaterialShell/clipboard` until it is deleted by hand.
`translate-shell` and `xdg-utils` are no longer recorded; remove
`translate-shell` with `paru -Rns translate-shell` if nothing else uses it
(`xdg-utils` is a dependency of other packages and stays).

## First start

Handy:

1. Open its window from the tray icon in the bar, or run `handy` (which
   raises the running instance).
2. Pick a model: Parakeet V3 (fast, multilingual including Dutch) or a
   Whisper model. Handy downloads it once; transcription then stays offline.
3. Leave the paste method on the Linux default ("direct", typing the text)
   and set the typing tool to `wtype` if it is not detected automatically.
4. Leave Handy's own "launch at startup" off: the unit starts it, and Niri's
   session also runs XDG autostart entries, which would start a second
   process.

Vicinae:

1. Open it with `Mod+Space`. The first start indexes files and uses a lot of
   CPU for a while.
2. Open the settings (`Ctrl+,`) and switch off telemetry under General; it
   is on by default.
3. Explore the built-in commands (clipboard history, emoji, files,
   quicklinks) and the Raycast store for extensions such as a GIF search.

## Acceptance checks

The setup is accepted when all of these work over a few days of normal use:

- [ ] `5m to km` and `5km in m` give the answer in the root search, without
      a prefix.
- [ ] An emoji is searched and pasted straight into the focused app.
- [ ] A clipboard-history entry (`Mod+V`) is pasted straight into the
      focused app.
- [ ] A GIF from a Raycast-store GIF extension lands in the focused app.
- [ ] File search finds a file in the home directory.
- [ ] Quicklinks with `{argument}` work for a folder, a web page, and a site
      search.
- [ ] Dictation works in Dutch and in English, into Zen and into Ghostty.
- [ ] Both stay fast and stable: no crashes, no noticeable delay when
      opening or typing, nothing alarming in the journal.

Check the journal for crashes and restarts with:

```fish
journalctl --user -b -u vicinae.service -u handy.service
```

## Rolling back

Revert the commit that introduced Vicinae and Handy with `git revert`,
review and apply the result with `./scripts/bootstrap.sh`, and restore the
former plugins with `./scripts/dms-restore-plugins.sh` (bootstrap runs it).
The revert does not delete live files on its own: remove
`~/.config/systemd/user/handy.service`, the two links in
`~/.config/systemd/user/niri.service.wants/`, `~/.config/xdg-terminals.list`,
and `~/.config/DankMaterialShell/clsettings.json` (or add them to
`chezmoi/.chezmoiremove` in the revert), then stop both services and remove
the packages:

```fish
systemctl --user stop vicinae.service handy.service
paru -Rns vicinae-bin handy-bin
paru -S --needed translate-shell xdg-utils
dms-reset
```

Record the reason in a new ADR that supersedes ADR-0024. The Vicinae and
Handy settings directories listed under "What runs" stay behind; delete
them by hand if they are not needed again.
