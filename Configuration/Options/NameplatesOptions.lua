---@diagnostic disable: undefined-field, inject-field
--[[
    NameplatesOptions.lua
    Option handlers and section builder for the Nameplates configuration panel.
]]
local TwichRx                          = _G.TwichRx
---@type TwichUI
local T                                = unpack(TwichRx)

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

local NAME_ANCHOR_POINTS = {
    BOTTOMLEFT  = "Bottom Left",
    BOTTOM      = "Bottom Center",
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
    self:GetDB().auraTimerFontSize = math.max(6, math.min(14, math.floor(tonumber(v) or 8))); Refresh()
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
                        desc  = "Prints live nameplate frame diagnostics to the chat window. Equivalent to /tui npdebug.",
                        order = 3,
                        func  = function()
                            local mod = T:GetModule("Nameplates", true)
                            if not mod then
                                T:Print("[NP] Module not loaded."); return
                            end
                            local db = mod.GetDB and mod:GetDB()
                            if db then
                                T:Print(string.format("[NP] healthFormat=%s  healthFontSize=%s  healthFont=%s",
                                    tostring(db.healthFormat), tostring(db.healthFontSize), tostring(db.healthFont)))
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

            -- ── Fonts tab ────────────────────────────────────────────────────
            fonts = {
                type  = "group",
                name  = "Fonts",
                order = 3,
                args  = {

                    nameGroup = {
                        type   = "group",
                        name   = "Name Text",
                        inline = true,
                        order  = 1,
                        args   = {
                            nameFontFace    = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 1,
                                values = FontList,
                                get    = function() return GetFontFace("name") end,
                                set    = function(_, v) SetFontFace("name", v) end,
                            },
                            nameFontSize    = {
                                type  = "range",
                                name  = "Font Size",
                                order = 2,
                                min   = 6,
                                max   = 20,
                                step  = 1,
                                get   = function() return Options:GetNameFontSize() end,
                                set   = function(_, v) Options:SetNameFontSize(_, v) end,
                            },
                            nameFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 3,
                                values = OUTLINE_VALUES,
                                get    = function() return GetFontOutline("name") end,
                                set    = function(_, v) SetFontOutline("name", v) end,
                            },
                            nameFontShadow  = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 4,
                                get   = function() return GetFontShadow("name") end,
                                set   = function(_, v) SetFontShadow("name", v) end,
                            },
                            nameFontColor   = {
                                type     = "color",
                                name     = "Color Override",
                                order    = 5,
                                hasAlpha = true,
                                get      = function() return GetFontColor("name") end,
                                set      = function(_, r, g, b, a) SetFontColor("name", r, g, b, a) end,
                            },
                            nameAnchorPoint = {
                                type   = "select",
                                name   = "Text Anchor",
                                order  = 6,
                                values = NAME_ANCHOR_POINTS,
                                get    = function() return Options:GetDB().nameAnchorPoint or "BOTTOMLEFT" end,
                                set    = function(_, v)
                                    Options:GetDB().nameAnchorPoint = v; Refresh()
                                end,
                            },
                            nameOffsetX     = {
                                type  = "range",
                                name  = "Offset X",
                                order = 7,
                                min   = -20,
                                max   = 20,
                                step  = 1,
                                get   = function() return Options:GetDB().nameOffsetX or 2 end,
                                set   = function(_, v)
                                    Options:GetDB().nameOffsetX = v; Refresh()
                                end,
                            },
                            nameOffsetY     = {
                                type  = "range",
                                name  = "Offset Y",
                                order = 8,
                                min   = -20,
                                max   = 20,
                                step  = 1,
                                get   = function() return Options:GetDB().nameOffsetY or 3 end,
                                set   = function(_, v)
                                    Options:GetDB().nameOffsetY = v; Refresh()
                                end,
                            },
                        },
                    },

                    healthGroup = {
                        type   = "group",
                        name   = "Health / Level Text",
                        inline = true,
                        order  = 2,
                        args   = {
                            healthFontFace    = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 1,
                                values = FontList,
                                get    = function() return GetFontFace("health") end,
                                set    = function(_, v) SetFontFace("health", v) end,
                            },
                            healthFontSize    = {
                                type  = "range",
                                name  = "Font Size",
                                order = 2,
                                min   = 6,
                                max   = 18,
                                step  = 1,
                                get   = function() return Options:GetHealthFontSize() end,
                                set   = function(_, v) Options:SetHealthFontSize(_, v) end,
                            },
                            healthFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 3,
                                values = OUTLINE_VALUES,
                                get    = function() return GetFontOutline("health") end,
                                set    = function(_, v) SetFontOutline("health", v) end,
                            },
                            healthFontShadow  = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 4,
                                get   = function() return GetFontShadow("health") end,
                                set   = function(_, v) SetFontShadow("health", v) end,
                            },
                            healthFontColor   = {
                                type     = "color",
                                name     = "Color Override",
                                order    = 5,
                                hasAlpha = true,
                                get      = function() return GetFontColor("health") end,
                                set      = function(_, r, g, b, a) SetFontColor("health", r, g, b, a) end,
                            },
                            healthTextAnchor  = {
                                type   = "select",
                                name   = "Health Text Anchor",
                                order  = 6,
                                values = ANCHOR_TEXTS,
                                get    = function() return Options:GetDB().healthTextAnchor or "RIGHT" end,
                                set    = function(_, v)
                                    Options:GetDB().healthTextAnchor = v; Refresh()
                                end,
                            },
                        },
                    },

                    castGroup = {
                        type   = "group",
                        name   = "Cast Bar Text",
                        inline = true,
                        order  = 3,
                        args   = {
                            castFontFace    = {
                                type   = "select",
                                name   = "Font Face",
                                order  = 1,
                                values = FontList,
                                get    = function() return GetFontFace("cast") end,
                                set    = function(_, v) SetFontFace("cast", v) end,
                            },
                            castFontSize    = {
                                type  = "range",
                                name  = "Font Size",
                                order = 2,
                                min   = 6,
                                max   = 16,
                                step  = 1,
                                get   = function() return Options:GetCastFontSize() end,
                                set   = function(_, v) Options:SetCastFontSize(_, v) end,
                            },
                            castFontOutline = {
                                type   = "select",
                                name   = "Outline",
                                order  = 3,
                                values = OUTLINE_VALUES,
                                get    = function() return GetFontOutline("cast") end,
                                set    = function(_, v) SetFontOutline("cast", v) end,
                            },
                            castFontShadow  = {
                                type  = "toggle",
                                name  = "Drop Shadow",
                                order = 4,
                                get   = function() return GetFontShadow("cast") end,
                                set   = function(_, v) SetFontShadow("cast", v) end,
                            },
                        },
                    },

                },
            },

            -- ── Textures tab ─────────────────────────────────────────────────
            textures = {
                type  = "group",
                name  = "Textures",
                order = 4,
                args  = {
                    sepHP = { type = "header", name = "Health Bar", order = 1 },
                    healthBarTexture = {
                        type = "select",
                        name = "Health Bar Texture",
                        order = 2,
                        values = TextureList,
                        get = function() return GetBarTexture("healthBarTexture") end,
                        set = function(_, v) SetBarTexture("healthBarTexture", v) end,
                    },
                    healthBgTexture = {
                        type = "select",
                        name = "Health BG Texture",
                        order = 3,
                        values = TextureList,
                        get = function() return GetBarTexture("healthBgTexture") end,
                        set = function(_, v) SetBarTexture("healthBgTexture", v) end,
                    },
                    healthBgColor = {
                        type = "color",
                        name = "Health BG Color",
                        order = 4,
                        hasAlpha = true,
                        get = function() return GetBarBgColor("healthBgColor") end,
                        set = function(_, r, g, b, a) SetBarBgColor("healthBgColor", r, g, b, a) end,
                    },
                    healthBorderColor = {
                        type = "color",
                        name = "Health Border Color",
                        order = 5,
                        hasAlpha = true,
                        get = function() return GetBarBorderColor("healthBorderColor") end,
                        set = function(_, r, g, b, a) SetBarBorderColor("healthBorderColor", r, g, b, a) end,
                    },
                    sepCast = { type = "header", name = "Cast Bar", order = 10 },
                    castBarTexture = {
                        type = "select",
                        name = "Cast Bar Texture",
                        order = 11,
                        values = TextureList,
                        get = function() return GetBarTexture("castBarTexture") end,
                        set = function(_, v) SetBarTexture("castBarTexture", v) end,
                    },
                    castBgColor = {
                        type = "color",
                        name = "Cast BG Color",
                        order = 12,
                        hasAlpha = true,
                        get = function() return GetBarBgColor("castBgColor") end,
                        set = function(_, r, g, b, a) SetBarBgColor("castBgColor", r, g, b, a) end,
                    },
                    castBorderColor = {
                        type = "color",
                        name = "Cast Border Color",
                        order = 13,
                        hasAlpha = true,
                        get = function() return GetBarBorderColor("castBorderColor") end,
                        set = function(_, r, g, b, a) SetBarBorderColor("castBorderColor", r, g, b, a) end,
                    },
                },
            },

            -- ── Health tab ───────────────────────────────────────────────────
            health = {
                type  = "group",
                name  = "Health",
                order = 5,
                args  = {
                    sep1 = { type = "header", name = "Display", order = 1 },
                    healthFormat = {
                        type = "select",
                        name = "Health Text Format",
                        order = 2,
                        values = HEALTH_FORMAT_VALUES,
                        get = function() return Options:GetHealthFormat() end,
                        set = function(_, v) Options:SetHealthFormat(_, v) end,
                    },
                    showAbsorb = {
                        type = "toggle",
                        name = "Show Absorb Overlay",
                        order = 3,
                        get = function() return Options:GetShowAbsorb() end,
                        set = function(_, v) Options:SetShowAbsorb(_, v) end,
                    },
                },
            },

            -- ── Name & Level tab ─────────────────────────────────────────────
            nameLevel = {
                type  = "group",
                name  = "Name & Level",
                order = 6,
                args  = {
                    showName = {
                        type = "toggle",
                        name = "Show Name",
                        order = 1,
                        get = function() return Options:GetShowName() end,
                        set = function(_, v) Options:SetShowName(_, v) end,
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
                        type = "toggle",
                        name = "Show Level",
                        order = 3,
                        get = function() return Options:GetShowLevel() end,
                        set = function(_, v) Options:SetShowLevel(_, v) end,
                    },
                    showEliteIcon = {
                        type = "toggle",
                        name = "Show Elite/Boss Icon",
                        order = 4,
                        get = function() return Options:GetShowEliteIcon() end,
                        set = function(_, v) Options:SetShowEliteIcon(_, v) end,
                    },
                },
            },

            -- ── Cast Bar tab ─────────────────────────────────────────────────
            castbar = {
                type  = "group",
                name  = "Cast Bar",
                order = 7,
                args  = {
                    showCastBar = {
                        type = "toggle",
                        name = "Show Cast Bar",
                        order = 1,
                        width = "full",
                        get = function() return Options:GetShowCastBar() end,
                        set = function(_, v) Options:SetShowCastBar(_, v) end,
                    },
                    castColor = {
                        type = "color",
                        name = "Cast Color",
                        order = 2,
                        hasAlpha = false,
                        get = function() return Options:GetCastColor() end,
                        set = function(_, r, g, b, a) Options:SetCastColor(_, r, g, b, a) end,
                    },
                    castTestMode = {
                        type = "execute",
                        order = 3,
                        name = function()
                            return Options:IsInCastTestMode() and "Stop Cast Preview" or "Cast Bar Preview"
                        end,
                        desc = "Play fake cast bars on all visible nameplates.",
                        func = function() Options:ToggleCastTestMode() end,
                    },
                },
            },

            -- ── Auras tab ────────────────────────────────────────────────────
            auras = {
                type  = "group",
                name  = "Auras",
                order = 8,
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
                        max = 14,
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
                order = 9,
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
                        type = "range",
                        name = "Arrow Size",
                        order = 24,
                        min = 8,
                        max = 32,
                        step = 1,
                        hidden = function() return not Options:GetShowTargetArrows() end,
                        get = function() return Options:GetTargetArrowSize() end,
                        set = function(_, v) Options:SetTargetArrowSize(_, v) end,
                    },
                },
            },

            -- ── Indicators tab ───────────────────────────────────────────────
            indicators = {
                type  = "group",
                name  = "Indicators",
                order = 10,
                args  = {
                    showThreat = {
                        type  = "toggle",
                        name  = "Threat Accent",
                        order = 1,
                        desc  = "Color the left edge of enemy plates based on threat level.",
                        get   = function() return Options:GetShowThreat() end,
                        set   = function(_, v) Options:SetShowThreat(_, v) end,
                    },
                    showAbsorb = {
                        type = "toggle",
                        name = "Show Absorb Overlay",
                        order = 2,
                        get = function() return Options:GetShowAbsorb() end,
                        set = function(_, v) Options:SetShowAbsorb(_, v) end,
                    },
                    showEliteIcon = {
                        type = "toggle",
                        name = "Show Elite/Boss Icon",
                        order = 3,
                        get = function() return Options:GetShowEliteIcon() end,
                        set = function(_, v) Options:SetShowEliteIcon(_, v) end,
                    },
                },
            },
        },
    }
end
