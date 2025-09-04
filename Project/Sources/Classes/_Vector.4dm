property catalog : cs:C1710.DataStore:=ds:C1482  // Always use the host project datastore

property defaultModel:="text-embedding-3-large"

property models; vectors : Collection

/* Phase 1



*/

property settings : Object

Class constructor
	
	This:C1470.settings:=This:C1470.readSettings()
	This:C1470.models:=This:C1470.readModels()
	This:C1470.vectors:=This:C1470.readStructure()
	
	
	// MARK:-[SETTINGS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readSettings() : Object
	
	Try
		
		var $settings:=JSON Parse:C1218(This:C1470.settingsFile.getText())
		
	Catch
		
		return {}
		
	End try
	
	return $settings
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get settingsFile() : 4D:C1709.File
	
	// For now, we are the developer who saves in the Settings folder.
	return Folder:C1567(fk database folder:K87:14).file("Settings/vectors.json")
	
	// For Admin, we'll need to search near the data and copy the internal file, if necessary, to enable modification.
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function saveSettings()
	
	This:C1470.settings.vectors:=This:C1470.vectors
	This:C1470.settings.models:=This:C1470.models
	
	This:C1470.settingsFile.setText(JSON Stringify:C1217(This:C1470.settings; *))
	
	
	// MARK:-[CATALOG]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readStructure() : Collection
	
	// Get all vector fields in the current catalog
	var $vectors:=[]
	
	var $table; $field : Text
	For each ($table; This:C1470.catalog)
		
		var $dataclass : 4D:C1709.DataClass:=This:C1470.catalog[$table]
		
		For each ($field; $dataclass)
			
			var $o : Object:=$dataclass[$field]
			
			If (String:C10($o.classID)="4D.Vector")
				
				// -1 version for a never-defined vector
				$vectors.push({\
					version: -1; \
					dataclassName: $table; \
					dataclassNumber: $dataclass.getInfo().tableNumber; \
					vectorName: $o.name; \
					vectorNumber: $o.fieldNumber; \
					model: ""; \
					fields: []\
					})
				
			End if 
		End for each 
	End for each 
	
	// Enrichment with saved structure
	If (This:C1470.settings.vectors#Null:C1517)
		
		For each ($o; This:C1470.settings.vectors)
			
			// Queries are performed using internal table/field numbers, to avoid failure in the event of a name change.
			var $v : Object:=$vectors.query("dataclassNumber = :1 & vectorNumber = :2"; $o.dataclassNumber; $o.vectorNumber).first()
			
			If ($v=Null:C1517)  // ERRORS: Table deleted or field modified/deleted
				
				$v:=OB Copy:C1225($o)  // Keep the saved definition
				
				Case of 
						
						//______________________________________________________
					: (This:C1470.catalog[$o.dataclassName]=Null:C1517)
						
						$v._error:=".Missing dataclass \""+$o.dataclassName+"\""
						
						//______________________________________________________
					: (This:C1470.catalog[$o.dataclassName][$o.vectorName]=Null:C1517)
						
						$v._error:=".Missing vector \""+$o.vectorName+"\"of dataclass \""+$o.dataclassName+"\""
						
						//______________________________________________________
					: (String:C10(This:C1470.catalog[$o.dataclassName][$o.vectorName].classID)#"4D.Vector")
						
						$v._error:="."+$o.vectorName+"\"of dataclass \""+$o.dataclassName+"\" is not a Vector"
						
						//______________________________________________________
				End case 
				
				$vectors.push($v)
				
			Else 
				
				// Update with saved definition
				$v.model:=String:C10($o.model)
				$v.fields:=$o.fields
				$v.version:=$o.version#Null:C1517 ? Num:C11($o.version) : $v.version
				
			End if 
		End for each 
	End if 
	
	return $vectors.orderBy("dataclassName asc, vectorName asc")
	
	// MARK:-[MODELS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readModels() : Collection
	
	//TODO:Read models
	return []