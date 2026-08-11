//%attributes = {}
#DECLARE($iso : Text) : Text

// Formats a local ISO timestamp ("YYYY-MM-DDThh:mm:ss") as a localized, human-friendly
// date and time (e.g. "August 10, 2026 11:14"). Returns "—" when empty, or the raw input
// when it is not a recognizable timestamp.

If (Length:C16(String:C10($iso))=0)
	return "—"
End if

var $parts : Collection:=Split string:C1554($iso; "T")
var $ymd : Collection:=Split string:C1554($parts[0]; "-")

If ($ymd.length<3)
	return $iso  // unknown format: leave it untouched
End if

var $date : Date:=Add to date:C393(!1900-01-01!; Num:C11($ymd[0])-1900; Num:C11($ymd[1])-1; Num:C11($ymd[2])-1)

var $time : Time:=?00:00:00?
If ($parts.length>=2)
	$time:=Time:C179(Substring:C12(String:C10($parts[1]); 1; 8))
End if

return String:C10($date; Internal date long:K1:5)+" "+String:C10($time; HH MM:K7:2)
