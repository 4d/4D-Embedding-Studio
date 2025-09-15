property catalog : cs:C1710.DataStore:=ds:C1482  // Always use the host project datastore

property defaultModel:="text-embedding-3-large"

property settings : Object
property models; vectors : Collection

// Vector list
property currentItem : Object
property itemPosition : Integer
property selectedItems : Collection

property modelsDropdown : Object

Class constructor
	
	This:C1470.settings:=This:C1470.readSettings()
	This:C1470.models:=This:C1470.readModels()
	This:C1470.vectors:=This:C1470.readStructure()
	
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
			//: ($e.objectName="modelManager")
			
			//This.modelManager($e)
			
			//______________________________________________________
		: ($e.objectName="manageModels")
			
			If ($e.code=On Clicked:K2:4)
				
				FORM GOTO PAGE:C247(2)
				
			End if 
			
			//______________________________________________________
		: ($e.objectName="backButton")
			
			BEEP:C151
			
			//______________________________________________________
		: ($e.objectName="save")
			
			This:C1470.saveSettings()
			
			//______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	var $vector : cs:C1710.Vector:=This:C1470.currentItem
	var $me:="list"
	
	If ($vector=Null:C1517)
		
		OBJECT SET ENABLED:C1123(*; "phrase"; False:C215)
		OBJECT SET ENABLED:C1123(*; "more"; False:C215)
		OBJECT SET ENABLED:C1123(*; "models"; False:C215)
		
		return 
		
	Else 
		
		OBJECT SET ENABLED:C1123(*; "phrase"; True:C214)
		OBJECT SET ENABLED:C1123(*; "more"; True:C214)
		OBJECT SET ENABLED:C1123(*; "models"; True:C214)
		
		// TODO: Error help tips based on the line hovered
		
/*
Case of 
//______________________________________________________
: ($e.code=On Mouse Move)
OBJECT SET HELP TIP(*; $me; $vector.helptip)
//______________________________________________________
: ($e.code=On Mouse Leave)
OBJECT SET HELP TIP(*; $me; "")
//______________________________________________________
Else 
// A "Case of" statement should never omit "Else"
//______________________________________________________
End case 
*/
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listMetaInfo($me : cs:C1710.Vector) : Object
	
	If ($me[""].errors.length>0) || (Length:C16(String:C10($me.error))>0)
		
		return {cell: {dataclass: {fill: "red"; stroke: "white"}; vector: {fill: "red"; stroke: "white"}}}
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function moreManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
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
			$menu.append(":xliff:embed"; $embed)
			
			var $attribute : Object
			For each ($attribute; $vector.supportedAttributes.orderBy("name"))
				
				$embed.append($attribute.name; "{"+$attribute.name+"}")
				
			End for each 
			
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
		: ($e.code=On Load:K2:1)
			
			var $me:={\
				values: This:C1470._getModelDropdownValues(); \
				index: -1; \
				placeholder: Localized string:C991("selectAModel")}
			
			$me.currentValue:=$me.placeholder
			Form:C1466.modelsDropdown:=$me
			
			//______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			$me:=Form:C1466.modelsDropdown
			
/*If ($me.index=0)  // New*/
			If ($me.currentValue=Localized string:C991("newModel"))  // New
				
				
				// Create a new model
				var $name:="myNewModel"
				var $o : Object:=OBJECT Get value:C1743("modelManager") || {models: Form:C1466.models}
				$o.context:="add"
				$o.name:=$name
				
				FORM GOTO PAGE:C247(2)
				OBJECT SET VALUE:C1742("modelManager"; $o)
				
				
				//If (Bool(OK))  //
				
				//This.models.push({name: $name})
				//$me.values:=This._getModelDropdownValues()
				//$me.index:=$me.values.indexOf($name)
				//$me.currentValue:=$name
				
				//Else 
				
				//$me.currentValue:=$me.placeholder
				//$me.index:=-1
				
				//End if 
				
				//Form.modelsDropdown:=Form.modelsDropdown  // Redraw
				
				return 
				
			End if 
			
			var $vector : cs:C1710.Vector:=This:C1470.currentItem
			$vector.model:=$me.currentValue
			
			//______________________________________________________
	End case 
	
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.code<0)
		
		var $o : Object:=OBJECT Get value:C1743("modelManager")
		
		Case of 
				
				//______________________________________________________
			: ($o.context=Null:C1517)
				
				// <NOTHING MORE TO DO>
				
				//______________________________________________________
			: ($o.context="add")
				
				
				
				//______________________________________________________
			Else 
				
				// A "Case of" statement should never omit "Else"
				
				//______________________________________________________
		End case 
	End if 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _getModelDropdownValues() : Collection
	
	return This:C1470.models.extract("name").orderBy().combine(["-"; Localized string:C991("newModel")])
	
	// MARK:- [SETTINGS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readSettings() : Object
	
	Try
		
		var $settings:=JSON Parse:C1218(This:C1470.settingsFile.getText())
		
	Catch
		
		return {vectors: []; models: []}
		
	End try
	
	return $settings
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get settingsFile() : 4D:C1709.File
	
/* Requirement 17311
The vector structure shall be saved in a JSON file named “vectors.json” in the “settings” folder
*/
	
	// For now, we are the developer who saves in the Settings folder.
	return Folder:C1567(fk database folder:K87:14).file("Settings/vectors.json")
	
/*
For the administrator, in order to enable modification, 
we will need to search for nearby data and copy the internal file, if necessary.
*/
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function saveSettings()
	
	// Keep only defined vectors
	This:C1470.settings.vectors:=[]
	
	var $vector : cs:C1710.Vector
	For each ($vector; Form:C1466.vectors)
		
		If ($vector.defined)
			
			This:C1470.settings.vectors.push($vector.definition)
			
		End if 
	End for each 
	
	This:C1470.settings.models:=This:C1470.models
	
	This:C1470.settingsFile.setText(JSON Stringify:C1217(This:C1470.settings; *))
	
	// MARK:- [CATALOG]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readStructure() : Collection
	
/* Requirement 17301
Get the possible vector fields in the current catalog
The list is displayed with:
• table/dataclass
• vector field
*/
	var $vectors:=[]
	
	var $tableName; $fieldName : Text
	For each ($tableName; This:C1470.catalog)
		
		var $dataclass : 4D:C1709.DataClass:=This:C1470.catalog[$tableName]
		
		For each ($fieldName; $dataclass)
			
			var $field : Object:=$dataclass[$fieldName]
			
			If (String:C10($field.classID)="4D.Vector")
				
				$vectors.push(cs:C1710.Vector.new($dataclass; $field))
				
			End if 
		End for each 
	End for each 
	
/* Enrichment with saved structure
{
    "vectors": [ {
        "version": "number",
        "dataclassName": "string",
        "dataclassNumber": "number",
        "vectorName": "string",
        "vectorNumber": "number", 
        "model": "string",
        "phrase": "string"
    }, { ... }
    ]
}
*/
	
	If (This:C1470.settings.vectors#Null:C1517)
		
		var $o : cs:C1710.Vector
		For each ($o; This:C1470.settings.vectors)
			
			// Queries are performed using internal table/field numbers, to avoid failure in the event of a name change.
			var $v : cs:C1710.Vector:=$vectors.query("dataclassNumber = :1 & vectorNumber = :2"; $o.dataclassNumber; $o.vectorNumber).first()
			
			If ($v=Null:C1517)  // ERROR
				
				$v:=OB Copy:C1225($o)  // Keep the saved definition
				
				// Automatic name corrections, where applicable and possible
				$v.dataclassName:=Try(Table name:C256($v.dataclassNumber)) || $v.dataclassName
				$v.vectorName:=Try(Field name:C257($v.dataclassNumber; $v.vectorNumber)) || $v.vectorName
				
				Case of 
						
						// ______________________________________________________
					: (This:C1470.catalog[$v.dataclassName]=Null:C1517)
						
						$v.error:=Replace string:C233(Localized string:C991("missingDataclass"); "{dataclass}"; $v.dataclassName)
						
						// ______________________________________________________
					: (This:C1470.catalog[$v.dataclassName][$v.vectorName]=Null:C1517)
						
						$v.error:=Replace string:C233(Replace string:C233(Localized string:C991("missingVector"); "{attribute}"; $v.vectorName); "{dataclass}"; $v.dataclassName)
						
						// ______________________________________________________
					: (String:C10(This:C1470.catalog[$v.dataclassName][$v.vectorName].classID)#"4D.Vector")
						
						$v.error:=Replace string:C233(Replace string:C233(Localized string:C991("attributeIsNotAVector"); "{attribute}"; $v.vectorName); "{dataclass}"; $v.dataclassName)
						
						// ______________________________________________________
				End case 
				
				$vectors.push($v)
				
				continue
				
			End if 
			
			// TODO: Check if the model exists
			
			// Update with saved definition
			$v.model:=String:C10($o.model)
			$v.phrase:=$v.parsePhrase($o.phrase)
			$v.version:=$o.version#Null:C1517 ? Num:C11($o.version) : $v.version
			
		End for each 
	End if 
	
	return $vectors.orderBy("dataclassName asc, vectorName asc")
	
	// MARK:- [MODELS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readModels() : Collection
	
	var $models:=[]
	
	var $o : cs:C1710.Vector
	For each ($o; This:C1470.settings.models)
		
		$models.push($o)
		
	End for each 
	
	// TODO: Read models
	return $models.orderBy("name asc")