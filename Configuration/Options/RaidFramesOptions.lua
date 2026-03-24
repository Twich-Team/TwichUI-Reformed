--[[
    Options for the Raid Frames module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class RaidFramesConfigurationOptions
local Options = ConfigurationModule.Options.RaidFrames or {}
ConfigurationModule.Options.RaidFrames = Options

local DEFAULT_COLOR = {
    r = 1,
    g = 0.82,
    b = 0.18,
    a = 0.9,
}

local DEFAULT_SPARK_COLOR = {
    r = 1,
    g = 0.88,
    b = 0.34,
    a = 0.95,
}

local DEFAULT_GLOW_STYLE = "classic"
local DEFAULT_SPARK_COUNT = 1
local DEFAULT_SPARK_WIDTH = 12
local DEFAULT_SPARK_HEIGHT = 2
local MIN_SPARK_COUNT = 1
local MAX_SPARK_COUNT = 6
local MIN_SPARK_WIDTH = 4
local MAX_SPARK_WIDTH = 32
local MIN_SPARK_HEIGHT = 1
local MAX_SPARK_HEIGHT = 8

local function ClampNumber(value, minimum, maximum, fallback)
    value = tonumber(value)
    if type(value) ~= "number" then
        value = fallback
    end

    if type(value) ~= "number" then
        value = minimum
    end

    return math.min(maximum, math.max(minimum, value))
end

local function GetModule()
    return T:GetModule("RaidFrames")
end

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().raidFrames then
        ConfigurationModule:GetProfileDB().raidFrames = {}
    end

    return ConfigurationModule:GetProfileDB().raidFrames
end

function Options:GetEnabled(info)
    local db = self:GetDB()
    return db.enabled == true
end

function Options:SetEnabled(info, value)
    local db = self:GetDB()
    db.enabled = value == true

    if value then
        GetModule():Enable()
    else
        GetModule():Disable()
    end
end

function Options:GetDispellableDebuffsHighlightEnabled(info)
    local db = self:GetDB()
    if db.dispellableDebuffsHighlightEnabled == nil then
        return true
    end

    return db.dispellableDebuffsHighlightEnabled == true
end

function Options:SetDispellableDebuffsHighlightEnabled(info, value)
    local db = self:GetDB()
    db.dispellableDebuffsHighlightEnabled = value == true

    if GetModule():IsEnabled() then
        if not value then
            GetModule():StopTest()
        end

        GetModule():Refresh()
    end
end

function Options:GetGlowColor(info)
    local db = self:GetDB()
    local color = db.glowColor or DEFAULT_COLOR
    return color.r, color.g, color.b, color.a
end

function Options:GetSparkColor(info)
    local db = self:GetDB()
    local color = db.sparkColor or DEFAULT_SPARK_COLOR
    return color.r, color.g, color.b, color.a
end

function Options:GetGlowStyle(info)
    local db = self:GetDB()
    local style = db.glowStyle
    if style == nil or style == "" then
        return DEFAULT_GLOW_STYLE
    end

    if style == "button" then
        return "button"
    end

    return DEFAULT_GLOW_STYLE
end

function Options:SetGlowStyle(info, value)
    local db = self:GetDB()
    db.glowStyle = value == "button" and "button" or DEFAULT_GLOW_STYLE

    if GetModule():IsEnabled() then
        GetModule():Refresh()
    end
end

function Options:SetGlowColor(info, r, g, b, a)
    local db = self:GetDB()
    db.glowColor = {
        r = r,
        g = g,
        b = b,
        a = a,
    }

    if GetModule():IsEnabled() then
        GetModule():Refresh()
    end
end

function Options:SetSparkColor(info, r, g, b, a)
    local db = self:GetDB()
    db.sparkColor = {
        r = r,
        g = g,
        b = b,
        a = a,
    }

    if GetModule():IsEnabled() then
        GetModule():Refresh()
    end
end

function Options:GetSparkCount(info)
    local db = self:GetDB()
    return ClampNumber(db.sparkCount, MIN_SPARK_COUNT, MAX_SPARK_COUNT, DEFAULT_SPARK_COUNT)
end

function Options:SetSparkCount(info, value)
    local db = self:GetDB()
    db.sparkCount = math.floor(ClampNumber(value, MIN_SPARK_COUNT, MAX_SPARK_COUNT, DEFAULT_SPARK_COUNT) + 0.5)

    if GetModule():IsEnabled() then
        GetModule():Refresh()
    end
end

function Options:GetSparkWidth(info)
    local db = self:GetDB()
    return ClampNumber(db.sparkWidth, MIN_SPARK_WIDTH, MAX_SPARK_WIDTH, DEFAULT_SPARK_WIDTH)
end

function Options:SetSparkWidth(info, value)
    local db = self:GetDB()
    db.sparkWidth = math.floor(ClampNumber(value, MIN_SPARK_WIDTH, MAX_SPARK_WIDTH, DEFAULT_SPARK_WIDTH) + 0.5)

    if GetModule():IsEnabled() then
        GetModule():Refresh()
    end
end

function Options:GetSparkHeight(info)
    local db = self:GetDB()
    return ClampNumber(db.sparkHeight, MIN_SPARK_HEIGHT, MAX_SPARK_HEIGHT, DEFAULT_SPARK_HEIGHT)
end

function Options:SetSparkHeight(info, value)
    local db = self:GetDB()
    db.sparkHeight = math.floor(ClampNumber(value, MIN_SPARK_HEIGHT, MAX_SPARK_HEIGHT, DEFAULT_SPARK_HEIGHT) + 0.5)

    if GetModule():IsEnabled() then
        GetModule():Refresh()
    end
end

function Options:TestGlow()
    if GetModule():IsEnabled() and self:GetDispellableDebuffsHighlightEnabled() then
        GetModule():StartTest(8)
    end
end
