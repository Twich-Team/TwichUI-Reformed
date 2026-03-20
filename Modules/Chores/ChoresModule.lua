---@diagnostic disable: undefined-field
--[[
    Weekly chore tracking for selected Midnight activities.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class ChoresModule : AceModule, AceEvent-3.0, AceTimer-3.0
---@field state table
---@field refreshTimer any
local Chores = T:NewModule("Chores", "AceEvent-3.0", "AceTimer-3.0")
Chores:SetEnabledState(false)

local C_QuestLog = _G.C_QuestLog
local C_AreaPoiInfo = _G.C_AreaPoiInfo
local C_CurrencyInfo = _G.C_CurrencyInfo
local C_Map = _G.C_Map
local C_TaskQuest = _G.C_TaskQuest
local GetQuestProgressBarPercent = _G.GetQuestProgressBarPercent
local GetAccountExpansionLevel = _G.GetAccountExpansionLevel
local GetLFGDungeonInfo = _G.GetLFGDungeonInfo
local GetLFGDungeonNumEncounters = _G.GetLFGDungeonNumEncounters
local GetNumRFDungeons = _G.GetNumRFDungeons
local GetRFDungeonInfo = _G.GetRFDungeonInfo
local LegacyLoadAddOn = _G.LoadAddOn
local PVEFrameLoadUI = _G.PVEFrame_LoadUI
local UnitLevel = _G.UnitLevel
local OPTIONAL_OBJECTIVE = _G.OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION and
_G.OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION:gsub("%%s", ".+"):gsub("([%(%)])", "%%%1") or nil

local STATUS_NOT_STARTED = 0
local STATUS_IN_PROGRESS = 1
local STATUS_COMPLETED = 2
local COFFER_KEY_CURRENCY_ID = 3028
local COFFER_KEY_SHARD_CURRENCY_ID = 3310
local EXPANSION_WAR_WITHIN = 10
local EXPANSION_MIDNIGHT = 11

local CATEGORY_DATA = {
    {
        key = "delves",
        name = "Delves",
        icon = "Interface\\Icons\\inv_misc_map08",
        minimumLevel = 80,
        filter = function(playerLevel)
            return playerLevel < 90
        end,
        pick = 8,
        entries = {
            { quest = 93384 },
            { quest = 93372 },
            { quest = 93409 },
            { quest = 93410 },
            { quest = 93421 },
            { quest = 93416 },
            { quest = 93428 },
            { quest = 93427 },
        },
    },
    {
        key = "abundance",
        name = "Abundance",
        icon = 134569,
        minimumLevel = 80,
        entries = {
            { quest = 89507 },
        },
    },
    {
        key = "unity",
        name = "Unity",
        icon = "Interface\\Icons\\achievement_guildperk_everybodysfriend",
        minimumLevel = 90,
        entries = {
            { quest = 93890 },
            { quest = 93767 },
            { quest = 94457 },
            { quest = 93909 },
            { quest = 93911 },
            { quest = 93769 },
            { quest = 93891 },
            { quest = 93910 },
            { quest = 93912 },
            { quest = 93889 },
            { quest = 93892 },
            { quest = 93913 },
            { quest = 93766 },
        },
    },
    {
        key = "hope",
        name = "Hope",
        icon = "Interface\\Icons\\spell_holy_holynova",
        minimumLevel = 80,
        filter = function(playerLevel)
            return playerLevel < 90
        end,
        entries = {
            { quest = 95468 },
        },
    },
    {
        key = "soiree",
        name = "Soiree",
        icon = "Interface\\Icons\\inv_misc_food_13",
        minimumLevel = 80,
        entries = {
            { quest = 90573 },
            { quest = 90574 },
            { quest = 90575 },
            { quest = 90576 },
        },
    },
    {
        key = "stormarion",
        name = "Stormarion",
        icon = "Interface\\Icons\\spell_nature_lightning",
        minimumLevel = 80,
        entries = {
            { quest = 90962 },
        },
    },
    {
        key = "specialAssignment",
        name = "Special Assignment",
        icon = "Interface\\Icons\\inv_scroll_11",
        minimumLevel = 80,
        pick = 2,
        alwaysShowObjectives = true,
        entries = {
            { quest = 91390, unlockQuest = 94865 },
            { quest = 91796, unlockQuest = 94866 },
            { quest = 92063, unlockQuest = 94390 },
            { quest = 92139, unlockQuest = 95435 },
            { quest = 92145, unlockQuest = 92848 },
            { quest = 93013, unlockQuest = 94391 },
            { quest = 93244, unlockQuest = 94795 },
            { quest = 93438, unlockQuest = 94743 },
        },
    },
    {
        key = "dungeon",
        name = "Dungeon",
        icon = "Interface\\Icons\\achievement_dungeon_azjolkahet_dungeon",
        iconAtlas = "Dungeon",
        minimumLevel = 90,
        oncePerAccount = true,
        alwaysQuestName = true,
        entries = {
            { quest = 93751 },
            { quest = 93752 },
            { quest = 93753 },
            { quest = 93754 },
            { quest = 93755 },
            { quest = 93756 },
            { quest = 93757 },
            { quest = 93758 },
        },
    },
}

local BOUNTIFUL_DELVE_DATA = {
    warWithin = {
        key = "warWithin",
        name = EXPANSION_NAME10,
        zones = {
            {
                uiMapId = 2248,
                pois = {
                    { active = 7779, inactive = 7864, quest = 82939 },
                    { active = 7781, inactive = 7865, quest = 82941 },
                    { active = 7787, inactive = 7863, quest = 82944 },
                },
            },
            {
                uiMapId = 2214,
                pois = {
                    { active = 7782, inactive = 7866, quest = 82945 },
                    { active = 7788, inactive = 7867, quest = 82938 },
                    { active = 8181, inactive = 8143, quest = 85187 },
                },
            },
            {
                uiMapId = 2215,
                pois = {
                    { active = 7780, inactive = 7869, quest = 82940 },
                    { active = 7783, inactive = 7870, quest = 82937 },
                    { active = 7785, inactive = 7868, quest = 82777 },
                    { active = 7789, inactive = 7871, quest = 78508 },
                },
            },
            {
                uiMapId = 2255,
                pois = {
                    { active = 7784, inactive = 7873, quest = 82776 },
                    { active = 7786, inactive = 7872, quest = 82943 },
                    { active = 7790, inactive = 7874, quest = 82942 },
                },
            },
            {
                uiMapId = 2346,
                pois = {
                    { active = 8246, inactive = 8140, quest = 85668 },
                },
            },
            {
                uiMapId = 2371,
                pois = {
                    { active = 8273, inactive = 8274, quest = 0 },
                },
            },
        },
    },
    midnight = {
        key = "midnight",
        name = "Midnight",
        zones = {
            {
                uiMapId = 2395,
                pois = {
                    { active = 8426, inactive = 8425, quest = 91186 },
                    { active = 8438, inactive = 8437, quest = 91189 },
                },
            },
            {
                uiMapId = 2405,
                pois = {
                    { active = 8432, inactive = 8431, quest = 91184 },
                    { active = 8430, inactive = 8429, quest = 91183 },
                },
            },
            {
                uiMapId = 2413,
                pois = {
                    { active = 8434, inactive = 8433, quest = 91185 },
                    { active = 8436, inactive = 8435, quest = 91187 },
                },
            },
            {
                uiMapId = 2437,
                pois = {
                    { active = 8444, inactive = 8443, quest = 91188 },
                    { active = 8442, inactive = 8441, quest = 91190 },
                },
            },
        },
    },
}

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

local function GetCurrentExpansionContentKey()
    local expansionLevel = type(GetAccountExpansionLevel) == "function" and GetAccountExpansionLevel() or nil
    if expansionLevel == EXPANSION_MIDNIGHT then
        return "midnight"
    end
    if expansionLevel == EXPANSION_WAR_WITHIN then
        return "warWithin"
    end
    return nil
end

local function GetBountifulKeyInfoText()
    local keyCount = 0
    local shardCount = 0

    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local keyInfo = C_CurrencyInfo.GetCurrencyInfo(COFFER_KEY_CURRENCY_ID)
        local shardInfo = C_CurrencyInfo.GetCurrencyInfo(COFFER_KEY_SHARD_CURRENCY_ID)
        keyCount = keyInfo and keyInfo.quantity or 0
        shardCount = shardInfo and shardInfo.quantity or 0
    end

    local parts = {
        T.Tools.Text.Color(T.Tools.Colors.WARNING, tostring(keyCount)),
        " |T4622270:0|t",
    }

    if shardCount > 0 then
        table.insert(parts, " ")
        table.insert(parts, T.Tools.Text.Color(T.Tools.Colors.WARNING, tostring(shardCount)))
        table.insert(parts, " |T133016:0|t")
    end

    return " " ..
    T.Tools.Text.Color(T.Tools.Colors.GRAY, "[") .. table.concat(parts) .. T.Tools.Text.Color(T.Tools.Colors.GRAY, "]")
end

local function GetRaidWingEntries()
    EnsureGroupFinderLoaded()

    local currentExpansionLevel = type(GetAccountExpansionLevel) == "function" and GetAccountExpansionLevel() or nil
    local raidWings = {}

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

local function GetOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.Chores
end

local function GetQuestTitle(questID)
    if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local title = C_QuestLog.GetTitleForQuestID(questID)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end

    return ("Quest #%d"):format(questID)
end

local function ShouldKeepObjective(objective)
    if type(objective) ~= "table" then
        return false
    end

    if objective.text == "" then
        return true
    end

    if OPTIONAL_OBJECTIVE and string.match(objective.text or "", OPTIONAL_OBJECTIVE) then
        return false
    end

    return true
end

local function BuildObjectiveState(questID, objective)
    local objectiveState = {
        type = objective.type,
        text = string.gsub(objective.text or "", ":18:18:0:2%%|a", ":0:0:0:2|a"),
    }

    if objective.type == "progressbar" then
        objectiveState.have = GetQuestProgressBarPercent and GetQuestProgressBarPercent(questID) or 0
        objectiveState.need = 100
    elseif objective.numFulfilled == 1 and objective.numRequired == 1 and objective.finished == false then
        objectiveState.have = 0
        objectiveState.need = 1
    else
        objectiveState.have = objective.numFulfilled or 0
        objectiveState.need = objective.numRequired or 0
    end

    return objectiveState
end

local function GetQuestState(questID)
    local accountCompleted = C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompletedOnAccount) == "function" and
        C_QuestLog.IsQuestFlaggedCompletedOnAccount(questID) or false
    local state = {
        questID = questID,
        title = GetQuestTitle(questID),
        status = STATUS_NOT_STARTED,
        accountCompleted = accountCompleted,
        objectives = {},
    }

    if C_QuestLog and type(C_QuestLog.IsQuestFlaggedCompleted) == "function" and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        state.status = STATUS_COMPLETED
        return state
    end

    local isOnQuest = C_QuestLog and type(C_QuestLog.IsOnQuest) == "function" and C_QuestLog.IsOnQuest(questID)
    local isWorldQuest = C_QuestLog and type(C_QuestLog.IsWorldQuest) == "function" and C_QuestLog.IsWorldQuest(questID)
    local hasWorldQuestTime = C_TaskQuest and type(C_TaskQuest.GetQuestTimeLeftSeconds) == "function" and
    C_TaskQuest.GetQuestTimeLeftSeconds(questID)

    if isOnQuest or (isWorldQuest and hasWorldQuestTime) then
        state.status = STATUS_IN_PROGRESS
        if C_QuestLog and type(C_QuestLog.GetQuestObjectives) == "function" then
            local objectives = C_QuestLog.GetQuestObjectives(questID)
            if type(objectives) == "table" then
                for _, objective in ipairs(objectives) do
                    if ShouldKeepObjective(objective) then
                        table.insert(state.objectives, BuildObjectiveState(questID, objective))
                    end
                end
            end
        end
    end

    return state
end

local function CloneEntry(entry)
    local cloned = {}
    for key, value in pairs(entry) do
        cloned[key] = value
    end
    return cloned
end

local function ResolveEntryState(entry, category)
    local questIDs = { entry.quest }
    if entry.actualQuest then
        table.insert(questIDs, entry.actualQuest)
    end
    if entry.unlockQuest then
        table.insert(questIDs, entry.unlockQuest)
    end

    local fallbackState = nil
    for index, questID in ipairs(questIDs) do
        local state = GetQuestState(questID)
        if category.oncePerAccount and questID ~= entry.unlockQuest and state.accountCompleted then
            state.status = STATUS_COMPLETED
        end

        state.sourceQuestID = questID
        fallbackState = state

        if state.status > STATUS_NOT_STARTED or index == #questIDs then
            return state
        end
    end

    return fallbackState
end

local function SortEntries(left, right)
    if left.state.status ~= right.state.status then
        return left.state.status > right.state.status
    end

    local leftTitle = left.state.title or left.label or ""
    local rightTitle = right.state.title or right.label or ""
    return leftTitle < rightTitle
end

local function BuildSimpleSummary(key, name, icon, iconAtlas)
    return {
        key = key,
        name = name,
        icon = icon,
        iconAtlas = iconAtlas,
        active = true,
        visible = true,
        total = 0,
        completed = 0,
        remaining = 0,
        status = STATUS_NOT_STARTED,
        entries = {},
        selectedEntries = {},
        showPendingEntries = false,
    }
end

function Chores:BuildCategorySummary(category, playerLevel)
    local summary = BuildSimpleSummary(category.key, category.name, category.icon, category.iconAtlas)
    summary.total = category.pick or 1

    if playerLevel < (category.minimumLevel or 1) then
        summary.visible = false
        summary.active = false
        return summary
    end

    if category.filter and not category.filter(playerLevel) then
        summary.visible = false
        summary.active = false
        return summary
    end

    local resolvedEntries = {}
    for _, entry in ipairs(category.entries) do
        local entryState = ResolveEntryState(entry, category)
        table.insert(resolvedEntries, {
            data = CloneEntry(entry),
            state = entryState,
            label = entryState.title,
        })
    end

    table.sort(resolvedEntries, SortEntries)

    local pickCount = category.pick or 1
    local completedCount = 0
    for _, resolvedEntry in ipairs(resolvedEntries) do
        if resolvedEntry.state.status == STATUS_COMPLETED then
            completedCount = completedCount + 1
        end
    end

    summary.completed = math.min(completedCount, pickCount)
    summary.remaining = math.max(pickCount - summary.completed, 0)

    if summary.completed >= pickCount then
        summary.status = STATUS_COMPLETED
    else
        for _, resolvedEntry in ipairs(resolvedEntries) do
            if resolvedEntry.state.status == STATUS_IN_PROGRESS then
                summary.status = STATUS_IN_PROGRESS
                break
            end
        end
    end

    summary.entries = resolvedEntries

    if category.pick and category.pick > 1 then
        local desiredEntries = math.max(summary.remaining, 1)
        for _, resolvedEntry in ipairs(resolvedEntries) do
            if resolvedEntry.state.status ~= STATUS_COMPLETED then
                table.insert(summary.selectedEntries, resolvedEntry)
            end
            if #summary.selectedEntries >= desiredEntries then
                break
            end
        end

        if #summary.selectedEntries == 0 then
            for _, resolvedEntry in ipairs(resolvedEntries) do
                table.insert(summary.selectedEntries, resolvedEntry)
                if #summary.selectedEntries >= math.min(pickCount, 2) then
                    break
                end
            end
        end
    else
        summary.selectedEntries[1] = resolvedEntries[1]
    end

    return summary
end

function Chores:BuildBountifulDelvesSummary()
    local options = GetOptions()
    local summary = BuildSimpleSummary("bountifulDelves", "Bountiful Delves", "Interface\\Icons\\inv_misc_map08")
    summary.showPendingEntries = true
    summary.infoText = GetBountifulKeyInfoText()

    if not options:GetTrackBountifulDelves() then
        summary.active = false
        summary.visible = false
        return summary
    end

    local dataKey = GetCurrentExpansionContentKey()
    local delveData = dataKey and BOUNTIFUL_DELVE_DATA[dataKey] or nil
    if not delveData or not C_AreaPoiInfo or type(C_AreaPoiInfo.GetAreaPOIInfo) ~= "function" then
        summary.active = false
        summary.visible = false
        return summary
    end

    for _, zone in ipairs(delveData.zones) do
        local mapName = "Unknown Zone"
        if C_Map and type(C_Map.GetMapInfo) == "function" then
            local mapInfo = C_Map.GetMapInfo(zone.uiMapId)
            mapName = mapInfo and mapInfo.name or mapName
        end

        for _, poi in ipairs(zone.pois) do
            local activePoi = C_AreaPoiInfo.GetAreaPOIInfo(zone.uiMapId, poi.active)
            local inactivePoi = C_AreaPoiInfo.GetAreaPOIInfo(zone.uiMapId, poi.inactive)
            local questState = poi.quest and poi.quest > 0 and GetQuestState(poi.quest) or nil

            if activePoi then
                local entry = {
                    data = CloneEntry(poi),
                    state = {
                        title = ("%s: %s"):format(mapName, activePoi.name or "Bountiful Delve"),
                        status = STATUS_NOT_STARTED,
                        objectives = {},
                    },
                }

                summary.total = summary.total + 1
                table.insert(summary.entries, entry)
                table.insert(summary.selectedEntries, entry)
            elseif inactivePoi and questState and questState.status == STATUS_COMPLETED then
                local entry = {
                    data = CloneEntry(poi),
                    state = {
                        title = ("%s: %s"):format(mapName, inactivePoi.name or "Bountiful Delve"),
                        status = STATUS_COMPLETED,
                        objectives = {},
                    },
                }

                summary.total = summary.total + 1
                summary.completed = summary.completed + 1
                table.insert(summary.entries, entry)
            end
        end
    end

    if summary.total == 0 then
        summary.active = false
        summary.visible = false
        return summary
    end

    summary.remaining = math.max(summary.total - summary.completed, 0)
    if summary.remaining == 0 then
        summary.status = STATUS_COMPLETED
    elseif summary.completed > 0 then
        summary.status = STATUS_IN_PROGRESS
    end

    table.sort(summary.entries, SortEntries)
    table.sort(summary.selectedEntries, SortEntries)
    return summary
end

function Chores:BuildRaidFinderSummary()
    local options = GetOptions()
    local summary = BuildSimpleSummary("raidFinder", "Raid Finder", nil, "Raid")
    summary.showPendingEntries = true

    for _, raidWing in ipairs(GetRaidWingEntries()) do
        if options:IsRaidWingEnabled(raidWing.dungeonID) then
            summary.total = summary.total + 1

            local numEncounters, numCompleted =
            type(GetLFGDungeonNumEncounters) == "function" and GetLFGDungeonNumEncounters(raidWing.dungeonID) or nil, nil
            if type(numEncounters) == "number" then
                numCompleted = select(2, GetLFGDungeonNumEncounters(raidWing.dungeonID))
            end

            local wingState = {
                title = raidWing.name,
                status = STATUS_NOT_STARTED,
                objectives = {},
            }

            if type(numEncounters) == "number" and numEncounters > 0 then
                local completedEncounters = type(numCompleted) == "number" and numCompleted or 0
                if completedEncounters >= numEncounters then
                    wingState.status = STATUS_COMPLETED
                    summary.completed = summary.completed + 1
                    wingState.title = ("%s (%d/%d)"):format(raidWing.name, completedEncounters, numEncounters)
                elseif completedEncounters > 0 then
                    wingState.status = STATUS_IN_PROGRESS
                    wingState.title = ("%s (%d/%d)"):format(raidWing.name, completedEncounters, numEncounters)
                end
            end

            local entry = {
                data = {
                    dungeonID = raidWing.dungeonID,
                },
                state = wingState,
            }

            table.insert(summary.entries, entry)
            if wingState.status ~= STATUS_COMPLETED then
                table.insert(summary.selectedEntries, entry)
            end
        end
    end

    if summary.total == 0 then
        summary.active = false
        summary.visible = false
        return summary
    end

    summary.remaining = math.max(summary.total - summary.completed, 0)
    if summary.remaining == 0 then
        summary.status = STATUS_COMPLETED
    elseif summary.completed > 0 or #summary.selectedEntries < summary.total then
        summary.status = STATUS_IN_PROGRESS
    end

    table.sort(summary.entries, SortEntries)
    table.sort(summary.selectedEntries, SortEntries)
    return summary
end

function Chores:RefreshState()
    if self.refreshTimer then
        self:CancelTimer(self.refreshTimer)
        self.refreshTimer = nil
    end

    local options = GetOptions()
    local playerLevel = UnitLevel("player") or 0
    local state = {
        playerLevel = playerLevel,
        enabled = options:GetEnabled(),
        totalRemaining = 0,
        totalTracked = 0,
        categories = {},
        orderedCategories = {},
    }

    if not state.enabled then
        self.state = state
        self:SendMessage("TWICHUI_CHORES_UPDATED", state)
        return
    end

    for _, category in ipairs(CATEGORY_DATA) do
        if options:IsCategoryEnabled(category.key) then
            local summary = self:BuildCategorySummary(category, playerLevel)
            if summary.active then
                state.totalRemaining = state.totalRemaining + summary.remaining
                state.totalTracked = state.totalTracked + summary.total
                state.categories[category.key] = summary
                table.insert(state.orderedCategories, summary)
            end
        end
    end

    local bountifulDelvesSummary = self:BuildBountifulDelvesSummary()
    if bountifulDelvesSummary.active then
        state.totalRemaining = state.totalRemaining + bountifulDelvesSummary.remaining
        state.totalTracked = state.totalTracked + bountifulDelvesSummary.total
        state.categories[bountifulDelvesSummary.key] = bountifulDelvesSummary
        table.insert(state.orderedCategories, bountifulDelvesSummary)
    end

    local raidFinderSummary = self:BuildRaidFinderSummary()
    if raidFinderSummary.active then
        state.totalRemaining = state.totalRemaining + raidFinderSummary.remaining
        state.totalTracked = state.totalTracked + raidFinderSummary.total
        state.categories[raidFinderSummary.key] = raidFinderSummary
        table.insert(state.orderedCategories, raidFinderSummary)
    end

    self.state = state
    self:SendMessage("TWICHUI_CHORES_UPDATED", state)
end

function Chores:RequestRefresh(immediate)
    if immediate == true then
        self:RefreshState()
        return
    end

    if self.refreshTimer then
        return
    end

    self.refreshTimer = self:ScheduleTimer("RefreshState", 0.2)
end

function Chores:GetState()
    if not self.state then
        self:RefreshState()
    end
    return self.state
end

function Chores:GetRemainingCount()
    local state = self:GetState()
    return state and state.totalRemaining or 0
end

function Chores:OnQuestEvent()
    self:RequestRefresh(false)
end

function Chores:OnCurrencyEvent()
    self:RequestRefresh(false)
end

function Chores:OnDelveEvent()
    self:RequestRefresh(false)
end

function Chores:OnLFGEvent()
    self:RequestRefresh(false)
end

function Chores:OnRefreshEvent()
    self:RequestRefresh(false)
end

function Chores:UNIT_QUEST_LOG_CHANGED(_, unitToken)
    if unitToken == "player" then
        self:RequestRefresh(false)
    end
end

function Chores:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnRefreshEvent")
    self:RegisterEvent("PLAYER_LEVEL_UP", "OnRefreshEvent")
    self:RegisterEvent("AREA_POIS_UPDATED", "OnDelveEvent")
    self:RegisterEvent("CURRENCY_DISPLAY_UPDATE", "OnCurrencyEvent")
    self:RegisterEvent("LFG_LOCK_INFO_RECEIVED", "OnLFGEvent")
    self:RegisterEvent("LFG_UPDATE_RANDOM_INFO", "OnLFGEvent")
    self:RegisterEvent("QUEST_ACCEPTED", "OnQuestEvent")
    self:RegisterEvent("QUEST_REMOVED", "OnQuestEvent")
    self:RegisterEvent("QUEST_TURNED_IN", "OnQuestEvent")
    self:RegisterEvent("QUEST_LOG_UPDATE", "OnQuestEvent")
    self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
    self:RefreshState()
end

function Chores:OnDisable()
    if self.refreshTimer then
        self:CancelTimer(self.refreshTimer)
        self.refreshTimer = nil
    end

    self.state = {
        enabled = false,
        totalRemaining = 0,
        totalTracked = 0,
        categories = {},
        orderedCategories = {},
    }
    self:SendMessage("TWICHUI_CHORES_UPDATED", self.state)
end
