-- Run from the repository root: lua tests/regression.lua
local ns = {}
local function addon(path)
    assert(loadfile(path))("BetterMacro", ns)
end
for _, path in ipairs({ "Locales/enUS.lua", "Core/Util.lua", "Core/Generator.lua",
    "Core/Parser.lua", "Core/Data.lua", "Core/Storage.lua" }) do addon(path) end

local U, G, S = ns.U, ns.Generator, ns.Storage
local slots = {}
local edits, deletes = 0, 0
MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS = 120, 18
UnitName = function() return "Test" end
GetRealmName = function() return "Realm" end
GetNumMacros = function() return #slots, 0 end
GetMacroInfo = function(index)
    local m = slots[index]
    if m then return m.name, m.icon, m.body end
end
EditMacro = function(index, name, icon, body)
    edits = edits + 1
    slots[index] = { name = name, icon = icon, body = body }
    return index
end
CreateMacro = function(name, icon, body)
    slots[#slots + 1] = { name = name, icon = icon, body = body }
    return #slots
end
DeleteMacro = function(index) deletes = deletes + 1; table.remove(slots, index) end
S.Init()

-- Adding a branch never moves an existing branch, including a fallback.
local original = { action = { kind = "spell", name = "Heal" } }
local line = { kind = "cast", cmd = "cast", branches = { original } }
U.AddBranch(line)
assert(line.branches[1] == original and #line.branches == 2)
assert(line.branches[2].action ~= original.action)
assert(G.LineText(line):find("Heal", 1, true))

-- A sorted-list insertion moves A from slot 1 to 2; resolve its identity
-- rather than writing to the new occupant of slot 1.
slots = { { name = "A", icon = 1, body = "/cast Heal" } }
local identity = S.Identity(1)
table.insert(slots, 1, { name = "0", icon = 2, body = "/cast Fireball" })
assert(S.ResolveIdentity(identity) == 2)
local m = U.NewMacro("A")
m.showtooltip = false
m.lines = { U.NewRawLine("/cast Renew") }
assert(S.Save(m, assert(S.ResolveIdentity(identity))) == 2)
assert(slots[1].body == "/cast Fireball" and slots[2].body == "/cast Renew")
assert(not S.ResolveIdentity(identity)) -- external content changed

-- Same-named macros are matched by name, icon and body, not by name alone.
slots = { { name = "Same", icon = 1, body = "/a" }, { name = "Same", icon = 2, body = "/b" } }
local duplicate = S.Identity(1)
assert(S.ResolveIdentity(duplicate) == 1)
assert(not S.FindIndex("Same", false))
local model = U.NewMacro("Same")
local index, err = S.Save(model, nil)
assert(index == 3 and not err)
table.insert(slots, 1, { name = "Other", icon = 3, body = "/c" })
assert(S.ResolveIdentity(duplicate) == 2)
-- Identical copies remain selectable and editable: prefer the selected slot.
slots = { { name = "Same", icon = 1, body = "/a" }, { name = "Same", icon = 1, body = "/a" } }
identity = S.Identity(2)
assert(S.ResolveIdentity(identity) == 2)
model = U.NewMacro("Same")
model.showtooltip = false
model.lines = { U.NewRawLine("/changed") }
assert(S.Save(model, assert(S.ResolveIdentity(identity))) == 2)
assert(slots[1].body == "/a" and slots[2].body == "/changed")
assert(S.Load(2).lines[1].text == "/changed")
assert(deletes == 0)

-- Text changed outside the addon and deletion must both invalidate identity.
slots = { { name = "A", icon = 1, body = "/cast Heal" } }
identity = S.Identity(1)
slots[1].body = "/cast Renew"
assert(not S.ResolveIdentity(identity))
slots = {}
assert(not S.ResolveIdentity(identity))

-- A hole (slot left for the player to fill) never reaches the game.
local holed = U.NewMacro("Holed")
holed.showtooltip = false
holed.lines = { { kind = "cast", cmd = "cast", branches = { { action = U.Hole("help") } } } }
assert(U.HasHoles(holed))
assert(G.Build(holed) == "/cast ")
local count = #slots
local holeIndex, holeErr = S.Save(holed, nil)
assert(not holeIndex and holeErr == ns.L.ERR_HOLES and #slots == count)
holed.lines[1].branches[1].action = { kind = "spell", name = "Heal" }
assert(not U.HasHoles(holed))

-- Extra conditions, "!" and conditional commands survive a parse/build round trip.
local P = ns.Parser
local function roundTrip(text) return G.LineText(P.ParseLine(text)) end
assert(roundTrip("/petattack [@mouseover,harm,nodead][]") == "/petattack [@mouseover,harm,nodead][]")
assert(roundTrip("/cancelaura [mod:shift] Slow Fall") == "/cancelaura [mod:shift] Slow Fall")
assert(roundTrip("/cast [nostance:1,nomod:shift,swimming,nopet,button:2] !Stealth")
    == "/cast [noform:1,nomod:shift,swimming,nopet,button:2] !Stealth")
assert(roundTrip("/cast [outdoors] Travel Form; Cat Form") == "/cast [outdoors] Travel Form; Cat Form")
-- Several modifier keys: all held ("mod:alt,mod:ctrl") or any of them ("mod:alt/ctrl").
assert(roundTrip("/cast [mod:ctrl,mod:alt] Blink") == "/cast [mod:alt,mod:ctrl] Blink")
assert(P.ParseLine("/cast [mod:ctrl,mod:alt] Blink").branches[1].mod == "alt+ctrl")
assert(roundTrip("/cast [mod:alt/ctrl] Blink") == "/cast [mod:alt/ctrl] Blink")
-- Keys written together ("mod:shiftalt") mean all of them held.
assert(P.ParseLine("/cast [mod:shiftalt,@player] Heal").branches[1].mod == "shift+alt")
assert(P.ParseLine("/cast [mod:ctrlshift,mod:shift] Heal").branches[1].mod == "shift+ctrl")
assert(P.ParseLine("/cast [mod:shiftalt/ctrl] Heal").kind == "raw")
local ht = P.ParseLine("/cast [mod:shiftalt,@player][mod:shift,@mouseover,help,nodead][mod:shift,help,nodead] Healing Touch; "
    .. "[mod:alt,@player][@mouseover,help,nodead][help,nodead] Healing Touch(Rank 4)")
assert(ht.kind == "cast" and #ht.branches == 6)
assert(G.LineText(ht) == "/cast [mod:shift,mod:alt,@player][mod:shift,@mouseover,help,nodead][mod:shift,help,nodead] Healing Touch; "
    .. "[mod:alt,@player][@mouseover,help,nodead][help,nodead] Healing Touch(Rank 4)")
assert(roundTrip("/cast [mod:shift] A; [mod:alt] B; [mod:ctrl] B; A") == "/cast [mod:shift] A; [mod:alt][mod:ctrl] B; A")
-- A missing ";" before a condition still splits the cases.
local fol = P.ParseLine("/cast [mod:shiftalt,@player][mod:shift,help] Flash of Light(Rank 1) [mod:alt,@player][help] Flash of Light(Rank 3)")
assert(fol.kind == "cast" and #fol.branches == 4)
assert(fol.branches[2].action.name == "Flash of Light(Rank 1)" and fol.branches[3].action.name == "Flash of Light(Rank 3)")
-- Compact text: no spaces, keys held together in one token.
assert(G.LineText(fol, true) == "/cast [mod:shiftalt,@player][mod:shift,help]Flash of Light(Rank 1);[mod:alt,@player][help]Flash of Light(Rank 3)")
assert(G.LineText(P.ParseLine(G.LineText(fol, true)), true) == G.LineText(fol, true))
-- /equip is a block like /use, with cases and conditions.
local eqLine = P.ParseLine("/equip [mod:shift] Shield of Thorns; Rod of Healing")
assert(eqLine.kind == "cast" and eqLine.cmd == "equip" and #eqLine.branches == 2)
assert(eqLine.branches[1].action.kind == "item")
assert(G.LineText(eqLine) == "/equip [mod:shift] Shield of Thorns; Rod of Healing")
assert(U.ToggleMod("alt+ctrl", "alt") == "ctrl" and U.ToggleMod("alt/ctrl", "shift") == "shift/alt/ctrl")
local tipped = P.Parse("#showtooltip [mod:shift] Thorns; Mark of the Wild\n/cast Thorns")
assert(tipped.showtooltip and not tipped.tooltipAction and #tipped.lines == 1)

-- Commands on a unit: /focus, /target, /assist take the unit from their conditions.
local fo = P.ParseLine("/focus [nomod:shift,@mouseover,exists][nomod:shift]")
assert(fo.kind == "command" and fo.cmd == "focus" and #fo.conds == 2 and fo.conds[1].unit == "mouseover")
assert(G.LineText(fo) == "/focus [@mouseover,exists,nomod:shift][nomod:shift]")
assert(roundTrip("/clearfocus [mod:shift]") == "/clearfocus [mod:shift]")
assert(roundTrip("/stopmacro [nocombat]") == "/stopmacro [nocombat]")
assert(roundTrip("/petstay") == "/petstay")
assert(P.ParseLine("/target Hogger").kind == "raw") -- a name: kept as text
-- More units, read back as they were written.
assert(roundTrip("/cast [@party1,help,nodead] Heal") == "/cast [@party1,help,nodead] Heal")
assert(roundTrip("/cast [@raid12,help,nodead] Heal") == "/cast [@raid12,help,nodead] Heal")
assert(roundTrip("/cast [@focustarget,harm] Fireball") == "/cast [@focustarget,harm] Fireball")
assert(P.ParseLine("/cast [@raid41] Heal").kind == "raw")
assert(P.ParseLine("/cast [@arena1] Heal").kind == "raw")
-- More conditions.
assert(roundTrip("/cast [mounted,group:raid,equipped:Shields] Shield Bash") == "/cast [mounted,group:raid,equipped:Shields] Shield Bash")
assert(P.ParseLine("/cast [equipped:Two-Handed Swords] Slam").branches[1].equipped == "Two-Handed Swords")
assert(P.ParseLine("/cast [equipped:Shields/Daggers] Slam").kind == "raw")
assert(roundTrip("/stopcasting [nochanneling]") == "/stopcasting [nochanneling]")
assert(roundTrip("/cast [channeling] Mind Flay; Smite") == "/cast [channeling] Mind Flay; Smite")
assert(roundTrip("/cast [nogroup] Hearthstone") == "/cast [nogroup] Hearthstone")
assert(roundTrip("/cast [exists] Attack; Auto Shot") == "/cast [exists] Attack; Auto Shot")
assert(roundTrip("/cast [noexists] Shoot; Fireball") == "/cast [noexists] Shoot; Fireball")
assert(roundTrip("/cast [@mouseover,noexists] Heal") == "/cast [@mouseover,noexists] Heal")
assert(P.ParseLine("/cast [exists,noexists] Heal").kind == "raw")
-- Random lines.
local rnd = P.ParseLine("/castrandom [combat] Fireball, Frostbolt")
assert(rnd.kind == "sequence" and rnd.random == "cast" and #rnd.steps == 2)
assert(G.LineText(rnd) == "/castrandom [combat] Fireball, Frostbolt")
local urnd = P.ParseLine("/userandom Major Healing Potion, Healthstone")
assert(urnd.random == "use" and urnd.steps[1].kind == "item")
assert(G.LineText(urnd) == "/userandom Major Healing Potion, Healthstone")
assert(P.ParseLine("/castrandom reset=5 A, B").kind == "raw")
assert(P.ParseLine("/castrandom [combat] A; B").kind == "raw")
-- A bag slot is an item where it sits, not a name.
local bag = P.ParseLine("/use 0 1")
assert(bag.branches[1].action.kind == "bag" and bag.branches[1].action.bag == 0 and bag.branches[1].action.slot == 1)
assert(G.LineText(bag) == "/use 0 1")
-- A ";" at the end of the line is ignored, like the game does; an empty case
-- in the middle is not (it stops the line there).
assert(roundTrip("/cast [mod:shift] Life Tap(Rank 2); Life Tap;") == "/cast [mod:shift] Life Tap(Rank 2); Life Tap")
assert(roundTrip("/cast Hellfire; ") == "/cast Hellfire")
assert(P.ParseLine("/cast [mod:shift] A; ; B").kind == "raw")
assert(P.ParseLine("/cast ;").kind == "raw")
-- Pet name or family: "pet:Voidwalker" keeps how it was written.
local demo = P.ParseLine("/cast  [pet:voidwalker] Sacrifice; [pet:succubus] Soothing Kiss; "
    .. "[pet:felhunter,mod:alt,@player][pet:felhunter, @mouseover][pet:felhunter] Devour Magic;")
assert(demo.kind == "cast" and #demo.branches == 5 and demo.branches[1].pet == "voidwalker")
assert(G.LineText(demo) == "/cast [pet:voidwalker] Sacrifice; [pet:succubus] Soothing Kiss; "
    .. "[mod:alt,@player,pet:felhunter][@mouseover,exists,pet:felhunter][pet:felhunter] Devour Magic")
assert(P.ParseLine("/cast [pet:Imp] Firebolt").branches[1].pet == "Imp")
assert(P.ParseLine("/cast [pet:Imp/Voidwalker] Firebolt").kind == "raw")
assert(roundTrip("/cast [pet] A; [nopet] B") == "/cast [pet] A; [nopet] B")
-- @cursor: an area spell placed under the mouse. Like @player, it needs no
-- enemy/ally or alive check and gets no "exists".
local rof = P.ParseLine("/cast [@cursor,mod:shift] Rain of Fire(Rank 1); [mod:ctrl] Rain of Fire; [@cursor] Rain of Fire;")
assert(rof.kind == "cast" and #rof.branches == 3 and rof.branches[3].unit == "cursor")
assert(G.LineText(rof) == "/cast [mod:shift,@cursor] Rain of Fire(Rank 1); [mod:ctrl][@cursor] Rain of Fire")
assert(U.IsCatchAll(rof.branches[3]) and not rof.branches[3].rel)
local cb = U.NewBranch("cursor", { kind = "spell", name = "Blizzard" })
assert(not cb.rel and not cb.life)
addon("Core/Explainer.lua")
local rofMacro = U.NewMacro("RoF")
rofMacro.lines = { rof }
local _, rofWarn = ns.Explainer.Explain(rofMacro, {})
for _, w in ipairs(rofWarn) do assert(not w:find(ns.L.UNIT_cursor, 1, true), w) end

print("OK: branch order, moved indices, duplicate names, stale identities, holes, conditions, units, commands, random lines, trailing \";\", pet names and @cursor")
