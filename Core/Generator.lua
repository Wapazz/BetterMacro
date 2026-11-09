local _, ns = ...
local U = ns.U

local G = {}
ns.Generator = G

function G.ActionText(a)
    if not a then return "" end
    if a.kind == "slot" then return tostring(a.id or a.name or "") end
    return a.name or ""
end

-- Condition tokens for one branch, in a stable order.
function G.CondTokens(b)
    local t = {}
    if b.mod then t[#t + 1] = "mod:" .. b.mod end
    if b.unit then t[#t + 1] = "@" .. b.unit end
    if b.rel then t[#t + 1] = b.rel end
    -- A unit with no enemy/ally check still needs to exist, otherwise the
    -- branch matches an empty unit and the macro never reaches the fallback.
    if b.unit and b.unit ~= "player" and not b.rel then t[#t + 1] = "exists" end
    if b.life == "alive" then t[#t + 1] = "nodead" elseif b.life == "dead" then t[#t + 1] = "dead" end
    if b.combat == true then t[#t + 1] = "combat" elseif b.combat == false then t[#t + 1] = "nocombat" end
    if b.stealth == true then t[#t + 1] = "stealth" elseif b.stealth == false then t[#t + 1] = "nostealth" end
    if b.form ~= nil then t[#t + 1] = "form:" .. b.form end
    return t
end

function G.Cond(b)
    return "[" .. table.concat(G.CondTokens(b), ",") .. "]"
end

local function castLine(line, sep)
    local br = line.branches or {}
    local cmd = "/" .. (line.cmd or "cast")
    if #br == 0 then return cmd end
    if #br == 1 and not U.HasConditions(br[1]) and not br[1].unit then
        return cmd .. " " .. G.ActionText(br[1].action)
    end
    -- Same action everywhere: /cast [a][b][c] Spell
    local same = true
    local first = G.ActionText(br[1].action)
    for i = 2, #br do
        if G.ActionText(br[i].action) ~= first then same = false break end
    end
    if same then
        local conds = {}
        for i, b in ipairs(br) do conds[i] = G.Cond(b) end
        return cmd .. " " .. table.concat(conds) .. " " .. first
    end
    -- Different actions: /cast [a] SpellA; [b] SpellB; SpellC
    local parts = {}
    for i, b in ipairs(br) do
        local c = G.Cond(b)
        if c == "[]" then
            parts[i] = G.ActionText(b.action)
        else
            parts[i] = c .. " " .. G.ActionText(b.action)
        end
    end
    return cmd .. " " .. table.concat(parts, sep)
end

local function resetText(r)
    local p = {}
    if r.seconds and r.seconds > 0 then p[#p + 1] = tostring(r.seconds) end
    if r.target then p[#p + 1] = "target" end
    if r.combat then p[#p + 1] = "combat" end
    for _, m in ipairs(U.MODS) do if r[m] then p[#p + 1] = m end end
    if #p == 0 then return nil end
    return "reset=" .. table.concat(p, "/")
end

local function sequenceLine(line, sep)
    local out = "/castsequence"
    local c = G.Cond(line.branch or {})
    if c ~= "[]" then out = out .. " " .. c end
    local r = resetText(line.reset or {})
    if r then out = out .. " " .. r end
    local names = {}
    for i, a in ipairs(line.steps or {}) do names[i] = G.ActionText(a) end
    return out .. " " .. table.concat(names, sep == ";" and "," or ", ")
end

local function commandLine(line)
    local s = "/" .. line.cmd
    if line.cmd == "cancelaura" and line.action then s = s .. " " .. G.ActionText(line.action) end
    return s
end

function G.LineText(line, compact)
    local sep = compact and ";" or "; "
    if line.kind == "cast" then return castLine(line, sep) end
    if line.kind == "sequence" then return sequenceLine(line, sep) end
    if line.kind == "command" then return commandLine(line) end
    return line.text or ""
end

function G.Build(macro, compact)
    compact = compact or macro.compact
    local out = {}
    if macro.showtooltip then
        local s = compact and "#show" or "#showtooltip"
        local a = G.ActionText(macro.tooltipAction)
        if a ~= "" then s = s .. " " .. a end
        out[1] = s
    end
    for _, line in ipairs(macro.lines or {}) do
        out[#out + 1] = G.LineText(line, compact)
    end
    return table.concat(out, "\n")
end
