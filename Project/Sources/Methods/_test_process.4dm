//%attributes = {}
// Interactive configuration check for EmbeddingProcess.
// Loads real settings, pre-checks each definition, then runs a dry-run.
// Prompts the user to fix missing model/phrase before proceeding.
var $dryRun:=Not:C34(Shift down:C543)
var $settings : cs:C1710.EmbeddingSettings:=cs:C1710.EmbeddingSettings.new()

//_invalidateVectors

// ══════════════════════════════════════════════════════════════════════
// CHECK: settings file exists and has definitions
// ══════════════════════════════════════════════════════════════════════

If (Not:C34($settings.file.exists))
	
	ALERT:C41("⚠️ Settings file not found:\n"+$settings.file.path\
		+"\n\nCreate it and add at least one vector definition, then re-run.")
	return 
	
End if 

If ($settings.vectors.length=0)
	
	ALERT:C41("⚠️ No vector definitions in settings.\n\nAdd definitions to:\n"+$settings.file.path)
	return 
	
End if 

// ══════════════════════════════════════════════════════════════════════
// PRE-FLIGHT: obvious omissions the user must fill in
// ══════════════════════════════════════════════════════════════════════

var $missing : Collection:=[]
var $def : cs:C1710.EmbeddingDefinition

For each ($def; $settings.vectors)
	
	var $ref : Text:=String:C10($def.dataclassName)+"."+String:C10($def.vectorName)
	
	If (Length:C16(String:C10($def.model))=0)
		$missing.push($ref+": no model — set one (e.g. text-embedding-3-small)")
	End if 
	
	If (Length:C16($def.phrase.template)=0)
		$missing.push($ref+": phrase is empty — add a template (e.g. \"{firstName} {lastName}\")")
	End if 
	
End for each 

If ($missing.length>0)
	
	var $hint : Text:="⚠️ "+String:C10($missing.length)+" missing configuration item(s):\n\n"
	var $item : Text
	For each ($item; $missing)
		$hint:=$hint+"  • "+$item+"\n"
	End for each 
	$hint:=$hint+"\nEdit: "+$settings.file.path+"\n\nContinue "+($dryRun ? "with dry-run" : "")+" anyway?"
	
	CONFIRM:C162($hint)
	If (OK=0)
		return 
	End if 
	
End if 

// ══════════════════════════════════════════════════════════════════════
// SEED: if a validated dataclass is empty, create random test entities
// ══════════════════════════════════════════════════════════════════════

var $seedLog : Text:=""
var $seedDef : cs:C1710.EmbeddingDefinition

For each ($seedDef; $settings.vectors)
	
	If (Length:C16(String:C10($seedDef.dataclassName))=0)
		continue
	End if 
	
	var $seedDC : 4D:C1709.DataClass:=ds:C1482[$seedDef.dataclassName]
	
	If ($seedDC=Null:C1517)
		continue
	End if 
	
	If ($seedDC.all().length>0)
		continue
	End if 
	
	CONFIRM:C162("ℹ️ \""+$seedDef.dataclassName+"\" has no entities.\nCreate 3 test entities with random data?")
	If (OK=0)
		continue
	End if 
	
	// Collect fillable storage attributes (skip vectors and auto-filled fields)
	var $seedAttrs : Collection:=[]
	var $seedAttrKey : Text
	For each ($seedAttrKey; $seedDC)
		var $seedAttr : Object:=$seedDC[$seedAttrKey]
		If (String:C10($seedAttr.kind)="storage") && (String:C10($seedAttr.classID)#"4D.Vector") && (Not:C34(Bool:C1537($seedAttr.autoFilled)))
			$seedAttrs.push($seedAttr)
		End if 
	End for each 
	
	var $seedN : Integer:=0
	While ($seedN<3)
		
		var $seedEntity : 4D:C1709.Entity:=$seedDC.new()
		
		var $seedA : Object
		For each ($seedA; $seedAttrs)
			Case of 
				: (String:C10($seedA.type)="string")
					$seedEntity[$seedA.name]:="Test_"+String:C10(Abs:C99(Random:C100))
				: (String:C10($seedA.type)="number")
					$seedEntity[$seedA.name]:=Abs:C99(Random:C100)/10
				: (String:C10($seedA.type)="long") | (String:C10($seedA.type)="word") | (String:C10($seedA.type)="byte")
					$seedEntity[$seedA.name]:=Abs:C99(Random:C100)
				: (String:C10($seedA.type)="bool")
					$seedEntity[$seedA.name]:=(Random:C100>0)
				: (String:C10($seedA.type)="date")
					$seedEntity[$seedA.name]:=Current date:C33
				: (String:C10($seedA.type)="time")
					$seedEntity[$seedA.name]:=Current time:C178
				: (String:C10($seedA.type)="object")
					$seedEntity[$seedA.name]:=New object:C1471("_test"; True:C214)
			End case 
		End for each 
		
		$seedEntity.save()
		$seedN+=1
		
	End while 
	
	$seedLog:=$seedLog+"  • "+$seedDef.dataclassName+": 3 entities created\n"
	
End for each 

If (Length:C16($seedLog)>0)
	ALERT:C41("ℹ️ Test data seeded:\n\n"+$seedLog)
End if 

// ══════════════════════════════════════════════════════════════════════
// (DRY-)RUN: validates each definition, counts entities
// ══════════════════════════════════════════════════════════════════════

var $proc : cs:C1710.EmbeddingProcess:=cs:C1710.EmbeddingProcess.new($settings; {dryRun: $dryRun})
var $result : cs:C1710.EmbeddingProcessResult

Try
	$result:=$proc.process()
Catch
	ALERT:C41("❌ Process raised an error:\n"+Last errors:C1799[0].message)
	return 
End try

var $summary : Text:=\
"Settings:   "+$settings.file.path+\
"\nDefinitions: "+String:C10($settings.vectors.length)+\
"\nProcessed:   "+String:C10($result.definitionsProcessed)+\
"\nConsidered:  "+String:C10($result.entitiesConsidered)+" entities"+\
"\nAPI calls:   "+String:C10($result.apiCalls)+($dryRun ? "(dry run)" : "")

If ($result.errors.length>0)
	
	var $errText : Text:=""
	var $err : Object
	For each ($err; $result.errors)
		$errText:=$errText+"  • "+String:C10($err.scope)+" / "+String:C10($err.ref)+": "+String:C10($err.message)+"\n"
	End for each 
	
	ALERT:C41("⚠️ "+String:C10($result.errors.length)+" error(s) — fix these before running for real:\n\n"+$errText+"\n"+$summary)
	
Else 
	
	ALERT:C41("✅ Configuration OK — all "+String:C10($settings.vectors.length)+" definition(s) passed.\n\n"+$summary)
	
End if 
