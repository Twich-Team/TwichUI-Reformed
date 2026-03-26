---@diagnostic disable: undefined-field
--[[
    Registers the Appearance / Theme section with the configuration system.
    The actual option definitions and section builder live in Options/ThemeOptions.lua
    so they're available before this file runs.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

-- The section builder is defined on ConfigurationModule.Options.Theme (ThemeOptions.lua).
-- Registration is also handled by ThemeModule:OnInitialize via RegisterConfigurationFunction,
-- but we register here as well to follow the same pattern as every other config section,
-- ensuring the tab appears even if ThemeModule hasn't initialized yet.
local function BuildThemeConfiguration()
    local Options = ConfigurationModule.Options.Theme
    if Options and type(Options.BuildConfiguration) == "function" then
        return Options:BuildConfiguration()
    end
end

ConfigurationModule:RegisterConfigurationFunction("Theme", BuildThemeConfiguration)
