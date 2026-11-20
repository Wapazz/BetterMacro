local _, ns = ...
local U, L = ns.U, ns.L

local G = {}
ns.Generator = G

function G.ActionText(a)
    if not a or a.kind == "hole" then return "" end -- a hole blocks saving, see Storage.Save
    if a.kind == "slot" then return tostring(a.id or a.name or "") end
    local name = a.name or ""
    if a.kind == "spell" and a.rank and name ~= "" then
        name = name .. "(" .. (a.rankText or L.RANK_FORMAT:format(a.rank)) .. ")"
    end
    if a.noToggle and name ~= "" then name = "!" .. name end
    return name
end

-- Condition tokens for one branch, in a stable order.
-- compact writes keys held together as one token: "mod:shiftalt".
function G.CondTokens(b, compact)
    local t = {}
    if b.mod then
        local keys, sep = U.ModList(b.mod)
        if sep == "/" then
            t[#t + 1] = "mod:" .. table.concat(keys, "/")
        elseif compact then
            t[#t + 1] = "mod:" .. table.concat(keys)
        else
            for _, k in ipairs(keys) do t[#t + 1] = "mod:" .. k end
        end
    end
    if b.unit then t[#t + 1] = "@" .. b.unit end
    if b.rel then t[#t + 1] = b.rel end
    -- A unit with no enemy/ally check still needs to exist, otherwise the
    -- branch matches an empty unit and the macro never reaches the fallback.
    if b.exists == true or (b.exists == nil and b.unit and not U.IsSelfUnit(b.unit) and not b.rel) then
        t[#t + 1] = "exists"
    elseif b.exists == false then
        t[#t + 1] = "noexists"
    end
    if b.life == "alive" then t[#t + 1] = "nodead" elseif b.life == "dead" then t[#t + 1] = "dead" end
    if b.combat == true then t[#t + 1] = "combat" elseif b.combat == false then t[#t + 1] = "nocombat" end
    if b.stealth == true then t[#t + 1] = "stealth" elseif b.stealth == false then t[#t + 1] = "nostealth" end
    if b.form ~= nil then t[#t + 1] = "form:" .. b.form end
    if b.noform ~= nil then t[#t + 1] = "noform:" .. b.noform end
    if b.nomod == true then t[#t + 1] = "nomod" elseif b.nomod then t[#t + 1] = "nomod:" .. b.nomod end
    if b.swim == true then t[#t + 1] = "swimming" elseif b.swim == false then t[#t + 1] = "noswimming" end
    if b.outdoors == true then t[#t + 1] = "outdoors" elseif b.outdoors == false then t[#t + 1] = "indoors" end
    if b.pet == true then t[#t + 1] = "pet"
    elseif b.pet == false then t[#t + 1] = "nopet"
    elseif b.pet then t[#t + 1] = "pet:" .. b.pet end
    if b.button then t[#t + 1] = "button:" .. b.button end
    if b.channel == true then t[#t + 1] = "channeling" elseif b.channel == false then t[#t + 1] = "nochanneling" end
    if b.mounted == true then t[#t + 1] = "mounted" elseif b.mounted == false then t[#t + 1] = "nomounted" end
    if b.group == true then t[#t + 1] = "group"
    elseif b.group == false then t[#t + 1] = "nogroup"
    elseif b.group then t[#t + 1] = "group:" .. b.group end
    if b.equipped then t[#t + 1] = "equipped:" .. b.equipped end
    return t
end

function G.Cond(b, compact)
    return "[" .. table.concat(G.CondTokens(b, compact), ",") .. "]"
end

-- compact: "[a][b]SpellA;SpellB" instead of "[a][b] SpellA; SpellB".
local function castLine(line, compact)
    local sep = compact and ";" or "; "
    local br = line.branches or {}
    local cmd = "/" .. (line.cmd or "cast")
    if #br == 0 then return cmd end
    if #br == 1 and not U.HasConditions(br[1]) and not br[1].unit then
        return cmd .. " " .. G.ActionText(br[1].action)
    end
    -- Branches that follow each other with the same action share it:
    -- /cast [a][b] SpellA; [c] SpellB; SpellC
    local parts = {}
    local i = 1
    while i <= #br do
        local action = G.ActionText(br[i].action)
        local conds = {}
        local j = i
        while j <= #br and G.ActionText(br[j].action) == action do
            conds[#conds + 1] = G.Cond(br[j], compact)
            j = j + 1
        end
        if #conds == 1 and conds[1] == "[]" then
            parts[#parts + 1] = action
        else
            parts[#parts + 1] = table.concat(conds) .. (compact and "" or " ") .. action
        end
        i = j
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
    local out = line.random and ("/" .. line.random .. "random") or "/castsequence"
    local c = G.Cond(line.branch or {}, sep == ";")
    if c ~= "[]" then out = out .. " " .. c end
    local r = not line.random and resetText(line.reset or {})
    if r then out = out .. " " .. r end
    local names = {}
    for i, a in ipairs(line.steps or {}) do names[i] = G.ActionText(a) end
    return out .. " " .. table.concat(names, sep == ";" and "," or ", ")
end

-- Conditions of a command line, or nil when it always runs.
function G.CommandConds(line, compact)
    local conds = line.conds
    if not conds or #conds == 0 then return nil end
    if #conds == 1 and not U.HasConditions(conds[1]) and not conds[1].unit then return nil end
    local parts = {}
    for i, b in ipairs(conds) do parts[i] = G.Cond(b, compact) end
    return table.concat(parts)
end

local function commandLine(line, compact)
    local s = "/" .. line.cmd
    local c = G.CommandConds(line, compact)
    if c then s = s .. " " .. c end
    if line.cmd == "cancelaura" and line.action then s = s .. " " .. G.ActionText(line.action) end
    return s
end

function G.LineText(line, compact)
    local sep = compact and ";" or "; "
    if line.kind == "cast" then return castLine(line, compact) end
    if line.kind == "sequence" then return sequenceLine(line, sep) end
    if line.kind == "command" then return commandLine(line, compact) end
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
