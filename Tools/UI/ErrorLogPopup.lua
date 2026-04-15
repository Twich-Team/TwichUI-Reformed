---@diagnostic disable: undefined-field, undefined-global
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class UISkins
local UI = Tools.UI or {}
Tools.UI = UI

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

local CLR_ACCENT = { 0.10, 0.79, 0.77 }
local CLR_WARN = { 0.98, 0.56, 0.50 }
local CLR_GOLD = { 0.98, 0.76, 0.22 }
local CLR_BG = { 0.04, 0.04, 0.06 }
local CLR_BG_PANEL = { 0.07, 0.07, 0.10 }

---@class TwichUIErrorLogPopup
---@field frame Frame|nil
---@field latestEntry table|nil
---@field pendingCount number
local ErrorLogPopup = UI.ErrorLogPopup or {}
UI.ErrorLogPopup = ErrorLogPopup
ErrorLogPopup.pendingCount = ErrorLogPopup.pendingCount or 0

local function Panel(parent, r, g, b, a, br, bg_, bb, ba)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(r or 0, g or 0, b or 0, a or 0.95)
    frame:SetBackdropBorderColor(br or 0, bg_ or 0, bb or 0, ba or 0.3)
    return frame
end

local function Button(parent, width, height, text, r, g, b)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(r * 0.20, g * 0.20, b * 0.20, 0.98)
    button:SetBackdropBorderColor(r, g, b, 0.4)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetAllPoints(button)
    label:SetText(text)
    label:SetTextColor(r, g, b)
    button.label = label

    button:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(r * 0.34, g * 0.34, b * 0.34, 1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self:SetBackdropColor(r * 0.20, g * 0.20, b * 0.20, 0.98)
    end)

    return button
end

function ErrorLogPopup:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = Panel(UIParent, CLR_BG[1], CLR_BG[2], CLR_BG[3], 0.98, CLR_GOLD[1], CLR_GOLD[2], CLR_GOLD[3], 0.30)
    frame:SetSize(420, 148)
    frame:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(90)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local header = Panel(frame, CLR_BG_PANEL[1], CLR_BG_PANEL[2], CLR_BG_PANEL[3], 0.98, 0, 0, 0, 0.15)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    header:SetHeight(38)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local stripe = header:CreateTexture(nil, "BORDER")
    stripe:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -1)
    stripe:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 1, 1)
    stripe:SetWidth(4)
    stripe:SetColorTexture(CLR_WARN[1], CLR_WARN[2], CLR_WARN[3], 1)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", header, "LEFT", 14, 0)
    title:SetJustifyH("LEFT")
    title:SetText("TwichUI Error Captured")
    title:SetTextColor(1, 0.95, 0.82)
    frame.title = title

    local count = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("RIGHT", header, "RIGHT", -12, 0)
    count:SetJustifyH("RIGHT")
    count:SetTextColor(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])
    frame.count = count

    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -12)
    summary:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -52)
    summary:SetJustifyH("LEFT")
    summary:SetJustifyV("TOP")
    summary:SetWordWrap(true)
    summary:SetTextColor(0.82, 0.88, 0.94)
    summary:SetText("")
    frame.summary = summary

    local openButton = Button(frame, 108, 28, "Open Log", CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])
    openButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    openButton:SetScript("OnClick", function()
        local viewer = Tools.UI and Tools.UI.ErrorLogViewer
        if viewer and type(viewer.Show) == "function" then
            viewer:Show()
        end
        ErrorLogPopup.pendingCount = 0
        frame:Hide()
    end)

    local dismissButton = Button(frame, 92, 28, "Dismiss", CLR_WARN[1], CLR_WARN[2], CLR_WARN[3])
    dismissButton:SetPoint("RIGHT", openButton, "LEFT", -8, 0)
    dismissButton:SetScript("OnClick", function()
        ErrorLogPopup.pendingCount = 0
        frame:Hide()
    end)

    frame:SetScript("OnHide", function()
        frame:SetAlpha(1)
    end)

    self.frame = frame
    return frame
end

function ErrorLogPopup:Refresh()
    local frame = self:EnsureFrame()
    local entry = self.latestEntry
    if not frame or not entry then
        return
    end

    frame.summary:SetText(entry.short or entry.detail or "Unknown error")
    if self.pendingCount > 1 then
        frame.count:SetText(self.pendingCount .. " new errors")
    else
        frame.count:SetText("New error")
    end
end

function ErrorLogPopup:NotifyNewError(entry)
    if not entry then
        return
    end

    self.latestEntry = entry
    self.pendingCount = (self.pendingCount or 0) + 1

    local frame = self:EnsureFrame()
    if not frame then
        return
    end

    self:Refresh()
    frame:Show()
end

function ErrorLogPopup:Hide()
    if self.frame then
        self.pendingCount = 0
        self.frame:Hide()
    end
end
