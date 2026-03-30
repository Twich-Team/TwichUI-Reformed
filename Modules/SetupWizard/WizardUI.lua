---@diagnostic disable: undefined-field, inject-field
--[[
    TwichUI Setup Wizard — Visual UI

    A multi-step modal wizard frame. Steps are:
      1  Welcome    — brand greeting and feature overview
      2  UI & Chat  — UI scale and chat setup options
      3  Layout     — choose a pre-defined layout  (cards sourced from Layouts.lua)
      4  Theme      — choose a color preset        (cards sourced from Layouts.lua)
      5  Font Sizes — adjust font sizes for chat and datatexts
      6  ElvUI      — resolve overlapping module conflicts (conditional)
      7  Finish     — summary and apply

    Extension points:
      • Add layouts  → AVAILABLE_LAYOUTS in Layouts.lua
      • Add themes   → THEME_PRESETS     in Layouts.lua
      • Add steps    → add an entry to STEP_DEFS and a Build* function below,
                       then increment WIZARD_VERSION in SetupWizardModule.lua
]]
local TwichRx            = _G.TwichRx
---@type TwichUI
local T                  = unpack(TwichRx)

---@type SetupWizardModule
local SetupWizardModule  = T:GetModule("SetupWizard")

local CreateFrame        = _G.CreateFrame
local C_UI               = _G.C_UI or {}
local GetCVar            = _G.GetCVar
local UnitClass          = _G.UnitClass
local RAID_CLASS_COLORS  = _G.RAID_CLASS_COLORS
local UIParent           = _G.UIParent
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

-- ─── Constants ──────────────────────────────────────────────────────────────

local W                  = 820
local H                  = 560
local HEADER_H           = 48
local STEPS_H            = 58
local FOOTER_H           = 60
local PAD                = 28
local CONTENT_H          = H - HEADER_H - STEPS_H - FOOTER_H -- ≈ 394

-- Canonical palette — intentionally not reading ThemeModule so the wizard
-- always launches in a legible state before the user applies a theme.
local C                  = {
    bg      = { 0.05, 0.06, 0.08 },
    header  = { 0.03, 0.04, 0.06 },
    border  = { 0.24, 0.26, 0.32 },
    teal    = { 0.10, 0.72, 0.74 },
    gold    = { 0.96, 0.76, 0.24 },
    text    = { 1.00, 0.95, 0.85 },
    muted   = { 0.50, 0.52, 0.58 },
    cardBg  = { 0.08, 0.09, 0.12 },
    cardSel = { 0.09, 0.18, 0.20 },
    cardBdr = { 0.20, 0.22, 0.28 },
}

local STEP_DEFS          = {
    { id = "welcome",    title = "Welcome" },
    { id = "ui",         title = "UI & Chat" },
    { id = "layout",     title = "Layout" },
    { id = "unitframes", title = "Unit Frames" },
    { id = "theme",      title = "Theme" },
    { id = "fonts",      title = "Font Sizes" },
    { id = "elvui",      title = "ElvUI" },
    { id = "finish",     title = "Finish" },
}

-- ─── UI namespace ───────────────────────────────────────────────────────────

---@class WizardUI
local UI                 = {}
SetupWizardModule.UI     = UI

UI.frame                 = nil
UI.backdrop              = nil
UI.currentStep           = 1
UI.selectedLayout        = "standard"
UI.selectedTheme         = "twich_default"
UI.selectedUIScalePreset = "auto"
UI.selectedUIScaleValue  = 0.8
UI.skipUIScale           = false
UI.applyChatSetup        = true
UI.uiScaleRefs           = {}
UI.chatFontSize          = 11
UI.chatHeaderFontSize    = 11
UI.datatextFontSize      = 11
UI.elvuiConflictInfo     = { available = false, chatEnabled = false, datatextEnabled = false }
UI.useTwichChat          = true
UI.useTwichDatatext      = true
UI.useTwichUnitFrames    = true
UI.showPlayerInParty     = true
UI.showPartyCastbars     = true

-- Per-step frames and build-state
UI.stepFrames            = {}
UI.stepBuilt             = {}

-- Live-refresh refs (populated by Build* functions)
UI.layoutCardRefs        = {} -- [layoutId]  = { card, nameText, checkMark }
UI.themeCardRefs         = {} -- [themeId]   = { card, checkMark }
UI.finishRefs            = {} -- { layoutLabel, themeLabel, resLabel }
UI.dotRefs               = {} -- [i]         = { dot, dotText, labelText }
UI.lineRefs              = {} -- [i]         = lineFrame (between dots i and i+1)

-- ─── Font helper ────────────────────────────────────────────────────────────

local function Font(size, flags)
    local LSM  = T.Libs and T.Libs.LSM
    -- Fonts\ARIALN.TTF is bundled with WoW and supports Unicode chars (✓ ← → ✕ ›).
    -- Prefer an LSM override, then Arial Narrow, then the system default.
    local path = (LSM and LSM.Fetch and LSM:Fetch("font", "Expressway"))
        or "Fonts\\ARIALN.TTF"
        or STANDARD_TEXT_FONT
    return path, size or 13, flags or ""
end

-- ─── Small constructors ─────────────────────────────────────────────────────

local function NewText(parent, text, size, r, g, b, justH, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Font(size or 13, flags))
    fs:SetText(text or "")
    if r then fs:SetTextColor(r, g, b) else fs:SetTextColor(C.text[1], C.text[2], C.text[3]) end
    fs:SetJustifyH(justH or "LEFT")
    return fs
end

local function Backdrop(frame, bg, border, a_bg, a_bdr)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], a_bg or 1)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], a_bdr or 1)
end

-- Creates a TwichUI-styled button and returns (button, labelFontString).
local function NewButton(parent, label, w, h, r, g, b)
    r, g, b = r or C.teal[1], g or C.teal[2], b or C.teal[3]
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 110, h or 32)
    Backdrop(btn, { r, g, b }, { r, g, b }, 0.12, 0.65)
    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Font(13))
    fs:SetText(label or "")
    fs:SetTextColor(C.text[1], C.text[2], C.text[3])
    fs:SetAllPoints(btn)
    fs:SetJustifyH("CENTER")
    btn:SetScript("OnEnter", function()
        btn:SetBackdropColor(r, g, b, 0.28); btn:SetBackdropBorderColor(r, g, b, 1)
    end)
    btn:SetScript("OnLeave",
        function()
            btn:SetBackdropColor(r, g, b, 0.12); btn:SetBackdropBorderColor(r, g, b, 0.65)
        end)
    return btn, fs
end

-- Creates a TwichUI-themed checkbox row and returns the clickable holder.
local function NewTwichCheckbox(parent, label, checked)
    local holder = CreateFrame("Button", nil, parent)
    holder:SetHeight(22)

    local box = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    box:SetSize(18, 18)
    box:SetPoint("LEFT", holder, "LEFT", 0, 0)

    local tick = box:CreateTexture(nil, "OVERLAY")
    tick:SetSize(12, 12)
    tick:SetPoint("CENTER", box, "CENTER", 0, 0)
    tick:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")

    local text = NewText(holder, label or "", 12, C.text[1], C.text[2], C.text[3])
    text:SetPoint("LEFT", box, "RIGHT", 8, 0)

    local function ApplyVisualState()
        local isChecked = holder.checked == true
        if isChecked then
            Backdrop(box, C.cardSel, C.teal, 1, 1)
            tick:Show()
        else
            Backdrop(box, C.cardBg, C.cardBdr, 1, 0.9)
            tick:Hide()
        end
    end

    function holder:SetChecked(value)
        self.checked = value == true
        ApplyVisualState()
    end

    function holder:GetChecked()
        return self.checked == true
    end

    function holder:SetOnValueChanged(callback)
        self._onValueChanged = callback
    end

    holder:SetScript("OnEnter", function()
        if not holder:GetChecked() then
            box:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.7)
        end
    end)
    holder:SetScript("OnLeave", function()
        if not holder:GetChecked() then
            box:SetBackdropBorderColor(C.cardBdr[1], C.cardBdr[2], C.cardBdr[3], 0.9)
        end
    end)
    holder:SetScript("OnClick", function(selfBtn)
        selfBtn:SetChecked(not selfBtn:GetChecked())
        if type(selfBtn._onValueChanged) == "function" then
            selfBtn._onValueChanged(selfBtn, selfBtn:GetChecked())
        end
    end)

    holder:SetChecked(checked == true)
    holder:SetWidth(math.max(160, math.floor((text:GetStringWidth() or 80) + 32)))

    return holder, text
end

-- Creates a TwichUI-themed horizontal slider shell.
local function NewTwichSlider(parent, width, minValue, maxValue, stepValue, initialValue, label)
    local shell = CreateFrame("Frame", nil, parent)
    shell:SetSize(width or 460, 44)

    shell.Label = NewText(shell, label or "", 12)
    shell.Label:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)
    shell.Label:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, shell)
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 0, 0)
    slider:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 0, 0)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(stepValue)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(initialValue)
    slider:EnableMouseWheel(true)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")

    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(1, 1)
        thumb:SetVertexColor(0, 0, 0, 0)
    end

    slider.Track = shell:CreateTexture(nil, "ARTWORK")
    slider.Track:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 0, 0)
    slider.Track:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", 0, 0)
    slider.Track:SetHeight(4)
    slider.Track:SetColorTexture(C.cardBdr[1], C.cardBdr[2], C.cardBdr[3], 0.95)

    slider.Fill = shell:CreateTexture(nil, "OVERLAY")
    slider.Fill:SetPoint("LEFT", slider.Track, "LEFT", 0, 0)
    slider.Fill:SetHeight(4)
    slider.Fill:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 0.95)

    slider.Knob = CreateFrame("Frame", nil, shell, "BackdropTemplate")
    slider.Knob:SetSize(12, 18)
    Backdrop(slider.Knob, C.cardSel, C.teal, 1, 1)
    slider.Knob:SetFrameLevel(shell:GetFrameLevel() + 3)

    slider.Low = NewText(shell, string.format("%.2f", minValue), 10, C.muted[1], C.muted[2], C.muted[3])
    slider.Low:SetPoint("TOPLEFT", slider.Track, "BOTTOMLEFT", 0, -2)
    slider.High = NewText(shell, string.format("%.2f", maxValue), 10, C.muted[1], C.muted[2], C.muted[3], "RIGHT")
    slider.High:SetPoint("TOPRIGHT", slider.Track, "BOTTOMRIGHT", 0, -2)

    local function UpdateVisual(value)
        local lo, hi = slider:GetMinMaxValues()
        local range = hi - lo
        local ratio = range > 0 and ((value - lo) / range) or 0
        ratio = math.max(0, math.min(1, ratio))
        local trackW = math.max(1, slider.Track:GetWidth() or (shell:GetWidth() or 1))
        slider.Fill:SetWidth(trackW * ratio)
        slider.Knob:ClearAllPoints()
        slider.Knob:SetPoint("CENTER", slider.Track, "LEFT", trackW * ratio, 0)
    end

    shell:SetScript("OnSizeChanged", function()
        UpdateVisual(slider:GetValue())
    end)

    slider:SetScript("OnValueChanged", function(selfSlider, value)
        UpdateVisual(value)
        if type(shell._onValueChanged) == "function" then
            shell._onValueChanged(shell, value)
        end
    end)
    slider:SetScript("OnMouseWheel", function(selfSlider, delta)
        selfSlider:SetValue(selfSlider:GetValue() + (delta * stepValue))
    end)

    function shell:SetOnValueChanged(callback)
        self._onValueChanged = callback
    end

    function shell:SetValue(value)
        slider:SetValue(value)
    end

    function shell:GetValue()
        return slider:GetValue()
    end

    function shell:SetEnabled(enabled)
        local state = enabled ~= false
        slider:SetEnabled(state)
        slider:EnableMouseWheel(state)
        shell:SetAlpha(state and 1 or 0.45)
    end

    shell.Slider = slider
    UpdateVisual(initialValue)
    return shell
end

-- ─── Main frame ─────────────────────────────────────────────────────────────

function UI:Create()
    if self.frame then return end

    -- Dim backdrop
    local bd = CreateFrame("Frame", nil, UIParent)
    bd:SetFrameStrata("DIALOG")
    bd:SetFrameLevel(100)
    bd:SetAllPoints(UIParent)
    local bdTex = bd:CreateTexture(nil, "BACKGROUND")
    bdTex:SetAllPoints(bd)
    bdTex:SetColorTexture(0, 0, 0, 0.58)
    bd:Hide()
    self.backdrop = bd

    -- Main frame
    local f = CreateFrame("Frame", "TwichWizardFrame", UIParent, "BackdropTemplate")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(101)
    f:SetSize(W, H)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    Backdrop(f, C.bg, C.border, 0.97, 1)
    f:Hide()
    self.frame = f

    self:_BuildHeader()
    self:_BuildStepIndicator()
    self:_BuildContentArea()
    self:_BuildFooter()
end

-- ─── Header ─────────────────────────────────────────────────────────────────

function UI:_BuildHeader()
    local f = self.frame

    local hdr = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hdr:SetSize(W - 2, HEADER_H)
    hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    Backdrop(hdr, C.header, C.header, 1, 1)

    local title = NewText(hdr, "|cff19c9c7Twich|r|cfffff4d6UI|r Reformed  |cff505468Setup Wizard|r", 15)
    title:SetPoint("LEFT", hdr, "LEFT", PAD, 0)

    local closeBtn = CreateFrame("Button", nil, hdr)
    closeBtn:SetSize(36, 36)
    closeBtn:SetPoint("RIGHT", hdr, "RIGHT", -10, 0)
    local closeText = NewText(closeBtn, "X", 15, 0.38, 0.40, 0.46, "CENTER")
    closeText:SetAllPoints(closeBtn)
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(0.80, 0.80, 0.80) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(0.38, 0.40, 0.46) end)
    closeBtn:SetScript("OnClick", function()
        -- Closing the wizard header-X is treated the same as Skip: mark it complete
        -- so it does not re-appear on the next reload.
        SetupWizardModule:MarkComplete()
        UI:_Close()
    end)

    -- Teal accent line below header
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 0.9)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(HEADER_H + 1))
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -(HEADER_H + 1))
end

-- ─── Step indicator ─────────────────────────────────────────────────────────

function UI:_BuildStepIndicator()
    local f        = self.frame
    local n        = #STEP_DEFS

    local DOT_SIZE = 22
    local LINE_W   = 54
    local totalW   = n * DOT_SIZE + (n - 1) * LINE_W
    local startX   = (W - totalW) / 2

    for i, step in ipairs(STEP_DEFS) do
        local dotX = startX + (i - 1) * (DOT_SIZE + LINE_W)
        local dotY = -(HEADER_H + 2 + (STEPS_H - DOT_SIZE) / 2)

        -- Dot
        local dot = CreateFrame("Frame", nil, f, "BackdropTemplate")
        dot:SetSize(DOT_SIZE, DOT_SIZE)
        dot:SetPoint("TOPLEFT", f, "TOPLEFT", dotX, dotY)
        Backdrop(dot, C.cardBg, C.cardBdr, 1, 0.7)

        local dotText = dot:CreateFontString(nil, "OVERLAY")
        dotText:SetFont(Font(12))
        dotText:SetAllPoints(dot)
        dotText:SetJustifyH("CENTER")
        dotText:SetJustifyV("MIDDLE")
        dotText:SetText(tostring(i))
        dotText:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

        -- Label under dot
        local labelText = NewText(f, step.title, 10, C.muted[1], C.muted[2], C.muted[3], "CENTER")
        labelText:SetPoint("TOP", dot, "BOTTOM", 0, -3)

        self.dotRefs[i] = { dot = dot, dotText = dotText, labelText = labelText }

        -- Connecting line to next dot
        if i < n then
            local line = CreateFrame("Frame", nil, f, "BackdropTemplate")
            line:SetSize(LINE_W, 1)
            line:SetPoint("LEFT", dot, "RIGHT", 0, 0)
            Backdrop(line, C.cardBdr, C.cardBdr, 0.8, 0)
            self.lineRefs[i] = line
        end
    end
end

function UI:_UpdateStepIndicator()
    for i, refs in ipairs(self.dotRefs) do
        if i < self.currentStep then
            -- Completed
            Backdrop(refs.dot, { 0.08, 0.48, 0.50 }, C.teal, 1, 1)
            refs.dotText:SetFont(Font(12))
            refs.dotText:SetText("|TInterface\\RAIDFRAME\\ReadyCheck-Ready:12:12:0:0|t")
            refs.dotText:SetTextColor(1, 1, 1)
            refs.labelText:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
        elseif i == self.currentStep then
            -- Active
            Backdrop(refs.dot, C.teal, C.teal, 1, 1)
            refs.dotText:SetFont(Font(12))
            refs.dotText:SetText(tostring(i))
            refs.dotText:SetTextColor(0.02, 0.04, 0.06)
            refs.labelText:SetTextColor(C.text[1], C.text[2], C.text[3])
        else
            -- Upcoming
            Backdrop(refs.dot, C.cardBg, C.cardBdr, 1, 0.5)
            refs.dotText:SetFont(Font(12))
            refs.dotText:SetText(tostring(i))
            refs.dotText:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
            refs.labelText:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        end
    end
    for i, line in ipairs(self.lineRefs) do
        if i < self.currentStep then
            Backdrop(line, C.teal, C.teal, 0.7, 0)
        else
            Backdrop(line, C.cardBdr, C.cardBdr, 0.6, 0)
        end
    end
end

-- ─── Content area ───────────────────────────────────────────────────────────

function UI:_BuildContentArea()
    local f = self.frame

    local contentRoot = CreateFrame("Frame", nil, f)
    contentRoot:SetSize(W - 2, CONTENT_H)
    contentRoot:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -(HEADER_H + 2 + STEPS_H))
    self.contentRoot = contentRoot

    -- Pre-create one frame per step; each is shown/hidden as we navigate.
    for i = 1, #STEP_DEFS do
        local sf = CreateFrame("Frame", nil, contentRoot)
        sf:SetAllPoints(contentRoot)
        sf:Hide()
        self.stepFrames[i] = sf
    end
end

-- ─── Footer ─────────────────────────────────────────────────────────────────

function UI:_BuildFooter()
    local f = self.frame

    local footer = CreateFrame("Frame", nil, f)
    footer:SetSize(W - 2, FOOTER_H)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)

    -- Skip link
    local skipBtn = CreateFrame("Button", nil, footer)
    skipBtn:SetSize(120, 30)
    skipBtn:SetPoint("LEFT", footer, "LEFT", PAD, 0)
    local skipText = NewText(skipBtn, "Skip Setup", 12, C.muted[1], C.muted[2], C.muted[3], "LEFT")
    skipText:SetAllPoints(skipBtn)
    skipBtn:SetScript("OnEnter", function() skipText:SetTextColor(C.text[1], C.text[2], C.text[3]) end)
    skipBtn:SetScript("OnLeave", function() skipText:SetTextColor(C.muted[1], C.muted[2], C.muted[3]) end)
    skipBtn:SetScript("OnClick", function()
        SetupWizardModule:MarkComplete()
        UI:_Close()
    end)
    self.skipBtn = skipBtn

    local resetBtn, resetLabel = NewButton(footer, "Reset TwichUI DB", 152, 28, 0.88, 0.33, 0.33)
    resetBtn:SetPoint("LEFT", skipBtn, "RIGHT", 12, 0)
    resetLabel:SetTextColor(1, 0.92, 0.88)
    resetBtn:SetScript("OnClick", function()
        local CM = T:GetModule("Configuration", true)
        local resetNow = function()
            SetupWizardModule:ResetAddonDatabase()
        end

        if CM and type(CM.ShowGenericConfirmationDialog) == "function" then
            CM:ShowGenericConfirmationDialog(
                "This will wipe all TwichUI settings and reload the UI. Continue?",
                resetNow)
            return
        end

        resetNow()
    end)
    self.resetDBBtn = resetBtn

    -- Next / Finish button (built first so back can anchor against it)
    local nextBtn, nextLabel = NewButton(footer, "Next >", 148, 32)
    nextBtn:SetPoint("RIGHT", footer, "RIGHT", -PAD, -2)
    nextBtn:SetScript("OnClick", function() UI:_GoNext() end)
    self.nextBtn             = nextBtn
    self.nextLabel           = nextLabel

    -- Back button — anchored to the left of next with a 10px gap
    local backBtn, backLabel = NewButton(footer, "< Back", 110, 32)
    backBtn:SetPoint("RIGHT", nextBtn, "LEFT", -10, 0)
    backBtn:SetBackdropColor(0.12, 0.13, 0.16, 1)
    backBtn:SetBackdropBorderColor(C.cardBdr[1], C.cardBdr[2], C.cardBdr[3], 0.8)
    backBtn:SetScript("OnEnter", function()
        backBtn:SetBackdropColor(0.16, 0.17, 0.20, 1)
        backBtn:SetBackdropBorderColor(0.40, 0.42, 0.48, 1)
    end)
    backBtn:SetScript("OnLeave", function()
        backBtn:SetBackdropColor(0.12, 0.13, 0.16, 1)
        backBtn:SetBackdropBorderColor(C.cardBdr[1], C.cardBdr[2], C.cardBdr[3], 0.8)
    end)
    backBtn:SetScript("OnClick", function() UI:_GoBack() end)
    self.backBtn   = backBtn
    self.backLabel = backLabel
end

-- ─── Navigation ─────────────────────────────────────────────────────────────

local function GetFirstLayoutId()
    local layouts = SetupWizardModule:GetAvailableLayouts() or {}
    return layouts[1] and layouts[1].id or "signature"
end

function UI:_GetPendingWizardStateSnapshot(targetStep)
    return {
        resumeStep = targetStep,
        selectedLayout = self.selectedLayout,
        selectedTheme = self.selectedTheme,
        selectedUIScalePreset = self.selectedUIScalePreset,
        selectedUIScaleValue = self.selectedUIScaleValue,
        skipUIScale = self.skipUIScale == true,
        applyChatSetup = self.applyChatSetup ~= false,
        chatFontSize = self.chatFontSize,
        chatHeaderFontSize = self.chatHeaderFontSize,
        datatextFontSize = self.datatextFontSize,
        useTwichChat = self.useTwichChat ~= false,
        useTwichDatatext = self.useTwichDatatext ~= false,
        useTwichUnitFrames = self.useTwichUnitFrames ~= false,
        showPlayerInParty = self.showPlayerInParty ~= false,
        showPartyCastbars = self.showPartyCastbars ~= false,
    }
end

function UI:_NeedsUnitFrameConflictReload()
    return self.useTwichUnitFrames ~= false and self.elvuiConflictInfo and self.elvuiConflictInfo.available and
        self.elvuiConflictInfo.unitFramesEnabled == true
end

function UI:_GoNext()
    if self.currentStep < #STEP_DEFS then
        local currentStepDef = STEP_DEFS[self.currentStep]
        if currentStepDef and currentStepDef.id == "unitframes" and self:_NeedsUnitFrameConflictReload() then
            SetupWizardModule:ApplyUnitFrameWizardChoices({
                useTwichUnitFrames = self.useTwichUnitFrames,
                showPlayerInParty = self.showPlayerInParty,
                showPartyCastbars = self.showPartyCastbars,
            })
            SetupWizardModule:SetPendingWizardState(self:_GetPendingWizardStateSnapshot(self.currentStep + 1))
            self:_Close()
            if type(C_UI.Reload) == "function" then
                C_UI.Reload()
            end
            return
        end

        local targetStep = self.currentStep + 1
        while targetStep <= #STEP_DEFS do
            local stepDef = STEP_DEFS[targetStep]
            if not (stepDef and stepDef.id == "elvui" and not (self.elvuiConflictInfo and self.elvuiConflictInfo.available)) then
                break
            end
            targetStep = targetStep + 1
        end
        if targetStep <= #STEP_DEFS then
            self:_GoToStep(targetStep)
        end
    else
        -- Mark complete FIRST so that even if ApplyLayout errors mid-way, the wizard
        -- does not re-appear on the next reload.
        SetupWizardModule:MarkComplete()
        local uiScaleMode = self.skipUIScale and "skip" or
            ((self.selectedUIScalePreset == "auto") and "auto" or "manual")
        SetupWizardModule:ApplyUIScale(uiScaleMode, self.selectedUIScaleValue)
        SetupWizardModule:ApplyLayout(self.selectedLayout, {
            applyChat = self.applyChatSetup ~= false,
        })
        SetupWizardModule:ApplyThemePreset(self.selectedTheme)
        SetupWizardModule:ApplyUnitFrameWizardChoices({
            useTwichUnitFrames = self.useTwichUnitFrames,
            showPlayerInParty = self.showPlayerInParty,
            showPartyCastbars = self.showPartyCastbars,
        })
        SetupWizardModule:ApplyElvUIConflictChoices({
            useTwichChat = self.useTwichChat,
            useTwichDatatext = self.useTwichDatatext,
        })
        SetupWizardModule:ApplyFontSizes({
            chatFontSize = self.chatFontSize,
            chatHeaderFontSize = self.chatHeaderFontSize,
            datatextFontSize = self.datatextFontSize,
        })
        self:_Close()
        -- Immediately reload without prompting
        C_UI.Reload()
    end
end

function UI:_GoBack()
    if self.currentStep > 1 then
        local targetStep = self.currentStep - 1
        while targetStep >= 1 do
            local stepDef = STEP_DEFS[targetStep]
            if not (stepDef and stepDef.id == "elvui" and not (self.elvuiConflictInfo and self.elvuiConflictInfo.available)) then
                break
            end
            targetStep = targetStep - 1
        end
        if targetStep >= 1 then
            self:_GoToStep(targetStep)
        end
    end
end

function UI:_GoToStep(n)
    self.currentStep = n
    self:_RenderStep(n)
end

function UI:_RenderStep(n)
    -- Hide all step frames
    for _, sf in ipairs(self.stepFrames) do sf:Hide() end

    self:_UpdateStepIndicator()
    self:_UpdateNavButtons()

    local stepDef = STEP_DEFS[n]
    local stepId = stepDef and stepDef.id or nil

    SetupWizardModule:SetLayoutPreviewUnitFramesEnabled(stepId == "layout")

    -- Build the step content on first visit, then just refresh dynamic pieces
    local sf = self.stepFrames[n]
    if not self.stepBuilt[n] then
        if stepId == "fonts" and self._SyncFontSizeStateFromConfig then
            self:_SyncFontSizeStateFromConfig(true)
        end
        self.stepBuilt[n] = true
        local builders = {
            welcome = UI._BuildWelcomeContent,
            ui = UI._BuildUIScaleContent,
            layout = UI._BuildLayoutContent,
            unitframes = UI._BuildUnitFramesContent,
            theme = UI._BuildThemeContent,
            fonts = UI._BuildFontSizeContent,
            elvui = UI._BuildElvUIContent,
            finish = UI._BuildFinishContent,
        }
        if stepId and builders[stepId] then builders[stepId](self, sf) end
    else
        -- Refresh live-selection state without a full rebuild
        if stepId == "ui" and self._RefreshUIScaleSummary then self:_RefreshUIScaleSummary() end
        if stepId == "layout" then self:_RefreshLayoutCards() end
        if stepId == "unitframes" and self._RefreshUnitFrameSummary then self:_RefreshUnitFrameSummary() end
        if stepId == "theme" then self:_RefreshThemeCards() end
        if stepId == "fonts" then
            if self._SyncFontSizeStateFromConfig then
                self:_SyncFontSizeStateFromConfig(true)
            end
            self:_RefreshFontSizeSliders()
        end
        if stepId == "elvui" and self._RefreshElvUIConflictSummary then self:_RefreshElvUIConflictSummary() end
        if stepId == "finish" then self:_RefreshFinishSummary() end
    end

    sf:Show()
end

function UI:_UpdateNavButtons()
    local n   = self.currentStep
    local max = #STEP_DEFS

    -- Back button hidden on first step
    if self.backBtn then
        self.backBtn:SetAlpha(n > 1 and 1 or 0)
        self.backBtn:EnableMouse(n > 1)
    end

    -- Next button label / accent on final step
    if self.nextLabel then
        if n == max then
            self.nextLabel:SetText("Apply & Begin")
            self.nextBtn:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.28)
            self.nextBtn:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
        else
            self.nextLabel:SetText("Next >")
            self.nextBtn:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
            self.nextBtn:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.65)
        end
    end
end

-- ─── Show / Hide ────────────────────────────────────────────────────────────

function UI:Show()
    self:Create()
    self.backdrop:Show()
    self.frame:Show()
    self.frame:SetAlpha(0)
    self.currentStep    = 1
    self.selectedLayout = GetFirstLayoutId()
    self.selectedTheme  = "twich_default"
    local useUiScale    = tonumber(GetCVar and GetCVar("useUiScale") or "0") == 1
    local cvarScale     = tonumber(GetCVar and GetCVar("uiScale") or "0")
    local autoScale     = SetupWizardModule:GetAutoUIScale()
    self.skipUIScale    = false
    if useUiScale then
        self.selectedUIScaleValue = math.max(0.64, math.min(1, cvarScale or autoScale))
        if math.abs(self.selectedUIScaleValue - 1.00) < 0.005 then
            self.selectedUIScalePreset = "default"
        else
            self.selectedUIScalePreset = "manual"
        end
    else
        self.selectedUIScalePreset = "auto"
        self.selectedUIScaleValue = autoScale
    end
    self.applyChatSetup     = true
    self.elvuiConflictInfo  = SetupWizardModule:DetectElvUIConflicts()
    self.useTwichChat       = true
    self.useTwichDatatext   = true
    self.useTwichUnitFrames = true
    self.showPlayerInParty  = true
    self.showPartyCastbars  = true
    self.uiScaleRefs        = {}

    local unitFrameChoices  = SetupWizardModule:GetUnitFrameWizardChoices()
    self.useTwichUnitFrames = unitFrameChoices.useTwichUnitFrames ~= false
    self.showPlayerInParty  = unitFrameChoices.showPlayerInParty ~= false
    self.showPartyCastbars  = unitFrameChoices.showPartyCastbars ~= false

    local pendingState      = SetupWizardModule:GetPendingWizardState()
    if type(pendingState) == "table" then
        self.currentStep = math.max(1, math.min(#STEP_DEFS, tonumber(pendingState.resumeStep) or 1))
        self.selectedLayout = pendingState.selectedLayout or self.selectedLayout
        self.selectedTheme = pendingState.selectedTheme or self.selectedTheme
        self.selectedUIScalePreset = pendingState.selectedUIScalePreset or self.selectedUIScalePreset
        self.selectedUIScaleValue = tonumber(pendingState.selectedUIScaleValue) or self.selectedUIScaleValue
        self.skipUIScale = pendingState.skipUIScale == true
        if pendingState.applyChatSetup ~= nil then
            self.applyChatSetup = pendingState.applyChatSetup == true
        end
        self.chatFontSize = tonumber(pendingState.chatFontSize) or self.chatFontSize
        self.chatHeaderFontSize = tonumber(pendingState.chatHeaderFontSize) or self.chatHeaderFontSize
        self.datatextFontSize = tonumber(pendingState.datatextFontSize) or self.datatextFontSize
        if pendingState.useTwichChat ~= nil then
            self.useTwichChat = pendingState.useTwichChat == true
        end
        if pendingState.useTwichDatatext ~= nil then
            self.useTwichDatatext = pendingState.useTwichDatatext == true
        end
        if pendingState.useTwichUnitFrames ~= nil then
            self.useTwichUnitFrames = pendingState.useTwichUnitFrames == true
        end
        if pendingState.showPlayerInParty ~= nil then
            self.showPlayerInParty = pendingState.showPlayerInParty == true
        end
        if pendingState.showPartyCastbars ~= nil then
            self.showPartyCastbars = pendingState.showPartyCastbars == true
        end
    end

    -- Clear prior build state so steps rebuild with fresh data
    self.stepBuilt      = {}
    self.layoutCardRefs = {}
    self.themeCardRefs  = {}
    self.unitFrameRefs  = {}
    self.finishRefs     = {}
    self:_RenderStep(self.currentStep)

    -- Fade in — OnFinished locks the base alpha so the frame stays visible
    -- after the animation ends (WoW reverts to base alpha on completion otherwise).
    local ag   = self.frame:CreateAnimationGroup()
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(0.22)
    ag:SetScript("OnFinished", function() self.frame:SetAlpha(1) end)
    ag:Play()
end

local function ResolvePresetSwatchColor(preset, key)
    if preset and preset.useClassColor == true and (key == "primaryColor" or key == "accentColor") then
        if type(UnitClass) == "function" then
            local _, classToken = UnitClass("player")
            local classTable = _G.CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
            local classColor = classTable and classToken and classTable[classToken]
            if classColor then
                return { classColor.r or 1, classColor.g or 1, classColor.b or 1 }
            end
        end
    end
    return preset and preset[key] or { 1, 1, 1 }
end

function UI:_Close()
    SetupWizardModule:SetLayoutPreviewUnitFramesEnabled(false)
    if self.frame then self.frame:Hide() end
    if self.backdrop then self.backdrop:Hide() end
end

-- ─── Step 1 — Welcome ────────────────────────────────────────────────────────

function UI:_BuildWelcomeContent(sf)
    local x, y = PAD, -PAD

    local brand = NewText(sf, "|cff19c9c7Twich|r|cfffff4d6UI|r Reformed", 28)
    brand:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local ver = NewText(sf, "Setup Wizard  ·  " .. (T.addonMetadata and T.addonMetadata.version or ""), 11, C.muted[1],
        C.muted[2], C.muted[3])
    ver:SetPoint("TOPLEFT", brand, "BOTTOMLEFT", 0, -4)

    local divLine = sf:CreateTexture(nil, "ARTWORK")
    divLine:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 0.55)
    divLine:SetSize(60, 1)
    divLine:SetPoint("TOPLEFT", ver, "BOTTOMLEFT", 0, -14)

    local welcome = NewText(sf, "Welcome! Let's get your setup configured.", 15, C.text[1], C.text[2], C.text[3])
    welcome:SetPoint("TOPLEFT", divLine, "BOTTOMLEFT", 0, -14)

    local desc = NewText(sf,
        "This wizard will help you choose a layout and a color theme.\n" ..
        "Everything can be changed at any time from |cff19c9c7/tui|r.",
        12, C.muted[1], C.muted[2], C.muted[3])
    desc:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -8)
    desc:SetWidth(W - PAD * 2 - 2)

    local bullets = {
        "Resolution-adaptive layouts — calibrated to your exact screen dimensions.",
        "Color themes with instant live preview — or customize every hue yourself.",
        "Designed and optimized for Mythic+ and Raiding.",
    }
    local prev = desc
    for i, text in ipairs(bullets) do
        local b = NewText(sf, "|cff19c9c7›|r  " .. text, 12, C.text[1], C.text[2], C.text[3])
        b:SetWidth(W - PAD * 2 - 24)
        if i == 1 then
            b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -22)
        else
            b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
        end
        prev = b
    end
end

-- ─── Step 2 — UI Scale & Chat ───────────────────────────────────────────────

local UI_SCALE_PRESETS = {
    { id = "auto",    label = "Auto" },
    { id = "default", label = "Default", value = 1.00 },
    { id = "small",   label = "Small",   value = 0.72 },
    { id = "medium",  label = "Medium",  value = 0.82 },
    { id = "large",   label = "Large",   value = 0.90 },
}

local function ResolveUIScaleFromPreset(presetId)
    for _, preset in ipairs(UI_SCALE_PRESETS) do
        if preset.id == presetId then
            if preset.id == "auto" then
                return SetupWizardModule:GetAutoUIScale()
            end
            return preset.value
        end
    end
    return SetupWizardModule:GetAutoUIScale()
end

function UI:_RefreshUIScalePresetButtons()
    local refs = self.uiScaleRefs
    if not refs or not refs.presetButtons then return end

    for presetId, presetRefs in pairs(refs.presetButtons) do
        local button = presetRefs.button
        local selected = (not self.skipUIScale) and (self.selectedUIScalePreset == presetId)
        if selected then
            button:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.38)
            button:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
            if presetRefs.label then
                presetRefs.label:SetTextColor(0.95, 1, 1)
                presetRefs.label:SetFont(Font(12, "OUTLINE"))
            end
            if presetRefs.selectedIcon then
                presetRefs.selectedIcon:Show()
            end
        else
            button:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
            button:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.65)
            if presetRefs.label then
                presetRefs.label:SetTextColor(C.text[1], C.text[2], C.text[3])
                presetRefs.label:SetFont(Font(12))
            end
            if presetRefs.selectedIcon then
                presetRefs.selectedIcon:Hide()
            end
        end
        button:SetEnabled(not self.skipUIScale)
    end

    if refs.recommendedText then
        refs.recommendedText:SetAlpha(self.skipUIScale and 0.55 or 1)
    end

    if refs.slider then
        refs.slider:SetEnabled(not self.skipUIScale)
        refs.slider:SetAlpha(self.skipUIScale and 0.45 or 1)
    end
end

function UI:_RefreshUIScaleSummary()
    local refs = self.uiScaleRefs
    if not refs then return end

    local value = math.max(0.64, math.min(1, tonumber(self.selectedUIScaleValue) or SetupWizardModule:GetAutoUIScale()))
    self.selectedUIScaleValue = value

    if refs.valueText then
        refs.valueText:SetText(string.format("%.2f", value))
    end
    if refs.summaryText then
        if self.skipUIScale then
            refs.summaryText:SetText("UI scale: skipped (current game value is unchanged).")
        elseif self.selectedUIScalePreset == "default" then
            refs.summaryText:SetText("UI scale: Default game value (1.00).")
        elseif self.selectedUIScalePreset == "auto" then
            refs.summaryText:SetText(string.format(
                "UI scale: Auto (recommended, calculated %.2f based on screen height).", value))
        else
            refs.summaryText:SetText(string.format("UI scale: Manual %.2f.", value))
        end
    end

    self:_RefreshUIScalePresetButtons()
end

function UI:_ApplyLiveUIScaleSelection()
    if self.skipUIScale then return end
    if self.selectedUIScalePreset == "auto" then
        SetupWizardModule:ApplyUIScale("auto")
    else
        SetupWizardModule:ApplyUIScale("manual", self.selectedUIScaleValue)
    end
end

function UI:_BuildUIScaleContent(sf)
    local x, y = PAD, -PAD

    local heading = NewText(sf, "UI Scale & Chat Setup", 20)
    heading:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local sub = NewText(sf,
        "Pick an initial UI scale preset or manual value. You can also skip scaling and still apply layout/theme.",
        12, C.muted[1], C.muted[2], C.muted[3])
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    sub:SetWidth(W - PAD * 2 - 2)

    local skipScale = NewTwichCheckbox(sf, "Skip UI Scale", self.skipUIScale)
    skipScale:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -18)

    local presetButtons = {}
    local prevButton = nil
    local buttonWidth = 96
    local buttonGap = 10
    local totalButtonWidth = (#UI_SCALE_PRESETS * buttonWidth) + ((#UI_SCALE_PRESETS - 1) * buttonGap)

    local presetRow = CreateFrame("Frame", nil, sf)
    presetRow:SetSize(totalButtonWidth, 30)
    presetRow:SetPoint("TOP", skipScale, "BOTTOM", 0, -18)
    local frameWidth = sf:GetWidth() or (W - 2)
    presetRow:SetPoint("LEFT", sf, "LEFT", math.floor((frameWidth - totalButtonWidth) / 2), 0)

    for index, preset in ipairs(UI_SCALE_PRESETS) do
        local btn, label = NewButton(sf, preset.label, 96, 30)
        label:SetFont(Font(12))
        if not prevButton then
            btn:SetPoint("TOPLEFT", presetRow, "TOPLEFT", 0, 0)
        else
            btn:SetPoint("LEFT", prevButton, "RIGHT", 10, 0)
        end
        btn:SetScript("OnClick", function()
            self.skipUIScale = false
            skipScale:SetChecked(false)
            self.selectedUIScalePreset = preset.id
            self.selectedUIScaleValue = ResolveUIScaleFromPreset(preset.id)
            if self.uiScaleRefs and self.uiScaleRefs.slider then
                self._updatingScaleSlider = true
                self.uiScaleRefs.slider:SetValue(self.selectedUIScaleValue)
                self._updatingScaleSlider = nil
            end
            self:_RefreshUIScaleSummary()
            self:_ApplyLiveUIScaleSelection()
        end)

        local selectedIcon = btn:CreateTexture(nil, "OVERLAY")
        selectedIcon:SetSize(12, 12)
        selectedIcon:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -4, -4)
        selectedIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        selectedIcon:Hide()

        local recommendedBadge = nil
        if preset.id == "auto" then
            recommendedBadge = btn:CreateFontString(nil, "OVERLAY")
            recommendedBadge:SetFont(Font(9, "OUTLINE"))
            recommendedBadge:SetText("REC")
            recommendedBadge:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
            recommendedBadge:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 3)
        end

        presetButtons[preset.id] = {
            button = btn,
            label = label,
            selectedIcon = selectedIcon,
            recommendedBadge = recommendedBadge,
        }
        prevButton = btn
    end

    local recommendedText = NewText(sf, "Auto is recommended for most setups.", 10, C.gold[1], C.gold[2], C.gold[3])
    recommendedText:SetPoint("TOPLEFT", presetRow, "BOTTOMLEFT", 0, -6)
    recommendedText:SetPoint("RIGHT", presetRow, "RIGHT", 0, 0)

    local slider = NewTwichSlider(sf, totalButtonWidth, 0.64, 1.00, 0.01, self.selectedUIScaleValue, "Manual UI Scale")
    slider:SetPoint("TOPLEFT", recommendedText, "BOTTOMLEFT", 0, -8)

    local valueText = NewText(sf, string.format("%.2f", self.selectedUIScaleValue), 12, C.gold[1], C.gold[2], C.gold[3])
    valueText:SetPoint("LEFT", slider, "RIGHT", 14, -11)

    slider:SetOnValueChanged(function(_, value)
        if self._updatingScaleSlider then return end
        self.selectedUIScaleValue = math.max(0.64, math.min(1, value))
        self.selectedUIScalePreset = "manual"
        self.skipUIScale = false
        skipScale:SetChecked(false)
        self:_RefreshUIScaleSummary()
        self:_ApplyLiveUIScaleSelection()
    end)

    skipScale:SetOnValueChanged(function(_, isChecked)
        self.skipUIScale = isChecked == true
        self:_RefreshUIScaleSummary()
        if not self.skipUIScale then
            self:_ApplyLiveUIScaleSelection()
        end
    end)

    local applyChat = NewTwichCheckbox(sf, "Apply Chat Setup from Layout", self.applyChatSetup ~= false)
    applyChat:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -2, -30)

    local chatNote = NewText(sf,
        "Recommended: enabled. Includes chat frame names, styling, and position data from your selected layout.",
        11, C.muted[1], C.muted[2], C.muted[3])
    chatNote:SetPoint("TOPLEFT", applyChat, "BOTTOMLEFT", 0, -6)
    chatNote:SetWidth(W - PAD * 2 - 2)

    applyChat:SetOnValueChanged(function(_, isChecked)
        self.applyChatSetup = isChecked == true
    end)

    local summaryText = NewText(sf, "", 11, C.muted[1], C.muted[2], C.muted[3])
    summaryText:SetPoint("TOPLEFT", chatNote, "BOTTOMLEFT", 0, -16)
    summaryText:SetWidth(W - PAD * 2 - 2)

    self.uiScaleRefs = {
        slider = slider,
        valueText = valueText,
        summaryText = summaryText,
        recommendedText = recommendedText,
        skipScale = skipScale,
        applyChat = applyChat,
        presetButtons = presetButtons,
    }

    self:_RefreshUIScaleSummary()
end

-- ─── Step 3 — Layout ─────────────────────────────────────────────────────────

local CARD_GAP   = 14
local CARD_H_LYT = 110

function UI:_BuildLayoutContent(sf)
    local x, y = PAD, -PAD

    local heading = NewText(sf, "Choose a Layout", 20)
    heading:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local sub = NewText(sf, "Positions scale automatically to your screen dimensions.", 12, C.muted[1], C.muted[2],
        C.muted[3])
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)

    local previewNote = NewText(sf,
        "Unit frame test mode is active on this step so party and raid placements are visible while you compare layouts.",
        11, C.gold[1], C.gold[2], C.gold[3])
    previewNote:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -7)
    previewNote:SetWidth(W - PAD * 2 - 2)

    local layouts       = SetupWizardModule:GetAvailableLayouts()
    local availW        = W - 2 - PAD * 2
    local cols          = math.min(2, #layouts)
    local cardW         = (availW - CARD_GAP * (cols - 1)) / cols

    self.layoutCardRefs = {}

    for i, layout in ipairs(layouts) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        local card = CreateFrame("Frame", nil, sf, "BackdropTemplate")
        card:SetSize(cardW, CARD_H_LYT)
        card:SetPoint("TOPLEFT", sf, "TOPLEFT",
            x + col * (cardW + CARD_GAP),
            y - 82 - row * (CARD_H_LYT + CARD_GAP))

        local nameText = NewText(card, layout.name, 15, C.text[1], C.text[2], C.text[3])
        nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -16)

        local roleText = NewText(card, (layout.role or "any"):upper(), 10, C.gold[1], C.gold[2], C.gold[3])
        roleText:SetFont(Font(10, "OUTLINE"))
        roleText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -4)

        local descText = NewText(card, layout.description or "", 11, C.muted[1], C.muted[2], C.muted[3])
        descText:SetPoint("TOPLEFT", roleText, "BOTTOMLEFT", 0, -7)
        descText:SetWidth(cardW - 34)

        local checkMark = NewText(card, "", 14, C.teal[1], C.teal[2], C.teal[3], "CENTER")
        checkMark:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -13)

        self.layoutCardRefs[layout.id] = { card = card, nameText = nameText, checkMark = checkMark }

        local layoutId = layout.id
        card:EnableMouse(true)
        card:SetScript("OnMouseUp", function()
            self.selectedLayout = layoutId
            self:_RefreshLayoutCards()
            -- Apply layout live so user can see preview
            SetupWizardModule:ApplyLayout(layoutId, {
                applyChat = self.applyChatSetup ~= false,
            })
            if self.selectedTheme then
                SetupWizardModule:ApplyThemePreset(self.selectedTheme)
            end
            if self._SyncFontSizeStateFromConfig then
                self:_SyncFontSizeStateFromConfig(false)
            end
        end)
        card:SetScript("OnEnter", function()
            if self.selectedLayout ~= layoutId then
                card:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.55)
            end
        end)
        card:SetScript("OnLeave", function()
            if self.selectedLayout ~= layoutId then
                card:SetBackdropBorderColor(C.cardBdr[1], C.cardBdr[2], C.cardBdr[3], 0.8)
            end
        end)
    end

    -- Seed initial selection state
    self:_RefreshLayoutCards()

    -- Apply the current selection immediately so defaults (including fonts)
    -- always reflect the selected layout before later wizard steps.
    if self.selectedLayout and SetupWizardModule:GetLayout(self.selectedLayout) then
        SetupWizardModule:ApplyLayout(self.selectedLayout, {
            applyChat = self.applyChatSetup ~= false,
        })
        if self.selectedTheme then
            SetupWizardModule:ApplyThemePreset(self.selectedTheme)
        end
        if self._SyncFontSizeStateFromConfig then
            self:_SyncFontSizeStateFromConfig(false)
        end
    end

    -- "More layouts coming" note when there's only one
    if #layouts == 1 then
        local hint = NewText(sf, "Additional role-specific layouts will be available in future updates.", 11, C.muted[1],
            C.muted[2], C.muted[3])
        local firstCard = self.layoutCardRefs[layouts[1].id]
        if firstCard then
            hint:SetPoint("TOPLEFT", firstCard.card, "BOTTOMLEFT", 0, -12)
        end
    end
end

function UI:_SyncFontSizeStateFromConfig(applyPreview)
    local configModule = T:GetModule("Configuration", true)
    local options = configModule and configModule.Options or nil
    if not options then
        return
    end

    local chatSize = self.chatFontSize or 11
    local headerSize = self.chatHeaderFontSize or chatSize
    local datatextSize = self.datatextFontSize or 11

    local chatOpts = options.ChatEnhancement
    if chatOpts and type(chatOpts.GetChatEnhancementDB) == "function" then
        local chatDB = chatOpts:GetChatEnhancementDB()
        if chatDB then
            chatSize = tonumber(chatDB.chatFontSize) or chatSize
            headerSize = tonumber(chatDB.tabFontSize) or headerSize
            local hdt = chatDB.headerDatatext
            if type(hdt) == "table" and hdt.fontSize ~= nil then
                headerSize = tonumber(hdt.fontSize) or headerSize
            end
        end
    end

    local datatextOpts = options.Datatext
    if datatextOpts and type(datatextOpts.GetStandaloneDB) == "function" then
        local standaloneDB = datatextOpts:GetStandaloneDB()
        if standaloneDB and type(standaloneDB.style) == "table" then
            datatextSize = tonumber(standaloneDB.style.fontSize) or datatextSize
        end
    end

    self.chatFontSize = math.floor(chatSize + 0.5)
    self.chatHeaderFontSize = math.floor(headerSize + 0.5)
    self.datatextFontSize = math.floor(datatextSize + 0.5)

    if applyPreview then
        SetupWizardModule:ApplyFontSizes({
            chatFontSize = self.chatFontSize,
            chatHeaderFontSize = self.chatHeaderFontSize,
            datatextFontSize = self.datatextFontSize,
        })
    end
end

function UI:_RefreshLayoutCards()
    for id, refs in pairs(self.layoutCardRefs) do
        local sel = (self.selectedLayout == id)
        if sel then
            Backdrop(refs.card, C.cardSel, C.teal, 1, 1)
            refs.nameText:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
            refs.checkMark:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t")
        else
            Backdrop(refs.card, C.cardBg, C.cardBdr, 1, 0.8)
            refs.nameText:SetTextColor(C.text[1], C.text[2], C.text[3])
            refs.checkMark:SetText("")
        end
    end
end

-- ─── Step 4 — Unit Frames ───────────────────────────────────────────────────

function UI:_RefreshUnitFrameSummary()
    local refs = self.unitFrameRefs
    if not refs then return end

    local info = self.elvuiConflictInfo or { available = false, unitFramesEnabled = false }
    local ownerText = self.useTwichUnitFrames ~= false and "TwichUI" or "ElvUI"

    if refs.infoText then
        if info.available then
            local availability = info.unitFramesEnabled and "ElvUI unit frames are currently enabled." or
                "ElvUI is installed, but its unit frames are already disabled."
            local reloadText = self:_NeedsUnitFrameConflictReload() and
                "Choosing TwichUI will reload once here, then resume the wizard on the next step." or
                "No extra reload is needed for your current choice."
            refs.infoText:SetText(string.format("%s\nOwner: %s\n%s", availability, ownerText, reloadText))
        else
            refs.infoText:SetText("ElvUI unit frames were not detected. TwichUI unit frames will be configured here.")
        end
    end

    if refs.partyPlayer then
        refs.partyPlayer:SetAlpha((self.useTwichUnitFrames ~= false) and 1 or 0.45)
        refs.partyPlayer:EnableMouse(self.useTwichUnitFrames ~= false)
    end
    if refs.partyCastbars then
        refs.partyCastbars:SetAlpha((self.useTwichUnitFrames ~= false) and 1 or 0.45)
        refs.partyCastbars:EnableMouse(self.useTwichUnitFrames ~= false)
    end
end

function UI:_BuildUnitFramesContent(sf)
    local x, y = PAD, -PAD
    local info = self.elvuiConflictInfo or { available = false, unitFramesEnabled = false }

    local heading = NewText(sf, "Unit Frames", 20)
    heading:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local sub = NewText(sf,
        "Choose who owns unit frames after your layout is applied, then set a couple of party-frame defaults.",
        12, C.muted[1], C.muted[2], C.muted[3])
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    sub:SetWidth(W - PAD * 2 - 2)

    local infoText = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    infoText:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -18)
    infoText:SetWidth(W - PAD * 2 - 2)

    local ownerCard = CreateFrame("Frame", nil, sf, "BackdropTemplate")
    ownerCard:SetSize(W - PAD * 2, 92)
    ownerCard:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -16)
    Backdrop(ownerCard, C.bg, C.border, 0.5, 0.6)

    local ownerTitle = NewText(ownerCard, "Unit Frame Owner", 11, C.gold[1], C.gold[2], C.gold[3])
    ownerTitle:SetPoint("TOPLEFT", ownerCard, "TOPLEFT", 10, -8)

    local twichBtn, twichLabel = NewButton(ownerCard, "TwichUI", 140, 30)
    twichBtn:SetPoint("TOPLEFT", ownerTitle, "BOTTOMLEFT", 0, -12)
    local elvBtn, elvLabel = NewButton(ownerCard, "ElvUI", 120, 30)
    elvBtn:SetPoint("LEFT", twichBtn, "RIGHT", 12, 0)

    local function RefreshOwnerButtons()
        local useTwich = self.useTwichUnitFrames ~= false
        if useTwich then
            twichBtn:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.55)
            twichBtn:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.9)
            elvBtn:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
            elvBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        else
            elvBtn:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.55)
            elvBtn:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.9)
            twichBtn:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
            twichBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
        end
        twichLabel:SetTextColor(C.text[1], C.text[2], C.text[3])
        elvLabel:SetTextColor(C.text[1], C.text[2], C.text[3])
        self:_RefreshUnitFrameSummary()
    end

    twichBtn:SetScript("OnClick", function()
        self.useTwichUnitFrames = true
        RefreshOwnerButtons()
    end)
    elvBtn:SetScript("OnClick", function()
        self.useTwichUnitFrames = false
        RefreshOwnerButtons()
    end)

    if not info.available then
        elvBtn:Disable()
        elvBtn:SetAlpha(0.45)
        self.useTwichUnitFrames = true
    end

    local optionsCard = CreateFrame("Frame", nil, sf, "BackdropTemplate")
    optionsCard:SetSize(W - PAD * 2, 104)
    optionsCard:SetPoint("TOPLEFT", ownerCard, "BOTTOMLEFT", 0, -10)
    Backdrop(optionsCard, C.bg, C.border, 0.5, 0.6)

    local optionsTitle = NewText(optionsCard, "Party Defaults", 11, C.gold[1], C.gold[2], C.gold[3])
    optionsTitle:SetPoint("TOPLEFT", optionsCard, "TOPLEFT", 10, -8)

    local partyPlayer = NewTwichCheckbox(optionsCard, "Show yourself in party frames", self.showPlayerInParty ~= false)
    partyPlayer:SetPoint("TOPLEFT", optionsTitle, "BOTTOMLEFT", 0, -14)
    partyPlayer:SetOnValueChanged(function(_, isChecked)
        self.showPlayerInParty = isChecked == true
    end)

    local partyCastbars = NewTwichCheckbox(optionsCard, "Show party member cast bars", self.showPartyCastbars ~= false)
    partyCastbars:SetPoint("TOPLEFT", partyPlayer, "BOTTOMLEFT", 0, -10)
    partyCastbars:SetOnValueChanged(function(_, isChecked)
        self.showPartyCastbars = isChecked == true
    end)

    local note = NewText(optionsCard,
        "These defaults apply to TwichUI unit frames. If you pick ElvUI here, the toggles are stored but stay inactive until you switch back.",
        11, C.muted[1], C.muted[2], C.muted[3])
    note:SetPoint("TOPLEFT", partyCastbars, "BOTTOMLEFT", 0, -8)
    note:SetWidth(W - PAD * 2 - 26)

    self.unitFrameRefs = {
        infoText = infoText,
        partyPlayer = partyPlayer,
        partyCastbars = partyCastbars,
    }

    RefreshOwnerButtons()
end

-- ─── Step 5 — Theme ──────────────────────────────────────────────────────────

local CARD_H_THM = 96

function UI:_BuildThemeContent(sf)
    local x, y = PAD, -PAD

    local heading = NewText(sf, "Choose a Theme", 20)
    heading:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local sub = NewText(sf, "Changes apply live so you can preview instantly. Fine-tune further in Appearance settings.",
        12, C.muted[1], C.muted[2], C.muted[3])
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    sub:SetWidth(W - PAD * 2 - 2)

    local presets      = SetupWizardModule:GetThemePresets()
    local availW       = W - 2 - PAD * 2
    local cols         = 2
    local cardW        = (availW - CARD_GAP * (cols - 1)) / cols

    self.themeCardRefs = {}

    for i, preset in ipairs(presets) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)

        local card = CreateFrame("Frame", nil, sf, "BackdropTemplate")
        card:SetSize(cardW, CARD_H_THM)
        card:SetPoint("TOPLEFT", sf, "TOPLEFT",
            x + col * (cardW + CARD_GAP),
            y - 52 - row * (CARD_H_THM + CARD_GAP))

        -- Color swatches
        local swatchColors = {
            ResolvePresetSwatchColor(preset, "primaryColor"),
            ResolvePresetSwatchColor(preset, "accentColor"),
            ResolvePresetSwatchColor(preset, "backgroundColor"),
        }
        for si, sc in ipairs(swatchColors) do
            local sw = CreateFrame("Frame", nil, card, "BackdropTemplate")
            sw:SetSize(20, 20)
            sw:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (si - 1) * 26, -14)
            Backdrop(sw, { sc[1], sc[2], sc[3] }, { 0, 0, 0 }, 1, 0.4)
        end

        -- Name & description to the right of swatches
        local nameText = NewText(card, preset.name, 13, C.text[1], C.text[2], C.text[3])
        nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 100, -16)

        local descValue = preset.description or ""
        if preset.useClassColor == true then
            descValue = (descValue ~= "" and (descValue .. " ") or "") .. "(Uses your class color)"
        end
        local descText = NewText(card, descValue, 11, C.muted[1], C.muted[2], C.muted[3])
        descText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -5)
        descText:SetWidth(cardW - 116)

        local checkMark = NewText(card, "", 14, C.teal[1], C.teal[2], C.teal[3], "CENTER")
        checkMark:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -12)

        self.themeCardRefs[preset.id] = { card = card, checkMark = checkMark }

        local presetId = preset.id
        card:EnableMouse(true)
        card:SetScript("OnMouseUp", function()
            self.selectedTheme = presetId
            SetupWizardModule:ApplyThemePreset(presetId)
            self:_RefreshThemeCards()
        end)
        card:SetScript("OnEnter", function()
            if self.selectedTheme ~= presetId then
                card:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.5)
            end
        end)
        card:SetScript("OnLeave", function()
            if self.selectedTheme ~= presetId then
                card:SetBackdropBorderColor(C.cardBdr[1], C.cardBdr[2], C.cardBdr[3], 0.8)
            end
        end)
    end

    self:_RefreshThemeCards()
end

function UI:_RefreshThemeCards()
    for id, refs in pairs(self.themeCardRefs) do
        local sel = (self.selectedTheme == id)
        if sel then
            Backdrop(refs.card, C.cardSel, C.teal, 1, 1)
            refs.checkMark:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t")
        else
            Backdrop(refs.card, C.cardBg, C.cardBdr, 1, 0.8)
            refs.checkMark:SetText("")
        end
    end
end

-- ─── Step 5 — ElvUI conflicts ───────────────────────────────────────────────

function UI:_RefreshElvUIConflictSummary()
    local refs = self.elvuiRefs
    if not refs then return end
    local info = self.elvuiConflictInfo or { available = false }

    if not info.available then
        if refs.infoText then
            refs.infoText:SetText("ElvUI is not loaded. This step is skipped automatically.")
        end
        return
    end

    local chatModule = info.chatEnabled and "Chat" or ""
    local dtModule = info.datatextEnabled and "Datatext" or ""
    local availableModules = {}
    if chatModule ~= "" then table.insert(availableModules, chatModule) end
    if dtModule ~= "" then table.insert(availableModules, dtModule) end
    local availableText = table.concat(availableModules, ", ")

    local ownerChat = self.useTwichChat and "TwichUI" or "ElvUI"
    local ownerDatatext = self.useTwichDatatext and "TwichUI" or "ElvUI"

    if refs.infoText then
        refs.infoText:SetText(string.format(
            "Available: %s\nYour choice: Chat uses %s, Datatext uses %s",
            availableText, ownerChat, ownerDatatext))
    end
end

-- ─── Step 5 — Font Sizes ────────────────────────────────────────────────────

function UI:_BuildFontSizeContent(sf)
    local x, y = PAD, -PAD

    local heading = NewText(sf, "Font Sizes", 20)
    heading:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local sub = NewText(sf,
        "Adjust font sizes for chat and datatexts. Use the test button to preview changes.",
        11, C.muted[1], C.muted[2], C.muted[3])
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    sub:SetWidth(W - PAD * 2 - 2)

    -- ─── Chat Messages Section ──────────────────────────────────────────────

    local chatSection = CreateFrame("Frame", nil, sf, "BackdropTemplate")
    chatSection:SetSize(W - PAD * 2, 100)
    chatSection:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -10)
    chatSection:SetClipsChildren(true)
    Backdrop(chatSection, C.bg, C.border, 0.5, 0.6)

    local chatTitle = NewText(chatSection, "Chat Messages", 11, C.gold[1], C.gold[2], C.gold[3])
    chatTitle:SetPoint("TOPLEFT", chatSection, "TOPLEFT", 10, -6)

    local chatLabel = NewText(chatSection, "Font Size", 10, C.text[1], C.text[2], C.text[3])
    chatLabel:SetPoint("TOPLEFT", chatTitle, "BOTTOMLEFT", 0, -6)

    local chatSlider = NewTwichSlider(chatSection, 140, 8, 16, 1, self.chatFontSize)
    chatSlider:SetPoint("TOPLEFT", chatLabel, "BOTTOMLEFT", 0, -3)

    local chatValue = NewText(chatSection, tostring(self.chatFontSize), 11, C.gold[1], C.gold[2], C.gold[3])
    chatValue:SetPoint("LEFT", chatSlider, "RIGHT", 8, -4)

    -- Test button inline with chat section
    local testBtn, testLabel = NewButton(sf, "Test in Chat", 110, 22)
    testBtn:SetPoint("TOPRIGHT", chatSection, "TOPRIGHT", -10, -6)
    testLabel:SetFont(Font(10))

    chatSlider:SetOnValueChanged(function(_, value)
        self.chatFontSize = math.floor(value)
        chatValue:SetText(tostring(self.chatFontSize))
        SetupWizardModule:ApplyFontSizes({
            chatFontSize = self.chatFontSize,
            chatHeaderFontSize = self.chatHeaderFontSize,
            datatextFontSize = self.datatextFontSize,
        })
    end)

    testBtn:SetScript("OnClick", function()
        local messages = {
            "By Elune's grace, these fonts are perfect!",
            "For the Alliance... and readable text!",
            "For the Horde... and readable text!",
            "This font size is LEGENDARY!",
            "Your UI is now over 9000!",
            "Time to clear Mythic+ in style.",
            "Raid night just got better.",
            "Perfectly sized for parsing.",
            "No more squinting at chat!",
            "This is the way.",
        }
        local msg = messages[math.random(#messages)]
        local chatModule = T:GetModule("ChatEnhancements", true)
        if chatModule and type(chatModule.PrintToChat) == "function" then
            chatModule:PrintToChat(msg)
        else
            print("|cff19c9c7TwichUI|r: " .. msg)
        end
    end)

    -- ─── Chat Header Section ────────────────────────────────────────────────

    local headerSection = CreateFrame("Frame", nil, sf, "BackdropTemplate")
    headerSection:SetSize(W - PAD * 2, 95)
    headerSection:SetPoint("TOPLEFT", chatSection, "BOTTOMLEFT", 0, -4)
    headerSection:SetClipsChildren(true)
    Backdrop(headerSection, C.bg, C.border, 0.5, 0.6)

    local headerTitle = NewText(headerSection, "Chat Header", 11, C.gold[1], C.gold[2], C.gold[3])
    headerTitle:SetPoint("TOPLEFT", headerSection, "TOPLEFT", 10, -6)

    local hdrLabel = NewText(headerSection, "Font Size", 10, C.text[1], C.text[2], C.text[3])
    hdrLabel:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -6)

    local headerSlider = NewTwichSlider(headerSection, 140, 8, 16, 1, self.chatHeaderFontSize)
    headerSlider:SetPoint("TOPLEFT", hdrLabel, "BOTTOMLEFT", 0, -3)

    local headerValue = NewText(headerSection, tostring(self.chatHeaderFontSize), 11, C.gold[1], C.gold[2], C.gold[3])
    headerValue:SetPoint("LEFT", headerSlider, "RIGHT", 8, -4)

    headerSlider:SetOnValueChanged(function(_, value)
        self.chatHeaderFontSize = math.floor(value)
        headerValue:SetText(tostring(self.chatHeaderFontSize))
        SetupWizardModule:ApplyFontSizes({
            chatFontSize = self.chatFontSize,
            chatHeaderFontSize = self.chatHeaderFontSize,
            datatextFontSize = self.datatextFontSize,
        })
    end)

    -- ─── Datatexts Section ──────────────────────────────────────────────────

    local dtSection = CreateFrame("Frame", nil, sf, "BackdropTemplate")
    dtSection:SetSize(W - PAD * 2, 95)
    dtSection:SetPoint("TOPLEFT", headerSection, "BOTTOMLEFT", 0, -4)
    dtSection:SetClipsChildren(true)
    Backdrop(dtSection, C.bg, C.border, 0.5, 0.6)

    local dtTitle = NewText(dtSection, "Datatexts", 11, C.gold[1], C.gold[2], C.gold[3])
    dtTitle:SetPoint("TOPLEFT", dtSection, "TOPLEFT", 10, -6)

    local dtLabel = NewText(dtSection, "Font Size", 10, C.text[1], C.text[2], C.text[3])
    dtLabel:SetPoint("TOPLEFT", dtTitle, "BOTTOMLEFT", 0, -6)

    local dtSlider = NewTwichSlider(dtSection, 140, 8, 16, 1, self.datatextFontSize)
    dtSlider:SetPoint("TOPLEFT", dtLabel, "BOTTOMLEFT", 0, -3)

    local dtValue = NewText(dtSection, tostring(self.datatextFontSize), 11, C.gold[1], C.gold[2], C.gold[3])
    dtValue:SetPoint("LEFT", dtSlider, "RIGHT", 8, -4)

    dtSlider:SetOnValueChanged(function(_, value)
        self.datatextFontSize = math.floor(value)
        dtValue:SetText(tostring(self.datatextFontSize))
        SetupWizardModule:ApplyFontSizes({
            chatFontSize = self.chatFontSize,
            chatHeaderFontSize = self.chatHeaderFontSize,
            datatextFontSize = self.datatextFontSize,
        })
    end)

    self.fontSizeRefs = {
        chatSlider = chatSlider,
        chatValue = chatValue,
        headerSlider = headerSlider,
        headerValue = headerValue,
        dtSlider = dtSlider,
        dtValue = dtValue,
        testBtn = testBtn,
    }
end

function UI:_RefreshFontSizeSliders()
    local refs = self.fontSizeRefs
    if not refs then return end

    if refs.chatSlider then
        refs.chatSlider:SetValue(self.chatFontSize)
    end
    if refs.chatValue then
        refs.chatValue:SetText(tostring(self.chatFontSize))
    end
    if refs.headerSlider then
        refs.headerSlider:SetValue(self.chatHeaderFontSize)
    end
    if refs.headerValue then
        refs.headerValue:SetText(tostring(self.chatHeaderFontSize))
    end
    if refs.dtSlider then
        refs.dtSlider:SetValue(self.datatextFontSize)
    end
    if refs.dtValue then
        refs.dtValue:SetText(tostring(self.datatextFontSize))
    end
end

-- ─── Step 6 — ElvUI ──────────────────────────────────────────────────────────

function UI:_BuildElvUIContent(sf)
    local x, y = PAD, -PAD
    local info = self.elvuiConflictInfo or { available = false }

    local heading = NewText(sf, "Choose Your UI Modules", 20)
    heading:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local sub = NewText(sf,
        "You have both TwichUI and ElvUI enabled. Select which one to use for each feature.",
        12, C.muted[1], C.muted[2], C.muted[3])
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    sub:SetWidth(W - PAD * 2 - 2)

    local infoText = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    infoText:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -16)
    infoText:SetWidth(W - PAD * 2 - 2)

    if info.available then
        local chatRow = CreateFrame("Frame", nil, sf)
        chatRow:SetSize(W - PAD * 2 - 2, 36)
        chatRow:SetPoint("TOPLEFT", infoText, "BOTTOMLEFT", 0, -18)

        local chatLabel = NewText(chatRow, "Chat", 12)
        chatLabel:SetPoint("LEFT", chatRow, "LEFT", 0, 0)
        local chatTwich = NewButton(chatRow, "TwichUI", 120, 28)
        chatTwich:SetPoint("LEFT", chatLabel, "RIGHT", 20, 0)
        local chatElv = NewButton(chatRow, "ElvUI", 110, 28)
        chatElv:SetPoint("LEFT", chatTwich, "RIGHT", 10, 0)

        local function RefreshChatButtons()
            local useTwich = self.useTwichChat ~= false
            if useTwich then
                chatTwich:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.55)
                chatTwich:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.9)
                chatElv:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
                chatElv:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
            else
                chatElv:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.55)
                chatElv:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.9)
                chatTwich:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
                chatTwich:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
            end
        end

        chatTwich:SetScript("OnClick", function()
            self.useTwichChat = true
            RefreshChatButtons()
            self:_RefreshElvUIConflictSummary()
        end)
        chatElv:SetScript("OnClick", function()
            self.useTwichChat = false
            RefreshChatButtons()
            self:_RefreshElvUIConflictSummary()
        end)

        local dtRow = CreateFrame("Frame", nil, sf)
        dtRow:SetSize(W - PAD * 2 - 2, 36)
        dtRow:SetPoint("TOPLEFT", chatRow, "BOTTOMLEFT", 0, -12)

        local dtLabel = NewText(dtRow, "Datatext", 12)
        dtLabel:SetPoint("LEFT", dtRow, "LEFT", 0, 0)
        local dtTwich = NewButton(dtRow, "TwichUI", 120, 28)
        dtTwich:SetPoint("LEFT", dtLabel, "RIGHT", 20, 0)
        local dtElv = NewButton(dtRow, "ElvUI", 110, 28)
        dtElv:SetPoint("LEFT", dtTwich, "RIGHT", 10, 0)

        local function RefreshDatatextButtons()
            local useTwich = self.useTwichDatatext ~= false
            if useTwich then
                dtTwich:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.55)
                dtTwich:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.9)
                dtElv:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
                dtElv:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
            else
                dtElv:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.55)
                dtElv:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.9)
                dtTwich:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.12)
                dtTwich:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.5)
            end
        end

        dtTwich:SetScript("OnClick", function()
            self.useTwichDatatext = true
            RefreshDatatextButtons()
            self:_RefreshElvUIConflictSummary()
        end)
        dtElv:SetScript("OnClick", function()
            self.useTwichDatatext = false
            RefreshDatatextButtons()
            self:_RefreshElvUIConflictSummary()
        end)

        if not info.chatEnabled then
            chatElv:Disable()
            chatElv:SetAlpha(0.5)
            self.useTwichChat = true
        end
        if not info.datatextEnabled then
            dtElv:Disable()
            dtElv:SetAlpha(0.5)
            self.useTwichDatatext = true
        end

        RefreshChatButtons()
        RefreshDatatextButtons()
    else
        self.useTwichChat = true
        self.useTwichDatatext = true
    end

    self.elvuiRefs = {
        infoText = infoText,
    }
    self:_RefreshElvUIConflictSummary()
end

-- ─── Step 6 — Finish ─────────────────────────────────────────────────────────

function UI:_BuildFinishContent(sf)
    local x, y = PAD, -PAD * 0.5

    local check = NewText(sf, "|TInterface\\RaidFrame\\ReadyCheck-Ready:32:32:0:0|t", 22)
    check:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local heading = NewText(sf, "You're all set!", 22, C.text[1], C.text[2], C.text[3])
    heading:SetPoint("LEFT", check, "RIGHT", 16, 1)

    -- Summary labels — stored as refs so they can be refreshed
    local layoutLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    layoutLabel:SetPoint("TOPLEFT", sf, "TOPLEFT", x, -86)

    local themeLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    themeLabel:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -8)

    local uiScaleLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    uiScaleLabel:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", 0, -8)

    local chatLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    chatLabel:SetPoint("TOPLEFT", uiScaleLabel, "BOTTOMLEFT", 0, -8)

    local integrationLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    integrationLabel:SetPoint("TOPLEFT", chatLabel, "BOTTOMLEFT", 0, -8)

    local unitFrameLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    unitFrameLabel:SetPoint("TOPLEFT", integrationLabel, "BOTTOMLEFT", 0, -8)

    local resLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    resLabel:SetPoint("TOPLEFT", unitFrameLabel, "BOTTOMLEFT", 0, -8)

    local note = NewText(sf,
        "Your layout and theme have been applied.\n" ..
        "Open the configuration panel any time via |cff19c9c7/tui|r or by clicking the TwichUI datatext.",
        12, C.muted[1], C.muted[2], C.muted[3])
    note:SetPoint("TOPLEFT", resLabel, "BOTTOMLEFT", 0, -22)
    note:SetWidth(W - PAD * 2 - 2)

    self.finishRefs = {
        layoutLabel = layoutLabel,
        themeLabel = themeLabel,
        uiScaleLabel = uiScaleLabel,
        chatLabel = chatLabel,
        integrationLabel = integrationLabel,
        unitFrameLabel = unitFrameLabel,
        resLabel = resLabel,
    }
    self:_RefreshFinishSummary()
end

function UI:_RefreshFinishSummary()
    local refs = self.finishRefs
    if not refs or not refs.layoutLabel then return end

    local layout = SetupWizardModule:GetLayout(self.selectedLayout)
    local theme  = SetupWizardModule:GetThemePreset(self.selectedTheme)
    local sw, sh = SetupWizardModule:GetScreenDimensions()
    local uiScaleText
    if self.skipUIScale then
        uiScaleText = "Skipped"
    elseif self.selectedUIScalePreset == "default" then
        uiScaleText = "Default (1.00)"
    elseif self.selectedUIScalePreset == "auto" then
        uiScaleText = string.format("Auto (%.2f)", self.selectedUIScaleValue or SetupWizardModule:GetAutoUIScale())
    else
        uiScaleText = string.format("Manual (%.2f)", self.selectedUIScaleValue or 0.8)
    end

    refs.layoutLabel:SetText(string.format("|cff787c88Layout  |r%s", layout and layout.name or "—"))
    refs.themeLabel:SetText(string.format("|cff787c88Theme   |r%s", theme and theme.name or "—"))
    refs.uiScaleLabel:SetText(string.format("|cff787c88UI Scale|r%s", uiScaleText))
    refs.chatLabel:SetText(string.format("|cff787c88Chat    |r%s",
        self.applyChatSetup ~= false and "Apply setup" or "Skip setup"))
    if self.elvuiConflictInfo and self.elvuiConflictInfo.available then
        refs.integrationLabel:SetText(string.format("|cff787c88ElvUI   |rChat: %s, Datatext: %s",
            self.useTwichChat and "TwichUI" or "ElvUI",
            self.useTwichDatatext and "TwichUI" or "ElvUI"))
    else
        refs.integrationLabel:SetText("|cff787c88ElvUI   |rNot detected")
    end
    if refs.unitFrameLabel then
        refs.unitFrameLabel:SetText(string.format("|cff787c88Frames  |r%s  |  Party Self: %s  |  Party Casts: %s",
            self.useTwichUnitFrames and "TwichUI" or "ElvUI",
            self.showPlayerInParty and "On" or "Off",
            self.showPartyCastbars and "On" or "Off"))
    end
    refs.resLabel:SetText(string.format("|cff787c88Screen  |r%dx%d", sw, sh))
end
