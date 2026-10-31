/**
 Public entry point for the automated embedding recalculation scheduler.

 Usage (from a host database, e.g. its On Server Startup method):
   cs.EmbeddingStudio.Scheduler.me.start()    // arm the background scheduler
   cs.EmbeddingStudio.Scheduler.me.stop()     // disarm (a running batch keeps finishing)
   cs.EmbeddingStudio.Scheduler.me.cancel()   // cooperative cancel of the running batch
   cs.EmbeddingStudio.Scheduler.me.force()    // force a recalculation now (skipped if one runs)
   cs.EmbeddingStudio.Scheduler.me.status()   // runtime status object
   cs.EmbeddingStudio.Scheduler.me.reload()   // no-op: config is re-read on each loop cycle
   cs.EmbeddingStudio.Scheduler.me.isStarted() // True when the background loop is alive
   cs.EmbeddingStudio.Scheduler.me.autoStart() // True when the host arms us through On Host Database Event

 The scheduler config lives under the "scheduler" key of Settings/embeddings.json:
   { "mode": "disabled|interval|daily",
     "intervalHours": 1..24,                    // interval mode
     "startFrom": "reference|lastExecution",    // interval mode
     "startReference": "YYYY-MM-DDThh:mm:ss",   // interval, anchor for startFrom "reference"
     "dailyTime": "HH:MM" }                     // daily mode

 Concurrency: at most one recalculation batch runs at a time (AC-4.1.1). A trigger
 fired while a batch is running is skipped and logged (AC-4.1.2/4.1.4).
**/

property _loopWorker : Text:="EmbeddingStudioScheduler"
property _execWorker : Text:="EmbeddingStudio"

// Where 4D stores the "Execute 'On Host Database Event' method of the components"
// option of the Settings > Security page.
property _hostSettings : Text:="/SOURCES/settings.4DSettings"
property _hostEventPath : Text:="/preferences/com.4d/general"
property _hostEventName : Text:="execute_host_database_event"

shared singleton Class constructor
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Arms the scheduler: starts the background loop worker if not already running.
	// Idempotent — calling it again just refreshes the arm-time anchor, which interval mode
	// only falls back to when the config carries no startReference.
server Function start() : Boolean
	
	// Rehydrate the last-run info persisted by the previous process before arming. The
	// in-memory state is empty after a restart; without this an interval "lastExecution"
	// schedule fires immediately and a daily one double-fires today's slot (AC-4.2.6), and
	// status() reports "never run". No-op once an in-session run exists (restore guards it).
	var $persisted : Object:=cs:C1710._ExecutionLog.me.lastRun()
	var $terminal : Boolean:=($persisted.status="completed") || ($persisted.status="failed")
	var $error : Text:=(($terminal) && (Value type:C1509($persisted.error)=Is text:K8:3)) ? String:C10($persisted.error) : ""
	cs:C1710._SchedulerState.me.restore($persisted.timestamp; ($terminal ? $persisted.status : ""); $error)

	If (Not:C34(cs:C1710._AIKit.me.isAvailable))
		cs:C1710._Logger.me.error("Scheduler: "+cs:C1710._AIKit.me.missingReason)  // Every run will fail its definitions until 4D AIKit is loaded
	End if 
	
	cs:C1710._SchedulerState.me.arm(cs:C1710._ScheduleCalc.me._nowISO())
	
	If (Not:C34(This:C1470.isStarted()))
		CALL WORKER:C1389(This:C1470._loopWorker; "_SCHEDULER_LOOP")
	End if 
	
	return True:C214
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Disarms the scheduler. The loop worker stops; a running batch keeps finishing.
server Function stop()
	
	cs:C1710._SchedulerState.me.disarm()
	
	var $process : Integer:=This:C1470._loopProcess()
	If ($process>0)
		
		KILL WORKER:C1390(This:C1470._loopWorker)
		
		// The loop only re-reads "armed" when its sleep ends, and KILL WORKER waits for the
		// current task — the whole loop method — to end. Cancelling the pending delay (0 ticks)
		// wakes it now, so stop() takes effect immediately instead of up to checkInterval later.
		DELAY PROCESS:C323($process; 0)
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Requests a cooperative cancel of the running batch (never force-kills).
server Function cancel()
	
	cs:C1710._SchedulerState.me.requestCancel()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Forces a recalculation now. Honors the single-batch rule: skipped if one is running (AC-6.5).
server Function force() : Object
	
	CALL WORKER:C1389(This:C1470._execWorker; "_SCHEDULER_RUN"; False:C215)
	
	return This:C1470.status()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Config is re-read by the loop on each cycle; nothing to do beyond returning status.
server Function reload() : Object
	
	return This:C1470.status()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the effective scheduler configuration with defaults applied.
Function config() : Object
	
	var $raw : Variant:=cs:C1710._Settings.me.get()
	var $sched : Object:=(($raw#Null:C1517) && (Value type:C1509($raw.scheduler)=Is object:K8:27)) ? $raw.scheduler : {}

	return This:C1470._normalize($sched)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Validates and persists a scheduler configuration, then returns the normalized value.
	// Only the "scheduler" key is written; _Settings.set merges, preserving other keys.
Function saveConfig($cfg : Object) : Object

	var $normalized : Object:=This:C1470._normalize($cfg)

	cs:C1710._Settings.me.set({scheduler: $normalized})

	return $normalized

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Computes the next scheduled run, or Null when disabled.
Function nextRun() : Object
	
	var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
	return cs:C1710._ScheduleCalc.me.nextRun(This:C1470.config(); This:C1470._effectiveLastRun(); $state.armedAt)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// The effective "last run" anchor for scheduling: the in-memory value when present, else the
	// one persisted in the execution history (which survives a restart and is what status() shows
	// as lastExecution). Keeps nextRun() consistent with the displayed last execution — so after a
	// restart, daily advances to tomorrow and interval "lastExecution" counts from the real last
	// run, instead of both anchoring on an empty value (today's passed slot / an immediate run).
Function _effectiveLastRun() : Text

	var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
	If (Length:C16($state.lastRun)>0)
		return $state.lastRun
	End if

	return String:C10(cs:C1710._ExecutionLog.me.lastRun().timestamp)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the current scheduler status (AC-5.5).
server Function status() : Object
	
	var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
	var $persisted : Object:=cs:C1710._ExecutionLog.me.lastRun()
	var $cfg : Object:=This:C1470.config()
	var $next : Object:=($cfg.mode="disabled") ? Null:C1517 : This:C1470.nextRun()

	return {\
		enabled: ($cfg.mode#"disabled"); \
		mode: $cfg.mode; \
		armed: $state.armed; \
		running: $state.running; \
		batchStart: (Length:C16($state.batchStart)>0) ? $state.batchStart : Null:C1517; \
		lastExecution: (Length:C16($state.lastRun)>0) ? $state.lastRun : ((Length:C16(String:C10($persisted.timestamp))>0) ? $persisted.timestamp : Null:C1517); \
		lastRunBeforeRestart: $state.lastRunRestored || ((Length:C16($state.lastRun)=0) && (Length:C16(String:C10($persisted.timestamp))>0)); \
		nextRun: ($next#Null:C1517) ? $next.timestamp : Null:C1517; \
		lastResult: (Length:C16($state.lastResult)>0) ? $state.lastResult : Null:C1517; \
		error: (Length:C16($state.lastError)>0) ? $state.lastError : $persisted.error; \
		started: This:C1470.isStarted(); \
		autoStart: This:C1470.autoStart()}
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when the background loop worker is alive, i.e. the scheduler really runs.
Function isStarted() : Boolean
	
	return (This:C1470._loopProcess()>0)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when the host database authorizes the component "On Host Database Event" method
	// (Settings > Security), in which case the scheduler arms and disarms itself with the host.
	// False means the host is responsible for calling start() and stop().
Function autoStart() : Boolean
	
	// the * targets the host structure settings, the only place the option can be set
	return Bool:C1537(This:C1470._hostEventSetting(File:C1566(This:C1470._hostSettings; *)))
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Process number of the background loop worker, 0 when it does not run. On a remote client the
	// snapshot only lists the client's own processes, so a loop armed on the server reads as absent.
Function _loopProcess() : Integer

	var $activity : Object:=Process activity:C1495(Processes only:K5:35)
	var $index : Integer:=$activity.processes.findIndex(Formula:C1597($1.value.name=$2); This:C1470._loopWorker)

	return ($index#-1) ? Num:C11($activity.processes[$index].number) : 0

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Applies defaults and clamping to a raw scheduler config object. Shared by config() (read)
	// and saveConfig() (write) so the stored shape and the effective shape always agree.
Function _normalize($sched : Object) : Object

	If (Value type:C1509($sched)#Is object:K8:27)
		$sched:={}
	End if

	var $mode : Text:=String:C10($sched.mode)
	If (($mode#"interval") && ($mode#"daily"))
		$mode:="disabled"
	End if

	var $hours : Integer:=Num:C11($sched.intervalHours)
	If (($hours<1) || ($hours>24))
		$hours:=3
	End if

	// HH:MM, 00:00..23:59; anything malformed falls back to midnight
	var $daily : Text:=String:C10($sched.dailyTime)
	If (Not:C34(Bool:C1537(Match regex:C1019("^([01]\\d|2[0-3]):[0-5]\\d$"; $daily; 1))))
		$daily:="00:00"
	End if

	// "lastExecution" counts from the last completed run; anything else (incl. the legacy "now")
	// counts from the fixed startReference instant captured when the user chose "now".
	var $startFrom : Text:=(String:C10($sched.startFrom)="lastExecution") ? "lastExecution" : "reference"

	return {\
		mode: $mode; \
		intervalHours: $hours; \
		startFrom: $startFrom; \
		startReference: String:C10($sched.startReference); \
		dailyTime: $daily}

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Reads the "execute_host_database_event" attribute of the settings.4DSettings file.
	// Returns Null when the file is missing, is not readable XML, or does not carry the attribute.
Function _hostEventSetting($file : 4D:C1709.File) : Variant
	
	If (($file=Null:C1517) || (Not:C34($file.exists)))
		return Null:C1517
	End if 
	
	var $xml : Text:=String:C10(Try($file.getText()))
	If (Length:C16($xml)=0)
		return Null:C1517
	End if 
	
	// on a malformed document the parser returns a null reference and sets OK to 0
	var $root : Text:=String:C10(Try(DOM Parse XML variable:C720($xml)))
	If ((OK=0) || (Length:C16($root)=0))
		return Null:C1517
	End if 
	
	var $value : Variant:=Try(This:C1470._hostEventAttribute($root))
	DOM CLOSE XML:C722($root)
	
	return (Value type:C1509($value)=Is boolean:K8:9) ? $value : Null:C1517
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Attribute lookup inside an already parsed settings document, Null when not declared.
Function _hostEventAttribute($root : Text) : Variant
	
	var $element : Text:=String:C10(Try(DOM Find XML element:C864($root; This:C1470._hostEventPath)))
	If ((OK=0) || (Length:C16($element)=0))
		return Null:C1517
	End if 
	
	// enumerated rather than read by name: a host that never checked the option simply has no
	// such attribute, and DOM GET XML ATTRIBUTE BY NAME would log error -9930 on every call
	var $name : Text
	var $value : Text
	var $index : Integer
	
	For ($index; 1; DOM Count XML attributes:C727($element))
	
		DOM GET XML ATTRIBUTE BY INDEX:C729($element; $index; $name; $value)
		If ($name=This:C1470._hostEventName)
			$value:=Lowercase:C14($value)
			return (($value="true") || ($value="1"))  // XML booleans
		End if 
	
	End for 
	
	return Null:C1517
	
