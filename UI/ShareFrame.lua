local _, ns = ...
local W, L = ns.W, ns.L

-- Small dialog with one text box, used both to copy a share code and to paste one.
local SF = {}
ns.ShareFrame = SF

local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil
local frame, title, hint, edit, action
local mode, exportCode, onImport

local function setHint(text, r, g, b)
    hint:SetText(text or "")
    hint:SetTextColor(r or 0.8, g or 0.8, b or 0.8)
end

local function submit()
    if mode ~= "import" or not onImport then return end
    local ok, err = onImport(edit:GetText())
    if ok then frame:Hide() else setHint(err, 1, 0.35, 0.35) end
end

local function create()
    if frame then return end
    frame = CreateFrame("Frame", "BetterMacroShareFrame", UIParent, BACKDROP_TEMPLATE)
    W.Backdrop(frame, { 0.04, 0.04, 0.05, 0.98 }, { 0.45, 0.45, 0.5, 1 })
    frame:SetSize(470, 132)
    frame:SetPoint("CENTER", 0, 80)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    title = W.Text(frame, "GameFontNormal")
    title:SetPoint("TOPLEFT", 14, -12)
    hint = W.Text(frame, "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 14, -34)
    hint:SetWidth(442)
    hint:SetWordWrap(true)

    edit = W.Edit(frame, 436, 20)
    edit:SetPoint("BOTTOMLEFT", 18, 44)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    edit:SetScript("OnEnterPressed", function() if mode == "import" then submit() else frame:Hide() end end)
    edit:SetScript("OnTextChanged", function(self, userInput)
        -- The code to copy can't be altered by mistake: any keystroke puts it back.
        if mode == "export" and userInput then
            self:SetText(exportCode)
            self:HighlightText()
        end
    end)
    edit:SetScript("OnEditFocusGained", function(self) if mode == "export" then self:HighlightText() end end)

    local close = W.Button(frame, CLOSE or "Close", 100, 22)
    close:SetPoint("BOTTOMRIGHT", -12, 12)
    close:SetScript("OnClick", function() frame:Hide() end)
    action = W.Button(frame, L.IMPORT, 110, 22)
    action:SetPoint("RIGHT", close, "LEFT", -6, 0)
    action:SetScript("OnClick", submit)
end

function SF.ShowExport(code)
    create()
    mode, exportCode, onImport = "export", code, nil
    title:SetText(L.SHARE_TITLE)
    setHint(L.SHARE_HINT)
    action:Hide()
    frame:Show()
    edit:SetText(code)
    edit:SetCursorPosition(0)
    edit:SetFocus()
    edit:HighlightText()
end

-- cb(code) must return true, or false and a message to show.
function SF.ShowImport(cb)
    create()
    mode, exportCode, onImport = "import", nil, cb
    title:SetText(L.IMPORT_TITLE)
    setHint(L.IMPORT_HINT)
    action:Show()
    frame:Show()
    edit:SetText("")
    edit:SetFocus()
end

function SF.Hide()
    if frame then frame:Hide() end
end
