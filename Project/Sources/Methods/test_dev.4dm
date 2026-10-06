//%attributes = {}
// Runs the dev-only helpers of the studio dev menus (_computeVectors, _invalidateVectors,
// _statVectors, _runInWorker) against a temporary settings file and the mock embedder.
// Their ALERT / CONFIRM go through cs._Dialog, captured here: nothing is displayed, the
// scripted answers drive them, and the messages are checked. Runs headless too.

If (Not:C34(Asserted:C1132(cs:C1710._TestFixtures.me.ensureAliases(["embed"]); "you must configure an 'embed' model alias")))
	return
End if

var $prevFile : 4D:C1709.File:=cs:C1710._Settings.me.file
var $tmp : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_dev_tmp.json")
var $execLog : cs:C1710._ExecutionLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""
var $dialog : cs:C1710._Dialog:=cs:C1710._Dialog.me
var $messages : Collection

// the mock embedder: no API call
var $definitions : Collection:=[\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "embed"; phrase: "{firstName} {lastName}"}; \
{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: "embed"; phrase: "{lastName}"}]
$tmp.setText(JSON Stringify:C1217({embedder: {className: "_TestProcessEmbedder"}; definitions: $definitions}))
cs:C1710._Settings.me.file:=$tmp

var $studentsDef : cs:C1710.Definition:=cs:C1710.Settings.new($tmp).find("_Students"; "student_vector_1")
cs:C1710._TestFixtures.me.seedStudents(2)

// ══════════════════════════════════════════════════════════════════════
// _computeVectors
// ══════════════════════════════════════════════════════════════════════

//MARK:- no settings file: says where it is expected
cs:C1710._Settings.me.file:=$tmp.parent.file("__test_dev_missing.json")
$dialog._capture:=[]
_computeVectors
$messages:=$dialog._capture
ASSERT:C1129(($messages.length=1) && ($messages[0].kind="alert"); "compute, no file: expected one alert, got "+JSON Stringify:C1217($messages))
ASSERT:C1129(Position:C15("Settings file not found"; $messages[0].message)>0; "compute, no file: "+$messages[0].message)
cs:C1710._Settings.me.file:=$tmp

//MARK:- no definition: says so
$tmp.setText(JSON Stringify:C1217({definitions: []}))
$dialog._capture:=[]
_computeVectors
$messages:=$dialog._capture
ASSERT:C1129(($messages.length=1) && (Position:C15("No vector definitions"; $messages[0].message)>0); "compute, no definition: "+JSON Stringify:C1217($messages))

//MARK:- missing model and phrase: asks, and stops on no
$tmp.setText(JSON Stringify:C1217({definitions: [{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: ""; phrase: ""}]}))
$dialog._capture:=[]
$dialog._answers:=[False:C215]
_computeVectors
$messages:=$dialog._capture
ASSERT:C1129($messages.length=1; "compute, incomplete: only the question expected, got "+JSON Stringify:C1217($messages))
ASSERT:C1129($messages[0].kind="confirm"; "compute, incomplete: should ask before going on")
ASSERT:C1129(Position:C15("no model"; $messages[0].message)>0; "compute, incomplete: should report the missing model")
ASSERT:C1129(Position:C15("phrase is empty"; $messages[0].message)>0; "compute, incomplete: should report the empty phrase")

//MARK:- complete settings, small dataclass not seeded: computes and reports success
$tmp.setText(JSON Stringify:C1217({embedder: {className: "_TestProcessEmbedder"}; definitions: $definitions}))
$dialog._capture:=[]
$dialog._answers:=[False:C215; False:C215]  // do not seed (asked once per definition)
_computeVectors
$messages:=$dialog._capture
ASSERT:C1129($messages.query("kind = :1"; "confirm").length=2; "compute: expected one seeding question per definition, got "+JSON Stringify:C1217($messages))
ASSERT:C1129(Position:C15("Configuration OK"; $messages.last().message)>0; "compute: should report success, got "+$messages.last().message)
ASSERT:C1129(ds:C1482._Students.all().length=2; "compute: no test data should be seeded on no")
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 = null").length=0; "compute: student_vector_1 should be computed")
ASSERT:C1129(ds:C1482._Students.query("student_vector_2 = null").length=0; "compute: student_vector_2 should be computed")

//MARK:- one definition, seeding accepted: creates test entities, then computes them
$dialog._capture:=[]
$dialog._answers:=[True:C214]
_computeVectors($studentsDef)
$messages:=$dialog._capture
ASSERT:C1129($messages.query("message = :1"; "@Test data seeded@").length=1; "compute, seeding: should report the seeded data, got "+JSON Stringify:C1217($messages))
ASSERT:C1129(ds:C1482._Students.all().length=102; "compute, seeding: 100 test entities should be created, got "+String:C10(ds:C1482._Students.all().length))
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 = null").length=0; "compute, seeding: the seeded entities should be computed too")
ASSERT:C1129(Position:C15("Configuration OK"; $messages.last().message)>0; "compute, seeding: should report success, got "+$messages.last().message)

//MARK:- a definition that does not validate: reports the errors (no seeding question: enough data now)
$tmp.setText(JSON Stringify:C1217({embedder: {className: "_TestProcessEmbedder"}; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "embed"; phrase: "{nonExistent}"}]}))
$dialog._capture:=[]
_computeVectors
$messages:=$dialog._capture
ASSERT:C1129($messages.length=1; "compute, invalid: only the report expected, got "+JSON Stringify:C1217($messages))
ASSERT:C1129(Position:C15("error(s)"; $messages[0].message)>0; "compute, invalid: should report the errors, got "+$messages[0].message)
ASSERT:C1129(Position:C15("nonExistent"; $messages[0].message)>0; "compute, invalid: should name the faulty attribute")

$tmp.setText(JSON Stringify:C1217({embedder: {className: "_TestProcessEmbedder"}; definitions: $definitions}))

// ══════════════════════════════════════════════════════════════════════
// _statVectors
// ══════════════════════════════════════════════════════════════════════

// some history to show next to the counts
If ($histFile.exists)
	$histFile.delete()
End if
$execLog.startFullRun("2026-01-01T00:00:00")
$execLog.updateDefinition("_Students.student_vector_1"; "2026-01-01T00:00:00"; "2026-01-01T00:00:05"; "failed"; "boom"; {prompt_tokens: 10; total_tokens: 12})
$execLog.endFullRun("2026-01-01T00:00:00"; "2026-01-01T00:00:06"; "failed"; "boom"; Null:C1517; {prompt_tokens: 10; total_tokens: 12})

//MARK:- every definition: counts, attributes, history and summary
$dialog._capture:=[]
_statVectors
$messages:=$dialog._capture
ASSERT:C1129($messages.length=1; "stat: one report expected, got "+JSON Stringify:C1217($messages))
var $report : Text:=$messages[0].message
ASSERT:C1129(Position:C15("_Students.student_vector_1"; $report)>0; "stat: should list student_vector_1")
ASSERT:C1129(Position:C15("_Students.student_vector_2"; $report)>0; "stat: should list student_vector_2")
ASSERT:C1129(Position:C15("total:    102"; $report)>0; "stat: should count the entities: "+$report)
ASSERT:C1129(Position:C15("firstName:"; $report)>0; "stat: should count empty phrase attributes: "+$report)
ASSERT:C1129(Position:C15("last run: 2026-01-01T00:00:05 (failed)"; $report)>0; "stat: should show the last run of the definition: "+$report)
ASSERT:C1129(Position:C15("tokens (last):  10 prompt / 12 total"; $report)>0; "stat: should show the tokens of the definition: "+$report)
ASSERT:C1129(Position:C15("Summary (2 definitions)"; $report)>0; "stat: should summarize several definitions: "+$report)
ASSERT:C1129(Position:C15("Last full run: 2026-01-01T00:00:06 (failed)"; $report)>0; "stat: should show the last full run: "+$report)

//MARK:- one definition, and an unknown dataclass
$dialog._capture:=[]
_statVectors(cs:C1710.Definition.new("NoSuchDataclass"; "v"; "embed"; "{x}"))
$messages:=$dialog._capture
ASSERT:C1129(Position:C15("NoSuchDataclass.v — unknown dataclass"; $messages[0].message)>0; "stat, unknown dataclass: "+$messages[0].message)
ASSERT:C1129(Position:C15("Summary"; $messages[0].message)=0; "stat, one definition: no summary expected")

// ══════════════════════════════════════════════════════════════════════
// _invalidateVectors
// ══════════════════════════════════════════════════════════════════════

//MARK:- one definition
var $vector2Count : Integer:=ds:C1482._Students.query("student_vector_2 != null").length
$dialog._capture:=[]
_invalidateVectors($studentsDef)
$messages:=$dialog._capture
ASSERT:C1129(Position:C15("102 entity(ies) invalidated"; $messages[0].message)>0; "invalidate one: "+$messages[0].message)
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 != null").length=0; "invalidate one: student_vector_1 should be cleared")
ASSERT:C1129(ds:C1482._Students.query("student_vector_2 != null").length=$vector2Count; "invalidate one: student_vector_2 should be untouched")

//MARK:- every definition: vectors cleared, dirty flags set
$dialog._capture:=[]
_invalidateVectors
$messages:=$dialog._capture
ASSERT:C1129(Position:C15("204 entity(ies) invalidated"; $messages[0].message)>0; "invalidate all: "+$messages[0].message)
ASSERT:C1129(ds:C1482._Students.query("student_vector_2 != null").length=0; "invalidate all: student_vector_2 should be cleared")
ASSERT:C1129(ds:C1482._Students.query("student_vector_2_dirty = true").length=102; "invalidate all: the dirty flags should be set")

//MARK:- an unknown dataclass is reported
$dialog._capture:=[]
_invalidateVectors(cs:C1710.Definition.new("NoSuchDataclass"; "v"; "embed"; "{x}"))
$messages:=$dialog._capture
ASSERT:C1129(Position:C15("NoSuchDataclass.v: unknown dataclass"; $messages[0].message)>0; "invalidate, unknown dataclass: "+$messages[0].message)

//MARK:- no definition: says so (stat and invalidate)
$tmp.setText(JSON Stringify:C1217({definitions: []}))
$dialog._capture:=[]
_invalidateVectors
_statVectors
$messages:=$dialog._capture
ASSERT:C1129($messages.query("message = :1"; "@No vector definitions found@").length=2; "no definition: both helpers should say so, got "+JSON Stringify:C1217($messages))

$dialog._capture:=Null:C1517
$dialog._answers:=[]

// ══════════════════════════════════════════════════════════════════════
// _runInWorker — how the studio menus run these helpers
// ══════════════════════════════════════════════════════════════════════

var $marker : 4D:C1709.File:=Folder:C1567(Temporary folder:C486; fk platform path:K87:2).file("__test_dev_runInWorker.txt")
If ($marker.exists)
	$marker.delete()
End if

CALL WORKER:C1389("__test_dev_worker"; Formula:C1597(_runInWorker($1; $2)); Formula:C1597(File:C1566($1).setText("done")); $marker.path)

var $waited : Integer:=0
While ((Not:C34($marker.exists)) && ($waited<600))
	DELAY PROCESS:C323(Current process:C322; 6)
	$waited+=6
End while
ASSERT:C1129($marker.exists; "_runInWorker: the formula should run with its parameter")

$waited:=0
While ((Process activity:C1495(Processes only:K5:35).processes.query("name = :1"; "__test_dev_worker").length>0) && ($waited<600))
	DELAY PROCESS:C323(Current process:C322; 6)
	$waited+=6
End while
ASSERT:C1129(Process activity:C1495(Processes only:K5:35).processes.query("name = :1"; "__test_dev_worker").length=0; "_runInWorker: the worker should be released afterwards")

// ══════════════════════════════════════════════════════════════════════
// CLEANUP
// ══════════════════════════════════════════════════════════════════════

If ($marker.exists)
	$marker.delete()
End if
ds:C1482._Students.all().drop()
ds:C1482.School.all().drop()
ds:C1482.Cities.all().drop()
cs:C1710._Settings.me.file:=$prevFile
$tmp.delete()
var $tmpBackup : 4D:C1709.File:=$tmp.parent.file($tmp.fullName+".bak")
If ($tmpBackup.exists)
	$tmpBackup.delete()
End if
If ($histExisted)
	$histFile.setText($histBackup)
Else
	If ($histFile.exists)
		$histFile.delete()
	End if
End if
