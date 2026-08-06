//%attributes = {}
// Verify vectors already processed before a rate limit error remain saved.
// Given a batch of 3 students processed one-at-a-time (batchSize=1), when the
// 2nd student's embedding call hits a transient 429 and must be retried, then
// the 1st student's vector — already computed and saved before the rate limit
// event — must still be present and clean once the whole run completes, and
// every student must eventually be embedded successfully.

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

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model alias")))
	return 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_ratelimit_saved_tmp.json")

Try
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: []}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $def : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_2"; $model; "{firstName} {lastName}")
	
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
	
	// batchSize=1: call #1 = Alice (succeeds immediately), call #2 = Bob (rate-limited,
	// retried as call #3 which succeeds), call #4 = Chloe (succeeds immediately).
	var $client:=cs:C1710._TestAIKitClient.new({failOnCallNumbers: [2]; backoffMs: 10})
	var $realEmbedder:=cs:C1710.Embedder.new({client: $client; backoffMs: 10; maxRetries: 3})
	
	var $proc:=cs:C1710.Process.new($settings; {embedder: $realEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=3; "all 3 students should end up embedded despite the mid-run rate limit blip")
	ASSERT:C1129($client.embeddings.callCount=4; "expected 4 calls (Alice, Bob rate-limited, Bob retry, Chloe), got "+String:C10($client.embeddings.callCount))
	
	$studentA:=ds:C1482._Students.get($studentA.ID)
	$studentB:=ds:C1482._Students.get($studentB.ID)
	$studentC:=ds:C1482._Students.get($studentC.ID)
	
	ASSERT:C1129($studentA.student_vector_2#Null:C1517; "student A (processed before the rate limit event) should have a saved vector")
	ASSERT:C1129(Not:C34($studentA.student_vector_2_dirty); "student A should be clean after being saved")
	ASSERT:C1129($studentB.student_vector_2#Null:C1517; "student B (retried after the rate limit event) should have a saved vector")
	ASSERT:C1129(Not:C34($studentB.student_vector_2_dirty); "student B should be clean after being saved")
	ASSERT:C1129($studentC.student_vector_2#Null:C1517; "student C (processed after the rate limit event) should have a saved vector")
	ASSERT:C1129(Not:C34($studentC.student_vector_2_dirty); "student C should be clean after being saved")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
