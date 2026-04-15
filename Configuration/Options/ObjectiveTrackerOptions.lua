---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local UIParent = _G.UIParent
local math_floor = math.floor
local type = type

---@class ObjectiveTrackerConfigurationOptions
local Options = ConfigurationModule.Options.ObjectiveTracker or {}
ConfigurationModule.Options.ObjectiveTracker = Options

local DEFAULTS = {
    enabled = true,
    hideBlizzardTracker = true,
    showInstanceSection = true,
    showScenario = true,
    showQuestObjectives = true,
    showCompletedQuests = true,
    showTooltips = true,
    hideInCombat = false,
    hideInDungeon = false,
    hideInRaid = false,
    fadeWhenNotHovered = false,
    animateEntries = true,
    collapsed = false,
    width = 340,
    scale = 1,
    maxEntries = 12,
    opacity = 1,
    inactiveOpacity = 0.28,
    backgroundAlpha = 0.95,
    borderAlpha = 0.9,
    headerFont = "__default",
    categoryFont = "__default",
    bodyFont = "__default",
    headerFontSize = 14,
    categoryFontSize = 12,
    bodyFontSize = 11,
    metaFontSize = 10,
    zoneFilterMode = "prioritize",
    anchorX = -100,
    anchorY = -220,
    emptyText = "No tracked objectives right now.",
    backgroundColor = { 0.05, 0.06, 0.08 },
    borderColor = { 0.24, 0.26, 0.32 },
    accentColor = { 0.10, 0.72, 0.74 },
    headerTextColor = { 0.92, 0.94, 0.98 },
    questTitleColor = { 0.96, 0.91, 0.68 },
    bodyTextColor = { 0.82, 0.85, 0.92 },
    metaTextColor = { 0.66, 0.70, 0.78 },
    completeColor = { 0.42, 0.88, 0.64 },
    objectiveColor = { 0.74, 0.77, 0.84 },
    sectionScenarioColor = { 0.77, 0.49, 0.94 },
    sectionCurrentZoneColor = { 0.14, 0.78, 0.70 },
    sectionWorldColor = { 0.16, 0.60, 0.98 },
    sectionQuestColor = { 0.94, 0.74, 0.28 },
    sectionCompletedColor = { 0.38, 0.84, 0.57 },
    sectionCollapsed = {},
}

local function GetModule()
    return T:GetModule("ObjectiveTracker", true)
end

local function Clamp(value, minValue, maxValue)
    local numeric = tonumber(value) or minValue
    if numeric < minValue then
        return minValue
    end
    if numeric > maxValue then
        return maxValue
    end
    return numeric
end

local function Round(value)
    return math_floor((tonumber(value) or 0) + 0.5)
end

local function GetFontValues()
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    local fonts = LSM and LSM:HashTable("font") or {}
    if fonts["__default"] == nil then
        fonts["__default"] = "Theme Default"
    end
    return fonts
end

local function CopyColor(color, fallback)
    if type(color) == "table" then
        return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
    end

    return fallback[1], fallback[2], fallback[3]
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.objectiveTracker) ~= "table" then
        profile.objectiveTracker = {}
    end

    if type(profile.objectiveTracker.sectionCollapsed) ~= "table" then
        profile.objectiveTracker.sectionCollapsed = {}
    end

    return profile.objectiveTracker
end

function Options:RefreshModule(reason)
    local module = GetModule()
    if not module then
        return
    end

    if self:GetEnabled() and not module:IsEnabled() then
        module:Enable()
        return
    end

    if not self:GetEnabled() and module:IsEnabled() then
        module:Disable()
        return
    end

    if module:IsEnabled() and type(module.RefreshNow) == "function" then
        module:RefreshNow(reason or "options")
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

local function GetRangeSetting(self, key, minValue, maxValue, fallback)
    local value = tonumber(self:GetDB()[key])
    if value == nil then
        value = fallback
    end

    return Clamp(value, minValue, maxValue)
end

local function SetRangeSetting(self, key, value, minValue, maxValue, reason)
    self:GetDB()[key] = Clamp(value, minValue, maxValue)
    self:RefreshModule(reason or key)
end

local function GetFontSetting(self, key)
    local value = self:GetDB()[key]
    if type(value) ~= "string" or value == "" then
        return DEFAULTS[key]
    end

    return value
end

local function SetFontSetting(self, key, value)
    self:GetDB()[key] = (type(value) == "string" and value ~= "") and value or DEFAULTS[key]
    self:RefreshModule(key)
end

local function GetColorSetting(self, key)
    return CopyColor(self:GetDB()[key], DEFAULTS[key])
end

local function SetColorSetting(self, key, red, green, blue)
    self:GetDB()[key] = { red, green, blue }
    self:RefreshModule(key)
end

function Options:GetEnabled()
    return GetBooleanSetting(self, "enabled")
end

function Options:SetEnabled(_, value)
    self:GetDB().enabled = value == true
    self:RefreshModule("enabled")
end

function Options:GetHideBlizzardTracker()
    return GetBooleanSetting(self, "hideBlizzardTracker")
end

function Options:SetHideBlizzardTracker(_, value)
    SetBooleanSetting(self, "hideBlizzardTracker", value)
end

function Options:GetShowScenario()
    return GetBooleanSetting(self, "showScenario")
end

function Options:SetShowScenario(_, value)
    SetBooleanSetting(self, "showScenario", value)
end

function Options:GetShowInstanceSection()
    return GetBooleanSetting(self, "showInstanceSection")
end

function Options:SetShowInstanceSection(_, value)
    SetBooleanSetting(self, "showInstanceSection", value)
end

function Options:GetShowQuestObjectives()
    return GetBooleanSetting(self, "showQuestObjectives")
end

function Options:SetShowQuestObjectives(_, value)
    SetBooleanSetting(self, "showQuestObjectives", value)
end

function Options:GetShowCompletedQuests()
    return GetBooleanSetting(self, "showCompletedQuests")
end

function Options:SetShowCompletedQuests(_, value)
    SetBooleanSetting(self, "showCompletedQuests", value)
end

function Options:GetShowTooltips()
    return GetBooleanSetting(self, "showTooltips")
end

function Options:SetShowTooltips(_, value)
    SetBooleanSetting(self, "showTooltips", value)
end

function Options:GetHideInCombat()
    return GetBooleanSetting(self, "hideInCombat")
end

function Options:SetHideInCombat(_, value)
    SetBooleanSetting(self, "hideInCombat", value)
end

function Options:GetHideInDungeon()
    return GetBooleanSetting(self, "hideInDungeon")
end

function Options:SetHideInDungeon(_, value)
    SetBooleanSetting(self, "hideInDungeon", value)
end

function Options:GetHideInRaid()
    return GetBooleanSetting(self, "hideInRaid")
end

function Options:SetHideInRaid(_, value)
    SetBooleanSetting(self, "hideInRaid", value)
end

function Options:GetFadeWhenNotHovered()
    return GetBooleanSetting(self, "fadeWhenNotHovered")
end

function Options:SetFadeWhenNotHovered(_, value)
    SetBooleanSetting(self, "fadeWhenNotHovered", value)
end

function Options:GetAnimateEntries()
    return GetBooleanSetting(self, "animateEntries")
end

function Options:SetAnimateEntries(_, value)
    SetBooleanSetting(self, "animateEntries", value)
end

function Options:GetCollapsed()
    return GetBooleanSetting(self, "collapsed")
end

function Options:SetCollapsed(_, value)
    SetBooleanSetting(self, "collapsed", value)
end

function Options:GetWidth()
    return GetRangeSetting(self, "width", 240, 560, DEFAULTS.width)
end

function Options:SetWidth(_, value)
    SetRangeSetting(self, "width", value, 240, 560)
end

function Options:GetScale()
    return GetRangeSetting(self, "scale", 0.75, 1.5, DEFAULTS.scale)
end

function Options:SetScale(_, value)
    SetRangeSetting(self, "scale", value, 0.75, 1.5)
end

function Options:GetOpacity()
    return GetRangeSetting(self, "opacity", 0.2, 1, DEFAULTS.opacity)
end

function Options:SetOpacity(_, value)
    SetRangeSetting(self, "opacity", value, 0.2, 1)
end

function Options:GetInactiveOpacity()
    return GetRangeSetting(self, "inactiveOpacity", 0.05, 1, DEFAULTS.inactiveOpacity)
end

function Options:SetInactiveOpacity(_, value)
    SetRangeSetting(self, "inactiveOpacity", value, 0.05, 1)
end

function Options:GetBackgroundAlpha()
    return GetRangeSetting(self, "backgroundAlpha", 0, 1, DEFAULTS.backgroundAlpha)
end

function Options:SetBackgroundAlpha(_, value)
    SetRangeSetting(self, "backgroundAlpha", value, 0, 1)
end

function Options:GetBorderAlpha()
    return GetRangeSetting(self, "borderAlpha", 0, 1, DEFAULTS.borderAlpha)
end

function Options:SetBorderAlpha(_, value)
    SetRangeSetting(self, "borderAlpha", value, 0, 1)
end

function Options:GetHeaderFont()
    return GetFontSetting(self, "headerFont")
end

function Options:SetHeaderFont(_, value)
    SetFontSetting(self, "headerFont", value)
end

function Options:GetCategoryFont()
    return GetFontSetting(self, "categoryFont")
end

function Options:SetCategoryFont(_, value)
    SetFontSetting(self, "categoryFont", value)
end

function Options:GetBodyFont()
    return GetFontSetting(self, "bodyFont")
end

function Options:SetBodyFont(_, value)
    SetFontSetting(self, "bodyFont", value)
end

function Options:GetHeaderFontSize()
    return GetRangeSetting(self, "headerFontSize", 10, 24, DEFAULTS.headerFontSize)
end

function Options:SetHeaderFontSize(_, value)
    SetRangeSetting(self, "headerFontSize", value, 10, 24)
end

function Options:GetCategoryFontSize()
    return GetRangeSetting(self, "categoryFontSize", 9, 22, DEFAULTS.categoryFontSize)
end

function Options:SetCategoryFontSize(_, value)
    SetRangeSetting(self, "categoryFontSize", value, 9, 22)
end

function Options:GetBodyFontSize()
    return GetRangeSetting(self, "bodyFontSize", 9, 20, DEFAULTS.bodyFontSize)
end

function Options:SetBodyFontSize(_, value)
    SetRangeSetting(self, "bodyFontSize", value, 9, 20)
end

function Options:GetMetaFontSize()
    return GetRangeSetting(self, "metaFontSize", 8, 18, DEFAULTS.metaFontSize)
end

function Options:SetMetaFontSize(_, value)
    SetRangeSetting(self, "metaFontSize", value, 8, 18)
end

function Options:GetZoneFilterMode()
    local value = self:GetDB().zoneFilterMode
    if value == "all" or value == "prioritize" or value == "current" then
        return value
    end

    return DEFAULTS.zoneFilterMode
end

function Options:SetZoneFilterMode(_, value)
    self:GetDB().zoneFilterMode = (value == "all" or value == "current") and value or "prioritize"
    self:RefreshModule("zoneFilterMode")
end

function Options:GetMaxEntries()
    return Round(GetRangeSetting(self, "maxEntries", 1, 30, DEFAULTS.maxEntries))
end

function Options:SetMaxEntries(_, value)
    self:GetDB().maxEntries = Round(Clamp(value, 1, 30))
    self:RefreshModule("maxEntries")
end

function Options:GetAnchorX()
    local value = tonumber(self:GetDB().anchorX)
    if value == nil then
        return DEFAULTS.anchorX
    end

    return value
end

function Options:SetAnchorX(_, value)
    self:GetDB().anchorX = Round(value or DEFAULTS.anchorX)
    self:RefreshModule("anchorX")
end

function Options:GetAnchorY()
    local value = tonumber(self:GetDB().anchorY)
    if value == nil then
        return DEFAULTS.anchorY
    end

    return value
end

function Options:SetAnchorY(_, value)
    self:GetDB().anchorY = Round(value or DEFAULTS.anchorY)
    self:RefreshModule("anchorY")
end

function Options:SetAnchorFromBottomLeft(x, y)
    local module = GetModule()
    local frame = module and module.frame or nil
    local width = frame and frame:GetWidth() or self:GetWidth()
    local height = frame and frame:GetHeight() or 220
    local uiWidth = UIParent and UIParent:GetWidth() or 0
    local uiHeight = UIParent and UIParent:GetHeight() or 0

    self:GetDB().anchorX = Round((tonumber(x) or 0) + width - uiWidth)
    self:GetDB().anchorY = Round((tonumber(y) or 0) + height - uiHeight)
    self:RefreshModule("anchor")
end

function Options:GetEmptyText()
    local value = self:GetDB().emptyText
    if type(value) ~= "string" or value == "" then
        return DEFAULTS.emptyText
    end

    return value
end

function Options:SetEmptyText(_, value)
    self:GetDB().emptyText = type(value) == "string" and value or DEFAULTS.emptyText
    self:RefreshModule("emptyText")
end

function Options:GetColor(key)
    return GetColorSetting(self, key)
end

function Options:SetColor(key, red, green, blue)
    SetColorSetting(self, key, red, green, blue)
end

function Options:GetSectionCollapsed(sectionKey)
    local db = self:GetDB()
    local state = db.sectionCollapsed and db.sectionCollapsed[sectionKey]
    return state == true
end

function Options:SetSectionCollapsed(sectionKey, value)
    local db = self:GetDB()
    db.sectionCollapsed = db.sectionCollapsed or {}
    db.sectionCollapsed[sectionKey] = value == true
    self:RefreshModule("sectionCollapsed")
end

function Options:BuildConfiguration()
    local W = ConfigurationModule.Widgets
    local fontValues = GetFontValues()

    return {
        type = "group",
        name = "Objective Tracker",
        order = 19,
        args = {
            overview = W.Description(1,
                "A TwichUI-native objective tracker with section grouping, zone-aware sorting, collapsible categories, hover fade, richer click actions, and expanded visual customisation inspired by Horizon's Focus tracker."),
            general = W.IGroup(10, "General", {
                enable = { type = "toggle", order = 1, name = "Enable", handler = Options, get = "GetEnabled", set = "SetEnabled" },
                collapse = { type = "toggle", order = 2, name = "Collapse Tracker", handler = Options, get = "GetCollapsed", set = "SetCollapsed" },
                hideBlizzard = { type = "toggle", order = 3, name = "Hide Blizzard Tracker", handler = Options, get = "GetHideBlizzardTracker", set = "SetHideBlizzardTracker" },
                showInstance = { type = "toggle", order = 4, name = "Show Instance Section", handler = Options, get = "GetShowInstanceSection", set = "SetShowInstanceSection" },
                showScenario = { type = "toggle", order = 5, name = "Show Scenario Section", handler = Options, get = "GetShowScenario", set = "SetShowScenario" },
                showObjectives = { type = "toggle", order = 6, name = "Show Objective Lines", handler = Options, get = "GetShowQuestObjectives", set = "SetShowQuestObjectives" },
                showCompleted = { type = "toggle", order = 7, name = "Show Completed Section", handler = Options, get = "GetShowCompletedQuests", set = "SetShowCompletedQuests" },
                showTooltips = { type = "toggle", order = 8, name = "Show Tooltips", handler = Options, get = "GetShowTooltips", set = "SetShowTooltips" },
                animateEntries = { type = "toggle", order = 9, name = "Animate Entries", handler = Options, get = "GetAnimateEntries", set = "SetAnimateEntries" },
                zoneFilterMode = {
                    type = "select",
                    order = 10,
                    name = "Zone Filter",
                    values = {
                        prioritize = "Prioritize Current Zone",
                        current = "Only Current Zone",
                        all = "Show All Watched",
                    },
                    handler = Options,
                    get = "GetZoneFilterMode",
                    set = "SetZoneFilterMode",
                },
                maxEntries = {
                    type = "range",
                    order = 11,
                    name = "Entry Limit",
                    desc = "Maximum number of visible quest rows before overflow is summarized.",
                    min = 1,
                    max = 30,
                    step = 1,
                    handler = Options,
                    get = "GetMaxEntries",
                    set = "SetMaxEntries",
                },
            }),
            visibility = W.IGroup(20, "Visibility", {
                hideInCombat = { type = "toggle", order = 1, name = "Hide In Combat", handler = Options, get = "GetHideInCombat", set = "SetHideInCombat" },
                hideInDungeon = { type = "toggle", order = 2, name = "Hide In Dungeons", handler = Options, get = "GetHideInDungeon", set = "SetHideInDungeon" },
                hideInRaid = { type = "toggle", order = 3, name = "Hide In Raids", handler = Options, get = "GetHideInRaid", set = "SetHideInRaid" },
                fadeWhenNotHovered = { type = "toggle", order = 4, name = "Fade When Not Hovered", handler = Options, get = "GetFadeWhenNotHovered", set = "SetFadeWhenNotHovered" },
                opacity = {
                    type = "range",
                    order = 5,
                    name = "Visible Opacity",
                    min = 0.2,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetOpacity",
                    set = "SetOpacity",
                },
                inactiveOpacity = {
                    type = "range",
                    order = 6,
                    name = "Inactive Opacity",
                    min = 0.05,
                    max = 1,
                    step = 0.01,
                    disabled = function() return Options:GetFadeWhenNotHovered() ~= true end,
                    handler = Options,
                    get = "GetInactiveOpacity",
                    set = "SetInactiveOpacity",
                },
                backgroundAlpha = {
                    type = "range",
                    order = 7,
                    name = "Background Alpha",
                    min = 0,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetBackgroundAlpha",
                    set = "SetBackgroundAlpha",
                },
                borderAlpha = {
                    type = "range",
                    order = 8,
                    name = "Border Alpha",
                    min = 0,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetBorderAlpha",
                    set = "SetBorderAlpha",
                },
            }),
            layout = W.IGroup(30, "Layout", {
                width = { type = "range", order = 1, name = "Width", min = 240, max = 560, step = 2, handler = Options, get = "GetWidth", set = "SetWidth" },
                scale = { type = "range", order = 2, name = "Scale", min = 0.75, max = 1.5, step = 0.01, handler = Options, get = "GetScale", set = "SetScale" },
                anchorX = { type = "range", order = 3, name = "Anchor X", min = -1800, max = 1800, step = 1, handler = Options, get = "GetAnchorX", set = "SetAnchorX" },
                anchorY = { type = "range", order = 4, name = "Anchor Y", min = -1200, max = 1200, step = 1, handler = Options, get = "GetAnchorY", set = "SetAnchorY" },
                emptyText = { type = "input", order = 5, name = "Empty State Text", width = 2.0, handler = Options, get = "GetEmptyText", set = "SetEmptyText" },
            }),
            typography = W.IGroup(40, "Typography", {
                headerFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 1,
                    name = "Header Font",
                    values = function() return fontValues end,
                    handler = Options,
                    get = "GetHeaderFont",
                    set = "SetHeaderFont",
                },
                categoryFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 2,
                    name = "Category Font",
                    values = function() return fontValues end,
                    handler = Options,
                    get = "GetCategoryFont",
                    set = "SetCategoryFont",
                },
                bodyFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 3,
                    name = "Body Font",
                    values = function() return fontValues end,
                    handler = Options,
                    get = "GetBodyFont",
                    set = "SetBodyFont",
                },
                headerFontSize = { type = "range", order = 4, name = "Header Font Size", min = 10, max = 24, step = 1, handler = Options, get = "GetHeaderFontSize", set = "SetHeaderFontSize" },
                categoryFontSize = { type = "range", order = 5, name = "Category Font Size", min = 9, max = 22, step = 1, handler = Options, get = "GetCategoryFontSize", set = "SetCategoryFontSize" },
                bodyFontSize = { type = "range", order = 6, name = "Body Font Size", min = 9, max = 20, step = 1, handler = Options, get = "GetBodyFontSize", set = "SetBodyFontSize" },
                metaFontSize = { type = "range", order = 7, name = "Meta Font Size", min = 8, max = 18, step = 1, handler = Options, get = "GetMetaFontSize", set = "SetMetaFontSize" },
            }),
            colors = W.IGroup(50, "Colors", {
                backgroundColor = {
                    type = "color",
                    order = 1,
                    name = "Background",
                    get = function()
                        return Options
                            :GetColor("backgroundColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor("backgroundColor", r, g,
                            b)
                    end
                },
                borderColor = {
                    type = "color",
                    order = 2,
                    name = "Border",
                    get = function()
                        return Options:GetColor(
                            "borderColor")
                    end,
                    set = function(_, r, g, b) Options:SetColor("borderColor", r, g, b) end
                },
                accentColor = {
                    type = "color",
                    order = 3,
                    name = "Header Accent",
                    get = function()
                        return Options
                            :GetColor("accentColor")
                    end,
                    set = function(_, r, g, b) Options:SetColor("accentColor", r, g, b) end
                },
                headerTextColor = {
                    type = "color",
                    order = 4,
                    name = "Header Text",
                    get = function()
                        return Options
                            :GetColor("headerTextColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor("headerTextColor", r, g,
                            b)
                    end
                },
                questTitleColor = {
                    type = "color",
                    order = 5,
                    name = "Quest Title",
                    get = function()
                        return Options
                            :GetColor("questTitleColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor("questTitleColor", r, g,
                            b)
                    end
                },
                bodyTextColor = {
                    type = "color",
                    order = 6,
                    name = "Body Text",
                    get = function()
                        return Options
                            :GetColor("bodyTextColor")
                    end,
                    set = function(_, r, g, b) Options:SetColor("bodyTextColor", r, g, b) end
                },
                metaTextColor = {
                    type = "color",
                    order = 7,
                    name = "Meta Text",
                    get = function()
                        return Options
                            :GetColor("metaTextColor")
                    end,
                    set = function(_, r, g, b) Options:SetColor("metaTextColor", r, g, b) end
                },
                completeColor = {
                    type = "color",
                    order = 8,
                    name = "Completed Text",
                    get = function()
                        return Options
                            :GetColor("completeColor")
                    end,
                    set = function(_, r, g, b) Options:SetColor("completeColor", r, g, b) end
                },
                objectiveColor = {
                    type = "color",
                    order = 9,
                    name = "Objective Text",
                    get = function()
                        return Options
                            :GetColor("objectiveColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor("objectiveColor", r, g,
                            b)
                    end
                },
            }),
            sectionColors = W.IGroup(60, "Section Colors", {
                sectionScenarioColor = {
                    type = "color",
                    order = 1,
                    name = "Scenario",
                    get = function()
                        return Options
                            :GetColor("sectionScenarioColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor(
                            "sectionScenarioColor", r, g, b)
                    end
                },
                sectionCurrentZoneColor = {
                    type = "color",
                    order = 2,
                    name = "Current Zone",
                    get = function()
                        return
                            Options:GetColor("sectionCurrentZoneColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor(
                            "sectionCurrentZoneColor", r, g, b)
                    end
                },
                sectionWorldColor = {
                    type = "color",
                    order = 3,
                    name = "World Quests",
                    get = function()
                        return Options
                            :GetColor("sectionWorldColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor("sectionWorldColor",
                            r, g, b)
                    end
                },
                sectionQuestColor = {
                    type = "color",
                    order = 4,
                    name = "Tracked Quests",
                    get = function()
                        return Options
                            :GetColor("sectionQuestColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor("sectionQuestColor",
                            r, g, b)
                    end
                },
                sectionCompletedColor = {
                    type = "color",
                    order = 5,
                    name = "Completed",
                    get = function()
                        return Options
                            :GetColor("sectionCompletedColor")
                    end,
                    set = function(_, r, g, b)
                        Options:SetColor(
                            "sectionCompletedColor", r, g, b)
                    end
                },
            }),
        },
    }
end
