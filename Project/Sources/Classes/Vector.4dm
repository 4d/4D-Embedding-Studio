property version : Integer:=-1  // -1 for a never-defined vector
property dataclassName : Text
property dataclassNumber : Integer
property vectorName : Text
property vectorNumber : Integer
property model:=""  // Define a default model if any
property phrase:=""  // Define a default phrase if any

property _errors:=[]

Class constructor($dataclass : 4D:C1709.DataClass; $attribute : Object; $model : Text; $phrase : Text)
	
	If (Count parameters:C259<2)
		
		throw:C1805({componentSignature: "4DVS"; message: "Missing parameter"; deferred: True:C214})
		
		return 
		
	End if 
	
	var $o:=$dataclass.getInfo()
	
	This:C1470.dataclassName:=$o.name
	This:C1470.dataclassNumber:=$o.tableNumber
	This:C1470.vectorName:=$attribute.name
	This:C1470.vectorNumber:=$attribute.fieldNumber
	This:C1470.model:=$model || This:C1470.model
	This:C1470.phrase:=$phrase || This:C1470.phrase
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> 
Function set error($message : Text)
	
	This:C1470._errors:=This:C1470._errors || []
	This:C1470._errors.push($message)