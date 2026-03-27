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
