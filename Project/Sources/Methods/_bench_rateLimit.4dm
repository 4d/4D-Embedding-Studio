//%attributes = {}
// _bench_rateLimit — headless rate-limit benchmark for 4D Embedding Studio.
//
// Runs one or more embedding scenarios against a local mock embedding server
// (SimpleEmbeddingMock) so the rate-limit / retry / adaptive-batch behaviour can
// be observed and correlated with the mock server log, the 4D diagnostic log and
// the vectors execution log.
//
// Configuration is read from Settings/bench_ratelimit.json (written by the bench
// script). Results are written to Logs/bench_ratelimit_result.json.
// The method enables the 4D diagnostic log, runs every scenario, then QUIT 4D.
//
// Launch (full 4D, needs real data — not tool4d):
//   /Applications/4D.app/Contents/MacOS/4D \
//     --project="Project/4D Embedding Studio.4DProject" \
//     --startup-method=_bench_rateLimit --skip-onstartup --headless

// --- enable the 4D diagnostic log so _Logger rate-limit events are persisted ---
SET DATABASE PARAMETER:C642(79; 1)  // 79 = Diagnostic log recording -> ON (Logs/4DDiagnosticLog_X.txt)

If (cs:C1710.AIKit=Null:C1517)
	LOG EVENT:C667(Into system standard outputs:K38:9; "[bench] FATAL: AIKit component not loaded"+Char:C90(Line feed:K15:40); Error message:K38:3)
	QUIT 4D:C291
	return 
End if 

// --- load configuration -------------------------------------------------------
var $dbFolder : 4D:C1709.Folder:=Folder:C1567(fk database folder:K87:14)
var $configFile : 4D:C1709.File:=$dbFolder.file("Settings/bench_ratelimit.json")
var $cfg : Object:={}
If ($configFile.exists)
	$cfg:=Try(JSON Parse:C1218($configFile.getText()))
	If (Value type:C1509($cfg)#Is object:K8:27)
		$cfg:={}
	End if 
End if 

var $baseURL : Text:=($cfg.baseURL#Null:C1517) ? String:C10($cfg.baseURL) : "http://127.0.0.1:8080/v1/"
var $apiKey : Text:=($cfg.apiKey#Null:C1517) ? String:C10($cfg.apiKey) : "none"
var $model : Text:=($cfg.model#Null:C1517) ? String:C10($cfg.model) : "perf-zero-1536"
var $alias : Text:=($cfg.alias#Null:C1517) ? String:C10($cfg.alias) : "benchmock"
var $providerName : Text:=($cfg.providerName#Null:C1517) ? String:C10($cfg.providerName) : "benchmock"
var $phrase : Text:=($cfg.phrase#Null:C1517) ? String:C10($cfg.phrase) : "{firstName} {lastName}"
var $dataclassName : Text:=($cfg.dataclassName#Null:C1517) ? String:C10($cfg.dataclassName) : "_Students"
var $vectorName : Text:=($cfg.vectorName#Null:C1517) ? String:C10($cfg.vectorName) : "student_vector_1"
var $maxRetries : Integer:=($cfg.maxRetries#Null:C1517) ? Num:C11($cfg.maxRetries) : 5
var $backoffMs : Integer:=($cfg.backoffMs#Null:C1517) ? Num:C11($cfg.backoffMs) : 500

var $scenarios : Collection
If (($cfg.scenarios#Null:C1517) && (Value type:C1509($cfg.scenarios)=Is collection:K8:32) && ($cfg.scenarios.length>0))
	$scenarios:=$cfg.scenarios
Else 
	$scenarios:=[{name: "default"; entities: 200; batchSize: 50}]
End if 

var $dc : 4D:C1709.DataClass:=ds:C1482[$dataclassName]
If ($dc=Null:C1517)
	LOG EVENT:C667(Into system standard outputs:K38:9; "[bench] FATAL: dataclass '"+$dataclassName+"' not found"+Char:C90(Line feed:K15:40); Error message:K38:3)
	QUIT 4D:C291
	return 
End if 

var $hasFirst : Boolean:=($dc["firstName"]#Null:C1517)
var $hasLast : Boolean:=($dc["lastName"]#Null:C1517)

// --- report shell -------------------------------------------------------------
var $report : Object:={\
tool: "_bench_rateLimit"; \
startedAt: Timestamp:C1445; \
localDate: String:C10(Current date:C33); \
localTime: String:C10(Current time:C178); \
baseURL: $baseURL; \
model: $model; \
alias: $alias; \
provider: $providerName; \
dataclassName: $dataclassName; \
vectorName: $vectorName; \
maxRetries: $maxRetries; \
backoffMs: $backoffMs; \
scenarios: []}

// --- register a temporary AIKit provider + model alias pointing at the mock ----
// The pipeline validates that modelAlias is a known alias (AIProviders.json) and
// resolves the alias to its provider baseURL, so we must register one. The
// original file is backed up and restored once the benchmark is done.
var $aiFile : 4D:C1709.File:=$dbFolder.file("Project/Sources/AIProviders.json")
var $aiExisted : Boolean:=$aiFile.exists
var $aiBackup : Text:=($aiExisted) ? $aiFile.getText() : ""
var $ai : Object:=($aiExisted) ? Try(JSON Parse:C1218($aiBackup)) : {}
If (Value type:C1509($ai)#Is object:K8:27)
	$ai:={}
End if 
If (Value type:C1509($ai.providers)#Is object:K8:27)
	$ai.providers:={}
End if 
If (Value type:C1509($ai.models)#Is object:K8:27)
	$ai.models:={}
End if 

// AIKit builds "<baseURL>/embeddings", so drop any trailing slash.
var $providerURL : Text:=$baseURL
While (($providerURL#"") && ($providerURL[[Length:C16($providerURL)]]="/"))
	$providerURL:=Substring:C12($providerURL; 1; Length:C16($providerURL)-1)
End while 

$ai.providers[$providerName]:={baseURL: $providerURL}
If (($apiKey#"") && ($apiKey#"none"))
	$ai.providers[$providerName].apiKey:=$apiKey
End if 
$ai.models[$alias]:={provider: $providerName; model: $model}
$aiFile.setText(JSON Stringify:C1217($ai; *))

LOG EVENT:C667(Into system standard outputs:K38:9; "[bench] registered alias '"+$alias+"' -> "+$providerURL+" ("+$model+")"+Char:C90(Line feed:K15:40))

// --- run each scenario --------------------------------------------------------
var $settingsFile : 4D:C1709.File:=$dbFolder.file("Settings/__bench_ratelimit_tmp.json")

var $sc : Object
For each ($sc; $scenarios)
	
	var $name : Text:=($sc.name#Null:C1517) ? String:C10($sc.name) : "scenario"
	var $entities : Integer:=($sc.entities#Null:C1517) ? Num:C11($sc.entities) : 200
	var $batchSize : Integer:=($sc.batchSize#Null:C1517) ? Num:C11($sc.batchSize) : 50
	If ($batchSize<1)
		$batchSize:=50
	End if 
	If ($entities<1)
		$entities:=1
	End if 
	
	// Ensure the dataclass holds exactly $entities rows (create or drop the surplus).
	var $current : Integer:=$dc.all().length
	If ($current<$entities)
		var $toCreate : Integer:=$entities-$current
		var $k : Integer:=0
		While ($k<$toCreate)
			var $e : 4D:C1709.Entity:=$dc.new()
			If ($hasFirst)
				$e["firstName"]:="First_"+String:C10(Abs:C99(Random:C100))
			End if 
			If ($hasLast)
				$e["lastName"]:="Last_"+String:C10(Abs:C99(Random:C100))
			End if 
			$e.save()
			$k+=1
		End while 
	Else 
		If ($current>$entities)
			$dc.all().slice($entities).drop()
		End if 
	End if 
	
	// Temporary settings file describing one definition pointing at the mock alias.
	$settingsFile.setText(JSON Stringify:C1217({\
		batchSize: $batchSize; \
		definitions: [{dataclassName: $dataclassName; vectorName: $vectorName; modelAlias: $alias; phrase: $phrase}]}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	
	// The model alias (AIProviders.json) resolves to the mock baseURL; the embedder
	// only needs the retry/backoff policy under test.
	var $embedder : cs:C1710.Embedder:=cs:C1710.Embedder.new({maxRetries: $maxRetries; backoffMs: $backoffMs})
	
	var $proc : cs:C1710.Process:=cs:C1710.Process.new($settings; {embedder: $embedder; force: True:C214})
	
	cs:C1710._Logger.me.info({event: "bench scenario start"; scenario: $name; entities: $entities; batchSize: $batchSize; model: $model})
	LOG EVENT:C667(Into system standard outputs:K38:9; "[bench] scenario '"+$name+"' start entities="+String:C10($entities)+" batchSize="+String:C10($batchSize)+Char:C90(Line feed:K15:40); Information message:K38:1)
	
	var $startMs : Integer:=Milliseconds:C459
	var $startTs : Text:=Timestamp:C1445
	var $result : cs:C1710.ProcessResult:=Null:C1517
	var $runError : Text:=""
	Try
		$result:=$proc.process()
	Catch
		$runError:=String:C10(Last errors:C1799[0].message)
	End try
	var $wallMs : Integer:=Milliseconds:C459-$startMs
	var $endTs : Text:=Timestamp:C1445
	
	var $scOut : Object:={\
		name: $name; \
		entities: $entities; \
		batchSize: $batchSize; \
		startTs: $startTs; \
		endTs: $endTs; \
		wallMs: $wallMs}
	If ($result#Null:C1517)
		$scOut.result:=$result.toObject()
	End if 
	If (Length:C16($runError)>0)
		$scOut.error:=$runError
	End if 
	$report.scenarios.push($scOut)
	
	cs:C1710._Logger.me.info({event: "bench scenario done"; scenario: $name; wallMs: $wallMs; \
		updated: ($result#Null:C1517) ? $result.entitiesUpdated : 0; \
		apiCalls: ($result#Null:C1517) ? $result.apiCalls : 0})
	var $scSuccess : Text:=(($result#Null:C1517) && ($result.success)) ? "true" : "false"
	LOG EVENT:C667(Into system standard outputs:K38:9; "[bench] scenario '"+$name+"' done wallMs="+String:C10($wallMs)\
		+" updated="+String:C10(($result#Null:C1517) ? $result.entitiesUpdated : 0)\
		+" apiCalls="+String:C10(($result#Null:C1517) ? $result.apiCalls : 0)\
		+" success="+$scSuccess+Char:C90(Line feed:K15:40))
	
End for each 

// --- finalize -----------------------------------------------------------------
$report.finishedAt:=Timestamp:C1445

// Restore the original AIProviders.json.
If ($aiExisted)
	$aiFile.setText($aiBackup)
Else 
	Try($aiFile.delete())
End if 

Try($settingsFile.delete())

var $logsFolder : 4D:C1709.Folder:=Folder:C1567(fk logs folder:K87:17)
$logsFolder.file("bench_ratelimit_result.json").setText(JSON Stringify:C1217($report; *))

LOG EVENT:C667(Into system standard outputs:K38:9; "[bench] complete scenarios="+String:C10($report.scenarios.length)+" -> Logs/bench_ratelimit_result.json"+Char:C90(Line feed:K15:40); Information message:K38:1)

QUIT 4D:C291
