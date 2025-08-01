local transform = require "fzf-lua-frecency.fn_transform"
local algo = require "fzf-lua-frecency.algo"

local root_dir = vim.fs.joinpath(vim.fn.getcwd(), "test-fn-transform")
local db_dir = vim.fs.joinpath(root_dir, "db-dir")

local cwd = vim.fs.joinpath(root_dir, "files")
local test_file_a = vim.fs.joinpath(cwd, "test-file-a.txt")
local test_file_b = vim.fs.joinpath(cwd, "test-file-b.txt")

local now = os.time { year = 2025, month = 1, day = 1, hour = 0, min = 0, sec = 0, }
local now_after_30_min = os.time { year = 2025, month = 1, day = 1, hour = 0, min = 30, sec = 0, }

local function create_file(path)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local file = io.open(path, "w")
  if not file then
    error "io.open failed!"
  end
  file:write "content"
  file:close()
end

local os_time = os.time
local vim_schedule = vim.schedule
local uv_fs_stat = vim.uv.fs_stat
local algo_update_file_score = algo.update_file_score

local function cleanup()
  os.time = os_time
  vim.schedule = vim_schedule
  vim.uv.fs_stat = uv_fs_stat
  algo.update_file_score = algo_update_file_score

  _G.FzfLua.make_entry.file = function(filename) return filename end
  _G._fzf_lua_frecency_dated_files = nil
  vim.fn.delete(root_dir, "rf")
  create_file(test_file_a)
  create_file(test_file_b)
end

local T = MiniTest.new_set()
T["#get_fn_transform"] = MiniTest.new_set {
  hooks = {
    pre_case = cleanup,
    post_case = cleanup,
  },
}

T["#get_fn_transform"]["basic functionality"] = MiniTest.new_set()
T["#get_fn_transform"]["basic functionality"]["returns entry when no options enabled"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, test_file_a)
end

T["#get_fn_transform"]["basic functionality"]["returns nil when FzfLua.make_entry.file returns nil"] = function()
  local original_make_entry = _G.FzfLua.make_entry.file
  _G.FzfLua.make_entry.file = function() return nil end

  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, nil)

  _G.FzfLua.make_entry.file = original_make_entry
end

T["#get_fn_transform"]["display_score"] = MiniTest.new_set()

T["#get_fn_transform"]["display_score"]["displays padded spaces for file not in db"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  local expected = (" "):rep(6) .. _G.FzfLua.utils.nbsp .. test_file_a
  MiniTest.expect.equality(result, expected)
end

T["#get_fn_transform"]["display_score"]["displays score for file in db"] = function()
  os.time = function() return now end

  algo.update_file_score(test_file_a, {
    db_dir = db_dir,
    update_type = "increase",
  })

  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  local expected = "  1.00" .. _G.FzfLua.utils.nbsp .. test_file_a
  MiniTest.expect.equality(result, expected)
end

T["#get_fn_transform"]["display_score"]["displays decayed score"] = function()
  os.time = function() return now end
  algo.update_file_score(test_file_a, {
    db_dir = db_dir,
    update_type = "increase",
  })
  os.time = function() return now_after_30_min end

  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  local expected = "  0.99" .. _G.FzfLua.utils.nbsp .. test_file_a
  MiniTest.expect.equality(result, expected)
end

T["#get_fn_transform"]["stat_file"] = MiniTest.new_set()

T["#get_fn_transform"]["stat_file"]["returns entry for existing file in db"] = function()
  os.time = function() return now end

  algo.update_file_score(test_file_a, {
    db_dir = db_dir,
    update_type = "increase",
  })

  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, test_file_a)
end

T["#get_fn_transform"]["stat_file"]["returns entry for file not in db"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, test_file_a)
end

T["#get_fn_transform"]["stat_file"]["schedules removal for nonexistent file in db"] = function()
  os.time = function() return now end

  algo.update_file_score(test_file_a, {
    db_dir = db_dir,
    update_type = "increase",
  })

  vim.uv.fs_stat = function(path)
    if path == test_file_a then
      return nil
    end
  end

  local scheduled_fn = nil
  vim.schedule = function(fn)
    scheduled_fn = fn
  end

  local update_called = false
  local update_args = {}
  algo.update_file_score = function(filename, opts)
    update_called = true
    update_args = { filename, opts, }
  end

  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, nil)
  MiniTest.expect.equality(type(scheduled_fn), "function")

  scheduled_fn()
  MiniTest.expect.equality(update_called, true)
  MiniTest.expect.equality(update_args[1], test_file_a)
  MiniTest.expect.equality(update_args[2].update_type, "remove")
end

T["#get_fn_transform"]["combined options"] = MiniTest.new_set()

T["#get_fn_transform"]["combined options"]["stat_file and display_score for existing file"] = function()
  os.time = function() return now end

  algo.update_file_score(test_file_a, {
    db_dir = db_dir,
    update_type = "increase",
  })

  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  local expected = "  1.00" .. _G.FzfLua.utils.nbsp .. test_file_a
  MiniTest.expect.equality(result, expected)
end

T["#get_fn_transform"]["combined options"]["stat_file and display_score for nonexistent file in db"] = function()
  os.time = function() return now end

  algo.update_file_score(test_file_a, {
    db_dir = db_dir,
    update_type = "increase",
  })

  vim.uv.fs_stat = function(path)
    if path == test_file_a then
      return nil
    end
  end
  vim.schedule = function(fn) end

  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, nil)
end

return T
