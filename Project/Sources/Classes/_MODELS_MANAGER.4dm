Class constructor
	
	BEEP:C151
	//
	
	
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				//______________________________________________________
			: ($e.code=On Load:K2:1)
				
				OBJECT SET VISIBLE:C603(*; "close"; OBJECT Get subform container value:C1785#Null:C1517)
				
				//______________________________________________________
			: ($e.code=On Resize:K2:27)
				
				//
				
				//______________________________________________________
		End case 
		
		
		return 
		
	End if 
	
	Case of 
			
			//______________________________________________________
		: ($e.objectName="backButton")
			
			BEEP:C151
			
			//______________________________________________________
		: ($e.objectName="close")
			
			//Form.me.close()
			CALL SUBFORM CONTAINER:C1086(-1)
			
			//______________________________________________________
	End case 