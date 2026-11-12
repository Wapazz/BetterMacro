local _, ns = ...
local W, D, L = ns.W, ns.Data, ns.L

-- Icon picker: the macro's own spells first, then a grid of every macro icon
-- the game offers. The grid only creates the visible buttons and scrolls by
-- re-texturing them, since the full list holds thousands of icons.
local IP = {}
ns.IconPicker = IP

local COLS, ROWS, SIZE, GAP = 10, 7, 32, 4
local STEP = SIZE + GAP
local GRID_TOP = -112
local SUGGEST_MAX = 10
local WHITE = "Interface\\Buttons\\WHITE8X8"

local frame, search, searchHint, slider, empty
local grid, suggest = {}, {}
local list, offset, updating = {}, 0, false
local current = { cb = nil, selected = nil }

local function choose(v)
    local cb = current.cb
    frame:Hide()
    if cb and v then cb(v) end
end

local function iconButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetPoint("TOPLEFT", -2, 2)
    b.sel:SetPoint("BOTTOMRIGHT", 2, -2)
    b.sel:SetColorTexture(1, 0.82, 0, 1)
    b.sel:Hide()
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnClick", function(self) choose(self.value) end)
    b:SetScript("OnEnter", function(self)
        local label = self.label or (type(self.value) == "string" and self.value) or nil
        if not label then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

local function maxOffset()
    return math.max(0, math.ceil(#list / COLS) - ROWS)
end

local function render()
    offset = math.max(0, math.min(offset, maxOffset()))
    for i, b in ipairs(grid) do
        local v = list[offset * COLS + i]
        if v then
            b.value = v
            b.tex:SetTexture(D.IconTexture(v))
            b.sel:SetShown(v == current.selected)
            b:Show()
        else
            b:Hide()
        end
    end
    empty:SetShown(#list == 0)
    -- Moving the slider from here must not feed back into the offset
    updating = true
    slider:SetShown(maxOffset() > 0)
    slider:SetMinMaxValues(0, maxOffset())
    slider:SetValue(offset)
    updating = false
end

local function filter()
    local all = D.ListIcons()
    local q = (search:GetText() or ""):lower()
    if q == "" then
        list = all
    else
        list = {}
        for _, v in ipairs(all) do
            if tostring(v):lower():find(q, 1, true) then list[#list + 1] = v end
        end
    end
    offset = 0
    render()
end

local function create()
    frame = W.Panel(UIParent)
    frame:SetSize(12 + COLS * STEP + 22, -GRID_TOP + ROWS * STEP + 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    W.Backdrop(frame, { 0.05, 0.05, 0.06, 0.98 }, { 0.45, 0.45, 0.5, 1 })
    _G.BetterMacroIconPicker = frame
    tinsert(UISpecialFrames, "BetterMacroIconPicker")

    local title = W.Text(frame, "GameFontNormal", L.ICON_PICK)
    title:SetPoint("TOPLEFT", 12, -10)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    local sl = W.Text(frame, "GameFontDisableSmall", L.ICON_SUGGESTED)
    sl:SetPoint("TOPLEFT", 12, -32)
    for i = 1, SUGGEST_MAX do
        local b = iconButton(frame, SIZE)
        b:SetPoint("TOPLEFT", 12 + (i - 1) * STEP, -46)
        suggest[i] = b
    end

    search = W.Edit(frame, 200, 20)
    search:SetPoint("TOPLEFT", 17, -84)
    search:SetScript("OnTextChanged", filter)
    search:SetScript("OnEnterPressed", function() choose(list[1]) end)
    searchHint = W.Text(search, "GameFontDisableSmall", L.SEARCH)
    searchHint:SetPoint("LEFT", 2, 0)
    search:HookScript("OnTextChanged", function(self) searchHint:SetShown(self:GetText() == "") end)

    for r = 1, ROWS do
        for c = 1, COLS do
            local b = iconButton(frame, SIZE)
            b:SetPoint("TOPLEFT", 12 + (c - 1) * STEP, GRID_TOP - (r - 1) * STEP)
            grid[#grid + 1] = b
        end
    end
    empty = W.Text(frame, "GameFontDisableSmall", L.NO_RESULTS)
    empty:SetPoint("TOP", 0, GRID_TOP - 20)

    slider = CreateFrame("Slider", nil, frame)
    slider:SetOrientation("VERTICAL")
    slider:SetPoint("TOPRIGHT", -8, GRID_TOP)
    slider:SetSize(10, ROWS * STEP - GAP)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.12, 0.12, 0.14, 1)
    slider:SetThumbTexture(WHITE)
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(10, 30)
    thumb:SetVertexColor(0.45, 0.45, 0.5, 1)
    slider:SetValueStep(1)
    slider:SetMinMaxValues(0, 0)
    slider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        local v = math.floor(value + 0.5)
        if v ~= offset then offset = v; render() end
    end)

    frame:SetScript("OnMouseWheel", function(_, delta)
        offset = offset - delta * 2
        render()
    end)
end

-- selected: the macro's current icon. suggestions: { { value, texture?, label? } }.
-- cb(value) receives the chosen icon (file ID or texture name).
function IP.Open(anchor, selected, suggestions, cb)
    if not frame then create() end
    current.cb, current.selected = cb, selected
    for i, b in ipairs(suggest) do
        local s = suggestions and suggestions[i]
        if s then
            b.value, b.label = s.value, s.label
            b.tex:SetTexture(s.texture or D.IconTexture(s.value))
            b.sel:SetShown(s.value == selected)
            b:Show()
        else
            b:Hide()
        end
    end
    -- File IDs have no name to search: only offer search on named icons
    local all = D.ListIcons()
    search:SetShown(type(all[1]) == "string")
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    frame:Show()
    search:SetText("")
    filter()
    -- Start on the row that holds the current icon
    for i, v in ipairs(list) do
        if v == selected then offset = math.floor((i - 1) / COLS); render(); break end
    end
end

function IP.Close()
    if frame then frame:Hide() end
end
