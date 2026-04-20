property _cache : Object  // { "<dataclassName>": Collection of supported attributes }
property _fieldNameCache : Object  // { "<dataclassName>": { "<fieldName>": True } }

singleton Class constructor

	This:C1470._cache:={}
	This:C1470._fieldNameCache:={}

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the collection of "supported" attributes for the given dataclass.
	// Result is cached, keyed by dataclass name, so multiple Vectors on the same
	// dataclass share a single computation.
Function forDataclass($dataclass : 4D:C1709.DataClass) : Collection

/* #17306
In the embedding phrase, the supported attributes shall be:
  • Simple fields
  • Computed attributes
  • Related fields (1:1, N:1 relationship)
  • Aliases
*/

	var $table:=$dataclass.getInfo()
	var $key : Text:=$table.name

	If (This:C1470._cache[$key]#Null:C1517)

		return This:C1470._cache[$key]

	End if

	var $supported:=[]

	var $attrKey : Text
	For each ($attrKey; $dataclass)

		var $attribute : Object:=$dataclass[$attrKey]

		// TODO: Ignore 1:N relationships ?

		If (String:C10($attribute.classID)="4D.Vector")

			continue

		End if

		// TODO: Ignore start/end of a relation ?
		If ($attribute.fieldNumber#Null:C1517)

			var $oneTable; $oneField : Integer
			GET RELATION PROPERTIES:C686($table.tableNumber; $attribute.fieldNumber; $oneTable; $oneField)

			If ($oneField#0)

				continue

			End if
		End if

		$supported.push($attribute)

	End for each

	This:C1470._cache[$key]:=$supported

	return $supported

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
