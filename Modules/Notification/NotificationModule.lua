--[[
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class NotificationModule : AceModule, AceEvent-3.0
---@field Frame NotificationFrame
local NM = T:NewModule("Notification", "AceEvent-3.0")
NM:SetEnabledState(true)

local AceGUI = LibStub("AceGUI-3.0")

local CreateFrame    = _G.CreateFrame
local UIParent       = _G.UIParent
local PlaySoundFile  = _G.PlaySoundFile

---@alias NotificationOptions { displayDuration: number|nil, soundKey: string|nil, wrap: boolean|nil, wrapMessage: string|nil, wrapMessageOptions: WrapperMessageOptions|nil }
---@alias WrapperMessageOptions { fontSize: number|nil }

local ANCHOR_HEIGHT   = 28
local ANCHOR_BORDER   = { 0.10, 0.72, 0.74, 0.90 }
local ANCHOR_BG       = { 0.04, 0.08, 0.10, 0.92 }
local ACCENT_COLOR    = "|cff1ab8bc"

function NM:GetOptions()
    local cfg = T:GetModule("Configuration")
    return cfg and cfg.Options and cfg.Options.NotificationPanel or nil
end

-- ── Anchor creation ───────────────────────────────────────────────────────

function NM:CreateAnchor()
    if self.anchor then return self.anchor end

    local anchor = CreateFrame("Frame", "TwichUI_NotificationAnchor", UIParent, "BackdropTemplate")
    local opts = self:GetOptions()
    local w = opts and opts.GetPanelWidth and opts:GetPanelWidth() or 300
    anchor:SetSize(w, ANCHOR_HEIGHT)
    anchor:SetMovable(true)
    anchor:SetClampedToScreen(true)
    anchor:RegisterForDrag("LeftButton")

    -- Visual chrome
    anchor:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    anchor:SetBackdropColor(ANCHOR_BG[1], ANCHOR_BG[2], ANCHOR_BG[3], ANCHOR_BG[4])
    anchor:SetBackdropBorderColor(ANCHOR_BORDER[1], ANCHOR_BORDER[2], ANCHOR_BORDER[3], ANCHOR_BORDER[4])

    local label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    label:SetText(ACCENT_COLOR .. "⠿|r  Notifications  " .. ACCENT_COLOR .. "⠿|r")
    label:SetTextColor(0.88, 0.88, 0.88, 1)
    anchor.Label = label

    anchor:SetScript("OnDragStart", function(selfAnchor)
        selfAnchor:StartMoving()
    end)

    anchor:SetScript("OnDragStop", function(selfAnchor)
        selfAnchor:StopMovingOrSizing()
        -- Persist position as CENTER offset from UIParent center.
        local ax, ay     = selfAnchor:GetCenter()
        local uiW, uiH   = UIParent:GetWidth(), UIParent:GetHeight()
        local offsetX    = ax - (uiW / 2)
        local offsetY    = ay - (uiH / 2)
        local o = NM:GetOptions()
        if o then
            o:SetAnchorX(nil, offsetX)
            o:SetAnchorY(nil, offsetY)
        end
    end)

    -- Position from DB
    self:ApplyAnchorPosition()

    -- Default hidden (locked); caller shows when unlocked
    anchor:SetMouseMotionEnabled(false)
    anchor:EnableMouse(false)
    anchor:Hide()

    self.anchor = anchor
    return anchor
end

-- ── Anchor state helpers ──────────────────────────────────────────────────

--- Move the anchor frame to the position currently stored in the DB.
function NM:ApplyAnchorPosition()
    if not self.anchor then return end
    local opts = self:GetOptions()
    local x = opts and opts.GetAnchorX and opts:GetAnchorX() or 300
    local y = opts and opts.GetAnchorY and opts:GetAnchorY() or -200
    self.anchor:ClearAllPoints()
    self.anchor:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

--- Show or hide the draggable visual and enable/disable mouse based on lock state.
function NM:ApplyAnchorLockState()
    if not self.anchor then return end
    local opts = self:GetOptions()
    local locked = not opts or opts:GetAnchorLocked()
    local dockMode = opts and opts.GetChatDockMode and opts:GetChatDockMode() or "none"

    -- Anchor is irrelevant (and must stay hidden) when docked to chat.
    if dockMode ~= "none" then
        self.anchor:EnableMouse(false)
        self.anchor:SetMouseMotionEnabled(false)
        self.anchor:Hide()
        return
    end

    if locked then
        self.anchor:EnableMouse(false)
        self.anchor:SetMouseMotionEnabled(false)
        self.anchor:Hide()
    else
        self.anchor:EnableMouse(true)
        self.anchor:SetMouseMotionEnabled(true)
        self.anchor:Show()
    end
end

-- ── Module lifecycle ──────────────────────────────────────────────────────

function NM:OnEnable()
    self:RegisterMessage("TWICH_NOTIFICATION")
    self:CreateAnchor()
    self:ApplyAnchorLockState()
    self.Frame:Create()
end

-- ── Helpers ───────────────────────────────────────────────────────────────

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
