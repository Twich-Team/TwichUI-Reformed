---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class WorldQuestsConfigurationOptions
local Options = ConfigurationModule.Options.WorldQuests or {}
ConfigurationModule.Options.WorldQuests = Options

local DEFAULTS = {
    enabled = false,
    showWorldMapTab = true,
    onlyCurrentZone = true,
    showChildZonesOnParentMaps = true,
    hideFilteredPOI = true,
    hideUntrackedPOI = false,
    showHoveredPOI = true,
    timeFilterHours = 8,
    sortMethod = "time",
    enabledFilters = {
        tracked = true,
        gear = true,
        gold = true,
        reputation = true,
        items = true,
        profession = true,
        pvp = true,
        pet = true,
        dungeon = true,
        rare = true,
        time = true,
    },
    selectedFilters = {},
}

local function GetModule()
    local qol = T:GetModule("QualityOfLife")
    return qol and qol.GetModule and qol:GetModule("WorldQuests", true) or nil
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.worldQuests) ~= "table" then
        profile.worldQuests = {}
    end

    local db = profile.worldQuests
    if type(db.enabledFilters) ~= "table" then
        db.enabledFilters = CopyTable(DEFAULTS.enabledFilters)
    end
    if type(db.selectedFilters) ~= "table" then
        db.selectedFilters = CopyTable(DEFAULTS.selectedFilters)
    end

    return db
end

function Options:RefreshModule(reason)
    local module = GetModule()
    if module and module.RefreshNow then
        if module:IsEnabled() then
            module:RefreshNow(reason or "options")
        elseif self:GetEnabled() then
            module:Enable()
        end
    end
end

function Options:GetEnabled()
    return self:GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    local module = GetModule()
    self:GetDB().enabled = value == true

    if value == true then
        if module and not module:IsEnabled() then
            module:Enable()
        end
    elseif module and module:IsEnabled() then
        module:Disable()
    end
end

local function GetBooleanSetting(self, key)
    local value = self:GetDB()[key]
    if value == nil then
        return DEFAULTS[key] == true
    end

    return value == true
end

local function SetBooleanSetting(self, key, value)
    self:GetDB()[key] = value == true
    self:RefreshModule(key)
end

function Options:GetShowWorldMapTab()
    return GetBooleanSetting(self, "showWorldMapTab")
end

function Options:SetShowWorldMapTab(info, value)
    SetBooleanSetting(self, "showWorldMapTab", value)
end

function Options:GetOnlyCurrentZone()
    return GetBooleanSetting(self, "onlyCurrentZone")
end

function Options:SetOnlyCurrentZone(info, value)
    SetBooleanSetting(self, "onlyCurrentZone", value)
end

function Options:GetShowChildZonesOnParentMaps()
    return GetBooleanSetting(self, "showChildZonesOnParentMaps")
end

function Options:SetShowChildZonesOnParentMaps(info, value)
    SetBooleanSetting(self, "showChildZonesOnParentMaps", value)
end

function Options:GetHideFilteredPOI()
    return GetBooleanSetting(self, "hideFilteredPOI")
end

function Options:SetHideFilteredPOI(info, value)
    SetBooleanSetting(self, "hideFilteredPOI", value)
end

function Options:GetHideUntrackedPOI()
    return GetBooleanSetting(self, "hideUntrackedPOI")
end

function Options:SetHideUntrackedPOI(info, value)
    SetBooleanSetting(self, "hideUntrackedPOI", value)
end

function Options:GetShowHoveredPOI()
    return GetBooleanSetting(self, "showHoveredPOI")
end

function Options:SetShowHoveredPOI(info, value)
    SetBooleanSetting(self, "showHoveredPOI", value)
end

function Options:GetTimeFilterHours()
    local value = tonumber(self:GetDB().timeFilterHours)
    if not value then
        return DEFAULTS.timeFilterHours
    end

    return math.max(1, math.min(24, value))
end

function Options:SetTimeFilterHours(info, value)
    self:GetDB().timeFilterHours = math.max(1, math.min(24, tonumber(value) or DEFAULTS.timeFilterHours))
    self:RefreshModule("timeFilterHours")
end

function Options:GetSortMethod()
    local value = self:GetDB().sortMethod
    if type(value) ~= "string" or value == "" then
        return DEFAULTS.sortMethod
    end

    return value
end

function Options:SetSortMethod(info, value)
    self:GetDB().sortMethod = type(value) == "string" and value or DEFAULTS.sortMethod
    self:RefreshModule("sortMethod")
end

function Options:GetEnabledFilters()
    local db = self:GetDB()
    for key, defaultValue in pairs(DEFAULTS.enabledFilters) do
        if db.enabledFilters[key] == nil then
            db.enabledFilters[key] = defaultValue == true
        end
    end
    return db.enabledFilters
end

function Options:GetFilterChipEnabled(key)
    local filters = self:GetEnabledFilters()
    if filters[key] == nil then
        return DEFAULTS.enabledFilters[key] == true
    end

    return filters[key] == true
end

function Options:SetFilterChipEnabled(key, value)
    self:GetEnabledFilters()[key] = value == true
    self:RefreshModule("enabledFilters")
end

function Options:GetSelectedFilters()
    local db = self:GetDB()
    if type(db.selectedFilters) ~= "table" then
        db.selectedFilters = {}
    end
    return db.selectedFilters
end

function Options:IsFilterSelected(key)
    return self:GetSelectedFilters()[key] == true
end

function Options:SetFilterSelected(key, value)
    local selected = self:GetSelectedFilters()
    if value == true then
        selected[key] = true
    else
        selected[key] = nil
    end
    self:RefreshModule("selectedFilters")
end

function Options:ClearSelectedFilters()
    self:GetDB().selectedFilters = {}
    self:RefreshModule("selectedFilters")
end

function Options:OpenPreview()
    local module = GetModule()
    if not module then
        return
    end

    if not module:IsEnabled() and self:GetEnabled() then
        module:Enable()
    elseif not self:GetEnabled() then
        self:SetEnabled(nil, true)
        if not module:IsEnabled() then
            module:Enable()
        end
    end

    if module.OpenWorldMapPanel then
        module:OpenWorldMapPanel()
    end
end

function Options:ClosePreview()
    local module = GetModule()
    if module and module.HideWorldMapPanel then
        module:HideWorldMapPanel()
    end
end