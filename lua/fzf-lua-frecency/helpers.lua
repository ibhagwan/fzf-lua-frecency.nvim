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

--- @param str string
--- @param len number
M.pad_str = function(str, len)
  if #str >= len then
    return tostring(str)
  end

  local num_spaces = len - #str
  return string.rep(" ", num_spaces) .. str
end

--- @param num number
--- @param decimals number
M.max_decimals = function(num, decimals)
  local factor = 10 ^ decimals
  return math.floor(num * factor) / factor
end

--- @param num number
--- @param decimals number
M.min_decimals = function(num, decimals)
  return string.format("%." .. decimals .. "f", num)
end

--- @param num number
--- @param decimals number
M.exact_decimals = function(num, decimals)
  return M.min_decimals(M.max_decimals(num, decimals), decimals)
end

M.get_default_db_dir = function()
  return vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency")
end

--- @param db_dir string
--- @param cwd string
M.get_sorted_files_path = function(db_dir, cwd)
  db_dir = M.default(db_dir, M.get_default_db_dir())
  cwd = M.default(cwd, vim.fn.getcwd())
  return vim.fs.joinpath(db_dir, "cwds", cwd, "sorted-files.txt")
end

--- @param db_dir string
M.get_dated_files_path = function(db_dir)
  db_dir = M.default(db_dir, M.get_default_db_dir())
  return vim.fs.joinpath(db_dir, "dated-files.mpack")
end

--- @param db_dir string
M.get_max_scores_path = function(db_dir)
  db_dir = M.default(db_dir, M.get_default_db_dir())
  return vim.fs.joinpath(db_dir, "max-scores.mpack")
end

--- @param str string
M.strip_score = function(str)
  return str:gsub("^%d+%.?%d*%s+", "")
end

return M
