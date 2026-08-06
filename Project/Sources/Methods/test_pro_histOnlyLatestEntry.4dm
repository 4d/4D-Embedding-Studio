//%attributes = {}
// Verify embeddingHistory.json contains only the latest entry after multiple
// recalculation runs — the file is always overwritten wholesale (JSON Stringify of a
// single top-level object), never appended to as a growing array of past runs. Only one
// compact "previous" snapshot (for cumulative token bookkeeping) is retained, not a list.

var $model:="embed"

var $modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
var $modelAlias : Object:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()

If ($modelAlias=Null:C1517)
	var $providersFile:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
	var $providersData : Object:=($providersFile.exists) ? JSON Parse:C1218($providersFile.getText()) : {providers: {}; models: {}}
	If ($providersData.providers["openai"]=Null:C1517)
		$providersData.providers["openai"]:={}
	End if 
	$providersData.models[$model]:={model: "text-embedding-3-small"; provider: "openai"}
	$providersFile.setText(JSON Stringify:C1217($providersData; *))
	$modelAliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	$modelAlias:=$modelAliases.filter(Formula:C1597($1.value.name=$2); $model).first()
End if 

If (Not:C34(Asserted:C1132($modelAlias#Null:C1517; "you must configure an 'embed' model alias")))
	return 
End if 

var $execLog:=cs:C1710._ExecutionLog.me
var $histFile : 4D:C1709.File:=$execLog._file()
var $histExisted : Boolean:=$histFile.exists
var $histBackup : Text:=($histExisted) ? $histFile.getText() : ""

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_hist_latest_only_tmp.json")

Try
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
		{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	var $def : cs:C1710.Definition:=$settings.find("_Students"; "student_vector_2")
	ASSERT:C1129($def#Null:C1517; "test definition missing")
	
	ds:C1482.Cities.all().drop()
	ds:C1482.School.all().drop()
	ds:C1482._Students.all().drop()
	
	var $city:=ds:C1482.Cities.new()
	$city.name:="Paris"
	$city.state:="Ile-de-France"
	ASSERT:C1129($city.save().success; "failed to save city")
	
	var $school:=ds:C1482.School.new()
	$school.name:="Sorbonne"
	$school.university:="Paris University"
	$school.city_ID:=$city.ID
	ASSERT:C1129($school.save().success; "failed to save school")
	
	var $student:=ds:C1482._Students.new()
	$student.firstName:="Alice"
	$student.lastName:="Durand"
	$student.school_ID:=$school.ID
	ASSERT:C1129($student.save().success; "failed to save student")
	
	// First full run.
	var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	var $result : cs:C1710.ProcessResult:=$proc.process()
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	
	var $log1 : Object:=$execLog._read()
	var $startTime1 : Text:=String:C10($log1.startTime)
	var $endTime1 : Text:=String:C10($log1.endTime)
	
	// Second full run (force a recompute so there is real work to do again).
	ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
	$proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	$result:=$proc.process()
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	
	var $log2 : Object:=$execLog._read()
	
	// The top-level entry must reflect the SECOND (latest) run only.
	ASSERT:C1129(String:C10($log2.startTime)#$startTime1; "startTime should have advanced to the latest run")
	ASSERT:C1129(String:C10($log2.endTime)#$endTime1; "endTime should have advanced to the latest run")
	ASSERT:C1129($log2.status="completed"; "expected latest status completed, got "+String:C10($log2.status))
	
	// There is no growing history array — the file root is a single object, and the
	// only retained prior state is a single "previous" object (not a list of entries).
	ASSERT:C1129(Value type:C1509($log2)=Is object:K8:27; "history file root should be a single object, not a list of entries")
	ASSERT:C1129(Value type:C1509($log2.previous)=Is object:K8:27; "previous run snapshot should be a single object")
	ASSERT:C1129(Value type:C1509($log2.previous)#Is collection:K8:32; "previous run snapshot must not be a growing collection of entries")
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
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

