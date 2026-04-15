---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local function BuildObjectiveTrackerConfiguration()
    local options = ConfigurationModule.Options and ConfigurationModule.Options.ObjectiveTracker
    if options and type(options.BuildConfiguration) == "function" then
        return options:BuildConfiguration()
    end
end

ConfigurationModule:RegisterConfigurationFunction("Objective Tracker", BuildObjectiveTrackerConfiguration)
