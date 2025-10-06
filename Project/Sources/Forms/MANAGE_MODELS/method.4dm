var $e:=FORM Event:C1606
var $me : Object:=Form:C1466.me.instance.data

Case of 
		
		// ______________________________________________________
	: ($e.code=On Load:K2:1)
		
		SET TIMER:C645(-1)
		
		// ______________________________________________________
	: ($e.code=On Timer:K2:25)
		
		SET TIMER:C645(0)
		
		//var $data : Object:=Form.me.instance.data
		//var $model:={name: $data.name}
		//OBJECT SET VALUE("model"; $model)
		
		// ______________________________________________________
	: ($e.code=On Bound Variable Change:K2:52)
		
		var $manager : Object:=OBJECT Get value:C1743("manager")
		$manager.models:=$me.models
		OBJECT SET VALUE:C1742("manager"; $manager)
		
		// ______________________________________________________
	: ($e.code=On Resize:K2:27)
		
		Form:C1466.me.onResize()
		
		// ______________________________________________________
End case 