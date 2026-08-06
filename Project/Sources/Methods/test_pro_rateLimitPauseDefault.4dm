//%attributes = {}
// Verify scheduler pauses on rate limit error (429) and resumes with default delay
// (no Retry-After hint present, so cs.Embedder falls back to exponential backoff:
// backoffMs * 2^attempt).

var $client:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; backoffMs: 300})
var $embedder:=cs:C1710.Embedder.new({client: $client; backoffMs: 300; maxRetries: 3})

var $start : Integer:=Milliseconds:C459
var $result : cs:C1710.EmbedderResult:=$embedder.embed("hello world"; "embed")
var $elapsed : Integer:=Milliseconds:C459-$start

ASSERT:C1129($result.vector#Null:C1517; "embed should eventually succeed after the rate-limited attempt")
ASSERT:C1129($client.embeddings.callCount=2; "expected exactly 2 calls (1 rate-limited + 1 success), got "+String:C10($client.embeddings.callCount))
ASSERT:C1129($elapsed>=250; "expected the default backoff delay (~300ms) to have elapsed, got "+String:C10($elapsed)+"ms")
ASSERT:C1129($elapsed<3000; "default backoff delay took suspiciously long: "+String:C10($elapsed)+"ms")
