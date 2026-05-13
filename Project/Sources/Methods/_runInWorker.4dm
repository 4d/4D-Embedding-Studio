//%attributes = {"invisible":true}
#DECLARE($formula : 4D:C1709.Function; $param : Variant)

// defer(KILL WORKER) // when tool4d has it

If (Count parameters:C259>=2)
	$formula.call(Null:C1517; $param)
Else 
	$formula.call()
End if 

KILL WORKER:C1390