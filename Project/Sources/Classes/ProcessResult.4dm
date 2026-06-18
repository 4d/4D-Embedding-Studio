property definitionsProcessed : Integer:=0
property entitiesConsidered : Integer:=0
property entitiesUpdated : Integer:=0
property entitiesSkipped : Integer:=0
property apiCalls : Integer:=0
property promptTokens : Integer:=0
property totalTokens : Integer:=0
property duration : Integer:=0
property errors : Collection

property _startTimestamp : Text
property _startMs : Integer

Class constructor()
	
	This:C1470.errors:=[]
	This:C1470._startTimestamp:=Timestamp:C1445
	This:C1470._startMs:=Milliseconds:C459
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Records a structured error scoped to the pipeline, a definition, a chunk, or a single entity.
	// $scope    : "pipeline" | "definition" | "chunk" | "entity"
	// $code     : machine-readable code — see cs.EmbeddingStudio.ProcessErrorCode
	// $ref      : caller-defined identifier (dataclass/vectorName, entity primary key, …)
	// $overrides: optional {severity; retryable} overriding the code defaults
Function _addError($scope : Text; $code : Integer; $ref : Variant; $message : Text; $overrides : Object) : cs:C1710.ProcessResult
	
	This:C1470.errors.push(cs:C1710.ProcessError.new($scope; $code; $ref; $message; $overrides))
	
	return This:C1470
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Accumulates token usage from a EmbedderResult.
Function _addUsage($embedderResult : cs:C1710.EmbedderResult) : cs:C1710.ProcessResult
	
	If ($embedderResult#Null:C1517)
		This:C1470.promptTokens+=$embedderResult.promptTokens
		This:C1470.totalTokens+=$embedderResult.totalTokens
	End if 
	
	return This:C1470
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Finalize the report (captures duration). Chainable.
Function _done() : cs:C1710.ProcessResult
	
	This:C1470.duration:=Milliseconds:C459-This:C1470._startMs
	
	return This:C1470
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when no blocking error was recorded (severity "error" or "fatal"). Warnings don't fail the run.
Function get success() : Boolean
	
	return This:C1470.errors.query("severity = :1 OR severity = :2"; "error"; "fatal").length=0
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when at least one fatal error was recorded (e.g. a model became unavailable).
Function get hasFatal() : Boolean
	
	return This:C1470.errors.query("severity = :1"; "fatal").length>0
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Errors filtered by scope ("pipeline" | "definition" | "chunk" | "entity").
Function errorsByScope($scope : Text) : Collection
	
	return This:C1470.errors.query("scope = :1"; $scope)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Errors filtered by machine-readable code (see cs.EmbeddingStudio.ProcessErrorCode).
Function errorsByCode($code : Integer) : Collection
	
	return This:C1470.errors.query("code = :1"; $code)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Errors flagged retryable — re-running the operation could plausibly succeed.
Function retryableErrors() : Collection
	
	return This:C1470.errors.query("retryable = :1"; True:C214)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Plain object suitable for logging or JSON serialization.
Function toObject() : Object
	
	return {\
		definitionsProcessed: This:C1470.definitionsProcessed; \
		entitiesConsidered: This:C1470.entitiesConsidered; \
		entitiesUpdated: This:C1470.entitiesUpdated; \
		entitiesSkipped: This:C1470.entitiesSkipped; \
		apiCalls: This:C1470.apiCalls; \
		promptTokens: This:C1470.promptTokens; \
		totalTokens: This:C1470.totalTokens; \
		duration: This:C1470.duration; \
		success: This:C1470.success; \
		hasFatal: This:C1470.hasFatal; \
		errors: This:C1470.errors.extract("scope,severity,code,ref,message,retryable")}
	