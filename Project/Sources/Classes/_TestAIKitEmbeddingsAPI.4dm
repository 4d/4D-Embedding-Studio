// Test-only mock for the AIKit embeddings.create() endpoint (used by the REAL
// cs.Embedder class via Embedder.new({client: cs._TestAIKitClient.new({embeddings: ...})})).
// Lets tests deterministically simulate rate-limit (429) responses — with or
// without a Retry-After hint — followed by eventual success, without touching
// any real network or the 4DAIKitTest mock server.

property callCount : Integer:=0
property rateLimitCount : Integer:=0  // fail the first N calls with a rate-limit error, then succeed
property failOnCallNumbers : Collection:=[]  // specific 1-based call numbers to fail with a rate-limit error
property retryAfterSec : Integer:=0  // if > 0, included as the Retry-After hint on every rate-limited response
property alwaysFail : Boolean:=False:C215  // never succeeds (used to exhaust retries deterministically)
property callTimestampsMs : Collection:=[]

Class constructor($options : Object)
	$options:=$options || {}
	This:C1470.rateLimitCount:=Num:C11($options.rateLimitCount)
	This:C1470.failOnCallNumbers:=$options.failOnCallNumbers || []
	This:C1470.retryAfterSec:=Num:C11($options.retryAfterSec)
	This:C1470.alwaysFail:=Bool:C1537($options.alwaysFail)

Function create($input : Variant; $model : Text) : Object
	This:C1470.callCount+=1
	This:C1470.callTimestampsMs.push(Milliseconds:C459)
	
	var $shouldFail : Boolean:=This:C1470.alwaysFail || (This:C1470.callCount<=This:C1470.rateLimitCount) || This:C1470.failOnCallNumbers.includes(This:C1470.callCount)
	
	If ($shouldFail)
		return {\
			success: False:C215; \
			errors: [{isRateLimitError: True:C214; status: 429; message: "Rate limit exceeded (mock)"}]; \
			_retryAfterValue: This:C1470.retryAfterSec}
	End if 
	
	If (Value type:C1509($input)=Is collection:K8:32)
		var $vectors : Collection:=[]
		var $totalChars : Integer:=0
		var $text : Text
		For each ($text; $input)
			$vectors.push(4D:C1709.Vector.new([Length:C16($text); 1; 1]))
			$totalChars+=Length:C16($text)
		End for each 
		return {success: True:C214; vectors: $vectors; usage: {prompt_tokens: $totalChars; total_tokens: $totalChars}}
	End if 
	
	var $len : Integer:=Length:C16(String:C10($input))
	return {success: True:C214; vector: 4D:C1709.Vector.new([$len; 1; 1]); usage: {prompt_tokens: $len; total_tokens: $len}}
