property name : Text  // Name displayed in the drop list for the user)
property model : Text  // The identifier of the model to retrieve. (e.g., “text-embedding-3-large”)
property apiKey : Text  // OpenAI API Key.

property baseURL : Text  // Base URL for OpenAI API requests. (optional)
property organization : Text  // OpenAI Organization ID. (optional)
property project : Text  // OpenAI Project ID. (optional)

property needAPIKey : Boolean
property valid : Boolean
property errors:=[]

Class constructor(\
$name : Text; \
$model : Text; \
$apiKey : Text; \
$optionals : Object)
	
	This:C1470.name:=$name
	This:C1470.model:=$model  //|| "text-embedding-3-large"
	This:C1470.apiKey:=$apiKey
	
	If ($optionals#Null:C1517)
		
		var $key : Text
		
		For each ($key; $optionals)
			
			This:C1470[$key]:=$optionals[$key]
			
		End for each 
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Function get valid() : Boolean
	
var $t : Text
For each ($t; This.needAPIKey ? ["name"; "apiKey"; "model"] : ["name"; "model"])
	
If (Length(String(This[$t]))=0)
	
var $error:=Replace string(Localized string("theValueIsRequired."); "{value}"; Localized string($t))
	
If (Not(This.errors.includes($error)))
	
This.errors.push($error)
	
End if 
	
return 
	
End if 
End for each 
*/
	
	
	