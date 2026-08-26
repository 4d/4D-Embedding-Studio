property _semaphoreName : Text:="4DES_ExecutionLog"
// In ticks. The guarded work is a small JSON read+write, i.e. milliseconds; a caller that
// waits longer than this is waiting on something stuck, and it pays the wait on every call.
property _semaphoreTimeout : Integer:=120

singleton Class constructor
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Sets top-level to "running", saving current top-level as "previous".
Function startFullRun($startTimestamp : Text)
	
	If (This:C1470._acquire("startFullRun"))
		
		Try
			
			var $log : Object:=This:C1470._read()
			
			If (Length:C16(String:C10($log.startTime))>0)
				$log.previous:=This:C1470._extractTopLevel($log)
			End if 
			
			$log.startTime:=$startTimestamp
			$log.endTime:=Null:C1517
			$log.status:="running"
			$log.trigger:="started"
			$log.error:=Null:C1517
			$log.nextComputeDate:=Null:C1517
			This:C1470._write($log)
			
		Catch
			cs:C1710._Logger.me.error("Execution log write failed: "+String:C10(Last errors:C1799[0].message))
		End try
		
		This:C1470._release()
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Finalizes top-level with completed/failed status.
Function endFullRun($startTimestamp : Text; $endTimestamp : Text; $status : Text; $error : Variant; $nextComputeDate : Variant; $usage : Object)
	
	If (This:C1470._acquire("endFullRun"))
		
		Try
			
			var $log : Object:=This:C1470._read()
			$log.startTime:=$startTimestamp
			$log.endTime:=$endTimestamp
			$log.status:=$status
			$log.trigger:=$status
			$log.error:=$error
			$log.nextComputeDate:=($nextComputeDate#Null:C1517) ? $nextComputeDate : Null:C1517
			If ($usage#Null:C1517)
				$log.promptTokens:=Num:C11($usage.prompt_tokens)
				$log.totalTokens:=Num:C11($usage.total_tokens)
				$log.cumulativePromptTokens:=Num:C11($log.previous.cumulativePromptTokens)+$log.promptTokens
				$log.cumulativeTotalTokens:=Num:C11($log.previous.cumulativeTotalTokens)+$log.totalTokens
			End if 
			This:C1470._write($log)
			
		Catch
			cs:C1710._Logger.me.error("Execution log write failed: "+String:C10(Last errors:C1799[0].message))
		End try
		
		This:C1470._release()
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Updates one definition entry, saving its current state as "previous".
Function updateDefinition($defKey : Text; $startTime : Text; $endTime : Text; $status : Text; $error : Variant; $usage : Object)
	
	If (This:C1470._acquire("updateDefinition"))
		
		Try
			
			var $log : Object:=This:C1470._read()
			
			If ($log.definitions=Null:C1517)
				$log.definitions:={}
			End if 
			
			var $entry : Object:={\
				startTime: $startTime; \
				endTime: $endTime; \
				status: $status; \
				error: $error}
			
			If ($usage#Null:C1517)
				$entry.promptTokens:=Num:C11($usage.prompt_tokens)
				$entry.totalTokens:=Num:C11($usage.total_tokens)
				If ($log.definitions[$defKey]#Null:C1517)
					$entry.cumulativePromptTokens:=Num:C11($log.definitions[$defKey].cumulativePromptTokens)+$entry.promptTokens
					$entry.cumulativeTotalTokens:=Num:C11($log.definitions[$defKey].cumulativeTotalTokens)+$entry.totalTokens
				Else 
					$entry.cumulativePromptTokens:=$entry.promptTokens
					$entry.cumulativeTotalTokens:=$entry.totalTokens
				End if 
			End if 
			
			If ($log.definitions[$defKey]#Null:C1517)
				var $prev : Object:=OB Copy:C1225($log.definitions[$defKey])
				OB REMOVE:C1226($prev; "previous")
				$entry.previous:=$prev
			End if 
			
			$log.definitions[$defKey]:=$entry
			This:C1470._write($log)
			
		Catch
			cs:C1710._Logger.me.error("Execution log write failed: "+String:C10(Last errors:C1799[0].message))
		End try
		
		This:C1470._release()
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Records a skipped scheduler trigger with its timestamp (AC-4.1.4).
Function logSkipped($timestamp : Text)
	
	If (This:C1470._acquire("logSkipped"))
		
		Try
			
			var $log : Object:=This:C1470._read()
			$log.trigger:="skipped"
			
			If (Value type:C1509($log.skipped)#Is collection:K8:32)
				$log.skipped:=[]
			End if 
			$log.skipped.push($timestamp)
			
			If ($log.skipped.length>50)
				$log.skipped:=$log.skipped.slice($log.skipped.length-50)
			End if 
			
			This:C1470._write($log)
			
		Catch
			cs:C1710._Logger.me.error("Execution log write failed: "+String:C10(Last errors:C1799[0].message))
		End try
		
		This:C1470._release()
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Updates the top-level next scheduled recalculation date.
Function setNextComputeDate($value : Text)
	
	If (This:C1470._acquire("setNextComputeDate"))
		
		Try
			
			var $log : Object:=This:C1470._read()
			$log.nextComputeDate:=(Length:C16(String:C10($value))>0) ? $value : Null:C1517
			This:C1470._write($log)
			
		Catch
			cs:C1710._Logger.me.error("Execution log write failed: "+String:C10(Last errors:C1799[0].message))
		End try
		
		This:C1470._release()
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the last completed run as { timestamp; status; error }, all in the scheduler's
	// local ISO base (startTime/endTime are written in that base too). While a run is in
	// progress the top-level endTime is Null and the last completed run sits in "previous",
	// so fall back to it — this is what lets the scheduler rehydrate its anchor after a restart
	// straight from the history, without persisting the timestamp a second time in its own field.
Function lastRun() : Object

	var $log : Object:=This:C1470._read()

	// A run in progress leaves the top-level endTime Null (JSON null, not a Text), so the last
	// completed run lives in "previous" — fall back to it. Guard on the value type: String(Null)
	// yields the literal "null" here, so a bare Length(String(endTime)) check would misfire.
	var $src : Object:=$log
	If (Not:C34(This:C1470._hasEndTime($log)) && (Value type:C1509($log.previous)=Is object:K8:27))
		$src:=$log.previous
	End if

	return {\
		timestamp: This:C1470._hasEndTime($src) ? String:C10($src.endTime) : ""; \
		status: (Value type:C1509($src.status)=Is text:K8:3) ? String:C10($src.status) : ""; \
		error: $src.error}

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// True when $o carries a usable (non-empty Text) endTime — i.e. a completed run, not a
	// null/absent one. JSON null parses to a Null value, not Text, and must not count.
Function _hasEndTime($o : Object) : Boolean

	return (Value type:C1509($o.endTime)=Is text:K8:3) && (Length:C16(String:C10($o.endTime))>0)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns a read-only snapshot of the top-level run state (for status reporting).
Function status() : Object
	
	var $log : Object:=This:C1470._read()
	
	return {\
		startTime: $log.startTime; \
		endTime: $log.endTime; \
		status: $log.status; \
		trigger: $log.trigger; \
		error: $log.error; \
		nextComputeDate: $log.nextComputeDate}
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Takes the write semaphore. False when it could not be taken: the caller must skip its
	// write — and it is said out loud, because a dropped write means the history (and the
	// scheduler state rehydrated from it) is missing a run.
Function _acquire($context : Text) : Boolean
	
	If (Not:C34(Semaphore:C143(This:C1470._semaphoreName; This:C1470._semaphoreTimeout)))
		
		return True:C214
		
	End if 
	
	cs:C1710._Logger.me.warn("Execution log is busy: "+$context+" was not written (waited "+String:C10(This:C1470._semaphoreTimeout/60)+"s)")
	
	return False:C215
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _release()
	
	CLEAR SEMAPHORE:C144(This:C1470._semaphoreName)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _file() : 4D:C1709.File
	
	return Folder:C1567(fk logs folder:K87:17; *).file("embeddingHistory.json")
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _read() : Object
	
	var $file : 4D:C1709.File:=This:C1470._file()
	
	If (Not:C34($file.exists))
		return {}
	End if 
	
	var $parsed : Variant:=Try(JSON Parse:C1218($file.getText()))
	
	If (Value type:C1509($parsed)=Is object:K8:27)
		return $parsed
	End if 
	
	return {}
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _write($log : Object)
	
	This:C1470._file().setText(JSON Stringify:C1217($log; *))
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _extractTopLevel($log : Object) : Object
	
	return {\
		startTime: $log.startTime; \
		endTime: $log.endTime; \
		status: $log.status; \
		error: $log.error; \
		nextComputeDate: $log.nextComputeDate; \
		promptTokens: $log.promptTokens; \
		totalTokens: $log.totalTokens; \
		cumulativePromptTokens: $log.cumulativePromptTokens; \
		cumulativeTotalTokens: $log.cumulativeTotalTokens}
	
