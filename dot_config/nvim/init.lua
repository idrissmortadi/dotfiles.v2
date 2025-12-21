-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Bubbles config for lualine
-- Author: lokesh-krishna
-- MIT license, see LICENSE for more details.

vim.api.nvim_set_hl(0, "WinSeparator", { fg = "#698DDA" })

vim.keymap.set("n", "<leader>k", function()
  require("hover_log").hover_append()
end, { silent = true })
