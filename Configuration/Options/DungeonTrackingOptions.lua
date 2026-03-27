---@diagnostic disable: undefined-field, inject-field
--[[
    Options for the Dungeon Tracking module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class DungeonTrackingConfigurationOptions
local Options = ConfigurationModule.Options.DungeonTracking or {}
ConfigurationModule.Options.DungeonTracking = Options

local DEFAULT_SOUND = "TwichUI Alert 1"
local DEFAULT_NOTIFICATION_DISPLAY_TIME = 10
local DEFAULT_CLASS_ICON_STYLE = "default"

local function TrimText(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().dungeonTracking then
        ConfigurationModule:GetProfileDB().dungeonTracking = {}
    end
    return ConfigurationModule:GetProfileDB().dungeonTracking
end

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("DungeonTracking")
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

function Options:GetSound(info)
    local db = self:GetDB()
    return db.sound or DEFAULT_SOUND
end

function Options:SetSound(info, value)
    local db = self:GetDB()
    db.sound = value
end

function Options:GetNotificationDisplayTime(info)
    local db = self:GetDB()
    return db.notificationDisplayTime or DEFAULT_NOTIFICATION_DISPLAY_TIME
end

function Options:SetNotificationDisplayTime(info, value)
    local db = self:GetDB()
    db.notificationDisplayTime = value
end

function Options:GetClassIconStyle(info)
    local db = self:GetDB()
    local val = db.classIconStyle
    if val then return val end
    local theme = T:GetModule("Theme", true)
    return (theme and theme:Get("classIconStyle")) or DEFAULT_CLASS_ICON_STYLE
end

function Options:SetClassIconStyle(info, value)
    local db = self:GetDB()
    db.classIconStyle = value or DEFAULT_CLASS_ICON_STYLE
end

function Options:GetShowLeaveGroupButton(info)
    local db = self:GetDB()
    if db.showLeaveGroupButton == nil then
        return true
    end

    return db.showLeaveGroupButton == true
end

function Options:SetShowLeaveGroupButton(info, value)
    local db = self:GetDB()
    db.showLeaveGroupButton = value == true
end

function Options:GetLeavePhrase(info)
    local db = self:GetDB()
    return db.leavePhrase or ""
end

function Options:SetLeavePhrase(info, value)
    local db = self:GetDB()
    local trimmedValue = TrimText(value)
    db.leavePhrase = trimmedValue ~= "" and trimmedValue or nil
end

function Options:TestNotification()
    GetModule():TestNotification()
end

function Options:TestMythicNotification()
    GetModule():TestMythicNotification()
end
