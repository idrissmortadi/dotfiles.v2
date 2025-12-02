return {
  "neovim/nvim-lspconfig",
  opts = function(_, opts)
    opts.servers = opts.servers or {}
    opts.servers.gopls = {
      cmd = { "dd-gopls" },
      settings = {
        gopls = {
          directoryFilters = {
            "-",
            "+domains/ai_platform",
            "+domains/chatbot",
            "+libs/go",
          },
          expandWorkspaceToModule = false,
          diagnosticsTrigger = "Save",
          semanticTokens = false,
          usePlaceholders = true,
          codelenses = {
            gc_details = false,
            generate = false,
            regenerate_cgo = true,
            run_govulncheck = true,
            test = false,
            tidy = false,
            upgrade_dependency = false,
            vendor = false,
          },
        },
      },
    }
  end,
}
