// Test-only embedder mock used across the Process/Embedder test suite.
// Records every embed()/embedBatch() call and returns deterministic vectors.
//
// Optional behaviours are opt-in via constructor options (no need for dedicated
// subclasses):
//   - criticalModels / criticalAfterCalls / nonCriticalTexts : simulate failures
//   - rateLimits                                             : drive _RateLimiter
//   - delaySeconds  (was _TestProcessEmbedderSlow)           : artificial latency
//   - dataclassName + entityKey + touchField/touchSuffix
//     (was _TestProcessEmbedderOptimisticLock)               : force a concurrent
//        modification during embed()/embedBatch() to trigger an optimistic-lock save failure.

property embedCalls : Collection:=[]
property embedBatchCalls : Collection:=[]
property criticalModels : Collection:=[]
property criticalAfterCalls : Object:={}  // { modelAlias: N } -> allow first N calls for that model to succeed, then throw critical on call N+1
property nonCriticalTexts : Collection:=[]
property rateLimits : Collection:=[]
property _rateLimitIndex : Integer:=0
property _modelCallCounts : Object:={}
property counter : Integer:=0

// --- optional: artificial latency (formerly _TestProcessEmbedderSlow) ---
property delaySeconds : Real:=0

// --- optional: concurrent modification / optimistic lock (formerly _TestProcessEmbedderOptimisticLock) ---
property dataclassName : Text:=""
property entityKey : Variant:=Null:C1517
property touchField : Text:="lastName"
property touchSuffix : Text:="_lock"
property touchCount : Integer:=0
property touchErrors : Collection:=[]

Class constructor($options : Object)
	$options:=$options || {}
	This:C1470.criticalModels:=$options.criticalModels || []
	This:C1470.criticalAfterCalls:=$options.criticalAfterCalls || {}
	This:C1470.nonCriticalTexts:=$options.nonCriticalTexts || []
	This:C1470.rateLimits:=$options.rateLimits || []

	var $delay : Real:=Num:C11($options.delaySeconds)
	If ($delay>0)
		This:C1470.delaySeconds:=$delay
	End if

	This:C1470.dataclassName:=String:C10($options.dataclassName)
	This:C1470.entityKey:=$options.entityKey
	If (Length:C16(String:C10($options.touchField))>0)
		This:C1470.touchField:=String:C10($options.touchField)
	End if
	If (Length:C16(String:C10($options.touchSuffix))>0)
		This:C1470.touchSuffix:=String:C10($options.touchSuffix)
	End if

Function embed($text : Text; $model : Text) : cs:C1710.EmbedderResult
	This:C1470.embedCalls.push({text: $text; model: $model})
	This:C1470._maybeThrow([$text]; $model)
	This:C1470._touchConcurrentEntity()
	This:C1470._maybeDelay()
	return cs:C1710.EmbedderResult.new({\
		vector: This:C1470._vectorFor($text; $model); \
		usage: {prompt_tokens: Length:C16($text); total_tokens: Length:C16($text)}; \
		rateLimit: This:C1470._mockRateLimit()}; False:C215)

Function embedBatch($texts : Collection; $model : Text) : cs:C1710.EmbedderResult
	var $copy : Collection:=($texts=Null:C1517) ? [] : $texts.copy()
	This:C1470.embedBatchCalls.push({texts: $copy; model: $model})
	This:C1470._maybeThrow($copy; $model)

	// Optional: force a concurrent update between phrase rendering and entity.save()
	// to create a stale snapshot in Process and trigger an optimistic-lock failure.
	This:C1470._touchConcurrentEntity()
	This:C1470._maybeDelay()

	var $vectors : Collection:=[]
	var $totalChars : Integer:=0
	var $text : Text
	For each ($text; $copy)
		$vectors.push(This:C1470._vectorFor($text; $model))
		$totalChars+=Length:C16($text)
	End for each

	return cs:C1710.EmbedderResult.new({\
		vectors: $vectors; \
		usage: {prompt_tokens: $totalChars; total_tokens: $totalChars}; \
		rateLimit: This:C1470._mockRateLimit()}; True:C214)

Function _maybeDelay()
	If (This:C1470.delaySeconds>0)
		DELAY PROCESS:C323(Current process:C322; Int:C8(This:C1470.delaySeconds*60))
	End if

Function _touchConcurrentEntity()
	If ((Length:C16(This:C1470.dataclassName)=0) || (This:C1470.entityKey=Null:C1517))
		return
	End if

	Try
		var $dc : 4D:C1709.DataClass:=ds:C1482[This:C1470.dataclassName]
		If ($dc=Null:C1517)
			This:C1470.touchErrors.push("dataclass not found: "+This:C1470.dataclassName)
			return
		End if

		var $entity : 4D:C1709.Entity:=$dc.get(This:C1470.entityKey)
		If ($entity=Null:C1517)
			This:C1470.touchErrors.push("entity not found: "+String:C10(This:C1470.entityKey))
			return
		End if

		var $field : Text:=This:C1470.touchField
		var $current : Text:=String:C10($entity[$field])
		$entity[$field]:=$current+This:C1470.touchSuffix+String:C10(This:C1470.touchCount+1)

		var $status : Object:=$entity.save()
		If ($status.success)
			This:C1470.touchCount+=1
		Else
			This:C1470.touchErrors.push(String:C10($status.statusText))
		End if
	Catch
		This:C1470.touchErrors.push(String:C10(Last errors:C1799[0].message))
	End try

Function _maybeThrow($texts : Collection; $model : Text)
	If (This:C1470.criticalModels.includes($model))
		throw:C1805({componentSignature: "4DES"; isCriticalAPIError: True:C214; model: $model; message: "Critical test failure for "+$model; errors: [{status: 400; message: "Critical test failure for "+$model}]})
	End if

	If (This:C1470.criticalAfterCalls[$model]#Null:C1517)
		This:C1470._modelCallCounts[$model]:=Num:C11(This:C1470._modelCallCounts[$model])+1
		If (This:C1470._modelCallCounts[$model]>Num:C11(This:C1470.criticalAfterCalls[$model]))
			throw:C1805({componentSignature: "4DES"; isCriticalAPIError: True:C214; model: $model; message: "Critical test failure for "+$model+" after "+String:C10(This:C1470.criticalAfterCalls[$model])+" calls"; errors: [{status: 400; message: "Critical test failure for "+$model}]})
		End if
	End if

	var $text : Text
	For each ($text; $texts || [])
		If (This:C1470.nonCriticalTexts.includes($text))
			throw:C1805({componentSignature: "4DES"; message: "Non-critical test failure for "+$text})
		End if
	End for each

Function _vectorFor($text : Text; $model : Text) : 4D:C1709.Vector
	This:C1470.counter+=1
	return 4D:C1709.Vector.new([This:C1470.counter; Length:C16(String:C10($text)); Length:C16($model)])

Function _mockRateLimit() : Object
	If (This:C1470.rateLimits.length>0)
		var $rl : Object:=This:C1470.rateLimits[This:C1470._rateLimitIndex]
		If (This:C1470._rateLimitIndex<(This:C1470.rateLimits.length-1))
			This:C1470._rateLimitIndex+=1
		End if
		return $rl
	End if
	return {remaining: {tokens: 100000; request: 500}; limit: {tokens: 150000; request: 1000}; reset: {tokens: "1m0s"; request: "1s"}}
