//%attributes = {}
// Unit tests for the structured error API: cs.EmbeddingStudio.ProcessErrorCode,
// cs.ProcessError and the error/usage helpers on cs.EmbeddingStudio.ProcessResult.
// Pure (no mock server) — exercises severity/retryable derivation, overrides,
// success/fatal logic and the query helpers directly.

var $codes : cs:C1710.ProcessErrorCode:=cs:C1710.ProcessErrorCode.me

// ══════════════════════════════════════════════════════════════════════
// ProcessErrorCode.meta() — defaults per code
// ══════════════════════════════════════════════════════════════════════

var $meta : Object

$meta:=$codes.meta($codes.NULL_INPUT)
ASSERT:C1129($meta.severity="error"; "NULL_INPUT severity")
ASSERT:C1129(Not:C34($meta.retryable); "NULL_INPUT not retryable")
ASSERT:C1129($meta.label="NULL_INPUT"; "NULL_INPUT label")

$meta:=$codes.meta($codes.INVALID_DEFINITION)
ASSERT:C1129($meta.severity="error"; "INVALID_DEFINITION severity")
ASSERT:C1129(Not:C34($meta.retryable); "INVALID_DEFINITION not retryable")

$meta:=$codes.meta($codes.VALIDATION_FAILED)
ASSERT:C1129($meta.severity="error"; "VALIDATION_FAILED severity")
ASSERT:C1129(Not:C34($meta.retryable); "VALIDATION_FAILED not retryable")

$meta:=$codes.meta($codes.MODEL_UNAVAILABLE)
ASSERT:C1129($meta.severity="fatal"; "MODEL_UNAVAILABLE is fatal")
ASSERT:C1129($meta.retryable; "MODEL_UNAVAILABLE is retryable")

$meta:=$codes.meta($codes.MODEL_SKIPPED)
ASSERT:C1129($meta.severity="error"; "MODEL_SKIPPED severity")
ASSERT:C1129($meta.retryable; "MODEL_SKIPPED is retryable")

$meta:=$codes.meta($codes.EMBED_FAILED)
ASSERT:C1129($meta.severity="error"; "EMBED_FAILED severity")
ASSERT:C1129($meta.retryable; "EMBED_FAILED is retryable")

$meta:=$codes.meta($codes.VECTOR_COUNT_MISMATCH)
ASSERT:C1129($meta.severity="error"; "VECTOR_COUNT_MISMATCH severity")
ASSERT:C1129(Not:C34($meta.retryable); "VECTOR_COUNT_MISMATCH not retryable")

$meta:=$codes.meta($codes.SAVE_FAILED)
ASSERT:C1129($meta.severity="error"; "SAVE_FAILED severity")
ASSERT:C1129($meta.retryable; "SAVE_FAILED is retryable")

// --- Unknown code → safe fallback ---
$meta:=$codes.meta(-999)
ASSERT:C1129($meta.severity="error"; "unknown code falls back to error severity")
ASSERT:C1129(Not:C34($meta.retryable); "unknown code falls back to not retryable")
ASSERT:C1129($meta.label="UNKNOWN"; "unknown code falls back to UNKNOWN label")

// --- Singleton identity ---
ASSERT:C1129($codes=cs:C1710.ProcessErrorCode.me; "ProcessErrorCode.me is a singleton")

// ══════════════════════════════════════════════════════════════════════
// ProcessError — constructor derives severity/retryable from the code
// ══════════════════════════════════════════════════════════════════════

var $err : cs:C1710.ProcessError

// --- Defaults derived from a fatal code ---
$err:=cs:C1710.ProcessError.new("definition"; $codes.MODEL_UNAVAILABLE; "Students.vector"; "model down")
ASSERT:C1129($err.scope="definition"; "scope stored verbatim")
ASSERT:C1129($err.code=$codes.MODEL_UNAVAILABLE; "code stored verbatim")
ASSERT:C1129($err.ref="Students.vector"; "ref stored verbatim")
ASSERT:C1129($err.message="model down"; "message stored verbatim")
ASSERT:C1129($err.severity="fatal"; "severity derived from code meta")
ASSERT:C1129($err.retryable; "retryable derived from code meta")
ASSERT:C1129($err.isFatal; "isFatal true for fatal severity")

// --- Defaults derived from a non-fatal code ---
$err:=cs:C1710.ProcessError.new("entity"; $codes.SAVE_FAILED; 42; "save failed")
ASSERT:C1129($err.severity="error"; "non-fatal code → error severity")
ASSERT:C1129($err.retryable; "SAVE_FAILED retryable by default")
ASSERT:C1129(Not:C34($err.isFatal); "isFatal false for error severity")

// --- $overrides override the code defaults ---
$err:=cs:C1710.ProcessError.new("chunk"; $codes.EMBED_FAILED; "c1"; "embed failed"; {severity: "warning"; retryable: False:C215})
ASSERT:C1129($err.severity="warning"; "override severity applied")
ASSERT:C1129(Not:C34($err.retryable); "override retryable applied")
ASSERT:C1129(Not:C34($err.isFatal); "warning is not fatal")

// --- Partial override only touches the supplied key ---
$err:=cs:C1710.ProcessError.new("entity"; $codes.EMBED_FAILED; "e1"; "embed failed"; {retryable: False:C215})
ASSERT:C1129($err.severity="error"; "partial override leaves severity at code default")
ASSERT:C1129(Not:C34($err.retryable); "partial override sets retryable")

// --- toObject() shape ---
$err:=cs:C1710.ProcessError.new("pipeline"; $codes.NULL_INPUT; Null:C1517; "nothing to do")
var $obj : Object:=$err.toObject()
ASSERT:C1129($obj.scope="pipeline"; "toObject scope")
ASSERT:C1129($obj.severity="error"; "toObject severity")
ASSERT:C1129($obj.code=$codes.NULL_INPUT; "toObject code")
ASSERT:C1129($obj.message="nothing to do"; "toObject message")
ASSERT:C1129(Not:C34($obj.retryable); "toObject retryable")

// ══════════════════════════════════════════════════════════════════════
// ProcessResult — fresh state
// ══════════════════════════════════════════════════════════════════════

var $result : cs:C1710.ProcessResult:=cs:C1710.ProcessResult.new()
ASSERT:C1129($result.errors.length=0; "fresh result has no errors")
ASSERT:C1129($result.success; "fresh result is success")
ASSERT:C1129(Not:C34($result.hasFatal); "fresh result has no fatal")

// ══════════════════════════════════════════════════════════════════════
// ProcessResult._addError — chaining, success and fatal logic
// ══════════════════════════════════════════════════════════════════════

// --- Warning-only run still counts as success ---
$result:=cs:C1710.ProcessResult.new()
ASSERT:C1129($result._addError("chunk"; $codes.EMBED_FAILED; "c1"; "soft"; {severity: "warning"})=$result; "_addError is chainable")
ASSERT:C1129($result.errors.length=1; "warning recorded")
ASSERT:C1129($result.success; "warning does not fail the run")
ASSERT:C1129(Not:C34($result.hasFatal); "warning is not fatal")

// --- An error severity fails the run but is not fatal ---
$result:=cs:C1710.ProcessResult.new()
$result._addError("entity"; $codes.SAVE_FAILED; 7; "save failed")
ASSERT:C1129(Not:C34($result.success); "error severity fails the run")
ASSERT:C1129(Not:C34($result.hasFatal); "error severity is not fatal")

// --- A fatal error fails the run and flags hasFatal ---
$result:=cs:C1710.ProcessResult.new()
$result._addError("definition"; $codes.MODEL_UNAVAILABLE; "Students.vector"; "down")
ASSERT:C1129(Not:C34($result.success); "fatal fails the run")
ASSERT:C1129($result.hasFatal; "fatal flags hasFatal")

// ══════════════════════════════════════════════════════════════════════
// ProcessResult — query helpers
// ══════════════════════════════════════════════════════════════════════

$result:=cs:C1710.ProcessResult.new()
$result._addError("definition"; $codes.MODEL_UNAVAILABLE; "Students.vector"; "down")  // fatal, retryable
$result._addError("definition"; $codes.MODEL_SKIPPED; "School.vector"; "skipped")  // error, retryable
$result._addError("entity"; $codes.VALIDATION_FAILED; 1; "bad")  // error, not retryable
$result._addError("chunk"; $codes.EMBED_FAILED; "c1"; "soft"; {severity: "warning"})  // warning, retryable

// --- errorsByScope ---
ASSERT:C1129($result.errorsByScope("definition").length=2; "errorsByScope definition")
ASSERT:C1129($result.errorsByScope("entity").length=1; "errorsByScope entity")
ASSERT:C1129($result.errorsByScope("chunk").length=1; "errorsByScope chunk")
ASSERT:C1129($result.errorsByScope("pipeline").length=0; "errorsByScope pipeline (none)")

// --- errorsByCode ---
ASSERT:C1129($result.errorsByCode($codes.MODEL_UNAVAILABLE).length=1; "errorsByCode MODEL_UNAVAILABLE")
ASSERT:C1129($result.errorsByCode($codes.VALIDATION_FAILED)[0].scope="entity"; "errorsByCode returns matching error")
ASSERT:C1129($result.errorsByCode($codes.SAVE_FAILED).length=0; "errorsByCode no match")

// --- retryableErrors (3 of 4 retryable: VALIDATION_FAILED is not) ---
ASSERT:C1129($result.retryableErrors().length=3; "retryableErrors counts only retryable")

// ══════════════════════════════════════════════════════════════════════
// ProcessResult._addUsage — null-safe accumulation
// ══════════════════════════════════════════════════════════════════════

$result:=cs:C1710.ProcessResult.new()

// --- Null is a no-op and stays chainable ---
ASSERT:C1129($result._addUsage(Null:C1517)=$result; "_addUsage(Null) is chainable")
ASSERT:C1129($result.promptTokens=0; "_addUsage(Null) leaves promptTokens at 0")
ASSERT:C1129($result.totalTokens=0; "_addUsage(Null) leaves totalTokens at 0")

// --- Accumulates across calls ---
$result._addUsage(cs:C1710.EmbedderResult.new({usage: {prompt_tokens: 5; total_tokens: 12}}; False:C215))
$result._addUsage(cs:C1710.EmbedderResult.new({usage: {prompt_tokens: 3; total_tokens: 8}}; False:C215))
ASSERT:C1129($result.promptTokens=8; "_addUsage accumulates promptTokens")
ASSERT:C1129($result.totalTokens=20; "_addUsage accumulates totalTokens")

// ══════════════════════════════════════════════════════════════════════
// ProcessResult._done / toObject
// ══════════════════════════════════════════════════════════════════════

$result:=cs:C1710.ProcessResult.new()
$result.definitionsProcessed:=2
$result.entitiesUpdated:=3
$result._addError("entity"; $codes.SAVE_FAILED; 1; "save failed")
ASSERT:C1129($result._done()=$result; "_done is chainable")
ASSERT:C1129($result.duration>=0; "_done captures a non-negative duration")

$obj:=$result.toObject()
ASSERT:C1129($obj.definitionsProcessed=2; "toObject definitionsProcessed")
ASSERT:C1129($obj.entitiesUpdated=3; "toObject entitiesUpdated")
ASSERT:C1129(Not:C34($obj.success); "toObject success reflects recorded error")
ASSERT:C1129(Not:C34($obj.hasFatal); "toObject hasFatal false")
ASSERT:C1129($obj.errors.length=1; "toObject extracts errors collection")
ASSERT:C1129($obj.errors[0].code=$codes.SAVE_FAILED; "toObject error carries code")
ASSERT:C1129($obj.errors[0].scope="entity"; "toObject error carries scope")

Try(1)
