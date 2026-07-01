/**
 Typed error recorded on a cs.ProcessResult.

 Replaces the former flat {scope, ref, message} object with a structured shape
 that lets callers distinguish failure modes programmatically instead of parsing
 message strings.
 
 | Property  | Type    | Description                                                        |
 | --------- | ------- | ------------------------------------------------------------------ |
 | scope     | Text    | "entity" \| "chunk" \| "definition" \| "pipeline"                  |
 | severity  | Text    | "warning" \| "error" \| "fatal"                                    |
 | code      | Integer | machine-readable code — see cs.ProcessErrorCode              |
 | ref       | Variant | contextual identifier (entity primary key, "Dataclass.vector", …)  |
 | message   | Text    | human-readable description                                          |
 | retryable | Boolean | True when re-running the operation could plausibly succeed         |
 | timestamp | Text    | ISO timestamp captured when the error was created                  |

 severity and retryable default from the code (cs.ProcessErrorCode.meta),
 and can be overridden via the $overrides object.
**/

property scope : Text
property severity : Text
property code : Integer
property ref : Variant
property message : Text
property retryable : Boolean
property timestamp : Text

// $overrides (optional): {severity; retryable} to override the code defaults.
Class constructor($scope : Text; $code : Integer; $ref : Variant; $message : Text; $overrides : Object)
	
	var $meta : Object:=cs:C1710.ProcessErrorCode.me.meta($code)
	
	This:C1470.scope:=$scope
	This:C1470.code:=$code
	This:C1470.ref:=$ref
	This:C1470.message:=$message
	This:C1470.severity:=$meta.severity
	This:C1470.retryable:=$meta.retryable
	This:C1470.timestamp:=Timestamp:C1445
	
	If ($overrides#Null:C1517)
		If ($overrides.severity#Null:C1517)
			This:C1470.severity:=String:C10($overrides.severity)
		End if 
		If ($overrides.retryable#Null:C1517)
			This:C1470.retryable:=Bool:C1537($overrides.retryable)
		End if 
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when this error blocks the rest of the run (e.g. a model is unavailable).
Function get isFatal() : Boolean
	
	return This:C1470.severity="fatal"
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Plain object — for logging or JSON serialization.
Function toObject() : Object
	
	return {\
		scope: This:C1470.scope; \
		severity: This:C1470.severity; \
		code: This:C1470.code; \
		ref: This:C1470.ref; \
		message: This:C1470.message; \
		retryable: This:C1470.retryable; \
		timestamp: This:C1470.timestamp}
	