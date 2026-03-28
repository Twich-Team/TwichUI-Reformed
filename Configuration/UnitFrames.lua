---@diagnostic disable: undefined-field
--[[
    Configuration section for standalone Unit Frames.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class UnitFramesConfigurationOptions
local Options = ConfigurationModule.Options.UnitFrames

local Widgets = ConfigurationModule.Widgets

local SINGLE_UNITS = {
    { key = "player", label = "Player" },
    { key = "target", label = "Target" },
    { key = "targettarget", label = "Target of Target" },
    { key = "focus", label = "Focus" },
    { key = "pet", label = "Pet" },
}

local GROUP_UNITS = {
    { key = "party", label = "Party" },
    { key = "raid", label = "Raid" },
    { key = "tank", label = "Tank" },
}

local TEXT_SCOPES = {
    { key = "singles", label = "Singles" },
    { key = "party", label = "Party" },
    { key = "raid", label = "Raid" },
    { key = "tank", label = "Tank" },
    { key = "boss", label = "Boss" },
}

local function BuildColorPicker(order, key, name, description)
    return {
        type = "color",
        name = name,
        desc = description,
        order = order,
        hasAlpha = true,
        disabled = function() return not Options:GetEnabled() end,
        get = function()
            return Options:GetColor(key)
        end,
        set = function(_, r, g, b, a)
            Options:SetColor(key, r, g, b, a)
        end,
    }
end

local function BuildPositionGroup(order, layoutKey)
    return Widgets.IGroup(order, "Position", {
        point = {
            type = "select",
            name = "Anchor",
            order = 1,
            width = 1.25,
            values = {
                TOP = "TOP",
                TOPLEFT = "TOPLEFT",
                TOPRIGHT = "TOPRIGHT",
                LEFT = "LEFT",
                RIGHT = "RIGHT",
                CENTER = "CENTER",
                BOTTOM = "BOTTOM",
                BOTTOMLEFT = "BOTTOMLEFT",
                BOTTOMRIGHT = "BOTTOMRIGHT",
            },
            disabled = function() return not Options:GetEnabled() or Options:GetLockFrames() end,
            get = function()
                return Options:GetLayoutSetting(layoutKey, "point") or "CENTER"
            end,
            set = function(_, value)
                Options:SetLayoutSetting(layoutKey, "point", value)
            end,
        },
        relativePoint = {
            type = "select",
            name = "Relative To",
            order = 2,
            width = 1.25,
            values = {
                TOP = "TOP",
                TOPLEFT = "TOPLEFT",
                TOPRIGHT = "TOPRIGHT",
                LEFT = "LEFT",
                RIGHT = "RIGHT",
                CENTER = "CENTER",
                BOTTOM = "BOTTOM",
                BOTTOMLEFT = "BOTTOMLEFT",
                BOTTOMRIGHT = "BOTTOMRIGHT",
            },
            disabled = function() return not Options:GetEnabled() or Options:GetLockFrames() end,
            get = function()
                return Options:GetLayoutSetting(layoutKey, "relativePoint") or "CENTER"
            end,
            set = function(_, value)
                Options:SetLayoutSetting(layoutKey, "relativePoint", value)
            end,
        },
        x = {
            type = "range",
            name = "X Offset",
            order = 3,
            min = -2500,
            max = 2500,
            step = 1,
            width = 1.3,
            disabled = function() return not Options:GetEnabled() or Options:GetLockFrames() end,
            get = function()
                return tonumber(Options:GetLayoutSetting(layoutKey, "x") or 0)
            end,
            set = function(_, value)
                Options:SetLayoutSetting(layoutKey, "x", math.floor((value or 0) + 0.5))
            end,
        },
        y = {
            type = "range",
            name = "Y Offset",
            order = 4,
            min = -2500,
            max = 2500,
            step = 1,
            width = 1.3,
            disabled = function() return not Options:GetEnabled() or Options:GetLockFrames() end,
            get = function()
                return tonumber(Options:GetLayoutSetting(layoutKey, "y") or 0)
            end,
            set = function(_, value)
                Options:SetLayoutSetting(layoutKey, "y", math.floor((value or 0) + 0.5))
            end,
        },
    })
end

local function BuildSingleUnitGroup(order, unitKey, unitLabel)
    return {
        type = "group",
        name = unitLabel,
        order = order,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable",
                order = 1,
                width = 1,
                disabled = function() return not Options:GetEnabled() end,
                get = function()
                    return Options:GetUnitSetting(unitKey, "enabled") ~= false
                end,
                set = function(_, value)
                    Options:SetUnitSetting(unitKey, "enabled", value == true)
                end,
            },
            width = {
                type = "range",
                name = "Width",
                order = 2,
                min = 80,
                max = 600,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetUnitSetting(unitKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetUnitSetting(unitKey, "width") or 220)
                end,
                set = function(_, value)
                    Options:SetUnitSetting(unitKey, "width", math.floor((value or 220) + 0.5))
                end,
            },
            height = {
                type = "range",
                name = "Height",
                order = 3,
                min = 16,
                max = 180,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetUnitSetting(unitKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetUnitSetting(unitKey, "height") or 40)
                end,
                set = function(_, value)
                    Options:SetUnitSetting(unitKey, "height", math.floor((value or 40) + 0.5))
                end,
            },
            powerHeight = {
                type = "range",
                name = "Power Bar Height",
                order = 4,
                min = 0,
                max = 32,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetUnitSetting(unitKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetUnitSetting(unitKey, "powerHeight") or 10)
                end,
                set = function(_, value)
                    Options:SetUnitSetting(unitKey, "powerHeight", math.floor((value or 10) + 0.5))
                end,
            },
            showPower = {
                type = "toggle",
                name = "Show Power Bar",
                order = 5,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetUnitSetting(unitKey, "enabled") == false
                end,
                get = function()
                    return Options:GetUnitSetting(unitKey, "showPower") ~= false
                end,
                set = function(_, value)
                    Options:SetUnitSetting(unitKey, "showPower", value == true)
                end,
            },
            position = BuildPositionGroup(20, unitKey),
        },
    }
end

local function BuildGroupUnitGroup(order, groupKey, label)
    return {
        type = "group",
        name = label,
        order = order,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable",
                order = 1,
                width = 1,
                disabled = function() return not Options:GetEnabled() end,
                get = function()
                    return Options:GetGroupSetting(groupKey, "enabled") ~= false
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "enabled", value == true)
                end,
            },
            width = {
                type = "range",
                name = "Frame Width",
                order = 2,
                min = 70,
                max = 400,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetGroupSetting(groupKey, "width") or 180)
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "width", math.floor((value or 180) + 0.5))
                end,
            },
            height = {
                type = "range",
                name = "Frame Height",
                order = 3,
                min = 14,
                max = 120,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetGroupSetting(groupKey, "height") or 34)
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "height", math.floor((value or 34) + 0.5))
                end,
            },
            yOffset = {
                type = "range",
                name = "Row Spacing",
                order = 4,
                min = -40,
                max = 40,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetGroupSetting(groupKey, "yOffset") or -6)
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "yOffset", math.floor((value or -6) + 0.5))
                end,
            },
            unitsPerColumn = {
                type = "range",
                name = "Units Per Column",
                order = 5,
                min = 1,
                max = 40,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetGroupSetting(groupKey, "unitsPerColumn") or 5)
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "unitsPerColumn", math.floor((value or 5) + 0.5))
                end,
            },
            maxColumns = {
                type = "range",
                name = "Max Columns",
                order = 6,
                min = 1,
                max = 8,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetGroupSetting(groupKey, "maxColumns") or 1)
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "maxColumns", math.floor((value or 1) + 0.5))
                end,
            },
            columnSpacing = {
                type = "range",
                name = "Column Spacing",
                order = 7,
                min = -10,
                max = 50,
                step = 1,
                width = 1.25,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return tonumber(Options:GetGroupSetting(groupKey, "columnSpacing") or 8)
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "columnSpacing", math.floor((value or 8) + 0.5))
                end,
            },
            showPlayer = {
                type = "toggle",
                name = "Include Player",
                order = 8,
                width = 1.25,
                hidden = function() return groupKey ~= "party" end,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return Options:GetGroupSetting(groupKey, "showPlayer") == true
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "showPlayer", value == true)
                end,
            },
            showSolo = {
                type = "toggle",
                name = "Show In Solo",
                order = 9,
                width = 1.25,
                hidden = function() return groupKey == "raid" end,
                disabled = function()
                    return not Options:GetEnabled() or Options:GetGroupSetting(groupKey, "enabled") == false
                end,
                get = function()
                    return Options:GetGroupSetting(groupKey, "showSolo") == true
                end,
                set = function(_, value)
                    Options:SetGroupSetting(groupKey, "showSolo", value == true)
                end,
            },
            position = BuildPositionGroup(20, groupKey),
        },
    }
end

local function BuildTextScopeGroup(order, scopeKey, scopeLabel)
    return {
        type = "group",
        name = scopeLabel,
        order = order,
        args = {
            nameFontSize = {
                type = "range", name = "Name Font Size", order = 1, min = 6, max = 28, step = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() end,
                get = function() return tonumber(Options:GetTextSetting(scopeKey, "nameFontSize") or 11) end,
                set = function(_, value) Options:SetTextSetting(scopeKey, "nameFontSize", math.floor((value or 11) + 0.5)) end,
            },
            healthFontSize = {
                type = "range", name = "Health Font Size", order = 2, min = 6, max = 28, step = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() end,
                get = function() return tonumber(Options:GetTextSetting(scopeKey, "healthFontSize") or 10) end,
                set = function(_, value) Options:SetTextSetting(scopeKey, "healthFontSize", math.floor((value or 10) + 0.5)) end,
            },
            powerFontSize = {
                type = "range", name = "Power Font Size", order = 3, min = 6, max = 28, step = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() end,
                get = function() return tonumber(Options:GetTextSetting(scopeKey, "powerFontSize") or 9) end,
                set = function(_, value) Options:SetTextSetting(scopeKey, "powerFontSize", math.floor((value or 9) + 0.5)) end,
            },
            nameFormat = {
                type = "select", name = "Name Format", order = 4, width = 1.2,
                values = { full = "Full Name", short = "Short Name" },
                disabled = function() return not Options:GetEnabled() end,
                get = function() return Options:GetTextSetting(scopeKey, "nameFormat") or "full" end,
                set = function(_, value) Options:SetTextSetting(scopeKey, "nameFormat", value) end,
            },
            healthFormat = {
                type = "select", name = "Health Text Format", order = 5, width = 1.4,
                values = { percent = "Percent", current = "Current", currentPercent = "Current + Percent", missing = "Missing" },
                disabled = function() return not Options:GetEnabled() or not Options:GetShowHealthText() end,
                get = function() return Options:GetTextSetting(scopeKey, "healthFormat") or "percent" end,
                set = function(_, value) Options:SetTextSetting(scopeKey, "healthFormat", value) end,
            },
            powerFormat = {
                type = "select", name = "Power Text Format", order = 6, width = 1.4,
                values = { percent = "Percent", current = "Current", currentPercent = "Current + Percent", missing = "Missing" },
                disabled = function() return not Options:GetEnabled() or not Options:GetShowPowerText() end,
                get = function() return Options:GetTextSetting(scopeKey, "powerFormat") or "percent" end,
                set = function(_, value) Options:SetTextSetting(scopeKey, "powerFormat", value) end,
            },
        },
    }
end

local function BuildAuraScopeGroup(order, scopeKey, scopeLabel)
    return {
        type = "group",
        name = scopeLabel,
        order = order,
        args = {
            enabled = {
                type = "toggle", name = "Enable Auras", order = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() end,
                get = function() return Options:GetAuraSetting(scopeKey, "enabled") ~= false end,
                set = function(_, value) Options:SetAuraSetting(scopeKey, "enabled", value == true) end,
            },
            maxIcons = {
                type = "range", name = "Max Icons", order = 2, min = 1, max = 16, step = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() or Options:GetAuraSetting(scopeKey, "enabled") == false end,
                get = function() return tonumber(Options:GetAuraSetting(scopeKey, "maxIcons") or 8) end,
                set = function(_, value) Options:SetAuraSetting(scopeKey, "maxIcons", math.floor((value or 8) + 0.5)) end,
            },
            iconSize = {
                type = "range", name = "Icon Size", order = 3, min = 10, max = 40, step = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() or Options:GetAuraSetting(scopeKey, "enabled") == false end,
                get = function() return tonumber(Options:GetAuraSetting(scopeKey, "iconSize") or 18) end,
                set = function(_, value) Options:SetAuraSetting(scopeKey, "iconSize", math.floor((value or 18) + 0.5)) end,
            },
            spacing = {
                type = "range", name = "Spacing", order = 4, min = 0, max = 8, step = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() or Options:GetAuraSetting(scopeKey, "enabled") == false end,
                get = function() return tonumber(Options:GetAuraSetting(scopeKey, "spacing") or 2) end,
                set = function(_, value) Options:SetAuraSetting(scopeKey, "spacing", math.floor((value or 2) + 0.5)) end,
            },
            yOffset = {
                type = "range", name = "Y Offset", order = 5, min = -20, max = 30, step = 1, width = 1.2,
                disabled = function() return not Options:GetEnabled() or Options:GetAuraSetting(scopeKey, "enabled") == false end,
                get = function() return tonumber(Options:GetAuraSetting(scopeKey, "yOffset") or 6) end,
                set = function(_, value) Options:SetAuraSetting(scopeKey, "yOffset", math.floor((value or 6) + 0.5)) end,
            },
        },
    }
end

local function BuildHealthColorScopeGroup(order, scopeKey, scopeLabel)
    return {
        type = "group",
        name = scopeLabel,
        order = order,
        args = {
            mode = {
                type = "select", name = "Health Color Mode", order = 1, width = 1.4,
                values = { theme = "Theme", class = "Class", custom = "Custom" },
                disabled = function() return not Options:GetEnabled() end,
                get = function() return Options:GetHealthColorMode(scopeKey) end,
                set = function(_, value) Options:SetHealthColorMode(scopeKey, value) end,
            },
            custom = {
                type = "color", name = "Custom Health Color", order = 2, hasAlpha = true,
                disabled = function() return not Options:GetEnabled() or Options:GetHealthColorMode(scopeKey) ~= "custom" end,
                get = function() return Options:GetHealthColor(scopeKey) end,
                set = function(_, r, g, b, a) Options:SetHealthColor(scopeKey, r, g, b, a) end,
            },
        },
    }
end

local function BuildConfiguration()
    local section = Widgets.NewConfigurationSection(7, "Unit Frames")

    section.args = {
        title = Widgets.TitleWidget(0, "Unit Frames"),
        desc = Widgets.Description(1,
            "Standalone oUF-based unit frames for player, target, group, boss, and castbar. Lock/unlock frames to position them directly in the world."),
        enable = {
            type = "toggle",
            name = "Enable Unit Frames",
            order = 2,
            width = 1.5,
            handler = Options,
            get = "GetEnabled",
            set = "SetEnabled",
        },
        lockFrames = {
            type = "toggle",
            name = "Lock Frame Positions",
            order = 3,
            width = 1.5,
            disabled = function() return not Options:GetEnabled() end,
            handler = Options,
            get = "GetLockFrames",
            set = "SetLockFrames",
        },
        testMode = {
            type = "toggle",
            name = "Test Mode",
            desc = "Displays mock values/preview groups for layout work.",
            order = 4,
            width = 1.5,
            disabled = function() return not Options:GetEnabled() end,
            handler = Options,
            get = "GetTestMode",
            set = "SetTestMode",
        },
        generalGroup = Widgets.IGroup(10, "General", {
            scale = {
                type = "range",
                name = "Global Scale",
                order = 1,
                min = 0.6,
                max = 1.6,
                step = 0.01,
                width = 1.3,
                disabled = function() return not Options:GetEnabled() end,
                handler = Options,
                get = "GetScale",
                set = "SetScale",
            },
            alpha = {
                type = "range",
                name = "Global Alpha",
                order = 2,
                min = 0.15,
                max = 1,
                step = 0.01,
                width = 1.3,
                disabled = function() return not Options:GetEnabled() end,
                handler = Options,
                get = "GetFrameAlpha",
                set = "SetFrameAlpha",
            },
            useClassColor = {
                type = "toggle",
                name = "Use Class Color For Health",
                order = 3,
                width = 1.4,
                disabled = function() return not Options:GetEnabled() end,
                handler = Options,
                get = "GetUseClassColor",
                set = "SetUseClassColor",
            },
            showHealthText = {
                type = "toggle",
                name = "Show Health Text",
                order = 4,
                width = 1.25,
                disabled = function() return not Options:GetEnabled() end,
                handler = Options,
                get = "GetShowHealthText",
                set = "SetShowHealthText",
            },
            showPowerText = {
                type = "toggle",
                name = "Show Power Text",
                order = 5,
                width = 1.25,
                disabled = function() return not Options:GetEnabled() end,
                handler = Options,
                get = "GetShowPowerText",
                set = "SetShowPowerText",
            },
            smoothBars = {
                type = "toggle",
                name = "Smooth Bars",
                order = 6,
                width = 1.25,
                disabled = function() return not Options:GetEnabled() end,
                handler = Options,
                get = "GetSmoothBars",
                set = "SetSmoothBars",
            },
        }),
        text = {
            type = "group",
            name = "Text",
            order = 11,
            childGroups = "tab",
            args = {},
        },
        colors = Widgets.IGroup(12, "Colors", {
            health = BuildColorPicker(1, "health", "Health", "Health bar color."),
            power = BuildColorPicker(2, "power", "Power", "Power bar color."),
            cast = BuildColorPicker(3, "cast", "Castbar", "Castbar color."),
            background = BuildColorPicker(4, "background", "Background", "Background color."),
            border = BuildColorPicker(5, "border", "Border", "Border color."),
        }),
        healthColors = {
            type = "group",
            name = "Health Colors",
            order = 13,
            childGroups = "tab",
            args = {},
        },
        auras = {
            type = "group",
            name = "Auras",
            order = 14,
            childGroups = "tab",
            args = {},
        },
        singles = {
            type = "group",
            name = "Single Units",
            order = 20,
            childGroups = "tab",
            args = {},
        },
        groups = {
            type = "group",
            name = "Group Units",
            order = 30,
            childGroups = "tab",
            args = {},
        },
        castbar = {
            type = "group",
            name = "Castbar",
            order = 40,
            args = {
                enabled = {
                    type = "toggle",
                    name = "Enable",
                    order = 1,
                    width = 1,
                    disabled = function() return not Options:GetEnabled() end,
                    get = function()
                        return Options:GetCastbarSetting("enabled") ~= false
                    end,
                    set = function(_, value)
                        Options:SetCastbarSetting("enabled", value == true)
                    end,
                },
                width = {
                    type = "range",
                    name = "Width",
                    order = 2,
                    min = 120,
                    max = 600,
                    step = 1,
                    width = 1.25,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false end,
                    get = function()
                        return tonumber(Options:GetCastbarSetting("width") or 260)
                    end,
                    set = function(_, value)
                        Options:SetCastbarSetting("width", math.floor((value or 260) + 0.5))
                    end,
                },
                height = {
                    type = "range",
                    name = "Height",
                    order = 3,
                    min = 10,
                    max = 60,
                    step = 1,
                    width = 1.25,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false end,
                    get = function()
                        return tonumber(Options:GetCastbarSetting("height") or 20)
                    end,
                    set = function(_, value)
                        Options:SetCastbarSetting("height", math.floor((value or 20) + 0.5))
                    end,
                },
                showIcon = {
                    type = "toggle",
                    name = "Show Icon",
                    order = 4,
                    width = 1.1,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false end,
                    get = function() return Options:GetCastbarSetting("showIcon") ~= false end,
                    set = function(_, value) Options:SetCastbarSetting("showIcon", value == true) end,
                },
                showSpellText = {
                    type = "toggle",
                    name = "Show Spell Text",
                    order = 5,
                    width = 1.2,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false end,
                    get = function() return Options:GetCastbarSetting("showSpellText") ~= false end,
                    set = function(_, value) Options:SetCastbarSetting("showSpellText", value == true) end,
                },
                showTimeText = {
                    type = "toggle",
                    name = "Show Time Text",
                    order = 6,
                    width = 1.2,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false end,
                    get = function() return Options:GetCastbarSetting("showTimeText") ~= false end,
                    set = function(_, value) Options:SetCastbarSetting("showTimeText", value == true) end,
                },
                iconSize = {
                    type = "range",
                    name = "Icon Size",
                    order = 7,
                    min = 12,
                    max = 50,
                    step = 1,
                    width = 1.2,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false or Options:GetCastbarSetting("showIcon") == false end,
                    get = function() return tonumber(Options:GetCastbarSetting("iconSize") or 20) end,
                    set = function(_, value) Options:SetCastbarSetting("iconSize", math.floor((value or 20) + 0.5)) end,
                },
                spellFontSize = {
                    type = "range",
                    name = "Spell Font Size",
                    order = 8,
                    min = 6,
                    max = 24,
                    step = 1,
                    width = 1.2,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false or Options:GetCastbarSetting("showSpellText") == false end,
                    get = function() return tonumber(Options:GetCastbarSetting("spellFontSize") or 11) end,
                    set = function(_, value) Options:SetCastbarSetting("spellFontSize", math.floor((value or 11) + 0.5)) end,
                },
                timeFontSize = {
                    type = "range",
                    name = "Time Font Size",
                    order = 9,
                    min = 6,
                    max = 24,
                    step = 1,
                    width = 1.2,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false or Options:GetCastbarSetting("showTimeText") == false end,
                    get = function() return tonumber(Options:GetCastbarSetting("timeFontSize") or 10) end,
                    set = function(_, value) Options:SetCastbarSetting("timeFontSize", math.floor((value or 10) + 0.5)) end,
                },
                useCustomColor = {
                    type = "toggle",
                    name = "Use Custom Cast Color",
                    order = 10,
                    width = 1.3,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false end,
                    get = function() return Options:GetCastbarSetting("useCustomColor") == true end,
                    set = function(_, value) Options:SetCastbarSetting("useCustomColor", value == true) end,
                },
                castColor = {
                    type = "color",
                    name = "Cast Color",
                    order = 11,
                    hasAlpha = true,
                    disabled = function() return not Options:GetEnabled() or Options:GetCastbarSetting("enabled") == false or Options:GetCastbarSetting("useCustomColor") ~= true end,
                    get = function() return Options:GetCastbarColor() end,
                    set = function(_, r, g, b, a) Options:SetCastbarColor(r, g, b, a) end,
                },
                position = BuildPositionGroup(10, "castbar"),
            },
        },
    }

    for index, item in ipairs(SINGLE_UNITS) do
        section.args.singles.args[item.key] = BuildSingleUnitGroup(index, item.key, item.label)
    end

    for index, scope in ipairs(TEXT_SCOPES) do
        section.args.text.args[scope.key] = BuildTextScopeGroup(index, scope.key, scope.label)
        section.args.auras.args[scope.key] = BuildAuraScopeGroup(index, scope.key, scope.label)
        section.args.healthColors.args[scope.key] = BuildHealthColorScopeGroup(index, scope.key, scope.label)
    end

    for index, item in ipairs(GROUP_UNITS) do
        section.args.groups.args[item.key] = BuildGroupUnitGroup(index, item.key, item.label)
    end

    section.args.groups.args.boss = {
        type = "group",
        name = "Boss",
        order = 10,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable",
                order = 1,
                width = 1,
                disabled = function() return not Options:GetEnabled() end,
                get = function()
                    return Options:GetGroupSetting("boss", "enabled") ~= false
                end,
                set = function(_, value)
                    Options:SetGroupSetting("boss", "enabled", value == true)
                end,
            },
            width = {
                type = "range",
                name = "Width",
                order = 2,
                min = 120,
                max = 500,
                step = 1,
                width = 1.25,
                disabled = function() return not Options:GetEnabled() or Options:GetGroupSetting("boss", "enabled") == false end,
                get = function()
                    return tonumber(Options:GetUnitSetting("boss", "width") or 220)
                end,
                set = function(_, value)
                    Options:SetUnitSetting("boss", "width", math.floor((value or 220) + 0.5))
                end,
            },
            height = {
                type = "range",
                name = "Height",
                order = 3,
                min = 16,
                max = 120,
                step = 1,
                width = 1.25,
                disabled = function() return not Options:GetEnabled() or Options:GetGroupSetting("boss", "enabled") == false end,
                get = function()
                    return tonumber(Options:GetUnitSetting("boss", "height") or 36)
                end,
                set = function(_, value)
                    Options:SetUnitSetting("boss", "height", math.floor((value or 36) + 0.5))
                end,
            },
            yOffset = {
                type = "range",
                name = "Row Spacing",
                order = 4,
                min = -40,
                max = 40,
                step = 1,
                width = 1.25,
                disabled = function() return not Options:GetEnabled() or Options:GetGroupSetting("boss", "enabled") == false end,
                get = function()
                    return tonumber(Options:GetGroupSetting("boss", "yOffset") or -8)
                end,
                set = function(_, value)
                    Options:SetGroupSetting("boss", "yOffset", math.floor((value or -8) + 0.5))
                end,
            },
            position = BuildPositionGroup(10, "boss"),
        },
    }

    return section
end

ConfigurationModule:RegisterConfigurationFunction("unitFrames", BuildConfiguration)
