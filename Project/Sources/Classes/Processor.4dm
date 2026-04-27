/**
 Thin wrapper around cs.embed.AIKit.OpenAI embeddings API.
 Stateless beyond configuration — safe to share between processes.
 Handles retries + rate-limit backoff; knows nothing about entities.
**/

property client : cs:C1710.AIKit.OpenAI
property maxRetries : Integer:=3
property backoffMs : Integer:=500  // base delay, doubled each retry

// MARK:-[CONSTRUCTOR]
Class constructor($options : Object)
	
	$options:=$options || {}
	
	This:C1470.client:=$options.client || cs:C1710.AIKit.OpenAI.new()
	This:C1470.maxRetries:=($options.maxRetries#Null:C1517) ? Num:C11($options.maxRetries) : 3
	This:C1470.backoffMs:=($options.backoffMs#Null:C1517) ? Num:C11($options.backoffMs) : 500
	
	// MARK:-[PUBLIC]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Embed a single text. Returns a 4D.Vector.
	// Throws on fatal errors after retries are exhausted.
Function embed($text : Text; $model : Text) : 4D:C1709.Vector
	
	var $result : Object:=This:C1470._createWithRetry($text; $model)
	
	return $result.vector
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Embed a collection of texts in a single API call.
	// Returns a collection of 4D.Vector, same order as inputs.
Function embedBatch($texts : Collection; $model : Text) : Collection
	
	If (($texts=Null:C1517) || ($texts.length=0))
		
		return []
		
	End if 
	
	var $result : Object:=This:C1470._createWithRetry($texts; $model)
	
	return $result.vectors
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Calls embeddings.create with retry on transient errors.
	// $input : Text or Collection (AIKit accepts both).
Function _createWithRetry($input : Variant; $model : Text) : cs:C1710.AIKit.OpenAIEmbeddingsResult
	
	var $attempt : Integer:=0
	var $result : cs:C1710.AIKit.OpenAIEmbeddingsResult
	
	While ($attempt<=This:C1470.maxRetries)
		
		$result:=This:C1470.client.embeddings.create($input; $model)
		
		If ($result.success)
			
			return $result
			
		End if 
		
		// Non-retryable → critical error; throw structured object so callers can detect it by model
		If (Not:C34($result._shouldRetry()))
			
			throw:C1805({componentSignature: "4DES"; \
				isCriticalAPIError: True:C214; \
				model: $model; \
				message: String:C10($result.errors[0].message); \
				errors: $result.errors})
			
			return $result  // unreachable
			
		End if 
		
		// Retryable: sleep using Retry-After header hint if present, else exponential backoff
		var $retryAfterSec : Integer:=$result._retryAfterValue
		var $delay : Integer
		
		If ($retryAfterSec>0)
			
			$delay:=$retryAfterSec*1000
			
		Else 
			
			$delay:=This:C1470.backoffMs*(2^$attempt)
			
		End if 
		
		LOG EVENT:C667(Into 4D diagnostic log:K38:8; \
			"[4DES] Rate limit hit — model: "+$model\
			+"; delay: "+String:C10($delay)+"ms"\
			+"; attempt: "+String:C10($attempt+1)+"/"+String:C10(This:C1470.maxRetries); \
			Warning message:K38:2)
		
		DELAY PROCESS:C323(Current process:C322; $delay*60/1000)  // ticks ≈ ms*60/1000
		
		$attempt+=1
		
	End while 
	
	// Exhausted retries
	throw:C1805({\
		componentSignature: "4DES"; \
		message: "Embedding API unreachable after "+String:C10(This:C1470.maxRetries)+" retries"; \
		errors: $result.errors})
	
	return $result
	