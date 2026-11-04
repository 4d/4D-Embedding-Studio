/**
 Renders and embeds on demand, resolved against the Studio settings (saved definitions → phrase + model).
 Nothing is persisted: use it to build a search query vector consistent with the stored ones, or to preview a phrase.

 Usage:
   var $studioEmbedder:=cs.StudioEmbedder.new()
   var $studioEmbedder:=cs.StudioEmbedder.new($settings; $options)

   $studioEmbedder.render($entity)                                  // auto-resolve phrase
   $studioEmbedder.render($entity; $phrase)                         // explicit phrase
   $studioEmbedder.render($entity; $definition)                     // from definition
   $studioEmbedder.render($entity; "template with {field}")         // compile on the fly
   $studioEmbedder.render($entity; {vectorName: "embedding"})       // stub → saved definition (deduces phrase)
   $studioEmbedder.render($entity; {phrase: "tpl {field}"})         // ad-hoc stub → inline template

   $studioEmbedder.embed("some text"; "text-embedding-3-small")     // direct embed
   $studioEmbedder.embed($entity; $definition)                      // render + embed
   $studioEmbedder.embed($entity)                                   // auto-resolve everything
   $studioEmbedder.embed($entity; {vectorName: "embedding"})        // stub → saved definition (deduces phrase + model)
   $studioEmbedder.embed($entity; {phrase: "tpl {x}"; modelAlias: "m"})  // ad-hoc stub (deduces nothing, all given)
   $studioEmbedder.embed("some text"; {modelAlias: "m"})            // stub supplies the model

 Untyped stubs are resolved the same way cs.Process resolves its definition argument: a
 {vectorName: …} (optionally with {dataclassName}) is matched against the saved
 definitions, deducing its phrase and model from the entity's dataclass.
**/

Class extends _ProcessBase

Class constructor($settings : cs:C1710.Settings; $options : Object)
	
	Super:C1705($settings; $options)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Render the phrase for an entity and return the resulting text. No API call, no persistence.
	// $entity: 4D entity
	// $definitionOrPhrase: could be
	//   - cs.Phrase                  → used directly
	//   - cs.Definition     → uses $definition.phrase
	//   - Text                       → compiled on the fly as a new Phrase
	//   - Object stub                → {vectorName[; dataclassName]} looked up in settings (deduces the phrase),
	//                                  or {phrase|template: Text} compiled inline
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
	// Useful for search queries, similarity checks, or previews.
	//
	// Supported call shapes:
	//   embed("some text"; "text-embedding-3-small")          → direct embed
	//   embed("some text"; $definition)                        → uses $definition.modelAlias
	//   embed($entity; $definition)                            → renders definition.phrase, embeds with definition.modelAlias
	//   embed($entity; $phrase; "text-embedding-3-small")      → renders $phrase, embeds with given model
	//   embed($entity; "template with {field}"; "model")       → compiles template on the fly
	//   embed($entity)                                         → auto-resolve definition from settings (unique match required)
	//   embed($entity; {vectorName: "v"})                      → stub → saved definition (deduces phrase + model)
	//   embed($entity; {phrase: "tpl {x}"; modelAlias: "m"})   → ad-hoc stub, phrase compiled inline, model taken from stub
	//   embed("some text"; {modelAlias: "m"})                  → stub supplies the model only
	//
	// $context stubs are resolved exactly like cs.Process resolves its definition argument — a
	// {vectorName} stub is matched against the saved definitions for the (entity's) dataclass; an
	// explicit {modelAlias} on the stub always wins over a deduced one.
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
					
					// Plain object stub → its modelAlias, or the model of a stub-matched saved definition
				: (Value type:C1509($context)=Is object:K8:27)
					
					$modelName:=This:C1470._modelFromStub(""; $context; $modelName)
					
			End case 
			
			// ______________________________________________________
		Else 
			
			// Assume entity (anything else falls through validation below)
			var $phrase : cs:C1710.Phrase:=This:C1470._phraseFrom($input; $context)
			
			If ($phrase=Null:C1517)
				
				throw:C1805({componentSignature: "4DES"; message: Localized string:C991("errNoPhraseResolved")})
				
			End if 
			
			$text:=$phrase.render($input)
			
			// Pick the model from $context (a Definition or a stub), else rely on $model, else auto-resolve
			Case of 
				: ((Value type:C1509($context)=Is object:K8:27) && (OB Instance of:C1731($context; cs:C1710.Definition)))
					
					$modelName:=String:C10($context.modelAlias)
					
				: ((Value type:C1509($context)=Is object:K8:27) && Not:C34(OB Instance of:C1731($context; cs:C1710.Phrase)))
					
					$modelName:=This:C1470._modelFromStub(This:C1470.resolver.dataclassNameFromEntity($input); $context; $modelName)
					
			End case 
			
			If (Length:C16($modelName)=0)
				
				var $resolved : cs:C1710.Definition:=This:C1470._resolveDefinitionFromEntity($input)
				If ($resolved#Null:C1517)
					
					$modelName:=String:C10($resolved.modelAlias)
					
				End if 
			End if 
			
			// ______________________________________________________
	End case 
	
	If (Length:C16($modelName)=0)
		
		throw:C1805({componentSignature: "4DES"; message: Localized string:C991("errNoModelSpecified")})
		
	End if 
	
	return This:C1470.embedder.embed($text; $modelName)
	
	
	// MARK:-[PRIVATE]
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Polymorphic phrase extraction: Phrase | Definition | Text template | object stub | Null (auto-resolve).
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
	
	// Plain object stub (e.g. {vectorName: "x"} or {phrase: "tpl {field}"}) → deduce like cs.Process does.
	return This:C1470._phraseFromStub($entity; $definitionOrPhrase)
	
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
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Resolves a plain object stub to a Phrase: an inline {phrase|template} compiles directly;
	// otherwise a {vectorName[; dataclassName]} stub is matched against the saved definitions
	// (the same way cs.Process resolves its definition argument) and its phrase is returned.
Function _phraseFromStub($entity : 4D:C1709.Entity; $stub : Object) : cs:C1710.Phrase
	
	// Inline ad-hoc template wins — no lookup needed.
	Case of 
			// ______________________________________________________
		: (Value type:C1509($stub.phrase)=Is text:K8:3)
			
			return cs:C1710.Phrase.new($stub.phrase)
			
			// ______________________________________________________
		: ((Value type:C1509($stub.phrase)=Is object:K8:27) && (OB Instance of:C1731($stub.phrase; cs:C1710.Phrase)))
			
			return $stub.phrase
			
			// ______________________________________________________
		: (Value type:C1509($stub.template)=Is text:K8:3)
			
			return cs:C1710.Phrase.new($stub.template)
			
			// ______________________________________________________
	End case 
	
	// Identity stub → resolve against the entity's dataclass, the same path cs.Process uses.
	var $dcName : Text:=This:C1470.resolver.dataclassNameFromEntity($entity)
	var $def : cs:C1710.Definition:=This:C1470.resolver.resolveForEntity($stub; $dcName).first()
	
	return ($def=Null:C1517) ? Null:C1517 : $def.phrase
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Deduces a model name from a plain object stub: an explicit {modelAlias} wins; otherwise the
	// model of a {vectorName[; dataclassName]} stub matched against the saved definitions; else $fallback.
Function _modelFromStub($contextDataclassName : Text; $stub : Object; $fallback : Text) : Text
	
	If (Length:C16(String:C10($stub.modelAlias))>0)
		
		return String:C10($stub.modelAlias)
		
	End if 
	
	var $def : cs:C1710.Definition:=This:C1470.resolver.resolveForEntity($stub; $contextDataclassName).first()
	
	If ($def#Null:C1517)
		
		return String:C10($def.modelAlias)
		
	End if 
	
	return $fallback
	