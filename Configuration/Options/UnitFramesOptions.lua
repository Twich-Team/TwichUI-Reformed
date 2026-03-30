---@diagnostic disable: undefined-field, inject-field
local TwichRx                          = _G.TwichRx
---@type TwichUI
local T                                = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule              = T:GetModule("Configuration")
local Widgets                          = ConfigurationModule.Widgets
local LibStub                          = _G.LibStub

---@class UnitFramesConfigurationOptions
local Options                          = ConfigurationModule.Options.UnitFrames or {}
ConfigurationModule.Options.UnitFrames = Options

local DEFAULT_SENTINEL                 = "__default"

local POINT_VALUES                     = {
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

local OUTLINE_VALUES                   = {
    OUTLINE = "Outline",
    THICKOUTLINE = "Thick Outline",
    MONOCHROME = "Monochrome",
    MONOCHROMEOUTLINE = "Monochrome Outline",
    MONOCHROMETHICKOUTLINE = "Monochrome Thick Outline",
    NONE = "None",
}

local NAME_FORMAT_VALUES               = {
    full = "Full Name",
    short = "Short Name",
    custom = "Custom Tag",
}

local RESOURCE_FORMAT_VALUES           = {
    percent = "Percent",
    current = "Current Value",
    currentPercent = "Current and Percent",
    missing = "Missing",
    custom = "Custom Tag",
}

local AURA_FILTER_VALUES               = {
    ALL = "All",
    HELPFUL = "Helpful",
    HARMFUL = "Harmful",
    DISPELLABLE = "Dispellable",
    DISPELLABLE_OR_BOSS = "Dispellable or Boss",
}

-- Aura Watcher constants
local INDICATOR_TYPES                  = {
    icons  = "Icon Cluster",
    border = "Border Highlight",
}
local INDICATOR_SOURCES                = {
    group               = "Spell Group",
    HELPFUL             = "Helpful",
    HARMFUL             = "Harmful",
    DISPELLABLE         = "Dispellable",
    DISPELLABLE_OR_BOSS = "Dispellable or Boss",
    ALL                 = "All",
}
local GROW_DIR_VALUES                  = {
    RIGHT = "Right →",
    LEFT  = "← Left",
    UP    = "↑ Up",
    DOWN  = "↓ Down",
}
local MAX_SPELL_GROUPS                 = 8
local MAX_INDICATORS                   = 6
-- Group-key list (g1..g8)
local SPELL_GROUP_KEYS                 = {}
for i = 1, MAX_SPELL_GROUPS do SPELL_GROUP_KEYS[#SPELL_GROUP_KEYS + 1] = "g" .. i end

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

local POWER_COLOR_MODES = {
    custom    = "Custom",
    powertype = "Power Type",
}

local UNIT_POWER_COLOR_MODES = {
    inherit   = "Inherit",
    custom    = "Custom",
    powertype = "Power Type",
}

local ROLE_ICON_CORNER_VALUES = {
    TOPLEFT     = "Top Left",
    TOPRIGHT    = "Top Right",
    BOTTOMLEFT  = "Bottom Left",
    BOTTOMRIGHT = "Bottom Right",
}

local ROLE_ICON_FILTER_VALUES = {
    all      = "All (fallback to DPS)",
    assigned = "Assigned Roles Only",
    nonDps   = "Healers & Tanks",
    healers  = "Healers Only",
    tanks    = "Tanks Only",
}

-- Default tag/justify for info bar text slots (mirrors INFO_BAR_TEXT_DEFAULTS in the engine)
local INFO_BAR_SLOT_DEFAULTS = {
    { tag = "[name]",     justify = "LEFT" },
    { tag = "[perhp<$%]", justify = "CENTER" },
    { tag = "",           justify = "RIGHT" },
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
    powerBackground = { 0.05, 0.06, 0.08, 0.85 },
    powerBorder = { 0.24, 0.26, 0.32, 0.9 },
    cast = { 0.96, 0.76, 0.24, 1 },
    background = { 0.05, 0.06, 0.08, 1 },
    border = { 0.24, 0.26, 0.32, 1 },
    targetHighlight = { 1.0, 0.82, 0.0, 0.9 },
    mouseoverHighlight = { 1.0, 1.0, 1.0, 0.08 },
    shadow = { 0, 0, 0, 0.85 },
    classBar = { 1, 1, 1, 1 },
    classBarBackground = { 0.05, 0.06, 0.08, 0.9 },
    classBarBorder = { 0.24, 0.26, 0.32, 0.9 },
    nameText = { 1, 1, 1, 1 },
    healthText = { 1, 1, 1, 1 },
    powerText = { 1, 1, 1, 1 },
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
    fontName = nil,
    spellFontSize = 11,
    timeFontSize = 10,
    spellPoint = "LEFT",
    spellRelativePoint = "LEFT",
    spellOffsetX = 6,
    spellOffsetY = 0,
    timePoint = "RIGHT",
    timeRelativePoint = "RIGHT",
    timeOffsetX = -6,
    timeOffsetY = 0,
    useCustomColor = false,
}

local EMBEDDED_CASTBAR_DEFAULTS = {
    target = { enabled = true, detached = false, width = 220, height = 12, iconSize = 16, showIcon = true, showText = true, showTimeText = true, fontSize = 9, timeFontSize = 9, yOffset = -2, iconPosition = "outside", iconSide = "left" },
    party  = { enabled = true, detached = false, width = 180, height = 12, iconSize = 16, showIcon = true, showText = true, showTimeText = true, fontSize = 9, timeFontSize = 9, yOffset = -2, iconPosition = "outside", iconSide = "left" },
    raid   = { enabled = true, detached = false, width = 120, height = 12, iconSize = 14, showIcon = true, showText = true, showTimeText = true, fontSize = 8, timeFontSize = 8, yOffset = -2, iconPosition = "outside", iconSide = "left" },
    boss   = { enabled = true, detached = false, width = 220, height = 12, iconSize = 18, showIcon = true, showText = true, showTimeText = true, fontSize = 9, timeFontSize = 9, yOffset = -2, iconPosition = "outside", iconSide = "left" },
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

local function GetDefaultCastbarSpellOffsetX()
    local castbar = (Options:GetDB() or {}).castbar or {}
    local showIcon = castbar.showIcon
    if showIcon == nil then
        showIcon = PLAYER_CASTBAR_DEFAULTS.showIcon
    end

    local iconPosition = castbar.iconPosition or PLAYER_CASTBAR_DEFAULTS.iconPosition
    local iconSide = castbar.iconSide or PLAYER_CASTBAR_DEFAULTS.iconSide
    local iconSize = tonumber(castbar.iconSize) or PLAYER_CASTBAR_DEFAULTS.iconSize or PLAYER_CASTBAR_DEFAULTS.height or
    20
    iconSize = math.max(12, math.min(50, iconSize))

    if showIcon ~= false and iconPosition == "inside" and iconSide ~= "right" then
        return iconSize + 8
    end

    return PLAYER_CASTBAR_DEFAULTS.spellOffsetX or 6
end

local function BuildCastbarTextLayoutGroup(order, name, basePath, prefix, defaults, opts)
    opts = opts or {}
    local title = prefix == "spell" and "Spell" or "Time"
    local pointField = prefix .. "Point"
    local relativePointField = prefix .. "RelativePoint"
    local xField = prefix .. "OffsetX"
    local yField = prefix .. "OffsetY"
    local defaultX = defaults[xField]
    if prefix == "spell" then
        defaultX = GetDefaultCastbarSpellOffsetX
    end

    return Widgets.IGroup(order, name, {
        point = BuildSelect(1, title .. " Anchor", title .. " text anchor point.", ExtendPath(basePath, pointField),
            defaults[pointField], POINT_VALUES, {
                disabled = opts.disabled,
                refreshConfig = true,
            }),
        relativePoint = BuildSelect(2, title .. " Relative", "Relative point on the castbar frame.",
            ExtendPath(basePath, relativePointField), defaults[relativePointField], POINT_VALUES, {
                disabled = opts.disabled,
                refreshConfig = true,
            }),
        offsetX = BuildRange(3, title .. " X", title .. " text horizontal offset.", ExtendPath(basePath, xField),
            defaultX, -240, 240, 1, {
                disabled = opts.disabled,
                refreshConfig = true,
            }),
        offsetY = BuildRange(4, title .. " Y", title .. " text vertical offset.", ExtendPath(basePath, yField),
            defaults[yField], -120, 120, 1, {
                disabled = opts.disabled,
                refreshConfig = true,
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
                nameColor = BuildColor(10, "Name Color", "Name text color.", ExtendPath(basePath, "nameColor"),
                    COLOR_DEFAULTS.nameText, true, { disabled = disabled }),
                healthColor = BuildColor(11, "Health Color", "Health text color.", ExtendPath(basePath, "healthColor"),
                    COLOR_DEFAULTS.healthText, true, { disabled = disabled }),
                powerColor = BuildColor(12, "Power Color", "Power text color.", ExtendPath(basePath, "powerColor"),
                    COLOR_DEFAULTS.powerText, true, { disabled = disabled }),
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
    local function BarModeDisabled()
        return ModuleDisabled(function()
            return GetPathValue(ExtendPath(basePath, "barMode"), auraDefault("barMode", false)) ~= true
        end)
    end

    local genericBarStyle = Widgets.IGroup(17, "Shared Bar Style", {
        barTexture = BuildTextureSelect(1, "Texture",
            "Default status bar texture used for aura bars. Uses the theme texture when set to default.",
            ExtendPath(basePath, "barTexture"), "Use Theme Texture", {
                disabled = BarModeDisabled(),
            }),
        barFontName = BuildFontSelect(2, "Font", "Default font used for aura bar labels and timers.",
            ExtendPath(basePath, "barFontName"), "Use Unit Frames Font", {
                disabled = BarModeDisabled(),
            }),
        barFontSize = BuildRange(3, "Font Size", "Default font size for bar labels and time text. Leave at 0 for auto-size.",
            ExtendPath(basePath, "barFontSize"), auraDefault("barFontSize", 0), 0, 20, 1, {
                disabled = BarModeDisabled(),
            }),
        barColor = BuildColor(4, "Fill Color",
            "Default aura bar fill color (timed auras). Overrides the palette cast color.",
            ExtendPath(basePath, "barColor"), { 0.15, 0.47, 0.87, 0.85 }, true, {
                disabled = BarModeDisabled(),
            }),
        barBackground = BuildColor(5, "Background", "Default aura bar background color override.",
            ExtendPath(basePath, "barBackground"), { 0.04, 0.05, 0.07, 0.95 }, true, {
                disabled = BarModeDisabled(),
            }),
        barBorderColor = BuildColor(6, "Border", "Default aura bar border color override.",
            ExtendPath(basePath, "barBorderColor"), { 0.16, 0.18, 0.24, 0.85 }, true, {
                disabled = BarModeDisabled(),
            }),
        barTextColor = BuildColor(7, "Text Color", "Default text color for bar labels, stacks, and timers.",
            ExtendPath(basePath, "barTextColor"), { 1, 1, 1, 1 }, true, {
                disabled = BarModeDisabled(),
            }),
    })

    local buffBarStyle = Widgets.IGroup(18, "Buff Style", {
        buffBarTexture = BuildTextureSelect(1, "Texture",
            "Optional texture override used only for buff bars.",
            ExtendPath(basePath, "buffBarTexture"), "Use Shared Texture", {
                disabled = BarModeDisabled(),
            }),
        buffBarFontName = BuildFontSelect(2, "Font", "Optional font override used only for buff bars.",
            ExtendPath(basePath, "buffBarFontName"), "Use Shared Font", {
                disabled = BarModeDisabled(),
            }),
        buffBarFontSize = BuildRange(3, "Font Size", "Optional buff bar font size override. Leave at 0 for shared sizing.",
            ExtendPath(basePath, "buffBarFontSize"), auraDefault("buffBarFontSize", 0), 0, 20, 1, {
                disabled = BarModeDisabled(),
            }),
        buffBarColor = BuildColor(4, "Fill Color", "Optional fill color override used only for buff bars.",
            ExtendPath(basePath, "buffBarColor"), { 0.15, 0.47, 0.87, 0.85 }, true, {
                disabled = BarModeDisabled(),
            }),
        buffBarBackground = BuildColor(5, "Background", "Optional background color override used only for buff bars.",
            ExtendPath(basePath, "buffBarBackground"), { 0.04, 0.05, 0.07, 0.95 }, true, {
                disabled = BarModeDisabled(),
            }),
        buffBarBorderColor = BuildColor(6, "Border", "Optional border color override used only for buff bars.",
            ExtendPath(basePath, "buffBarBorderColor"), { 0.16, 0.18, 0.24, 0.85 }, true, {
                disabled = BarModeDisabled(),
            }),
        buffBarTextColor = BuildColor(7, "Text Color", "Optional text color override used only for buff bars.",
            ExtendPath(basePath, "buffBarTextColor"), { 1, 1, 1, 1 }, true, {
                disabled = BarModeDisabled(),
            }),
    })

    local debuffBarStyle = Widgets.IGroup(19, "Debuff Style", {
        debuffBarTexture = BuildTextureSelect(1, "Texture",
            "Optional texture override used only for debuff bars.",
            ExtendPath(basePath, "debuffBarTexture"), "Use Shared Texture", {
                disabled = BarModeDisabled(),
            }),
        debuffBarFontName = BuildFontSelect(2, "Font", "Optional font override used only for debuff bars.",
            ExtendPath(basePath, "debuffBarFontName"), "Use Shared Font", {
                disabled = BarModeDisabled(),
            }),
        debuffBarFontSize = BuildRange(3, "Font Size", "Optional debuff bar font size override. Leave at 0 for shared sizing.",
            ExtendPath(basePath, "debuffBarFontSize"), auraDefault("debuffBarFontSize", 0), 0, 20, 1, {
                disabled = BarModeDisabled(),
            }),
        debuffBarColor = BuildColor(4, "Fill Color", "Optional fill color override used only for debuff bars.",
            ExtendPath(basePath, "debuffBarColor"), { 0.15, 0.47, 0.87, 0.85 }, true, {
                disabled = BarModeDisabled(),
            }),
        debuffBarBackground = BuildColor(5, "Background", "Optional background color override used only for debuff bars.",
            ExtendPath(basePath, "debuffBarBackground"), { 0.04, 0.05, 0.07, 0.95 }, true, {
                disabled = BarModeDisabled(),
            }),
        debuffBarBorderColor = BuildColor(6, "Border", "Optional border color override used only for debuff bars.",
            ExtendPath(basePath, "debuffBarBorderColor"), { 0.16, 0.18, 0.24, 0.85 }, true, {
                disabled = BarModeDisabled(),
            }),
        debuffBarTextColor = BuildColor(7, "Text Color", "Optional text color override used only for debuff bars.",
            ExtendPath(basePath, "debuffBarTextColor"), { 1, 1, 1, 1 }, true, {
                disabled = BarModeDisabled(),
            }),
    })

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
                disabled = BarModeDisabled(),
            }),
        showTime = BuildToggle(10, "Show Time", "Show remaining time on aura bars.",
            ExtendPath(basePath, "showTime"), auraDefault("showTime", true), {
                disabled = BarModeDisabled(),
            }),
        showStacks = BuildToggle(11, "Show Stacks", "Show stack count on aura bars (when > 1).",
            ExtendPath(basePath, "showStacks"), auraDefault("showStacks", true), {
                disabled = BarModeDisabled(),
            }),
        genericBarStyle = genericBarStyle,
        buffBarStyle = buffBarStyle,
        debuffBarStyle = debuffBarStyle,
    })
end

-- ============================================================
-- Aura Watcher: Spell Groups section (global)
-- ============================================================

-- Returns a display-name→key map of spell groups that have a label set.
local function GetSpellGroupValues()
    local db  = Options:GetDB()
    local out = {}
    for _, key in ipairs(SPELL_GROUP_KEYS) do
        local grp = db.spellGroups and db.spellGroups[key]
        local lbl = grp and grp.label
        if lbl and lbl ~= "" then
            out[key] = lbl
        else
            out[key] = "Group " .. key:sub(2) -- "g3" → "Group 3"
        end
    end
    return out
end

local function BuildSpellGroupSlot(order, groupKey)
    local disabled = ModuleDisabled()
    local basePath = { "spellGroups", groupKey }
    local idx      = tonumber(groupKey:sub(2)) or 0
    return Widgets.IGroup(order, "Group " .. idx, {
        label = BuildInput(1, "Name",
            "A short display name for this spell group (shown in indicator dropdowns).",
            ExtendPath(basePath, "label"), "", {
                disabled = disabled,
                width    = "normal",
            }),
        spellIds = BuildInput(2, "Spell IDs",
            "Comma-separated spell IDs to track. Example: 5484, 339, 118",
            ExtendPath(basePath, "spellIds"), "", {
                disabled = disabled,
                width    = "full",
            }),
    })
end

local function BuildSpellGroupsSection(order)
    local args = {}
    for i, key in ipairs(SPELL_GROUP_KEYS) do
        args[key] = BuildSpellGroupSlot(i, key)
    end
    return {
        type        = "group",
        name        = "Spell Groups",
        order       = order,
        inline      = false,
        childGroups = "flow",
        args        = args,
    }
end

-- ============================================================
-- Aura Watcher: per-scope indicator slots
-- ============================================================

local function BuildIndicatorSlot(order, slotIdx, basePath)
    local disabled = ModuleDisabled()
    local path     = ExtendPath(basePath, slotIdx)
    local itype    = function() return GetPathValue(ExtendPath(path, "type"), "icons") end
    local source   = function() return GetPathValue(ExtendPath(path, "source"), "HARMFUL") end
    local isIcons  = function() return itype() == "icons" end
    local isBorder = function() return itype() == "border" end
    local isGroup  = function() return source() == "group" end

    return Widgets.IGroup(order, "Indicator " .. slotIdx, {
        enabled = BuildToggle(1, "Enable",
            "Activate this indicator slot.",
            ExtendPath(path, "enabled"), false, {
                disabled      = disabled,
                refreshConfig = true,
            }),
        itype = BuildSelect(2, "Type",
            "How to display the tracked aura(s).",
            ExtendPath(path, "type"), "icons", INDICATOR_TYPES, {
                disabled      = ModuleDisabled(function()
                    return GetPathValue(ExtendPath(path, "enabled"), false) ~= true
                end),
                refreshConfig = true,
            }),
        source = BuildSelect(3, "Source",
            "What to track: a named Spell Group or a generic aura filter.",
            ExtendPath(path, "source"), "HARMFUL", INDICATOR_SOURCES, {
                disabled = ModuleDisabled(function()
                    return GetPathValue(ExtendPath(path, "enabled"), false) ~= true
                end),
                refreshConfig = true,
            }),
        groupKey = BuildSelect(4, "Spell Group",
            "Which Spell Group to watch (define groups in the Spell Groups tab).",
            ExtendPath(path, "groupKey"), "g1",
            GetSpellGroupValues, {
                disabled = ModuleDisabled(function()
                    return GetPathValue(ExtendPath(path, "enabled"), false) ~= true
                        or source() ~= "group"
                end),
            }),
        onlyMine = BuildToggle(5, "Only Mine",
            "Only show auras applied by you.",
            ExtendPath(path, "onlyMine"), false, {
                disabled = ModuleDisabled(function()
                    return GetPathValue(ExtendPath(path, "enabled"), false) ~= true
                end),
            }),
        iconSettings = Widgets.IGroup(6, "Icon Settings", {
            anchor = BuildSelect(1, "Anchor Point",
                "The corner / edge of the icon cluster anchored to the frame.",
                ExtendPath(path, "anchor"), "TOPLEFT", POINT_VALUES, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
            relativeAnchor = BuildSelect(2, "Frame Point",
                "The matching point on the unit frame.",
                ExtendPath(path, "relativeAnchor"), "TOPLEFT", POINT_VALUES, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
            offsetX = BuildRange(3, "X Offset", "Horizontal offset from the anchor.",
                ExtendPath(path, "offsetX"), 0, -200, 200, 1, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
            offsetY = BuildRange(4, "Y Offset", "Vertical offset from the anchor.",
                ExtendPath(path, "offsetY"), 0, -200, 200, 1, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
            iconSize = BuildRange(5, "Icon Size", "Pixel size of each aura icon.",
                ExtendPath(path, "iconSize"), 18, 8, 40, 1, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
            spacing = BuildRange(6, "Spacing", "Gap between icons.",
                ExtendPath(path, "spacing"), 2, 0, 12, 1, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
            maxCount = BuildRange(7, "Max Count", "Maximum number of icons to show.",
                ExtendPath(path, "maxCount"), 5, 1, 12, 1, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
            growDirection = BuildSelect(8, "Grow Direction",
                "Direction new icons are added in.",
                ExtendPath(path, "growDirection"), "RIGHT", GROW_DIR_VALUES, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isIcons()
                    end),
                }),
        }),
        borderSettings = Widgets.IGroup(7, "Border Settings", {
            borderColor = BuildColor(1, "Color",
                "Border color when the tracked aura is active.",
                ExtendPath(path, "borderColor"), { 1, 0.5, 0, 1 }, true, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isBorder()
                    end),
                }),
            borderWidth = BuildRange(2, "Width", "Border thickness in pixels.",
                ExtendPath(path, "borderWidth"), 2, 1, 8, 1, {
                    disabled = ModuleDisabled(function()
                        return GetPathValue(ExtendPath(path, "enabled"), false) ~= true or not isBorder()
                    end),
                }),
        }),
    })
end

-- Resolve the unit-frame key for the indicator designer from a DB path.
-- indicatorsPath is e.g. { "units", "player", "indicators" } or
-- { "auras", "scopes", "party", "indicators" }
local function DesignerFrameKeyFromPath(indicatorsPath)
    if not indicatorsPath then return "partyMember" end
    if indicatorsPath[1] == "units" then
        return indicatorsPath[2] or "player"
    elseif indicatorsPath[1] == "auras" and indicatorsPath[2] == "scopes" then
        local scope = indicatorsPath[3] or "party"
        -- Convert scope key → frame key used by the engine
        local scopeToKey = { party = "partyMember", raid = "raidMember", tank = "tankMember" }
        return scopeToKey[scope] or (scope .. "Member")
    end
    return "player"
end

local function BuildIndicatorsGroup(order, indicatorsPath)
    -- Do NOT capture UnitFrames at build time — it may not have AWOpenDesigner yet.
    -- Instead, resolve at click time so we always get the fully-initialised module.
    local frameKey = DesignerFrameKeyFromPath(indicatorsPath)
    return {
        type   = "group",
        name   = "Aura Indicators",
        order  = order,
        inline = true,
        args   = {
            desc = {
                type  = "description",
                order = 1,
                name  = "Design per-frame aura indicators using the graphical Aura Watcher Designer. "
                    .. "Assign spells from your spec's catalogue to indicator slots, set anchor "
                    .. "points, icon sizes, grow direction, and more.",
            },
            openDesigner = {
                type  = "execute",
                order = 2,
                name  = "Open Aura Watcher Designer",
                desc  = "Opens the graphical indicator designer for this frame type.",
                func  = function()
                    local UF = T:GetModule("UnitFrames")
                    if UF and UF.AWOpenDesigner then
                        UF:AWOpenDesigner(frameKey)
                    end
                end,
            },
        },
    }
end

local BuildColorScopeTab
local BuildUnitColorTab

-- ---------------------------------------------------------------------------
-- Copy-From helpers
-- These tables hold the currently-selected source key in the AceGUI dropdowns.
-- They are module-local (not persisted) because they are purely transient UI state.
-- ---------------------------------------------------------------------------
local _copyFromSingleSource = {} -- [dstKey] = srcKey
local _copyFromGroupSource  = {} -- [dstKey] = srcKey

local SINGLE_COPY_KEYS      = { "player", "target", "targettarget", "focus", "pet" }
local GROUP_COPY_KEYS       = { "party", "raid", "tank" }

-- Keys inside db.units[unitKey] that should NOT be copied (position / enabled toggle).
local UNIT_SKIP_KEYS        = { enabled = true }
-- Keys inside db.groups[groupKey] that should NOT be copied (enabled toggle; layout
-- is stored separately in db.layout so it is already excluded).
local GROUP_SKIP_KEYS       = { enabled = true }

-- Deep-merge src into dst, skipping nil values.  Creates sub-tables as needed.
local function DeepMerge(dst, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            DeepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

-- Copy all unit appearance settings from srcKey to dstKey (singles).
-- Skips: db.layout (position), db.units[x].enabled.
-- Copies: db.units sub-keys, db.colors.scopes, db.healthColorByScope,
--         db.text (singles share one scope), db.auras (singles share one scope).
local function CopyUnitSettings(srcKey, dstKey)
    local db = Options:GetDB()

    -- Frame settings (size, power, fonts, auras, etc.)
    local srcUnit = (db.units or {})[srcKey] or {}
    db.units = db.units or {}
    db.units[dstKey] = db.units[dstKey] or {}
    for k, v in pairs(srcUnit) do
        if not UNIT_SKIP_KEYS[k] then
            db.units[dstKey][k] = CopyTable(v)
        end
    end

    -- Color scope: singles all share the "singles" scope — no per-unit scope copy needed.
    -- Per-unit health color override lives under db.units[x].healthColor, already copied above.

    CommitChange(true)
end

-- Copy all group appearance settings from srcKey to dstKey (party/raid/tank).
-- Skips: db.layout (position), db.groups[x].enabled.
-- Copies: db.groups sub-keys, db.colors.scopes, db.healthColorByScope,
--         db.text.scopes, db.auras.scopes.
local function CopyGroupSettings(srcKey, dstKey)
    local db = Options:GetDB()

    -- Group frame settings (size, spacing, etc.)
    local srcGroup = (db.groups or {})[srcKey] or {}
    db.groups = db.groups or {}
    db.groups[dstKey] = db.groups[dstKey] or {}
    for k, v in pairs(srcGroup) do
        if not GROUP_SKIP_KEYS[k] then
            db.groups[dstKey][k] = CopyTable(v)
        end
    end

    -- Color scope (health/power/background/border tints)
    db.colors = db.colors or {}
    db.colors.scopes = db.colors.scopes or {}
    if db.colors.scopes[srcKey] then
        db.colors.scopes[dstKey] = CopyTable(db.colors.scopes[srcKey])
    end

    -- Health color mode + custom color
    db.healthColorByScope = db.healthColorByScope or {}
    if db.healthColorByScope[srcKey] then
        db.healthColorByScope[dstKey] = CopyTable(db.healthColorByScope[srcKey])
    end

    -- Text scope
    db.text = db.text or {}
    db.text.scopes = db.text.scopes or {}
    if db.text.scopes[srcKey] then
        db.text.scopes[dstKey] = CopyTable(db.text.scopes[srcKey])
    end

    -- Aura scope
    db.auras = db.auras or {}
    db.auras.scopes = db.auras.scopes or {}
    if db.auras.scopes[srcKey] then
        db.auras.scopes[dstKey] = CopyTable(db.auras.scopes[srcKey])
    end

    CommitChange(true)
end

-- Build the "Copy From" inline group for a single-unit tab.
local function BuildCopyFromSingle(dstKey)
    local sourceValues = {}
    for _, k in ipairs(SINGLE_COPY_KEYS) do
        if k ~= dstKey then
            local labels = {
                player = "Player",
                target = "Target",
                targettarget = "Target of Target",
                focus = "Focus",
                pet = "Pet"
            }
            sourceValues[k] = labels[k] or k
        end
    end

    return Widgets.IGroup(99, "Copy From", {
        source = {
            type     = "select",
            name     = "Source Frame",
            desc     = "Choose which unit frame to copy settings from.",
            order    = 1,
            values   = sourceValues,
            get      = function() return _copyFromSingleSource[dstKey] end,
            set      = function(_, v) _copyFromSingleSource[dstKey] = v end,
            disabled = ModuleDisabled(),
        },
        apply = BuildExecute(2, "Copy Settings",
            "Copy all appearance settings from the selected source frame. Position is never overwritten.",
            function()
                local src = _copyFromSingleSource[dstKey]
                if not src then return end
                CopyUnitSettings(src, dstKey)
                _copyFromSingleSource[dstKey] = nil
            end, {
                disabled = ModuleDisabled(function()
                    return _copyFromSingleSource[dstKey] == nil
                end),
            }),
    })
end

-- Build the "Copy From" inline group for a group (party/raid/tank) tab.
local function BuildCopyFromGroup(dstKey)
    local sourceValues = {}
    local labels = { party = "Party", raid = "Raid", tank = "Tank" }
    for _, k in ipairs(GROUP_COPY_KEYS) do
        if k ~= dstKey then
            sourceValues[k] = labels[k] or k
        end
    end

    return Widgets.IGroup(99, "Copy From", {
        source = {
            type     = "select",
            name     = "Source Group",
            desc     = "Choose which group frame to copy settings from.",
            order    = 1,
            values   = sourceValues,
            get      = function() return _copyFromGroupSource[dstKey] end,
            set      = function(_, v) _copyFromGroupSource[dstKey] = v end,
            disabled = ModuleDisabled(),
        },
        apply = BuildExecute(2, "Copy Settings",
            "Copy all appearance settings from the selected source group. Position is never overwritten.",
            function()
                local src = _copyFromGroupSource[dstKey]
                if not src then return end
                CopyGroupSettings(src, dstKey)
                _copyFromGroupSource[dstKey] = nil
            end, {
                disabled = ModuleDisabled(function()
                    return _copyFromGroupSource[dstKey] == nil
                end),
            }),
    })
end

--- Builds an inline Role Icon IGroup for a given base path (units/X/roleIcon or groups/X/roleIcon).
local function BuildRoleIconGroup(order, basePath, defaultEnabled)
    defaultEnabled = defaultEnabled == true
    local disabled = ModuleDisabled()
    local isRoleOff = ModuleDisabled(function()
        return GetPathValue(ExtendPath(basePath, "enabled"), defaultEnabled) ~= true
    end)
    return Widgets.IGroup(order, "Role Icon", {
        enabled = BuildToggle(1, "Show Role Icon",
            "Display the player's dungeon role icon (tank, healer, dps) directly on this frame.",
            ExtendPath(basePath, "enabled"), defaultEnabled, { disabled = disabled, refreshConfig = true }),
        filter = BuildSelect(2, "Show For",
            "Which roles will have the icon displayed.",
            ExtendPath(basePath, "filter"), "all", ROLE_ICON_FILTER_VALUES, { disabled = isRoleOff }),
        corner = BuildSelect(3, "Corner",
            "Which corner of the frame to place the icon in.",
            ExtendPath(basePath, "corner"), "TOPRIGHT", ROLE_ICON_CORNER_VALUES, { disabled = isRoleOff }),
        size = BuildRange(4, "Size", "Role icon size in pixels.",
            ExtendPath(basePath, "size"), 18, 8, 40, 1, { disabled = isRoleOff }),
        insetX = BuildRange(5, "X Inset", "Horizontal inset from the corner edge.",
            ExtendPath(basePath, "insetX"), 2, 0, 20, 1, { disabled = isRoleOff }),
        insetY = BuildRange(6, "Y Inset", "Vertical inset from the corner edge.",
            ExtendPath(basePath, "insetY"), 2, 0, 20, 1, { disabled = isRoleOff }),
    })
end

--- Builds a full Info Bar tab for a given base path (units/X/infoBar or groups/X/infoBar).
local function BuildInfoBarTab(order, basePath)
    local disabled    = ModuleDisabled()
    local isBarOff    = ModuleDisabled(function()
        return GetPathValue(ExtendPath(basePath, "enabled"), false) ~= true
    end)
    local isShadowOff = ModuleDisabled(function()
        return isBarOff()
            or GetPathValue(ExtendPath(basePath, "shadowEnabled"), false) ~= true
    end)

    local function BuildTextSlot(slotOrder, slotIndex)
        local def       = INFO_BAR_SLOT_DEFAULTS[slotIndex] or { tag = "", justify = "CENTER" }
        local slotPath  = ExtendPath(basePath, "text" .. slotIndex)
        local isClassOn = ModuleDisabled(function()
            return isBarOff()
                or GetPathValue(ExtendPath(slotPath, "useClassColor"), false) == true
        end)
        return Widgets.IGroup(slotOrder, "Text " .. slotIndex, {
            tag = BuildInput(1, "Tag",
                "oUF tag string for this slot. Leave blank to hide the slot.",
                ExtendPath(slotPath, "tag"), def.tag,
                { disabled = isBarOff, width = "full" }),
            justify = BuildSelect(2, "Alignment", "Text alignment.",
                ExtendPath(slotPath, "justify"), def.justify,
                { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
                { disabled = isBarOff }),
            fontSize = BuildRange(3, "Size", "Font size for this slot.",
                ExtendPath(slotPath, "fontSize"), 9, 6, 20, 1, { disabled = isBarOff }),
            useClassColor = BuildToggle(4, "Class Color",
                "Use the unit's class color for this text slot instead of a fixed color.",
                ExtendPath(slotPath, "useClassColor"), false,
                { disabled = isBarOff, refreshConfig = true }),
            color = BuildColor(5, "Color", "Text color (overridden when Class Color is on).",
                ExtendPath(slotPath, "color"), { 1, 1, 1, 1 }, true, { disabled = isClassOn }),
        })
    end

    return {
        type  = "group",
        name  = "Info Bar",
        order = order,
        args  = {
            settings = Widgets.IGroup(1, "Settings", {
                enabled = BuildToggle(1, "Enable",
                    "Extend the unit frame with an extra info row at the bottom. Defaults to off.",
                    ExtendPath(basePath, "enabled"), false,
                    { disabled = disabled, refreshConfig = true }),
                height = BuildRange(2, "Height", "Height of the info bar in pixels.",
                    ExtendPath(basePath, "height"), 18, 8, 40, 1, { disabled = isBarOff }),
                numTexts = BuildSelect(3, "Text Slots",
                    "How many text elements to display across the bar (1–3).",
                    ExtendPath(basePath, "numTexts"), 3,
                    { [1] = "1", [2] = "2", [3] = "3" },
                    { disabled = isBarOff }),
                bgColor = BuildColor(4, "Background", "Info bar background color.",
                    ExtendPath(basePath, "bgColor"), { 0.05, 0.06, 0.08, 0.92 }, true,
                    { disabled = isBarOff }),
                texture = BuildTextureSelect(5, "Texture",
                    "Optional status-bar texture drawn over the background.",
                    ExtendPath(basePath, "texture"), "None", { disabled = isBarOff }),
                borderSize = BuildRange(6, "Border Size",
                    "Width of the info bar border in pixels (0 = no border).",
                    ExtendPath(basePath, "borderSize"), 1, 0, 3, 1, { disabled = isBarOff }),
                borderColor = BuildColor(7, "Border Color", "Info bar border color.",
                    ExtendPath(basePath, "borderColor"), { 0.24, 0.26, 0.32, 0.9 }, true,
                    { disabled = isBarOff }),
                fontName = BuildFontSelect(8, "Font",
                    "Override the font for all info bar text slots (nil = inherit from unit text config).",
                    ExtendPath(basePath, "fontName"), "Inherit", { disabled = isBarOff }),
                outlineMode = BuildSelect(9, "Outline", "Font outline mode for info bar text slots.",
                    ExtendPath(basePath, "outlineMode"), "OUTLINE", OUTLINE_VALUES,
                    { disabled = isBarOff }),
                shadowEnabled = BuildToggle(10, "Shadow",
                    "Enable drop shadow on info bar text slots.",
                    ExtendPath(basePath, "shadowEnabled"), false,
                    { disabled = isBarOff, refreshConfig = true }),
                shadowColor = BuildColor(11, "Shadow Color", "Text shadow color.",
                    ExtendPath(basePath, "shadowColor"), { 0, 0, 0, 0.85 }, true,
                    { disabled = isShadowOff }),
                shadowOffsetX = BuildRange(12, "Shadow X",
                    "Horizontal shadow offset in pixels.",
                    ExtendPath(basePath, "shadowOffsetX"), 1, -8, 8, 1, { disabled = isShadowOff }),
                shadowOffsetY = BuildRange(13, "Shadow Y",
                    "Vertical shadow offset in pixels.",
                    ExtendPath(basePath, "shadowOffsetY"), -1, -8, 8, 1, { disabled = isShadowOff }),
            }),
            text1 = BuildTextSlot(2, 1),
            text2 = BuildTextSlot(3, 2),
            text3 = BuildTextSlot(4, 3),
        },
    }
end

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
                    highlights = Widgets.IGroup(3, "Highlights", {
                        showTarget = BuildToggle(1, "Target Highlight",
                            "Show the target highlight on this frame. Disable to hide it even when globally on.",
                            ExtendPath(basePath, "highlights", "showTarget"), true, { disabled = disabled }),
                        showMouseover = BuildToggle(2, "Mouseover Highlight",
                            "Show the mouseover highlight on this frame. Disable to hide it even when globally on.",
                            ExtendPath(basePath, "highlights", "showMouseover"), true, { disabled = disabled }),
                    }),
                    roleIcon = BuildRoleIconGroup(4, ExtendPath(basePath, "roleIcon"), false),
                    copyFrom = BuildCopyFromSingle(unitKey),
                },
            },
            layout = BuildLayoutGroup(2, "Layout", unitKey, layoutDefaults, {
                disabled = disabled,
            }),
            text = BuildTextGroup(3, "Text", textPath, unitKey),
            auras = BuildAuraGroup(4, "Auras", auraPath, unitKey),
            watchers = BuildIndicatorsGroup(5, { "units", unitKey, "indicators" }),
            colors = BuildUnitColorTab(6, unitKey),
            infoBar = BuildInfoBarTab(7, ExtendPath(basePath, "infoBar")),
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
        local isWidthDisabled = ModuleDisabled(function()
            return GetPathValue({ "classBar", "enabled" }, true) ~= true
                or GetPathValue({ "classBar", "matchFrameWidth" }, false) == true
        end)
        tab.args.classBar = {
            type = "group",
            name = "Class Bar",
            order = 6,
            args = Widgets.IGroup(1, "Class Bar", {
                enabled = BuildToggle(1, "Enable", "Show the player class resource bar.",
                    { "classBar", "enabled" }, true, { disabled = isBarDisabled, refreshConfig = true }),
                matchFrameWidth = BuildToggle(2, "Match Frame Width",
                    "Automatically match the class bar width to the player frame width.",
                    { "classBar", "matchFrameWidth" }, false, { disabled = isPowerOn, refreshConfig = true }),
                width = BuildRange(3, "Width", "Class bar width.",
                    { "classBar", "width" }, 260, 40, 600, 1, { disabled = isWidthDisabled }),
                height = BuildRange(4, "Height", "Class bar height.",
                    { "classBar", "height" }, 10, 4, 40, 1, { disabled = isPowerOn }),
                spacing = BuildRange(5, "Segment Gap",
                    "Pixel gap between each class resource segment (e.g. Holy Power ticks).",
                    { "classBar", "spacing" }, 2, 0, 40, 1, { disabled = isPowerOn }),
                point = BuildSelect(6, "Anchor", "Class bar anchor point.",
                    { "classBar", "point" }, "TOPLEFT", POINT_VALUES, { disabled = isPowerOn }),
                relativePoint = BuildSelect(7, "Relative Point", "Class bar relative anchor point.",
                    { "classBar", "relativePoint" }, "BOTTOMLEFT", POINT_VALUES, { disabled = isPowerOn }),
                xOffset = BuildRange(8, "X Offset", "Class bar horizontal offset.",
                    { "classBar", "xOffset" }, 0, -240, 240, 1, { disabled = isPowerOn }),
                yOffset = BuildRange(9, "Y Offset", "Class bar vertical offset.",
                    { "classBar", "yOffset" }, -2, -240, 240, 1, { disabled = isPowerOn }),
                useCustomColor = BuildToggle(10, "Custom Bar Color",
                    "Use a specific color instead of the class resource color.",
                    { "classBar", "useCustomColor" }, false, { disabled = isPowerOn, refreshConfig = true }),
                color = BuildColor(11, "Bar Color", "Custom class bar color.",
                    { "classBar", "color" }, COLOR_DEFAULTS.classBar, true, { disabled = isColorDisabled }),
                useCustomBackground = BuildToggle(12, "Custom Background",
                    "Use a custom background color for the class bar segments.",
                    { "classBar", "useCustomBackground" }, false, { disabled = isPowerOn, refreshConfig = true }),
                backgroundColor = BuildColor(13, "Background Color", "Class bar segment background color.",
                    { "classBar", "backgroundColor" }, COLOR_DEFAULTS.classBarBackground, true,
                    { disabled = isBGDisabled }),
                useCustomBorder = BuildToggle(14, "Custom Border",
                    "Use a custom border color for the class bar segments.",
                    { "classBar", "useCustomBorder" }, false, { disabled = isPowerOn, refreshConfig = true }),
                borderColor = BuildColor(15, "Border Color", "Class bar segment border color.",
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

    local memberKey = groupKey .. "Member"
    frameTab.args.highlights = Widgets.IGroup(3, "Highlights", {
        showTarget = BuildToggle(1, "Target Highlight",
            "Show the target highlight on group member frames. Disable to hide it even when globally on.",
            { "units", memberKey, "highlights", "showTarget" }, true, { disabled = disabled }),
        showMouseover = BuildToggle(2, "Mouseover Highlight",
            "Show the mouseover highlight on group member frames. Disable to hide it even when globally on.",
            { "units", memberKey, "highlights", "showMouseover" }, true, { disabled = disabled }),
    })
    -- Healer-only power bar is meaningful for party and raid — not for tank
    if groupKey == "party" or groupKey == "raid" then
        frameTab.args.power = Widgets.IGroup(4, "Power Bar", {
            healerOnlyPower = BuildToggle(1, "Healer Only",
                "When enabled, only show the power bar for frames whose unit has the Healer role assigned. All other roles will have the power bar hidden. Enabled by default — disable to show power for all roles.",
                ExtendPath(basePath, "healerOnlyPower"), true, {
                    disabled = disabled,
                }),
        })
    end
    frameTab.args.copyFrom = BuildCopyFromGroup(groupKey)

    local colorsTab = BuildColorScopeTab(groupKey, "Colors")
    colorsTab.order = 5

    return {
        type = "group",
        name = label,
        order = 1,
        childGroups = "tab",
        args = {
            frame    = frameTab,
            layout   = BuildLayoutGroup(2, "Layout", groupKey, layoutDefaults, {
                disabled = disabled,
            }),
            text     = BuildTextGroup(3, "Text", textPath, groupKey .. "Member"),
            auras    = BuildAuraGroup(4, "Auras", auraPath, groupKey .. "Member"),
            watchers = BuildIndicatorsGroup(5, { "auras", "scopes", groupKey, "indicators" }),
            colors   = colorsTab,
            roleIcon = BuildRoleIconGroup(6, ExtendPath(basePath, "roleIcon"), groupKey == "party"),
            infoBar  = BuildInfoBarTab(7, ExtendPath(basePath, "infoBar")),
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
                    highlights = Widgets.IGroup(2, "Highlights", {
                        showTarget = BuildToggle(1, "Target Highlight",
                            "Show the target highlight on boss frames. Disable to hide it even when globally on.",
                            { "units", "boss", "highlights", "showTarget" }, true, { disabled = disabled }),
                        showMouseover = BuildToggle(2, "Mouseover Highlight",
                            "Show the mouseover highlight on boss frames. Disable to hide it even when globally on.",
                            { "units", "boss", "highlights", "showMouseover" }, true, { disabled = disabled }),
                    }),
                },
            },
            layout = BuildLayoutGroup(2, "Layout", "boss", GROUP_LAYOUT_DEFAULTS.boss, {
                disabled = disabled,
            }),
            text = BuildTextGroup(3, "Text", { "text", "scopes", "boss" }, "boss"),
            auras = BuildAuraGroup(4, "Auras", { "auras", "scopes", "boss" }, "boss"),
            watchers = BuildIndicatorsGroup(5, { "units", "boss", "indicators" }),
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
                iconPosition = BuildSelect(13, "Icon Position",
                    "Place the icon outside the bar frame or embedded inside it.",
                    ExtendPath(path, "iconPosition"), defaults.iconPosition or "outside",
                    { outside = "Outside Bar", inside = "Inside Bar" }, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "showIcon"), defaults.showIcon) ~= true
                        end),
                    }),
                iconSide = BuildSelect(14, "Icon Side",
                    "Which side of the castbar the icon appears on.",
                    ExtendPath(path, "iconSide"), defaults.iconSide or "left",
                    { left = "Left", right = "Right" }, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(ExtendPath(path, "showIcon"), defaults.showIcon) ~= true
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
    local powerModePath = ExtendPath(colorPath, "powerColorMode")
    local disabled = ModuleDisabled()
    local function defaultMode()
        return GetPathValue({ "useClassColor" }, false) == true and "class" or "theme"
    end
    local function defaultPowerMode()
        return GetPathValue({ "powerColorMode" }, "custom")
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
                powerMode = BuildSelect(0.5, "Power Color Mode",
                    "How the power bar colour is determined for this scope.\n\nCustom: use the colour below.\nPower Type: automatically match the WoW power type colour (Mana=blue, Rage=red, etc.).",
                    powerModePath, defaultPowerMode, POWER_COLOR_MODES, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                power = BuildColor(1, "Power", "Power bar color (used when mode is Custom).",
                    ExtendPath(colorPath, "power"), COLOR_DEFAULTS.power,
                    true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(powerModePath, defaultPowerMode()) == "powertype"
                        end),
                    }),
                powerBackground = BuildColor(2, "Power Background", "Power bar empty area tint.",
                    ExtendPath(colorPath, "powerBackground"), COLOR_DEFAULTS.powerBackground, true, {
                        disabled = disabled,
                    }),
                powerBorder = BuildColor(3, "Power Border", "Power bar border tint.",
                    ExtendPath(colorPath, "powerBorder"), COLOR_DEFAULTS.powerBorder, true, {
                        disabled = disabled,
                    }),
                cast = BuildColor(4, "Cast", "Castbar color.", ExtendPath(colorPath, "cast"), COLOR_DEFAULTS.cast, true,
                    {
                        disabled = disabled,
                    }),
                background = BuildColor(5, "Background", "Frame background tint.", ExtendPath(colorPath, "background"),
                    COLOR_DEFAULTS.background, true, {
                        disabled = disabled,
                    }),
                border = BuildColor(6, "Border", "Frame border tint.", ExtendPath(colorPath, "border"),
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
    local powerModePath = ExtendPath(colorPath, "powerColorMode")
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
                powerMode = BuildSelect(0.5, "Power Color Mode",
                    "How this unit's power bar colour is determined.\n\nInherit: use the scope or global rule.\nCustom: use the colour below.\nPower Type: automatically match the WoW power type colour (Mana=blue, Rage=red, etc.).",
                    powerModePath, "inherit", UNIT_POWER_COLOR_MODES, {
                        disabled = disabled,
                        refreshConfig = true,
                    }),
                power = BuildColor(1, "Power", "Override the power bar color for this unit (used when mode is Custom).",
                    ExtendPath(colorPath, "power"), COLOR_DEFAULTS.power, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue(powerModePath, "inherit") == "powertype"
                        end),
                    }),
                powerBackground = BuildColor(2, "Power Background",
                    "Override the power bar empty area tint for this unit.",
                    ExtendPath(colorPath, "powerBackground"), COLOR_DEFAULTS.powerBackground, true, {
                        disabled = disabled,
                    }),
                powerBorder = BuildColor(3, "Power Border", "Override the power bar border tint for this unit.",
                    ExtendPath(colorPath, "powerBorder"), COLOR_DEFAULTS.powerBorder, true, {
                        disabled = disabled,
                    }),
                cast = BuildColor(4, "Cast", "Override the castbar color for this unit.", ExtendPath(colorPath, "cast"),
                    COLOR_DEFAULTS.cast, true, {
                        disabled = disabled,
                    }),
                background = BuildColor(5, "Background", "Override the frame background tint for this unit.",
                    ExtendPath(colorPath, "background"), COLOR_DEFAULTS.background, true, {
                        disabled = disabled,
                    }),
                border = BuildColor(6, "Border", "Override the frame border tint for this unit.",
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
                bgTexture = BuildTextureSelect(8, "Background Texture",
                    "Texture used for the empty (lost health) portion of health bars. Falls back to the bar texture when unset.",
                    { "bgTexture" }, "Use bar texture"),
                powerTexture = BuildTextureSelect(9, "Power Bar Texture",
                    "Optional texture override for the power bar fill. Falls back to the global bar texture when unset.",
                    { "powerTexture" }, "Use bar texture"),
                powerBgTexture = BuildTextureSelect(10, "Power Background Texture",
                    "Texture for the empty portion of power bars. Falls back to the background texture when unset.",
                    { "powerBgTexture" }, "Use background texture"),
                smoothBars = BuildToggle(11, "Smooth Bars", "Enable value interpolation for health, power, and castbars.",
                    { "smoothBars" }, db.smoothBars ~= false),
                showHealthText = BuildToggle(12, "Show Health Text", "Show health text tags on frames.",
                    { "showHealthText" }, db.showHealthText ~= false),
                showPowerText = BuildToggle(13, "Show Power Text", "Show power text tags on frames.", { "showPowerText" },
                    db.showPowerText ~= false),
                useClassColor = BuildToggle(14, "Use Class Color",
                    "Use class color for health bars when a scope does not override it.", { "useClassColor" },
                    db.useClassColor == true),
            }),
            sharedText = BuildTextGroup(2, "Shared Text Defaults", { "text" }, "__root"),
            highlights = Widgets.IGroup(3, "Highlights", {
                showTarget = BuildToggle(1, "Target Highlight", "Highlight the current target frame.",
                    { "highlights", "showTarget" }, true, { refreshConfig = true }),
                targetMode = BuildSelect(2, "Style", "Sharp border or additive glow around the target.",
                    { "highlights", "targetMode" }, "border", { border = "Border", glow = "Glow" }, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "highlights", "showTarget" }, true) ~= true
                        end),
                        refreshConfig = true,
                    }),
                targetWidth = BuildRange(3, "Width", "Border thickness or glow spread in pixels.",
                    { "highlights", "targetWidth" }, 2, 1, 12, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "highlights", "showTarget" }, true) ~= true
                        end),
                    }),
                targetColor = BuildColor(4, "Target Color", "Color for the target highlight.",
                    { "highlights", "targetColor" }, COLOR_DEFAULTS.targetHighlight, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "highlights", "showTarget" }, true) ~= true
                        end),
                    }),
                showMouseover = BuildToggle(5, "Mouseover Highlight", "Subtly highlight frames on hover.",
                    { "highlights", "showMouseover" }, true),
                mouseoverColor = BuildColor(6, "Mouseover Color", "Fill tint for the mouseover highlight.",
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
                fontName = BuildFontSelect(8, "Font", "Standalone castbar font override.",
                    { "castbar", "fontName" }, "Use player frame font", {
                        refreshConfig = true,
                    }),
                spellFontSize = BuildRange(9, "Spell Size", "Standalone castbar spell font size.",
                    { "castbar", "spellFontSize" }, PLAYER_CASTBAR_DEFAULTS.spellFontSize, 6, 24, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "showSpellText" }, PLAYER_CASTBAR_DEFAULTS.showSpellText) ~=
                                true
                        end),
                        refreshConfig = true,
                    }),
                timeFontSize = BuildRange(10, "Time Size", "Standalone castbar time font size.",
                    { "castbar", "timeFontSize" }, PLAYER_CASTBAR_DEFAULTS.timeFontSize, 6, 24, 1, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "showTimeText" }, PLAYER_CASTBAR_DEFAULTS.showTimeText) ~=
                                true
                        end),
                        refreshConfig = true,
                    }),
                texture = BuildTextureSelect(11, "Texture", "Optional texture override for the standalone castbar.",
                    { "castbar", "texture" }, "Use Unit Frames texture"),
                useCustomColor = BuildToggle(12, "Custom Color", "Use a dedicated player castbar color.",
                    { "castbar", "useCustomColor" }, PLAYER_CASTBAR_DEFAULTS.useCustomColor, {
                        refreshConfig = true,
                    }),
                color = BuildColor(13, "Castbar Color", "Dedicated player castbar color.", { "castbar", "color" },
                    COLOR_DEFAULTS.cast, true, {
                        disabled = ModuleDisabled(function()
                            return GetPathValue({ "castbar", "useCustomColor" }, PLAYER_CASTBAR_DEFAULTS.useCustomColor) ~=
                                true
                        end),
                    }),
                masqueEnabled = BuildToggle(14, "Masque Skinning",
                    "Enable Masque skinning for the castbar icon button. Requires the Masque addon to be installed. Disabled by default.",
                    { "castbar", "masqueEnabled" }, false, { refreshConfig = true }),
            }),
            textSpell = BuildCastbarTextLayoutGroup(3, "Spell Text", { "castbar" }, "spell", PLAYER_CASTBAR_DEFAULTS, {
                disabled = ModuleDisabled(function()
                    return GetPathValue({ "castbar", "showSpellText" }, PLAYER_CASTBAR_DEFAULTS.showSpellText) ~= true
                end),
            }),
            textTime = BuildCastbarTextLayoutGroup(4, "Time Text", { "castbar" }, "time", PLAYER_CASTBAR_DEFAULTS, {
                disabled = ModuleDisabled(function()
                    return GetPathValue({ "castbar", "showTimeText" }, PLAYER_CASTBAR_DEFAULTS.showTimeText) ~= true
                end),
            }),
            layout = BuildLayoutGroup(5, "Layout", "castbar", SINGLE_LAYOUT_DEFAULTS.castbar, {
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
                powerMode = BuildSelect(1.5, "Power Color Mode",
                    "How the power bar colour is determined globally.\n\nCustom: use the colour below.\nPower Type: automatically match the WoW power type colour (Mana=blue, Rage=red, Energy=yellow, etc.).",
                    { "powerColorMode" }, "custom", POWER_COLOR_MODES, {
                        refreshConfig = true,
                    }),
                power = BuildColor(2, "Power", "Fallback power color (used when mode is Custom).",
                    { "colors", "power" }, COLOR_DEFAULTS.power, true, {
                        disabled = function()
                            return GetPathValue({ "powerColorMode" }, "custom") == "powertype"
                        end,
                    }),
                cast = BuildColor(3, "Cast", "Fallback castbar color.", { "colors", "cast" }, COLOR_DEFAULTS.cast, true),
                background = BuildColor(4, "Background", "Fallback frame background tint.", { "colors", "background" },
                    COLOR_DEFAULTS.background, true),
                border = BuildColor(5, "Border", "Fallback frame border tint.", { "colors", "border" },
                    COLOR_DEFAULTS.border, true),
            }),
            powerTypeOverrides = Widgets.IGroup(2, "Power Type Colors", {
                desc          = Widgets.Description(0,
                    "Override the default WoW color for each power type. These take effect when Power Color Mode is set to \"Power Type\"."),
                mana          = BuildColor(1, "Mana", "Override color for Mana.", { "powerTypeColors", "MANA" },
                    { 0.0, 0.44, 1.0, 1 }, false, { refreshConfig = true }),
                rage          = BuildColor(2, "Rage", "Override color for Rage.", { "powerTypeColors", "RAGE" },
                    { 1.0, 0.0, 0.0, 1 }, false, { refreshConfig = true }),
                focus         = BuildColor(3, "Focus", "Override color for Focus.", { "powerTypeColors", "FOCUS" },
                    { 1.0, 0.55, 0.0, 1 }, false, { refreshConfig = true }),
                energy        = BuildColor(4, "Energy", "Override color for Energy.", { "powerTypeColors", "ENERGY" },
                    { 1.0, 1.0, 0.0, 1 }, false, { refreshConfig = true }),
                runicPower    = BuildColor(5, "Runic Power", "Override color for Runic Power.",
                    { "powerTypeColors", "RUNIC_POWER" }, { 0.0, 0.82, 1.0, 1 }, false, { refreshConfig = true }),
                lunarPower    = BuildColor(6, "Lunar Power", "Override color for Lunar Power.",
                    { "powerTypeColors", "LUNAR_POWER" }, { 0.3, 0.52, 0.9, 1 }, false, { refreshConfig = true }),
                holyPower     = BuildColor(7, "Holy Power", "Override color for Holy Power.",
                    { "powerTypeColors", "HOLY_POWER" }, { 0.95, 0.9, 0.6, 1 }, false, { refreshConfig = true }),
                fury          = BuildColor(8, "Fury", "Override color for Fury.", { "powerTypeColors", "FURY" },
                    { 0.79, 0.26, 0.99, 1 }, false, { refreshConfig = true }),
                pain          = BuildColor(9, "Pain", "Override color for Pain.", { "powerTypeColors", "PAIN" },
                    { 1.0, 0.61, 0.2, 1 }, false, { refreshConfig = true }),
                maelstrom     = BuildColor(10, "Maelstrom", "Override color for Maelstrom.",
                    { "powerTypeColors", "MAELSTROM" }, { 0.0, 0.5, 1.0, 1 }, false, { refreshConfig = true }),
                chi           = BuildColor(11, "Chi", "Override color for Chi.", { "powerTypeColors", "CHI" },
                    { 0.71, 1.0, 0.92, 1 }, false, { refreshConfig = true }),
                insanity      = BuildColor(12, "Insanity", "Override color for Insanity.",
                    { "powerTypeColors", "INSANITY" }, { 0.4, 0.0, 0.8, 1 }, false, { refreshConfig = true }),
                arcaneCharges = BuildColor(13, "Arcane Charges", "Override color for Arcane Charges.",
                    { "powerTypeColors", "ARCANE_CHARGES" }, { 0.19, 0.51, 1.0, 1 }, false, { refreshConfig = true }),
                comboPoints   = BuildColor(14, "Combo Points", "Override color for Combo Points.",
                    { "powerTypeColors", "COMBO_POINTS" }, { 1.0, 0.82, 0.0, 1 }, false, { refreshConfig = true }),
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
    if type(db.powerTypeColors) ~= "table" then db.powerTypeColors = {} end

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
        title        = Widgets.TitleWidget(0, "Unit Frames"),
        description  = Widgets.Description(1,
            "Standalone oUF unit frames with live previews, party and raid layout control, castbar styling, shared text rules, and scope-based colors."),
        generalGroup = BuildGeneralTab(),
        spellGroups  = BuildSpellGroupsSection(5),
        singles      = BuildSinglesTab(),
        groups       = BuildGroupsTab(),
        castbar      = BuildCastbarTab(),
        colors       = BuildColorsTab(),
    }

    return section
end
