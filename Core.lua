--[[
    TwichUI Redux Core
    This file contains the core of the TwichUI addon.
]]
---@class _G
---@field TwichRx table
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

    -- Install error handler now that the DB is available
    local errorLog = T.Tools and (T.Tools --[[@as any]]).ErrorLog --[[@as TwichUIErrorLog|nil]]
    if errorLog then
        errorLog:Install()
    end

    ---@type ConfigurationModule
    local CM = self:GetModule("Configuration")
    local Options = CM.Options --[[@as any]]

    --- Enable optional modules based on user settings
    ---@type table<AceModule, boolean>
    local moduleRegistry = {
        { module = self:GetModule("ChatEnhancements"):GetModule("ChatStyling"),  enabled = Options.ChatEnhancement:IsStylingEnabled() },
        { module = self:GetModule("ChatEnhancements"):GetModule("ChatRenderer"), enabled = Options.ChatEnhancement:IsStylingEnabled() },
        { module = self:GetModule("ChatEnhancements"):GetModule("ChatAlerts"),   enabled = Options.ChatEnhancement:IsAlertsEnabled() },
        { module = self:GetModule("Chores"),                                     enabled = Options.Chores:GetEnabled() },
        { module = self:GetModule("SmartMount"),                                 enabled = Options.SmartMount:GetEnabled() },
        { module = self:GetModule("EasyFish"),                                   enabled = Options.EasyFish:GetEnabled() },
        { module = self:GetModule("Datatexts"),                                  enabled = Options.Datatext:IsModuleEnabled() },
        { module = self:GetModule("UnitFrames"),                                 enabled = Options.UnitFrames:GetEnabled() },
        { module = self:GetModule("BestInSlot"),                                 enabled = Options.BestInSlot:IsBestInSlotModuleEnabled() },
        { module = self:GetModule("QualityOfLife"):GetModule("Gathering"),       enabled = Options.Gathering:GetEnabled() },
    }

    for _, entry in ipairs(moduleRegistry) do
        if entry.enabled then
            entry.module:Enable()
        end
    end
end
