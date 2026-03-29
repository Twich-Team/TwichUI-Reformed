---@diagnostic disable: undefined-field
--[[
	Registers the Unit Frames section with the configuration system.
	The actual option handlers and section builder live in Options/UnitFramesOptions.lua.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local function BuildUnitFramesConfiguration()
    local Options = ConfigurationModule.Options.UnitFrames
    if Options and type(Options.BuildConfiguration) == "function" then
        return Options:BuildConfiguration()
    end
end

ConfigurationModule:RegisterConfigurationFunction("unitFrames", BuildUnitFramesConfiguration)
