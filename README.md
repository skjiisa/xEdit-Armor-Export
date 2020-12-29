# xEdit-Armor-Export

xEdit script for exporting crafting materials and combined armor ratings

This script was designed to be used with the [Character Tracker](https://github.com/Isvvc/Character-Tracker) iOS app.
It is still totally usable without it, though.

## Use

### Dependencies

This script depends on `mteFunctions.pas` (included in release zips)

### Installation

1. Download `xEdit-Armor-Export.zip` from the [Releases tab](https://github.com/Isvvc/xEdit-Armor-Export/releases).
1. Extract to your xEdit (TES5Edit, TES5VREdit, etc.) folder, merging any contents.
If it asks to replace `mteFunctions.pas`, it doesn't matter either way.
	+ Extracting `Armor Export\myqr.exe` is optional.
	It is used for creating QR codes for Character Tracker.
	You are welcome to remove it if you are not using the app.

### Running

1. In xEdit, select all armor items for a particular armor set then right click and choose `Apply Script...`.
1. From the menu, chose `Armor Stats and Requirements.pas` and click OK.
1. Enter a name for the armor set.
1. **Optional**: Enter a name for the mod if you want it shown in Character Tracker.
	+ If you leave this empty, no mod entry will be created in the JSON.
	+ This has no affect on the simple printout.
1. This will create an `Ingredients.txt` file in the `Armor Export` folder in your xEdit directory with the following information:
	+ CSV list of crafting ingredients required
		+ quantity, plugin name and FixedFormID, DisplayName
	+ Combined armor rating
	+ The armor type (of the first armor selected)
	+ Calculated level based on type and rating
	+ JSON that can be imported into Character Tracker
	+ A QR code that can be scanned into Character Tracker if `myqr.exe` is present.
1. A GUI will launch for adding images and generating QR codes.
	+ Manually add images with the **Image URL** text box
	+ Enter a Nexusmods mod page in the **Nexusmods URL** text box to select images from the mod page to load.
		+ Currently only the first 5 images will load.
		+ Adult-only mod pages will not load as they require a user to be signed in, and this does not currently support signing in to an account.
	+ When you have the images inputted that you'd like, click any of the **Save images to** buttons to save the images to the `Ingredients.json` file.
		+ Check **Generate QR code** to generate a QR code that can be scanned into Character Tracker.
	+ Note that this GUI is in early stages and can crash if text fields are left blank.
		+ Generating QR codes with no images, however, should work just fine.

## Build

(You can ignore this section if you just download a release zip)

xEdit scripts are compiled at runtime, so no build is required for the Pascal script.

### MyQR

The `myqr.exe` included in Releases comes from [Isvvc/qrcode](https://github.com/Isvvc/qrcode/),
my slightly modified version of [sylnsfar/qrcode](https://github.com/sylnsfar/qrcode).
The changes I made were simply adding `"` to the supported characters list so it could encode JSON
and allowing it to read input from a file so long JSON could be passed in without having to try to pass it as an argument.

Once Python dependencies are installed (presumably using `pip`), it can be built using [PyInstaller](https://www.pyinstaller.org/) for Windows.

	pyinstaller -F myqr.py
