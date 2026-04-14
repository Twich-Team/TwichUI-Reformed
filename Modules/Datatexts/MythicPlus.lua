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
local C_AddOns = rawget(_G, "C_AddOns")
local C_MythicPlus = _G.C_MythicPlus
local C_PlayerInfo = _G.C_PlayerInfo
local C_Timer = _G.C_Timer
local C_TooltipInfo = _G.C_TooltipInfo
local C_WeeklyRewards = _G.C_WeeklyRewards
local CreateFrame = _G.CreateFrame
local Enum = _G.Enum
local GetAddOnEnableState = rawget(_G, "GetAddOnEnableState")
local LegacyGetAddOnMetadata = rawget(_G, "GetAddOnMetadata")
local ShowUIPanel = _G.ShowUIPanel
local UIParent = _G.UIParent
local UnitName = _G.UnitName
local WeeklyRewards_ShowUI = rawget(_G, "WeeklyRewards_ShowUI")
local LegacyLoadAddOn = rawget(_G, "LoadAddOn")
local LibStub = _G.LibStub
local PlayerInteractionFrameManager_ShowFrame = rawget(_G, "PlayerInteractionFrameManager_ShowFrame")
local GetDetailedItemLevelInfo = _G.C_Item and _G.C_Item.GetDetailedItemLevelInfo

local SIMC_ADDON_NAME = "Simulationcraft"

---@class MythicPlusDataText : AceModule
---@field definition DatatextDefinition
---@field panel ElvUI_DT_Panel|nil
---@field SimulationCraftFrame Frame|nil
local MPDT = DataTextModule:NewModule("MythicPlusDataText")

---@class SimulationCraftAddon : AceModule
---@field GetSimcProfile fun(self: SimulationCraftAddon, debugOutput:boolean, noBags:boolean, showMerchant:boolean, links:any|nil): string, string|nil

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

local function GetMythicPlusToolsOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.MythicPlusTools
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

local function GetSimulationCraftInstallState()
    local installed = false

    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        installed = type(C_AddOns.GetAddOnMetadata(SIMC_ADDON_NAME, "Title")) == "string"
    elseif type(LegacyGetAddOnMetadata) == "function" then
        installed = type(LegacyGetAddOnMetadata(SIMC_ADDON_NAME, "Title")) == "string"
    end

    if not installed then
        return false, false, false
    end

    local enabled = false
    if type(GetAddOnEnableState) == "function" then
        enabled = (GetAddOnEnableState(UnitName("player"), SIMC_ADDON_NAME) or 0) > 0
    end

    local loaded = C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded(SIMC_ADDON_NAME) or
    false
    if loaded then
        enabled = true
    end

    return installed, enabled, loaded
end

local function GetSimulationCraftMenuLabel()
    local installed, enabled = GetSimulationCraftInstallState()
    if not installed then
        return "SimulationCraft Export (Not Installed)", true
    end

    if not enabled then
        return "SimulationCraft Export (Disabled)", true
    end

    return "SimulationCraft Export", false
end

local function GetSimulationCraftAddon()
    local installed, enabled, loaded = GetSimulationCraftInstallState()
    if not installed then
        return nil, "SimulationCraft is not installed."
    end

    if not enabled then
        return nil, "SimulationCraft is installed but disabled."
    end

    if not loaded then
        if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
            local ok, reason = C_AddOns.LoadAddOn(SIMC_ADDON_NAME)
            if ok ~= true then
                return nil,
                    reason and ("SimulationCraft could not be loaded: " .. tostring(reason)) or
                    "SimulationCraft could not be loaded."
            end
        elseif type(LegacyLoadAddOn) == "function" then
            local ok, reason = pcall(LegacyLoadAddOn, SIMC_ADDON_NAME)
            if not ok then
                return nil,
                    reason and ("SimulationCraft could not be loaded: " .. tostring(reason)) or
                    "SimulationCraft could not be loaded."
            end
        end
    end

    local aceAddon = LibStub and LibStub("AceAddon-3.0", true)
    ---@type SimulationCraftAddon|nil
    local addon = aceAddon and aceAddon.GetAddon and aceAddon:GetAddon(SIMC_ADDON_NAME, true) or nil
    if not addon or type(addon.GetSimcProfile) ~= "function" then
        return nil, "SimulationCraft export API is unavailable."
    end

    return addon, nil
end

local function CreateSimulationCraftExportFrame(owner)
    local frame = CreateFrame("Frame", "TwichUISimulationCraftExportFrame", UIParent, "BackdropTemplate")
    frame:SetSize(820, 560)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(180)
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.035, 0.045, 0.06, 0.97)
        frame:SetBackdropBorderColor(0.14, 0.72, 0.72, 0.24)
    end

    frame.TopAccent = frame:CreateTexture(nil, "ARTWORK")
    frame.TopAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TopAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TopAccent:SetHeight(3)
    frame.TopAccent:SetColorTexture(0.95, 0.76, 0.24, 0.95)

    frame.Glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.Glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.Glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.Glow:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.Glow:SetGradient("VERTICAL", CreateColor(0.16, 0.78, 0.78, 0.12), CreateColor(0, 0, 0, 0))

    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -14)
    frame.Title:SetText("SimulationCraft Export")

    frame.Subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Subtitle:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -6)
    frame.Subtitle:SetPoint("RIGHT", frame, "RIGHT", -60, 0)
    frame.Subtitle:SetJustifyH("LEFT")
    frame.Subtitle:SetText("Press Ctrl+C to copy. The window closes automatically after copy.")

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinCloseButton then
        T.Tools.UI.SkinCloseButton(frame.CloseButton)
    end
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -56)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, 52)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(frame.ScrollFrame, { 0.16, 0.78, 0.78 }, true)
    end

    frame.EditBox = CreateFrame("EditBox", nil, frame.ScrollFrame, "BackdropTemplate")
    frame.EditBox:SetMultiLine(true)
    frame.EditBox:SetAutoFocus(true)
    frame.EditBox:SetFontObject("ChatFontNormal")
    frame.EditBox:SetWidth(740)
    frame.EditBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    frame.EditBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    frame.EditBox:SetScript("OnMouseUp", function(self)
        self:SetFocus()
    end)

    local ctrlDown = false
    frame.EditBox:SetScript("OnKeyDown", function(_, key)
        if key == "LCTRL" or key == "RCTRL" or key == "LMETA" or key == "RMETA" then
            ctrlDown = true
        end
    end)
    frame.EditBox:SetScript("OnKeyUp", function(_, key)
        if key == "LCTRL" or key == "RCTRL" or key == "LMETA" or key == "RMETA" then
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.2, function()
                    ctrlDown = false
                end)
            else
                ctrlDown = false
            end
            return
        end

        if ctrlDown and (key == "C" or key == "X") then
            if C_Timer and type(C_Timer.After) == "function" then
                C_Timer.After(0.1, function()
                    if frame and frame.Hide then
                        frame:Hide()
                    end
                end)
            else
                frame:Hide()
            end
        end
    end)

    if frame.EditBox.SetBackdrop then
        frame.EditBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame.EditBox:SetBackdropColor(0.06, 0.07, 0.09, 0.96)
        frame.EditBox:SetBackdropBorderColor(0.22, 0.24, 0.3, 0.16)
    end
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinEditBox then
        T.Tools.UI.SkinEditBox(frame.EditBox)
    end

    frame.ScrollFrame:SetScrollChild(frame.EditBox)

    frame.ActionButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.ActionButton:SetSize(120, 24)
    frame.ActionButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 16)
    frame.ActionButton:SetText("Highlight All")
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(frame.ActionButton, { 0.95, 0.76, 0.24 })
    elseif T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(frame.ActionButton)
    end
    frame.ActionButton:SetScript("OnClick", function()
        frame.EditBox:SetFocus()
        frame.EditBox:HighlightText()
    end)

    frame.CloseAction = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.CloseAction:SetSize(84, 24)
    frame.CloseAction:SetPoint("RIGHT", frame.ActionButton, "LEFT", -10, 0)
    frame.CloseAction:SetText("Close")
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(frame.CloseAction, { 0.16, 0.78, 0.78 })
    elseif T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(frame.CloseAction)
    end
    frame.CloseAction:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame:SetScript("OnHide", function(self)
        if self.EditBox and self.EditBox.ClearFocus then
            self.EditBox:ClearFocus()
        end
    end)

    frame:SetScript("OnSizeChanged", function(self)
        if self.EditBox then
            self.EditBox:SetWidth(math.max(1, (self.ScrollFrame:GetWidth() or 1) - 8))
        end
    end)

    owner.SimulationCraftFrame = frame
    return frame
end

function MPDT:ShowSimulationCraftExportFrame(text, isError)
    local frame = self.SimulationCraftFrame or CreateSimulationCraftExportFrame(self)
    if not frame then
        return
    end

    frame.Title:SetText(isError and "SimulationCraft Message" or "SimulationCraft Export")
    frame.Subtitle:SetText(isError and "SimulationCraft returned a message instead of an export string." or
    "Press Ctrl+C to copy. The window closes automatically after copy.")
    frame.EditBox:SetText(text or "")
    frame.EditBox:SetCursorPosition(0)
    frame.EditBox:SetFocus()
    frame.EditBox:HighlightText()
    frame:Show()
end

function MPDT:OpenSimulationCraftExport()
    local addon, err = GetSimulationCraftAddon()
    if not addon then
        T:Print(err)
        return
    end

    local profile, simcError = addon:GetSimcProfile(false, false, false)
    local output = simcError or profile
    if type(output) ~= "string" or output == "" then
        T:Print("SimulationCraft did not return an export string.")
        return
    end

    self:ShowSimulationCraftExportFrame(output, simcError ~= nil)
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
                itemLink = itemLink,
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

local function GetVaultUpgradeTrackLabel(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return nil
    end

    if not (C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function") then
        return nil
    end

    local ok, tooltipData = pcall(C_TooltipInfo.GetHyperlink, itemLink)
    if not ok or type(tooltipData) ~= "table" or type(tooltipData.lines) ~= "table" then
        return nil
    end

    for _, line in ipairs(tooltipData.lines) do
        if type(line) == "table" then
            local leftText = line.leftText
            if type(leftText) == "string" and leftText ~= "" then
                local trackName, currentRank, maxRank = leftText:match("([A-Za-z]+)%s+(%d+)%/(%d+)")
                if trackName and currentRank and maxRank then
                    return format("%s %s/%s", trackName, currentRank, maxRank)
                end

                local prefixedTrackName, prefixedCurrent, prefixedMax = leftText:match(
                "Upgrade Level:%s+([A-Za-z]+)%s+(%d+)%/(%d+)")
                if prefixedTrackName and prefixedCurrent and prefixedMax then
                    return format("%s %s/%s", prefixedTrackName, prefixedCurrent, prefixedMax)
                end
            end
        end
    end

    return nil
end

local function BuildVaultSlotValue(row)
    local statusColor = row.unlocked and T.Tools.Colors.GREEN or T.Tools.Colors.WARNING
    local statusText = row.unlocked and "Unlocked" or format("%d/%d", row.progress or 0, row.threshold or 0)
    local value = T.Tools.Text.Color(statusColor, statusText)
    local upgradeTrack = GetVaultUpgradeTrackLabel(row.itemLink)

    if type(row.itemLevel) == "number" and row.itemLevel > 0 then
        value = value .. T.Tools.Text.Color(T.Tools.Colors.GRAY, "  |  ilvl ") ..
            T.Tools.Text.Color(T.Tools.Colors.WHITE, FormatWholeNumber(row.itemLevel))
    else
        value = value .. T.Tools.Text.Color(T.Tools.Colors.GRAY, "  |  ilvl preview unavailable")
    end

    if type(upgradeTrack) == "string" and upgradeTrack ~= "" then
        value = value .. T.Tools.Text.Color(T.Tools.Colors.GRAY, "  |  ") ..
            T.Tools.Text.Color(T.Tools.Colors.WHITE, upgradeTrack)
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
        local nextText = "M+: " .. T.Tools.Text.ColorRGB(valueColorR, valueColorG, valueColorB, FormatWholeNumber(score))
        local previousText = self.panel.text:GetText()
        self.panel.text:SetText(nextText)
        DataTextModule:MaybeFlashPanel(self.panel, "mythicplus", previousText, nextText)
        return
    end

    local nextText = "M+: " .. FormatWholeNumber(score)
    local previousText = self.panel.text:GetText()
    self.panel.text:SetText(nextText)
    DataTextModule:MaybeFlashPanel(self.panel, "mythicplus", previousText, nextText)
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
    local mythicPlusToolsOptions = GetMythicPlusToolsOptions()
    local simcMenuLabel, simcDisabled = GetSimulationCraftMenuLabel()
    local menuList = {
        {
            text = "Mythic+",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Show Mythic+ Timer",
            checked = function()
                return mythicPlusToolsOptions and mythicPlusToolsOptions.GetMythicPlusTimerEnabled and
                    mythicPlusToolsOptions:GetMythicPlusTimerEnabled()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                if mythicPlusToolsOptions and mythicPlusToolsOptions.SetMythicPlusTimerEnabled and mythicPlusToolsOptions.GetMythicPlusTimerEnabled then
                    mythicPlusToolsOptions:SetMythicPlusTimerEnabled(nil,
                        not mythicPlusToolsOptions:GetMythicPlusTimerEnabled())
                end
            end,
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
        {
            text = simcMenuLabel,
            notCheckable = true,
            disabled = simcDisabled,
            func = function()
                self:OpenSimulationCraftExport()
            end,
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
