var $e:=FORM Event:C1606
var $me : Object:=Form:C1466.me.instance.data

Case of 
		
		// ______________________________________________________
	: ($e.code=On Load:K2:1)
		
		SET TIMER:C645(-1)
		
		// ______________________________________________________
	: ($e.code=On Timer:K2:25)
		
		SET TIMER:C645(0)
		
		var $model:=cs:C1710.Model.new($me.name)
		OBJECT SET VALUE:C1742("model"; $model)
		
		// ______________________________________________________
	: ($e.code=On Bound Variable Change:K2:52)
		
		If ($me.target#Null:C1517)  // ERROR Camllback
			
			$model:=OBJECT Get value:C1743("model")
			//%W-550.26
			$model.target:=$me.target
			$model.isNew:=True:C214
			//%W+550.26
			OBJECT SET VALUE:C1742("model"; $model)
			
		End if 
		
		// ______________________________________________________
	: ($e.code=On Resize:K2:27)
		
		Form:C1466.me.onResize()
		
		// ______________________________________________________
End case 