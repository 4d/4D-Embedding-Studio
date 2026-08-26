property _file : 4D:C1709.File

shared singleton Class constructor
	
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Reads the settings file and tells the caller *why* there is no content, which a bare
	// Null cannot: an absent file is a fresh install, an unreadable one is a file we must not
	// overwrite with defaults.
	// Returns { exists : Boolean ; valid : Boolean ; data : Object }
server Function read() : Object
	var $file:=This:C1470.file
	If (Not:C34($file.exists))
		return {exists: False:C215; valid: True:C214; data: Null:C1517}
	End if 
	var $data : Variant:=Try(JSON Parse:C1218($file.getText()))
	If (Value type:C1509($data)#Is object:K8:27)
		return {exists: True:C214; valid: False:C215; data: Null:C1517}
	End if 
	return {exists: True:C214; valid: True:C214; data: $data}
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// The settings content, or Null when there is none to read (absent or unreadable file).
	// Use read() when the difference matters.
server Function get() : Object
	return This:C1470.read().data
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
server Function set($value : Object)
	var $file:=This:C1470.file
	var $current : Object:=This:C1470.read()
	var $out : Object
	
	// before anything is merged into it: $out below is the very object read() returned,
	// so backing up afterwards would back up the new content
	This:C1470._backup($current)
	
	// we copy setted key, we do not remove key set by others (like scheduling settings),
	// and a key passed as Null is a removal — including on a file we are creating
	$out:=($current.data#Null:C1517) ? $current.data : {}
	
	var $key : Text
	For each ($key; $value)
		If ($value[$key]=Null:C1517)
			OB REMOVE:C1226($out; $key)
		Else 
			$out[$key]:=$value[$key]
		End if 
	End for each 
	
	$file.setText(JSON Stringify:C1217($out; *))
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Keeps the last readable content next to the file, as a ".bak", before it is replaced.
	// The settings file holds the vector definitions and the scheduler configuration, and a
	// bad write (or a bad merge) has no other way back.
server Function _backup($current : Object)
	
	If (($current=Null:C1517) || Not:C34($current.exists))
		return   // nothing to preserve yet
	End if 
	
	Try
		
		If ($current.valid)
			
			This:C1470.backupFile.setText(JSON Stringify:C1217($current.data; *))
			
		Else 
			
			// About to write over something we could not parse: keep the bytes as they are,
			// so a hand-editing accident stays recoverable.
			var $file:=This:C1470.file
			$file.parent.file($file.fullName+".corrupt").setText($file.getText())
			cs:C1710._Logger.me.error("Settings file was unreadable and has been replaced; previous content kept as "+$file.fullName+".corrupt")
			
		End if 
		
	Catch
		cs:C1710._Logger.me.warn("Settings backup failed: "+String:C10(Last errors:C1799[0].message))
	End try 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Where the last readable settings content is kept.
server Function get backupFile() : 4D:C1709.File
	var $file:=This:C1470.file
	return $file.parent.file($file.fullName+".bak")
	
	
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