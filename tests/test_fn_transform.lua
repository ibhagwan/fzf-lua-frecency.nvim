--- @diagnostic disable: duplicate-set-field, return-type-mismatch, missing-return, undefined-field, need-check-nil
local transform = require "fzf-lua-frecency.fn_transform"
local algo = require "fzf-lua-frecency.algo"

local root_dir = vim.fs.joinpath(vim.fn.getcwd(), "test-fn-transform")
local db_dir = vim.fs.joinpath(root_dir, "db-dir")

local cwd = vim.fs.joinpath(root_dir, "files")
local test_file_a = vim.fs.joinpath(cwd, "test-file-a.txt")
local test_file_b = vim.fs.joinpath(cwd, "test-file-b.txt")
local test_dir_a = vim.fs.joinpath(cwd, "test-dir-a")

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

local function cleanup()
  os.time = os_time

  _G.FzfLua.make_entry.file = function(filename, _) return filename end
  _G._fzf_lua_frecency_dated_files = nil
  _G._fzf_lua_frecency_EOF = nil
  vim.fn.delete(root_dir, "rf")
  create_file(test_file_a)
  create_file(test_file_b)
  vim.fn.mkdir(test_dir_a, "p")
end

local T = MiniTest.new_set()

T["#get_fn_transform"] = MiniTest.new_set {
  hooks = {
    pre_case = cleanup,
    post_case = cleanup,
    post_once = function()
      vim.fn.delete(root_dir, "rf")
    end,
  },
}

T["#get_fn_transform"]["basic functionality"] = MiniTest.new_set()
T["#get_fn_transform"]["basic functionality"]["returns entry when no options enabled"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = false,
    all_files = false,
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
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, nil)

  _G.FzfLua.make_entry.file = original_make_entry
end

T["#get_fn_transform"]["deduplicating"] = MiniTest.new_set()
T["#get_fn_transform"]["deduplicating"]["sets _G._fzf_lua_frecency_EOF when the file content is empty"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = true,
    db_dir = db_dir,
  }
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, nil)
  fn_transform(test_file_a, {})
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, nil)
  fn_transform("", {})
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, true)
  fn_transform(test_file_a, {})
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, true)
end
T["#get_fn_transform"]["deduplicating"]["when _G._fzf_lua_frecency_EOF is false, it does not return early"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = true,
    db_dir = db_dir,
  }
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, nil)
  local result = fn_transform(test_file_a, {})
  MiniTest.expect.no_equality(result, nil)
end
T["#get_fn_transform"]["deduplicating"]["when _G._fzf_lua_frecency_EOF is true"] = MiniTest.new_set()
T["#get_fn_transform"]["deduplicating"]["when _G._fzf_lua_frecency_EOF is true"]["should return an entry when the file is not in the db"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = true,
    db_dir = db_dir,
  }
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, nil)
  fn_transform("", {})
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, true)
  local result = fn_transform(test_file_a, {})
  MiniTest.expect.no_equality(result, nil)
end
T["#get_fn_transform"]["deduplicating"]["when _G._fzf_lua_frecency_EOF is true"]["should return early when the file is in the db"] = function()
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
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, nil)
  fn_transform("", {})
  MiniTest.expect.equality(_G._fzf_lua_frecency_EOF, true)
  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, nil)
end

T["#get_fn_transform"]["display_score"] = MiniTest.new_set()
T["#get_fn_transform"]["display_score"]["displays padded spaces for a file not in the db"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = false,
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  local expected = (" "):rep(6) .. _G.FzfLua.utils.nbsp .. test_file_a
  MiniTest.expect.equality(result, expected)
end

T["#get_fn_transform"]["display_score"]["displays score for a file in the db"] = function()
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

T["#get_fn_transform"]["stat_file=true"] = MiniTest.new_set()
T["#get_fn_transform"]["stat_file=true"]["returns entry for an existing file in the db"] = function()
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

-- i.e. from `fd`
T["#get_fn_transform"]["stat_file=true"]["returns entry for a file not in the db"] = function()
  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, test_file_a)
end

T["#get_fn_transform"]["stat_file=true"]["returns nil for nonexistent files in the db"] = function()
  os.time = function() return now end

  algo.update_file_score(test_file_a, {
    db_dir = db_dir,
    update_type = "increase",
  })

  vim.fn.delete(test_file_a)

  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, nil)
end

T["#get_fn_transform"]["stat_file=true"]["returns nil for directories in the db"] = function()
  os.time = function() return now end

  algo.update_file_score(test_dir_a, {
    db_dir = db_dir,
    update_type = "increase",
    stat_file = false,
  })

  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = false,
    db_dir = db_dir,
  }

  local result = fn_transform(test_dir_a, {})
  MiniTest.expect.equality(result, nil)
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

  vim.fn.delete(test_file_a)

  local fn_transform = transform.get_fn_transform {
    stat_file = true,
    display_score = true,
    db_dir = db_dir,
  }

  local result = fn_transform(test_file_a, {})
  MiniTest.expect.equality(result, nil)
end

return T
