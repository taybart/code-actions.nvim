local M = {
  servers = {}, -- Store server instances
}

local log_levels = vim.log.levels

local lsp = require("code-actions/lsp")

M.start = function(config, buf, ft)
  local type = vim.api.nvim_get_option_value("buftype", { buf = buf })
  if vim.tbl_contains({ "nofile", "prompt", "file", "quikfix", "terminal" }, type) then
    return
  end

  -- is this an excluded file type?
  if vim.tbl_contains(config.filetypes.exclude, ft) then
    return
  end
  -- are there included file types and does the file type match?
  if #config.filetypes.include > 0 and not vim.tbl_contains(config.filetypes.include, ft) then
    return
  end

  -- Create a new server instance for this configuration
  local server = lsp.new(config)

  local client_id = vim.lsp.start({
    name = config.name,
    cmd = server:handlers(),
    bufnr = buf,
    on_init = function(client)
      server.client = client
    end,
    on_exit = function() end,
    commands = server.commands,
  })
  if not client_id then
    vim.notify("Failed to start LSP server", log_levels.ERROR)
    return
  end
  -- Store the server instance
  M.servers[config.name] = server

  return client_id
end

return M
