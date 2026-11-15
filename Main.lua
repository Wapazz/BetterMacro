local ADDON, ns = ...
local L = ns.L

-- Adds a "BetterMacro" button under Blizzard's macro window that opens the
-- selected macro in our editor.
local function hookMacroFrame()
    if not MacroFrame or MacroFrame.BetterMacroButton then return end
    local b = CreateFrame("Button", nil, MacroFrame, "UIPanelButtonTemplate")
    b:SetSize(120, 22)
    b:SetText(L.OPEN_IN)
    b:SetPoint("TOPRIGHT", MacroFrame, "BOTTOMRIGHT", 0, -2)
    b:SetScript("OnClick", function()
        -- Newer clients: index inside the current tab, converted with GetMacroDataIndex.
        -- Older clients: MacroFrame.selectedMacro is already the global index.
        local index, i
        if MacroFrame.GetSelectedIndex then
            local ok, v = pcall(MacroFrame.GetSelectedIndex, MacroFrame)
            if ok then i = v end
        end
        if i then
            if MacroFrame.GetMacroDataIndex then
                local ok, v = pcall(MacroFrame.GetMacroDataIndex, MacroFrame, i)
                index = ok and v or nil
            end
            index = index or (i + (MacroFrame.macroBase or 0))
        end
        index = index or MacroFrame.selectedMacro
        if HideUIPanel then HideUIPanel(MacroFrame) else MacroFrame:Hide() end
        ns.MainFrame.Open(index)
    end)
    MacroFrame.BetterMacroButton = b
end

local function loadMacroUI()
    -- Loading Blizzard's macro UI also defines MAX_ACCOUNT_MACROS / MAX_CHARACTER_MACROS
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if load then pcall(load, "Blizzard_MacroUI") end
    hookMacroFrame()
end

local ev = CreateFrame("Frame")
local loggedIn = false
-- Event names differ between clients, and registering one the client doesn't
-- know raises an error that would stop this whole file (and /bm with it).
for _, name in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "UPDATE_MACROS",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB" }) do
    pcall(ev.RegisterEvent, ev, name)
end
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON then
            ns.Storage.Init()
        elseif arg1 == "Blizzard_MacroUI" then
            hookMacroFrame()
        end
    elseif event == "PLAYER_LOGIN" then
        loggedIn = true
        ns.Minimap.Create()
        loadMacroUI()
        ns.Storage.SnapshotCharacter()
    elseif event == "UPDATE_MACROS" then
        if loggedIn then ns.Storage.SnapshotCharacter() end
        if ns.MainFrame.IsShown() then ns.MainFrame.RefreshList() end
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.MainFrame.SetLocked(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.MainFrame.SetLocked(false)
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        ns.Data.InvalidateSpells()
        if ns.CatalogFrame and ns.CatalogFrame.Refresh then ns.CatalogFrame.Refresh() end
    end
end)

SLASH_BETTERMACRO1 = "/bm"
SLASH_BETTERMACRO2 = "/bettermacro"
-- Errors are printed in the chat: with Lua errors hidden (the default), a
-- failing window would otherwise just not open, with no clue why.
local function report(err)
    print("|cffff5555BetterMacro:|r " .. tostring(err))
end

SlashCmdList.BETTERMACRO = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if not ns.MainFrame then
        report("UI/MainFrame.lua did not load. Restart the game; if it stays, type /console scriptErrors 1 then /reload to see the error.")
        return
    end
    local ok, err = pcall(function()
        if (msg == "catalog" or msg == "catalogue") and ns.CatalogFrame then
            ns.CatalogFrame.Toggle()
        else
            ns.MainFrame.Toggle()
        end
    end)
    if not ok then report(err) end
end
