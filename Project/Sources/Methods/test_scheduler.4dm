//%attributes = {}
// Unit tests for cs.Scheduler configuration resolution, next-run computation,
// status shape and cancel() wiring. Fast and self-contained: no data model and
// no background workers (a temporary settings file drives config()).
//
// The full end-to-end scheduling behaviour (start()/stop() with the real worker
// loop and timing) is covered by the integration method _scheduler_integration,
// which is deliberately NOT named test_@ so the unit harness ignores it.

var $prevFile : 4D:C1709.File:=cs:C1710._Settings.me.file  // save to restore afterwards
var $tmp : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_scheduler_cfg.json")

// The single-batch-guard section below calls _ExecutionLog.logSkipped(), which writes
// embeddingHistory.json — back it up so it can be restored in Cleanup.
var $execLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

cs:C1710._SchedulerState.me.endBatch(""; ""; "")  // reset runtime baseline

// ══════════════════════════════════════════════════════════════════════
// DISABLED
// ══════════════════════════════════════════════════════════════════════

$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "disabled"}}))
cs:C1710._Settings.me.file:=$tmp

ASSERT:C1129(cs:C1710.Scheduler.me.config().mode="disabled"; "config: expected disabled")
ASSERT:C1129(cs:C1710.Scheduler.me.nextRun()=Null:C1517; "disabled: nextRun should be Null")

var $status : Object:=cs:C1710.Scheduler.me.status()
ASSERT:C1129($status.enabled=False:C215; "disabled: status.enabled should be false")
ASSERT:C1129($status.nextRun=Null:C1517; "disabled: status.nextRun should be Null")

// ══════════════════════════════════════════════════════════════════════
// INTERVAL
// ══════════════════════════════════════════════════════════════════════

$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 2; startFrom: "reference"}}))

var $cfg : Object:=cs:C1710.Scheduler.me.config()
ASSERT:C1129($cfg.mode="interval"; "config: expected interval")
ASSERT:C1129($cfg.intervalHours=2; "config: expected intervalHours 2, got "+String:C10($cfg.intervalHours))
ASSERT:C1129($cfg.startFrom="reference"; "config: expected startFrom reference")

cs:C1710._SchedulerState.me.arm(cs:C1710._ScheduleCalc.me._nowISO())  // anchor for "start from now"
var $next : Object:=cs:C1710.Scheduler.me.nextRun()
ASSERT:C1129($next#Null:C1517; "interval: nextRun should not be null")
ASSERT:C1129($next.timestamp>cs:C1710._ScheduleCalc.me._nowISO(); "interval: nextRun should be in the future")

$status:=cs:C1710.Scheduler.me.status()
ASSERT:C1129($status.enabled=True:C214; "interval: status.enabled should be true")
ASSERT:C1129($status.nextRun#Null:C1517; "interval: status.nextRun should be present")

// Out-of-range interval hours fall back to the default (3).
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 99}}))
ASSERT:C1129(cs:C1710.Scheduler.me.config().intervalHours=3; "config: out-of-range hours should default to 3")

// Boundary interval hours (AC-4.2.3): 1 and 24 are accepted verbatim; 0 and 25 fall back
// to the default (3). Form-level validation errors and blocking persistence of out-of-range
// or non-integer input stay a manual UI check.
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 1}}))
ASSERT:C1129(cs:C1710.Scheduler.me.config().intervalHours=1; "config: 1 hour should be accepted")
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 24}}))
ASSERT:C1129(cs:C1710.Scheduler.me.config().intervalHours=24; "config: 24 hours should be accepted")
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 0}}))
ASSERT:C1129(cs:C1710.Scheduler.me.config().intervalHours=3; "config: 0 hours should fall back to the default 3")
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 25}}))
ASSERT:C1129(cs:C1710.Scheduler.me.config().intervalHours=3; "config: 25 hours should fall back to the default 3")

// ══════════════════════════════════════════════════════════════════════
// DAILY
// ══════════════════════════════════════════════════════════════════════

$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "daily"; dailyTime: "08:30"}}))
$cfg:=cs:C1710.Scheduler.me.config()
ASSERT:C1129($cfg.mode="daily"; "config: expected daily")
ASSERT:C1129($cfg.dailyTime="08:30"; "config: expected dailyTime 08:30")
ASSERT:C1129(Substring:C12(cs:C1710.Scheduler.me.nextRun().timestamp; 11)="T08:30:00"; "daily: nextRun should be at 08:30")

// ══════════════════════════════════════════════════════════════════════
// Scheduler.cancel() wiring -> shared state
// ══════════════════════════════════════════════════════════════════════

cs:C1710._SchedulerState.me.endBatch(""; ""; "")
ASSERT:C1129(cs:C1710._SchedulerState.me.cancelRequested=False:C215; "baseline cancel flag should be false")
cs:C1710.Scheduler.me.cancel()
ASSERT:C1129(cs:C1710._SchedulerState.me.cancelRequested=True:C214; "Scheduler.cancel() should set cancelRequested")

// ══════════════════════════════════════════════════════════════════════
// status() shape
// ══════════════════════════════════════════════════════════════════════

$status:=cs:C1710.Scheduler.me.status()
ASSERT:C1129(OB Is defined:C1231($status; "running"); "status should expose running")
ASSERT:C1129(OB Is defined:C1231($status; "lastResult"); "status should expose lastResult")
ASSERT:C1129(OB Is defined:C1231($status; "lastExecution"); "status should expose lastExecution")
ASSERT:C1129(OB Is defined:C1231($status; "batchStart"); "status should expose batchStart")
ASSERT:C1129(OB Is defined:C1231($status; "nextRun"); "status should expose nextRun")

// ══════════════════════════════════════════════════════════════════════
// Single-batch guard : skip a trigger fired while a batch is running/paused.
// A batch paused mid-run (e.g. inside cs.Embedder's rate-limit retry) is still "running"
// from the scheduler's point of view, so _SCHEDULER_RUN skips any trigger fired meanwhile.
// ══════════════════════════════════════════════════════════════════════

var $state:=cs:C1710._SchedulerState.me
$state.endBatch(""; ""; "")  // clean baseline

//MARK:- test_pro_noDupBatchWhileP
var $ts1 : Text:=cs:C1710._ScheduleCalc.me._nowISO()
ASSERT:C1129($state.beginBatch($ts1); "the first batch should be allowed to start")
ASSERT:C1129($state.running; "state should report running=true once a batch has started")

// A second scheduled trigger fires while the first is still running/paused — it must be skipped.
var $ts2 : Text:=cs:C1710._ScheduleCalc.me._nowISO()
ASSERT:C1129(Not:C34($state.beginBatch($ts2)); "a duplicate batch must not start while one is running/paused for rate limiting")

//MARK:- test_pro_histSkippedOnC
$execLog.logSkipped($ts2)
var $skipStatus : Object:=$execLog.status()
ASSERT:C1129($skipStatus.trigger="skipped"; "the skipped trigger should be logged, got "+String:C10($skipStatus.trigger))

var $skipLog : Object:=$execLog._read()
ASSERT:C1129($skipLog.trigger="skipped"; "expected trigger skipped, got "+String:C10($skipLog.trigger))
ASSERT:C1129(Value type:C1509($skipLog.skipped)=Is collection:K8:32; "skipped timestamps should be recorded as a collection")
ASSERT:C1129($skipLog.skipped.length>0; "skipped timestamps collection should not be empty")
ASSERT:C1129($skipLog.skipped[$skipLog.skipped.length-1]=$ts2; "the last skipped entry should be the skipped trigger's timestamp")

// The original (still-running/paused) batch is unaffected and can complete normally.
ASSERT:C1129($state.running; "the original batch should still be marked running after the duplicate was skipped")
$state.endBatch("completed"; ""; cs:C1710._ScheduleCalc.me._nowISO())

// ══════════════════════════════════════════════════════════════════════
// nextComputeDate persistence (config -> nextRun -> _ExecutionLog.setNextComputeDate)
//MARK:- test_pro_histNCDateCalc
// ══════════════════════════════════════════════════════════════════════

$state.endBatch(""; ""; "")  // reset runtime baseline
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 2; startFrom: "reference"}}))
cs:C1710._Settings.me.file:=$tmp
$state.arm(cs:C1710._ScheduleCalc.me._nowISO())  // anchor for "start from now"

var $expectedNext : Object:=cs:C1710.Scheduler.me.nextRun()
ASSERT:C1129($expectedNext#Null:C1517; "setup: nextRun should not be null for an interval schedule")
$execLog.setNextComputeDate($expectedNext.timestamp)
ASSERT:C1129($execLog._read().nextComputeDate=$expectedNext.timestamp; "nextComputeDate should match the schedule's computed next run")
ASSERT:C1129(cs:C1710.Scheduler.me.status().nextRun=$expectedNext.timestamp; "Scheduler.status().nextRun should match the persisted nextComputeDate")

// ══════════════════════════════════════════════════════════════════════
// status() VALUES ACROSS LIFECYCLE STATES (AC-5.5) — deterministic, no worker.
// The persisted history file is backed up at the top of this test and restored in
// Cleanup, so it is safe to clear it here to isolate the in-memory state. These assert
// the real status() field names: running / batchStart / lastResult / lastExecution / nextRun.
// ══════════════════════════════════════════════════════════════════════

If ($histFile.exists)
	$histFile.delete()
End if 
$state.endBatch(""; ""; "")  // reset: lastRun="", lastResult=""

//MARK:- never run yet → empty execution fields, but nextRun is already planned
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 2; startFrom: "reference"}}))
$state.arm(cs:C1710._ScheduleCalc.me._nowISO())
var $neverStatus : Object:=cs:C1710.Scheduler.me.status()
ASSERT:C1129($neverStatus.running=False:C215; "never run: running should be false")
ASSERT:C1129($neverStatus.batchStart=Null:C1517; "never run: batchStart should be Null")
ASSERT:C1129($neverStatus.lastExecution=Null:C1517; "never run: lastExecution should be Null")
ASSERT:C1129($neverStatus.lastResult=Null:C1517; "never run: lastResult should be Null")
ASSERT:C1129($neverStatus.nextRun#Null:C1517; "never run: an enabled schedule should still expose a nextRun")

//MARK:- running batch → running true, batchStart carries the start timestamp, lastResult "started"
var $batchStart : Text:=cs:C1710._ScheduleCalc.me._nowISO()
ASSERT:C1129($state.beginBatch($batchStart); "a batch should start from the reset state")
var $runningStatus : Object:=cs:C1710.Scheduler.me.status()
ASSERT:C1129($runningStatus.running=True:C214; "running: running should be true")
ASSERT:C1129($runningStatus.batchStart=$batchStart; "running: batchStart should be the batch start timestamp")
ASSERT:C1129($runningStatus.lastResult="started"; "running: lastResult should be 'started'")

//MARK:- a skipped trigger is reflected by status().lastResult
$state.markSkipped($batchStart)
ASSERT:C1129(cs:C1710.Scheduler.me.status().lastResult="skipped"; "skip: status.lastResult should be 'skipped'")
$state.endBatch("completed"; ""; cs:C1710._ScheduleCalc.me._nowISO())

//MARK:- disabled keeps a historical last execution but drops the next run
var $historical : Text:="2031-01-02T03:04:05"
$state.endBatch(""; ""; "")  // clear in-memory lastRun
$state.restore($historical; "completed"; "")  // as after a restart, rehydrated from persisted history
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "disabled"}}))
var $disabledStatus : Object:=cs:C1710.Scheduler.me.status()
ASSERT:C1129($disabledStatus.nextRun=Null:C1517; "disabled: nextRun should be Null")
ASSERT:C1129($disabledStatus.lastExecution=$historical; "disabled: a historical lastExecution should be preserved")

// ══════════════════════════════════════════════════════════════════════
// Cleanup
// ══════════════════════════════════════════════════════════════════════

cs:C1710._SchedulerState.me.endBatch(""; ""; "")
cs:C1710._Settings.me.file:=$prevFile
$tmp.delete()
If ($histExisted)
	$histFile.setText($histBackup)
Else
	If ($histFile.exists)
		$histFile.delete()
	End if
End if
