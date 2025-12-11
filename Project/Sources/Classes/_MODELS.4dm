Class extends _COMMON

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
	var $cur:=This:C1470.currentItem
	
	// MARK:- Form method
	If ($e.objectName=Null:C1517)
		
		Super:C1706.manager($e; "MODELS")
		
		Case of 
				
				// ________________________________________________________________________________
			: ($e.code=On Load:K2:1)
				
				OBJECT SET FORMAT:C236(*; "Header1"; "path:/.PRODUCT_RESOURCES/Images/WatchIcons/Watch_693.png")
				OBJECT SET VISIBLE:C603(*; "noModel"; This:C1470.models.length=0)
				
				// ______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				This:C1470.listManager({code: On Selection Change:K2:29})
				
				// ______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				//
				
				// ______________________________________________________
			: ($e.code=On Unload:K2:2)
				
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
			var $using:=This:C1470.vectorsUsingTheModel($cur.name)
			
			If ($using.length>0)
				
				This:C1470._popError(Replace string:C233(Replace string:C233(Localized string:C991("thisModelCannotBeDeletedBecauseItIsUsed"); "{vector}"; $using[0].vectorName); "{dataclass}"; $using[0].dataclassName))
				
				return 
				
			End if 
			
			CONFIRM:C162(Localized string:C991("areYouSureYouWantToDeleteThisModel"))
			
			If (Bool:C1537(OK))
				
				This:C1470.deleteModel($cur.name)
				
				// Update UI
				LISTBOX SELECT ROW:C912(*; This:C1470.list; 0; lk remove from selection:K53:3)  // Unselect all
				SET TIMER:C645(-1)
				
			End if 
			
			// ______________________________________________________
		: ($e.objectName="name")
			
			This:C1470.nameManager($e)
			
			// ______________________________________________________
		: ($e.objectName="baseURLMenu")  // Menu of preconfigured providers
			
			GOTO OBJECT:C206(*; "baseURL")
			
			var $curbBase:=String:C10($cur.baseURL)
			var $menu:=cs:C1710.menu.new()
			
/*For each ($provider; Form._providers)*/
			var $provider : cs:C1710.Provider
			For each ($provider; This:C1470.PROVIDERS)
				
				$menu.append($provider.name; $provider.baseURL).mark($curbBase=$provider.baseURL)
				
			End for each 
			
			If ($menu.popup($curbBase).selected)\
				 && ($menu.choice#$curbBase)
				
				// Set the model baseURL
				$provider:=Form:C1466.PROVIDERS.query("baseURL = :1"; $menu.choice).first()
				
				$cur._provider:=$provider
				$cur.baseURL:=$menu.choice
				
				If ($provider.needToken#Null:C1517)
					
					$cur.apiKey:=$provider.endpoint.apiKey
					
				End if 
				
				Form:C1466.saveModels()
				
				If (This:C1470.updateUI())
					
					// Update mandatory or not fields labels
					OBJECT SET FONT STYLE:C166(*; "apiKey.label"; $cur._provider.needToken ? Bold:K14:2 : Plain:K14:1)
					
				End if 
			End if 
			
			// ______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	var $cur:=This:C1470.currentItem
	
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
		
		If ($cur#Null:C1517)
			
			$cur._provider:=This:C1470.PROVIDERS.query("baseURL = :1"; String:C10($cur.baseURL) || This:C1470.OPENAI).first()
			
		End if 
		
		This:C1470.previousItem:=OB Copy:C1225($cur)
		
		If (This:C1470.updateUI())
			
			OBJECT SET FONT STYLE:C166(*; "apiKey.label"; $cur._provider.needToken ? Bold:K14:2 : Plain:K14:1)
			
		End if 
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listMetaInfo($me : cs:C1710.Model) : Object
	
	var $meta:={}
	
	If (This:C1470.isModelUsed($me.name))
		
		$meta.fontWeight:="bold"
		
	End if 
	
	return $meta
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function nameManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	var $cur:=This:C1470.currentItem
	
	If ($e.code=On Data Change:K2:15)
		
/* #17323
The model name shall be unique.
*/
		
		If (This:C1470.models.query("name = :1 & _uid != :2"; $cur.name; $cur._uid).length>0)
			
			Form:C1466._popError(\
				Replace string:C233(Localized string:C991("theModelNameMustBeUnique"); "{name}"; $cur.name))
			
			$cur.name:=This:C1470.previousItem.name
/* TOUCH */This:C1470.models:=This:C1470.models
			
			GOTO OBJECT:C206(*; "name")
			
			return 
			
		Else 
			
			var $model:=This:C1470.models.query("name= :1"; This:C1470.previousItem.name)
			
			This:C1470.saveModels()
			
			var $c:=This:C1470.vectorsUsingTheModel(This:C1470.previousItem.name)
			
			If ($c.length>0)
				
				CONFIRM:C162(Replace string:C233(Localized string:C991("theModelIsUsedByOneOrMoreVectors"); "{name}"; This:C1470.previousItem.name))
				
				If (Bool:C1537(OK))
					
					var $vector : cs:C1710.Vector
					For each ($vector; $c)
						
						$vector.model:=$cur.name
						
					End for each 
					
					This:C1470.saveVectors()
					
					// TODO: Touch for update the vectors' window if opened
					
					If (Num:C11(Storage:C1525.studio.EMBEDDINGS)#0)
						
						var $old : Text:=This:C1470.previousItem.name
						var $new : Text:=$cur.name
						CALL FORM:C1391(Storage:C1525.studio.EMBEDDINGS; Formula:C1597(Form:C1466.modelUpdateName($old; $new)))
						
					End if 
				End if 
				
				This:C1470.previousItem.name:=$cur.name
				
			End if 
		End if 
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function selectModel($name : Text)
	
	This:C1470.currentItem:=This:C1470.models.query("name = :1"; $name).first()
	
	If (This:C1470.currentItem#Null:C1517)
		
		// Update UI
		var $index:=This:C1470.models.indexOf(This:C1470.currentItem)
		LISTBOX SELECT ROW:C912(*; This:C1470.list; $index+1; lk replace selection:K53:1)
		
	End if 
	
	//SET TIMER(-1)
	If (This:C1470.updateUI())
		
		OBJECT SET FONT STYLE:C166(*; "apiKey.label"; Bool:C1537(This:C1470.currentItem._provider.needToken) ? Bold:K14:2 : Plain:K14:1)
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function newModel()
	
/* #17323
The model name shall be unique.
*/
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
	
	If (Num:C11(Storage:C1525.studio.EMBEDDINGS)#0)
		
		//CALL FORM(Storage.studio.EMBEDDINGS; Formula(Form.updateModel($name)))
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function deleteModel($name : Text)
	
	var $c:=This:C1470.models.indices("name = :1"; $name)
	
	If ($c.length>0)
		
		This:C1470.models.remove($c[0])
		This:C1470.saveModels()
		
	End if 
	