local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class UISkins
local UI = Tools.UI or {}
Tools.UI = UI

local CreateFrame = _G.CreateFrame
local GameFontHighlight = _G.GameFontHighlight
local GameFontHighlightSmall = _G.GameFontHighlightSmall
local UIParent = _G.UIParent
local date = _G.date
local format = string.format
local GetTime = _G.GetTime
local max = math.max
local pairs = pairs
local pcall = pcall
local tableSort = table.sort
local tinsert = table.insert
local tostring = tostring
local type = type

---@class TwichUIDebugSource
---@field key string
---@field title string
---@field order number|nil
---@field aliases string[]|nil
---@field maxLines number|nil
---@field isEnabled fun():boolean|nil
---@field buildReport fun():string|nil

---@class TwichUIDebugConsole
---@field sources table<string, TwichUIDebugSource>
---@field sourceOrder string[]
---@field buffers table<string, string[]>
---@field activeSourceKey string|nil
---@field frame Frame|nil
local DebugConsole = UI.DebugConsole or {}
UI.DebugConsole = DebugConsole

DebugConsole.sources = DebugConsole.sources or {}
DebugConsole.sourceOrder = DebugConsole.sourceOrder or {}
DebugConsole.buffers = DebugConsole.buffers or {}
DebugConsole.activeSourceKey = DebugConsole.activeSourceKey or nil

local function Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

local function NormalizeKey(value)
    local trimmed = Trim(value):lower()
    if trimmed == "" then
        return ""
    end

    trimmed = trimmed:gsub("[%s%+_%-]+", "")
    return trimmed
end

local function SafeString(value)
    if value == nil then
        return "nil"
    end

    if type(value) == "string" then
        return value
    end

    local ok, stringValue = pcall(tostring, value)
    if ok and type(stringValue) == "string" then
        return stringValue
    end

    return "<value>"
end

function DebugConsole:GetSortedSourceKeys()
    local keys = {}
    for key in pairs(self.sources) do
        keys[#keys + 1] = key
    end

    tableSort(keys, function(leftKey, rightKey)
        local left = self.sources[leftKey] or {}
        local right = self.sources[rightKey] or {}
        local leftOrder = left.order or 1000
        local rightOrder = right.order or 1000
        if leftOrder ~= rightOrder then
            return leftOrder < rightOrder
        end

        return (left.title or leftKey) < (right.title or rightKey)
    end)

    self.sourceOrder = keys
    return keys
end

function DebugConsole:RegisterSource(key, source)
    key = NormalizeKey(key)
    if key == "" or type(source) ~= "table" then
        return
    end

    source.key = key
    source.title = source.title or key
    self.sources[key] = source
    self.buffers[key] = self.buffers[key] or {}
    self:GetSortedSourceKeys()

    if not self.activeSourceKey then
        self.activeSourceKey = key
    end

    if self.frame then
        self:RefreshSourceButtons()
        self:Refresh()
    end
end

function DebugConsole:ResolveSourceKey(input)
    local normalized = NormalizeKey(input)
    if normalized == "" then
        return self.activeSourceKey or self:GetSortedSourceKeys()[1]
    end

    if self.sources[normalized] then
        return normalized
    end

    for key, source in pairs(self.sources) do
        if NormalizeKey(source.title) == normalized then
            return key
        end

        for _, alias in ipairs(source.aliases or {}) do
            if NormalizeKey(alias) == normalized then
                return key
            end
        end
    end

    return nil
end

function DebugConsole:IsSourceEnabled(key)
    local source = key and self.sources[key] or nil
    if not source then
        return false
    end

    if type(source.isEnabled) == "function" then
        local ok, enabled = pcall(source.isEnabled)
        if ok then
            return enabled == true
        end
        return false
    end

    return true
end

function DebugConsole:GetLines(key)
    return self.buffers[key] or {}
end

function DebugConsole:ClearLogs(key)
    if key then
        self.buffers[key] = {}
    else
        for sourceKey in pairs(self.sources) do
            self.buffers[sourceKey] = {}
        end
    end

    if self.frame and self.frame:IsShown() then
        self:Refresh()
    end
end

function DebugConsole:Log(key, message, shouldShow)
    key = self:ResolveSourceKey(key)
    if not key or not self:IsSourceEnabled(key) then
        return false
    end

    local source = self.sources[key] or {}
    local lines = self.buffers[key] or {}
    self.buffers[key] = lines

    local prefix = date and type(date) == "function" and date("%H:%M:%S") or format("%.3f", GetTime())
    lines[#lines + 1] = format("[%s] %s", SafeString(prefix), SafeString(message))

    local maxLines = tonumber(source.maxLines) or 120
    while #lines > maxLines do
        table.remove(lines, 1)
    end

    if shouldShow == true then
        self:Show(key)
        return true
    end

    if self.frame and self.frame:IsShown() and self.activeSourceKey == key then
        self:Refresh()
    end

    return true
end

function DebugConsole:Logf(key, shouldShow, messageFormat, ...)
    key = self:ResolveSourceKey(key)
    if not key or not self:IsSourceEnabled(key) then
        return false
    end

    return self:Log(key, format(messageFormat, ...), shouldShow)
end

function DebugConsole:BuildSourceText(key)
    local source = key and self.sources[key] or nil
    if not source then
        return "TwichUI Debug Console\n\nNo debug sources are registered."
    end

    local lines = {
        "TwichUI Debug Console",
        format("Source: %s", source.title or key),
        format("Debug Capture: %s", self:IsSourceEnabled(key) and "Enabled" or "Disabled"),
        "",
    }

    if not self:IsSourceEnabled(key) then
        lines[#lines + 1] = "Live debug capture is disabled for this module."
        lines[#lines + 1] = "Enable it in the module's config if you want logs to be recorded while you play."
        lines[#lines + 1] = ""
    end

    if type(source.buildReport) == "function" then
        local ok, report = pcall(source.buildReport)
        if ok and type(report) == "string" and report ~= "" then
            lines[#lines + 1] = report
            lines[#lines + 1] = ""
        end

        if not ok then
            lines[#lines + 1] = "Failed to build debug report for this source."
            lines[#lines + 1] = SafeString(report)
            return table.concat(lines, "\n")
        end
    end

    local buffer = self:GetLines(key)
    if #buffer == 0 then
        lines[#lines + 1] = "No debug lines recorded yet."
    else
        lines[#lines + 1] = "Live Log"
        lines[#lines + 1] = ""
        for _, line in ipairs(buffer) do
            lines[#lines + 1] = line
        end
    end

    return table.concat(lines, "\n")
end

function DebugConsole:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", "TwichUIDebugConsoleFrame", UIParent, "BackdropTemplate")
    frame:SetSize(900, 560)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(0.06, 0.06, 0.08, 0.96)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    if titleBar.SetTemplate then
        titleBar:SetTemplate("Default")
    end
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    title:SetJustifyH("LEFT")
    if GameFontHighlight and title.SetFontObject then
        title:SetFontObject(GameFontHighlight)
    end
    title:SetText("TwichUI Debug Console")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -38)
    subtitle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -140, -38)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Use /tui debug or /tui debug <module> to open a source directly.")
    if GameFontHighlightSmall and subtitle.SetFontObject then
        subtitle:SetFontObject(GameFontHighlightSmall)
    end

    local sourceBar = CreateFrame("Frame", nil, frame)
    sourceBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -60)
    sourceBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -140, -60)
    sourceBar:SetHeight(24)

    local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    refreshButton:SetSize(60, 22)
    refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -74, -36)
    refreshButton:SetText("Refresh")
    if UI.SkinButton then
        UI.SkinButton(refreshButton)
    end

    local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearButton:SetSize(60, 22)
    clearButton:SetPoint("RIGHT", refreshButton, "LEFT", -8, 0)
    clearButton:SetText("Clear")
    if UI.SkinButton then
        UI.SkinButton(clearButton)
    end

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)
    if UI.SkinCloseButton then
        UI.SkinCloseButton(closeButton)
    end

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -92)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)
    if UI.SkinScrollBar then
        UI.SkinScrollBar(scroll)
    end

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(_G.ChatFontNormal)
    editBox:SetWidth(840)
    editBox:SetHeight(1800)
    editBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    editBox:SetScript("OnTextChanged", function(box)
        local text = box:GetText() or ""
        local _, lineCount = text:gsub("\n", "\n")
        local _, fontHeight = box:GetFont()
        local lineHeight = (fontHeight or 14) + 2
        box:SetHeight(max(1800, ((lineCount + 1) * lineHeight) + 24))
    end)

    scroll:SetScrollChild(editBox)

    frame.titleBar = titleBar
    frame.title = title
    frame.subtitle = subtitle
    frame.sourceBar = sourceBar
    frame.sourceButtons = {}
    frame.refreshButton = refreshButton
    frame.clearButton = clearButton
    frame.closeButton = closeButton
    frame.scroll = scroll
    frame.editBox = editBox

    refreshButton:SetScript("OnClick", function()
        self:Refresh()
    end)
    clearButton:SetScript("OnClick", function()
        self:ClearLogs(self.activeSourceKey)
    end)
    frame:SetScript("OnShow", function()
        self:RefreshSourceButtons()
        self:Refresh()
    end)

    self.frame = frame
    return frame
end

function DebugConsole:RefreshSourceButtons()
    local frame = self:EnsureFrame()
    if not frame or not frame.sourceBar or not frame.sourceButtons then
        return
    end

    local keys = self:GetSortedSourceKeys()
    local previous

    for index, key in ipairs(keys) do
        local button = frame.sourceButtons[index]
        if not button then
            button = CreateFrame("Button", nil, frame.sourceBar, "UIPanelButtonTemplate")
            button:SetHeight(22)
            if UI.SkinButton then
                UI.SkinButton(button)
            end
            frame.sourceButtons[index] = button
        end

        local source = self.sources[key]
        button:SetWidth(max(96, (source.title and #source.title or 10) * 7 + 18))
        button:SetText(source.title or key)
        button:SetPoint("LEFT", previous or frame.sourceBar, previous and "RIGHT" or "LEFT", previous and 6 or 0, 0)
        button:SetScript("OnClick", function()
            self:Show(key)
        end)

        if self.activeSourceKey == key then
            button:Disable()
            button:SetAlpha(1.0)
        else
            button:Enable()
            button:SetAlpha(self:IsSourceEnabled(key) and 1.0 or 0.65)
        end

        button:Show()
        previous = button
    end

    for index = #keys + 1, #frame.sourceButtons do
        frame.sourceButtons[index]:Hide()
    end
end

function DebugConsole:Refresh()
    local frame = self:EnsureFrame()
    if not frame or not frame.editBox or not frame.scroll or not frame.title then
        return
    end

    local key = self.activeSourceKey or self:GetSortedSourceKeys()[1]
    if not key then
        frame.editBox:SetText("TwichUI Debug Console\n\nNo debug sources are registered.")
        frame.editBox:SetCursorPosition(0)
        frame.scroll:SetVerticalScroll(0)
        return
    end

    self.activeSourceKey = key
    local source = self.sources[key]
    frame.title:SetText(format("TwichUI Debug Console - %s", source and source.title or key))
    frame.editBox:SetText(self:BuildSourceText(key))
    frame.editBox:SetCursorPosition(0)
    frame.editBox:HighlightText()
    frame.scroll:SetVerticalScroll(0)
    self:RefreshSourceButtons()
end

function DebugConsole:Show(sourceKey)
    local resolved = self:ResolveSourceKey(sourceKey)
    if not resolved then
        resolved = self:GetSortedSourceKeys()[1]
    end

    if not resolved then
        T:Print("[TwichUI] No debug sources are registered")
        return false
    end

    self.activeSourceKey = resolved
    local frame = self:EnsureFrame()
    if not frame then
        return false
    end

    self:Refresh()
    frame:Show()
    if frame.Raise then
        frame:Raise()
    end
    return true
end

function DebugConsole:ListSourceTitles()
    local titles = {}
    for _, key in ipairs(self:GetSortedSourceKeys()) do
        local source = self.sources[key]
        titles[#titles + 1] = source and source.title or key
    end
    return titles
end

return DebugConsole