---@diagnostic disable: undefined-field
--[[
    Options for the ChatEnhancement module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class DatatextConfigurationOptions
local Options = ConfigurationModule.Options.Datatext or {}
ConfigurationModule.Options.Datatext = Options

local MAX_STANDALONE_PANELS = 8
local MIN_STANDALONE_PANEL_WIDTH = 80
local MAX_STANDALONE_PANEL_WIDTH = 4000
local MAX_STANDALONE_PANEL_SLOTS = 6

-- Static structural defaults — non-color properties that don't derive from the theme.
-- Color-keyed properties are overridden at resolve-time by GetThemeBasedDefaults().
local DEFAULT_STANDALONE_STYLE = {
    font = "Friz Quadrata TT",
    fontSize = 12,
    textAlign = "CENTER",
    tooltipFont = "Friz Quadrata TT",
    tooltipFontSize = 11,
    menuFont = "Friz Quadrata TT",
    menuFontSize = 12,
    fontOutline = false,
    showDragHandle = true,
    textShadowAlpha = 0.85,
    backgroundColor = { 0.05, 0.06, 0.08, 1 },
    backgroundAlpha = 0.94,
    borderColor = { 0.24, 0.26, 0.32, 1 },
    borderAlpha = 0.9,
    accentColor = { 0.96, 0.76, 0.24, 1 },
    accentAlpha = 0.95,
    dividerAlpha = 0.28,
    hoverGlowColor = { 0.96, 0.76, 0.24, 1 },
    hoverGlowAlpha = 0.09,
    hoverBarColor = { 0.96, 0.76, 0.24, 1 },
    hoverBarAlpha = 0.92,
}

local function GetDatatextModule()
    return T:GetModule("Datatexts", true)
end

local function RefreshStandalonePanels()
    local datatextModule = GetDatatextModule()
    if datatextModule and datatextModule.RefreshStandalonePanels then
        datatextModule:RefreshStandalonePanels()
    end
end

local function CopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyTable(value)
    end
    return copy
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults or {}) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function BuildDefaultStandalonePanel(panelID, orderIndex)
    local baseYOffset = 6 + ((math.max(1, orderIndex) - 1) * 34)
    return {
        id = panelID,
        name = orderIndex == 1 and "Primary Panel" or ("Panel " .. tostring(orderIndex)),
        enabled = true,
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = baseYOffset,
        width = 420,
        height = 28,
        segments = 3,
        slot1 = orderIndex == 1 and "TwichUI: Chores" or "NONE",
        slot2 = orderIndex == 1 and "TwichUI: Mythic+" or "NONE",
        slot3 = orderIndex == 1 and "TwichUI: Portals" or "NONE",
        slot4 = "NONE",
        slot5 = "NONE",
        slot6 = "NONE",
    }
end

local function NormalizeStandalonePanel(panel, panelID, orderIndex)
    local defaults = BuildDefaultStandalonePanel(panelID, orderIndex)
    MergeDefaults(panel, defaults)
    panel.id = panelID
    if panel.useStyleOverrides == nil then
        panel.useStyleOverrides = false
    end
    if panel.style ~= nil and type(panel.style) ~= "table" then
        panel.style = {}
    end
    panel.width = math.min(MAX_STANDALONE_PANEL_WIDTH,
        math.max(MIN_STANDALONE_PANEL_WIDTH, tonumber(panel.width) or defaults.width))
    panel.height = math.min(80, math.max(20, tonumber(panel.height) or defaults.height))
    panel.segments = math.min(MAX_STANDALONE_PANEL_SLOTS, math.max(1, tonumber(panel.segments) or defaults.segments))
    panel.x = tonumber(panel.x) or defaults.x
    panel.y = tonumber(panel.y) or defaults.y
end

local function GetThemeBasedDefaults()
    local theme = T:GetModule("Theme", true)
    local base = CopyTable(DEFAULT_STANDALONE_STYLE)
    if theme then
        local ac             = theme:GetColor("accentColor")
        local bg             = theme:GetColor("backgroundColor")
        local bd             = theme:GetColor("borderColor")
        base.accentColor     = { ac[1], ac[2], ac[3], 1 }
        base.accentAlpha     = theme:Get("backgroundAlpha") and 0.95 or 0.95
        base.backgroundColor = { bg[1], bg[2], bg[3], 1 }
        base.backgroundAlpha = theme:Get("backgroundAlpha") or 0.94
        base.borderColor     = { bd[1], bd[2], bd[3], 1 }
        base.borderAlpha     = theme:Get("borderAlpha") or 0.9
        -- Hover colors always default to the live accent so they track theme changes.
        base.hoverGlowColor  = base.accentColor
        base.hoverBarColor   = base.accentColor
        -- Use the global font when one is set
        local gf             = theme:Get("globalFont")
        if gf and gf ~= "__default" then
            base.font = gf
        end
    end
    return base
end

function Options:GetResolvedStandaloneStyle(panelID)
    local standalone = self:GetStandaloneDB()
    local themeDefaults = GetThemeBasedDefaults()
    -- Always start from the live theme so global Appearance changes propagate instantly.
    local resolved = CopyTable(themeDefaults)
    -- Layer explicit shared-style user overrides (hoverGlowColor, hoverBarColor, fonts…)
    if type(standalone.style) == "table" then
        for k, v in pairs(standalone.style) do
            if v ~= nil then
                resolved[k] = type(v) == "table" and CopyTable(v) or v
            end
        end
    end
    -- Layer per-panel style overrides, but NEVER override theme-based colors
    local panel = type(panelID) == "string" and self:GetStandalonePanel(panelID) or nil
    if panel and panel.useStyleOverrides == true and type(panel.style) == "table" then
        for key, value in pairs(panel.style) do
            -- Theme colors always take precedence; only allow non-theme overrides
            if value ~= nil and key ~= "hoverGlowColor" and key ~= "hoverBarColor" and key ~= "accentColor" then
                resolved[key] = type(value) == "table" and CopyTable(value) or value
            end
        end
    end
    -- Transparent theme: zero out all opaque surfaces, keeping interaction
    -- colours (hover glow / hover bar) visible.
    if panel and panel.transparentTheme == true then
        resolved.backgroundAlpha = 0
        resolved.borderAlpha = 0
        resolved.accentAlpha = 0
        resolved.dividerAlpha = 0
    end
    return resolved
end

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().datatext then
        ConfigurationModule:GetProfileDB().datatext = {}
    end
    return ConfigurationModule:GetProfileDB().datatext
end

function Options:GetDatatextDB(datatextName)
    local db = self:GetDB()
    if not db[datatextName] then
        db[datatextName] = {}
    end
    return db[datatextName]
end

function Options:GetStandaloneDB()
    local db = self:GetDB()
    if type(db.standalone) ~= "table" then
        db.standalone = {}
    end

    local standalone = db.standalone
    if standalone.enabled == nil then
        standalone.enabled = false
    end
    if standalone.locked == nil then
        standalone.locked = true
    end

    if type(standalone.style) ~= "table" then
        standalone.style = {}
    end
    -- Migration v2: theme-origin color keys must not be stored in standalone.style;
    -- they are now always resolved live from GetThemeBasedDefaults().
    if standalone._styleSchemaV ~= 2 then
        local purgeKeys = {
            "accentColor", "accentAlpha", "backgroundColor", "backgroundAlpha",
            "borderColor", "borderAlpha", "hoverGlowColor", "hoverBarColor",
        }
        for _, k in ipairs(purgeKeys) do
            standalone.style[k] = nil
        end
        standalone._styleSchemaV = 2
    end

    if type(standalone.panels) ~= "table" then
        standalone.panels = {}
    end

    local panelIDs = {}
    for panelID in pairs(standalone.panels) do
        panelIDs[#panelIDs + 1] = panelID
    end

    if #panelIDs == 0 then
        standalone.panels.panel1 = BuildDefaultStandalonePanel("panel1", 1)
    else
        table.sort(panelIDs, function(left, right)
            return tostring(left) < tostring(right)
        end)
        for index, panelID in ipairs(panelIDs) do
            NormalizeStandalonePanel(standalone.panels[panelID], panelID, index)
        end
    end

    return standalone
end

function Options:GetStandalonePanel(panelID)
    local standalone = self:GetStandaloneDB()
    if type(panelID) ~= "string" or panelID == "" then
        return nil
    end

    if type(standalone.panels[panelID]) ~= "table" then
        return nil
    end

    local sortedIDs = self:GetStandalonePanelIDs()
    local orderIndex = 1
    for index, currentPanelID in ipairs(sortedIDs) do
        if currentPanelID == panelID then
            orderIndex = index
            break
        end
    end

    NormalizeStandalonePanel(standalone.panels[panelID], panelID, orderIndex)
    return standalone.panels[panelID]
end

function Options:GetStandalonePanelIDs()
    local standalone = self:GetStandaloneDB()
    local panelIDs = {}
    for panelID in pairs(standalone.panels or {}) do
        panelIDs[#panelIDs + 1] = panelID
    end

    table.sort(panelIDs, function(left, right)
        return tostring(left) < tostring(right)
    end)

    return panelIDs
end

function Options:GetStandaloneDatatextChoices()
    local datatextModule = GetDatatextModule()
    if datatextModule and datatextModule.GetStandaloneDatatextChoices then
        return datatextModule:GetStandaloneDatatextChoices()
    end

    return {
        NONE = "None",
    }
end

function Options:CreateStandalonePanel()
    local standalone = self:GetStandaloneDB()
    for index = 1, MAX_STANDALONE_PANELS do
        local panelID = "panel" .. tostring(index)
        if not standalone.panels[panelID] then
            standalone.panels[panelID] = BuildDefaultStandalonePanel(panelID, index)
            ConfigurationModule:Refresh()
            RefreshStandalonePanels()
            return panelID
        end
    end

    return nil
end

function Options:DeleteStandalonePanel(panelID)
    local standalone = self:GetStandaloneDB()
    if standalone.panels and standalone.panels[panelID] then
        standalone.panels[panelID] = nil
    end

    if next(standalone.panels) == nil then
        standalone.panels.panel1 = BuildDefaultStandalonePanel("panel1", 1)
    end

    ConfigurationModule:Refresh()
    RefreshStandalonePanels()
end

function Options:RefreshStandalonePanels()
    RefreshStandalonePanels()
end

function Options:IsModuleEnabled(info)
    return self:GetDB().enabled or false
end

function Options:SetModuleEnabled(info, value)
    self:GetDB().enabled = value
    if (value) then
        local datatextModule = T:GetModule("Datatexts")
        datatextModule:Enable()
    else
        local datatextModule = T:GetModule("Datatexts")
        datatextModule:Disable()
        ConfigurationModule:PromptToReloadUI()
    end
end

local function RefreshDatatext(datatextName)
    ---@type DataTextModule
    local dtModule = T:GetModule("Datatexts")
    dtModule:RefreshDataText(datatextName)
end

local DEFAULT_CUSTOM_CURRENCY_SETTINGS = {
    showIcon = true,
    nameStyle = "abbr",
    showMax = true,
    includeInTooltip = true,
}

local function GetCurrencyModule()
    local datatextModule = GetDatatextModule()
    return datatextModule and datatextModule.GetModule and datatextModule:GetModule("CurrencyDataText", true) or nil
end

local function GetCurrenciesDB(options)
    local db = options:GetDatatextDB("currencies")
    if type(db.tooltipCurrencyIDs) ~= "table" then
        db.tooltipCurrencyIDs = {}
    end
    if type(db.customDatatexts) ~= "table" then
        db.customDatatexts = {}
    end
    if type(db.displayedCurrency) ~= "string" or db.displayedCurrency == "" then
        db.displayedCurrency = "GOLD"
    end
    if type(db.displayStyle) ~= "string" or db.displayStyle == "" then
        db.displayStyle = "ICON_TEXT_ABBR"
    end
    if db.showMax == nil then
        db.showMax = true
    end
    return db
end

local function SyncCurrencyDatatexts(refreshConfig)
    local currencyModule = GetCurrencyModule()
    if currencyModule and currencyModule.SyncCustomDatatexts then
        currencyModule:SyncCustomDatatexts()
    end

    RefreshDatatext("TwichUI: Currencies")
    RefreshStandalonePanels()
    if refreshConfig == true then
        ConfigurationModule:Refresh()
    end
end

local function FindCurrencyInfo(currencyID)
    if type(C_CurrencyInfo) ~= "table" or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return nil
    end

    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if type(info) ~= "table" or not info.name then
        return nil
    end

    return info
end

local function TooltipHide()
    if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
    end
end

local function BuildCurrencyTooltipCallback(currencyID)
    return function(row)
        if not (_G.GameTooltip and _G.GameTooltip.SetOwner) then
            return
        end

        _G.GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        if _G.GameTooltip.SetCurrencyByID then
            _G.GameTooltip:SetCurrencyByID(currencyID)
        else
            local info = FindCurrencyInfo(currencyID)
            if info and info.name then
                _G.GameTooltip:AddLine(info.name)
            end
        end
        _G.GameTooltip:Show()
    end
end

local function InsertCurrencyCandidate(collected, seen, currencyID)
    local numericCurrencyID = tonumber(currencyID)
    if not numericCurrencyID or numericCurrencyID <= 0 or seen[numericCurrencyID] then
        return
    end

    local info = FindCurrencyInfo(numericCurrencyID)
    if not info or not info.name then
        return
    end

    seen[numericCurrencyID] = true
    collected[#collected + 1] = {
        value = numericCurrencyID,
        name = tostring(info.name),
        icon = info.iconFileID,
        search = tostring(info.name),
        onEnter = BuildCurrencyTooltipCallback(numericCurrencyID),
        onLeave = TooltipHide,
    }
end

function Options:GetCurrencySelectorCandidates()
    local db = GetCurrenciesDB(self)
    local candidates = {}
    local seen = {}

    if type(C_CurrencyInfo) == "table" and type(C_CurrencyInfo.GetCurrencyListSize) == "function" and
        type(C_CurrencyInfo.GetCurrencyListInfo) == "function" then
        local listSize = C_CurrencyInfo.GetCurrencyListSize() or 0
        for index = 1, listSize do
            local listInfo = C_CurrencyInfo.GetCurrencyListInfo(index)
            local currencyID = listInfo and (listInfo.currencyTypesID or listInfo.currencyID) or nil
            local isHeader = listInfo and (listInfo.isHeader == true or listInfo.header == true) or false
            if not isHeader and currencyID then
                InsertCurrencyCandidate(candidates, seen, currencyID)
            end
        end
    end

    for _, currencyID in ipairs(db.tooltipCurrencyIDs) do
        InsertCurrencyCandidate(candidates, seen, currencyID)
    end

    for currencyID in pairs(db.customDatatexts) do
        InsertCurrencyCandidate(candidates, seen, currencyID)
    end

    table.sort(candidates, function(left, right)
        return tostring(left.name or "") < tostring(right.name or "")
    end)

    return candidates
end

function Options:GetCurrencyDisplayChoices()
    local values = {
        GOLD = "Gold",
    }

    for _, candidate in ipairs(self:GetCurrencySelectorCandidates()) do
        values[tostring(candidate.value)] = candidate.name
    end

    return values
end

function Options:GetCurrenciesDisplaySource(info)
    return tostring(GetCurrenciesDB(self).displayedCurrency or "GOLD")
end

function Options:SetCurrenciesDisplaySource(info, value)
    local db = GetCurrenciesDB(self)
    db.displayedCurrency = tostring(value or "GOLD")
    SyncCurrencyDatatexts(false)
end

function Options:GetCurrenciesDisplayStyle(info)
    return GetCurrenciesDB(self).displayStyle or "ICON_TEXT_ABBR"
end

function Options:SetCurrenciesDisplayStyle(info, value)
    local db = GetCurrenciesDB(self)
    db.displayStyle = value or "ICON_TEXT_ABBR"
    SyncCurrencyDatatexts(false)
end

function Options:GetCurrenciesShowMax(info)
    return GetCurrenciesDB(self).showMax ~= false
end

function Options:SetCurrenciesShowMax(info, value)
    local db = GetCurrenciesDB(self)
    db.showMax = value == true
    SyncCurrencyDatatexts(false)
end

function Options:GetCurrenciesShowGoldInTooltip(info)
    return GetCurrenciesDB(self).showGoldInTooltip ~= false
end

function Options:SetCurrenciesShowGoldInTooltip(info, value)
    local db = GetCurrenciesDB(self)
    db.showGoldInTooltip = value == true
    SyncCurrencyDatatexts(false)
end

function Options:GetCurrenciesUseCustomColor(info)
    return GetCurrenciesDB(self).customColor == true
end

function Options:SetCurrenciesUseCustomColor(info, value)
    local db = GetCurrenciesDB(self)
    db.customColor = value == true
    SyncCurrencyDatatexts(false)
end

function Options:GetCurrenciesTextColor(info)
    local db = GetCurrenciesDB(self)
    if type(db.textColor) ~= "table" then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetCurrenciesTextColor(info, r, g, b, a)
    local db = GetCurrenciesDB(self)
    db.textColor = { r, g, b, a }
    SyncCurrencyDatatexts(false)
end

function Options:GetTooltipCurrencyEntries()
    local db = GetCurrenciesDB(self)
    local entries = {}
    for _, currencyID in ipairs(db.tooltipCurrencyIDs) do
        local info = FindCurrencyInfo(currencyID)
        if info and info.name then
            entries[#entries + 1] = {
                id = currencyID,
                name = info.name,
                icon = info.iconFileID,
            }
        end
    end
    return entries
end

function Options:AddTooltipCurrency(currencyID)
    local numericCurrencyID = tonumber(currencyID)
    if not numericCurrencyID or numericCurrencyID <= 0 then
        return
    end

    local db = GetCurrenciesDB(self)
    for _, existingID in ipairs(db.tooltipCurrencyIDs) do
        if tonumber(existingID) == numericCurrencyID then
            return
        end
    end

    db.tooltipCurrencyIDs[#db.tooltipCurrencyIDs + 1] = numericCurrencyID
    if db.displayedCurrency == "GOLD" then
        db.displayedCurrency = tostring(numericCurrencyID)
    end

    SyncCurrencyDatatexts(true)
end

function Options:RemoveTooltipCurrency(currencyID)
    local numericCurrencyID = tonumber(currencyID)
    if not numericCurrencyID then
        return
    end

    local db = GetCurrenciesDB(self)
    for index = #db.tooltipCurrencyIDs, 1, -1 do
        if tonumber(db.tooltipCurrencyIDs[index]) == numericCurrencyID then
            table.remove(db.tooltipCurrencyIDs, index)
        end
    end

    if tostring(db.displayedCurrency) == tostring(numericCurrencyID) then
        db.displayedCurrency = "GOLD"
    end

    SyncCurrencyDatatexts(true)
end

function Options:AddCustomCurrencyDatatext(currencyID)
    local numericCurrencyID = tonumber(currencyID)
    if not numericCurrencyID or numericCurrencyID <= 0 then
        return
    end

    local db = GetCurrenciesDB(self)
    if type(db.customDatatexts[numericCurrencyID]) ~= "table" then
        db.customDatatexts[numericCurrencyID] = CopyTable(DEFAULT_CUSTOM_CURRENCY_SETTINGS)
    end

    SyncCurrencyDatatexts(true)
end

function Options:RemoveCustomCurrencyDatatext(currencyID)
    local numericCurrencyID = tonumber(currencyID)
    if not numericCurrencyID then
        return
    end

    local db = GetCurrenciesDB(self)
    db.customDatatexts[numericCurrencyID] = nil
    SyncCurrencyDatatexts(true)
end

function Options:GetCustomCurrencyDatatextEntries()
    local db = GetCurrenciesDB(self)
    local entries = {}

    for currencyID, settings in pairs(db.customDatatexts) do
        local info = FindCurrencyInfo(currencyID)
        if info and info.name then
            MergeDefaults(settings, DEFAULT_CUSTOM_CURRENCY_SETTINGS)
            entries[#entries + 1] = {
                id = tonumber(currencyID),
                name = info.name,
                icon = info.iconFileID,
                settings = settings,
            }
        end
    end

    table.sort(entries, function(left, right)
        return tostring(left.name or "") < tostring(right.name or "")
    end)

    return entries
end

function Options:GetCustomCurrencyDatatextSetting(currencyID, key, fallback)
    local db = GetCurrenciesDB(self)
    local numericCurrencyID = tonumber(currencyID)
    local settings = numericCurrencyID and db.customDatatexts[numericCurrencyID] or nil
    if type(settings) ~= "table" then
        return fallback
    end

    if settings[key] == nil then
        return DEFAULT_CUSTOM_CURRENCY_SETTINGS[key] ~= nil and DEFAULT_CUSTOM_CURRENCY_SETTINGS[key] or fallback
    end

    return settings[key]
end

function Options:SetCustomCurrencyDatatextSetting(currencyID, key, value)
    local db = GetCurrenciesDB(self)
    local numericCurrencyID = tonumber(currencyID)
    if not numericCurrencyID then
        return
    end

    if type(db.customDatatexts[numericCurrencyID]) ~= "table" then
        db.customDatatexts[numericCurrencyID] = CopyTable(DEFAULT_CUSTOM_CURRENCY_SETTINGS)
    end

    db.customDatatexts[numericCurrencyID][key] = value
    SyncCurrencyDatatexts(false)
    RefreshDatatext(string.format("TwichUI: Currency: %d", numericCurrencyID))
end

--------- MOUNTS DATATEXT OPTIONS ---------
function Options:GetMountTextColor(info)
    local db = self:GetDatatextDB("mounts")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetMountTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("mounts")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetMountUseCustomColor(info)
    local db = self:GetDatatextDB("mounts")
    return db.customColor or false
end

function Options:SetMountUseCustomColor(info, value)
    local db = self:GetDatatextDB("mounts")
    db.customColor = value
    RefreshDatatext("TwichUI: Mount")
end

function Options:SetShowUtilityMounts(info, value)
    local db = self:GetDatatextDB("mounts")
    db.showUtilityMounts = value
    ---@type MountDataText
    local MountDataText = T:GetModule("Datatexts"):GetModule("MountDataText")
    MountDataText.flaggedForRebuild = true
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetShowUtilityMounts(info)
    local db = self:GetDatatextDB("mounts")
    -- Default to true when unset, but respect false
    if db.showUtilityMounts == nil then
        return true
    end
    return db.showUtilityMounts
end

function Options:SetShowFavoriteMounts(info, value)
    local db = self:GetDatatextDB("mounts")
    db.showFavoriteMounts = value
    ---@type MountDataText
    local MountDataText = T:GetModule("Datatexts"):GetModule("MountDataText")
    MountDataText.flaggedForRebuild = true
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetShowFavoriteMounts(info)
    local db = self:GetDatatextDB("mounts")
    -- Default to true when unset, but respect false
    if db.showFavoriteMounts == nil then
        return true
    end
    return db.showFavoriteMounts
end

function Options:GetVendorMount(info)
    local db = self:GetDatatextDB("mounts")
    return db.vendorMountID or 0
end

function Options:SetVendorMount(info, value)
    local db = self:GetDatatextDB("mounts")
    db.vendorMountID = value
    RefreshDatatext("TwichUI: Mount")
end

function Options:SetAuctionMount(info, value)
    local db = self:GetDatatextDB("mounts")
    db.auctionMountID = value
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetAuctionMount(info)
    local db = self:GetDatatextDB("mounts")
    return db.auctionMountID or 0
end

function Options:IsVendorMountShortcutEnabled(info)
    return self:GetDB().vendorMountShortcutEnabled or false
end

function Options:SetVendorMountShortcutEnabled(info, value)
    self:GetDB().vendorMountShortcutEnabled = value
end

function Options:IsAuctionMountShortcutEnabled(info)
    return self:GetDB().auctionMountShortcutEnabled or false
end

function Options:SetAuctionMountShortcutEnabled(info, value)
    self:GetDB().auctionMountShortcutEnabled = value
end

function Options:GetPortalsUseCustomColor(info)
    local db = self:GetDatatextDB("portals")
    return db.customColor or false
end

function Options:SetPortalsUseCustomColor(info, value)
    local db = self:GetDatatextDB("portals")
    db.customColor = value
    RefreshDatatext("TwichUI: Portals")
end

function Options:GetPortalsTextColor(info)
    local db = self:GetDatatextDB("portals")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetPortalsTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("portals")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Portals")
end

function Options:GetMythicPlusUseCustomColor(info)
    local db = self:GetDatatextDB("mythicplus")
    return db.customColor or false
end

function Options:SetMythicPlusUseCustomColor(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.customColor = value
    RefreshDatatext("TwichUI: Mythic+")
end

function Options:GetMythicPlusTextColor(info)
    local db = self:GetDatatextDB("mythicplus")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetMythicPlusTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("mythicplus")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Mythic+")
end

function Options:GetMythicPlusShowAffixes(info)
    local db = self:GetDatatextDB("mythicplus")
    if db.showAffixes == nil then
        return true
    end
    return db.showAffixes
end

function Options:SetMythicPlusShowAffixes(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.showAffixes = value
end

function Options:GetMythicPlusShowDungeonBests(info)
    local db = self:GetDatatextDB("mythicplus")
    if db.showDungeonBests == nil then
        return true
    end
    return db.showDungeonBests
end

function Options:SetMythicPlusShowDungeonBests(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.showDungeonBests = value
end

function Options:GetMythicPlusShowRewardProgress(info)
    local db = self:GetDatatextDB("mythicplus")
    if db.showRewardProgress == nil then
        return true
    end
    return db.showRewardProgress
end

function Options:SetMythicPlusShowRewardProgress(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.showRewardProgress = value
end

function Options:GetFavoriteHearthstone(info)
    local db = self:GetDatatextDB("portals")
    return db.favoriteHearthstoneItemID or 0
end

function Options:SetFavoriteHearthstone(info, value)
    local db = self:GetDatatextDB("portals")
    db.favoriteHearthstoneItemID = tonumber(value) or 0
    RefreshDatatext("TwichUI: Portals")
end

function Options:GetChoresUseCustomColor(info)
    local db = self:GetDatatextDB("chores")
    return db.customColor or false
end

function Options:SetChoresUseCustomColor(info, value)
    local db = self:GetDatatextDB("chores")
    db.customColor = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTextColor(info)
    local db = self:GetDatatextDB("chores")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetChoresTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("chores")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresUseCustomDoneColor(info)
    local db = self:GetDatatextDB("chores")
    return db.customDoneColor == true
end

function Options:SetChoresUseCustomDoneColor(info, value)
    local db = self:GetDatatextDB("chores")
    db.customDoneColor = value == true
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresDoneTextColor(info)
    local db = self:GetDatatextDB("chores")
    if not db.doneTextColor then
        db.doneTextColor = { 0.2, 0.82, 0.32, 1 }
    end
    return unpack(db.doneTextColor)
end

function Options:SetChoresDoneTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("chores")
    db.doneTextColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipHeaderFont(info)
    local style = self:GetStandaloneDB().style
    return style.tooltipFont or "Friz Quadrata TT"
end

function Options:SetChoresTooltipHeaderFont(info, value)
    local db = self:GetDatatextDB("chores")
    local style = self:GetStandaloneDB().style
    db.tooltipHeaderFont = value
    style.tooltipFont = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipHeaderFontSize(info)
    local style = self:GetStandaloneDB().style
    return style.tooltipFontSize or 11
end

function Options:SetChoresTooltipHeaderFontSize(info, value)
    local db = self:GetDatatextDB("chores")
    local style = self:GetStandaloneDB().style
    db.tooltipHeaderFontSize = value
    style.tooltipFontSize = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipEntryFont(info)
    local style = self:GetStandaloneDB().style
    return style.tooltipFont or "Friz Quadrata TT"
end

function Options:SetChoresTooltipEntryFont(info, value)
    local db = self:GetDatatextDB("chores")
    local style = self:GetStandaloneDB().style
    db.tooltipEntryFont = value
    style.tooltipFont = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipEntryFontSize(info)
    local style = self:GetStandaloneDB().style
    return style.tooltipFontSize or 11
end

function Options:SetChoresTooltipEntryFontSize(info, value)
    local db = self:GetDatatextDB("chores")
    local style = self:GetStandaloneDB().style
    db.tooltipEntryFontSize = value
    style.tooltipFontSize = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetSharedHoverGlowColor(info)
    local style = self:GetStandaloneDB().style
    local c = style.hoverGlowColor
    if not c then
        local theme = T:GetModule("Theme", true)
        c = theme and theme:GetColor("accentColor") or { 0.96, 0.76, 0.24 }
    end
    return c[1], c[2], c[3], style.hoverGlowAlpha or 0.09
end

function Options:SetSharedHoverGlowColor(info, r, g, b, a)
    local style = self:GetStandaloneDB().style
    style.hoverGlowColor = { r, g, b, 1 }
    style.hoverGlowAlpha = a
    RefreshStandalonePanels()
end

function Options:GetSharedHoverBarColor(info)
    local style = self:GetStandaloneDB().style
    local c = style.hoverBarColor
    if not c then
        local theme = T:GetModule("Theme", true)
        c = theme and theme:GetColor("accentColor") or { 0.96, 0.76, 0.24 }
    end
    return c[1], c[2], c[3], style.hoverBarAlpha or 0.92
end

function Options:SetSharedHoverBarColor(info, r, g, b, a)
    local style = self:GetStandaloneDB().style
    style.hoverBarColor = { r, g, b, 1 }
    style.hoverBarAlpha = a
    RefreshStandalonePanels()
end

function Options:GetSharedTooltipFont(info)
    local style = self:GetStandaloneDB().style
    return style.tooltipFont or style.font or "Friz Quadrata TT"
end

function Options:SetSharedTooltipFont(info, value)
    local style = self:GetStandaloneDB().style
    style.tooltipFont = value
    RefreshStandalonePanels()
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetSharedTooltipFontSize(info)
    local style = self:GetStandaloneDB().style
    return style.tooltipFontSize or 11
end

function Options:SetSharedTooltipFontSize(info, value)
    local style = self:GetStandaloneDB().style
    style.tooltipFontSize = math.min(24, math.max(8, tonumber(value) or 11))
    RefreshStandalonePanels()
    RefreshDatatext("TwichUI: Chores")
end

--- Resets the shared (global) panel style to current theme-based defaults.
--- Wipes all custom overrides so colors, fonts, and alphas re-inherit from the Theme module.
function Options:ResetSharedStyle()
    local standalone = self:GetStandaloneDB()
    standalone.style = {}
    RefreshStandalonePanels()
end

--- Returns true when the given panel should use a fully transparent visual style
--- (panel background, border, accent bar and dividers all hidden).
function Options:GetPanelTransparentTheme(panelID)
    local panel = self:GetStandalonePanel(panelID)
    return panel and panel.transparentTheme == true or false
end

--- Enables or disables the transparent theme for the given panel.
function Options:SetPanelTransparentTheme(panelID, value)
    local panel = self:GetStandalonePanel(panelID)
    if panel then
        panel.transparentTheme = value == true
    end
    RefreshStandalonePanels()
end

--- Clears per-panel style overrides for the given panelID, reverting it to the shared style.
function Options:ResetPanelStyleOverrides(panelID)
    local panel = self:GetStandalonePanel(panelID)
    if panel then
        panel.style = {}
        panel.useStyleOverrides = false
    end
    RefreshStandalonePanels()
end

--- Clears style overrides on every panel, reverting all to the shared style.
function Options:ResetAllPanelStyleOverrides()
    local panelIDs = self:GetStandalonePanelIDs()
    for _, panelID in ipairs(panelIDs or {}) do
        local panel = self:GetStandalonePanel(panelID)
        if panel then
            panel.style = {}
            panel.useStyleOverrides = false
        end
    end
    RefreshStandalonePanels()
end

function Options:GetGatheringUseCustomColor(info)
    local db = self:GetDatatextDB("gathering")
    return db.customColor == true
end

function Options:SetGatheringUseCustomColor(info, value)
    local db = self:GetDatatextDB("gathering")
    db.customColor = value == true
    RefreshDatatext("TwichUI_GatheringDataText")
end

function Options:GetGatheringTextColor(info)
    local db = self:GetDatatextDB("gathering")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetGatheringTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("gathering")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI_GatheringDataText")
end

function Options:GetChoresTrackerMode(info)
    local db = self:GetDatatextDB("chores")
    return db.trackerMode or "framed"
end

function Options:SetChoresTrackerMode(info, value)
    local db = self:GetDatatextDB("chores")
    db.trackerMode = value or "framed"
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTrackerFrameTransparency(info)
    local db = self:GetDatatextDB("chores")
    local value = db.trackerFrameTransparency
    if type(value) ~= "number" then
        return 1
    end
    return math.min(1, math.max(0.2, value))
end

function Options:SetChoresTrackerFrameTransparency(info, value)
    local db = self:GetDatatextDB("chores")
    db.trackerFrameTransparency = math.min(1, math.max(0.2, tonumber(value) or 1))
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTrackerBackgroundTransparency(info)
    local db = self:GetDatatextDB("chores")
    local value = db.trackerBackgroundTransparency
    if type(value) ~= "number" then
        return 0.95
    end
    return math.min(1, math.max(0, value))
end

function Options:SetChoresTrackerBackgroundTransparency(info, value)
    local db = self:GetDatatextDB("chores")
    db.trackerBackgroundTransparency = math.min(1, math.max(0, tonumber(value) or 0.95))
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetFriendsCountWoWOnly(info)
    local db = self:GetDatatextDB("friends")
    return db.countWoWOnly == true
end

function Options:SetFriendsCountWoWOnly(info, value)
    local db = self:GetDatatextDB("friends")
    db.countWoWOnly = value == true
    RefreshDatatext("TwichUI: Friends")
end

--- GOBLIN DATATEXT OPTIONS ---
function Options:GetGoblinGoldDisplayMode(info)
    local db = self:GetDatatextDB("goblin")
    return db.displayMode or "full"
end

function Options:SetGoblinGoldDisplayMode(info, value)
    local db = self:GetDatatextDB("goblin")
    db.displayMode = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinShowProfessions(info)
    local db = self:GetDatatextDB("goblin")
    return db.showProfessions or false
end

function Options:SetGoblinShowProfessions(info, value)
    local db = self:GetDatatextDB("goblin")
    db.showProfessions = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinProfessionDisplayMode(info)
    local db = self:GetDatatextDB("goblin")
    return db.professionDisplayMode or "both"
end

function Options:SetGoblinProfessionDisplayMode(info, value)
    local db = self:GetDatatextDB("goblin")
    db.professionDisplayMode = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinProfessionShowMaxSkillLevel(info)
    local db = self:GetDatatextDB("goblin")
    return db.professionShowMaxSkillLevel or false
end

function Options:SetGoblinProfessionShowMaxSkillLevel(info, value)
    local db = self:GetDatatextDB("goblin")
    db.professionShowMaxSkillLevel = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinAddonShortcutsEnabled(info)
    local db = self:GetDatatextDB("goblin")
    return db.addonShortcutsEnabled or false
end

function Options:SetGoblinAddonShortcutsEnabled(info, value)
    local db = self:GetDatatextDB("goblin")
    db.addonShortcutsEnabled = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetIsGoblinAddonEnabled(addonName)
    local db = self:GetDatatextDB("goblin")
    if not db.enabledAddons then
        db.enabledAddons = {}
    end
    return db.enabledAddons[addonName] or false
end

function Options:SetIsGoblinAddonEnabled(addonName, value)
    local db = self:GetDatatextDB("goblin")
    if not db.enabledAddons then
        db.enabledAddons = {}
    end
    db.enabledAddons[addonName] = value
end
