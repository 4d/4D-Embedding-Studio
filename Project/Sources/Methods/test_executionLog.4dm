//%attributes = {}
// Unit tests for cs._ExecutionLog, including what happens when its write semaphore
// cannot be taken (the history is what the scheduler rehydrates its state from).

var $execLog : cs:C1710._ExecutionLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

If ($histFile.exists)
	$histFile.delete()
End if 

// ══════════════════════════════════════════════════════════════════════
// NORMAL WRITES
// ══════════════════════════════════════════════════════════════════════

//MARK:- full run round-trip
$execLog.startFullRun("2026-01-01T00:00:00")
ASSERT:C1129($execLog.status().status="running"; "startFullRun: status should be running")

$execLog.endFullRun("2026-01-01T00:00:00"; "2026-01-01T00:00:10"; "completed"; Null:C1517; Null:C1517; Null:C1517)
ASSERT:C1129($execLog.status().status="completed"; "endFullRun: status should be completed")
ASSERT:C1129($execLog.lastRun().timestamp="2026-01-01T00:00:10"; "endFullRun: lastRun should be the end timestamp")

//MARK:- while a run is in progress, lastRun() is the previous completed run
$execLog.startFullRun("2026-01-01T01:00:00")
var $inProgress : Object:=$execLog.lastRun()
ASSERT:C1129($inProgress.timestamp="2026-01-01T00:00:10"; "in progress: lastRun should fall back to the previous run, got '"+String:C10($inProgress.timestamp)+"'")
ASSERT:C1129($inProgress.status="completed"; "in progress: lastRun status should be the previous one, got '"+String:C10($inProgress.status)+"'")

$execLog.endFullRun("2026-01-01T01:00:00"; "2026-01-01T01:00:05"; "completed"; Null:C1517; Null:C1517; Null:C1517)
ASSERT:C1129($execLog.lastRun().timestamp="2026-01-01T01:00:05"; "after the run: lastRun should be the new end timestamp")

//MARK:- skipped triggers are capped to the 50 most recent
var $k : Integer
For ($k; 1; 55)
	$execLog.logSkipped("2026-01-01T02:00:"+String:C10($k; "00"))
End for
var $skipped : Collection:=$execLog._read().skipped
ASSERT:C1129($skipped.length=50; "skipped cap: expected 50 entries, got "+String:C10($skipped.length))
ASSERT:C1129($skipped[0]="2026-01-01T02:00:06"; "skipped cap: the oldest entries should be dropped first, got "+String:C10($skipped[0]))
ASSERT:C1129($skipped[49]="2026-01-01T02:00:55"; "skipped cap: the newest entry should be last, got "+String:C10($skipped[49]))

//MARK:- next compute date
$execLog.setNextComputeDate("2026-01-02T03:00:00")
ASSERT:C1129($execLog.status().nextComputeDate="2026-01-02T03:00:00"; "setNextComputeDate: value should be stored")

// ══════════════════════════════════════════════════════════════════════
// SEMAPHORE TIMEOUT — the write is skipped, and it is said out loud
// ══════════════════════════════════════════════════════════════════════

//MARK:- a dropped write is warned about
var $capture : Collection:=[]
cs:C1710._Logger.me._capture:=$capture

CALL WORKER:C1389("_testExecLogHolder"; "_testHoldSemaphore"; $execLog._semaphoreName; 4)
DELAY PROCESS:C323(Current process:C322; 60)  // let the worker take it

var $start : Integer:=Milliseconds:C459
$execLog.setNextComputeDate("2026-06-15T12:00:00")
var $elapsed : Integer:=Milliseconds:C459-$start

cs:C1710._Logger.me._capture:=Null:C1517

ASSERT:C1129($execLog.status().nextComputeDate="2026-01-02T03:00:00"; "semaphore timeout: the previous value should still be there (write skipped)")
ASSERT:C1129($elapsed<(($execLog._semaphoreTimeout/60*1000)+2000); "semaphore timeout: the caller should not wait much beyond the timeout, waited "+String:C10($elapsed)+" ms")

var $warnings : Collection:=$capture.query("level = :1"; Warning message:K38:2)
ASSERT:C1129($warnings.length>0; "semaphore timeout: a warning should be logged")
ASSERT:C1129(Position:C15("setNextComputeDate"; $warnings.last().message)>0; "semaphore timeout: the warning should name the skipped write, got '"+String:C10($warnings.last().message)+"'")

// ══════════════════════════════════════════════════════════════════════
// CLEANUP
// ══════════════════════════════════════════════════════════════════════

KILL WORKER:C1390("_testExecLogHolder")

If ($histExisted)
	$histFile.setText($histBackup)
Else 
	If ($histFile.exists)
		$histFile.delete()
	End if 
End if 
