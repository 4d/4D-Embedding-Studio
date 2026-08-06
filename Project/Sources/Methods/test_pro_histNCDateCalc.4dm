//%attributes = {}
// Verify embeddingHistory.json nextComputeDate is correctly calculated based on the
// schedule configuration. _SCHEDULER_RUN persists it via
// cs._ExecutionLog.setNextComputeDate(cs.Scheduler.me.nextRun().timestamp) after each run;
// this test drives the same config -> nextRun -> setNextComputeDate path directly.

var $execLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

var $prevSettingsFile : 4D:C1709.File:=cs:C1710._Settings.me.file
var $tmp : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_hist_nextcompute_cfg.json")

var $state:=cs:C1710._SchedulerState.me

Try
	$state.endBatch(""; ""; "")  // reset runtime baseline
	
	$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 2; startFrom: "now"}}))
	cs:C1710._Settings.me.file:=$tmp
	
	$state.arm(cs:C1710._ScheduleCalc.me._nowISO())  // anchor for "start from now"
	
	var $expected : Object:=cs:C1710.Scheduler.me.nextRun()
	ASSERT:C1129($expected#Null:C1517; "setup: nextRun should not be null for an interval schedule")
	
	$execLog.setNextComputeDate($expected.timestamp)
	
	var $log : Object:=$execLog._read()
	ASSERT:C1129($log.nextComputeDate=$expected.timestamp; "nextComputeDate should match the schedule's computed next run, expected "+$expected.timestamp+" got "+String:C10($log.nextComputeDate))
	
	var $status : Object:=cs:C1710.Scheduler.me.status()
	ASSERT:C1129($status.nextRun=$expected.timestamp; "Scheduler.status().nextRun should match the persisted nextComputeDate")
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
cs:C1710._Settings.me.file:=$prevSettingsFile
$state.endBatch(""; ""; "")
If ($tmp.exists)
	$tmp.delete()
End if 
If ($histExisted)
	$histFile.setText($histBackup)
Else 
	If ($histFile.exists)
		$histFile.delete()
	End if 
End if 

