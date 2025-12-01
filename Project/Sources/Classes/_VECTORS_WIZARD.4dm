Class extends _WIZARD

// Vector list
property currentItem : Object
property itemPosition : Integer
property selectedItems : Collection

// Vector details
property details:=["phrase"; "phraseLabel"; "models"; "modelsLabel"; "openModelsManager"; "more"]
property modelsDropdown : Object

property debug:=Structure file:C489=Structure file:C489(*)

property _cache : Object  // Current catalog cache

Class constructor
	
	Super:C1705()
	
	This:C1470._cacheCatalog()
	
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
				
				OBJECT SET FORMAT:C236(*; "Header1"; "path:/.PRODUCT_RESOURCES/Images/ObjectIcons/Icon_600.png")
				
				// TODO: Use the new vector icon when ready
				OBJECT SET FORMAT:C236(*; "Header2"; "path:/.PRODUCT_RESOURCES/Images/StructureEditor/Field_14.png")
				
				SET TIMER:C645(-1)
				
				//______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				SET TIMER:C645(0)
				
				//______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				If (This:C1470._catalogModified())
					
					// MARK: Update lits
					This:C1470.vectors:=This:C1470.readVectors()
					
					If (This:C1470.currentItem#Null:C1517)  // Restore selection
						
						var $c:=This:C1470.vectors.indices("dataclassName = :1 & vectorName = :2"; This:C1470.currentItem.dataclassName; This:C1470.currentItem.vectorName)
						
						If ($c.length>0)
							
							LISTBOX SELECT ROW:C912(*; "list"; $c[0]+1)
							
						Else 
							
							LISTBOX SELECT ROW:C912(*; "list"; 0; lk remove from selection:K53:3)
							
						End if 
						
						This:C1470.listManager($e)
						
					End if 
					
					This:C1470._cacheCatalog()
					
				End if 
				
				//______________________________________________________
		End case 
		
		return 
		
	End if 
	
	If (($e.code=On Mouse Enter:K2:33) || ($e.code=On Mouse Move:K2:35) || ($e.code=On Mouse Leave:K2:34))
		
		Case of 
				
				//______________________________________________________
			: ($e.objectName="phrase")
				
				This:C1470.phraseManager($e)
				
				//______________________________________________________
		End case 
		
		return   // Mouseover is only handled for the sentence.
		
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
	
	var $vector : cs:C1710.Vector:=This:C1470.currentItem
	var $menu:=cs:C1710.menu.new()
	This:C1470._embeddedAttributesMenu($vector; $menu)
	
	$menu.line().append("🚧 Edit API key"; "editApiKey")
	
	If (This:C1470.debug)
		
		$menu.append("🚧 open setting file"; "openSettingFile")
		
	End if 
	
	Case of 
			
			// ______________________________________________________
		: (Not:C34($menu.popup().selected))
			
			// <NOTHING MORE TO DO> 
			
			// ______________________________________________________
		: (Position:C15("{"; $menu.choice)=1)  // Attribute to insert into the descriptive phrase
			
			This:C1470.insertInput($vector; $menu.choice)
			This:C1470.saveVectors()
			
			// ______________________________________________________
		: ($menu.choice="editApiKey")
			
			// TODO: Edit API key 
			
			// ______________________________________________________
		: ($menu.choice="openSettingFile")
			
			OPEN URL:C673(This:C1470.settingsFile.platformPath)
			
			// ______________________________________________________
	End case 
	
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
		: ($e.code=On Mouse Enter:K2:33) || ($e.code=On Mouse Move:K2:35)
			
			OBJECT SET HELP TIP:C1181(*; $me; $vector[""]#Null:C1517 ? String:C10($vector.helptip) : String:C10($vector.error))
			
			// ______________________________________________________
		: ($e.code=On Mouse Leave:K2:34)
			
			OBJECT SET HELP TIP:C1181(*; $me; "")
			
			// ______________________________________________________
		: ($e.code=On Clicked:K2:4)
			
			If (Not:C34(Contextual click:C713))
				
				return 
				
			End if 
			
			var $menu:=cs:C1710.menu.new().edit(True:C214).line()
			This:C1470._embeddedAttributesMenu($vector; $menu)
			
			If (Not:C34($menu.popup().selected))
				
				return 
				
			End if 
			
			// 📌 Ignored if an associated action (for edit items)
			This:C1470.insertInput($vector; $menu.choice)
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
Function insertInput($vector : cs:C1710.Vector; $input : Text)
	
	var $me:="phrase"
	var $plainText:=ST Get plain text:C1092(*; $me)  //Get edited text
	
	var $startSel; $endSel : Integer
	GET HIGHLIGHT:C209(*; $me; $startSel; $endSel)
	
	If (Length:C16($plainText)=0)
		
		var $newValue:="<span>"+$input+"</span>"
		
	Else 
		
		$newValue:=Substring:C12($plainText; 1; $startSel-1)+$input+Substring:C12($plainText; $endSel)
		
	End if 
	
	OBJECT SET VALUE:C1742($me; $newValue)
	
	$endSel:=$startSel+Length:C16($input)
	HIGHLIGHT TEXT:C210(*; $me; $endSel; $endSel)
	
	// Highlight any errors, if any
	$vector.phrase:=$vector.parsePhrase(ST Get plain text:C1092($newValue))
	
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
Function _cacheCatalog()
	
	This:C1470._cache:={}
	
	var $dataclass; $attribute : Text
	
	For each ($dataclass; This:C1470.catalog)
		
		This:C1470._cache[$dataclass]:={}
		
		For each ($attribute; This:C1470.catalog[$dataclass])
			
			This:C1470._cache[$dataclass][$attribute]:=True:C214
			
		End for each 
	End for each 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _catalogModified() : Boolean
	
	This:C1470.catalog:=ds:C1482
	
	var $dataclass; $attribute : Text
	
	For each ($dataclass; This:C1470._cache)
		
		If (This:C1470.catalog[$dataclass]=Null:C1517)
			
			return True:C214
			
		End if 
		
		For each ($attribute; This:C1470._cache[$dataclass])
			
			If (This:C1470.catalog[$dataclass][$attribute]=Null:C1517)
				
				return True:C214
				
			End if 
		End for each 
	End for each 
	
	For each ($dataclass; This:C1470.catalog)
		
		If (This:C1470._cache[$dataclass]=Null:C1517)
			
			return True:C214
			
		End if 
		
		For each ($attribute; This:C1470.catalog[$dataclass])
			
			If (This:C1470._cache[$dataclass][$attribute]=Null:C1517)
				
				return True:C214
				
			End if 
		End for each 
	End for each 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _getModelDropdownValues() : Collection
	
	return This:C1470.models.extract("name").orderBy().combine(["-"; Localized string:C991("newModelItem")])
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _embeddedAttributesMenu($vector : cs:C1710.Vector; $menu : cs:C1710.menu)
	
	var $embed:=$vector.inputsMenu
	
	If ($embed.itemCount()>0)
		
		$menu.append(":xliff:embed"; $embed).icon("|Images/ObjectIcons/Icon_455.png")
		
	Else 
		
		$embed.release()
		
	End if 
	