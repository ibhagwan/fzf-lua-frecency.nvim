local M = {}

--- @param opts FrecencyOpts
M.get_fn_transform = function(opts)
  return function(abs_file)
    local fzf_lua          = require "fzf-lua"
    local fs               = require "fzf-lua-frecency.fs"
    local h                = require "fzf-lua-frecency.helpers"
    local algo             = require "fzf-lua-frecency.algo"
    local now              = os.time()

    local defaulted_opts   = h.get_defaulted_frecency_opts(opts)
    local cwd              = defaulted_opts.cwd
    local db_dir           = defaulted_opts.db_dir
    local display_score    = defaulted_opts.display_score

    local dated_files_path = h.get_dated_files_path(db_dir)
    local max_scores_path  = h.get_max_scores_path(db_dir)

    local dated_files      = fs.read(dated_files_path)
    local max_scores       = fs.read(max_scores_path)
    local max_score        = h.default(max_scores[cwd], 0)
    local max_score_len    = #h.exact_decimals(max_score, 2)

    local rel_file         = vim.fs.relpath(cwd, abs_file)
    local entry            = fzf_lua.make_entry.file(rel_file, opts)

    if display_score then
      local score = nil
      local date_at_score_one = dated_files[cwd] and dated_files[cwd][abs_file] or nil
      if date_at_score_one then
        score = algo.compute_score { now = now, date_at_score_one = date_at_score_one, }
      end

      local formatted_score
      if max_score == 0 then
        formatted_score = ""
      elseif score == nil then
        formatted_score = (" "):rep(max_score_len)
      else
        formatted_score = h.pad_str(h.exact_decimals(score, 2), max_score_len)
      end
      return ("%s %s"):format(formatted_score, entry)
    end

    return entry
  end
end

return M
