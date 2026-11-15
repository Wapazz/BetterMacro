local _, ns = ...
local U, D = ns.U, ns.Data

-- Templates and the building blocks shared with the class catalog
-- (Core/Catalog.lua). A spell the character doesn't know becomes a hole: an
-- orange slot that says which kind of spell to put there.
local T = {}
ns.Templates = T

-- Spells per class and role (base rank IDs), used to pre-fill templates.
T.CLASS = {
    PALADIN = { harm = 20271, help = 19750, alt = 635, cc = 853, self = 19740, seq = { 20271, 853 } },
    PRIEST  = { harm = 589, help = 2061, alt = 17, cc = 9484, self = 1243, seq = { 589, 585 } },
    MAGE    = { harm = 116, help = 1459, alt = 133, cc = 118, interrupt = 2139, self = 1459, seq = { 116, 133 } },
    ROGUE   = { harm = 1752, alt = 2098, cc = 2094, interrupt = 1766, seq = { 1752, 1752, 2098 } },
    WARRIOR = { harm = 78, alt = 772, cc = 1715, interrupt = 6552, self = 6673, seq = { 772, 78 } },
    HUNTER  = { harm = 3044, alt = 1978, cc = 1513, self = 13165, seq = { 1130, 1978, 3044 } },
    WARLOCK = { harm = 686, alt = 172, cc = 5782, self = 687, seq = { 172, 980, 686 } },
    DRUID   = { harm = 5176, help = 5185, alt = 774, cc = 339, self = 1126, seq = { 8921, 5176 } },
    SHAMAN  = { harm = 403, help = 331, alt = 8050, interrupt = 8042, self = 324, seq = { 8050, 403 } },
}

function T.PlayerClass()
    return UnitClass and select(2, UnitClass("player")) or nil
end

function T.ClassSpells(cls)
    return T.CLASS[cls or T.PlayerClass() or ""] or {}
end

-- Name of the player's spell for a role, if known (the picker lists it first).
function T.RoleSpellName(role)
    local id = T.ClassSpells()[role]
    return id and D.IsKnown(id) and D.SpellName(id) or nil
end

-- A known spell, or a hole asking for that role.
function T.spell(id, role)
    if id and D.IsKnown(id) then
        local a = D.SpellAction(id)
        if a then return a end
    end
    return U.Hole(role)
end

function T.branch(unit, rel, life, action, extra)
    local b = { unit = unit, rel = rel, life = life, action = action and U.copy(action) or nil }
    if extra then for k, v in pairs(extra) do b[k] = v end end
    return b
end

function T.cast(branches, cmd) return { kind = "cast", cmd = cmd or "cast", branches = branches } end

function T.sequence(steps, reset)
    local line = U.NewSequenceLine()
    for k, v in pairs(reset or {}) do line.reset[k] = v end
    line.steps = steps
    return line
end

local spell, branch, cast = T.spell, T.branch, T.cast

T.list = {
    { key = "T_MO_HARM", build = function(c)
        local a = spell(c.harm, "harm")
        return { cast({ branch("mouseover", "harm", "alive", a), branch(nil, nil, nil, a) }) }
    end },
    { key = "T_MO_HELP", build = function(c)
        local a = spell(c.help, "help")
        return { cast({ branch("mouseover", "help", "alive", a), branch(nil, "help", "alive", a), branch("player", nil, nil, a) }) }
    end },
    { key = "T_SELF_ALT", build = function(c)
        local a = spell(c.help, "help")
        return { cast({ branch("player", nil, nil, a, { mod = "alt" }), branch("mouseover", "help", "alive", a), branch(nil, nil, nil, a) }) }
    end },
    { key = "T_TRINKETS", build = function(c)
        return {
            { kind = "cast", cmd = "use", branches = { branch(nil, nil, nil, { kind = "slot", id = 13, name = "13" }) } },
            { kind = "cast", cmd = "use", branches = { branch(nil, nil, nil, { kind = "slot", id = 14, name = "14" }) } },
            cast({ branch(nil, nil, nil, spell(c.harm, "harm")) }),
        }
    end },
    { key = "T_ATTACK", build = function(c)
        return { U.NewCommandLine("startattack"), cast({ branch(nil, nil, nil, spell(c.harm, "harm")) }) }
    end },
    { key = "T_INTERRUPT", build = function(c)
        local a = spell(c.interrupt, "interrupt")
        return { U.NewCommandLine("stopcasting"), cast({ branch("focus", "harm", "alive", a), branch(nil, nil, nil, a) }) }
    end },
    { key = "T_SHIFT", build = function(c)
        return { cast({ branch(nil, nil, nil, spell(c.alt, "alt"), { mod = "shift" }), branch(nil, nil, nil, spell(c.harm, "harm")) }) }
    end },
    { key = "T_SEQUENCE", build = function(c)
        local steps = {}
        for _, id in ipairs(c.seq or { false, false }) do steps[#steps + 1] = spell(id or nil, "harm") end
        return { T.sequence(steps, { target = true }) }
    end },
    { key = "T_FOCUS_CC", build = function(c)
        local a = spell(c.cc, "cc")
        return { cast({ branch("focus", "harm", "alive", a), branch(nil, nil, nil, a) }) }
    end },
}

-- Builds a new macro from a template, pre-filled for the player's class.
function T.Build(index)
    local t = T.list[index]
    if not t then return nil end
    local m = U.NewMacro("")
    m.lines = t.build(T.ClassSpells())
    return m
end

-- Plain-language explanation of a macro, as one text block (tooltips, previews).
function T.ExplainText(m)
    local E = ns.Explainer
    local items, warnings = E.Explain(m, { nature = D.Nature, slotName = D.SlotRealName })
    local out = {}
    for _, it in ipairs(items) do
        if it.kind == "header" then
            out[#out + 1] = "|cffffd100" .. it.text .. "|r"
        else
            out[#out + 1] = it.text
        end
    end
    for _, w in ipairs(warnings) do out[#out + 1] = "|cffff9e40! " .. w .. "|r" end
    return table.concat(out, "\n")
end
