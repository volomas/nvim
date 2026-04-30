-- ftplugin/java.lua
-- Runs every time a Java buffer is opened. Starts/attaches nvim-jdtls.
-- Keymaps mirror ideavimrc patterns for muscle-memory consistency.

local jdtls_ok, jdtls = pcall(require, 'jdtls')
if not jdtls_ok then
  vim.notify('nvim-jdtls not found. Run :Lazy sync to install it.', vim.log.levels.WARN)
  return
end

-- ── Paths ───────────────────────────────────────────────────────────────────
local mason_pkg = vim.fn.stdpath 'data' .. '/mason/packages'

-- Detect Java major version from $JAVA_HOME so runtimes.name stays in sync
-- with whatever sdkman has active. Output: e.g. "JavaSE-21"
local java_home = vim.fn.expand '$JAVA_HOME'
local java_runtime_name = 'JavaSE-21' -- fallback
local version_output = vim.fn.system(java_home .. '/bin/java -version 2>&1')
local major = version_output:match '"(%d+)%.'
if major then
  java_runtime_name = 'JavaSE-' .. major
end

local jdtls_path = mason_pkg .. '/jdtls'
local lombok_jar = jdtls_path .. '/lombok.jar'

-- The launcher jar drives the JVM startup
local launcher_jar = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')
if launcher_jar == '' then
  vim.notify('jdtls launcher jar not found. Run :MasonInstall jdtls', vim.log.levels.WARN)
  return
end

-- Config dir is OS-specific (must match arch on Apple Silicon)
local os_config = vim.fn.has 'mac' == 1 and 'config_mac' or 'config_linux'
if vim.uv.os_uname().machine == 'arm64' or vim.uv.os_uname().machine == 'aarch64' then
  os_config = os_config .. '_arm'
end
local config_dir = jdtls_path .. '/' .. os_config
if vim.fn.isdirectory(config_dir) == 0 then
  -- Fallback: try without arch suffix
  config_dir = jdtls_path .. '/' .. os_config:gsub('_arm$', '')
end

-- Workspace: one directory per project (keyed by project root name)
local root_markers = { 'pom.xml', 'build.gradle', 'build.gradle.kts', 'settings.gradle', 'settings.gradle.kts', '.git' }
local root_dir = require('jdtls.setup').find_root(root_markers)
if not root_dir then
  -- Fallback: current working directory
  root_dir = vim.fn.getcwd()
end
local project_name = vim.fn.fnamemodify(root_dir, ':p:h:t')
local jdtls_cache = vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. project_name
local workspace_dir = jdtls_cache

-- ── DAP bundles (java-debug-adapter + java-test) ───────────────────────────
local bundles = {}

-- java-debug-adapter
local debug_jar = vim.fn.glob(mason_pkg .. '/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar', 1)
if debug_jar ~= '' then
  table.insert(bundles, debug_jar)
end

-- java-test (vscode-java-test): exclude test runner and jacoco which conflict
local java_test_jars = vim.split(vim.fn.glob(mason_pkg .. '/java-test/extension/server/*.jar', 1), '\n', { trimempty = true })
local excluded_jars = { 'com.microsoft.java.test.runner-jar-with-dependencies.jar', 'jacocoagent.jar' }
for _, jar in ipairs(java_test_jars) do
  local fname = vim.fn.fnamemodify(jar, ':t')
  if not vim.tbl_contains(excluded_jars, fname) then
    table.insert(bundles, jar)
  end
end

-- ── Capabilities ─────────────────────────────────────────────────────────────
local capabilities = require('blink.cmp').get_lsp_capabilities()
-- jdtls needs a few extra capability flags for extended code actions
capabilities = vim.tbl_deep_extend('force', capabilities, {
  textDocument = {
    foldingRange = { dynamicRegistration = false, lineFoldingOnly = true },
  },
})

-- ── JVM args ─────────────────────────────────────────────────────────────────
local jvm_args = {
  '-Declipse.application=org.eclipse.jdt.ls.core.id1',
  '-Dosgi.bundles.defaultStartLevel=4',
  '-Declipse.product=org.eclipse.jdt.ls.core.product',
  '-Dlog.level=ALL',
  '-Xmx2G',
  '--add-modules=ALL-SYSTEM',
  '--add-opens', 'java.base/java.util=ALL-UNNAMED',
  '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
}

-- Lombok: attach as javaagent if the jar exists
if vim.fn.filereadable(lombok_jar) == 1 then
  table.insert(jvm_args, '-javaagent:' .. lombok_jar)
end

-- ── JDTLS config ──────────────────────────────────────────────────────────────
local config = {
  -- The command that starts the language server
  cmd = vim.list_extend({
    vim.fn.expand '$JAVA_HOME/bin/java',
  }, vim.list_extend(jvm_args, {
    '-jar', launcher_jar,
    '-configuration', config_dir,
    '-data', workspace_dir,
  })),

  -- Project root detection
  root_dir = root_dir,

  -- See: https://github.com/eclipse/eclipse.jdt.ls/wiki/Running-the-JAVA-LS-server-from-the-command-line#initialize-request
  settings = {
    java = {
      eclipse = { downloadSources = true },
      configuration = {
        -- 'automatic' reimports on pom.xml changes without prompting;
        -- 'interactive' tries to show a UI prompt which doesn't work in nvim
        updateBuildConfiguration = 'automatic',
        -- Map $JAVA_HOME to the correct JavaSE execution environment so m2e
        -- can resolve compiler source/target levels instead of falling back to 1.8
        runtimes = {
          {
            name = java_runtime_name,
            path = java_home,
            default = true,
          },
        },
      },
      -- Override Eclipse compiler settings globally — prevents m2e from
      -- regenerating source=1.8 fallback when it can't resolve the pom property chain
      settings = {
        url = vim.fn.expand '~/.config/nvim/java-settings/org.eclipse.jdt.core.prefs',
      },
      -- Keep Eclipse metadata (.classpath, .project, .factorypath) out of the project root
      import = {
        generatesMetadataFilesAtProjectRoot = false,
        gradle = {
          -- Init script redirects Eclipse output dirs (bin/) into build/eclipse-output
          arguments = { '--init-script', vim.fn.expand '~/.config/nvim/java-settings/jdtls-init.gradle' },
        },
      },
      maven = { downloadSources = true },
      implementationsCodeLens = { enabled = true },
      referencesCodeLens = { enabled = true },
      references = { includeDecompiledSources = true },
      inlayHints = { parameterNames = { enabled = 'all' } },
      signatureHelp = { enabled = true },
      completion = {
        favoriteStaticMembers = {
          'org.hamcrest.MatcherAssert.assertThat',
          'org.hamcrest.Matchers.*',
          'org.hamcrest.CoreMatchers.*',
          'org.junit.jupiter.api.Assertions.*',
          'java.util.Objects.requireNonNull',
          'java.util.Objects.requireNonNullElse',
          'org.mockito.Mockito.*',
        },
        importOrder = { 'java', 'javax', 'com', 'org' },
      },
      sources = {
        organizeImports = {
          starThreshold = 9999,
          staticStarThreshold = 9999,
        },
      },
      codeGeneration = {
        toString = {
          template = '${object.className}{${member.name()}=${member.value}, ${otherMembers}}',
        },
        useBlocks = true,
      },
      format = {
        -- Let conform.nvim / google-java-format handle formatting via ==
        enabled = false,
      },
    },
  },

  -- Extended capabilities (needed for code actions like extract/introduce)
  capabilities = capabilities,

  -- Bundles for java-debug and java-test
  init_options = {
    bundles = bundles,
  },
}

-- ── Start / attach ────────────────────────────────────────────────────────────
jdtls.start_or_attach(config)

-- Setup DAP configurations (discovers main classes and test methods automatically)
-- Deferred to allow the server to initialize first
jdtls.setup_dap { hotcodereplace = 'auto' }
require('jdtls.dap').setup_dap_main_class_configs()

-- ── User command: clean workspace (fixes stale m2e settings) ─────────────────
vim.api.nvim_buf_create_user_command(0, 'JdtlsCleanWorkspace', function()
  -- Stop the running JDTLS client
  local clients = vim.lsp.get_clients { name = 'jdtls' }
  for _, client in ipairs(clients) do
    client:stop(true)
  end
  -- Remove workspace cache and project .settings/ (regenerated by m2e on reimport)
  vim.fn.delete(workspace_dir, 'rf')
  local project_settings = root_dir .. '/.settings'
  if vim.fn.isdirectory(project_settings) == 1 then
    vim.fn.delete(project_settings, 'rf')
  end
  vim.notify('JDTLS workspace cleaned. Reopen the file to reimport.', vim.log.levels.INFO)
end, { desc = 'Clean JDTLS workspace cache and project .settings (fixes m2e 1.8 fallback)' })

-- ── Buffer-local keymaps (matching ideavimrc patterns) ────────────────────────
local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { buffer = true, silent = true, desc = desc })
end

-- Refactoring: <leader>r* (mirrors ideavimrc IntroduceVariable / ExtractMethod / IntroduceField)
map('n', '<leader>rv', function() jdtls.extract_variable() end, 'Refactor: Extract Variable')
map('v', '<leader>rv', function() jdtls.extract_variable(true) end, 'Refactor: Extract Variable')
map('n', '<leader>rm', function() jdtls.extract_method() end, 'Refactor: Extract Method')
map('v', '<leader>rm', function() jdtls.extract_method(true) end, 'Refactor: Extract Method')
map('n', '<leader>rf', function() jdtls.extract_constant() end, 'Refactor: Extract Constant (Introduce Field)')
map('v', '<leader>rf', function() jdtls.extract_constant(true) end, 'Refactor: Extract Constant (Introduce Field)')

-- <leader>rr = Refactoring quick list (code actions scoped to refactor) -- mirrors ideavimrc Refactorings.QuickListPopupAction
-- Override the global refactoring.nvim mapping with the JDTLS-aware version for Java
map({ 'n', 'v' }, '<leader>rr', function()
  vim.lsp.buf.code_action { context = { only = { 'refactor' } } }
end, 'Refactor: Quick List (Java)')

-- Go to test: <leader>gt (mirrors ideavimrc GotoTest)
map('n', '<leader>gt', function() require('jdtls.tests').goto_subjects() end, 'Goto: Test / Subject')

-- Run / Debug: \r, \d (mirrors ideavimrc RunClass / DebugClass)
map('n', '\\r', function() jdtls.test_nearest_method { config_overrides = { noDebug = true } } end, 'Run: Nearest Test Method')
map('n', '\\d', function() jdtls.test_nearest_method() end, 'Debug: Nearest Test Method')

-- Run / Debug entire test class: \R, \D (bonus: run/debug whole class like IntelliJ's "Run class")
map('n', '\\R', function() jdtls.test_class { config_overrides = { noDebug = true } } end, 'Run: Test Class')
map('n', '\\D', function() jdtls.test_class() end, 'Debug: Test Class')

-- Organize imports: =o (already mapped globally via util.organize_imports; override with jdtls version)
map('n', '=o', function() jdtls.organize_imports() end, 'Organize Imports')

-- vim: ts=2 sts=2 sw=2 et
