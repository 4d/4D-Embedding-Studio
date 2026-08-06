//%attributes = {}
// Verify embeddingHistory.json is updated to reflect a skipped trigger when a
// recalculation batch is skipped due to a concurrent run already in progress.
// NOTE: the implementation records this via the top-level "trigger" field (set to
// "skipped" by cs._ExecutionLog.logSkipped()), not a "status" field — "status" only
// ever takes "running"/"completed"/"failed" (set by startFullRun/endFullRun). This test
// asserts the actual persisted field/value; see also test_pro_noDupBatchWhileP.4dm which
// covers the scheduler single-batch guard itself.

var $execLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

var $state:=cs:C1710._SchedulerState.me

Try
	// Clean baseline.
	$state.endBatch(""; ""; "")
	
	var $ts1 : Text:=cs:C1710._ScheduleCalc.me._nowISO()
	ASSERT:C1129($state.beginBatch($ts1); "the first batch should be allowed to start")
	
	// A second trigger fires while the first is still running — must be skipped.
	var $ts2 : Text:=cs:C1710._ScheduleCalc.me._nowISO()
	ASSERT:C1129(Not:C34($state.beginBatch($ts2)); "a duplicate batch must not start while one is running")
	$execLog.logSkipped($ts2)
	
	var $log : Object:=$execLog._read()
	ASSERT:C1129($log.trigger="skipped"; "expected trigger skipped, got "+String:C10($log.trigger))
	ASSERT:C1129(Value type:C1509($log.skipped)=Is collection:K8:32; "skipped timestamps should be recorded as a collection")
	ASSERT:C1129($log.skipped.length>0; "skipped timestamps collection should not be empty")
	ASSERT:C1129($log.skipped[$log.skipped.length-1]=$ts2; "the last skipped entry should be the skipped trigger's timestamp")
	
	$state.endBatch("completed"; ""; cs:C1710._ScheduleCalc.me._nowISO())
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
$state.endBatch(""; ""; "")
If ($histExisted)
	$histFile.setText($histBackup)
Else 
	If ($histFile.exists)
		$histFile.delete()
	End if 
End if 

