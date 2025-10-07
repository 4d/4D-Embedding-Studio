var $e:=FORM Event:C1606

If ($e.code<0)
	
	// MARK: Return from subforms 
	var $instance : Object:=OBJECT Get value:C1743(OBJECT Get name:C1087).me.instance
	var $data : Object:=$instance.data
	
	// MARK: Specific actions
	Case of 
			
			// ________________________________________________________________________________
		: ($instance.form="NEW_MODEL")
			
			var $continue:=Form:C1466.newModelCallback($instance)
			
			// ________________________________________________________________________________
	End case 
	
	// MARK:- Standard actions
	If ($continue)
		
		$data.me.hide()
		
	End if 
	
	return 
	
End if 

// MARK:- Container form events