property _file : 4D:C1709.File

shared singleton Class constructor
	
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
server Function get() : Object
	var $file:=This:C1470.file
	If (Not:C34($file.exists))
		return Null:C1517
	End if 
	var $data : Variant:=Try(JSON Parse:C1218($file.getText()))
	If (Value type:C1509($data)#Is object:K8:27)
		return Null:C1517
	End if 
	return $data
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
server Function set($value : Object)
	var $file:=This:C1470.file
	var $out : Object
	If (Not:C34($file.exists))
		$out:=$value
	Else 
		var $data : Variant:=Try(JSON Parse:C1218($file.getText()))
		If (Value type:C1509($data)#Is object:K8:27)
			$out:=$value
		Else 
			// we copy setted key, we do not remove key set by others (like scheduling settings)
			$out:=$data
			var $key : Text
			For each ($key; $value)
				If ($value[$key]=Null:C1517)
					OB REMOVE:C1226($out; $key)
				Else 
					$out[$key]:=$value[$key]
				End if 
			End for each 
			
		End if 
	End if 
	
	$file.setText(JSON Stringify:C1217($out; *))
	
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
server Function get file() : 4D:C1709.File
	return This:C1470._file || This:C1470._defaultFile()
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
server Function set file($file : 4D:C1709.File)
	
	Use (This:C1470)
		This:C1470._file:=$file
	End use 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
server Function _defaultFile() : 4D:C1709.File
	
	var $env : Text:=String:C10(cs:C1710._Env.me["EMBEDDINGS_SETTINGS_PATH"])
	If (Length:C16($env)>0)
		
		return File:C1566($env; Is Windows:C1573 ? fk platform path:K87:2 : fk posix path:K87:1)
		
	End if 
	
	// we support only one config (not user, data ones)
	return Folder:C1567(fk database folder:K87:14; *).file("Settings/embeddings.json")