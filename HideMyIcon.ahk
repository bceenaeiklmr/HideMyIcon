; Script     HideMyIcon.ahk
; License:   MIT License
; Author:    Bence Markiel (bceenaeiklmr)
; Github:    https://github.com/bceenaeiklmr/HideMyIcon
; Date       22.10.2022
; Version    0.0.3

#SingleInstance, Force
#Persistent
SetBatchLines, -1
SetWindelay, -1
SetWorkingDir, %A_scriptDir%

global HMI := new HideMyIcon()

SleepText := "Sleep in fade effect (ms)" "`n`n"
	   . "Recommended: between 15 and 50" "`n"
	   . "0,-1, no sleep" "`n"

EffectText := [ "256 frames, transp: 0,1,2,3,4,5 ..."
	      , "87 frames, transp: 0,3,6,9,12,15, ..."
	      , "52 frames, transp: 0,5,10,15,20,25, ..."
	      , "18 frames, transp: 0,15,30,45,60,75, ..."
	      , "16 frames, transp: 0,17,34,51,68,85, ..."
	      , "6 frames, transp: 0,51,102,153,204,255"
	      , "4 frames, transp: 0,85,170,255"
	      , "2 frames, instant, on-off, transp: 0,255" ]

HoverText := { 0 : "The effect starts when you click on the desktop."
             , 1 : "The effect starts when you hover over the desktop." }

; Main Gui
Gui, Settings:New
Gui, Settings:+hwndHwndSettings
Gui, Settings:Font, s7
; Animation slider
Gui, Settings:Add, text,     % "x10 y20 w230", % "Animation"
Gui, Settings:Add, Slider,   % "x10 y40 w230 vEffectSlider Range1-8 gSliderEffect", % HMI.Speed
; Animation updown
Gui, Settings:Add, Edit,     % "x250 y40 w40"
Gui, Settings:Add, UpDown,   % "vEffectUpDown Range1-8 gUpDownEffectSpeed", % HMI.Speed
; Animation desc text
Gui, Settings:Add, text,     % "x20 w280 vEffectText", % EffectText[HMI.iniSpeed]
; Sleeptime slider text
Gui, Settings:Add, text,     % "x10 w230", % "`n" "Sleeptime"
; Sleeptime slider
Gui, Settings:Add, Slider,   % "x10 y145 w230 vSleepSlider Range-1-100 gSliderSleep", % HMI.Sleep
; Sleeptime updown
Gui, Settings:Add, Edit,     % "x250 y145 w40" 
Gui, Settings:Add, UpDown,   % "vSleepUpDown Range-1-100 gUpDownSleeptime", % HMI.Sleep
Gui, Settings:Add, text,     % "x20 vSleepText", % SleepText
; Hover or click
Gui, Settings:Add, CheckBox, % "x20 y260 vHover gHover Checked" (Hover:=HMI.Hover=1?1:0) , % "Effect starts on hover?"
Gui, Settings:Add, text,     % "x20 y280 w260 vHoverText"
; Buttons
Gui, Settings:Add, Button,   % "x100 y310 w100", % "&Save"
Gui, Settings:Add, Button,   % "x100 y340 w100", % "&ToTray"
; load from ini
GuiControl,, EffectSlider, % HMI.IniSpeed
GuiControl,, EffectUpDown, % HMI.IniSpeed
GuiControl,, SleepSlider,  % HMI.Sleep
GuiControl,, SleepUpDown,  % HMI.Sleep
Guicontrol,, HoverText,    % HoverText[HMI.Hover]
Gui, submit
; Show options
Gui, Settings:Show, % "w300 h370", % "HideMyIcon"
Menu, Tray, Standard
Menu, Tray, Add
Menu, Tray, Add, Show &GUI, ShowGui
Menu, Tray, Add, To &Tray, SettingsButtonToTray
return

; ######################

class HideMyIcon {
	
	Fade() {
		Desk := winActive( "ahk_id" this.hDesk ),
		Tray := winActive( "ahk_class Shell_TrayWnd" )		
		if !this.Hover
			step := (Desk||Tray) ? 1 : -1 ; (Desk) ? 1 : 0 -> clickink on the taskbar will not trigger the effect
		else if this.Hover
			step := (this.getMouse() ? 1 : -1)
		if (this.getMouse()~="ShowDesk|Tray")
			step := 1
		winGet, Transparent, Transparent, % "ahk_id" this.hIcon
		if (this.transparent+(step:=step*this.speed)=Transparent)
		|| (this.transparent+step>255||0>this.transparent+step)
			return
		winSet, % "Transparent", % ((this.transparent+=step)==0?1:this.transparent), % "ahk_id" . this.hIcon
		Sleep, % this.Sleep
		;tooltip(step "`n" transp "`n" this.speed "`n" this.mode)
	}

	getMouse() {
		MouseGetPos,,, id, ctrl
		WinGetClass, cls, % "ahk_id" id
		WinGetTitle, w, % "ahk_id" id
		return ((Ctrl~="TrayShowDesktopButton" && cls~="Shell_TrayWnd")
		     || (cls~="Progman|WorkerW" && w=="") ? "ShowDesk"
		      : (cls~="Progman|WorkerW") ? "Desktop"
		      : (cls~="Shell_TrayWnd") ? "Taskbar"
		      : (cls~="DFTaskbar") ? "DisplayFusion" : "") ; DF taskbar
	}
			
	__New() {	
		if !this.hDesk := winExist("ahk_class Progman") ; credit to SKAN
		    this.hDesk := winExist("ahk_class WorkerW")
		ControlGet, hIcon, hWnd,, SysListView321, % "ahk_id" this.hDesk
		this.hIcon := hIcon
		this.Ini()
		; AboveNormal priority makes the animation smoother for me
		Process, Priority, % "ahk_id" this.hDesk, AboveNormal 
		fn := ObjBindMethod(this, "Fade")
		this.fn := fn
		SetTimer, % fn, 10
		OnExit(objBindMethod(this, "RestoreIcons"))
	}

	Ini() {
		if !fileExist((this.cfg := A_ScriptDir "\" strSplit(A_ScriptName, ".").1 ".ini")) {
			fileAppend,,  % this.cfg 			
			IniWrite, 20, % this.cfg, % "Settings", % "Sleep"
			IniWrite, 5,  % this.cfg, % "Settings", % "Speed"
			IniWrite, 0,  % this.cfg, % "Settings", % "Hover"
		}
		IniRead, Sleep, % this.cfg, % "Settings", % "Sleep"
		IniRead, Speed, % this.cfg, % "Settings",  % "Speed"
		IniRead, Hover,  % this.cfg, % "Settings", % "Hover"
		this.iniSpeed := Speed,
		this.Speed := [1,3,5,15,17,51,85,255][Speed],
		this.Sleep := Sleep,
		this.Hover := Hover,
		this.Transparent := 255
	}

	RestoreIcons() {
		WinSet, Transparent, 255, % "ahk_id" this.hIcon
	}
			
}

SettingsButtonSave:
Gui, Submit, Nohide
IniWrite, % EffectSlider, % HMI.cfg, % "Settings", % "Speed"
IniWrite, % (HMI.Sleep:=SleepSlider),  % HMI.cfg, % "Settings", % "Sleep"
IniWrite, % (HMI.Hover:=Hover),  % HMI.cfg, % "Settings", % "Hover"
HMI.Speed := [1,3,5,15,17,51,85,255][EffectSlider]
fn := HMI.fn
SetTimer, % fn, Delete
fn := HMI.fn := ObjBindMethod(HMI, "Fade")
settimer, % fn, 10
Tooltip("The settings have been applied.")
return

UpDownEffectSpeed:
GuiControl,, EffectSlider, % EffectUpDown
GuiControl,, EffectText, % EffectText[EffectUpDown]
return

UpDownSleepTime:
GuiControl,, SleepSlider, % SleepUpDown
return

SliderEffect:
Guicontrol,, EffectUpDown, % EffectSlider
GuiControl,, EffectText, % EffectText[EffectSlider]
return

SliderSleep:
Guicontrol,, SleepUpDown, % SleepSlider
return

Hover:
Guicontrol,, HoverText, % HoverText[(HMI.Hover := Hover := !Hover)]
return

ShowGui:
Gui, %hWndSettings%:Show
return

SettingsButtonToTray:
Gui, %hWndSettings%:Hide
return

Tooltip(Strg, TimeOut:=1500) {
	Tooltip % Strg
	setTimer, RemoveTooltip, % -TimeOut
}

RemoveTooltip:
Tooltip
return
