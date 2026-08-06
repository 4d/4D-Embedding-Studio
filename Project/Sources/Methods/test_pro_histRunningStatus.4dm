//%attributes = {}
// Verify embeddingHistory.json reflects a 'running' status while a recalculation is
// in progress. cs.Process.process() (full run) calls cs._ExecutionLog.startFullRun()
// before doing any work and only calls endFullRun() once the whole run completes, so the
// file must show status "running" (and no endTime yet) for the whole in-between window.
// Exercised directly at the _ExecutionLog level for determinism (no real concurrent
// worker needed — same convention as test_pro_noDupBatchWhileP.4dm).

var $execLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

Try
	var $startTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
	$execLog.startFullRun($startTs)
	
	var $log : Object:=$execLog._read()
	ASSERT:C1129($log.status="running"; "expected status running during an in-progress recalculation, got "+String:C10($log.status))
	ASSERT:C1129($log.startTime=$startTs; "startTime should match the recorded start")
	ASSERT:C1129($log.endTime=Null:C1517; "endTime should not be set while still running")
	ASSERT:C1129($log.error=Null:C1517; "error should not be set while still running")
	
	// Complete the run so the on-disk state is left consistent for other tests.
	$execLog.endFullRun($startTs; cs:C1710._ScheduleCalc.me._nowISO(); "completed"; Null:C1517; Null:C1517; Null:C1517)
	
	var $log2 : Object:=$execLog._read()
	ASSERT:C1129($log2.status="completed"; "status should transition to completed once the run ends")
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
If ($histExisted)
	$histFile.setText($histBackup)
Else 
	If ($histFile.exists)
		$histFile.delete()
	End if 
End if 

