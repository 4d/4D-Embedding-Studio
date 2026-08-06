//%attributes = {}
// Optimistic-lock save failure during recomputation: the vector stays dirty for retry and
// the 'Vector still dirty after save during recomputation' event is logged.
//
// Some ORDA runtimes do not reproduce optimistic-lock conflicts deterministically, so a
// probe mirrors EXACTLY Process._processChunk()'s double "For each (entity; $chunk)" pattern
// (render pass, a concurrent save from elsewhere, then the persist pass) to decide whether
// this code path can actually reproduce a conflict here before asserting on it.

If (Not:C34(Asserted:C1132(cs:C1710._TestFixtures.me.ensureAliases(["embed"]); "you must configure an 'embed' model alias")))
	return 
End if 

var $SAVE_FAILED:=cs:C1710.ProcessErrorCode.me.SAVE_FAILED
var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_optimistic_lock_tmp.json")

$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: "embed"; phrase: "{firstName} {lastName}"}]}))
var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
ASSERT:C1129($def#Null:C1517; "test definition missing")

var $seed:=cs:C1710._TestFixtures.me.seedStudents(1)
var $student : 4D:C1709.Entity:=$seed.students[0]

// Compute once so the vector exists before invalidation.
var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
var $result : cs:C1710.ProcessResult:=$proc.process($def)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))

// Probe support by mirroring the exact double-For-each pattern over the same selection.
var $optimisticSupported : Boolean:=False:C215
var $probeSel : 4D:C1709.EntitySelection:=ds:C1482._Students.query("ID = :1"; $student.ID)
var $probeEntity : 4D:C1709.Entity

For each ($probeEntity; $probeSel)  // mirrors the phrase-render pass
End for each 

var $touchEntity : 4D:C1709.Entity:=ds:C1482._Students.get($student.ID)  // mirrors _touchConcurrentEntity()
$touchEntity.lastName:=String:C10($touchEntity.lastName)+"_probetouch"
ASSERT:C1129($touchEntity.save().success; "probe concurrent touch save failed unexpectedly")

For each ($probeEntity; $probeSel)  // mirrors the persist pass
	$probeEntity.lastName:=String:C10($probeEntity.lastName)+"_probesave"
	$optimisticSupported:=Not:C34($probeEntity.save().success)
End for each 

$student:=ds:C1482._Students.get($student.ID)
$student.lastName:="Durand"
ASSERT:C1129($student.save().success; "failed to restore student lastName after probe")

ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
$student:=ds:C1482._Students.get($student.ID)
ASSERT:C1129($student.student_vector_2#Null:C1517; "vector should remain non-null in dirty mode")
ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty should be true after invalidation")

// This embedder touches the same row inside embedBatch() to stale the snapshot and force
// an optimistic-lock save failure (formerly the dedicated _TestProcessEmbedderOptimisticLock).
var $conflictEmbedder:=cs:C1710._TestProcessEmbedder.new({\
	dataclassName: "_Students"; \
	entityKey: $student.ID; \
	touchField: "lastName"; \
	touchSuffix: "_concurrent"})

cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: $conflictEmbedder})
$result:=$proc.process($def)
var $logs : Collection:=cs:C1710._Logger.me._capture
cs:C1710._Logger.me._capture:=Null:C1517

ASSERT:C1129($conflictEmbedder.touchCount=1; "concurrent touch should have happened exactly once")

If ($optimisticSupported)
	
	//MARK:- test_process_optimisticLockDirty
	ASSERT:C1129(Not:C34($result.success); "optimistic lock scenario should report failure")
	ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.errors.query("code = :1"; $SAVE_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
	$student:=ds:C1482._Students.get($student.ID)
	ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty flag must remain true when save fails")
	
	//MARK:- test_pro_logDirtyAfterConflict
	var $dirtyLogs : Collection:=$logs.query("level = :1 AND message = :2"; Information message:K38:1; "@\"event\":\"Vector still dirty after save during recomputation\"@")
	ASSERT:C1129($dirtyLogs.length=1; "expected exactly one Info-level 'Vector still dirty after save' log, got "+String:C10($dirtyLogs.length))
	var $dirtyMsg : Text:=$dirtyLogs[0].message
	ASSERT:C1129(Position:C15("\"vector\":\"_Students.student_vector_2\""; $dirtyMsg)>0; "log should include the vector reference: "+$dirtyMsg)
	ASSERT:C1129(Position:C15("\"entityID\":"; $dirtyMsg)>0; "log should include the entity id: "+$dirtyMsg)
	ASSERT:C1129(Position:C15("\"timestamp\":\""; $dirtyMsg)>0; "log should include a timestamp: "+$dirtyMsg)
	
Else 
	
	// Without reproducible conflict support, recalculation simply succeeds.
	ASSERT:C1129($result.success; "without optimistic conflict support recalculation should succeed")
	ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
	$student:=ds:C1482._Students.get($student.ID)
	ASSERT:C1129(Not:C34($student.student_vector_2_dirty); "without conflict dirty should be cleared")
	
End if 

If ($settingsFile.exists)
	$settingsFile.delete()
End if 
