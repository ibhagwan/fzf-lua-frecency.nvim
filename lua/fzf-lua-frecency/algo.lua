local M = {}

local half_life_sec = 30 * 24 * 60 * 60
local decay_rate = math.log(2) / half_life_sec

--- @param date_in_sec number | nil
local _get_pretty_date = function(date_in_sec)
  if not date_in_sec then return "nil" end
  return os.date("%Y-%m-%d %H:%M:%S", date_in_sec)
end

M._now = function()
  return os.time()
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
  local h = require "fzf-lua-frecency.helpers"
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
--- @field update_type "increase" | "remove"
--- @field db_dir? string
--- @field debug? boolean
--- @field prepend_score? boolean

--- @param filename string
--- @param opts UpdateFileScoreOpts
M.update_file_score = function(filename, opts)
  local now = M._now()
  if not assert_field(filename, "filename")
      or not assert_field(opts, "opts")
      or not assert_field(opts.update_type, "opts.update_type") then
    return
  end

  local fs = require "fzf-lua-frecency.fs"
  local h = require "fzf-lua-frecency.helpers"
  local db_index = 1 -- We only use index 1 everywhere
  local db_dir = h.default(opts.db_dir, h.get_default_db_dir())
  local debug = h.default(opts.debug, false)
  local prepend_score = h.default(opts.prepend_score, false)

  local sorted_files_path = h.get_sorted_files_path(db_dir)
  local dated_files_path = h.get_dated_files_path(db_dir)
  local max_scores_path = h.get_max_scores_path(db_dir)

  if debug then
    h.notify_debug_header("DEBUG: update_file_score %s", filename)
    h.notify_debug("opts.update_type: %s", opts.update_type)
    h.notify_debug("now: %s", _get_pretty_date(now))
  end

  local dated_files = fs.read(dated_files_path)
  if not dated_files[db_index] then
    dated_files[db_index] = {}
  end

  if debug then
    h.notify_debug("dated_files: %s", vim.inspect(dated_files))
  end

  local updated_date_at_score_one
  if opts.update_type == "increase" then
    local score = 0
    local date_at_score_one = dated_files[db_index][filename]
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

  dated_files[db_index][filename] = updated_date_at_score_one
  fs.write { path = dated_files_path, data = dated_files, encode = true, }

  --- @type ScoredFile[]
  local scored_files = {}
  local updated_dated_files = {}
  local max_score = 0
  for dated_file_entry, date_at_one_point_entry in pairs(dated_files[db_index]) do
    local recomputed_score = M.compute_score { now = now, date_at_score_one = date_at_one_point_entry, }

    local readable = vim.uv.fs_stat(dated_file_entry) ~= nil

    if readable then
      max_score = math.max(max_score, recomputed_score)
      table.insert(scored_files, { filename = dated_file_entry, score = recomputed_score, })
      updated_dated_files[dated_file_entry] = date_at_one_point_entry
    end
  end
  dated_files[db_index] = updated_dated_files
  fs.write {
    data = dated_files,
    path = dated_files_path,
    encode = true,
  }
  local max_scores = fs.read(max_scores_path)
  max_scores[db_index] = max_score
  fs.write {
    data = max_scores,
    path = max_scores_path,
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

  local scored_files_list = {}
  for _, scored_file in pairs(scored_files) do
    if prepend_score then
      local formatted_score = h.exact_decimals(scored_file.score, 2)
      table.insert(scored_files_list, ("%s:%s"):format(formatted_score, scored_file.filename))
    else
      table.insert(scored_files_list, scored_file.filename)
    end
  end
  local sorted_files_str = table.concat(scored_files_list, "\n")
  if #sorted_files_str > 0 then
    sorted_files_str = sorted_files_str .. "\n"
  end

  fs.write {
    path = sorted_files_path,
    data = sorted_files_str,
    encode = false,
  }
end

return M
