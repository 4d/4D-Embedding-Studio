/**
 Shared runtime state for the embedding scheduler.

 Holds cross-process flags used by the scheduler loop worker, the execution
 worker and the public Scheduler API. All writes go through Use(This) so the
 state stays consistent across processes.

 lastResult follows AC-5.5.5: "started" | "skipped" | "completed" | "failed".
**/

property armed : Boolean:=False:C215
property armedAt : Text:=""  // local ISO, anchor for interval "start from now"
property running : Boolean:=False:C215
property batchStart : Text:=""  // local ISO of the current running batch
property lastRun : Text:=""  // local ISO of the last completed run
property lastResult : Text:=""  // started | skipped | completed | failed
property lastError : Text:=""
property cancelRequested : Boolean:=False:C215
property skipLoggedFor : Text:=""  // dedupe key for skipped-trigger logging
property checkInterval : Integer:=60  // loop sleep cap, in seconds

shared singleton Class constructor
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Marks the scheduler as armed and records the anchor time for "start from now".
Function arm($anchor : Text)
	
	Use (This:C1470)
		This:C1470.armed:=True:C214
		This:C1470.armedAt:=String:C10($anchor)
	End use 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Marks the scheduler as disarmed (loop stopped).
Function disarm()
	
	Use (This:C1470)
		This:C1470.armed:=False:C215
		This:C1470.cancelRequested:=False:C215
	End use 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Marks a batch as started. Returns False if one is already running (guards double-run).
Function beginBatch($startTimestamp : Text) : Boolean
	
	var $started : Boolean:=False:C215
	
	Use (This:C1470)
		If (Not:C34(This:C1470.running))
			This:C1470.running:=True:C214
			This:C1470.batchStart:=String:C10($startTimestamp)
			This:C1470.cancelRequested:=False:C215
			This:C1470.lastResult:="started"
			This:C1470.lastError:=""
			$started:=True:C214
		End if 
	End use 
	
	return $started
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Marks the current batch as finished with the given result and updates lastRun.
Function endBatch($result : Text; $error : Text; $endTimestamp : Text)
	
	Use (This:C1470)
		This:C1470.running:=False:C215
		This:C1470.batchStart:=""
		This:C1470.cancelRequested:=False:C215
		This:C1470.lastResult:=String:C10($result)
		This:C1470.lastError:=String:C10($error)
		This:C1470.lastRun:=String:C10($endTimestamp)
	End use 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Requests a cooperative cancel of the running batch.
Function requestCancel()
	
	Use (This:C1470)
		This:C1470.cancelRequested:=True:C214
	End use 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Records that a due trigger was skipped (dedup per next-run key).
Function markSkipped($key : Text)
	
	Use (This:C1470)
		This:C1470.lastResult:="skipped"
		This:C1470.skipLoggedFor:=String:C10($key)
	End use 
