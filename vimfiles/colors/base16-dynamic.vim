" base16-dynamic colorscheme
"
" Original:
" base16-vim (https://github.com/chriskempson/base16-vim)
" by Chris Kempson (http://chriskempson.com)
"
" License:
" original software ([chriskempson/base16-vim](https://github.com/chriskempson/base16-vim)):
" [MIT](https://github.com/chriskempson/base16-vim/blob/master/LICENSE.md)
"
" Credit:
" present pallet:
" Material: Nate Peterson <https://github.com/ntpeters/base16-materialtheme-scheme>
" One Light: Daniel Pfeifer <https://github.com/purpleKarrot/base16-one-light-scheme>

if !has('vim9script')
  execute 'source' fnameescape(fnamemodify(expand('<sfile>'), ':p:h') . '/' . 'base16-dynamic.vim.legacy')
  finish
endif
vim9script

# Configuration:
g:base16#enable_italics = get(g:, 'base16#enable_italics', 1)
g:base16#pallet#dark = get(g:, 'base16#pallet#dark', {"scheme": "Material", "author": "Nate Peterson", "base00": "263238", "base01": "2E3C43", "base02": "314549", "base03": "546E7A", "base04": "B2CCD6", "base05": "EEFFFF", "base06": "EEFFFF", "base07": "FFFFFF", "base08": "F07178", "base09": "F78C6C", "base0A": "FFCB6B", "base0B": "C3E88D", "base0C": "89DDFF", "base0D": "82AAFF", "base0E": "C792EA", "base0F": "FF5370"})
g:base16#pallet#light = get(g:, 'base16#pallet#light', {"scheme": "One Light", "author": "Daniel Pfeifer (http://github.com/purpleKarrot)", "base00": "fafafa", "base01": "f0f0f1", "base02": "e5e5e6", "base03": "a0a1a7", "base04": "696c77", "base05": "383a42", "base06": "202227", "base07": "090a0b", "base08": "ca1243", "base09": "d75f00", "base0A": "c18401", "base0B": "50a14f", "base0C": "0184bc", "base0D": "4078f2", "base0E": "a626a4", "base0F": "986801"})

const base16_pallet = &bg == 'dark' ? g:base16#pallet#dark : g:base16#pallet#light

# validate pallet {{{
var valid = 0
if type(base16_pallet) == type({})
  valid = 1
  for key in range(16)
    if get(base16_pallet, printf('base%02X', key)) !~? '\v[0-9a-f]{6}'
      valid = 0
      break
    endif
  endfor
endif

if empty(valid)
  echohl ErrorMsg
  echo printf('ERROR: colorscheme base16-dynamic: g:base16#pallet#%s invalid', &bg)
  echohl None
  finish
endif
# }}}

# GUI color definitions
const gui00 = base16_pallet['base00']
const gui01 = base16_pallet['base01']
const gui02 = base16_pallet['base02']
const gui03 = base16_pallet['base03']
const gui04 = base16_pallet['base04']
const gui05 = base16_pallet['base05']
const gui06 = base16_pallet['base06']
const gui07 = base16_pallet['base07']
const gui08 = base16_pallet['base08']
const gui09 = base16_pallet['base09']
const gui0A = base16_pallet['base0A']
const gui0B = base16_pallet['base0B']
const gui0C = base16_pallet['base0C']
const gui0D = base16_pallet['base0D']
const gui0E = base16_pallet['base0E']
const gui0F = base16_pallet['base0F']

# Terminal color definitions
def Round(num: number): number
  if num < (95 - 55) / 2 + 55
    return 0
  elseif num < (135 - 95) / 2 + 95
    return 1
  elseif num < (175 - 135) / 2 + 135
    return 2
  elseif num < (215 - 175) / 2 + 175
    return 3
  elseif num < (255 - 215) / 2 + 215
    return 4
  else
    return 5
  endif
enddef

# color info is from https://jonasjacek.github.io/colors/
def CastRGB(hex_code: string): string
  var r = str2nr(hex_code[0 : 1], 16)
  var g = str2nr(hex_code[2 : 3], 16)
  var b = str2nr(hex_code[4 : 5], 16)

  # greyscale
  var r1 = (r - 8) / 10
  var r2 = (g - 8) / 10
  var r3 = (b - 8) / 10
  if abs(r1 - r2) <= 2 && abs(r1 - r3) <= 2 && abs(r2 - r3) <= 2 && r1 < 24
    return string(232 + r1)
  endif

  # 16-231
  r = Round(r)
  g = Round(g)
  b = Round(b)
  return string(36 * r + 6 * g + b + 16)
enddef

const cterm00 = CastRGB(gui00)
const cterm01 = CastRGB(gui01)
const cterm02 = CastRGB(gui02)
const cterm03 = CastRGB(gui03)
const cterm04 = CastRGB(gui04)
const cterm05 = CastRGB(gui05)
const cterm06 = CastRGB(gui06)
const cterm07 = CastRGB(gui07)
const cterm08 = CastRGB(gui08)
const cterm09 = CastRGB(gui09)
const cterm0A = CastRGB(gui0A)
const cterm0B = CastRGB(gui0B)
const cterm0C = CastRGB(gui0C)
const cterm0D = CastRGB(gui0D)
const cterm0E = CastRGB(gui0E)
const cterm0F = CastRGB(gui0F)

# terminal colours
if has('gui_running') || (exists('&tgc') && &tgc)
  g:terminal_ansi_colors = [
    '#' .. base16_pallet['base00'],
    '#' .. base16_pallet['base08'],
    '#' .. base16_pallet['base0B'],
    '#' .. base16_pallet['base0A'],
    '#' .. base16_pallet['base0D'],
    '#' .. base16_pallet['base0E'],
    '#' .. base16_pallet['base0C'],
    '#' .. base16_pallet['base05'],
    '#' .. base16_pallet['base03'],
    '#' .. base16_pallet['base08'],
    '#' .. base16_pallet['base0B'],
    '#' .. base16_pallet['base0A'],
    '#' .. base16_pallet['base0D'],
    '#' .. base16_pallet['base0E'],
    '#' .. base16_pallet['base0C'],
    '#' .. base16_pallet['base07'],
    ]
endif

# Theme setup
hi clear
g:colors_name = "base16-dynamic"

# Highlighting function
# Optional variables are attributes and guisp
def Hi(group: string, guifg: string, guibg: string, ctermfg: string, ctermbg: string, attr: string, guisp: string)
  if guifg != ""
    exec "hi " .. group .. " guifg=#" .. guifg
  endif
  if guibg != ""
    exec "hi " .. group .. " guibg=#" .. guibg
  endif
  if ctermfg != ""
    exec "hi " .. group .. " ctermfg=" .. ctermfg
  endif
  if ctermbg != ""
    exec "hi " .. group .. " ctermbg=" .. ctermbg
  endif
  if attr != ""
    exec "hi " .. group .. " gui=" .. attr .. " cterm=" .. attr
  endif
  if guisp != ""
    exec "hi " .. group .. " guisp=#" .. guisp
  endif
enddef


# Vim editor colors
Hi("Normal",        gui05, gui00, cterm05, cterm00, "", "")
Hi("Bold",          "", "", "", "", "bold", "")
Hi("Debug",         gui08, "", cterm08, "", "", "")
Hi("Directory",     gui0D, "", cterm0D, "", "", "")
Hi("Error",         gui00, gui08, cterm00, cterm08, "", "")
Hi("ErrorMsg",      gui08, gui00, cterm08, cterm00, "", "")
Hi("Exception",     gui08, "", cterm08, "", "", "")
Hi("FoldColumn",    gui0C, gui01, cterm0C, cterm01, "", "")
Hi("Folded",        gui03, gui01, cterm03, cterm01, "", "")
Hi("IncSearch",     gui01, gui09, cterm01, cterm09, "none", "")
Hi("Italic",        "", "", "", "", "none", "")
Hi("Macro",         gui08, "", cterm08, "", "", "")
Hi("MatchParen",    "", gui03, "", cterm03,  "", "")
Hi("ModeMsg",       gui0B, "", cterm0B, "", "", "")
Hi("MoreMsg",       gui0B, "", cterm0B, "", "", "")
Hi("Question",      gui0D, "", cterm0D, "", "", "")
Hi("Search",        gui01, gui0A, cterm01, cterm0A,  "", "")
Hi("Substitute",    gui01, gui0A, cterm01, cterm0A, "none", "")
Hi("SpecialKey",    gui03, "", cterm03, "", "", "")
Hi("TooLong",       gui08, "", cterm08, "", "", "")
Hi("Underlined",    gui08, "", cterm08, "", "", "")
Hi("Visual",        "", gui02, "", cterm02, "", "")
Hi("VisualNOS",     gui08, "", cterm08, "", "", "")
Hi("WarningMsg",    gui08, "", cterm08, "", "", "")
Hi("WildMenu",      gui08, gui0A, cterm08, "", "", "")
Hi("Title",         gui0D, "", cterm0D, "", "none", "")
Hi("Conceal",       gui0D, gui00, cterm0D, cterm00, "", "")
Hi("Cursor",        gui00, gui05, cterm00, cterm05, "", "")
Hi("NonText",       gui03, "", cterm03, "", "", "")
Hi("LineNr",        gui03, gui01, cterm03, cterm01, "", "")
Hi("SignColumn",    gui03, gui01, cterm03, cterm01, "", "")
# StatusLine: none -> bold
Hi("StatusLine",    gui04, gui02, cterm04, cterm02, "bold", "")
Hi("StatusLineNC",  gui03, gui01, cterm03, cterm01, "none", "")
Hi("VertSplit",     gui02, gui02, cterm02, cterm02, "none", "")
Hi("ColorColumn",   "", gui01, "", cterm01, "none", "")
Hi("CursorColumn",  "", gui01, "", cterm01, "none", "")
Hi("CursorLine",    "", gui01, "", cterm01, "none", "")
Hi("CursorLineNr",  gui04, gui01, cterm04, cterm01, "", "")
Hi("QuickFixLine",  "", gui01, "", cterm01, "none", "")
Hi("PMenu",         gui05, gui01, cterm05, cterm01, "none", "")
Hi("PMenuSel",      gui01, gui05, cterm01, cterm05, "", "")
Hi("TabLine",       gui03, gui01, cterm03, cterm01, "none", "")
Hi("TabLineFill",   gui03, gui01, cterm03, cterm01, "none", "")
Hi("TabLineSel",    gui0B, gui01, cterm0B, cterm01, "none", "")

# Standard syntax highlighting
Hi("Boolean",      gui09, "", cterm09, "", "", "")
Hi("Character",    gui08, "", cterm08, "", "", "")
# Comment: "" -> italic
if !empty(g:base16#enable_italics)
  Hi("Comment",      gui03, "", cterm03, "", "italic", "")
else
  Hi("Comment",      gui03, "", cterm03, "", "", "")
endif
Hi("Conditional",  gui0E, "", cterm0E, "", "", "")
Hi("Constant",     gui09, "", cterm09, "", "", "")
Hi("Define",       gui0E, "", cterm0E, "", "none", "")
Hi("Delimiter",    gui0F, "", cterm0F, "", "", "")
Hi("Float",        gui09, "", cterm09, "", "", "")
Hi("Function",     gui0D, "", cterm0D, "", "", "")
Hi("Identifier",   gui08, "", cterm08, "", "none", "")
Hi("Include",      gui0D, "", cterm0D, "", "", "")
Hi("Keyword",      gui0E, "", cterm0E, "", "", "")
Hi("Label",        gui0A, "", cterm0A, "", "", "")
Hi("Number",       gui09, "", cterm09, "", "", "")
Hi("Operator",     gui05, "", cterm05, "", "none", "")
Hi("PreProc",      gui0A, "", cterm0A, "", "", "")
Hi("Repeat",       gui0A, "", cterm0A, "", "", "")
Hi("Special",      gui0C, "", cterm0C, "", "", "")
Hi("SpecialChar",  gui0F, "", cterm0F, "", "", "")
Hi("Statement",    gui08, "", cterm08, "", "", "")
Hi("StorageClass", gui0A, "", cterm0A, "", "", "")
Hi("String",       gui0B, "", cterm0B, "", "", "")
Hi("Structure",    gui0E, "", cterm0E, "", "", "")
Hi("Tag",          gui0A, "", cterm0A, "", "", "")
Hi("Todo",         gui0A, gui01, cterm0A, cterm01, "", "")
Hi("Type",         gui0A, "", cterm0A, "", "none", "")
Hi("Typedef",      gui0A, "", cterm0A, "", "", "")

# C highlighting
Hi("cOperator",   gui0C, "", cterm0C, "", "", "")
Hi("cPreCondit",  gui0E, "", cterm0E, "", "", "")

# C# highlighting
Hi("csClass",                 gui0A, "", cterm0A, "", "", "")
Hi("csAttribute",             gui0A, "", cterm0A, "", "", "")
Hi("csModifier",              gui0E, "", cterm0E, "", "", "")
Hi("csType",                  gui08, "", cterm08, "", "", "")
Hi("csUnspecifiedStatement",  gui0D, "", cterm0D, "", "", "")
Hi("csContextualStatement",   gui0E, "", cterm0E, "", "", "")
Hi("csNewDecleration",        gui08, "", cterm08, "", "", "")

# CSS highlighting
Hi("cssBraces",      gui05, "", cterm05, "", "", "")
Hi("cssClassName",   gui0E, "", cterm0E, "", "", "")
Hi("cssColor",       gui0C, "", cterm0C, "", "", "")

# Diff highlighting
Hi("DiffAdd",      gui0B, gui01,  cterm0B, cterm01, "", "")
Hi("DiffChange",   gui03, gui01,  cterm03, cterm01, "", "")
Hi("DiffDelete",   gui08, gui01,  cterm08, cterm01, "", "")
Hi("DiffText",     gui0D, gui01,  cterm0D, cterm01, "", "")
Hi("DiffAdded",    gui0B, gui00,  cterm0B, cterm00, "", "")
Hi("DiffFile",     gui08, gui00,  cterm08, cterm00, "", "")
Hi("DiffNewFile",  gui0B, gui00,  cterm0B, cterm00, "", "")
Hi("DiffLine",     gui0D, gui00,  cterm0D, cterm00, "", "")
Hi("DiffRemoved",  gui08, gui00,  cterm08, cterm00, "", "")

# Git highlighting
Hi("gitcommitOverflow",       gui08, "", cterm08, "", "", "")
Hi("gitcommitSummary",        gui0B, "", cterm0B, "", "", "")
Hi("gitcommitComment",        gui03, "", cterm03, "", "", "")
Hi("gitcommitUntracked",      gui03, "", cterm03, "", "", "")
Hi("gitcommitDiscarded",      gui03, "", cterm03, "", "", "")
Hi("gitcommitSelected",       gui03, "", cterm03, "", "", "")
Hi("gitcommitHeader",         gui0E, "", cterm0E, "", "", "")
Hi("gitcommitSelectedType",   gui0D, "", cterm0D, "", "", "")
Hi("gitcommitUnmergedType",   gui0D, "", cterm0D, "", "", "")
Hi("gitcommitDiscardedType",  gui0D, "", cterm0D, "", "", "")
Hi("gitcommitBranch",         gui09, "", cterm09, "", "bold", "")
Hi("gitcommitUntrackedFile",  gui0A, "", cterm0A, "", "", "")
Hi("gitcommitUnmergedFile",   gui08, "", cterm08, "", "bold", "")
Hi("gitcommitDiscardedFile",  gui08, "", cterm08, "", "bold", "")
Hi("gitcommitSelectedFile",   gui0B, "", cterm0B, "", "bold", "")

# GitGutter highlighting
Hi("GitGutterAdd",     gui0B, gui01, cterm0B, cterm01, "", "")
Hi("GitGutterChange",  gui0D, gui01, cterm0D, cterm01, "", "")
Hi("GitGutterDelete",  gui08, gui01, cterm08, cterm01, "", "")
Hi("GitGutterChangeDelete",  gui0E, gui01, cterm0E, cterm01, "", "")

# HTML highlighting
Hi("htmlBold",    gui0A, "", cterm0A, "", "", "")
Hi("htmlItalic",  gui0E, "", cterm0E, "", "", "")
Hi("htmlEndTag",  gui05, "", cterm05, "", "", "")
Hi("htmlTag",     gui05, "", cterm05, "", "", "")

# JavaScript highlighting
Hi("javaScript",        gui05, "", cterm05, "", "", "")
Hi("javaScriptBraces",  gui05, "", cterm05, "", "", "")
Hi("javaScriptNumber",  gui09, "", cterm09, "", "", "")
# pangloss/vim-javascript highlighting
Hi("jsOperator",          gui0D, "", cterm0D, "", "", "")
Hi("jsStatement",         gui0E, "", cterm0E, "", "", "")
Hi("jsReturn",            gui0E, "", cterm0E, "", "", "")
Hi("jsThis",              gui08, "", cterm08, "", "", "")
Hi("jsClassDefinition",   gui0A, "", cterm0A, "", "", "")
Hi("jsFunction",          gui0E, "", cterm0E, "", "", "")
Hi("jsFuncName",          gui0D, "", cterm0D, "", "", "")
Hi("jsFuncCall",          gui0D, "", cterm0D, "", "", "")
Hi("jsClassFuncName",     gui0D, "", cterm0D, "", "", "")
Hi("jsClassMethodType",   gui0E, "", cterm0E, "", "", "")
Hi("jsRegexpString",      gui0C, "", cterm0C, "", "", "")
Hi("jsGlobalObjects",     gui0A, "", cterm0A, "", "", "")
Hi("jsGlobalNodeObjects", gui0A, "", cterm0A, "", "", "")
Hi("jsExceptions",        gui0A, "", cterm0A, "", "", "")
Hi("jsBuiltins",          gui0A, "", cterm0A, "", "", "")

# Mail highlighting
Hi("mailQuoted1",  gui0A, "", cterm0A, "", "", "")
Hi("mailQuoted2",  gui0B, "", cterm0B, "", "", "")
Hi("mailQuoted3",  gui0E, "", cterm0E, "", "", "")
Hi("mailQuoted4",  gui0C, "", cterm0C, "", "", "")
Hi("mailQuoted5",  gui0D, "", cterm0D, "", "", "")
Hi("mailQuoted6",  gui0A, "", cterm0A, "", "", "")
Hi("mailURL",      gui0D, "", cterm0D, "", "", "")
Hi("mailEmail",    gui0D, "", cterm0D, "", "", "")

# Markdown highlighting
Hi("markdownCode",              gui0B, "", cterm0B, "", "", "")
Hi("markdownError",             gui05, gui00, cterm05, cterm00, "", "")
Hi("markdownCodeBlock",         gui0B, "", cterm0B, "", "", "")
Hi("markdownHeadingDelimiter",  gui0D, "", cterm0D, "", "", "")

# NERDTree highlighting
Hi("NERDTreeDirSlash",  gui0D, "", cterm0D, "", "", "")
Hi("NERDTreeExecFile",  gui05, "", cterm05, "", "", "")

# PHP highlighting
Hi("phpMemberSelector",  gui05, "", cterm05, "", "", "")
Hi("phpComparison",      gui05, "", cterm05, "", "", "")
Hi("phpParent",          gui05, "", cterm05, "", "", "")
Hi("phpMethodsVar",      gui0C, "", cterm0C, "", "", "")

# Python highlighting
Hi("pythonOperator",  gui0E, "", cterm0E, "", "", "")
Hi("pythonRepeat",    gui0E, "", cterm0E, "", "", "")
Hi("pythonInclude",   gui0E, "", cterm0E, "", "", "")
Hi("pythonStatement", gui0E, "", cterm0E, "", "", "")

# Ruby highlighting
Hi("rubyAttribute",               gui0D, "", cterm0D, "", "", "")
Hi("rubyConstant",                gui0A, "", cterm0A, "", "", "")
Hi("rubyInterpolationDelimiter",  gui0F, "", cterm0F, "", "", "")
Hi("rubyRegexp",                  gui0C, "", cterm0C, "", "", "")
Hi("rubySymbol",                  gui0B, "", cterm0B, "", "", "")
Hi("rubyStringDelimiter",         gui0B, "", cterm0B, "", "", "")

# SASS highlighting
Hi("sassidChar",     gui08, "", cterm08, "", "", "")
Hi("sassClassChar",  gui09, "", cterm09, "", "", "")
Hi("sassInclude",    gui0E, "", cterm0E, "", "", "")
Hi("sassMixing",     gui0E, "", cterm0E, "", "", "")
Hi("sassMixinName",  gui0D, "", cterm0D, "", "", "")

# Signify highlighting
Hi("SignifySignAdd",     gui0B, gui01, cterm0B, cterm01, "", "")
Hi("SignifySignChange",  gui0D, gui01, cterm0D, cterm01, "", "")
Hi("SignifySignDelete",  gui08, gui01, cterm08, cterm01, "", "")

# Spelling highlighting
Hi("SpellBad",     "", "", "", "", "undercurl", gui08)
Hi("SpellLocal",   "", "", "", "", "undercurl", gui0C)
Hi("SpellCap",     "", "", "", "", "undercurl", gui0D)
Hi("SpellRare",    "", "", "", "", "undercurl", gui0E)

# Startify highlighting
Hi("StartifyBracket",  gui03, "", cterm03, "", "", "")
Hi("StartifyFile",     gui07, "", cterm07, "", "", "")
Hi("StartifyFooter",   gui03, "", cterm03, "", "", "")
Hi("StartifyHeader",   gui0B, "", cterm0B, "", "", "")
Hi("StartifyNumber",   gui09, "", cterm09, "", "", "")
Hi("StartifyPath",     gui03, "", cterm03, "", "", "")
Hi("StartifySection",  gui0E, "", cterm0E, "", "", "")
Hi("StartifySelect",   gui0C, "", cterm0C, "", "", "")
Hi("StartifySlash",    gui03, "", cterm03, "", "", "")
Hi("StartifySpecial",  gui03, "", cterm03, "", "", "")

# Java highlighting
Hi("javaOperator",     gui0D, "", cterm0D, "", "", "")

# vim:ft=vim sw=2 fdm=marker
