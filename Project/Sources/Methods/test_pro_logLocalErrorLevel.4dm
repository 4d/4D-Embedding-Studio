//%attributes = {}
// Verify 'Local 4D error' (SAVE_FAILED) event is logged at Error level with entity details.
// Unit-level: exercises cs.ProcessResult._addError() directly — the single source of
// truth for mirroring recorded errors to the diagnostic log (see its own comment).
// This avoids relying on a real, hard-to-reproduce entity.save() conflict just to
// verify the logging contract for this error code/severity.

cs:C1710._Logger.me._capture:=[]

var $codes:=cs:C1710.ProcessErrorCode.me
var $report:=cs:C1710.ProcessResult.new()
$report._addError("entity"; $codes.SAVE_FAILED; "_Students.42"; "Record has been modified by another process")

var $logs : Collection:=cs:C1710._Logger.me._capture
var $errorLogs : Collection:=$logs.query("level = :1 AND message = :2"; Error message:K38:3; "@\"event\":\"Process error\"@")
ASSERT:C1129($errorLogs.length=1; "expected exactly one Error-level 'Process error' log for SAVE_FAILED, got "+String:C10($errorLogs.length))

var $message : Text:=$errorLogs[0].message
ASSERT:C1129(Position:C15("\"scope\":\"entity\""; $message)>0; "log should include the entity scope: "+$message)
ASSERT:C1129(Position:C15("\"code\":"+String:C10($codes.SAVE_FAILED); $message)>0; "log should include the SAVE_FAILED code: "+$message)
ASSERT:C1129(Position:C15("\"ref\":\"_Students.42\""; $message)>0; "log should include the entity reference: "+$message)
ASSERT:C1129(Position:C15("\"severity\":\"error\""; $message)>0; "log should include the error severity: "+$message)
ASSERT:C1129(Position:C15("Record has been modified by another process"; $message)>0; "log should include the failure message: "+$message)

cs:C1710._Logger.me._capture:=Null:C1517
