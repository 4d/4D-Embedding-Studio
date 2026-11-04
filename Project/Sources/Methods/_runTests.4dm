//%attributes = {"invisible":true}
#DECLARE($quiet : Boolean) : Object
var $results : Object:={success: False:C215; tests: []}

ARRAY TEXT:C222($testNames; 0)
METHOD GET NAMES:C1166($testNames; "test_@")
ARRAY TO COLLECTION:C1563($results.tests; $testNames)

$results.tests:=$results.tests.map(Formula:C1597({name: $1.value}))

// GUI tests (test_gui_@) open real windows: skipped when there is no screen (tool4d, 4D --headless)
var $info : Object:=Application info:C1599
var $headless : Boolean:=Bool:C1537($info.headless)

var $methodOnError:=Method called on error:C704
var $test : Object
For each ($test; $results.tests)
	
	If ($headless && (Position:C15("test_gui_"; $test.name)=1))
		$test.skipped:=True:C214
		$test.success:=True:C214
		continue
	End if 
	
	ON ERR CALL:C155("_onTestErrors"; ek global:K92:2)
	_onTestErrors(True:C214)
	
	var $start : Integer:=Milliseconds:C459
	Try(Formula from string:C1601($test.name).call())
	$test.duration:=Milliseconds:C459-$start  // ms
	
	$test.errors:=Last errors:C1799 || ((Storage:C1525.errors.last#Null:C1517) ? Storage:C1525.errors.last.copy() : Null:C1517)
	$test.success:=($test.errors=Null:C1517)
	
	ON ERR CALL:C155($methodOnError; ek global:K92:2)
End for each 

$results.success:=Not:C34($results.tests.some(Formula:C1597(Not:C34($1.value.success))))
	
If (Not:C34($quiet))
	ASSERT:C1129($results.success; JSON Stringify:C1217($results; *))
End if 

return $results