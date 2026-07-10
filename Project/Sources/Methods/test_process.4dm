//%attributes = {}
// Automated tests for cs.Process using dedicated fixtures and a controlled embedder.

var $mockEmbedder:=Not:C34(Shift down:C543)  // if false will use real configured provider and model, else we mock

var $model:="embed"
var $badmodel:="badembed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()
var $badModelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$badmodel)).first()

If ($mockEmbedder && (($modelAlias=Null:C1517) || ($badModelAlias=Null:C1517)))
	// add the missing test model aliases (mock mode only, never touch real config)
	var $file:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $data : Object:=($file.exists) ? JSON Parse:C1218($file.getText()) : {providers: {}; models: {}}
	
	If ($data.providers["openai"]=Null:C1517)
		$data.providers["openai"]:={}
	End if 
	If ($modelAlias=Null:C1517)
		$data.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	End if 
	If ($badModelAlias=Null:C1517)
		$data.models[$badmodel]:={model: "badmodel"; provider: "openai"}
	End if 
	$file.setText(JSON Stringify:C1217($data; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()
	$badModelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$badmodel)).first()
End if 

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model aliases")))
	return 
End if 

// TODO: mock stuff auto config

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_tmp.json")

$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: $model; phrase: "{firstName} {lastName}"}; \
{dataclassName: "School"; vectorName: "school_vector_1"; modelAlias: $model; phrase: "{name}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $studentsDef : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_1")
var $schoolDef : cs:C1710.Definition:=$settings.find("School"; "school_vector_1")

ASSERT:C1129($studentsDef#Null:C1517; "students test definition missing")
ASSERT:C1129($schoolDef#Null:C1517; "school test definition missing")

// Seed a deterministic fixture set inside the temporary child base.
ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482._Students.all().drop()
var $cityParis:=ds:C1482.Cities.new()
$cityParis.name:="Paris"
$cityParis.state:="Ile-de-France"
ASSERT:C1129($cityParis.save().success; "failed to save Paris")

var $cityLyon:=ds:C1482.Cities.new()
$cityLyon.name:="Lyon"
$cityLyon.state:="Auvergne-Rhone-Alpes"
ASSERT:C1129($cityLyon.save().success; "failed to save Lyon")

var $schoolParis:=ds:C1482.School.new()
$schoolParis.name:="Sorbonne"
$schoolParis.university:="Paris University"
$schoolParis.city_ID:=$cityParis.ID
ASSERT:C1129($schoolParis.save().success; "failed to save Sorbonne")

var $schoolLyon:=ds:C1482.School.new()
$schoolLyon.name:="ENS Lyon"
$schoolLyon.university:="Lyon University"
$schoolLyon.city_ID:=$cityLyon.ID
ASSERT:C1129($schoolLyon.save().success; "failed to save ENS Lyon")

var $studentAlice:=ds:C1482._Students.new()
$studentAlice.firstName:="Alice"
$studentAlice.lastName:="Durand"
$studentAlice.school_ID:=$schoolParis.ID
ASSERT:C1129($studentAlice.save().success; "failed to save Alice")

var $studentBob:=ds:C1482._Students.new()
$studentBob.firstName:="Bob"
$studentBob.lastName:="Martin"
$studentBob.school_ID:=$schoolLyon.ID
ASSERT:C1129($studentBob.save().success; "failed to save Bob")

var $embedder : Object:=$mockEmbedder ? cs:C1710._TestProcessEmbedder.new({criticalModels: [$badmodel]}) : Null:C1517/*use default*/

// --- process(one definition) ---
var $proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
var $result : cs:C1710.ProcessResult:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.definitionsProcessed=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- already-embedded filtering ---
$proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=0; JSON Stringify:C1217($result.toObject()))

// --- force recomputes already embedded entities ---
$proc:=cs:C1710.Process.new($settings; {embedder: $embedder; force: True:C214})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- dryRun skips writes and API calls ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate student vectors")
$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
$studentBob:=ds:C1482._Students.get($studentBob.ID)
ASSERT:C1129($studentAlice.student_vector_1=Null:C1517; "Alice vector should be reset before dryRun")
ASSERT:C1129($studentBob.student_vector_1=Null:C1517; "Bob vector should be reset before dryRun")

$proc:=cs:C1710.Process.new($settings; {embedder: $embedder; dryRun: True:C214})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=0; JSON Stringify:C1217($result.toObject()))
$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
$studentBob:=ds:C1482._Students.get($studentBob.ID)
ASSERT:C1129($studentAlice.student_vector_1=Null:C1517; "dryRun should not write Alice vector")
ASSERT:C1129($studentBob.student_vector_1=Null:C1517; "dryRun should not write Bob vector")

// --- processEntity entry point ---
$proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
$result:=$proc.processEntity($studentAlice)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.definitionsProcessed=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- processEntitySelection entry point ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate vectors before selection test")
var $selection : 4D:C1709.EntitySelection:=ds:C1482._Students.query("lastName = :1"; "Martin")
$proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
$result:=$proc.processEntitySelection($selection; {vectorName: "student_vector_1"})
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.definitionsProcessed=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- process(all definitions) ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before all-definitions test")
ASSERT:C1129($schoolDef.invalidateVectors().errors.length=0; "failed to invalidate schools before all-definitions test")

$proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
$result:=$proc.process()
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.definitionsProcessed=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=4; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=4; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=2; JSON Stringify:C1217($result.toObject()))

// --- callback invocation ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before callback test")
$settings.batchSize:=1
var $callbacks:={progress: 0; success: 0; error: 0; terminate: 0}

$proc:=cs:C1710.Process.new($settings; {embedder: $embedder; \
onProgress: Formula:C1597($callbacks.progress+=1); \
onSuccess: Formula:C1597($callbacks.success+=1); \
onError: Formula:C1597($callbacks.error+=1); \
onTerminate: Formula:C1597($callbacks.terminate+=1)})
$result:=$proc.processEntitySelection(ds:C1482._Students.all(); $studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($callbacks.progress=2; JSON Stringify:C1217($callbacks))
ASSERT:C1129($callbacks.success=1; JSON Stringify:C1217($callbacks))
ASSERT:C1129($callbacks.error=0; JSON Stringify:C1217($callbacks))
ASSERT:C1129($callbacks.terminate=1; JSON Stringify:C1217($callbacks))
$settings.batchSize:=50

// --- cooperative cancel (shouldCancel option) stops between chunks ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before cancel test")
$settings.batchSize:=1  // 2 students -> 2 chunks of 1
var $cancelFlag:={cancel: False:C215}
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); \
onProgress: Formula:C1597($cancelFlag.cancel:=True:C214); \
shouldCancel: Formula:C1597($cancelFlag.cancel)})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.entitiesConsidered=2; "cancel: expected 2 considered, got "+String:C10($result.entitiesConsidered))
ASSERT:C1129($result.entitiesUpdated=1; "cancel: expected only first chunk (1) updated, got "+String:C10($result.entitiesUpdated))
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 = null").length=1; "cancel: one student should remain unembedded")
$settings.batchSize:=50

// --- shouldCancel that never fires completes fully ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before no-cancel test")
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); shouldCancel: Formula:C1597(False:C215)})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.entitiesUpdated=2; "no-cancel: expected 2 updated, got "+String:C10($result.entitiesUpdated))

// --- invalid definition reporting + error callback ---
var $badDef:=cs:C1710.Definition.new("_Students"; "missing_vector"; "text-embedding-3-small"; "{firstName}")
var $errorCallbacks:={success: 0; error: 0; terminate: 0}
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); \
onSuccess: Formula:C1597($errorCallbacks.success+=1); \
onError: Formula:C1597($errorCallbacks.error+=1); \
onTerminate: Formula:C1597($errorCallbacks.terminate+=1)})
cs:C1710._Logger.me._capture:=[]  // capture diagnostic log entries emitted during this run
$result:=$proc.process($badDef)
var $loggedErrors : Collection:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517  // stop capturing so later tests are unaffected
ASSERT:C1129(Not:C34($result.success); "invalid definition should fail")
ASSERT:C1129($result.definitionsProcessed=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.length>0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors[0].scope="definition"; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors[0].code=cs:C1710.ProcessErrorCode.me.VALIDATION_FAILED; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Not:C34($result.errors[0].retryable); "validation failure should not be retryable")
ASSERT:C1129(Not:C34($result.hasFatal); "validation failure is not fatal")
ASSERT:C1129($errorCallbacks.success=0; JSON Stringify:C1217($errorCallbacks))
ASSERT:C1129($errorCallbacks.error=1; JSON Stringify:C1217($errorCallbacks))
ASSERT:C1129($errorCallbacks.terminate=1; JSON Stringify:C1217($errorCallbacks))

// every recorded error must also be mirrored into the diagnostic log (centralized in ProcessResult._addError)
ASSERT:C1129($result.errors.length>0; "expected at least one recorded error to check logging")
var $repErr : Object
For each ($repErr; $result.errors)
	var $logged : Collection:=$loggedErrors.query("message = :1 AND message = :2"; \
		"@\"event\":\"Process error\"@"; "@\"code\":"+String:C10($repErr.code)+"@")
	ASSERT:C1129($logged.length>0; "recorded error code "+String:C10($repErr.code)+" is missing from the diagnostic log: "+JSON Stringify:C1217($loggedErrors))
End for each 


// --- model-level critical failure skips later definitions with the same model ---
If (Not:C34(Asserted:C1132($badModelAlias#Null:C1517; "you must configure an 'badembed' model aliases that will failed")))
	return 
End if 

ASSERT:C1129($schoolDef.invalidateVectors().errors.length=0; "failed to invalidate schools before critical-model test")
var $criticalA:=cs:C1710.Definition.new("School"; "school_vector_1"; $badmodel; "{name}")
var $criticalB:=cs:C1710.Definition.new("School"; "vector_with_error"; $badmodel; "{name}")

$proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
cs:C1710._Logger.me._capture:=[]  // capture diagnostic log entries emitted during this run
$result:=$proc.process([$criticalA; $criticalB])
var $criticalLogged : Collection:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517  // stop capturing so later tests are unaffected
ASSERT:C1129(Not:C34($result.success); "critical model failure should be reported")
ASSERT:C1129($result.entitiesSkipped=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.query("scope = :1"; "pipeline").length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.query("scope = :1"; "definition").length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Position:C15("Skipped: model"; String:C10($result.errors.query("scope = :1"; "definition")[0].message))>0; JSON Stringify:C1217($result.toObject()))

// pipeline-level errors raised outside of _validateDefinition must also reach the diagnostic log
var $critErr : Object
For each ($critErr; $result.errors)
	var $critMatch : Collection:=$criticalLogged.query("message = :1 AND message = :2"; \
		"@\"event\":\"Process error\"@"; "@\"code\":"+String:C10($critErr.code)+"@")
	ASSERT:C1129($critMatch.length>0; "recorded error code "+String:C10($critErr.code)+" is missing from the diagnostic log: "+JSON Stringify:C1217($criticalLogged))
End for each 

// structured error fields: the critical model failure is fatal, the skipped definition is a retryable error
var $codes:=cs:C1710.ProcessErrorCode.me
ASSERT:C1129($result.hasFatal; "critical model failure should be fatal")
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE)[0].severity="fatal"; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.MODEL_SKIPPED).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.MODEL_SKIPPED)[0].scope="definition"; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.retryableErrors().length=$result.errors.length; "both critical-model errors should be retryable")

// --- settings.embedder: options forwarded to cs.Embedder (maxRetries + backoffMs) ---
$settings.embedder:={maxRetries: 1; backoffMs: 100}
$proc:=cs:C1710.Process.new($settings)
ASSERT:C1129(OB Instance of:C1731($proc.embedder; cs:C1710.Embedder); "settings.embedder options: should be an Embedder")
ASSERT:C1129($proc.embedder.maxRetries=1; "settings.embedder.maxRetries should be forwarded")
ASSERT:C1129($proc.embedder.backoffMs=100; "settings.embedder.backoffMs should be forwarded")
$settings.embedder:=Null:C1517

// --- settings.embedder.className: instantiates custom class when valid ---
$settings.embedder:={className: "_TestProcessEmbedder"}
$proc:=cs:C1710.Process.new($settings)
ASSERT:C1129(OB Instance of:C1731($proc.embedder; cs:C1710._TestProcessEmbedder); "settings.embedder.className should instantiate _TestProcessEmbedder")
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before className test")
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
var $casted : Object:=$proc.embedder
ASSERT:C1129($casted.embedBatchCalls.length>0; "className embedder should have been called via embedBatch")
$settings.embedder:=Null:C1517

// --- settings.embedder.className: falls back to default Embedder when class not found ---
$settings.embedder:={className: "NonExistentClass4DESTest"}
$proc:=cs:C1710.Process.new($settings)
ASSERT:C1129(OB Instance of:C1731($proc.embedder; cs:C1710.Embedder); "unknown className should fall back to default Embedder")
$settings.embedder:=Null:C1517

// --- invalidateVectors with dirty companion field (student_vector_2 has student_vector_2_dirty) ---
var $studentsDef2:=cs:C1710.Definition.new("_Students"; "student_vector_2"; $model; "{firstName} {lastName}")
$proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
$result:=$proc.process($studentsDef2)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))

ASSERT:C1129($studentsDef2.invalidateVectors().errors.length=0; "failed to invalidate student_vector_2")
$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
$studentBob:=ds:C1482._Students.get($studentBob.ID)
ASSERT:C1129($studentAlice.student_vector_2#Null:C1517; "dirty path: Alice vector_2 should NOT be nulled")
ASSERT:C1129(Bool:C1537($studentAlice.student_vector_2_dirty); "dirty path: Alice student_vector_2_dirty should be True")
ASSERT:C1129($studentBob.student_vector_2#Null:C1517; "dirty path: Bob vector_2 should NOT be nulled")
ASSERT:C1129(Bool:C1537($studentBob.student_vector_2_dirty); "dirty path: Bob student_vector_2_dirty should be True")

$proc:=cs:C1710.Process.new($settings; {embedder: $embedder})
$result:=$proc.process($studentsDef2)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; "dirty entities should be picked up for recompute")
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
$studentBob:=ds:C1482._Students.get($studentBob.ID)
ASSERT:C1129(Not:C34($studentAlice.student_vector_2_dirty); "after recompute: Alice student_vector_2_dirty should be cleared")
ASSERT:C1129(Not:C34($studentBob.student_vector_2_dirty); "after recompute: Bob student_vector_2_dirty should be cleared")

$settingsFile.delete()