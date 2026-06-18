/**
 Machine-readable error codes for cs.ProcessError.

 Exposes stable integer constants so callers can react programmatically
 (e.g. retry on transient failures, abort on fatal model outages) without
 parsing message strings.

 Each code maps — via meta() — to a default severity and retryability.
 The error scope ("entity" | "chunk" | "definition" | "pipeline") is
 contextual and supplied by the caller, not derived here.

 Usage:
   var $codes : cs.ProcessErrorCode:=cs.ProcessErrorCode.me
   If ($error.code=$codes.SAVE_FAILED)
       …
   End if
**/

// --- Input / configuration (1xx) ---
property NULL_INPUT : Integer:=100  // a required entity/selection/definition was Null
property INVALID_DEFINITION : Integer:=101  // value is not a usable Definition instance
property VALIDATION_FAILED : Integer:=102  // Definition.validate() reported a problem

// --- Model / API (2xx) ---
property MODEL_UNAVAILABLE : Integer:=200  // critical API error — the model is unusable for this run
property MODEL_SKIPPED : Integer:=201  // definition skipped because its model already failed critically
property EMBED_FAILED : Integer:=202  // non-critical embedding call failure (entity or chunk)

// --- Data integrity (3xx) ---
property VECTOR_COUNT_MISMATCH : Integer:=300  // provider returned a different vector count than requested

// --- Persistence (4xx) ---
property SAVE_FAILED : Integer:=400  // entity.save() failed (validation, lock, …)

singleton Class constructor()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Default severity ("warning" | "error" | "fatal") and retryability for a code.
	// Callers may override these per-error, but these defaults cover the common case.
Function meta($code : Integer) : Object
	
	Case of 
			
		: ($code=This:C1470.NULL_INPUT)
			return {severity: "error"; retryable: False:C215; label: "NULL_INPUT"}
			
		: ($code=This:C1470.INVALID_DEFINITION)
			return {severity: "error"; retryable: False:C215; label: "INVALID_DEFINITION"}
			
		: ($code=This:C1470.VALIDATION_FAILED)
			return {severity: "error"; retryable: False:C215; label: "VALIDATION_FAILED"}
			
		: ($code=This:C1470.MODEL_UNAVAILABLE)
			return {severity: "fatal"; retryable: True:C214; label: "MODEL_UNAVAILABLE"}
			
		: ($code=This:C1470.MODEL_SKIPPED)
			return {severity: "error"; retryable: True:C214; label: "MODEL_SKIPPED"}
			
		: ($code=This:C1470.EMBED_FAILED)
			return {severity: "error"; retryable: True:C214; label: "EMBED_FAILED"}
			
		: ($code=This:C1470.VECTOR_COUNT_MISMATCH)
			return {severity: "error"; retryable: False:C215; label: "VECTOR_COUNT_MISMATCH"}
			
		: ($code=This:C1470.SAVE_FAILED)
			return {severity: "error"; retryable: True:C214; label: "SAVE_FAILED"}
			
	End case 
	
	return {severity: "error"; retryable: False:C215; label: "UNKNOWN"}
	