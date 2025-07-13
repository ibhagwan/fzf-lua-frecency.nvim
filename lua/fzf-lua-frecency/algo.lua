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

--- @class AddFileScoreOpts
--- @field debug boolean
--- @field cwd string
--- @field sorted_files_path string
--- @field dated_files_path string

--- @param filename string
--- @param opts? AddFileScoreOpts
M.add_file_score = function(filename, opts)
  opts = h.default(opts, {})
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local debug = h.default(opts.debug, false)
  if debug then
    h.notify_debug_header("DEBUG: add_file_score %s", filename)
  end

  local now = os.time()

  local dated_files = fs.read(opts.dated_files_path)
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
  fs.write { path = opts.dated_files_path, data = dated_files, encode = true, }

  --- @type ScoredFile[]
  local scored_files = {}
  local updated_dated_files = {}
  for entry_file, entry_date_at_one_point in pairs(dated_files[cwd]) do
    local recomputed_score = math.exp(DECAY_RATE * (entry_date_at_one_point - now))
    -- if a file hasn't been accessed in 2 days
    if recomputed_score > 0.95 then
      table.insert(scored_files, { filename = entry_file, score = recomputed_score, })
      updated_dated_files[entry_file] = entry_date_at_one_point
    end
  end
  dated_files[cwd] = updated_dated_files

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

  table.sort(scored_files, function(a, b)
    return a.score > b.score
  end)
  local scored_files_list = vim.tbl_map(function(scored_file) return scored_file.filename end, scored_files)
  if debug then
    h.notify_debug("scored_files after sort: %s", vim.inspect(scored_files))
  end
  fs.write {
    path = opts.sorted_files_path,
    data = table.concat(scored_files_list, "\n") .. "\n",
    encode = false,
  }
end

return M
