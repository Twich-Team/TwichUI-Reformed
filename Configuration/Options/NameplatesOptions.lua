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

-- Test mode
function Options:IsInTestMode()
    local mod = GetModule()
    return mod and mod._testMode == true or false
end

function Options:ToggleTestMode()
    local mod = GetModule()
    if mod and type(mod.ToggleTestMode) == "function" then
        mod:ToggleTestMode()
    end
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
                            return Options:IsInTestMode() and "Exit Test Mode" or "Enter Test Mode"
                        end,
                        desc  = "Show preview nameplates to tune appearance without needing live targets.",
                        order = 2,
                        func  = function() Options:ToggleTestMode() end,
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

            -- ── Health tab ───────────────────────────────────────────────────
            health = {
                type  = "group",
                name  = "Health",
                order = 2,
                args  = {
                    healthColorMode = {
                        type   = "select",
                        name   = "Health Color",
                        order  = 1,
                        values = HEALTH_COLOR_MODES,
                        get    = function() return Options:GetHealthColorMode() end,
                        set    = function(_, v) Options:SetHealthColorMode(_, v) end,
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
                    sep1 = { type = "header", name = "Text", order = 10 },
                    healthFormat = {
                        type   = "select",
                        name   = "Health Text Format",
                        order  = 11,
                        values = HEALTH_FORMAT_VALUES,
                        get    = function() return Options:GetHealthFormat() end,
                        set    = function(_, v) Options:SetHealthFormat(_, v) end,
                    },
                    healthFontSize = {
                        type = "range",
                        name = "Health Font Size",
                        order = 12,
                        min = 6,
                        max = 18,
                        step = 1,
                        get = function() return Options:GetHealthFontSize() end,
                        set = function(_, v) Options:SetHealthFontSize(_, v) end,
                    },
                    sep2 = { type = "header", name = "Extras", order = 20 },
                    showAbsorb = {
                        type  = "toggle",
                        name  = "Show Absorb Overlay",
                        order = 21,
                        get   = function() return Options:GetShowAbsorb() end,
                        set   = function(_, v) Options:SetShowAbsorb(_, v) end,
                    },
                },
            },

            -- ── Name & Level tab ─────────────────────────────────────────────
            nameLevel = {
                type  = "group",
                name  = "Name & Level",
                order = 3,
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
                    nameFontSize = {
                        type = "range",
                        name = "Name Font Size",
                        order = 3,
                        min = 6,
                        max = 20,
                        step = 1,
                        hidden = function() return not Options:GetShowName() end,
                        get    = function() return Options:GetNameFontSize() end,
                        set    = function(_, v) Options:SetNameFontSize(_, v) end,
                    },
                    sep1 = { type = "header", name = "Level", order = 10 },
                    showLevel = {
                        type  = "toggle",
                        name  = "Show Level",
                        order = 11,
                        get   = function() return Options:GetShowLevel() end,
                        set   = function(_, v) Options:SetShowLevel(_, v) end,
                    },
                    showEliteIcon = {
                        type  = "toggle",
                        name  = "Show Elite / Boss Icon",
                        order = 12,
                        get   = function() return Options:GetShowEliteIcon() end,
                        set   = function(_, v) Options:SetShowEliteIcon(_, v) end,
                    },
                },
            },

            -- ── Cast Bar tab ─────────────────────────────────────────────────
            castbar = {
                type  = "group",
                name  = "Cast Bar",
                order = 4,
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
                        hidden   = function() return not Options:GetShowCastBar() end,
                        get      = function() return Options:GetCastColor() end,
                        set      = function(_, r, g, b, a) Options:SetCastColor(_, r, g, b, a) end,
                    },
                    castFontSize = {
                        type = "range",
                        name = "Cast Text Font Size",
                        order = 3,
                        min = 6,
                        max = 16,
                        step = 1,
                        hidden = function() return not Options:GetShowCastBar() end,
                        get    = function() return Options:GetCastFontSize() end,
                        set    = function(_, v) Options:SetCastFontSize(_, v) end,
                    },
                },
            },

            -- ── Auras tab ────────────────────────────────────────────────────
            auras = {
                type  = "group",
                name  = "Auras",
                order = 5,
                args  = {
                    showAuras = {
                        type  = "toggle",
                        name  = "Show Aura Icons",
                        order = 1,
                        width = "full",
                        get   = function() return Options:GetShowAuras() end,
                        set   = function(_, v) Options:SetShowAuras(_, v) end,
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
                    auraMax = {
                        type = "range",
                        name = "Max Icons",
                        order = 3,
                        min = 0,
                        max = 10,
                        step = 1,
                        hidden = function() return not Options:GetShowAuras() end,
                        get    = function() return Options:GetAuraMax() end,
                        set    = function(_, v) Options:SetAuraMax(_, v) end,
                    },
                    auraSize = {
                        type = "range",
                        name = "Icon Size",
                        order = 4,
                        min = 12,
                        max = 40,
                        step = 1,
                        hidden = function() return not Options:GetShowAuras() end,
                        get    = function() return Options:GetAuraSize() end,
                        set    = function(_, v) Options:SetAuraSize(_, v) end,
                    },
                },
            },

            -- ── Indicators tab ───────────────────────────────────────────────
            indicators = {
                type  = "group",
                name  = "Indicators",
                order = 6,
                args  = {
                    showTargetGlow = {
                        type  = "toggle",
                        name  = "Target / Focus Glow",
                        desc  = "Highlight your current target with a theme-colored glow.",
                        order = 1,
                        get   = function() return Options:GetShowTargetGlow() end,
                        set   = function(_, v) Options:SetShowTargetGlow(_, v) end,
                    },
                    showThreat = {
                        type  = "toggle",
                        name  = "Threat Accent",
                        desc  = "Color the left edge of enemy plates based on threat level.",
                        order = 2,
                        get   = function() return Options:GetShowThreat() end,
                        set   = function(_, v) Options:SetShowThreat(_, v) end,
                    },
                },
            },
        },
    }
end
