property definition : cs:C1710.Definition
property version : Integer:=-1
property phrase:=""  // Styled text for the UI editor (highlighted errors, etc.)
property embedded:=[]
property settings : cs:C1710.Settings

property touched : Boolean:=False:C215
property original : Object

property _phraseErrors : Collection:=[]
property _phraseWarnings : Collection:=[]
property _indexWarnings : Collection:=[]
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
	This:C1470._phraseWarnings:=[]
	This:C1470._indexWarnings:=[]
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
	var $validation:=$phrase.validate($dataclass; (This:C1470.settings=Null:C1517) ? Null:C1517 : This:C1470.settings.phrase; This:C1470.definition.vectorName)

	var $text : Text:=$phrase.template
	$text:=Replace string:C233($text; "&"; "&amp;")
	$text:=Replace string:C233($text; "<"; "&lt;")
	$text:=Replace string:C233($text; ">"; "&gt;")

	This:C1470._phraseErrors:=[]
	This:C1470._phraseWarnings:=[]

	var $entry : Object

	var $errorColor:=_errorColor()
	For each ($entry; $validation.errors)

		This:C1470._phraseErrors.push($entry.message)

		var $styled : Text:=$entry.key
		ST SET ATTRIBUTES:C1093($styled; ST Start text:K78:15; ST End text:K78:16; Attribute text color:K65:7; $errorColor)
		$text:=Replace string:C233($text; "{"+$entry.key+"}"; "{"+$styled+"}")

	End for each

	var $warningColor:=_warningColor()
	For each ($entry; $validation.warnings)

		This:C1470._phraseWarnings.push($entry.message)

		$styled:=$entry.key
		ST SET ATTRIBUTES:C1093($styled; ST Start text:K78:15; ST End text:K78:16; Attribute text color:K65:7; $warningColor)
		$text:=Replace string:C233($text; "{"+$entry.key+"}"; "{"+$styled+"}")

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
	// Non-blocking warnings: phrase (e.g. another vector's "_dirty" flag) + missing indexes.
Function get warnings() : Collection
	
	return This:C1470._phraseWarnings.concat(This:C1470._indexWarnings)
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Always safe to call: returns the joined error list (empty string when none).
	// Non-blocking warnings are appended below the errors.
Function get helptip() : Text

		var $lines : Collection:=This:C1470.errors.copy()

		var $warning : Text
		For each ($warning; This:C1470.warnings)
			$lines.push("⚠️ "+$warning)
		End for each

		return $lines.join("\r")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Re-runs phrase + model validation and refreshes _phraseErrors / _modelErrors.
	// Also refreshes the styled phrase so the editor stays in sync.
Function validate()
	
	This:C1470.phrase:=This:C1470.parsePhrase(This:C1470.definition.phrase)
	This:C1470._validateModel()
	This:C1470._validateIndexes()
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Warns, one message per missing index, when the vector lacks its automatic (object) index
	// (null checks: what to compute or invalidate) or its vector index (similarity queries),
	// or when its "_dirty" flag is not indexed: these get slow on large tables.
Function _validateIndexes()

	This:C1470._indexWarnings:=[]

	If ((This:C1470.definition=Null:C1517) || (This:C1470._dataclass=Null:C1517))

		return

	End if

	If (Not:C34(This:C1470.vectorObjectIndexed()))

		This:C1470._indexWarnings.push(Localized string:C991("theVectorFieldHasNoObjectIndex"))

	End if

	If (Not:C34(This:C1470.vectorDistanceIndexed()))

		This:C1470._indexWarnings.push(Localized string:C991("theVectorFieldHasNoVectorIndex"))

	End if

	If (This:C1470.hasDirtyAssociatedAttribute() && Not:C34(This:C1470.dirtyAssociatedAttributeIndexed()))

		This:C1470._indexWarnings.push(Localized string:C991("theDirtyFieldIsNotIndexed"))

	End if
	
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
	
	// Model is set — 4D AIKit must be loaded to know the available aliases
	If (Not:C34(cs:C1710._AIKit.me.isAvailable))
		
		This:C1470._modelErrors.push(cs:C1710._AIKit.me.missingReason)
		return 
		
	End if 
	
	// Model is set — must be part of the available aliases
	var $aliases : Collection:=cs:C1710._AIKit.me.modelNames()
	
	If (Not:C34($aliases.includes($model)))
		
		This:C1470._modelErrors.push(Replace string:C233(Localized string:C991("theModelIsNotAvailable"); "{model}"; $model))
		
	End if 
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get supportedAttributes() : Collection
	
	return cs:C1710._dataclassAttributes.me.forDataclass(This:C1470._dataclass; (This:C1470.settings#Null:C1517) ? This:C1470.settings.phrase : Null:C1517)
	
	// MARK:- dirty attributes
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Also drives the read-only "dirty flag" column of the vector list (see dirtyAssociatedAttributeMark).
Function hasDirtyAssociatedAttribute() : Boolean
	
	If ((This:C1470.definition=Null:C1517) || (This:C1470._dataclass=Null:C1517))
		
		return False:C215
		
	End if 
	
	return This:C1470._dataclass[This:C1470.definition.vectorName+"_dirty"]#Null:C1517
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Cell value of the "dirty flag" column: a plain ✓ (U+2713, renders on macOS and Windows), not a
	// checkbox, which would look like a control that creates the field (use the context menu for that).
Function get dirtyAssociatedAttributeMark() : Text
	
	return This:C1470.hasDirtyAssociatedAttribute() ? "✓" : ""
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// The automatic (object) index, used by the "= null" / "!= null" queries.
	// On a vector field, ORDA "indexed" only reports this one, never a vector index.
Function vectorObjectIndexed() : Boolean

	var $attr : Object:=This:C1470._dataclass[This:C1470.definition.vectorName]

	return $attr=Null:C1517 ? False:C215 : Bool:C1537($attr.indexed)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// The vector index (cosine, dot or euclidean), used by the similarity queries.
Function vectorDistanceIndexed() : Boolean

	var $vectorTypes : Collection:=[Vector cosine index; Vector dot index; Vector euclidean index]

	return This:C1470._dataclass.getIndexes().some(Formula:C1597($2.includes($1.value.type) && $1.value.attributes.includes($3)); $vectorTypes; This:C1470.definition.vectorName)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Creates the automatic (object) index of the vector field.
	// Pointers rather than SQL, so a field name with a space is fine.
Function createVectorObjectIndex()

	If (This:C1470.vectorObjectIndexed())

		return

	End if

	var $tableNum : Integer:=This:C1470._dataclass.getInfo().tableNumber

	ARRAY POINTER:C280($fields; 1)
	$fields{1}:=Field:C253($tableNum; This:C1470._dataclass[This:C1470.definition.vectorName].fieldNumber)

	CREATE INDEX:C966(Table:C252($tableNum)->; $fields; Default index type; This:C1470.definition.vectorName+"_"+This:C1470.definition.dataclassName)

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