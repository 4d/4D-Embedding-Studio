//%attributes = {}
// Verify scheduled batch run does not start a duplicate batch while paused for rate limiting.
// A batch that is mid-run and paused inside cs.Embedder's retry/backoff loop is still
// "running" from the scheduler's point of view (endBatch() is only called once the whole
// Process.process() call returns). This directly exercises the single-batch guard
// (_SchedulerState.beginBatch / _ExecutionLog.logSkipped) that _SCHEDULER_RUN relies on
// to skip a trigger fired while a batch — paused for rate limiting or not — is running.

var $state:=cs:C1710._SchedulerState.me
var $execLog:=cs:C1710._ExecutionLog.me

// Clean baseline.
$state.endBatch(""; ""; "")

var $ts1 : Text:=cs:C1710._ScheduleCalc.me._nowISO()
ASSERT:C1129($state.beginBatch($ts1); "the first batch should be allowed to start")
ASSERT:C1129($state.running; "state should report running=true once a batch has started")

// Simulate the batch being paused mid-run for a rate limit retry: it is still
// "running" the whole time (no endBatch() call happens until the batch finishes).
// A second scheduled trigger fires in the meantime — it must be skipped, not start
// a duplicate batch, exactly what _SCHEDULER_RUN does before calling Process.process().
var $ts2 : Text:=cs:C1710._ScheduleCalc.me._nowISO()
ASSERT:C1129(Not:C34($state.beginBatch($ts2)); "a duplicate batch must not start while one is running/paused for rate limiting")
$execLog.logSkipped($ts2)

var $status : Object:=$execLog.status()
ASSERT:C1129($status.trigger="skipped"; "the skipped trigger should be logged, got "+String:C10($status.trigger))

// The original (still-running/paused) batch is unaffected and can complete normally.
ASSERT:C1129($state.running; "the original batch should still be marked running after the duplicate was skipped")

// Cleanup — release the batch slot and restore baseline.
$state.endBatch("completed"; ""; cs:C1710._ScheduleCalc.me._nowISO())
