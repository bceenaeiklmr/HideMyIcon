; Script     HideMyIcon_Gui.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/HideMyIcon
; Date       19.02.2025
; Version    0.5.2

#Warn
#include HideMyIcon.ahk
Persistent(True)

; Timer update interval
TIMER_UPDATE := 20

; Stop the previous timer from HideMyIcon.ahk
SetTimer(fn, 0)

; Initialize the GUI and create a new timer
h := HideMyIconGui()
fn := HideMyIcon.Bind(h.effect_hover, h.effect_step_size, h.effect_delay)
SetTimer(fn, TIMER_UPDATE)


class HideMyIconGui {

    ; Initialize the GUI
    __New() {
        this.get_text()
        this.create_gui()
        this.get_settings()
        this.add_to_tray()
    }

    ; Using the desructor the script will exit properly
    __Delete(*) {
        ExitApp()
    }

    ; Change the details controls
    effect_detail {
        get => this.__effect_detail
        set {
            if not (value ~= "^\d+$")
                return
            this.g.effect_slider.value := value
            this.g.effect_updown.value := value
            this.g.effect_edit.value := value
            this.g.effect_text.value := this.text.detail[value]
            this.__effect_detail := value
        }
    }

    ; Change the delay controls
    effect_delay {
        get => this.__effect_delay
        set {
            if not (value ~= "^\d+$")
                return
            this.g.delay_slider.value := value
            this.g.delay_updown.value := value
            this.g.delay_edit.value := value
            this.__effect_delay := value
        }
    }

    ; Change the hover controls
    effect_hover {
        get => this.__effect_hover
        set {
            this.g.hover_cbox.value := value
            this.g.hover_text.value := this.text.hover.%value%
            this.__effect_hover := value
        }
    }

    ; Calculate the step size based on the effect detail
    effect_step_size {
        get => [1, 3, 5, 15, 17, 51, 85, 255][this.effect_detail]
    }

    ; GUI control functions
    set_effect_edit(*) => this.effect_detail := this.g.effect_edit.value
    set_effect_slider(*) => this.effect_detail := this.g.effect_slider.value
    set_effect_updown(*) => this.effect_detail := this.g.effect_updown.value
    set_hover_cbox(*) => this.effect_hover := !this.effect_hover
    set_delay_edit(*) => this.effect_delay := this.g.delay_edit.value
    set_delay_updown(*) => this.effect_delay := this.g.delay_updown.value
    set_delay_slider(*) => this.effect_delay := this.g.delay_slider.value
    ; GUI display functions
    show_gui(*) => this.g.Show()
    minimize_to_tray(*) => this.g.Hide()

    ; Manage the GUI restoration from the tray
    add_to_tray() {
        A_TrayMenu.Add()
        A_TrayMenu.Add("Show GUI", ObjBindMethod(this, "show_gui"))
        A_TrayMenu.Add("Minimize to tray", ObjBindMethod(this, "minimize_to_tray"))
    }

    ; Create the GUI and its controls
    create_gui() {
        ; Without the taskbar button
        this.g := g := Gui("+Owner +AlwaysOnTop", "HideMyIcon")
        g.SetFont("s7")

        ; Effect detail's controls
        g.AddText("x20 y20 w230", "Fade effect detail")
        g.effect_slider := g.AddSlider("x10 y40 w230 Range1-8")
        g.effect_edit := g.AddEdit("x250 y40 w40")
        g.effect_updown := g.AddUpDown("Range1-8")
        g.effect_text := g.AddText("x20 w280")

        ; Effect delay's controls
        g.AddText("x20 y110 w230", "Frame delay")
        g.delay_slider := g.AddSlider("x10 y140 w230 Range0-100")
        g.delay_edit := g.AddEdit("x250 y140 w40")
        g.delay_updown := g.AddUpDown("Range0-100")
        g.AddText("x20", this.text.delay)

        ; Effect on hover's controls
        g.hover_cbox := g.AddCheckbox("x20 y240 Checked", this.text.hover.cb)
        g.hover_text := g.AddText("x20 y260 w260")

        ; Other buttons
        g.save_ini := g.AddButton("x100 y290 w100", "Save")
        g.to_tray := g.AddButton("x100 y320 w100", "Minimize")

        ; Bind the functions to the GUI controls
        g.effect_slider.OnEvent("Change", ObjBindMethod(this, 'set_effect_slider'))
        g.effect_updown.OnEvent("Change", ObjBindMethod(this, 'set_effect_updown'))
        g.effect_edit.OnEvent("Change", ObjBindMethod(this, 'set_effect_edit'))
        g.delay_slider.OnEvent("Change", ObjBindMethod(this, 'set_delay_slider'))
        g.delay_updown.OnEvent("Change", ObjBindMethod(this, 'set_delay_updown'))
        g.delay_edit.OnEvent("Change", ObjBindMethod(this, 'set_delay_edit'))
        g.hover_cbox.OnEvent("Click", ObjBindMethod(this, 'set_hover_cbox'))
        g.save_ini.OnEvent("Click", ObjBindMethod(this, 'save_settings'))
        g.to_tray.OnEvent("Click", ObjBindMethod(this, 'minimize_to_tray'))

        ; Register exit routine for closing windows
        g.OnEvent("Close", ObjBindMethod(this, "__Delete"))

        ; Update and show options
        g.Submit()
        g.Show("w300 h350")
        return
    }

    ; Load the settings from the ini file
    get_settings() {
        cfg := this.cfg := A_ScriptDir "\" StrSplit(A_ScriptName, ".")[1] ".ini"
        if (!FileExist(cfg)) {
            FileAppend("", cfg)
            IniWrite((def_hover := True), cfg, "settings", "effect_hover")
            IniWrite((def_delay := 20), cfg, "settings", "effect_delay")
            IniWrite((def_detail := 5), cfg, "settings", "effect_detail")
        }
        this.effect_hover := IniRead(cfg, "settings", "effect_hover")
        this.effect_delay := IniRead(cfg, "settings", "effect_delay")
        this.effect_detail := IniRead(cfg, "settings", "effect_detail")
        return
    }

    ; Load the text for the GUI
    get_text() {
        text := {}
        text.hover := { 0: "The effect starts when you click on the desktop."
                      , 1: "The effect starts when you hover over the desktop."
                      , cb: "Triggered by hover." }
        text.detail := [
            "256 frames, {0, 1, 2, 3, 4, 5, ... 255}",
            "87 frames, {0, 3, 6, 9, 12, 15, ... 255}",
            "52 frames, {0, 5, 10, 15, 20, 25, ... 255}",
            "18 frames, {0, 15, 30, 45, 60, 75, ... 255}",
            "16 frames, {0, 17, 34, 51, 68, 85, ... 255}",
            "6 frames, {0, 51, 102, 153, 204, 255}",
            "4 frames, {0, 85, 170, 255}",
            "2 frames, on-off, {0, 255}" ]
        text.delay := "Delay between two frames in ms." "`n`n"
                    . "Recommended: between 20 and 100, 0 to ignore."
        this.text := text
        return
    }

    ; Save the settings to the ini file
    save_settings(*) {
        global fn
        this.g.Submit(False)
        ; Write the new settings
        IniWrite(this.effect_detail, this.cfg, "settings", "effect_detail")
        IniWrite(this.effect_delay, this.cfg, "settings", "effect_delay")
        IniWrite(this.effect_hover, this.cfg, "settings", "effect_hover")
        ; Delete the previous timer, and create the new one
        SetTimer(fn, 0)
        fn := HideMyIcon.Bind(this.effect_hover, this.effect_step_size, this.effect_delay)
        SetTimer(fn, TIMER_UPDATE)
        Tooltip("The new settings have been saved and applied.")
        SetTimer(() => ToolTip(), -1500)
        return
    }
}
