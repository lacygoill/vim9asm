vim9script

import autoload 'vim9asm.vim'

# Options {{{1

&l:foldmethod = 'expr'
&l:foldexpr = 'vim9asm.FoldExpr(v:lnum)'
&l:foldtext = 'vim9asm.FoldText(v:lnum)'
&l:foldminlines = 0

&l:buftype = 'nofile'
&l:modifiable = false
&l:swapfile = false
&l:readonly = true

# Mappings {{{1

nnoremap <buffer><nowait> <C-]> <ScriptCmd>vim9asm.DisassembleFunctionUnderCursor()<CR>
nnoremap <buffer><nowait> <C-T> <ScriptCmd>vim9asm.PopFuncFromStack()<CR>

# Commands {{{1

command -bar -bang -buffer Vim9asmFocus vim9asm.Focus(<bang>0)
command -bar -bang -buffer Vim9asmHint vim9asm.Hint(<bang>0)

# Teardown {{{1

b:undo_ftplugin = get(b:, 'undo_ftplugin', 'execute')
    .. '| set buftype< foldexpr< foldmethod< foldminlines< foldtext< modifiable< readonly< swapfile<'
    .. '| execute "nunmap <buffer> <C-]>"'
    .. '| execute "nunmap <buffer> <C-T>"'
    .. '| delcommand Vim9asmFocus'
    .. '| delcommand Vim9asmHint'
