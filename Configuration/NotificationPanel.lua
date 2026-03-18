--[[
    Configuration for notification panel.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class NotificationPanelConfigurationOptions
local Options = ConfigurationModule.Options.NotificationPanel

local Widgets = ConfigurationModule.Widgets

local function BuildNotificationPanelConfiguration()
    local function GetModule()
        ---@type NotificationModule
        return T:GetModule("Notification")
    end

    local optionsTab = ConfigurationModule.Widgets.NewConfigurationSection(4, "Notification Panel")

    optionsTab.args = {
        title = ConfigurationModule.Widgets.TitleWidget(0, "Notification Panel"),
        desc = {
            type = "description",
            name =
            "Configure the notification panel settings.",
            order = 1,
        },
        displayGroup = {
            type = "group",
            name = "Display",
            inline = true,
            order = 10,
            args = {
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
                }
            },
        }
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Notification Panel", BuildNotificationPanelConfiguration)
