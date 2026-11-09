local _, ns = ...
local U, G, P, D, L = ns.U, ns.Generator, ns.Parser, ns.Data, ns.L

-- WoW only stores macro text. The block layout is kept in BetterMacroDB and
-- reused as long as the text in game still matches; otherwise we rebuild
-- the blocks from the text (the game's version always wins).
local S = {}
ns.Storage = S

function S.Init()
    BetterMacroDB = BetterMacroDB or {}
    BetterMacroDB.macros = BetterMacroDB.macros or {}
    BetterMacroDB.minimap = BetterMacroDB.minimap or { angle = 200 }
    BetterMacroDB.history = BetterMacroDB.history or {}
    BetterMacroDB.trash = BetterMacroDB.trash or {}
end

S.MAX_VERSIONS = 8 -- earlier saved versions kept per macro
S.MAX_TRASH = 8    -- deleted macros kept

function S.Limits()
    return MAX_ACCOUNT_MACROS or 120, MAX_CHARACTER_MACROS or 18
end

local function charKey()
    local name = UnitName and UnitName("player") or "?"
    local realm = GetRealmName and GetRealmName() or "?"
    return name .. "-" .. realm
end

local function key(name, perChar)
    return (perChar and ("C:" .. charKey() .. ":") or "G:") .. (name or "")
end

local function normalize(body)
    local out = {}
    for line in ((body or "") .. "\n"):gmatch("([^\n]*)\n") do
        line = U.trim(line)
        if line ~= "" then out[#out + 1] = line end
    end
    return table.concat(out, "\n")
end

local function now()
    return (time and time()) or 0
end

-- Keeps the version a save is about to replace (newest first).
local function pushVersion(k, model, body)
    local list = BetterMacroDB.history[k] or {}
    if not (list[1] and normalize(list[1].body) == normalize(body)) then
        table.insert(list, 1, { t = now(), body = body or "", m = U.copy(model) })
        while #list > S.MAX_VERSIONS do table.remove(list) end
    end
    BetterMacroDB.history[k] = list
end

-- Earlier saved versions of the macro in this slot: { { t, body, m }, ... }, newest first.
function S.Versions(index)
    local name = index and GetMacroInfo(index)
    if not name then return {} end
    local maxA = S.Limits()
    return BetterMacroDB.history[key(name, index > maxA)] or {}
end

-- Deleted macros: { { t, name, perChar, body, m }, ... }, newest first.
function S.Trash()
    return BetterMacroDB.trash
end

function S.List()
    local maxA = S.Limits()
    local numA, numC = 0, 0
    if GetNumMacros then numA, numC = GetNumMacros() end
    local general, character = {}, {}
    for i = 1, numA do
        local name, icon, body = GetMacroInfo(i)
        if name then general[#general + 1] = { index = i, name = name, icon = icon, body = body } end
    end
    for i = maxA + 1, maxA + numC do
        local name, icon, body = GetMacroInfo(i)
        if name then character[#character + 1] = { index = i, name = name, icon = icon, body = body, perChar = true } end
    end
    return general, character
end

-- Returns the block model for a macro slot, and true if it was rebuilt from text.
function S.Load(index)
    local maxA = S.Limits()
    local name, icon, body = GetMacroInfo(index)
    if not name then return nil end
    local perChar = index > maxA
    local stored = BetterMacroDB.macros[key(name, perChar)]
    if stored and normalize(G.Build(stored)) == normalize(body) then
        local m = U.copy(stored)
        m.name, m.perChar = name, perChar
        return m, false
    end
    local m = P.Parse(body, D.Resolve, name)
    m.perChar = perChar
    m.icon = (icon == 134400) and U.DEFAULT_ICON or (icon or U.DEFAULT_ICON)
    return m, true
end

-- Writes the macro into the game. Returns the new slot index, or nil + error.
function S.Save(macro, index)
    if InCombatLockdown and InCombatLockdown() then return nil, L.ERR_COMBAT end
    local name = U.trim(macro.name)
    if name == "" then return nil, L.ERR_NAME end
    local body = G.Build(macro)
    if #body > 255 then return nil, L.ERR_LONG end

    local oldKey, before, beforeBody
    if index then
        local oldName, _, oldBody = GetMacroInfo(index)
        local maxA = S.Limits()
        local wasPerChar = index > maxA
        before, beforeBody = S.Load(index), oldBody or ""
        if wasPerChar ~= (macro.perChar and true or false) then
            -- Moving between General and Character: create in the new scope, then delete
            -- the old one. The two scopes have separate index ranges, so the old index
            -- stays valid after the create.
            local newIndex, err = S.Save(U.copy(macro), nil)
            if not newIndex then return nil, err end
            DeleteMacro(index)
            local movedKey, newKey = key(oldName, wasPerChar), key(name, macro.perChar)
            BetterMacroDB.macros[movedKey] = nil
            BetterMacroDB.history[newKey] = BetterMacroDB.history[movedKey]
            BetterMacroDB.history[movedKey] = nil
            if before and normalize(beforeBody) ~= normalize(body) then pushVersion(newKey, before, beforeBody) end
            return S.FindIndex(name, macro.perChar), nil
        end
        oldKey = key(oldName, wasPerChar)
    else
        local maxA, maxC = S.Limits()
        local numA, numC = GetNumMacros()
        if (macro.perChar and numC >= maxC) or (not macro.perChar and numA >= maxA) then
            return nil, L.ERR_FULL
        end
    end

    local ok, newIndex
    if index then
        ok, newIndex = pcall(EditMacro, index, name, macro.icon or U.DEFAULT_ICON, body)
    else
        ok, newIndex = pcall(CreateMacro, name, macro.icon or U.DEFAULT_ICON, body, macro.perChar and true or nil)
    end
    if not ok then return nil, tostring(newIndex) end

    if oldKey then BetterMacroDB.macros[oldKey] = nil end
    local saved = U.copy(macro)
    saved.name = name
    local newKey = key(name, macro.perChar)
    BetterMacroDB.macros[newKey] = saved
    if oldKey then
        -- The history follows the macro when it is renamed
        if oldKey ~= newKey then
            BetterMacroDB.history[newKey] = BetterMacroDB.history[oldKey]
            BetterMacroDB.history[oldKey] = nil
        end
        if before and normalize(beforeBody) ~= normalize(body) then
            pushVersion(newKey, before, beforeBody)
        end
    else
        BetterMacroDB.history[newKey] = nil -- a new macro starts with no history
    end
    return newIndex or S.FindIndex(name, macro.perChar), nil
end

function S.FindIndex(name, perChar)
    local general, character = S.List()
    for _, m in ipairs(perChar and character or general) do
        if m.name == name then return m.index end
    end
end

function S.Delete(index)
    if InCombatLockdown and InCombatLockdown() then return false, L.ERR_COMBAT end
    local name = GetMacroInfo(index)
    if not name then return false end
    local maxA = S.Limits()
    local perChar = index > maxA
    local _, _, body = GetMacroInfo(index)
    local model = S.Load(index)
    if model then
        table.insert(BetterMacroDB.trash, 1, { t = now(), name = name, perChar = perChar, body = body or "", m = model })
        while #BetterMacroDB.trash > S.MAX_TRASH do table.remove(BetterMacroDB.trash) end
    end
    BetterMacroDB.macros[key(name, perChar)] = nil
    BetterMacroDB.history[key(name, perChar)] = nil
    DeleteMacro(index)
    return true
end
