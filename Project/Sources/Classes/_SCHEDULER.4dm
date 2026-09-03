/**
 Form class for the standalone SCHEDULER window.

 Edits the embedding scheduler configuration (mode / interval / daily) and drives
 the live runtime through cs.Scheduler.me (Force now / Start / Stop / Cancel).
 Opened as an independent window by _SCHEDULER_WIZARD.

 The form binds these dynamic variables (see SCHEDULER/form.4DForm):
   modeDisabled, modeInterval, modeDaily   radio group "mode"
   intervalHours                           interval: hours between runs (1..24)
   startFromReference, startFromLast       radio group "startFrom": fixed rate vs fixed delay
   anchorText                              interval: the fixed-rate anchor, read-only
   dailyTime                               daily: the time of day, always "HH:MM"
   dailyTimeValue                          daily: the same instant as a Time, for the stepper
   stateText, lastRunText, errorText        read-only status
   summaryText                             the pending configuration restated in prose

 Everything in the config panel — the Reset-to-now button included — edits a *pending*
 configuration that only Save commits; the runtime buttons (Run now / Start / Stop) act at
 once. To keep the two apart, the next-run line says when it is showing an unsaved projection.
**/

property scheduler : cs:C1710.Scheduler

// Form-bound variables (see SCHEDULER/form.4DForm dataSources)
property modeDisabled; modeInterval; modeDaily : Boolean
property startFromReference; startFromLast : Boolean
property intervalHours : Integer
property dailyTime : Text

// The daily time as a Time, the value the stepper next to the field increments. The field
// itself stays text: 4D would render a time expression in its own format ("11:00:00",
// "11 hours…"), and this row must read "HH:MM" and nothing else.
property dailyTimeValue : Time
property stateText; lastRunText; errorText : Text
property anchorText; summaryText : Text

// The pending interval anchor ("YYYY-MM-DDThh:mm:ss") behind the startFromReference radio.
property startReference : Text

// The configuration as it stood when the window opened: the baseline the next-run line
// compares against to tell a saved schedule from an unsaved edit.
property _savedConfig : Object

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
		: ($e.objectName="startFromReference") || ($e.objectName="startFromLast")
			
			// Same caveat as the mode group above: the other member of the "startFrom" group is
			// not reliably zeroed yet during On Clicked, so set both flags from the clicked one.
			Form:C1466.startFromReference:=($e.objectName="startFromReference")
			Form:C1466.startFromLast:=($e.objectName="startFromLast")
			
			This:C1470.onConfigEdit($e)
			
			//______________________________________________________
		: ($e.objectName="intervalHours") || ($e.objectName="dailyTime")
			
			This:C1470.onConfigEdit($e)
			
			//______________________________________________________
		: ($e.objectName="dailyTimeStepper")
			
			// The stepper owns the Time; the field is repainted from it, then the usual
			// normalisation runs (which re-derives the Time, so the two cannot drift).
			Form:C1466.dailyTime:=This:C1470._formatHHMM(Form:C1466.dailyTimeValue)
			This:C1470.onConfigEdit($e)
			
			//______________________________________________________
		: ($e.objectName="resetAnchor")
			
			This:C1470.resetAnchor()
			
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
	This:C1470._savedConfig:=$cfg
	
	Form:C1466.modeDisabled:=($cfg.mode="disabled")
	Form:C1466.modeInterval:=($cfg.mode="interval")
	Form:C1466.modeDaily:=($cfg.mode="daily")
	
	Form:C1466.intervalHours:=$cfg.intervalHours
	Form:C1466.dailyTime:=This:C1470._formatHHMM(This:C1470._parseHHMM(String:C10($cfg.dailyTime)))
	Form:C1466.dailyTimeValue:=This:C1470._parseHHMM(Form:C1466.dailyTime)
	
	// The two real interval semantics, one radio each:
	//   • reference     : fixed rate — anchored on startReference, so it does not drift
	//   • lastExecution : fixed delay — N hours after the previous run finished
	// The anchor is always concrete: an absent one (fresh or legacy config) is stamped with
	// the current instant, so the row shows a real date and Save persists what is displayed.
	This:C1470.startReference:=String:C10($cfg.startReference)
	If (Length:C16(This:C1470.startReference)=0)
		This:C1470.startReference:=cs:C1710._ScheduleCalc.me._nowISO()
	End if 
	
	Form:C1466.startFromLast:=($cfg.startFrom="lastExecution")
	Form:C1466.startFromReference:=Not:C34(Bool:C1537(Form:C1466.startFromLast))
	This:C1470._paintAnchor()
	
	This:C1470._layout()
	This:C1470.paint()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Vertical layout: stacks the sections (config, status, error) top-down, sizing and hiding
	// each according to the mode and the error, then fits the window to the result. Keyed so it
	// only reflows when something actually changes.
Function _layout()
	
	var $interval : Boolean:=Bool:C1537(Form:C1466.modeInterval)
	var $daily : Boolean:=Bool:C1537(Form:C1466.modeDaily)
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
	
	// Exact wrapped height of the summary sentence (1..3 lines).
	var $sw; $sh : Integer
	OBJECT SET VISIBLE:C603(*; "summaryText"; True:C214)
	OBJECT GET BEST SIZE:C717(*; "summaryText"; $sw; $sh; 432)
	If ($sh<18)
		$sh:=18
	End if 
	If ($sh>54)
		$sh:=54
	End if 
	
	// Exact wrapped height of the purpose sentence at the top (1..4 lines): it states what the
	// scheduled task does, for a window that can be opened from the server admin with no context,
	// and translations wrap to different heights.
	var $iw; $ih : Integer
	OBJECT GET BEST SIZE:C717(*; "intro"; $iw; $ih; 440)
	If ($ih<16)
		$ih:=16
	End if 
	If ($ih>72)
		$ih:=72
	End if 
	
	var $key : Text:=String:C10($interval)+String:C10($daily)+String:C10($errTextH)+String:C10($sh)+String:C10($ih)
	If ($key=This:C1470._layoutKey)
		return 
	End if 
	This:C1470._layoutKey:=$key
	
	var $gap : Integer:=12
	
	// ── header: purpose sentence, then the mode radios under it ─
	This:C1470._sizeObj("intro"; 20; 16; 440; $ih)
	var $y : Integer:=16+$ih+$gap
	This:C1470._moveObj("modeDisabled"; 24; $y)
	This:C1470._moveObj("modeInterval"; 126; $y)
	This:C1470._moveObj("modeDaily"; 318; $y)
	$y:=$y+20+$gap
	
	// ── config section ─────────────────────────────────────────
	Case of 
		: ($interval)
			// Row 1: every N hours. Row 2: the fixed-rate radio, with its anchor and the
			// Reset-to-now button underneath. Row 3: the fixed-delay radio. The anchor is
			// always present, so the panel keeps a constant height.
			This:C1470._sizeObj("schedulerConfigPanel"; 20; $y; 440; 140)
			This:C1470._moveObj("intervalHours.label"; 40; $y+24)
			This:C1470._moveObj("intervalHours"; 124; $y+22)
			This:C1470._moveObj("schedulerHoursLabel"; 190; $y+24)
			This:C1470._moveObj("startFromReference"; 40; $y+52)
			This:C1470._moveObj("anchorText"; 62; $y+78)
			This:C1470._moveObj("resetAnchor"; 320; $y+74)
			This:C1470._moveObj("startFromLast"; 40; $y+106)
			OBJECT SET VISIBLE:C603(*; "schedulerConfigPanel"; True:C214)
			OBJECT SET VISIBLE:C603(*; "intervalHours"; True:C214)
			OBJECT SET VISIBLE:C603(*; "intervalHours.label"; True:C214)
			OBJECT SET VISIBLE:C603(*; "schedulerHoursLabel"; True:C214)
			OBJECT SET VISIBLE:C603(*; "startFromReference"; True:C214)
			OBJECT SET VISIBLE:C603(*; "anchorText"; True:C214)
			OBJECT SET VISIBLE:C603(*; "resetAnchor"; True:C214)
			OBJECT SET VISIBLE:C603(*; "startFromLast"; True:C214)
			OBJECT SET VISIBLE:C603(*; "dailyTime"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTimeStepper"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTime.label"; False:C215)
			$y:=$y+140+$gap
		: ($daily)
			This:C1470._sizeObj("schedulerConfigPanel"; 20; $y; 440; 56)
			This:C1470._moveObj("dailyTime.label"; 40; $y+20)
			This:C1470._moveObj("dailyTime"; 130; $y+18)
			This:C1470._moveObj("dailyTimeStepper"; 198; $y+16)
			OBJECT SET VISIBLE:C603(*; "schedulerConfigPanel"; True:C214)
			OBJECT SET VISIBLE:C603(*; "dailyTime"; True:C214)
			OBJECT SET VISIBLE:C603(*; "dailyTimeStepper"; True:C214)
			OBJECT SET VISIBLE:C603(*; "dailyTime.label"; True:C214)
			OBJECT SET VISIBLE:C603(*; "intervalHours"; False:C215)
			OBJECT SET VISIBLE:C603(*; "intervalHours.label"; False:C215)
			OBJECT SET VISIBLE:C603(*; "schedulerHoursLabel"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromReference"; False:C215)
			OBJECT SET VISIBLE:C603(*; "anchorText"; False:C215)
			OBJECT SET VISIBLE:C603(*; "resetAnchor"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromLast"; False:C215)
			$y:=$y+56+$gap
		Else 
			// disabled: no config section at all
			OBJECT SET VISIBLE:C603(*; "schedulerConfigPanel"; False:C215)
			OBJECT SET VISIBLE:C603(*; "intervalHours"; False:C215)
			OBJECT SET VISIBLE:C603(*; "intervalHours.label"; False:C215)
			OBJECT SET VISIBLE:C603(*; "schedulerHoursLabel"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromReference"; False:C215)
			OBJECT SET VISIBLE:C603(*; "anchorText"; False:C215)
			OBJECT SET VISIBLE:C603(*; "resetAnchor"; False:C215)
			OBJECT SET VISIBLE:C603(*; "startFromLast"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTime"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTimeStepper"; False:C215)
			OBJECT SET VISIBLE:C603(*; "dailyTime.label"; False:C215)
	End case 
	
	// ── status section (fixed height) ──────────────────────────
	This:C1470._sizeObj("schedulerStatusPanel"; 20; $y; 440; 92)
	This:C1470._moveObj("schedulerDot"; 40; $y+22)
	This:C1470._moveObj("spinner"; 39; $y+21)
	This:C1470._moveObj("stateText"; 58; $y+18)
	This:C1470._moveObj("forceNow"; 230; $y+16)
	This:C1470._moveObj("start"; 335; $y+15)
	This:C1470._moveObj("stop"; 335; $y+15)
	This:C1470._moveObj("lastRun.label"; 40; $y+60)
	This:C1470._moveObj("lastRunText"; 150; $y+60)
	$y:=$y+92+$gap
	
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
	
	// ── summary sentence ───────────────────────────────────────
	// The plain-language restatement of what is about to be saved, so the schedule can be
	// checked without reverse-engineering the radios above.
	This:C1470._sizeObj("summaryText"; 24; $y; 432; $sh)
	$y:=$y+$sh+$gap
	
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
	// Text → the time behind the field. Deliberately forgiving, because this is what every
	// edit goes through: "8" → 08:00, "830" / "8h30" → 08:30, "" → 00:00. Out-of-range or
	// unreadable input lands on midnight rather than on a random hour.
Function _parseHHMM($text : Text) : Time
	
	var $h; $m : Integer
	
	If (Position:C15(":"; $text)>0)
		
		var $parts : Collection:=Split string:C1554($text; ":")
		$h:=Num:C11($parts[0])
		$m:=($parts.length>1) ? Num:C11($parts[1]) : 0
		
	Else 
		
		// No separator: read the digits positionally, the way a clock is dictated.
		var $digits : Text:=""
		var $i : Integer
		For ($i; 1; Length:C16($text))
			If (Position:C15($text[[$i]]; "0123456789")>0)
				$digits:=$digits+$text[[$i]]
			End if 
		End for 
		
		Case of 
			: (Length:C16($digits)<=2)
				$h:=Num:C11($digits)
			: (Length:C16($digits)=3)
				$h:=Num:C11(Substring:C12($digits; 1; 1))
				$m:=Num:C11(Substring:C12($digits; 2; 2))
			Else 
				$h:=Num:C11(Substring:C12($digits; 1; 2))
				$m:=Num:C11(Substring:C12($digits; 3; 2))
		End case 
		
	End if 
	
	If (($h<0) || ($h>23))
		$h:=0
	End if 
	If (($m<0) || ($m>59))
		$m:=0
	End if 
	
	return Time:C179(String:C10($h; "00")+":"+String:C10($m; "00")+":00")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// The time → the "HH:MM" the field shows and the configuration stores. Seconds never
	// appear: the schedule has minute resolution, and _ScheduleCalc parses exactly two fields.
Function _formatHHMM($value : Time) : Text
	
	var $secs : Integer:=Num:C11($value)%86400
	If ($secs<0)
		$secs:=0
	End if 
	
	return String:C10($secs\3600; "00")+":"+String:C10(($secs%3600)\60; "00")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Reacts to an interval/daily/startFrom edit: clamps hours, rewrites the daily time in its
	// canonical "HH:MM" form (an emptied field falls back to midnight rather than staying
	// blank), re-syncs the stepper, and refreshes the preview.
Function onConfigEdit($event : Object)
	
	If ($event.code=On Clicked:K2:4)
		return 
	End if 
	
	var $hours : Integer:=Num:C11(Form:C1466.intervalHours)
	If ($hours<1)
		$hours:=1
	End if 
	If ($hours>24)
		$hours:=24
	End if 
	Form:C1466.intervalHours:=$hours
	
	Form:C1466.dailyTime:=This:C1470._formatHHMM(This:C1470._parseHHMM(String:C10(Form:C1466.dailyTime)))
	Form:C1466.dailyTimeValue:=This:C1470._parseHHMM(Form:C1466.dailyTime)
	
	This:C1470.preview()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Re-anchors the fixed-rate schedule on the current instant, and selects that mode.
	// Like every other control in the config panel it only edits the pending configuration;
	// Save is what commits it.
Function resetAnchor()
	
	This:C1470.startReference:=cs:C1710._ScheduleCalc.me._nowISO()
	Form:C1466.startFromReference:=True:C214
	Form:C1466.startFromLast:=False:C215
	
	This:C1470._paintAnchor()
	This:C1470.preview()
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Writes the anchor row: a labelled instant, never a bare timestamp.
Function _paintAnchor()
	
	Form:C1466.anchorText:=Replace string:C233(Localized string:C991("schedulerAnchorFrom"); "{date}"; _schedulerFormatDate(This:C1470.startReference))
	
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
	
	// Fixed delay keeps the anchor around, so switching back to fixed rate restores it.
	var $startFrom : Text:=Bool:C1537(Form:C1466.startFromLast) ? "lastExecution" : "reference"
	
	return {\
		mode: $mode; \
		intervalHours: Num:C11(Form:C1466.intervalHours); \
		startFrom: $startFrom; \
		startReference: This:C1470.startReference; \
		dailyTime: String:C10(Form:C1466.dailyTime)}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Computes and displays the next run from the *current edits* (not necessarily saved yet).
Function preview()
	
	var $cfg : Object:=This:C1470.currentConfig()
	var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
	var $next : Object:=cs:C1710._ScheduleCalc.me.nextRun($cfg; This:C1470.scheduler._effectiveLastRun(); $state.armedAt)
	
	// The config controls only commit on Save, while "Last run" above is a fact. The summary
	// says which one it is showing, so an unsaved projection is never read as the armed schedule.
	Form:C1466.summaryText:=This:C1470._summary($cfg; $next; This:C1470._isDirty($cfg))
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// True when the edited configuration differs from the one the window opened with.
Function _isDirty($cfg : Object) : Boolean
	
	var $saved : Object:=This:C1470._savedConfig
	If ($saved=Null:C1517)
		return False:C215
	End if 
	
	return (String:C10($cfg.mode)#String:C10($saved.mode))\
		 || (Num:C11($cfg.intervalHours)#Num:C11($saved.intervalHours))\
		 || (String:C10($cfg.startFrom)#String:C10($saved.startFrom))\
		 || (String:C10($cfg.startReference)#String:C10($saved.startReference))\
		 || (String:C10($cfg.dailyTime)#String:C10($saved.dailyTime))
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Restates the configuration and its next run in one sentence — the check a user can
	// actually perform, unlike reading back three radio groups.
Function _summary($cfg : Object; $next : Object; $pending : Boolean) : Text
	
	var $mark : Text:=$pending ? " "+Localized string:C991("schedulerSummaryPending") : ""
	
	If (String:C10($cfg.mode)="disabled")
		return Localized string:C991("schedulerSummaryDisabled")+$mark
	End if 
	
	var $text : Text:=""
	Case of 
		: (String:C10($cfg.mode)="daily")
			$text:=Replace string:C233(Localized string:C991("schedulerSummaryDaily"); "{time}"; String:C10($cfg.dailyTime))
		: (String:C10($cfg.startFrom)="lastExecution")
			$text:=Replace string:C233(Localized string:C991("schedulerSummaryIntervalLast"); "{hours}"; This:C1470._hoursLabel(Num:C11($cfg.intervalHours)))
		Else 
			$text:=Replace string:C233(Localized string:C991("schedulerSummaryInterval"); "{hours}"; This:C1470._hoursLabel(Num:C11($cfg.intervalHours)))
			$text:=Replace string:C233($text; "{anchor}"; _schedulerFormatDate(String:C10($cfg.startReference)))
	End case 
	
	If ($next=Null:C1517)
		return $text+$mark
	End if 
	
	var $stamp : Text:=String:C10($next.timestamp)
	var $tail : Text:=Replace string:C233(Localized string:C991("schedulerSummaryNext"); "{when}"; _schedulerFormatDate($stamp))
	$tail:=Replace string:C233($tail; "{relative}"; This:C1470._relative($stamp))
	
	return $text+" "+$tail+$mark
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// "1 hour" / "N hours".
Function _hoursLabel($hours : Integer) : Text
	
	If ($hours=1)
		return Localized string:C991("schedulerHoursOne")
	End if 
	
	return Replace string:C233(Localized string:C991("schedulerHoursMany"); "{n}"; String:C10($hours))
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// How far away a run is, in words — the part of a schedule people actually verify.
Function _relative($timestamp : Text) : Text
	
	var $seconds : Integer:=cs:C1710._ScheduleCalc.me.secondsUntil($timestamp)
	
	If ($seconds<=0)
		return Localized string:C991("schedulerRelDue")
	End if 
	If ($seconds<60)
		return Localized string:C991("schedulerRelSoon")
	End if 
	
	var $minutes : Integer:=Int:C8($seconds/60)
	If ($minutes<60)
		return Replace string:C233(Localized string:C991("schedulerRelMinutes"); "{n}"; String:C10($minutes))
	End if 
	
	var $hours : Integer:=Int:C8($minutes/60)
	var $text : Text:=Replace string:C233(Localized string:C991("schedulerRelHours"); "{h}"; String:C10($hours))
	return Replace string:C233($text; "{m}"; String:C10($minutes-($hours*60)))
	
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
	