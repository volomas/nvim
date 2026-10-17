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

local jdtls_path = mason_pkg .. '/jdtls'
local lombok_jar = jdtls_path .. '/lombok.jar'

-- ── Java runtimes ─────────────────────────────────────────────────────────────
-- Register every installed JDK so a project targeting an older release still
-- resolves its execution environment. With only $JAVA_HOME registered, a Java
-- 17/11 project has no matching runtime and m2e silently falls back to
-- source/target 1.8.
local java_home = vim.fn.expand '$JAVA_HOME'
local default_home = (vim.uv.fs_realpath(java_home) or java_home):gsub('/$', '')

-- Read a JDK's `release` file for the true major version ("21.0.11",
-- "11.0.28", "1.8.0_392" -> 21, 11, 8). Cheaper and more reliable than
-- shelling out to `java -version` once per candidate.
local function jdk_major(dir)
  if vim.fn.filereadable(dir .. '/release') == 0 then
    return nil
  end
  for _, line in ipairs(vim.fn.readfile(dir .. '/release')) do
    local ver = line:match '^JAVA_VERSION="([^"]+)"'
    if ver then
      local m = ver:match '^1%.(%d+)' or ver:match '^(%d+)'
      if m then
        return tonumber(m)
      end
    end
  end
  return nil
end

-- Collect candidates: every sdkman JDK, plus the active $JAVA_HOME (in case it
-- lives outside sdkman). Collapse to one runtime per major version, resolving
-- symlinks (sdkman's `current`) and preferring $JAVA_HOME for its own major.
local candidates = vim.fn.glob(vim.fn.expand '~/.sdkman/candidates/java' .. '/*', true, true)
table.insert(candidates, java_home)

local by_major = {}
for _, dir in ipairs(candidates) do
  local real = (vim.uv.fs_realpath(dir) or dir):gsub('/$', '')
  local major = jdk_major(real)
  if major and (by_major[major] == nil or real == default_home) then
    by_major[major] = real
  end
end

local majors = vim.tbl_keys(by_major)
table.sort(majors)
local runtimes = {}
for _, major in ipairs(majors) do
  local home = by_major[major]
  table.insert(runtimes, { name = 'JavaSE-' .. major, path = home, default = home == default_home })
end

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

-- Workspace: one directory per project (keyed by absolute root path)
-- Only repo-level markers. Build files (pom.xml/build.gradle) also appear in
-- every module of a multi-module project, which would start one jdtls per
-- module — wasteful, and it breaks neotest-java (tests in module B talk to
-- module A's server). Keeping repo-level markers means a single server per repo.
local root_markers = { '.git', 'mvnw', 'gradlew', 'settings.gradle', 'settings.gradle.kts' }
local root_dir = require('jdtls.setup').find_root(root_markers)
if not root_dir then
  -- Fallback: current working directory
  root_dir = vim.fn.getcwd()
end
-- Key on name + short hash of the absolute path so two repos with the same
-- directory name (e.g. two `backend` dirs, or a worktree next to its main
-- checkout) never share one index.
local project_root = vim.fn.fnamemodify(root_dir, ':p')
local project_name = vim.fn.fnamemodify(project_root:gsub('/$', ''), ':t')
local project_hash = vim.fn.sha256(project_root):sub(1, 8)
local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. project_name .. '-' .. project_hash

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
  -- ALL is useful when debugging jdtls itself; WARNING keeps .metadata/.log small
  '-Dlog.level=WARNING',
  '-Xmx2G',
  '--add-modules=ALL-SYSTEM',
  '--add-opens',
  'java.base/java.util=ALL-UNNAMED',
  '--add-opens',
  'java.base/java.lang=ALL-UNNAMED',
}

-- Lombok: attach as javaagent if the jar exists
if vim.fn.filereadable(lombok_jar) == 1 then
  table.insert(jvm_args, '-javaagent:' .. lombok_jar)
end

-- Build the launch command as a fresh list (never mutate jvm_args in place)
local cmd = { vim.fn.expand '$JAVA_HOME/bin/java' }
vim.list_extend(cmd, jvm_args)
vim.list_extend(cmd, { '-jar', launcher_jar, '-configuration', config_dir, '-data', workspace_dir })

-- ── JDTLS config ──────────────────────────────────────────────────────────────
local config = {
  -- The command that starts the language server
  cmd = cmd,

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
        -- Every installed JDK, discovered above; the active $JAVA_HOME is the
        -- default. This is what lets m2e resolve source/target levels for a
        -- project pinned to 11/17/21 without falling back to 1.8.
        runtimes = runtimes,
      },
      -- Organize imports when the buffer is saved
      saveActions = { organizeImports = true },
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

-- Setup DAP for Java (debug adapter + hot code replace)
jdtls.setup_dap { hotcodereplace = 'auto' }

-- Discover run configurations (main classes, test methods) only once the
-- server has actually attached. Calling this inline right after
-- start_or_attach races the async initialization and silently yields no
-- configurations on a fresh project.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('jdtls-dap-main-classes', { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == 'jdtls' and not client._dap_main_classes_ready then
      client._dap_main_classes_ready = true
      require('jdtls.dap').setup_dap_main_class_configs()
    end
  end,
})

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
map('n', '<leader>rv', function()
  jdtls.extract_variable()
end, 'Refactor: Extract Variable')
map('v', '<leader>rv', function()
  jdtls.extract_variable(true)
end, 'Refactor: Extract Variable')
map('n', '<leader>rm', function()
  jdtls.extract_method()
end, 'Refactor: Extract Method')
map('v', '<leader>rm', function()
  jdtls.extract_method(true)
end, 'Refactor: Extract Method')
map('n', '<leader>rf', function()
  jdtls.extract_constant()
end, 'Refactor: Extract Constant (Introduce Field)')
map('v', '<leader>rf', function()
  jdtls.extract_constant(true)
end, 'Refactor: Extract Constant (Introduce Field)')

-- <leader>rr = Refactoring quick list (code actions scoped to refactor) -- mirrors ideavimrc Refactorings.QuickListPopupAction
-- Override the global refactoring.nvim mapping with the JDTLS-aware version for Java
map({ 'n', 'v' }, '<leader>rr', function()
  vim.lsp.buf.code_action { context = { only = { 'refactor' } } }
end, 'Refactor: Quick List (Java)')

-- Go to test: <leader>gt (mirrors ideavimrc GotoTest)
map('n', '<leader>gt', function()
  require('jdtls.tests').goto_subjects()
end, 'Goto: Test / Subject')

-- Run / Debug: \r, \d (mirrors ideavimrc RunClass / DebugClass)
map('n', '\\r', function()
  jdtls.test_nearest_method { config_overrides = { noDebug = true } }
end, 'Run: Nearest Test Method')
map('n', '\\d', function()
  jdtls.test_nearest_method()
end, 'Debug: Nearest Test Method')

-- Run / Debug entire test class: \R, \D (bonus: run/debug whole class like IntelliJ's "Run class")
map('n', '\\R', function()
  jdtls.test_class { config_overrides = { noDebug = true } }
end, 'Run: Test Class')
map('n', '\\D', function()
  jdtls.test_class()
end, 'Debug: Test Class')

-- Organize imports: =o (already mapped globally via util.organize_imports; override with jdtls version)
map('n', '=o', function()
  jdtls.organize_imports()
end, 'Organize Imports')

-- vim: ts=2 sts=2 sw=2 et
