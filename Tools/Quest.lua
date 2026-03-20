--[[
    Provides Quest Utility functions..
]]
---@type TwichUI
local TwichRx = _G.TwichRx
local T, W, I, C = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class QuestTools
local Quest = Tools.Quest or {}
Tools.Quest = Quest

local GetQuestTagInfo = C_QuestLog.GetQuestTagInfo
local GetLogIndexForQuestID = C_QuestLog.GetLogIndexForQuestID
local GetQuestLogInfo = C_QuestLog.GetInfo
local GetQuestDifficultyLevel = C_QuestLog.GetQuestDifficultyLevel
local IsMetaQuest = C_QuestLog.IsMetaQuest
local IsRepeatableQuest = C_QuestLog.IsRepeatableQuest
local IsCampaignQuest = C_CampaignInfo.IsCampaignQuest
local GetQuestID = GetQuestID

local QUEST_CLASSIFICATION = {
    IMPORTANT = 0,
    LEGENDARY = 1,
    CAMPAIGN = 2,
    CALLING = 3,
    META = 4,
}

local QUEST_TAG_ID = {
    RAID = {
        [62] = true,
        [88] = true,
        [89] = true,
        [141] = true,
    },
    DUNGEON = {
        [81] = true,
        [137] = true,
        [145] = true,
    },
    ARTIFACT = {
        [107] = true,
    },
    IMPORTANT = {
        [282] = true,
        [292] = true,
    },
    META = {
        [284] = true,
    },
    DELVE = {
        [288] = true,
    },
}

---@alias QuestType { name: string, atlasIcon: string }

Quest.QuestTypes = {
    ANY = { name = "Any", atlasIcon = "QuestNormal" },
    CAMPAIGN = { name = "Campaign", atlasIcon = "Quest-Campaign-Available" },
    IMPORTANT = { name = "Important", atlasIcon = "UI-QuestPoiImportant-QuestBang" },
    META = { name = "Meta", atlasIcon = "UI-QuestPoiWrapper-QuestBang" },
    REPEATABLE = { name = "Repeatable", atlasIcon = "Recurringavailablequesticon" },
    DUNGEON = { name = "Dungeon", atlasIcon = "Dungeon" },
    RAID = { name = "Raid", atlasIcon = "Raid" },
    COMPLETED = { name = "Completed", atlasIcon = "QuestLog-icon-checkmark-yellow" },
    DELVE = { name = "Delve", atlasIcon = "delves-regular" },
    ARTIFACT = { name = "Artifact", atlasIcon = "UI-QuestPoiLegendary-QuestBang" },
}

---@param questID? number
---@return QuestInfo|nil
function Quest.GetQuestLogInfo(questID)
    if not questID then
        questID = GetQuestID()
    end

    if not questID then
        return nil
    end

    local questLogIndex = GetLogIndexForQuestID(questID)
    if not questLogIndex then
        return nil
    end

    return GetQuestLogInfo(questLogIndex)
end

---@param questID? number
---@return QuestTagInfo|nil
function Quest.GetQuestTagInfo(questID)
    if not questID then
        questID = GetQuestID()
    end

    if not questID then
        return nil
    end

    return GetQuestTagInfo(questID)
end

---@param values table<number, true>
---@param tagID number|nil
---@return boolean
local function TagIdMatches(values, tagID)
    return tagID ~= nil and values[tagID] == true
end

---@param questID? number
---@return number|nil
function Quest.GetQuestClassification(questID)
    local info = Quest.GetQuestLogInfo(questID)
    if not info then
        return nil
    end

    return info.questClassification
end

---@return QuestType questType
function Quest.GetTypeForQuestID(questID)
    for _, questType in pairs(Quest.QuestTypes) do
        if questType ~= Quest.QuestTypes.ANY and Quest.IsQuestOfType(questType, questID) then
            return questType
        end
    end

    -- special case: Campaign (handled even when there is no tag)
    if IsCampaignQuest(questID or GetQuestID()) then
        return Quest.QuestTypes.CAMPAIGN
    end

    -- unknown or untyped, return any
    return Quest.QuestTypes.ANY
end

--- Returns the tag name associated with the currently open quest or the specified questID.
--- Will attempt to lazily fetch the questID if not provided.
---@param questID? number If nil, uses the currently open quest.
---@return string|nil tag nil if no tag exists for the quest.
function Quest.GetQuestTag(questID)
    if not questID then
        questID = GetQuestID()
        if not questID then return nil end
    end
    local tagInfo = Quest.GetQuestTagInfo(questID)
    if not tagInfo then return nil end

    return tagInfo.tagName
end

---@param questType QuestType
---@param questID number|nil If nil, uses the currently open quest.
---@return boolean
function Quest.IsQuestOfType(questType, questID)
    if not questType then
        return false
    end

    local tag = Quest.GetQuestTag(questID)
    local tagInfo = Quest.GetQuestTagInfo(questID)
    local classification = Quest.GetQuestClassification(questID)

    -- special case: any
    if questType == Quest.QuestTypes.ANY then
        return true
    end

    if questType == Quest.QuestTypes.CAMPAIGN then
        if classification == QUEST_CLASSIFICATION.CAMPAIGN or IsCampaignQuest(questID or GetQuestID()) then
            return true
        end
        if tag and tag:lower():find("campaign") then
            return true
        end
        return false
    end

    if questType == Quest.QuestTypes.REPEATABLE then
        if IsRepeatableQuest and IsRepeatableQuest(questID or GetQuestID()) then
            return true
        end

        return tag and tag:lower():find("repeat") ~= nil or false
    end

    if questType == Quest.QuestTypes.IMPORTANT then
        if classification == QUEST_CLASSIFICATION.IMPORTANT then
            return true
        end
        if tagInfo and TagIdMatches(QUEST_TAG_ID.IMPORTANT, tagInfo.tagID) then
            return true
        end
    elseif questType == Quest.QuestTypes.META then
        if classification == QUEST_CLASSIFICATION.META then
            return true
        end
        if IsMetaQuest and IsMetaQuest(questID or GetQuestID()) then
            return true
        end
        if tagInfo and TagIdMatches(QUEST_TAG_ID.META, tagInfo.tagID) then
            return true
        end
    elseif questType == Quest.QuestTypes.RAID then
        if tagInfo and TagIdMatches(QUEST_TAG_ID.RAID, tagInfo.tagID) then
            return true
        end
    elseif questType == Quest.QuestTypes.DUNGEON then
        if tagInfo and TagIdMatches(QUEST_TAG_ID.DUNGEON, tagInfo.tagID) then
            return true
        end
    elseif questType == Quest.QuestTypes.DELVE then
        if tagInfo and TagIdMatches(QUEST_TAG_ID.DELVE, tagInfo.tagID) then
            return true
        end
    elseif questType == Quest.QuestTypes.ARTIFACT then
        if classification == QUEST_CLASSIFICATION.LEGENDARY then
            return true
        end
        if tagInfo and TagIdMatches(QUEST_TAG_ID.ARTIFACT, tagInfo.tagID) then
            return true
        end
    end

    -- other types rely on the tag string
    if not tag then
        return false
    end

    -- attempt to generically determine type from tag name
    return tag:lower():find(questType.name:lower()) ~= nil
end

---@param questID number
---@return number|nil
function Quest.GetQuestLevelByID(questID)
    return GetQuestDifficultyLevel(questID)
end

---@param questID number
---@param tolerance? number Levels above/below the player that are considered "near".
---@return boolean
function Quest.IsQuestNearPlayerLevel(questID, tolerance)
    tolerance = tolerance or 5 -- levels above/below the player

    local qLevel = Quest.GetQuestLevelByID(questID)
    if not qLevel then
        return false
    end

    local pLevel = UnitLevel("player")
    return math.abs(qLevel - pLevel) <= tolerance
end
