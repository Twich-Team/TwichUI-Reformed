--[[
    Options for the notification panel module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class NotificationPanelConfigurationOptions
local Options = ConfigurationModule.Options.NotificationPanel or {}
ConfigurationModule.Options.NotificationPanel = Options

local DEFAULT_SOUND = "TwichUI Chat Ping"


function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().notificationPanel then
        ConfigurationModule:GetProfileDB().notificationPanel = {}
    end
    return ConfigurationModule:GetProfileDB().notificationPanel
end

local function GetModule()
    ---@type NotificationModule
    return T:GetModule("Notification")
end

local function RefreshFrame()
    GetModule().Frame:Refresh()
end

function Options:GetGrowthDirection(info)
    local db = self:GetDB()
    return db.growthDirection or "DOWN"
end

function Options:SetGrowthDirection(info, value)
    local db = self:GetDB()
    db.growthDirection = value
    RefreshFrame()
end

function Options:SetPanelWidth(info, value)
    local db = self:GetDB()
    db.panelWidth = value
    RefreshFrame()
end

function Options:GetPanelWidth(info)
    local db = self:GetDB()
    return db.panelWidth or 300
end
