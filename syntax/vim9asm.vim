vim9script

if exists('b:current_syntax')
    finish
endif

syn match vim9asmFuncname /^\%1l.*/ display

syn match vim9asmInsIndex /^\s*\d\+/ nextgroup=vim9asmInsName skipwhite display
syn match vim9asmInsName /[A-Z_0-9]\+/ contained nextgroup=vim9asmInsArguments skipwhite display
syn match vim9asmInsArguments /.*/ contained display

syn match vim9asmComment /^\s*#.*/ display

hi def link vim9asmFuncname Title
hi def link vim9asmInsIndex Number
hi def link vim9asmInsName Statement
hi def link vim9asmInsArguments MoreMsg
hi def link vim9asmComment Comment

b:current_syntax = 'vim9asm'
