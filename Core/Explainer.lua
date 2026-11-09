local _, ns = ...
local U, L = ns.U, ns.L

local E = {}
ns.Explainer = E

local function unitName(unit)
    return L["UNIT_" .. (unit or "target")]
end

local function actionName(a, opts)
    if not a or not a.name or a.name == "" then
        if a and a.kind == "slot" and a.id then return tostring(a.id) end
        return L.MISSING_ACTION
    end
    return a.name
end

-- "you hold Shift and the unit under your mouse is a living enemy"
function E.CondPhrase(b)
    local p = {}
    if b.mod then p[#p + 1] = L.C_HOLD:format(L["MOD_" .. b.mod]) end
    if b.rel or b.life or (b.unit and b.unit ~= "player") then
        local u = unitName(b.unit)
        local f
        if b.rel == "harm" then
            f = (b.life == "alive" and L.C_ENEMY_ALIVE) or (b.life == "dead" and L.C_ENEMY_DEAD) or L.C_ENEMY
        elseif b.rel == "help" then
            f = (b.life == "alive" and L.C_FRIEND_ALIVE) or (b.life == "dead" and L.C_FRIEND_DEAD) or L.C_FRIEND
        else
            f = (b.life == "alive" and L.C_ALIVE) or (b.life == "dead" and L.C_DEAD) or L.C_EXISTS
        end
        p[#p + 1] = f:format(u)
    end
    if b.combat == true then p[#p + 1] = L.C_COMBAT elseif b.combat == false then p[#p + 1] = L.C_NOCOMBAT end
    if b.stealth == true then p[#p + 1] = L.C_STEALTH elseif b.stealth == false then p[#p + 1] = L.C_NOSTEALTH end
    if b.form ~= nil then p[#p + 1] = (b.form == 0) and L.C_NOFORM or L.C_FORM:format(b.form) end
    return U.joinAnd(p, L.AND)
end

local function actionPhrase(cmd, b, opts)
    local a = b.action
    if a and a.kind == "slot" then
        local slot = L.SLOT_FALLBACK:format(a.id or 0)
        local nm = opts.slotName and opts.slotName(a.id)
        return L.A_SLOT:format(nm and (nm .. ", " .. slot) or slot)
    end
    local name = actionName(a, opts)
    -- The unit was already named in the condition: "... cast X on it"
    local named = b.unit and b.unit ~= "player"
    if cmd == "use" then
        if not b.unit then return L.A_USE:format(name) end
        return named and L.A_USE_IT:format(name) or L.A_USE_ON:format(name, unitName(b.unit))
    end
    return named and L.A_CAST_IT:format(name) or L.A_CAST_ON:format(name, unitName(b.unit))
end

local function explainCast(line, li, opts, items, warnings)
    local br = line.branches or {}
    local catchAt
    local missing = false
    for j, b in ipairs(br) do
        local cond = U.HasConditions(b) and E.CondPhrase(b) or ""
        local prefix
        if j == 1 then
            prefix = (cond ~= "") and L.IF:format(cond) or ""
        else
            prefix = (cond ~= "") and L.OTHERWISE_IF:format(cond) or L.OTHERWISE
        end
        local text = U.cap(prefix .. actionPhrase(line.cmd, b, opts))
        local unreachable = catchAt ~= nil
        if unreachable then text = text .. L.UNREACHABLE end
        items[#items + 1] = { kind = "branch", line = li, branch = j, text = text .. ".", unreachable = unreachable }

        if not b.action or (b.action.kind ~= "slot" and (b.action.name or "") == "") then missing = true end
        if not catchAt and U.IsCatchAll(b) then catchAt = j end

        local isSpell = b.action and b.action.kind == "spell"
        if b.unit and b.unit ~= "player" and not unreachable then
            if not b.rel and isSpell then warnings[#warnings + 1] = L.W_NO_REL:format(li, j, unitName(b.unit)) end
            if not b.life then warnings[#warnings + 1] = L.W_NO_LIFE:format(li, j, unitName(b.unit)) end
        end
        local nature = isSpell and opts.nature and opts.nature(b.action)
        if nature == "help" and b.rel == "harm" then
            warnings[#warnings + 1] = L.W_HELP_ON_ENEMY:format(li, j, b.action.name)
        elseif nature == "harm" and b.rel == "help" then
            warnings[#warnings + 1] = L.W_HARM_ON_ALLY:format(li, j, b.action.name)
        end
    end
    if missing then warnings[#warnings + 1] = L.W_NO_ACTION:format(li) end
    if catchAt and catchAt < #br then warnings[#warnings + 1] = L.W_UNREACHABLE:format(li, catchAt) end

    if not catchAt then
        items[#items + 1] = { kind = "note", line = li, text = L.NOTHING }
    else
        local last = br[catchAt]
        if not last.unit and line.cmd == "cast" and last.action and last.action.kind == "spell" then
            local nature = opts.nature and opts.nature(last.action)
            items[#items + 1] = { kind = "note", line = li, text = (nature == "help") and L.NOTARGET_HELP or L.NOTARGET_HARM }
        end
    end
end

local function explainSequence(line, li, opts, items, warnings)
    local names = {}
    for i, a in ipairs(line.steps or {}) do names[i] = actionName(a, opts) end
    if #names == 0 then
        warnings[#warnings + 1] = L.W_NO_ACTION:format(li)
        names[1] = L.MISSING_ACTION
    end
    local b = line.branch or {}
    local text = L.SEQ:format(table.concat(names, L.SEQ_THEN))
    if U.HasConditions(b) then
        text = L.IF:format(E.CondPhrase(b)) .. text:gsub("^%u", string.lower)
        items[#items + 1] = { kind = "branch", line = li, branch = 1, text = U.cap(text) }
        items[#items + 1] = { kind = "note", line = li, text = L.NOTHING }
    else
        items[#items + 1] = { kind = "branch", line = li, branch = 1, text = text }
    end
    local r = line.reset or {}
    local why = {}
    if r.seconds and r.seconds > 0 then why[#why + 1] = L.RESET_SECONDS:format(r.seconds) end
    if r.target then why[#why + 1] = L.RESET_TARGET end
    if r.combat then why[#why + 1] = L.RESET_COMBAT end
    for _, m in ipairs(U.MODS) do if r[m] then why[#why + 1] = L.RESET_MOD:format(L["MOD_" .. m]) end end
    items[#items + 1] = { kind = "note", line = li,
        text = (#why > 0) and L.SEQ_RESET:format(U.joinAnd(why, L.OR)) or L.SEQ_RESET_NONE }
end

-- Returns items (sentences, in order) and warnings.
-- opts.nature(action) -> "help"|"harm"|nil ; opts.slotName(id) -> string ; opts.text = generated text
function E.Explain(macro, opts)
    opts = opts or {}
    local items, warnings = {}, {}
    local lines = macro.lines or {}
    if #lines == 0 then
        warnings[1] = L.W_EMPTY
        return items, warnings
    end
    if macro.showtooltip then
        local a = macro.tooltipAction
        local t = a and L.SHOWTOOLTIP_FIXED:format(a.kind == "slot"
            and ((opts.slotName and opts.slotName(a.id)) or L.SLOT_FALLBACK:format(a.id or 0))
            or actionName(a, opts)) or L.SHOWTOOLTIP
        items[#items + 1] = { kind = "note", text = t }
    end

    local casts = 0
    for li, line in ipairs(lines) do
        if #lines > 1 then items[#items + 1] = { kind = "header", line = li, text = L.LINE_HEADER:format(li) } end
        if line.kind == "cast" then
            if line.cmd == "cast" then casts = casts + 1 end
            explainCast(line, li, opts, items, warnings)
        elseif line.kind == "sequence" then
            casts = casts + 1
            explainSequence(line, li, opts, items, warnings)
        elseif line.kind == "command" then
            local t
            if line.cmd == "cancelaura" then
                t = L.CMD_cancelaura:format(actionName(line.action, opts))
            else
                t = L["CMD_" .. line.cmd]
            end
            items[#items + 1] = { kind = "branch", line = li, text = t }
        else
            items[#items + 1] = { kind = "branch", line = li, text = L.RAW:format(line.text or "") }
        end
    end
    if casts > 1 then warnings[#warnings + 1] = L.W_MULTI_CAST end
    if opts.text and #opts.text > 255 then warnings[#warnings + 1] = L.W_TOO_LONG:format(#opts.text) end
    if opts.checkName and U.trim(macro.name) == "" then warnings[#warnings + 1] = L.W_NO_NAME end
    return items, warnings
end
