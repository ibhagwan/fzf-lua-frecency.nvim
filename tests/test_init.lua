local h = require "fzf-lua-frecency.helpers"
local fzf_lua_frecency = require "fzf-lua-frecency.init"
local fzf_lua = require "fzf-lua"

local root_dir = vim.fs.joinpath(vim.fn.getcwd(), "test-init")
local db_dir = vim.fs.joinpath(root_dir, "db-dir")
local db_index = 1
local sorted_files_path = h.get_sorted_files_path(db_dir)
local dated_files_path = h.get_dated_files_path(db_dir)
local max_scores_path = h.get_max_scores_path(db_dir)
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
    print("cmd", cmd)
    called.cmd = cmd
    called.opts = opts
  end

  fzf_lua_frecency.frecency {
    db_dir = db_dir,
    all_files = true,
  }

  MiniTest.expect.equality(called.opts.all_files, true)

  local cat_cmd = ("cat %s 2>/dev/null"):format(sorted_files_path)
  local fd_cmd = "fd --absolute-path --type f --type l --exclude .git"
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
      local now = os.time { year = 2025, month = 1, day = 1, hour = 0, min = 0, sec = 0, }
      local now_after_30_min = os.time { year = 2025, month = 1, day = 1, hour = 0, min = 30, sec = 0, }

      write_file(sorted_files_path, "file_1.txt\nfile")
      write_file(dated_files_path, vim.mpack.encode { [db_index] = { file_1 = now, file_2 = now_after_30_min, }, })
      write_file(max_scores_path, vim.mpack.encode { [db_index] = { 1, }, })
      write_file(existing_file_path, "existing content")
    end,
    post_case = function()
      os.remove(sorted_files_path)
      os.remove(dated_files_path)
      os.remove(max_scores_path)
      os.remove(existing_file_path)
    end,
  },

}
T["#clear_db"]["deletes the cwd dir, dated-files.mpack, max-scores.mpack, and nothing else"] = function()
  MiniTest.expect.equality(
    vim.uv.fs_stat(sorted_files_path) ~= nil,
    true
  )
  MiniTest.expect.equality(
    vim.uv.fs_stat(dated_files_path) ~= nil,
    true
  )
  MiniTest.expect.equality(
    vim.uv.fs_stat(existing_file_path) ~= nil,
    true
  )
  MiniTest.expect.equality(
    vim.uv.fs_stat(max_scores_path) ~= nil,
    true
  )

  fzf_lua_frecency.clear_db {
    db_dir = db_dir,
  }

  MiniTest.expect.equality(
    vim.uv.fs_stat(sorted_files_path) == nil,
    true
  )
  MiniTest.expect.equality(
    vim.uv.fs_stat(dated_files_path) == nil,
    true
  )
  MiniTest.expect.equality(
    vim.uv.fs_stat(max_scores_path) == nil,
    true
  )

  MiniTest.expect.equality(
    vim.fn.isdirectory(db_dir),
    h.vimscript_true
  )
  MiniTest.expect.equality(
    vim.uv.fs_stat(existing_file_path) ~= nil,
    true
  )
end

return T
