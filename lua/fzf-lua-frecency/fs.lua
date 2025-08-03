local M = {}

--- @param path string
M.read = function(path)
  -- io.open won't throw
  local file = io.open(path, "r")
  if file == nil then
    return {}
  end

  -- file:read won't throw
  local encoded_data = file:read "*a"
  file:close()

  local h = require "fzf-lua-frecency.helpers"

  -- vim.mpack.decode will throw
  local decode_ok, decoded_data = pcall(vim.mpack.decode, encoded_data)
  if not decode_ok then
    h.notify_error("ERROR: vim.mpack.decode threw: %s", decoded_data)
    return {}
  end
  return decoded_data
end

--- @class WriteOpts
--- @field path string
--- @field data table | string | number
--- @field encode boolean

--- @param opts WriteOpts
--- @return nil
M.write = function(opts)
  local h = require "fzf-lua-frecency.helpers"
  -- vim.fn.mkdir won't throw
  local path_dir = vim.fs.dirname(opts.path)
  local mkdir_res = vim.fn.mkdir(path_dir, "p")
  if mkdir_res == h.vimscript_false then
    h.notify_error "ERROR: vim.fn.mkdir returned vimscript_false"
    return
  end

  -- io.open won't throw
  local file = io.open(opts.path, "w")
  if file == nil then
    h.notify_error("ERROR: io.open failed to open the file created with vim.fn.mkdir at path: %s", opts.path)
    return
  end

  if opts.encode then
    -- vim.mpack.encode will throw
    local encode_ok, encoded_data = pcall(vim.mpack.encode, opts.data)
    if encode_ok then
      file:write(encoded_data)
    else
      h.notify_error("ERROR: vim.mpack.encode threw: %s", encoded_data)
    end
  else
    file:write(opts.data)
  end

  file:close()
end

return M
