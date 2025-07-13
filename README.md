# fzf-lua-frecency.nvim

A frecency-based file picker for [fzf-lua](https://github.com/ibhagwan/fzf-lua), ranking files by how frequently and recently you use them.

Implements a [variant](https://wiki.mozilla.org/User:Jesse/NewFrecency) of Mozilla's frecency algorithm.

## ⏱️ Performance
`fzf-lua-frecency.nvim` prioritizes performance in a few ways:

- Frecency scores are recomputed when a file is opened, not when launching the file picker.
   - **Note**: This design comes with a tradeoff - if a significant amount of time passes between opening a file and triggering the picker, the score data may be slightly stale.
- Frecency-ranked lists are stored separately for each working directory (`cwd`). This avoids filtering irrelevant files at runtime.
- The frecency-ranked list is streamed alongside results from `fd`. This ensures the most relevant files appear first without delaying the rest of the results.

## 📚 Usage

```lua
require('fzf-lua-frecency').frecency()
require('fzf-lua-frecency').frecency({
   -- any fzf-lua option
   -- ...
   -- defaults:
   fzf_lua_frecency = {
       debug = false,
       db_dir = vim.fs.joinpath(vim.fn.stdpath "data", "fzf-lua-frecency"))
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

## ⚙️ How it works
- When a file is selected, it receives a score of `+1`. This score decays exponentially over time, with a half-life of 30 days i.e. if the current score is `1`, it will become `0.5` in 30 days.
- Scores are not stored directly. Instead, an `mpack`-encoded file keeps track of `{ [cwd] = { [filename] = date_at_score_one } }`, where `date_at_score_one` represents the time at which the file's score will decay to `1`. Using the `date_at_score_one`, current time, and decay-rate, we can derive the current score for each file. 
- The scores for all files are computed, and the files are sorted and output to a `txt` file. This `txt` file is scoped to the current working directory.
  - Files with a score of less than `0.95` (i.e. a file that hasn't been accessed in two days) are filtered out - these files will be grouped with the results of `fd` instead. Files that are no longer available (i.e. deleted) are also filtered during this step.
- When the picker is invoked, the `txt` file is read and it's content are streamed into the UI. In parallel, the results from `fd` are also streamed in.

## 🔗 Dependencies

- [fzf-lua](https://github.com/ibhagwan/fzf-lua)
- [`fd`](https://github.com/sharkdp/fd)
- Neovim 0.9+

## 👥 Similar plugins
- [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim)
- [smart-open.nvim](https://github.com/danielfalk/smart-open.nvim)
- [snacks.nvim's smart picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#smart)
- [fre integration with fzf-lua](https://github.com/ibhagwan/fzf-lua/discussions/2174)
- [fzf-lua-enchanted-files](https://github.com/otavioschwanck/fzf-lua-enchanted-files)

## 📝 TODO
- [ ] show the frecency score in the picker?
- [ ] user commands
