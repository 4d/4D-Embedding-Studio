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
	
/* #17306
In the embedding phrase, the supported attributes shall be:
  • Simple fields
  • Computed attributes
  • Related fields (1:1, N:1 relationship)
  • Aliases
*/
	
	var $table:=$dataclass.getInfo()
	
	var $key : Text
	For each ($key; $dataclass)
		
		var $attribute : Object:=$dataclass[$key]
		
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
		
		This:C1470.supportedAttributes.push($attribute)
		
	End for each 
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Gives a menu of available dataclass attributes to insert into the descriptive phrase.
Function get inputsMenu() : cs:C1710.menu
	
	var $medias:=[].resize(42)
/*Alpha*/$medias[0]:="|Images/StructureEditor/Field_1.png"
/*Real*/$medias[1]:="|Images/StructureEditor/Field_9.png"
/*Text*/$medias[2]:="|Images/StructureEditor/Field_2.png"
/*Picture*/$medias[3]:="|Images/StructureEditor/Field_12.png"
/*Date*/$medias[4]:="|Images/StructureEditor/Field_3.png"
/*Boolean*/$medias[6]:="|Images/StructureEditor/Field_5.png"
/*Integer*/$medias[8]:="|Images/StructureEditor/Field_6.png"
/*Long*/$medias[9]:="|Images/StructureEditor/Field_7.png"
/*Time*/$medias[11]:="|Images/StructureEditor/Field_4.png"
/*Blob*/$medias[25]:="|Images/StructureEditor/Field_8.png"
/*Integer64*/$medias[30]:="|Images/StructureEditor/Field_11.png"
/*Object*/$medias[38]:="|Images/StructureEditor/Field_14.png"
/*relatedEntities*/$medias[42]:="|Images/ObjectIcons/Icon_600.png"
	
	var $menu:=cs:C1710.menu.new()
	
	var $attribute : Object
	For each ($attribute; This:C1470.supportedAttributes.orderBy("name"))
		
		$menu.append($attribute.name; "{"+$attribute.name+"}")
		
		If ($attribute.fieldType#Null:C1517)
			
			Try($menu.icon($medias[Num:C11($attribute.fieldType)]))
			
		End if 
	End for each 
	
	return $menu
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Parse a plain text sentence and return a formatted text with any errors highlighted.
Function parsePhrase($phrase : Text) : Text
	
/* #17308
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
		
		Case of 
				//______________________________________________________
			: ($dataclass[$t]=Null:C1517)  // Not available
				
				This:C1470.error:=This:C1470._localizedErrorMessage("theAttributeDoesn'tExistsInTheDataclass"; $t)
				
				//______________________________________________________
			: (String:C10($dataclass[$t].classID)="4D.Vector")  // Vector
				
				This:C1470.error:=This:C1470._localizedErrorMessage("theAttributeIsAVector"; $t)
				
				//______________________________________________________
			Else 
				
				continue
				
				//______________________________________________________
		End case 
		
		var $old:=$t
		ST SET ATTRIBUTES:C1093($t; ST Start text:K78:15; ST End text:K78:16; Attribute text color:K65:7; "red")
		$phrase:=Replace string:C233($phrase; "{"+$old+"}"; "{"+$t+"}")
		
	End for each 
	
	return "<span>"+$phrase+"</span>"  // In multistyle text format
	
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