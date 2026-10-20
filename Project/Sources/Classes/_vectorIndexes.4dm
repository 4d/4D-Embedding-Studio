property _fields : Object  // { "<table>\t<field>": True } for each field carrying a vector index
property _vectorTypes : Collection:=["20"; "21"; "22"]  // structure index types: cosine, dot, euclidean

singleton Class constructor

	This:C1470._fields:=Null:C1517

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when the attribute carries a vector index (cosine, dot or euclidean).
	// ORDA "indexed" only reports the automatic (object) index of a vector field, so the
	// structure definition is read instead, once, until the next refresh().
Function has($dataclass : 4D:C1709.DataClass; $attributeName : Text) : Boolean

	var $attr : Object:=$dataclass[$attributeName]

	If ($attr=Null:C1517)

		return False:C215

	End if

	If (This:C1470._fields=Null:C1517)

		This:C1470.refresh()

	End if

	var $tableNum : Integer:=$dataclass.getInfo().tableNumber

	return Bool:C1537(This:C1470._fields[Table name:C256($tableNum)+"\t"+Field name:C257($tableNum; $attr.fieldNumber)])

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Reads the vector indexes from the structure definition: call it again after a structure change.
Function refresh()

	This:C1470._fields:={}

	var $xml : Text
	EXPORT STRUCTURE:C1311($xml)

	var $root : Text:=String:C10(Try(DOM Parse XML variable:C720($xml)))

	If ((OK=0) || (Length:C16($root)=0))

		return

	End if

	var $type : Text
	For each ($type; This:C1470._vectorTypes)

		ARRAY TEXT:C222($refs; 0)
		Try(DOM Find XML element:C864($root; "/base/index[@type=\""+$type+"\"]/field_ref"; $refs))

		var $i : Integer
		For ($i; 1; Size of array:C274($refs))

			var $field; $table : Text
			DOM GET XML ATTRIBUTE BY NAME:C728($refs{$i}; "name"; $field)
			DOM GET XML ATTRIBUTE BY NAME:C728(DOM Find XML element:C864($refs{$i}; "table_ref"); "name"; $table)
			This:C1470._fields[$table+"\t"+$field]:=True:C214

		End for

	End for each

	DOM CLOSE XML:C722($root)

