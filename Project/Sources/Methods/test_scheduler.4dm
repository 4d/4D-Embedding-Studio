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

$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "interval"; intervalHours: 2; startFrom: "now"}}))

var $cfg : Object:=cs:C1710.Scheduler.me.config()
ASSERT:C1129($cfg.mode="interval"; "config: expected interval")
ASSERT:C1129($cfg.intervalHours=2; "config: expected intervalHours 2, got "+String:C10($cfg.intervalHours))
ASSERT:C1129($cfg.startFrom="now"; "config: expected startFrom now")

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
// Cleanup
// ══════════════════════════════════════════════════════════════════════

cs:C1710._SchedulerState.me.endBatch(""; ""; "")
cs:C1710._Settings.me.file:=$prevFile
$tmp.delete()
