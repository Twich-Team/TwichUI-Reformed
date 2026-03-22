---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class TeleportsConfigurationOptions
local Options = ConfigurationModule.Options.Teleports or {}
ConfigurationModule.Options.Teleports = Options

local DEFAULTS = {
    enabled = false,
    showWorldMapTab = true,
    showDatatextPopup = true,
    showOnlyKnown = true,
    showHearthstones = true,
    showUtilityTeleports = true,
    datatextIncludeRaids = true,
}

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("Teleports")
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if not profile.teleports then
        profile.teleports = {}
    end

    return profile.teleports
end

function Options:RefreshModule()
    local module = GetModule()
    if module and module:IsEnabled() and module.RefreshNow then
        module:RefreshNow("options")
    end
end

function Options:GetEnabled()
    return self:GetDB().enabled == true
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

function Options:GetShowWorldMapTab()
    local value = self:GetDB().showWorldMapTab
    if value == nil then
        return DEFAULTS.showWorldMapTab
    end

    return value == true
end

function Options:SetShowWorldMapTab(info, value)
    self:GetDB().showWorldMapTab = value == true
    self:RefreshModule()
end

function Options:GetShowDatatextPopup()
    local value = self:GetDB().showDatatextPopup
    if value == nil then
        return DEFAULTS.showDatatextPopup
    end

    return value == true
end

function Options:SetShowDatatextPopup(info, value)
    self:GetDB().showDatatextPopup = value == true
    self:RefreshModule()
end

function Options:GetShowOnlyKnown()
    local value = self:GetDB().showOnlyKnown
    if value == nil then
        return DEFAULTS.showOnlyKnown
    end

    return value == true
end

function Options:SetShowOnlyKnown(info, value)
    self:GetDB().showOnlyKnown = value == true
    self:RefreshModule()
end

function Options:GetShowHearthstones()
    local value = self:GetDB().showHearthstones
    if value == nil then
        return DEFAULTS.showHearthstones
    end

    return value == true
end

function Options:SetShowHearthstones(info, value)
    self:GetDB().showHearthstones = value == true
    self:RefreshModule()
end

function Options:GetShowUtilityTeleports()
    local value = self:GetDB().showUtilityTeleports
    if value == nil then
        return DEFAULTS.showUtilityTeleports
    end

    return value == true
end

function Options:SetShowUtilityTeleports(info, value)
    self:GetDB().showUtilityTeleports = value == true
    self:RefreshModule()
end

function Options:GetDatatextIncludeRaids()
    local value = self:GetDB().datatextIncludeRaids
    if value == nil then
        return DEFAULTS.datatextIncludeRaids
    end

    return value == true
end

function Options:SetDatatextIncludeRaids(info, value)
    self:GetDB().datatextIncludeRaids = value == true
    self:RefreshModule()
end

function Options:OpenPreview()
    local module = GetModule()
    if not module:IsEnabled() then
        module:Enable()
    end

    if module.OpenStandaloneBrowser then
        module:OpenStandaloneBrowser()
    end
end

function Options:ClosePreview()
    local module = GetModule()
    if module and module.HideDatatextPopup then
        module:HideDatatextPopup()
    end
end
