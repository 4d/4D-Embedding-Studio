//%attributes = {}
// Verify embeddingHistory.json file integrity after an abrupt process interruption.
// Each write is a single, complete JSON.Stringify() overwrite of the whole state (never an
// incremental/partial append), so: (1) a run that starts but never finishes (crash before
// endFullRun) still leaves a fully valid, parseable file reflecting the "running" state,
// and (2) even if the file content itself were to become corrupted/truncated on disk,
// cs._ExecutionLog._read() must degrade gracefully (return {}) instead of throwing, so the
// app can always restart and resume normally.

var $execLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

Try
	// --- Scenario 1: interrupted mid-run (startFullRun called, endFullRun never called) ---
	var $startTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
	$execLog.startFullRun($startTs)
	
	var $rawText : Text:=$histFile.getText()
	var $parsed : Variant:=JSON Parse:C1218($rawText)  // must not throw: file must be valid, complete JSON
	ASSERT:C1129(Value type:C1509($parsed)=Is object:K8:27; "interrupted run: file must still contain a valid JSON object")
	ASSERT:C1129($parsed.status="running"; "interrupted run: status should still read running")
	
	// --- Recovery: the app can "restart" and start a fresh full run normally ---
	var $restartTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
	$execLog.startFullRun($restartTs)
	var $log : Object:=$execLog._read()
	ASSERT:C1129($log.status="running"; "recovery: a fresh startFullRun after an interruption should work normally")
	ASSERT:C1129($log.startTime=$restartTs; "recovery: startTime should reflect the new run")
	$execLog.endFullRun($restartTs; cs:C1710._ScheduleCalc.me._nowISO(); "completed"; Null:C1517; Null:C1517; Null:C1517)
	
	// --- Scenario 2: on-disk corruption (e.g. truncated write during a crash) ---
	$histFile.setText("{\"status\":\"running\", \"startTime\":")  // deliberately truncated/invalid JSON
	var $recovered : Object:=$execLog._read()
	ASSERT:C1129(Value type:C1509($recovered)=Is object:K8:27; "_read() must return an object even when the file is corrupted")
	ASSERT:C1129($recovered.status=Null:C1517; "_read() should not surface stale/garbage fields from a corrupted file")
	
	// The app must still be able to write a fresh, valid entry after a corrupted file was found.
	var $recoverTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
	$execLog.startFullRun($recoverTs)
	$execLog.endFullRun($recoverTs; cs:C1710._ScheduleCalc.me._nowISO(); "completed"; Null:C1517; Null:C1517; Null:C1517)
	var $final : Object:=$execLog._read()
	ASSERT:C1129($final.status="completed"; "the file should be fully healthy again after the next successful run")
	
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

