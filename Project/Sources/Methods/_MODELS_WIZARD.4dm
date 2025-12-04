//%attributes = {"shared":true}
#DECLARE($name : Text) : Integer

var $winRef:=Open form window:C675("MODELS_WIZARD"; Plain form window:K39:10; Horizontally centered:K39:1; At the top:K39:5; *)

Case of 
		
		// ______________________________________________________
	: (Count parameters:C259=0)  // C++ call
		
		// <NOTHING MORE TO DO>
		
		// ______________________________________________________
	: ($name="new")
		
		CALL FORM:C1391($winref; Formula:C1597(Form:C1466.newModel()))
		
		// ______________________________________________________
	Else 
		
		CALL FORM:C1391($winref; Formula:C1597(Form:C1466.selectModel($name)))
		
		// ______________________________________________________
End case 

If (Structure file:C489=Structure file:C489(*)) || (Macintosh command down:C546 && Macintosh option down:C545)  // DEV TESTS
	
	DIALOG:C40("MODELS_WIZARD")
	CLOSE WINDOW:C154($winRef)
	
Else 
	
	DIALOG:C40("MODELS_WIZARD"; *)
	
	return $winRef
	
End if 