//%attributes = {}
// Verify 'Vector still dirty after save during recomputation' event is logged at Info
// level on concurrent modification. Reuses the same optimistic-lock conflict mechanism
// as test_process_optimisticLockDirty.4dm (some runtimes do not reproduce optimistic-lock
// conflicts deterministically), but probes support by mirroring Process._processChunk()'s
// exact double "For each (entity; $chunk)" iteration pattern over the same EntitySelection,
// rather than a generic two-separate-entities probe (which can give a false positive: some
// ORDA runtimes re-fetch a fresh entity on every "For each" pass over the same selection,
// so the persist pass never actually sees the stale snapshot the generic probe implies).

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

var $settingsFile : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_log_dirty_after_conflict_tmp.json")

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
	
	var $proc:=cs:C1710.Process.new($settings; {embedder: cs:C1710._TestProcessEmbedder.new()})
	var $result : cs:C1710.ProcessResult:=$proc.process($def)
	ASSERT:C1129($result.success; JSON Stringify:C1217($result.toObject()))
	ASSERT:C1129($result.entitiesUpdated=1; JSON Stringify:C1217($result.toObject()))
	
	// Probe: mirrors EXACTLY the double "For each (entity; $chunk)" pattern used by
	// Process._processChunk() (render pass, then a concurrent save from elsewhere, then
	// the persist pass) — not a generic two-separate-entities probe. Some ORDA runtimes
	// re-fetch a fresh (already up to date) entity on each "For each" iteration over the
	// same EntitySelection, in which case the persist pass never sees a stale snapshot and
	// no optimistic-lock conflict occurs; a generic probe would falsely predict a conflict
	// that this specific code path can never actually reproduce.
	var $optimisticSupported : Boolean:=False:C215
	var $probeSel : 4D:C1709.EntitySelection:=ds:C1482._Students.query("ID = :1"; $student.ID)
	var $probeEntity : 4D:C1709.Entity
	
	For each ($probeEntity; $probeSel)  // mirrors the phrase-render pass
	End for each 
	
	var $touchEntity : 4D:C1709.Entity:=ds:C1482._Students.get($student.ID)  // mirrors _touchConcurrentEntity()
	$touchEntity.lastName:=String:C10($touchEntity.lastName)+"_probetouch"
	ASSERT:C1129($touchEntity.save().success; "probe concurrent touch save failed unexpectedly")
	
	For each ($probeEntity; $probeSel)  // mirrors the persist pass
		$probeEntity.lastName:=String:C10($probeEntity.lastName)+"_probesave"
		$optimisticSupported:=Not:C34($probeEntity.save().success)
	End for each 
	
	$student:=ds:C1482._Students.get($student.ID)
	$student.lastName:="Durand"
	ASSERT:C1129($student.save().success; "failed to restore student lastName after probe")
	
	ASSERT:C1129($def.invalidateVectors().errors.length=0; "failed to invalidate vectors")
	
	If ($optimisticSupported)
		
		cs:C1710._Logger.me._capture:=[]
		
		var $conflictEmbedder:=cs:C1710._TestProcessEmbedderOptimisticLock.new({\
			dataclassName: "_Students"; \
			entityKey: $student.ID; \
			touchField: "lastName"; \
			touchSuffix: "_concurrent"})
		
		$proc:=cs:C1710.Process.new($settings; {embedder: $conflictEmbedder})
		$result:=$proc.process($def)
		
		ASSERT:C1129(Not:C34($result.success); "optimistic lock scenario should report failure")
		
		var $logs : Collection:=cs:C1710._Logger.me._capture
		var $dirtyLogs : Collection:=$logs.query("level = :1 AND message = :2"; Information message:K38:1; "@\"event\":\"Vector still dirty after save during recomputation\"@")
		ASSERT:C1129($dirtyLogs.length=1; "expected exactly one Info-level 'Vector still dirty after save' log, got "+String:C10($dirtyLogs.length))
		
		var $message : Text:=$dirtyLogs[0].message
		ASSERT:C1129(Position:C15("\"vector\":\"_Students.student_vector_2\""; $message)>0; "log should include the vector reference: "+$message)
		ASSERT:C1129(Position:C15("\"entityID\":"; $message)>0; "log should include the entity id: "+$message)
		ASSERT:C1129(Position:C15("\"timestamp\":\""; $message)>0; "log should include a timestamp: "+$message)
		
	End if 
	
Catch
	throw:C1805(Last errors:C1799[0])
End try
cs:C1710._Logger.me._capture:=Null:C1517
If ($settingsFile.exists)
	$settingsFile.delete()
End if 