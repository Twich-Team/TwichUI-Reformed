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
local GetQuestDifficultyLevel = C_QuestLog.GetQuestDifficultyLevel
local IsCampaignQuest = C_CampaignInfo.IsCampaignQuest
local GetQuestID = GetQuestID

---@alias QuestType { name: string, atlasIcon: string }

Quest.QuestTypes = {
    ANY = { name = "Any", atlasIcon = "QuestNormal" },
    CAMPAIGN = { name = "Campaign", atlasIcon = "Quest-Campaign-Available" },
    IMPORTANT = { name = "Important", atlasIcon = "UI-QuestPoiImportant-QuestBang" },
    META = { name = "Meta", atlasIcon = "UI-QuestPoiWrapper-QuestBang" },
    DUNGEON = { name = "Dungeon", atlasIcon = "Dungeon" },
    RAID = { name = "Raid", atlasIcon = "Raid" },
    COMPLETED = { name = "Completed", atlasIcon = "QuestLog-icon-checkmark-yellow" },
    DELVE = { name = "Delve", atlasIcon = "delves-regular" },
    ARTIFACT = { name = "Artifact", atlasIcon = "UI-QuestPoiLegendary-QuestBang" },
}

---@return QuestType questType
function Quest.GetTypeForQuestID(questID)
    local tag = Quest.GetQuestTag(questID)
    if tag then
        for _, questType in pairs(Quest.QuestTypes) do
            if questType ~= Quest.QuestTypes.ANY then
                if tag:lower():find(questType.name:lower()) ~= nil then
                    return questType
                end
            end
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
    local tagInfo = GetQuestTagInfo(questID)
    if not tagInfo then return nil end

    return tagInfo.tagName
end

---@param questType QuestType
---@param questID number|nil If nil, uses the currently open quest.
---@return boolean
function Quest.IsQuestOfType(questType, questID)
    local tag = Quest.GetQuestTag(questID)

    -- special case: any
    if questType == Quest.QuestTypes.ANY then
        return true
    end

    if questType == Quest.QuestTypes.CAMPAIGN then
        if IsCampaignQuest(questID or GetQuestID()) then
            return true
        end
        if tag and tag:lower():find("campaign") then
            return true
        end
        return false
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
