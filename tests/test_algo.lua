local algo = require "fzf-lua-frecency.algo"
local fs = require "fzf-lua-frecency.fs"

local db_dir = vim.fs.joinpath(vim.fn.getcwd(), "test-algo", "db-dir")
local cwd = vim.fs.joinpath(vim.fn.getcwd(), "test-algo", "files")
local sorted_files_path = vim.fs.joinpath(db_dir, "cwds", cwd, "sorted-files.txt")
local dated_files_path = vim.fs.joinpath(db_dir, "dated-files.mpack")
local test_file_a = vim.fs.joinpath(cwd, "test-file-a.txt")
local test_file_b = vim.fs.joinpath(cwd, "test-file-b.txt")

local now = os.time { year = 2025, month = 1, day = 1, hour = 0, min = 0, sec = 0, }
local now_after_30_min = os.time { year = 2025, month = 1, day = 1, hour = 0, min = 30, sec = 0, }
local now_after_3_days = os.time { year = 2025, month = 1, day = 4, hour = 0, min = 0, sec = 0, }
local score_when_adding = 1
local date_at_score_one_now = algo.compute_date_at_score_one { now = now, score = score_when_adding, }
local score_decayed_after_30_min = 0.99951876362267

local function create_file(path)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local file = io.open(path, "w")
  if not file then
    error "io.open failed!"
  end
  file:write "content"
  file:close()
end

local function read_sorted()
  local file = io.open(sorted_files_path, "r")
  if not file then return "" end
  local data = file:read "*a"
  file:close()
  return data
end

local function cleanup()
  os.remove(dated_files_path)
  os.remove(sorted_files_path)
  os.remove(test_file_a)
  os.remove(test_file_b)
  create_file(test_file_a)
  create_file(test_file_b)
end

local T = MiniTest.new_set()
T["#add_file_score"] = MiniTest.new_set {
  hooks = {
    pre_case = cleanup,
    post_case = cleanup,
  },
}

T["#add_file_score"]["adds score entry for new file"] = function()
  algo._now = function() return now end

  algo.add_file_score(test_file_a, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  local dated_files = fs.read(dated_files_path)
  local date_at_score_one = dated_files[cwd][test_file_a]
  MiniTest.expect.equality(date_at_score_one, date_at_score_one_now)

  local sorted_files = read_sorted()
  MiniTest.expect.equality(sorted_files, test_file_a .. "\n")
end

T["#add_file_score"]["increments score on repeated calls"] = function()
  algo._now = function() return now end

  algo.add_file_score(test_file_a, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    date_at_score_one_now
  )

  algo._now = function() return now_after_30_min end

  algo.add_file_score(test_file_a, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    algo.compute_date_at_score_one { now = now_after_30_min, score = score_decayed_after_30_min + 1, }
  )
end

T["#add_file_score"]["recalculates all scores when adding a new file"] = function()
  algo._now = function() return now end

  algo.add_file_score(test_file_a, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    date_at_score_one_now
  )

  algo._now = function() return now_after_30_min end

  algo.add_file_score(test_file_b, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    algo.compute_date_at_score_one { now = now_after_30_min, score = score_decayed_after_30_min, }
  )
  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_b],
    algo.compute_date_at_score_one { now = now_after_30_min, score = score_when_adding, }
  )
  local sorted_files = read_sorted()
  MiniTest.expect.equality(sorted_files, test_file_b .. "\n" .. test_file_a .. "\n")
end

T["#add_file_score"]["filters files lower than 0.95"] = function()
  algo._now = function() return now end

  algo.add_file_score(test_file_a, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    date_at_score_one_now
  )

  algo._now = function() return now_after_3_days end

  algo.add_file_score(test_file_b, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    nil
  )
  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_b],
    algo.compute_date_at_score_one { now = now_after_3_days, score = score_when_adding, }
  )
  local sorted_files = read_sorted()
  MiniTest.expect.equality(sorted_files, test_file_b .. "\n")
end

T["#add_file_score"]["filters deleted files"] = function()
  algo._now = function() return now end

  algo.add_file_score(test_file_a, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    date_at_score_one_now
  )

  algo._now = function() return now_after_30_min end
  os.remove(test_file_a)

  algo.add_file_score(test_file_b, {
    debug = false,
    cwd = cwd,
    dated_files_path = dated_files_path,
    sorted_files_path = sorted_files_path,
  })

  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_a],
    nil
  )
  MiniTest.expect.equality(
    fs.read(dated_files_path)[cwd][test_file_b],
    algo.compute_date_at_score_one { now = now_after_30_min, score = score_when_adding, }
  )
  local sorted_files = read_sorted()
  MiniTest.expect.equality(sorted_files, test_file_b .. "\n")
end

return T
