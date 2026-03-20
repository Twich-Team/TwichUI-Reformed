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
local GetNumActiveQuests = GetNumActiveQuests
local GetNumAvailableQuests = GetNumAvailableQuests
local GetAvailableQuestInfo = GetAvailableQuestInfo
local GetActiveQuestID = GetActiveQuestID
local SelectGreetingActiveQuest = SelectActiveQuest
local SelectGreetingAvailableQuest = SelectAvailableQuest
local GetActiveQuests = C_GossipInfo.GetActiveQuests
local SelectActiveQuests = C_GossipInfo.SelectActiveQuest
local GetAvailableQuests = C_GossipInfo.GetAvailableQuests
local SelectAvailableQuest = C_GossipInfo.SelectAvailableQuest
local GetItemInfo = C_Item.GetItemInfo
local GetQuestItemInfo = GetQuestItemInfo
local GetQuestReward = GetQuestReward
local RequestLoadItemDataByID = C_Item.RequestLoadItemDataByID
local CompleteQuest = CompleteQuest
local IsCampaignQuest = C_CampaignInfo.IsCampaignQuest
local IsQuestCompletable = IsQuestCompletable

local GOSSIP_QUEST_INFO_ID = {
    IMPORTANT = {
        [282] = true,
        [292] = true,
    },
    META = {
        [284] = true,
    },
}

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class QuestAutomationModule : AceModule, AceEvent-3.0, AceConsole-3.0
local QAM = QOL:NewModule("QuestAutomation", "AceEvent-3.0", "AceConsole-3.0")

---@class QuestAutomationSelectionContext
---@field questID number|nil
---@field isMeta boolean|nil
---@field isImportant boolean|nil
---@field isRepeatable boolean|nil
---@field questInfoID number|nil

---@type QuestAutomationSelectionContext|nil
QAM.PendingSelection = nil

---@class QuestAutomationRewardContext
---@field questID number|nil
---@field itemIDs table<number, true>

---@type QuestAutomationRewardContext|nil
QAM.PendingRewardSelection = nil

---@type QuestTools
local QuestTools = T.Tools.Quest

---@type table<string, QuestType>
QAM.SupportedQuestTypes = {
    ANY = QuestTools.QuestTypes.ANY,
    CAMPAIGN = QuestTools.QuestTypes.CAMPAIGN,
    IMPORTANT = QuestTools.QuestTypes.IMPORTANT,
    META = QuestTools.QuestTypes.META,
    REPEATABLE = QuestTools.QuestTypes.REPEATABLE,
}

QAM.SupporttedQuestTypes = QAM.SupportedQuestTypes

QAM.QuestEvents = {
    "QUEST_DETAIL",
    "QUEST_COMPLETE",
    "QUEST_PROGRESS",
    "GOSSIP_SHOW",
    "QUEST_GREETING",
    "ITEM_DATA_LOAD_RESULT",
    "QUEST_TURNED_IN",
}

---@return QuestAutomationConfigurationOptions
local function GetQuestAutomationOptions()
    ---@type QuestAutomationConfigurationOptions
    local Options = T:GetModule("Configuration").Options.QuestAutomation
    return Options
end

---@param questID number|nil
---@param isMeta boolean|nil
---@param isImportant boolean|nil
---@param isRepeatable boolean|nil
---@param questInfoID number|nil
---@return QuestAutomationSelectionContext
local function BuildSelectionContext(questID, isMeta, isImportant, isRepeatable, questInfoID)
    return {
        questID = questID,
        isMeta = isMeta,
        isImportant = isImportant,
        isRepeatable = isRepeatable,
        questInfoID = questInfoID,
    }
end

---@param automationEnabled boolean
---@param questContext QuestAutomationSelectionContext|nil
---@return boolean
local function ShouldAutomateByContext(automationEnabled, questContext)
    if not automationEnabled or not questContext then
        return false
    end

    local Options = GetQuestAutomationOptions()
    local questID = questContext.questID

    if Options:GetOnlyQuestsNearMyLevel() and questID and not QuestTools.IsQuestNearPlayerLevel(questID) then
        return false
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.ANY.name) then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.META.name) then
        if questContext.isMeta then
            return true
        end
        if questContext.questInfoID and GOSSIP_QUEST_INFO_ID.META[questContext.questInfoID] then
            return true
        end
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.IMPORTANT.name) then
        if questContext.isImportant then
            return true
        end
        if questContext.questInfoID and GOSSIP_QUEST_INFO_ID.IMPORTANT[questContext.questInfoID] then
            return true
        end
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.REPEATABLE.name) and questContext.isRepeatable then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.CAMPAIGN.name) and questID and IsCampaignQuest(questID) then
        return true
    end

    return false
end

---@param questContext QuestAutomationSelectionContext|nil
local function SetPendingSelection(questContext)
    QAM.PendingSelection = questContext
end

local function ClearPendingSelection()
    QAM.PendingSelection = nil
end

---@param questID number|nil
---@param itemIDs table<number, true>
local function SetPendingRewardSelection(questID, itemIDs)
    QAM.PendingRewardSelection = {
        questID = questID,
        itemIDs = itemIDs,
    }
end

local function ClearPendingRewardSelection()
    QAM.PendingRewardSelection = nil
end

---@param questID number
---@param automationEnabled boolean
---@return boolean
local function ShouldAutomateQuest(questID, automationEnabled)
    if not questID then
        return false
    end

    local Options = GetQuestAutomationOptions()

    if not automationEnabled then
        return false
    end

    if Options:GetOnlyQuestsNearMyLevel() and not QuestTools.IsQuestNearPlayerLevel(questID) then
        return false
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.ANY.name) then
        return true
    end

    for _, questType in pairs(QAM.SupportedQuestTypes) do
        if questType ~= QAM.SupportedQuestTypes.ANY then
            if Options:IsQuestTypeEnabled(questType.name) and QuestTools.IsQuestOfType(questType, questID) then
                return true
            end
        end
    end

    return false
end

---@param gossipQuest GossipQuestUIInfo
---@param automationEnabled boolean
---@return boolean
local function ShouldAutomateGossipQuest(gossipQuest, automationEnabled)
    if not gossipQuest or not gossipQuest.questID then
        return false
    end

    if not automationEnabled then
        return false
    end

    local Options = GetQuestAutomationOptions()

    if Options:GetOnlyQuestsNearMyLevel() and not QuestTools.IsQuestNearPlayerLevel(gossipQuest.questID) then
        return false
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.ANY.name) then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.META.name) and gossipQuest.isMeta then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.META.name)
        and gossipQuest.questInfoID
        and GOSSIP_QUEST_INFO_ID.META[gossipQuest.questInfoID]
    then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.IMPORTANT.name) and gossipQuest.isImportant then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.REPEATABLE.name) and gossipQuest.repeatable then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.IMPORTANT.name)
        and gossipQuest.questInfoID
        and GOSSIP_QUEST_INFO_ID.IMPORTANT[gossipQuest.questInfoID]
    then
        return true
    end

    if Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.CAMPAIGN.name) and IsCampaignQuest(gossipQuest.questID) then
        return true
    end

    return ShouldAutomateQuest(gossipQuest.questID, automationEnabled)
end

---@param index number
---@param automationEnabled boolean
---@return boolean, number|nil
local function ShouldAutomateAvailableGreetingQuest(index, automationEnabled)
    local Options = GetQuestAutomationOptions()
    local isTrivial, frequency, isRepeatable, isLegendary, questID, isImportant, isMeta, questInfoID =
    GetAvailableQuestInfo(index)
    local shouldAutomate = automationEnabled and (
        (Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.ANY.name)) or
        (Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.META.name) and (isMeta or (questInfoID and GOSSIP_QUEST_INFO_ID.META[questInfoID]))) or
        (Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.IMPORTANT.name) and (isImportant or (questInfoID and GOSSIP_QUEST_INFO_ID.IMPORTANT[questInfoID]))) or
        (Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.REPEATABLE.name) and isRepeatable) or
        (Options:IsQuestTypeEnabled(QAM.SupportedQuestTypes.CAMPAIGN.name) and questID and IsCampaignQuest(questID)) or
        ShouldAutomateQuest(questID, automationEnabled)
    ) or false

    if Options:GetOnlyQuestsNearMyLevel() and questID and not QuestTools.IsQuestNearPlayerLevel(questID) then
        shouldAutomate = false
    end

    return shouldAutomate, questID
end

---@param index number
---@param automationEnabled boolean
---@return boolean, number|nil, boolean
local function ShouldAutomateActiveGreetingQuest(index, automationEnabled)
    local questID = GetActiveQuestID(index)
    local _, isComplete = GetActiveTitle(index)
    local isQuestComplete = isComplete == true
    local shouldAutomate = isQuestComplete and questID ~= nil and ShouldAutomateQuest(questID, automationEnabled) or
    false

    return shouldAutomate, questID, isQuestComplete
end

---@param questID number
---@return boolean
local function ShouldAccept(questID)
    local automaticAccept = GetQuestAutomationOptions():GetAutomaticAccept()
    if ShouldAutomateByContext(automaticAccept, QAM.PendingSelection) then
        return true
    end

    return ShouldAutomateQuest(questID, automaticAccept)
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
    return ShouldAutomateQuest(questID, GetQuestAutomationOptions():GetAutomaticTurnIn())
end

function QAM:QUEST_DETAIL()
    if not ShouldContinueWithModifier() then
        ClearPendingSelection()
        ClearPendingRewardSelection()
        return
    end

    local questID = GetQuestID()
    if ShouldAccept(questID) then
        AcceptQuest()
    end

    ClearPendingSelection()
end

---@param questID number
local function TurnInQuest(questID)
    if not ShouldTurnIn(questID) then
        ClearPendingRewardSelection()
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
        ClearPendingRewardSelection()
        GetQuestReward(1)
        return
    end

    -- If there are multiple rewards, find the one with the highest vendor value
    local bestIndex = 1
    local bestValue = -1
    local pendingItemIDs = nil

    for i = 1, numRewards do
        local _, _, quantity, _, _, itemID = GetQuestItemInfo("choice", i)
        local itemInfo = itemID and { GetItemInfo(itemID) } or nil
        local itemVendorValue = itemInfo and itemInfo[11] or nil

        if itemID and itemVendorValue == nil then
            pendingItemIDs = pendingItemIDs or {}
            pendingItemIDs[itemID] = true
            RequestLoadItemDataByID(itemID)
        end

        local totalValue = (itemVendorValue or 0) * (quantity or 1)
        if totalValue > bestValue then
            bestValue = totalValue
            bestIndex = i
        end
    end

    if pendingItemIDs then
        SetPendingRewardSelection(questID, pendingItemIDs)
        return
    end

    ClearPendingRewardSelection()
    GetQuestReward(bestIndex)
end

function QAM:ITEM_DATA_LOAD_RESULT(_, itemID, success)
    local pendingRewardSelection = self.PendingRewardSelection
    if not pendingRewardSelection or not success then
        return
    end

    if not pendingRewardSelection.itemIDs[itemID] then
        return
    end

    TurnInQuest(pendingRewardSelection.questID or GetQuestID())
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
    if not ShouldTurnIn(questID) then
        return
    end

    if IsQuestCompletable() then
        CompleteQuest()
    end
end

function QAM:GOSSIP_SHOW()
    if not ShouldContinueWithModifier() then
        ClearPendingSelection()
        return
    end

    ClearPendingSelection()

    -- active quests
    local quests = GetActiveQuests() or {}
    for _, q in ipairs(quests) do
        local shouldAutomate = q.isComplete and
        ShouldAutomateGossipQuest(q, GetQuestAutomationOptions():GetAutomaticTurnIn())
        if shouldAutomate then
            SelectActiveQuests(q.questID)
            return
        end
    end

    -- available quests
    local availableQuests = GetAvailableQuests() or {}
    for _, q in ipairs(availableQuests) do
        local shouldAutomate = ShouldAutomateGossipQuest(q, GetQuestAutomationOptions():GetAutomaticAccept())
        if shouldAutomate then
            SetPendingSelection(BuildSelectionContext(q.questID, q.isMeta, q.isImportant, q.repeatable, q.questInfoID))
            SelectAvailableQuest(q.questID)
            return
        end
    end
end

function QAM:QUEST_GREETING()
    if not ShouldContinueWithModifier() then
        ClearPendingSelection()
        return
    end

    ClearPendingSelection()

    local automaticTurnIn = GetQuestAutomationOptions():GetAutomaticTurnIn()
    for index = 1, (GetNumActiveQuests() or 0) do
        local shouldAutomate = ShouldAutomateActiveGreetingQuest(index, automaticTurnIn)
        if shouldAutomate then
            pcall(SelectGreetingActiveQuest, index)
            return
        end
    end

    local automaticAccept = GetQuestAutomationOptions():GetAutomaticAccept()
    for index = 1, (GetNumAvailableQuests() or 0) do
        local shouldAutomate, questID = ShouldAutomateAvailableGreetingQuest(index, automaticAccept)
        if shouldAutomate then
            local _, _, isRepeatable, _, _, isImportant, isMeta, questInfoID = GetAvailableQuestInfo(index)
            SetPendingSelection(BuildSelectionContext(questID, isMeta, isImportant, isRepeatable, questInfoID))
            pcall(SelectGreetingAvailableQuest, index)
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

function QAM:OnDisable()
    ClearPendingSelection()
    ClearPendingRewardSelection()
    self:UnregisterAllEvents()
end
