property prefix : Text:="[4DES]"
property outputType : Integer:=Into 4D diagnostic log:K38:8

singleton Class constructor
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Write one entry to 4D log.
	// $payload may be Text or Object.
Function _log($level : Integer; $payload : Variant)
	
	var $message : Text:=This:C1470._payloadToText($payload)
	If (Length:C16($message)=0)
		return 
	End if 
	
	If (Position:C15(This:C1470.prefix; $message)#1)
		$message:=This:C1470.prefix+" "+$message
	End if 
	
	LOG EVENT:C667(This:C1470.outputType; $message; $level)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function info($payload : Variant)
	This:C1470._log(Information message:K38:1; $payload)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function warn($payload : Variant)
	This:C1470._log(Warning message:K38:2; $payload)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function debug($payload : Variant)
	This:C1470._log(Information message:K38:1; $payload)  // XXX: no debug level available
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function error($payload : Variant)
	This:C1470._log(Error message:K38:3; $payload)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function _payloadToText($payload : Variant) : Text
	
	Case of 
		: ($payload=Null:C1517)
			return ""
		: (Value type:C1509($payload)=Is text:K8:3)
			return $payload
		: ((Value type:C1509($payload)=Is object:K8:27) || (Value type:C1509($payload)=Is collection:K8:32))
			return JSON Stringify:C1217($payload)
		Else 
			return String:C10($payload)
	End case 