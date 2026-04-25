return {
  "saghen/blink.cmp",
  opts = {
    fuzzy = {
      sorts = {
        "exact",
        "score",
      },
    },
    keymap = {
      preset = "default",
      ["<Tab>"] = { "select_and_accept", "fallback" },
      ["<C-p>"] = { "show", "select_prev", "fallback_to_mappings" },
      ["<C-n>"] = { "show", "select_next", "fallback_to_mappings" },
    },
    completion = {
      menu = {
        auto_show = false,
      },
      ghost_text = {
        show_with_menu = false,
      },
      documentation = {
        auto_show = false,
      },
      list = {
        selection = {
          preselect = true,
        },
      },
    },
    sources = {
      providers = {
        path = {
          opts = {
            get_cwd = function(_)
              return vim.fn.getcwd()
            end,
          },
        },
      },
    },
  },
}
