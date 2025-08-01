# fzf-lua-frecency.nvim

A frecency-based file picker for [fzf-lua](https://github.com/ibhagwan/fzf-lua) that ranks files based on how frequently and recently they're accessed.

![demo](https://elanmed.dev/nvim-plugins/fzf-lua-frecency.png)

Implements a [variant](https://wiki.mozilla.org/User:Jesse/NewFrecency) of Mozilla's frecency algorithm.

## Performance
`fzf-lua-frecency.nvim` prioritizes performance in a few ways:

- Frecency scores are sorted when a file is selected from the picker, _not_ when populating the picker UI.
- The picker UI opens instantly, with frecency-ranked files and `fd` results streaming in over time.
- Files are processed for the picker UI by headless Neovim instances (`fzf-lua`'s `multiprocess=true` option). 
  - `fzf-lua-frecency` uses string interpolation to embed user configuration options into the headless instances

## Usage

```lua

--- @class FrecencyFnOpts
--- @field debug boolean
--- @field db_dir string
--- @field all_files boolean
--- @field stat_file boolean
--- @field display_score boolean
--- @field [string] any any fzf-lua option

--- @param opts FrecencyFnOpts
require('fzf-lua-frecency').frecency()
require('fzf-lua-frecency').frecency({
   -- any fzf-lua option
   -- ...
   -- defaults:
    debug = false,
    db_dir = vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency")),
    cwd_only = false,     -- Display files from the cwd only 
    all_files = nil,      -- Populate non-scored files in cwd? Defaults to `true` if `cwd_only=true`, else `false`
    stat_file = true,     -- Test for a scored file's existence in the file system
    display_score = false,-- Prefix the fzf entry with its frecency score
})
```

> [!TIP]
> After running frecency for the first time (or after calling `setup`), fzf-lua-frecency
> will register as an fzf-lua extension, extending the `:FzfLua` command:
> ```lua
> :FzfLua frecency cwd_only=true all_files=false
>```

```lua
--- @class ClearDbOpts
--- @field db_dir? string

--- @param opts? ClearDbOpts
require('fzf-lua-frecency').clear_db()
require('fzf-lua-frecency').clear_db({
   -- defaults:
   db_dir = vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency"))
})
```

```lua
--- @class UpdateFileScoreOpts
--- @field update_type "increase" | "remove"
--- @field cwd? string
--- @field db_dir? string
--- @field debug? boolean

--- @param filename string
--- @param opts UpdateFileScoreOpts
require('fzf-lua-frecency.algo').update_file_score("absolute/path/to/file", {
    -- required
    update_type = "increase" 
    -- defaults:
    cwd = vim.fn.getcwd(),
    db_dir = vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency")),
    debug = false,
})
```

## Default `FzfLua` opts

By default, the following options are passed along to `FzfLua.fzf_exec`:

```lua
local opts = {
  -- the default actions for FzfLua files, with an additional
  -- ["ctrl-x"] -- action to remove a file's frecency score
  actions      = actions,    
  previewer    = previewer,  -- FzfLua's default previewer
  file_icons   = true,
  color_icons  = true,
  git_icons    = false,
  fzf_opts     = {
    ["--multi"] = true,
    ["--scheme"] = "path",
    ["--no-sort"] = true,
  },
  winopts      = { preview = { winopts = { cursorline = false, }, }, },
  multiprocess = true,
  fn_transform = function(abs_file, opts)
    local entry = FzfLua.make_entry.file(rel_file, opts)
    -- ...
    -- prepends the frecency score if `display_score` is true
    -- removes files that no longer exist if `stat_file` is true
    -- ...
    return entry
  end,
}
```

Any of the default options can be overriden by passing in your own option:

```lua
require('fzf-lua-frecency').frecency({
  file_icons   = false,
  color_icons  = false,
})

-- Using FzfLua's command
:FzfLua frecency display_score=false cwd_only=true
```

## How it works
- Files are ranked based on a frecency score. This score decays exponentially over time with a half-life of 30 days - i.e. if the current score is `1`, it will decay to `0.5` in 30 days.
- Scores are not stored directly. Instead, an `mpack`-encoded file keeps track of the `date_at_score_one` for each file, which represents the time at which the file's score will decay to `1`. Using the `date_at_score_one`, current time, and decay-rate, we can derive a file's current score.
- When a file is opened, the score for that file is computed, incremented by `1`, and converted back to a `date_at_score_one` format.
- The files are sorted based on current score and output to a `txt` file.
  - Files that are no longer available (i.e. deleted, renamed, moved) are also filtered during this step.
- When the picker is invoked, the `txt` file is read and its content are streamed into the UI. After the frecent files are fully populated, the results from `fd` are streamed in also. This ensures that the frecent files appear first, while also incrementally populating the picker UI.

## Dependencies

- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [`fd`](https://github.com/sharkdp/fd), [`rg`](https://github.com/BurntSushi/ripgrep) or [`find`](https://www.gnu.org/software/findutils/)
- `awk`
- Neovim 0.9+

## Similar plugins
- [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim)
- [smart-open.nvim](https://github.com/danielfalk/smart-open.nvim)
- [snacks.nvim's smart picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#smart)
- [fre integration with fzf-lua](https://github.com/ibhagwan/fzf-lua/discussions/2174)
- [fzf-lua-enchanted-files](https://github.com/otavioschwanck/fzf-lua-enchanted-files)

## TODO
- [ ] User commands
