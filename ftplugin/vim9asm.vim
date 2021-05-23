vim9script

# Options {{{1

setlocal foldmethod=expr
setlocal foldexpr=vim9asm#foldexpr(v:lnum)
setlocal foldtext=vim9asm#foldtext(v:lnum)

setlocal buftype=nofile nomodifiable noswapfile readonly

# Mappings {{{1

nnoremap <buffer><nowait> <c-]> <cmd>call vim9asm#disassembleFunctionUnderCursor()<cr>
nnoremap <buffer><nowait> <c-t> <cmd>call vim9asm#popFuncFromStack()<cr>

# Commands {{{1

command -bar -bang -buffer Vim9asmFocus vim9asm#focus(<bang>0)
command -bar -bang -buffer Vim9asmHint vim9asm#hint(<bang>0)

# Teardown {{{1

b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    .. '| set buftype< foldexpr< foldmethod< foldtext< modifiable< readonly< swapfile<'
    .. '| exe "nunmap <buffer> <c-]>"'
    .. '| exe "nunmap <buffer> <c-t>"'
    .. '| delcommand Vim9asmFocus'
    .. '| delcommand Vim9asmHint'

