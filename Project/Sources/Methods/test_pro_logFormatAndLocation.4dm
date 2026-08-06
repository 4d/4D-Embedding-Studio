//%attributes = {}
// Verify diagnostic log entries follow standard 4D diagnostic log format and location.
// Unit-level: exercises cs._Logger directly.

var $logger:=cs:C1710._Logger.me

// Location: entries are written to the 4D diagnostic log (not a custom file/output).
ASSERT:C1129($logger.outputType=Into 4D diagnostic log:K38:8; "logger should write into the 4D diagnostic log")

$logger._capture:=[]
$logger.info("plain text info message")
$logger.warn({event: "test warn"; detail: "x"})
$logger.error({event: "test error"; detail: "y"})
$logger.debug({event: "test debug"; detail: "z"})

var $logs : Collection:=$logger._capture
ASSERT:C1129($logs.length=4; "expected 4 captured entries, got "+String:C10($logs.length))

// Format: every entry is prefixed with the logger's standard tag.
var $log : Object
For each ($log; $logs)
	ASSERT:C1129(Position:C15($logger.prefix; $log.message)=1; "every log entry should start with the standard prefix: "+$log.message)
End for each 

// Object payloads must be serialized as valid, parseable JSON after the prefix.
var $objMessage : Text:=$logs[1].message
var $jsonPart : Text:=Substring:C12($objMessage; Length:C16($logger.prefix)+2)
var $parsed : Variant:=Try(JSON Parse:C1218($jsonPart))
ASSERT:C1129(Value type:C1509($parsed)=Is object:K8:27; "object payloads should serialize as valid JSON: "+$objMessage)
ASSERT:C1129($parsed.event="test warn"; "parsed JSON should round-trip the original payload: "+$objMessage)

// Levels: info/warn/error map to their respective 4D log-event levels; debug has no true
// Debug level in 4D's LOG EVENT constants, so it deliberately reuses Information message
// (see the "XXX: no debug level available" note in _Logger.4dm).
ASSERT:C1129($logs[0].level=Information message:K38:1; "info() should log at Information message level")
ASSERT:C1129($logs[1].level=Warning message:K38:2; "warn() should log at Warning message level")
ASSERT:C1129($logs[2].level=Error message:K38:3; "error() should log at Error message level")
ASSERT:C1129($logs[3].level=Information message:K38:1; "debug() currently reuses Information message level (no Debug level exists)")

$logger._capture:=Null:C1517
