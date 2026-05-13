/**
 Ad-hoc, non-persisting helpers for rendering phrases and computing embeddings.

 Usage:
   var $pg:=cs.embed.Playground.new()
   var $pg:=cs.embed.Playground.new($settings; $options)

   $pg.render($entity)                                  // auto-resolve phrase
   $pg.render($entity; $phrase)                         // explicit phrase
   $pg.render($entity; $definition)                     // from definition
   $pg.render($entity; "template with {field}")         // compile on the fly

   $pg.embed("some text"; "text-embedding-3-small")     // direct embed
   $pg.embed($entity; $definition)                      // render + embed
   $pg.embed($entity)                                   // auto-resolve everything
**/

Class extends _ProcessBase

Class constructor($settings : cs:C1710.Settings; $options : Object)
	
	Super:C1705($settings; $options)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Render the phrase for an entity and return the resulting text. No API call, no persistence.
	// $definitionOrPhrase may be:
	//   - cs.embed.Phrase                  → used directly
	//   - cs.embed.Definition     → uses $definition.phrase
	//   - Text                       → compiled on the fly as a new Phrase
	//   - Null                       → auto-resolved from settings (requires a unique match for $entity's dataclass)
Function render($entity : 4D:C1709.Entity; $definitionOrPhrase : Variant) : Text
	
	If ($entity=Null:C1517)
		
		return ""
		
	End if 
	
	var $phrase : cs:C1710.Phrase:=This:C1470._phraseFrom($entity; $definitionOrPhrase)
	
	If ($phrase=Null:C1517)
		
		return ""
		
	End if 
	
	return $phrase.render($entity)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Compute a vector for an arbitrary input — without persisting anywhere.
	// Useful for previews, similarity checks, REPL experimentation, or ad-hoc querying.
	//
	// Supported call shapes:
	//   embed("some text"; "text-embedding-3-small")          → direct embed
	//   embed("some text"; $definition)                        → uses $definition.modelAlias
	//   embed($entity; $definition)                            → renders definition.phrase, embeds with definition.modelAlias
	//   embed($entity; $phrase; "text-embedding-3-small")      → renders $phrase, embeds with given model
	//   embed($entity; "template with {field}"; "model")       → compiles template on the fly
	//   embed($entity)                                         → auto-resolve definition from settings (unique match required)
	//
	// Throws if no model can be determined.
Function embed($input : Variant; $context : Variant; $model : Text) : cs:C1710.EmbedderResult
	
	var $text : Text
	var $modelName : Text:=$model
	
	Case of 
			
			// ______________________________________________________
		: (Value type:C1509($input)=Is text:K8:3)
			
			// Text input → $context is the model (or an Definition holding a model)
			$text:=$input
			
			Case of 
					
				: (Value type:C1509($context)=Is text:K8:3)
					
					$modelName:=$context
					
				: (OB Instance of:C1731($context; cs:C1710.Definition))
					
					$modelName:=String:C10($context.modelAlias)
					
			End case 
			
			// ______________________________________________________
		Else 
			
			// Assume entity (anything else falls through validation below)
			var $phrase : cs:C1710.Phrase:=This:C1470._phraseFrom($input; $context)
			
			If ($phrase=Null:C1517)
				
				throw:C1805({componentSignature: "4DES"; message: "No phrase could be resolved for the given entity/context"})
				
			End if 
			
			$text:=$phrase.render($input)
			
			// Pick model from $context if it's a definition, otherwise rely on $model, otherwise auto-resolve
			If ((Value type:C1509($context)=Is object:K8:27) && (OB Instance of:C1731($context; cs:C1710.Definition)))
				
				$modelName:=String:C10($context.modelAlias)
				
			End if 
			
			If (Length:C16($modelName)=0)
				
				var $resolved : cs:C1710.Definition:=This:C1470._resolveDefinitionFromEntity($input)
				If ($resolved#Null:C1517)
					
					$modelName:=String:C10($resolved.modelAlias)
					
				End if 
			End if 
			
			// ______________________________________________________
	End case 
	
	If (Length:C16($modelName)=0)
		
		throw:C1805({componentSignature: "4DES"; message: "No model specified (and none could be resolved from settings)"})
		
	End if 
	
	return This:C1470.embedder.embed($text; $modelName)
	
	
	// MARK:-[PRIVATE]
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Polymorphic phrase extraction: Phrase | Definition | Text template | Null (auto-resolve).
Function _phraseFrom($entity : 4D:C1709.Entity; $definitionOrPhrase : Variant) : cs:C1710.Phrase
	
	Case of 
			// ______________________________________________________
		: ($definitionOrPhrase=Null:C1517)
			
			var $resolved : cs:C1710.Definition:=This:C1470._resolveDefinitionFromEntity($entity)
			return ($resolved=Null:C1517) ? Null:C1517 : $resolved.phrase
			
			// ______________________________________________________
		: (Value type:C1509($definitionOrPhrase)=Is text:K8:3)
			
			return cs:C1710.Phrase.new($definitionOrPhrase)
			
			// ______________________________________________________
		: (Value type:C1509($definitionOrPhrase)#Is object:K8:27)
			
			return Null:C1517  // throw?
			
			// ______________________________________________________
		: (OB Instance of:C1731($definitionOrPhrase; cs:C1710.Phrase))
			
			return $definitionOrPhrase
			
			// ______________________________________________________
		: (OB Instance of:C1731($definitionOrPhrase; cs:C1710.Definition))
			
			return $definitionOrPhrase.phrase
			
			// ______________________________________________________
	End case 
	
	return Null:C1517
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Best-effort resolution of a single definition for an entity's dataclass.
	// Returns Null when the match is not unique (0 or >1) — caller must specify explicitly.
Function _resolveDefinitionFromEntity($entity : 4D:C1709.Entity) : cs:C1710.Definition
	
	If ($entity=Null:C1517)
		
		return Null:C1517
		
	End if 
	
	var $dcName : Text:=This:C1470.resolver.dataclassNameFromEntity($entity)
	var $matches : Collection:=This:C1470.settings.definitions.query("dataclassName = :1"; $dcName)
	
	return ($matches.length=1) ? $matches[0] : Null:C1517
	
	