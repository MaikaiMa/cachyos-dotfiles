-- DMS renders colors/dms.lua and lua/lualine/themes/dms.lua from the
-- wallpaper (matugenTemplateNeovim); the colorscheme needs base46 and
-- reloads itself when DMS rewrites the file. Until DMS has rendered it,
-- as on a fresh install, LazyVim's tokyonight is used instead.
return {
  { "AvengeMedia/base46", lazy = true, opts = {} },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        if not pcall(vim.cmd.colorscheme, "dms") then
          vim.cmd.colorscheme("tokyonight")
        end
      end,
    },
  },
}
