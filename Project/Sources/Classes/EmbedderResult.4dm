/**
 Typed wrapper for Embedder API responses.
 Normalizes OpenAI snake_case keys to camelCase properties.
 Handles both single (embed) and batch (embedBatch) results.
**/

property vector : 4D:C1709.Vector
property vectors : Collection

property promptTokens : Integer:=0
property totalTokens : Integer:=0

property remainingTokens : Integer:=-1
property remainingRequests : Integer:=-1
property limitTokens : Integer:=0
property limitRequests : Integer:=0
property resetTokens : Text
property resetRequests : Text

Class constructor($result : Object; $isBatch : Boolean)
	
	This:C1470.vectors:=[]
	
	If (Count parameters:C259=0) || ($result=Null:C1517)
		return 
	End if 
	
	If ($isBatch)
		This:C1470.vectors:=$result.vectors || []
	Else 
		This:C1470.vector:=$result.vector
		This:C1470.vectors:=[$result.vector]
	End if 
	
	// usage: {prompt_tokens, total_tokens} → camelCase
	var $usage : Object:=$result.usage
	If ($usage#Null:C1517)
		This:C1470.promptTokens:=Num:C11($usage.prompt_tokens)
		This:C1470.totalTokens:=Num:C11($usage.total_tokens)
	End if 
	
	// rateLimit: {remaining: {tokens, request}, limit: {tokens, request}, reset: {tokens, request}}
	var $rl : Object:=$result.rateLimit
	If ($rl#Null:C1517)
		If ($rl.remaining#Null:C1517)
			If ($rl.remaining.tokens#Null:C1517)
				This:C1470.remainingTokens:=Num:C11($rl.remaining.tokens)
			End if 
			If ($rl.remaining.request#Null:C1517)
				This:C1470.remainingRequests:=Num:C11($rl.remaining.request)
			End if 
		End if 
		If ($rl.limit#Null:C1517)
			If ($rl.limit.tokens#Null:C1517)
				This:C1470.limitTokens:=Num:C11($rl.limit.tokens)
			End if 
			If ($rl.limit.request#Null:C1517)
				This:C1470.limitRequests:=Num:C11($rl.limit.request)
			End if 
		End if 
		If ($rl.reset#Null:C1517)
			If ($rl.reset.tokens#Null:C1517)
				This:C1470.resetTokens:=String:C10($rl.reset.tokens)
			End if 
			If ($rl.reset.request#Null:C1517)
				This:C1470.resetRequests:=String:C10($rl.reset.request)
			End if 
		End if 
	End if 
	