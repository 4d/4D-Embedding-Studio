property version : Integer:=-1  // -1 for a never-defined vector
property dataclassName : Text
property vectorName : Text
property model:=""  // Define a default model if any
property phrase : cs:C1710.Phrase

Class constructor($dataclassName : Text; $vectorName : Text; $model : Text; $phraseTemplate : Text)

	This:C1470.dataclassName:=$dataclassName
	This:C1470.vectorName:=$vectorName
	This:C1470.model:=$model || This:C1470.model
	This:C1470.phrase:=cs:C1710.Phrase.new($phraseTemplate || "")

	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns a plain object suitable for JSON persistence.
	// The phrase is flattened to its template text.
Function toObject() : Object

	return {\
		version: This:C1470.version; \
		dataclassName: This:C1470.dataclassName; \
		vectorName: This:C1470.vectorName; \
		model: This:C1470.model; \
		phrase: This:C1470.phrase.template\
		}
