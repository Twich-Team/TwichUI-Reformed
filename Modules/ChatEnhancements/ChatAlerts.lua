--[[
    SubModule that adds alerts to events that occur in the chat.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
local hasanysecretvalues = _G.hasanysecretvalues

--- local references to WoW APIs
local PlaySoundFile = PlaySoundFile

---@type ChatEnhancementModule
local ChatEnhancementModule = T:GetModule("ChatEnhancements")

---@class ChatAlertsModule : AceModule
---@field frame Frame the frame used to listen to chat events
---@field registeredChannels table<string, ChatChannelInfo>
---@field monitorKeywords boolean whether to monitor keywords in messages
---@field keyWords string[] list of keywords to monitor
---@field keywordChannels table<string, ChatChannelInfo> list of channels to monitor for keywords
---@field soundChannels table<string, ChatChannelInfo> list of channels to play sounds for
---@field blizzardTellSoundSuppressed boolean whether the default tell sound is suppressed
local ChatAlertsModule = ChatEnhancementModule:NewModule("ChatAlerts")
---@alias ChatChannelInfo { name: string, color: string, event: string }

local function HasSecretValues(...)
    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, ...)
        if ok and hasSecret then
            return true
        end
    end

    return false
end

local function IsUsablePlainString(value)
    if type(value) ~= "string" then
        return false
    end

    return not HasSecretValues(value)
end

--- Supported chat channels for monitoring. Configuration is created automatically based on added channels.
---@type table<string, ChatChannelInfo>
ChatAlertsModule.SupportedChannels = {
    BATTLE_NET = { name = "Battle.net", color = "#00FFF6", event = "CHAT_MSG_BN_WHISPER" },
    GUILD = { name = "Guild", color = "#40FF40", event = "CHAT_MSG_GUILD" },
    INSTANCE = { name = "Instance", color = "#FFA000", event = "CHAT_MSG_INSTANCE_CHAT" },
    PARTY = { name = "Party", color = "#8080FF", event = "CHAT_MSG_PARTY" },
    RAID = { name = "Raid", color = "#FF4040", event = "CHAT_MSG_RAID" },
    WHISPER = { name = "Whisper", color = "#FF80FF", event = "CHAT_MSG_WHISPER" },
}

-- Supress the default tell message sound
function ChatAlertsModule:SupressBlizzardTellSound()
    if self.blizzardTellSoundSuppressed then
        return
    end

    MuteSoundFile(SOUNDKIT.TELL_MESSAGE)
    self.blizzardTellSoundSuppressed = true
end

--- Determines if a channel has been registered for custom sounds.
--- @param channelInfo ChatChannelInfo the channel to check
--- @return boolean true if the channel is registered, false otherwise
function ChatAlertsModule:IsCustomSoundChannelRegistered(channelInfo)
    for _, registeredChannel in ipairs(self.soundChannels or {}) do
        if registeredChannel.event == channelInfo.event then
            return true
        end
    end
    return false
end

--- Determines if a channel has been registered for keyword monitoring.
--- @param channelInfo ChatChannelInfo the channel to check
--- @return boolean true if the channel is registered, false otherwise
function ChatAlertsModule:IsKeywordChannelRegistered(channelInfo)
    for _, registeredChannel in ipairs(self.keywordChannels or {}) do
        if registeredChannel.event == channelInfo.event then
            return true
        end
    end
    return false
end

---Registers a channel for monitoring based on the given parameters.
---@param channelInfo ChatChannelInfo the channel to monitor
---@param isKeywordChannel boolean whether to monitor keywords on this channel
---@param isCustomSoundChannel boolean whether to play custom sounds on this channel
function ChatAlertsModule:RegisterChannelMonitoring(channelInfo, isKeywordChannel, isCustomSoundChannel)
    -- register to frame if not already registered
    if not self.frame:IsEventRegistered(channelInfo.event) then
        self.frame:RegisterEvent(channelInfo.event)
    end

    -- ensure it in the lists
    if isKeywordChannel and not self:IsKeywordChannelRegistered(channelInfo) then
        tinsert(self.keywordChannels, channelInfo)
    end

    if isCustomSoundChannel and not self:IsCustomSoundChannelRegistered(channelInfo) then
        tinsert(self.soundChannels, channelInfo)
    end
end

--- Resets the module, removing all event listeners and clearing registered channels.
function ChatAlertsModule:Clear()
    if self.frame then
        self.frame:UnregisterAllEvents()
        self.frame:SetScript("OnEvent", nil)
        self.frame = nil
    end

    if self.blizzardTellSoundSuppressed then
        UnmuteSoundFile(SOUNDKIT.TELL_MESSAGE)
        self.blizzardTellSoundSuppressed = false
    end

    wipe(self.registeredChannels)
    wipe(self.soundChannels)
    wipe(self.keywordChannels)
end

--- Refreshes the list of keywords to monitor based on configuration settings.
function ChatAlertsModule:RefreshKeywords()
    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    self.monitorKeywords = CM.Options.ChatEnhancement:IsKeywordAlertsEnabled()

    if not self.monitorKeywords then
        self.keyWords = nil
        return
    end

    local function trim(s)
        -- trim leading/trailing whitespace
        return (s:gsub("^%s*(.-)%s*$", "%1"))
    end

    local function csvToList(input)
        local t = {}
        for field in (input .. ","):gmatch("(.-),") do
            field = trim(field)
            if field ~= "" then
                field = field:lower()
                table.insert(t, field)
            end
        end
        return t
    end

    if CM.Options.ChatEnhancement:GetKeyWords() then
        self.keyWords = csvToList(CM.Options.ChatEnhancement:GetKeyWords())
    else
        self.keyWords = nil
    end
end

--- Retrieves the channel information for a given chat event.
--- @param event string the chat event to look up
--- @return ChatChannelInfo|nil the channel information if found, nil otherwise
function ChatAlertsModule:GetChannelForEvent(event)
    for _, channel in pairs(self.SupportedChannels) do
        if channel.event == event then
            return channel
        end
    end
    return nil
end

--- Refreshes the event listeners based on configuration settings.
--- This will clear existing listeners and re-register them as needed.
function ChatAlertsModule:RefreshEvents()
    self:Clear()

    self.frame = CreateFrame("Frame")

    -- register events based on configuration settings
    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    for _, channel in pairs(self.SupportedChannels) do
        -- register channel monitoring if enabled for channel sounds or keyword monitoring
        local isKeywordChannel = CM.Options.ChatEnhancement:GetKeywordMonitoringForChannel(channel.name)
        local isCustomSoundChannel = CM.Options.ChatEnhancement:GetChannelMonitoringEnabled(channel.name)
        if (isCustomSoundChannel or isKeywordChannel) then
            self:RegisterChannelMonitoring(channel, isKeywordChannel, isCustomSoundChannel)
        end
    end

    local function HandleChatEvent(_, event, message, sender, ...)
        local playSound = true -- prevent two sounds for a message on a channel with a sound and a keyword
        local channel = self:GetChannelForEvent(event)

        -- first handle alert keywords if enabled
        if self.monitorKeywords and self.keyWords then
            -- is this a keywords monitored channel?
            if channel and self:IsKeywordChannelRegistered(channel) then
                -- does the message have a keyword?
                if IsUsablePlainString(message) then
                    local messageLower = message:lower()
                    for _, keyword in ipairs(self.keyWords) do
                        if string.find(messageLower, keyword, 1, true) then
                            -- if so, play sound
                            local keywordSound = ChatAlertsModule:GetKeywordSound()
                            if keywordSound then
                                PlaySoundFile(keywordSound, "Master")
                                playSound = false
                            end
                            break
                        end
                    end
                end
            end
        end

        if not playSound or not self:IsCustomSoundChannelRegistered(channel) then
            return
        end

        local sound = ChatAlertsModule:GetSound(channel)

        if sound and playSound then
            PlaySoundFile(sound, "Master")
        end
    end

    self.frame:SetScript("OnEvent", HandleChatEvent)
end

--- Called by AceModule when the module is initialized.
function ChatAlertsModule:OnInitialize()
    self.registeredChannels = {}
    self.soundChannels = {}
    self.keywordChannels = {}
end

--- Called by AceModule when the module is enabled.
function ChatAlertsModule:OnEnable()
    self:RefreshEvents()   -- set up event listeners
    self:RefreshKeywords() -- load keywords

    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    self.monitorKeywords = CM.Options.ChatEnhancement:IsKeywordAlertsEnabled() -- determine if user configured keyword monitoring

    -- supress default tell sound if needed
    if CM.Options.ChatEnhancement:IsBlizzardTellSoundSupressed() then
        self:SupressBlizzardTellSound()
    end
end

--- Called by AceModule when the module is disabled.
function ChatAlertsModule:OnDisable()
    self:Clear()
end

--- Determines the sound file path for keyword alerts.
--- @return string|nil the sound file path if set, nil otherwise
function ChatAlertsModule:GetKeywordSound()
    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    local soundKey = CM.Options.ChatEnhancement:GetKeyWordAlertSound() or nil
    if soundKey and soundKey ~= "None" then
        local LSM = LibStub("LibSharedMedia-3.0")
        local path = LSM and LSM:Fetch("sound", soundKey)
        return path
    end

    return nil;
end

--- Determines the sound file path for a given channel.
---@param channelInfo ChatChannelInfo the channel to get the sound for
---@return string|nil the sound file path if set, nil otherwise
function ChatAlertsModule:GetSound(channelInfo)
    local soundKey = nil

    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    soundKey = CM.Options.ChatEnhancement:GetChannelMonitoringEnabled(channelInfo.name)

    if not channelInfo then
        return nil
    end

    soundKey = CM.Options.ChatEnhancement:GetAlertSoundForChannel(channelInfo.name)

    if soundKey and soundKey ~= "None" then
        local LSM = LibStub("LibSharedMedia-3.0")
        local path = LSM and LSM:Fetch("sound", soundKey)
        return path
    end

    return nil;
end
