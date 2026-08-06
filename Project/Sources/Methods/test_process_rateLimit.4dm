//%attributes = {}
// Tests for _RateLimiter (unit) and rate-limit–aware batch processing (integration).

// =====================================================================================
// PART 1 — _RateLimiter unit tests
// =====================================================================================

// --- _parseResetDuration ---
var $limiter:=cs:C1710._RateLimiter.new(50)
ASSERT:C1129($limiter._parseResetDuration("")=0; "_parseResetDuration empty string")
ASSERT:C1129($limiter._parseResetDuration("1s")=1; "_parseResetDuration 1s")
ASSERT:C1129($limiter._parseResetDuration("30s")=30; "_parseResetDuration 30s")
ASSERT:C1129($limiter._parseResetDuration("6m0s")=360; "_parseResetDuration 6m0s")
ASSERT:C1129($limiter._parseResetDuration("1m30s")=90; "_parseResetDuration 1m30s")
ASSERT:C1129($limiter._parseResetDuration("200ms")=1; "_parseResetDuration 200ms rounds up")
ASSERT:C1129($limiter._parseResetDuration("1500ms")=2; "_parseResetDuration 1500ms rounds up")
ASSERT:C1129($limiter._parseResetDuration("1h0m0s")=3600; "_parseResetDuration 1h0m0s")
ASSERT:C1129($limiter._parseResetDuration("1h30m0s")=5400; "_parseResetDuration 1h30m0s")
ASSERT:C1129($limiter._parseResetDuration("45")=45; "_parseResetDuration bare number")

// --- nextBatchSize: unknown state (no update yet) returns configBatchSize ---
$limiter:=cs:C1710._RateLimiter.new(50)
ASSERT:C1129($limiter.nextBatchSize()=50; "nextBatchSize unknown state should return configBatchSize")

// --- nextBatchSize: custom configBatchSize ---
$limiter:=cs:C1710._RateLimiter.new(10)
ASSERT:C1129($limiter.nextBatchSize()=10; "nextBatchSize should respect custom configBatchSize")

// --- update + nextBatchSize: plenty of budget → configBatchSize ---
$limiter:=cs:C1710._RateLimiter.new(50)
var $plenty : cs:C1710.EmbedderResult:=cs:C1710.EmbedderResult.new({\
vectors: []; \
usage: {prompt_tokens: 500; total_tokens: 500}; \
rateLimit: {remaining: {tokens: 100000; request: 500}; limit: {tokens: 150000; request: 1000}; reset: {tokens: "1m0s"; request: "1s"}}}; True:C214)
$limiter.update($plenty; 10)
ASSERT:C1129($limiter.tokensPerEntity=50; "tokensPerEntity should be totalTokens/chunkSize = 500/10")
ASSERT:C1129($limiter.nextBatchSize()=50; "nextBatchSize with plenty of budget should stay at configBatchSize")

// --- update + nextBatchSize: low budget → reduced batch size ---
$limiter:=cs:C1710._RateLimiter.new(50)
var $tight : cs:C1710.EmbedderResult:=cs:C1710.EmbedderResult.new({\
vectors: []; \
usage: {prompt_tokens: 500; total_tokens: 500}; \
rateLimit: {remaining: {tokens: 500; request: 10}; limit: {tokens: 150000; request: 1000}; reset: {tokens: "6m0s"; request: "1s"}}}; True:C214)
$limiter.update($tight; 10)
// tokensPerEntity = 50, remaining = 500, target = Int(500*0.8/50) = 8
ASSERT:C1129($limiter.nextBatchSize()=8; "nextBatchSize with tight budget should be 8, got "+String:C10($limiter.nextBatchSize()))

// --- update + nextBatchSize: very low budget → floor of 1 ---
$limiter:=cs:C1710._RateLimiter.new(50)
var $critical : cs:C1710.EmbedderResult:=cs:C1710.EmbedderResult.new({\
vectors: []; \
usage: {prompt_tokens: 500; total_tokens: 500}; \
rateLimit: {remaining: {tokens: 10; request: 10}; limit: {tokens: 150000; request: 1000}; reset: {tokens: "6m0s"; request: "1s"}}}; True:C214)
$limiter.update($critical; 10)
// tokensPerEntity = 50, remaining = 10, target = Int(10*0.8/50) = 0 → clamped to 1
ASSERT:C1129($limiter.nextBatchSize()=1; "nextBatchSize with near-zero budget should be 1")

// --- update with null EmbedderResult does not crash ---
$limiter:=cs:C1710._RateLimiter.new(50)
$limiter.update(Null:C1517; 10)
ASSERT:C1129($limiter.remainingTokens=-1; "update with null should leave state unchanged")
ASSERT:C1129($limiter.nextBatchSize()=50; "nextBatchSize after null update should be configBatchSize")

// --- update with missing rate-limit data (ollama case) ---
$limiter:=cs:C1710._RateLimiter.new(50)
var $noRateLimit : cs:C1710.EmbedderResult:=cs:C1710.EmbedderResult.new({\
vectors: []; \
usage: {prompt_tokens: 100; total_tokens: 100}}; True:C214)
$limiter.update($noRateLimit; 5)
ASSERT:C1129($limiter.remainingTokens=-1; "missing rateLimit should leave remainingTokens at -1")
ASSERT:C1129($limiter.nextBatchSize()=50; "missing rateLimit should not reduce batch size")

// =====================================================================================
// PART 2 — Integration: batch size adaptation through Process
// =====================================================================================

var $model : Text:="embed"
var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model alias")))
	return 
End if 

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_ratelimit_tmp.json")

// batchSize=2 so we need >2 entities to get multiple batches
$settingsFile.setText(JSON Stringify:C1217({\
batchSize: 2; \
definitions: [{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
var $studentsDef : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_1")
ASSERT:C1129($studentsDef#Null:C1517; "students definition missing")

// Seed 6 students to guarantee multiple batches at batchSize=2
ds:C1482.Cities.all().drop()
ds:C1482.School.all().drop()
ds:C1482._Students.all().drop()
var $school:=ds:C1482.School.new()
$school.name:="Test School"
ASSERT:C1129($school.save().success; "failed to save school")
var $names : Collection:=["Alice Durand"; "Bob Martin"; "Claire Dupont"; "David Blanc"; "Emma Leroy"; "Frank Moreau"]
var $n : Text
For each ($n; $names)
	var $student:=ds:C1482._Students.new()
	$student.firstName:=Substring:C12($n; 1; Position:C15(" "; $n)-1)
	$student.lastName:=Substring:C12($n; Position:C15(" "; $n)+1)
	$student.school_ID:=$school.ID
	ASSERT:C1129($student.save().success; "failed to save "+$n)
End for each 

// --- Test A: plenty of budget → batch size stays at 2 ---
var $embedderA : cs:C1710._TestProcessEmbedder:=cs:C1710._TestProcessEmbedder.new({\
rateLimits: [\
{remaining: {tokens: 100000; request: 500}; limit: {tokens: 150000; request: 1000}; reset: {tokens: "1m0s"; request: "1s"}}]})

var $proc:=cs:C1710.Process.new($settings; {embedder: $embedderA; force: True:C214})
var $result : cs:C1710.ProcessResult:=$proc.process($studentsDef)
ASSERT:C1129($result.success; "plenty budget: "+JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=6; "plenty budget: should update all 6 entities")
ASSERT:C1129($embedderA.embedBatchCalls.length=3; "plenty budget: 6 entities / batch 2 = 3 calls, got "+String:C10($embedderA.embedBatchCalls.length))
ASSERT:C1129($embedderA.embedBatchCalls[0].texts.length=2; "plenty budget: first batch should be 2")
ASSERT:C1129($embedderA.embedBatchCalls[1].texts.length=2; "plenty budget: second batch should be 2")
ASSERT:C1129($embedderA.embedBatchCalls[2].texts.length=2; "plenty budget: third batch should be 2")

// --- Test B: low budget after second batch → batch size shrinks ---
// Batches 1-2: plenty of tokens → batch stays at 2
// After batch 2: only 15 tokens remaining with ~12 tokens/entity → nextBatchSize = Int(15*0.8/12) = 1
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate before low-budget test")

var $embedderB : cs:C1710._TestProcessEmbedder:=cs:C1710._TestProcessEmbedder.new({\
rateLimits: [\
{remaining: {tokens: 100000; request: 500}; limit: {tokens: 150000; request: 1000}; reset: {tokens: "1m0s"; request: "1s"}}; \
{remaining: {tokens: 15; request: 499}; limit: {tokens: 150000; request: 1000}; reset: {tokens: "1s"; request: "1s"}}]})

$proc:=cs:C1710.Process.new($settings; {embedder: $embedderB})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; "low budget: "+JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=6; "low budget: should still update all 6 entities")
ASSERT:C1129($embedderB.embedBatchCalls[0].texts.length=2; "low budget: first batch should be 2 (unknown state)")
ASSERT:C1129($embedderB.embedBatchCalls[1].texts.length=2; "low budget: second batch should be 2 (still plenty from first response)")
// After batch 2 update: remainingTokens=15, tokensPerEntity≈12 → nextBatchSize=1
ASSERT:C1129($embedderB.embedBatchCalls.length>3; "low budget: should produce more than 3 batches due to reduced size, got "+String:C10($embedderB.embedBatchCalls.length))
ASSERT:C1129($embedderB.embedBatchCalls[2].texts.length=1; "low budget: third batch should be 1, got "+String:C10($embedderB.embedBatchCalls[2].texts.length))

// --- Test C: no rate-limit data (ollama) → batch size stays at configBatchSize ---
ASSERT:C1129($studentsDef.invalidateVectors().errors.length=0; "failed to invalidate before no-ratelimit test")

var $embedderC : cs:C1710._TestProcessEmbedder:=cs:C1710._TestProcessEmbedder.new({\
rateLimits: [{remaining: {tokens: Null:C1517; request: Null:C1517}; limit: {tokens: Null:C1517; request: Null:C1517}; reset: {tokens: Null:C1517; request: Null:C1517}}]})

$proc:=cs:C1710.Process.new($settings; {embedder: $embedderC})
$result:=$proc.process($studentsDef)
ASSERT:C1129($result.success; "no ratelimit: "+JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($result.entitiesUpdated=6; "no ratelimit: should update all 6 entities")
ASSERT:C1129($embedderC.embedBatchCalls.length=3; "no ratelimit: should be 3 batches (no throttling), got "+String:C10($embedderC.embedBatchCalls.length))
ASSERT:C1129($embedderC.embedBatchCalls[0].texts.length=2; "no ratelimit: first batch should be 2")
ASSERT:C1129($embedderC.embedBatchCalls[1].texts.length=2; "no ratelimit: second batch should be 2")
ASSERT:C1129($embedderC.embedBatchCalls[2].texts.length=2; "no ratelimit: third batch should be 2")

// --- Cleanup ---
ds:C1482._Students.all().drop()
ds:C1482.School.all().drop()
$settingsFile.delete()

// =====================================================================================
// PART 3 — Embedder retry/backoff on 429 (cs.Embedder + fake AIKit client, no network)
// A different layer than PART 1/2 (which drive _RateLimiter): here the REAL cs.Embedder
// handles the pause/resume, backoff and Retry-After logic against a deterministic mock.
// =====================================================================================

//MARK:- test_pro_rateLimitRetryAfterHdr
// Resume after the delay specified by the Retry-After header. backoffMs is deliberately
// tiny so the observed delay can only be explained by the Retry-After hint being honored.
var $clientHdr:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; retryAfterSec: 1})
var $embedderHdr:=cs:C1710.Embedder.new({client: $clientHdr; backoffMs: 50; maxRetries: 3})

var $startHdr : Integer:=Milliseconds:C459
var $resHdr : cs:C1710.EmbedderResult:=$embedderHdr.embed("hello world"; "embed")
var $elapsedHdr : Integer:=Milliseconds:C459-$startHdr

ASSERT:C1129($resHdr.vector#Null:C1517; "embed should eventually succeed after the rate-limited attempt")
ASSERT:C1129($clientHdr.embeddings.callCount=2; "expected exactly 2 calls (1 rate-limited + 1 success), got "+String:C10($clientHdr.embeddings.callCount))
ASSERT:C1129($elapsedHdr>=900; "expected the Retry-After delay (~1000ms) to have elapsed, got "+String:C10($elapsedHdr)+"ms")
ASSERT:C1129($elapsedHdr<4000; "Retry-After delay took suspiciously long: "+String:C10($elapsedHdr)+"ms")

//MARK:- test_pro_rateLimitPauseDefault
// Resume with default delay when no Retry-After hint is present: cs.Embedder falls back to
// exponential backoff (backoffMs * 2^attempt).
var $clientDef:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; backoffMs: 300})
var $embedderDef:=cs:C1710.Embedder.new({client: $clientDef; backoffMs: 300; maxRetries: 3})

var $startDef : Integer:=Milliseconds:C459
var $resDef : cs:C1710.EmbedderResult:=$embedderDef.embed("hello world"; "embed")
var $elapsedDef : Integer:=Milliseconds:C459-$startDef

ASSERT:C1129($resDef.vector#Null:C1517; "embed should eventually succeed after the rate-limited attempt")
ASSERT:C1129($clientDef.embeddings.callCount=2; "expected exactly 2 calls (1 rate-limited + 1 success), got "+String:C10($clientDef.embeddings.callCount))
ASSERT:C1129($elapsedDef>=250; "expected the default backoff delay (~300ms) to have elapsed, got "+String:C10($elapsedDef)+"ms")
ASSERT:C1129($elapsedDef<3000; "default backoff delay took suspiciously long: "+String:C10($elapsedDef)+"ms")

//MARK:- test_pro_rateLimitLogged
// The "Rate limit hit" warning must carry enough detail (model, delay, attempt, timestamp)
// to diagnose a pause/resume cycle after the fact.
var $clientLog:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; retryAfterSec: 1})
var $embedderLog:=cs:C1710.Embedder.new({client: $clientLog; backoffMs: 10; maxRetries: 3})

cs:C1710._Logger.me._capture:=[]
var $resLog : cs:C1710.EmbedderResult:=$embedderLog.embed("hello world"; "embed")
ASSERT:C1129($resLog.vector#Null:C1517; "embed should eventually succeed after the rate-limited attempt")

var $logsRL : Collection:=cs:C1710._Logger.me._capture
var $rateLimitLogs : Collection:=$logsRL.query("level = :1 AND message = :2"; Warning message:K38:2; "@\"event\":\"Rate limit hit\"@")
ASSERT:C1129($rateLimitLogs.length=1; "expected exactly 1 rate-limit log entry, got "+String:C10($rateLimitLogs.length))

var $rlMessage : Text:=$rateLimitLogs[0].message
ASSERT:C1129(Position:C15("\"model\":\"embed\""; $rlMessage)>0; "log should include the model: "+$rlMessage)
ASSERT:C1129(Position:C15("\"delay\":\"1000ms\""; $rlMessage)>0; "log should include the Retry-After delay: "+$rlMessage)
ASSERT:C1129(Position:C15("\"attempt\":\"1/3\""; $rlMessage)>0; "log should include the attempt counter: "+$rlMessage)
ASSERT:C1129(Position:C15("\"timestamp\":\""; $rlMessage)>0; "log should include a timestamp: "+$rlMessage)
cs:C1710._Logger.me._capture:=Null:C1517

//MARK:- test_pro_multiRateLimitCycles
// 3 consecutive 429s before the 4th call succeeds: one "Rate limit hit" warning per cycle
// with an incrementing attempt counter.
var $clientMulti:=cs:C1710._TestAIKitClient.new({rateLimitCount: 3; backoffMs: 5})
var $embedderMulti:=cs:C1710.Embedder.new({client: $clientMulti; backoffMs: 5; maxRetries: 3})

cs:C1710._Logger.me._capture:=[]
var $resMulti : cs:C1710.EmbedderResult:=$embedderMulti.embed("hello world"; "embed")
ASSERT:C1129($resMulti.vector#Null:C1517; "embed should eventually succeed after 3 consecutive rate-limit cycles")
ASSERT:C1129($clientMulti.embeddings.callCount=4; "expected 4 calls (3 rate-limited + 1 success), got "+String:C10($clientMulti.embeddings.callCount))

var $logsMulti : Collection:=cs:C1710._Logger.me._capture
ASSERT:C1129($logsMulti.query("message = :1"; "@\"event\":\"Rate limit hit\"@").length=3; "expected 3 pause/resume cycles logged, got "+String:C10($logsMulti.query("message = :1"; "@\"event\":\"Rate limit hit\"@").length))
ASSERT:C1129($logsMulti.query("message = :1 AND message = :2"; "@\"event\":\"Rate limit hit\"@"; "@\"attempt\":\"1/3\"@").length=1; "1st cycle should log attempt 1/3")
ASSERT:C1129($logsMulti.query("message = :1 AND message = :2"; "@\"event\":\"Rate limit hit\"@"; "@\"attempt\":\"2/3\"@").length=1; "2nd cycle should log attempt 2/3")
ASSERT:C1129($logsMulti.query("message = :1 AND message = :2"; "@\"event\":\"Rate limit hit\"@"; "@\"attempt\":\"3/3\"@").length=1; "3rd cycle should log attempt 3/3")
cs:C1710._Logger.me._capture:=Null:C1517
