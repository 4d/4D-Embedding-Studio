
property definitions : Collection  // of cs:C1710.Definition
property batchSize : Integer
property phrase : Object  // optionnal { allowRelations, allowCalculated, allowAlias, allowObject }
property embedder : Object  // optional { className?, maxRetries?, backoffMs?, … }
property _isDev : Boolean
property _loadFailed : Boolean  // True when the settings file exists but could not be read

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
	This:C1470._loadFailed:=False:C215
	This:C1470[""].baseDefinitions:=[]
	
	var $read : Object:=cs:C1710._Settings.me.read()
	
	// An existing file we cannot parse is not "no settings": saving on top of it would
	// replace the definitions and the scheduler configuration with defaults. Remember it,
	// and let save() refuse.
	If ($read.exists && Not:C34($read.valid))
		
		This:C1470._loadFailed:=True:C214
		cs:C1710._Logger.me.error("Settings file cannot be read, it will not be overwritten: "+String:C10(This:C1470.file.path))
		
		return 
		
	End if 
	
	var $raw : Object:=$read.data
	
	If ($raw=Null:C1517)
		
		return 
		
	End if 
	
	This:C1470[""].raw:=$raw  // the file as it was when we loaded it; save() does not refresh it
	
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
	
	If (Value type:C1509($raw.definitions)#Is collection:K8:32)
		
		return 
		
	End if 
	
	// Snapshot of what was on disk when we loaded: save() diffs against it to merge with
	// whatever another editor may have written in the meantime.
	This:C1470[""].baseDefinitions:=$raw.definitions.copy()
	
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
	// preserving any other top-level keys, and merging the definitions with whatever the file
	// holds now (another editor may have written to it since this instance loaded).
	// Returns False, without touching the file, when the settings could not be read at load
	// time — saving then would replace real settings with defaults.
Function save() : Boolean
	
	If (This:C1470._loadFailed)
		
		cs:C1710._Logger.me.error("Settings not saved: the file could not be read when this instance loaded it ("+String:C10(This:C1470.file.path)+")")
		
		return False:C215
		
	End if 
	
	// Only the keys this class owns: _Settings.set() preserves everything else that is in the
	// file (the scheduler configuration, model aliases…). Rewriting them from the snapshot
	// taken at load time would restore stale values over whatever was saved meanwhile.
	// A key set to Null is removed from the file, which is how "back to the default" persists.
	var $out : Object:={}
	$out.batchSize:=(This:C1470.batchSize#This:C1470._defaultBatchSize()) ? This:C1470.batchSize : Null:C1517
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
		// explicit Null, not OB REMOVE: the setter removes a key only when it is passed as Null,
		// so dropping it here would leave the previous options in the file
		$out.phrase:=Null:C1517
	Else 
		$out.phrase:=$phraseOpts
	End if 
	
	$out.definitions:=This:C1470._mergeDefinitions(\
		This:C1470.definitions.copy().filter(Formula:C1597($1.value.hasDefinition)).map(Formula:C1597($1.value.toObject())))
	
	If (This:C1470.embedder#Null:C1517)
		$out.embedder:=This:C1470.embedder
	Else 
		$out.embedder:=Null:C1517
	End if 
	
	If (This:C1470._isDev)
		$out.dev:=True:C214
	End if 
	
	cs:C1710._Settings.me.set($out)
	
	// what we just wrote is the new common ancestor for the next save
	This:C1470[""].baseDefinitions:=$out.definitions.copy()
	
	return True:C214
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Three-way merge of the definitions: the snapshot this instance loaded (the common
	// ancestor), what it holds now, and what the file holds at this instant. Definitions are
	// keyed by dataclassName + vectorName. Without this, two editors open at the same time
	// silently drop each other's definitions — the last save simply rewrote the whole array.
Function _mergeDefinitions($mine : Collection) : Collection
	
	var $read : Object:=cs:C1710._Settings.me.read()
	var $disk : Collection:=[]
	
	If ($read.valid && ($read.data#Null:C1517) && (Value type:C1509($read.data.definitions)=Is collection:K8:32))
		$disk:=$read.data.definitions
	End if 
	
	var $base : Collection:=This:C1470[""].baseDefinitions || []
	
	// The file is where we left it: nothing to merge, ours is authoritative.
	If (JSON Stringify:C1217($disk)=JSON Stringify:C1217($base))
		
		return $mine
		
	End if 
	
	var $result : Collection:=$disk.copy()
	var $def : Object
	
	// definitions this instance dropped since it loaded
	For each ($def; $base)
		
		If (This:C1470._findDefinition($mine; $def)=Null:C1517)
			$result:=$result.filter(Formula:C1597(($1.value.dataclassName#$2) || ($1.value.vectorName#$3)); String:C10($def.dataclassName); String:C10($def.vectorName))
		End if 
		
	End for each 
	
	// definitions this instance added or edited since it loaded
	For each ($def; $mine)
		
		var $ancestor : Object:=This:C1470._findDefinition($base; $def)
		
		If (($ancestor#Null:C1517) && (JSON Stringify:C1217($ancestor)=JSON Stringify:C1217($def)))
			continue  // untouched here, keep whatever the file holds
		End if 
		
		var $index : Integer:=$result.findIndex(Formula:C1597(($1.value.dataclassName=$2) && ($1.value.vectorName=$3)); String:C10($def.dataclassName); String:C10($def.vectorName))
		
		If ($index=-1)
			$result.push($def)
		Else 
			$result[$index]:=$def
		End if 
		
	End for each 
	
	return $result
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// The entry of $collection matching $def's dataclass/vector pair, or Null.
Function _findDefinition($collection : Collection; $def : Object) : Object
	
	return $collection.query("dataclassName = :1 & vectorName = :2"; String:C10($def.dataclassName); String:C10($def.vectorName)).first()
	
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
	