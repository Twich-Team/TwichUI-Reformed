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

function Options:TestGlow()
    if GetModule():IsEnabled() and self:GetDispellableDebuffsHighlightEnabled() then
        GetModule():StartTest(8)
    end
end
