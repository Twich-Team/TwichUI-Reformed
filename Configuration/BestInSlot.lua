--[[
    Configuration for best in slot.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class BestInSlotConfigurationOptions
local Options = ConfigurationModule.Options.BestInSlot

local Widgets = ConfigurationModule.Widgets

local function BuildBestInSlotConfiguration()
    local optionsTab = ConfigurationModule.Widgets.NewConfigurationSection(3, "Best In Slot")

    local function GetModule()
        ---@type BestInSlotModule
        return T:GetModule("BestInSlot")
    end

    optionsTab.args = {
        title = ConfigurationModule.Widgets.TitleWidget(0, "Best In Slot"),
        desc = {
            type = "description",
            name =
            "Provides tracking for your best in slot items.",
            order = 1,
        },
        enable = {
            type = "toggle",
            name = "Enable",
            desc = "Enable or disable the Best In Slot module.",
            order = 2,
            handler = Options,
            get = "IsBestInSlotModuleEnabled",
            set = "SetBestInSlotModuleEnabled",
        },
        notifications = {
            type = "group",
            name = "Notifications",
            order = 5,
            childGroups = "tree",
            args = {
                title = Widgets.TitleWidget(0, "Notifications"),
                desc = {
                    type = "description",
                    name =
                    "Configure notifications for when best in slot items are received or available.",
                    order = 1,
                },
                testNotification = {
                    type = "execute",
                    name = "Create Test Notification",
                    desc = "Sends a test notification to demonstrate the best in slot notification system.",
                    width = 2,
                    order = 2,
                    func = function()
                        GetModule():GetModule("MonitorLootedItems"):CreateTest()
                    end,
                },
                openBisWindow = {
                    type = "execute",
                    name = "Open Best In Slot",
                    desc = "Open the Best In Slot window to configure your best in slot items.",
                    width = 2,
                    order = 3,
                    func = function()
                        GetModule().Frame:Show()
                    end,
                },
                help = Widgets.IGroup(4, "Help", {
                    desc1 = Widgets.Description(1,
                        "To configure your best in slot items, open the Best In Slot window with the /bis command or by clicking the button above. The item level of the item displayed in the Best In Slot window does not effect when notifications are displayed. As Blizzard has implemented scaling and upgrade tracks, notifications are based on whether the item in question is an upgrade over your currently owned item, not whether it is a specific item level."),
                    desc2 = Widgets.Description(2,
                        "\nNotifications will only appear if the following conditions are met:\n\n  - The item is selected as best in slot.\n  - If the item is already owned, the new item must be a higher upgrade track than the currently owned item.\n  - You have enabled the relevant notification type in this configuration menu."),
                }),
                eventsGroup = Widgets.IGroup(5, "Notification Events", {
                    monitorReceivedItems = {
                        type = "toggle",
                        name = "Received Items",
                        desc = "Notify you when you receive an item that is marked as best in slot.",
                        order = 1,
                        handler = Options,
                        get = "GetMonitorReceivedItems",
                        set = "SetMonitorReceivedItems",
                    },
                    monitorDroppedItems = {
                        type = "toggle",
                        name = "Dropped Items",
                        desc = "Notify you when an item that is marked as best in slot drops from a boss.",
                        order = 2,
                        handler = Options,
                        get = "GetMonitorDroppedItems",
                        set = "SetMonitorDroppedItems",
                    },
                    monitorGreatVaultItems = {
                        type = "toggle",
                        name = "Great Vault Items",
                        desc = "Notify you when an item that is marked as best in slot is available in the Great Vault.",
                        order = 3,
                        handler = Options,
                        get = "GetMonitorGreatVaultItems",
                        set = "SetMonitorGreatVaultItems",
                    },
                }),
                notificationSettings = Widgets.IGroup(10, "Notification Settings", {
                    displayDuration = {
                        type = "range",
                        name = "Display Duration",
                        desc = "How long (in seconds) the best in slot notification should remain visible.",
                        order = 1,
                        min = 2,
                        max = 60,
                        step = 1,
                        handler = Options,
                        get = "GetNotificationDisplayTime",
                        set = "SetNotificationDisplayTime",
                    },
                }),
                soundsGroup = Widgets.IGroup(10, "Notification Sounds", {
                    enable = {
                        type = "toggle",
                        name = "Enable Sounds",
                        desc = "Enable or disable sounds for best in slot notifications.",
                        order = 1,
                        width = "full",
                        handler = Options,
                        get = "IsSoundEnabled",
                        set = "SetSoundEnabled",
                    },
                    receivedItemSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Received Item Sound",
                        desc = "Sound to play when you receive a best in slot item.",
                        order = 2,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        handler = Options,
                        get = "GetAquiredSound",
                        set = "SetAquiredSound",
                    },
                    availableItemSound = {
                        type = "select",
                        dialogControl = "LSM30_Sound",
                        name = "Available Item Sound",
                        desc =
                        "Sound to play when a best in slot item is available. (from Great Vault, dropped but being looted still, etc.)",
                        order = 3,
                        width = 2,
                        values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                        handler = Options,
                        get = "GetAvailableSound",
                        set = "SetAvailableSound",
                    },
                }),
            },
        },
        greatVaultTab = {
            type = "group",
            name = "Great Vault",
            order = 10,
            childGroups = "tree",
            args = {
                title = Widgets.TitleWidget(0, "Great Vault"),
                desc = Widgets.Description(1, "Configure Best In Slot enhancements for the Great Vault."),
                highlightGroup = Widgets.IGroup(2, "Highlighting", {
                    desc = Widgets.Description(0,
                        "Display a pulsing glow around any Best in Slot items in the Great Vault frame."),
                    enable = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Highlight best in slot items in the Great Vault interface.",
                        order = 1,
                        width = "full",
                        handler = Options,
                        get = "IsGreatVaultHighlightEnabled",
                        set = "SetGreatVaultHighlightEnabled",
                    },
                    highlightColor = {
                        type = "color",
                        name = "Highlight Color",
                        desc = "Color to use when highlighting best in slot items in the Great Vault.",
                        order = 2,
                        hasAlpha = true,
                        handler = Options,
                        get = "GetGreatVaultHighlightColor",
                        set = "SetGreatVaultHighlightColor",
                    },
                }),
            }
        },
        itemCacheTab = {
            type = "group",
            name = "Item Cache",
            order = 20,
            childGroups = "tree",
            args = {
                title = ConfigurationModule.Widgets.TitleWidget(0, "Item Cache"),
                desc = {
                    type = "description",
                    name =
                    "The item cache contains the rewards identified by scanning the Encounter Journal. It is updated when a new game version is released by Blizzard. You can force a refresh of the cache if you believe it is out of date or missing items. The addon is only able to find rewards that are provided by Blizzard in the Encounter Journal. Any other items will need to be manually added.",
                    order = 1,
                },
                space1 = Widgets.Spacer(2),
                refreshCache = {
                    type = "execute",
                    name = "Refresh Item Cache",
                    desc = "Force a refresh of the best in slot item cache.\n\n" ..
                        T.Tools.Text.Color(T.Tools.Colors.RED,
                            "NOTE: This may cause a brief performance loss while the Encounter Journal is scanned."),
                    order = 3,
                    func = function()
                        GetModule():ForceRefreshCache()
                    end,
                },
                space2 = Widgets.Spacer(4),

                versionGroup = Widgets.IGroup(5, "Version Information", {
                    cacheVersion = {
                        type = "description",
                        name = function()
                            local db = GetModule().GetCharacterBISDB()
                            local version = db.CacheGameVersion or "Unknown"
                            return "Cache Version: " ..
                                T.Tools.Text.Color(T.Tools.Colors.PRIMARY, version)
                        end,
                        order = 1,
                    },
                    gameVersion = {
                        type = "description",
                        name = function()
                            local gameVersion = select(1, GetBuildInfo())
                            return "Game Version: " .. T.Tools.Text.Color(T.Tools.Colors.PRIMARY, gameVersion)
                        end,
                        order = 2,
                    }
                }),
            }
        }
    }
    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Best In Slot", BuildBestInSlotConfiguration)
