---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local Widgets = ConfigurationModule.Widgets
local LibStub = _G.LibStub

---@class UnitFramesConfigurationOptions
local Options = ConfigurationModule.Options.UnitFrames or {}
ConfigurationModule.Options.UnitFrames = Options

local DEFAULT_SENTINEL = "__default"

local POINT_VALUES = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local OUTLINE_VALUES = {
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    MONOCHROME = "Monochrome",
    MONOCHROMEOUTLINE = "Monochrome Outline",
    MONOCHROMETHICKOUTLINE = "Monochrome Thick Outline",
    NONE = "None",
}

local NAME_FORMAT_VALUES = {
    full = "Full Name",
    short = "Short Name",
    custom = "Custom Tag",
}

local RESOURCE_FORMAT_VALUES = {
    percent = "Percent",
    current = "Current Value",
    currentPercent = "Current and Percent",
    missing = "Missing",
    custom = "Custom Tag",
}

local AURA_FILTER_VALUES = {
    ALL = "All",
    HELPFUL = "Helpful",
    HARMFUL = "Harmful",
    DISPELLABLE = "Dispellable",
    DISPELLABLE_OR_BOSS = "Dispellable or Boss",
}

local HEALTH_MODE_VALUES = {
    theme = "Theme",
    class = "Class",
    custom = "Custom",
}

local UNIT_HEALTH_MODE_VALUES = {
    inherit = "Inherit",
    theme = "Theme",
    class = "Class",
    custom = "Custom",
}

local GROUP_BY_VALUES = {
    GROUP = "Group",
    CLASS = "Class",
    ASSIGNEDROLE = "Assigned Role",
    ROLE = "Role",
}

local COLOR_DEFAULTS = {
    health = { 0.34, 0.84, 0.54, 1 },
    power = { 0.10, 0.72, 0.74, 1 },
    cast = { 0.96, 0.76, 0.24, 1 },
    background = { 0.05, 0.06, 0.08, 1 },
    border = { 0.24, 0.26, 0.32, 1 },
    targetHighlight = { 1.0, 0.82, 0.0, 0.9 },
    mouseoverHighlight = { 1.0, 1.0, 1.0, 0.08 },
    shadow = { 0, 0, 0, 0.85 },
    classBar = { 1, 1, 1, 1 },
    classBarBackground = { 0.05, 0.06, 0.08, 0.9 },
    classBarBorder = { 0.24, 0.26, 0.32, 0.9 },
}

local ROOT_TEXT_DEFAULTS = {
    nameFormat = "full",
    healthFormat = "percent",
    powerFormat = "percent",
    nameFontSize = 11,
    healthFontSize = 10,
    powerFontSize = 9,
    outlineMode = "OUTLINE",
    shadowEnabled = false,
    shadowOffsetX = 1,
    shadowOffsetY = -1,
    namePoint = "LEFT",
    nameRelativePoint = "LEFT",
    nameOffsetX = 4,
    nameOffsetY = 0,
    healthPoint = "RIGHT",
    healthRelativePoint = "RIGHT",
    healthOffsetX = -4,
    healthOffsetY = 0,
    powerPoint = "RIGHT",
    powerRelativePoint = "RIGHT",
    powerOffsetX = -4,
    powerOffsetY = 0,
}

local SINGLE_UNIT_DEFAULTS = {
    player = { width = 260, height = 48, showPower = true, powerHeight = 10, powerDetached = false, powerWidth = 260 },
    target = { width = 240, height = 42, showPower = true, powerHeight = 10, powerDetached = false, powerWidth = 240 },
    targettarget = { width = 180, height = 30, showPower = true, powerHeight = 8, powerDetached = false, powerWidth = 180 },
    focus = { width = 220, height = 38, showPower = true, powerHeight = 8, powerDetached = false, powerWidth = 220 },
    pet = { width = 180, height = 28, showPower = true, powerHeight = 8, powerDetached = false, powerWidth = 180 },
    boss = { width = 220, height = 36, showPower = true, powerHeight = 8, powerDetached = false, powerWidth = 220 },
}

local SINGLE_LAYOUT_DEFAULTS = {
    player = { point = "BOTTOM", relativePoint = "BOTTOM", x = -260, y = 260 },
    target = { point = "BOTTOM", relativePoint = "BOTTOM", x = 260, y = 260 },
    targettarget = { point = "BOTTOM", relativePoint = "BOTTOM", x = 260, y = 212 },
    focus = { point = "BOTTOM", relativePoint = "BOTTOM", x = -260, y = 212 },
    pet = { point = "BOTTOM", relativePoint = "BOTTOM", x = -260, y = 176 },
    boss = { point = "RIGHT", relativePoint = "RIGHT", x = -60, y = 520 },
    castbar = { point = "BOTTOM", relativePoint = "BOTTOM", x = -260, y = 220 },
}

local GROUP_DEFAULTS = {
    party = {
        enabled = true,
        width = 180,
        height = 36,
        point = "TOP",
        xOffset = 0,
        yOffset = -6,
        showPlayer = true,
        showSolo = false,
    },
    raid = {
        enabled = true,
        width = 120,
        height = 30,
        point = "TOP",
        xOffset = 0,
        yOffset = -6,
        showSolo = false,
        groupBy = "GROUP",
        groupingOrder = "1,2,3,4,5,6,7,8",
        unitsPerColumn = 5,
        maxColumns = 4,
        columnSpacing = 6,
        columnAnchorPoint = "LEFT",
    },
    tank = {
        enabled = true,
        width = 180,
        height = 32,
        point = "TOP",
        xOffset = 0,
        yOffset = -6,
        showSolo = false,
        groupFilter = "MAINTANK,MAINASSIST",
        unitsPerColumn = 2,
        maxColumns = 1,
        columnSpacing = 6,
        columnAnchorPoint = "LEFT",
    },
    boss = {
        enabled = true,
        yOffset = -8,
    },
}

local GROUP_LAYOUT_DEFAULTS = {
    party = { point = "BOTTOMLEFT", relativePoint = "BOTTOM", x = 36, y = 360 },
    raid = { point = "BOTTOM", relativePoint = "BOTTOM", x = 0, y = 420 },
    tank = { point = "BOTTOMRIGHT", relativePoint = "BOTTOM", x = -36, y = 360 },
    boss = SINGLE_LAYOUT_DEFAULTS.boss,
}

local PLAYER_CASTBAR_DEFAULTS = {
    enabled = true,
    width = 260,
    height = 20,
    iconSize = 20,
    showIcon = true,
    iconPosition = "outside", -- "inside" | "outside"
    iconSide = "left",        -- "left" | "right"
    showSpellText = true,
    showTimeText = true,
    spellFontSize = 11,
    timeFontSize = 10,
    useCustomColor = false,
}

local EMBEDDED_CASTBAR_DEFAULTS = {
    target = { enabled = true, detached = false, width = 220, height = 12, iconSize = 16, showIcon = true, showText = true, showTimeText = true, fontSize = 9, timeFontSize = 9, yOffset = -2 },
    party = { enabled = true, detached = false, width = 180, height = 12, iconSize = 16, showIcon = true, showText = true, showTimeText = true, fontSize = 9, timeFontSize = 9, yOffset = -2 },
    raid = { enabled = true, detached = false, width = 120, height = 12, iconSize = 14, showIcon = true, showText = true, showTimeText = true, fontSize = 8, timeFontSize = 8, yOffset = -2 },
    boss = { enabled = true, detached = false, width = 220, height = 12, iconSize = 18, showIcon = true, showText = true, showTimeText = true, fontSize = 9, timeFontSize = 9, yOffset = -2 },
}

local function GetModule()
    return T:GetModule("UnitFrames", true)
end

local function ResolveValue(value)
    if type(value) == "function" then
        return value()
    end

    return value
end

local function CopyTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = CopyTable(value)
    end
    return copy
end

local function CopyMap(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function ExtendPath(base, ...)
    local path = {}
    if type(base) == "table" then
        for index = 1, #base do
            path[#path + 1] = base[index]
        end
    end

    for index = 1, select("#", ...) do
        path[#path + 1] = select(index, ...)
    end

    return path
end

local function EnsureChildTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
    end

    return parent[key]
end

local function EnsureParentPath(path)
    local node = Options:GetDB()
    for index = 1, (#path - 1) do
        node = EnsureChildTable(node, path[index])
    end

    return node, path[#path]
end

local function GetPathValue(path, fallback)
    local node = Options:GetDB()
    for index = 1, #path do
        if type(node) ~= "table" then
            return ResolveValue(fallback)
        end

        node = node[path[index]]
        if node == nil then
            return ResolveValue(fallback)
        end
    end

    return node
end

local function NotifyConfigurationChanged()
    if ConfigurationModule and type(ConfigurationModule.Refresh) == "function" then
        ConfigurationModule:Refresh()
    end
end

local function RefreshModule()
    local module = GetModule()
    if module and module.IsEnabled and module:IsEnabled() then
        if type(module.RefreshFromOptions) == "function" then
            module:RefreshFromOptions()
        elseif type(module.RefreshAllFrames) == "function" then
            module:RefreshAllFrames()
        end
    end
end

local function CommitChange(refreshConfig)
    RefreshModule()
    if refreshConfig == true then
        NotifyConfigurationChanged()
    end
end

local function SetPathValue(path, value, refreshConfig)
    local parent, key = EnsureParentPath(path)
    parent[key] = value
    CommitChange(refreshConfig)
end

local function SetPathColor(path, red, green, blue, alpha, refreshConfig)
    local parent, key = EnsureParentPath(path)
    parent[key] = {
        red,
        green,
        blue,
        alpha,
    }
    CommitChange(refreshConfig)
end

local function GetLSMValues(kind, defaultLabel)
    local values = {
        [DEFAULT_SENTINEL] = defaultLabel,
    }

    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    local hash = lsm and lsm:HashTable(kind) or nil
    for key, value in pairs(hash or {}) do
        values[key] = value
    end

    return values
end

local function GetEffectiveTextValue(unitKey, field, fallback)
    if unitKey == "__root" then
        return GetPathValue({ "text", field }, fallback)
    end

    local module = GetModule()
    if module and type(module.GetTextConfigFor) == "function" then
        local config = module:GetTextConfigFor(unitKey)
        if type(config) == "table" and config[field] ~= nil then
            return config[field]
        end
    end

    return fallback
end

local function GetEffectiveAuraValue(unitKey, field, fallback)
    local module = GetModule()
    if module and type(module.GetAuraConfigFor) == "function" then
        local config = module:GetAuraConfigFor(unitKey)
        if type(config) == "table" and config[field] ~= nil then
            return config[field]
        end
    end

    return fallback
end

local function ModuleDisabled(extra)
    return function()
        if not Options:GetEnabled() then
            return true
        end

        if type(extra) == "function" then
            return extra() == true
        end

        return false
    end
end

local function BuildToggle(order, name, desc, path, defaultValue, opts)
    opts = opts or {}
    return {
        type = "toggle",
        name = name,
        desc = desc,
        order = order,
        width = opts.width,
        disabled = opts.disabled,
        get = type(opts.get) == "function" and opts.get or function()
            return GetPathValue(path, defaultValue) == true
        end,
        set = function(_, value)
            if type(opts.set) == "function" then
                opts.set(value == true)
                return
            end

            SetPathValue(path, value == true, opts.refreshConfig)
        end,
    }
end

local function BuildRange(order, name, desc, path, defaultValue, minimum, maximum, step, opts)
    opts = opts or {}
    return {
        type = "range",
        name = name,
        desc = desc,
        order = order,
        min = minimum,
        max = maximum,
        step = step,
        width = opts.width,
        disabled = opts.disabled,
        get = function()
            return tonumber(GetPathValue(path, defaultValue)) or ResolveValue(defaultValue) or minimum
        end,
        set = function(_, value)
            if type(opts.normalize) == "function" then
                value = opts.normalize(value)
            end

            SetPathValue(path, value, opts.refreshConfig)
        end,
    }
end

local function BuildSelect(order, name, desc, path, defaultValue, values, opts)
    opts = opts or {}
    return {
        type = "select",
        name = name,
        desc = desc,
        order = order,
        values = values,
        width = opts.width,
        disabled = opts.disabled,
        dialogControl = opts.dialogControl,
        get = function()
            local value = GetPathValue(path, defaultValue)
            if type(opts.get) == "function" then
                value = opts.get(value)
            end
            return value
        end,
        set = function(_, value)
            if type(opts.set) == "function" then
                opts.set(value)
                return
            end

            if type(opts.normalize) == "function" then
                value = opts.normalize(value)
            end
            SetPathValue(path, value, opts.refreshConfig)
        end,
    }
end

local function BuildInput(order, name, desc, path, defaultValue, opts)
    opts = opts or {}
    return {
        type = "input",
        name = name,
        desc = desc,
        order = order,
        width = opts.width,
        multiline = opts.multiline,
        disabled = opts.disabled,
        get = function()
            local value = GetPathValue(path, defaultValue)
            if value == nil then
                return ""
            end
            return tostring(value)
        end,
        set = function(_, value)
            if type(opts.normalize) == "function" then
                value = opts.normalize(value)
            end
            SetPathValue(path, value, opts.refreshConfig)
        end,
    }
end

local function BuildColor(order, name, desc, path, defaultValue, hasAlpha, opts)
    opts = opts or {}
    return {
        type = "color",
        name = name,
        desc = desc,
        order = order,
        width = opts.width,
        hasAlpha = hasAlpha == true,
        disabled = opts.disabled,
        get = function()
            local color = GetPathValue(path, defaultValue)
            return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
        end,
        set = function(_, red, green, blue, alpha)
            SetPathColor(path, red, green, blue, hasAlpha == true and alpha or 1, opts.refreshConfig)
        end,
    }
end

local function BuildExecute(order, name, desc, func, opts)
    opts = opts or {}
    return {
        type = "execute",
        name = name,
        desc = desc,
        order = order,
        width = opts.width,
        disabled = opts.disabled,
        func = function()
            func()
        end,
    }
end

local function BuildFontSelect(order, name, desc, path, defaultLabel, opts)
    opts = opts or {}
    return BuildSelect(order, name, desc, path, DEFAULT_SENTINEL, function()
        return GetLSMValues("font", defaultLabel or "Use Default")
    end, {
        dialogControl = "LSM30_Font",
        disabled = opts.disabled,
        width = opts.width,
        get = function(value)
            if type(value) ~= "string" or value == "" then
                return DEFAULT_SENTINEL
            end
            return value
        end,
        normalize = function(value)
            if value == DEFAULT_SENTINEL then
                return nil
            end
            return value
        end,
    })
end

local function BuildTextureSelect(order, name, desc, path, defaultLabel, opts)
    opts = opts or {}
    return BuildSelect(order, name, desc, path, DEFAULT_SENTINEL, function()
        return GetLSMValues("statusbar", defaultLabel or "Use Theme Texture")
    end, {
        dialogControl = "LSM30_Statusbar",
        disabled = opts.disabled,
        width = opts.width,
        get = function(value)
            if type(value) ~= "string" or value == "" then
                return DEFAULT_SENTINEL
            end
            return value
        end,
        normalize = function(value)
            if value == DEFAULT_SENTINEL then
                return nil
            end
            return value
        end,
    })
end

local function BuildLayoutGroup(order, name, layoutKey, defaults, opts)
    opts = opts or {}
    local layoutPath = { "layout", layoutKey }
    return Widgets.IGroup(order, name, {
        point = BuildSelect(1, "Anchor", "Frame anchor point.", ExtendPath(layoutPath, "point"),
            defaults.point or "CENTER", POINT_VALUES, {
                disabled = opts.disabled,
            }),
        relativePoint = BuildSelect(2, "Relative Point", "Anchor point on the screen or parent frame.",
            ExtendPath(layoutPath, "relativePoint"), defaults.relativePoint or defaults.point or "CENTER", POINT_VALUES,
            {
                disabled = opts.disabled,
            }),
        x = BuildRange(3, "X Offset", "Horizontal position offset.", ExtendPath(layoutPath, "x"), defaults.x or 0, -2400,
            2400, 1, {
                disabled = opts.disabled,
            }),
        y = BuildRange(4, "Y Offset", "Vertical position offset.", ExtendPath(layoutPath, "y"), defaults.y or 0, -1600,
            1600, 1, {
                disabled = opts.disabled,
            }),
    })
end

local function BuildTextGroup(order, name, basePath, unitKey)
    local disabled = ModuleDisabled()
    local function textDefault(field)
        return function()
            return GetEffectiveTextValue(unitKey, field, ROOT_TEXT_DEFAULTS[field])
        end
    end

    return {
        type = "group",
        name = name,
        order = order,
        inline = true,
        args = {
            formats = Widgets.IGroup(1, "Formats", {
                nameFormat = BuildSelect(1, "Name", "Name tag format.", ExtendPath(basePath, "nameFormat"),
                    textDefault("nameFormat"), NAME_FORMAT_VALUES, {
                        disabled = disabled,
                    }),
                customNameTag = BuildInput(2, "Custom Name Tag", "Custom oUF tag string used when Name is set to Custom.",
                    ExtendPath(basePath, "customNameTag"), "", {
                        disabled = ModuleDisabled(function()
                            return GetEffectiveTextValue(unitKey, "nameFormat", "full") ~= "custom"
                        end),
                        width = "full",
                    }),
                healthFormat = BuildSelect(3, "Health", "Health text format.", ExtendPath(basePath, "healthFormat"),
                    textDefault("healthFormat"), RESOURCE_FORMAT_VALUES, {
                        disabled = disabled,
                    }),
                customHealthTag = BuildInput(4, "Custom Health Tag",
                    "Custom oUF tag string used when Health is set to Custom.", ExtendPath(basePath, "customHealthTag"),
                    "", {
                        disabled = ModuleDisabled(function()
                            return GetEffectiveTextValue(unitKey, "healthFormat", "percent") ~= "custom"
                        end),
                        width = "full",
                    }),
                powerFormat = BuildSelect(5, "Power", "Power text format.", ExtendPath(basePath, "powerFormat"),
                    textDefault("powerFormat"), RESOURCE_FORMAT_VALUES, {
                        disabled = disabled,
                    }),
                customPowerTag = BuildInput(6, "Custom Power Tag",
                    "Custom oUF tag string used when Power is set to Custom.", ExtendPath(basePath, "customPowerTag"), "",
                    {
                        disabled = ModuleDisabled(function()
                            return GetEffectiveTextValue(unitKey, "powerFormat", "percent") ~= "custom"
                        end),
                        width = "full",
                    }),
            }),
            fonts = Widgets.IGroup(2, "Font", {
                fontName = BuildFontSelect(1, "Font", "Overrides the shared Unit Frames font for this scope.",
                    ExtendPath(basePath, "fontName"), "Use inherited font", {
                        disabled = disabled,
                    }),
                outlineMode = BuildSelect(2, "Outline", "Font outline mode.", ExtendPath(basePath, "outlineMode"),
                    textDefault("outlineMode"), OUTLINE_VALUES, {
                        disabled = disabled,
                    }),
                nameFontSize = BuildRange(3, "Name Size", "Name font size.", ExtendPath(basePath, "nameFontSize"),
                    textDefault("nameFontSize"), 6, 28, 1, {
                        disabled = disabled,
                    }),
                healthFontSize = BuildRange(4, "Health Size", "Health value font size.",
                    ExtendPath(basePath, "healthFontSize"), textDefault("healthFontSize"), 6, 28, 1, {
                        disabled = disabled,
                    }),
                powerFontSize = BuildRange(5, "Power Size", "Power value font size.",
                    ExtendPath(basePath, "powerFontSize"), textDefault("powerFontSize"), 6, 28, 1, {
                        disabled = disabled,
                    }),
                shadowEnabled = BuildToggle(6, "Text Shadow", "Enable a text shadow for this scope.",
                    ExtendPath(basePath, "shadowEnabled"), textDefault("shadowEnabled"), {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                shadowColor = BuildColor(7, "Shadow Color", "Shadow tint and alpha.", ExtendPath(basePath, "shadowColor"),
                    COLOR_DEFAULTS.shadow, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(basePath, "shadowEnabled"), textDefault("shadowEnabled")) ~=
                            true
                        end),
                    }),
                shadowOffsetX = BuildRange(8, "Shadow X", "Horizontal text shadow offset.",
                    ExtendPath(basePath, "shadowOffsetX"), textDefault("shadowOffsetX"), -8, 8, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(basePath, "shadowEnabled"), textDefault("shadowEnabled")) ~=
                            true
                        end),
                    }),
                shadowOffsetY = BuildRange(9, "Shadow Y", "Vertical text shadow offset.",
                    ExtendPath(basePath, "shadowOffsetY"), textDefault("shadowOffsetY"), -8, 8, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(basePath, "shadowEnabled"), textDefault("shadowEnabled")) ~=
                            true
                        end),
                    }),
            }),
            positions = Widgets.IGroup(3, "Positioning", {
                namePoint = BuildSelect(1, "Name Point", "Name anchor point.", ExtendPath(basePath, "namePoint"),
                    textDefault("namePoint"), POINT_VALUES, {
                        disabled = disabled,
                    }),
                nameRelativePoint = BuildSelect(2, "Name Relative", "Relative anchor point for the name.",
                    ExtendPath(basePath, "nameRelativePoint"), textDefault("nameRelativePoint"), POINT_VALUES, {
                        disabled = disabled,
                    }),
                nameOffsetX = BuildRange(3, "Name X", "Name horizontal offset.", ExtendPath(basePath, "nameOffsetX"),
                    textDefault("nameOffsetX"), -120, 120, 1, {
                        disabled = disabled,
                    }),
                nameOffsetY = BuildRange(4, "Name Y", "Name vertical offset.", ExtendPath(basePath, "nameOffsetY"),
                    textDefault("nameOffsetY"), -60, 60, 1, {
                        disabled = disabled,
                    }),
                healthPoint = BuildSelect(5, "Health Point", "Health value anchor point.",
                    ExtendPath(basePath, "healthPoint"), textDefault("healthPoint"), POINT_VALUES, {
                        disabled = disabled,
                    }),
                healthRelativePoint = BuildSelect(6, "Health Relative", "Relative anchor point for health text.",
                    ExtendPath(basePath, "healthRelativePoint"), textDefault("healthRelativePoint"), POINT_VALUES, {
                        disabled = disabled,
                    }),
                healthOffsetX = BuildRange(7, "Health X", "Health text horizontal offset.",
                    ExtendPath(basePath, "healthOffsetX"), textDefault("healthOffsetX"), -120, 120, 1, {
                        disabled = disabled,
                    }),
                healthOffsetY = BuildRange(8, "Health Y", "Health text vertical offset.",
                    ExtendPath(basePath, "healthOffsetY"), textDefault("healthOffsetY"), -60, 60, 1, {
                        disabled = disabled,
                    }),
                powerPoint = BuildSelect(9, "Power Point", "Power value anchor point.",
                    ExtendPath(basePath, "powerPoint"), textDefault("powerPoint"), POINT_VALUES, {
                        disabled = disabled,
                    }),
                powerRelativePoint = BuildSelect(10, "Power Relative", "Relative anchor point for power text.",
                    ExtendPath(basePath, "powerRelativePoint"), textDefault("powerRelativePoint"), POINT_VALUES, {
                        disabled = disabled,
                    }),
                powerOffsetX = BuildRange(11, "Power X", "Power text horizontal offset.",
                    ExtendPath(basePath, "powerOffsetX"), textDefault("powerOffsetX"), -120, 120, 1, {
                        disabled = disabled,
                    }),
                powerOffsetY = BuildRange(12, "Power Y", "Power text vertical offset.",
                    ExtendPath(basePath, "powerOffsetY"), textDefault("powerOffsetY"), -60, 60, 1, {
                        disabled = disabled,
                    }),
            }),
        },
    }
end

local function BuildAuraGroup(order, name, basePath, unitKey)
    local disabled = ModuleDisabled()
    local function auraDefault(field, fallback)
        return function()
            return GetEffectiveAuraValue(unitKey, field, fallback)
        end
    end

    return Widgets.IGroup(order, name, {
        enabled = BuildToggle(1, "Enable", "Show aura icons or bars for this frame type.",
            ExtendPath(basePath, "enabled"), auraDefault("enabled", true), {
                disabled = disabled,
                refreshConfig = true,
            }),
        filter = BuildSelect(2, "Filter", "Which auras should be shown.", ExtendPath(basePath, "filter"),
            auraDefault("filter", "ALL"), AURA_FILTER_VALUES, {
                disabled = disabled,
            }),
        onlyMine = BuildToggle(3, "Only Mine", "Only show auras cast by you.", ExtendPath(basePath, "onlyMine"),
            auraDefault("onlyMine", false), {
                disabled = disabled,
            }),
        maxIcons = BuildRange(4, "Count", "Maximum aura icons or bars.", ExtendPath(basePath, "maxIcons"),
            auraDefault("maxIcons", 8), 1, 20, 1, {
                disabled = disabled,
            }),
        iconSize = BuildRange(5, "Icon Size", "Aura icon size.", ExtendPath(basePath, "iconSize"),
            auraDefault("iconSize", 18), 10, 40, 1, {
                disabled = disabled,
            }),
        spacing = BuildRange(6, "Spacing", "Space between aura icons or bars.", ExtendPath(basePath, "spacing"),
            auraDefault("spacing", 2), 0, 12, 1, {
                disabled = disabled,
            }),
        yOffset = BuildRange(7, "YOffset", "Offset above the frame.", ExtendPath(basePath, "yOffset"),
            auraDefault("yOffset", 6), -40, 60, 1, {
                disabled = disabled,
            }),
        barMode = BuildToggle(8, "Bar Mode", "Render tracked auras as bars instead of icons.",
            ExtendPath(basePath, "barMode"), auraDefault("barMode", false), {
                disabled = disabled,
                refreshConfig = true,
            }),
        barHeight = BuildRange(9, "Bar Height", "Aura bar height in bar mode.", ExtendPath(basePath, "barHeight"),
            auraDefault("barHeight", 14), 8, 30, 1, {
                disabled = ModuleDisabled(function()
                    return GetPathValue(ExtendPath(basePath, "barMode"), auraDefault("barMode", false)) ~= true
                end),
            }),
    })
end

local BuildColorScopeTab
local BuildUnitColorTab

local function BuildSingleUnitTab(unitKey, label)
    local defaults = SINGLE_UNIT_DEFAULTS[unitKey]
    local layoutDefaults = SINGLE_LAYOUT_DEFAULTS[unitKey]
    local basePath = { "units", unitKey }
    local textPath = ExtendPath(basePath, "text")
    local auraPath = ExtendPath(basePath, "auras")
    local disabled = ModuleDisabled()

    local tab = {
        type = "group",
        name = label,
        order = 1,
        childGroups = "tab",
        args = {
            frame = {
                type = "group",
                name = "Frame",
                order = 1,
                args = {
                    display = Widgets.IGroup(1, "Display", {
                        enabled = BuildToggle(1, "Enable", "Show this unit frame.", ExtendPath(basePath, "enabled"), true,
                            {
                                disabled = disabled,
                                refreshConfig = true,
                            }),
                        width = BuildRange(2, "Width", "Frame width.", ExtendPath(basePath, "width"), defaults.width, 80,
                            600, 1, {
                                disabled = disabled,
                            }),
                        height = BuildRange(3, "Height", "Frame height.", ExtendPath(basePath, "height"), defaults
                            .height, 16, 180, 1, {
                                disabled = disabled,
                            }),
                    }),
                    power = Widgets.IGroup(2, "Power Bar", {
                        showPower = BuildToggle(1, "Show Power", "Show the embedded power bar.",
                            ExtendPath(basePath, "showPower"), defaults.showPower, {
                                disabled = disabled,
                                refreshConfig = true,
                            }),
                        powerHeight = BuildRange(2, "Power Height", "Power bar height.",
                            ExtendPath(basePath, "powerHeight"), defaults.powerHeight, 4, 32, 1, {
                                disabled = ModuleDisabled(function()
                                    return GetPathValue(ExtendPath(basePath, "showPower"), defaults.showPower) ~= true
                                end),
                            }),
                        powerDetached = BuildToggle(3, "Detach Power", "Detach the power bar from the main frame.",
                            ExtendPath(basePath, "powerDetached"), defaults.powerDetached, {
                                disabled = ModuleDisabled(function()
                                    return GetPathValue(ExtendPath(basePath, "showPower"), defaults.showPower) ~= true
                                end),
                                refreshConfig = true,
                            }),
                        powerWidth = BuildRange(4, "Detached Width", "Width of the detached power bar.",
                            ExtendPath(basePath, "powerWidth"), defaults.powerWidth, 40, 600, 1, {
                                disabled = ModuleDisabled(function()
                                    return GetPathValue(ExtendPath(basePath, "powerDetached"), defaults.powerDetached) ~=
                                        true
                                end),
                            }),
                        powerPoint = BuildSelect(5, "Power Anchor", "Detached power bar anchor.",
                            ExtendPath(basePath, "powerPoint"), "TOPLEFT", POINT_VALUES, {
                                disabled = ModuleDisabled(function()
                                    return GetPathValue(ExtendPath(basePath, "powerDetached"), defaults.powerDetached) ~=
                                        true
                                end),
                            }),
                        powerRelativePoint = BuildSelect(6, "Power Relative", "Detached power bar relative point.",
                            ExtendPath(basePath, "powerRelativePoint"), "BOTTOMLEFT", POINT_VALUES, {
                                disabled = ModuleDisabled(function()
                                    return GetPathValue(ExtendPath(basePath, "powerDetached"), defaults.powerDetached) ~=
                                        true
                                end),
                            }),
                        powerOffsetX = BuildRange(7, "Power X", "Detached power bar horizontal offset.",
                            ExtendPath(basePath, "powerOffsetX"), 0, -120, 120, 1, {
                                disabled = ModuleDisabled(function()
                                    return GetPathValue(ExtendPath(basePath, "powerDetached"), defaults.powerDetached) ~=
                                        true
                                end),
                            }),
                        powerOffsetY = BuildRange(8, "Power Y", "Detached power bar vertical offset.",
                            ExtendPath(basePath, "powerOffsetY"), -1, -120, 120, 1, {
                                disabled = ModuleDisabled(function()
                                    return GetPathValue(ExtendPath(basePath, "powerDetached"), defaults.powerDetached) ~=
                                        true
                                end),
                            }),
                    }),
                },
            },
            layout = BuildLayoutGroup(2, "Layout", unitKey, layoutDefaults, {
                disabled = disabled,
            }),
            text = BuildTextGroup(3, "Text", textPath, unitKey),
            auras = BuildAuraGroup(4, "Auras", auraPath, unitKey),
            colors = BuildUnitColorTab(5, unitKey),
        },
    }

    -- Class bar tab only on the player
    if unitKey == "player" then
        local isBarDisabled = ModuleDisabled()
        local isColorDisabled = ModuleDisabled(function()
            return GetPathValue({ "classBar", "useCustomColor" }, false) ~= true
        end)
        local isBGDisabled = ModuleDisabled(function()
            return GetPathValue({ "classBar", "useCustomBackground" }, false) ~= true
        end)
        local isBorderDisabled = ModuleDisabled(function()
            return GetPathValue({ "classBar", "useCustomBorder" }, false) ~= true
        end)
        local isPowerOn = ModuleDisabled(function()
            return GetPathValue({ "classBar", "enabled" }, true) ~= true
        end)
        tab.args.classBar = {
            type = "group",
            name = "Class Bar",
            order = 6,
            args = Widgets.IGroup(1, "Class Bar", {
                enabled = BuildToggle(1, "Enable", "Show the player class resource bar.",
                    { "classBar", "enabled" }, true, { disabled = isBarDisabled, refreshConfig = true }),
                width = BuildRange(2, "Width", "Class bar width.",
                    { "classBar", "width" }, 260, 40, 600, 1, { disabled = isPowerOn }),
                height = BuildRange(3, "Height", "Class bar height.",
                    { "classBar", "height" }, 10, 4, 40, 1, { disabled = isPowerOn }),
                spacing = BuildRange(4, "Segment Gap",
                    "Pixel gap between each class resource segment (e.g. Holy Power ticks).",
                    { "classBar", "spacing" }, 2, 0, 40, 1, { disabled = isPowerOn }),
                point = BuildSelect(5, "Anchor", "Class bar anchor point.",
                    { "classBar", "point" }, "TOPLEFT", POINT_VALUES, { disabled = isPowerOn }),
                relativePoint = BuildSelect(6, "Relative Point", "Class bar relative anchor point.",
                    { "classBar", "relativePoint" }, "BOTTOMLEFT", POINT_VALUES, { disabled = isPowerOn }),
                xOffset = BuildRange(7, "X Offset", "Class bar horizontal offset.",
                    { "classBar", "xOffset" }, 0, -240, 240, 1, { disabled = isPowerOn }),
                yOffset = BuildRange(8, "Y Offset", "Class bar vertical offset.",
                    { "classBar", "yOffset" }, -2, -240, 240, 1, { disabled = isPowerOn }),
                useCustomColor = BuildToggle(9, "Custom Bar Color",
                    "Use a specific color instead of the class resource color.",
                    { "classBar", "useCustomColor" }, false, { disabled = isPowerOn, refreshConfig = true }),
                color = BuildColor(10, "Bar Color", "Custom class bar color.",
                    { "classBar", "color" }, COLOR_DEFAULTS.classBar, true, { disabled = isColorDisabled }),
                useCustomBackground = BuildToggle(11, "Custom Background",
                    "Use a custom background color for the class bar segments.",
                    { "classBar", "useCustomBackground" }, false, { disabled = isPowerOn, refreshConfig = true }),
                backgroundColor = BuildColor(12, "Background Color", "Class bar segment background color.",
                    { "classBar", "backgroundColor" }, COLOR_DEFAULTS.classBarBackground, true,
                    { disabled = isBGDisabled }),
                useCustomBorder = BuildToggle(13, "Custom Border",
                    "Use a custom border color for the class bar segments.",
                    { "classBar", "useCustomBorder" }, false, { disabled = isPowerOn, refreshConfig = true }),
                borderColor = BuildColor(14, "Border Color", "Class bar segment border color.",
                    { "classBar", "borderColor" }, COLOR_DEFAULTS.classBarBorder, true,
                    { disabled = isBorderDisabled }),
            }).args,
        }
    end

    return tab
end

local function BuildGroupTab(groupKey, label)
    local defaults = GROUP_DEFAULTS[groupKey]
    local layoutDefaults = GROUP_LAYOUT_DEFAULTS[groupKey]
    local basePath = { "groups", groupKey }
    local textPath = { "text", "scopes", groupKey }
    local auraPath = { "auras", "scopes", groupKey }
    local disabled = ModuleDisabled()
    local frameTab = {
        type = "group",
        name = "Frame",
        order = 1,
        args = {
            display = Widgets.IGroup(1, "Members", {
                enabled = BuildToggle(1, "Enable", "Show this header or group.", ExtendPath(basePath, "enabled"),
                    defaults.enabled, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                width = BuildRange(2, "Width", "Member frame width.", ExtendPath(basePath, "width"), defaults.width, 70,
                    500, 1, {
                        disabled = disabled,
                    }),
                height = BuildRange(3, "Height", "Member frame height.", ExtendPath(basePath, "height"), defaults.height,
                    14, 120, 1, {
                        disabled = disabled,
                    }),
                point = BuildSelect(4, "Growth Point", "Header growth direction.", ExtendPath(basePath, "point"),
                    defaults.point or "TOP", POINT_VALUES, {
                        disabled = disabled,
                    }),
                xOffset = BuildRange(5, "X Spacing", "Horizontal spacing between members.",
                    ExtendPath(basePath, "xOffset"), defaults.xOffset or 0, -120, 120, 1, {
                        disabled = disabled,
                    }),
                yOffset = BuildRange(6, "Y Spacing", "Vertical spacing between members.", ExtendPath(basePath, "yOffset"),
                    defaults.yOffset or -6, -120, 120, 1, {
                        disabled = disabled,
                    }),
            }),
        },
    }

    if groupKey == "party" then
        frameTab.args.visibility = Widgets.IGroup(2, "Visibility", {
            showPlayer = BuildToggle(1, "Include Player", "Show the player in party frames.",
                ExtendPath(basePath, "showPlayer"), defaults.showPlayer, {
                    disabled = disabled,
                }),
            showSolo = BuildToggle(2, "Show Solo", "Keep party frames visible while solo.",
                ExtendPath(basePath, "showSolo"), defaults.showSolo, {
                    disabled = disabled,
                }),
        })
    elseif groupKey == "raid" then
        frameTab.args.layouting = Widgets.IGroup(2, "Columns", {
            showSolo = BuildToggle(1, "Show Solo", "Keep raid frames visible while solo.",
                ExtendPath(basePath, "showSolo"), defaults.showSolo, {
                    disabled = disabled,
                }),
            groupBy = BuildSelect(2, "Group By", "Header grouping rule.", ExtendPath(basePath, "groupBy"),
                defaults.groupBy, GROUP_BY_VALUES, {
                    disabled = disabled,
                }),
            groupingOrder = BuildInput(3, "Grouping Order", "Secure header grouping order.",
                ExtendPath(basePath, "groupingOrder"), defaults.groupingOrder, {
                    disabled = disabled,
                    width = "full",
                }),
            unitsPerColumn = BuildRange(4, "Units Per Column", "How many frames to place in each raid column.",
                ExtendPath(basePath, "unitsPerColumn"), defaults.unitsPerColumn, 1, 8, 1, {
                    disabled = disabled,
                }),
            maxColumns = BuildRange(5, "Max Columns", "Maximum number of visible raid columns.",
                ExtendPath(basePath, "maxColumns"), defaults.maxColumns, 1, 8, 1, {
                    disabled = disabled,
                }),
            columnSpacing = BuildRange(6, "Column Spacing", "Space between raid columns.",
                ExtendPath(basePath, "columnSpacing"), defaults.columnSpacing, 0, 40, 1, {
                    disabled = disabled,
                }),
            columnAnchorPoint = BuildSelect(7, "Column Anchor", "Which side new columns grow from.",
                ExtendPath(basePath, "columnAnchorPoint"), defaults.columnAnchorPoint, {
                    LEFT = "Left",
                    RIGHT = "Right",
                    TOP = "Top",
                    BOTTOM = "Bottom",
                }, {
                    disabled = disabled,
                }),
        })
    elseif groupKey == "tank" then
        frameTab.args.visibility = Widgets.IGroup(2, "Visibility", {
            showSolo = BuildToggle(1, "Show Solo", "Keep tank frames visible while solo.",
                ExtendPath(basePath, "showSolo"), defaults.showSolo, {
                    disabled = disabled,
                }),
            groupFilter = BuildInput(2, "Group Filter", "Secure header group filter string.",
                ExtendPath(basePath, "groupFilter"), defaults.groupFilter, {
                    disabled = disabled,
                    width = "full",
                }),
            unitsPerColumn = BuildRange(3, "Units Per Column", "Maximum units per column.",
                ExtendPath(basePath, "unitsPerColumn"), defaults.unitsPerColumn, 1, 8, 1, {
                    disabled = disabled,
                }),
            maxColumns = BuildRange(4, "Max Columns", "Maximum number of tank columns.",
                ExtendPath(basePath, "maxColumns"), defaults.maxColumns, 1, 4, 1, {
                    disabled = disabled,
                }),
            columnSpacing = BuildRange(5, "Column Spacing", "Space between tank columns.",
                ExtendPath(basePath, "columnSpacing"), defaults.columnSpacing, 0, 40, 1, {
                    disabled = disabled,
                }),
        })
    end

    local colorsTab = BuildColorScopeTab(groupKey, "Colors")
    colorsTab.order = 5

    return {
        type = "group",
        name = label,
        order = 1,
        childGroups = "tab",
        args = {
            frame = frameTab,
            layout = BuildLayoutGroup(2, "Layout", groupKey, layoutDefaults, {
                disabled = disabled,
            }),
            text = BuildTextGroup(3, "Text", textPath, groupKey .. "Member"),
            auras = BuildAuraGroup(4, "Auras", auraPath, groupKey .. "Member"),
            colors = colorsTab,
        },
    }
end

local function BuildBossTab()
    local groupDefaults = GROUP_DEFAULTS.boss
    local unitDefaults = SINGLE_UNIT_DEFAULTS.boss
    local disabled = ModuleDisabled()
    local colorsTab = BuildColorScopeTab("boss", "Colors")
    colorsTab.order = 5

    return {
        type = "group",
        name = "Boss",
        order = 1,
        childGroups = "tab",
        args = {
            frame = {
                type = "group",
                name = "Frame",
                order = 1,
                args = {
                    display = Widgets.IGroup(1, "Display", {
                        enabled = BuildToggle(1, "Enable", "Show boss frames.", { "groups", "boss", "enabled" },
                            groupDefaults.enabled, {
                                disabled = disabled,
                                refreshConfig = true,
                            }),
                        width = BuildRange(2, "Width", "Boss frame width.", { "units", "boss", "width" },
                            unitDefaults.width, 120, 500, 1, {
                                disabled = disabled,
                            }),
                        height = BuildRange(3, "Height", "Boss frame height.", { "units", "boss", "height" },
                            unitDefaults.height, 16, 120, 1, {
                                disabled = disabled,
                            }),
                        yOffset = BuildRange(4, "Stack Y Offset", "Vertical spacing between boss frames.",
                            { "groups", "boss", "yOffset" }, groupDefaults.yOffset, -120, 120, 1, {
                                disabled = disabled,
                            }),
                    }),
                },
            },
            layout = BuildLayoutGroup(2, "Layout", "boss", GROUP_LAYOUT_DEFAULTS.boss, {
                disabled = disabled,
            }),
            text = BuildTextGroup(3, "Text", { "text", "scopes", "boss" }, "boss"),
            auras = BuildAuraGroup(4, "Auras", { "auras", "scopes", "boss" }, "boss"),
            colors = colorsTab,
        },
    }
end

local function BuildEmbeddedCastbarTab(scopeKey, label)
    local defaults = EMBEDDED_CASTBAR_DEFAULTS[scopeKey]
    local path = { "castbars", scopeKey }
    local disabled = ModuleDisabled()

    return {
        type = "group",
        name = label,
        order = 1,
        args = {
            display = Widgets.IGroup(1, "Display", {
                enabled = BuildToggle(1, "Enable", "Show embedded castbars for this scope.", ExtendPath(path, "enabled"),
                    defaults.enabled, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                detached = BuildToggle(2, "Detached", "Detach these castbars from the unit frame.",
                    ExtendPath(path, "detached"), defaults.detached, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                width = BuildRange(3, "Width", "Castbar width when detached.", ExtendPath(path, "width"), defaults.width,
                    40, 600, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "detached"), defaults.detached) ~= true
                        end),
                    }),
                height = BuildRange(4, "Height", "Castbar height.", ExtendPath(path, "height"), defaults.height, 4, 40, 1,
                    {
                        disabled = disabled,
                    }),
                iconSize = BuildRange(5, "Icon Size", "Castbar icon size.", ExtendPath(path, "iconSize"),
                    defaults.iconSize, 12, 50, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "showIcon"), defaults.showIcon) ~= true
                        end),
                    }),
                showIcon = BuildToggle(6, "Show Icon", "Show the spell icon.", ExtendPath(path, "showIcon"),
                    defaults.showIcon, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                showText = BuildToggle(7, "Show Spell", "Show the spell name text.", ExtendPath(path, "showText"),
                    defaults.showText, {
                        disabled = disabled,
                    }),
                showTimeText = BuildToggle(8, "Show Time", "Show the remaining cast time.",
                    ExtendPath(path, "showTimeText"), defaults.showTimeText, {
                        disabled = disabled,
                    }),
                fontSize = BuildRange(9, "Spell Size", "Spell text size.", ExtendPath(path, "fontSize"),
                    defaults.fontSize, 6, 20, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "showText"), defaults.showText) ~= true
                        end),
                    }),
                timeFontSize = BuildRange(10, "Time Size", "Time text size.", ExtendPath(path, "timeFontSize"),
                    defaults.timeFontSize, 6, 20, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "showTimeText"), defaults.showTimeText) ~= true
                        end),
                    }),
                useCustomColor = BuildToggle(11, "Custom Color", "Use a dedicated castbar color for this scope.",
                    ExtendPath(path, "useCustomColor"), false, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                color = BuildColor(12, "Castbar Color", "Custom castbar color.", ExtendPath(path, "color"),
                    COLOR_DEFAULTS.cast, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "useCustomColor"), false) ~= true
                        end),
                    }),
            }),
            anchor = Widgets.IGroup(2, "Detached Anchor", {
                point = BuildSelect(1, "Anchor", "Detached castbar anchor point.", ExtendPath(path, "point"), "TOPLEFT",
                    POINT_VALUES, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "detached"), defaults.detached) ~= true
                        end),
                    }),
                relativePoint = BuildSelect(2, "Relative Point", "Detached castbar relative anchor point.",
                    ExtendPath(path, "relativePoint"), "BOTTOMLEFT", POINT_VALUES, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "detached"), defaults.detached) ~= true
                        end),
                    }),
                xOffset = BuildRange(3, "X Offset", "Detached castbar horizontal offset.", ExtendPath(path, "xOffset"), 0,
                    -400, 400, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "detached"), defaults.detached) ~= true
                        end),
                    }),
                yOffset = BuildRange(4, "Y Offset", "Detached castbar vertical offset.", ExtendPath(path, "yOffset"),
                    defaults.yOffset, -400, 400, 1, {
                        disabled = disabled,
                    }),
            }),
        },
    }
end

BuildColorScopeTab = function(scopeKey, label)
    local healthModePath = { "healthColorByScope", scopeKey, "mode" }
    local healthColorPath = { "healthColorByScope", scopeKey, "color" }
    local colorPath = { "colors", "scopes", scopeKey }
    local disabled = ModuleDisabled()
    local function defaultMode()
        return GetPathValue({ "useClassColor" }, false) == true and "class" or "theme"
    end

    return {
        type = "group",
        name = label,
        order = 1,
        args = {
            health = Widgets.IGroup(1, "Health", {
                mode = BuildSelect(1, "Health Color Mode", "How the health bar color is chosen.", healthModePath,
                    defaultMode, HEALTH_MODE_VALUES, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                color = BuildColor(2, "Custom Health", "Custom health bar color when mode is set to Custom.",
                    healthColorPath, COLOR_DEFAULTS.health, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(healthModePath, defaultMode) ~= "custom"
                        end),
                    }),
            }),
            palette = Widgets.IGroup(2, "Palette", {
                power = BuildColor(1, "Power", "Power bar color.", ExtendPath(colorPath, "power"), COLOR_DEFAULTS.power,
                    true, {
                        disabled = disabled,
                    }),
                cast = BuildColor(2, "Cast", "Castbar color.", ExtendPath(colorPath, "cast"), COLOR_DEFAULTS.cast, true,
                    {
                        disabled = disabled,
                    }),
                background = BuildColor(3, "Background", "Frame background tint.", ExtendPath(colorPath, "background"),
                    COLOR_DEFAULTS.background, true, {
                        disabled = disabled,
                    }),
                border = BuildColor(4, "Border", "Frame border tint.", ExtendPath(colorPath, "border"),
                    COLOR_DEFAULTS.border, true, {
                        disabled = disabled,
                    }),
            }),
        },
    }
end

BuildUnitColorTab = function(order, unitKey)
    local unitPath = { "units", unitKey }
    local healthModePath = ExtendPath(unitPath, "healthColor", "mode")
    local healthColorPath = ExtendPath(unitPath, "healthColor", "color")
    local colorPath = ExtendPath(unitPath, "colors")
    local disabled = ModuleDisabled()

    return {
        type = "group",
        name = "Colors",
        order = order,
        args = {
            note = Widgets.Description(0,
                "These colors override the shared Single Units palette for this frame only. Leave Health on Inherit to keep the scope-wide rule."),
            health = Widgets.IGroup(1, "Health", {
                mode = BuildSelect(1, "Health Color Mode", "How this unit's health bar color is chosen.", healthModePath,
                    "inherit", UNIT_HEALTH_MODE_VALUES, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                color = BuildColor(2, "Custom Health", "Custom health bar color when mode is Custom.", healthColorPath,
                    COLOR_DEFAULTS.health, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(healthModePath, "inherit") ~= "custom"
                        end),
                    }),
            }),
            palette = Widgets.IGroup(2, "Palette", {
                power = BuildColor(1, "Power", "Override the power bar color for this unit.",
                    ExtendPath(colorPath, "power"), COLOR_DEFAULTS.power, true, {
                        disabled = disabled,
                    }),
                cast = BuildColor(2, "Cast", "Override the castbar color for this unit.", ExtendPath(colorPath, "cast"),
                    COLOR_DEFAULTS.cast, true, {
                        disabled = disabled,
                    }),
                background = BuildColor(3, "Background", "Override the frame background tint for this unit.",
                    ExtendPath(colorPath, "background"), COLOR_DEFAULTS.background, true, {
                        disabled = disabled,
                    }),
                border = BuildColor(4, "Border", "Override the frame border tint for this unit.",
                    ExtendPath(colorPath, "border"), COLOR_DEFAULTS.border, true, {
                        disabled = disabled,
                    }),
            }),
        },
    }
end

local function BuildGeneralTab()
    local db = Options:GetDB()
    return {
        type = "group",
        name = "General",
        order = 5,
        args = {
            moduleSettings = Widgets.IGroup(1, "Module", {
                moveHint = Widgets.Description(0,
                    "Unlock Movers shows drag handles for detached power, class, and cast bars. Use Test Mode when the anchor frame is normally hidden, such as party, raid, or boss previews."),
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable the standalone Unit Frames module.",
                    order = 1,
                    get = function()
                        return Options:GetEnabled()
                    end,
                    set = function(_, value)
                        Options:SetEnabled(nil, value)
                    end,
                },
                testMode = BuildToggle(2, "Test Mode", "Show preview frames for standalone unit frames.", { "testMode" },
                    db.testMode == true, {
                        refreshConfig = true,
                        set = function(value)
                            local module = GetModule()
                            if module and type(module.SetTestMode) == "function" then
                                module:SetTestMode(value == true)
                            else
                                SetPathValue({ "testMode" }, value == true, true)
                            end
                        end,
                    }),
                unlockMovers = BuildToggle(3, "Unlock Movers", "Show layout movers so frames can be repositioned.",
                    { "lockFrames" }, db.lockFrames ~= true, {
                        refreshConfig = true,
                        get = function()
                            return GetPathValue({ "lockFrames" }, true) ~= true
                        end,
                        set = function(value)
                            local module = GetModule()
                            if module and type(module.SetFrameLock) == "function" then
                                module:SetFrameLock(value ~= true)
                            else
                                SetPathValue({ "lockFrames" }, value ~= true, true)
                            end
                        end,
                    }),
                refreshNow = BuildExecute(4, "Refresh Frames", "Re-apply the current Unit Frames settings.", function()
                    RefreshModule()
                end),
                scale = BuildRange(5, "Scale", "Overall Unit Frames scale.", { "scale" }, db.scale or 1, 0.6, 1.6, 0.01),
                frameAlpha = BuildRange(6, "Alpha", "Overall Unit Frames alpha.", { "frameAlpha" }, db.frameAlpha or 1,
                    0.15, 1, 0.01),
                texture = BuildTextureSelect(7, "Bar Texture", "Global statusbar texture used by the frames.",
                    { "texture" }, "Use theme texture"),
                smoothBars = BuildToggle(8, "Smooth Bars", "Enable value interpolation for health, power, and castbars.",
                    { "smoothBars" }, db.smoothBars ~= false),
                showHealthText = BuildToggle(9, "Show Health Text", "Show health text tags on frames.",
                    { "showHealthText" }, db.showHealthText ~= false),
                showPowerText = BuildToggle(10, "Show Power Text", "Show power text tags on frames.", { "showPowerText" },
                    db.showPowerText ~= false),
                useClassColor = BuildToggle(11, "Use Class Color",
                    "Use class color for health bars when a scope does not override it.", { "useClassColor" },
                    db.useClassColor == true),
            }),
            sharedText = BuildTextGroup(2, "Shared Text Defaults", { "text" }, "__root"),
            highlights = Widgets.IGroup(3, "Highlights", {
                showTarget = BuildToggle(1, "Target Highlight", "Highlight the current target frame.",
                    { "highlights", "showTarget" }, true),
                targetColor = BuildColor(2, "Target Color", "Border color for the current target highlight.",
                    { "highlights", "targetColor" }, COLOR_DEFAULTS.targetHighlight, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "highlights", "showTarget" }, true) ~= true
                        end),
                    }),
                showMouseover = BuildToggle(3, "Mouseover Highlight", "Highlight frames when hovered.",
                    { "highlights", "showMouseover" }, true),
                mouseoverColor = BuildColor(4, "Mouseover Color", "Fill color for mouseover highlight.",
                    { "highlights", "mouseoverColor" }, COLOR_DEFAULTS.mouseoverHighlight, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "highlights", "showMouseover" }, true) ~= true
                        end),
                    }),
            }),
        },
    }
end

local function BuildSinglesTab()
    local playerTab = BuildSingleUnitTab("player", "Player")
    playerTab.order = 1

    local targetTab = BuildSingleUnitTab("target", "Target")
    targetTab.order = 2

    local targetOfTargetTab = BuildSingleUnitTab("targettarget", "Target of Target")
    targetOfTargetTab.order = 3

    local focusTab = BuildSingleUnitTab("focus", "Focus")
    focusTab.order = 4

    local petTab = BuildSingleUnitTab("pet", "Pet")
    petTab.order = 5

    return {
        type = "group",
        name = "Single Units",
        order = 10,
        childGroups = "tab",
        args = {
            player = playerTab,
            target = targetTab,
            targettarget = targetOfTargetTab,
            focus = focusTab,
            pet = petTab,
        },
    }
end

local function BuildGroupsTab()
    local partyTab = BuildGroupTab("party", "Party")
    partyTab.order = 1

    local raidTab = BuildGroupTab("raid", "Raid")
    raidTab.order = 2

    local tankTab = BuildGroupTab("tank", "Tank")
    tankTab.order = 3

    local bossTab = BuildBossTab()
    bossTab.order = 4

    return {
        type = "group",
        name = "Group Units",
        order = 15,
        childGroups = "tab",
        args = {
            party = partyTab,
            raid = raidTab,
            tank = tankTab,
            boss = bossTab,
        },
    }
end

local function BuildCastbarTab()
    local playerTab = {
        type = "group",
        name = "Player",
        order = 1,
        args = {
            display = Widgets.IGroup(1, "Standalone Castbar", {
                enabled = BuildToggle(1, "Enable", "Show the player standalone castbar.", { "castbar", "enabled" },
                    PLAYER_CASTBAR_DEFAULTS.enabled, {
                        refreshConfig = true,
                    }),
                width = BuildRange(2, "Width", "Standalone castbar width.", { "castbar", "width" },
                    PLAYER_CASTBAR_DEFAULTS.width, 120, 600, 1),
                height = BuildRange(3, "Height", "Standalone castbar height.", { "castbar", "height" },
                    PLAYER_CASTBAR_DEFAULTS.height, 10, 60, 1),
                iconSize = BuildRange(4, "Icon Size", "Standalone castbar icon size.", { "castbar", "iconSize" },
                    PLAYER_CASTBAR_DEFAULTS.iconSize, 12, 50, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "showIcon" }, PLAYER_CASTBAR_DEFAULTS.showIcon) ~= true
                        end),
                    }),
                showIcon = BuildToggle(5, "Show Icon", "Show the spell icon on the standalone castbar.",
                    { "castbar", "showIcon" }, PLAYER_CASTBAR_DEFAULTS.showIcon, {
                        refreshConfig = true,
                    }),
                iconPosition = BuildSelect(13, "Icon Position",
                    "Place the icon outside the bar frame or embedded inside it.",
                    { "castbar", "iconPosition" }, PLAYER_CASTBAR_DEFAULTS.iconPosition,
                    { outside = "Outside Bar", inside = "Inside Bar" }, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "showIcon" }, PLAYER_CASTBAR_DEFAULTS.showIcon) ~= true
                        end),
                    }),
                iconSide = BuildSelect(14, "Icon Side",
                    "Which side of the castbar the icon appears on.",
                    { "castbar", "iconSide" }, PLAYER_CASTBAR_DEFAULTS.iconSide,
                    { left = "Left", right = "Right" }, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "showIcon" }, PLAYER_CASTBAR_DEFAULTS.showIcon) ~= true
                        end),
                    }),
                showSpellText = BuildToggle(6, "Show Spell", "Show spell text on the standalone castbar.",
                    { "castbar", "showSpellText" }, PLAYER_CASTBAR_DEFAULTS.showSpellText),
                showTimeText = BuildToggle(7, "Show Time", "Show time text on the standalone castbar.",
                    { "castbar", "showTimeText" }, PLAYER_CASTBAR_DEFAULTS.showTimeText),
                spellFontSize = BuildRange(8, "Spell Size", "Standalone castbar spell font size.",
                    { "castbar", "spellFontSize" }, PLAYER_CASTBAR_DEFAULTS.spellFontSize, 6, 24, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "showSpellText" }, PLAYER_CASTBAR_DEFAULTS.showSpellText) ~=
                                true
                        end),
                    }),
                timeFontSize = BuildRange(9, "Time Size", "Standalone castbar time font size.",
                    { "castbar", "timeFontSize" }, PLAYER_CASTBAR_DEFAULTS.timeFontSize, 6, 24, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "showTimeText" }, PLAYER_CASTBAR_DEFAULTS.showTimeText) ~=
                            true
                        end),
                    }),
                texture = BuildTextureSelect(10, "Texture", "Optional texture override for the standalone castbar.",
                    { "castbar", "texture" }, "Use Unit Frames texture"),
                useCustomColor = BuildToggle(11, "Custom Color", "Use a dedicated player castbar color.",
                    { "castbar", "useCustomColor" }, PLAYER_CASTBAR_DEFAULTS.useCustomColor, {
                        refreshConfig = true,
                    }),
                color = BuildColor(12, "Castbar Color", "Dedicated player castbar color.", { "castbar", "color" },
                    COLOR_DEFAULTS.cast, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "useCustomColor" }, PLAYER_CASTBAR_DEFAULTS.useCustomColor) ~=
                                true
                        end),
                    }),
            }),
            layout = BuildLayoutGroup(2, "Layout", "castbar", SINGLE_LAYOUT_DEFAULTS.castbar, {
                disabled = ModuleDisabled(),
            }),
        },
    }

    local targetTab = BuildEmbeddedCastbarTab("target", "Target")
    targetTab.order = 2

    local partyTab = BuildEmbeddedCastbarTab("party", "Party and Tank")
    partyTab.order = 3

    local raidTab = BuildEmbeddedCastbarTab("raid", "Raid")
    raidTab.order = 4

    local bossTab = BuildEmbeddedCastbarTab("boss", "Boss")
    bossTab.order = 5

    return {
        type = "group",
        name = "Castbar",
        order = 20,
        childGroups = "tab",
        args = {
            player = playerTab,
            target = targetTab,
            party = partyTab,
            raid = raidTab,
            boss = bossTab,
        },
    }
end

local function BuildColorsTab()
    local globalTab = {
        type = "group",
        name = "Global",
        order = 1,
        args = {
            note = Widgets.Description(0,
                "Global palette values provide the fallback look for Unit Frames. Scope tabs override them for single units, party, raid, tank, and boss frames."),
            palette = Widgets.IGroup(1, "Palette", {
                health = BuildColor(1, "Health", "Fallback health color used when a scope is in Theme mode.",
                    { "colors", "health" }, COLOR_DEFAULTS.health, true),
                power = BuildColor(2, "Power", "Fallback power color.", { "colors", "power" }, COLOR_DEFAULTS.power, true),
                cast = BuildColor(3, "Cast", "Fallback castbar color.", { "colors", "cast" }, COLOR_DEFAULTS.cast, true),
                background = BuildColor(4, "Background", "Fallback frame background tint.", { "colors", "background" },
                    COLOR_DEFAULTS.background, true),
                border = BuildColor(5, "Border", "Fallback frame border tint.", { "colors", "border" },
                    COLOR_DEFAULTS.border, true),
            }),
        },
    }

    local singlesTab = BuildColorScopeTab("singles", "Single Units")
    singlesTab.order = 2

    local partyTab = BuildColorScopeTab("party", "Party")
    partyTab.order = 3

    local raidTab = BuildColorScopeTab("raid", "Raid")
    raidTab.order = 4

    local tankTab = BuildColorScopeTab("tank", "Tank")
    tankTab.order = 5

    local bossTab = BuildColorScopeTab("boss", "Boss")
    bossTab.order = 6

    return {
        type = "group",
        name = "Colors",
        order = 25,
        childGroups = "tab",
        args = {
            global = globalTab,
            singles = singlesTab,
            party = partyTab,
            raid = raidTab,
            tank = tankTab,
            boss = bossTab,
        },
    }
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.unitFrames) ~= "table" then
        profile.unitFrames = {}
    end

    local db = profile.unitFrames
    if db.enabled == nil then db.enabled = true end
    if db.testMode == nil then db.testMode = false end
    if db.lockFrames == nil then db.lockFrames = true end
    if db.scale == nil then db.scale = 1 end
    if db.frameAlpha == nil then db.frameAlpha = 1 end
    if db.smoothBars == nil then db.smoothBars = true end
    if db.showHealthText == nil then db.showHealthText = true end
    if db.showPowerText == nil then db.showPowerText = true end
    if type(db.units) ~= "table" then db.units = {} end
    if type(db.groups) ~= "table" then db.groups = {} end
    if type(db.layout) ~= "table" then db.layout = {} end
    if type(db.colors) ~= "table" then db.colors = {} end
    if type(db.colors.scopes) ~= "table" then db.colors.scopes = {} end
    if type(db.healthColorByScope) ~= "table" then db.healthColorByScope = {} end
    if type(db.text) ~= "table" then db.text = {} end
    if type(db.auras) ~= "table" then db.auras = {} end
    if type(db.auras.scopes) ~= "table" then db.auras.scopes = {} end
    if type(db.castbar) ~= "table" then db.castbar = {} end
    if type(db.castbars) ~= "table" then db.castbars = {} end
    if type(db.classBar) ~= "table" then db.classBar = {} end
    if type(db.highlights) ~= "table" then db.highlights = {} end

    return db
end

function Options:GetEnabled()
    return self:GetDB().enabled ~= false
end

function Options:SetEnabled(_, value)
    local db = self:GetDB()
    db.enabled = value == true

    local module = GetModule()
    if module then
        if value == true then
            module:Enable()
        else
            module:Disable()
        end
    end

    NotifyConfigurationChanged()
end

function Options:BuildConfiguration()
    local section = Widgets.NewConfigurationSection(7, "Unit Frames")
    section.args = {
        title = Widgets.TitleWidget(0, "Unit Frames"),
        description = Widgets.Description(1,
            "Standalone oUF unit frames with live previews, party and raid layout control, castbar styling, shared text rules, and scope-based colors."),
        generalGroup = BuildGeneralTab(),
        singles = BuildSinglesTab(),
        groups = BuildGroupsTab(),
        castbar = BuildCastbarTab(),
        colors = BuildColorsTab(),
    }

    return section
end
