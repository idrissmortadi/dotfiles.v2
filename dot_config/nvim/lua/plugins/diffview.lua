return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewRefresh" },
  keys = {
    { "<leader>gv", "<cmd>DiffviewOpen origin/main...HEAD --imply-local<cr>", desc = "Diffview vs Main" },
    { "<leader>gh", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview Branch History" },
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview File History" },
    { "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Diffview Close" },
  },
  opts = {
    view = {
      default = { layout = "diff2_horizontal" },
      merge_tool = { layout = "diff3_horizontal", disable_diagnostics = true, winbar_info = true },
      file_history = { layout = "diff2_horizontal" },
    },
    file_panel = {
      listing_style = "tree",
      win_config = { position = "left", width = 35 },
    },
    keymaps = {
      file_panel = {
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
      },
      file_history_panel = {
        { "n", "q", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" } },
      },
    },
  },
}
