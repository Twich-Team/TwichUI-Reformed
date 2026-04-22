--[[
    LFG Finder Configuration Options
    Implements all configuration handlers and options for the LFG Finder module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

ConfigurationModule.Options.LFGFinder = ConfigurationModule.Options.LFGFinder or {}

---@class LFGFinderConfigurationOptions
local Options = ConfigurationModule.Options.LFGFinder

local DEFAULTS = {
    enabled = true,
    autoOpen = true,
    muteApplicantPing = false,
    selectedDifficulty = "ANY",
    minKeystone = 2,
    maxKeystone = 99,
    minimumRating = 0,
    needsTank = false,
    needsHealer = false,
    needsDPS = false,
    hideDeclined = true,
    frameTransparency = 0.95,
    fontSize = 11,
    rowHeight = 24,
    sortColumn = "age",
    sortAscending = false,
}

local function GetLFGFinderDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.lfgfinder) ~= "table" then
        profile.lfgfinder = {}
    end
    return profile.lfgfinder
end

--- Returns a value from the database, with fallback to defaults
local function GetValue(key, default)
    local db = GetLFGFinderDB()
    local val = db[key]
    if val ~= nil then
        return val
    end
    return default or DEFAULTS[key]
end

--- Sets a value in the database
local function SetValue(key, value)
    local db = GetLFGFinderDB()
    db[key] = value
end

-- ──────────────────────────────────────────────────────────────────────────────
-- General Options
-- ──────────────────────────────────────────────────────────────────────────────

function Options:GetEnabled()
    return GetValue("enabled", true)
end

function Options:SetEnabled(value)
    SetValue("enabled", value == true)
    local LFG = T:GetModule("LFGFinder", true)
    if LFG then
        if value then
            T:EnableModule("LFGFinder")
        else
            T:DisableModule("LFGFinder")
        end
    end
end

function Options:GetAutoOpen()
    return GetValue("autoOpen", true)
end

function Options:SetAutoOpen(value)
    SetValue("autoOpen", value == true)
end

function Options:GetMuteApplicantPing()
    return GetValue("muteApplicantPing", false)
end

function Options:SetMuteApplicantPing(value)
    SetValue("muteApplicantPing", value == true)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Filter Options
-- ──────────────────────────────────────────────────────────────────────────────

function Options:GetSelectedDifficulty()
    return GetValue("selectedDifficulty", "ANY")
end

function Options:SetSelectedDifficulty(value)
    SetValue("selectedDifficulty", value)
end

function Options:GetSelectedActivities()
    local db = GetLFGFinderDB()
    if type(db.selectedActivities) ~= "table" then
        db.selectedActivities = {}
    end
    return db.selectedActivities
end

function Options:SetSelectedActivities(activities)
    local db = GetLFGFinderDB()
    db.selectedActivities = activities or {}
end

function Options:GetMinKeystone()
    return GetValue("minKeystone", 2)
end

function Options:SetMinKeystone(value)
    SetValue("minKeystone", tonumber(value) or 2)
end

function Options:GetMaxKeystone()
    return GetValue("maxKeystone", 99)
end

function Options:SetMaxKeystone(value)
    SetValue("maxKeystone", tonumber(value) or 99)
end

function Options:GetMinimumRating()
    return GetValue("minimumRating", 0)
end

function Options:SetMinimumRating(value)
    SetValue("minimumRating", tonumber(value) or 0)
end

function Options:GetNeedsTank()
    return GetValue("needsTank", false)
end

function Options:SetNeedsTank(value)
    SetValue("needsTank", value == true)
end

function Options:GetNeedsHealer()
    return GetValue("needsHealer", false)
end

function Options:SetNeedsHealer(value)
    SetValue("needsHealer", value == true)
end

function Options:GetNeedsDPS()
    return GetValue("needsDPS", false)
end

function Options:SetNeedsDPS(value)
    SetValue("needsDPS", value == true)
end

function Options:GetHideDeclined()
    return GetValue("hideDeclined", true)
end

function Options:SetHideDeclined(value)
    SetValue("hideDeclined", value == true)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Appearance Options
-- ──────────────────────────────────────────────────────────────────────────────

function Options:GetFrameTransparency()
    return GetValue("frameTransparency", 0.95)
end

function Options:SetFrameTransparency(value)
    SetValue("frameTransparency", tonumber(value) or 0.95)
    local LFG = T:GetModule("LFGFinder", true)
    if LFG and LFG.mainFrame then
        LFG:RefreshFrameAppearance()
    end
end

function Options:GetFontSize()
    return GetValue("fontSize", 11)
end

function Options:SetFontSize(value)
    SetValue("fontSize", tonumber(value) or 11)
    local LFG = T:GetModule("LFGFinder", true)
    if LFG then
        LFG:RefreshFrameAppearance()
    end
end

function Options:GetRowHeight()
    return GetValue("rowHeight", 24)
end

function Options:SetRowHeight(value)
    SetValue("rowHeight", tonumber(value) or 24)
    local LFG = T:GetModule("LFGFinder", true)
    if LFG then
        LFG:RefreshFrameAppearance()
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Sorting Options
-- ──────────────────────────────────────────────────────────────────────────────

function Options:GetSortColumn()
    return GetValue("sortColumn", "age")
end

function Options:SetSortColumn(value)
    SetValue("sortColumn", value)
end

function Options:GetSortAscending()
    return GetValue("sortAscending", false)
end

function Options:SetSortAscending(value)
    SetValue("sortAscending", value == true)
end
