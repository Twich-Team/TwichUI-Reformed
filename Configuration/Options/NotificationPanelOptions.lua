--[[
    Options for the notification panel module.
]]
local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class NotificationPanelConfigurationOptions
local Options = ConfigurationModule.Options.NotificationPanel or {}
ConfigurationModule.Options.NotificationPanel = Options

local DEFAULT_SOUND = "TwichUI Alert 1"
local DEFAULT_FRIENDS_DISPLAY_DURATION = 10
local DEFAULT_FRIENDS_ICON_STYLE = "default"
local DEFAULT_KEYSTONE_DISPLAY_DURATION = 15
local DEFAULT_GREAT_VAULT_DISPLAY_DURATION = 10
local DEFAULT_DAILY_RESET_DISPLAY_DURATION = 10
local DEFAULT_GROUP_FINDER_DISPLAY_DURATION = 10
local DEFAULT_CHORES_DISPLAY_DURATION = 15
local DEFAULT_NOTIFICATION_FONT = "__default"
local DEFAULT_NOTIFICATION_FONT_SIZE_ADJUSTMENT = 0


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

local function GetToastsModule()
    ---@type ToastsModule
    return T:GetModule("ToastsModule")
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

function Options:GetNotificationFont(info)
    local db = self:GetDB()
    return db.notificationFont or DEFAULT_NOTIFICATION_FONT
end

function Options:SetNotificationFont(info, value)
    local db = self:GetDB()
    db.notificationFont = value
    RefreshFrame()
end

function Options:GetNotificationFontSizeAdjustment(info)
    local db = self:GetDB()
    return db.notificationFontSizeAdjustment or DEFAULT_NOTIFICATION_FONT_SIZE_ADJUSTMENT
end

function Options:SetNotificationFontSizeAdjustment(info, value)
    local db = self:GetDB()
    db.notificationFontSizeAdjustment = value
    RefreshFrame()
end

function Options:GetEnableFriendsNotifications(info)
    local db = self:GetDB()
    if db.enableFriendsNotifications == nil then
        return true
    end
    return db.enableFriendsNotifications
end

function Options:SetEnableFriendsNotifications(info, value)
    local db = self:GetDB()
    db.enableFriendsNotifications = value
    GetToastsModule():SyncBlizzardFriendToasts()
end

function Options:GetUseFriendNoteAsName(info)
    local db = self:GetDB()
    return db.useFriendNoteAsName or false
end

function Options:SetUseFriendNoteAsName(info, value)
    local db = self:GetDB()
    db.useFriendNoteAsName = value
end

function Options:GetFriendsNotificationDisplayTime(info)
    local db = self:GetDB()
    return db.friendsNotificationDisplayTime or DEFAULT_FRIENDS_DISPLAY_DURATION
end

function Options:SetFriendsNotificationDisplayTime(info, value)
    local db = self:GetDB()
    db.friendsNotificationDisplayTime = value
end

function Options:GetFriendsNotificationSound(info)
    local db = self:GetDB()
    return db.friendsNotificationSound or DEFAULT_SOUND
end

function Options:SetFriendsNotificationSound(info, value)
    local db = self:GetDB()
    db.friendsNotificationSound = value
end

function Options:GetFriendsNotificationIconStyle(info)
    local db = self:GetDB()
    return db.friendsNotificationIconStyle or DEFAULT_FRIENDS_ICON_STYLE
end

function Options:SetFriendsNotificationIconStyle(info, value)
    local db = self:GetDB()
    db.friendsNotificationIconStyle = value
end

function Options:GetEnableKeystoneNotifications(info)
    local db = self:GetDB()
    if db.enableKeystoneNotifications == nil then
        return true
    end
    return db.enableKeystoneNotifications
end

function Options:SetEnableKeystoneNotifications(info, value)
    local db = self:GetDB()
    db.enableKeystoneNotifications = value
end

function Options:GetKeystoneNotificationDisplayTime(info)
    local db = self:GetDB()
    return db.keystoneNotificationDisplayTime or DEFAULT_KEYSTONE_DISPLAY_DURATION
end

function Options:SetKeystoneNotificationDisplayTime(info, value)
    local db = self:GetDB()
    db.keystoneNotificationDisplayTime = value
end

function Options:GetKeystoneNotificationSound(info)
    local db = self:GetDB()
    return db.keystoneNotificationSound or DEFAULT_SOUND
end

function Options:SetKeystoneNotificationSound(info, value)
    local db = self:GetDB()
    db.keystoneNotificationSound = value
end

function Options:GetEnableGreatVaultNotifications(info)
    local db = self:GetDB()
    if db.enableGreatVaultNotifications == nil then
        return true
    end
    return db.enableGreatVaultNotifications
end

function Options:SetEnableGreatVaultNotifications(info, value)
    local db = self:GetDB()
    db.enableGreatVaultNotifications = value
end

function Options:GetGreatVaultNotificationDisplayTime(info)
    local db = self:GetDB()
    return db.greatVaultNotificationDisplayTime or DEFAULT_GREAT_VAULT_DISPLAY_DURATION
end

function Options:SetGreatVaultNotificationDisplayTime(info, value)
    local db = self:GetDB()
    db.greatVaultNotificationDisplayTime = value
end

function Options:GetGreatVaultNotificationSound(info)
    local db = self:GetDB()
    return db.greatVaultNotificationSound or DEFAULT_SOUND
end

function Options:SetGreatVaultNotificationSound(info, value)
    local db = self:GetDB()
    db.greatVaultNotificationSound = value
end

function Options:GetEnableDailyResetNotifications(info)
    local db = self:GetDB()
    if db.enableDailyResetNotifications == nil then
        return true
    end
    return db.enableDailyResetNotifications
end

function Options:SetEnableDailyResetNotifications(info, value)
    local db = self:GetDB()
    db.enableDailyResetNotifications = value
end

function Options:GetDailyResetNotificationDisplayTime(info)
    local db = self:GetDB()
    return db.dailyResetNotificationDisplayTime or DEFAULT_DAILY_RESET_DISPLAY_DURATION
end

function Options:SetDailyResetNotificationDisplayTime(info, value)
    local db = self:GetDB()
    db.dailyResetNotificationDisplayTime = value
end

function Options:GetDailyResetNotificationSound(info)
    local db = self:GetDB()
    return db.dailyResetNotificationSound or DEFAULT_SOUND
end

function Options:SetDailyResetNotificationSound(info, value)
    local db = self:GetDB()
    db.dailyResetNotificationSound = value
end

function Options:GetEnableGroupFinderNotifications(info)
    local db = self:GetDB()
    if db.enableGroupFinderNotifications == nil then
        return true
    end
    return db.enableGroupFinderNotifications
end

function Options:SetEnableGroupFinderNotifications(info, value)
    local db = self:GetDB()
    db.enableGroupFinderNotifications = value
end

function Options:GetGroupFinderNotificationDisplayTime(info)
    local db = self:GetDB()
    return db.groupFinderNotificationDisplayTime or DEFAULT_GROUP_FINDER_DISPLAY_DURATION
end

function Options:SetGroupFinderNotificationDisplayTime(info, value)
    local db = self:GetDB()
    db.groupFinderNotificationDisplayTime = value
end

function Options:GetGroupFinderNotificationSound(info)
    local db = self:GetDB()
    return db.groupFinderNotificationSound or DEFAULT_SOUND
end

function Options:SetGroupFinderNotificationSound(info, value)
    local db = self:GetDB()
    db.groupFinderNotificationSound = value
end

function Options:GetEnableChoresNotifications(info)
    local db = self:GetDB()
    if db.enableChoresNotifications == nil then
        return true
    end
    return db.enableChoresNotifications
end

function Options:SetEnableChoresNotifications(info, value)
    local db = self:GetDB()
    db.enableChoresNotifications = value
end

function Options:GetChoresNotificationDisplayTime(info)
    local db = self:GetDB()
    return db.choresNotificationDisplayTime or DEFAULT_CHORES_DISPLAY_DURATION
end

function Options:SetChoresNotificationDisplayTime(info, value)
    local db = self:GetDB()
    db.choresNotificationDisplayTime = value
end

function Options:GetChoresNotificationSound(info)
    local db = self:GetDB()
    return db.choresNotificationSound or DEFAULT_SOUND
end

function Options:SetChoresNotificationSound(info, value)
    local db = self:GetDB()
    db.choresNotificationSound = value
end

function Options:TestFriendsNotification()
    GetToastsModule():TestFriendNotification()
end

function Options:TestKeystoneNotification()
    GetToastsModule():TestKeystoneNotification()
end

function Options:TestGreatVaultNotification()
    GetToastsModule():TestGreatVaultNotification()
end

function Options:TestDailyResetNotification()
    GetToastsModule():TestDailyResetNotification()
end

function Options:TestGroupFinderNotification()
    GetToastsModule():TestGroupFinderNotification()
end

function Options:TestChoresNotification()
    GetToastsModule():TestChoresNotification()
end
