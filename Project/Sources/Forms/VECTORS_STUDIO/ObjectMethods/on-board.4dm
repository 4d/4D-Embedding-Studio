var $e:=FORM Event:C1606

If ($e.code<0)
	
	var $instance : Object:=OBJECT Get value:C1743(OBJECT Get name:C1087).me.instance
	var $me : Object:=$instance.data
	
	// MARK:- Specific actions
	Case of 
			
			// ______________________________________________________
		: ($me.CANCELLED)
			
			// <NOTHING MORE TO DO>
			
			// ______________________________________________________
		: ($instance.form="NEW_MODEL")\
			 && ($me.ACCEPTED)
			
			var $model : cs:C1710.Model:=$me.model
			
/* #17322
For each model, the following information shall be provided: The name and model are required.
*/
			
			Case of 
					
					// ______________________________________________________
				: (Length:C16(String:C10($model.name))=0)
					
					BEEP:C151
					ALERT:C41(Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991("name")))
					EXECUTE METHOD IN SUBFORM:C1085(String:C10($instance.name); Formula:C1597(GOTO OBJECT:C206(*; "name")))
					
					return 
					
					// ______________________________________________________
				: (Length:C16(String:C10($model.model))=0)
					
					BEEP:C151
					ALERT:C41(Replace string:C233(Localized string:C991("theValueIsRequired."); "{value}"; Localized string:C991("model")))
					EXECUTE METHOD IN SUBFORM:C1085(String:C10($instance.name); Formula:C1597(GOTO OBJECT:C206(*; "model")))
					
					return 
					
					// ______________________________________________________
			End case 
			
/* #17323
The model name shall be unique.
*/
			If (Form:C1466.models.includes($model.name))
				
				BEEP:C151
				ALERT:C41(Localized string:C991("theModelNameMustBeUnique"))
				EXECUTE METHOD IN SUBFORM:C1085(String:C10($instance.name); Formula:C1597(GOTO OBJECT:C206(*; "name")))
				
				return 
				
			End if 
			
			// ______________________________________________________
	End case 
	
	// MARK:- Standard actions
	$me.me.hide()
	
	return 
	
End if 