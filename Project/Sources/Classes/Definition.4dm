property dataclassName : Text
property vectorName : Text
property modelAlias : Text
property phrase : cs:C1710.Phrase
property autoInvalidate : Boolean:=True:C214

Class constructor($dataclassName : Text; $vectorName : Text; $modelAlias : Text; $phraseTemplate : Text)
	
	This:C1470.dataclassName:=$dataclassName
	This:C1470.vectorName:=$vectorName
	This:C1470.modelAlias:=$modelAlias
	This:C1470.phrase:=cs:C1710.Phrase.new($phraseTemplate || "")
	This:C1470.autoInvalidate:=True:C214
	
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns true if model or phrase defined.
Function get hasDefinition : Boolean
	return (Length:C16(String:C10(This:C1470.modelAlias))>0) || (Length:C16(String:C10(This:C1470.phrase.template))>0)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Validates the definition against the live ds model and known models from settings.
	// Returns {success: Boolean, errors: Collection of {field, message}}
	// $settings may be Null — phrase validation will run without options.
Function validate($settings : cs:C1710.Settings) : Object
	
	var $errors:=[]
	
	// Fundamental identity — nothing else can be meaningfully checked without these
	If (Length:C16(String:C10(This:C1470.dataclassName))=0)
		return {success: False:C215; errors: [{field: "dataclassName"; message: Localized string:C991("errMissingDataclassName")}]}
	End if 
	
	If (Length:C16(String:C10(This:C1470.vectorName))=0)
		return {success: False:C215; errors: [{field: "vectorName"; message: Localized string:C991("errMissingVectorName")}]}
	End if 
	
	// Model (independent from dataclass)
	Case of 
			
		: (Length:C16(String:C10(This:C1470.modelAlias))=0)
			
			$errors.push({field: "modelAlias"; message: Localized string:C991("errNoModelConfigured")})
			
		: (Not:C34(cs:C1710._AIKit.me.isAvailable))  // The aliases cannot be listed without 4D AIKit
			
			$errors.push({field: "modelAlias"; message: cs:C1710._AIKit.me.missingReason})
			
		: (Not:C34(cs:C1710._AIKit.me.modelNames().includes(This:C1470.modelAlias)))
			
			$errors.push({field: "modelAlias"; message: Replace string:C233(Localized string:C991("errModelNotDefined"); "{model}"; This:C1470.modelAlias)})
			
	End case 
	
	// Dataclass and vector field
	var $dc : 4D:C1709.DataClass:=ds:C1482[This:C1470.dataclassName]
	
	If ($dc=Null:C1517)
		
		$errors.push({field: "dataclassName"; message: Replace string:C233(Localized string:C991("errUnknownDataclass"); "{dataclass}"; This:C1470.dataclassName)})
		return {success: False:C215; errors: $errors}
		
	End if 
	
	var $attr : Object:=$dc[This:C1470.vectorName]
	
	Case of 
		: ($attr=Null:C1517)
			
			$errors.push({field: "vectorName"; message: Replace string:C233(Localized string:C991("errVectorFieldNotFound"); "{attribute}"; This:C1470.vectorName)})
			
		: (String:C10($attr.classID)#"4D.Vector")
			
			$errors.push({field: "vectorName"; message: Replace string:C233(Localized string:C991("errTargetNotVector"); "{attribute}"; This:C1470.vectorName)})
			
	End case 
	
	// Phrase
	If ((This:C1470.phrase=Null:C1517) || (Length:C16(This:C1470.phrase.template)=0))
		
		$errors.push({field: "phrase"; message: Localized string:C991("errMissingPhrase")})
		
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
	// Nullifies the vector field (and sets the companion _dirty flag when present) for every
	// entity in the definition's dataclass, forcing a full re-embedding on the next run.
	// Returns {updated: Integer; skipped: Integer; errors: Collection of Text}
Function invalidateVectors() : Object
	
	var $dc : 4D:C1709.DataClass:=ds:C1482[This:C1470.dataclassName]
	
	If ($dc=Null:C1517)
		return {updated: 0; skipped: 0; errors: ["Unknown dataclass: "+This:C1470.dataclassName]}
	End if 
	
	var $dirtyName : Text:=This:C1470.vectorName+"_dirty"
	var $hasDirty : Boolean:=($dc[$dirtyName]#Null:C1517)
	
	var $updated : Integer:=0
	var $skipped : Integer:=0
	var $errors : Collection:=[]
	
	// attribute paths as placeholders: a field name may contain a space or a "." that the
	// query parser would otherwise read as part of the expression
	var $pending : 4D:C1709.EntitySelection:=($hasDirty)\
		 ? $dc.query(":1 != null & :2 = false"; This:C1470.vectorName; $dirtyName)\
		 : $dc.query(":1 != null"; This:C1470.vectorName)
	
	var $entity : cs:C1710.Entity
	For each ($entity; $pending)
		If ($hasDirty)
			$entity[$dirtyName]:=True:C214
		Else 
			$entity[This:C1470.vectorName]:=Null:C1517
		End if 
		
		var $status : Object:=$entity.save()
		
		If ($status.success)
			$updated+=1
		Else 
			$skipped+=1
			$errors.push(This:C1470.dataclassName+": "+String:C10($status.statusText))
		End if 
		
	End for each 
	
	return {updated: $updated; skipped: $skipped; errors: $errors}
	
Function _hasVectorComputed() : Boolean
	
	var $dc : 4D:C1709.DataClass:=ds:C1482[This:C1470.dataclassName]
	
	If ($dc=Null:C1517)
		return False:C215
	End if 
	
	var $dirtyName : Text:=This:C1470.vectorName+"_dirty"
	var $hasDirty : Boolean:=($dc[$dirtyName]#Null:C1517)
	
	var $s : 4D:C1709.EntitySelection:=($hasDirty)\
		 ? $dc.query(":1 != null & :2 = false"; This:C1470.vectorName; $dirtyName)\
		 : $dc.query(":1 != null"; This:C1470.vectorName)
	
	return $s.length>0  // is it optimized? I need not(isEmpty)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns a plain object suitable for JSON persistence.
	// The phrase is flattened to its template text.
Function toObject() : Object
	
	return {\
		dataclassName: This:C1470.dataclassName; \
		vectorName: This:C1470.vectorName; \
		modelAlias: This:C1470.modelAlias; \
		phrase: This:C1470.phrase.template; \
		autoInvalidate: Bool:C1537(This:C1470.autoInvalidate)\
		}
	