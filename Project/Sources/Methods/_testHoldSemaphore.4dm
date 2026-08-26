//%attributes = {"invisible":true}
// Test helper: holds $name for $seconds, so the caller can exercise a timeout path.
#DECLARE($name : Text; $seconds : Integer)

If (Not:C34(Semaphore:C143($name)))
	DELAY PROCESS:C323(Current process:C322; $seconds*60)
	CLEAR SEMAPHORE:C144($name)
End if 

KILL WORKER:C1390
