local fzf_lua = require "fzf-lua"
local h       = require "fzf-lua-frecency.helpers"
local algo    = require "fzf-lua-frecency.algo"
local fs      = require "fzf-lua-frecency.fs"

local M       = {}

local function get_default_db_dir()
  return vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency")
end

--- @param db_dir string
--- @param cwd string
local function get_sorted_files_path(db_dir, cwd)
  return vim.fs.joinpath(db_dir, "cwds", cwd, "sorted-files.txt")
end

--- @param db_dir string
local function get_dated_files_path(db_dir)
  return vim.fs.joinpath(db_dir, "dated-files.mpack")
end

--- @param db_dir string
local function get_max_scores_path(db_dir)
  return vim.fs.joinpath(db_dir, "max-scores.mpack")
end

--- @class FzfLuaFrecency
--- @field debug boolean
--- @field db_dir string the directory in which to persist frecency scores
--- @field fd_cmd string
--- @field display_score boolean

--- @class FrecencyOpts
--- @field fzf_lua_frecency FzfLuaFrecency
--- @field [string] any any fzf-lua option

--- @param opts FrecencyOpts
M.frecency = function(opts)
  opts = opts or {}
  local cwd = h.default(opts.cwd, vim.fn.getcwd())
  local frecency_opts = h.default(opts.fzf_lua_frecency, {})
  local display_score = h.default(frecency_opts.display_score, false)
  local debug = h.default(frecency_opts.debug, false)
  local db_dir = h.default(frecency_opts.db_dir, get_default_db_dir())
  local default_fd_cmd = table.concat({
    "fd",
    "--absolute-path",
    "--type", "f",
    "--type", "l",
    "--exclude", ".git",
    "--base-directory", cwd,
  }, " ")
  local fd_cmd = h.default(frecency_opts.fd_cmd, default_fd_cmd)
  local sorted_files_path = get_sorted_files_path(db_dir, cwd)
  local dated_files_path = get_dated_files_path(db_dir)
  local max_scores_path = get_max_scores_path(db_dir)
  local now = os.time()

  local wrapped_enter = function(action)
    return function(selected, action_opts)
      vim.schedule(function()
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
    winopts      = { preview = { winopts = { cursorline = false, }, }, },
    fn_transform = function(abs_file)
      local dated_files = fs.read(dated_files_path)
      local max_scores = fs.read(max_scores_path)
      local max_score = h.default(max_scores[cwd], 0)
      local max_score_len = #h.exact_decimals(max_score, 2)

      local rel_file = vim.fs.relpath(cwd, abs_file)
      local entry = fzf_lua.make_entry.file(rel_file, opts)

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
    end,
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
  opts = opts or {}
  local db_dir = h.default(opts.db_dir, get_default_db_dir())
  local sorted_files_dir = vim.fs.joinpath(db_dir, "cwds")
  local dated_files_path = get_dated_files_path(db_dir)

  vim.fn.delete(sorted_files_dir, "rf")
  vim.fn.delete(dated_files_path)
end

return M
