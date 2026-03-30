--[[
    Options for the QuestLogCleaner module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class SatchelWatchConfigurationOptions
local Options = ConfigurationModule.Options.SatchelWatch or {}
ConfigurationModule.Options.SatchelWatch = Options

---@return table satchelWatchDB the profile-level satchel watch configuration database.
function Options:GetSatchelWatchDB()
    if not ConfigurationModule:GetProfileDB().satchelWatch then
        ConfigurationModule:GetProfileDB().satchelWatch = {}
    end
    return ConfigurationModule:GetProfileDB().satchelWatch
end

function Options:GetIgnoredDungeonIDs()
    local db = self:GetSatchelWatchDB()
    db.ignoredDungeonIDs = db.ignoredDungeonIDs or {}
    return db.ignoredDungeonIDs
end

local function GetModule()
    ---@type SatchelWatchModule
    return T:GetModule("QualityOfLife"):GetModule("SatchelWatch")
end

local function RefreshPeriodicTimer()
    local module = GetModule()
    if module and module:IsEnabled() then
        module:StartPeriodicRefresh()
    end
end

function Options:GetEnabled(info)
    local db = self:GetSatchelWatchDB()
    return db.enabled or false
end

function Options:SetEnabled(info, value)
    local db = self:GetSatchelWatchDB()
    db.enabled = value

    if value then
        GetModule():Enable()
    else
        GetModule():Disable()
    end
end

function Options:GetNotifyForDPS(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForDPS or false
end

function Options:SetNotifyForDPS(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForDPS = value
    RefreshPeriodicTimer()
end

function Options:GetNotifyForHealers(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForHealers or false
end

function Options:SetNotifyForHealers(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForHealers = value
    RefreshPeriodicTimer()
end

function Options:GetNotifyForTanks(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForTanks or false
end

function Options:SetNotifyForTanks(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForTanks = value
    RefreshPeriodicTimer()
end

function Options:GetRoleIconType(info)
    local db = self:GetSatchelWatchDB()
    return db.roleIconType or "standard"
end

function Options:SetRoleIconType(info, value)
    local db = self:GetSatchelWatchDB()
    db.roleIconType = value == "twich" and "twich" or "standard"
end

function Options:GetNotifyOnlyWhenNotInGroup(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyOnlyWhenNotInGroup or false
end

function Options:SetNotifyOnlyWhenNotInGroup(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyOnlyWhenNotInGroup = value
    RefreshPeriodicTimer()
end

function Options:GetNotifyOnlyWhenNotCompleted(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyOnlyWhenNotCompleted or false
end

function Options:SetNotifyOnlyWhenNotCompleted(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyOnlyWhenNotCompleted = value
    RefreshPeriodicTimer()
end

function Options:GetNotifyForRegularDungeon(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForRegularDungeon or false
end

function Options:SetNotifyForRegularDungeon(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForRegularDungeon = value
    RefreshPeriodicTimer()
end

function Options:GetNotifyForHeroicDungeon(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyForHeroicDungeon or false
end

function Options:SetNotifyForHeroicDungeon(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyForHeroicDungeon = value
    RefreshPeriodicTimer()
end

function Options:GetNotifyOnlyForRaids(info)
    local db = self:GetSatchelWatchDB()
    return db.notifyOnlyForRaids or false
end

function Options:SetNotifyOnlyForRaids(info, value)
    local db = self:GetSatchelWatchDB()
    db.notifyOnlyForRaids = value
    RefreshPeriodicTimer()
end

function Options:GetSound(info)
    local db = self:GetSatchelWatchDB()
    return db.sound or "TwichUI Alert 2"
end

function Options:SetSound(info, value)
    local db = self:GetSatchelWatchDB()
    db.sound = value
end

function Options:GetNotificationDisplayTime(info)
    local db = self:GetSatchelWatchDB()
    return db.notificationDisplayTime or 10
end

function Options:SetNotificationDisplayTime(info, value)
    local db = self:GetSatchelWatchDB()
    db.notificationDisplayTime = value
end

function Options:GetPeriodicCheckEnabled(info)
    local db = self:GetSatchelWatchDB()
    return db.periodicCheckEnabled == true
end

function Options:SetPeriodicCheckEnabled(info, value)
    local db = self:GetSatchelWatchDB()
    db.periodicCheckEnabled = value == true
    RefreshPeriodicTimer()
end

function Options:GetPeriodicCheckInterval(info)
    local db = self:GetSatchelWatchDB()
    local intervalSeconds = tonumber(db.periodicCheckIntervalSeconds)

    if not intervalSeconds then
        return 30
    end

    return math.max(30, math.min(60, intervalSeconds))
end

function Options:SetPeriodicCheckInterval(info, value)
    local db = self:GetSatchelWatchDB()
    db.periodicCheckIntervalSeconds = math.max(30, math.min(60, tonumber(value) or 30))
    RefreshPeriodicTimer()
end

function Options:GetRaidWingEnabled(info)
    local db = self:GetSatchelWatchDB()
    local dungeonID = tonumber(info[#info])
    return db["raid_" .. dungeonID] or false
end

function Options:SetRaidWingEnabled(info, value)
    local db = self:GetSatchelWatchDB()
    local dungeonID = tonumber(info[#info])
    db["raid_" .. dungeonID] = value
    RefreshPeriodicTimer()
end

function Options:TestNotification()
    GetModule():TestNotification()
end

function Options:ResetIgnoredEntries()
    local db = self:GetSatchelWatchDB()
    db.ignoredDungeonIDs = {}
    RefreshPeriodicTimer()
end
