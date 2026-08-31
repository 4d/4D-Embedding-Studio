//%attributes = {}
// Unit tests for cs.Phrase

var $tpl : cs:C1710.Phrase
var $result : Text

// ══════════════════════════════════════════════════════════════════════
// COMPILE & RENDER TESTS
// ══════════════════════════════════════════════════════════════════════

// --- Simple variable ---
$tpl:=cs:C1710.Phrase.new("Hello {name}!")
ASSERT:C1129($tpl.keys.length=1; "Expected 1 key, got "+String:C10($tpl.keys.length))
ASSERT:C1129($tpl.keys[0]="name"; "Expected key 'name', got '"+$tpl.keys[0]+"'")
$result:=$tpl.render({name: "World"})
ASSERT:C1129($result="Hello World!"; "Simple: expected 'Hello World!', got '"+$result+"'")

// --- Multiple variables ---
$tpl:=cs:C1710.Phrase.new("{first} {last}")
ASSERT:C1129($tpl.keys.length=2; "Expected 2 keys")
$result:=$tpl.render({first: "John"; last: "Doe"})
ASSERT:C1129($result="John Doe"; "Multiple: expected 'John Doe', got '"+$result+"'")

// --- No variables (static text) ---
$tpl:=cs:C1710.Phrase.new("Just static text")
ASSERT:C1129($tpl.keys.length=0; "Expected 0 keys for static text")
$result:=$tpl.render({})
ASSERT:C1129($result="Just static text"; "Static: expected 'Just static text', got '"+$result+"'")

// --- Missing key renders empty ---
$tpl:=cs:C1710.Phrase.new("Hi {name}!")
$result:=$tpl.render({})
ASSERT:C1129($result="Hi !"; "Missing key: expected 'Hi !', got '"+$result+"'")

// --- Whitespace trimmed in keys ---
$tpl:=cs:C1710.Phrase.new("{ name }")
ASSERT:C1129($tpl.keys[0]="name"; "Trim: expected 'name', got '"+$tpl.keys[0]+"'")
$result:=$tpl.render({name: "Alice"})
ASSERT:C1129($result="Alice"; "Trim render: expected 'Alice', got '"+$result+"'")

// --- Reuse with different data ---
$tpl:=cs:C1710.Phrase.new("{greeting} {name}!")
$result:=$tpl.render({greeting: "Hello"; name: "Alice"})
ASSERT:C1129($result="Hello Alice!"; "Reuse 1: expected 'Hello Alice!', got '"+$result+"'")
$result:=$tpl.render({greeting: "Bonjour"; name: "Bob"})
ASSERT:C1129($result="Bonjour Bob!"; "Reuse 2: expected 'Bonjour Bob!', got '"+$result+"'")

// --- Numeric value ---
$tpl:=cs:C1710.Phrase.new("{name} is {age} years old")
$result:=$tpl.render({name: "Alice"; age: 30})
ASSERT:C1129($result="Alice is 30 years old"; "Numeric: expected 'Alice is 30 years old', got '"+$result+"'")

// --- Template property ---
$tpl:=cs:C1710.Phrase.new("Hello {name}")
ASSERT:C1129($tpl.template="Hello {name}"; "Template property mismatch")

// --- Empty template ---
$tpl:=cs:C1710.Phrase.new("")
ASSERT:C1129($tpl.keys.length=0; "Empty tpl: expected 0 keys")
$result:=$tpl.render({})
ASSERT:C1129($result=""; "Empty tpl: expected empty result, got '"+$result+"'")

// --- Adjacent variables ---
$tpl:=cs:C1710.Phrase.new("{a}{b}{c}")
ASSERT:C1129($tpl.keys.length=3; "Adjacent: expected 3 keys")
$result:=$tpl.render({a: "1"; b: "2"; c: "3"})
ASSERT:C1129($result="123"; "Adjacent: expected '123', got '"+$result+"'")

// ══════════════════════════════════════════════════════════════════════
// DOT-NOTATION TESTS
// ══════════════════════════════════════════════════════════════════════

// --- Dot-notation render ---
$tpl:=cs:C1710.Phrase.new("{user.name} in {user.address.city}")
ASSERT:C1129($tpl.keys.length=2; "Dot: expected 2 keys")
ASSERT:C1129($tpl.keys[0]="user.name"; "Dot: expected 'user.name'")
$result:=$tpl.render({user: {name: "Alice"; address: {city: "Paris"}}})
ASSERT:C1129($result="Alice in Paris"; "Dot render: expected 'Alice in Paris', got '"+$result+"'")

// --- Dot-notation missing intermediate ---
$tpl:=cs:C1710.Phrase.new("{a.b.c}")
$result:=$tpl.render({a: {x: 1}})
ASSERT:C1129($result=""; "Dot missing: expected empty, got '"+$result+"'")

// ══════════════════════════════════════════════════════════════════════
// VALIDATE TESTS (against real DataClasses)
// ══════════════════════════════════════════════════════════════════════

var $v : Object

// --- Valid simple attributes ---
$tpl:=cs:C1710.Phrase.new("{firstName} {lastName}")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129($v.success; "Validate simple: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- Valid dot-notation through N:1 relation (with allowRelations) ---
// Students.school → School (N:1), School.name is a field
$tpl:=cs:C1710.Phrase.new("{firstName} at {school.name}")
$v:=$tpl.validate(ds:C1482._Students; {allowRelations: True:C214})
ASSERT:C1129($v.success; "Validate N:1: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- Valid deep dot-notation (with allowRelations) ---
// Students.school → School → School.city → Cities, Cities.name
$tpl:=cs:C1710.Phrase.new("{firstName} in {school.city.name}")
$v:=$tpl.validate(ds:C1482._Students; {allowRelations: True:C214})
ASSERT:C1129($v.success; "Validate deep N:1: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- Invalid: dot-notation rejected by default (no options) ---
$tpl:=cs:C1710.Phrase.new("{firstName} at {school.name}")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129(Not:C34($v.success); "Validate relations not allowed: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate relations not allowed: expected 1 error")

// --- Invalid: N:1 relation as simple key rejected by default ---
$tpl:=cs:C1710.Phrase.new("{school}")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129(Not:C34($v.success); "Validate relatedEntity not allowed: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate relatedEntity not allowed: expected 1 error")

// --- Invalid: attribute does not exist ---
$tpl:=cs:C1710.Phrase.new("{nonExistent}")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129(Not:C34($v.success); "Validate nonExistent: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate nonExistent: expected 1 error")

// --- Invalid: vector attribute ---
$tpl:=cs:C1710.Phrase.new("{student_vector_1}")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129(Not:C34($v.success); "Validate vector: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate vector: expected 1 error")

// --- Invalid: 1:N relation as final key ---
// School.strudents is a 1:N relation (relatedEntities)
$tpl:=cs:C1710.Phrase.new("{strudents}")
$v:=$tpl.validate(ds:C1482.School)
ASSERT:C1129(Not:C34($v.success); "Validate 1:N: expected failure")

// --- Invalid: intermediate is not a relation (with allowRelations) ---
// Students.firstName is a storage field, not a relation
$tpl:=cs:C1710.Phrase.new("{firstName.something}")
$v:=$tpl.validate(ds:C1482._Students; {allowRelations: True:C214})
ASSERT:C1129(Not:C34($v.success); "Validate non-relation path: expected failure")

// --- Invalid: non-existent in deep path (with allowRelations) ---
$tpl:=cs:C1710.Phrase.new("{school.nonExistent}")
$v:=$tpl.validate(ds:C1482._Students; {allowRelations: True:C214})
ASSERT:C1129(Not:C34($v.success); "Validate deep nonExistent: expected failure")
ASSERT:C1129($v.errors[0].key="school.nonExistent"; "Validate deep: error key mismatch")

// --- Invalid: vector in related dataclass (with allowRelations) ---
$tpl:=cs:C1710.Phrase.new("{school.school_vector_1}")
$v:=$tpl.validate(ds:C1482._Students; {allowRelations: True:C214})
ASSERT:C1129(Not:C34($v.success); "Validate related vector: expected failure")

// --- Multiple errors ---
$tpl:=cs:C1710.Phrase.new("{nonExistent} {student_vector_1} {firstName}")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129(Not:C34($v.success); "Validate multi-error: expected failure")
ASSERT:C1129($v.errors.length=2; "Validate multi-error: expected 2 errors, got "+String:C10($v.errors.length))

// --- "_dirty" sibling of the CURRENT vector → error (would invalidate forever) ---
// student_vector_2_dirty is the dirty flag of the student_vector_2 vector
$tpl:=cs:C1710.Phrase.new("{firstName} {student_vector_2_dirty}")
$v:=$tpl.validate(ds:C1482._Students; Null:C1517; "student_vector_2")
ASSERT:C1129(Not:C34($v.success); "Validate own dirty: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate own dirty: expected 1 error")
ASSERT:C1129($v.errors[0].key="student_vector_2_dirty"; "Validate own dirty: error key mismatch")
ASSERT:C1129($v.warnings.length=0; "Validate own dirty: expected 0 warnings")

// --- "_dirty" sibling of ANOTHER vector → warning (useless, not blocking) ---
$tpl:=cs:C1710.Phrase.new("{firstName} {student_vector_2_dirty}")
$v:=$tpl.validate(ds:C1482._Students; Null:C1517; "student_vector_1")
ASSERT:C1129($v.success; "Validate other dirty: expected success (warning only)")
ASSERT:C1129($v.errors.length=0; "Validate other dirty: expected 0 errors")
ASSERT:C1129($v.warnings.length=1; "Validate other dirty: expected 1 warning")
ASSERT:C1129($v.warnings[0].key="student_vector_2_dirty"; "Validate other dirty: warning key mismatch")

// --- "_dirty" sibling with no current vector → warning ---
$tpl:=cs:C1710.Phrase.new("{student_vector_2_dirty}")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129($v.success; "Validate dirty no-vector: expected success (warning only)")
ASSERT:C1129($v.warnings.length=1; "Validate dirty no-vector: expected 1 warning")

// ══════════════════════════════════════════════════════════════════════
// VALIDATE TESTS — AllTypes (blob, object, picture rejected)
// ══════════════════════════════════════════════════════════════════════

// --- Scalar storage types accepted ---
$tpl:=cs:C1710.Phrase.new("{Alpha} {Text} {Date} {Time} {Boolean} {Integer} {LongInteger} {Integer64} {Real}")
$v:=$tpl.validate(ds:C1482.AllTypes)
ASSERT:C1129($v.success; "AllTypes scalars: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- Blob rejected ---
$tpl:=cs:C1710.Phrase.new("{Blob}")
$v:=$tpl.validate(ds:C1482.AllTypes)
ASSERT:C1129(Not:C34($v.success); "AllTypes Blob: expected failure")
ASSERT:C1129($v.errors.length=1; "AllTypes Blob: expected 1 error")
ASSERT:C1129($v.errors[0].key="Blob"; "AllTypes Blob: error key mismatch")

// --- Picture rejected ---
$tpl:=cs:C1710.Phrase.new("{Picture}")
$v:=$tpl.validate(ds:C1482.AllTypes)
ASSERT:C1129(Not:C34($v.success); "AllTypes Picture: expected failure")
ASSERT:C1129($v.errors.length=1; "AllTypes Picture: expected 1 error")
ASSERT:C1129($v.errors[0].key="Picture"; "AllTypes Picture: error key mismatch")

// --- Object rejected ---
$tpl:=cs:C1710.Phrase.new("{Object}")
$v:=$tpl.validate(ds:C1482.AllTypes)
ASSERT:C1129(Not:C34($v.success); "AllTypes Object: expected failure")
ASSERT:C1129($v.errors.length=1; "AllTypes Object: expected 1 error")
ASSERT:C1129($v.errors[0].key="Object"; "AllTypes Object: error key mismatch")

// --- Multiple unsupported types produce one error each ---
$tpl:=cs:C1710.Phrase.new("{Blob} {Picture} {Object} {Alpha}")
$v:=$tpl.validate(ds:C1482.AllTypes)
ASSERT:C1129(Not:C34($v.success); "AllTypes multi unsupported: expected failure")
ASSERT:C1129($v.errors.length=3; "AllTypes multi unsupported: expected 3 errors, got "+String:C10($v.errors.length))

// ══════════════════════════════════════════════════════════════════════
// VALIDATE TESTS — phrase with no key fields
// ══════════════════════════════════════════════════════════════════════

// --- Static-only phrase is rejected ---
$tpl:=cs:C1710.Phrase.new("Just static text, no variables")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129(Not:C34($v.success); "No key fields: expected failure")
ASSERT:C1129($v.errors.length=1; "No key fields: expected 1 error, got "+String:C10($v.errors.length))
ASSERT:C1129($v.errors[0].key=""; "No key fields: error key should be empty")

// --- Empty phrase is accepted (phrase not yet configured) ---
$tpl:=cs:C1710.Phrase.new("")
$v:=$tpl.validate(ds:C1482._Students)
ASSERT:C1129($v.success; "Empty phrase: expected success")

// ══════════════════════════════════════════════════════════════════════

// ALERT("✅ All Phrase tests passed!")