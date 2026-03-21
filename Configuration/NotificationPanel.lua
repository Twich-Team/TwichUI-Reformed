--[[
    Configuration for notification panel.
]]
local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
---@type TexturesTool
local Textures = T.Tools and T.Tools.Textures

---@class NotificationPanelConfigurationOptions
local Options = ConfigurationModule.Options.NotificationPanel

local Widgets = ConfigurationModule.Widgets

local function BuildIconStyleLabel(style, text)
    local icon = Textures and Textures.GetPlayerClassTextureString and Textures:GetPlayerClassTextureString(14, style)
    if icon then
        return ("%s %s"):format(icon, text)
    end

    return text
end

local function BuildNotificationPanelConfiguration()
    local optionsTab = ConfigurationModule.Widgets.NewConfigurationSection(4, "Notifications")

    optionsTab.args = {
        title = ConfigurationModule.Widgets.TitleWidget(0, "Notifications"),
        desc = {
            type = "description",
            name =
            "Configure notifications from TwichUI.",
            order = 1,
        },
        displayGroup = {
            type = "group",
            name = "Display Panel",
            inline = false,
            order = 10,
            args = {
                title = ConfigurationModule.Widgets.TitleWidget(0, "Display Panel"),

                anchorInfo = {
                    type = "description",
                    name = "Use the ElvUI mover labeled 'TwichUI Notifications' to reposition the notification panel.",
                    order = 1,
                },
                growthDirection = {
                    type = "select",
                    name = "Growth Direction",
                    desc = "The direction new notifications will appear from the anchor point.",
                    order = 2,
                    values = {
                        UP = "Upwards",
                        DOWN = "Downwards",
                    },
                    handler = Options,
                    get = "GetGrowthDirection",
                    set = "SetGrowthDirection",
                },
                panelWidth = {
                    type = "range",
                    name = "Notification Width",
                    softMin = 200,
                    softMax = 600,
                    handler = Options,
                    get = "GetPanelWidth",
                    set = "SetPanelWidth",
                    step = 1,
                },
                notificationFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Notification Font",
                    desc = "Font used across TwichUI notifications. Default preserves the current widget fonts.",
                    order = 4,
                    width = 2,
                    values = function()
                        local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                        local values = {
                            __default = "Default",
                        }

                        for key, value in pairs(fonts) do
                            values[key] = value
                        end

                        return values
                    end,
                    handler = Options,
                    get = "GetNotificationFont",
                    set = "SetNotificationFont",
                },
                notificationFontSizeAdjustment = {
                    type = "range",
                    name = "Font Size",
                    desc =
                    "Adjust notification text size while keeping the current style hierarchy. Zero preserves the current sizes.",
                    order = 5,
                    min = -4,
                    max = 8,
                    step = 1,
                    handler = Options,
                    get = "GetNotificationFontSizeAdjustment",
                    set = "SetNotificationFontSizeAdjustment",
                }
            },
        },
        additionalNotificationsGroup = {
            type = "group",
            name = "Additional Notifications",
            inline = false,
            order = 20,
            args = {
                title = ConfigurationModule.Widgets.TitleWidget(0, "Addditional Notifications"),
                desc = ConfigurationModule.Widgets.Description(1,
                    "Configure additional notifications provided by TwichUI modules."),
                friends = ConfigurationModule.Widgets.IGroup(5, "Friends", {
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
                        desc = "Choose whether friend notifications use Default, Fabled, or Pixel class icons.",
                        order = 3,
                        values = function()
                            return {
                                default = BuildIconStyleLabel("default", "Default Icons"),
                                fabled = BuildIconStyleLabel("fabled", "Fabled Icons"),
                                pixel = BuildIconStyleLabel("pixel", "Pixel Icons"),
                            }
                        end,
                        disabled = function() return not Options:GetEnableFriendsNotifications() end,
                        handler = Options,
                        get = "GetFriendsNotificationIconStyle",
                        set = "SetFriendsNotificationIconStyle",
                    },
                    displayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc = "How long friend notifications remain visible before dismissing automatically.",
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
                        name = "Notification Sound",
                        desc = "Sound to play when a friend comes online or goes offline.",
                        order = 5,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        disabled = function() return not Options:GetEnableFriendsNotifications() end,
                        handler = Options,
                        get = "GetFriendsNotificationSound",
                        set = "SetFriendsNotificationSound",
                    },
                    testFriendsNotification = {
                        type = "execute",
                        name = "Test Notification",
                        desc =
                        "Send a test friend notification using an online friend, or a fake friend when none are online.",
                        order = 6,
                        disabled = function() return not Options:GetEnableFriendsNotifications() end,
                        handler = Options,
                        func = "TestFriendsNotification",
                    }
                }),
                mythicPlus = ConfigurationModule.Widgets.IGroup(10, "Mythic+", {
                    enableKeystoneNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Show notifications when a Mythic Keystone is received in your bags.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableKeystoneNotifications",
                        set = "SetEnableKeystoneNotifications",
                    },
                    keystoneDisplayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc = "How long Mythic Keystone notifications remain visible before dismissing automatically.",
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
                        name = "Notification Sound",
                        desc = "Sound to play when a Mythic Keystone is received.",
                        order = 3,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        disabled = function() return not Options:GetEnableKeystoneNotifications() end,
                        handler = Options,
                        get = "GetKeystoneNotificationSound",
                        set = "SetKeystoneNotificationSound",
                    },
                    testKeystoneNotification = {
                        type = "execute",
                        name = "Test Notification",
                        desc =
                        "Send a test Mythic Keystone notification using the keystone in your bags, or a fake one if you do not have one.",
                        order = 4,
                        disabled = function() return not Options:GetEnableKeystoneNotifications() end,
                        handler = Options,
                        func = "TestKeystoneNotification",
                    },
                }),
                greatVault = ConfigurationModule.Widgets.IGroup(15, "Great Vault", {
                    enableGreatVaultNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Show notifications when Great Vault rewards become available or are available on login.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableGreatVaultNotifications",
                        set = "SetEnableGreatVaultNotifications",
                    },
                    greatVaultDisplayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc =
                        "How long Great Vault availability notifications remain visible before dismissing automatically.",
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
                        name = "Notification Sound",
                        desc = "Sound to play when Great Vault rewards are available.",
                        order = 3,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        disabled = function() return not Options:GetEnableGreatVaultNotifications() end,
                        handler = Options,
                        get = "GetGreatVaultNotificationSound",
                        set = "SetGreatVaultNotificationSound",
                    },
                    testGreatVaultNotification = {
                        type = "execute",
                        name = "Test Notification",
                        desc = "Send a test Great Vault notification.",
                        order = 4,
                        disabled = function() return not Options:GetEnableGreatVaultNotifications() end,
                        handler = Options,
                        func = "TestGreatVaultNotification",
                    },
                }),
                dailyReset = ConfigurationModule.Widgets.IGroup(20, "Daily Reset", {
                    enableDailyResetNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Show notifications when the daily reset occurs while you are online.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableDailyResetNotifications",
                        set = "SetEnableDailyResetNotifications",
                    },
                    dailyResetDisplayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc = "How long daily reset notifications remain visible before dismissing automatically.",
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
                        name = "Notification Sound",
                        desc = "Sound to play when the daily reset occurs.",
                        order = 3,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        disabled = function() return not Options:GetEnableDailyResetNotifications() end,
                        handler = Options,
                        get = "GetDailyResetNotificationSound",
                        set = "SetDailyResetNotificationSound",
                    },
                    testDailyResetNotification = {
                        type = "execute",
                        name = "Test Notification",
                        desc = "Send a test daily reset notification.",
                        order = 4,
                        disabled = function() return not Options:GetEnableDailyResetNotifications() end,
                        handler = Options,
                        func = "TestDailyResetNotification",
                    },
                }),
                groupFinder = ConfigurationModule.Widgets.IGroup(25, "Group Finder", {
                    enableGroupFinderNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Show notifications when you join a premade group from the Group Finder.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableGroupFinderNotifications",
                        set = "SetEnableGroupFinderNotifications",
                    },
                    groupFinderDisplayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc =
                        "How long Group Finder acceptance notifications remain visible before dismissing automatically.",
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
                        name = "Notification Sound",
                        desc = "Sound to play when you join a Group Finder listing.",
                        order = 3,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        disabled = function() return not Options:GetEnableGroupFinderNotifications() end,
                        handler = Options,
                        get = "GetGroupFinderNotificationSound",
                        set = "SetGroupFinderNotificationSound",
                    },
                    testGroupFinderNotification = {
                        type = "execute",
                        name = "Test Notification",
                        desc = "Send a test Group Finder acceptance notification.",
                        order = 4,
                        disabled = function() return not Options:GetEnableGroupFinderNotifications() end,
                        handler = Options,
                        func = "TestGroupFinderNotification",
                    },
                })

                ,
                chores = ConfigurationModule.Widgets.IGroup(30, "Chores", {
                    enableChoresNotifications = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Show grouped notifications when tracked chores become available or are completed.",
                        order = 1,
                        handler = Options,
                        get = "GetEnableChoresNotifications",
                        set = "SetEnableChoresNotifications",
                    },
                    choresDisplayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc = "How long Chores notifications remain visible before dismissing automatically.",
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
                        name = "Notification Sound",
                        desc = "Sound to play when tracked chores become available or are completed.",
                        order = 3,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        disabled = function() return not Options:GetEnableChoresNotifications() end,
                        handler = Options,
                        get = "GetChoresNotificationSound",
                        set = "SetChoresNotificationSound",
                    },
                    testChoresNotification = {
                        type = "execute",
                        name = "Test Notification",
                        desc = "Send a test Chores notification.",
                        order = 4,
                        disabled = function() return not Options:GetEnableChoresNotifications() end,
                        handler = Options,
                        func = "TestChoresNotification",
                    },
                })

            },
        },
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Notification Panel", BuildNotificationPanelConfiguration)
