//%attributes = {}
// Critical / model-level failure behaviour of cs.Process.

If (Not:C34(Asserted:C1132(cs:C1710._TestFixtures.me.ensureAliases(["embed"; "badembed"; "badembed2"]); "you must configure 'embed', 'badembed' and 'badembed2' model aliases")))
	return
End if

var $codes:=cs:C1710.ProcessErrorCode.me
var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_critical_tmp.json")

//MARK:- test_pro_criticalStopsSameModel / test_pro_criticalStopsUnavailM
// A critical API error (invalid key / model unavailable) stops the batch for ALL
// vectors of the affected model. Proven at two granularities from the same fixture:
//   - batchSize=1  : once detected, no further entity of that model is ever attempted
//   - batchSize=50 : the whole chunk (every pending entity) is skipped together
var $seed:=cs:C1710._TestFixtures.me.seedStudents(3)
var $sA : 4D:C1709.Entity:=$seed.students[0]
var $sB : 4D:C1709.Entity:=$seed.students[1]
var $sC : 4D:C1709.Entity:=$seed.students[2]
var $def : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_1"; "badembed"; "{firstName} {lastName}")

// batchSize=1 : per-entity chunks; every call to 'badembed' is a simulated auth error.
$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: []}))
var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: ["badembed"]})})
var $result : cs:C1710.ProcessResult:=$proc.process($def)

ASSERT:C1129(Not:C34($result.success); "batchSize=1: batch should fail on critical API error")
ASSERT:C1129($result.hasFatal; "batchSize=1: invalid API key error should be reported as fatal")
ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; "batchSize=1: no vector using the affected model should be updated")
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE)[0].severity="fatal"; JSON Stringify:C1217($result.toObject()))
$sA:=ds:C1482._Students.get($sA.ID)
$sB:=ds:C1482._Students.get($sB.ID)
$sC:=ds:C1482._Students.get($sC.ID)
ASSERT:C1129($sA.student_vector_1=Null:C1517; "batchSize=1: student A vector should never have been computed")
ASSERT:C1129($sB.student_vector_1=Null:C1517; "batchSize=1: student B vector should never have been computed")
ASSERT:C1129($sC.student_vector_1=Null:C1517; "batchSize=1: student C vector should never have been computed")

// batchSize=50 : a single chunk covers every pending entity, so the model-unavailable
// error fails the whole chunk at once (vectors are still null from the run above).
$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: []}))
$settings:=cs:C1710.Settings.new($settingsFile)
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: ["badembed"]})})
$result:=$proc.process($def)

ASSERT:C1129(Not:C34($result.success); "batchSize=50: batch should fail on model unavailable error")
ASSERT:C1129($result.hasFatal; "batchSize=50: model unavailable error should be reported as fatal")
ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; "batchSize=50: no vector using the affected model should be updated")
ASSERT:C1129($result.entitiesSkipped=3; "batchSize=50: all vectors of the single chunk should be skipped together")
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))

//MARK:- test_pro_multiModelsFail / test_pro_otherModelsContinue
// Several models each hit their own critical error; only the vectors of THAT model stop,
// while a definition on a third, healthy model still completes normally.
$seed:=cs:C1710._TestFixtures.me.seedStudents(1)
var $student : 4D:C1709.Entity:=$seed.students[0]
var $school : 4D:C1709.Entity:=$seed.school
var $badDef1 : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_1"; "badembed"; "{firstName} {lastName}")
var $badDef2 : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_2"; "badembed2"; "{lastName} {firstName}")
var $goodDef : cs:C1710.Definition:=cs:C1710.Definition.new("School"; "school_vector_1"; "embed"; "{name}")

$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: []}))
$settings:=cs:C1710.Settings.new($settingsFile)
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: ["badembed"; "badembed2"]})})
$result:=$proc.process([$badDef1; $badDef2; $goodDef])

ASSERT:C1129(Not:C34($result.success); "multi: batch should report failure due to the two bad models")
ASSERT:C1129($result.hasFatal; "multi: both critical model errors should be reported as fatal")
ASSERT:C1129($result.definitionsProcessed=3; "multi: all three definitions should have been attempted")
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=2; "multi: each bad model should report its own MODEL_UNAVAILABLE error")
$student:=ds:C1482._Students.get($student.ID)
ASSERT:C1129($student.student_vector_1=Null:C1517; "multi: student vector 1 (bad model 1) should never have been computed")
ASSERT:C1129($student.student_vector_2=Null:C1517; "multi: student vector 2 (bad model 2) should never have been computed")
$school:=ds:C1482.School.get($school.ID)
ASSERT:C1129($school.school_vector_1#Null:C1517; "multi: school vector (healthy model) should have been computed")
ASSERT:C1129($result.entitiesUpdated=1; "multi: only the healthy model's entity should have been updated")

//MARK:- test_pro_singleMClSAll
// Only one model is configured for the whole run: when it fails critically the entire
// run stops (nothing succeeds), since no other model exists to keep processing.
$seed:=cs:C1710._TestFixtures.me.seedStudents(2)
$sA:=$seed.students[0]
$sB:=$seed.students[1]
$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "badembed"; phrase: "{firstName} {lastName}"}]}))
$settings:=cs:C1710.Settings.new($settingsFile)
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: ["badembed"]})})
$result:=$proc.process()  // full run: resolves every definition in settings (here, just one)

ASSERT:C1129(Not:C34($result.success); "single: the entire run should fail")
ASSERT:C1129($result.hasFatal; "single: critical error should be reported as fatal")
ASSERT:C1129($result.definitionsProcessed=1; "single: the single definition should have been attempted")
ASSERT:C1129($result.entitiesUpdated=0; "single: nothing should succeed when the only model fails")
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
$sA:=ds:C1482._Students.get($sA.ID)
$sB:=ds:C1482._Students.get($sB.ID)
ASSERT:C1129($sA.student_vector_1=Null:C1517; "single: student A vector should never have been computed")
ASSERT:C1129($sB.student_vector_1=Null:C1517; "single: student B vector should never have been computed")

//MARK:- test_pro_priorVectorsROnC
// Vectors computed & saved before a mid-run critical error keep their value (not rolled
// back). batchSize=1: first two entities succeed, the 3rd call raises the critical error.
$seed:=cs:C1710._TestFixtures.me.seedStudents(3)
$sA:=$seed.students[0]
$sB:=$seed.students[1]
$sC:=$seed.students[2]
$def:=cs:C1710.Definition.new("_Students"; "student_vector_2"; "badembed"; "{firstName} {lastName}")
$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: []}))
$settings:=cs:C1710.Settings.new($settingsFile)
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalAfterCalls: {badembed: 2}})})
$result:=$proc.process($def)

ASSERT:C1129(Not:C34($result.success); "prior: batch should fail once the critical error is hit")
ASSERT:C1129($result.hasFatal; "prior: the mid-run critical error should be reported as fatal")
ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; "prior: the two vectors computed before the critical error should be saved")
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; JSON Stringify:C1217($result.toObject()))
$sA:=ds:C1482._Students.get($sA.ID)
$sB:=ds:C1482._Students.get($sB.ID)
$sC:=ds:C1482._Students.get($sC.ID)
ASSERT:C1129($sA.student_vector_2#Null:C1517; "prior: student A vector computed before the critical error should be retained")
ASSERT:C1129($sB.student_vector_2#Null:C1517; "prior: student B vector computed before the critical error should be retained")
ASSERT:C1129(Not:C34($sA.student_vector_2_dirty); "prior: student A should be clean after being saved")
ASSERT:C1129(Not:C34($sB.student_vector_2_dirty); "prior: student B should be clean after being saved")
ASSERT:C1129($sC.student_vector_2=Null:C1517; "prior: student C vector should never have been computed")

//MARK:- test_pro_vectorsSavedBeforeRL
// Same durability guarantee, but for a transient 429 instead of a critical error:
// the vector saved before the rate-limit blip survives, and all entities eventually embed.
// Uses the REAL cs.Embedder over a fake AIKit client (no network).
$seed:=cs:C1710._TestFixtures.me.seedStudents(3)
$sA:=$seed.students[0]
$sB:=$seed.students[1]
$sC:=$seed.students[2]
$def:=cs:C1710.Definition.new("_Students"; "student_vector_2"; "embed"; "{firstName} {lastName}")
$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: []}))
$settings:=cs:C1710.Settings.new($settingsFile)

// call #1 = Alice (ok), call #2 = Bob (429, retried as call #3 = ok), call #4 = Chloe (ok).
var $rlClient:=cs:C1710._TestAIKitClient.new({failOnCallNumbers: [2]; backoffMs: 10})
var $rlEmbedder:=cs:C1710.Embedder.new({client: $rlClient; backoffMs: 10; maxRetries: 3})
$proc:=cs:C1710.Process.new($settings; {embedder: $rlEmbedder})
$result:=$proc.process($def)

ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesConsidered=3; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=3; "rl: all 3 students should end up embedded despite the mid-run rate limit blip")
ASSERT:C1129($rlClient.embeddings.callCount=4; "rl: expected 4 calls (Alice, Bob 429, Bob retry, Chloe), got "+String:C10($rlClient.embeddings.callCount))
$sA:=ds:C1482._Students.get($sA.ID)
$sB:=ds:C1482._Students.get($sB.ID)
$sC:=ds:C1482._Students.get($sC.ID)
ASSERT:C1129(($sA.student_vector_2#Null:C1517) && Not:C34($sA.student_vector_2_dirty); "rl: student A (before the blip) should be saved and clean")
ASSERT:C1129(($sB.student_vector_2#Null:C1517) && Not:C34($sB.student_vector_2_dirty); "rl: student B (retried) should be saved and clean")
ASSERT:C1129(($sC.student_vector_2#Null:C1517) && Not:C34($sC.student_vector_2_dirty); "rl: student C (after the blip) should be saved and clean")

If ($settingsFile.exists)
	$settingsFile.delete()
End if
