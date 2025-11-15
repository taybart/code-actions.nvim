local M = {
  config = {
    register_keymap = true,
    name = "code-actions",
    actions = {},
    filetypes = {
      include = {},
      exclude = {},
    },
    servers = {},
  },
}

local servers = require("code-actions/servers")

local function condition_config(name, config)
  config.name = name
  config.ctx = config.ctx or {}
  config.filetypes = config.filetypes or {}
  config.filetypes.exclude = config.filetypes.exclude or {}
  config.filetypes.include = config.filetypes.include or {}
  return config
end

-- TODO: we need to be able add servers and only run setup once
function M.setup(config)
  M.config = vim.tbl_deep_extend("force", M.config, config)
  -- force main actions server to be code-actions
  M.config = condition_config(M.config.name, M.config)

  vim.api.nvim_create_autocmd({ "FileType" }, {
    group = vim.api.nvim_create_augroup("code-actions", { clear = true }),
    callback = function(ev)
      servers.start(M.config, ev.buf, ev.match)
      vim.iter(M.config.servers):each(function(name, cfg)
        servers.start(condition_config(name, cfg), ev.buf, ev.match)
      end)
      if M.config.register_keymap then
        vim.keymap.set("n", "ca", vim.lsp.buf.code_action, { buffer = ev.buf })
      end
    end,
  })
end

return M
