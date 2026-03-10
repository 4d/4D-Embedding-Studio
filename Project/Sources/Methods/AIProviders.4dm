//%attributes = {"invisible":true,"executedOnServer":true,"preemptive":"capable"}
/* GET/SET AI Providers JSON configuration files

with the current AIProviders.json file

GET: Retrieve providers configuration

SET: Save providers configuration

Parameters:
 $value : Object - (SET only) The providers object to save. Pass Null or omit for GET.
          If empty or providers is empty/null, the file is deleted.

Returns:
 Object - The providers configuration (GET) or empty object (SET)

Errors:
 - Throws error 619 "Not writable" if file cannot be written (SET)
 - JSON Parse errors propagated (GET)
 - JSON Stringify errors propagated (SET)
*/

#DECLARE($value : Object) : Object

var $file : 4D:C1709.File:=File:C1566("/DATA/Settings/AIProviders.json"; *)

If (Not:C34($file.exists))
	
	$file:=File:C1566("/PACKAGE/Settings/AIProviders.json"; *)
	
	If (Not:C34($file.exists))
		
		$file:=File:C1566("/SOURCES/AIProviders.json"; *)
		
	End if 
End if 


// MARK:- GET
If ($value=Null:C1517)
	
	If ($file.exists)
		
		return JSON Parse:C1218($file.getText())  // Error propagated
		
	End if 
	
	return {providers: {}}
	
End if 

// MARK:- SET
Case of 
		
		// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
	: ((OB Is empty:C1297($value))\
		 || ($value.providers=Null:C1517)\
		 || (OB Is empty:C1297($value.providers)))
		
		$file.delete()  // Error propagated
		
		// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
	Else 
		
		$file.setText(JSON Stringify:C1217($value; *))  // Error propagated
		
		// ┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅┅
End case 