vim9script

# Options {{{1

setlocal foldmethod=expr
setlocal foldexpr=vim9asm#foldexpr(v:lnum)
setlocal foldtext=vim9asm#foldtext(v:lnum)

setlocal buftype=nofile nomodifiable noswapfile readonly

# Commands {{{1

command -bar -bang -buffer Vim9asmFocus vim9asm#focus(<bang>0)
command -bar -bang -buffer Vim9asmHint vim9asm#hint(<bang>0)

# Teardown {{{1

b:undo_ftplugin = get(b:, 'undo_ftplugin', 'execute')
    .. '| set buftype< foldexpr< foldmethod< foldtext< modifiable< readonly< swapfile<'
    .. '| delcommand Vim9asmFocus'
    .. '| delcommand Vim9asmHint'

