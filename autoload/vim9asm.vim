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

import HINTS from '../import/hints.vim'

const TRANSLATED: dict<string> = {
    j: 'j',
    k: 'k',
    '<down>': "\<down>",
    '<up>': "\<up>",
    '<c-d>': "\<c-d>",
    '<c-u>': "\<c-u>",
    gg: 'gg',
    G: 'G',
}

const VIMSCRIPT_LINE: string =
       '^\%(\s*\%('
            # a Vim9 generated instruction
    ..     '\d\+\s\+[A-Z_0-9]\+'
    .. '\|'
            # or a Vim9 comment
    ..     '#'
    .. '\)\)'
       # we don't want to start a fold on any of those
    .. '\@!'
       # and we don't want to start a fold on an empty line
    .. '.'

var func_stacks: dict<list<number>>

# Functions {{{1
# Interface {{{2
def vim9asm#complete(arglead: string, _, _): list<string> #{{{3
    return arglead
        ->substitute('^\Cs:', '<SNR>*', '')
        ->getcompletion('function')
        ->filter((_, v: string): bool => v !~ '^\l' || v =~ '#')
        + ['debug', 'profile']
        ->filter((_, v: string): bool => v =~ '^' .. arglead)
enddef

def vim9asm#disassemble( #{{{3
    args: string,
    mods: string
)
    if args->empty()
        echo USAGE->join("\n")
        return
    endif

    # normalize the  buffer name so that  we can reliably determine  whether its
    # instructions are already displayed somewhere
    var bufname: string = args->substitute('()\=$', '', '') .. '()'
    # special case, we've already disassembled the function
    if bufexists(bufname)
        var buf: number = bufnr(bufname)
        var winid: number = buf
            ->win_findbuf()
            ->get(0)
        if winid != 0
            win_gotoid(winid)
        else
            # We don't want `SplitWindow()` to run `:enew` here (it would create
            # a useless empty buffer, which would break `C-^`).
            if mods != 'nosplit'
                SplitWindow(mods)
            endif
            exe 'b ' .. buf
            PushFuncOnStack()
        endif
        return
    endif

    var instructions: list<string>
    try
        instructions = execute('disa' .. ' ' .. args)->split('\n')
    # E1061: Cannot find function Funcname
    catch /^Vim\%((\a\+)\)\=:E1061:/
        # If `:Disa` was executed from  a script, rather than interactively from
        # the command-line, we should retry  after looking for "Funcname" in the
        # script namespace.
        instructions = RetryAsLocalFunction(args)
        if instructions->empty()
            Error(v:exception)
            return
        endif
    catch
        Error(v:exception)
        return
    endtry

    if instructions->empty()
        return
    endif

    SplitWindow(mods)
    instructions->setline(1)
    setf vim9asm
    if autofocus
        # `:exe` is necessary to suppress an error at compile time.
        # The command is only installed in a vim9asm buffer.
        exe 'Vim9asmFocus'
    endif
    if autohint
        exe 'Vim9asmHint'
    endif
    exe 'file ' .. bufname->fnameescape()
    PushFuncOnStack()
enddef

def vim9asm#disassembleFunctionUnderCursor() #{{{3
    var col: number = col('.')
    var cursor_is_after: string = '\%<' .. (col + 1) .. 'c'
    var cursor_is_before: string = '\%>' .. col .. 'c'

    var Im_here: string = '[^ (]\+'
    var defcall: string = '^\s*\d\+\s\+\CDCALL\s\+'
        .. '\zs' .. cursor_is_after .. Im_here .. cursor_is_before

    Im_here = '<lambda>\d\+\>'
    var lambda: string =
        cursor_is_after .. '\C' .. Im_here .. cursor_is_before

    var curline: string = getline('.')
    if curline =~ lambda
        curline
            ->matchstr(lambda)
            ->vim9asm#disassemble('', 'nosplit')
    elseif curline =~ defcall
        curline
            ->matchstr(defcall)
            ->vim9asm#disassemble('', 'nosplit')
    endif
enddef

def vim9asm#focus(disable: bool) #{{{3
    var maparg: dict<any> = maparg('j', 'n', false, true)
    if !disable && (maparg->empty() || !maparg.buffer)
        if foldclosed('.') >= 0
            norm! zvzz
        endif
        for lhs in keys(TRANSLATED)
            exe printf(
                'nno <buffer><nowait> %s <cmd>call <sid>MoveAndOpenFold(%s, %d)<cr>',
                    lhs,
                    lhs->substitute('^<\([^>]*>\)$', '<lt>\1', '')->string(),
                    v:count,
            )
        endfor
    elseif disable && !maparg->empty()
        for lhs in keys(TRANSLATED)
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
    return getline(lnum) =~ VIMSCRIPT_LINE ? '>1' : '='
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

def vim9asm#popFuncFromStack() #{{{3
    var winid: number = win_getid()
    if !func_stacks->has_key(winid)
    # `->empty()` is not enough.  We really need `->len() <= 1`.{{{
    #
    # Otherwise, when pressing  `C-t` while at the bottom of  the stack (i.e. in
    # the  first disassembled  function), the  next `remove()`  would empty  the
    # stack.  Because of that, later, after pressing `C-]`, you wouldn't be able
    # to return to the first function.
    #}}}
    || func_stacks[winid]->len() <= 1
        Error('at bottom of function stack')
        return
    endif
    func_stacks[winid]->remove(-1)
    exe 'b ' .. func_stacks[winid][-1]
enddef
#}}}2
# Core {{{2
def PushFuncOnStack() #{{{3
    var winid: number = win_getid()
    if !func_stacks->has_key(winid)
        func_stacks->extend({[winid]: []})
    endif
    func_stacks[winid] += [bufnr('%')]
enddef

def RetryAsLocalFunction(args: string): list<string> #{{{3
    var funcname: string = args
        ->substitute('^\%(debug\|profile\)\s\+\|($\|()$', '', 'g')

    if funcname =~ ':' && funcname !~ '^s:'
        return []
    endif

    var basename: string = funcname->substitute('^s:', '', '')
    # list of function names matching the one we're looking for
    var fullnames: list<string> = getcompletion('*' .. basename .. '(', 'function')
    # path to the script from where `:Disa` has been executed
    var calling_script: string = GetCallingScript()
    var full_funcname: string = fullnames
        # the function we're looking for *must* have been defined in the calling script
        ->filter((_, v: string): bool => v->GetFuncScript() == calling_script)
        ->get(0, '')
    if full_funcname !~ '^<SNR>\d\+_' .. basename .. '('
        return []
    endif
    var instructions: list<string>
    try
        var debug_or_profile: string = args->matchstr('^\%(debug\|profile\)\ze\s')
        instructions = printf('disa %s %s', debug_or_profile, full_funcname)
            ->execute()
            ->split('\n')
    catch
        return []
    endtry
    return instructions
enddef

def GiveHint() #{{{3
    if NothingUnderCursor() || PopupIsOpen()
        return
    endif
    var instruction: string = expand('<cword>')->substitute('^\d\+\s\+', '', '')
    if HINTS->has_key(instruction)
        popup_atcursor(HINTS[instruction], POPUP_OPTS)
    elseif HINTS->has_key('ISN_' .. instruction)
        popup_atcursor(HINTS['ISN_' .. instruction], POPUP_OPTS)
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
            .. TRANSLATED[lhs] .. 'zMzv'
    endif
enddef
#}}}2
# Util {{{2
def SplitWindow(mods: string) #{{{3
    if mods == 'nosplit'
        enew
    else
        exe mods .. ' new'
    endif
enddef

def GetCallingScript(): string #{{{3
    var calls: list<string> = expand('<stack>')
        ->split('\.\.')
    return calls
        ->get(calls->match('\C\<vim9asm#disassemble\>') - 1, '')
        ->matchstr('\S\+\ze\[\d\+\]$')
enddef

def GetFuncScript(funcname: string): string #{{{3
    return execute('verb def ' .. funcname->trim('()'))
        ->split('\n')
        ->get(1, '')
        ->matchstr('^\s*Last set from \zs\S\+')
        ->substitute('^\~/', $HOME .. '/', '')
enddef

def Error(msg: string) #{{{3
    # `:h :echo-redraw`
    redraw
    echohl ErrorMsg
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

