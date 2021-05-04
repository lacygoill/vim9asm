vim9script noclear

# Config {{{1

const autofocus: bool = get(g:, 'vim9asm', {})->get('autofocus', false)
const autohint: bool = get(g:, 'vim9asm', {})->get('autohint', false)

const POPUP_OPTS: dict<any> = {
    highlight: 'Pmenu',
    border: [],
    borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
}
    # take into consideration possible user config
    ->extend(get(g:, 'vim9asm', {})->get('hint', {}))

const HEADERFILE: string = $HOME .. '/Vcs/vim/src/vim9.h'

# Init {{{1

const USAGE: list<string> =<< trim END
    usage:
        # display instructions in new horizontal split window
        :Disassemble MyCompiledFunctionName

        # include instructions for profiling
        :Disassemble! MyCompiledFunctionName

        # display instructions in new vertical split window
        :vertical Disassemble MyCompiledFunctionName

        # display instructions in new tab page
        :tab Disassemble MyCompiledFunctionName
END

var INST2HINT: dict<string>
if filereadable(HEADERFILE)
    def GetHints()
        var lines: list<string> = readfile(HEADERFILE)
        var get_ins_name: string = '^\C\s*\zs[A-Z_0-9]\+'
        var get_hint: string = '//\s*\zs.*'
        var i: number
        for line in lines
            if line =~ get_ins_name
                var hint: string = line->matchstr(get_hint)
                # The hint could continue on the next line(s).
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
                INST2HINT[line->matchstr(get_ins_name)] = hint
            endif
            ++i
        endfor
        INST2HINT->filter((_, v: string): bool => v =~ '\S')
    enddef
    GetHints()
else
    import HINTS from '../import/vim9asm.vim'
    INST2HINT = HINTS
endif
lockvar! INST2HINT

const LHS2NORM: dict<string> = {
    j: 'j',
    k: 'k',
    '<down>': "\<down>",
    '<up>': "\<up>",
    '<c-d>': "\<c-d>",
    '<c-u>': "\<c-u>",
    gg: 'gg',
    G: 'G',
}

# Functions {{{1
# Interface {{{2
def vim9asm#disassemble(funcname: string, bang: string, mods: string) #{{{3
    if funcname->empty()
        echo USAGE->join("\n")
        return
    endif
    var name: string = funcname->trim('()')
    if bufexists(name)
        var buf: number = bufnr(name)
        var winid: number = buf
            ->win_findbuf()
            ->get(0)
        if winid != 0
            win_gotoid(winid)
        else
            exe mods .. ' new'
            exe 'b ' .. buf
        endif
        return
    endif
    var lines: list<string>
    try
        lines = execute('disa' .. bang .. ' ' .. name)->split('\n')
    catch
        Error(v:exception)
        return
    endtry
    if empty(lines)
        return
    endif
    exe mods .. ' new'
    setline(1, lines)
    setf vim9asm
    if autofocus
        # `:exe` is necessary to suppress an error at compile time.
        # The command is only installed in a vim9asm buffer.
        exe 'Vim9asmFocus'
    endif
    if autohint
        exe 'Vim9asmHint'
    endif
    exe 'file ' .. name->fnameescape()
enddef

def vim9asm#focus(disable: bool) #{{{3
    var maparg: dict<any> = maparg('j', 'n', false, true)
    if !disable && (maparg->empty() || !maparg.buffer)
        if foldclosed('.') >= 0
            norm! zvzz
        endif
        for lhs in keys(LHS2NORM)
            exe printf(
                'nno <buffer><nowait> %s <cmd>call <sid>MoveAndOpenFold(%s, %d)<cr>',
                    lhs,
                    lhs->substitute('^<\([^>]*>\)$', '<lt>\1', '')->string(),
                    v:count,
            )
        endfor
    elseif disable && !maparg->empty()
        for lhs in keys(LHS2NORM)
            exe 'sil! nunmap <buffer> ' .. lhs
        endfor
    endif
enddef

def vim9asm#hint(disable: bool) #{{{3
    if disable
        sil! au! Vim9asmHint * <buffer>

    elseif !disable
        augroup Vim9asmHint
            au! * <buffer>
            au CursorMoved <buffer> GiveHint()
        augroup END
    endif
enddef

def vim9asm#foldexpr(lnum: number): string #{{{3
    var curline: string = getline(lnum)
    var prevline: string = getline(lnum - 1)

    # The second line is a special case.{{{
    #
    # Usually, it's a Vim script line of code from the original function.
    # However, it  might be a compiled  instruction if the header  contains some
    # special syntax, like an optional argument:
    #
    #     def Func(x = 0)
    #              ^---^
    #}}}
    if lnum == 2 && getline(2) !~ '^\s\+\d\+\s\+[A-Z_0-9]\+'
      || prevline == '' && curline != ''
    # Special case necessary to handle several consecutive  `:end*` statements.{{{
    #
    # E.g.,  without, the  original source  code contains  2 `endif`,  the first
    # would start a fold, but not the second one.
    # We need the 2nd  `endif` to also start a fold, because we  want to see the
    # complete source code when the buffer is folded.
    #}}}
      || curline =~ '^\C\s*end\%(def\|for\|if\|try\|while\)$'
        return '>1'
    endif

    return '='
enddef

def vim9asm#foldtext(lnum: number): string #{{{3
    var title: string = getline(v:foldstart)
    if title =~ '^\s*#'
        var i: number = v:foldstart + 1
        while i <= line('$')
            title = getline(i)
            if title !~ '^\s*#'
                return title
            endif
            ++i
        endwhile
    endif
    return title
enddef
#}}}2
# Core {{{2
def GiveHint() #{{{3
    if NothingUnderCursor() || PopupIsOpen()
        return
    endif
    var name: string = expand('<cword>')->substitute('^\d\+\s\+', '', '')
    if INST2HINT->has_key(name)
        popup_atcursor(INST2HINT[name], POPUP_OPTS)
    elseif INST2HINT->has_key('ISN_' .. name)
        popup_atcursor(INST2HINT['ISN_' .. name], POPUP_OPTS)
    endif
enddef

def MoveAndOpenFold(lhs: string, cnt: number) #{{{3
    var old_foldlevel: number = foldlevel('.')
    var old_winline: number = winline()
    if lhs == 'j' || lhs == '<down>'
        norm! gj
        if getline('.') =~ '^#\+$'
            return
        endif
        var is_in_a_closed_fold: bool = foldclosed('.') >= 0
        var new_foldlevel: number = foldlevel('.')
        var level_changed: bool = new_foldlevel != old_foldlevel
        if is_in_a_closed_fold || level_changed
            norm! zMzv
        endif
    elseif lhs == 'k' || lhs == '<up>'
        norm! gk
        if getline('.') =~ '^#\+$'
            return
        endif
        var is_in_a_closed_fold: bool = foldclosed('.') >= 0
        var new_foldlevel: number = foldlevel('.')
        var level_changed: bool = new_foldlevel != old_foldlevel
        if is_in_a_closed_fold || level_changed
            sil! norm! gjzRgkzMzv
        endif
    else
        exe 'sil! norm! zR'
            .. (cnt != 0 ? cnt : '')
            .. LHS2NORM[lhs] .. 'zMzv'
    endif
enddef
#}}}2
# Util {{{2
def Error(msg: string) #{{{3
    echohl msg
    echom msg
    echohl NONE
enddef

def NothingUnderCursor(): bool #{{{3
    return getline('.')[charcol('.') - 1] =~ '\s'
enddef

def PopupIsOpen(): bool #{{{3
    return popup_list()
        ->map((_, v: number): number => v
                                        ->popup_getoptions().moved
                                        ->get(0))
        ->index(line('.')) >= 0
enddef

