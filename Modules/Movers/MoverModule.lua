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

local TwichRx          = _G.TwichRx
---@type TwichUI
local T                = unpack(TwichRx)

---@class TwichMoverModule : AceModule, AceEvent-3.0
local MoverModule      = T:NewModule("Movers", "AceEvent-3.0")

_G.TwichMoverModule    = MoverModule

local CreateFrame      = _G.CreateFrame
local UIParent         = _G.UIParent
local InCombatLockdown = _G.InCombatLockdown
local IsShiftKeyDown   = _G.IsShiftKeyDown
local C_Timer          = _G.C_Timer
local math_floor       = math.floor
local math_max         = math.max
local math_min         = math.min
local math_abs         = math.abs

-- ── Colours (match the rest of TwichUI) ────────────────────────────────────
local C_ACCENT         = { 0.10, 0.72, 0.74 } -- teal
local C_BG             = { 0.05, 0.06, 0.09 }
local C_BORDER         = { 0.10, 0.72, 0.74 }
local C_LABEL          = { 0.55, 0.58, 0.68 }
local C_BTN_BG         = { 0.09, 0.11, 0.15 }
local C_BTN_BD         = { 0.20, 0.22, 0.30 }

-- ── Per-category tint colours ────────────────────────────────────────────────
-- Handles are tinted by category so the user can identify module groups at a glance.
local CATEGORY_COLORS  = {
    ["Unit Frames"] = { 0.32, 0.55, 0.98 },  -- blue
    ["Action Bars"] = { 0.98, 0.62, 0.22 },  -- orange
    ["Data Panels"] = { 0.32, 0.85, 0.45 },  -- green
    ["Chat"]        = { 0.82, 0.48, 0.95 },  -- purple
    ["Gathering"]   = { 0.95, 0.88, 0.28 },  -- yellow
    -- fallback: teal (C_ACCENT) for anything unrecognised
}

local OVERLAY_ALPHA    = 0.65 -- translucency of the full-screen backdrop

-- ── Registry ────────────────────────────────────────────────────────────────
MoverModule._registry  = MoverModule._registry or {} -- key → opts
MoverModule._handles   = MoverModule._handles or {}  -- key → handle frame
MoverModule._hidden    = MoverModule._hidden or {}   -- key → true  (temp-hidden)
MoverModule._active    = false

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

    -- Hide on click-outside via overlay script (see _BuildOverlay)
    panel._activeKey = nil

    -- Hover-delay hide
    local function CancelHide()
        if panel._hideTimer then
            panel._hideTimer:Cancel(); panel._hideTimer = nil
        end
    end
    local function ScheduleHide()
        CancelHide()
        panel._hideTimer = C_Timer.NewTimer(0.1, function()
            panel._hideTimer = nil
            -- Keep open if any editbox has focus
            for _, eb in ipairs(panel._editBoxes or {}) do
                if eb:HasFocus() then return end
            end
            panel:Hide()
        end)
    end
    panel.CancelHide   = CancelHide
    panel.ScheduleHide = ScheduleHide
    panel:SetScript("OnEnter", CancelHide)
    panel:SetScript("OnLeave", ScheduleHide)

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

    -- ── Title row ────────────────────────────────────────────────────────
    local W = 240
    panel:SetWidth(W)

    local titleFS = MakeFS("", 8, -8, 11, C_ACCENT[1], C_ACCENT[2], C_ACCENT[3])
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    titleFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    titleFS:SetJustifyH("LEFT")
    panel.titleFS = titleFS

    local hintFS = MakeFS("Shift=10px", W - 8, -8, 8, 0.40, 0.40, 0.52)
    hintFS:ClearAllPoints()
    hintFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    hintFS:SetJustifyH("RIGHT")

    MakeDiv(-22)

    -- ── X / Y row ────────────────────────────────────────────────────────
    MakeFS("X", 8, -35, 10)
    MakeFS("Y", W / 2 + 4, -35, 10)
    local xBox = MakeEB(19, -30, W / 2 - 22)
    local yBox = MakeEB(W / 2 + 15, -30, W / 2 - 18)
    panel.xBox = xBox
    panel.yBox = yBox

    MakeDiv(-55, 0.18)

    -- ── W / H row ────────────────────────────────────────────────────────
    MakeFS("W", 8, -63, 10)
    MakeFS("H", W / 2 + 4, -63, 10)
    local wBox = MakeEB(19, -58, W / 2 - 22)
    local hBox = MakeEB(W / 2 + 15, -58, W / 2 - 18)
    panel.wBox = wBox
    panel.hBox = hBox

    MakeDiv(-83, 0.18)

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

    local r1y = -91
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

    MakeDiv(-91 - 3 * (S + G) - 4, 0.18)

    -- ── Anchor picker (3×3 grid) ──────────────────────────────────────────
    -- Shows which anchor is active; clicking any cell converts and saves the anchor.
    local anchorSectionY = -91 - 3 * (S + G) - 14

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
            local hndl   = MoverModule._handles[panel._activeKey]
            local blX    = hndl and hndl:GetLeft() or (type(opts.getX) == "function" and opts.getX() or 0)
            local blY    = hndl and hndl:GetBottom() or (type(opts.getY) == "function" and opts.getY() or 0)
            local hfw    = hndl and hndl:GetWidth() or 0
            local hfh    = hndl and hndl:GetHeight() or 0
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
    panel._extrasContainer = CreateFrame("Frame", nil, panel)
    panel._extrasContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panel._extrasContainer:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    panel._extrasContainer:SetHeight(0)
    panel._extrasContainer:Hide() -- shown only when extras exist

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

        -- Rebuild extra controls
        local ec = panel._extrasContainer
        -- Remove any previous extra children by hiding them
        if ec._extraWidgets then
            for _, w in ipairs(ec._extraWidgets) do w:Hide() end
        end
        ec._extraWidgets = {}
        ec:Hide()

        local extraH = 0
        local extras = opts.extras
        if type(extras) == "table" and #extras > 0 then
            ec:Show()
            -- Position the container below the hide button
            ec:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -(panel._baseHeight))
            ec:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -(panel._baseHeight))
            MakeDiv(-(panel._baseHeight + 1))
            local curY = -4
            for _, extra in ipairs(extras) do
                if extra.type == "toggle" then
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
                        local nv = not (type(self._extra.get) == "function" and self._extra.get() or false)
                        if type(self._extra.set) == "function" then self._extra.set(nv) end
                        self._dot:SetShown(nv)
                        MoverModule:_PositionHandle(key)
                    end)
                    chk:SetScript("OnEnter", CancelHide)
                    chk:SetScript("OnLeave", ScheduleHide)
                    ec._extraWidgets[#ec._extraWidgets + 1] = chk

                    curY = curY - 22
                    extraH = extraH + 22
                end
            end
            ec:SetHeight(extraH + 4)
        end

        local totalH = panel._baseHeight + (extraH > 0 and extraH + 12 or 0)
        panel:SetHeight(totalH)

        RefreshBoxes()

        -- Position near anchor handle
        panel:ClearAllPoints()
        if anchorHandle then
            local sw = UIParent:GetWidth() or 1280
            local sh = UIParent:GetHeight() or 768
            local hT = anchorHandle:GetTop() or 0
            local hL = anchorHandle:GetLeft() or 0
            local hR = anchorHandle:GetRight() or 0
            -- Prefer showing below; swap if near top
            if hT > sh * 0.6 then
                panel:SetPoint("TOP", anchorHandle, "BOTTOM", 0, -6)
            else
                panel:SetPoint("BOTTOM", anchorHandle, "TOP", 0, 6)
            end
            -- Clamp horizontally
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
        panel:Show()
        panel:SetFrameLevel(9999)
    end

    self._inspector = panel
    return panel
end

-- ── Handle creation & positioning ───────────────────────────────────────────

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
        -- When positioned via two-anchor live-frame approach, StartMoving() needs a
        -- single BOTTOMLEFT anchor first.  Read h's current screen coords (h is always
        -- scale-1 so GetLeft/GetBottom are reliable in UIParent space), then collapse to
        -- a single anchor before calling StartMoving.
        local blX = math_floor((self:GetLeft() or 0) + 0.5)
        local blY = math_floor((self:GetBottom() or 0) + 0.5)
        local vw  = math_floor((self:GetWidth() or 40) + 0.5)
        local vh  = math_floor((self:GetHeight() or 16) + 0.5)
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", blX, blY)
        self:SetSize(math_max(40, vw), math_max(16, vh))
        self:StartMoving()
        self._dragging = true
        local inspector = MoverModule._inspector
        if inspector and inspector._activeKey == key then
            inspector:Hide()
        end
    end)

    h:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self._dragging = false
        local blX      = math_floor((self:GetLeft() or 0) + 0.5)
        local blY      = math_floor((self:GetBottom() or 0) + 0.5)
        local o        = MoverModule._registry[key]
        if o then
            if type(o.setAnchor) == "function" then
                -- Preserve whatever anchor is currently stored: convert the dragged
                -- BOTTOMLEFT screen position back to an offset relative to that anchor.
                local curPt  = type(o.getPoint) == "function" and o.getPoint() or "BOTTOMLEFT"
                local nx, ny = MoverModule:_ConvertFromBL(blX, blY, curPt, self:GetWidth(), self:GetHeight())
                o.setAnchor(curPt, nx, ny)
            elseif type(o.setPos) == "function" then
                o.setPos(blX, blY)
            end
        end
        -- Open inspector at new position
        local insp = MoverModule:_GetInspector()
        insp.Activate(key, self)
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
    hudTitle:SetText("|cff19c9c7TwichUI|r  Move Mode")
    hudTitle:SetTextColor(0.92, 0.94, 0.96)

    -- Instruction text
    local hudHint = hud:CreateFontString(nil, "OVERLAY")
    hudHint:SetPoint("CENTER", hud, "CENTER", 0, 0)
    SetFont(hudHint, 10)
    hudHint:SetText("Drag handles to reposition · Left-click for inspector · Right-click to hide · Shift+nudge = 10 px")
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
        print("|cff19c9c7[TwichUI]|r Cannot enter Move Mode in combat.")
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

    print("|cff19c9c7[TwichUI]|r Move Mode active — drag handles or click for inspector. |cffff6060ESC|r or Exit button to close.")
end

function MoverModule:Deactivate()
    self._active = false

    -- Hide all handles
    for _, h in pairs(self._handles) do
        if h then h:Hide() end
    end

    -- Hide inspector
    if self._inspector then self._inspector:Hide() end

    -- Hide overlay / HUD
    if self._overlay then self._overlay:Hide() end
    if self._hud then self._hud:Hide() end

    print("|cff19c9c7[TwichUI]|r Move Mode closed.")

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
