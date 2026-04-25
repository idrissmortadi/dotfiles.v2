return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    -- opts.inlay_hints = { enabled = true }
    opts.servers = opts.servers or {}
    opts.servers.gopls = {
      on_new_config = function(config, root_dir)
        if root_dir:match("^" .. vim.fn.expand("~") .. "/dd/") then
          config.cmd = { "dd-gopls" }
          config.cmd_env = { GOPLS_DISABLE_MODULE_LOADS = "1" }
        else
          config.cmd = { "gopls" }
          config.cmd_env = {}
        end
      end,
      filetypes = { "go", "gomod", "gowork", "gotmpl" },
      settings = {
        gopls = {
          ["ui.inlayhint.hints"] = {
            compositeLiteralFields = true,
            constantValues = true,
            parameterNames = true,
            functionTypeParameters = true,
          },
          ui = {
            codelenses = {
              generate = false,
              test = false,
              tidy = false,
              upgrade_dependency = false,
              vendor = false,
            },
            completion = {
              usePlaceholders = true,
            },
          },
          build = {
            directoryFilters = {
              "-**/bazel-bin",
              "-**/bazel-dd-source",
              "-**/bazel-out",
              "-**/bazel-testlogs",
            },
          },
          analyses = {
            unusedparams = true,
            unreachable = true,
          },
          staticcheck = true,
          gofumpt = true,
        },
      },
    }
  end,
}
