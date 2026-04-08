# Neovim Configuration - Agent Guidelines

Kickstart.nvim fork targeting Neovim 0.12+. Plugin manager: lazy.nvim (SSH git URLs).

## Commands
- **Format Lua**: `stylua %` (CLI) or `==` in any mode (conform.nvim, async)
- **Format on save**: Go only (goimports + gofumpt). All other filetypes: manual `==`.
- **Plugin sync**: `nvim --headless "+Lazy! sync" +qa`
- **Health check**: `:checkhealth` inside Neovim

## Repo Layout
- `init.lua` — entrypoint: leader key, folding, theme commands, requires modules
- `lua/options.lua` — editor options (4-space tabs default, clipboard, etc.)
- `lua/keymaps.lua` — global keymaps and autocommands
- `lua/lazy-bootstrap.lua` — lazy.nvim bootstrap
- `lua/lazy-plugins.lua` — plugin list; core plugins inline, modular ones via `require`
- `lua/kickstart/plugins/` — core plugin configs (LSP, treesitter, telescope, conform, lint, etc.)
- `lua/custom/plugins/` — user plugin configs, auto-imported via `{ import = 'custom.plugins' }`
- `lua/util.lua` — small helpers (e.g. `organize_imports`)
- `ftplugin/` — filetype-specific config (go, java, lua, markdown). Java LSP (jdtls) lives here.

## Code Style
- `.stylua.toml`: 2-space indent, 160 col width, single quotes, no call parentheses
- Editor default is 4-space tabs (`options.lua`), but Lua files use 2-space via modelines
- All Lua files end with modeline: `-- vim: ts=2 sts=2 sw=2 et`
- Autocommands must use named groups (`vim.api.nvim_create_augroup`)

## LSP / Tooling (Mason-managed)
- **LSP servers**: gopls, lua_ls, bashls (registered via `vim.lsp.config` / `vim.lsp.enable`)
- **Java**: jdtls via nvim-jdtls, configured in `ftplugin/java.lua` (not in lspconfig)
- **Formatters**: stylua, goimports, gofumpt, google-java-format, jq, shfmt, prettierd/prettier
- **Linters**: golangci-lint (Go), shellcheck (sh/bash)

## Conventions
- Plugin specs return a table (or list of tables) from each file
- Adding a new plugin: create `lua/custom/plugins/<name>.lua` returning a lazy.nvim spec
- `lazy-lock.json` is gitignored — not committed
- Nerd Font assumed (`vim.g.have_nerd_font = true`)
- Two theme commands: `:Dark` (darcula_dark, default) and `:Light` (github_light)

## Testing
- No test suite. Validate by loading Neovim and checking `:checkhealth`.
- Reload a single plugin: `:Lazy reload <plugin>`
- Verify keymaps: `:verbose map <key>`
