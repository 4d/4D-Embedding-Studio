property version : Integer:=-1  // -1 for a never-defined vector
property dataclassName : Text
property dataclassNumber : Integer
property vectorName : Text
property vectorNumber : Integer
property model:=""  // Define a default model if any
property phrase:=""  // Define a default phrase if any
property supportedAttributes:=[]
property embedded:=[]

Class constructor($dataclass : Object; $attribute : Object; $model : Text; $phrase : Text)
	
	If (Count parameters:C259<2)
		
		If (Structure file:C489=Structure file:C489(*))
			
			ASSERT:C1129(False:C215; "Missing parameter")
			
		Else 
			
			throw:C1805({componentSignature: "4DVS"; message: "Missing parameter"; deferred: True:C214})
			
		End if 
		
		return 
		
	End if 
	
	If (OB Class:C1730($dataclass).superclass=4D:C1709.DataClass)
		
		var $o : Object:=$dataclass.getInfo()
		
		This:C1470.dataclassName:=$o.name
		This:C1470.dataclassNumber:=$o.tableNumber
		This:C1470.vectorName:=$attribute.name
		This:C1470.vectorNumber:=$attribute.fieldNumber
		This:C1470.model:=$model || This:C1470.model
		This:C1470.phrase:=$phrase || This:C1470.phrase
		
		This:C1470.getSupportedAttributes($dataclass)
		
	Else 
		
		// TODO: create with parameters
		
		//$class:=ds[$dataclass.name]  // Error if no longer exists
		
	End if 
	
	This:C1470[""]:={\
		touched: False:C215; \
		errors: []; \
		original: This:C1470.definition}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function getSupportedAttributes($dataclass : 4D:C1709.DataClass)
	
/* https://github.com/4d/4d/issues/17306
In the embedding phrase, the supported attributes shall be:
  • Simple fields
  • Computed attributes
  • Related fields (1:1, N:1 relationship)
  • Aliases
*/
	var $key : Text
	For each ($key; $dataclass)
		
		var $attribute : Object:=$dataclass[$key]
		
		// TODO: Ignore 1:N relationships 
		
		If (String:C10($attribute.classID)="4D.Vector")
			
			continue
			
		End if 
		
		This:C1470.supportedAttributes.push($attribute)
		
	End for each 
	
	//This.supportedAttributes:=This.supportedAttributes.orderBy("name")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Parse a plain text sentence and return a formatted text with any errors highlighted.
Function parsePhrase($phrase : Text) : Text
	
/* https://github.com/4d/4d/issues/17308
In the embedding phrase, if the attribute is incorrect, 
4D shall display the attribute in red 
and show a tooltip with an error message when the developer hovers over it.
*/
	var $pattern:="(?i-ms)\\{([^\\}]*)\\}"
	var $rgx:=cs:C1710.regex.new($phrase; $pattern)
	var $inputs:=$rgx.extract(1)
	var $dataclass : 4D:C1709.DataClass:=ds:C1482[This:C1470.dataclassName]
	
	$phrase:=Replace string:C233($phrase; "&"; "&amp;")
	$phrase:=Replace string:C233($phrase; "<"; "&lt;")
	$phrase:=Replace string:C233($phrase; ">"; "&gt;")
	
	This:C1470[""].errors:=[]
	
	var $t : Text
	For each ($t; $inputs)
		
		If ($dataclass[$t]=Null:C1517)
			
			This:C1470.error:=This:C1470._localizedErrorMessage("theAttibuteDoesn'tExistsInTheDataclass"; $t)
			
			var $old:=$t
			ST SET ATTRIBUTES:C1093($t; ST Start text:K78:15; ST End text:K78:16; Attribute text color:K65:7; "red")
			$phrase:=Replace string:C233($phrase; "{"+$old+"}"; "{"+$t+"}")
			
		End if 
	End for each 
	
	return "<span>"+$phrase+"</span>"
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _localizedErrorMessage($resname : Text; $attribute : Text; $dataclass : Text) : Text
	
	var $message:=Localized string:C991($resname)
	$message:=Replace string:C233($message; "{attribute}"; $attribute || This:C1470.vectorName)
	$message:=Replace string:C233($message; "{dataclass}"; $dataclass || This:C1470.dataclassName)
	
	return $message
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get defined() : Boolean
	
	return (This:C1470.version#-1) || (Length:C16(This:C1470.phrase)>0)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get definition() : cs:C1710.Vector
	
	var $phrase:=This:C1470.phrase
	
	return {\
		version: This:C1470.version; \
		dataclassName: This:C1470.dataclassName; \
		dataclassNumber: This:C1470.dataclassNumber; \
		vectorName: This:C1470.vectorName; \
		vectorNumber: This:C1470.vectorNumber; \
		model: This:C1470.model; \
		phrase: ST Get plain text:C1092($phrase)\
		}
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get helptip() : Text
	
	return Try(This:C1470[""].errors.join("\r"))
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> 
Function set error($message : Text)
	
	This:C1470[""]:=This:C1470[""] || {\
		touched: False:C215; \
		errors: []; \
		original: This:C1470.definition}
	
	This:C1470[""].errors.push($message)