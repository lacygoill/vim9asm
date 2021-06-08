vim9script

# Options {{{1

&l:foldmethod = 'expr'
&l:foldexpr = 'vim9asm#foldexpr(v:lnum)'
&l:foldtext = 'vim9asm#foldtext(v:lnum)'
&l:foldminlines = 0

&l:buftype = 'nofile'
&l:modifiable = false
&l:swapfile = false
&l:readonly = true

# Mappings {{{1

nnoremap <buffer><nowait> <c-]> <cmd>call vim9asm#disassembleFunctionUnderCursor()<cr>
nnoremap <buffer><nowait> <c-t> <cmd>call vim9asm#popFuncFromStack()<cr>

# Commands {{{1

command -bar -bang -buffer Vim9asmFocus vim9asm#focus(<bang>0)
command -bar -bang -buffer Vim9asmHint vim9asm#hint(<bang>0)

# Teardown {{{1

b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    .. '| set buftype< foldexpr< foldmethod< foldminlines< foldtext< modifiable< readonly< swapfile<'
    .. '| exe "nunmap <buffer> <c-]>"'
    .. '| exe "nunmap <buffer> <c-t>"'
    .. '| delcommand Vim9asmFocus'
    .. '| delcommand Vim9asmHint'

