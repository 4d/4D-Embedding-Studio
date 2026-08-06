//%attributes = {}
// Verifies that failed vector recalculation writes detailed error logs.

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

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_failure_logging_tmp.json")

Try
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
	
	// Ensure this path uses dirty-based recompute over a non-null vector.
	var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
	
	ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
	
	// Force recalculation failure and capture emitted error logs.
	cs:C1710._Logger.me._capture:=[]
	$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})})
	$result:=$proc.process($def)
	ASSERT:C1129(Not:C34($result.success); "recalculation should fail")
	ASSERT:C1129($result.errors.query("code = :1"; cs:C1710.ProcessErrorCode.me.EMBED_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
	
	var $logs : Collection:=cs:C1710._Logger.me._capture
	ASSERT:C1129($logs.length>0; "expected captured logs for failure run")
	
	var $failureLogs : Collection:=$logs.query("message = :1 AND message = :2"; \
		"@\"event\":\"Process error\"@"; \
		"@\"code\":"+String:C10(cs:C1710.ProcessErrorCode.me.EMBED_FAILED)+"@")
	ASSERT:C1129($failureLogs.length>0; "failure log should include Process error event with EMBED_FAILED code")
	ASSERT:C1129($logs.query("message = :1"; "@\"scope\":\"chunk\"@").length>0; "failure log should include chunk scope")
	ASSERT:C1129($logs.query("message = :1"; "@\"ref\":\"_Students.student_vector_2\"@").length>0; "failure log should include vector reference")
	ASSERT:C1129($logs.query("message = :1"; "@Non-critical test failure for Alice Durand@").length>0; "failure log should include the embed failure message")
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
cs:C1710._Logger.me._capture:=Null:C1517
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
