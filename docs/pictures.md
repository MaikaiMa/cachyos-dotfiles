# Pictures

`~/Pictures` is not managed by chezmoi; this documents the layout the desktop
configuration expects and the apps that view its contents.

## Layout

- `Libraries/` holds cloned wallpaper repositories (`dharmx-walls`,
  `dusklinux-walls`) as plain git checkouts. DMS never reads from here
  directly; treat it as raw source material.
- `Wallpapers/` is the single flat folder the DMS wallpaper picker points at.
  It contains only symlinks to favourites, created by `wallpaper-favorites`.
- `Screenshots/` is where the `dms screenshot` CLI saves; the path is
  hardcoded by DMS, not configured here.

## Favourite wallpapers

DMS's wallpaper picker reads `Wallpapers/` as one folder, non-recursively (Qt
`FolderListModel` with `showDirs` false), and cycling uses `find -maxdepth 1`.
The libraries hold thousands of images in nested category folders, so
`Wallpapers/` must stay a flat folder and must stay short.

Curation happens in Files (Nautilus): browse `Libraries/`, star the wallpapers
you want, and unstar the ones you are done with. `wallpaper-favorites` mirrors
those stars as symlinks; see
[ADR-0016](adr/ADR-0016-mirror-nautilus-stars-into-the-dms-wallpaper-folder.md)
for why stars are the source of truth.

The `wallpaper-favorites.path` user unit watches the Nautilus tag database and
runs `wallpaper-favorites sync` whenever it changes, so starring in Files is
normally the only step. Run a sync by hand when you want to see what it does:

```fish
wallpaper-favorites sync
```

It prints one summary line, for example `wallpaper-favorites: 12 linked, 1
added, 0 removed, 3 skipped`. Skipped counts starred files that are missing,
not images, or outside `Libraries/`. Link names are the path relative to
`Libraries/` with `/` replaced by `-`, because the same basename occurs in
several category folders. Only symlinks are created and removed; anything else
in `Wallpapers/` is left alone and reported on stderr.

List what a sync would link, without touching anything:

```fish
wallpaper-favorites list
```

Clone missing libraries and fast-forward the existing ones, then sync:

```fish
wallpaper-favorites pull
```

The libraries it manages are declared in
[`~/.config/wallpapers/libraries`](../chezmoi/dot_config/wallpapers/libraries),
one `name url` per line. A star is bound to the exact path of a file, so
renaming a library directory loses its stars.

All paths have environment overrides, mostly useful for trying something out:
`WALLPAPER_LIBRARIES_DIR`, `WALLPAPER_FAVORITES_DIR`, and `NAUTILUS_TAGS_DIR`.

```fish
env WALLPAPER_FAVORITES_DIR=$HOME/Pictures/Wallpapers-test wallpaper-favorites sync
```

### First-time setup

After `chezmoi apply` deploys the helper and the units:

```fish
systemctl --user daemon-reload
systemctl --user start wallpaper-favorites.path
wallpaper-favorites pull
```

Then point the DMS wallpaper picker at `~/Pictures/Wallpapers` once; DMS
remembers the folder in its own settings. Star something in Files and check
that it appears:

```fish
systemctl --user status wallpaper-favorites.service
```

## Screenshots

The binds, in
[`keybinds.kdl`](../chezmoi/dot_config/niri/cfg/keybinds.kdl), follow the
macOS layout from simple to complex: Mod+Shift+2 captures the focused screen,
Mod+Shift+3 captures the focused window, Mod+Shift+4 captures a region (on
mouse release), and Mod+Shift+5 captures a scrolling region: select a region,
scroll the content yourself, Enter finishes, Esc cancels, and the frames are
stitched into one tall image. Plain binds copy to the clipboard only; adding
Ctrl also saves a file to `~/Pictures/Screenshots` (and still copies).

Niri's own screenshot actions are unbound; `screenshot-path null` stays set in
[`misc.kdl`](../chezmoi/dot_config/niri/cfg/misc.kdl) so niri never writes
files itself.

## Viewing

Loupe is the default image viewer, set through the managed
[`mimeapps.list`](../chezmoi/dot_config/mimeapps.list). Sushi gives a
space-bar quick preview inside Files (Nautilus); the window-rule in
[`rules.kdl`](../chezmoi/dot_config/niri/cfg/rules.kdl) floats its preview
window instead of tiling it. Nautilus decides at startup which previewers and
tag features exist, so restart it after installing either.
