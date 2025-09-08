property version : Integer:=-1  // -1 for a never-defined vector
property dataclassName : Text
property dataclassNumber : Integer
property vectorName : Text
property vectorNumber : Integer
property model:=""  // Define a default model if any
property phrase:=""  // Define a default phrase if any
property supportedAttributes:=[]
property embedded:=[]

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
	
	This:C1470.getSupportedAttributes($dataclass)
	
	This:C1470[""]:={\
		touched: False:C215; \
		errors: []}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function getSupportedAttributes($dataclass : 4D:C1709.DataClass)
	
/*
In the embedding phrase, the supported attributes shall be:
  • Simple fields
  • Computed attributes
  • Related fields (1:1, N:1 relationship)
  • Aliases
*/
	var $key : Text
	For each ($key; $dataclass)
		
		var $attribute : Object:=$dataclass[$key]
		
		If (String:C10($attribute.classID)="4D.Vector")
			
			continue
			
		End if 
		
		This:C1470.supportedAttributes.push($attribute)
		
	End for each 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function parsePhrase($phrase : Text) : Text
	
/*
In the embedding phrase, if the attribute is incorrect, 
4D shall display the attribute in red 
and show a tooltip with an error message when the developer hovers over it.
*/
	var $pattern:="(?i-ms)\\{([^\\}]*)\\}"
	var $rgx:=cs:C1710.regex.new($phrase; $pattern)
	var $inputs:=$rgx.extract(1)
	var $dataclass : 4D:C1709.DataClass:=ds:C1482[This:C1470.dataclassName]
	var $t : Text
	For each ($t; $inputs)
		
		If ($dataclass[$t]=Null:C1517)
			
			var $old:=$t
			ST SET ATTRIBUTES:C1093($t; ST Start text:K78:15; ST End text:K78:16; Attribute text color:K65:7; "red")
			$phrase:=Replace string:C233($phrase; "{"+$old+"}"; "{"+$t+"}")
			
		End if 
	End for each 
	
	return "<span>"+$phrase+"</span>"
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> 
Function set error($message : Text)
	
	This:C1470[""].errors.push($message)