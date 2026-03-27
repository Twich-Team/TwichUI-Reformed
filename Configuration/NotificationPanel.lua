--[[
    Notification configuration.
    Consolidates per-feature alert settings alongside the panel display controls.
]]
local TwichRx             = _G["TwichRx"]
---@type TwichUI
local T                   = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
---@type TexturesTool
local Textures            = T.Tools and T.Tools.Textures

---@class NotificationPanelConfigurationOptions
local Options             = ConfigurationModule.Options.NotificationPanel
local MPTOptions          = ConfigurationModule.Options.MythicPlusTools
local DTOptions           = ConfigurationModule.Options.DungeonTracking
local BISOptions          = ConfigurationModule.Options.BestInSlot
local GatheringOptions    = ConfigurationModule.Options.Gathering

local Widgets             = ConfigurationModule.Widgets
local LibStub             = _G.LibStub

local function GetBISModule()
    ---@type BestInSlotModule
    return T:GetModule("BestInSlot")
end

local function GetSoundValues()
    return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {}
end

local function GetSoundValuesWithNone()
    local t = LibStub("LibSharedMedia-3.0"):HashTable("sound") or {}
    t["__none"] = "None"
    return t
end

local function BuildIconStyleLabel(style, text)
    local icon = Textures and Textures.GetPlayerClassTextureString and Textures:GetPlayerClassTextureString(14, style)
    if icon then
        return ("%s %s"):format(icon, text)
    end

    return text
end

local function BuildNotificationPanelConfiguration()
    local W = Widgets
    local optionsTab = W.NewConfigurationSection(4, "Notification Panel")

    optionsTab.args = {
        title = W.TitleWidget(0, "Notifications"),
        desc = W.Description(1, "Configure the notification panel and per-feature alerts."),

        -- ===== Tab: Display =====
        displayGroup = {
            type = "group",
            name = "Display",
            inline = false,
            order = 10,
            args = {
                title = W.TitleWidget(0, "Panel Display"),

                -- ── Dock mode ──────────────────────────────────────────────
                chatDockMode = {
                    type = "select",
                    name = "Chat Frame Dock",
                    desc =
                    "Attach the notification panel to the chat frame.\n\n|cffffcc00Top|r — Notifications grow upward from the top edge of the chat frame and match its width.\n\n|cffffcc00Right|r — Notifications grow upward from the bottom-right corner of the chat frame.",
                    order = 1,
                    values = {
                        none  = "None (manual position)",
                        top   = "Top of chat frame",
                        right = "Right of chat frame",
                    },
                    handler = Options,
                    get = "GetChatDockMode",
                    set = "SetChatDockMode",
                },

                -- ── Manual anchor controls (hidden when docked) ───────────
                anchorLockToggle = {
                    type = "execute",
                    name = function()
                        return Options:GetAnchorLocked() and "Unlock Anchor" or "Lock Anchor"
                    end,
                    desc = function()
                        return Options:GetAnchorLocked()
                            and "Show the draggable anchor handle so you can reposition the notification panel."
                            or "Hide the anchor handle and lock the notification panel in place."
                    end,
                    order = 2,
                    disabled = function() return Options:GetChatDockMode() ~= "none" end,
                    handler = Options,
                    func = function(self)
                        Options:SetAnchorLocked(nil, not Options:GetAnchorLocked())
                    end,
                },
                anchorX = {
                    type = "range",
                    name = "Position X",
                    desc =
                    "Horizontal offset of the notification anchor from the center of the screen. Positive moves right.",
                    order = 3,
                    softMin = -1200,
                    softMax = 1200,
                    step = 1,
                    disabled = function() return Options:GetChatDockMode() ~= "none" end,
                    handler = Options,
                    get = "GetAnchorX",
                    set = "SetAnchorX",
                },
                anchorY = {
                    type = "range",
                    name = "Position Y",
                    desc = "Vertical offset of the notification anchor from the center of the screen. Positive moves up.",
                    order = 4,
                    softMin = -600,
                    softMax = 600,
                    step = 1,
                    disabled = function() return Options:GetChatDockMode() ~= "none" end,
                    handler = Options,
                    get = "GetAnchorY",
                    set = "SetAnchorY",
                },

                -- ── Shared display controls ────────────────────────────────
                growthDirection = {
                    type = "select",
                    name = "Growth Direction",
                    desc =
                    "The direction new notifications appear from the anchor point. Forced upward when docked to the chat frame.",
                    order = 5,
                    values = { UP = "Upwards", DOWN = "Downwards" },
                    disabled = function() return Options:GetChatDockMode() ~= "none" end,
                    handler = Options,
                    get = "GetGrowthDirection",
                    set = "SetGrowthDirection",
                },
                panelWidth = {
                    type = "range",
                    name = "Notification Width",
                    desc =
                    "Width of each notification. Also applies when docked to the right of the chat frame. Ignored when docked to the top (width matches the chat frame).",
                    order = 6,
                    softMin = 200,
                    softMax = 600,
                    step = 1,
                    handler = Options,
                    get = "GetPanelWidth",
                    set = "SetPanelWidth",
                },
                notificationFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Font",
                    desc = "Font used across all notifications. Default preserves per-widget fonts.",
                    order = 7,
                    width = 2,
                    values = function()
                        local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                        local values = { __default = "Default" }
                        for k, v in pairs(fonts) do values[k] = v end
                        return values
                    end,
                    handler = Options,
                    get = "GetNotificationFont",
                    set = "SetNotificationFont",
                },
                notificationFontSizeAdjustment = {
                    type = "range",
                    name = "Font Size Adjustment",
                    desc =
                    "Shift notification text size up or down while keeping the style hierarchy. Zero preserves defaults.",
                    order = 8,
                    min = -4,
                    max = 8,
                    step = 1,
                    handler = Options,
                    get = "GetNotificationFontSizeAdjustment",
                    set = "SetNotificationFontSizeAdjustment",
                },
            },
        },

        -- ===== Tab: Friends =====
        friends = {
            type = "group",
            name = "Friends",
            inline = false,
            order = 20,
            args = {
                title = W.TitleWidget(0, "Friend Notifications"),
                enableFriendsNotifications = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Show notifications when friends come online or go offline.",
                    order = 1,
                    handler = Options,
                    get = "GetEnableFriendsNotifications",
                    set = "SetEnableFriendsNotifications",
                },
                useFriendNoteAsName = {
                    type = "toggle",
                    name = "Use Note as Name",
                    desc = "Use the friend's note as the name in notifications instead of their character name.",
                    order = 2,
                    disabled = function() return not Options:GetEnableFriendsNotifications() end,
                    handler = Options,
                    get = "GetUseFriendNoteAsName",
                    set = "SetUseFriendNoteAsName",
                },
                iconStyle = {
                    type = "select",
                    name = "Class Icon Style",
                    desc = "Choose the class icon set used in friend notifications.",
                    order = 3,
                    values = function()
                        return {
                            default = BuildIconStyleLabel("default", "Default"),
                            fabled  = BuildIconStyleLabel("fabled", "Fabled"),
                            pixel   = BuildIconStyleLabel("pixel", "Pixel"),
                        }
                    end,
                    disabled = function() return not Options:GetEnableFriendsNotifications() end,
                    handler = Options,
                    get = "GetFriendsNotificationIconStyle",
                    set = "SetFriendsNotificationIconStyle",
                },
                displayDuration = {
                    type = "range",
                    name = "Duration",
                    desc = "How long friend notifications remain visible.",
                    order = 4,
                    min = 2,
                    max = 30,
                    step = 1,
                    width = 1.5,
                    disabled = function() return not Options:GetEnableFriendsNotifications() end,
                    handler = Options,
                    get = "GetFriendsNotificationDisplayTime",
                    set = "SetFriendsNotificationDisplayTime",
                },
                sound = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "Sound",
                    desc = "Sound to play when a friend comes online or goes offline.",
                    order = 5,
                    width = 2,
                    values = GetSoundValues,
                    disabled = function() return not Options:GetEnableFriendsNotifications() end,
                    handler = Options,
                    get = "GetFriendsNotificationSound",
                    set = "SetFriendsNotificationSound",
                },
                testFriendsNotification = {
                    type = "execute",
                    name = "Test Notification",
                    desc = "Send a test friend notification using an online friend, or a fake one if none are available.",
                    order = 6,
                    disabled = function() return not Options:GetEnableFriendsNotifications() end,
                    handler = Options,
                    func = "TestFriendsNotification",
                },
            },
        },

        -- ===== Tab: Mythic+ =====
        mythicPlus = {
            type = "group",
            name = "Mythic+",
            inline = false,
            order = 30,
            args = {
                title = W.TitleWidget(0, "Mythic+ Notifications"),

                keystoneGroup = W.IGroup(10, "Keystone Received", {
                    desc = W.Description(0, "Notify when a Mythic Keystone lands in your bags."),
                    enableKeystoneNotifications = {
                        type = "toggle",
                        name = "Enable",
                        order = 1,
                        handler = Options,
                        get = "GetEnableKeystoneNotifications",
                        set = "SetEnableKeystoneNotifications",
                    },
                    keystoneDisplayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 2,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        disabled = function() return not Options:GetEnableKeystoneNotifications() end,
                        handler = Options,
                        get = "GetKeystoneNotificationDisplayTime",
                        set = "SetKeystoneNotificationDisplayTime",
                    },
                    keystoneSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        order = 3,
                        width = 2,
                        values = GetSoundValues,
                        disabled = function() return not Options:GetEnableKeystoneNotifications() end,
                        handler = Options,
                        get = "GetKeystoneNotificationSound",
                        set = "SetKeystoneNotificationSound",
                    },
                    testKeystoneNotification = {
                        type = "execute",
                        name = "Test Notification",
                        order = 4,
                        disabled = function() return not Options:GetEnableKeystoneNotifications() end,
                        handler = Options,
                        func = "TestKeystoneNotification",
                    },
                }),

                deathGroup = W.IGroup(20, "Death Alerts", {
                    desc = W.Description(0,
                        "Route party member deaths to notifications with role filtering and wipe suppression."),
                    enable = {
                        type = "toggle",
                        name = "Enable",
                        order = 1,
                        width = 1.5,
                        handler = MPTOptions,
                        get = "GetDeathNotificationEnabled",
                        set = "SetDeathNotificationEnabled",
                    },
                    displayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 2,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        handler = MPTOptions,
                        get = "GetDeathNotificationDisplayTime",
                        set = "SetDeathNotificationDisplayTime",
                    },
                    sound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        desc = "Sound to play when a tracked party member dies.",
                        order = 3,
                        width = 2,
                        values = GetSoundValuesWithNone,
                        handler = MPTOptions,
                        get = "GetDeathNotificationSound",
                        set = "SetDeathNotificationSound",
                    },
                    tank = {
                        type = "toggle",
                        name = "Tank",
                        order = 4,
                        width = 1.25,
                        handler = MPTOptions,
                        get = "GetNotifyForTankDeaths",
                        set = "SetNotifyForTankDeaths",
                    },
                    healer = {
                        type = "toggle",
                        name = "Healer",
                        order = 5,
                        width = 1.25,
                        handler = MPTOptions,
                        get = "GetNotifyForHealerDeaths",
                        set = "SetNotifyForHealerDeaths",
                    },
                    dps = {
                        type = "toggle",
                        name = "DPS",
                        order = 6,
                        width = 1.25,
                        handler = MPTOptions,
                        get = "GetNotifyForDPSDeaths",
                        set = "SetNotifyForDPSDeaths",
                    },
                    self = {
                        type = "toggle",
                        name = "Self",
                        order = 7,
                        width = 1.25,
                        handler = MPTOptions,
                        get = "GetNotifyForSelfDeaths",
                        set = "SetNotifyForSelfDeaths",
                    },
                    wipeSpam = {
                        type = "toggle",
                        name = "Suppress Wipe Spam",
                        desc = "Reduce repeated death alerts during near-full wipes while still tracking the total.",
                        order = 8,
                        width = 1.75,
                        handler = MPTOptions,
                        get = "GetSuppressWipeSpam",
                        set = "SetSuppressWipeSpam",
                    },
                    test = {
                        type = "execute",
                        name = "Test Notification",
                        desc = "Play a sample Mythic+ death notification.",
                        order = 9,
                        handler = MPTOptions,
                        func = "TestDeathNotification",
                    },
                }),

                timerGroup = W.IGroup(30, "Timer Events", {
                    desc = W.Description(0, "Notify when upgrade windows expire or enemy forces reach completion."),
                    plusThree = {
                        type = "toggle",
                        name = "+3 Timer Ends",
                        order = 1,
                        width = 1.5,
                        handler = MPTOptions,
                        get = "GetMythicPlusTimerNotifyPlusThreeExpired",
                        set = "SetMythicPlusTimerNotifyPlusThreeExpired",
                    },
                    plusTwo = {
                        type = "toggle",
                        name = "+2 Timer Ends",
                        order = 2,
                        width = 1.5,
                        handler = MPTOptions,
                        get = "GetMythicPlusTimerNotifyPlusTwoExpired",
                        set = "SetMythicPlusTimerNotifyPlusTwoExpired",
                    },
                    plusOne = {
                        type = "toggle",
                        name = "+1 Timer Ends",
                        order = 3,
                        width = 1.5,
                        handler = MPTOptions,
                        get = "GetMythicPlusTimerNotifyPlusOneExpired",
                        set = "SetMythicPlusTimerNotifyPlusOneExpired",
                    },
                    forces = {
                        type = "toggle",
                        name = "Forces Complete",
                        order = 4,
                        width = 1.5,
                        handler = MPTOptions,
                        get = "GetMythicPlusTimerNotifyForcesComplete",
                        set = "SetMythicPlusTimerNotifyForcesComplete",
                    },
                    displayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 5,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        handler = MPTOptions,
                        get = "GetMythicPlusTimerNotificationDisplayTime",
                        set = "SetMythicPlusTimerNotificationDisplayTime",
                    },
                    sound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        desc = "Sound to play when a timer notification fires. Set to None to disable.",
                        order = 6,
                        width = 2,
                        values = GetSoundValuesWithNone,
                        handler = MPTOptions,
                        get = "GetMythicPlusTimerNotificationSound",
                        set = "SetMythicPlusTimerNotificationSound",
                    },
                    testPlusThree = {
                        type = "execute",
                        name = "Test +3",
                        order = 7,
                        handler = MPTOptions,
                        func = function() MPTOptions:TestMythicPlusTimerNotification("plusThree") end,
                    },
                    testPlusTwo = {
                        type = "execute",
                        name = "Test +2",
                        order = 8,
                        handler = MPTOptions,
                        func = function() MPTOptions:TestMythicPlusTimerNotification("plusTwo") end,
                    },
                    testPlusOne = {
                        type = "execute",
                        name = "Test +1",
                        order = 9,
                        handler = MPTOptions,
                        func = function() MPTOptions:TestMythicPlusTimerNotification("plusOne") end,
                    },
                    testForces = {
                        type = "execute",
                        name = "Test Forces",
                        order = 10,
                        handler = MPTOptions,
                        func = function() MPTOptions:TestMythicPlusTimerNotification("forces") end,
                    },
                }),
            },
        },

        -- ===== Tab: Dungeon Tracking =====
        dungeonTracking = {
            type = "group",
            name = "Dungeon Tracking",
            inline = false,
            order = 35,
            args = {
                title = W.TitleWidget(0, "Dungeon Tracking Notifications"),
                desc = W.Description(1,
                    "Monitor dungeon runs, track how long they take, and notify you when they finish or end early."),

                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable dungeon run tracking.",
                    order = 2,
                    handler = DTOptions,
                    get = "GetEnabled",
                    set = "SetEnabled",
                },

                notificationGroup = W.IGroup(10, "Notification", {
                    displayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc = "How long dungeon tracking notifications remain visible before dismissing automatically.",
                        order = 1,
                        min = 2,
                        max = 60,
                        step = 1,
                        width = 1.5,
                        handler = DTOptions,
                        get = "GetNotificationDisplayTime",
                        set = "SetNotificationDisplayTime",
                    },
                    sound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Notification Sound",
                        desc = "Sound to play when a dungeon run ends.",
                        order = 2,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        handler = DTOptions,
                        get = "GetSound",
                        set = "SetSound",
                    },
                    iconStyle = {
                        type = "select",
                        name = "Class Icon Style",
                        desc = "Choose the class icon style used for dungeon group makeup in notifications.",
                        order = 3,
                        values = function()
                            return {
                                default = BuildIconStyleLabel("default", "Default Icons"),
                                fabled  = BuildIconStyleLabel("fabled", "Fabled Icons"),
                                pixel   = BuildIconStyleLabel("pixel", "Pixel Icons"),
                            }
                        end,
                        handler = DTOptions,
                        get = "GetClassIconStyle",
                        set = "SetClassIconStyle",
                    },
                    testGroup = W.IGroup(4, "Tests", {
                        test = {
                            type = "execute",
                            name = "Test Notification",
                            desc = "Play a test dungeon tracking notification.",
                            order = 1,
                            handler = DTOptions,
                            func = "TestNotification",
                        },
                        testMythic = {
                            type = "execute",
                            name = "Test Mythic+ Notification",
                            desc = "Play a test Mythic+ dungeon tracking notification with score and upgrade details.",
                            order = 2,
                            handler = DTOptions,
                            func = "TestMythicNotification",
                        },
                    }),
                }),

                leaveGroupButton = W.IGroup(20, "Leave Group Button", {
                    showButton = {
                        type = "toggle",
                        name = "Show Leave Group Button",
                        desc = "Show a Leave Group button on the dungeon completion notification.",
                        order = 1,
                        width = 1.75,
                        handler = DTOptions,
                        get = "GetShowLeaveGroupButton",
                        set = "SetShowLeaveGroupButton",
                    },
                    leavePhrase = {
                        type = "input",
                        name = "Instance Chat Phrase",
                        desc = "If set, this text is sent to instance chat before leaving the group.",
                        order = 2,
                        width = "full",
                        handler = DTOptions,
                        get = "GetLeavePhrase",
                        set = "SetLeavePhrase",
                    },
                }),
            },
        },

        -- ===== Tab: Scheduled Events =====
        scheduled = {
            type = "group",
            name = "Scheduled",
            inline = false,
            order = 40,
            args = {
                title = W.TitleWidget(0, "Scheduled Event Notifications"),

                greatVault = W.IGroup(10, "Great Vault", {
                    enableGreatVaultNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Notify when Great Vault rewards become available.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableGreatVaultNotifications",
                        set = "SetEnableGreatVaultNotifications",
                    },
                    greatVaultDisplayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 2,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        disabled = function() return not Options:GetEnableGreatVaultNotifications() end,
                        handler = Options,
                        get = "GetGreatVaultNotificationDisplayTime",
                        set = "SetGreatVaultNotificationDisplayTime",
                    },
                    greatVaultSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        order = 3,
                        width = 2,
                        values = GetSoundValues,
                        disabled = function() return not Options:GetEnableGreatVaultNotifications() end,
                        handler = Options,
                        get = "GetGreatVaultNotificationSound",
                        set = "SetGreatVaultNotificationSound",
                    },
                    testGreatVaultNotification = {
                        type = "execute",
                        name = "Test Notification",
                        order = 4,
                        disabled = function() return not Options:GetEnableGreatVaultNotifications() end,
                        handler = Options,
                        func = "TestGreatVaultNotification",
                    },
                }),

                dailyReset = W.IGroup(20, "Daily Reset", {
                    enableDailyResetNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Notify when the daily reset occurs while you are online.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableDailyResetNotifications",
                        set = "SetEnableDailyResetNotifications",
                    },
                    dailyResetDisplayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 2,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        disabled = function() return not Options:GetEnableDailyResetNotifications() end,
                        handler = Options,
                        get = "GetDailyResetNotificationDisplayTime",
                        set = "SetDailyResetNotificationDisplayTime",
                    },
                    dailyResetSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        order = 3,
                        width = 2,
                        values = GetSoundValues,
                        disabled = function() return not Options:GetEnableDailyResetNotifications() end,
                        handler = Options,
                        get = "GetDailyResetNotificationSound",
                        set = "SetDailyResetNotificationSound",
                    },
                    testDailyResetNotification = {
                        type = "execute",
                        name = "Test Notification",
                        order = 4,
                        disabled = function() return not Options:GetEnableDailyResetNotifications() end,
                        handler = Options,
                        func = "TestDailyResetNotification",
                    },
                }),

                chores = W.IGroup(30, "Chores", {
                    enableChoresNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Notify when tracked chores become available or are completed.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableChoresNotifications",
                        set = "SetEnableChoresNotifications",
                    },
                    choresDisplayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 2,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        disabled = function() return not Options:GetEnableChoresNotifications() end,
                        handler = Options,
                        get = "GetChoresNotificationDisplayTime",
                        set = "SetChoresNotificationDisplayTime",
                    },
                    choresSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        order = 3,
                        width = 2,
                        values = GetSoundValues,
                        disabled = function() return not Options:GetEnableChoresNotifications() end,
                        handler = Options,
                        get = "GetChoresNotificationSound",
                        set = "SetChoresNotificationSound",
                    },
                    testChoresNotification = {
                        type = "execute",
                        name = "Test Notification",
                        order = 4,
                        disabled = function() return not Options:GetEnableChoresNotifications() end,
                        handler = Options,
                        func = "TestChoresNotification",
                    },
                }),
            },
        },

        -- ===== Tab: Content =====
        content = {
            type = "group",
            name = "Content",
            inline = false,
            order = 50,
            args = {
                title = W.TitleWidget(0, "Content Notifications"),

                groupFinder = W.IGroup(10, "Group Finder", {
                    enableGroupFinderNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Notify when you join a premade group from the Group Finder.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableGroupFinderNotifications",
                        set = "SetEnableGroupFinderNotifications",
                    },
                    groupFinderDisplayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 2,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        disabled = function() return not Options:GetEnableGroupFinderNotifications() end,
                        handler = Options,
                        get = "GetGroupFinderNotificationDisplayTime",
                        set = "SetGroupFinderNotificationDisplayTime",
                    },
                    groupFinderSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        order = 3,
                        width = 2,
                        values = GetSoundValues,
                        disabled = function() return not Options:GetEnableGroupFinderNotifications() end,
                        handler = Options,
                        get = "GetGroupFinderNotificationSound",
                        set = "SetGroupFinderNotificationSound",
                    },
                    testGroupFinderNotification = {
                        type = "execute",
                        name = "Test Notification",
                        order = 4,
                        disabled = function() return not Options:GetEnableGroupFinderNotifications() end,
                        handler = Options,
                        func = "TestGroupFinderNotification",
                    },
                    testGroupFinderManaforgeNotification = {
                        type = "execute",
                        name = "Test Manaforge Omega",
                        desc =
                        "Test a Group Finder notification with a Manaforge Omega entry to verify the teleport button.",
                        order = 5,
                        disabled = function() return not Options:GetEnableGroupFinderNotifications() end,
                        handler = Options,
                        func = "TestGroupFinderManaforgeNotification",
                    },
                }),

                prey = W.IGroup(20, "Prey", {
                    enablePreyNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Notify when a prey hunt becomes active and ready.",
                        order = 1,
                        handler = Options,
                        get = "GetEnablePreyNotifications",
                        set = "SetEnablePreyNotifications",
                    },
                    preyDisplayDuration = {
                        type = "range",
                        name = "Duration",
                        order = 2,
                        min = 2,
                        max = 30,
                        step = 1,
                        width = 1.5,
                        disabled = function() return not Options:GetEnablePreyNotifications() end,
                        handler = Options,
                        get = "GetPreyNotificationDisplayTime",
                        set = "SetPreyNotificationDisplayTime",
                    },
                    preySound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Sound",
                        order = 3,
                        width = 2,
                        values = GetSoundValues,
                        disabled = function() return not Options:GetEnablePreyNotifications() end,
                        handler = Options,
                        get = "GetPreyNotificationSound",
                        set = "SetPreyNotificationSound",
                    },
                    testPreyNotification = {
                        type = "execute",
                        name = "Test Notification",
                        desc = "Send a test Prey ready notification with a waypoint button.",
                        order = 4,
                        disabled = function() return not Options:GetEnablePreyNotifications() end,
                        handler = Options,
                        func = "TestPreyNotification",
                    },
                }),
            },
        },

        -- ===== Tab: Gathering =====
        gathering = {
            type = "group",
            name = "Gathering",
            inline = false,
            order = 60,
            args = {
                title = W.TitleWidget(0, "Gathering Notifications"),
                desc = W.Description(1, "Notifications when items are gathered during an active session."),

                duration = {
                    type = "range",
                    name = "Duration",
                    desc = "How long a gathering notification stays on screen.",
                    order = 2,
                    min = 2,
                    max = 30,
                    step = 1,
                    width = 1.5,
                    handler = GatheringOptions,
                    get = "GetNotificationDuration",
                    set = "SetNotificationDuration",
                },
                sound = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "Sound",
                    desc = "Sound played when a gathering notification appears. Set to None to disable.",
                    order = 3,
                    width = 2,
                    values = GetSoundValuesWithNone,
                    handler = GatheringOptions,
                    get = "GetNotificationSound",
                    set = "SetNotificationSound",
                },
                highValueThreshold = {
                    type = "input",
                    name = "High Value Threshold (Gold)",
                    desc =
                    "Send a high-value notification when a single loot batch meets or exceeds this total. Set to 0 to disable.",
                    order = 4,
                    width = 1.5,
                    handler = GatheringOptions,
                    get = "GetHighValueThresholdGold",
                    set = "SetHighValueThresholdGold",
                },
                highValueSound = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "High Value Sound",
                    desc = "Optional separate sound for high-value notifications. Set to None to reuse the normal sound.",
                    order = 5,
                    width = 2,
                    values = GetSoundValuesWithNone,
                    handler = GatheringOptions,
                    get = "GetHighValueSound",
                    set = "SetHighValueSound",
                },
            },
        },

        -- ===== Tab: Best In Slot =====
        bestInSlot = {
            type = "group",
            name = "Best In Slot",
            inline = false,
            order = 70,
            args = {
                title = W.TitleWidget(0, "Best In Slot Notifications"),
                desc = W.Description(1, "Notify when tracked best in slot items are received or appear."),

                testNotification = {
                    type = "execute",
                    name = "Test Notification",
                    desc = "Send a test notification for the Best In Slot system.",
                    width = 2,
                    order = 2,
                    func = function()
                        local m = GetBISModule()
                        if m then m:GetModule("MonitorLootedItems"):CreateTest() end
                    end,
                },

                eventsGroup = W.IGroup(5, "Events", {
                    monitorReceivedItems = {
                        type = "toggle",
                        name = "Received Items",
                        desc = "Notify when you receive an item marked as best in slot.",
                        order = 1,
                        handler = BISOptions,
                        get = "GetMonitorReceivedItems",
                        set = "SetMonitorReceivedItems",
                    },
                    monitorDroppedItems = {
                        type = "toggle",
                        name = "Dropped Items",
                        desc = "Notify when a best in slot item drops from a boss.",
                        order = 2,
                        handler = BISOptions,
                        get = "GetMonitorDroppedItems",
                        set = "SetMonitorDroppedItems",
                    },
                    monitorGreatVaultItems = {
                        type = "toggle",
                        name = "Great Vault Items",
                        desc = "Notify when a best in slot item is available in the Great Vault.",
                        order = 3,
                        handler = BISOptions,
                        get = "GetMonitorGreatVaultItems",
                        set = "SetMonitorGreatVaultItems",
                    },
                }),

                settingsGroup = W.IGroup(10, "Settings", {
                    displayDuration = {
                        type = "range",
                        name = "Duration",
                        desc = "How long a Best In Slot notification remains visible.",
                        order = 1,
                        min = 2,
                        max = 60,
                        step = 1,
                        handler = BISOptions,
                        get = "GetNotificationDisplayTime",
                        set = "SetNotificationDisplayTime",
                    },
                }),

                soundsGroup = W.IGroup(15, "Sounds", {
                    enable = {
                        type = "toggle",
                        name = "Enable Sounds",
                        order = 1,
                        width = "full",
                        handler = BISOptions,
                        get = "IsSoundEnabled",
                        set = "SetSoundEnabled",
                    },
                    receivedItemSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Received Item",
                        order = 2,
                        width = 2,
                        values = GetSoundValues,
                        handler = BISOptions,
                        get = "GetAquiredSound",
                        set = "SetAquiredSound",
                    },
                    availableItemSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Available Item",
                        desc = "Sound for items available in the Great Vault or still lootable from a boss.",
                        order = 3,
                        width = 2,
                        values = GetSoundValues,
                        handler = BISOptions,
                        get = "GetAvailableSound",
                        set = "SetAvailableSound",
                    },
                }),
            },
        },
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Notification Panel", BuildNotificationPanelConfiguration)
