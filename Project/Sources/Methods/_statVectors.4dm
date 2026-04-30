//%attributes = {}
#DECLARE($definition : cs:C1710.Definition)

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new()
var $scope : Collection:=($definition=Null:C1517) ? $settings.definitions : [$definition]

If ($scope.length=0)
	ALERT:C41("⚠️ No vector definitions found.")
	return
End if

var $lines : Collection:=[]
var $summaryTotal : Integer:=0
var $summaryComputed : Integer:=0
var $summaryDirty : Integer:=0
var $summaryPending : Integer:=0

var $def : cs:C1710.Definition
For each ($def; $scope)

	var $dc : 4D:C1709.DataClass:=ds:C1482[$def.dataclassName]

	If ($dc=Null:C1517)
		$lines.push("⚠️ "+String:C10($def.dataclassName)+"."+String:C10($def.vectorName)+" — unknown dataclass")
		continue
	End if

	var $dirtyField : Text:=$def.vectorName+"_dirty"
	var $hasDirty : Boolean:=($dc[$dirtyField]#Null:C1517)

	var $total : Integer:=$dc.all().length
	var $pending : Integer:=$dc.query($def.vectorName+" = null").length
	var $dirty : Integer:=0

	If ($hasDirty)
		$dirty:=$dc.query($def.vectorName+" != null AND "+$dirtyField+" = true").length
	End if

	var $computed : Integer:=$total-$pending-$dirty

	$lines.push($def.dataclassName+"."+$def.vectorName\
		+"\n  total:    "+String:C10($total)\
		+"\n  computed: "+String:C10($computed)\
		+"\n  dirty:    "+String:C10($dirty)\
		+"\n  pending:  "+String:C10($pending))

	$summaryTotal+=$total
	$summaryComputed+=$computed
	$summaryDirty+=$dirty
	$summaryPending+=$pending

End for each

var $msg : Text:=$lines.join("\n\n")

If ($scope.length>1)
	$msg:=$msg+"\n\n───────────────────\nSummary ("+String:C10($scope.length)+" definitions)"\
		+"\n  total:    "+String:C10($summaryTotal)\
		+"\n  computed: "+String:C10($summaryComputed)\
		+"\n  dirty:    "+String:C10($summaryDirty)\
		+"\n  pending:  "+String:C10($summaryPending)
End if

ALERT:C41($msg)
