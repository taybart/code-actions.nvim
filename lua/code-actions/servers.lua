local _MODULE = {} _MODULE.servers = {}

local log_levels = vim.log.levels

local lsp = require("code-actions/lsp")

function _MODULE.start(config, buf, ft)
  local type = vim.api.nvim_get_option_value("buftype", {buf = buf})
  if vim.tbl_contains({"nofile", "prompt", "file", "quikfix", "terminal"}, type) then
    return
  end


  if vim.tbl_contains(config.filetypes.exclude, ft) then
    return
  end

  if #config.filetypes.include > 0 and not vim.tbl_contains(config.filetypes.include, ft) then
    return
  end


  local server = lsp.new(config)

  local client_id = vim.lsp.start({
  name = config.name, 
  cmd = server:handlers(), 
  bufnr = buf, 
  on_init = function(client)
    server.client = client
  end, 
  on_exit = function() end, 
  commands = server.commands
  })
  if not client_id then
    vim.notify("Failed to start LSP server", log_levels.ERROR)
    return
  end

  _MODULE.servers[config.name] = server

  return client_id
end
return _MODULE
-- __MIDNIGHT_COMPILED__