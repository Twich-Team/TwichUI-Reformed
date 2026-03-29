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

    local function CreatePanel(parent, r, g, b, a, borderA)
        local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        f:SetBackdropColor(r or 0.08, g or 0.08, b or 0.1, a or 0.96)
        f:SetBackdropBorderColor(0.94, 0.77, 0.28, borderA or 0.22)
        return f
    end

    -- Outer frame
    local frame = CreatePanel(UIParent, 0.03, 0.03, 0.05, 0.985, 0.3)
    frame:SetSize(940, 580)
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
    local titleBar = CreatePanel(frame, 0.08, 0.08, 0.11, 0.98, 0.24)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    titleBar:SetHeight(54)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    -- Gold accent stripe
    local titleAccent = titleBar:CreateTexture(nil, "BORDER")
    titleAccent:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 1, -1)
    titleAccent:SetPoint("BOTTOMLEFT", titleBar, "BOTTOMLEFT", 1, 1)
    titleAccent:SetWidth(5)
    titleAccent:SetColorTexture(0.98, 0.76, 0.22, 1)

    -- Title text
    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 18, -10)
    title:SetText("TwichUI Debug Console")
    title:SetTextColor(1, 0.95, 0.82)

    -- Subtitle
    local subtitle = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetTextColor(0.72, 0.74, 0.8)
    subtitle:SetText("Use /tui debug or /tui debug <module> to open a specific source.")

    -- Close button
    local closeButton = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    closeButton:SetSize(26, 26)
    closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -10, 0)
    closeButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    closeButton:SetBackdropColor(0.98 * 0.22, 0.56 * 0.22, 0.5 * 0.22, 0.98)
    closeButton:SetBackdropBorderColor(0.98, 0.56, 0.5, 0.42)
    local closeIcon = closeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    closeIcon:SetAllPoints(closeButton)
    closeIcon:SetJustifyH("CENTER")
    closeIcon:SetJustifyV("MIDDLE")
    closeIcon:SetText("×")
    closeIcon:SetTextColor(1, 0.85, 0.82)
    closeButton:SetScript("OnMouseDown", function(b) b:SetBackdropColor(0.98 * 0.38, 0.56 * 0.38, 0.5 * 0.38, 1) end)
    closeButton:SetScript("OnMouseUp", function(b)
        b:SetBackdropColor(0.98 * 0.22, 0.56 * 0.22, 0.5 * 0.22, 0.98)
        frame:Hide()
    end)
    closeButton:SetScript("OnClick", function() frame:Hide() end)

    -- Clear button
    local clearButton = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    clearButton:SetSize(72, 24)
    clearButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
    clearButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    clearButton:SetBackdropColor(0.42 * 0.18, 0.82 * 0.18, 0.98 * 0.18, 0.98)
    clearButton:SetBackdropBorderColor(0.42, 0.82, 0.98, 0.38)
    local clearLabel = clearButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    clearLabel:SetAllPoints(clearButton)
    clearLabel:SetJustifyH("CENTER")
    clearLabel:SetJustifyV("MIDDLE")
    clearLabel:SetText("Clear")
    clearLabel:SetTextColor(0.82, 0.92, 1)
    clearButton:SetScript("OnMouseDown", function(b) b:SetBackdropColor(0.42 * 0.28, 0.82 * 0.28, 0.98 * 0.28, 1) end)
    clearButton:SetScript("OnMouseUp", function(b) b:SetBackdropColor(0.42 * 0.18, 0.82 * 0.18, 0.98 * 0.18, 0.98) end)

    -- Refresh button
    local refreshButton = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    refreshButton:SetSize(72, 24)
    refreshButton:SetPoint("RIGHT", clearButton, "LEFT", -6, 0)
    refreshButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    refreshButton:SetBackdropColor(0.42 * 0.18, 0.82 * 0.18, 0.98 * 0.18, 0.98)
    refreshButton:SetBackdropBorderColor(0.42, 0.82, 0.98, 0.38)
    local refreshLabel = refreshButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    refreshLabel:SetAllPoints(refreshButton)
    refreshLabel:SetJustifyH("CENTER")
    refreshLabel:SetJustifyV("MIDDLE")
    refreshLabel:SetText("Refresh")
    refreshLabel:SetTextColor(0.82, 0.92, 1)
    refreshButton:SetScript("OnMouseDown", function(b) b:SetBackdropColor(0.42 * 0.28, 0.82 * 0.28, 0.98 * 0.28, 1) end)
    refreshButton:SetScript("OnMouseUp", function(b) b:SetBackdropColor(0.42 * 0.18, 0.82 * 0.18, 0.98 * 0.18, 0.98) end)

    -- Lua Only toggle — strips timestamps/headers; shows the last raw log entry for easy copy-paste.
    local luaOnlyButton = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    luaOnlyButton:SetSize(82, 24)
    luaOnlyButton:SetPoint("RIGHT", refreshButton, "LEFT", -6, 0)
    luaOnlyButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    luaOnlyButton:SetBackdropColor(0.42 * 0.14, 0.98 * 0.14, 0.56 * 0.14, 0.98)
    luaOnlyButton:SetBackdropBorderColor(0.42, 0.98, 0.56, 0.35)
    local luaOnlyLabel = luaOnlyButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    luaOnlyLabel:SetAllPoints(luaOnlyButton)
    luaOnlyLabel:SetJustifyH("CENTER")
    luaOnlyLabel:SetJustifyV("MIDDLE")
    luaOnlyLabel:SetText("Lua Only")
    luaOnlyLabel:SetTextColor(0.72, 1, 0.80)

    local function ApplyLuaOnlyButtonState(active)
        if active then
            luaOnlyButton:SetBackdropColor(0.42 * 0.32, 0.98 * 0.32, 0.56 * 0.32, 1)
            luaOnlyButton:SetBackdropBorderColor(0.42, 0.98, 0.56, 1)
            luaOnlyLabel:SetTextColor(0.60, 1, 0.70)
        else
            luaOnlyButton:SetBackdropColor(0.42 * 0.14, 0.98 * 0.14, 0.56 * 0.14, 0.98)
            luaOnlyButton:SetBackdropBorderColor(0.42, 0.98, 0.56, 0.35)
            luaOnlyLabel:SetTextColor(0.72, 1, 0.80)
        end
    end

    luaOnlyButton:SetScript("OnClick", function()
        self.showRawOnly = not self.showRawOnly
        ApplyLuaOnlyButtonState(self.showRawOnly)
        self:Refresh()
    end)
    luaOnlyButton:SetScript("OnMouseDown", function(b)
        b:SetBackdropColor(0.42 * 0.40, 0.98 * 0.40, 0.56 * 0.40, 1)
    end)
    luaOnlyButton:SetScript("OnMouseUp", function(b)
        ApplyLuaOnlyButtonState(self.showRawOnly)
    end)

    frame.luaOnlyButton     = luaOnlyButton
    frame.luaOnlyApplyState = ApplyLuaOnlyButtonState

    subtitle:SetPoint("RIGHT", luaOnlyButton, "LEFT", -12, 0)

    -- Source tab bar
    local sourceBar = CreatePanel(frame, 0.055, 0.055, 0.08, 0.985, 0.18)
    sourceBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -68)
    sourceBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -68)
    sourceBar:SetHeight(30)

    -- Log area
    local logPanel = CreatePanel(frame, 0.04, 0.04, 0.06, 0.98, 0.2)
    logPanel:SetPoint("TOPLEFT", sourceBar, "BOTTOMLEFT", 0, -4)
    logPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)

    -- Blue accent on log panel
    local logAccent = logPanel:CreateTexture(nil, "BORDER")
    logAccent:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 1, -1)
    logAccent:SetPoint("BOTTOMLEFT", logPanel, "BOTTOMLEFT", 1, 1)
    logAccent:SetWidth(3)
    logAccent:SetColorTexture(0.42, 0.82, 0.98, 0.5)

    local scroll = CreateFrame("ScrollFrame", nil, logPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", logPanel, "TOPLEFT", 10, -8)
    scroll:SetPoint("BOTTOMRIGHT", logPanel, "BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(_G.ChatFontNormal or GameFontHighlightSmall)
    editBox:SetWidth(860)
    editBox:SetHeight(1800)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetScript("OnTextChanged", function(box)
        local text = box:GetText() or ""
        local _, lineCount = text:gsub("\n", "\n")
        local _, fontHeight = box:GetFont()
        local lineHeight = (fontHeight or 13) + 2
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
    frame.luaOnlyButton = luaOnlyButton
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
            button = CreateFrame("Button", nil, frame.sourceBar, "BackdropTemplate")
            button:SetHeight(22)
            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            button:SetBackdropColor(0.08, 0.09, 0.13, 0.92)
            button:SetBackdropBorderColor(0.30, 0.32, 0.40, 0.42)
            local lbl = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            lbl:SetAllPoints(button)
            lbl:SetJustifyH("CENTER")
            lbl:SetJustifyV("MIDDLE")
            lbl:SetTextColor(0.68, 0.70, 0.78)
            button.__twichuiLabel = lbl
            button:SetScript("OnMouseDown", function(b) b:SetBackdropColor(0.14, 0.15, 0.20, 1.0) end)
            button:SetScript("OnMouseUp", function(b) b:SetBackdropColor(0.08, 0.09, 0.13, 0.92) end)
            frame.sourceButtons[index] = button
        end

        local source = self.sources[key]
        local labelText = source.title or key
        button:SetWidth(max(80, #labelText * 7 + 18))
        button.__twichuiLabel:SetText(labelText)
        button:SetPoint("LEFT", previous or frame.sourceBar, previous and "RIGHT" or "LEFT", previous and 6 or 8, 0)
        button:SetScript("OnClick", function()
            self:Show(key)
        end)

        if self.activeSourceKey == key then
            -- Active tab: bright gold background + full-strength border
            button:SetBackdropColor(0.22, 0.17, 0.04, 1.0)
            button:SetBackdropBorderColor(0.98, 0.76, 0.22, 1.0)
            button.__twichuiLabel:SetTextColor(1.0, 0.95, 0.78)
            button:EnableMouse(false)
            button:SetAlpha(1.0)
        else
            -- Inactive: fully uniform style across all tabs regardless of capture state.
            button:SetBackdropColor(0.08, 0.09, 0.13, 0.92)
            button:SetBackdropBorderColor(0.30, 0.32, 0.40, 0.42)
            button.__twichuiLabel:SetTextColor(0.68, 0.70, 0.78)
            button:SetAlpha(1.0)
            button:EnableMouse(true)
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

    -- Lua Only mode: show the last logged entry stripped of its [HH:MM:SS] prefix.
    -- This gives a clean, timestampless blob ready to copy into Lua files.
    if self.showRawOnly then
        local buffer = self:GetLines(key)
        local lastEntry = buffer[#buffer]
        if lastEntry then
            local raw = lastEntry:gsub("^%[%d%d:%d%d:%d%d%] ", "", 1)
            frame.editBox:SetText(raw)
        else
            frame.editBox:SetText("-- No output captured yet for this source.")
        end
    else
        frame.editBox:SetText(self:BuildSourceText(key))
    end

    -- Keep toggle button visual state in sync (frame may have just been created).
    if frame.luaOnlyApplyState then
        frame.luaOnlyApplyState(self.showRawOnly)
    end

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
