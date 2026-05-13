/**
 Stateful rate-limit tracker for embedding API calls.
 Created once per processing run. Tracks remaining budget from response headers,
 provides pre-flight throttling and adaptive batch sizing.
**/

property remainingTokens : Integer:=-1
property remainingRequests : Integer:=-1
property limitTokens : Integer:=0
property resetTokensSeconds : Integer:=0
property resetRequestsSeconds : Integer:=0
property tokensPerEntity : Real:=0
property configBatchSize : Integer:=50

Class constructor($configBatchSize : Integer)

	If ($configBatchSize>0)
		This:C1470.configBatchSize:=$configBatchSize
	End if

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Update internal state from the latest API response.
Function update($embedderResult : cs:C1710.EmbedderResult; $chunkSize : Integer)

	If ($embedderResult=Null:C1517)
		return
	End if

	This:C1470.remainingTokens:=$embedderResult.remainingTokens
	This:C1470.remainingRequests:=$embedderResult.remainingRequests
	This:C1470.limitTokens:=$embedderResult.limitTokens

	This:C1470.resetTokensSeconds:=This:C1470._parseResetDuration($embedderResult.resetTokens)
	This:C1470.resetRequestsSeconds:=This:C1470._parseResetDuration($embedderResult.resetRequests)

	If (($chunkSize>0) && ($embedderResult.totalTokens>0))
		This:C1470.tokensPerEntity:=$embedderResult.totalTokens/$chunkSize
	End if

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Pre-flight throttle. Waits if the remaining budget is too low for the next batch.
Function waitIfNeeded($estimatedTokens : Integer)

	// Token budget check
	If ((This:C1470.remainingTokens>=0) && ($estimatedTokens>0))

		If (This:C1470.remainingTokens<($estimatedTokens*1.1))
			var $waitTokens : Integer:=This:C1470.resetTokensSeconds
			If ($waitTokens<1)
				$waitTokens:=1
			End if
			cs:C1710._Logger.me.info({\
				event: "Rate limiter waiting (tokens)"; \
				remainingTokens: This:C1470.remainingTokens; \
				estimatedNeed: $estimatedTokens; \
				waitSeconds: $waitTokens})
			DELAY PROCESS:C323(Current process:C322; $waitTokens*60)
		End if

	End if

	// Request budget check
	If (This:C1470.remainingRequests=0)
		var $waitRequests : Integer:=This:C1470.resetRequestsSeconds
		If ($waitRequests<1)
			$waitRequests:=1
		End if
		cs:C1710._Logger.me.info({\
			event: "Rate limiter waiting (requests)"; \
			remainingRequests: This:C1470.remainingRequests; \
			waitSeconds: $waitRequests})
		DELAY PROCESS:C323(Current process:C322; $waitRequests*60)
	End if

	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Returns the recommended batch size for the next chunk.
Function nextBatchSize() : Integer

	If ((This:C1470.remainingTokens<0) || (This:C1470.tokensPerEntity<=0))
		return This:C1470.configBatchSize
	End if

	// Use at most 80% of remaining token budget
	var $target : Integer:=Int:C8((This:C1470.remainingTokens*0.8)/This:C1470.tokensPerEntity)

	If ($target<1)
		$target:=1
	End if

	If ($target>This:C1470.configBatchSize)
		$target:=This:C1470.configBatchSize
	End if

	If ($target#This:C1470.configBatchSize)
		cs:C1710._Logger.me.info({\
			event: "Batch size adapted"; \
			nextSize: $target; \
			remainingTokens: This:C1470.remainingTokens; \
			tokensPerEntity: This:C1470.tokensPerEntity})
	End if

	return $target

	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Parses OpenAI reset duration strings ("6m0s", "1s", "200ms") into seconds.
Function _parseResetDuration($reset : Text) : Integer

	If (Length:C16($reset)=0)
		return 0
	End if

	var $seconds : Integer:=0
	var $pos : Integer:=1
	var $num : Text:=""

	While ($pos<=Length:C16($reset))
		var $c : Text:=$reset[[$pos]]
		If (($c>="0") && ($c<="9"))
			$num:=$num+$c
		Else
			If (Length:C16($num)>0)
				Case of
					: ($c="m") && ($pos<Length:C16($reset)) && ($reset[[$pos+1]]="s")
						// "ms" — milliseconds, round up to 1s minimum
						$seconds+=Int:C8((Num:C11($num)+999)/1000)
						$pos+=1
					: ($c="m")
						$seconds+=Num:C11($num)*60
					: ($c="s")
						$seconds+=Num:C11($num)
					: ($c="h")
						$seconds+=Num:C11($num)*3600
				End case
				$num:=""
			End if
		End if
		$pos+=1
	End while

	// Bare number without unit → treat as seconds
	If (Length:C16($num)>0)
		$seconds+=Num:C11($num)
	End if

	return $seconds
