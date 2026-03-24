---@diagnostic disable: undefined-field
--[[
    Gathering Module
    ================
    Farm HUD radar (minimap overlay), item loot tracking, session management,
    loot notifications via the notification system, and gold-per-hour calculation.
    Pricing is provided by TSM_API.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local E = _G.ElvUI and _G.ElvUI[1]

---@class GatheringModule : AceModule, AceEvent-3.0, AceTimer-3.0
local Gathering = T:GetModule("QualityOfLife"):NewModule("Gathering", "AceEvent-3.0", "AceTimer-3.0")
Gathering:SetEnabledState(false)

-- ============================================================
-- Localised WoW API
-- ============================================================
local AceGUI               = LibStub("AceGUI-3.0")
local C_Item               = _G.C_Item
local C_Container          = _G.C_Container
local GetContainerNumSlots = _G.C_Container and _G.C_Container.GetContainerNumSlots or _G.GetContainerNumSlots
local GetContainerItemInfo = _G.C_Container and
function(bag, slot) return _G.C_Container.GetContainerItemInfo(bag, slot) end or _G.GetContainerItemInfo
local GetTime              = _G.GetTime
local UIParent             = _G.UIParent
local CreateFrame          = _G.CreateFrame
local IsControlKeyDown     = _G.IsControlKeyDown
local IsShiftKeyDown       = _G.IsShiftKeyDown
local GetItemInfo          = _G.GetItemInfo
local format               = string.format
local floor                = math.floor
local max                  = math.max
local min                  = math.min

-- ============================================================
-- Constants
-- ============================================================
local NUM_BAGS             = 5 -- 0..4
local HUD_DEFAULT_SIZE     = 400
local HUD_MINIMAP_SIZE     = 256 -- HorizonSuite always uses 256 physical, we drive via scale
local GPS_TICKER_INTERVAL  = 5.0

-- ============================================================
-- Module config helpers
-- ============================================================
local function GetOptions()
    return T:GetModule("Configuration").Options.Gathering
end

local function GetDB()
    local opts = GetOptions()
    return opts and opts:GetDB() or {}
end

local function GetNotificationModule()
    return T:GetModule("Notification")
end

-- ============================================================
-- Session state
-- ============================================================
Gathering.session = {
    active        = false,
    startTime     = nil,
    pausedAt      = nil,
    activeSeconds = 0,   -- total seconds the session was unpaused
    items         = {},  -- [itemID] = { itemLink, name, qty, totalValue, iconTexture }
    totalValue    = 0,   -- copper
    goldPerHour   = 0,   -- copper
    lastGPHUpdate = nil,
}

-- ============================================================
-- Minimap / HUD state
-- ============================================================
Gathering.hud = {
    active             = false,
    savedParent        = nil,
    savedScale         = nil,
    savedPoint         = nil,
    savedRelPoint      = nil,
    savedX             = nil,
    savedY             = nil,
    savedAlpha         = nil,
    savedMouseEnabled  = nil,
    savedRotateMinimap = nil,
    ringFrame          = nil,
    gpsTicker          = nil,
}

-- ============================================================
-- Proxy (mirrors HorizonSuite's taint-free pattern)
-- ============================================================
local proxy = CreateFrame("Frame")

-- ============================================================
-- Helpers: copper formatting
-- ============================================================
local function FormatCopper(copper)
    if not copper or copper <= 0 then return "|cffaaaaaa0g|r" end
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return format("|cffd4a017%dg|r |cffc0c0c0%ds|r |cffb87333%dc|r", g, s, c)
    elseif s > 0 then
        return format("|cffc0c0c0%ds|r |cffb87333%dc|r", s, c)
    else
        return format("|cffb87333%dc|r", c)
    end
end

-- ============================================================
-- TSM pricing
-- ============================================================
local function GetTSMItemPrice(itemID)
    if not _G.TSM_API then return nil end
    local db = GetDB()
    local priceSource = db.priceSource or "DBMarket"
    local itemString = "i:" .. itemID
    local ok, value = pcall(_G.TSM_API.GetCustomPriceValue, priceSource, itemString)
    if ok and type(value) == "number" and value > 0 then
        return value
    end
    -- Fallback to VendorSell
    local ok2, val2 = pcall(_G.TSM_API.GetCustomPriceValue, "VendorSell", itemString)
    if ok2 and type(val2) == "number" then return val2 end
    return nil
end

local function GetBagQuantity(itemID)
    if _G.TSM_API and _G.TSM_API.GetBagQuantity then
        local ok, qty = pcall(_G.TSM_API.GetBagQuantity, "i:" .. itemID)
        if ok and type(qty) == "number" then return qty end
    end
    -- Manual bag scan fallback
    local total = 0
    for bag = 0, NUM_BAGS - 1 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local info = GetContainerItemInfo(bag, slot)
                if info then
                    local id = info.itemID
                    if id == itemID then
                        total = total + (info.stackCount or 1)
                    end
                end
            end
        end
    end
    return total
end

-- ============================================================
-- Session management
-- ============================================================
function Gathering:StartSession()
    local sess = self.session
    if sess.active then return end
    sess.active = true
    if not sess.startTime then
        sess.startTime     = GetTime()
        sess.items         = {}
        sess.totalValue    = 0
        sess.goldPerHour   = 0
        sess.activeSeconds = 0
    else
        -- Resuming from pause
        if sess.pausedAt then
            sess.startTime = sess.startTime + (GetTime() - sess.pausedAt)
            sess.pausedAt  = nil
        end
    end
    sess.lastGPHUpdate = GetTime()
    self:RefreshDatatext()
end

function Gathering:PauseSession()
    local sess = self.session
    if not sess.active then return end
    sess.active = false
    sess.pausedAt = GetTime()
    -- Accumulate active seconds
    if sess.startTime then
        sess.activeSeconds = sess.activeSeconds + (sess.pausedAt - (sess.lastGPHUpdate or sess.startTime))
    end
    self:RefreshDatatext()
end

function Gathering:ResetSession()
    local sess         = self.session
    local wasActive    = sess.active
    sess.active        = false
    sess.startTime     = nil
    sess.pausedAt      = nil
    sess.activeSeconds = 0
    sess.items         = {}
    sess.totalValue    = 0
    sess.goldPerHour   = 0
    sess.lastGPHUpdate = nil
    if wasActive then
        self:StartSession()
    end
    self:RefreshDatatext()
    if self.trackerFrame then
        self:RefreshTrackerFrame()
    end
end

function Gathering:GetActiveSessionSeconds()
    local sess = self.session
    if not sess.active or not sess.startTime then
        return sess.activeSeconds
    end
    return sess.activeSeconds + (GetTime() - (sess.lastGPHUpdate or sess.startTime))
end

function Gathering:UpdateGoldPerHour()
    local sess = self.session
    if not sess.startTime then return end
    local secs = self:GetActiveSessionSeconds()
    if sess.active and sess.lastGPHUpdate then
        secs = secs + (GetTime() - sess.lastGPHUpdate)
        sess.activeSeconds = sess.activeSeconds + (GetTime() - sess.lastGPHUpdate)
        sess.lastGPHUpdate = GetTime()
    end
    if secs <= 0 then return end
    sess.goldPerHour = floor((sess.totalValue / secs) * 3600)
    self:RefreshDatatext()
    if self.trackerFrame and self.trackerFrame:IsShown() then
        self:RefreshTrackerFrame()
    end
end

-- ============================================================
-- Bag scanning & loot detection
-- ============================================================
Gathering.bagSnapshot = nil -- [bag][slot] = { itemID, count }

local function TakeBagSnapshot()
    local snap = {}
    for bag = 0, NUM_BAGS - 1 do
        snap[bag] = {}
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local info = GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    snap[bag][slot] = { itemID = info.itemID, count = info.stackCount or 0 }
                end
            end
        end
    end
    return snap
end

local function DiffBagSnapshots(old, new)
    -- Returns table of {itemID, delta (positive = gained)}
    local changes = {}
    local delta   = {} -- [itemID] = delta

    for bag = 0, NUM_BAGS - 1 do
        local oldBag = old[bag] or {}
        local newBag = new[bag] or {}
        local maxSlots = max(
            #oldBag + (old[bag] and 1 or 0),
            GetContainerNumSlots(bag) or 0
        )

        -- Iterate all possible slots
        for slot = 1, max(200, maxSlots) do
            local oldSlot = oldBag[slot]
            local newSlot = newBag[slot]
            if oldSlot and newSlot and oldSlot.itemID == newSlot.itemID then
                local d = newSlot.count - oldSlot.count
                if d ~= 0 then
                    delta[newSlot.itemID] = (delta[newSlot.itemID] or 0) + d
                end
            elseif newSlot and not oldSlot then
                delta[newSlot.itemID] = (delta[newSlot.itemID] or 0) + newSlot.count
            elseif oldSlot and not newSlot then
                delta[oldSlot.itemID] = (delta[oldSlot.itemID] or 0) - oldSlot.count
            end
        end
    end

    for itemID, d in pairs(delta) do
        if d > 0 then
            table.insert(changes, { itemID = itemID, delta = d })
        end
    end
    return changes
end

function Gathering:OnBAGUpdate()
    local newSnap = TakeBagSnapshot()
    if not self.bagSnapshot then
        self.bagSnapshot = newSnap
        return
    end

    if not self.session.active then
        self.bagSnapshot = newSnap
        return
    end

    local changes = DiffBagSnapshots(self.bagSnapshot, newSnap)
    self.bagSnapshot = newSnap

    for _, change in ipairs(changes) do
        self:OnItemGained(change.itemID, change.delta)
    end
end

function Gathering:OnItemGained(itemID, qty)
    local db = GetDB()

    -- Get item info.
    -- C_Item.GetItemLink requires an ItemLocationMixin (not an itemID) — use GetItemInfo
    -- which returns the formatted link as its 2nd return value instead.
    local name, itemLink, _, _, _, _, _, _, _, iconTexture = GetItemInfo(itemID)
    if not name or not itemLink then
        -- Fallback raw link if cache miss (will be corrected on retry below)
        itemLink = itemLink or ("|Hitem:" .. itemID .. ":::::::::::::|h[" .. (name or "Unknown") .. "]|h")
    end
    if not name then
        -- Item not cached yet; queue a retry
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            self:OnItemGained(itemID, qty)
        end)
        return
    end

    -- TSM price
    local pricePerUnit = GetTSMItemPrice(itemID) or 0
    local batchValue   = pricePerUnit * qty

    -- Update session items
    local sess         = self.session
    local entry        = sess.items[itemID]
    if not entry then
        sess.items[itemID] = {
            itemLink    = itemLink,
            name        = name,
            qty         = qty,
            totalValue  = batchValue,
            iconTexture = iconTexture,
        }
    else
        entry.qty        = entry.qty + qty
        entry.totalValue = entry.totalValue + batchValue
        entry.itemLink   = itemLink -- refresh link (may have gotten quality)
    end
    sess.totalValue = sess.totalValue + batchValue

    -- Update GPH
    self:UpdateGoldPerHour()

    -- Bag totals for notification
    local bagCount = GetBagQuantity(itemID)
    local bagValue = pricePerUnit * bagCount
    local priceSource = db.priceSource or "DBMarket"

    -- Send notification
    self:SendGatherNotification({
        itemLink    = itemLink,
        quantity    = qty,
        itemValue   = pricePerUnit,
        bagCount    = bagCount,
        bagValue    = bagValue,
        priceSource = priceSource,
        iconTexture = iconTexture,
    })

    -- Refresh tracker if open
    if self.trackerFrame and self.trackerFrame:IsShown() then
        self:RefreshTrackerFrame()
    end
    self:RefreshDatatext()
end

-- ============================================================
-- Notification
-- ============================================================
function Gathering:SendGatherNotification(data)
    local NM = GetNotificationModule()
    if not NM then return end
    local db     = GetDB()

    local widget = AceGUI:Create("TwichUI_GatheringNotification")
    if not widget then return end
    widget:SetGatherData(data)
    widget:SetDismissCallback(function()
        -- handled by notification frame
    end)

    NM:TWICH_NOTIFICATION("TWICH_NOTIFICATION", widget, {
        displayDuration = db.notificationDuration or 6,
        soundKey        = (db.notificationSound and db.notificationSound ~= "__none") and db.notificationSound or nil,
    })
end

-- ============================================================
-- HUD (Farm Radar)
-- ============================================================
function Gathering:EnableHUD()
    if self.hud.active then return end
    local db = GetDB()
    local mm = _G.Minimap
    if not mm then return end

    -- Save current state so we can restore
    local point, _, relPoint, x, y = mm:GetPoint()
    self.hud.savedPoint            = point or "TOPRIGHT"
    self.hud.savedRelPoint         = relPoint or "TOPRIGHT"
    self.hud.savedX                = x or -20
    self.hud.savedY                = y or -20
    self.hud.savedScale            = mm:GetScale()
    self.hud.savedAlpha            = mm:GetAlpha()

    -- Move minimap to center using HorizonSuite's taint-free proxy.
    -- NOTE: Do NOT call SetFrameStrata here — HorizonSuite locks Minimap strata to "LOW"
    -- via SetFixedFrameStrata(true) in Vista.Init().  Any SetFrameStrata call is silently
    -- ignored, so we leave it alone and instead draw our ring at "BACKGROUND" strata,
    -- which is always behind the Minimap regardless of its strata.
    local hudSize                  = (db.hudSize or HUD_DEFAULT_SIZE)
    local newScale                 = hudSize / HUD_MINIMAP_SIZE

    proxy.ClearAllPoints(mm)
    proxy.SetPoint(mm, "CENTER", UIParent, "CENTER", 0, 0)
    proxy.SetScale(mm, newScale)

    -- Force circular shape for HUD
    if mm.SetMaskTexture then
        mm:SetMaskTexture(186178)
    end

    -- Terrain transparency
    local opts = GetOptions()
    if opts:GetHudTerrainTransparent() then
        mm:SetAlpha(opts:GetHudTerrainAlpha())
    else
        mm:SetAlpha(1.0)
    end

    -- Disable mouse on minimap so the player can click through to control their character.
    -- Save current state so we can restore on DisableHUD.
    self.hud.savedMouseEnabled = mm:IsMouseEnabled()
    mm:EnableMouse(false)

    -- Enable minimap rotation so the map rotates with the character heading.
    self.hud.savedRotateMinimap = _G.GetCVar("rotateMinimap")
    _G.SetCVar("rotateMinimap", "1")

    -- Create ring decoration — read color through Options getter.
    local rr, rg, rb, ra = opts:GetHudRingColor()
    self:CreateHUDRing(hudSize, { r = rr, g = rg, b = rb, a = ra })

    self.hud.active = true

    -- Auto-start session
    self:StartSession()
end

function Gathering:DisableHUD()
    if not self.hud.active then return end
    local mm = _G.Minimap
    if mm then
        proxy.ClearAllPoints(mm)
        proxy.SetPoint(mm,
            self.hud.savedPoint or "TOPRIGHT",
            UIParent,
            self.hud.savedRelPoint or "TOPRIGHT",
            self.hud.savedX or -20,
            self.hud.savedY or -20)
        proxy.SetScale(mm, self.hud.savedScale or 1.0)
        mm:SetAlpha(self.hud.savedAlpha or 1.0)
        -- Restore mouse enablement
        mm:EnableMouse(self.hud.savedMouseEnabled ~= false)
        -- Restore minimap rotation preference
        if self.hud.savedRotateMinimap then
            _G.SetCVar("rotateMinimap", self.hud.savedRotateMinimap)
        end
    end

    -- Hide ring (reused on next EnableHUD)
    if self.hud.ringFrame then
        self.hud.ringFrame:Hide()
    end

    self.hud.active = false

    -- Pause session
    self:PauseSession()
end

function Gathering:ToggleHUD()
    if self.hud.active then
        self:DisableHUD()
    else
        self:EnableHUD()
    end
end

-- Number of line segments used to approximate the circle outline.
-- 64 gives a visually smooth ring at all normal minimap sizes.
local HUD_RING_SEGMENTS = 64
local HUD_PI2           = math.pi * 2

function Gathering:CreateHUDRing(hudSize, colorTable)
    local mm = _G.Minimap
    if not mm then return end

    local db        = GetDB()
    local ringWidth = db.hudRingWidth or 15
    local radius    = hudSize / 2 -- visual radius in UIParent coordinate space
    local r         = colorTable.r or 0.0
    local g         = colorTable.g or 0.85
    local b         = colorTable.b or 1.0
    local a         = colorTable.a or 1.0

    if self.hud.ringFrame then
        -- Ring frame already exists from a previous EnableHUD call.
        -- Update geometry and color then show it.
        local ring = self.hud.ringFrame
        for i, line in ipairs(ring._lines) do
            local a1 = ((i - 1) / HUD_RING_SEGMENTS) * HUD_PI2
            local a2 = (i / HUD_RING_SEGMENTS) * HUD_PI2
            line:SetStartPoint("CENTER", mm, math.cos(a1) * radius, math.sin(a1) * radius)
            line:SetEndPoint("CENTER", mm, math.cos(a2) * radius, math.sin(a2) * radius)
            line:SetThickness(ringWidth)
            line:SetColorTexture(r, g, b, a)
        end
        ring:Show()
        return
    end

    -- First-ever creation.  Use nil name (no global registration) and
    -- fill UIParent so lines are never clipped by the container bounds.
    -- EnableMouse(false) so clicks pass through.
    local ring = CreateFrame("Frame", nil, UIParent)
    ring:SetAllPoints(UIParent)
    ring:SetFrameStrata("MEDIUM")
    ring:SetFrameLevel(1)
    ring:EnableMouse(false)

    -- Build the polygon ring from individual line segments.
    -- Each line is one chord of the circle; together they form a clean outline
    -- with no fill whatsoever.  SetColorTexture on a Line sets its solid color.
    local lines = {}
    for i = 1, HUD_RING_SEGMENTS do
        local a1 = ((i - 1) / HUD_RING_SEGMENTS) * HUD_PI2
        local a2 = (i / HUD_RING_SEGMENTS) * HUD_PI2
        local line = ring:CreateLine(nil, "OVERLAY")
        line:SetColorTexture(r, g, b, a)
        line:SetThickness(ringWidth)
        -- SetStartPoint / SetEndPoint take (relativePoint, relativeTo, offsetX, offsetY).
        -- Offsets are in UIParent (unscaled) coordinate space, so hudSize/2 == the visual
        -- radius of the minimap when scaled to hudSize logical pixels.
        line:SetStartPoint("CENTER", mm, math.cos(a1) * radius, math.sin(a1) * radius)
        line:SetEndPoint("CENTER", mm, math.cos(a2) * radius, math.sin(a2) * radius)
        lines[i] = line
    end

    ring._lines = lines
    ring:Show()
    self.hud.ringFrame = ring
end

function Gathering:RefreshHUDRing()
    if not self.hud.active or not self.hud.ringFrame then return end
    local db             = GetDB()
    local opts           = GetOptions()
    local cr, cg, cb, ca = opts:GetHudRingColor()
    local rw             = db.hudRingWidth or 15
    local hudSize        = db.hudSize or HUD_DEFAULT_SIZE
    local radius         = hudSize / 2
    local mm             = _G.Minimap
    if not mm then return end
    for i, line in ipairs(self.hud.ringFrame._lines) do
        local a1 = ((i - 1) / HUD_RING_SEGMENTS) * HUD_PI2
        local a2 = (i / HUD_RING_SEGMENTS) * HUD_PI2
        line:SetColorTexture(cr, cg, cb, ca)
        line:SetThickness(rw)
        line:SetStartPoint("CENTER", mm, math.cos(a1) * radius, math.sin(a1) * radius)
        line:SetEndPoint("CENTER", mm, math.cos(a2) * radius, math.sin(a2) * radius)
    end
end

-- ============================================================
-- Tracker Frame (gathered items list)
-- ============================================================
local TRACKER_WIDTH      = 420
local TRACKER_HEIGHT     = 460
local TRACKER_MIN_WIDTH  = 320
local TRACKER_MIN_HEIGHT = 280
local TRACKER_MAX_WIDTH  = 800
local TRACKER_MAX_HEIGHT = 900

local function GetBackdropColors()
    local bgR, bgG, bgB, bgA = 0.06, 0.06, 0.08, 0.98
    local borderR, borderG, borderB = 0.25, 0.25, 0.3
    local E2 = _G.ElvUI and _G.ElvUI[1]
    if E2 and E2.media then
        if E2.media.backdropcolor then bgR, bgG, bgB = unpack(E2.media.backdropcolor) end
        if E2.media.bordercolor then borderR, borderG, borderB = unpack(E2.media.bordercolor) end
    end
    return bgR, bgG, bgB, bgA, borderR, borderG, borderB
end

local function CreateBackdrop(frame)
    local bgR, bgG, bgB, bgA, borderR, borderG, borderB = GetBackdropColors()
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, 0.6)
end

function Gathering:CreateTrackerFrame()
    if self.trackerFrame then return self.trackerFrame end

    local bgR, bgG, bgB, bgA, borderR, borderG, borderB = GetBackdropColors()

    local frame = CreateFrame("Frame", "TwichUIGatheringTrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(TRACKER_WIDTH, TRACKER_HEIGHT)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(TRACKER_MIN_WIDTH, TRACKER_MIN_HEIGHT, TRACKER_MAX_WIDTH, TRACKER_MAX_HEIGHT)
    end
    frame:Hide()
    CreateBackdrop(frame)

    -- Save position on drag
    frame:SetScript("OnMouseDown", function(f, btn)
        if btn == "LeftButton" and not self:IsTrackerLocked() then
            f:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(f)
        f:StopMovingOrSizing()
        self:SaveTrackerPosition()
    end)

    -- --------- Title bar ---------
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)
    titleBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 1 },
    })
    titleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.98)
    titleBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.35)

    -- Gold accent strip
    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 0, 0)
    titleAccent:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, 0)
    titleAccent:SetHeight(2)
    titleAccent:SetColorTexture(0.2, 0.75, 0.3, 0.95)

    -- Icon
    local titleIcon = titleBar:CreateTexture(nil, "OVERLAY")
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleIcon:SetSize(16, 16)
    titleIcon:SetTexture("Interface\\Icons\\inv_herb_haranir_rosepetal")
    titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetText("Gathering Session")
    titleText:SetTextColor(1, 0.94, 0.82)

    -- GPH label in title bar
    local gphLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    gphLabel:SetPoint("RIGHT", titleBar, "RIGHT", -38, 0)
    gphLabel:SetJustifyH("RIGHT")
    gphLabel:SetTextColor(0.2, 0.9, 0.3, 1)
    frame.gphLabel = gphLabel

    -- Close button
    local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -2, 0)
    T.Tools.UI.SkinCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- --------- Summary bar ---------
    local summaryBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    summaryBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -36)
    summaryBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -36)
    summaryBar:SetHeight(28)
    summaryBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    summaryBar:SetBackdropColor(0.12, 0.12, 0.14, 0.95)
    summaryBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.3)

    local totalValueLabel = summaryBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalValueLabel:SetPoint("LEFT", summaryBar, "LEFT", 8, 0)
    totalValueLabel:SetJustifyH("LEFT")
    totalValueLabel:SetTextColor(0.9, 0.78, 0.2, 1)
    frame.totalValueLabel = totalValueLabel

    local sessionTimeLabel = summaryBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sessionTimeLabel:SetPoint("RIGHT", summaryBar, "RIGHT", -8, 0)
    sessionTimeLabel:SetJustifyH("RIGHT")
    sessionTimeLabel:SetTextColor(0.72, 0.72, 0.72, 1)
    frame.sessionTimeLabel = sessionTimeLabel

    -- --------- Column headers ---------
    local hdrs = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    hdrs:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -68)
    hdrs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -68)
    hdrs:SetHeight(20)
    hdrs:SetBackdropColor(0, 0, 0, 0)
    hdrs:SetBackdropBorderColor(0, 0, 0, 0)

    local function MkHdr(text, anchor, relAnchor, x)
        local fs = hdrs:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint(anchor, hdrs, relAnchor, x, 0)
        fs:SetTextColor(0.75, 0.75, 0.75, 1)
        fs:SetText(text)
        return fs
    end
    MkHdr("Item", "LEFT", "LEFT", 8)
    MkHdr("Qty", "CENTER", "CENTER", -60)
    MkHdr("Item Value", "CENTER", "CENTER", 20)
    MkHdr("Total Value", "RIGHT", "RIGHT", -8)

    -- Divider line
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -88)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -88)
    divider:SetHeight(1)
    divider:SetColorTexture(0.25, 0.25, 0.30, 0.8)

    -- --------- Scroll area ---------
    local contentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -92)
    contentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 28)
    contentInset:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    contentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, 0.98)
    contentInset:SetBackdropBorderColor(borderR, borderG, borderB, 0.45)

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentInset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", contentInset, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentInset, "BOTTOMRIGHT", -20, 8)
    T.Tools.UI.SkinScrollBar(scrollFrame)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    frame.scrollFrame  = scrollFrame
    frame.scrollChild  = scrollChild
    frame.rows         = {}

    -- --------- Resize handle ---------
    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    resizeHandle:SetSize(18, 18)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrab")
    resizeHandle:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SaveTrackerSize()
    end)

    -- --------- Empty label ---------
    local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("CENTER", contentInset, "CENTER", 0, 0)
    emptyText:SetTextColor(0.6, 0.6, 0.6, 1)
    emptyText:SetText("No items gathered this session.")
    frame.emptyText = emptyText

    self.trackerFrame = frame
    self:RestoreTrackerPosition()
    return frame
end

local ROW_HEIGHT    = 28
local ICON_ROW_SIZE = 20

local function EnsureTrackerRow(scrollChild, rows, index)
    if rows[index] then return rows[index] end

    local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()
    local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    if index == 1 then
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    else
        local prev = rows[index - 1]
        row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -2)
        row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -2)
    end
    row:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    -- alternate row shading
    if index % 2 == 0 then
        row:SetBackdropColor(bgR * 1.1, bgG * 1.1, bgB * 1.15, 0.6)
    else
        row:SetBackdropColor(bgR, bgG, bgB, 0.4)
    end
    row:SetBackdropBorderColor(borderR, borderG, borderB, 0.15)

    -- Item icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetSize(ICON_ROW_SIZE, ICON_ROW_SIZE)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    -- Item link label
    local itemLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemLabel:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    itemLabel:SetWidth(130)
    itemLabel:SetJustifyH("LEFT")
    itemLabel:SetWordWrap(false)
    row.itemLabel = itemLabel

    -- Qty
    local qtyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtyLabel:SetPoint("CENTER", row, "CENTER", -60, 0)
    qtyLabel:SetWidth(50)
    qtyLabel:SetJustifyH("CENTER")
    qtyLabel:SetTextColor(0.85, 0.85, 0.85, 1)
    row.qtyLabel = qtyLabel

    -- Item value (per unit)
    local itemValLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemValLabel:SetPoint("CENTER", row, "CENTER", 20, 0)
    itemValLabel:SetWidth(80)
    itemValLabel:SetJustifyH("CENTER")
    row.itemValLabel = itemValLabel

    -- Total value
    local totalValLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalValLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    totalValLabel:SetWidth(90)
    totalValLabel:SetJustifyH("RIGHT")
    totalValLabel:SetTextColor(0.9, 0.78, 0.2, 1)
    row.totalValLabel = totalValLabel

    rows[index] = row
    return row
end

function Gathering:RefreshTrackerFrame()
    local frame = self.trackerFrame
    if not frame then return end

    local sess        = self.session
    local scrollChild = frame.scrollChild
    local rows        = frame.rows

    -- Build sorted item list
    local sorted      = {}
    for itemID, entry in pairs(sess.items) do
        table.insert(sorted, { itemID = itemID, entry = entry })
    end
    table.sort(sorted, function(a, b)
        return (a.entry.totalValue or 0) > (b.entry.totalValue or 0)
    end)

    -- Show/hide empty text
    if #sorted == 0 then
        frame.emptyText:Show()
    else
        frame.emptyText:Hide()
    end

    -- Build rows
    for i, item in ipairs(sorted) do
        local row   = EnsureTrackerRow(scrollChild, rows, i)
        local entry = item.entry
        row.icon:SetTexture(entry.iconTexture)
        row.itemLabel:SetText(entry.itemLink or entry.name or "Unknown")

        row.qtyLabel:SetText(tostring(entry.qty or 0))

        -- Per-unit price
        local perUnit = (entry.qty and entry.qty > 0) and floor((entry.totalValue or 0) / entry.qty) or 0
        row.itemValLabel:SetText(FormatCopper(perUnit))
        row.totalValLabel:SetText(FormatCopper(entry.totalValue or 0))

        row:Show()
    end

    -- Hide excess rows
    for i = #sorted + 1, #rows do
        if rows[i] then rows[i]:Hide() end
    end

    -- Resize scroll child
    local totalH = (#sorted * (ROW_HEIGHT + 2))
    scrollChild:SetHeight(max(1, totalH))

    -- Summary bar
    frame.totalValueLabel:SetText("Total: " .. FormatCopper(sess.totalValue))

    -- GPH in title bar
    local gphText = sess.goldPerHour > 0
        and (FormatCopper(sess.goldPerHour) .. "/hr")
        or "|cffaaaaaa--/hr|r"
    frame.gphLabel:SetText(gphText)

    -- Session time
    local secs = self:GetActiveSessionSeconds()
    local mins = floor(secs / 60)
    local secs2 = secs % 60
    local statusStr
    if not sess.startTime then
        statusStr = "|cffaaaaaa No Session|r"
    elseif not sess.active then
        statusStr = "|cffd4a017Paused|r"
    else
        statusStr = format("%dm %ds", mins, secs2)
    end
    frame.sessionTimeLabel:SetText(statusStr)
end

function Gathering:ToggleTrackerFrame()
    if not self.trackerFrame then
        self:CreateTrackerFrame()
    end
    if self.trackerFrame:IsShown() then
        self.trackerFrame:Hide()
    else
        self:RefreshTrackerFrame()
        self.trackerFrame:Show()
    end
end

function Gathering:IsTrackerLocked()
    local db = GetDB()
    return db.trackerLocked == true
end

function Gathering:SaveTrackerPosition()
    local db = GetDB()
    if not self.trackerFrame then return end
    local point, _, relPoint, x, y = self.trackerFrame:GetPoint()
    db.trackerPoint                = point or "CENTER"
    db.trackerRelPoint             = relPoint or "CENTER"
    db.trackerX                    = x or 0
    db.trackerY                    = y or 0
end

function Gathering:SaveTrackerSize()
    local db = GetDB()
    if not self.trackerFrame then return end
    db.trackerWidth  = self.trackerFrame:GetWidth()
    db.trackerHeight = self.trackerFrame:GetHeight()
end

function Gathering:RestoreTrackerPosition()
    local db = GetDB()
    if not self.trackerFrame then return end
    if db.trackerPoint then
        self.trackerFrame:ClearAllPoints()
        self.trackerFrame:SetPoint(db.trackerPoint, UIParent, db.trackerRelPoint or "CENTER", db.trackerX or 0,
            db.trackerY or 0)
    else
        self.trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if db.trackerWidth and db.trackerHeight then
        self.trackerFrame:SetSize(db.trackerWidth, db.trackerHeight)
    end
end

-- ============================================================
-- Datatext refresh
-- ============================================================
function Gathering:RefreshDatatext()
    local DT = T:GetModule("Datatexts")
    if DT and DT.RefreshDataText then
        DT:RefreshDataText("TwichUI: Gathering")
    end
end

-- ============================================================
-- Timers
-- ============================================================
function Gathering:StartGPHTicker()
    if self.hud.gpsTicker then return end
    self.hud.gpsTicker = self:ScheduleRepeatingTimer(function()
        if self.session.active then
            self:UpdateGoldPerHour()
        end
    end, GPS_TICKER_INTERVAL)
end

function Gathering:StopGPHTicker()
    if self.hud.gpsTicker then
        self:CancelTimer(self.hud.gpsTicker)
        self.hud.gpsTicker = nil
    end
end

-- ============================================================
-- AceModule lifecycle
-- ============================================================
function Gathering:OnEnable()
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBAGUpdate")
    self.bagSnapshot = TakeBagSnapshot()
    self:StartGPHTicker()
end

function Gathering:OnDisable()
    if self.hud.active then
        self:DisableHUD()
    end
    self:UnregisterAllEvents()
    self:StopGPHTicker()
end
