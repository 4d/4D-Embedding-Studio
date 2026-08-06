//%attributes = {}
// Verify no sensitive data (API keys, tokens) appears across all embedding diagnostic
// log events (Recalculation started/completed, Vector recomputed, Process error,
// Critical API error, Rate limit hit).

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
// prove it is absent from every captured log entry across every scenario below.
var $providersFile2:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
var $realApiKey : Text:=""
If ($providersFile2.exists)
	var $realProviders : Object:=JSON Parse:C1218($providersFile2.getText())
	If (($realProviders.providers#Null:C1517) && ($realProviders.providers.openai#Null:C1517))
		$realApiKey:=String:C10($realProviders.providers.openai.apiKey)
	End if 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_log_no_sensitive_data_tmp.json")
var $allLogs : Collection:=[]

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
	
	// Scenario 1: normal successful recomputation (Recalculation started/completed, Vector recomputed).
	cs:C1710._Logger.me._capture:=[]
	var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); debug: True:C214})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	$allLogs.combine(cs:C1710._Logger.me._capture)
	
	// Scenario 2: non-critical local failure (Process error).
	ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
	cs:C1710._Logger.me._capture:=[]
	$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})})
	$result:=$proc.process($def)
	ASSERT:C1129(Not:C34($result.success); "expected the non-critical failure scenario to fail")
	$allLogs.combine(cs:C1710._Logger.me._capture)
	
	// Scenario 3: critical API error.
	cs:C1710._Logger.me._capture:=[]
	$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: [$model]})})
	$result:=$proc.process($def)
	ASSERT:C1129(Not:C34($result.success); "expected the critical error scenario to fail")
	$allLogs.combine(cs:C1710._Logger.me._capture)
	
	// Scenario 4: rate limit hit + resume (real cs.Embedder + fake AIKit client, no real network).
	cs:C1710._Logger.me._capture:=[]
	var $client:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; backoffMs: 5})
	var $embedder:=cs:C1710.Embedder.new({client: $client; backoffMs: 5; maxRetries: 3})
	var $embedResult : cs:C1710.EmbedderResult:=$embedder.embed("hello world"; $model)
	ASSERT:C1129($embedResult.vector#Null:C1517; "expected the rate-limit scenario to eventually succeed")
	$allLogs.combine(cs:C1710._Logger.me._capture)
	
	ASSERT:C1129($allLogs.length>0; "expected captured logs across all scenarios")
	
	var $log : Object
	For each ($log; $allLogs)
		ASSERT:C1129(Position:C15("apiKey"; $log.message)=0; "no log entry should contain an 'apiKey' field: "+$log.message)
		ASSERT:C1129(Position:C15("api_key"; $log.message)=0; "no log entry should contain an 'api_key' field: "+$log.message)
		ASSERT:C1129(Position:C15("Authorization"; $log.message)=0; "no log entry should contain an Authorization header: "+$log.message)
		ASSERT:C1129(Position:C15("Bearer "; $log.message)=0; "no log entry should contain a Bearer token: "+$log.message)
		ASSERT:C1129(Position:C15("sk-"; $log.message)=0; "no log entry should contain an OpenAI-style secret key prefix: "+$log.message)
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

