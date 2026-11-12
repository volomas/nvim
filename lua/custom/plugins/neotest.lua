-- Compile Java tests with Maven instead of jdtls' `java/buildWorkspace`.
--
-- jdtls (ECJ 1.63, the version bundled with mason's jdtls >= 1.63) crashes on a
-- Lombok `@SneakyThrows` constructor with
--   ClassCastException: BlockScope cannot be cast to MethodScope
-- (see redhat-developer/vscode-java#4558 / eclipse.jdt.ls#3199). The Java
-- Builder then retries forever, wipes target/classes and rewrites
-- target/generated-sources/annotations while Maven compiles them, so nothing
-- can be compiled or run. `java.autobuild.enabled` is therefore disabled in
-- ftplugin/java.lua and Maven owns the build output.
local function maven_compiler()
  return {
    -- opts = { base_dir = neotest-java.Path, compile_mode = 'incremental'|'full' }
    compile = function(opts)
      local cwd = opts.base_dir:to_string()
      local wrapper = cwd .. '/mvnw'
      local mvn = vim.fn.executable(wrapper) == 1 and wrapper or 'mvn'

      local cmd = {
        mvn,
        '-o', -- dependencies are already in the local repo; fail fast otherwise
        '-q',
        '-DskipTests',
        '-Dspotless.check.skip=true',
        '-Dcheckstyle.skip=true',
        'test-compile',
      }

      local nio = require 'nio'
      local future = nio.control.future()
      vim.system(cmd, { cwd = cwd, text = true }, function(result)
        future.set(result)
      end)

      local result = future.wait()
      if result.code ~= 0 then
        local output = table.concat({ result.stdout or '', result.stderr or '' }, '\n')
        vim.notify('Maven test-compile failed:\n' .. output:sub(-3000), vim.log.levels.ERROR)
        error 'mvn test-compile failed'
      end
    end,
  }
end

--- The Java adapter, with two small patches:
---
--- 1. `results`: neotest's result objects carry no timing information and
---    neotest-java deletes the JUnit XML reports right after parsing them, so
---    read the report files first and hand the durations to the results window
---    (lua/custom/java_test_results.lua).
--- 2. `build_spec`: the adapter hardcodes `--details=testfeed`, which prints a
---    progress feed to the launcher's stdout during the run. `--details=none`
---    keeps that noise out of the output panel. (JUnit's XML report still
---    writes a small `unique-id:` block per test; the results window strips it.)
local function java_adapter()
  local adapter = require 'neotest-java'({
    incremental_build = true,
  }, {
    lsp_compiler = maven_compiler(),
  })

  local results = adapter.results
  adapter.results = function(spec, result, tree)
    pcall(function()
      require('custom.java_test_results').record_reports(spec.context and spec.context.reports_dir)
    end)
    return results(spec, result, tree)
  end

  local build_spec = adapter.build_spec
  adapter.build_spec = function(args)
    local spec = build_spec(args)
    local specs = type(spec) == 'table' and (spec[1] and spec or { spec }) or {}
    for _, one in ipairs(specs) do
      local command = one.command
      if type(command) == 'table' then
        for i, arg in ipairs(command) do
          if arg == '--details=testfeed' then
            command[i] = '--details=none'
          end
        end
      end
    end
    return spec
  end

  return adapter
end

return {
  {
    'nvim-neotest/neotest',
    dependencies = {
      'nvim-neotest/nvim-nio',
      'nvim-lua/plenary.nvim',
      'antoinemadec/FixCursorHold.nvim',
      'nvim-treesitter/nvim-treesitter',
      -- Go adapter
      'fredrikaverpil/neotest-golang',
    },
    keys = {
      {
        '<leader>ts',
        function()
          require('neotest').summary.toggle()
        end,
        desc = 'Toggle test summary',
      },
      {
        '<leader>to',
        function()
          require('neotest').output_panel.toggle()
        end,
        desc = 'Toggle test output panel',
      },
    },
    config = function()
      require('neotest').setup {
        adapters = {
          require 'neotest-golang' {
            go_test_args = { '-v', '-race', '-count=1' },
            dap_go_enabled = true, -- Enable DAP integration for debugging tests
          },
          java_adapter(),
        },
      }
    end,
  },

  {
    -- Java adapter (JUnit 5). Runs tests with the JUnit Platform Console
    -- standalone jar against the jdtls client configured in ftplugin/java.lua.
    -- Lazy-loaded on Java buffers and on the :NeotestJava command, so run
    -- `:NeotestJava setup` once to download the JUnit console jar.
    --
    -- This is the supported route for `:NeotestJava setup`, hence the ft/cmd
    -- triggers; neotest's config above pulls the adapter in via `require`.
    'rcasia/neotest-java',
    ft = 'java',
    cmd = { 'NeotestJava' },
    dependencies = {
      'mfussenegger/nvim-jdtls',
      'mfussenegger/nvim-dap', -- debug strategy for `\d` / `\D`
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
