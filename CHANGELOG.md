# BetterMacro

## 1.2.3

### New

- **More commands as blocks:** Target, Assist, Set focus, Clear focus, Target ally, Stop the macro, and pet stay, defensive and aggressive. Target, Assist and Set focus pick their unit like a spell does (`/focus [@mouseover,exists][]`). The "Focus on mouseover" macro of the Common section no longer opens as raw text.
- **Random spell / Random item** blocks for `/castrandom` and `/userandom`. Click the title of a sequence block to switch between in order and at random.
- **More conditions** from the "+" chip: the unit exists or not, channeling, mounted, in a group or a raid (or solo), and an item type equipped (`equipped:Shields`).
- **More units:** your focus's target, your mouseover's target, your pet's target, and party members 1 to 4. Raid members (`@raid12`) and party pets are read from macros too.
- `/use 0 1` (an item by bag and slot) is now a block that shows what sits in that slot.
- **Search in the macro list**, by name or by macro text: "Renew" finds every macro that casts it.
- **Cast at the cursor** (`@cursor`): area spells such as Rain of Fire or Blizzard land under your mouse without the targeting click. Like "me", it needs no enemy/ally check.
- **Pet by name or family:** `[pet:Voidwalker]` is now read from macros and shown as its own condition.

### Changed

- The live test now also lights up the condition that matches on commands, such as `/stopcasting [mod:shift]`.

### Fixed

- A `;` at the end of a line (`/cast [mod:shift] Life Tap(Rank 2); Life Tap;`) no longer turns the whole line into raw text. The game ignores it, and so does the editor now.

## 1.2.2

### New

- **"Equip an item" block.** `/equip` is no longer raw text: it works like "Use an item", with cases and conditions (`/equip [mod:shift] Shield; Staff`). Its picker lists what you are wearing first, with the slot, then everything in your bags that you can equip.
- **"Common" section in the catalog**, after the classes, for macros every class can use: both trinkets, weapon stones, wizard and mana oils, Healthstone or potion, bandage on mouseover, skull on the target, focus on mouseover, and setting your role for the dungeon finder.

### Changed

- The class catalog is now called the **macro catalog**, since it also holds macros for every class.
- In the right panel, "Blocks" is now called "Commands", and every section (templates, commands, my templates) folds when you click its title. The game remembers which ones are folded.
- In a block, "If" and "Else" now sit in front of the conditions instead of the spell.
- "Spell ranks" is now on by default, so every spell shows its rank picker. Items (`/use`, `/equip`) never show one. The macro still uses the highest rank until you pick another one. Untick it to hide the pickers.

## 1.2.1

### Fixed

- Modifier keys written together, such as `[mod:shiftalt]`, are now understood. Before, the whole line was kept as raw text.
- A missing `;` between two cases (`Spell A [mod:alt] Spell B`) no longer turns everything after it into the spell name. The `;` is added back.
- When cases that follow each other cast the same spell, they now share it in the macro text (`[a][b] Spell; [c] Other`). Macros stay shorter and further from the 255-character limit.
- "Compress" now also removes the space before each spell and writes keys held together as one condition (`[mod:shiftalt]Spell;Other`).

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
