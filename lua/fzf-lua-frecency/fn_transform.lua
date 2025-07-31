local M = {}

--- @class GetFnTransformOpts
--- @field stat_file boolean
--- @field display_score boolean
--- @field db_dir string

--- @param rpc_opts GetFnTransformOpts
M.get_fn_transform = function(rpc_opts)
  return function(abs_file, opts)
    -- Call fzf-lua's entry maker, filters out cwd/cwd_only/file_ignore_patterns, etc
    -- will also make the file path relative, use formatters, path_shorten, etc
    local entry = FzfLua.make_entry.file(abs_file, opts)
    if not entry then return end

    -- If we don't display score or test for the file on disk stop here
    if not rpc_opts.display_score and not rpc_opts.stat_file then
      return entry
    end

    local fs = require "fzf-lua-frecency.fs"
    local h = require "fzf-lua-frecency.helpers"
    local algo = require "fzf-lua-frecency.algo"
    local now = os.time()
    local db_index = 1

    if not _G._fzf_lua_frecency_dated_files then
      local dated_files_path = h.get_dated_files_path(rpc_opts.db_dir)
      local max_scores_path = h.get_max_scores_path(rpc_opts.db_dir)
      _G._fzf_lua_frecency_dated_files = fs.read(dated_files_path)
      _G._fzf_lua_frecency_max_scores = fs.read(max_scores_path)
     end

    local dated_files = _G._fzf_lua_frecency_dated_files
    local max_scores = _G._fzf_lua_frecency_max_scores
    local max_score = h.default(max_scores[db_index], 0)
    local max_score_len = #h.exact_decimals(max_score, 2)

    local date_at_score_one = dated_files[db_index] and dated_files[db_index][abs_file] or nil

    -- Only "stat" files from the db, fd|rg enumerated files guaranteed to exist
    if rpc_opts.stat_file and date_at_score_one then
      if not vim.uv.fs_stat(abs_file) then
        vim.schedule(function()
          -- File no longer exists,remove from the db, schedule to avoid E5560
          algo.update_file_score(abs_file, { update_type = "remove", })
        end)
        return
      end
    end

    if rpc_opts.display_score then
      local score = nil
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
      return ("%s%s%s"):format(formatted_score, FzfLua.utils.nbsp, entry)
    end

    return entry
  end
end

return M
