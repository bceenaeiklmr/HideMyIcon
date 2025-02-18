; Script     HideMyIcon_ahk_v2.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/HideMyIcon
; Date       18.02.2025
; Version    0.5.0

#Requires AutoHotkey v2
#SingleInstance Force
#Warn

SetTimer(HideMyIcon.Bind(1, 17, 0), 20)

/**
 * Controls the transparency of an icon based on user interaction.
 * @param {bool} change_on_hover A flag for the trigger mode: 0 = click, 1 = hover.
 * @param {int}  step_size       Defines the rate at which the transparency changes.
 * Accepts any value between 0 and 255, where specific values correspond to predefined frame counts: 
 * *     1   -> 256 frames 
 * *     3   -> 86 frames 
 * *     5   -> 52 frames 
 * *     15  -> 18 frames 
 * *     17  -> 16 frames 
 * *     51  -> 6 frames 
 * *     85  -> 4 frames 
 * *     255 -> 2 frames
 * @param {int}  delay           Sleep time between each transparency change.
 * 
 * Usage Examples with SetTimer:
 * *   SetTimer(HideMyIcon.Bind(1, 15, 20), 20)   ; Hover-triggered effect with a moderate step size and a 20 ms delay.
 * *   SetTimer(HideMyIcon.Bind(1, 51,  0), 20)   ; Hover-triggered effect with a faster transition.
 * *   SetTimer(HideMyIcon.Bind(0, 85,  0), 20)   ; Click-triggered effect with a rapid transition.
 * *   SetTimer(HideMyIcon.Bind(0, 255, 0), 1000) ; Click-triggered effect with the quickest transition but with a 1000 ms timer delay.
 */
HideMyIcon(change_on_hover := 0, step_size := 17, delay := 16.67) {

    static TRANSPARENT_MIN := 1, TRANSPARENT_MAX := 255
    static transparent := 255
    static hdesk, hicon    
    static init := False
    
    if !init {
        if (step_size < 1 || step_size > 255)
            throw("Step size must be between 1 and 255.")

        ; Get the handle of the desktop and its' icons
        if !hdesk := WinExist("ahk_class Progman")
            if !hdesk := WinExist("ahk_class WorkerW")
                hdesk := WinExist("Shell_TrayWnd")
        hicon := ControlGetHwnd("SysListView321", hdesk)
        
        ; Register the restore function on exit
        OnExit((*) => WinSetTransparent(TRANSPARENT_MAX, hicon))
        init := True
    }

    ; Initialize variables
    id := ctrl := cls := wnd := ""
    
    ; Get the title and class of the window under the mouse,
    ; MouseGetPos raises an error if the mouse is over the Start Menu
    try {
        MouseGetPos(,, &id, &ctrl)
        cls := WinGetClass(id)
        wnd := WinGetTitle(id)
    } 
    
    ; Determine the mouse position by the window class, title, and control
    mouse_pos := ((ctrl ~= "TrayShowDesktopButton") ? "TrayShowDesktopButton"
               : (cls ~= "Progman|WorkerW" && wnd == "") ? "StartMenu"
               : (cls ~= "Progman|WorkerW") ? "Desktop"
               : (cls ~= "Shell_TrayWnd") ? "Taskbar"
               : (cls ~= "DFTaskbar") ? "DisplayFusion" : "")

    ; Determine the direction of the change
    if (mouse_pos ~= "TrayShowDesktopButton|StartMenu|Taskbar")
        change := 1
    else if !change_on_hover
        change := (WinActive(hdesk) || WinActive("ahk_class Shell_TrayWnd")) ? 1 : -1
    else
        change := (mouse_pos) ? 1 : -1

    ; Calculate the new transparency
    before := transparent
    transparent := transparent + change * step_size

    ; On zero transparency, we can't detect the taskbar, nor the show desktop button
    if (1 > transparent)
        transparent := TRANSPARENT_MIN
    else if (transparent > TRANSPARENT_MAX)
        transparent := TRANSPARENT_MAX
 
    ; Set the transparency
    if (transparent != before)
        WinSetTransparent(transparent, hicon)
    
    ; Add delay
    if delay
        Sleep(delay)
    return
}
