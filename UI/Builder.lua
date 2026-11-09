local _, ns = ...
local W, U, D, L = ns.W, ns.U, ns.Data, ns.L

-- Draws the macro as blocks inside a scroll content frame.
-- Every edit changes the model then calls ctx.changed(), which redraws.
local B = {}
ns.Builder = B

local pools
local highlights = {} -- [line][branch] = frame
local ROW = 24

local function ensurePools(parent)
    if pools then return end
    pools = {
        card = W.Pool(function() return W.Panel(parent) end),
        flat = W.Pool(function() return W.Flat(parent) end),
        slot = W.Pool(function() return W.Flat(parent, true) end),
        text = W.Pool(function() return W.Text(parent, "GameFontNormalSmall") end),
        icon = W.Pool(function() return W.IconButton(parent, 16, "Interface\\Buttons\\UI-GroupLoot-Pass-Up") end),
        hl = W.Pool(function()
            local f = CreateFrame("Frame", nil, parent)
            f.tex = f:CreateTexture(nil, "BACKGROUND")
            f.tex:SetAllPoints()
            f.tex:SetColorTexture(0.15, 0.55, 0.25, 0.28)
            return f
        end),
        edit = W.Pool(function() return W.Edit(parent, 100, 20) end),
    }
end

local function releaseAll()
    for _, p in pairs(pools) do p:ReleaseAll() end
    highlights = {}
end

------------------------------------------------------------------ helpers
local function text(parent, str, x, y, template)
    local fs = pools.text:Acquire()
    fs:SetParent(parent)
    fs:SetFontObject(template or "GameFontNormalSmall")
    fs:SetText(str)
    fs:SetPoint("TOPLEFT", x, -y - 4)
    return fs
end

local function flat(parent, label, style, x, y, minW)
    local b = pools.flat:Acquire()
    b:SetParent(parent)
    b:SetFrameLevel(parent:GetFrameLevel() + 2)
    b.label:SetFontObject("GameFontHighlightSmall")
    b:SetStyle(style)
    b:SetLabel(label, minW)
    b:SetHeight(20)
    b:SetPoint("TOPLEFT", x, -y)
    b:SetScript("OnEnter", nil)
    b:SetScript("OnLeave", nil)
    return b
end

local function iconBtn(parent, texture, x, y, tip, onClick)
    local b = pools.icon:Acquire()
    b:SetParent(parent)
    b:SetFrameLevel(parent:GetFrameLevel() + 2)
    b:SetNormalTexture(texture)
    b:SetPoint("TOPLEFT", x, -y - 2)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(tip); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function chipTip(b)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(L.CHIP_TIP, 1, 1, 1); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function cycle(list, value)
    for i, v in ipairs(list) do
        if v == value then return list[i % #list + 1] end
    end
    return list[1]
end

-- Action slot: shows the chosen spell/item; click opens the picker, drop accepts
-- a spell or item from the cursor, right-click clears.
local function actionSlot(ctx, parent, action, x, y, w, tab, set, emptyLabel)
    local b = pools.slot:Acquire()
    b:SetParent(parent)
    b:SetFrameLevel(parent:GetFrameLevel() + 2)
    b:SetStyle(action and "action" or "off")
    b:SetSize(w, 20)
    b:SetPoint("TOPLEFT", x, -y)
    b.icon:SetTexture(D.Icon(action))
    b.label:SetText(D.Label(action) or emptyLabel or L.CHOOSE)
    local function fromCursor()
        local a = D.FromCursor()
        if a then set(a) return true end
    end
    b:SetScript("OnReceiveDrag", fromCursor)
    b:SetScript("OnClick", function(self, button)
        if ns.locked then return end
        if button == "RightButton" then set(nil) return end
        if fromCursor() then return end
        ctx.openPicker(self, tab, set)
    end)
    b:SetScript("OnEnter", nil)
    b:SetScript("OnLeave", nil)
    return b
end

-- Condition chips for a branch. Returns the y below the last chip row.
local function chips(ctx, parent, b, x0, y, width, nature)
    local x = x0
    local function add(label, style, onLeft, onRight)
        local c = flat(parent, label, style, 0, 0)
        if x + c:GetWidth() > width and x > x0 then
            x = x0
            y = y + ROW
        end
        c:SetPoint("TOPLEFT", x, -y)
        c:SetScript("OnClick", function(_, button)
            if ns.locked then return end
            if button == "RightButton" then onRight() else onLeft() end
            ctx.changed()
        end)
        chipTip(c)
        x = x + c:GetWidth() + 4
    end

    local relLabel = (b.rel == "harm" and L.CH_ENEMY) or (b.rel == "help" and L.CH_ALLY) or L.CH_REL
    add(relLabel, b.rel and "cond" or "off",
        function()
            -- Start with the kind that matches the spell, then the other one
            local first = nature or "harm"
            local other = first == "harm" and "help" or "harm"
            b.rel = cycle({ false, first, other }, b.rel or false) or nil
        end,
        function() b.rel = nil end)

    local lifeLabel = (b.life == "alive" and L.CH_ALIVE) or (b.life == "dead" and L.CH_DEAD) or L.CH_LIFE
    add(lifeLabel, b.life and "cond" or "off",
        function() b.life = cycle({ false, "alive", "dead" }, b.life or false) or nil end,
        function() b.life = nil end)

    for _, m in ipairs(U.MODS) do
        add(L["MOD_" .. m], b.mod == m and "mod" or "off",
            function() b.mod = (b.mod ~= m) and m or nil end,
            function() if b.mod == m then b.mod = nil end end)
    end

    local combatLabel = (b.combat == true and L.CH_COMBAT) or (b.combat == false and L.CH_NOCOMBAT) or L.CH_COMBATQ
    add(combatLabel, b.combat ~= nil and "cond" or "off",
        function()
            if b.combat == nil then b.combat = true elseif b.combat then b.combat = false else b.combat = nil end
        end,
        function() b.combat = nil end)

    local stealthLabel = (b.stealth == true and L.CH_STEALTH) or (b.stealth == false and L.CH_NOSTEALTH) or L.CH_STEALTHQ
    add(stealthLabel, b.stealth ~= nil and "cond" or "off",
        function()
            if b.stealth == nil then b.stealth = true elseif b.stealth then b.stealth = false else b.stealth = nil end
        end,
        function() b.stealth = nil end)

    add(b.form and L.CH_FORM:format(b.form) or L.CH_FORMQ, b.form and "cond" or "off",
        function()
            if b.form == nil then b.form = 0 elseif b.form >= 6 then b.form = nil else b.form = b.form + 1 end
        end,
        function() b.form = nil end)

    return y + ROW
end

local function unitMenu(ctx, owner, b)
    local items = {}
    for _, u in ipairs(U.UNITS) do
        local key = u or "target"
        items[#items + 1] = { text = L["UNITSHORT_" .. key], value = u, checked = (b.unit or false) == u }
    end
    W.OpenMenu(owner, items, function(v)
        b.unit = v or nil
        U.ApplyGuards(b, D.Nature(b.action))
        ctx.changed()
    end)
end

local function setAction(ctx, b)
    return function(a)
        b.action = a
        -- Keep the enemy/ally check in line with the spell
        local nature = D.Nature(a)
        if nature and b.rel and b.rel ~= nature then b.rel = nature end
        ctx.changed()
    end
end

------------------------------------------------------------------ line kinds
local function drawCast(ctx, card, line, li, W_, live)
    local y = 30
    local nature
    for j, b in ipairs(line.branches) do
        nature = D.Nature(b.action)
        local top = y
        local hl = pools.hl:Acquire()
        hl:SetParent(card)
        hl:SetFrameLevel(card:GetFrameLevel() + 1)
        highlights[li] = highlights[li] or {}
        highlights[li][j] = hl

        text(card, j == 1 and L.IF_W or L.ELSE_W, 8, y, "GameFontNormalSmall")
        text(card, L.ON, 58, y, "GameFontDisableSmall")
        local u = flat(card, L["UNITSHORT_" .. (b.unit or "target")], "plain", 80, y, 90)
        u:SetScript("OnClick", function(self) if not ns.locked then unitMenu(ctx, self, b) end end)
        local slotX = 80 + u:GetWidth() + 6
        local slotW = W_ - slotX - (#line.branches > 1 and 30 or 10)
        actionSlot(ctx, card, b.action, slotX, y, slotW, line.cmd == "use" and "item" or "spell", setAction(ctx, b))
        if #line.branches > 1 then
            iconBtn(card, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", W_ - 24, y, L.REMOVE, function()
                if ns.locked then return end
                table.remove(line.branches, j)
                ctx.changed()
            end)
        end
        y = chips(ctx, card, b, 58, y + ROW, W_ - 8, nature)
        hl:SetPoint("TOPLEFT", 2, -top + 2)
        hl:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", -2, -y + 2)
        hl:SetShown(live and live.branch == j)
        y = y + 4
    end
    local add = flat(card, L.ADD_BRANCH, "ghost", 54, y)
    add:SetScript("OnClick", function()
        if ns.locked then return end
        local br = line.branches
        local last = br[#br]
        local a = last and U.copy(last.action)
        if last and U.IsCatchAll(last) then
            -- Insert before the fallback so it stays reachable
            local nb = { unit = "mouseover", action = a }
            U.ApplyGuards(nb, D.Nature(a))
            table.insert(br, #br, nb)
        else
            br[#br + 1] = { action = a }
        end
        ctx.changed()
    end)
    return y + ROW
end

local function drawSequence(ctx, card, line, li, W_, live)
    local y = 30
    local b = line.branch
    local hl = pools.hl:Acquire()
    hl:SetParent(card)
    hl:SetFrameLevel(card:GetFrameLevel() + 1)
    highlights[li] = { hl }

    text(card, L.SEQ_IF, 8, y)
    local u = flat(card, L["UNITSHORT_" .. (b.unit or "target")], "plain", 80, y, 90)
    u:SetScript("OnClick", function(self) if not ns.locked then unitMenu(ctx, self, b) end end)
    y = chips(ctx, card, b, 80, y + ROW, W_ - 8, nil)
    hl:SetPoint("TOPLEFT", 2, -28)
    hl:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", -2, -y + 2)
    hl:SetShown(live and live.branch == 1)

    for k, a in ipairs(line.steps) do
        text(card, k .. ".", 58, y, "GameFontDisableSmall")
        actionSlot(ctx, card, a, 80, y, W_ - 120, "spell", function(na)
            if na then line.steps[k] = na else table.remove(line.steps, k) end
            ctx.changed()
        end)
        iconBtn(card, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", W_ - 34, y, L.REMOVE, function()
            if ns.locked then return end
            table.remove(line.steps, k)
            ctx.changed()
        end)
        y = y + ROW
    end
    local add = flat(card, L.ADD_STEP, "ghost", 76, y)
    add:SetScript("OnClick", function(self)
        if ns.locked then return end
        ctx.openPicker(self, "spell", function(a)
            if a then line.steps[#line.steps + 1] = a; ctx.changed() end
        end)
    end)
    y = y + ROW

    -- Reset options
    local r = line.reset
    text(card, L.RESET_W, 8, y)
    local x = 80
    local function toggle(label, keyName)
        local c = flat(card, label, r[keyName] and "cond" or "off", x, y)
        c:SetScript("OnClick", function()
            if ns.locked then return end
            r[keyName] = not r[keyName] or nil
            ctx.changed()
        end)
        x = x + c:GetWidth() + 4
    end
    toggle(L.RS_TARGET, "target")
    toggle(L.RS_COMBAT, "combat")
    for _, m in ipairs(U.MODS) do toggle(L["MOD_" .. m], m) end
    local e = pools.edit:Acquire()
    e:SetParent(card)
    e:SetFrameLevel(card:GetFrameLevel() + 2)
    e:SetSize(30, 20)
    e:SetNumeric(true)
    e:SetMaxLetters(3)
    e:SetPoint("TOPLEFT", x + 6, -y)
    e:SetText(r.seconds and tostring(r.seconds) or "")
    e:SetScript("OnEditFocusLost", function(self)
        local n = tonumber(self:GetText())
        r.seconds = (n and n > 0) and n or nil
        ctx.changed()
    end)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    text(card, L.SECONDS, x + 40, y, "GameFontDisableSmall")
    return y + ROW + 4
end

local function drawCommand(ctx, card, line, li, W_)
    local y = 30
    if line.cmd == "cancelaura" then
        actionSlot(ctx, card, line.action, 8, y, W_ - 16, "spell", function(a)
            line.action = a
            ctx.changed()
        end)
        y = y + ROW
    end
    return y + 4
end

local function drawRaw(ctx, card, line, li, W_)
    local e = pools.edit:Acquire()
    e:SetParent(card)
    e:SetFrameLevel(card:GetFrameLevel() + 2)
    e:SetNumeric(false)
    e:SetMaxLetters(255)
    e:SetSize(W_ - 24, 20)
    e:SetPoint("TOPLEFT", 14, -30)
    e:SetText(line.text or "")
    e:SetCursorPosition(0)
    e:SetScript("OnEditFocusLost", function(self)
        if line.text ~= self:GetText() then
            line.text = self:GetText()
            ctx.changed()
        end
    end)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return 30 + ROW + 4
end

local KIND_LABEL = { sequence = "K_SEQ", raw = "K_RAW" }

-- Tooltip block: always first, not movable. Empty = plain "#showtooltip".
local function drawTooltip(ctx, content, width)
    local m = ctx.macro
    local card = pools.card:Acquire()
    card:SetParent(content)
    card:SetFrameLevel(content:GetFrameLevel() + 1)
    card:SetPoint("TOPLEFT", 0, 0)
    card:SetWidth(width)
    local h = flat(card, L.K_TOOLTIP, "off", 6, 6)
    h.label:SetFontObject("GameFontNormalSmall")
    h:SetLabel(L.K_TOOLTIP)
    iconBtn(card, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", width - 24, 6, L.REMOVE, function()
        if ns.locked then return end
        m.showtooltip, m.tooltipAction = false, nil
        ctx.changed()
    end)
    text(card, L.TT_SHOW, 8, 30)
    actionSlot(ctx, card, m.tooltipAction, 80, 30, width - 90, "spell", function(a)
        m.tooltipAction = a
        ctx.changed()
    end, L.TT_AUTO)
    text(card, L.TT_HINT, 80, 52, "GameFontDisableSmall")
    card:SetHeight(74)
    return 74 + 6
end

local function header(ctx, card, line, li, W_, count)
    local label
    if line.kind == "cast" then label = (line.cmd == "use") and L.K_USE or L.K_CAST
    elseif line.kind == "command" then label = L["CMDNAME_" .. line.cmd]
    else label = L[KIND_LABEL[line.kind]] end
    local h = flat(card, label, (line.kind == "cast" or line.kind == "command") and "plain" or "off", 6, 6)
    h.label:SetFontObject("GameFontNormalSmall")
    h:SetLabel(label)
    if line.kind == "cast" then
        h:SetScript("OnClick", function(self)
            if ns.locked then return end
            W.OpenMenu(self, {
                { text = L.K_CAST, value = "cast", checked = line.cmd == "cast" },
                { text = L.K_USE, value = "use", checked = line.cmd == "use" },
            }, function(v) line.cmd = v; ctx.changed() end)
        end)
    elseif line.kind == "command" then
        h:SetScript("OnClick", function(self)
            if ns.locked then return end
            local items = {}
            for _, c in ipairs(U.COMMANDS) do
                items[#items + 1] = { text = L["CMDNAME_" .. c], value = c, checked = line.cmd == c }
            end
            W.OpenMenu(self, items, function(v) line.cmd = v; ctx.changed() end)
        end)
    end
    local lines = ctx.macro.lines
    local x = W_ - 24
    iconBtn(card, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", x, 6, L.REMOVE, function()
        if ns.locked then return end
        table.remove(lines, li); ctx.changed()
    end)
    if li < count then
        iconBtn(card, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", x - 20, 6, L.MOVE_DOWN, function()
            if ns.locked then return end
            lines[li], lines[li + 1] = lines[li + 1], lines[li]; ctx.changed()
        end)
    end
    if li > 1 then
        iconBtn(card, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up", x - 40, 6, L.MOVE_UP, function()
            if ns.locked then return end
            lines[li], lines[li - 1] = lines[li - 1], lines[li]; ctx.changed()
        end)
    end
    text(card, "#" .. li, x - 64, 6, "GameFontDisableSmall")
end

------------------------------------------------------------------ public
-- ctx = { macro, changed(), openPicker(anchor, tab, cb), live = { [li] = {branch} } }
function B.Render(content, ctx, width)
    ensurePools(content)
    releaseAll()
    local y = 0
    if ctx.macro.showtooltip then y = drawTooltip(ctx, content, width) end
    local lines = ctx.macro.lines
    for li, line in ipairs(lines) do
        local card = pools.card:Acquire()
        card:SetParent(content)
        card:SetFrameLevel(content:GetFrameLevel() + 1)
        card:SetPoint("TOPLEFT", 0, -y)
        card:SetWidth(width)
        local live = ctx.live and ctx.live[li]
        local h
        if line.kind == "cast" then h = drawCast(ctx, card, line, li, width, live)
        elseif line.kind == "sequence" then h = drawSequence(ctx, card, line, li, width, live)
        elseif line.kind == "command" then h = drawCommand(ctx, card, line, li, width)
        else h = drawRaw(ctx, card, line, li, width) end
        header(ctx, card, line, li, width, #lines)
        card:SetHeight(h)
        y = y + h + 6
    end
    content:SetHeight(math.max(y, 10))
    return y
end

-- Updates the live highlight without redrawing everything.
function B.SetLive(live)
    for li, byBranch in pairs(highlights) do
        local active = live and live[li] and live[li].branch
        for j, hl in pairs(byBranch) do hl:SetShown(active == j) end
    end
end
