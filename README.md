# fzf-lua-frecency.nvim

A frecency-based file picker for [fzf-lua](https://github.com/ibhagwan/fzf-lua), ranking files by how frequently and recently you use them.

Implements a [variant](https://wiki.mozilla.org/User:Jesse/NewFrecency) of Mozilla's frecency algorithm.

## ⏱️Performance
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

## 🔗 Dependencies

* [fzf-lua](https://github.com/ibhagwan/fzf-lua)
* [`fd`](https://github.com/sharkdp/fd)
* Neovim 0.9+

## 👥 Similar plugins
- [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim)
- [smart-open.nvim](https://github.com/danielfalk/smart-open.nvim)
- [snacks.nvim's smart picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#smart)
- [fre integration with fzf-lua](https://github.com/ibhagwan/fzf-lua/discussions/2174)
- [fzf-lua-enchanted-files](https://github.com/otavioschwanck/fzf-lua-enchanted-files)

## ✅ TODO
- [ ] nicer looking readme, emojis, etc
- [ ] show the frecency score in the picker?
- [ ] user commands
