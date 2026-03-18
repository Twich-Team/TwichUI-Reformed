--[[
    Module that adds datatexts to ElvUI.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

--- @class ElvUI_DT_Panel : Frame
--- @field text FontString

---@alias DatatextDefinition {name: string, prettyName: string, events: string[]|nil, onEventFunc: fun(panel: ElvUI_DT_Panel, event: string, ...)|nil, onUpdateFunc: fun(panel: ElvUI_DT_Panel, elapsed: number)|nil, onClickFunc: fun(panel: ElvUI_DT_Panel, button: string)|nil, onEnterFunc: fun(panel: ElvUI_DT_Panel)|nil, onLeaveFunc: fun(panel: ElvUI_DT_Panel)|nil, module: AceModule|nil}

---@class DataTextModule : AceModule
---@field DatatextRegistry table<string, DatatextDefinition>
---@field CommonEvents table<string, string>
local DataTextModule = T:NewModule("Datatexts")

DataTextModule.CommonEvents = {
    ELVUI_FORCE_UPDATE = "ELVUI_FORCE_UPDATE",
}

--- Convenience function to get the ElvUI engine instance.
local function GetElvUIEngine()
    return _G.ElvUI and _G.ElvUI[1]
end

function DataTextModule:ShowMenu(panel, menuList)
    local E = GetElvUIEngine()
    E:SetEasyMenuAnchor(E.EasyMenu, panel)
    E:ComplicatedMenu(menuList, E.EasyMenu, nil, nil, nil, "MENU")
end

--- Convenience function to get the ElvUI DataTexts module instance.
local function GetElvUIDatatextModule()
    local E = GetElvUIEngine()
    return E and E:GetModule("DataTexts")
end

---@return DatatextConfigurationOptions options
function DataTextModule.GetOptions()
    return T:GetModule("Configuration").Options.Datatext
end

local function RegisterDatatext(datatextDefinition)
    -- first enable
    if datatextDefinition.module and not datatextDefinition.module:IsEnabled() then
        datatextDefinition.module:Enable()
    end

    local DT = GetElvUIDatatextModule()

    DT:RegisterDatatext(
        datatextDefinition.name,
        "TwichUI",
        datatextDefinition.events or {},
        datatextDefinition.onEventFunc,
        datatextDefinition.onUpdateFunc,
        datatextDefinition.onClickFunc,
        datatextDefinition.onEnterFunc,
        datatextDefinition.onLeaveFunc,
        nil
    )
end
--- Retrieves the configuration database for a specific datatext.
function DataTextModule:GetDatatextDB(datatextName)
    local configurationDB = T.db.profile.configuration
    if not configurationDB.datatext then
        configurationDB.datatext = {}
    end
    if not configurationDB.datatext[datatextName] then
        configurationDB.datatext[datatextName] = {}
    end
    return configurationDB.datatext[datatextName]
end

--- Checks if a datatext with the given name is registered in ElvUI.
--- @param name string The name of the datatext to check.
--- @return boolean True if the datatext is registered, false otherwise.
function DataTextModule:IsDatatextRegistered(name)
    local DT = GetElvUIDatatextModule()
    return DT.RegisteredDatatexts and DT.RegisteredDatatexts[name] ~= nil
end

--- Removes a datatext with the given name from ElvUI.
--- @param name string The name of the datatext to remove.
function DataTextModule:RemoveDatatext(name)
    local DT = GetElvUIDatatextModule()

    -- wipe from ElvUI Registered Datatexts
    if DT.RegisteredDatatexts then
        DT.RegisteredDatatexts[name] = nil
    end

    if self.DatatextRegistry[name] and self.DatatextRegistry[name].module then
        local module = self.DatatextRegistry[name].module
        if module and module:IsEnabled() then
            module:Disable()
        end
    end

    -- refresh the configuration, as if this occurs, the user is likely within the config
    ---@type ConfigurationModule
    local CM = T:GetModule("Configuration")
    CM:Refresh()
end

---@param datatextDefinition DatatextDefinition
---@param module AceModule
function DataTextModule:Inform(datatextDefinition)
    if not self.DatatextRegistry then
        self.DatatextRegistry = {}
    end
    self.DatatextRegistry[datatextDefinition.name] = datatextDefinition
end

function DataTextModule:GetElvUIValueColor()
    -- ElvUI's value color (db.general.valuecolor or E.media.rgbvaluecolor depending on version)
    local E = GetElvUIEngine()
    local vc = E.db and E.db.general and E.db.general.valuecolor
    if not vc then vc = E.media and E.media.rgbvaluecolor end
    if vc then
        return vc.r, vc.g, vc.b
    end
    return nil
end

function DataTextModule:GetElvUITooltip()
    local E = GetElvUIDatatextModule()
    return E and E.tooltip
end

function DataTextModule:OnEnable()
    -- Called when the module is enabled
    for _, datatextDefinition in pairs(self.DatatextRegistry) do
        RegisterDatatext(datatextDefinition)
    end
end

function DataTextModule:OnDisable()
    -- Called when the module is disabled
    for name, _ in pairs(self.DatatextRegistry) do
        self:RemoveDatatext(name)
    end
end

function DataTextModule:OnInitialize()
    -- Called when the module is initialized
end

function DataTextModule:RefreshDataText(datatextName)
    local DT = GetElvUIDatatextModule()
    DT:ForceUpdate_DataText(datatextName)
end
