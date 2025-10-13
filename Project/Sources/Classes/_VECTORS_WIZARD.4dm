Class extends _WIZARD

// Vector list
property currentItem : Object
property itemPosition : Integer
property selectedItems : Collection

// Vector details
property details:=["phrase"; "phraseLabel"; "models"; "modelsLabel"; "openModelsManager"; "more"]
property modelsDropdown : Object

property debug:=Structure file:C489=Structure file:C489(*)

Class constructor
	
	Super:C1705()
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				//______________________________________________________
			: ($e.code=On Load:K2:1)
				
				This:C1470.listManager($e)
				This:C1470.modelsDropdownManager($e)
				
				SET TIMER:C645(-1)
				
				//______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				SET TIMER:C645(0)
				
				//______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				// TODO: Check vectors ?
				
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
			
			_MODELS_WIZARD(True:C214; String:C10(This:C1470.currentItem.model))
			
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
	
	var $menu:=cs:C1710.menu.new()
	
	$menu.append("🚧 Edit API key"; "editApiKey")
	
	If (This:C1470.debug)
		
		$menu.append("🚧 open setting file"; "openSettingFile")
		
	End if 
	
	If ($menu.popup().selected)
		
		Case of 
				
				//______________________________________________________
			: ($menu.choice="editApiKey")
				
				
				
				//______________________________________________________
			: ($menu.choice="openSettingFile")
				
				OPEN URL:C673(This:C1470.settingsFile.platformPath)
				
				//______________________________________________________
		End case 
	End if 
	
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
			
			This:C1470.saveVectors()
			
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
			
			This:C1470.saveVectors()
			
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
				
				var $model:=New_Model(This:C1470)
				
				If ($model#Null:C1517)
					
					// Update the current vector
					This:C1470.currentItem.model:=$model.name
					This:C1470.saveVectors()
					
					// Update the dropdown
					This:C1470.modelsDropdown.values:=This:C1470._getModelDropdownValues()
					
				End if 
				
				// Update UI
				This:C1470.modelsDropdownUpdate()
				
				return 
				
			End if 
			
			// Update current vector
			This:C1470.currentItem.model:=$dropDown.currentValue
			This:C1470.currentItem.version+=1
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