---@diagnostic disable: undefined-field, inject-field
--[[
    Module that adds datatexts to ElvUI.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
local UIParent = _G.UIParent
local format = string.format
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local MouseIsOver = _G.MouseIsOver
local GetMouseFocus = _G.GetMouseFocus
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local LSM = T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)

local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil

local TOOLTIP_EDGE_PADDING = 16
local TOOLTIP_OFFSET = 8
local TOOLTIP_HIDE_DELAY = 0.05

local function IsFrameDescendantOf(frame, potentialAncestor)
    if not (frame and potentialAncestor) then
        return false
    end

    local current = frame
    while current do
        if current == potentialAncestor then
            return true
        end

        current = current.GetParent and current:GetParent() or nil
    end

    return false
end

local function IsPanelStillHovered(panel)
    if not panel then
        return false
    end

    if panel.IsMouseOver and panel:IsMouseOver() then
        return true
    end

    if MouseIsOver and MouseIsOver(panel) then
        return true
    end

    if GetMouseFocus then
        local mouseFocus = GetMouseFocus()
        if mouseFocus and IsFrameDescendantOf(mouseFocus, panel) then
            return true
        end
    end

    return false
end

local function RunDeferredPanelLeave(panel, onConfirmedLeave)
    if type(onConfirmedLeave) ~= "function" then
        return
    end

    if not panel then
        onConfirmedLeave()
        return
    end

    panel.__twichuiLeaveRequest = (panel.__twichuiLeaveRequest or 0) + 1
    local leaveRequest = panel.__twichuiLeaveRequest

    if not (C_Timer and type(C_Timer.After) == "function") then
        if not IsPanelStillHovered(panel) then
            onConfirmedLeave()
        end
        return
    end

    C_Timer.After(TOOLTIP_HIDE_DELAY, function()
        if not panel or panel.__twichuiLeaveRequest ~= leaveRequest then
            return
        end

        if IsPanelStillHovered(panel) then
            return
        end

        onConfirmedLeave()
    end)
end

--- @class ElvUI_DT_Panel : Frame
--- @field text FontString

---@alias DatatextDefinition {name: string, prettyName: string, events: string[]|nil, onEventFunc: fun(panel: ElvUI_DT_Panel, event: string, ...)|nil, onUpdateFunc: fun(panel: ElvUI_DT_Panel, elapsed: number)|nil, onClickFunc: fun(panel: ElvUI_DT_Panel, button: string)|nil, onEnterFunc: fun(panel: ElvUI_DT_Panel)|nil, onLeaveFunc: fun(panel: ElvUI_DT_Panel)|nil, module: AceModule|nil}

---@class DataTextModule : AceModule
---@field DatatextRegistry table<string, DatatextDefinition>
---@field CommonEvents table<string, string>
---@field tooltipOwner Frame|nil
---@field activeTooltip GameTooltip|nil
---@field standaloneMenu TwichUISecureMenu|nil
---@field standalonePanels table<string, Frame>|nil
---@field ShowStandaloneMenu fun(self: DataTextModule, panel: Frame|nil, menuList: table)|nil
---@field HideStandaloneMenu fun(self: DataTextModule)|nil
---@field RefreshStandalonePanels fun(self: DataTextModule)|nil
---@field HideStandalonePanels fun(self: DataTextModule)|nil
---@field RefreshStandaloneDataText fun(self: DataTextModule, datatextName: string)|nil
---@field GetStandaloneDatatextChoices fun(self: DataTextModule): table<string, string>|nil
local DataTextModule = T:NewModule("Datatexts")

DataTextModule.CommonEvents = {
    ELVUI_FORCE_UPDATE = "ELVUI_FORCE_UPDATE",
    TWICHUI_FORCE_UPDATE = "TWICHUI_FORCE_UPDATE",
}

function DataTextModule:RunDeferredPanelLeave(panel, onConfirmedLeave)
    RunDeferredPanelLeave(panel, onConfirmedLeave)
end

--- Convenience function to get the ElvUI engine instance.
local function GetElvUIEngine()
    return _G.ElvUI and _G.ElvUI[1]
end

function DataTextModule:ShowMenu(panel, menuList)
    local activeTooltip = self:GetActiveDatatextTooltip()
    if activeTooltip and activeTooltip.Hide then
        self:HideDatatextTooltip(activeTooltip, true)
    end

    local E = GetElvUIEngine()
    if panel and panel.__twichuiStandalonePanel and self.ShowStandaloneMenu then
        self:ShowStandaloneMenu(panel, menuList)
        return
    end

    if not (E and E.SetEasyMenuAnchor and E.ComplicatedMenu) then
        if self.ShowStandaloneMenu then
            self:ShowStandaloneMenu(panel, menuList)
        end
        return
    end

    E:SetEasyMenuAnchor(E.EasyMenu, panel)
    E:ComplicatedMenu(menuList, E.EasyMenu, nil, nil, nil, "MENU")
end

function DataTextModule:ResolveStandaloneCallbackTarget(module, panel)
    if panel and panel.__twichuiStandaloneInstance and panel.__twichuiStandaloneBaseModule == module then
        return panel.__twichuiStandaloneInstance
    end

    return module
end

function DataTextModule:CreateBoundCallback(module, methodName)
    return function(panel, ...)
        local isEnter = methodName == "OnEnter"
        local isLeave = methodName == "OnLeave"

        if isEnter and panel then
            panel.__twichuiLeaveRequest = (panel.__twichuiLeaveRequest or 0) + 1
            self:SetTooltipOwner(panel)
        end

        local target = self:ResolveStandaloneCallbackTarget(module, panel)
        local method = target and target[methodName]
        if type(method) ~= "function" then
            if isLeave and panel then
                RunDeferredPanelLeave(panel, function()
                    self:ClearTooltipOwner(panel)
                end)
            end
            return nil
        end

        if isLeave and panel then
            local packedArgs = { ... }
            RunDeferredPanelLeave(panel, function()
                method(target, panel, unpack(packedArgs))
                self:ClearTooltipOwner(panel)
            end)
            return nil
        end

        local results = { method(target, panel, ...) }

        return unpack(results)
    end
end

--- Convenience function to get the ElvUI DataTexts module instance.
local function GetElvUIDatatextModule()
    local E = GetElvUIEngine()
    return E and E:GetModule("DataTexts")
end

local function GetSmartTooltipAnchor(owner, tooltip)
    if not owner or not owner.GetLeft or not owner.GetRight or not owner.GetTop or not owner.GetBottom then
        return "TOPLEFT", "BOTTOMLEFT", 0, -TOOLTIP_OFFSET
    end

    local parentWidth = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 1920
    local parentHeight = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 1080
    local left = owner:GetLeft() or 0
    local right = owner:GetRight() or left
    local top = owner:GetTop() or parentHeight
    local bottom = owner:GetBottom() or 0
    local tooltipWidth = tooltip and tooltip.GetWidth and math.max(tooltip:GetWidth() or 0, 240) or 240
    local tooltipHeight = tooltip and tooltip.GetHeight and math.max(tooltip:GetHeight() or 0, 80) or 80
    local leftSpace = left
    local rightSpace = parentWidth - right
    local topSpace = parentHeight - top
    local bottomSpace = bottom
    local openUp = not (topSpace < (tooltipHeight + TOOLTIP_EDGE_PADDING) and bottomSpace > topSpace)
    local openLeft = rightSpace < (tooltipWidth + TOOLTIP_EDGE_PADDING) and leftSpace > rightSpace

    if openUp and openLeft then
        return "BOTTOMRIGHT", "TOPRIGHT", 0, TOOLTIP_OFFSET
    end

    if openUp then
        return "BOTTOMLEFT", "TOPLEFT", 0, TOOLTIP_OFFSET
    end

    if openLeft then
        return "TOPRIGHT", "BOTTOMRIGHT", 0, -TOOLTIP_OFFSET
    end

    return "TOPLEFT", "BOTTOMLEFT", 0, -TOOLTIP_OFFSET
end

local function ApplySmartTooltipAnchor(tooltip, owner, resetOwnerAnchor)
    if not (tooltip and owner and tooltip.SetOwner and tooltip.SetPoint and tooltip.ClearAllPoints) then
        return
    end

    local point, relativePoint, x, y = GetSmartTooltipAnchor(owner, tooltip)
    local currentOwner = tooltip.GetOwner and tooltip:GetOwner() or nil
    if resetOwnerAnchor or currentOwner ~= owner then
        tooltip:SetOwner(owner, "ANCHOR_NONE")
    end
    tooltip:ClearAllPoints()

    if owner.__twichuiStandalonePanel and UIParent and owner.GetLeft and owner.GetRight and owner.GetTop and owner.GetBottom then
        local visualOwner = owner.GetParent and owner:GetParent() or owner
        local visualTop = visualOwner and visualOwner.GetTop and visualOwner:GetTop() or owner:GetTop() or 0
        local visualBottom = visualOwner and visualOwner.GetBottom and visualOwner:GetBottom() or owner:GetBottom() or 0
        local anchorX = 0
        local anchorY = 0

        if point == "BOTTOMRIGHT" and relativePoint == "TOPRIGHT" then
            anchorX = owner:GetRight() or 0
            anchorY = visualTop + y
        elseif point == "BOTTOMLEFT" and relativePoint == "TOPLEFT" then
            anchorX = owner:GetLeft() or 0
            anchorY = visualTop + y
        elseif point == "TOPRIGHT" and relativePoint == "BOTTOMRIGHT" then
            anchorX = owner:GetRight() or 0
            anchorY = visualBottom + y
        else
            anchorX = (owner:GetLeft() or 0) + x
            anchorY = visualBottom + y
        end

        tooltip:SetPoint(point, UIParent, "BOTTOMLEFT", anchorX, anchorY)
        return
    end

    tooltip:SetPoint(point, owner, relativePoint, x, y)
end

local function ShowTooltipWithFade(tooltip)
    if not tooltip then
        return
    end

    tooltip:SetAlpha(1)
    tooltip:Show()
end

local function HideTooltipWithFade(tooltip)
    if not tooltip then
        return
    end

    if not tooltip:IsShown() then
        tooltip:Hide()
        return
    end

    tooltip:SetAlpha(1)
    tooltip:Hide()
end

local function GetTooltipOwnerFrame(tooltip, owner)
    if owner then
        return owner
    end

    if tooltip and tooltip.GetOwner then
        return tooltip:GetOwner()
    end

    return nil
end

local function IsTooltipHoverMaintained(tooltip, owner)
    if MouseIsOver then
        if owner and owner.IsShown and owner:IsShown() and MouseIsOver(owner) then
            return true
        end
    end

    return false
end

local function GetTooltipDebugLabel(tooltip)
    if tooltip == _G.GameTooltip then
        return "GameTooltip"
    end

    if tooltip and tooltip.GetName then
        return tooltip:GetName() or "<unnamed tooltip>"
    end

    return tostring(tooltip)
end

local function GetTooltipDebugPoint(frame)
    if not (frame and frame.GetPoint) then
        return "n/a"
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
    local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
    return format("%s -> %s %s (%.1f, %.1f)", tostring(point), tostring(relativeName), tostring(relativePoint), x or 0,
        y or 0)
end

local function GetTooltipDebugSize(frame)
    if not frame then
        return "n/a"
    end

    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    return format("%.1f x %.1f", width or 0, height or 0)
end

local function BuildTooltipDebugReport(module)
    local owner = module.tooltipOwner
    local tooltip = module:GetActiveDatatextTooltip()
    if not owner and tooltip and tooltip.GetOwner then
        owner = tooltip:GetOwner()
    end
    local ownerName = owner and owner.GetName and owner:GetName() or tostring(owner)
    local ownerLeft = owner and owner.GetLeft and owner:GetLeft() or nil
    local ownerRight = owner and owner.GetRight and owner:GetRight() or nil
    local ownerTop = owner and owner.GetTop and owner:GetTop() or nil
    local ownerBottom = owner and owner.GetBottom and owner:GetBottom() or nil
    local tooltipShown = tooltip and tooltip.IsShown and tooltip:IsShown() or false
    local tooltipLines = tooltip and tooltip.NumLines and tooltip:NumLines() or 0
    local tooltipAlpha = tooltip and tooltip.GetAlpha and tooltip:GetAlpha() or 0

    return table.concat({
        "TwichUI Datatext Debug",
        format("Tooltip owner: %s", ownerName or "nil"),
        format("Owner standalone: %s", owner and owner.__twichuiStandalonePanel and "true" or "false"),
        format("Owner rect: L=%s R=%s T=%s B=%s", tostring(ownerLeft), tostring(ownerRight), tostring(ownerTop),
            tostring(ownerBottom)),
        format("Tooltip frame: %s", GetTooltipDebugLabel(tooltip)),
        format("Tooltip shown: %s", tooltipShown and "true" or "false"),
        format("Tooltip alpha: %.2f", tooltipAlpha or 0),
        format("Tooltip lines: %d", tooltipLines or 0),
        format("Tooltip point: %s", GetTooltipDebugPoint(tooltip)),
        format("Tooltip size: %s", GetTooltipDebugSize(tooltip)),
    }, "\n")
end

local function LogTooltipDebug(message, ...)
    if not (DebugConsole and DebugConsole.Logf) then
        return
    end

    pcall(DebugConsole.Logf, DebugConsole, "datatexts", false, message, ...)
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
    if not DT or type(DT.RegisterDatatext) ~= "function" then
        return
    end

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
    if not DT then
        return false
    end

    return DT.RegisteredDatatexts and DT.RegisteredDatatexts[name] ~= nil
end

--- Removes a datatext with the given name from ElvUI.
--- @param name string The name of the datatext to remove.
function DataTextModule:RemoveDatatext(name)
    local DT = GetElvUIDatatextModule()

    -- wipe from ElvUI Registered Datatexts
    if DT and DT.RegisteredDatatexts then
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
function DataTextModule:Inform(datatextDefinition)
    if not self.DatatextRegistry then
        self.DatatextRegistry = {}
    end
    if not datatextDefinition.prettyName and type(datatextDefinition.name) == "string" then
        datatextDefinition.prettyName = datatextDefinition.name:gsub("^TwichUI:%s*", "")
    end
    self.DatatextRegistry[datatextDefinition.name] = datatextDefinition
end

---@param datatextDefinition DatatextDefinition
function DataTextModule:RegisterDefinition(datatextDefinition)
    if type(datatextDefinition) ~= "table" or type(datatextDefinition.name) ~= "string" then
        return
    end

    self:Inform(datatextDefinition)

    if self.IsEnabled and self:IsEnabled() then
        RegisterDatatext(datatextDefinition)
        if self.RefreshStandalonePanels then
            self:RefreshStandalonePanels()
        end
    end
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

function DataTextModule:GetStandaloneTooltip()
    if not self.standaloneTooltip then
        local tooltip = CreateFrame("GameTooltip", "TwichUIDatatextTooltip", UIParent, "GameTooltipTemplate")
        tooltip:SetFrameStrata("TOOLTIP")
        tooltip:SetClampedToScreen(true)
        if tooltip.EnableMouse then
            tooltip:EnableMouse(false)
        end
        self.standaloneTooltip = tooltip
    end

    local tooltip = self.standaloneTooltip
    if tooltip then
        tooltip:SetFrameStrata("TOOLTIP")
        tooltip:SetClampedToScreen(true)
        if tooltip.EnableMouse then
            tooltip:EnableMouse(false)
        end
    end

    return tooltip
end

function DataTextModule:GetActiveDatatextTooltip()
    if self.activeTooltip then
        return self.activeTooltip
    end

    if self.tooltipOwner and self.tooltipOwner.__twichuiStandalonePanel then
        return self:GetStandaloneTooltip()
    end

    local DT = GetElvUIDatatextModule()
    return (DT and DT.tooltip) or _G.DataTextTooltip
end

function DataTextModule:GetElvUITooltip()
    local useStandaloneTooltip = self.tooltipOwner and self.tooltipOwner.__twichuiStandalonePanel
    local tooltip

    if useStandaloneTooltip then
        tooltip = self:GetStandaloneTooltip()
    elseif self.activeTooltip then
        tooltip = self.activeTooltip
    else
        local DT = GetElvUIDatatextModule()
        tooltip = (DT and DT.tooltip) or _G.DataTextTooltip
    end

    if self.tooltipOwner then
        ApplySmartTooltipAnchor(tooltip, self.tooltipOwner, true)
    end
    self:ApplyTooltipFontStyle(tooltip)
    return tooltip
end

function DataTextModule:ApplyTooltipFontStyle(tooltip)
    if not (tooltip and tooltip.GetRegions) then
        return
    end

    local options = self.GetOptions and self.GetOptions()
    local owner = self.tooltipOwner
    local ownerPanel = owner and owner.__twichuiStandalonePanel and owner.ownerPanel or nil
    local style = nil

    if ownerPanel and options and options.GetResolvedStandaloneStyle then
        style = options:GetResolvedStandaloneStyle(ownerPanel.panelID)
    elseif options and options.GetStandaloneDB then
        style = options:GetStandaloneDB().style
    end

    if type(style) ~= "table" then
        return
    end

    local fontName = style.tooltipFont or style.font
    local fontSize = tonumber(style.tooltipFontSize) or tonumber(style.fontSize) or 12
    local fontPath = STANDARD_TEXT_FONT
    if LSM and type(fontName) == "string" and fontName ~= "" then
        fontPath = LSM:Fetch("font", fontName, true) or STANDARD_TEXT_FONT
    end

    for _, region in ipairs({ tooltip:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "FontString" and region.SetFont then
            region:SetFont(fontPath, fontSize, "")
        end
    end
end

function DataTextModule:ShowDatatextTooltip(tooltip)
    local owner = self.tooltipOwner
    if not owner and tooltip and tooltip.GetOwner then
        owner = tooltip:GetOwner()
    end

    if tooltip then
        self.activeTooltip = tooltip
        tooltip.__twichuiHideRequest = (tooltip.__twichuiHideRequest or 0) + 1
    end

    LogTooltipDebug("Show tooltip frame=%s owner=%s lines=%s", GetTooltipDebugLabel(tooltip),
        owner and (owner.GetName and owner:GetName() or tostring(owner)) or "nil",
        tooltip and tooltip.NumLines and tooltip:NumLines() or 0)

    ShowTooltipWithFade(tooltip)
    if owner then
        ApplySmartTooltipAnchor(tooltip, owner, false)
    end
    LogTooltipDebug("Post-show tooltip frame=%s shown=%s lines=%s owner=%s point=%s size=%s", GetTooltipDebugLabel(tooltip),
        tooltip and tooltip.IsShown and tooltip:IsShown() and "true" or "false",
        tooltip and tooltip.NumLines and tooltip:NumLines() or 0,
        owner and (owner.GetName and owner:GetName() or tostring(owner)) or "nil",
        GetTooltipDebugPoint(tooltip),
        GetTooltipDebugSize(tooltip))
end

function DataTextModule:HideDatatextTooltip(tooltip, forceImmediate)
    tooltip = tooltip or self.activeTooltip
    if not tooltip then
        return
    end

    local owner = GetTooltipOwnerFrame(tooltip, self.tooltipOwner)
    local hideRequest = (tooltip.__twichuiHideRequest or 0) + 1
    tooltip.__twichuiHideRequest = hideRequest

    LogTooltipDebug("Hide tooltip frame=%s", GetTooltipDebugLabel(tooltip))

    if forceImmediate then
        HideTooltipWithFade(tooltip)
        if self.activeTooltip == tooltip then
            self.activeTooltip = nil
        end
        return
    end

    if not (C_Timer and type(C_Timer.After) == "function") then
        HideTooltipWithFade(tooltip)
        if self.activeTooltip == tooltip then
            self.activeTooltip = nil
        end
        return
    end

    C_Timer.After(TOOLTIP_HIDE_DELAY, function()
        if not tooltip or tooltip.__twichuiHideRequest ~= hideRequest then
            return
        end

        if IsTooltipHoverMaintained(tooltip, owner) then
            LogTooltipDebug("Abort hide tooltip frame=%s hover maintained", GetTooltipDebugLabel(tooltip))
            return
        end

        HideTooltipWithFade(tooltip)
        if self.activeTooltip == tooltip then
            self.activeTooltip = nil
        end
    end)
end

function DataTextModule:SetTooltipOwner(panel)
    self.tooltipOwner = panel
    LogTooltipDebug("Set owner=%s", panel and (panel.GetName and panel:GetName() or tostring(panel)) or "nil")
end

function DataTextModule:ClearTooltipOwner(panel)
    if self.tooltipOwner == panel then
        LogTooltipDebug("Clear owner=%s", panel and (panel.GetName and panel:GetName() or tostring(panel)) or "nil")
        self.tooltipOwner = nil
    end
end

function DataTextModule:OnEnable()
    -- Called when the module is enabled
    for _, datatextDefinition in pairs(self.DatatextRegistry) do
        RegisterDatatext(datatextDefinition)
    end

    if self.RefreshStandalonePanels then
        self:RefreshStandalonePanels()
    end
end

function DataTextModule:OnDisable()
    -- Called when the module is disabled
    for name, _ in pairs(self.DatatextRegistry) do
        self:RemoveDatatext(name)
    end

    if self.HideStandalonePanels then
        self:HideStandalonePanels()
    end
end

function DataTextModule:OnInitialize()
    if DebugConsole and DebugConsole.RegisterSource then
        DebugConsole:RegisterSource("datatexts", {
            title = "Datatexts",
            order = 25,
            aliases = { "datatext", "panels", "datapanels", "tooltip" },
            maxLines = 120,
            buildReport = function()
                return BuildTooltipDebugReport(self)
            end,
        })
    end
end

function DataTextModule:RefreshDataText(datatextName)
    local DT = GetElvUIDatatextModule()
    if DT and type(DT.ForceUpdate_DataText) == "function" then
        DT:ForceUpdate_DataText(datatextName)
    end

    if self.RefreshStandaloneDataText then
        self:RefreshStandaloneDataText(datatextName)
    end
end
