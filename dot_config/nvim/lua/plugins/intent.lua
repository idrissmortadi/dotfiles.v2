return {
  dir = "/Users/idriss.mortadi/Projects/codecode",
  name = "intent.nvim",
  dev = true,
  config = function(_, opts)
    require("intent").setup(opts)
  end,
  opts = {
    provider = "openai",
    model = "openai/gpt-4.1-nano",
    openai_base_url = "https://ai-gateway.us1.staging.dog",
    auth_cmd = "ddtool auth token rapid-ai-platform --datacenter us1.staging.dog --http-header",
    extra_headers = {
      { "source", "intent-nvim" },
      { "org-id", "2" },
    },
    auto_start_bridge = false,
  },
}
