Class extends _COMMON

property _detailFields:=[\
"phrase"; \
"models"; \
"more"]

property modelsDropdown : Object
property _cache : Object  // Current catalog cache

Class constructor
	
	Super:C1705()
	
	This:C1470._cacheCatalog()
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Super:C1706.manager($e; "EMBEDDINGS")
		
		Case of 
				
				// ________________________________________________________________________________
			: ($e.code=On Load:K2:1)
				
				This:C1470.modelsDropdownManager($e)
				
				OBJECT SET FORMAT:C236(*; "Header1"; "path:/.PRODUCT_RESOURCES/Images/ObjectIcons/Icon_600.png")
				// TODO: Use the new vector icon when ready
				OBJECT SET FORMAT:C236(*; "Header2"; "path:/.PRODUCT_RESOURCES/Images/StructureEditor/Field_14.png")
				
				// ______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				//
				
				// ______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				// TODO: Visual indicator
				CALL FORM:C1391(Current form window:C827; Formula:C1597(Form:C1466.refresh()))
				
				// ________________________________________________________________________________
		End case 
		
		return 
		
	End if 
	
	If (($e.code=On Mouse Enter:K2:33) || ($e.code=On Mouse Move:K2:35) || ($e.code=On Mouse Leave:K2:34))
		
		Case of 
				
				//______________________________________________________
			: ($e.objectName=This:C1470.list)
				
				var $me:=This:C1470.list
				var $x; $y; $button; $column; $row : Integer
				MOUSE POSITION:C468($x; $y; $button)
				LISTBOX GET CELL POSITION:C971(*; $me; $x; $y; $column; $row)
				
				If ($row>0)
					
					var $vector : cs:C1710.Vector:=Form:C1466.vectors[$row-1]
					OBJECT SET HELP TIP:C1181(*; $me; $vector[""]#Null:C1517 ? String:C10($vector.helptip) : String:C10($vector.error))
					
				Else 
					
					OBJECT SET HELP TIP:C1181(*; $me; "")
					
				End if 
				
				//______________________________________________________
			: ($e.objectName="phrase")
				
				This:C1470.phraseManager($e)
				
				//______________________________________________________
		End case 
		
		return 
		
	End if 
	
	Case of 
			
			//______________________________________________________
		: ($e.objectName=This:C1470.list)
			
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
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If (This:C1470.updateUI())
		
		This:C1470.modelUpdateDropdown(This:C1470.currentItem)
		
	Else 
		
		This:C1470.vectors:=This:C1470.vectors  // ‼️ If no item is selected, we must force a refresh for listMetaInfo to apply 
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listMetaInfo($me : cs:C1710.Vector) : Object
	
	var $meta:={}
	
	If ($me.defined)
		
		$meta.fontWeight:="bold"
		
		If ($me#This:C1470.currentItem)
			
			If (($me[""].errors.length>0)\
				 || (Length:C16(String:C10($me.error))>0))\
				 || ($me.model="")
				
				$meta.stroke:="red"
				
			End if 
		End if 
	End if 
	
	return $meta
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function moreManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	var $vector : cs:C1710.Vector:=This:C1470.currentItem
	var $menu:=cs:C1710.menu.new()
	
	If (OBJECT Get name:C1087(Object with focus:K67:3)="phrase")
		
		$menu.edit(True:C214).line()
		This:C1470._embeddedAttributesMenu($vector; $menu)
		
	End if 
	
	If (This:C1470.DEBUG)
		
		$menu.line().append("🚧 Edit API key"; "editApiKey")
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
			
			Form:C1466.vectors:=Form:C1466.vectors  // update UI
			
			// ______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			// Highlight any errors, if any
			ST SET TEXT:C1115(*; $me; $vector.parsePhrase($plainText); ST Start text:K78:15; ST End text:K78:16)
			
			This:C1470.currentItem.version+=1
			This:C1470.saveVectors()
			
			Form:C1466.vectors:=Form:C1466.vectors  // update UI
			
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
			
			// Update current vector
			This:C1470.currentItem.model:=$dropDown.currentValue
			This:C1470.currentItem.version+=1
			This:C1470.saveVectors()
			
			Form:C1466.vectors:=Form:C1466.vectors  // update UI
			
			//______________________________________________________
	End case 
	
	// MARK: -
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
Function modelUpdateDropdown($vector : cs:C1710.Vector)
	
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
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function refresh()  //($force : Boolean)
	
	This:C1470.readVectors()
	
	If (This:C1470._catalogModified())
		
		This:C1470._cacheCatalog()  // Update cache
		
	End if 
	
	// MARK: Update list
	var $current:=This:C1470.currentItem
	
	If ($current#Null:C1517)  // Restore selection
		
		var $c:=This:C1470.vectors.indices("dataclassName = :1 & vectorName = :2"; $current.dataclassName; $current.vectorName)
		
		If ($c.length>0)
			
			LISTBOX SELECT ROW:C912(*; This:C1470.list; $c[0]+1)
			This:C1470.currentItem:=This:C1470.vectors[$c[0]]
			
		Else 
			
			LISTBOX SELECT ROW:C912(*; This:C1470.list; 0; lk remove from selection:K53:3)  // Deselect
			This:C1470.currentItem:=Null:C1517
			
		End if 
		
		This:C1470.listManager()
		
	End if 
	
	This:C1470.modelsDropdown.values:=This:C1470._getModelDropdownValues()
	This:C1470.modelUpdateDropdown(This:C1470.currentItem)
	
	// MARK: -[PRIVATE]
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
	
	return cs:C1710.AIKit.OpenAIProviders.new().modelAliases().extract("name")
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _embeddedAttributesMenu($vector : cs:C1710.Vector; $menu : cs:C1710.menu)
	
	var $embed:=$vector.inputsMenu
	
	If ($embed.itemCount()>0)
		
		$menu.append(":xliff:embed"; $embed).icon("|Images/ObjectIcons/Icon_455.png")
		
	Else 
		
		$embed.release()
		
	End if 