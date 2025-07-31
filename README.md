# sanfona.nvim

TODO: logo
TODO: a video is worth a thousand words

Most languages and projects these days uses formating tools that will
help force a maximum number of characters per line on our files.

Sanfona (accordion in Portuguese) is a plugin that auto resizes your neovim
windows so that they will have at least the min_width that is provided as
configuration for the setup function.

It accomplishes that by expanding the currently focused window, as well as the
previously focused ones, while hidding other windows that can't fit in the
current viewport considering the set min_width.

I lied, the other windows are not actually hidden, they are just collapsed on
the sides (and you can see them), and are set to have width 1.

This way you can have as many windows open as your monitor can fit, while also
being able to navigate to these collapsed windows if needed.

# Install

## lazy.nvim

```lua
return {
  {
    'fabiomcosta/sanfona.nvim',
    opts = {
        -- vim.o.colorcolumn is used as the default value
        min_width = 80,
    },
  },
}
```

# TODO

- [x] Buggy behavior when there is only one expanded window
- [x] When opening nvim we should put the currently focused win on the right,
      and expand other wins that fit to the left (or maybe put it in the center)
- [x] Make it behave nicely when opening new splits
- [x] Make it behave nicely when closing splits
- [x] Make it behave nicely with horizontal splits
- [x] Ignore telescope buffers (note: checking for zindex should be enough)
- [x] Ignore quickfix buffers

# Credits

- [vim-accordion](https://github.com/mattboehm/vim-accordion) - I've been using this plugin for a long time now and it has been working fine for me with some small adaptations, but a recent interaction when opening a new telescope window made me want to create Sanfona, which is a modern version of this plugin written in lua.
- [lua-ordered-set](https://github.com/basiliscos/lua-ordered-set) - Copied and made some changes to better support storing an ordered set of focused window ids
