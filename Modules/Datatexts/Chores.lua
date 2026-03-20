---@diagnostic disable: undefined-field
--[[
    Datatext showing remaining weekly chores.
]]
local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")
local LSM = T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)

local GetAccountExpansionLevel = _G.GetAccountExpansionLevel
local GetLFGDungeonInfo = _G.GetLFGDungeonInfo
local GetNumRFDungeons = _G.GetNumRFDungeons
local GetRFDungeonInfo = _G.GetRFDungeonInfo
local LegacyLoadAddOn = _G.LoadAddOn
local PVEFrameLoadUI = _G.PVEFrame_LoadUI
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

---@class ChoresDataText : AceModule, AceEvent-3.0
---@field definition DatatextDefinition
---@field panel ElvUI_DT_Panel|nil
---@field tooltipFontRestore table<number, {left: table|nil, right: table|nil}>|nil
local CDT = DataTextModule:NewModule("ChoresDataText", "AceEvent-3.0")

local MENU_CATEGORY_ITEMS = {
    { key = "delves",            name = "Delves",             icon = "Interface\\Icons\\inv_misc_map08" },
    { key = "abundance",         name = "Abundance",          icon = 134569 },
    { key = "unity",             name = "Unity",              icon = "Interface\\Icons\\achievement_guildperk_everybodysfriend" },
    { key = "hope",              name = "Hope",               icon = "Interface\\Icons\\spell_holy_holynova" },
    { key = "soiree",            name = "Soiree",             icon = "Interface\\Icons\\inv_misc_food_13" },
    { key = "stormarion",        name = "Stormarion",         icon = "Interface\\Icons\\spell_nature_lightning" },
    { key = "specialAssignment", name = "Special Assignment", icon = "Interface\\Icons\\inv_scroll_11" },
    { key = "dungeon",           name = "Dungeon",            iconAtlas = "Dungeon" },
}

local function GetDatatextOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.Datatext
end

local function GetChoresOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.Chores
end

local function GetChoresModule()
    ---@type ChoresModule
    return T:GetModule("Chores")
end

local function EnsureGroupFinderLoaded()
    if type(PVEFrameLoadUI) == "function" then
        PVEFrameLoadUI()
    end

    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        if type(C_AddOns.IsAddOnLoaded) == "function" then
            if not C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
                C_AddOns.LoadAddOn("Blizzard_GroupFinder")
            end
            if not C_AddOns.IsAddOnLoaded("Blizzard_PVE") then
                C_AddOns.LoadAddOn("Blizzard_PVE")
            end
        else
            C_AddOns.LoadAddOn("Blizzard_GroupFinder")
            C_AddOns.LoadAddOn("Blizzard_PVE")
        end
    elseif type(LegacyLoadAddOn) == "function" then
        LegacyLoadAddOn("Blizzard_GroupFinder")
        LegacyLoadAddOn("Blizzard_PVE")
    end
end

local function GetCurrentExpansionRaidWings()
    EnsureGroupFinderLoaded()

    local raidWings = {}
    local currentExpansionLevel = type(GetAccountExpansionLevel) == "function" and GetAccountExpansionLevel() or nil

    if type(GetNumRFDungeons) ~= "function" or type(GetRFDungeonInfo) ~= "function" then
        return raidWings
    end

    for index = 1, GetNumRFDungeons() do
        local dungeonID = GetRFDungeonInfo(index)
        local name
        local expansionLevel

        if type(dungeonID) == "number" then
            name, _, _, _, _, _, _, _, expansionLevel = GetLFGDungeonInfo(dungeonID)
        end

        if type(dungeonID) == "number" and dungeonID > 0 and name and (not currentExpansionLevel or expansionLevel == currentExpansionLevel) then
            table.insert(raidWings, {
                dungeonID = dungeonID,
                name = name,
            })
        end
    end

    table.sort(raidWings, function(left, right)
        return left.name < right.name
    end)

    return raidWings
end

local function GetValueColor()
    local options = GetDatatextOptions()
    if options:GetChoresUseCustomColor() then
        return options:GetChoresTextColor()
    end
    return DataTextModule:GetElvUIValueColor()
end

local function GetTooltipFontSettings()
    local options = GetDatatextOptions()
    local headerFontName = options:GetChoresTooltipHeaderFont()
    local entryFontName = options:GetChoresTooltipEntryFont()

    local headerFont = LSM and headerFontName and LSM:Fetch("font", headerFontName, true) or nil
    local entryFont = LSM and entryFontName and LSM:Fetch("font", entryFontName, true) or nil

    if not headerFont or headerFont == "" then
        headerFont = STANDARD_TEXT_FONT
    end

    if not entryFont or entryFont == "" then
        entryFont = STANDARD_TEXT_FONT
    end

    return {
        headerFont = headerFont,
        headerFontSize = options:GetChoresTooltipHeaderFontSize(),
        entryFont = entryFont,
        entryFontSize = options:GetChoresTooltipEntryFontSize(),
    }
end

local function GetStatusColorHex(status)
    if status == 2 then
        return T.Tools.Colors.GREEN
    end
    if status == 1 then
        return T.Tools.Colors.WARNING
    end
    return T.Tools.Colors.RED
end

local function BuildProgressText(summary)
    if summary.status == 2 then
        return T.Tools.Text.Color(T.Tools.Colors.GREEN, "Complete")
    end

    local progress = (summary.total - summary.remaining) .. "/" .. summary.total
    return T.Tools.Text.Color(GetStatusColorHex(summary.status), progress)
end

local function GetTooltipLineFontStrings(tooltip, lineIndex)
    local tooltipName = tooltip and tooltip.GetName and tooltip:GetName()
    if not tooltipName then
        return nil, nil
    end

    return _G[tooltipName .. "TextLeft" .. lineIndex], _G[tooltipName .. "TextRight" .. lineIndex]
end

local function SnapshotFontString(fontString)
    if not fontString or not fontString.GetFont then
        return nil
    end

    local fontPath, fontSize, fontFlags = fontString:GetFont()
    return {
        path = fontPath,
        size = fontSize,
        flags = fontFlags or "",
    }
end

local function RestoreFontString(fontString, snapshot)
    if not fontString or not fontString.SetFont or not snapshot then
        return
    end

    fontString:SetFont(snapshot.path or STANDARD_TEXT_FONT, snapshot.size or 12, snapshot.flags or "")
end

function CDT:RestoreTooltipFonts(tooltip)
    if not self.tooltipFontRestore then
        return
    end

    for lineIndex, snapshot in pairs(self.tooltipFontRestore) do
        local left, right = GetTooltipLineFontStrings(tooltip, lineIndex)
        RestoreFontString(left, snapshot.left)
        RestoreFontString(right, snapshot.right)
    end

    self.tooltipFontRestore = nil
end

local function ApplyTooltipLineFont(tooltip, lineIndex, fontPath, fontSize)
    local left, right = GetTooltipLineFontStrings(tooltip, lineIndex)
    if not left and not right then
        return
    end
    local currentFontPath, _, currentFlags

    if not CDT.tooltipFontRestore then
        CDT.tooltipFontRestore = {}
    end

    if not CDT.tooltipFontRestore[lineIndex] then
        CDT.tooltipFontRestore[lineIndex] = {
            left = SnapshotFontString(left),
            right = SnapshotFontString(right),
        }
    end

    if left and left.GetFont then
        currentFontPath, _, currentFlags = left:GetFont()
    end

    local resolvedFontPath = fontPath or currentFontPath or STANDARD_TEXT_FONT
    local resolvedFontSize = fontSize or 12
    local resolvedFlags = currentFlags or ""

    if left and left.SetFont then
        left:SetFont(resolvedFontPath, resolvedFontSize, resolvedFlags)
    end

    if right and right.SetFont then
        right:SetFont(resolvedFontPath, resolvedFontSize, resolvedFlags)
    end
end

local function BuildSummaryIcon(summary)
    if summary.iconAtlas then
        return ("|A:%s:16:16|a"):format(summary.iconAtlas)
    end

    return T.Tools.Text.Icon(summary.icon)
end

local function BuildSummaryLabel(summary)
    local label = BuildSummaryIcon(summary) .. " " .. T.Tools.Text.Color(GetStatusColorHex(summary.status), summary.name)
    if summary.infoText then
        label = label .. summary.infoText
    end
    return label
end

local function BuildObjectiveText(objective)
    local text = objective.text or ""
    if objective.need and objective.need > 0 then
        local progress = (objective.have or 0) .. "/" .. objective.need
        if string.match(text, "^" .. progress:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. "%s+") then
            return text
        end

        return progress .. " " .. text
    end

    return text
end

local function AddObjectiveLines(tooltip, entry, fontSettings)
    if not entry or not entry.state or type(entry.state.objectives) ~= "table" then
        return
    end

    for _, objective in ipairs(entry.state.objectives) do
        local prefix = T.Tools.Text.Color(T.Tools.Colors.GRAY, "    • ")
        tooltip:AddLine(prefix .. T.Tools.Text.Color(T.Tools.Colors.GRAY, BuildObjectiveText(objective)))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
    end
end

local function GetEntryColorHex(summary, status)
    if summary.showPendingEntries and status == 0 then
        return T.Tools.Colors.WARNING
    end

    return GetStatusColorHex(status)
end

function CDT:Refresh()
    if not self.panel then
        return
    end

    local choresModule = GetChoresModule()
    local state = choresModule and choresModule:GetState() or nil
    if not state or not state.enabled then
        self.panel.text:SetText(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Chores: Off"))
        return
    end

    local count = state.totalRemaining or 0
    local r, g, b = GetValueColor()
    if r and g and b then
        self.panel.text:SetText("Chores: " .. T.Tools.Text.ColorRGB(r, g, b, tostring(count)))
        return
    end

    self.panel.text:SetText("Chores: " .. tostring(count))
end

function CDT:OnEvent(panel)
    if not self.panel then
        self.panel = panel
    end

    self:Refresh()
end

function CDT:HandleChoresUpdated()
    self:Refresh()
    DataTextModule:RefreshDataText("TwichUI: Chores")
end

function CDT:GetMenuList()
    local choresOptions = GetChoresOptions()
    local menuList = {
        {
            text = "Chores",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Enable Tracking",
            checked = function()
                return choresOptions:GetEnabled()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetEnabled(nil, not choresOptions:GetEnabled())
            end,
        },
        {
            text = "Show Completed Chores",
            checked = function()
                return choresOptions:GetShowCompleted()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetShowCompleted(nil, not choresOptions:GetShowCompleted())
            end,
        },
        {
            text = "",
            disabled = true,
            notCheckable = true,
        },
        {
            text = "Weekly Chores",
            isTitle = true,
            notCheckable = true,
        },
    }

    for _, item in ipairs(MENU_CATEGORY_ITEMS) do
        local iconMarkup = item.iconAtlas and ("|A:%s:16:16|a "):format(item.iconAtlas) or
        (T.Tools.Text.Icon(item.icon) .. " ")
        table.insert(menuList, {
            text = iconMarkup .. item.name,
            checked = function()
                return choresOptions:IsCategoryEnabled(item.key)
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCategoryEnabled(item.key, not choresOptions:IsCategoryEnabled(item.key))
            end,
        })
    end

    table.insert(menuList, {
        text = "",
        disabled = true,
        notCheckable = true,
    })
    table.insert(menuList, {
        text = "Additional Tracking",
        isTitle = true,
        notCheckable = true,
    })
    table.insert(menuList, {
        text = T.Tools.Text.Icon("Interface\\Icons\\inv_misc_map08") .. " Bountiful Delves",
        checked = function()
            return choresOptions:GetTrackBountifulDelves()
        end,
        isNotRadio = true,
        keepShownOnClick = true,
        func = function()
            choresOptions:SetTrackBountifulDelves(nil, not choresOptions:GetTrackBountifulDelves())
        end,
    })

    local raidWings = GetCurrentExpansionRaidWings()
    if #raidWings > 0 then
        table.insert(menuList, {
            text = "",
            disabled = true,
            notCheckable = true,
        })
        table.insert(menuList, {
            text = "Raid Finder Wings",
            isTitle = true,
            notCheckable = true,
        })

        for _, raidWing in ipairs(raidWings) do
            table.insert(menuList, {
                text = ("|A:%s:16:16|a "):format("Raid") .. raidWing.name,
                checked = function()
                    return choresOptions:IsRaidWingEnabled(raidWing.dungeonID)
                end,
                isNotRadio = true,
                keepShownOnClick = true,
                func = function()
                    choresOptions:SetRaidWingEnabled(raidWing.dungeonID,
                        not choresOptions:IsRaidWingEnabled(raidWing.dungeonID))
                end,
            })
        end
    end

    return menuList
end

function CDT:OnClick(panel, button)
    if button == "RightButton" then
        DataTextModule:ShowMenu(panel, self:GetMenuList())
    end
end

function CDT:OnEnter(panel)
    if not self.panel then
        self.panel = panel
    end

    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    self:RestoreTooltipFonts(tooltip)

    local choresModule = GetChoresModule()
    local choresOptions = GetChoresOptions()
    local state = choresModule and choresModule:GetState() or nil
    local showCompleted = choresOptions and choresOptions.GetShowCompleted and choresOptions:GetShowCompleted() or false
    local fontSettings = GetTooltipFontSettings()

    tooltip:ClearLines()
    tooltip:AddLine("Weekly Chores")
    ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.headerFont, fontSettings.headerFontSize)

    if not state or not state.enabled then
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Enable Quality of Life > Chores to start tracking."))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
        tooltip:Show()
        return
    end

    if #state.orderedCategories == 0 then
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY,
            "No tracked chores are active for this character right now."))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
        tooltip:Show()
        return
    end

    tooltip:AddDoubleLine("Remaining", T.Tools.Text.Color(T.Tools.Colors.WARNING, tostring(state.totalRemaining)), 1, 1,
        1, 1, 1, 1)
    ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.headerFont, fontSettings.headerFontSize)
    tooltip:AddLine(" ")

    local displayedSummaryCount = 0
    for _, summary in ipairs(state.orderedCategories) do
        local entries = showCompleted and summary.entries or summary.selectedEntries
        local shouldShowSummary = showCompleted or summary.remaining > 0

        if shouldShowSummary then
            local visibleEntries = {}
            for _, entry in ipairs(entries) do
                if showCompleted or entry.state.status ~= 2 then
                    table.insert(visibleEntries, entry)
                end
            end

            if showCompleted or #visibleEntries > 0 then
                displayedSummaryCount = displayedSummaryCount + 1
                local label = BuildSummaryLabel(summary)
                tooltip:AddDoubleLine(label, BuildProgressText(summary), 1, 1, 1, 1, 1, 1)
                ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.headerFont, fontSettings.headerFontSize)

                if not (showCompleted and summary.status == 2) then
                    for _, entry in ipairs(visibleEntries) do
                        local shouldShowEntry = summary.showPendingEntries and entry.state.status ~= 2 or
                        entry.state.status == 1
                        if shouldShowEntry then
                            local entryColor = GetEntryColorHex(summary, entry.state.status)
                            tooltip:AddLine(T.Tools.Text.Color(entryColor, "  • " .. (entry.state.title or summary.name)))
                            ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont,
                                fontSettings.entryFontSize)
                            AddObjectiveLines(tooltip, entry, fontSettings)
                        end
                    end
                end

                tooltip:AddLine(" ")
            end
        end
    end

    if displayedSummaryCount == 0 then
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "All tracked chores are complete."))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
        tooltip:AddLine(" ")
    end

    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Right-click to toggle chores on or off."))
    ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
    tooltip:Show()
end

function CDT:OnLeave()
    local tooltip = DataTextModule:GetElvUITooltip()
    if tooltip and tooltip.Hide then
        self:RestoreTooltipFonts(tooltip)
        tooltip:Hide()
    end
end

function CDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Chores",
        prettyName = "Chores",
        events = {
            DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE,
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = function(...) self:OnEvent(...) end,
        onUpdateFunc = nil,
        onClickFunc = function(...) self:OnClick(...) end,
        onEnterFunc = function(...) self:OnEnter(...) end,
        onLeaveFunc = function() self:OnLeave() end,
    }

    DataTextModule:Inform(self.definition)
end

function CDT:OnEnable()
    self:RegisterMessage("TWICHUI_CHORES_UPDATED", "HandleChoresUpdated")
end
