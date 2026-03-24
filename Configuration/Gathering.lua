--[[
    Configuration UI for the Gathering module.
    Registers a tab within the Quality of Life configuration section.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@type GatheringConfigurationOptions
local GatheringOptions = ConfigurationModule.Options.Gathering

local function BuildGatheringTab()
    local W = ConfigurationModule.Widgets

    return {
        type  = "group",
        name  = "Gathering",
        order = 12,
        args  = {
            title = W.TitleWidget(0, "Gathering"),
            desc  = W.Description(1,
                "Farm HUD radar, item loot session tracking, TSM-powered item pricing, and loot notifications."),

            enable = {
                type    = "toggle",
                name    = "Enable",
                desc    = "Enable the Gathering module.",
                order   = 2,
                handler = GatheringOptions,
                get     = "GetEnabled",
                set     = "SetEnabled",
            },

            -- ===== HUD / Radar =====
            hudGroup = W.IGroup(10, "Farm HUD Radar", {
                desc = W.Description(1,
                    "Moves the minimap to the center of the screen and enlarges it for farming. Toggling the HUD also starts or pauses your gathering session."),

                hudSize = {
                    type  = "range",
                    name  = "HUD Minimap Size",
                    desc  = "Pixel size for the minimap when the HUD is active.",
                    order = 2,
                    min   = 200,
                    max   = 700,
                    step  = 10,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetHudSize",
                    set   = "SetHudSize",
                },

                ringColor = {
                    type     = "color",
                    name     = "Ring Color",
                    desc     = "Color of the decorative ring around the minimap in HUD mode.",
                    order    = 3,
                    hasAlpha = true,
                    width    = 1.25,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler  = GatheringOptions,
                    get      = "GetHudRingColor",
                    set      = "SetHudRingColor",
                },

                ringWidth = {
                    type  = "range",
                    name  = "Ring Width",
                    desc  = "Pixel width of the decorative ring.",
                    order = 4,
                    min   = 1,
                    max   = 12,
                    step  = 1,
                    width = 1.25,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetHudRingWidth",
                    set   = "SetHudRingWidth",
                },

                terrainTransparent = {
                    type  = "toggle",
                    name  = "Transparent Terrain",
                    desc  = "Reduce minimap terrain opacity while HUD is active.",
                    order = 5,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetHudTerrainTransparent",
                    set   = "SetHudTerrainTransparent",
                },

                terrainAlpha = {
                    type  = "range",
                    name  = "Terrain Alpha",
                    desc  = "How transparent the minimap terrain is when HUD is active (0 = fully transparent, 1 = fully opaque). Low values will let the ring color show through the minimap center.",
                    order = 6,
                    min   = 0.0,
                    max   = 1.0,
                    step  = 0.05,
                    isPercent = true,
                    width = 1.5,
                    disabled = function()
                        return not GatheringOptions:GetEnabled() or not GatheringOptions:GetHudTerrainTransparent()
                    end,
                    handler = GatheringOptions,
                    get   = "GetHudTerrainAlpha",
                    set   = "SetHudTerrainAlpha",
                },
            }),

            -- ===== Notifications =====
            notificationGroup = W.IGroup(20, "Loot Notifications", {
                desc = W.Description(1,
                    "Notifications are sent through the TwichUI notification panel when items are gathered during an active session."),

                duration = {
                    type  = "range",
                    name  = "Display Duration",
                    desc  = "Seconds a gathering notification stays on screen.",
                    order = 2,
                    min   = 2,
                    max   = 30,
                    step  = 1,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetNotificationDuration",
                    set   = "SetNotificationDuration",
                },

                sound = {
                    type          = "select",
                    dialogControl = "LSM30_Sound",
                    name          = "Notification Sound",
                    desc          = "Sound played when a gathering notification appears. Set to None to disable.",
                    order         = 3,
                    width         = 2,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    values = function()
                        local LSM = T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)
                        local t = LSM and LSM:HashTable("sound") or {}
                        t["__none"] = "None"
                        return t
                    end,
                    handler = GatheringOptions,
                    get     = "GetNotificationSound",
                    set     = "SetNotificationSound",
                },

                highValueThreshold = {
                    type  = "input",
                    name  = "High Value Threshold (Gold)",
                    desc  = "Send a high value gather notification when a single loot batch meets or exceeds this total value. Set to 0 to disable.",
                    order = 4,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetHighValueThresholdGold",
                    set   = "SetHighValueThresholdGold",
                },

                highValueSound = {
                    type          = "select",
                    dialogControl = "LSM30_Sound",
                    name          = "High Value Sound",
                    desc          = "Optional separate sound for high value gather notifications. Set to None to reuse the normal notification sound.",
                    order         = 5,
                    width         = 2,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    values = function()
                        local LSM = T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)
                        local t = LSM and LSM:HashTable("sound") or {}
                        t["__none"] = "None"
                        return t
                    end,
                    handler = GatheringOptions,
                    get     = "GetHighValueSound",
                    set     = "SetHighValueSound",
                },
            }),

            -- ===== TSM Pricing =====
            pricingGroup = W.IGroup(30, "Item Pricing (TSM)", {
                desc = W.Description(1,
                    "Requires TradeSkillMaster to be installed and loaded. Pricing is used in loot notifications and the session tracker."),

                priceSource = {
                    type   = "select",
                    name   = "Price Source",
                    desc   = "TSM price source used to value gathered items.",
                    order  = 2,
                    width  = 2,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    values   = function() return GatheringOptions:GetPriceSources() end,
                    handler  = GatheringOptions,
                    get      = "GetPriceSource",
                    set      = "SetPriceSource",
                },
            }),

            -- ===== Datatext =====
            datatextGroup = W.IGroup(40, "Datatext", {
                desc = W.Description(1,
                    "Controls for the Gathering datatext panel bar. Add it via ElvUI's DataText configuration."),

                datatextEnabled = {
                    type  = "toggle",
                    name  = "Enable Datatext",
                    desc  = "Show the Gathering datatext in ElvUI data bar panels.",
                    order = 2,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetDatatextEnabled",
                    set   = "SetDatatextEnabled",
                },

                showGPH = {
                    type  = "toggle",
                    name  = "Show Gold/Hour",
                    desc  = "Show current session gold-per-hour on the datatext label.",
                    order = 3,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetShowGPH",
                    set   = "SetShowGPH",
                },

                showSessionStatus = {
                    type  = "toggle",
                    name  = "Show Session Status",
                    desc  = "Show session active/paused status on the datatext label.",
                    order = 4,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetShowSessionStatus",
                    set   = "SetShowSessionStatus",
                },

                gphUpdateInterval = {
                    type  = "range",
                    name  = "GPH Recalculate Interval",
                    desc  = "How often gold-per-hour is recalculated while a session is active. Loot events still trigger an immediate recalculation.",
                    order = 5,
                    min   = 1,
                    max   = 30,
                    step  = 1,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetGPHUpdateInterval",
                    set   = "SetGPHUpdateInterval",
                },
            }),

            trackerGroup = W.IGroup(50, "Gathered Items Frame", {
                desc = W.Description(1,
                    "Appearance and behavior for the gathered items session frame."),

                trackerLocked = {
                    type  = "toggle",
                    name  = "Lock Frame",
                    desc  = "Prevent the gathered items frame from being dragged.",
                    order = 2,
                    width = 1.25,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetTrackerLocked",
                    set   = "SetTrackerLocked",
                },

                trackerReset = {
                    type  = "execute",
                    name  = "Reset Frame Position",
                    desc  = "Reset the gathered items frame position and size.",
                    order = 3,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    func  = "ResetTrackerPosition",
                },

                trackerFont = {
                    type          = "select",
                    dialogControl = "LSM30_Font",
                    name          = "Frame Font",
                    desc          = "Font used by the gathered items frame.",
                    order         = 4,
                    width         = 2,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("font") or {} end,
                    handler = GatheringOptions,
                    get     = "GetTrackerFont",
                    set     = "SetTrackerFont",
                },

                trackerFontSize = {
                    type  = "range",
                    name  = "Font Size",
                    desc  = "Font size used by the gathered items frame.",
                    order = 5,
                    min   = 10,
                    max   = 20,
                    step  = 1,
                    width = 1.25,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetTrackerFontSize",
                    set   = "SetTrackerFontSize",
                },

                trackerFontOutline = {
                    type  = "select",
                    name  = "Font Outline",
                    desc  = "Outline style for the gathered items frame text.",
                    order = 6,
                    width = 1.25,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    values = {
                        [""] = "None",
                        ["OUTLINE"] = "Outline",
                        ["THICKOUTLINE"] = "Thick Outline",
                        ["MONOCHROME"] = "Monochrome",
                    },
                    handler = GatheringOptions,
                    get   = "GetTrackerFontOutline",
                    set   = "SetTrackerFontOutline",
                },

                trackerBackgroundAlpha = {
                    type  = "range",
                    name  = "Frame Transparency",
                    desc  = "Transparency for the gathered items frame background.",
                    order = 7,
                    min   = 0.20,
                    max   = 1.0,
                    step  = 0.05,
                    isPercent = true,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetTrackerBackgroundAlpha",
                    set   = "SetTrackerBackgroundAlpha",
                },

                trackerAccentColor = {
                    type     = "color",
                    name     = "Accent Color",
                    desc     = "Accent color used by the gathered items frame header.",
                    order    = 8,
                    hasAlpha = true,
                    width    = 1.25,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler  = GatheringOptions,
                    get      = "GetTrackerAccentColor",
                    set      = "SetTrackerAccentColor",
                },

                trackerItemColumnWidth = {
                    type  = "range",
                    name  = "Item Column Width",
                    desc  = "Width of the item name column in the gathered items frame.",
                    order = 9,
                    min   = 120,
                    max   = 320,
                    step  = 5,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetTrackerItemColumnWidth",
                    set   = "SetTrackerItemColumnWidth",
                },

                trackerQtyColumnWidth = {
                    type  = "range",
                    name  = "Quantity Column Width",
                    desc  = "Width of the quantity column in the gathered items frame.",
                    order = 10,
                    min   = 40,
                    max   = 120,
                    step  = 5,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetTrackerQtyColumnWidth",
                    set   = "SetTrackerQtyColumnWidth",
                },

                trackerItemValueColumnWidth = {
                    type  = "range",
                    name  = "Item Value Column Width",
                    desc  = "Width of the per-item value column in the gathered items frame.",
                    order = 11,
                    min   = 60,
                    max   = 160,
                    step  = 5,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetTrackerItemValueColumnWidth",
                    set   = "SetTrackerItemValueColumnWidth",
                },

                trackerTotalValueColumnWidth = {
                    type  = "range",
                    name  = "Total Value Column Width",
                    desc  = "Width of the total value column in the gathered items frame.",
                    order = 12,
                    min   = 70,
                    max   = 180,
                    step  = 5,
                    width = 1.5,
                    disabled = function() return not GatheringOptions:GetEnabled() end,
                    handler = GatheringOptions,
                    get   = "GetTrackerTotalValueColumnWidth",
                    set   = "SetTrackerTotalValueColumnWidth",
                },
            }),
        },
    }
end

-- Export so QualityOfLife.lua can include it
ConfigurationModule.BuildGatheringTab = BuildGatheringTab
