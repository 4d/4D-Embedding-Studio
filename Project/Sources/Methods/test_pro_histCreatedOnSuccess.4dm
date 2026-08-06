//%attributes = {}
// Verify embeddingHistory.json is created after a successful recalculation.
// process($definition=Null) is a "full run" — only that path calls
// cs._ExecutionLog.startFullRun()/endFullRun(), which write Logs/embeddingHistory.json.

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

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_hist_created_tmp.json")

Try
	$settingsFile.setText(JSON Stringify:C1217({batchSize: 1; definitions: [\
		{dataclassName: "_Students"; vectorName: "student_vector_2"; modelAlias: $model; phrase: "{firstName} {lastName}"}]}))
	
	var $settings : cs:C1710.Settings:=cs:C1710.Settings.new($settingsFile)
	
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
	
	// Remove the history file so we can prove the full run creates it.
	If ($histFile.exists)
		$histFile.delete()
	End if 
	ASSERT:C1129(Not:C34($histFile.exists); "setup: history file should be absent before the run")
	
	var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	var $result : cs:C1710.ProcessResult:=$proc.process()  // Null definition => full run
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	
	ASSERT:C1129($histFile.exists; "embeddingHistory.json should exist after a successful full recalculation")
	
	var $log : Object:=$execLog._read()
	ASSERT:C1129($log.status="completed"; "expected status completed, got "+String:C10($log.status))
	ASSERT:C1129(Length:C16(String:C10($log.startTime))>0; "startTime should be recorded")
	ASSERT:C1129(Length:C16(String:C10($log.endTime))>0; "endTime should be recorded")
	
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

