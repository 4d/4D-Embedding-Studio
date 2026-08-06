//%attributes = {}
// Verify scheduler resumes after delay specified in Retry-After header.
// backoffMs is deliberately tiny so the observed delay can only be explained
// by the Retry-After hint (retryAfterSec) being honored, not the exponential
// backoff fallback.

var $client:=cs:C1710._TestAIKitClient.new({rateLimitCount: 1; retryAfterSec: 1})
var $embedder:=cs:C1710.Embedder.new({client: $client; backoffMs: 50; maxRetries: 3})

var $start : Integer:=Milliseconds:C459
var $result : cs:C1710.EmbedderResult:=$embedder.embed("hello world"; "embed")
var $elapsed : Integer:=Milliseconds:C459-$start

ASSERT:C1129($result.vector#Null:C1517; "embed should eventually succeed after the rate-limited attempt")
ASSERT:C1129($client.embeddings.callCount=2; "expected exactly 2 calls (1 rate-limited + 1 success), got "+String:C10($client.embeddings.callCount))
ASSERT:C1129($elapsed>=900; "expected the Retry-After delay (~1000ms) to have elapsed, got "+String:C10($elapsed)+"ms")
ASSERT:C1129($elapsed<4000; "Retry-After delay took suspiciously long: "+String:C10($elapsed)+"ms")
