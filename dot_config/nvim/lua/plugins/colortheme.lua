return {
  {
    "zenbones-theme/zenbones.nvim",
    dependencies = "rktjmp/lush.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.opt.termguicolors = true
      vim.opt.background = "dark"
    end,
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "zenbones" } },
}
