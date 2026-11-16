-- Kanso developer overlay: preserves plugins, mappings, LSP and VimTeX.
-- Color changes follow ~/Rice/kanso/theme-selection.json when re-entering Nvim.
local uv = vim.uv or vim.loop
local selection = vim.fn.expand('~/Rice/kanso/theme-selection.json')
local last_mode = nil
local augroup = vim.api.nvim_create_augroup('KansoDeveloperColors', { clear = true })

local palettes = {
  day = {
    bg='#1D3D46', surface='#294E57', ink='#F7E9C9', muted='#9EBCB8',
    accent='#D5CFAD', border='#527781', selection='#41636B',
    green='#A7C1A5', yellow='#DDC99B', blue='#A5BCC8', cyan='#92C3C1',
    magenta='#C7B3CA', red='#CF958B'
  },
  night = {
    bg='#12262E', surface='#1E3740', ink='#EADFCC', muted='#A3B7B2',
    accent='#D5CFAD', border='#3C606B', selection='#31525D',
    green='#9FBEA5', yellow='#E4CCA3', blue='#99BEC9', cyan='#8DC5BF',
    magenta='#C6A9C6', red='#D79B96'
  }
}

local function mode()
  local fd = io.open(selection, 'r')
  if not fd then return 'day' end
  local contents = fd:read('*a') or ''
  fd:close()
  local selected = contents:match('"selected"%s*:%s*"([^"]+)"')
  return selected == 'night' and 'night' or 'day'
end

local function set(group, options) vim.api.nvim_set_hl(0, group, options) end
local function apply(force)
  local selected = mode()
  if not force and last_mode == selected then return end
  last_mode = selected
  local p = palettes[selected]
  -- Do not change terminal colors here; terminal palette comes from Alacritty.
  vim.o.termguicolors = true
  vim.o.background = 'dark'
  set('Normal', { bg=p.bg, fg=p.ink })
  set('NormalNC', { bg=p.bg, fg=p.ink })
  set('NormalFloat', { bg=p.surface, fg=p.ink })
  set('FloatBorder', { bg=p.surface, fg=p.border })
  set('FloatTitle', { bg=p.surface, fg=p.accent, bold=true })
  set('WinSeparator', { fg=p.border })
  set('CursorLine', { bg=p.surface })
  set('CursorColumn', { bg=p.surface })
  set('LineNr', { fg=p.muted })
  set('CursorLineNr', { fg=p.accent, bold=true })
  set('SignColumn', { bg=p.bg })
  set('FoldColumn', { bg=p.bg, fg=p.muted })
  set('Visual', { bg=p.selection })
  set('Search', { bg=p.yellow, fg=p.bg })
  set('IncSearch', { bg=p.accent, fg=p.bg })
  set('MatchParen', { bg=p.selection, bold=true })
  set('Pmenu', { bg=p.surface, fg=p.ink })
  set('PmenuSel', { bg=p.selection, fg=p.accent, bold=true })
  set('PmenuSbar', { bg=p.bg })
  set('PmenuThumb', { bg=p.border })
  set('StatusLine', { bg=p.surface, fg=p.ink })
  set('StatusLineNC', { bg=p.bg, fg=p.muted })
  set('TabLine', { bg=p.bg, fg=p.muted })
  set('TabLineSel', { bg=p.surface, fg=p.accent, bold=true })
  set('TabLineFill', { bg=p.bg })
  set('VertSplit', { fg=p.border })
  set('Directory', { fg=p.blue })
  set('Comment', { fg=p.muted, italic=true })
  set('Constant', { fg=p.yellow })
  set('String', { fg=p.green })
  set('Character', { fg=p.green })
  set('Number', { fg=p.yellow })
  set('Boolean', { fg=p.yellow })
  set('Identifier', { fg=p.ink })
  set('Function', { fg=p.blue })
  set('Statement', { fg=p.accent })
  set('Conditional', { fg=p.accent })
  set('Repeat', { fg=p.accent })
  set('Operator', { fg=p.muted })
  set('Keyword', { fg=p.accent, bold=true })
  set('PreProc', { fg=p.magenta })
  set('Type', { fg=p.cyan })
  set('Special', { fg=p.yellow })
  set('Underlined', { fg=p.blue, underline=true })
  set('Todo', { fg=p.bg, bg=p.yellow, bold=true })
  set('Error', { fg=p.red, bold=true })
  set('DiagnosticError', { fg=p.red })
  set('DiagnosticWarn', { fg=p.yellow })
  set('DiagnosticInfo', { fg=p.blue })
  set('DiagnosticHint', { fg=p.green })
  set('DiagnosticUnderlineError', { sp=p.red, undercurl=true })
  set('DiagnosticUnderlineWarn', { sp=p.yellow, undercurl=true })
  set('DiffAdd', { fg=p.green, bg=p.surface })
  set('DiffChange', { fg=p.yellow, bg=p.surface })
  set('DiffDelete', { fg=p.red, bg=p.surface })
  set('GitSignsAdd', { fg=p.green })
  set('GitSignsChange', { fg=p.yellow })
  set('GitSignsDelete', { fg=p.red })
  local captures = {
    ['@comment']={ fg=p.muted, italic=true },
    ['@string']={ fg=p.green }, ['@string.escape']={ fg=p.magenta },
    ['@number']={ fg=p.yellow }, ['@boolean']={ fg=p.yellow },
    ['@keyword']={ fg=p.accent }, ['@keyword.function']={ fg=p.accent },
    ['@function']={ fg=p.blue }, ['@function.call']={ fg=p.blue },
    ['@method']={ fg=p.blue }, ['@function.method']={ fg=p.blue },
    ['@type']={ fg=p.cyan }, ['@type.builtin']={ fg=p.cyan },
    ['@variable']={ fg=p.ink }, ['@variable.parameter']={ fg=p.ink },
    ['@property']={ fg=p.yellow }, ['@constant']={ fg=p.yellow },
    ['@punctuation']={ fg=p.muted }, ['@operator']={ fg=p.muted },
    ['@markup.heading']={ fg=p.blue, bold=true },
    ['@markup.link']={ fg=p.cyan, underline=true },
    ['@lsp.type.function']={ fg=p.blue },
    ['@lsp.type.class']={ fg=p.cyan },
    ['@lsp.type.interface']={ fg=p.cyan },
    ['@lsp.type.parameter']={ fg=p.ink },
  }
  for name, settings in pairs(captures) do set(name, settings) end
end

vim.api.nvim_create_autocmd('ColorScheme', { group=augroup, callback=function() apply(true) end })
vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  group=augroup, callback=function() apply(false) end,
})
vim.api.nvim_create_user_command('KansoRefresh', function() apply(true) end,
  { desc='Reload the current Kanso day/night colors' })
apply(true)
