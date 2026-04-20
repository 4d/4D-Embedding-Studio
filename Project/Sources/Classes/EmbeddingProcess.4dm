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
property options : Object  // { onProgress, dryRun, force }

// MARK:-[CONSTRUCTOR]
Class constructor($settings : cs:C1710.EmbeddingSettings; $options : Object)
	
	This:C1470.settings:=$settings || cs:C1710.EmbeddingSettings.new()
	This:C1470.resolver:=cs:C1710._EmbeddingResolver.new(This:C1470.settings)
	This:C1470.options:=$options || {}
	This:C1470.processor:=$options.processor || cs:C1710.EmbeddingProcessor.new()
	
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
		
		This:C1470._runOnSelection($es; $def; $report)
		
	End for each 
	
	return $report._done()
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Validates a definition before running. On failure, records error in report and returns False.
Function _validateDefinition($def : cs:C1710.EmbeddingDefinition; $report : cs:C1710.EmbeddingProcessResult) : Boolean
	
	If ($def=Null:C1517)
		
		$report._addError("definition"; Null:C1517; "Null definition")
		return False:C215
		
	End if 
	
	var $ref : Text:=String:C10($def.dataclassName)+"."+String:C10($def.vectorName)
	
	If (Length:C16(String:C10($def.dataclassName))=0)
		
		$report._addError("definition"; $ref; "Missing dataclassName")
		return False:C215
		
	End if 
	
	If (Length:C16(String:C10($def.vectorName))=0)
		
		$report._addError("definition"; $ref; "Missing vectorName")
		return False:C215
		
	End if 
	
	If (Length:C16(String:C10($def.model))=0)
		
		$report._addError("definition"; $ref; "No model configured for definition")
		return False:C215
		
	End if 
	
	var $dc : 4D:C1709.DataClass:=ds:C1482[$def.dataclassName]
	
	If ($dc=Null:C1517)
		
		$report._addError("definition"; $ref; "Unknown dataclass: "+$def.dataclassName)
		return False:C215
		
	End if 
	
	var $field : Object:=$dc[$def.vectorName]
	
	If ($field=Null:C1517)
		
		$report._addError("definition"; $ref; "Vector field not found: "+$def.vectorName)
		return False:C215
		
	End if 
	
	If (String:C10($field.classID)#"4D.Vector")
		
		$report._addError("definition"; $ref; "Target field is not a 4D.Vector: "+$def.vectorName)
		return False:C215
		
	End if 
	
	If ($def.phrase=Null:C1517)
		
		$report._addError("definition"; $ref; "Missing phrase")
		return False:C215
		
	End if 
	
	var $validation : Object:=$def.phrase.validate($dc; This:C1470.settings.phrase)
	
	If (Not:C34($validation.success))
		
		$report._addError("definition"; $ref; "Phrase validation failed: "+$validation.errors.extract("message").join(", "))
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
			
		Else 
			
			$report.entitiesSkipped+=1
			$report._addError("entity"; This:C1470._entityRef($entity); String:C10($status.statusText))
			
		End if 
		
	Catch
		
		$report.entitiesSkipped+=1
		$report._addError("entity"; This:C1470._entityRef($entity); Last errors:C1799[0].message)
		
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
	
	var $batchSize : Integer:=Num:C11(This:C1470.settings.batchSize)
	If ($batchSize<=0)
		
		$batchSize:=50
		
	End if 
	
	var $i : Integer:=0
	While ($i<$pending.length)
		
		var $chunk : 4D:C1709.EntitySelection:=$pending.slice($i; $i+$batchSize)
		This:C1470._processChunk($chunk; $def; $hasDirty; $dirtyField; $report)
		
		This:C1470._notifyProgress($def; $report)
		
		$i+=$batchSize
		
	End while 
	
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
	
	Try
		
		$vectors:=This:C1470.processor.embedBatch($texts; $def.model)
		
	Catch
		
		// Entire chunk failed → entities stay dirty, picked up on next run
		$report._addError("chunk"; $def.dataclassName+"."+$def.vectorName; Last errors:C1799[0].message)
		$report.entitiesSkipped+=$chunk.length
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
	