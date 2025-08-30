local config = {}

M = setmetatable(config, {
  -- call the config object to update/extend the configs.
  __call = function(_self, cfg)
    config = vim.tbl_deep_extend(
      'force',
      config,
      { min_width = tonumber(vim.o.colorcolumn) or 80 },
      cfg
    )
  end,
  __index = function(_self, key)
    return config[key]
  end,
})

return M
