; to run at startup, just create shortcut of this file (with explorer), and
; move it to `shell:startup` dir.

; run or raise (impl). {{{1
RunOrRaise(class, run)
{
    if WinExist(class) {
        WinActivate, %class%
    }
    else {
        Run, %run%
    }
}

; run or raise list. {{{1
!,::RunOrRaise("ahk_exe msedge.exe", "msedge")
; it's required to add gvim to $PATH
!.::RunOrRaise("ahk_exe gvim.exe", "gvim")
!/::RunOrRaise("ahk_exe WindowsTerminal.exe", "wt")

; multimedia key. {{{1
#,::Send {Media_Prev}
#.::Send {Media_Next}
#/::Send {Media_Play_Pause}

; edge home page. {{{1
$!+h::
    if WinActive("ahk_exe msedge.exe")
        Send !{home}
    else
        Send !+h
return

; map alt-1 to alt-9. {{{1
; generation vim command ( i_ctrl-r=F() ) {{{
; def! g:F(): string
;   var result = ''
;   var data =<< trim END
;   $!{n}::
;       if WinActive("ahk_exe msedge.exe")
;           Send ^{n}
;       else
;           Send !{n}
;   return
;   END
;
;   for i in range(1, 9)
;     result ..= data->join("\n")->substitute('\V{n}', i, 'g')
;     result ..= "\n"
;   endfor
;   return result
; enddef
; generated {{{2
$!1::
    if WinActive("ahk_exe msedge.exe")
        Send ^1
    else
        Send !1
return
$!2::
    if WinActive("ahk_exe msedge.exe")
        Send ^2
    else
        Send !2
return
$!3::
    if WinActive("ahk_exe msedge.exe")
        Send ^3
    else
        Send !3
return
$!4::
    if WinActive("ahk_exe msedge.exe")
        Send ^4
    else
        Send !4
return
$!5::
    if WinActive("ahk_exe msedge.exe")
        Send ^5
    else
        Send !5
return
$!6::
    if WinActive("ahk_exe msedge.exe")
        Send ^6
    else
        Send !6
return
$!7::
    if WinActive("ahk_exe msedge.exe")
        Send ^7
    else
        Send !7
return
$!8::
    if WinActive("ahk_exe msedge.exe")
        Send ^8
    else
        Send !8
return
$!9::
    if WinActive("ahk_exe msedge.exe")
        Send ^9
    else
        Send !9
return
