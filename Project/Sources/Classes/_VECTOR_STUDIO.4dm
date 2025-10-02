property catalog : cs:C1710.DataStore:=ds:C1482  // Always use the host project datastore

property defaultModel:="text-embedding-3-large"

property settings : Object
property models; vectors : Collection

// Vector list
property currentItem : Object
property itemPosition : Integer
property selectedItems : Collection

// Vector details
property details:=["phrase"; "phraseLabel"; "models"; "modelsLabel"; "openModelsManager"]
property modelsDropdown : Object

property newModel; modelManager : cs:C1710.onBoard

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
				
				This:C1470.newModel:=cs:C1710.onBoard.new("on-board"; "NEW_MODEL")
				This:C1470.newModel.me:=This:C1470.newModel
				
				This:C1470.modelManager:=cs:C1710.onBoard.new("on-board"; "MODELS_MANAGER")
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
				
				// Ensure that the proposed name is unique.
				var $name:=Localized string:C991("newModel")
				var $i; $indx : Integer
				
				Repeat 
					
					If ($dropDown.values.includes($name))
						
						$i+=1
						$name:=Localized string:C991("newModel")+String:C10($i; " ##")
						
					Else 
						
						break
						
					End if 
				Until (False:C215)
				
				This:C1470.newModel.show()
				
				var $o : Object:=This:C1470.newModel.instance
				$o.data.name:=$name
				$o.data.models:=This:C1470.models
				$o.data.context:="add"
				
				return 
				
			End if 
			
			// Update current vector
			This:C1470.currentItem.model:=$dropDown.currentValue
			This:C1470.saveSettings()
			
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
			
			var $o : Object:=$data.model
			var $model:=cs:C1710.Model.new($o.name; $o.model; $o.apiKey; {\
				baseURL: $o.baseURL; \
				organization: $o.organization; \
				project: $o.project\
				})
			
/* #17322
For each model, the name, api Key and model are required.
*/
			var $t : Text
			For each ($t; ["name"; "model"; "apiKey"])
				
				If (Length:C16(String:C10($model[$t]))=0)
					
					BEEP:C151
					ALERT:C41(Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991($t)))
					EXECUTE METHOD IN SUBFORM:C1085(String:C10($instance.name); Formula:C1597(GOTO OBJECT:C206(*; $t)))
					
					return 
					
				End if 
			End for each 
			
/* #17323
The model name shall be unique.
*/
			If (This:C1470.modelsDropdown.values.includes($model.name))
				
				BEEP:C151
				ALERT:C41(Localized string:C991("theModelNameMustBeUnique"))
				EXECUTE METHOD IN SUBFORM:C1085(String:C10($instance.name); Formula:C1597(GOTO OBJECT:C206(*; "name")))
				
				return 
				
			End if 
			
			// Update the current vector
			This:C1470.currentItem.model:=$model.name
			
/* #17326
The structure of the models shall be saved in a JSON file named “vectors.json” in the “settings” folder.
*/
			This:C1470.models.push($model)
			This:C1470.saveSettings()
			
			// Update the dropdown
			This:C1470.modelsDropdown.values:=This:C1470._getModelDropdownValues()
			
			This:C1470.modelsDropdownUpdate()
			
			// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
	End case 
	
	return True:C214  // Success
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelsManagerCallback($instance : Object) : Boolean
	
	
	
	return True:C214  // Success
	
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
	
/* #17311
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
	For each ($vector; This:C1470.vectors)
		
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
	
	return $models.orderBy("name asc")