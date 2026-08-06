//%attributes = {}
// Verifies dirty flag remains true when vector recalculation fails
// due to an embedding error (before save).

var $model:="embed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()

If ($modelAlias=Null:C1517)
	// test-only alias bootstrap (same approach as existing process tests)
	var $file:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $data : Object:=($file.exists) ? JSON Parse:C1218($file.getText()) : {providers: {}; models: {}}
	
	If ($data.providers["openai"]=Null:C1517)
		$data.providers["openai"]:={}
	End if
	$data.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	$file.setText(JSON Stringify:C1217($data; *))
	
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
End if

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model aliases")))
	return
End if

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_dirty_embed_failure_tmp.json")

$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
ASSERT:C1129($def#Null:C1517; "test definition missing")

// Deterministic fixture set.
ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482._Students.all().drop()

var $city:=ds:C1482.Cities.new()
$city.name:="Paris"
$city.state:="Ile-de-France"
ASSERT:C1129($city.save().success; "failed to save city")

var $school:=ds:C1482.School.new()
$school.name:="Sorbonne"
$school.university:="Paris University"
$school.city_ID:=$city.ID
ASSERT:C1129($school.save().success; "failed to save school")

var $student:=ds:C1482._Students.new()
$student.firstName:="Alice"
$student.lastName:="Durand"
$student.school_ID:=$school.ID
ASSERT:C1129($student.save().success; "failed to save student")

// Compute once so invalidateVectors can set dirty=true with a non-null vector.
var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
var $result : cs:C1710.ProcessResult:=$proc.process($def)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))

ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")

$student:=ds:C1482._Students.get($student.ID)
ASSERT:C1129($student.student_vector_2#Null:C1517; "vector should remain non-null in dirty mode")
ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty should be true before failed recalculation")

// Force embed failure on the exact rendered phrase.
var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})

$proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
$result:=$proc.process($def)

ASSERT:C1129(Not:C34($result.success); "embed failure should mark process as failed")
ASSERT:C1129($result.entitiesConsidered=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=0; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.apiCalls=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.errors.query("code = :1"; cs:C1710.ProcessErrorCode.me.EMBED_FAILED).length=1; JSON Stringify:C1217($result.toObject()))

$student:=ds:C1482._Students.get($student.ID)
ASSERT:C1129(Bool:C1537($student.student_vector_2_dirty); "dirty flag must remain true when recalculation fails")

$settingsFile.delete()