vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

import autoload '../autoload/vim9asm.vim'

command -bar -nargs=* -complete=customlist,vim9asm.Complete Disassemble {
    vim9asm.Disassemble(<q-args>, <q-mods>)
}
