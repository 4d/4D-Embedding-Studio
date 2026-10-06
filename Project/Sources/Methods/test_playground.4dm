//%attributes = {}
// Automated tests for cs.Playground (render + embed).

var $mockEmbedder:=Not:C34(Shift down:C543)

var $model:="embed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()

If (($mockEmbedder) && ($modelAlias=Null:C1517))
	var $file:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $data : Object:=($file.exists) ? JSON Parse:C1218($file.getText()) : {providers: {}; models: {}}
	If ($data.models=Null:C1517)
		$data.models:={}
	End if 
	$data.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	If ($data.providers["openai"]=Null:C1517)
		$data.providers["openai"]:={}
	End if 
	$file.setText(JSON Stringify:C1217($data; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()
End if 

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model aliases")))
	return 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_playground_tmp.json")

$settingsFile.setText(JSON Stringify:C1217({batchSize: 50; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $studentsDef : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_1")
ASSERT:C1129($studentsDef#Null:C1517; "students test definition missing")

// Seed fixtures
ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482._Students.all().drop()

var $cityParis:=ds:C1482.Cities.new()
$cityParis.name:="Paris"
$cityParis.state:="Ile-de-France"
ASSERT:C1129($cityParis.save().success; "failed to save Paris")

var $schoolParis:=ds:C1482.School.new()
$schoolParis.name:="Sorbonne"
$schoolParis.university:="Paris University"
$schoolParis.city_ID:=$cityParis.ID
ASSERT:C1129($schoolParis.save().success; "failed to save Sorbonne")

var $studentAlice:=ds:C1482._Students.new()
$studentAlice.firstName:="Alice"
$studentAlice.lastName:="Durand"
$studentAlice.school_ID:=$schoolParis.ID
ASSERT:C1129($studentAlice.save().success; "failed to save Alice")

var $embedder : Object:=$mockEmbedder ? cs:C1710._TestProcessEmbedder.new() : Null:C1517

// =====================================================
// render() tests
// =====================================================

var $pg:=cs:C1710.Playground.new($settings; {embedder: $embedder})

// --- render with definition ---
var $text : Text:=$pg.render($studentAlice; $studentsDef)
ASSERT:C1129($text="Alice Durand"; "render with definition: expected 'Alice Durand' got '"+$text+"'")

// --- render with Phrase ---
var $phrase : cs:C1710.Phrase:=cs:C1710.Phrase.new("Hello {firstName}")
$text:=$pg.render($studentAlice; $phrase)
ASSERT:C1129($text="Hello Alice"; "render with Phrase: expected 'Hello Alice' got '"+$text+"'")

// --- render with Text template ---
$text:=$pg.render($studentAlice; "Student: {lastName}")
ASSERT:C1129($text="Student: Durand"; "render with Text: expected 'Student: Durand' got '"+$text+"'")

// --- render with Null (auto-resolve, unique definition) ---
$text:=$pg.render($studentAlice)
ASSERT:C1129($text="Alice Durand"; "render auto-resolve: expected 'Alice Durand' got '"+$text+"'")

// --- render with Null entity returns empty ---
$text:=$pg.render(Null:C1517)
ASSERT:C1129($text=""; "render null entity should return empty")

// --- render with stub {vectorName} (resolved against entity's dataclass) ---
$text:=$pg.render($studentAlice; {vectorName: "student_vector_1"})
ASSERT:C1129($text="Alice Durand"; "render stub vectorName: expected 'Alice Durand' got '"+$text+"'")

// --- render with ad-hoc stub {phrase} ---
$text:=$pg.render($studentAlice; {phrase: "Hi {firstName}"})
ASSERT:C1129($text="Hi Alice"; "render stub phrase: expected 'Hi Alice' got '"+$text+"'")

// --- render with ad-hoc stub {template} ---
$text:=$pg.render($studentAlice; {template: "Name: {lastName}"})
ASSERT:C1129($text="Name: Durand"; "render stub template: expected 'Name: Durand' got '"+$text+"'")

// --- render with stub {vectorName} that doesn't exist → empty (no unique match) ---
$text:=$pg.render($studentAlice; {vectorName: "does_not_exist"})
ASSERT:C1129($text=""; "render stub unknown vectorName should return empty, got '"+$text+"'")

// --- render with stub whose dataclassName mismatches the entity → empty ---
$text:=$pg.render($studentAlice; {dataclassName: "School"; vectorName: "student_vector_1"})
ASSERT:C1129($text=""; "render stub mismatched dataclass should return empty, got '"+$text+"'")

// --- render with ad-hoc stub holding a compiled Phrase ---
$text:=$pg.render($studentAlice; {phrase: cs:C1710.Phrase.new("Yo {firstName}")})
ASSERT:C1129($text="Yo Alice"; "render stub Phrase: expected 'Yo Alice' got '"+$text+"'")

// --- render with an unsupported phrase argument (number) → empty ---
$text:=$pg.render($studentAlice; 42)
ASSERT:C1129($text=""; "render unsupported phrase type should return empty, got '"+$text+"'")

// =====================================================
// embed() tests
// =====================================================

// --- embed text + model ---
var $result : cs:C1710.EmbedderResult:=$pg.embed("hello world"; $model)
ASSERT:C1129($result#Null:C1517; "embed text+model should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed text+model should return a vector")

// --- embed text + definition ---
$result:=$pg.embed("hello world"; $studentsDef)
ASSERT:C1129($result#Null:C1517; "embed text+def should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed text+def should return a vector")

// --- embed entity + definition ---
$result:=$pg.embed($studentAlice; $studentsDef)
ASSERT:C1129($result#Null:C1517; "embed entity+def should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed entity+def should return a vector")

// --- embed entity + phrase + model ---
$result:=$pg.embed($studentAlice; $phrase; $model)
ASSERT:C1129($result#Null:C1517; "embed entity+phrase+model should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed entity+phrase+model should return a vector")

// --- embed entity + text template + model ---
$result:=$pg.embed($studentAlice; "Profile: {firstName}"; $model)
ASSERT:C1129($result#Null:C1517; "embed entity+template+model should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed entity+template+model should return a vector")

// --- embed entity auto-resolve (unique definition) ---
$result:=$pg.embed($studentAlice)
ASSERT:C1129($result#Null:C1517; "embed entity auto-resolve should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed entity auto-resolve should return a vector")

// --- embed entity + stub {vectorName} (deduces phrase + model) ---
$result:=$pg.embed($studentAlice; {vectorName: "student_vector_1"})
ASSERT:C1129($result#Null:C1517; "embed entity+stub vectorName should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed entity+stub vectorName should return a vector")

// --- embed entity + ad-hoc stub {phrase; modelAlias} ---
$result:=$pg.embed($studentAlice; {phrase: "Hi {firstName}"; modelAlias: $model})
ASSERT:C1129($result#Null:C1517; "embed entity+stub phrase/model should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed entity+stub phrase/model should return a vector")

// --- embed text + stub {modelAlias} ---
$result:=$pg.embed("hello world"; {modelAlias: $model})
ASSERT:C1129($result#Null:C1517; "embed text+stub model should return result")
ASSERT:C1129($result.vector#Null:C1517; "embed text+stub model should return a vector")

// --- embed with no model throws ---
var $threw : Boolean:=False:C215
Try
	$pg.embed("hello world")
Catch
	$threw:=True:C214
End try
ASSERT:C1129($threw; "embed with no model should throw")
Try(1)

// --- embed entity + stub {vectorName} that doesn't exist → throws (no phrase resolved) ---
$threw:=False:C215
Try
	$pg.embed($studentAlice; {vectorName: "does_not_exist"})
Catch
	$threw:=True:C214
End try
ASSERT:C1129($threw; "embed stub unknown vectorName should throw (no phrase)")
Try(1)

// --- embed text + stub that resolves no model → throws ---
$threw:=False:C215
Try
	$pg.embed("hello world"; {phrase: "ignored {x}"})
Catch
	$threw:=True:C214
End try
ASSERT:C1129($threw; "embed stub with no resolvable model should throw")
Try(1)

// --- embed with a Null entity → throws (no phrase resolved) ---
$threw:=False:C215
Try
	$pg.embed(Null:C1517)
Catch
	$threw:=True:C214
End try
ASSERT:C1129($threw; "embed null entity should throw (no phrase)")
Try(1)

// --- ambiguous auto-resolution (two definitions for the dataclass) ---
$settings.definitions.push(cs:C1710.Definition.new("_Students"; "student_vector_2"; $model; "{lastName}"))

$text:=$pg.render($studentAlice)
ASSERT:C1129($text=""; "render auto-resolve with 2 definitions should return empty, got '"+$text+"'")

// a phrase is given but no model, and the model cannot be deduced → throws
$threw:=False:C215
Try
	$pg.embed($studentAlice; $phrase)
Catch
	$threw:=True:C214
End try
ASSERT:C1129($threw; "embed with an ambiguous model should throw")
Try(1)

$settings.definitions.pop()

// =====================================================
// Cleanup
// =====================================================

ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482._Students.all().drop()
$settingsFile.delete()

