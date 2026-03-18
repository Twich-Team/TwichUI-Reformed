--[[
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local E = _G.ElvUI and _G.ElvUI[1]

---@class NotificationModule : AceModule, AceEvent-3.0
---@field Frame NotificationFrame
local NM = T:NewModule("Notification", "AceEvent-3.0")
NM:SetEnabledState(true)

local AceGUI = LibStub("AceGUI-3.0")

---@alias NotificationOptions { displayDuration: number|nil, soundKey: string|nil, wrap: boolean|nil, wrapMessage: string|nil, wrapMessageOptions: WrapperMessageOptions|nil }
---@alias WrapperMessageOptions { fontSize: number|nil }

function NM:OnEnable()
    self:RegisterMessage("TWICH_NOTIFICATION")

    -- Create an ElvUI-style anchor/mover for the notification panel so
    -- users can position it like other ElvUI elements.
    if not self.anchor then
        local parent = (E and E.UIParent) or UIParent

        local anchor = CreateFrame("Frame", "TwichUI_NotificationAnchor", parent)
        anchor:SetSize(300, 80)
        anchor:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -300, -200)

        if E and type(E.CreateMover) == "function" then
            E:CreateMover(anchor, "TwichUI_NotificationMover", "TwichUI Notifications", nil, nil, nil, "ALL")
        end

        self.anchor = anchor
    end

    self.Frame:Create()
end

local function GetSoundPathFromKey(key)
    local LSM = LibStub("LibSharedMedia-3.0")
    local path = LSM and LSM:Fetch("sound", key)
    return path
end

---@param event string the event name received
---@param widget AceGUIWidget the widget to display in the notification
---@param options NotificationOptions options for the notification
function NM:TWICH_NOTIFICATION(event, widget, options)
    local displayWidget = widget
    if options then
        if options.soundKey then
            local soundPath = GetSoundPathFromKey(options.soundKey)
            if soundPath then
                PlaySoundFile(soundPath, "Master")
            end
        end

        if options.wrap then
            local wrapper = AceGUI:Create("TwichUI_NotificationWrapper")
            wrapper:SetMessage(options.wrapMessage or "")
            wrapper:AddChild(widget)
            displayWidget = wrapper

            if options.wrapMessageOptions then
                local wrapMsgOpts = options.wrapMessageOptions
                if wrapMsgOpts.fontSize then
                    wrapper:SetFontSize(wrapMsgOpts.fontSize)
                end
            end
        end
    end

    self.Frame:DisplayNotification(displayWidget, options)
end

function NM:RefreshFrame()
    if self.Frame and self.Frame.Refresh then
        self.Frame:Refresh()
    end
end
