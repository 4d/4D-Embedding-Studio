property name; model; apiKey; baseURL; organization; project : Text
property focus:="name"

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
				
				// ______________________________________________________
			: ($e.code=On Bound Variable Change:K2:52)
				
				var $data : Object:=OBJECT Get subform container value:C1785
				
				OB GET PROPERTY NAMES:C1232(cs:C1710.Model.new(); $arrProperties)
				var $c:=[]
				ARRAY TO COLLECTION:C1563($c; $arrProperties)
				
				var $t
				For each ($t; ["name"; "model"; "apiKey"; "baseURL"; "organization"; "project"])
					
					This:C1470[$t]:=$data[$t]
					
				End for each 
				
				GOTO OBJECT:C206(*; String:C10($data.target) || This:C1470.focus)
				OB REMOVE:C1226($data; "target")
				
				// ______________________________________________________
		End case 
		
		return 
		
	End if 
	
	Case of 
			
			// ______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			OBJECT SET SUBFORM CONTAINER VALUE:C1784({\
				name: This:C1470.name; \
				model: This:C1470.model; \
				apiKey: This:C1470.apiKey; \
				baseURL: This:C1470.baseURL; \
				organization: This:C1470.organization; \
				project: This:C1470.project\
				})
			
			// ______________________________________________________
	End case 