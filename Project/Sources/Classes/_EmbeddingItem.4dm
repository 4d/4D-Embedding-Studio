property definition : cs:C1710.Definition
property version : Integer:=-1
property phrase:=""  // Styled text for the UI editor (highlighted errors, etc.)
property embedded:=[]
property settings : cs:C1710.Settings

property touched : Boolean:=False:C215
property original : Object

property _phraseErrors : Collection:=[]
property _modelErrors : Collection:=[]

property _dataclass : cs:C1710.DataClass

Class constructor($dataclass : 4D:C1709.DataClass; $definition : cs:C1710.Definition; $settings : cs:C1710.Settings)
	
	If (Count parameters:C259<2)
		
		If (Structure file:C489=Structure file:C489(*))
			
			ASSERT:C1129(False:C215; "Missing parameter")
			
		Else 
			
			throw:C1805({componentSignature: "4DES"; message: Localized string:C991("errMissingParameter"); deferred: True:C214})
			
		End if 
		
		return 
		
	End if 
	
	If (OB Class:C1730($dataclass).superclass=4D:C1709.DataClass)
		
		This:C1470.definition:=$definition
		This:C1470.settings:=$settings
		This:C1470._dataclass:=$dataclass
		
	End if 
	
	This:C1470.touched:=False:C215
	This:C1470._phraseErrors:=[]
	This:C1470._modelErrors:=[]
	This:C1470.original:=This:C1470.definition.toObject()
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Gives a menu of available dataclass attributes to insert into the descriptive phrase.
Function get inputsMenu() : cs:C1710._menu
	
	var $medias:=cs:C1710._typeMedia.me.medias
	var $menu:=cs:C1710._menu.new()
	
	var $attribute : Object
	For each ($attribute; This:C1470.supportedAttributes.orderBy("name"))
		
		If ($attribute.fields#Null:C1517)
			
			var $relationName : Text:=String:C10($attribute.name)
			var $submenu:=cs:C1710._menu.new()
			
			var $subAttr : Object
			For each ($subAttr; $attribute.fields.orderBy("name"))
				
				$submenu.append($subAttr.name; "{"+$relationName+"."+$subAttr.name+"}")
				
				If ($subAttr.fieldType#Null:C1517)
					
					Try($submenu.icon($medias[Num:C11($subAttr.fieldType)]))
					
				End if 
			End for each 
			
			$menu.append($relationName; $submenu)
			$menu.icon($medias[42])
			
		Else 
			
			$menu.append($attribute.name; "{"+$attribute.name+"}")
			
			If ($attribute.fieldType#Null:C1517)
				
				var $fieldType:=Num:C11($attribute.fieldType)
				
				Try($menu.icon($medias[$fieldType]))
				
			End if 
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
	
	This:C1470._phraseErrors:=[]
	
	var $err : Object
	var $errorColor:=FORM Get color scheme:C1761="dark" ? "#ea7979" : "red"
	For each ($err; $validation.errors)
		
		This:C1470._phraseErrors.push($err.message)
		
		var $styled : Text:=$err.key
		ST SET ATTRIBUTES:C1093($styled; ST Start text:K78:15; ST End text:K78:16; Attribute text color:K65:7; $errorColor)
		$text:=Replace string:C233($text; "{"+$err.key+"}"; "{"+$styled+"}")
		
	End for each 
	
	return "<span>"+$text+"</span>"  // In multistyle text format
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get defined() : Boolean
	
	return (This:C1470.definition#Null:C1517) && (This:C1470.version>=0)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Concatenation of phrase + model error messages (most recent validate() pass).
Function get errors() : Collection
	
	return This:C1470._phraseErrors.concat(This:C1470._modelErrors)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Always safe to call: returns the joined error list (empty string when none).
Function get helptip() : Text
	
	return This:C1470.errors.join("\r")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Re-runs phrase + model validation and refreshes _phraseErrors / _modelErrors.
	// Also refreshes the styled phrase so the editor stays in sync.
Function validate()
	
	This:C1470.phrase:=This:C1470.parsePhrase(This:C1470.definition.phrase)
	This:C1470._validateModel()
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Validates the model:
	//  • a phrase set without a configured model
	//  • a model name that is not part of the available modelAliases
Function _validateModel()
	
	This:C1470._modelErrors:=[]
	
	If (This:C1470.definition=Null:C1517)
		
		return 
		
	End if 
	
	var $model : Text:=String:C10(This:C1470.definition.modelAlias)
	
	If (Length:C16($model)=0)
		
		If (Length:C16(String:C10(This:C1470.definition.phrase.template))>0)
			
			This:C1470._modelErrors.push(Localized string:C991("theModelIsNotDefined"))
			
		End if 
		
		return 
		
	End if 
	
	// Model is set — must be part of the available aliases
	var $aliases : Collection:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases().extract("name")
	
	If (Not:C34($aliases.includes($model)))
		
		This:C1470._modelErrors.push(Replace string:C233(Localized string:C991("theModelIsNotAvailable"); "{model}"; $model))
		
	End if 
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get supportedAttributes() : Collection
	
	return cs:C1710._dataclassAttributes.me.forDataclass(This:C1470._dataclass; (This:C1470.settings#Null:C1517) ? This:C1470.settings.phrase : Null:C1517)
	
	// MARK:- dirty attributes
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function hasDirtyAssociatedAttribute() : Boolean
	
	return This:C1470._dataclass[This:C1470.definition.vectorName+"_dirty"]#Null:C1517
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function dirtyAssociatedAttributeIndexed() : Boolean
	
	var $attr : Object:=This:C1470._dataclass[This:C1470.definition.vectorName+"_dirty"]
	
	return $attr=Null:C1517 ? False:C215 : Bool:C1537($attr.indexed)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function createDirtyAssociatedAttribute()
	
	If (This:C1470.hasDirtyAssociatedAttribute())
		
		return 
		
	End if 
	
	var $t:=This:C1470.definition.dataclassName
	var $f:=This:C1470.definition.vectorName+"_dirty"
	
	DOCUMENT:="ALTER TABLE ["+$t+"] ADD TRAILING "+$f+" boolean;"
	
	Begin SQL
		
		EXECUTE IMMEDIATE : DOCUMENT
		
	End SQL
	
	DOCUMENT:="CREATE INDEX "+$f+"_"+$t+" ON ["+$t+"] ("+$f+");"
	
	Begin SQL
		
		EXECUTE IMMEDIATE : DOCUMENT
		
	End SQL
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function createDirtyAssociatedAttributeIndex()
	
	If (This:C1470.dirtyAssociatedAttributeIndexed())
		
		return 
		
	End if 
	
	var $t:=This:C1470.definition.dataclassName
	var $f:=This:C1470.definition.vectorName+"_dirty"
	
	DOCUMENT:="CREATE INDEX "+$f+"_"+$t+" ON ["+$t+"] ("+$f+");"
	
	Begin SQL
		
		EXECUTE IMMEDIATE : DOCUMENT
		
	End SQL