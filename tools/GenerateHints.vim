vim9script noclear

const HEADERFILE: string = $HOME .. '/Vcs/vim/src/vim9.h'
if !HEADERFILE->filereadable()
    echom printf('cannot read Vim9 header file at: %s', HEADERFILE)
    finish
endif

const IMPORT_FILEPATH: string = expand('<sfile>:p:h:h') .. '/import/hints.vim'

def WriteImportFile()
    # extract the hints from the Vim9 header file
    var lines: list<string> = HEADERFILE->readfile()
    var hints: dict<string>
    var get_ins_name: string = '^\C\s*\zs[A-Z_0-9]\+'
    var get_hint: string = '//\s*\zs.*'
    var i: number
    for line in lines
        if line =~ get_ins_name
            var hint: string = line->matchstr(get_hint)
            # the hint could continue on the next line(s)
            var get_continuation: string = '^\C\s*//\%(\s*[A-Z_0-9]\+\)\@!\s*\zs\s.*'
            var j: number = i + 1
            while lines[j] =~ get_continuation
                hint ..= lines[j]->matchstr(get_continuation)
                ++j
            endwhile
            if hint !~ '\S'
                var jj: number = i - 1
                while jj > 0
                    if lines[jj] =~ '^\s*//'
                        hint = lines[jj]->matchstr(get_hint)
                        break
                    endif
                    --jj
                endwhile
            endif
            hints[line->matchstr(get_ins_name)] = hint
        endif
        ++i
    endfor
    hints->filter((_, v: string): bool => v =~ '\S')

    # write the hints
    [hints->string()]->writefile(IMPORT_FILEPATH)
    exe 'e ' .. IMPORT_FILEPATH

    # break dictionary after the opening `{`
    :1/^\%x7b/ s/{\zs\ze'/\r/
    # break each item in dictionary on a separate line
    :s/',\zs \ze'/\r/g
    # break dictionary before the closing `}`
    :$ s/'\zs\ze}/,\r/
    # indent dictionary items
    :1/^{$/+,$?^}$?- s/^/    /
    # remove quotes around dictionary keys
    :'[,'] s/'\([^']*\)'/\1/
    # sort keys
    :'[,'] sort

    # turn file into a Vim9 script
    ['vim9script noclear', '']->append(0)
    # assign dictionary to importable item
    :1/\%x7b/ s/^/export const HINTS: dict<string> = /
    # write the import file
    update
enddef

silent WriteImportFile()
