local log_levels = vim.log.levels

local function should_show(action)

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

  return false
end







local lsp = {} lsp.__index = lsp

function lsp.new(config) local self = setmetatable({}, lsp)
  self.name = config.name
  self.actions = config.actions or {}
  self.commands = {}
  self.ctx = {}
  self.client = nil


  vim.iter(self.actions):each(function(action)
    if action.title == nil then
      action.title = action.command
    end
    self.commands[action.command] = action.fn
  end)


  do local __MIDNIGHT_TMP_1__ = type(config.ctx)
    if __MIDNIGHT_TMP_1__ == "function" then self.ctx = config.ctx()
    elseif __MIDNIGHT_TMP_1__ == "table" then self.ctx = config.ctx
    end end
  return self end


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

    local range_start = {start_row, start_col - 1}
    local range_end = {end_row, end_col - 1}
    params = vim.lsp.util.make_given_range_params(range_start, range_end, 0, offset) else

    params = vim.lsp.util.make_range_params(0, offset)
  end

  return params
end



















function lsp:get_ctx(params) if params == nil then params = self:make_params() end
  local buf = vim.uri_to_bufnr(params.textDocument.uri)
  local win = vim.fn.win_findbuf(buf)[1]

  if not win then return end

  local cursor = vim.api.nvim_win_get_cursor(win)
  local __MIDNIGHT_TMP_2__ if params.range then __MIDNIGHT_TMP_2__ = params.range.start.line else __MIDNIGHT_TMP_2__ = cursor[1] end local row = __MIDNIGHT_TMP_2__
  local __MIDNIGHT_TMP_3__ if params.range then __MIDNIGHT_TMP_3__ = params.range.start.character else __MIDNIGHT_TMP_3__ = cursor[2] end local col = __MIDNIGHT_TMP_3__

  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local node = vim.treesitter.get_node()

  local file = vim.uri_to_fname(params.textDocument.uri)
  local root = vim.fs.root(file, {".git", ".gitignore"}) or ""

  if params.range then
    params.range.rc = {
    params.range.start.line, 
    params.range.start.character, 
    params.range["end"].line, 
    params.range["end"].character}

  end

  local ctx = {buf = 
  buf, win = 
  win, row = 
  row, col = 
  col, line = 
  line, word = 
  ((function() if line then return (vim.fn.expand("<cword>")) else return nil end end)()), ts_type = 
  ((function() if node then return (node:type()) else return nil end end)()), ts_range = 
  ((function() if node then return {node:range()} else return nil end end)()), bufname = 
  file, root = 
  root, filetype = 
  vim.api.nvim_get_option_value("filetype", {buf = buf}), range = 
  params.range, g = 
  self.ctx}


  return ctx
end


function lsp:code_actions(ctx)
  return 




  vim.iter(self.actions):filter(function(action) action.ctx = ctx return should_show(action) end):totable()
end

function lsp:handlers()

  local handlers = {initialize = 
  function() return {capabilities = {codeActionProvider = true}} end, [
  "textDocument/codeAction"] = function(params)
    local ctx = self:get_ctx(params)
    if not ctx then
      vim.notify("could not get action context", log_levels.ERROR)
      return
    end
    return self:code_actions(ctx)
  end, shutdown = 
  function() end}


  return function(dispatchers)
    local closing = false
    return {request = 
    function(method, params, handler)
      local status, error = xpcall(function()
        if handlers[method] then
          handler(nil, handlers[method](params))
        end
      end, debug.traceback)

      if not status then
        vim.notify("error in LSP request: " .. error, log_levels.ERROR)
      end
      return true
    end, notify = 

    function(method)
      if method == "exit" then
        dispatchers.on_exit(0, 15)
      end
    end, is_closing = 

    function() return closing end, terminate = 

    function()
      closing = true
    end}

  end
end


return lsp
-- __MIDNIGHT_COMPILED__