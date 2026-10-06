/**
 User-facing ALERT / CONFIRM, with a test seam.

 Code that talks to the developer calls cs._Dialog.me.alert() / .confirm() instead of
 ALERT / CONFIRM. Tests set _capture to a collection: nothing is displayed any more, every
 message is recorded there as {kind; message}, and confirm() answers from _answers, in
 order (False once they are used up). This keeps the dev helpers and the studio forms
 testable without anyone clicking, in the IDE as well as headless.

 Usage (tests):
   cs._Dialog.me._capture:=[]
   cs._Dialog.me._answers:=[True; False]
   …
   cs._Dialog.me._capture:=Null  // stop capturing so later code is unaffected
**/

// Test seam: when non-Null, nothing is displayed and every message is pushed here as {kind; message}.
property _capture : Collection

// Test seam: the answers confirm() gives while capturing, in order (False when exhausted).
property _answers : Collection:=[]

singleton Class constructor

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Displays $message.
Function alert($message : Text)

	If (This:C1470._capture#Null:C1517)

		This:C1470._capture.push({kind: "alert"; message: $message})
		return

	End if

	ALERT:C41($message)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Asks $message and returns True when the user accepted.
	// $okLabel / $cancelLabel are optional button titles.
Function confirm($message : Text; $okLabel : Text; $cancelLabel : Text) : Boolean

	If (This:C1470._capture#Null:C1517)

		This:C1470._capture.push({kind: "confirm"; message: $message})
		return (This:C1470._answers.length>0) ? Bool:C1537(This:C1470._answers.shift()) : False:C215

	End if

	Case of
		: (Length:C16($okLabel)=0)
			CONFIRM:C162($message)
		: (Length:C16($cancelLabel)=0)
			CONFIRM:C162($message; $okLabel)
		Else
			CONFIRM:C162($message; $okLabel; $cancelLabel)
	End case

	return (OK=1)
