//%attributes = {}
// Verify vectors using other models continue processing after critical error on one model.
// Given a critical API error occurs for one model, when the error is detected, then vectors
// using OTHER models shall continue processing normally.

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

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_other_models_continue_tmp.json")

Try
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: []}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	// badDef (Students, badmodel) is listed FIRST and will fail critically.
	// goodDef (School, embed) uses a completely different model and must still succeed.
	var $badDef : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_1"; $badmodel; "{firstName} {lastName}")
	var $goodDef : cs:C1710.Definition:=cs:C1710.Definition.new("School"; "school_vector_1"; $model; "{name}")
	
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
	
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({criticalModels: [$badmodel]})
	var $proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process([$badDef; $goodDef])
	
	var $codes:=cs:C1710.ProcessErrorCode.me
	ASSERT:C1129(Not:C34($result.success); "batch should report failure due to the bad model")
	ASSERT:C1129($result.definitionsProcessed=2; "both definitions should have been attempted")
	ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
	
	// The affected model's vector was never computed...
	$studentA:=ds:C1482._Students.get($studentA.ID)
	ASSERT:C1129($studentA.student_vector_1=Null:C1517; "student A vector should never have been computed (affected model)")
	
	// ...but the other model's definition completed fully and normally.
	$school:=ds:C1482.School.get($school.ID)
	ASSERT:C1129($school.school_vector_1#Null:C1517; "school vector (different model) should have been computed")
	ASSERT:C1129($result.entitiesUpdated=1; "the good model's entity should have been updated despite the other model's failure")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
