local lsp = {}
lsp.__index = lsp

local log_levels = vim.log.levels

--- @class Action
--- @field command string - command name
--- @field title string - what should be shown in the picker
--- @field show function - should the action be shown
--- @field fn function - what to do when action is triggered

-- Create a new server instance
function lsp.new(config)
  local server = {
    name = config.name,
    actions = config.actions or {},
    commands = {},
    ctx = {},
    client = nil,
  }

  -- Initialize commands and titles
  vim.iter(server.actions):map(function(action)
    if action.title == nil then
      action.title = action.command
    end
    server.commands[action.command] = action.fn
  end)

  -- Set up global context
  if type(config.ctx) == "function" then
    server.ctx = config.ctx()
  elseif type(config.ctx) == "table" then
    server.ctx = config.ctx
  end

  setmetatable(server, lsp)

  return server
end

--- @return table
function lsp:make_params()
  local mode = vim.api.nvim_get_mode().mode
  local offset = self.client and self.client.offset_encoding or "utf-16"
  local params

  if mode == "v" or mode == "V" then
    local start = vim.fn.getpos("v")
    local end_ = vim.fn.getpos(".")

    local start_row, start_col = start[2], start[3]
    local end_row, end_col = end_[2], end_[3]

    if start_row == end_row and end_col < start_col then
      end_col, start_col = start_col, end_col
    elseif end_row < start_row then
      start_row, end_row = end_row, start_row
      start_col, end_col = end_col, start_col
    end

    if mode == "V" then
      start_col = 1
      local lines = vim.api.nvim_buf_get_lines(0, end_row - 1, end_row, true)
      end_col = #lines[1]
    end

    local range_start = { start_row, start_col - 1 }
    local range_end = { end_row, end_col - 1 }
    params = vim.lsp.util.make_given_range_params(range_start, range_end, 0, offset)
  else
    params = vim.lsp.util.make_range_params(0, offset)
  end

  return params
end

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

--- @param params table|nil
--- @return Ctx|nil
function lsp:get_ctx(params)
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

  return ctx
end

local function should_show(action)
  -- default to showing
  if action.show == nil then
    return true
  end
  if type(action.show) == "function" then
    return action.show(action.ctx)
  end
  if type(action.show) == "table" then
    if action.show.ft ~= nil then
      if vim.tbl_contains(action.show.ft or {}, action.ctx.filetype) then
        return true
      end
    end
  end
  -- don't show if something was specified and it didn't match above
  return false
end

--- @param ctx Ctx
function lsp:code_actions(ctx)
  return vim.iter(self.actions)
      :filter(function(action)
        action.ctx = ctx
        return should_show(action)
      end)
      :totable()
end

function lsp:handlers()
  -- stylua: ignore
  local handlers = {
    ["initialize"] = function() return { capabilities = { codeActionProvider = true } } end,
    ["textDocument/codeAction"] = function(params)
      local ctx = self:get_ctx(params)
      if not ctx then
        vim.notify("could not get action context", log_levels.ERROR)
        return
      end
      local ca = self:code_actions(ctx)
      vim.print(ca)
      return ca
    end,
    ["shutdown"] = function() end,
  }

  return function(dispatchers)
    local closing = false
    return {
      request = function(method, params, handler)
        local status, error = xpcall(function()
          if handlers[method] then
            handler(nil, handlers[method](params))
          end
        end, debug.traceback)

        if not status then
          vim.notify("error in LSP request: " .. error, log_levels.ERROR)
        end
        return true
      end,

      notify = function(method)
        if method == "exit" then
          dispatchers.on_exit(0, 15)
        end
      end,

      is_closing = function()
        return closing
      end,

      terminate = function()
        closing = true
      end,
    }
  end
end

return lsp
