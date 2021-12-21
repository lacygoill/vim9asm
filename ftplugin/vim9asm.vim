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

nnoremap <buffer><nowait> <C-]> <Cmd>call vim9asm#disassembleFunctionUnderCursor()<CR>
nnoremap <buffer><nowait> <C-T> <Cmd>call vim9asm#popFuncFromStack()<CR>

# Commands {{{1

command -bar -bang -buffer Vim9asmFocus vim9asm#focus(<bang>0)
command -bar -bang -buffer Vim9asmHint vim9asm#hint(<bang>0)

# Teardown {{{1

b:undo_ftplugin = get(b:, 'undo_ftplugin', 'execute')
    .. '| set buftype< foldexpr< foldmethod< foldminlines< foldtext< modifiable< readonly< swapfile<'
    .. '| execute "nunmap <buffer> <C-]>"'
    .. '| execute "nunmap <buffer> <C-T>"'
    .. '| delcommand Vim9asmFocus'
    .. '| delcommand Vim9asmHint'
