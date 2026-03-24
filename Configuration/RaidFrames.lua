--[[
    Configuration for raid frame enhancements.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class RaidFramesConfigurationOptions
local Options = ConfigurationModule.Options.RaidFrames

local Widgets = ConfigurationModule.Widgets

local function BuildRaidFramesConfiguration()
    local optionsTab = Widgets.NewConfigurationSection(6, "UnitFrame Tweaks")

    optionsTab.args = {
        title = Widgets.TitleWidget(0, "UnitFrame Tweaks"),
        desc = Widgets.Description(1,
            "Feature tweaks for ElvUI party and raid frames. Each subtab is intended to behave like its own tweak module inside the UnitFrame Tweaks category."),
        enable = {
            type = "toggle",
            name = "Enable",
            desc = "Enable the UnitFrame Tweaks category.",
            order = 2,
            handler = Options,
            get = "GetEnabled",
            set = "SetEnabled",
        },
        dispellableDebuffsTab = {
            type = "group",
            name = "Dispellable Debuffs Highlight",
            order = 10,
            args = {
                title = Widgets.TitleWidget(0, "Dispellable Debuffs Highlight"),
                desc = Widgets.Description(1,
                    "Highlight ElvUI party and raid frames when that unit has a debuff your current character can dispel."),
                glowSettings = Widgets.IGroup(10, "Glow", {
                    enable = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Enable the dispellable debuff highlight on ElvUI party and raid frames.",
                        order = 1,
                        width = 1.25,
                        disabled = function() return not Options:GetEnabled() end,
                        handler = Options,
                        get = "GetDispellableDebuffsHighlightEnabled",
                        set = "SetDispellableDebuffsHighlightEnabled",
                    },
                    glowColor = {
                        type = "color",
                        name = "Glow Color",
                        desc = "Color used for the dispellable debuff glow.",
                        order = 2,
                        hasAlpha = true,
                        width = 1.5,
                        disabled = function()
                            return not Options:GetEnabled() or not Options:GetDispellableDebuffsHighlightEnabled()
                        end,
                        handler = Options,
                        get = "GetGlowColor",
                        set = "SetGlowColor",
                    },
                    glowStyle = {
                        type = "select",
                        name = "Glow Style",
                        desc = "Choose between the current custom glow and a Blizzard-style button proc glow.",
                        order = 3,
                        width = 1.4,
                        values = {
                            classic = "Classic",
                            button = "Button Glow",
                        },
                        disabled = function()
                            return not Options:GetEnabled() or not Options:GetDispellableDebuffsHighlightEnabled()
                        end,
                        handler = Options,
                        get = "GetGlowStyle",
                        set = "SetGlowStyle",
                    },
                    sparkColor = {
                        type = "color",
                        name = "Spark Color",
                        desc = "Color used for the moving classic glow sparks.",
                        order = 4,
                        hasAlpha = true,
                        width = 1.5,
                        disabled = function()
                            return not Options:GetEnabled()
                                or not Options:GetDispellableDebuffsHighlightEnabled()
                                or Options:GetGlowStyle() ~= "classic"
                        end,
                        handler = Options,
                        get = "GetSparkColor",
                        set = "SetSparkColor",
                    },
                    sparkCount = {
                        type = "range",
                        name = "Spark Count",
                        desc = "Number of moving sparks shown around the classic glow border.",
                        order = 5,
                        min = 1,
                        max = 6,
                        step = 1,
                        width = 1.25,
                        disabled = function()
                            return not Options:GetEnabled()
                                or not Options:GetDispellableDebuffsHighlightEnabled()
                                or Options:GetGlowStyle() ~= "classic"
                        end,
                        handler = Options,
                        get = "GetSparkCount",
                        set = "SetSparkCount",
                    },
                    sparkWidth = {
                        type = "range",
                        name = "Spark Width",
                        desc = "Length of each moving classic glow spark.",
                        order = 6,
                        min = 4,
                        max = 32,
                        step = 1,
                        width = 1.25,
                        disabled = function()
                            return not Options:GetEnabled()
                                or not Options:GetDispellableDebuffsHighlightEnabled()
                                or Options:GetGlowStyle() ~= "classic"
                        end,
                        handler = Options,
                        get = "GetSparkWidth",
                        set = "SetSparkWidth",
                    },
                    sparkHeight = {
                        type = "range",
                        name = "Spark Height",
                        desc = "Thickness of each moving classic glow spark.",
                        order = 7,
                        min = 1,
                        max = 8,
                        step = 1,
                        width = 1.25,
                        disabled = function()
                            return not Options:GetEnabled()
                                or not Options:GetDispellableDebuffsHighlightEnabled()
                                or Options:GetGlowStyle() ~= "classic"
                        end,
                        handler = Options,
                        get = "GetSparkHeight",
                        set = "SetSparkHeight",
                    },
                    testGlow = {
                        type = "execute",
                        name = "Test Glow",
                        desc = "Show the glow on visible party and raid frames for a few seconds.",
                        order = 8,
                        width = 1.25,
                        disabled = function()
                            return not Options:GetEnabled() or not Options:GetDispellableDebuffsHighlightEnabled()
                        end,
                        handler = Options,
                        func = "TestGlow",
                    },
                }),
            },
        },
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("raidFrames", BuildRaidFramesConfiguration)
