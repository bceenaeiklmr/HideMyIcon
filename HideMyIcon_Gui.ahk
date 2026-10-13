; Script     HideMyIcon_Gui.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/HideMyIcon
; Date       13.10.2026
; Version    0.6.0

#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn
Persistent(true)

; Core engine: eased animation & hybrid event dispatcher

class HideMyIconEngine {
    static hdesk := 0
    static hicon := 0
    static currentAlpha := 255
    static targetAlpha := 255
    static isAnimating := false
    static animTimer := ""
    static hoverTimer := ""
    static hookGui := ""
    static hookHwnd := 0
    static hookMsg := 0
    static hookCallback := ""
    static isHookRegistered := false
    static durationMs := 250
    static isHoverMode := true
    static lastMouseX := -1
    static lastMouseY := -1

    ; Locate desktop list view handle and setup restore on exit
    static Init() {
        if (this.hicon && WinExist(this.hicon))
            return

        hdesk := WinExist("ahk_class WorkerW", "FolderView") ? WinExist()
               : WinExist("ahk_class Progman", "FolderView")
        if (!hdesk) {
            if (!hdesk := WinExist("ahk_class Progman"))
                hdesk := WinExist("ahk_class WorkerW")
        }
        if (!hdesk)
            hdesk := WinExist("ahk_class Shell_TrayWnd")

        this.hdesk := hdesk

        ; Get SysListView32 child control via ShellDefView
        hShellDefView := DllCall("user32.dll\GetWindow", "ptr", hdesk, "int", 5, "ptr")
        this.hicon := DllCall("user32.dll\GetWindow", "ptr", hShellDefView, "int", 5, "ptr")
        if (!this.hicon && hdesk) {
            try this.hicon := ControlGetHwnd("SysListView321", hdesk)
        }

        ; Always restore desktop icons to full opacity on exit
        OnExit((*) => this.Restore())
    }

    ; Restore desktop icons to normal
    static Restore(*) {
        if (this.hicon) {
            try WinSetTransparent(255, this.hicon)
        }
    }

    ; Calculate duration in ms from detail and delay slider
    static CalculateDuration(detail, delay) {
        baseDurations := [600, 500, 400, 320, 250, 180, 120, 30]
        base := baseDurations[Min(Max(detail, 1), 8)]
        if (delay <= 0)
            return 30
        factor := delay / 20 ; 20 = 1.0x baseline, 10 = 0.5x, 50 = 2.5x, 100 = 5.0x
        return Max(30, Round(base * factor))
    }

    ; Apply configuration from GUI / INI
    static ApplySettings(isHover, detail, delay) {
        this.Init()
        this.isHoverMode := isHover
        this.durationMs := this.CalculateDuration(detail, delay)

        if (isHover) {
            this.EnableShellHook(false)
            this.EnableHover(true)
        } else {
            this.EnableHover(false)
            this.EnableShellHook(true)
        }
    }

    ; Set transparency safely
    static SetAlpha(alpha) {
        alpha := Min(Max(Round(alpha), 1), 255)
        this.currentAlpha := alpha

        if (!this.hicon)
            return

        try WinSetTransparent(alpha, this.hicon)
    }

    ; Smooth Quadratic Ease-Out Animation (from GpGFX)
    static FadeTo(target, durationMs := 0) {
        this.Init()
        if (durationMs <= 0)
            durationMs := this.durationMs

        target := Min(Max(Round(target), 1), 255)
        if (target == this.targetAlpha && (this.currentAlpha == target || this.isAnimating))
            return

        this.targetAlpha := target
        fromAlpha := this.currentAlpha
        startTick := A_TickCount

        if (this.animTimer) {
            SetTimer(this.animTimer, 0)
            this.animTimer := ""
        }

        this.isAnimating := true

        __Tick() {
            elapsed := A_TickCount - startTick
            progress := (durationMs > 0) ? Min(1.0, elapsed / durationMs) : 1.0

            ; Quadratic Ease-Out: f(t) = 1 - (1 - t)^2
            easeOut := 1.0 - ((1.0 - progress) * (1.0 - progress))
            curAlpha := Round(fromAlpha + (target - fromAlpha) * easeOut)
            this.SetAlpha(curAlpha)

            if (progress >= 1.0) {
                SetTimer(__Tick, 0)
                this.animTimer := ""
                this.isAnimating := false
                this.SetAlpha(target)
            }
        }

        this.animTimer := __Tick
        SetTimer(__Tick, 16) ; ~60 FPS
    }

    ; Event-Driven ShellHook for Click / Window-Focus Mode (0% idle CPU)
    static EnableShellHook(enable := true) {
        if (enable && !this.isHookRegistered) {
            this.hookGui := Gui()
            this.hookHwnd := this.hookGui.Hwnd
            DllCall("RegisterShellHookWindow", "ptr", this.hookHwnd)
            this.hookMsg := DllCall("RegisterWindowMessage", "str", "SHELLHOOK")
            this.hookCallback := ObjBindMethod(this, "OnShellMessage")
            OnMessage(this.hookMsg, this.hookCallback)
            this.isHookRegistered := true

            ; Evaluate initial active window
            this.CheckActiveWindow()
        } else if (!enable && this.isHookRegistered) {
            DllCall("DeregisterShellHookWindow", "ptr", this.hookHwnd)
            if (this.hookCallback) {
                OnMessage(this.hookMsg, this.hookCallback, 0)
                this.hookCallback := ""
            }
            if (this.hookGui)
                this.hookGui.Destroy()
            this.hookGui := ""
            this.hookHwnd := 0
            this.isHookRegistered := false
        }
    }

    ; Handle window activation events
    static OnShellMessage(wParam, lParam, *) {
        static HSHELL_WINDOWACTIVATED := 4
        static HSHELL_RUDEAPPACTIVATED := 0x8004

        if (wParam == HSHELL_WINDOWACTIVATED || wParam == HSHELL_RUDEAPPACTIVATED) {
            this.CheckActiveWindow()
        }
    }

    ; Check if Desktop or Taskbar is active
    static CheckActiveWindow() {
        isDesktopActive := WinActive("ahk_class Progman")
                        || WinActive("ahk_class WorkerW")
                        || WinActive("ahk_class Shell_TrayWnd")

        target := isDesktopActive ? 255 : 1
        this.FadeTo(target)
    }

    ; Hover tracking with adaptive idle checking
    static EnableHover(enable := true, checkIntervalMs := 60) {
        if (this.hoverTimer) {
            SetTimer(this.hoverTimer, 0)
            this.hoverTimer := ""
        }

        if (!enable)
            return

        __CheckHover() {
            MouseGetPos(&mx, &my, &winId, &ctrl)

            ; Skip if mouse has not moved and no animation is running
            if (mx == this.lastMouseX && my == this.lastMouseY && !this.isAnimating)
                return

            this.lastMouseX := mx
            this.lastMouseY := my

            cls := WinGetClass(winId)
            wnd := WinGetTitle(winId)

            isTarget := (ctrl ~= "TrayShowDesktopButton"
                     || (cls ~= "Progman|WorkerW" && (wnd == "" || InStr(wnd, "Program Manager")))
                     || cls ~= "Shell_TrayWnd|DFTaskbar")

            target := isTarget ? 255 : 1
            if (target != this.targetAlpha)
                this.FadeTo(target)
        }

        this.hoverTimer := __CheckHover
        SetTimer(__CheckHover, checkIntervalMs)
    }
}

; GUI implementation

class HideMyIconGui {
    __New() {
        this.get_text()
        this.create_gui()
        this.get_settings()
        this.add_to_tray()
        this.apply_engine()
    }

    __Delete(*) {
        HideMyIconEngine.Restore()
        ExitApp()
    }

    effect_detail {
        get => this.__effect_detail
        set {
            if not (value ~= "^\d+$")
                return
            this.g.effect_slider.value := value
            this.g.effect_updown.value := value
            this.g.effect_edit.value := value
            this.__effect_detail := Integer(value)
            this.update_display_text()
        }
    }

    effect_delay {
        get => this.__effect_delay
        set {
            if not (value ~= "^\d+$")
                return
            this.g.delay_slider.value := value
            this.g.delay_updown.value := value
            this.g.delay_edit.value := value
            this.__effect_delay := Integer(value)
            this.update_display_text()
        }
    }

    effect_hover {
        get => this.__effect_hover
        set {
            this.g.hover_cbox.value := value
            this.g.hover_text.value := this.text.hover.%value%
            this.__effect_hover := value
        }
    }

    update_display_text() {
        if (!this.HasOwnProp("g") || !this.g.HasOwnProp("effect_text"))
            return
        if (!this.HasOwnProp("__effect_detail") || !this.HasOwnProp("__effect_delay"))
            return
        dur := HideMyIconEngine.CalculateDuration(this.__effect_detail, this.__effect_delay)
        speedNames := [
            "Ultra Smooth",
            "Very Smooth",
            "Smooth",
            "Balanced",
            "Snappy",
            "Fast",
            "Very Fast",
            "Instant"
        ]
        name := speedNames[Min(Max(this.__effect_detail, 1), 8)]
        this.g.effect_text.value := name " (~" dur " ms ease-out)"

        if (this.g.HasOwnProp("delay_text")) {
            mult := Round(this.__effect_delay / 20, 1)
            this.g.delay_text.value := "Modifier scale: " mult "x  (Result: ~" dur " ms)"
        }
    }

    set_effect_edit(*) {
        this.effect_detail := this.g.effect_edit.value
        this.apply_engine()
    }
    set_effect_slider(*) {
        this.effect_detail := this.g.effect_slider.value
        this.apply_engine()
    }
    set_effect_updown(*) {
        this.effect_detail := this.g.effect_updown.value
        this.apply_engine()
    }
    set_hover_cbox(*) {
        this.effect_hover := !this.effect_hover
        this.apply_engine()
    }
    set_delay_edit(*) {
        this.effect_delay := this.g.delay_edit.value
        this.apply_engine()
    }
    set_delay_updown(*) {
        this.effect_delay := this.g.delay_updown.value
        this.apply_engine()
    }
    set_delay_slider(*) {
        this.effect_delay := this.g.delay_slider.value
        this.apply_engine()
    }

    show_gui(*) => this.g.Show()
    minimize_to_tray(*) => this.g.Hide()

    add_to_tray() {
        A_TrayMenu.Add()
        A_TrayMenu.Add("Show GUI", ObjBindMethod(this, "show_gui"))
        A_TrayMenu.Add("Minimize to tray", ObjBindMethod(this, "minimize_to_tray"))
    }

    create_gui() {
        this.g := g := Gui("+Owner +AlwaysOnTop", "HideMyIcon")
        g.SetFont("s8", "Segoe UI")

        ; Effect detail's controls
        g.AddText("x20 y20 w260", "Fade animation speed (Ease-Out)")
        g.effect_slider := g.AddSlider("x10 y45 w230 Range1-8")
        g.effect_edit := g.AddEdit("x250 y45 w40")
        g.effect_updown := g.AddUpDown("Range1-8")
        g.effect_text := g.AddText("x20 y75 w260")

        ; Delay / Speed modifier controls
        g.AddText("x20 y115 w260", "Duration modifier (scale)")
        g.delay_slider := g.AddSlider("x10 y140 w230 Range0-100")
        g.delay_edit := g.AddEdit("x250 y140 w40")
        g.delay_updown := g.AddUpDown("Range0-100")
        g.delay_text := g.AddText("x20 y170 w260")

        ; Trigger mode controls
        g.hover_cbox := g.AddCheckbox("x20 y220 Checked", this.text.hover.cb)
        g.hover_text := g.AddText("x20 y245 w260")

        ; Action buttons
        g.save_ini := g.AddButton("x45 y290 w100", "Save")
        g.to_tray := g.AddButton("x155 y290 w100", "Minimize")

        ; Events
        g.effect_slider.OnEvent("Change", ObjBindMethod(this, 'set_effect_slider'))
        g.effect_updown.OnEvent("Change", ObjBindMethod(this, 'set_effect_updown'))
        g.effect_edit.OnEvent("Change", ObjBindMethod(this, 'set_effect_edit'))
        g.delay_slider.OnEvent("Change", ObjBindMethod(this, 'set_delay_slider'))
        g.delay_updown.OnEvent("Change", ObjBindMethod(this, 'set_delay_updown'))
        g.delay_edit.OnEvent("Change", ObjBindMethod(this, 'set_delay_edit'))
        g.hover_cbox.OnEvent("Click", ObjBindMethod(this, 'set_hover_cbox'))
        g.save_ini.OnEvent("Click", ObjBindMethod(this, 'save_settings'))
        g.to_tray.OnEvent("Click", ObjBindMethod(this, 'minimize_to_tray'))
        g.OnEvent("Close", ObjBindMethod(this, "__Delete"))

        g.Show("w310 h340")
        return
    }

    get_settings() {
        cfg := this.cfg := A_ScriptDir "\" StrSplit(A_ScriptName, ".")[1] ".ini"
        if (!FileExist(cfg)) {
            FileAppend("", cfg)
            IniWrite(1, cfg, "settings", "effect_hover")
            IniWrite(20, cfg, "settings", "effect_delay")
            IniWrite(5, cfg, "settings", "effect_detail")
        }
        this.effect_hover := Integer(IniRead(cfg, "settings", "effect_hover", "1"))
        this.effect_delay := Integer(IniRead(cfg, "settings", "effect_delay", "20"))
        this.effect_detail := Integer(IniRead(cfg, "settings", "effect_detail", "5"))
        return
    }

    get_text() {
        text := {}
        text.hover := {
            0: "Event-driven: Fades when desktop is focused (0% CPU).",
            1: "Adaptive hover: Fades when cursor moves over desktop.",
            cb: "Triggered by mouse hover"
        }
        text.detail := [
            "Ultra Smooth (~550ms ease-out)",
            "Very Smooth (~450ms ease-out)",
            "Smooth (~380ms ease-out)",
            "Balanced (~300ms ease-out)",
            "Snappy (~240ms ease-out)",
            "Fast (~180ms ease-out)",
            "Very Fast (~120ms ease-out)",
            "Instant (~30ms on-off)"
        ]
        text.delay := "Fine-tunes the transition speed.`n(Recommended: 16 - 25 ms, 0 for shortest)"
        this.text := text
        return
    }

    apply_engine() {
        HideMyIconEngine.ApplySettings(this.effect_hover, this.effect_detail, this.effect_delay)
    }

    save_settings(*) {
        this.g.Submit(false)
        IniWrite(this.effect_detail, this.cfg, "settings", "effect_detail")
        IniWrite(this.effect_delay, this.cfg, "settings", "effect_delay")
        IniWrite(this.effect_hover, this.cfg, "settings", "effect_hover")
        this.apply_engine()

        ToolTip("New settings saved and applied!")
        SetTimer(() => ToolTip(), -1500)
    }
}

; Start application
HMI := HideMyIconGui()
