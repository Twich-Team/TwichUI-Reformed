---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class ObjectiveTrackerModule : AceModule, AceEvent-3.0, AceHook-3.0
local ObjectiveTracker = T:NewModule("ObjectiveTracker", "AceEvent-3.0", "AceHook-3.0")

local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local InCombatLockdown = _G.InCombatLockdown
local C_QuestLog = _G.C_QuestLog
local C_SuperTrack = _G.C_SuperTrack
local C_Scenario = _G.C_Scenario
local C_ScenarioInfo = _G.C_ScenarioInfo
local C_Timer = _G.C_Timer
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local ipairs = ipairs
local pairs = pairs
local table_insert = table.insert
local table_sort = table.sort
local string_format = string.format

local HEADER_HEIGHT = 28
local PANEL_PADDING = 12
local ENTRY_GAP = 8
local OBJECTIVE_GAP = 3
local MAX_SCENARIO_CRITERIA = 10

local EVENT_REFRESHES = {
    "PLAYER_ENTERING_WORLD",
    "QUEST_LOG_UPDATE",
    "QUEST_WATCH_UPDATE",
    "QUEST_WATCH_LIST_CHANGED",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_TURNED_IN",
    "SUPER_TRACKING_CHANGED",
    "SCENARIO_UPDATE",
    "SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_POI_UPDATE",
    "ZONE_CHANGED_NEW_AREA",
    "TASK_PROGRESS_UPDATE",
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3, result4, result5 = pcall(func, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3, result4, result5
end

local function GetConfigurationModule()
    return T:GetModule("Configuration")
end

local function GetOptions()
    local configurationModule = GetConfigurationModule()
    return configurationModule and configurationModule.Options and configurationModule.Options.ObjectiveTracker or nil
end

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function GetThemeColor(key, fallback)
    local theme = GetThemeModule()
    local getColor = theme and theme.GetColor or nil
    if theme and type(getColor) == "function" then
        local color = getColor(theme, key)
        if type(color) == "table" then
            return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
        end
    end

    return fallback[1], fallback[2], fallback[3]
end

local function ResolveFontPath()
    local path = STANDARD_TEXT_FONT
    local theme = GetThemeModule()
    local getValue = theme and theme.Get or nil
    local LSM = T.Libs and T.Libs.LSM
    if theme and type(getValue) == "function" and LSM then
        local fontKey = getValue(theme, "globalFont")
        if fontKey and fontKey ~= "" and fontKey ~= "__default" then
            local fetched = SafeCall(LSM.Fetch, LSM, "font", fontKey)
            if type(fetched) == "string" and fetched ~= "" then
                path = fetched
            end
        end
    end

    return path
end

local function Clamp(value, minValue, maxValue)
    local numeric = tonumber(value) or minValue
    if numeric < minValue then
        return minValue
    end
    if numeric > maxValue then
        return maxValue
    end
    return numeric
end

local function ToInteger(value, minValue, maxValue)
    return math_floor(Clamp(value, minValue, maxValue) + 0.5)
end

local function ColorizeText(text, red, green, blue)
    if type(text) ~= "string" or text == "" then
        return ""
    end

    local r = math_floor(Clamp(red or 1, 0, 1) * 255 + 0.5)
    local g = math_floor(Clamp(green or 1, 0, 1) * 255 + 0.5)
    local b = math_floor(Clamp(blue or 1, 0, 1) * 255 + 0.5)
    return string_format("|cff%02x%02x%02x%s|r", r, g, b, text)
end

local function IsQuestObjectiveComplete(objective)
    if type(objective) ~= "table" then
        return false
    end

    return objective.finished == true or objective.completed == true or objective.isCompleted == true
end

local function GetQuestInfoByID(questID)
    if not questID or type(C_QuestLog) ~= "table" then
        return nil
    end

    local logIndex = SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
    if not logIndex or logIndex <= 0 then
        return nil
    end

    return SafeCall(C_QuestLog.GetInfo, logIndex)
end

local function GetQuestObjectives(questID)
    if not questID or type(C_QuestLog) ~= "table" or type(C_QuestLog.GetQuestObjectives) ~= "function" then
        return nil
    end

    return SafeCall(C_QuestLog.GetQuestObjectives, questID)
end

local function GetSuperTrackedQuestID()
    if type(C_SuperTrack) == "table" and type(C_SuperTrack.GetSuperTrackedQuestID) == "function" then
        return SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
    end
    return nil
end

function ObjectiveTracker:GetOptions()
    return GetOptions()
end

function ObjectiveTracker:GetDB()
    local options = GetOptions()
    return options and options.GetDB and options:GetDB() or nil
end

function ObjectiveTracker:IsModuleEnabled()
    local options = GetOptions()
    return options and options.GetEnabled and options:GetEnabled() or false
end

function ObjectiveTracker:IsBlizzardSuppressed()
    local options = GetOptions()
    return self:IsModuleEnabled() and options and options.GetHideBlizzardTracker and
    options:GetHideBlizzardTracker() == true
end

function ObjectiveTracker:CreateRefreshDriver()
    if self.refreshDriver then
        return self.refreshDriver
    end

    local driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", function(frame)
        frame:Hide()
        ObjectiveTracker.refreshPending = false
        if ObjectiveTracker:IsEnabled() then
            ObjectiveTracker:RefreshNow("dirty-frame")
        end
    end)
    self.refreshDriver = driver
    return driver
end

function ObjectiveTracker:ScheduleRefresh(reason)
    self.lastRefreshReason = reason or self.lastRefreshReason or "unknown"
    if self.refreshPending then
        return
    end

    self.refreshPending = true
    self:CreateRefreshDriver():Show()
end

function ObjectiveTracker:CreateEntryFrame(parent, index)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    frame:SetHeight(24)

    frame.Accent = frame:CreateTexture(nil, "ARTWORK")
    frame.Accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 1)
    frame.Accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -1)
    frame.Accent:SetWidth(2)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
    frame.Title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetJustifyV("TOP")
    frame.Title:SetWordWrap(true)

    frame.Objectives = {}
    frame.index = index
    return frame
end

function ObjectiveTracker:GetEntryFrame(index)
    self.entryPool = self.entryPool or {}
    if self.entryPool[index] then
        return self.entryPool[index]
    end

    local entry = self:CreateEntryFrame(self.frame.Content, index)
    self.entryPool[index] = entry
    return entry
end

function ObjectiveTracker:GetObjectiveFontString(entryFrame, index)
    entryFrame.Objectives = entryFrame.Objectives or {}
    if entryFrame.Objectives[index] then
        return entryFrame.Objectives[index]
    end

    local text = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 18, 0)
    text:SetPoint("TOPRIGHT", entryFrame, "TOPRIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    entryFrame.Objectives[index] = text
    return text
end

function ObjectiveTracker:CreateFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "TwichUIObjectiveTrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(320, 220)
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -100, -220)
    frame:SetClampedToScreen(true)
    frame:SetMovable(false)
    frame:EnableMouse(true)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(40)

    frame.Header = CreateFrame("Button", nil, frame)
    frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.Header:SetHeight(HEADER_HEIGHT)

    frame.HeaderAccent = frame:CreateTexture(nil, "BORDER")
    frame.HeaderAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.HeaderAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.HeaderAccent:SetHeight(2)

    frame.Title = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("LEFT", frame.Header, "LEFT", PANEL_PADDING, 0)
    frame.Title:SetPoint("RIGHT", frame.Header, "RIGHT", -40, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("Objectives")

    frame.Count = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Count:SetPoint("RIGHT", frame.Header, "RIGHT", -28, 0)
    frame.Count:SetJustifyH("RIGHT")

    frame.CollapseButton = CreateFrame("Button", nil, frame.Header)
    frame.CollapseButton:SetSize(20, 20)
    frame.CollapseButton:SetPoint("RIGHT", frame.Header, "RIGHT", -8, 0)
    frame.CollapseButton.Text = frame.CollapseButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.CollapseButton.Text:SetAllPoints()
    frame.CollapseButton.Text:SetText("-")

    frame.Content = CreateFrame("Frame", nil, frame)
    frame.Content:SetPoint("TOPLEFT", frame, "TOPLEFT", PANEL_PADDING, -HEADER_HEIGHT - PANEL_PADDING)
    frame.Content:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PANEL_PADDING, -HEADER_HEIGHT - PANEL_PADDING)
    frame.Content:SetHeight(120)

    frame.EmptyText = frame.Content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("TOPLEFT", frame.Content, "TOPLEFT", 0, 0)
    frame.EmptyText:SetPoint("TOPRIGHT", frame.Content, "TOPRIGHT", 0, 0)
    frame.EmptyText:SetJustifyH("LEFT")
    frame.EmptyText:SetWordWrap(true)
    frame.EmptyText:SetText("No tracked objectives right now.")

    frame.OverflowText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.OverflowText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PANEL_PADDING, PANEL_PADDING)
    frame.OverflowText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PANEL_PADDING, PANEL_PADDING)
    frame.OverflowText:SetJustifyH("LEFT")
    frame.OverflowText:SetWordWrap(true)

    frame.Header:SetScript("OnMouseDown", function(_, button)
        if button == "RightButton" then
            ObjectiveTracker:ToggleCollapsed()
        end
    end)
    frame.CollapseButton:SetScript("OnClick", function()
        ObjectiveTracker:ToggleCollapsed()
    end)

    self.frame = frame
    self:ApplyFramePosition()
    self:ApplyTheme()
    self:RegisterWithMovers()
    self:RegisterWithLayoutSystem()
    return frame
end

function ObjectiveTracker:ApplyFramePosition()
    if not self.frame then
        return
    end

    local db = self:GetDB()
    if not db then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", db.anchorX or -100, db.anchorY or -220)
end

function ObjectiveTracker:ApplyTheme()
    local frame = self:CreateFrame()
    local options = GetOptions()
    if not frame or not options then
        return
    end

    local backgroundR, backgroundG, backgroundB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    local textR, textG, textB = GetThemeColor("textColor", { 0.88, 0.90, 0.96 })
    local fontPath = ResolveFontPath()

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(backgroundR, backgroundG, backgroundB, Clamp(options:GetOpacity() * 0.96, 0.10, 1.0))
    frame:SetBackdropBorderColor(borderR, borderG, borderB, 0.9)
    frame.HeaderAccent:SetColorTexture(accentR, accentG, accentB, 0.95)
    frame.Title:SetFont(fontPath, options:GetHeaderFontSize(), "")
    frame.Title:SetTextColor(textR, textG, textB)
    frame.Count:SetFont(fontPath, options:GetBodyFontSize(), "")
    frame.Count:SetTextColor(0.70, 0.76, 0.86)
    frame.CollapseButton.Text:SetFont(fontPath, options:GetHeaderFontSize(), "")
    frame.CollapseButton.Text:SetTextColor(textR, textG, textB)
    frame.EmptyText:SetFont(fontPath, options:GetBodyFontSize(), "")
    frame.EmptyText:SetTextColor(0.66, 0.70, 0.78)
    frame.OverflowText:SetFont(fontPath, options:GetBodyFontSize(), "")
    frame.OverflowText:SetTextColor(0.66, 0.70, 0.78)
    frame:SetScale(options:GetScale())
    frame:SetWidth(options:GetWidth())
    frame:SetAlpha(options:GetHideInCombat() and InCombatLockdown and InCombatLockdown() and 0 or 1)
end

function ObjectiveTracker:BuildQuestObjectiveText(objective)
    if type(objective) ~= "table" then
        return nil, false
    end

    local text = objective.text or objective.description
    if type(text) ~= "string" or text == "" then
        return nil, false
    end

    local complete = IsQuestObjectiveComplete(objective)
    if complete then
        return ColorizeText("• " .. text, 0.42, 0.88, 0.64), true
    end

    return ColorizeText("• " .. text, 0.74, 0.77, 0.84), false
end

function ObjectiveTracker:BuildQuestEntry(questID)
    local info = GetQuestInfoByID(questID)
    if type(info) ~= "table" or info.isHeader == true or info.isHidden == true then
        return nil
    end

    local entry = {
        type = "quest",
        questID = questID,
        title = info.title or ("Quest " .. tostring(questID)),
        isComplete = info.isComplete == true,
        isSuperTracked = GetSuperTrackedQuestID() == questID,
        objectives = {},
    }

    local options = GetOptions()
    if options and options:GetShowQuestObjectives() then
        local objectives = GetQuestObjectives(questID)
        if type(objectives) == "table" then
            for _, objective in ipairs(objectives) do
                local objectiveText, isComplete = self:BuildQuestObjectiveText(objective)
                if objectiveText and objectiveText ~= "" then
                    table_insert(entry.objectives, {
                        text = objectiveText,
                        isComplete = isComplete,
                    })
                end
            end
        end
    end

    return entry
end

function ObjectiveTracker:BuildScenarioEntry()
    local options = GetOptions()
    if not options or not options:GetShowScenario() then
        return nil
    end
    if type(C_Scenario) ~= "table" or type(C_Scenario.GetInfo) ~= "function" then
        return nil
    end

    local scenarioInfo = SafeCall(C_Scenario.GetInfo)
    local stepName, numCriteria = nil, 0

    local scenarioName = nil
    if type(scenarioInfo) == "table" then
        scenarioName = scenarioInfo.name or scenarioInfo.title
    else
        scenarioName = scenarioInfo
    end

    if type(C_Scenario.GetStepInfo) == "function" then
        local value1, _, value3 = SafeCall(C_Scenario.GetStepInfo)
        if type(value1) == "table" then
            stepName = value1.description or value1.title
            numCriteria = tonumber(value1.numCriteria) or 0
        else
            stepName = value1
            numCriteria = tonumber(value3) or 0
        end
    end

    if type(scenarioName) ~= "string" or scenarioName == "" then
        return nil
    end

    local entry = {
        type = "scenario",
        title = type(stepName) == "string" and stepName ~= "" and stepName or scenarioName,
        subtitle = scenarioName,
        objectives = {},
        isScenario = true,
        isSuperTracked = false,
        isComplete = false,
    }

    if type(C_ScenarioInfo) == "table" and type(C_ScenarioInfo.GetCriteriaInfo) == "function" then
        for index = 1, math_max(MAX_SCENARIO_CRITERIA, numCriteria) do
            local info = SafeCall(C_ScenarioInfo.GetCriteriaInfo, index)
            if type(info) == "table" and type(info.description) == "string" and info.description ~= "" then
                local isComplete = info.completed == true
                local text = (isComplete and ColorizeText("• " .. info.description, 0.42, 0.88, 0.64))
                    or ColorizeText("• " .. info.description, 0.74, 0.77, 0.84)
                table_insert(entry.objectives, {
                    text = text,
                    isComplete = isComplete,
                })
            end
        end
    end

    if #entry.objectives == 0 then
        return nil
    end

    return entry
end

function ObjectiveTracker:CollectEntries()
    local entries = {}
    if type(C_QuestLog) == "table" and type(C_QuestLog.GetNumQuestWatches) == "function" and type(C_QuestLog.GetQuestIDForQuestWatchIndex) == "function" then
        local watchCount = SafeCall(C_QuestLog.GetNumQuestWatches) or 0
        for index = 1, watchCount do
            local questID = SafeCall(C_QuestLog.GetQuestIDForQuestWatchIndex, index)
            if questID then
                local entry = self:BuildQuestEntry(questID)
                if entry then
                    table_insert(entries, entry)
                end
            end
        end
    end

    local scenarioEntry = self:BuildScenarioEntry()
    if scenarioEntry then
        table_insert(entries, 1, scenarioEntry)
    end

    table_sort(entries, function(a, b)
        if a.isScenario ~= b.isScenario then
            return a.isScenario == true
        end
        if a.isSuperTracked ~= b.isSuperTracked then
            return a.isSuperTracked == true
        end
        if a.isComplete ~= b.isComplete then
            return a.isComplete == false
        end
        return tostring(a.title or "") < tostring(b.title or "")
    end)

    return entries
end

function ObjectiveTracker:ApplyBlizzardTrackerState()
    local tracker = _G.ObjectiveTrackerFrame
    if not tracker then
        return
    end

    if tracker.__tuiObjectiveTrackerHooked ~= true and type(tracker.HookScript) == "function" then
        tracker.__tuiObjectiveTrackerHooked = true
        tracker:HookScript("OnShow", function(frame)
            if ObjectiveTracker:IsBlizzardSuppressed() then
                frame:SetAlpha(0)
                frame:Hide()
            end
        end)
    end

    if self:IsBlizzardSuppressed() then
        tracker:SetAlpha(0)
        if tracker.EnableMouse then
            tracker:EnableMouse(false)
        end
        tracker:Hide()
    else
        tracker:SetAlpha(1)
        if tracker.EnableMouse then
            tracker:EnableMouse(true)
        end
    end
end

function ObjectiveTracker:LayoutEntry(entryFrame, entry, yOffset)
    local options = GetOptions()
    if not options then
        return yOffset
    end

    local fontPath = ResolveFontPath()
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })

    entryFrame:ClearAllPoints()
    entryFrame:SetPoint("TOPLEFT", self.frame.Content, "TOPLEFT", 0, -yOffset)
    entryFrame:SetPoint("TOPRIGHT", self.frame.Content, "TOPRIGHT", 0, -yOffset)
    entryFrame:Show()

    entryFrame.Accent:SetColorTexture(accentR, accentG, accentB, entry.isSuperTracked and 1 or 0.55)
    entryFrame.Title:SetFont(fontPath, options:GetHeaderFontSize() - 1, "")
    entryFrame.Title:SetText(entry.isComplete and ColorizeText(entry.title, 0.50, 0.86, 0.62) or entry.title)
    entryFrame.Title:SetTextColor(0.92, 0.94, 0.98)
    entryFrame.Title:ClearAllPoints()
    entryFrame.Title:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 10, 0)
    entryFrame.Title:SetPoint("TOPRIGHT", entryFrame, "TOPRIGHT", -4, 0)

    local height = math_max(options:GetHeaderFontSize() + 4, entryFrame.Title:GetStringHeight())
    local objectiveYOffset = height + 2

    for objectiveIndex, objectiveLine in ipairs(entryFrame.Objectives or {}) do
        objectiveLine:Hide()
    end

    if options:GetShowQuestObjectives() and type(entry.objectives) == "table" then
        for objectiveIndex, objective in ipairs(entry.objectives) do
            local textLine = self:GetObjectiveFontString(entryFrame, objectiveIndex)
            textLine:SetFont(fontPath, options:GetBodyFontSize(), "")
            textLine:SetText(objective.text or "")
            textLine:ClearAllPoints()
            textLine:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", 18, -objectiveYOffset)
            textLine:SetPoint("TOPRIGHT", entryFrame, "TOPRIGHT", -4, -objectiveYOffset)
            textLine:SetTextColor(objective.isComplete and 0.42 or 0.74, objective.isComplete and 0.88 or 0.77,
                objective.isComplete and 0.64 or 0.84)
            textLine:Show()
            local lineHeight = math_max(options:GetBodyFontSize(), textLine:GetStringHeight())
            objectiveYOffset = objectiveYOffset + lineHeight + OBJECTIVE_GAP
        end
        height = math_max(height, objectiveYOffset)
    end

    entryFrame:SetHeight(height)
    return yOffset + height + ENTRY_GAP
end

function ObjectiveTracker:RefreshNow(reason)
    if not self:IsModuleEnabled() then
        if self.frame then
            self.frame:Hide()
        end
        self:ApplyBlizzardTrackerState()
        return
    end

    local frame = self:CreateFrame()
    local options = GetOptions()
    if not options then
        return
    end

    self:ApplyTheme()
    self:ApplyFramePosition()
    self:ApplyBlizzardTrackerState()

    if options:GetHideInCombat() and InCombatLockdown and InCombatLockdown() then
        frame:Hide()
        return
    end

    local entries = self:CollectEntries()
    local visibleEntries = {}
    local maxEntries = options:GetMaxEntries()
    for index = 1, math_min(#entries, maxEntries) do
        visibleEntries[index] = entries[index]
    end

    frame:SetWidth(options:GetWidth())
    frame:SetScale(options:GetScale())
    frame.Count:SetText(#entries > 0 and tostring(#entries) or "")
    frame.CollapseButton.Text:SetText(options:GetCollapsed() and "+" or "-")

    for index, entryFrame in pairs(self.entryPool or {}) do
        entryFrame:Hide()
        for _, objectiveLine in ipairs(entryFrame.Objectives or {}) do
            objectiveLine:Hide()
        end
    end

    if #entries == 0 then
        frame.EmptyText:Show()
        frame.EmptyText:SetText(options:GetEmptyText())
        frame.OverflowText:SetText("")
        frame:SetHeight(HEADER_HEIGHT + (PANEL_PADDING * 2) + options:GetBodyFontSize() + 10)
        frame:Show()
        return
    end

    frame.EmptyText:Hide()
    if options:GetCollapsed() then
        frame.OverflowText:SetText("")
        frame:SetHeight(HEADER_HEIGHT + 10)
        frame:Show()
        return
    end

    local yOffset = 0
    for index, entry in ipairs(visibleEntries) do
        local entryFrame = self:GetEntryFrame(index)
        yOffset = self:LayoutEntry(entryFrame, entry, yOffset)
    end

    local overflowCount = #entries - #visibleEntries
    if overflowCount > 0 then
        frame.OverflowText:SetText(string_format("%d more tracked objectives hidden by the entry limit.", overflowCount))
        frame.OverflowText:Show()
        yOffset = yOffset + math_max(options:GetBodyFontSize(), frame.OverflowText:GetStringHeight()) + 4
    else
        frame.OverflowText:SetText("")
        frame.OverflowText:Hide()
    end

    frame:SetHeight(HEADER_HEIGHT + (PANEL_PADDING * 2) + yOffset)
    frame:Show()
end

function ObjectiveTracker:ToggleCollapsed()
    local options = GetOptions()
    if not options then
        return
    end

    options:SetCollapsed(nil, not options:GetCollapsed())
end

function ObjectiveTracker:RegisterWithLayoutSystem()
    if self.layoutRegistered == true or not self.frame then
        return
    end

    local setupWizardModule = T:GetModule("SetupWizard", true)
    if not setupWizardModule or type(setupWizardModule.RegisterLayoutFrame) ~= "function" then
        return
    end

    setupWizardModule:RegisterLayoutFrame("ObjectiveTracker", self.frame, function(absX, absY, absW)
        local options = GetOptions()
        if not options then
            return
        end

        options:SetAnchorFromBottomLeft(absX, absY)
        if absW and absW > 0 then
            options:SetWidth(nil, absW)
        end
    end)

    self.layoutRegistered = true
end

function ObjectiveTracker:RegisterWithMovers()
    if self.moversRegistered == true or not self.frame then
        return
    end

    local moversModule = T:GetModule("Movers", true)
    if not moversModule or type(moversModule.RegisterMover) ~= "function" then
        return
    end

    moversModule:RegisterMover("ObjectiveTracker", {
        label = "Objective Tracker",
        category = "World & Gameplay",
        headerToggle = {
            label = "Enabled",
            get = function()
                local options = GetOptions()
                return options and options:GetEnabled() or false
            end,
            set = function(value)
                local options = GetOptions()
                if options and type(options.SetEnabled) == "function" then
                    options:SetEnabled(nil, value)
                end
            end,
        },
        getFrame = function() return ObjectiveTracker.frame end,
        getX = function()
            return ObjectiveTracker.frame and math_floor((ObjectiveTracker.frame:GetLeft() or 0) + 0.5) or 0
        end,
        getY = function()
            return ObjectiveTracker.frame and math_floor((ObjectiveTracker.frame:GetBottom() or 0) + 0.5) or 0
        end,
        getW = function()
            return ObjectiveTracker.frame and ObjectiveTracker.frame:GetWidth() or 320
        end,
        getH = function()
            return ObjectiveTracker.frame and ObjectiveTracker.frame:GetHeight() or 220
        end,
        setPos = function(x, y)
            local options = GetOptions()
            if options then
                options:SetAnchorFromBottomLeft(x, y)
            end
        end,
        setSize = function(width)
            local options = GetOptions()
            if options then
                options:SetWidth(nil, width)
            end
        end,
        isEnabled = function()
            local options = GetOptions()
            return options and options:GetEnabled() or false
        end,
        extras = {
            {
                label = "Collapsed",
                type = "toggle",
                get = function()
                    local options = GetOptions()
                    return options and options:GetCollapsed() or false
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetCollapsed(nil, value)
                    end
                end,
            },
            {
                label = "Show Objectives",
                type = "toggle",
                get = function()
                    local options = GetOptions()
                    return options and options:GetShowQuestObjectives() or true
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetShowQuestObjectives(nil, value)
                    end
                end,
            },
            {
                label = "Show Scenario",
                type = "toggle",
                get = function()
                    local options = GetOptions()
                    return options and options:GetShowScenario() or true
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetShowScenario(nil, value)
                    end
                end,
            },
            {
                label = "Scale",
                type = "range",
                min = 0.8,
                max = 1.5,
                step = 0.01,
                get = function()
                    local options = GetOptions()
                    return options and options:GetScale() or 1
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetScale(nil, value)
                    end
                end,
            },
            {
                label = "Width",
                type = "range",
                min = 220,
                max = 520,
                step = 2,
                get = function()
                    local options = GetOptions()
                    return options and options:GetWidth() or 320
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetWidth(nil, value)
                    end
                end,
            },
            {
                label = "Entry Limit",
                type = "range",
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    local options = GetOptions()
                    return options and options:GetMaxEntries() or 8
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetMaxEntries(nil, value)
                    end
                end,
            },
        },
    })

    self.moversRegistered = true
end

function ObjectiveTracker:OnRefreshEvent(event)
    self:ScheduleRefresh(event)
end

function ObjectiveTracker:OnEnable()
    if not self:IsModuleEnabled() then
        return
    end

    self:CreateFrame()
    for _, eventName in ipairs(EVENT_REFRESHES) do
        self:RegisterEvent(eventName, "OnRefreshEvent")
    end
    self:RefreshNow("enable")
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if ObjectiveTracker:IsEnabled() then
                ObjectiveTracker:RegisterWithMovers()
                ObjectiveTracker:RegisterWithLayoutSystem()
            end
        end)
    end
end

function ObjectiveTracker:OnDisable()
    self:UnregisterAllEvents()
    if self.frame then
        self.frame:Hide()
    end
    self:ApplyBlizzardTrackerState()
end
