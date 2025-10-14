property name : Text
property success : Boolean
property endpoint : cs:C1710.AIKit.OpenAI
property models : Collection

Class constructor($configuration)
	
	Case of 
			
			// ______________________________________________________
		: ($configuration=Null:C1517)  // Default to openAI
			
			This:C1470.name:="openAI"
			This:C1470.endpoint:=cs:C1710.AIKit.OpenAI.new(This:C1470.apiKey)
			
			// ______________________________________________________
		: (Value type:C1509($configuration)=Is text:K8:3)  // Preconfigured
			
			// TODO: Provide preconfigured providers
			
			// ______________________________________________________
		: (Value type:C1509($configuration)=Is object:K8:27)  // {apiKey: "your api key"; baseURL: "https://server.ai"}
			
			ASSERT:C1129($configuration.baseURL#Null:C1517)
			
			This:C1470.name:=$configuration.name || This:C1470.normalizedName($configuration.baseURL)
			
			If ($configuration.apiKey=Null:C1517)
				
				$configuration.apiKey:=This:C1470.apiKey
				
			End if 
			
			This:C1470.endpoint:=cs:C1710.AIKit.OpenAI.new(This:C1470.apiKey)
			
			// ______________________________________________________
	End case 
	
	// This.name:=$provider || "openAI"
	// If (This.name="openAI")
	// This.endpoint:=cs.AIKit.OpenAI.new(This.apiKey)
	// End if
	
	If (This:C1470.endpoint.apiKey#Null:C1517)
		
		var $models:=This:C1470.endpoint.models.list()
		
		This:C1470.success:=$models.success
		
		If (This:C1470.success)
			
			This:C1470.models:=$models.models
			
		End if 
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function normalizedName($url : Text) : Text
	
	If ($url="https://api.openai.com/@")
		
		return "openAI"
		
	End if 
	
	var $name:=Replace string:C233($url; "https://"; "")
	$name:=Replace string:C233($name; "http://"; "")
	$name:=Replace string:C233($name; "api."; "")
	$name:=Replace string:C233($name; ".com"; "")
	$name:=Replace string:C233($name; "."; "_")
	
	return $name
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function get apiKey() : Text
	
	If (This:C1470.endpoint#Null:C1517)
		
		return This:C1470.endpoint.apiKey
		
	End if 
	
	// First search in the environment variables
	var $apikey:=String:C10(cs:C1710.Env.me[Uppercase:C13(This:C1470.name)+"_API_KEY"])
	
	If (Length:C16($apikey)>0)
		
		return $apiKey
		
	End if 
	
	// Search in user preferences folder
	var $file : 4D:C1709.File:=Folder:C1567(fk user preferences folder:K87:10).file(This:C1470.name+".json")
	
	If ($file.exists)
		
		Try
			
			$apikey:=String:C10(JSON Parse:C1218($file.getText()).apiKey)
			return $apikey
			
		Catch
			
			// ERROR
			
		End try
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function set apiKey($apikey : Text)
	
	If (This:C1470.endpoint#Null:C1517)
		
		This:C1470.endpoint.apiKey:=$apikey
		
		var $models:=This:C1470.endpoint.models.list()
		
		This:C1470.success:=$models.success
		
		If (This:C1470.success)
			
			This:C1470.models:=$models.models
			
		End if 
	End if 
	
	
	
	
	
	