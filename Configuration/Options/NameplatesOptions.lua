---@diagnostic disable: undefined-field, inject-field
--[[
    NameplatesOptions.lua
    Option handlers and section builder for the Nameplates configuration panel.
]]
local TwichRx                          = _G.TwichRx
---@type TwichUI
local T                                = unpack(TwichRx)
local C_CVar                           = _G.C_CVar
local Enum_NamePlateStackType          = _G.Enum and _G.Enum.NamePlateStackType
local GetCVar                          = _G.GetCVar

---@type ConfigurationModule
local ConfigurationModule              = T:GetModule("Configuration")
local Widgets                          = ConfigurationModule.Widgets

---@class NameplatesConfigurationOptions
local Options                          = ConfigurationModule.Options.Nameplates or {}
ConfigurationModule.Options.Nameplates = Options

-- ── Value maps ───────────────────────────────────────────────────────────────
local HEALTH_COLOR_MODES               = {
    reaction = "Reaction",
    class    = "Class Color",
    theme    = "Theme Accent",
    custom   = "Custom",
}

local HEALTH_FORMAT_VALUES             = {
    none    = "None",
    percent = "Percent %",
    current = "Current Value",
    deficit = "Deficit",
}

local AURA_FILTER_VALUES               = {
    HARMFUL = "Debuffs",
    HELPFUL = "Buffs",
    ALL     = "All",
}

local NAME_FORMAT_VALUES               = {
    full  = "Full Name",
    short = "Short (10 chars)",
}

-- ── DB access ─────────────────────────────────────────────────────────────────
function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().nameplates then
        ConfigurationModule:GetProfileDB().nameplates = {}
    end
    return ConfigurationModule:GetProfileDB().nameplates
end

-- Friendly nameplate sub-table (mirrors enemy DB; keys not set here inherit from GetDB()).
function Options:GetFriendlyDB()
    local db = self:GetDB()
    if not db.friendly then db.friendly = {} end
    return db.friendly
end

-- Module getter
local function GetModule()
    return T:GetModule("Nameplates", true)
end

-- ── Enable / disable ──────────────────────────────────────────────────────────
function Options:IsModuleEnabled()
    return self:GetDB().enabled == true
end

function Options:SetModuleEnabled(_, value)
    self:GetDB().enabled = value == true
    local mod = GetModule()
    if not mod then return end
    if value then
        mod:Enable()
    else
        mod:Disable()
    end
end

-- ── Generic refresh helper ────────────────────────────────────────────────────
local function Refresh()
    local mod = GetModule()
    if mod and mod:IsEnabled() and type(mod.Refresh) == "function" then
        mod:Refresh()
    end
end

-- ── Value maps (extended) ────────────────────────────────────────────────────
local OUTLINE_VALUES = {
    OUTLINE      = "Outline",
    THICKOUTLINE = "Thick Outline",
    NONE         = "None",
}

local ANCHOR_HALIGN = {
    LEFT   = "Left",
    CENTER = "Center",
    RIGHT  = "Right",
}

local ANCHOR_TEXTS = {
    LEFT   = "Bar Left",
    CENTER = "Bar Center",
    RIGHT  = "Bar Right",
}

local LEGACY_NAME_ANCHORS = {
    BOTTOMLEFT  = "ABOVE_LEFT",
    BOTTOM      = "ABOVE_CENTER",
    BOTTOMRIGHT = "ABOVE_RIGHT",
    TOPLEFT     = "BELOW_LEFT",
    TOP         = "BELOW_CENTER",
    TOPRIGHT    = "BELOW_RIGHT",
    LEFT        = "HEALTH_LEFT",
    CENTER      = "HEALTH_CENTER",
    RIGHT       = "HEALTH_RIGHT",
}

local function NormalizeNameAnchor(anchor)
    return LEGACY_NAME_ANCHORS[anchor] or anchor or "ABOVE_LEFT"
end

local NAME_ANCHOR_POINTS = {
    ABOVE_LEFT    = "Above Left",
    ABOVE_CENTER  = "Above Center",
    ABOVE_RIGHT   = "Above Right",
    HEALTH_LEFT   = "Health Bar Left",
    HEALTH_CENTER = "Health Bar Center",
    HEALTH_RIGHT  = "Health Bar Right",
    BELOW_LEFT    = "Below Left",
    BELOW_CENTER  = "Below Center",
    BELOW_RIGHT   = "Below Right",
}

local RAID_MARKER_POINTS = {
    TOP = "Top",
    BOTTOM = "Bottom",
    LEFT = "Left",
    RIGHT = "Right",
    CENTER = "Center",
    TOPLEFT = "Top Left",
    TOPRIGHT = "Top Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOMRIGHT = "Bottom Right",
}

-- ── Individual getters / setters ──────────────────────────────────────────────

-- Width / height
function Options:GetWidth() return self:GetDB().width or 220 end

function Options:SetWidth(_, v)
    self:GetDB().width = math.max(60, math.min(500, math.floor(tonumber(v) or 220)))
    Refresh()
end

function Options:GetHeight() return self:GetDB().height or 22 end

function Options:SetHeight(_, v)
    self:GetDB().height = math.max(8, math.min(60, math.floor(tonumber(v) or 22)))
    Refresh()
end

function Options:GetCastHeight() return self:GetDB().castHeight or 12 end

function Options:SetCastHeight(_, v)
    self:GetDB().castHeight = math.max(6, math.min(30, math.floor(tonumber(v) or 12)))
    Refresh()
end

-- Alpha / scale
function Options:GetAlpha() return self:GetDB().alpha or 1 end

function Options:SetAlpha(_, v)
    self:GetDB().alpha = math.max(0.05, math.min(1, tonumber(v) or 1))
    Refresh()
end

function Options:GetScale() return self:GetDB().scale or 1 end

function Options:SetScale(_, v)
    self:GetDB().scale = math.max(0.5, math.min(2, tonumber(v) or 1))
    Refresh()
end

-- Health colour mode
function Options:GetHealthColorMode() return self:GetDB().healthColorMode or "reaction" end

function Options:SetHealthColorMode(_, v)
    self:GetDB().healthColorMode = v
    Refresh()
end

function Options:GetHealthCustomColor()
    local c = self:GetDB().healthCustomColor or { 0.28, 0.88, 0.42, 1 }
    return c[1], c[2], c[3], c[4] or 1
end

function Options:SetHealthCustomColor(_, r, g, b, a)
    self:GetDB().healthCustomColor = { r, g, b, a or 1 }
    Refresh()
end

-- Health text format
function Options:GetHealthFormat() return self:GetDB().healthFormat or "percent" end

function Options:SetHealthFormat(_, v)
    self:GetDB().healthFormat = v
    Refresh()
end

-- Show toggles
function Options:GetShowName() return self:GetDB().showName ~= false end

function Options:SetShowName(_, v)
    self:GetDB().showName = v == true; Refresh()
end

function Options:GetShowLevel() return self:GetDB().showLevel ~= false end

function Options:SetShowLevel(_, v)
    self:GetDB().showLevel = v == true; Refresh()
end

function Options:GetShowEliteIcon() return self:GetDB().showEliteIcon ~= false end

function Options:SetShowEliteIcon(_, v)
    self:GetDB().showEliteIcon = v == true; Refresh()
end

function Options:GetShowTargetGlow() return self:GetDB().showTargetGlow ~= false end

function Options:SetShowTargetGlow(_, v)
    self:GetDB().showTargetGlow = v == true; Refresh()
end

function Options:GetShowThreat() return self:GetDB().showThreat ~= false end

function Options:SetShowThreat(_, v)
    self:GetDB().showThreat = v == true; Refresh()
end

function Options:GetShowRaidMarker() return self:GetDB().showRaidMarker ~= false end

function Options:SetShowRaidMarker(_, v)
    self:GetDB().showRaidMarker = v == true; Refresh()
end

function Options:GetRaidMarkerPoint() return self:GetDB().raidMarkerPoint or "TOP" end

function Options:SetRaidMarkerPoint(_, v)
    self:GetDB().raidMarkerPoint = v or "TOP"; Refresh()
end

function Options:GetRaidMarkerOffsetX() return tonumber(self:GetDB().raidMarkerOffsetX) or 0 end

function Options:SetRaidMarkerOffsetX(_, v)
    self:GetDB().raidMarkerOffsetX = math.max(-80, math.min(80, tonumber(v) or 0)); Refresh()
end

function Options:GetRaidMarkerOffsetY() return tonumber(self:GetDB().raidMarkerOffsetY) or 0 end

function Options:SetRaidMarkerOffsetY(_, v)
    self:GetDB().raidMarkerOffsetY = math.max(-80, math.min(80, tonumber(v) or 0)); Refresh()
end

function Options:GetRaidMarkerScale() return tonumber(self:GetDB().raidMarkerScale) or 1 end

function Options:SetRaidMarkerScale(_, v)
    self:GetDB().raidMarkerScale = math.max(0.5, math.min(3, tonumber(v) or 1)); Refresh()
end

-- Aggro color override
function Options:GetShowAggroColor() return self:GetDB().showAggroColor ~= false end

function Options:SetShowAggroColor(_, v)
    self:GetDB().showAggroColor = v == true; Refresh()
end

function Options:GetAggroColorTank()
    local c = self:GetDB().aggroColorTank or { 0.25, 0.90, 0.40, 1 }
    return c[1], c[2], c[3], c[4] or 1
end

function Options:SetAggroColorTank(_, r, g, b, a)
    self:GetDB().aggroColorTank = { r, g, b, a or 1 }; Refresh()
end

function Options:GetAggroColorDps()
    local c = self:GetDB().aggroColorDps or { 1.00, 0.40, 0.10, 1 }
    return c[1], c[2], c[3], c[4] or 1
end

function Options:SetAggroColorDps(_, r, g, b, a)
    self:GetDB().aggroColorDps = { r, g, b, a or 1 }; Refresh()
end

function Options:GetShowAbsorb() return self:GetDB().showAbsorb ~= false end

function Options:SetShowAbsorb(_, v)
    self:GetDB().showAbsorb = v == true; Refresh()
end

function Options:GetShowCastBar() return self:GetDB().showCastBar ~= false end

function Options:SetShowCastBar(_, v)
    self:GetDB().showCastBar = v == true; Refresh()
end

-- Cast bar colour
function Options:GetCastColor()
    local c = self:GetDB().castColor or { 0.96, 0.76, 0.24, 1 }
    return c[1], c[2], c[3], c[4] or 1
end

function Options:SetCastColor(_, r, g, b, a)
    self:GetDB().castColor = { r, g, b, a or 1 }
    Refresh()
end

-- Auras
function Options:GetShowAuras() return self:GetDB().showAuras ~= false end

function Options:SetShowAuras(_, v)
    self:GetDB().showAuras = v == true; Refresh()
end

function Options:GetAuraFilter() return self:GetDB().auraFilter or "HARMFUL" end

function Options:SetAuraFilter(_, v)
    self:GetDB().auraFilter = v; Refresh()
end

function Options:GetAuraMax() return self:GetDB().auraMax or 5 end

function Options:SetAuraMax(_, v)
    self:GetDB().auraMax = math.max(0, math.min(10, math.floor(tonumber(v) or 5)))
    Refresh()
end

function Options:GetAuraSize() return self:GetDB().auraSize or 20 end

function Options:SetAuraSize(_, v)
    self:GetDB().auraSize = math.max(12, math.min(40, math.floor(tonumber(v) or 20)))
    Refresh()
end

-- Name format
function Options:GetNameFormat() return self:GetDB().nameFormat or "full" end

function Options:SetNameFormat(_, v)
    self:GetDB().nameFormat = v; Refresh()
end

-- Font sizes
function Options:GetNameFontSize() return self:GetDB().nameFontSize or 10 end

function Options:SetNameFontSize(_, v)
    self:GetDB().nameFontSize = math.max(6, math.min(20, math.floor(tonumber(v) or 10)))
    Refresh()
end

function Options:GetHealthFontSize() return self:GetDB().healthFontSize or 9 end

function Options:SetHealthFontSize(_, v)
    self:GetDB().healthFontSize = math.max(6, math.min(18, math.floor(tonumber(v) or 9)))
    Refresh()
end

function Options:GetCastFontSize() return self:GetDB().castFontSize or 9 end

function Options:SetCastFontSize(_, v)
    self:GetDB().castFontSize = math.max(6, math.min(16, math.floor(tonumber(v) or 9)))
    Refresh()
end

-- Max nameplate visibility distance
function Options:GetMaxDistance() return self:GetDB().nameplateMaxDistance or 60 end

function Options:SetMaxDistance(_, v)
    self:GetDB().nameplateMaxDistance = math.max(20, math.min(100, math.floor(tonumber(v) or 60)))
    Refresh()
end

local function GetCVarBoolSafe(name, fallback)
    if not GetCVar then return fallback end
    local value = GetCVar(name)
    if value == nil then return fallback end
    return value == "1"
end

local function SupportsPerTypeStacking()
    return C_CVar and C_CVar.GetCVarBitfield and C_CVar.SetCVarBitfield and Enum_NamePlateStackType
end

local function GetStackingBitfieldState(kind, fallback)
    if not SupportsPerTypeStacking() then return fallback end
    local stackType = Enum_NamePlateStackType[kind]
    if not stackType then return fallback end

    local ok, value = pcall(C_CVar.GetCVarBitfield, "nameplateStackingTypes", stackType)
    if ok and type(value) == "boolean" then
        return value
    end

    return fallback
end

function Options:SupportsPerTypeStacking()
    return SupportsPerTypeStacking() ~= nil
end

function Options:GetEnemyStackingEnabled()
    local value = self:GetDB().stackNameplates
    if value ~= nil then return value == true end
    if SupportsPerTypeStacking() then
        return GetStackingBitfieldState("Enemy", false)
    end
    return GetCVarBoolSafe("nameplateMotion", false)
end

function Options:SetEnemyStackingEnabled(_, value)
    self:GetDB().stackNameplates = value == true
    Refresh()
end

function Options:GetFriendlyStackingEnabled()
    local value = self:GetFriendlyDB().stackNameplates
    if value ~= nil then return value == true end
    if SupportsPerTypeStacking() then
        return GetStackingBitfieldState("Friendly", false)
    end
    return self:GetEnemyStackingEnabled()
end

function Options:SetFriendlyStackingEnabled(_, value)
    self:GetFriendlyDB().stackNameplates = value == true
    Refresh()
end

function Options:GetClampTargetNameplateToScreen()
    local value = self:GetDB().clampTargetNameplateToScreen
    if value ~= nil then return value == true end
    return GetCVarBoolSafe("clampTargetNameplateToScreen", true)
end

function Options:SetClampTargetNameplateToScreen(_, value)
    self:GetDB().clampTargetNameplateToScreen = value == true
    Refresh()
end

function Options:GetEnemyStackingWidthScale()
    return tonumber(self:GetDB().stackingWidthScale) or 1
end

function Options:SetEnemyStackingWidthScale(_, value)
    self:GetDB().stackingWidthScale = math.max(0.75, math.min(3, tonumber(value) or 1))
    Refresh()
end

function Options:GetEnemyStackingHeightScale()
    return tonumber(self:GetDB().stackingHeightScale) or 1
end

function Options:SetEnemyStackingHeightScale(_, value)
    self:GetDB().stackingHeightScale = math.max(0.75, math.min(4, tonumber(value) or 1))
    Refresh()
end

function Options:GetFriendlyStackingWidthScale()
    return tonumber(self:GetFriendlyDB().stackingWidthScale) or self:GetEnemyStackingWidthScale()
end

function Options:SetFriendlyStackingWidthScale(_, value)
    self:GetFriendlyDB().stackingWidthScale = math.max(0.75, math.min(3, tonumber(value) or 1))
    Refresh()
end

function Options:GetFriendlyStackingHeightScale()
    return tonumber(self:GetFriendlyDB().stackingHeightScale) or self:GetEnemyStackingHeightScale()
end

function Options:SetFriendlyStackingHeightScale(_, value)
    self:GetFriendlyDB().stackingHeightScale = math.max(0.75, math.min(4, tonumber(value) or 1))
    Refresh()
end

-- Test mode helpers
function Options:IsInTestMode()
    local mod = GetModule()
    return mod and mod._testMode == true or false
end

function Options:ToggleTestMode()
    local mod = GetModule()
    if mod and type(mod.ToggleTestMode) == "function" then mod:ToggleTestMode() end
end

function Options:IsInCastTestMode()
    local mod = GetModule()
    return mod and mod._castTestMode == true or false
end

function Options:ToggleCastTestMode()
    local mod = GetModule()
    if mod and type(mod.ToggleCastBarTestMode) == "function" then mod:ToggleCastBarTestMode() end
end

-- ── Reaction / classification color getters ──────────────────────────────────
local function GetReactionColor(key, r, g, b)
    local c = Options:GetDB()[key]
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
    return r, g, b, 1
end
local function SetReactionColor(key, r, g, b, a)
    Options:GetDB()[key] = { r, g, b, a or 1 }
    Refresh()
end

-- ── Per-element font getters ──────────────────────────────────────────────────
local function GetFontFace(key) return Options:GetDB()[key .. "Font"] or "__default" end
local function SetFontFace(key, v)
    Options:GetDB()[key .. "Font"] = (v == "__default") and nil or v
    Refresh()
end
local function GetFontOutline(key) return Options:GetDB()[key .. "FontOutline"] or "OUTLINE" end
local function SetFontOutline(key, v)
    Options:GetDB()[key .. "FontOutline"] = v
    Refresh()
end
local function GetFontShadow(key) return Options:GetDB()[key .. "FontShadow"] == true end
local function SetFontShadow(key, v)
    Options:GetDB()[key .. "FontShadow"] = v == true
    Refresh()
end
local function GetFontColor(key)
    local c = Options:GetDB()[key .. "FontColor"]
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
    return 1, 1, 1, 1
end
local function SetFontColor(key, r, g, b, a)
    Options:GetDB()[key .. "FontColor"] = { r, g, b, a or 1 }
    Refresh()
end

-- ── Per-element bar texture getters ──────────────────────────────────────────
local function GetBarTexture(key)
    return Options:GetDB()[key] or "__default"
end
local function SetBarTexture(key, v)
    Options:GetDB()[key] = (v == "__default") and nil or v
    Refresh()
end
local function GetBarBgColor(key)
    local c = Options:GetDB()[key]
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 0.92 end
    if key == "healthBgColor" then return 0.05, 0.06, 0.08, 0.92 end
    return 0.05, 0.06, 0.08, 0.92
end
local function SetBarBgColor(key, r, g, b, a)
    Options:GetDB()[key] = { r, g, b, a or 0.92 }
    Refresh()
end
local function GetBarBorderColor(key)
    local c = Options:GetDB()[key]
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 0.9 end
    return 0.14, 0.15, 0.20, 0.9
end
local function SetBarBorderColor(key, r, g, b, a)
    Options:GetDB()[key] = { r, g, b, a or 0.9 }
    Refresh()
end

-- LSM list helpers
local function FontList()
    local LSM = T.Libs and T.Libs.LSM
    local list = { ["__default"] = "Theme Default" }
    if LSM then
        for name in pairs(LSM:HashTable("font") or {}) do list[name] = name end
    end
    return list
end
local function TextureList()
    local LSM = T.Libs and T.Libs.LSM
    local list = { ["__default"] = "Theme Default" }
    if LSM then
        for name in pairs(LSM:HashTable("statusbar") or {}) do list[name] = name end
    end
    return list
end

-- Target options
function Options:GetTargetGrowWidth() return self:GetDB().targetGrowWidth or 1 end

function Options:SetTargetGrowWidth(_, v)
    self:GetDB().targetGrowWidth = math.max(0.5, math.min(2, tonumber(v) or 1)); Refresh()
end

function Options:GetTargetGrowHeight() return self:GetDB().targetGrowHeight or 1 end

function Options:SetTargetGrowHeight(_, v)
    self:GetDB().targetGrowHeight = math.max(0.5, math.min(2, tonumber(v) or 1)); Refresh()
end

function Options:GetShowTargetArrows() return self:GetDB().showTargetArrows ~= false end

function Options:SetShowTargetArrows(_, v)
    self:GetDB().showTargetArrows = v == true; Refresh()
end

function Options:GetTargetArrowSize() return self:GetDB().targetArrowSize or 16 end

function Options:SetTargetArrowSize(_, v)
    self:GetDB().targetArrowSize = math.max(8, math.min(32, math.floor(tonumber(v) or 16))); Refresh()
end

-- All .tga files in Media/Textures/Arrows/ (Arrow0-72, ArrowBracket, ArrowRed, ArrowUp)
local ARROW_BASE = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Arrows\\"
local ALL_ARROW_STYLES = nil
local function GetAllArrowStyles()
    if ALL_ARROW_STYLES then return ALL_ARROW_STYLES end
    ALL_ARROW_STYLES = { "ArrowUp", "ArrowBracket", "ArrowRed" }
    for i = 0, 72 do ALL_ARROW_STYLES[#ALL_ARROW_STYLES + 1] = "Arrow" .. i end
    return ALL_ARROW_STYLES
end

-- ── Arrow picker popup ────────────────────────────────────────────────────────
-- A floating AceGUI window showing all arrow styles as clickable icon buttons.
local _arrowPickerFrame = nil

local function OpenArrowPicker()
    local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
    if not AceGUI then return end

    -- If already open, close (toggle behaviour)
    if _arrowPickerFrame then
        _arrowPickerFrame:Hide()
        _arrowPickerFrame = nil
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Select Arrow Style")
    frame:SetStatusText("Click an arrow to select  |  " .. Options:GetTargetArrowStyle() .. " is current")
    frame:SetLayout("Flow")
    frame:SetWidth(560)
    frame:SetHeight(420)
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        _arrowPickerFrame = nil
    end)
    _arrowPickerFrame = frame

    local current = Options:GetTargetArrowStyle()

    for _, style in ipairs(GetAllArrowStyles()) do
        local s       = style
        -- Short display label: "ArrowUp" → "Up", "Arrow0" → "0"
        local label   = s:match("^Arrow(.+)$") or s
        local texPath = ARROW_BASE .. s .. ".tga"

        local icon    = AceGUI:Create("Icon")
        icon:SetImage(texPath)
        icon:SetImageSize(40, 40)
        icon:SetLabel(label)
        icon:SetWidth(68)
        if s == current then
            icon.label:SetTextColor(0.2, 1, 0.3)
            icon.image:SetVertexColor(0.2, 1, 0.3, 1)
        end
        icon:SetCallback("OnClick", function()
            Options:SetTargetArrowStyle(nil, s)
            -- Close the picker; the config panel refreshes automatically via Refresh()
            if _arrowPickerFrame then
                _arrowPickerFrame:Hide()
                _arrowPickerFrame = nil
            end
        end)
        frame:AddChild(icon)
    end
end

function Options:GetTargetArrowStyle() return self:GetDB().targetArrowStyle or "ArrowUp" end

function Options:SetTargetArrowStyle(_, v)
    self:GetDB().targetArrowStyle = v; Refresh()
end

function Options:GetTargetArrowPreviewTex()
    return ARROW_BASE .. self:GetTargetArrowStyle() .. ".tga"
end

function Options:GetTargetGlowOutset() return self:GetDB().targetGlowOutset or 3 end

function Options:SetTargetGlowOutset(_, v)
    self:GetDB().targetGlowOutset = math.max(1, math.min(10, math.floor(tonumber(v) or 3))); Refresh()
end

function Options:GetTargetGlowColor()
    local c = self:GetDB().targetGlowColor
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 0.9 end
    return 0.96, 0.76, 0.24, 0.9
end

function Options:SetTargetGlowColor(_, r, g, b, a)
    self:GetDB().targetGlowColor = { r, g, b, a or 0.9 }; Refresh()
end

function Options:GetFocusGlowColor()
    local c = self:GetDB().focusGlowColor
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 0.7 end
    return 0.22, 0.78, 0.96, 0.7
end

function Options:SetFocusGlowColor(_, r, g, b, a)
    self:GetDB().focusGlowColor = { r, g, b, a or 0.7 }; Refresh()
end

-- Target arrow color (separate from glow color; nil = use glow color)
function Options:GetTargetArrowColor()
    local c = self:GetDB().targetArrowColor
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 1 end
    -- Default: match the glow color
    return Options:GetTargetGlowColor()
end

function Options:SetTargetArrowColor(_, r, g, b, a)
    self:GetDB().targetArrowColor = { r, g, b, a or 1 }; Refresh()
end

-- Power bar
function Options:GetShowPowerBar() return self:GetDB().showPowerBar ~= false end

function Options:SetShowPowerBar(_, v)
    self:GetDB().showPowerBar = v == true; Refresh()
end

function Options:GetPowerBarHeight() return self:GetDB().powerBarHeight or 4 end

function Options:SetPowerBarHeight(_, v)
    self:GetDB().powerBarHeight = math.max(2, math.min(14, math.floor(tonumber(v) or 4))); Refresh()
end

function Options:GetPowerBarGap() return self:GetDB().powerBarGap or 2 end

function Options:SetPowerBarGap(_, v)
    self:GetDB().powerBarGap = math.max(0, math.min(12, math.floor(tonumber(v) or 2))); Refresh()
end

function Options:GetPowerBgColor()
    local c = self:GetDB().powerBgColor or { 0.05, 0.06, 0.08, 0.92 }
    return c[1], c[2], c[3], c[4] or 0.92
end

function Options:SetPowerBgColor(_, r, g, b, a)
    self:GetDB().powerBgColor = { r, g, b, a or 0.92 }; Refresh()
end

function Options:GetPowerBorderColor()
    local c = self:GetDB().powerBorderColor or { 0.14, 0.15, 0.20, 0.90 }
    return c[1], c[2], c[3], c[4] or 0.9
end

function Options:SetPowerBorderColor(_, r, g, b, a)
    self:GetDB().powerBorderColor = { r, g, b, a or 0.9 }; Refresh()
end

-- Aura extra options
function Options:GetAuraOnlyMine() return self:GetDB().auraOnlyMine == true end

function Options:SetAuraOnlyMine(_, v)
    self:GetDB().auraOnlyMine = v == true; Refresh()
end

function Options:GetAuraShowTimer() return self:GetDB().auraShowTimer ~= false end

function Options:SetAuraShowTimer(_, v)
    self:GetDB().auraShowTimer = v == true; Refresh()
end

function Options:GetAuraTimerFontSize() return self:GetDB().auraTimerFontSize or 8 end

function Options:SetAuraTimerFontSize(_, v)
    self:GetDB().auraTimerFontSize = math.max(6, math.min(28, math.floor(tonumber(v) or 8))); Refresh()
end

function Options:GetAuraTestMode() return self:GetDB().auraTestMode ~= false end

function Options:SetAuraTestMode(_, v)
    self:GetDB().auraTestMode = v == true; Refresh()
end

-- caster color toggle
function Options:GetColorByCaster() return self:GetDB().colorByCaster == true end

function Options:SetColorByCaster(_, v)
    self:GetDB().colorByCaster = v == true; Refresh()
end

-- ── AceConfig table builder ───────────────────────────────────────────────────
function Options:BuildConfiguration()
    return {
        type        = "group",
        name        = "Nameplates",
        childGroups = "tab",
        args        = {
            enemy = {
                type        = "group",
                name        = "Enemy",
                order       = 1,
                childGroups = "tab",
                args        = {

                    -- ── General tab ──────────────────────────────────────────────────
                    general = {
                        type  = "group",
                        name  = "General",
                        order = 1,
                        args  = {
                            enabled = {
                                type  = "toggle",
                                name  = "Enable Nameplates",
                                desc  = "Replace Blizzard's default nameplates with TwichUI nameplates.",
                                order = 1,
                                width = "full",
                                get   = function() return Options:IsModuleEnabled() end,
                                set   = function(_, v) Options:SetModuleEnabled(_, v) end,
                            },
                            testMode = {
                                type  = "execute",
                                name  = function()
                                    return Options:IsInTestMode() and "Exit Preview Mode" or "Enter Preview Mode"
                                end,
                                desc  = "Show mock nameplates to tune appearance without live targets.",
                                order = 2,
                                func  = function() Options:ToggleTestMode() end,
                            },
                            diagDump = {
                                type  = "execute",
                                name  = "Dump Plate State to Chat",
                                desc  =
                                "Prints live nameplate frame diagnostics to the chat window. Equivalent to /tui npdebug.",
                                order = 3,
                                func  = function()
                                    local mod = T:GetModule("Nameplates", true)
                                    if not mod then
                                        T:Print("[NP] Module not loaded."); return
                                    end
                                    local db = mod.GetDB and mod:GetDB()
                                    if db then
                                        T:Print(string.format("[NP] healthFormat=%s  healthFontSize=%s  healthFont=%s",
                                            tostring(db.healthFormat), tostring(db.healthFontSize),
                                            tostring(db.healthFont)))
                                        T:Print(string.format("[NP] healthTextAnchor=%s  showAbsorb=%s",
                                            tostring(db.healthTextAnchor), tostring(db.showAbsorb)))
                                    end
                                    T:Print(string.format("[NP] IsEnabled=%s", tostring(mod:IsEnabled())))
                                    local total, visible = 0, 0
                                    if mod._plates then
                                        for _, frame in pairs(mod._plates) do
                                            total = total + 1
                                            if frame and frame:IsShown() then visible = visible + 1 end
                                        end
                                    end
                                    T:Print(string.format("[NP] Tracked plates: %d  Visible: %d", total, visible))
                                    if mod._plates then
                                        for unit, frame in pairs(mod._plates) do
                                            if frame and frame:IsShown() then
                                                T:Print(string.format("[NP] Sample unit: %s", tostring(unit)))
                                                local ht = frame.healthText
                                                if ht then
                                                    local font, size = ht:GetFont()
                                                    T:Print(string.format(
                                                        "  healthText: IsShown=%s Text='%s' Points=%d Font=%s sz=%s",
                                                        tostring(ht:IsShown()), tostring(ht:GetText() or ""),
                                                        ht:GetNumPoints(), tostring(font), tostring(size)))
                                                else
                                                    T:Print("  healthText: NOT CREATED")
                                                end
                                                break
                                            end
                                        end
                                    end
                                end,
                            },
                            sep1 = { type = "header", name = "Layout", order = 10 },
                            width = {
                                type = "range",
                                name = "Bar Width",
                                order = 11,
                                min = 60,
                                max = 500,
                                step = 5,
                                bigStep = 10,
                                get = function() return Options:GetWidth() end,
                                set = function(_, v) Options:SetWidth(_, v) end,
                            },
                            height = {
                                type = "range",
                                name = "Bar Height",
                                order = 12,
                                min = 8,
                                max = 60,
                                step = 1,
                                get = function() return Options:GetHeight() end,
                                set = function(_, v) Options:SetHeight(_, v) end,
                            },
                            castHeight = {
                                type = "range",
                                name = "Cast Bar Height",
                                order = 13,
                                min = 6,
                                max = 30,
                                step = 1,
                                get = function() return Options:GetCastHeight() end,
                                set = function(_, v) Options:SetCastHeight(_, v) end,
                            },
                            sep2 = { type = "header", name = "Visibility", order = 20 },
                            alpha = {
                                type = "range",
                                name = "Alpha",
                                order = 21,
                                min = 0.05,
                                max = 1.0,
                                step = 0.05,
                                get = function() return Options:GetAlpha() end,
                                set = function(_, v) Options:SetAlpha(_, v) end,
                            },
                            scale = {
                                type = "range",
                                name = "Scale",
                                order = 22,
                                min = 0.5,
                                max = 2.0,
                                step = 0.05,
                                get = function() return Options:GetScale() end,
                                set = function(_, v) Options:SetScale(_, v) end,
                            },
                            maxDistance = {
                                type = "range",
                                name = "Visibility Distance",
                                desc = "Maximum range at which nameplates appear (yards).",
                                order = 23,
                                min = 20,
                                max = 100,
                                step = 5,
                                get = function() return Options:GetMaxDistance() end,
                                set = function(_, v) Options:SetMaxDistance(_, v) end,
                            },
                            sep_positioning = { type = "header", name = "Positioning", order = 30 },
                            positioningHelp = {
                                type = "description",
                                name =
                                "Stacking and target clamp are driven by Blizzard on Midnight. TwichUI adds custom stacking footprint controls so dense pulls reserve enough room for cast and power bars.",
                                order = 31,
                                width = "full",
                            },
                            clampTargetNameplateToScreen = {
                                type = "toggle",
                                name = "Clamp Target Plate To Screen",
                                desc =
                                "Keep your current target nameplate pinned to the screen edge instead of letting it drift offscreen.",
                                order = 32,
                                width = "full",
                                get = function() return Options:GetClampTargetNameplateToScreen() end,
                                set = function(_, v) Options:SetClampTargetNameplateToScreen(_, v) end,
                            },
                            stackNameplates = {
                                type = "toggle",
                                name = "Stack Enemy Plates",
                                desc =
                                "Use stacked placement for enemy nameplates to reduce overlap in large pulls.",
                                order = 33,
                                width = "full",
                                get = function() return Options:GetEnemyStackingEnabled() end,
                                set = function(_, v) Options:SetEnemyStackingEnabled(_, v) end,
                            },
                            stackingWidthScale = {
                                type = "range",
                                name = "Enemy Stack Width",
                                desc =
                                "Scale the horizontal footprint Blizzard uses when spacing stacked enemy plates. Increase this if cast icons or side elements feel cramped.",
                                order = 34,
                                min = 0.75,
                                max = 3,
                                step = 0.05,
                                bigStep = 0.1,
                                get = function() return Options:GetEnemyStackingWidthScale() end,
                                set = function(_, v) Options:SetEnemyStackingWidthScale(_, v) end,
                            },
                            stackingHeightScale = {
                                type = "range",
                                name = "Enemy Stack Height",
                                desc =
                                "Scale the downward stacking footprint for enemy plates. Increase this to reserve more room for cast and power bars.",
                                order = 35,
                                min = 0.75,
                                max = 4,
                                step = 0.05,
                                bigStep = 0.1,
                                get = function() return Options:GetEnemyStackingHeightScale() end,
                                set = function(_, v) Options:SetEnemyStackingHeightScale(_, v) end,
                            },
                        },
                    },

                    -- ── Colors tab ───────────────────────────────────────────────────
                    colors = {
                        type  = "group",
                        name  = "Colors",
                        order = 2,
                        args  = {
                            healthColorMode = {
                                type = "select",
                                name = "Health Color Mode",
                                order = 1,
                                values = HEALTH_COLOR_MODES,
                                get = function() return Options:GetHealthColorMode() end,
                                set = function(_, v) Options:SetHealthColorMode(_, v) end,
                            },
                            healthCustomColor = {
                                type     = "color",
                                name     = "Custom Health Color",
                                order    = 2,
                                hasAlpha = false,
                                hidden   = function() return Options:GetHealthColorMode() ~= "custom" end,
                                get      = function() return Options:GetHealthCustomColor() end,
                                set      = function(_, r, g, b, a) Options:SetHealthCustomColor(_, r, g, b, a) end,
                            },
                            sepRC = { type = "header", name = "Reaction Colors", order = 10 },
                            colorHostile = {
                                type = "color",
                                name = "Hostile",
                                order = 11,
                                hasAlpha = false,
                                get = function() return GetReactionColor("colorHostile", 0.87, 0.25, 0.25) end,
                                set = function(_, r, g, b, a) SetReactionColor("colorHostile", r, g, b, a) end,
                            },
                            colorNeutral = {
                                type = "color",
                                name = "Neutral",
                                order = 12,
                                hasAlpha = false,
                                get = function() return GetReactionColor("colorNeutral", 0.92, 0.77, 0.22) end,
                                set = function(_, r, g, b, a) SetReactionColor("colorNeutral", r, g, b, a) end,
                            },
                            colorFriendly = {
                                type = "color",
                                name = "Friendly",
                                order = 13,
                                hasAlpha = false,
                                get = function() return GetReactionColor("colorFriendly", 0.28, 0.88, 0.42) end,
                                set = function(_, r, g, b, a) SetReactionColor("colorFriendly", r, g, b, a) end,
                            },
                            colorTapped = {
                                type = "color",
                                name = "Tapped",
                                order = 14,
                                hasAlpha = false,
                                get = function() return GetReactionColor("colorTapped", 0.48, 0.48, 0.48) end,
                                set = function(_, r, g, b, a) SetReactionColor("colorTapped", r, g, b, a) end,
                            },
                            sepClass = { type = "header", name = "Classification Colors (Hostile Only)", order = 20 },
                            colorBoss = {
                                type = "color",
                                name = "Boss / World Boss",
                                order = 21,
                                hasAlpha = false,
                                get = function() return GetReactionColor("colorBoss", 0.90, 0.10, 0.10) end,
                                set = function(_, r, g, b, a) SetReactionColor("colorBoss", r, g, b, a) end,
                            },
                            colorMiniboss = {
                                type = "color",
                                name = "Rare Elite",
                                order = 22,
                                hasAlpha = false,
                                get = function() return GetReactionColor("colorMiniboss", 0.75, 0.30, 0.90) end,
                                set = function(_, r, g, b, a) SetReactionColor("colorMiniboss", r, g, b, a) end,
                            },
                            colorRare = {
                                type = "color",
                                name = "Rare",
                                order = 23,
                                hasAlpha = false,
                                get = function() return GetReactionColor("colorRare", 0.50, 0.80, 1.00) end,
                                set = function(_, r, g, b, a) SetReactionColor("colorRare", r, g, b, a) end,
                            },
                            colorByCaster = {
                                type  = "toggle",
                                name  = "Differentiate Casters",
                                order = 24,
                                desc  =
                                "Use a separate color for NPC units that are inherently caster-type (e.g. Paladin healer NPCs, detected via class type — not active casting).",
                                get   = function() return Options:GetColorByCaster() end,
                                set   = function(_, v) Options:SetColorByCaster(_, v) end,
                            },
                            colorNpcCaster = {
                                type     = "color",
                                name     = "NPC Caster Color",
                                order    = 25,
                                hasAlpha = false,
                                hidden   = function() return not Options:GetColorByCaster() end,
                                get      = function() return GetReactionColor("colorNpcCaster", 0.90, 0.45, 0.22) end,
                                set      = function(_, r, g, b, a) SetReactionColor("colorNpcCaster", r, g, b, a) end,
                            },
                        },
                    },

                    -- ── Health tab ───────────────────────────────────────────────────
                    -- Contains: bar texture/colors, health text, absorb, and health font.
                    health = {
                        type  = "group",
                        name  = "Health",
                        order = 3,
                        args  = {
                            sep_display = { type = "header", name = "Display", order = 1 },
                            healthFormat = {
                                type = "select",
                                name = "Health Text Format",
                                order = 2,
                                values = HEALTH_FORMAT_VALUES,
                                get = function() return Options:GetHealthFormat() end,
                                set = function(_, v) Options:SetHealthFormat(_, v) end,
                            },
                            showAbsorb = {
                                type  = "toggle",
                                name  = "Show Absorb Overlay",
                                order = 3,
                                get   = function() return Options:GetShowAbsorb() end,
                                set   = function(_, v) Options:SetShowAbsorb(_, v) end,
                            },
                            sep_tex = { type = "header", name = "Health Bar", order = 10 },
                            healthBarTexture = {
                                type   = "select",
                                name   = "Bar Texture",
                                order  = 11,
                                values = TextureList,
                                get    = function() return GetBarTexture("healthBarTexture") end,
                                set    = function(_, v) SetBarTexture("healthBarTexture", v) end,
                            },
                            healthBgTexture = {
                                type   = "select",
                                name   = "Background Texture",
                                order  = 12,
                                values = TextureList,
                                get    = function() return GetBarTexture("healthBgTexture") end,
                                set    = function(_, v) SetBarTexture("healthBgTexture", v) end,
                            },
                            healthBgColor = {
                                type     = "color",
                                name     = "Background Color",
                                order    = 13,
                                hasAlpha = true,
                                get      = function() return GetBarBgColor("healthBgColor") end,
                                set      = function(_, r, g, b, a) SetBarBgColor("healthBgColor", r, g, b, a) end,
                            },
                            healthBorderColor = {
                                type     = "color",
                                name     = "Border Color",
                                order    = 14,
                                hasAlpha = true,
                                get      = function() return GetBarBorderColor("healthBorderColor") end,
                                set      = function(_, r, g, b, a) SetBarBorderColor("healthBorderColor", r, g, b, a) end,
                            },
                            sep_font = { type = "header", name = "Health Text Font", order = 20 },
                            healthFontFace = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 21,
                                values = FontList,
                                get    = function() return GetFontFace("health") end,
                                set    = function(_, v) SetFontFace("health", v) end,
                            },
                            healthFontSize = {
                                type  = "range",
                                name  = "Font Size",
                                order = 22,
                                min   = 6,
                                max   = 18,
                                step  = 1,
                                get   = function() return Options:GetHealthFontSize() end,
                                set   = function(_, v) Options:SetHealthFontSize(_, v) end,
                            },
                            healthFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 23,
                                values = OUTLINE_VALUES,
                                get    = function() return GetFontOutline("health") end,
                                set    = function(_, v) SetFontOutline("health", v) end,
                            },
                            healthFontShadow = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 24,
                                get   = function() return GetFontShadow("health") end,
                                set   = function(_, v) SetFontShadow("health", v) end,
                            },
                            healthFontColor = {
                                type     = "color",
                                name     = "Text Color Override",
                                order    = 25,
                                hasAlpha = true,
                                get      = function() return GetFontColor("health") end,
                                set      = function(_, r, g, b, a) SetFontColor("health", r, g, b, a) end,
                            },
                            healthTextAnchor = {
                                type   = "select",
                                name   = "Text Align",
                                order  = 26,
                                values = ANCHOR_TEXTS,
                                get    = function() return Options:GetDB().healthTextAnchor or "RIGHT" end,
                                set    = function(_, v)
                                    Options:GetDB().healthTextAnchor = v; Refresh()
                                end,
                            },
                        },
                    },

                    -- ── Name & Level tab ─────────────────────────────────────────────
                    -- Contains: show toggles, name format, elite icon, and name font.
                    nameLevel = {
                        type  = "group",
                        name  = "Name & Level",
                        order = 4,
                        args  = {
                            showName = {
                                type  = "toggle",
                                name  = "Show Name",
                                order = 1,
                                get   = function() return Options:GetShowName() end,
                                set   = function(_, v) Options:SetShowName(_, v) end,
                            },
                            nameFormat = {
                                type   = "select",
                                name   = "Name Format",
                                order  = 2,
                                values = NAME_FORMAT_VALUES,
                                hidden = function() return not Options:GetShowName() end,
                                get    = function() return Options:GetNameFormat() end,
                                set    = function(_, v) Options:SetNameFormat(_, v) end,
                            },
                            showLevel = {
                                type  = "toggle",
                                name  = "Show Level",
                                order = 3,
                                get   = function() return Options:GetShowLevel() end,
                                set   = function(_, v) Options:SetShowLevel(_, v) end,
                            },
                            showEliteIcon = {
                                type  = "toggle",
                                name  = "Show Elite/Boss Icon",
                                order = 4,
                                get   = function() return Options:GetShowEliteIcon() end,
                                set   = function(_, v) Options:SetShowEliteIcon(_, v) end,
                            },
                            nameColorClass = {
                                type  = "toggle",
                                name  = "Color Name by Class",
                                order = 5,
                                desc  = "Color the name text with the unit's class color (players only).",
                                get   = function() return Options:GetDB().nameColorClass == true end,
                                set   = function(_, v)
                                    Options:GetDB().nameColorClass = v == true; Refresh()
                                end,
                            },
                            sep_font = { type = "header", name = "Name Text Font", order = 10 },
                            nameFontFace = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 11,
                                values = FontList,
                                get    = function() return GetFontFace("name") end,
                                set    = function(_, v) SetFontFace("name", v) end,
                            },
                            nameFontSize = {
                                type  = "range",
                                name  = "Font Size",
                                order = 12,
                                min   = 6,
                                max   = 20,
                                step  = 1,
                                get   = function() return Options:GetNameFontSize() end,
                                set   = function(_, v) Options:SetNameFontSize(_, v) end,
                            },
                            nameFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 13,
                                values = OUTLINE_VALUES,
                                get    = function() return GetFontOutline("name") end,
                                set    = function(_, v) SetFontOutline("name", v) end,
                            },
                            nameFontShadow = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 14,
                                get   = function() return GetFontShadow("name") end,
                                set   = function(_, v) SetFontShadow("name", v) end,
                            },
                            nameFontColor = {
                                type     = "color",
                                name     = "Text Color Override",
                                order    = 15,
                                hasAlpha = true,
                                get      = function() return GetFontColor("name") end,
                                set      = function(_, r, g, b, a) SetFontColor("name", r, g, b, a) end,
                            },
                            sep_pos = { type = "header", name = "Name Position", order = 20 },
                            nameAnchorPoint = {
                                type   = "select",
                                name   = "Text Anchor",
                                order  = 21,
                                values = NAME_ANCHOR_POINTS,
                                get    = function() return NormalizeNameAnchor(Options:GetDB().nameAnchorPoint) end,
                                set    = function(_, v)
                                    Options:GetDB().nameAnchorPoint = v; Refresh()
                                end,
                            },
                            nameJustify = {
                                type   = "select",
                                name   = "Justify",
                                order  = 22,
                                values = ANCHOR_HALIGN,
                                get    = function() return Options:GetDB().nameJustify or "LEFT" end,
                                set    = function(_, v)
                                    Options:GetDB().nameJustify = v; Refresh()
                                end,
                            },
                            nameOffsetX = {
                                type  = "range",
                                name  = "Offset X",
                                order = 23,
                                min   = -20,
                                max   = 20,
                                step  = 1,
                                get   = function() return Options:GetDB().nameOffsetX or 2 end,
                                set   = function(_, v)
                                    Options:GetDB().nameOffsetX = v; Refresh()
                                end,
                            },
                            nameOffsetY = {
                                type  = "range",
                                name  = "Offset Y",
                                order = 24,
                                min   = -20,
                                max   = 20,
                                step  = 1,
                                get   = function() return Options:GetDB().nameOffsetY or 3 end,
                                set   = function(_, v)
                                    Options:GetDB().nameOffsetY = v; Refresh()
                                end,
                            },
                            nameWidth = {
                                type  = "range",
                                name  = "Text Width",
                                desc  = "0 uses the automatic anchor width.",
                                order = 25,
                                min   = 0,
                                max   = 600,
                                step  = 1,
                                get   = function() return Options:GetDB().nameWidth or 0 end,
                                set   = function(_, v)
                                    Options:GetDB().nameWidth = (v and v > 0) and math.floor(v) or nil; Refresh()
                                end,
                            },
                        },
                    },

                    -- ── Cast Bar tab ─────────────────────────────────────────────────
                    -- Contains: show toggle, colors, texture/bg/border, cast font.
                    castbar = {
                        type  = "group",
                        name  = "Cast Bar",
                        order = 5,
                        args  = {
                            showCastBar = {
                                type  = "toggle",
                                name  = "Show Cast Bar",
                                order = 1,
                                width = "full",
                                get   = function() return Options:GetShowCastBar() end,
                                set   = function(_, v) Options:SetShowCastBar(_, v) end,
                            },
                            castColor = {
                                type     = "color",
                                name     = "Cast Bar Color",
                                order    = 2,
                                hasAlpha = false,
                                get      = function() return Options:GetCastColor() end,
                                set      = function(_, r, g, b, a) Options:SetCastColor(_, r, g, b, a) end,
                            },
                            sep_tex = { type = "header", name = "Cast Bar Appearance", order = 10 },
                            castBarTexture = {
                                type   = "select",
                                name   = "Bar Texture",
                                order  = 11,
                                values = TextureList,
                                get    = function() return GetBarTexture("castBarTexture") end,
                                set    = function(_, v) SetBarTexture("castBarTexture", v) end,
                            },
                            castBgColor = {
                                type     = "color",
                                name     = "Background Color",
                                order    = 12,
                                hasAlpha = true,
                                get      = function() return GetBarBgColor("castBgColor") end,
                                set      = function(_, r, g, b, a) SetBarBgColor("castBgColor", r, g, b, a) end,
                            },
                            castBorderColor = {
                                type     = "color",
                                name     = "Border Color",
                                order    = 13,
                                hasAlpha = true,
                                get      = function() return GetBarBorderColor("castBorderColor") end,
                                set      = function(_, r, g, b, a) SetBarBorderColor("castBorderColor", r, g, b, a) end,
                            },
                            sep_font = { type = "header", name = "Cast Bar Font", order = 20 },
                            castFontFace = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 21,
                                values = FontList,
                                get    = function() return GetFontFace("cast") end,
                                set    = function(_, v) SetFontFace("cast", v) end,
                            },
                            castFontSize = {
                                type  = "range",
                                name  = "Font Size",
                                order = 22,
                                min   = 6,
                                max   = 16,
                                step  = 1,
                                get   = function() return Options:GetCastFontSize() end,
                                set   = function(_, v) Options:SetCastFontSize(_, v) end,
                            },
                            castFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 23,
                                values = OUTLINE_VALUES,
                                get    = function() return GetFontOutline("cast") end,
                                set    = function(_, v) SetFontOutline("cast", v) end,
                            },
                            castFontShadow = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 24,
                                get   = function() return GetFontShadow("cast") end,
                                set   = function(_, v) SetFontShadow("cast", v) end,
                            },
                            sep_test = { type = "header", name = "Testing", order = 30 },
                            castTestMode = {
                                type  = "execute",
                                order = 31,
                                name  = function()
                                    return Options:IsInCastTestMode() and "Stop Cast Preview" or "Cast Bar Preview"
                                end,
                                desc  = "Play fake cast bars on all visible nameplates.",
                                func  = function() Options:ToggleCastTestMode() end,
                            },
                        },
                    },

                    -- ── Power Bar tab ────────────────────────────────────────────────
                    powerBar = {
                        type  = "group",
                        name  = "Power Bar",
                        order = 6,
                        args  = {
                            showPowerBar = {
                                type  = "toggle",
                                name  = "Show Power Bar",
                                order = 1,
                                width = "full",
                                desc  = "Display a thin resource bar (mana, energy, rage, etc.) below the health bar.",
                                get   = function() return Options:GetShowPowerBar() end,
                                set   = function(_, v) Options:SetShowPowerBar(_, v) end,
                            },
                            powerBarHeight = {
                                type   = "range",
                                name   = "Bar Height",
                                order  = 2,
                                min    = 2,
                                max    = 14,
                                step   = 1,
                                hidden = function() return not Options:GetShowPowerBar() end,
                                get    = function() return Options:GetPowerBarHeight() end,
                                set    = function(_, v) Options:SetPowerBarHeight(_, v) end,
                            },
                            powerBarGap = {
                                type   = "range",
                                name   = "Gap from Health Bar",
                                order  = 3,
                                min    = 0,
                                max    = 12,
                                step   = 1,
                                hidden = function() return not Options:GetShowPowerBar() end,
                                get    = function() return Options:GetPowerBarGap() end,
                                set    = function(_, v) Options:SetPowerBarGap(_, v) end,
                            },
                            powerBgColor = {
                                type     = "color",
                                name     = "Background Color",
                                order    = 4,
                                hasAlpha = true,
                                hidden   = function() return not Options:GetShowPowerBar() end,
                                get      = function() return Options:GetPowerBgColor() end,
                                set      = function(_, r, g, b, a) Options:SetPowerBgColor(_, r, g, b, a) end,
                            },
                            powerBorderColor = {
                                type     = "color",
                                name     = "Border Color",
                                order    = 5,
                                hasAlpha = true,
                                hidden   = function() return not Options:GetShowPowerBar() end,
                                get      = function() return Options:GetPowerBorderColor() end,
                                set      = function(_, r, g, b, a) Options:SetPowerBorderColor(_, r, g, b, a) end,
                            },
                        },
                    },

                    -- ── Auras tab ────────────────────────────────────────────────────
                    auras = {
                        type  = "group",
                        name  = "Auras",
                        order = 7,
                        args  = {
                            showAuras = {
                                type = "toggle",
                                name = "Show Auras",
                                order = 1,
                                width = "full",
                                get = function() return Options:GetShowAuras() end,
                                set = function(_, v) Options:SetShowAuras(_, v) end,
                            },
                            auraFilter = {
                                type   = "select",
                                name   = "Aura Filter",
                                order  = 2,
                                values = AURA_FILTER_VALUES,
                                hidden = function() return not Options:GetShowAuras() end,
                                get    = function() return Options:GetAuraFilter() end,
                                set    = function(_, v) Options:SetAuraFilter(_, v) end,
                            },
                            auraOnlyMine = {
                                type   = "toggle",
                                name   = "Show Only Mine",
                                order  = 3,
                                desc   = "Only display auras applied by you.",
                                hidden = function() return not Options:GetShowAuras() end,
                                get    = function() return Options:GetAuraOnlyMine() end,
                                set    = function(_, v) Options:SetAuraOnlyMine(_, v) end,
                            },
                            auraMax = {
                                type   = "range",
                                name   = "Max Auras",
                                order  = 4,
                                min    = 1,
                                max    = 10,
                                step   = 1,
                                hidden = function() return not Options:GetShowAuras() end,
                                get    = function() return Options:GetAuraMax() end,
                                set    = function(_, v) Options:SetAuraMax(_, v) end,
                            },
                            auraSize = {
                                type   = "range",
                                name   = "Icon Size",
                                order  = 5,
                                min    = 12,
                                max    = 40,
                                step   = 1,
                                hidden = function() return not Options:GetShowAuras() end,
                                get    = function() return Options:GetAuraSize() end,
                                set    = function(_, v) Options:SetAuraSize(_, v) end,
                            },
                            auraShowTimer = {
                                type   = "toggle",
                                name   = "Show Timer Text",
                                order  = 6,
                                hidden = function() return not Options:GetShowAuras() end,
                                get    = function() return Options:GetAuraShowTimer() end,
                                set    = function(_, v) Options:SetAuraShowTimer(_, v) end,
                            },
                            auraTimerFontSize = {
                                type = "range",
                                name = "Timer Font Size",
                                order = 7,
                                min = 6,
                                max = 28,
                                step = 1,
                                hidden = function()
                                    return not Options:GetShowAuras() or not Options:GetAuraShowTimer()
                                end,
                                get = function() return Options:GetAuraTimerFontSize() end,
                                set = function(_, v) Options:SetAuraTimerFontSize(_, v) end,
                            },
                            auraTestMode = {
                                type   = "toggle",
                                name   = "Show in Preview Mode",
                                order  = 8,
                                desc   = "Display fake aura icons when preview / test mode is active.",
                                hidden = function() return not Options:GetShowAuras() end,
                                get    = function() return Options:GetAuraTestMode() end,
                                set    = function(_, v) Options:SetAuraTestMode(_, v) end,
                            },
                        },
                    },

                    -- ── Target tab ───────────────────────────────────────────────────
                    target = {
                        type  = "group",
                        name  = "Target",
                        order = 8,
                        args  = {
                            showTargetGlow = {
                                type  = "toggle",
                                name  = "Target / Focus Glow",
                                order = 1,
                                width = "full",
                                desc  = "Highlight target and focus with a colored glow.",
                                get   = function() return Options:GetShowTargetGlow() end,
                                set   = function(_, v) Options:SetShowTargetGlow(_, v) end,
                            },
                            targetGlowOutset = {
                                type = "range",
                                name = "Glow Outset",
                                order = 2,
                                min = 1,
                                max = 10,
                                step = 1,
                                hidden = function() return not Options:GetShowTargetGlow() end,
                                get = function() return Options:GetTargetGlowOutset() end,
                                set = function(_, v) Options:SetTargetGlowOutset(_, v) end,
                            },
                            targetGlowColor = {
                                type     = "color",
                                name     = "Target Glow Color",
                                order    = 3,
                                hasAlpha = true,
                                hidden   = function() return not Options:GetShowTargetGlow() end,
                                get      = function() return Options:GetTargetGlowColor() end,
                                set      = function(_, r, g, b, a) Options:SetTargetGlowColor(_, r, g, b, a) end,
                            },
                            focusGlowColor = {
                                type     = "color",
                                name     = "Focus Glow Color",
                                order    = 4,
                                hasAlpha = true,
                                hidden   = function() return not Options:GetShowTargetGlow() end,
                                get      = function() return Options:GetFocusGlowColor() end,
                                set      = function(_, r, g, b, a) Options:SetFocusGlowColor(_, r, g, b, a) end,
                            },
                            sepGrow = { type = "header", name = "Target Scale", order = 10 },
                            targetGrowWidth = {
                                type = "range",
                                name = "Width Multiplier",
                                order = 11,
                                desc = "Multiply the bar width when it is your current target. 1 = no change.",
                                min = 0.5,
                                max = 2.0,
                                step = 0.05,
                                get = function() return Options:GetTargetGrowWidth() end,
                                set = function(_, v) Options:SetTargetGrowWidth(_, v) end,
                            },
                            targetGrowHeight = {
                                type = "range",
                                name = "Height Multiplier",
                                order = 12,
                                min = 0.5,
                                max = 2.0,
                                step = 0.05,
                                get = function() return Options:GetTargetGrowHeight() end,
                                set = function(_, v) Options:SetTargetGrowHeight(_, v) end,
                            },
                            sepArrows = { type = "header", name = "Target Arrows", order = 20 },
                            showTargetArrows = {
                                type = "toggle",
                                name = "Show Target Arrows",
                                order = 21,
                                get = function() return Options:GetShowTargetArrows() end,
                                set = function(_, v) Options:SetShowTargetArrows(_, v) end,
                            },
                            -- "Browse" button opens the arrow picker popup gallery
                            targetArrowPicker = {
                                type   = "execute",
                                name   = "Browse Arrow Styles...",
                                desc   = "Open a visual gallery of all arrow styles.",
                                order  = 22,
                                hidden = function() return not Options:GetShowTargetArrows() end,
                                func   = function() OpenArrowPicker() end,
                                width  = "normal",
                            },
                            -- Current selection preview (shows the arrow upright — no coord gymnastics)
                            targetArrowPreview = {
                                type        = "description",
                                name        = function()
                                    return "Current: " .. Options:GetTargetArrowStyle()
                                end,
                                order       = 22.5,
                                hidden      = function() return not Options:GetShowTargetArrows() end,
                                image       = function() return Options:GetTargetArrowPreviewTex() end,
                                imageWidth  = 64,
                                imageHeight = 64,
                                width       = "full",
                            },
                            targetArrowSize = {
                                type   = "range",
                                name   = "Arrow Size",
                                order  = 24,
                                min    = 8,
                                max    = 32,
                                step   = 1,
                                hidden = function() return not Options:GetShowTargetArrows() end,
                                get    = function() return Options:GetTargetArrowSize() end,
                                set    = function(_, v) Options:SetTargetArrowSize(_, v) end,
                            },
                            targetArrowColor = {
                                type     = "color",
                                name     = "Arrow Color",
                                order    = 25,
                                hasAlpha = false,
                                desc     = "Color of the target arrows. Defaults to the target glow color if not set.",
                                hidden   = function() return not Options:GetShowTargetArrows() end,
                                get      = function() return Options:GetTargetArrowColor() end,
                                set      = function(_, r, g, b, a) Options:SetTargetArrowColor(_, r, g, b, a) end,
                            },
                        },
                    },

                    -- ── Indicators tab ───────────────────────────────────────────────
                    indicators = {
                        type  = "group",
                        name  = "Indicators",
                        order = 9,
                        args  = {
                            showThreat = {
                                type  = "toggle",
                                name  = "Threat Accent",
                                order = 1,
                                desc  = "Color the left edge of enemy plates based on threat level.",
                                get   = function() return Options:GetShowThreat() end,
                                set   = function(_, v) Options:SetShowThreat(_, v) end,
                            },
                            sepRaidMarker = { type = "header", name = "Raid Marker", order = 5 },
                            showRaidMarker = {
                                type  = "toggle",
                                name  = "Show Raid Marker",
                                order = 6,
                                width = "full",
                                desc  = "Display the unit's raid target icon on the nameplate.",
                                get   = function() return Options:GetShowRaidMarker() end,
                                set   = function(_, v) Options:SetShowRaidMarker(_, v) end,
                            },
                            raidMarkerPoint = {
                                type   = "select",
                                name   = "Anchor Point",
                                order  = 7,
                                values = RAID_MARKER_POINTS,
                                hidden = function() return not Options:GetShowRaidMarker() end,
                                get    = function() return Options:GetRaidMarkerPoint() end,
                                set    = function(_, v) Options:SetRaidMarkerPoint(_, v) end,
                            },
                            raidMarkerOffsetX = {
                                type   = "range",
                                name   = "Offset X",
                                order  = 8,
                                min    = -80,
                                max    = 80,
                                step   = 1,
                                hidden = function() return not Options:GetShowRaidMarker() end,
                                get    = function() return Options:GetRaidMarkerOffsetX() end,
                                set    = function(_, v) Options:SetRaidMarkerOffsetX(_, v) end,
                            },
                            raidMarkerOffsetY = {
                                type   = "range",
                                name   = "Offset Y",
                                order  = 9,
                                min    = -80,
                                max    = 80,
                                step   = 1,
                                hidden = function() return not Options:GetShowRaidMarker() end,
                                get    = function() return Options:GetRaidMarkerOffsetY() end,
                                set    = function(_, v) Options:SetRaidMarkerOffsetY(_, v) end,
                            },
                            raidMarkerScale = {
                                type   = "range",
                                name   = "Scale",
                                order  = 10,
                                min    = 0.5,
                                max    = 3,
                                step   = 0.05,
                                hidden = function() return not Options:GetShowRaidMarker() end,
                                get    = function() return Options:GetRaidMarkerScale() end,
                                set    = function(_, v) Options:SetRaidMarkerScale(_, v) end,
                            },
                            sepAggro = { type = "header", name = "Aggro Bar Color", order = 20 },
                            showAggroColor = {
                                type  = "toggle",
                                name  = "Enable Aggro Color",
                                order = 21,
                                width = "full",
                                desc  =
                                "Override the health bar color when you have aggro on an enemy. Uses a different color depending on whether you are tanking or not.",
                                get   = function() return Options:GetShowAggroColor() end,
                                set   = function(_, v) Options:SetShowAggroColor(_, v) end,
                            },
                            aggroColorTank = {
                                type     = "color",
                                name     = "Tank Aggro Color",
                                order    = 22,
                                hasAlpha = false,
                                desc     =
                                "Health bar color when you have aggro and your role is Tank. Aggro is good — default green.",
                                hidden   = function() return not Options:GetShowAggroColor() end,
                                get      = function() return Options:GetAggroColorTank() end,
                                set      = function(_, r, g, b, a) Options:SetAggroColorTank(_, r, g, b, a) end,
                            },
                            aggroColorDps = {
                                type     = "color",
                                name     = "DPS / Healer Aggro Color",
                                order    = 23,
                                hasAlpha = false,
                                desc     =
                                "Health bar color when you have aggro and your role is DPS or Healer. Aggro is bad — default orange.",
                                hidden   = function() return not Options:GetShowAggroColor() end,
                                get      = function() return Options:GetAggroColorDps() end,
                                set      = function(_, r, g, b, a) Options:SetAggroColorDps(_, r, g, b, a) end,
                            },
                        },
                    },
                },
            },

            -- ── Friendly Nameplates tab ──────────────────────────────────────
            -- All settings here override the corresponding enemy settings only
            -- for friendly units (party, raid, friendly NPCs, etc.).
            -- Keys not explicitly set inherit the enemy value via __index fallback.
            friendly = {
                type        = "group",
                name        = "Friendly",
                order       = 10,
                childGroups = "tab",
                args        = {

                    -- ── Layout ────────────────────────────────────────────────
                    layout = {
                        type  = "group",
                        name  = "Layout",
                        order = 1,
                        args  = {
                            intro = {
                                type  = "description",
                                name  =
                                "Settings here apply only to friendly nameplates (party, raid, friendly NPCs). Any value not changed here inherits from the enemy configuration.",
                                order = 0,
                                width = "full",
                            },
                            sep_layout = { type = "header", name = "Dimensions", order = 5 },
                            width = {
                                type = "range",
                                name = "Bar Width",
                                order = 6,
                                min = 60,
                                max = 500,
                                step = 5,
                                bigStep = 10,
                                get = function() return Options:GetFriendlyDB().width or Options:GetWidth() end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().width = math.max(60,
                                        math.min(500, math.floor(tonumber(v) or 220)))
                                    Refresh()
                                end,
                            },
                            height = {
                                type = "range",
                                name = "Bar Height",
                                order = 7,
                                min = 8,
                                max = 60,
                                step = 1,
                                get = function() return Options:GetFriendlyDB().height or Options:GetHeight() end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().height = math.max(8,
                                        math.min(60, math.floor(tonumber(v) or 22)))
                                    Refresh()
                                end,
                            },
                            castHeight = {
                                type = "range",
                                name = "Cast Bar Height",
                                order = 8,
                                min = 6,
                                max = 30,
                                step = 1,
                                get = function() return Options:GetFriendlyDB().castHeight or Options:GetCastHeight() end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().castHeight = math.max(6,
                                        math.min(30, math.floor(tonumber(v) or 12)))
                                    Refresh()
                                end,
                            },
                            sep_vis = { type = "header", name = "Visibility", order = 15 },
                            alpha = {
                                type = "range",
                                name = "Alpha",
                                order = 16,
                                min = 0.05,
                                max = 1.0,
                                step = 0.05,
                                get = function() return Options:GetFriendlyDB().alpha or Options:GetAlpha() end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().alpha = math.max(0.05, math.min(1, tonumber(v) or 1))
                                    Refresh()
                                end,
                            },
                            scale = {
                                type = "range",
                                name = "Scale",
                                order = 17,
                                min = 0.5,
                                max = 2.0,
                                step = 0.05,
                                get = function() return Options:GetFriendlyDB().scale or Options:GetScale() end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().scale = math.max(0.5, math.min(2, tonumber(v) or 1))
                                    Refresh()
                                end,
                            },
                            maxDistance = {
                                type = "range",
                                name = "Visibility Distance",
                                desc = "Maximum range at which friendly nameplates appear (yards).",
                                order = 18,
                                min = 20,
                                max = 100,
                                step = 5,
                                get = function()
                                    return Options:GetFriendlyDB().nameplateMaxDistance or
                                        Options:GetMaxDistance()
                                end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().nameplateMaxDistance = math.max(20,
                                        math.min(100, math.floor(tonumber(v) or 60)))
                                    Refresh()
                                end,
                            },
                            sep_positioning = { type = "header", name = "Stacking", order = 30 },
                            positioningHelp = {
                                type = "description",
                                name =
                                "Friendly plates can use their own stacking toggle and stacking footprint on Midnight. Height is the main control for preventing cast bars from colliding in crowded groups.",
                                order = 31,
                                width = "full",
                            },
                            stackNameplates = {
                                type = "toggle",
                                name = "Stack Friendly Plates",
                                desc = "Use stacked placement for friendly nameplates instead of allowing overlap.",
                                order = 32,
                                width = "full",
                                hidden = function() return not Options:SupportsPerTypeStacking() end,
                                get = function() return Options:GetFriendlyStackingEnabled() end,
                                set = function(_, v) Options:SetFriendlyStackingEnabled(_, v) end,
                            },
                            stackingWidthScale = {
                                type = "range",
                                name = "Friendly Stack Width",
                                desc =
                                "Scale the horizontal footprint Blizzard uses when spacing stacked friendly plates.",
                                order = 33,
                                min = 0.75,
                                max = 3,
                                step = 0.05,
                                bigStep = 0.1,
                                get = function() return Options:GetFriendlyStackingWidthScale() end,
                                set = function(_, v) Options:SetFriendlyStackingWidthScale(_, v) end,
                            },
                            stackingHeightScale = {
                                type = "range",
                                name = "Friendly Stack Height",
                                desc =
                                "Scale the downward stacking footprint for friendly plates so cast and power bars stay readable.",
                                order = 34,
                                min = 0.75,
                                max = 4,
                                step = 0.05,
                                bigStep = 0.1,
                                get = function() return Options:GetFriendlyStackingHeightScale() end,
                                set = function(_, v) Options:SetFriendlyStackingHeightScale(_, v) end,
                            },
                        },
                    },

                    -- ── Colors ────────────────────────────────────────────────
                    colors = {
                        type  = "group",
                        name  = "Colors",
                        order = 2,
                        args  = {
                            healthColorMode = {
                                type   = "select",
                                name   = "Health Color Mode",
                                order  = 1,
                                values = HEALTH_COLOR_MODES,
                                get    = function()
                                    return Options:GetFriendlyDB().healthColorMode or
                                        Options:GetHealthColorMode()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().healthColorMode = v; Refresh()
                                end,
                            },
                            healthCustomColor = {
                                type     = "color",
                                name     = "Custom Health Color",
                                order    = 2,
                                hasAlpha = false,
                                hidden   = function()
                                    return (Options:GetFriendlyDB().healthColorMode or Options:GetHealthColorMode()) ~=
                                        "custom"
                                end,
                                get      = function()
                                    local c = Options:GetFriendlyDB().healthCustomColor or { 0.28, 0.88, 0.42, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().healthCustomColor = { r, g, b, a or 1 }; Refresh()
                                end,
                            },
                            sepRC = { type = "header", name = "Reaction Colors", order = 10 },
                            colorFriendly = {
                                type     = "color",
                                name     = "Friendly",
                                order    = 11,
                                hasAlpha = false,
                                get      = function()
                                    local c = Options:GetFriendlyDB().colorFriendly or { 0.28, 0.88, 0.42, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().colorFriendly = { r, g, b, a or 1 }; Refresh()
                                end,
                            },
                        },
                    },

                    -- ── Health ────────────────────────────────────────────────
                    health = {
                        type  = "group",
                        name  = "Health",
                        order = 3,
                        args  = {
                            sep_display = { type = "header", name = "Display", order = 1 },
                            healthFormat = {
                                type   = "select",
                                name   = "Health Text Format",
                                order  = 2,
                                values = HEALTH_FORMAT_VALUES,
                                get    = function()
                                    return Options:GetFriendlyDB().healthFormat or
                                        Options:GetHealthFormat()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().healthFormat = v; Refresh()
                                end,
                            },
                            showAbsorb = {
                                type  = "toggle",
                                name  = "Show Absorb Overlay",
                                order = 3,
                                get   = function()
                                    local v = Options:GetFriendlyDB().showAbsorb
                                    if v ~= nil then return v end
                                    return Options:GetShowAbsorb()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showAbsorb = v == true; Refresh()
                                end,
                            },
                            sep_tex = { type = "header", name = "Health Bar", order = 10 },
                            healthBarTexture = {
                                type   = "select",
                                name   = "Bar Texture",
                                order  = 11,
                                values = TextureList,
                                get    = function() return Options:GetFriendlyDB().healthBarTexture or "__default" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().healthBarTexture = (v == "__default") and nil or v; Refresh()
                                end,
                            },
                            healthBgColor = {
                                type     = "color",
                                name     = "Background Color",
                                order    = 12,
                                hasAlpha = true,
                                get      = function()
                                    local c = Options:GetFriendlyDB().healthBgColor or { 0.05, 0.06, 0.08, 0.92 }
                                    return c[1], c[2], c[3], c[4] or 0.92
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().healthBgColor = { r, g, b, a or 0.92 }; Refresh()
                                end,
                            },
                            healthBorderColor = {
                                type     = "color",
                                name     = "Border Color",
                                order    = 13,
                                hasAlpha = true,
                                get      = function()
                                    local c = Options:GetFriendlyDB().healthBorderColor or { 0.14, 0.15, 0.20, 0.90 }
                                    return c[1], c[2], c[3], c[4] or 0.9
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().healthBorderColor = { r, g, b, a or 0.9 }; Refresh()
                                end,
                            },
                            sep_font = { type = "header", name = "Health Text Font", order = 20 },
                            healthFontFace = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 21,
                                values = FontList,
                                get    = function() return Options:GetFriendlyDB().healthFont or "__default" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().healthFont = (v == "__default") and nil or v; Refresh()
                                end,
                            },
                            healthFontSize = {
                                type = "range",
                                name = "Font Size",
                                order = 22,
                                min = 6,
                                max = 18,
                                step = 1,
                                get = function()
                                    return Options:GetFriendlyDB().healthFontSize or
                                        Options:GetHealthFontSize()
                                end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().healthFontSize = math.max(6,
                                        math.min(18, math.floor(tonumber(v) or 9)))
                                    Refresh()
                                end,
                            },
                            healthFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 23,
                                values = OUTLINE_VALUES,
                                get    = function() return Options:GetFriendlyDB().healthFontOutline or "OUTLINE" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().healthFontOutline = v; Refresh()
                                end,
                            },
                            healthFontShadow = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 24,
                                get   = function() return Options:GetFriendlyDB().healthFontShadow == true end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().healthFontShadow = v == true; Refresh()
                                end,
                            },
                            healthTextAnchor = {
                                type   = "select",
                                name   = "Text Align",
                                order  = 25,
                                values = ANCHOR_TEXTS,
                                get    = function() return Options:GetFriendlyDB().healthTextAnchor or "RIGHT" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().healthTextAnchor = v; Refresh()
                                end,
                            },
                        },
                    },

                    -- ── Name & Level ─────────────────────────────────────────
                    nameLevel = {
                        type  = "group",
                        name  = "Name & Level",
                        order = 4,
                        args  = {
                            showName = {
                                type  = "toggle",
                                name  = "Show Name",
                                order = 1,
                                get   = function()
                                    local v = Options:GetFriendlyDB().showName
                                    if v ~= nil then return v end
                                    return Options:GetShowName()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showName = v == true; Refresh()
                                end,
                            },
                            nameFormat = {
                                type   = "select",
                                name   = "Name Format",
                                order  = 2,
                                values = NAME_FORMAT_VALUES,
                                get    = function() return Options:GetFriendlyDB().nameFormat or Options:GetNameFormat() end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().nameFormat = v; Refresh()
                                end,
                            },
                            showLevel = {
                                type  = "toggle",
                                name  = "Show Level",
                                order = 3,
                                get   = function()
                                    local v = Options:GetFriendlyDB().showLevel
                                    if v ~= nil then return v end
                                    return Options:GetShowLevel()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showLevel = v == true; Refresh()
                                end,
                            },
                            showEliteIcon = {
                                type  = "toggle",
                                name  = "Show Elite/Boss Icon",
                                order = 4,
                                get   = function()
                                    local v = Options:GetFriendlyDB().showEliteIcon
                                    if v ~= nil then return v end
                                    return Options:GetShowEliteIcon()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showEliteIcon = v == true; Refresh()
                                end,
                            },
                            nameColorClass = {
                                type  = "toggle",
                                name  = "Color Name by Class",
                                order = 5,
                                desc  = "Color the name text with the unit's class color (players only).",
                                get   = function()
                                    local v = Options:GetFriendlyDB().nameColorClass
                                    if v ~= nil then return v end
                                    return Options:GetDB().nameColorClass == true
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().nameColorClass = v == true; Refresh()
                                end,
                            },
                            sep_font = { type = "header", name = "Name Text Font", order = 10 },
                            nameFontFace = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 11,
                                values = FontList,
                                get    = function() return Options:GetFriendlyDB().nameFont or "__default" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().nameFont = (v == "__default") and nil or v; Refresh()
                                end,
                            },
                            nameFontSize = {
                                type = "range",
                                name = "Font Size",
                                order = 12,
                                min = 6,
                                max = 20,
                                step = 1,
                                get = function() return Options:GetFriendlyDB().nameFontSize or Options:GetNameFontSize() end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().nameFontSize = math.max(6,
                                        math.min(20, math.floor(tonumber(v) or 10)))
                                    Refresh()
                                end,
                            },
                            nameFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 13,
                                values = OUTLINE_VALUES,
                                get    = function() return Options:GetFriendlyDB().nameFontOutline or "OUTLINE" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().nameFontOutline = v; Refresh()
                                end,
                            },
                            nameFontShadow = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 14,
                                get   = function() return Options:GetFriendlyDB().nameFontShadow == true end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().nameFontShadow = v == true; Refresh()
                                end,
                            },
                            sep_pos = { type = "header", name = "Name Position", order = 20 },
                            nameAnchorPoint = {
                                type   = "select",
                                name   = "Text Anchor",
                                order  = 21,
                                values = NAME_ANCHOR_POINTS,
                                get    = function() return NormalizeNameAnchor(Options:GetFriendlyDB().nameAnchorPoint) end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().nameAnchorPoint = v; Refresh()
                                end,
                            },
                            nameJustify = {
                                type   = "select",
                                name   = "Justify",
                                order  = 22,
                                values = ANCHOR_HALIGN,
                                get    = function() return Options:GetFriendlyDB().nameJustify or "LEFT" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().nameJustify = v; Refresh()
                                end,
                            },
                            nameOffsetX = {
                                type = "range",
                                name = "Offset X",
                                order = 23,
                                min = -20,
                                max = 20,
                                step = 1,
                                get = function() return Options:GetFriendlyDB().nameOffsetX or 2 end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().nameOffsetX = v; Refresh()
                                end,
                            },
                            nameOffsetY = {
                                type = "range",
                                name = "Offset Y",
                                order = 24,
                                min = -20,
                                max = 20,
                                step = 1,
                                get = function() return Options:GetFriendlyDB().nameOffsetY or 3 end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().nameOffsetY = v; Refresh()
                                end,
                            },
                            nameWidth = {
                                type = "range",
                                name = "Text Width",
                                desc = "0 uses the automatic anchor width.",
                                order = 25,
                                min = 0,
                                max = 600,
                                step = 1,
                                get = function() return Options:GetFriendlyDB().nameWidth or 0 end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().nameWidth = (v and v > 0) and math.floor(v) or nil; Refresh()
                                end,
                            },
                        },
                    },

                    -- ── Cast Bar ─────────────────────────────────────────────
                    castbar = {
                        type  = "group",
                        name  = "Cast Bar",
                        order = 5,
                        args  = {
                            showCastBar = {
                                type  = "toggle",
                                name  = "Show Cast Bar",
                                order = 1,
                                width = "full",
                                desc  =
                                "Show cast bars on friendly nameplates. Disable to hide cast bars only on friendlies.",
                                get   = function()
                                    local v = Options:GetFriendlyDB().showCastBar
                                    if v ~= nil then return v end
                                    return Options:GetShowCastBar()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showCastBar = v == true; Refresh()
                                end,
                            },
                            castColor = {
                                type     = "color",
                                name     = "Cast Bar Color",
                                order    = 2,
                                hasAlpha = false,
                                get      = function()
                                    local c = Options:GetFriendlyDB().castColor or { 0.96, 0.76, 0.24, 1 }
                                    return c[1], c[2], c[3], c[4] or 1
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().castColor = { r, g, b, a or 1 }; Refresh()
                                end,
                            },
                            sep_tex = { type = "header", name = "Cast Bar Appearance", order = 10 },
                            castBarTexture = {
                                type   = "select",
                                name   = "Bar Texture",
                                order  = 11,
                                values = TextureList,
                                get    = function() return Options:GetFriendlyDB().castBarTexture or "__default" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().castBarTexture = (v == "__default") and nil or v; Refresh()
                                end,
                            },
                            castBgColor = {
                                type     = "color",
                                name     = "Background Color",
                                order    = 12,
                                hasAlpha = true,
                                get      = function()
                                    local c = Options:GetFriendlyDB().castBgColor or { 0.05, 0.06, 0.08, 0.92 }
                                    return c[1], c[2], c[3], c[4] or 0.92
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().castBgColor = { r, g, b, a or 0.92 }; Refresh()
                                end,
                            },
                            castBorderColor = {
                                type     = "color",
                                name     = "Border Color",
                                order    = 13,
                                hasAlpha = true,
                                get      = function()
                                    local c = Options:GetFriendlyDB().castBorderColor or { 0.14, 0.15, 0.20, 0.90 }
                                    return c[1], c[2], c[3], c[4] or 0.9
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().castBorderColor = { r, g, b, a or 0.9 }; Refresh()
                                end,
                            },
                            sep_font = { type = "header", name = "Cast Bar Font", order = 20 },
                            castFontFace = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 21,
                                values = FontList,
                                get    = function() return Options:GetFriendlyDB().castFont or "__default" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().castFont = (v == "__default") and nil or v; Refresh()
                                end,
                            },
                            castFontSize = {
                                type = "range",
                                name = "Font Size",
                                order = 22,
                                min = 6,
                                max = 16,
                                step = 1,
                                get = function() return Options:GetFriendlyDB().castFontSize or Options:GetCastFontSize() end,
                                set = function(_, v)
                                    Options:GetFriendlyDB().castFontSize = math.max(6,
                                        math.min(16, math.floor(tonumber(v) or 9)))
                                    Refresh()
                                end,
                            },
                            castFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 23,
                                values = OUTLINE_VALUES,
                                get    = function() return Options:GetFriendlyDB().castFontOutline or "OUTLINE" end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().castFontOutline = v; Refresh()
                                end,
                            },
                            castFontShadow = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 24,
                                get   = function() return Options:GetFriendlyDB().castFontShadow == true end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().castFontShadow = v == true; Refresh()
                                end,
                            },
                        },
                    },

                    -- ── Power Bar ────────────────────────────────────────────
                    powerBar = {
                        type  = "group",
                        name  = "Power Bar",
                        order = 6,
                        args  = {
                            showPowerBar = {
                                type  = "toggle",
                                name  = "Show Power Bar",
                                order = 1,
                                width = "full",
                                desc  =
                                "Show power bars on friendly nameplates. Disable to hide power bars only on friendlies.",
                                get   = function()
                                    local v = Options:GetFriendlyDB().showPowerBar
                                    if v ~= nil then return v end
                                    return Options:GetShowPowerBar()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showPowerBar = v == true; Refresh()
                                end,
                            },
                            powerBarHeight = {
                                type   = "range",
                                name   = "Bar Height",
                                order  = 2,
                                min    = 2,
                                max    = 14,
                                step   = 1,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showPowerBar
                                    if v ~= nil then return not v end
                                    return not Options:GetShowPowerBar()
                                end,
                                get    = function()
                                    return Options:GetFriendlyDB().powerBarHeight or
                                        Options:GetPowerBarHeight()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().powerBarHeight = math.max(2,
                                        math.min(14, math.floor(tonumber(v) or 4)))
                                    Refresh()
                                end,
                            },
                            powerBarGap = {
                                type   = "range",
                                name   = "Gap from Health Bar",
                                order  = 3,
                                min    = 0,
                                max    = 12,
                                step   = 1,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showPowerBar
                                    if v ~= nil then return not v end
                                    return not Options:GetShowPowerBar()
                                end,
                                get    = function()
                                    return Options:GetFriendlyDB().powerBarGap or
                                        Options:GetPowerBarGap()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().powerBarGap = math.max(0,
                                        math.min(12, math.floor(tonumber(v) or 2)))
                                    Refresh()
                                end,
                            },
                            powerBgColor = {
                                type     = "color",
                                name     = "Background Color",
                                order    = 4,
                                hasAlpha = true,
                                hidden   = function()
                                    local v = Options:GetFriendlyDB().showPowerBar
                                    if v ~= nil then return not v end
                                    return not Options:GetShowPowerBar()
                                end,
                                get      = function()
                                    local c = Options:GetFriendlyDB().powerBgColor or { 0.05, 0.06, 0.08, 0.92 }
                                    return c[1], c[2], c[3], c[4] or 0.92
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().powerBgColor = { r, g, b, a or 0.92 }; Refresh()
                                end,
                            },
                            powerBorderColor = {
                                type     = "color",
                                name     = "Border Color",
                                order    = 5,
                                hasAlpha = true,
                                hidden   = function()
                                    local v = Options:GetFriendlyDB().showPowerBar
                                    if v ~= nil then return not v end
                                    return not Options:GetShowPowerBar()
                                end,
                                get      = function()
                                    local c = Options:GetFriendlyDB().powerBorderColor or { 0.14, 0.15, 0.20, 0.90 }
                                    return c[1], c[2], c[3], c[4] or 0.9
                                end,
                                set      = function(_, r, g, b, a)
                                    Options:GetFriendlyDB().powerBorderColor = { r, g, b, a or 0.9 }; Refresh()
                                end,
                            },
                        },
                    },

                    -- ── Auras ─────────────────────────────────────────────────
                    auras = {
                        type  = "group",
                        name  = "Auras",
                        order = 7,
                        args  = {
                            showAuras = {
                                type  = "toggle",
                                name  = "Show Auras",
                                order = 1,
                                width = "full",
                                get   = function()
                                    local v = Options:GetFriendlyDB().showAuras
                                    if v ~= nil then return v end
                                    return Options:GetShowAuras()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showAuras = v == true; Refresh()
                                end,
                            },
                            auraFilter = {
                                type   = "select",
                                name   = "Aura Filter",
                                order  = 2,
                                values = AURA_FILTER_VALUES,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showAuras
                                    if v ~= nil then return not v end
                                    return not Options:GetShowAuras()
                                end,
                                get    = function() return Options:GetFriendlyDB().auraFilter or Options:GetAuraFilter() end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().auraFilter = v; Refresh()
                                end,
                            },
                            auraOnlyMine = {
                                type   = "toggle",
                                name   = "Show Only Mine",
                                order  = 3,
                                desc   = "Only display auras applied by you.",
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showAuras
                                    if v ~= nil then return not v end
                                    return not Options:GetShowAuras()
                                end,
                                get    = function() return Options:GetFriendlyDB().auraOnlyMine == true end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().auraOnlyMine = v == true; Refresh()
                                end,
                            },
                            auraMax = {
                                type   = "range",
                                name   = "Max Auras",
                                order  = 4,
                                min    = 1,
                                max    = 10,
                                step   = 1,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showAuras
                                    if v ~= nil then return not v end
                                    return not Options:GetShowAuras()
                                end,
                                get    = function() return Options:GetFriendlyDB().auraMax or Options:GetAuraMax() end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().auraMax = math.max(1,
                                        math.min(10, math.floor(tonumber(v) or 5)))
                                    Refresh()
                                end,
                            },
                            auraSize = {
                                type   = "range",
                                name   = "Icon Size",
                                order  = 5,
                                min    = 12,
                                max    = 40,
                                step   = 1,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showAuras
                                    if v ~= nil then return not v end
                                    return not Options:GetShowAuras()
                                end,
                                get    = function() return Options:GetFriendlyDB().auraSize or Options:GetAuraSize() end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().auraSize = math.max(12,
                                        math.min(40, math.floor(tonumber(v) or 20)))
                                    Refresh()
                                end,
                            },
                            auraShowTimer = {
                                type   = "toggle",
                                name   = "Show Timer Text",
                                order  = 6,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showAuras
                                    if v ~= nil then return not v end
                                    return not Options:GetShowAuras()
                                end,
                                get    = function()
                                    local v = Options:GetFriendlyDB().auraShowTimer
                                    if v ~= nil then return v end
                                    return Options:GetAuraShowTimer()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().auraShowTimer = v == true; Refresh()
                                end,
                            },
                        },
                    },

                    indicators = {
                        type  = "group",
                        name  = "Indicators",
                        order = 8,
                        args  = {
                            showRaidMarker = {
                                type  = "toggle",
                                name  = "Show Raid Marker",
                                order = 1,
                                width = "full",
                                desc  = "Display raid target markers on friendly nameplates.",
                                get   = function()
                                    local v = Options:GetFriendlyDB().showRaidMarker
                                    if v ~= nil then return v end
                                    return Options:GetShowRaidMarker()
                                end,
                                set   = function(_, v)
                                    Options:GetFriendlyDB().showRaidMarker = v == true; Refresh()
                                end,
                            },
                            raidMarkerPoint = {
                                type   = "select",
                                name   = "Anchor Point",
                                order  = 2,
                                values = RAID_MARKER_POINTS,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showRaidMarker
                                    if v ~= nil then return not v end
                                    return not Options:GetShowRaidMarker()
                                end,
                                get    = function()
                                    return Options:GetFriendlyDB().raidMarkerPoint or Options:GetRaidMarkerPoint()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().raidMarkerPoint = v; Refresh()
                                end,
                            },
                            raidMarkerOffsetX = {
                                type   = "range",
                                name   = "Offset X",
                                order  = 3,
                                min    = -80,
                                max    = 80,
                                step   = 1,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showRaidMarker
                                    if v ~= nil then return not v end
                                    return not Options:GetShowRaidMarker()
                                end,
                                get    = function()
                                    local v = Options:GetFriendlyDB().raidMarkerOffsetX
                                    if v ~= nil then return v end
                                    return Options:GetRaidMarkerOffsetX()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().raidMarkerOffsetX = v; Refresh()
                                end,
                            },
                            raidMarkerOffsetY = {
                                type   = "range",
                                name   = "Offset Y",
                                order  = 4,
                                min    = -80,
                                max    = 80,
                                step   = 1,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showRaidMarker
                                    if v ~= nil then return not v end
                                    return not Options:GetShowRaidMarker()
                                end,
                                get    = function()
                                    local v = Options:GetFriendlyDB().raidMarkerOffsetY
                                    if v ~= nil then return v end
                                    return Options:GetRaidMarkerOffsetY()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().raidMarkerOffsetY = v; Refresh()
                                end,
                            },
                            raidMarkerScale = {
                                type   = "range",
                                name   = "Scale",
                                order  = 5,
                                min    = 0.5,
                                max    = 3,
                                step   = 0.05,
                                hidden = function()
                                    local v = Options:GetFriendlyDB().showRaidMarker
                                    if v ~= nil then return not v end
                                    return not Options:GetShowRaidMarker()
                                end,
                                get    = function()
                                    local v = Options:GetFriendlyDB().raidMarkerScale
                                    if v ~= nil then return v end
                                    return Options:GetRaidMarkerScale()
                                end,
                                set    = function(_, v)
                                    Options:GetFriendlyDB().raidMarkerScale = v; Refresh()
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
end
