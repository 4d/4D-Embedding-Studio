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

// --- no settings.embedder: default Embedder with its default retry policy ---
$proc:=cs:C1710.Process.new($settings)
ASSERT:C1129(OB Instance of:C1731($proc.embedder; cs:C1710.Embedder); "no settings.embedder: should be a default Embedder")
ASSERT:C1129($proc.embedder.maxRetries=3; "no settings.embedder: default maxRetries should be 3")
ASSERT:C1129($proc.embedder.backoffMs=500; "no settings.embedder: default backoffMs should be 500")

// --- settings.embedder.className without embed/embedBatch: falls back to default Embedder, and says so ---
$settings.embedder:={className: "ProcessResult"}
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings)
var $classLogs : Collection:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517
ASSERT:C1129(OB Instance of:C1731($proc.embedder; cs:C1710.Embedder); "className without embed/embedBatch should fall back to default Embedder")
ASSERT:C1129($classLogs.query("message = :1"; "@missing embed or embedBatch@").length=1; "className without embed/embedBatch should be logged: "+JSON Stringify:C1217($classLogs))

// --- settings.embedder.className that cannot be instantiated: falls back to default Embedder, and says so ---
$settings.embedder:={className: "Phrase"}  // its constructor expects a Text template, not the embedder options
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings)
$classLogs:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517
ASSERT:C1129(OB Instance of:C1731($proc.embedder; cs:C1710.Embedder); "className that cannot be instantiated should fall back to default Embedder")
ASSERT:C1129($classLogs.query("message = :1"; "@could not be instantiated@").length=1; "className that cannot be instantiated should be logged: "+JSON Stringify:C1217($classLogs))
$settings.embedder:=Null:C1517
Try(1)  // clear the error raised by the refused instantiation

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

// ══════════════════════════════════════════════════════════════════════
// ENTITY ENTRY POINTS — null inputs and invalid definitions are reported, not thrown
// ══════════════════════════════════════════════════════════════════════

//MARK:- processEntity(Null)
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.processEntity(Null:C1517)
ASSERT:C1129(Not:C34($result.success); "processEntity(Null) should fail")
ASSERT:C1129($result.errorsByCode($codes.NULL_INPUT).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors[0].scope="entity"; JSON Stringify:C1217($result.toObject()))

//MARK:- processEntitySelection(Null)
$result:=$proc.processEntitySelection(Null:C1517)
ASSERT:C1129(Not:C34($result.success); "processEntitySelection(Null) should fail")
ASSERT:C1129($result.errorsByCode($codes.NULL_INPUT).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors[0].scope="pipeline"; JSON Stringify:C1217($result.toObject()))

//MARK:- invalid definition on processEntity / processEntitySelection
$result:=$proc.processEntity($studentAlice; $badDef)
ASSERT:C1129(Not:C34($result.success); "processEntity with an invalid definition should fail")
ASSERT:C1129($result.definitionsProcessed=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.VALIDATION_FAILED).length>0; JSON Stringify:C1217($result.toObject()))

$result:=$proc.processEntitySelection(ds:C1482._Students.all(); $badDef)
ASSERT:C1129(Not:C34($result.success); "processEntitySelection with an invalid definition should fail")
ASSERT:C1129($result.definitionsProcessed=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.VALIDATION_FAILED).length>0; JSON Stringify:C1217($result.toObject()))

//MARK:- _validateDefinition rejects Null and objects that are not definitions
var $report : cs:C1710.ProcessResult:=cs:C1710.ProcessResult.new()
ASSERT:C1129(Not:C34($proc._validateDefinition(Null:C1517; $report)); "_validateDefinition(Null) should be False")
ASSERT:C1129(Not:C34($proc._validateDefinition({dataclassName: "_Students"; vectorName: "student_vector_1"}; $report)); "_validateDefinition(plain object) should be False")
ASSERT:C1129($report.errorsByCode($codes.NULL_INPUT).length=1; JSON Stringify:C1217($report.toObject()))
ASSERT:C1129($report.errorsByCode($codes.INVALID_DEFINITION).length=1; JSON Stringify:C1217($report.toObject()))

// ══════════════════════════════════════════════════════════════════════
// SINGLE ENTITY PATH (processEntity)
// ══════════════════════════════════════════════════════════════════════

var $single : cs:C1710._TestProcessEmbedder

//MARK:- an entity already embedded and not dirty is skipped without API call
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); force: True:C214})
$result:=$proc.processEntity($studentAlice; $studentsDef)
ASSERT:C1129($result.entitiesUpdated=1; "setup: Alice should be embedded: "+JSON Stringify:C1217($result.toObject()))

$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
$single:=cs:C1710._TestProcessEmbedder.new()
$proc:=cs:C1710.Process.new($settings; {embedder: $single})
$result:=$proc.processEntity($studentAlice; $studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($single.embedCalls.length=0; "already embedded entity: the embedder should not be called")

//MARK:- dryRun: no API call, nothing written
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before single dryRun test")
$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
$single:=cs:C1710._TestProcessEmbedder.new()
$proc:=cs:C1710.Process.new($settings; {embedder: $single; dryRun: True:C214})
$result:=$proc.processEntity($studentAlice; $studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($single.embedCalls.length=0; "single dryRun: the embedder should not be called")
ASSERT:C1129(ds:C1482._Students.get($studentAlice.ID).student_vector_1=Null:C1517; "single dryRun: no vector should be written")

//MARK:- debug option logs each recomputed vector
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); debug: True:C214})
$result:=$proc.processEntity($studentAlice; $studentsDef)
var $debugLogs : Collection:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($debugLogs.query("message = :1"; "@Vector recomputed@").length=1; "single debug: the recomputed vector should be logged: "+JSON Stringify:C1217($debugLogs))

//MARK:- the dirty flag is cleared
ASSERT:C1129($studentsDef2.invalidateVectors().errors.length=0; "failed to invalidate student_vector_2 before single dirty test")
$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
ASSERT:C1129(Bool:C1537($studentAlice.student_vector_2_dirty); "setup: Alice student_vector_2 should be dirty")
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.processEntity($studentAlice; $studentsDef2)
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Not:C34(ds:C1482._Students.get($studentAlice.ID).student_vector_2_dirty); "single dirty: the dirty flag should be cleared")

//MARK:- a non-critical embedding failure is reported for the entity
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]}); force: True:C214})
$result:=$proc.processEntity($studentAlice; $studentsDef)
ASSERT:C1129(Not:C34($result.success); "single non-critical failure should be reported")
ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.EMBED_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.EMBED_FAILED)[0].scope="entity"; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Not:C34($result.hasFatal); "a non-critical failure is not fatal")

//MARK:- a critical model failure on one entity skips that model afterwards
var $criticalEntityDef:=cs:C1710.Definition.new("_Students"; "student_vector_1"; $badmodel; "{firstName}")
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: [$badmodel]}); force: True:C214})
cs:C1710._Logger.me._capture:=[]
$result:=$proc.processEntity($studentAlice; $criticalEntityDef)
var $entityCriticalLogs : Collection:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517
ASSERT:C1129(Not:C34($result.success); "single critical failure should be reported")
ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.hasFatal; "single critical failure should be fatal")
// no errorCode on the thrown error: the HTTP status of its first error is logged instead
ASSERT:C1129($entityCriticalLogs.query("message = :1 AND message = :2"; "@\"event\":\"Critical API error\"@"; "@\"errorCode\":\"400\"@").length=1; "single critical failure should be logged with its status: "+JSON Stringify:C1217($entityCriticalLogs))

$result:=$proc.processEntity($studentBob; $criticalEntityDef)
ASSERT:C1129($result.definitionsProcessed=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.MODEL_SKIPPED).length=1; "processEntity: the failed model should be skipped: "+JSON Stringify:C1217($result.toObject()))

$result:=$proc.processEntitySelection(ds:C1482._Students.all(); $criticalEntityDef)
ASSERT:C1129($result.entitiesConsidered=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.MODEL_SKIPPED).length=1; "processEntitySelection: the failed model should be skipped: "+JSON Stringify:C1217($result.toObject()))
Try(1)  // clear the errors thrown by the mock embedder

//MARK:- a save failure keeps the vector dirty and says so
ASSERT:C1129($studentsDef2.invalidateVectors().errors.length=0; "failed to invalidate student_vector_2 before single save failure test")
$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
// the embedder saves the same row from elsewhere: the entity held by Process becomes stale
var $lockEmbedder:=cs:C1710._TestProcessEmbedder.new({dataclassName: "_Students"; entityKey: $studentAlice.ID; touchField: "lastName"; touchSuffix: "_concurrent"})
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: $lockEmbedder})
$result:=$proc.processEntity($studentAlice; $studentsDef2)
var $lockLogs : Collection:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517
ASSERT:C1129($lockEmbedder.touchCount=1; "single save failure: the concurrent save should have happened: "+JSON Stringify:C1217($lockEmbedder.touchErrors))
ASSERT:C1129(Not:C34($result.success); "single save failure should be reported")
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.SAVE_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Bool:C1537(ds:C1482._Students.get($studentAlice.ID).student_vector_2_dirty); "single save failure: the dirty flag must remain set")
ASSERT:C1129($lockLogs.query("message = :1"; "@\"event\":\"Vector still dirty after save during recomputation\"@").length=1; "single save failure: the still-dirty vector should be logged")

$studentAlice:=ds:C1482._Students.get($studentAlice.ID)
$studentAlice.lastName:="Durand"
ASSERT:C1129($studentAlice.save().success; "failed to restore Alice's last name")

// ══════════════════════════════════════════════════════════════════════
// SELECTION PATH OPTIONS
// ══════════════════════════════════════════════════════════════════════

//MARK:- a non-positive batchSize falls back to 50 (one chunk here)
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before batchSize test")
$settings.batchSize:=0
var $batchEmbedder:=cs:C1710._TestProcessEmbedder.new()
$proc:=cs:C1710.Process.new($settings; {embedder: $batchEmbedder})
$result:=$proc.process($studentsDef)
$settings.batchSize:=50
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($batchEmbedder.embedBatchCalls.length=1; "batchSize 0: both entities should go in a single chunk")

//MARK:- index pausing disabled, or resumed synchronously
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before pauseIndexes test")
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); pauseIndexes: False:C215})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success && ($result.entitiesUpdated=2); "pauseIndexes False: "+JSON Stringify:C1217($result.toObject()))

ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before waitForIndexes test")
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); waitForIndexes: True:C214})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success && ($result.entitiesUpdated=2); "waitForIndexes True: "+JSON Stringify:C1217($result.toObject()))

//MARK:- a provider returning the wrong number of vectors is reported for the chunk
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before vector count test")
var $shortEmbedder : Object:={\
embedBatch: Formula:C1597(cs:C1710.EmbedderResult.new({vectors: []; usage: {prompt_tokens: 1; total_tokens: 1}}; True:C214))}
$proc:=cs:C1710.Process.new($settings; {embedder: $shortEmbedder})
$result:=$proc.process($studentsDef)
ASSERT:C1129(Not:C34($result.success); "vector count mismatch should be reported")
ASSERT:C1129($result.errorsByCode($codes.VECTOR_COUNT_MISMATCH).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 = null").length=2; "vector count mismatch: no vector should be written")

$settingsFile.delete()