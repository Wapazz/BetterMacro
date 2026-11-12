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

print("OK: branch order, moved indices, duplicate names and stale identities")
