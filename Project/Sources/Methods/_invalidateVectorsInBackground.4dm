//%attributes = {"invisible":true}
// Runs in the "EmbeddingStudio_invalidate" worker, posted by cs._EMBEDDINGS.flushPromptInvalidate():
// invalidates the definitions the user agreed to recalculate out of the window's process (one
// save per entity: a large table would freeze the UI), calls the window back, then posts the
// optional follow-up ($then, called with $param, e.g. a compute) to the "EmbeddingStudio" worker.
// While it runs, Storage.studio.operation names it for the window's footer status bar.
// No KILL WORKER: it would discard the requests queued behind this one.
#DECLARE($definitions : Collection; $then : 4D:C1709.Function; $param : Variant)

var $result : Object:={updated: 0; skipped: 0; errors: []}
var $window : Integer:=(Storage:C1525.studio=Null:C1517) ? 0 : Num:C11(Storage:C1525.studio["EMBEDDINGS"])

If (($definitions.length>0) && (Storage:C1525.studio#Null:C1517))
	
	Use (Storage:C1525.studio)
		Storage:C1525.studio.operation:=Replace string:C233(Localized string:C991("operationInvalidating"); "{vectors}"; \
			$definitions.map(Formula:C1597($1.value.dataclassName+"."+$1.value.vectorName)).join(", "))
	End use 
	
	If ($window#0)
		CALL FORM:C1391($window; Formula:C1597(Form:C1466.paintSchedulerStatus()))
	End if 
	
End if 

var $o : Object
For each ($o; $definitions)
	
	var $r : Object:=cs:C1710.Definition.new($o.dataclassName; $o.vectorName).invalidateVectors()
	$result.updated+=Num:C11($r.updated)
	$result.skipped+=Num:C11($r.skipped)
	$result.errors.combine($r.errors)
	
End for each 

If ($result.errors.length>0)
	
	$result.message:=Replace string:C233(Localized string:C991("invalidateFailed"); "{count}"; String:C10($result.skipped))
	
	var $e : Text
	For each ($e; $result.errors)
		$result.message+="\n  • "+$e
	End for each 
	
End if 

If ($definitions.length>0)
	
	If (Storage:C1525.studio#Null:C1517)
		Use (Storage:C1525.studio)
			Storage:C1525.studio.operation:=""
		End use 
	End if 
	
	$window:=(Storage:C1525.studio=Null:C1517) ? 0 : Num:C11(Storage:C1525.studio["EMBEDDINGS"])  // May have been closed meanwhile
	
	Case of 
		: ($window#0)
			CALL FORM:C1391($window; Formula:C1597(Form:C1466.invalidateDone($1)); $result)
		: ($result.errors.length>0)  // The window is closed: report from here
			cs:C1710._Dialog.me.alert($result.message)
	End case 
	
End if 

If ($then#Null:C1517)
	
	CALL WORKER:C1389("EmbeddingStudio"; Formula:C1597(_runInWorker($1; $2)); $then; $param)
	
End if 
