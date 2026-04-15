---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local function BuildMinimapConfiguration()
    local options = ConfigurationModule.Options and ConfigurationModule.Options.Minimap
    if options and type(options.BuildConfiguration) == "function" then
        return options:BuildConfiguration()
    end
end

ConfigurationModule:RegisterConfigurationFunction("Minimap", BuildMinimapConfiguration)
