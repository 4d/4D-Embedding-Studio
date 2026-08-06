// Test-only mock AIKit client. Exposes the same shape cs.Embedder relies on
// (This.client.embeddings.create($input; $model)) so cs.Embedder's real retry/
// backoff/Retry-After logic can be exercised deterministically in tests.
//
// Usage:
//   var $client:=cs._TestAIKitClient.new({rateLimitCount: 1; retryAfterSec: 1})
//   var $embedder:=cs.Embedder.new({client: $client; backoffMs: 10; maxRetries: 3})

property embeddings : cs:C1710._TestAIKitEmbeddingsAPI

Class constructor($options : Object)
	This:C1470.embeddings:=cs:C1710._TestAIKitEmbeddingsAPI.new($options)
