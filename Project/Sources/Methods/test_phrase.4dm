//%attributes = {}
// Unit tests for cs.embed.Phrase

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
// DEFAULT VALUE TESTS (pipe syntax)
// ══════════════════════════════════════════════════════════════════════

// --- Default used when key missing ---
$tpl:=cs:C1710.Phrase.new("{name|Anonymous}")
$result:=$tpl.render({})
ASSERT:C1129($result="Anonymous"; "Default missing: expected 'Anonymous', got '"+$result+"'")

// --- Default used when value is Null ---
$tpl:=cs:C1710.Phrase.new("{name|Anonymous}")
$result:=$tpl.render({name: Null:C1517})
ASSERT:C1129($result="Anonymous"; "Default null: expected 'Anonymous', got '"+$result+"'")

// --- Default used when value is empty string ---
$tpl:=cs:C1710.Phrase.new("{name|Anonymous}")
$result:=$tpl.render({name: ""})
ASSERT:C1129($result="Anonymous"; "Default empty: expected 'Anonymous', got '"+$result+"'")

// --- Default ignored when value is present ---
$tpl:=cs:C1710.Phrase.new("{name|Anonymous}")
$result:=$tpl.render({name: "Alice"})
ASSERT:C1129($result="Alice"; "Default ignored: expected 'Alice', got '"+$result+"'")

// --- Numeric 0 is NOT treated as missing ---
$tpl:=cs:C1710.Phrase.new("{age|unknown}")
$result:=$tpl.render({age: 0})
ASSERT:C1129($result="0"; "Default zero: expected '0', got '"+$result+"'")

// --- False is NOT treated as missing (default must NOT be used) ---
$tpl:=cs:C1710.Phrase.new("{active|n/a}")
$result:=$tpl.render({active: False:C215})
ASSERT:C1129($result#"n/a"; "Default false: expected NOT 'n/a', got '"+$result+"'")
ASSERT:C1129($result#""; "Default false: expected non-empty, got '"+$result+"'")

// --- Default text untrimmed ---
$tpl:=cs:C1710.Phrase.new("[{x| n/a }]")
$result:=$tpl.render({})
ASSERT:C1129($result="[ n/a ]"; "Default untrimmed: expected '[ n/a ]', got '"+$result+"'")

// --- Multiple | only first is separator ---
$tpl:=cs:C1710.Phrase.new("{x|a|b}")
$result:=$tpl.render({})
ASSERT:C1129($result="a|b"; "Default multi-pipe: expected 'a|b', got '"+$result+"'")

// --- Whitespace around field name still trimmed; default untrimmed ---
$tpl:=cs:C1710.Phrase.new("{ name | Anonymous}")
ASSERT:C1129($tpl.keys[0]="name"; "Default trim key: expected 'name', got '"+$tpl.keys[0]+"'")
$result:=$tpl.render({})
ASSERT:C1129($result=" Anonymous"; "Default trim val: expected ' Anonymous', got '"+$result+"'")

// --- Dot-notation with default — empty string triggers default ---
$tpl:=cs:C1710.Phrase.new("{user.name|Anonymous}")
$result:=$tpl.render({user: {name: ""}})
ASSERT:C1129($result="Anonymous"; "Default dot empty: expected 'Anonymous', got '"+$result+"'")

// --- Dot-notation with default — present value wins ---
$result:=$tpl.render({user: {name: "Alice"}})
ASSERT:C1129($result="Alice"; "Default dot present: expected 'Alice', got '"+$result+"'")

// --- Dot-notation with default — missing intermediate triggers default ---
$result:=$tpl.render({})
ASSERT:C1129($result="Anonymous"; "Default dot missing: expected 'Anonymous', got '"+$result+"'")

// --- keys getter unaffected by defaults ---
$tpl:=cs:C1710.Phrase.new("{firstName|X} {lastName|Y}")
ASSERT:C1129($tpl.keys.length=2; "Default keys: expected 2 keys")
ASSERT:C1129($tpl.keys[0]="firstName"; "Default keys[0]: expected 'firstName', got '"+$tpl.keys[0]+"'")
ASSERT:C1129($tpl.keys[1]="lastName"; "Default keys[1]: expected 'lastName', got '"+$tpl.keys[1]+"'")

// --- User's example end-to-end ---
$tpl:=cs:C1710.Phrase.new("Customer {firstName|Anonymous} from {city|unknown city}, registered {signupDate|recently}.")
$result:=$tpl.render({firstName: ""; city: Null:C1517})
ASSERT:C1129($result="Customer Anonymous from unknown city, registered recently."; "Default e2e: got '"+$result+"'")

// --- Empty default = empty render (no-op) ---
$tpl:=cs:C1710.Phrase.new("{name|}")
$result:=$tpl.render({})
ASSERT:C1129($result=""; "Default empty default: expected '', got '"+$result+"'")

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
$v:=$tpl.validate(ds:C1482.Students)
ASSERT:C1129($v.success; "Validate simple: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- Valid dot-notation through N:1 relation (with allowRelations) ---
// Students.school → School (N:1), School.name is a field
$tpl:=cs:C1710.Phrase.new("{firstName} at {school.name}")
$v:=$tpl.validate(ds:C1482.Students; {allowRelations: True:C214})
ASSERT:C1129($v.success; "Validate N:1: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- Valid deep dot-notation (with allowRelations) ---
// Students.school → School → School.city → Cities, Cities.name
$tpl:=cs:C1710.Phrase.new("{firstName} in {school.city.name}")
$v:=$tpl.validate(ds:C1482.Students; {allowRelations: True:C214})
ASSERT:C1129($v.success; "Validate deep N:1: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- Invalid: dot-notation rejected by default (no options) ---
$tpl:=cs:C1710.Phrase.new("{firstName} at {school.name}")
$v:=$tpl.validate(ds:C1482.Students)
ASSERT:C1129(Not:C34($v.success); "Validate relations not allowed: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate relations not allowed: expected 1 error")

// --- Invalid: N:1 relation as simple key rejected by default ---
$tpl:=cs:C1710.Phrase.new("{school}")
$v:=$tpl.validate(ds:C1482.Students)
ASSERT:C1129(Not:C34($v.success); "Validate relatedEntity not allowed: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate relatedEntity not allowed: expected 1 error")

// --- Invalid: attribute does not exist ---
$tpl:=cs:C1710.Phrase.new("{nonExistent}")
$v:=$tpl.validate(ds:C1482.Students)
ASSERT:C1129(Not:C34($v.success); "Validate nonExistent: expected failure")
ASSERT:C1129($v.errors.length=1; "Validate nonExistent: expected 1 error")

// --- Invalid: vector attribute ---
$tpl:=cs:C1710.Phrase.new("{student_vector_1}")
$v:=$tpl.validate(ds:C1482.Students)
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
$v:=$tpl.validate(ds:C1482.Students; {allowRelations: True:C214})
ASSERT:C1129(Not:C34($v.success); "Validate non-relation path: expected failure")

// --- Invalid: non-existent in deep path (with allowRelations) ---
$tpl:=cs:C1710.Phrase.new("{school.nonExistent}")
$v:=$tpl.validate(ds:C1482.Students; {allowRelations: True:C214})
ASSERT:C1129(Not:C34($v.success); "Validate deep nonExistent: expected failure")
ASSERT:C1129($v.errors[0].key="school.nonExistent"; "Validate deep: error key mismatch")

// --- Invalid: vector in related dataclass (with allowRelations) ---
$tpl:=cs:C1710.Phrase.new("{school.school_vector_1}")
$v:=$tpl.validate(ds:C1482.Students; {allowRelations: True:C214})
ASSERT:C1129(Not:C34($v.success); "Validate related vector: expected failure")

// --- Multiple errors ---
$tpl:=cs:C1710.Phrase.new("{nonExistent} {student_vector_1} {firstName}")
$v:=$tpl.validate(ds:C1482.Students)
ASSERT:C1129(Not:C34($v.success); "Validate multi-error: expected failure")
ASSERT:C1129($v.errors.length=2; "Validate multi-error: expected 2 errors, got "+String:C10($v.errors.length))

// --- validate() ignores defaults (valid fields with defaults pass) ---
$tpl:=cs:C1710.Phrase.new("{firstName|Anon} {lastName|}")
$v:=$tpl.validate(ds:C1482.Students)
ASSERT:C1129($v.success; "Validate with defaults: expected success, errors: "+JSON Stringify:C1217($v.errors))

// --- validate() reports missing field even when a default is present ---
$tpl:=cs:C1710.Phrase.new("{nonExistent|fallback}")
$v:=$tpl.validate(ds:C1482.Students)
ASSERT:C1129(Not:C34($v.success); "Validate default+missing: expected failure")
ASSERT:C1129($v.errors[0].key="nonExistent"; "Validate default+missing: error key mismatch, got '"+$v.errors[0].key+"'")

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

// ALERT("✅ All Phrase tests passed!")