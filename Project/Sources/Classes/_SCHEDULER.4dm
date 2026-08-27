/**
 Form class for the standalone SCHEDULER window.

 Edits the embedding scheduler configuration (mode / interval / daily) and drives
 the live runtime through cs.Scheduler.me (Force now / Start / Stop / Cancel).
 Opened as an independent window by _SCHEDULER_WIZARD.

 The form binds these dynamic variables (see SCHEDULER/form.4DForm):
   modeDisabled, modeInterval, modeDaily   radio group "mode"
   intervalHours                           interval: hours between runs (1..24)
   startFromNow, startFromLast             radio group "startFrom"
   dailyTime                               daily: "HH:MM"
   nextRunText, stateText, lastRunText, errorText   read-only status
**/

property scheduler : cs:C1710.Scheduler

// Form-bound variables (see SCHEDULER/form.4DForm dataSources)
property modeDisabled; modeInterval; modeDaily : Boolean
property startFromReference; startFromNow; startFromLast : Boolean
property intervalHours : Integer
property dailyTime : Text
property nextRunText; stateText; lastRunText; errorText : Text

// The saved interval anchor ("YYYY-MM-DDThh:mm:ss") behind the startFromReference radio.
property startReference : Text

// Error-area layout state and window geometry (drive the grow/shrink of the window).
// Vertical-layout bookkeeping (see _layout).
property _layoutKey : Text  // last applied layout signature; skips relayout when unchanged
property _buttonBar : Integer:=46  // reserved under the last section: buttons (26) + bottom margin (20)
property _appliedH : Integer:=400  // window content height last applied; MUST match the form's design height
property _appliedHD : Boolean:=False:C215  // to postpone resize of windows using timer, using this._appliedH value
property _activated : Boolean  // True once the window is shown (On Activate); gates the first resize

Class constructor
	
	This:C1470.scheduler:=cs:C1710.Scheduler.me
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Central event dispatcher, called by the FORM_MANAGER form method.
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				//______________________________________________________
			: ($e.code=On Load:K2:1)
				
				This:C1470.onLoad()
				
				//______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				// Window geometry is settled here; enable resizing and force one clean pass.
				This:C1470._activated:=True:C214
				This:C1470._layoutKey:=""
				This:C1470._layout()
				
				
				
				//______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				If (Bool:C1537(This:C1470._appliedHD))
					
					var $l; $t; $r; $b : Integer
					GET WINDOW RECT:C443($l; $t; $r; $b; Current form window:C827)
					
					SET WINDOW RECT:C444($l; $t; $r; $t+This:C1470._appliedH; Current form window:C827)
					
					This:C1470._appliedHD:=False:C215
					
				Else 
					This:C1470.paint()
				End if 
				//______________________________________________________
			: ($e.code=On Unload:K2:2)
				
				SET TIMER:C645(0)
				
				If (Storage:C1525.studio#Null:C1517)
					Use (Storage:C1525.studio)
						Storage:C1525.studio["SCHEDULER"]:=0
					End use 
				End if 
				
				//______________________________________________________
		End case 
		
		return 
		
	End if 
	
	Case of 
			
			//______________________________________________________
		: ($e.objectName="modeDisabled") || ($e.objectName="modeInterval") || ($e.objectName="modeDaily")
			
			// Set the flags from the clicked radio: during On Clicked the other group members are
			// not reliably zeroed yet, which would make _layout keep the previous mode (no reflow).
			Form:C1466.modeDisabled:=($e.objectName="modeDisabled")
			Form:C1466.modeInterval:=($e.objectName="modeInterval")
			Form:C1466.modeDaily:=($e.objectName="modeDaily")
			
			This:C1470._layout()
			This:C1470.preview()
			
			//______________________________________________________
		: ($e.objectName="intervalHours") || ($e.objectName="startFromReference") || ($e.objectName="startFromNow") || ($e.objectName="startFromLast") || ($e.objectName="dailyTime")
			
			This:C1470.onConfigEdit()
			
			//______________________________________________________
		: ($e.objectName="forceNow")
			
			This:C1470.scheduler.force()
			This:C1470.paint()
			
			//______________________________________________________
		: ($e.objectName="start")
			
			This:C1470.scheduler.start()
			This:C1470.paint()
			
			//______________________________________________________
		: ($e.objectName="stop")
			
			This:C1470.scheduler.stop()
			This:C1470.paint()
			
			//______________________________________________________
		: ($e.objectName="save")
			
			This:C1470.save()
			
			//______________________________________________________
		: ($e.objectName="close")
			
			CANCEL:C270
			
			//______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// On Load: register the window, load the saved config, arm a periodic status refresh.
Function onLoad()
	
	If (Storage:C1525.studio=Null:C1517)
		Use (Storage:C1525)
			Storage:C1525.studio:=New shared object:C1526("EMBEDDINGS"; 0; "MODELS"; 0; "SCHEDULER"; 0)
		End use 
	End if 
	
	Use (Storage:C1525.studio)
		Storage:C1525.studio["SCHEDULER"]:=Current form window:C827
	End use 
	
	This:C1470.load()
	
	SET TIMER:C645(60)  // refresh status roughly once a second
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Populates the form variables from the saved configuration.
Function load()
	
	var $cfg : Object:=This:C1470.scheduler.config()
	
	Form:C1466.modeDisabled:=($cfg.mode="disabled")
	Form:C1466.modeInterval:=($cfg.mode="interval")
	Form:C1466.modeDaily:=($cfg.mode="daily")
	
	Form:C1466.intervalHours:=$cfg.intervalHours
	Form:C1466.dailyTime:=$cfg.dailyTime
	
	// "counting from" selection (three radios sharing the "startFrom" group):
	//   • reference : a saved instant is shown and selected
	//   • now       : selected only when there is no saved reference yet (fresh/legacy)
	//   • lastExecution
	This:C1470.startReference:=String:C10($cfg.startReference)
	var $isLast : Boolean:=($cfg.startFrom="lastExecution")
	var $hasRef : Boolean:=(Length:C16(This:C1470.startReference)>0)
	
	Form:C1466.startFromLast:=$isLast
	Form:C1466.startFromReference:=(Not:C34($isLast)) && $hasRef
	Form:C1466.startFromNow:=(Not:C34($isLast)) && (Not:C34($hasRef))
	
	// The reference radio's label is the saved instant; "the last execution" optionally shows its date.
	OBJECT SET TITLE:C194(*; "startFromReference"; $hasRef ? _schedulerFormatDate(This:C1470.startReference) : "")
	var $lastRun : Text:=($cfg.mode="disabled") ? "" : String:C10(This:C1470.scheduler.status().lastExecution)
	var $lastLabel : Text:=Localized string:C991("schedulerStartFromLast")
	If (Length:C16($lastRun)>0)
		$lastLabel:=$lastLabel+" ("+_schedulerFormatDate($lastRun)+")"
	End if 
	OBJECT SET TITLE:C194(*; "startFromLast"; $lastLabel)
	
	This:C1470._layout()
	This:C1470.paint()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Vertical layout: stacks the sections (config, status, error) top-down, sizing and hiding
	// each according to the mode and the error, then fits the window to the result. Keyed so it
	// only reflows when something actually changes.
Function _layout()
	
	var $interval : Boolean:=Bool:C1537(Form:C1466.modeInterval)
	var $daily : Boolean:=Bool:C1537(Form:C1466.modeDaily)
	var $hasRef : Boolean:=(Length:C16(This:C1470.startReference)>0)
	var $hasError : Boolean:=(Length:C16(String:C10(Form:C1466.errorText))>0)
	
	// Exact wrapped height of the error message (1..5 lines), measured at the box width.
	var $errTextH : Integer:=0
	If ($hasError)
		OBJECT SET VISIBLE:C603(*; "error"; True:C214)
		var $bw; $bh : Integer
		OBJECT GET BEST SIZE:C717(*; "error"; $bw; $bh; 416)
		$errTextH:=$bh
		If ($errTextH<18)
			$errTextH:=18
		End if 
		If ($errTextH>90)
			$errTextH:=90
		End if 
	End if 
	
	var $key : Text:=String:C10($interval)+String:C10($daily)+String:C10($hasRef)+String:C10($errTextH)
	If ($key=This:C1470._layoutKey)
		return 
	End if 
	This:C1470._layoutKey:=$key
	
	var $gap : Integer:=12
	var $y : Integer:=76  // below the fixed title + mode radios
	
	// ── config section ─────────────────────────────────────────
	Case of 
		: ($interval)
			var $refRow : Integer:=$hasRef ? 48 : 0
			var $nowRow : Integer:=$hasRef ? 72 : 48
			var $lastRow : Integer:=$hasRef ? 96 : 72
			var $panelH : Integer:=$hasRef ? 128 : 104
			This:C1470._sizeObj("schedulerConfigPanel"; 20; $y; 440; $panelH)
			This:C1470._moveObj("intervalHours.label"; 40; $y+24)
			This:C1470._moveObj("intervalHours"; 124; $y+22)
			This:C1470._moveObj("schedulerHoursLabel"; 190; $y+24)
			This:C1470._moveObj("startFromReference"; 40; $y+$refRow)
			This:C1470._moveObj("startFromNow"; 40; $y+$nowRow)
			This:C1470._moveObj("startFromLast"; 40; $y+$lastRow)
			OBJECT SET VISIBLE:C603(*; "schedulerConfigPanel"; True:C214)
			OBJECT SET VISIBLE:C603(*; "intervalHours"; True:C214)
			OBJECT SET VISIBLE:C603(*; "intervalHours.label"; True:C214)
			OBJECT SET VISIBLE:C603(*; "schedulerHoursLabel"; True:C214)
			OBJECT SET VISIBLE:C603(*; "startFromReference"; $hasRef)
			OBJECT SET VISIBLE:C603(*; "startFromNow"; True:C214)
			OBJECT SET VISIBLE:C603(*; "startFromLast"; True:C214)
			OBJECT SET VISIBLE:C603(*; "dailyTime"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTime.label"; False:C215)
			$y:=$y+$panelH+$gap
		: ($daily)
			This:C1470._sizeObj("schedulerConfigPanel"; 20; $y; 440; 56)
			This:C1470._moveObj("dailyTime.label"; 40; $y+20)
			This:C1470._moveObj("dailyTime"; 176; $y+18)
			OBJECT SET VISIBLE:C603(*; "schedulerConfigPanel"; True:C214)
			OBJECT SET VISIBLE:C603(*; "dailyTime"; True:C214)
			OBJECT SET VISIBLE:C603(*; "dailyTime.label"; True:C214)
			OBJECT SET VISIBLE:C603(*; "intervalHours"; False:C215)
			OBJECT SET VISIBLE:C603(*; "intervalHours.label"; False:C215)
			OBJECT SET VISIBLE:C603(*; "schedulerHoursLabel"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromReference"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromNow"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromLast"; False:C215)
			$y:=$y+56+$gap
		Else 
			// disabled: no config section at all
			OBJECT SET VISIBLE:C603(*; "schedulerConfigPanel"; False:C215)
			OBJECT SET VISIBLE:C603(*; "intervalHours"; False:C215)
			OBJECT SET VISIBLE:C603(*; "intervalHours.label"; False:C215)
			OBJECT SET VISIBLE:C603(*; "schedulerHoursLabel"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromReference"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromNow"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromLast"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTime"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTime.label"; False:C215)
	End case 
	
	// ── status section (fixed height) ──────────────────────────
	This:C1470._sizeObj("schedulerStatusPanel"; 20; $y; 440; 118)
	This:C1470._moveObj("schedulerDot"; 40; $y+22)
	This:C1470._moveObj("spinner"; 39; $y+21)
	This:C1470._moveObj("stateText"; 58; $y+18)
	This:C1470._moveObj("forceNow"; 230; $y+16)
	This:C1470._moveObj("start"; 335; $y+15)
	This:C1470._moveObj("stop"; 335; $y+15)
	This:C1470._moveObj("nextRun.label"; 40; $y+60)
	This:C1470._moveObj("nextRunText"; 150; $y+60)
	This:C1470._moveObj("lastRun.label"; 40; $y+86)
	This:C1470._moveObj("lastRunText"; 150; $y+86)
	$y:=$y+118+$gap
	
	// ── error section (0, or 1..5 lines) ───────────────────────
	If ($hasError)
		var $boxH : Integer:=$errTextH+16
		This:C1470._sizeObj("schedulerErrorBox"; 20; $y; 440; $boxH)
		This:C1470._sizeObj("error"; 32; $y+8; 416; $errTextH)
		OBJECT SET VISIBLE:C603(*; "schedulerErrorBox"; True:C214)
		OBJECT SET VISIBLE:C603(*; "error"; True:C214)
		$y:=$y+$boxH+$gap
	Else 
		OBJECT SET VISIBLE:C603(*; "schedulerErrorBox"; False:C215)
		OBJECT SET VISIBLE:C603(*; "error"; False:C215)
	End if 
	
	// ── buttons bar + fit the window to the content ──────────────────────────
	// The buttons sit a gap under the real last section; the window height must be that plus the
	// button bar. RESIZE FORM WINDOW takes a *delta* (pixels to add/remove), so we track the height
	// we last applied and move by the difference. Baseline is the form's designed height (_appliedH),
	// and we only resize once the window is settled (after On Activate) to keep the delta accurate.
	This:C1470._moveObj("close"; 300; $y)
	This:C1470._moveObj("save"; 384; $y)
	
	var $targetH : Integer:=$y+This:C1470._buttonBar
	If (This:C1470._activated && ($targetH#This:C1470._appliedH))
		This:C1470._appliedH:=$targetH
		This:C1470._appliedHD:=True:C214
		SET TIMER:C645(10)
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Moves an object to (left, top), preserving its width and height.
Function _moveObj($name : Text; $left; $top : Integer)
	
	var $l; $t; $r; $b : Integer
	OBJECT GET COORDINATES:C663(*; $name; $l; $t; $r; $b)
	OBJECT SET COORDINATES:C1248(*; $name; $left; $top; $left+($r-$l); $top+($b-$t))
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Places an object at (left, top) with an explicit width and height.
Function _sizeObj($name : Text; $left; $top; $width; $height : Integer)
	
	OBJECT SET COORDINATES:C1248(*; $name; $left; $top; $left+$width; $top+$height)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Reacts to an interval/daily/startFrom edit: clamps hours and refreshes the preview.
Function onConfigEdit()
	
	var $hours : Integer:=Num:C11(Form:C1466.intervalHours)
	If ($hours<1)
		$hours:=1
	End if 
	If ($hours>24)
		$hours:=24
	End if 
	Form:C1466.intervalHours:=$hours
	
	This:C1470.preview()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Persists the edited configuration through the Scheduler, then reloads the normalized values.
Function save()
	
	This:C1470.scheduler.saveConfig(This:C1470.currentConfig())
	
	ACCEPT:C269  // close the window, like Cancel does
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Builds a raw scheduler config object from the current form variables.
Function currentConfig() : Object
	
	var $mode : Text:="disabled"
	Case of 
		: (Bool:C1537(Form:C1466.modeInterval))
			$mode:="interval"
		: (Bool:C1537(Form:C1466.modeDaily))
			$mode:="daily"
	End case 
	
	// Resolve the "counting from" choice into a persistable startFrom + startReference.
	//   • last execution → "lastExecution" (reference kept for when the user switches back)
	//   • now            → "reference", capturing the current instant now
	//   • reference      → "reference", keeping the saved instant
	var $startFrom : Text:="reference"
	var $startReference : Text:=This:C1470.startReference
	Case of 
		: (Bool:C1537(Form:C1466.startFromLast))
			$startFrom:="lastExecution"
		: (Bool:C1537(Form:C1466.startFromNow))
			$startReference:=cs:C1710._ScheduleCalc.me._nowISO()
	End case 
	
	return {\
		mode: $mode; \
		intervalHours: Num:C11(Form:C1466.intervalHours); \
		startFrom: $startFrom; \
		startReference: $startReference; \
		dailyTime: String:C10(Form:C1466.dailyTime)}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Computes and displays the next run from the *current edits* (not necessarily saved yet).
Function preview()
	
	var $cfg : Object:=This:C1470.currentConfig()
	var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
	var $next : Object:=cs:C1710._ScheduleCalc.me.nextRun($cfg; This:C1470.scheduler._effectiveLastRun(); $state.armedAt)
	
	Form:C1466.nextRunText:=($next#Null:C1517) ? _schedulerFormatDate(String:C10($next.timestamp)) : "—"
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Refreshes the read-only status block and the enable state of the runtime buttons.
Function paint()
	
	var $status : Object:=This:C1470.scheduler.status()
	
	Form:C1466.stateText:=This:C1470._stateLabel($status)
	Form:C1466.lastRunText:=($status.lastExecution#Null:C1517) ? _schedulerFormatDate(String:C10($status.lastExecution)) : "—"
	Form:C1466.errorText:=($status.error#Null:C1517) ? String:C10($status.error) : ""
	
	This:C1470.preview()
	
	// The box shows ~5 lines; the full message is always on the help tip for longer errors.
	OBJECT SET HELP TIP:C1181(*; "error"; String:C10(Form:C1466.errorText))
	This:C1470._layout()
	
	// While running the spinner replaces the status dot; otherwise the dot shows the state color
	// (green when armed, grey when idle/disabled).
	var $running : Boolean:=Bool:C1537($status.running)
	var $active : Boolean:=$running || Bool:C1537($status.started)
	OBJECT SET VISIBLE:C603(*; "spinner"; $running)
	OBJECT SET VISIBLE:C603(*; "schedulerDot"; Not:C34($running))
	OBJECT SET RGB COLORS:C628(*; "schedulerDot"; ($active ? 0x002ECC71 : 0x009AA0A6); ($active ? 0x002ECC71 : 0x009AA0A6))
	
	// A single Start/Stop toggle occupies one slot; show whichever applies.
	OBJECT SET VISIBLE:C603(*; "start"; Not:C34(Bool:C1537($status.started)))
	OBJECT SET VISIBLE:C603(*; "stop"; Bool:C1537($status.started))
	var $canForceNow : Boolean:=Bool:C1537($status.started) && Not:C34(Bool:C1537($status.running))
	OBJECT SET ENABLED:C1123(*; "forceNow"; $canForceNow)
	
	// Explain why the button is greyed out: scheduler not started, vs. a run already in progress.
	Case of 
		: ($canForceNow)
			OBJECT SET HELP TIP:C1181(*; "forceNow"; "")
		: (Bool:C1537($status.running))
			OBJECT SET HELP TIP:C1181(*; "forceNow"; Localized string:C991("schedulerForceNowTipRunning"))
		Else 
			OBJECT SET HELP TIP:C1181(*; "forceNow"; Localized string:C991("schedulerForceNowTipStopped"))
	End case 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Maps a status object to a localized, human-readable state label.
Function _stateLabel($status : Object) : Text
	
	Case of 
		: (Bool:C1537($status.running))
			return Localized string:C991("schedulerStateRunning")
		: (Not:C34(Bool:C1537($status.enabled)))
			return Localized string:C991("schedulerStateDisabled")
		: (Bool:C1537($status.started))
			return Localized string:C991("schedulerStateArmed")
		Else 
			return Localized string:C991("schedulerStateIdle")
	End case 
	