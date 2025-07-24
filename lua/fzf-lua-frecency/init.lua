local M = {}

--- @class FzfLuaFrecencyTbl
--- @field debug boolean
--- @field db_dir string
--- @field fd_cmd string
--- @field display_score boolean

--- @class FrecencyFnOpts
--- @field fzf_lua_frecency FzfLuaFrecencyTbl
--- @field [string] any any fzf-lua option

--- @param opts FrecencyFnOpts
M.frecency = function(opts)
  opts = opts or {}
  local h = require "fzf-lua-frecency.helpers"

  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local frecency_opts = h.default(opts.fzf_lua_frecency, {})
  local display_score = h.default(frecency_opts.display_score, false)
  local debug = h.default(frecency_opts.debug, false)
  local db_dir = h.default(frecency_opts.db_dir, h.get_default_db_dir())
  local default_fd_cmd = table.concat({
    "fd",
    "--absolute-path",
    "--type", "f",
    "--type", "l",
    "--exclude", ".git",
    "--base-directory", cwd,
  }, " ")
  local fd_cmd = h.default(frecency_opts.fd_cmd, default_fd_cmd)


  local sorted_files_path = h.get_sorted_files_path(db_dir, cwd)
  local fzf_lua = require "fzf-lua"
  local algo = require "fzf-lua-frecency.algo"

  local wrapped_enter = function(action)
    return function(selected, action_opts)
      vim.schedule(function()
        for _, sel in ipairs(selected) do
          if display_score then
            sel = h.strip_score(sel)
          end
          -- https://github.com/ibhagwan/fzf-lua/wiki/Advanced#explore-changes-from-a-git-branch
          local filename = fzf_lua.path.entry_to_file(sel, action_opts).path
          algo.update_file_score(filename, {
            update_type = "increase",
            cwd = cwd,
            db_dir = db_dir,
            fd_cmd = fd_cmd,
          })
        end
      end)

      return action(selected, action_opts)
    end
  end

  local actions = vim.tbl_deep_extend("force", fzf_lua.defaults.actions.files, {
    enter = wrapped_enter(fzf_lua.defaults.actions.files.enter),
    ["ctrl-x"] = {
      fn = function(selected, action_opts)
        for _, sel in ipairs(selected) do
          if display_score then
            sel = h.strip_score(sel)
          end

          local filename = fzf_lua.path.entry_to_file(sel, action_opts).path
          algo.update_file_score(filename, {
            update_type = "remove",
            cwd = cwd,
            db_dir = db_dir,
            fd_cmd = fd_cmd,
          })
        end
      end,
      reload = true,
    },
  })

  --- @type GetFnTransformOpts
  local encodeable_opts = {
    cwd = cwd,
    display_score = display_score,
    debug = debug,
    db_dir = db_dir,
    fd_cmd = fd_cmd,
  }

  -- RPC worked fine on linux, be was hanging on mac - specifically vim.rpcrequest
  -- using basic string interpolation works well since all the opts that are used can be stringified
  local fn_transform_str = string.format([[
    local abs_file = ...
    local rpc_opts = vim.mpack.decode(%q)
    return require "fzf-lua-frecency.fn_transform".get_fn_transform(rpc_opts)(abs_file)
  ]], vim.mpack.encode(encodeable_opts))

  local fn_transform
  local fn_transform_ok, fn_transform_res = pcall(loadstring, fn_transform_str)
  if fn_transform_ok then
    fn_transform = fn_transform_res
  else
    fn_transform = function(file) return require "fzf-lua".make_entry.file(file) end
  end

  -- relevant options from the default `files` options
  -- https://github.com/ibhagwan/fzf-lua/blob/f972ad787ee8d3646d30000a0652e9b168a90840/lua/fzf-lua/defaults.lua#L336-L360
  local default_opts = {
    actions = actions,
    previewer = "builtin",
    file_icons = true,
    color_icons = true,
    git_icons = false,
    fzf_opts = {
      ["--multi"] = true,
      ["--scheme"] = "path",
      ["--no-sort"] = true,
      ["--header"] = (":: <%s> to %s"):format(
        fzf_lua.utils.ansi_from_hl("FzfLuaHeaderBind", "ctrl-x"),
        fzf_lua.utils.ansi_from_hl("FzfLuaHeaderText", "delete a frecency score")
      ),
    },
    winopts = {
      preview = {
        winopts = { cursorline = false, },
      },
    },
    multiprocess = true,
    fn_transform = fn_transform,
  }
  local fzf_exec_opts = vim.tbl_deep_extend("force", default_opts, opts)

  local cat_cmd = table.concat({
    "cat",
    sorted_files_path,
    "2>/dev/null",
  }, " ")

  local awk_cmd = "awk '!x[$0]++'" -- https://stackoverflow.com/a/11532198
  local cmd = ("(%s; %s) | %s"):format(cat_cmd, fd_cmd, awk_cmd)
  fzf_lua.fzf_exec(cmd, fzf_exec_opts)
end

--- @class ClearDbOpts
--- @field db_dir? string

--- Deletes the `dated-files.mpack` file and the `cwds` directory.
--- Does not delete `db_dir` itself or anything else in `db_dir`
--- @param opts? ClearDbOpts
M.clear_db = function(opts)
  local h = require "fzf-lua-frecency.helpers"
  opts = opts or {}
  local db_dir = h.default(opts.db_dir, h.get_default_db_dir())
  local sorted_files_dir = vim.fs.joinpath(db_dir, "cwds")
  local dated_files_path = h.get_dated_files_path(db_dir)
  local max_scores_path = h.get_max_scores_path(db_dir)

  vim.fn.delete(sorted_files_dir, "rf")
  vim.fn.delete(dated_files_path)
  vim.fn.delete(max_scores_path)
end

return M
