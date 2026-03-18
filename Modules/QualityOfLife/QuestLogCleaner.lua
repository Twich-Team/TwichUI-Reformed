--[[
        Quest log cleaner module.

        Responsibilities:
        - Scan the quest log and identify quests that should be abandoned
            according to user-configured filters and modifiers.
        - (Optionally) abandon those quests when run.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local SetSelectedQuest = C_QuestLog.SetSelectedQuest
local SetAbandonQuest = C_QuestLog.SetAbandonQuest
local AbandonQuest = C_QuestLog.AbandonQuest

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class QuestLogCleaner : AceModule, AceConsole-3.0
---@field questsToAbandon table<integer, QuestAbandonCandidate>
local QLC = QOL:NewModule("QuestLogCleaner")

---@type QuestTools
local QT = T.Tools.Quest

QLC.FiltersByQuestType = {
    CAMPAIGN  = QT.QuestTypes.CAMPAIGN,
    IMPORTANT = QT.QuestTypes.IMPORTANT,
    META      = QT.QuestTypes.META,
    DUNGEON   = QT.QuestTypes.DUNGEON,
    RAID      = QT.QuestTypes.RAID,
    DELVE     = QT.QuestTypes.DELVE,
    ARTIFACT  = QT.QuestTypes.ARTIFACT,
}

--- Returns the Quest Log Cleaner configuration options.
---@return QuestLogCleanerConfigurationOptions
function QLC:GetOptions()
    return T:GetModule("Configuration").Options.QuestLogCleaner
end

--- Determines if the specified quest should be abandoned based on the
--- configured criteria.
---
--- A quest will be **kept** (return false) if:
--- - It matches any quest type for which the user has enabled a
---   corresponding "keep" option (e.g., Keep Campaign Quests), or
--- - The "Near My Level" modifier is enabled and the quest is near the
---   player's level.
--- All other quests are considered candidates for abandonment.
---
--- @param questID number
--- @return boolean shouldAbandon
local function ShouldAbandonQuest(questID)
    local Options = QLC:GetOptions()

    -- Evaluate quest types against the configured "keep" filters.
    -- We always check the quest type, and then apply the option value,
    -- so that type-detection isn't short-circuited by the options check.
    for _, questType in pairs(QLC.FiltersByQuestType) do
        local keepFunctionName = ("GetKeep%sQuests"):format(questType.name)
        local getter = Options and Options[keepFunctionName]

        local keepThisType = false
        if type(getter) == "function" then
            keepThisType = getter(Options)
        end

        if QT.IsQuestOfType(questType, questID) then
            -- If this quest matches a type the user wants to keep, do not abandon it.
            if keepThisType then
                return false
            end
        end
    end

    -- Finally, apply the near-my-level modifier.
    if Options and Options.GetKeepNearMyLevelQuests then
        if Options:GetKeepNearMyLevelQuests() and QT.IsQuestNearPlayerLevel(questID) then
            return false
        end
    end

    -- If it didn't match any kept type and isn't protected by level, abandon it.
    return true
end

---@class QuestAbandonCandidate
---@field questID number
---@field title string

---@alias QuestAbandonCandidateList QuestAbandonCandidate[]

--- Builds and caches the list of quests that should be abandoned
--- according to the current configuration.
---
--- @return QuestAbandonCandidateList questsToAbandon
function QLC:GetQuestsToAbandon()
    if not self.questsToAbandon then
        self.questsToAbandon = {}
    end
    wipe(self.questsToAbandon)

    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    -- Work backwards to avoid index shifting when abandoning quests.
    for index = numEntries, 1, -1 do
        local info = C_QuestLog.GetInfo(index)

        -- Skip non-quest rows such as headers, hidden/internal entries, etc.
        if info and not info.isInternalOnly and not info.isHidden and not info.isHeader then
            local questID = info.questID
            if questID and questID > 0 then
                if ShouldAbandonQuest(questID) then
                    table.insert(self.questsToAbandon, { questID = questID, title = info.title })
                end
            end
        end
    end
    return self.questsToAbandon
end

--- Builds the human-readable confirmation text listing all quests that
--- are currently marked to be abandoned.
---
--- @return string text
function QLC:BuildConfirmationText()
    if not self.questsToAbandon or #self.questsToAbandon == 0 then
        return "No quests to abandon."
    end

    local lines = {
        T.Tools.Text.Color(T.Tools.Colors.WARNING, "The following quests will be abandoned:"),
        "",
    }

    local questsByType = {}

    for _, candidate in ipairs(self.questsToAbandon) do
        local questType = QT.GetTypeForQuestID(candidate.questID)
        if not questsByType[questType.name] then
            questsByType[questType.name] = {
                type = questType,
                candidates = {},
            }
        end
        table.insert(questsByType[questType.name].candidates, candidate)
    end

    for _, group in pairs(questsByType) do
        for _, candidate in ipairs(group.candidates) do
            table.insert(lines, ("|A:%s:16:16|a%s"):format(group.type.atlasIcon, candidate.title))
        end
    end

    table.insert(lines,
        T.Tools.Text.Color(T.Tools.Colors.RED,
            "\nAre you sure you want to abandon these quests? This action cannot be undone."))
    return table.concat(lines, "\n")
end

--- Scans the quest log and abandons all quests that match the
--- configured criteria.
function QLC:Run()
    -- Ensure filters and dependencies are available before proceeding.
    if not self.FiltersByQuestType or not QT or not C_QuestLog then
        return
    end

    local candidates = self:GetQuestsToAbandon()
    if not candidates or #candidates == 0 then
        return
    end

    for _, candidate in ipairs(candidates) do
        if candidate.questID and candidate.questID > 0 then
            SetSelectedQuest(candidate.questID)
            SetAbandonQuest()
            AbandonQuest()
        end
    end
end
