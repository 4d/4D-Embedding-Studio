//%attributes = {}
// Automated tests for cs.embed.Process using dedicated fixtures and a controlled processor.

var $mockProcessor:=Not:C34(Shift down:C543)  // if false will use real configured provider and model, else we mock

var $model:="embed"
var $badmodel:="badembed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()

If (($mockProcessor) && ($modelAlias=Null:C1517))
	// add embed model alias if not defined
	var $file:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $data : Object:=($file.exists) ? JSON Parse:C1218($file.getText()) : {providers: {}; models: {}}
	
	$data.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	If ($data.providers["openai"]=Null:C1517)
		$data.providers["openai"]:={}
	End if 
	$data.models[$badmodel]:={model: "badmodel"; provider: "openai"}
	$file.setText(JSON Stringify:C1217($data; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()
End if 

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model aliases")))
	return 
End if 

// TODO: mock stuff auto config

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_tmp.json")

$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; vectors: [\
{dataclassName: "Students"; vectorName: "student_vector_1"; model: $model; phrase: "{firstName} {lastName}"}; \
{dataclassName: "School"; vectorName: "school_vector_1"; model: $model; phrase: "{name}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $studentsDef : cs:C1710.Definition:=$settings.find("Students"; "student_vector_1")
var $schoolDef : cs:C1710.Definition:=$settings.find("School"; "school_vector_1")

ASSERT:C1129($studentsDef#Null:C1517; "students test definition missing")
ASSERT:C1129($schoolDef#Null:C1517; "school test definition missing")

// Seed a deterministic fixture set inside the temporary child base.
ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482.Students.all().drop()
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

var $studentAlice:=ds:C1482.Students.new()
$studentAlice.firstName:="Alice"
$studentAlice.lastName:="Durand"
$studentAlice.school_ID:=$schoolParis.ID
ASSERT:C1129($studentAlice.save().success; "failed to save Alice")

var $studentBob:=ds:C1482.Students.new()
$studentBob.firstName:="Bob"
$studentBob.lastName:="Martin"
$studentBob.school_ID:=$schoolLyon.ID
ASSERT:C1129($studentBob.save().success; "failed to save Bob")

var $processor : Object:=$mockProcessor ? cs:C1710._TestProcessProcessor.new({criticalModels: [$badmodel]}) : Null:C1517/*use default*/

// --- process(one definition) ---
var $proc:=cs:C1710.Process.new($settings; {processor: $processor})
var $result : cs:C1710.ProcessResult:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.definitionsProcessed=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- already-embedded filtering ---
$proc:=cs:C1710.Process.new($settings; {processor: $processor})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=0; JSON Stringify:C1217($result.toObject()))

// --- force recomputes already embedded entities ---
$proc:=cs:C1710.Process.new($settings; {processor: $processor; force: True:C214})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- dryRun skips writes and API calls ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate student vectors")
$studentAlice:=ds:C1482.Students.get($studentAlice.ID)
$studentBob:=ds:C1482.Students.get($studentBob.ID)
ASSERT:C1129($studentAlice.student_vector_1=Null:C1517; "Alice vector should be reset before dryRun")
ASSERT:C1129($studentBob.student_vector_1=Null:C1517; "Bob vector should be reset before dryRun")

$proc:=cs:C1710.Process.new($settings; {processor: $processor; dryRun: True:C214})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=0; JSON Stringify:C1217($result.toObject()))
$studentAlice:=ds:C1482.Students.get($studentAlice.ID)
$studentBob:=ds:C1482.Students.get($studentBob.ID)
ASSERT:C1129($studentAlice.student_vector_1=Null:C1517; "dryRun should not write Alice vector")
ASSERT:C1129($studentBob.student_vector_1=Null:C1517; "dryRun should not write Bob vector")

// --- processEntity entry point ---
$proc:=cs:C1710.Process.new($settings; {processor: $processor})
$result:=$proc.processEntity($studentAlice)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.definitionsProcessed=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- processEntitySelection entry point ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate vectors before selection test")
var $selection : 4D:C1709.EntitySelection:=ds:C1482.Students.query("lastName = :1"; "Martin")
$proc:=cs:C1710.Process.new($settings; {processor: $processor})
$result:=$proc.processEntitySelection($selection; {vectorName: "student_vector_1"})
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.definitionsProcessed=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))

// --- process(all definitions) ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before all-definitions test")
ASSERT:C1129($schoolDef.invalidateVectors().errors.length=0; "failed to invalidate schools before all-definitions test")

$proc:=cs:C1710.Process.new($settings; {processor: $processor})
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

$proc:=cs:C1710.Process.new($settings; {processor: $processor; \
onProgress: Formula:C1597($callbacks.progress+=1); \
onSuccess: Formula:C1597($callbacks.success+=1); \
onError: Formula:C1597($callbacks.error+=1); \
onTerminate: Formula:C1597($callbacks.terminate+=1)})
$result:=$proc.processEntitySelection(ds:C1482.Students.all(); $studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($callbacks.progress=2; JSON Stringify:C1217($callbacks))
ASSERT:C1129($callbacks.success=1; JSON Stringify:C1217($callbacks))
ASSERT:C1129($callbacks.error=0; JSON Stringify:C1217($callbacks))
ASSERT:C1129($callbacks.terminate=1; JSON Stringify:C1217($callbacks))
$settings.batchSize:=50

// --- invalid definition reporting + error callback ---
var $badDef:=cs:C1710.Definition.new("Students"; "missing_vector"; "text-embedding-3-small"; "{firstName}")
var $errorCallbacks:={success: 0; error: 0; terminate: 0}
$proc:=cs:C1710.Process.new($settings; {processor: cs:C1710._TestProcessProcessor.new(); \
onSuccess: Formula:C1597($errorCallbacks.success+=1); \
onError: Formula:C1597($errorCallbacks.error+=1); \
onTerminate: Formula:C1597($errorCallbacks.terminate+=1)})
$result:=$proc.process($badDef)
ASSERT:C1129(Not:C34($result.success); "invalid definition should fail")
ASSERT:C1129($result.definitionsProcessed=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.length>0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors[0].scope="definition"; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($errorCallbacks.success=0; JSON Stringify:C1217($errorCallbacks))
ASSERT:C1129($errorCallbacks.error=1; JSON Stringify:C1217($errorCallbacks))
ASSERT:C1129($errorCallbacks.terminate=1; JSON Stringify:C1217($errorCallbacks))

// --- model-level critical failure skips later definitions with the same model ---
$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$badmodel)).first()

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'badembed' model aliases that will failed")))
	return 
End if 

ASSERT:C1129($schoolDef.invalidateVectors().errors.length=0; "failed to invalidate schools before critical-model test")
var $criticalA:=cs:C1710.Definition.new("School"; "school_vector_1"; $badmodel; "{name}")
var $criticalB:=cs:C1710.Definition.new("School"; "vector_with_error"; $badmodel; "{name}")

$proc:=cs:C1710.Process.new($settings; {processor: $processor})
$result:=$proc.process([$criticalA; $criticalB])
ASSERT:C1129(Not:C34($result.success); "critical model failure should be reported")
ASSERT:C1129($result.entitiesSkipped=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.query("scope = :1"; "model").length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.query("scope = :1"; "definition").length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Position:C15("Skipped: model"; String:C10($result.errors.query("scope = :1"; "definition")[0].message))>0; JSON Stringify:C1217($result.toObject()))

// --- settings.processor: options forwarded to cs.Processor (maxRetries + backoffMs) ---
$settings.processor:={maxRetries: 1; backoffMs: 100}
$proc:=cs:C1710.Process.new($settings)
ASSERT:C1129(OB Instance of:C1731($proc.processor; cs:C1710.Processor); "settings.processor options: should be a Processor")
ASSERT:C1129($proc.processor.maxRetries=1; "settings.processor.maxRetries should be forwarded")
ASSERT:C1129($proc.processor.backoffMs=100; "settings.processor.backoffMs should be forwarded")
$settings.processor:=Null:C1517

// --- settings.processor.className: instantiates custom class when valid ---
$settings.processor:={className: "_TestProcessProcessor"}
$proc:=cs:C1710.Process.new($settings)
ASSERT:C1129(OB Instance of:C1731($proc.processor; cs:C1710._TestProcessProcessor); "settings.processor.className should instantiate _TestProcessProcessor")
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate students before className test")
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
var $casted : Object:=$proc.processor
ASSERT:C1129($casted.embedBatchCalls.length>0; "className processor should have been called via embedBatch")
$settings.processor:=Null:C1517

// --- settings.processor.className: falls back to default Processor when class not found ---
$settings.processor:={className: "NonExistentClass4DESTest"}
$proc:=cs:C1710.Process.new($settings)
ASSERT:C1129(OB Instance of:C1731($proc.processor; cs:C1710.Processor); "unknown className should fall back to default Processor")
$settings.processor:=Null:C1517

$settingsFile.delete()