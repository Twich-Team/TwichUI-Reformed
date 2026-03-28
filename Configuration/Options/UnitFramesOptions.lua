---@diagnostic disable: undefined-field, inject-field
--[[
    Options handlers for Unit Frames.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class UnitFramesConfigurationOptions
local Options = ConfigurationModule.Options.UnitFrames or {}
ConfigurationModule.Options.UnitFrames = Options

local DEFAULTS = {
    enabled = true,
    lockFrames = true,
    testMode = false,
    scale = 1,
    frameAlpha = 1,
    smoothBars = true,
    useClassColor = false,
    showHealthText = true,
    showPowerText = true,
    text = {
        nameFormat = "full",
        healthFormat = "percent",
        powerFormat = "percent",
        nameFontSize = 11,
        healthFontSize = 10,
        powerFontSize = 9,
        scopes = {
            singles = { nameFormat = "full", healthFormat = "percent", powerFormat = "percent", nameFontSize = 11, healthFontSize = 10, powerFontSize = 9 },
            party = { nameFormat = "short", healthFormat = "percent", powerFormat = "percent", nameFontSize = 10, healthFontSize = 9, powerFontSize = 8 },
            raid = { nameFormat = "short", healthFormat = "percent", powerFormat = "percent", nameFontSize = 9, healthFontSize = 8, powerFontSize = 8 },
            tank = { nameFormat = "short", healthFormat = "currentPercent", powerFormat = "percent", nameFontSize = 10, healthFontSize = 9, powerFontSize = 8 },
            boss = { nameFormat = "full", healthFormat = "currentPercent", powerFormat = "percent", nameFontSize = 10, healthFontSize = 9, powerFontSize = 8 },
        },
    },
    auras = {
        scopes = {
            singles = { enabled = true, maxIcons = 8, iconSize = 18, spacing = 2, yOffset = 6 },
            party = { enabled = true, maxIcons = 6, iconSize = 14, spacing = 2, yOffset = 5 },
            raid = { enabled = false, maxIcons = 4, iconSize = 12, spacing = 1, yOffset = 4 },
            tank = { enabled = true, maxIcons = 6, iconSize = 14, spacing = 2, yOffset = 5 },
            boss = { enabled = true, maxIcons = 8, iconSize = 16, spacing = 2, yOffset = 6 },
        },
    },
    healthColorByScope = {
        singles = { mode = "theme", color = { 0.34, 0.84, 0.54, 1 } },
        party = { mode = "class", color = { 0.34, 0.84, 0.54, 1 } },
        raid = { mode = "class", color = { 0.34, 0.84, 0.54, 1 } },
        tank = { mode = "class", color = { 0.34, 0.84, 0.54, 1 } },
        boss = { mode = "custom", color = { 0.96, 0.26, 0.30, 1 } },
    },
    colors = {
        health = { 0.34, 0.84, 0.54, 1 },
        power = { 0.10, 0.72, 0.74, 1 },
        cast = { 0.96, 0.76, 0.24, 1 },
        background = { 0.05, 0.06, 0.08, 1 },
        border = { 0.24, 0.26, 0.32, 1 },
    },
    castbar = {
        enabled = true,
        width = 260,
        height = 20,
        showIcon = true,
        showSpellText = true,
        showTimeText = true,
        spellFontSize = 11,
        timeFontSize = 10,
        iconSize = 20,
        useCustomColor = false,
        color = { 0.96, 0.76, 0.24, 1 },
    },
    units = {
        player = { enabled = true, width = 260, height = 42, showPower = true, powerHeight = 10 },
        target = { enabled = true, width = 260, height = 42, showPower = true, powerHeight = 10 },
        targettarget = { enabled = true, width = 180, height = 30, showPower = true, powerHeight = 8 },
        focus = { enabled = true, width = 220, height = 34, showPower = true, powerHeight = 8 },
        pet = { enabled = true, width = 170, height = 28, showPower = true, powerHeight = 7 },
        boss1 = { enabled = true, width = 220, height = 36, showPower = true, powerHeight = 8 },
        boss2 = { enabled = true, width = 220, height = 36, showPower = true, powerHeight = 8 },
        boss3 = { enabled = true, width = 220, height = 36, showPower = true, powerHeight = 8 },
        boss4 = { enabled = true, width = 220, height = 36, showPower = true, powerHeight = 8 },
        boss5 = { enabled = true, width = 220, height = 36, showPower = true, powerHeight = 8 },
        boss = { enabled = true, width = 220, height = 36, showPower = true, powerHeight = 8 },
    },
    groups = {
        party = {
            enabled = true,
            width = 180,
            height = 36,
            point = "TOP",
            xOffset = 0,
            yOffset = -8,
            unitsPerColumn = 5,
            maxColumns = 1,
            columnSpacing = 8,
            columnAnchorPoint = "LEFT",
            showPlayer = true,
            showSolo = false,
        },
        raid = {
            enabled = true,
            width = 112,
            height = 34,
            point = "TOP",
            xOffset = 0,
            yOffset = -6,
            unitsPerColumn = 5,
            maxColumns = 8,
            columnSpacing = 6,
            columnAnchorPoint = "LEFT",
            showSolo = false,
            groupBy = "GROUP",
            groupingOrder = "1,2,3,4,5,6,7,8",
        },
        tank = {
            enabled = true,
            width = 180,
            height = 32,
            point = "TOP",
            xOffset = 0,
            yOffset = -6,
            unitsPerColumn = 8,
            maxColumns = 1,
            columnSpacing = 6,
            columnAnchorPoint = "LEFT",
            showSolo = false,
            groupFilter = "MAINTANK,MAINASSIST",
        },
        boss = {
            enabled = true,
            width = 220,
            height = 36,
            yOffset = -8,
        },
    },
    layout = {
        player = { point = "BOTTOM", relativePoint = "BOTTOM", x = -280, y = 220 },
        target = { point = "BOTTOM", relativePoint = "BOTTOM", x = 280, y = 220 },
        targettarget = { point = "BOTTOM", relativePoint = "BOTTOM", x = 280, y = 180 },
        focus = { point = "BOTTOM", relativePoint = "BOTTOM", x = -520, y = 300 },
        pet = { point = "BOTTOM", relativePoint = "BOTTOM", x = -280, y = 180 },
        castbar = { point = "BOTTOM", relativePoint = "BOTTOM", x = -280, y = 180 },
        party = { point = "LEFT", relativePoint = "LEFT", x = 40, y = 140 },
        raid = { point = "LEFT", relativePoint = "LEFT", x = 40, y = 420 },
        tank = { point = "RIGHT", relativePoint = "RIGHT", x = -60, y = 300 },
        boss = { point = "RIGHT", relativePoint = "RIGHT", x = -60, y = 520 },
    },
}

local function DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end

    local out = {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            out[key] = DeepCopy(value)
        else
            out[key] = value
        end
    end

    return out
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function GetModule()
    return T:GetModule("UnitFrames", true)
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.unitFrames) ~= "table" then
        profile.unitFrames = DeepCopy(DEFAULTS)
        return profile.unitFrames
    end

    MergeDefaults(profile.unitFrames, DEFAULTS)
    return profile.unitFrames
end

function Options:RefreshModule()
    local module = GetModule()
    if module and module.IsEnabled and module:IsEnabled() and type(module.RefreshFromOptions) == "function" then
        pcall(module.RefreshFromOptions, module)
    end
end

function Options:GetEnabled()
    return self:GetDB().enabled ~= false
end

function Options:SetEnabled(info, value)
    local db = self:GetDB()
    db.enabled = value == true

    local module = GetModule()
    if not module then
        return
    end

    if value then
        module:Enable()
    else
        module:Disable()
    end
end

function Options:GetLockFrames()
    return self:GetDB().lockFrames ~= false
end

function Options:SetLockFrames(info, value)
    self:GetDB().lockFrames = value == true

    local module = GetModule()
    if module and module.IsEnabled and module:IsEnabled() and type(module.SetFrameLock) == "function" then
        pcall(module.SetFrameLock, module, value == true)
    end
end

function Options:GetTestMode()
    return self:GetDB().testMode == true
end

function Options:SetTestMode(info, value)
    self:GetDB().testMode = value == true

    local module = GetModule()
    if module and module.IsEnabled and module:IsEnabled() and type(module.SetTestMode) == "function" then
        pcall(module.SetTestMode, module, value == true)
    end
end

function Options:GetScale()
    return tonumber(self:GetDB().scale) or 1
end

function Options:SetScale(info, value)
    self:GetDB().scale = tonumber(value) or 1
    self:RefreshModule()
end

function Options:GetFrameAlpha()
    return tonumber(self:GetDB().frameAlpha) or 1
end

function Options:SetFrameAlpha(info, value)
    self:GetDB().frameAlpha = tonumber(value) or 1
    self:RefreshModule()
end

function Options:GetSmoothBars()
    return self:GetDB().smoothBars ~= false
end

function Options:SetSmoothBars(info, value)
    self:GetDB().smoothBars = value == true
    self:RefreshModule()
end

function Options:GetUseClassColor()
    return self:GetDB().useClassColor == true
end

function Options:SetUseClassColor(info, value)
    self:GetDB().useClassColor = value == true
    self:RefreshModule()
end

function Options:GetShowHealthText()
    return self:GetDB().showHealthText ~= false
end

function Options:SetShowHealthText(info, value)
    self:GetDB().showHealthText = value == true
    self:RefreshModule()
end

function Options:GetShowPowerText()
    return self:GetDB().showPowerText ~= false
end

function Options:SetShowPowerText(info, value)
    self:GetDB().showPowerText = value == true
    self:RefreshModule()
end

function Options:GetTextSetting(scopeOrKey, maybeKey)
    local db = self:GetDB()
    db.text = db.text or {}

    if maybeKey == nil then
        return db.text[scopeOrKey]
    end

    db.text.scopes = db.text.scopes or {}
    db.text.scopes[scopeOrKey] = db.text.scopes[scopeOrKey] or {}
    local scoped = db.text.scopes[scopeOrKey]

    if scoped[maybeKey] == nil then
        return db.text[maybeKey]
    end

    return scoped[maybeKey]
end

function Options:SetTextSetting(scopeOrKey, maybeKey, maybeValue)
    local db = self:GetDB()
    db.text = db.text or {}

    if maybeValue == nil then
        db.text[scopeOrKey] = maybeKey
        self:RefreshModule()
        return
    end

    db.text.scopes = db.text.scopes or {}
    db.text.scopes[scopeOrKey] = db.text.scopes[scopeOrKey] or {}
    db.text.scopes[scopeOrKey][maybeKey] = maybeValue
    self:RefreshModule()
end

function Options:GetAuraSetting(scope, key)
    local db = self:GetDB()
    db.auras = db.auras or {}
    db.auras.scopes = db.auras.scopes or {}
    db.auras.scopes[scope] = db.auras.scopes[scope] or {}
    return db.auras.scopes[scope][key]
end

function Options:SetAuraSetting(scope, key, value)
    local db = self:GetDB()
    db.auras = db.auras or {}
    db.auras.scopes = db.auras.scopes or {}
    db.auras.scopes[scope] = db.auras.scopes[scope] or {}
    db.auras.scopes[scope][key] = value
    self:RefreshModule()
end

function Options:GetHealthColorMode(scope)
    local db = self:GetDB()
    db.healthColorByScope = db.healthColorByScope or {}
    db.healthColorByScope[scope] = db.healthColorByScope[scope] or {}
    return db.healthColorByScope[scope].mode or "theme"
end

function Options:SetHealthColorMode(scope, mode)
    local db = self:GetDB()
    db.healthColorByScope = db.healthColorByScope or {}
    db.healthColorByScope[scope] = db.healthColorByScope[scope] or {}
    db.healthColorByScope[scope].mode = mode
    self:RefreshModule()
end

function Options:GetHealthColor(scope)
    local db = self:GetDB()
    db.healthColorByScope = db.healthColorByScope or {}
    db.healthColorByScope[scope] = db.healthColorByScope[scope] or {}
    db.healthColorByScope[scope].color = db.healthColorByScope[scope].color or { 0.34, 0.84, 0.54, 1 }
    local color = db.healthColorByScope[scope].color
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

function Options:SetHealthColor(scope, r, g, b, a)
    local db = self:GetDB()
    db.healthColorByScope = db.healthColorByScope or {}
    db.healthColorByScope[scope] = db.healthColorByScope[scope] or {}
    db.healthColorByScope[scope].color = { r, g, b, a or 1 }
    self:RefreshModule()
end

function Options:GetColor(key)
    local db = self:GetDB()
    db.colors = db.colors or {}
    db.colors[key] = db.colors[key] or { 1, 1, 1, 1 }

    local color = db.colors[key]
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

function Options:SetColor(key, r, g, b, a)
    local db = self:GetDB()
    db.colors = db.colors or {}
    db.colors[key] = { r, g, b, a or 1 }
    self:RefreshModule()
end

function Options:GetUnitSetting(unit, key)
    local db = self:GetDB()
    db.units = db.units or {}
    db.units[unit] = db.units[unit] or {}

    return db.units[unit][key]
end

function Options:SetUnitSetting(unit, key, value)
    local db = self:GetDB()
    db.units = db.units or {}
    db.units[unit] = db.units[unit] or {}
    db.units[unit][key] = value
    self:RefreshModule()
end

function Options:GetGroupSetting(group, key)
    local db = self:GetDB()
    db.groups = db.groups or {}
    db.groups[group] = db.groups[group] or {}

    return db.groups[group][key]
end

function Options:SetGroupSetting(group, key, value)
    local db = self:GetDB()
    db.groups = db.groups or {}
    db.groups[group] = db.groups[group] or {}
    db.groups[group][key] = value
    self:RefreshModule()
end

function Options:GetLayoutSetting(key, field)
    local db = self:GetDB()
    db.layout = db.layout or {}
    db.layout[key] = db.layout[key] or {}

    return db.layout[key][field]
end

function Options:SetLayoutSetting(key, field, value)
    local db = self:GetDB()
    db.layout = db.layout or {}
    db.layout[key] = db.layout[key] or {}
    db.layout[key][field] = value
    self:RefreshModule()
end

function Options:GetCastbarSetting(key)
    local db = self:GetDB()
    db.castbar = db.castbar or {}
    return db.castbar[key]
end

function Options:SetCastbarSetting(key, value)
    local db = self:GetDB()
    db.castbar = db.castbar or {}
    db.castbar[key] = value
    self:RefreshModule()
end

function Options:GetCastbarColor()
    local db = self:GetDB()
    db.castbar = db.castbar or {}
    db.castbar.color = db.castbar.color or { 0.96, 0.76, 0.24, 1 }
    local color = db.castbar.color
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

function Options:SetCastbarColor(r, g, b, a)
    local db = self:GetDB()
    db.castbar = db.castbar or {}
    db.castbar.color = { r, g, b, a or 1 }
    self:RefreshModule()
end
