//%attributes = {}
// Verify batch continues with all other models when multiple models fail independently.
// Given several models each encounter their own critical API error during the same run,
// when each error is detected, then only the vectors using THAT specific model stop, while
// a definition using a third, healthy model still completes normally.

var $model:="embed"
var $badmodel1:="badembed"
var $badmodel2:="badembed2"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
var $badModelAlias1 : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel1).first()
var $badModelAlias2 : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel2).first()

If (($modelAlias=Null:C1517) || ($badModelAlias1=Null:C1517) || ($badModelAlias2=Null:C1517))
	// test-only alias bootstrap (same approach as existing process tests)
	var $providersFile:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $providersData : Object:=($providersFile.exists) ? JSON Parse:C1218($providersFile.getText()) : {providers: {}; models: {}}
	
	If ($providersData.providers["openai"]=Null:C1517)
		$providersData.providers["openai"]:={}
	End if 
	If ($modelAlias=Null:C1517)
		$providersData.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	End if 
	If ($badModelAlias1=Null:C1517)
		$providersData.models[$badmodel1]:={model: "badmodel"; provider: "openai"}
	End if 
	If ($badModelAlias2=Null:C1517)
		$providersData.models[$badmodel2]:={model: "badmodel2"; provider: "openai"}
	End if 
	$providersFile.setText(JSON Stringify:C1217($providersData; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
	$badModelAlias1:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel1).first()
	$badModelAlias2:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $badmodel2).first()
End if 

If (Not:C34(Asserted:C1132(($modelAlias#Null:C1517) && ($badModelAlias1#Null:C1517) && ($badModelAlias2#Null:C1517); "you must configure 'embed', 'badembed' and 'badembed2' model aliases")))
	return 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_multi_models_fail_tmp.json")

Try
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: []}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $badDef1 : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_1"; $badmodel1; "{firstName} {lastName}")
	var $badDef2 : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_2"; $badmodel2; "{lastName} {firstName}")
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
	
	// Each bad model throws independently for its own definition; the third, healthy model is untouched.
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({criticalModels: [$badmodel1; $badmodel2]})
	var $proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process([$badDef1; $badDef2; $goodDef])
	
	var $codes:=cs:C1710.ProcessErrorCode.me
	ASSERT:C1129(Not:C34($result.success); "batch should report failure due to the two bad models")
	ASSERT:C1129($result.hasFatal; "both critical model errors should be reported as fatal")
	ASSERT:C1129($result.definitionsProcessed=3; "all three definitions should have been attempted")
	ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=2; "each bad model should report its own MODEL_UNAVAILABLE error")
	
	// Neither bad model's vector was ever computed.
	$studentA:=ds:C1482._Students.get($studentA.ID)
	ASSERT:C1129($studentA.student_vector_1=Null:C1517; "student A vector 1 (bad model 1) should never have been computed")
	ASSERT:C1129($studentA.student_vector_2=Null:C1517; "student A vector 2 (bad model 2) should never have been computed")
	
	// The third, healthy model's definition completed fully and normally, unaffected by the other two failures.
	$school:=ds:C1482.School.get($school.ID)
	ASSERT:C1129($school.school_vector_1#Null:C1517; "school vector (healthy model) should have been computed")
	ASSERT:C1129($result.entitiesUpdated=1; "only the healthy model's entity should have been updated")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
