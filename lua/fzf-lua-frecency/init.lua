local fzf_lua = require "fzf-lua"
local h = require "fzf-lua-frecency.helpers"
local algo = require "fzf-lua-frecency.algo"
local M = {}

M.frecency = function(opts)
  opts = opts or {}
  local cwd = opts.cwd or vim.fn.getcwd()

  local contents = function(fzf_cb)
    local seen = {}

    coroutine.wrap(function()
      local co = coroutine.running()

      local scored_files = algo.get_sorted_scored_files { cwd = cwd, }
      for _, scored_file in ipairs(scored_files) do
        local abs_file = scored_file.filename
        seen[abs_file] = true

        local rel_file = vim.fs.relpath(cwd, abs_file)
        local entry = fzf_lua.make_entry.file(rel_file, opts)
        fzf_cb(entry, function()
          coroutine.resume(co)
        end)
        coroutine.yield()
      end

      local fd_cmd = {
        "fd",
        "--absolute-path",
        "--type", "f",
        "--type", "l",
        "--exclude", ".git",
        "--base-directory", cwd,
      }

      vim.system(fd_cmd, {
          text = true,
          stdout = function(err, data)
            if err then
              h.notify_error("ERROR: vim.system threw when running fd with error: %s", err)
              return
            end

            if type(data) ~= "string" then return end
            local files = vim.split(data, "\n")

            coroutine.wrap(function()
              local co = coroutine.running()

              for _, abs_file in ipairs(files) do
                if seen[abs_file] then goto continue end

                local rel_file = vim.fs.relpath(cwd, abs_file)
                local entry = fzf_lua.make_entry.file(rel_file, opts)
                fzf_cb(entry, function()
                  coroutine.resume(co)
                end)
                coroutine.yield()

                ::continue::
              end
            end)()
          end,
        },
        function()
          fzf_cb(nil)
        end)
    end)()
  end

  local wrapped_enter = function(action)
    return function(selected, action_opts)
      for _, sel in ipairs(selected) do
        -- based on https://github.com/ibhagwan/fzf-lua/blob/bee05a6600ca5fe259d74c418ac9e016a6050cec/lua/fzf-lua/actions.lua#L147
        local filename = fzf_lua.path.entry_to_file(sel, action_opts, action_opts._uri).path
        algo.add_file_score(filename, { cwd = cwd, })
      end

      return action(selected, action_opts)
    end
  end

  local actions = vim.tbl_extend("force", fzf_lua.defaults.actions.files, {
    enter = wrapped_enter(fzf_lua.defaults.actions.files.enter),
  })
  -- relevant options from the default `files` options
  -- https://github.com/ibhagwan/fzf-lua/blob/f972ad787ee8d3646d30000a0652e9b168a90840/lua/fzf-lua/defaults.lua#L336-L360
  local default_opts = {
    actions      = actions,
    previewer    = "builtin",
    multiprocess = true,
    file_icons   = true,
    color_icons  = true,
    git_icons    = false,
    fzf_opts     = { ["--multi"] = true, ["--scheme"] = "path", },
    winopts      = { preview = { winopts = { cursorline = false, }, }, },
  }
  local fzf_exec_opts = vim.tbl_extend("force", default_opts, opts)
  fzf_lua.fzf_exec(contents, fzf_exec_opts)
end

return M
