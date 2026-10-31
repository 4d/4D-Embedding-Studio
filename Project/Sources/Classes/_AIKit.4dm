/**
 Guard around the 4D AIKit component (cs.AIKit).

 The studio needs 4D AIKit for every embedding call and to list the model aliases
 (cs.AIKit.OpenAIProviders, 4D 21 R3 or later). When the component is not loaded — the
 dependency was not resolved, was removed, or could not be downloaded — cs.AIKit is Null and
 any cs.AIKit.X.new() fails at runtime with a raw "null object" error. When AIKit is too old,
 cs.AIKit.OpenAIProviders is Null and fails the same way.

 Code goes through this class instead of touching cs.AIKit directly:

 | Member         | When AIKit is missing or outdated                                  |
 | -------------- | ------------------------------------------------------------------ |
 | isAvailable    | False                                                              |
 | missingReason  | localized explanation ("" when AIKit is usable)                    |
 | assert()       | throws {componentSignature: "4DES"; isAIKitMissing: True; message} |
 | client()       | throws, like assert()                                              |
 | modelAliases() | [] — the studio and Definition.validate() keep working and report  |
 | modelNames()   | [] — missingReason instead of a list of unknown models             |

 Test seam: set _simulate to "missing" or "outdated" to run those paths with AIKit loaded.
 The singleton is per process, so this only affects the test's own process.
**/

// Test seam: "" runs the real check; "missing" or "outdated" forces that result.
property _simulate : Text:=""

singleton Class constructor

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// True when 4D AIKit is loaded and recent enough for the studio.
Function get isAvailable() : Boolean

	return Length:C16(This:C1470.missingReason)=0

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Why 4D AIKit cannot be used, or "" when it can.
Function get missingReason() : Text

	Case of

		: ((This:C1470._simulate="missing") || (cs:C1710.AIKit=Null:C1517))

			return Localized string:C991("errAIKitMissing")

		: ((This:C1470._simulate="outdated") || (cs:C1710.AIKit.OpenAI=Null:C1517) || (cs:C1710.AIKit.OpenAIProviders=Null:C1517))

			return Localized string:C991("errAIKitOutdated")

	End case

	return ""

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Throws when 4D AIKit cannot be used. isCriticalAPIError makes cs.Process stop calling the
	// model for the rest of the run instead of failing once per entity.
Function assert()

	var $reason : Text:=This:C1470.missingReason

	If (Length:C16($reason)>0)

		throw:C1805({componentSignature: "4DES"; \
			isAIKitMissing: True:C214; \
			isCriticalAPIError: True:C214; \
			message: $reason})

	End if

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// A new AIKit client. Throws when 4D AIKit cannot be used.
Function client() : cs:C1710.AIKit.OpenAI

	This:C1470.assert()

	return cs:C1710.AIKit.OpenAI.new()

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// The model aliases configured for AIKit, or [] when AIKit cannot be used.
Function modelAliases() : Collection

	If (Not:C34(This:C1470.isAvailable))

		return []

	End if

	return cs:C1710.AIKit.OpenAIProviders.new().modelAliases()

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// The names of the model aliases, or [] when AIKit cannot be used.
Function modelNames() : Collection

	return This:C1470.modelAliases().extract("name")

