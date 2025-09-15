var $e:=FORM Event:C1606

If ($e.objectName=Null:C1517)
	
	Case of 
			
			// ________________________________________________________________________________
		: ($e.code=On Load:K2:1)
			
			OBJECT SET VISIBLE:C603(*; "close"; OBJECT Get subform container value:C1785#Null:C1517)
			
			If (Form:C1466.context=Null:C1517)
				
				return 
				
			End if 
			
			Form:C1466.modelsBackUp:=Form:C1466.models.copy()
			
			Case of 
					
					// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
				: (Form:C1466.context="add")
					
					var $model:=cs:C1710.Model.new(Form:C1466.name)
					Form:C1466.models.push($model)
					Form:C1466.models.orderBy("name")
					Form:C1466.currentItem:=$model
					Form:C1466.itemPosition:=Form:C1466.models.indexOf($model)
					
					LISTBOX SELECT ROW:C912(*; "list"; Form:C1466.models.indexOf($model)+1)
					
					// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
			End case 
			
			// ________________________________________________________________________________
		: ($e.code=On Bound Variable Change:K2:52)
			
			// <NOTHING MORE TO DO>
			
			// ________________________________________________________________________________
	End case 
	
Else 
	
	Case of 
			
			// ________________________________________________________________________________
		: ($e.objectName="close")
			
			CALL SUBFORM CONTAINER:C1086(-1)
			
			// ________________________________________________________________________________
	End case 
End if 