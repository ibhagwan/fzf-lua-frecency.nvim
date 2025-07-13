# fzf-lua-frecency.nvim

A frecency-based file picker for [fzf-lua](https://github.com/ibhagwan/fzf-lua), ranking files by how frequently and recently you use them.

Implements a [variant](https://wiki.mozilla.org/User:Jesse/NewFrecency) of Mozilla's frecency algorithm

## Status
* This plugin is still a WIP, breaking changes are likely!

## Usage

```lua
require('fzf-lua-frecency').frecency({
   -- any fzf-lua option
})
```

## Dependencies

* [fzf-lua](https://github.com/ibhagwan/fzf-lua)
* [`fd`](https://github.com/sharkdp/fd)
* Neovim 0.9+

## Similar plugins
- [telescope-frecency.nvim](https://github.com/nvim-telescope/telescope-frecency.nvim)
- [smart-open.nvim](https://github.com/danielfalk/smart-open.nvim)
- [snacks.nvim's smart picker](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md#smart)
- [fre integration with fzf-lua](https://github.com/ibhagwan/fzf-lua/discussions/2174)
- [fzf-lua-enchanted-files](https://github.com/otavioschwanck/fzf-lua-enchanted-files)

## TODO:
- [ ] testing
- [ ] differentiate between fzf-lua options and fzf-lua-frecency options
- [ ] healthcheck
- [ ] more info on performance in the README
- [ ] investigate off-loading to a script
- [ ] investigate ranking files < 1 after `fd`
- [ ] purge deleted files
- [ ] purge files below a threshold?
