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

// Daily slot whose time has already passed today and was never run → due now (timestamp<=now),
// so the loop can actually fire it instead of forever pointing at tomorrow.
var $dueToday : Object:=$calc.nextRun({mode: "daily"; dailyTime: "00:00"}; ""; "")
ASSERT:C1129($dueToday.timestamp<=$now; "daily past-time, never ran → due now, got "+$dueToday.timestamp)

// Same slot but it was already run today (lastExecution=now) → advance to tomorrow.
var $ranToday : Object:=$calc.nextRun({mode: "daily"; dailyTime: "00:00"}; $now; "")
ASSERT:C1129($ranToday.timestamp>$now; "daily past-time, already ran today → tomorrow, got "+$ranToday.timestamp)

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

// AC-4.2.5: next run is EXACTLY lastExecution + N hours (deterministic math, not just
// "in the future"). A far-future last execution keeps the computed slot ahead of now,
// so it is returned verbatim instead of collapsing to an immediate run.
var $lastExec : Text:="2030-06-15T08:00:00"
var $exact : Object:=$calc.nextRun({mode: "interval"; intervalHours: 4; startFrom: "lastExecution"}; $lastExec; "")
ASSERT:C1129($exact.immediate=False:C215; "future lastExecution +4h → not immediate")
ASSERT:C1129($exact.timestamp="2030-06-15T12:00:00"; "interval lastExecution +4h should be exactly L+4h, got "+$exact.timestamp)
ASSERT:C1129($exact.timestamp=$calc.slotAfter({mode: "interval"; intervalHours: 4}; $lastExec); "nextRun should match slotAfter for the same interval anchor")

// ══════════════════════════════════════════════════════════════════════
// INTERVAL — start from now
// ══════════════════════════════════════════════════════════════════════

var $fromNow : Object:=$calc.nextRun({mode: "interval"; intervalHours: 1; startFrom: "reference"}; ""; $now)
ASSERT:C1129($fromNow#Null:C1517; "interval start-from-reference (fallback to anchor) → not null")
ASSERT:C1129($fromNow.timestamp>$now; "interval start-from-reference → next in the future")

// Explicit startReference in the past → next run is that reference advanced past now.
var $fromRef : Object:=$calc.nextRun({mode: "interval"; intervalHours: 3; startFrom: "reference"; startReference: "2020-01-01T00:00:00"}; ""; "")
ASSERT:C1129($fromRef#Null:C1517; "interval start-from-reference → not null")
ASSERT:C1129($fromRef.timestamp>$calc._nowISO(); "interval start-from-reference → next in the future")
ASSERT:C1129(Substring:C12($fromRef.timestamp; 15)="00:00"; "interval start-from-reference → aligned to the reference minutes")

// ══════════════════════════════════════════════════════════════════════
// slotAfter
// ══════════════════════════════════════════════════════════════════════

var $slot : Text:=$calc.slotAfter({mode: "interval"; intervalHours: 3}; "2020-01-01T00:00:00")
ASSERT:C1129($slot="2020-01-01T03:00:00"; "slotAfter interval +3h, got "+$slot)

var $slotDay : Text:=$calc.slotAfter({mode: "daily"; dailyTime: "06:00"}; "2020-01-01T09:00:00")
ASSERT:C1129($slotDay="2020-01-02T06:00:00"; "slotAfter daily next day, got "+$slotDay)

ASSERT:C1129($calc.slotAfter({mode: "disabled"}; "2020-01-01T00:00:00")=""; "slotAfter disabled → empty")
