//%attributes = {}
#DECLARE($caller : Object) : cs:C1710.Model

var $name:=Localized string:C991("newModel")
var $i : Integer

var $c : Collection:=$caller.models.extract("name")

Repeat 
	
	If ($c.includes($name))
		
		$i+=1
		$name:=Localized string:C991("newModel")+String:C10($i; " ##")
		
	Else 
		
		break
		
	End if 
Until (False:C215)

$caller.model:=cs:C1710.Model.new($name)

// Window positioning based on caller
var $height; $width : Integer
FORM GET PROPERTIES:C674("MODEL"; $width; $height)

var $bottom; $left; $right; $top : Integer
GET WINDOW RECT:C443($left; $top; $right; $bottom)

$left+=((($right-$left)-$width)\2)
$top+=40

$caller.winRef:=Open form window:C675("MODEL"; Movable form dialog box no title:K39:20; $left; $top)

DIALOG:C40("MODEL"; $caller)

If (Bool:C1537(OK))
	
	var $o : Object:=$caller.model
	
	var $model:=cs:C1710.Model.new($o.name; $o.model; $o.apiKey; {\
		baseURL: $o.baseURL; \
		organization: $o.organization; \
		project: $o.project\
		})
	
	$caller.addModel($model)
	
	return $model
	
End if 