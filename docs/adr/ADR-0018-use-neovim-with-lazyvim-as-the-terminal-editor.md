# ADR-0018: Use Neovim with LazyVim as the terminal editor

- Status: Accepted
- Date: 2026-09-23

## Context

Zed is the main editor. A terminal editor is still needed for commit
messages, `sudoedit`, quick edits from Ghostty, and as a backup when Zed is
unavailable. `EDITOR` and `VISUAL` pointed at plain `vim`, without any
configuration. The user already knows LazyVim from earlier machines and wants
the terminal editor to be easy to use and clean, not a configuration project.

DMS 1.6.2 ships a matugen template for Neovim that renders a colorscheme from
the wallpaper, as it does for Ghostty.

## Decision

Use Neovim with the LazyVim starter as the terminal editor, managed in
`chezmoi/dot_config/nvim/`. The starter files stay as close to upstream as
possible so LazyVim upgrades remain easy; only the demo content is dropped,
luarocks support is disabled, and one plugin file adds the colours.

Plugin versions are pinned by `lazy-lock.json`, which chezmoi manages.
`EDITOR` and `VISUAL` point at `nvim`.

The colours come from DMS's `matugenTemplateNeovim` template, switched on in
`dms/look.json`. It writes a `dms` colorscheme, which needs the
`AvengeMedia/base46` plugin, and a lualine theme into `~/.config/nvim`. Those
two files are DMS runtime state, not managed by chezmoi and listed in
`.chezmoiignore`. When they do not exist yet, LazyVim's default tokyonight is
used.

`gvim` stays installed for a plain `vim` with Wayland clipboard support; it
has no managed configuration.

## Consequences

- The first start of Neovim downloads lazy.nvim, LazyVim, and the plugins
  from GitHub, then builds treesitter parsers with `tree-sitter-cli` and
  `gcc`. It needs network access once; later starts are offline.
- `lazy-lock.json` pins every plugin commit. `:Lazy update` changes the live
  lockfile, which must be copied back into the repository with
  `chezmoi re-add`. Until then `chezmoi status` reports drift, and the next
  bootstrap asks whether to overwrite it with the old pins. See
  [docs/editor.md](../editor.md).
- Mason installs language servers and formatters into
  `~/.local/share/nvim/mason`. That state is not managed and differs per
  machine; the default LazyVim set installs itself on first use.
- The colorscheme follows the wallpaper in open Neovim instances without a
  signal from DMS, because the generated file watches itself. It depends on
  `base46` supporting DMS's template; if a DMS update and base46 disagree,
  the fallback is to switch the template off and use tokyonight.
- More moving parts than a bare editor: about 30 plugins, updated from
  GitHub rather than pacman. The update checker runs quietly and only shows
  pending updates in `:Lazy`.
- Plain `vim` remains available through `gvim`, so muscle memory on servers,
  where only Vim exists, still has a local counterpart.

## Alternatives considered

- **Plain Vim with a small vimrc:** available on every server and stable,
  but bare: no LSP, fuzzy finder, or Git integration without assembling
  plugins by hand, which is exactly the configuration work to avoid.
- **Neovim with LazyVim:** familiar keymaps and layout, lazy-loaded and fast,
  with sensible defaults; costs plugin downloads and a lockfile to maintain.
  Chosen.
- **Helix:** modal, fast, and complete out of the box with almost no
  configuration, but its selection-first keymap differs from Vim and LazyVim,
  so it would mean relearning instead of reusing existing habits.
