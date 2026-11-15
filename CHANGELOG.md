# BetterMacro

## 1.2.0

### New

- **Class catalog.** Open it with the "Class catalog" button or `/bm catalog`. It lists ready-made macros for every class, including 96 macros from classicwowforever.com (CC BY 4.0). You can filter by class, role (heal, tank, DPS, utility) and type (group, solo, PvP, pet), search by name, and show only the macros you can use right now. Each macro shows what it does, its text, and the spells you haven't learned yet. "Use" opens it in the editor, and you can mark favorites.
- **Templates with empty slots.** A template now fills in your class's spells by itself. When your class has no spell for a slot, the slot stays empty and shows what it is for (heal, self, interrupt, crowd control…). Hover a template to see what it will do before you open it. A macro with an empty slot can't be saved or shared until you fill the slot.
- **More conditions.** No form, no modifier key, swimming, outdoors or indoors, pet or no pet, and mouse button. Add them from the "+" chip on a branch.
- **Several modifier keys together.** A branch can now require Alt *and* Ctrl, or either one.
- **Conditions on commands.** Commands such as `/stopcasting`, `/petattack` or `/cancelaura` can now have conditions. `/petpassive` was added.
- **"Never turn it off."** Right-click a spell to add `!`, so pressing the macro again doesn't cancel an aura or a stance.

### Fixed

- Spells learned at a lower rank, such as Lay on Hands or paladin auras, are now detected as learned.
- `/bm` now prints an error in the chat when the window can't open, instead of doing nothing.

> After updating, restart the game: new files aren't loaded by `/reload`.

## 1.1.0

### New

- **Macro header.** The name, icon, scope (character or account), tooltip, rank, "What does it do?" and a new "More" menu (share, save as template) are now grouped above the macro.
- **Icon picker.** Click the icon to choose from every icon in the game, with suggestions based on the spells in the macro. You can also drag the icon to an action bar.

### Changed

- Bigger window, with more room for the editor.
- "Otherwise" is now "Else".
- Duplicate now sits next to Delete and Save.
- The History button is hidden for now.

### Fixed

- The editor panel no longer shows up empty.

## 1.0.1

- Branches inside a block can now be moved up or down. The order of the branches is the order the game tries them in, so you can now change it without rebuilding the block.
