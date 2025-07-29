local h = require "fzf-lua-frecency.helpers"
local algo = require "fzf-lua-frecency.algo"

-- Runtime path for this package, to be used with the headless instance for loading
local __FILE__ = debug.getinfo(1, "S").source:gsub("^@", "")
local __RTP__ = vim.fn.fnamemodify(__FILE__, ":h:h:h")

local M = {}

--- @class FrecencyFnOpts
--- @field debug boolean
--- @field db_dir string
--- @field all_files boolean
--- @field stat_file boolean
--- @field display_score boolean
--- @field [string] any any fzf-lua option


local function get_files_cmd(opts)
  local cmd
  local fd_args = table.concat({
    "--absolute-path",
    "--type", "f",
    "--type", "l",
    "--exclude", ".git",
  }, " ")
  if vim.fn.executable "fdfind" == 1 then
    cmd = string.format("fdfind %s", fd_args)
  elseif vim.fn.executable "fd" == 1 then
    cmd = string.format("fd %s", fd_args)
  elseif vim.fn.executable "rg" == 1 then
    -- return [[rg --files -g "\!.git" "$(pwd)"]]
    cmd = string.format([[rg --files -g "!.git"]], opts.cmd or vim.uv.cwd())
  else
    FzfLua.utils.warn "[fzf-lua-frecency] 'all_files' requires 'fd' or 'rg'."
    return nil
  end
  for k, v in pairs {
    follow = opts.toggle_follow_flag or "-L",
    hidden = opts.toggle_hidden_flag or "--hidden",
    no_ignore = opts.toggle_ignore_flag or "--no-ignore",
  } do
    (function()
      local toggle, is_find = opts[k], nil
      -- Do nothing unless opt was set
      if opts[k] == nil then return end
      if cmd:match "^dir" then return end
      if cmd:match "^find" then
        if k == "no_ignore" then return end
        if k == "hidden" then
          is_find = true
          toggle = not opts[k]
          v = [[\! -path '*/.*']]
        end
      end
      cmd = FzfLua.utils.toggle_cmd_flag(cmd, v, toggle, is_find)
    end)()
  end
  return cmd
end

--- @diagnostic disable-next-line: unused-local
M.setup = function(opts)
  -- Singleton setup
  if M._did_setup then return end
  M._did_setup = true

  -- Trigger lazy loading if need be, creates the FzfLua global object
  require "fzf-lua"

  -- Register as an fzf-lua extenstion, merge default opts with users' setup opts
  FzfLua.register_extension("frecency", M.frecency, vim.tbl_deep_extend("keep", opts or {}, {
      -- fzf-lua-frecency specific defaults
      cwd_only = false,
      all_files = nil,
      stat_file = true,
      display_score = true,
      -- Relevant options from fzf-lua's default `files` options
      _type = "file", -- Adds `fn_preprocess` if required
      previewer = FzfLua.defaults.files.previewer, -- Inherit from default previewer (if `bat`)
      multiprocess = true,
      file_icons = true,
      color_icons = true,
      git_icons = false,
      fzf_opts = {
        ["--multi"] = true,
        ["--scheme"] = "path",
        ["--no-sort"] = true,
      },
      winopts = {
        title = " Frecency ",
        preview = { winopts = { cursorline = false, }, },
      },
      -- Display cwd (if different) and action (ctrl-x) headers
      _headers = { "cwd", "actions", },
      -- Inherit actions from the users' setup/global `actions.files`
      _actions = function() return FzfLua.config.globals.actions.files end,
      -- Adds `ctrl-x` to the default actions
      actions = {
        ["ctrl-x"] = {
          fn = function(selected, o)
            for _, sel in ipairs(selected) do
              local filename = FzfLua.path.entry_to_file(sel, o).path
              algo.update_file_score(filename, { update_type = "remove", })
            end
          end,
          desc = "delete-score",
          header = "delete a frecency score",
          reload = true,
        },
      },
    }),
    true)
  -- Update score of all files when editing / changing windows
  vim.api.nvim_create_autocmd({ "BufWinEnter", }, {
    group = vim.api.nvim_create_augroup("FzfLuaFrecency", { clear = true, }),
    callback = function(ev)
      local current_win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(current_win).relative ~= "" then
        return
      end
      algo.update_file_score(vim.api.nvim_buf_get_name(ev.buf), { update_type = "increase", })
    end,
  })
end

--- @param opts FrecencyFnOpts
M.frecency = function(opts)
  -- Does nothing if already called, will lazy load fzf-lua
  -- and create the FzfLua global object
  M.setup()

  -- Normalize users' opts with our (registered) defaults and fzf-lua's
  -- (keymaps, previewers, special options, fzf/skim version check, etc)
  opts = FzfLua.config.normalize_opts(opts, "frecency")
  if not opts then return end

  -- Set default cwd if needed
  opts.cwd = opts.cwd or vim.uv.cwd()

  local db_dir = h.default(opts.db_dir, h.get_default_db_dir())
  local sorted_files_path = h.get_sorted_files_path(db_dir)

  -- Options that fzf-lua's multiprocess does not serialize
  -- these aren't included in the fn_transform callback opts
  --- @type GetFnTransformOpts
  local encodeable_opts = {
    db_dir = db_dir,
    stat_file = opts.stat_file,
    display_score = opts.display_score,
  }

  -- Clear the global db vars on exit, only matters on `multiprocess=false`
  -- with `multiprocess=true` fn_preprocess is called in the headless process
  -- and the global vars are created there
  opts.fn_selected = function(...)
    _G._fzf_lua_frecency_dated_files = nil
    _G._fzf_lua_frecency_max_scores = nil
    FzfLua.actions.act(...)
  end

  -- RPC worked fine on linux, be was hanging on mac - specifically vim.rpcrequest
  -- using basic string interpolation works well since all the opts that are used
  -- can be stringified
  opts.fn_transform = string.format([[
    vim.opt.runtimepath:append("%s")
    local rpc_opts = vim.mpack.decode(%q)
    return require "fzf-lua-frecency.fn_transform".get_fn_transform(rpc_opts)
  ]], __RTP__, vim.mpack.encode(encodeable_opts))

  -- Create the shell command, adds file enumeration (fd|rg) and dedup (awk)
  opts.cmd = (function()
    -- If caller did not specifically set `all_files` set to true if `cwd_only=true`
    local all_files = opts.all_files == nil and opts.cwd_only or opts.all_files
    local cat_cmd = table.concat({
      "cat",
      sorted_files_path,
      "2>/dev/null",
    }, " ")
    if not all_files then return cat_cmd end
    local all_files_cmd = get_files_cmd(opts)
    -- `all_files_cmd` will return nil of fd|rg aren't installed
    if not all_files_cmd then return cat_cmd end
    local awk_cmd = "awk '!x[$0]++'" -- https://stackoverflow.com/a/11532198
    return ("(%s; %s) | %s"):format(cat_cmd, all_files_cmd, awk_cmd)
  end)()

  -- Set title flags (h|i|f) based on hidden/no-ignore/follow flags
  opts = FzfLua.core.set_title_flags(opts, { "cmd", })
  return FzfLua.fzf_exec(opts.cmd, opts)
end

--- @class ClearDbOpts
--- @field db_dir? string

--- Deletes the `dated-files.mpack` file and the `cwds` directory.
--- Does not delete `db_dir` itself or anything else in `db_dir`
--- @param opts? ClearDbOpts
M.clear_db = function(opts)
  opts = opts or {}
  local db_dir = h.default(opts.db_dir, h.get_default_db_dir())
  local sorted_files_path = h.get_sorted_files_path(db_dir)
  local dated_files_path = h.get_dated_files_path(db_dir)
  local max_scores_path = h.get_max_scores_path(db_dir)

  vim.fn.delete(sorted_files_path)
  vim.fn.delete(dated_files_path)
  vim.fn.delete(max_scores_path)
end

return M
