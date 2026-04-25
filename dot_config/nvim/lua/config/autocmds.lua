-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Poll for file changes every 2s so buffers refresh even while
-- focus is on Claude's tmux pane (FocusGained won't fire there).
local reload_timer = vim.uv.new_timer()
reload_timer:start(
  500,
  500,
  vim.schedule_wrap(function()
    if vim.api.nvim_get_mode().mode == "n" then
      vim.cmd("silent! checktime")
    end
  end)
)
