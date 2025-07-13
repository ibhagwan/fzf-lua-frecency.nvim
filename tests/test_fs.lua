local fs = require "fzf-lua-frecency.fs"
local h = require "fzf-lua-frecency.helpers"

local cwd = vim.fs.joinpath(vim.fn.getcwd(), "test-fs", "files")
local test_file = vim.fs.joinpath(cwd, "test.mpack")

local T = MiniTest.new_set()

local function write_file(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local file = io.open(path, "w")
  assert(file, "io.open failed!")
  file:write(contents)
  file:close()
end

local h_notify_error = h.notify_error
local vim_fn_mkdir = vim.fn.mkdir
local vim_mpack_encode = vim.mpack.encode

local function cleanup()
  h.notify_error = h_notify_error
  vim.fn.mkdir = vim_fn_mkdir
  vim.mpack.encode = vim_mpack_encode
  os.remove(test_file)
end

T["#read"] = MiniTest.new_set {
  hooks = {
    pre_case = cleanup,
    post_case = cleanup,
  },
}

T["#read"]["returns empty table when file is missing"] = function()
  MiniTest.expect.equality(fs.read(test_file), {})
end

T["#read"]["returns decoded table when valid mpack"] = function()
  local data = { foo = "bar", num = 42, }
  write_file(test_file, vim.mpack.encode(data))
  MiniTest.expect.equality(fs.read(test_file), data)
end

T["#read"]["returns empty table and notifies on decode failure"] = function()
  local called_err = false
  h.notify_error = function(msg)
    called_err = msg:find "ERROR: vim.mpack.decode threw: " ~= nil
  end

  write_file(test_file, "not valid mpack")

  local result = fs.read(test_file)
  MiniTest.expect.equality(result, {})
  MiniTest.expect.equality(called_err, true)
end

T["#write"] = MiniTest.new_set {
  hooks = {
    pre_case = cleanup,
    post_case = cleanup,
  },
}

T["#write"]["writes encoded mpack data when encode = true"] = function()
  local data = { hello = "world", }
  fs.write { path = test_file, data = data, encode = true, }
  local file = io.open(test_file, "r")
  assert(file, "io.open failed!")
  local contents = file:read "*a"
  file:close()
  local decoded = vim.mpack.decode(contents)
  MiniTest.expect.equality(decoded, data)
end

T["#write"]["writes raw string when encode = false"] = function()
  local data = "raw text"
  fs.write { path = test_file, data = data, encode = false, }
  local file = io.open(test_file, "r")
  assert(file, "io.open failed!")
  local contents = file:read "*a"
  file:close()
  MiniTest.expect.equality(contents, data)
end

T["#write"]["notifies on mkdir failure"] = function()
  local called_err = false

  h.notify_error = function(msg)
    called_err = msg:find "ERROR: vim.fn.mkdir returned vimscript_false" ~= nil
  end
  vim.fn.mkdir = function()
    return h.vimscript_false
  end

  fs.write { path = test_file, data = "content", encode = false, }
  MiniTest.expect.equality(called_err, true)
end

T["#write"]["notifies on mpack.encode failure"] = function()
  local called_err = false

  h.notify_error = function(msg)
    called_err = msg:find "ERROR: vim.mpack.encode threw: " ~= nil
  end
  vim.mpack.encode = function()
    error "fail!"
  end

  fs.write { path = test_file, data = {}, encode = true, }
  MiniTest.expect.equality(called_err, true)
end

return T
