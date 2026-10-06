//%attributes = {}
// GUI test of the SCHEDULER window (cs._SCHEDULER), opened through _SCHEDULER_WIZARD and
// driven by cs._TestGui: no one has to click. Skipped headless (see _runTests).

var $prevFile : 4D:C1709.File:=cs:C1710._Settings.me.file
var $tmp : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_gui_scheduler.json")
var $tmpBackup : 4D:C1709.File:=$tmp.parent.file($tmp.fullName+".bak")
var $state : cs:C1710._SchedulerState:=cs:C1710._SchedulerState.me
var $calc : cs:C1710._ScheduleCalc:=cs:C1710._ScheduleCalc.me
var $gui : cs:C1710._TestGui:=cs:C1710._TestGui.me

cs:C1710.Scheduler.me.stop()
$tmp.setText(JSON Stringify:C1217({scheduler: {mode: "disabled"}}))
cs:C1710._Settings.me.file:=$tmp

// the last run failed: the window shows its error (error box in the layout)
$state.endBatch("failed"; "boom from the last run"; $calc._nowISO())

var $inTenMinutes : Text:=$calc._addSeconds($calc._parse($calc._nowISO()); 600).timestamp
var $inTwoHours : Text:=$calc._addSeconds($calc._parse($calc._nowISO()); 7230).timestamp
var $inSeconds : Text:=$calc._addSeconds($calc._parse($calc._nowISO()); 30).timestamp

// the settings file is redirected above: restore it even when an assertion fails
var $failure : Object
Try
	// ══════════════════════════════════════════════════════════════════════
	// EDIT EVERY CONTROL, THEN SAVE
	// ══════════════════════════════════════════════════════════════════════

	var $driven : Boolean:=$gui.run("SCHEDULER"; Formula:C1597(_SCHEDULER_WIZARD); [\
	Formula:C1597($1.note("loadedMode"; Form:C1466.currentConfig().mode)); \
	Formula:C1597($1.note("errorText"; Form:C1466.errorText)); \
	{objectName: "modeInterval"; code: On Clicked:K2:4}; \
	Formula:C1597(Form:C1466.intervalHours:=99); \
	{objectName: "intervalHours"; code: On Data Change:K2:15}; \
	Formula:C1597($1.note("clampedHours"; Form:C1466.intervalHours)); \
	{objectName: "startFromLast"; code: On Clicked:K2:4}; \
	Formula:C1597($1.note("lastSummary"; Form:C1466.summaryText)); \
	{objectName: "resetAnchor"; code: On Clicked:K2:4}; \
	Formula:C1597($1.note("fromReference"; Form:C1466.startFromReference)); \
	Formula:C1597($1.note("anchorText"; Form:C1466.anchorText)); \
	{objectName: "startFromReference"; code: On Clicked:K2:4}; \
	{objectName: "start"; code: On Clicked:K2:4}; \
	{objectName: "stop"; code: On Clicked:K2:4}; \
	{objectName: "modeDaily"; code: On Clicked:K2:4}; \
	Formula:C1597(Form:C1466.dailyTime:="830"); \
	{objectName: "dailyTime"; code: On Data Change:K2:15}; \
	Formula:C1597($1.note("typedTime"; Form:C1466.dailyTime)); \
	Formula:C1597(Form:C1466.dailyTimeValue:=?21:45:00?); \
	{objectName: "dailyTimeStepper"; code: On Data Change:K2:15}; \
	Formula:C1597($1.note("stepperTime"; Form:C1466.dailyTime)); \
	Formula:C1597($1.note("pendingSummary"; Form:C1466.summaryText)); \
	Formula:C1597($1.note("relDue"; Form:C1466._relative("2000-01-01T00:00:00"))); \
	Formula:C1597($1.note("relSoon"; Form:C1466._relative($inSeconds))); \
	Formula:C1597($1.note("relMinutes"; Form:C1466._relative($inTenMinutes))); \
	Formula:C1597($1.note("relHours"; Form:C1466._relative($inTwoHours))); \
	Formula:C1597($1.note("oneHour"; Form:C1466._hoursLabel(1))); \
	{objectName: "save"; code: On Clicked:K2:4}])

	ASSERT:C1129($driven; "the SCHEDULER window should open and be driven: "+JSON Stringify:C1217($gui.errors))
	ASSERT:C1129($gui.errors.length=0; "no step should fail: "+JSON Stringify:C1217($gui.errors))

	var $notes : Object:=$gui.notes
	ASSERT:C1129($notes.loadedMode="disabled"; "load: the saved mode should be shown, got "+String:C10($notes.loadedMode))
	ASSERT:C1129($notes.errorText="boom from the last run"; "load: the last error should be shown, got "+String:C10($notes.errorText))
	ASSERT:C1129($notes.clampedHours=24; "interval: hours should be clamped to 24, got "+String:C10($notes.clampedHours))
	ASSERT:C1129(Position:C15(Replace string:C233(Localized string:C991("schedulerHoursMany"); "{n}"; "24"); String:C10($notes.lastSummary))>0; "interval: the summary should restate the hours, got "+String:C10($notes.lastSummary))
	ASSERT:C1129($notes.fromReference=True:C214; "resetAnchor: should select the fixed-rate mode")
	ASSERT:C1129(Length:C16(String:C10($notes.anchorText))>0; "resetAnchor: the anchor row should be painted")
	ASSERT:C1129($notes.typedTime="08:30"; "daily: '830' should be normalized to 08:30, got "+String:C10($notes.typedTime))
	ASSERT:C1129($notes.stepperTime="21:45"; "daily: the stepper should drive the field, got "+String:C10($notes.stepperTime))
	ASSERT:C1129(Position:C15(Localized string:C991("schedulerSummaryPending"); String:C10($notes.pendingSummary))>0; "unsaved edits should be flagged in the summary, got "+String:C10($notes.pendingSummary))
	ASSERT:C1129($notes.relDue=Localized string:C991("schedulerRelDue"); "relative: a past run is due")
	ASSERT:C1129($notes.relSoon=Localized string:C991("schedulerRelSoon"); "relative: a run within a minute is soon")
	ASSERT:C1129(Position:C15("{n}"; String:C10($notes.relMinutes))=0; "relative: minutes should be filled in, got "+String:C10($notes.relMinutes))
	ASSERT:C1129(Position:C15("{h}"; String:C10($notes.relHours))=0; "relative: hours should be filled in, got "+String:C10($notes.relHours))
	ASSERT:C1129($notes.oneHour=Localized string:C991("schedulerHoursOne"); "hours label: singular")

	ASSERT:C1129(Not:C34($state.armed); "start then stop: the scheduler should end disarmed")

	var $saved : Object:=JSON Parse:C1218($tmp.getText()).scheduler
	ASSERT:C1129($saved.mode="daily"; "save: the daily mode should be persisted, got "+String:C10($saved.mode))
	ASSERT:C1129($saved.dailyTime="21:45"; "save: the daily time should be persisted, got "+String:C10($saved.dailyTime))
	ASSERT:C1129($saved.intervalHours=24; "save: the interval should be persisted too, got "+String:C10($saved.intervalHours))

	// ══════════════════════════════════════════════════════════════════════
	// CLOSE DISCARDS PENDING EDITS
	// ══════════════════════════════════════════════════════════════════════

	$driven:=$gui.run("SCHEDULER"; Formula:C1597(_SCHEDULER_WIZARD); [\
	Formula:C1597($1.note("reloadedTime"; Form:C1466.dailyTime)); \
	{objectName: "modeDisabled"; code: On Clicked:K2:4}; \
	Formula:C1597($1.note("disabledSummary"; Form:C1466.summaryText)); \
	{objectName: "close"; code: On Clicked:K2:4}])

	ASSERT:C1129($driven; "the SCHEDULER window should open again: "+JSON Stringify:C1217($gui.errors))
	ASSERT:C1129($gui.errors.length=0; "no step should fail: "+JSON Stringify:C1217($gui.errors))
	ASSERT:C1129($gui.notes.reloadedTime="21:45"; "reopen: the saved daily time should be loaded, got "+String:C10($gui.notes.reloadedTime))
	ASSERT:C1129(Position:C15(Localized string:C991("schedulerSummaryDisabled"); String:C10($gui.notes.disabledSummary))=1; "disabled: the summary should say so, got "+String:C10($gui.notes.disabledSummary))
	ASSERT:C1129(JSON Parse:C1218($tmp.getText()).scheduler.mode="daily"; "close: pending edits should not be saved")

	// ══════════════════════════════════════════════════════════════════════
	// FORM HELPERS (no window needed)
	// ══════════════════════════════════════════════════════════════════════

	var $helpers : cs:C1710._SCHEDULER:=cs:C1710._SCHEDULER.new()
	ASSERT:C1129($helpers._formatHHMM($helpers._parseHHMM("8"))="08:00"; "parse: '8' → 08:00")
	ASSERT:C1129($helpers._formatHHMM($helpers._parseHHMM("1245"))="12:45"; "parse: '1245' → 12:45")
	ASSERT:C1129($helpers._formatHHMM($helpers._parseHHMM("8h30"))="08:30"; "parse: '8h30' → 08:30")
	ASSERT:C1129($helpers._formatHHMM($helpers._parseHHMM("25:70"))="00:00"; "parse: out of range → 00:00")
	ASSERT:C1129($helpers._formatHHMM($helpers._parseHHMM(""))="00:00"; "parse: empty → 00:00")
	ASSERT:C1129($helpers._stateLabel({running: True:C214})=Localized string:C991("schedulerStateRunning"); "state label: running")
	ASSERT:C1129($helpers._stateLabel({enabled: True:C214; started: True:C214})=Localized string:C991("schedulerStateArmed"); "state label: armed")
	ASSERT:C1129($helpers._stateLabel({enabled: True:C214})=Localized string:C991("schedulerStateIdle"); "state label: idle")
Catch
	$failure:=(Last errors:C1799.length>0) ? Last errors:C1799[0] : {errCode: -1; message: "test_gui_scheduler failed"}
End try

// ══════════════════════════════════════════════════════════════════════
// CLEANUP
// ══════════════════════════════════════════════════════════════════════

cs:C1710.Scheduler.me.stop()
$state.endBatch(""; ""; "")
cs:C1710._Settings.me.file:=$prevFile
If ($tmp.exists)
	$tmp.delete()
End if
If ($tmpBackup.exists)
	$tmpBackup.delete()
End if

If ($failure#Null:C1517)
	throw:C1805($failure)
End if 
