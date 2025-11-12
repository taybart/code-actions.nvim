--- @class Action
--- @field command string - command name
--- @field title string - what should be shown in the picker
--- @field show function - should the action be shown
--- @field fn function - what to do when action is triggered

--- @class Ctx
--- @field buf number - buffer number
--- @field win number - window number
--- @field row number - current line number
--- @field col number - current column number
--- @field line string - current line
--- @field word string - word under cursor
--- @field ts_node userdata|nil - current TS node
--- @field ts_type string|nil - type of the current TS node
--- @field ts_range table|nil - range of the current TS node
--- @field bufname string - full path to file in buffer
--- @field root string - root directory of the file
--- @field filetype string - filetype
--- @field range table|nil - range of the current selection
--- @field g table - global run context provided in the config

local log_levels = vim.log.levels

local LSP = {}
LSP.__index = LSP

-- Create a new server instance
function LSP.new(config)
  local server = {
    name = config.name,
    actions = config.actions or {},
    commands = {},
    ctx = {},
    client = nil,
  }
  setmetatable(server, LSP)

  -- Set up context
  if type(config.ctx) == "function" then
    server.ctx = config.ctx()
  elseif type(config.ctx) == "table" then
    server.ctx = config.ctx
  end

  return server
end

--- @return table
function LSP:make_params()
  local mode = vim.api.nvim_get_mode().mode
  local offset = self.client and self.client.offset_encoding or "utf-16"
  local params

  if mode == "v" or mode == "V" then
    -- TODO:
    -- local range = Utils.range_from_selection(0, mode)
    -- params = vim.lsp.util.make_given_range_params(range.start, range["end"], 0, offset)
    params = vim.lsp.util.make_range_params(0, offset)
  else
    params = vim.lsp.util.make_range_params(0, offset)
  end

  return params
end

--- @param params table|nil
--- @return Ctx|nil
function LSP:get_ctx(params)
  params = params or self:make_params()

  local buf = vim.uri_to_bufnr(params.textDocument.uri)
  local win = vim.fn.win_findbuf(buf)[1]

  if not win then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local row = params.range and params.range.start.line or cursor[1]
  local col = params.range and params.range.start.character or cursor[2]

  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local node = vim.treesitter.get_node()

  local file = vim.uri_to_fname(params.textDocument.uri)
  local root = vim.fs.root(file, { ".git", ".gitignore" }) or ""

  if params.range then
    params.range.rc = {
      params.range.start.line,
      params.range.start.character,
      params.range["end"].line,
      params.range["end"].character,
    }
  end

  local ctx = {
    buf = buf,
    win = win,
    row = row,
    col = col,
    line = line,
    word = line and vim.fn.expand("<cword>") or nil,
    ts_type = node and node:type() or nil,
    ts_range = node and { node:range() } or nil,
    bufname = file,
    root = root,
    filetype = vim.api.nvim_get_option_value("filetype", { buf = buf }),
    range = params.range,
    g = self.ctx,
  }

  ctx.edit = setmetatable(ctx, {
    __index = function(t, k)
      if k == "ts_node" then
        return node
      end
      return rawget(t, k)
    end,
  })

  return ctx
end

local function check_show(action)
  if action.show == nil then
    return true
  end
  if type(action.show) == "function" then
    return action.show(action.ctx)
  end
  if type(action.show) == "table" then
    if action.show.ft ~= nil then
      local sh = vim.iter(action.show.ft):find(action.ctx.filetype)
      if sh ~= nil then
        return true
      end
    end
  end

  return false
end

--- @param ctx Ctx|nil
function LSP:code_actions(ctx)
  -- Initialize commands and titles
  vim.iter(self.actions):map(function(action)
    if action.title == nil then
      action.title = action.command
    end
    self.commands[action.command] = action.fn
  end)

  if not ctx then
    return self.actions
  end

  return vim.iter(self.actions)
      :filter(function(action)
        ctx.g = self.ctx
        action.ctx = ctx
        return check_show(action)
      end)
      :totable()
end

function LSP:initialize()
  return {
    capabilities = {
      codeActionProvider = true,
    },
  }
end

function LSP:new_server_with_handlers()
  -- Create a closure to capture the server instance for handlers
  local function get_server_actions(ctx)
    return self:code_actions(ctx)
  end

  -- Update handlers to use server instance
  local server_handlers = {
    ["initialize"] = function()
      return self:initialize()
    end,
    ["textDocument/codeAction"] = get_server_actions,
    ["shutdown"] = function() end,
  }

  local function server(dispatchers)
    local closing = false
    local srv = {}

    function srv.request(method, params, handler)
      local status, error = xpcall(function()
        local ctx = params and params.textDocument and self:get_ctx(params)
        if server_handlers[method] then
          handler(nil, server_handlers[method](ctx))
        end
      end, debug.traceback)

      if not status then
        vim.notify("error in LSP request: " .. error, log_levels.ERROR)
      end
      return true
    end

    function srv.notify(method, _)
      if method == "exit" then
        dispatchers.on_exit(0, 15)
      end
    end

    function srv.is_closing()
      return closing
    end

    function srv.terminate()
      closing = true
    end

    return srv
  end

  return server
end

local M = {
  servers = {}, -- Store server instances
}

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
  server.actions = server:code_actions()

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
