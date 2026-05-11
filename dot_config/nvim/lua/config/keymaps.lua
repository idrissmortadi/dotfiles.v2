-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local function copy_filepath()
  local filepath = vim.fn.expand("%:.")
  local mode = vim.fn.mode()

  if mode == "v" or mode == "V" or mode == "\22" then
    -- exit visual to update '< and '> marks
    vim.cmd("normal! \27")
    local start_line = vim.fn.getpos("'<")[2]
    local end_line = vim.fn.getpos("'>")[2]
    if start_line == end_line then
      filepath = filepath .. "#L" .. start_line
    else
      filepath = filepath .. "#L" .. start_line .. "-L" .. end_line
    end
  end

  vim.fn.setreg("+", filepath)
  vim.notify("Copied: " .. filepath)
end

vim.keymap.set(
  { "n", "x" },
  "<leader>yp",
  copy_filepath,
  { noremap = true, silent = true, desc = "Yank filepath (with line range in visual)" }
)
vim.keymap.set("i", "jj", "<ESC>", { silent = true })

local ls = require("luasnip")
vim.keymap.set({ "i" }, "<C-J>", function()
  ls.expand()
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-L>", function()
  ls.jump(1)
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-H>", function()
  ls.jump(-1)
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-E>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  end
end, { silent = true })
