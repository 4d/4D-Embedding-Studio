//%attributes = {"invisible":true}
#DECLARE() : Boolean

// Shows the "scheduler not running" dialog (modal). Returns True when the user goes on
// (OK or Start now), False when the window was closed.

var $form:="SCHEDULER_NOT_RUNNING"
var $winRef:=Open form window($form; Movable form dialog box; Horizontally centered; Vertically centered)

DIALOG($form)
CLOSE WINDOW($winRef)

return (OK=1)
