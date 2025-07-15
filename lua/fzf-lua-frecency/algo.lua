local h = require "fzf-lua-frecency.helpers"
local fs = require "fzf-lua-frecency.fs"

local M = {}

local half_life_sec = 30 * 24 * 60 * 60
local decay_rate = math.log(2) / half_life_sec

--- @param date_in_sec number
local _get_pretty_date = function(date_in_sec)
  return os.date("%Y-%m-%d %H:%M:%S", date_in_sec)
end

--- @class ComputeScore
--- @field date_at_score_one number an os.time date
--- @field now number an os.time date

--- @param opts ComputeScore
M.compute_score = function(opts)
  return math.exp(decay_rate * (opts.date_at_score_one - opts.now))
end

--- @class ComputeDateAtScoreOne
--- @field score number
--- @field now number an os.time date

--- @param opts ComputeDateAtScoreOne
M.compute_date_at_score_one = function(opts)
  return opts.now + math.log(opts.score) / decay_rate
end

local function assert_field(field, name)
  if not field then
    h.notify_error("ERROR: missing %s!", name)
    return false
  end
  return true
end

--- @class ScoredFile
--- @field score number
--- @field filename string

--- @class AddFileScoreOpts
--- @field debug? boolean
--- @field cwd? string
--- @field now? number
--- @field sorted_files_path string
--- @field dated_files_path string
--- @field max_score_path string

--- @param filename string
--- @param opts AddFileScoreOpts
M.add_file_score = function(filename, opts)
  if not assert_field(filename, "filename")
      or not assert_field(opts, "opts")
      or not assert_field(opts.dated_files_path, "opts.dated_files_path")
      or not assert_field(opts.sorted_files_path, "opts.sorted_files_path")
      or not assert_field(opts.max_score_path, "opts.max_score_path") then
    return
  end

  local now = h.default(opts.now, os.time())
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local debug = h.default(opts.debug, false)
  if debug then
    h.notify_debug_header("DEBUG: add_file_score %s", filename)
  end

  local dated_files = fs.read(opts.dated_files_path, {})
  if not dated_files[cwd] then
    dated_files[cwd] = {}
  end

  local score = 0
  local date_at_score_one = dated_files[cwd][filename]
  if date_at_score_one then
    score = M.compute_score { now = now, date_at_score_one = date_at_score_one, }
  end
  local updated_score = score + 1
  local updated_date_at_score_one = M.compute_date_at_score_one { now = now, score = updated_score, }

  dated_files[cwd][filename] = updated_date_at_score_one
  fs.write { path = opts.dated_files_path, data = dated_files, encode = true, }

  --- @type ScoredFile[]
  local scored_files = {}
  local updated_dated_files = {}
  local max_score = 0
  for dated_file_entry, date_at_one_point_entry in pairs(dated_files[cwd]) do
    local recomputed_score = M.compute_score { now = now, date_at_score_one = date_at_one_point_entry, }

    local accessed_in_past_two_days = recomputed_score > 0.95
    local readable = vim.fn.filereadable(dated_file_entry) == h.vimscript_true

    if readable and accessed_in_past_two_days then
      max_score = math.max(max_score, recomputed_score)
      table.insert(scored_files, { filename = dated_file_entry, score = recomputed_score, })
      updated_dated_files[dated_file_entry] = date_at_one_point_entry
    end
  end
  dated_files[cwd] = updated_dated_files
  fs.write {
    data = dated_files,
    path = opts.dated_files_path,
    encode = true,
  }
  fs.write {
    data = max_score,
    path = opts.max_score_path,
    encode = true,
  }

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
  fs.write {
    path = opts.sorted_files_path,
    data = table.concat(scored_files_list, "\n") .. "\n",
    encode = false,
  }
end

return M
