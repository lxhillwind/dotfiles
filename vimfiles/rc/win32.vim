vim9script

# utility function (copied from ~/vimfiles/vimrc {{{
def TrSlash(s: string): string
    if has('win32')
        return substitute(s, '\', '/', 'g')
    else
        return s
    endif
enddef
# }}}

# Set shellslash, so file path completion returns slash based str, {{{
# which works in sh environment and win32 shell (cmd is not supported?).
# shellescape() also returns unix-shell-friendly string.
#   - plugin vim-fuzzy also requires it.
# Windows XP does not like slash path; let's handle it in ":Start"
# UserCommand. }}}
set shellslash

# XP italic font is not displayed correctly
if windowsversion()->str2float() <= 5.1
    g:base16#enable_italics = 0
endif

# set env for cygwin / msys2 shell (start via :!): $VIM, $MYVIMRC... {{{
# It's better to override $VIM / $VIMRUNTIME via shell startup, so cygwin
# vim has correct $VIM set (/usr/share/vim). }}}
$VIM = TrSlash($VIM)
$VIMRUNTIME = TrSlash($VIMRUNTIME)
$MYVIMRC = TrSlash($MYVIMRC)

# $HOME should be set to make git bash find ~; otherwise vim-fuzzy won't
# work (e.g. "RecentFiles" does not show file under ~).
if !exists('$HOME')
    $HOME = TrSlash($USERPROFILE)
else
    $HOME = TrSlash($HOME)
endif

# set &shell, and add dir of it to $PATH. {{{
# console vim and gvim handle &shell differently:
# When &shell contains whitespace and not quoted, console vim does not
# work with ":!..." command: it calls _wsystem() currently, while in gvim
# it calls CreateProcess(); Most importantly, quoting is handled
# differently.
# So only set shell when it does not contain special char.
#
# To make things simpler, use git path to find bash.
# Then git should be installed where path does not contain speical char.
#
# NOTE: busybox sh cannot handle CJK correctly (chcp.exe / utf-8). Use
# cygwin / msys2 derived shell (fullset) if possible.
# }}}

def Exepath(program: string): string  # {{{
    # exepath(xxx) returns xxx in current dir, which is not desired.
    # so let's wrap it; NOTE: `.exe` suffix should be set in param.
    for i in globpath($PATH->substitute('\', '/', 'g')->substitute(';', ',', 'g'), program, 0, 1)
        if i->match('\v[\/]') >= 0  # not in current dir
            return i
        endif
    endfor
    return ''  # not found
enddef  # }}}

const git_path = Exepath('git.exe')->substitute('\', '/', 'g')
for _ in ['']  # use a for loop to make indent below fewer.
    if !(
            execute(':verbose set shell?')->split("\n")->get(-1)
            ->match('^\s*Last set from') < 0
            || &shell->match('^/') >= 0)
        # only set shell if it is not set or set to invalid value (like
        # /bin/sh when invoking from busybox shell).
        break
    endif
    if empty(git_path)
        # try busybox before giving up.
        if !Exepath('busybox.exe')->empty()
            &shell = 'busybox sh'
        endif
        break
    endif

    # git.exe, when invoking from git bash, has different paths. {{{
    # checking 4 times is enough.
    # $ find ./ -name git.exe  # from git root dir
    # ./bin/git.exe
    # ./cmd/git.exe
    # ./mingw64/bin/git.exe
    # ./mingw64/libexec/git-core/git.exe
    # }}}
    var depth = 4
    var git_root = git_path
    while depth > 0
        depth -= 1
        git_root = fnamemodify(git_root, ':h')
        if executable(git_root .. '/usr/bin/bash')
            break
        endif
    endwhile

    const bash_path = git_root .. '/usr/bin/bash'
    if !executable(bash_path)
        echoerr 'vimrc: bash not found in git dir; using MinGit?'
        break
    endif
    if bash_path->match(' ') >= 0
        # git-for-windows default install location contains whitespace.
        &shell = '"' .. bash_path .. '"'
    else
        &shell = bash_path
    endif
    if fnamemodify(exepath('find'), ':h') != fnamemodify(bash_path, ':h')
        # always add dir of shell to $PATH, so tools like find wins. {{{
        # (it will be messy when calling win32 find.exe in unix shell)
        # When running cygwin / msys2 shell via :!, bash_path here will be
        # translated to /usr/bin, which is feasible. }}}
        $PATH = fnamemodify(bash_path, ':h') .. ';' .. $PATH
    endif
endfor

# vim-sh config; busybox sh rc
$ENV = expand('~/.config/zshrc')

# set &shell related options. {{{
# NOTE: to use '"' correctly, all '"' should be escaped with '\'.
# like this:
#   :!echo \"hello world\"
# (so just use :Sh if possible: it is more user friendly, and does not
# depends on &shell related setting) }}}
if &shell->match('\v(bash|zsh|busybox(|.exe) sh)(|.exe)$') >= 0
    # these settings are from vim_faq, modified.
    # https://vimhelp.org/vim_faq.txt.html#faq-33.6
    &shellcmdflag = '-c'
    # shq seems to modify excmd very early; use sxq instead.
    &shellquote = ''
    &shellxquote = '"'
    # sxe take effect even when sxq is not "(", so set it to empty.
    # see vim-sh (search ":!start") for details.
    &shellxescape = ''
    # shellpipe / shellredir seems not required.
endif
