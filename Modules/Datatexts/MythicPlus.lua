--[[
    Datatext providing Mythic+ season score, affixes, dungeon bests, and reward milestone progress.
]]
local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

local floor = math.floor
local max = math.max
local min = math.min
local format = string.format
local gsub = string.gsub
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
---@field EstimatorFrame Frame|nil
---@field SimulationCraftFrame Frame|nil
local MPDT = DataTextModule:NewModule("MythicPlusDataText")

---@class SimulationCraftAddon : AceModule
---@field GetSimcProfile fun(self: SimulationCraftAddon, debugOutput:boolean, noBags:boolean, showMerchant:boolean, links:any|nil): string, string|nil

local MILESTONES = {
    { score = 2000, label = "Catalyst Charge + Mount" },
    { score = 2500, label = "Tier Appearance" },
    { score = 3000, label = "Additional Mount" },
}

local ESTIMATOR_OUTCOME_PROFILES = {
    { key = "timed1", label = "Timed (+1)", shortLabel = "+1", starCount = 1, parFraction = 1.00, difficulty = 1 },
    { key = "timed2", label = "Timed (+2)", shortLabel = "+2", starCount = 2, parFraction = 0.80, difficulty = 2 },
    { key = "timed3", label = "Timed (+3)", shortLabel = "+3", starCount = 3, parFraction = 0.60, difficulty = 3 },
}

local ESTIMATOR_OUTCOME_CAPS = {
    { key = "timed1", label = "Timed (+1) Max", maxDifficulty = 1 },
    { key = "timed2", label = "Timed (+2) Max", maxDifficulty = 2 },
    { key = "timed3", label = "Timed (+3) Max", maxDifficulty = 3 },
}

local ESTIMATOR_ROUTE_MODES = {
    { key = "quickest",   label = "Quickest Route", description = "Prioritize the biggest score gains per run to hit the target in as few upgrades as possible." },
    { key = "balanced",   label = "Balanced Route", description = "Trade some efficiency for easier keys and more forgiving upgrades." },
    { key = "easiest",    label = "Easiest Route",  description = "Bias hard toward accessible completions and softer timer requirements." },
    { key = "lowestkeys", label = "Lowest Keys",    description = "Push the minimum key level first, then take the best score gain available at that level." },
}

local ESTIMATOR_OUTCOME_COLORS = {
    timed1 = { 0.24, 0.72, 0.92 },
    timed2 = { 0.46, 0.78, 0.38 },
    timed3 = { 0.90, 0.68, 0.22 },
}

local GetMapName
local GetRatingSummary
local GetOverallScore

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

local function ClampNumber(value, low, high)
    if type(value) ~= "number" then
        return low
    end

    if value < low then
        return low
    end

    if value > high then
        return high
    end

    return value
end

local function RoundHalfUp(value)
    if type(value) ~= "number" then
        return 0
    end

    if value >= 0 then
        return floor(value + 0.5)
    end

    return -floor(-value + 0.5)
end

local function FormatEstimatorNumber(value)
    return format("%d", RoundHalfUp(value or 0))
end

local function FormatEstimatorDelta(value)
    local rounded = RoundHalfUp(value or 0)
    if rounded > 0 then
        return "+" .. rounded
    end

    return tostring(rounded)
end

local function ParseEstimatorInteger(value, fallback)
    if type(value) == "number" then
        return RoundHalfUp(value)
    end

    if type(value) ~= "string" then
        return fallback
    end

    local digits = value:match("%-?%d+")
    local parsed = digits and tonumber(digits) or nil
    if type(parsed) ~= "number" then
        return fallback
    end

    return RoundHalfUp(parsed)
end

local function NormalizeEstimatorInputText(text)
    if type(text) ~= "string" then
        return ""
    end

    return (gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function GetEstimatorMode(modeIndex)
    return ESTIMATOR_ROUTE_MODES[ClampNumber(modeIndex or 1, 1, #ESTIMATOR_ROUTE_MODES)]
end

local function GetEstimatorOutcomeCap(capIndex)
    return ESTIMATOR_OUTCOME_CAPS[ClampNumber(capIndex or 2, 1, #ESTIMATOR_OUTCOME_CAPS)]
end

local function GetEstimatorAllowedOutcomes(capIndex)
    local cap = GetEstimatorOutcomeCap(capIndex)
    local outcomes = {}

    for _, profile in ipairs(ESTIMATOR_OUTCOME_PROFILES) do
        if profile.difficulty <= cap.maxDifficulty then
            tinsert(outcomes, profile)
        end
    end

    return outcomes
end

local function GetOutcomeVisuals(outcomeKey)
    local color = ESTIMATOR_OUTCOME_COLORS[outcomeKey] or { 0.75, 0.75, 0.75 }
    return color[1], color[2], color[3]
end

local function GetEstimatorBreakpointBonus(level)
    local bonus = 0
    if level >= 5 then
        bonus = bonus + 15
    end
    if level >= 7 then
        bonus = bonus + 15
    end
    if level >= 10 then
        bonus = bonus + 15
    end
    if level >= 12 then
        bonus = bonus + 15
    end
    return bonus
end

local function GetEstimatorDungeonBaseScore(level)
    if type(level) ~= "number" or level <= 0 then
        return 0
    end

    local wholeLevel = RoundHalfUp(level)
    if wholeLevel < 2 then
        return 0
    end

    return 155 + ((wholeLevel - 2) * 15) + GetEstimatorBreakpointBonus(wholeLevel)
end

local function GetEstimatorTimeModifier(parTimeFraction)
    if type(parTimeFraction) ~= "number" or parTimeFraction <= 0 then
        return nil
    end

    local percentageOffset = 1 - parTimeFraction
    if percentageOffset > 0.4 then
        return 15
    end

    if percentageOffset > 0 then
        return percentageOffset * 37.5
    end

    return 0
end

local function ComputeEstimatorRunScore(mapID, level, parFraction)
    local parTime = C_ChallengeMode and type(C_ChallengeMode.GetMapUIInfo) == "function" and
    select(3, C_ChallengeMode.GetMapUIInfo(mapID)) or nil
    if type(parTime) ~= "number" or parTime <= 0 then
        return nil
    end

    local timeModifier = GetEstimatorTimeModifier(parFraction)
    if timeModifier == nil then
        return {
            baseScore = GetEstimatorDungeonBaseScore(level),
            totalScore = 0,
            modifier = nil,
            parFraction = parFraction,
        }
    end

    local baseScore = GetEstimatorDungeonBaseScore(level)
    return {
        baseScore = baseScore,
        totalScore = max(0, baseScore + timeModifier),
        modifier = timeModifier,
        parFraction = parFraction,
    }
end

local function ComputeEstimatorDungeonScore(score)
    return score or 0
end

local function GetEstimatorCurrentMapState(summary, mapID)
    local runInfo = nil
    if type(summary) == "table" and type(summary.runs) == "table" then
        for _, candidate in ipairs(summary.runs) do
            if type(candidate) == "table" and candidate.challengeModeID == mapID then
                runInfo = candidate
                break
            end
        end
    end

    local mapScore = type(runInfo) == "table" and runInfo.mapScore or nil
    local bestRunLevel = type(runInfo) == "table" and runInfo.bestRunLevel or nil

    if (type(mapScore) ~= "number" or type(bestRunLevel) ~= "number") and C_MythicPlus and type(C_MythicPlus.GetSeasonBestForMap) == "function" then
        local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapID)
        local bestRun = nil
        if type(intimeInfo) == "table" then
            bestRun = intimeInfo
        end
        if type(overtimeInfo) == "table" and (not bestRun or (overtimeInfo.dungeonScore or 0) > (bestRun.dungeonScore or 0)) then
            bestRun = overtimeInfo
        end
        if type(bestRun) == "table" then
            local bestRunMapScore = rawget(bestRun, "mapScore")
            local bestRunDungeonScore = rawget(bestRun, "dungeonScore")
            local resolvedBestRunLevel = rawget(bestRun, "level") or rawget(bestRun, "bestRunLevel")
            mapScore = bestRunMapScore or bestRunDungeonScore or mapScore
            bestRunLevel = resolvedBestRunLevel or bestRunLevel
        end
    end

    return {
        score = type(mapScore) == "number" and mapScore or 0,
        roundedScore = RoundHalfUp(type(mapScore) == "number" and mapScore or 0),
        level = type(bestRunLevel) == "number" and bestRunLevel or 0,
    }
end

local function GetEstimatorMapIDs(summary)
    local seen = {}
    local mapIDs = {}

    if C_ChallengeMode and type(C_ChallengeMode.GetMapTable) == "function" then
        local activeMapIDs = C_ChallengeMode.GetMapTable()
        if type(activeMapIDs) == "table" then
            for _, mapID in ipairs(activeMapIDs) do
                if type(mapID) == "number" and mapID > 0 and not seen[mapID] then
                    seen[mapID] = true
                    tinsert(mapIDs, mapID)
                end
            end
        end
    end

    if type(summary) == "table" and type(summary.runs) == "table" then
        for _, runInfo in ipairs(summary.runs) do
            local mapID = type(runInfo) == "table" and runInfo.challengeModeID or nil
            if type(mapID) == "number" and mapID > 0 and not seen[mapID] then
                seen[mapID] = true
                tinsert(mapIDs, mapID)
            end
        end
    end

    sort(mapIDs, function(left, right)
        return GetMapName(left) < GetMapName(right)
    end)

    return mapIDs
end

local function BuildEstimatorState(summary)
    local state = {}

    for _, mapID in ipairs(GetEstimatorMapIDs(summary)) do
        local runState = GetEstimatorCurrentMapState(summary, mapID)
        state[mapID] = {
            mapID = mapID,
            name = GetMapName(mapID),
            bestRun = runState,
            totalScore = ComputeEstimatorDungeonScore(runState.score),
        }
    end

    return state
end

local function GetEstimatorCandidateWeight(candidate, modeKey)
    if modeKey == "quickest" then
        return (candidate.delta * 1000) - (candidate.level * 8) - candidate.outcome.difficulty
    end

    if modeKey == "balanced" then
        return (candidate.delta * 240) - (candidate.level * 30) - (candidate.outcome.difficulty * 14)
    end

    if modeKey == "easiest" then
        return (candidate.delta * 25) - (candidate.level * 240) - (candidate.outcome.difficulty * 100)
    end

    return (candidate.delta * 20) - (candidate.level * 320) - (candidate.outcome.difficulty * 70)
end

local function BuildEstimatorCandidates(state, maxKeyLevel, outcomeCapIndex, modeIndex)
    local mode = GetEstimatorMode(modeIndex)
    local candidates = {}
    local allowedOutcomes = GetEstimatorAllowedOutcomes(outcomeCapIndex)

    for mapID, mapState in pairs(state) do
        for level = 2, maxKeyLevel do
            for _, outcome in ipairs(allowedOutcomes) do
                local projectedRun = ComputeEstimatorRunScore(mapID, level, outcome.parFraction)
                local newDungeonScore = projectedRun and projectedRun.totalScore or 0
                if newDungeonScore > ((mapState.totalScore or 0) + 0.05) then
                    local delta = newDungeonScore - (mapState.totalScore or 0)
                    if delta > 0.05 then
                        local candidate = {
                            mapID = mapID,
                            mapName = mapState.name,
                            currentDungeonScore = mapState.totalScore or 0,
                            level = level,
                            outcome = outcome,
                            newDungeonScore = newDungeonScore,
                            delta = delta,
                        }
                        candidate.weight = GetEstimatorCandidateWeight(candidate, mode.key)
                        tinsert(candidates, candidate)
                    end
                end
            end
        end
    end

    sort(candidates, function(left, right)
        if left.weight ~= right.weight then
            return left.weight > right.weight
        end

        if left.level ~= right.level then
            return left.level < right.level
        end

        if left.outcome.difficulty ~= right.outcome.difficulty then
            return left.outcome.difficulty < right.outcome.difficulty
        end

        if left.delta ~= right.delta then
            return left.delta > right.delta
        end

        if left.mapName ~= right.mapName then
            return left.mapName < right.mapName
        end

        return left.outcome.difficulty < right.outcome.difficulty
    end)

    return candidates
end

local function ApplyEstimatorCandidate(state, candidate)
    local mapState = state[candidate.mapID]
    if not mapState or not mapState.bestRun then
        return
    end

    mapState.bestRun.score = candidate.newDungeonScore
    mapState.bestRun.roundedScore = RoundHalfUp(candidate.newDungeonScore)
    mapState.bestRun.level = candidate.level
    mapState.totalScore = candidate.newDungeonScore
end

local function BuildEstimatorPlan(currentScore, targetScore, maxKeyLevel, outcomeCapIndex, modeIndex, summary)
    local plan = {
        currentScore = currentScore,
        targetScore = targetScore,
        mode = GetEstimatorMode(modeIndex),
        cap = GetEstimatorOutcomeCap(outcomeCapIndex),
        maxKeyLevel = maxKeyLevel,
        steps = {},
        projectedScore = currentScore,
        reachable = targetScore <= currentScore,
    }

    if targetScore <= currentScore then
        return plan
    end

    local state = BuildEstimatorState(summary)
    local stepLimit = 24

    for _ = 1, stepLimit do
        local candidates = BuildEstimatorCandidates(state, maxKeyLevel, outcomeCapIndex, modeIndex)
        local candidate = candidates[1]
        if not candidate then
            break
        end

        ApplyEstimatorCandidate(state, candidate)
        plan.projectedScore = plan.projectedScore + candidate.delta
        candidate.projectedScore = plan.projectedScore
        tinsert(plan.steps, candidate)

        if plan.projectedScore >= (targetScore - 0.05) then
            plan.reachable = true
            break
        end
    end

    plan.totalGain = plan.projectedScore - currentScore
    plan.remaining = max(0, targetScore - plan.projectedScore)
    if not plan.reachable then
        plan.reason = #plan.steps == 0 and "No upgrades fit the current key and timer caps." or
            "The current caps run out of score before the target is reached."
    end

    return plan
end

local function ApplyEstimatorBackdrop(frame, bgColor, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
end

local function CreateEstimatorCard(parent, bgColor, borderColor)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ApplyEstimatorBackdrop(card, bgColor, borderColor)

    card.Accent = card:CreateTexture(nil, "ARTWORK")
    card.Accent:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    card.Accent:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
    card.Accent:SetWidth(3)
    card.Accent:SetColorTexture(borderColor[1], borderColor[2], borderColor[3], 1)

    return card
end

local function CreateEstimatorFrame(owner)
    local frame = CreateFrame("Frame", "TwichUIMythicPlusEstimatorFrame", UIParent, "BackdropTemplate")
    frame:SetSize(1040, 700)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    ApplyEstimatorBackdrop(frame, { 0.035, 0.05, 0.08, 0.97 }, { 0.18, 0.24, 0.32, 1 })
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.Header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -14)
    frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -14)
    frame.Header:SetHeight(92)
    ApplyEstimatorBackdrop(frame.Header, { 0.06, 0.09, 0.13, 0.96 }, { 0.16, 0.22, 0.32, 1 })

    frame.HeaderGlow = frame.Header:CreateTexture(nil, "BACKGROUND")
    frame.HeaderGlow:SetPoint("TOPLEFT", frame.Header, "TOPLEFT", 1, -1)
    frame.HeaderGlow:SetPoint("TOPRIGHT", frame.Header, "TOPRIGHT", -1, -1)
    frame.HeaderGlow:SetHeight(28)
    frame.HeaderGlow:SetColorTexture(0.18, 0.52, 0.74, 0.18)

    frame.Title = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.Title:SetPoint("TOPLEFT", frame.Header, "TOPLEFT", 18, -14)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("Mythic+ Score Estimator")
    frame.Title:SetTextColor(0.96, 0.98, 1)

    frame.Subtitle = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.Subtitle:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -6)
    frame.Subtitle:SetJustifyH("LEFT")
    frame.Subtitle:SetText("Plan a target score using Blizzard score math, route heuristics, and realistic key caps.")
    frame.Subtitle:SetTextColor(0.65, 0.78, 0.92)

    frame.Close = CreateFrame("Button", nil, frame.Header, "UIPanelCloseButton")
    frame.Close:SetPoint("TOPRIGHT", frame.Header, "TOPRIGHT", 4, 4)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinCloseButton then
        T.Tools.UI.SkinCloseButton(frame.Close)
    end
    frame.Close:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.HeaderMeta = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.HeaderMeta:SetPoint("BOTTOMLEFT", frame.Header, "BOTTOMLEFT", 18, 16)
    frame.HeaderMeta:SetJustifyH("LEFT")
    frame.HeaderMeta:SetTextColor(0.78, 0.85, 0.92)

    frame.CurrentCard = CreateEstimatorCard(frame, { 0.06, 0.10, 0.14, 0.95 }, { 0.18, 0.56, 0.82, 1 })
    frame.CurrentCard:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 0, -14)
    frame.CurrentCard:SetSize(246, 78)
    frame.CurrentCard.Label = frame.CurrentCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.CurrentCard.Label:SetPoint("TOPLEFT", frame.CurrentCard, "TOPLEFT", 16, -12)
    frame.CurrentCard.Label:SetText("Current Score")
    frame.CurrentCard.Label:SetTextColor(0.62, 0.79, 0.92)
    frame.CurrentCard.Value = frame.CurrentCard:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.CurrentCard.Value:SetPoint("BOTTOMLEFT", frame.CurrentCard, "BOTTOMLEFT", 16, 14)
    frame.CurrentCard.Value:SetTextColor(0.95, 0.98, 1)

    frame.NeededCard = CreateEstimatorCard(frame, { 0.085, 0.09, 0.14, 0.95 }, { 0.84, 0.66, 0.22, 1 })
    frame.NeededCard:SetPoint("LEFT", frame.CurrentCard, "RIGHT", 12, 0)
    frame.NeededCard:SetSize(246, 78)
    frame.NeededCard.Label = frame.NeededCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.NeededCard.Label:SetPoint("TOPLEFT", frame.NeededCard, "TOPLEFT", 16, -12)
    frame.NeededCard.Label:SetText("Needed Gain")
    frame.NeededCard.Label:SetTextColor(0.92, 0.82, 0.56)
    frame.NeededCard.Value = frame.NeededCard:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.NeededCard.Value:SetPoint("BOTTOMLEFT", frame.NeededCard, "BOTTOMLEFT", 16, 14)
    frame.NeededCard.Value:SetTextColor(1, 0.94, 0.86)

    frame.PlanCard = CreateEstimatorCard(frame, { 0.06, 0.09, 0.12, 0.95 }, { 0.44, 0.70, 0.40, 1 })
    frame.PlanCard:SetPoint("LEFT", frame.NeededCard, "RIGHT", 12, 0)
    frame.PlanCard:SetSize(246, 78)
    frame.PlanCard.Label = frame.PlanCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.PlanCard.Label:SetPoint("TOPLEFT", frame.PlanCard, "TOPLEFT", 16, -12)
    frame.PlanCard.Label:SetText("Estimated Runs")
    frame.PlanCard.Label:SetTextColor(0.72, 0.90, 0.68)
    frame.PlanCard.Value = frame.PlanCard:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    frame.PlanCard.Value:SetPoint("BOTTOMLEFT", frame.PlanCard, "BOTTOMLEFT", 16, 14)
    frame.PlanCard.Value:SetTextColor(0.93, 1, 0.91)

    frame.CapCard = CreateEstimatorCard(frame, { 0.07, 0.08, 0.12, 0.95 }, { 0.62, 0.46, 0.86, 1 })
    frame.CapCard:SetPoint("LEFT", frame.PlanCard, "RIGHT", 12, 0)
    frame.CapCard:SetSize(246, 78)
    frame.CapCard.Label = frame.CapCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.CapCard.Label:SetPoint("TOPLEFT", frame.CapCard, "TOPLEFT", 16, -12)
    frame.CapCard.Label:SetText("Route Cap")
    frame.CapCard.Label:SetTextColor(0.85, 0.74, 0.96)
    frame.CapCard.Value = frame.CapCard:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.CapCard.Value:SetPoint("BOTTOMLEFT", frame.CapCard, "BOTTOMLEFT", 16, 18)
    frame.CapCard.Value:SetTextColor(0.97, 0.94, 1)

    frame.ControlPanel = CreateEstimatorCard(frame, { 0.05, 0.07, 0.10, 0.96 }, { 0.14, 0.18, 0.24, 1 })
    frame.ControlPanel:SetPoint("TOPLEFT", frame.CurrentCard, "BOTTOMLEFT", 0, -14)
    frame.ControlPanel:SetPoint("TOPRIGHT", frame.CapCard, "BOTTOMRIGHT", 0, -14)
    frame.ControlPanel:SetHeight(86)

    frame.TargetLabel = frame.ControlPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.TargetLabel:SetPoint("TOPLEFT", frame.ControlPanel, "TOPLEFT", 16, -12)
    frame.TargetLabel:SetText("Target Score")
    frame.TargetLabel:SetTextColor(0.78, 0.84, 0.92)

    frame.TargetInput = CreateFrame("EditBox", nil, frame.ControlPanel, "InputBoxTemplate")
    frame.TargetInput:SetAutoFocus(false)
    frame.TargetInput:SetSize(110, 28)
    frame.TargetInput:SetPoint("TOPLEFT", frame.TargetLabel, "BOTTOMLEFT", -2, -10)
    frame.TargetInput:SetNumeric(true)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinEditBox then
        T.Tools.UI.SkinEditBox(frame.TargetInput)
    end

    frame.MaxKeyLabel = frame.ControlPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.MaxKeyLabel:SetPoint("TOPLEFT", frame.TargetLabel, "TOPRIGHT", 34, 0)
    frame.MaxKeyLabel:SetText("Max Key")
    frame.MaxKeyLabel:SetTextColor(0.78, 0.84, 0.92)

    frame.MaxKeyInput = CreateFrame("EditBox", nil, frame.ControlPanel, "InputBoxTemplate")
    frame.MaxKeyInput:SetAutoFocus(false)
    frame.MaxKeyInput:SetSize(80, 28)
    frame.MaxKeyInput:SetPoint("TOPLEFT", frame.MaxKeyLabel, "BOTTOMLEFT", -2, -10)
    frame.MaxKeyInput:SetNumeric(true)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinEditBox then
        T.Tools.UI.SkinEditBox(frame.MaxKeyInput)
    end

    frame.RouteModeButton = CreateFrame("Button", nil, frame.ControlPanel, "UIPanelButtonTemplate")
    frame.RouteModeButton:SetSize(188, 28)
    frame.RouteModeButton:SetPoint("TOPLEFT", frame.MaxKeyInput, "TOPRIGHT", 34, 0)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(frame.RouteModeButton, { 0.18, 0.58, 0.84 })
    elseif T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(frame.RouteModeButton)
    end

    frame.RouteModeLabel = frame.ControlPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.RouteModeLabel:SetPoint("BOTTOMLEFT", frame.RouteModeButton, "TOPLEFT", 0, 8)
    frame.RouteModeLabel:SetText("Planner Mode")
    frame.RouteModeLabel:SetTextColor(0.78, 0.84, 0.92)

    frame.OutcomeCapButton = CreateFrame("Button", nil, frame.ControlPanel, "UIPanelButtonTemplate")
    frame.OutcomeCapButton:SetSize(170, 28)
    frame.OutcomeCapButton:SetPoint("LEFT", frame.RouteModeButton, "RIGHT", 12, 0)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(frame.OutcomeCapButton, { 0.52, 0.42, 0.84 })
    elseif T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(frame.OutcomeCapButton)
    end

    frame.OutcomeCapLabel = frame.ControlPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.OutcomeCapLabel:SetPoint("BOTTOMLEFT", frame.OutcomeCapButton, "TOPLEFT", 0, 8)
    frame.OutcomeCapLabel:SetText("Best Allowed Result")
    frame.OutcomeCapLabel:SetTextColor(0.78, 0.84, 0.92)

    frame.RecalculateButton = CreateFrame("Button", nil, frame.ControlPanel, "UIPanelButtonTemplate")
    frame.RecalculateButton:SetSize(136, 28)
    frame.RecalculateButton:SetPoint("LEFT", frame.OutcomeCapButton, "RIGHT", 12, 0)
    frame.RecalculateButton:SetText("Build Route")
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(frame.RecalculateButton, { 0.90, 0.68, 0.22 })
    elseif T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(frame.RecalculateButton)
    end

    frame.RoutePanel = CreateEstimatorCard(frame, { 0.045, 0.06, 0.09, 0.98 }, { 0.14, 0.18, 0.24, 1 })
    frame.RoutePanel:SetPoint("TOPLEFT", frame.ControlPanel, "BOTTOMLEFT", 0, -14)
    frame.RoutePanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -300, 14)

    frame.RoutePanelTitle = frame.RoutePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.RoutePanelTitle:SetPoint("TOPLEFT", frame.RoutePanel, "TOPLEFT", 16, -14)
    frame.RoutePanelTitle:SetText("Recommended Route")
    frame.RoutePanelTitle:SetTextColor(0.95, 0.98, 1)

    frame.RoutePanelHint = frame.RoutePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.RoutePanelHint:SetPoint("TOPRIGHT", frame.RoutePanel, "TOPRIGHT", -16, -16)
    frame.RoutePanelHint:SetJustifyH("RIGHT")
    frame.RoutePanelHint:SetTextColor(0.60, 0.74, 0.88)

    frame.RouteScrollFrame = CreateFrame("ScrollFrame", "TwichUIMythicPlusEstimatorRouteScrollFrame", frame.RoutePanel,
        "UIPanelScrollFrameTemplate")
    frame.RouteScrollFrame:SetPoint("TOPLEFT", frame.RoutePanelTitle, "BOTTOMLEFT", -2, -14)
    frame.RouteScrollFrame:SetPoint("BOTTOMRIGHT", frame.RoutePanel, "BOTTOMRIGHT", -28, 14)
    local routeScrollBar = frame.RouteScrollFrame.ScrollBar or
    rawget(_G, "TwichUIMythicPlusEstimatorRouteScrollFrameScrollBar")
    if routeScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(routeScrollBar)
    elseif routeScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinScrollBar then
        T.Tools.UI.SkinScrollBar(routeScrollBar)
    end

    frame.RouteContainer = CreateFrame("Frame", nil, frame.RouteScrollFrame)
    frame.RouteContainer:SetSize(1, 1)
    frame.RouteScrollFrame:SetScrollChild(frame.RouteContainer)
    frame.RouteCards = {}

    frame.EmptyState = frame.RouteContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.EmptyState:SetPoint("TOPLEFT", frame.RouteContainer, "TOPLEFT", 12, -18)
    frame.EmptyState:SetWidth(640)
    frame.EmptyState:SetJustifyH("LEFT")
    frame.EmptyState:SetJustifyV("TOP")
    frame.EmptyState:SetTextColor(0.56, 0.68, 0.80)
    frame.EmptyState:SetText("Enter a target score and build a route.")

    frame.SidePanel = CreateEstimatorCard(frame, { 0.055, 0.07, 0.10, 0.98 }, { 0.14, 0.18, 0.24, 1 })
    frame.SidePanel:SetPoint("TOPLEFT", frame.RoutePanel, "TOPRIGHT", 14, 0)
    frame.SidePanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)

    frame.SideTitle = frame.SidePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.SideTitle:SetPoint("TOPLEFT", frame.SidePanel, "TOPLEFT", 16, -14)
    frame.SideTitle:SetText("Plan Notes")
    frame.SideTitle:SetTextColor(0.95, 0.98, 1)

    frame.SummaryText = frame.SidePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.SummaryText:SetPoint("TOPLEFT", frame.SideTitle, "BOTTOMLEFT", 0, -14)
    frame.SummaryText:SetPoint("TOPRIGHT", frame.SidePanel, "TOPRIGHT", -16, -48)
    frame.SummaryText:SetJustifyH("LEFT")
    frame.SummaryText:SetJustifyV("TOP")
    frame.SummaryText:SetTextColor(0.76, 0.84, 0.92)

    frame.AssumptionsCard = CreateEstimatorCard(frame.SidePanel, { 0.08, 0.10, 0.14, 0.95 }, { 0.18, 0.24, 0.32, 1 })
    frame.AssumptionsCard:SetPoint("TOPLEFT", frame.SummaryText, "BOTTOMLEFT", 0, -18)
    frame.AssumptionsCard:SetPoint("TOPRIGHT", frame.SidePanel, "TOPRIGHT", -16, 0)
    frame.AssumptionsCard:SetHeight(160)

    frame.AssumptionsTitle = frame.AssumptionsCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.AssumptionsTitle:SetPoint("TOPLEFT", frame.AssumptionsCard, "TOPLEFT", 14, -12)
    frame.AssumptionsTitle:SetText("Assumptions")
    frame.AssumptionsTitle:SetTextColor(0.94, 0.97, 1)

    frame.AssumptionsText = frame.AssumptionsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.AssumptionsText:SetPoint("TOPLEFT", frame.AssumptionsTitle, "BOTTOMLEFT", 0, -10)
    frame.AssumptionsText:SetPoint("BOTTOMRIGHT", frame.AssumptionsCard, "BOTTOMRIGHT", -14, 14)
    frame.AssumptionsText:SetJustifyH("LEFT")
    frame.AssumptionsText:SetJustifyV("TOP")
    frame.AssumptionsText:SetTextColor(0.76, 0.84, 0.92)

    frame.modeIndex = 2
    frame.outcomeCapIndex = 2

    frame.TargetInput:SetScript("OnEnterPressed", function()
        owner:RefreshMythicPlusEstimator()
    end)
    frame.TargetInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    frame.MaxKeyInput:SetScript("OnEnterPressed", function()
        owner:RefreshMythicPlusEstimator()
    end)
    frame.MaxKeyInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    frame.RouteModeButton:SetScript("OnClick", function()
        frame.modeIndex = frame.modeIndex + 1
        if frame.modeIndex > #ESTIMATOR_ROUTE_MODES then
            frame.modeIndex = 1
        end
        owner:RefreshMythicPlusEstimator()
    end)
    frame.OutcomeCapButton:SetScript("OnClick", function()
        frame.outcomeCapIndex = frame.outcomeCapIndex + 1
        if frame.outcomeCapIndex > #ESTIMATOR_OUTCOME_CAPS then
            frame.outcomeCapIndex = 1
        end
        owner:RefreshMythicPlusEstimator()
    end)
    frame.RecalculateButton:SetScript("OnClick", function()
        owner:RefreshMythicPlusEstimator()
    end)
    frame:SetScript("OnShow", function()
        owner:RefreshMythicPlusEstimator(true)
    end)

    owner.EstimatorFrame = frame
    return frame
end

local function EnsureEstimatorRouteCard(frame, index)
    if frame.RouteCards[index] then
        return frame.RouteCards[index]
    end

    local card = CreateEstimatorCard(frame.RouteContainer, { 0.065, 0.09, 0.12, 0.97 }, { 0.16, 0.22, 0.30, 1 })
    card:SetSize(686, 76)

    card.Step = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.Step:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -12)
    card.Step:SetTextColor(0.96, 0.98, 1)

    card.Dungeon = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.Dungeon:SetPoint("TOPLEFT", card.Step, "TOPRIGHT", 16, 0)
    card.Dungeon:SetJustifyH("LEFT")
    card.Dungeon:SetTextColor(0.96, 0.98, 1)

    card.Details = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.Details:SetPoint("BOTTOMLEFT", card.Dungeon, "BOTTOMLEFT", 0, -18)
    card.Details:SetJustifyH("LEFT")
    card.Details:SetTextColor(0.66, 0.78, 0.90)

    card.Key = card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    card.Key:SetPoint("TOPRIGHT", card, "TOPRIGHT", -16, -12)
    card.Key:SetJustifyH("RIGHT")

    card.Projected = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.Projected:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -16, 14)
    card.Projected:SetJustifyH("RIGHT")
    card.Projected:SetTextColor(0.78, 0.86, 0.92)

    card.Gain = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.Gain:SetPoint("TOPRIGHT", card.Key, "BOTTOMRIGHT", 0, -6)
    card.Gain:SetJustifyH("RIGHT")
    card.Gain:SetTextColor(0.94, 0.84, 0.54)

    frame.RouteCards[index] = card
    return card
end

local function UpdateEstimatorRouteCards(frame, plan)
    local topCard = nil

    for index, step in ipairs(plan.steps or {}) do
        local card = EnsureEstimatorRouteCard(frame, index)
        if topCard then
            card:SetPoint("TOPLEFT", topCard, "BOTTOMLEFT", 0, -10)
        else
            card:SetPoint("TOPLEFT", frame.RouteContainer, "TOPLEFT", 10, -10)
        end
        card:Show()

        local red, green, blue = GetOutcomeVisuals(step.outcome.key)
        card.Accent:SetColorTexture(red, green, blue, 1)
        card.Step:SetText(format("%d", index))
        card.Dungeon:SetText(step.mapName)
        card.Details:SetText(format("%s  |  Dungeon +%s -> +%s", step.outcome.label,
            FormatEstimatorNumber(step.currentDungeonScore), FormatEstimatorNumber(step.newDungeonScore)))
        card.Key:SetText(format("+%d", step.level))
        card.Key:SetTextColor(red, green, blue)
        card.Gain:SetText(format("Gain %s", FormatEstimatorDelta(step.delta)))
        card.Projected:SetText(format("Projected %s", FormatEstimatorNumber(step.projectedScore)))

        topCard = card
    end

    for index = #(plan.steps or {}) + 1, #frame.RouteCards do
        frame.RouteCards[index]:Hide()
    end

    local height = 24
    if topCard then
        local top = 10
        local visibleCards = #plan.steps
        height = top + (visibleCards * 76) + (max(0, visibleCards - 1) * 10) + 20
    end
    frame.RouteContainer:SetSize(686, height)
end

function MPDT:RefreshMythicPlusEstimator(resetDefaults)
    local frame = self.EstimatorFrame or CreateEstimatorFrame(self)
    if not frame then
        return
    end

    local summary = GetRatingSummary()
    local currentScore = GetOverallScore(summary)
    local defaultTarget = RoundHalfUp(currentScore + 100)
    local existingTarget = ParseEstimatorInteger(NormalizeEstimatorInputText(frame.TargetInput:GetText()), defaultTarget)
    if resetDefaults or existingTarget <= RoundHalfUp(currentScore) then
        frame.TargetInput:SetText(tostring(defaultTarget))
        existingTarget = defaultTarget
    end

    local maxKeyLevel = ClampNumber(ParseEstimatorInteger(NormalizeEstimatorInputText(frame.MaxKeyInput:GetText()), 13),
        2, 20)
    if resetDefaults or NormalizeEstimatorInputText(frame.MaxKeyInput:GetText()) == "" then
        frame.MaxKeyInput:SetText(tostring(maxKeyLevel))
    end

    local mode = GetEstimatorMode(frame.modeIndex)
    local cap = GetEstimatorOutcomeCap(frame.outcomeCapIndex)
    frame.RouteModeButton:SetText(mode.label)
    frame.OutcomeCapButton:SetText(cap.label)

    local plan = BuildEstimatorPlan(currentScore, existingTarget, maxKeyLevel, frame.outcomeCapIndex, frame.modeIndex,
        summary)

    frame.CurrentCard.Value:SetText(FormatEstimatorNumber(currentScore))
    frame.NeededCard.Value:SetText(existingTarget > currentScore and FormatEstimatorDelta(existingTarget - currentScore) or
    "+0")
    frame.PlanCard.Value:SetText(FormatEstimatorNumber(#plan.steps))
    frame.CapCard.Value:SetText(format("+%d, %s", maxKeyLevel, cap.label))
    frame.HeaderMeta:SetText(format("Current %s  •  Target %s  •  Projected %s", FormatEstimatorNumber(currentScore),
        FormatEstimatorNumber(existingTarget), FormatEstimatorNumber(plan.projectedScore)))
    frame.RoutePanelHint:SetText(mode.label)

    local summaryText
    if existingTarget <= currentScore then
        summaryText = "Your target is already met. Raise the target score to generate a route."
    elseif plan.reachable then
        summaryText = format("This route reaches %s with %d recommended upgrades, staying under +%d and %s.",
            FormatEstimatorNumber(existingTarget), #plan.steps, maxKeyLevel, cap.label)
    else
        summaryText = format("Current cap tops out near %s. %s", FormatEstimatorNumber(plan.projectedScore),
            plan.reason or
            "Try a higher key cap or a stronger timer result.")
    end
    frame.SummaryText:SetText(summaryText)

    frame.AssumptionsText:SetText(format(
        "Mode: %s\n%s\n\nScoring: Midnight single-run dungeon score using Mr. Mythical's current breakpoints. Base is 155 at +2, +15 per level, +15 breakpoint bonuses at +5/+7/+10/+12, with up to +15 for faster timers.\nCaps: Up to +%d and %s.\nTarget: %s\nProjected Gain: %s",
        mode.label,
        mode.description,
        maxKeyLevel,
        cap.label,
        FormatEstimatorNumber(existingTarget),
        FormatEstimatorDelta(plan.totalGain or 0)
    ))

    if #plan.steps == 0 then
        frame.EmptyState:SetText(existingTarget <= currentScore and
            "Raise the target score above your current rating to build a route." or
            "No score upgrades fit the current caps. Increase the maximum key level or allow stronger timed results.")
        frame.EmptyState:Show()
    else
        frame.EmptyState:Hide()
    end

    UpdateEstimatorRouteCards(frame, plan)
end

function MPDT:OpenMythicPlusEstimator()
    local frame = self.EstimatorFrame or CreateEstimatorFrame(self)
    if not frame then
        return
    end

    self:RefreshMythicPlusEstimator(true)
    frame:Show()
    frame:Raise()
end

GetMapName = function(mapID)
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

GetRatingSummary = function()
    if C_PlayerInfo and type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) == "function" then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
        if type(summary) == "table" then
            return summary
        end
    end

    return nil
end

GetOverallScore = function(summary)
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

    if self.EstimatorFrame and self.EstimatorFrame:IsShown() then
        self:RefreshMythicPlusEstimator()
    end
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
            text = "Score Estimator",
            notCheckable = true,
            func = function()
                self:OpenMythicPlusEstimator()
            end,
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
