/**
 Shared base for Process and Playground.
 Holds common configuration, embedder construction, and resolver wiring.
**/

property settings : cs:C1710.Settings
property embedder : cs:C1710.Embedder
property resolver : cs:C1710._Resolver
property options : Object

Class constructor($settings : cs:C1710.Settings; $options : Object)
	
	This:C1470.settings:=$settings || cs:C1710.Settings.new()
	This:C1470.resolver:=cs:C1710._Resolver.new(This:C1470.settings)
	This:C1470.options:=$options || {}
	This:C1470.embedder:=This:C1470._buildEmbedder($options)
	
Function _buildEmbedder($options : Object) : Object
	
	If (($options#Null:C1517) && ($options.embedder#Null:C1517))
		return $options.embedder
	End if 
	
	var $cfg : Object:=This:C1470.settings.embedder
	
	If ($cfg=Null:C1517)
		return cs:C1710.Embedder.new()
	End if 
	
	var $className : Text:=String:C10($cfg.className)
	If ($className#"")
		Try
			var $instance : Object:=cs:C1710[$className].new($cfg)
			If ((OB Instance of:C1731($instance.embed; 4D:C1709.Function))\
				 && (OB Instance of:C1731($instance.embedBatch; 4D:C1709.Function)))
				return $instance
			End if 
			cs:C1710._Logger.me.error("embedder.className '"+$className+"' is missing embed or embedBatch — using default Embedder")
		Catch
			cs:C1710._Logger.me.error("embedder.className '"+$className+"' could not be instantiated — using default Embedder")
		End try
	End if 
	
	return cs:C1710.Embedder.new($cfg)
	
	