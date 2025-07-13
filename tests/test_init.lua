local fzf_lua_frecency = require "fzf-lua-frecency.init"
local fzf_lua = require "fzf-lua"

local db_dir = vim.fs.joinpath(vim.fn.getcwd(), "test-init", "db-dir")
local cwd = vim.fs.joinpath(vim.fn.getcwd(), "test-init", "files")
local sorted_files_path = vim.fs.joinpath(db_dir, "cwds", cwd, "sorted-files.txt")

local fzf_lua_fzf_exec = fzf_lua.fzf_exec

local function cleanup()
  fzf_lua.fzf_exec = fzf_lua_fzf_exec
end

local T = MiniTest.new_set {
  hooks = {
    pre_case = cleanup,
    post_case = cleanup,
  },
}

T["frecency builds the correct fzf command and calls fzf_exec"] = function()
  local called = {
    cmd = nil,
    opts = nil,
  }

  fzf_lua.fzf_exec = function(cmd, opts)
    called.cmd = cmd
    called.opts = opts
  end

  fzf_lua_frecency.frecency {
    cwd = cwd,
    fzf_lua_frecency = {
      db_dir = db_dir,
    },
  }

  local cat_cmd = ("cat %s 2>/dev/null"):format(sorted_files_path)
  local fd_cmd = ("fd --absolute-path --type f --type l --exclude .git --base-directory %s"):format(cwd)
  MiniTest.expect.equality(called.cmd, ("cat <(%s) <(%s)"):format(cat_cmd, fd_cmd))
end

return T
