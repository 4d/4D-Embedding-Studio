//%attributes = {}
// Execution history file (Logs/embeddingHistory.json) written by cs._ExecutionLog.

If (Not:C34(Asserted:C1132(cs:C1710._TestFixtures.me.ensureAliases(["embed"]); "you must configure an 'embed' model alias")))
	return 
End if 

// Read the real configured secret once (never echoed into any assertion message).
var $realApiKey : Text:=""
var $providersFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
If ($providersFile.exists)
	var $realProviders : Object:=JSON Parse:C1218($providersFile.getText())
	If (($realProviders.providers#Null:C1517) && ($realProviders.providers.openai#Null:C1517))
		$realApiKey:=String:C10($realProviders.providers.openai.apiKey)
	End if 
End if 

var $execLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_process_history_tmp.json")

//MARK:- test_pro_histRunningStatus
// The file reads status "running" (no endTime/error yet) between startFullRun() and
// endFullRun(). Exercised directly at the _ExecutionLog level for determinism.
var $startTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
$execLog.startFullRun($startTs)
var $log : Object:=$execLog._read()
ASSERT:C1129($log.status="running"; "expected status running during an in-progress recalculation, got "+String:C10($log.status))
ASSERT:C1129($log.startTime=$startTs; "startTime should match the recorded start")
ASSERT:C1129($log.endTime=Null:C1517; "endTime should not be set while still running")
ASSERT:C1129($log.error=Null:C1517; "error should not be set while still running")
$execLog.endFullRun($startTs; cs:C1710._ScheduleCalc.me._nowISO(); "completed"; Null:C1517; Null:C1517; Null:C1517)
ASSERT:C1129($execLog._read().status="completed"; "status should transition to completed once the run ends")

//MARK:- test_pro_histCreatedOnSuccess
// A successful full run (process(Null)) creates embeddingHistory.json with status completed.
cs:C1710._TestFixtures.me.seedStudents(1)
$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
	{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: "embed"; phrase: "{firstName} {lastName}"}]}))
var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)

If ($histFile.exists)
	$histFile.delete()
End if 
ASSERT:C1129(Not:C34($histFile.exists); "setup: history file should be absent before the run")

var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
var $result : cs:C1710.ProcessResult:=$proc.process()  // Null => full run
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
ASSERT:C1129($histFile.exists; "embeddingHistory.json should exist after a successful full recalculation")
$log:=$execLog._read()
ASSERT:C1129($log.status="completed"; "expected status completed, got "+String:C10($log.status))
ASSERT:C1129(Length:C16(String:C10($log.startTime))>0; "startTime should be recorded")
ASSERT:C1129(Length:C16(String:C10($log.endTime))>0; "endTime should be recorded")

//MARK:- test_pro_histStatusErrorOnFail / test_pro_histNoSensitiveDataErr
// A failed full run records status "failed" with a populated error field — and that field
// (and the whole file) must never contain the API key.
cs:C1710._TestFixtures.me.seedStudents(1)
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new({criticalModels: ["embed"]})})
$result:=$proc.process()  // Null => full run
ASSERT:C1129(Not:C34($result.success); "expected the full run to fail")
$log:=$execLog._read()
ASSERT:C1129($log.status="failed"; "expected status failed, got "+String:C10($log.status))
ASSERT:C1129(Length:C16(String:C10($log.error))>0; "error field should be populated on failure")
If (Length:C16($realApiKey)>0)
	ASSERT:C1129(Position:C15($realApiKey; String:C10($log.error))=0; "error field must not contain the API key")
	ASSERT:C1129(Position:C15($realApiKey; $histFile.getText())=0; "embeddingHistory.json must not contain the API key anywhere")
End if 

//MARK:- test_pro_histOnlyLatestEntry
// The file is overwritten wholesale (single top-level object): after multiple runs it holds
// only the latest entry, plus a single compact "previous" object (never a growing list).
cs:C1710._TestFixtures.me.seedStudents(1)
var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
ASSERT:C1129($def#Null:C1517; "test definition missing")
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.process()
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
var $log1 : Object:=$execLog._read()
var $startTime1 : Text:=String:C10($log1.startTime)
var $endTime1 : Text:=String:C10($log1.endTime)

ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
$result:=$proc.process()
ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
var $log2 : Object:=$execLog._read()
ASSERT:C1129(String:C10($log2.startTime)#$startTime1; "startTime should have advanced to the latest run")
ASSERT:C1129(String:C10($log2.endTime)#$endTime1; "endTime should have advanced to the latest run")
ASSERT:C1129($log2.status="completed"; "expected latest status completed, got "+String:C10($log2.status))
ASSERT:C1129(Value type:C1509($log2)=Is object:K8:27; "history file root should be a single object, not a list of entries")
ASSERT:C1129(Value type:C1509($log2.previous)=Is object:K8:27; "previous run snapshot should be a single object")
ASSERT:C1129(Value type:C1509($log2.previous)#Is collection:K8:32; "previous run snapshot must not be a growing collection of entries")

//MARK:- test_pro_histIOnInterrupt
// Each write is a single complete JSON.Stringify overwrite: an interrupted run still leaves
// valid JSON, and a corrupted/truncated file degrades gracefully (_read() returns {}).
var $interruptTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
$execLog.startFullRun($interruptTs)
var $parsed : Variant:=JSON Parse:C1218($histFile.getText())  // must not throw
ASSERT:C1129(Value type:C1509($parsed)=Is object:K8:27; "interrupted run: file must still contain a valid JSON object")
ASSERT:C1129($parsed.status="running"; "interrupted run: status should still read running")

var $restartTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
$execLog.startFullRun($restartTs)
ASSERT:C1129($execLog._read().status="running"; "recovery: a fresh startFullRun after an interruption should work normally")
$execLog.endFullRun($restartTs; cs:C1710._ScheduleCalc.me._nowISO(); "completed"; Null:C1517; Null:C1517; Null:C1517)

$histFile.setText("{\"status\":\"running\", \"startTime\":")  // deliberately truncated/invalid JSON
var $recovered : Object:=$execLog._read()
ASSERT:C1129(Value type:C1509($recovered)=Is object:K8:27; "_read() must return an object even when the file is corrupted")
ASSERT:C1129($recovered.status=Null:C1517; "_read() should not surface stale/garbage fields from a corrupted file")

var $recoverTs : Text:=cs:C1710._ScheduleCalc.me._nowISO()
$execLog.startFullRun($recoverTs)
$execLog.endFullRun($recoverTs; cs:C1710._ScheduleCalc.me._nowISO(); "completed"; Null:C1517; Null:C1517; Null:C1517)
ASSERT:C1129($execLog._read().status="completed"; "the file should be fully healthy again after the next successful run")

// Cleanup: restore the history file and remove the temp settings.
If ($histExisted)
	$histFile.setText($histBackup)
Else
	If ($histFile.exists)
		$histFile.delete()
	End if
End if
If ($settingsFile.exists)
	$settingsFile.delete()
End if
