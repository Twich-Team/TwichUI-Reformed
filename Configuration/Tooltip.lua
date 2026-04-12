---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local function BuildTooltipConfiguration()
    local options = ConfigurationModule.Options --[[@as any]]
    options = options and options.Tooltip
    if options and type(options.BuildConfiguration) == "function" then
        return options:BuildConfiguration()
    end
end

ConfigurationModule:RegisterConfigurationFunction("Tooltip", BuildTooltipConfiguration)
