//%attributes = {}
// Unit tests for cs._menu (menu builder). Menus are built and inspected, never shown:
// the menu commands work headless too, so this runs in CI. popup() is only exercised
// headless, where it returns at once with no choice; with a screen it would wait for a
// click (see test_gui_menu for what needs a screen).

var $menu : cs:C1710._menu
var $sub : cs:C1710._menu
var $item : Object

// ══════════════════════════════════════════════════════════════════════
// CONSTRUCTOR
// ══════════════════════════════════════════════════════════════════════

//MARK:- default: a new, localized, auto-released menu
$menu:=cs:C1710._menu.new()
ASSERT:C1129(Length:C16($menu.ref)>0; "new(): a menu reference is expected")
ASSERT:C1129($menu.localize && $menu.autoRelease && Not:C34($menu.metacharacters); "new(): default options")
ASSERT:C1129($menu.itemCount()=0; "new(): the menu should be empty")
$menu.release()
ASSERT:C1129($menu.released; "release(): the menu should be flagged as released")

//MARK:- options as text, alone or combined
ASSERT:C1129(Not:C34(cs:C1710._menu.new("no-localization").localize); "new('no-localization')")
ASSERT:C1129(Not:C34(cs:C1710._menu.new("keep-reference").autoRelease); "new('keep-reference')")
ASSERT:C1129(cs:C1710._menu.new("display-metacharacters").metacharacters; "new('display-metacharacters')")
$menu:=cs:C1710._menu.new("no-localization;keep-reference;display-metacharacters")
ASSERT:C1129(Not:C34($menu.localize) && Not:C34($menu.autoRelease) && $menu.metacharacters; "new(combined options)")

//MARK:- options as an object, with an icon accessor
var $icons : Collection:=[]
$menu:=cs:C1710._menu.new({localize: False:C215; autoRelease: False:C215; metacharacters: True:C214; iconAccessor: Formula:C1597($icons.push($3))})
ASSERT:C1129(Not:C34($menu.localize) && Not:C34($menu.autoRelease) && $menu.metacharacters; "new(object options)")

//MARK:- the icon proxies, resolved through the accessor
$menu.append("x"; "x")
$menu.icon("path:/RESOURCES/a.png").icon("#b.png").icon("§c.png").icon("|Images/d.png").icon("/RESOURCES/e.png").icon("f.png"; 1)
ASSERT:C1129($icons.join("|")="path:/RESOURCES/a.png|path:/RESOURCES/b.png|path:/FORM/c.png|path:/.PRODUCT_RESOURCES/Images/d.png|path:/RESOURCES/e.png|path:/RESOURCES/f.png"; "icon(): proxies, got "+$icons.join("|"))
$menu.release()

//MARK:- from a menu bar (by number or by name), or an existing reference
var $bar : cs:C1710._menu:=cs:C1710._menu.new(1)
ASSERT:C1129($bar.itemCount()=3; "new(1): menu bar #1 has File, Edit and a third menu, got "+String:C10($bar.itemCount()))
ASSERT:C1129($bar.item(1).withSubMenu; "new(1): the bar items carry their menus")
ASSERT:C1129(Length:C16($bar.itemSubMenuRef($bar.item(1).title))>0; "itemSubMenuRef(): the sub-menu of a bar item")
ASSERT:C1129(Length:C16(cs:C1710._menu.new("Barre #1").ref)>0; "new(bar name): a menu reference is expected")
//MARK:- the menu bar of the current process: none in Design mode or headless
var $current : Text:=Get menu bar reference:C979
var $live : cs:C1710._menu:=cs:C1710._menu.new("menuBar")  // never released: it would be the live menu bar
ASSERT:C1129($live.ref=$current; "new('menuBar'): should be the menu bar of the current process")
If (Length:C16($current)>0)
	ASSERT:C1129($live.items().every(Formula:C1597($1.value.withSubMenu)); "new('menuBar'): every bar item should carry its menu")
End if 

var $same : cs:C1710._menu:=cs:C1710._menu.new($bar.ref)
ASSERT:C1129($same.ref=$bar.ref; "new(reference): the same menu should be used")
$bar.release()

//MARK:- from a collection
var $calls : Collection:=[]
$menu:=cs:C1710._menu.new([\
{label: "First"; parameter: "p1"; marked: True:C214; shortcut: "F"; modifier: Shift key mask:K16:3}; \
{label: "Second"; parameter: "p2"; enabled: False:C215; method: "_errorColor"}; \
{label: "Third"; parameter: "p3"; action: ak copy:K76:54}])
ASSERT:C1129($menu.itemCount()=3; "new(collection): 3 items expected")
$item:=$menu.item(1)
ASSERT:C1129(($item.title="First") && ($item.parameter="p1") && ($item.mark=Char:C90(18)); "new(collection): first item, got "+JSON Stringify:C1217($item))
ASSERT:C1129(($item.key=Character code:C91("F")) && ($item.modifiers=Shift key mask:K16:3); "new(collection): shortcut, got "+JSON Stringify:C1217($item))
ASSERT:C1129($menu.item(2).method="_errorColor"; "new(collection): method")
ASSERT:C1129($menu.getProperty(Associated standard action name:K28:8; 3)="copy"; "new(collection): standard action")
$menu.release()

// ══════════════════════════════════════════════════════════════════════
// ITEMS
// ══════════════════════════════════════════════════════════════════════

//MARK:- append: parameter, mark, default parameter, insertion
$menu:=cs:C1710._menu.new("no-localization")
$menu.append("Alpha"; "a").append("Beta"; "b"; True:C214).append("Gamma")
ASSERT:C1129($menu.item(1).parameter="a"; "append(): parameter")
ASSERT:C1129($menu.item(2).mark=Char:C90(18); "append(): mark")
ASSERT:C1129($menu.item(3).parameter=""; "append(): without parameter, no parameter is set")
$menu.append("Inserted"; "i"; 1)  // a number as 3rd parameter is the position
ASSERT:C1129($menu.item(2).title="Inserted"; "append(after 1): inserted as the 2nd item, got "+JSON Stringify:C1217($menu.items().extract("title")))

//MARK:- append with localization: an xliff reference is localized by 4D
// Plain keys are not asserted: append() tests Position(Char(1); $item) without *, which
// matches every title, so they are never localized (nor their hyphens replaced) today.
var $localized : cs:C1710._menu:=cs:C1710._menu.new()
$localized.append(":xliff:CommonMenuFile")
ASSERT:C1129((Length:C16($localized.item(1).title)>0) && (Position:C15(":xliff:"; $localized.item(1).title)=0); "append(:xliff:): localized by 4D, got "+$localized.item(1).title)
$localized.release()

//MARK:- lines: appended and inserted, recognized as separators
$menu.line()
$menu.line(1)
ASSERT:C1129($menu.isSeparatorItem($menu.itemCount()); "line(): the last item should be a separator")
ASSERT:C1129($menu.isSeparatorItem(2); "line(1): the 2nd item should be a separator")
ASSERT:C1129(Not:C34($menu.isSeparatorItem(1)); "isSeparatorItem(): a plain item is not a separator")
ASSERT:C1129($menu.item(2).isSeparator; "item(): flags separators")

//MARK:- delete: the last added item, or by index
var $count : Integer:=$menu.itemCount()
$menu.delete()  // the last added item is the line inserted at 2, not the last of the list
ASSERT:C1129($menu.itemCount()=($count-1); "delete(): removes one item")
ASSERT:C1129($menu.item(2).title="Inserted"; "delete(): removes the last added item")
$menu.delete(2)
ASSERT:C1129($menu.item(2).title="Beta"; "delete(2): removes the 2nd item")

//MARK:- sub-menu, with its data, kept or released
$sub:=cs:C1710._menu.new("no-localization;keep-reference")
$sub.append("Child"; "c").setData("payload"; 42)
$menu.append("Parent"; $sub)
$item:=$menu.item($menu.itemCount())
ASSERT:C1129($item.withSubMenu; "append(sub-menu): the item should carry the sub-menu")
ASSERT:C1129($menu.submenus.length=1; "append(sub-menu): the sub-menu structure is kept")
ASSERT:C1129($menu.getData("payload")=42; "append(sub-menu): its data is kept")
ASSERT:C1129(Not:C34($sub.released); "keep-reference: the sub-menu should not be released")
var $autoSub : cs:C1710._menu:=cs:C1710._menu.new("no-localization")
$autoSub.append("Child 2"; "c2")
$menu.append("Parent 2"; $autoSub; 1)
ASSERT:C1129($autoSub.released; "auto-release: the sub-menu should be released once attached")
ASSERT:C1129($menu.item(2).withSubMenu; "append(sub-menu; after 1): inserted as the 2nd item")
$sub.release()

//MARK:- with metacharacters
var $meta : cs:C1710._menu:=cs:C1710._menu.new("display-metacharacters")
$sub:=cs:C1710._menu.new("no-localization")
$sub.append("Child"; "c")
$meta.append("Plain"; "p").append("Inserted"; "i"; 0).append("Sub"; $sub).append("Sub first"; cs:C1710._menu.new("no-localization").append("x"; "x"); 0)
ASSERT:C1129($meta.itemCount()=4; "metacharacters: 4 items expected, got "+String:C10($meta.itemCount()))
$meta.release()

$menu.release()

// ══════════════════════════════════════════════════════════════════════
// ITEM PROPERTIES
// ══════════════════════════════════════════════════════════════════════

$menu:=cs:C1710._menu.new("no-localization")
$menu.append("One"; "1").append("Two"; "2").append("Three"; "3")

//MARK:- mark, parameter, method, shortcut, style
$menu.mark()
ASSERT:C1129($menu.item(3).mark=Char:C90(18); "mark(): checks the last item")
$menu.mark(False:C215)
ASSERT:C1129($menu.item(3).mark=""; "mark(False): unchecks the last item")
$menu.mark(True:C214; 1)
ASSERT:C1129($menu.item(1).mark=Char:C90(18); "mark(True; 1)")
$menu.parameter("one"; 1)
ASSERT:C1129($menu.item(1).parameter="one"; "parameter(; 1)")
$menu.method("_warningColor"; 2).method("_errorColor")
ASSERT:C1129(($menu.item(2).method="_warningColor") && ($menu.item(3).method="_errorColor"); "method()")
$menu.shortcut("K").shortcut({key: "J"; modifier: Shift key mask:K16:3}; 0; 2).shortcut("L"; Shift key mask:K16:3; 1)
ASSERT:C1129($menu.item(3).key=Character code:C91("K"); "shortcut(key)")
ASSERT:C1129(($menu.item(2).key=Character code:C91("J")) && ($menu.item(2).modifiers=Shift key mask:K16:3); "shortcut(object; ; index)")
ASSERT:C1129(($menu.item(1).key=Character code:C91("L")) && ($menu.item(1).modifiers=Shift key mask:K16:3); "shortcut(key; modifier; index)")
$menu.shortcut({key: "M"; modifier: 0})
ASSERT:C1129($menu.item(3).key=Character code:C91("M"); "shortcut(object)")
$menu.setStyle(1).setStyle(2; 1)  // Bold, Italic
ASSERT:C1129(($menu.item(3).style=1) && ($menu.item(1).style=2); "setStyle()")

//MARK:- enable / disable, standard action, custom property, indent
$menu.disable().enable().enable(False:C215).enable(True:C214; 1).enable(False:C215; 2).disable(1)
$menu.action(ak paste:K76:55).action(ak copy:K76:54; 1)
ASSERT:C1129($menu.getProperty(Associated standard action name:K28:8; 3)="paste"; "action(): last item")
ASSERT:C1129($menu.getProperty(Associated standard action name:K28:8; 1)="copy"; "action(; 1)")
$menu.property("flag"; "true").property("count"; "12"; 1).property("label"; "text"; 2)
ASSERT:C1129($menu.getProperty("flag"; 3)=True:C214; "getProperty(): a boolean")
ASSERT:C1129($menu.getProperty("count"; 1)=12; "getProperty(): a number")
ASSERT:C1129($menu.getProperty("label"; 2)="text"; "getProperty(): a text")
$menu.indent().indent(1; 2)

//MARK:- data: set, update, read back by name or by item
$menu.setData("color"; "red").setData("color"; "blue").setData("size"; 3; 1)
ASSERT:C1129($menu.getData("color")="blue"; "setData(): the value should be updated")
ASSERT:C1129($menu.getData("size"; "one")=3; "getData(name; ref)")
ASSERT:C1129($menu.getData("missing")=Null:C1517; "getData(): unknown name")
ASSERT:C1129($menu.items().length=3; "items(): every first-level item")

$menu.release()

// ══════════════════════════════════════════════════════════════════════
// STANDARD MENUS
// ══════════════════════════════════════════════════════════════════════

$menu:=cs:C1710._menu.new().edit()
ASSERT:C1129($menu.itemCount()=10; "edit(): 10 items expected, got "+String:C10($menu.itemCount()))
$menu.release()
$menu:=cs:C1710._menu.new().edit(True:C214)
ASSERT:C1129($menu.itemCount()=8; "edit(contextual): 8 items expected, got "+String:C10($menu.itemCount()))
$menu.release()
$menu:=cs:C1710._menu.new().file()
ASSERT:C1129($menu.itemCount()=3; "file(): 3 items expected")
$menu.release()

ARRAY TEXT:C222($fonts; 0)
FONT LIST:C460($fonts)
$menu:=cs:C1710._menu.new().fonts()
ASSERT:C1129($menu.itemCount()=Size of array:C274($fonts); "fonts(): one item per font family")
$menu.release()
$menu:=cs:C1710._menu.new().fonts(True:C214; "_errorColor")
ASSERT:C1129($menu.itemCount()=Size of array:C274($fonts); "fonts(with styles): one item per font family")
$menu.release()
$menu:=cs:C1710._menu.new().fonts("_errorColor")  // a text is the callback
ASSERT:C1129($menu.itemCount()=Size of array:C274($fonts); "fonts(callback): one item per font family")
$menu.release()

// ══════════════════════════════════════════════════════════════════════
// CLEANUP AND POPUP
// ══════════════════════════════════════════════════════════════════════

//MARK:- _cleanup removes leading, trailing and doubled lines and items
$menu:=cs:C1710._menu.new("no-localization")
$menu.line().line().append("A"; "a").line().line().append("B"; "b").append("B"; "b").line().line()
$menu._cleanup()
ASSERT:C1129($menu.items().extract("title").join("|")="A|-|B"; "_cleanup(): got "+$menu.items().extract("title").join("|"))
$menu.release()

//MARK:- popup: headless, returns at once without a choice and releases the menu
var $info : Object:=Application info:C1599
If (Bool:C1537($info.headless))

	$menu:=cs:C1710._menu.new("no-localization")
	$menu.append("A"; "a")
	$menu.popup()
	ASSERT:C1129(Not:C34($menu.selected) && ($menu.choice=""); "popup(headless): no choice")
	ASSERT:C1129($menu.released; "popup(): an auto-released menu is released afterwards")

	$menu:=cs:C1710._menu.new("no-localization;keep-reference")
	$menu.append("A"; "a")
	$menu.popup("a"; 10; 10)
	$menu.popup("a")
	$menu.popup(10; 10)
	var $widget : Object:={windowCoordinates: {left: 10; bottom: 10}; updateCoordinates: Formula:C1597(True:C214)}  // a widget stub
	$menu.popup($widget; "a")
	$menu.popup($widget)
	ASSERT:C1129(Not:C34($menu.released); "popup(keep-reference): the menu is kept")
	$menu.release()

End if
