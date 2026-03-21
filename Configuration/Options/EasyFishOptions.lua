---@diagnostic disable: undefined-field, inject-field
--[[
    Options for the EasyFish module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class EasyFishConfigurationOptions
local Options = ConfigurationModule.Options.EasyFish or {}
ConfigurationModule.Options.EasyFish = Options

local DEFAULT_ENHANCED_SOUNDS_SCALE = 1

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().easyFish then
        ConfigurationModule:GetProfileDB().easyFish = {}
    end
    return ConfigurationModule:GetProfileDB().easyFish
end

function Options:GetEnabled(info)
    return self:GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    self:GetDB().enabled = value == true

    ---@type EasyFishModule
    local easyFish = T:GetModule("EasyFish")
    if value then
        easyFish:Enable()
    else
        easyFish:Disable()
    end
end

function Options:GetEasyFishKeybinding(info)
    return self:GetDB().keybinding or ""
end

function Options:SetEasyFishKeybinding(info, value)
    self:GetDB().keybinding = value

    ---@type EasyFishModule
    local easyFish = T:GetModule("EasyFish")
    easyFish:SetKeybinding()
end

function Options:GetMuteOtherSounds(info)
    local value = self:GetDB().muteOtherSounds
    if value == nil then
        return true
    end
    return value == true
end

function Options:SetMuteOtherSounds(info, value)
    self:GetDB().muteOtherSounds = value == true

    ---@type EasyFishModule
    local easyFish = T:GetModule("EasyFish")
    if easyFish and easyFish.RefreshFishingState then
        easyFish:RefreshFishingState()
    end
end

function Options:GetEnhancedSoundsScale(info)
    local value = self:GetDB().enhancedSoundsScale
    if type(value) ~= "number" then
        return DEFAULT_ENHANCED_SOUNDS_SCALE
    end
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

function Options:SetEnhancedSoundsScale(info, value)
    if type(value) ~= "number" then
        value = DEFAULT_ENHANCED_SOUNDS_SCALE
    end

    value = math.max(0, math.min(1, value))
    self:GetDB().enhancedSoundsScale = value

    ---@type EasyFishModule
    local easyFish = T:GetModule("EasyFish")
    if easyFish and easyFish.RefreshFishingState then
        easyFish:RefreshFishingState()
    end
end
