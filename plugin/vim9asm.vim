vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

command -bar -nargs=* -complete=customlist,vim9asm#complete Disassemble
    \ vim9asm#disassemble(<q-args>, <q-mods>)
