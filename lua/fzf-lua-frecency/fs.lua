local h = require "fzf-lua-frecency.helpers"

local M = {}

--- @param path string
--- @return table
M.read = function(path)
  -- io.open won't throw
  local file = io.open(path, "r")
  if file == nil then
    return {}
  end

  -- file:read won't throw
  local encoded_data = file:read "*a"
  file:close()

  -- vim.mpack.decode will throw
  local decode_ok, decoded_data = pcall(vim.mpack.decode, encoded_data)
  if not decode_ok then
    h.notify_error("ERROR: vim.mpack.decode threw: %s", decoded_data)
    return {}
  end
  return decoded_data
end

--- @param path string
--- @param data table
--- @return nil
M.write = function(path, data)
  -- io.open won't throw
  local file = io.open(path, "w")
  if file == nil then
    local path_dir = vim.fs.dirname(path)
    local mkdir_res = vim.fn.mkdir(path_dir, "p")
    if mkdir_res == h.vimscript_false then
      h.notify_error "ERROR: vim.fn.mkdir returned vimscript_false"
      return
    end

    file = io.open(path, "w")
    if file == nil then
      h.notify_error("ERROR: io.open failed to open the file created with vim.fn.mkdir at path: %s", path)
      return
    end
  end

  local encode_ok, encoded_data = pcall(vim.mpack.encode, data)
  if encode_ok then
    file:write(encoded_data)
  else
    h.notify_error("ERROR: vim.mpack.encode threw: %s", encoded_data)
  end
  file:close()
end

return M
