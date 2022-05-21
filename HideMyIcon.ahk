
; #############################################################################

; Enjoy customizing!

; #############################################################################

;   Thank you!
;
; + SKAN DesktopIcons
; + EvilC LogTailerClass
; + anonymous1184
; + 0xB0BAFE77
; + G33kDude
; + errorseven
; + Maestrith AHK Studio
; + every Autohotkey contributor

; #############################################################################

#singleInstance, force
#persistent
setBatchLines, -1      			
setWindelay, -1    
setWorkingDir, %A_scriptDir%

; #############################################################################

hmi := new HideMyIcon()

; #############################################################################

SleeptimeText := "The elapsed time between two animation frames in ms" . "`n`n"
	       . "Recommended sleep between 15 and 50." "`n"
	       . "0,-1, no sleep." "`n"

EffectText := [ "256 frames, transparency: 0,1,2,3,4,5 ..." 
	      , "87 frames, transparency: 0,3,6,9,12,15, ..."
	      , "52 frames, transparency: 0,5,10,15,20,25, ..."
	      , "18 frames, transparency: 0,15,30,45,60,75, ..."
	      , "16 frames, transparency: 0,17,34,51,68,85, ..."
	      , "6 frames, transparency: 0,51,102,153,204,255"
	      , "4 frames, transparency: 0,85,170,255"
	      , "2 frames, instant, on-off, transparency: 0,255" ] 

HoverText := { 1 : "The effect starts when you hover over the desktop.", 0 : "The effect starts when you click on the desktop." }

; create the main gui
gui, Settings:new
gui, Settings:+hwndHwndSettings
gui, Settings:Font, s7
; animation slider
gui, Settings:Add, text,   % "x10 y20 w230", % "Animation"
gui, Settings:Add, Slider, % "x10 y40 w230 vEffectSlider Range1-8 gSliderEffect", % hmi.EffectSpeed  ; ToolTipBottom
; animation updown
gui, Settings:Add, Edit, % "x250 y40 w40"
gui, Settings:Add, UpDown, % "vEffectUpDown Range1-8 gUpDownEffectSpeed", % hmi.EffectSpeed
; animation description text
gui, Settings:Add, text, % "x20 w280 vEffectText", % EffectText[hmi.EffectSpeed] ;Default 4, 1 fastest, 8 slowest
; sleeptime slider text
gui, Settings:Add, text, % "x10 w230", % "`n" "Sleeptime"
; sleeptime slider
gui, Settings:Add, Slider, % "x10 y145 w230 vSleepSlider Range-1-100 gSliderSleep", % hmi.effectdelay
; sleeptime updown
gui, Settings:Add, Edit, % "x250 y145 w40" 
gui, Settings:Add, UpDown, % "vSleepUpDown Range-1-100 gUpDownSleeptime", % hmi.effectdelay
gui, Settings:Add, text, % "x20 vSleepText", % SleeptimeText
; hover or click
gui, Settings:Add, CheckBox, % "x20 y260 vEffectOnHover gOnHover", % "Effect on hover?"
gui, Settings:Add, text, % "x20 y280 w260 vHoverText"
guicontrol,, hovertext, % hoverText[hmi.Hover]
guicontrol,, effectonhover, % hmi.Hover
; buttons

gui, Settings:Add, Button, % "x110 y310 w80", % "&Preview"
gui, Settings:Add, Button, % " x20 y340 w80", % "&Apply"
gui, Settings:Add, Button, % "x200 y340 w80", % "&Default"
gui, Settings:Add, Button, % "x110 y340 w80", % "&To tray"
; show options
gui, Settings:Show, % "w300 h370", % "HideMyIcon"

menu, tray, Standard
menu, tray, Add
menu, tray, Add, Show &GUI, showgui

onExit( "restoreicon" )

return

; #############################################################################

; The only hotkey is needed for detecting the show desktop button in the tray.
; The left button behaves normally, except it activates the destop.

~Lbutton::
if ( A_TimeSinceThisHotkey < 100 )
	hmi.isMouseOverShowDeskButton()
return

; #############################################################################

class HideMyIcon {
	
	__New( effect := "linear", effectspeed := 1, effectDelay := 33, precisionsleep := 0, processpriority := "AboveNormal", showOn := "hover" )
	{	
		static init
		if init
			return init
		
		this.getHandle()
		this.ini()
		this.setPriority( processpriority )
		
		this.getframes( effect, this.effectspeed )
		this.sleepfn := func( ( precisionsleep ? "preciseSleep" : "Sleep" ) )
		this.ShowOn := ( this.hover = 1 ? "Hover" : ( this.hover = 0 ? "Click" : "" ) )
		
		winGet, transparency, % "transparent", % "ahk_id" this.hIcon
		this.transparency := transparency
		
		fn := objBindMethod( this, "Fade" )
		this.fadefn := fn
		
		this.start()
		
		init := this
	}
	
	Start()
	{
		fn := this.FadeFn
		setTimer, % fn, 10
	}
	
	Off()
	{
		fn := this.FadeFn
		setTimer, % fn, off
		this.RestoreIcon()
	}
	
	Pause()
	{
		static s
		fn := this.FadeFn
		setTimer, % fn, % s := ( !s || s = "Off" ) ? 10 : ( s = 10 ? "Off" : "" )
	}
	
	Fade()
	{	
		isDeskActive  := winActive( "ahk_id" this.hDesk )
		isTrayActive  := winActive( "ahk_class Shell_TrayWnd" )
		
		; the frame indicates whether to change the transparency of the icons or just do nothing
		if ( this.ShowOn = "Click" )
			frame := ( isDeskActive || isTrayActive ) ? 1 : ( ! isDeskActive && ! isTrayActive ? -1 : "" )
		else if ( this.ShowOn = "Hover" )
			frame := ( this.classUnderMouse() ? 1 : -1 )
		
		; if show desktop button is pressed the active title will be empty for a short amount of time
		if ( ! frame && this.ShowOn = "Click" )
		{
			winGetTitle, activeTitle
			winGetClass, activeClass
			if ( activeTitle = "" && activeClass ~= "Progman|WorkerW|Tray" )
				frame := 1
		}
		
		if !frame
			return
		else if this.frames.hasKey( this.framekey + frame )
		{	
			;critical, 30
			winSet, % "transparent", % this.frames[(this.framekey+=frame)], % "ahk_id" this.hIcon
			this.sleepfn.call( this.effectdelay )
		}	
		
	}
	
	getFrames( effect, effectspeed )
	{
		if !this.effect
			this.effect := {}
		
		if ( effect = "linear" )
		{
			this.effect.linear := []
			
			; find n between 0-255 where !mod( 255, n ), basically: 1,3,5,15,17,51,85,255
			while ( ( !n ? n := 1 : n++ ) != 256 )
				( !mod( 255, n ) ) ? this.effect.linear.push( n ) : ""
			
			; fill the transparent values
			for k, step in this.effect.linear
			{
				this.effect.linear[k] := [0]
				loop % ( 255 / step )
					this.effect.linear[k][A_index+1] := A_index * step
			}
			
			; load the frames
			this.frames := this.effect.linear[effectspeed]		
		}
		else if ( effect = "2pow" )
		{
			; not really smooth tbh :(
			this.effect.2pow := [0]
			loop 8
				this.effect.2pow.push( ( 2 ** A_index ) )
			--this.effect.2pow[9]	
			this.frames := this.effect.2pow
		}
		else if ( effect = "exponential" )
		{
			exponential := []
			while ( exponential[exponential.length()] != 2**8-1 )
				exponential.push(A_index**2-1)
			this.frames := exponential
		}
		
		; locate the actual frame
		winGet, transp, transparent, % "ahk_id" this.hdesk
		( !transp ) ? transp := 0 : ""			
			; if found set it
		for k, v in this.frames
			if ( v = transp )
				this.framekey := k	
	}
	
	getHandle()
	{
		if ! hDesk := winExist( "ahk_class Progman" )
			hDesk := winExist( "ahk_class WorkerW" )
		controlGet, hIcon, hwnd,, SysListView321, % "ahk_id" hDesk
		this.hdesk := hdesk
		this.hicon := hicon
	}
	
	classUnderMouse()
	{		
		MouseGetPos, x, y, WinUnderMouse ; 
		WinGetClass, className, % "ahk_id" WinUnderMouse
		return ( className ~= "Progman|WorkerW" ? "Desktop" : ( className ~= "Shell_TrayWnd" ? "Tray" : 0 ) )
	}
	
	isMouseOverShowDeskButton( AreaWidth := 5, AreaHeight := 40 )
	{			
		oldMode := A_coordModeMouse
		coordMode, mouse, screen
		mousegetPos, Mousex, Mousey	
		coordMode, mouse, % oldMode
		
		; if the icons are hidden and you click on one of them the desktop will not be activated and the animation will not start
		; as a workaround the desktop can be activated
		
		if ( Mousex >= A_screenWidth  - AreaWidth )
		&& ( Mousey >= A_screenHeight - AreaHeight )
		&& ( regExMatch( this.classUnderMouse(), "Desktop|Tray" ) )
		&& ( this.ShowOn = "Click" )
		&& ( !winActive( "ahk_id" this.hdesk ) ) ; "Program Manager ahk_class Progman ahk_exe Explorer.EXE"
		{
			winActivate, % "ahk_id" this.hdesk
			;a short delay is required until the window will be minimized
			sleep, 300
		}
		
	}
	
	Ini()
	{
		this.inifile := A_ScriptDir "\" strSplit( A_ScriptName, "." )[1] ".ini"
		if !fileExist( this.iniFile )
		{
			fileAppend, % "", % this.inifile
			_Sleeptime   := 20
			_EffectSpeed := 2
			_Hover       := 0
			; create default keys and values
			iniWrite, % _Sleeptime,   % this.inifile, % "settings", % "sleeptime"
			iniWrite, % _EffectSpeed, % this.inifile, % "settings", % "effectspeed"
			iniWrite, % _Hover,       % this.inifile, % "settings", % "hover"
		}
		iniRead, _Sleeptime,   % this.inifile, % "settings", % "sleeptime"
		iniRead, _EffectSpeed, % this.inifile, % "settings", % "effectspeed"
		iniRead, _Hover,       % this.inifile, % "settings", % "hover"
		this.effectspeed := _EffectSpeed
		this.effectdelay := _Sleeptime
		this.hover       := _Hover
	}
	
	setPriority( processpriority )
	{
		; set process priority, Normal, AboveNormal are allowed only
		if ( processpriority ~= "i)^A(boveNormal)?$|^N(ormal)?$" )
		{
			pidscript := dllCall( "GetCurrentProcessId" )
			process, priority, % pidscript, % processpriority
		}
	}
	
}

RestoreIcon()
{
	global
	winSet,  % "transparent", 255, % "ahk_id" hmi.hIcon
}

; #############################################################################

; Apply button

SettingsButtonApply:
gui, submit, nohide
; write the new settings
iniWrite, % effectslider,  % hmi.inifile, % "settings", % "effectspeed"
iniWrite, % sleepslider,   % hmi.inifile, % "settings", % "sleeptime"
iniWrite, % effectOnHover, % hmi.inifile, % "settings", % "hover"
; turn off the current timer
fn := hmi.fadeFn
setTimer, % fn, off
; select frames
hmi.frames := hmi.effect.linear[effectslider]
hmi.effectdelay := sleepslider
; start the new timer
fn := objBindMethod( hmi, "Fade" )
settimer, % fn, 10
tooltipfn := func( "settingstooltip" ).bind("The settings have been applied.")
settimer, % tooltipfn, -1
return

; #############################################################################

; Preview button

SettingsButtonPreview:
gui, submit, noHide
; save active settings
oldframes := hmi.frames
oldsleep  := hmi.effectdelay

( hmi.hover ? hmi.ShowOn := "click" : "" )

; turn of current timer
fn := hmi.fadeFn
settimer, % fn, off
; get the new frames
hmi.frames := hmi.effect.linear[effectslider]
hmi.effectDelay := sleepslider
; calculate rough dur
previewDuration := ( hmi.frames.length() - 1 ) * ( sleepslider < 15 ? 15 : sleepslider )
if ( previewDuration * 2 > 10000 )
{
	msgbox, 0x4, % " HideMyIcon", % "The preview will take about " 
		                      . format( "{:.2f}", previewDuration * 2 / 1000 ) " seconds.`n`n"
		                      . "Do you want to continue?"
	ifmsgBox, No
		return
}
; start the preview anim
previewFn := objBindMethod( hmi, "Fade" )
setTimer, % previewFn, 10
;blockInput, on
; activate the desktop
winActivate, % "ahk_id" hmi.hDesk
; wait until fade in end
hmi.sleepfn.call( previewDuration )
;sleep, % effectDur
; activate gui
winActivate, % "ahk_id" hwndSettings
; wait until fade out ends
sleep, % previewduration
;blockinput off
; off preview timer
settimer, % previewFn, off
( hmi.hover ? hmi.ShowOn := "hover" : "" )
; restore original timer
hmi.frames := oldframes
hmi.effectDelay := oldsleep
setTimer, % fn, 10	
return

; #############################################################################

; Default button

SettingsButtonDefault:
msgbox, 0x4, % " HideMyIcon", % "Would you like to restore the default settings?"
ifmsgBox yes
{
	veffectslider := 5
	vsleepslider  := 25
	vhover        := 0
	iniWrite, % veffectslider, hmi.inifile, % "settings", % "effectspeed" 
	iniWrite, % vsleepslider,  hmi.inifile, % "settings", % "sleeptime"
	iniWrite, % vhover,        hmi.inifile, % "settings", % "hover"
	guiControl,, EffectSlider,  % veffectslider
	guiControl,, EffectUpdown,  % veffectslider
	guiControl,, EffectText,    % FadeEffectText[veffectslider]
	guiControl,, SleepSlider,   % vSleepSlider
	guiControl,, SleepUpDown,   % vSleepSlider
	guicontrol,, hovertext,     % hoverText[vhover]
	guicontrol,, effectonhover, % hmi.Hover
	
	; off preview timer
	fn := hmi.fadeFn
	settimer, % fn, off
	; restore original timer
	hmi.effectdelay := sleepslider
	hmi.effect.linear[effectslider]
	setTimer, % fn, 10
	tooltipfn := func( "settingstooltip" ).bind("The default settings have been restored.")
	settimer, % tooltipfn, -1
} 
return

; #############################################################################

UpDownEffectSpeed:
guiControl,, EffectSlider, % EffectUpDown
guiControl,, EffectText, % EffectText[EffectUpDown]
return

UpDownSleepTime:
guiControl,, SleepSlider, % SleepUpDown
; add text
return

SliderEffect:
guicontrol,, EffectUpDown, % EffectSlider
guiControl,, EffectText, % EffectText[EffectSlider]
return

SliderSleep:
guicontrol,, SleepUpDown, % SleepSlider
return

OnHover:
gui, submit, noHide
hmi.ShowOn := ( EffectOnHover ? "hover" : "click" )
guicontrol,, hovertext, % hovertext[EffectOnHover]
return

ShowGui:
gui, %HwndSettings%:show
return

SettingsButtonToTray:
gui, %HwndSettings%: hide
return

; #############################################################################

; high precision sleep, high cpu usage

preciseSleep( ms := 10 )
{
	; thank you nuj! https://www.reddit.com/r/AutoHotkey/comments/c2937u/accurate_sleep/
	
	static freq
	if !freq
		dllCall( "QueryPerformanceFrequency", "Int64*", freq )
	dllCall( "QueryPerformanceCounter", "Int64*", before )
	while ( ( ( after - before ) / freq * 1000 ) < ms )
		dllCall("QueryPerformanceCounter", "Int64*", after )
	return  ( ( after - before ) / freq * 1000 ) 
}

; #############################################################################

sleep( ms )
{
	sleep % ms
}

; #############################################################################

settingstooltip( strg, timeout := 1500 )
{
	tooltip % strg
	sleep, % timeout
	tooltip
}

; #############################################################################
