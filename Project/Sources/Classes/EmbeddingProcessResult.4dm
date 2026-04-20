property definitionsProcessed : Integer:=0
property entitiesConsidered : Integer:=0
property entitiesUpdated : Integer:=0
property entitiesSkipped : Integer:=0
property apiCalls : Integer:=0
property durationMs : Integer:=0
property errors : Collection

property _startMs : Integer

Class constructor()
	
	This:C1470.errors:=[]
	This:C1470._startMs:=Milliseconds:C459
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Records an error scoped to a definition, a chunk, or a single entity.
	// $scope : "definition" | "chunk" | "entity"
	// $ref   : caller-defined identifier (dataclass/vectorName, entity primary key, …)
Function _addError($scope : Text; $ref : Variant; $message : Text) : cs:C1710.EmbeddingProcessResult
	
	This:C1470.errors.push({\
		scope: $scope; \
		ref: $ref; \
		message: $message})
	
	return This:C1470
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Finalize the report (captures durationMs). Chainable.
Function _done() : cs:C1710.EmbeddingProcessResult
	
	This:C1470.durationMs:=Milliseconds:C459-This:C1470._startMs
	
	return This:C1470
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when no error was recorded.
Function get success() : Boolean
	
	return This:C1470.errors.length=0
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Plain object suitable for logging or JSON serialization.
Function toObject() : Object
	
	return {\
		definitionsProcessed: This:C1470.definitionsProcessed; \
		entitiesConsidered: This:C1470.entitiesConsidered; \
		entitiesUpdated: This:C1470.entitiesUpdated; \
		entitiesSkipped: This:C1470.entitiesSkipped; \
		apiCalls: This:C1470.apiCalls; \
		durationMs: This:C1470.durationMs; \
		success: This:C1470.success; \
		errors: This:C1470.errors}
	