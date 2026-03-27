---@diagnostic disable: undefined-field, inject-field
--[[
    TwichUI Setup Wizard — Visual UI

    A multi-step modal wizard frame. Steps are:
      1  Welcome  — brand greeting and feature overview
      2  Layout   — choose a pre-defined layout  (cards sourced from Layouts.lua)
      3  Theme    — choose a color preset        (cards sourced from Layouts.lua)
      4  Finish   — summary and apply

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
    { id = "welcome", title = "Welcome" },
    { id = "layout",  title = "Layout" },
    { id = "theme",   title = "Theme" },
    { id = "finish",  title = "Finish" },
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
            refs.dotText:SetFont(Font(13))
            refs.dotText:SetText("v")
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

function UI:_GoNext()
    if self.currentStep < #STEP_DEFS then
        self:_GoToStep(self.currentStep + 1)
    else
        -- Mark complete FIRST so that even if ApplyLayout errors mid-way, the wizard
        -- does not re-appear on the next reload.
        SetupWizardModule:MarkComplete()
        SetupWizardModule:ApplyLayout(self.selectedLayout)
        self:_Close()
        -- Prompt for a reload so the restored DB settings take full effect.
        local CM = T:GetModule("Configuration", true)
        if CM and type(CM.PromptToReloadUI) == "function" then
            CM:PromptToReloadUI()
        end
    end
end

function UI:_GoBack()
    if self.currentStep > 1 then
        self:_GoToStep(self.currentStep - 1)
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

    -- Build the step content on first visit, then just refresh dynamic pieces
    local sf = self.stepFrames[n]
    if not self.stepBuilt[n] then
        self.stepBuilt[n] = true
        local builders = {
            [1] = UI._BuildWelcomeContent,
            [2] = UI._BuildLayoutContent,
            [3] = UI._BuildThemeContent,
            [4] = UI._BuildFinishContent,
        }
        if builders[n] then builders[n](self, sf) end
    else
        -- Refresh live-selection state without a full rebuild
        if n == 2 then self:_RefreshLayoutCards() end
        if n == 3 then self:_RefreshThemeCards() end
        if n == 4 then self:_RefreshFinishSummary() end
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
    self.selectedLayout = "standard"
    self.selectedTheme  = "twich_default"
    -- Clear prior build state so steps rebuild with fresh data
    self.stepBuilt      = {}
    self.layoutCardRefs = {}
    self.themeCardRefs  = {}
    self.finishRefs     = {}
    self:_RenderStep(1)

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

function UI:_Close()
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

-- ─── Step 2 — Layout ─────────────────────────────────────────────────────────

local CARD_GAP   = 14
local CARD_H_LYT = 110

function UI:_BuildLayoutContent(sf)
    local x, y = PAD, -PAD

    local heading = NewText(sf, "Choose a Layout", 20)
    heading:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local sub = NewText(sf, "Positions scale automatically to your screen dimensions.", 12, C.muted[1], C.muted[2],
        C.muted[3])
    sub:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)

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
            y - 54 - row * (CARD_H_LYT + CARD_GAP))

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

function UI:_RefreshLayoutCards()
    for id, refs in pairs(self.layoutCardRefs) do
        local sel = (self.selectedLayout == id)
        if sel then
            Backdrop(refs.card, C.cardSel, C.teal, 1, 1)
            refs.nameText:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
            refs.checkMark:SetText("✓")
        else
            Backdrop(refs.card, C.cardBg, C.cardBdr, 1, 0.8)
            refs.nameText:SetTextColor(C.text[1], C.text[2], C.text[3])
            refs.checkMark:SetText("")
        end
    end
end

-- ─── Step 3 — Theme ──────────────────────────────────────────────────────────

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
        local swatchColors = { preset.primaryColor, preset.accentColor, preset.backgroundColor }
        for si, sc in ipairs(swatchColors) do
            local sw = CreateFrame("Frame", nil, card, "BackdropTemplate")
            sw:SetSize(20, 20)
            sw:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + (si - 1) * 26, -14)
            Backdrop(sw, { sc[1], sc[2], sc[3] }, { 0, 0, 0 }, 1, 0.4)
        end

        -- Name & description to the right of swatches
        local nameText = NewText(card, preset.name, 13, C.text[1], C.text[2], C.text[3])
        nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 100, -16)

        local descText = NewText(card, preset.description or "", 11, C.muted[1], C.muted[2], C.muted[3])
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
            refs.checkMark:SetText("✓")
        else
            Backdrop(refs.card, C.cardBg, C.cardBdr, 1, 0.8)
            refs.checkMark:SetText("")
        end
    end
end

-- ─── Step 4 — Finish ─────────────────────────────────────────────────────────

function UI:_BuildFinishContent(sf)
    local x, y = PAD, -PAD * 1.4

    local check = NewText(sf, "|cff19c9c7✓|r", 42)
    check:SetPoint("TOPLEFT", sf, "TOPLEFT", x, y)

    local heading = NewText(sf, "You're all set!", 22, C.text[1], C.text[2], C.text[3])
    heading:SetPoint("LEFT", check, "RIGHT", 16, 1)

    -- Summary labels — stored as refs so they can be refreshed
    local layoutLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    layoutLabel:SetPoint("TOPLEFT", sf, "TOPLEFT", x, -86)

    local themeLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    themeLabel:SetPoint("TOPLEFT", layoutLabel, "BOTTOMLEFT", 0, -8)

    local resLabel = NewText(sf, "", 12, C.text[1], C.text[2], C.text[3])
    resLabel:SetPoint("TOPLEFT", themeLabel, "BOTTOMLEFT", 0, -8)

    local note = NewText(sf,
        "Your layout and theme have been applied.\n" ..
        "Open the configuration panel any time via |cff19c9c7/tui|r or the AddOns compartment.",
        12, C.muted[1], C.muted[2], C.muted[3])
    note:SetPoint("TOPLEFT", resLabel, "BOTTOMLEFT", 0, -22)
    note:SetWidth(W - PAD * 2 - 2)

    self.finishRefs = { layoutLabel = layoutLabel, themeLabel = themeLabel, resLabel = resLabel }
    self:_RefreshFinishSummary()
end

function UI:_RefreshFinishSummary()
    local refs = self.finishRefs
    if not refs or not refs.layoutLabel then return end

    local layout = SetupWizardModule:GetLayout(self.selectedLayout)
    local theme  = SetupWizardModule:GetThemePreset(self.selectedTheme)
    local sw, sh = SetupWizardModule:GetScreenDimensions()

    refs.layoutLabel:SetText(string.format("|cff787c88Layout  |r%s", layout and layout.name or "—"))
    refs.themeLabel:SetText(string.format("|cff787c88Theme   |r%s", theme and theme.name or "—"))
    refs.resLabel:SetText(string.format("|cff787c88Screen  |r%dx%d", sw, sh))
end
