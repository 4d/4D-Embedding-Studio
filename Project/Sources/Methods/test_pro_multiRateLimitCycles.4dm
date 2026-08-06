//%attributes = {}
// Verify multiple consecutive rate limit errors result in repeated pause/resume cycles.
// 3 consecutive 429s are returned before the 4th call succeeds; the embedder must
// retry (pause then resume) 3 times in a row and log one "Rate limit hit" warning
// per cycle, with an incrementing attempt counter.

var $client:=cs:C1710._TestAIKitClient.new({rateLimitCount: 3; backoffMs: 5})
var $embedder:=cs:C1710.Embedder.new({client: $client; backoffMs: 5; maxRetries: 3})

cs:C1710._Logger.me._capture:=[]
var $result : cs:C1710.EmbedderResult:=$embedder.embed("hello world"; "embed")

ASSERT:C1129($result.vector#Null:C1517; "embed should eventually succeed after 3 consecutive rate-limit cycles")
ASSERT:C1129($client.embeddings.callCount=4; "expected 4 calls (3 rate-limited + 1 success), got "+String:C10($client.embeddings.callCount))

var $logs : Collection:=cs:C1710._Logger.me._capture
var $rateLimitLogs : Collection:=$logs.query("message = :1"; "@\"event\":\"Rate limit hit\"@")
ASSERT:C1129($rateLimitLogs.length=3; "expected 3 pause/resume cycles logged, got "+String:C10($rateLimitLogs.length))

ASSERT:C1129($logs.query("message = :1 AND message = :2"; "@\"event\":\"Rate limit hit\"@"; "@\"attempt\":\"1/3\"@").length=1; "1st cycle should log attempt 1/3")
ASSERT:C1129($logs.query("message = :1 AND message = :2"; "@\"event\":\"Rate limit hit\"@"; "@\"attempt\":\"2/3\"@").length=1; "2nd cycle should log attempt 2/3")
ASSERT:C1129($logs.query("message = :1 AND message = :2"; "@\"event\":\"Rate limit hit\"@"; "@\"attempt\":\"3/3\"@").length=1; "3rd cycle should log attempt 3/3")

cs:C1710._Logger.me._capture:=Null:C1517
