local M = {}

local external_instructions =
  "Or launch `opencode` with your own method and optionally override `vim.g.opencode_opts.provider` for convenience, then use `opencode.nvim` normally."

function M.check()
  vim.health.start("opencode.nvim")

  if vim.fn.executable("opencode") == 1 then
    local found_version = vim.fn.system("opencode --version")
    found_version = vim.trim(vim.split(found_version, "\n")[1])
    vim.health.ok("`opencode` executable found in `$PATH` with version `" .. found_version .. "`.")

    local latest_tested_version = "0.15.8"
    if vim.version.parse(latest_tested_version)[2] ~= vim.version.parse(found_version)[2] then
      vim.health.warn(
        "`opencode` found version `"
          .. found_version
          .. "` has a `minor` mismatch with latest tested version `"
          .. latest_tested_version
          .. "`."
      )
    end
  else
    vim.health.error("`opencode` executable not found in `$PATH`.", {
      "Install `opencode` and ensure it's in your `$PATH`.",
    })
  end

  if vim.fn.executable("lsof") == 1 then
    vim.health.ok(
      "`lsof` executable found in `$PATH`: it will be used to auto-find `opencode` if `vim.g.opencode_opts.port` is not set."
    )
  else
    vim.health.warn(
      "`lsof` executable not found in `$PATH`.",
      { "Install `lsof` and ensure it's in your `$PATH`", "Or set `vim.g.opencode_opts.port`." }
    )
  end

  if require("opencode.config").opts.auto_reload and not vim.o.autoread then
    vim.health.warn(
      "`vim.g.opencode_opts.auto_reload = true` but `vim.o.autoread = false`: files edited by `opencode` won't be automatically reloaded in buffers.",
      {
        "Set `vim.o.autoread = true`",
        "Or set `vim.g.opencode_opts.auto_reload = false`",
      }
    )
  end

  if vim.g.opencode_opts then
    vim.health.ok("`vim.g.opencode_opts` is " .. vim.inspect(vim.g.opencode_opts))
  else
    vim.health.warn("`vim.g.opencode_opts` is `nil`")
  end

  vim.health.start("opencode.nvim [snacks]")

  local snacks_ok, snacks = pcall(require, "snacks")
  if snacks_ok then
    if snacks.input and snacks.config.get("input", {}).enabled then
      vim.health.ok("`snacks.input` is enabled: `ask()` will be enhanced.")
      local blink_ok = pcall(require, "blink.cmp")
      if blink_ok then
        vim.health.ok(
          "`blink.cmp` is available: `vim.g.opencode_opts.auto_register_cmp_sources` will be registered in `ask()`."
        )
      end
    else
      vim.health.warn("`snacks.input` is disabled: `ask()` will not be enhanced.")
    end
    if snacks.picker and snacks.config.get("picker", {}).enabled then
      vim.health.ok("`snacks.picker` is enabled: `select()` will be enhanced.")
    else
      vim.health.warn("`snacks.picker` is disabled: `select()` will not be enhanced.")
    end
    if snacks.picker and snacks.config.get("terminal", {}).enabled then
      vim.health.ok("`snacks.terminal` is enabled: will default to `snacks` provider.")
    else
      vim.health.warn("`snacks.terminal` is disabled: the `snacks` provider will not be available.", {
        "Enable `snacks.terminal`",
        external_instructions,
      })
    end
  else
    vim.health.warn("`snacks.nvim` is not available: `ask()` and `select()` will not be enhanced.")
    vim.health.warn("`snacks.nvim` is not available: the `snacks` provider will not be available.", {
      "Install `snacks.nvim`",
      external_instructions,
    })
  end
end

return M
