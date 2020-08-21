# xEdit-Armor-Export

xEdit script for exporting crafting materials and combined armor ratings

## Use

### Dependencies

This script depends on `mteFunctions.pas`

### Installation

1. Copy `mteFunctions.pas` (from Automation Tools for TES5Edit or elsewhere) to your xEdit's `Edit Scripts` directory.
1. Merge the `Edit Scripts` folder from this repository with the one from you xEdit install.
1. Copy `CT Ingredients-Do Not Edit.txt` to your xEdit install (the same directory as the exe file). As the title suggests, don't edit this file.

### Running

1. In xEdit, select all armor items for a particular armor set then right click and choose `Apply Script...`.
1. From the menu, chose `Armor Stats and Requirements.pas` and click OK.
1. Enter a name for the armor set.
1. This will create an Ingredients.txt file in your xEdit directory with the following information:

* CSV list of crafting ingredients required
	* quantity, plugin name and FixedFormID, DisplayName
* Combined armor rating
* The armor type (of the first armor selected)
* Calculated level based on type and rating
* JSON that can be imported into the [Character Tracker](https://github.com/Isvvc/Character-Tracker) iOS app.
