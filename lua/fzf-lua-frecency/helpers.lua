local M = {}

--- @generic T
--- @param val T | nil
--- @param default_val T
--- @return T
M.default = function(val, default_val)
  return val == nil and default_val or val
end

--- @param level vim.log.levels
--- @param msg string
--- @param ... any
local _notify = function(level, msg, ...)
  local rest = ...
  vim.schedule(function()
    vim.notify(msg:format(rest), level)
  end)
end

--- @param msg string
--- @param ... any
M.notify_error = function(msg, ...)
  _notify(vim.log.levels.ERROR, msg, ...)
end

--- @param msg string
--- @param ... any
M.notify_debug = function(msg, ...)
  _notify(vim.log.levels.DEBUG, msg, ...)
end

M.notify_debug_header = function(header, ...)
  local debug_header = (header):format(...)
  M.notify_debug(("-"):rep(#debug_header))
  M.notify_debug(debug_header)
  M.notify_debug(("-"):rep(#debug_header))
end

M.vimscript_true = 1
M.vimscript_false = 0

return M
