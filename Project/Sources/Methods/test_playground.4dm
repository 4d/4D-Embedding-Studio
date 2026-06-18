//%attributes = {}
// Automated tests for cs.EmbeddingStudio.Playground (render + embed).

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
{dataclassName: "Students"; vectorName: "student_vector_1"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $studentsDef : cs:C1710.Definition:=$settings.find("Students"; "student_vector_1")
ASSERT:C1129($studentsDef#Null:C1517; "students test definition missing")

// Seed fixtures
ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482.Students.all().drop()

var $cityParis:=ds:C1482.Cities.new()
$cityParis.name:="Paris"
$cityParis.state:="Ile-de-France"
ASSERT:C1129($cityParis.save().success; "failed to save Paris")

var $schoolParis:=ds:C1482.School.new()
$schoolParis.name:="Sorbonne"
$schoolParis.university:="Paris University"
$schoolParis.city_ID:=$cityParis.ID
ASSERT:C1129($schoolParis.save().success; "failed to save Sorbonne")

var $studentAlice:=ds:C1482.Students.new()
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

// --- embed with no model throws ---
var $threw : Boolean:=False:C215
Try
	$pg.embed("hello world")
Catch
	$threw:=True:C214
End try
ASSERT:C1129($threw; "embed with no model should throw")

// =====================================================
// Cleanup
// =====================================================

ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482.Students.all().drop()
$settingsFile.delete()

