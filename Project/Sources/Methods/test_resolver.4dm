//%attributes = {}
// Unit tests for cs._Resolver

// Build a cs.Settings pointing at a file that does not exist,
// so constructor/load does no I/O. We then populate .definitions manually.
var $noFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_resolver_nonexistent.json")
var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($noFile)

var $defStudentsV1 : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_1"; "text-embedding-3-small"; "{firstName}")
var $defStudentsV2 : cs:C1710.Definition:=cs:C1710.Definition.new("_Students"; "student_vector_2"; "text-embedding-3-small"; "{lastName}")
var $defSchoolV1 : cs:C1710.Definition:=cs:C1710.Definition.new("School"; "school_vector_1"; "text-embedding-3-small"; "{name}")

$settings.definitions:=[$defStudentsV1; $defStudentsV2; $defSchoolV1]

var $resolver : cs:C1710._Resolver:=cs:C1710._Resolver.new($settings)
var $out : Collection

// ══════════════════════════════════════════════════════════════════════
// resolveForProcess — no entity context
// ══════════════════════════════════════════════════════════════════════

// --- Null → all definitions in settings ---
$out:=$resolver.resolveForProcess(Null:C1517)
ASSERT:C1129($out.length=3; "resolveForProcess(Null): expected 3 defs, got "+String:C10($out.length))

// --- Single definition → wrapped in collection ---
$out:=$resolver.resolveForProcess($defStudentsV1)
ASSERT:C1129($out.length=1; "resolveForProcess(single): expected 1, got "+String:C10($out.length))
ASSERT:C1129($out[0].vectorName="student_vector_1"; "resolveForProcess(single): wrong def returned")

// --- Collection of full Definitions → flat-mapped, order preserved ---
$out:=$resolver.resolveForProcess([$defStudentsV1; $defSchoolV1])
ASSERT:C1129($out.length=2; "resolveForProcess(collection): expected 2, got "+String:C10($out.length))
ASSERT:C1129($out[0].vectorName="student_vector_1"; "resolveForProcess(collection): order preserved")
ASSERT:C1129($out[1].vectorName="school_vector_1"; "resolveForProcess(collection): order preserved")

// --- Empty collection → empty result ---
$out:=$resolver.resolveForProcess([])
ASSERT:C1129($out.length=0; "resolveForProcess([]): expected empty")

// --- Unsupported type (Text) → empty ---
$out:=$resolver.resolveForProcess("not a definition")
ASSERT:C1129($out.length=0; "resolveForProcess(text): expected empty")

// --- Null-returned collection does not share identity with settings.definitions ---
// (i.e. mutating the result should not mutate settings)
$out:=$resolver.resolveForProcess(Null:C1517)
$out.pop()
ASSERT:C1129($settings.definitions.length=3; "resolveForProcess(Null): result must be a copy")

// --- DataClass → every saved definition for that dataclass (expands to many) ---
$out:=$resolver.resolveForProcess(ds:C1482._Students)
ASSERT:C1129($out.length=2; "resolveForProcess(DataClass _Students): expected 2, got "+String:C10($out.length))
ASSERT:C1129($out.query("dataclassName # _Students").length=0; "resolveForProcess(DataClass Students): all must be Students")

// --- DataClass with a field named "name" → uses getInfo().name, not the attribute ---
$out:=$resolver.resolveForProcess(ds:C1482.School)
ASSERT:C1129($out.length=1; "resolveForProcess(DataClass School): expected 1, got "+String:C10($out.length))
ASSERT:C1129($out[0].vectorName="school_vector_1"; "resolveForProcess(DataClass School): wrong def")

// --- Plain stub (dataclassName+vectorName) matching settings → real Definition from settings ---
$out:=$resolver.resolveForProcess({dataclassName: "_Students"; vectorName: "student_vector_2"})
ASSERT:C1129($out.length=1; "resolveForProcess(stub match): expected 1")
ASSERT:C1129(OB Instance of:C1731($out[0]; cs:C1710.Definition); "resolveForProcess(stub match): must be real Definition")
ASSERT:C1129($out[0].modelAlias="text-embedding-3-small"; "resolveForProcess(stub match): modelAlias from settings")

// --- Plain stub with no matching definition → a new Definition is built from its fields ---
$out:=$resolver.resolveForProcess({dataclassName: "Cities"; vectorName: "city_vec"; modelAlias: "text-embedding-3-large"; phrase: {template: "{name}"}})
ASSERT:C1129($out.length=1; "resolveForProcess(stub new): expected 1")
ASSERT:C1129(OB Instance of:C1731($out[0]; cs:C1710.Definition); "resolveForProcess(stub new): must be a Definition")
ASSERT:C1129($out[0].dataclassName="Cities"; "resolveForProcess(stub new): dataclassName")
ASSERT:C1129($out[0].vectorName="city_vec"; "resolveForProcess(stub new): vectorName")
ASSERT:C1129($out[0].modelAlias="text-embedding-3-large"; "resolveForProcess(stub new): modelAlias")
ASSERT:C1129($out[0].phrase.template="{name}"; "resolveForProcess(stub new): phrase template")

// --- Collection containing a DataClass → flat-mapped/expanded ---
$out:=$resolver.resolveForProcess([ds:C1482._Students])
ASSERT:C1129($out.length=2; "resolveForProcess([DataClass]): expected 2, got "+String:C10($out.length))

// --- Collection of mixed shapes: Definition + DataClass + stub → flattened ---
$out:=$resolver.resolveForProcess([\
$defSchoolV1; \
ds:C1482._Students; \
{dataclassName: "School"; vectorName: "school_vector_1"}\
])
ASSERT:C1129($out.length=4; "resolveForProcess(mixed collection): expected 1+2+1=4, got "+String:C10($out.length))

// --- Collection with an unsupported item → that item contributes nothing ---
$out:=$resolver.resolveForProcess(["not a definition"; $defStudentsV1])
ASSERT:C1129($out.length=1; "resolveForProcess(collection w/ junk): expected 1, got "+String:C10($out.length))
ASSERT:C1129($out[0].vectorName="student_vector_1"; "resolveForProcess(collection w/ junk): wrong def")

// ══════════════════════════════════════════════════════════════════════
// resolveForEntity — with inferred dataclass context
// ══════════════════════════════════════════════════════════════════════

// --- Null with context "_Students" → only Students definitions ---
$out:=$resolver.resolveForEntity(Null:C1517; "_Students")
ASSERT:C1129($out.length=2; "resolveForEntity(Null, Students): expected 2, got "+String:C10($out.length))
ASSERT:C1129($out.query("dataclassName # _Students").length=0; "resolveForEntity(Null, Students): all must be Students")

// --- Null with context "School" → only School definitions ---
$out:=$resolver.resolveForEntity(Null:C1517; "School")
ASSERT:C1129($out.length=1; "resolveForEntity(Null, School): expected 1, got "+String:C10($out.length))
ASSERT:C1129($out[0].vectorName="school_vector_1"; "resolveForEntity(Null, School): wrong def")

// --- Null with unknown context → empty ---
$out:=$resolver.resolveForEntity(Null:C1517; "Unknown")
ASSERT:C1129($out.length=0; "resolveForEntity(Null, Unknown): expected empty")

// --- Null with empty context → empty ---
$out:=$resolver.resolveForEntity(Null:C1517; "")
ASSERT:C1129($out.length=0; "resolveForEntity(Null, ''): expected empty")

// --- Fully-specified Definition matching context → returned ---
$out:=$resolver.resolveForEntity($defStudentsV1; "_Students")
ASSERT:C1129($out.length=1; "resolveForEntity(match): expected 1")
ASSERT:C1129($out[0].vectorName="student_vector_1"; "resolveForEntity(match): wrong def")

// --- Fully-specified Definition mismatching context → empty ---
$out:=$resolver.resolveForEntity($defSchoolV1; "_Students")
ASSERT:C1129($out.length=0; "resolveForEntity(mismatch): expected empty (School def, Students context)")

// --- Stub: only vectorName → looked up by context dataclass ---
var $stubVectorOnly : Object:={vectorName: "student_vector_2"}
$out:=$resolver.resolveForEntity($stubVectorOnly; "_Students")
ASSERT:C1129($out.length=1; "resolveForEntity(vectorName-only): expected 1")
ASSERT:C1129($out[0].dataclassName="_Students"; "resolveForEntity(vectorName-only): wrong dc")
ASSERT:C1129($out[0].vectorName="student_vector_2"; "resolveForEntity(vectorName-only): wrong vector")

// --- Stub: only vectorName but no matching definition in settings → empty ---
$out:=$resolver.resolveForEntity({vectorName: "does_not_exist"}; "_Students")
ASSERT:C1129($out.length=0; "resolveForEntity(stub unknown vector): expected empty")

// --- Stub: only vectorName without context → empty ---
$out:=$resolver.resolveForEntity({vectorName: "student_vector_1"}; "")
ASSERT:C1129($out.length=0; "resolveForEntity(stub, no context): expected empty")

// --- Stub: empty vectorName → empty ---
$out:=$resolver.resolveForEntity({vectorName: ""}; "_Students")
ASSERT:C1129($out.length=0; "resolveForEntity(empty vectorName): expected empty")

// --- Plain object (non-Definition) with dataclassName+vectorName → looked up in settings ---
var $plain : Object:={dataclassName: "_Students"; vectorName: "student_vector_1"}
$out:=$resolver.resolveForEntity($plain; "_Students")
ASSERT:C1129($out.length=1; "resolveForEntity(plain object): expected 1")
ASSERT:C1129(OB Instance of:C1731($out[0]; cs:C1710.Definition); "resolveForEntity(plain): must return real Definition")
ASSERT:C1129($out[0].modelAlias="text-embedding-3-small"; "resolveForEntity(plain): modelAlias should come from settings")

// --- Collection of mixed shapes ---
$out:=$resolver.resolveForEntity([\
$defStudentsV1; \
{vectorName: "student_vector_2"}; \
$defSchoolV1\
]; "_Students")
ASSERT:C1129($out.length=2; "resolveForEntity(mixed collection): expected 2 kept (School one dropped), got "+String:C10($out.length))

// --- Collection with all mismatches → empty ---
$out:=$resolver.resolveForEntity([$defSchoolV1; {vectorName: "nope"}]; "_Students")
ASSERT:C1129($out.length=0; "resolveForEntity(all mismatch): expected empty")

// --- Empty collection → empty ---
$out:=$resolver.resolveForEntity([]; "_Students")
ASSERT:C1129($out.length=0; "resolveForEntity([]): expected empty")

// --- Unsupported type (text) → empty ---
$out:=$resolver.resolveForEntity("nope"; "_Students")
ASSERT:C1129($out.length=0; "resolveForEntity(text): expected empty")

// ══════════════════════════════════════════════════════════════════════
// dataclassNameFrom* — real dataclass probes
// ══════════════════════════════════════════════════════════════════════

// --- Null entity → empty string ---
ASSERT:C1129($resolver.dataclassNameFromEntity(Null:C1517)=""; "dataclassNameFromEntity(Null): expected ''")

// --- Null entity selection → empty string ---
ASSERT:C1129($resolver.dataclassNameFromSelection(Null:C1517)=""; "dataclassNameFromSelection(Null): expected ''")

// --- Real entity selection from ds._Students ---
var $sel : 4D:C1709.EntitySelection:=ds:C1482._Students.all()
ASSERT:C1129($resolver.dataclassNameFromSelection($sel)="_Students"; "dataclassNameFromSelection: expected 'Students'")

// --- Real entity from ds._Students (only if there is at least one row) ---
If ($sel.length>0)
	
	var $e : 4D:C1709.Entity:=$sel.first()
	ASSERT:C1129($resolver.dataclassNameFromEntity($e)="_Students"; "dataclassNameFromEntity: expected 'Students'")
	
End if 

// ══════════════════════════════════════════════════════════════════════
// Settings with empty vectors (edge case)
// ══════════════════════════════════════════════════════════════════════

var $emptySettings : cs:C1710.Settings:=cs:C1710.Settings.new($noFile)
$emptysettings.definitions:=[]

var $emptyResolver : cs:C1710._Resolver:=cs:C1710._Resolver.new($emptySettings)

$out:=$emptyResolver.resolveForProcess(Null:C1517)
ASSERT:C1129($out.length=0; "empty settings / resolveForProcess(Null): expected empty")

$out:=$emptyResolver.resolveForEntity(Null:C1517; "_Students")
ASSERT:C1129($out.length=0; "empty settings / resolveForEntity(Null, Students): expected empty")

$out:=$emptyResolver.resolveForEntity({vectorName: "student_vector_1"}; "_Students")
ASSERT:C1129($out.length=0; "empty settings / resolveForEntity(stub): expected empty (nothing in settings)")

// A fully-specified definition still passes through even with empty settings,
// because resolveForEntity only consults settings when the candidate is a stub.
$out:=$emptyResolver.resolveForEntity($defStudentsV1; "_Students")
ASSERT:C1129($out.length=1; "empty settings / resolveForEntity(full def): expected 1")

// ══════════════════════════════════════════════════════════════════════

// ALERT("✅ All resolver tests passed!")
