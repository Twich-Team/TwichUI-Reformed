--[[
    Options for the QuestAutomation module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class QuestAutomationConfigurationOptions
local Options = ConfigurationModule.Options.QuestAutomation or {}
ConfigurationModule.Options.QuestAutomation = Options

---@return table questAutomationDB the profile-level quest automation configuration database.
function Options:GetQuestAutomationDB()
    if not ConfigurationModule:GetProfileDB().questAutomation then
        ConfigurationModule:GetProfileDB().questAutomation = {}
    end
    return ConfigurationModule:GetProfileDB().questAutomation
end

function Options:IsModuleEnabled(info)
    return self:GetQuestAutomationDB().enabled or false
end

function Options:SetModuleEnabled(info, value)
    self:GetQuestAutomationDB().enabled = value

    ---@type QualityOfLife
    local QOL = T:GetModule("QualityOfLife")
    ---@type QuestAutomationModule
    local QAM = QOL:GetModule("QuestAutomation")

    if value == true then
        QAM:Enable()
    else
        QAM:Disable()
    end
end

function Options:SetAutomaticTurnIn(info, value)
    local db = self:GetQuestAutomationDB()
    db.automaticTurnIn = value
end

function Options:GetAutomaticTurnIn(info)
    local db = self:GetQuestAutomationDB()
    return db.automaticTurnIn or false
end

function Options:SetAutomaticAccept(info, value)
    local db = self:GetQuestAutomationDB()
    db.automaticAccept = value
end

function Options:GetAutomaticAccept(info)
    local db = self:GetQuestAutomationDB()
    return db.automaticAccept or false
end

function Options:SetAutoCompleteWithRewards(info, value)
    local db = self:GetQuestAutomationDB()
    db.autoCompleteWithRewards = value
end

function Options:GetAutoCompleteWithRewards(info)
    local db = self:GetQuestAutomationDB()
    return db.autoCompleteWithRewards or false
end

function Options:IsQuestTypeEnabled(questType)
    local db = self:GetQuestAutomationDB()
    local typeDb = db.questType or {}
    db.questType = typeDb

    return typeDb[questType:lower()] or false
end

function Options:SetQuestTypeEnabled(questType, value)
    local db = self:GetQuestAutomationDB()
    local typeDb = db.questType or {}
    db.questType = typeDb

    typeDb[questType:lower()] = value
end

function Options:GetModifierKeyFunction(info)
    local db = self:GetQuestAutomationDB()
    return db.modifierKeyFunction or "DISABLE"
end

function Options:SetModifierKeyFunction(info, value)
    local db = self:GetQuestAutomationDB()
    db.modifierKeyFunction = value
end

function Options:SetOnlyQuestsNearMyLevel(info, value)
    local db = self:GetQuestAutomationDB()
    db.onlyQuestsNearMyLevel = value
end

function Options:GetOnlyQuestsNearMyLevel(info)
    local db = self:GetQuestAutomationDB()
    return db.onlyQuestsNearMyLevel or false
end
