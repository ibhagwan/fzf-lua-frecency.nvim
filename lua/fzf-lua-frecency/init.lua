local M = {}

vim.fn.setenv("FZF_LUA_FRECENCY_SERVER", vim.v.servername)

--- @class FzfLuaFrecencyTbl
--- @field debug boolean
--- @field db_dir string the directory in which to persist frecency scores
--- @field fd_cmd string
--- @field display_score boolean

--- @class FrecencyFnOpts
--- @field fzf_lua_frecency FzfLuaFrecencyTbl
--- @field [string] any any fzf-lua option

--- @param opts FrecencyFnOpts
M.frecency = function(opts)
  opts = opts or {}
  require "fzf-lua-frecency.rpc_state".opts = opts
  local h = require "fzf-lua-frecency.helpers"

  local defaulted_opts = h.get_defaulted_frecency_opts(opts)
  local cwd = defaulted_opts.cwd
  local db_dir = defaulted_opts.db_dir
  local debug = defaulted_opts.debug
  local fd_cmd = defaulted_opts.fd_cmd

  local sorted_files_path = h.get_sorted_files_path(db_dir, cwd)
  local dated_files_path = h.get_dated_files_path(db_dir)
  local max_scores_path = h.get_max_scores_path(db_dir)
  local fzf_lua = require "fzf-lua"
  local algo = require "fzf-lua-frecency.algo"

  local wrapped_enter = function(action)
    return function(selected, action_opts)
      vim.schedule(function()
        local now = os.time()
        for _, sel in ipairs(selected) do
          -- based on https://github.com/ibhagwan/fzf-lua/blob/bee05a6600ca5fe259d74c418ac9e016a6050cec/lua/fzf-lua/actions.lua#L147
          local filename = fzf_lua.path.entry_to_file(sel, action_opts, action_opts._uri).path
          algo.update_file_score(filename, {
            now = now,
            debug = debug,
            dated_files_path = dated_files_path,
            sorted_files_path = sorted_files_path,
            max_scores_path = max_scores_path,
            cwd = cwd,
            update_type = "increase",
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
        local now = os.time()
        for _, sel in ipairs(selected) do
          local filename = fzf_lua.path.entry_to_file(sel, action_opts, action_opts._uri).path
          algo.update_file_score(filename, {
            now = now,
            debug = debug,
            dated_files_path = dated_files_path,
            sorted_files_path = sorted_files_path,
            max_scores_path = max_scores_path,
            cwd = cwd,
            update_type = "remove",
          })
        end
      end,
      reload = true,
    },
  })

  -- relevant options from the default `files` options
  -- https://github.com/ibhagwan/fzf-lua/blob/f972ad787ee8d3646d30000a0652e9b168a90840/lua/fzf-lua/defaults.lua#L336-L360
  local default_opts = {
    actions      = actions,
    previewer    = "builtin",
    file_icons   = true,
    color_icons  = true,
    git_icons    = false,
    fzf_opts     = {
      ["--multi"] = true,
      ["--scheme"] = "path",
      ["--no-sort"] = true,
      ["--header"] = (":: <%s> to %s"):format(
        fzf_lua.utils.ansi_from_hl("FzfLuaHeaderBind", "ctrl-x"),
        fzf_lua.utils.ansi_from_hl("FzfLuaHeaderText", "delete a frecency score")
      ),
    },
    winopts      = {
      preview = {
        winopts = { cursorline = false, },
      },
    },
    multiprocess = true,
    fn_transform = function(abs_file)
      local ok, rpc_opts = pcall(function()
        local chan = vim.fn.sockconnect("pipe", vim.fn.getenv "FZF_LUA_FRECENCY_SERVER", { rpc = true, })
        local rpc_response = vim.rpcrequest(chan, "nvim_exec_lua", 'return require "fzf-lua-frecency.rpc_state".opts', {})
        vim.fn.chanclose(chan)
        return rpc_response
      end)

      if not ok then
        return require "fzf-lua".make_entry.file(abs_file)
      end

      return require "fzf-lua-frecency.fn_transform".get_fn_transform(rpc_opts)(abs_file)
    end,
  }
  local fzf_exec_opts = vim.tbl_deep_extend("force", default_opts, opts)

  local cat_cmd = table.concat({
    "cat",
    sorted_files_path,
    "2>/dev/null",
  }, " ")

  local awk_cmd = "awk '!x[$0]++'"                             -- https://stackoverflow.com/a/11532198
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
