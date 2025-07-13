local fzf_lua = require "fzf-lua"
local h = require "fzf-lua-frecency.helpers"
local algo = require "fzf-lua-frecency.algo"
local M = {}

M.frecency = function(opts)
  opts = opts or {}
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local frecency_opts = h.default(opts.fzf_lua_frecency, {})
  local debug = h.default(frecency_opts.debug, false)
  local db_dir = h.default(frecency_opts.db_dir, vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency"))
  local sorted_files_path = vim.fs.joinpath(db_dir, "cwds", cwd, "sorted-files.txt")
  local dated_files_path = vim.fs.joinpath(db_dir, "dated-files.mpack")

  local wrapped_enter = function(action)
    return function(selected, action_opts)
      vim.schedule(function()
        for _, sel in ipairs(selected) do
          -- based on https://github.com/ibhagwan/fzf-lua/blob/bee05a6600ca5fe259d74c418ac9e016a6050cec/lua/fzf-lua/actions.lua#L147
          local filename = fzf_lua.path.entry_to_file(sel, action_opts, action_opts._uri).path
          algo.add_file_score(filename, {
            debug = debug,
            dated_files_path = dated_files_path,
            sorted_files_path = sorted_files_path,
            cwd = cwd,
          })
        end
      end)

      return action(selected, action_opts)
    end
  end

  local actions = vim.tbl_extend("force", fzf_lua.defaults.actions.files, {
    enter = wrapped_enter(fzf_lua.defaults.actions.files.enter),
  })
  local seen = {}
  -- relevant options from the default `files` options
  -- https://github.com/ibhagwan/fzf-lua/blob/f972ad787ee8d3646d30000a0652e9b168a90840/lua/fzf-lua/defaults.lua#L336-L360
  local default_opts = {
    actions      = actions,
    previewer    = "builtin",
    multiprocess = true,
    file_icons   = true,
    color_icons  = true,
    git_icons    = false,
    fzf_opts     = { ["--multi"] = true, ["--scheme"] = "path", },
    winopts      = { preview = { winopts = { cursorline = false, }, }, },
    fn_transform = function(abs_file)
      if seen[abs_file] then return end
      seen[abs_file] = true

      local rel_file = vim.fs.relpath(cwd, abs_file)
      return fzf_lua.make_entry.file(rel_file, opts)
    end,
  }
  local fzf_exec_opts = vim.tbl_extend("force", default_opts, opts)

  local cat_cmd = table.concat({
    "cat",
    sorted_files_path,
    "2>/dev/null",
  }, " ")

  local fd_cmd = table.concat({
    "fd",
    "--absolute-path",
    "--type", "f",
    "--type", "l",
    "--exclude", ".git",
    "--base-directory", cwd,
  }, " ")

  local cmd = ("cat <(%s) <(%s)"):format(cat_cmd, fd_cmd)
  fzf_lua.fzf_exec(cmd, fzf_exec_opts)
end

return M
