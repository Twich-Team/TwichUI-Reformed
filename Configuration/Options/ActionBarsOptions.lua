---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class ActionBarsConfigurationOptions
local Options = ConfigurationModule.Options.ActionBars or {}
ConfigurationModule.Options.ActionBars = Options

local LSM = (T.Libs and T.Libs.LSM) or (_G.LibStub and _G.LibStub("LibSharedMedia-3.0", true))

local ROOT_DEFAULTS = {
    enabled = true,
    debugEnabled = false,
    lockBars = true,
    useMasque = false,
    buttonSpacing = 4,
    showGrid = true,
    textFont = "__default",
    fontOutline = "NONE",
    textShadow = true,
    hotkeyFontSize = 11,
    countFontSize = 11,
    macroFontSize = 9,
    textColor = { 0.92, 0.94, 0.96 },
    showHotkeys = true,
    showCounts = true,
    showMacroNames = false,
    showCooldownText = true,
    showCooldownSwipe = true,
    failedActionFeedback = true,
    failedActionDuration = 0.45,
    failedActionColor = { 0.93, 0.22, 0.20 },
    procGlowStyle = "pixel",
    procGlowUseThemeColor = true,
    procGlowColor = { 0.96, 0.76, 0.24 },
}

local SIMPLE_VISIBILITY_RULES = {
    { key = "combat",    label = "Combat",               condition = "combat" },
    { key = "petbattle", label = "Pet Battle",           condition = "petbattle" },
    { key = "skyriding", label = "Skyriding / Override", condition = "overridebar" },
    { key = "vehicle",   label = "Vehicle",              condition = "vehicleui" },
    { key = "possess",   label = "Possess",              condition = "possessbar" },
    { key = "pet",       label = "Pet",                  condition = "pet" },
    { key = "stance",    label = "Stance",               condition = "shapeshift" },
}

local BAR_DEFAULTS = {
    bar1 = {
        enabled = true,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 36,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 42,
    },
    bar2 = {
        enabled = true,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 34,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 84,
    },
    bar3 = {
        enabled = true,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 34,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 124,
    },
    bar4 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 1,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "RIGHT",
        relativePoint = "RIGHT",
        x = -46,
        y = 6,
    },
    bar5 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 1,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "RIGHT",
        relativePoint = "RIGHT",
        x = -88,
        y = 6,
    },
    bar6 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 164,
    },
    bar7 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 202,
    },
    bar8 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 240,
    },
    bar9 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 278,
    },
    bar10 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 316,
    },
    bar11 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 354,
    },
    bar12 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 392,
    },
    bar13 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 430,
    },
    bar14 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 468,
    },
    bar15 = {
        enabled = false,
        buttonCount = 12,
        buttonsPerRow = 12,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 506,
    },
    extraAction = {
        enabled = true,
        buttonCount = 1,
        buttonsPerRow = 1,
        buttonSize = 52,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[extrabar] show; hide",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = -150,
        y = 300,
    },
    vehicleExit = {
        enabled = true,
        buttonCount = 1,
        buttonsPerRow = 1,
        buttonSize = 32,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[vehicleui] show; hide",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 150,
        y = 300,
    },
    pet = {
        enabled = true,
        buttonCount = 10,
        buttonsPerRow = 10,
        buttonSize = 30,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showBorder = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle][vehicleui][overridebar] hide; [pet] show; hide",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 278,
    },
    stance = {
        enabled = true,
        buttonCount = 10,
        buttonsPerRow = 10,
        buttonSize = 30,
        scale = 1,
        alpha = 1,
        mouseover = false,
        backdrop = true,
        showAccent = true,
        showCooldownSwipe = true,
        simpleVisibilityMode = "raw",
        simpleVisibility = {},
        visibility = "[petbattle] hide; show",
        point = "BOTTOM",
        relativePoint = "BOTTOM",
        x = 0,
        y = 318,
    },
}

local BAR_ORDER = {
    { key = "bar1",        label = "Bar 1" },
    { key = "bar2",        label = "Bar 2" },
    { key = "bar3",        label = "Bar 3" },
    { key = "bar4",        label = "Bar 4" },
    { key = "bar5",        label = "Bar 5" },
    { key = "bar6",        label = "Bar 6" },
    { key = "bar7",        label = "Bar 7" },
    { key = "bar8",        label = "Bar 8" },
    { key = "bar9",        label = "Bar 9" },
    { key = "bar10",       label = "Bar 10" },
    { key = "bar11",       label = "Bar 11" },
    { key = "bar12",       label = "Bar 12" },
    { key = "bar13",       label = "Bar 13" },
    { key = "bar14",       label = "Bar 14" },
    { key = "bar15",       label = "Bar 15" },
    { key = "extraAction", label = "Extra Action" },
    { key = "vehicleExit", label = "Vehicle Exit" },
    { key = "pet",         label = "Pet Bar" },
    { key = "stance",      label = "Stance Bar" },
}

local BAR_LABELS = {}
local pendingCopySources = {}
local UpdateBarVisibilityFromSimple

for _, entry in ipairs(BAR_ORDER) do
    BAR_LABELS[entry.key] = entry.label
end

local BAR_MAX_BUTTONS = {
    bar1 = 12,
    bar2 = 12,
    bar3 = 12,
    bar4 = 12,
    bar5 = 12,
    bar6 = 12,
    bar7 = 12,
    bar8 = 12,
    bar9 = 12,
    bar10 = 12,
    bar11 = 12,
    bar12 = 12,
    bar13 = 12,
    bar14 = 12,
    bar15 = 12,
    extraAction = 1,
    vehicleExit = 1,
    pet = 10,
    stance = 10,
}

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end

    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end

    return value
end

local function DeepCopyValue(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, nestedValue in pairs(value) do
        clone[key] = DeepCopyValue(nestedValue)
    end

    return clone
end

local function NormalizeBarSettings(barKey, barDB)
    if type(barDB) ~= "table" then
        return
    end

    local defaults = BAR_DEFAULTS[barKey] or {}
    local maxButtons = BAR_MAX_BUTTONS[barKey] or 12

    for key, defaultValue in pairs(defaults) do
        if barDB[key] == nil then
            barDB[key] = DeepCopyValue(defaultValue)
        end
    end

    barDB.enabled = barDB.enabled == true
    barDB.mouseover = barDB.mouseover == true
    barDB.backdrop = barDB.backdrop ~= false
    barDB.showBorder = barDB.showBorder ~= false
    barDB.showAccent = barDB.showAccent ~= false
    barDB.showCooldownSwipe = barDB.showCooldownSwipe ~= false

    barDB.buttonCount = ClampNumber(barDB.buttonCount, 1, maxButtons, defaults.buttonCount or maxButtons)
    barDB.buttonsPerRow = ClampNumber(barDB.buttonsPerRow, 1, maxButtons,
        defaults.buttonsPerRow or barDB.buttonCount or maxButtons)
    barDB.buttonSize = ClampNumber(barDB.buttonSize, 22, 64, defaults.buttonSize or 32)
    barDB.scale = ClampNumber(barDB.scale, 0.5, 2, defaults.scale or 1)
    barDB.alpha = ClampNumber(barDB.alpha, 0.05, 1, defaults.alpha or 1)
    barDB.x = tonumber(barDB.x) or defaults.x or 0
    barDB.y = tonumber(barDB.y) or defaults.y or 0
    barDB.point = defaults.point and (barDB.point or defaults.point) or barDB.point
    barDB.relativePoint = defaults.relativePoint and (barDB.relativePoint or defaults.relativePoint) or
    barDB.relativePoint

    if type(barDB.simpleVisibility) ~= "table" then
        barDB.simpleVisibility = DeepCopyValue(defaults.simpleVisibility or {})
    end

    if barDB.simpleVisibilityMode ~= "show" and barDB.simpleVisibilityMode ~= "hide" then
        barDB.simpleVisibilityMode = "raw"
    end

    if barDB.simpleVisibilityMode ~= "raw" then
        UpdateBarVisibilityFromSimple(barDB)
    else
        barDB.visibility = tostring(barDB.visibility or defaults.visibility or "show")
    end

    barDB._cooldownSwipeDefaultsMigrated = true
end

local function CopyBarSettings(targetBarKey, sourceBarKey, db)
    if not targetBarKey or not sourceBarKey or targetBarKey == sourceBarKey then
        return false
    end

    db = db or Options:GetDB()
    if type(db) ~= "table" or type(db.bars) ~= "table" then
        return false
    end

    local sourceBarDB = db.bars[sourceBarKey]
    local targetBarDB = db.bars[targetBarKey]
    if type(sourceBarDB) ~= "table" or type(targetBarDB) ~= "table" then
        return false
    end

    for key in pairs(targetBarDB) do
        targetBarDB[key] = nil
    end

    for key, value in pairs(sourceBarDB) do
        if key ~= "_cooldownSwipeDefaultsMigrated" then
            targetBarDB[key] = DeepCopyValue(value)
        end
    end

    NormalizeBarSettings(targetBarKey, targetBarDB)
    return true
end

local function GetCopySourceValues(targetBarKey)
    local values = {}

    for _, entry in ipairs(BAR_ORDER) do
        if entry.key ~= targetBarKey then
            values[entry.key] = entry.label
        end
    end

    return values
end

local function GetModule()
    return _G.TwichUIActionBarsRuntime
end

local function RequestRefresh(refreshConfig)
    local module = GetModule()
    if module and type(module.RefreshModuleState) == "function" then
        module:RefreshModuleState()
    end

    if refreshConfig and ConfigurationModule and ConfigurationModule.Refresh then
        ConfigurationModule:Refresh()
    end
end

local function RequestGlowRefresh(refreshConfig)
    local module = GetModule()
    if module and type(module.RefreshGlowState) == "function" then
        module:RefreshGlowState()
    else
        RequestRefresh(refreshConfig)
        return
    end

    if refreshConfig and ConfigurationModule and ConfigurationModule.Refresh then
        ConfigurationModule:Refresh()
    end
end

local function GetFontValues()
    local values = {
        ["__default"] = "Theme / Default",
    }

    local fonts = LSM and LSM:HashTable("font") or {}
    for key in pairs(fonts) do
        values[key] = key
    end

    return values
end

local function GetOutlineValues()
    return {
        NONE = "None",
        OUTLINE = "Outline",
        THICKOUTLINE = "Thick Outline",
        MONOCHROMEOUTLINE = "Monochrome Outline",
    }
end

local function GetThemeTextColor()
    local theme = T:GetModule("Theme", true)
    local color = theme and theme.Get and theme:Get("textColor") or nil
    if type(color) == "table" then
        return color[1] or 0.92, color[2] or 0.94, color[3] or 0.96
    end

    return 0.92, 0.94, 0.96
end

local function BuildSimpleVisibilityDriver(barDB)
    if type(barDB) ~= "table" then
        return "show"
    end

    local mode = barDB.simpleVisibilityMode or "raw"
    if mode == "raw" then
        return tostring(barDB.visibility or "")
    end

    local action = mode == "show" and "show" or "hide"
    local fallback = mode == "show" and "hide" or "show"
    local clauses = {}
    local simpleVisibility = type(barDB.simpleVisibility) == "table" and barDB.simpleVisibility or {}

    for _, rule in ipairs(SIMPLE_VISIBILITY_RULES) do
        if simpleVisibility[rule.key] == true then
            clauses[#clauses + 1] = string.format("[%s] %s", rule.condition, action)
        end
    end

    if #clauses == 0 then
        return fallback
    end

    clauses[#clauses + 1] = fallback
    return table.concat(clauses, "; ")
end

local function EnsureSimpleVisibility(barDB)
    if type(barDB.simpleVisibility) ~= "table" then
        barDB.simpleVisibility = {}
    end

    return barDB.simpleVisibility
end

UpdateBarVisibilityFromSimple = function(barDB)
    barDB.visibility = BuildSimpleVisibilityDriver(barDB)
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.actionBars) ~= "table" then
        profile.actionBars = {}
    end

    local db = profile.actionBars
    for key, value in pairs(ROOT_DEFAULTS) do
        if db[key] == nil then
            db[key] = value
        end
    end

    if db._cooldownSwipeDefaultsMigrated ~= true then
        db.showCooldownSwipe = true
        db._cooldownSwipeDefaultsMigrated = true
    end

    if type(db.bars) ~= "table" then
        db.bars = {}
    end

    for barKey, defaults in pairs(BAR_DEFAULTS) do
        if type(db.bars[barKey]) ~= "table" then
            db.bars[barKey] = {}
        end

        for key, value in pairs(defaults) do
            if db.bars[barKey][key] == nil then
                db.bars[barKey][key] = value
            end
        end

        if db.bars[barKey]._cooldownSwipeDefaultsMigrated ~= true then
            db.bars[barKey].showCooldownSwipe = true
            db.bars[barKey]._cooldownSwipeDefaultsMigrated = true
        end
    end

    return db
end

function Options:GetBarSettings(barKey)
    local db = self:GetDB()
    return db.bars and db.bars[barKey] or nil
end

function Options:GetEnabled()
    return self:GetDB().enabled ~= false
end

function Options:SetEnabled(_, value)
    self:GetDB().enabled = value == true
    RequestRefresh(true)
end

function Options:GetDebugEnabled()
    return self:GetDB().debugEnabled == true
end

function Options:SetDebugEnabled(_, value)
    self:GetDB().debugEnabled = value == true

    if value ~= true and T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole then
        T.Tools.UI.DebugConsole:ClearLogs("actionbars")
    end
end

function Options:OpenDebugConsole()
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if console and console.Show then
        console:Show("actionbars")
    end
end

function Options:OpenQuickBindMode()
    local module = GetModule()
    if module and type(module.ActivateBindMode) == "function" then
        module:ActivateBindMode()
    end
end

function Options:BuildConfiguration()
    local Widgets = ConfigurationModule.Widgets
    local db = self:GetDB()
    local section = Widgets.NewConfigurationSection(8, "Action Bars")

    local generalArgs = {
        module = Widgets.IGroup(1, "Module", {
            desc = Widgets.Description(0,
                "Rebuild Blizzard action bars into TwichUI-managed bars with movers, visibility drivers, mouseover fading, text controls, and optional Masque skinning."),
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable the TwichUI action bars system.",
                order = 1,
                width = "half",
                get = function()
                    return Options:GetEnabled()
                end,
                set = function(_, value)
                    Options:SetEnabled(nil, value)
                end,
            },
            unlock = {
                type = "toggle",
                name = "Unlock Movers",
                desc = "Open the TwichUI central mover overlay to reposition all bars and frames simultaneously.",
                order = 2,
                width = "half",
                get = function()
                    return _G.TwichMoverModule and _G.TwichMoverModule:IsActive() or false
                end,
                set = function()
                    local m = _G.TwichMoverModule
                    if m then m:Toggle() end
                end,
            },
            useMasque = {
                type = "toggle",
                name = "Use Masque",
                desc = "Allow Masque to skin action buttons when the addon is installed.",
                order = 3,
                width = "half",
                get = function()
                    return db.useMasque == true
                end,
                set = function(_, value)
                    db.useMasque = value == true
                    RequestRefresh(false)
                end,
            },
            debugEnabled = {
                type = "toggle",
                name = "Debug Logging",
                desc = "Capture Action Bars diagnostics into the TwichUI Debug Console.",
                order = 4,
                width = "half",
                get = function()
                    return Options:GetDebugEnabled()
                end,
                set = function(_, value)
                    Options:SetDebugEnabled(nil, value)
                end,
            },
            openDebug = {
                type = "execute",
                name = "Open Action Bars Logs",
                desc = "Open the Debug Console focused on the Action Bars source.",
                order = 5,
                width = 1.3,
                func = function()
                    Options:OpenDebugConsole()
                end,
            },
            quickBind = {
                type = "execute",
                name = "Quick Bind Mode",
                desc = "Open a hover-and-press keybind overlay for action buttons.",
                order = 5.5,
                width = 1.3,
                func = function()
                    Options:OpenQuickBindMode()
                end,
            },
            showGrid = {
                type = "toggle",
                name = "Show Empty Slots",
                desc = "Keep empty action slots visible instead of collapsing to only populated actions.",
                order = 6,
                width = "half",
                get = function()
                    return db.showGrid == true
                end,
                set = function(_, value)
                    db.showGrid = value == true
                    RequestRefresh(false)
                end,
            },
            spacing = {
                type = "range",
                name = "Button Spacing",
                desc = "Spacing between buttons inside each bar.",
                order = 7,
                min = 0,
                max = 20,
                step = 1,
                width = 1.6,
                get = function()
                    return db.buttonSpacing or 4
                end,
                set = function(_, value)
                    db.buttonSpacing = ClampNumber(value, 0, 20, 4)
                    RequestRefresh(false)
                end,
            },
            refresh = {
                type = "execute",
                name = "Refresh Bars",
                desc = "Force a full action bar rebuild with the current settings.",
                order = 8,
                width = 1.3,
                func = function()
                    RequestRefresh(false)
                end,
            },
        }),
        cooldowns = Widgets.IGroup(2, "Cooldowns", {
            showText = {
                type = "toggle",
                name = "Cooldown Text",
                desc = "Show numeric countdown text on button cooldowns.",
                order = 1,
                width = "half",
                get = function()
                    return db.showCooldownText == true
                end,
                set = function(_, value)
                    db.showCooldownText = value == true
                    RequestRefresh(false)
                end,
            },
            showSwipe = {
                type = "toggle",
                name = "Cooldown Swipe",
                desc = "Show the radial cooldown swipe on action buttons.",
                order = 2,
                width = "half",
                get = function()
                    return db.showCooldownSwipe == true
                end,
                set = function(_, value)
                    db.showCooldownSwipe = value == true
                    RequestRefresh(false)
                end,
            },
            glowStyle = {
                type = "select",
                name = "Proc Glow Style",
                desc = "Choose how spell activation glows are rendered on action buttons.",
                order = 3,
                width = 1.3,
                values = {
                    pixel = "Pixel Border",
                    proc = "Soft Proc",
                    button = "Action Button",
                    blizzard = "Blizzard",
                    none = "None",
                },
                get = function()
                    return db.procGlowStyle or "pixel"
                end,
                set = function(_, value)
                    db.procGlowStyle = value or "pixel"
                    RequestGlowRefresh(false)
                end,
            },
            glowUseThemeColor = {
                type = "toggle",
                name = "Use Theme Accent",
                desc = "Drive supported glow styles from the current TwichUI accent color.",
                order = 4,
                width = "half",
                disabled = function()
                    local style = db.procGlowStyle or "pixel"
                    return style == "none" or style == "blizzard"
                end,
                get = function()
                    return db.procGlowUseThemeColor ~= false
                end,
                set = function(_, value)
                    db.procGlowUseThemeColor = value ~= false
                    RequestGlowRefresh(false)
                end,
            },
            glowColor = {
                type = "color",
                name = "Glow Color",
                desc = "Custom proc glow color for supported Action Bars glow styles.",
                order = 5,
                width = "half",
                disabled = function()
                    local style = db.procGlowStyle or "pixel"
                    return style == "none" or style == "blizzard" or db.procGlowUseThemeColor ~= false
                end,
                get = function()
                    local color = db.procGlowColor
                    if type(color) == "table" then
                        return color[1] or 0.96, color[2] or 0.76, color[3] or 0.24
                    end

                    return 0.96, 0.76, 0.24
                end,
                set = function(_, red, green, blue)
                    db.procGlowColor = { red, green, blue }
                    RequestGlowRefresh(false)
                end,
            },
            failedFeedback = {
                type = "toggle",
                name = "Failed Cast Feedback",
                desc = "Flash the last attempted action button red when the spell or action fails to fire.",
                order = 6,
                width = "half",
                get = function()
                    return db.failedActionFeedback ~= false
                end,
                set = function(_, value)
                    db.failedActionFeedback = value ~= false
                    RequestRefresh(false)
                end,
            },
            failedFeedbackDuration = {
                type = "range",
                name = "Feedback Duration",
                desc = "How long the failed-action flash remains visible.",
                order = 7,
                min = 0.15,
                max = 1.2,
                step = 0.05,
                width = 1.4,
                disabled = function()
                    return db.failedActionFeedback == false
                end,
                get = function()
                    return ClampNumber(db.failedActionDuration, 0.15, 1.2, 0.45)
                end,
                set = function(_, value)
                    db.failedActionDuration = ClampNumber(value, 0.15, 1.2, 0.45)
                end,
            },
            failedFeedbackColor = {
                type = "color",
                name = "Feedback Color",
                desc = "Color used for the failed-action flash.",
                order = 8,
                width = "half",
                disabled = function()
                    return db.failedActionFeedback == false
                end,
                get = function()
                    local color = db.failedActionColor
                    if type(color) == "table" then
                        return color[1] or 0.93, color[2] or 0.22, color[3] or 0.20
                    end

                    return 0.93, 0.22, 0.20
                end,
                set = function(_, red, green, blue)
                    db.failedActionColor = { red, green, blue }
                end,
            },
        }),
    }

    local textArgs = {
        text = Widgets.IGroup(1, "Text", {
            font = {
                type = "select",
                name = "Font",
                desc = "Shared font for hotkeys, stack counts, and macro names.",
                order = 1,
                width = 1.5,
                values = GetFontValues,
                get = function()
                    return db.textFont or "__default"
                end,
                set = function(_, value)
                    db.textFont = value
                    RequestRefresh(false)
                end,
            },
            outline = {
                type = "select",
                name = "Outline",
                desc = "Outline mode for action button text.",
                order = 2,
                width = 1.2,
                values = GetOutlineValues,
                get = function()
                    return db.fontOutline or "NONE"
                end,
                set = function(_, value)
                    db.fontOutline = value
                    RequestRefresh(false)
                end,
            },
            shadow = {
                type = "toggle",
                name = "Text Shadow",
                desc = "Apply a soft shadow to hotkeys, stack counts, and macro names.",
                order = 2.25,
                width = "half",
                get = function()
                    return db.textShadow == true
                end,
                set = function(_, value)
                    db.textShadow = value == true
                    RequestRefresh(false)
                end,
            },
            textColor = {
                type = "color",
                name = "Text Color",
                desc = "Shared color for hotkeys, stack counts, and macro names.",
                order = 2.5,
                width = "half",
                get = function()
                    local color = db.textColor
                    if type(color) == "table" then
                        return color[1] or 0.92, color[2] or 0.94, color[3] or 0.96
                    end

                    return GetThemeTextColor()
                end,
                set = function(_, red, green, blue)
                    db.textColor = { red, green, blue }
                    RequestRefresh(false)
                end,
            },
            hotkeys = {
                type = "toggle",
                name = "Show Hotkeys",
                desc = "Display hotkey text in the top-right of buttons.",
                order = 3,
                width = "half",
                get = function()
                    return db.showHotkeys == true
                end,
                set = function(_, value)
                    db.showHotkeys = value == true
                    RequestRefresh(false)
                end,
            },
            counts = {
                type = "toggle",
                name = "Show Counts",
                desc = "Display stack and charge counts.",
                order = 4,
                width = "half",
                get = function()
                    return db.showCounts == true
                end,
                set = function(_, value)
                    db.showCounts = value == true
                    RequestRefresh(false)
                end,
            },
            macros = {
                type = "toggle",
                name = "Show Macro Names",
                desc = "Display the button macro name text.",
                order = 5,
                width = "half",
                get = function()
                    return db.showMacroNames == true
                end,
                set = function(_, value)
                    db.showMacroNames = value == true
                    RequestRefresh(false)
                end,
            },
            hotkeySize = {
                type = "range",
                name = "Hotkey Size",
                desc = "Font size for hotkey text.",
                order = 6,
                min = 6,
                max = 24,
                step = 1,
                width = 1.3,
                get = function()
                    return db.hotkeyFontSize or 11
                end,
                set = function(_, value)
                    db.hotkeyFontSize = ClampNumber(value, 6, 24, 11)
                    RequestRefresh(false)
                end,
            },
            countSize = {
                type = "range",
                name = "Count Size",
                desc = "Font size for stack and charge counts.",
                order = 7,
                min = 6,
                max = 24,
                step = 1,
                width = 1.3,
                get = function()
                    return db.countFontSize or 11
                end,
                set = function(_, value)
                    db.countFontSize = ClampNumber(value, 6, 24, 11)
                    RequestRefresh(false)
                end,
            },
            macroSize = {
                type = "range",
                name = "Macro Size",
                desc = "Font size for macro names.",
                order = 8,
                min = 6,
                max = 24,
                step = 1,
                width = 1.3,
                get = function()
                    return db.macroFontSize or 9
                end,
                set = function(_, value)
                    db.macroFontSize = ClampNumber(value, 6, 24, 9)
                    RequestRefresh(false)
                end,
            },
        }),
    }

    section.args = {
        title = Widgets.TitleWidget(0, "Action Bars"),
        description = Widgets.Description(1,
            "Control TwichUI-managed primary bars, extra bars, pet and stance bars, with secure movers, visibility drivers, mouseover fading, text styling, and Masque support."),
        general = {
            type = "group",
            name = "General",
            order = 2,
            args = generalArgs,
        },
        text = {
            type = "group",
            name = "Text",
            order = 3,
            args = textArgs,
        },
    }

    for index, entry in ipairs(BAR_ORDER) do
        local barKey = entry.key
        local label = entry.label
        section.args[barKey] = {
            type = "group",
            name = label,
            order = 10 + index,
            args = {
                controls = Widgets.IGroup(1, label, {
                    copySource = {
                        type = "select",
                        name = "Copy Settings From",
                        desc =
                        "Choose another bar and copy its current settings into this bar, including layout, visibility, and styling.",
                        order = 0.1,
                        width = 1.5,
                        values = function()
                            return GetCopySourceValues(barKey)
                        end,
                        get = function()
                            return pendingCopySources[barKey]
                        end,
                        set = function(_, value)
                            pendingCopySources[barKey] = value
                        end,
                    },
                    copyExecute = {
                        type = "execute",
                        name = "Copy Settings",
                        desc = "Apply the selected bar's settings to this bar.",
                        order = 0.2,
                        width = 1.1,
                        disabled = function()
                            local sourceBarKey = pendingCopySources[barKey]
                            return sourceBarKey == nil or sourceBarKey == barKey
                        end,
                        func = function()
                            local sourceBarKey = pendingCopySources[barKey]
                            if not sourceBarKey or sourceBarKey == barKey then
                                return
                            end

                            local sourceLabel = BAR_LABELS[sourceBarKey] or sourceBarKey
                            local targetLabel = BAR_LABELS[barKey] or barKey
                            local applyCopy = function()
                                if CopyBarSettings(barKey, sourceBarKey, db) then
                                    RequestRefresh(true)
                                end
                            end

                            if ConfigurationModule and ConfigurationModule.ShowGenericConfirmationDialog then
                                ConfigurationModule:ShowGenericConfirmationDialog(
                                    string.format("Copy settings from %s to %s?", sourceLabel, targetLabel),
                                    applyCopy)
                            else
                                applyCopy()
                            end
                        end,
                    },
                    copyNote = Widgets.Description(0.3,
                        "Copying replaces this bar's current settings and then normalizes values for the target bar's limits."),
                    enable = {
                        type = "toggle",
                        name = "Enable",
                        desc = "Show this bar inside the TwichUI action bars layout.",
                        order = 1,
                        width = "half",
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.enabled == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.enabled = value == true
                            RequestRefresh(false)
                        end,
                    },
                    mouseover = {
                        type = "toggle",
                        name = "Mouseover",
                        desc = "Fade this bar out until it is hovered.",
                        order = 2,
                        width = "half",
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.mouseover == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.mouseover = value == true
                            RequestRefresh(false)
                        end,
                    },
                    backdrop = {
                        type = "toggle",
                        name = "Backdrop",
                        desc = "Show the TwichUI panel treatment behind this bar.",
                        order = 3,
                        width = "half",
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.backdrop ~= false
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.backdrop = value == true
                            RequestRefresh(false)
                        end,
                    },
                    border = {
                        type = "toggle",
                        name = "Border",
                        desc = "Show the TwichUI border treatment on this bar and its buttons.",
                        order = 3.25,
                        width = "half",
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.showBorder ~= false
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.showBorder = value == true
                            RequestRefresh(false)
                        end,
                    },
                    accent = {
                        type = "toggle",
                        name = "Accent",
                        desc = "Show the accent glow and left accent strip on this bar's frame styling.",
                        order = 3.5,
                        width = "half",
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.showAccent ~= false
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.showAccent = value == true
                            RequestRefresh(false)
                        end,
                    },
                    buttonCount = {
                        type = "range",
                        name = "Visible Buttons",
                        desc = "How many buttons from this bar to display.",
                        order = 4,
                        min = 1,
                        max = BAR_MAX_BUTTONS[barKey] or 12,
                        step = 1,
                        width = 1.4,
                        disabled = function()
                            return (BAR_MAX_BUTTONS[barKey] or 12) <= 1
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.buttonCount or (BAR_MAX_BUTTONS[barKey] or 12)
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.buttonCount = ClampNumber(value, 1, BAR_MAX_BUTTONS[barKey] or 12,
                                BAR_MAX_BUTTONS[barKey] or 12)
                            RequestRefresh(false)
                        end,
                    },
                    rows = {
                        type = "range",
                        name = "Buttons Per Row",
                        desc = "How many buttons to place before wrapping to a new row.",
                        order = 5,
                        min = 1,
                        max = BAR_MAX_BUTTONS[barKey] or 12,
                        step = 1,
                        width = 1.4,
                        disabled = function()
                            return (BAR_MAX_BUTTONS[barKey] or 12) <= 1
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.buttonsPerRow or (BAR_MAX_BUTTONS[barKey] or 12)
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.buttonsPerRow = ClampNumber(value, 1, BAR_MAX_BUTTONS[barKey] or 12,
                                BAR_MAX_BUTTONS[barKey] or 12)
                            RequestRefresh(false)
                        end,
                    },
                    buttonSize = {
                        type = "range",
                        name = "Button Size",
                        desc = "Pixel size for buttons in this bar.",
                        order = 6,
                        min = 22,
                        max = 64,
                        step = 1,
                        width = 1.4,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.buttonSize or 32
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.buttonSize = ClampNumber(value, 22, 64, 32)
                            RequestRefresh(false)
                        end,
                    },
                    scale = {
                        type = "range",
                        name = "Scale",
                        desc = "Overall scale for this bar.",
                        order = 7,
                        min = 0.5,
                        max = 2,
                        step = 0.01,
                        width = 1.4,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.scale or 1
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.scale = ClampNumber(value, 0.5, 2, 1)
                            RequestRefresh(false)
                        end,
                    },
                    alpha = {
                        type = "range",
                        name = "Alpha",
                        desc = "Visible alpha for this bar when shown.",
                        order = 8,
                        min = 0.05,
                        max = 1,
                        step = 0.01,
                        width = 1.4,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.alpha or 1
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.alpha = ClampNumber(value, 0.05, 1, 1)
                            RequestRefresh(false)
                        end,
                    },
                    simpleVisibilityMode = {
                        type = "select",
                        name = "Simple Visibility",
                        desc =
                        "Use common-state checkboxes to build this bar's visibility driver, or leave this on Raw to manage the driver manually.",
                        order = 9,
                        width = 1.4,
                        values = {
                            raw = "Raw Driver",
                            show = "Show Selected States",
                            hide = "Hide Selected States",
                        },
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.simpleVisibilityMode or "raw"
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            if not barDB then
                                return
                            end

                            barDB.simpleVisibilityMode = value or "raw"
                            if barDB.simpleVisibilityMode ~= "raw" then
                                UpdateBarVisibilityFromSimple(barDB)
                            end
                            RequestRefresh(false)
                        end,
                    },
                    combatVisibility = {
                        type = "toggle",
                        name = "Combat",
                        desc = "Include combat in the simple visibility rules.",
                        order = 9.1,
                        width = "half",
                        disabled = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return not barDB or barDB.simpleVisibilityMode == "raw"
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local simpleVisibility = barDB and EnsureSimpleVisibility(barDB) or {}
                            return simpleVisibility.combat == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            EnsureSimpleVisibility(barDB).combat = value == true
                            UpdateBarVisibilityFromSimple(barDB)
                            RequestRefresh(false)
                        end,
                    },
                    skyridingVisibility = {
                        type = "toggle",
                        name = "Skyriding / Override",
                        desc =
                        "Include override-bar states, which are the closest secure visibility match for skyriding-style bars.",
                        order = 9.2,
                        width = "half",
                        disabled = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return not barDB or barDB.simpleVisibilityMode == "raw"
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local simpleVisibility = barDB and EnsureSimpleVisibility(barDB) or {}
                            return simpleVisibility.skyriding == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            EnsureSimpleVisibility(barDB).skyriding = value == true
                            UpdateBarVisibilityFromSimple(barDB)
                            RequestRefresh(false)
                        end,
                    },
                    petBattleVisibility = {
                        type = "toggle",
                        name = "Pet Battle",
                        desc = "Include pet battles in the simple visibility rules.",
                        order = 9.3,
                        width = "half",
                        disabled = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return not barDB or barDB.simpleVisibilityMode == "raw"
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local simpleVisibility = barDB and EnsureSimpleVisibility(barDB) or {}
                            return simpleVisibility.petbattle == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            EnsureSimpleVisibility(barDB).petbattle = value == true
                            UpdateBarVisibilityFromSimple(barDB)
                            RequestRefresh(false)
                        end,
                    },
                    vehicleVisibility = {
                        type = "toggle",
                        name = "Vehicle",
                        desc = "Include vehicle UI states in the simple visibility rules.",
                        order = 9.4,
                        width = "half",
                        disabled = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return not barDB or barDB.simpleVisibilityMode == "raw"
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local simpleVisibility = barDB and EnsureSimpleVisibility(barDB) or {}
                            return simpleVisibility.vehicle == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            EnsureSimpleVisibility(barDB).vehicle = value == true
                            UpdateBarVisibilityFromSimple(barDB)
                            RequestRefresh(false)
                        end,
                    },
                    possessVisibility = {
                        type = "toggle",
                        name = "Possess",
                        desc = "Include possess-bar states in the simple visibility rules.",
                        order = 9.5,
                        width = "half",
                        disabled = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return not barDB or barDB.simpleVisibilityMode == "raw"
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local simpleVisibility = barDB and EnsureSimpleVisibility(barDB) or {}
                            return simpleVisibility.possess == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            EnsureSimpleVisibility(barDB).possess = value == true
                            UpdateBarVisibilityFromSimple(barDB)
                            RequestRefresh(false)
                        end,
                    },
                    petVisibility = {
                        type = "toggle",
                        name = "Pet",
                        desc = "Include pet-state visibility in the simple visibility rules.",
                        order = 9.6,
                        width = "half",
                        disabled = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return not barDB or barDB.simpleVisibilityMode == "raw"
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local simpleVisibility = barDB and EnsureSimpleVisibility(barDB) or {}
                            return simpleVisibility.pet == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            EnsureSimpleVisibility(barDB).pet = value == true
                            UpdateBarVisibilityFromSimple(barDB)
                            RequestRefresh(false)
                        end,
                    },
                    stanceVisibility = {
                        type = "toggle",
                        name = "Stance",
                        desc = "Include shapeshift or stance states in the simple visibility rules.",
                        order = 9.7,
                        width = "half",
                        disabled = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return not barDB or barDB.simpleVisibilityMode == "raw"
                        end,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local simpleVisibility = barDB and EnsureSimpleVisibility(barDB) or {}
                            return simpleVisibility.stance == true
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            EnsureSimpleVisibility(barDB).stance = value == true
                            UpdateBarVisibilityFromSimple(barDB)
                            RequestRefresh(false)
                        end,
                    },
                    visibility = {
                        type = "input",
                        name = "Advanced Visibility Driver",
                        desc =
                        "Secure visibility state driver for this bar. Editing this switches the bar back to raw driver mode.",
                        order = 10,
                        width = 2.2,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return tostring(barDB and barDB.visibility or "")
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.simpleVisibilityMode = "raw"
                            barDB.visibility = tostring(value or "")
                            RequestRefresh(false)
                        end,
                    },
                    swipe = {
                        type = "toggle",
                        name = "Cooldown Swipe",
                        desc = "Show the radial cooldown swipe on this bar. The swipe is constrained to the icon area.",
                        order = 11,
                        width = "half",
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return barDB and barDB.showCooldownSwipe ~= false
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.showCooldownSwipe = value == true
                            RequestRefresh(false)
                        end,
                    },
                    x = {
                        type = "input",
                        name = "X",
                        desc = "Horizontal offset. Movers save to precise bottom-left coordinates after dragging.",
                        order = 12,
                        width = 0.8,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return tostring(barDB and barDB.x or 0)
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.x = tonumber(value) or 0
                            RequestRefresh(false)
                        end,
                    },
                    y = {
                        type = "input",
                        name = "Y",
                        desc = "Vertical offset. Movers save to precise bottom-left coordinates after dragging.",
                        order = 13,
                        width = 0.8,
                        get = function()
                            local barDB = Options:GetBarSettings(barKey)
                            return tostring(barDB and barDB.y or 0)
                        end,
                        set = function(_, value)
                            local barDB = Options:GetBarSettings(barKey)
                            barDB.y = tonumber(value) or 0
                            RequestRefresh(false)
                        end,
                    },
                    reset = {
                        type = "execute",
                        name = "Reset Position",
                        desc = "Reset this bar back to its default anchor and offset.",
                        order = 14,
                        width = 1.2,
                        func = function()
                            local barDB = Options:GetBarSettings(barKey)
                            local defaults = BAR_DEFAULTS[barKey]
                            if barDB and defaults then
                                barDB.point = defaults.point
                                barDB.relativePoint = defaults.relativePoint
                                barDB.x = defaults.x
                                barDB.y = defaults.y
                                RequestRefresh(false)
                            end
                        end,
                    },
                    note = Widgets.Description(15,
                        "Use Unlock Movers for drag-and-drop placement. Visibility drivers are applied only while bars are locked so mover mode always stays visible."),
                }),
            },
        }
    end

    return section
end
