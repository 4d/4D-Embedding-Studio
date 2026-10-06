//%attributes = {}
// Unit tests for cs.Settings

var $noFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_settings_nonexistent.json")
var $tmpFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_settings_tmp.json")

// ══════════════════════════════════════════════════════════════════════
// CONSTRUCTOR DEFAULTS (non-existent file)
// ══════════════════════════════════════════════════════════════════════

var $s : cs:C1710.Settings:=cs:C1710.Settings.new($noFile)
ASSERT:C1129($s.definitions.length=0; "defaults: expected empty vectors")
ASSERT:C1129($s.batchSize=50; "defaults: expected batchSize=50, got "+String:C10($s.batchSize))
ASSERT:C1129($s.phrase.allowRelations=False:C215; "defaults: allowRelations should be false")
ASSERT:C1129($s.phrase.allowCalculated=False:C215; "defaults: allowCalculated should be false")
ASSERT:C1129($s.phrase.allowAlias=False:C215; "defaults: allowAlias should be false")

// ══════════════════════════════════════════════════════════════════════
// LOAD
// ══════════════════════════════════════════════════════════════════════

// --- Two definitions ---
$tmpFile.setText(JSON Stringify:C1217({\
definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "text-embedding-3-small"; phrase: "{firstName}"}; \
{dataclassName: "School"; vectorName: "school_vector_1"; modelAlias: "text-embedding-3-large"; phrase: "{name}"}]}))

$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.definitions.length=2; "load: expected 2 vectors, got "+String:C10($s.definitions.length))
ASSERT:C1129($s.definitions[0].dataclassName="_Students"; "load[0]: dataclassName mismatch")
ASSERT:C1129($s.definitions[0].vectorName="student_vector_1"; "load[0]: vectorName mismatch")
ASSERT:C1129($s.definitions[0].modelAlias="text-embedding-3-small"; "load[0]: modelAlias mismatch")
ASSERT:C1129($s.definitions[0].autoInvalidate=True:C214; "load[0]: autoInvalidate default should be true")
ASSERT:C1129($s.definitions[1].dataclassName="School"; "load[1]: dataclassName mismatch")
ASSERT:C1129($s.definitions[1].modelAlias="text-embedding-3-large"; "load[1]: modelAlias mismatch")
ASSERT:C1129(OB Instance of:C1731($s.definitions[0]; cs:C1710.Definition); "load: vectors must be Definition instances")

// --- Explicit autoInvalidate=false ---
$tmpFile.setText(JSON Stringify:C1217({\
definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "text-embedding-3-small"; phrase: "{firstName}"; autoInvalidate: False:C215}]}))

$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.definitions[0].autoInvalidate=False:C215; "load[0]: autoInvalidate should be loaded from file")

// --- Custom batchSize ---
$tmpFile.setText(JSON Stringify:C1217({batchSize: 25; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.batchSize=25; "batchSize: expected 25, got "+String:C10($s.batchSize))

// --- Negative batchSize → default ---
$tmpFile.setText(JSON Stringify:C1217({batchSize: -5; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.batchSize=50; "negative batchSize: expected default 50, got "+String:C10($s.batchSize))

// --- Zero batchSize → default ---
$tmpFile.setText(JSON Stringify:C1217({batchSize: 0; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.batchSize=50; "zero batchSize: expected default 50, got "+String:C10($s.batchSize))

// --- Phrase options ---
$tmpFile.setText(JSON Stringify:C1217({phrase: {allowRelations: True:C214; allowCalculated: True:C214; allowAlias: False:C215}; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.phrase.allowRelations=True:C214; "phrase: allowRelations expected true")
ASSERT:C1129($s.phrase.allowCalculated=True:C214; "phrase: allowCalculated expected true")
ASSERT:C1129($s.phrase.allowAlias=False:C215; "phrase: allowAlias expected false")

// --- Phrase allowObject round-trip ---
$tmpFile.setText(JSON Stringify:C1217({phrase: {allowObject: True:C214}; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.phrase.allowObject=True:C214; "phrase: allowObject expected true")
$s.save()
var $savedRaw : Object:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($savedRaw.phrase.allowObject=True:C214; "phrase: allowObject should persist on save")

// --- Malformed JSON → silent, defaults ---
$tmpFile.setText("not valid json {{{")
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.definitions.length=0; "malformed JSON: expected empty vectors")
ASSERT:C1129($s.batchSize=50; "malformed JSON: expected default batchSize")

// --- Missing vectors key → empty vectors, batchSize still loaded ---
$tmpFile.setText(JSON Stringify:C1217({batchSize: 10}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.definitions.length=0; "missing vectors key: expected empty")
ASSERT:C1129($s.batchSize=10; "missing vectors key: batchSize still loaded")

// ══════════════════════════════════════════════════════════════════════
// FIND
// ══════════════════════════════════════════════════════════════════════

$tmpFile.setText(JSON Stringify:C1217({definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "m1"; phrase: "{firstName}"}; \
{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: "m2"; phrase: "{lastName}"}; \
{dataclassName: "School"; vectorName: "school_vector_1"; modelAlias: "m3"; phrase: "{name}"}]}))
$s:=cs:C1710.Settings.new($tmpFile)

var $found : cs:C1710.Definition

// --- Exact match ---
$found:=$s.find("_Students"; "student_vector_1")
ASSERT:C1129($found#Null:C1517; "find: expected match for Students/student_vector_1")
ASSERT:C1129($found.modelAlias="m1"; "find: expected modelAlias m1, got '"+String:C10($found.modelAlias)+"'")

// --- Second definition ---
$found:=$s.find("_Students"; "student_vector_2")
ASSERT:C1129($found#Null:C1517; "find: expected match for Students/student_vector_2")
ASSERT:C1129($found.modelAlias="m2"; "find: expected modelAlias m2")

// --- Different dataclass ---
$found:=$s.find("School"; "school_vector_1")
ASSERT:C1129($found#Null:C1517; "find: expected match for School/school_vector_1")

// --- Wrong dataclass for existing vectorName → Null ---
$found:=$s.find("School"; "student_vector_1")
ASSERT:C1129($found=Null:C1517; "find: wrong dataclass should return Null")

// --- Unknown names → Null ---
$found:=$s.find("Unknown"; "no_vector")
ASSERT:C1129($found=Null:C1517; "find: unknown names → Null")

// ══════════════════════════════════════════════════════════════════════
// SAVE
// ══════════════════════════════════════════════════════════════════════

// --- Round-trip: vectors, batchSize, phrase options ---
$tmpFile.delete()
$s:=cs:C1710.Settings.new($tmpFile)  // start clean (no file → raw={})
$s.definitions:=[cs:C1710.Definition.new("_Students"; "student_vector_1"; "text-embedding-3-small"; "{firstName} {lastName}")]
$s.definitions[0].autoInvalidate:=False:C215
$s.batchSize:=20
$s.phrase.allowRelations:=True:C214
$s.save()

var $s2 : cs:C1710.Settings:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s2.definitions.length=1; "save round-trip: expected 1 vector")
ASSERT:C1129($s2.definitions[0].dataclassName="_Students"; "save round-trip: dataclassName mismatch")
ASSERT:C1129($s2.definitions[0].vectorName="student_vector_1"; "save round-trip: vectorName mismatch")
ASSERT:C1129($s2.definitions[0].modelAlias="text-embedding-3-small"; "save round-trip: modelAlias mismatch")
ASSERT:C1129($s2.definitions[0].phrase.template="{firstName} {lastName}"; "save round-trip: phrase mismatch")
ASSERT:C1129($s2.definitions[0].autoInvalidate=False:C215; "save round-trip: autoInvalidate mismatch")
ASSERT:C1129($s2.batchSize=20; "save round-trip: batchSize mismatch")
ASSERT:C1129($s2.phrase.allowRelations=True:C214; "save round-trip: allowRelations mismatch")

// --- Default batchSize and phrase not written ---
$tmpFile.delete()
$s:=cs:C1710.Settings.new($tmpFile)
$s.save()
var $raw : Object:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129(Not:C34(OB Is defined:C1231($raw; "batchSize")); "save: default batchSize should not be written")
ASSERT:C1129(Not:C34(OB Is defined:C1231($raw; "phrase")); "save: default phrase options should not be written")

// --- Unknown top-level keys preserved ---
$tmpFile.setText(JSON Stringify:C1217({models: {myModel: "text-embedding-3-small"}; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "m"; phrase: "{firstName}"}]}))
$s:=cs:C1710.Settings.new($tmpFile)
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129(OB Is defined:C1231($raw; "models"); "save: unknown key 'models' should be preserved")
ASSERT:C1129($raw.models.myModel="text-embedding-3-small"; "save: preserved key value mismatch")

// --- Definition without model and phrase filtered out (hasDefinition=false) ---
$tmpFile.delete()
$s:=cs:C1710.Settings.new($tmpFile)
$s.definitions:=[\
cs:C1710.Definition.new("_Students"; "student_vector_1"; "text-embedding-3-small"; "{firstName}"); \
cs:C1710.Definition.new("_Students"; "student_vector_2"; ""; "")]
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.definitions.length=1; "save: empty definition (no model/phrase) should be filtered out")
ASSERT:C1129($raw.definitions[0].vectorName="student_vector_1"; "save: correct definition kept after filter")

// --- Embedder options are written, reloaded, and removed when cleared ---
$tmpFile.setText(JSON Stringify:C1217({definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.embedder=Null:C1517; "embedder: no options by default")
$s.embedder:={className: "_TestProcessEmbedder"; maxRetries: 2}
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.embedder.className="_TestProcessEmbedder"; "embedder: className should be written")
ASSERT:C1129($raw.embedder.maxRetries=2; "embedder: maxRetries should be written")
ASSERT:C1129(cs:C1710.Settings.new($tmpFile).embedder.maxRetries=2; "embedder: options should be reloaded")

$s.embedder:=Null:C1517
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129(Not:C34(OB Is defined:C1231($raw; "embedder")); "embedder: cleared options should be removed from the file")

// ══════════════════════════════════════════════════════════════════════
// SAVE — UNREADABLE FILE IS NEVER OVERWRITTEN (R-001a)
// ══════════════════════════════════════════════════════════════════════

var $bakFile : 4D:C1709.File:=$tmpFile.parent.file($tmpFile.fullName+".bak")
var $corruptFile : 4D:C1709.File:=$tmpFile.parent.file($tmpFile.fullName+".corrupt")

//MARK:- corrupt file is left untouched
var $corruptText : Text:="{ this is not json"
$tmpFile.setText($corruptText)
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129(Not:C34($s.save()); "corrupt file: save() must refuse and return False")
ASSERT:C1129($tmpFile.getText()=$corruptText; "corrupt file: content must be left untouched")

//MARK:- a readable file is backed up before being replaced
If ($bakFile.exists)
	$bakFile.delete()
End if 
$tmpFile.setText(JSON Stringify:C1217({batchSize: 7; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
$s.batchSize:=8
ASSERT:C1129($s.save(); "backup: save() should succeed on a readable file")
ASSERT:C1129($bakFile.exists; "backup: a .bak of the previous content should exist")
ASSERT:C1129(JSON Parse:C1218($bakFile.getText()).batchSize=7; "backup: .bak should hold the previous content")
ASSERT:C1129(JSON Parse:C1218($tmpFile.getText()).batchSize=8; "backup: the file should hold the new content")

//MARK:- writing over an unreadable file through the setter keeps the old bytes
If ($corruptFile.exists)
	$corruptFile.delete()
End if 
$tmpFile.setText($corruptText)
cs:C1710._Settings.me.set({scheduler: {mode: "daily"}})
ASSERT:C1129($corruptFile.exists; "corrupt setter write: previous bytes should be kept as .corrupt")
ASSERT:C1129($corruptFile.getText()=$corruptText; "corrupt setter write: .corrupt should hold the unreadable content")
ASSERT:C1129(JSON Parse:C1218($tmpFile.getText()).scheduler.mode="daily"; "corrupt setter write: the new value should be written")

// ══════════════════════════════════════════════════════════════════════
// SAVE — TWO EDITORS DO NOT DROP EACH OTHER'S DEFINITIONS (R-001b)
// ══════════════════════════════════════════════════════════════════════

//MARK:- both additions survive
$tmpFile.setText(JSON Stringify:C1217({definitions: []}))
var $editorA : cs:C1710.Settings:=cs:C1710.Settings.new($tmpFile)
var $editorB : cs:C1710.Settings:=cs:C1710.Settings.new($tmpFile)

$editorA.definitions.push(cs:C1710.Definition.new("_Students"; "student_vector_1"; "m1"; "{firstName}"))
ASSERT:C1129($editorA.save(); "two editors: first save should succeed")

$editorB.definitions.push(cs:C1710.Definition.new("School"; "school_vector_1"; "m2"; "{name}"))
ASSERT:C1129($editorB.save(); "two editors: second save should succeed")

$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.definitions.length=2; "two editors: both definitions should survive, got "+String:C10($raw.definitions.length))
ASSERT:C1129($raw.definitions.query("vectorName = :1"; "student_vector_1").length=1; "two editors: the first editor's definition should survive")
ASSERT:C1129($raw.definitions.query("vectorName = :1"; "school_vector_1").length=1; "two editors: the second editor's definition should survive")

//MARK:- each editor's own edit wins on its own definition
$tmpFile.setText(JSON Stringify:C1217({definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "m1"; phrase: "{firstName}"; autoInvalidate: True:C214}; \
{dataclassName: "School"; vectorName: "school_vector_1"; modelAlias: "m2"; phrase: "{name}"; autoInvalidate: True:C214}]}))

$editorA:=cs:C1710.Settings.new($tmpFile)
$editorB:=cs:C1710.Settings.new($tmpFile)

$editorA.find("_Students"; "student_vector_1").modelAlias:="edited-by-A"
$editorA.save()

$editorB.find("School"; "school_vector_1").phrase:=cs:C1710.Phrase.new("{university}")
$editorB.save()

$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.definitions.length=2; "concurrent edits: both definitions should remain")
ASSERT:C1129($raw.definitions.query("vectorName = :1"; "student_vector_1").first().modelAlias="edited-by-A"; "concurrent edits: editor A's change should survive")
ASSERT:C1129($raw.definitions.query("vectorName = :1"; "school_vector_1").first().phrase="{university}"; "concurrent edits: editor B's change should be written")

//MARK:- a definition removed by an editor is removed from the file
$editorA:=cs:C1710.Settings.new($tmpFile)
$editorA.definitions:=$editorA.definitions.query("vectorName != :1"; "school_vector_1")
$editorA.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.definitions.length=1; "removal: the dropped definition should be gone")
ASSERT:C1129($raw.definitions[0].vectorName="student_vector_1"; "removal: the kept definition should be the other one")

//MARK:- a removal by one editor and an addition by another both apply
$tmpFile.setText(JSON Stringify:C1217({definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "m1"; phrase: "{firstName}"; autoInvalidate: True:C214}; \
{dataclassName: "School"; vectorName: "school_vector_1"; modelAlias: "m2"; phrase: "{name}"; autoInvalidate: True:C214}]}))

$editorA:=cs:C1710.Settings.new($tmpFile)
$editorB:=cs:C1710.Settings.new($tmpFile)

$editorB.definitions.push(cs:C1710.Definition.new("_Students"; "student_vector_2"; "m3"; "{lastName}"))
ASSERT:C1129($editorB.save(); "removal + addition: editor B's save should succeed")

$editorA.definitions:=$editorA.definitions.query("vectorName != :1"; "school_vector_1")
ASSERT:C1129($editorA.save(); "removal + addition: editor A's save should succeed")

$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.definitions.length=2; "removal + addition: expected 2 definitions, got "+String:C10($raw.definitions.length))
ASSERT:C1129($raw.definitions.query("vectorName = :1"; "school_vector_1").length=0; "removal + addition: editor A's removal should apply")
ASSERT:C1129($raw.definitions.query("vectorName = :1"; "student_vector_2").length=1; "removal + addition: editor B's addition should survive")
ASSERT:C1129($raw.definitions.query("vectorName = :1"; "student_vector_1").length=1; "removal + addition: the untouched definition should remain")

// ══════════════════════════════════════════════════════════════════════
// SAVE — KEYS OWNED BY OTHERS ARE NOT REWRITTEN FROM A STALE SNAPSHOT
// ══════════════════════════════════════════════════════════════════════

//MARK:- a scheduler config saved after this instance loaded survives its save
$tmpFile.setText(JSON Stringify:C1217({batchSize: 12; scheduler: {mode: "interval"; intervalHours: 3}; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)  // loads while the scheduler is still on "interval"

cs:C1710._Settings.me.set({scheduler: {mode: "daily"; dailyTime: "05:00"}})  // e.g. the scheduler wizard

$s.batchSize:=13
ASSERT:C1129($s.save(); "foreign keys: save should succeed")

$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.scheduler.mode="daily"; "foreign keys: the newer scheduler config should not be rewritten, got '"+String:C10($raw.scheduler.mode)+"'")
ASSERT:C1129($raw.scheduler.dailyTime="05:00"; "foreign keys: the newer scheduler config should be intact")
ASSERT:C1129($raw.batchSize=13; "foreign keys: our own key should be written")

// ══════════════════════════════════════════════════════════════════════
// SAVE — RESET OPTIONS ARE PERSISTED
// ══════════════════════════════════════════════════════════════════════

//MARK:- batchSize back to the default removes the key from the file
$tmpFile.setText(JSON Stringify:C1217({batchSize: 25; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.batchSize=25; "reset batchSize: setup should load 25")
$s.batchSize:=$s._defaultBatchSize()
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129(Not:C34(OB Is defined:C1231($raw; "batchSize")); "reset batchSize: the key should be removed, so the default applies on reload")
ASSERT:C1129(cs:C1710.Settings.new($tmpFile).batchSize=50; "reset batchSize: reload should give the default")

//MARK:- phrase options back to defaults remove the key from the file
$tmpFile.setText(JSON Stringify:C1217({phrase: {allowRelations: True:C214; allowCalculated: False:C215; allowAlias: False:C215; allowObject: False:C215}; definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.phrase.allowRelations; "reset options: setup should have allowRelations true")
$s.phrase.allowRelations:=False:C215
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129(Not:C34(OB Is defined:C1231($raw; "phrase")); "reset options: the phrase key should be removed from the file")

// ══════════════════════════════════════════════════════════════════════
// VECTOR HELPERS (data-backed)
// ══════════════════════════════════════════════════════════════════════

// Two students with every vector computed (dirty flags explicitly cleared).
var $seed : Object:=cs:C1710._TestFixtures.me.seedStudents(2)
var $student : 4D:C1709.Entity
For each ($student; $seed.students)
	$student.student_vector_1:=4D:C1709.Vector.new([1; 2; 3])
	$student.student_vector_2:=4D:C1709.Vector.new([1; 2; 3])
	$student.student_vector_2_dirty:=False:C215
	ASSERT:C1129($student.save().success; "vector helpers: failed to seed vectors")
End for each

$tmpFile.setText(JSON Stringify:C1217({definitions: []}))
$s:=cs:C1710.Settings.new($tmpFile)

//MARK:- _affectedByAliasChange: only a changed model with computed vectors is reported
$s.definitions:=[\
cs:C1710.Definition.new("_Students"; "student_vector_1"; "aliasA"; "{firstName}"); \
cs:C1710.Definition.new("School"; "school_vector_1"; "aliasA"; "{name}"); \
cs:C1710.Definition.new("_Students"; "student_vector_2"; "aliasB"; "{lastName}"); \
cs:C1710.Definition.new("_Students"; "student_not_defined"; "aliasNew"; "{lastName}"); \
cs:C1710.Definition.new("_Students"; "student vector 3"; ""; "{lastName}")]

var $before : Object:={aliasA: {provider: "openai"; model: "small"}; aliasB: {provider: "openai"; model: "same"}}
var $after : Object:={aliasA: {provider: "openai"; model: "large"}; aliasB: {provider: "openai"; model: "same"}; aliasNew: {provider: "openai"; model: "x"}}

var $affected : Collection:=$s._affectedByAliasChange($before; $after)
ASSERT:C1129($affected.length=1; "alias change: expected only 1 affected definition, got "+String:C10($affected.length))
ASSERT:C1129($affected[0].vectorName="student_vector_1"; "alias change: the changed alias with computed vectors should be reported")

ASSERT:C1129($s._affectedByAliasChange(Null:C1517; $after).length=0; "alias change: no previous aliases → nothing reported")

$after.aliasB:={provider: "other"; model: "same"}
$affected:=$s._affectedByAliasChange($before; $after)
ASSERT:C1129($affected.query("vectorName = :1"; "student_vector_2").length=1; "alias change: a provider change should be reported too")

//MARK:- invalidateVectors aggregates every definition
$s.definitions:=[\
cs:C1710.Definition.new("_Students"; "student_vector_1"; "aliasA"; "{firstName}"); \
cs:C1710.Definition.new("NoSuchDataclass"; "v"; "aliasA"; "{x}")]
var $invalidation : Object:=$s.invalidateVectors()
ASSERT:C1129($invalidation.updated=2; "invalidateVectors: expected 2 updated, got "+String:C10($invalidation.updated))
ASSERT:C1129($invalidation.skipped=0; "invalidateVectors: expected 0 skipped")
ASSERT:C1129($invalidation.errors.length=1; "invalidateVectors: expected the unknown dataclass error, got "+JSON Stringify:C1217($invalidation.errors))
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 != null").length=0; "invalidateVectors: student vectors should be cleared")

ds:C1482._Students.all().drop()
ds:C1482.School.all().drop()
ds:C1482.Cities.all().drop()

// ══════════════════════════════════════════════════════════════════════
// DEFAULT FILE
// ══════════════════════════════════════════════════════════════════════

//MARK:- Settings/embeddings.json unless EMBEDDINGS_SETTINGS_PATH says otherwise
var $envPath : Text:=String:C10(cs:C1710._Env.me["EMBEDDINGS_SETTINGS_PATH"])
var $defaultFile : 4D:C1709.File:=cs:C1710._Settings.me._defaultFile()
If (Length:C16($envPath)=0)
	ASSERT:C1129($defaultFile.path=Folder:C1567(fk database folder:K87:14; *).file("Settings/embeddings.json").path; "default file: expected Settings/embeddings.json, got "+$defaultFile.path)
Else
	ASSERT:C1129($defaultFile.path=File:C1566($envPath; Is Windows:C1573 ? fk platform path:K87:2 : fk posix path:K87:1).path; "default file: expected EMBEDDINGS_SETTINGS_PATH, got "+$defaultFile.path)
End if

// Cleanup
$tmpFile.delete()
If ($bakFile.exists)
	$bakFile.delete()
End if 
If ($corruptFile.exists)
	$corruptFile.delete()
End if 

// ALERT("✅ All Settings tests passed!")
