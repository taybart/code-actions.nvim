local M = {
  servers = {}, -- Store server instances
}

local LSP = require("code-actions/lsp")

M.start = function(config, buf, ft)
  local type = vim.api.nvim_get_option_value("buftype", { buf = buf })
  if vim.tbl_contains({ "nofile", "prompt", "file", "quikfix", "terminal" }, type) then
    return
  end

  if vim.tbl_contains(config.filetypes.exclude or {}, ft) then
    return
  end
  if #(config.filetypes.include or {}) > 0 and not vim.tbl_contains(config.filetypes.include, ft) then
    return
  end

  -- Create a new server instance for this configuration
  local server = LSP.new(config)

  -- Store the server instance
  M.servers[config.name] = server

  local dispatchers = {
    on_exit = function(code, signal)
      vim.notify(config.name .. " server exited with code " .. code .. " and signal " .. signal, log_levels.ERROR)
    end,
  }

  local server_func = server:new_server_with_handlers()

  local client_id = vim.lsp.start({
    name = config.name,
    cmd = server_func,
    root_dir = "",
    bufnr = buf,
    on_init = function(client)
      server.client = client
    end,
    on_exit = function(code, signal) end,
    commands = server.commands,
  }, dispatchers)
  if not client_id then
    vim.notify("Failed to start LSP server", log_levels.ERROR)
    return
  end

  server.client = vim.lsp.get_client_by_id(client_id)

  return client_id
end

return M
