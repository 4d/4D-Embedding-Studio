//%attributes = {"invisible":true}
var $updated : Integer:=0
var $skipped : Integer:=0
var $errors : Collection:=[]

var $dcName : Text
For each ($dcName; ds)

	var $dc : 4D:C1709.DataClass:=ds[$dcName]

	// Collect vector fields and whether each has a companion _dirty flag
	var $fields : Collection:=[]
	var $attrKey : Text
	For each ($attrKey; $dc)
		var $attr : Object:=$dc[$attrKey]
		If (String:C10($attr.classID)="4D.Vector")
			var $dirtyName : Text:=$attr.name+"_dirty"
			$fields.push({\
				vector: $attr.name; \
				dirty: $dirtyName; \
				hasDirty: ($dc[$dirtyName]#Null:C1517)})
		End if
	End for each

	If ($fields.length=0)
		continue
	End if

	var $entity : 4D:C1709.Entity
	For each ($entity; $dc.all())

		var $field : Object
		For each ($field; $fields)
			$entity[$field.vector]:=Null:C1517
			If ($field.hasDirty)
				$entity[$field.dirty]:=True:C214
			End if
		End for each

		var $status : Object:=$entity.save()

		If ($status.success)
			$updated+=1
		Else
			$skipped+=1
			$errors.push($dcName+": "+String:C10($status.statusText))
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
