//%attributes = {}
// Verify 'Critical API error' event is logged at Error level without exposing the API key.

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

// Read the real configured secret (never echoed into any assertion message) so we can
// prove it is absent from every captured log entry across this run.
var $providersFile2:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
var $realApiKey : Text:=""
If ($providersFile2.exists)
	var $realProviders : Object:=JSON Parse:C1218($providersFile2.getText())
	If (($realProviders.providers#Null:C1517) && ($realProviders.providers.openai#Null:C1517))
		$realApiKey:=String:C10($realProviders.providers.openai.apiKey)
	End if 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_log_critical_no_key_tmp.json")

Try
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
	
	var $student:=ds:C1482._Students.new()
	$student.firstName:="Alice"
	$student.lastName:="Durand"
	$student.school_ID:=$school.ID
	ASSERT:C1129($student.save().success; "failed to save student")
	
	cs:C1710._Logger.me._capture:=[]
	var $failingEmbedder:=cs:C1710._TestProcessEmbedder.new({criticalModels: [$model]})
	var $proc:=cs:C1710.Process.new($settings; {embedder: $failingEmbedder})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	ASSERT:C1129(Not:C34($result.success); "batch should fail on the critical API error")
	
	var $logs : Collection:=cs:C1710._Logger.me._capture
	var $criticalLogs : Collection:=$logs.query("level = :1 AND message = :2"; Error message:K38:3; "@\"event\":\"Critical API error\"@")
	ASSERT:C1129($criticalLogs.length=1; "expected exactly one Error-level 'Critical API error' log, got "+String:C10($criticalLogs.length))
	
	var $message : Text:=$criticalLogs[0].message
	ASSERT:C1129(Position:C15("\"model\":\""+$model+"\""; $message)>0; "log should include the model: "+$message)
	
	// No log entry (across the whole run, any level) may leak API-key-shaped data.
	var $log : Object
	For each ($log; $logs)
		ASSERT:C1129(Position:C15("apiKey"; $log.message)=0; "no log entry should contain an 'apiKey' field")
		ASSERT:C1129(Position:C15("api_key"; $log.message)=0; "no log entry should contain an 'api_key' field")
		ASSERT:C1129(Position:C15("Authorization"; $log.message)=0; "no log entry should contain an Authorization header")
		If (Length:C16($realApiKey)>0)
			ASSERT:C1129(Position:C15($realApiKey; $log.message)=0; "no log entry should contain the real configured API key")
		End if 
	End for each 
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
cs:C1710._Logger.me._capture:=Null:C1517
If ($settingsFile.exists)
	$settingsFile.delete()
End if 
