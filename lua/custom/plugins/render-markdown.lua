-- In-buffer markdown rendering: headings, code blocks, tables, checkboxes, etc.
-- Works with the treesitter markdown/markdown_inline parsers from kickstart.plugins.treesitter.
return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown', 'opencode_output' },
  keys = {
    -- markdown-plus owns the rest of <leader>m*, so mt/mT are free.
    { '<leader>mt', function() require('render-markdown').buf_toggle() end, desc = 'Markdown: toggle render (buffer)' },
    { '<leader>mT', function() require('render-markdown').toggle() end, desc = 'Markdown: toggle render (global)' },
  },
  dependencies = {
    'nvim-treesitter/nvim-treesitter',
    'nvim-tree/nvim-web-devicons',
  },
  opts = {
    file_types = { 'markdown', 'opencode_output' },
    heading = {
      -- Keep the text aligned with the raw line so editing does not jump around.
      position = 'overlay',
    },
    code = {
      sign = false,
      width = 'block',
      left_pad = 1,
      right_pad = 1,
    },
    -- Math rendering needs an external latex toolchain (utftex/latex2text), not installed here.
    latex = { enabled = false },
    -- Hide added virtual text on the cursor line so the raw line is editable.
    anti_conceal = {
      enabled = true,
      ignore = {
        code_background = true,
        indent = true,
        sign = true,
        virtual_lines = true,
      },
    },
    overrides = {
      filetype = {
        -- opencode output is read-only: keep it fully rendered at all times.
        opencode_output = {
          anti_conceal = { enabled = false },
        },
      },
    },
  },
}
-- vim: ts=2 sts=2 sw=2 et
