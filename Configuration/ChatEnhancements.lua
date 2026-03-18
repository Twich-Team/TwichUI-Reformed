--[[
    Configuration for chat enhancements.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local DEFAULT_SOUND = "TwichUI Chat Ping"

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @type ChatEnhancementConfigurationOptions
local Options = ConfigurationModule.Options.ChatEnhancement

local function BuildChatEnhancementConfiguration()
    local channelSectionOrder = 0

    local function CreateChannelConfigurationSection(channelInfo)
        channelSectionOrder = channelSectionOrder + 1
        return {
            type = "group",
            name = T.Tools.Text.Color(channelInfo.color, channelInfo.name),
            order = channelSectionOrder,
            args = {
                title = {
                    type = "description",
                    name = T.Tools.Text.Color(channelInfo.color, channelInfo.name) .. " Chat Alerts",
                    order = 1,
                    fontSize = "medium"
                },
                description = {
                    type = "description",
                    name = "Configure alerts that occur when you receive " .. channelInfo.name .. " messages in chat.",
                    order = 2,
                },
                chatAlertEnabled = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Play a sound alert when you receive a " .. channelInfo.name .. " message in chat.",
                    order = 3,
                    get = function()
                        return Options:GetChatEnhancementDB()
                            [channelInfo.name .. "ChatAlertEnabled"] or
                            false
                    end,
                    set = function(info, value)
                        Options:GetChatEnhancementDB()[channelInfo.name .. "ChatAlertEnabled"] =
                            value

                        ---@type ChatAlertsModule
                        local ChatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")

                        if value then
                            ChatAlertsModule:RefreshEvents()
                        else
                            ChatAlertsModule:RefreshEvents()
                        end
                    end,
                },
                soundSelector = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "Alert Sound",
                    desc = "The sound that will play when you receive a message.",
                    order = 5,
                    width = 2,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                    get = function()
                        return Options:GetChatEnhancementDB()
                            [channelInfo.name .. "SoundSelector"] or
                            DEFAULT_SOUND
                    end,
                    set = function(info, value)
                        Options:GetChatEnhancementDB()[channelInfo.name .. "SoundSelector"] =
                            value
                    end,
                }
            }
        }
    end

    local order = 9

    ---@param channelInfo ChatChannelInfo
    local function CreateChatChannelToggle(channelInfo)
        order = order + 1
        return {
            type = "toggle",
            name = T.Tools.Text.Color(channelInfo.color, channelInfo.name),
            desc = "Monitor " .. channelInfo.name .. " messages for keywords.",
            order = order,
            width = "full",
            handler = Options,
            get = function()
                return Options:GetChatEnhancementDB()[channelInfo.name .. "KeywordMonitoring"] or
                    false
            end,
            set = function(info, value)
                Options:GetChatEnhancementDB()[channelInfo.name .. "KeywordMonitoring"] = value

                ---@type ChatAlertsModule
                local ChatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")
                ChatAlertsModule:RefreshKeywords()
            end
        }
    end

    local optionsTab = ConfigurationModule.Widgets.NewConfigurationSection(20, "Chat")


    optionsTab.args = {
        title = ConfigurationModule.Widgets.TitleWidget(0, "Chat Enhancements"),
        desc = {
            type = "description",
            name =
            "Provides various enhancements to the chat interface.",
            order = 1,
        },
        experimentalTab = {
            type = "group",
            name = "Alerts",
            order = 2,
            childGroups = "tree",
            args = {
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable chat alerts.",
                    order = 1,
                    width = "half",
                    handler = Options,
                    get = "IsAlertsEnabled",
                    set = "SetAlertsEnabled"
                },
                SupressBlizzardTellSound = {
                    type = "toggle",
                    name = "Suppress Blizzard Tell Sound",
                    desc =
                    "Suppress the default Blizzard tell message sound that plays when you first receive a private message.",
                    order = 2,
                    width = 2,
                    handler = Options,
                    get = "IsBlizzardTellSoundSupressed",
                    set = "SetBlizzardTellSoundSupressed"
                },
                desc = {
                    type = "description",
                    name =
                    "Configure alerts for various chat events.",
                    order = 3,
                },
                wordsChatGroup = {
                    type = "group",
                    name = T.Tools.Text.Color(T.Tools.Colors.WHITE, "Keywords"),
                    order = -1,
                    args = {
                        title = {
                            type = "description",
                            name = T.Tools.Text.Color(T.Tools.Colors.PRIMARY, "Keywords"),
                            order = 1,
                            fontSize = "medium"
                        },
                        description = {
                            type = "description",
                            name = "Configure alerts that occur when you receive a message with specific keywords.",
                            order = 2,
                        },
                        bnChatAlertEnabled = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Play a sound alert when you receive a message with specific keywords.",
                            order = 2.1,
                            handler = Options,
                            get = "IsKeywordAlertsEnabled",
                            set = "SetKeywordAlertsEnabled"
                        },
                        bnSoundSelector = {
                            type = "select",
                            dialogControl = "LSM30_Sound",
                            name = "Alert Sound",
                            desc = "The sound that will play when you receive a message with a keyword in it.",
                            order = 2.2,
                            width = 2,
                            values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                            handler = Options,
                            get = "GetKeyWordAlertSound",
                            set = "SetKeyWordAlertSound"
                        },
                        spacer = {
                            type = "description",
                            name = " ",
                            order = 2.3,
                        },
                        help = {
                            type = "description",
                            name = T.Tools.Text.Color(T.Tools.Colors.GRAY,
                                "Separate multiple keywords with commas. Case does not matter."),
                            order = 2.5,
                        },
                        keywordsInput = {
                            type = "input",
                            name = "Keywords",
                            multiline = 3,
                            handler = Options,
                            get = "GetKeyWords",
                            set = "SetKeyWords",
                            order = 3,
                            width = "full",
                        },
                        monitoredChannelsGroup = {
                            type = "group",
                            name = "Monitored Channels",
                            order = 5,
                            inline = true,
                            args = (function()
                                local args = {}

                                ---@type ChatAlertsModule
                                for _, channel in pairs(T:GetModule("ChatEnhancements"):GetModule("ChatAlerts").SupportedChannels) do
                                    args[channel.name .. "Toggle"] = CreateChatChannelToggle(channel)
                                end
                                return args
                            end)(),
                        }
                    }
                },
            }
        }
    }

    for _, channel in pairs(T:GetModule("ChatEnhancements"):GetModule("ChatAlerts").SupportedChannels) do
        optionsTab.args.experimentalTab.args[channel.name .. "Group"] = CreateChannelConfigurationSection(channel)
    end
    return optionsTab
end

--- Register the chat enhancement configuration section with the Configuration module for display when loaded.
ConfigurationModule:RegisterConfigurationFunction("Chat", BuildChatEnhancementConfiguration)
