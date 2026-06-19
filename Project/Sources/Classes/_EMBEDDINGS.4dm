property settings : cs:C1710.Settings
property catalog : cs:C1710.DataStore:=ds:C1482  // Always use the host project datastore
property items : Collection

// Main list
property list:="list"
property currentItem : Object
property itemPosition : Integer
property selectedItems : Collection

// Details panel
property _detailFields:=[\
"phrase"; \
"models"; \
"autoInvalidate"; \
"more"]

property modelsDropdown : Object
property _cache : Object  // Current catalog cache

// ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___ --- ___
Class constructor
	
	This:C1470.read()
	
	If (Storage:C1525.studio=Null:C1517)
		
		Use (Storage:C1525)
			
			Storage:C1525.studio:=New shared object:C1526(\
				"EMBEDDINGS"; 0; \
				"MODELS"; 0)
			
		End use 
	End if 
	
	This:C1470._cacheCatalog()
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function read()
	
	This:C1470.settings:=cs:C1710.Settings.new()
	This:C1470.readEmbeddingItems()
	
	// MARK:- [MANAGERS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function manager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.objectName=Null:C1517)
		
		Case of 
				
				// ________________________________________________________________________________
			: ($e.code=On Load:K2:1)
				
				Use (Storage:C1525.studio)
					
					Storage:C1525.studio["EMBEDDINGS"]:=Current form window:C827
					
				End use 
				
				SET TIMER:C645(-1)
				
				This:C1470.modelsDropdownManager($e)
				
				OBJECT SET FORMAT:C236(*; "Header1"; "path:/.PRODUCT_RESOURCES/Images/ObjectIcons/Icon_600.png")
				// TODO: Use the new vector icon when ready
				OBJECT SET FORMAT:C236(*; "Header2"; "path:/.PRODUCT_RESOURCES/Images/StructureEditor/Field_14.png")
				
				// ______________________________________________________
			: ($e.code=On Activate:K2:9)
				
				This:C1470.catalog:=ds:C1482
				
				If (Length:C16(OBJECT Get name:C1087(Object with focus:K67:3))=0)
					
					GOTO OBJECT:C206(*; This:C1470.list)
					
				End if 
				
				// The list of models may have been modified
				This:C1470.modelsDropdownManager($e)
				This:C1470.modelUpdateDropdown()
				
				// TODO: Visual indicator
				CALL FORM:C1391(Current form window:C827; Formula:C1597(Form:C1466.refresh()))
				
				// ______________________________________________________
			: ($e.code=On Timer:K2:25)
				
				SET TIMER:C645(0)
				
				// ______________________________________________________
			: ($e.code=On Unload:K2:2)
				
				Use (Storage:C1525.studio)
					
					Storage:C1525.studio["EMBEDDINGS"]:=0
					
				End use 
				
				// ________________________________________________________________________________
		End case 
		
		return 
		
	End if 
	
	If (($e.code=On Mouse Enter:K2:33)\
		 || ($e.code=On Mouse Move:K2:35)\
		 || ($e.code=On Mouse Leave:K2:34))
		
		Case of 
				
				// ______________________________________________________
			: ($e.objectName=This:C1470.list)
				
				var $me:=This:C1470.list
				var $x; $y; $button; $column; $row : Integer
				MOUSE POSITION:C468($x; $y; $button)
				LISTBOX GET CELL POSITION:C971(*; $me; $x; $y; $column; $row)
				
				If ($row>0)
					
					var $item : cs:C1710._EmbeddingItem:=Form:C1466.items[$row-1]
					OBJECT SET HELP TIP:C1181(*; $me; String:C10($item.helptip))
					
				Else 
					
					OBJECT SET HELP TIP:C1181(*; $me; "")
					
				End if 
				
				// ______________________________________________________
			: ($e.objectName="phrase")
				
				This:C1470.phraseManager($e)
				
				// ______________________________________________________
		End case 
		
		return 
		
	End if 
	
	Case of 
			
			//______________________________________________________
		: ($e.objectName=This:C1470.list)
			
			This:C1470.listManager($e)
			
			//______________________________________________________
		: ($e.objectName="phrase")
			
			This:C1470.phraseManager($e)
			
			//______________________________________________________
		: ($e.objectName="more")
			
			This:C1470.moreManager($e)
			
			//______________________________________________________
		: ($e.objectName="models")
			
			This:C1470.modelsDropdownManager($e)
			
			//______________________________________________________
		: ($e.objectName="autoInvalidate")
			
			This:C1470.autoInvalidateManager($e)
			
			//______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
	// Hide/show details based on selection
Function updateUI() : Boolean
	
	var $t : Text
	
	If (This:C1470.currentItem=Null:C1517)
		
		For each ($t; This:C1470._detailFields)
			
			OBJECT SET VISIBLE:C603(*; $t; False:C215)
			OBJECT SET VISIBLE:C603(*; $t+".label"; False:C215)
			
		End for each 
		
		return 
		
	End if 
	
	For each ($t; This:C1470._detailFields)
		
		OBJECT SET VISIBLE:C603(*; $t; True:C214)
		OBJECT SET VISIBLE:C603(*; $t+".label"; True:C214)
		
	End for each 
	
	return True:C214
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If (This:C1470.updateUI())
		
		This:C1470.modelUpdateDropdown(This:C1470.currentItem)
		
	Else 
		
		This:C1470.items:=This:C1470.items  // ‼️ If no item is selected, we must force a refresh for listMetaInfo to apply
		
	End if 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function listMetaInfo($me : cs:C1710._EmbeddingItem) : Object
	
	var $meta:={}
	
	If ($me.defined)
		
		$meta.fontWeight:="bold"
		
		If ($me#This:C1470.currentItem)
			
			If ($me.errors.length>0)
				
				$meta.stroke:=_errorColor
				
			End if 
		End if 
	End if 
	
	return $meta
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function moreManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	var $item : cs:C1710._EmbeddingItem:=This:C1470.currentItem
	var $menu:=cs:C1710._menu.new()
	
	If (OBJECT Get name:C1087(Object with focus:K67:3)="phrase")
		
		$menu.edit(True:C214).line()
		This:C1470._embeddedAttributesMenu($item; $menu)
		
	End if 
	
	If (This:C1470.settings._isDev)
		var $workerBusy : Boolean:=(Process number:C372("EmbeddingStudio")>0)
		$menu.append("🚧 Insert All Attributes"; "insertAllAttributes")
		$menu.append("🚧 AI Generated Phrase"; "aiGeneratedPhrase")
		$menu.line().append($workerBusy ? "⏳ Compute Vectors" : "🚧 Compute Vectors"; "computeVectors").enable(Not:C34($workerBusy))
		$menu.append($workerBusy ? "⏳ Invalid Vectors" : "🚧 Invalid Vectors"; "invalidVectors").enable(Not:C34($workerBusy))
		$menu.append($workerBusy ? "⏳ Stat Vectors" : "🚧 Stat Vectors"; "statVectors").enable(Not:C34($workerBusy))
		$menu.line().append($workerBusy ? "⏳ Compute All Vectors" : "🚧 Compute All Vectors"; "computeAllVectors").enable(Not:C34($workerBusy))
		$menu.append($workerBusy ? "⏳ Invalid All Vectors" : "🚧 Invalid All Vectors"; "invalidAllVectors").enable(Not:C34($workerBusy))
		$menu.append($workerBusy ? "⏳ Stat All Vectors" : "🚧 Stat All Vectors"; "statAllVectors").enable(Not:C34($workerBusy))
		var $modelAliases : Collection:=This:C1470._getModelDropdownValues()
		If ($modelAliases.length>0)
			var $allSameModel : Text
			var $defs : Collection:=This:C1470.settings.definitions
			If (($defs.length>0) && ($defs.distinct("modelAlias").length=1))
				$allSameModel:=String:C10($defs[0].modelAlias)
			End if 
			var $modelSubmenu:=cs:C1710._menu.new("no-localization")
			var $alias : Text
			For each ($alias; $modelAliases)
				$modelSubmenu.append($alias; "setAllModels:"+$alias; ($alias=$allSameModel))
			End for each 
			$menu.append("🚧 Set All Vectors To"; $modelSubmenu)
		End if 
		$menu.line().append("🚧 Open AI Setting"; "openAISetting")
		$menu.append("🚧 Open Setting File"; "openSettingFile")
		$menu.append("🚧 Open Execution Log"; "openExecutionLog")
		var $phraseOpts : Object:=This:C1470.settings.phrase
		var $phraseSubmenu:=cs:C1710._menu.new("no-localization")
		$phraseSubmenu.append("Allow Relations"; "phraseOption:allowRelations"; Bool:C1537($phraseOpts.allowRelations))
		$phraseSubmenu.append("Allow Calculated"; "phraseOption:allowCalculated"; Bool:C1537($phraseOpts.allowCalculated))
		$phraseSubmenu.append("Allow Alias"; "phraseOption:allowAlias"; Bool:C1537($phraseOpts.allowAlias))
		$phraseSubmenu.append("Allow Object"; "phraseOption:allowObject"; Bool:C1537($phraseOpts.allowObject))
		$menu.append("🚧 Phrase Settings"; $phraseSubmenu)
		var $diagEnabled : Integer:=Get database parameter:C643(Diagnostic log recording:K37:69)
		$menu.line().append("🚧 Toggle Diagnostic Log"; "toggleDiagnosticLogRecording"; ($diagEnabled=1))
		var $diagLevel : Integer:=Get database parameter:C643(Diagnostic log level:K37:108)
		var $levelSubmenu:=cs:C1710._menu.new("no-localization")
		var $levelNames:=["Trace"; "Debug"; "Info"; "Warning"; "Error"]
		var $levelConsts:=[Log trace:K37:109; Log debug:K37:110; Log info:K37:111; Log warn:K37:112; Log error:K37:113]
		var $i : Integer
		For ($i; 0; $levelNames.length-1)
			$levelSubmenu.append($levelNames[$i]; "diagLevel:"+String:C10($levelConsts[$i]); ($diagLevel=$levelConsts[$i]))
		End for 
		$menu.append("🚧 Diagnostic Log Level"; $levelSubmenu)
		$menu.append("🚧 Open Diagnostic Log"; "openDiagosticLog")
		Case of 
			: (Not:C34($item.hasDirtyAssociatedAttribute()))
				$menu.line().append("🚧 Create dirty attribute"; "createDirtyAttribute")
			: (Not:C34($item.dirtyAssociatedAttributeIndexed()))
				$menu.line().append("🚧 Create index dirty attribute"; "createDirtyAttributeIndex")
		End case 
	End if 
	
	Case of 
			
			// ______________________________________________________
		: (Not:C34($menu.popup().selected))
			
			// <NOTHING MORE TO DO>
			
			// ______________________________________________________
		: (Position:C15("{"; $menu.choice)=1)  // Attribute to insert into the descriptive phrase
			
			This:C1470.insertInput($item; $menu.choice)
			This:C1470.saveEmbeddingItems()
			This:C1470._promptInvalidate($item)
			
			// ______________________________________________________
		: ($menu.choice="openAISetting")
			OPEN SETTINGS WINDOW:C903("/Database/AI")
			// ______________________________________________________
		: ($menu.choice="openSettingFile")
			OPEN URL:C673(This:C1470.settings.file.platformPath)
			// ______________________________________________________
		: ($menu.choice="openExecutionLog")
			var $execFile : 4D:C1709.File:=cs:C1710._ExecutionLog.me._file()
			If ($execFile.exists)
				OPEN URL:C673($execFile.platformPath)
			Else 
				ALERT:C41("No execution log file found.")
			End if 
			// ______________________________________________________
		: ($menu.choice="insertAllAttributes")
			var $plainText:=$item.supportedAttributes.map(Formula:C1597($1.value.name+"={"+$1.value.name+"}")).join(",")
			$item.definition.phrase:=cs:C1710.Phrase.new($plainText)
			$item.phrase:=$item.parsePhrase($item.definition.phrase)
			This:C1470.saveEmbeddingItems()
			// ______________________________________________________
		: ($menu.choice="aiGeneratedPhrase")
			$plainText:=$item.supportedAttributes.map(Formula:C1597($1.value.name)).join(",")
			var $model:="StudioPhrase"
			If (Not:C34(cs:C1710.AIKit.OpenAIProviders.new().modelAliases().extract("name").includes($model)))
				ALERT:C41("You must configure a chat model with name: "+$model)
				return 
			End if 
			var $client : cs:C1710.AIKit.OpenAI:=cs:C1710.AIKit.OpenAI.new()
			var $prompt:="You are an assistant that generates natural-language phrases for embedding database rows."
			$prompt+="Your task : "
			$prompt+="- Convert a list of fields into ONE short, natural sentence."
			$prompt+="- Use all provided fields as template variables(e.g.{firstName})."
			$prompt+="- The sentence must sound natural when variables are replaced with real values."
			$prompt+="- Do NOT describe fields(no \"first name and last name\")."
			$prompt+="- Do NOT list fields with commas unless it sounds natural."
			$prompt+="- Prefer human-like phrasing(as if describing a real entity)."
			$prompt+="- Include the table meaning(e.g.\"student\",\"product\") naturally."
			$prompt+=""
			$prompt+="Rules : "
			$prompt+="- Output ONLY the final sentence."
			$prompt+="- No explanations."
			$prompt+="- No extra formatting."
			$prompt+="- Exclude ID."
			var $messages:=[{role: "system"; content: $prompt}; {role: "user"; content: $plainText+"\n"+"table="+$item.definition.dataclassName}]
			var $resultAI:=$client.chat.completions.create($messages; {model: $model})
			If ($resultAI.success)
				$plainText:=$resultAI.choice.message.text
				$item.definition.phrase:=cs:C1710.Phrase.new($plainText)
				$item.phrase:=$item.parsePhrase($item.definition.phrase)
				This:C1470.saveEmbeddingItems()
			Else 
				ALERT:C41(JSON Stringify:C1217($resultAI))
			End if 
			// ______________________________________________________
		: ($menu.choice="computeVectors")
			CALL WORKER:C1389("EmbeddingStudio"; Formula:C1597(_runInWorker($1; $2)); Formula:C1597(_computeVectors($1)); $item.definition)
			// ______________________________________________________
		: ($menu.choice="invalidVectors")
			CALL WORKER:C1389("EmbeddingStudio"; Formula:C1597(_runInWorker($1; $2)); Formula:C1597(_invalidateVectors($1)); $item.definition)
			// ______________________________________________________
		: ($menu.choice="computeAllVectors")
			CALL WORKER:C1389("EmbeddingStudio"; Formula:C1597(_runInWorker($1)); Formula:C1597(_computeVectors))
			// ______________________________________________________
		: ($menu.choice="invalidAllVectors")
			CALL WORKER:C1389("EmbeddingStudio"; Formula:C1597(_runInWorker($1)); Formula:C1597(_invalidateVectors))
			// ______________________________________________________
		: ($menu.choice="statVectors")
			CALL WORKER:C1389("EmbeddingStudio"; Formula:C1597(_runInWorker($1; $2)); Formula:C1597(_statVectors($1)); $item.definition)
			// ______________________________________________________
		: ($menu.choice="statAllVectors")
			CALL WORKER:C1389("EmbeddingStudio"; Formula:C1597(_runInWorker($1)); Formula:C1597(_statVectors))
			// ______________________________________________________
		: (Position:C15("setAllModels:"; $menu.choice)=1)
			var $chosenAlias : Text:=Substring:C12($menu.choice; Length:C16("setAllModels:")+1)
			var $def : cs:C1710.Definition
			For each ($def; This:C1470.settings.definitions)
				$def.modelAlias:=$chosenAlias
			End for each 
			This:C1470.settings.save()
			This:C1470.readEmbeddingItems()
			This:C1470.modelUpdateDropdown()
			// ______________________________________________________
		: (Position:C15("phraseOption:"; $menu.choice)=1)
			var $optKey : Text:=Substring:C12($menu.choice; Length:C16("phraseOption:")+1)
			This:C1470.settings.phrase[$optKey]:=Not:C34(Bool:C1537(This:C1470.settings.phrase[$optKey]))
			This:C1470.settings.save()
			// ______________________________________________________
		: ($menu.choice="toggleDiagnosticLogRecording")
			var $current : Integer:=Get database parameter:C643(Diagnostic log recording:K37:69)
			SET DATABASE PARAMETER:C642(Diagnostic log recording:K37:69; ($current=0) ? 1 : 0)
			// ______________________________________________________
		: (Position:C15("diagLevel:"; $menu.choice)=1)
			SET DATABASE PARAMETER:C642(Diagnostic log level:K37:108; Num:C11(Substring:C12($menu.choice; Length:C16("diagLevel:")+1)))
			// ______________________________________________________
		: ($menu.choice="openDiagosticLog")
			var $file:=Folder:C1567(fk logs folder:K87:17).files().filter(Formula:C1597(Position:C15("4DDiagnosticLog_"; $1.value.name)=1)).sort().first()
			If ($file=Null:C1517)
				ALERT:C41("No log")
			Else 
				OPEN URL:C673($file.platformPath)
			End if 
			// ______________________________________________________
		: ($menu.choice="createDirtyAttribute")
			$item.createDirtyAssociatedAttribute()
			// ______________________________________________________
		: ($menu.choice="createDirtyAttributeIndex")
			$item.createDirtyAssociatedAttributeIndex()
			// ______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function phraseManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	var $item : cs:C1710._EmbeddingItem:=This:C1470.currentItem
	var $me:="phrase"
	var $plainText:=ST Get plain text:C1092(*; $me)  //Get edited text
	
	Case of 
			
			// ______________________________________________________
		: ($item=Null:C1517)
			
			return 
			
			// ______________________________________________________
		: ($e.code=On Mouse Enter:K2:33) || ($e.code=On Mouse Move:K2:35)
			
			OBJECT SET HELP TIP:C1181(*; $me; String:C10($item.helptip))
			
			// ______________________________________________________
		: ($e.code=On Mouse Leave:K2:34)
			
			OBJECT SET HELP TIP:C1181(*; $me; "")
			
			// ______________________________________________________
		: ($e.code=On Clicked:K2:4)
			
			If (Not:C34(Contextual click:C713))
				
				return 
				
			End if 
			
			var $menu:=cs:C1710._menu.new().edit(True:C214).line()
			This:C1470._embeddedAttributesMenu($item; $menu)
			
			If (Not:C34($menu.popup().selected))
				
				return 
				
			End if 
			
			// 📌 Ignored if an associated action (for edit items)
			This:C1470.insertInput($item; $menu.choice)
			
			// XXX: maybe launch on times this:
			This:C1470.saveEmbeddingItems()
			This:C1470._promptInvalidate($item)  // XXX: maybe too aggressive, ask if go out? (but if never? do not saveEmbeddingItems?)
			
			// ______________________________________________________
		: ($e.code=On Before Keystroke:K2:6)
			
			var $char:=Keystroke:C390
			
			If (["<"; ">"; "&"].includes($char))
				
				// Special characters that must be encoded in styled text
				FILTER KEYSTROKE:C389("")
				GET HIGHLIGHT:C209(*; $me; $startSel; $endSel)
				ST SET TEXT:C1115(*; $me; $char; $startSel; $endSel)
				
			End if 
			
			// ______________________________________________________
		: ($e.code=On After Edit:K2:43)
			
			// Highlight any errors, if any
			$item.phrase:=$item.parsePhrase(cs:C1710.Phrase.new($plainText))
			
			Form:C1466.items:=Form:C1466.items  // update UI
			
			// ______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			$item.definition.phrase:=cs:C1710.Phrase.new($plainText)
			$item.version+=1
			
			// Re-validate phrase + model and refresh styled text
			$item.validate()
			ST SET TEXT:C1115(*; $me; $item.phrase; ST Start text:K78:15; ST End text:K78:16)
			
			This:C1470.saveEmbeddingItems()
			This:C1470._promptInvalidate($item)
			
			Form:C1466.items:=Form:C1466.items  // update UI
			
			// ______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelsDropdownManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	Case of 
			
			//______________________________________________________
		: ($e.code=On Load:K2:1)  // Define dropdown
			
			var $dropDown:={\
				values: This:C1470._getModelDropdownValues(); \
				index: -1; \
				placeholder: Localized string:C991("selectAModel")}
			
			$dropDown.currentValue:=$dropDown.placeholder
			This:C1470.modelsDropdown:=$dropDown
			
			//______________________________________________________
		: ($e.code=On Activate:K2:9)  // Update model list if any
			
			This:C1470.modelsDropdown.values:=This:C1470._getModelDropdownValues()
			
			//______________________________________________________
		: ($e.code=On Data Change:K2:15)
			
			$dropDown:=This:C1470.modelsDropdown
			
			If ($dropDown.currentValue=Localized string:C991("createAModel"))
				
				// FIXME: Set the appropriate selector for the models page when the command is updated
				OPEN SETTINGS WINDOW:C903("/Database/AI")
				
				return 
				
			End if 
			
			// Update current item
			This:C1470.currentItem.definition.modelAlias:=$dropDown.currentValue
			This:C1470.currentItem.version+=1
			This:C1470.currentItem.validate()  // refresh _modelErrors
			This:C1470.saveEmbeddingItems()
			This:C1470._promptInvalidate(This:C1470.currentItem)
			
			Form:C1466.items:=Form:C1466.items  // update UI
			
			//______________________________________________________
	End case 
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function autoInvalidateManager($e : Object)
	
	$e:=$e || FORM Event:C1606
	
	If ($e.code#On Clicked:K2:4)\
		 || (This:C1470.currentItem=Null:C1517)
		
		return 
		
	End if 
	
	This:C1470.currentItem.version+=1
	This:C1470.saveEmbeddingItems()
	
	Form:C1466.items:=Form:C1466.items  // Update UI
	
	// MARK: -
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function insertInput($item : cs:C1710._EmbeddingItem; $input : Text)
	
	var $me:="phrase"
	var $plainText:=ST Get plain text:C1092(*; $me)  //Get edited text
	
	var $startSel; $endSel : Integer
	GET HIGHLIGHT:C209(*; $me; $startSel; $endSel)
	
	If (Length:C16($plainText)=0)
		
		var $newValue:="<span>"+$input+"</span>"
		
	Else 
		
		$newValue:=Substring:C12($plainText; 1; $startSel-1)+$input+Substring:C12($plainText; $endSel)
		
	End if 
	
	OBJECT SET VALUE:C1742($me; $newValue)
	
	$endSel:=$startSel+Length:C16($input)
	HIGHLIGHT TEXT:C210(*; $me; $endSel; $endSel)
	
	// Highlight any errors, if any
	$item.definition.phrase:=cs:C1710.Phrase.new(ST Get plain text:C1092($newValue))
	$item.phrase:=$item.parsePhrase($item.definition.phrase)
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function modelUpdateDropdown($item : cs:C1710._EmbeddingItem)
	
	$item:=$item || This:C1470.currentItem
	
	If ($item=Null:C1517)
		
		return 
		
	End if 
	
	var $dropDown : Object:=This:C1470.modelsDropdown
	var $model : Text:=$item.definition.modelAlias
	
	If ($dropDown.values.includes($model))
		
		$dropDown.index:=$dropDown.values.indexOf($model)
		
	Else 
		
		$dropDown.index:=-1
		OBJECT SET RGB COLORS:C628(*; "models"; Length:C16(String:C10($model))>0 ? _errorColor : Foreground color:K23:1)
		
	End if 
	
	$dropDown.placeholder:=$dropDown.values.length>2 ? Localized string:C991("selectAModel") : Localized string:C991("createAModel")
	$dropDown.currentValue:=$model || $dropDown.placeholder
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function refresh()
	
	This:C1470.readEmbeddingItems()
	
	If (This:C1470._catalogModified())
		
		This:C1470._cacheCatalog()  // Update cache
		This:C1470.readEmbeddingItems()  // Update list
		
	End if 
	
	// MARK: Update list
	var $current:=This:C1470.currentItem
	
	If ($current#Null:C1517)  // Restore selection
		
		var $c:=This:C1470.items.indices("definition.dataclassName = :1 & definition.vectorName = :2"; $current.definition.dataclassName; $current.definition.vectorName)
		
		If ($c.length>0)
			
			LISTBOX SELECT ROW:C912(*; This:C1470.list; $c[0]+1)
			This:C1470.currentItem:=This:C1470.items[$c[0]]
			
		Else 
			
			LISTBOX SELECT ROW:C912(*; This:C1470.list; 0; lk remove from selection:K53:3)  // Deselect
			This:C1470.currentItem:=Null:C1517
			
		End if 
		
		This:C1470.listManager()
		
	End if 
	
	This:C1470.modelsDropdown.values:=This:C1470._getModelDropdownValues()
	This:C1470.modelUpdateDropdown(This:C1470.currentItem)
	
	// MARK:- [ITEMS]
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function readEmbeddingItems() : Collection
	
/* #17301
Get the possible vector fields in the current catalog
The list is displayed with:
• table/dataclass
• vector field
Enriched with saved Definition entries from Settings/vectors.json.
*/
	If (This:C1470.settings=Null:C1517)
		
		This:C1470.settings:=cs:C1710.Settings.new()
		
	Else 
		
		This:C1470.settings.load()
		
	End if 
	
	var $items:=[]
	var $vf : Object
	
	For each ($vf; This:C1470._collectVectorFields())
		
		var $def : cs:C1710.Definition:=This:C1470.settings.find($vf.dataclassName; $vf.field.name)
		var $wasSaved : Boolean:=$def#Null:C1517
		
		If (Not:C34($wasSaved))
			
			$def:=cs:C1710.Definition.new($vf.dataclassName; $vf.field.name; ""; "")
			
		End if 
		
		var $item : cs:C1710._EmbeddingItem:=cs:C1710._EmbeddingItem.new($vf.dataclass; $def; This:C1470.settings)
		
		If ($wasSaved)
			
			$item.version:=0
			$item.validate()  // Refreshes styled phrase + _phraseErrors + _modelErrors
			
		End if 
		
		$items.push($item)
		
	End for each 
	
	// Ghost entries: saved definitions that no longer match any catalog vector field.
	var $saved : cs:C1710.Definition
	
	For each ($saved; This:C1470.settings.definitions)
		
		If ($items.query("definition.dataclassName = :1 & definition.vectorName = :2"; $saved.dataclassName; $saved.vectorName).length>0)
			
			continue
			
		End if 
		
		var $ghost : Object:={\
			definition: $saved; \
			errors: []; \
			helptip: ""}
		
		Case of 
				
				// ______________________________________________________
			: (This:C1470.catalog[$saved.dataclassName]=Null:C1517)
				
				$ghost.errors.push(Replace string:C233(Localized string:C991("missingDataclass"); "{dataclass}"; $saved.dataclassName))
				
				// ______________________________________________________
			: (This:C1470.catalog[$saved.dataclassName][$saved.vectorName]=Null:C1517)
				
				$ghost.errors.push(Replace string:C233(Replace string:C233(Localized string:C991("missingVector"); "{attribute}"; $saved.vectorName); "{dataclass}"; $saved.dataclassName))
				
				// ______________________________________________________
			: (String:C10(This:C1470.catalog[$saved.dataclassName][$saved.vectorName].classID)#"4D.Vector")
				
				$ghost.errors.push(Replace string:C233(Replace string:C233(Localized string:C991("attributeIsNotAVector"); "{attribute}"; $saved.vectorName); "{dataclass}"; $saved.dataclassName))
				
				// ______________________________________________________
		End case 
		
		$ghost.helptip:=$ghost.errors.join("\r")
		
		$items.push($ghost)
		
	End for each 
	
	This:C1470.items:=$items.orderBy("definition.dataclassName asc, definition.vectorName asc")
	
	// === === === === === === === === === === === === === === === === === === === === === === === === === === ===
Function saveEmbeddingItems()
	
	// Keep only defined items
	This:C1470.settings.definitions:=This:C1470.items\
		.filter(Formula:C1597(Bool:C1537($1.value.defined)))\
		.map(Formula:C1597($1.value.definition))
	
	This:C1470.settings.save()
	
	// MARK: -[PRIVATE]
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Compares current phrase/model against the snapshot taken at load time.
	// If either changed, prompts the developer and calls invalidateVectors() on confirmation.
Function _promptInvalidate($item : cs:C1710._EmbeddingItem)
	
	If (($item=Null:C1517)\
		 || ($item.original=Null:C1517))
		
		return 
		
	End if 
	
	var $orig : Object:=$item.original
	var $changed : Boolean:=\
		(String:C10($item.definition.phrase.template)#String:C10($orig.phrase))\
		 || (String:C10($item.definition.modelAlias)#String:C10($orig.modelAlias))
	
	If (Not:C34($changed))\
		 || (Not:C34($item.definition._hasVectorComputed()))
		
		return 
		
	End if 
	
	// Update snapshot so a subsequent save won't re-prompt for the same delta
	$item.original:=$item.definition.toObject()
	
	// TODO: To localize
	CONFIRM:C162(\
		"The definition for "+$item.definition.dataclassName+"."+$item.definition.vectorName+" has changed.\rDo you want to mark all existing vectors for recalculation?"; \
		"Recalculate"; \
		"Skip")  // TODO: localize
	
	If (Bool:C1537(OK))
		
		$item.definition.invalidateVectors()
		
	End if 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _cacheCatalog()
	
	This:C1470._cache:={}
	
	var $dataclass; $attribute : Text
	For each ($dataclass; This:C1470.catalog)
		
		This:C1470._cache[$dataclass]:={}
		
		For each ($attribute; This:C1470.catalog[$dataclass])
			
			This:C1470._cache[$dataclass][$attribute]:=True:C214
			
		End for each 
	End for each 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _catalogModified() : Boolean
	
	This:C1470.catalog:=ds:C1482
	
	var $dataclass; $attribute : Text
	For each ($dataclass; This:C1470._cache)
		
		If (This:C1470.catalog[$dataclass]=Null:C1517)
			
			return True:C214
			
		End if 
		
		For each ($attribute; This:C1470._cache[$dataclass])
			
			If (This:C1470.catalog[$dataclass][$attribute]=Null:C1517)
				
				return True:C214
				
			End if 
		End for each 
	End for each 
	
	For each ($dataclass; This:C1470.catalog)
		
		If (This:C1470._cache[$dataclass]=Null:C1517)
			
			return True:C214
			
		End if 
		
		For each ($attribute; This:C1470.catalog[$dataclass])
			
			If (This:C1470._cache[$dataclass][$attribute]=Null:C1517)
				
				return True:C214
				
			End if 
		End for each 
	End for each 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
	// Returns a flat list of catalog vector fields: [{dataclass, dataclassName, field}]
Function _collectVectorFields() : Collection
	
	var $fields:=[]
	var $tableName; $fieldName : Text
	
	For each ($tableName; This:C1470.catalog)
		
		var $dataclass : 4D:C1709.DataClass:=This:C1470.catalog[$tableName]
		
		For each ($fieldName; $dataclass)
			
			var $field : Object:=$dataclass[$fieldName]
			
			If (String:C10($field.classID)="4D.Vector")
				
				$fields.push({\
					dataclass: $dataclass; \
					dataclassName: $dataclass.getInfo().name; \
					field: $field})
				
			End if 
		End for each 
	End for each 
	
	return $fields
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _getModelDropdownValues() : Collection
	
	// return cs.AIKit.OpenAIProviders.new().modelAliases().extract("name")
	var $models : Collection:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases().extract("name")
	$models.push("-")
	$models.push(Localized string:C991("createAModel"))
	
	return $models
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _embeddedAttributesMenu($item : cs:C1710._EmbeddingItem; $menu : cs:C1710._menu)
	
	var $embed:=$item.inputsMenu
	
	If ($embed.itemCount()>0)
		
		$menu.append(":xliff:embed"; $embed).icon("|Images/ObjectIcons/Icon_455.png")
		
	Else 
		
		$embed.release()
		
	End if 
	
	// *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** *** ***
Function _popError($message : Text; $widget : Text; $target : Text)
	
	BEEP:C151
	ALERT:C41($message)
	
	If (Length:C16($target)>0)
		
		var $o : Object:=OBJECT Get value:C1743($widget)
		$o.target:=$target
		OBJECT SET VALUE:C1742($widget; $o)
		
	End if 
	