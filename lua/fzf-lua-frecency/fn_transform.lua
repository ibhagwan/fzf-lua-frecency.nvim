local M = {}

--- @class GetFnTransformOpts
--- @field cwd string
--- @field display_score boolean
--- @field debug boolean
--- @field db_dir string
--- @field fd_cmd string

--- @param opts GetFnTransformOpts
M.get_fn_transform = function(opts)
  return function(abs_file)
    local fzf_lua = require "fzf-lua"
    local algo = require "fzf-lua-frecency.algo"
    local rel_file = vim.fs.relpath(opts.cwd, abs_file)
    local entry = fzf_lua.make_entry.file(rel_file, { file_icons = true, color_icons = true, })

    if opts.display_score then
      local formatted_score = algo.get_score_prefix(abs_file, {
        db_dir = opts.db_dir,
        cwd = opts.cwd,
      })
      return ("%s %s"):format(formatted_score, entry)
    end

    return entry
  end
end

return M
