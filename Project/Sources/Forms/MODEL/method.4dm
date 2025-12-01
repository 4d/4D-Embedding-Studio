var $e:=FORM Event:C1606

If ($e.code=On Bound Variable Change:K2:52)
	
	Form:C1466._snapshot:=OB Copy:C1225(Form:C1466.model)
	
	
End if 



If ($e.objectName=Null:C1517)  // Form method
	
	Case of 
			
			// ______________________________________________________
		: ($e.code=On Load:K2:1)
			
			// Keep a snapshot of the current model definition
			
			SET TIMER:C645(-1)
			
			// ______________________________________________________
		: ($e.code=On Timer:K2:25)
			
			SET TIMER:C645(0)
			
			Form:C1466._snapshot:=Form:C1466._snapshot || Form:C1466.model=Null:C1517 ? Null:C1517 : OB Copy:C1225(Form:C1466.model)
			
			
			// Mandatory or not fields labels style
			$provider:=Form:C1466._provider || cs:C1710.Provider.new(Form:C1466.model)
			OBJECT SET FONT STYLE:C166(*; "apiKey.label"; Form:C1466._provider.needAPIKey ? Bold:K14:2 : Plain:K14:1)
			
			// ______________________________________________________
		: ($e.code=On Bound Variable Change:K2:52)
			
			Form:C1466._snapshot:=OB Copy:C1225(Form:C1466.model)
			
			// ______________________________________________________
	End case 
	
	return 
	
End if 

var $model : Object:=Form:C1466.model

If ($e.code=On Data Change:K2:15)
	
	// attention, si c'est le nom qui est modifié cela peut mettre en péril les vecteurs qui sont associés
	
	
	If (OBJECT Get subform container value:C1785#Null:C1517)
		
/* #17322
For each model, the name, api Key and model are required.
*/
		
/* ⚠️
		
* The name cannot be changed at this stage
* apiKey is not required if local
		
*/
		$provider:=Form:C1466._providers.query("baseURL = :1"; String:C10(Form:C1466.model.baseURL) || "https://api.openai.com/@").first()
		
		SET TIMER:C645(-1)  // To update mandatory or not fields labels style
		
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
			
			
		: ($e.objectName="name")
			
			var $c : Collection:=Form:C1466.vectors.query("model = :1"; Form:C1466._snapshot.name)
			
			If ($c.length>0)
				
				
				
				
			End if 
			
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
		$provider:=Form:C1466._provider || cs:C1710.Provider.new(Form:C1466.model)
		
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

