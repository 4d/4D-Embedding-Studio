//%attributes = {}
// Verifies that a local 4D-side error on one vector does not stop the batch:
// remaining vectors are still processed, and the failed one stays dirty for retry.

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

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_batch_continue_local_error_tmp.json")

Try
	// batchSize=1 forces one chunk per entity, so a chunk-level local embedding error
	// on student A cannot affect student B, who is processed in a separate chunk.
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
		{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
	ASSERT:C1129($def#Null:C1517; "test definition missing")
	
	// Deterministic fixture set (2 students in the same batch).
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
	
	// Compute once so invalidation sets dirty=true on non-null vectors.
	var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))

	ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
	
	$studentA:=ds:C1482._Students.get($studentA.ID)
	$studentB:=ds:C1482._Students.get($studentB.ID)
	ASSERT:C1129(Bool:C1537($studentA.student_vector_2_dirty); "student A should be dirty before run")
	ASSERT:C1129(Bool:C1537($studentB.student_vector_2_dirty); "student B should be dirty before run")
	
	// Deterministic local 4D-side error: student A's rendered phrase always throws a
	// non-critical error inside the embedder (the same proven mechanism used by
	// test_process_dirtyFlagOnEmbedF.4dm). Student B's chunk is unaffected.
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})
	
	$proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	$result:=$proc.process($def)

	ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129(Not:C34($result.success); "batch should report failure due to one local EMBED_FAILED")
	ASSERT:C1129($result.entitiesUpdated=1; "one entity should still be saved despite local failure")
	ASSERT:C1129($result.entitiesSkipped=1; "one entity should be skipped due to local failure")
	ASSERT:C1129($result.errors.query("code = :1"; cs:C1710.ProcessErrorCode.me.EMBED_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
	
	$studentA:=ds:C1482._Students.get($studentA.ID)
	$studentB:=ds:C1482._Students.get($studentB.ID)
	ASSERT:C1129(Bool:C1537($studentA.student_vector_2_dirty); "failed vector should remain dirty for retry")
	ASSERT:C1129(Not:C34($studentB.student_vector_2_dirty); "remaining vector should be recomputed and saved")

	// Retry path (next scheduled/manual run): previously failed dirty vector must succeed.
	$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	$result:=$proc.process($def)
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesConsidered=1; "only previously failed dirty vector should be retried")
	ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
	$studentA:=ds:C1482._Students.get($studentA.ID)
	ASSERT:C1129(Not:C34($studentA.student_vector_2_dirty); "failed vector should be clean after retry")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 