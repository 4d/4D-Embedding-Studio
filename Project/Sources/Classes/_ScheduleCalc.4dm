/**
 Pure next-run calculator for the embedding scheduler.
 Stateless: every input is passed in, no side effects, no persistence.

 $config : { mode; intervalHours; startFrom; dailyTime }
   mode      : "disabled" | "interval" | "daily"
   intervalHours : Integer 1..24 (interval mode)
   startFrom : "now" | "lastExecution" (interval mode)
   dailyTime : "HH:MM" (daily mode)

 nextRun() returns { date : Date; time : Time; timestamp : Text; immediate : Boolean }
 or Null when the scheduler is disabled.
 All values are expressed in local time (Current date / Current time).
**/

singleton Class constructor
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Computes the next scheduled run.
	// $lastExecution : local ISO timestamp of the last completed run, or "" if none.
	// $anchor        : local ISO timestamp used as the "start from now" anchor (arm time), or "" for current.
Function nextRun($config : Object; $lastExecution : Text; $anchor : Text) : Object
	
	If ($config=Null:C1517)
		return Null:C1517
	End if 
	
	Case of 
		: (String:C10($config.mode)="interval")
			return This:C1470._interval($config; String:C10($lastExecution); String:C10($anchor))
		: (String:C10($config.mode)="daily")
			return This:C1470._daily($config)
		Else 
			return Null:C1517  // disabled or unknown
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Interval mode: next = anchor/lastExecution + N hours, advanced past "now".
Function _interval($config : Object; $lastExecution : Text; $anchor : Text) : Object
	
	var $hours : Integer:=Num:C11($config.intervalHours)
	If (($hours<1) || ($hours>24))
		$hours:=3
	End if 
	
	var $stepSeconds : Integer:=$hours*3600
	var $nowStamp : Text:=This:C1470._nowISO()
	
	If (String:C10($config.startFrom)="lastExecution")
		
		// AC-4.2.6: anchor on the last completed execution.
		If (Length:C16($lastExecution)=0)
			// Never ran yet — run immediately.
			return This:C1470._immediate()
		End if 
		
		var $base : Object:=This:C1470._parse($lastExecution)
		var $candidate : Object:=This:C1470._addSeconds($base; $stepSeconds)
		
		// If the interval already elapsed (e.g. after a server restart) — run immediately.
		If ($candidate.timestamp<=$nowStamp)
			return This:C1470._immediate()
		End if 
		
		return $candidate
		
	End if 
	
	// startFrom = "now": AC-4.2.5, anchor on the arm time (survives across the loop).
	var $anchorStamp : Text:=(Length:C16($anchor)>0) ? $anchor : $nowStamp
	var $slot : Object:=This:C1470._parse($anchorStamp)
	$slot:=This:C1470._addSeconds($slot; $stepSeconds)
	
	// Advance until strictly after now.
	var $guard : Integer:=0
	While (($slot.timestamp<=$nowStamp) && ($guard<100000))
		$slot:=This:C1470._addSeconds($slot; $stepSeconds)
		$guard+=1
	End while 
	
	return $slot
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Daily mode: next occurrence of dailyTime, today or tomorrow.
Function _daily($config : Object) : Object
	
	var $parts : Collection:=Split string:C1554(String:C10($config.dailyTime); ":")
	var $h : Integer:=Num:C11($parts[0])
	var $m : Integer:=($parts.length>=2) ? Num:C11($parts[1]) : 0
	var $target : Time:=?00:00:00?+($h*3600)+($m*60)
	
	var $date : Date:=Current date:C33
	If ($target<=Current time:C178)
		$date:=$date+1
	End if 
	
	return This:C1470._result($date; $target)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Immediate run (now).
Function _immediate() : Object
	
	var $r : Object:=This:C1470._result(Current date:C33; Current time:C178)
	$r.immediate:=True:C214
	return $r
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Builds a result object from a date + time.
Function _result($date : Date; $time : Time) : Object
	
	return {\
		date: $date; \
		time: $time; \
		timestamp: This:C1470._iso($date; $time); \
		immediate: False:C215}
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Adds seconds to a {date; time} pair, returning a full result object.
Function _addSeconds($base : Object; $seconds : Integer) : Object
	
	var $date : Date:=$base.date
	var $time : Time:=$base.time+$seconds
	
	While ($time>=?24:00:00?)
		$date:=$date+1
		$time:=$time-?24:00:00?
	End while 
	
	While ($time<?00:00:00?)
		$date:=$date-1
		$time:=$time+?24:00:00?
	End while 
	
	return This:C1470._result($date; $time)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Parses a local ISO timestamp "YYYY-MM-DDThh:mm:ss" into { date; time }.
Function _parse($iso : Text) : Object
	
	var $parts : Collection:=Split string:C1554($iso; "T")
	var $ymd : Collection:=Split string:C1554($parts[0]; "-")
	var $date : Date:=Add to date:C393(!1900-01-01!; Num:C11($ymd[0])-1900; Num:C11($ymd[1])-1; Num:C11($ymd[2])-1)
	
	var $time : Time:=?00:00:00?
	If ($parts.length>=2)
		$time:=Time:C179(Substring:C12(String:C10($parts[1]); 1; 8))
	End if 
	
	return {date: $date; time: $time}
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Formats a date + time as a local ISO timestamp "YYYY-MM-DDThh:mm:ss".
Function _iso($date : Date; $time : Time) : Text
	
	var $d : Text:=String:C10(Year of:C25($date); "0000")+"-"+String:C10(Month of:C24($date); "00")+"-"+String:C10(Day of:C23($date); "00")
	return $d+"T"+Time string:C180($time)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the next schedule slot strictly after $after (local ISO), or "" when disabled.
	// Used to detect scheduled slots that elapse while a batch is running (skip traceability).
Function slotAfter($config : Object; $after : Text) : Text
	
	If ($config=Null:C1517) || (Length:C16(String:C10($after))=0)
		return ""
	End if 
	
	Case of 
		: (String:C10($config.mode)="interval")
			
			var $hours : Integer:=Num:C11($config.intervalHours)
			If (($hours<1) || ($hours>24))
				$hours:=3
			End if 
			var $slot : Object:=This:C1470._addSeconds(This:C1470._parse($after); $hours*3600)
			return $slot.timestamp
			
		: (String:C10($config.mode)="daily")
			
			var $base : Object:=This:C1470._parse($after)
			var $parts : Collection:=Split string:C1554(String:C10($config.dailyTime); ":")
			var $target : Time:=?00:00:00?+(Num:C11($parts[0])*3600)+(($parts.length>=2) ? (Num:C11($parts[1])*60) : 0)
			var $date : Date:=$base.date
			If ($target<=$base.time)
				$date:=$date+1
			End if 
			return This:C1470._iso($date; $target)
			
		Else 
			return ""
	End case 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Current local timestamp as ISO.
Function _nowISO() : Text
	
	return This:C1470._iso(Current date:C33; Current time:C178)
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Seconds from now until the given local ISO timestamp (may be negative if past).
Function secondsUntil($timestamp : Text) : Integer
	
	var $target : Object:=This:C1470._parse($timestamp)
	var $days : Integer:=$target.date-Current date:C33
	var $seconds : Integer:=($target.time-Current time:C178)
	
	return ($days*86400)+$seconds
