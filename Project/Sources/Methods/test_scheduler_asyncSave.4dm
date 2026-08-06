//%attributes = {}
// Verifies that forced recalculation runs asynchronously and does not
// block regular entity save operations.

var $model:="embed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()

If ($modelAlias=Null:C1517)
	// test-only alias bootstrap (same approach as existing process tests)
	var $providersFile:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $providersData : Object:=($providersFile.exists) ? JSON Parse:C1218($providersFile.getText()) : {providers: {}; models: {}}
	
	If ($providersData.providers["openai"]=Null:C1517)
		$providersData.providers["openai"]:={}
	End if
	$providersData.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	$providersFile.setText(JSON Stringify:C1217($providersData; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
End if

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model aliases")))
	return
End if

var $prevFile : 4D:C1709.File:=cs:C1710._Settings.me.file
var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_scheduler_async_nonblocking_tmp.json")

// Clean state before triggering background run.
cs:C1710.Scheduler.me.stop()
cs:C1710._SchedulerState.me.endBatch(""; ""; "")

// Seed deterministic fixtures.
ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482._Students.all().drop()

var $city:=ds:C1482.Cities.new()
$city.name:="Paris"
$city.state:="Ile-de-France"
ASSERT:C1129($city.save().success; "failed to save city")

var $school:=ds:C1482.School.new()
$school.name:="Sorbonne"
$school.university:="Paris University"
$school.city_ID:=$city.ID
ASSERT:C1129($school.save().success; "failed to save school")

var $i : Integer
For ($i; 1; 3)
	var $student:=ds:C1482._Students.new()
	$student.firstName:="Async"+String:C10($i)
	$student.lastName:="Test"+String:C10($i)
	$student.school_ID:=$school.ID
	ASSERT:C1129($student.save().success; "failed to save student "+String:C10($i))
End for

$settingsFile.setText(JSON Stringify:C1217({\
	batchSize: 1; \
	embedder: {className: "_TestProcessEmbedder"; delaySeconds: 2}; \
	definitions: [{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))
cs:C1710._Settings.me.file:=$settingsFile

// Non-blocking trigger (runs in worker "EmbeddingStudio").
cs:C1710.Scheduler.me.force()

// Wait briefly until scheduler reports a running batch.
var $running : Boolean:=False:C215
var $elapsedTicks : Integer:=0
While (($elapsedTicks<300) && (Not:C34($running)))
	var $status : Object:=cs:C1710.Scheduler.me.status()
	$running:=Bool:C1537($status.running)
	If (Not:C34($running))
		DELAY PROCESS:C323(Current process:C322; 6)
		$elapsedTicks+=6
	End if
End while
ASSERT:C1129($running; "forced scheduler run should be running asynchronously")

// Save a separate entity while recomputation is still running.
var $probeCity:=ds:C1482.Cities.new()
$probeCity.name:="Lyon"
$probeCity.state:="Auvergne-Rhone-Alpes"
var $saveStartMs : Integer:=Milliseconds:C459
var $probeSave : Object:=$probeCity.save()
var $saveDurationMs : Integer:=Milliseconds:C459-$saveStartMs
ASSERT:C1129($probeSave.success; "probe entity save should succeed while batch runs")

// Confirm overlap: scheduler should still be running right after the probe save.
$status:=cs:C1710.Scheduler.me.status()
ASSERT:C1129(Bool:C1537($status.running); "scheduler should still be running right after probe save")
ASSERT:C1129($saveDurationMs<1500; "probe save should not be blocked by async recalculation")

// Wait for completion.
$elapsedTicks:=0
Repeat
	DELAY PROCESS:C323(Current process:C322; 30)
	$elapsedTicks+=30
	$status:=cs:C1710.Scheduler.me.status()
Until ((Not:C34(Bool:C1537($status.running))) || ($elapsedTicks>=3600))

ASSERT:C1129(Not:C34(Bool:C1537($status.running)); "scheduler batch should complete")
ASSERT:C1129($status.lastResult="completed"; "scheduler run should complete successfully")
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 = null").length=0; "all students should be embedded")


// Cleanup.
cs:C1710.Scheduler.me.stop()
cs:C1710._SchedulerState.me.endBatch(""; ""; "")
cs:C1710._Settings.me.file:=$prevFile
If ($settingsFile.exists)
	$settingsFile.delete()
End if