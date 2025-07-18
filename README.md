# fzf-lua-frecency.nvim

A frecency-based file picker for [fzf-lua](https://github.com/ibhagwan/fzf-lua) that ranks files based on how frequently and recently they're accessed.

Implements a [variant](https://wiki.mozilla.org/User:Jesse/NewFrecency) of Mozilla's frecency algorithm.

## Performance
`fzf-lua-frecency.nvim` prioritizes performance in a few ways:

- Frecency scores are computed and sorted when a file is selected from the picker, _not_ when populating the picker UI.
- Scores are stored separately for each working directory (`cwd`). This avoids filtering irrelevant files when populating the picker UI.
- The picker UI opens instantly, with frecency-ranked files and `fd` results streaming in over time.

## Usage

```lua
require('fzf-lua-frecency').frecency()
require('fzf-lua-frecency').frecency({
   -- any fzf-lua option
   -- ...
   -- defaults:
   fzf_lua_frecency = {
       debug = false,
       db_dir = vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency")),
       fd_cmd = "fd --absolute-path --type f --type l --exclude .git --base-directory [cwd]" -- where cwd is opts.cwd provided to fzf-lua, or vim.fn.getcwd()
       display_score = false,
   }
})
```

```lua
require('fzf-lua-frecency').clear_db()
require('fzf-lua-frecency').clear_db({
   -- defaults:
   db_dir = vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency"))
})
```

## How it works
- Files are ranked based on a frecency score. This score decays exponentially over time with a half-life of 30 days - i.e. if the current score is `1`, it will decay to `0.5` in 30 days.
- Scores are not stored directly. Instead, an `mpack`-encoded file keeps track of the `date_at_score_one` for each file, which represents the time at which the file's score will decay to `1`. Using the `date_at_score_one`, current time, and decay-rate, we can derive a file's current score.
- When a file is selected, the score for that file is computed, incremented by `1`, and converted back to a `date_at_score_one` format.
- The files are sorted based on current score and output to a `txt` file which is scoped to the current working directory.
  - Files with a score of less than `0.95` (a file that hasn't been accessed in two days) are filtered out - these files will be grouped with the results of `fd` instead. Files that are no longer available (i.e. deleted, renamed, moved) are also filtered during this step.
- When the picker is invoked, the `txt` file is read and its content are streamed into the UI. After the frecent files are fully populated, the results from `fd` are streamed in also. This ensures that the frecent files appear first, while also incrementally populating the picker UI.

## Dependencies

- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [`fd`](https://github.com/sharkdp/fd)
- Neovim 0.9+

## Similar plugins
- [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim)
- [smart-open.nvim](https://github.com/danielfalk/smart-open.nvim)
- [snacks.nvim's smart picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#smart)
- [fre integration with fzf-lua](https://github.com/ibhagwan/fzf-lua/discussions/2174)
- [fzf-lua-enchanted-files](https://github.com/otavioschwanck/fzf-lua-enchanted-files)

## TODO
- [ ] User commands
- [ ] Function to remove a specific file in a cwd, corresponding fzf-lua action
