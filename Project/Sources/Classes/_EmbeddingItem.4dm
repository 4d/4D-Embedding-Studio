property definition : cs:C1710.EmbeddingDefinition
property phrase:=""  // Styled text for the UI editor (highlighted errors, etc.)
property supportedAttributes:=[]
property embedded:=[]
property settings : cs:C1710.EmbeddingSettings

Class constructor($dataclass : 4D:C1709.DataClass; $definition : cs:C1710.EmbeddingDefinition; $settings : cs:C1710.EmbeddingSettings)
	
	If (Count parameters:C259<2)
		
		If (Structure file:C489=Structure file:C489(*))
			
			ASSERT:C1129(False:C215; "Missing parameter")
			
		Else 
			
			throw:C1805({componentSignature: "4DVS"; message: "Missing parameter"; deferred: True:C214})
			
		End if 
		
		return 
		
	End if 
	
	If (OB Class:C1730($dataclass).superclass=4D:C1709.DataClass)
		
		This:C1470.definition:=$definition
		This:C1470.settings:=$settings
		
		This:C1470.supportedAttributes:=cs:C1710._dataclassAttributes.me.forDataclass($dataclass; ($settings#Null:C1517) ? $settings.phrase : Null:C1517)
		
	End if 
	
	This:C1470[""]:={\
		touched: False:C215; \
		errors: []; \
		original: This:C1470.definition.toObject()}
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Gives a menu of available dataclass attributes to insert into the descriptive phrase.
Function get inputsMenu() : cs:C1710._menu
	
	var $medias:=cs:C1710._typeMedia.me.medias
	var $menu:=cs:C1710._menu.new()
	
	var $attribute : Object
	For each ($attribute; This:C1470.supportedAttributes.orderBy("name"))
		
		$menu.append($attribute.name; "{"+$attribute.name+"}")
		
		If ($attribute.fieldType#Null:C1517)
			
			Try($menu.icon($medias[Num:C11($attribute.fieldType)]))
			
		End if 
	End for each 
	
	return $menu
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Validate a compiled Phrase against this item's dataclass and return styled
	// text (multistyle) with any attribute errors highlighted.
Function parsePhrase($phrase : cs:C1710.Phrase) : Text
	
/* #17308
In the embedding phrase, if the attribute is incorrect,
4D shall display the attribute in red
and show a tooltip with an error message when the developer hovers over it.
*/
	var $dataclass : 4D:C1709.DataClass:=ds:C1482[This:C1470.definition.dataclassName]
	var $validation:=$phrase.validate($dataclass; (This:C1470.settings=Null:C1517) ? Null:C1517 : This:C1470.settings.phrase)
	
	var $text : Text:=$phrase.template
	$text:=Replace string:C233($text; "&"; "&amp;")
	$text:=Replace string:C233($text; "<"; "&lt;")
	$text:=Replace string:C233($text; ">"; "&gt;")
	
	This:C1470[""].errors:=[]
	
	var $err : Object
	var $errorColor:=FORM Get color scheme:C1761="dark" ? "#ea7979" : "red"
	For each ($err; $validation.errors)
		
		This:C1470.error:=$err.message
		
		var $styled : Text:=$err.key
		ST SET ATTRIBUTES:C1093($styled; ST Start text:K78:15; ST End text:K78:16; Attribute text color:K65:7; $errorColor)
		$text:=Replace string:C233($text; "{"+$err.key+"}"; "{"+$styled+"}")
		
	End for each 
	
	return "<span>"+$text+"</span>"  // In multistyle text format
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get defined() : Boolean
	
	return (This:C1470.definition#Null:C1517) && (This:C1470.definition.version>=0)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get helptip() : Text
	
	return Try(This:C1470[""].errors.join("\r"))
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==>
Function set error($message : Text)
	
	This:C1470[""]:=This:C1470[""] || {\
		touched: False:C215; \
		errors: []; \
		original: This:C1470.definition.toObject()}
	
	This:C1470[""].errors.push($message)
	