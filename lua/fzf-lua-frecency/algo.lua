local h = require "fzf-lua-frecency.helpers"
local fs = require "fzf-lua-frecency.fs"

local M = {}

local half_life_sec = 30 * 24 * 60 * 60
local decay_rate = math.log(2) / half_life_sec

--- @param date_in_sec number | nil
local _get_pretty_date = function(date_in_sec)
  if not date_in_sec then return "nil" end
  return os.date("%Y-%m-%d %H:%M:%S", date_in_sec)
end

--- @class ComputeScore
--- @field date_at_score_one number an os.time date. the date in seconds when the score decays to 1
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

--- @class UpdateFileScoreOpts
--- @field debug? boolean
--- @field cwd? string
--- @field now? number
--- @field sorted_files_path string
--- @field dated_files_path string
--- @field max_scores_path string
--- @field update_type "increase" | "remove"

--- @param filename string
--- @param opts UpdateFileScoreOpts
M.update_file_score = function(filename, opts)
  if not assert_field(filename, "filename")
      or not assert_field(opts, "opts")
      or not assert_field(opts.update_type, "opts.update_type")
      or not assert_field(opts.dated_files_path, "opts.dated_files_path")
      or not assert_field(opts.sorted_files_path, "opts.sorted_files_path")
      or not assert_field(opts.max_scores_path, "opts.max_scores_path") then
    return
  end

  local now = h.default(opts.now, os.time())
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local debug = h.default(opts.debug, false)
  if debug then
    h.notify_debug_header("DEBUG: update_file_score %s", filename)
    h.notify_debug("opts.update_type: %s", opts.update_type)
    h.notify_debug("now: %s", _get_pretty_date(now))
    h.notify_debug("cwd: %s", cwd)
  end

  local dated_files = fs.read(opts.dated_files_path)
  if not dated_files[cwd] then
    dated_files[cwd] = {}
  end

  if debug then
    h.notify_debug("dated_files: %s", vim.inspect(dated_files))
  end

  local updated_date_at_score_one
  if opts.update_type == "increase" then
    local score = 0
    local date_at_score_one = dated_files[cwd][filename]
    if date_at_score_one then
      score = M.compute_score { now = now, date_at_score_one = date_at_score_one, }
    end
    local updated_score = score + 1
    updated_date_at_score_one = M.compute_date_at_score_one { now = now, score = updated_score, }

    if debug then
      h.notify_debug(
        "date_at_score_one: %s",
        date_at_score_one and _get_pretty_date(date_at_score_one) or "no date_at_score_one"
      )
      h.notify_debug("score: %s", score)
      h.notify_debug("updated_score: %s", updated_score)
    end
  else
    updated_date_at_score_one = nil
  end

  if debug then
    h.notify_debug("updated_date_at_score_one: %s", _get_pretty_date(updated_date_at_score_one))
  end

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
  local max_scores = fs.read(opts.max_scores_path)
  max_scores[cwd] = max_score
  fs.write {
    data = max_scores,
    path = opts.max_scores_path,
    encode = true,
  }

  if debug then
    h.notify_debug("scored_files before sort: %s", vim.inspect(scored_files))
  end

  table.sort(scored_files, function(a, b)
    return a.score > b.score
  end)

  if debug then
    h.notify_debug("scored_files after sort: %s", vim.inspect(scored_files))
  end

  local scored_files_list = vim.tbl_map(function(scored_file) return scored_file.filename end, scored_files)
  local sorted_files_str = table.concat(scored_files_list, "\n")
  if #sorted_files_str > 0 then
    sorted_files_str = sorted_files_str .. "\n"
  end

  fs.write {
    path = opts.sorted_files_path,
    data = sorted_files_str,
    encode = false,
  }
end

return M
