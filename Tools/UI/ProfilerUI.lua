--[[
    TwichUI Profiler UI Viewer
    A visual frame displaying profiling results with charts and metrics.
    Shows the worst performing functions with color-coded severity indicators.
]]

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
local math = math
local pairs = pairs
local pcall = pcall
local table = table
local type = type
local format = string.format

-- Theme colors
local CLR_ACCENT = { 0.10, 0.79, 0.77 } -- teal
local CLR_GOLD = { 0.98, 0.76, 0.22 }   -- gold
local CLR_GOOD = { 0.30, 0.80, 0.30 }   -- green
local CLR_WARN = { 0.98, 0.76, 0.22 }   -- yellow/orange
local CLR_BAD = { 0.98, 0.56, 0.50 }    -- red
local CLR_BG_DEEP = { 0.03, 0.03, 0.05 }
local CLR_BG_MID = { 0.07, 0.07, 0.10 }
local CLR_BG_PANEL = { 0.05, 0.05, 0.07 }
local CLR_TEXT_HI = { 1.00, 0.95, 0.82 }
local CLR_TEXT_MUT = { 0.55, 0.60, 0.68 }
local CLR_BORDER = { 0.20, 0.25, 0.30 }

local FRAME_W = 920
local FRAME_H = 700
local FRAME_MIN_W = 820
local FRAME_MIN_H = 520
local FRAME_MAX_W = 1600
local FRAME_MAX_H = 1100
local TITLEBAR_H = 52
local ROW_H = 36
local CHART_ROW_H = 28
local INSET = 6

---@class TwichUIProfilerUI
---@field frame Frame|nil
---@field isVisible boolean
---@field rowPool table
---@field sortColumn string
---@field sortDescending boolean
local ProfilerUI = UI.ProfilerUI or {}
UI.ProfilerUI = ProfilerUI
ProfilerUI.rowPool = ProfilerUI.rowPool or {}
ProfilerUI.sortColumn = "totalTime"
ProfilerUI.sortDescending = true

-- Utility: Create a colored panel
local function Panel(parent, r, g, b, a, br, bg_, bb, ba)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(r or 0, g or 0, b or 0, a or 0.95)
    f:SetBackdropBorderColor(br or 0, bg_ or 0, bb or 0, ba or 0.22)
    return f
end

-- Utility: Create a button
local function Btn(parent, w, h, label, r, g, b, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, h)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
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

    btn:SetScript("OnMouseDown", function(s)
        s:SetBackdropColor(r * 0.32, g * 0.32, b * 0.32, 1)
    end)
    btn:SetScript("OnMouseUp", function(s)
        s:SetBackdropColor(dr, dg, db, 0.95)
        if onClick then onClick(s) end
    end)

    return btn
end

-- Utility: Format milliseconds
local function FormatMs(ms)
    if ms < 0.01 then
        return format("%.3f", ms)
    elseif ms < 1 then
        return format("%.2f", ms)
    else
        return format("%.1f", ms)
    end
end

local function FormatKB(kb)
    kb = tonumber(kb) or 0
    return format("%.2f", kb)
end

-- Get severity color based on execution time
local function GetSeverityColor(ms)
    if ms < 0.5 then
        return CLR_GOOD
    elseif ms < 2 then
        return CLR_WARN
    else
        return CLR_BAD
    end
end

-- Create a profile row widget
local function MakeProfileRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(CHART_ROW_H)
    row:SetWidth(FRAME_W - 10)
    row:SetScript("OnEnter", function(self)
        if self.__tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(self.__tooltip, CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    -- Name
    local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    name:SetPoint("LEFT", row, "LEFT", 6, 0)
    name:SetWidth(230)
    name:SetJustifyH("LEFT")
    row.__name = name

    -- Calls
    local calls = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    calls:SetPoint("LEFT", name, "RIGHT", 16, 0)
    calls:SetWidth(60)
    calls:SetJustifyH("RIGHT")
    row.__calls = calls

    -- Total time
    local total = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    total:SetPoint("LEFT", calls, "RIGHT", 12, 0)
    total:SetWidth(70)
    total:SetJustifyH("RIGHT")
    row.__total = total

    -- Average time
    local avg = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    avg:SetPoint("LEFT", total, "RIGHT", 10, 0)
    avg:SetWidth(70)
    avg:SetJustifyH("RIGHT")
    row.__avg = avg

    -- Max time
    local maxVal = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    maxVal:SetPoint("LEFT", avg, "RIGHT", 10, 0)
    maxVal:SetWidth(70)
    maxVal:SetJustifyH("RIGHT")
    row.__max = maxVal

    -- Memory average delta (KB)
    local memAvg = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    memAvg:SetPoint("LEFT", maxVal, "RIGHT", 10, 0)
    memAvg:SetWidth(70)
    memAvg:SetJustifyH("RIGHT")
    row.__memAvg = memAvg

    -- Memory max delta (KB)
    local memMax = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    memMax:SetPoint("LEFT", memAvg, "RIGHT", 10, 0)
    memMax:SetWidth(70)
    memMax:SetJustifyH("RIGHT")
    row.__memMax = memMax

    -- Visual bar
    local bar = CreateFrame("Frame", nil, row, "BackdropTemplate")
    bar:SetPoint("LEFT", memMax, "RIGHT", 10, 0)
    bar:SetWidth(90)
    bar:SetHeight(8)
    bar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    bar:SetBackdropColor(0.1, 0.1, 0.12, 0.8)
    bar:SetBackdropBorderColor(0.3, 0.3, 0.35, 0.4)

    local barFill = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    barFill:SetPoint("LEFT", bar, "LEFT", 1, 0)
    barFill:SetHeight(6)
    barFill:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
    })
    row.__bar = bar
    row.__barFill = barFill

    return row
end

-- Populate a row with profile data
local function PopulateProfileRow(row, profile, maxTime, showMemory)
    if not row or not profile then
        return
    end

    local funcName = profile.name:sub(1, 40)
    row.__name:SetText(funcName)
    row.__calls:SetText(tostring(profile.callCount))
    row.__total:SetText(FormatMs(profile.totalTime))
    row.__avg:SetText(FormatMs(profile.averageTime))
    row.__max:SetText(FormatMs(profile.maxTime))

    -- Update tooltip
    if showMemory then
        row.__memAvg:SetText(FormatKB(profile.memoryAverageDelta))
        row.__memMax:SetText(FormatKB(profile.memoryMaxDelta))
        row.__memAvg:Show()
        row.__memMax:Show()
        row.__tooltip = format(
            "%s\nTotal: %.3f ms | Avg: %.3f ms | Min: %.3f ms | Max: %.3f ms\nMem Avg: %.3f KB | Mem Max: %.3f KB | Mem Last: %.3f KB",
            profile.name,
            profile.totalTime,
            profile.averageTime,
            profile.minTime,
            profile.maxTime,
            tonumber(profile.memoryAverageDelta) or 0,
            tonumber(profile.memoryMaxDelta) or 0,
            tonumber(profile.memoryLastDelta) or 0
        )
    else
        row.__memAvg:SetText("-")
        row.__memMax:SetText("-")
        row.__memAvg:Hide()
        row.__memMax:Hide()
        row.__tooltip = format(
            "%s\nTotal: %.3f ms | Avg: %.3f ms | Min: %.3f ms | Max: %.3f ms",
            profile.name,
            profile.totalTime,
            profile.averageTime,
            profile.minTime,
            profile.maxTime
        )
    end

    -- Color text based on severity
    local color = GetSeverityColor(profile.maxTime)
    row.__max:SetTextColor(color[1], color[2], color[3])

    -- Update bar
    maxTime = maxTime or 1
    local ratio = math.min(1, profile.totalTime / maxTime)
    row.__barFill:SetWidth(90 * ratio)
    row.__barFill:SetBackdropColor(color[1], color[2], color[3], 0.8)
end

-- Build the main display frame
local function BuildFrame()
    if ProfilerUI.frame then
        return ProfilerUI.frame
    end

    local frame = CreateFrame("Frame", "TwichUIProfilerUIFrame", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER", UIParent, "CENTER", 150, -50)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    frame:SetBackdropColor(CLR_BG_DEEP[1], CLR_BG_DEEP[2], CLR_BG_DEEP[3], 0.95)
    frame:SetBackdropBorderColor(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], 0.6)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(FRAME_MIN_W, FRAME_MIN_H, FRAME_MAX_W, FRAME_MAX_H)
    else
        if frame.SetMinResize then
            frame:SetMinResize(FRAME_MIN_W, FRAME_MIN_H)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(FRAME_MAX_W, FRAME_MAX_H)
        end
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    -- Title bar
    local titleBar = Panel(frame, CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], 0.15)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    titleBar:SetHeight(TITLEBAR_H)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    title:SetText("Profiler Results")
    title:SetTextColor(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])

    local status = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("LEFT", title, "RIGHT", 20, 0)
    status:SetText("")
    status:SetTextColor(CLR_TEXT_MUT[1], CLR_TEXT_MUT[2], CLR_TEXT_MUT[3])
    frame.__status = status

    -- Close button
    local closeBtn = Btn(titleBar, 80, 28, "Close", CLR_BAD[1], CLR_BAD[2], CLR_BAD[3], function()
        frame:Hide()
    end)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)

    -- Refresh button
    local refreshBtn = Btn(titleBar, 80, 28, "Refresh", CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3], function()
        ProfilerUI:Refresh()
    end)
    refreshBtn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

    -- Column headers
    local headerPanel = Panel(frame, CLR_BG_MID[1], CLR_BG_MID[2], CLR_BG_MID[3], 0.6)
    headerPanel:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    headerPanel:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    headerPanel:SetHeight(26)
    headerPanel:SetFrameLevel(titleBar:GetFrameLevel() + 2)

    local function MakeHeaderBtn(anchorFrame, anchorPoint, text, width, column)
        local btn = CreateFrame("Button", nil, headerPanel)
        btn:SetWidth(width)
        btn:SetHeight(26)
        btn:EnableMouse(true)

        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetAllPoints(btn)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetText(text)
        label:SetTextColor(CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])
        btn.__label = label
        btn.__baseText = text
        btn.__column = column
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine("Sort by " .. (self.__baseText or "column"), CLR_ACCENT[1], CLR_ACCENT[2], CLR_ACCENT[3])
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            if ProfilerUI.sortColumn == column then
                ProfilerUI.sortDescending = not ProfilerUI.sortDescending
            else
                ProfilerUI.sortColumn = column
                ProfilerUI.sortDescending = true
            end
            ProfilerUI:Refresh()
        end)

        return btn
    end

    local nameHeader = MakeHeaderBtn(headerPanel, "LEFT", "Function Name", 290, "name")
    nameHeader:SetPoint("LEFT", headerPanel, "LEFT", 6, 0)

    local callsHeader = MakeHeaderBtn(nameHeader, "TOPRIGHT", "Calls", 60, "calls")
    callsHeader:SetPoint("LEFT", nameHeader, "RIGHT", 16, 0)

    local totalHeader = MakeHeaderBtn(callsHeader, "TOPRIGHT", "Total (ms)", 70, "totalTime")
    totalHeader:SetPoint("LEFT", callsHeader, "RIGHT", 12, 0)

    local avgHeader = MakeHeaderBtn(totalHeader, "TOPRIGHT", "Avg (ms)", 70, "avgTime")
    avgHeader:SetPoint("LEFT", totalHeader, "RIGHT", 10, 0)

    local maxHeader = MakeHeaderBtn(avgHeader, "TOPRIGHT", "Max (ms)", 70, "maxTime")
    maxHeader:SetPoint("LEFT", avgHeader, "RIGHT", 10, 0)

    local memAvgHeader = MakeHeaderBtn(maxHeader, "TOPRIGHT", "Mem Avg", 70, "memAvg")
    memAvgHeader:SetPoint("LEFT", maxHeader, "RIGHT", 10, 0)

    local memMaxHeader = MakeHeaderBtn(memAvgHeader, "TOPRIGHT", "Mem Max", 70, "memMax")
    memMaxHeader:SetPoint("LEFT", memAvgHeader, "RIGHT", 10, 0)

    local barHeader = MakeHeaderBtn(memMaxHeader, "TOPRIGHT", "Visual", 90, "visual")
    barHeader:SetPoint("LEFT", memMaxHeader, "RIGHT", 10, 0)

    frame.__headers = {
        name = nameHeader,
        calls = callsHeader,
        totalTime = totalHeader,
        avgTime = avgHeader,
        maxTime = maxHeader,
        memAvg = memAvgHeader,
        memMax = memMaxHeader,
        visual = barHeader,
    }

    memAvgHeader.__baseText = "Mem Avg (KB)"
    memAvgHeader.__label:SetText(memAvgHeader.__baseText)
    memMaxHeader.__baseText = "Mem Max (KB)"
    memMaxHeader.__label:SetText(memMaxHeader.__baseText)

    -- Scrollable content area
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "BackdropTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerPanel, "BOTTOMLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    scrollFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    scrollFrame:SetBackdropColor(CLR_BG_PANEL[1], CLR_BG_PANEL[2], CLR_BG_PANEL[3], 0.5)
    scrollFrame:SetBackdropBorderColor(CLR_BORDER[1], CLR_BORDER[2], CLR_BORDER[3], 0.4)

    -- Content container
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    content:SetWidth(FRAME_W - 6)
    content:SetHeight(CHART_ROW_H)
    scrollFrame:SetScrollChild(content)
    frame.__scrollFrame = scrollFrame
    frame.__content = content

    -- Resize grip
    local resizeGrip = CreateFrame("Button", nil, frame)
    resizeGrip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    resizeGrip:SetSize(18, 18)
    resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeGrip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        ProfilerUI:Refresh()
    end)
    frame.__resizeGrip = resizeGrip

    frame:SetScript("OnSizeChanged", function(self)
        if self.__content then
            self.__content:SetWidth(math.max(200, self:GetWidth() - 6))
        end
        if self.__scrollFrame then
            local available = math.max(40, self.__scrollFrame:GetWidth() - 6)
            for i = 1, #ProfilerUI.rowPool do
                local row = ProfilerUI.rowPool[i]
                if row then
                    row:SetWidth(available)
                end
            end
        end
    end)

    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local scroll = self:GetVerticalScroll()
        self:SetVerticalScroll(math.max(0, scroll - delta * 20))
    end)

    ProfilerUI.frame = frame
    return frame
end

-- Refresh the display with current profiler data
function ProfilerUI:Refresh()
    local frame = BuildFrame()
    if not frame then
        return
    end

    local profiler = T.Tools and T.Tools.UI and T.Tools.UI.Profiler
    if not profiler then
        T:Print("[TwichUI] Profiler is unavailable")
        return
    end

    -- Get profile data
    local profileData = profiler:GetProfileData()
    local profiles = profileData.profiles or {}

    -- Sort profiles
    if self.sortColumn == "name" then
        table.sort(profiles, function(a, b)
            if self.sortDescending then
                return a.name > b.name
            else
                return a.name < b.name
            end
        end)
    elseif self.sortColumn == "calls" then
        table.sort(profiles, function(a, b)
            if self.sortDescending then
                return a.callCount > b.callCount
            else
                return a.callCount < b.callCount
            end
        end)
    elseif self.sortColumn == "avgTime" then
        table.sort(profiles, function(a, b)
            if self.sortDescending then
                return a.averageTime > b.averageTime
            else
                return a.averageTime < b.averageTime
            end
        end)
    elseif self.sortColumn == "maxTime" then
        table.sort(profiles, function(a, b)
            if self.sortDescending then
                return a.maxTime > b.maxTime
            else
                return a.maxTime < b.maxTime
            end
        end)
    elseif self.sortColumn == "memAvg" then
        table.sort(profiles, function(a, b)
            local av = tonumber(a.memoryAverageDelta) or 0
            local bv = tonumber(b.memoryAverageDelta) or 0
            if self.sortDescending then
                return av > bv
            else
                return av < bv
            end
        end)
    elseif self.sortColumn == "memMax" then
        table.sort(profiles, function(a, b)
            local av = tonumber(a.memoryMaxDelta) or 0
            local bv = tonumber(b.memoryMaxDelta) or 0
            if self.sortDescending then
                return av > bv
            else
                return av < bv
            end
        end)
    else -- totalTime
        table.sort(profiles, function(a, b)
            if self.sortDescending then
                return a.totalTime > b.totalTime
            else
                return a.totalTime < b.totalTime
            end
        end)
    end

    if frame.__headers then
        local activeArrow = self.sortDescending and " v" or " ^"
        for key, header in pairs(frame.__headers) do
            if header and header.__label and header.__baseText then
                local labelText = header.__baseText
                if key == self.sortColumn then
                    labelText = labelText .. activeArrow
                end
                header.__label:SetText(labelText)
            end
        end
    end

    -- Update status
    local isActive = profileData.isActive and "|cff69b86f◌ RECORDING|r" or "|cffff9a6cSTOPPED|r"
    local memoryEnabled = profileData.memoryProfilingEnabled == true
    frame.__status:SetText(format("%d profiles | %s | Memory: %s",
        profileData.totalProfiles,
        isActive,
        memoryEnabled and "|cff69b86fON|r" or "|cffff9a6cOFF|r"))
    if frame.__headers and frame.__headers.memAvg and frame.__headers.memMax then
        frame.__headers.memAvg:SetShown(memoryEnabled)
        frame.__headers.memMax:SetShown(memoryEnabled)
    end

    -- Calculate max time for bar scaling
    local maxTime = 0
    for _, profile in ipairs(profiles) do
        maxTime = math.max(maxTime, profile.totalTime)
    end
    maxTime = math.max(maxTime, 1)

    -- Clear content
    local content = frame.__content
    if not content then
        return
    end

    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", frame.__scrollFrame, "TOPLEFT", 0, 0)

    content:SetHeight(math.max(CHART_ROW_H, #profiles * CHART_ROW_H))

    -- Recycle or create rows
    for i = 1, #profiles do
        local row = self.rowPool[i]
        if not row then
            row = MakeProfileRow(content)
            self.rowPool[i] = row
        end

        row:ClearAllPoints()
        row:SetWidth(math.max(40, frame.__scrollFrame:GetWidth() - 6))
        row:Show()
        if i == 1 then
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", self.rowPool[i - 1], "BOTTOMLEFT", 0, 0)
        end

        PopulateProfileRow(row, profiles[i], maxTime, memoryEnabled)
    end

    -- Hide unused rows
    for i = #profiles + 1, #self.rowPool do
        self.rowPool[i]:Hide()
    end

    -- Update scroll
    frame.__scrollFrame:SetVerticalScroll(0)
    content:Show()
end

-- Toggle the frame visibility
function ProfilerUI:Toggle()
    local frame = BuildFrame()
    if not frame then return end
    if frame:IsShown() then
        frame:Hide()
    else
        self:Refresh()
        frame:Show()
    end
end

-- Show the frame
function ProfilerUI:Show()
    local frame = BuildFrame()
    if not frame then return end
    self:Refresh()
    frame:Show()
end

-- Hide the frame
function ProfilerUI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
