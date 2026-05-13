//%attributes = {}
#DECLARE($definition : cs:C1710.Definition)

var $settings : cs:C1710.Settings:=cs:C1710.Settings.new()
var $scope : Collection:=($definition=Null:C1517) ? $settings.definitions : [$definition]

If ($scope.length=0)
	ALERT:C41("⚠️ No vector definitions found.")
	return 
End if 

var $execLog : Object:=cs:C1710._ExecutionLog.me._read()
var $execDefs : Object:=$execLog.definitions || {}

var $stats : Object:={definitions: []; summary: {total: 0; computed: 0; dirty: 0; pending: 0}}

var $def : cs:C1710.Definition
For each ($def; $scope)
	
	var $dc : 4D:C1709.DataClass:=ds:C1482[$def.dataclassName]
	
	If ($dc=Null:C1517)
		$stats.definitions.push({name: $def.dataclassName+"."+$def.vectorName; error: "unknown dataclass"})
		continue
	End if 
	
	var $dirtyField : Text:=$def.vectorName+"_dirty"
	var $hasDirty : Boolean:=($dc[$dirtyField]#Null:C1517)
	
	var $stat : Object:={name: $def.dataclassName+"."+$def.vectorName; total: 0; computed: 0; dirty: 0; pending: 0; attributes: {}}
	$stat.total:=$dc.all().length
	$stat.pending:=$dc.query($def.vectorName+" = null").length
	
	If ($hasDirty)
		$stat.dirty:=$dc.query($def.vectorName+" != null AND "+$dirtyField+" = true").length
	End if 
	
	$stat.computed:=$stat.total-$stat.pending-$stat.dirty
	
	// Per-attribute empty/null stats
	var $attributes : Collection:=$def.phrase.attributes($dc)
	var $keys : Collection:=$def.phrase.keys
	var $ai : Integer
	For ($ai; 0; $attributes.length-1)
		var $attr : Object:=$attributes[$ai]
		var $attrKey : Text:=$keys[$ai]
		If ($attr#Null:C1517)
			If ($attr.type="string")
				$stat.attributes[$attrKey]:=$dc.query($attrKey+" = null OR "+$attrKey+" = :1"; "").length
			Else 
				$stat.attributes[$attrKey]:=$dc.query($attrKey+" = null").length
			End if 
		End if 
	End for 
	
	$stats.definitions.push($stat)
	
	$stats.summary.total+=$stat.total
	$stats.summary.computed+=$stat.computed
	$stats.summary.dirty+=$stat.dirty
	$stats.summary.pending+=$stat.pending
	
End for each 

// Build display text from collected stats
var $lines : Collection:=[]
var $defStat : Object
For each ($defStat; $stats.definitions)
	If ($defStat.error#Null:C1517)
		$lines.push("⚠️ "+$defStat.name+" — "+$defStat.error)
	Else 
		var $attrLines : Collection:=[]
		var $ak : Text
		For each ($ak; $defStat.attributes)
			$attrLines.push("      "+$ak+": "+String:C10($defStat.attributes[$ak]))
		End for each 
		var $attrPart : Text:=""
		If ($attrLines.length>0)
			$attrPart:="\n  attributes (empty/null):\n"+$attrLines.join("\n")
		End if 
		var $execEntry : Object:=$execDefs[$defStat.name]
		var $execPart : Text:=""
		If ($execEntry#Null:C1517)
			$execPart:="\n  last run: "+String:C10($execEntry.endTime)+" ("+String:C10($execEntry.status)+")"
			If ($execEntry.error#Null:C1517)
				$execPart:=$execPart+"\n  error:    "+String:C10($execEntry.error)
			End if 
			If (Num:C11($execEntry.totalTokens)>0)
				$execPart:=$execPart+"\n  tokens (last):  "+String:C10($execEntry.promptTokens)+" prompt / "+String:C10($execEntry.totalTokens)+" total"
			End if 
			If (Num:C11($execEntry.cumulativeTotalTokens)>0)
				$execPart:=$execPart+"\n  tokens (all):   "+String:C10($execEntry.cumulativePromptTokens)+" prompt / "+String:C10($execEntry.cumulativeTotalTokens)+" total"
			End if 
		End if 
		$lines.push($defStat.name\
			+"\n  total:    "+String:C10($defStat.total)\
			+"\n  computed: "+String:C10($defStat.computed)\
			+"\n  dirty:    "+String:C10($defStat.dirty)\
			+"\n  pending:  "+String:C10($defStat.pending)\
			+$attrPart+$execPart)
	End if 
End for each 

var $msg : Text:=$lines.join("\n\n")

If ($scope.length>1)
	$msg:=$msg+"\n\n───────────────────\nSummary ("+String:C10($scope.length)+" definitions)"\
		+"\n  total:    "+String:C10($stats.summary.total)\
		+"\n  computed: "+String:C10($stats.summary.computed)\
		+"\n  dirty:    "+String:C10($stats.summary.dirty)\
		+"\n  pending:  "+String:C10($stats.summary.pending)
	If (Length:C16(String:C10($execLog.startTime))>0)
		$msg:=$msg+"\n\nLast full run: "+String:C10($execLog.endTime)+" ("+String:C10($execLog.status)+")"
		If ($execLog.error#Null:C1517)
			$msg:=$msg+"\n  error: "+String:C10($execLog.error)
		End if 
		If (Num:C11($execLog.totalTokens)>0)
			$msg:=$msg+"\n  tokens (last):  "+String:C10($execLog.promptTokens)+" prompt / "+String:C10($execLog.totalTokens)+" total"
		End if 
		If (Num:C11($execLog.cumulativeTotalTokens)>0)
			$msg:=$msg+"\n  tokens (all):   "+String:C10($execLog.cumulativePromptTokens)+" prompt / "+String:C10($execLog.cumulativeTotalTokens)+" total"
		End if 
	End if 
End if 

ALERT:C41($msg)
