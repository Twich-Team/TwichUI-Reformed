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
local C_MajorFactions = _G.C_MajorFactions
local C_Map = _G.C_Map
local C_SpellBook = _G.C_SpellBook
local C_TaskQuest = _G.C_TaskQuest
local C_TradeSkillUI = _G.C_TradeSkillUI
local GetQuestProgressBarPercent = _G.GetQuestProgressBarPercent
local GetAccountExpansionLevel = _G.GetAccountExpansionLevel
local GetProfessionInfo = _G.GetProfessionInfo
local GetProfessions = _G.GetProfessions
local GetLFGDungeonInfo = _G.GetLFGDungeonInfo
local GetLFGDungeonEncounterInfo = _G.GetLFGDungeonEncounterInfo
local GetLFGDungeonNumEncounters = _G.GetLFGDungeonNumEncounters
local GetNumRFDungeons = _G.GetNumRFDungeons
local GetRFDungeonInfo = _G.GetRFDungeonInfo
local GetTime = _G.GetTime
local floor = _G.floor
local LegacyLoadAddOn = _G.LoadAddOn
local PVEFrameLoadUI = _G.PVEFrame_LoadUI
local UnitLevel = _G.UnitLevel
local LegacyIsPlayerSpell = rawget(_G, "IsPlayerSpell")
local LegacyIsSpellKnown = rawget(_G, "IsSpellKnown")
local IsProfessionSpellKnown = (C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" and C_SpellBook.IsSpellKnown) or
    LegacyIsPlayerSpell or LegacyIsSpellKnown
local OPTIONAL_OBJECTIVE = _G.OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION and
    _G.OPTIONAL_QUEST_OBJECTIVE_DESCRIPTION:gsub("%%s", ".+"):gsub("([%(%)])", "%%%1") or nil

local STATUS_NOT_STARTED = 0
local STATUS_IN_PROGRESS = 1
local STATUS_COMPLETED = 2
local STATUS_UNKNOWN = -1
local MIN_REFRESH_INTERVAL_SECONDS = 1
local COFFER_KEY_CURRENCY_ID = 3028
local COFFER_KEY_SHARD_CURRENCY_ID = 3310
local EXPANSION_WAR_WITHIN = 10
local EXPANSION_MIDNIGHT = 11
local PREY_TARGETS_PER_DIFFICULTY = 4
local PREY_ICON =
"Interface\\AddOns\\TwichUI_Reformed\\Modules\\Chores\\Plumber\\Art\\ExpansionLandingPage\\Icons\\InProgressPrey.png"
local ASTALOR_PREY_MAP_ID = 2393
local ASTALOR_PREY_X = 0.55
local ASTALOR_PREY_Y = 0.634

local PROFESSION_CATEGORY_DATA = {
    {
        key = "professionAlchemy",
        name = "Alchemy",
        baseSkillLineId = 171,
        childSkillLineId = 2906,
        professionSpellID = 2259,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93529, item = 259189, name = "Aged Cruor" }, { quest = 93528, item = 259188, name = "Lightbloomed Spore Sample" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003189, currency = 3189 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95127 } } },
            { key = "orders",      name = "Orders",         sources = { { quest = 93690 } } },
        },
    },
    {
        key = "professionBlacksmithing",
        name = "Blacksmithing",
        baseSkillLineId = 164,
        childSkillLineId = 2907,
        professionSpellID = 2018,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93531, item = 259191, name = "Infused Quenching Oil" }, { quest = 93530, item = 259190, name = "Thalassian Whestone" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003199, currency = 3199 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95128 } } },
            { key = "orders",      name = "Orders",         sources = { { quest = 93691 } } },
        },
    },
    {
        key = "professionEnchanting",
        name = "Enchanting",
        baseSkillLineId = 333,
        childSkillLineId = 2909,
        professionSpellID = 7411,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93533, item = 259193, name = "Lost Thalassian Vellum" }, { quest = 93532, item = 259192, name = "Voidstorm Ashes" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003198, currency = 3198 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95129 } } },
        },
    },
    {
        key = "professionEngineering",
        name = "Engineering",
        baseSkillLineId = 202,
        childSkillLineId = 2910,
        professionSpellID = 4036,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93534, item = 259194, name = "Dance Gear" }, { quest = 93535, item = 259195, name = "Dawn Capacitor" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003197, currency = 3197 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95138 } } },
            { key = "orders",      name = "Orders",         sources = { { quest = 93692 } } },
        },
    },
    {
        key = "professionHerbalism",
        name = "Herbalism",
        baseSkillLineId = 182,
        childSkillLineId = 2912,
        professionSpellID = 2366,
        entries = {
            { key = "catchup",  name = "Catchup",  sources = { { quest = 5003196, currency = 3196 } } },
            { key = "treatise", name = "Treatise", sources = { { quest = 95130 } } },
        },
    },
    {
        key = "professionInscription",
        name = "Inscription",
        baseSkillLineId = 773,
        childSkillLineId = 2913,
        professionSpellID = 45357,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93536, item = 259196, name = "Brilliant Phoenix Ink" }, { quest = 93537, item = 259197, name = "Loa-Blessed Rune" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003195, currency = 3195 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95131 } } },
            { key = "orders",      name = "Orders",         sources = { { quest = 93693 } } },
        },
    },
    {
        key = "professionJewelcrafting",
        name = "Jewelcrafting",
        baseSkillLineId = 755,
        childSkillLineId = 2914,
        professionSpellID = 25229,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93539, item = 259199, name = "Harandar Stone Sample" }, { quest = 93538, item = 259198, name = "Void-Touched Eversong Diamond Fragments" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003194, currency = 3194 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95133 } } },
            { key = "orders",      name = "Orders",         sources = { { quest = 93694 } } },
        },
    },
    {
        key = "professionLeatherworking",
        name = "Leatherworking",
        baseSkillLineId = 165,
        childSkillLineId = 2915,
        professionSpellID = 2108,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93540, item = 259200, name = "Amani Tanning Oil" }, { quest = 93541, item = 259201, name = "Thalassian Mana Oil" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003193, currency = 3193 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95134 } } },
            { key = "orders",      name = "Orders",         sources = { { quest = 93695 } } },
        },
    },
    {
        key = "professionMining",
        name = "Mining",
        baseSkillLineId = 186,
        childSkillLineId = 2916,
        professionSpellID = 2575,
        entries = {
            { key = "catchup",  name = "Catchup",  sources = { { quest = 5003192, currency = 3192 } } },
            { key = "treatise", name = "Treatise", sources = { { quest = 95135 } } },
        },
    },
    {
        key = "professionSkinning",
        name = "Skinning",
        baseSkillLineId = 393,
        childSkillLineId = 2917,
        professionSpellID = 8613,
        entries = {
            { key = "catchup",  name = "Catchup",  sources = { { quest = 5003191, currency = 3191 } } },
            { key = "treatise", name = "Treatise", sources = { { quest = 95136 } } },
        },
    },
    {
        key = "professionTailoring",
        name = "Tailoring",
        baseSkillLineId = 197,
        childSkillLineId = 2918,
        professionSpellID = 3908,
        entries = {
            { key = "mobTreasure", name = "Mobs/Treasures", sources = { { quest = 93542, item = 259202, name = "Embroidered Memento" }, { quest = 93543, item = 259203, name = "Finely Woven Lynx Collar" } } },
            { key = "catchup",     name = "Catchup",        sources = { { quest = 5003190, currency = 3190 } } },
            { key = "treatise",    name = "Treatise",       sources = { { quest = 95137 } } },
            { key = "orders",      name = "Orders",         sources = { { quest = 93696 } } },
        },
    },
}

local CATEGORY_DATA = {
    {
        key = "delves",
        name = "Delver's Call",
        iconAtlas = "delves-regular",
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
        iconAtlas = "UI-EventPoi-abundancebountiful",
        minimumLevel = 80,
        entries = {
            { quest = 89507 },
        },
    },
    {
        key = "unity",
        name = "Unity Against the Void",
        icon = "Interface\\Icons\\Inv_nullstone_void",
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
        name = "Legends of the Haranir",
        icon = "Interface\\Icons\\Inv_achievement_zone_harandar",
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
        name = "Saltheril's Soiree",
        iconAtlas = "UI-EventPoi-saltherilssoiree",
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
        name = "Stormarion Assault",
        iconAtlas = "UI-EventPoi-stormarionassault",
        minimumLevel = 80,
        entries = {
            { quest = 90962 },
        },
    },
    {
        key = "specialAssignment",
        name = "Special Assignment",
        iconAtlas = "worldquest-Capstone-questmarker-epic-locked",
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

local function AddQuestsByPattern(tbl, fromID, step, times)
    local questID = fromID - step

    for _ = 1, times do
        questID = questID + step
        table.insert(tbl, questID)
    end
end

local PREY_DIFFICULTY_DATA = {
    {
        key = "normal",
        name = "Normal",
        questIDs = {},
    },
    {
        key = "hard",
        name = "Hard",
        questIDs = {},
    },
    {
        key = "nightmare",
        name = "Nightmare",
        questIDs = {},
    },
}

AddQuestsByPattern(PREY_DIFFICULTY_DATA[1].questIDs, 91095, 1, 30)
AddQuestsByPattern(PREY_DIFFICULTY_DATA[2].questIDs, 91210, 2, 16)
AddQuestsByPattern(PREY_DIFFICULTY_DATA[2].questIDs, 91242, 1, 14)
AddQuestsByPattern(PREY_DIFFICULTY_DATA[3].questIDs, 91211, 2, 16)
AddQuestsByPattern(PREY_DIFFICULTY_DATA[3].questIDs, 91256, 1, 14)

local function GetUnlockedPreyDifficultyNames()
    local renownLevel = C_MajorFactions and type(C_MajorFactions.GetCurrentRenownLevel) == "function" and
        C_MajorFactions.GetCurrentRenownLevel(2764) or nil

    if type(renownLevel) == "number" then
        if renownLevel >= 4 then
            return {
                "Nightmare",
                "Hard",
                "Normal",
            }
        end

        if renownLevel >= 1 then
            return {
                "Hard",
                "Normal",
            }
        end
    end

    return {
        "Normal",
    }
end

local function GetPreyDifficultyDefinition(difficultyName)
    for _, definition in ipairs(PREY_DIFFICULTY_DATA) do
        if definition.name == difficultyName then
            return definition
        end
    end

    return nil
end

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

local function GetBountifulKeyCurrencyCounts()
    local keyCount = 0
    local shardCount = 0

    if C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local keyInfo = C_CurrencyInfo.GetCurrencyInfo(COFFER_KEY_CURRENCY_ID)
        local shardInfo = C_CurrencyInfo.GetCurrencyInfo(COFFER_KEY_SHARD_CURRENCY_ID)
        keyCount = keyInfo and keyInfo.quantity or 0
        shardCount = shardInfo and shardInfo.quantity or 0
    end

    return keyCount, shardCount
end

local function GetBountifulKeyInfoText()
    local keyCount, shardCount = GetBountifulKeyCurrencyCounts()

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
        T.Tools.Text.Color(T.Tools.Colors.GRAY, "[") ..
        table.concat(parts) .. T.Tools.Text.Color(T.Tools.Colors.GRAY, "]")
end

local function GetAreaPOIPositionXY(poiInfo)
    local position = poiInfo and poiInfo.position or nil
    if position and type(position.GetXY) == "function" then
        return position:GetXY()
    end

    return nil, nil
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
        if type(hasWorldQuestTime) == "number" and hasWorldQuestTime > 0 then
            state.timeLeftSeconds = hasWorldQuestTime
        end
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

    if type(state.timeLeftSeconds) == "number" and state.timeLeftSeconds > 0 then
        local totalSeconds = math.max(0, floor(state.timeLeftSeconds))
        local hours = floor(totalSeconds / 3600)
        local minutes = floor((totalSeconds % 3600) / 60)

        if hours > 0 then
            state.timeRemainingText = minutes > 0 and ("%dh %dm"):format(hours, minutes) or ("%dh"):format(hours)
        elseif minutes > 0 then
            state.timeRemainingText = ("%dm"):format(minutes)
        else
            state.timeRemainingText = "<1m"
        end
    end

    if state.status == STATUS_IN_PROGRESS and C_TaskQuest then
        if type(C_TaskQuest.GetQuestZoneID) == "function" then
            state.mapID = C_TaskQuest.GetQuestZoneID(questID)
        end

        if type(state.mapID) == "number" and state.mapID > 0 and type(C_TaskQuest.GetQuestLocation) == "function" then
            local x, y = C_TaskQuest.GetQuestLocation(questID, state.mapID)
            if type(x) == "number" and type(y) == "number" then
                state.x = x
                state.y = y
            end
        end
    end

    return state
end

local function BuildSpecialAssignmentNotificationInfo(state)
    if type(state) ~= "table" then
        return nil
    end

    return {
        questID = state.questID or state.sourceQuestID,
        mapID = state.mapID,
        x = state.x,
        y = state.y,
        buttonText = "Set Waypoint",
        buttonTooltipText = "Place a waypoint for this Special Assignment.",
    }
end

local function CloneEntry(entry)
    local cloned = {}
    for key, value in pairs(entry) do
        cloned[key] = value
    end
    return cloned
end

local function ResolveEntryState(entry, category)
    if category and category.key == "specialAssignment" and entry.unlockQuest then
        local assignmentState = GetQuestState(entry.quest)
        assignmentState.sourceQuestID = entry.quest
        if assignmentState.status == STATUS_COMPLETED then
            return assignmentState
        end

        if entry.actualQuest then
            local actualState = GetQuestState(entry.actualQuest)
            actualState.sourceQuestID = entry.actualQuest
            if actualState.status > STATUS_NOT_STARTED then
                return actualState
            end
        end

        local unlockState = GetQuestState(entry.unlockQuest)
        unlockState.sourceQuestID = entry.unlockQuest
        if unlockState.status == STATUS_COMPLETED then
            assignmentState.status = STATUS_IN_PROGRESS
            assignmentState.notificationKind = "unlocked"
            assignmentState.notificationStatus = STATUS_COMPLETED
            assignmentState.notificationInfo = BuildSpecialAssignmentNotificationInfo(assignmentState)
            return assignmentState
        end

        if unlockState.status > STATUS_NOT_STARTED then
            return unlockState
        end

        return assignmentState.title and assignmentState or unlockState
    end

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

local function ResolveProfessionName(definition)
    if C_TradeSkillUI and type(C_TradeSkillUI.GetTradeSkillDisplayName) == "function" then
        local displayName = C_TradeSkillUI.GetTradeSkillDisplayName(definition.childSkillLineId)
        if type(displayName) == "string" and displayName ~= "" then
            return displayName
        end
    end

    if C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" then
        local professionInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(definition.childSkillLineId)
        if type(professionInfo) == "table" and type(professionInfo.professionName) == "string" and professionInfo.professionName ~= "" then
            return professionInfo.professionName
        end
    end

    return definition.name
end

local function ResolveProfessionIcon(definition)
    if C_Spell and type(C_Spell.GetSpellTexture) == "function" and definition.professionSpellID then
        local iconTexture = C_Spell.GetSpellTexture(definition.professionSpellID)
        if iconTexture then
            return iconTexture
        end
    end

    return nil
end

local function GetCurrencyQuestState(source)
    local quantity = 0
    local maxQuantity = 1

    if source.currency and C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
        local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(source.currency)
        if type(currencyInfo) == "table" then
            quantity = currencyInfo.totalEarned or currencyInfo.quantity or 0
            maxQuantity = currencyInfo.maxQuantity or 1
            if maxQuantity == 0 then
                maxQuantity = 1
            end
        end
    end

    local state = {
        questID = source.quest,
        title = source.name,
        status = quantity >= maxQuantity and STATUS_COMPLETED or STATUS_IN_PROGRESS,
        accountCompleted = quantity >= maxQuantity,
        objectives = {
            {
                text = source.name or "Catchup",
                have = quantity,
                need = maxQuantity,
            },
        },
    }

    if quantity <= 0 then
        state.status = STATUS_NOT_STARTED
    end

    return state
end

local function BuildProfessionSourceObjective(entry, source, sourceState)
    local objective = {
        text = source.name or sourceState.title or entry.name,
        itemID = source.item,
    }
    local progressObjective = type(sourceState.objectives) == "table" and sourceState.objectives[1] or nil

    if type(progressObjective) == "table" then
        if progressObjective.need and progressObjective.need > 0 then
            objective.have = progressObjective.have or 0
            objective.need = progressObjective.need
        end

        if type(progressObjective.text) == "string" and progressObjective.text ~= "" then
            objective.text = progressObjective.text
        end
    end

    if (objective.text == nil or objective.text == "") and source.quest then
        objective.text = GetQuestTitle(source.quest)
    end

    return objective
end

local function BuildNotificationEntryKey(summary, entry)
    local parts = { summary.key or "summary" }
    local data = entry and entry.data or nil

    if type(data) == "table" then
        if type(data.quest) == "number" and data.quest > 0 then
            table.insert(parts, "quest:" .. data.quest)
        elseif type(data.dungeonID) == "number" and data.dungeonID > 0 then
            table.insert(parts, "dungeon:" .. data.dungeonID)
        elseif type(data.key) == "string" and data.key ~= "" then
            table.insert(parts, "key:" .. data.key)
        elseif type(data.active) == "number" and data.active > 0 then
            table.insert(parts, "poi:" .. data.active)
        elseif type(data.inactive) == "number" and data.inactive > 0 then
            table.insert(parts, "poi:" .. data.inactive)
        elseif type(data.name) == "string" and data.name ~= "" then
            table.insert(parts, "name:" .. data.name)
        end
    end

    if #parts == 1 then
        table.insert(parts, entry.label or entry.state.title or "entry")
    end

    return table.concat(parts, "|")
end

local function BuildNotificationLineText(summary, entry)
    local iconText = ""
    if summary.iconAtlas then
        iconText = ("|A:%s:14:14|a "):format(summary.iconAtlas)
    elseif summary.icon then
        iconText = ("|T%s:14:14:0:0|t "):format(tostring(summary.icon))
    end

    local categoryText = ("|cff72c7ff%s|r"):format(summary.name or "Chores")
    local entryTitle = entry.label or (entry.state and entry.state.title) or summary.name or "Chore"
    if entry.state and entry.state.timeRemainingText then
        entryTitle = ("%s |cff7f8c8d(%s left)|r"):format(entryTitle, entry.state.timeRemainingText)
    end
    return ("%s%s |cff7f8c8d-|r %s"):format(iconText, categoryText, entryTitle)
end

local function BuildNotificationSnapshot(state)
    local snapshot = {}

    if type(state) ~= "table" or state.enabled ~= true or type(state.orderedCategories) ~= "table" then
        return snapshot
    end

    for _, summary in ipairs(state.orderedCategories) do
        if summary.active ~= false and type(summary.entries) == "table" then
            for _, entry in ipairs(summary.entries) do
                local key = BuildNotificationEntryKey(summary, entry)
                snapshot[key] = {
                    status = entry.notificationStatus or (entry.state and entry.state.status) or STATUS_NOT_STARTED,
                    kind = entry.notificationKind or (entry.state and entry.state.notificationKind) or nil,
                    notificationInfo = entry.notificationInfo or (entry.state and entry.state.notificationInfo) or nil,
                    summaryKey = summary.key,
                    summaryName = summary.name,
                    lineText = entry.notificationLineText or (entry.state and entry.state.notificationLineText) or
                        BuildNotificationLineText(summary, entry),
                }
            end
        end
    end

    return snapshot
end

local function BuildNotificationChanges(previousSnapshot, currentSnapshot)
    local changes = {
        available = {},
        completed = {},
        unlocked = {},
        unlockedInfo = {},
    }

    for key, currentEntry in pairs(currentSnapshot) do
        local previousEntry = previousSnapshot[key]
        local previousStatus = previousEntry and previousEntry.status or STATUS_COMPLETED
        local currentStatus = currentEntry.status or STATUS_NOT_STARTED

        if previousStatus ~= STATUS_UNKNOWN and currentStatus ~= STATUS_UNKNOWN then
            if currentStatus == STATUS_COMPLETED then
                if currentEntry.kind == "unlocked" then
                    local wasUnlocked = previousEntry and previousStatus == STATUS_COMPLETED and
                    previousEntry.kind == "unlocked"
                    if not wasUnlocked then
                        table.insert(changes.unlocked, currentEntry.lineText)
                        table.insert(changes.unlockedInfo, currentEntry.notificationInfo)
                    end
                elseif previousEntry and (previousStatus ~= STATUS_COMPLETED or previousEntry.kind == "unlocked") then
                    table.insert(changes.completed, currentEntry.lineText)
                end
            elseif previousStatus == STATUS_COMPLETED and (not previousEntry or previousEntry.kind ~= "unlocked") then
                table.insert(changes.available, currentEntry.lineText)
            end
        end
    end

    table.sort(changes.available)
    table.sort(changes.completed)
    return changes
end

function Chores:MaybeSendNotifications(state)
    local snapshot = BuildNotificationSnapshot(state)

    if not state or state.enabled ~= true then
        self.notificationSnapshot = snapshot
        self.notificationsPrimed = false
        return
    end

    local previousSnapshot = self.notificationSnapshot or {}
    self.notificationSnapshot = snapshot

    if not self.notificationsPrimed then
        self.notificationsPrimed = true
        return
    end

    ---@type ToastsModule
    local toastsModule = T:GetModule("ToastsModule")
    if not toastsModule or type(toastsModule.SendChoresNotification) ~= "function" then
        return
    end

    local changes = BuildNotificationChanges(previousSnapshot, snapshot)
    if #changes.unlocked > 0 then
        local notificationInfo = #changes.unlockedInfo == 1 and changes.unlockedInfo[1] or nil
        toastsModule:SendChoresNotification("unlocked", changes.unlocked, notificationInfo)
    end

    if #changes.completed > 0 then
        toastsModule:SendChoresNotification("completed", changes.completed)
    end

    if #changes.available > 0 then
        toastsModule:SendChoresNotification("available", changes.available)
    end
end

local function ResolveProfessionEntryState(entry)
    local sourceStates = {}
    local completedSources = 0
    local hasInProgress = false

    for _, source in ipairs(entry.sources) do
        local sourceState
        if source.currency then
            sourceState = GetCurrencyQuestState(source)
        else
            sourceState = GetQuestState(source.quest)
        end

        if source.name and (type(sourceState.title) ~= "string" or sourceState.title == "" or string.match(sourceState.title, "^Quest #%d+$")) then
            sourceState.title = source.name
        end

        table.insert(sourceStates, {
            source = source,
            state = sourceState,
        })

        if sourceState.status == STATUS_COMPLETED then
            completedSources = completedSources + 1
        elseif sourceState.status == STATUS_IN_PROGRESS then
            hasInProgress = true
        end
    end

    local resolvedState = {
        title = entry.name,
        status = STATUS_NOT_STARTED,
        objectives = {},
    }

    if #sourceStates == 0 then
        return resolvedState
    end

    if entry.key == "catchup" then
        local progressState = sourceStates[1].state
        local progressObjective = type(progressState.objectives) == "table" and progressState.objectives[1] or nil
        if progressObjective and progressObjective.need and progressObjective.need > 0 then
            progressState.title = ("%s (%d/%d)"):format(entry.name, progressObjective.have or 0, progressObjective.need)
        else
            progressState.title = entry.name
        end
        progressState.objectives = {}
        return progressState
    end

    if completedSources >= #sourceStates then
        resolvedState.status = STATUS_COMPLETED
    elseif completedSources > 0 or hasInProgress then
        resolvedState.status = STATUS_IN_PROGRESS
    end

    if #sourceStates > 1 then
        resolvedState.title = ("%s (%d/%d)"):format(entry.name, completedSources, #sourceStates)
    end

    for _, sourceInfo in ipairs(sourceStates) do
        if sourceInfo.state.status < STATUS_COMPLETED then
            table.insert(resolvedState.objectives,
                BuildProfessionSourceObjective(entry, sourceInfo.source, sourceInfo.state))
        end
    end

    return resolvedState
end

function Chores:GetProfessionCategoryDefinitions()
    local definitions = {}
    local professions = { type(GetProfessions) == "function" and GetProfessions() or nil }

    for _, professionDefinition in ipairs(PROFESSION_CATEGORY_DATA) do
        local skillLevel = 0
        local currentSkillLineName = nil
        local matchedProfession = false

        for index = 1, 5 do
            local professionID = professions[index]
            if professionID then
                local _, _, resolvedSkillLevel, _, _, _, skillLineId, _, _, _, resolvedSkillLineName = GetProfessionInfo(
                    professionID)
                if skillLineId == professionDefinition.baseSkillLineId then
                    matchedProfession = true
                    skillLevel = resolvedSkillLevel or 0
                    currentSkillLineName = resolvedSkillLineName
                    break
                end
            end
        end

        local hasProfessionSpell = type(IsProfessionSpellKnown) == "function" and professionDefinition.professionSpellID and
            IsProfessionSpellKnown(professionDefinition.professionSpellID) or false

        if matchedProfession or hasProfessionSpell then
            local childDisplayName = C_TradeSkillUI and type(C_TradeSkillUI.GetTradeSkillDisplayName) == "function" and
                C_TradeSkillUI.GetTradeSkillDisplayName(professionDefinition.childSkillLineId) or nil
            local childInfo = C_TradeSkillUI and type(C_TradeSkillUI.GetProfessionInfoBySkillLineID) == "function" and
                C_TradeSkillUI.GetProfessionInfoBySkillLineID(professionDefinition.childSkillLineId) or nil
            local hasMidnightSkill = currentSkillLineName == childDisplayName or
                (type(childInfo) == "table" and (childInfo.skillLevel or 0) > 0) or
                matchedProfession or hasProfessionSpell

            if hasMidnightSkill then
                table.insert(definitions, {
                    key = professionDefinition.key,
                    name = ResolveProfessionName(professionDefinition),
                    icon = ResolveProfessionIcon(professionDefinition),
                    childSkillLineId = professionDefinition.childSkillLineId,
                    skillLevel = skillLevel,
                    entries = professionDefinition.entries,
                })
            end
        end
    end

    table.sort(definitions, function(left, right)
        return left.name < right.name
    end)

    return definitions
end

function Chores:GetPreyDifficultyDefinitions()
    local definitions = {}

    for _, definition in ipairs(PREY_DIFFICULTY_DATA) do
        table.insert(definitions, {
            key = definition.key,
            name = definition.name,
        })
    end

    return definitions
end

function Chores:BuildProfessionSummary(definition)
    local summary = BuildSimpleSummary(definition.key, definition.name, definition.icon)
    summary.showPendingEntries = true
    summary.progressStyle = "remaining"

    for _, entryDefinition in ipairs(definition.entries) do
        local entryState = ResolveProfessionEntryState(entryDefinition)
        local entry = {
            data = CloneEntry(entryDefinition),
            state = entryState,
            label = entryDefinition.name,
        }

        summary.total = summary.total + 1
        table.insert(summary.entries, entry)

        if entryState.status == STATUS_COMPLETED then
            summary.completed = summary.completed + 1
        else
            table.insert(summary.selectedEntries, entry)
            if entryState.status == STATUS_IN_PROGRESS then
                summary.status = STATUS_IN_PROGRESS
            end
        end
    end

    if summary.total == 0 then
        summary.active = false
        summary.visible = false
        return summary
    end

    if summary.completed >= summary.total then
        summary.status = STATUS_COMPLETED
    elseif summary.completed > 0 and summary.status ~= STATUS_IN_PROGRESS then
        summary.status = STATUS_IN_PROGRESS
    end

    summary.remaining = math.max(summary.total - summary.completed, 0)
    table.sort(summary.entries, SortEntries)
    table.sort(summary.selectedEntries, SortEntries)
    return summary
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
    local summary = BuildSimpleSummary("bountifulDelves", "Bountiful Delves", nil, "delves-bountiful")
    summary.showPendingEntries = true
    summary.infoText = GetBountifulKeyInfoText()
    local keyCount = GetBountifulKeyCurrencyCounts()
    local trackWithKeyOnly = options.GetOnlyTrackBountifulDelvesWithKey
        and options:GetOnlyTrackBountifulDelvesWithKey()

    if not options:GetTrackBountifulDelves() then
        summary.active = false
        summary.visible = false
        return summary
    end

    if trackWithKeyOnly and keyCount <= 0
    then
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
                local entryData = CloneEntry(poi)
                local x, y = GetAreaPOIPositionXY(activePoi)
                entryData.mapID = zone.uiMapId
                entryData.x = x
                entryData.y = y
                entryData.waypointName = activePoi.name or "Bountiful Delve"
                entryData.waypointZone = mapName
                entryData.waypointTooltipText = "Click to set a waypoint to this bountiful delve."

                local entry = {
                    data = entryData,
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

    table.sort(summary.entries, SortEntries)
    table.sort(summary.selectedEntries, SortEntries)

    if trackWithKeyOnly then
        local trackedPendingCount = math.min(keyCount, #summary.selectedEntries)
        local trackedEntries = {}
        local trackedSelectedEntries = {}

        for _, entry in ipairs(summary.entries) do
            if entry.state.status == STATUS_COMPLETED then
                table.insert(trackedEntries, entry)
            end
        end

        for index = 1, trackedPendingCount do
            local entry = summary.selectedEntries[index]
            trackedSelectedEntries[index] = entry
            trackedEntries[#trackedEntries + 1] = entry
        end

        table.sort(trackedEntries, SortEntries)
        summary.entries = trackedEntries
        summary.selectedEntries = trackedSelectedEntries
        summary.total = summary.completed + trackedPendingCount
    end

    summary.remaining = math.max(summary.total - summary.completed, 0)
    if summary.remaining == 0 then
        summary.status = STATUS_COMPLETED
    elseif summary.completed > 0 then
        summary.status = STATUS_IN_PROGRESS
    end

    return summary
end

function Chores:BuildPreySummary()
    local options = GetOptions()
    local summary = BuildSimpleSummary("prey", "Prey", PREY_ICON)
    summary.showPendingEntries = true
    summary.progressStyle = "remaining"

    if not options:GetTrackPrey() then
        summary.active = false
        summary.visible = false
        return summary
    end

    if not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompleted) ~= "function" then
        summary.active = false
        summary.visible = false
        return summary
    end

    for _, difficultyName in ipairs(GetUnlockedPreyDifficultyNames()) do
        local definition = GetPreyDifficultyDefinition(difficultyName)

        if definition and options:IsPreyDifficultyEnabled(definition.key) then
            local completedTargets = 0

            for _, questID in ipairs(definition.questIDs) do
                if C_QuestLog.IsQuestFlaggedCompleted(questID) then
                    completedTargets = completedTargets + 1
                end
            end

            completedTargets = math.min(completedTargets, PREY_TARGETS_PER_DIFFICULTY)

            local remainingTargets = math.max(PREY_TARGETS_PER_DIFFICULTY - completedTargets, 0)
            local difficultyState = {
                title = ("%s (%d/%d available)"):format(definition.name, remainingTargets, PREY_TARGETS_PER_DIFFICULTY),
                status = STATUS_NOT_STARTED,
                objectives = {},
            }

            if remainingTargets == 0 then
                difficultyState.status = STATUS_COMPLETED
            elseif completedTargets > 0 then
                difficultyState.status = STATUS_IN_PROGRESS
            end

            local entry = {
                data = {
                    key = ("prey-%s"):format(definition.key),
                    mapID = ASTALOR_PREY_MAP_ID,
                    x = ASTALOR_PREY_X,
                    y = ASTALOR_PREY_Y,
                    waypointName = "Astalor Bloodsworn",
                    waypointZone = "Silvermoon City",
                },
                state = difficultyState,
            }

            summary.total = summary.total + PREY_TARGETS_PER_DIFFICULTY
            summary.completed = summary.completed + completedTargets
            table.insert(summary.entries, entry)

            if difficultyState.status ~= STATUS_COMPLETED then
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
    local notificationsReady = self.raidFinderNotificationsReady == true

    for _, raidWing in ipairs(GetRaidWingEntries()) do
        if options:IsRaidWingEnabled(raidWing.dungeonID) then
            summary.total = summary.total + 1

            local numEncounters, numCompleted =
                type(GetLFGDungeonNumEncounters) == "function" and GetLFGDungeonNumEncounters(raidWing.dungeonID) or nil,
                nil
            if type(numEncounters) == "number" then
                numCompleted = select(2, GetLFGDungeonNumEncounters(raidWing.dungeonID))
            end

            local wingState = {
                title = raidWing.name,
                status = STATUS_UNKNOWN,
                objectives = {},
                encounters = {},
            }

            if type(numEncounters) == "number" and numEncounters > 0 then
                local completedEncounters = type(numCompleted) == "number" and numCompleted or 0
                if type(GetLFGDungeonEncounterInfo) == "function" then
                    for encounterIndex = 1, numEncounters do
                        local encounterName, _, isCompleted = GetLFGDungeonEncounterInfo(raidWing.dungeonID,
                            encounterIndex)
                        if encounterName then
                            table.insert(wingState.encounters, {
                                name = encounterName,
                                isCompleted = isCompleted == true,
                            })
                        end
                    end
                end

                if completedEncounters >= numEncounters then
                    wingState.status = STATUS_COMPLETED
                    summary.completed = summary.completed + 1
                    wingState.title = ("%s (%d/%d)"):format(raidWing.name, completedEncounters, numEncounters)
                elseif completedEncounters > 0 then
                    wingState.status = STATUS_IN_PROGRESS
                    wingState.title = ("%s (%d/%d)"):format(raidWing.name, completedEncounters, numEncounters)
                else
                    wingState.status = STATUS_NOT_STARTED
                end
            end

            local entry = {
                data = {
                    dungeonID = raidWing.dungeonID,
                },
                state = wingState,
                notificationStatus = notificationsReady and wingState.status or STATUS_UNKNOWN,
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

    if type(GetTime) == "function" then
        self.lastRefreshTime = GetTime()
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

    local function AddSummary(summary, countTowardsTotal)
        if not summary or not summary.active then
            return
        end

        summary.countTowardsTotal = countTowardsTotal ~= false
        if summary.countTowardsTotal then
            state.totalRemaining = state.totalRemaining + summary.remaining
            state.totalTracked = state.totalTracked + summary.total
        end

        state.categories[summary.key] = summary
        table.insert(state.orderedCategories, summary)
    end

    for _, category in ipairs(CATEGORY_DATA) do
        if options:IsCategoryEnabled(category.key) then
            local summary = self:BuildCategorySummary(category, playerLevel)
            AddSummary(summary, true)
        end
    end

    for _, professionDefinition in ipairs(self:GetProfessionCategoryDefinitions()) do
        if options:IsCategoryEnabled(professionDefinition.key) then
            local professionSummary = self:BuildProfessionSummary(professionDefinition)
            AddSummary(professionSummary, options:GetCountProfessionsTowardTotal())
        end
    end

    local preySummary = self:BuildPreySummary()
    AddSummary(preySummary, options:GetCountPreyTowardTotal())

    local bountifulDelvesSummary = self:BuildBountifulDelvesSummary()
    AddSummary(bountifulDelvesSummary, options:GetCountBountifulDelvesTowardTotal())

    local raidFinderSummary = self:BuildRaidFinderSummary()
    AddSummary(raidFinderSummary, true)

    self.state = state
    self:MaybeSendNotifications(state)
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

    local delay = 0.2

    if type(GetTime) == "function" and type(self.lastRefreshTime) == "number" then
        local remaining = (self.lastRefreshTime + MIN_REFRESH_INTERVAL_SECONDS) - GetTime()
        if remaining > delay then
            delay = remaining
        end
    end

    self.refreshTimer = self:ScheduleTimer("RefreshState", delay)
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
    self.raidFinderNotificationsReady = true
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
    self.notificationsPrimed = false
    self.notificationSnapshot = nil
    self.raidFinderNotificationsReady = false
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnRefreshEvent")
    self:RegisterEvent("PLAYER_LEVEL_UP", "OnRefreshEvent")
    self:RegisterEvent("SKILL_LINES_CHANGED", "OnRefreshEvent")
    self:RegisterEvent("TRADE_SKILL_SHOW", "OnRefreshEvent")
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
    self.notificationsPrimed = false
    self.notificationSnapshot = nil
    self.raidFinderNotificationsReady = false
    self:SendMessage("TWICHUI_CHORES_UPDATED", self.state)
end
