local M = {}

--- @generic T
--- @param val T | nil
--- @param default_val T
--- @return T
M.default = function(val, default_val)
  return val == nil and default_val or val
end

--- @param msg string
--- @param ... any
M.notify_error = function(msg, ...)
  vim.notify(msg:format(...), vim.log.levels.ERROR)
end

M.vimscript_true = 1
M.vimscript_false = 0

return M
