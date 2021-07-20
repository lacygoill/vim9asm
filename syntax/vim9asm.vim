vim9script

if exists('b:current_syntax')
    finish
endif

syntax match vim9asmFuncname /^\%1l.*/ display

syntax match vim9asmInsIndex /^\s*\d\+/ nextgroup=vim9asmInsName skipwhite display
syntax match vim9asmInsName /[A-Z_0-9]\+/ contained nextgroup=vim9asmInsArguments skipwhite display
syntax match vim9asmInsArguments /.*/ contained display

syntax match vim9asmComment /^\s*#.*/ display

highlight default link vim9asmFuncname Title
highlight default link vim9asmInsIndex Number
highlight default link vim9asmInsName Statement
highlight default link vim9asmInsArguments MoreMsg
highlight default link vim9asmComment Comment

b:current_syntax = 'vim9asm'
