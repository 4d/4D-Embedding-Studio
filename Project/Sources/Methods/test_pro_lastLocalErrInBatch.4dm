//%attributes = {}
// Verifies that a local error on the last vector in a batch does not rollback
// prior successful vectors, and the failed one remains dirty for retry.

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

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_last_local_error_tmp.json")

Try
	// batchSize=1 forces one chunk per entity, so a chunk-level embedding error on the
	// LAST chunk cannot roll back or affect entities already saved in earlier chunks.
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
		{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
	ASSERT:C1129($def#Null:C1517; "test definition missing")
	
	// Deterministic fixture set (3 students in one batch).
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
	
	// Compute once so invalidateVectors sets dirty=true on non-null vectors.
	var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=3; JSON Stringify:C1217($result.toObject()))
	
	ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
	
	// Force a genuine local 4D-side error on exactly the LAST vector's computation
	// (student C's rendered phrase) via the already-proven throw mechanism used by
	// _TestProcessEmbedder. With batchSize=1, students A and B are each processed and
	// saved in their own prior chunk before the failing chunk for C ever runs, so their
	// success cannot depend on, or be rolled back by, C's failure.
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Chloe Bernard"]})
	$proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	$result:=$proc.process($def)
	var $embedFailedCount : Integer:=$result.errors.query("code = :1"; cs:C1710.ProcessErrorCode.me.EMBED_FAILED).length
	
	ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($embedFailedCount=1; "exact scenario required: expected one local EMBED_FAILED on last vector")
	ASSERT:C1129(Not:C34($result.success); "batch should report failure for last vector local error")
	ASSERT:C1129($result.entitiesUpdated=2; "prior vectors should still be processed successfully")
	ASSERT:C1129($result.entitiesSkipped=1; "last vector should fail locally")
	
	var $dirtyCount : Integer:=ds:C1482._Students.query("student_vector_2_dirty = true").length
	var $cleanCount : Integer:=ds:C1482._Students.query("student_vector_2_dirty = false").length
	ASSERT:C1129($dirtyCount=1; "exactly one vector should remain dirty after local error")
	ASSERT:C1129($cleanCount=2; "two prior vectors should be saved and clean")
	$studentC:=ds:C1482._Students.get($studentC.ID)
	ASSERT:C1129($studentC.student_vector_2_dirty; "the specific failed entity (student C) must remain dirty")
	
	// Next run retries only the previously-failed dirty vector (student C).
	$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	$result:=$proc.process($def)
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesConsidered=1; "only the failed last dirty vector should be retried")
	ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
	$dirtyCount:=ds:C1482._Students.query("student_vector_2_dirty = true").length
	ASSERT:C1129($dirtyCount=0; "all vectors should be clean after retry")
	
Catch
	throw:C1805(Last errors:C1799[0])
	
End try
If ($settingsFile.exists)
	$settingsFile.delete()
End if 