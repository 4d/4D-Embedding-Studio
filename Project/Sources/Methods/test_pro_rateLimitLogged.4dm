//%attributes = {}
// Verify rate limit pause/resume behavior is logged with error details.
// The "Rate limit hit" warning emitted by cs.Embedder must carry enough detail
// (model, delay, timestamp, attempt) to diagnose a pause/resume cycle after the fact.

var $client:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; retryAfterSec: 1})
var $embedder:=cs:C1710.Embedder.new({client: $client; backoffMs: 10; maxRetries: 3})

cs:C1710._Logger.me._capture:=[]
var $result : cs:C1710.EmbedderResult:=$embedder.embed("hello world"; "embed")
ASSERT:C1129($result.vector#Null:C1517; "embed should eventually succeed after the rate-limited attempt")

var $logs : Collection:=cs:C1710._Logger.me._capture
var $rateLimitLogs : Collection:=$logs.query("level = :1 AND message = :2"; Warning message:K38:2; "@\"event\":\"Rate limit hit\"@")
ASSERT:C1129($rateLimitLogs.length=1; "expected exactly 1 rate-limit log entry, got "+String:C10($rateLimitLogs.length))

var $message : Text:=$rateLimitLogs[0].message
ASSERT:C1129(Position:C15("\"model\":\"embed\""; $message)>0; "log should include the model: "+$message)
ASSERT:C1129(Position:C15("\"delay\":\"1000ms\""; $message)>0; "log should include the Retry-After delay: "+$message)
ASSERT:C1129(Position:C15("\"attempt\":\"1/3\""; $message)>0; "log should include the attempt counter: "+$message)
ASSERT:C1129(Position:C15("\"timestamp\":\""; $message)>0; "log should include a timestamp: "+$message)

cs:C1710._Logger.me._capture:=Null:C1517
