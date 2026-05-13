/**
 Simple template engine for embedding phrases.
 Compiles a template with {variable} placeholders once,
 then renders it efficiently with different data objects.
 Supports dot-notation for related attributes: {relation.field}
 
 Usage:
   var $tpl:=cs.embed.Phrase.new("Hello {firstName}, you study at {school.name}.")
   $tpl.render($entity)  // "Hello Alice, you study at MIT."
   $tpl.keys             // ["firstName", "school.name"]
**/

property _template : Text
property _parts : Collection:=[]  // Static text segments between variables
property _keyPaths : Collection:=[]  // Text for simple keys, Collection for dot-notation (e.g. "a.b.c" → ["a", "b", "c"])

// MARK:-[CONSTRUCTOR]
Class constructor($template : Text)
	
	This:C1470._template:=$template
	
	This:C1470._compile()
	
	// MARK:-[PROPERTIES]
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns the original template string.
Function get template() : Text
	
	return This:C1470._template
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns a copy of the variable names found in the template.
Function get keys() : Collection
	
	return This:C1470._keyPaths.map(Formula:C1597((Value type:C1509($1.value)=Is text:K8:3) ? String:C10($1.value) : $1.value.join(".")))
	
	// MARK:-[PUBLIC]
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Renders the compiled template by replacing variables with values from $data.
	// Missing keys produce an empty string.
Function render($data : Object) : Text
	
	var $result : Text
	var $i : Integer
	
	For ($i; 0; This:C1470._keyPaths.length-1)
		
		$result+=(This:C1470._parts[$i] || "")
		
		var $path : Variant:=This:C1470._keyPaths[$i]
		
		// Fast path for simple keys, deep resolve for dot-notation
		var $value : Variant:=(Value type:C1509($path)=Is text:K8:3) ? $data[$path] : This:C1470._resolve($path; $data)
		
		If ($value#Null:C1517)
			If ((Value type:C1509($value)=Is object:K8:27) || (Value type:C1509($value)=Is collection:K8:32))
				$result+=JSON Stringify:C1217($value)
			Else 
				$result+=String:C10($value)
			End if 
		End if 
		
	End for 
	
	// Append the trailing static text after the last variable
	$result+=(This:C1470._parts[This:C1470._keyPaths.length] || "")
	
	return $result
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Validates that all keys in the phrase can be resolved against a DataClass.
	// Walks dot-notation paths through relations (N:1 / 1:1).
	// Returns {success: Boolean, errors: Collection of {key, message}}
	//
	// $options (all default to False — storage kind only):
	//   .allowRelations  : Boolean — allow dot-notation paths through N:1 relations
	//   .allowCalculated : Boolean — allow calculated attributes
	//   .allowAlias      : Boolean — allow alias attributes
Function validate($dataclass : 4D:C1709.DataClass; $options : Object) : Object
	
	var $errors:=[]
	var $dcName : Text:=$dataclass.getInfo().name
	
	// Options with defaults (all False when omitted → storage kind only)
	var $allowRelations:=False:C215
	var $allowCalculated:=False:C215
	var $allowAlias:=False:C215
	var $allowObject:=False:C215
	
	If ($options#Null:C1517)
		
		$allowRelations:=$options.allowRelations
		$allowCalculated:=$options.allowCalculated
		$allowAlias:=$options.allowAlias
		$allowObject:=$options.allowObject
		
	End if 
	
	If (This:C1470._keyPaths.length=0) && (Length:C16(This:C1470._template)>0)
		$errors.push({key: ""; message: This:C1470._localizedErrorMessage("phraseHasNoKeyField"; ""; "")})
		return {success: False:C215; errors: $errors}
	End if 
	
	var $kp : Variant
	For each ($kp; This:C1470._keyPaths)
		
		var $segments : Collection:=(Value type:C1509($kp)=Is text:K8:3) ? [$kp] : $kp
		
		// Reject dot-notation paths when relations are not allowed
		If ($segments.length>1) && (Not:C34($allowRelations))
			
			$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("relationsAreNotAllowed"; $segments.join("."))})
			continue
			
		End if 
		
		var $current:=$dataclass
		var $valid : Boolean:=True:C214
		
		var $j : Integer
		For ($j; 0; $segments.length-1)
			
			var $segment : Text:=$segments[$j]
			var $attribute : Object:=$current[$segment]
			
			If ($attribute=Null:C1517)
				
				$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("theAttributeDoesn'tExistsInTheDataclass"; $segment; $dcName)})
				$valid:=False:C215
				
				break
				
			End if 
			
			If (String:C10($attribute.classID)="4D.Vector")
				
				$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("theAttributeIsAVector"; $segment)})
				$valid:=False:C215
				
				break
				
			End if 
			
			If ($j<($segments.length-1))
				
				// Intermediate segment: must be a N:1 or 1:1 relation
				If ($attribute.kind="relatedEntity")
					
					$current:=ds:C1482[$attribute.relatedDataClass]
					
				Else 
					
					$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("theAttributeIsNotARelation"; $segment)})
					$valid:=False:C215
					
					break
					
				End if 
				
			Else 
				
				// Last segment: check kind restrictions
				Case of 
					: ($attribute.kind="relatedEntities")
						
						$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("theAttributeIsA1NRelation"; $segment)})
						
					: (($attribute.kind="relatedEntity") && (Not:C34($allowRelations)))
						
						$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("relationsAreNotAllowed"; $segment)})
						
					: (($attribute.kind="calculated") && (Not:C34($allowCalculated)))
						
						$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("calculatedAttributeIsNotAllowed"; $segment)})
						
					: (($attribute.kind="alias") && (Not:C34($allowAlias)))
						
						$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("aliasAttributeIsNotAllowed"; $segment)})
						
					: (cs:C1710._dataclassAttributes.me.isExcludedStorageType($attribute; $allowObject))
						
						$errors.push({key: $segments.join("."); message: This:C1470._localizedErrorMessage("theAttributeTypeIsNotSupportedInAPhrase"; $segment)})
						
				End case 
				
			End if 
			
		End for 
		
	End for each 
	
	return {success: ($errors.length=0); errors: $errors}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function attributes($dataclass : 4D:C1709.DataClass) : Collection
	
	var $attributes : Collection:=[]
	
	var $kp : Variant
	For each ($kp; This:C1470._keyPaths)
		
		var $segments : Collection:=(Value type:C1509($kp)=Is text:K8:3) ? [$kp] : $kp
		
		var $current : 4D:C1709.DataClass:=$dataclass
		var $attribute : Object:=Null:C1517
		var $valid : Boolean:=True:C214
		
		var $j : Integer
		For ($j; 0; $segments.length-1)
			
			$attribute:=$current[$segments[$j]]
			
			If ($attribute=Null:C1517)
				$valid:=False:C215
				break
			End if 
			
			If ($j<($segments.length-1))
				If ($attribute.kind="relatedEntity")
					$current:=ds:C1482[$attribute.relatedDataClass]
					If ($current=Null:C1517)
						$valid:=False:C215
						break
					End if 
				Else 
					$valid:=False:C215
					break
				End if 
			End if 
			
		End for 
		
		If ($valid)
			$attributes.push($attribute)
		Else 
			$attributes.push(Null:C1517)
		End if 
		
	End for each 
	
	return $attributes
	
	// MARK:-[PRIVATE]
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Compiles the template by extracting {variable} tokens via regex.
	// Splits the template into interleaved _parts (static text) and _keyPaths (variable names).
Function _compile()
	
	var $pattern : Text:="\\{([^}]*)\\}"
	var $cursor : Integer:=1
	
	ARRAY LONGINT:C221($pos; 0)
	ARRAY LONGINT:C221($len; 0)
	
	While (Match regex:C1019($pattern; This:C1470._template; $cursor; $pos; $len))
		
		// Static text before this match
		If ($pos{0}>$cursor)
			
			This:C1470._parts.push(Substring:C12(This:C1470._template; $cursor; $pos{0}-$cursor))
			
		Else 
			
			This:C1470._parts.push("")
			
		End if 
		
		// Captured variable name (group 1), trimmed
		var $key : Text:=Substring:C12(This:C1470._template; $pos{1}; $len{1})
		
		var $trimmed : Text:=Trim:C1853($key)
		
		// Simple key → store as Text; dot-notation → store as Collection
		If (Position:C15("."; $trimmed)>0)
			
			This:C1470._keyPaths.push(Split string:C1554($trimmed; "."))
			
		Else 
			
			This:C1470._keyPaths.push($trimmed)
			
		End if 
		
		// Advance cursor past the match
		$cursor:=$pos{0}+$len{0}
		
	End while 
	
	// Trailing static text after the last match
	If ($cursor<=Length:C16(This:C1470._template))
		
		This:C1470._parts.push(Substring:C12(This:C1470._template; $cursor))
		
	Else 
		
		This:C1470._parts.push("")
		
	End if 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Resolves a dot-notation path against a data object.
	// e.g. ["a", "b", "c"] against {a: {b: {c: "value"}}} → "value"
Function _resolve($path : Collection; $data : Object) : Variant
	
	var $current : Variant:=$data
	var $segment : Text
	
	For each ($segment; $path)
		
		If ($current=Null:C1517)
			
			return Null:C1517
			
		End if 
		
		If (Value type:C1509($current)#Is object:K8:27)
			
			return Null:C1517  // maybe throw?
			
		End if 
		
		
		$current:=$current[$segment]
		
	End for each 
	
	return $current
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Returns a localized error message with {attribute} and {dataclass} placeholders replaced.
Function _localizedErrorMessage($resname : Text; $attribute : Text; $dataclass : Text) : Text
	
	var $message : Text:=Localized string:C991($resname)
	$message:=Replace string:C233($message; "{attribute}"; $attribute)
	$message:=Replace string:C233($message; "{dataclass}"; $dataclass)
	
	return $message