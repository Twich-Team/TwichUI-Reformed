--[[
    Options for the Best In Slot module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class BestInSlotConfigurationOptions
local Options = ConfigurationModule.Options.BestInSlot or {}
ConfigurationModule.Options.BestInSlot = Options

---@return table bestInSlotDB the profile-level best in slot configuration database.
function Options:GetBestInSlotDB()
    if not ConfigurationModule:GetProfileDB().bestInSlot then
        ConfigurationModule:GetProfileDB().bestInSlot = {}
    end
    return ConfigurationModule:GetProfileDB().bestInSlot
end

---@return BestInSlotModule
local function GetModule()
    ---@type BestInSlotModule
    return T:GetModule("BestInSlot")
end

function Options:IsBestInSlotModuleEnabled(info)
    local db = self:GetBestInSlotDB()
    return db.enabled == true
end

function Options:SetBestInSlotModuleEnabled(info, enabled)
    local db = self:GetBestInSlotDB()
    db.enabled = enabled

    if enabled then
        GetModule():Enable()
    else
        GetModule():Disable()
    end
end

function Options:GetMonitorReceivedItems(info)
    local db = self:GetBestInSlotDB()
    return db.monitorReceivedItems ~= false
end

function Options:SetMonitorReceivedItems(info, monitorReceivedItems)
    local db = self:GetBestInSlotDB()
    db.monitorReceivedItems = monitorReceivedItems

    if monitorReceivedItems then
        GetModule():GetModule("MonitorLootedItems"):Enable()
    else
        GetModule():GetModule("MonitorLootedItems"):Disable()
    end
end

function Options:GetMonitorDroppedItems(info)
    local db = self:GetBestInSlotDB()
    return db.monitorDroppedItems ~= false
end

function Options:SetMonitorDroppedItems(info, monitorDroppedItems)
    local db = self:GetBestInSlotDB()
    db.monitorDroppedItems = monitorDroppedItems

    if monitorDroppedItems then
        GetModule():GetModule("MonitorDroppedItems"):Enable()
    else
        GetModule():GetModule("MonitorDroppedItems"):Disable()
    end
end

function Options:GetMonitorGreatVaultItems(info)
    local db = self:GetBestInSlotDB()
    return db.monitorGreatVaultItems ~= false
end

function Options:SetMonitorGreatVaultItems(info, monitorGreatVaultItems)
    local db = self:GetBestInSlotDB()
    db.monitorGreatVaultItems = monitorGreatVaultItems

    if monitorGreatVaultItems then
        GetModule():GetModule("MonitorGreatVaultItems"):Enable()
    else
        GetModule():GetModule("MonitorGreatVaultItems"):Disable()
    end
end

function Options:GetAquiredSound(info)
    local db = self:GetBestInSlotDB()
    return db.aquiredSound or "TwichUI Green Dude Gets Loot"
end

function Options:SetAquiredSound(info, value)
    local db = self:GetBestInSlotDB()
    db.aquiredSound = value
end

function Options:GetAvailableSound(info)
    local db = self:GetBestInSlotDB()
    return db.availableSound or "TwichUI Notification 8"
end

function Options:SetAvailableSound(info, value)
    local db = self:GetBestInSlotDB()
    db.availableSound = value
end

function Options:IsSoundEnabled(info)
    local db = self:GetBestInSlotDB()
    return db.soundEnabled or false
end

function Options:SetSoundEnabled(info, value)
    local db = self:GetBestInSlotDB()
    db.soundEnabled = value
end

function Options:GetNotificationDisplayTime(info)
    local db = self:GetBestInSlotDB()
    return db.displayTime or 10
end

function Options:SetNotificationDisplayTime(info, value)
    local db = self:GetBestInSlotDB()
    db.displayTime = value
end

function Options:IsGreatVaultHighlightEnabled(info)
    local db = self:GetBestInSlotDB()
    return db.greatVaultHighlightEnabled ~= false
end

function Options:SetGreatVaultHighlightEnabled(info, value)
    local db = self:GetBestInSlotDB()
    db.greatVaultHighlightEnabled = value

    if value then
        GetModule():GetModule("GreatVaultEnhancement"):Enable()
    else
        GetModule():GetModule("GreatVaultEnhancement"):Disable()
    end
end

function Options:SetGreatVaultHighlightColor(info, r, g, b, a)
    local db = self:GetBestInSlotDB()
    db.greatVaultHighlightColor = { r = r, g = g, b = b, a = a }
end

function Options:GetGreatVaultHighlightColor(info)
    local db = self:GetBestInSlotDB()
    local color = db.greatVaultHighlightColor or { r = 1, g = 0.8, b = 0, a = 0.8 }
    return color.r, color.g, color.b, color.a
end
