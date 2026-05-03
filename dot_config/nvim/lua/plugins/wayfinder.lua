return {
  "error311/wayfinder.nvim",
  opts = {},
  config = function()
    require("wayfinder").setup({
      layout = {
        width = 0.88,
        height = 0.72,
      },
    })
  end,
}
