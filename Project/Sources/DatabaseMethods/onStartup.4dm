
// dev purpose: this project opened directly, not as a component (a component's database
// methods are not executed — see On Host Database Event). Remote clients run On Startup
// too, and the scheduler state is per machine: without this guard every connected client
// would arm its own loop worker and run its own batches.
If (Application type:C494#4D Remote mode:K5:5)
	
	cs:C1710.Scheduler.me.start()
	
End if 

If (Not:C34(Is compiled mode:C492))
	
	ARRAY TEXT:C222($componentsArray; 0)
	COMPONENT LIST:C1001($componentsArray)
	
	If (Find in array:C230($componentsArray; "4DPop QuickOpen")>0)
		
		// Installing quickOpen
		EXECUTE METHOD:C1007("quickOpenInit"; *; Formula:C1597(MODIFIERS); Formula:C1597(KEYCODE))
		ON EVENT CALL:C190("quickOpenEventHandler"; "$quickOpenListener")
		
	End if 
	
	If (Structure file:C489=Structure file:C489(*))  // DEV: VERSION MINI
		
		If (Not:C34(cs:C1710._AIKit.me.isAvailable))
			
			var $c:=Split string:C1554(Application version:C493; "")
			var $major : Text:=$c[0]+$c[1]
			
			If (Application version:C493(*)="A@")
				
				var $version : Text:="DEV ("+$major+"R"+$c[2]+")"
				
			Else 
				
				$version:=$major+Choose:C955($c[2]="0"; ("."+$c[3]); ("R"+$c[2]))
				
			End if 
			
			ALERT:C41(cs:C1710._AIKit.me.missingReason+"\r(4D "+$version+")")
			
		End if 
	End if 
End if 

