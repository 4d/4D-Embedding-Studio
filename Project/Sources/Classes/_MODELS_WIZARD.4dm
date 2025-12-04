Class extends _WIZARD

property _detailFields:=[\
"name"; \
"baseURL"; \
"baseURLMenu"; \
"apiKey"; \
"model"; \
"modelMenu"; \
"organization"; \
"project"]

property previousItem : Object

Class constructor
	
	Super:C1705()
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	// MARK:- Form method
	If ($e.objectName=Null:C1517)
		
		Super:C1706.manager($e)
		
		Case of 
				
				// ________________________________________________________________________________
			: ($e.code=On Load:K2:1)
				
				OBJECT SET FORMAT:C236(*; "Header1"; "path:/.PRODUCT_RESOURCES/Images/WatchIcons/Watch_693.png")
				OBJECT SET VISIBLE:C603(*; "noModel"; This:C1470.models.length=0)
				
				// ______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				//
				
				// ______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				//
				
				// ________________________________________________________________________________
		End case 
		
		return 
		
	End if 
	
	// MARK:- Widget methods
	Case of 
			
			// ______________________________________________________
		: ($e.objectName=This:C1470.list)
			
			This:C1470.listManager($e)
			
			// ______________________________________________________
		: ($e.objectName="add")
			
			This:C1470.newModel()
			
			// ______________________________________________________
		: ($e.objectName="delete")
			
/* #17324
If the user tries to delete a model used by a vector, 
an error message shall warn them that this model is used by xxx and 4D shall not delete the model.
*/
			var $user:=This:C1470.isModelUsed(This:C1470.currentItem.name)
			
			If ($user#Null:C1517)
				
				This:C1470._popError(Replace string:C233(Replace string:C233(Localized string:C991("thisModelCannotBeDeletedBecauseItIsUsed"); "{vector}"; $user.vectorName); "{dataclass}"; $user.dataclassName))
				
				return 
				
			End if 
			
			CONFIRM:C162(Localized string:C991("areYouSureYouWantToDeleteThisModel"))
			
			If (Bool:C1537(OK))
				
				This:C1470.deleteModel(This:C1470.currentItem.name)
				
				// Update UI
				LISTBOX SELECT ROW:C912(*; This:C1470.list; 0; lk remove from selection:K53:3)  // Unselect all
				SET TIMER:C645(-1)
				
			End if 
			
			// ______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.code=On Selection Change:K2:29)  // ⚠️ This event must be enabled for both the list box AND the form.
		
		var $previous : cs:C1710.Model:=This:C1470.previousItem
		
		If ($previous#Null:C1517)
			
			If (Not:C34($previous.validate()))
				
				ALERT:C41($previous.errors.join("\r"))
				
				var $index:=This:C1470.models.indexOf($previous)
				LISTBOX SELECT ROW:C912(*; This:C1470.list; $index+1; lk replace selection:K53:1)
				
				return 
				
			End if 
		End if 
		
		If (This:C1470.currentItem#Null:C1517)
			
			This:C1470.currentItem._provider:=This:C1470.modelProvider
			
		End if 
		
		This:C1470.previousItem:=This:C1470.currentItem
		
		If (This:C1470.updateUI())
			
/*
var $provider:=This.modelProvider
OBJECT SET FONT STYLE(*; "apiKey.label"; Bool($provider.needToken) ? Bold : Plain)
*/
			OBJECT SET FONT STYLE:C166(*; "apiKey.label"; This:C1470.currentItem._provider.needToken ? Bold:K14:2 : Plain:K14:1)
			
		End if 
	End if 
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get modelProvider() : cs:C1710.Provider
	
	If (This:C1470.currentItem=Null:C1517)
		
		return 
		
	End if 
	
	return This:C1470._providers.query("baseURL = :1"; String:C10(This:C1470.currentItem.baseURL) || This:C1470._OPENAI).first()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function validate($model : cs:C1710.Model) : Boolean
	
	$model.errors:=$model.errors || []
	
	var $t : Text
	For each ($t; $model._provider.needToken ? ["name"; "apiKey"; "model"] : ["name"; "model"])
		
		var $error:=Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991($t))
		
		If (Length:C16(String:C10($model[$t]))=0)
			
			If (Not:C34($model.errors.includes($error)))
				
				$model.errors.push($error)
				
			End if 
			
		Else 
			
			var $index:=$model.errors.indexOf($error)
			
			If ($index#-1)
				
				$model.errors.remove($index)
				
			End if 
		End if 
	End for each 
	
	return $model.errors.length=0
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelContainerManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.code=-1)  // Update model
		
		This:C1470.saveModels()
		
		This:C1470.models:=This:C1470.models  // Touch collection to force redrawing
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function selectModel($name : Text)
	
	This:C1470.currentItem:=This:C1470.models.query("name = :1"; $name).first()
	
	If (This:C1470.currentItem#Null:C1517)
		
		// Update UI
		var $index:=This:C1470.models.indexOf(This:C1470.currentItem)
		LISTBOX SELECT ROW:C912(*; This:C1470.list; $index+1; lk replace selection:K53:1)
		
	End if 
	
	SET TIMER:C645(-1)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function newModel()
	
	var $name:=Localized string:C991("newModel")
	var $i : Integer
	
	var $c : Collection:=Form:C1466.models.extract("name")
	
	Repeat 
		
		If ($c.includes($name))
			
			$i+=1
			$name:=Localized string:C991("newModel")+String:C10($i; " ##")
			
		Else 
			
			break
			
		End if 
	Until (False:C215)
	
	var $model:=cs:C1710.Model.new($name)
	Form:C1466.models.push($model)
	This:C1470.models:=This:C1470.models.orderBy("name asc")
	This:C1470.selectModel($name)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function deleteModel($name : Text)
	
	var $c:=This:C1470.models.indices("name = :1"; $name)
	
	If ($c.length>0)
		
		This:C1470.models.remove($c[0])
		This:C1470.saveModels()
		
	End if 
	