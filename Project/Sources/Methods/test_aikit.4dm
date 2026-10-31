//%attributes = {}
// Unit tests for cs._AIKit, the guard around the 4D AIKit component.
// AIKit is loaded in the test project, so the "missing" and "outdated" paths are forced with
// the _simulate test seam (per-process singleton: nothing else is affected).

var $aikit : cs:C1710._AIKit:=cs:C1710._AIKit.me
var $def : cs:C1710.Definition
var $result : Object
var $embedder : cs:C1710.Embedder
var $error : Object

//MARK:- available
$aikit._simulate:=""
ASSERT:C1129($aikit.isAvailable; "AIKit is a dependency of the project: it must be available")
ASSERT:C1129($aikit.missingReason=""; "available: missingReason must be empty")
ASSERT:C1129(Value type:C1509($aikit.modelNames())=Is collection:K8:32; "available: modelNames must return a collection")
ASSERT:C1129($aikit.client()#Null:C1517; "available: client() must return a client")

//MARK:- missing / outdated
var $mode : Text
For each ($mode; ["missing"; "outdated"])

	$aikit._simulate:=$mode

	ASSERT:C1129(Not:C34($aikit.isAvailable); $mode+": isAvailable must be False")
	ASSERT:C1129(Length:C16($aikit.missingReason)>0; $mode+": missingReason must explain why")
	ASSERT:C1129($aikit.modelAliases().length=0; $mode+": modelAliases must be empty, not fail")
	ASSERT:C1129($aikit.modelNames().length=0; $mode+": modelNames must be empty, not fail")

	// client() throws a clear, flagged error instead of a raw "null object" one
	$error:=Null:C1517
	Try
		$aikit.client()
	Catch
		$error:=Last errors:C1799[0]
	End try
	Try(1)  // Clears Last errors: the throw was expected
	ASSERT:C1129($error#Null:C1517; $mode+": client() must throw")
	ASSERT:C1129(($error#Null:C1517) && ($error.message=$aikit.missingReason); $mode+": client() must throw missingReason")

	// Definition.validate reports the reason on the model, not "model not defined"
	$def:=cs:C1710.Definition.new("_Students"; "student_vector_1"; "embed"; "{firstName}")
	$result:=$def.validate(Null:C1517)
	ASSERT:C1129(Not:C34($result.success); $mode+": a definition must not validate without AIKit")
	ASSERT:C1129($result.errors.query("field = :1 AND message = :2"; "modelAlias"; $aikit.missingReason).length=1; \
		$mode+": validate must report missingReason on modelAlias")

	// Building an Embedder never fails; the first call throws
	$embedder:=Null:C1517
	$embedder:=cs:C1710.Embedder.new()
	ASSERT:C1129($embedder#Null:C1517; $mode+": building an Embedder must not fail")

	$error:=Null:C1517
	Try
		$embedder.embed("hello"; "embed")
	Catch
		$error:=Last errors:C1799[0]
	End try
	Try(1)  // Clears Last errors: the throw was expected
	ASSERT:C1129(($error#Null:C1517) && ($error.message=$aikit.missingReason); $mode+": embed() must throw missingReason")

End for each

//MARK:- an injected client is used as is, AIKit or not
$aikit._simulate:="missing"
$embedder:=cs:C1710.Embedder.new({client: cs:C1710._TestAIKitClient.new({})})
ASSERT:C1129(OB Instance of:C1731($embedder.client; cs:C1710._TestAIKitClient); "an injected client must be kept")

$aikit._simulate:=""
