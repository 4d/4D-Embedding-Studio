//%attributes = {}
// Unit tests for cs._ScheduleCalc (pure next-run calculator)

var $calc : cs:C1710._ScheduleCalc:=cs:C1710._ScheduleCalc.me
var $now : Text:=$calc._nowISO()

// ══════════════════════════════════════════════════════════════════════
// NEVER / UNKNOWN
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129($calc.nextRun(Null:C1517; ""; "")=Null:C1517; "null config → Null")
ASSERT:C1129($calc.nextRun({mode: "never"}; ""; "")=Null:C1517; "never → Null")
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

ASSERT:C1129($calc.slotAfter({mode: "never"}; "2020-01-01T00:00:00")=""; "slotAfter never → empty")

ASSERT:C1129($calc.slotAfter(Null:C1517; "2020-01-01T00:00:00")=""; "slotAfter null config → empty")
ASSERT:C1129($calc.slotAfter({mode: "interval"; intervalHours: 3}; "")=""; "slotAfter without base timestamp → empty")

var $slotClamped : Text:=$calc.slotAfter({mode: "interval"; intervalHours: 48}; "2020-01-01T00:00:00")
ASSERT:C1129($slotClamped="2020-01-01T03:00:00"; "slotAfter out-of-range hours fall back to 3h, got "+$slotClamped)

var $slotSameDay : Text:=$calc.slotAfter({mode: "daily"; dailyTime: "10:00"}; "2020-01-01T09:00:00")
ASSERT:C1129($slotSameDay="2020-01-01T10:00:00"; "slotAfter daily later the same day, got "+$slotSameDay)

// ══════════════════════════════════════════════════════════════════════
// INTERVAL — out-of-range hours
// ══════════════════════════════════════════════════════════════════════

// intervalHours outside 1..24 falls back to 3h: last execution now → next run in 3h
var $clamped : Object:=$calc.nextRun({mode: "interval"; intervalHours: 0; startFrom: "lastExecution"}; $now; "")
var $expectedClamped : Text:=$calc._addSeconds($calc._parse($now); 3*3600).timestamp
ASSERT:C1129($clamped.timestamp=$expectedClamped; "interval 0h → 3h, expected "+$expectedClamped+", got "+$clamped.timestamp)

// ══════════════════════════════════════════════════════════════════════
// DATE ARITHMETIC
// ══════════════════════════════════════════════════════════════════════

var $back : Object:=$calc._addSeconds({date: !2020-01-02!; time: ?00:30:00?}; -3600)
ASSERT:C1129($back.timestamp="2020-01-01T23:30:00"; "_addSeconds negative crosses midnight backwards, got "+$back.timestamp)

var $forward : Object:=$calc._addSeconds({date: !2020-12-31!; time: ?23:30:00?}; 3600)
ASSERT:C1129($forward.timestamp="2021-01-01T00:30:00"; "_addSeconds crosses the year, got "+$forward.timestamp)

var $dateOnly : Object:=$calc._parse("2020-03-04")
ASSERT:C1129($calc._iso($dateOnly.date; $dateOnly.time)="2020-03-04T00:00:00"; "_parse without a time part → midnight")

// ══════════════════════════════════════════════════════════════════════
// secondsUntil
// ══════════════════════════════════════════════════════════════════════

var $inAnHour : Text:=$calc._addSeconds($calc._parse($calc._nowISO()); 3600).timestamp
var $seconds : Integer:=$calc.secondsUntil($inAnHour)
ASSERT:C1129(($seconds>3590) && ($seconds<=3600); "secondsUntil in one hour ≈ 3600, got "+String:C10($seconds))

var $tomorrow : Text:=$calc._addSeconds($calc._parse($calc._nowISO()); 86400).timestamp
$seconds:=$calc.secondsUntil($tomorrow)
ASSERT:C1129(($seconds>86390) && ($seconds<=86400); "secondsUntil the same time tomorrow ≈ 86400, got "+String:C10($seconds))

ASSERT:C1129($calc.secondsUntil("2000-01-01T00:00:00")<0; "secondsUntil a past timestamp is negative")

// ══════════════════════════════════════════════════════════════════════
// _schedulerFormatDate (display of scheduler timestamps)
// ══════════════════════════════════════════════════════════════════════

ASSERT:C1129(_schedulerFormatDate("")="—"; "format empty → dash")
ASSERT:C1129(_schedulerFormatDate("garbage")="garbage"; "format unknown → left untouched")

var $formatted : Text:=_schedulerFormatDate("2026-08-10T11:14:00")
ASSERT:C1129($formatted=(String:C10(!2026-08-10!; Internal date long:K1:5)+" "+String:C10(?11:14:00?; HH MM:K7:2)); "format timestamp → long date + HH:MM, got "+$formatted)

$formatted:=_schedulerFormatDate("2026-08-10")
ASSERT:C1129($formatted=(String:C10(!2026-08-10!; Internal date long:K1:5)+" "+String:C10(?00:00:00?; HH MM:K7:2)); "format date only → midnight, got "+$formatted)
