What's this?
=======

This folder contains scripts and resources used by the AD team. The content of this folder is not required to run the mod, and it should not be included in the mod/zip-file.

---

# Textures & Icons

All icons, textures and materials are stored as PNG files in the [icons](icons/) folder. Do not add other file types to that folder. Do not add icons to any other folder.

The [build_textures](build_textures.py) script is used to merge these images into a single texture file, and to generate the required xml file for UV coordinate lookup. 

***Adding a new icon***

1. add the icon as a PNG file to the `icons` folder. Giants has no public naming convention for these files, but it is probably a good idea to follow the existing pattern, and to refrain from using white space and dots.

2. run [build_textures](build_textures.py). This script takes all images from the `icons` folder and arranges them in a single texture file. This will  replace the existing [ad_gui.dds](/textures/ad_gui.dds) and [ad_gui.xml](/textures/ad_gui.xml) files. If the script fails to find a solution, increase the width and height defined at the top of the file.

3. use your new icon, typically via `g_overlayManager:createOverlay("ad_gui.<your_icon_name>")`

4. stage and commit your new icon, as well as both files in the `textures` folder.

# Translations

Translations are stored in the [translations](/translations/) folder. The [sync_translations](sync_translations.py) script can be used to add or remove new translation entries quickly. This script uses the english translation file as the single source of truth.

***Adding a new translation string***

1. add the new string to [translation_en.xml](/translations/translation_en.xml)

2. run the script. This adds the same entry to all other files - ready for translators to pick it up. 

3. stage and commit all translation files.

***Removing an unused translation string***

1. make sure the string is not used, then remove it from [translation_en.xml](/translations/translation_en.xml)

2. run the script. This removes the entry from all other translation files

3. stage and commit all translation files

***Renaming a translation string***

Changing the `name` part of a translation string is not supported by the script. Use search/replace in your IDE instead. 
If you rename an entry in [translation_en.xml](/translations/translation_en.xml) and then run the script, it will delete the old entry and copy the new entry - which will <strong>reset all existing translations</strong> of this entry to the English version.

# Release

Use [make_release](make_release.py) to quickly bundle all required files into a FS25 compliant zip file. 
This script excludes some files managed by `git`, the `tools` folder, as well as all files which are excluded by `.gitignore`. 
