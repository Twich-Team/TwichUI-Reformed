---@diagnostic disable: undefined-field
--[[
    Options for the Chores module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class ChoresConfigurationOptions
local Options = ConfigurationModule.Options.Chores or {}
ConfigurationModule.Options.Chores = Options

local function RefreshChores()
    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if choresModule and choresModule.RequestRefresh then
        choresModule:RequestRefresh(true)
    end

    ---@type DataTextModule
    local datatextModule = T:GetModule("Datatexts")
    if datatextModule and datatextModule.RefreshDataText then
        datatextModule:RefreshDataText("TwichUI: Chores")
    end
end

local function GetTrackerFrameDB()
    local datatextOptions = ConfigurationModule.Options.Datatext
    local db = datatextOptions and datatextOptions.GetDatatextDB and datatextOptions:GetDatatextDB("chores") or nil
    if not db then
        ConfigurationModule:GetProfileDB().datatext = ConfigurationModule:GetProfileDB().datatext or {}
        ConfigurationModule:GetProfileDB().datatext.chores = ConfigurationModule:GetProfileDB().datatext.chores or {}
        db = ConfigurationModule:GetProfileDB().datatext.chores
    end

    return db
end

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().chores then
        ConfigurationModule:GetProfileDB().chores = {}
    end
    return ConfigurationModule:GetProfileDB().chores
end

function Options:GetCategoryDB()
    local db = self:GetDB()
    if not db.categories then
        db.categories = {}
    end
    return db.categories
end

function Options:GetRaidWingDB()
    local db = self:GetDB()
    if not db.raidWings then
        db.raidWings = {}
    end
    return db.raidWings
end

function Options:GetPreyDifficultyDB()
    local db = self:GetDB()
    if not db.preyDifficulties then
        db.preyDifficulties = {}
    end
    return db.preyDifficulties
end

function Options:GetEnabled(info)
    local enabled = self:GetDB().enabled
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetEnabled(info, value)
    self:GetDB().enabled = value

    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if value then
        choresModule:Enable()
        choresModule:RequestRefresh(true)
    else
        choresModule:Disable()
    end

    RefreshChores()
end

function Options:GetShowCompleted(info)
    return self:GetDB().showCompleted == true
end

function Options:SetShowCompleted(info, value)
    self:GetDB().showCompleted = value == true
    RefreshChores()
end

function Options:GetTrackBountifulDelves(info)
    local enabled = self:GetDB().trackBountifulDelves
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetTrackBountifulDelves(info, value)
    self:GetDB().trackBountifulDelves = value == true
    RefreshChores()
end

function Options:GetOnlyTrackBountifulDelvesWithKey(info)
    return self:GetDB().onlyTrackBountifulDelvesWithKey == true
end

function Options:SetOnlyTrackBountifulDelvesWithKey(info, value)
    self:GetDB().onlyTrackBountifulDelvesWithKey = value == true
    RefreshChores()
end

function Options:GetTrackPrey(info)
    local enabled = self:GetDB().trackPrey
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetTrackPrey(info, value)
    self:GetDB().trackPrey = value == true
    RefreshChores()
end

function Options:GetCountProfessionsTowardTotal(info)
    local enabled = self:GetDB().countProfessionsTowardTotal
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetCountProfessionsTowardTotal(info, value)
    self:GetDB().countProfessionsTowardTotal = value == true
    RefreshChores()
end

function Options:GetCountPreyTowardTotal(info)
    local enabled = self:GetDB().countPreyTowardTotal
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetCountPreyTowardTotal(info, value)
    self:GetDB().countPreyTowardTotal = value == true
    RefreshChores()
end

function Options:GetCountBountifulDelvesTowardTotal(info)
    local enabled = self:GetDB().countBountifulDelvesTowardTotal
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetCountBountifulDelvesTowardTotal(info, value)
    self:GetDB().countBountifulDelvesTowardTotal = value == true
    RefreshChores()
end

function Options:IsCategoryEnabled(categoryKey)
    local enabled = self:GetCategoryDB()[categoryKey]
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetCategoryEnabled(categoryKey, value)
    self:GetCategoryDB()[categoryKey] = value
    RefreshChores()
end

function Options:IsPreyDifficultyEnabled(difficultyKey)
    local enabled = self:GetPreyDifficultyDB()[difficultyKey]
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetPreyDifficultyEnabled(difficultyKey, value)
    self:GetPreyDifficultyDB()[difficultyKey] = value == true
    RefreshChores()
end

function Options:IsRaidWingEnabled(dungeonID)
    local enabled = self:GetRaidWingDB()[tostring(dungeonID)]
    if enabled == nil then
        return true
    end
    return enabled
end

function Options:SetRaidWingEnabled(dungeonID, value)
    self:GetRaidWingDB()[tostring(dungeonID)] = value == true
    RefreshChores()
end

function Options:GetTrackerFrameMode(info)
    return GetTrackerFrameDB().trackerMode or "framed"
end

function Options:SetTrackerFrameMode(info, value)
    GetTrackerFrameDB().trackerMode = value or "framed"
    RefreshChores()
end

function Options:GetTrackerFrameTransparency(info)
    local value = GetTrackerFrameDB().trackerFrameTransparency
    if type(value) ~= "number" then
        return 1
    end

    return math.min(1, math.max(0.2, value))
end

function Options:SetTrackerFrameTransparency(info, value)
    GetTrackerFrameDB().trackerFrameTransparency = math.min(1, math.max(0.2, tonumber(value) or 1))
    RefreshChores()
end

function Options:GetTrackerBackgroundTransparency(info)
    local value = GetTrackerFrameDB().trackerBackgroundTransparency
    if type(value) ~= "number" then
        return 0.95
    end

    return math.min(1, math.max(0, value))
end

function Options:SetTrackerBackgroundTransparency(info, value)
    GetTrackerFrameDB().trackerBackgroundTransparency = math.min(1, math.max(0, tonumber(value) or 0.95))
    RefreshChores()
end

function Options:GetTrackerHeaderFont(info)
    return GetTrackerFrameDB().trackerHeaderFont or "__tooltipHeader"
end

function Options:SetTrackerHeaderFont(info, value)
    GetTrackerFrameDB().trackerHeaderFont = value or "__tooltipHeader"
    RefreshChores()
end

function Options:GetTrackerFrameConfigKeybinding(info)
    return self:GetDB().trackerFrameConfigKeybinding or ""
end

function Options:SetTrackerFrameConfigKeybinding(info, value)
    self:GetDB().trackerFrameConfigKeybinding = value or ""

    local configurationModule = T:GetModule("Configuration")
    if configurationModule and configurationModule.SetChoresTrackerConfigKeybinding then
        configurationModule:SetChoresTrackerConfigKeybinding()
    end
end
