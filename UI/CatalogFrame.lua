local _, ns = ...
local W, D, T, C, L = ns.W, ns.Data, ns.Templates, ns.Catalog, ns.L

-- Macro catalog. It takes the place of the editor inside the main window:
-- class bar and filters on top, macro cards on the left, the selected macro on
-- the right. "Use this macro" goes back to the editor with it as a new,
-- unsaved macro; "Back to the editor" just goes back.
local CF = {}
ns.CatalogFrame = CF

local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CLASS_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local STAR = "Interface\\Common\\ReputationStar"

local TOP = -116           -- where the cards and the detail start
local GRID_W = 700         -- cards area width (the detail takes the rest)
local COLS, CARD_H, GAP = 2, 56, 6

-- Badge colours for situations and roles
local TAG_COLOR = {
    pvp = { 0.75, 0.22, 0.22 }, group = { 0.20, 0.55, 0.30 },
    solo = { 0.70, 0.55, 0.15 }, pet = { 0.50, 0.35, 0.20 },
}
local ROLE_COLOR = {
    heal = { 0.25, 0.65, 0.35 }, tank = { 0.30, 0.45, 0.75 },
    dps = { 0.75, 0.30, 0.25 }, utility = { 0.45, 0.45, 0.50 },
}

local f, ui = nil, {}
local filter = { class = nil, role = nil, tag = nil, usableOnly = false, search = "" }
local selected

local function favorites()
    BetterMacroDB.catalogFavorites = BetterMacroDB.catalogFavorites or {}
    return BetterMacroDB.catalogFavorites
end

local function className(cls)
    if cls == C.COMMON then return L.CAT_COMMON end
    local names = LOCALIZED_CLASS_NAMES_MALE or {}
    return names[cls] or cls
end

local function classColor(cls)
    if cls == C.COMMON then return 0.85, 0.78, 0.62 end
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
    if c then return c.r, c.g, c.b end
    return 0.9, 0.9, 0.9
end

local function setClassIcon(tex, cls)
    local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[cls]
    if cls == C.COMMON then
        tex:SetTexture(C.COMMON_ICON)
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif coords then
        tex:SetTexture(CLASS_TEX)
        tex:SetTexCoord(unpack(coords))
    else
        tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

------------------------------------------------------------------ badges
-- Small coloured label: role or situation of a macro.
local function badge(parent)
    local b = CreateFrame("Frame", nil, parent, BACKDROP)
    b:SetHeight(14)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", 0, 0)
    local font, size, flags = b.text:GetFont()
    if font then b.text:SetFont(font, (size or 10) - 1, flags) end
    function b:Set(label, color)
        self.text:SetText(label)
        W.Backdrop(self, { color[1], color[2], color[3], 0.85 }, { color[1] * 1.3, color[2] * 1.3, color[3] * 1.3, 1 })
        self:SetWidth(self.text:GetStringWidth() + 10)
        self:Show()
    end
    return b
end

-- Lays out role + situation badges from left to right, returns them.
local function setBadges(owner, list, e, x, y)
    for _, b in ipairs(list) do b:Hide() end
    local items = { { L["CATROLE_" .. e.role], ROLE_COLOR[e.role] or ROLE_COLOR.utility } }
    for _, t in ipairs(e.tags or {}) do items[#items + 1] = { L["CATTAG_" .. t], TAG_COLOR[t] or ROLE_COLOR.utility } end
    for i, it in ipairs(items) do
        local b = list[i]
        if not b then b = badge(owner); list[i] = b end
        b:Set(it[1], it[2])
        b:ClearAllPoints()
        if i == 1 then b:SetPoint("TOPLEFT", x, y) else b:SetPoint("LEFT", list[i - 1], "RIGHT", 3, 0) end
    end
end

------------------------------------------------------------------ list
local function currentList()
    local list = C.Filter({
        class = filter.class, role = filter.role, tag = filter.tag,
        usableOnly = filter.usableOnly, favorites = favorites(),
    })
    local q = (filter.search or ""):lower()
    if q == "" then return list end
    local out = {}
    for _, e in ipairs(list) do
        if (C.Name(e) or ""):lower():find(q, 1, true) then out[#out + 1] = e end
    end
    return out
end

local showDetail

local function card(i)
    local c = ui.cards[i]
    if c then return c end
    c = CreateFrame("Button", nil, ui.grid.content, BACKDROP)
    c:SetSize(ui.cardW, CARD_H)
    c.stripe = c:CreateTexture(nil, "ARTWORK")
    c.stripe:SetPoint("TOPLEFT", 1, -1)
    c.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    c.stripe:SetWidth(3)
    c.stripe:SetTexture(WHITE)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetSize(36, 36)
    c.icon:SetPoint("LEFT", 10, 0)
    c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.name = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.name:SetPoint("TOPLEFT", 54, -8)
    c.name:SetPoint("RIGHT", -24, 0)
    c.name:SetJustifyH("LEFT")
    c.name:SetWordWrap(false)
    c.star = c:CreateTexture(nil, "OVERLAY")
    c.star:SetSize(14, 14)
    c.star:SetPoint("TOPRIGHT", -6, -6)
    c.star:SetTexture(STAR)
    c.badges = {}
    local hl = c:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)
    ui.cards[i] = c
    return c
end

local function refreshList()
    if not f then return end
    local list = currentList()
    for _, c in ipairs(ui.cards) do c:Hide() end
    local stillThere = false
    for i, e in ipairs(list) do
        local c = card(i)
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", col * (ui.cardW + GAP), -row * (CARD_H + GAP))
        local usable = C.Usable(e)
        local r, g, b = classColor(e.class)
        local active = e == selected
        W.Backdrop(c, active and { 0.12, 0.20, 0.30, 0.95 } or { 0.08, 0.08, 0.10, 0.95 },
            active and { 0.35, 0.60, 0.90, 1 } or { 0.24, 0.24, 0.28, 1 })
        c.stripe:SetVertexColor(r, g, b, 1)
        c.icon:SetTexture(C.Icon(e))
        c.icon:SetDesaturated(not usable)
        c.name:SetText(C.Name(e))
        if usable then c.name:SetTextColor(1, 1, 1) else c.name:SetTextColor(0.55, 0.55, 0.58) end
        c.star:SetShown(favorites()[e.id] and true or false)
        setBadges(c, c.badges, e, 54, -30)
        c:SetScript("OnClick", function() showDetail(e); refreshList() end)
        c:Show()
        if active then stillThere = true end
    end
    local rows = math.ceil(#list / COLS)
    ui.grid.content:SetHeight(math.max(10, rows * (CARD_H + GAP)))
    ui.empty:SetShown(#list == 0)
    ui.count:SetText(L.CAT_COUNT:format(#list))
    if not stillThere then
        showDetail(list[1])
        if list[1] then refreshList() end
    end
end

------------------------------------------------------------------ detail
showDetail = function(e)
    selected = e
    ui.detail:SetShown(e ~= nil)
    ui.none:SetShown(e == nil)
    if not e then return end
    ui.icon:SetTexture(C.Icon(e))
    ui.icon:SetDesaturated(not C.Usable(e))
    ui.name:SetText(C.Name(e))
    local r, g, b = classColor(e.class)
    setClassIcon(ui.classIcon, e.class)
    ui.className:SetText(className(e.class))
    ui.className:SetTextColor(r, g, b)
    setBadges(ui.detail, ui.badges, e, 64, -44)

    local y = -70
    local desc = C.Description(e)
    ui.desc:SetText(desc or "")
    ui.desc:SetShown(desc ~= nil)
    if desc then y = y - ui.desc:GetStringHeight() - 10 end

    local missing = C.Missing(e)
    ui.missingBox:SetShown(#missing > 0)
    if #missing > 0 then
        ui.missing:SetText(L.CAT_MISSING:format(table.concat(missing, ", ")))
        ui.missingBox:ClearAllPoints()
        ui.missingBox:SetPoint("TOPLEFT", 0, y)
        ui.missingBox:SetHeight(ui.missing:GetStringHeight() + 12)
        y = y - ui.missingBox:GetHeight() - 10
    end

    local m = C.Build(e)
    ui.explainBox:ClearAllPoints()
    ui.explainBox:SetPoint("TOPLEFT", 0, y)
    ui.explainBox:SetPoint("BOTTOMRIGHT", ui.detail, "BOTTOMRIGHT", 0, 150)
    ui.explain:SetText(T.ExplainText(m))
    ui.explainScroll.content:SetHeight(math.max(10, ui.explain:GetStringHeight() + 8))
    ui.explainScroll:SetVerticalScroll(0)
    ui.code:SetText((ns.Generator.Build(m):gsub("|", "||")))

    ui.source:SetText(e.source and L.CAT_SOURCE:format(e.source) or "")
    ui.fav:SetText(favorites()[e.id] and L.CAT_UNFAV or L.CAT_FAV)
end

------------------------------------------------------------------ filters
local function chip(parent, label, onClick)
    local b = W.Flat(parent)
    b:SetLabel(label, 54)
    b:SetHeight(22)
    b:SetScript("OnClick", onClick)
    return b
end

local function refreshFilters()
    for cls, b in pairs(ui.classButtons) do
        local on = filter.class == cls
        b.ring:SetVertexColor(on and 1 or 0.3, on and 0.82 or 0.3, on and 0 or 0.33, 1)
        b.icon:SetDesaturated(filter.class ~= nil and not on)
    end
    ui.allClasses:SetStyle(filter.class == nil and "accent" or "off")
    for role, b in pairs(ui.roleChips) do b:SetStyle(filter.role == role and "accent" or "off") end
    ui.allRoles:SetStyle(filter.role == nil and "accent" or "off")
    for tag, b in pairs(ui.tagChips) do
        local col = TAG_COLOR[tag]
        if filter.tag == tag then
            W.Backdrop(b, { col[1], col[2], col[3], 0.9 }, { col[1] * 1.4, col[2] * 1.4, col[3] * 1.4, 1 })
            b.label:SetTextColor(1, 1, 1)
        else
            b:SetStyle("off")
        end
    end
    ui.allTags:SetStyle(filter.tag == nil and "accent" or "off")
    ui.classTitle:SetText(filter.class and className(filter.class) or L.CAT_ALL_CLASSES)
    if filter.class then ui.classTitle:SetTextColor(classColor(filter.class)) else ui.classTitle:SetTextColor(1, 0.82, 0) end
end

local function setFilter(key, value)
    filter[key] = value
    refreshFilters()
    refreshList()
end

------------------------------------------------------------------ creation
local function create(main)
    f = CreateFrame("Frame", "BetterMacroCatalogFrame", main, BACKDROP)
    f:SetAllPoints(main)
    f:SetFrameLevel(main:GetFrameLevel() + 100)
    f:EnableMouse(true)
    W.Backdrop(f, { 0.04, 0.04, 0.05, 0.99 }, { 0.4, 0.4, 0.45, 1 })
    -- Moving the catalog moves the window
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() main:StartMoving() end)
    f:SetScript("OnDragStop", function() main:StopMovingOrSizing() end)
    f:SetScript("OnHide", function() W.CloseMenu() end)
    main:HookScript("OnHide", function() f:Hide() end)
    ui.cards = {}

    local W_ = main:GetWidth()
    local H_ = main:GetHeight()

    -- Title bar
    local title = W.Text(f, "GameFontNormalLarge", L.CATALOG)
    title:SetPoint("TOPLEFT", 16, -12)
    ui.classTitle = W.Text(f, "GameFontHighlightLarge")
    ui.classTitle:SetPoint("LEFT", title, "RIGHT", 10, 0)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() main:Hide() end)
    local back = W.Button(f, L.CAT_BACK, 150, 22)
    back:SetPoint("TOPRIGHT", -34, -8)
    back:SetScript("OnClick", function() f:Hide() end)

    -- Class bar: "All", then one round icon per class
    ui.allClasses = chip(f, L.CAT_ALL, function() setFilter("class", nil) end)
    ui.allClasses:SetPoint("TOPLEFT", 16, -50)
    ui.classButtons = {}
    local x = 16 + ui.allClasses:GetWidth() + 10
    local buttons = {}
    for _, cls in ipairs(C.CLASSES) do buttons[#buttons + 1] = cls end
    buttons[#buttons + 1] = C.COMMON
    for _, cls in ipairs(buttons) do
        if cls == C.COMMON then x = x + 14 end -- a small gap sets "Common" apart
        local b = CreateFrame("Button", nil, f)
        b:SetSize(36, 36)
        b:SetPoint("TOPLEFT", x, -42)
        b.ring = b:CreateTexture(nil, "BACKGROUND")
        b.ring:SetPoint("TOPLEFT", -2, 2)
        b.ring:SetPoint("BOTTOMRIGHT", 2, -2)
        b.ring:SetTexture(WHITE)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        setClassIcon(b.icon, cls)
        b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        b:SetScript("OnClick", function() setFilter("class", filter.class ~= cls and cls or nil) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(className(cls), classColor(cls))
            if cls == C.COMMON then GameTooltip:AddLine(L.CAT_COMMON_TIP, 1, 1, 1, true) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ui.classButtons[cls] = b
        x = x + 44
    end

    -- Search, at the right of the class bar
    ui.search = W.Edit(f, 220, 22)
    ui.search:SetPoint("TOPRIGHT", -20, -48)
    local hint = W.Text(ui.search, "GameFontDisableSmall", L.CAT_SEARCH)
    hint:SetPoint("LEFT", 2, 0)
    ui.search:SetScript("OnTextChanged", function(self)
        hint:SetShown(self:GetText() == "")
        filter.search = self:GetText()
        refreshList()
    end)

    -- Roles and situations
    ui.allRoles = chip(f, L.CAT_ALL_ROLES, function() setFilter("role", nil) end)
    ui.allRoles:SetPoint("TOPLEFT", 16, -88)
    ui.roleChips = {}
    local prev = ui.allRoles
    for _, role in ipairs(C.ROLES) do
        local b = chip(f, L["CATROLE_" .. role], function() setFilter("role", filter.role ~= role and role or nil) end)
        b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        ui.roleChips[role] = b
        prev = b
    end
    ui.allTags = chip(f, L.CAT_ALL_TAGS, function() setFilter("tag", nil) end)
    ui.allTags:SetPoint("LEFT", prev, "RIGHT", 18, 0)
    ui.tagChips = {}
    prev = ui.allTags
    for _, tag in ipairs(C.TAGS) do
        local b = chip(f, L["CATTAG_" .. tag], function() setFilter("tag", filter.tag ~= tag and tag or nil) end)
        b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        ui.tagChips[tag] = b
        prev = b
    end
    ui.usable = W.Check(f, L.CAT_USABLE)
    ui.usable:SetPoint("LEFT", prev, "RIGHT", 16, 0)
    ui.usable:SetScript("OnClick", function(self)
        filter.usableOnly = self:GetChecked() and true or false
        refreshList()
    end)
    W.Tooltip(ui.usable, L.CAT_USABLE, L.CAT_USABLE_TIP)

    -- Cards
    local gridPanel = W.Panel(f)
    gridPanel:SetPoint("TOPLEFT", 12, TOP)
    gridPanel:SetSize(GRID_W, H_ + TOP - 14)
    W.Backdrop(gridPanel, { 0.03, 0.03, 0.04, 0.9 }, { 0.22, 0.22, 0.26, 1 })
    ui.grid = W.Scroll(gridPanel, GRID_W - 8, H_ + TOP - 30)
    ui.grid:SetPoint("TOPLEFT", 8, -8)
    ui.cardW = (GRID_W - 8 - 26 - GAP * (COLS - 1) - 6) / COLS
    ui.empty = W.Text(gridPanel, "GameFontDisable", L.CAT_NONE)
    ui.empty:SetPoint("TOP", 0, -30)
    ui.count = W.Text(f, "GameFontDisableSmall")
    ui.count:SetPoint("BOTTOMRIGHT", gridPanel, "TOPRIGHT", -4, 4)

    -- Detail
    local dx = 12 + GRID_W + 14
    local dw = W_ - dx - 16
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPLEFT", dx, TOP)
    d:SetSize(dw, H_ + TOP - 14)
    ui.detail = d
    ui.none = W.Text(f, "GameFontDisable", L.CAT_NONE)
    ui.none:SetPoint("TOPLEFT", dx, TOP - 10)

    local iconBox = W.Panel(d)
    iconBox:SetPoint("TOPLEFT", 0, 0)
    iconBox:SetSize(54, 54)
    W.Backdrop(iconBox, { 0, 0, 0, 0.6 }, { 0.5, 0.5, 0.55, 1 })
    ui.icon = iconBox:CreateTexture(nil, "ARTWORK")
    ui.icon:SetPoint("TOPLEFT", 3, -3)
    ui.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    ui.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ui.name = W.Text(d, "GameFontNormalLarge")
    ui.name:SetPoint("TOPLEFT", 64, -2)
    ui.name:SetWidth(dw - 64)
    ui.classIcon = d:CreateTexture(nil, "ARTWORK")
    ui.classIcon:SetSize(16, 16)
    ui.classIcon:SetPoint("TOPLEFT", 64, -22)
    ui.className = W.Text(d, "GameFontHighlightSmall")
    ui.className:SetPoint("LEFT", ui.classIcon, "RIGHT", 4, 0)
    ui.badges = {}

    ui.desc = W.Text(d, "GameFontHighlight")
    ui.desc:SetPoint("TOPLEFT", 0, -70)
    ui.desc:SetWidth(dw)
    ui.desc:SetWordWrap(true)

    ui.missingBox = W.Panel(d)
    ui.missingBox:SetWidth(dw)
    W.Backdrop(ui.missingBox, { 0.30, 0.18, 0.05, 0.6 }, { 0.85, 0.55, 0.20, 1 })
    ui.missing = W.Text(ui.missingBox, "GameFontHighlightSmall")
    ui.missing:SetPoint("TOPLEFT", 8, -6)
    ui.missing:SetWidth(dw - 16)
    ui.missing:SetWordWrap(true)
    ui.missing:SetTextColor(1, 0.75, 0.4)

    ui.explainBox = W.Panel(d)
    local exTitle = W.Text(ui.explainBox, "GameFontNormalSmall", L.EXPLAIN)
    exTitle:SetPoint("TOPLEFT", 8, -6)
    ui.explainScroll = W.Scroll(ui.explainBox, dw - 4, 200)
    ui.explainScroll:SetPoint("TOPLEFT", 6, -22)
    ui.explainScroll:SetPoint("BOTTOMRIGHT", -26, 6)
    ui.explain = W.Text(ui.explainScroll.content, "GameFontHighlightSmall")
    ui.explain:SetPoint("TOPLEFT", 2, 0)
    ui.explain:SetWidth(dw - 44)
    ui.explain:SetWordWrap(true)
    ui.explain:SetSpacing(3)

    -- Macro text, as it will be written in the game
    local codeBox = W.Panel(d)
    codeBox:SetPoint("BOTTOMLEFT", 0, 40)
    codeBox:SetSize(dw, 100)
    W.Backdrop(codeBox, { 0.02, 0.02, 0.03, 0.95 }, { 0.22, 0.22, 0.26, 1 })
    local codeTitle = W.Text(codeBox, "GameFontDisableSmall", L.TEXT)
    codeTitle:SetPoint("TOPLEFT", 8, -6)
    ui.code = W.Text(codeBox, "GameFontHighlightSmall")
    ui.code:SetPoint("TOPLEFT", 8, -20)
    ui.code:SetPoint("BOTTOMRIGHT", -8, 6)
    ui.code:SetJustifyV("TOP")
    ui.code:SetWordWrap(true)
    ui.code:SetTextColor(0.75, 0.9, 1)

    ui.source = W.Text(d, "GameFontDisableSmall")
    ui.source:SetPoint("BOTTOMLEFT", 0, 8)
    ui.source:SetWidth(dw - 300)
    ui.source:SetWordWrap(true)

    local use = W.Button(d, L.CAT_USE, 160, 26)
    use:SetPoint("BOTTOMRIGHT", 0, 2)
    use:SetScript("OnClick", function()
        if not selected then return end
        if ns.locked then ns.MainFrame.Status(L.ERR_COMBAT_EDIT, 1, 0.35, 0.35) return end
        local m = C.Build(selected)
        f:Hide()
        ns.MainFrame.OpenNew(m, L.CAT_OPENED)
    end)
    W.Tooltip(use, L.CAT_USE, L.CAT_USE_TIP)
    ui.fav = W.Button(d, L.CAT_FAV, 140, 26)
    ui.fav:SetPoint("RIGHT", use, "LEFT", -6, 0)
    ui.fav:SetScript("OnClick", function()
        if not selected then return end
        local fav = favorites()
        fav[selected.id] = not fav[selected.id] or nil
        showDetail(selected)
        refreshList()
    end)
end

------------------------------------------------------------------ public
function CF.Open()
    ns.MainFrame.Open()
    local main = _G.BetterMacroFrame
    if not main then return end
    if not f then
        create(main)
        filter.class = T.PlayerClass()
    end
    W.CloseMenu()
    f:Show()
    refreshFilters()
    refreshList()
end

function CF.Toggle()
    if f and f:IsVisible() then f:Hide() else CF.Open() end
end

-- Called when the spellbook changes: learned spells can make a macro usable.
function CF.Refresh()
    if f and f:IsVisible() then refreshList(); showDetail(selected) end
end
