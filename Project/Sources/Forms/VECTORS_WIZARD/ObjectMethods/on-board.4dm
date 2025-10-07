var $e:=FORM Event:C1606

If ($e.code<0)
	
	// MARK: Callback from the subform 
	var $instance : Object:=OBJECT Get value:C1743(OBJECT Get name:C1087).me.instance
	var $data : Object:=$instance.data
	
	// MARK: Specific actions
	Case of 
			
			// ________________________________________________________________________________
		: ($instance.form="NEW_MODEL")
			
			var $success:=Form:C1466.newModelCallback($instance)
			
			// ________________________________________________________________________________
			//: ($instance.form="MODELS_MANAGER")
			
			//$success:=Form.modelsManagerCallback($instance)
			
			// ________________________________________________________________________________
	End case 
	
	// MARK:- Standard actions
	If ($success)
		
		$data.me.hide()
		
	End if 
	
	return 
	
End if 

// MARK:- Container form events