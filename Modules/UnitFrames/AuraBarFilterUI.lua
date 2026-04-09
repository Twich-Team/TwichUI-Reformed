---@diagnostic disable: undefined-field, undefined-global, inject-field

local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type UnitFramesModule
local UnitFrames = T:GetModule("UnitFrames")
if not UnitFrames then return end

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local type = type
local math_max = math.max
local string_format = string.format
local table_remove = table.remove

local W_TOTAL = 760
local H_TOTAL = 588
local PAD = 14
local ROW_HEIGHT = 34
local MAX_VISIBLE_ROWS = 11

local C = {
    bg = { 0.05, 0.06, 0.08 },
    panel = { 0.08, 0.09, 0.12 },
    card = { 0.10, 0.11, 0.15 },
    cardAlt = { 0.07, 0.08, 0.11 },
    border = { 0.20, 0.22, 0.28 },
    teal = { 0.10, 0.72, 0.74 },
    gold = { 0.96, 0.76, 0.24 },
    text = { 1.00, 0.95, 0.85 },
    muted = { 0.54, 0.57, 0.63 },
    danger = { 0.90, 0.30, 0.32 },
}

local FRAME_LABELS = {
    player = "Player",
    target = "Target",
    targettarget = "Target Target",
    focus = "Focus",
    pet = "Pet",
    partyMember = "Party",
    raidMember = "Raid",
    tankMember = "Tanks",
}

local root
local dismissLayer
local titleLabel
local subtitleLabel
local statusLabel
local enabledToggle
local inputBox
local rows = {}
local scrollOffset = 0
local activeFrameKey = "player"

local function Font(size, flags)
    local LSM = T.Libs and T.Libs.LSM
    local path = (LSM and LSM.Fetch and LSM:Fetch("font", "Expressway")) or "Fonts\\ARIALN.TTF"
    return path, size or 12, flags or ""
end

local function Backdrop(frame, bg, border, bgAlpha, borderAlpha)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bgAlpha == nil and 1 or bgAlpha)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], borderAlpha == nil and 1 or borderAlpha)
end

local function GetSpellNameById(spellId)
    if _G.C_Spell and _G.C_Spell.GetSpellName then
        return _G.C_Spell.GetSpellName(spellId)
    end
    if _G.GetSpellInfo then
        return (_G.GetSpellInfo(spellId))
    end
    return nil
end

local function RefreshAuraBarFilters()
    UnitFrames._auraConfigCache = nil
    if UnitFrames.RefreshAllFrames then
        UnitFrames:RefreshAllFrames()
    end
end

local function ResolveScope(frameKey)
    if frameKey == "partyMember" then return "party" end
    if frameKey == "raidMember" then return "raid" end
    if frameKey == "tankMember" then return "tank" end
    return "singles"
end

local function GetAuraBarConfig(frameKey)
    local db = UnitFrames:GetDB()
    local scope = ResolveScope(frameKey)

    if scope == "singles" then
        db.units = db.units or {}
        db.units[frameKey] = db.units[frameKey] or {}
        db.units[frameKey].auras = db.units[frameKey].auras or {}
        return db.units[frameKey].auras
    end

    db.auras = db.auras or {}
    db.auras.scopes = db.auras.scopes or {}
    db.auras.scopes[scope] = db.auras.scopes[scope] or {}
    return db.auras.scopes[scope]
end

local function NormalizeTrackedSpellIds(frameKey)
    local cfg = GetAuraBarConfig(frameKey)
    local source = cfg.trackedSpellIds
    local cleaned = {}
    local seen = {}

    if type(source) == "table" then
        for _, rawSpellId in ipairs(source) do
            local spellId = tonumber(rawSpellId)
            if spellId and spellId > 0 and not seen[spellId] then
                cleaned[#cleaned + 1] = spellId
                seen[spellId] = true
            end
        end
    end

    cfg.trackedSpellIds = cleaned
    return cleaned
end

local function ParseSpellIds(text)
    local parsed = {}
    if type(text) ~= "string" or text == "" then
        return parsed
    end

    for token in text:gmatch("[^%s,\n]+") do
        local spellId = tonumber(token)
        if spellId and spellId > 0 then
            parsed[#parsed + 1] = spellId
        end
    end

    return parsed
end

local function UpdateToggleVisual(toggle, checked)
    if not toggle then return end
    toggle.checked = checked == true
    toggle.check:SetShown(toggle.checked == true)
    if toggle.checked then
        toggle.label:SetTextColor(C.text[1], C.text[2], C.text[3])
        toggle.box:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
    else
        toggle.label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        toggle.box:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end
end

local function CreateStyledButton(parent, label, width, height, variant)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    Backdrop(btn, C.card, C.border, 0.98, 1)

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont(Font(12))
    btn.label:SetAllPoints(btn)
    btn.label:SetJustifyH("CENTER")
    btn.label:SetJustifyV("MIDDLE")
    btn.label:SetText(label)

    local hover = variant == "danger" and C.danger or C.teal
    local normal = variant == "danger" and C.danger or C.text
    btn.label:SetTextColor(normal[1], normal[2], normal[3])

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(hover[1], hover[2], hover[3], 1)
        self:SetBackdropColor(C.card[1] + 0.02, C.card[2] + 0.02, C.card[3] + 0.02, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        self:SetBackdropColor(C.card[1], C.card[2], C.card[3], 0.98)
    end)

    return btn
end

local function CreateStyledInput(parent, width, height)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(width, height)
    Backdrop(eb, C.cardAlt, C.border, 1, 1)
    eb:SetFont(Font(12))
    eb:SetTextInsets(10, 10, 0, 0)
    eb:SetAutoFocus(false)
    eb:SetJustifyH("LEFT")
    eb:SetMaxLetters(120)

    eb.placeholder = eb:CreateFontString(nil, "ARTWORK")
    eb.placeholder:SetFont(Font(11))
    eb.placeholder:SetPoint("LEFT", 10, 0)
    eb.placeholder:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    eb.placeholder:SetText("315496, 12345, 67890")

    local function RefreshPlaceholder(self)
        local text = self:GetText()
        self.placeholder:SetShown(text == nil or text == "")
    end

    eb:SetScript("OnTextChanged", RefreshPlaceholder)
    eb:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
        self:HighlightText()
        RefreshPlaceholder(self)
    end)
    eb:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        RefreshPlaceholder(self)
    end)
    RefreshPlaceholder(eb)

    return eb
end

local function CreateToggle(parent, label)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(250, 24)

    btn.box = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    btn.box:SetSize(18, 18)
    btn.box:SetPoint("LEFT", 0, 0)
    Backdrop(btn.box, C.cardAlt, C.border, 1, 1)

    btn.check = btn.box:CreateTexture(nil, "OVERLAY")
    btn.check:SetPoint("TOPLEFT", 3, -3)
    btn.check:SetPoint("BOTTOMRIGHT", -3, 3)
    btn.check:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 0.9)

    btn.label = btn:CreateFontString(nil, "OVERLAY")
    btn.label:SetFont(Font(12))
    btn.label:SetPoint("LEFT", btn.box, "RIGHT", 10, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetText(label)

    btn:SetScript("OnEnter", function(self)
        self.box:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        UpdateToggleVisual(self, self.checked == true)
    end)

    UpdateToggleVisual(btn, false)
    return btn
end

local function CloseDesigner()
    if inputBox then
        inputBox:ClearFocus()
    end
    if dismissLayer then
        dismissLayer:Hide()
    end
    if root then
        root:Hide()
    end
end

local function RefreshRows()
    if not root then return end

    local cfg = GetAuraBarConfig(activeFrameKey)
    local spellIds = NormalizeTrackedSpellIds(activeFrameKey)
    local total = #spellIds
    local maxOffset = math_max(0, total - MAX_VISIBLE_ROWS)
    if scrollOffset > maxOffset then
        scrollOffset = maxOffset
    end

    UpdateToggleVisual(enabledToggle, cfg.trackedSpellFilterEnabled == true)

    if titleLabel then
        titleLabel:SetText("Aura Bar Filter Designer")
    end
    if subtitleLabel then
        subtitleLabel:SetText(string_format("%s aura bars", FRAME_LABELS[activeFrameKey] or activeFrameKey))
    end
    if statusLabel then
        statusLabel:SetText(string_format("Tracked spells: %d", total))
    end

    for rowIndex = 1, MAX_VISIBLE_ROWS do
        local spellIndex = scrollOffset + rowIndex
        local spellId = spellIds[spellIndex]
        local row = rows[rowIndex]
        if row then
            if spellId then
                local spellName = GetSpellNameById(spellId) or "Unknown Spell"
                row.index = spellIndex
                row.name:SetText(spellName)
                row.meta:SetText("Spell ID: " .. tostring(spellId))
                row:Show()
            else
                row.index = nil
                row:Hide()
            end
        end
    end
end

local function AddTrackedSpellIdsFromInput()
    if not inputBox then return end

    local parsed = ParseSpellIds(inputBox:GetText())
    if #parsed == 0 then
        return
    end

    local cfg = GetAuraBarConfig(activeFrameKey)
    local spellIds = NormalizeTrackedSpellIds(activeFrameKey)
    local seen = {}
    for _, existingSpellId in ipairs(spellIds) do
        seen[existingSpellId] = true
    end

    local changed = false
    for _, spellId in ipairs(parsed) do
        if not seen[spellId] then
            spellIds[#spellIds + 1] = spellId
            seen[spellId] = true
            changed = true
        end
    end

    if changed then
        cfg.trackedSpellIds = spellIds
        cfg.trackedSpellFilterEnabled = true
        inputBox:SetText("")
        RefreshAuraBarFilters()
        RefreshRows()
    end
end

local function RemoveTrackedSpellId(index)
    if not index then return end

    local spellIds = NormalizeTrackedSpellIds(activeFrameKey)
    if not spellIds[index] then return end

    table_remove(spellIds, index)
    RefreshAuraBarFilters()
    RefreshRows()
end

local function ClearTrackedSpellIds()
    local cfg = GetAuraBarConfig(activeFrameKey)
    cfg.trackedSpellIds = {}
    scrollOffset = 0
    RefreshAuraBarFilters()
    RefreshRows()
end

local function ToggleTrackedSpellFilter(enabled)
    local cfg = GetAuraBarConfig(activeFrameKey)
    cfg.trackedSpellFilterEnabled = enabled == true
    RefreshAuraBarFilters()
    RefreshRows()
end

local function BuildDesigner()
    if root then return end

    dismissLayer = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    dismissLayer:SetAllPoints(UIParent)
    dismissLayer:SetFrameStrata("DIALOG")
    dismissLayer:SetFrameLevel(1)
    dismissLayer:EnableMouse(true)
    dismissLayer:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8" })
    dismissLayer:SetBackdropColor(0, 0, 0, 0.22)
    dismissLayer:SetScript("OnClick", CloseDesigner)
    dismissLayer:Hide()

    root = CreateFrame("Frame", "TwichUIAuraBarFilterDesigner", UIParent, "BackdropTemplate")
    root:SetSize(W_TOTAL, H_TOTAL)
    root:SetPoint("CENTER")
    root:SetFrameStrata("DIALOG")
    root:SetFrameLevel(2)
    root:SetToplevel(true)
    root:SetClampedToScreen(true)
    root:EnableMouse(true)
    root:SetMovable(true)
    root:EnableKeyboard(true)
    Backdrop(root, C.bg, C.border, 0.98, 1)
    root:Hide()

    root:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)
    root:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)
    root:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            CloseDesigner()
        end
    end)
    root:SetScript("OnHide", function()
        if inputBox then
            inputBox:ClearFocus()
        end
    end)

    local header = CreateFrame("Frame", nil, root, "BackdropTemplate")
    header:SetHeight(42)
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    Backdrop(header, C.panel, C.border, 1, 1)

    titleLabel = header:CreateFontString(nil, "OVERLAY")
    titleLabel:SetFont(Font(14, "OUTLINE"))
    titleLabel:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
    titleLabel:SetPoint("LEFT", header, "LEFT", PAD, 0)

    subtitleLabel = header:CreateFontString(nil, "OVERLAY")
    subtitleLabel:SetFont(Font(11))
    subtitleLabel:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    subtitleLabel:SetPoint("LEFT", titleLabel, "RIGHT", 12, 0)

    local closeBtn = CreateStyledButton(header, "Close", 58, 24, "danger")
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -PAD, 0)
    closeBtn:SetScript("OnClick", CloseDesigner)

    local body = CreateFrame("Frame", nil, root, "BackdropTemplate")
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PAD, -PAD)
    body:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -PAD, PAD)
    Backdrop(body, C.panel, C.border, 1, 1)

    local description = body:CreateFontString(nil, "OVERLAY")
    description:SetFont(Font(12))
    description:SetPoint("TOPLEFT", 16, -16)
    description:SetPoint("TOPRIGHT", -16, -16)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    description:SetText(
        "Limit aura bars to an explicit spell list. Add spell IDs below to build a custom tracked-spell filter for this frame."
    )

    enabledToggle = CreateToggle(body, "Enable tracked-spell filter")
    enabledToggle:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -16)
    enabledToggle:SetScript("OnClick", function(self)
        ToggleTrackedSpellFilter(not self.checked)
    end)

    statusLabel = body:CreateFontString(nil, "OVERLAY")
    statusLabel:SetFont(Font(11, "OUTLINE"))
    statusLabel:SetPoint("LEFT", enabledToggle, "RIGHT", 22, 0)
    statusLabel:SetTextColor(C.gold[1], C.gold[2], C.gold[3])

    local inputLabel = body:CreateFontString(nil, "OVERLAY")
    inputLabel:SetFont(Font(12))
    inputLabel:SetPoint("TOPLEFT", enabledToggle, "BOTTOMLEFT", 0, -20)
    inputLabel:SetTextColor(C.text[1], C.text[2], C.text[3])
    inputLabel:SetText("Add spell IDs")

    inputBox = CreateStyledInput(body, 432, 30)
    inputBox:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -10)
    inputBox:SetScript("OnEnterPressed", function(self)
        AddTrackedSpellIdsFromInput()
        self:ClearFocus()
    end)
    inputBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        CloseDesigner()
    end)

    local addButton = CreateStyledButton(body, "Add", 88, 30)
    addButton:SetPoint("LEFT", inputBox, "RIGHT", 10, 0)
    addButton:SetScript("OnClick", AddTrackedSpellIdsFromInput)

    local clearButton = CreateStyledButton(body, "Clear All", 96, 30, "danger")
    clearButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
    clearButton:SetScript("OnClick", ClearTrackedSpellIds)

    local hint = body:CreateFontString(nil, "OVERLAY")
    hint:SetFont(Font(10))
    hint:SetPoint("TOPLEFT", inputBox, "BOTTOMLEFT", 0, -8)
    hint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    hint:SetText("Enter one or more spell IDs separated by commas, spaces, or new lines.")

    local listPanel = CreateFrame("Frame", nil, body, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    listPanel:SetPoint("BOTTOMRIGHT", -16, 50)
    Backdrop(listPanel, C.card, C.border, 0.96, 1)

    local listHeader = listPanel:CreateFontString(nil, "OVERLAY")
    listHeader:SetFont(Font(12, "OUTLINE"))
    listHeader:SetPoint("TOPLEFT", 14, -12)
    listHeader:SetTextColor(C.text[1], C.text[2], C.text[3])
    listHeader:SetText("Tracked Spells")

    local prevButton = CreateStyledButton(listPanel, "Up", 40, 22)
    prevButton:SetPoint("TOPRIGHT", -106, -8)
    prevButton:SetScript("OnClick", function()
        scrollOffset = math_max(0, scrollOffset - 1)
        RefreshRows()
    end)

    local nextButton = CreateStyledButton(listPanel, "Down", 56, 22)
    nextButton:SetPoint("LEFT", prevButton, "RIGHT", 6, 0)
    nextButton:SetScript("OnClick", function()
        scrollOffset = scrollOffset + 1
        RefreshRows()
    end)

    listPanel:EnableMouseWheel(true)
    listPanel:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            scrollOffset = math_max(0, scrollOffset - 1)
        else
            scrollOffset = scrollOffset + 1
        end
        RefreshRows()
    end)

    for rowIndex = 1, MAX_VISIBLE_ROWS do
        local row = CreateFrame("Frame", nil, listPanel, "BackdropTemplate")
        row:SetPoint("TOPLEFT", 12, -40 - ((rowIndex - 1) * (ROW_HEIGHT + 6)))
        row:SetPoint("TOPRIGHT", -12, -40 - ((rowIndex - 1) * (ROW_HEIGHT + 6)))
        row:SetHeight(ROW_HEIGHT)
        Backdrop(row, C.cardAlt, C.border, 1, 1)

        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetFont(Font(12))
        row.name:SetPoint("TOPLEFT", 10, -7)
        row.name:SetPoint("RIGHT", -92, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetTextColor(C.text[1], C.text[2], C.text[3])

        row.meta = row:CreateFontString(nil, "OVERLAY")
        row.meta:SetFont(Font(10))
        row.meta:SetPoint("BOTTOMLEFT", 10, 7)
        row.meta:SetPoint("RIGHT", -92, 0)
        row.meta:SetJustifyH("LEFT")
        row.meta:SetTextColor(C.muted[1], C.muted[2], C.muted[3])

        row.remove = CreateStyledButton(row, "Remove", 72, 24, "danger")
        row.remove:SetPoint("RIGHT", -8, 0)
        row.remove:SetScript("OnClick", function(self)
            RemoveTrackedSpellId(self:GetParent().index)
        end)

        rows[rowIndex] = row
    end

    local footerHint = body:CreateFontString(nil, "OVERLAY")
    footerHint:SetFont(Font(10))
    footerHint:SetPoint("BOTTOMLEFT", 18, 18)
    footerHint:SetPoint("BOTTOMRIGHT", -18, 18)
    footerHint:SetJustifyH("LEFT")
    footerHint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    footerHint:SetText("This filter only affects aura bars. Aura icon mode continues to use the standard aura filters.")
end

function UnitFrames:ABOpenDesigner(frameKey)
    BuildDesigner()
    activeFrameKey = frameKey or activeFrameKey or "player"
    scrollOffset = 0
    dismissLayer:Show()
    root:Show()
    root:Raise()
    RefreshRows()
end

function UnitFrames:ABCloseDesigner()
    CloseDesigner()
end

function UnitFrames:ABToggleDesigner(frameKey)
    BuildDesigner()
    if root:IsShown() then
        CloseDesigner()
    else
        self:ABOpenDesigner(frameKey)
    end
end
