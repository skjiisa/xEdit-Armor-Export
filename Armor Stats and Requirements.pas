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
    if Strings[i] = Value then begin
      Result := i;
      Exit;
    end;
end;

function Initialize: integer;
begin
	slCobj := TStringList.Create;
end;

function Process(e: IInterface): integer;
var
	i: integer;
	cobj, refBy, bnam: IInterface;
begin
	// Go through all of the Referenced By until you find the crafting (not tempering) recipe
	for i := 0 to ReferencedByCount(e) - 1 do begin
		refBy := ObjectToElement(ReferencedByIndex(e, i));
		if Signature(refBy) = 'COBJ' then begin
			bnam := LinksTo(ElementByPath(refBy, 'BNAM'));
			if (geev(bnam, 'EDID') = 'CraftingSmithingForge') or (geev(bnam, 'EDID') = 'CraftingTanningRack') then begin;
				cobj := refBy;
				break;
			end;
		end;
	end;

	// Add the armor's EDID and the crafting recipe (if one was found) to the list
	slCobj.AddObject(geev(e, 'EDID'), TObject(cobj));
	AddMessage('    Loading '+slCobj[slCobj.Count - 1]);
end;

function Finalize: integer;
var
	i, j, k, count, level: integer;
	armorRating: double;
	armorTypeSet: bool;
	armorType, itemID, itemName: string;
	cobj, cnam, items, li, item: IInterface;
	slIngredients, slIngredientNames, slOutput: TStringList;
begin
	slIngredients := TStringList.Create;
	slIngredientNames := TStringList.Create;
	slOutput := TStringList.Create;
	armorRating := 0;
	armorTypeSet := False;

	// Go through every recipe
	for i := 0 to slCobj.Count - 1 do begin
		cobj := ObjectToElement(slCobj.Objects[i]);
		cnam := LinksTo(ElementByPath(cobj, 'CNAM'));
		items := ElementByPath(cobj, 'Items');
		if not Assigned(cnam) then Continue;

		AddMessage('    Processing '+slCobj[i]);
		
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
		
		// Increase the armor rating by the amount of the resulting armor
		armorRating := armorRating + geev(cnam, 'DNAM');
		if not armorTypeSet then begin
			// The armor type and thus calculated level will be based off the first armor encountered
			armorType := geev(cnam, 'BOD2\Armor Type');
			armorTypeSet := True
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

	//slOutput.Add();
	for i := 0 to slIngredients.Count - 1 do
		slOutput.Add(IntToStr(Integer(slIngredients.Objects[i]))+',"'+slIngredients[i]+'","'+slIngredientNames[i]+'"');
	
	// This breaks csv format but I don't care
	slOutput.Add('Armor Rating: '+FloatToStr(armorRating));
	slOutput.Add(armorType);
	slOutput.Add('Level '+IntToStr(level));

	slOutput.SaveToFile('Ingredients.txt');
	slIngredients.Free;
	slIngredientNames.Free;
	slOutput.Free;
end;

end.