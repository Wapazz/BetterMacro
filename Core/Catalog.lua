local _, ns = ...
local U, D, T, L = ns.U, ns.Data, ns.Templates, ns.L

-- Class catalog: ready-made macros per class, explained and checked against
-- the spellbook. Each entry builds its blocks with the same pieces as the
-- templates, so a spell not learned yet shows up as a hole.
--
-- entry = { id, class, role = "heal"|"tank"|"dps"|"utility", tags = { "group"|"solo"|"pvp"|"pet" },
--           spells = { spellID, ... }, build = function() return lines end }
-- Texts: L["CAT_" .. id] (name) and L["CATD_" .. id] (one-line description).
--
-- Spell IDs are base ranks and still need checking in game on WoW Forever.
local C = {}
ns.Catalog = C

C.CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
C.ROLES = { "heal", "tank", "dps", "utility" }
C.TAGS = { "group", "solo", "pvp", "pet" }

local sp, branch, cast = T.spell, T.branch, T.cast

------------------------------------------------------------------ patterns
-- Heal on mouseover, else on a friendly target, else on yourself.
local function healMO(id)
    local a = sp(id, "help")
    return { cast({ branch("mouseover", "help", "alive", a), branch(nil, "help", "alive", a), branch("player", nil, nil, a) }) }
end

-- Same, with Alt forcing it on yourself.
local function healAltSelf(id)
    local a = sp(id, "help")
    return { cast({ branch("player", nil, nil, a, { mod = "alt" }), branch("mouseover", "help", "alive", a),
        branch(nil, "help", "alive", a), branch("player", nil, nil, a) }) }
end

-- Offensive spell on mouseover, else on the target.
local function harmMO(id, role)
    local a = sp(id, role or "harm")
    return { cast({ branch("mouseover", "harm", "alive", a), branch(nil, nil, nil, a) }) }
end

-- On the focus if it is a living enemy, else on the target.
local function onFocus(id, role, stop)
    local a = sp(id, role or "cc")
    local lines = { cast({ branch("focus", "harm", "alive", a), branch(nil, nil, nil, a) }) }
    if stop then table.insert(lines, 1, U.NewCommandLine("stopcasting")) end
    return lines
end

-- Holding a modifier swaps to another spell.
local function modSwap(mod, idMod, roleMod, id, role)
    return { cast({ branch(nil, nil, nil, sp(idMod, roleMod), { mod = mod }), branch(nil, nil, nil, sp(id, role)) }) }
end

local function withCommand(cmd, lines)
    table.insert(lines, 1, U.NewCommandLine(cmd))
    return lines
end

local function single(id, role)
    return { cast({ branch(nil, nil, nil, sp(id, role)) }) }
end

------------------------------------------------------------------ entries
C.list = {
    -- Warrior
    { id = "WAR_CHARGE", class = "WARRIOR", role = "dps", tags = { "solo" }, spells = { 100, 78 },
        build = function()
            return withCommand("startattack", { cast({ branch(nil, nil, nil, sp(100, "alt"), { combat = false }),
                branch(nil, nil, nil, sp(78, "harm")) }) })
        end },
    { id = "WAR_TAUNT_MO", class = "WARRIOR", role = "tank", tags = { "group" }, spells = { 355 },
        build = function() return harmMO(355) end },
    { id = "WAR_PUMMEL", class = "WARRIOR", role = "utility", tags = { "group", "pvp" }, spells = { 6552 },
        build = function() return onFocus(6552, "interrupt") end },
    { id = "WAR_HAMSTRING", class = "WARRIOR", role = "dps", tags = { "pvp", "solo" }, spells = { 1715 },
        build = function() return withCommand("startattack", single(1715, "cc")) end },

    -- Paladin
    { id = "PAL_FOL_MO", class = "PALADIN", role = "heal", tags = { "group" }, spells = { 19750 },
        build = function() return healMO(19750) end },
    { id = "PAL_HL_ALT", class = "PALADIN", role = "heal", tags = { "group", "solo" }, spells = { 635 },
        build = function() return healAltSelf(635) end },
    { id = "PAL_HOJ_FOCUS", class = "PALADIN", role = "utility", tags = { "group", "pvp" }, spells = { 853 },
        build = function() return onFocus(853, "cc", true) end },
    { id = "PAL_JUDGE", class = "PALADIN", role = "dps", tags = { "solo" }, spells = { 20271 },
        build = function() return withCommand("startattack", single(20271, "harm")) end },
    { id = "PAL_BOP_MO", class = "PALADIN", role = "utility", tags = { "group" }, spells = { 1022 },
        build = function() return healMO(1022) end },

    -- Hunter
    { id = "HUN_MARK_PET", class = "HUNTER", role = "dps", tags = { "solo", "pet" }, spells = { 1130 },
        build = function() return withCommand("petattack", single(1130, "harm")) end },
    { id = "HUN_STING_MO", class = "HUNTER", role = "dps", tags = { "group" }, spells = { 1978 },
        build = function() return harmMO(1978) end },
    { id = "HUN_MEND_REVIVE", class = "HUNTER", role = "utility", tags = { "pet" }, spells = { 136, 982 },
        build = function() return modSwap("shift", 982, "alt", 136, "help") end },
    { id = "HUN_CALL_DISMISS", class = "HUNTER", role = "utility", tags = { "pet" }, spells = { 883, 2641 },
        build = function() return modSwap("shift", 2641, "alt", 883, "self") end },
    { id = "HUN_WINGCLIP", class = "HUNTER", role = "dps", tags = { "pvp", "solo" }, spells = { 2974 },
        build = function() return withCommand("startattack", single(2974, "cc")) end },

    -- Rogue
    { id = "ROG_SS_ATTACK", class = "ROGUE", role = "dps", tags = { "solo" }, spells = { 1752 },
        build = function() return withCommand("startattack", single(1752, "harm")) end },
    { id = "ROG_OPENER", class = "ROGUE", role = "dps", tags = { "solo", "pvp" }, spells = { 8676, 1752 },
        build = function()
            return { cast({ branch(nil, nil, nil, sp(8676, "alt"), { stealth = true }), branch(nil, nil, nil, sp(1752, "harm")) }) }
        end },
    { id = "ROG_KICK_FOCUS", class = "ROGUE", role = "utility", tags = { "group", "pvp" }, spells = { 1766 },
        build = function() return onFocus(1766, "interrupt") end },
    { id = "ROG_SAP_FOCUS", class = "ROGUE", role = "utility", tags = { "group", "pvp" }, spells = { 6770 },
        build = function() return onFocus(6770, "cc") end },

    -- Priest
    { id = "PRI_FLASH_MO", class = "PRIEST", role = "heal", tags = { "group" }, spells = { 2061 },
        build = function() return healMO(2061) end },
    { id = "PRI_SHIELD_MO", class = "PRIEST", role = "heal", tags = { "group", "solo" }, spells = { 17 },
        build = function() return healMO(17) end },
    { id = "PRI_RENEW_ALT", class = "PRIEST", role = "heal", tags = { "group", "solo" }, spells = { 139 },
        build = function() return healAltSelf(139) end },
    { id = "PRI_SWP_MO", class = "PRIEST", role = "dps", tags = { "group", "solo" }, spells = { 589 },
        build = function() return harmMO(589) end },
    { id = "PRI_SHACKLE_FOCUS", class = "PRIEST", role = "utility", tags = { "group" }, spells = { 9484 },
        build = function() return onFocus(9484, "cc") end },

    -- Shaman
    { id = "SHA_HW_MO", class = "SHAMAN", role = "heal", tags = { "group" }, spells = { 331 },
        build = function() return healMO(331) end },
    { id = "SHA_LHW_ALT", class = "SHAMAN", role = "heal", tags = { "group", "solo" }, spells = { 8004 },
        build = function() return healAltSelf(8004) end },
    { id = "SHA_ES_FOCUS", class = "SHAMAN", role = "utility", tags = { "group", "pvp" }, spells = { 8042 },
        build = function() return onFocus(8042, "interrupt", true) end },
    { id = "SHA_FS_MO", class = "SHAMAN", role = "dps", tags = { "group", "solo" }, spells = { 8050 },
        build = function() return harmMO(8050) end },
    { id = "SHA_LB_SHIFT", class = "SHAMAN", role = "dps", tags = { "solo" }, spells = { 403, 8042 },
        build = function() return modSwap("shift", 8042, "alt", 403, "harm") end },

    -- Mage
    { id = "MAG_POLY_FOCUS", class = "MAGE", role = "utility", tags = { "group", "pvp" }, spells = { 118 },
        build = function() return onFocus(118, "cc") end },
    { id = "MAG_CS_FOCUS", class = "MAGE", role = "utility", tags = { "group", "pvp" }, spells = { 2139 },
        build = function() return onFocus(2139, "interrupt", true) end },
    { id = "MAG_AI_MO", class = "MAGE", role = "utility", tags = { "group" }, spells = { 1459 },
        build = function() return healMO(1459) end },
    { id = "MAG_NOVA_SHIFT", class = "MAGE", role = "dps", tags = { "solo", "pvp" }, spells = { 116, 122 },
        build = function() return modSwap("shift", 122, "cc", 116, "harm") end },
    { id = "MAG_DECURSE_MO", class = "MAGE", role = "utility", tags = { "group" }, spells = { 475 },
        build = function() return healMO(475) end },

    -- Warlock
    { id = "WLK_FEAR_FOCUS", class = "WARLOCK", role = "utility", tags = { "group", "pvp" }, spells = { 5782 },
        build = function() return onFocus(5782, "cc") end },
    { id = "WLK_CORR_MO", class = "WARLOCK", role = "dps", tags = { "group" }, spells = { 172 },
        build = function() return harmMO(172) end },
    { id = "WLK_PET_SB", class = "WARLOCK", role = "dps", tags = { "solo", "pet" }, spells = { 686 },
        build = function() return withCommand("petattack", single(686, "harm")) end },
    { id = "WLK_TAP_SHIFT", class = "WARLOCK", role = "dps", tags = { "solo" }, spells = { 686, 1454 },
        build = function() return modSwap("shift", 1454, "self", 686, "harm") end },
    { id = "WLK_DOTS_SEQ", class = "WARLOCK", role = "dps", tags = { "solo" }, spells = { 172, 980, 686 },
        build = function()
            return { T.sequence({ sp(172, "harm"), sp(980, "harm"), sp(686, "harm") }, { target = true }) }
        end },

    -- Druid
    { id = "DRU_HT_MO", class = "DRUID", role = "heal", tags = { "group" }, spells = { 5185 },
        build = function() return healMO(5185) end },
    { id = "DRU_REJUV_ALT", class = "DRUID", role = "heal", tags = { "group", "solo" }, spells = { 774 },
        build = function() return healAltSelf(774) end },
    { id = "DRU_ROOTS_FOCUS", class = "DRUID", role = "utility", tags = { "group", "pvp" }, spells = { 339 },
        build = function() return onFocus(339, "cc") end },
    { id = "DRU_MOONFIRE_MO", class = "DRUID", role = "dps", tags = { "group", "solo" }, spells = { 8921 },
        build = function() return harmMO(8921) end },
    { id = "DRU_MOTW_MO", class = "DRUID", role = "utility", tags = { "group" }, spells = { 1126 },
        build = function() return healMO(1126) end },
}

------------------------------------------------------------------ text entries
-- Entries can also be written as macro text (see Core/CatalogImported.lua).
-- Spells and items are written {sID|English name} / {iID|English name}: the
-- ID gives the name in the player's language, the English name is the
-- fallback when the ID is unknown (0) or the game doesn't know it.
local TOKEN = "{([si])(%d+)|([^}]+)}"

local function tokens(e)
    if e._tokens then return e._tokens end
    local out = {}
    for kind, id, name in e.text:gmatch(TOKEN) do
        out[#out + 1] = { kind = kind, id = tonumber(id), name = name }
    end
    e._tokens = out
    return out
end

local function localName(t)
    local n
    if t.id > 0 then n = (t.kind == "s") and D.SpellName(t.id) or D.ItemName(t.id) end
    return n or t.name
end

local function spellKnown(t)
    if t.id > 0 then return D.IsKnown(t.id) end
    return D.IsKnownName(t.name)
end

local function buildText(e)
    local ids = {}
    local text = e.text:gsub(TOKEN, function(kind, id, name)
        local t = { kind = kind, id = tonumber(id), name = name }
        local n = localName(t)
        if t.id > 0 then ids[n] = t.id end
        return n
    end)
    local m = ns.Parser.Parse(text, D.Resolve, "")
    -- The parser only finds IDs for spells the character knows: add the others
    U.EachAction(m, function(a)
        if a.name and not a.id and ids[a.name] then a.id = ids[a.name] end
    end)
    return m
end

------------------------------------------------------------------ queries
function C.Name(e) return L["CAT_" .. e.id] end
-- Imported entries have no description of their own: the explanation says it all.
function C.Description(e) return rawget(L, "CATD_" .. e.id) end

function C.Build(e)
    if e.text then return buildText(e) end
    local m = U.NewMacro("")
    m.lines = e.build()
    return m
end

-- Names of the entry's spells the character hasn't learned yet.
function C.Missing(e)
    local out = {}
    if e.text then
        local seen = {}
        for _, t in ipairs(tokens(e)) do
            if t.kind == "s" and not seen[t.name] and not spellKnown(t) then
                seen[t.name] = true
                out[#out + 1] = localName(t)
            end
        end
        return out
    end
    for _, id in ipairs(e.spells or {}) do
        if not D.IsKnown(id) then out[#out + 1] = D.SpellName(id) or ("#" .. id) end
    end
    return out
end

function C.Usable(e) return #C.Missing(e) == 0 end

function C.Icon(e)
    if e.text then
        for _, t in ipairs(tokens(e)) do
            local ic = (t.kind == "s") and D.SpellIcon(t.id > 0 and t.id or t.name) or D.ItemIcon(t.id)
            if ic then return ic end
        end
        return 134400
    end
    return e.spells and e.spells[1] and D.SpellIcon(e.spells[1]) or 134400
end

-- Entries for the other faction (teleports, portals) are never shown.
local function rightFaction(e)
    if not e.faction then return true end
    local mine = UnitFactionGroup and UnitFactionGroup("player")
    return not mine or mine == e.faction
end

function C.HasTag(e, tag)
    for _, t in ipairs(e.tags or {}) do if t == tag then return true end end
    return false
end

-- filter = { class, role|nil, tag|nil, usableOnly, favorites|nil }
function C.Filter(filter)
    local out = {}
    for _, e in ipairs(C.list) do
        local ok = rightFaction(e)
            and (not filter.class or e.class == filter.class)
            and (not filter.role or e.role == filter.role)
            and (not filter.tag or C.HasTag(e, filter.tag))
            and (not filter.usableOnly or C.Usable(e))
        if ok then out[#out + 1] = e end
    end
    local fav = filter.favorites or {}
    table.sort(out, function(a, b)
        local fa, fb = fav[a.id] and 0 or 1, fav[b.id] and 0 or 1
        if fa ~= fb then return fa < fb end
        return C.Name(a) < C.Name(b)
    end)
    return out
end
