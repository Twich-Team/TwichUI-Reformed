---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local function BuildActionBarsConfiguration()
    local options = ConfigurationModule.Options.ActionBars
    if options and type(options.BuildConfiguration) == "function" then
        return options:BuildConfiguration()
    end
end

ConfigurationModule:RegisterConfigurationFunction("Action Bars", BuildActionBarsConfiguration)