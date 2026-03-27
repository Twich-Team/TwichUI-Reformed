---@diagnostic disable: undefined-field
--[[
    TwichUI Setup Wizard — Core Module

    Manages the wizard version, first-login trigger, DB persistence, layout frame
    registry, and layout/theme application APIs.

    HOW TO RE-TRIGGER THE WIZARD FOR NEW FEATURES:
      Increment WIZARD_VERSION below. All users whose completedVersion is less than
      the new value will see the wizard again on next login.
]]
local TwichRx           = _G.TwichRx
---@type TwichUI
local T                 = unpack(TwichRx)

local C_Timer           = _G.C_Timer
local InCombatLockdown  = _G.InCombatLockdown
local GetScreenWidth    = _G.GetScreenWidth
local GetScreenHeight   = _G.GetScreenHeight

--- Increment to re-show the wizard for all users (e.g. when a new setup step is added).
local WIZARD_VERSION    = 1

---@class SetupWizardModule : AceModule, AceEvent-3.0
local SetupWizardModule = T:NewModule("SetupWizard", "AceEvent-3.0")
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

-- ─── Version / trigger ─────────────────────────────────────────────────────

--- Returns true if the wizard should be shown (never completed, or a new version is available).
function SetupWizardModule:ShouldShow()
    -- In-session guard: if we already completed the wizard this session, never re-show
    -- regardless of DB state (guards against any edge-case DB timing issues).
    if self._completedThisSession then return false end
    local db = self:GetDB()
    return (db.completedVersion or 0) < WIZARD_VERSION
end

--- Marks the wizard as completed for the current WIZARD_VERSION.
function SetupWizardModule:MarkComplete()
    self._completedThisSession = true
    self:GetDB().completedVersion = WIZARD_VERSION
end

--- Resets completion so the wizard will appear again on next login.
--- Useful for testing or for the config panel's "Re-run Wizard" button.
function SetupWizardModule:Reset()
    self._completedThisSession = false
    self:GetDB().completedVersion = 0
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
    for sectionKey, sectionVal in pairs(snapshot) do
        if sectionKey ~= "setupWizard" then
            config[sectionKey] = sectionVal
        end
    end
    T:SendMessage("TWICH_CONFIG_RESTORED")
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
    for key, fd in pairs(layoutData.frames) do
        local entry = self.layoutFrames[key]
        local frame = entry and entry.frame
        if frame and frame.SetPoint then
            local absX = (fd.x or 0) * sw
            local absY = (fd.y or 0) * sh
            local absW = fd.w and fd.w * sw
            local absH = fd.h and fd.h * sh
            frame:ClearAllPoints()
            -- Always BOTTOMLEFT so persist callbacks receive consistent values.
            frame:SetPoint("BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", absX, absY)
            if absW then frame:SetWidth(absW) end
            if absH then frame:SetHeight(absH) end
            if entry.persist then
                entry.persist(absX, absY, absW or 0, absH or 0)
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
function SetupWizardModule:ApplyLayout(layoutId)
    local layout = self:GetLayout(layoutId)
    if not layout then return end
    -- 1. Apply the config snapshot: replaces chatEnhancement, datatext, etc.
    if type(layout.apply) == "function" then
        layout.apply()
    end
    -- 2. Apply frame positions: persist callbacks now write into the new tables.
    self:ApplyLayoutData(layout)
    self:GetDB().appliedLayout = layoutId
end

--- Applies a theme preset to ThemeModule and broadcasts TWICH_THEME_CHANGED.
---@param presetId string
function SetupWizardModule:ApplyThemePreset(presetId)
    local preset = self:GetThemePreset(presetId)
    if not preset then return end
    local ThemeModule = T:GetModule("Theme")
    if not ThemeModule then return end
    local colorKeys = { "primaryColor", "accentColor", "backgroundColor", "borderColor" }
    for _, key in ipairs(colorKeys) do
        if preset[key] then
            ThemeModule:Set(key, preset[key])
        end
    end
    self:GetDB().appliedThemePreset = presetId
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
