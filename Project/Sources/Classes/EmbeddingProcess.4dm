/**
 Orchestrator for computing and storing embeddings on 4D entities.

 Usage:
   var $p:=cs.EmbeddingProcess.new()              // uses defaults
   var $p:=cs.EmbeddingProcess.new($settings; $options)

   $p.process()                                    // all definitions in settings
   $p.process($def)                                // one or a collection of definitions
   $p.processEntity($entity)                       // infer definitions from entity
   $p.processEntity($entity; $def)
   $p.processEntitySelection($es; $def)

 All entry points return a cs.EmbeddingProcessResult.
**/

property settings : cs:C1710.EmbeddingSettings
property processor : cs:C1710.EmbeddingProcessor
property resolver : cs:C1710._EmbeddingResolver
property options : Object  // { onProgress, dryRun, force, debug }
property _failedModels : Collection

// MARK:-[CONSTRUCTOR]
Class constructor($settings : cs:C1710.EmbeddingSettings; $options : Object)
	
	This:C1470.settings:=$settings || cs:C1710.EmbeddingSettings.new()
	This:C1470.resolver:=cs:C1710._EmbeddingResolver.new(This:C1470.settings)
	This:C1470.options:=$options || {}
	This:C1470.processor:=$options.processor || cs:C1710.EmbeddingProcessor.new()
	This:C1470._failedModels:=[]
	
	// MARK:-[PUBLIC]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Process one, many, or all EmbeddingDefinitions across their full dataclass selections.
	// $definition may be: Null (= all definitions in settings), a single EmbeddingDefinition,
	//                     or a collection of EmbeddingDefinition.
Function process($definition : Variant) : cs:C1710.EmbeddingProcessResult
	
	var $report : cs:C1710.EmbeddingProcessResult:=cs:C1710.EmbeddingProcessResult.new()
	var $defs : Collection:=This:C1470.resolver.resolveForProcess($definition)
	
	var $def : cs:C1710.EmbeddingDefinition
	For each ($def; $defs)
		
		If (Not:C34(This:C1470._validateDefinition($def; $report)))
			
			continue
			
		End if 
		
		If (This:C1470._failedModels.includes($def.model))
			
			$report._addError("definition"; String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
				"Skipped: model '"+String:C10($def.model)+"' encountered a critical API error")
			continue
			
		End if 
		
		var $dc : 4D:C1709.DataClass:=ds:C1482[$def.dataclassName]
		This:C1470._runOnSelection($dc.all(); $def; $report)
		
	End for each 
	
	return $report._done()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Process a single entity. $definition rules match resolveForEntity.
Function processEntity($entity : 4D:C1709.Entity; $definition : Variant) : cs:C1710.EmbeddingProcessResult
	
	var $report : cs:C1710.EmbeddingProcessResult:=cs:C1710.EmbeddingProcessResult.new()
	
	If ($entity=Null:C1517)
		
		$report._addError("entity"; Null:C1517; "Null entity")
		return $report._done()
		
	End if 
	
	var $dcName : Text:=This:C1470.resolver.dataclassNameFromEntity($entity)
	var $defs : Collection:=This:C1470.resolver.resolveForEntity($definition; $dcName)
	
	var $def : cs:C1710.EmbeddingDefinition
	For each ($def; $defs)
		
		If (Not:C34(This:C1470._validateDefinition($def; $report)))
			
			continue
			
		End if 
		
		If (This:C1470._failedModels.includes($def.model))
			
			$report._addError("definition"; String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
				"Skipped: model '"+String:C10($def.model)+"' encountered a critical API error")
			continue
			
		End if 
		
		This:C1470._runOnEntity($entity; $def; $report)
		
	End for each 
	
	return $report._done()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Process an entity selection. Preferred path for large jobs — honors batchSize.
Function processEntitySelection($es : 4D:C1709.EntitySelection; $definition : Variant) : cs:C1710.EmbeddingProcessResult
	
	var $report : cs:C1710.EmbeddingProcessResult:=cs:C1710.EmbeddingProcessResult.new()
	
	If ($es=Null:C1517)
		
		$report._addError("selection"; Null:C1517; "Null entity selection")
		return $report._done()
		
	End if 
	
	var $dcName : Text:=This:C1470.resolver.dataclassNameFromSelection($es)
	var $defs : Collection:=This:C1470.resolver.resolveForEntity($definition; $dcName)
	
	var $def : cs:C1710.EmbeddingDefinition
	For each ($def; $defs)
		
		If (Not:C34(This:C1470._validateDefinition($def; $report)))
			
			continue
			
		End if 
		
		If (This:C1470._failedModels.includes($def.model))
			
			$report._addError("definition"; String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
				"Skipped: model '"+String:C10($def.model)+"' encountered a critical API error")
			continue
			
		End if 
		
		This:C1470._runOnSelection($es; $def; $report)
		
	End for each 
	
	return $report._done()
	
	// MARK:-[PLAYGROUND — ad-hoc, non-persisting helpers]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Render the phrase for an entity and return the resulting text. No API call, no persistence.
	// $definitionOrPhrase may be:
	//   - cs.Phrase                  → used directly
	//   - cs.EmbeddingDefinition     → uses $definition.phrase
	//   - Text                       → compiled on the fly as a new Phrase
	//   - Null                       → auto-resolved from settings (requires a unique match for $entity's dataclass)
Function render($entity : 4D:C1709.Entity; $definitionOrPhrase : Variant) : Text
	
	If ($entity=Null:C1517)
		
		return ""
		
	End if 
	
	var $phrase : cs:C1710.Phrase:=This:C1470._phraseFrom($entity; $definitionOrPhrase)
	
	If ($phrase=Null:C1517)
		
		return ""
		
	End if 
	
	return $phrase.render($entity)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Compute a vector for an arbitrary input — without persisting anywhere.
	// Useful for previews, similarity checks, REPL experimentation, or ad-hoc querying.
	//
	// Supported call shapes:
	//   embed("some text"; "text-embedding-3-small")          → direct embed
	//   embed("some text"; $definition)                        → uses $definition.model
	//   embed($entity; $definition)                            → renders definition.phrase, embeds with definition.model
	//   embed($entity; $phrase; "text-embedding-3-small")      → renders $phrase, embeds with given model
	//   embed($entity; "template with {field}"; "model")       → compiles template on the fly
	//   embed($entity)                                         → auto-resolve definition from settings (unique match required)
	//
	// Throws if no model can be determined.
Function embed($input : Variant; $context : Variant; $model : Text) : 4D:C1709.Vector
	
	var $text : Text
	var $modelName : Text:=$model
	
	Case of 
			
			// ______________________________________________________
		: (Value type:C1509($input)=Is text:K8:3)
			
			// Text input → $context is the model (or an EmbeddingDefinition holding a model)
			$text:=$input
			
			Case of 
					
				: (Value type:C1509($context)=Is text:K8:3)
					
					$modelName:=$context
					
				: (OB Instance of:C1731($context; cs:C1710.EmbeddingDefinition))
					
					$modelName:=String:C10($context.model)
					
			End case 
			
			// ______________________________________________________
		Else 
			
			// Assume entity (anything else falls through validation below)
			var $phrase : cs:C1710.Phrase:=This:C1470._phraseFrom($input; $context)
			
			If ($phrase=Null:C1517)
				
				throw:C1805({componentSignature: "4DES"; message: "No phrase could be resolved for the given entity/context"})
				
			End if 
			
			$text:=$phrase.render($input)
			
			// Pick model from $context if it's a definition, otherwise rely on $model, otherwise auto-resolve
			If (OB Instance of:C1731($context; cs:C1710.EmbeddingDefinition))
				
				$modelName:=String:C10($context.model)
				
			End if 
			
			If (Length:C16($modelName)=0)
				
				var $resolved : cs:C1710.EmbeddingDefinition:=This:C1470._resolveDefinitionFromEntity($input)
				If ($resolved#Null:C1517)
					
					$modelName:=String:C10($resolved.model)
					
				End if 
			End if 
			
			// ______________________________________________________
	End case 
	
	If (Length:C16($modelName)=0)
		
		throw:C1805({componentSignature: "4DES"; message: "No model specified (and none could be resolved from settings)"})
		
	End if 
	
	return This:C1470.processor.embed($text; $modelName)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Polymorphic phrase extraction: Phrase | EmbeddingDefinition | Text template | Null (auto-resolve).
Function _phraseFrom($entity : 4D:C1709.Entity; $definitionOrPhrase : Variant) : cs:C1710.Phrase
	
	Case of 
			
			// ______________________________________________________
		: (OB Instance of:C1731($definitionOrPhrase; cs:C1710.Phrase))
			
			return $definitionOrPhrase
			
			// ______________________________________________________
		: (OB Instance of:C1731($definitionOrPhrase; cs:C1710.EmbeddingDefinition))
			
			return $definitionOrPhrase.phrase
			
			// ______________________________________________________
		: (Value type:C1509($definitionOrPhrase)=Is text:K8:3)
			
			return cs:C1710.Phrase.new($definitionOrPhrase)
			
			// ______________________________________________________
		: ($definitionOrPhrase=Null:C1517)
			
			var $resolved : cs:C1710.EmbeddingDefinition:=This:C1470._resolveDefinitionFromEntity($entity)
			return ($resolved=Null:C1517) ? Null:C1517 : $resolved.phrase
			
			// ______________________________________________________
	End case 
	
	return Null:C1517
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Best-effort resolution of a single definition for an entity's dataclass.
	// Returns Null when the match is not unique (0 or >1) — caller must specify explicitly.
Function _resolveDefinitionFromEntity($entity : 4D:C1709.Entity) : cs:C1710.EmbeddingDefinition
	
	If ($entity=Null:C1517)
		
		return Null:C1517
		
	End if 
	
	var $dcName : Text:=This:C1470.resolver.dataclassNameFromEntity($entity)
	var $matches : Collection:=This:C1470.settings.vectors.query("dataclassName = :1"; $dcName)
	
	return ($matches.length=1) ? $matches[0] : Null:C1517
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Validates a definition before running. On failure, records all errors in report and returns False.
Function _validateDefinition($def : cs:C1710.EmbeddingDefinition; $report : cs:C1710.EmbeddingProcessResult) : Boolean
	
	If ($def=Null:C1517)
		
		$report._addError("definition"; Null:C1517; "Null definition")
		return False:C215
		
	End if 
	
	var $ref : Text:=String:C10($def.dataclassName)+"."+String:C10($def.vectorName)
	var $validation : Object:=$def.validate(This:C1470.settings)
	
	If (Not:C34($validation.success))
		
		var $error : Object
		For each ($error; $validation.errors)
			$report._addError("definition"; $ref; $error.message)
		End for each 
		return False:C215
		
	End if 
	
	return True:C214
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Single-entity fast path (no chunking, no server-side filter).
Function _runOnEntity($entity : 4D:C1709.Entity; $def : cs:C1710.EmbeddingDefinition; $report : cs:C1710.EmbeddingProcessResult)
	
	var $dc : 4D:C1709.DataClass:=$entity.getDataClass()
	var $dirtyField : Text:=$def.vectorName+"_dirty"
	var $hasDirty : Boolean:=cs:C1710._dataclassAttributes.me.hasField($dc; $dirtyField)
	
	$report.entitiesConsidered+=1
	$report.definitionsProcessed+=1
	
	// Skip if vector already present and not dirty (unless force)
	If (Not:C34(Bool:C1537(This:C1470.options.force)))
		
		var $hasVector : Boolean:=($entity[$def.vectorName]#Null:C1517)
		var $isDirty : Boolean:=$hasDirty && Bool:C1537($entity[$dirtyField])
		
		If ($hasVector && (Not:C34($isDirty)))
			
			return 
			
		End if 
	End if 
	
	If (Bool:C1537(This:C1470.options.dryRun))
		
		return 
		
	End if 
	
	$report.apiCalls+=1
	
	var $entityStartMs : Integer:=Milliseconds:C459
	
	Try
		
		var $text : Text:=$def.phrase.render($entity)
		var $vector : 4D:C1709.Vector:=This:C1470.processor.embed($text; $def.model)
		
		$entity[$def.vectorName]:=$vector
		
		If ($hasDirty)
			
			$entity[$dirtyField]:=False:C215
			
		End if 
		
		var $status : Object:=$entity.save()
		
		If ($status.success)
			
			$report.entitiesUpdated+=1
			This:C1470._logDebug("Vector recomputed — vector: "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)\
				+"; entityID: "+String:C10(This:C1470._entityRef($entity))\
				+"; duration: "+String:C10(Milliseconds:C459-$entityStartMs)+"ms")
			
		Else 
			
			$report.entitiesSkipped+=1
			$report._addError("entity"; This:C1470._entityRef($entity); String:C10($status.statusText))
			
		End if 
		
	Catch
		
		var $entityErr : Object:=Last errors:C1799[0]
		$report.entitiesSkipped+=1
		If (Bool:C1537($entityErr.isCriticalAPIError))
			This:C1470._failedModels.push(String:C10($def.model))
			$report._addError("model"; String:C10($def.model); String:C10($entityErr.message))
			LOG EVENT:C667(Into 4D diagnostic log:K38:8; \
				"[4DES] Critical API error — model: "+String:C10($def.model)\
				+"; message: "+String:C10($entityErr.message); \
				Error message:K38:3)
			return 
		End if 
		$report._addError("entity"; This:C1470._entityRef($entity); String:C10($entityErr.message))
		
	End try
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Core pipeline: filter → chunk → embed → persist.
Function _runOnSelection($es : 4D:C1709.EntitySelection; $def : cs:C1710.EmbeddingDefinition; $report : cs:C1710.EmbeddingProcessResult)
	
	var $dc : 4D:C1709.DataClass:=ds:C1482[$def.dataclassName]
	var $dirtyField : Text:=$def.vectorName+"_dirty"
	var $hasDirty : Boolean:=cs:C1710._dataclassAttributes.me.hasField($dc; $dirtyField)
	
	var $pending : 4D:C1709.EntitySelection:=This:C1470._filterNeedsRecompute($es; $def; $hasDirty)
	$report.entitiesConsidered+=$pending.length
	$report.definitionsProcessed+=1
	
	If ($pending.length=0)
		
		return 
		
	End if 
	
	If (Bool:C1537(This:C1470.options.dryRun))
		
		return 
		
	End if 
	
	var $selStartMs : Integer:=Milliseconds:C459
	var $updatedBefore : Integer:=$report.entitiesUpdated
	var $skippedBefore : Integer:=$report.entitiesSkipped
	LOG EVENT:C667(Into 4D diagnostic log:K38:8; \
		"[4DES] Recalculation started — vector: "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)\
		+"; entities: "+String:C10($pending.length)\
		+"; timestamp: "+String:C10(Current date:C33)+"T"+String:C10(Current time:C178); \
		Information message:K38:1)
	
	var $batchSize : Integer:=Num:C11(This:C1470.settings.batchSize)
	If ($batchSize<=0)
		
		$batchSize:=50
		
	End if 
	
	var $i : Integer:=0
	While ($i<$pending.length)
		
		var $chunk : 4D:C1709.EntitySelection:=$pending.slice($i; $i+$batchSize)
		Try
			
			This:C1470._processChunk($chunk; $def; $hasDirty; $dirtyField; $report)
			
		Catch
			
			If (Bool:C1537(Last errors:C1799[0].isCriticalAPIError))
				This:C1470._failedModels.push(String:C10($def.model))
				LOG EVENT:C667(Into 4D diagnostic log:K38:8; \
					"[4DES] Critical API error — model: "+String:C10($def.model)\
					+"; vector: "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)\
					+"; message: "+String:C10(Last errors:C1799[0].message); \
					Error message:K38:3)
				return 
			End if 
			
		End try
		
		This:C1470._notifyProgress($def; $report)
		
		$i+=$batchSize
		
	End while 
	
	LOG EVENT:C667(Into 4D diagnostic log:K38:8; \
		"[4DES] Recalculation completed — vector: "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)\
		+"; duration: "+String:C10(Milliseconds:C459-$selStartMs)+"ms"\
		+"; success: "+String:C10($report.entitiesUpdated-$updatedBefore)\
		+"; failure: "+String:C10($report.entitiesSkipped-$skippedBefore); \
		Information message:K38:1)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Filter an entity selection down to rows that need (re)computation.
	// Uses server-side query when possible (vector is null OR dirty flag set).
Function _filterNeedsRecompute($es : 4D:C1709.EntitySelection; $def : cs:C1710.EmbeddingDefinition; $hasDirty : Boolean) : 4D:C1709.EntitySelection
	
	If (Bool:C1537(This:C1470.options.force))
		
		return $es
		
	End if 
	
	// Attribute names come from EmbeddingDefinition (developer-controlled), not user input,
	// so interpolating them into the query string is safe.
	var $q : Text:=$def.vectorName+" = null"
	
	If ($hasDirty)
		
		$q:=$q+" OR "+$def.vectorName+"_dirty = true"
		
	End if 
	
	return $es.query($q)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Process one chunk: build texts, call API once, zip vectors back, persist each entity.
Function _processChunk($chunk : 4D:C1709.EntitySelection; $def : cs:C1710.EmbeddingDefinition; $hasDirty : Boolean; $dirtyField : Text; $report : cs:C1710.EmbeddingProcessResult)
	
	// Build texts (positional: $texts[i] corresponds to $chunk entity #i)
	var $texts : Collection:=[]
	var $entity : 4D:C1709.Entity
	
	For each ($entity; $chunk)
		
		$texts.push($def.phrase.render($entity))
		
	End for each 
	
	// Single API call for the whole chunk
	var $vectors : Collection
	$report.apiCalls+=1
	var $chunkStartMs : Integer:=Milliseconds:C459
	
	Try
		
		$vectors:=This:C1470.processor.embedBatch($texts; $def.model)
		
	Catch
		
		var $chunkErr : Object:=Last errors:C1799[0]
		$report.entitiesSkipped+=$chunk.length
		If (Bool:C1537($chunkErr.isCriticalAPIError))
			$report._addError("model"; String:C10($def.model); String:C10($chunkErr.message))
			throw:C1805($chunkErr)
		End if 
		$report._addError("chunk"; $def.dataclassName+"."+$def.vectorName; String:C10($chunkErr.message))
		return 
		
	End try
	
	If (($vectors=Null:C1517) || ($vectors.length#$chunk.length))
		
		$report._addError("chunk"; $def.dataclassName+"."+$def.vectorName; "Vector count mismatch: got "+String:C10($vectors.length)+" expected "+String:C10($chunk.length))
		$report.entitiesSkipped+=$chunk.length
		return 
		
	End if 
	
	// Persist — one save per entity (4D entity save is atomic)
	var $k : Integer:=0
	For each ($entity; $chunk)
		
		Try
			
			$entity[$def.vectorName]:=$vectors[$k]
			
			If ($hasDirty)
				
				$entity[$dirtyField]:=False:C215
				
			End if 
			
			var $status : Object:=$entity.save()
			
			If ($status.success)
				
				$report.entitiesUpdated+=1
				This:C1470._logDebug("Vector recomputed — vector: "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)\
					+"; entityID: "+String:C10(This:C1470._entityRef($entity)))
				
			Else 
				
				$report.entitiesSkipped+=1
				$report._addError("entity"; This:C1470._entityRef($entity); String:C10($status.statusText))
				
			End if 
			
		Catch
			
			$report.entitiesSkipped+=1
			$report._addError("entity"; This:C1470._entityRef($entity); Last errors:C1799[0].message)
			
		End try
		
		$k+=1
		
	End for each 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Fire optional onProgress callback (Formula receiving ({definition, report})).
Function _notifyProgress($def : cs:C1710.EmbeddingDefinition; $report : cs:C1710.EmbeddingProcessResult)
	
	var $cb : 4D:C1709.Function:=This:C1470.options.onProgress
	
	If ($cb=Null:C1517)
		
		return 
		
	End if 
	
	Try($cb.call(Null:C1517; {definition: $def; report: $report}))
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Best-effort identifier for an entity (primary key if available, else its reference).
Function _entityRef($entity : 4D:C1709.Entity) : Variant
	
	Try
		
		var $key : Variant:=$entity.getKey()
		If ($key#Null:C1517)
			
			return $key
			
		End if 
		
	End try
	
	return String:C10($entity)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Conditional debug logger — no-op when This.option.debug is False.
Function _logDebug($message : Text)
	
	If (Bool:C1537(This:C1470.options.debug))
		LOG EVENT:C667(Into 4D diagnostic log:K38:8; "[4DES] "+$message; Information message:K38:1)
	End if 
	