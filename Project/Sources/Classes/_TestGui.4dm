// Test-only driver for the GUI tests (test_gui_@, skipped headless by _runTests).
//
// Opens a studio window through its real entry point, plays scripted steps inside it,
// then closes it: no one has to click. The window runs in the test process (its entry
// point blocks in DIALOG); the _testGuiDriver worker waits for the window to register in
// Storage.studio, then asks it (CALL FORM) to run _play(), which runs the steps in the
// form context and closes the window.
//
// A step is either:
//   - a 4D.Function, called in the form context (Form is the form class instance), or
//   - an event object {objectName; code; value?} sent to Form.manager(); when "value" is
//     defined, it is first set on the object (OBJECT SET VALUE), as if typed by the user.
//
// Usage:
//   var $gui:=cs._TestGui.me
//   $gui.run("SCHEDULER"; Formula(_SCHEDULER_WIZARD); [\
//     {objectName: "startFromLast"; code: On Clicked}; \
//     Formula($1.note("summary"; Form.summaryText))])
//   ASSERT($gui.errors.length=0; JSON Stringify($gui.errors))
//   $gui.form   // the Form object of the closed window
//   $gui.notes  // the values recorded with note()

property form : Object  // the Form object of the last driven window
property errors : Collection:=[]  // errors raised by the steps
property notes : Object:={}  // values recorded by the steps with note()
property _steps : Collection:=[]

singleton Class constructor

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Opens the window with $open, plays $steps inside it, and returns once it is closed.
	// Returns False when the window could not be driven (e.g. it was already open).
Function run($formName : Text; $open : 4D:C1709.Function; $steps : Collection) : Boolean

	This:C1470.form:=Null:C1517
	This:C1470.errors:=[]
	This:C1470.notes:={}
	This:C1470._steps:=$steps || []

	If (Num:C11(Storage:C1525.studio[$formName])#0)
		This:C1470.errors.push("the "+$formName+" window is already open: close it before running the GUI tests")
		return False:C215
	End if

	// one worker per run: a shared name would queue this run behind the previous driver,
	// whose KILL WORKER discards pending messages, leaving the window undriven in DIALOG
	CALL WORKER:C1389("_testGuiDriver_"+Generate UUID:C1066; "_testGuiDriver"; $formName)

	$open.call()  // blocks in DIALOG until _play() closes the window

	return (This:C1470.form#Null:C1517)

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Records a value seen inside the window, for assertions once it is closed.
Function note($key : Text; $value : Variant)

	This:C1470.notes[$key]:=$value

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Builds a menu with $builder (called with the menu as $1) and returns its item count.
	// The menu is released, never displayed.
Function menuItemCount($builder : 4D:C1709.Function) : Integer

	var $menu : cs:C1710._menu:=cs:C1710._menu.new()
	$builder.call(Null:C1517; $menu)
	var $count : Integer:=$menu.itemCount()
	$menu.release()

	return $count

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Runs inside the window (CALL FORM from _testGuiDriver): plays the steps, then closes it.
Function _play()

	This:C1470.form:=Form:C1466

	var $step : Variant
	For each ($step; This:C1470._steps)

		Try

			If (OB Instance of:C1731($step; 4D:C1709.Function))

				$step.call(Null:C1517; This:C1470)

			Else

				If (OB Is defined:C1231($step; "value"))
					OBJECT SET VALUE:C1742($step.objectName; $step.value)
				End if

				Form:C1466.manager({objectName: $step.objectName; code: $step.code})

			End if

		Catch

			This:C1470.errors.push({step: This:C1470._steps.indexOf($step); errors: Last errors:C1799.copy()})

		End try

	End for each

	// queued after whatever the steps posted themselves (e.g. On Activate's refresh)
	CALL FORM:C1391(Current form window:C827; Formula:C1597(CANCEL:C270))
