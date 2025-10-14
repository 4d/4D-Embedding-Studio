singleton Class constructor()
	
	SET ENVIRONMENT VARIABLE:C812("_4D_OPTION_HIDE_CONSOLE"; "true")
	
	var $error; $input; $output : Text
	LAUNCH EXTERNAL PROCESS:C811(Is Windows:C1573 ? "cmd /C SET" : "/usr/bin/env"; $input; $output; $error)
	
	If (Bool:C1537(OK))
		
		var $t : Text
		For each ($t; Split string:C1554($output; Is Windows:C1573 ? "\r\n" : "\n"; sk ignore empty strings:K86:1))
			
			var $c:=Split string:C1554($t; "=")
			This:C1470[$c[0]]:=$c.length=2 ? $c[1] : ""
			
		End for each 
	End if 
	
	