---@diagnostic disable: undefined-field, undefined-global
--[[
    TwichUI Error Log Viewer
    A movable, two-panel frame:
      Left  – scrollable list of captured errors (newest first)
      Right – full detail text for the selected error

    Styled to match the TwichUI DebugConsole visual language.
]]
local TwichRx                = _G.TwichRx
---@type TwichUI
local T                      = unpack(TwichRx)

---@type Tools
local Tools                  = T.Tools

---@class UISkins
local UI                     = Tools.UI or {}
Tools.UI                     = UI

local CreateFrame            = _G.CreateFrame
local GameFontHighlightSmall = _G.GameFontHighlightSmall
local UIParent               = _G.UIParent
local math                   = math
local pairs                  = pairs
local pcall                  = pcall
local table                  = table
local type                   = type

local function MeasureDetailTextHeight(frame, text)
    if not frame then
        return 1
    end

    if not frame._detailMeasure then
        frame._detailMeasure = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        frame._detailMeasure:Hide()
        frame._detailMeasure:SetJustifyH("LEFT")
        frame._detailMeasure:SetJustifyV("TOP")
        frame._detailMeasure:SetWordWrap(true)
        frame._detailMeasure:SetNonSpaceWrap(true)
    end

    local measure = frame._detailMeasure
    local width = (frame.detailEditBox and frame.detailEditBox:GetWidth() or
        (frame.detailContent and frame.detailContent:GetWidth() or 300) - 16)
    measure:SetWidth(math.max(40, width))
    measure:SetText(text or "")
    return math.max(1, measure:GetStringHeight() + 16)
end

-- ---------------------------------------------------------------------------
-- Theme constants (mirrors DebugConsole palette)
-- ---------------------------------------------------------------------------
local CLR_ACCENT             = { 0.10, 0.79, 0.77 } -- primary teal
local CLR_GOLD               = { 0.98, 0.76, 0.22 } -- title accent stripe
local CLR_WARN               = { 0.98, 0.56, 0.50 } -- close / danger
local CLR_BG_DEEP            = { 0.03, 0.03, 0.05 }
local CLR_BG_MID             = { 0.07, 0.07, 0.10 }
local CLR_BG_PANEL           = { 0.05, 0.05, 0.07 }
local CLR_TEXT_HI            = { 1.00, 0.95, 0.82 }
local CLR_TEXT_MUT           = { 0.55, 0.60, 0.68 }
local CLR_TEXT_DATE          = { 0.47, 0.52, 0.60 }

local FRAME_W                = 880
local FRAME_H                = 560
local TITLEBAR_H             = 52
local LIST_W                 = 276
local ROW_H                  = 44
local INSET                  = 6

---@class TwichUIErrorLogViewer
---@field frame Frame|nil
---@field rowPool table
---@field selectedIndex number|nil
local ErrorLogViewer         = UI.ErrorLogViewer or {}
UI.ErrorLogViewer            = ErrorLogViewer
ErrorLogViewer.rowPool       = ErrorLogViewer.rowPool or {}
ErrorLogViewer.selectedIndex = nil
ErrorLogViewer.selectedEntryId = ErrorLogViewer.selectedEntryId or nil

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function Panel(parent, r, g, b, a, br, bg_, bb, ba)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(r or 0, g or 0, b or 0, a or 0.95)
    f:SetBackdropBorderColor(br or 0, bg_ or 0, bb or 0, ba or 0.22)
    return f
end

local function Btn(parent, w, h, label, r, g, b)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local dr, dg, db = r * 0.20, g * 0.20, b * 0.20
    btn:SetBackdropColor(dr, dg, db, 0.95)
    btn:SetBackdropBorderColor(r, g, b, 0.40)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetAllPoints(btn)
    lbl:SetJustifyH("CENTER")
    lbl:SetJustifyV("MIDDLE")
    lbl:SetText(label)
    lbl:SetTextColor(r, g, b)
    btn.__lbl = lbl
    btn:SetScript("OnMouseDown", function(s)
        s:SetBackdropColor(r * 0.32, g * 0.32, b * 0.32, 1)
    end)
    btn:SetScript("OnMouseUp", function(s)
        s:SetBackdropColor(dr, dg, db, 0.95)
    end)
    return btn
end

local function ApplyFont(fs, size, r, g, b)
    local fontPath = "Fonts\\FRIZQT__.TTF"
    -- Try to use our registered monospace-style font if available
    local ok = pcall(function()
        local lsm = T.Libs and T.Libs.LSM
        if lsm then
            local f = lsm:Fetch("font", "PT Mono") or lsm:Fetch("font", "Share Tech Mono")
            if f then fontPath = f end
        end
    end)
    if not ok then fontPath = "Fonts\\FRIZQT__.TTF" end
    fs:SetFont(fontPath, size or 11, "")
    fs:SetTextColor(r or 1, g or 1, b or 1)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
end

-- ---------------------------------------------------------------------------
-- Row construction / recycling
-- ---------------------------------------------------------------------------
local function MakeListRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_H)
    row:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    local dateLabel = row:CreateFontString(nil, "OVERLAY")
    dateLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -7)
    dateLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -7)
    dateLabel:SetJustifyH("LEFT")
    ApplyFont(dateLabel, 9, CLR_TEXT_DATE[1], CLR_TEXT_DATE[2], CLR_TEXT_DATE[3])
    row.dateLabel = dateLabel

    local nameLabel = row:CreateFontString(nil, "OVERLAY")
    nameLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -21)
    nameLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -21)
    nameLabel:SetJustifyH("LEFT")
    ApplyFont(nameLabel, 10, CLR_TEXT_HI[1], CLR_TEXT_HI[2], CLR_TEXT_HI[3])
    nameLabel:SetMaxLines(1)
    nameLabel:SetWordWrap(false)
    row.nameLabel = nameLabel

    -- Accent bar on left edge (shown when selected)
    local bar = row:CreateTexture(nil, "BORDER")
    bar:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)
    bar:SetWidth(3)
    bar:SetColorTexture(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], 0)
    row.accentBar = bar

    -- Hover highlight
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    hl:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    hl:SetColorTexture(1, 1, 1, 0.04)
    row.highlight = hl

    return row
end

local function SetRowSelected(row, selected)
    if selected then
        row:SetBackdropColor(CLR_ACCENT[1] * 0.12, CLR_ACCENT[2] * 0.12, CLR_ACCENT[3] * 0.14, 0.95)
        row:SetBackdropBorderColor(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], 0.35)
        row.accentBar:SetColorTexture(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], 1)
    else
        row:SetBackdropColor(0, 0, 0, 0)
        row:SetBackdropBorderColor(0, 0, 0, 0)
        row.accentBar:SetColorTexture(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], 0)
    end
end

local function UpdateDeleteButtonState(frame, hasSelection)
    local button = frame and frame.deleteBtn
    if not button then
        return
    end

    button:SetEnabled(hasSelection == true)
    button:SetAlpha(hasSelection == true and 1 or 0.45)
end

local function UpdateDetailLayout(frame)
    if not frame or not frame.detailScroll or not frame.detailContent or not frame.detailEditBox then
        return
    end

    local scrollWidth = frame.detailScroll:GetWidth() or 0
    local contentWidth = math.max(220, scrollWidth - 8)
    local editWidth = math.max(200, contentWidth - 20)

    frame.detailContent:SetWidth(contentWidth)
    frame.detailEditBox:SetWidth(editWidth)
    local contentHeight = math.max(1, frame.detailContent:GetHeight() or 1)
    frame.detailEditBox:SetHeight(math.max(1, contentHeight - 16))
end

local function GetEntryIndexById(errors, entryId)
    if not entryId then
        return nil
    end

    for index, entry in ipairs(errors or {}) do
        if entry and entry.id == entryId then
            return index
        end
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Frame construction
-- ---------------------------------------------------------------------------
function ErrorLogViewer:EnsureFrame()
    if self.frame then return self.frame end

    -- Outer shell
    local frame = Panel(UIParent,
        CLR_BG_DEEP[1], CLR_BG_DEEP[2], CLR_BG_DEEP[3], 0.985,
        CLR_GOLD[1], CLR_GOLD[2], CLR_GOLD[3], 0.30)
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(80)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    -- Title bar
    local titleBar = Panel(frame,
        CLR_BG_MID[1], CLR_BG_MID[2], CLR_BG_MID[3], 0.98,
        0, 0, 0, 0.22)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, -INSET)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -INSET, -INSET)
    titleBar:SetHeight(TITLEBAR_H)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Gold accent stripe
    local stripe = titleBar:CreateTexture(nil, "BORDER")
    stripe:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 1, -1)
    stripe:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 1, 1)
    stripe:SetWidth(4)
    stripe:SetColorTexture(CLR_GOLD[1], CLR_GOLD[2], CLR_GOLD[3], 1)

    -- Title text
    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 16, -10)
    titleText:SetText("TwichUI Error Log")
    titleText:SetTextColor(CLR_TEXT_HI[1], CLR_TEXT_HI[2], CLR_TEXT_HI[3])

    -- Subtitle / count badge
    local countLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    countLabel:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -5)
    countLabel:SetJustifyH("LEFT")
    countLabel:SetTextColor(CLR_TEXT_MUT[1], CLR_TEXT_MUT[2], CLR_TEXT_MUT[3])
    frame.countLabel = countLabel

    -- Close button (×)
    local closeBtn = Btn(titleBar, 26, 26, "×", CLR_WARN[1], CLR_WARN[2], CLR_WARN[3])
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -INSET, 0)
    closeBtn.__lbl:SetTextColor(CLR_WARN[1], CLR_WARN[2], CLR_WARN[3])
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Clear button
    local clearBtn = Btn(titleBar, 72, 26, "Clear All", CLR_WARN[1] * 0.8, CLR_WARN[2] * 0.6, CLR_WARN[3] * 0.5)
    clearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    clearBtn:SetScript("OnClick", function()
        local el = Tools.ErrorLog
        if el and el.Clear then el:Clear() end
    end)

    local deleteBtn = Btn(titleBar, 74, 26, "Delete", 0.98, 0.74, 0.30)
    deleteBtn:SetPoint("RIGHT", clearBtn, "LEFT", -6, 0)
    deleteBtn:SetScript("OnClick", function()
        self:DeleteSelectedEntry()
    end)
    frame.deleteBtn = deleteBtn
    UpdateDeleteButtonState(frame, false)

    -- -----------------------------------------------------------------------
    -- Body area (below title bar)
    -- -----------------------------------------------------------------------
    local bodyY  = -(INSET + TITLEBAR_H + INSET)
    local bodyH  = FRAME_H - TITLEBAR_H - INSET * 3
    local bodyW  = FRAME_W - INSET * 2

    -- Left panel background
    local leftBg = Panel(frame,
        CLR_BG_PANEL[1], CLR_BG_PANEL[2], CLR_BG_PANEL[3], 0.92,
        0, 0, 0, 0.18)
    leftBg:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET, bodyY)
    leftBg:SetSize(LIST_W, bodyH)

    -- Left panel header
    local listHeader = leftBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listHeader:SetPoint("TOPLEFT", leftBg, "TOPLEFT", 10, -8)
    listHeader:SetText("Errors")
    listHeader:SetTextColor(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])

    -- Scroll frame for the list
    local listScroll = CreateFrame("ScrollFrame", nil, leftBg)
    listScroll:SetPoint("TOPLEFT", leftBg, "TOPLEFT", 1, -24)
    listScroll:SetPoint("BOTTOMRIGHT", leftBg, "BOTTOMRIGHT", -1, 1)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetWidth(LIST_W - 2)
    listContent:SetHeight(1) -- will be updated in Refresh
    listScroll:SetScrollChild(listContent)
    frame.listContent = listContent
    frame.listScroll  = listScroll

    -- Right panel background
    local rightBg     = Panel(frame,
        CLR_BG_PANEL[1], CLR_BG_PANEL[2], CLR_BG_PANEL[3] * 0.80, 0.92,
        0, 0, 0, 0.18)
    rightBg:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET + LIST_W + INSET, bodyY)
    rightBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET, INSET)

    -- Right panel header
    local detailHeader = rightBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailHeader:SetPoint("TOPLEFT", rightBg, "TOPLEFT", 10, -8)
    detailHeader:SetText("Error Details")
    detailHeader:SetTextColor(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])
    frame.detailHeader = detailHeader

    -- Scroll frame for detail text
    local detailScroll = CreateFrame("ScrollFrame", nil, rightBg)
    detailScroll:SetPoint("TOPLEFT", rightBg, "TOPLEFT", 1, -24)
    detailScroll:SetPoint("BOTTOMRIGHT", rightBg, "BOTTOMRIGHT", -6, 6)
    detailScroll:EnableMouseWheel(true)
    detailScroll:SetScript("OnMouseWheel", function(_, delta)
        local cur  = detailScroll:GetVerticalScroll()
        local max_ = detailScroll:GetVerticalScrollRange()
        detailScroll:SetVerticalScroll(math.max(0, math.min(max_, cur - delta * 28)))
    end)

    local detailContent = CreateFrame("Frame", nil, detailScroll)
    detailContent:SetWidth(FRAME_W - INSET * 2 - LIST_W - INSET * 4)
    detailContent:SetHeight(1)
    detailScroll:SetScrollChild(detailContent)

    -- Use an EditBox instead of FontString so users can select/copy stack traces.
    local detailEditBox = CreateFrame("EditBox", nil, detailContent)
    detailEditBox:SetPoint("TOPLEFT", detailContent, "TOPLEFT", 8, -8)
    detailEditBox:SetMultiLine(true)
    detailEditBox:SetAutoFocus(false)
    detailEditBox:SetFontObject(GameFontHighlightSmall)
    detailEditBox:SetTextColor(0.82, 0.88, 0.94)
    detailEditBox:SetJustifyH("LEFT")
    detailEditBox:SetJustifyV("TOP")
    detailEditBox:SetTextInsets(0, 0, 0, 0)
    detailEditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        self:HighlightText(0, 0)
    end)
    detailEditBox:SetScript("OnMouseDown", function(self)
        self:SetFocus()
    end)
    detailEditBox:SetScript("OnCursorChanged", function(self, _, y)
        local height = detailScroll:GetHeight()
        local offset = -y
        if offset < detailScroll:GetVerticalScroll() then
            detailScroll:SetVerticalScroll(offset)
        elseif (offset + 24) > (detailScroll:GetVerticalScroll() + height) then
            detailScroll:SetVerticalScroll(offset - height + 24)
        end
    end)

    frame.detailEditBox = detailEditBox
    frame.detailContent = detailContent
    frame.detailScroll  = detailScroll
    frame.rightBg       = rightBg

    frame:SetScript("OnSizeChanged", function(self)
        UpdateDetailLayout(self)
    end)
    UpdateDetailLayout(frame)

    -- Mousewheel on list
    listScroll:EnableMouseWheel(true)
    listScroll:SetScript("OnMouseWheel", function(_, delta)
        local cur  = listScroll:GetVerticalScroll()
        local max_ = listScroll:GetVerticalScrollRange()
        listScroll:SetVerticalScroll(math.max(0, math.min(max_, cur - delta * ROW_H)))
    end)

    self.frame = frame
    return frame
end

-- ---------------------------------------------------------------------------
-- Refresh: rebuild the row list and update count label
-- ---------------------------------------------------------------------------
function ErrorLogViewer:Refresh()
    local frame = self.frame
    if not frame then return end

    local el = Tools.ErrorLog
    if not el then return end

    local errors = el:GetAll()
    local count  = #errors
    local selectedIndex = GetEntryIndexById(errors, self.selectedEntryId)
    if selectedIndex then
        self.selectedIndex = selectedIndex
    elseif count == 0 then
        self.selectedIndex = nil
        self.selectedEntryId = nil
    elseif self.selectedIndex and self.selectedIndex > count then
        self.selectedIndex = 1
        self.selectedEntryId = errors[1] and errors[1].id or nil
    end

    -- Count label
    if count == 0 then
        frame.countLabel:SetText("No errors captured")
    elseif count == 1 then
        frame.countLabel:SetText("1 error captured")
    else
        frame.countLabel:SetText(count .. " errors captured")
    end

    -- Recycle rows: hide all existing
    for _, row in pairs(self.rowPool) do
        row:Hide()
        row:ClearAllPoints()
    end

    local content = frame.listContent
    local yOffset = 0
    UpdateDetailLayout(frame)

    for i, entry in ipairs(errors) do
        local row = self.rowPool[i]
        if not row then
            row = MakeListRow(content)
            self.rowPool[i] = row
        end

        row:Show()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)
        row:SetHeight(ROW_H)

        -- Alternating background
        if i % 2 == 0 then
            row:SetBackdropColor(0.06, 0.06, 0.08, 0.70)
        else
            row:SetBackdropColor(0.04, 0.04, 0.06, 0.70)
        end
        row:SetBackdropBorderColor(0, 0, 0, 0)
        row.accentBar:SetColorTexture(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], 0)

        row.dateLabel:SetText(entry.dateStr or "")
        row.nameLabel:SetText(entry.short or "Unknown error")

        -- Re-apply selection state
        if i == self.selectedIndex then
            SetRowSelected(row, true)
        end

        -- Click handler
        local capturedIndex = i
        local capturedEntry = entry
        row:SetScript("OnClick", function()
            self:SelectEntry(capturedIndex, capturedEntry)
        end)

        yOffset = yOffset + ROW_H
    end

    content:SetHeight(math.max(1, yOffset))

    -- If selection is out of range (e.g. after clear), reset detail panel
    if count == 0 then
        self.selectedIndex = nil
        self.selectedEntryId = nil
        frame.detailHeader:SetText("Error Details")
        frame.detailEditBox:SetText(
        "No errors have been captured yet.\n\nErrors originating from TwichUI_Reformed will appear here automatically.")
        frame.detailEditBox:HighlightText(0, 0)
        frame.detailContent:SetHeight(MeasureDetailTextHeight(frame, frame.detailEditBox:GetText()))
        UpdateDetailLayout(frame)
        UpdateDeleteButtonState(frame, false)
    elseif self.selectedIndex then
        self:SelectEntry(self.selectedIndex, errors[self.selectedIndex])
    else
        frame.detailHeader:SetText("Error Details")
        frame.detailEditBox:SetText("Select an error on the left to inspect its full stack trace.")
        frame.detailEditBox:HighlightText(0, 0)
        frame.detailScroll:SetVerticalScroll(0)
        frame.detailContent:SetHeight(MeasureDetailTextHeight(frame, frame.detailEditBox:GetText()))
        UpdateDetailLayout(frame)
        UpdateDeleteButtonState(frame, false)
    end
end

function ErrorLogViewer:SelectEntry(index, entry)
    local frame = self.frame
    if not frame or not entry then return end

    -- Deselect old row
    local oldRow = self.rowPool[self.selectedIndex]
    if oldRow then SetRowSelected(oldRow, false) end

    self.selectedIndex = index
    self.selectedEntryId = entry.id

    -- Select new row
    local newRow = self.rowPool[index]
    if newRow then SetRowSelected(newRow, true) end

    -- Update detail panel
    frame.detailHeader:SetText("Error Details  |cff55667a—  " .. (entry.dateStr or "") .. "|r")
    local detail = entry.detail or entry.short or ""
    frame.detailEditBox:SetText(detail)
    frame.detailEditBox:SetFocus()
    frame.detailEditBox:HighlightText(0, 0)

    -- Reset detail scroll to top
    frame.detailScroll:SetVerticalScroll(0)

    -- Resize the scroll child to match current text height.
    local textH = MeasureDetailTextHeight(frame, detail)
    frame.detailContent:SetHeight(textH)
    UpdateDetailLayout(frame)
    UpdateDeleteButtonState(frame, true)
end

function ErrorLogViewer:DeleteSelectedEntry()
    local frame = self.frame
    local entryId = self.selectedEntryId
    if not frame or not entryId then
        return
    end

    local el = Tools.ErrorLog
    if not el or type(el.RemoveEntry) ~= "function" then
        return
    end

    local removed = el:RemoveEntry(entryId)
    if not removed then
        return
    end

    local errors = el:GetAll()
    if #errors == 0 then
        self.selectedIndex = nil
        self.selectedEntryId = nil
    else
        local nextIndex = self.selectedIndex or 1
        if nextIndex > #errors then
            nextIndex = #errors
        end
        self.selectedIndex = nextIndex
        self.selectedEntryId = errors[nextIndex] and errors[nextIndex].id or nil
    end

    self:Refresh()
end

-- ---------------------------------------------------------------------------
-- Show / Hide / Toggle
-- ---------------------------------------------------------------------------
function ErrorLogViewer:Show()
    local frame = self:EnsureFrame()
    if not frame then return end
    self:Refresh()
    frame:Show()
    -- Auto-select first entry
    local el = Tools.ErrorLog
    local errors = el and el:GetAll() or {}
    if #errors > 0 and not self.selectedEntryId then
        self:SelectEntry(1, errors[1])
    end
end

function ErrorLogViewer:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function ErrorLogViewer:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
