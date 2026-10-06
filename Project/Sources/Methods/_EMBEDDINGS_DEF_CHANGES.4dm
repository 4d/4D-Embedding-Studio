//%attributes = {"invisible":true,"shared":true}
// _EMBEDDINGS_DEF_CHANGES
// ----------------------------------------------------------------------------
// Called after the user edited the AI model aliases, to keep stored embeddings
// consistent with the model they were computed from.
//
// It compares the alias configuration before and after the edit, detects the
// embedding definitions whose resolved model (provider + model) actually
// changed AND that already hold computed vectors, then asks the user whether to
// invalidate them so they get recomputed on the next run.
//
// $before / $after : alias configuration. Either a plain alias map
//                    { aliasName: { provider; model } } or a full settings
//                    object { providers; models } (in which case .models is used).
// $result          : optional object, filled by reference with
//                    { affected; invalidated; skipped; confirmed; errors }.
#DECLARE($before : Object; $after : Object; $result : Object)

// MARK:- Normalize inputs to alias maps
var $beforeModels : Object:=(($before#Null:C1517) && (Value type:C1509($before.models)=Is object:K8:27)) ? $before.models : $before
var $afterModels : Object:=(($after#Null:C1517) && (Value type:C1509($after.models)=Is object:K8:27)) ? $after.models : $after
$beforeModels:=$beforeModels || {}
$afterModels:=$afterModels || {}

// MARK:- Find impacted definitions (resolved model changed + data present)
var $settings : cs:C1710.Settings:=cs:C1710.Settings.new()
var $affected : Collection:=$settings._affectedByAliasChange($beforeModels; $afterModels)

var $def : cs:C1710.Definition

// MARK:- Ask the user and invalidate on confirmation
var $confirmed : Boolean:=False:C215
var $invalidated : Integer:=0
var $skipped : Integer:=0
var $errors : Collection:=[]

If ($affected.length>0)
	
	var $lines : Collection:=[]
	For each ($def; $affected)
		$lines.push("• "+$def.dataclassName+"."+$def.vectorName+" ("+$def.modelAlias+")")
	End for each 
	
	var $message : Text:=Replace string:C233(Localized string:C991("aliasChangeConfirm"); "{count}"; String:C10($affected.length))
	$message:=$message+"\n\n"+$lines.join("\n")
	
	If (cs:C1710._Dialog.me.confirm($message))
		
		$confirmed:=True:C214
		
		For each ($def; $affected)
			var $r : Object:=$def.invalidateVectors()
			$invalidated+=Num:C11($r.updated)
			$skipped+=Num:C11($r.skipped)
			$errors.combine($r.errors)
		End for each 
		
	End if 
	
End if 

// MARK:- Return the outcome to the caller (by reference)
If ($result#Null:C1517)
	$result.affected:=$affected.length
	$result.invalidated:=$invalidated
	$result.skipped:=$skipped
	$result.confirmed:=$confirmed
	$result.errors:=$errors
End if 
