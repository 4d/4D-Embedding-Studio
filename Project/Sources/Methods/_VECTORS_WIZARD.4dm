//%attributes = {"shared":true}
/*#17300
In project mode, if the “4D Vector Studio” component is loaded, in the “Design > Vector” menu, a “Vector Studio” item allows you to open the wizard window.
*/
var $winRef:=Open form window:C675("VECTORS_WIZARD"; Structure file:C489=Structure file:C489(*) ? Plain form window:K39:10 : Movable form dialog box:K39:8; Horizontally centered:K39:1; At the top:K39:5; *)
DIALOG:C40("VECTORS_WIZARD")
CLOSE WINDOW:C154($winRef)
