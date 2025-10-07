Class extends _WIZARD

// Model list
property currentItem : cs:C1710.Model
property itemPosition : Integer
property selectedItems : Collection

// Embedded dialogs
property newModel : cs:C1710.onBoard

property isSubform : Boolean
property debug:=Structure file:C489=Structure file:C489(*)

Class constructor
	
	Super:C1705()
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	// MARK:- Form method
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				// ________________________________________________________________________________
			: ($e.code=On Load:K2:1)
				
				This:C1470.newModel:=cs:C1710.onBoard.new("on-board"; "NEW_MODEL"; {top: 40})
				//This.newModel.me:=This.newModel
				
				SET TIMER:C645(-1)
				
				// ______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				SET TIMER:C645(0)
				
				This:C1470.isSubform:=OBJECT Get subform container value:C1785#Null:C1517
				
				This:C1470.listManager()
				
				// ________________________________________________________________________________
			: ($e.code=On Bound Variable Change:K2:52)
				
				// ???????????????????
				
				// ______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				GOTO OBJECT:C206(*; "list")
				
				// ________________________________________________________________________________
		End case 
		
		return 
		
	End if 
	
	// MARK:- Widget methods
	Case of 
			
			//______________________________________________________
		: ($e.objectName="list")
			
			This:C1470.listManager($e)
			
			//______________________________________________________
		: ($e.objectName="add")
			
			This:C1470.newModel.show()
			
			var $instance : Object:=This:C1470.newModel.instance
			$instance.data.name:=This:C1470.uniqueNewModelName(This:C1470.models.extract("name"))
			$instance.data.models:=This:C1470.models
			
			//______________________________________________________
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
			
			This:C1470.deleteModel(This:C1470.currentItem.name)
			
			// Update UI
			LISTBOX SELECT ROW:C912(*; "list"; 0; lk remove from selection:K53:3)  // unselect all
			This:C1470.listManager($e)
			
			//______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If (This:C1470.currentItem=Null:C1517)
		
		OBJECT SET VISIBLE:C603(*; "model"; False:C215)
		OBJECT SET ENABLED:C1123(*; "delete"; False:C215)
		
		return 
		
	End if 
	
	var $o : Object:=OBJECT Get value:C1743("model")
	var $key : Text
	For each ($key; ["name"; "model"; "apiKey"; "baseURL"; "organization"; "project"])
		
		$o[$key]:=This:C1470.currentItem[$key]  // Null if any
		
	End for each 
	
	OBJECT SET VALUE:C1742("model"; $o)
	OBJECT SET VISIBLE:C603(*; "model"; True:C214)
	OBJECT SET ENABLED:C1123(*; "delete"; True:C214)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function selectModel($name : Text)
	
	This:C1470.currentItem:=This:C1470.models.query("name = :1"; $name).first()
	
	If (This:C1470.currentItem#Null:C1517)
		
		// Update UI
		var $index:=This:C1470.models.indexOf(This:C1470.currentItem)
		LISTBOX SELECT ROW:C912(*; "list"; $index+1; lk replace selection:K53:1)
		
	End if 
	
	SET TIMER:C645(-1)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function deleteModel($name : Text)
	
	var $c:=This:C1470.models.indices("name = :1"; $name)
	
	If ($c.length>0)
		
		This:C1470.models.remove($c[0])
		This:C1470.saveModels()
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function newModelCallback($instance : Object) : Boolean
	
	var $data : Object:=$instance.data
	
	Case of 
			
			// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
		: ($data.CANCELLED)
			
			// <NOTHING MORE TO DO>
			
			// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
		: ($data.ACCEPTED)
			
			var $new : Object:=$data.model
			var $model:=cs:C1710.Model.new($new.name; $new.model; $new.apiKey; {\
				baseURL: $new.baseURL; \
				organization: $new.organization; \
				project: $new.project\
				})
			
/* #17323
The model name shall be unique.
*/
			If (This:C1470.models.extract("name").includes($model.name))
				
				This:C1470._popError(\
					Replace string:C233(Localized string:C991("theModelNameMustBeUnique"); "{name}"; $model.name); \
					$instance.name; \
					"name")
				
				return 
				
			End if 
			
/* #17322
For each model, the name, api Key and model are required.
*/
			var $t : Text
			For each ($t; ["name"; "model"; "apiKey"])
				
				If (Length:C16(String:C10($model[$t]))=0)
					
					This:C1470._popError(\
						Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991($t)); \
						$instance.name; \
						$t)
					
					return 
					
				End if 
			End for each 
			
			This:C1470.models.push($model)
			This:C1470.saveModels()
			
			This:C1470.models:=This:C1470.models.orderBy("name asc")
			This:C1470.selectModel($model.name)
			
			// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
	End case 
	
	return True:C214  // Success
	