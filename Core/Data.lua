local _, ns = ...
local L = ns.L

-- Everything that reads the game (spellbook, bags, gear, cursor) lives here,
-- wrapped in pcall so an API difference in WoW Forever never breaks the UI.
local D = {}
ns.Data = D

local function try(f, ...)
    if not f then return nil end
    local ok, a, b, c, d, e = pcall(f, ...)
    if ok then return a, b, c, d, e end
end

local QUESTION = 134400

local SLOT_GLOBALS = {
    [1] = "HEADSLOT", [2] = "NECKSLOT", [3] = "SHOULDERSLOT", [4] = "SHIRTSLOT", [5] = "CHESTSLOT",
    [6] = "WAISTSLOT", [7] = "LEGSSLOT", [8] = "FEETSLOT", [9] = "WRISTSLOT", [10] = "HANDSSLOT",
    [11] = "FINGER0SLOT", [12] = "FINGER1SLOT", [13] = "TRINKET0SLOT", [14] = "TRINKET1SLOT",
    [15] = "BACKSLOT", [16] = "MAINHANDSLOT", [17] = "SECONDARYHANDSLOT", [18] = "RANGEDSLOT", [19] = "TABARDSLOT",
}

-- Localised slot name, or nil if the game doesn't give one
function D.SlotRealName(id)
    if id == 13 or id == 14 then return L["SLOT_" .. id] end
    local g = SLOT_GLOBALS[id or 0]
    local s = g and _G[g]
    if type(s) == "string" and s ~= "" then return s end
end

function D.SlotName(id)
    return D.SlotRealName(id) or L.SLOT_FALLBACK:format(id or 0)
end

------------------------------------------------------------------ macro icons
-- Every icon the game offers for macros. Depending on the client these
-- functions fill the table they are given or return a new one, and give
-- file IDs or texture names: both are accepted by CreateMacro/EditMacro.
local iconCache

function D.ListIcons()
    if iconCache then return iconCache end
    local out, seen = {}, {}
    local function collect(fn)
        if not fn then return end
        local t = {}
        local ok, r = pcall(fn, t)
        if not ok then return end
        if type(r) == "table" then t = r end
        for _, v in ipairs(t) do
            if v and v ~= "" and not seen[v] then
                seen[v] = true
                out[#out + 1] = v
            end
        end
    end
    collect(GetLooseMacroIcons)
    collect(GetLooseMacroItemIcons)
    collect(GetMacroIcons)
    collect(GetMacroItemIcons)
    if #out > 0 then iconCache = out end -- empty: try again next time
    return out
end

-- Texture to draw for a stored icon value (file ID, short name or full path).
function D.IconTexture(v)
    if type(v) == "string" and not v:find("[\\/]") then return "Interface\\Icons\\" .. v end
    return v
end

------------------------------------------------------------------ spells
function D.SpellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then return try(C_Spell.GetSpellName, id) end
    local info = C_Spell and try(C_Spell.GetSpellInfo, id)
    return info and info.name
end

function D.SpellIcon(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellTexture then return try(C_Spell.GetSpellTexture, id) end
    local info = C_Spell and try(C_Spell.GetSpellInfo, id)
    return info and info.iconID
end

function D.SpellIdFromName(name)
    local info = C_Spell and C_Spell.GetSpellInfo and try(C_Spell.GetSpellInfo, name)
    return info and info.spellID
end

function D.IsKnown(id)
    if IsPlayerSpell and try(IsPlayerSpell, id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and try(C_SpellBook.IsSpellKnown, id) then return true end
    if IsSpellKnown and try(IsSpellKnown, id) then return true end
    return false
end

function D.SpellAction(id)
    local name = D.SpellName(id)
    if not name then return nil end
    return { kind = "spell", id = id, name = name }
end

-- Read actual spellbook entries instead of guessing which ranks exist. The
-- spellbook API exposes lower ranks even when the UI hides them; subName can
-- temporarily be empty while spell text loads, so an empty result is safe.
function D.SpellRanks(action)
    local out, seen = {}, {}
    if not action or action.kind ~= "spell" or not action.name then return out end
    local function add(name, subName)
        if name ~= action.name or type(subName) ~= "string" then return end
        local n = subName:match("^[Rr]ank%s*(%d+)$") or subName:match("^[Rr]ang%s*(%d+)$")
        n = tonumber(n)
        if n and n > 0 and not seen[n] then
            seen[n] = true
            out[#out + 1] = { rank = n, text = subName }
        end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines
        and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        for i = 1, try(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
            local line = try(C_SpellBook.GetSpellBookSkillLineInfo, i)
            if line and line.itemIndexOffset and line.numSpellBookItems then
                for idx = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local item = try(C_SpellBook.GetSpellBookItemInfo, idx, bank)
                    if item and not item.isOffSpec and (not spellType or item.itemType == spellType) then
                        local name, subName = item.name, item.subName
                        if (not name or not subName or subName == "") and C_SpellBook.GetSpellBookItemName then
                            name, subName = try(C_SpellBook.GetSpellBookItemName, idx, bank)
                        end
                        add(name, subName)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemName then
        for tab = 1, try(GetNumSpellTabs) or 0 do
            local _, _, offset, count = try(GetSpellTabInfo, tab)
            if offset and count then
                for idx = offset + 1, offset + count do
                    local kind = GetSpellBookItemInfo and try(GetSpellBookItemInfo, idx, "spell")
                    if not kind or kind == "SPELL" then
                        local name, subName = try(GetSpellBookItemName, idx, "spell")
                        add(name, subName)
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.rank < b.rank end)
    return out
end

function D.ListSpells()
    local out, seen = {}, {}
    local function add(id, name, icon)
        if id and name and not seen[name] then
            seen[name] = true
            out[#out + 1] = { kind = "spell", id = id, name = name, icon = icon or D.SpellIcon(id) }
        end
    end
    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
        local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        for i = 1, try(C_SpellBook.GetNumSpellBookSkillLines) or 0 do
            local line = try(C_SpellBook.GetSpellBookSkillLineInfo, i)
            if line and not line.shouldHide then
                for idx = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                    local it = try(C_SpellBook.GetSpellBookItemInfo, idx, bank)
                    if it and it.spellID and not it.isPassive and (not spellType or it.itemType == spellType) then
                        add(it.spellID, it.name, it.iconID)
                    end
                end
            end
        end
    elseif GetNumSpellTabs then
        for t = 1, GetNumSpellTabs() do
            local _, _, offset, num = GetSpellTabInfo(t)
            for idx = offset + 1, offset + num do
                local kind, id = GetSpellBookItemInfo(idx, "spell")
                if kind == "SPELL" and not (IsPassiveSpell and IsPassiveSpell(idx, "spell")) then
                    add(id, D.SpellName(id))
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

------------------------------------------------------------------ items
function D.ItemName(id)
    if not id then return nil end
    if C_Item and C_Item.GetItemNameByID then
        local n = try(C_Item.GetItemNameByID, id)
        if n then return n end
    end
    if C_Item and C_Item.GetItemInfo then return (try(C_Item.GetItemInfo, id)) end
    if GetItemInfo then return (try(GetItemInfo, id)) end
end

function D.ItemIcon(id)
    if not id then return nil end
    if C_Item and C_Item.GetItemIconByID then return try(C_Item.GetItemIconByID, id) end
    if GetItemIcon then return try(GetItemIcon, id) end
end

local function itemHasUse(id)
    local f = (C_Item and C_Item.GetItemSpell) or GetItemSpell
    return try(f, id) ~= nil
end

function D.ItemIdFromName(name)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    return (try(f, name))
end

function D.ListItems()
    local out, seen = {}, {}
    if not C_Container then return out end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        for slot = 1, try(C_Container.GetContainerNumSlots, bag) or 0 do
            local info = try(C_Container.GetContainerItemInfo, bag, slot)
            local id = info and info.itemID
            if id and not seen[id] and itemHasUse(id) then
                local name = D.ItemName(id) or (info.hyperlink and info.hyperlink:match("%[(.-)%]"))
                if name then
                    seen[id] = true
                    out[#out + 1] = { kind = "item", id = id, name = name, icon = info.iconFileID or D.ItemIcon(id) }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

function D.ListSlots()
    local out = {}
    for slot = 1, 19 do
        local id = GetInventoryItemID and GetInventoryItemID("player", slot)
        if id and (slot == 13 or slot == 14 or itemHasUse(id)) then
            out[#out + 1] = {
                kind = "slot", id = slot, name = tostring(slot),
                label = D.SlotName(slot) .. " - " .. (D.ItemName(id) or "?"),
                icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slot),
            }
        end
    end
    -- Trinket slots are always offered, even when empty
    for _, s in ipairs({ 13, 14 }) do
        local found = false
        for _, e in ipairs(out) do if e.id == s then found = true end end
        if not found then
            out[#out + 1] = { kind = "slot", id = s, name = tostring(s), label = D.SlotName(s), icon = QUESTION }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

------------------------------------------------------------------ misc
function D.Icon(a)
    if not a then return QUESTION end
    if a.kind == "spell" then return D.SpellIcon(a.id or a.name) or QUESTION end
    if a.kind == "item" then return D.ItemIcon(a.id or D.ItemIdFromName(a.name)) or QUESTION end
    if a.kind == "slot" then
        return (GetInventoryItemTexture and GetInventoryItemTexture("player", a.id or 0)) or QUESTION
    end
    return QUESTION
end

function D.Label(a)
    if not a then return nil end
    if a.kind == "slot" then return D.SlotName(a.id) end
    return a.name
end

-- Reads whatever is held on the cursor (spell from the spellbook, item from bags).
function D.FromCursor()
    if not GetCursorInfo then return nil end
    local kind, a1, a2, a3, a4 = GetCursorInfo()
    local action
    if kind == "spell" then
        local id = (type(a3) == "number" and a3) or (type(a4) == "number" and a4)
        if not id and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
            local it = try(C_SpellBook.GetSpellBookItemInfo, a1, (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0)
            id = it and it.spellID
        end
        action = id and D.SpellAction(id)
    elseif kind == "item" then
        local name = D.ItemName(a1) or (type(a2) == "string" and a2:match("%[(.-)%]"))
        if name then action = { kind = "item", id = a1, name = name } end
    end
    if action then ClearCursor() end
    return action
end

-- "help" | "harm" | nil
function D.Nature(a)
    if not a or a.kind ~= "spell" then return nil end
    local key = a.id or a.name
    if C_Spell then
        if C_Spell.IsSpellHarmful and try(C_Spell.IsSpellHarmful, key) then return "harm" end
        if C_Spell.IsSpellHelpful and try(C_Spell.IsSpellHelpful, key) then return "help" end
    end
    if IsHarmfulSpell and try(IsHarmfulSpell, a.name) then return "harm" end
    if IsHelpfulSpell and try(IsHelpfulSpell, a.name) then return "help" end
    return nil
end

-- Used by the parser to turn a name from macro text into an action.
function D.Resolve(name, cmd)
    local base, rankText = name:match("^(.-)%s*%(([^()]*)%)$")
    local rank = rankText and (rankText:match("^[Rr]ank%s*(%d+)$") or rankText:match("^[Rr]ang%s*(%d+)$"))
    if rank and base ~= "" then
        return { kind = "spell", id = D.SpellIdFromName(base), name = base, rank = tonumber(rank), rankText = rankText }
    end
    local n = tonumber(name)
    if n then return { kind = "slot", id = n, name = tostring(n) } end
    if cmd == "use" then
        local iid = D.ItemIdFromName(name)
        if iid then return { kind = "item", id = iid, name = name } end
    end
    local sid = D.SpellIdFromName(name)
    if sid then return { kind = "spell", id = sid, name = name } end
    local iid = D.ItemIdFromName(name)
    if iid then return { kind = "item", id = iid, name = name } end
    return { kind = (cmd == "use") and "item" or "spell", name = name }
end
