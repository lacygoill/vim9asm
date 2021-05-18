# Rationale

Vim9 comes with a builtin `:disassemble` command which displays the low-level instructions generated for a compiled function.  This output cannot be searched, is not syntax highlighted, and does not provide information regarding the meaning of each instruction.

This package provides a custom `:Disassemble` command whose purpose is to display the output of the builtin `:disassemble` command in a new window.  The code is syntax highlighted, and folded to let you focus on the instructions for a given line of Vim9 script.  A hint can be displayed for the instruction name under the cursor.

![demo](https://user-images.githubusercontent.com/8505073/114791103-2c56da00-9d86-11eb-9439-5c48834544ce.gif)

# Usage

    # display generated instructions for MyCompiledFunction in a new horizontal split window
    :Disassemble MyCompiledFunctionName

    # same thing but with the instructions used for profiling and in a vertical split window
    :vertical Disassemble! MyCompiledFunctionName

    # display a hint popup when the cursor is over an instruction name
    :Vim9asmHint

    # stop displaying a hint popup
    :Vim9asmHint!

    # automatically open/close folds to only display instructions
    # for 1 Vim9 script line of code at a time
    :Vim9asmFocus

    # stop automatically opening/closing folds
    :Vim9asmFocus!

---

To disassemble a script-local function from the command-line, you need to provide the full name of the function, including its script ID.  To do so, prepend its name with a `*` wildcard, append an opening parenthesis,
then press Tab to make Vim complete the name:

    :Disassemble *Funcname(
    # press Tab
    :Disassemble <SNR>123_Funcname(
    # press Enter

---

While the cursor is on a `<lambda>123` token inside a generated instruction, you can press `<C-]>` to get the instructions for that lambda.

# Configuration

The plugin can be customized with `g:vim9asm`:

    # in a Vim9 script
    g:vim9asm = {
      # automatically open/close folds
      autofocus: true,
      # automatically display hint about instruction name under cursor in popup
      autohint: true,
      hint: {
        # determine background color of popup
        highlight: 'Pmenu',
        # draw border around popup
        border: [],
        # determine characters used to draw border
        borderchars: ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
      }
    }

# Requirements

A recent Vim version.

# Installation
## Linux

Run this shell command:

    git clone https://github.com/lacygoill/vim9asm.git ~/.vim/pack/vim9asm/opt/vim9asm

Then, add this line in your vimrc:

    packadd! vim9asm

## Windows

Run this shell command:

    git clone https://github.com/lacygoill/vim9asm.git %USERPROFILE%\vimfiles\pack\vim9asm\opt\vim9asm

Then, add this line in your vimrc:

    packadd! vim9asm

# License

[VIM License](https://github.com/vim/vim/blob/master/LICENSE)

