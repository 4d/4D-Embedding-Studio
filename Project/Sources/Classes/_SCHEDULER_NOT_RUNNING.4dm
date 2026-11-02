/**
 Form class for the SCHEDULER_NOT_RUNNING dialog.

 Shown by _SCHEDULER_WIZARD before the scheduling panel when the scheduler does not run:
 says why nothing is recomputed and how to start it with the database (Settings option or
 code). "Start now" starts it for this session; OK just goes on to the panel.
**/

property optionA; optionB : Text  // the two "how to" lines, a bold label then plain text
property code : Text:="cs.EmbeddingStudio.Scheduler.me.start()"

Class constructor

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
			: ($e.code=On Unload:K2:2)

				If (Storage:C1525.studio#Null:C1517)
					Use (Storage:C1525.studio)
						Storage:C1525.studio["SCHEDULER_NOT_RUNNING"]:=0
					End use
				End if

				//______________________________________________________
		End case

		return

	End if

	Case of

			//______________________________________________________
		: ($e.objectName="openSettings")

			OPEN SETTINGS WINDOW("/Database/Security")

			//______________________________________________________
		: ($e.objectName="copy")

			SET TEXT TO PASTEBOARD(This:C1470.code)

			//______________________________________________________
		: ($e.objectName="help")

			OPEN URL:C673("https://github.com/4d/4D-Embedding-Studio/blob/main/Documentation/Classes/Scheduler.md#starting-the-scheduler"; *)

			//______________________________________________________
		: ($e.objectName="startNow")

			cs:C1710.Scheduler.me.start()
			ACCEPT:C269

			//______________________________________________________
		: ($e.objectName="ok")

			ACCEPT:C269

			//______________________________________________________
	End case

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// On Load: register the window, build the styled lines, fit the buttons to their captions.
Function onLoad()

	If (Storage:C1525.studio=Null:C1517)
		Use (Storage:C1525)
			Storage:C1525.studio:=New shared object:C1526("EMBEDDINGS"; 0; "MODELS"; 0; "SCHEDULER"; 0)
		End use
	End if

	Use (Storage:C1525.studio)
		Storage:C1525.studio["SCHEDULER_NOT_RUNNING"]:=Current form window:C827
	End use

	Form:C1466.optionA:=This:C1470._boldThen("schedulerNotRunningOptionA"; "schedulerNotRunningOptionAText")
	Form:C1466.optionB:=This:C1470._boldThen("schedulerNotRunningOptionB"; "schedulerNotRunningOptionBText")

	// Right-aligned pair, OK flush to the margin and "Start now" 12 px to its left; both widths
	// follow the localized captions ("Démarrer maintenant" is far wider than "Start now").
	This:C1470._fitButton("ok"; 88)
	This:C1470._fitButton("startNow"; 110)
	This:C1470._moveRight("ok"; 580)
	var $l; $t; $r; $b : Integer
	OBJECT GET COORDINATES:C663(*; "ok"; $l; $t; $r; $b)
	This:C1470._moveRight("startNow"; $l-12)

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Multistyle text: the localized $boldKey in bold, then $textKey in plain.
Function _boldThen($boldKey : Text; $textKey : Text) : Text

	return "<span style=\"font-weight:bold\">"+This:C1470._escape(Localized string:C991($boldKey))+"</span> "+This:C1470._escape(Localized string:C991($textKey))

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Escapes a plain string for a multistyle text value.
Function _escape($text : Text) : Text

	$text:=Replace string:C233($text; "&"; "&amp;")
	$text:=Replace string:C233($text; "<"; "&lt;")
	return Replace string:C233($text; ">"; "&gt;")

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Widens a button to its caption, never below $minWidth (the design width).
Function _fitButton($name : Text; $minWidth : Integer)

	var $l; $t; $r; $b; $bw; $bh : Integer
	OBJECT GET COORDINATES:C663(*; $name; $l; $t; $r; $b)
	OBJECT GET BEST SIZE:C717(*; $name; $bw; $bh)
	OBJECT SET COORDINATES:C1248(*; $name; $l; $t; $l+(($bw>$minWidth) ? $bw : $minWidth); $b)

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Moves an object so its right edge sits at $right, keeping its size.
Function _moveRight($name : Text; $right : Integer)

	var $l; $t; $r; $b : Integer
	OBJECT GET COORDINATES:C663(*; $name; $l; $t; $r; $b)
	OBJECT SET COORDINATES:C1248(*; $name; $right-($r-$l); $t; $right; $b)
