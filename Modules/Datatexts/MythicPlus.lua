--[[
    Datatext providing Mythic+ season score, affixes, dungeon bests, and reward milestone progress.
]]
local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

local floor = math.floor
local min = math.min
local format = string.format
local tinsert = table.insert
local sort = table.sort

local C_ChallengeMode = _G.C_ChallengeMode
local C_MythicPlus = _G.C_MythicPlus
local C_PlayerInfo = _G.C_PlayerInfo
local C_WeeklyRewards = _G.C_WeeklyRewards
local Enum = _G.Enum
local ShowUIPanel = _G.ShowUIPanel
local WeeklyRewards_ShowUI = rawget(_G, "WeeklyRewards_ShowUI")
local LegacyLoadAddOn = rawget(_G, "LoadAddOn")
local PlayerInteractionFrameManager_ShowFrame = rawget(_G, "PlayerInteractionFrameManager_ShowFrame")
local GetDetailedItemLevelInfo = _G.C_Item and _G.C_Item.GetDetailedItemLevelInfo

---@class MythicPlusDataText : AceModule
---@field definition DatatextDefinition
---@field panel ElvUI_DT_Panel|nil
local MPDT = DataTextModule:NewModule("MythicPlusDataText")

local MILESTONES = {
    { score = 2000, label = "Catalyst Charge + Mount" },
    { score = 2500, label = "Tier Appearance" },
    { score = 3000, label = "Additional Mount" },
}

---@return DatatextConfigurationOptions
local function GetOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.Datatext
end

local function EnsureWeeklyRewardsLoaded()
    if _G.C_AddOns and type(_G.C_AddOns.LoadAddOn) == "function" then
        if type(_G.C_AddOns.IsAddOnLoaded) == "function" then
            if not _G.C_AddOns.IsAddOnLoaded("Blizzard_WeeklyRewards") then
                _G.C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
            end
        else
            _G.C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")
        end
    elseif type(LegacyLoadAddOn) == "function" then
        LegacyLoadAddOn("Blizzard_WeeklyRewards")
    end
end

local function OpenGreatVaultRewards()
    EnsureWeeklyRewardsLoaded()

    if type(WeeklyRewards_ShowUI) == "function" then
        WeeklyRewards_ShowUI()
        return
    end

    if type(PlayerInteractionFrameManager_ShowFrame) == "function" and Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.WeeklyRewards then
        PlayerInteractionFrameManager_ShowFrame(Enum.PlayerInteractionType.WeeklyRewards)
        return
    end

    local weeklyRewardsFrame = rawget(_G, "WeeklyRewardsFrame")
    if not weeklyRewardsFrame then
        return
    end

    if type(ShowUIPanel) == "function" then
        ShowUIPanel(weeklyRewardsFrame)
        return
    end

    if type(weeklyRewardsFrame.Show) == "function" then
        weeklyRewardsFrame:Show()
    end
end

local function OpenBestInSlotWindow()
    ---@type BestInSlotModule
    local bestInSlot = T:GetModule("BestInSlot")
    if bestInSlot and bestInSlot.Frame and bestInSlot.Frame.Show then
        bestInSlot.Frame:Show()
    end
end

local function GetMapName(mapID)
    if not C_ChallengeMode or type(C_ChallengeMode.GetMapUIInfo) ~= "function" then
        return format("Dungeon %d", mapID)
    end

    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if type(name) == "string" and name ~= "" then
        return name
    end

    return format("Dungeon %d", mapID)
end

local function GetCurrentAffixNames()
    if not C_MythicPlus or type(C_MythicPlus.GetCurrentAffixes) ~= "function" then
        return {}
    end

    local affixes = C_MythicPlus.GetCurrentAffixes()
    if type(affixes) ~= "table" then
        return {}
    end

    local names = {}
    for _, affix in ipairs(affixes) do
        local affixID = type(affix) == "table" and affix.id or nil
        if type(affixID) == "number" and C_ChallengeMode and type(C_ChallengeMode.GetAffixInfo) == "function" then
            local name = C_ChallengeMode.GetAffixInfo(affixID)
            if type(name) == "string" and name ~= "" then
                tinsert(names, name)
            end
        end
    end

    return names
end

local function GetRatingSummary()
    if C_PlayerInfo and type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) == "function" then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
        if type(summary) == "table" then
            return summary
        end
    end

    return nil
end

local function GetOverallScore(summary)
    if type(summary) == "table" and type(summary.currentSeasonScore) == "number" then
        return summary.currentSeasonScore
    end

    if C_ChallengeMode and type(C_ChallengeMode.GetOverallDungeonScore) == "function" then
        local overallScore = C_ChallengeMode.GetOverallDungeonScore()
        if type(overallScore) == "number" then
            return overallScore
        end
    end

    return 0
end

local function BuildRunLookup(summary)
    local lookup = {}
    if type(summary) ~= "table" or type(summary.runs) ~= "table" then
        return lookup
    end

    for _, runInfo in ipairs(summary.runs) do
        local mapID = type(runInfo) == "table" and runInfo.challengeModeID or nil
        if type(mapID) == "number" and mapID > 0 then
            lookup[mapID] = runInfo
        end
    end

    return lookup
end

local function GetFallbackSeasonBestForMap(mapID)
    if not C_MythicPlus or type(C_MythicPlus.GetSeasonBestForMap) ~= "function" then
        return nil
    end

    local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
    local bestRun = nil

    if type(intimeInfo) == "table" then
        bestRun = intimeInfo
    end

    if type(overtimeInfo) == "table" then
        if not bestRun or (overtimeInfo.dungeonScore or 0) > (bestRun.dungeonScore or 0) then
            bestRun = overtimeInfo
        end
    end

    return bestRun
end

local function GetDungeonRows(summary)
    local mapIDs = {}
    if C_ChallengeMode and type(C_ChallengeMode.GetMapTable) == "function" then
        mapIDs = C_ChallengeMode.GetMapTable() or {}
    end

    local lookup = BuildRunLookup(summary)
    local rows = {}

    for _, mapID in ipairs(mapIDs) do
        local runInfo = lookup[mapID]
        local mapScore = type(runInfo) == "table" and runInfo.mapScore or nil
        local bestRunLevel = type(runInfo) == "table" and runInfo.bestRunLevel or nil

        if type(mapScore) ~= "number" or type(bestRunLevel) ~= "number" then
            local bestRun = GetFallbackSeasonBestForMap(mapID)
            if type(bestRun) == "table" then
                mapScore = bestRun.dungeonScore
                bestRunLevel = bestRun.level
            end
        end

        tinsert(rows, {
            mapID = mapID,
            name = GetMapName(mapID),
            mapScore = type(mapScore) == "number" and mapScore or 0,
            bestRunLevel = type(bestRunLevel) == "number" and bestRunLevel or 0,
        })
    end

    sort(rows, function(left, right)
        return left.name < right.name
    end)

    return rows
end

local function FormatWholeNumber(value)
    if type(value) ~= "number" then
        return "0"
    end

    return tostring(floor(value + 0.5))
end

local function FormatSingleDecimal(value)
    if type(value) ~= "number" then
        return "0.0"
    end

    return format("%.1f", value)
end

function MPDT:ReleaseTooltipBars()
    return
end

local function GetMilestoneProgressText(currentScore, milestoneScore)
    local clampedScore = min(currentScore, milestoneScore)
    local progressText = FormatWholeNumber(clampedScore) .. "/" .. milestoneScore
    if currentScore >= milestoneScore then
        return T.Tools.Text.Color(T.Tools.Colors.GREEN, progressText)
    end
    return progressText
end

local function GetSectionTitle(text)
    return T.Tools.Text.Color(T.Tools.Colors.PRIMARY, text)
end

local function FormatRunCount(count)
    if type(count) ~= "number" or count <= 0 then
        return "0 Runs"
    end

    if count == 1 then
        return "1 Run"
    end

    return tostring(count) .. " Runs"
end

local function GetVaultSlotRows()
    EnsureWeeklyRewardsLoaded()

    if not C_WeeklyRewards or not Enum or not Enum.WeeklyRewardChestThresholdType or
        type(C_WeeklyRewards.GetActivities) ~= "function" then
        return {}
    end

    local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.Activities)
    if type(activities) ~= "table" then
        return {}
    end

    sort(activities, function(left, right)
        return (left.index or 0) < (right.index or 0)
    end)

    local rows = {}

    for slotIndex = 1, 3 do
        local activityInfo = activities[slotIndex]
        if type(activityInfo) == "table" then
            local progress = tonumber(activityInfo.progress) or 0
            local threshold = tonumber(activityInfo.threshold) or 0
            local unlocked = threshold > 0 and progress >= threshold
            local itemLevel = nil
            local nextItemLevel = nil
            local itemLink = nil

            if type(C_WeeklyRewards.GetExampleRewardItemHyperlinks) == "function" then
                itemLink = C_WeeklyRewards.GetExampleRewardItemHyperlinks(activityInfo.id)
            end

            if type(itemLink) == "string" and itemLink ~= "" and type(GetDetailedItemLevelInfo) == "function" then
                itemLevel = GetDetailedItemLevelInfo(itemLink)
            end

            if type(C_WeeklyRewards.GetNextActivitiesIncrease) == "function" and activityInfo.activityTierID and activityInfo.level then
                local hasData, _, _, nextItemLevelResult = C_WeeklyRewards.GetNextActivitiesIncrease(
                    activityInfo.activityTierID,
                    activityInfo.level
                )
                if hasData and type(nextItemLevelResult) == "number" then
                    nextItemLevel = nextItemLevelResult
                end
            end

            tinsert(rows, {
                slotIndex = slotIndex,
                progress = progress,
                threshold = threshold,
                unlocked = unlocked,
                itemLevel = itemLevel,
                nextItemLevel = nextItemLevel,
            })
        end
    end

    return rows
end

local function BuildVaultSlotLabel(row)
    return format("Slot %d  %s", row.slotIndex or 0,
        T.Tools.Text.Color(T.Tools.Colors.GRAY, "(" .. FormatRunCount(row.threshold) .. ")"))
end

local function BuildVaultSlotValue(row)
    local statusColor = row.unlocked and T.Tools.Colors.GREEN or T.Tools.Colors.WARNING
    local statusText = row.unlocked and "Unlocked" or format("%d/%d", row.progress or 0, row.threshold or 0)
    local value = T.Tools.Text.Color(statusColor, statusText)

    if type(row.itemLevel) == "number" and row.itemLevel > 0 then
        value = value .. T.Tools.Text.Color(T.Tools.Colors.GRAY, "  |  ilvl ") ..
            T.Tools.Text.Color(T.Tools.Colors.WHITE, FormatWholeNumber(row.itemLevel))
    else
        value = value .. T.Tools.Text.Color(T.Tools.Colors.GRAY, "  |  ilvl preview unavailable")
    end

    return value
end

local function AddGreatVaultSection(tooltip)
    local vaultRows = GetVaultSlotRows()

    tooltip:AddLine(GetSectionTitle("Great Vault - Dungeons"))

    if #vaultRows == 0 then
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Unavailable"))
        tooltip:AddLine(" ")
        return
    end

    for _, row in ipairs(vaultRows) do
        tooltip:AddDoubleLine(BuildVaultSlotLabel(row), BuildVaultSlotValue(row), 1, 1, 1, 1, 1, 1)

        if not row.unlocked and type(row.nextItemLevel) == "number" and row.nextItemLevel > 0 then
            tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY,
                format("   Next increase: ilvl %s", FormatWholeNumber(row.nextItemLevel))))
        end
    end

    tooltip:AddLine(" ")
end

function MPDT:Refresh()
    if not self.panel then
        return
    end

    local options = GetOptions()
    local score = GetOverallScore(GetRatingSummary())
    local valueColorR, valueColorG, valueColorB

    if options:GetMythicPlusUseCustomColor() then
        valueColorR, valueColorG, valueColorB = options:GetMythicPlusTextColor()
    else
        valueColorR, valueColorG, valueColorB = DataTextModule:GetElvUIValueColor()
    end

    if valueColorR and valueColorG and valueColorB then
        self.panel.text:SetText("M+: " ..
        T.Tools.Text.ColorRGB(valueColorR, valueColorG, valueColorB, FormatWholeNumber(score)))
        return
    end

    self.panel.text:SetText("M+: " .. FormatWholeNumber(score))
end

function MPDT:OnEvent(panel, event)
    if not self.panel then
        self.panel = panel
    end

    self:Refresh()
end

function MPDT:OnEnter(panel)
    if not self.panel then
        self.panel = panel
    end

    local options = GetOptions()
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    self:ReleaseTooltipBars()

    local summary = GetRatingSummary()
    local overallScore = GetOverallScore(summary)
    local dungeonRows = GetDungeonRows(summary)
    local affixNames = GetCurrentAffixNames()

    tooltip:ClearLines()
    tooltip:AddLine("Mythic+")
    tooltip:AddDoubleLine("Current Score", FormatWholeNumber(overallScore), 1, 1, 1, 1, 1, 1)
    tooltip:AddLine(" ")

    if options:GetMythicPlusShowAffixes() then
        tooltip:AddLine(GetSectionTitle("This Week's Affixes"))
        if #affixNames == 0 then
            tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Unavailable"))
        else
            for _, affixName in ipairs(affixNames) do
                tooltip:AddLine("- " .. affixName)
            end
        end
        tooltip:AddLine(" ")
    end

    if options:GetMythicPlusShowDungeonBests() then
        tooltip:AddLine(GetSectionTitle("Season Best By Dungeon"))
        for _, row in ipairs(dungeonRows) do
            local valueText
            if row.bestRunLevel > 0 then
                valueText = "+" .. row.bestRunLevel .. " | " .. FormatSingleDecimal(row.mapScore)
            else
                valueText = T.Tools.Text.Color(T.Tools.Colors.GRAY, "No run yet")
            end

            tooltip:AddDoubleLine(row.name, valueText, 1, 1, 1, 1, 1, 1)
        end
        tooltip:AddLine(" ")
    end

    AddGreatVaultSection(tooltip)

    if options:GetMythicPlusShowRewardProgress() then
        tooltip:AddLine(GetSectionTitle("Season Reward Progress"))
        for _, milestone in ipairs(MILESTONES) do
            tooltip:AddDoubleLine(milestone.label, GetMilestoneProgressText(overallScore, milestone.score), 1, 1, 1, 1, 1,
                1)
        end
        tooltip:AddLine(" ")
    end

    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Click: Open Mythic+ menu"))
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function MPDT:OnLeave()
    self:ReleaseTooltipBars()

    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function MPDT:OnClick(panel)
    local menuList = {
        {
            text = "Mythic+",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Best in Slot",
            notCheckable = true,
            func = OpenBestInSlotWindow,
        },
        {
            text = "Great Vault",
            notCheckable = true,
            func = OpenGreatVaultRewards,
        },
    }

    DataTextModule:ShowMenu(panel, menuList)
end

function MPDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Mythic+",
        prettyName = "Mythic+",
        events = {
            DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE,
            "PLAYER_ENTERING_WORLD",
            "CHALLENGE_MODE_MAPS_UPDATE",
            "CHALLENGE_MODE_COMPLETED",
            "MYTHIC_PLUS_CURRENT_AFFIX_UPDATE",
            "WEEKLY_REWARDS_UPDATE",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end
