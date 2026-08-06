//%attributes = {}
// Local (4D-side / non-critical) embedding errors: the batch keeps going, failed vectors
// stay dirty for retry, and prior successes are never rolled back.

If (Not:C34(Asserted:C1132(cs:C1710._TestFixtures.me.ensureAliases(["embed"]); "you must configure an 'embed' model alias")))
	return 
End if 

var $EMBED_FAILED:=cs:C1710.ProcessErrorCode.me.EMBED_FAILED
var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_local_errors_tmp.json")

// batchSize=1 forces one chunk per entity, so a chunk-level local error on one entity
// cannot affect another entity processed in a separate chunk.
$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: "embed"; phrase: "{firstName} {lastName}"}]}))
var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
ASSERT:C1129($def#Null:C1517; "test definition missing")

//MARK:- test_process_dirtyFlagOnEmbedF
// The dirty flag stays true (and the old vector is preserved) when recalculation fails
// on the embedding call, before any save.
var $seed:=cs:C1710._TestFixtures.me.seedStudents(1)
var $student : 4D:C1709.Entity:=$seed.students[0]

var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
var $result : cs:C1710.ProcessResult:=$proc.process($def)  // first compute so a non-null vector exists
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")

$student:=ds:C1482._Students.get($student.ID)
ASSERT:C1129($student.student_vector_2#Null:C1517; "vector should remain non-null in dirty mode")
ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty should be true before failed recalculation")

$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})})
$result:=$proc.process($def)
ASSERT:C1129(Not:C34($result.success); "embed failure should mark process as failed")
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.query("code = :1"; $EMBED_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
$student:=ds:C1482._Students.get($student.ID)
ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty flag must remain true when recalculation fails")

//MARK:- test_pro_batchContinuesAfterLEr
// One local error on entity A does not stop the batch: B is still processed, A stays
// dirty, and a later run retries A successfully.
$seed:=cs:C1710._TestFixtures.me.seedStudents(2)
var $sA : 4D:C1709.Entity:=$seed.students[0]
var $sB : 4D:C1709.Entity:=$seed.students[1]

$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.process($def)  // compute once so invalidation can mark dirty
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")

$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})})
$result:=$proc.process($def)
ASSERT:C1129($result.entitiesConsidered=2; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Not:C34($result.success); "batch should report failure due to one local EMBED_FAILED")
ASSERT:C1129($result.entitiesUpdated=1; "one entity should still be saved despite local failure")
ASSERT:C1129($result.entitiesSkipped=1; "one entity should be skipped due to local failure")
ASSERT:C1129($result.errors.query("code = :1"; $EMBED_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
$sA:=ds:C1482._Students.get($sA.ID)
$sB:=ds:C1482._Students.get($sB.ID)
ASSERT:C1129(Bool:C1537($sA.student_vector_2_dirty); "failed vector should remain dirty for retry")
ASSERT:C1129(Not:C34($sB.student_vector_2_dirty); "remaining vector should be recomputed and saved")

$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.process($def)  // retry path
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=1; "only previously failed dirty vector should be retried")
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
$sA:=ds:C1482._Students.get($sA.ID)
ASSERT:C1129(Not:C34($sA.student_vector_2_dirty); "failed vector should be clean after retry")

//MARK:- test_pro_multiLocalErrorsInB
// Several vectors failing locally in the same run all stay dirty, while the rest are
// still processed; a later run retries only the failed ones.
$seed:=cs:C1710._TestFixtures.me.seedStudents(3)
$sA:=$seed.students[0]
$sB:=$seed.students[1]
var $sC : 4D:C1709.Entity:=$seed.students[2]

$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.process($def)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=3; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")

$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"; "Bob Martin"]})})
$result:=$proc.process($def)
ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129(Not:C34($result.success); "batch should report failure due to local EMBED_FAILED errors")
ASSERT:C1129($result.entitiesUpdated=1; "remaining vector should still be processed")
ASSERT:C1129($result.entitiesSkipped=2; "two vectors should fail locally")
ASSERT:C1129($result.errors.query("code = :1"; $EMBED_FAILED).length=2; JSON Stringify:C1217($result.toObject()))
$sA:=ds:C1482._Students.get($sA.ID)
$sB:=ds:C1482._Students.get($sB.ID)
$sC:=ds:C1482._Students.get($sC.ID)
ASSERT:C1129(Bool:C1537($sA.student_vector_2_dirty); "first failed vector should remain dirty")
ASSERT:C1129(Bool:C1537($sB.student_vector_2_dirty); "second failed vector should remain dirty")
ASSERT:C1129(Not:C34($sC.student_vector_2_dirty); "successful vector should be saved and cleaned")

$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.process($def)  // retry path
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=2; "only failed dirty vectors should be retried")
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
$sA:=ds:C1482._Students.get($sA.ID)
$sB:=ds:C1482._Students.get($sB.ID)
ASSERT:C1129(Not:C34($sA.student_vector_2_dirty); "first failed vector should be clean after retry")
ASSERT:C1129(Not:C34($sB.student_vector_2_dirty); "second failed vector should be clean after retry")

If ($settingsFile.exists)
	$settingsFile.delete()
End if 
