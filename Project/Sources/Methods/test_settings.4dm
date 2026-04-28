//%attributes = {}
// Unit tests for cs.embed.Settings

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
vectors: [\
{dataclassName: "Students"; vectorName: "student_vector_1"; model: "text-embedding-3-small"; phrase: "{firstName}"}; \
{dataclassName: "School"; vectorName: "school_vector_1"; model: "text-embedding-3-large"; phrase: "{name}"}]}))

$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.definitions.length=2; "load: expected 2 vectors, got "+String:C10($s.definitions.length))
ASSERT:C1129($s.definitions[0].dataclassName="Students"; "load[0]: dataclassName mismatch")
ASSERT:C1129($s.definitions[0].vectorName="student_vector_1"; "load[0]: vectorName mismatch")
ASSERT:C1129($s.definitions[0].model="text-embedding-3-small"; "load[0]: model mismatch")
ASSERT:C1129($s.definitions[1].dataclassName="School"; "load[1]: dataclassName mismatch")
ASSERT:C1129($s.definitions[1].model="text-embedding-3-large"; "load[1]: model mismatch")
ASSERT:C1129(OB Instance of:C1731($s.definitions[0]; cs:C1710.Definition); "load: vectors must be Definition instances")

// --- Custom batchSize ---
$tmpFile.setText(JSON Stringify:C1217({batchSize: 25; vectors: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.batchSize=25; "batchSize: expected 25, got "+String:C10($s.batchSize))

// --- Negative batchSize → default ---
$tmpFile.setText(JSON Stringify:C1217({batchSize: -5; vectors: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.batchSize=50; "negative batchSize: expected default 50, got "+String:C10($s.batchSize))

// --- Zero batchSize → default ---
$tmpFile.setText(JSON Stringify:C1217({batchSize: 0; vectors: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.batchSize=50; "zero batchSize: expected default 50, got "+String:C10($s.batchSize))

// --- Phrase options ---
$tmpFile.setText(JSON Stringify:C1217({phrase: {allowRelations: True:C214; allowCalculated: True:C214; allowAlias: False:C215}; vectors: []}))
$s:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s.phrase.allowRelations=True:C214; "phrase: allowRelations expected true")
ASSERT:C1129($s.phrase.allowCalculated=True:C214; "phrase: allowCalculated expected true")
ASSERT:C1129($s.phrase.allowAlias=False:C215; "phrase: allowAlias expected false")

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

$tmpFile.setText(JSON Stringify:C1217({vectors: [\
{dataclassName: "Students"; vectorName: "student_vector_1"; model: "m1"; phrase: "{firstName}"}; \
{dataclassName: "Students"; vectorName: "student_vector_2"; model: "m2"; phrase: "{lastName}"}; \
{dataclassName: "School"; vectorName: "school_vector_1"; model: "m3"; phrase: "{name}"}]}))
$s:=cs:C1710.Settings.new($tmpFile)

var $found : cs:C1710.Definition

// --- Exact match ---
$found:=$s.find("Students"; "student_vector_1")
ASSERT:C1129($found#Null:C1517; "find: expected match for Students/student_vector_1")
ASSERT:C1129($found.model="m1"; "find: expected model m1, got '"+String:C10($found.model)+"'")

// --- Second definition ---
$found:=$s.find("Students"; "student_vector_2")
ASSERT:C1129($found#Null:C1517; "find: expected match for Students/student_vector_2")
ASSERT:C1129($found.model="m2"; "find: expected model m2")

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
$s:=cs:C1710.Settings.new($noFile)  // start clean (no file → raw={})
$s.file:=$tmpFile
$s.definitions:=[cs:C1710.Definition.new("Students"; "student_vector_1"; "text-embedding-3-small"; "{firstName} {lastName}")]
$s.batchSize:=20
$s.phrase.allowRelations:=True:C214
$s.save()

var $s2 : cs:C1710.Settings:=cs:C1710.Settings.new($tmpFile)
ASSERT:C1129($s2.definitions.length=1; "save round-trip: expected 1 vector")
ASSERT:C1129($s2.definitions[0].dataclassName="Students"; "save round-trip: dataclassName mismatch")
ASSERT:C1129($s2.definitions[0].vectorName="student_vector_1"; "save round-trip: vectorName mismatch")
ASSERT:C1129($s2.definitions[0].model="text-embedding-3-small"; "save round-trip: model mismatch")
ASSERT:C1129($s2.definitions[0].phrase.template="{firstName} {lastName}"; "save round-trip: phrase mismatch")
ASSERT:C1129($s2.batchSize=20; "save round-trip: batchSize mismatch")
ASSERT:C1129($s2.phrase.allowRelations=True:C214; "save round-trip: allowRelations mismatch")

// --- Default batchSize and phrase not written ---
$s:=cs:C1710.Settings.new($noFile)
$s.file:=$tmpFile
$s.save()
var $raw : Object:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129(Not:C34(OB Is defined:C1231($raw; "batchSize")); "save: default batchSize should not be written")
ASSERT:C1129(Not:C34(OB Is defined:C1231($raw; "phrase")); "save: default phrase options should not be written")

// --- Unknown top-level keys preserved ---
$tmpFile.setText(JSON Stringify:C1217({models: {myModel: "text-embedding-3-small"}; vectors: [\
{dataclassName: "Students"; vectorName: "student_vector_1"; model: "m"; phrase: "{firstName}"}]}))
$s:=cs:C1710.Settings.new($tmpFile)
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129(OB Is defined:C1231($raw; "models"); "save: unknown key 'models' should be preserved")
ASSERT:C1129($raw.models.myModel="text-embedding-3-small"; "save: preserved key value mismatch")

// --- Definition without model and phrase filtered out (hasDefinition=false) ---
$s:=cs:C1710.Settings.new($noFile)
$s.file:=$tmpFile
$s.definitions:=[\
cs:C1710.Definition.new("Students"; "student_vector_1"; "text-embedding-3-small"; "{firstName}"); \
cs:C1710.Definition.new("Students"; "student_vector_2"; ""; "")]
$s.save()
$raw:=JSON Parse:C1218($tmpFile.getText())
ASSERT:C1129($raw.vectors.length=1; "save: empty definition (no model/phrase) should be filtered out")
ASSERT:C1129($raw.vectors[0].vectorName="student_vector_1"; "save: correct definition kept after filter")

// Cleanup
$tmpFile.delete()

// ALERT("✅ All Settings tests passed!")
