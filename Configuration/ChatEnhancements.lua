---@diagnostic disable: undefined-field
--[[
    Configuration for chat enhancements.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local DEFAULT_SOUND = "TwichUI Chat Ping"

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local Widgets = ConfigurationModule.Widgets

--- @type ChatEnhancementConfigurationOptions
local Options = ConfigurationModule.Options.ChatEnhancement

local function BuildChatEnhancementConfiguration()
    local channelSectionOrder = 0
    ---@type ChatAlertsModule
    local chatAlertsModule = T:GetModule("ChatEnhancements"):GetModule("ChatAlerts")

    local function SetAbbreviationValue(key, value)
        Options:SetAbbreviation(key, value)
    end

    local function GetAbbreviationValue(key)
        return Options:GetAbbreviation(key)
    end

    local function CreateAbbreviationInput(order, label, key, description)
        return {
            type = "input",
            name = label,
            desc = description,
            order = order,
            width = "half",
            get = function()
                return GetAbbreviationValue(key)
            end,
            set = function(_, value)
                SetAbbreviationValue(key, value)
            end,
        }
    end

    local function CreateChannelColorOption(order, label, key, description)
        return {
            type = "color",
            name = label,
            desc = description,
            order = order,
            width = "half",
            get = function()
                return Options:GetChannelColor(key)
            end,
            set = function(_, r, g, b)
                Options:SetChannelColor(key, r, g, b)
            end,
        }
    end

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

                        chatAlertsModule:RefreshEvents()
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

                chatAlertsModule:RefreshKeywords()
            end
        }
    end

    local optionsTab = Widgets.NewConfigurationSection(20, "Chat")


    optionsTab.args = {
        title = Widgets.TitleWidget(0, "Chat Module"),
        visualsGroup = {
            type = "group",
            name = "Visuals",
            order = 2,
            childGroups = "tab",
            args = {
                -- ──────────────── General ────────────────
                generalTab = {
                    type = "group",
                    name = "General",
                    order = 1,
                    inline = true,
                    args = {
                        enableStyling = {
                            type = "toggle",
                            name = "Enable Styling",
                            desc = "Apply addon formatting to Blizzard chat frames.",
                            order = 1,
                            width = "half",
                            handler = Options,
                            get = "IsStylingEnabled",
                            set = "SetStylingEnabled",
                        },
                        animationsEnabled = {
                            type = "toggle",
                            name = "Animations",
                            desc = "Enable tab and control-strip fades for the bespoke chat shell.",
                            order = 2,
                            width = "half",
                            handler = Options,
                            get = "AreAnimationsEnabled",
                            set = "SetAnimationsEnabled",
                        },
                        chatLocked = {
                            type = "toggle",
                            name = "Lock Chat",
                            desc =
                            "Prevent the chat frame from being moved or resized and hide the drag and resize handles.",
                            order = 3,
                            width = "half",
                            handler = Options,
                            get = "IsChatLocked",
                            set = "SetChatLocked",
                        },
                        hideHeader = {
                            type = "toggle",
                            name = "Hide Header",
                            desc = "Remove the header bar entirely so messages extend to the top edge of the frame.",
                            order = 4,
                            width = "half",
                            handler = Options,
                            get = "IsHeaderHidden",
                            set = "SetHeaderHidden",
                        },
                        showChromeAccent = {
                            type = "toggle",
                            name = "Show Accent",
                            desc =
                            "Show the accent glow, left accent bar, and bottom gradient on the chat chrome. Disable for a flat, minimal look.",
                            order = 5,
                            width = "half",
                            handler = Options,
                            get = "IsChromeAccentShown",
                            set = "SetChromeAccentShown",
                        },
                        positionNote = {
                            type = "description",
                            name =
                            "Position Override — enter exact pixel coordinates to snap the chat frame to a precise location. 0, 0 = bottom-left of screen. Leave blank to let WoW manage position.",
                            order = 10,
                            width = "full",
                        },
                        positionX = {
                            type = "input",
                            name = "Position X",
                            desc = "Horizontal offset in pixels from the left edge of the screen (BOTTOMLEFT anchor).",
                            order = 11,
                            width = "half",
                            handler = Options,
                            get = "GetChatPositionXStr",
                            set = "SetChatPositionX",
                        },
                        positionY = {
                            type = "input",
                            name = "Position Y",
                            desc = "Vertical offset in pixels from the bottom edge of the screen.",
                            order = 12,
                            width = "half",
                            handler = Options,
                            get = "GetChatPositionYStr",
                            set = "SetChatPositionY",
                        },
                        positionCapture = {
                            type = "execute",
                            name = "Capture Current Position",
                            desc = "Read the chat frame's current on-screen position and save it as the override.",
                            order = 13,
                            width = "half",
                            func = function()
                                local stylingModule = T:GetModule("ChatEnhancements", true)
                                    and T:GetModule("ChatEnhancements"):GetModule("ChatStyling", true)
                                local x, y = stylingModule and stylingModule:CaptureCurrentPosition()
                                if x and y then
                                    Options:SetChatPositionX(nil, x)
                                    Options:SetChatPositionY(nil, y)
                                end
                            end,
                        },
                        positionClear = {
                            type = "execute",
                            name = "Clear Override",
                            desc = "Remove the position override and let WoW position the frame normally.",
                            order = 14,
                            width = "half",
                            func = function()
                                Options:ClearChatPosition()
                            end,
                        },
                    },
                },
                -- ──────────────── Fonts ────────────────
                fontsTab = {
                    type = "group",
                    name = "Fonts",
                    order = 2,
                    inline = true,
                    args = {
                        chatFont = {
                            type = "select",
                            dialogControl = "LSM30_Font",
                            name = "Chat Font",
                            desc = "Font used for chat lines and the edit box.",
                            order = 1,
                            width = "half",
                            handler = Options,
                            get = "GetChatFont",
                            set = "SetChatFont",
                            values = function() return LibStub("LibSharedMedia-3.0"):HashTable("font") or {} end,
                        },
                        chatFontSize = {
                            type = "range",
                            name = "Chat Font Size",
                            desc = "Font size used for chat lines and the edit box.",
                            order = 2,
                            width = "half",
                            min = 10,
                            max = 20,
                            step = 1,
                            handler = Options,
                            get = "GetChatFontSize",
                            set = "SetChatFontSize",
                        },
                        tabFont = {
                            type = "select",
                            dialogControl = "LSM30_Font",
                            name = "Tab Font",
                            desc = "Font used for the custom chat tab bar.",
                            order = 3,
                            width = "half",
                            handler = Options,
                            get = "GetTabFont",
                            set = "SetTabFont",
                            values = function() return LibStub("LibSharedMedia-3.0"):HashTable("font") or {} end,
                        },
                        tabFontSize = {
                            type = "range",
                            name = "Tab Font Size",
                            desc = "Font size used for the custom chat tab bar.",
                            order = 4,
                            width = "half",
                            min = 10,
                            max = 18,
                            step = 1,
                            handler = Options,
                            get = "GetTabFontSize",
                            set = "SetTabFontSize",
                        },
                    },
                },
                -- ──────────────── Colors ────────────────
                colorsTab = {
                    type = "group",
                    name = "Colors",
                    order = 3,
                    inline = true,
                    args = {
                        shellAccent = {
                            type = "color",
                            name = "Shell Accent",
                            desc = "Primary accent used for tabs, borders, scroll chrome, and shell highlights.",
                            order = 1,
                            width = "half",
                            handler = Options,
                            get = "GetShellAccentColor",
                            set = "SetShellAccentColor",
                        },
                        headerBgColor = {
                            type = "color",
                            name = "Header Background",
                            desc = "Background fill of the header area. Set alpha to 0 to hide it entirely.",
                            order = 2,
                            width = "half",
                            hasAlpha = true,
                            handler = Options,
                            get = "GetHeaderBgColor",
                            set = "SetHeaderBgColor",
                        },
                        chatBgColor = {
                            type = "color",
                            name = "Frame Background",
                            desc = "Fill color and opacity of the chat frame chrome background.",
                            order = 3,
                            width = "half",
                            hasAlpha = true,
                            handler = Options,
                            get = "GetChatBgColor",
                            set = "SetChatBgColor",
                        },
                        chatBorderColor = {
                            type = "color",
                            name = "Frame Border",
                            desc = "Color and opacity of the chat frame chrome border.",
                            order = 4,
                            width = "half",
                            hasAlpha = true,
                            handler = Options,
                            get = "GetChatBorderColor",
                            set = "SetChatBorderColor",
                        },
                        msgBgColor = {
                            type = "color",
                            name = "Message Background",
                            desc = "Fill color and opacity of each chat message row.",
                            order = 5,
                            width = "half",
                            hasAlpha = true,
                            handler = Options,
                            get = "GetMsgBgColor",
                            set = "SetMsgBgColor",
                        },
                    },
                },
                -- ──────────────── Messages ────────────────
                messagesTab = {
                    type = "group",
                    name = "Messages",
                    order = 4,
                    inline = true,
                    args = {
                        accentBar = {
                            type = "toggle",
                            name = "Accent Separator",
                            desc = "Add a colored left-edge bar to each message row.",
                            order = 1,
                            width = "half",
                            handler = Options,
                            get = "ShouldShowAccentBar",
                            set = "SetShowAccentBar",
                        },
                        showClassIcons = {
                            type = "toggle",
                            name = "Class Icons",
                            desc = "Show a class icon next to each player message.",
                            order = 2,
                            width = "half",
                            handler = Options,
                            get = "IsClassIconsEnabled",
                            set = "SetClassIconsEnabled",
                        },
                        classIconStyle = {
                            type = "select",
                            name = "Icon Style",
                            desc = "Artwork used for class icons.",
                            order = 3,
                            width = "half",
                            handler = Options,
                            get = "GetClassIconStyle",
                            set = "SetClassIconStyle",
                            values = {
                                ["default"] = "Default",
                                ["fabled"]  = "Fabled",
                                ["pixel"]   = "Pixel",
                            },
                        },
                        rowGap = {
                            type = "range",
                            name = "Message Gap",
                            desc = "Vertical spacing between rendered chat entries.",
                            order = 4,
                            width = "half",
                            min = 2,
                            max = 20,
                            step = 1,
                            handler = Options,
                            get = "GetRowGap",
                            set = "SetRowGap",
                        },
                        timestampsEnabled = {
                            type = "toggle",
                            name = "Timestamps",
                            desc = "Show a compact timestamp before each message.",
                            order = 5,
                            width = "half",
                            handler = Options,
                            get = "AreTimestampsEnabled",
                            set = "SetTimestampsEnabled",
                        },
                        timestampFormat = {
                            type = "select",
                            name = "Timestamp Format",
                            desc = "Choose the timestamp format used in chat.",
                            order = 6,
                            width = "half",
                            handler = Options,
                            get = "GetTimestampFormat",
                            set = "SetTimestampFormat",
                            values = {
                                ["%H:%M"] = "24h, minutes",
                                ["%H:%M:%S"] = "24h, seconds",
                                ["%I:%M %p"] = "12h, minutes",
                            },
                        },
                        timestampWidth = {
                            type = "range",
                            name = "Timestamp Width",
                            desc = "Width of the timestamp column on the left edge.",
                            order = 7,
                            width = "half",
                            min = 36,
                            max = 120,
                            step = 2,
                            handler = Options,
                            get = "GetTimestampWidth",
                            set = "SetTimestampWidth",
                        },
                        preview = {
                            type = "description",
                            name = T.Tools.Text.Color(T.Tools.Colors.GRAY,
                                "Preview: [12:34] | [G] Twich: Pull in 10"),
                            order = 8,
                            width = "full",
                        },
                    },
                },
                -- ──────────────── Fading ────────────────
                fadingTab = {
                    type = "group",
                    name = "Fading",
                    order = 5,
                    inline = true,
                    args = {
                        messageFadesEnabled = {
                            type = "toggle",
                            name = "Enable Fading",
                            desc = "Fade old messages when the view is resting at the bottom and the cursor is away.",
                            order = 1,
                            width = "half",
                            handler = Options,
                            get = "AreMessageFadesEnabled",
                            set = "SetMessageFadesEnabled",
                        },
                        messageFadeDelay = {
                            type = "range",
                            name = "Fade Delay",
                            desc = "Seconds after the cursor leaves before old messages begin fading.",
                            order = 2,
                            width = "half",
                            min = 10,
                            max = 300,
                            step = 1,
                            handler = Options,
                            get = "GetMessageFadeDelay",
                            set = "SetMessageFadeDelay",
                        },
                        messageFadeDuration = {
                            type = "range",
                            name = "Fade Duration",
                            desc = "Seconds the fade-out animation should take once it starts.",
                            order = 3,
                            width = "half",
                            min = 1,
                            max = 20,
                            step = 1,
                            handler = Options,
                            get = "GetMessageFadeDuration",
                            set = "SetMessageFadeDuration",
                        },
                        messageFadeMinAlpha = {
                            type = "range",
                            name = "Minimum Opacity",
                            desc = "The lowest opacity messages can fade to. 0 = fully invisible, 1 = fully opaque.",
                            order = 4,
                            width = "half",
                            min = 0.0,
                            max = 1.0,
                            step = 0.05,
                            handler = Options,
                            get = "GetMessageFadeMinAlpha",
                            set = "SetMessageFadeMinAlpha",
                        },
                    },
                },
            },
        },
        tabsGroup = {
            type = "group",
            name = "Tabs",
            order = 7,
            inline = true,
            args = {
                tabStyle = {
                    type = "select",
                    name = "Tab Style",
                    desc =
                    "Visual style for chat tabs. Solid renders filled pill buttons; Transparent renders text-only with an accent underline.",
                    order = 1,
                    width = "half",
                    handler = Options,
                    get = "GetTabStyle",
                    set = "SetTabStyle",
                    values = {
                        solid = "Solid",
                        transparent = "Transparent",
                        unified = "Unified",
                    },
                },
                tabBgColor = {
                    type = "color",
                    name = "Tab Background",
                    desc = "Base fill color for inactive tab buttons (solid style only).",
                    order = 2,
                    width = "half",
                    handler = Options,
                    get = "GetTabBgColor",
                    set = "SetTabBgColor",
                },
                tabNameFade = {
                    type = "toggle",
                    name = "Fade Tab Names",
                    desc = "Dim tab label text when the tab is not selected or hovered.",
                    order = 1.5,
                    width = "half",
                    handler = Options,
                    get = "IsTabNameFadeEnabled",
                    set = "SetTabNameFadeEnabled",
                },
                tabBorderColor = {
                    type = "color",
                    name = "Tab Border",
                    desc = "Border and hover accent color for tab buttons (solid style only).",
                    order = 3,
                    width = "half",
                    handler = Options,
                    get = "GetTabBorderColor",
                    set = "SetTabBorderColor",
                },
                tabAccentColor = {
                    type = "color",
                    name = "Tab Accent",
                    desc = "Accent bar color shown on the selected tab and in transparent underline mode.",
                    order = 4,
                    width = "half",
                    handler = Options,
                    get = "GetTabAccentColor",
                    set = "SetTabAccentColor",
                },
            },
        },
        editBoxGroup = {
            type = "group",
            name = "Edit Box",
            order = 8,
            inline = true,
            args = {
                editBoxPosition = {
                    type = "select",
                    name = "Position",
                    desc = "Whether the edit box sits above or below the chat frame.",
                    order = 1,
                    width = "half",
                    handler = Options,
                    get = "GetEditBoxPosition",
                    set = "SetEditBoxPosition",
                    values = {
                        below = "Below (default)",
                        above = "Above",
                    },
                },
                editBoxHeight = {
                    type = "range",
                    name = "Height",
                    desc = "Height of the chat input box in pixels. Width always matches the chat frame.",
                    order = 2,
                    width = "half",
                    min = 20,
                    max = 60,
                    step = 1,
                    handler = Options,
                    get = "GetEditBoxHeight",
                    set = "SetEditBoxHeight",
                },
                editBoxBgColor = {
                    type = "color",
                    name = "Background",
                    desc = "Fill color and opacity of the edit box background.",
                    order = 3,
                    width = "half",
                    hasAlpha = true,
                    handler = Options,
                    get = "GetEditBoxBgColor",
                    set = "SetEditBoxBgColor",
                },
                editBoxPaddingH = {
                    type = "range",
                    name = "Horizontal Padding",
                    desc = "Left and right text inset inside the edit box.",
                    order = 4,
                    width = "half",
                    min = 2,
                    max = 24,
                    step = 1,
                    handler = Options,
                    get = "GetEditBoxPaddingH",
                    set = "SetEditBoxPaddingH",
                },
                editBoxPaddingV = {
                    type = "range",
                    name = "Vertical Padding",
                    desc = "Top and bottom text inset inside the edit box.",
                    order = 5,
                    width = "half",
                    min = 0,
                    max = 12,
                    step = 1,
                    handler = Options,
                    get = "GetEditBoxPaddingV",
                    set = "SetEditBoxPaddingV",
                },
                editBoxFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Font",
                    desc = "Font used in the chat edit box. Leave blank to inherit the chat font.",
                    order = 6,
                    width = "half",
                    handler = Options,
                    get = "GetEditBoxFont",
                    set = "SetEditBoxFont",
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("font") or {} end,
                },
                editBoxFontSize = {
                    type = "range",
                    name = "Font Size",
                    desc = "Font size for the chat edit box. 0 inherits the chat font size.",
                    order = 7,
                    width = "half",
                    min = 0,
                    max = 20,
                    step = 1,
                    handler = Options,
                    get = "GetEditBoxFontSize",
                    set = "SetEditBoxFontSize",
                },
            },
        },
        debugGroup = {
            type = "group",
            name = "Debugging",
            order = 4,
            inline = true,
            args = {
                description = {
                    type = "description",
                    name =
                    "Capture optional chat renderer and shell diagnostics in the shared /tui debug console. Leave this disabled during normal play to avoid extra logging overhead.",
                    order = 1,
                    width = "full",
                },
                enableDebug = {
                    type = "toggle",
                    name = "Enable Debug Capture",
                    desc = "Record chat tab, layout, drag, and scroll diagnostics in the shared debug console.",
                    order = 2,
                    width = "half",
                    disabled = function()
                        return not Options:IsStylingEnabled()
                    end,
                    handler = Options,
                    get = "GetDebugEnabled",
                    set = "SetDebugEnabled",
                },
                openDebug = {
                    type = "execute",
                    name = "Open Debug Console",
                    desc = "Open the shared debug console focused on chat.",
                    order = 3,
                    width = "half",
                    handler = Options,
                    func = "OpenDebugConsole",
                },

            },
        },
        channelColorsGroup = {
            type = "group",
            name = "Channel Colors",
            order = 5,
            childGroups = "tab",
            args = {
                openWorld = {
                    type = "group",
                    name = "Open World",
                    order = 1,
                    args = {
                        generalColor = CreateChannelColorOption(1, "General", "general",
                            "Color used for General and World chat."),
                        tradeColor = CreateChannelColorOption(2, "Trade", "trade", "Color used for Trade chat."),
                        defenseColor = CreateChannelColorOption(3, "Local Defense", "localDefense",
                            "Color used for Local Defense chat."),
                        lfgColor = CreateChannelColorOption(4, "Looking For Group", "lookingForGroup",
                            "Color used for Looking For Group chat."),
                        servicesColor = CreateChannelColorOption(5, "Services", "services",
                            "Color used for Services chat."),
                        newcomerColor = CreateChannelColorOption(6, "Newcomer", "newcomer",
                            "Color used for Newcomer chat."),
                    },
                },
                groups = {
                    type = "group",
                    name = "Groups",
                    order = 2,
                    args = {
                        guildColor = CreateChannelColorOption(1, "Guild", "guild",
                            "Color used for guild chat and matching edit-box accents."),
                        officerColor = CreateChannelColorOption(2, "Officer", "officer", "Color used for officer chat."),
                        partyColor = CreateChannelColorOption(3, "Party", "party", "Color used for party chat."),
                        partyLeaderColor = CreateChannelColorOption(4, "Party Leader", "partyLeader",
                            "Color used for party leader chat."),
                        raidColor = CreateChannelColorOption(5, "Raid", "raid", "Color used for raid chat."),
                        raidLeaderColor = CreateChannelColorOption(6, "Raid Leader", "raidLeader",
                            "Color used for raid leader chat."),
                        instanceColor = CreateChannelColorOption(7, "Instance", "instance",
                            "Color used for instance chat."),
                        instanceLeaderColor = CreateChannelColorOption(8, "Instance Leader", "instanceLeader",
                            "Color used for instance leader chat."),
                    },
                },
                private = {
                    type = "group",
                    name = "Private",
                    order = 3,
                    args = {
                        battleNetWhisperColor = CreateChannelColorOption(1, "Battle.net Whisper",
                            "battleNetWhisper", "Color used for Battle.net whispers and tells."),
                        whisperColor = CreateChannelColorOption(2, "Whisper", "whisper",
                            "Color used for whispers and tells."),
                        addonColor = CreateChannelColorOption(3, "Addon Output", "addon",
                            "Color used for redirected addon output."),
                    },
                },
                chatTypes = {
                    type = "group",
                    name = "Chat Types",
                    order = 4,
                    args = {
                        sayColor = CreateChannelColorOption(1, "Say", "say",
                            "Color used for /say messages."),
                        yellColor = CreateChannelColorOption(2, "Yell", "yell",
                            "Color used for /yell messages."),
                        emoteColor = CreateChannelColorOption(3, "Emote", "emote",
                            "Color used for emote messages."),
                    },
                },
            },
        },
        abbreviationsGroup = {
            type = "group",
            name = "Abbreviations",
            order = 6,
            childGroups = "tab",
            args = {
                general = {
                    type = "group",
                    name = "Open World",
                    order = 1,
                    args = {
                        enableAbbreviations = {
                            type = "toggle",
                            name = "Enable",
                            desc = "Replace long chat channel labels with shorter versions.",
                            order = 1,
                            width = "half",
                            handler = Options,
                            get = "AreAbbreviationsEnabled",
                            set = "SetAbbreviationsEnabled",
                        },
                        help = {
                            type = "description",
                            name = T.Tools.Text.Color(T.Tools.Colors.GRAY,
                                "Leave a field empty to fall back to the default abbreviation."),
                            order = 2,
                            width = "full",
                        },
                        generalInput = CreateAbbreviationInput(3, "General", "general", "Used for General / World chat."),
                        tradeInput = CreateAbbreviationInput(4, "Trade", "trade", "Used for Trade chat."),
                        defenseInput = CreateAbbreviationInput(5, "Local Defense", "localDefense",
                            "Used for Local Defense chat."),
                        lfgInput = CreateAbbreviationInput(6, "Looking For Group", "lookingForGroup",
                            "Used for Looking For Group chat."),
                        servicesInput = CreateAbbreviationInput(7, "Services", "services",
                            "Used for Services chat."),
                        newcomerInput = CreateAbbreviationInput(8, "Newcomer", "newcomer",
                            "Used for Newcomer chat."),
                    },
                },
                group = {
                    type = "group",
                    name = "Groups",
                    order = 2,
                    args = {
                        guildInput = CreateAbbreviationInput(1, "Guild", "guild", "Used for guild chat."),
                        officerInput = CreateAbbreviationInput(2, "Officer", "officer", "Used for officer chat."),
                        partyInput = CreateAbbreviationInput(3, "Party", "party", "Used for party chat."),
                        partyLeaderInput = CreateAbbreviationInput(4, "Party Leader", "partyLeader",
                            "Used for party leader chat."),
                        raidInput = CreateAbbreviationInput(5, "Raid", "raid", "Used for raid chat."),
                        raidLeaderInput = CreateAbbreviationInput(6, "Raid Leader", "raidLeader",
                            "Used for raid leader chat."),
                        instanceInput = CreateAbbreviationInput(7, "Instance", "instance",
                            "Used for instance chat."),
                        instanceLeaderInput = CreateAbbreviationInput(8, "Instance Leader", "instanceLeader",
                            "Used for instance leader chat."),
                    },
                },
            },
        },
        alertsGroup = {
            type = "group",
            name = "Alerts",
            order = 11,
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
                    "Channel and keyword-driven alerts inspired by the lower-overhead parts of ElvUI's chat tooling.",
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
                        keywordHighlightEnabled = {
                            type = "toggle",
                            name = "Highlight Keyword Rows",
                            desc = "Visually highlight chat rows whose message matches one of your keywords.",
                            order = 3.5,
                            width = "half",
                            handler = Options,
                            get = "IsKeywordHighlightEnabled",
                            set = "SetKeywordHighlightEnabled",
                        },
                        keywordHighlightColor = {
                            type = "color",
                            name = "Highlight Color",
                            desc = "Color used for the row tint and accent bar on keyword-matched messages.",
                            order = 3.6,
                            width = "half",
                            handler = Options,
                            get = "GetKeywordHighlightColor",
                            set = "SetKeywordHighlightColor",
                        },
                        monitoredChannelsGroup = {
                            type = "group",
                            name = "Monitored Channels",
                            order = 5,
                            inline = true,
                            args = (function()
                                local args = {}

                                for _, channel in pairs(chatAlertsModule.SupportedChannels) do
                                    args[channel.name .. "Toggle"] = CreateChatChannelToggle(channel)
                                end
                                return args
                            end)(),
                        }
                    }
                },
            }
        },
        routingGroup = {
            type = "group",
            name = "Routing",
            order = 9,
            inline = true,
            args = {
                whisperTabs = {
                    type = "toggle",
                    name = "Whisper Tabs",
                    desc =
                    "Automatically open a dedicated chat tab for each whisper sender so conversations stay grouped. Replies are mirrored there too.",
                    order = 1,
                    width = "half",
                    handler = Options,
                    get = "IsWhisperTabEnabled",
                    set = "SetWhisperTabEnabled",
                },
                routingDesc = {
                    type = "description",
                    order = 5,
                    width = "full",
                    name = T.Tools.Text.Color(T.Tools.Colors.GRAY,
                        "Keyword Routing: redirect any message whose text contains a pattern to a specific chat tab. Plain-text matching, case-sensitive."),
                },
                routingColumnPat = {
                    type = "description",
                    order = 9,
                    width = "double",
                    name = T.Tools.Text.Color(T.Tools.Colors.MUTED, "  Match (plain text)"),
                },
                routingColumnTab = {
                    type = "description",
                    order = 9.5,
                    width = "normal",
                    name = T.Tools.Text.Color(T.Tools.Colors.MUTED, "  Route To Tab"),
                },
                routingColumnSpacer = {
                    type = "description",
                    order = 9.6,
                    width = "half",
                    name = "",
                },
                routingAddBtn = {
                    type = "execute",
                    name = "+ Add Rule",
                    desc = "Add a new keyword routing rule.",
                    order = 10,
                    width = "half",
                    func = function()
                        Options:AddRoutingEntry()
                        ConfigurationModule:Refresh()
                    end,
                },
            },
        },
        headerDatatextGroup = {
            type = "group",
            name = "Header Datatexts",
            order = 8.5,
            inline = true,
            args = {
                headerDatatextNote = {
                    type = "description",
                    order = 0,
                    width = "full",
                    name =
                    "Display up to 3 datatext cells in the chat header area below the drag strip. Supports all datatexts registered in the Datatexts module.",
                },
                headerDatatextEnabled = {
                    type = "toggle",
                    name = "Enable Header Bar",
                    desc = "Show a row of datatext cells inside the chat header.",
                    order = 1,
                    width = "half",
                    handler = Options,
                    get = "IsHeaderDatatextEnabled",
                    set = "SetHeaderDatatextEnabled",
                },
                headerDatatextSlotCount = {
                    type = "range",
                    name = "Slot Count",
                    desc = "Number of datatext cells to display (1-3).",
                    order = 2,
                    width = "half",
                    min = 1,
                    max = 3,
                    step = 1,
                    handler = Options,
                    get = "GetHeaderDatatextSlotCount",
                    set = "SetHeaderDatatextSlotCount",
                },
                headerDatatextSlotWidth = {
                    type = "range",
                    name = "Slot Width",
                    desc = "Width of each datatext slot cell in pixels.",
                    order = 2.5,
                    width = "half",
                    min = 32,
                    max = 200,
                    step = 4,
                    handler = Options,
                    get = "GetHeaderDatatextSlotWidth",
                    set = "SetHeaderDatatextSlotWidth",
                },
                headerDatatextSlot1 = {
                    type = "select",
                    name = "Slot 1",
                    desc = "Datatext to display in the first slot.",
                    order = 3,
                    width = "half",
                    values = function() return Options:GetHeaderDatatextChoices() end,
                    get = function() return Options:GetHeaderDatatextSlot(1) end,
                    set = function(_, value) Options:SetHeaderDatatextSlot(1, value) end,
                },
                headerDatatextSlot2 = {
                    type = "select",
                    name = "Slot 2",
                    desc = "Datatext to display in the second slot.",
                    order = 4,
                    width = "half",
                    values = function() return Options:GetHeaderDatatextChoices() end,
                    get = function() return Options:GetHeaderDatatextSlot(2) end,
                    set = function(_, value) Options:SetHeaderDatatextSlot(2, value) end,
                },
                headerDatatextSlot3 = {
                    type = "select",
                    name = "Slot 3",
                    desc = "Datatext to display in the third slot.",
                    order = 5,
                    width = "half",
                    values = function() return Options:GetHeaderDatatextChoices() end,
                    get = function() return Options:GetHeaderDatatextSlot(3) end,
                    set = function(_, value) Options:SetHeaderDatatextSlot(3, value) end,
                },
                headerDatatextFontSize = {
                    type = "range",
                    name = "Font Size",
                    desc = "Font size for header datatext cells (8-18).",
                    order = 6,
                    width = "half",
                    min = 8,
                    max = 18,
                    step = 1,
                    handler = Options,
                    get = "GetHeaderDatatextFontSize",
                    set = "SetHeaderDatatextFontSize",
                },
                headerDatatextFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Font",
                    desc = "Override font used by the header datatext cells.",
                    order = 6.5,
                    width = "half",
                    handler = Options,
                    get = "GetHeaderDatatextFont",
                    set = "SetHeaderDatatextFont",
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("font") or {} end,
                },
                headerDatatextCustomColor = {
                    type = "toggle",
                    name = "Custom Text Color",
                    desc = "Use a custom color for the header datatext cells instead of the default white.",
                    order = 7,
                    width = "half",
                    handler = Options,
                    get = "GetHeaderDatatextUseCustomTextColor",
                    set = "SetHeaderDatatextUseCustomTextColor",
                },
                headerDatatextTextColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the header datatext cell text.",
                    order = 8,
                    width = "half",
                    disabled = function() return not Options:GetHeaderDatatextUseCustomTextColor() end,
                    hasAlpha = false,
                    handler = Options,
                    get = "GetHeaderDatatextTextColor",
                    set = "SetHeaderDatatextTextColor",
                },
            },
        },
        messagesGroup = {
            type = "group",
            name = "Messages",
            order = 10,
            inline = true,
            args = {
                msgNote = {
                    type = "description",
                    order = 0,
                    width = "full",
                    name = "Configure how chat messages are displayed and retained.",
                },
                hideRealm = {
                    type = "toggle",
                    name = "Hide Realm Name",
                    desc =
                    "Strip the -RealmName suffix from player names in chat messages. The hyperlink target is kept intact so right-clicking still works.",
                    order = 1,
                    width = "full",
                    handler = Options,
                    get = "IsRealmHidden",
                    set = "SetRealmHidden",
                },
                historyLimit = {
                    type = "range",
                    name = "History Limit",
                    desc =
                    "Maximum number of messages to retain per chat frame. Older messages are trimmed when the limit is reached.",
                    order = 2,
                    width = "full",
                    min = 50,
                    max = 500,
                    step = 10,
                    handler = Options,
                    get = "GetChatHistoryLimit",
                    set = "SetChatHistoryLimit",
                },
                persistHistory = {
                    type = "toggle",
                    name = "Persist History Across Reloads",
                    desc =
                    "Save recent chat lines from each chat window and restore them after a reload or relog when Blizzard would otherwise drop them.",
                    order = 3,
                    width = "full",
                    handler = Options,
                    get = "IsChatHistoryPersistenceEnabled",
                    set = "SetChatHistoryPersistenceEnabled",
                },
                addonRedirect = {
                    type = "toggle",
                    name = "Redirect Addon Output",
                    desc =
                    "Route CHAT_MSG_ADDON traffic into a chat window named \"AddOns\". Create that window first via the + tab button, name it AddOns, then enable this.",
                    order = 4,
                    width = "half",
                    handler = Options,
                    get = "IsAddonRedirectEnabled",
                    set = "SetAddonRedirectEnabled",
                },
            },
        },
    }

    for _, channel in pairs(chatAlertsModule.SupportedChannels) do
        optionsTab.args.alertsGroup.args[channel.name .. "Group"] = CreateChannelConfigurationSection(channel)
    end

    -- Build dynamic routing entry slots (up to 20).  Each slot shows only when
    -- its index references a real entry in Options:GetRoutingEntries().
    do
        local MAX_ROUTING_SLOTS = 20
        local routingArgs = optionsTab.args.routingGroup.args
        for i = 1, MAX_ROUTING_SLOTS do
            local idx = i -- capture loop variable for closures
            routingArgs["routingPat_" .. idx] = {
                type   = "input",
                name   = "",
                desc   =
                "Plain-text pattern. Any message containing this text (case-sensitive) is redirected to the chosen tab.",
                order  = 100 + idx * 3,
                width  = "double",
                hidden = function()
                    return idx > #Options:GetRoutingEntries()
                end,
                get    = function()
                    return Options:GetRoutingEntryPattern(idx)
                end,
                set    = function(info, val)
                    Options:SetRoutingEntryPattern(idx, val)
                end,
            }
            routingArgs["routingTab_" .. idx] = {
                type    = "select",
                name    = "",
                desc    = "Chat tab that matching messages will be routed to.",
                order   = 100 + idx * 3 + 1,
                width   = "normal",
                hidden  = function()
                    return idx > #Options:GetRoutingEntries()
                end,
                values  = function()
                    return Options:GetAvailableChatTabs()
                end,
                sorting = function()
                    local t = Options:GetAvailableChatTabs()
                    local s = {}
                    for k in pairs(t) do s[#s + 1] = k end
                    table.sort(s)
                    return s
                end,
                get     = function()
                    local v    = Options:GetRoutingEntryTab(idx)
                    local tabs = Options:GetAvailableChatTabs()
                    -- Return nil if the stored tab no longer exists (avoids AceConfig warning).
                    return tabs[v] and v or nil
                end,
                set     = function(info, val)
                    Options:SetRoutingEntryTab(idx, val)
                end,
            }
            routingArgs["routingRemove_" .. idx] = {
                type   = "execute",
                name   = "Remove",
                desc   = "Remove this routing rule.",
                order  = 100 + idx * 3 + 2,
                width  = "half",
                hidden = function()
                    return idx > #Options:GetRoutingEntries()
                end,
                func   = function()
                    Options:RemoveRoutingEntry(idx)
                    ConfigurationModule:Refresh()
                end,
            }
        end
    end

    return optionsTab
end

--- Register the chat enhancement configuration section with the Configuration module for display when loaded.
ConfigurationModule:RegisterConfigurationFunction("Chat", BuildChatEnhancementConfiguration)
