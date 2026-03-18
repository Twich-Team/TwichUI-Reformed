--[[
    TwichUI Redux Core
    This file contains the core of the TwichUI addon.
]]
local _G = _G
local AceAddon, AceAddonMinor = _G.LibStub('AceAddon-3.0')

local GetBuildInfo = GetBuildInfo
local GetAddOnMetadata = C_AddOns.GetAddOnMetadata


-- Initialize the addon
local AddOnName, Engine = ...

---@class TwichUI : AceAddon, AceConsole-3.0, AceEvent-3.0, AceTimer-3.0, AceHook-3.0
---@field Tools Tools
local T = AceAddon:NewAddon(AddOnName, 'AceConsole-3.0', 'AceEvent-3.0', 'AceTimer-3.0', 'AceHook-3.0')
T:SetDefaultModuleState(false)
T.privateVars = { profile = {} }
-- wow metadata
T.wowMetadata = T.wowMetadata or {}
T.wowMetadata.wowpatch, T.wowMetadata.wowbuild, T.wowMetadata.wowdate, T.wowMetadata.wowtoc = GetBuildInfo()
-- addon metadata
T.addonMetadata = T.addonMetadata or {}
T.addonMetadata.addonName = AddOnName

Engine[1] = T
Engine[2] = T.privateVars.profile
_G.TwichRx = Engine


--[[
    Registering libraries to the engine. Based on how ElvUI does this, great developers
    deserve credit where credit is due.
]]
do
    T.Libs = {}
    T.LibsMinor = {}

    function T:AddLib(name, major, minor)
        if not name then return end

        if type(major) == 'table' and type(minor) == 'number' then
            T.Libs[name], T.LibsMinor[name] = major, minor
        else
            T.Libs[name], T.LibsMinor[name] = _G.LibStub(major, minor)
        end
    end

    T:AddLib("AceAddon", AceAddon, AceAddonMinor)
    T:AddLib("AceDB", "AceDB-3.0")
    T:AddLib("LSM", "LibSharedMedia-3.0")

    -- libraries used for options
    T:AddLib('AceGUI', 'AceGUI-3.0')
    T:AddLib('AceConfig', 'AceConfig-3.0')
    T:AddLib('AceConfigDialog', 'AceConfigDialog-3.0')
    T:AddLib('AceConfigRegistry', 'AceConfigRegistry-3.0')
    T:AddLib('AceDBOptions', 'AceDBOptions-3.0')
    T:AddLib('LibElvUIPlugin', 'LibElvUIPlugin-1.0')
end

--[[
    Load AddOn metadata
    ]]
do
    local version = GetAddOnMetadata(AddOnName, 'Version')
    T.addonMetadata.version = version
end

--- Called by AceAddon when the addon is initialized
function T:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("TwichDB")

    ---@type ConfigurationModule
    local CM = self:GetModule("Configuration")

    -- Register with ElVUI as a plugin
    if T.Libs.LibElvUIPlugin then
        T.Libs.LibElvUIPlugin:RegisterPlugin('TwichUI', nil, false, T.addonMetadata.version)
    end

    --- Enable optional modules based on user settings
    ---@type table<AceModule, boolean>
    local moduleRegistry = {
        { module = self:GetModule("ChatEnhancements"):GetModule("ChatAlerts"), enabled = CM.Options.ChatEnhancement:IsAlertsEnabled() },
        { module = self:GetModule("SmartMount"),                               enabled = CM.Options.SmartMount:GetEnabled() },
        { module = self:GetModule("Datatexts"),                                enabled = CM.Options.Datatext:IsModuleEnabled() },
        { module = self:GetModule("BestInSlot"),                               enabled = CM.Options.BestInSlot:IsBestInSlotModuleEnabled() },
    }

    for _, entry in ipairs(moduleRegistry) do
        if entry.enabled then
            entry.module:Enable()
        end
    end
end
