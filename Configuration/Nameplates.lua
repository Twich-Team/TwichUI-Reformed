--[[
    Registers the Nameplates section with the configuration system.
    The actual option handlers and section builder live in Options/NameplatesOptions.lua.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local function BuildNameplatesConfiguration()
    local Options = ConfigurationModule.Options.Nameplates
    if Options and type(Options.BuildConfiguration) == "function" then
        return Options:BuildConfiguration()
    end
end

ConfigurationModule:RegisterConfigurationFunction("nameplates", BuildNameplatesConfiguration)
