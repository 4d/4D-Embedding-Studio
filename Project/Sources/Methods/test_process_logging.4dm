//%attributes = {}
// Diagnostic logging contract (cs._Logger events emitted by cs.Process / cs.Embedder).

If (Not:C34(Asserted:C1132(cs:C1710._TestFixtures.me.ensureAliases(["embed"]); "you must configure an 'embed' model alias")))
	return 
End if 

var $codes:=cs:C1710.ProcessErrorCode.me

// Read the real configured secret once (never echoed into any assertion message) so the
// no-secret sections can prove it is absent from the logs.
var $realApiKey : Text:=""
var $providersFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
If ($providersFile.exists)
	var $realProviders : Object:=JSON Parse:C1218($providersFile.getText())
	If (($realProviders.providers#Null:C1517) && ($realProviders.providers.openai#Null:C1517))
		$realApiKey:=String:C10($realProviders.providers.openai.apiKey)
	End if 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_logging_tmp.json")
$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: "embed"; phrase: "{firstName} {lastName}"}]}))
var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
ASSERT:C1129($def#Null:C1517; "test definition missing")

//MARK:- test_pro_logFormatAndLocation
// Unit-level: entries go to the 4D diagnostic log, are prefixed with the standard tag,
// serialize object payloads as valid JSON, and map info/warn/error/debug to the right level.
var $logger:=cs:C1710._Logger.me
ASSERT:C1129($logger.outputType=Into 4D diagnostic log:K38:8; "logger should write into the 4D diagnostic log")

$logger._capture:=[]
$logger.info("plain text info message")
$logger.warn({event: "test warn"; detail: "x"})
$logger.error({event: "test error"; detail: "y"})
$logger.debug({event: "test debug"; detail: "z"})
var $fmtLogs : Collection:=$logger._capture
ASSERT:C1129($fmtLogs.length=4; "expected 4 captured entries, got "+String:C10($fmtLogs.length))

var $entry : Object
For each ($entry; $fmtLogs)
	ASSERT:C1129(Position:C15($logger.prefix; $entry.message)=1; "every log entry should start with the standard prefix: "+$entry.message)
End for each 

var $objMessage : Text:=$fmtLogs[1].message
var $jsonPart : Text:=Substring:C12($objMessage; Length:C16($logger.prefix)+2)
var $parsed : Variant:=Try(JSON Parse:C1218($jsonPart))
ASSERT:C1129(Value type:C1509($parsed)=Is object:K8:27; "object payloads should serialize as valid JSON: "+$objMessage)
ASSERT:C1129($parsed.event="test warn"; "parsed JSON should round-trip the original payload: "+$objMessage)

ASSERT:C1129($fmtLogs[0].level=Information message:K38:1; "info() should log at Information message level")
ASSERT:C1129($fmtLogs[1].level=Warning message:K38:2; "warn() should log at Warning message level")
ASSERT:C1129($fmtLogs[2].level=Error message:K38:3; "error() should log at Error message level")
ASSERT:C1129($fmtLogs[3].level=Information message:K38:1; "debug() currently reuses Information message level (no Debug level exists)")
$logger._capture:=Null:C1517

//MARK:- test_pro_logLocalErrorLevel
// Unit-level: exercises ProcessResult._addError() (single source of truth for mirroring
// recorded errors to the diagnostic log) — a SAVE_FAILED is logged at Error level with detail.
cs:C1710._Logger.me._capture:=[]
var $report:=cs:C1710.ProcessResult.new()
$report._addError("entity"; $codes.SAVE_FAILED; "_Students.42"; "Record has been modified by another process")

var $localErrLogs : Collection:=cs:C1710._Logger.me._capture.query("level = :1 AND message = :2"; Error message:K38:3; "@\"event\":\"Process error\"@")
ASSERT:C1129($localErrLogs.length=1; "expected exactly one Error-level 'Process error' log for SAVE_FAILED, got "+String:C10($localErrLogs.length))
var $localMsg : Text:=$localErrLogs[0].message
ASSERT:C1129(Position:C15("\"scope\":\"entity\""; $localMsg)>0; "log should include the entity scope: "+$localMsg)
ASSERT:C1129(Position:C15("\"code\":"+String:C10($codes.SAVE_FAILED); $localMsg)>0; "log should include the SAVE_FAILED code: "+$localMsg)
ASSERT:C1129(Position:C15("\"ref\":\"_Students.42\""; $localMsg)>0; "log should include the entity reference: "+$localMsg)
ASSERT:C1129(Position:C15("\"severity\":\"error\""; $localMsg)>0; "log should include the error severity: "+$localMsg)
ASSERT:C1129(Position:C15("Record has been modified by another process"; $localMsg)>0; "log should include the failure message: "+$localMsg)
cs:C1710._Logger.me._capture:=Null:C1517

//MARK:- test_process_failureLogging
// Integration: a real local embed failure emits a 'Process error' event (EMBED_FAILED)
// at chunk scope, with the vector reference and the embed failure message.
var $seed:=cs:C1710._TestFixtures.me.seedStudents(1)
var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
var $result : cs:C1710.ProcessResult:=$proc.process($def)  // compute once, then recompute via dirty
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")

cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})})
$result:=$proc.process($def)
ASSERT:C1129(Not:C34($result.success); "recalculation should fail")
ASSERT:C1129($result.errors.query("code = :1"; $codes.EMBED_FAILED).length=1; JSON Stringify:C1217($result.toObject()))
var $failLogs : Collection:=cs:C1710._Logger.me._capture
ASSERT:C1129($failLogs.query("message = :1 AND message = :2"; "@\"event\":\"Process error\"@"; "@\"code\":"+String:C10($codes.EMBED_FAILED)+"@").length>0; "failure log should include Process error event with EMBED_FAILED code")
ASSERT:C1129($failLogs.query("message = :1"; "@\"scope\":\"chunk\"@").length>0; "failure log should include chunk scope")
ASSERT:C1129($failLogs.query("message = :1"; "@\"ref\":\"_Students.student_vector_2\"@").length>0; "failure log should include vector reference")
ASSERT:C1129($failLogs.query("message = :1"; "@Non-critical test failure for Alice Durand@").length>0; "failure log should include the embed failure message")
cs:C1710._Logger.me._capture:=Null:C1517

//MARK:- test_pro_logRecalcStarted
// 'Recalculation started' logged at Info level with vector ref, pending count and timestamp.
cs:C1710._TestFixtures.me.seedStudents(1)
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.process($def)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
var $startedLogs : Collection:=cs:C1710._Logger.me._capture.query("level = :1 AND message = :2"; Information message:K38:1; "@\"event\":\"Recalculation started\"@")
ASSERT:C1129($startedLogs.length=1; "expected exactly one 'Recalculation started' Info log, got "+String:C10($startedLogs.length))
var $startedMsg : Text:=$startedLogs[0].message
ASSERT:C1129(Position:C15("\"vector\":\"_Students.student_vector_2\""; $startedMsg)>0; "log should include the vector reference: "+$startedMsg)
ASSERT:C1129(Position:C15("\"entities\":1"; $startedMsg)>0; "log should include the pending entity count: "+$startedMsg)
ASSERT:C1129(Position:C15("\"timestamp\":\""; $startedMsg)>0; "log should include a timestamp: "+$startedMsg)
cs:C1710._Logger.me._capture:=Null:C1517

//MARK:- test_pro_logRecalcCompleted
// 'Recalculation completed' logged at Info level with success/failure counts and duration.
// batchSize=1: Alice succeeds, Bob fails non-critically → deterministic 1 success / 1 failure.
cs:C1710._TestFixtures.me.seedStudents(2)
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Bob Martin"]})})
$result:=$proc.process($def)
ASSERT:C1129(Not:C34($result.success); JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesSkipped=1; JSON Stringify:C1217($result.toObject()))
var $completedLogs : Collection:=cs:C1710._Logger.me._capture.query("level = :1 AND message = :2"; Information message:K38:1; "@\"event\":\"Recalculation completed\"@")
ASSERT:C1129($completedLogs.length=1; "expected exactly one 'Recalculation completed' Info log, got "+String:C10($completedLogs.length))
var $completedMsg : Text:=$completedLogs[0].message
ASSERT:C1129(Position:C15("\"vector\":\"_Students.student_vector_2\""; $completedMsg)>0; "log should include the vector reference: "+$completedMsg)
ASSERT:C1129(Position:C15("\"success\":1"; $completedMsg)>0; "log should include the success count: "+$completedMsg)
ASSERT:C1129(Position:C15("\"failure\":1"; $completedMsg)>0; "log should include the failure count: "+$completedMsg)
ASSERT:C1129(Position:C15("\"duration\":\""; $completedMsg)>0; "log should include a duration: "+$completedMsg)
cs:C1710._Logger.me._capture:=Null:C1517

//MARK:- test_pro_logVectorRecomputed / test_process_successLogging
// With debug enabled, a 'Vector recomputed' entry (with entityID) is logged per entity.
cs:C1710._TestFixtures.me.seedStudents(2)
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); debug: True:C214})
$result:=$proc.process($def)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=2; JSON Stringify:C1217($result.toObject()))
var $recomputedLogs : Collection:=cs:C1710._Logger.me._capture.query("level = :1 AND message = :2"; Information message:K38:1; "@Vector recomputed — vector: _Students.student_vector_2@")
ASSERT:C1129($recomputedLogs.length=2; "expected one 'Vector recomputed' log per entity (2 entities), got "+String:C10($recomputedLogs.length))
var $recEntry : Object
For each ($recEntry; $recomputedLogs)
	ASSERT:C1129(Position:C15("entityID:"; $recEntry.message)>0; "each 'Vector recomputed' log should include an entityID: "+$recEntry.message)
End for each 
cs:C1710._Logger.me._capture:=Null:C1517

//MARK:- test_pro_logCriticalErrorNoKey
// 'Critical API error' logged at Error level with the model, and never any API key.
cs:C1710._TestFixtures.me.seedStudents(1)
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: ["embed"]})})
$result:=$proc.process($def)
ASSERT:C1129(Not:C34($result.success); "batch should fail on the critical API error")
var $critLogs : Collection:=cs:C1710._Logger.me._capture.query("level = :1 AND message = :2"; Error message:K38:3; "@\"event\":\"Critical API error\"@")
ASSERT:C1129($critLogs.length=1; "expected exactly one Error-level 'Critical API error' log, got "+String:C10($critLogs.length))
ASSERT:C1129(Position:C15("\"model\":\"embed\""; $critLogs[0].message)>0; "log should include the model: "+$critLogs[0].message)
var $critEntry : Object
For each ($critEntry; cs:C1710._Logger.me._capture)
	ASSERT:C1129(Position:C15("apiKey"; $critEntry.message)=0; "no log entry should contain an 'apiKey' field")
	ASSERT:C1129(Position:C15("Authorization"; $critEntry.message)=0; "no log entry should contain an Authorization header")
	If (Length:C16($realApiKey)>0)
		ASSERT:C1129(Position:C15($realApiKey; $critEntry.message)=0; "no log entry should contain the real configured API key")
	End if 
End for each 
cs:C1710._Logger.me._capture:=Null:C1517

//MARK:- test_pro_noApiKeyInLogs
// No secret (API key / token) leaks across every embedding diagnostic event:
// success (started/completed/recomputed), local failure, critical error, and rate-limit hit.
cs:C1710._TestFixtures.me.seedStudents(1)
var $allLogs : Collection:=[]

// Scenario 1: successful recomputation with debug.
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new(); debug: True:C214})
$result:=$proc.process($def)
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
$allLogs.combine(cs:C1710._Logger.me._capture)

// Scenario 2: non-critical local failure.
ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({nonCriticalTexts: ["Alice Durand"]})})
$result:=$proc.process($def)
ASSERT:C1129(Not:C34($result.success); "expected the non-critical failure scenario to fail")
$allLogs.combine(cs:C1710._Logger.me._capture)

// Scenario 3: critical API error.
cs:C1710._Logger.me._capture:=[]
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: ["embed"]})})
$result:=$proc.process($def)
ASSERT:C1129(Not:C34($result.success); "expected the critical error scenario to fail")
$allLogs.combine(cs:C1710._Logger.me._capture)

// Scenario 4: rate-limit hit + resume (real cs.Embedder + fake AIKit client, no network).
cs:C1710._Logger.me._capture:=[]
var $client:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; backoffMs: 5})
var $embedder:=cs:C1710.Embedder.new({client: $client; backoffMs: 5; maxRetries: 3})
var $embedResult : cs:C1710.EmbedderResult:=$embedder.embed("hello world"; "embed")
ASSERT:C1129($embedResult.vector#Null:C1517; "expected the rate-limit scenario to eventually succeed")
$allLogs.combine(cs:C1710._Logger.me._capture)

ASSERT:C1129($allLogs.length>0; "expected captured logs across all scenarios")
var $entry2 : Object
For each ($entry2; $allLogs)
	ASSERT:C1129(Position:C15("apiKey"; $entry2.message)=0; "no log entry should contain an 'apiKey' field: "+$entry2.message)
	ASSERT:C1129(Position:C15("api_key"; $entry2.message)=0; "no log entry should contain an 'api_key' field: "+$entry2.message)
	ASSERT:C1129(Position:C15("Authorization"; $entry2.message)=0; "no log entry should contain an Authorization header: "+$entry2.message)
	ASSERT:C1129(Position:C15("Bearer "; $entry2.message)=0; "no log entry should contain a Bearer token: "+$entry2.message)
	ASSERT:C1129(Position:C15("sk-"; $entry2.message)=0; "no log entry should contain an OpenAI-style secret key prefix: "+$entry2.message)
	If (Length:C16($realApiKey)>0)
		ASSERT:C1129(Position:C15($realApiKey; $entry2.message)=0; "no log entry should contain the real configured API key")
	End if 
End for each 
cs:C1710._Logger.me._capture:=Null:C1517

If ($settingsFile.exists)
	$settingsFile.delete()
End if 
