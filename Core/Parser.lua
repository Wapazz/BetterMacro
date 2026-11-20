local _, ns = ...
local U = ns.U

-- Turns macro text back into blocks. Anything we don't fully understand
-- becomes a "raw text" block, so nothing is ever lost.
local P = {}
ns.Parser = P

local MODS = { shift = true, alt = true, ctrl = true }
local SIMPLE = {}
for _, c in ipairs(U.COMMANDS) do SIMPLE[c] = true end
local GROUPS = { party = true, raid = true }

local function defaultResolve(name, cmd)
    local bag, slot = name:match("^(%d+)%s+(%d+)$")
    if bag then return { kind = "bag", bag = tonumber(bag), slot = tonumber(slot), name = bag .. " " .. slot } end
    local n = tonumber(name)
    if n then return { kind = "slot", id = n, name = tostring(n) } end
    return { kind = (cmd == "use" or cmd == "equip") and "item" or "spell", name = name }
end

-- "shiftalt" -> { "shift", "alt" }; nil if it isn't only modifier names.
local function splitMods(word)
    local keys = {}
    while word ~= "" do
        local found
        for k in pairs(MODS) do
            if word:sub(1, #k) == k then found = k break end
        end
        if not found then return nil end
        keys[#keys + 1] = found
        word = word:sub(#found + 1)
    end
    return keys
end

local function parseToken(tok, b)
    -- "equipped:Two-Handed Swords" keeps its spaces and case: it is the client's item type
    local eq = U.trim(tok):match("^[Ee][Qq][Uu][Ii][Pp][Pp][Ee][Dd]:%s*(.-)%s*$")
        or U.trim(tok):match("^[Ww][Oo][Rr][Nn]:%s*(.-)%s*$")
    if eq then
        if eq == "" or eq:find("[/%[%]]") then return false end -- "a/b" alternatives: raw text
        b.equipped = eq
        return true
    end
    -- "pet:Voidwalker": a pet name or family, kept as written
    local pn = U.trim(tok):match("^[Pp][Ee][Tt]:%s*(.-)%s*$")
    if pn then
        if pn == "" or pn:find("[/%[%]]") then return false end
        b.pet = pn
        return true
    end
    tok = tok:lower():gsub("%s+", "")
    if tok == "" then return true end
    local unit = tok:match("^@(.+)$") or tok:match("^target=(.+)$")
    if unit then
        if unit == "target" then b.unit = nil return true end
        if unit ~= "player" and not U.IsUnit(unit) then return false end
        b.unit = unit
        return true
    end
    if tok == "help" or tok == "harm" then b.rel = tok return true end
    if tok == "exists" then b._exists = true return true end
    if tok == "noexists" then b.exists = false return true end
    if tok == "channeling" then b.channel = true return true end
    if tok == "nochanneling" then b.channel = false return true end
    if tok == "mounted" then b.mounted = true return true end
    if tok == "nomounted" then b.mounted = false return true end
    if tok == "group" then b.group = true return true end
    if tok == "nogroup" then b.group = false return true end
    local grp = tok:match("^group:(%a+)$")
    if grp then
        if not GROUPS[grp] then return false end
        b.group = grp
        return true
    end
    if tok == "nodead" then b.life = "alive" return true end
    if tok == "dead" then b.life = "dead" return true end
    -- "mod:alt" ; "mod:alt/ctrl" = any of them ;
    -- "mod:alt,mod:ctrl" or "mod:altctrl" = all of them
    local m = tok:match("^mod:([%a/]+)$") or tok:match("^modifier:([%a/]+)$")
    if m then
        local keys = {}
        for k in m:gmatch("[^/]+") do keys[#keys + 1] = k end
        if #keys == 0 then return false end
        if #keys > 1 then
            for _, k in ipairs(keys) do
                if not MODS[k] then return false end -- "shiftalt/ctrl" can't be shown as blocks
            end
            if b.mod then return false end -- "any" mixed with other keys: keep as raw text
            b.mod = U.ModJoin(keys, "/")
        else
            local combo = splitMods(keys[1])
            if not combo then return false end
            if b.mod and b.mod:find("/", 1, true) then return false end
            local held = U.ModList(b.mod)
            for _, k in ipairs(combo) do
                local dup = false
                for _, h in ipairs(held) do if h == k then dup = true end end
                if not dup then held[#held + 1] = k end
            end
            b.mod = U.ModJoin(held, "+")
        end
        return true
    end
    if tok == "combat" then b.combat = true return true end
    if tok == "nocombat" then b.combat = false return true end
    if tok == "stealth" then b.stealth = true return true end
    if tok == "nostealth" then b.stealth = false return true end
    if tok == "noform" or tok == "nostance" then b.form = 0 return true end
    local f = tok:match("^form:(%d+)$") or tok:match("^stance:(%d+)$")
    if f then b.form = tonumber(f) return true end
    local nf = tok:match("^noform:(%d+)$") or tok:match("^nostance:(%d+)$")
    if nf then b.noform = tonumber(nf) return true end
    if tok == "nomod" or tok == "nomodifier" then b.nomod = true return true end
    local nm = tok:match("^nomod:(%a+)$") or tok:match("^nomodifier:(%a+)$")
    if nm then
        if not MODS[nm] then return false end
        b.nomod = nm
        return true
    end
    if tok == "swimming" then b.swim = true return true end
    if tok == "noswimming" then b.swim = false return true end
    if tok == "outdoors" then b.outdoors = true return true end
    if tok == "indoors" then b.outdoors = false return true end
    if tok == "pet" then b.pet = true return true end
    if tok == "nopet" then b.pet = false return true end
    local btn = tok:match("^button:(%d)$") or tok:match("^btn:(%d)$")
    if btn then b.button = tonumber(btn) return true end
    return false
end

local function parseGroup(content)
    local b = {}
    for tok in (content .. ","):gmatch("([^,]*),") do
        if not parseToken(tok, b) then return nil end
    end
    -- "exists" on a unit with no enemy/ally check is written back by itself
    -- (see Generator.CondTokens); anywhere else it is its own condition.
    if b._exists then
        if b.exists == false then return nil end -- "exists,noexists"
        if not b.unit or U.IsSelfUnit(b.unit) then b.exists = true end
    end
    b._exists = nil
    return b
end

-- "[a][b] Spell" -> list of condition groups (or {}), action text
local function splitClause(clause)
    clause = U.trim(clause)
    local groups = {}
    while clause:sub(1, 1) == "[" do
        local close = clause:find("]", 1, true)
        if not close then return nil end
        groups[#groups + 1] = clause:sub(2, close - 1)
        clause = U.trim(clause:sub(close + 1))
    end
    return groups, clause
end

-- "!Spell" never turns an active aura or stance off: keep the flag on the action.
local function resolveAction(text, cmd, resolve)
    local bang = text:sub(1, 1) == "!"
    if bang then text = U.trim(text:sub(2)) end
    if text == "" then return nil end
    local a = resolve(text, cmd)
    if a and bang and a.kind ~= "slot" then a.noToggle = true end
    return a
end

local function parseCast(cmd, rest, resolve)
    local line = { kind = "cast", cmd = cmd, branches = {} }
    local clauses = {}
    for clause in (rest .. ";"):gmatch("([^;]*);") do clauses[#clauses + 1] = clause end
    -- "A; B;": the game ignores the empty last case(s). An empty case in the
    -- middle does matter (it casts nothing and stops there), so it stays raw.
    while #clauses > 1 and U.trim(clauses[#clauses]) == "" do clauses[#clauses] = nil end
    local ci = 1
    while ci <= #clauses do
        local groups, actionText = splitClause(clauses[ci])
        if not groups or actionText == "" then return nil end
        -- A missing ";" ("A [mod:alt] B"): no spell name has "[", so cut there.
        local cut = actionText:find("[", 1, true)
        if cut then
            table.insert(clauses, ci + 1, actionText:sub(cut))
            actionText = U.trim(actionText:sub(1, cut - 1))
            if actionText == "" then return nil end
        end
        ci = ci + 1
        local action = resolveAction(actionText, cmd, resolve)
        if not action then return nil end
        if #groups == 0 then groups = { "" } end
        for _, g in ipairs(groups) do
            local b = parseGroup(g)
            if not b then return nil end
            b.action = U.copy(action)
            line.branches[#line.branches + 1] = b
        end
    end
    if #line.branches == 0 then return nil end
    return line
end

-- stepCmd: "cast" or "use"; random: /castrandom or /userandom (no reset).
local function parseSequence(rest, resolve, stepCmd, random)
    stepCmd = stepCmd or "cast"
    local groups, after = splitClause(rest)
    if not groups or #groups > 1 then return nil end
    local line = U.NewSequenceLine()
    if random then line.random = stepCmd end
    if groups[1] then
        local b = parseGroup(groups[1])
        if not b then return nil end
        line.branch = b
    end
    local reset = after:match("^reset=(%S+)")
    if reset and random then return nil end
    if reset then
        after = U.trim(after:sub(#reset + 7))
        for rawPart in (reset .. "/"):gmatch("([^/]*)/") do
            local part = rawPart:lower()
            local n = tonumber(part)
            if n then line.reset.seconds = n
            elseif part == "target" or part == "combat" or MODS[part] then line.reset[part] = true
            else return nil end
        end
    end
    for rawStep in (after .. ","):gmatch("([^,]*),") do
        local step = resolveAction(U.trim(rawStep), stepCmd, resolve)
        if not step then return nil end
        line.steps[#line.steps + 1] = step
    end
    if #line.steps == 0 then return nil end
    return line
end

function P.ParseLine(text, resolve)
    resolve = resolve or defaultResolve
    local cmd, rest = text:match("^/(%S+)%s*(.*)$")
    if not cmd then return U.NewRawLine(text) end
    cmd = cmd:lower()
    local line
    if cmd == "cast" or cmd == "use" or cmd == "equip" then
        line = parseCast(cmd, rest, resolve)
    elseif cmd == "castsequence" then
        line = parseSequence(rest, resolve)
    elseif (cmd == "castrandom" or cmd == "userandom") and not rest:find(";", 1, true) then
        line = parseSequence(rest, resolve, cmd == "userandom" and "use" or "cast", true)
    elseif SIMPLE[cmd] and not rest:find(";", 1, true) then
        -- "/cmd [a][b] arg": conditions are OR'ed; only /cancelaura takes an argument
        local groups, arg = splitClause(rest)
        if groups and ((cmd == "cancelaura") == (arg ~= "")) then
            line = U.NewCommandLine(cmd)
            if cmd == "cancelaura" then line.action = resolve(arg, "cast") end
            if #groups > 0 then
                line.conds = {}
                for _, g in ipairs(groups) do
                    local b = parseGroup(g)
                    if not b then line = nil; break end
                    line.conds[#line.conds + 1] = b
                end
            end
        end
    end
    return line or U.NewRawLine(text)
end

function P.Parse(body, resolve, name)
    local macro = U.NewMacro(name)
    macro.showtooltip = false
    local first = true
    for raw in ((body or "") .. "\n"):gmatch("([^\n]*)\n") do
        local text = U.trim(raw)
        if text ~= "" then
            local low = text:lower()
            local arg
            if first then
                local word, rest = low:match("^(#%a+)%s*(.*)$")
                if word == "#showtooltip" or word == "#show" then arg = U.trim(text:sub(#word + 1)) end
            end
            if arg then
                -- "#showtooltip [conditions] A; B" becomes the automatic tooltip,
                -- which already follows whatever the macro is about to cast.
                macro.showtooltip = true
                if arg ~= "" and not arg:find("[%[;]") then
                    macro.tooltipAction = (resolve or defaultResolve)(arg, "cast")
                end
            else
                macro.lines[#macro.lines + 1] = P.ParseLine(text, resolve)
            end
            first = false
        end
    end
    local function ranked(action) return action and action.kind == "spell" and action.rank end
    if ranked(macro.tooltipAction) then macro.downrank = true end
    for _, line in ipairs(macro.lines) do
        if ranked(line.action) then macro.downrank = true end
        for _, branch in ipairs(line.branches or {}) do
            if ranked(branch.action) then macro.downrank = true end
        end
        for _, action in ipairs(line.steps or {}) do
            if ranked(action) then macro.downrank = true end
        end
    end
    return macro
end
