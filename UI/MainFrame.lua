local _, ns = ...
local W, U, G, E, S, D, T, L = ns.W, ns.U, ns.Generator, ns.Explainer, ns.Storage, ns.Data, ns.Templates, ns.L
local H, Sh = ns.History, ns.Share

local MF = {}
ns.MainFrame = MF

local state = { macro = nil, index = nil, scope = "general", live = nil, liveSig = "" }
ns.state = state

-- Undo history. A "lineage" is one macro being worked on: it starts when a macro
-- is opened or created, and idents[lineage] remembers which saved macro it is
-- (nil while it has never been saved). Undo steps carry their lineage, so going
-- back across "New macro" or a template click finds the right slot again by
-- name, even if the slot numbers moved in between.
state.hist = H.New()
state.lineage = 0
state.idents = {}

local function newLineage(identity)
    state.lineage = state.lineage + 1
    state.idents[state.lineage] = identity
end

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local QUESTION_TEX = "Interface\\Icons\\INV_Misc_QuestionMark"

local f -- main frame
local ui = {}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MAX_LEN = 255
local FRAME_W, LEFT_W = 1050, 228
local CENTER_X, CENTER_W = LEFT_W + 20, 500
local CONTENT_W = CENTER_W - 26

------------------------------------------------------------------ status line
-- A message stays 5 s, then the live test summary takes the line back.
local statusUntil = 0
function MF.Status(msg, r, g, b)
    if not ui.status then return end
    ui.status:SetText(msg or "")
    ui.status:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
    statusUntil = GetTime() + 5
end

------------------------------------------------------------------ list
local function scopeList()
    local general, character = S.List()
    return general, character
end

function MF.RefreshList()
    if not f then return end
    local identity = state.idents[state.lineage]
    if identity then state.index = S.ResolveIdentity(identity) end
    local general, character = scopeList()
    local maxA, maxC = S.Limits()
    ui.tabG:SetLabel(("%s %d/%d"):format(L.GENERAL, #general, maxA), false)
    ui.tabC:SetLabel(("%s %d/%d"):format(L.CHARACTER, #character, maxC), false)
    ui.tabG:SetStyle(state.scope == "general" and "accent" or "off")
    ui.tabC:SetStyle(state.scope == "character" and "accent" or "off")
    ui.tabC:ClearAllPoints()
    ui.tabC:SetPoint("LEFT", ui.tabG, "RIGHT", 4, 0)

    local list = state.otherCharacter and S.CharacterMacros(state.otherCharacter)
        or ((state.scope == "character") and character or general)
    ui.otherLabel:SetText(state.otherCharacter or L.OTHER_CHARACTERS)
    local content = ui.listScroll.content
    for _, r in ipairs(ui.listRows) do r:Hide() end
    for i, m in ipairs(list) do
        local r = ui.listRows[i]
        if not r then
            r = W.Flat(content, true)
            ui.listRows[i] = r
        end
        r:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
        r:SetSize(content:GetWidth(), 20)
        r:SetStyle(not state.otherCharacter and m.index == state.index and "accent" or "ghost")
        r.icon:SetTexture(m.icon or QUESTION_TEX)
        r.label:SetText(m.name)
        r.label:SetTextColor(1, 1, 1)
        r:SetScript("OnClick", function()
            if state.otherCharacter then
                if ns.locked then return end
                local copy = U.copy(m)
                state.scope, state.otherCharacter = "character", nil
                MF.New(copy)
                MF.Status(L.OTHER_COPY_HINT, 0.6, 0.8, 1)
            else
                MF.Select(m.index)
            end
        end)
        r:Show()
    end
    content:SetHeight(math.max(10, #list * 22))
    ui.listEmpty:SetShown(#list == 0)
end

------------------------------------------------------------------ explanation
local function explainRow(i)
    local fs = ui.explainRows[i]
    if not fs then
        fs = W.Text(ui.explainScroll.content, "GameFontHighlightSmall")
        fs:SetWidth(CONTENT_W - 18)
        fs:SetWordWrap(true)
        ui.explainRows[i] = fs
    end
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local function renderExplanation(text)
    local m = state.macro
    local items, warnings = E.Explain(m, {
        text = text, nature = D.Nature, slotName = D.SlotRealName, checkName = true,
    })
    for _, fs in ipairs(ui.explainRows) do fs:Hide() end
    ui.explainMap = {}
    local y, n = 0, 0
    local function put(str, font, color, item)
        n = n + 1
        local fs = explainRow(n)
        fs:SetFontObject(font)
        fs:SetText(str)
        fs:SetTextColor(unpack(color))
        fs:SetPoint("TOPLEFT", (item and item.kind ~= "header" and item.line) and 10 or 2, -y)
        fs.baseColor = color
        y = y + fs:GetStringHeight() + 5
        if item then ui.explainMap[#ui.explainMap + 1] = { item = item, fs = fs } end
    end
    for _, w in ipairs(warnings) do put("! " .. w, "GameFontHighlightSmall", { 1, 0.62, 0.25 }) end
    if #warnings > 0 then y = y + 4 end
    for _, it in ipairs(items) do
        if it.kind == "header" then
            put(it.text, "GameFontNormalSmall", { 1, 0.82, 0 }, it)
        elseif it.kind == "note" then
            put(it.text, "GameFontHighlightSmall", { 0.62, 0.62, 0.66 }, it)
        else
            put(it.text, "GameFontHighlightSmall", it.unreachable and { 0.5, 0.5, 0.5 } or { 0.95, 0.95, 0.95 }, it)
        end
    end
    ui.explainScroll.content:SetHeight(math.max(10, y))
end

local function applyLiveToExplanation()
    if not ui.explainMap then return end
    for _, e in ipairs(ui.explainMap) do
        local it = e.item
        local active = it.kind == "branch" and it.branch and state.live and state.live[it.line]
            and state.live[it.line].branch == it.branch
        if active then e.fs:SetTextColor(0.45, 1, 0.45) else e.fs:SetTextColor(unpack(e.fs.baseColor)) end
    end
end

function MF.UpdateLiveText()
    if not ui.status then return end
    if ns.locked then
        ui.status:SetText(L.LIVE_COMBAT)
        ui.status:SetTextColor(1, 0.5, 0.3)
        return
    end
    local parts = {}
    local m = state.macro
    for li in ipairs(m and m.lines or {}) do
        local r = state.live and state.live[li]
        if r then
            if r.branch then
                local s = L.LIVE_BRANCH:format(li, r.branch)
                local key = "UNIT_" .. tostring(r.unit)
                if rawget(L, key) then s = s .. L.LIVE_ON:format(L[key]) end
                parts[#parts + 1] = s
            else
                parts[#parts + 1] = L.LIVE_NONE:format(li)
            end
        end
    end
    ui.status:SetText(#parts > 0 and (L.LIVE .. table.concat(parts, " | ")) or "")
    ui.status:SetTextColor(0.45, 1, 0.45)
end

local function tickLive()
    if not state.macro then return end
    local ev = ns.Evaluator.Evaluate(state.macro)
    local sig = {}
    for li, r in pairs(ev) do sig[#sig + 1] = li .. ":" .. tostring(r.branch) .. ":" .. tostring(r.unit) end
    table.sort(sig)
    sig = table.concat(sig, ",")
    local sigChanged = sig ~= state.liveSig
    if sigChanged then
        state.liveSig = sig
        state.live = ev
        ns.Builder.SetLive(ev)
        applyLiveToExplanation()
    end
    if GetTime() > statusUntil and statusUntil ~= -1 then
        statusUntil = -1
        MF.UpdateLiveText()
    elseif statusUntil == -1 and sigChanged then
        MF.UpdateLiveText()
    end
end

------------------------------------------------------------------ refresh
local function iconTexture(m)
    if not m.icon or m.icon == U.DEFAULT_ICON then return QUESTION_TEX end
    return m.icon
end

-- Length gauge: green, orange when close to the limit, red when over it.
local function updateGauge(n)
    local r, g, b = 0.45, 1, 0.45
    if n > MAX_LEN then r, g, b = 1, 0.3, 0.3
    elseif n > 230 then r, g, b = 1, 0.75, 0.2 end
    ui.gauge:SetValue(math.min(n, MAX_LEN))
    ui.gauge:SetStatusBarColor(r, g, b)
    if n > MAX_LEN then
        ui.count:SetText(L.GAUGE_OVER:format(n, MAX_LEN, n - MAX_LEN))
    else
        ui.count:SetText(L.GAUGE_LEFT:format(n, MAX_LEN, MAX_LEN - n))
    end
    ui.count:SetTextColor(r, g, b)
end

local function setEnabled(b, on)
    if on then b:Enable() else b:Disable() end
end

local function updateUndoButtons()
    if not ui.undo then return end
    setEnabled(ui.undo, not ns.locked and H.CanUndo(state.hist))
    setEnabled(ui.redo, not ns.locked and H.CanRedo(state.hist))
end

-- A text box being edited only writes into the macro when it loses focus:
-- make it do so before we save, share or undo.
local function commitFocus()
    local e = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if e and e.ClearFocus then e:ClearFocus() end
end

function MF.Refresh()
    if not f or not state.macro then return end
    local m = state.macro
    if not ui.name:HasFocus() then ui.name:SetText(m.name or "") end
    ui.tooltipCheck:SetChecked(m.showtooltip and true or false)
    ui.charCheck:SetChecked(m.perChar and true or false)
    ui.rankCheck:SetChecked(m.downrank and true or false)
    ui.icon:SetNormalTexture(iconTexture(m))

    ns.Builder.Render(ui.builderScroll.content, {
        macro = m,
        changed = MF.Refresh,
        openPicker = ns.Picker.Open,
        live = state.live,
    }, CONTENT_W)

    local text = G.Build(m)
    ui.text:SetText((text:gsub("|", "||")))
    updateGauge(#text)
    ui.compress:SetShown(#text > MAX_LEN and not m.compact)
    H.Record(state.hist, m, nil, state.lineage)
    updateUndoButtons()
    renderExplanation(text)
    applyLiveToExplanation()
    state.liveSig = "" -- force a live update on next tick
end

------------------------------------------------------------------ actions
function MF.Select(index)
    local m, imported = S.Load(index)
    if not m then return end
    state.macro, state.index, state.otherCharacter = m, index, nil
    state.scope = m.perChar and "character" or "general"
    newLineage(S.Identity(index))
    ns.Picker.Close()
    MF.Refresh()
    MF.RefreshList()
    if imported and #m.lines > 0 then MF.Status(L.IMPORTED, 0.6, 0.8, 1) end
end

function MF.New(macro)
    state.macro = macro or U.NewMacro("")
    state.otherCharacter = nil
    state.macro.perChar = (state.scope == "character")
    state.index = nil
    newLineage(nil)
    ns.Picker.Close()
    MF.Refresh()
    MF.RefreshList()
    ui.name:SetFocus()
end

function MF.Duplicate()
    if ns.locked or not state.macro then return end
    commitFocus()
    local copy = U.copy(state.macro)
    copy.name = ""
    state.scope = copy.perChar and "character" or "general"
    MF.New(copy)
    MF.Status(L.DUPLICATE_HINT, 0.6, 0.8, 1)
end

function MF.AddLine(line)
    if ns.locked or not state.macro then return end
    table.insert(state.macro.lines, line)
    MF.Refresh()
    if C_Timer then
        C_Timer.After(0, function()
            ui.builderScroll:SetVerticalScroll(ui.builderScroll:GetVerticalScrollRange())
        end)
    end
end

function MF.Save()
    commitFocus()
    local identity = state.idents[state.lineage]
    local index, err
    if identity then
        index, err = S.ResolveIdentity(identity)
        if not index then MF.Status(err, 1, 0.35, 0.35); return end
    end
    local idx
    idx, err = S.Save(state.macro, index)
    if idx then
        state.index = idx
        state.scope = state.macro.perChar and "character" or "general"
        state.idents[state.lineage] = S.Identity(idx)
        MF.Status(L.SAVED, 0.45, 1, 0.45)
        MF.RefreshList()
    else
        MF.Status(err, 1, 0.35, 0.35)
    end
end

StaticPopupDialogs["BETTERMACRO_DELETE"] = {
    text = "%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, data)
        if not data or state.lineage ~= data.lineage or state.idents[state.lineage] ~= data.identity then return end
        local index, err = S.ResolveIdentity(data.identity)
        if not index then MF.Status(err, 1, 0.35, 0.35); return end
        local ok
        ok, err = S.Delete(index)
        if not ok then MF.Status(err or L.ERR_MACRO_CHANGED, 1, 0.35, 0.35); return end
        state.idents[state.lineage] = nil
        MF.New()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

function MF.Delete()
    if ns.locked then return end
    local identity = state.idents[state.lineage]
    if not identity then MF.New() return end
    local index, err = S.ResolveIdentity(identity)
    if not index then MF.Status(err, 1, 0.35, 0.35); return end
    StaticPopup_Show("BETTERMACRO_DELETE", L.CONFIRM_DELETE:format(identity.name or ""), nil,
        { identity = identity, lineage = state.lineage })
end

------------------------------------------------------------------ undo, history, sharing
local function applyStep(macro, lineage)
    if not macro then return end
    state.macro, state.lineage = macro, lineage
    local id = state.idents[lineage]
    state.index = id and S.ResolveIdentity(id) or nil
    if state.index then state.scope = id.perChar and "character" or "general" end
    ns.Picker.Close()
    W.CloseMenu()
    MF.Refresh()
    MF.RefreshList()
end

function MF.Undo()
    if ns.locked or not state.macro then return end
    commitFocus()
    if not H.CanUndo(state.hist) then MF.Status(L.UNDO_NONE, 0.8, 0.8, 0.8) return end
    applyStep(H.Undo(state.hist))
end

function MF.Redo()
    if ns.locked or not state.macro then return end
    commitFocus()
    if not H.CanRedo(state.hist) then MF.Status(L.REDO_NONE, 0.8, 0.8, 0.8) return end
    applyStep(H.Redo(state.hist))
end

local function stamp(t)
    return (date and t and t > 0) and date("%d/%m %H:%M", t) or "?"
end

-- Puts an earlier version back in the editor. Nothing is written to the game
-- until the player saves, and the swap itself can be undone.
local function restoreVersion(v)
    local m = U.copy(v.m)
    m.name, m.perChar = state.macro.name, state.macro.perChar
    state.macro = m
    ns.Picker.Close()
    MF.Refresh()
    MF.Status(L.HIST_RESTORED, 0.6, 0.8, 1)
end

local function historyMenu(owner)
    commitFocus()
    local items = {}
    local identity = state.idents[state.lineage]
    if identity then
        local err
        state.index, err = S.ResolveIdentity(identity)
        if not state.index then MF.Status(err, 1, 0.35, 0.35); return end
    end
    if state.index then
        local saved = S.Load(state.index)
        if saved and G.Build(saved) ~= G.Build(state.macro) then
            items[#items + 1] = { text = L.HIST_SAVED, value = function() restoreVersion({ m = saved }) end }
        end
        for _, v in ipairs(S.Versions(state.index)) do
            items[#items + 1] = {
                text = L.HIST_VERSION:format(stamp(v.t), #(v.body or "")),
                value = function() restoreVersion(v) end,
            }
        end
    end
    for _, v in ipairs(S.Trash()) do
        items[#items + 1] = {
            text = L.HIST_DELETED:format((v.name or ""):gsub("|", "||"), stamp(v.t)),
            value = function()
                state.scope = v.perChar and "character" or "general"
                MF.New(U.copy(v.m))
                MF.Status(L.HIST_UNDELETED, 0.6, 0.8, 1)
            end,
        }
    end
    if #items == 0 then MF.Status(L.HIST_EMPTY, 0.8, 0.8, 0.8) return end
    W.OpenMenu(owner, items, function(run) run() end)
end

function MF.Share()
    if not state.macro then return end
    commitFocus()
    if #state.macro.lines == 0 then MF.Status(L.SHARE_EMPTY, 1, 0.75, 0.2) return end
    ns.ShareFrame.ShowExport(Sh.Encode(state.macro))
end

-- Opens a shared macro as a new, unsaved macro. Returns true, or false + message.
function MF.Import(code)
    if ns.locked then return false, L.ERR_COMBAT_EDIT end
    local m, rawLines = Sh.Decode(code)
    if not m then return false, L[rawLines] end
    MF.New(m)
    if rawLines > 0 then
        MF.Status(L.IMPORT_RAW:format(rawLines), 1, 0.75, 0.2)
    else
        MF.Status(L.IMPORT_OK, 0.45, 1, 0.45)
    end
    return true
end

-- Ctrl+Z / Ctrl+Y only while the window is open and out of combat. They are
-- override bindings (cleared when the window closes), so the keys keep their
-- normal use the rest of the time and the window never swallows other keys.
local function syncBindings()
    if not f or not ClearOverrideBindings or (InCombatLockdown and InCombatLockdown()) then return end
    pcall(ClearOverrideBindings, f)
    if f:IsShown() and not ns.locked and SetOverrideBindingClick then
        pcall(SetOverrideBindingClick, f, true, "CTRL-Z", "BetterMacroUndoKey")
        pcall(SetOverrideBindingClick, f, true, "CTRL-Y", "BetterMacroRedoKey")
        pcall(SetOverrideBindingClick, f, true, "CTRL-SHIFT-Z", "BetterMacroRedoKey")
    end
end

local function keyButton(name, run)
    local b = CreateFrame("Button", name, f)
    b:RegisterForClicks("AnyDown", "AnyUp")
    -- Depending on the client a key press sends "down", "up" or both: act once per press.
    local sawDown = false
    b:SetScript("OnClick", function(_, _, down)
        if down then
            sawDown = true
            run()
        else
            if not sawDown then run() end
            sawDown = false
        end
    end)
    return b
end

local function iconMenu(owner)
    local items = { { text = L.ICON_AUTO, value = U.DEFAULT_ICON, checked = state.macro.icon == U.DEFAULT_ICON } }
    local seen = {}
    local function addAction(a)
        if not a then return end
        local ic = D.Icon(a)
        if ic and ic ~= 134400 and not seen[ic] then
            seen[ic] = true
            items[#items + 1] = { text = ("|T%s:16|t %s"):format(ic, D.Label(a) or ""), value = ic, checked = state.macro.icon == ic }
        end
    end
    addAction(state.macro.tooltipAction)
    for _, line in ipairs(state.macro.lines) do
        for _, b in ipairs(line.branches or {}) do addAction(b.action) end
        for _, a in ipairs(line.steps or {}) do addAction(a) end
    end
    W.OpenMenu(owner, items, function(v) state.macro.icon = v; MF.Refresh() end)
end

function MF.SetLocked(locked)
    ns.locked = locked
    if not f then return end
    ui.lock:SetShown(locked)
    if locked then ui.save:Disable(); ui.delete:Disable() else ui.save:Enable(); ui.delete:Enable() end
    ui.name:EnableMouse(not locked)
    if locked then ui.name:ClearFocus(); W.CloseMenu(); ns.Picker.Close(); ns.ShareFrame.Hide() end
    updateUndoButtons()
    -- PLAYER_REGEN_DISABLED fires just before the combat lockdown, so the keys
    -- can still be given back here; they are set again when combat ends.
    syncBindings()
    MF.UpdateLiveText()
end

------------------------------------------------------------------ creation
local function sectionTitle(text, x, y)
    local fs = W.Text(f, "GameFontNormal", text)
    fs:SetPoint("TOPLEFT", x, y)
    return fs
end

local function createLeft()
    local tabW = (LEFT_W - 4) / 2
    ui.tabG = W.Flat(f)
    ui.tabG:SetSize(tabW, 20)
    ui.tabG:SetPoint("TOPLEFT", 10, -34)
    ui.tabG:SetScript("OnClick", function() state.scope = "general"; state.otherCharacter = nil; MF.RefreshList() end)
    ui.tabC = W.Flat(f)
    ui.tabC:SetSize(tabW, 20)
    ui.tabC:SetScript("OnClick", function() state.scope = "character"; state.otherCharacter = nil; MF.RefreshList() end)

    local others = W.Flat(f)
    others:SetSize(LEFT_W, 20)
    others:SetPoint("TOPLEFT", 10, -58)
    others:SetStyle("plain")
    ui.otherLabel = others.label
    others:SetScript("OnClick", function(self)
        local items = {}
        for _, name in ipairs(S.OtherCharacters()) do
            items[#items + 1] = { text = name, value = name, checked = name == state.otherCharacter }
        end
        if #items == 0 then MF.Status(L.OTHER_EMPTY, 1, 0.75, 0.2); return end
        W.OpenMenu(self, items, function(name)
            state.scope, state.otherCharacter = "character", name
            MF.RefreshList()
        end)
    end)
    W.Tooltip(others, L.OTHER_CHARACTERS, L.OTHER_TIP)

    local panel = W.Panel(f)
    panel:SetPoint("TOPLEFT", 10, -82)
    panel:SetSize(LEFT_W, 564)
    ui.listScroll = W.Scroll(panel, LEFT_W, 556)
    ui.listScroll:SetPoint("TOPLEFT", 4, -4)
    ui.listRows = {}
    ui.listEmpty = W.Text(panel, "GameFontDisableSmall", L.EMPTY_LIST)
    ui.listEmpty:SetPoint("TOP", 0, -12)

    local new = W.Button(f, L.NEW, 68, 24)
    new:SetPoint("BOTTOMLEFT", 10, 12)
    new:SetScript("OnClick", function() if not ns.locked then MF.New() end end)
    local import = W.Button(f, L.IMPORT, 74, 24)
    import:SetPoint("LEFT", new, "RIGHT", 4, 0)
    import:SetScript("OnClick", function() if not ns.locked then ns.ShareFrame.ShowImport(MF.Import) end end)
    W.Tooltip(import, L.IMPORT, L.IMPORT_TIP)
    local duplicate = W.Button(f, L.DUPLICATE, LEFT_W - 150, 24)
    duplicate:SetPoint("LEFT", import, "RIGHT", 4, 0)
    duplicate:SetScript("OnClick", MF.Duplicate)
    W.Tooltip(duplicate, L.DUPLICATE, L.DUPLICATE_HINT)
end

local function createHeader()
    local icon = W.IconButton(f, 36, QUESTION_TEX)
    icon:SetPoint("TOPLEFT", CENTER_X, -30)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnClick", function(self) if not ns.locked then iconMenu(self) end end)
    icon:SetScript("OnDragStart", function()
        if ns.locked then return end
        local identity = state.idents[state.lineage]
        if not identity then MF.Status(L.SAVE_FIRST, 1, 0.75, 0.2) return end
        local index, err = S.ResolveIdentity(identity)
        if not index then MF.Status(err, 1, 0.35, 0.35); return end
        state.index = index
        PickupMacro(state.index)
    end)
    W.Tooltip(icon, L.DRAG_HINT, L.ICON_TIP)
    ui.icon = icon

    local nameLabel = W.Text(f, "GameFontDisableSmall", L.NAME)
    nameLabel:SetPoint("TOPLEFT", CENTER_X + 48, -28)
    ui.name = W.Edit(f, 150, 20)
    ui.name:SetPoint("TOPLEFT", CENTER_X + 52, -42)
    ui.name:SetMaxLetters(16)
    ui.name:SetScript("OnTextChanged", function(self, userInput)
        if userInput and state.macro then
            state.macro.name = self:GetText()
            renderExplanation(G.Build(state.macro))
            applyLiveToExplanation()
            H.Record(state.hist, state.macro, "name", state.lineage)
            updateUndoButtons()
        end
    end)

    ui.tooltipCheck = W.Check(f, L.SHOWTOOLTIP_CB)
    ui.tooltipCheck:SetPoint("TOPLEFT", CENTER_X + 216, -40)
    ui.tooltipCheck:SetScript("OnClick", function(self)
        if ns.locked then self:SetChecked(state.macro.showtooltip) return end
        state.macro.showtooltip = self:GetChecked() and true or false
        if not state.macro.showtooltip then state.macro.tooltipAction = nil end
        MF.Refresh()
    end)
    ui.charCheck = W.Check(f, L.PERCHAR)
    ui.charCheck:SetPoint("TOPLEFT", CENTER_X + 310, -40)
    ui.charCheck:SetScript("OnClick", function(self)
        if ns.locked then self:SetChecked(state.macro.perChar) return end
        state.macro.perChar = self:GetChecked() and true or false
        H.Record(state.hist, state.macro, nil, state.lineage)
        updateUndoButtons()
    end)
end

local function addLineMenu(owner)
    local items = {
        { text = L.K_CAST, value = function() return U.NewCastLine("cast") end },
        { text = L.K_USE, value = function() return U.NewCastLine("use") end },
        { text = L.K_SEQ, value = U.NewSequenceLine },
        { text = L.K_CMD, value = function() return U.NewCommandLine("startattack") end },
        { text = L.K_RAW, value = function() return U.NewRawLine("") end },
    }
    W.OpenMenu(owner, items, function(make) MF.AddLine(make()) end)
end

local function createCenter()
    local panel = W.Panel(f)
    panel:SetPoint("TOPLEFT", CENTER_X, -74)
    panel:SetSize(CENTER_W, 412)
    ui.builderScroll = W.Scroll(panel, CENTER_W - 4, 404)
    ui.builderScroll:SetPoint("TOPLEFT", 4, -4)
    ui.builderPanel = panel

    local add = W.Button(f, L.ADD_LINE, 110, 22)
    add:SetPoint("TOPLEFT", CENTER_X, -492)
    add:SetScript("OnClick", function(self) if not ns.locked then addLineMenu(self) end end)

    local share = W.Button(f, L.SHARE, 84, 22)
    share:SetPoint("LEFT", add, "RIGHT", 6, 0)
    share:SetScript("OnClick", MF.Share)
    W.Tooltip(share, L.SHARE, L.SHARE_TIP)

    ui.redo = W.Button(f, L.REDO, 80, 22)
    ui.redo:SetPoint("TOPRIGHT", f, "TOPLEFT", CENTER_X + CENTER_W, -492)
    ui.redo:SetScript("OnClick", MF.Redo)
    W.Tooltip(ui.redo, L.REDO, L.REDO_TIP)
    ui.undo = W.Button(f, L.UNDO, 80, 22)
    ui.undo:SetPoint("RIGHT", ui.redo, "LEFT", -4, 0)
    ui.undo:SetScript("OnClick", MF.Undo)
    W.Tooltip(ui.undo, L.UNDO, L.UNDO_TIP)
    local hist = W.Button(f, L.HISTORY, 90, 22)
    hist:SetPoint("RIGHT", ui.undo, "LEFT", -4, 0)
    hist:SetScript("OnClick", function(self) if not ns.locked then historyMenu(self) end end)
    W.Tooltip(hist, L.HISTORY, L.HISTORY_TIP)

    local ep = CreateFrame("Frame", "BetterMacroExplanationFrame", f, BACKDROP_TEMPLATE)
    ep:SetSize(CENTER_W, 300)
    ep:SetPoint("CENTER")
    ep:SetFrameStrata("DIALOG")
    ep:EnableMouse(true)
    W.Backdrop(ep, { 0.04, 0.04, 0.05, 0.98 }, { 0.45, 0.45, 0.5, 1 })
    ep:Hide()
    tinsert(UISpecialFrames, "BetterMacroExplanationFrame")
    local title = W.Text(ep, "GameFontNormal", L.EXPLAIN)
    title:SetPoint("TOPLEFT", 14, -12)
    local close = CreateFrame("Button", nil, ep, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    ui.explainScroll = W.Scroll(ep, CENTER_W - 20, 252)
    ui.explainScroll:SetPoint("TOPLEFT", 10, -34)
    ui.explainRows = {}
    local explain = W.Button(f, L.EXPLAIN, 180, 22)
    explain:SetPoint("TOPLEFT", CENTER_X, -522)
    explain:SetScript("OnClick", function() ep:SetShown(not ep:IsShown()) end)
    ui.rankCheck = W.Check(f, L.RANK_TITLE)
    ui.rankCheck:SetPoint("TOPLEFT", CENTER_X + 195, -522)
    ui.rankCheck:SetScript("OnClick", function(self)
        if ns.locked then self:SetChecked(state.macro.downrank); return end
        state.macro.downrank = self:GetChecked() and true or false
        MF.Refresh()
    end)
    W.Tooltip(ui.rankCheck, L.RANK_TITLE, L.RANK_TIP)

    local tt = W.Text(f, "GameFontDisableSmall", L.TEXT)
    tt:SetPoint("TOPLEFT", CENTER_X, -554)
    ui.count = W.Text(f, "GameFontHighlightSmall")
    ui.count:SetPoint("TOPRIGHT", f, "TOPLEFT", CENTER_X + CENTER_W, -554)

    -- Gauge of the 255 characters WoW allows, between the label and the count
    local track = W.Panel(f)
    track:SetPoint("TOPLEFT", CENTER_X + 104, -555)
    track:SetSize(CENTER_W - 104 - 150, 10)
    W.Backdrop(track, { 0.09, 0.09, 0.11, 0.95 }, { 0.3, 0.3, 0.33, 1 })
    ui.gauge = CreateFrame("StatusBar", nil, track)
    ui.gauge:SetPoint("TOPLEFT", 1, -1)
    ui.gauge:SetPoint("BOTTOMRIGHT", -1, 1)
    ui.gauge:SetStatusBarTexture(WHITE)
    ui.gauge:SetMinMaxValues(0, MAX_LEN)
    ui.gauge:SetValue(0)
    track:EnableMouse(true)
    W.Tooltip(track, L.GAUGE, L.GAUGE_TIP)
    ui.text = W.Text(f, "GameFontHighlightSmall")
    ui.text:SetPoint("TOPLEFT", CENTER_X, -568)
    ui.text:SetWidth(CENTER_W)
    ui.text:SetWordWrap(true)
    ui.text:SetTextColor(0.75, 0.9, 1)

    ui.status = W.Text(f, "GameFontHighlightSmall")
    ui.status:SetPoint("BOTTOMLEFT", CENTER_X, 18)
    ui.status:SetWidth(CENTER_W - 250)
    ui.status:SetWordWrap(false)

    ui.save = W.Button(f, L.SAVE, 110, 24)
    ui.save:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", CENTER_X + CENTER_W, 12)
    ui.save:SetScript("OnClick", MF.Save)
    ui.delete = W.Button(f, L.DELETE, 90, 24)
    ui.delete:SetPoint("RIGHT", ui.save, "LEFT", -6, 0)
    ui.delete:SetScript("OnClick", MF.Delete)
    ui.compress = W.Button(f, L.COMPRESS, 100, 24)
    ui.compress:SetPoint("RIGHT", ui.delete, "LEFT", -6, 0)
    ui.compress:SetScript("OnClick", function()
        if state.macro then state.macro.compact = true; MF.Refresh() end
    end)
end

local function createRight()
    local x = CENTER_X + CENTER_W + 14
    local w = FRAME_W - x - 12
    local scroll = W.Scroll(f, w, 628)
    scroll:SetPoint("TOPLEFT", x, -32)
    local content = scroll.content
    local contentW = w - 26
    local function title(label, y)
        local text = W.Text(content, "GameFontNormal", label)
        text:SetPoint("TOPLEFT", 0, y)
    end
    title(L.TEMPLATES, 0)
    local y = -20
    for i, t in ipairs(T.list) do
        local b = W.Flat(content)
        b:SetStyle("plain")
        b:SetLabel(L[t.key], false)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", 6, 0)
        b.label:SetPoint("RIGHT", -4, 0)
        b:SetSize(contentW, 20)
        b:SetPoint("TOPLEFT", 0, y)
        b:SetScript("OnClick", function()
            if ns.locked then return end
            MF.New(T.Build(i))
        end)
        y = y - 22
    end

    y = y - 12
    title(L.BLOCKS, y)
    y = y - 20
    local blocks = {
        { L.K_CAST, function() return U.NewCastLine("cast") end },
        { L.K_USE, function() return U.NewCastLine("use") end },
        { L.K_SEQ, U.NewSequenceLine },
        { L.K_RAW, function() return U.NewRawLine("") end },
    }
    for _, c in ipairs(U.COMMANDS) do
        blocks[#blocks + 1] = { L["CMDNAME_" .. c], function() return U.NewCommandLine(c) end, true }
    end
    for _, def in ipairs(blocks) do
        local b = W.Flat(content)
        b:SetStyle(def[3] and "off" or "action")
        b:SetLabel(def[1], false)
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", 6, 0)
        b:SetSize(contentW, 20)
        b:SetPoint("TOPLEFT", 0, y)
        b:SetScript("OnClick", function() MF.AddLine(def[2]()) end)
        y = y - 22
    end

    y = y - 12
    title(L.MY_TEMPLATES, y)
    y = y - 20
    local save = W.Button(content, L.SAVE_TEMPLATE, contentW, 22)
    save:SetPoint("TOPLEFT", 0, y)
    save:SetScript("OnClick", function()
        if ns.locked or not state.macro then return end
        commitFocus()
        if U.trim(state.macro.name) == "" then MF.Status(L.ERR_NAME, 1, 0.35, 0.35); return end
        for _, template in ipairs(S.Templates()) do
            if template.name == U.trim(state.macro.name) then
                StaticPopup_Show("BETTERMACRO_TEMPLATE_REPLACE", state.macro.name)
                return
            end
        end
        S.SaveTemplate(state.macro)
        ui.refreshTemplates()
        MF.Status(L.TEMPLATE_SAVED, 0.45, 1, 0.45)
    end)
    y = y - 26
    local rows = {}
    ui.refreshTemplates = function()
        for _, row in ipairs(rows) do row:Hide() end
        local templates = S.Templates()
        for i, template in ipairs(templates) do
            local row = rows[i]
            if not row then
                row = W.Flat(content)
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", 6, 0)
                row.label:SetPoint("RIGHT", -4, 0)
                rows[i] = row
            end
            row:SetStyle("plain")
            row:SetSize(contentW, 20)
            row:SetPoint("TOPLEFT", 0, y - (i - 1) * 22)
            row:SetLabel(template.name, false)
            row:SetScript("OnClick", function(_, button)
                if ns.locked then return end
                if button == "RightButton" then
                    StaticPopup_Show("BETTERMACRO_TEMPLATE_DELETE", template.name, nil, i)
                else
                    MF.New(U.copy(template))
                end
            end)
            row:Show()
        end
        content:SetHeight(math.max(628, -y + #templates * 22 + 8))
    end
    ui.refreshTemplates()
end

StaticPopupDialogs["BETTERMACRO_TEMPLATE_REPLACE"] = {
    text = L.TEMPLATE_REPLACE, button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function()
        if ns.locked or not state.macro then return end
        S.SaveTemplate(state.macro); ui.refreshTemplates(); MF.Status(L.TEMPLATE_SAVED, 0.45, 1, 0.45)
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["BETTERMACRO_TEMPLATE_DELETE"] = {
    text = L.TEMPLATE_DELETE, button1 = YES or "Yes", button2 = NO or "No",
    OnAccept = function(_, index)
        if ns.locked or not index then return end
        S.DeleteTemplate(index); ui.refreshTemplates()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function createLockOverlay()
    -- In combat the game forbids saving macros: we keep the window readable,
    -- the live test running, and block edits on the list, blocks and palette.
    local zones = {
        { 8, -28, CENTER_X - 4, -680 },                 -- macro list
        { CENTER_X - 2, -26, CENTER_X + CENTER_W + 2, -518 }, -- header + blocks
        { CENTER_X + CENTER_W + 8, -28, FRAME_W - 8, -680 },    -- palette
    }
    local frames = {}
    for i, z in ipairs(zones) do
        local lock = CreateFrame("Frame", nil, f, BACKDROP_TEMPLATE)
        lock:SetPoint("TOPLEFT", f, "TOPLEFT", z[1], z[2])
        lock:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", z[3], z[4])
        lock:SetFrameLevel(f:GetFrameLevel() + 50)
        lock:EnableMouse(true)
        W.Backdrop(lock, { 0.25, 0.05, 0.05, 0.25 }, { 0.8, 0.3, 0.2, 0.6 })
        if i == 2 then
            local t = W.Text(lock, "GameFontNormalLarge", L.IN_COMBAT)
            t:SetPoint("CENTER")
        end
        lock:Hide()
        frames[i] = lock
    end
    ui.lock = { SetShown = function(_, v) for _, l in ipairs(frames) do l:SetShown(v) end end }
end

function MF.Create()
    if f then return end
    f = CreateFrame("Frame", "BetterMacroFrame", UIParent, BACKDROP_TEMPLATE)
    W.Backdrop(f, { 0.04, 0.04, 0.05, 0.97 }, { 0.4, 0.4, 0.45, 1 })
    f:SetSize(FRAME_W, 700)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    tinsert(UISpecialFrames, "BetterMacroFrame")

    local title = W.Text(f, "GameFontNormal", L.TITLE)
    title:SetPoint("TOP", 0, -8)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    createLeft()
    createHeader()
    createCenter()
    createRight()
    createLockOverlay()

    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc >= 0.2 then acc = 0; tickLive() end
    end)
    keyButton("BetterMacroUndoKey", MF.Undo)
    keyButton("BetterMacroRedoKey", MF.Redo)
    f:SetScript("OnShow", syncBindings)
    f:SetScript("OnHide", function() W.CloseMenu(); ns.Picker.Close(); ns.ShareFrame.Hide(); syncBindings() end)
    MF.SetLocked(InCombatLockdown and InCombatLockdown() or false)
end

function MF.Open(index)
    MF.Create()
    f:Show()
    if index then
        MF.Select(index)
    elseif not state.macro then
        MF.New()
    else
        MF.Refresh()
        MF.RefreshList()
    end
end

function MF.Toggle()
    if f and f:IsShown() then f:Hide() else MF.Open() end
end

function MF.IsShown()
    return f and f:IsShown()
end
