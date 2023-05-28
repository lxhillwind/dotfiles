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
; TODO: vscode shows cmd window when launches via ahk (though the window can be closed manually)
!.::RunOrRaise("ahk_exe Code.exe", "code", Home)
!/::RunOrRaise("ahk_exe WindowsTerminal.exe", "wt", Home)

; multimedia key. {{{1
#,::Send {Media_Prev}
#.::Send {Media_Next}
#/::Send {Media_Play_Pause}

; firefox {{{1
#IfWinActive ahk_exe firefox.exe
; let ctrl-6 send alt-6, differ from alt-6 (sending ctrl-6).
; so we can differ them in tridactyl:
; atl-6 to switch tab 6 (native function for ctrl-6: requires unbind in local tridactylrc);
; ctrl-6 to switch between # tab (alt-6 recognized).
^6::Send !6
; alt-1 to alt-9
!1::Send ^1
!2::Send ^2
!3::Send ^3
!4::Send ^4
!5::Send ^5
!6::Send ^6
!7::Send ^7
!8::Send ^8
!9::Send ^9
#IfWinActive  ; endif

; screenshot (ctrl+alt+a) {{{1
^!a::Send #+s
; switch desktop (alt+[, alt+]) {{{1
![::Send #^{Left}
!]::Send #^{Right}
; ctrl-space to switch input method (windows 8+ only) {{{1
; (requires setting en-us keyboard as default
^space::Send, #{space}
