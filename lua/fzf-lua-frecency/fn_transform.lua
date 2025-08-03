local M = {}

--- @class GetFnTransformOpts
--- @field stat_file boolean
--- @field display_score boolean
--- @field db_dir string

--- @param rpc_opts GetFnTransformOpts
M.get_fn_transform = function(rpc_opts)
  return function(abs_file, opts)
    local entry = FzfLua.make_entry.file(abs_file, opts)
    if not entry then return end

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
      _G._fzf_lua_frecency_dated_files = fs.read(dated_files_path)
    end

    local dated_files = _G._fzf_lua_frecency_dated_files
    if not dated_files[db_index] then
      dated_files[db_index] = {}
    end
    local date_at_score_one = dated_files[db_index][abs_file]

    local max_score = 999
    local max_score_len = #h.exact_decimals(max_score, 2)

    -- only call fs_stat on files from the db, fd/rg files are guaranteed to exist
    if rpc_opts.stat_file and date_at_score_one then
      local stat_result = vim.uv.fs_stat(abs_file)
      if not stat_result then return end
      if stat_result.type ~= "file" then return end
    end

    if rpc_opts.display_score then
      local score = nil
      if date_at_score_one then
        score = algo.compute_score { now = now, date_at_score_one = date_at_score_one, }
      end

      local formatted_score
      if score == nil then
        formatted_score = (" "):rep(max_score_len)
      else
        formatted_score = h.pad_str(h.fit_decimals(score, max_score_len), max_score_len)
      end
      return ("%s%s%s"):format(formatted_score, FzfLua.utils.nbsp, entry)
    end

    return entry
  end
end

return M
