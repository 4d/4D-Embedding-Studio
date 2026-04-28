//%attributes = {}
var $results:=Try(_runTests(True:C214))

If ($results=Null:C1517)
	$results:={success: False:C215; tests: [{name: "_runTests"; success: False:C215; errors: Last errors:C1799.copy()}]}
End if 

var $test : Object
For each ($test; $results.tests || [])
	If ($test.success)
		LOG EVENT:C667(Into system standard outputs:K38:9; "PASS "+String:C10($test.name)+Char:C90(Line feed:K15:40))
	Else 
		LOG EVENT:C667(Into system standard outputs:K38:9; "FAIL "+String:C10($test.name)+" "+JSON Stringify:C1217($test.errors)+Char:C90(Line feed:K15:40))
	End if 
End for each 

Try
	Folder:C1567(fk database folder:K87:14; *).file("results.json").setText(JSON Stringify:C1217($results; *))
Catch
	Folder:C1567(Temporary folder:C486; fk platform path:K87:2).file("tests4DEmbeddingStudio.json").setText(JSON Stringify:C1217($results; *))
End try

QUIT 4D:C291