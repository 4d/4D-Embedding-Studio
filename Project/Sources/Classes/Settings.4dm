
property definitions : Collection  // of cs:C1710.Definition
property batchSize : Integer
property phrase : Object  // optionnal { allowRelations, allowCalculated, allowAlias, allowObject }
property embedder : Object  // optional { className?, maxRetries?, backoffMs?, … }
property _isDev : Boolean

Class constructor($file : 4D:C1709.File)
	
	This:C1470[""]:={raw: {}}
	This:C1470.definitions:=[]
	
	If ($file#Null:C1517)
		If (Asserted:C1132(Application type:C494#4D Remote mode:K5:5; "Cannot propose settings file if remote. Execute the code on server"))
			cs:C1710._Settings.me.file:=$file
		End if 
	End if 
	
	This:C1470.load()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Reads the settings file, if any, and populates This.definitions with Definition objects.
	// Also loads This.batchSize and This.phrase (allow* options).
	// Any unknown top-level keys (e.g. "models") are preserved internally and restored on save.
Function load()
	
	This:C1470.definitions:=[]
	This:C1470[""].raw:={}
	This:C1470.batchSize:=This:C1470._defaultBatchSize()
	This:C1470.phrase:=This:C1470._defaultPhraseOptions()
	This:C1470.embedder:=Null:C1517
	This:C1470._isDev:=(Structure file:C489=Structure file:C489(*))
	
	var $raw:=cs:C1710._Settings.me.get()
	
	If ($raw=Null:C1517)
		
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
		var $key : Text
		For each ($key; $raw.phrase)
			This:C1470.phrase[$key]:=$raw.phrase[$key]
		End for each 
	End if 
	
	If (Value type:C1509($raw.embedder)=Is object:K8:27)
		This:C1470.embedder:=$raw.embedder
	End if 
	
	This:C1470._isDev:=This:C1470._isDev || Bool:C1537($raw.dev)
	
	If ($raw.definitions=Null:C1517)
		
		return 
		
	End if 
	
	var $saved : Object
	For each ($saved; $raw.definitions)
		
		var $def : cs:C1710.Definition:=cs:C1710.Definition.new(\
			String:C10($saved.dataclassName); \
			String:C10($saved.vectorName); \
			String:C10($saved.modelAlias); \
			String:C10($saved.phrase))
		$def.autoInvalidate:=($saved.autoInvalidate=Null:C1517) ? True:C214 : Bool:C1537($saved.autoInvalidate)
		This:C1470.definitions.push($def)
		
	End for each 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Serializes This.definitions, batchSize and phrase options back to the settings file,
	// preserving any other top-level keys.
Function save()
	
	var $out : Object:=This:C1470[""].raw || {}
	If (This:C1470.batchSize#This:C1470._defaultBatchSize())
		$out.batchSize:=This:C1470.batchSize
	End if 
	var $phraseOpts : Object:={\
		allowRelations: Bool:C1537(This:C1470.phrase.allowRelations); \
		allowCalculated: Bool:C1537(This:C1470.phrase.allowCalculated); \
		allowAlias: Bool:C1537(This:C1470.phrase.allowAlias); \
		allowObject: Bool:C1537(This:C1470.phrase.allowObject)}
	var $defaults : Object:=This:C1470._defaultPhraseOptions()
	If (($phraseOpts.allowRelations=$defaults.allowRelations)\
		 && ($phraseOpts.allowCalculated=$defaults.allowCalculated)\
		 && ($phraseOpts.allowAlias=$defaults.allowAlias)\
		 && ($phraseOpts.allowObject=$defaults.allowObject))
		OB REMOVE:C1226($out; "phrase")
	Else 
		$out.phrase:=$phraseOpts
	End if 
	
	$out.definitions:=This:C1470.definitions.copy().filter(Formula:C1597($1.value.hasDefinition)).map(Formula:C1597($1.value.toObject()))
	
	If (This:C1470.embedder#Null:C1517)
		$out.embedder:=This:C1470.embedder
	Else 
		OB REMOVE:C1226($out; "embedder")
	End if 
	
	If (This:C1470._isDev)
		$out.dev:=True:C214
	End if 
	
	This:C1470[""].raw:=$out
	
	cs:C1710._Settings.me.set($out)
	
	// Return the file used 
Function get file : 4D:C1709.File
	return cs:C1710._Settings.me.file
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the saved Definition for the given dataclass/vector, or Null.
Function find($dataclassName : Text; $vectorName : Text) : cs:C1710.Definition
	
	return This:C1470.definitions.query("dataclassName = :1 & vectorName = :2"; $dataclassName; $vectorName).first()
	
	// Returns the saved Definitions for the given dataclass
Function findAll($dataclassName : Text) : Collection
	
	return This:C1470.definitions.query("dataclassName = :1 "; $dataclassName)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Calls invalidateVectors() on every definition and merges the results.
	// Returns {updated: Integer; skipped: Integer; errors: Collection of Text}
Function invalidateVectors() : Object
	
	var $updated : Integer:=0
	var $skipped : Integer:=0
	var $errors : Collection:=[]
	
	var $def : cs:C1710.Definition
	For each ($def; This:C1470.definitions)
		
		var $result : Object:=$def.invalidateVectors()
		$updated+=$result.updated
		$skipped+=$result.skipped
		$errors.combine($result.errors)
		
	End for each 
	
	return {updated: $updated; skipped: $skipped; errors: $errors}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the definitions whose resolved model (provider+model) changed between the two alias
	// maps AND that already hold computed vectors. Used to warn before invalidating on alias edits.
	// $beforeModels / $afterModels : alias maps { aliasName: { provider; model } }.
Function _affectedByAliasChange($beforeModels : Object; $afterModels : Object) : Collection
	
	var $before : Object:=$beforeModels || {}
	var $after : Object:=$afterModels || {}
	var $affected : Collection:=[]
	
	var $def : cs:C1710.Definition
	For each ($def; This:C1470.definitions)
		
		var $alias : Text:=String:C10($def.modelAlias)
		If (Length:C16($alias)=0)
			continue
		End if 
		
		var $b : Object:=$before[$alias]
		var $a : Object:=$after[$alias]
		
		// Rename-away or brand-new alias => not a silent model change, skip.
		If (($b=Null:C1517) || ($a=Null:C1517))
			continue
		End if 
		
		// Same resolved provider+model => nothing changed for this alias.
		If ((String:C10($a.provider)=String:C10($b.provider)) && (String:C10($a.model)=String:C10($b.model)))
			continue
		End if 
		
		// Only warn when there is at least one computed vector to protect.
		If ($def._hasVectorComputed())
			$affected.push($def)
		End if 
		
	End for each 
	
	return $affected
	
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _defaultPhraseOptions() : Object
	
	return {\
		allowRelations: False:C215; \
		allowCalculated: False:C215; \
		allowAlias: False:C215; \
		allowObject: False:C215}
	
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _defaultBatchSize() : Integer
	return 50
	