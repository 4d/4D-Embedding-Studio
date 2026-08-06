//%attributes = {}
// Verify batch stops for affected model on unavailable model error.
// Given the configured model becomes unavailable during the embedding computation batch,
// when the error is detected, then the batch shall stop computation for ALL vectors using
// that model (here: an entire chunk covering every pending entity for that definition).

var $model:="embed"
var $badmodel:="badembed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
var $badModelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel).first()

If (($modelAlias=Null:C1517) || ($badModelAlias=Null:C1517))
	// test-only alias bootstrap (same approach as existing process tests)
	var $providersFile:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $providersData : Object:=($providersFile.exists) ? JSON Parse:C1218($providersFile.getText()) : {providers: {}; models: {}}
	
	If ($providersData.providers["openai"]=Null:C1517)
		$providersData.providers["openai"]:={}
	End if 
	If ($modelAlias=Null:C1517)
		$providersData.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	End if 
	If ($badModelAlias=Null:C1517)
		$providersData.models[$badmodel]:={model: "badmodel"; provider: "openai"}
	End if 
	$providersFile.setText(JSON Stringify:C1217($providersData; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
	$badModelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel).first()
End if 

If (Not:C34(Asserted:C1132(($modelAlias#Null:C1517) && ($badModelAlias#Null:C1517); "you must configure 'embed' and 'badembed' model aliases")))
	return 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_critical_unavail_model_tmp.json")

Try
	// batchSize covers ALL pending entities in a single chunk/API call, so a model-unavailable
	// error fails the whole chunk at once: every vector using that model is skipped together.
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: []}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $def : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_1"; $badmodel; "{firstName} {lastName}")
	
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
	
	var $studentA:=ds:C1482._Students.new()
	$studentA.firstName:="Alice"
	$studentA.lastName:="Durand"
	$studentA.school_ID:=$school.ID
	ASSERT:C1129($studentA.save().success; "failed to save student A")
	
	var $studentB:=ds:C1482._Students.new()
	$studentB.firstName:="Bob"
	$studentB.lastName:="Martin"
	$studentB.school_ID:=$school.ID
	ASSERT:C1129($studentB.save().success; "failed to save student B")
	
	var $studentC:=ds:C1482._Students.new()
	$studentC.firstName:="Chloe"
	$studentC.lastName:="Bernard"
	$studentC.school_ID:=$school.ID
	ASSERT:C1129($studentC.save().success; "failed to save student C")
	
	// Simulated "model unavailable" critical error: every call for $badmodel throws.
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({criticalModels: [$badmodel]})
	var $proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	
	var $codes:=cs:C1710.ProcessErrorCode.me
	ASSERT:C1129(Not:C34($result.success); "batch should fail on model unavailable error")
	ASSERT:C1129($result.hasFatal; "model unavailable error should be reported as fatal")
	ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=0; "no vector using the affected model should be updated")
	ASSERT:C1129($result.entitiesSkipped=3; "all vectors of the single chunk should be skipped together")
	ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
	
	$studentA:=ds:C1482._Students.get($studentA.ID)
	$studentB:=ds:C1482._Students.get($studentB.ID)
	$studentC:=ds:C1482._Students.get($studentC.ID)
	ASSERT:C1129($studentA.student_vector_1=Null:C1517; "student A vector should never have been computed")
	ASSERT:C1129($studentB.student_vector_1=Null:C1517; "student B vector should never have been computed")
	ASSERT:C1129($studentC.student_vector_1=Null:C1517; "student C vector should never have been computed")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
