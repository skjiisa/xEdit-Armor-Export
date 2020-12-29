{
	Armor Stats and Requirements
	Created by Isvvc

	From selected armors, this script exports a text file with:
	* CSV list of crafting ingredients required
		* quantity, plugin name and FixedFormID, DisplayName
	* Combined armor rating
	* The armor type (of the first armor selected)
	* Calculated level based on type and rating
}

unit UserScript;

uses 'lib\mteFunctions';

var
	slCobj: TStringList;

function IndexOfStringInArray(Value: string; Strings: TStringList): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to Pred(Strings.Count) do
	if CompareText(Strings[i], Value) = 0 then begin
      Result := i;
      Exit;
    end;
end;

// Returns False if no COBJ could be found for the cnam object
function AddIngredients(slIngredients, slIngredientNames: TStringList; cnam: IInterface;): Bool;
var
	i, j, count: integer;
	itemName, itemID: string;
	ref, bnam, cobj, items, item, li: IInterface;
begin
	Result := False;

	// Go through all of the Referenced By until you find the crafting (not tempering) recipe
	for i := 0 to Pred(ReferencedByCount(cnam)) do begin
		ref := ObjectToElement(ReferencedByIndex(cnam, i));
		if (Signature(ref) = 'COBJ') and (geev(LinksTo(ElementByPath(ref, 'CNAM')), 'EDID') = geev(cnam, 'EDID')) then begin
			bnam := LinksTo(ElementByPath(ref, 'BNAM'));
			if (geev(bnam, 'EDID') = 'CraftingSmithingForge') or (geev(bnam, 'EDID') = 'CraftingTanningRack') then begin;
				cobj := ref;
				break;
			end;
		end;
	end;

	if not Assigned(cobj) then exit;
	
	// Add every crafting ingredient to the ingredients list
	items := ElementByPath(cobj, 'Items');
	for i := 0 to Pred(ElementCount(items)) do begin
		li := ElementByIndex(items, i);
		item := LinksTo(ElementByPath(li, 'CNTO\Item'));
		count := geev(li, 'CNTO - Item\Count');

		itemName := DisplayName(item);
		itemID := GetFileName(GetFile(item))+' '+copy(IntToHex(FixedFormID(item),8),3,6);
		
		// Run this function recursively on this ingredient if it's from this mod.
		if GetFileName(GetFile(item)) = GetFileName(GetFile(cnam)) then
			if AddIngredients(slIngredients, slIngredientNames, item) then
				// A recipe was found for this ingredient. Don't add this to the list.
				continue;
		
		j := IndexOfStringInArray(itemID, slIngredients);
		if j <> -1 then
			// If the list already has the ingredient, increase the count
			slIngredients.Objects[j] := TObject(count + Integer(slIngredients.Objects[j]))
		else begin
			// If the list doesn't have the ingredient yet, add item
			slIngredients.AddObject(itemID, TObject(count));
			slIngredientNames.Add(itemName);
		end;
	end;
	
	// Add perks, crafting manuals, etc. to ingredients list
	items := ElementByPath(cobj, 'Conditions');
	for i := 0 to Pred(ElementCount(items)) do begin
		li := ElementByIndex(items, i);
		
		// I wish I could use a switch statement here,
		// but Pascal only supports case on integers.
		if geev(li, 'CTDA\Function') = 'GetItemCount' then
			item := LinksTo(ElementByPath(li, 'CTDA\Inventory Object'))
		else if geev(li, 'CTDA\Function') = 'HasPerk' then
			item := LinksTo(ElementByPath(li, 'CTDA\Perk'))
		else
			item := nil;
		
		if Assigned(item) then begin
			itemName := DisplayName(item);
			itemID := GetFileName(GetFile(item))+' '+copy(IntToHex(FixedFormID(item),8),3,6);
			
			count := geev(li, 'CTDA\Comparison Value');
			// If only one item is required, set count to 0
			// to improve the way it is displayed in Character Tracker
			if count = 1 then
				count := 0;
			j := IndexOfStringInArray(itemID, slIngredients);
			if j <> -1 then begin
				// Since these items aren't consumed on use,
				// only store the largest value found.
				// Don't add them up.
				if count > Integer(slIngredients.Objects[j]) then
					slIngredients.Objects[j] := TObject(count);
			end
			else begin
				slIngredients.AddObject(itemID, TObject(count));
				slIngredientNames.Add(itemName);
			end;
		end;
	end;
	
	Result := True;
end;

procedure AddSkyrims(json: TJsonObject);
begin
	json.A['games'].Add('33839302-E5B9-4299-AA81-444BED243F20');
	json.A['games'].Add('75CFE734-1107-4B03-8269-AC130D88A8B7');
	json.A['games'].Add('C68322E4-6550-4588-B5E4-D54DF5976E7C');
end;

function FlagsConflict(sl1, sl2: TStringList): Bool;
var i: Integer;
begin
	Result := False;
	for i := 0 to Pred(sl1.Count) do
		if CompareText(sl1[i], sl2[i]) <> 0 then begin
			Result := True;
			Exit;
		end
		else if (Assigned(sl1.Objects[i])) and (Assigned(sl2.Objects[i])) then begin
			Result := True;
			Exit;
		end;
end;

function Initialize: integer;
begin
	slCobj := TStringList.Create;
end;

function Process(e: IInterface): integer;
begin
	// Add the armor's EDID and reference to the list
	slCobj.AddObject(geev(e, 'EDID'), e);
	AddMessage('    Loading '+slCobj[slCobj.Count - 1]);
end;

function Finalize: integer;
var
	i, level: integer;
	armorRating: double;
	armorTypeSet: bool;
	armorType, armorName, moduleID, modName, modID: string;
	cnam, flags: IInterface;
	slIngredients, slIngredientNames, slOutput, slCTIngredients, slFlags, slots: TStringList;
	module, modJSON, json, outputJSON: TJsonObject;
begin
	slIngredients := TStringList.Create;
	slIngredientNames := TStringList.Create;
	slOutput := TStringList.Create;
	slCTIngredients := TStringList.Create;
	slots := TStringList.Create;
	armorRating := 0;
	armorTypeSet := False;
	
	// Temporarily use Ingredients.txt to get two UUID/GUIDs from Powershell
	ShellExecute(0, nil, 'powershell', '[guid]::NewGuid().ToString() > Armor` Export\Ingredients.txt; [guid]::NewGuid().ToString() >> Armor` Export\Ingredients.txt', nil, 0);
	
	InputQuery('Armor Stats and Requirements', 'Armor Name', armorName);
	InputQuery('Character Tracker mod', 'Mod name or empty for no mod', modName);

	// Go through every armor piece
	for i := 0 to slCobj.Count - 1 do begin
		cnam := ObjectToElement(slCobj.Objects[i]);
		AddMessage('    Equipping '+slCobj[i]);
		
		// Get the Armor Addon to check its armor slots
		flags := ElementByPath(cnam, 'BOD2\First Person Flags');
		slFlags := TStringList.Create;
		slFlags.text := FlagValues(flags);
		
		if slots.Count = 0 then
			slots.text := FlagValues(ElementByPath(cnam, 'BOD2\First Person Flags'));
		
		for i := 0 to Pred(slFlags.Count) do begin
			slFlags.Objects[i] := TObject(geev(flags, slFlags[i]));
			if Assigned(slFlags.Objects[i]) then
				AddMessage('            ' + slFlags[i]);
		end;
		
		if FlagsConflict(slFlags, slots) then
			AddMessage('        Conflicts with already eqipped item. Armor rating not added.')
		else begin
			// Increase the armor rating by the amount of the resulting armor
			armorRating := armorRating + geev(cnam, 'DNAM');
			if not armorTypeSet then begin
				// The armor type and thus calculated level will be based off the first armor encountered
				armorType := geev(cnam, 'BOD2\Armor Type');
				if (armorType = 'Light Armor') or (armorType = 'Heavy Armor') then
					armorTypeSet := True
			end;
			
			for i := 0 to Pred(slFlags.Count) do
				if Assigned(slFlags.Objects[i]) then
					slots.Objects[i] := slFlags.Objects[i];
		end;
		
		slFlags.Free;
		
		AddMessage('        Adding ingredients.');
		AddIngredients(slIngredients, slIngredientNames, cnam);
	end;
	
	// These level calculations are quadratic extrapolations from the in-game leveled lists
	// based on values from https://en.uesp.net/wiki/Skyrim:Armor
	if armorType = 'Light Armor' then
		level := Floor(0.0198*Power(armorRating,2) - 1.3631*armorRating + 25.182)
	else if armorType = 'Heavy Armor' then
		level := Floor(0.0133*Power(armorRating,2) - 1.2304*armorRating + 26.463);

	//AddMessage(slIngredients[0]+IntToStr(Integer(slIngredients.Objects[0])));
	AddMessage('Total armor rating: '+IntToStr(armorRating));
	AddMessage('Level '+IntToStr(level));
	
	// Use slOutput to read the UUID/GUID generated earlier
	slOutput.LoadFromFile('Armor Export\Ingredients.txt');
	moduleID := slOutput[0];
	modID := slOutput[1];
	slOutput.Delete(1);
	slOutput.Delete(0);
	
	// Load the reference list of Ingredients included with Character Tracker
	// so that Ingredients that aren't included can be added.
	slCTIngredients.LoadFromFile('Armor Export\CT Ingredients-Do Not Edit.txt');

	slOutput.Add('---- Simple printout ----');
	slOutput.Add(armorName);
	for i := 0 to slIngredients.Count - 1 do
		slOutput.Add(IntToStr(Integer(slIngredients.Objects[i]))+',"'+slIngredients[i]+'","'+slIngredientNames[i]+'"');
	
	slOutput.Add('Armor Rating: '+FloatToStr(armorRating));
	slOutput.Add(armorType);
	slOutput.Add('Level '+IntToStr(level));
	
	// Create JSON output
	
	outputJSON := TJsonObject.Create;
	module := outputJSON.A['modules'].AddObject;
	
	// This type means equipment (armor), so this is static
	module.S['type'] := 'EA1A35DB-3165-45F0-A55D-A94D5B5DA6BE';
	
	module.S['id'] := moduleID;
	
	module.S['name'] := armorName;
	module.I['level'] := level;
	
	json := module.A['attributes'].AddObject;
	if armorType = 'Light Armor' then
		json.S['attribute'] := '97113C70-BCF3-490D-9810-761A783B45D3'
	else if armorType = 'Heavy Armor' then
		json.S['attribute'] := '5BE4471A-F7CA-4F1C-B81C-E4A20C4C7525';
	
	// For now, assume it's compatible with all 3 Skyrims
	AddSkyrims(module);
	
	// Only add a mod if the user gave a mod name
	if modName <> '' then begin
		modJSON := outputJSON.A['mods'].AddObject;
		modJSON.S['name'] := modName;
		modJSON.S['id'] := modID;
		modJSON.A['modules'].Add(moduleID);
		AddSkyrims(modJSON);
	end;
	
	for i := 0 to slIngredients.Count - 1 do begin
		json := module.A['ingredients'].AddObject;
		json.S['ingredient'] := slIngredients[i];
		json.I['quantity'] := Integer(slIngredients.Objects[i]);
		
		// If the Ingredient isn't already included in Character Tracker,
		// create a new object for it
		if IndexOfStringInArray(slIngredients[i], slCTIngredients) = -1 then begin
			json := outputJSON.A['ingredients'].AddObject;
			json.S['id'] := slIngredients[i];
			json.S['name'] := slIngredientNames[i];
			// For now, assume it's compatible with all 3 Skyrims
			AddSkyrims(json);
			
			if Assigned(modJSON) then
				modJSON.A['ingredients'].Add(slIngredients[i]);
		end;
	end;
	
	slOutput.Add('');
	slOutput.Add('(Compact JSON in Ingredients.json)');
	slOutput.Add('---- Pretty Character Tracker JSON ----');
	slOutput.Add(outputJSON.ToJSON({Compact:=}False));
	slOutput.SaveToFile('Armor Export\Ingredients.txt');
	
	slOutput.Free;
	slOutput := TStringList.Create;
	slOutput.Add(outputJSON.ToJSON({Compact:=}True));
	slOutput.SaveToFile('Armor Export\Ingredients.json');
	
	// Requires my modified myqr.exe compiled from https://github.com/Isvvc/qrcode
	// This should have already come with this script if you downloaded it from Releases.
	//ShellExecute(0, nil, '"Armor Export\myqr.exe"', '-l L -d "Armor Export" "Armor Export\Ingredients.json"', nil, 0);
	ShellExecute(0, nil, '"Armor Export\Python38\python.exe"', '"Armor Export\Armor_Export.py"', nil, 0);

	slIngredients.Free;
	slIngredientNames.Free;
	slOutput.Free;
	slCTIngredients.Free;
	slots.Free;
	outputJSON.Free;
	//json and module point to children of outputJSON so don't need freeing
end;

end.
