//%attributes = {}
// GUI test of the EMBEDDINGS studio window (cs._EMBEDDINGS), opened through
// _EMBEDDINGS_WIZARD and driven by cs._TestGui: no one has to click. Its dialogs go
// through cs._Dialog, captured here. Skipped headless (see _runTests).

If (Not:C34(Asserted:C1132(cs:C1710._TestFixtures.me.ensureAliases(["embed"]); "you must configure an 'embed' model alias")))
	return
End if

var $prevFile : 4D:C1709.File:=cs:C1710._Settings.me.file
var $tmp : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14; *).file("Settings/__test_gui_embeddings.json")
var $tmpBackup : 4D:C1709.File:=$tmp.parent.file($tmp.fullName+".bak")
var $gui : cs:C1710._TestGui:=cs:C1710._TestGui.me
var $dialog : cs:C1710._Dialog:=cs:C1710._Dialog.me

// One real definition, plus three saved definitions the catalog cannot match (ghost rows).
$tmp.setText(JSON Stringify:C1217({definitions: [\
{dataclassName: "_Students"; vectorName: "student_vector_1"; modelAlias: "embed"; phrase: "{firstName}"; autoInvalidate: True:C214}; \
{dataclassName: "NoSuchDataclass"; vectorName: "v"; modelAlias: "embed"; phrase: "{x}"}; \
{dataclassName: "_Students"; vectorName: "nope"; modelAlias: "embed"; phrase: "{x}"}; \
{dataclassName: "_Students"; vectorName: "firstName"; modelAlias: "embed"; phrase: "{x}"}]}))
cs:C1710._Settings.me.file:=$tmp

// Students with computed vectors: editing the definition must offer to invalidate them.
var $seed : Object:=cs:C1710._TestFixtures.me.seedStudents(2)
var $student : 4D:C1709.Entity
For each ($student; $seed.students)
	$student.student_vector_1:=4D:C1709.Vector.new([1; 2; 3])
	ASSERT:C1129($student.save().success; "setup: failed to seed a vector")
End for each

// Expected rows: every 4D.Vector attribute of the catalog, plus the three ghosts.
var $expectedRows : Integer:=3
var $dcName; $attrName : Text
For each ($dcName; ds:C1482)
	For each ($attrName; ds:C1482[$dcName])
		If (String:C10(ds:C1482[$dcName][$attrName].classID)="4D.Vector")
			$expectedRows+=1
		End if
	End for each
End for each

var $devMenu : 4D:C1709.Function:=Formula:C1597(Form:C1466._appendDevMenu($1))
var $attributesMenu : 4D:C1709.Function:=Formula:C1597(Form:C1466._embeddedAttributesMenu(Form:C1466.currentItem; $1))
var $diagLevel : Integer:=Get database parameter:C643(Diagnostic log level:K37:108)

$dialog._capture:=[]
$dialog._answers:=[True:C214]  // "mark all existing vectors for recalculation?" → yes

var $driven : Boolean:=$gui.run("EMBEDDINGS"; Formula:C1597(_EMBEDDINGS_WIZARD); [\
Formula:C1597($1.note("rows"; Form:C1466.items.length)); \
Formula:C1597($1.note("ghostErrors"; Form:C1466.items.query("definition.dataclassName = :1"; "NoSuchDataclass")[0].errors.length)); \
Formula:C1597($1.note("missingVectorErrors"; Form:C1466.items.query("definition.vectorName = :1"; "nope")[0].errors.length)); \
Formula:C1597($1.note("notVectorErrors"; Form:C1466.items.query("definition.vectorName = :1"; "firstName")[0].errors.length)); \
Formula:C1597(Form:C1466.currentItem:=Form:C1466.items.query("definition.dataclassName = :1 AND definition.vectorName = :2"; "_Students"; "student_vector_1")[0]); \
{objectName: "list"; code: On Selection Change:K2:31}; \
{objectName: "list"; code: On Mouse Move:K2:35}; \
{objectName: "phrase"; code: On Mouse Enter:K2:33}; \
{objectName: "phrase"; code: On Mouse Leave:K2:34}; \
{objectName: "phrase"; code: On Clicked:K2:4}; \
{objectName: "phrase"; code: On After Edit:K2:43; value: "{firstName} {nonExistent}"}; \
Formula:C1597($1.note("typingErrors"; Form:C1466.currentItem.errors.length)); \
{objectName: "phrase"; code: On Data Change:K2:15; value: "{firstName} {lastName}"}; \
Formula:C1597($1.note("savedErrors"; Form:C1466.currentItem.errors.length)); \
Formula:C1597(Form:C1466.modelsDropdown.currentValue:="embed"); \
{objectName: "models"; code: On Data Change:K2:15}; \
Formula:C1597(Form:C1466.currentItem.definition.autoInvalidate:=False:C215); \
{objectName: "autoInvalidate"; code: On Clicked:K2:4}; \
Formula:C1597(Form:C1466.refresh()); \
Formula:C1597($1.note("devMenuItems"; $1.menuItemCount($devMenu))); \
Formula:C1597($1.note("attributesMenuItems"; $1.menuItemCount($attributesMenu))); \
Formula:C1597($1.note("unknownChoice"; Form:C1466._handleDevChoice("nope"))); \
Formula:C1597(Form:C1466._handleDevChoice("phraseOption:allowCalculated")); \
Formula:C1597($1.note("allowCalculated"; Form:C1466.settings.phrase.allowCalculated)); \
Formula:C1597(Form:C1466._handleDevChoice("phraseOption:allowCalculated")); \
Formula:C1597(Form:C1466._handleDevChoice("setAllModels:embed")); \
Formula:C1597(Form:C1466._handleDevChoice("diagLevel:"+String:C10($diagLevel))); \
Formula:C1597(Form:C1466.paintSchedulerStatus()); \
Formula:C1597($1.note("schedulerStatus"; Form:C1466.schedulerStatusText)); \
Formula:C1597(Form:C1466.items:=[]); \
Formula:C1597($1.note("emptyState"; Form:C1466.paintEmptyState())); \
Formula:C1597($1.note("emptyText"; Form:C1466.emptyStateText)); \
Formula:C1597(Form:C1466.refresh()); \
Formula:C1597(Form:C1466.currentItem:=Null:C1517); \
{objectName: "list"; code: On Selection Change:K2:31}])

var $asked : Collection:=$dialog._capture
$dialog._capture:=Null:C1517
$dialog._answers:=[]

ASSERT:C1129($driven; "the EMBEDDINGS window should open and be driven: "+JSON Stringify:C1217($gui.errors))
ASSERT:C1129($gui.errors.length=0; "no step should fail: "+JSON Stringify:C1217($gui.errors))

var $notes : Object:=$gui.notes

//MARK:- the list: catalog vectors and saved definitions the catalog cannot match
ASSERT:C1129($notes.rows=$expectedRows; "list: expected "+String:C10($expectedRows)+" rows, got "+String:C10($notes.rows))
ASSERT:C1129($notes.ghostErrors=1; "list: an unknown dataclass should be reported on its row")
ASSERT:C1129($notes.missingVectorErrors=1; "list: a missing vector attribute should be reported on its row")
ASSERT:C1129($notes.notVectorErrors=1; "list: a non-vector attribute should be reported on its row")

//MARK:- the phrase editor: errors while typing, saved on data change
ASSERT:C1129($notes.typingErrors=1; "phrase: an unknown attribute should be highlighted while typing, got "+String:C10($notes.typingErrors))
ASSERT:C1129($notes.savedErrors=0; "phrase: the corrected phrase should have no error, got "+String:C10($notes.savedErrors))

var $saved : Object:=JSON Parse:C1218($tmp.getText()).definitions.query("vectorName = :1"; "student_vector_1").first()
ASSERT:C1129($saved#Null:C1517; "save: the definition should still be in the settings file")
ASSERT:C1129($saved.phrase="{firstName} {lastName}"; "save: the edited phrase should be saved, got "+String:C10($saved.phrase))
ASSERT:C1129($saved.modelAlias="embed"; "save: the model should be saved, got "+String:C10($saved.modelAlias))
ASSERT:C1129($saved.autoInvalidate=False:C215; "save: autoInvalidate should be saved")

//MARK:- leaving an edited definition with computed vectors asks once, and invalidates on yes
ASSERT:C1129($asked.query("kind = :1"; "confirm").length=1; "invalidate prompt: expected exactly one question, got "+JSON Stringify:C1217($asked))
ASSERT:C1129(Position:C15("_Students.student_vector_1"; String:C10($asked.query("kind = :1"; "confirm").first().message))>0; "invalidate prompt: should name the definition")
ASSERT:C1129($asked.query("kind = :1"; "alert").length=0; "no alert expected: "+JSON Stringify:C1217($asked))

// the invalidation runs in its own worker, not in the window: wait for it (up to ~10s)
var $waited : Integer:=0
While ((ds:C1482._Students.query("student_vector_1 != null").length>0) && ($waited<600))
	DELAY PROCESS:C323(Current process:C322; 6)
	$waited+=6
End while
ASSERT:C1129(ds:C1482._Students.query("student_vector_1 != null").length=0; "invalidate prompt: the vectors should be invalidated after yes")

//MARK:- dev menus and actions
ASSERT:C1129($notes.devMenuItems>0; "dev menu: should not be empty")
ASSERT:C1129($notes.attributesMenuItems>0; "attributes menu: should offer the attributes to insert")
ASSERT:C1129($notes.unknownChoice=False:C215; "dev choice: an unknown choice should not be handled")
ASSERT:C1129($notes.allowCalculated=True:C214; "dev choice: the phrase option should toggle")
ASSERT:C1129(Get database parameter:C643(Diagnostic log level:K37:108)=$diagLevel; "dev choice: the diagnostic level should be unchanged")

//MARK:- footer and empty state
ASSERT:C1129(Length:C16(String:C10($notes.schedulerStatus))>0; "footer: the scheduler status should be painted")
ASSERT:C1129($notes.emptyState=True:C214; "empty state: no row → empty state")
ASSERT:C1129(Position:C15(Localized string:C991("emptyStateIntro"); String:C10($notes.emptyText))=1; "empty state: the getting-started text should be shown")

// ══════════════════════════════════════════════════════════════════════
// CLEANUP
// ══════════════════════════════════════════════════════════════════════

ds:C1482._Students.all().drop()
ds:C1482.School.all().drop()
ds:C1482.Cities.all().drop()
cs:C1710._Settings.me.file:=$prevFile
If ($tmp.exists)
	$tmp.delete()
End if
If ($tmpBackup.exists)
	$tmpBackup.delete()
End if
