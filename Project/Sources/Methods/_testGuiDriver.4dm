//%attributes = {"invisible":true}
// Test helper (GUI tests, see cs._TestGui): waits for the studio window $formName to
// register in Storage.studio, asks it to play the scripted steps, and makes sure it gets
// closed. Runs in its own worker: the test process is busy in the window's blocking DIALOG.
#DECLARE($formName : Text)

var $win : Integer:=0
var $waited : Integer:=0

// up to ~10s for the window to load
While (($win=0) && ($waited<600))
	$win:=Num:C11(Storage:C1525.studio[$formName])
	If ($win=0)
		DELAY PROCESS:C323(Current process:C322; 6)
		$waited+=6
	End if
End while

If ($win#0)

	CALL FORM:C1391($win; Formula:C1597(cs:C1710._TestGui.me._play()))

	// up to ~30s for the steps to run and the window to close (On Unload resets the entry)
	$waited:=0
	While ((Num:C11(Storage:C1525.studio[$formName])=$win) && ($waited<1800))
		DELAY PROCESS:C323(Current process:C322; 6)
		$waited+=6
	End while

	If (Num:C11(Storage:C1525.studio[$formName])=$win)
		CALL FORM:C1391($win; Formula:C1597(CANCEL:C270))  // never leave the test process stuck in the dialog
	End if

End if

KILL WORKER:C1390
