---@diagnostic disable: undefined-field
--[[
    TwichUI Setup Wizard — Core Module

    Manages the wizard version, first-login trigger, DB persistence, layout frame
    registry, and layout/theme application APIs.

    HOW TO RE-TRIGGER THE WIZARD FOR NEW FEATURES:
      Increment WIZARD_VERSION below. All users whose completedVersion is less than
      the new value will see the wizard again on next login.
]]
local TwichRx               = _G.TwichRx
---@type TwichUI
local T                     = unpack(TwichRx)

local C_Timer               = _G.C_Timer
local InCombatLockdown      = _G.InCombatLockdown
local C_AddOns              = _G.C_AddOns
local GetScreenWidth        = _G.GetScreenWidth
local GetScreenHeight       = _G.GetScreenHeight
local GetPhysicalScreenSize = _G.GetPhysicalScreenSize
local GetRealmName          = _G.GetRealmName
local ReloadUI              = _G.ReloadUI
local CopyTable             = _G.CopyTable
local SetCVar               = _G.SetCVar
local UnitFullName          = _G.UnitFullName
local math_abs              = _G.math.abs
local math_min              = _G.math.min
local wipe                  = _G.wipe

--- Increment to re-show the wizard for all users (e.g. when a new setup step is added).
local WIZARD_VERSION        = 3

---@class SetupWizardModule : AceModule, AceEvent-3.0
local SetupWizardModule     = T:NewModule("SetupWizard", "AceEvent-3.0")
SetupWizardModule:SetEnabledState(true)

-- UI namespace populated by WizardUI.lua
SetupWizardModule.UI = nil

-- ─── DB ────────────────────────────────────────────────────────────────────

-- Wizard state is stored directly in the raw SavedVariable (TwichDB.wizardState),
-- bypassing AceDB entirely.  This key is outside AceDB's managed section registry
-- so it is never touched by profile resets, section cleanup, ResetProfile, or
-- RestoreConfigSnapshot. WoW writes TwichDB at PLAYER_LOGOUT regardless of AceDB.
function SetupWizardModule:GetDB()
    -- rawget(T.db, "sv") gets the underlying TwichDB table without going through
    -- the AceDB metatable, avoiding any possible lazy-init edge cases.
    local sv = T.db and rawget(T.db, "sv")
    if not sv then return {} end
    if type(sv.wizardState) ~= "table" then
        sv.wizardState = {}
    end
    return sv.wizardState
end

function SetupWizardModule:GetCharacterKey()
    local name, realm = type(UnitFullName) == "function" and UnitFullName("player") or nil, nil
    if type(name) == "table" then
        name, realm = name[1], name[2]
    else
        realm = type(UnitFullName) == "function" and select(2, UnitFullName("player")) or nil
    end

    if type(name) ~= "string" or name == "" then
        return "account"
    end

    if type(realm) ~= "string" or realm == "" then
        realm = type(GetRealmName) == "function" and GetRealmName() or "Realm"
    end

    realm = tostring(realm):gsub("%s+", "")
    return string.format("%s-%s", tostring(name), realm ~= "" and realm or "Realm")
end

function SetupWizardModule:GetRequiredWizardVersion()
    local db = self:GetDB()
    local forcedVersion = tonumber(db.forcedVersion) or 0
    return math.max(WIZARD_VERSION, forcedVersion)
end

function SetupWizardModule:GetCharacterState(createIfMissing)
    local db = self:GetDB()
    if type(db.characters) ~= "table" then
        db.characters = {}
    end

    local characterKey = self:GetCharacterKey()
    if createIfMissing ~= false and type(db.characters[characterKey]) ~= "table" then
        db.characters[characterKey] = {}
    end

    return db.characters[characterKey], characterKey
end

function SetupWizardModule:GetPendingWizardState()
    local characterState = self:GetCharacterState(false)
    return characterState and characterState.pendingState or nil
end

function SetupWizardModule:SetPendingWizardState(state)
    local characterState = self:GetCharacterState(true)
    if type(state) == "table" then
        characterState.pendingState = type(CopyTable) == "function" and CopyTable(state) or state
    else
        characterState.pendingState = nil
    end
end

function SetupWizardModule:ClearPendingWizardState()
    local characterState = self:GetCharacterState(false)
    if characterState then
        characterState.pendingState = nil
    end
end

-- ─── Version / trigger ─────────────────────────────────────────────────────

--- Returns true if the wizard should be shown (never completed, or a new version is available).
function SetupWizardModule:ShouldShow()
    -- In-session guard: if we already completed the wizard this session, never re-show
    -- regardless of DB state (guards against any edge-case DB timing issues).
    if self._completedThisSession then return false end
    local characterState = self:GetCharacterState(true)
    return (characterState.completedVersion or 0) < self:GetRequiredWizardVersion()
end

--- Marks the wizard as completed for the current WIZARD_VERSION.
function SetupWizardModule:MarkComplete()
    self._completedThisSession = true
    local characterState = self:GetCharacterState(true)
    characterState.completedVersion = self:GetRequiredWizardVersion()
    characterState.completedAt = _G.time and _G.time() or nil
    self:ClearPendingWizardState()
end

--- Resets completion so the wizard will appear again on next login.
--- Useful for testing or for the config panel's "Re-run Wizard" button.
function SetupWizardModule:Reset()
    self._completedThisSession = false
    local db = self:GetDB()
    db.completedVersion = 0
    db.characters = {}
end

--- Wipes the entire TwichUI saved-variable table and reloads the UI.
--- Intended for first-run recovery when the user wants a clean slate.
function SetupWizardModule:ResetAddonDatabase()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        T:Print("Cannot reset TwichUI database while in combat.")
        return false
    end

    local sv = T.db and rawget(T.db, "sv")
    if type(sv) == "table" and type(wipe) == "function" then
        wipe(sv)
    end

    self._completedThisSession = false
    self.layoutFrames = {}

    if type(ReloadUI) == "function" then
        ReloadUI()
    end

    return true
end

-- ─── Layout frame registry ─────────────────────────────────────────────────

-- layoutFrames stores { frame = <Frame>, persist = <fn|nil> } per key.
SetupWizardModule.layoutFrames = {}

--- Register a named frame for layout capture and apply.
---
--- @param key       string       Unique identifier (e.g. "ChatFrame1")
--- @param frame     table        WoW Frame object
--- @param persistFn function|nil Called after the frame is repositioned with (absX, absY, absW, absH).
---                              Use this to write the new position into your module's own DB so it
---                              survives a reload. absX/Y are BOTTOMLEFT-relative screen pixels.
function SetupWizardModule:RegisterLayoutFrame(key, frame, persistFn)
    self.layoutFrames[key] = { frame = frame, persist = persistFn }
end

local function CloneValue(value)
    if type(value) ~= "table" then
        return value
    end
    if type(CopyTable) == "function" then
        return CopyTable(value)
    end

    local copy = {}
    for key, innerValue in pairs(value) do
        copy[key] = CloneValue(innerValue)
    end
    return copy
end

local function ScaleNumericValue(value, scale)
    local numeric = tonumber(value)
    if not numeric or not scale or math_abs(scale - 1) < 0.0001 then
        return value
    end
    return numeric * scale
end

local function ScalePixelConfig(config, xKeys, yKeys, uniformKeys, scales)
    if type(config) ~= "table" then
        return
    end

    for _, key in ipairs(xKeys or {}) do
        if config[key] ~= nil then
            config[key] = ScaleNumericValue(config[key], scales.width)
        end
    end

    for _, key in ipairs(yKeys or {}) do
        if config[key] ~= nil then
            config[key] = ScaleNumericValue(config[key], scales.height)
        end
    end

    for _, key in ipairs(uniformKeys or {}) do
        if config[key] ~= nil then
            config[key] = ScaleNumericValue(config[key], scales.uniform)
        end
    end
end

function SetupWizardModule:GetActiveLayoutScales()
    local layoutData = self._activeLayoutData
    local referenceResolution = layoutData and layoutData.referenceResolution
    local refW = type(referenceResolution) == "table" and tonumber(referenceResolution.w) or nil
    local refH = type(referenceResolution) == "table" and tonumber(referenceResolution.h) or nil
    if not refW or not refH or refW <= 0 or refH <= 0 then
        return nil
    end

    local sw, sh = GetScreenWidth(), GetScreenHeight()
    return {
        width = sw / refW,
        height = sh / refH,
        uniform = math_min(sw / refW, sh / refH),
    }
end

function SetupWizardModule:PrepareConfigSnapshotSection(sectionKey, sectionVal)
    if type(sectionVal) ~= "table" then
        return sectionVal
    end

    local prepared = CloneValue(sectionVal)
    -- Always strip wizard-only debug flags so they never leak into live gameplay.
    if sectionKey == "unitFrames" then
        prepared.testMode         = nil
        prepared.testPreviewParty = nil
        prepared.testPreviewRaid  = nil
        prepared.lockFrames       = nil
    end
    if sectionKey ~= "unitFrames" then
        return prepared
    end

    local scales = self:GetActiveLayoutScales()
    if not scales then
        return prepared
    end

    local layout = prepared.layout
    if type(layout) == "table" then
        for _, layoutEntry in pairs(layout) do
            ScalePixelConfig(layoutEntry, { "x" }, { "y" }, nil, scales)
        end
    end

    local units = prepared.units
    if type(units) == "table" then
        for _, unitConfig in pairs(units) do
            if type(unitConfig) == "table" then
                -- powerWidth is excluded from the xPixels list here and handled
                -- below with height-biased scaling, matching ApplyLayoutData's
                -- approach for single UF frame widths.
                ScalePixelConfig(unitConfig,
                    {},
                    { "powerHeight", "powerOffsetY" },
                    { "width", "height" },
                    scales)
                -- powerWidth: use max(scaleX, scaleY) so the detached power bar
                -- widens proportionally with the frame height rather than compressing
                -- to scaleX on narrower / lower-res monitors.
                if type(unitConfig.powerWidth) == "number" then
                    local hb = math.max(scales.width, scales.height)
                    unitConfig.powerWidth = math.floor(unitConfig.powerWidth * hb + 0.5)
                end
                ScalePixelConfig(unitConfig,
                    { "powerOffsetX" },
                    nil,
                    nil,
                    scales)
                ScalePixelConfig(unitConfig.classBar, { "xOffset" }, { "yOffset" }, { "width", "height", "spacing" },
                    scales)
                ScalePixelConfig(unitConfig.combatIndicator, { "offsetX" }, { "offsetY" }, { "size" }, scales)
                ScalePixelConfig(unitConfig.restingIndicator, { "offsetX" }, { "offsetY" }, { "size" }, scales)
                ScalePixelConfig(unitConfig.spiritIndicator, { "offsetX" }, { "offsetY" }, { "size" }, scales)
            end
        end
    end

    local groups = prepared.groups
    if type(groups) == "table" then
        for _, groupConfig in pairs(groups) do
            if type(groupConfig) == "table" then
                -- Group member width/height/spacing: use height scale (scaleY) instead
                -- of uniform=min(scaleX,scaleY) so frames stay readable at small or
                -- non-ultrawide resolutions. The xOffset position still uses scaleX.
                local groupScales = {
                    width   = scales.width,
                    height  = scales.height,
                    uniform = scales.height,
                }
                ScalePixelConfig(groupConfig,
                    { "xOffset" },
                    { "yOffset" },
                    { "width", "height", "rowSpacing", "columnSpacing" },
                    groupScales)
                ScalePixelConfig(groupConfig.roleIcon, { "insetX" }, { "insetY" }, { "size" }, scales)
                ScalePixelConfig(groupConfig.combatIndicator, { "offsetX" }, { "offsetY" }, { "size" }, scales)
                ScalePixelConfig(groupConfig.restingIndicator, { "offsetX" }, { "offsetY" }, { "size" }, scales)
                ScalePixelConfig(groupConfig.spiritIndicator, { "offsetX" }, { "offsetY" }, { "size" }, scales)
            end
        end
    end

    ScalePixelConfig(prepared.castbar, nil, nil, { "width", "height", "iconSize" }, scales)

    local castbars = prepared.castbars
    if type(castbars) == "table" then
        for _, castbarConfig in pairs(castbars) do
            ScalePixelConfig(castbarConfig, { "xOffset" }, { "yOffset" }, { "width", "height", "iconSize" },
                scales)
        end
    end

    return prepared
end

--- Restores all configuration sections from a previously captured DB snapshot.
--- Each top-level key in `snapshot` replaces the corresponding sub-section in
--- the profile configuration DB. "setupWizard" is always skipped so wizard
--- completion state is never overwritten.
--- Fires TWICH_CONFIG_RESTORED after writing so modules can self-refresh.
---@param snapshot table  A table of { sectionKey = sectionTable } pairs.
function SetupWizardModule:RestoreConfigSnapshot(snapshot)
    if type(snapshot) ~= "table" then return end
    local CM = T:GetModule("Configuration")
    if not CM then return end
    local config = CM:GetProfileDB()
    local applyOptions = self._layoutApplyOptions
    for sectionKey, sectionVal in pairs(snapshot) do
        if sectionKey ~= "setupWizard" and not (sectionKey == "chatEnhancement" and applyOptions and applyOptions.applyChat == false) then
            config[sectionKey] = self:PrepareConfigSnapshotSection(sectionKey, sectionVal)
        end
    end
    T:SendMessage("TWICH_CONFIG_RESTORED")
end

local function Clamp(value, minV, maxV)
    if value < minV then return minV end
    if value > maxV then return maxV end
    return value
end

--- Returns an auto-calculated UI scale similar to Blizzard/Elv-style auto-scaling.
---@return number
function SetupWizardModule:GetAutoUIScale()
    local physicalH = nil
    if type(GetPhysicalScreenSize) == "function" then
        local _, h = GetPhysicalScreenSize()
        physicalH = h
    end
    local h = tonumber(physicalH) or tonumber(GetScreenHeight and GetScreenHeight()) or 1080
    return Clamp(768 / math.max(1, h), 0.64, 1)
end

--- Applies UI scale mode/value from wizard and stores the selection in wizard state.
---@param mode string|nil  "skip"|"auto"|"manual"
---@param value number|nil Manual scale value when mode="manual"
function SetupWizardModule:ApplyUIScale(mode, value)
    local db = self:GetDB()
    mode = mode or "auto"

    if mode == "skip" then
        db.appliedUIScaleMode = "skip"
        db.appliedUIScaleValue = nil
        return
    end

    if type(SetCVar) ~= "function" then
        return
    end

    if mode == "auto" then
        pcall(SetCVar, "useUiScale", "0")
        db.appliedUIScaleMode = "auto"
        db.appliedUIScaleValue = self:GetAutoUIScale()
        return
    end

    local scaleValue = Clamp(tonumber(value) or self:GetAutoUIScale(), 0.64, 1)
    pcall(SetCVar, "useUiScale", "1")
    pcall(SetCVar, "uiScale", string.format("%.2f", scaleValue))
    db.appliedUIScaleMode = "manual"
    db.appliedUIScaleValue = scaleValue
end

--- Returns the current screen dimensions.
---@return number screenWidth, number screenHeight
function SetupWizardModule:GetScreenDimensions()
    return GetScreenWidth(), GetScreenHeight()
end

--- Applies normalized frame positions from a layout definition.
--- Coordinates are stored as fractions of screen size and always applied
--- with a BOTTOMLEFT anchor so they are consistent with how modules like
--- ChatStyling persist positions. Calls each frame's persist callback so
--- the module's own DB is updated and the position survives a reload.
---@param layoutData table  Layout definition table with a `frames` sub-table
function SetupWizardModule:ApplyLayoutData(layoutData)
    if type(layoutData) ~= "table" or type(layoutData.frames) ~= "table" then return end
    local sw, sh = GetScreenWidth(), GetScreenHeight()
    local referenceResolution = layoutData.referenceResolution
    local refW = type(referenceResolution) == "table" and tonumber(referenceResolution.w) or sw
    local refH = type(referenceResolution) == "table" and tonumber(referenceResolution.h) or sh
    local hasRefResolution = refW and refW > 0 and refH and refH > 0
    for key, fd in pairs(layoutData.frames) do
        local entry = self.layoutFrames[key]
        local frame = entry and entry.frame
        local unitFrameKey = type(key) == "string" and key:match("^UF_(.+)$") or nil
        local skipZeroCapture = unitFrameKey == "party" or unitFrameKey == "raid" or unitFrameKey == "tank"
        local skipBossChildCapture = type(unitFrameKey) == "string" and unitFrameKey:match("^boss%d+$") ~= nil
        local hasCapturedPosition = (tonumber(fd.x) or 0) ~= 0 or (tonumber(fd.y) or 0) ~= 0 or
            (tonumber(fd.w) or 0) > 0 or (tonumber(fd.h) or 0) > 0
        if frame and frame.SetPoint and not skipBossChildCapture and not (skipZeroCapture and not hasCapturedPosition) then
            local absX = (fd.x or 0) * sw
            local absY = (fd.y or 0) * sh
            local absW = fd.w and fd.w * sw
            local absH = fd.h and fd.h * sh
            local scaleMode = fd.scaleMode

            -- Single UF frames (player, target, etc.) get height-biased width so they
            -- appear wider instead of squashing horizontally on narrower monitors.
            -- Group frames (party/raid/tank/boss) are excluded; their member sizes are
            -- set by the UF module and squashing them would break group indicators.
            local isSingleUF = unitFrameKey and unitFrameKey ~= "party"
                and unitFrameKey ~= "raid" and unitFrameKey ~= "tank"
                and not (type(unitFrameKey) == "string" and unitFrameKey:match("^boss"))
            if isSingleUF and hasRefResolution and fd.w and fd.h then
                local heightBiasW = fd.w * refW * (sh / refH)
                if absW and heightBiasW > absW then absW = heightBiasW end
            end

            -- Backward-compatible chat behavior for older captures:
            -- if no scale metadata exists, preserve snapshot size from layout.apply()
            -- and only reposition the chat frame.
            if key == "ChatFrame1" and scaleMode == nil and not hasRefResolution then
                absW = nil
                absH = nil
            end

            if hasRefResolution and fd.w and fd.h then
                if key == "ChatFrame1" and scaleMode == nil then
                    scaleMode = "height"
                end
                if key == "ChatFrame1" and scaleMode == "height" then
                    local widthScale = sw / refW
                    local heightScale = sh / refH
                    local s = math.min(widthScale, heightScale)
                    absW = fd.w * refW * s
                    absH = fd.h * refH * s
                elseif scaleMode == "height" then
                    local s = sh / refH
                    absW = fd.w * refW * s
                    absH = fd.h * refH * s
                elseif scaleMode == "width" then
                    local s = sw / refW
                    absW = fd.w * refW * s
                    absH = fd.h * refH * s
                elseif scaleMode == "uniform" then
                    local s = math.min(sw / refW, sh / refH)
                    absW = fd.w * refW * s
                    absH = fd.h * refH * s
                end
            end

            if absW and absW > sw * 0.98 then absW = sw * 0.98 end
            if absH and absH > sh * 0.98 then absH = sh * 0.98 end
            if absW and absX + absW > sw then
                absX = math.max(0, sw - absW - 2)
            end
            if absH and absY + absH > sh then
                absY = math.max(0, sh - absH - 2)
            end

            -- Layout captures for ChatFrame1 are recorded from the chat chrome shell
            -- bottom-left. Convert back to the underlying frame anchor before SetPoint.
            if key == "ChatFrame1" then
                local chrome = frame.TwichUIChrome
                local offsetX, offsetY = -8, -8
                if chrome and chrome.GetLeft and chrome.GetBottom and frame.GetLeft and frame.GetBottom then
                    local frameLeft = frame:GetLeft()
                    local frameBottom = frame:GetBottom()
                    local chromeLeft = chrome:GetLeft()
                    local chromeBottom = chrome:GetBottom()
                    if frameLeft and frameBottom and chromeLeft and chromeBottom then
                        offsetX = chromeLeft - frameLeft
                        offsetY = chromeBottom - frameBottom
                    end
                end
                absX = absX - offsetX
                absY = absY - offsetY
            end

            frame:ClearAllPoints()
            -- Always BOTTOMLEFT so persist callbacks receive consistent values.
            frame:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", absX, absY)
            if absW then frame:SetWidth(absW) end
            if absH then frame:SetHeight(absH) end
            if entry.persist then
                local persistW = absW or (frame.GetWidth and frame:GetWidth() or 0)
                local persistH = absH or (frame.GetHeight and frame:GetHeight() or 0)
                entry.persist(absX, absY, persistW, persistH)
            end
        end
    end
end

-- ─── Layout application ────────────────────────────────────────────────────

--- Applies the named layout: config snapshot first, then normalised frame positions.
--- The snapshot MUST run before ApplyLayoutData so that persist callbacks (which
--- write position data into module DB sections) write into the freshly-replaced
--- tables rather than tables that would immediately be overwritten by the snapshot.
---@param layoutId string
---@param options table|nil
function SetupWizardModule:ApplyLayout(layoutId, options)
    local layout = self:GetLayout(layoutId)
    if not layout then return end
    self._layoutApplyOptions = options
    self._activeLayoutData = layout
    -- 1. Apply the config snapshot: replaces chatEnhancement, datatext, etc.
    if type(layout.apply) == "function" then
        layout.apply()
    end
    self._layoutApplyOptions = nil
    -- 1.5. Scale action bar positions and button sizes from the capture resolution.
    --   Center-intent bars (capture center in [35%,65%] of refW) are ALWAYS snapped
    --   to sw/2 — even at the reference resolution — so minor off-center placement
    --   in a capture is automatically corrected.
    --   Scaling of buttonSize / spacing / y / non-centre x only happens when the
    --   current resolution differs from the capture reference.
    local _sw, _sh
    local _centerClusterLeft  = math.huge
    local _centerClusterRight = -math.huge
    local _refRes = layout.referenceResolution
    local _refW   = _refRes and tonumber(_refRes.w) or nil
    local _refH   = _refRes and tonumber(_refRes.h) or nil
    if _refW and _refW > 0 and _refH and _refH > 0 then
        _sw, _sh      = GetScreenWidth(), GetScreenHeight()
        local scaleX  = _sw / _refW
        local scaleY  = _sh / _refH
        local isScaled = math.abs(_sw - _refW) > 1 or math.abs(_sh - _refH) > 1
        local gentleX = scaleX + 0.4 * (scaleY - scaleX)

        local CM     = T:GetModule("Configuration", true)
        local config = CM and type(CM.GetProfileDB) == "function" and CM:GetProfileDB() or nil

        -- Scale global button spacing first so bar-width estimates below are correct.
        local scaledSpacing = 4
        if isScaled and config and type(config.actionBars) == "table" then
            local sp = config.actionBars.buttonSpacing
            if type(sp) == "number" then
                scaledSpacing = math.max(0, math.floor(sp * scaleY + 0.5))
                config.actionBars.buttonSpacing = scaledSpacing
            end
        end

        local HOLDER_PAD = 6  -- must match DEFAULT_HOLDER_PADDING in ActionBars.lua
        local abBars = config and type(config.actionBars) == "table" and
                       type(config.actionBars.bars) == "table" and config.actionBars.bars or nil
        if abBars then
            for _, bs in pairs(abBars) do
                if type(bs) == "table" and bs.enabled == true then
                    local origX      = type(bs.x)             == "number" and bs.x             or 0
                    local origBtnSz  = type(bs.buttonSize)    == "number" and bs.buttonSize    or 32
                    local origPerRow = type(bs.buttonsPerRow) == "number" and bs.buttonsPerRow or 12
                    local origCount  = type(bs.buttonCount)   == "number" and bs.buttonCount   or 12
                    -- bs.scale applies a visual multiplier to the holder frame (SetScale).
                    -- Use it when computing the true on-screen width for cluster bounds.
                    local origScale  = type(bs.scale)         == "number" and bs.scale         or 1.0
                    local perRow     = math.min(origPerRow, origCount)

                    -- Scale button size by height ratio when resolution differs.
                    -- Clamp to 22 minimum to match LayoutBar's ClampNumber(sz, 22, 64, …).
                    local scaledBtnSz = isScaled
                        and math.max(22, math.floor(origBtnSz * scaleY + 0.5))
                        or  math.max(22, origBtnSz)
                    if isScaled then bs.buttonSize = scaledBtnSz end

                    -- barW is the logical holder size; visual width = barW * origScale.
                    local barW    = perRow * scaledBtnSz
                        + math.max(0, perRow - 1) * scaledSpacing + HOLDER_PAD * 2
                    local refBarW = perRow * origBtnSz
                        + math.max(0, perRow - 1) * 4 + HOLDER_PAD * 2

                    -- Where was this bar's horizontal centre as a fraction of refW?
                    local origCtrFrc = (origX + refBarW / 2) / _refW

                    if origCtrFrc >= 0.35 and origCtrFrc <= 0.65 then
                        -- Centre-intent: switch the anchor to BOTTOM with x=0 so WoW's
                        -- own layout system guarantees perfect horizontal centering regardless
                        -- of button size, scale, or rounding.  y is unchanged (vertical offset
                        -- from UIParent bottom means the same for both BOTTOMLEFT and BOTTOM).
                        bs.point = "BOTTOM"
                        bs.relativePoint = "BOTTOM"
                        bs.x = 0
                        -- Track visual cluster bounds for step 2.5: bar spans ±barW*scale/2
                        -- around sw/2 when BOTTOM-anchored.
                        local halfVisual = barW * origScale / 2
                        _centerClusterLeft  = math.min(_centerClusterLeft,  _sw / 2 - halfVisual)
                        _centerClusterRight = math.max(_centerClusterRight, _sw / 2 + halfVisual)
                    elseif isScaled then
                        bs.x = math.floor(origX * gentleX + 0.5)
                    end

                    if isScaled and type(bs.y) == "number" then
                        bs.y = math.floor(bs.y * scaleY + 0.5)
                    end
                end
            end
        end
    end

    -- 2. Apply frame positions: persist callbacks now write into the new tables.
    self:ApplyLayoutData(layout)
    self:GetDB().appliedLayout = layoutId

    -- 2.5. Adapt UF frame positions around the centred action-bar cluster.
    --      ApplyLayoutData persist callbacks have written current-screen pixel
    --      positions into config.unitFrames.layout by this point, so nudging here
    --      will take effect on the RefreshAllFrames call below.
    local _hasCluster = _sw and _centerClusterLeft < _centerClusterRight
    if _hasCluster then
        local CM     = T:GetModule("Configuration", true)
        local config = CM and type(CM.GetProfileDB) == "function" and CM:GetProfileDB() or nil
        local ufDB   = config and type(config.unitFrames) == "table" and config.unitFrames or nil
        if ufDB then
            local ufLayout = type(ufDB.layout) == "table" and ufDB.layout or nil
            local ufUnits  = type(ufDB.units)  == "table" and ufDB.units  or nil
            local GAP      = 14  -- px gap between UF edge and nearest bar edge

            -- Player: push left so its right edge clears the cluster
            local pL = ufLayout and ufLayout["player"]
            if pL and type(pL.x) == "number" then
                local pw = ufUnits and ufUnits["player"] and tonumber(ufUnits["player"].width) or nil
                if pw and pw > 0 then
                    local maxRight = _centerClusterLeft - GAP
                    if pL.x + pw > maxRight then
                        pL.x = math.max(0, maxRight - pw)
                    end
                end
            end

            -- Target: push right so its left edge clears the cluster
            local tL = ufLayout and ufLayout["target"]
            if tL and type(tL.x) == "number" then
                local desiredX = _centerClusterRight + GAP
                if tL.x < desiredX then
                    tL.x = desiredX
                end
            end

            -- Target-of-Target: follow immediately right of target so it doesn't
            -- end up overlapping the target frame after it was pushed right.
            local totL = ufLayout and ufLayout["targettarget"]
            if totL and tL and type(tL.x) == "number" then
                local tw = ufUnits and ufUnits["target"] and tonumber(ufUnits["target"].width) or nil
                if tw and tw > 0 then
                    totL.x = tL.x + tw + 4  -- 4 px gap matching original layout spacing
                end
            end

            -- Castbar: re-centre above the bar cluster
            local cL = ufLayout and ufLayout["castbar"]
            if cL and type(cL.x) == "number" and ufDB.castbar then
                local cbW = tonumber(ufDB.castbar.width)
                if cbW and cbW > 0 then
                    cL.x = math.floor(_sw / 2 - cbW / 2 + 0.5)
                end
            end

            -- Detached player power bar: also centre on screen so it sits
            -- directly between the UF cluster and the action bar cluster.
            local ppL = ufLayout and ufLayout["player_power"]
            if ppL and type(ppL.x) == "number" then
                local ppW = ufUnits and ufUnits["player"] and tonumber(ufUnits["player"].powerWidth) or nil
                if ppW and ppW > 0 then
                    ppL.x = math.floor(_sw / 2 - ppW / 2 + 0.5)
                end
            end
        end
    end

    -- 3. Refresh all live modules so the wizard preview reflects the applied layout.
    local datatextModule = T:GetModule("Datatexts", true)
    if datatextModule and type(datatextModule.RefreshStandalonePanels) == "function" then
        pcall(datatextModule.RefreshStandalonePanels, datatextModule)
    end

    local unitFramesModule = T:GetModule("UnitFrames", true)
    if unitFramesModule and type(unitFramesModule.RefreshAllFrames) == "function" then
        pcall(unitFramesModule.RefreshAllFrames, unitFramesModule)
    end

    -- Action bars: RequestRefresh re-runs LayoutBar for every enabled bar so
    -- holders move to the newly-scaled x/y positions from step 1.5.
    local actionBarsModule = T:GetModule("ActionBars", true)
    if actionBarsModule and type(actionBarsModule.RequestRefresh) == "function" then
        pcall(actionBarsModule.RequestRefresh, actionBarsModule)
    end

    self._activeLayoutData = nil
end

function SetupWizardModule:SetLayoutPreviewUnitFramesEnabled(enabled)
    local unitFramesModule = T:GetModule("UnitFrames", true)
    if not unitFramesModule then
        self._layoutPreviewUnitFramesState = nil
        return
    end

    if enabled == true then
        if self._layoutPreviewUnitFramesState then
            if type(unitFramesModule.SetTestMode) == "function" then
                pcall(unitFramesModule.SetTestMode, unitFramesModule, true)
            end
            return
        end

        local wasEnabled = unitFramesModule.IsEnabled and unitFramesModule:IsEnabled() or false
        local unitFrameDB = type(unitFramesModule.GetDB) == "function" and unitFramesModule:GetDB() or nil

        self._layoutPreviewUnitFramesState = {
            wasEnabled = wasEnabled,
            testMode = unitFrameDB and unitFrameDB.testMode == true or false,
        }

        if not wasEnabled and type(unitFramesModule.Enable) == "function" then
            pcall(unitFramesModule.Enable, unitFramesModule)
        end

        if type(unitFramesModule.SetTestMode) == "function" then
            pcall(unitFramesModule.SetTestMode, unitFramesModule, true)
        elseif unitFrameDB then
            unitFrameDB.testMode = true
            if type(unitFramesModule.RefreshAllFrames) == "function" then
                pcall(unitFramesModule.RefreshAllFrames, unitFramesModule)
            end
        end
        return
    end

    local previousState = self._layoutPreviewUnitFramesState
    if not previousState then
        return
    end

    if type(unitFramesModule.SetTestMode) == "function" then
        pcall(unitFramesModule.SetTestMode, unitFramesModule, previousState.testMode == true)
    else
        local unitFrameDB = type(unitFramesModule.GetDB) == "function" and unitFramesModule:GetDB() or nil
        if unitFrameDB then
            unitFrameDB.testMode = previousState.testMode == true
            if type(unitFramesModule.RefreshAllFrames) == "function" then
                pcall(unitFramesModule.RefreshAllFrames, unitFramesModule)
            end
        end
    end

    if not previousState.wasEnabled and unitFramesModule.IsEnabled and unitFramesModule:IsEnabled() and
        type(unitFramesModule.Disable) == "function" then
        pcall(unitFramesModule.Disable, unitFramesModule)
    end

    self._layoutPreviewUnitFramesState = nil
end

--- Applies a theme preset to ThemeModule and broadcasts TWICH_THEME_CHANGED.
---@param presetId string
function SetupWizardModule:ApplyThemePreset(presetId)
    local preset = self:GetThemePreset(presetId)
    if not preset then return end
    local ThemeModule = T:GetModule("Theme")
    if not ThemeModule then return end
    local db = ThemeModule:GetDB()
    local themeKeys = {
        "primaryColor", "accentColor", "backgroundColor", "borderColor",
        "textColor", "successColor", "warningColor", "dangerColor",
        "backgroundAlpha", "borderAlpha", "statusBarTexture", "classIconStyle",
        "globalFont", "soundProfile", "uiSoundsEnabled", "soundVolume",
        "useClassColor",
    }
    for _, key in ipairs(themeKeys) do
        if preset[key] ~= nil then
            if type(preset[key]) == "table" and type(CopyTable) == "function" then
                db[key] = CopyTable(preset[key])
            else
                db[key] = preset[key]
            end
        end
    end

    -- Keep chat message row background aligned with the active theme background,
    -- but at a lightweight readability alpha.
    local chatOpts = T:GetModule("Configuration", true) and T:GetModule("Configuration", true).Options and
        T:GetModule("Configuration", true).Options.ChatEnhancement
    if chatOpts and type(chatOpts.GetChatEnhancementDB) == "function" then
        local chatDB = chatOpts:GetChatEnhancementDB()
        local bg = db.backgroundColor or { 0.05, 0.06, 0.08 }
        chatDB.msgBgColor = {
            r = bg[1] or 0.05,
            g = bg[2] or 0.06,
            b = bg[3] or 0.08,
            a = 0.30,
        }
        if type(chatOpts.RefreshChatStylingModule) == "function" then
            pcall(chatOpts.RefreshChatStylingModule, chatOpts)
        end
    end

    db.appliedThemePreset = presetId
    ThemeModule:SendMessage("TWICH_THEME_CHANGED", nil)
    self:GetDB().appliedThemePreset = presetId

    -- Immediately refresh datatext panels to show new theme colors
    local datatextModule = T:GetModule("Datatexts", true)
    if datatextModule then
        -- Directly refresh panels if they exist
        if type(datatextModule.RefreshStandalonePanels) == "function" then
            pcall(datatextModule.RefreshStandalonePanels, datatextModule)
        end
        -- Also try to update the theme colors in its stored panels
        if datatextModule.standalonePanels then
            for panelID, frame in pairs(datatextModule.standalonePanels) do
                if frame and type(datatextModule.ApplyStandalonePanelStyle) == "function" then
                    local panelDB = datatextModule.GetStandaloneDB and datatextModule:GetStandaloneDB()
                    local panelDefinition = panelDB and panelDB.panels and panelDB.panels[panelID]
                    pcall(datatextModule.ApplyStandalonePanelStyle, datatextModule, frame, panelDefinition)
                end
            end
        end
    end
end

--- Returns whether ElvUI is installed and currently loaded.
---@return boolean
function SetupWizardModule:IsElvUIActive()
    local isLoaded = type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" and
        C_AddOns.IsAddOnLoaded("ElvUI")
    local E = _G.ElvUI and _G.ElvUI[1]
    return isLoaded == true and type(E) == "table"
end

--- Detects ElvUI module states that are likely to conflict with TwichUI systems.
---@return table
function SetupWizardModule:DetectElvUIConflicts()
    local result = {
        available = false,
        chatEnabled = false,
        datatextEnabled = false,
        unitFramesEnabled = false,
        actionBarsEnabled = false,
    }
    if not self:IsElvUIActive() then
        return result
    end

    local E = _G.ElvUI and _G.ElvUI[1]
    local private = E and E.private or nil
    local db = E and E.db or nil

    -- ElvUI chat typically uses private.chat.enable
    local chatEnabled = true
    if type(private) == "table" and type(private.chat) == "table" and private.chat.enable ~= nil then
        chatEnabled = private.chat.enable ~= false
    end

    -- Datatexts are usually controlled via private/datatext containers.
    local datatextEnabled = true
    if type(private) == "table" and type(private.datatexts) == "table" and private.datatexts.enable ~= nil then
        datatextEnabled = private.datatexts.enable ~= false
    elseif type(db) == "table" and type(db.datatexts) == "table" and db.datatexts.enable ~= nil then
        datatextEnabled = db.datatexts.enable ~= false
    end

    result.available = true
    result.chatEnabled = chatEnabled
    result.datatextEnabled = datatextEnabled
    result.unitFramesEnabled = type(private) == "table" and type(private.unitframe) == "table" and
        private.unitframe.enable ~= false or false
    result.actionBarsEnabled = type(private) == "table" and type(private.actionbar) == "table" and
        private.actionbar.enable ~= false or false
    return result
end

function SetupWizardModule:GetUnitFrameWizardChoices()
    local CM = T:GetModule("Configuration", true)
    local options = CM and CM.Options or nil
    local unitFrameOptions = options and options.UnitFrames or nil

    local result = {
        useTwichUnitFrames = true,
        showPlayerInParty = true,
        showPartyCastbars = true,
    }

    if not (unitFrameOptions and type(unitFrameOptions.GetDB) == "function") then
        return result
    end

    local db = unitFrameOptions:GetDB()
    local partySettings = type(db.groups) == "table" and type(db.groups.party) == "table" and db.groups.party or {}
    local partyCastbar = type(db.castbars) == "table" and type(db.castbars.party) == "table" and db.castbars.party or {}

    result.useTwichUnitFrames = db.enabled ~= false
    result.showPlayerInParty = partySettings.showPlayer ~= false
    result.showPartyCastbars = partyCastbar.enabled ~= false
    return result
end

function SetupWizardModule:ApplyUnitFrameWizardChoices(choices)
    local selected = choices or {}
    local useTwichUnitFrames = selected.useTwichUnitFrames ~= false
    local showPlayerInParty = selected.showPlayerInParty ~= false
    local showPartyCastbars = selected.showPartyCastbars ~= false
    local conflicts = self:DetectElvUIConflicts()

    local CM = T:GetModule("Configuration", true)
    local options = CM and CM.Options or nil
    local unitFrameOptions = options and options.UnitFrames or nil
    if unitFrameOptions and type(unitFrameOptions.GetDB) == "function" then
        local db = unitFrameOptions:GetDB()
        db.enabled = useTwichUnitFrames
        db.groups = db.groups or {}
        db.groups.party = db.groups.party or {}
        db.groups.party.showPlayer = showPlayerInParty
        db.castbars = db.castbars or {}
        db.castbars.party = db.castbars.party or {}
        db.castbars.party.enabled = showPartyCastbars

        local unitFramesModule = T:GetModule("UnitFrames", true)
        if unitFramesModule then
            if useTwichUnitFrames then
                if unitFramesModule.IsEnabled and not unitFramesModule:IsEnabled() and type(unitFramesModule.Enable) == "function" then
                    pcall(unitFramesModule.Enable, unitFramesModule)
                elseif type(unitFramesModule.RefreshAllFrames) == "function" then
                    pcall(unitFramesModule.RefreshAllFrames, unitFramesModule)
                end
            elseif unitFramesModule.IsEnabled and unitFramesModule:IsEnabled() and type(unitFramesModule.Disable) == "function" then
                pcall(unitFramesModule.Disable, unitFramesModule)
            end
        end
    end

    local E = _G.ElvUI and _G.ElvUI[1]
    if E and type(E.private) == "table" then
        E.private.unitframe = E.private.unitframe or {}
        if useTwichUnitFrames then
            E.private.unitframe.enable = false
        elseif conflicts.available then
            E.private.unitframe.enable = true
        end
    end

    local wizardDB = self:GetDB()
    wizardDB.unitFrameChoice = {
        useTwichUnitFrames = useTwichUnitFrames,
        showPlayerInParty = showPlayerInParty,
        showPartyCastbars = showPartyCastbars,
        appliedAt = _G.time and _G.time() or nil,
    }

    return useTwichUnitFrames and conflicts.available and conflicts.unitFramesEnabled == true
end

--- Reads current action bar wizard choices from the DB.
---@return table
function SetupWizardModule:GetActionBarWizardChoices()
    local CM = T:GetModule("Configuration", true)
    local options = CM and CM.Options or nil
    local abOptions = options and options.ActionBars or nil

    local result = { useTwichActionBars = true }

    if not (abOptions and type(abOptions.GetDB) == "function") then
        return result
    end

    local db = abOptions:GetDB()
    result.useTwichActionBars = db.enabled ~= false
    return result
end

--- Applies the wizard action bar ownership choice; disables ElvUI action bars when TwichUI is chosen.
--- Returns true if a reload is needed (TwichUI chosen and ElvUI action bars were active).
---@param choices table|nil
---@return boolean
function SetupWizardModule:ApplyActionBarWizardChoices(choices)
    local selected   = choices or {}
    local useTwichAB = selected.useTwichActionBars ~= false
    local conflicts  = self:DetectElvUIConflicts()

    local CM         = T:GetModule("Configuration", true)
    local options    = CM and CM.Options or nil
    local abOptions  = options and options.ActionBars or nil
    if abOptions and type(abOptions.GetDB) == "function" then
        local db = abOptions:GetDB()
        db.enabled = useTwichAB
        local abModule = T:GetModule("ActionBars", true)
        if abModule then
            if useTwichAB then
                if abModule.IsEnabled and not abModule:IsEnabled() and type(abModule.Enable) == "function" then
                    pcall(abModule.Enable, abModule)
                end
            elseif abModule.IsEnabled and abModule:IsEnabled() and type(abModule.Disable) == "function" then
                pcall(abModule.Disable, abModule)
            end
        end
    end

    local E = _G.ElvUI and _G.ElvUI[1]
    if E and type(E.private) == "table" then
        E.private.actionbar = E.private.actionbar or {}
        if useTwichAB then
            E.private.actionbar.enable = false
        elseif conflicts.available then
            E.private.actionbar.enable = true
        end
    end

    local wizardDB = self:GetDB()
    wizardDB.actionBarChoice = {
        useTwichActionBars = useTwichAB,
        appliedAt = _G.time and _G.time() or nil,
    }

    return useTwichAB and conflicts.available and conflicts.actionBarsEnabled == true
end

--- Applies wizard ownership choices between TwichUI and ElvUI for overlapping features.
---@param choices table|nil
function SetupWizardModule:ApplyElvUIConflictChoices(choices)
    local selected = choices or {}
    local useTwichChat = selected.useTwichChat ~= false
    local useTwichDatatext = selected.useTwichDatatext ~= false

    local CM = T:GetModule("Configuration", true)
    if not CM then return end

    local chatOpts = CM.Options and CM.Options.ChatEnhancement
    if chatOpts and type(chatOpts.GetChatEnhancementDB) == "function" then
        chatOpts:GetChatEnhancementDB().stylingEnabled = useTwichChat
        if type(chatOpts.RefreshChatStylingModule) == "function" then
            pcall(chatOpts.RefreshChatStylingModule, chatOpts)
        end
    end

    local datatextOpts = CM.Options and CM.Options.Datatext
    if datatextOpts and type(datatextOpts.GetDB) == "function" then
        datatextOpts:GetDB().enabled = useTwichDatatext
        local datatextModule = T:GetModule("Datatexts", true)
        if datatextModule then
            if useTwichDatatext and type(datatextModule.Enable) == "function" and not datatextModule:IsEnabled() then
                pcall(datatextModule.Enable, datatextModule)
            elseif (not useTwichDatatext) and type(datatextModule.Disable) == "function" and datatextModule:IsEnabled() then
                pcall(datatextModule.Disable, datatextModule)
            end
            if type(datatextModule.RefreshStandalonePanels) == "function" then
                pcall(datatextModule.RefreshStandalonePanels, datatextModule)
            end
        end
    end

    -- Disable ElvUI modules when TwichUI is chosen
    local E = _G.ElvUI and _G.ElvUI[1]
    if E then
        if useTwichChat and E.private and E.private.chat then
            E.private.chat.enable = false
        end
        if useTwichDatatext then
            -- Disable main datatext system
            if E.private and E.private.datatexts then
                E.private.datatexts.enable = false
            end
            -- Disable all individual datatext panels
            local DT = E:GetModule('DataTexts')
            if DT and DT.db and DT.db.panels then
                for panelName in pairs(DT.db.panels) do
                    DT.db.panels[panelName].enable = false
                end
            end
            -- Disable ElvUI bottom panel when using TwichUI datatexts
            if E.db and E.db.general then
                E.db.general.bottomPanel = false
            end
        end
    end

    local wizardDB = self:GetDB()
    wizardDB.elvuiChoice = {
        useTwichChat = useTwichChat,
        useTwichDatatext = useTwichDatatext,
        appliedAt = _G.time and _G.time() or nil,
    }
end

--- Applies font size settings to chat, chat header, and datatext modules.
---@param sizes {chatFontSize: number, chatHeaderFontSize: number, datatextFontSize: number}
function SetupWizardModule:ApplyFontSizes(sizes)
    local selected = sizes or {}
    local chatFontSize = tonumber(selected.chatFontSize) or 11
    local chatHeaderFontSize = tonumber(selected.chatHeaderFontSize) or 11
    local datatextFontSize = tonumber(selected.datatextFontSize) or 11

    -- Apply chat message font size
    local chatOpts = T:GetModule("Configuration", true) and T:GetModule("Configuration", true).Options and
        T:GetModule("Configuration", true).Options.ChatEnhancement
    if chatOpts and type(chatOpts.GetChatEnhancementDB) == "function" then
        local chatDB = chatOpts:GetChatEnhancementDB()
        if chatDB then
            chatDB.chatFontSize = chatFontSize
        end
        if type(chatOpts.RefreshChatStylingModule) == "function" then
            pcall(chatOpts.RefreshChatStylingModule, chatOpts)
        end
    end

    -- Apply chat header (tab + header datatext) font size
    if chatOpts and type(chatOpts.GetChatEnhancementDB) == "function" then
        local chatDB = chatOpts:GetChatEnhancementDB()
        if chatDB then
            chatDB.tabFontSize = chatHeaderFontSize
        end
        local hdt = chatDB and type(chatOpts.GetHeaderDatatextDB) == "function" and chatOpts:GetHeaderDatatextDB() or nil
        if hdt then
            hdt.fontSize = chatHeaderFontSize
        end
        if type(chatOpts.RefreshChatStylingModule) == "function" then
            pcall(chatOpts.RefreshChatStylingModule, chatOpts)
        end
    end

    -- Apply standalone datatext panel font size
    local datatextOpts = T:GetModule("Configuration", true) and T:GetModule("Configuration", true).Options and
        T:GetModule("Configuration", true).Options.Datatext
    if datatextOpts and type(datatextOpts.GetStandaloneDB) == "function" then
        local standaloneDB = datatextOpts:GetStandaloneDB()
        if standaloneDB and standaloneDB.style then
            standaloneDB.style.fontSize = datatextFontSize
        end
        local datatextModule = T:GetModule("Datatexts", true)
        if datatextModule and type(datatextModule.RefreshStandalonePanels) == "function" then
            pcall(datatextModule.RefreshStandalonePanels, datatextModule)
        end
    end

    local wizardDB = self:GetDB()
    wizardDB.appliedFontSizes = {
        chatFontSize = chatFontSize,
        chatHeaderFontSize = chatHeaderFontSize,
        datatextFontSize = datatextFontSize,
        appliedAt = _G.time and _G.time() or nil,
    }
end

-- ─── Lifecycle ──────────────────────────────────────────────────────────────

function SetupWizardModule:OnEnable()
    -- Register the wizard debug console source so /tui debug wizard works immediately.
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if console and type(console.RegisterSource) == "function" then
        console:RegisterSource("wizard", { title = "SetupWizard Dev" })
    end

    -- Register once per session; unregistered immediately after firing.
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function SetupWizardModule:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if not self:ShouldShow() then return end
    -- Brief delay so the game world finishes rendering before overlaying the wizard.
    C_Timer.After(3, function()
        if InCombatLockdown() then return end
        self:Show()
    end)
end

--- Shows the setup wizard immediately (safe to call from slash commands / config UI).
function SetupWizardModule:Show()
    if not self.UI then return end
    self.UI:Show()
end

function SetupWizardModule:Hide()
    if not self.UI or not self.UI._Close then return end
    self.UI:_Close()
end

function SetupWizardModule:IsShown()
    local frame = self.UI and self.UI.frame or nil
    return frame and frame.IsShown and frame:IsShown() or false
end

function SetupWizardModule:Toggle()
    if self:IsShown() then
        self:Hide()
        return
    end

    self:Show()
end
