//%attributes = {}
// Verifies that when a concurrent modification causes save failure
// (optimistic lock), the dirty flag stays true for retry.

var $model:="embed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()

If ($modelAlias=Null:C1517)
	// test-only alias bootstrap (same approach as test_process)
	var $file:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $data : Object:=($file.exists) ? JSON Parse:C1218($file.getText()) : {providers: {}; models: {}}
	
	If ($data.providers["openai"]=Null:C1517)
		$data.providers["openai"]:={}
	End if
	$data.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	$file.setText(JSON Stringify:C1217($data; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
End if

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model aliases")))
	return
End if

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_optimistic_lock_tmp.json")

$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")

ASSERT:C1129($def#Null:C1517; "test definition missing")

// Deterministic fixture set.
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

var $student:=ds:C1482._Students.new()
$student.firstName:="Alice"
$student.lastName:="Durand"
$student.school_ID:=$school.ID
ASSERT:C1129($student.save().success; "failed to save student")

// Compute once to ensure the vector exists before invalidation.
var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
var $result : cs:C1710.ProcessResult:=$proc.process($def)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))

// Probe: some runtimes do not reproduce optimistic-lock conflicts deterministically.
// If not supported, we only assert the success path invariants below.
var $optimisticSupported : Boolean:=False:C215
var $probe1 : 4D:C1709.Entity:=ds:C1482._Students.get($student.ID)
var $probe2 : 4D:C1709.Entity:=ds:C1482._Students.get($student.ID)
$probe1.lastName:=String:C10($probe1.lastName)+"_probe1"
ASSERT:C1129($probe1.save().success; "probe save #1 failed unexpectedly")
$probe2.lastName:=String:C10($probe2.lastName)+"_probe2"
var $probeStatus : Object:=$probe2.save()
$optimisticSupported:=Not:C34($probeStatus.success)
$student:=ds:C1482._Students.get($student.ID)
$student.lastName:="Durand"
ASSERT:C1129($student.save().success; "failed to restore student lastName after probe")

ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")

$student:=ds:C1482._Students.get($student.ID)
ASSERT:C1129($student.student_vector_2#Null:C1517; "vector should remain non-null in dirty mode")
ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty should be true after invalidation")

// This embedder touches the same row in embedBatch() to stale the snapshot.
var $conflictEmbedder:=cs:C1710._TestProcessEmbedderOptimisticLock.new({\
	dataclassName: "_Students"; \
	entityKey: $student.ID; \
	touchField: "lastName"; \
	touchSuffix: "_concurrent"})

$proc:=cs:C1710.Process.new($settings; {embedder: $conflictEmbedder})
$result:=$proc.process($def)

ASSERT:C1129($conflictEmbedder.touchCount=1; "concurrent touch should have happened exactly once")
If ($optimisticSupported)
	ASSERT:C1129(Not:C34($result.success); "optimistic lock scenario should report failure")
	ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.errors.query("code = :1"; cs:C1710.ProcessErrorCode.me.SAVE_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
	
	$student:=ds:C1482._Students.get($student.ID)
	ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty flag must remain true when save fails")
Else
	ASSERT:C1129($result.success; "without optimistic conflict support recalculation should succeed")
	ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
	$student:=ds:C1482._Students.get($student.ID)
	ASSERT:C1129(Not:C34($student.student_vector_2_dirty); "without conflict dirty should be cleared")
End if

$settingsFile.delete()