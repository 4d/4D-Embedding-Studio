property embedCalls : Collection:=[]
property embedBatchCalls : Collection:=[]
property criticalModels : Collection:=[]
property nonCriticalTexts : Collection:=[]
property counter : Integer:=0

Class constructor($options : Object)
	$options:=$options || {}
	This:C1470.criticalModels:=$options.criticalModels || []
	This:C1470.nonCriticalTexts:=$options.nonCriticalTexts || []
	
Function embed($text : Text; $model : Text) : 4D:C1709.Vector
	This:C1470.embedCalls.push({text: $text; model: $model})
	This:C1470._maybeThrow([$text]; $model)
	return This:C1470._vectorFor($text; $model)
	
Function embedBatch($texts : Collection; $model : Text) : Collection
	var $copy : Collection:=($texts=Null:C1517) ? [] : $texts.copy()
	This:C1470.embedBatchCalls.push({texts: $copy; model: $model})
	This:C1470._maybeThrow($copy; $model)
	
	
	var $vectors : Collection:=[]
	var $text : Text
	For each ($text; $copy)
		$vectors.push(This:C1470._vectorFor($text; $model))
	End for each 
	
	return $vectors
	
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