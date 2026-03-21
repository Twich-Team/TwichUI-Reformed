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
local C_Item = _G.C_Item
local PREY_ICON =
"Interface\\AddOns\\TwichUI_Redux\\Modules\\Chores\\Plumber\\Art\\ExpansionLandingPage\\Icons\\InProgressPrey.png"

---@class ChoresDataText : AceModule, AceEvent-3.0
---@field definition DatatextDefinition
---@field panel ElvUI_DT_Panel|nil
---@field tooltipFontRestore table<number, {left: table|nil, right: table|nil}>|nil
local CDT = DataTextModule:NewModule("ChoresDataText", "AceEvent-3.0")

local MENU_CATEGORY_ITEMS = {
    { key = "delves",            name = "Delver's Call",          iconAtlas = "delves-regular" },
    { key = "abundance",         name = "Abundance",              iconAtlas = "UI-EventPoi-abundancebountiful" },
    { key = "unity",             name = "Unity Against the Void", icon = "Interface\\Icons\\Inv_nullstone_void" },
    { key = "hope",              name = "Legends of the Haranir", icon = "Interface\\Icons\\Inv_achievement_zone_harandar" },
    { key = "soiree",            name = "Saltheril's Soiree",     iconAtlas = "UI-EventPoi-saltherilssoiree" },
    { key = "stormarion",        name = "Stormarion Assault",     iconAtlas = "UI-EventPoi-stormarionassault" },
    { key = "specialAssignment", name = "Special Assignment",     iconAtlas = "worldquest-Capstone-questmarker-epic-locked" },
    { key = "dungeon",           name = "Dungeon",                iconAtlas = "Dungeon" },
}

local function GetProfessionMenuItems()
    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if not choresModule or not choresModule.GetProfessionCategoryDefinitions then
        return {}
    end

    return choresModule:GetProfessionCategoryDefinitions() or {}
end

local function GetPreyDifficultyMenuItems()
    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if not choresModule or not choresModule.GetPreyDifficultyDefinitions then
        return {}
    end

    return choresModule:GetPreyDifficultyDefinitions() or {}
end

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
    local progressColor = summary.countTowardsTotal == false and T.Tools.Colors.GRAY or GetStatusColorHex(summary.status)

    if summary.status == 2 then
        return T.Tools.Text.Color(progressColor, "Complete")
    end

    local current = summary.progressStyle == "remaining" and summary.remaining or (summary.total - summary.remaining)
    local progress = current .. "/" .. summary.total
    return T.Tools.Text.Color(progressColor, progress)
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
    local prefix = ""

    if objective.itemID and C_Item and type(C_Item.GetItemIconByID) == "function" then
        local itemIcon = C_Item.GetItemIconByID(objective.itemID)
        if itemIcon then
            prefix = ("|T%d:14:14:0:0|t "):format(itemIcon)
        end
    end

    if objective.need and objective.need > 0 then
        local progress = (objective.have or 0) .. "/" .. objective.need
        if string.match(text, "^" .. progress:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. "%s+") then
            return prefix .. text
        end

        return prefix .. progress .. " " .. text
    end

    return prefix .. text
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

local function BuildMenuSectionTitle(text)
    return T.Tools.Text.ColorRGB(0.45, 0.78, 1, text)
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
            text = "Count Toward Total",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = T.Tools.Text.Icon("Interface\\Icons\\Inv_12_profession_enchanting_enchantedvellum_blue") ..
                " Profession Chores",
            checked = function()
                return choresOptions:GetCountProfessionsTowardTotal()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCountProfessionsTowardTotal(nil, not choresOptions:GetCountProfessionsTowardTotal())
            end,
        },
        {
            text = "|A:delves-bountiful:16:16|a Bountiful Delves",
            checked = function()
                return choresOptions:GetCountBountifulDelvesTowardTotal()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCountBountifulDelvesTowardTotal(nil,
                    not choresOptions:GetCountBountifulDelvesTowardTotal())
            end,
        },
        {
            text = T.Tools.Text.Icon(PREY_ICON) .. " Prey",
            checked = function()
                return choresOptions:GetCountPreyTowardTotal()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCountPreyTowardTotal(nil, not choresOptions:GetCountPreyTowardTotal())
            end,
        },
        {
            text = "",
            disabled = true,
            notCheckable = true,
        },
        {
            text = BuildMenuSectionTitle("Weekly Chores"),
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

    local professionMenuItems = GetProfessionMenuItems()
    if #professionMenuItems > 0 then
        table.insert(menuList, {
            text = "",
            disabled = true,
            notCheckable = true,
        })
        table.insert(menuList, {
            text = BuildMenuSectionTitle("Profession Chores"),
            isTitle = true,
            notCheckable = true,
        })

        for _, item in ipairs(professionMenuItems) do
            table.insert(menuList, {
                text = T.Tools.Text.Icon(item.icon) .. " " .. item.name,
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
    end

    table.insert(menuList, {
        text = "",
        disabled = true,
        notCheckable = true,
    })
    table.insert(menuList, {
        text = BuildMenuSectionTitle("Additional Tracking"),
        isTitle = true,
        notCheckable = true,
    })
    table.insert(menuList, {
        text = "|A:delves-bountiful:16:16|a Bountiful Delves",
        checked = function()
            return choresOptions:GetTrackBountifulDelves()
        end,
        isNotRadio = true,
        keepShownOnClick = true,
        func = function()
            choresOptions:SetTrackBountifulDelves(nil, not choresOptions:GetTrackBountifulDelves())
        end,
    })
    table.insert(menuList, {
        text = T.Tools.Text.Icon(PREY_ICON) .. " Prey",
        checked = function()
            return choresOptions:GetTrackPrey()
        end,
        isNotRadio = true,
        keepShownOnClick = true,
        func = function()
            choresOptions:SetTrackPrey(nil, not choresOptions:GetTrackPrey())
        end,
    })

    local preyDifficulties = GetPreyDifficultyMenuItems()
    if #preyDifficulties > 0 then
        table.insert(menuList, {
            text = "",
            disabled = true,
            notCheckable = true,
        })
        table.insert(menuList, {
            text = BuildMenuSectionTitle("Prey Difficulties"),
            isTitle = true,
            notCheckable = true,
        })

        for _, difficulty in ipairs(preyDifficulties) do
            table.insert(menuList, {
                text = difficulty.name,
                checked = function()
                    return choresOptions:IsPreyDifficultyEnabled(difficulty.key)
                end,
                isNotRadio = true,
                keepShownOnClick = true,
                func = function()
                    choresOptions:SetPreyDifficultyEnabled(difficulty.key,
                        not choresOptions:IsPreyDifficultyEnabled(difficulty.key))
                end,
            })
        end
    end

    local raidWings = GetCurrentExpansionRaidWings()
    if #raidWings > 0 then
        table.insert(menuList, {
            text = "",
            disabled = true,
            notCheckable = true,
        })
        table.insert(menuList, {
            text = BuildMenuSectionTitle("Raid Finder Wings"),
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
    if button == "LeftButton" then
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

    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Left-click to toggle chores on or off."))
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
