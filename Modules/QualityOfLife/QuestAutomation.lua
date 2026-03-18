--[[
    Quest automation module.

    Responsibilities:
    - Automatically accept quests based on configured quest types.
    - Automatically turn in quests and select rewards (highest vendor value).
    - Respect a modifier key setting to temporarily enable/disable automation.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local GetQuestID = GetQuestID
local AcceptQuest = AcceptQuest
local GetActiveQuests = C_GossipInfo.GetActiveQuests
local SelectActiveQuests = C_GossipInfo.SelectActiveQuest
local GetAvailableQuests = C_GossipInfo.GetAvailableQuests
local SelectAvailableQuest = C_GossipInfo.SelectAvailableQuest
local GetItemInfo = C_Item.GetItemInfo
local GetQuestItemLink = GetQuestItemLink
local GetQuestItemInfo = GetQuestItemInfo
local GetQuestReward = GetQuestReward
local IsCampaignQuest = C_CampaignInfo.IsCampaignQuest

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class QuestAutomationModule : AceModule, AceEvent-3.0, AceConsole-3.0
local QAM = QOL:NewModule("QuestAutomation", "AceEvent-3.0", "AceConsole-3.0")

---@type QuestTools
local QuestTools = T.Tools.Quest

---@type table<string, QuestType>
QAM.SupporttedQuestTypes = {
    ANY = QuestTools.QuestTypes.ANY,
    CAMPAIGN = QuestTools.QuestTypes.CAMPAIGN,
    IMPORTANT = QuestTools.QuestTypes.IMPORTANT,
    META = QuestTools.QuestTypes.META,
}

QAM.QuestEvents = {
    "QUEST_DETAIL",
    "QUEST_COMPLETE",
    "QUEST_PROGRESS",
    "GOSSIP_SHOW",
    "QUEST_TURNED_IN",
}

---@return QuestAutomationConfigurationOptions
local function GetQuestAutomationOptions()
    ---@type QuestAutomationConfigurationOptions
    local Options = T:GetModule("Configuration").Options.QuestAutomation
    return Options
end

---Return the human-readable names of quest types configured for automation.
--- @return string[] list of quest types to automate
local function GetAutomatedQuestTypes()
    local quests = {}
    local Options = GetQuestAutomationOptions()
    for _, info in pairs(QAM.SupporttedQuestTypes) do
        if Options:IsQuestTypeEnabled(info.name) then
            table.insert(quests, info.name)
        end
    end
    return quests
end

---@param questID number
---@return boolean
local function ShouldAccept(questID)
    if not questID then return false end
    local Options = GetQuestAutomationOptions()

    if not Options:GetAutomaticAccept() then
        return false
    end

    local onlyNearMyLevel = Options:GetOnlyQuestsNearMyLevel()

    -- if any quest is enabled, accept all quests
    if Options:IsQuestTypeEnabled(QAM.SupporttedQuestTypes.ANY.name) then
        if onlyNearMyLevel and not QuestTools.IsQuestNearPlayerLevel(questID) then
            return false
        end
        return true
    end

    local tag = QuestTools.GetQuestTag(questID)

    for qType, info in pairs(QAM.SupporttedQuestTypes) do
        if tag and tag:lower():find(info.name:lower()) then
            if Options:IsQuestTypeEnabled(info.name) then
                if onlyNearMyLevel and not QuestTools.IsQuestNearPlayerLevel(questID) then
                    return false
                end
                return true
            end
        end
    end

    -- special case for campaign
    if Options:IsQuestTypeEnabled(QAM.SupporttedQuestTypes.CAMPAIGN.name) and IsCampaignQuest(questID) then
        if onlyNearMyLevel and not QuestTools.IsQuestNearPlayerLevel(questID) then
            return false
        end
        return true
    end

    return false
end

---@return boolean
local function ShouldContinueWithModifier()
    local modifierFunction = GetQuestAutomationOptions():GetModifierKeyFunction()

    if modifierFunction == "ENABLE" then
        if IsShiftKeyDown() then
            return true
        else
            return false
        end
    elseif modifierFunction == "DISABLE" then
        if IsShiftKeyDown() then
            return false
        else
            return true
        end
    end

    -- Fallback behavior if configuration is unexpected: do not block automation.
    return true
end

---@param questID number
---@return boolean
local function ShouldTurnIn(questID)
    if not questID then return false end
    local Options = GetQuestAutomationOptions()

    if not Options:GetAutomaticTurnIn() then
        return false
    end

    local onlyNearMyLevel = Options:GetOnlyQuestsNearMyLevel()

    -- if any quest is enabled, turn in all quests
    if Options:IsQuestTypeEnabled(QAM.SupporttedQuestTypes.ANY.name) then
        if onlyNearMyLevel and not QuestTools.IsQuestNearPlayerLevel(questID) then
            return false
        end
        return true
    end

    local tag = QuestTools.GetQuestTag(questID)

    for qType, info in pairs(QAM.SupporttedQuestTypes) do
        if tag and tag:lower():find(info.name:lower()) then
            if Options:IsQuestTypeEnabled(info.name) then
                if onlyNearMyLevel and not QuestTools.IsQuestNearPlayerLevel(questID) then
                    return false
                end
                return true
            end
        end
    end

    -- special case for campaign
    if Options:IsQuestTypeEnabled(QAM.SupporttedQuestTypes.CAMPAIGN.name) and IsCampaignQuest(questID) then
        if onlyNearMyLevel and not QuestTools.IsQuestNearPlayerLevel(questID) then
            return false
        end
        return true
    end

    return false
end

function QAM:QUEST_DETAIL()
    if not ShouldContinueWithModifier() then
        return
    end

    local questID = GetQuestID()
    if ShouldAccept(questID) then
        AcceptQuest()
    end
end

---@param questID number
local function TurnInQuest(questID)
    if not ShouldTurnIn(questID) then
        return
    end

    local Options = GetQuestAutomationOptions()
    local numRewards = GetNumQuestChoices()

    -- do not turn in if not configured to choose rewards
    if not Options:GetAutoCompleteWithRewards() and numRewards > 0 then
        return
    end

    -- If there are zero or one choices, the quest API expects index 1.
    -- This covers quests with a fixed reward and no selectable choices.
    if numRewards <= 1 then
        GetQuestReward(1)
        return
    end

    -- If there are multiple rewards, find the one with the highest vendor value
    local bestIndex = 1
    local bestValue = -1

    for i = 1, numRewards do
        local itemLink = GetQuestItemLink("choice", i)
        local _, _, _, _, _, _, _, _, _, itemVendorValue = GetItemInfo(itemLink)

        local _, _, quantity = GetQuestItemInfo("choice", i)

        local totalValue = (itemVendorValue or 0) * (quantity or 1)
        if totalValue > bestValue then
            bestValue = totalValue
            bestIndex = i
        end
    end

    GetQuestReward(bestIndex)
end

function QAM:QUEST_COMPLETE()
    if not ShouldContinueWithModifier() then
        return
    end

    local questID = GetQuestID()
    TurnInQuest(questID)
end

function QAM:QUEST_TURNED_IN()
    if not ShouldContinueWithModifier() then
        return
    end

    -- If gossip is still up, mimic a fresh GOSSIP_SHOW pass
    if GossipFrame and GossipFrame:IsShown() then
        self:GOSSIP_SHOW()
    end
end

function QAM:QUEST_PROGRESS()
    if not ShouldContinueWithModifier() then
        return
    end

    local questID = GetQuestID()
    TurnInQuest(questID)
end

function QAM:GOSSIP_SHOW()
    if not ShouldContinueWithModifier() then
        return
    end

    -- active quests
    local quests = GetActiveQuests()
    for _, q in ipairs(quests) do
        if q.isComplete then
            SelectActiveQuests(q.questID)
            return
        end
    end

    -- available quests
    local availableQuests = GetAvailableQuests()
    for _, q in ipairs(availableQuests) do
        if ShouldAccept(q.questID) then
            SelectAvailableQuest(q.questID)
            return
        end
    end
end

function QAM:OnEnable()
    -- register quest events
    for _, event in ipairs(self.QuestEvents) do
        self:RegisterEvent(event)
    end
end
