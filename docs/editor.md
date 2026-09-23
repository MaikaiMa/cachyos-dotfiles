# Editor

Zed is the main editor. Neovim with [LazyVim](https://www.lazyvim.org/) is
the terminal editor and backup, and is what `EDITOR` and `VISUAL` point at,
so Git commit messages, `chezmoi edit`, and `sudoedit` open in it. Why is
recorded in
[ADR-0018](adr/ADR-0018-use-neovim-with-lazyvim-as-the-terminal-editor.md).

## What is installed

`packages/pacman.txt` records `neovim` and what LazyVim uses from the system:
`tree-sitter-cli` and `gcc` to build treesitter parsers, `lazygit` for
`<leader>gg`, `ripgrep` and `fd` for the pickers, `fzf`, `unzip` for Mason,
and `wl-clipboard` for the system clipboard. `git` and `curl` are already
recorded for other reasons. Node.js is not required by the default
configuration; Mason only needs `npm` for servers of language extras such as
TypeScript.

`gvim` provides plain `vim` with Wayland clipboard support. It replaced the
`vim` package and has no managed configuration.

## Configuration

`chezmoi/dot_config/nvim/` is the [LazyVim
starter](https://github.com/LazyVim/starter) without its example plugin file,
README, and licence:

```text
init.lua                   loads lua/config/lazy.lua
lua/config/lazy.lua        bootstraps lazy.nvim and LazyVim; luarocks disabled
lua/config/options.lua     own options (empty: LazyVim defaults)
lua/config/keymaps.lua     own keymaps (empty)
lua/config/autocmds.lua    own autocommands (empty)
lua/plugins/colorscheme.lua DMS colours with tokyonight as fallback
lazy-lock.json             pinned plugin commits
stylua.toml                formatting of this configuration
```

Keep the starter files close to upstream so LazyVim upgrades stay easy; add
own plugins or overrides as new files under `lua/plugins/`.

## First start

The first `nvim` after deployment clones lazy.nvim, LazyVim, and the plugins
at the commits in `lazy-lock.json`, builds the treesitter parsers, and lets
Mason install LazyVim's default tools. This needs network access and takes a
minute; close the `:Lazy` window once it is done. Check the result with
`:checkhealth lazyvim`.

LazyVim extras enabled through `:LazyExtras` are saved in
`~/.config/nvim/lazyvim.json`. Once that file exists and should be kept, add
it to the repository:

```fish
chezmoi add ~/.config/nvim/lazyvim.json
```

## Updating plugins and the lockfile

The update checker runs quietly: `:Lazy` shows pending updates, without a
notification. Update from Neovim with `:Lazy update`, which moves the
plugins and rewrites the live `~/.config/nvim/lazy-lock.json`. Copy that
lockfile back into the repository and review it:

```fish
chezmoi re-add ~/.config/nvim/lazy-lock.json
git -C ~/Projects/dotfiles diff chezmoi/dot_config/nvim/lazy-lock.json
```

Plain `chezmoi` finds the repository through the `sourceDir` that bootstrap
writes into `~/.config/chezmoi/chezmoi.toml`. Before the first bootstrap, pass
the source explicitly:

```fish
chezmoi --source ~/Projects/dotfiles/chezmoi re-add ~/.config/nvim/lazy-lock.json
```

Until the lockfile is re-added, `chezmoi status` reports it as changed, and
the next bootstrap asks whether to overwrite it with the old pins. On another
machine, `:Lazy restore` checks out exactly the commits in the lockfile.

Mason's language servers, formatters, and linters live in
`~/.local/share/nvim/mason` and are not managed by the repository; update them
with `:Mason`. The rest of `~/.local/share/nvim`, `~/.local/state/nvim`, and
`~/.cache/nvim` is machine-local state as well.

## Colours

`dms/look.json` switches on DMS's `matugenTemplateNeovim`, which is off by
default in DMS. On every wallpaper or theme change DMS then renders:

- `~/.config/nvim/colors/dms.lua`, a `dms` colorscheme built on a
  [base46](https://github.com/AvengeMedia/base46) theme, tinted towards the
  wallpaper colour, with the DMS background;
- `~/.config/nvim/lua/lualine/themes/dms.lua`, the matching statusline theme,
  which LazyVim's lualine picks up automatically.

DMS renders them only when `nvim` is on `PATH`. The files are DMS runtime
state, like the Ghostty theme, so they are not in the repository and
`chezmoi/.chezmoiignore` keeps `chezmoi add` from picking them up.

`lua/plugins/colorscheme.lua` installs `AvengeMedia/base46` and loads `dms`.
When the file does not exist yet, as on a fresh install before the first
wallpaper change, LazyVim's default tokyonight is used instead.

DMS does not signal Neovim. The generated colorscheme watches its own file and
DMS's `settings.json`, so an open Neovim reloads with the new colours and
shows a short "Theme reload" notification.

The base themes (default `github_dark` and `github_light`) and how strongly
they are tinted are set in DMS Settings under Theme & Colors, Neovim. To go
back to tokyonight permanently, switch the template off there and remove the
generated file:

```fish
rm ~/.config/nvim/colors/dms.lua
```

## System files

Edit files owned by root with `sudoedit` rather than `sudo nvim`:

```fish
sudoedit /etc/greetd/config.toml
```

`sudoedit` copies the file, opens the copy in `$EDITOR` as the user, with the
user's LazyVim configuration, and writes it back as root afterwards.
