Class extends _WIZARD

property models; vectors : Collection

// Vector list
property currentItem : Object
property itemPosition : Integer
property selectedItems : Collection

// Vector details
property details:=["phrase"; "phraseLabel"; "models"; "modelsLabel"; "openModelsManager"; "more"]
property modelsDropdown : Object

// Embedded dialogs
property newModel; modelManager : cs:C1710.onBoard

property debug:=Structure file:C489=Structure file:C489(*)

Class constructor
	
	Super:C1705()
	
	This:C1470.settings:=This:C1470.readSettings()
	This:C1470.models:=This:C1470.readModels()
	This:C1470.vectors:=This:C1470.readVectors()
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				//______________________________________________________
			: ($e.code=On Load:K2:1)
				
				This:C1470.listManager($e)
				
				This:C1470.newModel:=cs:C1710.onBoard.new("on-board"; "NEW_MODEL"; {top: 40})
				This:C1470.newModel.me:=This:C1470.newModel
				
				This:C1470.modelManager:=cs:C1710.onBoard.new("on-board"; "MANAGE_MODELS"; {top: 40})
				This:C1470.modelManager.me:=This:C1470.modelManager
				
				This:C1470.modelsDropdownManager($e)
				
				SET TIMER:C645(-1)
				
				//______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				SET TIMER:C645(0)
				
				//______________________________________________________
		End case 
		
		return 
		
	End if 
	
	Case of 
			
			//______________________________________________________
		: ($e.objectName="list")
			
			This:C1470.listManager($e)
			
			//______________________________________________________
		: ($e.objectName="phrase")
			
			This:C1470.phraseManager($e)
			
			//______________________________________________________
		: ($e.objectName="more")
			
			This:C1470.moreManager($e)
			
			//______________________________________________________
		: ($e.objectName="models")
			
			This:C1470.modelsDropdownManager($e)
			
			//______________________________________________________
		: ($e.objectName="openModelsManager")
			
			This:C1470.modelManager.show()
			
			//______________________________________________________
		: ($e.objectName="backButton")  // Background button for embedded dialog boxes
			
			If (This:C1470.debug && Macintosh option down:C545)
				
				var $new:=This:C1470.newModel.visible
				var $manager:=This:C1470.modelManager.visible
				
				var $widget : Object:=This:C1470.newModel.instances.query("visible = true").first()\
					 || This:C1470.modelManager.instances.query("visible = true").first()
				
				If ($widget#Null:C1517)
					
					OBJECT SET VISIBLE:C603(*; $widget.name; False:C215)
					
				End if 
				
			Else 
				
				BEEP:C151
				
			End if 
			
			//______________________________________________________
		: ($e.objectName="save")
			
			This:C1470.saveVectors()
			This:C1470.saveModels()
			
			//______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	// TODO: Error help tips based on the line hovered
	
	If (This:C1470.currentItem=Null:C1517)
		
		var $t : Text
		For each ($t; This:C1470.details)
			
			OBJECT SET VISIBLE:C603(*; $t; False:C215)
			
		End for each 
		
		return 
		
	Else 
		
		For each ($t; This:C1470.details)
			
			OBJECT SET VISIBLE:C603(*; $t; True:C214)
			
		End for each 
		
		This:C1470.modelsDropdownUpdate(This:C1470.currentItem)
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listMetaInfo($me : cs:C1710.Vector) : Object
	
	If ($me#This:C1470.currentItem)\
		 && (($me[""].errors.length>0) || (Length:C16(String:C10($me.error))>0))
		
		return {cell: {dataclass: {stroke: "red"}; vector: {stroke: "red"}}}
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function moreManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	// TODO: More button
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function phraseManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	var $vector : cs:C1710.Vector:=This:C1470.currentItem
	var $me:="phrase"
	var $plainText:=ST Get plain text:C1092(*; $me)  //Get edited text
	
	Case of 
			
			// ______________________________________________________
		: ($vector=Null:C1517)
			
			return 
			
			// ______________________________________________________
		: ($e.code=On Mouse Move:K2:35)
			
			OBJECT SET HELP TIP:C1181(*; $me; $vector[""]#Null:C1517 ? String:C10($vector.helptip) : String:C10($vector.error))
			
			// ______________________________________________________
		: ($e.code=On Clicked:K2:4)
			
			If (Not:C34(Contextual click:C713))
				
				return 
				
			End if 
			
			var $menu:=cs:C1710.menu.new().edit(True:C214).line()
			var $embed:=cs:C1710.menu.new()
			
			var $attribute : Object
			For each ($attribute; $vector.supportedAttributes.orderBy("name"))
				
				$embed.append($attribute.name; "{"+$attribute.name+"}")
				
			End for each 
			
			If ($embed.itemCount()>0)
				
				$menu.append(":xliff:embed"; $embed)
				
			Else 
				
				$embed.release()
				
			End if 
			
			If (Not:C34($menu.popup().selected))
				
				return 
				
			End if 
			
			// 📌 Ignored if an associated action (for edit items)
			var $startSel; $endSel : Integer
			GET HIGHLIGHT:C209(*; $me; $startSel; $endSel)
			
			If (Length:C16($plainText)=0)
				
				var $newValue:="<span>"+$menu.choice+"</span>"
				
			Else 
				
				$newValue:=Substring:C12($plainText; 1; $startSel-1)+$menu.choice+Substring:C12($plainText; $endSel)
				
			End if 
			
			OBJECT SET VALUE:C1742($me; $newValue)
			
			$endSel:=$startSel+Length:C16($menu.choice)
			HIGHLIGHT TEXT:C210(*; $me; $endSel; $endSel)
			
			// Highlight any errors, if any
			$vector.phrase:=$vector.parsePhrase(ST Get plain text:C1092($newValue))
			
			// ______________________________________________________
		: ($e.code=On Before Keystroke:K2:6)
			
			var $char:=Keystroke:C390
			
			If (["<"; ">"; "&"].includes($char))
				
				// Special characters that must be encoded in styled text
				FILTER KEYSTROKE:C389("")
				GET HIGHLIGHT:C209(*; $me; $startSel; $endSel)
				ST SET TEXT:C1115(*; $me; $char; $startSel; $endSel)
				
			End if 
			
			// ______________________________________________________
		: ($e.code=On After Edit:K2:43)
			
			// Highlight any errors, if any
			$vector.phrase:=$vector.parsePhrase($plainText)
			
			// ______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			// Highlight any errors, if any
			ST SET TEXT:C1115(*; $me; $vector.parsePhrase($plainText); ST Start text:K78:15; ST End text:K78:16)
			
			// ______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelsDropdownManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	Case of 
			
			//______________________________________________________
		: ($e.code=On Load:K2:1)  // Define dropdown
			
			var $dropDown:={\
				values: This:C1470._getModelDropdownValues(); \
				index: -1; \
				placeholder: Localized string:C991("selectAModel")}
			
			$dropDown.currentValue:=$dropDown.placeholder
			This:C1470.modelsDropdown:=$dropDown
			
			//______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			$dropDown:=This:C1470.modelsDropdown
			
			If ($dropDown.currentValue=Localized string:C991("newModelItem"))  // Create a new model
				
				This:C1470.newModel.show()
				
				var $instance : Object:=This:C1470.newModel.instance
				$instance.data.name:=This:C1470.uniqueNewModelName($dropDown.values)
				$instance.data.models:=This:C1470.models
				
				return 
				
			End if 
			
			// Update current vector
			This:C1470.currentItem.model:=$dropDown.currentValue
			This:C1470.saveVectors()
			
			//______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelsDropdownUpdate($vector : cs:C1710.Vector)
	
	$vector:=$vector || This:C1470.currentItem
	
	If ($vector=Null:C1517)
		
		return 
		
	End if 
	var $dropDown : Object:=This:C1470.modelsDropdown
	
	If ($dropDown.values.includes($vector.model))
		
		$dropDown.index:=$dropDown.values.indexOf($vector.model)
		
	Else 
		
		$dropDown.index:=-1
		
	End if 
	
	$dropDown.currentValue:=$vector.model || $dropDown.placeholder
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _getModelDropdownValues() : Collection
	
	return This:C1470.models.extract("name").orderBy().combine(["-"; Localized string:C991("newModelItem")])
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function newModelCallback($instance : Object) : Boolean
	
	var $data : Object:=$instance.data
	
	Case of 
			
			// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
		: ($data.CANCELLED)
			
			// Restore dropdown
			This:C1470.modelsDropdownUpdate()
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
			If (This:C1470.modelsDropdown.values.includes($model.name))
				
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
			
			// Update the current vector
			This:C1470.currentItem.model:=$model.name
			This:C1470.saveVectors()
			
/* #17326
The structure of the models shall be saved in a JSON file named “vectors.json” in the “settings” folder.
*/
			This:C1470.models.push($model)
			This:C1470.saveModels()
			
			// Update the dropdown
			This:C1470.modelsDropdown.values:=This:C1470._getModelDropdownValues()
			
			This:C1470.modelsDropdownUpdate()
			
			// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
	End case 
	
	return True:C214  // Success
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelsManagerCallback($instance : Object) : Boolean
	
	// TODO: Models Manager
	
	return True:C214  // Success
	
	// MARK:- [PRIVATE]
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _popError($message : Text; $widget : Text; $target : Text)
	
	BEEP:C151
	ALERT:C41($message)
	var $o : Object:=OBJECT Get value:C1743($widget)
	$o.target:=$target
	OBJECT SET VALUE:C1742($widget; $o)