//%attributes = {"shared":true}
#DECLARE($name : Text)

var $winRef:=Open form window:C675("MODELS_WIZARD"; Plain form window:K39:10; Horizontally centered:K39:1; At the top:K39:5; *)

Case of 
		
		// ______________________________________________________
	: (Count parameters:C259=0)
		
		// <NOTHING MORE TO DO>
		
		// ______________________________________________________
	: ($name="new")
		
		CALL FORM:C1391($winref; Formula:C1597(Form:C1466.newModel()))
		
		// ______________________________________________________
	Else 
		
		CALL FORM:C1391($winref; Formula:C1597(Form:C1466.selectModel($name)))
		
		// ______________________________________________________
End case 

DIALOG:C40("MODELS_WIZARD")
CLOSE WINDOW:C154($winRef)