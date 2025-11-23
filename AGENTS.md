# Neovim Configuration - Agent Guidelines

## Commands
- **Format**: `stylua %` (format Lua files), `==` in normal mode (format buffer)
- **Lint**: Automatic on save/file changes via nvim-lint
- **Plugin sync**: `nvim --headless "+Lazy! sync" +qa`
- **Health check**: `:checkhealth` in Neovim

## Code Style Guidelines
- **Indentation**: 2 spaces (configured in .stylua.toml)
- **Line width**: 160 characters
- **Quotes**: Prefer single quotes, auto-convert when appropriate
- **Call parentheses**: None (stylua config)
- **File structure**: 
  - Main config in `init.lua`
  - Plugin configs in `lua/kickstart/plugins/` and `lua/custom/plugins/`
  - Modular files in `lua/` (options.lua, keymaps.lua, etc.)

## Lua Conventions
- Use `require()` for module imports
- Plugin specs return tables with plugin name and config
- Use vim.api functions for Neovim API calls
- Autocommands should be created with named groups
- Keymaps defined in `keymaps.lua` or plugin configs

## Error Handling
- Use pcall() for potentially failing operations
- Check health with `:checkhealth` for issues
- Plugin errors visible in `:Lazy` UI

## Testing
- No formal test suite - validate by loading Neovim
- Test plugin changes with `:Lazy reload <plugin>`
- Verify keymaps with `:map` and `:verbose map`