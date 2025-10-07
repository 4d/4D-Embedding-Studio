//%attributes = {"shared":true}
#DECLARE($fromVS : Boolean; $name : Text)

// Display the main UI

If ($fromVS)
	
	var $bottom; $left; $right; $top : Integer
	
	var $winref:=Frontmost window:C447
	GET WINDOW RECT:C443($left; $top; $right; $bottom; $winref)
	var $offset : Integer:=40
	$winRef:=Open form window:C675("MODELS_WIZARD"; Movable form dialog box:K39:8; $left+$offset; $top+$offset)
	
Else 
	
	$winRef:=Open form window:C675("MODELS_WIZARD"; Structure file:C489=Structure file:C489(*) ? Plain form window:K39:10 : Movable form dialog box:K39:8; Horizontally centered:K39:1; At the top:K39:5; *)
	
End if 

If (Length:C16($name)>0)
	
	CALL FORM:C1391($winref; Formula:C1597(Form:C1466.selectModel($name)))
	
End if 

DIALOG:C40("MODELS_WIZARD")
CLOSE WINDOW:C154($winRef)