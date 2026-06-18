/**
 Orchestrator for computing and storing embeddings on 4D entities.
 
 Usage:
   var $p:=cs.EmbeddingStudio.Process.new()              // uses defaults
   var $p:=cs.EmbeddingStudio.Process.new($settings; $options)

   $p.process()                                    // all definitions in settings
   $p.process($def)                                // one or a collection of definitions
   $p.processEntity($entity)                       // infer definitions from entity
   $p.processEntity($entity; $def)
   $p.processEntitySelection($es; $def)
 
 All entry points return a cs.EmbeddingStudio.ProcessResult.

 For ad-hoc rendering and embedding without persistence, see cs.EmbeddingStudio.Playground.

 Options object ($options)

 | Key | Type | Default | Description |
 | --- | --- | --- | --- |
 | onProgress | 4D.Function | Null | Optional callback fired during selection processing after each batch. Receives `{definition, report}`. |
 | onSuccess | 4D.Function | Null | Optional callback fired once when processing ends with `report.success = true`. Receives `{report, success, errors}`. |
 | onError | 4D.Function | Null | Optional callback fired once when processing ends with `report.success = false`. Receives `{report, success, errors}`. |
 | onTerminate | 4D.Function | Null | Optional callback fired once at the end in all cases (after `onSuccess` or `onError`). Receives `{report, success, errors}`. |
 | dryRun | Boolean | False | If true, computes filtering/progress only and skips writes/API calls. |
 | force | Boolean | False | If true, bypasses "already embedded / not dirty" filtering and recomputes all targeted rows. |
 | debug | Boolean | False | If true, emits extra diagnostic log entries. |
 | embedder | cs.EmbeddingStudio.Embedder | New embedder instance | Optional embedder override, mainly for tests or custom providers. |
**/

Class extends _ProcessBase

property _failedModels : Collection

// MARK:-[CONSTRUCTOR]
Class constructor($settings : cs:C1710.Settings; $options : Object)
	
	Super:C1705($settings; $options)
	This:C1470._failedModels:=[]
	
	// MARK:-[PUBLIC]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Process one, many, or all Definitions across their full dataclass selections.
	// $definition may be: Null (= all definitions in settings), a single Definition,
	//                     or a collection of Definition.
Function process($definition : Variant) : cs:C1710.ProcessResult
	
	var $report : cs:C1710.ProcessResult:=cs:C1710.ProcessResult.new()
	var $defs : Collection:=This:C1470.resolver.resolveForProcess($definition)
	var $isFullRun : Boolean:=($definition=Null:C1517)
	var $execLog : cs:C1710._ExecutionLog:=cs:C1710._ExecutionLog.me
	
	If ($isFullRun)
		$execLog.startFullRun($report._startTimestamp)
	End if 
	
	var $def : cs:C1710.Definition
	For each ($def; $defs)
		
		var $defKey : Text:=String:C10($def.dataclassName)+"."+String:C10($def.vectorName)
		var $defStartTime : Text:=Timestamp:C1445
		var $errCountBefore : Integer:=$report.errors.length
		var $tokensBefore : Object:={prompt_tokens: $report.promptTokens; total_tokens: $report.totalTokens}
		
		If (Not:C34(This:C1470._validateDefinition($def; $report)))
			
			$execLog.updateDefinition($defKey; $defStartTime; Timestamp:C1445; "failed"; \
				This:C1470._buildErrorSummary($report.errors.slice($errCountBefore)); Null:C1517)
			continue
			
		End if 
		
		If (This:C1470._failedModels.includes($def.modelAlias))
			
			$report._addError("definition"; cs:C1710.ProcessErrorCode.me.MODEL_SKIPPED; $defKey; \
				Replace string:C233(Localized string:C991("errModelSkipped"); "{model}"; String:C10($def.modelAlias)))
			$execLog.updateDefinition($defKey; $defStartTime; Timestamp:C1445; "skipped"; \
				"Model '"+String:C10($def.modelAlias)+"' encountered a critical API error"; Null:C1517)
			continue
			
		End if 
		
		var $dc : 4D:C1709.DataClass:=ds:C1482[$def.dataclassName]
		This:C1470._runOnSelection($dc.all(); $def; $report; This:C1470._isDebug())
		
		var $defErrors : Collection:=$report.errors.slice($errCountBefore)
		var $defUsage : Object:={prompt_tokens: $report.promptTokens-$tokensBefore.prompt_tokens; total_tokens: $report.totalTokens-$tokensBefore.total_tokens}
		$execLog.updateDefinition($defKey; $defStartTime; Timestamp:C1445; \
			($defErrors.length=0) ? "completed" : "failed"; \
			This:C1470._buildErrorSummary($defErrors); $defUsage)
		
	End for each 
	
	var $result : cs:C1710.ProcessResult:=This:C1470._doneWithCallbacks($report)
	
	If ($isFullRun)
		$execLog.endFullRun($result._startTimestamp; Timestamp:C1445; \
			$result.success ? "completed" : "failed"; \
			This:C1470._buildErrorSummary($result.errors); \
			This:C1470.options.nextComputeDate; \
			{prompt_tokens: $result.promptTokens; total_tokens: $result.totalTokens})
	End if 
	
	return $result
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Process a single entity. $definition rules match resolveForEntity.
Function processEntity($entity : 4D:C1709.Entity; $definition : Variant) : cs:C1710.ProcessResult
	
	var $report : cs:C1710.ProcessResult:=cs:C1710.ProcessResult.new()
	
	If ($entity=Null:C1517)
		
		$report._addError("entity"; cs:C1710.ProcessErrorCode.me.NULL_INPUT; Null:C1517; Localized string:C991("errNullEntity"))
		return This:C1470._doneWithCallbacks($report)
		
	End if 
	
	var $dcName : Text:=This:C1470.resolver.dataclassNameFromEntity($entity)
	var $defs : Collection:=This:C1470.resolver.resolveForEntity($definition; $dcName)
	
	var $def : cs:C1710.Definition
	For each ($def; $defs)
		
		If (Not:C34(This:C1470._validateDefinition($def; $report)))
			
			continue
			
		End if 
		
		If (This:C1470._failedModels.includes($def.modelAlias))
			
			$report._addError("definition"; cs:C1710.ProcessErrorCode.me.MODEL_SKIPPED; String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
				Replace string:C233(Localized string:C991("errModelSkipped"); "{model}"; String:C10($def.modelAlias)))
			continue
			
		End if 
		
		This:C1470._runOnEntity($entity; $def; $report; This:C1470._isDebug())
		
	End for each 
	
	return This:C1470._doneWithCallbacks($report)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Process an entity selection. Preferred path for large jobs — honors batchSize.
Function processEntitySelection($es : 4D:C1709.EntitySelection; $definition : Variant) : cs:C1710.ProcessResult
	
	var $report : cs:C1710.ProcessResult:=cs:C1710.ProcessResult.new()
	
	If ($es=Null:C1517)
		
		$report._addError("pipeline"; cs:C1710.ProcessErrorCode.me.NULL_INPUT; Null:C1517; Localized string:C991("errNullSelection"))
		return This:C1470._doneWithCallbacks($report)
		
	End if 
	
	var $dcName : Text:=This:C1470.resolver.dataclassNameFromSelection($es)
	var $defs : Collection:=This:C1470.resolver.resolveForEntity($definition; $dcName)
	
	var $def : cs:C1710.Definition
	For each ($def; $defs)
		
		If (Not:C34(This:C1470._validateDefinition($def; $report)))
			
			continue
			
		End if 
		
		If (This:C1470._failedModels.includes($def.modelAlias))
			
			$report._addError("definition"; cs:C1710.ProcessErrorCode.me.MODEL_SKIPPED; String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
				Replace string:C233(Localized string:C991("errModelSkipped"); "{model}"; String:C10($def.modelAlias)))
			continue
			
		End if 
		
		This:C1470._runOnSelection($es; $def; $report; This:C1470._isDebug())
		
	End for each 
	
	return This:C1470._doneWithCallbacks($report)
	
	
	// MARK:-[PRIVATE]
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Finalize report and fire optional lifecycle callbacks.
	// Callbacks are Formula receiving ({report, success, errors}).
Function _doneWithCallbacks($report : cs:C1710.ProcessResult) : cs:C1710.ProcessResult
	
	var $done : cs:C1710.ProcessResult:=$report._done()
	var $payload : Object:={report: $done; success: $done.success; errors: $done.errors}
	
	If ($done.success)
		var $onSuccess : 4D:C1709.Function:=This:C1470.options.onSuccess
		If ($onSuccess#Null:C1517)
			Try($onSuccess.call(Null:C1517; $payload))
		End if 
	Else 
		var $onError : 4D:C1709.Function:=This:C1470.options.onError
		If ($onError#Null:C1517)
			Try($onError.call(Null:C1517; $payload))
		End if 
	End if 
	
	var $onTerminate : 4D:C1709.Function:=This:C1470.options.onTerminate
	If ($onTerminate#Null:C1517)
		Try($onTerminate.call(Null:C1517; $payload))
	End if 
	
	return $done
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// is debug info 
Function _isDebug() : Boolean
	return (This:C1470.options.debug#Null:C1517) ? Bool:C1537(This:C1470.options.debug) : Get database parameter:C643(Diagnostic log level:K37:108)<=Log debug:K37:110
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Validates a definition before running. On failure, records all errors in report and returns False.
Function _validateDefinition($def : cs:C1710.Definition; $report : cs:C1710.ProcessResult) : Boolean
	
	If ($def=Null:C1517)
		
		$report._addError("definition"; cs:C1710.ProcessErrorCode.me.NULL_INPUT; Null:C1517; Localized string:C991("errNullDefinition"))
		return False:C215
		
	End if 
	
	If ($def.validate=Null:C1517)
		
		$report._addError("definition"; cs:C1710.ProcessErrorCode.me.INVALID_DEFINITION; Null:C1517; Replace string:C233(Localized string:C991("errInvalidDefinition"); "{definition}"; JSON Stringify:C1217($def)))
		return False:C215
		
	End if 
	
	var $validation : Object:=$def.validate(This:C1470.settings)
	
	var $ref : Text:=String:C10($def.dataclassName)+"."+String:C10($def.vectorName)
	If (Not:C34($validation.success))
		
		var $error : Object
		For each ($error; $validation.errors)
			$report._addError("definition"; cs:C1710.ProcessErrorCode.me.VALIDATION_FAILED; $ref; $error.message)
		End for each 
		return False:C215
		
	End if 
	
	return True:C214
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Single-entity fast path (no chunking, no server-side filter).
Function _runOnEntity($entity : 4D:C1709.Entity; $def : cs:C1710.Definition; $report : cs:C1710.ProcessResult; $debug : Boolean)
	
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
		var $embedResult : cs:C1710.EmbedderResult:=This:C1470.embedder.embed($text; $def.modelAlias)
		var $vector : 4D:C1709.Vector:=$embedResult.vector
		$report._addUsage($embedResult)
		
		$entity[$def.vectorName]:=$vector
		
		If ($hasDirty)
			
			$entity[$dirtyField]:=False:C215
			
		End if 
		
		var $status : Object:=$entity.save()
		
		If ($status.success)
			
			$report.entitiesUpdated+=1
			
			If ($debug)
				cs:C1710._Logger.me.debug("Vector recomputed — vector: "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)\
					+"; entityID: "+String:C10(This:C1470._entityRef($entity))\
					+"; duration: "+String:C10(Milliseconds:C459-$entityStartMs)+"ms")
			End if 
			
		Else 
			
			$report.entitiesSkipped+=1
			$report._addError("entity"; cs:C1710.ProcessErrorCode.me.SAVE_FAILED; This:C1470._entityRef($entity); String:C10($status.statusText))
			cs:C1710._Logger.me.error({\
				event: "Local 4D error"; \
				vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
				entityID: This:C1470._entityRef($entity); \
				message: String:C10($status.statusText); \
				timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
				})
			If ($hasDirty)
				cs:C1710._Logger.me.info({\
					event: "Vector still dirty after save during recomputation"; \
					vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
					entityID: This:C1470._entityRef($entity); \
					timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
					})
			End if 
			
		End if 
		
	Catch
		
		var $entityErr : Object:=Last errors:C1799[0]
		$report.entitiesSkipped+=1
		If (Bool:C1537($entityErr.isCriticalAPIError))
			This:C1470._failedModels.push(String:C10($def.modelAlias))
			$report._addError("pipeline"; cs:C1710.ProcessErrorCode.me.MODEL_UNAVAILABLE; String:C10($def.modelAlias); String:C10($entityErr.message))
			var $entityErrorCode : Text:=String:C10($entityErr.errorCode)
			If ((Length:C16($entityErrorCode)=0) && ($entityErr.errors#Null:C1517) && ($entityErr.errors.length>0))
				$entityErrorCode:=String:C10($entityErr.errors[0].status)
			End if 
			cs:C1710._Logger.me.error({\
				event: "Critical API error"; \
				model: String:C10($def.modelAlias); \
				errorCode: $entityErrorCode; \
				affectedVectorCount: 1; \
				message: String:C10($entityErr.message)\
				})
			return 
		End if 
		$report._addError("entity"; cs:C1710.ProcessErrorCode.me.EMBED_FAILED; This:C1470._entityRef($entity); String:C10($entityErr.message))
		cs:C1710._Logger.me.error({\
			event: "Local 4D error"; \
			vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
			entityID: This:C1470._entityRef($entity); \
			message: String:C10($entityErr.message); \
			timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
			})
		
	End try
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Core pipeline: filter → chunk → embed → persist.
Function _runOnSelection($es : 4D:C1709.EntitySelection; $def : cs:C1710.Definition; $report : cs:C1710.ProcessResult; $debug : Boolean)
	
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
	cs:C1710._Logger.me.info({\
		event: "Recalculation started"; \
		vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
		entities: $pending.length; \
		timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
		})
	
	var $configBatchSize : Integer:=Num:C11(This:C1470.settings.batchSize)
	If ($configBatchSize<=0)
		$configBatchSize:=50
	End if 
	
	var $limiter : cs:C1710._RateLimiter:=cs:C1710._RateLimiter.new($configBatchSize)
	var $batchSize : Integer:=$configBatchSize
	
	var $i : Integer:=0
	While ($i<$pending.length)
		
		$limiter.waitIfNeeded(Int:C8($batchSize*$limiter.tokensPerEntity))
		$batchSize:=$limiter.nextBatchSize()
		
		var $chunk : 4D:C1709.EntitySelection:=$pending.slice($i; $i+$batchSize)
		var $chunkResult : cs:C1710.EmbedderResult
		Try
			
			$chunkResult:=This:C1470._processChunk($chunk; $def; $hasDirty; $dirtyField; $report; $debug)
			
		Catch
			
			If (Bool:C1537(Last errors:C1799[0].isCriticalAPIError))
				This:C1470._failedModels.push(String:C10($def.modelAlias))
				var $chunkCriticalErr : Object:=Last errors:C1799[0]
				var $chunkErrorCode : Text:=String:C10($chunkCriticalErr.errorCode)
				If ((Length:C16($chunkErrorCode)=0) && ($chunkCriticalErr.errors#Null:C1517) && ($chunkCriticalErr.errors.length>0))
					$chunkErrorCode:=String:C10($chunkCriticalErr.errors[0].status)
				End if 
				cs:C1710._Logger.me.error({\
					event: "Critical API error"; \
					model: String:C10($def.modelAlias); \
					vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
					errorCode: $chunkErrorCode; \
					affectedVectorCount: $chunk.length; \
					message: String:C10($chunkCriticalErr.message)\
					})
				return 
			End if 
			
		End try
		
		$limiter.update($chunkResult; $chunk.length)
		This:C1470._notifyProgress($def; $report)
		
		$i+=$chunk.length
		
	End while 
	
	cs:C1710._Logger.me.info({\
		event: "Recalculation completed"; \
		vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
		duration: String:C10(Milliseconds:C459-$selStartMs)+"ms"; \
		success: $report.entitiesUpdated-$updatedBefore; \
		failure: $report.entitiesSkipped-$skippedBefore\
		})
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Filter an entity selection down to rows that need (re)computation.
	// Uses server-side query when possible (vector is null OR dirty flag set).
Function _filterNeedsRecompute($es : 4D:C1709.EntitySelection; $def : cs:C1710.Definition; $hasDirty : Boolean) : 4D:C1709.EntitySelection
	
	If (Bool:C1537(This:C1470.options.force))
		
		return $es
		
	End if 
	
	// Attribute names come from Definition (developer-controlled), not user input,
	// so interpolating them into the query string is safe.
	var $q : Text:=$def.vectorName+" = null"
	
	If ($hasDirty)
		
		$q:=$q+" OR "+$def.vectorName+"_dirty = true"
		
	End if 
	
	return $es.query($q)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Process one chunk: build texts, call API once, zip vectors back, persist each entity.
	// Returns the EmbedderResult for rate-limit tracking.
Function _processChunk($chunk : 4D:C1709.EntitySelection; $def : cs:C1710.Definition; $hasDirty : Boolean; $dirtyField : Text; $report : cs:C1710.ProcessResult; $debug : Boolean) : cs:C1710.EmbedderResult
	
	// Build texts (positional: $texts[i] corresponds to $chunk entity #i)
	var $texts : Collection:=[]
	var $entity : 4D:C1709.Entity
	
	For each ($entity; $chunk)
		
		$texts.push($def.phrase.render($entity))
		
	End for each 
	
	// Single API call for the whole chunk
	var $vectors : Collection
	var $embedResult : cs:C1710.EmbedderResult
	$report.apiCalls+=1
	var $chunkStartMs : Integer:=Milliseconds:C459
	
	Try
		
		$embedResult:=This:C1470.embedder.embedBatch($texts; $def.modelAlias)
		$vectors:=$embedResult.vectors
		$report._addUsage($embedResult)
		
	Catch
		
		var $chunkErr : Object:=Last errors:C1799[0]
		$report.entitiesSkipped+=$chunk.length
		If (Bool:C1537($chunkErr.isCriticalAPIError))
			$report._addError("pipeline"; cs:C1710.ProcessErrorCode.me.MODEL_UNAVAILABLE; String:C10($def.modelAlias); String:C10($chunkErr.message))
			throw:C1805($chunkErr)
		End if 
		$report._addError("chunk"; cs:C1710.ProcessErrorCode.me.EMBED_FAILED; $def.dataclassName+"."+$def.vectorName; String:C10($chunkErr.message))
		return $embedResult
		
	End try
	
	If (($vectors=Null:C1517) || ($vectors.length#$chunk.length))
		
		$report._addError("chunk"; cs:C1710.ProcessErrorCode.me.VECTOR_COUNT_MISMATCH; $def.dataclassName+"."+$def.vectorName; Replace string:C233(Replace string:C233(Localized string:C991("errVectorCountMismatch"); "{got}"; String:C10($vectors.length)); "{expected}"; String:C10($chunk.length)))
		$report.entitiesSkipped+=$chunk.length
		return $embedResult
		
	End if 
	
	// Persist — one save per entity (4D entity save is atomic)
	var $k : Integer:=0
	For each ($entity; $chunk)
		
		var $entityStartMs : Integer
		If ($debug)
			$entityStartMs:=Milliseconds:C459
		End if 
		
		Try
			
			$entity[$def.vectorName]:=$vectors[$k]
			
			If ($hasDirty)
				
				$entity[$dirtyField]:=False:C215
				
			End if 
			
			var $status : Object:=$entity.save()
			
			If ($status.success)
				
				$report.entitiesUpdated+=1
				
				If ($debug)
					cs:C1710._Logger.me.debug("Vector recomputed — vector: "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)\
						+"; entityID: "+String:C10(This:C1470._entityRef($entity))\
						+"; duration: "+String:C10(Milliseconds:C459-$entityStartMs)+"ms")
				End if 
				
			Else 
				
				$report.entitiesSkipped+=1
				$report._addError("entity"; cs:C1710.ProcessErrorCode.me.SAVE_FAILED; This:C1470._entityRef($entity); String:C10($status.statusText))
				cs:C1710._Logger.me.error({\
					event: "Local 4D error"; \
					vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
					entityID: This:C1470._entityRef($entity); \
					message: String:C10($status.statusText); \
					timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
					})
				If ($hasDirty)
					cs:C1710._Logger.me.info({\
						event: "Vector still dirty after save during recomputation"; \
						vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
						entityID: This:C1470._entityRef($entity); \
						timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
						})
				End if 
				
			End if 
			
		Catch
			
			$report.entitiesSkipped+=1
			$report._addError("entity"; cs:C1710.ProcessErrorCode.me.SAVE_FAILED; This:C1470._entityRef($entity); Last errors:C1799[0].message)
			cs:C1710._Logger.me.error({\
				event: "Local 4D error"; \
				vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
				entityID: This:C1470._entityRef($entity); \
				message: String:C10(Last errors:C1799[0].message); \
				timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
				})
			If ($hasDirty)
				cs:C1710._Logger.me.info({\
					event: "Vector still dirty after save during recomputation"; \
					vector: String:C10($def.dataclassName)+"."+String:C10($def.vectorName); \
					entityID: This:C1470._entityRef($entity); \
					timestamp: String:C10(Current date:C33)+"T"+String:C10(Current time:C178)\
					})
			End if 
			
		End try
		
		$k+=1
		
	End for each 
	
	return $embedResult
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Fire optional onProgress callback (Formula receiving ({definition, report})).
Function _notifyProgress($def : cs:C1710.Definition; $report : cs:C1710.ProcessResult)
	
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
Function _buildErrorSummary($errors : Collection) : Variant
	
	If ($errors.length=0)
		return Null:C1517
	End if 
	
	If ($errors.length=1)
		return String:C10($errors[0].message)
	End if 
	
	return String:C10($errors.length)+" errors. First: "+String:C10($errors[0].message)
	
	
	