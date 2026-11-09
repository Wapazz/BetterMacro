local _, ns = ...

-- Small set of hand-made widgets. We avoid UIDropDownMenu and other Blizzard
-- widgets whose API differs between clients, so the addon works on WoW Forever
-- whatever its UI version.
local W = {}
ns.W = W

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local WHITE = "Interface\\Buttons\\WHITE8X8"

W.STYLES = {
    off    = { bg = { 0.13, 0.13, 0.15, 0.95 }, border = { 0.30, 0.30, 0.33 }, text = { 0.62, 0.62, 0.66 } },
    plain  = { bg = { 0.10, 0.10, 0.12, 0.95 }, border = { 0.38, 0.38, 0.42 }, text = { 0.95, 0.95, 0.95 } },
    cond   = { bg = { 0.25, 0.20, 0.45, 0.95 }, border = { 0.52, 0.44, 0.85 }, text = { 0.88, 0.84, 1.00 } },
    mod    = { bg = { 0.40, 0.25, 0.10, 0.95 }, border = { 0.82, 0.56, 0.24 }, text = { 1.00, 0.86, 0.60 } },
    action = { bg = { 0.08, 0.25, 0.25, 0.95 }, border = { 0.25, 0.62, 0.58 }, text = { 0.78, 1.00, 0.95 } },
    accent = { bg = { 0.12, 0.27, 0.42, 0.95 }, border = { 0.30, 0.56, 0.85 }, text = { 1.00, 1.00, 1.00 } },
    ghost  = { bg = { 0, 0, 0, 0 }, border = { 0, 0, 0, 0 }, text = { 0.55, 0.75, 1.00 } },
}

function W.Backdrop(f, bg, border)
    if not f.SetBackdrop then return end
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(bg or { 0.06, 0.06, 0.07, 0.95 }))
    f:SetBackdropBorderColor(unpack(border or { 0.25, 0.25, 0.28, 1 }))
end

function W.Panel(parent)
    local f = CreateFrame("Frame", nil, parent, BACKDROP_TEMPLATE)
    W.Backdrop(f)
    return f
end

function W.Text(parent, template, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    if text then fs:SetText(text) end
    return fs
end

function W.Tooltip(f, title, body)
    f:HookScript("OnEnter", function(self)
        local t, b = title, body
        if type(t) == "function" then t, b = t(self) end
        if not t then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(t, 1, 1, 1)
        if b then GameTooltip:AddLine(b, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Flat button: chips, selectors, list rows. Optional icon on the left.
function W.Flat(parent, withIcon)
    local b = CreateFrame("Button", nil, parent, BACKDROP_TEMPLATE)
    b:SetHeight(20)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.label = W.Text(b, "GameFontHighlightSmall")
    if withIcon then
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(16, 16)
        b.icon:SetPoint("LEFT", 3, 0)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.label:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
        b.label:SetPoint("RIGHT", -4, 0)
    else
        b.label:SetPoint("CENTER")
    end
    b.label:SetWordWrap(false)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    function b:SetStyle(name)
        local s = W.STYLES[name] or W.STYLES.plain
        W.Backdrop(self, s.bg, s.border)
        self.label:SetTextColor(unpack(s.text))
    end
    function b:SetLabel(text, minWidth)
        self.label:SetText(text or "")
        if minWidth ~= false then
            local w = self.label:GetStringWidth() + (self.icon and 30 or 14)
            self:SetWidth(math.max(minWidth or 0, w))
        end
    end
    b:SetStyle("plain")
    return b
end

function W.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text or "")
    return b
end

function W.IconButton(parent, size, texture)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b:SetNormalTexture(texture)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    return b
end

function W.Check(parent, text)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    c.text = rawget(c, "text") or rawget(c, "Text") or W.Text(c, "GameFontHighlightSmall")
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c, "RIGHT", 1, 0)
    c.text:SetText(text)
    return c
end

function W.Edit(parent, w, h)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, h or 20)
    e:SetAutoFocus(false)
    e:SetFontObject("GameFontHighlightSmall")
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    return e
end

-- Vertical scroll area. Returns the scroll frame and its content frame.
function W.Scroll(parent, w, h)
    local s = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    s:SetSize(w - 26, h)
    local c = CreateFrame("Frame", nil, s)
    c:SetSize(w - 26, 10)
    s:SetScrollChild(c)
    s.content = c
    return s, c
end

------------------------------------------------------------------ pools
-- Frames can't be garbage collected in WoW, so the builder recycles them.
function W.Pool(create)
    local pool = { free = {}, used = {} }
    function pool:Acquire()
        local f = table.remove(self.free) or create()
        self.used[#self.used + 1] = f
        f:ClearAllPoints()
        f:Show()
        return f
    end
    function pool:ReleaseAll()
        for _, f in ipairs(self.used) do
            f:Hide()
            f:ClearAllPoints()
            if f.HasScript then
                for _, s in ipairs({ "OnClick", "OnReceiveDrag", "OnTextChanged", "OnEditFocusLost" }) do
                    if f:HasScript(s) then f:SetScript(s, nil) end
                end
            end
            self.free[#self.free + 1] = f
        end
        self.used = {}
    end
    return pool
end

------------------------------------------------------------------ popup menu
local menu, catcher

function W.CloseMenu()
    if menu then menu:Hide() end
    if catcher then catcher:Hide() end
end

-- items = { { text = "...", value = any, checked = bool }, ... }
function W.OpenMenu(owner, items, onSelect)
    if not menu then
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:RegisterForClicks("AnyUp")
        catcher:SetScript("OnClick", W.CloseMenu)
        menu = W.Panel(UIParent)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
        menu:SetClampedToScreen(true)
        W.Backdrop(menu, { 0.05, 0.05, 0.06, 0.98 }, { 0.45, 0.45, 0.5, 1 })
        menu.rows = {}
    end
    for _, r in ipairs(menu.rows) do r:Hide() end
    local width = 120
    for i, it in ipairs(items) do
        local r = menu.rows[i]
        if not r then
            r = W.Flat(menu)
            r.label:ClearAllPoints()
            r.label:SetPoint("LEFT", 8, 0)
            r:SetFrameLevel(menu:GetFrameLevel() + 2)
            menu.rows[i] = r
        end
        r:SetStyle(it.checked and "accent" or "ghost")
        r.label:SetText(it.text)
        r.label:SetTextColor(1, 1, 1)
        width = math.max(width, r.label:GetStringWidth() + 24)
        r:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
        r:SetScript("OnClick", function()
            W.CloseMenu()
            onSelect(it.value, it)
        end)
        r:Show()
    end
    for i = 1, #items do menu.rows[i]:SetWidth(width) end
    menu:SetSize(width + 8, #items * 20 + 8)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    catcher:Show()
    menu:Show()
end
