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
$api : Text; \
$options : Object)
	
	This:C1470.name:=$name
	This:C1470.model:=$model || "text-embedding-3-large"
	
	If ($options#Null:C1517)
		
		
		
		
	End if 