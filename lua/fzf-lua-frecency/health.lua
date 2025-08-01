local h = require "fzf-lua-frecency.helpers"
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

  if vim.fn.executable "fdfind" == h.vimscript_true then
    vim.health.ok "'fd' is installed"
  elseif vim.fn.executable "fd" == h.vimscript_true then
    vim.health.ok "'fd' is installed"
  elseif vim.fn.executable "rg" == h.vimscript_true then
    vim.health.ok "'rg' is installed"
  elseif vim.fn.executable "find" == h.vimscript_true then
    vim.health.ok "'find' is installed"
  else
    vim.health.error("'all_files' requires 'fd', 'rg', or 'find' to be installed", {
      "Install fd: https://github.com/sharkdp/fd",
      "Install rg: https://github.com/BurntSushi/ripgrep",
      "Install find: https://www.gnu.org/software/findutils/",
    })
  end
end

return M
