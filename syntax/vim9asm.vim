if exists('b:current_syntax')
    finish
endif

syn match vim9asmFuncname /^\S.*/ display

syn match vim9asmInsIndex /^\s*\d\+/ nextgroup=vim9asmInsName skipwhite display
syn match vim9asmInsName /[A-Z_0-9]\+/ contained nextgroup=vim9asmInsArguments skipwhite display
syn match vim9asmInsArguments /.*/ contained display

syn match vim9asmComment /^\s\+#.*/ display

hi link vim9asmFuncname Title
hi link vim9asmInsIndex Number
hi link vim9asmInsName Statement
hi link vim9asmInsArguments MoreMsg
hi link vim9asmComment Comment

let b:current_syntax = 'vim9asm'
