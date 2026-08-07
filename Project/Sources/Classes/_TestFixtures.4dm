// Shared test setup helpers for the Process/Embedder test suite.
// Extracts the two blocks that used to be copy-pasted into every test method:
//   - ensureAliases() : the test-only model-alias bootstrap into AIProviders.json
//   - seedStudents()  : the deterministic Cities/School/_Students fixture set
//
// Usage:
//   var $fx:=cs._TestFixtures.me
//   If (Not(Asserted($fx.ensureAliases(["embed"; "badembed"]); "...")))
//     return
//   End if
//   var $seed:=$fx.seedStudents(3)  // -> {city; school; students: [<3 entities>]}

// Known test aliases -> real (or intentionally-invalid) provider model names.
property _knownModels : Object:={embed: "text-embedding-3-small"; badembed: "badmodel"; badembed2: "badmodel2"}

// Deterministic student names (index order is stable across runs).
property _names : Collection:=[\
{first: "Alice"; last: "Durand"}; \
{first: "Bob"; last: "Martin"}; \
{first: "Chloe"; last: "Bernard"}; \
{first: "David"; last: "Blanc"}; \
{first: "Emma"; last: "Leroy"}; \
{first: "Frank"; last: "Moreau"}]

singleton Class constructor
	// stateless
	
	// Ensure every requested model alias exists (test-only bootstrap, mock mode).
	// Returns True when all requested aliases resolve after the bootstrap.
Function ensureAliases($names : Collection) : Boolean
	$names:=$names || []
	
	var $aliases : Collection:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	var $name : Text
	
	If (Not:C34(This:C1470._allPresent($aliases; $names)))
		var $file : 4D:C1709.File:=Folder:C1567(fk database folder:K87:14).file("Project/Sources/AIProviders.json")
		var $data : Object:=($file.exists) ? JSON Parse:C1218($file.getText()) : {providers: {}; models: {}}
		
		If ($data.providers["openai"]=Null:C1517)
			$data.providers["openai"]:={}
		End if 
		For each ($name; $names)
			If ($data.models[$name]=Null:C1517)
				$data.models[$name]:={model: (String:C10(This:C1470._knownModels[$name]) || $name); provider: "openai"}
			End if 
		End for each 
		$file.setText(JSON Stringify:C1217($data; *))
		
		$aliases:=cs:C1710.AIKit.OpenAIProviders.new().modelAliases()
	End if 
	
	return This:C1470._allPresent($aliases; $names)
	
Function _allPresent($aliases : Collection; $names : Collection) : Boolean
	var $name : Text
	For each ($name; $names)
		If ($aliases.filter(Formula:C1597($1.value.name=$2); $name).first()=Null:C1517)
			return False:C215
		End if 
	End for each 
	return True:C214
	
	// Drop and re-create a deterministic fixture set: 1 city (Paris), 1 school
	// (Sorbonne) and $count students. Returns {city; school; students}.
Function seedStudents($count : Integer) : Object
	If (($count=Null:C1517) || ($count<=0))
		$count:=1
	End if 
	
	ds:C1482.Cities.all().drop()
	ds:C1482.School.all().drop()
	ds:C1482._Students.all().drop()
	
	var $city:=ds:C1482.Cities.new()
	$city.name:="Paris"
	$city.state:="Ile-de-France"
	ASSERT:C1129($city.save().success; "seedStudents: failed to save city")
	
	var $school:=ds:C1482.School.new()
	$school.name:="Sorbonne"
	$school.university:="Paris University"
	$school.city_ID:=$city.ID
	ASSERT:C1129($school.save().success; "seedStudents: failed to save school")
	
	var $students : Collection:=[]
	var $i : Integer
	For ($i; 1; $count)
		var $n : Object:=This:C1470._names[($i-1)%This:C1470._names.length]
		var $student:=ds:C1482._Students.new()
		$student.firstName:=$n.first
		$student.lastName:=$n.last
		$student.school_ID:=$school.ID
		ASSERT:C1129($student.save().success; "seedStudents: failed to save student "+String:C10($i))
		$students.push($student)
	End for 
	
	return {city: $city; school: $school; students: $students}
	