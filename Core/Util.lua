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
--            mod = nil|"shift"|"alt"|"ctrl"|"alt+ctrl" (all held)|"alt/ctrl" (any held),
--            combat = nil|true|false,
--            stealth = nil|true|false, form = nil|number, action = action|nil,
--            -- extra conditions (U.EXTRA_CONDS), shown only when set:
--            nomod = nil|true|"shift"|"alt"|"ctrl", noform = nil|number,
--            swim = nil|true|false, outdoors = nil|true|false (false = indoors),
--            pet = nil|true|false, button = nil|1|2|3 }
-- A command line can carry conditions too: line.conds = { branch* } (no action), OR'ed.
-- action = { kind = "spell"|"item"|"slot", name = string, id = number|nil,
--            noToggle = true|nil -- "!Spell": never turns an active aura/stance off }
--        | { kind = "hole", role = U.ROLES[i] }  -- left for the player to fill
--------------------------------------------------------------------------

-- Roles a hole can ask for. "help"/"self" are helpful, the others offensive.
U.ROLES = { "help", "harm", "alt", "cc", "interrupt", "self" }
U.ROLE_NATURE = { help = "help", self = "help", harm = "harm", alt = "harm", cc = "harm", interrupt = "harm" }

function U.Hole(role)
    return { kind = "hole", role = role or "harm" }
end

function U.IsHole(a)
    return a ~= nil and a.kind == "hole"
end

-- Calls fn(action) for every action of the macro (tooltip, branches, steps, aura).
function U.EachAction(macro, fn)
    if macro.tooltipAction then fn(macro.tooltipAction) end
    for _, line in ipairs(macro.lines or {}) do
        for _, b in ipairs(line.branches or {}) do if b.action then fn(b.action) end end
        for _, a in ipairs(line.steps or {}) do fn(a) end
        if line.action then fn(line.action) end
    end
end

function U.HasHoles(macro)
    local found = false
    U.EachAction(macro, function(a) if a.kind == "hole" then found = true end end)
    return found
end

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
    "petattack", "petfollow", "petpassive", "dismount", "cancelform", "cancelaura" }
U.MODS = { "shift", "alt", "ctrl" }

-- Modifier keys of a branch. b.mod holds one key, or several joined with
-- "+" (all must be held) or "/" (any of them). Returns the keys and the joiner.
function U.ModList(mod)
    if not mod then return {}, "+" end
    local sep = mod:find("/", 1, true) and "/" or "+"
    local keys = {}
    for k in mod:gmatch("[^+/]+") do keys[#keys + 1] = k end
    return keys, sep
end

-- Keys in a stable order (shift, alt, ctrl), joined; nil when there are none.
function U.ModJoin(keys, sep)
    local set = {}
    for _, k in ipairs(keys) do set[k] = true end
    local out = {}
    for _, k in ipairs(U.MODS) do if set[k] then out[#out + 1] = k end end
    if #out == 0 then return nil end
    return table.concat(out, sep or "+")
end

-- Adds the key if it is missing, removes it otherwise.
function U.ToggleMod(mod, key)
    local keys, sep = U.ModList(mod)
    local out, found = {}, false
    for _, k in ipairs(keys) do
        if k == key then found = true else out[#out + 1] = k end
    end
    if not found then out[#out + 1] = key end
    return U.ModJoin(out, sep)
end

-- Less common conditions: each has the values it can take, the first being
-- the one set when the player adds it.
U.EXTRA_CONDS = {
    { key = "nomod", values = { true, "shift", "alt", "ctrl" } },
    { key = "noform", values = { 1, 2, 3, 4, 5, 6 } },
    { key = "swim", values = { true, false } },
    { key = "outdoors", values = { true, false } },
    { key = "pet", values = { true, false } },
    { key = "button", values = { 2, 1, 3 } },
}

function U.HasConditions(b)
    return (b.unit and b.unit ~= "player") or b.rel or b.life or b.mod
        or b.combat ~= nil or b.stealth ~= nil or b.form ~= nil
        or b.nomod ~= nil or b.noform ~= nil or b.swim ~= nil
        or b.outdoors ~= nil or b.pet ~= nil or b.button ~= nil
end

-- A branch that always matches: the ones after it can never be reached.
function U.IsCatchAll(b)
    return not U.HasConditions(b)
end

-- Append without moving existing branches. An earlier fallback may need editing
-- before the new branch can be reached; the explainer reports that condition.
function U.AddBranch(line)
    local branches = line.branches
    local last = branches[#branches]
    branches[#branches + 1] = { action = last and U.copy(last.action) or nil }
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
