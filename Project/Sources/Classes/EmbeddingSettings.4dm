property file : 4D:C1709.File
property vectors : Collection  // of cs:C1710.EmbeddingDefinition

Class constructor($file : 4D:C1709.File)

	This:C1470[""]:={raw: {}}
	This:C1470.file:=$file || Folder:C1567(fk database folder:K87:14; *).file("Settings/vectors.json")
	This:C1470.vectors:=[]

	This:C1470.load()

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Reads the settings file, if any, and populates This.vectors with EmbeddingDefinition objects.
	// Any unknown top-level keys (e.g. "models") are preserved internally and restored on save.
Function load()

	This:C1470.vectors:=[]
	This:C1470[""].raw:={}

	If (Not:C34(This:C1470.file.exists))

		return

	End if

	var $raw : Variant:=Try(JSON Parse:C1218(This:C1470.file.getText()))

	If (Value type:C1509($raw)#Is object:K8:27)

		return

	End if

	This:C1470[""].raw:=$raw

	If ($raw.vectors=Null:C1517)

		return

	End if

	var $saved : Object
	For each ($saved; $raw.vectors)

		var $def : cs:C1710.EmbeddingDefinition:=cs:C1710.EmbeddingDefinition.new(\
			String:C10($saved.dataclassName); \
			String:C10($saved.vectorName); \
			String:C10($saved.model); \
			String:C10($saved.phrase))
		$def.version:=$saved.version#Null:C1517 ? Num:C11($saved.version) : $def.version

		This:C1470.vectors.push($def)

	End for each

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Serializes This.vectors back to the settings file, preserving any other top-level keys.
Function save()

	var $out : Object:=This:C1470[""].raw || {}
	$out.vectors:=[]

	var $def : cs:C1710.EmbeddingDefinition
	For each ($def; This:C1470.vectors)

		$out.vectors.push($def.toObject())

	End for each

	This:C1470[""].raw:=$out
	This:C1470.file.setText(JSON Stringify:C1217($out; *))

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the saved EmbeddingDefinition for the given dataclass/vector, or Null.
Function find($dataclassName : Text; $vectorName : Text) : cs:C1710.EmbeddingDefinition

	return This:C1470.vectors.query("dataclassName = :1 & vectorName = :2"; $dataclassName; $vectorName).first()

