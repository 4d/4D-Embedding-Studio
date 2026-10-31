//%attributes = {}
#DECLARE() : Integer

/*#17300
In project mode, if the “4D Embeddings Studio” component is loaded, in the “Design > Embeddings Studio...” menu, 
a “Embeddings Studio” item allows you to open the wizard window.
*/

var $form:="EMBEDDINGS"
var $openDial : Boolean

If (Num:C11(Storage:C1525.studio[$form])=0)
	
	// Definitions can still be edited without 4D AIKit, but no model can be listed or called
	If (Not:C34(cs:C1710._AIKit.me.isAvailable))
		cs:C1710._Dialog.me.alert(cs:C1710._AIKit.me.missingReason)
	End if 
	
	// Create the window
	var $winRef:=Open form window:C675($form; Plain form window:K39:10; Horizontally centered:K39:1; At the top:K39:5; *)
	$openDial:=True:C214
	
Else 
	
	// Select the window
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