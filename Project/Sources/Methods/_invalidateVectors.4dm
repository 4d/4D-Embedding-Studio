//%attributes = {"invisible":true}
#DECLARE($definition : cs:C1710.Definition)

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new()
var $scope : Collection:=($definition=Null:C1517) ? $settings.definitions : [$definition]

If ($scope.length=0)
	ALERT:C41("⚠️ No vector definitions found.")
	return 
End if 

var $updated : Integer:=0
var $skipped : Integer:=0
var $errors : Collection:=[]

var $def : cs:C1710.Definition
For each ($def; $scope)
	
	var $dc : 4D:C1709.DataClass:=ds:C1482[$def.dataclassName]
	
	If ($dc=Null:C1517)
		$errors.push($def.dataclassName+"."+$def.vectorName+": unknown dataclass")
		continue
	End if 
	
	var $dirtyName : Text:=$def.vectorName+"_dirty"
	var $hasDirty : Boolean:=($dc[$dirtyName]#Null:C1517)
	
	var $entity : 4D:C1709.Entity
	For each ($entity; $dc.all())
		
		$entity[$def.vectorName]:=Null:C1517
		If ($hasDirty)
			$entity[$dirtyName]:=True:C214
		End if 
		
		var $status : Object:=$entity.save()
		
		If ($status.success)
			$updated+=1
		Else 
			$skipped+=1
			$errors.push($def.dataclassName+"."+$def.vectorName+": "+String:C10($status.statusText))
		End if 
		
	End for each 
	
End for each 

var $msg : Text:="✅ "+String:C10($updated)+" entity(ies) invalidated."

If ($skipped>0)
	$msg:=$msg+"\n⚠️ "+String:C10($skipped)+" skipped."
End if 

If ($errors.length>0)
	var $e : Text
	For each ($e; $errors)
		$msg:=$msg+"\n  • "+$e
	End for each 
End if 

ALERT:C41($msg)
