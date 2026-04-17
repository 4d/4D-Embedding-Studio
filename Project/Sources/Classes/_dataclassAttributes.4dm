property _cache : Object  // { "<dataclassName>": Collection of supported attributes }

singleton Class constructor

	This:C1470._cache:={}

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
	// Invalidate the cache. Call with no argument to clear everything,
	// or with a dataclass name to drop a single entry.
Function reset($dataclassName : Text)

	If (Count parameters:C259>=1)

		OB REMOVE:C1226(This:C1470._cache; $dataclassName)

	Else

		This:C1470._cache:={}

	End if
