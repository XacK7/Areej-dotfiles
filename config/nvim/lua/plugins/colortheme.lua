-- ~/.config/nvim/lua/plugins/horizon.lua
return {
  {
    'akinsho/horizon.nvim',
    lazy = false,
    priority = 1000, -- make sure it loads before other themes
    config = function()
      vim.cmd.colorscheme 'horizon'

      -- Function to set transparency
      local function set_transparent(enable)
        if enable then
          vim.cmd [[
            hi Normal           guibg=NONE ctermbg=NONE
            hi NormalNC         guibg=NONE ctermbg=NONE
            hi NormalFloat      guibg=NONE ctermbg=NONE
            hi FloatBorder      guibg=NONE ctermbg=NONE
            hi FloatTitle       guibg=NONE ctermbg=NONE
            hi Pmenu            guibg=NONE ctermbg=NONE
            hi PmenuSel         guibg=NONE ctermbg=NONE
            hi SignColumn       guibg=NONE ctermbg=NONE
            hi VertSplit        guibg=NONE ctermbg=NONE
            hi WinSeparator     guibg=NONE ctermbg=NONE
            hi StatusLine       guibg=NONE ctermbg=NONE
            hi StatusLineNC     guibg=NONE ctermbg=NONE
            hi TabLine          guibg=NONE ctermbg=NONE
            hi TabLineFill      guibg=NONE ctermbg=NONE
            hi EndOfBuffer      guibg=NONE ctermbg=NONE
            hi MsgArea          guibg=NONE ctermbg=NONE
            hi FoldColumn       guibg=NONE ctermbg=NONE
            hi CursorLine       guibg=NONE ctermbg=NONE
            hi CursorLineNr     guibg=NONE ctermbg=NONE
            hi LineNrAbove      guifg=#888888 guibg=NONE ctermbg=NONE
            hi LineNrBelow      guifg=#888888 guibg=NONE ctermbg=NONE
            hi LineNr           guifg=#ffffff guibg=NONE ctermbg=NONE
            " Telescope
            hi TelescopeNormal       guibg=NONE ctermbg=NONE
            hi TelescopeBorder       guibg=NONE ctermbg=NONE
            hi TelescopePromptNormal guibg=NONE ctermbg=NONE
            hi TelescopePromptBorder guibg=NONE ctermbg=NONE
            hi TelescopeResultsNormal guibg=NONE ctermbg=NONE
            hi TelescopeResultsBorder guibg=NONE ctermbg=NONE
            hi TelescopePreviewNormal guibg=NONE ctermbg=NONE
            hi TelescopePreviewBorder guibg=NONE ctermbg=NONE
            " Neo-tree
            hi NeoTreeNormal     guibg=NONE ctermbg=NONE
            hi NeoTreeNormalNC   guibg=NONE ctermbg=NONE
            hi NeoTreeEndOfBuffer guibg=NONE ctermbg=NONE
            hi NeoTreeWinSeparator guibg=NONE ctermbg=NONE
            " Bufferline
            hi BufferLineFill            guibg=NONE ctermbg=NONE
            hi BufferLineBackground      guibg=NONE ctermbg=NONE
            hi BufferLineBufferVisible   guibg=NONE ctermbg=NONE
            hi BufferLineBufferSelected  guibg=NONE ctermbg=NONE
            " Which-key / notify / cmp
            hi WhichKeyFloat     guibg=NONE ctermbg=NONE
            hi NotifyBackground  guibg=NONE ctermbg=NONE
            hi CmpItemMenu       guibg=NONE ctermbg=NONE
            " Diagnostics
            hi DiagnosticVirtualTextError guibg=NONE ctermbg=NONE
            hi DiagnosticVirtualTextWarn  guibg=NONE ctermbg=NONE
            hi DiagnosticVirtualTextInfo  guibg=NONE ctermbg=NONE
            hi DiagnosticVirtualTextHint  guibg=NONE ctermbg=NONE
          ]]
        else
          vim.cmd 'colorscheme horizon' -- reload theme with normal background
        end
      end

      -- Toggle command
      vim.api.nvim_create_user_command('ToggleTransparency', function()
        if vim.g.transparent_enabled then
          set_transparent(false)
          vim.g.transparent_enabled = false
        else
          set_transparent(true)
          vim.g.transparent_enabled = true
        end
      end, {})
      -- Keymap for toggling (Normal mode)
      vim.keymap.set('n', '<leader>bg', ':ToggleTransparency<CR>', { desc = 'Toggle Transparency' })

      -- Start with transparency ON by default
      vim.g.transparent_enabled = true
      set_transparent(true)
    end,
    opts = {
      plugins = {
        cmp = true,
        indent_blankline = true,
        nvim_tree = true,
        telescope = true,
        which_key = true,
        barbar = true,
        notify = true,
        symbols_outline = true,
        neo_tree = true,
        gitsigns = true,
        crates = true,
        hop = true,
        navic = true,
        quickscope = true,
        flash = true,
      },
    },
  },
}
