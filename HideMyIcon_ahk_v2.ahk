; Script     HideMyIcon_ahk_v2.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/HideMyIcon
; Date       17.01.2023
; Version    0.4

#Requires AutoHotkey >=2.0
#SingleInstance
#Warn
SetTitleMatchMode 2

SetTimer(HideMyIcon, 10)                   ; default settings
;SetTimer(HideMyIcon.bind(1,  17, ''), 10) ; without delay -> smooth effect
;SetTimer(HideMyIcon.Bind(1, 255, ''), 10) ; on-off

/*
    Hover: effect triggered by clicking (0) or hovering (1)
    Speed: 1 (frames 256), 3 (86), 5 (52), 15 (18), 17 (16), 51 (6), 85 (4), 255 (2), works with any number between 0, 255
    Delay: sleep time between changing the transparency, use "" or 0 for best performance
*/
HideMyIcon(Hover := 0, Speed := 17, Delay := 16.67) {

    static init := 0, Transparent := 255, hDesk := 0, hIcon := 0

    if !init {
        ; get handles
        if !hDesk := winExist("ahk_class Progman") ; credit to SKAN
            hDesk := winExist("ahk_class WorkerW")
        hIcon := ControlGetHwnd("SysListView321", "ahk_id" hDesk)
        ; raising proc priority makes the fade animation smoother (could be placebo)
        ProcessSetPriority("AboveNormal")
        ; exiting the script will restore the icons" transparency to 255
        OnExit(RestoreIcons)
        init := 1
    }

    ; active windows and transparency
    Desk := WinActive("ahk_id" hDesk),
    Tray := WinActive("ahk_class Shell_TrayWnd"),
    Transp := WinGetTransparent("ahk_id" hIcon),
    
    ; mouseover state
    MouseGetPos(,, &id, &ctrl),
    cls := WinGetClass("ahk_id" id),
    wnd := WinGetTitle("ahk_id" id),

    MousePos := ((cls ~= "Shell_TrayWnd" && Ctrl ~= "TrayShowDesktopButton" )
              || (cls ~= "Progman|WorkerW" && wnd == "") ? "ShowDesk"
               : (cls ~= "Progman|WorkerW") ? "Desktop"
               : (cls ~= "Shell_TrayWnd") ? "Taskbar"
               : (cls ~= "DFTaskbar") ? "DisplayFusion" : "")

    ; the step indicates to decrease or increase transparency
    if !Hover
        step := (Desk||Tray) ? 1 : -1
    else
        step := (MousePos) ? 1 : -1
    ; forcing fade in effect on desktop & tray
    if (MousePos ~= "ShowDesk|TrayWnd")
        step := 1
    
    NextStep := Transp + step * Speed

    ; a minimum value of 1 is required for proper use of the taskbar and showdesk button
    if (NextStep == 1) || (NextStep == 0) || (0 > NextStep)
        Transparent := 1
    else if (NextStep > 255)
        Transparent := 255
    else
        Transparent := NextStep    
    ; set the transparency of the icon
    WinSetTransparent(Transparent, "ahk_id" hIcon)
    if Delay
        Sleep(Delay)
    return

    RestoreIcons(*) {
        WinSetTransparent(255, "ahk_id" hIcon)
    }
    
}
