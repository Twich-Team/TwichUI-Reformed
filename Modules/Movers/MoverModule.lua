---@diagnostic disable: undefined-field, undefined-global
--[[
    TwichUI Central Mover System

    Provides a unified, full-screen mover overlay — similar in spirit to ElvUI's
    unlock/move mode — where ALL registered movable elements can be repositioned
    simultaneously without visiting individual module configuration panels.

    Usage:
        /tui movers              — toggle mover mode on/off
        /tui movers on|off       — explicit toggle

    Registering elements (called by each module at init time):
        TwichMoverModule:RegisterMover(key, {
            label      = "Player Frame",       -- displayed on the mover handle
            category   = "Unit Frames",        -- grouping label in the overlay HUD
            getFrame   = function() ... end,   -- returns the live WoW frame (or nil)
            getX       = function() ... end,   -- returns current BOTTOMLEFT x
            getY       = function() ... end,   -- returns current BOTTOMLEFT y
            getW       = function() ... end,   -- returns frame width  (nil = not resizable)
            getH       = function() ... end,   -- returns frame height (nil = not resizable)
            setPos     = function(x, y) ... end,  -- called when position changes
            setSize    = function(w, h) ... end,  -- called when size changes (nil = fixed)
            isEnabled  = function() ... end,   -- true = show mover, false = hide
            -- optional extra controls shown in the inspector panel:
            extras     = {
                { label = "Enabled", type = "toggle",
                  get = function() ... end, set = function(v) ... end },
                { label = "Mouseover", type = "toggle",
                  get = function() ... end, set = function(v) ... end },
            },
        })
]]

local TwichRx                     = _G.TwichRx
---@type TwichUI
local T                           = unpack(TwichRx)

---@class TwichMoverModule : AceModule, AceEvent-3.0
---@field _snapLineH Frame|nil
---@field _snapLineV Frame|nil
local MoverModule                 = T:NewModule("Movers", "AceEvent-3.0")

_G.TwichMoverModule               = MoverModule

local CreateFrame                 = _G.CreateFrame
local UIParent                    = _G.UIParent
local InCombatLockdown            = _G.InCombatLockdown
local IsShiftKeyDown              = _G.IsShiftKeyDown
local C_Timer                     = _G.C_Timer
local math_floor                  = math.floor
local math_max                    = math.max
local math_min                    = math.min
local math_abs                    = math.abs

local DESIGNER_DOCK_WIDTH         = 360
local DESIGNER_DOCK_INSET         = 16
local DESIGNER_DOCK_CONTENT_WIDTH = DESIGNER_DOCK_WIDTH - (DESIGNER_DOCK_INSET * 2)

-- ── Snapping constants ───────────────────────────────────────────────────────
-- Frames snap when a dragged edge comes within SNAP_THRESHOLD px of a target.
-- Hold Shift while dragging to bypass snapping for pixel-perfect placement.
local SNAP_THRESHOLD              = 16

-- ── Colours (match the rest of TwichUI) ────────────────────────────────────
local C_ACCENT                    = { 0.10, 0.72, 0.74 } -- teal
local C_BG                        = { 0.05, 0.06, 0.09 }
local C_BORDER                    = { 0.10, 0.72, 0.74 }
local C_LABEL                     = { 0.55, 0.58, 0.68 }
local C_BTN_BG                    = { 0.09, 0.11, 0.15 }
local C_BTN_BD                    = { 0.20, 0.22, 0.30 }
local C_DOCK_BORDER               = { 0.32, 0.78, 0.96 }
local C_DOCK_GLOW                 = { 0.24, 0.62, 0.92 }
local C_DOCK_TEXT                 = { 0.70, 0.90, 0.98 }
local C_DOCK_PILL                 = { 0.11, 0.18, 0.24 }
local C_DOCK_PILL_TEXT            = { 0.58, 0.88, 1.00 }

-- ── Per-category tint colours ────────────────────────────────────────────────
-- Handles are tinted by category so the user can identify module groups at a glance.
local CATEGORY_COLORS             = {
    ["Unit Frames"] = { 0.32, 0.55, 0.98 }, -- blue
    ["Action Bars"] = { 0.98, 0.62, 0.22 }, -- orange
    ["Data Panels"] = { 0.32, 0.85, 0.45 }, -- green
    ["Chat"]        = { 0.82, 0.48, 0.95 }, -- purple
    ["Gathering"]   = { 0.95, 0.88, 0.28 }, -- yellow
    -- fallback: teal (C_ACCENT) for anything unrecognised
}

local OVERLAY_ALPHA               = 0.65 -- translucency of the full-screen backdrop

-- ── Registry ────────────────────────────────────────────────────────────────
MoverModule._registry             = MoverModule._registry or {} -- key → opts
MoverModule._handles              = MoverModule._handles or {} -- key → handle frame
MoverModule._hidden               = MoverModule._hidden or {} -- key → true  (temp-hidden)
MoverModule._active               = false

-- ── Font helper ─────────────────────────────────────────────────────────────
local function ResolveFont(size)
    local path  = _G.STANDARD_TEXT_FONT
    local LSM   = T.Libs and T.Libs.LSM
    local theme = T:GetModule("Theme", true)
    if LSM and theme then
        local name = theme.Get and theme:Get("globalFont")
        if name and name ~= "" and name ~= "__default" then
            local ok, fetched = pcall(LSM.Fetch, LSM, "font", name)
            if ok and type(fetched) == "string" and fetched ~= "" then
                path = fetched
            end
        end
    end
    return path, size or 11
end

local function GetFrameScreenRect(frame)
    if not frame then
        return 0, 0, 0, 0
    end

    local left = frame:GetLeft() or 0
    local bottom = frame:GetBottom() or 0
    local right = frame:GetRight() or (left + (frame:GetWidth() or 0))
    local top = frame:GetTop() or (bottom + (frame:GetHeight() or 0))

    return left, bottom, right, top
end

local function GetFrameScreenSize(frame, minWidth, minHeight)
    local left, bottom, right, top = GetFrameScreenRect(frame)
    local width = right - left
    local height = top - bottom

    if width <= 0 then
        width = frame and frame.GetWidth and frame:GetWidth() or minWidth or 0
    end
    if height <= 0 then
        height = frame and frame.GetHeight and frame:GetHeight() or minHeight or 0
    end

    return math_max(minWidth or 0, width), math_max(minHeight or 0, height)
end

local function RoundPixel(value)
    return math_floor((tonumber(value) or 0) + 0.5)
end

local function SetFont(widget, size)
    local p, s = ResolveFont(size)
    widget:SetFont(p, s, "")
end

-- ── Backdrop helper ─────────────────────────────────────────────────────────
local PLAIN_BACKDROP = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function ApplyBackdrop(frame, r, g, b, a, br, bg, bb, ba)
    frame:SetBackdrop(PLAIN_BACKDROP)
    frame:SetBackdropColor(r, g, b, a or 1)
    frame:SetBackdropBorderColor(br, bg, bb, ba or 1)
end

-- ── Registration API ────────────────────────────────────────────────────────

---@param key string  Unique key for this mover (e.g. "UF_player", "AB_bar1")
---@param opts table  See module header for required/optional fields
function MoverModule:RegisterMover(key, opts)
    if type(key) ~= "string" or type(opts) ~= "table" then return end
    self._registry[key] = opts
    -- If movers are already active, create the handle immediately.
    if self._active then
        self:_EnsureHandle(key)
        self:_PositionHandle(key)
    end
end

function MoverModule:UnregisterMover(key)
    self._registry[key] = nil
    local h = self._handles[key]
    if h then h:Hide() end
    self._handles[key] = nil
end

-- ── Anchor coordinate conversion ────────────────────────────────────────────
-- Converts a BOTTOMLEFT absolute position (blX, blY) to an equivalent offset
-- relative to any of the nine standard UIParent anchor points.  fw/fh are the
-- frame's rendered width and height at the time of conversion.
function MoverModule:_ConvertFromBL(blX, blY, targetPoint, fw, fh)
    local sw = UIParent:GetWidth() or 1280
    local sh = UIParent:GetHeight() or 768
    fw       = fw or 0; fh = fh or 0
    local L  = blX
    local B  = blY
    local R  = blX + fw
    local T_ = blY + fh
    local CX = blX + fw / 2
    local CY = blY + fh / 2
    if targetPoint == "BOTTOMLEFT" then
        return math_floor(L + 0.5), math_floor(B + 0.5)
    elseif targetPoint == "BOTTOM" then
        return math_floor(CX - sw / 2 + 0.5), math_floor(B + 0.5)
    elseif targetPoint == "BOTTOMRIGHT" then
        return math_floor(R - sw + 0.5), math_floor(B + 0.5)
    elseif targetPoint == "LEFT" then
        return math_floor(L + 0.5), math_floor(CY - sh / 2 + 0.5)
    elseif targetPoint == "CENTER" then
        return math_floor(CX - sw / 2 + 0.5), math_floor(CY - sh / 2 + 0.5)
    elseif targetPoint == "RIGHT" then
        return math_floor(R - sw + 0.5), math_floor(CY - sh / 2 + 0.5)
    elseif targetPoint == "TOPLEFT" then
        return math_floor(L + 0.5), math_floor(T_ - sh + 0.5)
    elseif targetPoint == "TOP" then
        return math_floor(CX - sw / 2 + 0.5), math_floor(T_ - sh + 0.5)
    elseif targetPoint == "TOPRIGHT" then
        return math_floor(R - sw + 0.5), math_floor(T_ - sh + 0.5)
    else
        return math_floor(L + 0.5), math_floor(B + 0.5)
    end
end

-- ── Inspector singleton ─────────────────────────────────────────────────────
-- One shared inspector panel that follows the most recently clicked mover.

function MoverModule:_GetInspector()
    if self._inspector then return self._inspector end

    local panel = CreateFrame("Frame", "TwichUICentralMoverInspector", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(9999)
    panel:SetClampedToScreen(true)
    ApplyBackdrop(panel, C_BG[1], C_BG[2], C_BG[3], 0.97,
        C_BORDER[1], C_BORDER[2], C_BORDER[3], 1)
    panel:EnableMouse(true)
    panel:Hide()
    panel._dockOverrides = {}
    panel._activeDockSide = "RIGHT"

    local dock = CreateFrame("Frame", "TwichUIInterfaceDesignerDock", UIParent, "BackdropTemplate")
    dock:SetFrameStrata("TOOLTIP")
    dock:SetFrameLevel(9998)
    dock:SetClampedToScreen(true)
    dock:SetWidth(DESIGNER_DOCK_WIDTH)
    dock:EnableMouse(true)
    dock:Hide()
    ApplyBackdrop(dock, 0.05, 0.055, 0.07, 0.985, C_DOCK_BORDER[1], C_DOCK_BORDER[2], C_DOCK_BORDER[3], 1)
    panel._dock = dock

    local dockInner = CreateFrame("Frame", nil, dock, "BackdropTemplate")
    dockInner:SetPoint("TOPLEFT", dock, "TOPLEFT", 1, -1)
    dockInner:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", -1, 1)
    ApplyBackdrop(dockInner, 0.05, 0.035, 0.025, 0.82, 0.27, 0.16, 0.09, 0.55)

    -- Hide on click-outside via overlay script (see _BuildOverlay)
    panel._activeKey = nil

    local function CancelHide()
    end
    local function ScheduleHide()
    end
    panel.CancelHide   = CancelHide
    panel.ScheduleHide = ScheduleHide
    panel:SetScript("OnEnter", CancelHide)
    panel:SetScript("OnLeave", ScheduleHide)
    panel:SetScript("OnHide", function(self)
        if self._dock then
            self._dock:Hide()
        end
        self._dockSessionSide = nil
        self._activeKey = nil
    end)

    local dockHeaderFrame = CreateFrame("Frame", nil, dock, "BackdropTemplate")
    dockHeaderFrame:SetPoint("TOPLEFT", dock, "TOPLEFT", 6, -6)
    dockHeaderFrame:SetPoint("TOPRIGHT", dock, "TOPRIGHT", -6, -6)
    dockHeaderFrame:SetHeight(78)
    ApplyBackdrop(dockHeaderFrame, 0.07, 0.10, 0.14, 0.98, C_DOCK_BORDER[1], C_DOCK_BORDER[2], C_DOCK_BORDER[3], 0.72)
    dockHeaderFrame:SetFrameLevel(dock:GetFrameLevel() + 2)

    local dockHeaderContent = CreateFrame("Frame", nil, dockHeaderFrame)
    dockHeaderContent:SetAllPoints(dockHeaderFrame)
    dockHeaderContent:SetFrameLevel(dockHeaderFrame:GetFrameLevel() + 3)

    local dockHeader = dockHeaderFrame:CreateTexture(nil, "ARTWORK")
    dockHeader:SetPoint("TOPLEFT", dockHeaderFrame, "TOPLEFT", 1, -1)
    dockHeader:SetPoint("TOPRIGHT", dockHeaderFrame, "TOPRIGHT", -1, -1)
    dockHeader:SetHeight(75)
    dockHeader:SetColorTexture(0.08, 0.12, 0.16, 0.96)

    local dockHeaderGlow = dockHeaderFrame:CreateTexture(nil, "ARTWORK")
    dockHeaderGlow:SetPoint("TOPLEFT", dockHeaderFrame, "TOPLEFT", 1, -1)
    dockHeaderGlow:SetPoint("TOPRIGHT", dockHeaderFrame, "TOPRIGHT", -1, -1)
    dockHeaderGlow:SetHeight(22)
    dockHeaderGlow:SetColorTexture(C_DOCK_GLOW[1], C_DOCK_GLOW[2], C_DOCK_GLOW[3], 0.10)

    local dockHeaderBottom = dockHeaderFrame:CreateTexture(nil, "BORDER")
    dockHeaderBottom:SetHeight(1)
    dockHeaderBottom:SetPoint("BOTTOMLEFT", dockHeaderFrame, "BOTTOMLEFT", 10, 0)
    dockHeaderBottom:SetPoint("BOTTOMRIGHT", dockHeaderFrame, "BOTTOMRIGHT", -10, 0)
    dockHeaderBottom:SetColorTexture(C_DOCK_BORDER[1], C_DOCK_BORDER[2], C_DOCK_BORDER[3], 0.55)

    local dockGlow = dock:CreateTexture(nil, "BACKGROUND")
    dockGlow:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, -76)
    dockGlow:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, -76)
    dockGlow:SetHeight(140)
    dockGlow:SetColorTexture(C_DOCK_GLOW[1], C_DOCK_GLOW[2], C_DOCK_GLOW[3], 0.08)

    local dockSpotlight = dock:CreateTexture(nil, "BACKGROUND")
    dockSpotlight:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, -76)
    dockSpotlight:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, -76)
    dockSpotlight:SetHeight(220)
    dockSpotlight:SetColorTexture(C_DOCK_TEXT[1], C_DOCK_TEXT[2], C_DOCK_TEXT[3], 0.03)

    local dockAccent = dock:CreateTexture(nil, "BORDER")
    dockAccent:SetWidth(5)
    dockAccent:SetPoint("TOP", dock, "TOP", 0, 0)
    dockAccent:SetPoint("BOTTOM", dock, "BOTTOM", 0, 0)
    dockAccent:SetColorTexture(C_DOCK_BORDER[1], C_DOCK_BORDER[2], C_DOCK_BORDER[3], 0.95)
    dock._accent = dockAccent

    local dockBadge = dockHeaderContent:CreateFontString(nil, "OVERLAY")
    dockBadge:SetPoint("TOPLEFT", dockHeaderContent, "TOPLEFT", 12, -10)
    dockBadge:SetPoint("TOPRIGHT", dockHeaderContent, "TOPRIGHT", -100, -10)
    dockBadge:SetJustifyH("LEFT")
    SetFont(dockBadge, 9)
    dockBadge:SetText("DESIGNER DOCK")
    dockBadge:SetTextColor(C_DOCK_TEXT[1], C_DOCK_TEXT[2], C_DOCK_TEXT[3])

    local dockPill = dockHeaderContent:CreateTexture(nil, "ARTWORK")
    dockPill:SetPoint("TOPLEFT", dockHeaderContent, "TOPLEFT", 12, -24)
    dockPill:SetSize(74, 14)
    dockPill:SetColorTexture(C_DOCK_PILL[1], C_DOCK_PILL[2], C_DOCK_PILL[3], 0.92)

    local dockPillText = dockHeaderContent:CreateFontString(nil, "OVERLAY")
    dockPillText:SetPoint("CENTER", dockPill, "CENTER", 0, 0)
    SetFont(dockPillText, 8)
    dockPillText:SetText("SELECTED")
    dockPillText:SetTextColor(C_DOCK_PILL_TEXT[1], C_DOCK_PILL_TEXT[2], C_DOCK_PILL_TEXT[3])

    local dockTitle = dockHeaderContent:CreateFontString(nil, "OVERLAY")
    dockTitle:SetPoint("TOPLEFT", dockHeaderContent, "TOPLEFT", 12, -42)
    dockTitle:SetPoint("TOPRIGHT", dockHeaderContent, "TOPRIGHT", -108, -42)
    dockTitle:SetJustifyH("LEFT")
    SetFont(dockTitle, 13)
    dockTitle:SetTextColor(0.96, 0.92, 0.86)
    dock._title = dockTitle

    local dockSubtitle = dockHeaderContent:CreateFontString(nil, "OVERLAY")
    dockSubtitle:SetPoint("TOPLEFT", dockHeaderContent, "TOPLEFT", 12, -59)
    dockSubtitle:SetPoint("TOPRIGHT", dockHeaderContent, "TOPRIGHT", -108, -59)
    dockSubtitle:SetJustifyH("LEFT")
    SetFont(dockSubtitle, 9)
    dockSubtitle:SetTextColor(0.64, 0.76, 0.84)
    dock._subtitle = dockSubtitle

    local dockStatusDot = dockHeaderContent:CreateTexture(nil, "OVERLAY")
    dockStatusDot:SetPoint("TOPRIGHT", dockHeaderContent, "TOPRIGHT", -90, -36)
    dockStatusDot:SetSize(6, 6)
    dockStatusDot:SetColorTexture(0.14, 0.84, 0.78, 1)

    local dockStatusText = dockHeaderContent:CreateFontString(nil, "OVERLAY")
    dockStatusText:SetPoint("LEFT", dockStatusDot, "RIGHT", 6, 0)
    dockStatusText:SetPoint("RIGHT", dockHeaderContent, "RIGHT", -12, -36)
    dockStatusText:SetJustifyH("RIGHT")
    SetFont(dockStatusText, 8)
    dockStatusText:SetText("LIVE CONTROLS")
    dockStatusText:SetTextColor(C_DOCK_TEXT[1], C_DOCK_TEXT[2], C_DOCK_TEXT[3])

    local dockBtn = CreateFrame("Button", nil, dockHeaderContent, "BackdropTemplate")
    dockBtn:SetSize(74, 20)
    dockBtn:SetPoint("TOPRIGHT", dockHeaderContent, "TOPRIGHT", -10, -10)
    dockBtn:SetFrameStrata(dockHeaderFrame:GetFrameStrata())
    dockBtn:SetFrameLevel(dockHeaderContent:GetFrameLevel() + 4)
    ApplyBackdrop(dockBtn, C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1,
        C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
    local dockBtnFS = dockBtn:CreateFontString(nil, "OVERLAY")
    dockBtnFS:SetAllPoints(dockBtn)
    dockBtnFS:SetJustifyH("CENTER")
    dockBtnFS:SetJustifyV("MIDDLE")
    SetFont(dockBtnFS, 10)
    dockBtnFS:SetText("Dock Left")
    dockBtn._fs = dockBtnFS
    dockBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.22)
        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
    end)
    dockBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1)
        self:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
    end)
    dock._dockBtn = dockBtn

    local dockDivider = dock:CreateTexture(nil, "ARTWORK")
    dockDivider:SetHeight(1)
    dockDivider:SetPoint("TOPLEFT", dock, "TOPLEFT", DESIGNER_DOCK_INSET, -100)
    dockDivider:SetPoint("TOPRIGHT", dock, "TOPRIGHT", -DESIGNER_DOCK_INSET, -100)
    dockDivider:SetColorTexture(C_DOCK_BORDER[1], C_DOCK_BORDER[2], C_DOCK_BORDER[3], 0.40)

    local dockTopEdge = dock:CreateTexture(nil, "BORDER")
    dockTopEdge:SetTexture("Interface\\Buttons\\WHITE8x8")
    dockTopEdge:SetHeight(1)
    dockTopEdge:SetVertexColor(C_DOCK_BORDER[1], C_DOCK_BORDER[2], C_DOCK_BORDER[3], 0.65)
    dock._topEdge = dockTopEdge

    local dockBottomEdge = dock:CreateTexture(nil, "BORDER")
    dockBottomEdge:SetTexture("Interface\\Buttons\\WHITE8x8")
    dockBottomEdge:SetHeight(1)
    dockBottomEdge:SetVertexColor(C_DOCK_BORDER[1], C_DOCK_BORDER[2], C_DOCK_BORDER[3], 0.45)
    dock._bottomEdge = dockBottomEdge

    local function StyleDockSide(side)
        dockAccent:ClearAllPoints()
        dockTopEdge:ClearAllPoints()
        dockBottomEdge:ClearAllPoints()

        if side == "LEFT" then
            dockAccent:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0)
            dockAccent:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
            dockTopEdge:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
            dockTopEdge:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0)
            dockBottomEdge:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
            dockBottomEdge:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
        else
            dockAccent:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
            dockAccent:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
            dockTopEdge:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
            dockTopEdge:SetPoint("TOPRIGHT", dock, "TOPRIGHT", 0, 0)
            dockBottomEdge:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
            dockBottomEdge:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
        end
    end

    -- ── Shared widget builders ───────────────────────────────────────────
    panel._editBoxes = {}

    local function MakeFS(text, xOff, yOff, size, r, g, b)
        local fs = panel:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", xOff, yOff)
        SetFont(fs, size or 10)
        fs:SetText(text)
        fs:SetTextColor(r or C_LABEL[1], g or C_LABEL[2], b or C_LABEL[3])
        return fs
    end

    local function MakeEB(xOff, yOff, w, h)
        local eb = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
        eb:SetSize(w or 72, h or 20)
        eb:SetPoint("TOPLEFT", panel, "TOPLEFT", xOff, yOff)
        ApplyBackdrop(eb, 0.04, 0.05, 0.08, 1, 0.20, 0.22, 0.30, 1)
        eb:SetTextInsets(5, 5, 2, 2)
        eb:SetMaxLetters(7)
        eb:SetAutoFocus(false)
        SetFont(eb, 10)
        eb:SetTextColor(1, 1, 1)
        eb:SetJustifyH("RIGHT")
        eb:EnableMouse(true)
        eb:SetScript("OnEnter", CancelHide)
        eb:SetScript("OnLeave", ScheduleHide)
        eb:SetScript("OnEditFocusGained", CancelHide)
        panel._editBoxes[#panel._editBoxes + 1] = eb
        return eb
    end

    local function MakeDiv(yOff, alpha)
        local d = panel:CreateTexture(nil, "ARTWORK")
        d:SetHeight(1)
        d:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, yOff)
        d:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, yOff)
        d:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], alpha or 0.35)
        return d
    end

    local function MakeBtn(label, xOff, yOff, w, h, onClick)
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(w or 80, h or 20)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", xOff, yOff)
        ApplyBackdrop(btn, C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1,
            C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        SetFont(fs, 10)
        fs:SetText(label)
        btn._fs = fs
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.22)
            self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
            CancelHide()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1)
            self:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
            ScheduleHide()
        end)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local function ResolveExtraNumeric(value, fallback)
        if type(value) == "function" then
            value = value()
        end

        value = tonumber(value)
        if value == nil then
            return fallback
        end

        return value
    end

    local function ResolveExtraDisabled(extra)
        return type(extra.disabled) == "function" and extra.disabled() == true
    end

    local function FormatExtraValue(extra, value)
        if type(extra.format) == "function" then
            return tostring(extra.format(value))
        end

        local step = ResolveExtraNumeric(extra.step, 1)
        if step >= 1 then
            return tostring(math_floor((tonumber(value) or 0) + 0.5))
        end

        return string.format("%.2f", tonumber(value) or 0)
    end

    local function StyleExtraState(frame, enabled)
        if not frame or not frame.SetBackdropColor then
            return
        end

        if enabled then
            frame:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1)
            frame:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
            if frame._fs and frame._fs.SetTextColor then
                frame._fs:SetTextColor(0.92, 0.94, 0.96)
            end
            if frame.SetTextColor then
                frame:SetTextColor(0.92, 0.94, 0.96)
            end
        else
            frame:SetBackdropColor(0.03, 0.03, 0.05, 0.9)
            frame:SetBackdropBorderColor(0.12, 0.13, 0.18, 0.9)
            if frame._fs and frame._fs.SetTextColor then
                frame._fs:SetTextColor(0.46, 0.48, 0.56)
            end
            if frame.SetTextColor then
                frame:SetTextColor(0.46, 0.48, 0.56)
            end
        end
    end

    -- ── Title row ────────────────────────────────────────────────────────
    local W = 282
    panel:SetWidth(W)

    local badgeFS = MakeFS("POSITION", 8, -8, 9, C_ACCENT[1], C_ACCENT[2], C_ACCENT[3])
    badgeFS:SetTextColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3])
    panel.badgeFS = badgeFS

    local titleFS = MakeFS("", 8, -24, 12, 0.96, 0.92, 0.86)
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -24)
    titleFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -88, -24)
    titleFS:SetJustifyH("LEFT")
    panel.titleFS = titleFS

    local subtitleFS = MakeFS("", 8, -39, 9, 0.78, 0.64, 0.52)
    subtitleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -39)
    subtitleFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -88, -39)
    subtitleFS:SetJustifyH("LEFT")
    panel.subtitleFS = subtitleFS

    local dockBtn = MakeBtn("Dock Left", W - 78, -18, 70, 18, function()
        local key = panel._activeKey
        if not key then
            return
        end
        local current = panel._activeDockSide == "LEFT" and "LEFT" or "RIGHT"
        panel._dockOverrides[key] = current == "LEFT" and "RIGHT" or "LEFT"
        panel.Activate(key, MoverModule._handles[key])
    end)
    panel.dockBtn = dockBtn
    panel.dockBtn:Hide()

    local hintFS = MakeFS("Shift=10px", W - 8, -40, 8, 0.50, 0.44, 0.40)
    hintFS:ClearAllPoints()
    hintFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -40)
    hintFS:SetJustifyH("RIGHT")

    MakeDiv(-54)

    -- ── X / Y row ────────────────────────────────────────────────────────
    MakeFS("X", 8, -67, 10)
    MakeFS("Y", W / 2 + 4, -67, 10)
    local xBox = MakeEB(19, -62, W / 2 - 22)
    local yBox = MakeEB(W / 2 + 15, -62, W / 2 - 18)
    panel.xBox = xBox
    panel.yBox = yBox

    MakeDiv(-87, 0.18)

    -- ── W / H row ────────────────────────────────────────────────────────
    MakeFS("W", 8, -95, 10)
    MakeFS("H", W / 2 + 4, -95, 10)
    local wBox = MakeEB(19, -90, W / 2 - 22)
    local hBox = MakeEB(W / 2 + 15, -90, W / 2 - 18)
    panel.wBox = wBox
    panel.hBox = hBox

    MakeDiv(-115, 0.18)

    -- ── Nudge buttons (arrow cross) ──────────────────────────────────────
    local S, G = 20, 3
    local CX = W / 2

    local function MakeNudge(label, dx, dy)
        local btn = CreateFrame("Button", nil, panel, "BackdropTemplate")
        btn:SetSize(S, S)
        ApplyBackdrop(btn, C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1,
            C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetAllPoints(btn); fs:SetJustifyH("CENTER"); fs:SetJustifyV("MIDDLE")
        SetFont(fs, 11); fs:SetText(label)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.22)
            self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
            CancelHide()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1)
            self:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
            ScheduleHide()
        end)
        btn:SetScript("OnClick", function()
            if not panel._activeKey or InCombatLockdown() then return end
            local step = IsShiftKeyDown() and 10 or 1
            local cx = tonumber(xBox:GetText()) or 0
            local cy = tonumber(yBox:GetText()) or 0
            panel._applyPos(cx + dx * step, cy + dy * step)
        end)
        return btn
    end

    local r1y = -123
    local btnU = MakeNudge("\226\134\145", 0, 1)
    local btnL = MakeNudge("\226\134\144", -1, 0)
    local btnR = MakeNudge("\226\134\146", 1, 0)
    local btnD = MakeNudge("\226\134\147", 0, -1)
    btnU:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2, r1y)
    btnL:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2 - S - G, r1y - S - G)
    btnR:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2 + S + G, r1y - S - G)
    btnD:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2, r1y - 2 * (S + G))
    local ctr = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    ctr:SetSize(S, S)
    ctr:SetPoint("TOPLEFT", panel, "TOPLEFT", CX - S / 2, r1y - S - G)
    ctr:EnableMouse(false)
    ApplyBackdrop(ctr, 0.05, 0.06, 0.09, 0.7, 0.15, 0.17, 0.22, 0.6)
    local ctrFS = ctr:CreateFontString(nil, "OVERLAY")
    ctrFS:SetAllPoints(ctr); ctrFS:SetJustifyH("CENTER"); ctrFS:SetJustifyV("MIDDLE")
    SetFont(ctrFS, 8); ctrFS:SetText("XY"); ctrFS:SetTextColor(0.38, 0.40, 0.50)

    MakeDiv(-123 - 3 * (S + G) - 4, 0.18)

    -- ── Anchor picker (3×3 grid) ──────────────────────────────────────────
    -- Shows which anchor is active; clicking any cell converts and saves the anchor.
    local anchorSectionY = -123 - 3 * (S + G) - 14

    local anchorHdrFS = panel:CreateFontString(nil, "OVERLAY")
    anchorHdrFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, anchorSectionY)
    anchorHdrFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, anchorSectionY)
    SetFont(anchorHdrFS, 9)
    anchorHdrFS:SetJustifyH("CENTER")
    anchorHdrFS:SetText("Anchor")
    anchorHdrFS:SetTextColor(C_LABEL[1], C_LABEL[2], C_LABEL[3])

    local ANCHOR_GRID = {
        { "TOPLEFT", "TL" }, { "TOP", "T" }, { "TOPRIGHT", "TR" },
        { "LEFT",    "L" }, { "CENTER", "C" }, { "RIGHT", "R" },
        { "BOTTOMLEFT", "BL" }, { "BOTTOM", "B" }, { "BOTTOMRIGHT", "BR" },
    }
    -- 3 buttons span the full usable panel width (8px padding each side)
    local BW, BH, BG  = math_floor((W - 16 - 2 * 2) / 3), 18, 2
    local gridStartY  = anchorSectionY - 12
    panel._anchorBtns = {}

    for i, ag in ipairs(ANCHOR_GRID) do
        local gPoint, gLabel = ag[1], ag[2]
        local col            = (i - 1) % 3
        local row            = math_floor((i - 1) / 3)
        local bx             = 8 + col * (BW + BG)
        local by             = gridStartY - row * (BH + BG)

        local abtn           = CreateFrame("Button", nil, panel, "BackdropTemplate")
        abtn:SetSize(BW, BH)
        abtn:SetPoint("TOPLEFT", panel, "TOPLEFT", bx, by)
        ApplyBackdrop(abtn, C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1,
            C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
        local abtnFS = abtn:CreateFontString(nil, "OVERLAY")
        abtnFS:SetAllPoints(abtn)
        abtnFS:SetJustifyH("CENTER")
        abtnFS:SetJustifyV("MIDDLE")
        SetFont(abtnFS, 9)
        abtnFS:SetText(gLabel)
        abtnFS:SetTextColor(0.70, 0.72, 0.82)
        abtn._fs     = abtnFS
        abtn._pt     = gPoint
        abtn._active = false

        abtn:SetScript("OnEnter", function(self)
            if not self._active then
                self:SetBackdropColor(C_ACCENT[1] * 0.18, C_ACCENT[2] * 0.18, C_ACCENT[3] * 0.18, 0.7)
                self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.65)
            end
            CancelHide()
        end)
        abtn:SetScript("OnLeave", function(self)
            if not self._active then
                self:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1)
                self:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
            end
            ScheduleHide()
        end)
        abtn:SetScript("OnClick", function(self)
            if not panel._activeKey or InCombatLockdown() then return end
            local opts = MoverModule._registry[panel._activeKey]
            if not opts then return end
            -- Use handle's current absolute BOTTOMLEFT position for coordinate conversion
            local hndl     = MoverModule._handles[panel._activeKey]
            local blX      = type(opts.getX) == "function" and opts.getX() or 0
            local blY      = type(opts.getY) == "function" and opts.getY() or 0
            local hfw, hfh = 0, 0
            if hndl then
                blX, blY = GetFrameScreenRect(hndl)
                hfw, hfh = GetFrameScreenSize(hndl, 0, 0)
            end
            local nx, ny = MoverModule:_ConvertFromBL(blX, blY, self._pt, hfw, hfh)
            if type(opts.setAnchor) == "function" then
                opts.setAnchor(self._pt, nx, ny)
            elseif type(opts.setPos) == "function" then
                opts.setPos(blX, blY) -- no anchor support: at least commit position
            end
            C_Timer.After(0, function()
                panel.RefreshBoxes()
                MoverModule:_PositionHandle(panel._activeKey)
            end)
        end)

        panel._anchorBtns[gPoint] = abtn
    end

    -- Compute grid bottom so we can place the divider + hide button dynamically
    local gridBottomY = gridStartY - (3 * BH + 2 * BG)
    MakeDiv(gridBottomY - 4, 0.18)

    -- ── Hide-toggle button ───────────────────────────────────────────────
    local hideY = gridBottomY - 14
    local hideBtn = MakeBtn("Hide Mover", 8, hideY, W - 16, 20, function()
        local key = panel._activeKey
        if not key then return end
        MoverModule._hidden[key] = not MoverModule._hidden[key] or nil
        MoverModule:_RefreshHandleVisibility(key)
        panel:Hide()
    end)
    panel.hideBtn = hideBtn

    -- ── Extra controls placeholder (rebuilt on Show) ─────────────────────
    dock._extrasContainer = CreateFrame("Frame", nil, dock)
    dock._extrasContainer:SetPoint("TOPLEFT", dock, "TOPLEFT", DESIGNER_DOCK_INSET, -118)
    dock._extrasContainer:SetPoint("TOPRIGHT", dock, "TOPRIGHT", -DESIGNER_DOCK_INSET, -118)
    dock._extrasContainer:SetHeight(0)
    dock._extrasContainer:Hide()

    -- Dynamic height is recalculated in panel.Activate().
    panel._baseHeight = math_abs(hideY) + 20 + 8 -- extra margin below hide btn

    -- ── Logic ────────────────────────────────────────────────────────────
    local function RefreshBoxes()
        local key  = panel._activeKey
        local opts = key and MoverModule._registry[key]
        if not opts then return end
        local x = type(opts.getX) == "function" and opts.getX() or 0
        local y = type(opts.getY) == "function" and opts.getY() or 0
        xBox:SetText(tostring(math_floor(x + 0.5)))
        yBox:SetText(tostring(math_floor(y + 0.5)))
        xBox:SetCursorPosition(0); yBox:SetCursorPosition(0)
        local w = type(opts.getW) == "function" and opts.getW() or nil
        local h = type(opts.getH) == "function" and opts.getH() or nil
        local canW = type(opts.setSize) == "function" and w ~= nil
        local canH = type(opts.setSize) == "function" and h ~= nil
        if canW then
            wBox:SetText(tostring(math_floor(w + 0.5)))
            ApplyBackdrop(wBox, 0.04, 0.05, 0.08, 1, 0.20, 0.22, 0.30, 1)
        else
            wBox:SetText("—")
            ApplyBackdrop(wBox, 0.03, 0.03, 0.05, 1, 0.12, 0.13, 0.18, 1)
        end
        if canH then
            hBox:SetText(tostring(math_floor(h + 0.5)))
            ApplyBackdrop(hBox, 0.04, 0.05, 0.08, 1, 0.20, 0.22, 0.30, 1)
        else
            hBox:SetText("—")
            ApplyBackdrop(hBox, 0.03, 0.03, 0.05, 1, 0.12, 0.13, 0.18, 1)
        end
        wBox:SetCursorPosition(0); hBox:SetCursorPosition(0)
        wBox:SetEnabled(canW); hBox:SetEnabled(canH)
        -- Anchor grid: highlight the current anchor and dim cells when setAnchor unavailable
        if panel._anchorBtns then
            local curPt   = type(opts.getPoint) == "function" and opts.getPoint() or "BOTTOMLEFT"
            local hasAnch = type(opts.setAnchor) == "function"
            for pt, abtn in pairs(panel._anchorBtns) do
                abtn._active = (pt == curPt)
                abtn:EnableMouse(hasAnch or type(opts.setPos) == "function")
                if abtn._active then
                    ApplyBackdrop(abtn,
                        C_ACCENT[1] * 0.20, C_ACCENT[2] * 0.20, C_ACCENT[3] * 0.20, 0.85,
                        C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
                    abtn._fs:SetTextColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3])
                else
                    local a = hasAnch and 1 or 0.40
                    ApplyBackdrop(abtn,
                        C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], a,
                        C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], a)
                    abtn._fs:SetTextColor(0.70, 0.72, 0.82, a)
                end
            end
        end
    end
    panel.RefreshBoxes = RefreshBoxes

    local function ApplyPos(x, y)
        if not panel._activeKey or InCombatLockdown() then return end
        local opts = MoverModule._registry[panel._activeKey]
        if not opts or type(opts.setPos) ~= "function" then return end
        local nx, ny = math_floor((tonumber(x) or 0) + 0.5), math_floor((tonumber(y) or 0) + 0.5)
        opts.setPos(nx, ny)
        xBox:SetText(tostring(nx)); yBox:SetText(tostring(ny))
        xBox:SetCursorPosition(0); yBox:SetCursorPosition(0)
        -- Reposition the handle to match
        MoverModule:_PositionHandle(panel._activeKey)
    end
    panel._applyPos = ApplyPos

    local function ApplySize(w, h)
        if not panel._activeKey or InCombatLockdown() then return end
        local opts = MoverModule._registry[panel._activeKey]
        if not opts or type(opts.setSize) ~= "function" then return end
        local nw = math_max(20, math_floor((tonumber(w) or 20) + 0.5))
        local nh = math_max(4, math_floor((tonumber(h) or 4) + 0.5))
        opts.setSize(nw, nh)
        wBox:SetText(tostring(nw)); hBox:SetText(tostring(nh))
        wBox:SetCursorPosition(0); hBox:SetCursorPosition(0)
        MoverModule:_PositionHandle(panel._activeKey)
    end

    -- EditBox scripts
    xBox:SetScript("OnEnterPressed",
        function(eb)
            ApplyPos(eb:GetText(), tonumber(yBox:GetText()) or 0); eb:ClearFocus()
        end)
    xBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes(); eb:ClearFocus()
    end)
    yBox:SetScript("OnEnterPressed",
        function(eb)
            ApplyPos(tonumber(xBox:GetText()) or 0, eb:GetText()); eb:ClearFocus()
        end)
    yBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes(); eb:ClearFocus()
    end)
    wBox:SetScript("OnEnterPressed",
        function(eb)
            ApplySize(eb:GetText(), tonumber(hBox:GetText()) or 0); eb:ClearFocus()
        end)
    wBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes(); eb:ClearFocus()
    end)
    hBox:SetScript("OnEnterPressed",
        function(eb)
            ApplySize(tonumber(wBox:GetText()) or 0, eb:GetText()); eb:ClearFocus()
        end)
    hBox:SetScript("OnEscapePressed", function(eb)
        RefreshBoxes(); eb:ClearFocus()
    end)

    -- ── Activate for a given key ─────────────────────────────────────────
    function panel.Activate(key, anchorHandle)
        local opts = MoverModule._registry[key]
        if not opts then
            panel:Hide(); return
        end
        panel._activeKey = key
        panel.titleFS:SetText(opts.label or key)
        panel.subtitleFS:SetText(opts.category or "Designer Control")

        -- Rebuild extra controls in dock
        local ec = dock._extrasContainer
        -- Remove any previous extra children by hiding them
        if ec._extraWidgets then
            for _, w in ipairs(ec._extraWidgets) do w:Hide() end
        end
        ec._extraWidgets = {}
        ec:Hide()
        dock:Hide()

        local extraH = 0
        local extras = opts.extras
        if type(extras) == "table" and #extras > 0 then
            ec:Show()
            dock._title:SetText(opts.label or key)
            dock._subtitle:SetText(opts.category or "Designer Control")
            local curY = -4
            local function QueueRefresh()
                C_Timer.After(0, function()
                    if panel._activeKey == key then
                        panel.Activate(key, MoverModule._handles[key] or anchorHandle)
                    end
                    MoverModule:_PositionHandle(key)
                end)
            end

            local function MakeExtraBtn(parent, text, xOff, yOff, width, height, onClick)
                local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
                btn:SetSize(width or 80, height or 20)
                btn:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, yOff)
                ApplyBackdrop(btn, C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1,
                    C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
                local fs = btn:CreateFontString(nil, "OVERLAY")
                fs:SetAllPoints(btn)
                fs:SetJustifyH("CENTER")
                fs:SetJustifyV("MIDDLE")
                SetFont(fs, 10)
                fs:SetText(text or "")
                btn._fs = fs
                btn:SetScript("OnEnter", function(self)
                    if self:IsEnabled() then
                        self:SetBackdropColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.22)
                        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
                    end
                    CancelHide()
                end)
                btn:SetScript("OnLeave", function(self)
                    StyleExtraState(self, self:IsEnabled())
                    ScheduleHide()
                end)
                btn:SetScript("OnClick", onClick)
                return btn
            end

            for _, extra in ipairs(extras) do
                local hidden = type(extra.hidden) == "function" and extra.hidden() == true
                if not hidden and extra.type == "toggle" then
                    local cur = type(extra.get) == "function" and extra.get() or false
                    local lbl = ec:CreateFontString(nil, "OVERLAY")
                    lbl:SetPoint("TOPLEFT", ec, "TOPLEFT", 8, curY)
                    SetFont(lbl, 10)
                    lbl:SetText(extra.label or "")
                    lbl:SetTextColor(C_LABEL[1], C_LABEL[2], C_LABEL[3])
                    ec._extraWidgets[#ec._extraWidgets + 1] = lbl

                    local chk = CreateFrame("Button", nil, ec, "BackdropTemplate")
                    chk:SetSize(14, 14)
                    chk:SetPoint("TOPRIGHT", ec, "TOPRIGHT", -8, curY - 2)
                    ApplyBackdrop(chk, 0.04, 0.05, 0.08, 1, 0.20, 0.22, 0.30, 1)
                    local dot = chk:CreateTexture(nil, "OVERLAY")
                    dot:SetAllPoints(chk)
                    dot:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
                    dot:SetShown(cur)
                    chk._dot = dot
                    chk._extra = extra
                    chk:SetScript("OnClick", function(self)
                        if ResolveExtraDisabled(self._extra) then
                            return
                        end
                        local nv = not (type(self._extra.get) == "function" and self._extra.get() or false)
                        if type(self._extra.set) == "function" then self._extra.set(nv) end
                        self._dot:SetShown(nv)
                        QueueRefresh()
                    end)
                    chk:SetScript("OnEnter", CancelHide)
                    chk:SetScript("OnLeave", ScheduleHide)
                    chk:SetEnabled(not ResolveExtraDisabled(extra))
                    StyleExtraState(chk, chk:IsEnabled())
                    ec._extraWidgets[#ec._extraWidgets + 1] = chk

                    curY = curY - 22
                    extraH = extraH + 22
                elseif not hidden and extra.type == "execute" then
                    local btn = MakeExtraBtn(ec, extra.buttonLabel or extra.label or "Action", 0, curY,
                        DESIGNER_DOCK_CONTENT_WIDTH, 22,
                        function()
                            if ResolveExtraDisabled(extra) then
                                return
                            end
                            if type(extra.func) == "function" then
                                extra.func()
                                QueueRefresh()
                            end
                        end)
                    btn:SetEnabled(not ResolveExtraDisabled(extra))
                    StyleExtraState(btn, btn:IsEnabled())
                    ec._extraWidgets[#ec._extraWidgets + 1] = btn

                    curY = curY - 24
                    extraH = extraH + 24
                elseif not hidden and extra.type == "range" then
                    local lbl = ec:CreateFontString(nil, "OVERLAY")
                    lbl:SetPoint("TOPLEFT", ec, "TOPLEFT", 0, curY)
                    lbl:SetPoint("TOPRIGHT", ec, "TOPRIGHT", 0, curY)
                    SetFont(lbl, 10)
                    lbl:SetText(extra.label or "")
                    lbl:SetTextColor(C_LABEL[1], C_LABEL[2], C_LABEL[3])
                    ec._extraWidgets[#ec._extraWidgets + 1] = lbl

                    local disabled = ResolveExtraDisabled(extra)
                    local currentValue = type(extra.get) == "function" and extra.get() or
                    ResolveExtraNumeric(extra.min, 0)
                    local rowY = curY - 14
                    local minus = MakeExtraBtn(ec, "-", 0, rowY, 24, 18, function()
                        if ResolveExtraDisabled(extra) then
                            return
                        end
                        local current = tonumber(type(extra.get) == "function" and extra.get() or 0) or 0
                        local step = ResolveExtraNumeric(extra.step, 1)
                        local minimum = ResolveExtraNumeric(extra.min, current)
                        local maximum = ResolveExtraNumeric(extra.max, current)
                        local factor = IsShiftKeyDown() and 10 or 1
                        local nextValue = math.max(minimum, math.min(maximum, current - (step * factor)))
                        if type(extra.set) == "function" then
                            extra.set(nextValue)
                            QueueRefresh()
                        end
                    end)
                    local plus = MakeExtraBtn(ec, "+", DESIGNER_DOCK_CONTENT_WIDTH - 24, rowY, 24, 18, function()
                        if ResolveExtraDisabled(extra) then
                            return
                        end
                        local current = tonumber(type(extra.get) == "function" and extra.get() or 0) or 0
                        local step = ResolveExtraNumeric(extra.step, 1)
                        local minimum = ResolveExtraNumeric(extra.min, current)
                        local maximum = ResolveExtraNumeric(extra.max, current)
                        local factor = IsShiftKeyDown() and 10 or 1
                        local nextValue = math.max(minimum, math.min(maximum, current + (step * factor)))
                        if type(extra.set) == "function" then
                            extra.set(nextValue)
                            QueueRefresh()
                        end
                    end)
                    local valueBox = CreateFrame("EditBox", nil, ec, "BackdropTemplate")
                    valueBox:SetSize(DESIGNER_DOCK_CONTENT_WIDTH - 56, 18)
                    valueBox:SetPoint("TOPLEFT", ec, "TOPLEFT", 28, rowY)
                    ApplyBackdrop(valueBox, 0.04, 0.05, 0.08, 1, 0.20, 0.22, 0.30, 1)
                    valueBox:SetTextInsets(5, 5, 2, 2)
                    valueBox:SetAutoFocus(false)
                    valueBox:SetMaxLetters(8)
                    valueBox:SetJustifyH("CENTER")
                    SetFont(valueBox, 10)
                    valueBox:SetText(FormatExtraValue(extra, currentValue))
                    valueBox:SetScript("OnEnter", CancelHide)
                    valueBox:SetScript("OnLeave", ScheduleHide)
                    valueBox:SetScript("OnEditFocusGained", function(self)
                        CancelHide()
                        self:HighlightText()
                    end)
                    valueBox:SetScript("OnEscapePressed", function(self)
                        local refreshedValue = type(extra.get) == "function" and extra.get() or
                        ResolveExtraNumeric(extra.min, 0)
                        self:SetText(FormatExtraValue(extra, refreshedValue))
                        self:HighlightText(0, 0)
                        self:ClearFocus()
                    end)
                    valueBox:SetScript("OnEnterPressed", function(self)
                        if ResolveExtraDisabled(extra) then
                            local refreshedValue = type(extra.get) == "function" and extra.get() or
                            ResolveExtraNumeric(extra.min, 0)
                            self:SetText(FormatExtraValue(extra, refreshedValue))
                            self:ClearFocus()
                            return
                        end

                        local entered = tonumber(self:GetText())
                        local current = tonumber(type(extra.get) == "function" and extra.get() or 0) or 0
                        local minimum = ResolveExtraNumeric(extra.min, current)
                        local maximum = ResolveExtraNumeric(extra.max, current)
                        local nextValue = entered or current
                        nextValue = math.max(minimum, math.min(maximum, nextValue))

                        if type(extra.set) == "function" then
                            extra.set(nextValue)
                        end

                        self:SetText(FormatExtraValue(extra, nextValue))
                        self:HighlightText(0, 0)
                        self:ClearFocus()
                        QueueRefresh()
                    end)

                    minus:SetEnabled(not disabled)
                    plus:SetEnabled(not disabled)
                    valueBox:SetEnabled(not disabled)
                    StyleExtraState(minus, minus:IsEnabled())
                    StyleExtraState(plus, plus:IsEnabled())
                    StyleExtraState(valueBox, valueBox:IsEnabled())

                    ec._extraWidgets[#ec._extraWidgets + 1] = minus
                    ec._extraWidgets[#ec._extraWidgets + 1] = plus
                    ec._extraWidgets[#ec._extraWidgets + 1] = valueBox

                    curY = curY - 38
                    extraH = extraH + 38
                elseif not hidden and extra.type == "label" then
                    local lbl = ec:CreateFontString(nil, "OVERLAY")
                    lbl:SetPoint("TOPLEFT", ec, "TOPLEFT", 0, curY)
                    lbl:SetPoint("TOPRIGHT", ec, "TOPRIGHT", 0, curY)
                    lbl:SetJustifyH("LEFT")
                    lbl:SetJustifyV("TOP")
                    SetFont(lbl, 9)
                    lbl:SetText(extra.text or extra.label or "")
                    lbl:SetTextColor(0.62, 0.66, 0.74)
                    ec._extraWidgets[#ec._extraWidgets + 1] = lbl

                    curY = curY - 18
                    extraH = extraH + 18
                end
            end
            ec:SetHeight(extraH + 4)
        end

        panel:SetHeight(panel._baseHeight)

        RefreshBoxes()

        local function GetDockSide()
            if panel._dockSessionSide == "LEFT" or panel._dockSessionSide == "RIGHT" then
                return panel._dockSessionSide
            end

            if anchorHandle then
                local left, _, right = GetFrameScreenRect(anchorHandle)
                local centerX = ((left or 0) + (right or left or 0)) * 0.5
                local screenMid = (UIParent:GetWidth() or 1280) * 0.5
                if centerX < screenMid then
                    return "RIGHT"
                end
            end

            return "LEFT"
        end

        local dockSide = GetDockSide()
        panel._dockSessionSide = dockSide
        panel._activeDockSide = dockSide
        dock._dockBtn._fs:SetText(dockSide == "LEFT" and "Dock Right" or "Dock Left")
        dock._dockBtn:SetScript("OnClick", function()
            panel._dockSessionSide = dockSide == "LEFT" and "RIGHT" or "LEFT"
            panel.Activate(key, MoverModule._handles[key] or anchorHandle)
        end)
        StyleDockSide(dockSide)

        panel:ClearAllPoints()
        if anchorHandle then
            local sw = UIParent:GetWidth() or 1280
            local sh = UIParent:GetHeight() or 768
            local hT = anchorHandle:GetTop() or 0
            if hT > sh * 0.6 then
                panel:SetPoint("TOP", anchorHandle, "BOTTOM", 0, -6)
            else
                panel:SetPoint("BOTTOM", anchorHandle, "TOP", 0, 6)
            end
            C_Timer.After(0, function()
                local pl = panel:GetLeft() or 0
                local pr = panel:GetRight() or sw
                if pl < 4 then
                    panel:SetPoint("LEFT", UIParent, "LEFT", 4, 0)
                elseif pr > sw - 4 then
                    panel:SetPoint("RIGHT", UIParent, "RIGHT", -4, 0)
                end
            end)
        else
            panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end

        if type(extras) == "table" and #extras > 0 then
            local dockHeight = math.floor(math_max(420, math_min((UIParent:GetHeight() or 768) * 0.72, 760)) + 0.5)
            dock:SetHeight(dockHeight)
            dock:ClearAllPoints()
            if dockSide == "LEFT" then
                dock:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -42)
            else
                dock:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, -42)
            end
            dock:Show()
        end
        panel:Show()
        panel:SetFrameLevel(9999)
    end

    self._inspector = panel
    return panel
end

-- ── Handle creation & positioning ───────────────────────────────────────────

-- ── Snap guide lines ─────────────────────────────────────────────────────────
-- Two full-screen 1-px lines (H + V) that appear at snap targets during drag.

local function GetOrCreateSnapLines()
    local self = MoverModule
    if not self._snapLineH then
        local lh = CreateFrame("Frame", "TwichUIMoverSnapLineH", UIParent)
        lh:SetFrameStrata("TOOLTIP")
        lh:SetFrameLevel(500)
        lh:SetHeight(1)
        local t = lh:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(lh)
        t:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.80)
        lh:Hide()
        self._snapLineH = lh
    end
    if not self._snapLineV then
        local lv = CreateFrame("Frame", "TwichUIMoverSnapLineV", UIParent)
        lv:SetFrameStrata("TOOLTIP")
        lv:SetFrameLevel(500)
        lv:SetWidth(1)
        local t = lv:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(lv)
        t:SetColorTexture(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.80)
        lv:Hide()
        self._snapLineV = lv
    end
    return self._snapLineH, self._snapLineV
end

function MoverModule:_ShowSnapLines(snapX, snapY)
    local lh, lv = GetOrCreateSnapLines()
    if not lh or not lv then
        return
    end

    if snapY then
        lh:ClearAllPoints()
        lh:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, snapY)
        lh:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, snapY)
        lh:Show()
    else
        lh:Hide()
    end
    if snapX then
        lv:ClearAllPoints()
        lv:SetPoint("TOP", UIParent, "TOPLEFT", snapX, 0)
        lv:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", snapX, 0)
        lv:Show()
    else
        lv:Hide()
    end
end

function MoverModule:_HideSnapLines()
    if self._snapLineH then self._snapLineH:Hide() end
    if self._snapLineV then self._snapLineV:Hide() end
end

-- ── Snap computation ──────────────────────────────────────────────────────────
-- Returns snappedBlX, snappedBlY, guideLineX, guideLineY, snapModeX, snapModeY.
-- guideLineX/Y are screen-space positions for snap guide lines (nil = no snap on that axis).
-- Hold Shift during drag to bypass snap entirely.

function MoverModule:_SnapPosition(dragKey, rawBlX, rawBlY, fw, fh)
    if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then
        return rawBlX, rawBlY, nil, nil
    end

    local sw     = RoundPixel(UIParent:GetWidth() or 1280)
    local sh     = RoundPixel(UIParent:GetHeight() or 768)
    fw           = RoundPixel(fw)
    fh           = RoundPixel(fh)
    rawBlX       = RoundPixel(rawBlX)
    rawBlY       = RoundPixel(rawBlY)

    -- Edges of the dragged frame at the raw (un-snapped) BOTTOMLEFT.
    local L      = rawBlX
    local R      = rawBlX + fw
    local B      = rawBlY
    local T      = rawBlY + fh
    local CX     = rawBlX + fw * 0.5
    local CY     = rawBlY + fh * 0.5

    -- ── X-axis candidates  { targetBlX, guideLine_X_screen } ────────────────
    local xCands = {
        { L = 0,                   line = 0,        mode = "left" },   -- frame L → screen L
        { L = sw - fw,             line = sw,       mode = "right" },  -- frame R → screen R
        { L = sw * 0.5 - fw * 0.5, line = sw * 0.5, mode = "center" }, -- frame CX → screen CX
    }
    -- snap against every other visible handle
    for otherKey, oh in pairs(self._handles) do
        if otherKey ~= dragKey and oh:IsShown() then
            local oL = RoundPixel(oh:GetLeft() or 0)
            local oR = RoundPixel(oh:GetRight() or (oL + 80))
            local oCX = (oL + oR) * 0.5
            xCands[#xCands + 1] = { L = oL, line = oL, mode = "left" }                -- L-edge align
            xCands[#xCands + 1] = { L = oR - fw, line = oR, mode = "right" }          -- R-edge align
            xCands[#xCands + 1] = { L = oR, line = oR, mode = "left" }                -- frame L sticks to other R
            xCands[#xCands + 1] = { L = oL - fw, line = oL, mode = "right" }          -- frame R sticks to other L
            xCands[#xCands + 1] = { L = oCX - fw * 0.5, line = oCX, mode = "center" } -- centre-X align
        end
    end

    -- ── Y-axis candidates  { targetBlY, guideLine_Y_screen } ────────────────
    local yCands = {
        { B = 0,                   line = 0,        mode = "bottom" }, -- frame B → screen B
        { B = sh - fh,             line = sh,       mode = "top" },    -- frame T → screen T
        { B = sh * 0.5 - fh * 0.5, line = sh * 0.5, mode = "center" }, -- frame CY → screen CY
    }
    for otherKey, oh in pairs(self._handles) do
        if otherKey ~= dragKey and oh:IsShown() then
            local oB = RoundPixel(oh:GetBottom() or 0)
            local oT = RoundPixel(oh:GetTop() or (oB + 24))
            local oCY = (oB + oT) * 0.5
            yCands[#yCands + 1] = { B = oB, line = oB, mode = "bottom" }              -- B-edge align
            yCands[#yCands + 1] = { B = oT - fh, line = oT, mode = "top" }            -- T-edge align
            yCands[#yCands + 1] = { B = oT, line = oT, mode = "bottom" }              -- frame B sticks to other T
            yCands[#yCands + 1] = { B = oB - fh, line = oB, mode = "top" }            -- frame T sticks to other B
            yCands[#yCands + 1] = { B = oCY - fh * 0.5, line = oCY, mode = "center" } -- centre-Y align
        end
    end

    -- Find best X snap within threshold
    local bestX, bestXLine, bestXMode = rawBlX, nil, nil
    local bestXDist = SNAP_THRESHOLD + 1
    for _, c in ipairs(xCands) do
        local d = math_abs(L - c.L)
        if d < bestXDist then
            bestXDist = d
            bestX     = math_floor(c.L + 0.5)
            bestXLine = math_floor(c.line + 0.5)
            bestXMode = c.mode
        end
    end

    -- Find best Y snap within threshold
    local bestY, bestYLine, bestYMode = rawBlY, nil, nil
    local bestYDist = SNAP_THRESHOLD + 1
    for _, c in ipairs(yCands) do
        local d = math_abs(B - c.B)
        if d < bestYDist then
            bestYDist = d
            bestY     = math_floor(c.B + 0.5)
            bestYLine = math_floor(c.line + 0.5)
            bestYMode = c.mode
        end
    end

    return bestX, bestY, bestXLine, bestYLine, bestXMode, bestYMode
end

local function BuildHandleLabel(opts)
    return opts and opts.label or "?"
end

function MoverModule:_EnsureHandle(key)
    if self._handles[key] then return self._handles[key] end
    local opts = self._registry[key]
    if not opts then return end

    local h = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    h:SetFrameStrata("TOOLTIP")
    h:SetFrameLevel(300)
    h:SetMovable(true)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetClampedToScreen(true)

    -- Tint handle with category colour so the user can identify module groups at a glance
    local catCol = CATEGORY_COLORS[opts.category or ""] or C_ACCENT
    h._catColor  = catCol
    ApplyBackdrop(h, catCol[1] * 0.15, catCol[2] * 0.15, catCol[3] * 0.15, 0.78,
        catCol[1], catCol[2], catCol[3], 0.9)

    -- Label
    local lbl = h:CreateFontString(nil, "OVERLAY")
    lbl:SetAllPoints(h)
    lbl:SetJustifyH("CENTER")
    lbl:SetJustifyV("MIDDLE")
    SetFont(lbl, 11)
    lbl:SetText(BuildHandleLabel(opts))
    lbl:SetTextColor(1, 0.95, 0.85)
    h._label = lbl

    -- Category sub-label
    local cat = h:CreateFontString(nil, "OVERLAY")
    cat:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 4, 3)
    cat:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -4, 3)
    cat:SetJustifyH("LEFT")
    cat:SetJustifyV("BOTTOM")
    SetFont(cat, 8)
    cat:SetText(opts.category or "")
    cat:SetTextColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.7)
    h._cat = cat

    -- Right-click tooltip hint
    local hint = h:CreateFontString(nil, "OVERLAY")
    hint:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -4, 3)
    hint:SetJustifyH("RIGHT")
    hint:SetJustifyV("BOTTOM")
    SetFont(hint, 8)
    hint:SetText("RClick: hide")
    hint:SetTextColor(0.45, 0.47, 0.56, 0.85)
    h._hint = hint

    h._key = key

    -- Store original position on drag start
    h:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        -- Collapse the live-frame attachment to a single BOTTOMLEFT anchor while
        -- preserving the handle's rendered screen-space size. Logical GetWidth/
        -- GetHeight are not reliable once the source frame is scaled.
        local blX, blY = GetFrameScreenRect(self)
        local vw, vh = GetFrameScreenSize(self, 40, 16)
        blX = math_floor(blX + 0.5)
        blY = math_floor(blY + 0.5)
        vw = math_floor(vw + 0.5)
        vh = math_floor(vh + 0.5)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", blX, blY)
        self:SetSize(math_max(40, vw), math_max(16, vh))
        self:StartMoving()
        self._dragging = true
        -- Live snap-line preview: show guide lines as the frame approaches snap targets.
        self:SetScript("OnUpdate", function(dragFrame)
            if not dragFrame._dragging then return end
            local rX, rY = GetFrameScreenRect(dragFrame)
            local rW, rH = GetFrameScreenSize(dragFrame, 40, 16)
            local _, _, snapX, snapY = MoverModule:_SnapPosition(key, rX, rY, rW, rH)
            MoverModule:_ShowSnapLines(snapX, snapY)
        end)
        local inspector = MoverModule._inspector
        if inspector and inspector._activeKey == key then
            inspector:Hide()
        end
    end)

    h:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._dragging = false
        self:SetScript("OnUpdate", nil) -- stop live-snap preview

        -- Compute snapped BOTTOMLEFT position and reposition handle before saving.
        local rawX, rawY = GetFrameScreenRect(self)
        local fw, fh = GetFrameScreenSize(self, 40, 16)
        local blX, blY, snapLineX, snapLineY, snapModeX, snapModeY = MoverModule:_SnapPosition(key, rawX, rawY, fw, fh)
        MoverModule:_HideSnapLines()

        -- Commit handle to its final (snapped) screen position.
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", blX, blY)

        local o = MoverModule._registry[key]
        local function FinalizeDrag()
            MoverModule:_PositionHandle(key)
            local insp = MoverModule:_GetInspector()
            insp.Activate(key, self)
        end

        local function GetAxisDrift()
            local left, bottom, right, top = GetFrameScreenRect(self)
            left = RoundPixel(left)
            bottom = RoundPixel(bottom)
            right = RoundPixel(right)
            top = RoundPixel(top)

            local driftX = 0
            local driftY = 0

            if snapLineX and snapModeX == "left" then
                driftX = snapLineX - left
            elseif snapLineX and snapModeX == "right" then
                driftX = snapLineX - right
            elseif snapLineX and snapModeX == "center" then
                driftX = snapLineX - RoundPixel((left + right) * 0.5)
            end

            if snapLineY and snapModeY == "bottom" then
                driftY = snapLineY - bottom
            elseif snapLineY and snapModeY == "top" then
                driftY = snapLineY - top
            elseif snapLineY and snapModeY == "center" then
                driftY = snapLineY - RoundPixel((bottom + top) * 0.5)
            end

            return driftX, driftY
        end

        local function CorrectSnapEdges(targetX, targetY, attempt)
            C_Timer.After(0, function()
                MoverModule:_PositionHandle(key)

                local driftX, driftY = GetAxisDrift()

                if (math_abs(driftX) > 0 or math_abs(driftY) > 0) and (attempt or 1) < 2 and o and type(o.setPos) == "function" then
                    o.setPos(targetX + driftX, targetY + driftY)
                    CorrectSnapEdges(targetX + driftX, targetY + driftY, (attempt or 1) + 1)
                    return
                end

                FinalizeDrag()
            end)
        end

        if o then
            if type(o.setAnchor) == "function" then
                -- Preserve whatever anchor is currently stored: convert the snapped
                -- BOTTOMLEFT screen position back to an offset relative to that anchor.
                local curPt  = type(o.getPoint) == "function" and o.getPoint() or "BOTTOMLEFT"
                local nx, ny = MoverModule:_ConvertFromBL(blX, blY, curPt, fw, fh)
                o.setAnchor(curPt, nx, ny)
                FinalizeDrag()
                return
            elseif type(o.setPos) == "function" then
                o.setPos(blX, blY)
                CorrectSnapEdges(blX, blY, 1)
                return
            end
        end

        FinalizeDrag()
    end)

    -- Left-click: open inspector
    h:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not self._dragging then
            local insp = MoverModule:_GetInspector()
            insp.Activate(key, self)
        end
    end)

    -- Right-click: temporarily hide this mover
    h:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            MoverModule._hidden[key] = true
            self:Hide()
            -- Close inspector if it's showing this mover
            local insp = MoverModule._inspector
            if insp and insp._activeKey == key then insp:Hide() end
        end
    end)

    h:SetScript("OnEnter", function(self)
        local insp = MoverModule._inspector
        if insp then insp.CancelHide() end
        -- Highlight using the category colour
        local cc = self._catColor or C_ACCENT
        self:SetBackdropColor(cc[1] * 0.28, cc[2] * 0.28, cc[3] * 0.28, 0.9)
        self:SetBackdropBorderColor(cc[1], cc[2], cc[3], 1)
    end)
    h:SetScript("OnLeave", function(self)
        local cc = self._catColor or C_ACCENT
        self:SetBackdropColor(cc[1] * 0.15, cc[2] * 0.15, cc[3] * 0.15, 0.78)
        self:SetBackdropBorderColor(cc[1], cc[2], cc[3], 0.9)
    end)

    h:Hide()
    self._handles[key] = h
    return h
end

function MoverModule:_PositionHandle(key)
    local h = self._handles[key]
    local opts = self._registry[key]
    if not h or not opts then return end

    local enabled = type(opts.isEnabled) ~= "function" or opts.isEnabled() ~= false
    if not enabled then
        h:Hide(); return
    end

    -- ── Live-frame path ─────────────────────────────────────────────────────
    -- Anchor the handle directly to the live frame using two opposing corners.
    -- WoW's layout engine resolves all coordinate-space and scale conversions
    -- internally, so this is correct regardless of SetScale(), anchor type, or
    -- button count.  GetLeft()/GetWidth() are NOT used here because they return
    -- values in the frame's own (pre-scale) coordinate space which diverges from
    -- UIParent space whenever the frame has a non-1 scale.
    if type(opts.getFrame) == "function" then
        local liveFrame = opts.getFrame()
        if liveFrame and liveFrame.IsShown and liveFrame:IsShown() then
            local liveWidth, liveHeight = GetFrameScreenSize(liveFrame, 0, 0)
            if liveWidth > 4 and liveHeight > 4 then
                h:ClearAllPoints()
                h:SetPoint("BOTTOMLEFT", liveFrame, "BOTTOMLEFT", 0, 0)
                h:SetPoint("TOPRIGHT", liveFrame, "TOPRIGHT", 0, 0)
                if h._label then h._label:SetText(BuildHandleLabel(opts)) end
                if h._cat then h._cat:SetText(opts.category or "") end
                local insp = self._inspector
                if insp and insp._activeKey == key and insp:IsShown() then
                    insp.RefreshBoxes()
                end
                return
            end
        end
    end

    -- ── Fallback: frame hidden / not yet shown ───────────────────────────────
    -- Use DB position + logical dimensions (best-effort; scale not applied).
    local x  = type(opts.getX) == "function" and opts.getX() or 0
    local y  = type(opts.getY) == "function" and opts.getY() or 0
    local w  = type(opts.getW) == "function" and opts.getW() or nil
    local hh = type(opts.getH) == "function" and opts.getH() or nil
    local fw = math_max(40, w or 80)
    local fh = math_max(16, hh or 24)
    if type(opts.getFrame) == "function" then
        local liveFrame = opts.getFrame()
        if liveFrame and liveFrame.GetWidth and liveFrame.GetHeight then
            local lw = liveFrame:GetWidth()
            local lh = liveFrame:GetHeight()
            if lw and lw > 4 then fw = lw end
            if lh and lh > 4 then fh = math_max(16, lh) end
        end
    end

    local point    = type(opts.getPoint) == "function" and opts.getPoint() or "BOTTOMLEFT"
    local relPoint = type(opts.getRelativePoint) == "function" and opts.getRelativePoint() or point
    h:ClearAllPoints()
    h:SetPoint(point, UIParent, relPoint, x, y)
    h:SetSize(fw, fh)

    if h._label then h._label:SetText(BuildHandleLabel(opts)) end
    if h._cat then h._cat:SetText(opts.category or "") end

    -- Update inspector boxes if this handle is currently active
    local insp = self._inspector
    if insp and insp._activeKey == key and insp:IsShown() then
        insp.RefreshBoxes()
    end
end

function MoverModule:_RefreshHandleVisibility(key)
    local h = self._handles[key]
    if not h then return end
    local hidden = self._hidden[key] == true
    if hidden then
        h:Hide()
    else
        self:_PositionHandle(key)
        if self._active then h:Show() end
    end
end

-- ── Overlay (full-screen dim + HUD bar) ─────────────────────────────────────

function MoverModule:_BuildOverlay()
    if self._overlay then return self._overlay end

    -- Full-screen backdrop
    local ov = CreateFrame("Frame", "TwichUIMoverOverlay", UIParent, "BackdropTemplate")
    ov:SetAllPoints(UIParent)
    ov:SetFrameStrata("HIGH")
    ov:SetFrameLevel(200)
    ApplyBackdrop(ov, 0, 0, 0, OVERLAY_ALPHA, 0, 0, 0, 0)
    ov:EnableMouse(true) -- Blocks clicks to game world, passes to handles above
    ov:Hide()

    -- Click on overlay (behind handles) dismisses the inspector
    ov:SetScript("OnMouseDown", function()
        local insp = self._inspector
        if insp and insp:IsShown() then insp:Hide() end
    end)

    -- ── HUD bar at top ───────────────────────────────────────────────────
    local hud = CreateFrame("Frame", "TwichUIMoverHUD", UIParent, "BackdropTemplate")
    hud:SetFrameStrata("TOOLTIP")
    hud:SetFrameLevel(500)
    hud:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    hud:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    hud:SetHeight(36)
    ApplyBackdrop(hud, 0.04, 0.05, 0.08, 0.97, C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.9)
    hud:EnableMouse(true)
    hud:Hide()

    -- Title text
    local hudTitle = hud:CreateFontString(nil, "OVERLAY")
    hudTitle:SetPoint("LEFT", hud, "LEFT", 16, 0)
    SetFont(hudTitle, 13)
    hudTitle:SetText("|cff19c9c7TwichUI|r  Interface Designer")
    hudTitle:SetTextColor(0.92, 0.94, 0.96)

    -- Instruction text
    local hudHint = hud:CreateFontString(nil, "OVERLAY")
    hudHint:SetPoint("CENTER", hud, "CENTER", 0, 0)
    SetFont(hudHint, 10)
    hudHint:SetText(
        "Drag to reposition · snaps to edges & other frames · |cffffcc00Shift|r: bypass snap · Left-click: inspector · Right-click: hide")
    hudHint:SetTextColor(0.55, 0.58, 0.68)

    -- Show Hidden button (reveals all temp-hidden)
    local showAllBtn = CreateFrame("Button", nil, hud, "BackdropTemplate")
    showAllBtn:SetSize(110, 22)
    showAllBtn:SetPoint("RIGHT", hud, "RIGHT", -120, 0)
    ApplyBackdrop(showAllBtn, C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1,
        C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
    local showAllFS = showAllBtn:CreateFontString(nil, "OVERLAY")
    showAllFS:SetAllPoints(showAllBtn); showAllFS:SetJustifyH("CENTER"); showAllFS:SetJustifyV("MIDDLE")
    SetFont(showAllFS, 10); showAllFS:SetText("Show All Movers")
    showAllBtn:SetScript("OnClick", function()
        -- Un-hide all temporarily hidden movers
        for key in pairs(self._hidden) do
            self._hidden[key] = nil
        end
        for key in pairs(self._registry) do
            self:_RefreshHandleVisibility(key)
        end
    end)
    showAllBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 0.22)
        self:SetBackdropBorderColor(C_ACCENT[1], C_ACCENT[2], C_ACCENT[3], 1)
    end)
    showAllBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(C_BTN_BG[1], C_BTN_BG[2], C_BTN_BG[3], 1)
        self:SetBackdropBorderColor(C_BTN_BD[1], C_BTN_BD[2], C_BTN_BD[3], 1)
    end)

    -- Exit button
    local exitBtn = CreateFrame("Button", nil, hud, "BackdropTemplate")
    exitBtn:SetSize(80, 22)
    exitBtn:SetPoint("RIGHT", hud, "RIGHT", -12, 0)
    ApplyBackdrop(exitBtn, 0.35, 0.08, 0.08, 1, 0.75, 0.20, 0.20, 1)
    local exitFS = exitBtn:CreateFontString(nil, "OVERLAY")
    exitFS:SetAllPoints(exitBtn); exitFS:SetJustifyH("CENTER"); exitFS:SetJustifyV("MIDDLE")
    SetFont(exitFS, 11); exitFS:SetText("Exit  [Esc]")
    exitBtn:SetScript("OnClick", function() MoverModule:Deactivate() end)
    exitBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.55, 0.12, 0.12, 1)
        self:SetBackdropBorderColor(0.90, 0.30, 0.30, 1)
    end)
    exitBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.35, 0.08, 0.08, 1)
        self:SetBackdropBorderColor(0.75, 0.20, 0.20, 1)
    end)

    -- ESC key closes mover mode
    ov:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then MoverModule:Deactivate() end
    end)
    ov:SetPropagateKeyboardInput(false)

    hud._showAllBtn = showAllBtn
    self._overlay   = ov
    self._hud       = hud
    return ov
end

-- ── Activate / Deactivate ────────────────────────────────────────────────────

function MoverModule:Activate()
    if InCombatLockdown() then
        print("|cff19c9c7[TwichUI]|r Cannot enter Interface Designer in combat.")
        return
    end

    -- Remember whether the config UI was open so we can restore it on exit.
    self._configWasOpen = false
    local cfg = T:GetModule("Configuration", true)
    if cfg and cfg.StandaloneUI and type(cfg.StandaloneUI.GetFrame) == "function" then
        local cfgFrame = cfg.StandaloneUI:GetFrame()
        if cfgFrame and cfgFrame.IsShown and cfgFrame:IsShown() then
            self._configWasOpen = true
        end
    end

    self._active = true
    self:_BuildOverlay()
    self._overlay:Show()
    self._hud:Show()

    -- Ensure handles exist and are positioned
    for key in pairs(self._registry) do
        self:_EnsureHandle(key)
        if not self._hidden[key] then
            self:_PositionHandle(key)
            local h = self._handles[key]
            local opts = self._registry[key]
            local enabled = type(opts.isEnabled) ~= "function" or opts.isEnabled() ~= false
            if h and enabled then h:Show() end
        end
    end

    print(
        "|cff19c9c7[TwichUI]|r Interface Designer active — drag handles or click for quick controls. |cffff6060ESC|r or Exit button to close.")
end

function MoverModule:Deactivate()
    self._active = false

    -- Hide all handles
    for _, h in pairs(self._handles) do
        if h then
            h:SetScript("OnUpdate", nil)
            h:Hide()
        end
    end

    -- Hide snap guide lines
    self:_HideSnapLines()

    -- Hide inspector
    if self._inspector then self._inspector:Hide() end

    -- Hide overlay / HUD
    if self._overlay then self._overlay:Hide() end
    if self._hud then self._hud:Hide() end

    print("|cff19c9c7[TwichUI]|r Interface Designer closed.")

    -- Re-open config UI if it was visible when Move Mode started.
    if self._configWasOpen then
        self._configWasOpen = false
        local cfg = T:GetModule("Configuration", true)
        if cfg and type(cfg.OpenOptionsUI) == "function" then
            C_Timer.After(0, function() cfg:OpenOptionsUI() end)
        end
    end
end

function MoverModule:Toggle()
    if self._toggleLocked then return end
    self._toggleLocked = true
    C_Timer.After(0.3, function() self._toggleLocked = false end)

    if self._active then
        self:Deactivate()
    else
        self:Activate()
    end
end

function MoverModule:IsActive()
    return self._active == true
end

-- ── AceModule lifecycle ──────────────────────────────────────────────────────

function MoverModule:OnInitialize()
    self._registry = self._registry or {}
    self._handles  = self._handles or {}
    self._hidden   = self._hidden or {}
    self._active   = false
end

function MoverModule:OnEnable() end

function MoverModule:OnDisable()
    if self._active then self:Deactivate() end
end
