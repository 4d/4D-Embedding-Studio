/**
 Private helper for Process.
 Turns the polymorphic $definition parameter (Null | single | collection | vectorName-only stub)
 into a concrete Collection of cs.Definition, using the provided Settings
 and optionally an entity/entitySelection to infer dataclassName.
**/

property settings : cs:C1710.Settings

Class constructor($settings : cs:C1710.Settings)
	
	This:C1470.settings:=$settings
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Resolution for the dataclass-wide process($definition) entry point.
	// No entity context available.
Function resolveForProcess($definition : Variant) : Collection
	
	Case of 
			
			// ______________________________________________________
		: ($definition=Null:C1517)
			
			return This:C1470.settings.definitions.copy()
			
			// ______________________________________________________
		: (Value type:C1509($definition)=Is collection:K8:32)

			// Flat-map each item: an item may itself expand to several definitions
			// (e.g. a DataClass), so we cannot just copy the collection as-is.
			return This:C1470._resolveMany($definition)

			// ______________________________________________________
		: (Value type:C1509($definition)=Is object:K8:27)

			return This:C1470._resolveOneForProcess($definition)

			// ______________________________________________________
		Else
			
			return []
			
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Resolution for processEntity*() entry points.
	// $contextDataclassName is the dataclass inferred from the entity/selection.
Function resolveForEntity($definition : Variant; $contextDataclassName : Text) : Collection
	
	Case of 
			
			// ______________________________________________________
		: ($definition=Null:C1517)
			
			// All definitions matching the entity's dataclass
			return This:C1470.settings.definitions.query("dataclassName = :1"; $contextDataclassName)
			
			// ______________________________________________________
		: (Value type:C1509($definition)=Is collection:K8:32)
			
			var $out : Collection:=[]
			var $item : Variant
			For each ($item; $definition)
				
				var $resolved : cs:C1710.Definition:=This:C1470._resolveOne($item; $contextDataclassName)
				If ($resolved#Null:C1517)
					
					$out.push($resolved)
					
				End if 
				
			End for each 
			return $out
			
			// ______________________________________________________
		: (Value type:C1509($definition)=Is object:K8:27)
			
			var $single : cs:C1710.Definition:=This:C1470._resolveOne($definition; $contextDataclassName)
			return ($single=Null:C1517) ? [] : [$single]
			
			// ______________________________________________________
		Else 
			
			return []
			
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Infer dataclass name from a single entity.
Function dataclassNameFromEntity($entity : 4D:C1709.Entity) : Text
	
	If ($entity=Null:C1517)
		
		return ""
		
	End if 
	
	return $entity.getDataClass().getInfo().name
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Infer dataclass name from an entity selection.
Function dataclassNameFromSelection($es : 4D:C1709.EntitySelection) : Text
	
	If ($es=Null:C1517)
		
		return ""
		
	End if 
	
	return $es.getDataClass().getInfo().name
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Flat-maps _resolveOneForProcess over a collection of polymorphic items.
	// Each item may expand to zero, one or several definitions.
Function _resolveMany($items : Collection) : Collection

	var $out : Collection:=[]
	var $item : Variant
	For each ($item; $items)

		$out.combine(This:C1470._resolveOneForProcess($item))

	End for each
	return $out

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Resolves a single polymorphic item (no entity context) into a Collection of Definition.
	// - cs.Definition instance  → itself.
	// - 4D.DataClass            → every saved definition for that dataclass.
	// - plain object stub        → matching saved definition, or a new one built from its fields.
	// - anything else            → empty.
Function _resolveOneForProcess($item : Variant) : Collection

	If (Value type:C1509($item)#Is object:K8:27)

		return []

	End if

	If (OB Instance of:C1731($item; cs:C1710.Definition))

		return [$item]

	End if

	If (OB Instance of:C1731($item; 4D:C1709.DataClass))

		return This:C1470.settings.findAll($item.getInfo().name)

	End if

	var $found : cs:C1710.Definition:=This:C1470.settings.find(String:C10($item.dataclassName); String:C10($item.vectorName))

	If ($found#Null:C1517)

		return [$found]

	End if

	return [cs:C1710.Definition.new(\
		String:C10($item.dataclassName); \
		String:C10($item.vectorName); \
		String:C10($item.modelAlias); \
		($item.phrase=Null:C1517) ? "" : String:C10($item.phrase.template))]

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Normalizes a single definition argument against an entity dataclass context.
	// - Fully-specified definition (dataclassName+vectorName): returned as-is if dataclass matches.
	// - Stub with only vectorName: looked up in settings against the context dataclass.
	// - Mismatched dataclass: returns Null (caller records the error).
Function _resolveOne($candidate : Object; $contextDataclassName : Text) : cs:C1710.Definition
	
	If ($candidate=Null:C1517)
		
		return Null:C1517
		
	End if 
	
	var $dcName : Text:=String:C10($candidate.dataclassName)
	var $vecName : Text:=String:C10($candidate.vectorName)
	
	If (Length:C16($vecName)=0)
		
		return Null:C1517
		
	End if 
	
	// vectorName-only stub → look up in settings against the context dataclass
	If (Length:C16($dcName)=0)
		
		If (Length:C16($contextDataclassName)=0)
			
			return Null:C1517
			
		End if 
		
		return This:C1470.settings.find($contextDataclassName; $vecName)
		
	End if 
	
	// Explicit dataclassName must match the entity's dataclass (if we have context)
	If ((Length:C16($contextDataclassName)>0) && ($dcName#$contextDataclassName))
		
		return Null:C1517
		
	End if 
	
	// If it's already a full Definition, pass through
	If (OB Instance of:C1731($candidate; cs:C1710.Definition))
		
		return $candidate
		
	End if 
	
	// Otherwise look it up in settings (caller passed a plain object)
	return This:C1470.settings.find($dcName; $vecName)
	