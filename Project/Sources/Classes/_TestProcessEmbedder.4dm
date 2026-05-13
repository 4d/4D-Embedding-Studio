property embedCalls : Collection:=[]
property embedBatchCalls : Collection:=[]
property criticalModels : Collection:=[]
property nonCriticalTexts : Collection:=[]
property rateLimits : Collection:=[]
property _rateLimitIndex : Integer:=0
property counter : Integer:=0

Class constructor($options : Object)
	$options:=$options || {}
	This:C1470.criticalModels:=$options.criticalModels || []
	This:C1470.nonCriticalTexts:=$options.nonCriticalTexts || []
	This:C1470.rateLimits:=$options.rateLimits || []

Function embed($text : Text; $model : Text) : cs:C1710.EmbedderResult
	This:C1470.embedCalls.push({text: $text; model: $model})
	This:C1470._maybeThrow([$text]; $model)
	return cs:C1710.EmbedderResult.new({\
		vector: This:C1470._vectorFor($text; $model); \
		usage: {prompt_tokens: Length:C16($text); total_tokens: Length:C16($text)}; \
		rateLimit: This:C1470._mockRateLimit()}; False:C215)

Function embedBatch($texts : Collection; $model : Text) : cs:C1710.EmbedderResult
	var $copy : Collection:=($texts=Null:C1517) ? [] : $texts.copy()
	This:C1470.embedBatchCalls.push({texts: $copy; model: $model})
	This:C1470._maybeThrow($copy; $model)

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

Function _maybeThrow($texts : Collection; $model : Text)
	If (This:C1470.criticalModels.includes($model))
		throw:C1805({componentSignature: "4DES"; isCriticalAPIError: True:C214; model: $model; message: "Critical test failure for "+$model; errors: [{status: 400; message: "Critical test failure for "+$model}]})
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
