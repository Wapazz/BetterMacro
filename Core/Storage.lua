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
    BetterMacroDB.templates = BetterMacroDB.templates or {}
    BetterMacroDB.characters = BetterMacroDB.characters or {}
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

function S.CharacterKey() return charKey() end

function S.SnapshotCharacter()
    if not GetNumMacros or not GetMacroInfo then return end
    local _, character = S.List()
    local snapshot = {}
    for _, entry in ipairs(character) do
        local model = S.Load(entry.index)
        if model then snapshot[#snapshot + 1] = model end
    end
    BetterMacroDB.characters[charKey()] = snapshot
end

function S.OtherCharacters()
    local names = {}
    for name in pairs(BetterMacroDB.characters) do
        if name ~= charKey() then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

function S.CharacterMacros(name)
    return BetterMacroDB.characters[name] or {}
end

function S.SaveTemplate(macro)
    local name = U.trim(macro.name)
    if name == "" then return false end
    local templates = BetterMacroDB.templates
    local copy = U.copy(macro)
    copy.name = name
    for i, entry in ipairs(templates) do
        if entry.name == name then templates[i] = copy; return true end
    end
    templates[#templates + 1] = copy
    return true
end

function S.Templates() return BetterMacroDB.templates end
function S.DeleteTemplate(index) table.remove(BetterMacroDB.templates, index) end

local function key(name, perChar)
    return (perChar and ("C:" .. charKey() .. ":") or "G:") .. (name or "")
end

-- A fingerprint distinguishes same-named macros without relying on WoW's
-- movable list index. Identical copies intentionally share metadata until one
-- changes; the game exposes no stable ID that could distinguish them.
local function recordKey(name, icon, body, perChar)
    return "F:" .. key("", perChar) .. U.sig({ name = name, icon = icon, body = body })
end

local function normalize(body)
    local out = {}
    for raw in ((body or "") .. "\n"):gmatch("([^\n]*)\n") do
        local line = U.trim(raw)
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
    if not index then return {} end
    local name, icon, body = GetMacroInfo(index)
    if not name then return {} end
    local maxA = S.Limits()
    local perChar = index > maxA
    local k = recordKey(name, icon, body, perChar)
    return BetterMacroDB.history[k] or (S.FindIndex(name, perChar) and BetterMacroDB.history[key(name, perChar)]) or {}
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
    local stored = BetterMacroDB.macros[recordKey(name, icon, body, perChar)]
        or BetterMacroDB.macros[key(name, perChar)]
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

    local oldKey, before, beforeBody, oldVersions
    if index then
        local oldName, oldIcon, oldBody = GetMacroInfo(index)
        if not oldName then return nil, L.ERR_MACRO_CHANGED end
        local maxA = S.Limits()
        local wasPerChar = index > maxA
        oldKey = recordKey(oldName, oldIcon, oldBody, wasPerChar)
        oldVersions = U.copy(S.Versions(index))
        before, beforeBody = S.Load(index), oldBody or ""
        if wasPerChar ~= (macro.perChar and true or false) then
            -- Moving between General and Character: create in the new scope, then delete
            -- the old one. The two scopes have separate index ranges, so the old index
            -- stays valid after the create.
            local newIndex, err = S.Save(U.copy(macro), nil)
            if not newIndex then return nil, err end
            DeleteMacro(index)
            local newName, newIcon, newBody = GetMacroInfo(newIndex)
            local newKey = recordKey(newName, newIcon, newBody, macro.perChar)
            BetterMacroDB.history[newKey] = oldVersions
            if before and normalize(beforeBody) ~= normalize(body) then pushVersion(newKey, before, beforeBody) end
            S.SnapshotCharacter()
            return newIndex, nil
        end
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

    if not newIndex then return nil, L.ERR_MACRO_CHANGED end
    local saved = U.copy(macro)
    saved.name = name
    local savedName, savedIcon, savedBody = GetMacroInfo(newIndex)
    if not savedName then return nil, L.ERR_MACRO_CHANGED end
    local newKey = recordKey(savedName, savedIcon, savedBody, macro.perChar)
    BetterMacroDB.macros[newKey] = saved
    if oldKey then
        if oldKey ~= newKey then
            BetterMacroDB.history[newKey] = oldVersions
        end
        if before and normalize(beforeBody) ~= normalize(body) then
            pushVersion(newKey, before, beforeBody)
        end
    end
    S.SnapshotCharacter()
    return newIndex or S.FindIndex(name, macro.perChar), nil
end

function S.FindIndex(name, perChar)
    local general, character = S.List()
    local found
    for _, m in ipairs(perChar and character or general) do
        if m.name == name then
            if found then return nil end
            found = m.index
        end
    end
    return found
end

-- Prefer the last slot for identical copies; otherwise follow the fingerprint.
function S.ResolveIdentity(identity)
    if not identity then return nil, L.ERR_MACRO_CHANGED end
    local general, character = S.List()
    local found
    for _, entry in ipairs(identity.perChar and character or general) do
        if entry.name == identity.name and entry.icon == identity.icon and entry.body == identity.body then
            if entry.index == identity.index then return entry.index end
            found = found or entry.index
        end
    end
    if found then identity.index = found; return found end
    return nil, L.ERR_MACRO_CHANGED
end

function S.Identity(index)
    local name, icon, body = GetMacroInfo(index)
    if not name then return nil end
    local maxA = S.Limits()
    return { name = name, icon = icon, body = body, perChar = index > maxA, index = index }
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
    DeleteMacro(index)
    S.SnapshotCharacter()
    return true
end
