local _, ns = ...
local U, D = ns.U, ns.Data

local T = {}
ns.Templates = T

-- Default spells per class (base rank IDs). A spell the character doesn't
-- know is left empty so the player picks it.
local CLASS = {
    PALADIN = { harm = 853, help = 19750, alt = 635, cc = 853, seq = { 20271, 853 } },
    PRIEST  = { harm = 589, help = 2061, alt = 17, cc = 9484, seq = { 589, 585 } },
    MAGE    = { harm = 116, help = 1459, alt = 133, cc = 118, interrupt = 2139, seq = { 116, 133 } },
    ROGUE   = { harm = 1752, alt = 2098, cc = 2094, interrupt = 1766, seq = { 1752, 1752, 2098 } },
    WARRIOR = { harm = 78, alt = 772, cc = 1715, interrupt = 6552, seq = { 772, 78 } },
    HUNTER  = { harm = 3044, alt = 1978, cc = 1513, seq = { 1130, 1978, 3044 } },
    WARLOCK = { harm = 686, alt = 172, cc = 5782, seq = { 172, 980, 686 } },
    DRUID   = { harm = 5176, help = 5185, alt = 774, cc = 339, seq = { 8921, 5176 } },
    SHAMAN  = { harm = 403, help = 331, alt = 8050, interrupt = 8042, seq = { 8050, 403 } },
}

local function classSpells()
    local cls = UnitClass and select(2, UnitClass("player"))
    return CLASS[cls or ""] or {}
end

local function spell(id)
    if id and D.IsKnown(id) then return D.SpellAction(id) end
    return nil
end

local function branch(unit, rel, life, action, extra)
    local b = { unit = unit, rel = rel, life = life, action = action and U.copy(action) or nil }
    if extra then for k, v in pairs(extra) do b[k] = v end end
    return b
end

local function cast(branches) return { kind = "cast", cmd = "cast", branches = branches } end

T.list = {
    { key = "T_MO_HARM", build = function(c)
        local a = spell(c.harm)
        return { cast({ branch("mouseover", "harm", "alive", a), branch(nil, nil, nil, a) }) }
    end },
    { key = "T_MO_HELP", build = function(c)
        local a = spell(c.help)
        return { cast({ branch("mouseover", "help", "alive", a), branch(nil, "help", "alive", a), branch("player", nil, nil, a) }) }
    end },
    { key = "T_SELF_ALT", build = function(c)
        local a = spell(c.help)
        return { cast({ branch("player", nil, nil, a, { mod = "alt" }), branch("mouseover", "help", "alive", a), branch(nil, nil, nil, a) }) }
    end },
    { key = "T_TRINKETS", build = function(c)
        return {
            { kind = "cast", cmd = "use", branches = { branch(nil, nil, nil, { kind = "slot", id = 13, name = "13" }) } },
            { kind = "cast", cmd = "use", branches = { branch(nil, nil, nil, { kind = "slot", id = 14, name = "14" }) } },
            cast({ branch(nil, nil, nil, spell(c.harm)) }),
        }
    end },
    { key = "T_ATTACK", build = function(c)
        return { U.NewCommandLine("startattack"), cast({ branch(nil, nil, nil, spell(c.harm)) }) }
    end },
    { key = "T_INTERRUPT", build = function(c)
        local a = spell(c.interrupt)
        return { U.NewCommandLine("stopcasting"), cast({ branch("focus", "harm", "alive", a), branch(nil, nil, nil, a) }) }
    end },
    { key = "T_SHIFT", build = function(c)
        return { cast({ branch(nil, nil, nil, spell(c.alt), { mod = "shift" }), branch(nil, nil, nil, spell(c.harm)) }) }
    end },
    { key = "T_SEQUENCE", build = function(c)
        local line = U.NewSequenceLine()
        line.reset.target = true
        for _, id in ipairs(c.seq or {}) do
            local a = spell(id)
            if a then line.steps[#line.steps + 1] = a end
        end
        return { line }
    end },
    { key = "T_FOCUS_CC", build = function(c)
        local a = spell(c.cc)
        return { cast({ branch("focus", "harm", "alive", a), branch(nil, nil, nil, a) }) }
    end },
}

-- Builds a new macro from a template, pre-filled for the player's class.
function T.Build(index)
    local t = T.list[index]
    if not t then return nil end
    local m = U.NewMacro("")
    m.lines = t.build(classSpells())
    return m
end
