//%attributes = {}
// Verify 'Recalculation completed' event is logged at Info level with success/failure counts.

var $model:="embed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()

If ($modelAlias=Null:C1517)
	var $providersFile:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $providersData : Object:=($providersFile.exists) ? JSON Parse:C1218($providersFile.getText()) : {providers: {}; models: {}}
	If ($providersData.providers["openai"]=Null:C1517)
		$providersData.providers["openai"]:={}
	End if 
	$providersData.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	$providersFile.setText(JSON Stringify:C1217($providersData; *))
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
End if 

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model alias")))
	return 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_log_recalc_completed_tmp.json")

Try
	// batchSize=1 forces one chunk per entity: Alice succeeds, Bob's rendered phrase
	// is configured to fail non-critically, giving a deterministic 1 success / 1 failure count.
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
		{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
	ASSERT:C1129($def#Null:C1517; "test definition missing")
	
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
	
	var $studentA:=ds:C1482._Students.new()
	$studentA.firstName:="Alice"
	$studentA.lastName:="Durand"
	$studentA.school_ID:=$school.ID
	ASSERT:C1129($studentA.save().success; "failed to save student A")
	
	var $studentB:=ds:C1482._Students.new()
	$studentB.firstName:="Bob"
	$studentB.lastName:="Martin"
	$studentB.school_ID:=$school.ID
	ASSERT:C1129($studentB.save().success; "failed to save student B")
	
	cs:C1710._Logger.me._capture:=[]
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Bob Martin"]})
	var $proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	ASSERT:C1129(Not:C34($result.success); JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
	
	var $logs : Collection:=cs:C1710._Logger.me._capture
	var $completedLogs : Collection:=$logs.query("level = :1 AND message = :2"; Information message:K38:1; "@\"event\":\"Recalculation completed\"@")
	ASSERT:C1129($completedLogs.length=1; "expected exactly one 'Recalculation completed' Info log, got "+String:C10($completedLogs.length))
	
	var $message : Text:=$completedLogs[0].message
	ASSERT:C1129(Position:C15("\"vector\":\"_Students.student_vector_2\""; $message)>0; "log should include the vector reference: "+$message)
	ASSERT:C1129(Position:C15("\"success\":1"; $message)>0; "log should include the success count: "+$message)
	ASSERT:C1129(Position:C15("\"failure\":1"; $message)>0; "log should include the failure count: "+$message)
	ASSERT:C1129(Position:C15("\"duration\":\""; $message)>0; "log should include a duration: "+$message)
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
cs:C1710._Logger.me._capture:=Null:C1517
If ($settingsFile.exists)
	$settingsFile.delete()
End if 

