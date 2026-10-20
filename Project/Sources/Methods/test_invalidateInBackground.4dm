//%attributes = {}
// _invalidateVectorsInBackground, posted by cs._EMBEDDINGS.flushPromptInvalidate() when the
// user agrees to recalculate: the invalidation runs in the "EmbeddingStudio_invalidate"
// worker (not in the window), and the follow-up ($then, e.g. a compute) only runs after it.
// While it runs, Storage.studio.operation names it for the footer status bar.

If (Storage:C1525.studio=Null:C1517)  // Headless: no studio window has created it
	Use (Storage:C1525)
		Storage:C1525.studio:=New shared object:C1526("EMBEDDINGS"; 0; "MODELS"; 0; "SCHEDULER"; 0)
	End use 
End if 

var $seed : Object:=cs:C1710._TestFixtures.me.seedStudents(3)
var $student : 4D:C1709.Entity
For each ($student; $seed.students)
	$student.reload()
	$student.student_vector_1:=4D:C1709.Vector.new([1; 2; 3])  // no _dirty companion: nullified
	$student.student_vector_2:=4D:C1709.Vector.new([1; 2; 3])  // _dirty companion: flagged
	$student.student_vector_2_dirty:=False:C215
	ASSERT:C1129($student.save().success; "setup: failed to seed the vectors")
End for each 

// $then writes what it sees: it must find the invalidation done
var $seen : 4D:C1709.File:=Folder:C1567(Temporary folder:C486; fk platform path:K87:2).file("test_invalidateInBackground_"+Generate UUID:C1066+".json")
var $then : 4D:C1709.Function:=Formula:C1597($1.setText(JSON Stringify:C1217({\
vector1: ds:C1482._Students.query("student_vector_1 != null").length; \
clean2: ds:C1482._Students.query("student_vector_2_dirty = false").length; \
operation: String:C10(Storage:C1525.studio.operation)})))

CALL WORKER:C1389("EmbeddingStudio_invalidate"; "_invalidateVectorsInBackground"; [\
{dataclassName: "_Students"; vectorName: "student_vector_1"}; \
{dataclassName: "_Students"; vectorName: "student_vector_2"}]; $then; $seen)

// up to ~10s for both workers
var $waited : Integer:=0
While ((Not:C34($seen.exists)) && ($waited<600))
	DELAY PROCESS:C323(Current process:C322; 6)
	$waited+=6
End while 

//MARK:- the vectors are invalidated by the worker
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 != null").length=0; "background: student_vector_1 should be nullified")
ASSERT:C1129(ds:C1482._Students.query("student_vector_2_dirty = true").length=3; "background: student_vector_2 should be flagged dirty")
ASSERT:C1129(ds:C1482._Students.query("student_vector_2 != null").length=3; "background: student_vector_2 should be kept (dirty mode)")

//MARK:- the follow-up runs after the invalidation
ASSERT:C1129($seen.exists; "then: the follow-up should have run in the EmbeddingStudio worker")
If ($seen.exists)
	var $after : Object:=JSON Parse:C1218($seen.getText())
	ASSERT:C1129($after.vector1=0; "then: should run after student_vector_1 is nullified, saw "+String:C10($after.vector1))
	ASSERT:C1129($after.clean2=0; "then: should run after student_vector_2 is flagged, saw "+String:C10($after.clean2)+" clean")
	ASSERT:C1129($after.operation=""; "then: the footer operation should be cleared, got "+String:C10($after.operation))
	$seen.delete()
End if 

// ══════════════════════════════════════════════════════════════════════
// CLEANUP
// ══════════════════════════════════════════════════════════════════════

ds:C1482._Students.all().drop()
ds:C1482.School.all().drop()
ds:C1482.Cities.all().drop()
