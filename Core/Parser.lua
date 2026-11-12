local _, ns = ...
local U = ns.U

-- Turns macro text back into blocks. Anything we don't fully understand
-- becomes a "raw text" block, so nothing is ever lost.
local P = {}
ns.Parser = P

local UNITS = { mouseover = true, player = true, focus = true, targettarget = true, pet = true }
local MODS = { shift = true, alt = true, ctrl = true }
local SIMPLE = {}
for _, c in ipairs(U.COMMANDS) do SIMPLE[c] = true end

local function defaultResolve(name, cmd)
    local n = tonumber(name)
    if n then return { kind = "slot", id = n, name = tostring(n) } end
    return { kind = (cmd == "use") and "item" or "spell", name = name }
end

local function parseToken(tok, b)
    tok = tok:lower():gsub("%s+", "")
    if tok == "" then return true end
    local unit = tok:match("^@(.+)$") or tok:match("^target=(.+)$")
    if unit then
        if unit == "target" then b.unit = nil return true end
        if not UNITS[unit] then return false end
        b.unit = unit
        return true
    end
    if tok == "help" or tok == "harm" then b.rel = tok return true end
    if tok == "exists" then b._exists = true return true end
    if tok == "nodead" then b.life = "alive" return true end
    if tok == "dead" then b.life = "dead" return true end
    local m = tok:match("^mod:(%a+)$") or tok:match("^modifier:(%a+)$")
    if m then
        if not MODS[m] or b.mod then return false end
        b.mod = m
        return true
    end
    if tok == "combat" then b.combat = true return true end
    if tok == "nocombat" then b.combat = false return true end
    if tok == "stealth" then b.stealth = true return true end
    if tok == "nostealth" then b.stealth = false return true end
    if tok == "noform" or tok == "nostance" then b.form = 0 return true end
    local f = tok:match("^form:(%d+)$") or tok:match("^stance:(%d+)$")
    if f then b.form = tonumber(f) return true end
    return false
end

local function parseGroup(content)
    local b = {}
    for tok in (content .. ","):gmatch("([^,]*),") do
        if not parseToken(tok, b) then return nil end
    end
    -- [exists] on the default target can't be expressed with our blocks
    if b._exists and not b.unit then return nil end
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

local function parseCast(cmd, rest, resolve)
    local line = { kind = "cast", cmd = cmd, branches = {} }
    for clause in (rest .. ";"):gmatch("([^;]*);") do
        local groups, actionText = splitClause(clause)
        if not groups or actionText == "" then return nil end
        local action = resolve(actionText, cmd)
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

local function parseSequence(rest, resolve)
    local groups, after = splitClause(rest)
    if not groups or #groups > 1 then return nil end
    local line = U.NewSequenceLine()
    if groups[1] then
        local b = parseGroup(groups[1])
        if not b then return nil end
        line.branch = b
    end
    local reset = after:match("^reset=(%S+)")
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
        local step = U.trim(rawStep)
        if step == "" then return nil end
        line.steps[#line.steps + 1] = resolve(step, "cast")
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
    if cmd == "cast" or cmd == "use" then
        line = parseCast(cmd, rest, resolve)
    elseif cmd == "castsequence" then
        line = parseSequence(rest, resolve)
    elseif cmd == "cancelaura" and rest ~= "" and not rest:find("[%[;]") then
        line = { kind = "command", cmd = "cancelaura", action = resolve(U.trim(rest), "cast") }
    elseif SIMPLE[cmd] and rest == "" then
        line = U.NewCommandLine(cmd)
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
            -- "#showtooltip [conditions] X" can't be expressed with blocks: kept as raw text
            if arg and not arg:find("[%[;]") then
                macro.showtooltip = true
                if arg ~= "" then macro.tooltipAction = (resolve or defaultResolve)(arg, "cast") end
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
