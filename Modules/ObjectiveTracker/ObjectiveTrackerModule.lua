---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class ObjectiveTrackerModule : AceModule, AceEvent-3.0, AceHook-3.0
local ObjectiveTracker = T:NewModule("ObjectiveTracker", "AceEvent-3.0", "AceHook-3.0")

local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local CreateFrame = _G.CreateFrame
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local InCombatLockdown = _G.InCombatLockdown
local IsInInstance = _G.IsInInstance
local GetInstanceInfo = _G.GetInstanceInfo
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local C_QuestLog = _G.C_QuestLog
local C_SuperTrack = _G.C_SuperTrack
local C_Scenario = _G.C_Scenario
local C_ScenarioInfo = _G.C_ScenarioInfo
local C_Timer = _G.C_Timer
local C_Map = _G.C_Map
local C_TaskQuest = _G.C_TaskQuest
local Enum = _G.Enum
local GetQuestUiMapID = _G.GetQuestUiMapID
local QuestMapFrame_OpenToQuestDetails = _G.QuestMapFrame_OpenToQuestDetails
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local ipairs = ipairs
local next = next
local pairs = pairs
local table_insert = table.insert
local table_sort = table.sort
local string_format = string.format
local tostring = tostring
local type = type

local HEADER_HEIGHT = 30
local SECTION_HEADER_HEIGHT = 22
local PANEL_PADDING = 12
local SECTION_GAP = 8
local ENTRY_GAP = 6
local OBJECTIVE_GAP = 2
local ROW_PADDING = 8
local MAX_SCENARIO_CRITERIA = 10
local ALPHA_LERP_SPEED = 12

local SECTION_ORDER = {
    "scenario",
    "currentZone",
    "world",
    "quests",
    "completed",
}

local SECTION_TITLES = {
    scenario = "Scenario",
    currentZone = "Current Zone",
    world = "World Quests",
    quests = "Tracked Quests",
    completed = "Completed",
}

local SECTION_COLOR_KEYS = {
    scenario = "sectionScenarioColor",
    currentZone = "sectionCurrentZoneColor",
    world = "sectionWorldColor",
    quests = "sectionQuestColor",
    completed = "sectionCompletedColor",
}

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
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "TASK_PROGRESS_UPDATE",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_DIFFICULTY_CHANGED",
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3, result4, result5, result6 = pcall(func, ...)
    if not ok then
        return nil
    end

    return result1, result2, result3, result4, result5, result6
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

local function ResolveColor(options, key, fallback, themeKey)
    if options and type(options.GetColor) == "function" then
        local red, green, blue = options:GetColor(key)
        return red or fallback[1], green or fallback[2], blue or fallback[3]
    end

    if themeKey then
        return GetThemeColor(themeKey, fallback)
    end

    return fallback[1], fallback[2], fallback[3]
end

local function ResolveFontPath(fontKey)
    local LSM = T.Libs and T.Libs.LSM
    local theme = GetThemeModule()
    if type(fontKey) ~= "string" or fontKey == "" or fontKey == "__default" then
        local themeFont = theme and theme.Get and theme:Get("globalFont") or nil
        fontKey = themeFont
    end

    if LSM and type(fontKey) == "string" and fontKey ~= "" and fontKey ~= "__default" then
        local fetched = SafeCall(LSM.Fetch, LSM, "font", fontKey)
        if type(fetched) == "string" and fetched ~= "" then
            return fetched
        end
    end

    return STANDARD_TEXT_FONT
end

local function GetQuestInfoByID(questID)
    if type(questID) ~= "number" or type(C_QuestLog) ~= "table" then
        if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestInfoByQuestID) == "function" then
            local taskTitle = SafeCall(C_TaskQuest.GetQuestInfoByQuestID, questID)
            if type(taskTitle) == "string" and taskTitle ~= "" then
                return {
                    title = taskTitle,
                    isHeader = false,
                    isHidden = false,
                    isComplete = false,
                }
            end
        end
        return nil
    end

    local logIndex = SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
    if not logIndex or logIndex <= 0 then
        if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestInfoByQuestID) == "function" then
            local taskTitle = SafeCall(C_TaskQuest.GetQuestInfoByQuestID, questID)
            if type(taskTitle) == "string" and taskTitle ~= "" then
                return {
                    title = taskTitle,
                    isHeader = false,
                    isHidden = false,
                    isComplete = false,
                }
            end
        end
        return nil
    end

    return SafeCall(C_QuestLog.GetInfo, logIndex)
end

local function GetQuestObjectives(questID)
    if type(questID) ~= "number" or type(C_QuestLog) ~= "table" or type(C_QuestLog.GetQuestObjectives) ~= "function" then
        return nil
    end

    return SafeCall(C_QuestLog.GetQuestObjectives, questID)
end

local function GetCurrentMapID()
    if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
        return SafeCall(C_Map.GetBestMapForUnit, "player")
    end

    return nil
end

local function GetMapInfoSafe(mapID)
    if type(mapID) ~= "number" or type(C_Map) ~= "table" or type(C_Map.GetMapInfo) ~= "function" then
        return nil
    end

    return SafeCall(C_Map.GetMapInfo, mapID)
end

local function BuildZoneLineage(mapID)
    local lineage = {}
    local seen = {}
    local zoneTypeThreshold = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3

    while type(mapID) == "number" and mapID > 0 and not seen[mapID] do
        seen[mapID] = true
        local info = GetMapInfoSafe(mapID)
        if type(info) ~= "table" then
            break
        end

        local mapType = tonumber(info.mapType)
        if mapType and mapType < zoneTypeThreshold then
            break
        end

        lineage[mapID] = true
        mapID = tonumber(info.parentMapID)
    end

    return lineage
end

local function IsCurrentZoneMap(mapID, currentMapID)
    if type(mapID) ~= "number" or type(currentMapID) ~= "number" or mapID <= 0 or currentMapID <= 0 then
        return false
    end

    if mapID == currentMapID then
        return true
    end

    local currentLineage = BuildZoneLineage(currentMapID)
    local questLineage = BuildZoneLineage(mapID)
    for lineageMapID in pairs(questLineage) do
        if currentLineage[lineageMapID] then
            return true
        end
    end

    return false
end

local function GetQuestMapID(questID)
    if type(questID) ~= "number" then
        return nil
    end

    if type(GetQuestUiMapID) == "function" then
        local mapID = SafeCall(GetQuestUiMapID, questID, true)
        if type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestZoneID) == "function" then
        local mapID = SafeCall(C_TaskQuest.GetQuestZoneID, questID)
        if type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end

    return nil
end

local function GetQuestLocation(questID, mapID)
    if type(questID) ~= "number" or type(mapID) ~= "number" then
        return nil, nil
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestLocation) == "function" then
        local x, y = SafeCall(C_TaskQuest.GetQuestLocation, questID, mapID)
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    return nil, nil
end

local function GetQuestZoneName(questID, mapID)
    mapID = mapID or GetQuestMapID(questID)
    local info = GetMapInfoSafe(mapID)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        return info.name
    end

    return nil
end

local function GetQuestTitle(questID)
    if type(C_QuestLog) == "table" and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local title = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestInfoByQuestID) == "function" then
        local title = SafeCall(C_TaskQuest.GetQuestInfoByQuestID, questID)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end

    return "Quest " .. tostring(questID)
end

local function IsWorldQuest(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.IsWorldQuest) == "function"
        and SafeCall(C_QuestLog.IsWorldQuest, questID) == true
end

local function IsQuestComplete(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.IsComplete) == "function"
        and SafeCall(C_QuestLog.IsComplete, questID) == true
end

local function GetQuestTimeLeftSeconds(questID)
    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestTimeLeftSeconds) == "function" then
        local seconds = SafeCall(C_TaskQuest.GetQuestTimeLeftSeconds, questID)
        if type(seconds) == "number" and seconds > 0 then
            return seconds
        end
    end

    return nil
end

local function GetQuestTagName(questID)
    if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestTagInfo) == "function" then
        local tagInfo = SafeCall(C_QuestLog.GetQuestTagInfo, questID)
        if type(tagInfo) == "table" then
            if type(tagInfo.tagName) == "string" and tagInfo.tagName ~= "" then
                return tagInfo.tagName
            end
            if type(tagInfo.worldQuestType) == "number" and IsWorldQuest(questID) then
                return "World Quest"
            end
        end
    end

    return nil
end

local function AppendQuestIDs(target, seen, questList)
    if type(target) ~= "table" or type(seen) ~= "table" or type(questList) ~= "table" then
        return
    end

    for _, info in pairs(questList) do
        local questID = nil
        if type(info) == "number" then
            questID = info
        elseif type(info) == "table" then
            questID = tonumber(info.questId or info.questID)
        end

        if type(questID) == "number" and questID > 0 and not seen[questID] then
            seen[questID] = true
            target[#target + 1] = questID
        end
    end
end

local function GetTaskQuestsForMap(mapID)
    if type(mapID) ~= "number" or mapID <= 0 or type(C_TaskQuest) ~= "table" then
        return nil
    end

    if type(C_TaskQuest.GetQuestsForPlayerByMapID) == "function" then
        local quests = SafeCall(C_TaskQuest.GetQuestsForPlayerByMapID, mapID)
        if type(quests) == "table" then
            return quests
        end
    end

    if type(C_TaskQuest.GetQuestsOnMap) == "function" then
        local quests = SafeCall(C_TaskQuest.GetQuestsOnMap, mapID)
        if type(quests) == "table" then
            return quests
        end
    end

    return nil
end

local function BuildMapQueryList(currentMapID)
    local queryList = {}
    local seen = {}

    local function AddMap(mapID)
        if type(mapID) == "number" and mapID > 0 and not seen[mapID] then
            seen[mapID] = true
            queryList[#queryList + 1] = mapID
        end
    end

    AddMap(currentMapID)

    local info = GetMapInfoSafe(currentMapID)
    while type(info) == "table" and type(info.parentMapID) == "number" and info.parentMapID > 0 do
        AddMap(info.parentMapID)
        info = GetMapInfoSafe(info.parentMapID)
    end

    return queryList
end

local function GetSuperTrackedQuestID()
    if type(C_SuperTrack) == "table" and type(C_SuperTrack.GetSuperTrackedQuestID) == "function" then
        return SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
    end

    return nil
end

local function FormatTimeRemaining(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return nil
    end

    if seconds >= 86400 then
        return string_format("%dd", math_floor(seconds / 86400))
    end
    if seconds >= 3600 then
        return string_format("%dh", math_floor(seconds / 3600))
    end
    if seconds >= 60 then
        return string_format("%dm", math_floor(seconds / 60))
    end

    return string_format("%ds", math_floor(seconds))
end

local function BuildEntryMetaText(entry)
    local parts = {}
    if entry.isCurrentZone then
        parts[#parts + 1] = "Current Zone"
    elseif type(entry.zoneName) == "string" and entry.zoneName ~= "" then
        parts[#parts + 1] = entry.zoneName
    end

    if entry.isWorldQuest then
        parts[#parts + 1] = "World Quest"
    end

    if type(entry.tagName) == "string" and entry.tagName ~= "" and entry.tagName ~= "World Quest" then
        parts[#parts + 1] = entry.tagName
    end

    local timeText = FormatTimeRemaining(entry.timeLeftSeconds)
    if timeText then
        parts[#parts + 1] = timeText .. " left"
    end

    return table.concat(parts, "  •  ")
end

local function SetWaypoint(mapID, x, y, questID)
    if type(mapID) == "number" and type(x) == "number" and type(y) == "number"
        and type(_G.CreateVector2D) == "function"
        and type(C_Map) == "table"
        and type(C_Map.SetUserWaypoint) == "function"
    then
        SafeCall(C_Map.SetUserWaypoint, {
            uiMapID = mapID,
            position = _G.CreateVector2D(x, y),
        })
        if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            SafeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
        end
        return true
    end

    if type(questID) == "number" and type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        SafeCall(C_SuperTrack.SetSuperTrackedQuestID, questID)
        return true
    end

    return false
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

function ObjectiveTracker:GetSectionColor(sectionKey)
    local options = GetOptions()
    local colorKey = SECTION_COLOR_KEYS[sectionKey] or "sectionQuestColor"
    return ResolveColor(options, colorKey, { 0.94, 0.74, 0.28 }, "primaryColor")
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
            ObjectiveTracker:RefreshNow(ObjectiveTracker.lastRefreshReason or "dirty-frame")
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
    local frame = CreateFrame("Button", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    frame:SetHeight(28)
    frame:RegisterForClicks("AnyUp")

    frame.Highlight = frame:CreateTexture(nil, "BACKGROUND")
    frame.Highlight:SetAllPoints()
    frame.Highlight:Hide()

    frame.Accent = frame:CreateTexture(nil, "ARTWORK")
    frame.Accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.Accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.Accent:SetWidth(2)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", ROW_PADDING, 0)
    frame.Title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetJustifyV("TOP")
    frame.Title:SetWordWrap(true)

    frame.Meta = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Meta:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -1)
    frame.Meta:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -1)
    frame.Meta:SetJustifyH("LEFT")
    frame.Meta:SetJustifyV("TOP")
    frame.Meta:SetWordWrap(true)

    frame.Objectives = {}
    frame.index = index
    frame:SetScript("OnEnter", function(self)
        ObjectiveTracker.frameHovered = true
        ObjectiveTracker:UpdateTrackedAlphaTarget()
        ObjectiveTracker:ShowEntryTooltip(self)
        self.Highlight:Show()
    end)
    frame:SetScript("OnLeave", function(self)
        ObjectiveTracker:HideEntryTooltip()
        self.Highlight:Hide()
        if ObjectiveTracker.frame and ObjectiveTracker.frame.IsMouseOver and not ObjectiveTracker.frame:IsMouseOver() then
            ObjectiveTracker.frameHovered = false
            ObjectiveTracker:UpdateTrackedAlphaTarget()
        end
    end)
    frame:SetScript("OnClick", function(self, button)
        ObjectiveTracker:HandleEntryClick(self, button)
    end)

    return frame
end

function ObjectiveTracker:GetObjectiveFontString(entryFrame, index)
    entryFrame.Objectives = entryFrame.Objectives or {}
    if entryFrame.Objectives[index] then
        return entryFrame.Objectives[index]
    end

    local text = entryFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", ROW_PADDING + 8, 0)
    text:SetPoint("TOPRIGHT", entryFrame, "TOPRIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(true)
    entryFrame.Objectives[index] = text
    return text
end

function ObjectiveTracker:CreateSectionFrame(parent, index)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    frame:SetHeight(SECTION_HEADER_HEIGHT)

    frame.Header = CreateFrame("Button", nil, frame)
    frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.Header:SetHeight(SECTION_HEADER_HEIGHT)

    frame.HeaderHighlight = frame.Header:CreateTexture(nil, "BACKGROUND")
    frame.HeaderHighlight:SetAllPoints()
    frame.HeaderHighlight:Hide()

    frame.Accent = frame.Header:CreateTexture(nil, "ARTWORK")
    frame.Accent:SetPoint("TOPLEFT", frame.Header, "TOPLEFT", 0, 1)
    frame.Accent:SetPoint("BOTTOMLEFT", frame.Header, "BOTTOMLEFT", 0, -1)
    frame.Accent:SetWidth(2)

    frame.Label = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.Label:SetPoint("LEFT", frame.Header, "LEFT", 8, 0)
    frame.Label:SetJustifyH("LEFT")

    frame.Count = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Count:SetPoint("RIGHT", frame.Header, "RIGHT", -18, 0)
    frame.Count:SetJustifyH("RIGHT")

    frame.Chevron = frame.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.Chevron:SetPoint("RIGHT", frame.Header, "RIGHT", -2, 0)
    frame.Chevron:SetJustifyH("RIGHT")

    frame.Body = CreateFrame("Frame", nil, frame)
    frame.Body:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 0, -1)
    frame.Body:SetPoint("TOPRIGHT", frame.Header, "BOTTOMRIGHT", 0, -1)
    frame.Body:SetHeight(1)

    frame.entryPool = {}
    frame.index = index
    frame.Header:SetScript("OnEnter", function(self)
        ObjectiveTracker.frameHovered = true
        ObjectiveTracker:UpdateTrackedAlphaTarget()
        self:GetParent().HeaderHighlight:Show()
    end)
    frame.Header:SetScript("OnLeave", function(self)
        self:GetParent().HeaderHighlight:Hide()
        if ObjectiveTracker.frame and ObjectiveTracker.frame.IsMouseOver and not ObjectiveTracker.frame:IsMouseOver() then
            ObjectiveTracker.frameHovered = false
            ObjectiveTracker:UpdateTrackedAlphaTarget()
        end
    end)
    frame.Header:SetScript("OnClick", function(self, button)
        local parentFrame = self:GetParent()
        if button == "LeftButton" then
            ObjectiveTracker:ToggleSectionCollapsed(parentFrame.sectionKey)
        elseif button == "RightButton" then
            ObjectiveTracker:ShowSectionMenu(parentFrame)
        end
    end)

    return frame
end

function ObjectiveTracker:GetSectionFrame(index)
    self.sectionPool = self.sectionPool or {}
    if self.sectionPool[index] then
        return self.sectionPool[index]
    end

    local section = self:CreateSectionFrame(self.frame.Content, index)
    self.sectionPool[index] = section
    return section
end

function ObjectiveTracker:GetEntryFrame(sectionFrame, index)
    if sectionFrame.entryPool[index] then
        return sectionFrame.entryPool[index]
    end

    local entry = self:CreateEntryFrame(sectionFrame.Body, index)
    sectionFrame.entryPool[index] = entry
    return entry
end

function ObjectiveTracker:CreateFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "TwichUIObjectiveTrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(340, 220)
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
    frame.Title:SetPoint("RIGHT", frame.Header, "RIGHT", -58, 0)
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

    frame:SetScript("OnEnter", function()
        ObjectiveTracker.frameHovered = true
        ObjectiveTracker:UpdateTrackedAlphaTarget()
    end)
    frame:SetScript("OnLeave", function(self)
        if self.IsMouseOver and self:IsMouseOver() then
            return
        end
        ObjectiveTracker.frameHovered = false
        ObjectiveTracker:UpdateTrackedAlphaTarget()
    end)
    frame:SetScript("OnUpdate", function(_, elapsed)
        ObjectiveTracker:OnFrameUpdate(elapsed)
    end)

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

    local backgroundR, backgroundG, backgroundB = ResolveColor(options, "backgroundColor", { 0.05, 0.06, 0.08 },
        "backgroundColor")
    local borderR, borderG, borderB = ResolveColor(options, "borderColor", { 0.24, 0.26, 0.32 }, "borderColor")
    local accentR, accentG, accentB = ResolveColor(options, "accentColor", { 0.10, 0.72, 0.74 }, "primaryColor")
    local headerTextR, headerTextG, headerTextB = ResolveColor(options, "headerTextColor", { 0.92, 0.94, 0.98 },
        "textColor")
    local metaR, metaG, metaB = ResolveColor(options, "metaTextColor", { 0.66, 0.70, 0.78 }, nil)
    local headerFontPath = ResolveFontPath(options.GetHeaderFont and options:GetHeaderFont() or "__default")
    local bodyFontPath = ResolveFontPath(options.GetBodyFont and options:GetBodyFont() or "__default")

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(backgroundR, backgroundG, backgroundB, Clamp(options:GetBackgroundAlpha(), 0, 1))
    frame:SetBackdropBorderColor(borderR, borderG, borderB, Clamp(options:GetBorderAlpha(), 0, 1))
    frame.HeaderAccent:SetColorTexture(accentR, accentG, accentB, 0.95)
    frame.Title:SetFont(headerFontPath, options:GetHeaderFontSize(), "")
    frame.Title:SetTextColor(headerTextR, headerTextG, headerTextB)
    frame.Count:SetFont(bodyFontPath, options:GetMetaFontSize(), "")
    frame.Count:SetTextColor(metaR, metaG, metaB)
    frame.CollapseButton.Text:SetFont(headerFontPath, options:GetHeaderFontSize(), "")
    frame.CollapseButton.Text:SetTextColor(headerTextR, headerTextG, headerTextB)
    frame.EmptyText:SetFont(bodyFontPath, options:GetBodyFontSize(), "")
    frame.EmptyText:SetTextColor(metaR, metaG, metaB)
    frame.OverflowText:SetFont(bodyFontPath, options:GetMetaFontSize(), "")
    frame.OverflowText:SetTextColor(metaR, metaG, metaB)
    frame:SetScale(options:GetScale())
    frame:SetWidth(options:GetWidth())
end

function ObjectiveTracker:IsQuestObjectiveComplete(objective)
    if type(objective) ~= "table" then
        return false
    end

    return objective.finished == true or objective.completed == true or objective.isCompleted == true
end

function ObjectiveTracker:BuildQuestObjectiveText(objective)
    if type(objective) ~= "table" then
        return nil, false
    end

    local text = objective.text or objective.description
    if type(text) ~= "string" or text == "" then
        return nil, false
    end

    return "• " .. text, self:IsQuestObjectiveComplete(objective)
end

function ObjectiveTracker:BuildQuestEntry(questID, currentMapID)
    local info = GetQuestInfoByID(questID)
    if type(info) ~= "table" or info.isHeader == true or info.isHidden == true then
        return nil
    end

    local mapID = GetQuestMapID(questID)
    local isCurrentZone = IsCurrentZoneMap(mapID, currentMapID)
    local isWorld = IsWorldQuest(questID)
    local isComplete = info.isComplete == true or IsQuestComplete(questID) == true
    local tagName = GetQuestTagName(questID)

    local sectionKey = "quests"
    if isComplete then
        sectionKey = "completed"
    elseif isCurrentZone then
        sectionKey = "currentZone"
    elseif isWorld then
        sectionKey = "world"
    end

    local entry = {
        signature = string_format("quest:%d:%s:%s", questID, tostring(isComplete), tostring(isCurrentZone)),
        type = "quest",
        questID = questID,
        title = info.title or GetQuestTitle(questID),
        zoneName = GetQuestZoneName(questID, mapID),
        mapID = mapID,
        x = nil,
        y = nil,
        isCurrentZone = isCurrentZone,
        isWorldQuest = isWorld,
        isComplete = isComplete,
        isSuperTracked = GetSuperTrackedQuestID() == questID,
        timeLeftSeconds = GetQuestTimeLeftSeconds(questID),
        tagName = tagName,
        sectionKey = sectionKey,
        objectives = {},
    }

    entry.x, entry.y = GetQuestLocation(questID, mapID)

    local options = GetOptions()
    if options and options:GetShowQuestObjectives() then
        local objectives = GetQuestObjectives(questID)
        if type(objectives) == "table" then
            for _, objective in ipairs(objectives) do
                local objectiveText, objectiveComplete = self:BuildQuestObjectiveText(objective)
                if objectiveText then
                    table_insert(entry.objectives, {
                        text = objectiveText,
                        isComplete = objectiveComplete,
                    })
                end
            end
        end
    end

    entry.metaText = BuildEntryMetaText(entry)
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
        signature = "scenario:" .. tostring(scenarioName) .. ":" .. tostring(stepName),
        type = "scenario",
        title = (type(stepName) == "string" and stepName ~= "" and stepName) or scenarioName,
        subtitle = scenarioName,
        sectionKey = "scenario",
        isScenario = true,
        isCurrentZone = true,
        isWorldQuest = false,
        isComplete = false,
        isSuperTracked = false,
        objectives = {},
        metaText = scenarioName,
    }

    if type(C_ScenarioInfo) == "table" and type(C_ScenarioInfo.GetCriteriaInfo) == "function" then
        for index = 1, math_max(numCriteria, MAX_SCENARIO_CRITERIA) do
            local info = SafeCall(C_ScenarioInfo.GetCriteriaInfo, index)
            if type(info) == "table" and type(info.description) == "string" and info.description ~= "" then
                table_insert(entry.objectives, {
                    text = "• " .. info.description,
                    isComplete = info.completed == true,
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
    local currentMapID = GetCurrentMapID()
    local seenQuestIDs = {}

    if type(C_QuestLog) == "table"
        and type(C_QuestLog.GetNumQuestWatches) == "function"
        and type(C_QuestLog.GetQuestIDForQuestWatchIndex) == "function"
    then
        local watchCount = SafeCall(C_QuestLog.GetNumQuestWatches) or 0
        for index = 1, watchCount do
            local questID = SafeCall(C_QuestLog.GetQuestIDForQuestWatchIndex, index)
            if type(questID) == "number" then
                seenQuestIDs[questID] = true
                local entry = self:BuildQuestEntry(questID, currentMapID)
                if entry then
                    table_insert(entries, entry)
                end
            end
        end
    end

    local queryMaps = BuildMapQueryList(currentMapID)
    local taskQuestIDs = {}
    for _, mapID in ipairs(queryMaps) do
        AppendQuestIDs(taskQuestIDs, seenQuestIDs, GetTaskQuestsForMap(mapID))
    end

    for _, questID in ipairs(taskQuestIDs) do
        local entry = self:BuildQuestEntry(questID, currentMapID)
        if entry and (entry.isWorldQuest or entry.isCurrentZone) then
            table_insert(entries, entry)
        end
    end

    local scenarioEntry = self:BuildScenarioEntry()
    if scenarioEntry then
        table_insert(entries, 1, scenarioEntry)
    end

    return entries
end

function ObjectiveTracker:BuildSections(entries)
    local options = GetOptions()
    local zoneMode = options and options.GetZoneFilterMode and options:GetZoneFilterMode() or "prioritize"
    local sectionsByKey = {}

    for _, entry in ipairs(entries) do
        local effectiveSectionKey = entry.sectionKey
        if zoneMode == "all" and effectiveSectionKey == "currentZone" then
            effectiveSectionKey = entry.isWorldQuest and "world" or "quests"
        end

        if not (zoneMode == "current" and effectiveSectionKey ~= "scenario" and entry.isCurrentZone ~= true) then
            if not (entry.isComplete and options and options.GetShowCompletedQuests and options:GetShowCompletedQuests() ~= true) then
                local section = sectionsByKey[effectiveSectionKey]
                if not section then
                    section = {
                        key = effectiveSectionKey,
                        title = SECTION_TITLES[effectiveSectionKey] or effectiveSectionKey,
                        entries = {},
                    }
                    sectionsByKey[effectiveSectionKey] = section
                end
                table_insert(section.entries, entry)
            end
        end
    end

    for _, section in pairs(sectionsByKey) do
        table_sort(section.entries, function(a, b)
            if a.isSuperTracked ~= b.isSuperTracked then
                return a.isSuperTracked == true
            end
            if a.isCurrentZone ~= b.isCurrentZone then
                return a.isCurrentZone == true
            end
            if a.isComplete ~= b.isComplete then
                return a.isComplete == false
            end
            if a.timeLeftSeconds ~= b.timeLeftSeconds then
                if a.timeLeftSeconds == nil then
                    return false
                end
                if b.timeLeftSeconds == nil then
                    return true
                end
                return a.timeLeftSeconds < b.timeLeftSeconds
            end
            return tostring(a.title or "") < tostring(b.title or "")
        end)
    end

    local orderedSections = {}
    for _, key in ipairs(SECTION_ORDER) do
        local section = sectionsByKey[key]
        if section and #section.entries > 0 then
            table_insert(orderedSections, section)
        end
    end

    return orderedSections
end

function ObjectiveTracker:ApplyEntryLimit(sections)
    local options = GetOptions()
    local remaining = options and options.GetMaxEntries and options:GetMaxEntries() or 12
    local overflowCount = 0
    local visibleSections = {}

    for _, section in ipairs(sections) do
        local totalCount = #section.entries
        if remaining <= 0 then
            overflowCount = overflowCount + totalCount
        else
            local takeCount = math_min(totalCount, remaining)
            local visibleEntries = {}
            for index = 1, takeCount do
                visibleEntries[index] = section.entries[index]
            end
            remaining = remaining - takeCount
            overflowCount = overflowCount + (totalCount - takeCount)
            if takeCount > 0 then
                section.totalCount = totalCount
                section.visibleEntries = visibleEntries
                section.hiddenEntryCount = totalCount - takeCount
                table_insert(visibleSections, section)
            end
        end
    end

    return visibleSections, overflowCount
end

function ObjectiveTracker:ShouldHideForContext()
    local options = GetOptions()
    if not options then
        return false
    end

    if options:GetHideInCombat() and InCombatLockdown and InCombatLockdown() then
        return true
    end

    if type(IsInInstance) == "function" then
        local inInstance = SafeCall(IsInInstance)
        if inInstance and type(GetInstanceInfo) == "function" then
            local _, instanceType = GetInstanceInfo()
            if instanceType == "party" and options:GetHideInDungeon() then
                return true
            end
            if instanceType == "raid" and options:GetHideInRaid() then
                return true
            end
        end
    end

    return false
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

function ObjectiveTracker:UpdateTrackedAlphaTarget()
    if not self.frame then
        return
    end

    local options = GetOptions()
    if not options then
        return
    end

    local targetAlpha = options:GetOpacity()
    if options:GetFadeWhenNotHovered() and self.frameHovered ~= true then
        targetAlpha = options:GetInactiveOpacity()
    end

    self.targetAlpha = Clamp(targetAlpha, 0.05, 1)
end

function ObjectiveTracker:OnFrameUpdate(elapsed)
    if not self.frame or not self.frame:IsShown() then
        return
    end

    self:UpdateTrackedAlphaTarget()
    local currentAlpha = self.frame:GetAlpha() or 1
    local targetAlpha = self.targetAlpha or 1
    if math_abs(currentAlpha - targetAlpha) < 0.005 then
        self.frame:SetAlpha(targetAlpha)
        return
    end

    local nextAlpha = currentAlpha + ((targetAlpha - currentAlpha) * math_min(1, (elapsed or 0) * ALPHA_LERP_SPEED))
    self.frame:SetAlpha(nextAlpha)
end

function ObjectiveTracker:ShowEntryTooltip(entryFrame)
    local options = GetOptions()
    if not options or options:GetShowTooltips() ~= true or not GameTooltip or GameTooltip.IsForbidden and GameTooltip:IsForbidden() then
        return
    end

    local entry = entryFrame and entryFrame.entry or nil
    if type(entry) ~= "table" then
        return
    end

    GameTooltip:SetOwner(entryFrame, "ANCHOR_LEFT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(entry.title or "Objective", 1, 1, 1)

    if type(entry.metaText) == "string" and entry.metaText ~= "" then
        GameTooltip:AddLine(entry.metaText, 0.8, 0.84, 0.92, true)
    end

    for _, objective in ipairs(entry.objectives or {}) do
        if type(objective.text) == "string" and objective.text ~= "" then
            if objective.isComplete then
                GameTooltip:AddLine(objective.text, 0.42, 0.88, 0.64, true)
            else
                GameTooltip:AddLine(objective.text, 0.74, 0.77, 0.84, true)
            end
        end
    end

    if entry.questID then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left Click: Super Track", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Shift+Left Click: Open Quest Details", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Right Click: Context Menu", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Shift+Right Click: Untrack", 0.85, 0.85, 0.85)
    end

    GameTooltip:Show()
end

function ObjectiveTracker:HideEntryTooltip()
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

function ObjectiveTracker:OpenQuestDetails(entry)
    if not entry or type(entry.questID) ~= "number" then
        return
    end

    if type(QuestMapFrame_OpenToQuestDetails) == "function" then
        SafeCall(QuestMapFrame_OpenToQuestDetails, entry.questID)
        return
    end

    if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        SafeCall(C_SuperTrack.SetSuperTrackedQuestID, entry.questID)
    end
end

function ObjectiveTracker:SuperTrackEntry(entry)
    if not entry then
        return
    end

    if type(entry.questID) == "number" and type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        SafeCall(C_SuperTrack.SetSuperTrackedQuestID, entry.questID)
    elseif type(entry.mapID) == "number" then
        SetWaypoint(entry.mapID, entry.x, entry.y, entry.questID)
    end

    self:ScheduleRefresh("super-track")
end

function ObjectiveTracker:UntrackEntry(entry)
    if not entry or type(entry.questID) ~= "number" then
        return
    end

    if entry.isWorldQuest and type(C_QuestLog) == "table" and type(C_QuestLog.RemoveWorldQuestWatch) == "function" then
        SafeCall(C_QuestLog.RemoveWorldQuestWatch, entry.questID)
    elseif type(C_QuestLog) == "table" and type(C_QuestLog.RemoveQuestWatch) == "function" then
        SafeCall(C_QuestLog.RemoveQuestWatch, entry.questID)
    end

    if type(C_SuperTrack) == "table"
        and type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
        and type(C_SuperTrack.SetSuperTrackedQuestID) == "function"
        and SafeCall(C_SuperTrack.GetSuperTrackedQuestID) == entry.questID
    then
        SafeCall(C_SuperTrack.SetSuperTrackedQuestID, 0)
    end

    self:ScheduleRefresh("untrack")
end

function ObjectiveTracker:ShowEntryMenu(entryFrame)
    local entry = entryFrame and entryFrame.entry or nil
    local ui = T.Tools and T.Tools.UI or nil
    if type(entry) ~= "table" or not ui or type(ui.ShowSecureDropdown) ~= "function" then
        return
    end

    local menu = {
        { text = entry.title or "Objective", isTitle = true },
        {
            text = "Super Track",
            disabled = entry.questID == nil and entry.mapID == nil,
            func = function()
                ObjectiveTracker:SuperTrackEntry(entry)
            end,
        },
        {
            text = "Open Quest Details",
            disabled = entry.questID == nil,
            func = function()
                ObjectiveTracker:OpenQuestDetails(entry)
            end,
        },
        {
            text = "Set Waypoint",
            disabled = entry.mapID == nil,
            func = function()
                SetWaypoint(entry.mapID, entry.x, entry.y, entry.questID)
            end,
        },
        {
            text = "Untrack",
            disabled = entry.questID == nil,
            func = function()
                ObjectiveTracker:UntrackEntry(entry)
            end,
        },
        {
            text = "Collapse Section",
            disabled = type(entryFrame.sectionKey) ~= "string",
            func = function()
                ObjectiveTracker:ToggleSectionCollapsed(entryFrame.sectionKey)
            end,
        },
    }

    ui.ShowSecureDropdown(menu, entryFrame)
end

function ObjectiveTracker:ShowSectionMenu(sectionFrame)
    local ui = T.Tools and T.Tools.UI or nil
    if not ui or type(ui.ShowSecureDropdown) ~= "function" or not sectionFrame or not sectionFrame.sectionKey then
        return
    end

    local isCollapsed = self:IsSectionCollapsed(sectionFrame.sectionKey)
    ui.ShowSecureDropdown({
        { text = sectionFrame.sectionTitle or "Section", isTitle = true },
        {
            text = isCollapsed and "Expand Section" or "Collapse Section",
            func = function()
                ObjectiveTracker:ToggleSectionCollapsed(sectionFrame.sectionKey)
            end,
        },
        {
            text = self.frame and self.frame:IsShown() and "Collapse Tracker" or "Expand Tracker",
            func = function()
                ObjectiveTracker:ToggleCollapsed()
            end,
        },
    }, sectionFrame.Header)
end

function ObjectiveTracker:HandleEntryClick(entryFrame, button)
    local entry = entryFrame and entryFrame.entry or nil
    if type(entry) ~= "table" then
        return
    end

    if button == "RightButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then
            self:UntrackEntry(entry)
        else
            self:ShowEntryMenu(entryFrame)
        end
        return
    end

    if button == "LeftButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then
            self:OpenQuestDetails(entry)
        else
            self:SuperTrackEntry(entry)
        end
    end
end

function ObjectiveTracker:IsSectionCollapsed(sectionKey)
    local options = GetOptions()
    return options and type(options.GetSectionCollapsed) == "function" and
        options:GetSectionCollapsed(sectionKey) == true
end

function ObjectiveTracker:ToggleSectionCollapsed(sectionKey)
    local options = GetOptions()
    if not options or type(options.SetSectionCollapsed) ~= "function" then
        return
    end

    options:SetSectionCollapsed(sectionKey, not self:IsSectionCollapsed(sectionKey))
end

function ObjectiveTracker:PlayEntryAnimation(entryFrame, signature)
    local options = GetOptions()
    if not options or options:GetAnimateEntries() ~= true then
        entryFrame:SetAlpha(1)
        entryFrame.__tuiLastSignature = signature
        return
    end

    if entryFrame.__tuiLastSignature == signature then
        entryFrame:SetAlpha(1)
        return
    end

    entryFrame.__tuiLastSignature = signature
    entryFrame:SetAlpha(0)
    if entryFrame.animIn and entryFrame.animIn.Stop then
        entryFrame.animIn:Stop()
    end

    if not entryFrame.animIn then
        local animIn = entryFrame:CreateAnimationGroup()
        local alpha = animIn:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(1)
        alpha:SetDuration(0.18)
        alpha:SetSmoothing("OUT")

        local translate = animIn:CreateAnimation("Translation")
        translate:SetOffset(0, -6)
        translate:SetDuration(0.18)
        translate:SetSmoothing("OUT")
        animIn:SetScript("OnFinished", function()
            if entryFrame and entryFrame.SetAlpha then
                entryFrame:SetAlpha(1)
            end
        end)
        entryFrame.animIn = animIn
    end

    entryFrame.animIn:Play()
end

function ObjectiveTracker:LayoutEntry(sectionFrame, entryFrame, entry, yOffset)
    local options = GetOptions()
    if not options then
        return yOffset
    end

    local bodyFontPath = ResolveFontPath(options:GetBodyFont())
    local bodyTextR, bodyTextG, bodyTextB = ResolveColor(options, "bodyTextColor", { 0.82, 0.85, 0.92 }, nil)
    local questTitleR, questTitleG, questTitleB = ResolveColor(options, "questTitleColor", { 0.96, 0.91, 0.68 }, nil)
    local metaR, metaG, metaB = ResolveColor(options, "metaTextColor", { 0.66, 0.70, 0.78 }, nil)
    local completeR, completeG, completeB = ResolveColor(options, "completeColor", { 0.42, 0.88, 0.64 }, nil)
    local objectiveR, objectiveG, objectiveB = ResolveColor(options, "objectiveColor", { 0.74, 0.77, 0.84 }, nil)
    local accentR, accentG, accentB = self:GetSectionColor(sectionFrame.sectionKey)

    entryFrame.entry = entry
    entryFrame.sectionKey = sectionFrame.sectionKey
    entryFrame:ClearAllPoints()
    entryFrame:SetPoint("TOPLEFT", sectionFrame.Body, "TOPLEFT", 0, -yOffset)
    entryFrame:SetPoint("TOPRIGHT", sectionFrame.Body, "TOPRIGHT", 0, -yOffset)
    entryFrame:Show()
    entryFrame.Highlight:SetColorTexture(accentR, accentG, accentB, 0.10)
    entryFrame.Accent:SetColorTexture(accentR, accentG, accentB, entry.isSuperTracked and 1 or 0.6)

    entryFrame.Title:SetFont(bodyFontPath, options:GetBodyFontSize(), "")
    if entry.isComplete then
        entryFrame.Title:SetTextColor(completeR, completeG, completeB)
    elseif entry.type == "quest" then
        entryFrame.Title:SetTextColor(questTitleR, questTitleG, questTitleB)
    else
        entryFrame.Title:SetTextColor(bodyTextR, bodyTextG, bodyTextB)
    end

    local titleText = entry.title or "Objective"
    if entry.isSuperTracked then
        titleText = "[Tracked] " .. titleText
    end
    entryFrame.Title:SetText(titleText)

    local height = math_max(options:GetBodyFontSize() + 4, entryFrame.Title:GetStringHeight())
    local contentOffset = height + 1

    if type(entry.metaText) == "string" and entry.metaText ~= "" then
        entryFrame.Meta:SetFont(bodyFontPath, options:GetMetaFontSize(), "")
        entryFrame.Meta:SetTextColor(metaR, metaG, metaB)
        entryFrame.Meta:SetText(entry.metaText)
        entryFrame.Meta:Show()
        contentOffset = contentOffset + math_max(options:GetMetaFontSize(), entryFrame.Meta:GetStringHeight()) + 2
        height = math_max(height, contentOffset)
    else
        entryFrame.Meta:SetText("")
        entryFrame.Meta:Hide()
    end

    for objectiveIndex, objectiveLine in ipairs(entryFrame.Objectives or {}) do
        objectiveLine:Hide()
    end

    if options:GetShowQuestObjectives() and type(entry.objectives) == "table" then
        for objectiveIndex, objective in ipairs(entry.objectives) do
            local textLine = self:GetObjectiveFontString(entryFrame, objectiveIndex)
            textLine:SetFont(bodyFontPath, options:GetMetaFontSize(), "")
            textLine:SetText(objective.text or "")
            textLine:ClearAllPoints()
            textLine:SetPoint("TOPLEFT", entryFrame, "TOPLEFT", ROW_PADDING + 8, -contentOffset)
            textLine:SetPoint("TOPRIGHT", entryFrame, "TOPRIGHT", -4, -contentOffset)
            if objective.isComplete then
                textLine:SetTextColor(completeR, completeG, completeB)
            else
                textLine:SetTextColor(objectiveR, objectiveG, objectiveB)
            end
            textLine:Show()
            local lineHeight = math_max(options:GetMetaFontSize(), textLine:GetStringHeight())
            contentOffset = contentOffset + lineHeight + OBJECTIVE_GAP
            height = math_max(height, contentOffset)
        end
    end

    entryFrame:SetHeight(height)
    self:PlayEntryAnimation(entryFrame, entry.signature)
    return yOffset + height + ENTRY_GAP
end

function ObjectiveTracker:HideUnusedSections()
    for _, sectionFrame in pairs(self.sectionPool or {}) do
        sectionFrame:Hide()
        if sectionFrame.entryPool then
            for _, entryFrame in pairs(sectionFrame.entryPool) do
                entryFrame:Hide()
                for _, objectiveLine in ipairs(entryFrame.Objectives or {}) do
                    objectiveLine:Hide()
                end
            end
        end
    end
end

function ObjectiveTracker:LayoutSection(sectionFrame, section, yOffset)
    local options = GetOptions()
    if not options then
        return yOffset
    end

    local categoryFontPath = ResolveFontPath(options:GetCategoryFont())
    local metaFontPath = ResolveFontPath(options:GetBodyFont())
    local sectionR, sectionG, sectionB = self:GetSectionColor(section.key)
    local textR, textG, textB = ResolveColor(options, "headerTextColor", { 0.92, 0.94, 0.98 }, "textColor")
    local metaR, metaG, metaB = ResolveColor(options, "metaTextColor", { 0.66, 0.70, 0.78 }, nil)

    sectionFrame.sectionKey = section.key
    sectionFrame.sectionTitle = section.title
    sectionFrame:ClearAllPoints()
    sectionFrame:SetPoint("TOPLEFT", self.frame.Content, "TOPLEFT", 0, -yOffset)
    sectionFrame:SetPoint("TOPRIGHT", self.frame.Content, "TOPRIGHT", 0, -yOffset)
    sectionFrame:Show()

    sectionFrame.HeaderHighlight:SetColorTexture(sectionR, sectionG, sectionB, 0.08)
    sectionFrame.Accent:SetColorTexture(sectionR, sectionG, sectionB, 0.95)
    sectionFrame.Label:SetFont(categoryFontPath, options:GetCategoryFontSize(), "")
    sectionFrame.Label:SetTextColor(textR, textG, textB)
    sectionFrame.Label:SetText(section.title)
    sectionFrame.Count:SetFont(metaFontPath, options:GetMetaFontSize(), "")
    sectionFrame.Count:SetTextColor(metaR, metaG, metaB)
    sectionFrame.Count:SetText(tostring(section.totalCount or #section.entries or 0))
    sectionFrame.Chevron:SetFont(categoryFontPath, options:GetCategoryFontSize(), "")
    sectionFrame.Chevron:SetTextColor(sectionR, sectionG, sectionB)

    local isCollapsed = self:IsSectionCollapsed(section.key)
    sectionFrame.Chevron:SetText(isCollapsed and "+" or "-")

    local totalHeight = SECTION_HEADER_HEIGHT
    for _, entryFrame in pairs(sectionFrame.entryPool or {}) do
        entryFrame:Hide()
        for _, objectiveLine in ipairs(entryFrame.Objectives or {}) do
            objectiveLine:Hide()
        end
    end

    if isCollapsed then
        sectionFrame.Body:Hide()
        sectionFrame:SetHeight(totalHeight)
        return yOffset + totalHeight + SECTION_GAP
    end

    sectionFrame.Body:Show()
    local sectionOffset = 0
    for index, entry in ipairs(section.visibleEntries or {}) do
        local entryFrame = self:GetEntryFrame(sectionFrame, index)
        sectionOffset = self:LayoutEntry(sectionFrame, entryFrame, entry, sectionOffset)
    end

    sectionFrame.Body:SetHeight(math_max(1, sectionOffset))
    totalHeight = totalHeight + sectionOffset
    sectionFrame:SetHeight(totalHeight)
    return yOffset + totalHeight + SECTION_GAP
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

    if self:ShouldHideForContext() then
        frame:Hide()
        return
    end

    local entries = self:CollectEntries()
    local sections = self:BuildSections(entries)
    local visibleSections, overflowCount = self:ApplyEntryLimit(sections)

    frame:SetWidth(options:GetWidth())
    frame:SetScale(options:GetScale())
    frame.Count:SetText(#entries > 0 and tostring(#entries) or "")
    frame.CollapseButton.Text:SetText(options:GetCollapsed() and "+" or "-")
    frame.EmptyText:SetText(options:GetEmptyText())

    self:HideUnusedSections()

    if #entries == 0 then
        frame.EmptyText:Show()
        frame.OverflowText:SetText("")
        frame.OverflowText:Hide()
        frame:SetHeight(HEADER_HEIGHT + (PANEL_PADDING * 2) + options:GetBodyFontSize() + 12)
        frame:Show()
        frame:SetAlpha(options:GetOpacity())
        self.frameHovered = false
        self:UpdateTrackedAlphaTarget()
        return
    end

    frame.EmptyText:Hide()
    if options:GetCollapsed() then
        frame.OverflowText:SetText("")
        frame.OverflowText:Hide()
        frame:SetHeight(HEADER_HEIGHT + 10)
        frame:Show()
        frame:SetAlpha(options:GetOpacity())
        self.frameHovered = false
        self:UpdateTrackedAlphaTarget()
        return
    end

    local yOffset = 0
    for index, section in ipairs(visibleSections) do
        local sectionFrame = self:GetSectionFrame(index)
        yOffset = self:LayoutSection(sectionFrame, section, yOffset)
    end

    if overflowCount > 0 then
        frame.OverflowText:SetText(string_format("%d more tracked objectives hidden by the entry limit.", overflowCount))
        frame.OverflowText:Show()
        yOffset = yOffset + math_max(options:GetMetaFontSize(), frame.OverflowText:GetStringHeight()) + 4
    else
        frame.OverflowText:SetText("")
        frame.OverflowText:Hide()
    end

    frame:SetHeight(HEADER_HEIGHT + (PANEL_PADDING * 2) + yOffset)
    frame:Show()
    if options:GetFadeWhenNotHovered() ~= true then
        frame:SetAlpha(options:GetOpacity())
    end
    self:UpdateTrackedAlphaTarget()
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
            return ObjectiveTracker.frame and ObjectiveTracker.frame:GetWidth() or 340
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
                label = "Fade On Mouseover",
                type = "toggle",
                get = function()
                    local options = GetOptions()
                    return options and options:GetFadeWhenNotHovered() or false
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetFadeWhenNotHovered(nil, value)
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
                label = "Hide In Dungeons",
                type = "toggle",
                get = function()
                    local options = GetOptions()
                    return options and options:GetHideInDungeon() or false
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetHideInDungeon(nil, value)
                    end
                end,
            },
            {
                label = "Hide In Raids",
                type = "toggle",
                get = function()
                    local options = GetOptions()
                    return options and options:GetHideInRaid() or false
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetHideInRaid(nil, value)
                    end
                end,
            },
            {
                label = "Scale",
                type = "range",
                min = 0.75,
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
                min = 240,
                max = 560,
                step = 2,
                get = function()
                    local options = GetOptions()
                    return options and options:GetWidth() or 340
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetWidth(nil, value)
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
