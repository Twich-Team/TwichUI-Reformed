-- Portal Authority Mythic+ teleport dock.

PortalAuthority = PortalAuthority or {}

local DEBUG = false

local function debugVisibility(message)
    if DEBUG then
        print(string.format("|cffff7f50Portal Authority Dock Debug:|r %s", message))
    end
end

local function PA_PerfBegin(scopeName, explicitState)
    if PortalAuthority and PortalAuthority.PerfBegin then
        return PortalAuthority:PerfBegin(scopeName, explicitState)
    end
    return nil, nil
end

local function PA_PerfEnd(scopeName, startedAt, stateLabel)
    if startedAt ~= nil and PortalAuthority and PortalAuthority.PerfEnd then
        PortalAuthority:PerfEnd(scopeName, startedAt, stateLabel)
    end
end

local function PA_PerfDockEventScope(event)
    if event == "SPELL_UPDATE_COOLDOWN" then
        return "dock_event_spell_update_cooldown"
    end
    if event == "SPELLS_CHANGED" then
        return "dock_event_spells_changed"
    end
    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_UPDATE_RESTING" then
        return "dock_event_zone"
    end
    if event == "PLAYER_ENTERING_WORLD" then
        return "dock_event_player_entering_world"
    end
    return "dock_event_other"
end

local function PA_CpuDiagCount(scopeName, detailKey)
    if PortalAuthority and PortalAuthority.CpuDiagCount then
        PortalAuthority:CpuDiagCount(scopeName, detailKey)
    end
end

local function PA_CpuDiagRecordDispatcherEvent(dispatcherName, eventName)
    if PortalAuthority and PortalAuthority.CpuDiagRecordDispatcherEvent then
        PortalAuthority:CpuDiagRecordDispatcherEvent(dispatcherName, eventName)
    end
end

local function PA_CpuDiagRecordTrigger(triggerKey)
    if PortalAuthority and PortalAuthority.CpuDiagRecordTrigger then
        PortalAuthority:CpuDiagRecordTrigger(triggerKey)
    end
end

local function PA_CpuDiagDockTriggerKey(event)
    if event == "PLAYER_UPDATE_RESTING" then
        return "resting_update"
    end
    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        return "zone_local"
    end
    return nil
end

local function shouldBeginDockDrag(button)
    if button == "LeftButton" then
        return true
    end

    return false
end

local function makeClickThrough(frame, visited)
    if not frame or not frame.GetChildren then
        return
    end

    visited = visited or {}
    if visited[frame] then
        return
    end
    visited[frame] = true

    local children = { frame:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child.EnableMouse then
            child:EnableMouse(false)
        end
        if child.SetMouseClickEnabled then
            child:SetMouseClickEnabled(false)
        end
        if child.SetMouseMotionEnabled then
            child:SetMouseMotionEnabled(false)
        end
        makeClickThrough(child, visited)
    end
end

local function isFrameActuallyVisible(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end
    if frame.IsVisible then
        return frame:IsVisible() and true or false
    end
    return true
end

local function isDungeonsAndRaidsWindowOpen()
    local pve = _G and _G.PVEFrame or nil
    if isFrameActuallyVisible(pve) then
        return true
    end
    local lfdParent = _G and _G.LFDParentFrame or nil
    if isFrameActuallyVisible(lfdParent) then
        return true
    end
    return false
end

local function canShowDock()
    local db = PortalAuthorityDB or PortalAuthority.defaults
    if not db.dockEnabled then
        return false, "dock disabled"
    end
    if db.dockLocked == false then
        return true, "dock unlocked override"
    end
    if db.dockGizmoMode and not isDungeonsAndRaidsWindowOpen() then
        return false, "gizmo mode (dungeons & raids closed)"
    end
    if not db.dockGizmoMode then
        if db.dockHideInCombat and InCombatLockdown() then
            return false, "hide in combat"
        end
        if db.dockHideInMajorCity and IsResting() then
            return false, "hide in major city"
        end

        local inInstance, instanceType = IsInInstance()
        if db.dockHideInDungeon and inInstance and (instanceType == "party" or instanceType == "raid") then
            return false, "hide in dungeon"
        end
    end

    return true, "visible"
end

local function requestDockVisibilityRefresh()
    if not PortalAuthority then
        return
    end
    if PortalAuthority.UpdateDockVisibility then
        PortalAuthority:UpdateDockVisibility(true)
    elseif PortalAuthority.RefreshDockVisibility then
        PortalAuthority:RefreshDockVisibility(true)
    end
end

local function hideGameTooltipIfOwnedBy(owner)
    if not GameTooltip then
        return
    end
    local currentOwner = GameTooltip.GetOwner and GameTooltip:GetOwner() or nil
    if owner == nil or currentOwner == owner then
        GameTooltip:Hide()
    end
end

local function hookDockGizmoVisibilityFrame(frame)
    if not frame or not frame.HookScript then
        return false
    end
    if frame._paDockGizmoHooked then
        return false
    end
    frame._paDockGizmoHooked = true
    frame:HookScript("OnShow", function()
        local perfStart, perfState = PA_PerfBegin("callback_class_ui_hook")
        PA_CpuDiagCount("callback_class_ui_hook", "dock_gizmo_frame_onshow")
        requestDockVisibilityRefresh()
        PA_PerfEnd("callback_class_ui_hook", perfStart, perfState)
    end)
    frame:HookScript("OnHide", function()
        local perfStart, perfState = PA_PerfBegin("callback_class_ui_hook")
        PA_CpuDiagCount("callback_class_ui_hook", "dock_gizmo_frame_onhide")
        requestDockVisibilityRefresh()
        PA_PerfEnd("callback_class_ui_hook", perfStart, perfState)
    end)
    return true
end

local function isDockGizmoRelevantPanelFrame(frame)
    if not frame then
        return false
    end
    local targets = {
        _G and _G.PVEFrame or nil,
        _G and _G.LFDParentFrame or nil,
    }
    for i = 1, #targets do
        local target = targets[i]
        if target then
            if frame == target then
                return true
            end
            if frame.IsDescendantOf and frame:IsDescendantOf(target) then
                return true
            end
            if target.IsDescendantOf and target:IsDescendantOf(frame) then
                return true
            end
        end
    end

    local frameName = frame.GetName and frame:GetName() or ""
    return frameName == "PVEFrame" or frameName == "LFDParentFrame"
end

function PortalAuthority:HookDockGizmoModeWindow()
    local hookedAny = false
    local frameNames = { "PVEFrame", "LFDParentFrame" }
    for i = 1, #frameNames do
        local frame = _G and _G[frameNames[i]] or nil
        if hookDockGizmoVisibilityFrame(frame) then
            hookedAny = true
        end
    end

    -- If we just attached hooks while one of the target windows is already open,
    -- force an immediate visibility refresh so Gizmo mode responds without delay.
    if hookedAny and isDungeonsAndRaidsWindowOpen() then
        requestDockVisibilityRefresh()
    end

    if not self._paDockGizmoUIPanelHooked and hooksecurefunc then
        self._paDockGizmoUIPanelHooked = true
        hooksecurefunc("ShowUIPanel", function(frame)
            local perfStart, perfState = PA_PerfBegin("callback_class_ui_hook")
            if isDockGizmoRelevantPanelFrame(frame) then
                PA_CpuDiagCount("callback_class_ui_hook", "dock_showuipanel")
                requestDockVisibilityRefresh()
            end
            PA_PerfEnd("callback_class_ui_hook", perfStart, perfState)
        end)
        hooksecurefunc("HideUIPanel", function(frame)
            local perfStart, perfState = PA_PerfBegin("callback_class_ui_hook")
            if isDockGizmoRelevantPanelFrame(frame) then
                PA_CpuDiagCount("callback_class_ui_hook", "dock_hideuipanel")
                requestDockVisibilityRefresh()
            end
            PA_PerfEnd("callback_class_ui_hook", perfStart, perfState)
        end)
    end
end
local function round(value)
    if not value then
        return 0
    end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function clamp(value, minValue, maxValue, fallback)
    local n = tonumber(value)
    if n == nil then
        n = tonumber(fallback) or minValue
    end
    if n < minValue then
        n = minValue
    elseif n > maxValue then
        n = maxValue
    end
    return n
end

local function getDockLabelControlRanges(iconSize)
    local resolvedIconSize = math.max(16, math.floor(tonumber(iconSize) or 36))
    local maxGap = math.max(8, math.floor((resolvedIconSize * 1.10) + 0.5))
    local maxNudge = math.max(4, math.floor((resolvedIconSize * 0.50) + 0.5))
    return maxGap, maxNudge
end

local DOCK_SPACING_CROSS = {
    MIN_SPACING_X = -600,
    MAX_SPACING_X = 160,
    MIN_SPACING_Y = -200,
    MAX_SPACING_Y = 200,
    ARM_LENGTH = 110,
    ARM_THICKNESS = 2,
    ARM_HIT_THICKNESS = 16,
    CENTER_SIZE = 8,
    DRAG_PIXELS_PER_STEP = 8,
    SHIFT_DRAG_MULT = 1.8,   -- finer
    ALT_DRAG_MULT = 0.5,     -- coarser
    WHEEL_BASE_STEP = 2,
    WHEEL_SHIFT_STEP = 1,    -- finer
    WHEEL_ALT_STEP = 4,      -- coarse
    READOUT_HOLD = 0.7,
    READOUT_FADE = 0.2,
    CURSOR_X = "Interface\\CURSOR\\UI-Cursor-SizeRight",
    CURSOR_Y = "Interface\\CURSOR\\UI-Cursor-SizeRight",
    CURSOR_GENERIC = "Interface\\CURSOR\\UI-Cursor-Move",
}
local DOCK_UNLOCK_POPUP_HOLD = 2.7
local DOCK_UNLOCK_POPUP_FADE = 0.3
local DOCK_UNLOCK_POPUP_FAST_FADE = 0.2

local DOCK_TEXT_DIRECTION_CROSS = {
    ARM_LENGTH = DOCK_SPACING_CROSS.ARM_LENGTH,
    ARM_THICKNESS = DOCK_SPACING_CROSS.ARM_THICKNESS,
    ARM_HIT_THICKNESS = DOCK_SPACING_CROSS.ARM_HIT_THICKNESS,
    CENTER_SIZE = DOCK_SPACING_CROSS.CENTER_SIZE,
    PAIR_GAP = 18,
    DEADZONE_PIXELS = 10,
    READOUT_HOLD = 0.7,
    READOUT_FADE = 0.2,
    CURSOR_X = DOCK_SPACING_CROSS.CURSOR_X,
    CURSOR_Y = DOCK_SPACING_CROSS.CURSOR_Y,
    CURSOR_GENERIC = DOCK_SPACING_CROSS.CURSOR_GENERIC,
}

local function dockCrossPairOffsetX()
    return (DOCK_SPACING_CROSS.ARM_LENGTH + DOCK_TEXT_DIRECTION_CROSS.PAIR_GAP) / 2
end

local function normalizeDockTextDirection(direction, fallback)
    local d = string.upper(tostring(direction or fallback or "BOTTOM"))
    if d == "LEFT"
        or d == "TOP"
        or d == "RIGHT"
        or d == "BOTTOM"
        or d == "INNER_TOP"
        or d == "INNER_BOTTOM"
        or d == "CENTER"
    then
        return d
    end
    return string.upper(tostring(fallback or "BOTTOM"))
end

local function dockTextDirectionLabel(direction)
    local d = normalizeDockTextDirection(direction, "BOTTOM")
    if d == "LEFT" then return "Left" end
    if d == "TOP" then return "Top" end
    if d == "RIGHT" then return "Right" end
    if d == "INNER_TOP" then return "Inner Top" end
    if d == "INNER_BOTTOM" then return "Inner Bottom" end
    if d == "CENTER" then return "Center" end
    return "Bottom"
end

local function normalizeDockSimpleLayoutMode(mode, fallback)
    local m = string.upper(tostring(mode or fallback or "GRID"))
    if m == "HORIZONTAL" then
        m = "HORIZONTAL_ROW"
    elseif m == "VERTICAL" then
        m = "VERTICAL_COLUMN"
    end
    if m ~= "HORIZONTAL_ROW" and m ~= "VERTICAL_COLUMN" and m ~= "GRID" then
        m = tostring(fallback or "GRID")
    end
    return m
end

local function resolveDockSimpleLayoutModeFromDB(db, defaults)
    local fallback = (defaults and defaults.dockSimpleLayoutMode) or "GRID"
    if type(db) ~= "table" then
        return normalizeDockSimpleLayoutMode(db, fallback)
    end
    local resolved
    if db.dockSimpleLayoutMode ~= nil then
        resolved = normalizeDockSimpleLayoutMode(db.dockSimpleLayoutMode, fallback)
    else
        resolved = normalizeDockSimpleLayoutMode(db.dockSimpleLayoutModePersist, fallback)
    end
    db.dockSimpleLayoutMode = resolved
    db.dockSimpleLayoutModePersist = resolved
    return resolved
end

local function getDockSpacingAxisApplicability(modeOrDB, defaults)
    local mode
    if type(modeOrDB) == "table" then
        mode = resolveDockSimpleLayoutModeFromDB(modeOrDB, defaults)
    else
        local fallback = (defaults and defaults.dockSimpleLayoutMode) or "GRID"
        mode = normalizeDockSimpleLayoutMode(modeOrDB, fallback)
    end

    local xActive = true
    local yActive = true
    if mode == "HORIZONTAL_ROW" then
        yActive = false
    elseif mode == "VERTICAL_COLUMN" then
        xActive = false
    end
    return mode, xActive, yActive
end

local function dockSpacingModeLabel(mode)
    if mode == "HORIZONTAL_ROW" then
        return "Row"
    elseif mode == "VERTICAL_COLUMN" then
        return "Column"
    end
    return "Grid"
end

local function normalizeDockLabelMode(mode, fallback)
    if mode == false then
        return "OFF"
    end
    if mode == true then
        return "OUTSIDE"
    end
    local m = string.upper(tostring(mode or fallback or "OUTSIDE"))
    if m ~= "OFF" and m ~= "OUTSIDE" and m ~= "INSIDE" then
        m = string.upper(tostring(fallback or "OUTSIDE"))
    end
    if m ~= "OFF" and m ~= "OUTSIDE" and m ~= "INSIDE" then
        m = "OUTSIDE"
    end
    return m
end

local function normalizeDockSortMode(mode, fallback)
    local m = string.upper(tostring(mode or fallback or "ROW_ORDER"))
    if m == "TYPE" then
        m = "TYPE_ID"
    elseif m == "ROW" then
        m = "ROW_ORDER"
    end
    if m ~= "TYPE_ID" and m ~= "COOLDOWN" and m ~= "ROW_ORDER" then
        m = string.upper(tostring(fallback or "ROW_ORDER"))
    end
    if m == "TYPE" then
        m = "TYPE_ID"
    elseif m == "ROW" then
        m = "ROW_ORDER"
    end
    if m ~= "TYPE_ID" and m ~= "COOLDOWN" and m ~= "ROW_ORDER" then
        m = "ROW_ORDER"
    end
    return m
end

local function normalizeDockVisibilityMode(mode, fallback)
    local resolved = string.upper(tostring(mode or fallback or "NORMAL"))
    if resolved ~= "NORMAL" and resolved ~= "HIDE" then
        resolved = string.upper(tostring(fallback or "NORMAL"))
    end
    if resolved ~= "NORMAL" and resolved ~= "HIDE" then
        resolved = "NORMAL"
    end
    return resolved
end

local function normalizeDockLabelSide(side, fallback)
    local s = string.upper(tostring(side or fallback or "BOTTOM"))
    if s ~= "BOTTOM" and s ~= "TOP" and s ~= "LEFT" and s ~= "RIGHT" and s ~= "CENTER" then
        s = string.upper(tostring(fallback or "BOTTOM"))
    end
    if s ~= "BOTTOM" and s ~= "TOP" and s ~= "LEFT" and s ~= "RIGHT" and s ~= "CENTER" then
        s = "BOTTOM"
    end
    return s
end

local function isOutsideDockLabelSide(side)
    return side == "BOTTOM" or side == "TOP" or side == "LEFT" or side == "RIGHT"
end

local function normalizeDockOutsideLabelSide(side, fallback)
    local resolvedFallback = string.upper(tostring(fallback or "BOTTOM"))
    if not isOutsideDockLabelSide(resolvedFallback) then
        resolvedFallback = "BOTTOM"
    end

    local resolved = string.upper(tostring(side or resolvedFallback))
    if not isOutsideDockLabelSide(resolved) then
        resolved = resolvedFallback
    end
    if not isOutsideDockLabelSide(resolved) then
        resolved = "BOTTOM"
    end
    return resolved
end

local function resolveDockLabelModeFromDB(db, defaults)
    local fallback = (defaults and defaults.dockLabelMode) or "OUTSIDE"
    if type(db) ~= "table" then
        return normalizeDockLabelMode(db, fallback)
    end
    local liveRaw = db.dockLabelMode
    local persistRaw = db.dockLabelModePersist
    if normalizeDockLabelMode(liveRaw or "", fallback) == "OFF" or normalizeDockLabelMode(persistRaw or "", fallback) == "OFF" then
        db.dockHideDungeonName = true
    end
    if db.dockHideDungeonName then
        db.dockLabelMode = "OFF"
        db.dockLabelModePersist = "OFF"
        return "OFF"
    end
    local live = db.dockLabelMode
    local persisted = db.dockLabelModePersist
    local resolvedLive = (live ~= nil) and normalizeDockLabelMode(live, fallback) or nil
    local resolvedPersist = (persisted ~= nil) and normalizeDockLabelMode(persisted, fallback) or nil
    local resolved
    if resolvedLive == "OFF" or resolvedPersist == "OFF" then
        resolved = "OFF"
    elseif resolvedLive ~= nil then
        resolved = resolvedLive
    elseif resolvedPersist ~= nil then
        resolved = resolvedPersist
    else
        resolved = normalizeDockLabelMode(fallback, fallback)
    end
    db.dockLabelMode = resolved
    db.dockLabelModePersist = resolved
    return resolved
end

local function resolveDockLabelSideFromDB(db, defaults, labelMode)
    local fallback = (defaults and defaults.dockLabelSide) or "BOTTOM"
    local outsideFallback = (defaults and defaults.dockLabelSideOutsidePersist) or fallback
    local resolvedMode = normalizeDockLabelMode(labelMode or (type(db) == "table" and db.dockLabelMode or nil), (defaults and defaults.dockLabelMode) or "OUTSIDE")
    if type(db) ~= "table" then
        local resolvedValue = normalizeDockLabelSide(db, fallback)
        if resolvedMode == "OUTSIDE" and not isOutsideDockLabelSide(resolvedValue) then
            resolvedValue = normalizeDockOutsideLabelSide(nil, outsideFallback)
        end
        return resolvedValue
    end
    local rememberedOutside = normalizeDockOutsideLabelSide(db.dockLabelSideOutsidePersist, outsideFallback)
    if not isOutsideDockLabelSide(db.dockLabelSideOutsidePersist) then
        db.dockLabelSideOutsidePersist = rememberedOutside
    end
    local resolved
    if db.dockLabelSide ~= nil then
        resolved = normalizeDockLabelSide(db.dockLabelSide, fallback)
    elseif db.dockLabelSidePersist ~= nil then
        resolved = normalizeDockLabelSide(db.dockLabelSidePersist, fallback)
    else
        resolved = normalizeDockLabelSide(fallback, fallback)
    end
    if resolvedMode == "OUTSIDE" then
        if not isOutsideDockLabelSide(resolved) then
            resolved = rememberedOutside
        end
        resolved = normalizeDockOutsideLabelSide(resolved, rememberedOutside)
        db.dockLabelSideOutsidePersist = resolved
    end
    db.dockLabelSide = resolved
    db.dockLabelSidePersist = resolved
    return resolved
end

local function resolveDockLabelSideNoWrite(db, defaults, labelMode)
    local fallback = (defaults and defaults.dockLabelSide) or "BOTTOM"
    local outsideFallback = (defaults and defaults.dockLabelSideOutsidePersist) or fallback
    local resolvedMode = normalizeDockLabelMode(labelMode or (type(db) == "table" and db.dockLabelMode or nil), (defaults and defaults.dockLabelMode) or "OUTSIDE")
    if type(db) ~= "table" then
        local resolvedValue = normalizeDockLabelSide(db, fallback)
        if resolvedMode == "OUTSIDE" and not isOutsideDockLabelSide(resolvedValue) then
            resolvedValue = normalizeDockOutsideLabelSide(nil, outsideFallback)
        end
        return resolvedValue
    end
    local rememberedOutside = normalizeDockOutsideLabelSide(db.dockLabelSideOutsidePersist, outsideFallback)
    local resolved
    if db.dockLabelSide ~= nil then
        resolved = normalizeDockLabelSide(db.dockLabelSide, fallback)
    elseif db.dockLabelSidePersist ~= nil then
        resolved = normalizeDockLabelSide(db.dockLabelSidePersist, fallback)
    else
        resolved = normalizeDockLabelSide(fallback, fallback)
    end
    if resolvedMode == "OUTSIDE" then
        if not isOutsideDockLabelSide(resolved) then
            resolved = rememberedOutside
        end
        resolved = normalizeDockOutsideLabelSide(resolved, rememberedOutside)
    end
    return resolved
end

local function getDockDiagLabelModeOverride()
    if PortalAuthority then
        return PortalAuthority._dockDiagLabelMode
    end
    return nil
end

local function getDockDiagSortModeOverride()
    if PortalAuthority then
        return PortalAuthority._dockDiagSortMode
    end
    return nil
end

local function getDockDiagVisibilityOverride()
    if PortalAuthority then
        return PortalAuthority._dockDiagVisibilityMode
    end
    return nil
end

local function normalizeDockLabelRenderMode(mode, fallback)
    local resolved = string.upper(tostring(mode or fallback or "NORMAL"))
    if resolved ~= "NORMAL" and resolved ~= "BLANK" and resolved ~= "PLAIN" then
        resolved = string.upper(tostring(fallback or "NORMAL"))
    end
    if resolved ~= "NORMAL" and resolved ~= "BLANK" and resolved ~= "PLAIN" then
        resolved = "NORMAL"
    end
    return resolved
end

local function getDockDiagLabelRenderOverride()
    if PortalAuthority then
        return PortalAuthority._dockDiagLabelRenderMode
    end
    return nil
end

local function getEffectiveDockLabelRenderMode()
    return normalizeDockLabelRenderMode(getDockDiagLabelRenderOverride(), "NORMAL")
end

local function getEffectiveDockLabelMode(db, defaults)
    local override = getDockDiagLabelModeOverride()
    if override ~= nil then
        return normalizeDockLabelMode(override, (defaults and defaults.dockLabelMode) or "OUTSIDE")
    end
    return resolveDockLabelModeFromDB(db, defaults)
end

local function getEffectiveDockLabelSide(db, defaults, labelMode)
    if getDockDiagLabelModeOverride() ~= nil then
        return resolveDockLabelSideNoWrite(db, defaults, labelMode)
    end
    return resolveDockLabelSideFromDB(db, defaults, labelMode)
end

local function shouldShowDockLabels(db, labelMode)
    if getDockDiagLabelModeOverride() ~= nil then
        return labelMode ~= "OFF"
    end
    return (labelMode ~= "OFF") and not (db.dockHideDungeonName and true or false)
end

local function getEffectiveDockSortMode(db, defaults)
    local override = getDockDiagSortModeOverride()
    if override ~= nil then
        return normalizeDockSortMode(override, (defaults and defaults.dockSortMode) or "ROW_ORDER")
    end
    local raw = (type(db) == "table") and db.dockSortMode or db
    return normalizeDockSortMode(raw, (defaults and defaults.dockSortMode) or "ROW_ORDER")
end

local function setDockCrossCursor(cursorPath)
    if cursorPath and SetCursor then
        pcall(SetCursor, cursorPath)
        return
    end
    if ResetCursor then
        ResetCursor()
    end
end

function PortalAuthority:EnsureDockCrossContainer(parentDockFrame)
    local dock = parentDockFrame or self.dockFrame
    if not dock then
        return nil
    end

    local container = self.dockCrossContainer
    if not container then
        container = CreateFrame("Frame", nil, dock)
        container:EnableMouse(false)
        container:Hide()
        self.dockCrossContainer = container
    elseif container:GetParent() ~= dock then
        container:SetParent(dock)
    end

    local crossSize = math.max(
        DOCK_SPACING_CROSS.ARM_LENGTH + 12,
        DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH + 12
    )
    local pairWidth = (dockCrossPairOffsetX() * 2) + crossSize

    container:ClearAllPoints()
    container:SetPoint("CENTER", dock, "CENTER", 0, 0)
    container:SetSize(pairWidth, crossSize)
    container:SetFrameStrata(dock:GetFrameStrata())
    container:SetFrameLevel(dock:GetFrameLevel() + 9)

    return container
end

local function dockSpacingCrossDragUnits(deltaPixels, pixelsPerStep, axis)
    local px = tonumber(deltaPixels) or 0
    local perStep = math.max(1, tonumber(pixelsPerStep) or 1)
    local sign = px < 0 and -1 or 1
    local raw = math.abs(px) / perStep
    local units = raw

    -- Y gets a slightly stronger ramp than X so vertical spacing feels a touch more responsive.
    if axis == "x" then
        if raw <= 8 then
            units = raw
        elseif raw <= 20 then
            units = 8 + ((raw - 8) * 1.4)
        else
            units = 24.8 + ((raw - 20) * 1.9)
        end
    elseif axis == "y" then
        if raw <= 8 then
            units = raw
        elseif raw <= 20 then
            units = 8 + ((raw - 8) * 1.45)
        else
            units = 25.4 + ((raw - 20) * 1.95)
        end
    end

    return sign * round(units)
end

local function isSpellAvailable(spellID)
    if type(spellID) ~= "number" then
        return false
    end

    if C_Spell and C_Spell.GetSpellInfo then
        return C_Spell.GetSpellInfo(spellID) ~= nil
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID) ~= nil
    end

    return true
end

local function getSpellCooldownData(spellID)
    if type(spellID) ~= "number" then
        return 0, 0
    end

    if C_Spell and C_Spell.GetSpellCooldown then
        local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
        if type(cooldownInfo) == "table" then
            local startTime = cooldownInfo.startTime or cooldownInfo.start or 0
            local duration = cooldownInfo.duration or 0
            return startTime, duration
        end
    end

    if GetSpellCooldown then
        local startTime, duration = GetSpellCooldown(spellID)
        return startTime or 0, duration or 0
    end

    return 0, 0
end

local function getSpellNameByID(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return ""
    end
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if type(name) == "string" then
            return name
        end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if type(name) == "string" then
            return name
        end
    end
    return ""
end

local function getSpellTextureByID(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    if GetSpellTexture then
        return GetSpellTexture(spellID)
    end
    return nil
end

local function getCooldownRemaining(spellID)
    local startTime, duration = getSpellCooldownData(spellID)
    if not startTime or not duration or duration <= 0 then
        return 0
    end
    local now = GetTime and GetTime() or 0
    return math.max(0, (startTime + duration) - now)
end

local function buildCategoryOrderValue(category)
    if category == "portals" then return 1 end
    if category == "teleports" then return 2 end
    if category == "mplus" then return 3 end
    return 4
end

function PortalAuthority:QueueDockUpdate()
    self.pendingDockUpdate = true
end

function PortalAuthority:QueueDockVisibilityRefresh()
    self.pendingDockVisibilityRefresh = true
end

function PortalAuthority:SetDockCombatVisibilityDriverEnabled(enabled)
    if not self.dockFrame or not RegisterStateDriver or not UnregisterStateDriver then
        return
    end

    if enabled then
        if not self.dockVisibilityDriverActive then
            RegisterStateDriver(self.dockFrame, "visibility", "[combat] hide; show")
            self.dockVisibilityDriverActive = true
        end
    elseif self.dockVisibilityDriverActive then
        UnregisterStateDriver(self.dockFrame, "visibility")
        self.dockVisibilityDriverActive = false
    end
end

function PortalAuthority:ApplyDockCombatVisibilityDriver()
    local db = PortalAuthorityDB or self.defaults
    self:SetDockCombatVisibilityDriverEnabled(db.dockEnabled and db.dockHideInCombat)
end

function PortalAuthority:Dock_GetPreviewSpellID(slotIndex)
    if not self._dockPreviewSpellIDs then
        self._dockPreviewSpellIDs = {}
        local spellMap = self.SpellMap or {}
        for spellID, info in pairs(spellMap) do
            local sid = tonumber(spellID)
            if sid and info and (info.category == "portals" or info.category == "teleports" or info.category == "mplus") then
                table.insert(self._dockPreviewSpellIDs, sid)
            end
        end
        table.sort(self._dockPreviewSpellIDs)
    end

    local list = self._dockPreviewSpellIDs
    if not list or #list == 0 then
        return 0
    end
    local i = ((math.max(1, tonumber(slotIndex) or 1) - 1) % #list) + 1
    return list[i] or 0
end

function PortalAuthority:Dock_BuildEnabledEntries(includeTestMode)
    local db = PortalAuthorityDB or self.defaults
    local entries = {}
    local spellMap = self.SpellMap or {}
    local slots = db.dockSlots or {}

    for i = 1, 10 do
        local slot = slots[i]
        if type(slot) ~= "table" then
            slot = { enabled = false, selection = "CUSTOM", spellID = 0, name = "" }
        end

        local enabled = slot.enabled and true or false
        local spellID = math.max(0, math.floor(tonumber(slot.spellID) or 0))
        local useSlot = includeTestMode or (enabled and spellID > 0)
        if useSlot then
            if spellID <= 0 then
                spellID = self:Dock_GetPreviewSpellID(i)
            end
            local mapEntry = spellMap[spellID]
            local name = tostring(slot.name or "")
            if name == "" then
                name = getSpellNameByID(spellID)
                if name == "" and mapEntry and mapEntry.dest then
                    name = tostring(mapEntry.dest)
                end
            end
            table.insert(entries, {
                slotIndex = i,
                spellID = spellID,
                selection = tostring(slot.selection or "CUSTOM"),
                name = name,
                category = (mapEntry and mapEntry.category) or "custom",
                useItemID = (mapEntry and tonumber(mapEntry.useItemID)) or nil,
                isPreview = includeTestMode and not enabled or false,
            })
        end
    end

    return entries
end

function PortalAuthority:Dock_SortEntries(entries)
    local db = PortalAuthorityDB or self.defaults
    local mode = getEffectiveDockSortMode(db, self.defaults or {})
    for i = 1, #entries do
        entries[i]._cooldownRemaining = 0
        if mode == "COOLDOWN" then
            entries[i]._cooldownRemaining = getCooldownRemaining(entries[i].spellID)
        end
    end

    table.sort(entries, function(a, b)
        if mode == "ROW_ORDER" then
            return a.slotIndex < b.slotIndex
        elseif mode == "COOLDOWN" then
            if a._cooldownRemaining ~= b._cooldownRemaining then
                return a._cooldownRemaining < b._cooldownRemaining
            end
            return a.slotIndex < b.slotIndex
        end

        local ac = buildCategoryOrderValue(a.category)
        local bc = buildCategoryOrderValue(b.category)
        if ac ~= bc then
            return ac < bc
        end
        if a.spellID ~= b.spellID then
            return a.spellID < b.spellID
        end
        return a.slotIndex < b.slotIndex
    end)

    return entries
end

function PortalAuthority:Dock_GetEntriesSignature(entries)
    local parts = {}
    for i = 1, #entries do
        local entry = entries[i]
        parts[#parts + 1] = string.format("%d:%d", entry.slotIndex or 0, entry.spellID or 0)
    end
    return table.concat(parts, "|")
end

local function applyAcronymStyle(fontString, renderMode)
    local db = PortalAuthorityDB or PortalAuthority.defaults
    local resolvedRenderMode = normalizeDockLabelRenderMode(renderMode, "NORMAL")
    local fontPath = db.dockFontPath
    if not fontPath or fontPath == "" then
        fontPath = PortalAuthority:GetGlobalFontPath()
    end
    local outline = db.dockTextOutline
    if resolvedRenderMode == "PLAIN" then
        outline = ""
    end
    fontString:SetFont(fontPath, db.dockFontSize, outline)

    local c = db.dockFontColor
    fontString:SetTextColor(c.r, c.g, c.b, c.a)

    if db.dockTextShadow and resolvedRenderMode ~= "PLAIN" then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(db.dockShadowOffsetX, db.dockShadowOffsetY)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

local function buildDockLabelRenderedText(text, renderMode)
    if normalizeDockLabelRenderMode(renderMode, "NORMAL") == "BLANK" then
        return ""
    end
    return tostring(text or "")
end

local function buildDockLabelStyleSignature(db, renderMode)
    local fontPath = db.dockFontPath
    if not fontPath or fontPath == "" then
        fontPath = PortalAuthority:GetGlobalFontPath()
    end

    local c = db.dockFontColor or {}
    local resolvedRenderMode = normalizeDockLabelRenderMode(renderMode, "NORMAL")
    local outline = db.dockTextOutline
    local shadowEnabled = db.dockTextShadow and true or false
    local shadowX = tonumber(db.dockShadowOffsetX) or 0
    local shadowY = tonumber(db.dockShadowOffsetY) or 0
    if resolvedRenderMode == "PLAIN" then
        outline = ""
        shadowEnabled = false
        shadowX = 0
        shadowY = 0
    end
    return string.format(
        "%s\31%s\31%d\31%s\31%.4f\31%.4f\31%.4f\31%.4f\31%s\31%.4f\31%.4f",
        tostring(resolvedRenderMode),
        tostring(fontPath or ""),
        math.floor(tonumber(db.dockFontSize) or 0),
        tostring(outline or ""),
        tonumber(c.r) or 1,
        tonumber(c.g) or 1,
        tonumber(c.b) or 1,
        tonumber(c.a) or 1,
        tostring(shadowEnabled),
        shadowX,
        shadowY
    )
end

local function getDockButtonLabelCache(btn)
    if not btn then
        return nil
    end

    local cache = btn._paDockLabelCache
    if not cache then
        cache = {}
        btn._paDockLabelCache = cache
    end
    return cache
end

local function dockLabelNumbersEqual(a, b)
    if a == b then
        return true
    end
    if a == nil or b == nil then
        return false
    end
    return math.abs((tonumber(a) or 0) - (tonumber(b) or 0)) < 0.01
end

local function releaseDockButtonLabelMoveActive(btn)
    if not btn or not btn.labelArea or not btn.labelArea._paLabelMoveActive then
        return
    end

    btn.labelArea._paLabelMoveActive = nil
    if PortalAuthority then
        local activeCount = tonumber(PortalAuthority._paDockLabelAnimActiveCount) or 0
        PortalAuthority._paDockLabelAnimActiveCount = math.max(0, activeCount - 1)
    end
end

local function clearDockButtonLabelPositionState(btn)
    if not btn then
        return
    end

    btn._lastLabelCx = nil
    btn._lastLabelCy = nil
    btn._animFromLabelCx = nil
    btn._animFromLabelCy = nil

    local cache = btn._paDockLabelCache
    if cache then
        cache.labelCenterX = nil
        cache.labelCenterY = nil
    end
end

local function invalidateDockButtonLabelCache(btn)
    if not btn then
        return
    end

    if btn.labelArea then
        if btn.labelArea._paLabelMoveAG and btn.labelArea._paLabelMoveAG.IsPlaying and btn.labelArea._paLabelMoveAG:IsPlaying() then
            btn.labelArea._paLabelMoveAG:Stop()
        end
        releaseDockButtonLabelMoveActive(btn)
        if btn.labelArea._paLabelSettleAG and btn.labelArea._paLabelSettleAG.IsPlaying and btn.labelArea._paLabelSettleAG:IsPlaying() then
            btn.labelArea._paLabelSettleAG:Stop()
        end
    end

    clearDockButtonLabelPositionState(btn)

    if PortalAuthority and (tonumber(PortalAuthority._paDockLabelAnimActiveCount) or 0) == 0 then
        PortalAuthority._paDockLabelSettlePending = nil
    end

    local cache = getDockButtonLabelCache(btn)
    cache.valid = false
    cache.text = nil
    cache.visible = nil
    cache.styleSignature = nil
    cache.areaWidth = nil
    cache.areaHeight = nil
    cache.areaAnchorPoint = nil
    cache.areaAnchorRelativeTo = nil
    cache.areaAnchorRelativePoint = nil
    cache.areaAnchorX = nil
    cache.areaAnchorY = nil
    cache.padLeft = nil
    cache.padRight = nil
    cache.padTop = nil
    cache.padBottom = nil
    cache.contentWidth = nil
    cache.justifyH = nil
    cache.justifyV = nil
    cache.labelCenterX = nil
    cache.labelCenterY = nil
end

local function applyDockButtonLabelState(btn, state)
    if not btn or not btn.label or not btn.labelArea then
        return false
    end

    local cache = getDockButtonLabelCache(btn)
    local label = btn.label
    local labelArea = btn.labelArea
    local force = state.force or not cache.valid
    local visible = state.visible and true or false
    local text = tostring(state.text or "")
    local styleSignature = state.styleSignature
    local geometryChanged = false

    if visible and state.areaWidth ~= nil then
        geometryChanged =
            force
            or not dockLabelNumbersEqual(cache.areaWidth, state.areaWidth)
            or not dockLabelNumbersEqual(cache.areaHeight, state.areaHeight)
            or cache.areaAnchorPoint ~= state.areaAnchorPoint
            or cache.areaAnchorRelativeTo ~= state.areaAnchorRelativeTo
            or cache.areaAnchorRelativePoint ~= state.areaAnchorRelativePoint
            or not dockLabelNumbersEqual(cache.areaAnchorX, state.areaAnchorX)
            or not dockLabelNumbersEqual(cache.areaAnchorY, state.areaAnchorY)
            or not dockLabelNumbersEqual(cache.padLeft, state.padLeft)
            or not dockLabelNumbersEqual(cache.padRight, state.padRight)
            or not dockLabelNumbersEqual(cache.padTop, state.padTop)
            or not dockLabelNumbersEqual(cache.padBottom, state.padBottom)
            or not dockLabelNumbersEqual(cache.contentWidth, state.contentWidth)
            or cache.justifyH ~= state.justifyH
            or cache.justifyV ~= state.justifyV

        if geometryChanged then
            labelArea:ClearAllPoints()
            labelArea:SetSize(state.areaWidth, state.areaHeight)
            labelArea:SetPoint(
                state.areaAnchorPoint,
                state.areaAnchorRelativeTo,
                state.areaAnchorRelativePoint,
                state.areaAnchorX,
                state.areaAnchorY
            )

            label:ClearAllPoints()
            label:SetPoint("TOPLEFT", labelArea, "TOPLEFT", state.padLeft, -state.padTop)
            label:SetPoint("BOTTOMRIGHT", labelArea, "BOTTOMRIGHT", -state.padRight, state.padBottom)
            label:SetWordWrap(false)
            label:SetMaxLines(1)
            label:SetWidth(math.max(1, state.contentWidth - 1))
            label:SetWidth(state.contentWidth)
            if state.justifyH == "LEFT" or state.justifyH == "RIGHT" then
                label:SetJustifyH(state.justifyH == "LEFT" and "RIGHT" or "LEFT")
            end
            label:SetJustifyH(state.justifyH)
            label:SetJustifyV(state.justifyV)

            cache.areaWidth = state.areaWidth
            cache.areaHeight = state.areaHeight
            cache.areaAnchorPoint = state.areaAnchorPoint
            cache.areaAnchorRelativeTo = state.areaAnchorRelativeTo
            cache.areaAnchorRelativePoint = state.areaAnchorRelativePoint
            cache.areaAnchorX = state.areaAnchorX
            cache.areaAnchorY = state.areaAnchorY
            cache.padLeft = state.padLeft
            cache.padRight = state.padRight
            cache.padTop = state.padTop
            cache.padBottom = state.padBottom
            cache.contentWidth = state.contentWidth
            cache.justifyH = state.justifyH
            cache.justifyV = state.justifyV
        end
    end

    if not visible then
        if force or cache.visible ~= false then
            label:Hide()
            labelArea:Hide()
        end

        cache.valid = true
        cache.visible = false
        cache.text = nil
        cache.styleSignature = nil
        cache.areaWidth = nil
        cache.areaHeight = nil
        cache.areaAnchorPoint = nil
        cache.areaAnchorRelativeTo = nil
        cache.areaAnchorRelativePoint = nil
        cache.areaAnchorX = nil
        cache.areaAnchorY = nil
        cache.padLeft = nil
        cache.padRight = nil
        cache.padTop = nil
        cache.padBottom = nil
        cache.contentWidth = nil
        cache.justifyH = nil
        cache.justifyV = nil
        cache.labelCenterX = nil
        cache.labelCenterY = nil
        clearDockButtonLabelPositionState(btn)
        return geometryChanged
    end

    local styleChanged = force or cache.styleSignature ~= styleSignature
    local textChanged = force or cache.text ~= text
    local visibilityChanged = force or cache.visible ~= true
    local needsTextApply = geometryChanged or textChanged

    if styleChanged then
        applyAcronymStyle(label, state.renderMode)
    end
    if needsTextApply then
        label:SetText(text)
    end
    if visibilityChanged then
        label:Show()
        labelArea:Show()
    end

    cache.valid = true
    cache.visible = true
    cache.text = text
    cache.styleSignature = styleSignature
    if state.labelCenterX ~= nil then
        cache.labelCenterX = state.labelCenterX
    end
    if state.labelCenterY ~= nil then
        cache.labelCenterY = state.labelCenterY
    end
    return geometryChanged
end

local function formatCooldownTime(remaining)
    if remaining >= 3600 then
        return string.format("%dh", math.ceil(remaining / 3600))
    end
    if remaining >= 60 then
        return string.format("%dm", math.ceil(remaining / 60))
    end
    if remaining >= 10 then
        return tostring(math.ceil(remaining))
    end
    if remaining > 0 then
        return string.format("%.1f", remaining)
    end
    return ""
end

local function updateCooldownText(btn)
    if not btn or not btn.cooldownText then
        return
    end

    local ok, remaining, expired = pcall(function()
        local now = GetTime()
        local rem = math.max(0, (btn.cooldownEndTime or 0) - now)
        return rem, rem <= 0
    end)

    if not ok or expired then
        btn.cooldownText:Hide()
        btn.cooldownText:SetText("")
        btn:SetScript("OnUpdate", nil)
        btn.cooldownEndTime = nil
        return
    end

    btn.cooldownText:SetText(formatCooldownTime(remaining))
    btn.cooldownText:Show()
end

local function fitHorizontalLabel(btn, text, maxWidth)
    local db = PortalAuthorityDB or PortalAuthority.defaults
    local fontPath = db.dockFontPath
    if not fontPath or fontPath == "" then
        fontPath = PortalAuthority:GetGlobalFontPath()
    end

    btn.label:SetText(text)
    btn.label:SetWidth(maxWidth)
    btn.label:SetWordWrap(false)
    btn.label:SetMaxLines(1)

    local fontSize = db.dockFontSize
    local minSize = 8
    while fontSize > minSize do
        btn.label:SetFont(fontPath, fontSize, db.dockTextOutline)
        if btn.label:GetUnboundedStringWidth() <= maxWidth then
            break
        end
        fontSize = fontSize - 1
    end

    if fontSize == minSize then
        btn.label:SetFont(fontPath, minSize, db.dockTextOutline)
    end
end

local function getHorizontalFontSize(text, maxWidth)
    local db = PortalAuthorityDB or PortalAuthority.defaults
    local fontPath = db.dockFontPath
    if not fontPath or fontPath == "" then
        fontPath = PortalAuthority:GetGlobalFontPath()
    end

    local probe = PortalAuthority._dockMeasureLabel
    if not probe and PortalAuthority.dockFrame then
        probe = PortalAuthority.dockFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        probe:Hide()
        probe:SetAlpha(0)
        probe:SetText("")
        PortalAuthority._dockMeasureLabel = probe
    end
    if not probe then
        return db.dockFontSize
    end

    probe:SetText(text or "")
    probe:SetWordWrap(false)
    probe:SetMaxLines(1)

    local fontSize = db.dockFontSize
    local minSize = 8
    while fontSize > minSize do
        probe:SetFont(fontPath, fontSize, db.dockTextOutline)
        if probe:GetUnboundedStringWidth() <= maxWidth then
            break
        end
        fontSize = fontSize - 1
    end

    return math.max(minSize, fontSize)
end

local function applyNameTextLayout(btn, text, layout)
    if not btn or not btn.label then
        return
    end

    local label = btn.label
    label:SetText(text or "")
    label:ClearAllPoints()
    label:SetMaxLines(1)
    label:SetWordWrap(false)

    if layout and layout.mode == "VERTICAL" and layout.container then
        local container = layout.container
        local justify = (layout.textSide == "RIGHT") and "LEFT" or "RIGHT"

        container:ClearAllPoints()
        container:SetHeight(layout.rowHeight)
        container:SetWidth(layout.width)
        if layout.textSide == "RIGHT" then
            container:SetPoint("LEFT", layout.anchorFrame, "LEFT", 0, layout.yOffset)
        else
            container:SetPoint("RIGHT", layout.anchorFrame, "RIGHT", 0, layout.yOffset)
        end

        label:SetWidth(layout.width)
        if layout.textSide == "RIGHT" then
            label:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            label:SetPoint("RIGHT", container, "RIGHT", 0, 0)
        end
        label:SetJustifyH(justify)
        label:SetJustifyV("MIDDLE")
        return
    end

    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
end

function PortalAuthority:RefreshDockVisibility(force)
    local perfStart, perfState = PA_PerfBegin("dock_refresh_visibility")
    local function finish(...)
        PA_PerfEnd("dock_refresh_visibility", perfStart, perfState)
        return ...
    end

    if not self.dockFrame then
        return finish()
    end

    if InCombatLockdown() then
        self:QueueDockVisibilityRefresh()
        return finish()
    end

    self._dockDiagVisibilityRefreshCount = (tonumber(self._dockDiagVisibilityRefreshCount) or 0) + 1
    self.pendingDockVisibilityRefresh = false

    local db = PortalAuthorityDB or self.defaults
    if db.dockEnabled == false then
        self._dockDiagNaturalVisibilityReason = "dock disabled"
        self._dockDiagEffectiveVisibilityReason = "dock disabled"
        self._dockDiagLastVisibilityReason = "dock disabled"
        self:SetDockCombatVisibilityDriverEnabled(false)
        self.dockFrame:Hide()
        if self.UpdateDockOnUpdateState then
            self:UpdateDockOnUpdateState()
        end
        if self.UpdateDockLockWarning then
            self:UpdateDockLockWarning()
        end
        if self.UpdateMoveHintTickerState then
            self:UpdateMoveHintTickerState()
        end
        return finish()
    end
    local shouldShowNaturally, naturalReason = canShowDock()
    local visibilityOverride = normalizeDockVisibilityMode(getDockDiagVisibilityOverride(), "NORMAL")
    local naturalReasonText = tostring(naturalReason or "<none>")
    local hasEntries = ((self.dockEntriesCount or 0) > 0) or (db.dockTestMode and true or false)
    local effectiveShouldShow = shouldShowNaturally and hasEntries
    local effectiveReason = naturalReasonText

    if shouldShowNaturally then
        if hasEntries then
            effectiveReason = "visible"
        else
            effectiveReason = "no entries"
        end
    end
    if visibilityOverride == "HIDE" and effectiveShouldShow then
        effectiveShouldShow = false
        effectiveReason = "dockdiag visibility hide"
    end

    self._dockDiagNaturalVisibilityReason = naturalReasonText
    self._dockDiagEffectiveVisibilityReason = tostring(effectiveReason or "<none>")
    self._dockDiagLastVisibilityReason = self._dockDiagEffectiveVisibilityReason
    debugVisibility(naturalReason)

    -- Only keep the combat driver active when dock is otherwise eligible to show.
    self:SetDockCombatVisibilityDriverEnabled((shouldShowNaturally and db.dockEnabled and db.dockHideInCombat and db.dockLocked ~= false) and true or false)

    if effectiveShouldShow then
        self.dockFrame:Show()
    else
        self.dockFrame:Hide()
    end
    if self.UpdateDockOnUpdateState then
        self:UpdateDockOnUpdateState()
    end

    if self.UpdateDockLockWarning then
        self:UpdateDockLockWarning()
    end
    if self.UpdateMoveHintTickerState then
        self:UpdateMoveHintTickerState()
    end
    return finish()
end

function PortalAuthority:UpdateDockVisibility(force)
    self:RefreshDockVisibility(force)
end

function PortalAuthority:HideDock()
    if self.dockFrame then
        if InCombatLockdown() then
            self:QueueDockVisibilityRefresh()
            return
        end
        self.dockFrame:Hide()
    end
    if self.UpdateDockLockWarning then
        self:UpdateDockLockWarning()
    end
end

function PortalAuthority:RestoreDock(force)
    self:RefreshDockVisibility(force)
end

function PortalAuthority:ApplyDockPosition()
    if not self.dockFrame then
        return
    end
    if InCombatLockdown() then
        self:QueueDockUpdate()
        return
    end

    local db = PortalAuthorityDB or self.defaults
    local x = db.dockX or 0
    local y = db.dockY or 0
    local anchor = db.dockAnchorPoint or "CENTER"
    self.dockFrame:ClearAllPoints()
    self.dockFrame:SetPoint(anchor, UIParent, "CENTER", x, y)
    self:NotifyDockPositionChanged(x, y)
end

function PortalAuthority:ApplyDockLayoutSettings(reposition)
    local db = PortalAuthorityDB or self.defaults
    local defaults = self.defaults or {}

    local previousMode = self._dockEffectiveLayoutMode
    local mode = resolveDockSimpleLayoutModeFromDB(db, defaults)
    self._dockEffectiveLayoutMode = mode
    db.dockIconsPerLine = math.floor(clamp(db.dockIconsPerLine, 1, 10, defaults.dockIconsPerLine or 4))
    db.dockIconSpacing = math.floor(clamp(db.dockIconSpacing, 0, 40, defaults.dockIconSpacing or 6))
    db.dockDensity = math.floor(clamp(db.dockDensity, 0, 100, defaults.dockDensity or 50))
    db.dockSpacingX = math.floor(clamp(db.dockSpacingX, DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, db.dockIconSpacing))
    db.dockSpacingY = math.floor(clamp(db.dockSpacingY, DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, db.dockIconSpacing))

    -- Keep legacy wrap key synced while preserving independent X/Y spacing.
    db.dockWrapAfter = db.dockIconsPerLine

    if InCombatLockdown() then
        self:QueueDockUpdate()
        if reposition then
            self:QueueDockVisibilityRefresh()
        end
        return
    end

    local animateTransition = (previousMode ~= nil and previousMode ~= mode)
    if animateTransition then
        self._dockTransitionMode = "LAYOUT"
    end
    self:RebuildDock(animateTransition)
    if animateTransition then
        self._dockTransitionMode = nil
    end
    if self.dockSpacingCross and self.dockSpacingCross._refreshVisual then
        self.dockSpacingCross._refreshVisual()
    end
    if reposition then
        self:ApplyDockPosition()
    end
    self:RefreshDockVisibility(true)
end

function PortalAuthority:ApplyDockAppearanceSettings()
    local db = PortalAuthorityDB or self.defaults
    local defaults = self.defaults or {}

    local previousLabelMode = self._dockEffectiveLabelMode
    local previousLabelSide = self._dockEffectiveLabelSide
    local effectiveLabelMode = getEffectiveDockLabelMode(db, defaults)
    local effectiveLabelSide = getEffectiveDockLabelSide(db, defaults, effectiveLabelMode)
    if getDockDiagLabelModeOverride() == nil then
        db.dockLabelMode = effectiveLabelMode
        db.dockLabelSide = effectiveLabelSide
    end
    self._dockEffectiveLabelMode = effectiveLabelMode
    self._dockEffectiveLabelSide = effectiveLabelSide

    local textAlign = string.upper(tostring(db.dockTextAlign or defaults.dockTextAlign or "CENTER"))
    if textAlign ~= "LEFT" and textAlign ~= "CENTER" and textAlign ~= "RIGHT" then
        textAlign = string.upper(tostring(defaults.dockTextAlign or "CENTER"))
    end
    db.dockTextAlign = textAlign

    db.dockFontSize = math.floor(clamp(db.dockFontSize, 8, 48, defaults.dockFontSize or 12))
    db.dockFontSizeUI = db.dockFontSize

    db.dockHoverGlowAlpha = clamp(db.dockHoverGlowAlpha, 0.0, 1.0, defaults.dockHoverGlowAlpha or 0.2)
    db.dockHoverGlowSize = math.floor(clamp(db.dockHoverGlowSize, 0, 20, defaults.dockHoverGlowSize or 0))

    if InCombatLockdown() then
        self:QueueDockUpdate()
        self:QueueDockVisibilityRefresh()
        return
    end

    local animateTransition =
        (previousLabelMode ~= nil and previousLabelMode ~= effectiveLabelMode)
        or (previousLabelSide ~= nil and previousLabelSide ~= effectiveLabelSide)
    if animateTransition then
        self._dockTransitionMode = "LABEL"
    end
    self:RebuildDock(animateTransition)
    if animateTransition then
        self._dockTransitionMode = nil
    end
    self:RefreshDockVisibility(true)
end

function PortalAuthority:CreateDockSpacingCross(parentDockFrame)
    local dock = parentDockFrame or self.dockFrame
    if not dock then
        return nil
    end

    local host = dock

    if self.dockSpacingCross and self.dockSpacingCross:GetParent() ~= host then
        self.dockSpacingCross:SetParent(host)
        self.dockSpacingCross:ClearAllPoints()
        self.dockSpacingCross:SetPoint("CENTER", host, "CENTER", 0, 0)
    end

    if self.dockSpacingCross then
        self.dockSpacingCross:ClearAllPoints()
        self.dockSpacingCross:SetPoint("CENTER", host, "CENTER", 0, 0)
        self.dockSpacingCross:SetFrameStrata("HIGH")
        self.dockSpacingCross:SetFrameLevel((host:GetFrameLevel() or 1) + 30)
        return self.dockSpacingCross
    end

    local cross = CreateFrame("Frame", nil, host)
    cross:SetPoint("CENTER", host, "CENTER", 0, 0)
    cross:SetSize(DOCK_SPACING_CROSS.ARM_LENGTH + 12, DOCK_SPACING_CROSS.ARM_LENGTH + 12)
    cross:SetFrameStrata("HIGH")
    cross:SetFrameLevel((host:GetFrameLevel() or 1) + 30)
    cross:EnableMouse(true)
    cross:EnableMouseWheel(true)
    cross:Hide()

    local backing = cross:CreateTexture(nil, "BACKGROUND")
    backing:SetTexture("Interface\\Buttons\\WHITE8x8")
    backing:SetPoint("CENTER", cross, "CENTER", 0, 0)
    backing:SetSize(DOCK_SPACING_CROSS.ARM_LENGTH + 18, DOCK_SPACING_CROSS.ARM_LENGTH + 18)
    backing:SetVertexColor(0, 0, 0, 0.28)
    if backing.SetMask then
        backing:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    cross.backing = backing

    local function createArm(axis)
        local arm = CreateFrame("Button", nil, cross)
        arm.axis = axis
        if axis == "x" then
            arm:SetSize(DOCK_SPACING_CROSS.ARM_LENGTH, DOCK_SPACING_CROSS.ARM_HIT_THICKNESS)
        else
            arm:SetSize(DOCK_SPACING_CROSS.ARM_HIT_THICKNESS, DOCK_SPACING_CROSS.ARM_LENGTH)
        end
        arm:SetPoint("CENTER", cross, "CENTER", 0, 0)
        arm:EnableMouse(true)

        arm.line = arm:CreateTexture(nil, "ARTWORK")
        arm.line:SetTexture("Interface\\Buttons\\WHITE8x8")
        arm.line:SetPoint("CENTER", arm, "CENTER", 0, 0)
        if axis == "x" then
            arm.line:SetSize(DOCK_SPACING_CROSS.ARM_LENGTH, DOCK_SPACING_CROSS.ARM_THICKNESS)
        else
            arm.line:SetSize(DOCK_SPACING_CROSS.ARM_THICKNESS, DOCK_SPACING_CROSS.ARM_LENGTH)
        end

        arm.glow = arm:CreateTexture(nil, "OVERLAY")
        arm.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        arm.glow:SetPoint("CENTER", arm.line, "CENTER", 0, 0)
        if axis == "x" then
            arm.glow:SetSize(DOCK_SPACING_CROSS.ARM_LENGTH + 4, DOCK_SPACING_CROSS.ARM_THICKNESS + 4)
        else
            arm.glow:SetSize(DOCK_SPACING_CROSS.ARM_THICKNESS + 4, DOCK_SPACING_CROSS.ARM_LENGTH + 4)
        end
        arm.glow:SetBlendMode("ADD")
        arm.glow:SetVertexColor(1.0, 0.82, 0.0, 0)
        return arm
    end

    local xArm = createArm("x")
    local yArm = createArm("y")
    cross.xArm = xArm
    cross.yArm = yArm

    local center = cross:CreateTexture(nil, "OVERLAY")
    center:SetTexture("Interface\\Buttons\\WHITE8x8")
    center:SetSize(DOCK_SPACING_CROSS.CENTER_SIZE, DOCK_SPACING_CROSS.CENTER_SIZE)
    center:SetPoint("CENTER", cross, "CENTER", 0, 0)
    center:SetVertexColor(1.0, 0.82, 0.0, 0.9)
    if center.SetMask then
        center:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    cross.centerNode = center

    local readout = CreateFrame("Frame", nil, cross, "BackdropTemplate")
    readout:SetPoint("BOTTOM", cross, "TOP", 0, 8)
    readout:SetSize(104, 18)
    if readout.SetBackdrop then
        readout:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        readout:SetBackdropColor(0, 0, 0, 0.78)
        readout:SetBackdropBorderColor(1, 1, 1, 0.08)
    end
    readout.text = readout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    readout.text:SetPoint("CENTER", readout, "CENTER", 0, 0)
    readout.text:SetTextColor(0.9, 0.9, 0.9, 1)
    readout:Hide()
    cross.readout = readout

    local unlockHint = CreateFrame("Frame", nil, cross, "BackdropTemplate")
    unlockHint:SetPoint("TOP", cross, "BOTTOM", 0, -8)
    unlockHint:SetSize(420, 18)
    if unlockHint.SetBackdrop then
        unlockHint:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        unlockHint:SetBackdropColor(0, 0, 0, 0.62)
        unlockHint:SetBackdropBorderColor(1, 1, 1, 0.06)
    end
    unlockHint.text = unlockHint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlockHint.text:SetPoint("CENTER", unlockHint, "CENTER", 0, 0)
    unlockHint.text:SetText("")
    unlockHint.text:SetTextColor(0.76, 0.76, 0.76, 0.92)
    unlockHint:Hide()
    cross.unlockHint = unlockHint

    local function axisState(axis)
        local dbNow = PortalAuthorityDB or PortalAuthority.defaults
        local defaultsNow = PortalAuthority and PortalAuthority.defaults or nil
        local modeNow, xActiveNow, yActiveNow = getDockSpacingAxisApplicability(dbNow, defaultsNow)
        if axis == "x" then
            return xActiveNow, modeNow
        end
        return yActiveNow, modeNow
    end

    local function refreshVisual()
        local activeAxis = cross._activeAxis
        local hoverAxis = cross._hoverAxis

        local xEnabled = axisState("x")
        local yEnabled = axisState("y")

        if not xEnabled and hoverAxis == "x" then
            hoverAxis = nil
            cross._hoverAxis = nil
        end
        if not yEnabled and hoverAxis == "y" then
            hoverAxis = nil
            cross._hoverAxis = nil
        end
        if not xEnabled and activeAxis == "x" then
            activeAxis = nil
            cross._activeAxis = nil
        end
        if not yEnabled and activeAxis == "y" then
            activeAxis = nil
            cross._activeAxis = nil
        end

        xArm:SetShown(xEnabled)
        xArm:EnableMouse(xEnabled)
        yArm:SetShown(yEnabled)
        yArm:EnableMouse(yEnabled)

        local function paint(arm, hot, enabled)
            if not enabled then
                arm.line:SetVertexColor(0.52, 0.52, 0.52, 0.16)
                arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0)
                return
            end
            if hot then
                arm.line:SetVertexColor(1.0, 0.84, 0.1, 0.95)
                arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0.35)
            else
                arm.line:SetVertexColor(0.72, 0.72, 0.72, 0.35)
                arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0)
            end
        end

        paint(xArm, activeAxis == "x" or hoverAxis == "x", xEnabled)
        paint(yArm, activeAxis == "y" or hoverAxis == "y", yEnabled)
    end
    cross._refreshVisual = refreshVisual
    refreshVisual()

    local function showTip(anchor, line1, line2)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
        GameTooltip:SetText(line1, 1, 0.82, 0, 1, true)
        if line2 and line2 ~= "" then
            GameTooltip:AddLine(line2, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end

    local TOOLTIP_DEBOUNCE = 0.10
    cross._tooltipRegionActive = nil
    cross._tooltipRegionWanted = nil
    cross._tooltipDebounceToken = 0

    local function getTooltipLinesForRegion(region)
        if region == "X_ARM" then
            local enabled, modeNow = axisState("x")
            if not enabled then
                return "Not applicable in " .. dockSpacingModeLabel(modeNow) .. " mode.", nil
            end
            return "Drag horizontal to adjust X spacing", "Scroll to adjust Y spacing (Shift fine / Alt coarse)"
        elseif region == "Y_ARM" then
            local enabled, modeNow = axisState("y")
            if not enabled then
                return "Not applicable in " .. dockSpacingModeLabel(modeNow) .. " mode.", nil
            end
            return "Drag vertical to adjust Y spacing", "Scroll to adjust Y spacing (Shift fine / Alt coarse)"
        elseif region == "BACKING" then
            local dbNow = PortalAuthorityDB or PortalAuthority.defaults
            local defaultsNow = PortalAuthority and PortalAuthority.defaults or nil
            local _, xActiveNow, yActiveNow = getDockSpacingAxisApplicability(dbNow, defaultsNow)
            if xActiveNow and yActiveNow then
                return "Scroll to adjust Y spacing (Shift fine / Alt coarse)", "Drag horizontal/vertical arms for X/Y spacing"
            elseif xActiveNow then
                return "Drag horizontal arm to adjust X spacing", "Vertical spacing is not applicable in Row mode."
            else
                return "Drag vertical arm to adjust Y spacing", "Horizontal spacing is not applicable in Column mode."
            end
        end
        return nil, nil
    end

    local function applyTooltipRegion(region)
        if region == cross._tooltipRegionActive then
            return
        end
        if self._dockIsAdjustingSpacing and cross._tooltipRegionActive ~= nil then
            return
        end
        if not region then
            cross._tooltipRegionActive = nil
            hideGameTooltipIfOwnedBy(cross)
            return
        end

        local line1, line2 = getTooltipLinesForRegion(region)
        if not line1 or line1 == "" then
            cross._tooltipRegionActive = nil
            hideGameTooltipIfOwnedBy(cross)
            return
        end

        cross._tooltipRegionActive = region
        showTip(cross, line1, line2)
    end

    local function requestTooltipRegion(region)
        cross._tooltipRegionWanted = region
        cross._tooltipDebounceToken = (cross._tooltipDebounceToken or 0) + 1
        local token = cross._tooltipDebounceToken

        if not (C_Timer and C_Timer.After) then
            applyTooltipRegion(region)
            return
        end

        C_Timer.After(TOOLTIP_DEBOUNCE, function()
            if not self.dockSpacingCross or self.dockSpacingCross ~= cross then
                return
            end
            if token ~= cross._tooltipDebounceToken then
                return
            end
            if cross._tooltipRegionWanted ~= region then
                return
            end
            applyTooltipRegion(region)
        end)
    end

    local function armEnter(axis)
        local enabled, modeNow = axisState(axis)
        if not enabled then
            cross._hoverAxis = nil
            refreshVisual()
            setDockCrossCursor(nil)
            requestTooltipRegion(axis == "x" and "X_ARM" or "Y_ARM")
            if not self._dockSpacingDrag then
                self:UpdateReadout(false)
            end
            return
        end

        cross._hoverAxis = axis
        refreshVisual()
        self:UpdateReadout(true)
        if axis == "x" then
            setDockCrossCursor(DOCK_SPACING_CROSS.CURSOR_X)
            requestTooltipRegion("X_ARM")
        else
            setDockCrossCursor(DOCK_SPACING_CROSS.CURSOR_Y)
            requestTooltipRegion("Y_ARM")
        end
    end

    local function armLeave(axis)
        if cross._activeAxis ~= axis then
            cross._hoverAxis = nil
            refreshVisual()
            setDockCrossCursor(nil)
        end
        requestTooltipRegion(nil)
        if not self._dockSpacingDrag then
            self:UpdateReadout(false)
        end
    end

    xArm:SetScript("OnEnter", function() armEnter("x") end)
    yArm:SetScript("OnEnter", function() armEnter("y") end)
    xArm:SetScript("OnLeave", function() armLeave("x") end)
    yArm:SetScript("OnLeave", function() armLeave("y") end)

    xArm:SetScript("OnMouseDown", function(_, button)
        local enabled = axisState("x")
        if enabled and shouldBeginDockDrag(button) then
            self:BeginDrag("x")
        end
    end)
    yArm:SetScript("OnMouseDown", function(_, button)
        local enabled = axisState("y")
        if enabled and shouldBeginDockDrag(button) then
            self:BeginDrag("y")
        end
    end)
    xArm:SetScript("OnMouseUp", function(_, button)
        if shouldBeginDockDrag(button) then
            self:EndDrag()
        end
    end)
    yArm:SetScript("OnMouseUp", function(_, button)
        if shouldBeginDockDrag(button) then
            self:EndDrag()
        end
    end)

    cross:SetScript("OnMouseWheel", function(_, delta)
        if InCombatLockdown() then
            return
        end
        local step = DOCK_SPACING_CROSS.WHEEL_BASE_STEP
        if IsAltKeyDown and IsAltKeyDown() then
            step = DOCK_SPACING_CROSS.WHEEL_ALT_STEP
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            step = DOCK_SPACING_CROSS.WHEEL_SHIFT_STEP
        end
        local yEnabled, modeNow = axisState("y")
        if not yEnabled then
            requestTooltipRegion("Y_ARM")
            return
        end
        if delta and delta ~= 0 then
            self._dockIsAdjustingSpacing = true
            hideGameTooltipIfOwnedBy(cross)
            local activeButtons = self.dockActiveButtons or self.dockButtons
            if type(activeButtons) == "table" then
                for i = 1, #activeButtons do
                    local activeBtn = activeButtons[i]
                    if activeBtn and activeBtn.hover then
                        activeBtn.hover:Hide()
                    end
                end
            end
            self:ApplySpacingDelta(0, delta * step, "wheel")
            self:UpdateReadout(false)
            self._dockWheelAdjustToken = (self._dockWheelAdjustToken or 0) + 1
            local token = self._dockWheelAdjustToken
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    if token ~= self._dockWheelAdjustToken then
                        return
                    end
                    if PortalAuthority and PortalAuthority._dockSpacingDrag then
                        return
                    end
                    if PortalAuthority then
                        PortalAuthority._dockIsAdjustingSpacing = false
                    end
                end)
            else
                self._dockIsAdjustingSpacing = false
            end
        end
    end)

    cross:SetScript("OnEnter", function()
        if not cross._activeAxis then
            setDockCrossCursor(DOCK_SPACING_CROSS.CURSOR_GENERIC)
            requestTooltipRegion("BACKING")
        end
        self:UpdateReadout(true)
    end)
    cross:SetScript("OnLeave", function()
        if not cross._activeAxis then
            cross._hoverAxis = nil
            refreshVisual()
            setDockCrossCursor(nil)
            requestTooltipRegion(nil)
            if not self._dockSpacingDrag then
                self:UpdateReadout(false)
            end
        end
    end)

    self.dockSpacingCross = cross
    return cross
end

function PortalAuthority:CreateDockTextDirectionCross(parentDockFrame)
    local dock = parentDockFrame or self.dockFrame
    if not dock then
        return nil
    end

    local host = self:EnsureDockCrossContainer(dock) or dock
    local offsetX = dockCrossPairOffsetX()

    if self.dockTextDirectionCross and self.dockTextDirectionCross:GetParent() ~= host then
        self.dockTextDirectionCross:SetParent(host)
        self.dockTextDirectionCross:ClearAllPoints()
        self.dockTextDirectionCross:SetPoint("CENTER", host, "CENTER", offsetX, 0)
    end

    if self.dockTextDirectionCross then
        self.dockTextDirectionCross:ClearAllPoints()
        self.dockTextDirectionCross:SetPoint("CENTER", host, "CENTER", offsetX, 0)
        self.dockTextDirectionCross:SetFrameStrata(host:GetFrameStrata())
        self.dockTextDirectionCross:SetFrameLevel(host:GetFrameLevel() + 1)
        return self.dockTextDirectionCross
    end

    local cross = CreateFrame("Frame", nil, host)
    cross:SetPoint("CENTER", host, "CENTER", offsetX, 0)
    cross:SetSize(DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH + 12, DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH + 12)
    cross:SetFrameStrata(host:GetFrameStrata())
    cross:SetFrameLevel(host:GetFrameLevel() + 1)
    cross:EnableMouse(true)
    cross:Hide()

    local function createArm(axis)
        local arm = CreateFrame("Button", nil, cross)
        arm.axis = axis
        if axis == "x" then
            arm:SetSize(DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH, DOCK_TEXT_DIRECTION_CROSS.ARM_HIT_THICKNESS)
        else
            arm:SetSize(DOCK_TEXT_DIRECTION_CROSS.ARM_HIT_THICKNESS, DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH)
        end
        arm:SetPoint("CENTER", cross, "CENTER", 0, 0)
        arm:EnableMouse(true)

        arm.line = arm:CreateTexture(nil, "ARTWORK")
        arm.line:SetTexture("Interface\\Buttons\\WHITE8x8")
        arm.line:SetPoint("CENTER", arm, "CENTER", 0, 0)
        if axis == "x" then
            arm.line:SetSize(DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH, DOCK_TEXT_DIRECTION_CROSS.ARM_THICKNESS)
        else
            arm.line:SetSize(DOCK_TEXT_DIRECTION_CROSS.ARM_THICKNESS, DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH)
        end

        arm.glow = arm:CreateTexture(nil, "OVERLAY")
        arm.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        arm.glow:SetPoint("CENTER", arm.line, "CENTER", 0, 0)
        if axis == "x" then
            arm.glow:SetSize(DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH + 4, DOCK_TEXT_DIRECTION_CROSS.ARM_THICKNESS + 4)
        else
            arm.glow:SetSize(DOCK_TEXT_DIRECTION_CROSS.ARM_THICKNESS + 4, DOCK_TEXT_DIRECTION_CROSS.ARM_LENGTH + 4)
        end
        arm.glow:SetBlendMode("ADD")
        arm.glow:SetVertexColor(1.0, 0.82, 0.0, 0)
        return arm
    end

    local xArm = createArm("x")
    local yArm = createArm("y")
    cross.xArm = xArm
    cross.yArm = yArm

    local center = cross:CreateTexture(nil, "OVERLAY")
    center:SetTexture("Interface\\Buttons\\WHITE8x8")
    center:SetSize(DOCK_TEXT_DIRECTION_CROSS.CENTER_SIZE, DOCK_TEXT_DIRECTION_CROSS.CENTER_SIZE)
    center:SetPoint("CENTER", cross, "CENTER", 0, 0)
    center:SetVertexColor(1.0, 0.82, 0.0, 0.9)
    if center.SetMask then
        center:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    cross.centerNode = center

    local readout = CreateFrame("Frame", nil, cross, "BackdropTemplate")
    readout:SetPoint("BOTTOM", cross, "TOP", 0, 8)
    readout:SetSize(102, 18)
    if readout.SetBackdrop then
        readout:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        readout:SetBackdropColor(0, 0, 0, 0.78)
        readout:SetBackdropBorderColor(1, 1, 1, 0.08)
    end
    readout.text = readout:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    readout.text:SetPoint("CENTER", readout, "CENTER", 0, 0)
    readout.text:SetTextColor(0.9, 0.9, 0.9, 1)
    readout:Hide()
    cross.readout = readout

    local function refreshVisual()
        local activeAxis = cross._activeAxis
        local hoverAxis = cross._hoverAxis

        local function paint(arm, hot)
            if hot then
                arm.line:SetVertexColor(1.0, 0.84, 0.1, 0.95)
                arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0.35)
            else
                arm.line:SetVertexColor(0.72, 0.72, 0.72, 0.35)
                arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0)
            end
        end

        paint(xArm, activeAxis == "x" or hoverAxis == "x")
        paint(yArm, activeAxis == "y" or hoverAxis == "y")
    end
    cross._refreshVisual = refreshVisual
    refreshVisual()

    local function showTip(anchor, line1, line2)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
        GameTooltip:SetText(line1, 1, 0.82, 0, 1, true)
        if line2 and line2 ~= "" then
            GameTooltip:AddLine(line2, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end

    local function armEnter(axis)
        cross._hoverAxis = axis
        refreshVisual()
        self:UpdateTextDirectionReadout(true)
        if axis == "x" then
            setDockCrossCursor(DOCK_TEXT_DIRECTION_CROSS.CURSOR_X)
            showTip(cross, "Drag to set text direction (Left/Right)", "Drag vertically to set Top/Bottom")
        else
            setDockCrossCursor(DOCK_TEXT_DIRECTION_CROSS.CURSOR_Y)
            showTip(cross, "Drag to set text direction (Top/Bottom)", "Drag horizontally to set Left/Right")
        end
    end

    local function armLeave(axis)
        if cross._activeAxis ~= axis then
            cross._hoverAxis = nil
            refreshVisual()
            setDockCrossCursor(nil)
        end
        hideGameTooltipIfOwnedBy(cross)
        if not self._dockTextDirectionDrag then
            self:UpdateTextDirectionReadout(false)
        end
    end

    xArm:SetScript("OnEnter", function() armEnter("x") end)
    yArm:SetScript("OnEnter", function() armEnter("y") end)
    xArm:SetScript("OnLeave", function() armLeave("x") end)
    yArm:SetScript("OnLeave", function() armLeave("y") end)

    xArm:SetScript("OnMouseDown", function(_, button)
        if shouldBeginDockDrag(button) then
            self:BeginTextDirectionDrag("x")
        end
    end)
    yArm:SetScript("OnMouseDown", function(_, button)
        if shouldBeginDockDrag(button) then
            self:BeginTextDirectionDrag("y")
        end
    end)
    xArm:SetScript("OnMouseUp", function(_, button)
        if shouldBeginDockDrag(button) then
            self:EndTextDirectionDrag()
        end
    end)
    yArm:SetScript("OnMouseUp", function(_, button)
        if shouldBeginDockDrag(button) then
            self:EndTextDirectionDrag()
        end
    end)

    cross:SetScript("OnEnter", function()
        if not cross._activeAxis then
            setDockCrossCursor(DOCK_TEXT_DIRECTION_CROSS.CURSOR_GENERIC)
            showTip(cross, "Drag to set text direction (Left/Right/Top/Bottom)", "")
        end
        self:UpdateTextDirectionReadout(true)
    end)
    cross:SetScript("OnLeave", function()
        if not cross._activeAxis then
            cross._hoverAxis = nil
            refreshVisual()
            setDockCrossCursor(nil)
            hideGameTooltipIfOwnedBy(cross)
            if not self._dockTextDirectionDrag then
                self:UpdateTextDirectionReadout(false)
            end
        end
    end)

    self.dockTextDirectionCross = cross
    return cross
end

function PortalAuthority:UpdateReadout(interacting)
    local cross = self.dockSpacingCross
    if not cross or not cross.readout or not cross.readout.text then
        return
    end
    cross.readout:Hide()
end

function PortalAuthority:ShowDockSpacingUnlockHint()
    local cross = self.dockSpacingCross
    if not cross or not cross.unlockHint or not cross.unlockHint.text then
        return
    end
    if not cross:IsShown() then
        return
    end

    local db = PortalAuthorityDB or self.defaults
    local hint = cross.unlockHint
    local message
    if db and db.dockEnabled then
        message = "Drag to reposition. Use the cross to adjust spacing."
    else
        message = "Drag to reposition. Dock is temporarily visible. Use the cross to adjust spacing."
    end
    hint.text:SetText(message)
    if hint.text.GetStringWidth then
        local targetW = math.floor((hint.text:GetStringWidth() or 0) + 22)
        hint:SetWidth(math.max(220, math.min(640, targetW)))
    end
    hint:SetAlpha(0)
    hint:Show()
    self._dockSpacingUnlockHintVisible = true
    if UIFrameFadeIn then
        UIFrameFadeIn(hint, 0.12, 0, 1)
    else
        hint:SetAlpha(1)
    end

    self._dockSpacingUnlockHintToken = (self._dockSpacingUnlockHintToken or 0) + 1
    local token = self._dockSpacingUnlockHintToken

    if C_Timer and C_Timer.After then
        C_Timer.After(DOCK_UNLOCK_POPUP_HOLD, function()
            if not self.dockSpacingCross or not self.dockSpacingCross.unlockHint then
                return
            end
            if token ~= self._dockSpacingUnlockHintToken then
                return
            end
            local currentHint = self.dockSpacingCross.unlockHint
            if UIFrameFadeOut then
                UIFrameFadeOut(currentHint, DOCK_UNLOCK_POPUP_FADE, currentHint:GetAlpha() or 1, 0)
                C_Timer.After(DOCK_UNLOCK_POPUP_FADE, function()
                    if not self.dockSpacingCross or not self.dockSpacingCross.unlockHint then
                        return
                    end
                    if token ~= self._dockSpacingUnlockHintToken then
                        return
                    end
                    self.dockSpacingCross.unlockHint:Hide()
                    self._dockSpacingUnlockHintVisible = false
                end)
            else
                currentHint:Hide()
                self._dockSpacingUnlockHintVisible = false
            end
        end)
    end
end

function PortalAuthority:PlayDockSpacingBoundaryPulse()
    local db = PortalAuthorityDB or self.defaults
    if not db or db.dockLocked then
        return
    end

    local cross = self.dockSpacingCross
    if not cross or not cross:IsShown() then
        return
    end

    if InCombatLockdown() then
        return
    end

    local boundaryState = self._dockSpacingBoundaryState
    if type(boundaryState) ~= "table" then
        return
    end
    local hitX = boundaryState.x and true or false
    local hitY = boundaryState.y and true or false
    if not hitX and not hitY then
        return
    end

    local buttons = self.dockActiveButtons
    if type(buttons) ~= "table" or #buttons == 0 then
        return
    end

    local centerX = 0
    local centerY = 0
    local samples = 0
    for i = 1, #buttons do
        local btn = buttons[i]
        if btn and btn._lastX ~= nil and btn._lastY ~= nil then
            centerX = centerX + (tonumber(btn._lastX) or 0)
            centerY = centerY + (tonumber(btn._lastY) or 0)
            samples = samples + 1
        end
    end
    if samples <= 0 then
        return
    end
    centerX = centerX / samples
    centerY = centerY / samples

    local function directionSign(value)
        if value > 0 then
            return 1
        elseif value < 0 then
            return -1
        end
        return 1
    end

    local amplitude = 3
    local outDuration = 0.08
    local inDuration = 0.08
    local token = (self._dockSpacingBoundaryPulseToken or 0) + 1
    self._dockSpacingBoundaryPulseToken = token

    for i = 1, #buttons do
        if token ~= self._dockSpacingBoundaryPulseToken then
            return
        end

        local btn = buttons[i]
        if btn and btn:IsShown() then
            local lastX = tonumber(btn._lastX)
            local lastY = tonumber(btn._lastY)
            if lastX ~= nil and lastY ~= nil then
                local dirX = directionSign(lastX - centerX)
                local dirY = directionSign(lastY - centerY)
                local dx = hitX and (dirX * amplitude) or 0
                local dy = hitY and (dirY * amplitude) or 0
                if dx ~= 0 or dy ~= 0 then
                    if not btn._paBoundaryPulseAG then
                        local ag = btn:CreateAnimationGroup()
                        local out = ag:CreateAnimation("Translation")
                        out:SetOrder(1)
                        out:SetDuration(outDuration)
                        if out.SetSmoothing then
                            out:SetSmoothing("OUT")
                        end

                        local back = ag:CreateAnimation("Translation")
                        back:SetOrder(2)
                        back:SetDuration(inDuration)
                        if back.SetSmoothing then
                            back:SetSmoothing("IN")
                        end

                        btn._paBoundaryPulseAG = ag
                        btn._paBoundaryPulseOut = out
                        btn._paBoundaryPulseBack = back
                    end

                    local ag = btn._paBoundaryPulseAG
                    local out = btn._paBoundaryPulseOut
                    local back = btn._paBoundaryPulseBack
                    if ag and out and back then
                        if ag.IsPlaying and ag:IsPlaying() then
                            ag:Stop()
                        end
                        out:SetOffset(dx, dy)
                        back:SetOffset(-dx, -dy)
                        ag:Play()
                    end
                end
            end
        end
    end
end

local function measureDockLabelText(text)
    local db = PortalAuthorityDB or PortalAuthority.defaults
    local host = (PortalAuthority and PortalAuthority.dockFrame) or UIParent
    if not host or not host.CreateFontString then
        local fallbackHeight = math.floor((tonumber(db and db.dockFontSize) or 12) + 0.5)
        local fallbackWidth = math.floor(((text and string.len(tostring(text))) or 0) * 6)
        return fallbackWidth, fallbackHeight
    end

    local measure = PortalAuthority._dockMeasureLabel
    if not measure or measure:GetParent() ~= host then
        measure = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        measure:Hide()
        measure:SetAlpha(0)
        measure:SetWordWrap(false)
        measure:SetMaxLines(1)
        PortalAuthority._dockMeasureLabel = measure
    end

    local fontPath = db.dockFontPath
    if not fontPath or fontPath == "" then
        fontPath = PortalAuthority:GetGlobalFontPath()
    end
    measure:SetFont(fontPath, db.dockFontSize, db.dockTextOutline)
    measure:SetText(text or "")

    local width = math.floor((tonumber(measure:GetStringWidth()) or 0) + 0.5)
    local height = math.floor((tonumber(measure:GetStringHeight()) or tonumber(db.dockFontSize) or 12) + 0.5)
    return width, height
end

function PortalAuthority:DismissDockSpacingUnlockHint(fadeDuration)
    local cross = self.dockSpacingCross
    if not cross or not cross.unlockHint then
        return
    end
    local hint = cross.unlockHint
    if not hint:IsShown() then
        self._dockSpacingUnlockHintVisible = false
        return
    end

    self._dockSpacingUnlockHintToken = (self._dockSpacingUnlockHintToken or 0) + 1
    local token = self._dockSpacingUnlockHintToken
    local fade = tonumber(fadeDuration) or DOCK_UNLOCK_POPUP_FAST_FADE
    if fade < 0 then
        fade = 0
    end

    if UIFrameFadeOut and fade > 0 then
        UIFrameFadeOut(hint, fade, hint:GetAlpha() or 1, 0)
        if C_Timer and C_Timer.After then
            C_Timer.After(fade, function()
                if not self.dockSpacingCross or not self.dockSpacingCross.unlockHint then
                    return
                end
                if token ~= self._dockSpacingUnlockHintToken then
                    return
                end
                self.dockSpacingCross.unlockHint:Hide()
                self._dockSpacingUnlockHintVisible = false
            end)
        else
            hint:Hide()
            self._dockSpacingUnlockHintVisible = false
        end
    else
        hint:Hide()
        self._dockSpacingUnlockHintVisible = false
    end
end

function PortalAuthority:UpdateTextDirectionReadout(interacting)
    local cross = self.dockTextDirectionCross
    if not cross or not cross.readout or not cross.readout.text then
        return
    end
    if not cross:IsShown() and not interacting then
        cross.readout:Hide()
        return
    end

    local db = PortalAuthorityDB or self.defaults
    local currentDirection = normalizeDockTextDirection(db.dockTextDirection, (self.defaults and self.defaults.dockTextDirection) or "BOTTOM")
    cross.readout.text:SetText("Text: " .. dockTextDirectionLabel(currentDirection))
    cross.readout:SetAlpha(1)
    cross.readout:Show()

    self._dockTextDirectionReadoutToken = (self._dockTextDirectionReadoutToken or 0) + 1
    local token = self._dockTextDirectionReadoutToken
    if interacting then
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(DOCK_TEXT_DIRECTION_CROSS.READOUT_HOLD, function()
            if not self.dockTextDirectionCross or not self.dockTextDirectionCross.readout then
                return
            end
            if token ~= self._dockTextDirectionReadoutToken then
                return
            end
            local readout = self.dockTextDirectionCross.readout
            if UIFrameFadeOut then
                UIFrameFadeOut(readout, DOCK_TEXT_DIRECTION_CROSS.READOUT_FADE, readout:GetAlpha() or 1, 0)
                C_Timer.After(DOCK_TEXT_DIRECTION_CROSS.READOUT_FADE, function()
                    if not self.dockTextDirectionCross or not self.dockTextDirectionCross.readout then
                        return
                    end
                    if token ~= self._dockTextDirectionReadoutToken then
                        return
                    end
                    self.dockTextDirectionCross.readout:Hide()
                end)
            else
                readout:Hide()
            end
        end)
    end
end

function PortalAuthority:ApplySpacingDelta(dx, dy, source)
    if InCombatLockdown() then
        return false
    end

    local db = PortalAuthorityDB or self.defaults
    local defaults = self.defaults or {}
    local _, xAxisActive, yAxisActive = getDockSpacingAxisApplicability(db, defaults)
    local iconFloor = math.max(16, math.floor(tonumber(db.dockIconSize) or tonumber(defaults.dockIconSize) or 36))

    local minX = math.max(math.floor(tonumber(self._dockMinSpacingX) or iconFloor), DOCK_SPACING_CROSS.MIN_SPACING_X)
    local minY = math.max(math.floor(tonumber(self._dockMinSpacingY) or iconFloor), DOCK_SPACING_CROSS.MIN_SPACING_Y)
    if minX > DOCK_SPACING_CROSS.MAX_SPACING_X then
        minX = DOCK_SPACING_CROSS.MAX_SPACING_X
    end
    if minY > DOCK_SPACING_CROSS.MAX_SPACING_Y then
        minY = DOCK_SPACING_CROSS.MAX_SPACING_Y
    end

    local currentX = math.floor(clamp(db.dockSpacingX, DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, db.dockIconSpacing or 6))
    local currentY = math.floor(clamp(db.dockSpacingY, DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, db.dockIconSpacing or 6))
    local nextX = math.floor(clamp(currentX + (tonumber(dx) or 0), DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, currentX))
    local nextY = math.floor(clamp(currentY + (tonumber(dy) or 0), DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, currentY))

    if xAxisActive then
        if nextX < minX then
            nextX = minX
        end
    else
        nextX = currentX
    end

    if yAxisActive then
        if nextY < minY then
            nextY = minY
        end
    else
        nextY = currentY
    end

    local boundaryState = self._dockSpacingBoundaryState
    if type(boundaryState) ~= "table" then
        boundaryState = { x = false, y = false }
        self._dockSpacingBoundaryState = boundaryState
    end

    if nextX == currentX and nextY == currentY then
        boundaryState.x = xAxisActive and (currentX <= minX) or false
        boundaryState.y = yAxisActive and (currentY <= minY) or false
        return false
    end

    db.dockSpacingX = nextX
    db.dockSpacingY = nextY
    self._dockSpacingLastSource = source or "unknown"

    self:ApplyDockLayoutSettings(false)

    local effectiveX = math.floor(tonumber(self._dockEffectiveSpacingX) or db.dockSpacingX or nextX)
    local effectiveY = math.floor(tonumber(self._dockEffectiveSpacingY) or db.dockSpacingY or nextY)
    local atBoundaryX = xAxisActive and (effectiveX <= minX) or false
    local atBoundaryY = yAxisActive and (effectiveY <= minY) or false
    local enteredBoundary = (atBoundaryX and not boundaryState.x) or (atBoundaryY and not boundaryState.y)
    boundaryState.x = atBoundaryX
    boundaryState.y = atBoundaryY
    if enteredBoundary then
        self:PlayDockSpacingBoundaryPulse()
    end

    self:UpdateReadout(true)
    return true
end

function PortalAuthority:ApplyDockTextDirection(direction, source)
    if InCombatLockdown() then
        return false
    end

    local db = PortalAuthorityDB or self.defaults
    local defaults = self.defaults or {}
    local currentDirection = normalizeDockTextDirection(db.dockTextDirection, defaults.dockTextDirection or "BOTTOM")
    local nextDirection = normalizeDockTextDirection(direction, defaults.dockTextDirection or "BOTTOM")
    if nextDirection == currentDirection then
        return false
    end

    db.dockTextDirection = nextDirection
    self._dockTextDirectionLastSource = source or "unknown"
    self:ApplyDockAppearanceSettings()
    self:UpdateTextDirectionReadout(true)
    return true
end

function PortalAuthority:BeginDrag(axis)
    if axis ~= "x" and axis ~= "y" then
        return
    end
    if InCombatLockdown() then
        return
    end

    local db = PortalAuthorityDB or self.defaults
    if db.dockLocked then
        return
    end
    local defaults = self.defaults or {}
    local _, xAxisActive, yAxisActive = getDockSpacingAxisApplicability(db, defaults)
    if (axis == "x" and not xAxisActive) or (axis == "y" and not yAxisActive) then
        return
    end

    local cross = self:CreateDockSpacingCross(self.dockFrame)
    if not cross then
        return
    end

    self:DismissDockSpacingUnlockHint(DOCK_UNLOCK_POPUP_FAST_FADE)
    self:EndDrag()

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale <= 0 then
        scale = 1
    end
    local cx, cy = GetCursorPosition()
    if not cx or not cy then
        return
    end

    self._dockSpacingDrag = {
        axis = axis,
        startCursorX = cx / scale,
        startCursorY = cy / scale,
        startSpacingX = math.floor(clamp(db.dockSpacingX, DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, db.dockIconSpacing or 6)),
        startSpacingY = math.floor(clamp(db.dockSpacingY, DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, db.dockIconSpacing or 6)),
    }
    self._dockIsAdjustingSpacing = true
    hideGameTooltipIfOwnedBy(cross)
    local activeButtons = self.dockActiveButtons or self.dockButtons
    if type(activeButtons) == "table" then
        for i = 1, #activeButtons do
            local activeBtn = activeButtons[i]
            if activeBtn and activeBtn.hover then
                activeBtn.hover:Hide()
            end
        end
    end

    cross._activeAxis = axis
    cross._hoverAxis = axis
    if cross._refreshVisual then
        cross._refreshVisual()
    end

    self:UpdateReadout(true)
    setDockCrossCursor(axis == "x" and DOCK_SPACING_CROSS.CURSOR_X or DOCK_SPACING_CROSS.CURSOR_Y)

    cross:SetScript("OnUpdate", function()
        local drag = PortalAuthority._dockSpacingDrag
        if not drag then
            cross:SetScript("OnUpdate", nil)
            return
        end
        if InCombatLockdown() then
            PortalAuthority:EndDrag()
            PortalAuthority:SetDockSpacingCrossEnabled(false)
            return
        end

        local s = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if not s or s <= 0 then
            s = 1
        end
        local px, py = GetCursorPosition()
        if not px or not py then
            return
        end
        px = px / s
        py = py / s

        local pixelsPerStep = DOCK_SPACING_CROSS.DRAG_PIXELS_PER_STEP
        if IsShiftKeyDown and IsShiftKeyDown() then
            pixelsPerStep = pixelsPerStep * DOCK_SPACING_CROSS.SHIFT_DRAG_MULT
        end
        if IsAltKeyDown and IsAltKeyDown() then
            pixelsPerStep = pixelsPerStep * DOCK_SPACING_CROSS.ALT_DRAG_MULT
        end
        if pixelsPerStep < 1 then
            pixelsPerStep = 1
        end

        local dbNow = PortalAuthorityDB or PortalAuthority.defaults
        if drag.axis == "x" then
            local units = dockSpacingCrossDragUnits((px - drag.startCursorX), pixelsPerStep, "x")
            local targetX = math.floor(clamp(drag.startSpacingX + units, DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, drag.startSpacingX))
            local currentX = math.floor(clamp(dbNow.dockSpacingX, DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, dbNow.dockIconSpacing or 6))
            if targetX ~= currentX then
                PortalAuthority:ApplySpacingDelta(targetX - currentX, 0, "drag-x")
            end
        else
            local units = dockSpacingCrossDragUnits((py - drag.startCursorY), pixelsPerStep, "y")
            local targetY = math.floor(clamp(drag.startSpacingY + units, DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, drag.startSpacingY))
            local currentY = math.floor(clamp(dbNow.dockSpacingY, DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, dbNow.dockIconSpacing or 6))
            if targetY ~= currentY then
                PortalAuthority:ApplySpacingDelta(0, targetY - currentY, "drag-y")
            end
        end
    end)
end

function PortalAuthority:BeginTextDirectionDrag(axis)
    if axis ~= "x" and axis ~= "y" then
        return
    end
    if InCombatLockdown() then
        return
    end

    local db = PortalAuthorityDB or self.defaults
    if db.dockLocked then
        return
    end

    local cross = self:CreateDockTextDirectionCross(self.dockFrame)
    if not cross then
        return
    end

    self:EndTextDirectionDrag()

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale <= 0 then
        scale = 1
    end
    local cx, cy = GetCursorPosition()
    if not cx or not cy then
        return
    end

    self._dockTextDirectionDrag = {
        axis = axis,
        startCursorX = cx / scale,
        startCursorY = cy / scale,
    }

    cross._activeAxis = axis
    cross._hoverAxis = axis
    if cross._refreshVisual then
        cross._refreshVisual()
    end

    self:UpdateTextDirectionReadout(true)
    setDockCrossCursor(axis == "x" and DOCK_TEXT_DIRECTION_CROSS.CURSOR_X or DOCK_TEXT_DIRECTION_CROSS.CURSOR_Y)

    cross:SetScript("OnUpdate", function()
        local drag = PortalAuthority._dockTextDirectionDrag
        if not drag then
            cross:SetScript("OnUpdate", nil)
            return
        end
        if InCombatLockdown() then
            PortalAuthority:EndTextDirectionDrag()
            PortalAuthority:SetDockSpacingCrossEnabled(false)
            return
        end

        local s = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if not s or s <= 0 then
            s = 1
        end
        local px, py = GetCursorPosition()
        if not px or not py then
            return
        end
        px = px / s
        py = py / s

        local nextDirection = nil
        local deadzone = math.max(1, tonumber(DOCK_TEXT_DIRECTION_CROSS.DEADZONE_PIXELS) or 8)
        if drag.axis == "x" then
            local dx = px - drag.startCursorX
            if dx <= -deadzone then
                nextDirection = "LEFT"
            elseif dx >= deadzone then
                nextDirection = "RIGHT"
            end
        else
            local dy = py - drag.startCursorY
            if dy >= deadzone then
                nextDirection = "TOP"
            elseif dy <= -deadzone then
                nextDirection = "BOTTOM"
            end
        end

        if nextDirection then
            PortalAuthority:ApplyDockTextDirection(nextDirection, drag.axis == "x" and "drag-text-x" or "drag-text-y")
        else
            PortalAuthority:UpdateTextDirectionReadout(true)
        end
    end)
end

function PortalAuthority:EndDrag()
    local cross = self.dockSpacingCross
    if cross then
        cross:SetScript("OnUpdate", nil)
        cross._activeAxis = nil
        cross._hoverAxis = nil
        if cross._refreshVisual then
            cross._refreshVisual()
        end
    end

    self._dockSpacingDrag = nil
    self._dockIsAdjustingSpacing = false
    setDockCrossCursor(nil)
    hideGameTooltipIfOwnedBy(cross)
    self:UpdateReadout(false)
end

function PortalAuthority:EndTextDirectionDrag()
    local cross = self.dockTextDirectionCross
    if cross then
        cross:SetScript("OnUpdate", nil)
        cross._activeAxis = nil
        cross._hoverAxis = nil
        if cross._refreshVisual then
            cross._refreshVisual()
        end
    end

    self._dockTextDirectionDrag = nil
    setDockCrossCursor(nil)
    hideGameTooltipIfOwnedBy(cross)
    self:UpdateTextDirectionReadout(false)
end

function PortalAuthority:SetDockSpacingCrossEnabled(isUnlocked)
    local spacingCross = self:CreateDockSpacingCross(self.dockFrame)
    if not spacingCross then
        return
    end

    local db = PortalAuthorityDB or self.defaults
    local enable = isUnlocked and true or false
    if enable and InCombatLockdown() then
        enable = false
    end
    if enable and self.dockFrame and not self.dockFrame:IsShown() then
        enable = false
    end

    if enable then
        spacingCross._baseScale = tonumber(spacingCross._baseScale) or 1
        spacingCross:SetScale(spacingCross._baseScale)
        spacingCross:Show()
        spacingCross:EnableMouse(true)
        spacingCross:EnableMouseWheel(true)
        if spacingCross._refreshVisual then
            spacingCross._refreshVisual()
        end
        if not self._dockSpacingHintShownForUnlock then
            self._dockSpacingHintShownForUnlock = true
            self:ShowDockSpacingUnlockHint()
        end
        if self.dockTextDirectionCross then
            self.dockTextDirectionCross:Hide()
            self.dockTextDirectionCross:EnableMouse(false)
            self.dockTextDirectionCross:EnableMouseWheel(false)
            if self.dockTextDirectionCross.readout then
                self.dockTextDirectionCross.readout:Hide()
            end
        end
        if self.dockCrossContainer then
            self.dockCrossContainer:Hide()
        end
    else
        self:EndDrag()
        self:EndTextDirectionDrag()

        spacingCross:EnableMouse(false)
        spacingCross:EnableMouseWheel(false)
        spacingCross:SetScale(tonumber(spacingCross._baseScale) or 1)
        spacingCross:Hide()
        if spacingCross.readout then
            spacingCross.readout:Hide()
        end
        if spacingCross.unlockHint then
            spacingCross.unlockHint:Hide()
        end
        self._dockSpacingUnlockHintVisible = false
        self._dockSpacingBoundaryState = { x = false, y = false }

        if self.dockTextDirectionCross then
            self.dockTextDirectionCross:EnableMouse(false)
            self.dockTextDirectionCross:EnableMouseWheel(false)
            self.dockTextDirectionCross:Hide()
            if self.dockTextDirectionCross.readout then
                self.dockTextDirectionCross.readout:Hide()
            end
        end
        if self.dockCrossContainer then
            self.dockCrossContainer:Hide()
        end
        if db and db.dockLocked then
            self._dockSpacingHintShownForUnlock = false
        end
    end
end

function PortalAuthority:ClampDockToScreenBounds()
    if not self.dockFrame then
        return false
    end

    local uiW, uiH = UIParent:GetWidth(), UIParent:GetHeight()
    local l, r = self.dockFrame:GetLeft(), self.dockFrame:GetRight()
    local t, b = self.dockFrame:GetTop(), self.dockFrame:GetBottom()
    if not uiW or not uiH or not l or not r or not t or not b then
        return false
    end

    local tolerance = 1
    local db = PortalAuthorityDB or self.defaults
    local dockX = db.dockX or 0
    local dockY = db.dockY or 0
    local changed = false

    if l < -tolerance then
        dockX = dockX + (-l)
        changed = true
    end
    if r > (uiW + tolerance) then
        dockX = dockX - (r - uiW)
        changed = true
    end
    if b < -tolerance then
        dockY = dockY + (-b)
        changed = true
    end
    if t > (uiH + tolerance) then
        dockY = dockY - (t - uiH)
        changed = true
    end

    if changed then
        db.dockX = round(dockX)
        db.dockY = round(dockY)
        self:ApplyDockPosition()
    end

    return changed
end

function PortalAuthority:ApplyDockAnchor()
    self:ApplyDockPosition()
end

function PortalAuthority:SaveDockPosition()
    local perfStart, perfState = PA_PerfBegin("dock_save_position")
    local function finish(...)
        PA_PerfEnd("dock_save_position", perfStart, perfState)
        return ...
    end

    if not self.dockFrame then
        return finish()
    end

    local dockCenterX, dockCenterY = self.dockFrame:GetCenter()
    local parentCenterX, parentCenterY = UIParent:GetCenter()
    if not dockCenterX or not dockCenterY or not parentCenterX or not parentCenterY then
        return finish()
    end

    PortalAuthorityDB.dockX = round(dockCenterX - parentCenterX)
    PortalAuthorityDB.dockY = round(dockCenterY - parentCenterY)

    if self.NotifyDockPositionChanged then
        self:NotifyDockPositionChanged(PortalAuthorityDB.dockX, PortalAuthorityDB.dockY)
    end

    return finish()
end

function PortalAuthority:NotifyDockPositionChanged(x, y)
    self._lastDockX = x
    self._lastDockY = y

    if self.onDockPositionChanged then
        self.onDockPositionChanged(x, y)
    end
end

function PortalAuthority:GetDockOnUpdateHandler()
    if self._dockOnUpdateHandler then
        return self._dockOnUpdateHandler
    end

    self._dockOnUpdateHandler = function()
        local perfStart, perfState = PA_PerfBegin("dock_onupdate")
        PA_CpuDiagCount("dock_onupdate")
        PortalAuthority:HandleDockDragMotion()
        if PortalAuthority.dockDragging then
            PortalAuthority:SaveDockPosition()
        end
        PA_PerfEnd("dock_onupdate", perfStart, perfState)
    end

    return self._dockOnUpdateHandler
end

function PortalAuthority:UpdateDockOnUpdateState()
    if not self.dockFrame then
        return
    end

    local db = PortalAuthorityDB or self.defaults or {}
    local shouldRun = self.dockFrame:IsShown()
        and (not InCombatLockdown())
        and (db.dockLocked == false)
        and (self.dockDragRequested or self.dockDragging)
    local current = self.dockFrame:GetScript("OnUpdate")

    if shouldRun then
        local handler = self:GetDockOnUpdateHandler()
        if current ~= handler then
            self.dockFrame:SetScript("OnUpdate", handler)
        end
    elseif current then
        self.dockFrame:SetScript("OnUpdate", nil)
    end
end

function PortalAuthority:TryStartDockDrag()
    if not self.dockFrame then
        return
    end

    local db = PortalAuthorityDB or self.defaults
    if db.dockLocked then
        return
    end

    if InCombatLockdown() then
        self.dockDragRequested = false
        self.dockDragging = false
        self.dockDragStartX = nil
        self.dockDragStartY = nil
        self:UpdateDockOnUpdateState()
        return
    end

    self:DismissDockSpacingUnlockHint(DOCK_UNLOCK_POPUP_FAST_FADE)
    self.dockDragStartX = nil
    self.dockDragStartY = nil
    self.dockDragRequested = true
    self.dockDragging = false
    self:UpdateDockOnUpdateState()
end

function PortalAuthority:HandleDockDragMotion()
    local perfStart, perfState = PA_PerfBegin("dock_drag_motion")
    local function finish(...)
        PA_PerfEnd("dock_drag_motion", perfStart, perfState)
        return ...
    end

    if not self.dockDragRequested or self.dockDragging or not self.dockFrame then
        return finish()
    end

    if InCombatLockdown() then
        self.dockDragRequested = false
        self.dockDragStartX = nil
        self.dockDragStartY = nil
        self:UpdateDockOnUpdateState()
        return finish()
    end

    local x, y = GetCursorPosition()
    if not x or not y then
        return finish()
    end

    if not self.dockDragStartX or not self.dockDragStartY then
        self.dockDragStartX = x
        self.dockDragStartY = y
        return finish()
    end

    local threshold = 6
    if math.abs(x - self.dockDragStartX) < threshold and math.abs(y - self.dockDragStartY) < threshold then
        return finish()
    end

    self.dockDragging = true
    self.dockFrame:StartMoving()

    self:SaveDockPosition()
    self:UpdateDockOnUpdateState()
    return finish()
end

function PortalAuthority:StopDockDrag()
    if not self.dockFrame then
        return
    end

    if InCombatLockdown() then
        self.dockDragRequested = false
        self.dockDragging = false
        self.dockDragStartX = nil
        self.dockDragStartY = nil
        self:UpdateDockOnUpdateState()
        return
    end

    if self.dockDragging then
        self.dockFrame:StopMovingOrSizing()
        self:SaveDockPosition()
    end

    self.dockDragRequested = false
    self.dockDragging = false
    self.dockDragStartX = nil
    self.dockDragStartY = nil
    self:UpdateDockOnUpdateState()

    local db = PortalAuthorityDB or self.defaults
    if db.dockLocked then
        return
    end

    self:SaveDockPosition()
end

function PortalAuthority:UpdateDockButtonBindings()
    local buttons = self.dockActiveButtons or self.dockButtons
    if not buttons then
        return
    end

    if InCombatLockdown() then
        self:QueueDockUpdate()
        return
    end

    local appliedBindings = false
    for _, btn in ipairs(buttons) do
        if btn then
            btn:RegisterForClicks("AnyDown", "AnyUp")
            btn._paClicks = "AnyDown/AnyUp"
            if type(btn.useItemID) == "number" and btn.useItemID > 0 then
                btn:SetAttribute("type", "item")
                btn:SetAttribute("item", "item:" .. tostring(btn.useItemID))
                btn:SetAttribute("spell", nil)
            elseif type(btn.spellID) == "number" and btn.spellID > 0 then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", btn.spellID)
                btn:SetAttribute("item", nil)
            else
                btn:SetAttribute("type", nil)
                btn:SetAttribute("spell", nil)
                btn:SetAttribute("item", nil)
            end
            btn:SetAttribute("shift-type1", nil)
            btn:SetAttribute("shift-spell1", nil)
            btn:SetAttribute("shift-item1", nil)
            appliedBindings = true
        end
    end

    if appliedBindings then
        self._dockBindApplyCount = (self._dockBindApplyCount or 0) + 1
    end

end

function PortalAuthority:DebugDockBindingState()
    local fsobj = _G and _G.fsobj or nil
    local target = nil

    if fsobj then
        local node = fsobj
        while node do
            if node.GetObjectType and node:GetObjectType() == "Button" and node.GetAttribute and node.IsProtected and node:IsProtected() then
                target = node
                break
            end
            if not node.GetParent then
                break
            end
            node = node:GetParent()
        end
    end

    local usedFallback = false
    if not target and self.dockButtons then
        target = self.dockButtons[1]
        usedFallback = target ~= nil
    end

    local lines = {}
    local function addLine(key, value)
        lines[#lines + 1] = string.format("  %s: %s", key, tostring(value))
    end

    lines[#lines + 1] = "|cffff7f50Portal Authority Dock Debug:|r"
    addLine("target name", target and target.GetName and (target:GetName() or "<unnamed>") or "<none>")

    if not target then
        addLine("IsProtected", "<target missing>")
        addLine("attr.type", "<target missing>")
        addLine("attr.spell", "<target missing>")
        addLine("spellID", "<target missing>")
        addLine("IsSpellKnown", "<target missing>")
        addLine("DoesSpellExist", "<target missing>")
        print(table.concat(lines, "\n"))
        return
    end

    addLine("IsProtected", target.IsProtected and target:IsProtected() or "<api missing>")
    addLine("attr.type", target.GetAttribute and target:GetAttribute("type") or "<api missing>")
    addLine("attr.spell", target.GetAttribute and target:GetAttribute("spell") or "<api missing>")
    addLine("spellID", target.spellID)

    local spellID = target.spellID
    if type(spellID) == "number" then
        local spellExists = "<api missing>"
        if C_Spell and C_Spell.DoesSpellExist then
            spellExists = C_Spell.DoesSpellExist(spellID)
        end
        addLine("DoesSpellExist", spellExists)

        local isKnown = "<api missing>"
        if IsSpellKnown then
            isKnown = IsSpellKnown(spellID)
        end
        addLine("IsSpellKnown", isKnown)
    else
        addLine("DoesSpellExist", "<spellID missing>")
        addLine("IsSpellKnown", "<spellID missing>")
    end

    print(table.concat(lines, "\n"))
end

function PortalAuthority:ResetDockAnchor()
    local db = PortalAuthorityDB or self.defaults
    db.dockX = 0
    db.dockY = 0
    self:ApplyDockPosition()
end

function PortalAuthority:InvalidateDockLabelCaches()
    local buttons = self.dockActiveButtons or self.dockButtons
    if type(buttons) == "table" then
        for i = 1, #buttons do
            invalidateDockButtonLabelCache(buttons[i])
        end
    end
    if (tonumber(self._paDockLabelAnimActiveCount) or 0) == 0 then
        self._paDockLabelSettlePending = nil
    end
end

function PortalAuthority:ResetDockDiagCounters()
    self._dockDiagVisibilityRefreshCount = 0
    self._dockDiagFrameShowCount = 0
    self._dockDiagFrameHideCount = 0
end

local function PA_IsUiSurfaceGateEnabled()
    return PortalAuthority and PortalAuthority.IsUiSurfaceGateEnabled and PortalAuthority:IsUiSurfaceGateEnabled() or false
end

function PortalAuthority:RefreshDockForDiagnostics()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if not self.dockFrame and self.InitializeDock then
        self:InitializeDock()
    end

    if InCombatLockdown() then
        if self.QueueDockUpdate then
            self:QueueDockUpdate()
        end
        if self.QueueDockVisibilityRefresh then
            self:QueueDockVisibilityRefresh()
        end
        return
    end

    if self.RebuildDock then
        self:RebuildDock(false)
    end
    if self.UpdateDockVisibility then
        self:UpdateDockVisibility(true)
    elseif self.RefreshDockVisibility then
        self:RefreshDockVisibility(true)
    end
end

function PortalAuthority:RefreshDockVisibilityForDiagnostics()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if not self.dockFrame and self.InitializeDock then
        self:InitializeDock()
    end

    if InCombatLockdown() then
        if self.QueueDockVisibilityRefresh then
            self:QueueDockVisibilityRefresh()
        end
        return
    end

    if self.UpdateDockVisibility then
        self:UpdateDockVisibility(true)
    elseif self.RefreshDockVisibility then
        self:RefreshDockVisibility(true)
    end
end

function PortalAuthority:SetDockDiagLabelMode(mode)
    if mode == nil then
        self._dockDiagLabelMode = nil
    else
        self._dockDiagLabelMode = normalizeDockLabelMode(mode, (self.defaults and self.defaults.dockLabelMode) or "OUTSIDE")
    end
    self:InvalidateDockLabelCaches()
    self:RefreshDockForDiagnostics()
end

function PortalAuthority:SetDockDiagLabelRenderMode(mode)
    if mode == nil then
        self._dockDiagLabelRenderMode = nil
    else
        self._dockDiagLabelRenderMode = normalizeDockLabelRenderMode(mode, "NORMAL")
    end
    self:InvalidateDockLabelCaches()
    self:RefreshDockForDiagnostics()
end

function PortalAuthority:SetDockDiagSortMode(mode)
    if mode == nil then
        self._dockDiagSortMode = nil
    else
        self._dockDiagSortMode = normalizeDockSortMode(mode, (self.defaults and self.defaults.dockSortMode) or "ROW_ORDER")
    end
    self:RefreshDockForDiagnostics()
end

function PortalAuthority:SetDockDiagVisibilityMode(mode)
    if mode == nil then
        self._dockDiagVisibilityMode = nil
    else
        self._dockDiagVisibilityMode = normalizeDockVisibilityMode(mode, "NORMAL")
    end
    self:RefreshDockVisibilityForDiagnostics()
end

function PortalAuthority:ResetDockDiagOverrides()
    self._dockDiagLabelMode = nil
    self._dockDiagSortMode = nil
    self._dockDiagLabelRenderMode = nil
    self._dockDiagVisibilityMode = nil
    self:InvalidateDockLabelCaches()
    self:RefreshDockForDiagnostics()
    self:ResetDockDiagCounters()
end

function PortalAuthority:GetDockDiagStatusLines()
    local db = PortalAuthorityDB or self.defaults or {}
    local inInstance, instanceType = IsInInstance()
    local dockShown = self.dockFrame and self.dockFrame.IsShown and self.dockFrame:IsShown() and true or false
    local effectiveSortMode = getEffectiveDockSortMode(db, self.defaults or {})
    local persistedSortMode = (type(db) == "table") and db.dockSortMode or nil
    local effectiveLabelMode = self._dockEffectiveLabelMode or getEffectiveDockLabelMode(db, self.defaults or {})
    local effectiveLabelRenderMode = getEffectiveDockLabelRenderMode()
    local activeButtons = self.dockActiveButtons or self.dockButtons or {}
    local activeButtonCount = 0
    for i = 1, #activeButtons do
        if activeButtons[i] then
            activeButtonCount = activeButtonCount + 1
        end
    end

    local lines = {}
    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority DockDiag:|r shown=%s enabled=%s locked=%s resting=%s instance=%s",
        tostring(dockShown),
        tostring(db.dockEnabled and true or false),
        tostring(db.dockLocked ~= false),
        tostring(IsResting and IsResting() or false),
        tostring(inInstance and (instanceType or "unknown") or "none")
    )
    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority DockDiag:|r sort=%s persisted=%s label=%s entries=%d activeButtons=%d",
        tostring(effectiveSortMode),
        tostring(persistedSortMode or "<nil>"),
        tostring(effectiveLabelMode),
        tonumber(self.dockEntriesCount) or 0,
        activeButtonCount
    )
    if self._dockUnexpectedPersistedSortMode then
        lines[#lines + 1] = string.format(
            "|cffffd100Portal Authority DockDiag:|r sortaudit value=%s source=%s",
            tostring(self._dockUnexpectedPersistedSortMode),
            tostring(self._dockUnexpectedPersistedSortModeSource or "<unknown>")
        )
    end
    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority DockDiag:|r order=%s transition=%s labelAnimActive=%d settleRunning=%s",
        tostring(self._dockOrderSignature or "<nil>"),
        tostring(self._dockTransitionMode or "<nil>"),
        tonumber(self._paDockLabelAnimActiveCount) or 0,
        tostring(self._paDockLabelSettleRunning and true or false)
    )
    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority DockDiag:|r overrides label=%s sort=%s labelrender=%s visoverride=%s",
        tostring(self._dockDiagLabelMode or "<none>"),
        tostring(self._dockDiagSortMode or "<none>"),
        tostring(effectiveLabelRenderMode),
        tostring(self._dockDiagVisibilityMode or "<none>")
    )
    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority DockDiag:|r visRefresh=%d show=%d hide=%d lastReason=%s",
        tonumber(self._dockDiagVisibilityRefreshCount) or 0,
        tonumber(self._dockDiagFrameShowCount) or 0,
        tonumber(self._dockDiagFrameHideCount) or 0,
        tostring(self._dockDiagLastVisibilityReason or "<none>")
    )
    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority DockDiag:|r naturalReason=%s effectiveReason=%s",
        tostring(self._dockDiagNaturalVisibilityReason or "<none>"),
        tostring(self._dockDiagEffectiveVisibilityReason or "<none>")
    )
    return lines
end

local function getDockLabelText(db, dungeon)
    if db.dockHideDungeonName then
        return ""
    end
    if db.dockUseShortNames then
        return dungeon.short or dungeon.dest or ""
    end
    return dungeon.dest or dungeon.short or ""
end

local function getVerticalLabelPadding(db)
    local padding = 4

    if db.dockTextOutline and db.dockTextOutline ~= "" then
        padding = padding + 2
    end

    if db.dockTextShadow then
        padding = padding + math.abs(db.dockShadowOffsetX or 0) + math.abs(db.dockShadowOffsetY or 0)
    end

    return padding
end

function PortalAuthority:UpdateDockButtonState(btn)
    if not btn then
        return
    end

    local perfStart, perfState = PA_PerfBegin("dock_update_button_state")
    local db = PortalAuthorityDB or self.defaults
    local available = false
    if type(btn.useItemID) == "number" and btn.useItemID > 0 then
        available = true
        if GetItemCount then
            local itemCount = tonumber(GetItemCount(btn.useItemID, true)) or 0
            available = itemCount > 0
        end
        if available and IsUsableItem then
            local usable = IsUsableItem(btn.useItemID)
            if usable == false then
                available = false
            end
        end
    else
        available = isSpellAvailable(btn.spellID)
        if IsSpellKnown and type(btn.spellID) == "number" and btn.spellID > 0 then
            available = IsSpellKnown(btn.spellID) and true or false
        end
    end
    btn.isAvailable = available
    if btn.icon then
        btn.icon:SetDesaturated(not available)
        btn.icon:SetAlpha(available and 1 or (db.dockInactiveAlpha or 0.5))
    end
    if btn.label then
        local labelMode = self._dockEffectiveLabelMode or getEffectiveDockLabelMode(db, self.defaults or {})
        local showLabels = shouldShowDockLabels(db, labelMode)
        local labelRenderMode = self._dockCurrentLabelRenderMode or getEffectiveDockLabelRenderMode()
        local labelStyleSignature = self._dockCurrentLabelStyleSignature or buildDockLabelStyleSignature(db, labelRenderMode)
        applyDockButtonLabelState(btn, {
            visible = showLabels,
            text = buildDockLabelRenderedText(btn.destinationName or "", labelRenderMode),
            styleSignature = labelStyleSignature,
            renderMode = labelRenderMode,
        })
    end

    if btn.cooldown then
        if available then
            local startTime, duration = getSpellCooldownData(btn.spellID)

            if startTime ~= nil and duration ~= nil then
                btn.cooldown:SetCooldown(startTime, duration)
            else
                btn.cooldown:SetCooldown(0, 0)
            end

            btn.cooldownEndTime = nil
            if btn.cooldownText then
                btn.cooldownText:SetText("")
                btn.cooldownText:Hide()
            end
            btn:SetScript("OnUpdate", nil)

            local ok, hasRemaining, cooldownEndTime = pcall(function()
                local endTime = startTime + duration
                local remaining = math.max(0, endTime - GetTime())
                return remaining > 0, endTime
            end)

            if ok and hasRemaining then
                btn.cooldownEndTime = cooldownEndTime
                updateCooldownText(btn)
                btn:SetScript("OnUpdate", function(selfButton)
                    local perfStart, perfState = PA_PerfBegin("dock_button_cooldown_onupdate")
                    PA_CpuDiagCount("dock_button_cooldown_onupdate")
                    updateCooldownText(selfButton)
                    PA_PerfEnd("dock_button_cooldown_onupdate", perfStart, perfState)
                end)
            end
        else
            btn.cooldown:SetCooldown(0, 0)
            btn.cooldownEndTime = nil
            if btn.cooldownText then
                btn.cooldownText:SetText("")
                btn.cooldownText:Hide()
            end
            btn:SetScript("OnUpdate", nil)
        end
    end

    if btn.hover then
        local glowAlpha = 0.22
        local glowSize = 0
        btn.hover:SetVertexColor(1, 1, 1, glowAlpha)
        if btn.icon then
            btn.hover:ClearAllPoints()
            btn.hover:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", -glowSize, glowSize)
            btn.hover:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", glowSize, -glowSize)
        end
        btn.hover:SetShown(false)
    end

    PA_PerfEnd("dock_update_button_state", perfStart, perfState)
end

function PortalAuthority:UpdateDockButtonStates()
    local buttons = self.dockActiveButtons or self.dockButtons
    if not buttons then
        return
    end

    local perfStart, perfState = PA_PerfBegin("dock_update_button_states")
    self._dockCurrentLabelRenderMode = getEffectiveDockLabelRenderMode()
    self._dockCurrentLabelStyleSignature = buildDockLabelStyleSignature(PortalAuthorityDB or self.defaults or {}, self._dockCurrentLabelRenderMode)
    for _, btn in ipairs(buttons) do
        if btn:IsShown() then
            self:UpdateDockButtonState(btn)
        end
    end
    self._dockCurrentLabelRenderMode = nil
    self._dockCurrentLabelStyleSignature = nil
    PA_PerfEnd("dock_update_button_states", perfStart, perfState)
end

function PortalAuthority:Dock_AssignButtons(entries)
    if not self.dockButtonPool then
        return
    end
    if InCombatLockdown() then
        self:QueueDockUpdate()
        return
    end

    self.dockButtonPool:ReleaseAll()
    self.dockActiveButtons = {}
    self.dockButtons = self.dockActiveButtons

    for i = 1, #entries do
        local entry = entries[i]
        local btn = self.dockButtonPool:Acquire()
        if not btn._paInitialized then
            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
            btn.labelArea = CreateFrame("Frame", nil, btn)
            btn.labelArea:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.labelArea:SetSize(1, 1)
            btn.labelArea:EnableMouse(false)
            btn.label = btn.labelArea:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            btn.label:SetJustifyH("CENTER")
            btn.label:SetJustifyV("TOP")
            btn.label:SetPoint("LEFT", btn.labelArea, "LEFT", 0, 0)
            btn.label:SetPoint("RIGHT", btn.labelArea, "RIGHT", 0, 0)
            btn.label:SetPoint("TOP", btn.labelArea, "TOP", 0, 0)
            btn.label:SetPoint("BOTTOM", btn.labelArea, "BOTTOM", 0, 0)
            btn.hover = btn:CreateTexture(nil, "HIGHLIGHT")
            btn.hover:SetTexture("Interface\\Buttons\\WHITE8x8")
            btn.hover:SetVertexColor(1, 1, 1, 0.15)
            btn.hover:SetAllPoints()
            btn.hover:Hide()
            btn:SetScript("OnEnter", function(selfButton)
                local db = PortalAuthorityDB or PortalAuthority.defaults
                if PortalAuthority and PortalAuthority._dockIsAdjustingSpacing then
                    if selfButton.hover then
                        selfButton.hover:Hide()
                    end
                    hideGameTooltipIfOwnedBy(selfButton)
                    return
                end
                if db.dockHoverGlow and selfButton.hover then
                    selfButton.hover:Show()
                end
                if selfButton.spellID and selfButton.spellID > 0 then
                    GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
                    if GameTooltip.SetSpellByID then
                        GameTooltip:SetSpellByID(selfButton.spellID)
                    else
                        GameTooltip:SetText(selfButton.destinationName or "Unknown")
                    end
                    GameTooltip:Show()
                end
            end)
            btn:SetScript("OnLeave", function(selfButton)
                if selfButton.hover then
                    selfButton.hover:Hide()
                end
                hideGameTooltipIfOwnedBy(selfButton)
            end)
            btn._paInitialized = true
        end

        invalidateDockButtonLabelCache(btn)

        btn.entry = entry
        btn.slotIndex = entry.slotIndex
        btn.spellID = entry.spellID
        btn.useItemID = entry.useItemID
        btn.destinationName = entry.name or getSpellNameByID(entry.spellID)
        btn.icon:SetTexture(getSpellTextureByID(entry.spellID) or "Interface\\ICONS\\INV_Misc_QuestionMark")
        btn.icon:SetTexCoord(0, 1, 0, 1)
        btn:Show()
        table.insert(self.dockActiveButtons, btn)
    end
end

function PortalAuthority:Dock_UpdateLayout(entries, animateAllowed)
    if not self.dockFrame or not self.dockIconContainer then
        return
    end

    local db = PortalAuthorityDB or self.defaults
    local iconSize = math.max(16, math.floor(tonumber(db.dockIconSize) or 36))
    self._dockEffectiveIconSize = iconSize
    db.dockIconSizeUI = iconSize
    local baseSpacingX = math.floor(clamp(db.dockSpacingX, DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, db.dockIconSpacing or 6))
    local baseSpacingY = math.floor(clamp(db.dockSpacingY, DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, db.dockIconSpacing or 6))
    local padding = math.max(0, math.floor(tonumber(db.dockPadding) or 6))
    local spacingX = baseSpacingX
    local spacingY = baseSpacingY
    local mode = resolveDockSimpleLayoutModeFromDB(db, self.defaults or {})
    self._dockEffectiveLayoutMode = mode
    local iconsPerLine = math.floor(clamp(db.dockIconsPerLine, 1, 10, 4))
    local labelMode = getEffectiveDockLabelMode(db, self.defaults or {})
    local labelSide = getEffectiveDockLabelSide(db, self.defaults or {}, labelMode)
    self._dockEffectiveLabelMode = labelMode
    self._dockEffectiveLabelSide = labelSide
    if getDockDiagLabelModeOverride() == nil then
        db.dockLabelMode = labelMode
        db.dockLabelSide = labelSide
    end
    local showNames = shouldShowDockLabels(db, labelMode)
    local labelPaddingX = math.max(2, math.floor(iconSize * 0.08))
    local labelPaddingY = math.max(1, math.floor(iconSize * 0.05))
    local outsideGap = 2
    local insideInset = 2
    local cellW = iconSize
    local cellH = iconSize
    local count = #entries
    local labelRenderMode = getEffectiveDockLabelRenderMode()
    local labelStyleSignature = showNames and buildDockLabelStyleSignature(db, labelRenderMode) or nil

    local maxTextW = 0
    local maxTextH = 0
    if showNames then
        -- Measure with the hidden probe only; do not touch live button label/cache state here.
        for index = 1, count do
            local btn = self.dockActiveButtons[index]
            if btn then
                local textWidth, textHeight = measureDockLabelText(btn.destinationName or "")
                if textWidth > maxTextW then
                    maxTextW = textWidth
                end
                if textHeight > maxTextH then
                    maxTextH = textHeight
                end
            end
        end
    end

    local outsideLabelBlockW = 0
    local outsideLabelBlockH = 0
    local outsideReserveX = 0
    local outsideReserveY = 0
    if showNames and labelMode == "OUTSIDE" then
        -- Side-independent footprint so switching Bottom/Top/Left/Right never moves icons.
        outsideLabelBlockW = math.max(
            math.floor((iconSize * 0.75) + 0.5),
            maxTextW + (labelPaddingX * 2)
        )
        outsideLabelBlockH = math.max(
            math.floor((iconSize * 0.32) + 0.5),
            maxTextH + (labelPaddingY * 2)
        )
        outsideReserveX = outsideLabelBlockW + outsideGap
        outsideReserveY = outsideLabelBlockH + outsideGap
        cellW = iconSize + (outsideReserveX * 2)
        cellH = iconSize + (outsideReserveY * 2)
    end

    local minSpacingX = iconSize
    local minSpacingY = iconSize
    if showNames and labelMode == "OUTSIDE" then
        -- Outside labels behave as a one-sided extension:
        -- cross can compress until the extension touches adjacent icon/label,
        -- but cannot overlap.
        if labelSide == "LEFT" or labelSide == "RIGHT" then
            minSpacingX = iconSize + outsideReserveX
            minSpacingY = iconSize
        else -- TOP / BOTTOM
            minSpacingX = iconSize
            minSpacingY = iconSize + outsideReserveY
        end
    end
    spacingX = math.max(spacingX, minSpacingX)
    spacingY = math.max(spacingY, minSpacingY)

    self._dockMinSpacingX = math.floor(minSpacingX + 0.5)
    self._dockMinSpacingY = math.floor(minSpacingY + 0.5)
    self._dockEffectiveSpacingX = math.floor(spacingX + 0.5)
    self._dockEffectiveSpacingY = math.floor(spacingY + 0.5)
    db.dockSpacingX = self._dockEffectiveSpacingX
    db.dockSpacingY = self._dockEffectiveSpacingY

    local footprintW = cellW
    local footprintH = cellH

    local rows = 0
    local cols = 0
    if count > 0 then
        if mode == "HORIZONTAL_ROW" then
            rows = 1
            cols = count
        elseif mode == "VERTICAL_COLUMN" then
            rows = count
            cols = 1
        else
            local lineCount = math.max(1, math.min(iconsPerLine, count))
            cols = lineCount
            rows = math.ceil(count / lineCount)
        end
    end

    self._dockAppliedLabelGap = nil
    self._dockLabelGapLimited = false
    self._dockLabelGapLimitedHard = false

    local gridW = cols > 0 and ((((cols - 1) * spacingX) + footprintW)) or 0
    local gridH = rows > 0 and ((((rows - 1) * spacingY) + footprintH)) or 0
    self.dockFrame:SetSize(math.max(1, gridW + (padding * 2)), math.max(1, gridH + (padding * 2)))
    self.dockIconContainer:ClearAllPoints()
    self.dockIconContainer:SetPoint("TOPLEFT", self.dockFrame, "TOPLEFT", padding, -padding)
    self.dockIconContainer:SetPoint("BOTTOMRIGHT", self.dockFrame, "BOTTOMRIGHT", -padding, padding)

    local transitionMode = self._dockTransitionMode
    local allowTransitionAnimation = animateAllowed and not InCombatLockdown()
    local allowIconMove = allowTransitionAnimation and (transitionMode == "LAYOUT")
    local allowLabelMove = allowTransitionAnimation and (transitionMode == "LABEL")
    local iconMoveDuration = 0.22
    local labelMoveDuration = 0.15

    for index = 1, #entries do
        local btn = self.dockActiveButtons[index]
        if btn then
            local oldScreenCx = allowIconMove and tonumber(btn._animFromScreenCx) or nil
            local oldScreenCy = allowIconMove and tonumber(btn._animFromScreenCy) or nil
            local oldLabelCx = nil
            local oldLabelCy = nil
            if allowLabelMove then
                oldLabelCx = tonumber(btn._animFromLabelCx)
                oldLabelCy = tonumber(btn._animFromLabelCy)
                if oldLabelCx == nil then
                    oldLabelCx = tonumber(btn._lastLabelCx)
                end
                if oldLabelCy == nil then
                    oldLabelCy = tonumber(btn._lastLabelCy)
                end
            end

            if btn._moveAG and btn._moveAG.IsPlaying and btn._moveAG:IsPlaying() then
                btn._moveAG:Stop()
            end
            if allowLabelMove and btn.labelArea and btn.labelArea._paLabelMoveAG and btn.labelArea._paLabelMoveAG.IsPlaying and btn.labelArea._paLabelMoveAG:IsPlaying() then
                btn.labelArea._paLabelMoveAG:Stop()
                releaseDockButtonLabelMoveActive(btn)
                if PortalAuthority and (tonumber(PortalAuthority._paDockLabelAnimActiveCount) or 0) == 0 then
                    PortalAuthority._paDockLabelSettlePending = nil
                end
            end

            local row, col
            if mode == "HORIZONTAL_ROW" then
                row = 1
                col = index
            elseif mode == "VERTICAL_COLUMN" then
                col = 1
                row = index
            else
                local perRow = math.max(1, math.min(iconsPerLine, count))
                row = math.floor((index - 1) / perRow) + 1
                col = ((index - 1) % perRow) + 1
            end

            local xPos = (col - 1) * spacingX
            local yPos = -((row - 1) * spacingY)
            local btnX = xPos
            local btnY = yPos
            if showNames and labelMode == "OUTSIDE" then
                btnX = btnX + outsideReserveX
                btnY = btnY - outsideReserveY
            end

            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.dockIconContainer, "TOPLEFT", btnX, btnY)
            -- Keep secure click/hover area exactly icon-sized.
            btn:SetSize(iconSize, iconSize)
            btn._lastX = xPos
            btn._lastY = yPos
            btn._lastAnchorX = btnX
            btn._lastAnchorY = btnY

            btn.icon:ClearAllPoints()
            btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
            btn.icon:SetSize(iconSize, iconSize)
            local newLabelCx = nil
            local newLabelCy = nil
            if showNames then
                if not btn.labelArea then
                    btn.labelArea = CreateFrame("Frame", nil, btn)
                    btn.labelArea:SetPoint("CENTER", btn, "CENTER", 0, 0)
                    btn.labelArea:SetSize(1, 1)
                    btn.labelArea:EnableMouse(false)
                end
                local labelAreaWidth = iconSize
                local labelAreaHeight = math.max(8, maxTextH + (labelPaddingY * 2))
                local padLeft = labelPaddingX
                local padRight = labelPaddingX
                local padTop = labelPaddingY
                local padBottom = labelPaddingY
                local mappedJustify = "CENTER"
                local areaAnchorPoint = "CENTER"
                local areaAnchorRelativeTo = btn.icon
                local areaAnchorRelativePoint = "CENTER"
                local areaAnchorX = 0
                local areaAnchorY = 0

                if labelMode == "OUTSIDE" then
                    if labelSide == "LEFT" or labelSide == "RIGHT" then
                        labelAreaWidth = outsideLabelBlockW
                        labelAreaHeight = iconSize
                        mappedJustify = (labelSide == "LEFT") and "RIGHT" or "LEFT"
                        if labelSide == "LEFT" then
                            padRight = 0
                        else
                            padLeft = 0
                        end
                    else
                        labelAreaWidth = iconSize
                        labelAreaHeight = outsideLabelBlockH
                        mappedJustify = "CENTER"
                        if labelSide == "TOP" then
                            padBottom = 0
                        else
                            padTop = 0
                        end
                    end
                else -- INSIDE
                    labelAreaWidth = math.max(1, iconSize - (insideInset * 2))
                    labelAreaHeight = math.max(8, math.min(iconSize - (insideInset * 2), maxTextH + (labelPaddingY * 2)))
                    mappedJustify = "CENTER"
                end

                if labelMode == "OUTSIDE" then
                    if labelSide == "RIGHT" then
                        areaAnchorPoint = "LEFT"
                        areaAnchorRelativePoint = "RIGHT"
                        areaAnchorX = outsideGap
                        areaAnchorY = 0
                        newLabelCx = (iconSize / 2) + outsideGap + (labelAreaWidth / 2)
                        newLabelCy = 0
                    elseif labelSide == "LEFT" then
                        areaAnchorPoint = "RIGHT"
                        areaAnchorRelativePoint = "LEFT"
                        areaAnchorX = -outsideGap
                        areaAnchorY = 0
                        newLabelCx = -((iconSize / 2) + outsideGap + (labelAreaWidth / 2))
                        newLabelCy = 0
                    elseif labelSide == "TOP" then
                        areaAnchorPoint = "BOTTOM"
                        areaAnchorRelativePoint = "TOP"
                        areaAnchorX = 0
                        areaAnchorY = outsideGap
                        newLabelCx = 0
                        newLabelCy = (iconSize / 2) + outsideGap + (labelAreaHeight / 2)
                    else -- BOTTOM
                        areaAnchorPoint = "TOP"
                        areaAnchorRelativePoint = "BOTTOM"
                        areaAnchorX = 0
                        areaAnchorY = -outsideGap
                        newLabelCx = 0
                        newLabelCy = -((iconSize / 2) + outsideGap + (labelAreaHeight / 2))
                    end
                else -- INSIDE
                    if labelSide == "TOP" then
                        areaAnchorPoint = "TOP"
                        areaAnchorRelativePoint = "TOP"
                        areaAnchorX = 0
                        areaAnchorY = -insideInset
                        newLabelCx = 0
                        newLabelCy = (iconSize / 2) - insideInset - (labelAreaHeight / 2)
                    elseif labelSide == "BOTTOM" then
                        areaAnchorPoint = "BOTTOM"
                        areaAnchorRelativePoint = "BOTTOM"
                        areaAnchorX = 0
                        areaAnchorY = insideInset
                        newLabelCx = 0
                        newLabelCy = -((iconSize / 2) - insideInset - (labelAreaHeight / 2))
                    else
                        areaAnchorPoint = "CENTER"
                        areaAnchorRelativePoint = "CENTER"
                        areaAnchorX = 0
                        areaAnchorY = 0
                        newLabelCx = 0
                        newLabelCy = 0
                    end
                end

                local labelContentW = math.max(1, labelAreaWidth - (padLeft + padRight))
                applyDockButtonLabelState(btn, {
                    visible = true,
                    text = buildDockLabelRenderedText(btn.destinationName or "", labelRenderMode),
                    styleSignature = labelStyleSignature,
                    renderMode = labelRenderMode,
                    areaWidth = labelAreaWidth,
                    areaHeight = labelAreaHeight,
                    areaAnchorPoint = areaAnchorPoint,
                    areaAnchorRelativeTo = areaAnchorRelativeTo,
                    areaAnchorRelativePoint = areaAnchorRelativePoint,
                    areaAnchorX = areaAnchorX,
                    areaAnchorY = areaAnchorY,
                    padLeft = padLeft,
                    padRight = padRight,
                    padTop = padTop,
                    padBottom = padBottom,
                    contentWidth = labelContentW,
                    justifyH = mappedJustify,
                    justifyV = "MIDDLE",
                    labelCenterX = newLabelCx,
                    labelCenterY = newLabelCy,
                })
                btn._paDesiredLabelJustifyH = mappedJustify
                btn._paDesiredLabelWidth = labelContentW
                btn._paDesiredPadLeft = padLeft
                btn._paDesiredPadRight = padRight
                btn._paDesiredPadTop = padTop
                btn._paDesiredPadBottom = padBottom
            else
                applyDockButtonLabelState(btn, {
                    visible = false,
                    text = buildDockLabelRenderedText(btn.destinationName or "", labelRenderMode),
                    styleSignature = labelStyleSignature,
                    renderMode = labelRenderMode,
                })
                btn._paDesiredLabelJustifyH = nil
                btn._paDesiredLabelWidth = nil
                btn._paDesiredPadLeft = nil
                btn._paDesiredPadRight = nil
                btn._paDesiredPadTop = nil
                btn._paDesiredPadBottom = nil
                btn.icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
            end

            btn.cooldown:ClearAllPoints()
            btn.cooldown:SetAllPoints(btn.icon)

            if btn.hover then
                local glowSize = 0
                local glowAlpha = 0.22
                btn.hover:ClearAllPoints()
                btn.hover:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", -glowSize, glowSize)
                btn.hover:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", glowSize, -glowSize)
                btn.hover:SetVertexColor(1, 1, 1, glowAlpha)
            end

            if allowIconMove and oldScreenCx and oldScreenCy then
                local newCx, newCy = btn:GetCenter()
                if newCx and newCy then
                    local dx = oldScreenCx - newCx
                    local dy = oldScreenCy - newCy
                    if math.abs(dx) + math.abs(dy) >= 1 then
                        if not btn._moveAG then
                            local ag = btn:CreateAnimationGroup()
                            local prep = ag:CreateAnimation("Translation")
                            prep:SetOrder(1)
                            prep:SetDuration(0)

                            local slide = ag:CreateAnimation("Translation")
                            slide:SetOrder(2)
                            slide:SetDuration(iconMoveDuration)
                            if slide.SetSmoothing then
                                slide:SetSmoothing("OUT")
                            end

                            btn._moveAG = ag
                            btn._movePrep = prep
                            btn._moveAnim = slide
                        end

                        if btn._moveAG and btn._movePrep and btn._moveAnim then
                            btn._movePrep:SetOffset(dx, dy)
                            btn._moveAnim:SetOffset(-dx, -dy)
                            btn._moveAnim:SetDuration(iconMoveDuration)
                            if btn._moveAnim.SetSmoothing then
                                btn._moveAnim:SetSmoothing("OUT")
                            end
                            btn._moveAG:Play()
                        end
                    end
                end
            end

            if allowLabelMove and showNames and btn.labelArea and newLabelCx and newLabelCy then
                if oldLabelCx == nil then
                    oldLabelCx = 0
                end
                if oldLabelCy == nil then
                    oldLabelCy = 0
                end
                local ldx = oldLabelCx - newLabelCx
                local ldy = oldLabelCy - newLabelCy
                if math.abs(ldx) + math.abs(ldy) >= 1 then
                    if not btn.labelArea._paLabelMoveAG then
                        local lag = btn.labelArea:CreateAnimationGroup()
                        local lprep = lag:CreateAnimation("Translation")
                        lprep:SetOrder(1)
                        lprep:SetDuration(0)

                        local lslide = lag:CreateAnimation("Translation")
                        lslide:SetOrder(2)
                        lslide:SetDuration(labelMoveDuration)
                        if lslide.SetSmoothing then
                            lslide:SetSmoothing("OUT")
                        end

                        btn.labelArea._paLabelMoveAG = lag
                        btn.labelArea._paLabelMovePrep = lprep
                        btn.labelArea._paLabelMoveAnim = lslide
                        lag:SetScript("OnFinished", function(group)
                            local area = group and group:GetParent() or nil
                            local ownerBtn = area and area:GetParent() or nil
                            if ownerBtn and ownerBtn.labelArea and ownerBtn.labelArea._paLabelMoveActive then
                                releaseDockButtonLabelMoveActive(ownerBtn)
                                if PortalAuthority then
                                    local activeCount = tonumber(PortalAuthority._paDockLabelAnimActiveCount) or 0
                                    if activeCount == 0 and PortalAuthority._paDockLabelSettlePending and not PortalAuthority._paDockLabelSettleRunning and PortalAuthority.RebuildDock then
                                        local settleStart, settleState = PA_PerfBegin("dock_label_settle_rebuild")
                                        PortalAuthority._paDockLabelSettleRunning = true
                                        local preSettleBySlot = {}
                                        local beforeButtons = PortalAuthority.dockActiveButtons or {}
                                        for i = 1, #beforeButtons do
                                            local b = beforeButtons[i]
                                            local slot = b and b.slotIndex
                                            if slot and b.labelArea and b.labelArea.IsShown and b.labelArea:IsShown() then
                                                local cx, cy = b.labelArea:GetCenter()
                                                if cx and cy then
                                                    preSettleBySlot[slot] = { x = cx, y = cy }
                                                end
                                            end
                                        end
                                        PortalAuthority:RebuildDock(false)
                                        local settleDuration = 0.12
                                        local afterButtons = PortalAuthority.dockActiveButtons or {}
                                        for i = 1, #afterButtons do
                                            local b = afterButtons[i]
                                            local slot = b and b.slotIndex
                                            local from = slot and preSettleBySlot[slot] or nil
                                            if from and b and b.labelArea and b.labelArea.IsShown and b.labelArea:IsShown() then
                                                local nx, ny = b.labelArea:GetCenter()
                                                if nx and ny then
                                                    local dx = from.x - nx
                                                    local dy = from.y - ny
                                                    if math.abs(dx) + math.abs(dy) >= 0.5 then
                                                        if not b.labelArea._paLabelSettleAG then
                                                            local sag = b.labelArea:CreateAnimationGroup()
                                                            local sprep = sag:CreateAnimation("Translation")
                                                            sprep:SetOrder(1)
                                                            sprep:SetDuration(0)
                                                            local sslide = sag:CreateAnimation("Translation")
                                                            sslide:SetOrder(2)
                                                            sslide:SetDuration(settleDuration)
                                                            if sslide.SetSmoothing then
                                                                sslide:SetSmoothing("IN_OUT")
                                                            end
                                                            b.labelArea._paLabelSettleAG = sag
                                                            b.labelArea._paLabelSettlePrep = sprep
                                                            b.labelArea._paLabelSettleAnim = sslide
                                                        end
                                                        if b.labelArea._paLabelSettleAG and b.labelArea._paLabelSettlePrep and b.labelArea._paLabelSettleAnim then
                                                            if b.labelArea._paLabelSettleAG.IsPlaying and b.labelArea._paLabelSettleAG:IsPlaying() then
                                                                b.labelArea._paLabelSettleAG:Stop()
                                                            end
                                                            b.labelArea._paLabelSettlePrep:SetOffset(dx, dy)
                                                            b.labelArea._paLabelSettleAnim:SetOffset(-dx, -dy)
                                                            b.labelArea._paLabelSettleAnim:SetDuration(settleDuration)
                                                            if b.labelArea._paLabelSettleAnim.SetSmoothing then
                                                                b.labelArea._paLabelSettleAnim:SetSmoothing("IN_OUT")
                                                            end
                                                            b.labelArea._paLabelSettleAG:Play()
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                        PortalAuthority._paDockLabelSettlePending = nil
                                        PortalAuthority._paDockLabelSettleRunning = nil
                                        PA_PerfEnd("dock_label_settle_rebuild", settleStart, settleState)
                                    end
                                end
                            end
                        end)
                    end

                    if btn.labelArea._paLabelMoveAG and btn.labelArea._paLabelMovePrep and btn.labelArea._paLabelMoveAnim then
                        btn.labelArea._paLabelMovePrep:SetOffset(ldx, ldy)
                        btn.labelArea._paLabelMoveAnim:SetOffset(-ldx, -ldy)
                        btn.labelArea._paLabelMoveAnim:SetDuration(labelMoveDuration)
                        if btn.labelArea._paLabelMoveAnim.SetSmoothing then
                            btn.labelArea._paLabelMoveAnim:SetSmoothing("OUT")
                        end
                        if not btn.labelArea._paLabelMoveActive then
                            btn.labelArea._paLabelMoveActive = true
                            if PortalAuthority then
                                PortalAuthority._paDockLabelAnimActiveCount = (tonumber(PortalAuthority._paDockLabelAnimActiveCount) or 0) + 1
                                PortalAuthority._paDockLabelSettlePending = true
                            end
                        end
                        btn.labelArea._paLabelMoveAG:Play()
                    end
                end
            end

            if showNames then
                btn._lastLabelCx = newLabelCx
                btn._lastLabelCy = newLabelCy
            end

            if allowIconMove then
                btn._animFromScreenCx = nil
                btn._animFromScreenCy = nil
            end
            if allowLabelMove then
                btn._animFromLabelCx = nil
                btn._animFromLabelCy = nil
            end
        end
    end

    if self.dockSpacingCross and self.dockSpacingCross._refreshVisual then
        self.dockSpacingCross._refreshVisual()
    end

    if self.dockFrame.SetBackdrop then
        if db.dockBackdropEnabled then
            self.dockFrame:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 10,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            self.dockFrame:SetBackdropColor(0, 0, 0, 0.35)
            self.dockFrame:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.8)
        else
            self.dockFrame:SetBackdrop(nil)
        end
    end
end

function PortalAuthority:Dock_RefreshCooldownOrdering()
    local perfStart, perfState = PA_PerfBegin("dock_refresh_cooldown_ordering")
    local function finish()
        PA_PerfEnd("dock_refresh_cooldown_ordering", perfStart, perfState)
    end

    local db = PortalAuthorityDB or self.defaults
    if getEffectiveDockSortMode(db, self.defaults or {}) ~= "COOLDOWN" then
        return finish()
    end
    if InCombatLockdown() then
        self:QueueDockUpdate()
        return finish()
    end
    local entries = self:Dock_BuildEnabledEntries(db.dockTestMode and true or false)
    self:Dock_SortEntries(entries)
    local signature = self:Dock_GetEntriesSignature(entries)
    if signature ~= self._dockOrderSignature then
        self:Dock_AssignButtons(entries)
        self:Dock_UpdateLayout(entries, false)
        self:UpdateDockButtonBindings()
        self._dockOrderSignature = signature
    end
    self:UpdateDockButtonStates()
    return finish()
end

function PortalAuthority:RebuildDock(animateTransition)
    if not self.dockFrame then
        return
    end

    local perfStart, perfState = PA_PerfBegin("dock_rebuild")
    local function finish()
        PA_PerfEnd("dock_rebuild", perfStart, perfState)
    end

    if InCombatLockdown() then
        self:QueueDockUpdate()
        return finish()
    end

    local db = PortalAuthorityDB or self.defaults
    db.dockIconsPerLine = math.floor(clamp(db.dockIconsPerLine, 1, 10, 4))
    db.dockIconSpacing = math.floor(clamp(db.dockIconSpacing, 0, 40, 6))
    db.dockDensity = math.floor(clamp(db.dockDensity, 0, 100, (self.defaults and self.defaults.dockDensity) or 50))
    db.dockSpacingX = math.floor(clamp(db.dockSpacingX, DOCK_SPACING_CROSS.MIN_SPACING_X, DOCK_SPACING_CROSS.MAX_SPACING_X, db.dockIconSpacing))
    db.dockSpacingY = math.floor(clamp(db.dockSpacingY, DOCK_SPACING_CROSS.MIN_SPACING_Y, DOCK_SPACING_CROSS.MAX_SPACING_Y, db.dockIconSpacing))
    db.dockWrapAfter = db.dockIconsPerLine

    local entries = self:Dock_BuildEnabledEntries(db.dockTestMode and true or false)
    self:Dock_SortEntries(entries)

    self.dockEntriesCount = #entries
    self._dockOrderSignature = self:Dock_GetEntriesSignature(entries)
    self._dockLastEntries = entries

    if #entries == 0 and not db.dockTestMode then
        if self.dockButtonPool then
            self.dockButtonPool:ReleaseAll()
        end
        self.dockActiveButtons = {}
        self.dockButtons = self.dockActiveButtons
        self:RefreshDockVisibility(true)
        return finish()
    end

    local transitionMode = self._dockTransitionMode
    if animateTransition and (transitionMode == "LAYOUT" or transitionMode == "LABEL") then
        local animFromBySlot = {}
        for i = 1, #self.dockActiveButtons do
            local btn = self.dockActiveButtons[i]
            local slot = btn and btn.slotIndex
            if slot then
                local from = animFromBySlot[slot] or {}
                if transitionMode == "LAYOUT" then
                    local cx, cy = btn:GetCenter()
                    if cx and cy then
                        from.cx = cx
                        from.cy = cy
                    end
                elseif transitionMode == "LABEL" then
                    from.lcX = btn._lastLabelCx
                    from.lcY = btn._lastLabelCy
                end
                animFromBySlot[slot] = from
            end
        end
        self._dockAnimFromBySlot = animFromBySlot
    else
        self._dockAnimFromBySlot = nil
    end

    self:InvalidateDockLabelCaches()

    self:Dock_AssignButtons(entries)
    if animateTransition and self._dockAnimFromBySlot and (transitionMode == "LAYOUT" or transitionMode == "LABEL") then
        for i = 1, #self.dockActiveButtons do
            local btn = self.dockActiveButtons[i]
            if btn then
                local slot = btn.slotIndex
                local from = slot and self._dockAnimFromBySlot[slot]
                if from then
                    if transitionMode == "LAYOUT" then
                        btn._animFromScreenCx = from.cx
                        btn._animFromScreenCy = from.cy
                    elseif transitionMode == "LABEL" then
                        btn._animFromLabelCx = from.lcX
                        btn._animFromLabelCy = from.lcY
                    end
                end
            end
        end
    end
    self._dockAnimFromBySlot = nil
    self:Dock_UpdateLayout(entries, false)
    self:UpdateDockButtonBindings()
    self:UpdateDockButtonStates()
    -- Finalize label/icon geometry after state styling so side/alignment updates
    -- are deterministic on first click.
    self:Dock_UpdateLayout(entries, animateTransition and true or false)
    self:ApplyDockPosition()
    self:RefreshDockVisibility(true)
    return finish()
end

function PortalAuthority:FinalizeDockLayout()
    if not self.dockFrame then
        return
    end
    if InCombatLockdown() then
        return
    end
    local entries = self._dockLastEntries
    if type(entries) ~= "table" then
        return
    end
    self:Dock_UpdateLayout(entries, false)
    self:UpdateDockButtonStates()
    self:Dock_UpdateLayout(entries, false)
end

function PortalAuthority:UpdateDockMovableState()
    if not self.dockFrame then
        return
    end

    local db = PortalAuthorityDB or self.defaults
    local locked = db.dockLocked
    if locked == nil then
        locked = true
    end
    local dockEnabled = (db.dockEnabled ~= false)
    if self.lockTipText then
        if locked then
            self.lockTipText:SetTextColor(0.72, 0.72, 0.72)
        else
            self.lockTipText:SetTextColor(1, 0.35, 0.2)
        end
    end
    self.dockFrame:SetMovable(not locked)
    self.dockFrame:EnableMouse(false)
    if self.dockDragHandle then
        if locked or not dockEnabled then
            self.dockDragHandle:EnableMouse(false)
            self.dockDragHandle:Hide()
        else
            self.dockDragHandle:Show()
            self.dockDragHandle:EnableMouse(true)
        end
    end
    self:SetDockSpacingCrossEnabled((not locked) and dockEnabled)
    self:UpdateDockButtonBindings()
    if locked then
        self:StopDockDrag()
    end

    self:RefreshDockVisibility(true)
    if self.UpdateDockOnUpdateState then
        self:UpdateDockOnUpdateState()
    end
    if self.UpdateMoveHintTickerState then
        self:UpdateMoveHintTickerState()
    end
end

function PortalAuthority:UpdateDockLockWarning()
    if not self.dockWarningFrame then
        return
    end

    -- Legacy warning frame is no longer persistent; unlock guidance is shown as a single timed popup.
    self.dockWarningFrame:Hide()
end

function PortalAuthority:InitializeDock()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if self.dockFrame then
        self:RebuildDock()
        return
    end

    self.dockButtons = {}
    self.dockActiveButtons = self.dockButtons
    self.dockEntriesCount = 0
    do
        local db = PortalAuthorityDB or self.defaults or {}
        self._dockEffectiveLayoutMode = resolveDockSimpleLayoutModeFromDB(db, self.defaults or {})
    end

    local dock = CreateFrame("Frame", "PortalAuthorityMPlusDock", UIParent, "BackdropTemplate")
    dock:SetClampedToScreen(false)
    dock:SetFrameStrata("MEDIUM")
    dock:SetMovable(true)
    dock:EnableMouse(true)

    dock:SetScript("OnHide", function()
        local perfStart, perfState = PA_PerfBegin("dock_frame_onhide")
        local function finish(...)
            PA_PerfEnd("dock_frame_onhide", perfStart, perfState)
            return ...
        end
        PortalAuthority._dockDiagFrameHideCount = (tonumber(PortalAuthority._dockDiagFrameHideCount) or 0) + 1
        PortalAuthority:StopDockDrag()
        PortalAuthority:EndDrag()
        PortalAuthority:UpdateDockOnUpdateState()
        return finish()
    end)

    dock:SetScript("OnShow", function()
        local perfStart, perfState = PA_PerfBegin("dock_frame_onshow")
        local function finish(...)
            PA_PerfEnd("dock_frame_onshow", perfStart, perfState)
            return ...
        end
        PortalAuthority._dockDiagFrameShowCount = (tonumber(PortalAuthority._dockDiagFrameShowCount) or 0) + 1
        PortalAuthority:UpdateDockButtonStates()
        local db = PortalAuthorityDB or PortalAuthority.defaults
        PortalAuthority:SetDockSpacingCrossEnabled(not db.dockLocked)
        PortalAuthority:UpdateDockOnUpdateState()
        return finish()
    end)

    self.dockFrame = dock
    self.dockVisibilityDriverActive = false
    self:UpdateDockOnUpdateState()

    local iconContainer = CreateFrame("Frame", nil, dock)
    iconContainer:SetPoint("TOPLEFT", dock, "TOPLEFT", 0, 0)
    iconContainer:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, 0)
    self.dockIconContainer = iconContainer

    self.dockButtonPool = CreateFramePool("Button", iconContainer, "SecureActionButtonTemplate", function(_, btn)
        if btn._moveAG and btn._moveAG.IsPlaying and btn._moveAG:IsPlaying() then
            btn._moveAG:Stop()
        end
        invalidateDockButtonLabelCache(btn)
        btn:Hide()
        btn:ClearAllPoints()
        btn.spellID = nil
        btn.slotIndex = nil
        btn.entry = nil
        if btn.icon then
            btn.icon:SetTexture(nil)
            btn.icon:SetDesaturated(false)
            btn.icon:SetAlpha(1)
        end
        if btn.label then
            btn.label:SetText("")
            btn.label:Hide()
        end
        if btn.labelArea then
            btn.labelArea:Hide()
        end
        if btn.cooldown then
            btn.cooldown:SetCooldown(0, 0)
        end
        if btn.hover then
            btn.hover:Hide()
        end
        btn:SetScript("OnUpdate", nil)
    end)

    local warningFrame = CreateFrame("Frame", nil, dock)
    warningFrame:SetPoint("BOTTOM", dock, "TOP", 0, 22)
    warningFrame:SetSize(320, 28)
    warningFrame:SetFrameStrata("HIGH")
    warningFrame:SetFrameLevel(dock:GetFrameLevel() + 8)
    warningFrame:Hide()
    self.dockWarningFrame = warningFrame

    local lockWarning = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lockWarning:SetPoint("TOP", warningFrame, "TOP", 0, 0)
    lockWarning:SetJustifyH("CENTER")
    lockWarning:SetText("Unlocked — lock it in /pa")
    lockWarning:SetTextColor(1, 0.2, 0.2)
    self.dockLockWarningText = lockWarning

    local precisionWarning = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    precisionWarning:SetPoint("TOP", lockWarning, "BOTTOM", 0, -2)
    precisionWarning:SetJustifyH("CENTER")
    precisionWarning:SetText("For precision, use X/Y in /pa")
    precisionWarning:SetTextColor(1, 0.82, 0.2)
    self.dockPrecisionWarningText = precisionWarning

    local dragHandle = CreateFrame("Button", nil, dock, "BackdropTemplate")
    dragHandle:ClearAllPoints()
    dragHandle:SetPoint("BOTTOMLEFT", dock, "TOPLEFT", -39, 3)
    dragHandle:SetPoint("BOTTOMRIGHT", dock, "TOPRIGHT", 39, 3)
    dragHandle:SetHeight(16)
    dragHandle:SetFrameStrata(dock:GetFrameStrata())
    dragHandle:SetFrameLevel(dock:GetFrameLevel() + 2)
    dragHandle:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    dragHandle:SetBackdropColor(0.0, 1.0, 0.0, 0.85)
    dragHandle:SetBackdropBorderColor(0.0, 0.25, 0.0, 1.0)
    dragHandle:EnableMouse(false)
    dragHandle:Hide()
    local dragGlyph = dragHandle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dragGlyph:SetPoint("CENTER", dragHandle, "CENTER", 0, 0)
    dragGlyph:SetText("GRAB")
    dragGlyph:SetTextColor(0, 0, 0, 1)
    self.dockDragHandleText = dragGlyph
    dragHandle:SetScript("OnMouseDown", function(_, button)
        local db = PortalAuthorityDB or PortalAuthority.defaults
        if shouldBeginDockDrag(button) and not InCombatLockdown() and not db.dockLocked then
            PortalAuthority:TryStartDockDrag()
        end
    end)
    dragHandle:SetScript("OnMouseUp", function(_, button)
        if shouldBeginDockDrag(button) and PortalAuthority.dockDragRequested then
            PortalAuthority:StopDockDrag()
        end
    end)
    self.dockDragHandle = dragHandle

    local dockEvents = CreateFrame("Frame")
    dockEvents:RegisterEvent("PLAYER_UPDATE_RESTING")
    dockEvents:RegisterEvent("ZONE_CHANGED")
    dockEvents:RegisterEvent("ZONE_CHANGED_INDOORS")
    dockEvents:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    dockEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
    dockEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
    dockEvents:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    dockEvents:RegisterEvent("SPELLS_CHANGED")
    dockEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    dockEvents:RegisterEvent("ADDON_LOADED")

    dockEvents:SetScript("OnEvent", function(_, event, arg1)
        PA_CpuDiagRecordDispatcherEvent("dock", event)
        local triggerKey = PA_CpuDiagDockTriggerKey(event)
        if triggerKey then
            PA_CpuDiagRecordTrigger(triggerKey)
        end
        local dispatchStart, dispatchState = PA_PerfBegin("dock_event_dispatch")
        local eventScope = PA_PerfDockEventScope(event)
        local eventStart, eventState = PA_PerfBegin(eventScope, dispatchState)
        local function finish(...)
            PA_PerfEnd(eventScope, eventStart, eventState)
            PA_PerfEnd("dock_event_dispatch", dispatchStart, dispatchState)
            return ...
        end

        if event == "PLAYER_REGEN_DISABLED" then
            PortalAuthority:EndDrag()
            PortalAuthority:SetDockSpacingCrossEnabled(false)
            PortalAuthority:QueueDockVisibilityRefresh()
            return finish()
        end

        if event == "PLAYER_REGEN_ENABLED" then
            if PortalAuthority.pendingDockUpdate then
                PortalAuthority.pendingDockUpdate = false
                PortalAuthority:RebuildDock()
            end
            if PortalAuthority.pendingDockVisibilityRefresh then
                PortalAuthority.pendingDockVisibilityRefresh = false
            end
            PortalAuthority:RestoreDock()
            PortalAuthority:UpdateDockMovableState()
            return finish()
        end


        if event == "ADDON_LOADED" and (arg1 == "Blizzard_PVEFrame" or arg1 == "Blizzard_PVE") then
            PortalAuthority:HookDockGizmoModeWindow()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            PortalAuthority:HookDockGizmoModeWindow()
            PortalAuthority:InvalidateDockLabelCaches()
            if InCombatLockdown() then
                PortalAuthority:QueueDockUpdate()
            else
                PortalAuthority:RebuildDock()
            end
        end

        if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELLS_CHANGED" then
            if not InCombatLockdown() then
                PortalAuthority:UpdateDockButtonStates()
                local db = PortalAuthorityDB or PortalAuthority.defaults
                if getEffectiveDockSortMode(db, PortalAuthority.defaults or {}) == "COOLDOWN" then
                    PortalAuthority:Dock_RefreshCooldownOrdering()
                end
            else
                PortalAuthority:QueueDockUpdate()
            end
        end

        PortalAuthority:UpdateDockVisibility()
        return finish()
    end)

    self.dockEvents = dockEvents
    self:HookDockGizmoModeWindow()
    self:ApplyDockPosition()
    self:UpdateDockMovableState()
    self:RebuildDock()
    self:RestoreDock()
end


