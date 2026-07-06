property _semaphoreName : Text:="4DES_ExecutionLog"

singleton Class constructor
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Sets top-level to "running", saving current top-level as "previous".
Function startFullRun($startTimestamp : Text)
	
	If (Not:C34(Semaphore:C143(This:C1470._semaphoreName; 300)))
		
		Try
			
			var $log : Object:=This:C1470._read()
			
			If (Length:C16(String:C10($log.startTime))>0)
				$log.previous:=This:C1470._extractTopLevel($log)
			End if 
			
			$log.startTime:=$startTimestamp
			$log.endTime:=Null:C1517
			$log.status:="running"
			$log.error:=Null:C1517
			$log.nextComputeDate:=Null:C1517
			This:C1470._write($log)
			
		Catch
			cs:C1710._Logger.me.error("Execution log write failed: "+String:C10(Last errors:C1799[0].message))
		End try
		
		CLEAR SEMAPHORE:C144(This:C1470._semaphoreName)
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Finalizes top-level with completed/failed status.
Function endFullRun($startTimestamp : Text; $endTimestamp : Text; $status : Text; $error : Variant; $nextComputeDate : Variant; $usage : Object)
	
	If (Not:C34(Semaphore:C143(This:C1470._semaphoreName; 300)))
		
		Try
			
			var $log : Object:=This:C1470._read()
			$log.startTime:=$startTimestamp
			$log.endTime:=$endTimestamp
			$log.status:=$status
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
		
		CLEAR SEMAPHORE:C144(This:C1470._semaphoreName)
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Updates one definition entry, saving its current state as "previous".
Function updateDefinition($defKey : Text; $startTime : Text; $endTime : Text; $status : Text; $error : Variant; $usage : Object)
	
	If (Not:C34(Semaphore:C143(This:C1470._semaphoreName; 300)))
		
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
		
		CLEAR SEMAPHORE:C144(This:C1470._semaphoreName)
		
	End if 
	
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
	
