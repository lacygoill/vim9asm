vim9script noclear

# Config {{{1

const autofocus: bool = get(g:, 'vim9asm', {})->get('autofocus', false)
const autohint: bool = get(g:, 'vim9asm', {})->get('autohint', false)
const hint_type: string = get(g:, 'vim9asm', {})->get('hint_type', 'popup')

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

import '../import/hints.vim'
const HINTS: dict<string> = hints.HINTS
var last_hints_impl: string  # how are hints currently implemented (popup vs virtual)

const TRANSLATED: dict<string> = {
    j: 'j',
    k: 'k',
    '<Down>': "\<Down>",
    '<Up>': "\<Up>",
    '<C-D>': "\<C-D>",
    '<C-U>': "\<C-U>",
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
export def Complete(arglead: string, _, _): list<string> #{{{3
    # Note that `:disassemble` accepts wildcards like `*` and `?`.
    # See `:help file-pattern`.
    return getcompletion($'disassemble {arglead}', 'cmdline')
enddef

export def HintComplete(_, _, _): string #{{{3
    return "popup\nvirtual"
enddef

export def Disassemble( #{{{3
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
            execute $'buffer {buf}'
            PushFuncOnStack()
        endif
        return
    endif

    var instructions: list<string>
    try
        instructions = execute($'disassemble {args}')->split('\n')
    # E1061: Cannot find function Funcname
    catch /^Vim\%((\a\+)\)\=:E1061:/
        # If   `:Disassemble`  was   executed   from  a   script,  rather   than
        # interactively from the command-line, we should retry after looking for
        # `Funcname` in the script namespace.
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
    setfiletype vim9asm
    if autofocus
        # `:execute` is necessary to suppress an error at compile time.
        # The command is only installed in a vim9asm buffer.
        execute 'Vim9asmFocus'
    endif
    if autohint
        execute $'Vim9asmHint {hint_type}'
    endif
    execute $'file {bufname->fnameescape()}'
    PushFuncOnStack()
enddef

export def DisassembleFunctionUnderCursor() #{{{3
    var col: number = col('.')
    var before_cursor: string = '\%(\%<.c\|\%.c\)'
    var after_cursor: string = '\%>.c'

    var Im_here: string = '[^ (]\+'
    var defcall: string = '^\s*\d\+\s\+\CDCALL\s\+'
        .. $'\zs{before_cursor}{Im_here}{after_cursor}'

    Im_here = '<lambda>\d\+\>'
    var lambda: string =
        $'{before_cursor}\C{Im_here}{after_cursor}'

    var curline: string = getline('.')
    if curline =~ lambda
        curline
            ->matchstr(lambda)
            ->Disassemble('nosplit')
    elseif curline =~ defcall
        curline
            ->matchstr(defcall)
            ->Disassemble('nosplit')
    endif
enddef

export def Focus(disable: bool) #{{{3
    var maparg: dict<any> = maparg('j', 'n', false, true)
    if !disable && (maparg->empty() || !maparg.buffer)
        if foldclosed('.') >= 0
            normal! zvzz
        endif
        for lhs: string in TRANSLATED->keys()
            execute printf(
                'nnoremap <buffer><nowait> %s <ScriptCmd>MoveAndOpenFold(%s, v:count)<CR>',
                    lhs,
                    lhs->substitute('^<\([^>]*>\)$', '<lt>\1', '')->string(),
            )
        endfor
    elseif disable && !maparg->empty()
        for lhs: string in TRANSLATED->keys()
            execute $'silent! nunmap <buffer> {lhs}'
        endfor
    endif
enddef

export def Hint(disable: bool, impl: string) #{{{3
    if impl != '' && impl != 'popup' && impl != 'virtual'
        Error($'"{impl}" is not a valid implementation for hints.')
        return
    endif

    if disable
        if impl != ''
            Error('nothing allowed after bang.')
            return
        endif

        if last_hints_impl == 'popup'
            silent! autocmd! Vim9asmHint * <buffer>
        elseif last_hints_impl == 'virtual'
            HintsVirtualRemove()
        endif
        last_hints_impl = ''

    elseif !disable
        if last_hints_impl != ''
            # Hints are already visible, and they use the desired implementation.
            # Nothing to do.
            if impl == last_hints_impl
                return
            endif
            # start from clean state
            execute 'Vim9asmHint!'
        endif
        if impl == 'popup'
            last_hints_impl = 'popup'
            augroup Vim9asmHint
                autocmd! * <buffer>
                autocmd CursorMoved <buffer> HintOpenPopup()
            augroup END
        elseif impl == 'virtual'
            last_hints_impl = 'virtual'
            HintsVirtualAdd()
        endif
    endif
enddef

export def FoldExpr(lnum: number): string #{{{3
    return getline(lnum) =~ VIMSCRIPT_LINE ? '>1' : '='
enddef

export def FoldText(lnum: number): string #{{{3
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

export def PopFuncFromStack() #{{{3
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
    execute $'buffer {func_stacks[winid][-1]}'
enddef
#}}}2
# Core {{{2
def PushFuncOnStack() #{{{3
    var winid: number = win_getid()
    if !func_stacks->has_key(winid)
        func_stacks->extend({[winid]: []})
    endif
    func_stacks[winid]->add(bufnr('%'))
enddef

def RetryAsLocalFunction(args: string): list<string> #{{{3
    var funcname: string = args
        ->substitute('^\%(debug\|profile\)\s\+\|($\|()$', '', 'g')

    if funcname =~ ':'
        return []
    endif

    # list of function names matching the one we're looking for
    var fullnames: list<string> = getcompletion($'*{funcname}(', 'function')
    # path to the script from where `:Disassemble` has been executed
    var calling_script: string = GetCallingScript()
    var full_funcname: string = fullnames
        # the function we're looking for *must* have been defined in the calling script
        ->filter((_, v: string): bool => v->GetFuncScript() == calling_script)
        ->get(0, '')
    if full_funcname !~ $'^<SNR>\d\+_{funcname}('
        return []
    endif
    var instructions: list<string>
    try
        var debug_or_profile: string = args->matchstr('^\%(debug\|profile\)\ze\s')
        instructions = printf('disassemble %s %s', debug_or_profile, full_funcname)
            ->execute()
            ->split('\n')
    catch
        return []
    endtry
    return instructions
enddef

def HintOpenPopup() #{{{3
    if NothingUnderCursor() || PopupIsOpen()
        return
    endif
    var instruction: string = expand('<cword>')
    var hint: string = instruction->GetHint()
    if hint == ''
        return
    endif
    popup_atcursor(hint, POPUP_OPTS)
enddef

def HintsVirtualAdd() #{{{3
    var buf: number = bufnr('%')
    if prop_type_get('vim9asm_hint', {bufnr: buf}) == {}
        prop_type_add('vim9asm_hint', {highlight: 'Comment', bufnr: buf})
    endif
    &l:wrap = true
    for [lnum: number, line: string] in getline(1, '$')->items()
        if line !~ '^\s*\d\+'
            continue
        endif
        var instruction: string = line->matchstr('^\s*\d\+\s\+\zs[A-Z_0-9]\+')
        var hint: string = instruction->GetHint()
        if hint == ''
            continue
        endif
        prop_add(lnum + 1, 0, {
            type: 'vim9asm_hint',
            text: $' {hint}',
            text_wrap: 'wrap',
            combine: false,
        })
    endfor
enddef

def HintsVirtualRemove() #{{{3
    var buf: number = bufnr('%')
    var prop_types: list<string> = prop_type_list({bufnr: buf})
        ->filter((_, type: string): bool => type =~ '^vim9asm_hint')
    if !prop_types->empty()
        {types: prop_types, bufnr: buf, all: true}
            ->prop_remove(1, line('$'))
    endif
enddef

def MoveAndOpenFold(lhs: string, cnt: number) #{{{3
    var old_foldlevel: number = foldlevel('.')
    var old_winline: number = winline()
    if lhs == 'j' || lhs == '<Down>'
        normal! gj
        if getline('.') =~ '^#\+$'
            return
        endif
        var is_in_a_closed_fold: bool = foldclosed('.') >= 0
        var new_foldlevel: number = foldlevel('.')
        var level_changed: bool = new_foldlevel != old_foldlevel
        if is_in_a_closed_fold || level_changed
            normal! zMzv
        endif
    elseif lhs == 'k' || lhs == '<Up>'
        normal! gk
        if getline('.') =~ '^#\+$'
            return
        endif
        var is_in_a_closed_fold: bool = foldclosed('.') >= 0
        var new_foldlevel: number = foldlevel('.')
        var level_changed: bool = new_foldlevel != old_foldlevel
        if is_in_a_closed_fold || level_changed
            silent! normal! gjzRgkzMzv
        endif
    else
        execute 'silent! normal! zR'
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
        execute $'{mods} new'
    endif
enddef

def GetCallingScript(): string #{{{3
    var calls: list<string> = expand('<stack>')
        ->split('\.\.')
    return calls
        ->get(calls->match('\C\<vim9asm#Disassemble\>') - 1, '')
        ->matchstr('\S\+\ze\[\d\+\]$')
enddef

def GetFuncScript(funcname: string): string #{{{3
    return execute('verbose def ' .. funcname->trim('()'))
        ->split('\n')
        ->get(1, '')
        ->matchstr('^\s*Last set from \zs\S\+')
        ->substitute('^\~/', $'{$HOME}/', '')
enddef

def GetHint(instruction: string): string #{{{3
    if HINTS->has_key(instruction)
        return HINTS[instruction]
    elseif HINTS->has_key($'ISN_{instruction}')
        return HINTS[$'ISN_{instruction}']
    endif
    return ''
enddef

def Error(msg: string) #{{{3
    # `:help :echo-redraw`
    redraw
    echohl ErrorMsg
    echomsg msg
    echohl NONE
enddef

def NothingUnderCursor(): bool #{{{3
    return getline('.')[charcol('.') - 1] =~ '\s'
enddef

def PopupIsOpen(): bool #{{{3
    return popup_list()
        ->map((_, v: number) => v
                                ->popup_getoptions().moved
                                ->get(0))
        ->index(line('.')) >= 0
enddef
