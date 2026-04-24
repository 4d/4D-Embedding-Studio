property _cache : Object  // { "<dataclassName>": Collection of supported attributes }
property _fieldNameCache : Object  // { "<dataclassName>": { "<fieldName>": True } }

singleton Class constructor
	
	This:C1470._cache:={}
	This:C1470._fieldNameCache:={}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the collection of "supported" attributes for the given dataclass,
	// filtered by the optional phrase options (allowRelations, allowCalculated, allowAlias, allowObject).
	// The base list is cached per dataclass; options filtering is applied on top without caching.
Function forDataclass($dataclass : 4D:C1709.DataClass; $options : Object) : Collection
	
/* #17306
In the embedding phrase, the supported attributes shall be:
  • Simple fields
  • Computed attributes (when allowCalculated)
  • Related fields (N:1 / 1:1 relationship) (when allowRelations)
  • Aliases (when allowAlias)
*/
	
	var $table:=$dataclass.getInfo()
	var $key : Text:=$table.name
	
	If (This:C1470._cache[$key]=Null:C1517)
		
		var $base:=[]
		
		var $attrKey : Text
		For each ($attrKey; $dataclass)
			
			var $attribute : Object:=$dataclass[$attrKey]
			
			If (String:C10($attribute.classID)="4D.Vector")
				continue
			End if 
			
			If (This:C1470.isExcludedStorageType($attribute; True:C214))
				continue
			End if 
			
			// 1:N relations are never valid in a phrase
			If ($attribute.kind="relatedEntities")
				continue
			End if 
			
			// Skip N:1 FK source storage fields (the relatedEntity attribute is preferred)
			If ($attribute.fieldNumber#Null:C1517)
				
				var $oneTable; $oneField : Integer
				GET RELATION PROPERTIES:C686($table.tableNumber; $attribute.fieldNumber; $oneTable; $oneField)
				
				If ($oneField#0)
					continue
				End if 
			End if 
			
			$base.push($attribute)
			
		End for each 
		
		This:C1470._cache[$key]:=$base
		
	End if 
	
	$base:=This:C1470._cache[$key]
	
	// Apply phrase options filtering
	var $allowRelations : Boolean:=Bool:C1537($options#Null:C1517 ? $options.allowRelations : False:C215)
	var $allowCalculated : Boolean:=Bool:C1537($options#Null:C1517 ? $options.allowCalculated : False:C215)
	var $allowAlias : Boolean:=Bool:C1537($options#Null:C1517 ? $options.allowAlias : False:C215)
	var $allowObject : Boolean:=Bool:C1537($options#Null:C1517 ? $options.allowObject : False:C215)
	
	If ($allowRelations && $allowCalculated && $allowAlias && $allowObject)
		return $base
	End if 
	
	var $filtered:=[]
	var $attr : Object
	For each ($attr; $base)
		If (This:C1470.isExcludedStorageType($attr; $allowObject))
			continue
		End if 
		If ($attr.kind="relatedEntity") && (Not:C34($allowRelations))
			continue
		End if 
		If ($attr.kind="calculated") && (Not:C34($allowCalculated))
			continue
		End if 
		If ($attr.kind="alias") && (Not:C34($allowAlias))
			continue
		End if 
		$filtered.push($attr)
	End for each 
	
	return $filtered
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns True if the given field name exists on the dataclass.
	// Field name set is cached per dataclass so repeated lookups (typically
	// for "${vectorName}_dirty" probes during batch embedding runs) are O(1).
Function hasField($dataclass : 4D:C1709.DataClass; $fieldName : Text) : Boolean
	
	var $key : Text:=$dataclass.getInfo().name
	
	If (This:C1470._fieldNameCache[$key]=Null:C1517)
		
		var $names : Object:={}
		var $attrKey : Text
		
		For each ($attrKey; $dataclass)
			
			$names[$attrKey]:=True:C214
			
		End for each 
		
		This:C1470._fieldNameCache[$key]:=$names
		
	End if 
	
	return Bool:C1537(This:C1470._fieldNameCache[$key][$fieldName])
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns True when a storage attribute should be excluded from a phrase.
	// blob and image are always excluded; object is excluded unless $allowObject is True.
Function isExcludedStorageType($attribute : Object; $allowObject : Boolean) : Boolean
	
	If ($attribute.kind#"storage")
		return False:C215
	End if 
	return ($attribute.type="blob") || ($attribute.type="image")\
		 || (($attribute.type="object") && Not:C34($allowObject))
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Invalidate the cache. Call with no argument to clear everything,
	// or with a dataclass name to drop a single entry.
Function reset($dataclassName : Text)
	
	If (Count parameters:C259>=1)
		
		OB REMOVE:C1226(This:C1470._cache; $dataclassName)
		OB REMOVE:C1226(This:C1470._fieldNameCache; $dataclassName)
		
	Else 
		
		This:C1470._cache:={}
		This:C1470._fieldNameCache:={}
		
	End if 
	