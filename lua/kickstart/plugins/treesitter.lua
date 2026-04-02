---@module 'lazy'
---@type LazySpec
return {
  { -- Highlight, edit, and navigate code
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    branch = 'main',
    -- [[ Configure Treesitter ]] See `:help nvim-treesitter-intro`
    config = function()
      local parsers = {
        'bash', 'c', 'cpp', 'diff', 'go', 'html', 'java', 'javascript',
        'lua', 'luadoc', 'markdown', 'markdown_inline', 'python',
        'query', 'rust', 'tsx', 'typescript', 'vim', 'vimdoc',
      }
      require('nvim-treesitter').install(parsers)

      vim.api.nvim_create_autocmd('FileType', {
        callback = function(args)
          local buf, filetype = args.buf, args.match
          local language = vim.treesitter.language.get_lang(filetype)
          if not language then return end
          if not vim.treesitter.language.add(language) then return end

          vim.treesitter.start(buf, language)
          vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

  { -- Textobjects: select, move, swap via treesitter queries
    'nvim-treesitter/nvim-treesitter-textobjects',
    branch = 'main',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-treesitter-textobjects').setup {
        select = {
          lookahead = true,
        },
        move = {
          set_jumps = true,
        },
      }

      local select = require 'nvim-treesitter-textobjects.select'
      local move = require 'nvim-treesitter-textobjects.move'
      local swap = require 'nvim-treesitter-textobjects.swap'

      -- Select textobjects
      for _, mode in ipairs { 'x', 'o' } do
        vim.keymap.set(mode, 'aa', function() select.select_textobject('@parameter.outer', 'textobjects') end, { desc = 'a parameter' })
        vim.keymap.set(mode, 'ia', function() select.select_textobject('@parameter.inner', 'textobjects') end, { desc = 'inner parameter' })
        vim.keymap.set(mode, 'af', function() select.select_textobject('@function.outer', 'textobjects') end, { desc = 'a function' })
        vim.keymap.set(mode, 'if', function() select.select_textobject('@function.inner', 'textobjects') end, { desc = 'inner function' })
        vim.keymap.set(mode, 'ac', function() select.select_textobject('@class.outer', 'textobjects') end, { desc = 'a class' })
        vim.keymap.set(mode, 'ic', function() select.select_textobject('@class.inner', 'textobjects') end, { desc = 'inner class' })
      end

      -- Move to next/previous function/class
      for _, mode in ipairs { 'n', 'x', 'o' } do
        vim.keymap.set(mode, ']m', function() move.goto_next_start('@function.outer', 'textobjects') end, { desc = 'Next function start' })
        vim.keymap.set(mode, ']]', function() move.goto_next_start('@class.outer', 'textobjects') end, { desc = 'Next class start' })
        vim.keymap.set(mode, ']M', function() move.goto_next_end('@function.outer', 'textobjects') end, { desc = 'Next function end' })
        vim.keymap.set(mode, '][', function() move.goto_next_end('@class.outer', 'textobjects') end, { desc = 'Next class end' })
        vim.keymap.set(mode, '[m', function() move.goto_previous_start('@function.outer', 'textobjects') end, { desc = 'Previous function start' })
        vim.keymap.set(mode, '[[', function() move.goto_previous_start('@class.outer', 'textobjects') end, { desc = 'Previous class start' })
        vim.keymap.set(mode, '[M', function() move.goto_previous_end('@function.outer', 'textobjects') end, { desc = 'Previous function end' })
        vim.keymap.set(mode, '[]', function() move.goto_previous_end('@class.outer', 'textobjects') end, { desc = 'Previous class end' })
      end

      -- Swap parameters
      vim.keymap.set('n', '<leader>a', function() swap.swap_next '@parameter.inner' end, { desc = 'Swap next parameter' })
      vim.keymap.set('n', '<leader>A', function() swap.swap_previous '@parameter.inner' end, { desc = 'Swap previous parameter' })
    end,
  },
}
-- vim: ts=2 sts=2 sw=2 et
