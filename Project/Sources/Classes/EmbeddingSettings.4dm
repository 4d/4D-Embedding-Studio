property file : 4D:C1709.File
property vectors : Collection  // of cs:C1710.EmbeddingDefinition
property batchSize : Integer:=50
property phrase : Object  // { allowRelations, allowCalculated, allowAlias }

Class constructor($file : 4D:C1709.File)
	
	This:C1470[""]:={raw: {}}
	This:C1470.file:=$file || Folder:C1567(fk database folder:K87:14; *).file("Settings/vectors.json")
	This:C1470.vectors:=[]
	This:C1470.phrase:=This:C1470._defaultPhraseOptions()
	
	This:C1470.load()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Reads the settings file, if any, and populates This.vectors with EmbeddingDefinition objects.
	// Also loads This.batchSize and This.phrase (allow* options).
	// Any unknown top-level keys (e.g. "models") are preserved internally and restored on save.
Function load()
	
	This:C1470.vectors:=[]
	This:C1470[""].raw:={}
	This:C1470.batchSize:=50
	This:C1470.phrase:=This:C1470._defaultPhraseOptions()
	
	If (Not:C34(This:C1470.file.exists))
		
		return 
		
	End if 
	
	var $raw : Variant:=Try(JSON Parse:C1218(This:C1470.file.getText()))
	
	If (Value type:C1509($raw)#Is object:K8:27)
		
		return 
		
	End if 
	
	This:C1470[""].raw:=$raw
	
	If (Value type:C1509($raw.batchSize)=Is real:K8:4)
		
		var $bs : Integer:=Num:C11($raw.batchSize)
		If ($bs>0)
			
			This:C1470.batchSize:=$bs
			
		End if 
	End if 
	
	If (Value type:C1509($raw.phrase)=Is object:K8:27)
		
		This:C1470.phrase.allowRelations:=Bool:C1537($raw.phrase.allowRelations)
		This:C1470.phrase.allowCalculated:=Bool:C1537($raw.phrase.allowCalculated)
		This:C1470.phrase.allowAlias:=Bool:C1537($raw.phrase.allowAlias)
		
	End if 
	
	If ($raw.vectors=Null:C1517)
		
		return 
		
	End if 
	
	var $saved : Object
	For each ($saved; $raw.vectors)
		
		var $def : cs:C1710.EmbeddingDefinition:=cs:C1710.EmbeddingDefinition.new(\
			String:C10($saved.dataclassName); \
			String:C10($saved.vectorName); \
			String:C10($saved.model); \
			String:C10($saved.phrase))
		$def.version:=$saved.version#Null:C1517 ? Num:C11($saved.version) : $def.version
		
		This:C1470.vectors.push($def)
		
	End for each 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Serializes This.vectors, batchSize and phrase options back to the settings file,
	// preserving any other top-level keys.
Function save()
	
	var $out : Object:=This:C1470[""].raw || {}
	$out.vectors:=[]
	$out.batchSize:=This:C1470.batchSize
	$out.phrase:={\
		allowRelations: Bool:C1537(This:C1470.phrase.allowRelations); \
		allowCalculated: Bool:C1537(This:C1470.phrase.allowCalculated); \
		allowAlias: Bool:C1537(This:C1470.phrase.allowAlias)}
	// TODO: if $out.phrase is default one -> remove
	OB REMOVE:C1226($out; "phrase")
	
	var $def : cs:C1710.EmbeddingDefinition
	For each ($def; This:C1470.vectors)
		
		$out.vectors.push($def.toObject())
		
	End for each 
	
	This:C1470[""].raw:=$out
	This:C1470.file.setText(JSON Stringify:C1217($out; *))
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the saved EmbeddingDefinition for the given dataclass/vector, or Null.
Function find($dataclassName : Text; $vectorName : Text) : cs:C1710.EmbeddingDefinition
	
	return This:C1470.vectors.query("dataclassName = :1 & vectorName = :2"; $dataclassName; $vectorName).first()
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _defaultPhraseOptions() : Object
	
	return {\
		allowRelations: False:C215; \
		allowCalculated: False:C215; \
		allowAlias: False:C215}
	