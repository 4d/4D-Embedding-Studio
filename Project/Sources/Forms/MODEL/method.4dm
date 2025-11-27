var $e:=FORM Event:C1606

If ($e.objectName=Null:C1517)
	
	Case of 
			
			// ______________________________________________________
		: ($e.code=On Load:K2:1)
			
			SET TIMER:C645(-1)
			
			// ______________________________________________________
		: ($e.code=On Timer:K2:25)
			
			SET TIMER:C645(0)
			
			If (OBJECT Get subform container value:C1785#Null:C1517)  // Edition
				
				// The name cannot be changed at this stage
				OBJECT SET ENABLED:C1123(*; "name"; False:C215)
				OBJECT SET RGB COLORS:C628(*; "name"; -1; "transparent")
				
			End if 
			
			$provider:=Form:C1466._providers.query("baseURL = :1"; String:C10(Form:C1466.model.baseURL) || "https://api.openai.com/@").first()
			OBJECT SET FONT STYLE:C166(*; "apiKey.label"; $provider.needAPIKey ? Bold:K14:2 : Plain:K14:1)
			
			// ______________________________________________________
	End case 
	
	return 
	
End if 

var $model : Object:=Form:C1466.model

If ($e.code=On Data Change:K2:15)
	
	If (OBJECT Get subform container value:C1785#Null:C1517)
		
		// The name cannot be changed at this stage
		///* #17323
		//The model name shall be unique.
		//*/
		//If (Form.models.extract("name").includes($model.name))
		//Form._popError(\
			Replace string(Localized string("theModelNameMustBeUnique"); "{name}"; $model.name))
		//GOTO OBJECT(*; "name")
		//return 
		//End if 
		
/* #17322
For each model, the name, api Key and model are required.
*/
		
		// ⚠️ apiKey is not required if local
		$provider:=Form:C1466._providers.query("baseURL = :1"; String:C10(Form:C1466.model.baseURL) || "https://api.openai.com/@").first()
		
		SET TIMER:C645(-1)  // To update mandatory or not fields labels
		
		var $t : Text
		For each ($t; $provider.needAPIKey ? ["name"; "apiKey"; "model"] : ["name"; "model"])
			
			If (Length:C16(String:C10($model[$t]))=0)
				
				Form:C1466._popError(\
					Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991($t)))
				
				GOTO OBJECT:C206(*; $t)
				
				return 
				
			End if 
		End for each 
		
		CALL SUBFORM CONTAINER:C1086(-1)
		
	End if 
	
	Case of 
			
			//______________________________________________________
		: ($e.objectName="baseURL")
			
			var $provider:=cs:C1710.Provider.new($model.baseURL ? {baseURL: $model.baseURL} : Null:C1517)
			Form:C1466._provider:=$provider
			
			If (Form:C1466.providers[$provider.name]=Null:C1517)
				
				Form:C1466.providers[$provider.name]:=$provider
				
			End if 
			
			SET TIMER:C645(-1)  // To update mandtory or not fields labels
			
			//______________________________________________________
		: ($e.objectName="apiKey")
			
			If (Form:C1466._provider#Null:C1517)
				
				Form:C1466._provider.apiKey:=$model.apiKey
				
			End if 
			
			//______________________________________________________
	End case 
End if 

Case of 
		
		// ______________________________________________________
	: ($e.objectName="baseURLMenu")  // Menu of preconfigured providers
		
		GOTO OBJECT:C206(*; "baseURL")
		
		var $curbBase:=String:C10(Form:C1466.model.baseURL)
		var $menu:=cs:C1710.menu.new()
		
		For each ($provider; Form:C1466._providers)
			
			$menu.append($provider.name; $provider.baseURL).mark($curbBase=$provider.baseURL)
			
		End for each 
		
		If ($menu.popup($curbBase).selected)\
			 && ($menu.choice#$curbBase)
			
			// Set the model baseURL
			$provider:=Form:C1466._providers.query("baseURL = :1"; $menu.choice).first()
			Form:C1466.model.baseURL:=$menu.choice
			
			If ($provider.token_env_key#Null:C1517)
				
				Form:C1466.model.apiKey:=$provider.endpoint.apiKey
				
			End if 
			
			Form:C1466.saveModels()
			
			SET TIMER:C645(-1)  // To update mandatory or not fields labels
			
		End if 
		
		// ______________________________________________________
	: ($e.objectName="modelMenu")  // Menu of available models
		
		GOTO OBJECT:C206(*; "model")
		
		var $curModel:=String:C10($model.model)
		
		If (Length:C16(String:C10(Form:C1466.model.baseURL))=0)
			
			$provider:=Form:C1466._providers.query("name = :1"; "openAI").first()
			
		Else 
			
			$provider:=Form:C1466._providers.query("baseURL = :1"; Form:C1466.model.baseURL).first()
			
		End if 
		
		$menu:=$provider.menuModels($curModel)
		
		If ($menu=Null:C1517)
			
			return 
			
		End if 
		
		If ($menu.popup($curModel).selected)\
			 && ($menu.choice#$curModel)
			
			$model.model:=$menu.choice
			Form:C1466.saveModels()
			
		End if 
		
		// ______________________________________________________
	: ($e.objectName="done")  // New model
		
/* #17323
The model name shall be unique.
*/
		If (Form:C1466.models.extract("name").includes($model.name))
			
			Form:C1466._popError(\
				Replace string:C233(Localized string:C991("theModelNameMustBeUnique"); "{name}"; $model.name))
			
			GOTO OBJECT:C206(*; "name")
			
			return 
			
		End if 
		
/* #17322
For each model, the name, api Key (if not local) and model are required.
*/
		If (Length:C16(String:C10(Form:C1466.model.baseURL))=0)
			
			$provider:=Form:C1466._providers.query("name = :1"; "openAI").first()
			
		Else 
			
			$provider:=Form:C1466._providers.query("baseURL = :1"; Form:C1466.model.baseURL).first()
			
		End if 
		
		For each ($t; $provider.needAPIKey ? ["name"; "model"; "apiKey"] : ["name"; "model"])
			
			If (Length:C16(String:C10($model[$t]))=0)
				
				Form:C1466._popError(\
					Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991($t)))
				
				GOTO OBJECT:C206(*; $t)
				
				return 
				
			End if 
		End for each 
		
		ACCEPT:C269
		
		// ______________________________________________________
End case 

