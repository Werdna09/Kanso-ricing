-- Kanso: small, non-invasive highlight overlay applied after the existing theme.
-- Does not touch plugin lists, LSP, Treesitter, VimTeX or key mappings.
local palette = {
  bg = '#1D3D46', side = '#294E57', ink = '#F7E9C9', muted = '#9EBCB8',
  accent = '#D5CFAD', blue = '#A5BCC8', green = '#A7C1A5',
  yellow = '#DDC99B', red = '#CF958B', border = '#527781',
}
local function apply()
  local hl = vim.api.nvim_set_hl
  hl(0, 'Normal', { fg = palette.ink, bg = palette.bg })
  hl(0, 'NormalFloat', { fg = palette.ink, bg = palette.side })
  hl(0, 'FloatBorder', { fg = palette.border, bg = palette.side })
  hl(0, 'CursorLine', { bg = palette.side })
  hl(0, 'CursorLineNr', { fg = palette.accent, bold = true })
  hl(0, 'LineNr', { fg = palette.muted })
  hl(0, 'Visual', { bg = '#41636B' })
  hl(0, 'Search', { fg = palette.bg, bg = palette.yellow })
  hl(0, 'IncSearch', { fg = palette.bg, bg = palette.accent })
  hl(0, 'Pmenu', { fg = palette.ink, bg = palette.side })
  hl(0, 'PmenuSel', { fg = palette.bg, bg = palette.accent })
  hl(0, 'StatusLine', { fg = palette.ink, bg = palette.side })
  hl(0, 'StatusLineNC', { fg = palette.muted, bg = palette.bg })
  hl(0, 'Comment', { fg = palette.muted, italic = true })
  hl(0, 'String', { fg = palette.green })
  hl(0, 'Function', { fg = palette.blue })
  hl(0, 'Keyword', { fg = palette.accent, bold = true })
  hl(0, 'Type', { fg = palette.yellow })
  hl(0, 'DiagnosticError', { fg = palette.red })
  hl(0, 'DiagnosticWarn', { fg = palette.yellow })
  hl(0, 'DiagnosticInfo', { fg = palette.blue })
  hl(0, 'DiagnosticHint', { fg = palette.green })
end
vim.api.nvim_create_autocmd('ColorScheme', { group = vim.api.nvim_create_augroup('KansoInk', { clear = true }), callback = apply })
apply()
