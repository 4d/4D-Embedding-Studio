var $e:=FORM Event:C1606

If ($e.objectName=Null:C1517)
	
	Case of 
			
			// ______________________________________________________
		: ($e.code=On Load:K2:1)
			
			SET TIMER:C645(-1)
			
			// ______________________________________________________
		: ($e.code=On Timer:K2:25)
			
			SET TIMER:C645(0)
			
			If (OBJECT Get subform container value:C1785#Null:C1517)  // Edition
				
				// The name cannot be changed at this stage
				OBJECT SET ENABLED:C1123(*; "name"; False:C215)
				OBJECT SET RGB COLORS:C628(*; "name"; -1; "transparent")
				
			End if 
			
			// ______________________________________________________
	End case 
	
	return 
	
End if 

var $caller:=Form:C1466
var $model : Object:=$caller.model

If ($e.code=On Data Change:K2:15)\
 && (OBJECT Get subform container value:C1785#Null:C1517)
	
	// The name cannot be changed at this stage
	///* #17323
	//The model name shall be unique.
	//*/
	//If ($caller.models.extract("name").includes($model.name))
	//$caller._popError(\
		Replace string(Localized string("theModelNameMustBeUnique"); "{name}"; $model.name))
	//GOTO OBJECT(*; "name")
	//return 
	//End if 
	
/* #17322
For each model, the name, api Key and model are required.
*/
	var $t : Text
	For each ($t; ["name"; "model"; "apiKey"])
		
		If (Length:C16(String:C10($model[$t]))=0)
			
			$caller._popError(\
				Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991($t)))
			
			GOTO OBJECT:C206(*; $t)
			
			return 
			
		End if 
	End for each 
	
	CALL SUBFORM CONTAINER:C1086(-1)
	
End if 

Case of 
		
		// ______________________________________________________
	: ($e.objectName="modelMenu")  // Menu of available models
		
		var $curModel:=String:C10($model.model)  // .model)
		var $menu:=cs:C1710.menu.new()
		
		var $id : Text
		For each ($id; $caller.getAvailableModels("id"))
			
			$menu.append($id; $id).mark($curModel=$id)
			
		End for each 
		
		If ($menu.popup($curModel).selected)\
			 && ($menu.choice#$curModel)
			
			// Set the model name
			$model.model:=$menu.choice
			
		End if 
		
		// ______________________________________________________
	: ($e.objectName="done")
		
/* #17323
The model name shall be unique.
*/
		If ($caller.models.extract("name").includes($model.name))
			
			$caller._popError(\
				Replace string:C233(Localized string:C991("theModelNameMustBeUnique"); "{name}"; $model.name))
			
			GOTO OBJECT:C206(*; "name")
			
			return 
			
		End if 
		
/* #17322
For each model, the name, api Key and model are required.
*/
		For each ($t; ["name"; "model"; "apiKey"])
			
			If (Length:C16(String:C10($model[$t]))=0)
				
				$caller._popError(\
					Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991($t)))
				
				GOTO OBJECT:C206(*; $t)
				
				return 
				
			End if 
		End for each 
		
		ACCEPT:C269
		
		// ______________________________________________________
End case 