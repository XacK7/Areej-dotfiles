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
            hi Normal guibg=NONE ctermbg=NONE
            hi NormalNC guibg=NONE ctermbg=NONE
            hi Pmenu guibg=NONE ctermbg=NONE
            hi SignColumn guibg=NONE ctermbg=NONE
            hi VertSplit guibg=NONE ctermbg=NONE
            hi StatusLine guibg=NONE ctermbg=NONE
            hi EndOfBuffer guibg=NONE ctermbg=NONE
            hi LineNrAbove guifg=#888888
            hi LineNrBelow guifg=#888888
            hi LineNr guifg=#ffffff
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
