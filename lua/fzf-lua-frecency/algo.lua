local h = require "fzf-lua-frecency.helpers"
local fs = require "fzf-lua-frecency.fs"

local HALF_LIFE_SEC = 30 * 24 * 60 * 60
local DECAY_RATE = math.log(2) / HALF_LIFE_SEC

local M = {}

--- @param date_in_sec number
local _get_pretty_date = function(date_in_sec)
  return os.date("%Y-%m-%d %H:%M:%S", date_in_sec)
end

--- @class ScoredFile
--- @field score number
--- @field filename string

--- @class AddOpts
--- @field cwd string
--- @field db_dir string
--- @field debug boolean

--- @param filename string
--- @param opts? AddOpts
M.add_file_score = function(filename, opts)
  opts = opts or {}
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local db_dir = h.default(opts.db_dir, vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency"))
  local debug = h.default(opts.debug, false)
  if debug then
    local debug_header = ("DEBUG: add_file_score %s"):format(filename)
    h.notify_debug(("-"):rep(#debug_header))
    h.notify_debug(debug_header)
    h.notify_debug(("-"):rep(#debug_header))
  end

  local dated_files_path = vim.fs.joinpath(db_dir, "dated-files.mpack")
  local sorted_scored_files_path = vim.fs.joinpath(db_dir, "sorted-scored-files.mpack")

  local now = os.time()

  local dated_files = fs.read(dated_files_path)
  if not dated_files[cwd] then
    dated_files[cwd] = {}
  end

  local score = 0
  local date_at_score_one = dated_files[cwd][filename]
  if date_at_score_one then
    score = math.exp(DECAY_RATE * (date_at_score_one - now))
  end
  local updated_score = score + 1
  local updated_date_at_score_one = now + math.log(updated_score) / DECAY_RATE

  dated_files[cwd][filename] = updated_date_at_score_one
  fs.write(dated_files_path, dated_files)

  --- @type ScoredFile[]
  local scored_files = {}
  for entry_file, entry_date_at_one_point in pairs(dated_files[cwd]) do
    local recomputed_score = math.exp(DECAY_RATE * (entry_date_at_one_point - now))
    table.insert(scored_files, { filename = entry_file, score = recomputed_score, })
  end

  if debug then
    h.notify_debug("now: %s", _get_pretty_date(now))
    h.notify_debug("dated_files: %s", vim.inspect(dated_files))
    h.notify_debug(
      "date_at_score_one: %s",
      date_at_score_one and _get_pretty_date(date_at_score_one) or "no date_at_score_one"
    )
    h.notify_debug("score: %s", score)
    h.notify_debug("updated_score: %s", updated_score)
    h.notify_debug("updated_date_at_score_one: %s", _get_pretty_date(updated_date_at_score_one))
    h.notify_debug("scored_files before sort: %s", vim.inspect(scored_files))
  end

  local sorted_scored_files = fs.read(sorted_scored_files_path)
  if not sorted_scored_files[cwd] then
    sorted_scored_files[cwd] = {}
  end

  table.sort(scored_files, function(a, b)
    return a.score > b.score
  end)

  if debug then
    h.notify_debug("scored_files after sort: %s", vim.inspect(scored_files))
  end

  sorted_scored_files[cwd] = scored_files
  fs.write(sorted_scored_files_path, sorted_scored_files)
end

--- @param opts? AddOpts
--- @return ScoredFile[]
M.get_sorted_scored_files = function(opts)
  opts = opts or {}
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local db_dir = h.default(opts.db_dir, vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency"))
  local debug = h.default(opts.debug, false)
  if debug then
    local debug_header = "DEBUG: get_sorted_scored_files"
    h.notify_debug(("-"):rep(#debug_header))
    h.notify_debug(debug_header)
    h.notify_debug(("-"):rep(#debug_header))
  end

  local sorted_scored_files_path = vim.fs.joinpath(db_dir, "sorted-scored-files.mpack")
  local sorted_scored_files = fs.read(sorted_scored_files_path)

  if not sorted_scored_files[cwd] then
    sorted_scored_files[cwd] = {}
  end
  if debug then
    h.notify_debug("sorted_scored_files[cwd]: %s", vim.inspect(sorted_scored_files[cwd]))
  end
  return sorted_scored_files[cwd]
end

return M
