--[[
    Options for the ChatEnhancement module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class ChatEnhancementConfigurationOptions
local Options = ConfigurationModule.Options.ChatEnhancement or {}
ConfigurationModule.Options.ChatEnhancement = Options

local DEFAULT_SOUND = "TwichUI Chat Ping"

---@return table chatEnhancementDB the profile-level chat enhancement configuration database.
function Options:GetChatEnhancementDB()
    if not ConfigurationModule:GetProfileDB().chatEnhancement then
        ConfigurationModule:GetProfileDB().chatEnhancement = {}
    end
    return ConfigurationModule:GetProfileDB().chatEnhancement
end

function Options:IsAlertsEnabled()
    return self:GetChatEnhancementDB().alertsEnabled or false
end

function Options:SetAlertsEnabled(info, value)
    self:GetChatEnhancementDB().alertsEnabled = value

    ---@type ChatAlertsModule
    local ChatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")
    ChatAlertsModule:RefreshEvents()
end

function Options:IsBlizzardTellSoundSupressed()
    return self:GetChatEnhancementDB().supressBlizzardTellSound or false
end

function Options:SetBlizzardTellSoundSupressed(info, value)
    self:GetChatEnhancementDB().supressBlizzardTellSound = value

    ---@type ChatAlertsModule
    local ChatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")

    if value then
        ChatAlertsModule:SupressBlizzardTellSound()
    else
        ConfigurationModule:PromptToReloadUI()
    end
end

function Options:IsBNChatAlertEnabled()
    return self:GetChatEnhancementDB().bnChatAlertEnabled or false
end

function Options:SetBNChatAlertEnabled(info, value)
    self:GetChatEnhancementDB().bnChatAlertEnabled = value

    ---@type ChatAlertsModule
    local ChatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")

    if value then
        ChatAlertsModule:Enable()
    else
        ChatAlertsModule:Disable()
    end
end

function Options:GetBNSound()
    return self:GetChatEnhancementDB().bnSoundSelector or
        DEFAULT_SOUND
end

function Options:SetBNSound(info, value)
    self:GetChatEnhancementDB().bnSoundSelector = value
end

function Options:GetKeyWords()
    return self:GetChatEnhancementDB().keyWords or ""
end

function Options:SetKeyWords(info, value)
    self:GetChatEnhancementDB().keyWords = value

    ---@type ChatAlertsModule
    local ChatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")
    ChatAlertsModule:RefreshKeywords()
end

function Options:IsKeywordAlertsEnabled()
    return self:GetChatEnhancementDB().keywordAlertsEnabled or false
end

function Options:SetKeywordAlertsEnabled(info, value)
    self:GetChatEnhancementDB().keywordAlertsEnabled = value

    ---@type ChatAlertsModule
    local ChatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")
    ChatAlertsModule:RefreshKeywords()
end

function Options:GetKeywordMonitoringForChannel(channelName)
    return self:GetChatEnhancementDB()[channelName .. "KeywordMonitoring"] or false
end

function Options:GetKeyWordAlertSound()
    return self:GetChatEnhancementDB().keyWordAlertSound or
        DEFAULT_SOUND
end

function Options:SetKeyWordAlertSound(info, value)
    self:GetChatEnhancementDB().keyWordAlertSound = value
end

function Options:GetAlertSoundForChannel(channelName)
    return self:GetChatEnhancementDB()[channelName .. "SoundSelector"] or
        DEFAULT_SOUND
end

function Options:GetChannelMonitoringEnabled(channelName)
    return self:GetChatEnhancementDB()[channelName .. "ChatAlertEnabled"] or false
end
