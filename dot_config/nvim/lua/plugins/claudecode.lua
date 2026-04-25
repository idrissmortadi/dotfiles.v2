return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    port_range = { min = 10000, max = 65535 },
    auto_start = true,
    log_level = "info",
    terminal_cmd = nil,
    focus_after_send = false,
    track_selection = true,
    visual_demotion_delay_ms = 20,
    terminal = {
      provider = "snacks",
      auto_close = true,
      snacks_win_opts = {
        position = "left",
        height = 1.0,
        width = 0.5,
        border = "single",
      },
    },
    diff_opts = {
      auto_close_on_accept = true,
      vertical_split = false,
      open_in_current_tab = true,
      keep_terminal_focus = false,
    },
  },
}
