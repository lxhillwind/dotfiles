; to run at startup, just create shortcut of this file (with explorer), and
; move it to `shell:startup` dir.
;
; cheatsheet:
; ^ => ctrl
; ! => alt
; + => shift
; # => win
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
; it's required to add gvim to $PATH
!.::RunOrRaise("ahk_exe gvim.exe", "gvim", Home)
!/::RunOrRaise("ahk_exe WindowsTerminal.exe", "wt", Home)

; multimedia key. {{{1
#,::Send {Media_Prev}
#.::Send {Media_Next}
#/::Send {Media_Play_Pause}

; firefox {{{1
#IfWinActive ahk_exe firefox.exe
; c-n / c-p as down / up.
^n::Send {Down}
^p::Send {Up}
; addon shortcut
^g::Send !g
^+g::Send !+g
#z::Send !z
; alt no steal focus
Alt::return  ; LAlt::return will disable Alt-Tab.
; home page
!+h::Send !{home}
; tab switch(alt+shift+[ or ])
!+[::Send ^+{Tab}
!+]::Send ^{Tab}
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
