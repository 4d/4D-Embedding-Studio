property settings : cs:C1710.EmbeddingSettings
property catalog : cs:C1710.DataStore:=ds:C1482  // Always use the host project datastore
property vectors : Collection

// Main list
property list:="list"
property currentItem : Object
property itemPosition : Integer
property selectedItems : Collection

// Details panel
property _detailFields:=[\
"phrase"; \
"models"; \
"more"]

property modelsDropdown : Object
property _cache : Object  // Current catalog cache

property DEBUG:=Structure file:C489=Structure file:C489(*)

// ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___
Class constructor
	
	This:C1470.read()
	
	If (Storage:C1525.studio=Null:C1517)
		
		Use (Storage:C1525)
			
			Storage:C1525.studio:=New shared object:C1526(\
				"EMBEDDINGS"; 0; \
				"MODELS"; 0)
			
		End use 
	End if 
	
	This:C1470._cacheCatalog()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function read()
	
	This:C1470.settings:=cs:C1710.EmbeddingSettings.new()
	This:C1470.readEmbeddingItems()
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				// ________________________________________________________________________________
			: ($e.code=On Load:K2:1)
				
				Use (Storage:C1525.studio)
					
					Storage:C1525.studio["EMBEDDINGS"]:=Current form window:C827
					
				End use 
				
				SET TIMER:C645(-1)
				
				This:C1470.modelsDropdownManager($e)
				
				OBJECT SET FORMAT:C236(*; "Header1"; "path:/.PRODUCT_RESOURCES/Images/ObjectIcons/Icon_600.png")
				// TODO: Use the new vector icon when ready
				OBJECT SET FORMAT:C236(*; "Header2"; "path:/.PRODUCT_RESOURCES/Images/StructureEditor/Field_14.png")
				
				// ______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				SET TIMER:C645(0)
				
				// ______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				If (Length:C16(OBJECT Get name:C1087(Object with focus:K67:3))=0)
					
					GOTO OBJECT:C206(*; This:C1470.list)
					
				End if 
				
				// TODO: Visual indicator
				CALL FORM:C1391(Current form window:C827; Formula:C1597(Form:C1466.refresh()))
				
				// ______________________________________________________
			: ($e.code=On Unload:K2:2)
				
				Use (Storage:C1525.studio)
					
					Storage:C1525.studio["EMBEDDINGS"]:=0
					
				End use 
				
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
					
					var $item : cs:C1710._EmbeddingItem:=Form:C1466.vectors[$row-1]
					OBJECT SET HELP TIP:C1181(*; $me; $item[""]#Null:C1517 ? String:C10($item.helptip) : String:C10($item.error))
					
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
	// Hide/show details based on selection
Function updateUI() : Boolean
	
	var $t : Text
	
	If (This:C1470.currentItem=Null:C1517)
		
		For each ($t; This:C1470._detailFields)
			
			OBJECT SET VISIBLE:C603(*; $t; False:C215)
			OBJECT SET VISIBLE:C603(*; $t+".label"; False:C215)
			
		End for each 
		
		return 
		
	End if 
	
	For each ($t; This:C1470._detailFields)
		
		OBJECT SET VISIBLE:C603(*; $t; True:C214)
		OBJECT SET VISIBLE:C603(*; $t+".label"; True:C214)
		
	End for each 
	
	return True:C214
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If (This:C1470.updateUI())
		
		This:C1470.modelUpdateDropdown(This:C1470.currentItem)
		
	Else 
		
		This:C1470.vectors:=This:C1470.vectors  // ‼️ If no item is selected, we must force a refresh for listMetaInfo to apply
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listMetaInfo($me : cs:C1710._EmbeddingItem) : Object
	
	var $meta:={}
	
	If ($me.defined)
		
		$meta.fontWeight:="bold"
		
		If ($me#This:C1470.currentItem)
			
			If (($me[""].errors.length>0)\
				 || (Length:C16(String:C10($me.error))>0))\
				 || ($me.definition.model="")
				
				$meta.stroke:=FORM Get color scheme:C1761="dark" ? "#ea7979" : "red"
				
			End if 
		End if 
	End if 
	
	return $meta
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function moreManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	var $item : cs:C1710._EmbeddingItem:=This:C1470.currentItem
	var $menu:=cs:C1710._menu.new()
	
	If (OBJECT Get name:C1087(Object with focus:K67:3)="phrase")
		
		$menu.edit(True:C214).line()
		This:C1470._embeddedAttributesMenu($item; $menu)
		
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
			
			This:C1470.insertInput($item; $menu.choice)
			This:C1470.saveEmbeddingItems()
			
			// ______________________________________________________
		: ($menu.choice="editApiKey")
			
			// TODO: Edit API key
			
			// ______________________________________________________
		: ($menu.choice="openSettingFile")
			
			OPEN URL:C673(This:C1470.settings.file.platformPath)
			
			// ______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function phraseManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	var $item : cs:C1710._EmbeddingItem:=This:C1470.currentItem
	var $me:="phrase"
	var $plainText:=ST Get plain text:C1092(*; $me)  //Get edited text
	
	Case of 
			
			// ______________________________________________________
		: ($item=Null:C1517)
			
			return 
			
			// ______________________________________________________
		: ($e.code=On Mouse Enter:K2:33) || ($e.code=On Mouse Move:K2:35)
			
			OBJECT SET HELP TIP:C1181(*; $me; $item[""]#Null:C1517 ? String:C10($item.helptip) : String:C10($item.error))
			
			// ______________________________________________________
		: ($e.code=On Mouse Leave:K2:34)
			
			OBJECT SET HELP TIP:C1181(*; $me; "")
			
			// ______________________________________________________
		: ($e.code=On Clicked:K2:4)
			
			If (Not:C34(Contextual click:C713))
				
				return 
				
			End if 
			
			var $menu:=cs:C1710._menu.new().edit(True:C214).line()
			This:C1470._embeddedAttributesMenu($item; $menu)
			
			If (Not:C34($menu.popup().selected))
				
				return 
				
			End if 
			
			// 📌 Ignored if an associated action (for edit items)
			This:C1470.insertInput($item; $menu.choice)
			This:C1470.saveEmbeddingItems()
			
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
			$item.phrase:=$item.parsePhrase(cs:C1710.Phrase.new($plainText))
			
			Form:C1466.vectors:=Form:C1466.vectors  // update UI
			
			// ______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			$item.definition.phrase:=cs:C1710.Phrase.new($plainText)
			$item.version+=1
			
			// Highlight any errors, if any
			ST SET TEXT:C1115(*; $me; $item.parsePhrase($item.definition.phrase); ST Start text:K78:15; ST End text:K78:16)
			
			This:C1470.saveEmbeddingItems()
			
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
			
			// Update current item
			This:C1470.currentItem.definition.model:=$dropDown.currentValue
			This:C1470.currentItem.version+=1
			This:C1470.saveEmbeddingItems()
			
			Form:C1466.vectors:=Form:C1466.vectors  // update UI
			
			//______________________________________________________
	End case 
	
	// MARK: -
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function insertInput($item : cs:C1710._EmbeddingItem; $input : Text)
	
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
	$item.definition.phrase:=cs:C1710.Phrase.new(ST Get plain text:C1092($newValue))
	$item.phrase:=$item.parsePhrase($item.definition.phrase)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelUpdateDropdown($item : cs:C1710._EmbeddingItem)
	
	$item:=$item || This:C1470.currentItem
	
	If ($item=Null:C1517)
		
		return 
		
	End if 
	
	var $dropDown : Object:=This:C1470.modelsDropdown
	
	If ($dropDown.values.includes($item.definition.model))
		
		$dropDown.index:=$dropDown.values.indexOf($item.definition.model)
		
	Else 
		
		$dropDown.index:=-1
		
	End if 
	
	$dropDown.currentValue:=$item.definition.model || $dropDown.placeholder
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function refresh()  //($force : Boolean)
	
	This:C1470.readEmbeddingItems()
	
	If (This:C1470._catalogModified())
		
		This:C1470._cacheCatalog()  // Update cache
		
	End if 
	
	// MARK: Update list
	var $current:=This:C1470.currentItem
	
	If ($current#Null:C1517)  // Restore selection
		
		var $c:=This:C1470.vectors.indices("definition.dataclassName = :1 & definition.vectorName = :2"; $current.definition.dataclassName; $current.definition.vectorName)
		
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
	
	// MARK:- [VECTORS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readEmbeddingItems() : Collection
	
/* #17301
Get the possible vector fields in the current catalog
The list is displayed with:
• table/dataclass
• vector field
Enriched with saved EmbeddingDefinition entries from Settings/vectors.json.
*/
	This:C1470.settings:=This:C1470.settings || cs:C1710.EmbeddingSettings.new()
	This:C1470.settings.load()
	
	var $items:=[]
	
	var $vf : Object
	For each ($vf; This:C1470._collectVectorFields())
		
		var $def : cs:C1710.EmbeddingDefinition:=This:C1470.settings.find($vf.dataclassName; $vf.field.name)
		var $wasSaved : Boolean:=$def#Null:C1517
		
		If (Not:C34($wasSaved))
			
			$def:=cs:C1710.EmbeddingDefinition.new($vf.dataclassName; $vf.field.name; ""; "")
			
		End if 
		
		var $item : cs:C1710._EmbeddingItem:=cs:C1710._EmbeddingItem.new($vf.dataclass; $def; This:C1470.settings)
		
		If ($wasSaved)

			$item.version:=0
			$item.phrase:=$item.parsePhrase($def.phrase)
			
			// TODO: Check if the model exists
			If (($def.model="") && (Length:C16($def.phrase.template)>0))
				
				$item.error:=Localized string:C991("theModelIsNotDefined")
				
			End if 
		End if 
		
		$items.push($item)
		
	End for each 
	
	// Ghost entries: saved definitions that no longer match any catalog vector field.
	var $saved : cs:C1710.EmbeddingDefinition
	For each ($saved; This:C1470.settings.vectors)
		
		If ($items.query("definition.dataclassName = :1 & definition.vectorName = :2"; $saved.dataclassName; $saved.vectorName).length>0)
			
			continue
			
		End if 
		
		var $ghost : Object:={definition: $saved; error: ""}
		
		Case of 
				
				// ______________________________________________________
			: (This:C1470.catalog[$saved.dataclassName]=Null:C1517)
				
				$ghost.error:=Replace string:C233(Localized string:C991("missingDataclass"); "{dataclass}"; $saved.dataclassName)
				
				// ______________________________________________________
			: (This:C1470.catalog[$saved.dataclassName][$saved.vectorName]=Null:C1517)
				
				$ghost.error:=Replace string:C233(Replace string:C233(Localized string:C991("missingVector"); "{attribute}"; $saved.vectorName); "{dataclass}"; $saved.dataclassName)
				
				// ______________________________________________________
			: (String:C10(This:C1470.catalog[$saved.dataclassName][$saved.vectorName].classID)#"4D.Vector")
				
				$ghost.error:=Replace string:C233(Replace string:C233(Localized string:C991("attributeIsNotAVector"); "{attribute}"; $saved.vectorName); "{dataclass}"; $saved.dataclassName)
				
				// ______________________________________________________
		End case 
		
		$items.push($ghost)
		
	End for each 
	
	This:C1470.vectors:=$items.orderBy("definition.dataclassName asc, definition.vectorName asc")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function saveEmbeddingItems()
	
	// Keep only defined items
	This:C1470.settings.vectors:=This:C1470.vectors\
		.filter(Formula:C1597(Bool:C1537($1.value.defined)))\
		.map(Formula:C1597($1.value.definition))
	This:C1470.settings.save()
	
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
	// Returns a flat list of catalog vector fields: [{dataclass, dataclassName, field}]
Function _collectVectorFields() : Collection
	
	var $fields : Collection:=[]
	var $tableName; $fieldName : Text
	
	For each ($tableName; This:C1470.catalog)
		
		var $dataclass : 4D:C1709.DataClass:=This:C1470.catalog[$tableName]
		
		For each ($fieldName; $dataclass)
			
			var $field : Object:=$dataclass[$fieldName]
			
			If (String:C10($field.classID)="4D.Vector")
				
				$fields.push({\
					dataclass: $dataclass; \
					dataclassName: $dataclass.getInfo().name; \
					field: $field})
				
			End if 
		End for each 
	End for each 
	
	return $fields
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _getModelDropdownValues() : Collection
	
	return cs:C1710.AIKit.OpenAIProviders.new().modelAliases().extract("name")
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _embeddedAttributesMenu($item : cs:C1710._EmbeddingItem; $menu : cs:C1710._menu)
	
	var $embed:=$item.inputsMenu
	
	If ($embed.itemCount()>0)
		
		$menu.append(":xliff:embed"; $embed).icon("|Images/ObjectIcons/Icon_455.png")
		
	Else 
		
		$embed.release()
		
	End if 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _popError($message : Text; $widget : Text; $target : Text)
	
	BEEP:C151
	ALERT:C41($message)
	
	If (Length:C16($target)>0)
		
		var $o : Object:=OBJECT Get value:C1743($widget)
		$o.target:=$target
		OBJECT SET VALUE:C1742($widget; $o)
		
	End if 
	