//%attributes = {}
// Verify vectors successfully processed before the critical error retain their computed state.
// Given some vectors of a model are successfully computed and saved before that model then
// encounters a critical API error later in the same run, when the error is detected, then the
// already-saved vectors shall keep their computed value (not be rolled back or invalidated).

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

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_prior_vectors_retain_tmp.json")

Try
	// batchSize=1 forces one chunk per entity, so the first two entities are embedded and
	// saved successfully before the model's critical error is raised on the third call.
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: []}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $def : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_2"; $badmodel; "{firstName} {lastName}")
	
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
	
	// The first 2 calls to $badmodel succeed normally (students A and B); the 3rd call
	// (student C) throws the same critical error the real provider would raise mid-run
	// (e.g. the API key was revoked, or the model became unavailable, part-way through).
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({criticalAfterCalls: {badembed: 2}})
	var $proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	
	var $codes:=cs:C1710.ProcessErrorCode.me
	ASSERT:C1129(Not:C34($result.success); "batch should fail once the critical error is hit")
	ASSERT:C1129($result.hasFatal; "the mid-run critical error should be reported as fatal")
	ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=2; "the two vectors computed before the critical error should be saved")
	ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
	
	// Students A and B retain their computed vector and are no longer dirty.
	$studentA:=ds:C1482._Students.get($studentA.ID)
	$studentB:=ds:C1482._Students.get($studentB.ID)
	$studentC:=ds:C1482._Students.get($studentC.ID)
	ASSERT:C1129($studentA.student_vector_2#Null:C1517; "student A vector computed before the critical error should be retained")
	ASSERT:C1129($studentB.student_vector_2#Null:C1517; "student B vector computed before the critical error should be retained")
	ASSERT:C1129(Not:C34($studentA.student_vector_2_dirty); "student A should be clean after being saved")
	ASSERT:C1129(Not:C34($studentB.student_vector_2_dirty); "student B should be clean after being saved")
	
	// Student C (hit by the critical error) was never computed nor saved.
	ASSERT:C1129($studentC.student_vector_2=Null:C1517; "student C vector should never have been computed")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
