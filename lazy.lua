return {
  "taybart/code-actions.nvim",
  lazy = true,
  event = "BufEnter",
  dependencies = {},
  specs = {
    {
      "folke/snacks.nvim",
      opts = { picker = { enabled = true } },
    },
  },
  opts = {},
}
