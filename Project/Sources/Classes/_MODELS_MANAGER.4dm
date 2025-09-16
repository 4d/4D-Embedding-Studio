
property _class : cs:C1710._MODELS_MANAGER

property models : Collection
property currentItem : cs:C1710.Model
property itemPosition : Integer
property selectedItems : Collection

Class constructor
	
	//
	
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	// MARK:-Form method
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				// ________________________________________________________________________________
			: ($e.code=On Load:K2:1)
				
				Form:C1466.isSubform:=OBJECT Get subform container value:C1785#Null:C1517
				
				OBJECT SET VISIBLE:C603(*; "close"; Form:C1466.isSubform)
				
				If (Form:C1466.context=Null:C1517)
					
					return 
					
				End if 
				
				Form:C1466.modelsBackUp:=Form:C1466.models.copy()
				
				Case of 
						
						// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
					: (Form:C1466.context="add")
						
						Form:C1466.name:=Localized string:C991("model")
						var $i : Integer:=1
						
						Repeat 
							
							If (Form:C1466.models.query("name = :1"; Form:C1466.name).first()=Null:C1517)
								
								break
								
							End if 
							
							$i+=1
							Form:C1466.name:=[Localized string:C991("model"); String:C10($i)].join(" ")
							
						Until (False:C215)
						
						
						
						
						var $model:=cs:C1710.Model.new(Form:C1466.name)
						
						Form:C1466.models.push($model)
						Form:C1466.models.orderBy("name")
						Form:C1466.currentItem:=$model
						
						OBJECT SET TITLE:C194(*; "title"; Localized string:C991("newModel"))
						LISTBOX SET PROPERTY:C1440(*; "list"; lk selection mode:K53:35; lk none:K53:57)
						LISTBOX SELECT ROW:C912(*; "list"; Form:C1466.models.indexOf($model)+1)
						GOTO OBJECT:C206(*; "model")
						
						
						// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
				End case 
				
				//______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				If (Form:C1466.context=Null:C1517)
					
					GOTO OBJECT:C206(*; "list")
					
				Else 
					
					GOTO OBJECT:C206(*; "model")
					
				End if 
				
				// ________________________________________________________________________________
		End case 
		
		return 
		
	End if 
	
	// MARK:-Widget methods
	Case of 
			
			// ________________________________________________________________________________
		: ($e.objectName="close")
			
			If ($e.code#On Clicked:K2:4)
				
				return 
				
			End if 
			
			If (Form:C1466.isSubform)
				
				If (Form:C1466.context="add")
					
					
					
					
					
					
					
					
					
				End if 
				
				CALL SUBFORM CONTAINER:C1086(-1)
				FORM GOTO PAGE:C247(1)
				
			Else 
				
				CANCEL:C270
				
			End if 
			
			// ________________________________________________________________________________
	End case 