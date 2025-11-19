local M = {}

function M.check()
  vim.health.start("opencode.nvim")

  vim.health.ok("`nvim` version: `" .. tostring(vim.version()) .. "`.")

  local plugin_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
  local git_hash = vim.fn.system("cd " .. vim.fn.shellescape(plugin_dir) .. " && git rev-parse HEAD")
  if vim.v.shell_error == 0 then
    git_hash = vim.trim(git_hash)
    vim.health.ok("`opencode.nvim` git commit hash: `" .. git_hash .. "`.")
  else
    vim.health.warn("Could not determine `opencode.nvim` git commit hash.")
  end

  vim.health.ok("`vim.g.opencode_opts` is " .. (vim.g.opencode_opts and vim.inspect(vim.g.opencode_opts) or "`nil`"))

  if require("opencode.config").opts.auto_reload and not vim.o.autoread then
    vim.health.warn(
      "`opts.auto_reload = true` but `vim.o.autoread = false`: files edited by `opencode` won't be automatically reloaded in buffers.",
      {
        "Set `vim.o.autoread = true`",
        "Or set `vim.g.opencode_opts.auto_reload = false`",
      }
    )
  end

  vim.health.start("opencode.nvim [binaries]")

  if vim.fn.executable("opencode") == 1 then
    local found_version = vim.fn.system("opencode --version")
    found_version = vim.trim(vim.split(found_version, "\n")[1])
    vim.health.ok("`opencode` available with version `" .. found_version .. "`.")

    local found_version_parsed = vim.version.parse(found_version)
    local latest_tested_version = "1.0.60"
    local latest_tested_version_parsed = vim.version.parse(latest_tested_version)
    if found_version_parsed and latest_tested_version_parsed then
      if latest_tested_version_parsed[1] ~= found_version_parsed[1] then
        vim.health.warn(
          "`opencode` version has a `major` version mismatch with latest tested version `"
            .. latest_tested_version
            .. "`: may cause compatibility issues."
        )
      elseif latest_tested_version_parsed[2] ~= found_version_parsed[2] then
        vim.health.warn(
          "`opencode` version has an older `minor` version than latest tested version `"
            .. latest_tested_version
            .. "`: may cause compatibility issues.",
          {
            "Update `opencode`.",
          }
        )
      elseif latest_tested_version_parsed[3] ~= found_version_parsed[3] then
        vim.health.warn(
          "`opencode` version has an older `patch` version than latest tested version `"
            .. latest_tested_version
            .. "`: may cause compatibility issues.",
          {
            "Update `opencode`.",
          }
        )
      end
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

  if vim.fn.executable("lsof") == 1 then
    vim.health.ok("`lsof` available: it will be used to auto-find `opencode` if `vim.g.opencode_opts.port` is not set.")
  else
    vim.health.warn(
      "`lsof` executable not found in `$PATH`.",
      { "Install `lsof` and ensure it's in your `$PATH`", "Or set `vim.g.opencode_opts.port`." }
    )
  end

  vim.health.start("opencode.nvim [snacks]")

  local snacks_ok, snacks = pcall(require, "snacks")
  if snacks_ok then
    if snacks.input and snacks.config.get("input", {}).enabled then
      vim.health.ok("`snacks.input` is enabled: `ask()` will be enhanced.")
      local blink_ok = pcall(require, "blink.cmp")
      if blink_ok then
        vim.health.ok(
          "`blink.cmp` is available: `opts.ask.blink_cmp_sources` will be registered in `ask()`."
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
      vim.health.ok("`snacks.terminal` is enabled: the `snacks` provider will be available.")
    else
      vim.health.warn("`snacks.terminal` is disabled: the `snacks` provider will not be available.", {
        "Enable `snacks.terminal`",
      })
    end
  else
    vim.health.warn("`snacks.nvim` is not available: `ask()` and `select()` will not be enhanced.")
    vim.health.warn("`snacks.nvim` is not available: the `snacks` provider will not be available.", {
      "Install `snacks.nvim` and enable `snacks.terminal`",
    })
  end

  vim.health.start("opencode.nvim [tmux]")

  if vim.fn.has("unix") then
    vim.health.ok("Running inside a Unix system.")
    if vim.fn.executable("tmux") == 1 then
      vim.health.ok("`tmux` available.")
      if vim.env.TMUX then
        vim.health.ok("Running inside a `tmux` session: the `tmux` provider will be available.")
      else
        vim.health.warn("Not running inside a `tmux` session: the `tmux` provider will not be available.", {
          "Launch Neovim inside a `tmux` session.",
        })
      end
    else
      vim.health.warn("`tmux` executable not found in `$PATH`: the `tmux` provider will not be available.", {
        "Install `tmux` and ensure it's in your `$PATH`.",
      })
    end
  else
    vim.health.warn("Not running inside a Unix system: the `tmux` provider will not be available.")
  end
end

return M
