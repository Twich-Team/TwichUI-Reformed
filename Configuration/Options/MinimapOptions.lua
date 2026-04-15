---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local UIParent = _G.UIParent
local floor = math.floor
local pairs = pairs
local type = type

---@class MinimapConfigurationOptions
local Options = ConfigurationModule.Options.Minimap or {}
ConfigurationModule.Options.Minimap = Options

local LSM = (T.Libs and T.Libs.LSM) or (_G.LibStub and _G.LibStub("LibSharedMedia-3.0", true))

local DEFAULTS = {
    enabled = true,
    size = 228,
    circular = false,
    showZoneText = true,
    showSubzone = true,
    showCoordinates = true,
    showClock = true,
    useLocalTime = false,
    use24HourClock = false,
    showMailIndicator = true,
    manageAddonButtons = true,
    fadeAddonButtonsOnHover = true,
    addonButtonPosition = "bottom",
    addonButtonOffsetX = 0,
    addonButtonOffsetY = 0,
    addonButtonSize = 24,
    addonButtonActiveAlpha = 1,
    addonButtonInactiveAlpha = 0.16,
    coordinatePrecision = 1,
    zoneTextPosition = "top",
    zoneTextOffsetX = 0,
    zoneTextOffsetY = 0,
    clockPosition = "bottom-left",
    clockOffsetX = 0,
    clockOffsetY = 0,
    coordinatesPosition = "bottom-right",
    coordinatesOffsetX = 0,
    coordinatesOffsetY = 0,
    accentUsesTheme = true,
    accentColor = { 0.98, 0.72, 0.24 },
    titleFont = "__default",
    titleFontSize = 13,
    titleColor = { 0.98, 0.95, 0.84 },
    detailFont = "__default",
    detailFontSize = 10,
    detailColor = { 0.70, 0.74, 0.82 },
    clockFont = "__default",
    clockFontSize = 11,
    clockColor = { 0.78, 0.82, 0.92 },
    coordinatesFont = "__default",
    coordinatesFontSize = 11,
    coordinatesColor = { 0.78, 0.82, 0.92 },
    mailFont = "__default",
    mailFontSize = 9,
    mailColor = { 0.98, 0.72, 0.24 },
    backgroundAlpha = 0.94,
    borderAlpha = 0.82,
    accentAlpha = 1,
}

local POSITION_VALUES = {
    top = "Top",
    bottom = "Bottom",
}

local EDGE_POSITION_VALUES = {
    top = "Top",
    bottom = "Bottom",
    left = "Left",
    right = "Right",
}

local CORNER_POSITION_VALUES = {
    ["top-left"] = "Top Left",
    ["top-right"] = "Top Right",
    ["bottom-left"] = "Bottom Left",
    ["bottom-right"] = "Bottom Right",
}

local FONT_VALUES = nil

local function Round(value)
    return floor((tonumber(value) or 0) + 0.5)
end

local function Clamp(value, minimum, maximum)
    local numeric = tonumber(value) or minimum
    if numeric < minimum then
        return minimum
    end
    if numeric > maximum then
        return maximum
    end
    return numeric
end

local function GetModule()
    return T:GetModule("Minimap", true)
end

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function RefreshAnchorOnly(reason)
    local module = GetModule()
    if not module or not module:IsEnabled() then
        return false
    end

    if type(module.ApplyPosition) == "function" then
        module:ApplyPosition(reason or "anchor")
    end
    return true
end

local function GetFontValues()
    if FONT_VALUES then
        return FONT_VALUES
    end

    local values = {
        __default = "Default",
    }

    if LSM and type(LSM.HashTable) == "function" then
        local fonts = LSM:HashTable("font") or {}
        for key, value in pairs(fonts) do
            values[key] = value
        end
    end

    FONT_VALUES = values
    return values
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.minimap) ~= "table" then
        profile.minimap = {}
    end
    return profile.minimap
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

    if module:IsEnabled() and type(module.RequestApply) == "function" then
        module:RequestApply(reason or "options")
    end
end

function Options:GetDefaultAnchorPosition()
    local module = GetModule()
    if module and module.GetDefaultAnchorPosition then
        return module:GetDefaultAnchorPosition()
    end

    local width = UIParent and UIParent:GetWidth() or 1920
    local height = UIParent and UIParent:GetHeight() or 1080
    return Round(width - 276), Round(height - 336)
end

local function GetBoolean(self, key)
    local value = self:GetDB()[key]
    if value == nil then
        return DEFAULTS[key] == true
    end
    return value == true
end

local function SetBoolean(self, key, value)
    self:GetDB()[key] = value == true
    self:RefreshModule(key)
end

local function GetRange(self, key, minimum, maximum)
    local value = tonumber(self:GetDB()[key])
    if value == nil then
        value = DEFAULTS[key]
    end
    return Clamp(value, minimum, maximum)
end

local function SetRange(self, key, value, minimum, maximum)
    self:GetDB()[key] = Clamp(value, minimum, maximum)
    self:RefreshModule(key)
end

local function GetChoice(self, key, defaultValue, allowedValues)
    local value = self:GetDB()[key]
    if type(value) == "string" and allowedValues[value] ~= nil then
        return value
    end
    return defaultValue
end

local function SetChoice(self, key, value, defaultValue, allowedValues)
    if allowedValues[value] == nil then
        value = defaultValue
    end
    self:GetDB()[key] = value
    self:RefreshModule(key)
end

local function GetFont(self, key)
    local value = self:GetDB()[key]
    if type(value) ~= "string" or value == "" then
        return DEFAULTS[key] or "__default"
    end
    return value
end

local function SetFont(self, key, value)
    local fonts = GetFontValues()
    if type(value) ~= "string" or fonts[value] == nil then
        value = "__default"
    end
    self:GetDB()[key] = value
    self:RefreshModule(key)
end

local function GetColor(self, key)
    local dbValue = self:GetDB()[key]
    local fallback = type(DEFAULTS[key]) == "table" and DEFAULTS[key] or { 1, 1, 1 }
    if type(dbValue) == "table" then
        return dbValue[1] or fallback[1], dbValue[2] or fallback[2], dbValue[3] or fallback[3]
    end
    return fallback[1], fallback[2], fallback[3]
end

local function SetColor(self, key, red, green, blue)
    self:GetDB()[key] = {
        Clamp(red, 0, 1),
        Clamp(green, 0, 1),
        Clamp(blue, 0, 1),
    }
    self:RefreshModule(key)
end

local function GetOffset(self, key)
    return GetRange(self, key, -200, 200)
end

local function SetOffset(self, key, value)
    SetRange(self, key, value, -200, 200)
end

function Options:GetEnabled()
    return GetBoolean(self, "enabled")
end

function Options:SetEnabled(_, value)
    self:GetDB().enabled = value == true
    self:RefreshModule("enabled")
end

function Options:GetSize()
    return GetRange(self, "size", 160, 320)
end

function Options:SetSize(_, value)
    SetRange(self, "size", value, 160, 320)
end

function Options:GetCircular()
    return GetBoolean(self, "circular")
end

function Options:SetCircular(_, value)
    SetBoolean(self, "circular", value)
end

function Options:GetAnchorX()
    local db = self:GetDB()
    if db.anchorX == nil then
        local x = self:GetDefaultAnchorPosition()
        return x
    end
    return Round(db.anchorX)
end

function Options:GetAnchorY()
    local db = self:GetDB()
    if db.anchorY == nil then
        local _, y = self:GetDefaultAnchorPosition()
        return y
    end
    return Round(db.anchorY)
end

function Options:GetAnchorPoint()
    local point = self:GetDB().anchorPoint
    if type(point) == "string" and point ~= "" then
        return point
    end
    return "BOTTOMLEFT"
end

function Options:GetRelativePoint()
    local relativePoint = self:GetDB().relativePoint
    if type(relativePoint) == "string" and relativePoint ~= "" then
        return relativePoint
    end
    return self:GetAnchorPoint()
end

function Options:SetAnchorPosition(x, y)
    local db = self:GetDB()
    db.anchorX = Round(x)
    db.anchorY = Round(y)
    if not RefreshAnchorOnly("anchor") then
        self:RefreshModule("anchor")
    end
end

function Options:SetAnchor(point, x, y)
    local db = self:GetDB()
    local anchorPoint = type(point) == "string" and point ~= "" and point or self:GetAnchorPoint()
    db.anchorPoint = anchorPoint
    db.relativePoint = anchorPoint
    db.anchorX = Round(x)
    db.anchorY = Round(y)
    if not RefreshAnchorOnly("anchor-point") then
        self:RefreshModule("anchor-point")
    end
end

function Options:ResetAnchorPosition()
    local db = self:GetDB()
    local x, y = self:GetDefaultAnchorPosition()
    db.anchorPoint = "BOTTOMLEFT"
    db.relativePoint = "BOTTOMLEFT"
    db.anchorX = x
    db.anchorY = y
    if not RefreshAnchorOnly("anchor-reset") then
        self:RefreshModule("anchor-reset")
    end
end

function Options:GetShowZoneText()
    return GetBoolean(self, "showZoneText")
end

function Options:SetShowZoneText(_, value)
    SetBoolean(self, "showZoneText", value)
end

function Options:GetShowSubzone()
    return GetBoolean(self, "showSubzone")
end

function Options:SetShowSubzone(_, value)
    SetBoolean(self, "showSubzone", value)
end

function Options:GetShowCoordinates()
    return GetBoolean(self, "showCoordinates")
end

function Options:SetShowCoordinates(_, value)
    SetBoolean(self, "showCoordinates", value)
end

function Options:GetShowClock()
    return GetBoolean(self, "showClock")
end

function Options:SetShowClock(_, value)
    SetBoolean(self, "showClock", value)
end

function Options:GetUseLocalTime()
    return GetBoolean(self, "useLocalTime")
end

function Options:SetUseLocalTime(_, value)
    SetBoolean(self, "useLocalTime", value)
end

function Options:GetUse24HourClock()
    return GetBoolean(self, "use24HourClock")
end

function Options:SetUse24HourClock(_, value)
    SetBoolean(self, "use24HourClock", value)
end

function Options:GetShowMailIndicator()
    return GetBoolean(self, "showMailIndicator")
end

function Options:SetShowMailIndicator(_, value)
    SetBoolean(self, "showMailIndicator", value)
end

function Options:GetZoneTextPosition()
    return GetChoice(self, "zoneTextPosition", DEFAULTS.zoneTextPosition, POSITION_VALUES)
end

function Options:SetZoneTextPosition(_, value)
    SetChoice(self, "zoneTextPosition", value, DEFAULTS.zoneTextPosition, POSITION_VALUES)
end

function Options:GetZoneTextOffsetX()
    return GetOffset(self, "zoneTextOffsetX")
end

function Options:SetZoneTextOffsetX(_, value)
    SetOffset(self, "zoneTextOffsetX", value)
end

function Options:GetZoneTextOffsetY()
    return GetOffset(self, "zoneTextOffsetY")
end

function Options:SetZoneTextOffsetY(_, value)
    SetOffset(self, "zoneTextOffsetY", value)
end

function Options:GetClockPosition()
    return GetChoice(self, "clockPosition", DEFAULTS.clockPosition, CORNER_POSITION_VALUES)
end

function Options:SetClockPosition(_, value)
    SetChoice(self, "clockPosition", value, DEFAULTS.clockPosition, CORNER_POSITION_VALUES)
end

function Options:GetClockOffsetX()
    return GetOffset(self, "clockOffsetX")
end

function Options:SetClockOffsetX(_, value)
    SetOffset(self, "clockOffsetX", value)
end

function Options:GetClockOffsetY()
    return GetOffset(self, "clockOffsetY")
end

function Options:SetClockOffsetY(_, value)
    SetOffset(self, "clockOffsetY", value)
end

function Options:GetCoordinatesPosition()
    return GetChoice(self, "coordinatesPosition", DEFAULTS.coordinatesPosition, CORNER_POSITION_VALUES)
end

function Options:SetCoordinatesPosition(_, value)
    SetChoice(self, "coordinatesPosition", value, DEFAULTS.coordinatesPosition, CORNER_POSITION_VALUES)
end

function Options:GetCoordinatesOffsetX()
    return GetOffset(self, "coordinatesOffsetX")
end

function Options:SetCoordinatesOffsetX(_, value)
    SetOffset(self, "coordinatesOffsetX", value)
end

function Options:GetCoordinatesOffsetY()
    return GetOffset(self, "coordinatesOffsetY")
end

function Options:SetCoordinatesOffsetY(_, value)
    SetOffset(self, "coordinatesOffsetY", value)
end

function Options:GetCoordinatePrecision()
    return GetRange(self, "coordinatePrecision", 0, 2)
end

function Options:SetCoordinatePrecision(_, value)
    SetRange(self, "coordinatePrecision", value, 0, 2)
end

function Options:GetManageAddonButtons()
    return GetBoolean(self, "manageAddonButtons")
end

function Options:SetManageAddonButtons(_, value)
    SetBoolean(self, "manageAddonButtons", value)
end

function Options:GetFadeAddonButtonsOnHover()
    return GetBoolean(self, "fadeAddonButtonsOnHover")
end

function Options:SetFadeAddonButtonsOnHover(_, value)
    SetBoolean(self, "fadeAddonButtonsOnHover", value)
end

function Options:GetAddonButtonPosition()
    return GetChoice(self, "addonButtonPosition", DEFAULTS.addonButtonPosition, EDGE_POSITION_VALUES)
end

function Options:SetAddonButtonPosition(_, value)
    SetChoice(self, "addonButtonPosition", value, DEFAULTS.addonButtonPosition, EDGE_POSITION_VALUES)
end

function Options:GetAddonButtonOffsetX()
    return GetOffset(self, "addonButtonOffsetX")
end

function Options:SetAddonButtonOffsetX(_, value)
    SetOffset(self, "addonButtonOffsetX", value)
end

function Options:GetAddonButtonOffsetY()
    return GetOffset(self, "addonButtonOffsetY")
end

function Options:SetAddonButtonOffsetY(_, value)
    SetOffset(self, "addonButtonOffsetY", value)
end

function Options:GetAddonButtonSize()
    return GetRange(self, "addonButtonSize", 18, 34)
end

function Options:SetAddonButtonSize(_, value)
    SetRange(self, "addonButtonSize", value, 18, 34)
end

function Options:GetAddonButtonActiveAlpha()
    return GetRange(self, "addonButtonActiveAlpha", 0.05, 1)
end

function Options:SetAddonButtonActiveAlpha(_, value)
    SetRange(self, "addonButtonActiveAlpha", value, 0.05, 1)
end

function Options:GetAddonButtonInactiveAlpha()
    return GetRange(self, "addonButtonInactiveAlpha", 0.05, 1)
end

function Options:SetAddonButtonInactiveAlpha(_, value)
    SetRange(self, "addonButtonInactiveAlpha", value, 0.05, 1)
end

function Options:GetBackgroundAlpha()
    return GetRange(self, "backgroundAlpha", 0.20, 1)
end

function Options:SetBackgroundAlpha(_, value)
    SetRange(self, "backgroundAlpha", value, 0.20, 1)
end

function Options:GetBorderAlpha()
    return GetRange(self, "borderAlpha", 0.10, 1)
end

function Options:SetBorderAlpha(_, value)
    SetRange(self, "borderAlpha", value, 0.10, 1)
end

function Options:GetAccentAlpha()
    return GetRange(self, "accentAlpha", 0.20, 1)
end

function Options:SetAccentAlpha(_, value)
    SetRange(self, "accentAlpha", value, 0.20, 1)
end

function Options:GetAccentUsesTheme()
    return GetBoolean(self, "accentUsesTheme")
end

function Options:SetAccentUsesTheme(_, value)
    SetBoolean(self, "accentUsesTheme", value)
end

function Options:GetAccentColor()
    if self:GetAccentUsesTheme() then
        local theme = GetThemeModule()
        if theme and type(theme.GetColor) == "function" then
            local color = theme:GetColor("accentColor")
            if type(color) == "table" then
                return color[1] or 0.98, color[2] or 0.72, color[3] or 0.24
            end
        end
    end

    return GetColor(self, "accentColor")
end

function Options:SetAccentColor(_, red, green, blue)
    self:GetDB().accentUsesTheme = false
    SetColor(self, "accentColor", red, green, blue)
end

function Options:GetBorderColor()
    return self:GetAccentColor()
end

function Options:GetTitleFont()
    return GetFont(self, "titleFont")
end

function Options:SetTitleFont(_, value)
    SetFont(self, "titleFont", value)
end

function Options:GetTitleFontSize()
    return GetRange(self, "titleFontSize", 8, 28)
end

function Options:SetTitleFontSize(_, value)
    SetRange(self, "titleFontSize", value, 8, 28)
end

function Options:GetTitleColor()
    return GetColor(self, "titleColor")
end

function Options:SetTitleColor(_, red, green, blue)
    SetColor(self, "titleColor", red, green, blue)
end

function Options:GetDetailFont()
    return GetFont(self, "detailFont")
end

function Options:SetDetailFont(_, value)
    SetFont(self, "detailFont", value)
end

function Options:GetDetailFontSize()
    return GetRange(self, "detailFontSize", 8, 24)
end

function Options:SetDetailFontSize(_, value)
    SetRange(self, "detailFontSize", value, 8, 24)
end

function Options:GetDetailColor()
    return GetColor(self, "detailColor")
end

function Options:SetDetailColor(_, red, green, blue)
    SetColor(self, "detailColor", red, green, blue)
end

function Options:GetClockFont()
    return GetFont(self, "clockFont")
end

function Options:SetClockFont(_, value)
    SetFont(self, "clockFont", value)
end

function Options:GetClockFontSize()
    return GetRange(self, "clockFontSize", 8, 24)
end

function Options:SetClockFontSize(_, value)
    SetRange(self, "clockFontSize", value, 8, 24)
end

function Options:GetClockColor()
    return GetColor(self, "clockColor")
end

function Options:SetClockColor(_, red, green, blue)
    SetColor(self, "clockColor", red, green, blue)
end

function Options:GetCoordinatesFont()
    return GetFont(self, "coordinatesFont")
end

function Options:SetCoordinatesFont(_, value)
    SetFont(self, "coordinatesFont", value)
end

function Options:GetCoordinatesFontSize()
    return GetRange(self, "coordinatesFontSize", 8, 24)
end

function Options:SetCoordinatesFontSize(_, value)
    SetRange(self, "coordinatesFontSize", value, 8, 24)
end

function Options:GetCoordinatesColor()
    return GetColor(self, "coordinatesColor")
end

function Options:SetCoordinatesColor(_, red, green, blue)
    SetColor(self, "coordinatesColor", red, green, blue)
end

function Options:GetMailFont()
    return GetFont(self, "mailFont")
end

function Options:SetMailFont(_, value)
    SetFont(self, "mailFont", value)
end

function Options:GetMailFontSize()
    return GetRange(self, "mailFontSize", 8, 20)
end

function Options:SetMailFontSize(_, value)
    SetRange(self, "mailFontSize", value, 8, 20)
end

function Options:GetMailColor()
    return GetColor(self, "mailColor")
end

function Options:SetMailColor(_, red, green, blue)
    SetColor(self, "mailColor", red, green, blue)
end

function Options:ShowPreview()
    local module = GetModule()
    if module and module.ShowPreview then
        module:ShowPreview()
    end
end

function Options:BuildConfiguration()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Minimap",
        order = 16,
        args = {
            overview = W.Description(1,
                "Wrap the Blizzard minimap in TwichUI chrome with premium text overlays, button collection, and Interface Designer support inspired by Horizon Vista."),
            general = W.IGroup(10, "General", {
                enable = {
                    type = "toggle",
                    order = 1,
                    name = "Enable",
                    desc = "Enable the TwichUI minimap module.",
                    handler = Options,
                    get = "GetEnabled",
                    set = "SetEnabled",
                },
                preview = {
                    type = "execute",
                    order = 2,
                    name = "Pulse Minimap",
                    desc = "Highlights the minimap shell so you can find and move it quickly.",
                    handler = Options,
                    func = "ShowPreview",
                    width = 1.5,
                },
                reset = {
                    type = "execute",
                    order = 3,
                    name = "Reset Position",
                    desc = "Move the minimap back to the default TwichUI position.",
                    func = function()
                        Options:ResetAnchorPosition()
                    end,
                    width = 1.5,
                },
                size = {
                    type = "range",
                    order = 4,
                    name = "Size",
                    desc = "Rendered size of the minimap frame in pixels.",
                    min = 160,
                    max = 320,
                    step = 1,
                    handler = Options,
                    get = "GetSize",
                    set = "SetSize",
                },
                circular = {
                    type = "toggle",
                    order = 5,
                    name = "Circular Mask",
                    desc = "Use a circular minimap mask instead of the square shell.",
                    handler = Options,
                    get = "GetCircular",
                    set = "SetCircular",
                },
            }),
            overlays = W.IGroup(20, "Overlay Text", {
                showZone = {
                    type = "toggle",
                    order = 1,
                    name = "Zone Text",
                    desc = "Show the current zone name on the minimap shell.",
                    handler = Options,
                    get = "GetShowZoneText",
                    set = "SetShowZoneText",
                },
                showSubzone = {
                    type = "toggle",
                    order = 2,
                    name = "Subzone Detail",
                    desc = "Show the subzone when it differs from the main zone, or instance difficulty when applicable.",
                    handler = Options,
                    get = "GetShowSubzone",
                    set = "SetShowSubzone",
                    disabled = function()
                        return not Options:GetShowZoneText()
                    end,
                },
                zonePosition = {
                    type = "select",
                    order = 3,
                    name = "Zone Position",
                    values = POSITION_VALUES,
                    handler = Options,
                    get = "GetZoneTextPosition",
                    set = "SetZoneTextPosition",
                    disabled = function()
                        return not Options:GetShowZoneText()
                    end,
                },
                zoneOffsetX = {
                    type = "range",
                    order = 3.1,
                    name = "Zone Offset X",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetZoneTextOffsetX",
                    set = "SetZoneTextOffsetX",
                    disabled = function()
                        return not Options:GetShowZoneText()
                    end,
                },
                zoneOffsetY = {
                    type = "range",
                    order = 3.2,
                    name = "Zone Offset Y",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetZoneTextOffsetY",
                    set = "SetZoneTextOffsetY",
                    disabled = function()
                        return not Options:GetShowZoneText()
                    end,
                },
                showCoordinates = {
                    type = "toggle",
                    order = 4,
                    name = "Coordinates",
                    desc = "Show player coordinates around the minimap.",
                    handler = Options,
                    get = "GetShowCoordinates",
                    set = "SetShowCoordinates",
                },
                coordinatesPosition = {
                    type = "select",
                    order = 5,
                    name = "Coordinates Position",
                    values = CORNER_POSITION_VALUES,
                    handler = Options,
                    get = "GetCoordinatesPosition",
                    set = "SetCoordinatesPosition",
                    disabled = function()
                        return not Options:GetShowCoordinates()
                    end,
                },
                coordinatesOffsetX = {
                    type = "range",
                    order = 5.1,
                    name = "Coordinates Offset X",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetCoordinatesOffsetX",
                    set = "SetCoordinatesOffsetX",
                    disabled = function()
                        return not Options:GetShowCoordinates()
                    end,
                },
                coordinatesOffsetY = {
                    type = "range",
                    order = 5.2,
                    name = "Coordinates Offset Y",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetCoordinatesOffsetY",
                    set = "SetCoordinatesOffsetY",
                    disabled = function()
                        return not Options:GetShowCoordinates()
                    end,
                },
                coordinatePrecision = {
                    type = "range",
                    order = 6,
                    name = "Coordinate Precision",
                    desc = "Number of decimal places shown for X and Y coordinates.",
                    min = 0,
                    max = 2,
                    step = 1,
                    handler = Options,
                    get = "GetCoordinatePrecision",
                    set = "SetCoordinatePrecision",
                    disabled = function()
                        return not Options:GetShowCoordinates()
                    end,
                },
                showClock = {
                    type = "toggle",
                    order = 7,
                    name = "Clock",
                    desc = "Show a clock around the minimap.",
                    handler = Options,
                    get = "GetShowClock",
                    set = "SetShowClock",
                },
                clockPosition = {
                    type = "select",
                    order = 8,
                    name = "Clock Position",
                    values = CORNER_POSITION_VALUES,
                    handler = Options,
                    get = "GetClockPosition",
                    set = "SetClockPosition",
                    disabled = function()
                        return not Options:GetShowClock()
                    end,
                },
                clockOffsetX = {
                    type = "range",
                    order = 8.1,
                    name = "Clock Offset X",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetClockOffsetX",
                    set = "SetClockOffsetX",
                    disabled = function()
                        return not Options:GetShowClock()
                    end,
                },
                clockOffsetY = {
                    type = "range",
                    order = 8.2,
                    name = "Clock Offset Y",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetClockOffsetY",
                    set = "SetClockOffsetY",
                    disabled = function()
                        return not Options:GetShowClock()
                    end,
                },
                useLocalTime = {
                    type = "toggle",
                    order = 9,
                    name = "Use Local Time",
                    desc = "Use your computer time instead of the game server time.",
                    handler = Options,
                    get = "GetUseLocalTime",
                    set = "SetUseLocalTime",
                    disabled = function()
                        return not Options:GetShowClock()
                    end,
                },
                use24Hour = {
                    type = "toggle",
                    order = 10,
                    name = "24-Hour Clock",
                    desc = "Format the minimap clock using 24-hour time.",
                    handler = Options,
                    get = "GetUse24HourClock",
                    set = "SetUse24HourClock",
                    disabled = function()
                        return not Options:GetShowClock()
                    end,
                },
                showMail = {
                    type = "toggle",
                    order = 11,
                    name = "Mail Indicator",
                    desc = "Show a small animated mail badge when new mail is waiting.",
                    handler = Options,
                    get = "GetShowMailIndicator",
                    set = "SetShowMailIndicator",
                },
            }),
            typography = W.IGroup(30, "Typography", {
                titleFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 1,
                    name = "Title Font",
                    width = 2,
                    values = GetFontValues,
                    handler = Options,
                    get = "GetTitleFont",
                    set = "SetTitleFont",
                },
                titleSize = {
                    type = "range",
                    order = 2,
                    name = "Title Size",
                    min = 8,
                    max = 28,
                    step = 1,
                    handler = Options,
                    get = "GetTitleFontSize",
                    set = "SetTitleFontSize",
                },
                titleColor = {
                    type = "color",
                    order = 3,
                    name = "Title Color",
                    hasAlpha = false,
                    handler = Options,
                    get = "GetTitleColor",
                    set = "SetTitleColor",
                },
                detailFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 4,
                    name = "Detail Font",
                    width = 2,
                    values = GetFontValues,
                    handler = Options,
                    get = "GetDetailFont",
                    set = "SetDetailFont",
                },
                detailSize = {
                    type = "range",
                    order = 5,
                    name = "Detail Size",
                    min = 8,
                    max = 24,
                    step = 1,
                    handler = Options,
                    get = "GetDetailFontSize",
                    set = "SetDetailFontSize",
                },
                detailColor = {
                    type = "color",
                    order = 6,
                    name = "Detail Color",
                    hasAlpha = false,
                    handler = Options,
                    get = "GetDetailColor",
                    set = "SetDetailColor",
                },
                clockFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 7,
                    name = "Clock Font",
                    width = 2,
                    values = GetFontValues,
                    handler = Options,
                    get = "GetClockFont",
                    set = "SetClockFont",
                },
                clockSize = {
                    type = "range",
                    order = 8,
                    name = "Clock Size",
                    min = 8,
                    max = 24,
                    step = 1,
                    handler = Options,
                    get = "GetClockFontSize",
                    set = "SetClockFontSize",
                },
                clockColor = {
                    type = "color",
                    order = 9,
                    name = "Clock Color",
                    hasAlpha = false,
                    handler = Options,
                    get = "GetClockColor",
                    set = "SetClockColor",
                },
                coordinatesFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 10,
                    name = "Coordinates Font",
                    width = 2,
                    values = GetFontValues,
                    handler = Options,
                    get = "GetCoordinatesFont",
                    set = "SetCoordinatesFont",
                },
                coordinatesSize = {
                    type = "range",
                    order = 11,
                    name = "Coordinates Size",
                    min = 8,
                    max = 24,
                    step = 1,
                    handler = Options,
                    get = "GetCoordinatesFontSize",
                    set = "SetCoordinatesFontSize",
                },
                coordinatesColor = {
                    type = "color",
                    order = 12,
                    name = "Coordinates Color",
                    hasAlpha = false,
                    handler = Options,
                    get = "GetCoordinatesColor",
                    set = "SetCoordinatesColor",
                },
                mailFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    order = 13,
                    name = "Mail Font",
                    width = 2,
                    values = GetFontValues,
                    handler = Options,
                    get = "GetMailFont",
                    set = "SetMailFont",
                },
                mailSize = {
                    type = "range",
                    order = 14,
                    name = "Mail Size",
                    min = 8,
                    max = 20,
                    step = 1,
                    handler = Options,
                    get = "GetMailFontSize",
                    set = "SetMailFontSize",
                },
                mailColor = {
                    type = "color",
                    order = 15,
                    name = "Mail Color",
                    hasAlpha = false,
                    handler = Options,
                    get = "GetMailColor",
                    set = "SetMailColor",
                },
            }),
            buttons = W.IGroup(40, "Addon Buttons", {
                manage = {
                    type = "toggle",
                    order = 1,
                    name = "Manage Addon Buttons",
                    desc = "Collect eligible addon minimap buttons into a TwichUI bar.",
                    handler = Options,
                    get = "GetManageAddonButtons",
                    set = "SetManageAddonButtons",
                },
                position = {
                    type = "select",
                    order = 2,
                    name = "Bar Position",
                    values = EDGE_POSITION_VALUES,
                    handler = Options,
                    get = "GetAddonButtonPosition",
                    set = "SetAddonButtonPosition",
                    disabled = function()
                        return not Options:GetManageAddonButtons()
                    end,
                },
                offsetX = {
                    type = "range",
                    order = 2.1,
                    name = "Bar Offset X",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetAddonButtonOffsetX",
                    set = "SetAddonButtonOffsetX",
                    disabled = function()
                        return not Options:GetManageAddonButtons()
                    end,
                },
                offsetY = {
                    type = "range",
                    order = 2.2,
                    name = "Bar Offset Y",
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = Options,
                    get = "GetAddonButtonOffsetY",
                    set = "SetAddonButtonOffsetY",
                    disabled = function()
                        return not Options:GetManageAddonButtons()
                    end,
                },
                fade = {
                    type = "toggle",
                    order = 3,
                    name = "Fade Until Hovered",
                    desc = "Fade the addon button bar until the cursor moves over the minimap or bar.",
                    handler = Options,
                    get = "GetFadeAddonButtonsOnHover",
                    set = "SetFadeAddonButtonsOnHover",
                    disabled = function()
                        return not Options:GetManageAddonButtons()
                    end,
                },
                size = {
                    type = "range",
                    order = 4,
                    name = "Button Size",
                    desc = "Size of collected addon minimap buttons.",
                    min = 18,
                    max = 34,
                    step = 1,
                    handler = Options,
                    get = "GetAddonButtonSize",
                    set = "SetAddonButtonSize",
                    disabled = function()
                        return not Options:GetManageAddonButtons()
                    end,
                },
                activeAlpha = {
                    type = "range",
                    order = 5,
                    name = "Hover Alpha",
                    desc = "Alpha used while the button bar is hovered or fade is disabled.",
                    min = 0.05,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetAddonButtonActiveAlpha",
                    set = "SetAddonButtonActiveAlpha",
                    disabled = function()
                        return not Options:GetManageAddonButtons()
                    end,
                },
                inactiveAlpha = {
                    type = "range",
                    order = 6,
                    name = "Idle Alpha",
                    desc = "Alpha used while the button bar is fading out.",
                    min = 0.05,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetAddonButtonInactiveAlpha",
                    set = "SetAddonButtonInactiveAlpha",
                    disabled = function()
                        return not Options:GetManageAddonButtons() or not Options:GetFadeAddonButtonsOnHover()
                    end,
                },
            }),
            appearance = W.IGroup(50, "Appearance", {
                accentUsesTheme = {
                    type = "toggle",
                    order = 1,
                    name = "Use Global Accent",
                    desc = "Use the current TwichUI appearance accent for the minimap by default.",
                    handler = Options,
                    get = "GetAccentUsesTheme",
                    set = "SetAccentUsesTheme",
                },
                accentColor = {
                    type = "color",
                    order = 2,
                    name = "Accent Color",
                    desc = "Override the minimap accent color.",
                    hasAlpha = false,
                    handler = Options,
                    get = "GetAccentColor",
                    set = "SetAccentColor",
                    disabled = function()
                        return Options:GetAccentUsesTheme()
                    end,
                },
                backgroundAlpha = {
                    type = "range",
                    order = 3,
                    name = "Background Alpha",
                    desc = "Opacity of the minimap shell and button bar surfaces.",
                    min = 0.20,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetBackgroundAlpha",
                    set = "SetBackgroundAlpha",
                },
                borderAlpha = {
                    type = "range",
                    order = 4,
                    name = "Border Alpha",
                    desc = "Opacity of the minimap shell border.",
                    min = 0.10,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetBorderAlpha",
                    set = "SetBorderAlpha",
                },
                accentAlpha = {
                    type = "range",
                    order = 5,
                    name = "Accent Alpha",
                    desc = "Opacity of the accent strip along the minimap shell.",
                    min = 0.20,
                    max = 1,
                    step = 0.01,
                    handler = Options,
                    get = "GetAccentAlpha",
                    set = "SetAccentAlpha",
                },
            }),
        },
    }
end
