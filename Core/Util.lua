local _, ns = ...

local U = {}
ns.U = U

function U.copy(t)
    if type(t) ~= "table" then return t end
    local r = {}
    for k, v in pairs(t) do r[k] = U.copy(v) end
    return r
end

function U.trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Uppercase the first letter (ASCII only; every sentence we build starts with one)
function U.cap(s)
    return (s:gsub("^%l", string.upper))
end

-- "a", "a and b", "a, b and c"
function U.joinAnd(list, sepAnd)
    local n = #list
    if n == 0 then return "" end
    if n == 1 then return list[1] end
    return table.concat(list, ", ", 1, n - 1) .. sepAnd .. list[n]
end

function U.len(s)
    return #s -- WoW counts bytes towards the 255 limit
end

--------------------------------------------------------------------------
-- Model
--
-- macro  = { name, icon, perChar, showtooltip, tooltipAction = action|nil, compact, lines = { line* } }
-- line   = { kind = "cast",     cmd = "cast"|"use", branches = { branch* } }
--        | { kind = "sequence", branch = branch(conditions only), reset = {...}, steps = { action* } }
--        | { kind = "command",  cmd = "startattack"|..., action = action|nil }
--        | { kind = "raw",      text = "..." }
-- branch = { unit = nil|"mouseover"|"player"|"focus"|"targettarget"|"pet",
--            rel = nil|"help"|"harm", life = nil|"alive"|"dead",
--            mod = nil|"shift"|"alt"|"ctrl", combat = nil|true|false,
--            stealth = nil|true|false, form = nil|number, action = action|nil }
-- action = { kind = "spell"|"item"|"slot", name = string, id = number|nil }
--------------------------------------------------------------------------

U.DEFAULT_ICON = "INV_MISC_QUESTIONMARK"

function U.NewMacro(name)
    return { name = name or "", icon = U.DEFAULT_ICON, perChar = false, showtooltip = true, lines = {} }
end

function U.NewBranch(unit, action)
    local b = { unit = unit, action = action and U.copy(action) or nil }
    U.ApplyGuards(b)
    return b
end

-- Safety defaults: any unit other than "my target" / "me" gets an enemy/ally
-- check and an "alive" check, both visible and removable in the UI.
function U.ApplyGuards(b, nature)
    if b.unit and b.unit ~= "player" then
        b.rel = nature or b.rel or "harm"
        b.life = "alive"
    else
        b.rel, b.life = nil, nil
    end
end

function U.NewCastLine(cmd, action)
    return { kind = "cast", cmd = cmd or "cast", branches = { U.NewBranch(nil, action) } }
end

function U.NewSequenceLine()
    return { kind = "sequence", branch = {}, reset = {}, steps = {} }
end

function U.NewCommandLine(cmd)
    return { kind = "command", cmd = cmd or "startattack" }
end

function U.NewRawLine(text)
    return { kind = "raw", text = text or "" }
end

U.UNITS = { false, "mouseover", "player", "focus", "targettarget", "pet" } -- false = my target
U.COMMANDS = { "startattack", "stopattack", "stopcasting", "cleartarget", "targetenemy",
    "petattack", "petfollow", "dismount", "cancelform", "cancelaura" }
U.MODS = { "shift", "alt", "ctrl" }

function U.HasConditions(b)
    return (b.unit and b.unit ~= "player") or b.rel or b.life or b.mod
        or b.combat ~= nil or b.stealth ~= nil or b.form ~= nil
end

-- A branch that always matches: the ones after it can never be reached.
function U.IsCatchAll(b)
    return not U.HasConditions(b)
end

-- Stable text signature of a model table (keys sorted), used to tell whether
-- two versions of a macro are the same.
function U.sig(v)
    local t = type(v)
    if t ~= "table" then return t:sub(1, 1) .. tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        return a < b
    end)
    local out = {}
    for i, k in ipairs(keys) do out[i] = tostring(k) .. "=" .. U.sig(v[k]) end
    return "{" .. table.concat(out, ";") .. "}"
end
