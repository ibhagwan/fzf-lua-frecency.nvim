local h = require "lua.fzf-lua-frecency.helpers"
local fs = require "lua.fzf-lua-frecency.fs"

local HALF_LIFE_DAYS = 30
local DECAY_RATE = math.log(2) / HALF_LIFE_DAYS

local M = {}

--- @param date_in_days number
M._get_pretty_date = function(date_in_days)
  local date_in_sec = date_in_days * 24 * 60 * 60
  return os.date("%Y-%m-%d %H:%M:%S", date_in_sec)
end

M._get_now_in_days = function()
  local now_in_sec = os.time()
  return now_in_sec / (60 * 60 * 24)
end

--- @class AddOpts
--- @field cwd string
--- @field db_dir string
--- @field debug boolean

--- @param filename string
--- @param opts AddOpts
M.add = function(filename, opts)
  opts = opts or {}
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local db_dir = h.default(opts.db_dir, vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency"))
  local debug = h.default(opts.debug, false)
  if debug then
    if debug then h.notify_debug(("-"):rep(7 + #filename)) end
    h.notify_debug("DEBUG: %s", filename)
    h.notify_debug(("-"):rep(7 + #filename))
  end

  local scored_files_path = vim.fs.joinpath(db_dir, "scored-files.mpack")
  local sorted_files_path = vim.fs.joinpath(db_dir, "sorted-files.mpack")

  local now = M._get_now_in_days()

  local scored_files = fs.read(scored_files_path)
  if not scored_files[cwd] then
    scored_files[cwd] = {}
  end

  local score = 0
  local date_at_one_point = scored_files[cwd][filename]
  if date_at_one_point then
    score = math.exp(DECAY_RATE * (date_at_one_point - now))
  end
  local updated_score = score + 1
  local updated_date_at_one_point = now + math.log(updated_score) / DECAY_RATE

  scored_files[cwd][filename] = updated_date_at_one_point
  fs.write(scored_files_path, scored_files)

  local scored_cwd_list = {}
  for entry_file, entry_date_at_one_point in pairs(scored_files[cwd]) do
    local recomputed_score = math.exp(DECAY_RATE * (entry_date_at_one_point - now))
    table.insert(scored_cwd_list, { filename = entry_file, score = recomputed_score, })
  end

  if debug then
    h.notify_debug("now: %s", now)
    h.notify_debug("pretty now: %s", M._get_pretty_date(now))
    h.notify_debug("scored_files: %s", vim.inspect(scored_files))
    h.notify_debug(
      "date_at_one_point: %s",
      date_at_one_point and M._get_pretty_date(date_at_one_point) or "no date_at_one_point"
    )
    h.notify_debug("score: %s", score)
    h.notify_debug("updated_score: %s", updated_score)
    h.notify_debug("updated_date_at_one_point: %s", updated_date_at_one_point)
    h.notify_debug("scored_cwd_list before sort: %s", vim.inspect(scored_cwd_list))
  end

  local sorted_files = fs.read(sorted_files_path)
  if not sorted_files[cwd] then
    sorted_files[cwd] = {}
  end

  table.sort(scored_cwd_list, function(a, b)
    return a.score < b.score
  end)

  if debug then
    h.notify_debug("scored_cwd_list after sort: %s", vim.inspect(scored_cwd_list))
  end

  sorted_files[cwd] = scored_cwd_list
  fs.write(sorted_files_path, sorted_files)
end

return M
