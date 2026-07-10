//%attributes = {"invisible":true}
/**
 Executes one embedding recalculation batch. Runs in worker "EmbeddingStudio".

 $preAcquired : True when the caller (the scheduler loop) already acquired the batch
                via _SchedulerState.beginBatch(); False for direct callers (force()),
                which acquire it here.

 Enforces the single-batch rule (AC-4.1.1): if a batch is already running the call
 is skipped and logged. The run is cancellable cooperatively via the shared state
 (Scheduler.cancel()), which Process checks between chunks.
**/

#DECLARE($preAcquired : Boolean)

var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
var $execLog : cs:C1710._ExecutionLog:=cs:C1710._ExecutionLog.me
var $startStamp : Text:=cs:C1710._ScheduleCalc.me._nowISO()

// Single-batch guard — acquire unless the loop already did.
If (Not:C34($preAcquired))
	If (Not:C34($state.beginBatch($startStamp)))
		$execLog.logSkipped($startStamp)
		KILL WORKER:C1390  // free the worker on the skip path too
		return 
	End if 
End if 

var $result : Text:="completed"
var $errorText : Text:=""

Try
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new()
	var $options : Object:={\
		shouldCancel: Formula:C1597(cs:C1710._SchedulerState.me.cancelRequested)}
	
	var $process : cs:C1710.Process:=cs:C1710.Process.new($settings; $options)
	var $report : cs:C1710.ProcessResult:=$process.process()
	
	If (Not:C34($report.success))
		$result:="failed"
		If ($report.errors.length>0)
			$errorText:=$report.errors.map(Formula:C1597(String:C10($1.value.message))).join("; ")
		End if 
	End if 
	
Catch
	
	$result:="failed"
	$errorText:=String:C10(Last errors:C1799[0].message)
	cs:C1710._Logger.me.error("Scheduler run failed: "+$errorText)
	
End try

var $endStamp : Text:=cs:C1710._ScheduleCalc.me._nowISO()
$state.endBatch($result; $errorText; $endStamp)

// Persist the computed next run in the history (AC-6.3 / AC-5.5.2).
var $next : Object:=cs:C1710.Scheduler.me.nextRun()
$execLog.setNextComputeDate(($next#Null:C1517) ? $next.timestamp : "")

// Free the shared execution worker after the run (same convention as _runInWorker).
KILL WORKER:C1390
