property success : Boolean:=True:C214  // True = search has found an occurrence; Otherwise, False.
property matches : Collection  // All matches found: collection of objects {index, string, position, length}.
property searchTime : Integer:=0
property errors:=[]

property _target : Text:=""
property _pattern : Text:=""
property _startTime : Integer:=Milliseconds:C459
property _options : Integer:=0

Class constructor($target; $pattern : Text)
	
	If (Count parameters:C259>=1)
		
		This:C1470._setTarget($target)
		
		If (Count parameters:C259>=2)
			
			This:C1470._pattern:=$pattern
			
		End if 
	End if 
	
	// MARK:-
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get target() : Text
	
	return This:C1470._target
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==>
Function set target($target)
	
	This:C1470._setTarget($target)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Sets the string where will be perform the search.
	// Could be a text or a disk file
Function setTarget($target) : cs:C1710.regex
	
	This:C1470._setTarget($target)
	
	return This:C1470
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _setTarget($target)
	
	This:C1470._reset(True:C214)
	
	Case of 
			
			//…………………………………………………………………………………………
		: (Value type:C1509($target)=Is text:K8:3)
			
			This:C1470._target:=$target
			
			//…………………………………………………………………………………………
		: (Value type:C1509($target)=Is object:K8:27)
			
			If (OB Class:C1730($target).name="File")
				
				If ($target.exists)
					
					This:C1470._target:=$target.getText()
					
				Else 
					
					// File not found.
					This:C1470._pushError(Current method name:C684; -43; "File not found.")
					
				End if 
				
			Else 
				
				// Argument types are incompatible.
				This:C1470._pushError(Current method name:C684; 54; "The \"target\" object is not a 4D.File.")
				
			End if 
			
			//…………………………………………………………………………………………
		: (Value type:C1509($target)=Is BLOB:K8:12)
			
			This:C1470._target:=Convert to text:C1012($target; "UTF-8")
			This:C1470.success:=Bool:C1537(OK)
			
			//…………………………………………………………………………………………
		Else 
			
			// Argument types are incompatible.
			This:C1470._pushError(Current method name:C684; 54; "The \"target\" argument  must be Text, a Blob or 4D.File.")
			
			//…………………………………………………………………………………………
	End case 
	
	// MARK:-
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// The current regular expression
Function get pattern() : Text
	
	return This:C1470._pattern
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==>
Function set pattern($pattern : Text)
	
	This:C1470.setPattern($pattern)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Sets the regular expression to use.
Function setPattern($pattern : Text) : cs:C1710.regex
	
	This:C1470._setPattern($pattern)
	
	return This:C1470
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Load a pattern from a file
Function loadPattern($ID : Text; $file : 4D:C1709.File) : cs:C1710.regex
	
	$file:=Count parameters:C259>=2 ? $file : File:C1566("/RESOURCES/regex.xml"; *)
	
	If ($file.exists)
		
		var $root:=DOM Parse XML source:C719($file.platformPath; False:C215)
		
		If (Bool:C1537(OK))
			
			var $node:=DOM Find XML element:C864($root; "/REGEX/patterns/pattern[@name=\""+$ID+"\"]")
			
			If (Bool:C1537(OK))
				
				var $pattern : Text
				DOM GET XML ELEMENT VALUE:C731($node; $pattern; $pattern)
				
				This:C1470.setPattern(cs:C1710.regex.new($pattern; "\\s*\\(\\?#[^)]*\\)|\\s").substitute(""))
				
			End if 
			
			DOM CLOSE XML:C722($root)
			
		End if 
		
	Else 
		
		// File not found.
		This:C1470._pushError(Current method name:C684; -43; "File not found.")
		
	End if 
	
	return This:C1470
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _setPattern($pattern : Text)
	
	This:C1470._reset(True:C214)
	
	This:C1470._pattern:=$pattern
	
	// MARK:-
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function get lastError() : Object
	
	If (This:C1470.errors#Null:C1517)\
		 && (This:C1470.errors.length>0)
		
		return This:C1470.errors[This:C1470.errors.length-1]
		
	End if 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _pushError($method : Text; $code : Integer; $desc : Text)
	
	This:C1470.success:=False:C215
	
	This:C1470.errors.push({\
		code: $code; \
		method: $method; \
		desc: $desc\
		})
	
	// MARK:-[OPTIONS]
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==>
Function get caseSensitve() : Boolean
	
	return This:C1470._options ?? 0
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// If True, search will be case-sensitive. (?-i)
Function set caseSensitve($on : Boolean)
	
	This:C1470._options:=$on ? This:C1470._options ?+ 0 : This:C1470._options ?- 0
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==>
Function get treatTargetAsOneLine() : Boolean
	
	return This:C1470._options ?? 1
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function set treatTargetAsOneLine($on : Boolean)
	
	This:C1470._options:=$on ? This:C1470._options ?+ 1 : This:C1470._options ?- 1
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==>
Function get dotMatchNewLine() : Boolean
	
	return This:C1470._options ?? 2
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
Function set dotMatchNewLine($on : Boolean)
	
	This:C1470._options:=$on ? This:C1470._options ?+ 2 : This:C1470._options ?- 2
	
	// ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==> ==>
Function get allowSpaceAndComments() : Boolean
	
	return This:C1470._options ?? 3
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// If True, allow use of white space and #comments within patterns. (?x)
Function set allowSpaceAndComments($on : Boolean)
	
	This:C1470._options:=$on ? This:C1470._options ?+ 3 : This:C1470._options ?- 3
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function setOptions($options : Integer) : cs:C1710.regex
	
	This:C1470._options:=$options
	
	return This:C1470
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _setOptions($pattern : Text) : Text
	
	var $on : Collection:=[]
	var $off : Collection:=[]
	
	If (This:C1470._options ?? 0)
		
		$off.push("i")  // (?-i)
		
	Else 
		
		$on.push("i")  // (?i)
		
	End if 
	
	If (This:C1470._options ?? 1)
		
		$off.push("m")  // (?-m)
		
	Else 
		
		$on.push("m")  // (?m)
		
	End if 
	
	If (This:C1470._options ?? 2)
		
		$on.push("s")  // (?s)
		
	End if 
	
	If (This:C1470._options ?? 3)
		
		$on.push("x")  // (?x)
		
	End if 
	
	var $options : Text:="(?"+$on.join("")
	
	$options:="(?"
	$options+=$on.join("")
	
	If ($off.length>0)
		
		$options+=" -"+$off.join("")
		
	End if 
	
	$options+=")"
	
	return $options+$pattern
	
	// MARK:-
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Returns True if the pattern matches the target.
 .match({start: Integer ;}{all : Boolean}) : Boolean
*/
Function match($start; $all : Boolean) : Boolean
	
	var $i; $index : Integer
	
	ARRAY LONGINT:C221($pos; 0)
	ARRAY LONGINT:C221($len; 0)
	
	If (Count parameters:C259>=1)
		
		If (Value type:C1509($start)=Is boolean:K8:9)
			
			$all:=$start
			$start:=1
			
		Else 
			
			$start:=Num:C11($start)
			
		End if 
		
	Else 
		
		$start:=1  // Start the search with the first character
		
	End if 
	
	This:C1470._reset()
	
	var $pattern : Text:=This:C1470._setOptions(This:C1470._pattern)
	
	Repeat 
		
		var $match : Boolean:=Try(Match regex:C1019($pattern; This:C1470._target; $start; $pos; $len))
		
		If (Last errors:C1799.length>0)
			
			This:C1470._pushError(Current method name:C684; Last errors:C1799[0].errCode; Last errors:C1799[0].message)
			
			return 
			
		End if 
		
		If ($match)
			
			This:C1470.success:=True:C214
			
			For ($i; 0; Size of array:C274($pos); 1)
				
				This:C1470.matches.push({\
					index: $index; \
					data: Substring:C12(This:C1470._target; $pos{$i}; $len{$i}); \
					position: $pos{$i}; \
					length: $len{$i}\
					})
				
				If ($len{$i}=0)
					
					$match:=($i>0)
					
					If ($match)
						
						$match:=($pos{$i}#$pos{$i-1})
						
					End if 
				End if 
				
				If ($pos{$i}>0)
					
					$start:=$pos{$i}+$len{$i}
					
				End if 
			End for 
			
			If (Not:C34($all))
				
				break  // Stop after the first match
				
			End if 
		End if 
		
		$index+=1
		
	Until (Not:C34($match))
	
	This:C1470.searchTime:=This:C1470._elapsedTime()
	
	return This:C1470.success
	
	// <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <== <==
	// Returns the number of pattern matches with the target
Function get count() : Integer
	
	return This:C1470.matches.length
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Return the position of the matched region in the input string.
Function start($index : Integer) : Integer
	
	$index:=$index#0 ? $index-1 : 0
	
	If (This:C1470.matches.length>=$index)
		
		return This:C1470.matches[$index].position
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Return the length of the match.
Function length($index : Integer) : Integer
	
	$index:=$index#0 ? $index-1 : 0
	
	If (This:C1470.matches.length>=$index)
		
		return This:C1470.matches[$index].length
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Return the position of the first character following the match.
Function end($index : Integer) : Integer
	
	$index:=$index#0 ? $index-1 : 0
	
	If (This:C1470.matches.length>=$index)
		
		return This:C1470.matches[$index].position+This:C1470.matches[$index].length+1
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Return the text that was matched.
Function group($index : Integer) : Text
	
	$index:=$index#0 ? $index-1 : 0
	
	If (This:C1470.matches.length>=$index)
		
		return This:C1470.matches[$index].data
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Returns a collection of extracted substrings
 .extract({groups: Integer}) : Collection
 .extract({groups: Text}) : Collection
 .extract({groups: Collection}) : Collection
*/
Function extract($groups) : Collection
	
	var $i; $index; $indx : Integer
	
	This:C1470._reset()
	
	Case of 
			
			//___________________________________
		: ($groups=Null:C1517)
			
			$groups:=[]
			
			//___________________________________
		: (Value type:C1509($groups)=Is longint:K8:6)\
			 | (Value type:C1509($groups)=Is real:K8:4)
			
			$groups:=[String:C10($groups)]
			
			//___________________________________
		: (Value type:C1509($groups)=Is text:K8:3)
			
			$groups:=Split string:C1554($groups; " ")
			
			//___________________________________
		: (Value type:C1509($groups)=Is collection:K8:32)
			
			// Transform into text if necessary
			var $v
			
			For each ($v; $groups)
				
				$groups[$i]:=String:C10($v)
				$i+=1
				
			End for each 
			
			//___________________________________
		Else 
			
			// Argument types are incompatible.
			This:C1470._pushError(Current method name:C684; 54; "The \"groups\" argument must be an integer, a text or a collection.")
			
			return 
			
			//___________________________________
	End case 
	
	ARRAY LONGINT:C221($len; 0)
	ARRAY LONGINT:C221($pos; 0)
	
	var $pattern : Text:=This:C1470._setOptions(This:C1470._pattern)
	var $start : Integer:=1  // Start the search with the first character
	
	Repeat 
		
		var $match : Boolean:=Try(Match regex:C1019($pattern; This:C1470._target; $start; $pos; $len))
		
		If (Last errors:C1799.length>0)
			
			This:C1470._pushError(Current method name:C684; Last errors:C1799[0].errCode; Last errors:C1799[0].message)
			
			return 
			
		End if 
		
		If ($match)
			
			This:C1470.success:=True:C214
			
			var $current : Integer:=0
			
			For ($i; 0; Size of array:C274($pos); 1)
				
				var $groupIndex : Integer:=$groups.length>0 ? $groups.indexOf(String:C10($current)) : $current
				
				If ($groupIndex>=0)
					
					If ($i>0)\
						 | ($index=0)
						
						If (This:C1470.matches.query("data = :1 & pos = :2"; Substring:C12(This:C1470._target; $pos{$i}; $len{$i}); $pos{$i}).pop()=Null:C1517)
							
							This:C1470.matches.push({\
								index: $indx; \
								data: Substring:C12(This:C1470._target; $pos{$i}; $len{$i}); \
								pos: $pos{$i}; \
								len: $len{$i}\
								})
							
							$indx+=1
							
						End if 
					End if 
				End if 
				
				If ($pos{$i}>0)
					
					$start:=$pos{$i}+$len{$i}
					
				End if 
				
				$current+=1
				
			End for 
		End if 
		
		$index+=1
		
	Until (Not:C34($match))
	
	This:C1470.searchTime:=This:C1470._elapsedTime()
	
	return This:C1470.matches.extract("data")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Replace matching substrings with the replacement text.
Function substitute($replacement : Text; $count : Integer; $position : Integer) : Text
	
	var $replacedText : Text
	var $i; $index : Integer
	var $o : Object
	
	ARRAY LONGINT:C221($len; 0)
	ARRAY LONGINT:C221($pos; 0)
	
	// TODO:Manage count and position
	
	var $backup : Text:=$replacement
	
	This:C1470._reset()
	
	var $pattern : Text:=This:C1470._setOptions(This:C1470._pattern)
	var $start : Integer:=1
	
	Repeat 
		
		var $match : Boolean:=Try(Match regex:C1019($pattern; This:C1470._target; $start; $pos; $len))
		
		If (Last errors:C1799.length>0)
			
			This:C1470._pushError(Current method name:C684; Last errors:C1799[0].errCode; Last errors:C1799[0].message)
			
			return 
			
		End if 
		
		If ($match)
			
			var $sub : Integer:=0
			
			For ($i; 0; Size of array:C274($pos); 1)
				
				If ($pos{$i}>0)
					
					$start:=$pos{$i}+$len{$i}
					
				End if 
				
				If ($len{$i}=0)
					
					$match:=($i>0)
					
					If ($match)
						
						$match:=($pos{$i}#$pos{$i-1})
						
					End if 
				End if 
				
				If ($match)
					
					This:C1470.matches.push({\
						index: $index; \
						data: Substring:C12(This:C1470._target; $pos{$i}; $len{$i}); \
						pos: $pos{$i}; \
						len: $len{$i}; \
						_subpattern: $sub\
						})
					
					$sub+=1
					$index+=1
					
				Else 
					
					break
					
				End if 
			End for 
		End if 
		
	Until (Not:C34($match))
	
	$replacedText:=This:C1470._target
	
	If (This:C1470.matches.length>0)
		
		$index:=This:C1470.matches.length-1
		
		Repeat 
			
			$o:=This:C1470.matches[$index]
			
			If ($o._subpattern#0)
				
				var $subexpression : Text:="\\"+String:C10($o._subpattern)
				
				If (Position:C15($subexpression; $replacement)>0)
					
					$replacement:=Replace string:C233($replacement; $subexpression; $o.data)
					
				End if 
				
			Else 
				
				$replacedText:=Delete string:C232($replacedText; $o.pos; $o.len)
				$replacedText:=Insert string:C231($replacedText; $replacement; $o.pos)
				$replacement:=$backup
				
			End if 
			
			$index-=1
			
		Until ($index=-1)
		
		For each ($o; This:C1470.matches)
			
			OB REMOVE:C1226($o; "_subpattern")
			
		End for each 
	End if 
	
	This:C1470.searchTime:=This:C1470._elapsedTime()
	
	This:C1470.success:=True:C214
	
	return $replacedText
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Alias of substitute 
Function replace($replacement : Text; $count : Integer; $position : Integer) : Text
	
	return This:C1470.substitute($replacement; $count; $position)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns True if the pattern matches at the start of the given string
Function lookingAt($target : Text; $pattern : Text) : Boolean
	
	return cs:C1710.regex.new($target || This:C1470.target).LookingAt($pattern)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns True if the pattern matches at the start of the current string
Function LookingAt($pattern : Text) : Boolean
	
	This:C1470._reset()
	
	var $match : Boolean:=Try(Match regex:C1019(This:C1470._setOptions($pattern || This:C1470._pattern); This:C1470._target; 1; *))
	
	If (Last errors:C1799.length>0)
		
		This:C1470._pushError(Current method name:C684; Last errors:C1799[0].errCode; Last errors:C1799[0].message)
		
		return 
		
	End if 
	
	This:C1470.success:=$match
	
	This:C1470.searchTime:=This:C1470._elapsedTime()
	
	return This:C1470.success
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function split() : Collection
	
	// TODO:split with regex ?
	
	return []
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Returns a string with backslashes in front of predefined characters:
\, *, +, ?, |, {, [, (,), ^, $, ., #, and white spaces
This tells the regular expression engine that it must interpret these characters literally, 
and not as metacharacters.
*/
Function addslashes($in : Text) : Text
	
	If (Length:C16($in)=0)
		
		return ""
		
	End if 
	
	var $char : Text
	
	For each ($char; ["\\"; "*"; "+"; "?"; "|"; "{"; "["; "("; ")"; "^"; "$"; "."; "#"; " "])
		
		$in:=$char=Char:C90(Space:K15:42)\
			 ? Replace string:C233($in; " "; "\\s")\
			 : Replace string:C233($in; $char; "\\"+$char)
		
	End for each 
	
	return $in
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Alias of addslashes
Function escape($in : Text) : Text
	
	return This:C1470.addslashes($in)
	
	// MARK:-[BUILT-IN SHORTCUTS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Validate an email address
Function validateMail($target : Text) : Boolean
	
	This:C1470.target:=$target || This:C1470.target
	This:C1470.pattern:="^([-a-zA-Z0-9_]+(?:\\.[-a-zA-Z0-9_]+)*)(?:@)([-a-zA-Z0-9\\._]+(?:\\.[a-zA-Z0-9]{2,}"+")+)$"
	
	return This:C1470.match()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Removes HTML, XML and PHP tags from the current string
Function StripTags($allow) : Text
	
	This:C1470._target:=This:C1470.stripTags(This:C1470._target; $allow)
	
	return This:C1470._target
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Removes HTML, XML and PHP tags from a string
Function stripTags($target : Text; $allow) : Text
	
	$target:=$target || This:C1470._target
	$target:=Replace string:C233($target; "</p><p>"; " ")
	
	var $len; $pos : Integer
	var $start : Integer:=1
	
	Case of 
			
			//______________________________________________________
		: ($allow=Null:C1517)
			
			var $allowed:=[]
			
			//______________________________________________________
		: (Value type:C1509($allow)=Is collection:K8:32)
			
			$allowed:=$allow
			
			//______________________________________________________
		: (Value type:C1509($allow)=Is text:K8:3)
			
			$allowed:=Split string:C1554($allow; ",")
			
			If ($allowed.length=1)\
				 && Match regex:C1019("(?m-si)^<([^/>]*)>$"; $allow; 1; $pos; $len; *)
				
				$allowed.push("</"+Substring:C12($allow; $pos+1; $len-2)+">")
				
			End if 
			
			//______________________________________________________
		Else 
			
			This:C1470._pushError(Current method name:C684; 54; "The \"allow\" argument  must be Text or a collection.")
			return 
			
			//______________________________________________________
	End case 
	
	While (Match regex:C1019("(?mi-s)<[^>]*>"; $target; $start; $pos; $len))
		
		If ($allowed.includes(Substring:C12($target; $pos; $len)))
			
			$start:=$pos+$len
			
		Else 
			
			$target:=Delete string:C232($target; $pos; $len)
			
		End if 
	End while 
	
	$target:=Replace string:C233($target; "\r\n"; "\n")
	$target:=Replace string:C233($target; "\n\n"; "\n")
	$target:=Replace string:C233($target; "\n"; " ")
	$target:=Replace string:C233($target; "\t"; " ")
	
	While (Position:C15("  "; $target)>0)
		
		$target:=Replace string:C233($target; "  "; " ")
		
	End while 
	
	return $target
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/* 
Extracts & validate dates from a string.
	
The result is a collection of date objects 
{
  string:Text;
  day:Integer;
  month:Integer;
  year:Integer;
  separator:Text;
  valid:Boolean
}
	
You can pass a pivot year to avoid using the default value used by 4D (30).
	
*/
Function extractDates($target; $pivotYear : Integer) : Collection
	
	If (Count parameters:C259>0)
		
		If (Value type:C1509($target)=Is text:K8:3)
			
			This:C1470._target:=$target
			$pivotYear:=$pivotYear>0 ? $pivotYear : 30
			
		Else 
			
			$pivotYear:=Num:C11($target)
			
		End if 
		
	Else 
		
		$pivotYear:=30
		
	End if 
	
	This:C1470.pattern:="(?mi-s)\\b(\\d{1,2})([/-])(\\d{1,2})\\2(\\d{4}|\\d{2})\\b"
	
	var $t : Text
	GET SYSTEM FORMAT:C994(Short date day position:K60:12; $t)
	var $dayPos : Integer:=Num:C11($t)
	
	GET SYSTEM FORMAT:C994(Short date month position:K60:13; $t)
	var $monthPos : Integer:=Num:C11($t)
	
	GET SYSTEM FORMAT:C994(Short date year position:K60:14; $t)
	var $yearPos : Integer:=Num:C11($t)
	
	GET SYSTEM FORMAT:C994(Date separator:K60:10; $t)
	
	var $century : Integer:=Num:C11(Delete string:C232(String:C10(Year of:C25(Current date:C33)); 3; 2))*100
	
	var $c:=[]
	
	If (This:C1470.match(1; True:C214))
		
		var $indx : Integer:=0
		var $o : Object
		
		For each ($o; This:C1470.matches)
			
			Case of 
					
					//______________________________________________________
				: ($indx=0)
					
					var $date : Object:={\
						valid: False:C215; \
						string: $o.data; \
						day: 0; \
						month: 0; \
						year: 0; \
						separator: ""}
					
					//______________________________________________________
				: ($indx=$dayPos)  // Day 
					
					$date.day:=Num:C11($o.data)
					
					//______________________________________________________
				: ($indx=2)  // The separator
					
					$date.separator:=$o.data
					
					//______________________________________________________
				: ($indx=($monthPos+1))  // Month 
					
					$date.month:=Num:C11($o.data)
					
					//______________________________________________________
				: ($indx=($yearPos+1))  // Year
					
					var $year : Integer:=Num:C11($o.data)
					
					If ($year<100)
						
						If ($year>($pivotYear-1))
							
							$date.year:=$century-100+$year
							
						Else 
							
							$date.year:=$century+$year
							
						End if 
						
					Else 
						
						$date.year:=$year
						
					End if 
					
					//______________________________________________________
			End case 
			
			$indx+=1
			
			If ($indx=5)
				
				// Validate
				$date.value:=Date:C102(Replace string:C233($date.string; $date.separator; $t))
				$date.valid:=$date.value=Add to date:C393(!00-00-00!; $date.year; $date.month; $date.day)
				
				// Keep
				$c.push($date)
				
				// Reset index
				$indx:=0
				
			End if 
		End for each 
	End if 
	
	return $c
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Extracts & validate emails from a text.
	
The result is a collection of email objects 
{
  address:Text;
  user:Text;
  domain:Text;
  topLeveldomain:Text;
}
	
This is an imperfect pattern that will pick out likely e-mail addresses using the most common symbols, but will miss unusual addresses.
	
It assumes first that address will start with a letter or number that is not proceeded by one of the other acceptable symbols like "%+__$.-", 
e.g., a@b.com or 9a@b.com. It also assumes that those acceptable symbols can come before the "@", but never two of those in a row. 
Thus a_b@c.com is acceptable but not a_-b@c.com. Finally, every symbol must be followed up by a letter or number like a.b.c@d.com, but not a.@c.com.
	
After the "@", there must be a letter or number like "someone@27bslash6.com". 
After that, there can either be a letter or number, or a symbol like "._-". 
Again, any symbol must be followed by a letter or number, like a@b9-8.com but not a@b--9.com or a@b9-.com.
Finally, the address will end with a period followed by a top-level domain of 2-6 letters. 
	
This will include such addresses as a@b.info and a@b.museum, but not a@b.company. 
It does not verify the top-level domain, of course, so an address like a@b.aol.spam would get through. 
	
Note, by the way, that multiple subdomains are not a problem, like a@really.long.stinkin.domain.name.
*/
Function extractMailsAdresses($target; $domains : Collection) : Collection
	
	If (Value type:C1509($target)=Is collection:K8:32)
		
		$domains:=$target
		$target:=Null:C1517
		
	End if 
	
	If ($target#Null:C1517)
		
		This:C1470._target:=String:C10($target)
		
	End if 
	
	If ($domains#Null:C1517)
		
		This:C1470._pattern:="(?mi-s)\\b(?<![%+_$.-])([a-z0-9](?:[a-z0-9]*|(?:[%+_$.-]?[a-z0-9])*))+@([a-z0-9](?:[a-z0-9]|[._-][a-z0-9])*)("+$domains.map(Formula:C1597("\\."+$1.value)).join("|")+")\\b"
		
	Else 
		
		This:C1470._pattern:="(?mi-s)\\b(?<![%+_$.-])([a-z0-9](?:[a-z0-9]*|(?:[%+_$.-]?[a-z0-9])*))+@([a-z0-9](?:[a-z0-9]|[._-][a-z0-9])*)(\\.[a-z]{2,6})\\b"
		
	End if 
	
	var $c:=[]
	
	If (This:C1470.match(1; True:C214))
		
		var $indx : Integer:=0
		var $o : Object
		
		For each ($o; This:C1470.matches)
			
			Case of 
					
					//______________________________________________________
				: ($indx=0)
					
					var $address : Object:={\
						valid: False:C215; \
						address: $o.data; \
						user: ""; \
						domain: ""; \
						topLeveldomain: ""}
					
					//______________________________________________________
				: ($indx=1)
					
					$address.user:=$o.data
					
					//______________________________________________________
				: ($indx=2)
					
					$address.domain:=$o.data
					
					//______________________________________________________
				: ($indx=3)
					
					$address.topLeveldomain:=$o.data
					
					//______________________________________________________
			End case 
			
			$indx+=1
			
			If ($indx=4)
				
				// Validate
				$address.valid:=This:C1470.validateMail($address.address)
				
				// Keep
				$c.push($address)
				
				// Reset index
				$indx:=0
				
			End if 
			
		End for each 
	End if 
	
	return $c
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Returns the given string in which all start occurrences of a specified character have been removed.
If the character is omitted, the space is used.
*/
Function trimLeading($target : Text; $char : Text) : Text
	
	return cs:C1710.regex.new($target || This:C1470.target).TrimLeading($char)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Removes all beginning occurrences of a specified character from the current string.
If the character is omitted, the space is used.
*/
Function TrimLeading($char : Text) : Text
	
	$char:=This:C1470.addslashes($char) || "\\s"
	
	This:C1470._pattern:="^"+$char+"*"
	This:C1470._target:=This:C1470.substitute()
	
	return This:C1470._target
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Returns the given string in which all ending occurrences of a specified character have been removed.
If the character is omitted, the space is used.
*/
Function trimTrailing($target : Text; $char : Text) : Text
	
	return cs:C1710.regex.new($target || This:C1470.target).TrimTrailing($char)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/* 
Removes all ending occurrences of a specified character from the current string.
If the character is omitted, the space is used.
*/
Function TrimTrailing($char : Text) : Text
	
	$char:=This:C1470.addslashes($char) || "\\s"
	
	This:C1470._pattern:=$char+"*$"
	This:C1470._target:=This:C1470.substitute()
	
	return This:C1470._target
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Returns the given string in which all start and end occurrences of a specified character have been removed.
If the character is omitted, the space is used.
*/
Function trim($target : Text; $char : Text) : Text
	
	return cs:C1710.regex.new($target || This:C1470.target).Trim($char)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
/*
Removes all beginning and ending occurrences of a specified character from the current string.
If the character is omitted, the space is used.
*/
Function Trim($char : Text) : Text
	
	$char:=This:C1470.addslashes($char) || "\\s"
	
	This:C1470._pattern:="^"+$char+"*"
	This:C1470._target:=This:C1470.substitute()
	This:C1470._pattern:=$char+"*$"
	This:C1470._target:=This:C1470.substitute()
	
	return This:C1470._target
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// 🚧 Returns the number of words in a string
Function countWords($target : Text) : Integer
	
	This:C1470._target:=$target || This:C1470._target
	This:C1470.pattern:="(?mi-s)((?:[^[:punct:]\\s[:cntrl:]'‘’]+[’'][^[:punct:]\\s[:cntrl:]'‘’]+)|(?:[^[:punct:]\\s[:cntrl:]'‘’]+))"
	
	return This:C1470.extract().length
	
	// MARK:-
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _reset($success : Boolean)
	
	This:C1470.success:=$success
	This:C1470.matches:=[]
	This:C1470._startTime:=Milliseconds:C459
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _elapsedTime() : Integer
	
	return Milliseconds:C459-This:C1470._startTime
	