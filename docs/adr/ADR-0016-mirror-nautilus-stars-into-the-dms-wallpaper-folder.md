# ADR-0016: Mirror Nautilus stars into the DMS wallpaper folder

- Status: Accepted (2026-09-22)
- Date: 2026-09-22

## Context

The DMS wallpaper picker reads exactly one folder, non-recursively: a Qt
`FolderListModel` with `showDirs` false, and wallpaper cycling shells out to
`find -maxdepth 1`. There is no setting for a recursive scan, a second folder,
or a filter, and DMS plugins cannot reach the picker.

The wallpaper source material is two cloned repositories under
`~/Pictures/Libraries/`: together roughly 3150 images, organised in nested
category folders, with about 450 basenames occurring in more than one
category. Almost none of them are wallpapers the user actually wants; the
picker needs a short curated list, and curation has to survive a
`git pull` that adds or renames files.

Alternatives considered:

- **Point the picker at a flattened copy or link of everything.** 3150
  thumbnails in one grid, no curation, and cycling would walk the whole set.
- **A keybind that favourites the current wallpaper.** Every candidate has to
  become the live wallpaper before it can be judged: bind the picker to a
  category folder, browse, select, favourite, then repeat for the next
  folder. Clumsy, and it fights the picker's one-folder limitation instead of
  working around it.
- **A DMS plugin that teaches the picker about subfolders.** The picker is
  part of the DMS shell, not the plugin surface; anything reaching into it is
  a fork in practice and breaks on DMS updates.
- **A tagging image viewer as the curation tool.** That introduces a second
  tagging system next to the file manager's. gThumb is the obvious candidate
  and is still GTK3; gThumb 4 is alpha.

Files (Nautilus) already offers starring, with a keyboard shortcut, a
Starred view in the sidebar, and thumbnails and previews the user is using to
browse the libraries anyway. Nautilus 50 keeps stars in a private TinySPARQL
database at `~/.local/share/nautilus/tags/`, readable without a daemon:

```fish
tinysparql query -d ~/.local/share/nautilus/tags \
    "SELECT ?f { ?f a nautilus:File ; nautilus:starred true }"
```

## Decision

1. Stars in Files are the source of truth for wallpaper favourites. No
   repository-owned tagging UI, database, or list of chosen wallpapers.
2. `~/.local/bin/wallpaper-favorites` (POSIX `sh`) reads the starred URIs,
   keeps the ones that are existing image files under
   `~/Pictures/Libraries/`, and makes `~/Pictures/Wallpapers` contain exactly
   one symlink per favourite. Link names are the path relative to
   `Libraries/` with `/` replaced by `-`, because basenames collide across
   category folders. The helper only ever creates and removes symlinks;
   anything else in the folder is left alone and reported.
3. A systemd user path unit, `wallpaper-favorites.path`, watches the tag
   database and triggers the oneshot `wallpaper-favorites.service`, so
   starring in Files updates the picker without a manual step. It uses
   `PathModified`, not `PathChanged`: Nautilus keeps its SQLite connection
   open, so a star produces only an `IN_MODIFY` on `meta.db-wal` and no
   close event until Nautilus quits.
4. `wallpaper-favorites pull` clones and fast-forwards the libraries listed in
   `~/.config/wallpapers/libraries`, then syncs, so the checkouts are declared
   in the repository while their contents stay out of it.

## Consequences

- A star is bound to an exact path. Moving or renaming a library directory, or
  an upstream rename, silently loses that file's star; re-star it after the
  move.
- `~/Pictures/Wallpapers` must stay flat and must only ever contain symlinks.
  Dropping a real image in there works for DMS but is not managed, will not be
  removed by a sync, and gets reported on every run.
- A light/dark or per-mood split is not possible in one folder. If it is
  wanted later it needs a second folder plus a second favourites mechanism,
  which stars alone cannot express.
- Nautilus caches which previewers and tag features are available when it
  starts, so a freshly installed Nautilus extension or a newly created tag
  database needs a Nautilus restart.
- The tag database is a Nautilus implementation detail. A future Nautilus
  release may change its location, schema, or backend, which would break the
  helper's read.

## Alternatives considered

Recorded in the Context section above.
