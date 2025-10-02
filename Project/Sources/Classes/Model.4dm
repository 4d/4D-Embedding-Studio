property name : Text  // Name displayed in the drop list for the user)
property model : Text  // The identifier of the model to retrieve. (e.g., “text-embedding-3-large”)
property apiKey : Text  // OpenAI API Key.

property baseURL : Text  // Base URL for OpenAI API requests. (optional)
property organization : Text  // OpenAI Organization ID. (optional)
property project : Text  // OpenAI Project ID. (optional)

property valid : Boolean

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