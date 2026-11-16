-- Build tooling for neotest-java.
--
-- jdtls autobuild is disabled in ftplugin/java.lua, so the build tool owns the
-- compiled output:
--
-- * Maven: jdtls (ECJ 1.63, bundled with mason's jdtls >= 1.63) crashes on a
--   Lombok `@SneakyThrows` constructor with
--     ClassCastException: BlockScope cannot be cast to MethodScope
--   (see redhat-developer/vscode-java#4558 / eclipse.jdt.ls#3199). The Java
--   Builder then retries forever, wipes target/classes and rewrites
--   target/generated-sources/annotations while Maven compiles them. Maven
--   output (target/classes) is what jdtls already reports, so nothing to remap.
-- * Gradle: jdtls (Buildship) reports Eclipse output dirs `bin/<sourceSet>`,
--   which stay empty without autobuild. Gradle writes to
--   `build/classes/java/<sourceSet>` and `build/resources/<sourceSet>`, so the
--   classpath is remapped to those.
local GRADLE_MARKERS = { 'build.gradle', 'build.gradle.kts', 'settings.gradle', 'settings.gradle.kts' }

local function is_gradle(dir)
  for _, name in ipairs(GRADLE_MARKERS) do
    if vim.uv.fs_stat(dir .. '/' .. name) then
      return true
    end
  end
  return false
end

local function build_command(cwd)
  if is_gradle(cwd) then
    local wrapper = cwd .. '/gradlew'
    local cmd = { vim.fn.executable(wrapper) == 1 and wrapper or 'gradle', '--offline', '-q', 'testClasses' }
    if vim.uv.fs_stat(cwd .. '/src/integrationTest') then
      table.insert(cmd, 'integrationTestClasses')
    end
    return cmd
  end

  local wrapper = cwd .. '/mvnw'
  return {
    vim.fn.executable(wrapper) == 1 and wrapper or 'mvn',
    '-o', -- dependencies are already in the local repo; fail fast otherwise
    '-q',
    '-DskipTests',
    '-Dspotless.check.skip=true',
    '-Dcheckstyle.skip=true',
    'test-compile',
  }
end

local function java_compiler()
  return {
    -- opts = { base_dir = neotest-java.Path, compile_mode = 'incremental'|'full' }
    compile = function(opts)
      local cwd = opts.base_dir:to_string()
      local cmd = build_command(cwd)

      local nio = require 'nio'
      local future = nio.control.future()
      vim.system(cmd, { cwd = cwd, text = true }, function(result)
        future.set(result)
      end)

      local result = future.wait()
      if result.code ~= 0 then
        local output = table.concat({ result.stdout or '', result.stderr or '' }, '\n')
        vim.notify(cmd[1] .. ' compile failed:\n' .. output:sub(-3000), vim.log.levels.ERROR)
        error('java compile failed: ' .. cmd[1])
      end
    end,
  }
end

--- neotest-java's default classpath provider; for Gradle modules, `bin/<sourceSet>`
--- entries are replaced by Gradle's real class and resource output dirs. The same
--- provider feeds the JUnit launcher and the javap method-id resolver.
local function java_classpath_provider()
  local compilers = require 'neotest-java.core.spec_builder.compiler'
  local ClasspathProvider = require 'neotest-java.core.spec_builder.compiler.classpath_provider'
  local default = ClasspathProvider { client_provider = compilers.client_provider }

  return {
    get_classpath = function(base_dir, additional_entries)
      local classpath = default.get_classpath(base_dir, additional_entries)
      -- Method-id resolution passes the test file's directory, not the module root.
      local dir = vim.fs.root(base_dir:to_string(), GRADLE_MARKERS)
      if not dir then
        return classpath
      end
      local name = vim.fs.basename(dir)

      local entries = {}
      for _, entry in ipairs(vim.split(classpath, ':', { plain = true })) do
        -- jdtls reports either `<dir>/bin/<sourceSet>` or the workspace-relative `/<project>/bin/<sourceSet>`
        local source_set = entry:match('^' .. vim.pesc(dir) .. '/bin/([%w_]+)$') or entry:match('^/' .. vim.pesc(name) .. '/bin/([%w_]+)$')
        local classes = source_set and dir .. '/build/classes/java/' .. source_set
        if classes and vim.uv.fs_stat(classes) then
          table.insert(entries, classes)
          table.insert(entries, dir .. '/build/resources/' .. source_set)
        else
          table.insert(entries, entry)
        end
      end
      return table.concat(entries, ':')
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
    lsp_compiler = java_compiler(),
    classpath_provider = java_classpath_provider(),
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
