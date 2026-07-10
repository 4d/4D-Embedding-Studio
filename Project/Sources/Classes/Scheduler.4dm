/**
 Public entry point for the automated embedding recalculation scheduler.

 Usage (from a host database, e.g. its On Server Startup method):
   cs.EmbeddingStudio.Scheduler.me.start()    // arm the background scheduler
   cs.EmbeddingStudio.Scheduler.me.stop()     // disarm (a running batch keeps finishing)
   cs.EmbeddingStudio.Scheduler.me.cancel()   // cooperative cancel of the running batch
   cs.EmbeddingStudio.Scheduler.me.force()    // force a recalculation now (skipped if one runs)
   cs.EmbeddingStudio.Scheduler.me.status()   // runtime status object
   cs.EmbeddingStudio.Scheduler.me.reload()   // no-op: config is re-read on each loop cycle

 The scheduler config lives under the "scheduler" key of Settings/embeddings.json:
   { "mode": "disabled|interval|daily",
     "intervalHours": 1..24,           // interval mode
     "startFrom": "now|lastExecution", // interval mode
     "dailyTime": "HH:MM" }            // daily mode

 Concurrency: at most one recalculation batch runs at a time (AC-4.1.1). A trigger
 fired while a batch is running is skipped and logged (AC-4.1.2/4.1.4).
**/

property _loopWorker : Text:="EmbeddingStudioScheduler"
property _execWorker : Text:="EmbeddingStudio"

singleton Class constructor
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Arms the scheduler: starts the background loop worker if not already running.
	// Idempotent — calling it again just refreshes the "start from now" anchor.
Function start() : Boolean
	
	cs:C1710._SchedulerState.me.arm(cs:C1710._ScheduleCalc.me._nowISO())
	
	If (Not:C34(This:C1470._loopRunning()))
		CALL WORKER:C1389(This:C1470._loopWorker; "_SCHEDULER_LOOP")
	End if 
	
	return True:C214
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Disarms the scheduler. The loop worker stops; a running batch keeps finishing.
Function stop()
	
	cs:C1710._SchedulerState.me.disarm()
	
	If (This:C1470._loopRunning())
		KILL WORKER:C1390(This:C1470._loopWorker)
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Requests a cooperative cancel of the running batch (never force-kills).
Function cancel()
	
	cs:C1710._SchedulerState.me.requestCancel()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Forces a recalculation now. Honors the single-batch rule: skipped if one is running (AC-6.5).
Function force() : Object
	
	CALL WORKER:C1389(This:C1470._execWorker; "_SCHEDULER_RUN"; False:C215)
	
	return This:C1470.status()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Config is re-read by the loop on each cycle; nothing to do beyond returning status.
Function reload() : Object
	
	return This:C1470.status()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the effective scheduler configuration with defaults applied.
Function config() : Object
	
	var $raw : Variant:=cs:C1710._Settings.me.get()
	var $sched : Object:=(($raw#Null:C1517) && (Value type:C1509($raw.scheduler)=Is object:K8:27)) ? $raw.scheduler : {}
	
	var $mode : Text:=String:C10($sched.mode)
	If (($mode#"interval") && ($mode#"daily"))
		$mode:="disabled"
	End if 
	
	var $hours : Integer:=Num:C11($sched.intervalHours)
	If (($hours<1) || ($hours>24))
		$hours:=3
	End if 
	
	return {\
		mode: $mode; \
		intervalHours: $hours; \
		startFrom: (String:C10($sched.startFrom)="lastExecution") ? "lastExecution" : "now"; \
		dailyTime: (Length:C16(String:C10($sched.dailyTime))>0) ? String:C10($sched.dailyTime) : "00:00"}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Computes the next scheduled run, or Null when disabled.
Function nextRun() : Object
	
	var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
	return cs:C1710._ScheduleCalc.me.nextRun(This:C1470.config(); $state.lastRun; $state.armedAt)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the current scheduler status (AC-5.5).
Function status() : Object
	
	var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
	var $log : Object:=cs:C1710._ExecutionLog.me.status()
	var $cfg : Object:=This:C1470.config()
	var $next : Object:=($cfg.mode="disabled") ? Null:C1517 : This:C1470.nextRun()
	
	return {\
		enabled: ($cfg.mode#"disabled"); \
		mode: $cfg.mode; \
		armed: $state.armed; \
		running: $state.running; \
		batchStart: (Length:C16($state.batchStart)>0) ? $state.batchStart : Null:C1517; \
		lastExecution: (Length:C16($state.lastRun)>0) ? $state.lastRun : Null:C1517; \
		nextRun: ($next#Null:C1517) ? $next.timestamp : Null:C1517; \
		lastResult: (Length:C16($state.lastResult)>0) ? $state.lastResult : Null:C1517; \
		error: (Length:C16($state.lastError)>0) ? $state.lastError : $log.error}
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// True when the background loop worker currently exists.
Function _loopRunning() : Boolean
	
	var $activity : Object:=Process activity:C1495(Processes only:K5:35)
	return ($activity.processes.findIndex(Formula:C1597($1.value.name=$2); This:C1470._loopWorker)#-1)
