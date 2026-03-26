---@diagnostic disable: undefined-field
--[[
    TwichUI cross-module theme engine.

    Owns the addon-wide color palette, surface settings, and config UI sound profile.
    Any module can read from the theme via ThemeModule:Get(key) or ThemeModule:GetColor(key).
    When any theme value changes, the message "TWICH_THEME_CHANGED" is broadcast with the
    changed key so subscribed modules can re-apply their visuals without a reload.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local CopyTable = _G.CopyTable

---@class ThemeModule : AceModule, AceEvent-3.0
local ThemeModule = T:NewModule("Theme", "AceEvent-3.0")
ThemeModule:SetEnabledState(true)

-- ─── Default palette ───────────────────────────────────────────────────────

--- Every theme-aware property with its canonical default.
--- Modules should call ThemeModule:Get(key) / ThemeModule:GetColor(key) instead of reading
--- this table directly, so DB overrides are respected.
local DEFAULT_THEME = {
    -- Core palette
    primaryColor    = { 0.10, 0.72, 0.74 }, -- TwichUI Teal — chat chrome, primary borders
    accentColor     = { 0.96, 0.76, 0.24 }, -- Gold — panel accents, active indicators
    backgroundColor = { 0.05, 0.06, 0.08 }, -- Near-black surface
    borderColor     = { 0.24, 0.26, 0.32 }, -- Cool-grey border
    textColor       = { 1.00, 0.95, 0.85 }, -- Warm white labels
    successColor    = { 0.42, 0.89, 0.63 }, -- Green — enabled states
    warningColor    = { 0.96, 0.74, 0.22 }, -- Amber — cautionary callouts
    dangerColor     = { 0.90, 0.30, 0.32 }, -- Red — destructive / critical

    -- Surface alphas
    backgroundAlpha = 0.94,
    borderAlpha     = 0.85,

    -- Config UI sounds
    uiSoundsEnabled = true,
    soundProfile    = "Subtle", -- "None" | "Subtle" | "Standard"
}

-- Expose defaults so other modules can use them as typed fallbacks.
ThemeModule.DEFAULT_THEME = DEFAULT_THEME

-- ─── Lifecycle ─────────────────────────────────────────────────────────────

function ThemeModule:OnInitialize()
    local ConfigurationModule = T:GetModule("Configuration")
    ConfigurationModule:RegisterConfigurationFunction("Theme", function()
        local options = ConfigurationModule.Options.Theme
        if options and type(options.BuildConfiguration) == "function" then
            return options:BuildConfiguration()
        end
    end)
end

-- ─── DB access ─────────────────────────────────────────────────────────────

function ThemeModule:GetDB()
    local ConfigurationModule = T:GetModule("Configuration")
    local profile = ConfigurationModule:GetProfileDB()
    if type(profile.theme) ~= "table" then
        profile.theme = {}
    end
    return profile.theme
end

-- ─── Public API ────────────────────────────────────────────────────────────

--- Returns the resolved value for a theme key, falling back to the default.
--- For table values (colors) this returns a fresh copy each time.
function ThemeModule:Get(key)
    local db = self:GetDB()
    local val = db[key]
    if val ~= nil then
        if type(val) == "table" then
            return CopyTable(val)
        end
        return val
    end
    local default = DEFAULT_THEME[key]
    if type(default) == "table" then
        return CopyTable(default)
    end
    return default
end

--- Returns the resolved color for a theme key as a plain {r, g, b} table.
--- Always returns a safe table even if the key is unknown.
function ThemeModule:GetColor(key)
    local val = self:Get(key)
    if type(val) == "table" then
        return { val[1] or 1, val[2] or 1, val[3] or 1 }
    end
    local def = DEFAULT_THEME[key]
    if type(def) == "table" then
        return CopyTable(def)
    end
    return { 1, 1, 1 }
end

--- Persists a theme value and broadcasts TWICH_THEME_CHANGED.
--- Pass nil as value to reset to the built-in default.
function ThemeModule:Set(key, value)
    self:GetDB()[key] = value
    self:SendMessage("TWICH_THEME_CHANGED", key)
end

--- Convenience wrapper for setting a color key from r, g, b components.
function ThemeModule:SetColor(key, r, g, b)
    self:Set(key, { r, g, b })
end

--- Resets all theme values to defaults and broadcasts TWICH_THEME_CHANGED.
function ThemeModule:ResetToDefaults()
    local db = self:GetDB()
    for key in pairs(DEFAULT_THEME) do
        db[key] = nil
    end
    self:SendMessage("TWICH_THEME_CHANGED", nil)
end
