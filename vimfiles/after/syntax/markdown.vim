vim9script

# checkbox
hi link CheckboxUnchecked Type
hi link CheckboxChecked Comment
syn match CheckboxUnchecked '\v^\s*- \[ \] '
syn match CheckboxChecked '\v^\s*- \[X\] '

# markdown ``` `` ``` hl fix. TODO: not work
#syn region markdownCode matchgroup=markdownCodeDelimiter start=/.\+\zs```/ end=/.\+\zs```/

syntax region markdownQuestion start='\v<Q:' end='\v(\n(^((\s*-)|([0-9]+\.)) .+|)\n)@=' | hi link markdownQuestion Error
syntax region markdownToday start='\v<T:' end='\v(\n(^((\s*-)|([0-9]+\.)) .+|)\n)@=' | hi link markdownToday TODO
syntax region markdownLowPriority start='\v<L:' end='\v(\n(^((\s*-)|([0-9]+\.)) .+|)\n)@=' | hi link markdownLowPriority Comment

hi def StrikeoutColor ctermfg=grey guifg=grey cterm=strikethrough gui=strikethrough
syntax match StrikeoutMatch /\~\~.*\~\~/
hi link StrikeoutMatch StrikeoutColor

syntax match Todo /\v(^|\W)\zsTODO\ze(\W|$)/
