property dataclassName : Text
property vectorName : Text
property model : Text
property phrase : cs:C1710.Phrase

Class constructor($dataclassName : Text; $vectorName : Text; $model : Text; $phraseTemplate : Text)
	
	This:C1470.dataclassName:=$dataclassName
	This:C1470.vectorName:=$vectorName
	This:C1470.model:=$model
	This:C1470.phrase:=cs:C1710.Phrase.new($phraseTemplate || "")
	
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns true if model or phrase defined.
Function get hasDefinition : Boolean
	return (Length:C16(String:C10(This:C1470.model))>0) || (Length:C16(String:C10(This:C1470.phrase.template))>0)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Validates the definition against the live ds model and known models from settings.
	// Returns {success: Boolean, errors: Collection of {field, message}}
	// $settings may be Null — phrase validation will run without options.
Function validate($settings : cs:C1710.EmbeddingSettings) : Object
	
	var $errors:=[]
	
	// Fundamental identity — nothing else can be meaningfully checked without these
	If (Length:C16(String:C10(This:C1470.dataclassName))=0)
		return {success: False:C215; errors: [{field: "dataclassName"; message: "Missing dataclassName"}]}
	End if 
	
	If (Length:C16(String:C10(This:C1470.vectorName))=0)
		return {success: False:C215; errors: [{field: "vectorName"; message: "Missing vectorName"}]}
	End if 
	
	// Model (independent from dataclass)
	If (Length:C16(String:C10(This:C1470.model))=0)
		
		$errors.push({field: "model"; message: "No model configured for definition"})
		
	Else 
		
		var $found:=False:C215
		var $models:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
		var $m : Object
		For each ($m; $models)
			If ($m.name=This:C1470.model)
				$found:=True:C214
			End if 
		End for each 
		
		If (Not:C34($found))
			$errors.push({field: "model"; message: "Model '"+This:C1470.model+"' is not defined"})
		End if 
		
	End if 
	
	// Dataclass and vector field
	var $dc : 4D:C1709.DataClass:=ds:C1482[This:C1470.dataclassName]
	
	If ($dc=Null:C1517)
		
		$errors.push({field: "dataclassName"; message: "Unknown dataclass: "+This:C1470.dataclassName})
		return {success: False:C215; errors: $errors}
		
	End if 
	
	var $attr : Object:=$dc[This:C1470.vectorName]
	
	Case of 
		: ($attr=Null:C1517)
			
			$errors.push({field: "vectorName"; message: "Vector field not found: "+This:C1470.vectorName})
			
		: (String:C10($attr.classID)#"4D.Vector")
			
			$errors.push({field: "vectorName"; message: "Target field is not a 4D.Vector: "+This:C1470.vectorName})
			
	End case 
	
	// Phrase
	If ((This:C1470.phrase=Null:C1517) || (Length:C16(This:C1470.phrase.template)=0))
		
		$errors.push({field: "phrase"; message: "Missing phrase"})
		
	Else 
		
		var $phraseOptions : Object:=($settings#Null:C1517) ? $settings.phrase : Null:C1517
		var $phraseValidation : Object:=This:C1470.phrase.validate($dc; $phraseOptions)
		
		If (Not:C34($phraseValidation.success))
			
			var $phraseErr : Object
			For each ($phraseErr; $phraseValidation.errors)
				$errors.push({field: "phrase"; message: $phraseErr.message})
			End for each 
			
		End if 
		
	End if 
	
	return {success: ($errors.length=0); errors: $errors}
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns a plain object suitable for JSON persistence.
	// The phrase is flattened to its template text.
Function toObject() : Object
	
	return {\
		dataclassName: This:C1470.dataclassName; \
		vectorName: This:C1470.vectorName; \
		model: This:C1470.model; \
		phrase: This:C1470.phrase.template\
		}
	