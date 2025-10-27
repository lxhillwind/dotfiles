; to run at startup, just create shortcut of this file (with explorer), and
; move it to `shell:startup` dir.
;
; cheatsheet:
; ^ => ctrl
; ! => alt
; + => shift
; # => win
;
; beginning with `$` => I guess it is like nnoremap in vim.
;
; or:
; AutoHotkey Help => Usage and Syntax => List of Keys

#NoEnv

EnvGet Home, USERPROFILE

; run or raise (impl). {{{1
; seems that inside function cannot access outside variable, so pass it as
; argument.
RunOrRaise(class, run, where)
{
    if WinExist(class) {
        WinActivate, %class%
    }
    else {
        Run, %run%, %where%
    }
}

; run or raise list. {{{1
!,::RunOrRaise("ahk_exe firefox.exe", "firefox", Home)
; if in quite limited device (like in vm), consider using IE:
;!,::RunOrRaise("ahk_exe iexplore.exe", "iexplore", Home)
!.::RunOrRaise("ahk_exe gvim.exe", "gvim", Home)
!/::RunOrRaise("ahk_exe WindowsTerminal.exe", "wt", Home)
; if wt is not available, consider using busybox:
;!/::RunOrRaise("ahk_exe busybox.exe", "busybox sh", Home)

; multimedia key. {{{1
#,::Send {Media_Prev}
#.::Send {Media_Next}
#/::Send {Media_Play_Pause}

; screenshot (ctrl+alt+a) {{{1
^!a::Send #+s
; switch desktop (alt+[, alt+]) {{{1
![::Send #^{Left}
!]::Send #^{Right}
; ctrl-space to switch input method {{{1
; For all os, add en-US keyboard as default input method;
;
; windows xp / windows 7:
; set key ctrl+space in "中文(简体)输入法 - 输入法/非输入法切换"
;
; windows 8+:
; send key win+space;
;^space::Send, #{space}
