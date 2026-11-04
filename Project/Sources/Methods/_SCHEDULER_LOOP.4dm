//%attributes = {"invisible":true}
/**
 Background loop for the embedding scheduler. Runs in worker "EmbeddingStudioScheduler".

 Each cycle re-reads the effective configuration (so config changes are picked up
 without a restart), computes the next run, and — when due and idle — atomically
 acquires the batch and fires the execution worker. A scheduled slot that elapses
 while a batch is running is skipped and logged for traceability (AC-4.1.2/4.1.4).
**/

var $scheduler : cs:C1710.Scheduler:=cs:C1710.Scheduler.me
var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
var $calc : cs:C1710._ScheduleCalc:=cs:C1710._ScheduleCalc.me

Repeat 
	
	var $sleep : Integer:=$state.checkInterval
	var $cfg : Object:=$scheduler.config()
	
	If ($cfg.mode#"never")
		
		var $nowStamp : Text:=$calc._nowISO()
		
		If ($state.running)
			
			// A batch is running (single-batch rule). Log any scheduled slot that
			// elapsed during the run, once (AC-4.1.4).
			var $missed : Text:=$calc.slotAfter($cfg; $state.batchStart)
			If ((Length:C16($missed)>0) && ($missed<=$nowStamp) && ($missed#$state.skipLoggedFor))
				cs:C1710._ExecutionLog.me.logSkipped($nowStamp)
				$state.markSkipped($missed)
			End if 
			
		Else 
			
			var $next : Object:=$scheduler.nextRun()
			
			If ($next#Null:C1517)
				
				If ($next.timestamp<=$nowStamp)
					
					// Due and idle — acquire atomically, then fire the execution worker.
					If ($state.beginBatch($nowStamp))
						CALL WORKER:C1389("EmbeddingStudio"; "_SCHEDULER_RUN"; True:C214)
					End if 
					
				Else 
					
					$sleep:=$calc.secondsUntil($next.timestamp)
					
				End if 
			End if 
		End if 
	End if 
	
	If ($sleep<1)
		$sleep:=1
	End if 
	
	If ($sleep>$state.checkInterval)
		$sleep:=$state.checkInterval
	End if 
	
	DELAY PROCESS:C323(Current process:C322; $sleep*60)  // $sleep is seconds; DELAY PROCESS takes ticks (1s=60)
	
Until (Not:C34($state.armed))

KILL WORKER:C1390
