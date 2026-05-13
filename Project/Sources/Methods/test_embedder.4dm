//%attributes = {}
// Automated tests for cs.embed.Embedder against the 4DAIKitTest embeddings mock.

var $client:=cs:C1710.AIKit.OpenAI.new()
var $mockBased:=Position:C15("127.0.0.1"; $client.baseURL)>0
var $model:="text-embedding-ada-002"
If ($mockBased)
	$client.apiKey:="none"
Else 
	
	var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name="embed")).first()
	If ($modelAlias=Null:C1517)
		If (Not:C34(Asserted:C1132(Length:C16(String:C10($client.apiKey))>0; "mock based not configured you must have key or you must configure an 'embed' model aliases")))
			return 
		End if 
	Else 
		$model:="embed"
	End if 
End if 

var $embedder:=cs:C1710.Embedder.new({client: $client; maxRetries: 2; backoffMs: 1})

// --- Single text success ---
var $embedResult : cs:C1710.EmbedderResult:=$embedder.embed("embedder single"; $model)
var $vector : 4D:C1709.Vector:=$embedResult.vector
ASSERT:C1129($vector#Null:C1517; "single embed should return a vector")
ASSERT:C1129($embedResult.totalTokens>0; "single embed should have tokens")

// --- Batch success ---
var $batchResult : cs:C1710.EmbedderResult:=$embedder.embedBatch(["first"; "second"]; $model)
var $vectors : Collection:=$batchResult.vectors
ASSERT:C1129($vectors.length=2; "batch embed should preserve item count")
ASSERT:C1129($vectors[0]#Null:C1517; "batch embed first vector missing")
ASSERT:C1129($vectors[1]#Null:C1517; "batch embed second vector missing")
ASSERT:C1129($batchResult.totalTokens>0; "batch embed should have tokens")

// --- Retryable error succeeds after retry ---
var $retryInput : Text:="__retryable_once__"+String:C10(Milliseconds:C459)
var $retryResult : cs:C1710.EmbedderResult:=$embedder.embed($retryInput; $model)
var $retryVector : 4D:C1709.Vector:=$retryResult.vector
ASSERT:C1129($retryVector#Null:C1517; "retryable error should recover and return a vector")

// --- Fatal error throws structured critical error ---
var $fatalThrown:=False:C215
Try
	$embedder.embed("fatal"; "bad-model")
Catch
	$fatalThrown:=True:C214
	var $fatalErr : Object:=Last errors:C1799[0]
	ASSERT:C1129(Bool:C1537($fatalErr.isCriticalAPIError); JSON Stringify:C1217($fatalErr))
	ASSERT:C1129(String:C10($fatalErr.model)="bad-model"; JSON Stringify:C1217($fatalErr))
	If ($mockBased)
		ASSERT:C1129(Position:C15("Unsupported embedding model"; String:C10($fatalErr.message))>0; JSON Stringify:C1217($fatalErr))
	End if 
End try
ASSERT:C1129($fatalThrown; "fatal embedder path should throw")


Try(1)