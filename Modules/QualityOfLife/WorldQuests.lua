---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class WorldQuestsModule : AceModule
---@field worldMapButton Button|nil
---@field worldMapPanel Frame|nil
---@field worldMapInitialized boolean|nil
---@field providerHooked boolean|nil
---@field dataDirty boolean|nil
---@field refreshQueued boolean|nil
---@field pendingPinRefresh boolean|nil
---@field refreshTimerPending boolean|nil
---@field pendingRefreshReason string|nil
---@field hoveredQuestID number|nil
---@field activeDisplayMapID number|nil
---@field cachedEntries table|nil
---@field cachedLookup table|nil
local WorldQuests = QOL:NewModule("WorldQuests", "AceEvent-3.0")

local C_AddOns = _G.C_AddOns
local C_Map = _G.C_Map
local C_QuestLog = _G.C_QuestLog
local C_TaskQuest = _G.C_TaskQuest
local C_Timer = _G.C_Timer
local C_SuperTrack = _G.C_SuperTrack
local C_CurrencyInfo = _G.C_CurrencyInfo
local CreateFrame = _G.CreateFrame
local CreateVector2D = _G.CreateVector2D
local GameTooltip = _G.GameTooltip
local GetMoneyString = _G.GetMoneyString
local GetNumQuestLogRewards = _G.GetNumQuestLogRewards
local GetNumQuestLogRewardFactions = _G.GetNumQuestLogRewardFactions
local GetQuestLogRewardFactionInfo = _G.GetQuestLogRewardFactionInfo
local GetQuestLogRewardInfo = _G.GetQuestLogRewardInfo
local GetQuestLogRewardMoney = _G.GetQuestLogRewardMoney
local GetTime = _G.GetTime
local HaveQuestRewardData = _G.HaveQuestRewardData
local InCombatLockdown = _G.InCombatLockdown
local MapUtil = _G.MapUtil
local QuestMapFrame = _G.QuestMapFrame
local QuestUtil = _G.QuestUtil
local UIParent = _G.UIParent
local WorldMapFrame = _G.WorldMapFrame
local WorldMap_IsWorldQuestEffectivelyTracked = _G.WorldMap_IsWorldQuestEffectivelyTracked
local hooksecurefunc = _G.hooksecurefunc

local floor = math.floor
local format = string.format
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs
local table_insert = table.insert
local table_sort = table.sort
local tostring = tostring
local unpack = table.unpack or unpack

local TAB_ICON_TEXTURE = "Interface\\Icons\\inv_misc_map_01"
local ROW_ICON_TEXTURE = "Interface\\Icons\\inv_misc_map08"
local DEBUG_SOURCE = "worldquests"
local MAX_SOURCE_MAPS = 48

local FILTER_DEFS = {
    { key = "tracked", label = "Tracked" },
    { key = "gear", label = "Loot" },
    { key = "gold", label = "Gold" },
    { key = "reputation", label = "Rep" },
    { key = "items", label = "Items" },
    { key = "profession", label = "Profession" },
    { key = "pvp", label = "PvP" },
    { key = "pet", label = "Pet" },
    { key = "dungeon", label = "Dungeon" },
    { key = "rare", label = "Rare" },
    { key = "time", label = "Soon" },
}

local QUEST_TYPE_FLAGS = {
    [Enum.QuestTagType.PvP] = "pvp",
    [Enum.QuestTagType.PetBattle] = "pet",
    [Enum.QuestTagType.Dungeon] = "dungeon",
    [Enum.QuestTagType.Raid] = "dungeon",
    [Enum.QuestTagType.Profession] = "profession",
}

local function GetOptions()
    return T:GetModule("Configuration").Options.WorldQuests
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result1, result2, result3, result4, result5, result6, result7 = pcall(func, ...)
    if ok then
        return result1, result2, result3, result4, result5, result6, result7
    end

    return nil
end

local function IsDebugEnabled()
    local debugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    return debugConsole and debugConsole.IsSourceEnabled and debugConsole:IsSourceEnabled(DEBUG_SOURCE) == true
end

local function LogDebug(message)
    local debugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if not debugConsole or type(debugConsole.Log) ~= "function" or not IsDebugEnabled() then
        return
    end

    debugConsole:Log(DEBUG_SOURCE, tostring(message), false)
end

local function GetThemeColor(key, fallback)
    local theme = T:GetModule("Theme", true)
    if theme and type(theme.GetColor) == "function" then
        local color = theme:GetColor(key)
        if type(color) == "table" and color[1] and color[2] and color[3] then
            return color
        end
    end

    return fallback
end

local function GetBackdropColors()
    local background = GetThemeColor("backgroundColor", { 0.06, 0.06, 0.08, 0.96 })
    local border = GetThemeColor("borderColor", { 0.24, 0.26, 0.32, 1 })
    local accent = GetThemeColor("accentColor", { 0.95, 0.76, 0.26, 1 })
    local primary = GetThemeColor("primaryColor", { 0.14, 0.74, 0.72, 1 })

    return background, border, accent, primary
end

local function CreateBackdrop(frame)
    if frame.backdropApplied then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local background, border = GetBackdropColors()
    frame:SetBackdropColor(background[1], background[2], background[3], background[4] or 0.96)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)

    frame.BackgroundFill = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.BackgroundFill:SetAllPoints(frame)
    frame.BackgroundFill:SetColorTexture(background[1], background[2], background[3], 0.98)
    frame.backdropApplied = true
end

local function SkinScrollBar(scrollFrame)
    local ui = T.Tools and T.Tools.UI
    if ui and ui.SkinScrollBar then
        ui.SkinScrollBar(scrollFrame)
    end
end

local function SkinButton(button)
    local ui = T.Tools and T.Tools.UI
    if ui and ui.SkinTwichButton then
        ui.SkinTwichButton(button)
    end
end

local function SkinCloseButton(button)
    local ui = T.Tools and T.Tools.UI
    if ui and ui.SkinCloseButton then
        ui.SkinCloseButton(button)
    end
end

local function FormatRemainingTime(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return nil
    end

    if seconds >= 86400 then
        return format("%dd", floor(seconds / 86400))
    end
    if seconds >= 3600 then
        return format("%dh", floor(seconds / 3600))
    end
    if seconds >= 60 then
        return format("%dm", floor(seconds / 60))
    end
    return format("%ds", floor(seconds))
end

local function GetQuestMapID(questID)
    if type(_G.GetQuestUiMapID) == "function" then
        local mapID = SafeCall(_G.GetQuestUiMapID, questID, true)
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

    return format("Quest %d", tonumber(questID) or 0)
end

local function GetQuestLocation(questID, mapID)
    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestLocation) == "function" then
        local x, y = SafeCall(C_TaskQuest.GetQuestLocation, questID, mapID)
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    return nil, nil
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

local function IsQuestTracked(questID)
    if type(WorldMap_IsWorldQuestEffectivelyTracked) == "function" then
        return SafeCall(WorldMap_IsWorldQuestEffectivelyTracked, questID) == true
    end

    if type(C_QuestLog) == "table" and type(C_QuestLog.IsQuestWatched) == "function" then
        return SafeCall(C_QuestLog.IsQuestWatched, questID) == true
    end

    return false
end

local function AppendQuestIDs(questIDs, seen, entries)
    if type(entries) ~= "table" then
        return
    end

    for _, info in ipairs(entries) do
        local questID = type(info) == "table" and tonumber(info.questID) or nil
        if questID and not seen[questID] then
            seen[questID] = true
            questIDs[#questIDs + 1] = questID
        end
    end
end

local function GetDisplayedMapID()
    local mapFrame = _G.WorldMapFrame
    if mapFrame and type(mapFrame.GetMapID) == "function" then
        local mapID = mapFrame:GetMapID()
        if type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end

    if type(C_Map) == "table" and type(C_Map.GetBestMapForUnit) == "function" then
        return SafeCall(C_Map.GetBestMapForUnit, "player")
    end

    return nil
end

local function GetMapName(mapID)
    if type(C_Map) == "table" and type(C_Map.GetMapInfo) == "function" then
        local info = SafeCall(C_Map.GetMapInfo, mapID)
        if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end

    return "World Quests"
end

local function GetMapInfoSafe(mapID)
    if type(C_Map) ~= "table" or type(C_Map.GetMapInfo) ~= "function" then
        return nil
    end

    return SafeCall(C_Map.GetMapInfo, mapID)
end

local function IsZoneOrChildMap(mapID)
    local mapInfo = GetMapInfoSafe(mapID)
    if type(mapInfo) ~= "table" then
        return false, nil
    end

    local mapType = tonumber(mapInfo.mapType)
    if not mapType then
        return false, mapInfo
    end

    return mapType >= Enum.UIMapType.Zone, mapInfo
end

local function AddDescendantZones(mapID, result, seen)
    if type(C_Map) ~= "table" or type(C_Map.GetMapChildrenInfo) ~= "function" then
        return
    end

    local children = SafeCall(C_Map.GetMapChildrenInfo, mapID, Enum.UIMapType.Zone, true)
    for _, childInfo in ipairs(type(children) == "table" and children or {}) do
        if #result >= MAX_SOURCE_MAPS then
            break
        end

        local childMapID = type(childInfo) == "table" and tonumber(childInfo.mapID) or nil
        if childMapID and not seen[childMapID] then
            seen[childMapID] = true
            result[#result + 1] = childMapID
        end
    end
end

local function ResolveSourceMapIDs(displayMapID)
    local options = GetOptions()
    local mapIDs = {}
    local seen = {}

    if type(displayMapID) ~= "number" or displayMapID <= 0 then
        return mapIDs
    end

    local isZoneMap, mapInfo = IsZoneOrChildMap(displayMapID)
    if isZoneMap then
        mapIDs[1] = displayMapID
        return mapIDs
    end

    if options:GetOnlyCurrentZone() or not mapInfo then
        return mapIDs
    end

    if mapInfo.mapType and mapInfo.mapType < Enum.UIMapType.Zone and options:GetShowChildZonesOnParentMaps() then
        AddDescendantZones(displayMapID, mapIDs, seen)
    end

    return mapIDs
end

local function BuildMoneySummary(money)
    if type(money) == "number" and money > 0 and type(GetMoneyString) == "function" then
        return GetMoneyString(money, true)
    end

    return nil
end

local function RequestQuestRewards(questID)
    if type(HaveQuestRewardData) == "function" and HaveQuestRewardData(questID) == false then
        if type(C_QuestLog) == "table" and type(C_QuestLog.RequestLoadQuestByID) == "function" then
            SafeCall(C_QuestLog.RequestLoadQuestByID, questID)
        end
    end
end

local function AddSummaryPiece(summaryParts, text)
    if type(text) == "string" and text ~= "" then
        summaryParts[#summaryParts + 1] = text
    end
end

local function CompactSummary(summaryParts)
    local count = #summaryParts
    if count == 0 then
        return "No reward data yet."
    end

    if count <= 2 then
        return table.concat(summaryParts, "  •  ")
    end

    return format("%s  •  %s  •  +%d more", summaryParts[1], summaryParts[2], count - 2)
end

local function JoinSummary(summaryParts)
    if #summaryParts == 0 then
        return "No reward data yet."
    end

    return CompactSummary(summaryParts)
end

local function BuildQuestRewards(questID)
    RequestQuestRewards(questID)

    local summaryParts = {}
    local flags = {}
    local tooltipLines = {}
    local displayIcon

    local money = type(GetQuestLogRewardMoney) == "function" and GetQuestLogRewardMoney(questID) or 0
    if type(money) == "number" and money > 0 then
        flags.gold = true
        AddSummaryPiece(summaryParts, BuildMoneySummary(money))
        tooltipLines[#tooltipLines + 1] = "Gold reward available."
    end

    local currencyFn = type(C_QuestLog) == "table" and C_QuestLog.GetQuestRewardCurrencies or nil
    for index, currencyInfo in ipairs(type(currencyFn) == "function" and SafeCall(currencyFn, questID) or {}) do
        if type(currencyInfo) == "table" then
            local quantity = tonumber(currencyInfo.totalRewardAmount or currencyInfo.quantity or currencyInfo.totalQuantity or 0) or 0
            local currencyName = currencyInfo.name
            if not currencyName and type(C_CurrencyInfo) == "table" and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
                local info = SafeCall(C_CurrencyInfo.GetCurrencyInfo, currencyInfo.currencyID)
                currencyName = info and info.name or nil
            end

            currencyName = currencyName or format("Currency %d", tonumber(currencyInfo.currencyID) or index)
            AddSummaryPiece(summaryParts, format("%s %s", tostring(quantity), currencyName))
            tooltipLines[#tooltipLines + 1] = format("%s %s", tostring(quantity), currencyName)
            displayIcon = displayIcon or currencyInfo.texture
        end
    end

    local factionIndex = 1
    while type(GetQuestLogRewardFactionInfo) == "function" do
        local factionName, reputationAmount = SafeCall(GetQuestLogRewardFactionInfo, factionIndex, questID)
        if type(factionName) ~= "string" or factionName == "" then
            break
        end
        flags.reputation = true
        local text = reputationAmount and reputationAmount > 0
            and format("%s %s", tostring(reputationAmount), factionName)
            or factionName
        AddSummaryPiece(summaryParts, text)
        tooltipLines[#tooltipLines + 1] = text
        factionIndex = factionIndex + 1
    end

    local rewardCount = type(GetNumQuestLogRewards) == "function" and tonumber(GetNumQuestLogRewards(questID)) or 0
    for rewardIndex = 1, rewardCount do
        local itemName, itemTexture, itemCount, _, _, itemID, itemLevel = SafeCall(GetQuestLogRewardInfo, rewardIndex, questID)
        if type(itemName) == "string" and itemName ~= "" then
            displayIcon = displayIcon or itemTexture
            local itemEquipLoc = nil
            if type(C_Item) == "table" and type(C_Item.GetItemInfoInstant) == "function" then
                local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
                itemEquipLoc = equipLoc
            end

            local isGear = type(itemEquipLoc) == "string" and itemEquipLoc ~= ""
            if isGear then
                flags.gear = true
            else
                flags.items = true
            end

            local label = itemCount and itemCount > 1 and format("%dx %s", itemCount, itemName) or itemName
            if isGear and tonumber(itemLevel) and tonumber(itemLevel) > 0 then
                label = format("%s (%d)", label, tonumber(itemLevel))
            end

            AddSummaryPiece(summaryParts, label)
            tooltipLines[#tooltipLines + 1] = label
        end
    end

    return {
        flags = flags,
        summary = JoinSummary(summaryParts),
        tooltipLines = tooltipLines,
        icon = displayIcon,
    }
end

local function SetUserWaypoint(mapID, x, y, questID, title)
    if type(mapID) == "number" and type(x) == "number" and type(y) == "number"
        and type(CreateVector2D) == "function"
        and type(C_Map) == "table"
        and type(C_Map.SetUserWaypoint) == "function"
    then
        C_Map.SetUserWaypoint({
            uiMapID = mapID,
            position = CreateVector2D(x, y),
        })

        if type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end
    end

    if type(questID) == "number" and type(C_SuperTrack) == "table" and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
    end

    LogDebug(format("waypoint questID=%s mapID=%s title=%s", tostring(questID), tostring(mapID), tostring(title)))
end

local function ToggleWorldQuestWatch(questID, shouldTrack)
    if type(questID) ~= "number" then
        return
    end

    local watchType = Enum and Enum.QuestWatchType and Enum.QuestWatchType.Manual or 1
    if shouldTrack then
        if type(QuestUtil) == "table" and type(QuestUtil.TrackWorldQuest) == "function" then
            SafeCall(QuestUtil.TrackWorldQuest, questID, watchType)
        elseif type(C_QuestLog) == "table" and type(C_QuestLog.AddWorldQuestWatch) == "function" then
            SafeCall(C_QuestLog.AddWorldQuestWatch, questID, watchType)
        end
    else
        if type(QuestUtil) == "table" and type(QuestUtil.UntrackWorldQuest) == "function" then
            SafeCall(QuestUtil.UntrackWorldQuest, questID)
        elseif type(C_QuestLog) == "table" and type(C_QuestLog.RemoveWorldQuestWatch) == "function" then
            SafeCall(C_QuestLog.RemoveWorldQuestWatch, questID)
        end
    end
end

local function BuildQuestEntry(questID, sourceMapID)
    if type(questID) ~= "number" or questID <= 0 or not IsWorldQuest(questID) or IsQuestComplete(questID) then
        return nil
    end

    local mapID = GetQuestMapID(questID) or sourceMapID
    local title = GetQuestTitle(questID)
    local x, y = GetQuestLocation(questID, mapID)
    local zoneName = GetMapName(mapID)
    local tagInfo = type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestTagInfo) == "function"
        and SafeCall(C_QuestLog.GetQuestTagInfo, questID)
        or nil
    local timeLeftSeconds = type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestTimeLeftSeconds) == "function"
        and SafeCall(C_TaskQuest.GetQuestTimeLeftSeconds, questID)
        or nil
    local rewards = BuildQuestRewards(questID)
    local flags = rewards.flags

    if type(tagInfo) == "table" then
        if tagInfo.quality and tagInfo.quality > Enum.WorldQuestQuality.Common then
            flags.rare = true
        end

        local typeFlag = QUEST_TYPE_FLAGS[tagInfo.worldQuestType]
        if typeFlag then
            flags[typeFlag] = true
        end
    end

    if IsQuestTracked(questID) then
        flags.tracked = true
    end

    local timeThreshold = tonumber(GetOptions():GetTimeFilterHours()) or 8
    if type(timeLeftSeconds) == "number" and timeLeftSeconds > 0 and timeLeftSeconds <= (timeThreshold * 3600) then
        flags.time = true
    end

    local icon = rewards.icon or ROW_ICON_TEXTURE
    local atlas
    if type(QuestUtil) == "table" and type(QuestUtil.GetWorldQuestAtlasInfo) == "function" and type(tagInfo) == "table" then
        atlas = SafeCall(QuestUtil.GetWorldQuestAtlasInfo, questID, tagInfo, false)
    end

    return {
        questID = questID,
        title = title,
        mapID = mapID,
        sourceMapID = sourceMapID,
        zoneName = zoneName,
        x = x,
        y = y,
        tracked = IsQuestTracked(questID),
        flags = flags,
        rewardSummary = rewards.summary,
        rewardTooltipLines = rewards.tooltipLines,
        timeLeftSeconds = timeLeftSeconds,
        timeLeftText = FormatRemainingTime(timeLeftSeconds),
        icon = icon,
        atlas = atlas,
        quality = type(tagInfo) == "table" and tagInfo.quality or nil,
    }
end

function WorldQuests:GetSelectedFilters()
    return GetOptions():GetSelectedFilters()
end

function WorldQuests:HasActiveFilters()
    for _, value in pairs(self:GetSelectedFilters()) do
        if value == true then
            return true
        end
    end

    return false
end

function WorldQuests:QuestMatchesFilters(entry)
    local options = GetOptions()
    if not entry or type(entry.flags) ~= "table" then
        return false
    end

    local selected = self:GetSelectedFilters()
    local hasSelected = false
    for key, value in pairs(selected) do
        if value == true and options:GetFilterChipEnabled(key) then
            hasSelected = true
            if entry.flags[key] == true then
                return true
            end
        end
    end

    return hasSelected == false
end

function WorldQuests:SortEntries(entries)
    local method = GetOptions():GetSortMethod()
    table_sort(entries, function(left, right)
        if method == "zone" then
            local leftZone = tostring(left.zoneName or "")
            local rightZone = tostring(right.zoneName or "")
            if leftZone ~= rightZone then
                return leftZone < rightZone
            end
        elseif method == "name" then
            local leftName = tostring(left.title or "")
            local rightName = tostring(right.title or "")
            if leftName ~= rightName then
                return leftName < rightName
            end
        elseif method == "rewards" then
            local leftReward = tostring(left.rewardSummary or "")
            local rightReward = tostring(right.rewardSummary or "")
            if leftReward ~= rightReward then
                return leftReward < rightReward
            end
        else
            local leftTime = tonumber(left.timeLeftSeconds) or 2147483647
            local rightTime = tonumber(right.timeLeftSeconds) or 2147483647
            if leftTime ~= rightTime then
                return leftTime < rightTime
            end
        end

        local leftTracked = left.tracked == true and 1 or 0
        local rightTracked = right.tracked == true and 1 or 0
        if leftTracked ~= rightTracked then
            return leftTracked > rightTracked
        end

        return tostring(left.title or "") < tostring(right.title or "")
    end)
end

function WorldQuests:GatherEntries(displayMapID)
    if not self.dataDirty and self.activeDisplayMapID == displayMapID and self.cachedEntries and self.cachedLookup then
        return self.cachedEntries, self.cachedLookup
    end

    local entries = {}
    local lookup = {}
    local seenQuestIDs = {}
    local sourceMapIDs = ResolveSourceMapIDs(displayMapID)

    for _, mapID in ipairs(sourceMapIDs) do
        local questIDs = {}
        AppendQuestIDs(questIDs, seenQuestIDs,
            type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestsOnMap) == "function"
                and SafeCall(C_QuestLog.GetQuestsOnMap, mapID)
                or nil)
        AppendQuestIDs(questIDs, seenQuestIDs,
            type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestsOnMap) == "function"
                and SafeCall(C_TaskQuest.GetQuestsOnMap, mapID)
                or nil)

        for _, questID in ipairs(questIDs) do
            local entry = BuildQuestEntry(questID, mapID)
            if entry then
                entries[#entries + 1] = entry
                lookup[questID] = entry
            end
        end
    end

    self:SortEntries(entries)

    self.activeDisplayMapID = displayMapID
    self.cachedEntries = entries
    self.cachedLookup = lookup
    self.dataDirty = false

    LogDebug(format("gather mapID=%s entries=%d", tostring(displayMapID), #entries))
    return entries, lookup
end

function WorldQuests:QueueRefresh(reason, delay)
    self.pendingRefreshReason = reason or self.pendingRefreshReason or "refresh"
    if self.refreshTimerPending then
        return
    end

    self.refreshTimerPending = true
    local waitTime = tonumber(delay) or 0
    local function Run()
        self.refreshTimerPending = false
        local nextReason = self.pendingRefreshReason or "refresh"
        self.pendingRefreshReason = nil
        self:RefreshNow(nextReason)
    end

    if waitTime > 0 and C_Timer and C_Timer.After then
        C_Timer.After(waitTime, Run)
    else
        Run()
    end
end

local function CreateBrowserFrame(name, parent)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:SetSize(352, 472)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    CreateBackdrop(frame)

    local background, border, accent = GetBackdropColors()

    frame.TitleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(34)
    frame.TitleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 1 },
    })
    frame.TitleBar:SetBackdropColor(background[1] * 0.82, background[2] * 0.82, background[3] * 0.82, 0.98)
    frame.TitleBar:SetBackdropBorderColor(border[1], border[2], border[3], 0.35)

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "ARTWORK")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 0, 0)
    frame.TitleAccent:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", 0, 0)
    frame.TitleAccent:SetHeight(2)
    frame.TitleAccent:SetColorTexture(accent[1], accent[2], accent[3], 0.95)

    frame.TitleIcon = frame.TitleBar:CreateTexture(nil, "OVERLAY")
    frame.TitleIcon:SetPoint("LEFT", frame.TitleBar, "LEFT", 10, 0)
    frame.TitleIcon:SetSize(16, 16)
    frame.TitleIcon:SetTexture(TAB_ICON_TEXTURE)
    frame.TitleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.TitleIcon, "RIGHT", 8, 0)
    frame.Title:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -10, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("World Quests")
    frame.Title:SetTextColor(1, 0.94, 0.82)

    frame.FilterBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.FilterBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -42)
    frame.FilterBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -42)
    frame.FilterBar:SetHeight(76)
    frame.FilterBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.FilterBar:SetBackdropColor(background[1] * 0.9, background[2] * 0.9, background[3] * 0.9, 0.94)
    frame.FilterBar:SetBackdropBorderColor(border[1], border[2], border[3], 0.25)

    frame.Meta = frame.FilterBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Meta:SetPoint("TOPLEFT", frame.FilterBar, "TOPLEFT", 10, -8)
    frame.Meta:SetPoint("TOPRIGHT", frame.FilterBar, "TOPRIGHT", -10, -8)
    frame.Meta:SetJustifyH("LEFT")
    frame.Meta:SetTextColor(0.84, 0.84, 0.84)
    frame.Meta:SetWordWrap(false)

    frame.ChipAnchor = CreateFrame("Frame", nil, frame.FilterBar)
    frame.ChipAnchor:SetPoint("TOPLEFT", frame.FilterBar, "TOPLEFT", 8, -24)
    frame.ChipAnchor:SetPoint("BOTTOMRIGHT", frame.FilterBar, "BOTTOMRIGHT", -8, -6)
    frame.filterButtons = {}

    frame.ContentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ContentInset:SetPoint("TOPLEFT", frame.FilterBar, "BOTTOMLEFT", 0, -8)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.ContentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.ContentInset:SetBackdropColor(background[1] * 0.82, background[2] * 0.82, background[3] * 0.82, 0.98)
    frame.ContentInset:SetBackdropBorderColor(border[1], border[2], border[3], 0.45)

    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame.ContentInset, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 8, -8)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame.ContentInset, "BOTTOMRIGHT", -20, 8)
    SkinScrollBar(frame.ScrollFrame)

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ScrollFrame)
    frame.ScrollChild:SetSize(1, 1)
    frame.ScrollFrame:SetScrollChild(frame.ScrollChild)
    frame.ScrollFrame:HookScript("OnSizeChanged", function(scroll)
        frame.ScrollChild:SetWidth(max(1, (scroll:GetWidth() or 1) - 8))
    end)

    frame.EmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("CENTER", frame.ContentInset, "CENTER", 0, 0)
    frame.EmptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.EmptyText:Hide()

    frame.headers = {}
    frame.rows = {}

    return frame
end

local function EnsureHeader(frame, index)
    local header = frame.headers[index]
    if header then
        return header
    end

    header = CreateFrame("Frame", nil, frame.ScrollChild, "BackdropTemplate")
    header:SetHeight(22)
    header:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    header:SetBackdropColor(1, 1, 1, 0.03)

    header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.Text:SetPoint("LEFT", header, "LEFT", 8, 0)
    header.Text:SetTextColor(1, 0.92, 0.76)

    frame.headers[index] = header
    return header
end

local function EnsureFilterButton(frame, index)
    local button = frame.filterButtons[index]
    if button then
        return button
    end

    button = CreateFrame("Button", nil, frame.ChipAnchor, "UIPanelButtonTemplate")
    button:SetHeight(18)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetHighlightFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
    SkinButton(button)
    frame.filterButtons[index] = button
    return button
end

local function ApplyChipState(button, active)
    if not button then
        return
    end

    local accent = GetThemeColor("accentColor", { 0.95, 0.76, 0.26, 1 })
    local border = GetThemeColor("borderColor", { 0.24, 0.26, 0.32, 1 })
    if not button.StateFill then
        button.StateFill = button:CreateTexture(nil, "BACKGROUND")
        button.StateFill:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        button.StateFill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    end

    if active then
        button.StateFill:SetColorTexture(accent[1], accent[2], accent[3], 0.18)
        if button.SetBackdropBorderColor then
            button:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.75)
        end
    else
        button.StateFill:SetColorTexture(1, 1, 1, 0.02)
        if button.SetBackdropBorderColor then
            button:SetBackdropBorderColor(border[1], border[2], border[3], 0.45)
        end
    end
end

local function EnsureRow(frame, index)
    local row = frame.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, frame.ScrollChild)
    row:SetHeight(92)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetAllPoints(row)
    row.Background:SetColorTexture(1, 1, 1, 0.03)

    row.Hover = row:CreateTexture(nil, "HIGHLIGHT")
    row.Hover:SetAllPoints(row)
    row.Hover:SetColorTexture(1, 1, 1, 0.06)

    row.Divider = row:CreateTexture(nil, "BORDER")
    row.Divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 0)
    row.Divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 0)
    row.Divider:SetHeight(1)
    row.Divider:SetColorTexture(1, 1, 1, 0.05)

    row.IconBackdrop = row:CreateTexture(nil, "BORDER")
    row.IconBackdrop:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
    row.IconBackdrop:SetSize(36, 36)
    row.IconBackdrop:SetColorTexture(0, 0, 0, 0.28)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetPoint("CENTER", row.IconBackdrop, "CENTER", 0, 0)
    row.Icon:SetSize(32, 32)
    row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.ActionAnchor = CreateFrame("Frame", nil, row)
    row.ActionAnchor:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
    row.ActionAnchor:SetSize(52, 44)

    row.Title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Title:SetPoint("TOPLEFT", row.IconBackdrop, "TOPRIGHT", 10, 0)
    row.Title:SetPoint("RIGHT", row.ActionAnchor, "LEFT", -8, 0)
    row.Title:SetJustifyH("LEFT")
    row.Title:SetWordWrap(true)
    row.Title:SetMaxLines(2)

    row.Subtitle = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Subtitle:SetPoint("TOPLEFT", row.Title, "BOTTOMLEFT", 0, -4)
    row.Subtitle:SetPoint("RIGHT", row.ActionAnchor, "LEFT", -8, 0)
    row.Subtitle:SetJustifyH("LEFT")
    row.Subtitle:SetTextColor(0.78, 0.8, 0.84)
    row.Subtitle:SetWordWrap(false)
    row.Subtitle:SetMaxLines(1)

    row.Rewards = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Rewards:SetPoint("TOPLEFT", row.Subtitle, "BOTTOMLEFT", 0, -3)
    row.Rewards:SetPoint("RIGHT", row.ActionAnchor, "LEFT", -8, 0)
    row.Rewards:SetPoint("BOTTOM", row, "BOTTOM", 0, 8)
    row.Rewards:SetJustifyH("LEFT")
    row.Rewards:SetTextColor(0.92, 0.9, 0.84)
    row.Rewards:SetWordWrap(true)
    row.Rewards:SetMaxLines(2)

    row.Time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.Time:SetPoint("TOPRIGHT", row.ActionAnchor, "TOPRIGHT", 0, 0)
    row.Time:SetTextColor(1, 0.84, 0.38)
    row.Time:SetJustifyH("RIGHT")

    row.TrackButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.TrackButton:SetSize(52, 18)
    row.TrackButton:SetPoint("TOPRIGHT", row.ActionAnchor, "TOPRIGHT", 0, -18)
    row.TrackButton:SetText("Watch")
    SkinButton(row.TrackButton)

    row.WaypointButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.WaypointButton:SetSize(52, 18)
    row.WaypointButton:SetPoint("TOPRIGHT", row.TrackButton, "BOTTOMRIGHT", 0, -4)
    row.WaypointButton:SetText("Pin")
    SkinButton(row.WaypointButton)

    frame.rows[index] = row
    return row
end

function WorldQuests:BuildRowTooltip(row)
    if not row or not row.entry then
        return
    end

    local entry = row.entry
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(entry.title or "World Quest")
    GameTooltip:AddLine(entry.zoneName or "Unknown Zone", 0.82, 0.82, 0.82)

    if entry.timeLeftText then
        GameTooltip:AddLine(format("Expires in %s", entry.timeLeftText), 1, 0.82, 0.3)
    end

    GameTooltip:AddLine(" ")
    for _, line in ipairs(entry.rewardTooltipLines or {}) do
        GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Left-click to place a waypoint.", 0.95, 0.82, 0.3)
    GameTooltip:AddLine("Right-click to toggle tracking.", 0.95, 0.82, 0.3)
    GameTooltip:Show()
end

function WorldQuests:SetHoveredQuestID(questID)
    if self.hoveredQuestID == questID then
        return
    end

    self.hoveredQuestID = questID
    if GetOptions():GetShowHoveredPOI() then
        self:QueueMapPinRefresh()
    end
end

function WorldQuests:RenderFilterButtons(frame)
    local options = GetOptions()
    local buttons = frame.filterButtons
    local buttonIndex = 1
    local x = 0
    local y = 0
    local rowHeight = 22
    local maxWidth = max(120, (frame.ChipAnchor:GetWidth() or 220) - 2)

    local function LayoutButton(button, text, active, onClick)
        button:SetText(text)
        button:SetWidth(max(40, (#text * 6) + 16))
        if x > 0 and (x + button:GetWidth()) > maxWidth then
            x = 0
            y = y - rowHeight
        end

        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", frame.ChipAnchor, "TOPLEFT", x, y)
        button:SetScript("OnClick", onClick)
        button:Show()
        ApplyChipState(button, active)
        x = x + button:GetWidth() + 6
    end

    local allButton = EnsureFilterButton(frame, buttonIndex)
    LayoutButton(allButton, "All", not self:HasActiveFilters(), function()
        options:ClearSelectedFilters()
    end)
    buttonIndex = buttonIndex + 1

    for _, filterDef in ipairs(FILTER_DEFS) do
        if options:GetFilterChipEnabled(filterDef.key) then
            local button = EnsureFilterButton(frame, buttonIndex)
            LayoutButton(button, filterDef.label, options:IsFilterSelected(filterDef.key), function()
                options:SetFilterSelected(filterDef.key, not options:IsFilterSelected(filterDef.key))
            end)
            buttonIndex = buttonIndex + 1
        end
    end

    for index = buttonIndex, #buttons do
        buttons[index]:Hide()
    end

    local rowsUsed = max(1, math.floor((-y) / rowHeight) + 1)
    local filterHeight = 30 + (rowsUsed * rowHeight)
    frame.FilterBar:SetHeight(filterHeight)
end

function WorldQuests:BuildDisplaySections(entries)
    local sections = {}
    local currentSection

    for _, entry in ipairs(entries) do
        if not currentSection or currentSection.title ~= entry.zoneName then
            currentSection = {
                title = entry.zoneName,
                entries = {},
            }
            sections[#sections + 1] = currentSection
        end

        currentSection.entries[#currentSection.entries + 1] = entry
    end

    return sections
end

function WorldQuests:RenderBrowser(frame)
    if not frame then
        return
    end

    local displayMapID = GetDisplayedMapID()
    local entries, lookup = self:GatherEntries(displayMapID)
    local filtered = {}

    for _, entry in ipairs(entries) do
        if self:QuestMatchesFilters(entry) then
            filtered[#filtered + 1] = entry
        end
    end

    self.cachedLookup = lookup
    self:RenderFilterButtons(frame)

    local mapName = displayMapID and GetMapName(displayMapID) or "World Quests"
    frame.Title:SetText(mapName)
    frame.Meta:SetText(format("%d shown  •  %d total  •  %s",
        #filtered,
        #entries,
        GetOptions():GetOnlyCurrentZone() and "Current map only" or "Expanded view"))

    frame.EmptyText:SetShown(#filtered == 0)
    if #filtered == 0 then
        frame.EmptyText:SetText("No world quests matched the current view and filters.")
    end

    local sections = self:BuildDisplaySections(filtered)
    local nextHeader = 1
    local nextRow = 1
    local contentHeight = 0

    for _, section in ipairs(sections) do
        local header = EnsureHeader(frame, nextHeader)
        header.Text:SetText(section.title or "Zone")
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -contentHeight)
        header:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)
        header:Show()
        contentHeight = contentHeight + header:GetHeight() + 4
        nextHeader = nextHeader + 1

        for _, entry in ipairs(section.entries) do
            local row = EnsureRow(frame, nextRow)
            row.entry = entry
            row.Title:SetText(entry.title or "World Quest")
            row.Subtitle:SetText(entry.tracked and (entry.zoneName .. "  •  Tracked") or entry.zoneName)
            row.Rewards:SetText(entry.rewardSummary or "No reward data yet.")
            row.Time:SetText(entry.timeLeftText or "")

            if type(entry.atlas) == "string" and entry.atlas ~= "" then
                row.Icon:SetAtlas(entry.atlas, true)
            else
                row.Icon:SetTexture(entry.icon or ROW_ICON_TEXTURE)
            end

            row.Title:SetTextColor(entry.flags.rare and 1 or 0.96, entry.flags.rare and 0.82 or 0.94,
                entry.flags.rare and 0.42 or 0.88)
            row.Background:SetAlpha((nextRow % 2 == 0) and 0.05 or 0.02)

            row.TrackButton:SetText(entry.tracked and "Stop" or "Watch")
            row.TrackButton:SetScript("OnClick", function()
                ToggleWorldQuestWatch(entry.questID, not entry.tracked)
                self.dataDirty = true
                self:RefreshNow("track")
            end)

            row.WaypointButton:SetScript("OnClick", function()
                SetUserWaypoint(entry.mapID, entry.x, entry.y, entry.questID, entry.title)
            end)

            row:SetScript("OnMouseUp", function(_, button)
                if button == "RightButton" then
                    ToggleWorldQuestWatch(entry.questID, not entry.tracked)
                    self.dataDirty = true
                    self:RefreshNow("track")
                else
                    SetUserWaypoint(entry.mapID, entry.x, entry.y, entry.questID, entry.title)
                end
            end)
            row:SetScript("OnEnter", function(button)
                self:SetHoveredQuestID(button.entry and button.entry.questID or nil)
                self:BuildRowTooltip(button)
            end)
            row:SetScript("OnLeave", function()
                self:SetHoveredQuestID(nil)
                GameTooltip:Hide()
            end)

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -contentHeight)
            row:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)
            row:Show()

            contentHeight = contentHeight + row:GetHeight() + 4
            nextRow = nextRow + 1
        end

        contentHeight = contentHeight + 8
    end

    for index = nextHeader, #frame.headers do
        frame.headers[index]:Hide()
    end
    for index = nextRow, #frame.rows do
        frame.rows[index]:Hide()
    end

    frame.ScrollChild:SetHeight(max(1, contentHeight + 8))
end

local ApplyWorldMapTabIconLayout

local function RefreshWorldMapTabIcon(button)
    if not button or not button.Icon then
        return
    end

    button.Icon:SetTexture(TAB_ICON_TEXTURE)
    if ApplyWorldMapTabIconLayout then
        ApplyWorldMapTabIconLayout(button)
    end
end

local function ApplyWorldMapTabSkin(button)
    local ui = T.Tools and T.Tools.UI
    local skins = ui and ui.GetElvUISkins and ui:GetElvUISkins()
    if skins then
        if skins.HandleTab then
            pcall(skins.HandleTab, skins, button)
        elseif skins.HandleButton then
            pcall(skins.HandleButton, skins, button)
        end
    end

    if not button.twichCheckedHighlight then
        local checkedHighlight = button:CreateTexture(nil, "OVERLAY")
        checkedHighlight:SetDrawLayer("BACKGROUND", 0)
        checkedHighlight:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -2)
        checkedHighlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        checkedHighlight:SetColorTexture(1, 0.82, 0, 0.25)
        checkedHighlight:Hide()
        button.twichCheckedHighlight = checkedHighlight

        hooksecurefunc(button, "SetChecked", function(_, checked)
            checkedHighlight:SetShown(checked == true)
            RefreshWorldMapTabIcon(button)
        end)
    end

    button:SetSize(38, 46)
end

ApplyWorldMapTabIconLayout = function(button)
    if not button or not button.Icon then
        return
    end

    button.Icon:ClearAllPoints()
    button.Icon:SetPoint("CENTER", button, "CENTER", -2, 0)
    button.Icon:SetSize(20, 20)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

function WorldQuests:HideWorldMapPanel()
    if self.worldMapPanel then
        self.worldMapPanel:Hide()
    end

    if self.worldMapButton and self.worldMapButton.SetChecked then
        self.worldMapButton:SetChecked(false)
        RefreshWorldMapTabIcon(self.worldMapButton)
    end
end

function WorldQuests:ShowWorldMapPanel()
    if not self.worldMapPanel then
        return
    end

    self:RenderBrowser(self.worldMapPanel)
    self.worldMapPanel:Show()

    if self.worldMapButton and self.worldMapButton.SetChecked then
        self.worldMapButton:SetChecked(true)
        RefreshWorldMapTabIcon(self.worldMapButton)
    end
end

function WorldQuests:OpenWorldMapPanel()
    if not _G.WorldMapFrame and type(_G.WorldMapFrame_LoadUI) == "function" then
        SafeCall(_G.WorldMapFrame_LoadUI)
    end

    if _G.WorldMapFrame and not _G.WorldMapFrame:IsShown() and type(_G.ToggleWorldMap) == "function" then
        SafeCall(_G.ToggleWorldMap)
    end

    self:TryInitializeWorldMapTab()
    self:ShowWorldMapPanel()
end

function WorldQuests:ToggleWorldMapPanel()
    if not self.worldMapPanel then
        return
    end

    if self.worldMapPanel:IsShown() then
        self:HideWorldMapPanel()
    else
        self:ShowWorldMapPanel()
    end
end

function WorldQuests:HookWorldMapTabSiblings()
    local questMapFrame = _G.QuestMapFrame
    if not questMapFrame then
        return
    end

    local function HidePanel()
        WorldQuests:HideWorldMapPanel()
    end

    for _, tab in ipairs({ questMapFrame.QuestsTab, questMapFrame.EventsTab, questMapFrame.MapLegendTab }) do
        if tab and not tab.twichWorldQuestHooked then
            tab:HookScript("OnMouseUp", function(_, mouseButton)
                if mouseButton == "LeftButton" then
                    HidePanel()
                end
            end)
            tab.twichWorldQuestHooked = true
        end
    end

    for _, contentFrame in ipairs({ questMapFrame.QuestsFrame, questMapFrame.EventsFrame, questMapFrame.MapLegendFrame }) do
        if contentFrame and not contentFrame.twichWorldQuestHooked then
            hooksecurefunc(contentFrame, "Show", HidePanel)
            contentFrame.twichWorldQuestHooked = true
        end
    end
end

function WorldQuests:CreateWorldMapPanel()
    local questMapFrame = _G.QuestMapFrame
    local parentFrame = questMapFrame or _G.WorldMapFrame
    if not parentFrame then
        return
    end

    local contentAnchor = questMapFrame and questMapFrame.ContentsAnchor or parentFrame
    self.worldMapPanel = CreateBrowserFrame("TwichUI_WorldQuestsWorldMapPanel", parentFrame)
    self.worldMapPanel:SetFrameStrata(contentAnchor:GetFrameStrata())
    self.worldMapPanel:SetFrameLevel((contentAnchor:GetFrameLevel() or 1) + 20)
    self.worldMapPanel:ClearAllPoints()
    if questMapFrame and contentAnchor == questMapFrame.ContentsAnchor then
        self.worldMapPanel:SetPoint("TOPLEFT", contentAnchor, "TOPLEFT", 0, -29)
        self.worldMapPanel:SetPoint("BOTTOMRIGHT", contentAnchor, "BOTTOMRIGHT", -22, 0)
    else
        self.worldMapPanel:SetAllPoints(contentAnchor)
    end
end

function WorldQuests:LayoutWorldMapButton()
    local button = self.worldMapButton
    if not button then
        return
    end

    local questMapFrame = _G.QuestMapFrame
    local teleportsButton = _G.TwichUI_TeleportsWorldMapTabButton
    local anchorTab = questMapFrame and (questMapFrame.MapLegendTab or questMapFrame.EventsTab or questMapFrame.QuestsTab)

    button:ClearAllPoints()
    if teleportsButton and teleportsButton ~= button and teleportsButton:IsShown() then
        button:SetPoint("TOP", teleportsButton, "BOTTOM", 0, -1)
    elseif anchorTab then
        button:SetPoint("TOP", anchorTab, "BOTTOM", 0, -1)
    elseif _G.WorldMapFrame and _G.WorldMapFrame.BorderFrame then
        button:SetPoint("TOPRIGHT", _G.WorldMapFrame.BorderFrame, "TOPRIGHT", -8, -146)
    end
end

function WorldQuests:CreateWorldMapButton()
    local questMapFrame = _G.QuestMapFrame
    local tabParent = questMapFrame or (_G.WorldMapFrame and _G.WorldMapFrame.BorderFrame)
    if not tabParent then
        return
    end

    local button = CreateFrame("Button", "TwichUI_WorldQuestsWorldMapTabButton", tabParent, "LargeSideTabButtonTemplate")
    button:SetFrameStrata("HIGH")
    button.tooltipText = "World Quests"
    button:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            WorldQuests:ToggleWorldMapPanel()
        end
    end)

    if button.Icon then
        button.Icon:SetTexture(TAB_ICON_TEXTURE)
        ApplyWorldMapTabIconLayout(button)
    end

    ApplyWorldMapTabSkin(button)
    if not button.twichIconHooks then
        button:HookScript("OnShow", function() RefreshWorldMapTabIcon(button) end)
        button:HookScript("OnMouseDown", function() RefreshWorldMapTabIcon(button) end)
        button:HookScript("OnMouseUp", function() RefreshWorldMapTabIcon(button) end)
        button:HookScript("OnClick", function() RefreshWorldMapTabIcon(button) end)
        button.twichIconHooks = true
    end

    self.worldMapButton = button
    self:LayoutWorldMapButton()
end

function WorldQuests:GetWorldQuestDataProvider()
    local mapFrame = _G.WorldMapFrame
    if not mapFrame or type(mapFrame.dataProviders) ~= "table" then
        return nil
    end

    for dataProvider in pairs(mapFrame.dataProviders) do
        if type(dataProvider) == "table"
            and dataProvider.AddWorldQuest
            and _G.WorldMap_WorldQuestDataProviderMixin
            and dataProvider.AddWorldQuest == _G.WorldMap_WorldQuestDataProviderMixin.AddWorldQuest
        then
            return dataProvider
        end
    end

    return nil
end

function WorldQuests:PostProcessWorldQuestPins(dataProvider)
    if not self:IsEnabled() then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingPinRefresh = true
        return
    end

    local mapFrame = _G.WorldMapFrame
    if not mapFrame then
        return
    end

    local mapID = type(mapFrame.GetMapID) == "function" and mapFrame:GetMapID() or nil
    if not mapID then
        return
    end

    local isZoneMap = IsZoneOrChildMap(mapID)
    if not isZoneMap and GetOptions():GetOnlyCurrentZone() then
        return
    end

    local _, lookup = self:GatherEntries(mapID)
    local pinTemplate = dataProvider.GetPinTemplate and dataProvider:GetPinTemplate() or dataProvider.pinTemplate
    if not pinTemplate or not mapFrame.pinPools or not mapFrame.pinPools[pinTemplate] then
        return
    end

    local hideFiltered = GetOptions():GetHideFilteredPOI()
    local hideUntracked = GetOptions():GetHideUntrackedPOI()
    local showHovered = GetOptions():GetShowHoveredPOI()

    for pin in mapFrame.pinPools[pinTemplate]:EnumerateActive() do
        if pin and pin.questID and IsWorldQuest(pin.questID) then
            local entry = (type(lookup) == "table" and lookup[pin.questID]) or BuildQuestEntry(pin.questID, mapID)
            local shouldHide = false
            if hideFiltered and entry then
                shouldHide = not self:QuestMatchesFilters(entry)
            end
            if hideUntracked and IsQuestTracked(pin.questID) ~= true then
                shouldHide = true
            end
            if showHovered and self.hoveredQuestID == pin.questID then
                shouldHide = false
            end

            if shouldHide then
                pin:Hide()
            else
                pin:Show()
            end
        end
    end
end

function WorldQuests:EnsureProviderHooked()
    if self.providerHooked then
        return
    end

    local dataProvider = self:GetWorldQuestDataProvider()
    if not dataProvider or not dataProvider.RefreshAllData then
        return
    end

    hooksecurefunc(dataProvider, "RefreshAllData", function(provider)
        WorldQuests:PostProcessWorldQuestPins(provider)
    end)

    self.providerHooked = true
end

function WorldQuests:QueueMapPinRefresh()
    if self.pendingPinRefresh then
        return
    end

    self.pendingPinRefresh = true
    local function Run()
        self.pendingPinRefresh = false
        if not self:IsEnabled() or (InCombatLockdown and InCombatLockdown()) then
            self.pendingPinRefresh = true
            return
        end

        self:EnsureProviderHooked()
        local provider = self:GetWorldQuestDataProvider()
        if provider and provider.RefreshAllData then
            provider:RefreshAllData()
        end
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, Run)
    else
        Run()
    end
end

function WorldQuests:TryInitializeWorldMapTab()
    if self.worldMapInitialized then
        return true
    end
    if not GetOptions():GetShowWorldMapTab() then
        return false
    end

    if not _G.WorldMapFrame and type(_G.WorldMapFrame_LoadUI) == "function" then
        SafeCall(_G.WorldMapFrame_LoadUI)
    end
    if not _G.WorldMapFrame then
        return false
    end

    self:CreateWorldMapButton()
    self:CreateWorldMapPanel()
    if not self.worldMapButton or not self.worldMapPanel then
        return false
    end

    self:HookWorldMapTabSiblings()
    self:EnsureProviderHooked()
    self.worldMapInitialized = true
    return true
end

function WorldQuests:RefreshNow(reason)
    if not self:IsEnabled() then
        return
    end

    self.dataDirty = true
    if GetOptions():GetShowWorldMapTab() then
        self:TryInitializeWorldMapTab()
        if self.worldMapButton then
            self.worldMapButton:Show()
            self:LayoutWorldMapButton()
        end
    else
        if self.worldMapButton then
            self.worldMapButton:Hide()
        end
        self:HideWorldMapPanel()
    end

    if self.worldMapPanel and self.worldMapPanel:IsShown() then
        self:RenderBrowser(self.worldMapPanel)
    end

    if reason ~= "hover" then
        self:QueueMapPinRefresh()
    end
end

function WorldQuests:HandleQuestUpdate()
    self.dataDirty = true
    self:QueueRefresh("quest", 0.05)
end

function WorldQuests:OnEnable()
    self.dataDirty = true

    local debugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if debugConsole and debugConsole.RegisterSource then
        debugConsole:RegisterSource(DEBUG_SOURCE, {
            title = "World Quests",
            order = 31,
            aliases = { "worldquests", "wq" },
            maxLines = 80,
            isEnabled = function()
                return false
            end,
        })
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleQuestUpdate")
    self:RegisterEvent("QUEST_LOG_UPDATE", "HandleQuestUpdate")
    self:RegisterEvent("QUEST_DATA_LOAD_RESULT", "HandleQuestUpdate")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "HandleQuestUpdate")
    self:RegisterEvent("SUPER_TRACKING_CHANGED", "HandleQuestUpdate")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "HandleQuestUpdate")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if self.refreshQueued or self.pendingPinRefresh then
            self.refreshQueued = false
            self.pendingPinRefresh = false
            self:QueueRefresh("regen", 0)
        end
    end)

    self:TryInitializeWorldMapTab()
    if _G.WorldMapFrame then
        hooksecurefunc(_G.WorldMapFrame, "OnMapChanged", function()
            if WorldQuests:IsEnabled() then
                WorldQuests.dataDirty = true
                WorldQuests:QueueRefresh("map", 0.1)
            end
        end)
    end

    self:RefreshNow("enable")
end

function WorldQuests:OnDisable()
    self:UnregisterAllEvents()
    self:HideWorldMapPanel()
    if self.worldMapButton then
        self.worldMapButton:Hide()
    end
    self.hoveredQuestID = nil
    self.dataDirty = true
    local provider = self:GetWorldQuestDataProvider()
    if provider and provider.RefreshAllData then
        provider:RefreshAllData()
    end
end