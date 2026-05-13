//%attributes = {}
// Unit tests for cs.embed._dataclassAttributes

var $dca : cs:C1710._dataclassAttributes:=cs:C1710._dataclassAttributes.me
$dca.reset()

var $attrs : Collection

// ══════════════════════════════════════════════════════════════════════
// forDataclass — default options (no relations, no calculated, no alias)
// ══════════════════════════════════════════════════════════════════════

// --- Simple storage fields returned ---
$attrs:=$dca.forDataclass(ds:C1482.Students)
ASSERT:C1129($attrs.query("name = :1"; "ID").length=1; "default: ID must be included")
ASSERT:C1129($attrs.query("name = :1"; "firstName").length=1; "default: firstName must be included")
ASSERT:C1129($attrs.query("name = :1"; "lastName").length=1; "default: lastName must be included")

// --- Vector fields excluded ---
ASSERT:C1129($attrs.query("name = :1"; "student_vector_1").length=0; "default: student_vector_1 must be excluded")
ASSERT:C1129($attrs.query("name = :1"; "student_vector_2").length=0; "default: student_vector_2 must be excluded")
ASSERT:C1129($attrs.query("name = :1"; "student_not_defined").length=0; "default: student_not_defined must be excluded")

// --- FK source storage field excluded ---
ASSERT:C1129($attrs.query("name = :1"; "school_ID").length=0; "default: FK storage 'school_ID' must be excluded")

// --- N:1 relatedEntity excluded without allowRelations ---
ASSERT:C1129($attrs.query("name = :1"; "school").length=0; "default: relatedEntity 'school' excluded without allowRelations")

// --- Calculated excluded without allowCalculated ---
ASSERT:C1129($attrs.query("name = :1"; "fullName").length=0; "default: calculated 'fullName' excluded without allowCalculated")

// --- Alias excluded without allowAlias ---
ASSERT:C1129($attrs.query("name = :1"; "town").length=0; "default: alias 'town' excluded without allowAlias")

// ══════════════════════════════════════════════════════════════════════
// forDataclass — allowRelations
// ══════════════════════════════════════════════════════════════════════

$attrs:=$dca.forDataclass(ds:C1482.Students; {allowRelations: True:C214})
// relation is now {name; fields} object, not a flat attribute object
var $schoolEntry:=$attrs.query("name = :1"; "school").first()
ASSERT:C1129($schoolEntry#Null:C1517; "allowRelations: 'school' must be present in result")
ASSERT:C1129(Value type:C1509($schoolEntry.fields)=Is collection:K8:32; "allowRelations: 'school' entry must have a fields Collection")
ASSERT:C1129($schoolEntry.fields.length>0; "allowRelations: 'school' fields must not be empty")
ASSERT:C1129($attrs.query("name = :1"; "firstName").length=1; "allowRelations: simple fields still present")
ASSERT:C1129($attrs.query("name = :1"; "student_vector_1").length=0; "allowRelations: vectors still excluded")
ASSERT:C1129($attrs.query("name = :1"; "school_ID").length=0; "allowRelations: FK storage still excluded")
ASSERT:C1129($attrs.query("name = :1"; "fullName").length=0; "allowRelations: calculated still excluded")
ASSERT:C1129($attrs.query("name = :1"; "town").length=0; "allowRelations: alias still excluded")

// ══════════════════════════════════════════════════════════════════════
// forDataclass — allowCalculated
// ══════════════════════════════════════════════════════════════════════

$attrs:=$dca.forDataclass(ds:C1482.Students; {allowCalculated: True:C214})
ASSERT:C1129($attrs.query("name = :1"; "fullName").length=1; "allowCalculated: 'fullName' must be included")
ASSERT:C1129($attrs.query("name = :1"; "firstName").length=1; "allowCalculated: simple fields still present")
ASSERT:C1129($attrs.query("name = :1"; "school").length=0; "allowCalculated: relatedEntity still excluded")
ASSERT:C1129($attrs.query("name = :1"; "town").length=0; "allowCalculated: alias still excluded")

// ══════════════════════════════════════════════════════════════════════
// forDataclass — allowAlias
// ══════════════════════════════════════════════════════════════════════

$attrs:=$dca.forDataclass(ds:C1482.Students; {allowAlias: True:C214})
ASSERT:C1129($attrs.query("name = :1"; "town").length=1; "allowAlias: 'town' alias must be included")
ASSERT:C1129($attrs.query("name = :1"; "firstName").length=1; "allowAlias: simple fields still present")
ASSERT:C1129($attrs.query("name = :1"; "school").length=0; "allowAlias: relatedEntity still excluded")
ASSERT:C1129($attrs.query("name = :1"; "fullName").length=0; "allowAlias: calculated still excluded")

// ══════════════════════════════════════════════════════════════════════
// forDataclass — all options True
// ══════════════════════════════════════════════════════════════════════

$attrs:=$dca.forDataclass(ds:C1482.Students; {allowRelations: True:C214; allowCalculated: True:C214; allowAlias: True:C214})
var $schoolEntry2:=$attrs.query("name = :1"; "school").first()
ASSERT:C1129(Value type:C1509($schoolEntry2.fields)=Is collection:K8:32; "all options: relatedEntity 'school' must have a fields Collection")
ASSERT:C1129($attrs.query("name = :1"; "fullName").length=1; "all options: calculated included")
ASSERT:C1129($attrs.query("name = :1"; "town").length=1; "all options: alias included")
ASSERT:C1129($attrs.query("name = :1"; "firstName").length=1; "all options: simple fields present")
ASSERT:C1129($attrs.query("name = :1"; "student_vector_1").length=0; "all options: vectors still excluded")
ASSERT:C1129($attrs.query("name = :1"; "school_ID").length=0; "all options: FK storage still excluded")

// ══════════════════════════════════════════════════════════════════════
// forDataclass — School dataclass (1:N always excluded)
// ══════════════════════════════════════════════════════════════════════

$attrs:=$dca.forDataclass(ds:C1482.School)
ASSERT:C1129($attrs.query("name = :1"; "name").length=1; "School default: 'name' must be included")
ASSERT:C1129($attrs.query("name = :1"; "university").length=1; "School default: 'university' must be included")
ASSERT:C1129($attrs.query("name = :1"; "strudents").length=0; "School default: 1:N 'strudents' always excluded")
ASSERT:C1129($attrs.query("name = :1"; "school_vector_1").length=0; "School default: vector excluded")
ASSERT:C1129($attrs.query("name = :1"; "city_ID").length=0; "School default: FK storage 'city_ID' excluded")
ASSERT:C1129($attrs.query("name = :1"; "city").length=0; "School default: relatedEntity 'city' excluded without allowRelations")

$attrs:=$dca.forDataclass(ds:C1482.School; {allowRelations: True:C214})
var $cityEntry:=$attrs.query("name = :1"; "city").first()
ASSERT:C1129(Value type:C1509($cityEntry.fields)=Is collection:K8:32; "School allowRelations: 'city' must have a fields Collection")
ASSERT:C1129($attrs.query("name = :1"; "strudents").length=0; "School allowRelations: 1:N 'strudents' still excluded")

// ══════════════════════════════════════════════════════════════════════
// hasField
// ══════════════════════════════════════════════════════════════════════

// --- Known simple fields ---
ASSERT:C1129($dca.hasField(ds:C1482.Students; "firstName"); "hasField: 'firstName' must return True")
ASSERT:C1129($dca.hasField(ds:C1482.Students; "lastName"); "hasField: 'lastName' must return True")
ASSERT:C1129($dca.hasField(ds:C1482.Students; "ID"); "hasField: 'ID' must return True")

// --- Relation attribute names found ---
ASSERT:C1129($dca.hasField(ds:C1482.Students; "school"); "hasField: relation 'school' must return True")

// --- Vector attribute names found (hasField does not filter by kind) ---
ASSERT:C1129($dca.hasField(ds:C1482.Students; "student_vector_1"); "hasField: vector attribute must return True")

// --- Non-existent field ---
ASSERT:C1129(Not:C34($dca.hasField(ds:C1482.Students; "nonExistent")); "hasField: 'nonExistent' must return False")
ASSERT:C1129(Not:C34($dca.hasField(ds:C1482.Students; "")); "hasField: empty string must return False")

// ══════════════════════════════════════════════════════════════════════
// reset
// ══════════════════════════════════════════════════════════════════════

// Prime the cache
$dca.forDataclass(ds:C1482.Students)
$dca.forDataclass(ds:C1482.School)
$dca.hasField(ds:C1482.Students; "firstName")
$dca.hasField(ds:C1482.School; "name")

// --- reset(name) only drops that dataclass; results remain correct ---
$dca.reset("Students")
$attrs:=$dca.forDataclass(ds:C1482.Students)
ASSERT:C1129($attrs.query("name = :1"; "firstName").length=1; "reset(Students): forDataclass still returns correct results")
$attrs:=$dca.forDataclass(ds:C1482.School)
ASSERT:C1129($attrs.query("name = :1"; "name").length=1; "reset(Students): School cache still valid")

// --- reset() clears all; results remain correct after rebuild ---
$dca.reset()
$attrs:=$dca.forDataclass(ds:C1482.Students)
ASSERT:C1129($attrs.query("name = :1"; "firstName").length=1; "reset(): Students forDataclass correct after full reset")
$attrs:=$dca.forDataclass(ds:C1482.School)
ASSERT:C1129($attrs.query("name = :1"; "name").length=1; "reset(): School forDataclass correct after full reset")
ASSERT:C1129($dca.hasField(ds:C1482.School; "university"); "reset(): hasField correct after full reset")

// ══════════════════════════════════════════════════════════════════════
// forDataclass — AllTypes dataclass (blob, image, object excluded by default)
// ══════════════════════════════════════════════════════════════════════

$attrs:=$dca.forDataclass(ds:C1482.AllTypes)

// Scalar types that ARE embeddable
ASSERT:C1129($attrs.query("name = :1"; "ID").length=1; "AllTypes: ID must be included")
ASSERT:C1129($attrs.query("name = :1"; "Alpha").length=1; "AllTypes: Alpha must be included")
ASSERT:C1129($attrs.query("name = :1"; "Text").length=1; "AllTypes: Text must be included")
ASSERT:C1129($attrs.query("name = :1"; "Date").length=1; "AllTypes: Date must be included")
ASSERT:C1129($attrs.query("name = :1"; "Time").length=1; "AllTypes: Time must be included")
ASSERT:C1129($attrs.query("name = :1"; "Boolean").length=1; "AllTypes: Boolean must be included")
ASSERT:C1129($attrs.query("name = :1"; "Integer").length=1; "AllTypes: Integer must be included")
ASSERT:C1129($attrs.query("name = :1"; "LongInteger").length=1; "AllTypes: LongInteger must be included")
ASSERT:C1129($attrs.query("name = :1"; "Integer64").length=1; "AllTypes: Integer64 must be included")
ASSERT:C1129($attrs.query("name = :1"; "Real").length=1; "AllTypes: Real must be included")

// Types excluded without allowObject
ASSERT:C1129($attrs.query("name = :1"; "Blob").length=0; "AllTypes: Blob must be excluded")
ASSERT:C1129($attrs.query("name = :1"; "Picture").length=0; "AllTypes: Picture must be excluded")
ASSERT:C1129($attrs.query("name = :1"; "Object").length=0; "AllTypes: Object excluded by default")
ASSERT:C1129($attrs.query("name = :1"; "Vector").length=0; "AllTypes: Vector (4D.Vector) must be excluded")

// forDataclass — allowObject
$dca.reset()
$attrs:=$dca.forDataclass(ds:C1482.AllTypes; {allowObject: True:C214})
ASSERT:C1129($attrs.query("name = :1"; "Object").length=1; "allowObject: Object must be included")
ASSERT:C1129($attrs.query("name = :1"; "Blob").length=0; "allowObject: Blob still excluded")
ASSERT:C1129($attrs.query("name = :1"; "Picture").length=0; "allowObject: Picture still excluded")
ASSERT:C1129($attrs.query("name = :1"; "Alpha").length=1; "allowObject: scalar fields still present")

// isExcludedStorageType
ASSERT:C1129($dca.isExcludedStorageType({kind: "storage"; type: "blob"}; False:C215); "isExcludedStorageType: blob excluded")
ASSERT:C1129($dca.isExcludedStorageType({kind: "storage"; type: "image"}; False:C215); "isExcludedStorageType: image excluded")
ASSERT:C1129($dca.isExcludedStorageType({kind: "storage"; type: "object"}; False:C215); "isExcludedStorageType: object excluded when allowObject=False")
ASSERT:C1129(Not:C34($dca.isExcludedStorageType({kind: "storage"; type: "object"}; True:C214)); "isExcludedStorageType: object included when allowObject=True")
ASSERT:C1129(Not:C34($dca.isExcludedStorageType({kind: "storage"; type: "string"}; False:C215)); "isExcludedStorageType: scalar storage not excluded")
ASSERT:C1129(Not:C34($dca.isExcludedStorageType({kind: "relatedEntity"; type: "object"}; False:C215)); "isExcludedStorageType: non-storage kind not excluded")

// ══════════════════════════════════════════════════════════════════════

// ALERT("✅ All _dataclassAttributes tests passed!")
