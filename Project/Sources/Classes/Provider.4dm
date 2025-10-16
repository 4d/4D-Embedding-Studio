property name : Text
property baseURL : Text
property token_env_key : Text
property success : Boolean
property endpoint : cs:C1710.AIKit.OpenAI
property models : Collection

Class constructor($config)
	
	Case of 
			
			// ______________________________________________________
		: ($config=Null:C1517)  // Default to openAI
			
			This:C1470.name:="openAI"
			This:C1470.endpoint:=cs:C1710.AIKit.OpenAI.new(This:C1470.apiKey)
			
			// ______________________________________________________
		: (Value type:C1509($config)=Is object:K8:27)  // {apiKey: "your api key"; baseURL: "https://server.ai"}
			
			This:C1470.baseURL:=$config.baseURL || $config.base_url
			ASSERT:C1129(This:C1470.baseURL#Null:C1517)
			
			This:C1470.name:=$config.name || This:C1470.normalizedName(This:C1470.baseURL)
			
			If (Length:C16(String:C10($config.token_env_key))>0)
				
				This:C1470.token_env_key:=$config.token_env_key
				This:C1470.endpoint:=cs:C1710.AIKit.OpenAI.new({baseURL: This:C1470.baseURL; apiKey: This:C1470.apiKey})
				
			Else 
				
				This:C1470.endpoint:=cs:C1710.AIKit.OpenAI.new({baseURL: This:C1470.baseURL})
				
			End if 
			
			// ______________________________________________________
	End case 
	
	This:C1470._getModels()
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _getModels()
	
	//If (This.endpoint.apiKey#Null)
	
	var $models:=This:C1470.endpoint.models.list()
	
	This:C1470.success:=$models.success
	
	If (This:C1470.success)
		
		This:C1470.models:=$models.models
		
	End if 
	//End if 
	
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
	
	var $tokenEnvKey : Text:=This:C1470.token_env_key || (Uppercase:C13(This:C1470.name)+"_API_KEY")
	
	// First search in the environment variables
	var $apikey:=String:C10(cs:C1710.Env.me[$tokenEnvKey])
	
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