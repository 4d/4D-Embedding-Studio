//%attributes = {}
// Unit tests for cs._ScheduleCalc (pure next-run calculator)

var $calc : cs:C1710._ScheduleCalc:=cs:C1710._ScheduleCalc.me
var $now : Text:=$calc._nowISO()

// ══════════════════════════════════════════════════════════════════════
// DISABLED / UNKNOWN
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($calc.nextRun(Null:C1517; ""; "")=Null:C1517; "null config → Null")
ASSERT:C1129($calc.nextRun({mode: "disabled"}; ""; "")=Null:C1517; "disabled → Null")
ASSERT:C1129($calc.nextRun({mode: "unknown"}; ""; "")=Null:C1517; "unknown mode → Null")

// ══════════════════════════════════════════════════════════════════════
// DAILY
// ══════════════════════════════════════════════════════════════════════

var $daily : Object:=$calc.nextRun({mode: "daily"; dailyTime: "23:59"}; ""; "")
ASSERT:C1129($daily#Null:C1517; "daily → not null")
ASSERT:C1129(Substring:C12($daily.timestamp; 11)="T23:59:00"; "daily time part should be 23:59:00, got "+$daily.timestamp)
ASSERT:C1129($daily.timestamp>$now; "daily next run should be in the future")
ASSERT:C1129($daily.immediate=False:C215; "daily should not be immediate")

// ══════════════════════════════════════════════════════════════════════
// INTERVAL — start from last execution
// ══════════════════════════════════════════════════════════════════════

// Elapsed since last execution far exceeds the interval → run immediately (AC-4.2.6)
var $overdue : Object:=$calc.nextRun({mode: "interval"; intervalHours: 3; startFrom: "lastExecution"}; "2000-01-01T00:00:00"; "")
ASSERT:C1129($overdue.immediate=True:C214; "overdue lastExecution → immediate")

// Never ran yet → run immediately
var $never : Object:=$calc.nextRun({mode: "interval"; intervalHours: 3; startFrom: "lastExecution"}; ""; "")
ASSERT:C1129($never.immediate=True:C214; "no lastExecution → immediate")

// Recent last execution → next is one interval later, in the future
var $recent : Object:=$calc.nextRun({mode: "interval"; intervalHours: 2; startFrom: "lastExecution"}; $now; "")
ASSERT:C1129($recent.immediate=False:C215; "recent lastExecution → not immediate")
ASSERT:C1129($recent.timestamp>$now; "recent lastExecution → next in the future")

// ══════════════════════════════════════════════════════════════════════
// INTERVAL — start from now
// ══════════════════════════════════════════════════════════════════════

var $fromNow : Object:=$calc.nextRun({mode: "interval"; intervalHours: 1; startFrom: "now"}; ""; $now)
ASSERT:C1129($fromNow#Null:C1517; "interval start-from-now → not null")
ASSERT:C1129($fromNow.timestamp>$now; "interval start-from-now → next in the future")

// ══════════════════════════════════════════════════════════════════════
// slotAfter
// ══════════════════════════════════════════════════════════════════════

var $slot : Text:=$calc.slotAfter({mode: "interval"; intervalHours: 3}; "2020-01-01T00:00:00")
ASSERT:C1129($slot="2020-01-01T03:00:00"; "slotAfter interval +3h, got "+$slot)

var $slotDay : Text:=$calc.slotAfter({mode: "daily"; dailyTime: "06:00"}; "2020-01-01T09:00:00")
ASSERT:C1129($slotDay="2020-01-02T06:00:00"; "slotAfter daily next day, got "+$slotDay)

ASSERT:C1129($calc.slotAfter({mode: "disabled"}; "2020-01-01T00:00:00")=""; "slotAfter disabled → empty")
