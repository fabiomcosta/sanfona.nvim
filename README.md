# TODO

- [x] Buggy behavior when there is only one expanded window
- [x] When opening nvim we should put the currently focused win on the right,
and expand other wins that fit to the left (or maybe put it in the center)
- [x] Make it behave nicely when opening new splits
- [x] Make it behave nicely when closing splits
- [x] Make it behave nicely with horizontal splits
- [x] Ignore telescope buffers (note: checking for zindex should be enough)
- [x] Ignore quickfix buffers
- [ ] Because `wincmd =` is used, windows without `winfix*` are getting their
size changed unexpectedly in some scenarios. Should we change our approach
so that we don't rely on setting `winfix*` and so that we don't rely on
`wincmd =`?

# Credits

- [vim-accordion](https://github.com/mattboehm/vim-accordion) - I've been using this plugin for a long time now and it has been working fine for me with some small adaptations, but a recent interaction when opening a new telescope window made me want to create Sanfona, which is a modern version of this plugin written in lua.
- [lua-ordered-set](https://github.com/basiliscos/lua-ordered-set) - Copied and made some changes to better support storing an ordered set of focused window ids
