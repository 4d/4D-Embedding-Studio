//%attributes = {"invisible":true}
/**
 FULL INTEGRATION test for the embedding scheduler — NOT a unit test.

 It is deliberately not named test_@ so the _runTests harness skips it (it is
 long: it starts the real background worker loop and waits on scheduling timing).

 What it does:
   1. Seeds a few _Students (requires a DATA FILE — uses ds._Students).
   2. Writes a temporary settings file with the MOCK embedder
      (embedder.className = "_TestProcessEmbedder", so no API is needed) and an
      interval scheduler configured to fire immediately (startFrom lastExecution
      with no prior run).
   3. Calls Scheduler.start(), then polls status() until one batch completes.
   4. Asserts the batch ran, completed and embedded every student.
   5. Calls Scheduler.stop() and checks the loop worker is gone.

 Run headless (against a COPY of the data file — it drops/reseeds _Students):
   tool4d --project=... --data=<copy>/data.4DD \
--startup-method="_scheduler_integration" --skip-onstartup
 Pass $keepAlive=True to skip the final QUIT 4D when running from the method editor or shift down.
**/

#DECLARE($keepAlive : Boolean)
If (Shift down:C543)
	$keepAlive:=True:C214
End if 

LOG EVENT:C667(Into system standard outputs:K38:9; "[IT] scheduler integration starting…"+Char:C90(Line feed:K15:40))

// Ensure a clean slate.
cs:C1710.Scheduler.me.stop()
cs:C1710._SchedulerState.me.endBatch(""; ""; "")

// --- Seed 5 students without vectors ---
ds:C1482._Students.all().drop()
var $i : Integer
For ($i; 1; 5)
	var $st : 4D:C1709.Entity:=ds:C1482._Students.new()
	$st.firstName:="Int"+String:C10($i)
	$st.lastName:="Test"+String:C10($i)
	ASSERT:C1129($st.save().success; "IT: failed to save student "+String:C10($i))
End for 

// --- Temp settings: mock embedder + interval scheduler firing immediately ---
var $prevFile : 4D:C1709.File:=cs:C1710._Settings.me.file
var $file : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__it_scheduler.json")
// The 1h interval fires immediately here because startFrom "lastExecution" with no prior run (lastRun="") triggers an immediate run; the interval only spaces subsequent runs.
$file.setText(JSON Stringify:C1217({\
batchSize: 2; \
embedder: {className: "_TestProcessEmbedder"}; \
definitions: [{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "embed"; phrase: "{firstName} {lastName}"}]; \
scheduler: {mode: "interval"; intervalHours: 1; startFrom: "lastExecution"}}))
cs:C1710._Settings.me.file:=$file

// --- Arm the real background scheduler ---
cs:C1710.Scheduler.me.start()
LOG EVENT:C667(Into system standard outputs:K38:9; "[IT] armed, waiting for the batch…"+Char:C90(Line feed:K15:40))

// --- Poll up to ~30s for one batch to complete ---
var $status : Object
var $elapsed : Integer:=0
Repeat 
	DELAY PROCESS:C323(Current process:C322; 60)  // 1 second
	$elapsed+=1
	$status:=cs:C1710.Scheduler.me.status()
Until (((Length:C16(String:C10($status.lastExecution))>0) && (Not:C34($status.running))) || ($elapsed>=30))

LOG EVENT:C667(Into system standard outputs:K38:9; "[IT] status after run: "+JSON Stringify:C1217($status)+Char:C90(Line feed:K15:40))

// --- Assertions ---
ASSERT:C1129(Length:C16(String:C10($status.lastExecution))>0; "IT: a run should have completed within the timeout")
ASSERT:C1129($status.lastResult="completed"; "IT: lastResult should be 'completed', got "+String:C10($status.lastResult))
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 = null").length=0; "IT: every student should be embedded after the scheduled run")

// --- Stop and verify the loop worker is gone ---
cs:C1710.Scheduler.me.stop()
DELAY PROCESS:C323(Current process:C322; 60)
ASSERT:C1129(Not:C34(cs:C1710.Scheduler.me.isStarted()); "IT: the scheduler loop worker should be stopped")

// --- Cleanup ---
cs:C1710._SchedulerState.me.endBatch(""; ""; "")
cs:C1710._Settings.me.file:=$prevFile
$file.delete()

LOG EVENT:C667(Into system standard outputs:K38:9; "[IT] scheduler integration PASSED"+Char:C90(Line feed:K15:40))

If (Not:C34($keepAlive))
	QUIT 4D:C291
End if 
