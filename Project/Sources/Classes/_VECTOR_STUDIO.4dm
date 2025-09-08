property catalog : cs:C1710.DataStore:=ds:C1482  // Always use the host project datastore

property defaultModel:="text-embedding-3-large"

property models; vectors : Collection

// Vector list
property currentVector : Object
property currentVectorPosition : Integer
property selectedVectors : Collection

/* Phase 1

*/

property settings : Object

Class constructor
	
	This:C1470.settings:=This:C1470.readSettings()
	This:C1470.models:=This:C1470.readModels()
	This:C1470.vectors:=This:C1470.readStructure()
	
	// MARK:- [SETTINGS]
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
	
	// MARK:- [CATALOG]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readStructure() : Collection
	
	// Get all vector fields in the current catalog
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
	
	// Enrichment with saved structure
	If (This:C1470.settings.vectors#Null:C1517)
		
		var $vector : cs:C1710.Vector
		
		For each ($vector; This:C1470.settings.vectors)
			
			// Queries are performed using internal table/field numbers, to avoid failure in the event of a name change.
			var $v : cs:C1710.Vector:=$vectors.query("dataclassNumber = :1 & vectorNumber = :2"; $vector.dataclassNumber; $vector.vectorNumber).first()
			
			If ($v=Null:C1517)  // ERRORS: Table deleted or field modified/deleted
				
				$v:=OB Copy:C1225($vector)  // Keep the saved definition
				
				// FIXME: To Localize
				
				Case of 
						
						// ______________________________________________________
					: (This:C1470.catalog[$vector.dataclassName]=Null:C1517)
						
						$v.error:="Missing dataclass \""+$vector.dataclassName+"\""
						
						// ______________________________________________________
					: (This:C1470.catalog[$vector.dataclassName][$vector.vectorName]=Null:C1517)
						
						$v.error:="Missing vector \""+$vector.vectorName+"\"of dataclass \""+$vector.dataclassName+"\""
						
						// ______________________________________________________
					: (String:C10(This:C1470.catalog[$vector.dataclassName][$vector.vectorName].classID)#"4D.Vector")
						
						$v.error:=$vector.vectorName+"\"of dataclass \""+$vector.dataclassName+"\" is not a Vector"
						
						// ______________________________________________________
				End case 
				
				$vectors.push($v)
				
			Else 
				
				// Update with saved definition
				$v.model:=String:C10($vector.model)
				$v.phrase:=$vector.phrase
				$v.version:=$vector.version#Null:C1517 ? Num:C11($vector.version) : $v.version
				
			End if 
		End for each 
	End if 
	
	return $vectors.orderBy("dataclassName asc, vectorName asc")
	
	// MARK:- [MODELS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readModels() : Collection
	
	// TODO: Read models
	return []
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function moreManager()
	
	//
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function phraseManager()
	
	var $e:=FORM Event:C1606
	var $vector : cs:C1710.Vector:=This:C1470.currentVector
	var $plainText:=ST Get plain text:C1092(*; "phrase")  //Get edited text
	
	Case of 
			
			// ______________________________________________________
		: ($e.code=On Clicked:K2:4)
			
			If ($vector=Null:C1517) || Not:C34(Contextual click:C713)
				
				return 
				
			End if 
			
			var $menu:=cs:C1710.menu.new()
			
			// TODO: Menu Cut, Copy, Paste, Select All & sub menu insert
			var $attribute : Object
			
			For each ($attribute; $vector.supportedAttributes.sort(Formula:C1597(String:C10($1.name)<String:C10($1.name))))
				
				$menu.append($attribute.name; "{"+$attribute.name+"}")
				
			End for each 
			
			If (Not:C34($menu.popup().selected))
				
				return 
				
			End if 
			var $startSel; $endSel : Integer
			GET HIGHLIGHT:C209(*; "phrase"; $startSel; $endSel)
			
			var $newValue:=Substring:C12($plainText; 1; $startSel-1)+$menu.choice+Substring:C12($plainText; $endSel)
			
			OBJECT SET VALUE:C1742("phrase"; $newValue)
			
			$endSel:=$startSel+Length:C16($menu.choice)
			HIGHLIGHT TEXT:C210(*; "phrase"; $endSel; $endSel)
			
			// ______________________________________________________
		: ($e.code=On Before Keystroke:K2:6)
			
			//
			
			// ______________________________________________________
		: ($e.code=On After Edit:K2:43)
			
			// Remove styles
			OBJECT SET VALUE:C1742("phrase"; $plainText)
			
			// Highlight any errors, if any
			$vector.phrase:=$vector.parsePhrase($vector.phrase)
			
			// ______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			// Highlight any errors, if any
			ST SET TEXT:C1115(*; "phrase"; $vector.parsePhrase(OBJECT Get value:C1743("phrase")); ST Start text:K78:15; ST End text:K78:16)
			
			// ______________________________________________________
		Else 
			
			// A "Case of" statement should never omit "Else"
			
			// ______________________________________________________
	End case 
	
	
	