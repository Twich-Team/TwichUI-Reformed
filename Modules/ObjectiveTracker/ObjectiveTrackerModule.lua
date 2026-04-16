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
local GetNumSavedInstances = _G.GetNumSavedInstances
local GetSavedInstanceInfo = _G.GetSavedInstanceInfo
local GetSavedInstanceEncounterInfo = _G.GetSavedInstanceEncounterInfo
local GetLFGDungeonNumEncounters = _G.GetLFGDungeonNumEncounters
local GetLFGDungeonEncounterInfo = _G.GetLFGDungeonEncounterInfo
local RequestRaidInfo = _G.RequestRaidInfo
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local C_AddOns = _G.C_AddOns
local C_ChallengeMode = _G.C_ChallengeMode
local C_QuestLog = _G.C_QuestLog
local C_SuperTrack = _G.C_SuperTrack
local C_Scenario = _G.C_Scenario
local C_ScenarioInfo = _G.C_ScenarioInfo
local C_Timer = _G.C_Timer
local C_Map = _G.C_Map
local C_TaskQuest = _G.C_TaskQuest
local C_CampaignInfo = _G.C_CampaignInfo
local C_QuestInfoSystem = _G.C_QuestInfoSystem
local C_QuestLine = _G.C_QuestLine
local C_UIWidgetManager = _G.C_UIWidgetManager
local Enum = _G.Enum
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show
local ShowQuestComplete = _G.ShowQuestComplete
local IsAddOnLoaded = _G.IsAddOnLoaded
local LoadAddOn = _G.LoadAddOn
local GetQuestUiMapID = _G.GetQuestUiMapID
local QuestMapFrame_OpenToQuestDetails = _G.QuestMapFrame_OpenToQuestDetails
local math_abs = math.abs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local ipairs = ipairs
local next = next
local pairs = pairs
local select = select
local table_insert = table.insert
local table_sort = table.sort
local string_format = string.format
local tostring = tostring
local type = type
local GetTime = _G.GetTime

local ABANDON_POPUP_KEY = "TWICHUI_OBJECTIVE_TRACKER_ABANDON_QUEST"

local HEADER_HEIGHT = 30
local SECTION_HEADER_HEIGHT = 22
local PANEL_PADDING = 12
local SECTION_GAP = 8
local ENTRY_GAP = 6
local OBJECTIVE_GAP = 2
local OBJECTIVE_PROGRESS_GAP = 3
local ROW_PADDING = 8
local MAX_SCENARIO_CRITERIA = 10
local ALPHA_LERP_SPEED = 12
local DEBUG_SOURCE_KEY = "objectivetracker"
local WORLD_QUEST_OBJECTIVE_RADIUS = 0.08
local STATUSBAR_TEXTURE_FALLBACK = "Interface\\TargetingFrame\\UI-StatusBar"
local WIDGET_TYPE_STATUSBAR = (Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.StatusBar) or 2
local WIDGET_TYPE_ICONANDTEXT = (Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.IconAndText) or
0

local SECTION_ORDER = {
    "instance",
    "scenario",
    "completeNow",
    "campaign",
    "currentZone",
    "world",
    "quests",
    "completed",
}

local SECTION_TITLES = {
    instance = "Instance",
    scenario = "Scenario",
    completeNow = "Complete Now",
    campaign = "Campaign",
    currentZone = "Current Zone",
    world = "World Quests",
    quests = "Tracked Quests",
    completed = "Completed",
}

local SECTION_COLOR_KEYS = {
    instance = "sectionScenarioColor",
    scenario = "sectionScenarioColor",
    completeNow = "sectionCompletedColor",
    campaign = "sectionQuestColor",
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
    "QUEST_COMPLETE",
    "QUEST_AUTOCOMPLETE",
    "QUEST_TURNED_IN",
    "UPDATE_UI_WIDGET",
    "UPDATE_ALL_UI_WIDGETS",
    "SUPER_TRACKING_CHANGED",
    "UPDATE_INSTANCE_INFO",
    "ENCOUNTER_END",
    "SCENARIO_UPDATE",
    "SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_POI_UPDATE",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET",
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

    local results = { pcall(func, ...) }
    local ok = results[1]
    if not ok then
        return nil
    end

    return select(2, unpack(results))
end

local function GetDebugConsole()
    return T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil
end

local GetCurrentInstanceContext

local function SafeDebugString(value)
    if value == nil then
        return "nil"
    end

    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" then
        return text
    end

    return "<unprintable>"
end

local function LogDebug(message, shouldShow)
    local console = GetDebugConsole()
    if not console or type(console.Log) ~= "function" then
        return nil
    end

    return console:Log(DEBUG_SOURCE_KEY, SafeDebugString(message), shouldShow == true)
end

local function LogDebugf(shouldShow, messageFormat, ...)
    local console = GetDebugConsole()
    if not console or type(console.Logf) ~= "function" then
        return nil
    end

    return console:Logf(DEBUG_SOURCE_KEY, shouldShow == true, messageFormat, ...)
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

local function ResolveStatusBarTexturePath()
    local LSM = T.Libs and T.Libs.LSM
    if LSM and type(LSM.Fetch) == "function" then
        local path = SafeCall(LSM.Fetch, LSM, "statusbar", "Blizzard", true)
        if type(path) == "string" and path ~= "" then
            return path
        end
    end

    return STATUSBAR_TEXTURE_FALLBACK
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
        local isAccepted = type(C_QuestLog.IsOnQuest) == "function" and SafeCall(C_QuestLog.IsOnQuest, questID) == true
        local isWorld = type(C_QuestLog.IsWorldQuest) == "function" and
            SafeCall(C_QuestLog.IsWorldQuest, questID) == true
        local isTaskActive = type(C_TaskQuest) == "table"
            and type(C_TaskQuest.IsActive) == "function"
            and SafeCall(C_TaskQuest.IsActive, questID) == true
        if not isAccepted and not isWorld and not isTaskActive then
            return nil
        end

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

local function StripColorCodes(text)
    if type(text) ~= "string" then
        return nil
    end

    local cleanText = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    cleanText = cleanText:gsub("^%s+", ""):gsub("%s+$", "")
    if cleanText == "" then
        return nil
    end

    return cleanText
end

local function NormalizeObjectiveSignature(text, value, maxValue, percent)
    local cleanText = StripColorCodes(text) or ""
    cleanText = cleanText:lower():gsub("%s+", " ")
    return string_format("%s:%s:%s:%s", cleanText, tostring(value), tostring(maxValue), tostring(percent))
end

local function BuildProgressBarLabel(progress)
    if type(progress) ~= "table" then
        return nil
    end

    if type(progress.value) == "number" and type(progress.maxValue) == "number" and progress.maxValue > 0 then
        return string_format("%d/%d (%d%%)", progress.value, progress.maxValue, progress.percent or 0)
    end

    if type(progress.percent) == "number" then
        return string_format("%d%%", progress.percent)
    end

    return nil
end

local function BuildObjectiveProgress(objective, displayText)
    if type(objective) ~= "table" then
        return nil
    end

    local value = tonumber(objective.numFulfilled or objective.quantity or objective.barValue or objective.curValue)
    local maxValue = tonumber(objective.numRequired or objective.totalQuantity or objective.barMax or objective.maxValue)
    if type(maxValue) == "number" and maxValue > 0 and type(value) == "number" then
        local clampedValue = Clamp(value, 0, maxValue)
        local percent = math_floor(((clampedValue / maxValue) * 100) + 0.5)
        if maxValue > 1 then
            local progress = {
                value = clampedValue,
                maxValue = maxValue,
                percent = Clamp(percent, 0, 100),
            }
            progress.label = BuildProgressBarLabel(progress)
            return progress
        end
    end

    local percentText = type(displayText) == "string" and tonumber(displayText:match("(%d+)%%")) or nil
    local percent = tonumber(objective.percent or objective.fulfilledPercent or objective.progress or percentText)
    if type(percent) == "number" then
        local progress = {
            percent = Clamp(percent, 0, 100),
            isPercentOnly = true,
        }
        progress.label = BuildProgressBarLabel(progress)
        return progress
    end

    return nil
end

local function GetScenarioWidgetSetID()
    if type(C_Scenario) == "table" and type(C_Scenario.GetStepInfo) == "function" then
        local stepInfo = { SafeCall(C_Scenario.GetStepInfo) }
        local widgetSetID = stepInfo[12]
        if type(widgetSetID) == "number" and widgetSetID > 0 then
            return widgetSetID
        end
    end

    if type(C_UIWidgetManager) == "table" and type(C_UIWidgetManager.GetObjectiveTrackerWidgetSetID) == "function" then
        local widgetSetID = SafeCall(C_UIWidgetManager.GetObjectiveTrackerWidgetSetID)
        if type(widgetSetID) == "number" and widgetSetID > 0 then
            return widgetSetID
        end
    end

    return nil
end

local function GetScenarioWidgetObjectives(widgetSetID)
    if type(widgetSetID) ~= "number"
        or widgetSetID <= 0
        or type(C_UIWidgetManager) ~= "table"
        or type(C_UIWidgetManager.GetAllWidgetsBySetID) ~= "function"
    then
        return nil
    end

    local widgets = SafeCall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
    if type(widgets) ~= "table" then
        return nil
    end

    local objectives = {}
    local seen = {}
    for _, widgetInfo in pairs(widgets) do
        local widgetID = type(widgetInfo) == "table" and widgetInfo.widgetID or widgetInfo
        local widgetType = type(widgetInfo) == "table" and widgetInfo.widgetType or nil

        if type(widgetID) == "number" then
            if (widgetType == nil or widgetType == WIDGET_TYPE_STATUSBAR)
                and type(C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo) == "function"
            then
                local barInfo = SafeCall(C_UIWidgetManager.GetStatusBarWidgetVisualizationInfo, widgetID)
                local maxValue = nil
                if type(barInfo) == "table" then
                    maxValue = tonumber(barInfo.barMax)
                end
                if type(maxValue) == "number" and maxValue > 0 then
                    local value = 0
                    local text = nil
                    if type(barInfo) == "table" then
                        value = Clamp(tonumber(barInfo.barValue) or 0, 0, maxValue)
                        text = StripColorCodes(barInfo.overrideBarText or barInfo.text)
                    end
                    text = text or string_format("%d/%d", value, maxValue)
                    local signature = NormalizeObjectiveSignature(text, value, maxValue, nil)
                    if not seen[signature] then
                        seen[signature] = true
                        objectives[#objectives + 1] = {
                            description = text,
                            completed = value >= maxValue,
                            numFulfilled = value,
                            numRequired = maxValue,
                            percent = math_floor(((value / maxValue) * 100) + 0.5),
                            isWeighted = true,
                        }
                    end
                end
            end

            if (widgetType == nil or widgetType == WIDGET_TYPE_ICONANDTEXT)
                and type(C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo) == "function"
            then
                local iconTextInfo = SafeCall(C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo, widgetID)
                local text = type(iconTextInfo) == "table" and StripColorCodes(iconTextInfo.text) or nil
                if type(text) == "string" then
                    local currentText, maxText = text:match("(%d[%d,]*)%s*/%s*(%d[%d,]*)")
                    if currentText and maxText then
                        local currentValue = tonumber((currentText:gsub(",", "")))
                        local maxValue = tonumber((maxText:gsub(",", "")))
                        if type(currentValue) == "number" and type(maxValue) == "number" and maxValue > 0 then
                            local signature = NormalizeObjectiveSignature(text, currentValue, maxValue, nil)
                            if not seen[signature] then
                                seen[signature] = true
                                objectives[#objectives + 1] = {
                                    description = text,
                                    completed = currentValue >= maxValue,
                                    numFulfilled = currentValue,
                                    numRequired = maxValue,
                                    percent = math_floor(((currentValue / maxValue) * 100) + 0.5),
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    return #objectives > 0 and objectives or nil
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

local function IsExactCurrentMap(mapID, currentMapID)
    return type(mapID) == "number" and type(currentMapID) == "number" and mapID > 0 and currentMapID > 0
        and mapID == currentMapID
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

local function IsQuestAccepted(questID)
    if type(questID) ~= "number" or type(C_QuestLog) ~= "table" then
        return false
    end

    if type(C_QuestLog.IsOnQuest) == "function" then
        return SafeCall(C_QuestLog.IsOnQuest, questID) == true
    end

    if type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local logIndex = SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
        return type(logIndex) == "number" and logIndex > 0
    end

    return false
end

local function IsTaskQuestActive(questID)
    return type(C_TaskQuest) == "table"
        and type(C_TaskQuest.IsActive) == "function"
        and SafeCall(C_TaskQuest.IsActive, questID) == true
end

local function IsQuestStrictlyOnCurrentMap(questID, currentMapID)
    if type(questID) ~= "number" or type(currentMapID) ~= "number" or currentMapID <= 0 then
        return false
    end

    local x, y = GetQuestLocation(questID, currentMapID)
    if type(x) ~= "number" or type(y) ~= "number" or type(C_Map) ~= "table" or type(C_Map.GetPlayerMapPosition) ~= "function" then
        return false
    end

    local playerPosition = SafeCall(C_Map.GetPlayerMapPosition, currentMapID, "player")
    if type(playerPosition) ~= "table" or type(playerPosition.GetXY) ~= "function" then
        return false
    end

    local playerX, playerY = playerPosition:GetXY()
    if type(playerX) ~= "number" or type(playerY) ~= "number" then
        return false
    end

    local deltaX = x - playerX
    local deltaY = y - playerY
    local distance = math_sqrt((deltaX * deltaX) + (deltaY * deltaY))
    return distance <= WORLD_QUEST_OBJECTIVE_RADIUS
end

local function GetQuestZoneName(questID, mapID)
    mapID = mapID or GetQuestMapID(questID)
    local info = GetMapInfoSafe(mapID)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
        return info.name
    end

    return nil
end

local function IsEntryInCurrentArea(entry)
    return type(entry) == "table"
        and (entry.isCurrentZone == true or entry.isOnMap == true or entry.isCurrentTaskMap == true)
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

local function IsCampaignQuest(questID)
    if type(questID) ~= "number" or questID <= 0 then
        return false
    end

    if type(C_CampaignInfo) == "table" and type(C_CampaignInfo.IsCampaignQuest) == "function" then
        if SafeCall(C_CampaignInfo.IsCampaignQuest, questID) == true then
            return true
        end
    end

    if type(C_QuestInfoSystem) == "table"
        and type(C_QuestInfoSystem.GetQuestClassification) == "function"
        and type(Enum) == "table"
        and type(Enum.QuestClassification) == "table"
    then
        return SafeCall(C_QuestInfoSystem.GetQuestClassification, questID) == Enum.QuestClassification.Campaign
    end

    return false
end

local function IsWorldQuest(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.IsWorldQuest) == "function"
        and SafeCall(C_QuestLog.IsWorldQuest, questID) == true
end

local function IsQuestReadyForTurnIn(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.ReadyForTurnIn) == "function"
        and SafeCall(C_QuestLog.ReadyForTurnIn, questID) == true
end

local function IsQuestComplete(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.IsComplete) == "function"
        and SafeCall(C_QuestLog.IsComplete, questID) == true
end

local function IsQuestAutoComplete(questID, info)
    if type(info) == "table" and info.isAutoComplete == true then
        return true
    end

    if type(questID) ~= "number" or type(C_QuestLog) ~= "table" then
        return false
    end

    local logIndex = type(C_QuestLog.GetLogIndexForQuestID) == "function"
        and SafeCall(C_QuestLog.GetLogIndexForQuestID, questID)
        or nil
    if type(logIndex) ~= "number" or logIndex <= 0 or type(C_QuestLog.GetInfo) ~= "function" then
        return false
    end

    local questInfo = SafeCall(C_QuestLog.GetInfo, logIndex)
    return type(questInfo) == "table" and questInfo.isAutoComplete == true
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

local function GetQuestListEntryID(info)
    if type(info) == "number" then
        return info
    end

    if type(info) == "table" then
        return tonumber(info.questId or info.questID)
    end

    return nil
end

local function AppendQuestLogIDs(target, seen, currentMapID)
    if type(target) ~= "table"
        or type(seen) ~= "table"
        or type(C_QuestLog) ~= "table"
        or type(C_QuestLog.GetNumQuestLogEntries) ~= "function"
        or type(C_QuestLog.GetInfo) ~= "function"
    then
        return
    end

    local instance = GetCurrentInstanceContext()
    local superTrackedQuestID = type(C_SuperTrack) == "table"
        and type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
        and SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
        or nil

    local totalEntries = tonumber((SafeCall(C_QuestLog.GetNumQuestLogEntries))) or 0
    for index = 1, totalEntries do
        local info = SafeCall(C_QuestLog.GetInfo, index)
        if type(info) == "table" then
            local questID = tonumber(info.questID)
            if questID and questID > 0 and not seen[questID] and info.isHeader ~= true and info.isHidden ~= true then
                local watchType = type(C_QuestLog.GetQuestWatchType) == "function"
                    and SafeCall(C_QuestLog.GetQuestWatchType, questID)
                    or nil
                local isTracked = watchType ~= nil or superTrackedQuestID == questID
                local isCampaign = IsCampaignQuest(questID)
                local isReadyForTurnIn = IsQuestReadyForTurnIn(questID)
                local isAutoComplete = IsQuestAutoComplete(questID, info)
                if isTracked or isCampaign or isReadyForTurnIn or isAutoComplete or instance then
                    seen[questID] = true
                    target[#target + 1] = questID
                end
            end
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
    local zoneTypeThreshold = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3

    local function AddMap(mapID)
        if type(mapID) == "number" and mapID > 0 and not seen[mapID] then
            seen[mapID] = true
            queryList[#queryList + 1] = mapID
        end
    end

    AddMap(currentMapID)

    local info = GetMapInfoSafe(currentMapID)
    while type(info) == "table" and type(info.parentMapID) == "number" and info.parentMapID > 0 do
        local parentInfo = GetMapInfoSafe(info.parentMapID)
        local parentMapType = parentInfo and tonumber(parentInfo.mapType) or nil
        if parentMapType and parentMapType < zoneTypeThreshold then
            break
        end

        AddMap(info.parentMapID)
        info = parentInfo
    end

    return queryList
end

local function GetInstanceCollapseContextKey()
    local instance = GetCurrentInstanceContext()
    if not instance or (instance.instanceType ~= "party" and instance.instanceType ~= "raid") then
        return nil
    end

    return string_format("%s:%s:%s", SafeDebugString(instance.instanceType), SafeDebugString(instance.name),
        SafeDebugString(instance.difficultyID))
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
    if entry.isCampaignQuest then
        parts[#parts + 1] = "Campaign"
    end

    if IsEntryInCurrentArea(entry) then
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

    if entry.isReadyForTurnIn then
        parts[#parts + 1] = "Ready to Turn In"
    end

    if entry.isAutoComplete then
        parts[#parts + 1] = "Click to Complete"
    end

    local timeText = FormatTimeRemaining(entry.timeLeftSeconds)
    if timeText then
        parts[#parts + 1] = timeText .. " left"
    end

    return table.concat(parts, "  •  ")
end

local function NormalizeInstanceSearchKey(value)
    local normalized = type(value) == "string" and string.lower(value) or ""
    normalized = normalized:gsub("['`%-]", "")
    normalized = normalized:gsub("[^%w]", "")
    return normalized
end

GetCurrentInstanceContext = function()
    if type(IsInInstance) ~= "function" or type(GetInstanceInfo) ~= "function" then
        return nil
    end

    if SafeCall(IsInInstance) ~= true then
        return nil
    end

    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID, _, lfgDungeonID = SafeCall(GetInstanceInfo)
    if instanceType ~= "party" and instanceType ~= "raid" then
        return nil
    end

    return {
        name = type(name) == "string" and name ~= "" and name or (instanceType == "raid" and "Raid" or "Dungeon"),
        instanceType = instanceType,
        difficultyID = tonumber(difficultyID) or 0,
        difficultyName = type(difficultyName) == "string" and difficultyName or "",
        mapID = tonumber(mapID) or nil,
        lfgDungeonID = tonumber(lfgDungeonID) or nil,
        isRaid = instanceType == "raid",
        isKeystone = type(C_ChallengeMode) == "table"
            and type(C_ChallengeMode.IsChallengeModeActive) == "function"
            and SafeCall(C_ChallengeMode.IsChallengeModeActive) == true,
    }
end

local function RequestInstanceLockoutInfo(force)
    if type(RequestRaidInfo) ~= "function" then
        return
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    ObjectiveTracker.lastRaidInfoRequestAt = ObjectiveTracker.lastRaidInfoRequestAt or 0
    if not force and (now - ObjectiveTracker.lastRaidInfoRequestAt) < 2 then
        return
    end

    ObjectiveTracker.lastRaidInfoRequestAt = now
    SafeCall(RequestRaidInfo)
end

local function GetSavedInstanceCandidates(instance)
    if type(instance) ~= "table"
        or type(GetNumSavedInstances) ~= "function"
        or type(GetSavedInstanceInfo) ~= "function"
    then
        return {}, nil, nil, 0
    end

    local candidates = {}
    local exactMatch = nil
    local partialMatch = nil
    local targetKey = NormalizeInstanceSearchKey(instance.name)
    local totalSaved = tonumber(SafeCall(GetNumSavedInstances)) or 0

    for index = 1, totalSaved do
        local name, _, reset, difficultyID, locked, extended, _, isRaid, _, difficultyName, numEncounters, numCompleted =
            SafeCall(
                GetSavedInstanceInfo, index)
        local normalizedName = type(name) == "string" and NormalizeInstanceSearchKey(name) or ""
        local matchesType = isRaid == instance.isRaid
        local isExact = normalizedName ~= "" and normalizedName == targetKey
        local isPartial = normalizedName ~= "" and targetKey ~= ""
            and (normalizedName:find(targetKey, 1, true) or targetKey:find(normalizedName, 1, true))

        if type(name) == "string" and matchesType and (isExact or isPartial) then
            local candidate = {
                index = index,
                name = name,
                reset = reset,
                difficultyID = tonumber(difficultyID) or 0,
                difficultyName = type(difficultyName) == "string" and difficultyName or "",
                locked = locked == true,
                extended = extended == true,
                numEncounters = tonumber(numEncounters) or 0,
                numCompleted = tonumber(numCompleted) or 0,
            }

            table_insert(candidates, candidate)
            if isExact and candidate.difficultyID == instance.difficultyID then
                exactMatch = exactMatch or candidate
            end
            if partialMatch == nil then
                partialMatch = candidate
            elseif partialMatch.difficultyID ~= instance.difficultyID and candidate.difficultyID == instance.difficultyID then
                partialMatch = candidate
            elseif (tonumber(candidate.numCompleted) or 0) > (tonumber(partialMatch.numCompleted) or 0) then
                partialMatch = candidate
            end
        end
    end

    return candidates, exactMatch, partialMatch, totalSaved
end

local function GetSavedInstanceProgress(instance)
    if type(instance) ~= "table"
        or type(GetNumSavedInstances) ~= "function"
        or type(GetSavedInstanceInfo) ~= "function"
    then
        return nil
    end

    local _, exactMatch, partialMatch = GetSavedInstanceCandidates(instance)
    local chosen = exactMatch or partialMatch
    if not chosen then
        return nil
    end

    local encounters = {}
    if type(GetSavedInstanceEncounterInfo) == "function" and chosen.numEncounters > 0 then
        for encounterIndex = 1, chosen.numEncounters do
            local encounterName, _, isKilled = SafeCall(GetSavedInstanceEncounterInfo, chosen.index, encounterIndex)
            if type(encounterName) == "string" and encounterName ~= "" then
                encounters[#encounters + 1] = {
                    name = encounterName,
                    isCompleted = isKilled == true,
                }
            end
        end
    end

    return {
        numEncounters = chosen.numEncounters,
        numCompleted = chosen.numCompleted,
        encounters = encounters,
    }
end

local function GetLFGEncounterProgress(lfgDungeonID)
    if type(lfgDungeonID) ~= "number"
        or lfgDungeonID <= 0
        or type(GetLFGDungeonNumEncounters) ~= "function"
    then
        return nil
    end

    local numEncounters, numCompleted = SafeCall(GetLFGDungeonNumEncounters, lfgDungeonID)
    if type(numEncounters) ~= "number" or numEncounters <= 0 then
        return nil
    end

    local encounters = {}
    if type(GetLFGDungeonEncounterInfo) == "function" then
        for encounterIndex = 1, numEncounters do
            local encounterName, _, isCompleted = SafeCall(GetLFGDungeonEncounterInfo, lfgDungeonID, encounterIndex)
            if type(encounterName) == "string" and encounterName ~= "" then
                encounters[#encounters + 1] = {
                    name = encounterName,
                    isCompleted = isCompleted == true,
                }
            end
        end
    end

    return {
        numEncounters = numEncounters,
        numCompleted = tonumber(numCompleted) or 0,
        encounters = encounters,
    }
end

local function GetEncounterJournalFunctions()
    local isLoaded = (type(C_AddOns) == "table"
            and type(C_AddOns.IsAddOnLoaded) == "function"
            and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal"))
        or (type(IsAddOnLoaded) == "function" and IsAddOnLoaded("Blizzard_EncounterJournal"))

    if not isLoaded and type(LoadAddOn) == "function" then
        pcall(LoadAddOn, "Blizzard_EncounterJournal")
    end

    if type(_G.EJ_SelectTier) ~= "function"
        or type(_G.EJ_GetCurrentTier) ~= "function"
        or type(_G.EJ_GetNumTiers) ~= "function"
        or type(_G.EJ_GetInstanceByIndex) ~= "function"
        or type(_G.EJ_SelectInstance) ~= "function"
        or type(_G.EJ_GetEncounterInfoByIndex) ~= "function"
    then
        return nil
    end

    return {
        selectTier = _G.EJ_SelectTier,
        getCurrentTier = _G.EJ_GetCurrentTier,
        getNumTiers = _G.EJ_GetNumTiers,
        getInstanceByIndex = _G.EJ_GetInstanceByIndex,
        selectInstance = _G.EJ_SelectInstance,
        getEncounterInfoByIndex = _G.EJ_GetEncounterInfoByIndex,
    }
end

local function SafeEncounterJournalSelectTier(ej, tierIndex)
    if not ej or type(ej.selectTier) ~= "function" then
        return false
    end

    local numericTier = tonumber(tierIndex)
    if not numericTier or numericTier <= 0 then
        return false
    end

    return pcall(ej.selectTier, numericTier) == true
end

local function FindBestEncounterJournalInstance(mapID, mapName, expectRaid)
    local ej = GetEncounterJournalFunctions()
    if not ej then
        return nil
    end

    local searchKey = NormalizeInstanceSearchKey(mapName)
    if searchKey == "" then
        return nil
    end

    local exactMatch = nil
    local partialMatch = nil
    local previousTier = ej.getCurrentTier()
    local tierCount = tonumber(ej.getNumTiers()) or 0

    for tierIndex = 1, tierCount do
        if not SafeEncounterJournalSelectTier(ej, tierIndex) then
            break
        end

        for _, isRaid in ipairs({ expectRaid == true, expectRaid ~= true }) do
            local instanceIndex = 1
            while true do
                local instanceID, instanceName = ej.getInstanceByIndex(instanceIndex, isRaid)
                if not instanceID then
                    break
                end

                local instanceKey = NormalizeInstanceSearchKey(instanceName)
                if instanceKey == searchKey then
                    exactMatch = { tier = tierIndex, id = instanceID, name = instanceName, isRaid = isRaid }
                    break
                elseif partialMatch == nil and instanceKey ~= "" and
                    (instanceKey:find(searchKey, 1, true) or searchKey:find(instanceKey, 1, true)) then
                    partialMatch = { tier = tierIndex, id = instanceID, name = instanceName, isRaid = isRaid }
                end

                instanceIndex = instanceIndex + 1
            end

            if exactMatch then
                break
            end
        end

        if exactMatch then
            break
        end
    end

    if previousTier then
        SafeEncounterJournalSelectTier(ej, previousTier)
    end

    return exactMatch or partialMatch
end

local function GetEncounterJournalProgress(instance)
    if type(instance) ~= "table" then
        return nil
    end

    local instanceInfo = FindBestEncounterJournalInstance(instance.mapID, instance.name, instance.isRaid)
    local ej = GetEncounterJournalFunctions()
    if not instanceInfo or not ej then
        return nil
    end

    local encounters = {}
    local previousTier = ej.getCurrentTier()
    if SafeEncounterJournalSelectTier(ej, instanceInfo.tier) and pcall(ej.selectInstance, instanceInfo.id) then
        local encounterIndex = 1
        while true do
            pcall(ej.selectInstance, instanceInfo.id)
            local encounterName = ej.getEncounterInfoByIndex(encounterIndex)
            if not encounterName then
                break
            end

            encounters[#encounters + 1] = {
                name = encounterName,
                isCompleted = false,
            }
            encounterIndex = encounterIndex + 1
        end
    end

    if previousTier then
        SafeEncounterJournalSelectTier(ej, previousTier)
    end

    if #encounters == 0 then
        return nil
    end

    return {
        numEncounters = #encounters,
        numCompleted = 0,
        encounters = encounters,
    }
end

local function MergeEncounterProgress(primary, overlay)
    if type(primary) ~= "table" then
        return overlay
    end
    if type(overlay) ~= "table" then
        return primary
    end

    local merged = {
        numEncounters = tonumber(primary.numEncounters) or tonumber(overlay.numEncounters) or 0,
        numCompleted = tonumber(primary.numCompleted) or 0,
        encounters = {},
    }

    local overlayByKey = {}
    for index, encounter in ipairs(overlay.encounters or {}) do
        local key = NormalizeInstanceSearchKey(encounter.name)
        if key ~= "" then
            overlayByKey[key] = encounter
        end
        overlayByKey["#" .. tostring(index)] = encounter
    end

    for index, encounter in ipairs(primary.encounters or {}) do
        local key = NormalizeInstanceSearchKey(encounter.name)
        local match = overlayByKey[key] or overlayByKey["#" .. tostring(index)]
        local isCompleted = (match and match.isCompleted == true) or encounter.isCompleted == true
        merged.encounters[#merged.encounters + 1] = {
            name = encounter.name,
            isCompleted = isCompleted,
        }
        if isCompleted then
            merged.numCompleted = merged.numCompleted + 1
        end
    end

    if #merged.encounters == 0 then
        merged.encounters = overlay.encounters or {}
        merged.numCompleted = tonumber(overlay.numCompleted) or 0
    end

    merged.numCompleted = math_max(merged.numCompleted, tonumber(overlay.numCompleted) or 0)

    if merged.numEncounters <= 0 then
        merged.numEncounters = #merged.encounters
    end

    return merged
end

local function BuildInstanceMetaText(instance, progress)
    local parts = {}
    parts[#parts + 1] = instance.isKeystone and "Mythic+" or (instance.isRaid and "Raid" or "Dungeon")

    if type(instance.difficultyName) == "string" and instance.difficultyName ~= "" then
        parts[#parts + 1] = instance.difficultyName
    end

    if type(progress) == "table" and tonumber(progress.numEncounters) and progress.numEncounters > 0 then
        parts[#parts + 1] = string_format("%d/%d encounters", tonumber(progress.numCompleted) or 0,
            tonumber(progress.numEncounters) or 0)
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

function ObjectiveTracker:IsQuestSuppressed(questID)
    return type(questID) == "number"
        and type(self.suppressedQuestIDs) == "table"
        and self.suppressedQuestIDs[questID] == true
end

function ObjectiveTracker:SetQuestSuppressed(questID, suppressed)
    if type(questID) ~= "number" then
        return
    end

    if type(self.suppressedQuestIDs) ~= "table" then
        self.suppressedQuestIDs = {}
    end

    if suppressed == true then
        self.suppressedQuestIDs[questID] = true
    else
        self.suppressedQuestIDs[questID] = nil
    end
end

function ObjectiveTracker:ShouldHideSuppressedQuest(entry)
    if type(entry) ~= "table" or type(entry.questID) ~= "number" then
        return false
    end

    if not self:IsQuestSuppressed(entry.questID) then
        return false
    end

    if entry.isAutoComplete == true then
        return false
    end

    if entry.isSuperTracked == true then
        self:SetQuestSuppressed(entry.questID, false)
        return false
    end

    if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestWatchType) == "function" then
        local watchType = SafeCall(C_QuestLog.GetQuestWatchType, entry.questID)
        if watchType ~= nil then
            self:SetQuestSuppressed(entry.questID, false)
            return false
        end
    end

    return true
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
    frame.ProgressBars = {}
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

function ObjectiveTracker:GetObjectiveProgressBar(entryFrame, index)
    entryFrame.ProgressBars = entryFrame.ProgressBars or {}
    if entryFrame.ProgressBars[index] then
        return entryFrame.ProgressBars[index]
    end

    local bar = CreateFrame("StatusBar", nil, entryFrame)
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    bar:SetStatusBarTexture(ResolveStatusBarTexturePath())

    bar.Background = bar:CreateTexture(nil, "BACKGROUND")
    bar.Background:SetAllPoints()
    bar.Background:SetColorTexture(0.10, 0.12, 0.15, 0.85)

    bar.Border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    bar.Border:SetAllPoints()
    bar.Border:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    bar.Border:SetBackdropBorderColor(0, 0, 0, 0.35)

    bar.Label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Label:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.Label:SetJustifyH("CENTER")
    bar.Label:SetJustifyV("MIDDLE")

    entryFrame.ProgressBars[index] = bar
    return bar
end

local function BuildInstanceDebugSnapshotData()
    local instance = GetCurrentInstanceContext()
    if not instance then
        return {
            inInstance = false,
            reason = "No party or raid instance context detected.",
        }
    end

    local savedCandidates, exactSaved, partialSaved, totalSavedInstances = GetSavedInstanceCandidates(instance)
    local journal = GetEncounterJournalProgress(instance)
    local lfg = GetLFGEncounterProgress(instance.lfgDungeonID)
    local saved = GetSavedInstanceProgress(instance)
    local merged = MergeEncounterProgress(journal, lfg)
    merged = MergeEncounterProgress(merged, saved)

    return {
        inInstance = true,
        instance = instance,
        savedCandidates = savedCandidates,
        exactSaved = exactSaved,
        partialSaved = partialSaved,
        totalSavedInstances = totalSavedInstances,
        journal = journal,
        lfg = lfg,
        saved = saved,
        merged = merged,
        requestAge = type(GetTime) == "function" and ((GetTime() or 0) - (ObjectiveTracker.lastRaidInfoRequestAt or 0)) or
            nil,
    }
end

local function BuildProgressSummary(progress)
    if type(progress) ~= "table" then
        return "nil"
    end

    return string_format("%d/%d encounters, %d rows", tonumber(progress.numCompleted) or 0,
        tonumber(progress.numEncounters) or 0, #(progress.encounters or {}))
end

local function BuildCandidateSummary(candidate)
    if type(candidate) ~= "table" then
        return "nil"
    end

    return string_format("index=%s difficulty=%s (%s) completed=%d/%d locked=%s extended=%s reset=%s",
        SafeDebugString(candidate.index), SafeDebugString(candidate.difficultyID),
        SafeDebugString(candidate.difficultyName ~= "" and candidate.difficultyName or "unknown"),
        tonumber(candidate.numCompleted) or 0, tonumber(candidate.numEncounters) or 0,
        SafeDebugString(candidate.locked), SafeDebugString(candidate.extended), SafeDebugString(candidate.reset))
end

local function BuildEncounterLines(label, progress)
    local lines = {}
    if type(progress) ~= "table" then
        lines[#lines + 1] = string_format("%s encounters: nil", label)
        return lines
    end

    lines[#lines + 1] = string_format("%s encounters: %s", label, BuildProgressSummary(progress))
    for index, encounter in ipairs(progress.encounters or {}) do
        lines[#lines + 1] = string_format("  %02d. [%s] %s", index,
            encounter.isCompleted == true and "x" or " ", SafeDebugString(encounter.name))
    end

    return lines
end

local function EmitInstanceDebugSnapshot(shouldShow, contextLabel)
    local data = BuildInstanceDebugSnapshotData()
    ObjectiveTracker.lastInstanceDebugSnapshot = data

    LogDebug(
        string_format("----- Objective Tracker Instance Snapshot (%s) -----", SafeDebugString(contextLabel or "manual")),
        shouldShow)

    if data.inInstance ~= true then
        LogDebug(data.reason or "No instance context available.", false)
        return data
    end

    local instance = data.instance or {}
    LogDebugf(false,
        "instance name=%s type=%s difficultyID=%s difficulty=%s mapID=%s lfgDungeonID=%s raid=%s keystone=%s",
        SafeDebugString(instance.name), SafeDebugString(instance.instanceType), SafeDebugString(instance.difficultyID),
        SafeDebugString(instance.difficultyName), SafeDebugString(instance.mapID), SafeDebugString(instance.lfgDungeonID),
        SafeDebugString(instance.isRaid), SafeDebugString(instance.isKeystone))
    LogDebugf(false, "saved total=%s candidates=%d exact=%s partial=%s lastRaidInfoRequestAge=%s",
        SafeDebugString(data.totalSavedInstances), #(data.savedCandidates or {}), BuildCandidateSummary(data.exactSaved),
        BuildCandidateSummary(data.partialSaved), data.requestAge and string_format("%.2fs", data.requestAge) or "nil")

    for index, candidate in ipairs(data.savedCandidates or {}) do
        LogDebugf(false, "saved[%d] %s", index, BuildCandidateSummary(candidate))
    end

    if #(data.savedCandidates or {}) == 0 and type(GetNumSavedInstances) == "function" and type(GetSavedInstanceInfo) == "function" then
        local totalSaved = tonumber(SafeCall(GetNumSavedInstances)) or 0
        for index = 1, totalSaved do
            local name, _, reset, difficultyID, locked, extended, _, isRaid, _, difficultyName, numEncounters, numCompleted =
                SafeCall(
                    GetSavedInstanceInfo, index)
            LogDebugf(false,
                "saved-all[%d] name=%s difficultyID=%s difficulty=%s raid=%s completed=%s/%s locked=%s extended=%s reset=%s",
                index, SafeDebugString(name), SafeDebugString(difficultyID), SafeDebugString(difficultyName),
                SafeDebugString(isRaid), SafeDebugString(numCompleted), SafeDebugString(numEncounters),
                SafeDebugString(locked), SafeDebugString(extended), SafeDebugString(reset))
        end
    end

    LogDebugf(false, "journal=%s | lfg=%s | saved=%s | merged=%s",
        BuildProgressSummary(data.journal), BuildProgressSummary(data.lfg), BuildProgressSummary(data.saved),
        BuildProgressSummary(data.merged))

    for _, line in ipairs(BuildEncounterLines("journal", data.journal)) do
        LogDebug(line, false)
    end
    for _, line in ipairs(BuildEncounterLines("lfg", data.lfg)) do
        LogDebug(line, false)
    end
    for _, line in ipairs(BuildEncounterLines("saved", data.saved)) do
        LogDebug(line, false)
    end
    for _, line in ipairs(BuildEncounterLines("merged", data.merged)) do
        LogDebug(line, false)
    end

    local console = GetDebugConsole()
    if shouldShow and console and type(console.Show) == "function" then
        console:Show(DEBUG_SOURCE_KEY)
    end

    return data
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
        return nil
    end

    local rawText = StripColorCodes(objective.text or objective.description)
    if type(rawText) ~= "string" or rawText == "" then
        return nil
    end

    local objectiveEntry = {
        text = "• " .. rawText,
        rawText = rawText,
        isComplete = self:IsQuestObjectiveComplete(objective),
    }

    objectiveEntry.progress = BuildObjectiveProgress(objective, rawText)
    return objectiveEntry
end

function ObjectiveTracker:BuildQuestEntry(questID, currentMapID)
    local info = GetQuestInfoByID(questID)
    if type(info) ~= "table" or info.isHeader == true or info.isHidden == true then
        return nil
    end

    local mapID = GetQuestMapID(questID)
    local isCurrentZone = IsCurrentZoneMap(mapID, currentMapID)
    local isWorld = IsWorldQuest(questID)
    local isAccepted = IsQuestAccepted(questID)
    local isTaskActive = IsTaskQuestActive(questID)
    local isCampaign = isWorld ~= true and IsCampaignQuest(questID)
    local isReadyForTurnIn = IsQuestReadyForTurnIn(questID)
    local isAutoComplete = IsQuestAutoComplete(questID, info)
    local isStrictCurrentMap = isWorld == true and IsQuestStrictlyOnCurrentMap(questID, currentMapID) or false
    local isOnMap = type(C_QuestLog) == "table" and type(C_QuestLog.IsOnMap) == "function"
        and SafeCall(C_QuestLog.IsOnMap, questID) == true

    if isWorld ~= true and isAccepted ~= true and isTaskActive ~= true then
        return nil
    end

    local isComplete = info.isComplete == true or IsQuestComplete(questID) == true or isReadyForTurnIn == true
    local tagName = GetQuestTagName(questID)

    local sectionKey = "quests"
    if isAutoComplete and isComplete then
        sectionKey = "completeNow"
    elseif isCampaign then
        sectionKey = "campaign"
    elseif isWorld then
        sectionKey = "world"
    elseif isComplete then
        sectionKey = "completed"
    elseif isCurrentZone or isOnMap then
        sectionKey = "currentZone"
    end

    local entry = {
        signature = string_format("quest:%d:%s:%s:%s:%s:%s", questID, tostring(isComplete), tostring(isCurrentZone),
            tostring(isCampaign), tostring(isReadyForTurnIn), tostring(isAutoComplete)),
        type = "quest",
        questID = questID,
        title = info.title or GetQuestTitle(questID),
        zoneName = GetQuestZoneName(questID, mapID),
        mapID = mapID,
        x = nil,
        y = nil,
        isCurrentZone = isCurrentZone,
        isWorldQuest = isWorld,
        isCampaignQuest = isCampaign,
        isComplete = isComplete,
        isReadyForTurnIn = isReadyForTurnIn,
        isAutoComplete = isAutoComplete,
        isStrictCurrentMap = isStrictCurrentMap,
        isOnMap = isOnMap,
        isCurrentTaskMap = false,
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
                local objectiveEntry = self:BuildQuestObjectiveText(objective)
                if objectiveEntry then
                    table_insert(entry.objectives, objectiveEntry)
                end
            end
        end
    end

    entry.metaText = BuildEntryMetaText(entry)
    return entry
end

function ObjectiveTracker:ApplyInstanceQuestContext(entry)
    if type(entry) ~= "table" or entry.type ~= "quest" or entry.isWorldQuest == true or entry.isCampaignQuest == true then
        return entry
    end

    local instance = GetCurrentInstanceContext()
    if not instance then
        return entry
    end

    entry.isCurrentZone = true
    if entry.isComplete ~= true then
        entry.sectionKey = "currentZone"
    end
    entry.metaText = BuildEntryMetaText(entry)
    return entry
end

function ObjectiveTracker:ShouldIncludeQuestEntryInContext(entry, currentMapID)
    if type(entry) ~= "table" then
        return false
    end

    if entry.isAutoComplete == true and entry.isComplete == true then
        return true
    end

    if entry.isWorldQuest == true then
        if entry.isReadyForTurnIn == true or entry.isSuperTracked == true then
            return true
        end

        if entry.isCurrentTaskMap == true and entry.isStrictCurrentMap == true then
            return true
        end

        return false
    end

    return true
end

function ObjectiveTracker:EnsureAutomaticSectionCollapseState()
    local contextKey = GetInstanceCollapseContextKey()
    if not contextKey then
        self.runtimeSectionCollapsed = nil
        self.runtimeSectionCollapseContextKey = nil
        return
    end

    if self.runtimeSectionCollapseContextKey == contextKey and type(self.runtimeSectionCollapsed) == "table" then
        return
    end

    self.runtimeSectionCollapseContextKey = contextKey
    self.runtimeSectionCollapsed = {}
    for _, sectionKey in ipairs(SECTION_ORDER) do
        self.runtimeSectionCollapsed[sectionKey] = sectionKey ~= "instance"
    end
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

    local objectiveSignatures = {}

    if type(C_ScenarioInfo) == "table" and type(C_ScenarioInfo.GetCriteriaInfo) == "function" then
        for index = 1, math_max(numCriteria, MAX_SCENARIO_CRITERIA) do
            local info = SafeCall(C_ScenarioInfo.GetCriteriaInfo, index)
            if type(info) == "table" and type(info.description) == "string" and info.description ~= "" then
                local cleanText = StripColorCodes(info.description)
                local objectiveEntry = {
                    text = "• " .. cleanText,
                    rawText = cleanText,
                    isComplete = info.completed == true,
                    progress = BuildObjectiveProgress(info, cleanText),
                }
                local signature = NormalizeObjectiveSignature(cleanText,
                    objectiveEntry.progress and objectiveEntry.progress.value or nil,
                    objectiveEntry.progress and objectiveEntry.progress.maxValue or nil,
                    objectiveEntry.progress and objectiveEntry.progress.percent or nil)
                objectiveSignatures[signature] = true
                table_insert(entry.objectives, objectiveEntry)
            end
        end
    end

    local widgetObjectives = GetScenarioWidgetObjectives(GetScenarioWidgetSetID())
    if type(widgetObjectives) == "table" then
        for _, widgetObjective in ipairs(widgetObjectives) do
            local cleanText = StripColorCodes(widgetObjective.description or widgetObjective.text)
            if cleanText then
                local progress = BuildObjectiveProgress(widgetObjective, cleanText)
                local signature = NormalizeObjectiveSignature(cleanText,
                    progress and progress.value or nil,
                    progress and progress.maxValue or nil,
                    progress and progress.percent or nil)
                if objectiveSignatures[signature] ~= true then
                    objectiveSignatures[signature] = true
                    table_insert(entry.objectives, {
                        text = "• " .. cleanText,
                        rawText = cleanText,
                        isComplete = widgetObjective.completed == true,
                        progress = progress,
                    })
                end
            end
        end
    end

    if #entry.objectives == 0 then
        return nil
    end

    return entry
end

function ObjectiveTracker:BuildInstanceEntry()
    local options = GetOptions()
    if not options or not options.GetShowInstanceSection or not options:GetShowInstanceSection() then
        return nil
    end

    local instance = GetCurrentInstanceContext()
    if not instance then
        return nil
    end

    local progress = GetEncounterJournalProgress(instance)
    progress = MergeEncounterProgress(progress, GetLFGEncounterProgress(instance.lfgDungeonID))
    progress = MergeEncounterProgress(progress, GetSavedInstanceProgress(instance))

    local entry = {
        signature = string_format("instance:%s:%s:%s:%s", tostring(instance.name), tostring(instance.difficultyID),
            tostring(progress and progress.numCompleted or 0), tostring(progress and progress.numEncounters or 0)),
        type = "instance",
        title = instance.name,
        sectionKey = "instance",
        isScenario = false,
        isCurrentZone = true,
        isWorldQuest = false,
        isComplete = false,
        isSuperTracked = false,
        objectives = {},
        mapID = instance.mapID,
        metaText = BuildInstanceMetaText(instance, progress),
    }

    if options:GetShowQuestObjectives() and type(progress) == "table" then
        for _, encounter in ipairs(progress.encounters or {}) do
            if type(encounter.name) == "string" and encounter.name ~= "" then
                table_insert(entry.objectives, {
                    text = "• " .. encounter.name,
                    isComplete = encounter.isCompleted == true,
                })
            end
        end
    end

    return entry
end

function ObjectiveTracker:GetDebugSummaryLine()
    local snapshot = self.lastInstanceDebugSnapshot or BuildInstanceDebugSnapshotData()
    if type(snapshot) ~= "table" or snapshot.inInstance ~= true then
        return "|cffff9a6cObjective tracker: no active raid or dungeon context.|r"
    end

    local instance = snapshot.instance or {}
    local merged = snapshot.merged
    local saved = snapshot.saved
    return string_format(
        "|cff69b86f%s|r  |  merged: |cff9ad1ff%s|r  |  saved: |cffd8c27a%s|r  |  candidates: |cffd8c27a%d|r",
        SafeDebugString(instance.name or "Instance"), BuildProgressSummary(merged), BuildProgressSummary(saved),
        #(snapshot.savedCandidates or {}))
end

function ObjectiveTracker:CaptureDebugSnapshot(shouldShow)
    RequestInstanceLockoutInfo(true)
    EmitInstanceDebugSnapshot(shouldShow == true, "manual-immediate")

    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1.0, function()
            if ObjectiveTracker and ObjectiveTracker:IsEnabled() then
                EmitInstanceDebugSnapshot(false, "manual-follow-up")
            end
        end)
    end
end

function ObjectiveTracker:CollectEntries()
    local entries = {}
    local currentMapID = GetCurrentMapID()
    local seenQuestIDs = {}
    local questLogQuestIDs = {}

    local instanceEntry = self:BuildInstanceEntry()
    if instanceEntry then
        table_insert(entries, instanceEntry)
    end

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
                entry = self:ApplyInstanceQuestContext(entry)
                if entry
                    and not self:ShouldHideSuppressedQuest(entry)
                    and self:ShouldIncludeQuestEntryInContext(entry, currentMapID)
                then
                    table_insert(entries, entry)
                end
            end
        end
    end

    AppendQuestLogIDs(questLogQuestIDs, seenQuestIDs, currentMapID)
    for _, questID in ipairs(questLogQuestIDs) do
        local entry = self:BuildQuestEntry(questID, currentMapID)
        entry = self:ApplyInstanceQuestContext(entry)
        if entry
            and not self:ShouldHideSuppressedQuest(entry)
            and self:ShouldIncludeQuestEntryInContext(entry, currentMapID)
        then
            table_insert(entries, entry)
        end
    end

    local queryMaps = BuildMapQueryList(currentMapID)
    local taskQuestIDs = {}
    local taskQuestSources = {}
    for _, mapID in ipairs(queryMaps) do
        local questList = GetTaskQuestsForMap(mapID)
        if type(questList) == "table" then
            for _, info in pairs(questList) do
                local questID = GetQuestListEntryID(info)
                if type(questID) == "number" and questID > 0 then
                    local source = taskQuestSources[questID]
                    if not source then
                        source = {
                            onCurrentMap = false,
                            onRelatedMap = false,
                        }
                        taskQuestSources[questID] = source
                    end

                    if mapID == currentMapID then
                        source.onCurrentMap = true
                    else
                        source.onRelatedMap = true
                    end

                    if not seenQuestIDs[questID] then
                        seenQuestIDs[questID] = true
                        taskQuestIDs[#taskQuestIDs + 1] = questID
                    end
                end
            end
        end
    end

    for _, questID in ipairs(taskQuestIDs) do
        local entry = self:BuildQuestEntry(questID, currentMapID)
        local taskSource = taskQuestSources[questID]
        if entry and type(taskSource) == "table" then
            entry.isCurrentTaskMap = taskSource.onCurrentMap == true
        end
        if entry
            and not self:ShouldHideSuppressedQuest(entry)
            and self:ShouldIncludeQuestEntryInContext(entry, currentMapID)
            and (entry.isWorldQuest == true or entry.isReadyForTurnIn == true or entry.isAutoComplete == true)
        then
            table_insert(entries, entry)
        end
    end

    local scenarioEntry = self:BuildScenarioEntry()
    if scenarioEntry then
        table_insert(entries, instanceEntry and 2 or 1, scenarioEntry)
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

        if not (zoneMode == "current"
                and effectiveSectionKey ~= "scenario"
                and effectiveSectionKey ~= "completeNow"
                and effectiveSectionKey ~= "campaign"
                and effectiveSectionKey ~= "completed"
                and IsEntryInCurrentArea(entry) ~= true)
        then
            if not (entry.isComplete
                    and entry.isAutoComplete ~= true
                    and options
                    and options.GetShowCompletedQuests
                    and options:GetShowCompletedQuests() ~= true)
            then
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
            if a.isAutoComplete ~= b.isAutoComplete then
                return a.isAutoComplete == true
            end
            if a.isReadyForTurnIn ~= b.isReadyForTurnIn then
                return a.isReadyForTurnIn == true
            end
            if a.isSuperTracked ~= b.isSuperTracked then
                return a.isSuperTracked == true
            end
            if a.isCampaignQuest ~= b.isCampaignQuest then
                return a.isCampaignQuest == true
            end
            local aIsCurrentArea = IsEntryInCurrentArea(a)
            local bIsCurrentArea = IsEntryInCurrentArea(b)
            if aIsCurrentArea ~= bIsCurrentArea then
                return aIsCurrentArea == true
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

    if type(entry.questID) == "number" then
        self:SetQuestSuppressed(entry.questID, false)
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

    self:SetQuestSuppressed(entry.questID, true)

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

function ObjectiveTracker:CanAbandonEntry(entry)
    if type(entry) ~= "table" or type(entry.questID) ~= "number" or type(C_QuestLog) ~= "table" then
        return false
    end

    if type(C_QuestLog.GetLogIndexForQuestID) == "function" then
        local logIndex = SafeCall(C_QuestLog.GetLogIndexForQuestID, entry.questID)
        if type(logIndex) ~= "number" or logIndex <= 0 then
            return false
        end
    end

    if type(C_QuestLog.CanAbandonQuest) == "function" then
        return SafeCall(C_QuestLog.CanAbandonQuest, entry.questID) == true
    end

    return type(C_QuestLog.AbandonQuest) == "function"
end

function ObjectiveTracker:AbandonEntry(entry)
    if not self:CanAbandonEntry(entry) or type(StaticPopup_Show) ~= "function" or type(StaticPopupDialogs) ~= "table" then
        return
    end

    StaticPopupDialogs[ABANDON_POPUP_KEY] = StaticPopupDialogs[ABANDON_POPUP_KEY] or {
        text = "Abandon %s?",
        button1 = YES,
        button2 = NO,
        OnAccept = function(popup)
            local popupEntry = popup and popup.data or nil
            if not popupEntry or type(popupEntry.questID) ~= "number" or type(C_QuestLog) ~= "table" then
                return
            end

            if type(C_QuestLog.SetSelectedQuest) == "function" then
                SafeCall(C_QuestLog.SetSelectedQuest, popupEntry.questID)
            end
            if type(C_QuestLog.SetAbandonQuest) == "function" then
                SafeCall(C_QuestLog.SetAbandonQuest)
            end
            if type(C_QuestLog.AbandonQuest) == "function" then
                SafeCall(C_QuestLog.AbandonQuest)
            end

            ObjectiveTracker:SetQuestSuppressed(popupEntry.questID, false)
            ObjectiveTracker:ScheduleRefresh("abandon")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopup_Show(ABANDON_POPUP_KEY, entry.title or "this quest", nil, entry)
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
            text = "Abandon Quest",
            disabled = ObjectiveTracker:CanAbandonEntry(entry) ~= true,
            func = function()
                ObjectiveTracker:AbandonEntry(entry)
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
        elseif entry.isAutoComplete == true and entry.isComplete == true and type(ShowQuestComplete) == "function" then
            if type(C_QuestLog) == "table" and type(C_QuestLog.SetSelectedQuest) == "function" then
                SafeCall(C_QuestLog.SetSelectedQuest, entry.questID)
            end
            SafeCall(ShowQuestComplete, entry.questID)
            self:ScheduleRefresh("quest-complete-click")
        else
            self:SuperTrackEntry(entry)
        end
    end
end

function ObjectiveTracker:IsSectionCollapsed(sectionKey)
    self:EnsureAutomaticSectionCollapseState()

    local runtimeState = self.runtimeSectionCollapsed
    if type(runtimeState) == "table" and runtimeState[sectionKey] ~= nil then
        return runtimeState[sectionKey] == true
    end

    local options = GetOptions()
    return options and type(options.GetSectionCollapsed) == "function" and
        options:GetSectionCollapsed(sectionKey) == true
end

function ObjectiveTracker:ToggleSectionCollapsed(sectionKey)
    self:EnsureAutomaticSectionCollapseState()

    local runtimeState = self.runtimeSectionCollapsed
    if type(runtimeState) == "table" and runtimeState[sectionKey] ~= nil then
        runtimeState[sectionKey] = not (runtimeState[sectionKey] == true)
        self:ScheduleRefresh("sectionCollapsed")
        return
    end

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
    local progressBarTexture = ResolveStatusBarTexturePath()
    local progressTextSize = math_max(8, options:GetMetaFontSize() - 1)
    local progressBarHeight = math_max(10, progressTextSize + 5)

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
    elseif entry.type == "quest" or entry.type == "instance" then
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
    for progressIndex, progressBar in ipairs(entryFrame.ProgressBars or {}) do
        progressBar:Hide()
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

            if type(objective.progress) == "table" then
                local progressBar = self:GetObjectiveProgressBar(entryFrame, objectiveIndex)
                progressBar:ClearAllPoints()
                progressBar:SetPoint("TOPLEFT", textLine, "BOTTOMLEFT", 0, -OBJECTIVE_PROGRESS_GAP)
                progressBar:SetPoint("TOPRIGHT", textLine, "BOTTOMRIGHT", 0, -OBJECTIVE_PROGRESS_GAP)
                progressBar:SetHeight(progressBarHeight)
                progressBar:SetStatusBarTexture(progressBarTexture)
                progressBar.Background:SetColorTexture(0.10, 0.12, 0.15, 0.85)

                local fillR, fillG, fillB = accentR, accentG, accentB
                if objective.isComplete then
                    fillR, fillG, fillB = completeR, completeG, completeB
                end

                progressBar:SetMinMaxValues(0, objective.progress.maxValue or 100)
                progressBar:SetValue(objective.progress.value or objective.progress.percent or 0)
                progressBar:SetStatusBarColor(fillR, fillG, fillB, objective.isComplete and 0.95 or 0.85)
                progressBar.Label:SetFont(bodyFontPath, progressTextSize, "")
                progressBar.Label:SetTextColor(metaR, metaG, metaB)
                progressBar.Label:SetText(objective.progress.label or "")
                progressBar:Show()

                contentOffset = contentOffset + progressBarHeight + OBJECTIVE_PROGRESS_GAP
                height = math_max(height, contentOffset)
            end
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
                for _, progressBar in ipairs(entryFrame.ProgressBars or {}) do
                    progressBar:Hide()
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
        for _, progressBar in ipairs(entryFrame.ProgressBars or {}) do
            progressBar:Hide()
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
    self:EnsureAutomaticSectionCollapseState()

    RequestInstanceLockoutInfo(reason == "enable")

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

function ObjectiveTracker:OnRefreshEvent(event, ...)
    local questID = ...
    if (event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" or event == "QUEST_TURNED_IN")
        and type(questID) == "number"
    then
        self:SetQuestSuppressed(questID, false)
    end

    if event == "PLAYER_ENTERING_WORLD"
        or event == "UPDATE_INSTANCE_INFO"
        or event == "ENCOUNTER_END"
        or event == "PLAYER_DIFFICULTY_CHANGED"
        or event == "CHALLENGE_MODE_START"
        or event == "CHALLENGE_MODE_COMPLETED"
        or event == "CHALLENGE_MODE_RESET"
    then
        RequestInstanceLockoutInfo(event == "PLAYER_ENTERING_WORLD")
    end

    self:ScheduleRefresh(event)
end

function ObjectiveTracker:OnEnable()
    if not self:IsModuleEnabled() then
        return
    end

    self.suppressedQuestIDs = self.suppressedQuestIDs or {}
    self:CreateFrame()
    local console = GetDebugConsole()
    if console and console.RegisterSource then
        console:RegisterSource(DEBUG_SOURCE_KEY, {
            title = "Objective Tracker",
            category = "Gameplay",
        })
    end
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
    self.suppressedQuestIDs = {}
    if self.frame then
        self.frame:Hide()
    end
    self:ApplyBlizzardTrackerState()
end
