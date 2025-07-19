local h = require "fzf-lua-frecency.helpers"
local fzf_lua_frecency = require "fzf-lua-frecency.init"
local fzf_lua = require "fzf-lua"

local root_dir = vim.fs.joinpath(vim.fn.getcwd(), "test-init")
local db_dir = vim.fs.joinpath(root_dir, "db-dir")
local cwd = vim.fs.joinpath(root_dir, "files")
local sorted_files_path = vim.fs.joinpath(db_dir, "cwds", cwd, "sorted-files.txt")
local dated_files_path = vim.fs.joinpath(db_dir, "dated-files.mpack")
local existing_file_path = vim.fs.joinpath(db_dir, "existing-dir", "existing-file.txt")

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

T["#frecency"] = MiniTest.new_set()
T["#frecency"]["builds the correct fzf command and calls fzf_exec"] = function()
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
  MiniTest.expect.equality(called.cmd, ("(%s; %s) | awk '!x[$0]++'"):format(cat_cmd, fd_cmd))
end

local function write_file(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local file = io.open(path, "w")
  assert(file, "io.open failed!")
  file:write(contents)
  file:close()
end

T["#clear_db"] = MiniTest.new_set {
  hooks = {
    pre_case = function()
      write_file(sorted_files_path, vim.mpack.encode { foo = "bar", num = 42, })
      write_file(dated_files_path, vim.mpack.encode { foo = "bar", num = 42, })
      write_file(existing_file_path, vim.mpack.encode { foo = "bar", num = 42, })
    end,
    post_case = function()
      os.remove(sorted_files_path)
      os.remove(dated_files_path)
      os.remove(existing_file_path)
    end,
  },

}
T["#clear_db"]["deletes the cwd dir, dated-files.mpack, and nothing else"] = function()
  MiniTest.expect.equality(
    vim.fn.filereadable(sorted_files_path),
    h.vimscript_true
  )
  MiniTest.expect.equality(
    vim.fn.filereadable(dated_files_path),
    h.vimscript_true
  )
  MiniTest.expect.equality(
    vim.fn.filereadable(existing_file_path),
    h.vimscript_true
  )

  fzf_lua_frecency.clear_db {
    db_dir = db_dir,
  }

  MiniTest.expect.equality(
    vim.fn.filereadable(sorted_files_path),
    h.vimscript_false
  )
  MiniTest.expect.equality(
    vim.fn.filereadable(dated_files_path),
    h.vimscript_false
  )
  MiniTest.expect.equality(
    vim.fn.isdirectory(vim.fs.joinpath(db_dir, "cwds")),
    h.vimscript_false
  )

  MiniTest.expect.equality(
    vim.fn.isdirectory(db_dir),
    h.vimscript_true
  )
  MiniTest.expect.equality(
    vim.fn.filereadable(existing_file_path),
    h.vimscript_true
  )
end

return T
