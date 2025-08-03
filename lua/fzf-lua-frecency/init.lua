local h = require "fzf-lua-frecency.helpers"
local algo = require "fzf-lua-frecency.algo"

-- runtime path for this package, to be used with the headless instance for loading
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
  -- https://github.com/ibhagwan/fzf-lua/blob/e40e2337611fa426b8bcb6989fc310035c6ec4aa/README.md?plain=1#L831-L833
  local default_fd_opts = [[--absolute-path --color=never --hidden --type f --type l --exclude .git]]
  local default_rg_opts = string.format([[--color=never --hidden --files -g "!.git" %s]], opts.cwd)
  local default_find_opts = string.format([[%s -type f \! -path '*/.git/*']], opts.cwd)

  local fd_opts = h.default(opts.fd_opts, default_fd_opts)
  local find_opts = h.default(opts.find_opts, default_find_opts)
  local rg_opts = h.default(opts.rg_opts, default_rg_opts)

  local cmd
  if vim.fn.executable "fdfind" == h.vimscript_true then
    cmd = ("fdfind %s"):format(fd_opts)
  elseif vim.fn.executable "fd" == h.vimscript_true then
    cmd = ("fd %s"):format(fd_opts)
  elseif vim.fn.executable "rg" == h.vimscript_true then
    cmd = ("rg %s"):format(rg_opts)
  elseif vim.fn.executable "find" == h.vimscript_true then
    cmd = ("find %s"):format(find_opts)
  else
    FzfLua.utils.warn "[fzf-lua-frecency] 'all_files' requires 'fd', 'rg', or 'find'."
    return nil
  end

  local toggle_flags = {
    follow = h.default(opts.toggle_follow_flag, "-L"),
    hidden = h.default(opts.toggle_hidden_flag, "--hidden"),
    no_ignore = h.default(opts.toggle_ignore_flag, "--no-ignore"),
  }

  for flag_name, flag_value in pairs(toggle_flags) do
    (function()
      --- @type boolean | nil
      local flag_opt = opts[flag_name]
      if flag_opt == nil then return end
      if cmd:match "^dir" then return end

      local flag_to_use = flag_value
      local toggle_value = flag_opt
      local is_find_command = false

      if cmd:match "^find" then
        -- find doesn't support --no-ignore
        if flag_name == "no_ignore" then return end

        if flag_name == "hidden" then
          -- find uses different syntax and inverted logic for hidden files
          flag_to_use = [[\! -path '*/.*']]
          toggle_value = not flag_opt
          is_find_command = true
        end
      end

      cmd = FzfLua.utils.toggle_cmd_flag(cmd, flag_to_use, toggle_value, is_find_command)
    end)()
  end

  return cmd
end

--- @diagnostic disable-next-line: unused-local
M.setup = function(opts)
  if M._did_setup then return end
  M._did_setup = true

  -- creates the FzfLua global object
  require "fzf-lua"

  FzfLua.register_extension("frecency", M.frecency, vim.tbl_deep_extend("keep", opts or {}, {
      -- fzf-lua-frecency specific defaults
      cwd_only = false,
      all_files = nil,
      stat_file = true,
      display_score = true,
      -- relevant options from fzf-lua's default `files` options
      _type = "file", -- adds `fn_preprocess` if required
      previewer = FzfLua.defaults.files.previewer, -- inherit from default previewer (if `bat`)
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
      -- tell fzf to ignore fuzzy matching anything before the filename
      -- by adding a "--delimiter=utils.nbsp|--nth=-1.." to fzf_opts
      -- this avoids matching the score text/icons so we can perform
      -- searches like "^init.lua"
      _fzf_nth_devicons = true,
      -- display cwd (if different) and action (ctrl-x) headers
      _headers = { "cwd", "actions", },
      -- inherit actions from the users' setup/global `actions.files`
      _actions = function() return FzfLua.config.globals.actions.files end,
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

  vim.api.nvim_create_autocmd({ "BufWinEnter", }, {
    group = vim.api.nvim_create_augroup("FzfLuaFrecency", { clear = true, }),
    callback = function(ev)
      local current_win = vim.api.nvim_get_current_win()
      -- :h nvim_win_get_config({window}) "relative is empty for normal buffers"
      if vim.api.nvim_win_get_config(current_win).relative == "" then
        -- `nvim_buf_get_name` for unnamed buffers is an empty string
        local bname = vim.api.nvim_buf_get_name(ev.buf)
        if #bname > 0 then
          algo.update_file_score(bname, { update_type = "increase", })
        end
      end
    end,
  })
end

--- @param opts FrecencyFnOpts
M.frecency = function(opts)
  -- does nothing if already called
  M.setup()

  opts = FzfLua.config.normalize_opts(opts, "frecency")
  if not opts then return end

  opts.cwd = h.default(opts.cwd, vim.uv.cwd())
  local db_dir = h.default(opts.db_dir, h.get_default_db_dir())
  local sorted_files_path = h.get_sorted_files_path(db_dir)

  -- options that fzf-lua's multiprocess does not serialize
  -- these aren't included in the fn_transform callback opts
  --- @type GetFnTransformOpts
  local encodeable_opts = {
    db_dir = db_dir,
    stat_file = opts.stat_file,
    display_score = opts.display_score,
  }

  opts.fn_selected = function(...)
    _G._fzf_lua_frecency_dated_files = nil
    FzfLua.actions.act(...)
  end

  -- RPC worked fine on linux, but was hanging on mac - specifically vim.rpcrequest
  -- using basic string interpolation works well since all the opts that are used
  -- can be stringified
  opts.fn_transform = string.format([[
    vim.opt.runtimepath:append("%s")
    local rpc_opts = vim.mpack.decode(%q)
    return require "fzf-lua-frecency.fn_transform".get_fn_transform(rpc_opts)
  ]], __RTP__, vim.mpack.encode(encodeable_opts))

  opts.cmd = (function()
    local all_files
    if opts.all_files == nil then
      all_files = opts.cwd_only
    else
      all_files = opts.all_files
    end

    local cat_cmd = table.concat({
      "cat",
      sorted_files_path,
      "2>/dev/null", -- in case the file doesn't exist
    }, " ")
    if not all_files then
      return cat_cmd
    end

    local all_files_cmd = get_files_cmd(opts)
    if not all_files_cmd then return cat_cmd end

    local awk_cmd = "awk '!x[$0]++'" -- https://stackoverflow.com/a/11532198
    return ("(%s; %s) | %s"):format(cat_cmd, all_files_cmd, awk_cmd)
  end)()

  -- set title flags (h|i|f) based on hidden/no-ignore/follow flags
  opts = FzfLua.core.set_title_flags(opts, { "cmd", })
  return FzfLua.fzf_exec(opts.cmd, opts)
end

--- @class ClearDbOpts
--- @field db_dir? string

--- deletes the `dated-files.mpack` file and the `cwds` directory.
--- does not delete `db_dir` itself or anything else in `db_dir`
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
