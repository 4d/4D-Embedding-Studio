property name; model; apiKey; baseURL; organization; project : Text
property focus:="name"

property _model:={}

property tool:=cs:C1710._WIZARD.new()

Class constructor
	
	//
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				// ______________________________________________________
			: ($e.code=On Load:K2:1)
				
				SET TIMER:C645(-1)
				
				// ______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				SET TIMER:C645(0)
				
				OBJECT SET SUBFORM CONTAINER VALUE:C1784(This:C1470)
				
				
				
				// ______________________________________________________
			: ($e.code=On Bound Variable Change:K2:52)
				
				// Update UI
				var $data : Object:=OBJECT Get subform container value:C1785
				
				//var $t
				//For each ($t; ["name"; "model"; "apiKey"; "baseURL"; "organization"; "project"])
				
				//This._model[$t]:=$data._model[$t]
				
				//End for each 
				
				If ($data.target#Null:C1517)
					
					GOTO OBJECT:C206(*; String:C10($data.target) || This:C1470.focus)
					OB REMOVE:C1226($data; "target")
					
				End if 
				
				// ______________________________________________________
		End case 
		
		return 
		
	End if 
	
	Case of 
			
			// ______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			// Update data
			//OBJECT SET SUBFORM CONTAINER VALUE({\
				name: This._model.name; \
				model: This._model.model; \
				apiKey: This._model.apiKey; \
				baseURL: This._model.baseURL; \
				organization: This._model.organization; \
				project: This._model.project\
				})
			
			CALL SUBFORM CONTAINER:C1086(-1)
			
			// ______________________________________________________
		: ($e.objectName="modelMenu")
			
			var $menu:=cs:C1710.menu.new()
			
			For each ($t; This:C1470.tool.getAvailableModels("id"))
				
				$menu.append($t; $t)
				
			End for each 
			
			If ($menu.popup().selected)
				
/*
This.data.model:=$menu.choice
$data:=OBJECT Get subform container value
$data.model:=$menu.choice
OBJECT SET SUBFORM CONTAINER VALUE($data)
*/
				This:C1470._model.model:=$menu.choice
				
				CALL SUBFORM CONTAINER:C1086(-1)
				
			End if 
			
			// ______________________________________________________
	End case 
	