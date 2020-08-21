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

uses mteFunctions;

var
	slCobj, slCsv: TStringList;

function IndexOfStringInArray(Value: string; Strings: TStringList): Integer;
var I: Integer;
begin
  Result := -1;
  for I := 0 to Strings.Count-1 do
	if CompareText(Strings[i], Value) = 0 then begin
      Result := i;
      Exit;
    end;
end;

procedure AddSkyrims(json: TJsonObject);
begin
	json.A['games'].Add('33839302-E5B9-4299-AA81-444BED243F20');
	json.A['games'].Add('75CFE734-1107-4B03-8269-AC130D88A8B7');
	json.A['games'].Add('C68322E4-6550-4588-B5E4-D54DF5976E7C');
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
	i, j, k, count, level: integer;
	armorRating: double;
	armorTypeSet: bool;
	armorType, itemID, itemName, armorName, moduleID: string;
	cobj, cnam, items, li, item, refBy, bnam: IInterface;
	slIngredients, slIngredientNames, slOutput, slCTIngredients: TStringList;
	module, json, outputJSON: TJsonObject;
begin
	slIngredients := TStringList.Create;
	slIngredientNames := TStringList.Create;
	slOutput := TStringList.Create;
	slCTIngredients := TStringList.Create;
	armorRating := 0;
	armorTypeSet := False;
	
	// Temporarily use Ingredients.txt to get a UUID/GUID from Powershell
	ShellExecute(0, nil, 'powershell', '[guid]::NewGuid().ToString() > Ingredients.txt', nil, 0);
	
	InputQuery('Armor Stats and Requirements', 'Armor Name', armorName);

	// Go through every armor piece
	for i := 0 to slCobj.Count - 1 do begin
		cnam := ObjectToElement(slCobj.Objects[i]);
		AddMessage('    Processing '+slCobj[i]);
		
		// Increase the armor rating by the amount of the resulting armor
		armorRating := armorRating + geev(cnam, 'DNAM');
		if not armorTypeSet then begin
			// The armor type and thus calculated level will be based off the first armor encountered
			armorType := geev(cnam, 'BOD2\Armor Type');
			if (armorType = 'Light Armor') or (armorType = 'Heavy Armor') then
				armorTypeSet := True
		end;
		
		// Go through all of the Referenced By until you find the crafting (not tempering) recipe
		for i := 0 to ReferencedByCount(cnam) - 1 do begin
			refBy := ObjectToElement(ReferencedByIndex(cnam, i));
			if Signature(refBy) = 'COBJ' then begin
				bnam := LinksTo(ElementByPath(refBy, 'BNAM'));
				if (geev(bnam, 'EDID') = 'CraftingSmithingForge') or (geev(bnam, 'EDID') = 'CraftingTanningRack') then begin;
					cobj := refBy;
					break;
				end;
			end;
		end;
	
		if not Assigned(cobj) then Continue;
		items := ElementByPath(cobj, 'Items');
		
		// Add every crafting ingredient to the ingredients list
		for j := 0 to ElementCount(items) - 1 do begin
			li := ElementByIndex(items, j);
			item := LinksTo(ElementByPath(li, 'CNTO\Item'));
			count := geev(li, 'CNTO - Item\Count');

			itemName := DisplayName(item);
			itemID := GetFileName(GetFile(item))+' '+copy(IntToHex(FixedFormID(item),8),3,6);
			k := IndexOfStringInArray(itemID, slIngredients);
			// If the list doesn't have the ingredient yet, add item
			if k <> -1 then
				slIngredients.Objects[k] := TObject(count + Integer(slIngredients.Objects[k]))
			// If the list already has the ingredient, increase the count
			else begin
				slIngredients.AddObject(itemID, TObject(count));
				slIngredientNames.Add(itemName);
			end;
		end;

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
	slOutput.LoadFromFile('Ingredients.txt');
	moduleID := slOutput[0];
	AddMessage(slOutput[0]);
	slOutput.Delete(0);
	
	// Load the reference list of Ingredients included with Character Tracker
	// so that Ingredients that aren't included can be added.
	slCTIngredients.LoadFromFile('CT Ingredients-Do Not Edit.txt');

	slOutput.Add('---- Simple printout ----');
	slOutput.Add(armorName);
	for i := 0 to slIngredients.Count - 1 do
		slOutput.Add(IntToStr(Integer(slIngredients.Objects[i]))+',"'+slIngredients[i]+'","'+slIngredientNames[i]+'"');
	
	slOutput.Add('Armor Rating: '+FloatToStr(armorRating));
	slOutput.Add(armorType);
	slOutput.Add('Level '+IntToStr(level));
	
	outputJSON := TJsonObject.Create;
	module := outputJSON.A['modules'].AddObject;
	
	// This type means equipment (armor), so this is static
	module.S['type'] := 'EA1A35DB-3165-45F0-A55D-A94D5B5DA6BE';
	
	// I can't find any Pascal/Delphi function for generating a UUID or GUID
	// that works in xEdit, so I'm hard-coding one for now.
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
		end;
	end;
	
	slOutput.Add('');
	slOutput.Add('---- Pretty Character Tracker JSON ----');
	slOutput.Add(outputJSON.ToJSON({Compact:=}False));
	slOutput.Add('');
	slOutput.Add('---- Compact Character Tracker JSON ----');
	slOutput.Add(outputJSON.ToJSON({Compact:=}True));

	slOutput.SaveToFile('Ingredients.txt');
	slIngredients.Free;
	slIngredientNames.Free;
	slOutput.Free;
	slCTIngredients.Free;
	outputJSON.Free;
	//json and module point to children of outputJSON so don't need freeing
end;

end.
