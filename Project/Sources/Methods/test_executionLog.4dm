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
