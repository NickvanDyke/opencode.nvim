local M = {}

function M.check()
  vim.health.start("opencode.nvim")

  local uname = vim.uv.os_uname()
  vim.health.info(string.format("OS: %s %s (%s)", uname.sysname, uname.release, uname.machine))

  vim.health.info("`nvim` version: `" .. tostring(vim.version()) .. "`")

  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
  local git_hash =
    vim.trim(vim.fn.system("cd " .. vim.fn.shellescape(plugin_dir) .. " && git rev-parse HEAD")):gsub("\n", "\\n")
  if vim.v.shell_error == 0 then
    vim.health.info("opencode.nvim git commit: `" .. git_hash .. "`")
  else
    vim.health.warn("opencode.nvim git commit: `" .. git_hash .. "`")
  end

  vim.health.info("`vim.g.opencode_opts`: " .. vim.inspect(vim.g.opencode_opts))
  local opts = require("opencode.config").opts

  if opts.events.reload.enabled and not vim.o.autoread then
    vim.health.warn(
      "`vim.g.opencode_opts.events.reload.enabled = true` but `vim.o.autoread = false`: files edited by `opencode` can't be automatically reloaded in buffers.",
      "Set `vim.o.autoread = true`."
    )
  end

  vim.health.start("opencode.nvim [binaries]")

  if vim.fn.executable("opencode") == 1 then
    local found_version = vim.fn.system("opencode --version")
    found_version = vim.trim(vim.split(found_version, "\n")[1])
    vim.health.ok("`opencode` available with version `" .. found_version .. "`.")

    local found_version_parsed = vim.version.parse(found_version)
    local minimum_version = "1.17"
    local minimum_version_parsed = vim.version.parse(minimum_version)
    if
      found_version_parsed
      and minimum_version_parsed
      and vim.version.cmp(found_version_parsed, minimum_version_parsed) < 0
    then
      vim.health.warn(
        "`opencode` version is older than the minimum supported version `"
          .. minimum_version
          .. "`: may cause compatibility issues.",
        {
          "Update `opencode`.",
        }
      )
    end
  else
    vim.health.error("`opencode` executable not found in `$PATH`.", {
      "Install `opencode` and ensure it's in your `$PATH`.",
    })
  end

  if vim.fn.executable("curl") == 1 then
    vim.health.ok("`curl` available.")
  else
    vim.health.error("`curl` executable not found in `$PATH`.", {
      "Install `curl` and ensure it's in your `$PATH`.",
    })
  end

  -- Binaries for auto-finding `opencode` process (Unix only)
  if vim.fn.has("win32") == 0 and not (opts and opts.server and opts.server.url) then
    if vim.fn.executable("pgrep") == 1 then
      vim.health.ok("`pgrep` available.")
    else
      vim.health.error(
        "`pgrep` executable not found in `$PATH`.",
        { "Install `pgrep` and ensure it's in your `$PATH`", "Or set `vim.g.opencode_opts.server.url`." }
      )
    end
    if vim.fn.executable("lsof") == 1 then
      vim.health.ok("`lsof` available.")
    else
      vim.health.error(
        "`lsof` executable not found in `$PATH`.",
        { "Install `lsof` and ensure it's in your `$PATH`", "Or set `vim.g.opencode_opts.server.url`." }
      )
    end
  end

  vim.health.start("opencode.nvim [snacks]")

  local snacks_ok, snacks = pcall(require, "snacks")
  if snacks_ok then
    if snacks.config.get("input", {}).enabled then
      vim.health.ok("snacks.input enabled: `ask()` enhanced.")
    else
      vim.health.warn("snacks.input disabled: `ask()` not enhanced.")
    end
    if snacks.config.get("picker", {}).enabled then
      vim.health.ok("snacks.picker enabled: `select()` enhanced.")
    else
      vim.health.warn("snacks.picker disabled: `select()` enhanced.")
    end
  else
    vim.health.warn("snacks.nvim not available: `ask()` and `select()` not enhanced.")
  end
end

return M
