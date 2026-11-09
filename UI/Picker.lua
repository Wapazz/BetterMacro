local _, ns = ...
local W, D, L = ns.W, ns.Data, ns.L

-- Popup to choose a spell, a bag item or an equipped slot, with search.
-- A spell or item can also be dropped on it from the spellbook or bags.
local Pk = {}
ns.Picker = Pk

local ROWS_H = 22
local frame, rows, tabs, search, scroll, empty
local current = { tab = "spell", cb = nil, data = {} }

local function filtered()
    local q = (search:GetText() or ""):lower()
    if q == "" then return current.data end
    local out = {}
    for _, e in ipairs(current.data) do
        if ((e.label or e.name) or ""):lower():find(q, 1, true) then out[#out + 1] = e end
    end
    return out
end

local function choose(e)
    local cb = current.cb
    frame:Hide()
    if cb and e then cb({ kind = e.kind, id = e.id, name = e.name }) end
end

local function render()
    local list = filtered()
    local content = scroll.content
    for _, r in ipairs(rows) do r:Hide() end
    for i, e in ipairs(list) do
        local r = rows[i]
        if not r then
            r = W.Flat(content, true)
            r:SetStyle("ghost")
            rows[i] = r
        end
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROWS_H)
        r:SetSize(content:GetWidth(), ROWS_H - 2)
        r.icon:SetTexture(e.icon or 134400)
        r.label:SetText(e.label or e.name)
        r.label:SetTextColor(1, 1, 1)
        r:SetScript("OnClick", function() choose(e) end)
        r:Show()
    end
    content:SetHeight(math.max(10, #list * ROWS_H))
    empty:SetShown(#list == 0)
end

local function setTab(tab)
    current.tab = tab
    for k, t in pairs(tabs) do t:SetStyle(k == tab and "accent" or "off") end
    if tab == "spell" then current.data = D.ListSpells()
    elseif tab == "item" then current.data = D.ListItems()
    else current.data = D.ListSlots() end
    scroll:SetVerticalScroll(0)
    render()
end

local function create()
    frame = W.Panel(UIParent)
    frame:SetSize(300, 380)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    W.Backdrop(frame, { 0.05, 0.05, 0.06, 0.98 }, { 0.45, 0.45, 0.5, 1 })
    tinsert(UISpecialFrames, "BetterMacroPicker")
    _G.BetterMacroPicker = frame

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    tabs = {}
    local x = 8
    for _, def in ipairs({ { "spell", L.TAB_SPELLS }, { "item", L.TAB_ITEMS }, { "slot", L.TAB_SLOTS } }) do
        local t = W.Flat(frame)
        t:SetLabel(def[2], 70)
        t:SetPoint("TOPLEFT", x, -8)
        t:SetScript("OnClick", function() setTab(def[1]) end)
        tabs[def[1]] = t
        x = x + t:GetWidth() + 4
    end

    search = W.Edit(frame, 270, 20)
    search:SetPoint("TOPLEFT", 14, -34)
    search:SetScript("OnTextChanged", render)
    search:SetScript("OnEnterPressed", function() choose(filtered()[1]) end)
    local hint = W.Text(search, "GameFontDisableSmall", L.SEARCH)
    hint:SetPoint("LEFT", 2, 0)
    search:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)

    scroll = W.Scroll(frame, 290, 310)
    scroll:SetPoint("TOPLEFT", 8, -60)
    rows = {}
    empty = W.Text(frame, "GameFontDisableSmall", L.NO_RESULTS)
    empty:SetPoint("TOP", 0, -80)

    local function drop()
        local a = D.FromCursor()
        if a then
            local cb = current.cb
            frame:Hide()
            if cb then cb(a) end
        end
    end
    frame:SetScript("OnReceiveDrag", drop)
    frame:SetScript("OnMouseUp", drop)
end

-- tab: "spell" | "item" | "slot"
function Pk.Open(anchor, tab, cb)
    if not frame then create() end
    current.cb = cb
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    search:SetText("")
    frame:Show()
    setTab(tab or "spell")
    search:SetFocus()
end

function Pk.Close()
    if frame then frame:Hide() end
end
