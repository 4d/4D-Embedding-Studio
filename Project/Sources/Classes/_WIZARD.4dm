property settings : Object
property file : 4D:C1709.File

property catalog : cs:C1710.DataStore:=ds:C1482  // Always use the host project datastore

property models; vectors : Collection

property providers:={}

property _key : Text
property _models : Collection
property _providers:=[]

// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _loadPredefinedProviders()
	
	var $file:=File:C1566("/RESOURCES/providers.json")
	
	var $o : Object
	For each ($o; JSON Parse:C1218($file.getText()))
		
		This:C1470._providers.push(cs:C1710.Provider.new($o))
		
	End for each 
	
Class constructor
	
	This:C1470._loadPredefinedProviders()
	
	// Default provider
	This:C1470.providers.openAI:=cs:C1710.Provider.new()
	
	This:C1470.settings:=This:C1470.readSettings()
	This:C1470.models:=This:C1470.readModels()
	This:C1470.vectors:=This:C1470.readVectors()
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get settingsFile() : 4D:C1709.File
	
/* #17311
The vector structure shall be saved in a JSON file named “vectors.json” in the “settings” folder
*/
	
	// For now, we are the developer who saves in the Settings folder of the host project.
	return Folder:C1567(fk database folder:K87:14; *).file("Settings/vectors.json")
	
/*
For the administrator, in order to enable modification, 
we will need to search for nearby data and copy the internal file, if necessary.
*/
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readSettings() : Object
	
	Try
		
		var $settings:=JSON Parse:C1218(This:C1470.settingsFile.getText())
		
	Catch
		
		return {vectors: []; models: []}
		
	End try
	
	return $settings
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function writeSettings()
	
	This:C1470.settingsFile.setText(JSON Stringify:C1217(This:C1470.settings; *))
	
	// MARK:- [VECTORS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readVectors() : Collection
	
/* #17301
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
		
		var $vector : cs:C1710.Vector
		For each ($vector; This:C1470.settings.vectors)
			
/* Queries are performed using internal table/field numbers, to avoid failure in the event of a name change.
var $v : cs.Vector:=$vectors.query("dataclassNumber = :1 & vectorNumber = :2"; $vector.dataclassNumber; $vector.vectorNumber).first()*/
			
			var $v : cs:C1710.Vector:=$vectors.query("dataclassName = :1 & vectorName"; $vector.dataclassName; $vector.vectorName).first()
			
			If ($v=Null:C1517)  // ERROR
				
				$v:=OB Copy:C1225($vector)  // Keep the saved definition
				
				//// Automatic name corrections, where applicable and possible
				//$v.dataclassName:=Try(Table name($v.dataclassNumber)) || $v.dataclassName
				//$v.vectorName:=Try(Field name($v.dataclassNumber; $v.vectorNumber)) || $v.vectorName
				
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
			$v.model:=String:C10($vector.model)
			$v.phrase:=$v.parsePhrase($vector.phrase)
			$v.version:=$vector.version#Null:C1517 ? Num:C11($vector.version) : $v.version
			
			Case of 
					
					// ______________________________________________________
				: ($v.model="")
					
					$v.error:=Localized string:C991("theModelIsNotDefined")
					
			End case 
			
		End for each 
	End if 
	
	return $vectors.orderBy("dataclassName asc, vectorName asc")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function saveVectors($vectors : Collection)
	
	// Keep only defined vectors
	This:C1470.settings.vectors:=[]
	
	//%W-550.26
	var $vector : cs:C1710.Vector
	For each ($vector; $vectors || This:C1470.vectors)
		
		If ($vector.defined)
			
			This:C1470.settings.vectors.push($vector.definition)
			
		End if 
	End for each 
	//%W+550.26
	
	This:C1470.writeSettings()
	
	// MARK:- [MODELS
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readModels() : Collection
	
	var $models:=[]
	
	var $model : cs:C1710.Model
	For each ($model; This:C1470.settings.models)
		
		$models.push($model)
		
	End for each 
	
	return $models.orderBy("name asc")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function saveModels($models : Collection)
	
/* #17326
The structure of the models shall be saved in a JSON file named “vectors.json” in the “settings” folder.
*/
	This:C1470.settings.models:=[]
	
	//%W-550.26
	var $model : cs:C1710.Model
	For each ($model; $models || This:C1470.models)
		
		This:C1470.settings.models.push({\
			name: $model.name; \
			model: $model.model; \
			apiKey: $model.apiKey; \
			baseURL: $model.baseURL; \
			organization: $model.organization; \
			project: $model.project\
			})
		
	End for each 
	//%W+550.26
	
	This:C1470.writeSettings()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function addModel($model : cs:C1710.Model)
	
	This:C1470.models.push($model)
	This:C1470.saveModels()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function isModelUsed($name : Text) : cs:C1710.Vector
	
	return This:C1470.vectors.query("model = :1"; $name).first()
	
	// MARK:- [PRIVATE]
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _popError($message : Text; $widget : Text; $target : Text)
	
	BEEP:C151
	ALERT:C41($message)
	
	If (Length:C16($target)>0)
		
		var $o : Object:=OBJECT Get value:C1743($widget)
		$o.target:=$target
		OBJECT SET VALUE:C1742($widget; $o)
		
	End if 
	