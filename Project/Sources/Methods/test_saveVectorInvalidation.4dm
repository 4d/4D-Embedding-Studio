//%attributes = {}
// Tests the NATIVE 4D auto-invalidation of embedding vectors at entity.save().
//
// When an entity is saved and a *modified* field appears in the phrase of a definition, 4D either
//   • sets the companion "<vectorName>_dirty" boolean to True (when that field exists),
//     leaving the vector value intact, or
//   • nullifies the "<vectorName>" field (when there is no _dirty companion).
// A field that is NOT part of any phrase must never invalidate the vector, and a
// definition with autoInvalidate=false must never invalidate at all (see CASE 6).
//
// Reference definitions in Settings/embeddings.json exercised here:
//   _Students.student_vector_1  phrase "ID={ID},firstName={firstName},lastName={lastName}\r"  (no _dirty companion)
//   _Students.student_vector_2  phrase "ID={ID},firstName={firstName},lastName={lastName}"    (has student_vector_2_dirty)
//   AllTypes.Vector             phrase "...,Alpha={Alpha},...,Real={Real}"                     (no _dirty companion)

// ══════════════════════════════════════════════════════════════════════
// Runtime gate: only a real 4D (not tool4d) implements the feature.
// ══════════════════════════════════════════════════════════════════════
If (Application type:C494=tool4d:K5:70)
	LOG EVENT:C667(Into system standard outputs:K38:9; "SKIP test_saveVectorInvalidation: native vector auto-invalidation is not available in tool4d "+Char:C90(Line feed:K15:40))
	return 
End if 

// ══════════════════════════════════════════════════════════════════════
// Fixture — the test must not depend on the local Settings/embeddings.json
// (not versioned, edited by hand or by the wizard). Install the reference
// definitions below, keep the others, and always restore the original file.
// ══════════════════════════════════════════════════════════════════════
// the default file (the one 4D reads at save), not cs._Settings.me.file which tests may redirect
var $embFile : 4D:C1709.File:=cs:C1710._Settings.me._defaultFile()
var $embExisted : Boolean:=$embFile.exists
var $embOrig : Text:=$embExisted ? $embFile.getText() : ""

var $embRoot : Object:=($embOrig#"") ? Try(JSON Parse:C1218($embOrig)) : Null:C1517
If (Value type:C1509($embRoot)#Is object:K8:27)
	$embRoot:={}
End if 
If (Value type:C1509($embRoot.definitions)#Is collection:K8:32)
	$embRoot.definitions:=[]
End if 

var $fixtureDefs : Collection:=[\
{dataclassName: "_Students"; vectorName: "student_vector_1"; phrase: "ID={ID},firstName={firstName},lastName={lastName}\r"}; \
{dataclassName: "_Students"; vectorName: "student_vector_2"; phrase: "ID={ID},firstName={firstName},lastName={lastName}"}; \
{dataclassName: "AllTypes"; vectorName: "Vector"; phrase: "Alpha={Alpha},Real={Real}"}]

var $fixtureDef; $embDef : Object
For each ($fixtureDef; $fixtureDefs)
	$embDef:=$embRoot.definitions.find(Formula:C1597(($1.value.dataclassName=$2.dataclassName) && ($1.value.vectorName=$2.vectorName)); $fixtureDef)
	If ($embDef=Null:C1517)
		$embDef:={dataclassName: $fixtureDef.dataclassName; vectorName: $fixtureDef.vectorName; modelAlias: "embed"}
		$embRoot.definitions.push($embDef)
	End if 
	$embDef.phrase:=$fixtureDef.phrase
	$embDef.autoInvalidate:=True:C214
End for each 

var $embFixture : Text:=JSON Stringify:C1217($embRoot; *)
$embFile.setText($embFixture)

var $failure : Object
Try
	
	// ══════════════════════════════════════════════════════════════════════
	// Schema guards — fail loudly if the fixture schema drifted.
	// ══════════════════════════════════════════════════════════════════════
	ASSERT:C1129(ds:C1482._Students["student_vector_2_dirty"]#Null:C1517; "schema: _Students.student_vector_2_dirty (the _dirty companion) must exist")
	ASSERT:C1129(ds:C1482._Students["student_vector_1_dirty"]=Null:C1517; "schema: _Students.student_vector_1 must NOT have a _dirty companion")
	
	var $vec : 4D:C1709.Vector:=4D:C1709.Vector.new([0.11; 0.22; 0.33; 0.44])
	
	// Best-effort cleanup of any rows left over from a previous failed run.
	ds:C1482._Students.query("firstName = :1"; "AV_@").drop()
	ds:C1482.AllTypes.query("Alpha = :1"; "AV_@").drop()
	ds:C1482.School.query("name = :1"; "AV_@").drop()
	
	// ══════════════════════════════════════════════════════════════════════
	// CASE 1 — no _dirty companion → a modified phrase field NULLIFIES the vector
	//          (_Students.student_vector_1)
	// ══════════════════════════════════════════════════════════════════════
	var $s1 : cs:C1710.Entity:=ds:C1482._Students.new()
	$s1.firstName:="AV_Alice"
	$s1.lastName:="AV_Durand"
	ASSERT:C1129($s1.save().success; "case1: insert save failed")
	
	// Persist a vector in its own save (mirrors the real embedding flow: only the
	// vector field changes, so nothing must be invalidated here).
	$s1:=ds:C1482._Students.get($s1.ID)
	$s1.student_vector_1:=$vec
	ASSERT:C1129($s1.save().success; "case1: vector save failed")
	
	$s1:=ds:C1482._Students.get($s1.ID)
	ASSERT:C1129($s1.student_vector_1#Null:C1517; "case1: baseline vector must persist after a vector-only save")
	
	// Now modify a field that IS in the phrase → vector must be nullified.
	$s1.firstName:="AV_Alice_MODIFIED"
	ASSERT:C1129($s1.save().success; "case1: phrase-field modify save failed")
	
	$s1:=ds:C1482._Students.get($s1.ID)
	ASSERT:C1129($s1.student_vector_1=Null:C1517; "case1: vector must be nullified after modifying a phrase field (no _dirty companion)")
	
	// ══════════════════════════════════════════════════════════════════════
	// CASE 2 — _dirty companion present → a modified phrase field SETS <name>_dirty
	//          and PRESERVES the vector (_Students.student_vector_2)
	// ══════════════════════════════════════════════════════════════════════
	var $s2 : cs:C1710.Entity:=ds:C1482._Students.new()
	$s2.firstName:="AV_Bob"
	$s2.lastName:="AV_Martin"
	ASSERT:C1129($s2.save().success; "case2: insert save failed")
	
	$s2:=ds:C1482._Students.get($s2.ID)
	$s2.student_vector_2:=$vec
	$s2.student_vector_2_dirty:=False:C215
	ASSERT:C1129($s2.save().success; "case2: vector save failed")
	
	$s2:=ds:C1482._Students.get($s2.ID)
	ASSERT:C1129($s2.student_vector_2#Null:C1517; "case2: baseline vector must persist")
	ASSERT:C1129(Not:C34($s2.student_vector_2_dirty); "case2: baseline _dirty must be false")
	
	// Modify a phrase field → _dirty must flip to true, vector must be kept.
	$s2.lastName:="AV_Martin_MODIFIED"
	ASSERT:C1129($s2.save().success; "case2: phrase-field modify save failed")
	
	$s2:=ds:C1482._Students.get($s2.ID)
	ASSERT:C1129($s2.student_vector_2_dirty=True:C214; "case2: _dirty must be set to true after modifying a phrase field")
	ASSERT:C1129($s2.student_vector_2#Null:C1517; "case2: vector must be PRESERVED when a _dirty companion exists")
	
	// ══════════════════════════════════════════════════════════════════════
	// CASE 3 — modifying a field that is NOT in any phrase must NOT invalidate.
	//          (_Students.school_ID is a plain FK, absent from every phrase)
	// ══════════════════════════════════════════════════════════════════════
	var $sch1 : cs:C1710.Entity:=ds:C1482.School.new()
	$sch1.name:="AV_School1"
	$sch1.university:="AV_U1"
	ASSERT:C1129($sch1.save().success; "case3: school1 save failed")
	
	var $sch2 : cs:C1710.Entity:=ds:C1482.School.new()
	$sch2.name:="AV_School2"
	$sch2.university:="AV_U2"
	ASSERT:C1129($sch2.save().success; "case3: school2 save failed")
	
	var $s3 : cs:C1710.Entity:=ds:C1482._Students.new()
	$s3.firstName:="AV_Chloe"
	$s3.lastName:="AV_Bernard"
	$s3.school_ID:=$sch1.ID
	ASSERT:C1129($s3.save().success; "case3: insert save failed")
	
	$s3:=ds:C1482._Students.get($s3.ID)
	$s3.student_vector_1:=$vec
	$s3.student_vector_2:=$vec
	$s3.student_vector_2_dirty:=False:C215
	ASSERT:C1129($s3.save().success; "case3: vector save failed")
	
	// Modify only the non-phrase FK field.
	$s3:=ds:C1482._Students.get($s3.ID)
	$s3.school_ID:=$sch2.ID
	ASSERT:C1129($s3.save().success; "case3: non-phrase modify save failed")
	
	$s3:=ds:C1482._Students.get($s3.ID)
	ASSERT:C1129($s3.student_vector_1#Null:C1517; "case3: student_vector_1 must remain when modifying a non-phrase field")
	ASSERT:C1129($s3.student_vector_2#Null:C1517; "case3: student_vector_2 must remain when modifying a non-phrase field")
	ASSERT:C1129(Not:C34($s3.student_vector_2_dirty); "case3: _dirty must stay false when modifying a non-phrase field")
	
	// ══════════════════════════════════════════════════════════════════════
	// CASE 4 — second table, both directions in one place (AllTypes.Vector, no _dirty):
	//          a non-phrase field (Object) leaves the vector; a phrase field (Alpha)
	//          nullifies it.
	// ══════════════════════════════════════════════════════════════════════
	var $a1 : cs:C1710.Entity:=ds:C1482.AllTypes.new()
	$a1.Alpha:="AV_alpha"
	$a1.Text:="AV_text"
	ASSERT:C1129($a1.save().success; "case4: insert save failed")
	
	$a1:=ds:C1482.AllTypes.get($a1.ID)
	$a1.Vector:=$vec
	ASSERT:C1129($a1.save().success; "case4: vector save failed")
	
	// Modify a field that is NOT in the phrase (Object) → vector kept.
	$a1:=ds:C1482.AllTypes.get($a1.ID)
	$a1.Object:={note: "not in phrase"}
	ASSERT:C1129($a1.save().success; "case4: non-phrase modify save failed")
	
	$a1:=ds:C1482.AllTypes.get($a1.ID)
	ASSERT:C1129($a1.Vector#Null:C1517; "case4: modifying a non-phrase field (Object) must not invalidate the vector")
	
	// Modify a phrase field (Alpha) → vector nullified.
	$a1.Alpha:="AV_alpha_MODIFIED"
	ASSERT:C1129($a1.save().success; "case4: phrase-field modify save failed")
	
	$a1:=ds:C1482.AllTypes.get($a1.ID)
	ASSERT:C1129($a1.Vector=Null:C1517; "case4: modifying a phrase field (Alpha) must nullify the vector")
	
	// ══════════════════════════════════════════════════════════════════════
	// CASE 5 — batch modification over an entity selection.
	//          Every entity whose phrase field changed must be invalidated.
	// ══════════════════════════════════════════════════════════════════════
	var $batchIDs : Collection:=[]
	var $i : Integer
	For ($i; 1; 5)
		var $b : cs:C1710.Entity:=ds:C1482._Students.new()
		$b.firstName:="AV_batch_"+String:C10($i)
		$b.lastName:="AV_last_"+String:C10($i)
		ASSERT:C1129($b.save().success; "case5: insert save failed for "+String:C10($i))
		$b:=ds:C1482._Students.get($b.ID)
		$b.student_vector_1:=$vec
		$b.student_vector_2:=$vec
		$b.student_vector_2_dirty:=False:C215
		ASSERT:C1129($b.save().success; "case5: vector save failed for "+String:C10($i))
		$batchIDs.push($b.ID)
	End for 
	
	// Batch-modify a phrase field on the whole selection, saving each entity.
	var $sel : 4D:C1709.EntitySelection:=ds:C1482._Students.query("ID in :1"; $batchIDs)
	ASSERT:C1129($sel.length=5; "case5: selection should hold 5 entities, got "+String:C10($sel.length))
	
	var $e : cs:C1710.Entity
	For each ($e; $sel)
		$e.lastName:=$e.lastName+"_MOD"  // a phrase field
		ASSERT:C1129($e.save().success; "case5: batch save failed")
	End for each 
	
	// After the batch, every one must be invalidated.
	var $stillSet : Integer:=ds:C1482._Students.query("ID in :1 and student_vector_1 != null"; $batchIDs).length
	ASSERT:C1129($stillSet=0; "case5: all student_vector_1 must be nullified, "+String:C10($stillSet)+" remained set")
	
	var $notDirty : Integer:=ds:C1482._Students.query("ID in :1 and student_vector_2_dirty = false"; $batchIDs).length
	ASSERT:C1129($notDirty=0; "case5: all student_vector_2_dirty must be true, "+String:C10($notDirty)+" remained false")
	
	var $vec2Lost : Integer:=ds:C1482._Students.query("ID in :1 and student_vector_2 = null"; $batchIDs).length
	ASSERT:C1129($vec2Lost=0; "case5: student_vector_2 must be preserved (has _dirty), "+String:C10($vec2Lost)+" were nullified")
	
	// ══════════════════════════════════════════════════════════════════════
	// CASE 6 — autoInvalidate flag: when a definition has autoInvalidate=false,
	//          save() must do NOTHING (vector kept, _dirty untouched), even if a
	//          phrase field changed. The flag is read live per save, so we flip it
	//          in Settings/embeddings.json, run, then RESTORE the file *before*
	//          asserting so a failure can never leave the settings file mutated.
	//
	// ══════════════════════════════════════════════════════════════════════
	// Flip both _Students definitions to autoInvalidate=false.
	$embRoot:=JSON Parse:C1218($embFixture)
	For each ($embDef; $embRoot.definitions)
		If ($embDef.dataclassName="_Students") && (($embDef.vectorName="student_vector_1") || ($embDef.vectorName="student_vector_2"))
			$embDef.autoInvalidate:=False:C215
		End if 
	End for each 
	$embFile.setText(JSON Stringify:C1217($embRoot; *))
	
	// Build a baseline entity with both vectors set and _dirty=false.
	var $s6 : cs:C1710.Entity:=ds:C1482._Students.new()
	$s6.firstName:="AV_Denise"
	$s6.lastName:="AV_Petit"
	$s6.save()
	$s6:=ds:C1482._Students.get($s6.ID)
	$s6.student_vector_1:=$vec
	$s6.student_vector_2:=$vec
	$s6.student_vector_2_dirty:=False:C215
	$s6.save()
	
	// Modify a phrase field while autoInvalidate=false → nothing must change.
	$s6:=ds:C1482._Students.get($s6.ID)
	$s6.firstName:="AV_Denise_MODIFIED"
	$s6.save()
	
	// Capture results, THEN restore the settings file, THEN assert.
	$s6:=ds:C1482._Students.get($s6.ID)
	var $v1Preserved : Boolean:=($s6.student_vector_1#Null:C1517)
	var $v2Preserved : Boolean:=($s6.student_vector_2#Null:C1517)
	var $dirtyUntouched : Boolean:=Not:C34($s6.student_vector_2_dirty)
	
	// Back to the fixture definitions (the original file is restored after the Try block).
	$embFile.setText($embFixture)
	
	ASSERT:C1129($v1Preserved; "case6: student_vector_1 must be PRESERVED when autoInvalidate=false (flag ignored — known bug)")
	ASSERT:C1129($v2Preserved; "case6: student_vector_2 must be PRESERVED when autoInvalidate=false")
	ASSERT:C1129($dirtyUntouched; "case6: student_vector_2_dirty must stay false when autoInvalidate=false (flag ignored — known bug)")
	
Catch
	$failure:=(Last errors:C1799.length>0) ? Last errors:C1799[0] : {errCode: -1; message: "test_saveVectorInvalidation failed"}
End try

// Always restore the original settings file and drop the test rows.
If ($embExisted)
	$embFile.setText($embOrig)
Else 
	$embFile.delete()
End if 
ds:C1482._Students.query("firstName = :1"; "AV_@").drop()
ds:C1482.AllTypes.query("Alpha = :1"; "AV_@").drop()
ds:C1482.School.query("name = :1"; "AV_@").drop()

If ($failure#Null:C1517)
	throw:C1805($failure)
End if 
