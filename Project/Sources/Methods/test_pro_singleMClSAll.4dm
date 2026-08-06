//%attributes = {}
// Verify batch stops entirely when only one model is present and it fails with a critical error.
// Given only a single model is configured for the run, when that model encounters a critical
// API error, then the whole run shall stop (nothing succeeds), since no other model exists to
// keep processing.

var $badmodel:="badembed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $badModelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel).first()

If ($badModelAlias=Null:C1517)
	// test-only alias bootstrap (same approach as existing process tests)
	var $providersFile:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $providersData : Object:=($providersFile.exists) ? JSON Parse:C1218($providersFile.getText()) : {providers: {}; models: {}}
	
	If ($providersData.providers["openai"]=Null:C1517)
		$providersData.providers["openai"]:={}
	End if 
	$providersData.models[$badmodel]:={model: "badmodel"; provider: "openai"}
	$providersFile.setText(JSON Stringify:C1217($providersData; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$badModelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel).first()
End if 

If (Not:C34(Asserted:C1132($badModelAlias#Null:C1517; "you must configure a 'badembed' model alias")))
	return 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_single_model_critical_tmp.json")

Try
	// Only ONE definition/model exists in the whole settings for this run.
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: [\
		{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: $badmodel; phrase: "{firstName} {lastName}"}]}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	
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
	
	// Full run (process() with no argument): resolves every definition in settings — here, just one.
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({criticalModels: [$badmodel]})
	var $proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process()
	
	var $codes:=cs:C1710.ProcessErrorCode.me
	ASSERT:C1129(Not:C34($result.success); "the entire run should fail")
	ASSERT:C1129($result.hasFatal; "critical error should be reported as fatal")
	ASSERT:C1129($result.definitionsProcessed=1; "the single definition should have been attempted")
	ASSERT:C1129($result.entitiesUpdated=0; "nothing should succeed when the only model fails")
	ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
	
	$studentA:=ds:C1482._Students.get($studentA.ID)
	$studentB:=ds:C1482._Students.get($studentB.ID)
	ASSERT:C1129($studentA.student_vector_1=Null:C1517; "student A vector should never have been computed")
	ASSERT:C1129($studentB.student_vector_1=Null:C1517; "student B vector should never have been computed")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
