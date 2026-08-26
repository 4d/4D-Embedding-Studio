//%attributes = {}
// Unit tests for cs.Definition.validate()

var $def : cs:C1710.Definition
var $result : Object

// ══════════════════════════════════════════════════════════════════════
// IDENTITY
// ══════════════════════════════════════════════════════════════════════

//MARK:- missing dataclass name
$def:=cs:C1710.Definition.new(""; "student_vector_1"; "m"; "{firstName}")
$result:=$def.validate(Null:C1517)
ASSERT:C1129(Not:C34($result.success); "missing dataclassName: should not validate")
ASSERT:C1129($result.errors[0].field="dataclassName"; "missing dataclassName: error field mismatch")

//MARK:- missing vector name
$def:=cs:C1710.Definition.new("_Students"; ""; "m"; "{firstName}")
$result:=$def.validate(Null:C1517)
ASSERT:C1129(Not:C34($result.success); "missing vectorName: should not validate")
ASSERT:C1129($result.errors[0].field="vectorName"; "missing vectorName: error field mismatch")

//MARK:- unknown dataclass
$def:=cs:C1710.Definition.new("NoSuchDataclass"; "student_vector_1"; "m"; "{firstName}")
$result:=$def.validate(Null:C1517)
ASSERT:C1129(Not:C34($result.success); "unknown dataclass: should not validate")
ASSERT:C1129($result.errors.query("field = :1"; "dataclassName").length=1; "unknown dataclass: should report the dataclass")

// ══════════════════════════════════════════════════════════════════════
// ATTRIBUTE NAMES THE QUERY PARSER CANNOT READ INLINE
// A 4D field name may contain a space (or a "." or "="). Interpolated into
// a query string it breaks; passed as a placeholder it works. This is why
// every query built from a definition uses placeholders — the assertions
// below pin that difference.
// ══════════════════════════════════════════════════════════════════════

//MARK:- setup: an object attribute holding a key with a space
ds:C1482.AllTypes.all().drop()
var $probe : 4D:C1709.Entity:=ds:C1482.AllTypes.new()
var $payload : Object:={}
$payload["my key"]:="x"
$probe.Object:=$payload
ASSERT:C1129($probe.save().success; "spaced path: setup entity should save")

//MARK:- interpolated, the parser reads the space as part of the expression
var $interpolated : Variant:=Try(ds:C1482.AllTypes.all().query("Object.my key = :1"; "x").length)
ASSERT:C1129($interpolated=Null:C1517; "spaced path: an interpolated attribute path is expected to fail")

//MARK:- as a placeholder, the very same path works
var $placeheld : Variant:=Try(ds:C1482.AllTypes.all().query(":1 = :2"; "Object.my key"; "x").length)
ASSERT:C1129($placeheld=1; "spaced path: the placeholder form should find the entity, got "+String:C10($placeheld))

ds:C1482.AllTypes.all().drop()

//MARK:- a vector name is not rejected for its shape, only for not existing
$def:=cs:C1710.Definition.new("_Students"; "student_vector_1"; "m"; "{firstName}")
$result:=$def.validate(Null:C1517)
ASSERT:C1129($result.errors.query("field = :1"; "vectorName").length=0; "existing vectorName: no vector name error expected")

// ══════════════════════════════════════════════════════════════════════
// TARGET FIELD
// ══════════════════════════════════════════════════════════════════════

//MARK:- attribute that is not a vector
$def:=cs:C1710.Definition.new("_Students"; "firstName"; "m"; "{firstName}")
$result:=$def.validate(Null:C1517)
ASSERT:C1129(Not:C34($result.success); "non-vector attribute: should not validate")
ASSERT:C1129($result.errors.query("field = :1"; "vectorName").length=1; "non-vector attribute: should report the vector name")

//MARK:- unknown attribute
$def:=cs:C1710.Definition.new("_Students"; "no_such_attribute"; "m"; "{firstName}")
$result:=$def.validate(Null:C1517)
ASSERT:C1129(Not:C34($result.success); "unknown attribute: should not validate")
ASSERT:C1129($result.errors.query("field = :1"; "vectorName").length=1; "unknown attribute: should report the vector name")
