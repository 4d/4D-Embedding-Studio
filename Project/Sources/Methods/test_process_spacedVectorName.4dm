//%attributes = {}
// A 4D field name may contain a space. Such a name cannot be interpolated into an ORDA
// query string, so every query built from a definition passes the attribute path as a
// placeholder — this test walks a full definition on "student vector 3" to keep it that way.

var $fx : cs:C1710._TestFixtures:=cs:C1710._TestFixtures.me

If (Not:C34(Asserted:C1132($fx.ensureAliases(["embed"]); "you must configure an 'embed' model alias")))
	return 
End if 

var $vectorName : Text:="student vector 3"
var $dirtyName : Text:=$vectorName+"_dirty"

ASSERT:C1129(cs:C1710._dataclassAttributes.me.hasField(ds:C1482._Students; $vectorName); "fixture field \""+$vectorName+"\" is missing from the structure")
ASSERT:C1129(cs:C1710._dataclassAttributes.me.hasField(ds:C1482._Students; $dirtyName); "fixture field \""+$dirtyName+"\" is missing from the structure")

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_spaced_vector_tmp.json")
$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: [\
{dataclassName: "_Students"; vectorName: $vectorName; modelAlias: "embed"; phrase: "{firstName} {lastName}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $def : cs:C1710.Definition:=$settings.find("_Students"; $vectorName)
ASSERT:C1129($def#Null:C1517; "the definition on a spaced vector name should load")

// ══════════════════════════════════════════════════════════════════════
// VALIDATION — the name is legal 4D, it must be accepted
// ══════════════════════════════════════════════════════════════════════

//MARK:- validate accepts a spaced vector name
var $validation : Object:=$def.validate($settings)
ASSERT:C1129($validation.success; "spaced vector name should validate, got "+JSON Stringify:C1217($validation.errors))

// ══════════════════════════════════════════════════════════════════════
// FIRST RUN — the needs-recompute filter must find the null vectors
// ══════════════════════════════════════════════════════════════════════

//MARK:- entities are computed
var $seed : Object:=$fx.seedStudents(3)
ASSERT:C1129($seed.students.length=3; "seed: expected 3 students")

var $embedder : Object:=cs:C1710._TestProcessEmbedder.new()
var $report : cs:C1710.ProcessResult:=cs:C1710.Process.new($settings; {embedder: $embedder}).process()

ASSERT:C1129($report.success; "first run should succeed, errors: "+JSON Stringify:C1217($report.errors))
ASSERT:C1129($report.entitiesConsidered=3; "first run: 3 entities should need a vector, got "+String:C10($report.entitiesConsidered))
ASSERT:C1129($report.entitiesUpdated=3; "first run: 3 entities should be updated, got "+String:C10($report.entitiesUpdated))
ASSERT:C1129(ds:C1482._Students.all().query(":1 != null"; $vectorName).length=3; "first run: every student should hold a vector")
ASSERT:C1129(ds:C1482._Students.all().query(":1 = true"; $dirtyName).length=0; "first run: the dirty flag should be cleared")

// ══════════════════════════════════════════════════════════════════════
// SECOND RUN — nothing is pending any more
// ══════════════════════════════════════════════════════════════════════

//MARK:- nothing left to recompute
$report:=cs:C1710.Process.new($settings; {embedder: $embedder}).process()
ASSERT:C1129($report.entitiesConsidered=0; "second run: nothing should be pending, got "+String:C10($report.entitiesConsidered))

// ══════════════════════════════════════════════════════════════════════
// INVALIDATION — same placeholder path, from Definition
// ══════════════════════════════════════════════════════════════════════

//MARK:- invalidateVectors flags every computed entity
ASSERT:C1129($def._hasVectorComputed(); "computed vectors should be detected")

var $invalidated : Object:=$def.invalidateVectors()
ASSERT:C1129($invalidated.errors.length=0; "invalidateVectors: no error expected, got "+JSON Stringify:C1217($invalidated.errors))
ASSERT:C1129($invalidated.updated=3; "invalidateVectors: 3 entities should be flagged, got "+String:C10($invalidated.updated))
ASSERT:C1129(ds:C1482._Students.all().query(":1 = true"; $dirtyName).length=3; "invalidateVectors: every student should be dirty")
ASSERT:C1129(Not:C34($def._hasVectorComputed()); "invalidateVectors: no clean computed vector should be left")

// ══════════════════════════════════════════════════════════════════════
// THIRD RUN — the "OR dirty" branch of the filter
// ══════════════════════════════════════════════════════════════════════

//MARK:- dirty entities are picked up again
$report:=cs:C1710.Process.new($settings; {embedder: $embedder}).process()
ASSERT:C1129($report.entitiesConsidered=3; "third run: the 3 dirty entities should be considered, got "+String:C10($report.entitiesConsidered))
ASSERT:C1129($report.entitiesUpdated=3; "third run: the 3 dirty entities should be recomputed, got "+String:C10($report.entitiesUpdated))
ASSERT:C1129(ds:C1482._Students.all().query(":1 = true"; $dirtyName).length=0; "third run: the dirty flag should be cleared again")

// ══════════════════════════════════════════════════════════════════════
// CLEANUP
// ══════════════════════════════════════════════════════════════════════

var $student : cs:C1710.Entity
For each ($student; ds:C1482._Students.all())
	$student[$vectorName]:=Null:C1517
	$student[$dirtyName]:=False:C215
	$student.save()
End for each 

If ($settingsFile.exists)
	$settingsFile.delete()
End if 
