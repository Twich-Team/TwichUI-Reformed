---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class ObjectiveTrackerConfigurationOptions
local Options = ConfigurationModule.Options.ObjectiveTracker or {}
ConfigurationModule.Options.ObjectiveTracker = Options

local DEFAULTS = {
    enabled = true,
    hideBlizzardTracker = true,
    showScenario = true,
    showQuestObjectives = true,
    hideInCombat = false,
    collapsed = false,
    width = 320,
    scale = 1,
    maxEntries = 8,
    opacity = 1,
    headerFontSize = 13,
    bodyFontSize = 11,
    anchorX = -100,
    anchorY = -220,
    emptyText = "No tracked objectives right now.",
}

local function GetModule()
    return T:GetModule("ObjectiveTracker", true)
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.objectiveTracker) ~= "table" then
        profile.objectiveTracker = {}
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

function Options:GetShowQuestObjectives()
    return GetBooleanSetting(self, "showQuestObjectives")
end

function Options:SetShowQuestObjectives(_, value)
    SetBooleanSetting(self, "showQuestObjectives", value)
end

function Options:GetHideInCombat()
    return GetBooleanSetting(self, "hideInCombat")
end

function Options:SetHideInCombat(_, value)
    SetBooleanSetting(self, "hideInCombat", value)
end

function Options:GetCollapsed()
    return GetBooleanSetting(self, "collapsed")
end

function Options:SetCollapsed(_, value)
    SetBooleanSetting(self, "collapsed", value)
end

function Options:GetWidth()
    local value = tonumber(self:GetDB().width)
    if not value then
        return DEFAULTS.width
    end
    return math.max(220, math.min(520, value))
end

function Options:SetWidth(_, value)
    self:GetDB().width = math.max(220, math.min(520, tonumber(value) or DEFAULTS.width))
    self:RefreshModule("width")
end

function Options:GetScale()
    local value = tonumber(self:GetDB().scale)
    if not value then
        return DEFAULTS.scale
    end
    return math.max(0.8, math.min(1.5, value))
end

function Options:SetScale(_, value)
    self:GetDB().scale = math.max(0.8, math.min(1.5, tonumber(value) or DEFAULTS.scale))
    self:RefreshModule("scale")
end

function Options:GetOpacity()
    local value = tonumber(self:GetDB().opacity)
    if not value then
        return DEFAULTS.opacity
    end
    return math.max(0.2, math.min(1.0, value))
end

function Options:SetOpacity(_, value)
    self:GetDB().opacity = math.max(0.2, math.min(1.0, tonumber(value) or DEFAULTS.opacity))
    self:RefreshModule("opacity")
end

function Options:GetHeaderFontSize()
    local value = tonumber(self:GetDB().headerFontSize)
    if not value then
        return DEFAULTS.headerFontSize
    end
    return math.max(11, math.min(18, value))
end

function Options:SetHeaderFontSize(_, value)
    self:GetDB().headerFontSize = math.max(11, math.min(18, tonumber(value) or DEFAULTS.headerFontSize))
    self:RefreshModule("headerFontSize")
end

function Options:GetBodyFontSize()
    local value = tonumber(self:GetDB().bodyFontSize)
    if not value then
        return DEFAULTS.bodyFontSize
    end
    return math.max(10, math.min(16, value))
end

function Options:SetBodyFontSize(_, value)
    self:GetDB().bodyFontSize = math.max(10, math.min(16, tonumber(value) or DEFAULTS.bodyFontSize))
    self:RefreshModule("bodyFontSize")
end

function Options:GetMaxEntries()
    local value = tonumber(self:GetDB().maxEntries)
    if not value then
        return DEFAULTS.maxEntries
    end
    return math.max(1, math.min(20, math.floor(value + 0.5)))
end

function Options:SetMaxEntries(_, value)
    self:GetDB().maxEntries = math.max(1, math.min(20, math.floor((tonumber(value) or DEFAULTS.maxEntries) + 0.5)))
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
    self:GetDB().anchorX = math.floor((tonumber(value) or DEFAULTS.anchorX) + 0.5)
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
    self:GetDB().anchorY = math.floor((tonumber(value) or DEFAULTS.anchorY) + 0.5)
    self:RefreshModule("anchorY")
end

function Options:SetAnchorFromBottomLeft(x, y)
    local module = GetModule()
    local frame = module and module.frame or nil
    local width = frame and frame:GetWidth() or self:GetWidth()
    local height = frame and frame:GetHeight() or 220
    local uiWidth = UIParent and UIParent:GetWidth() or 0
    local uiHeight = UIParent and UIParent:GetHeight() or 0

    self:GetDB().anchorX = math.floor(((tonumber(x) or 0) + width - uiWidth) + 0.5)
    self:GetDB().anchorY = math.floor(((tonumber(y) or 0) + height - uiHeight) + 0.5)
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

function Options:BuildConfiguration()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Objective Tracker",
        order = 19,
        args = {
            overview = W.Description(1,
                "A TwichUI-native tracked objective panel inspired by Horizon's cleaner quest presentation, with watched quests, scenario steps, and Interface Designer support."),
            general = W.IGroup(10, "General", {
                enable = {
                    type = "toggle",
                    order = 1,
                    name = "Enable",
                    desc = "Enable the TwichUI objective tracker.",
                    handler = Options,
                    get = "GetEnabled",
                    set = "SetEnabled",
                },
                collapse = {
                    type = "toggle",
                    order = 2,
                    name = "Collapsed",
                    desc = "Collapse the tracker down to its header bar.",
                    handler = Options,
                    get = "GetCollapsed",
                    set = "SetCollapsed",
                },
                hideBlizzard = {
                    type = "toggle",
                    order = 3,
                    name = "Hide Blizzard Tracker",
                    desc = "Suppress the default Blizzard objective tracker while TwichUI's tracker is enabled.",
                    handler = Options,
                    get = "GetHideBlizzardTracker",
                    set = "SetHideBlizzardTracker",
                },
                hideInCombat = {
                    type = "toggle",
                    order = 4,
                    name = "Hide In Combat",
                    desc = "Hide the custom tracker while in combat.",
                    handler = Options,
                    get = "GetHideInCombat",
                    set = "SetHideInCombat",
                },
                showScenario = {
                    type = "toggle",
                    order = 5,
                    name = "Show Scenario Objectives",
                    desc = "Render active scenario criteria above watched quests.",
                    handler = Options,
                    get = "GetShowScenario",
                    set = "SetShowScenario",
                },
                showQuestObjectives = {
                    type = "toggle",
                    order = 6,
                    name = "Show Objective Lines",
                    desc = "Show individual quest objective progress lines beneath quest titles.",
                    handler = Options,
                    get = "GetShowQuestObjectives",
                    set = "SetShowQuestObjectives",
                },
            }),
            layout = W.IGroup(20, "Layout", {
                width = {
                    type = "range",
                    order = 1,
                    name = "Width",
                    min = 220,
                    max = 520,
                    step = 2,
                    handler = Options,
                    get = "GetWidth",
                    set = "SetWidth",
                },
                scale = {
                    type = "range",
                    order = 2,
                    name = "Scale",
                    min = 0.8,
                    max = 1.5,
                    step = 0.01,
                    handler = Options,
                    get = "GetScale",
                    set = "SetScale",
                },
                opacity = {
                    type = "range",
                    order = 3,
                    name = "Opacity",
                    min = 0.2,
                    max = 1.0,
                    step = 0.01,
                    handler = Options,
                    get = "GetOpacity",
                    set = "SetOpacity",
                },
                maxEntries = {
                    type = "range",
                    order = 4,
                    name = "Entry Limit",
                    desc =
                    "Maximum number of quest or scenario entries shown before collapsing overflow into a summary line.",
                    min = 1,
                    max = 20,
                    step = 1,
                    handler = Options,
                    get = "GetMaxEntries",
                    set = "SetMaxEntries",
                },
                anchorX = {
                    type = "range",
                    order = 5,
                    name = "Anchor X",
                    min = -1600,
                    max = 1600,
                    step = 1,
                    handler = Options,
                    get = "GetAnchorX",
                    set = "SetAnchorX",
                },
                anchorY = {
                    type = "range",
                    order = 6,
                    name = "Anchor Y",
                    min = -1200,
                    max = 1200,
                    step = 1,
                    handler = Options,
                    get = "GetAnchorY",
                    set = "SetAnchorY",
                },
            }),
            typography = W.IGroup(30, "Typography", {
                headerFontSize = {
                    type = "range",
                    order = 1,
                    name = "Header Font Size",
                    min = 11,
                    max = 18,
                    step = 1,
                    handler = Options,
                    get = "GetHeaderFontSize",
                    set = "SetHeaderFontSize",
                },
                bodyFontSize = {
                    type = "range",
                    order = 2,
                    name = "Body Font Size",
                    min = 10,
                    max = 16,
                    step = 1,
                    handler = Options,
                    get = "GetBodyFontSize",
                    set = "SetBodyFontSize",
                },
                emptyText = {
                    type = "input",
                    order = 3,
                    name = "Empty State Text",
                    desc = "Message shown when no watched quests or scenario objectives are available.",
                    width = 2.0,
                    handler = Options,
                    get = "GetEmptyText",
                    set = "SetEmptyText",
                },
            }),
        },
    }
end
