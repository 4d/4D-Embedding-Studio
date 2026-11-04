//%attributes = {}
#DECLARE($skipNotRunning : Boolean) : Integer

// Opens the standalone embedding scheduler window (single instance).
// Can be launched from the host Design menu or from the Embedding Studio status bar.
// When the scheduler does not run, the SCHEDULER_NOT_RUNNING dialog is shown first
// ($skipNotRunning: GUI tests); closing it opens nothing.

var $form:="SCHEDULER"
var $openDial : Boolean

If (Num:C11(Storage:C1525.studio[$form])=0)

	If (Not:C34($skipNotRunning) && Not:C34(Bool:C1537(cs:C1710.Scheduler.me.status().started)))
		If (Not:C34(_SCHEDULER_NOT_RUNNING))
			return 0
		End if
	End if

	// Create the window
	var $winRef:=Open form window:C675($form; Plain form window:K39:10; Horizontally centered:K39:1; At the top:K39:5; *)
	$openDial:=True:C214

Else

	// Select the already-open window
	$winRef:=Num:C11(Storage:C1525.studio[$form])
	var $left; $top; $right; $bottom : Integer
	GET WINDOW RECT:C443($left; $top; $right; $bottom; $winRef)
	SET WINDOW RECT:C444($left; $top; $right; $bottom; $winRef)

End if

If ($openDial)

	If (Structure file:C489=Structure file:C489(*))  // DEV TESTS

		DIALOG:C40($form)
		CLOSE WINDOW:C154($winRef)

	Else

		DIALOG:C40($form; *)

	End if
End if

return $winRef
