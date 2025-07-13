local M = {}

function M.check()
  local fzf_lua_ok = pcall(require, "fzf-lua")
  if fzf_lua_ok then
    vim.health.ok "'fzf-lua' is installed"
  else
    vim.health.error("'fzf-lua' is not installed", {
      "Install fzf-lua: https://github.com/ibhagwan/fzf-lua",
    })
  end

  if vim.fn.executable "fd" == 1 then
    vim.health.ok "'fd' is installed"
  else
    vim.health.error("'fd' is not installed", {
      "Install fd: https://github.com/sharkdp/fd",
    })
  end
end

return M
