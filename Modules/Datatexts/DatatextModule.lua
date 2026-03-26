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

function DataTextModule:MaybeFlashPanel(panel, dbKey, previousText, nextText)
    if not (panel and dbKey) then
        return
    end

    if previousText == nil or previousText == nextText then
        panel.__twichuiLastFlashText = nextText
        return
    end

    local options = self.GetOptions and self.GetOptions()
    local db = options and options.GetDatatextDB and options:GetDatatextDB(dbKey) or nil
    if not db or db.flashOnUpdate ~= true then
        panel.__twichuiLastFlashText = nextText
        return
    end

    self:PlayPanelFlash(panel)
    panel.__twichuiLastFlashText = nextText
end

function DataTextModule:PlayPanelFlash(panel)
    if not panel then
        return false
    end

    if not panel.__twichuiFlashAnimation then
        local flashLayer = CreateFrame("Frame", nil, panel)
        flashLayer:SetAllPoints(panel)
        flashLayer:SetFrameStrata(panel:GetFrameStrata() or "MEDIUM")
        flashLayer:SetFrameLevel(math.max((panel.GetFrameLevel and panel:GetFrameLevel() or 1) + 1, 1))
        if flashLayer.EnableMouse then
            flashLayer:EnableMouse(false)
        end

        local flashFill = flashLayer:CreateTexture(nil, "OVERLAY", nil, 1)
        flashFill:SetAllPoints(flashLayer)
        flashFill:SetColorTexture(0.98, 0.82, 0.24, 0)
        flashFill:SetBlendMode("ADD")

        local flashBloom = flashLayer:CreateTexture(nil, "OVERLAY", nil, 2)
        flashBloom:SetPoint("TOPLEFT", flashLayer, "TOPLEFT", 4, -2)
        flashBloom:SetPoint("BOTTOMRIGHT", flashLayer, "BOTTOMRIGHT", -4, 2)
        flashBloom:SetColorTexture(1, 0.9, 0.42, 0)
        flashBloom:SetBlendMode("ADD")

        local flashBorder = flashLayer:CreateTexture(nil, "OVERLAY", nil, 3)
        flashBorder:SetPoint("TOPLEFT", flashLayer, "TOPLEFT", -1, 1)
        flashBorder:SetPoint("BOTTOMRIGHT", flashLayer, "BOTTOMRIGHT", 1, -1)
        flashBorder:SetColorTexture(0.98, 0.82, 0.24, 0)
        flashBorder:SetBlendMode("ADD")

        local flashSheen = flashLayer:CreateTexture(nil, "OVERLAY", nil, 4)
        flashSheen:SetPoint("TOPLEFT", flashLayer, "TOPLEFT", 0, 0)
        flashSheen:SetPoint("BOTTOMLEFT", flashLayer, "BOTTOMLEFT", 0, 0)
        flashSheen:SetWidth(math.max(18, (panel.GetWidth and panel:GetWidth() or 80) * 0.24))
        flashSheen:SetColorTexture(1, 0.96, 0.82, 0)
        flashSheen:SetBlendMode("ADD")

        local flashText = nil
        if panel.text and panel.text.GetParent then
            flashText = panel:CreateFontString(nil, "OVERLAY", nil, 8)
            flashText:SetAllPoints(panel.text)
            if panel.text.GetFont and flashText.SetFont then
                local fontPath, fontSize, fontFlags = panel.text:GetFont()
                if fontPath then
                    flashText:SetFont(fontPath, fontSize or 12, fontFlags or "")
                end
            elseif panel.text.GetFontObject and flashText.SetFontObject then
                local fontObject = panel.text:GetFontObject()
                if fontObject then
                    flashText:SetFontObject(fontObject)
                end
            end
            if panel.text.GetJustifyH and flashText.SetJustifyH then
                flashText:SetJustifyH(panel.text:GetJustifyH() or "CENTER")
            end
            if panel.text.GetJustifyV and flashText.SetJustifyV then
                flashText:SetJustifyV(panel.text:GetJustifyV() or "MIDDLE")
            end
            if panel.text.GetWordWrap and flashText.SetWordWrap then
                flashText:SetWordWrap(panel.text:GetWordWrap())
            end
            flashText:SetText("")
            flashText:SetTextColor(1, 0.94, 0.72, 0)
            flashText:SetShadowColor(1, 0.78, 0.2, 0)
            flashText:SetShadowOffset(0, 0)
        end

        local animationGroup = panel:CreateAnimationGroup()

        local fillFadeIn = animationGroup:CreateAnimation("Alpha")
        fillFadeIn:SetTarget(flashFill)
        fillFadeIn:SetOrder(1)
        fillFadeIn:SetDuration(0.08)
        fillFadeIn:SetFromAlpha(0)
        fillFadeIn:SetToAlpha(0.22)

        local bloomFadeIn = animationGroup:CreateAnimation("Alpha")
        bloomFadeIn:SetTarget(flashBloom)
        bloomFadeIn:SetOrder(1)
        bloomFadeIn:SetDuration(0.10)
        bloomFadeIn:SetFromAlpha(0)
        bloomFadeIn:SetToAlpha(0.48)

        local borderFadeIn = animationGroup:CreateAnimation("Alpha")
        borderFadeIn:SetTarget(flashBorder)
        borderFadeIn:SetOrder(1)
        borderFadeIn:SetDuration(0.08)
        borderFadeIn:SetFromAlpha(0)
        borderFadeIn:SetToAlpha(0.95)

        local sheenFadeIn = animationGroup:CreateAnimation("Alpha")
        sheenFadeIn:SetTarget(flashSheen)
        sheenFadeIn:SetOrder(1)
        sheenFadeIn:SetDuration(0.06)
        sheenFadeIn:SetFromAlpha(0)
        sheenFadeIn:SetToAlpha(0.72)

        local fadeIn = animationGroup:CreateAnimation("Alpha")
        fadeIn:SetTarget(panel.text)
        fadeIn:SetOrder(1)
        fadeIn:SetDuration(0.08)
        fadeIn:SetFromAlpha(1)
        fadeIn:SetToAlpha(1)

        local fillFadeOut = animationGroup:CreateAnimation("Alpha")
        fillFadeOut:SetTarget(flashFill)
        fillFadeOut:SetOrder(2)
        fillFadeOut:SetDuration(0.30)
        fillFadeOut:SetFromAlpha(0.22)
        fillFadeOut:SetToAlpha(0)

        local bloomFadeOut = animationGroup:CreateAnimation("Alpha")
        bloomFadeOut:SetTarget(flashBloom)
        bloomFadeOut:SetOrder(2)
        bloomFadeOut:SetDuration(0.34)
        bloomFadeOut:SetFromAlpha(0.48)
        bloomFadeOut:SetToAlpha(0)

        local borderFadeOut = animationGroup:CreateAnimation("Alpha")
        borderFadeOut:SetTarget(flashBorder)
        borderFadeOut:SetOrder(2)
        borderFadeOut:SetDuration(0.34)
        borderFadeOut:SetFromAlpha(0.95)
        borderFadeOut:SetToAlpha(0)

        local sheenFadeOut = animationGroup:CreateAnimation("Alpha")
        sheenFadeOut:SetTarget(flashSheen)
        sheenFadeOut:SetOrder(2)
        sheenFadeOut:SetDuration(0.22)
        sheenFadeOut:SetFromAlpha(0.72)
        sheenFadeOut:SetToAlpha(0)

        local sheenSweep = animationGroup:CreateAnimation("Translation")
        sheenSweep:SetTarget(flashSheen)
        sheenSweep:SetOrder(2)
        sheenSweep:SetDuration(0.26)
        sheenSweep:SetOffset((panel.GetWidth and panel:GetWidth() or 80) * 0.62, 0)

        if flashText then
            local textFadeIn = animationGroup:CreateAnimation("Alpha")
            textFadeIn:SetTarget(flashText)
            textFadeIn:SetOrder(1)
            textFadeIn:SetDuration(0.06)
            textFadeIn:SetFromAlpha(0)
            textFadeIn:SetToAlpha(1)

            local textFadeOut = animationGroup:CreateAnimation("Alpha")
            textFadeOut:SetTarget(flashText)
            textFadeOut:SetOrder(2)
            textFadeOut:SetDuration(0.28)
            textFadeOut:SetFromAlpha(1)
            textFadeOut:SetToAlpha(0)
        end

        animationGroup:SetScript("OnPlay", function()
            if flashLayer and flashLayer.SetFrameLevel then
                flashLayer:SetFrameLevel(math.max((panel.GetFrameLevel and panel:GetFrameLevel() or 1) + 1, 1))
            end
            if flashSheen then
                local sweepWidth = math.max(18, (panel.GetWidth and panel:GetWidth() or 80) * 0.24)
                flashSheen:SetWidth(sweepWidth)
                flashSheen:ClearAllPoints()
                flashSheen:SetPoint("TOPLEFT", flashLayer, "TOPLEFT", -sweepWidth, 0)
                flashSheen:SetPoint("BOTTOMLEFT", flashLayer, "BOTTOMLEFT", -sweepWidth, 0)
            end
            if flashText and panel.text then
                if panel.text.GetFont and flashText.SetFont then
                    local fontPath, fontSize, fontFlags = panel.text:GetFont()
                    if fontPath then
                        flashText:SetFont(fontPath, fontSize or 12, fontFlags or "")
                    end
                elseif panel.text.GetFontObject and flashText.SetFontObject then
                    local fontObject = panel.text:GetFontObject()
                    if fontObject then
                        flashText:SetFontObject(fontObject)
                    end
                end

                flashText:SetText(panel.text:GetText() or "")
                local textR, textG, textB, textA = 1, 1, 1, 1
                if panel.text.GetTextColor then
                    textR, textG, textB, textA = panel.text:GetTextColor()
                end
                panel.__twichuiFlashOriginalTextColor = { textR or 1, textG or 1, textB or 1, textA or 1 }
                panel.text:SetTextColor(1, 0.96, 0.84, math.max(textA or 1, 0.95))
                if panel.text.SetShadowColor then
                    panel.__twichuiFlashOriginalShadowColor = { panel.text:GetShadowColor() }
                    panel.text:SetShadowColor(1, 0.78, 0.2, 0.95)
                end
                if panel.text.SetShadowOffset and panel.text.GetShadowOffset then
                    panel.__twichuiFlashOriginalShadowOffset = { panel.text:GetShadowOffset() }
                    panel.text:SetShadowOffset(0, 0)
                end
            end
        end)

        animationGroup:SetScript("OnFinished", function()
            flashFill:SetAlpha(0)
            flashBloom:SetAlpha(0)
            flashBorder:SetAlpha(0)
            flashSheen:SetAlpha(0)
            if flashText then
                flashText:SetAlpha(0)
                flashText:SetText("")
            end

            if panel.text and panel.__twichuiFlashOriginalTextColor and panel.text.SetTextColor then
                panel.text:SetTextColor(unpack(panel.__twichuiFlashOriginalTextColor))
            end
            if panel.text and panel.__twichuiFlashOriginalShadowColor and panel.text.SetShadowColor then
                panel.text:SetShadowColor(unpack(panel.__twichuiFlashOriginalShadowColor))
            end
            if panel.text and panel.__twichuiFlashOriginalShadowOffset and panel.text.SetShadowOffset then
                panel.text:SetShadowOffset(unpack(panel.__twichuiFlashOriginalShadowOffset))
            end
        end)

        panel.__twichuiFlashLayer = flashLayer
        panel.__twichuiFlashFill = flashFill
        panel.__twichuiFlashBloom = flashBloom
        panel.__twichuiFlashBorder = flashBorder
        panel.__twichuiFlashSheen = flashSheen
        panel.__twichuiFlashText = flashText
        panel.__twichuiFlashAnimation = animationGroup
    end

    if panel.__twichuiFlashAnimation then
        panel.__twichuiFlashAnimation:Stop()
        if panel.__twichuiFlashFill then
            panel.__twichuiFlashFill:SetAlpha(0)
        end
        if panel.__twichuiFlashBloom then
            panel.__twichuiFlashBloom:SetAlpha(0)
        end
        if panel.__twichuiFlashBorder then
            panel.__twichuiFlashBorder:SetAlpha(0)
        end
        if panel.__twichuiFlashSheen then
            panel.__twichuiFlashSheen:SetAlpha(0)
        end
        if panel.__twichuiFlashText then
            panel.__twichuiFlashText:SetAlpha(0)
        end
        panel.__twichuiFlashAnimation:Play()
    end

    return true
end

function DataTextModule:TestDatatextFlash(datatextName, dbKey)
    if type(datatextName) ~= "string" or datatextName == "" then
        return
    end

    local flashed = false
    local definition = self.DatatextRegistry and self.DatatextRegistry[datatextName] or nil
    local module = definition and definition.module or nil
    local panel = module and module.panel or nil

    if panel then
        flashed = self:PlayPanelFlash(panel) or flashed
    end

    for _, frame in pairs(self.standalonePanels or {}) do
        for slotIndex = 1, 5 do
            local slot = frame.slots and frame.slots[slotIndex] or nil
            local slotDefinition = slot and slot.datatextDefinition or nil
            if slot and slotDefinition and slotDefinition.name == datatextName then
                flashed = self:PlayPanelFlash(slot) or flashed
            end
        end
    end

    if not flashed and panel and dbKey then
        self:MaybeFlashPanel(panel, dbKey, "__twichui_flash_test_prev", "__twichui_flash_test_next")
    end
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
    LogTooltipDebug("Post-show tooltip frame=%s shown=%s lines=%s owner=%s point=%s size=%s",
        GetTooltipDebugLabel(tooltip),
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
