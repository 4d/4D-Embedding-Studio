/**
 Thin wrapper around 4D AIKit embeddings API.
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
Function embed($text : Text; $model : Text) : cs:C1710.EmbedderResult

	var $result:=This:C1470._createWithRetry($text; $model)

	return cs:C1710.EmbedderResult.new($result; False:C215)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Embed a collection of texts in a single API call.
	// Returns a EmbedderResult with vectors in same order as inputs.
Function embedBatch($texts : Collection; $model : Text) : cs:C1710.EmbedderResult

	If (($texts=Null:C1517) || ($texts.length=0))

		return cs:C1710.EmbedderResult.new()

	End if

	var $result:=This:C1470._createWithRetry($texts; $model)

	return cs:C1710.EmbedderResult.new($result; True:C214)
	
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _shouldRetry($result : cs:C1710.AIKit.OpenAIEmbeddingsResult) : Boolean
	ASSERT:C1129(Not:C34($result.success))
	
	return $result.errors.reduce(Formula:C1597($1.accumulate:=$1.accumulate || Bool:C1537($1.value.isRateLimitError)); False:C215)
	
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
		If (Not:C34(This:C1470._shouldRetry($result)))
			var $fatalCode : Text:=""
			If (($result.errors#Null:C1517) && ($result.errors.length>0))
				$fatalCode:=String:C10($result.errors[0].status)
			End if 
			
			throw:C1805({componentSignature: "4DES"; \
				isCriticalAPIError: True:C214; \
				model: $model; \
				errorCode: $fatalCode; \
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
		
		var $timestamp : Text:=String:C10(Current date:C33)+"T"+String:C10(Current time:C178)
		cs:C1710._Logger.me.warn({\
			event: "Rate limit hit"; \
			model: $model; \
			delay: String:C10($delay)+"ms"; \
			timestamp: $timestamp; \
			attempt: String:C10($attempt+1)+"/"+String:C10(This:C1470.maxRetries)\
			})
		
		DELAY PROCESS:C323(Current process:C322; $delay*60/1000)  // ticks ≈ ms*60/1000
		
		$attempt+=1
		
	End while 
	
	// Exhausted retries
	var $retryErrorCode : Text:=""
	If (($result#Null:C1517) && ($result.errors#Null:C1517) && ($result.errors.length>0))
		$retryErrorCode:=String:C10($result.errors[0].status)
	End if 
	throw:C1805({\
		componentSignature: "4DES"; \
		errorCode: $retryErrorCode; \
		message: Replace string:C233(Localized string:C991("errApiUnreachable"); "{retries}"; String:C10(This:C1470.maxRetries)); \
		errors: $result.errors})
	
	return $result
	