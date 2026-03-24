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

---@class QualityOfLifeGatheringModule : AceModule, AceEvent-3.0, AceTimer-3.0
local Gathering = T:GetModule("QualityOfLife"):NewModule("Gathering", "AceEvent-3.0", "AceTimer-3.0")
Gathering:SetEnabledState(false)

-- ============================================================
-- Localised WoW API
-- ============================================================
local AceGUI                          = LibStub("AceGUI-3.0")
local C_Item                          = _G.C_Item
local C_Container                     = _G.C_Container
local GetContainerNumSlots            = _G.C_Container and _G.C_Container.GetContainerNumSlots or _G
.GetContainerNumSlots
local GetContainerItemInfo            = _G.C_Container and
function(bag, slot) return _G.C_Container.GetContainerItemInfo(bag, slot) end or _G.GetContainerItemInfo
local GetTime                         = _G.GetTime
local UIParent                        = _G.UIParent
local CreateFrame                     = _G.CreateFrame
local IsControlKeyDown                = _G.IsControlKeyDown
local IsShiftKeyDown                  = _G.IsShiftKeyDown
local GetItemInfo                     = _G.GetItemInfo
local time                            = _G.time
local date                            = _G.date
local format                          = string.format
local floor                           = math.floor
local max                             = math.max
local min                             = math.min

-- ============================================================
-- Constants
-- ============================================================
local NUM_BAGS                        = 5 -- 0..4
local HUD_DEFAULT_SIZE                = 400
local HUD_MINIMAP_SIZE                = 256 -- HorizonSuite always uses 256 physical, we drive via scale
local GPS_TICKER_INTERVAL             = 5.0
local MIN_GPH_TICKER_INTERVAL         = 1.0
local HUD_COMPATIBILITY_TICK_INTERVAL = 0.2
local DEBUG_LOG_LIMIT                 = 80

local GOLD_COLOR                      = "|cffffd24a"
local SILVER_COLOR                    = "|cffd7e0ea"
local COPPER_COLOR                    = "|cffd08a43"

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

local function GetLSM()
    return T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)
end

local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
local DEBUG_SOURCE_KEY = "gathering"

local function RefreshExternalMinimapOverlays()
    local routesCanvas = _G.Minimap

    -- Routes draws directly on Minimap and caches radius/rotation/scale state.
    if _G.Routes and type(_G.Routes.DrawMinimapLines) == "function" then
        if type(_G.Routes.ReparentMinimap) == "function" then
            pcall(_G.Routes.ReparentMinimap, _G.Routes, routesCanvas)
        end
        if type(_G.Routes.CVAR_UPDATE) == "function" and _G.GetCVar then
            pcall(_G.Routes.CVAR_UPDATE, _G.Routes, "CVAR_UPDATE", "rotateMinimap", _G.GetCVar("rotateMinimap"))
        end
        if type(_G.Routes.MINIMAP_UPDATE_ZOOM) == "function" then
            pcall(_G.Routes.MINIMAP_UPDATE_ZOOM, _G.Routes)
        end
        pcall(_G.Routes.DrawMinimapLines, _G.Routes, true)
    end

    -- GatherMate2 caches minimap size, scale, strata, frame level, and rotateMinimap.
    local aceAddon = LibStub("AceAddon-3.0", true)
    if aceAddon then
        local ok, gatherMate = pcall(aceAddon.GetAddon, aceAddon, "GatherMate2", true)
        if ok and gatherMate and gatherMate.GetModule then
            local okDisplay, display = pcall(gatherMate.GetModule, gatherMate, "Display", true)
            if okDisplay and display then
                if display.ReparentMinimapPins then
                    pcall(display.ReparentMinimapPins, display, _G.Minimap)
                end
                if display.ChangedVars and _G.GetCVar then
                    pcall(display.ChangedVars, display, "CVAR_UPDATE", "rotateMinimap", _G.GetCVar("rotateMinimap"))
                end
                if display.MinimapZoom then
                    pcall(display.MinimapZoom, display)
                end
                if display.UpdateMaps then
                    pcall(display.UpdateMaps, display)
                end
                if display.UpdateMiniMap then
                    pcall(display.UpdateMiniMap, display, true)
                end
                if display.UpdateIconPositions then
                    pcall(display.UpdateIconPositions, display)
                end
            end
        end
    end

    local hbdPins = LibStub("HereBeDragons-Pins-2.0", true)
    if hbdPins and hbdPins.SetMinimapObject then
        pcall(hbdPins.SetMinimapObject, hbdPins, _G.Minimap)
    end
end

local function ScheduleExternalOverlayRefreshes(owner)
    if owner and owner.LogHUDDebug then
        owner:LogHUDDebug("Scheduling external overlay refresh")
    end
    RefreshExternalMinimapOverlays()
    if owner and owner.hud and owner.hud.active then
        owner:RestoreThirdPartyMinimapOverlays()
        owner:ApplyHUDMousePassthrough()
        if owner.LogHUDSnapshot then
            owner:LogHUDSnapshot("Overlay refresh immediate")
        end
    end
    if _G.C_Timer and _G.C_Timer.After then
        local function scheduleDelayedRefresh(delay)
            _G.C_Timer.After(delay, function()
                if owner and owner.LogHUDDebug then
                    owner:LogHUDDebugf(false, "Running delayed external overlay refresh (+%.2fs)", delay)
                end
                RefreshExternalMinimapOverlays()
                if owner and owner.hud and owner.hud.active then
                    owner:RestoreThirdPartyMinimapOverlays()
                    owner:ApplyHUDMousePassthrough()
                    if owner.LogHUDSnapshot then
                        owner:LogHUDSnapshot(format("Overlay refresh +%.2fs", delay))
                    end
                end
            end)
        end
        scheduleDelayedRefresh(0.10)
        scheduleDelayedRefresh(0.35)
        scheduleDelayedRefresh(1.00)
    end
end

local function CopySessionItems(items)
    local copied = {}
    for itemID, entry in pairs(items or {}) do
        copied[itemID] = {
            itemLink = entry.itemLink,
            name = entry.name,
            qty = entry.qty or 0,
            totalValue = entry.totalValue or 0,
            iconTexture = entry.iconTexture,
        }
    end
    return copied
end

local function SetFrameMouseEnabled(frame, enabled)
    if not frame then return end
    if frame.EnableMouse then
        pcall(frame.EnableMouse, frame, enabled)
    end
    if frame.SetMouseClickEnabled then
        pcall(frame.SetMouseClickEnabled, frame, enabled)
    end
    if frame.SetMouseMotionEnabled then
        pcall(frame.SetMouseMotionEnabled, frame, enabled)
    end
    if frame.SetPropagateMouseClicks then
        pcall(frame.SetPropagateMouseClicks, frame, not enabled)
    end
    if frame.SetPropagateMouseMotion then
        pcall(frame.SetPropagateMouseMotion, frame, not enabled)
    end
end

local function WalkFrameTree(root, callback, depth)
    if not root or depth < 0 then return end
    callback(root)
    if depth == 0 or not root.GetChildren then return end
    for _, child in ipairs({ root:GetChildren() }) do
        WalkFrameTree(child, callback, depth - 1)
    end
end

local function IsGatheringOverlayName(globalName)
    if type(globalName) ~= "string" then return false end
    return globalName:find("^GatherMatePin")
        or globalName:find("^Gatherer")
        or globalName:find("^GatherLite")
end

local function BoolToDebugString(value)
    if value == nil then
        return "nil"
    end
    return value and "true" or "false"
end

local function SafeDebugString(value)
    if value == nil then
        return "nil"
    end

    local valueType = type(value)
    if valueType == "number" or valueType == "boolean" then
        return tostring(value)
    end

    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" then
        return text
    end

    return "<" .. valueType .. ">"
end

local function GetFrameDebugName(frame)
    if not frame then
        return "nil"
    end

    if frame.GetName then
        local name = frame:GetName()
        if name and name ~= "" then
            return name
        end
    end

    return SafeDebugString(frame)
end

local function CountChildren(frame)
    if not frame or not frame.GetChildren then
        return 0
    end

    local count = 0
    for _ in ipairs({ frame:GetChildren() }) do
        count = count + 1
    end
    return count
end

local function CollectGatheringOverlayStats()
    local stats = {
        total = 0,
        visible = 0,
        minimapParent = 0,
        uiParent = 0,
        otherParent = 0,
        samples = {},
    }

    for globalName, frame in pairs(_G) do
        if IsGatheringOverlayName(globalName) and type(frame) == "table" and frame.GetObjectType then
            stats.total = stats.total + 1
            if frame.IsShown and frame:IsShown() then
                stats.visible = stats.visible + 1
            end

            local parent = frame.GetParent and frame:GetParent() or nil
            if parent == _G.Minimap then
                stats.minimapParent = stats.minimapParent + 1
            elseif parent == UIParent then
                stats.uiParent = stats.uiParent + 1
            else
                stats.otherParent = stats.otherParent + 1
                if #stats.samples < 8 then
                    stats.samples[#stats.samples + 1] = format("%s -> %s", globalName, GetFrameDebugName(parent))
                end
            end
        end
    end

    return stats
end

local function SetFrameIgnoreParentAlpha(frame, enabled)
    if frame and frame.SetIgnoreParentAlpha then
        pcall(frame.SetIgnoreParentAlpha, frame, enabled)
    end
end

local function SetRegionsIgnoreParentAlpha(frame, enabled)
    if not frame or not frame.GetRegions then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.SetIgnoreParentAlpha then
            pcall(region.SetIgnoreParentAlpha, region, enabled)
        end
    end
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
    active                         = false,
    savedParent                    = nil,
    savedFrameStrata               = nil,
    savedFrameLevel                = nil,
    savedScale                     = nil,
    savedPoint                     = nil,
    savedRelativeTo                = nil,
    savedRelPoint                  = nil,
    savedX                         = nil,
    savedY                         = nil,
    savedAlpha                     = nil,
    savedMouseEnabled              = nil,
    savedMouseMotionEnabled        = nil,
    savedClusterMouseEnabled       = nil,
    savedClusterMouseMotionEnabled = nil,
    savedRotateMinimap             = nil,
    savedGetMinimapShape           = nil,
    savedMouseFrames               = nil,
    ringFrame                      = nil,
    overlayFrame                   = nil,
    gpsTicker                      = nil,
    compatibilityTicker            = nil,
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
        return format("%s%dg|r %s%ds|r %s%dc|r", GOLD_COLOR, g, SILVER_COLOR, s, COPPER_COLOR, c)
    elseif s > 0 then
        return format("%s%ds|r %s%dc|r", SILVER_COLOR, s, COPPER_COLOR, c)
    else
        return format("%s%dc|r", COPPER_COLOR, c)
    end
end

local function GetTrackerSettings()
    local db = GetDB()
    return {
        fontKey = db.trackerFont or "Friz Quadrata TT",
        fontSize = db.trackerFontSize or 12,
        outline = db.trackerFontOutline or "",
        backgroundAlpha = db.trackerBackgroundAlpha or 0.96,
        accent = db.trackerAccentColor or { r = 0.2, g = 0.75, b = 0.3, a = 0.95 },
        itemColumnWidth = db.trackerItemColumnWidth or 170,
        qtyColumnWidth = db.trackerQtyColumnWidth or 50,
        itemValueColumnWidth = db.trackerItemValueColumnWidth or 80,
        totalValueColumnWidth = db.trackerTotalValueColumnWidth or 90,
    }
end

local function GetGPHTickerInterval()
    local db = GetDB()
    local interval = tonumber(db.gphUpdateInterval) or GPS_TICKER_INTERVAL
    return max(MIN_GPH_TICKER_INTERVAL, interval)
end

local function GetTrackerSortState(owner)
    owner.trackerSort = owner.trackerSort or {
        key = "totalValue",
        ascending = false,
    }
    return owner.trackerSort
end

local function EnsureTrackerPulse(row)
    if row.flashOverlay then
        return row.flashOverlay, row.flashAnimation
    end

    local flash = row:CreateTexture(nil, "OVERLAY")
    flash:SetAllPoints(row)
    flash:SetColorTexture(0.25, 0.85, 0.35, 1)
    flash:SetAlpha(0)
    flash:Hide()

    local animation = flash:CreateAnimationGroup()
    local fadeIn = animation:CreateAnimation("Alpha")
    fadeIn:SetOrder(1)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.32)
    fadeIn:SetDuration(0.12)

    local fadeOut = animation:CreateAnimation("Alpha")
    fadeOut:SetOrder(2)
    fadeOut:SetFromAlpha(0.32)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.45)

    animation:SetScript("OnPlay", function()
        flash:Show()
    end)
    animation:SetScript("OnFinished", function()
        flash:SetAlpha(0)
        flash:Hide()
    end)

    row.flashOverlay = flash
    row.flashAnimation = animation
    return flash, animation
end

local function PlayTrackerRowPulse(row, isNew)
    if not row then return end
    local flash, animation = EnsureTrackerPulse(row)
    if flash then
        if isNew then
            flash:SetColorTexture(0.2, 0.85, 0.35, 1)
        else
            flash:SetColorTexture(0.95, 0.72, 0.2, 1)
        end
        flash:SetAlpha(0)
    end
    if animation then
        animation:Stop()
        animation:Play()
    end
end

local function CreateColumnHandle(parent)
    local handle = CreateFrame("Button", nil, parent)
    handle:SetWidth(10)

    local line = handle:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOP", handle, "TOP", 0, 2)
    line:SetPoint("BOTTOM", handle, "BOTTOM", 0, -2)
    line:SetWidth(2)
    line:SetColorTexture(0.42, 0.42, 0.48, 0.75)
    handle.line = line

    local glow = handle:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(handle)
    glow:SetColorTexture(0.2, 0.75, 0.3, 0.15)

    handle:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    return handle
end

local function CreateTrackerHeaderButton(parent, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(parent:GetHeight())
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetTextColor(0.75, 0.75, 0.75, 1)
    label:SetText(text)
    button.baseText = text
    button.label = label
    return button
end

function Gathering:LogHUDDebug(message)
    if not DebugConsole or type(DebugConsole.Log) ~= "function" then
        return false
    end

    return DebugConsole:Log(DEBUG_SOURCE_KEY, SafeDebugString(message), false)
end

function Gathering:LogHUDDebugf(shouldShow, messageFormat, ...)
    if not DebugConsole or type(DebugConsole.Logf) ~= "function" then
        return false
    end

    return DebugConsole:Logf(DEBUG_SOURCE_KEY, shouldShow, messageFormat, ...)
end

function Gathering:IsDebugEnabled()
    local options = GetOptions()
    return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
end

function Gathering:LogHUDSnapshot(label)
    if not self:IsDebugEnabled() then
        return
    end

    local mm = _G.Minimap
    if not mm then
        self:LogHUDDebug((label or "snapshot") .. " | minimap=nil")
        return
    end

    local point, relativeTo, relPoint, x, y = mm:GetPoint()
    local overlayStats = CollectGatheringOverlayStats()
    self:LogHUDDebugf(false,
        "%s | active=%s parent=%s point=%s/%s relTo=%s offset=(%s,%s) scale=%.3f size=%.1fx%.1f alpha=%.2f strata=%s level=%s shape=%s rotate=%s overlays=%d/%d",
        label or "snapshot",
        BoolToDebugString(self.hud.active),
        GetFrameDebugName(mm:GetParent()),
        SafeDebugString(point),
        SafeDebugString(relPoint),
        GetFrameDebugName(relativeTo),
        SafeDebugString(x),
        SafeDebugString(y),
        mm:GetScale() or 0,
        mm:GetWidth() or 0,
        mm:GetHeight() or 0,
        mm:GetAlpha() or 0,
        SafeDebugString(mm:GetFrameStrata()),
        SafeDebugString(mm:GetFrameLevel()),
        SafeDebugString(_G.GetMinimapShape and _G.GetMinimapShape() or nil),
        SafeDebugString(_G.GetCVar and _G.GetCVar("rotateMinimap") or nil),
        overlayStats.visible,
        overlayStats.total)
end

function Gathering:BuildDebugReport()
    local lines = {}
    local mm = _G.Minimap
    local cluster = _G.MinimapCluster
    local routes = _G.Routes
    local overlayStats = CollectGatheringOverlayStats()

    lines[#lines + 1] = "TwichUI Gathering HUD Debug"
    lines[#lines + 1] = format("Timestamp: %s", date and date("%Y-%m-%d %H:%M:%S") or format("%.3f", GetTime()))
    lines[#lines + 1] = ""
    lines[#lines + 1] = "HUD"
    lines[#lines + 1] = format("active=%s sessionActive=%s sessionPaused=%s compatibilityTicker=%s",
        BoolToDebugString(self.hud.active),
        BoolToDebugString(self.session.active),
        BoolToDebugString(self.session.pausedAt ~= nil),
        BoolToDebugString(self.hud.compatibilityTicker ~= nil))

    if mm then
        local point, relativeTo, relPoint, x, y = mm:GetPoint()
        lines[#lines + 1] = format("minimap parent=%s point=%s rel=%s relTo=%s offset=(%s,%s)",
            GetFrameDebugName(mm:GetParent()),
            SafeDebugString(point),
            SafeDebugString(relPoint),
            GetFrameDebugName(relativeTo),
            SafeDebugString(x),
            SafeDebugString(y))
        lines[#lines + 1] = format(
            "minimap size=%.1fx%.1f scale=%.3f effectiveScale=%.3f alpha=%.2f shown=%s children=%d",
            mm:GetWidth() or 0,
            mm:GetHeight() or 0,
            mm:GetScale() or 0,
            mm.GetEffectiveScale and mm:GetEffectiveScale() or 0,
            mm:GetAlpha() or 0,
            BoolToDebugString(mm:IsShown()),
            CountChildren(mm))
        lines[#lines + 1] = format("minimap strata=%s level=%s shape=%s rotateMinimap=%s mask=%s",
            SafeDebugString(mm:GetFrameStrata()),
            SafeDebugString(mm:GetFrameLevel()),
            SafeDebugString(_G.GetMinimapShape and _G.GetMinimapShape() or nil),
            SafeDebugString(_G.GetCVar and _G.GetCVar("rotateMinimap") or nil),
            SafeDebugString(mm.GetMaskTexture and mm:GetMaskTexture() or nil))

        if mm.pinPools then
            local activePools = {}
            for templateName, pinPool in pairs(mm.pinPools) do
                if pinPool and pinPool.EnumerateActive then
                    local count = 0
                    for _ in pinPool:EnumerateActive() do
                        count = count + 1
                    end
                    if count > 0 then
                        activePools[#activePools + 1] = format("%s=%d", SafeDebugString(templateName), count)
                    end
                end
            end

            if #activePools > 0 then
                table.sort(activePools)
                lines[#lines + 1] = "minimap active pinPools=" .. table.concat(activePools, ", ")
            else
                lines[#lines + 1] = "minimap active pinPools=<none>"
            end
        end
    else
        lines[#lines + 1] = "minimap=nil"
    end

    if cluster then
        lines[#lines + 1] = format("cluster parent=%s shown=%s mouse=%s motion=%s children=%d",
            GetFrameDebugName(cluster:GetParent()),
            BoolToDebugString(cluster:IsShown()),
            BoolToDebugString(cluster:IsMouseEnabled()),
            BoolToDebugString(cluster.IsMouseMotionEnabled and cluster:IsMouseMotionEnabled() or nil),
            CountChildren(cluster))
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "External Addons"
    lines[#lines + 1] = format("Routes loaded=%s reparent=%s draw=%s zoomHandler=%s cvarHandler=%s",
        BoolToDebugString(routes ~= nil),
        BoolToDebugString(routes and type(routes.ReparentMinimap) == "function" or false),
        BoolToDebugString(routes and type(routes.DrawMinimapLines) == "function" or false),
        BoolToDebugString(routes and type(routes.MINIMAP_UPDATE_ZOOM) == "function" or false),
        BoolToDebugString(routes and type(routes.CVAR_UPDATE) == "function" or false))

    do
        local aceAddon = LibStub("AceAddon-3.0", true)
        local gatherMateLoaded = false
        local gatherMateDisplay = nil
        if aceAddon then
            local ok, gatherMate = pcall(aceAddon.GetAddon, aceAddon, "GatherMate2", true)
            if ok and gatherMate then
                gatherMateLoaded = true
                if gatherMate.GetModule then
                    local okDisplay, display = pcall(gatherMate.GetModule, gatherMate, "Display", true)
                    if okDisplay then
                        gatherMateDisplay = display
                    end
                end
            end
        end

        lines[#lines + 1] = format(
            "GatherMate2 loaded=%s display=%s changedVars=%s updateMiniMap=%s updateIconPositions=%s",
            BoolToDebugString(gatherMateLoaded),
            BoolToDebugString(gatherMateDisplay ~= nil),
            BoolToDebugString(gatherMateDisplay and type(gatherMateDisplay.ChangedVars) == "function" or false),
            BoolToDebugString(gatherMateDisplay and type(gatherMateDisplay.UpdateMiniMap) == "function" or false),
            BoolToDebugString(gatherMateDisplay and type(gatherMateDisplay.UpdateIconPositions) == "function" or false))
    end

    lines[#lines + 1] = format(
        "overlay frames total=%d visible=%d parentedToMinimap=%d parentedToUIParent=%d parentedElsewhere=%d",
        overlayStats.total,
        overlayStats.visible,
        overlayStats.minimapParent,
        overlayStats.uiParent,
        overlayStats.otherParent)
    for _, sample in ipairs(overlayStats.samples) do
        lines[#lines + 1] = "  " .. sample
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Tracker"
    do
        local trackerSettings = GetTrackerSettings()
        local trackerFrame = self.trackerFrame
        local sortState = GetTrackerSortState(self)
        lines[#lines + 1] = format("tracker shown=%s size=%s x %s locked=%s sort=%s/%s",
            BoolToDebugString(trackerFrame and trackerFrame:IsShown() or false),
            SafeDebugString(trackerFrame and trackerFrame:GetWidth() or nil),
            SafeDebugString(trackerFrame and trackerFrame:GetHeight() or nil),
            BoolToDebugString(self:IsTrackerLocked()),
            SafeDebugString(sortState.key),
            BoolToDebugString(sortState.ascending))
        lines[#lines + 1] = format("tracker columns item=%d qty=%d itemValue=%d totalValue=%d",
            trackerSettings.itemColumnWidth,
            trackerSettings.qtyColumnWidth,
            trackerSettings.itemValueColumnWidth,
            trackerSettings.totalValueColumnWidth)
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Recent Log"
    local debugLines = DebugConsole and DebugConsole.GetLines and DebugConsole:GetLines(DEBUG_SOURCE_KEY) or nil
    if debugLines and #debugLines > 0 then
        for _, line in ipairs(debugLines) do
            lines[#lines + 1] = line
        end
    else
        lines[#lines + 1] = "<no log entries yet>"
    end

    return table.concat(lines, "\n")
end

local function GetTrackerFontPath(fontKey)
    local lsm = GetLSM()
    if lsm and lsm.Fetch then
        local ok, fontPath = pcall(lsm.Fetch, lsm, "font", fontKey)
        if ok and fontPath then
            return fontPath
        end
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function ApplyFontObject(fontString, fontPath, fontSize, outline)
    if fontString and fontString.SetFont then
        fontString:SetFont(fontPath, fontSize, outline)
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

local function GetBagQuantity(itemID, snapshot)
    local total = 0
    if snapshot then
        for bag = 0, NUM_BAGS - 1 do
            local bagInfo = snapshot[bag] or {}
            for _, slotInfo in pairs(bagInfo) do
                if slotInfo and slotInfo.itemID == itemID then
                    total = total + (slotInfo.count or 1)
                end
            end
        end
    else
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
    end
    return total
end

-- ============================================================
-- Session management
-- ============================================================
function Gathering:SaveSessionState()
    local db = GetDB()
    if not db then return end

    local sess = self.session
    db.sessionState = {
        hasSession = sess.startTime ~= nil,
        active = sess.active == true,
        elapsedSeconds = self:GetActiveSessionSeconds(),
        totalValue = sess.totalValue or 0,
        goldPerHour = sess.goldPerHour or 0,
        items = CopySessionItems(sess.items),
        savedAt = time and time() or nil,
    }
end

function Gathering:RestoreSessionState()
    local db = GetDB()
    local saved = db and db.sessionState
    if not saved or not saved.hasSession then
        return
    end

    local elapsedSeconds = saved.elapsedSeconds or 0
    if saved.active and saved.savedAt and time then
        elapsedSeconds = elapsedSeconds + max(0, time() - saved.savedAt)
    end

    self.session.active = saved.active == true
    self.session.startTime = GetTime()
    self.session.pausedAt = self.session.active and nil or GetTime()
    self.session.activeSeconds = elapsedSeconds
    self.session.items = CopySessionItems(saved.items)
    self.session.totalValue = saved.totalValue or 0
    self.session.goldPerHour = saved.goldPerHour or 0
    self.session.lastGPHUpdate = self.session.active and GetTime() or nil
end

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
    self:SaveSessionState()
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
    self:SaveSessionState()
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
        return
    end
    self:SaveSessionState()
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
    self:SaveSessionState()
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

    -- Get item info. GetItemInfo returns the formatted item link as its 2nd return value.
    -- C_Item.GetItemLink expects an ItemLocationMixin, not a raw itemID.
    local name, itemLink, _, _, _, _, _, _, _, iconTexture = GetItemInfo(itemID)
    if not itemLink then
        itemLink = "|Hitem:" .. itemID .. ":::::::::::::|h[" .. (name or "Unknown") .. "]|h"
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
    local pricePerUnit       = GetTSMItemPrice(itemID) or 0
    local batchValue         = pricePerUnit * qty
    local highValueThreshold = tonumber(db.highValueThreshold) or 0
    local isHighValue        = highValueThreshold > 0 and batchValue >= highValueThreshold

    -- Update session items
    local sess               = self.session
    local entry              = sess.items[itemID]
    local isNewEntry         = entry == nil
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
    self.pendingTrackerAnimations = self.pendingTrackerAnimations or {}
    self.pendingTrackerAnimations[itemID] = isNewEntry and "new" or "update"
    sess.totalValue = sess.totalValue + batchValue

    -- Update GPH
    self:UpdateGoldPerHour()

    -- Bag totals for notification
    local bagCount = GetBagQuantity(itemID, self.bagSnapshot)
    local bagValue = pricePerUnit * bagCount
    local priceSource = db.priceSource or "DBMarket"

    -- Send notification
    self:SendGatherNotification({
        itemLink    = itemLink,
        quantity    = qty,
        itemValue   = pricePerUnit,
        batchValue  = batchValue,
        bagCount    = bagCount,
        bagValue    = bagValue,
        priceSource = priceSource,
        iconTexture = iconTexture,
        isHighValue = isHighValue,
    })

    -- Refresh tracker if open
    if self.trackerFrame and self.trackerFrame:IsShown() then
        self:RefreshTrackerFrame()
    end
    self:SaveSessionState()
    self:RefreshDatatext()
end

-- ============================================================
-- Notification
-- ============================================================
function Gathering:SendGatherNotification(data)
    local NM = GetNotificationModule()
    if not NM then return end
    local db     = GetDB()

    ---@diagnostic disable-next-line: param-type-mismatch
    local widget = AceGUI:Create("TwichUI_GatheringNotification")
    if not widget then return end
    widget:SetGatherData(data)
    widget:SetDismissCallback(function()
        -- handled by notification frame
    end)

    local soundKey = (db.notificationSound and db.notificationSound ~= "__none") and db.notificationSound or nil
    if data.isHighValue and db.highValueSound and db.highValueSound ~= "__none" then
        soundKey = db.highValueSound
    end

    NM:TWICH_NOTIFICATION("TWICH_NOTIFICATION", widget, {
        displayDuration = db.notificationDuration or 6,
        soundKey        = soundKey,
    })
end

function Gathering:RestoreThirdPartyMinimapOverlays()
    local mm = _G.Minimap
    if not mm or not self.hud.active then return end

    for globalName, frame in pairs(_G) do
        if IsGatheringOverlayName(globalName) and type(frame) == "table" and frame.GetObjectType then
            pcall(function()
                frame:SetParent(mm)
                frame:SetFrameStrata(mm:GetFrameStrata())
                frame:SetFrameLevel(mm:GetFrameLevel() + 5)
                frame:SetAlpha(1)
                SetFrameIgnoreParentAlpha(frame, true)
                frame:Show()
                for _, region in ipairs({ frame:GetRegions() }) do
                    if region.SetAlpha then
                        region:SetAlpha(1)
                    end
                    if region.SetIgnoreParentAlpha then
                        region:SetIgnoreParentAlpha(true)
                    end
                    if region.Show then
                        region:Show()
                    end
                end
            end)
        end
    end

    if mm.Routes_Lines_Used then
        for _, texture in ipairs(mm.Routes_Lines_Used) do
            if texture then
                if texture.SetAlpha then
                    texture:SetAlpha(1)
                end
                if texture.SetIgnoreParentAlpha then
                    texture:SetIgnoreParentAlpha(true)
                end
                texture:Show()
            end
        end
    end
end

function Gathering:ApplyHUDMousePassthrough()
    if not self.hud.active then return end

    if not self.hud.savedMouseFrames then
        self.hud.savedMouseFrames = {}
    end

    local function rememberAndDisable(frame)
        if not frame or self.hud.savedMouseFrames[frame] ~= nil then return end
        self.hud.savedMouseFrames[frame] = {
            mouseEnabled = frame.IsMouseEnabled and frame:IsMouseEnabled() or false,
            mouseMotionEnabled = frame.IsMouseMotionEnabled and frame:IsMouseMotionEnabled() or false,
        }
        SetFrameMouseEnabled(frame, false)
    end

    WalkFrameTree(_G.Minimap, rememberAndDisable, 3)
    if _G.MinimapCluster then
        WalkFrameTree(_G.MinimapCluster, rememberAndDisable, 3)
    end
    if self.hud.overlayFrame then
        WalkFrameTree(self.hud.overlayFrame, rememberAndDisable, 3)
    end
end

function Gathering:RestoreHUDMouseState()
    if not self.hud.savedMouseFrames then return end
    for frame, state in pairs(self.hud.savedMouseFrames) do
        if frame then
            SetFrameMouseEnabled(frame, state and state.mouseEnabled ~= false)
            if state and frame.SetMouseMotionEnabled then
                pcall(frame.SetMouseMotionEnabled, frame, state.mouseMotionEnabled == true)
            end
        end
    end
    self.hud.savedMouseFrames = nil
end

function Gathering:RestoreOverlayAlphaInheritance()
    local mm = _G.Minimap
    if mm and mm.Routes_Lines_Used then
        for _, texture in ipairs(mm.Routes_Lines_Used) do
            if texture and texture.SetIgnoreParentAlpha then
                texture:SetIgnoreParentAlpha(false)
            end
        end
    end

    for globalName, frame in pairs(_G) do
        if IsGatheringOverlayName(globalName) and type(frame) == "table" and frame.GetObjectType then
            SetFrameIgnoreParentAlpha(frame, false)
            SetRegionsIgnoreParentAlpha(frame, false)
        end
    end
end

function Gathering:StartHUDCompatibilityTicker()
    if self.hud.compatibilityTicker then return end
    self.hud.compatibilityTicker = self:ScheduleRepeatingTimer(function()
        if not self.hud.active then return end
        RefreshExternalMinimapOverlays()
        self:RestoreThirdPartyMinimapOverlays()
        self:ApplyHUDMousePassthrough()
    end, HUD_COMPATIBILITY_TICK_INTERVAL)
end

function Gathering:StopHUDCompatibilityTicker()
    if self.hud.compatibilityTicker then
        self:CancelTimer(self.hud.compatibilityTicker)
        self.hud.compatibilityTicker = nil
    end
end

-- ============================================================
-- HUD (Farm Radar)
-- ============================================================
function Gathering:EnableHUD()
    if self.hud.active then return end
    local opts = GetOptions()
    local mm   = _G.Minimap
    if not mm then return end

    self:LogHUDDebug("EnableHUD started")

    -- Save current state so we can restore
    local point, relativeTo, relPoint, x, y = mm:GetPoint()
    self.hud.savedParent                    = mm:GetParent()
    self.hud.savedFrameStrata               = mm:GetFrameStrata()
    self.hud.savedFrameLevel                = mm:GetFrameLevel()
    self.hud.savedPoint                     = point or "TOPRIGHT"
    self.hud.savedRelativeTo                = relativeTo or UIParent
    self.hud.savedRelPoint                  = relPoint or "TOPRIGHT"
    self.hud.savedX                         = x or -20
    self.hud.savedY                         = y or -20
    self.hud.savedScale                     = mm:GetScale()
    self.hud.savedAlpha                     = mm:GetAlpha()
    self.hud.savedMouseEnabled              = mm:IsMouseEnabled()
    self.hud.savedMouseMotionEnabled        = mm.IsMouseMotionEnabled and mm:IsMouseMotionEnabled() or nil
    self.hud.savedClusterMouseEnabled       = _G.MinimapCluster and _G.MinimapCluster:IsMouseEnabled() or nil
    self.hud.savedClusterMouseMotionEnabled = _G.MinimapCluster and _G.MinimapCluster.IsMouseMotionEnabled and
    _G.MinimapCluster:IsMouseMotionEnabled() or nil
    self.hud.savedRotateMinimap             = _G.GetCVar and _G.GetCVar("rotateMinimap") or nil
    self.hud.savedGetMinimapShape           = _G.GetMinimapShape

    -- Ensure Blizzard base size before scaling (mirrors HorizonSuite's approach)
    mm:SetSize(HUD_MINIMAP_SIZE, HUD_MINIMAP_SIZE)

    -- Move minimap to center using HorizonSuite's taint-free proxy
    -- Do NOT change FrameStrata — leave minimap at its current strata so the
    -- ring (which will match that strata at level-1) correctly sits behind it.
    local hudSize = opts and opts:GetHudSize() or HUD_DEFAULT_SIZE
    local newScale = hudSize / HUD_MINIMAP_SIZE

    proxy.SetParent(mm, UIParent)
    proxy.ClearAllPoints(mm)
    proxy.SetPoint(mm, "CENTER", UIParent, "CENTER", 0, 0)
    mm:SetFrameStrata("LOW")
    mm:SetFrameLevel(2)
    proxy.SetScale(mm, newScale)

    if self.hud.overlayFrame then
        self.hud.overlayFrame:Hide()
    end

    -- Force circular shape for radar look
    mm:SetMaskTexture(186178)

    -- Several minimap overlay addons key their clipping math off GetMinimapShape().
    -- HorizonSuite changes the visual mask, but not the global shape API. While HUD is
    -- active, force the API to report a round minimap so Routes/GatherMate2 use the
    -- correct circular math.
    _G.GetMinimapShape = function()
        return "ROUND"
    end

    -- Terrain transparency — use Options getters so defaults apply correctly
    if opts and opts:GetHudTerrainTransparent() then
        mm:SetAlpha(opts:GetHudTerrainAlpha())
    else
        mm:SetAlpha(1.0)
    end

    -- FarmHUD behavior: rotate the minimap with the player and allow click-through.
    if _G.SetCVar then
        _G.SetCVar("rotateMinimap", "1")
    end
    if mm.SetMouseMotionEnabled then
        mm:SetMouseMotionEnabled(false)
    end
    if _G.MinimapCluster and _G.MinimapCluster.SetMouseMotionEnabled then
        _G.MinimapCluster:SetMouseMotionEnabled(false)
    end
    self.hud.active = true
    self:LogHUDSnapshot("EnableHUD geometry applied")
    self:ApplyHUDMousePassthrough()

    -- Hide HorizonSuite's decor frame (square border lines, zone/coord text overlays)
    -- so the minimap becomes a clean circular radar disc.
    -- Vista.ApplyOptions() called in DisableHUD will restore it.
    local vistaDecor = _G["HorizonSuiteVistaDecor"]
    if vistaDecor and vistaDecor:IsShown() then
        vistaDecor:Hide()
        self.hud.hidVistaDecor = true
    end
    -- Also hide Vista's own circular border frame to avoid a double-ring
    local vistaCBorder = _G["HorizonSuiteVistaCircularBorder"]
    if vistaCBorder and vistaCBorder:IsShown() then
        vistaCBorder:Hide()
        self.hud.hidVistaCBorder = true
    end

    -- Create ring decoration using Options getters for color
    local ringR, ringG, ringB, ringA = 0.0, 0.85, 1.0, 1.0
    if opts then ringR, ringG, ringB, ringA = opts:GetHudRingColor() end
    self:CreateHUDRing(hudSize, { r = ringR, g = ringG, b = ringB, a = ringA })

    -- Let external minimap overlay addons recalc against the resized/rotated HUD minimap.
    ScheduleExternalOverlayRefreshes(self)
    self:StartHUDCompatibilityTicker()
    self:LogHUDDebug("EnableHUD completed")

    -- Auto-start session
    self:StartSession()
end

function Gathering:DisableHUD()
    if not self.hud.active then return end
    local mm = _G.Minimap
    self:LogHUDDebug("DisableHUD started")
    self:LogHUDSnapshot("DisableHUD pre-restore")
    if mm then
        if _G.Routes and type(_G.Routes.ReparentMinimap) == "function" then
            pcall(_G.Routes.ReparentMinimap, _G.Routes, mm)
        end
        for globalName, frame in pairs(_G) do
            if IsGatheringOverlayName(globalName) and type(frame) == "table" and frame.GetObjectType then
                pcall(function()
                    frame:SetParent(mm)
                    frame:SetFrameStrata(mm:GetFrameStrata())
                    frame:SetFrameLevel(mm:GetFrameLevel() + 5)
                    frame:Show()
                end)
            end
        end

        if self.hud.savedParent then
            proxy.SetParent(mm, self.hud.savedParent)
        end
        proxy.ClearAllPoints(mm)
        proxy.SetPoint(mm,
            self.hud.savedPoint or "TOPRIGHT",
            self.hud.savedRelativeTo or UIParent,
            self.hud.savedRelPoint or "TOPRIGHT",
            self.hud.savedX or -20,
            self.hud.savedY or -20)
        proxy.SetScale(mm, self.hud.savedScale or 1.0)
        mm:SetFrameStrata(self.hud.savedFrameStrata or "MEDIUM")
        mm:SetFrameLevel(self.hud.savedFrameLevel or 1)
        mm:SetAlpha(self.hud.savedAlpha or 1.0)
        self:RestoreOverlayAlphaInheritance()
        self:RestoreHUDMouseState()
        mm:EnableMouse(self.hud.savedMouseEnabled ~= false)
        if mm.SetMouseMotionEnabled and self.hud.savedMouseMotionEnabled ~= nil then
            mm:SetMouseMotionEnabled(self.hud.savedMouseMotionEnabled)
        end
        if _G.MinimapCluster and self.hud.savedClusterMouseEnabled ~= nil then
            _G.MinimapCluster:EnableMouse(self.hud.savedClusterMouseEnabled)
        end
        if _G.MinimapCluster and _G.MinimapCluster.SetMouseMotionEnabled and self.hud.savedClusterMouseMotionEnabled ~= nil then
            _G.MinimapCluster:SetMouseMotionEnabled(self.hud.savedClusterMouseMotionEnabled)
        end
        if _G.SetCVar and self.hud.savedRotateMinimap ~= nil then
            _G.SetCVar("rotateMinimap", self.hud.savedRotateMinimap)
        end
        _G.GetMinimapShape = self.hud.savedGetMinimapShape

        if self.hud.overlayFrame then
            self.hud.overlayFrame:Hide()
        end

        -- Restore HorizonSuite's decor frame before calling ApplyOptions
        -- (ApplyOptions refreshes content inside decor but doesn't call decor:Show())
        if self.hud.hidVistaDecor then
            local vistaDecor = _G["HorizonSuiteVistaDecor"]
            if vistaDecor then vistaDecor:Show() end
            self.hud.hidVistaDecor = false
        end
        if self.hud.hidVistaCBorder then
            -- Vista.ApplyOptions will correctly show/hide this based on its settings
            self.hud.hidVistaCBorder = false
        end

        -- Let HorizonSuite re-apply its mask, scale, and border textures cleanly
        local addon = _G.HorizonSuite or _G.HorizonSuiteBeta or _G._HorizonSuite_Loading
        if addon and addon.Vista and addon.Vista.ApplyOptions then
            C_Timer.After(0, addon.Vista.ApplyOptions)
        end

        self.hud.active = false
        ScheduleExternalOverlayRefreshes(self)
    end

    self:StopHUDCompatibilityTicker()
    self:LogHUDDebug("DisableHUD completed")

    -- Destroy ring
    if self.hud.ringFrame then
        self.hud.ringFrame:Hide()
        self.hud.ringFrame = nil
    end

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

local HUD_RING_SEGMENTS = 64
local HUD_RING_ARC      = math.pi * 2

function Gathering:CreateHUDRing(hudSize, colorTable)
    local mm = _G.Minimap
    if not mm then return end

    local opts = GetOptions()
    local ringWidth = opts and opts:GetHudRingWidth() or 15

    local ring = self.hud.ringFrame
    if not ring then
        -- Fill UIParent so the line endpoints are never clipped by the container bounds.
        ring = CreateFrame("Frame", nil, UIParent)
        ring:SetAllPoints(UIParent)
        ring:SetFrameStrata("BACKGROUND")
        ring:SetFrameLevel(1)
        ring:EnableMouse(false)
        ring._lines = {}

        for i = 1, HUD_RING_SEGMENTS do
            ring._lines[i] = ring:CreateLine(nil, "OVERLAY")
        end

        self.hud.ringFrame = ring
    end

    local radius = (hudSize / 2) + (ringWidth / 2)
    for i, line in ipairs(ring._lines) do
        local startAngle = ((i - 1) / HUD_RING_SEGMENTS) * HUD_RING_ARC
        local endAngle   = (i / HUD_RING_SEGMENTS) * HUD_RING_ARC
        line:SetColorTexture(
            colorTable.r or 0.0,
            colorTable.g or 0.85,
            colorTable.b or 1.0,
            colorTable.a or 1.0)
        line:SetThickness(ringWidth)
        line:SetStartPoint("CENTER", mm, math.cos(startAngle) * radius, math.sin(startAngle) * radius)
        line:SetEndPoint("CENTER", mm, math.cos(endAngle) * radius, math.sin(endAngle) * radius)
        line:Show()
    end

    ring:Show()
end

function Gathering:RefreshHUDRing()
    if not self.hud.active or not self.hud.ringFrame then return end
    local opts = GetOptions()
    local r, g, b, a = 0.0, 0.85, 1.0, 1.0
    if opts then r, g, b, a = opts:GetHudRingColor() end
    local ringWidth = opts and opts:GetHudRingWidth() or 15
    local hudSize   = opts and opts:GetHudSize() or HUD_DEFAULT_SIZE
    local mm        = _G.Minimap
    if not mm then return end
    local radius = (hudSize / 2) + (ringWidth / 2)

    for i, line in ipairs(self.hud.ringFrame._lines or {}) do
        local startAngle = ((i - 1) / HUD_RING_SEGMENTS) * HUD_RING_ARC
        local endAngle   = (i / HUD_RING_SEGMENTS) * HUD_RING_ARC
        line:SetColorTexture(r, g, b, a)
        line:SetThickness(ringWidth)
        line:SetStartPoint("CENTER", mm, math.cos(startAngle) * radius, math.sin(startAngle) * radius)
        line:SetEndPoint("CENTER", mm, math.cos(endAngle) * radius, math.sin(endAngle) * radius)
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
    local trackerSettings = GetTrackerSettings()

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
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if not self:IsTrackerLocked() then
            frame:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveTrackerPosition()
    end)
    frame.titleBar = titleBar

    -- Gold accent strip
    local titleAccent = titleBar:CreateTexture(nil, "ARTWORK")
    titleAccent:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 0, 0)
    titleAccent:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", 0, 0)
    titleAccent:SetHeight(2)
    titleAccent:SetColorTexture(trackerSettings.accent.r, trackerSettings.accent.g, trackerSettings.accent.b,
        trackerSettings.accent.a)
    frame.titleAccent = titleAccent

    -- Icon
    local titleIcon = titleBar:CreateTexture(nil, "OVERLAY")
    titleIcon:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleIcon:SetSize(18, 18)
    titleIcon:SetTexture("Interface\\Icons\\inv_misc_herb_flamecap")
    titleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.titleIcon = titleIcon

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleIcon, "RIGHT", 8, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetText("Gathering Session")
    titleText:SetTextColor(1, 0.94, 0.82)
    frame.titleText = titleText

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
    frame.headerFrame = hdrs

    frame.headerItemButton = CreateTrackerHeaderButton(hdrs, "Item")
    frame.headerQtyButton = CreateTrackerHeaderButton(hdrs, "Qty")
    frame.headerItemValueButton = CreateTrackerHeaderButton(hdrs, "Item Value")
    frame.headerTotalValueButton = CreateTrackerHeaderButton(hdrs, "Total Value")
    frame.headerItemLabel = frame.headerItemButton.label
    frame.headerQtyLabel = frame.headerQtyButton.label
    frame.headerItemValueLabel = frame.headerItemValueButton.label
    frame.headerTotalValueLabel = frame.headerTotalValueButton.label

    frame.headerItemButton:SetScript("OnClick", function()
        self:ToggleTrackerSort("item")
    end)
    frame.headerQtyButton:SetScript("OnClick", function()
        self:ToggleTrackerSort("qty")
    end)
    frame.headerItemValueButton:SetScript("OnClick", function()
        self:ToggleTrackerSort("itemValue")
    end)
    frame.headerTotalValueButton:SetScript("OnClick", function()
        self:ToggleTrackerSort("totalValue")
    end)

    local itemHandle = CreateColumnHandle(hdrs)
    local qtyHandle = CreateColumnHandle(hdrs)
    local totalValueHandle = CreateColumnHandle(hdrs)
    frame.columnHandles = {
        item = itemHandle,
        qty = qtyHandle,
        totalValue = totalValueHandle,
    }
    itemHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:StartColumnResize("item")
        end
    end)
    qtyHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:StartColumnResize("qty")
        end
    end)
    totalValueHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:StartColumnResize("totalValue")
        end
    end)
    itemHandle:SetScript("OnMouseUp", function()
        self:StopColumnResize()
    end)
    qtyHandle:SetScript("OnMouseUp", function()
        self:StopColumnResize()
    end)
    totalValueHandle:SetScript("OnMouseUp", function()
        self:StopColumnResize()
    end)

    -- Divider line
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -88)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -88)
    divider:SetHeight(1)
    divider:SetColorTexture(0.25, 0.25, 0.30, 0.8)

    -- --------- Scroll area ---------
    local contentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    contentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -92)
    contentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 38)
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
    scrollFrame:SetScript("OnSizeChanged", function(sf, width)
        local contentWidth = max(1, (width or sf:GetWidth()) - 4)
        scrollChild:SetWidth(contentWidth)
    end)

    frame.scrollFrame = scrollFrame
    frame.scrollChild = scrollChild
    frame.rows        = {}

    -- --------- Footer actions ---------
    local footerBar   = CreateFrame("Frame", nil, frame)
    footerBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    footerBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 8)
    footerBar:SetHeight(24)
    frame.footerBar = footerBar

    local sessionToggleButton = CreateFrame("Button", nil, footerBar, "UIPanelButtonTemplate")
    sessionToggleButton:SetSize(116, 22)
    sessionToggleButton:SetPoint("LEFT", footerBar, "LEFT", 0, 0)
    sessionToggleButton:SetScript("OnClick", function()
        if not self.session.startTime or not self.session.active then
            self:StartSession()
        else
            self:PauseSession()
        end
        self:RefreshTrackerFrame()
    end)
    if T and T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(sessionToggleButton)
    end
    frame.sessionToggleButton = sessionToggleButton

    local resetSessionButton = CreateFrame("Button", nil, footerBar, "UIPanelButtonTemplate")
    resetSessionButton:SetSize(96, 22)
    resetSessionButton:SetPoint("LEFT", sessionToggleButton, "RIGHT", 8, 0)
    resetSessionButton:SetText("Reset Session")
    resetSessionButton:SetScript("OnClick", function()
        self:ResetSession()
        self:RefreshTrackerFrame()
    end)
    if T and T.Tools and T.Tools.UI and T.Tools.UI.SkinButton then
        T.Tools.UI.SkinButton(resetSessionButton)
    end
    frame.resetSessionButton = resetSessionButton

    -- --------- Resize handle ---------
    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    resizeHandle:SetSize(18, 18)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrab")
    resizeHandle:SetScript("OnMouseDown", function()
        if not self:IsTrackerLocked() then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SaveTrackerSize()
        self:RefreshTrackerFrame()
    end)
    frame.resizeHandle = resizeHandle

    -- --------- Empty label ---------
    local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("CENTER", contentInset, "CENTER", 0, 0)
    emptyText:SetTextColor(0.6, 0.6, 0.6, 1)
    emptyText:SetText("No items gathered this session.")
    frame.emptyText = emptyText

    self.trackerFrame = frame
    self:ApplyTrackerFrameStyle()
    self:RestoreTrackerPosition()
    self:UpdateTrackerInteractivity()
    self:UpdateTrackerSessionButtons()
    return frame
end

local ROW_HEIGHT    = 28
local ICON_ROW_SIZE = 20

local function ConfigureTrackerLabel(fontString, justifyH)
    if not fontString then return end
    fontString:SetJustifyH(justifyH or "LEFT")
    if fontString.SetJustifyV then
        fontString:SetJustifyV("MIDDLE")
    end
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end
    if fontString.SetMaxLines then
        fontString:SetMaxLines(1)
    end
end

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
    itemLabel:SetWidth(170)
    ConfigureTrackerLabel(itemLabel, "LEFT")
    row.itemLabel = itemLabel

    -- Qty
    local qtyLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    qtyLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
    qtyLabel:SetWidth(50)
    ConfigureTrackerLabel(qtyLabel, "CENTER")
    qtyLabel:SetTextColor(0.85, 0.85, 0.85, 1)
    row.qtyLabel = qtyLabel

    -- Item value (per unit)
    local itemValLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    itemValLabel:SetPoint("LEFT", row, "LEFT", 0, 0)
    itemValLabel:SetWidth(80)
    ConfigureTrackerLabel(itemValLabel, "CENTER")
    row.itemValLabel = itemValLabel

    -- Total value
    local totalValLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    totalValLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    totalValLabel:SetWidth(90)
    ConfigureTrackerLabel(totalValLabel, "RIGHT")
    totalValLabel:SetTextColor(0.9, 0.78, 0.2, 1)
    row.totalValLabel = totalValLabel

    row:SetScript("OnEnter", function(f)
        local entry = f.entryData
        if not entry then return end
        local gt = _G.GameTooltip
        gt:SetOwner(f, "ANCHOR_RIGHT")
        gt:ClearLines()
        if entry.itemLink and entry.itemLink:find("|Hitem:") then
            gt:SetHyperlink(entry.itemLink:match("|Hitem:[^|]+|h") or entry.itemLink)
        else
            gt:AddLine(entry.name or "Unknown Item")
        end
        gt:AddLine(" ")
        gt:AddDoubleLine("Quantity", tostring(entry.qty or 0), 0.82, 0.87, 0.94, 1, 1, 1)
        gt:AddDoubleLine("Total Value", FormatCopper(entry.totalValue or 0), 0.82, 0.87, 0.94, 1, 1, 1)
        gt:Show()
        row:SetBackdropBorderColor(0.2, 0.75, 0.3, 0.45)
    end)
    row:SetScript("OnLeave", function(f)
        _G.GameTooltip:Hide()
        row:SetBackdropBorderColor(borderR, borderG, borderB, 0.15)
    end)

    rows[index] = row
    return row
end

function Gathering:UpdateTrackerSessionButtons()
    local frame = self.trackerFrame
    if not frame then return end

    local sess = self.session
    if frame.sessionToggleButton then
        if not sess.startTime then
            frame.sessionToggleButton:SetText("Start Session")
        elseif sess.active then
            frame.sessionToggleButton:SetText("Pause Session")
        else
            frame.sessionToggleButton:SetText("Resume Session")
        end
    end

    if frame.resetSessionButton then
        if sess.startTime then
            if frame.resetSessionButton.Enable then
                frame.resetSessionButton:Enable()
            end
        else
            if frame.resetSessionButton.Disable then
                frame.resetSessionButton:Disable()
            end
        end
    end
end

function Gathering:ApplyTrackerFrameStyle()
    local frame = self.trackerFrame
    if not frame then return end

    local trackerSettings = GetTrackerSettings()
    local bgR, bgG, bgB, _, _, _, _ = GetBackdropColors()
    local fontPath = GetTrackerFontPath(trackerSettings.fontKey)
    local accent = trackerSettings.accent

    frame:SetBackdropColor(bgR, bgG, bgB, trackerSettings.backgroundAlpha)
    if frame.titleBar then
        frame.titleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75,
            min(1, trackerSettings.backgroundAlpha + 0.02))
    end
    if frame.titleAccent then
        frame.titleAccent:SetColorTexture(accent.r, accent.g, accent.b, accent.a)
    end

    ApplyFontObject(frame.titleText, fontPath, trackerSettings.fontSize + 2, trackerSettings.outline)
    ApplyFontObject(frame.gphLabel, fontPath, trackerSettings.fontSize, trackerSettings.outline)
    ApplyFontObject(frame.totalValueLabel, fontPath, trackerSettings.fontSize, trackerSettings.outline)
    ApplyFontObject(frame.sessionTimeLabel, fontPath, trackerSettings.fontSize, trackerSettings.outline)
    ApplyFontObject(frame.emptyText, fontPath, trackerSettings.fontSize, trackerSettings.outline)
    if frame.sessionToggleButton and frame.sessionToggleButton.GetFontString then
        ApplyFontObject(frame.sessionToggleButton:GetFontString(), fontPath, trackerSettings.fontSize - 1,
            trackerSettings.outline)
    end
    if frame.resetSessionButton and frame.resetSessionButton.GetFontString then
        ApplyFontObject(frame.resetSessionButton:GetFontString(), fontPath, trackerSettings.fontSize - 1,
            trackerSettings.outline)
    end

    local iconLeft = 4
    local iconRight = iconLeft + ICON_ROW_SIZE
    local itemLeft = iconRight + 4
    local itemRight = itemLeft + trackerSettings.itemColumnWidth
    local qtyLeft = itemRight + 8
    local qtyRight = qtyLeft + trackerSettings.qtyColumnWidth
    local itemValueLeft = qtyRight + 8
    local headerFrame = frame.headerFrame
    local headerWidth = headerFrame and headerFrame:GetWidth() or 0
    local totalValueLeft = max(itemValueLeft + trackerSettings.itemValueColumnWidth + 8,
        headerWidth - trackerSettings.totalValueColumnWidth)

    if frame.headerItemButton and headerFrame then
        frame.headerItemButton:ClearAllPoints()
        frame.headerItemButton:SetPoint("LEFT", headerFrame, "LEFT", 0, 0)
        frame.headerItemButton:SetPoint("RIGHT", headerFrame, "LEFT", qtyLeft - 8, 0)
    end
    if frame.headerQtyButton and headerFrame then
        frame.headerQtyButton:ClearAllPoints()
        frame.headerQtyButton:SetPoint("LEFT", headerFrame, "LEFT", qtyLeft, 0)
        frame.headerQtyButton:SetPoint("RIGHT", headerFrame, "LEFT", itemValueLeft - 8, 0)
    end
    if frame.headerItemValueButton and headerFrame then
        frame.headerItemValueButton:ClearAllPoints()
        frame.headerItemValueButton:SetPoint("LEFT", headerFrame, "LEFT", itemValueLeft, 0)
        frame.headerItemValueButton:SetPoint("RIGHT", headerFrame, "LEFT", totalValueLeft - 8, 0)
    end
    if frame.headerTotalValueButton and headerFrame then
        frame.headerTotalValueButton:ClearAllPoints()
        frame.headerTotalValueButton:SetPoint("LEFT", headerFrame, "LEFT", totalValueLeft, 0)
        frame.headerTotalValueButton:SetPoint("RIGHT", headerFrame, "RIGHT", 0, 0)
    end

    if frame.columnHandles and headerFrame then
        local handleHeight = headerFrame:GetHeight()
        if frame.columnHandles.item then
            frame.columnHandles.item:SetHeight(handleHeight)
            frame.columnHandles.item:ClearAllPoints()
            frame.columnHandles.item:SetPoint("LEFT", headerFrame, "LEFT", qtyLeft - 4, 0)
        end
        if frame.columnHandles.qty then
            frame.columnHandles.qty:SetHeight(handleHeight)
            frame.columnHandles.qty:ClearAllPoints()
            frame.columnHandles.qty:SetPoint("LEFT", headerFrame, "LEFT", itemValueLeft - 4, 0)
        end
        if frame.columnHandles.totalValue then
            frame.columnHandles.totalValue:SetHeight(handleHeight)
            frame.columnHandles.totalValue:ClearAllPoints()
            frame.columnHandles.totalValue:SetPoint("LEFT", headerFrame, "LEFT", totalValueLeft - 4, 0)
        end
    end

    for _, row in ipairs(frame.rows or {}) do
        ApplyFontObject(row.itemLabel, fontPath, trackerSettings.fontSize, trackerSettings.outline)
        ApplyFontObject(row.qtyLabel, fontPath, trackerSettings.fontSize, trackerSettings.outline)
        ApplyFontObject(row.itemValLabel, fontPath, trackerSettings.fontSize, trackerSettings.outline)
        ApplyFontObject(row.totalValLabel, fontPath, trackerSettings.fontSize, trackerSettings.outline)
        ConfigureTrackerLabel(row.itemLabel, "LEFT")
        ConfigureTrackerLabel(row.qtyLabel, "CENTER")
        ConfigureTrackerLabel(row.itemValLabel, "RIGHT")
        ConfigureTrackerLabel(row.totalValLabel, "RIGHT")

        row.itemLabel:SetWidth(trackerSettings.itemColumnWidth)
        row.qtyLabel:SetWidth(trackerSettings.qtyColumnWidth)
        row.itemValLabel:SetWidth(0)
        row.totalValLabel:SetWidth(0)

        row.itemLabel:ClearAllPoints()
        row.itemLabel:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)

        row.qtyLabel:ClearAllPoints()
        row.qtyLabel:SetPoint("LEFT", row, "LEFT", qtyLeft, 0)

        row.itemValLabel:ClearAllPoints()
        row.itemValLabel:SetPoint("LEFT", row, "LEFT", itemValueLeft, 0)
        row.itemValLabel:SetPoint("RIGHT", row, "LEFT", totalValueLeft - 8, 0)

        row.totalValLabel:ClearAllPoints()
        row.totalValLabel:SetPoint("LEFT", row, "LEFT", totalValueLeft, 0)
        row.totalValLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    end
end

function Gathering:UpdateTrackerInteractivity()
    local frame = self.trackerFrame
    if not frame then return end

    local unlocked = not self:IsTrackerLocked()
    if frame.titleBar then
        frame.titleBar:EnableMouse(unlocked)
    end
    if frame.resizeHandle then
        if unlocked then frame.resizeHandle:Show() else frame.resizeHandle:Hide() end
    end
    if frame.columnHandles then
        for _, handle in pairs(frame.columnHandles) do
            if unlocked then
                handle:EnableMouse(true)
                handle:Show()
            else
                handle:EnableMouse(false)
                handle:Hide()
            end
        end
    end
end

function Gathering:ToggleTrackerSort(key)
    local sortState = GetTrackerSortState(self)
    if sortState.key == key then
        sortState.ascending = not sortState.ascending
    else
        sortState.key = key
        sortState.ascending = (key == "item")
    end
    self:RefreshTrackerFrame()
end

function Gathering:UpdateTrackerHeaderSortIndicator()
    local frame = self.trackerFrame
    if not frame then return end

    local sortState = GetTrackerSortState(self)
    local arrow = sortState.ascending and " |cff8fd18f^|r" or " |cffe7c15av|r"
    local function apply(button, key)
        if not button or not button.label then return end
        local text = button.baseText or ""
        if sortState.key == key then
            text = text .. arrow
        end
        button.label:SetText(text)
    end

    apply(frame.headerItemButton, "item")
    apply(frame.headerQtyButton, "qty")
    apply(frame.headerItemValueButton, "itemValue")
    apply(frame.headerTotalValueButton, "totalValue")
end

function Gathering:StartColumnResize(columnKey)
    local frame = self.trackerFrame
    if not frame or self:IsTrackerLocked() then return end

    local db = GetDB()
    frame.activeColumnResize = {
        columnKey = columnKey,
        startX = _G.GetCursorPosition(),
        itemWidth = db.trackerItemColumnWidth or 170,
        qtyWidth = db.trackerQtyColumnWidth or 50,
        totalValueWidth = db.trackerTotalValueColumnWidth or 90,
    }
    frame:SetScript("OnUpdate", function()
        self:UpdateColumnResize()
    end)
end

function Gathering:UpdateColumnResize()
    local frame = self.trackerFrame
    local state = frame and frame.activeColumnResize
    if not frame or not state then return end

    local scale = frame:GetEffectiveScale()
    local cursorX = _G.GetCursorPosition()
    local delta = (cursorX - state.startX) / (scale > 0 and scale or 1)
    local db = GetDB()

    if state.columnKey == "item" then
        db.trackerItemColumnWidth = max(120, floor(state.itemWidth + delta + 0.5))
    elseif state.columnKey == "qty" then
        db.trackerQtyColumnWidth = max(40, floor(state.qtyWidth + delta + 0.5))
    elseif state.columnKey == "totalValue" then
        db.trackerTotalValueColumnWidth = max(70, floor(state.totalValueWidth - delta + 0.5))
    end

    self:RefreshTrackerFrame()
end

function Gathering:StopColumnResize()
    local frame = self.trackerFrame
    if not frame then return end
    frame:SetScript("OnUpdate", nil)
    frame.activeColumnResize = nil
end

function Gathering:ResetTrackerPosition()
    local db = GetDB()
    db.trackerPoint = nil
    db.trackerRelPoint = nil
    db.trackerX = nil
    db.trackerY = nil
    db.trackerWidth = nil
    db.trackerHeight = nil

    if self.trackerFrame then
        self.trackerFrame:ClearAllPoints()
        self.trackerFrame:SetSize(TRACKER_WIDTH, TRACKER_HEIGHT)
        self.trackerFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function Gathering:RefreshTrackerFrame()
    local frame = self.trackerFrame
    if not frame then return end

    local sess        = self.session
    local scrollChild = frame.scrollChild
    local rows        = frame.rows
    if frame.scrollFrame then
        scrollChild:SetWidth(max(1, frame.scrollFrame:GetWidth() - 26))
    end

    -- Build sorted item list
    local sorted = {}
    for itemID, entry in pairs(sess.items) do
        table.insert(sorted, { itemID = itemID, entry = entry })
    end
    local sortState = GetTrackerSortState(self)
    table.sort(sorted, function(a, b)
        local aEntry = a.entry or {}
        local bEntry = b.entry or {}
        local aValue
        local bValue

        if sortState.key == "item" then
            aValue = aEntry.name or ""
            bValue = bEntry.name or ""
        elseif sortState.key == "qty" then
            aValue = aEntry.qty or 0
            bValue = bEntry.qty or 0
        elseif sortState.key == "itemValue" then
            aValue = ((aEntry.qty or 0) > 0) and ((aEntry.totalValue or 0) / (aEntry.qty or 1)) or 0
            bValue = ((bEntry.qty or 0) > 0) and ((bEntry.totalValue or 0) / (bEntry.qty or 1)) or 0
        else
            aValue = aEntry.totalValue or 0
            bValue = bEntry.totalValue or 0
        end

        if aValue == bValue then
            return (aEntry.totalValue or 0) > (bEntry.totalValue or 0)
        end

        if sortState.ascending then
            return aValue < bValue
        end
        return aValue > bValue
    end)

    -- Show/hide empty text
    if #sorted == 0 then
        frame.emptyText:Show()
    else
        frame.emptyText:Hide()
    end

    -- Build rows
    for i, item in ipairs(sorted) do
        local row       = EnsureTrackerRow(scrollChild, rows, i)
        local entry     = item.entry
        local rowItemID = item.itemID
        row.entryData   = entry
        row.itemID      = rowItemID
        row.icon:SetTexture(entry.iconTexture)
        row.itemLabel:SetText(entry.itemLink or entry.name or "Unknown")

        row.qtyLabel:SetText(tostring(entry.qty or 0))

        -- Per-unit price
        local perUnit = (entry.qty and entry.qty > 0) and floor((entry.totalValue or 0) / entry.qty) or 0
        row.itemValLabel:SetText(FormatCopper(perUnit))
        row.totalValLabel:SetText(FormatCopper(entry.totalValue or 0))

        row:Show()

        local pendingPulse = self.pendingTrackerAnimations and self.pendingTrackerAnimations[rowItemID]
        if pendingPulse then
            PlayTrackerRowPulse(row, pendingPulse == "new")
            self.pendingTrackerAnimations[rowItemID] = nil
        end
    end

    self:ApplyTrackerFrameStyle()
    self:UpdateTrackerHeaderSortIndicator()

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
    self:UpdateTrackerSessionButtons()
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
    self:RefreshTrackerFrame()
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
    if self.hud.gpsTicker then
        self:CancelTimer(self.hud.gpsTicker)
        self.hud.gpsTicker = nil
    end
    self.hud.gpsTicker = self:ScheduleRepeatingTimer(function()
        if self.session.active then
            self:UpdateGoldPerHour()
        end
    end, GetGPHTickerInterval())
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
    self:RegisterEvent("PLAYER_LOGOUT", "OnPlayerLogout")
    self.bagSnapshot = TakeBagSnapshot()
    self:RestoreSessionState()
    self:StartGPHTicker()
    self:RefreshDatatext()
    self:LogHUDDebug("Gathering module enabled")
end

function Gathering:OnPlayerLogout()
    self.isLoggingOut = true
    self:SaveSessionState()
end

function Gathering:OnDisable()
    if self.hud.active then
        self:DisableHUD()
    end
    if not self.isLoggingOut then
        self:SaveSessionState()
    end
    self:UnregisterAllEvents()
    self:StopGPHTicker()
    self:StopHUDCompatibilityTicker()
    if self.hud.overlayFrame and _G.Routes and type(_G.Routes.ReparentMinimap) == "function" then
        pcall(_G.Routes.ReparentMinimap, _G.Routes, _G.Minimap)
    end
    self:LogHUDDebug("Gathering module disabled")
    self.isLoggingOut = nil
end

if DebugConsole and DebugConsole.RegisterSource then
    DebugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
        title = "Gathering",
        order = 20,
        aliases = { "gather", "gatheringhud", "gatherhud" },
        maxLines = DEBUG_LOG_LIMIT,
        isEnabled = function()
            local options = GetOptions()
            return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
        end,
        buildReport = function()
            return Gathering:BuildDebugReport()
        end,
    })
end
