local M = {}

function M.check()
  vim.health.start("opencode.nvim")

  local snacks_ok, snacks = pcall(require, "snacks")
  if snacks_ok then
    vim.health.ok("`snacks.nvim` is available.")
    if snacks.input and snacks.config.get("input", {}) ~= false then
      vim.health.ok("`snacks.input` is enabled: `ask()` will be enhanced.")
    else
      vim.health.warn("`snacks.input` is disabled: `ask()` will not be enhanced.")
    end
    if snacks.picker and snacks.config.get("picker", {}).enabled ~= false then
      vim.health.ok("`snacks.picker` is enabled: `select()` will be enhanced.")
    else
      vim.health.warn("`snacks.picker` is disabled: `select()` will not be enhanced.")
    end
  else
    vim.health.warn("`snacks.nvim` is not available to enhance `ask()` and `select()`.")
  end

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
      { "Install `lsof` and ensure it's in your `$PATH`, or set `vim.g.opencode_opts.port`." }
    )
  end

  if require("opencode.config").opts.auto_reload and not vim.o.autoread then
    vim.health.warn(
      "`vim.g.opencode_opts.auto_reload = true` but `vim.o.autoread = false`: files edited by `opencode` won't be automatically reloaded in real-time.",
      {
        "Set `vim.o.autoread = true` or `vim.g.opencode_opts.auto_reload = false`",
      }
    )
  end
end

return M
