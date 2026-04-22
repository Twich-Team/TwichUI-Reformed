--[[
    LFG Finder Browser UI - Main frame, rows, and browser mode rendering
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
local LFG = T:GetModule("LFGFinder")

local CreateFrame = _G.CreateFrame
local type = _G.type
local ipairs = _G.ipairs
local wipe = _G.wipe
local format = _G.format
local table = _G.table
local UIParent = _G.UIParent
local GetThrottledCombatFrameElapsed = _G.GetThrottledCombatFrameElapsed

local ROW_HEIGHT = 24
local ROWS_PER_PAGE = 12
local FRAME_WIDTH = 1000
local FRAME_HEIGHT = 400

-- ──────────────────────────────────────────────────────────────────────────────
-- Main Frame Creation
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:CreateMainFrameImpl()
    if self.mainFrame then
        return
    end

    -- Create main window
    local frame = CreateFrame("Frame", "TwichLFGFinder", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("TOPLEFT", _G.LFGListFrame or UIParent, "TOPRIGHT", 4, 0)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:EnableMouse(true)
    frame:SetUserPlaced(false)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:Hide()

    -- ESC closes the frame
    _G["TwichLFGFinder"] = frame
    _G.tinsert(_G.UISpecialFrames, "TwichLFGFinder")

    -- Drag support
    frame:SetScript("OnMouseDown", function(f, btn)
        if btn == "LeftButton" then f:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(f) f:StopMovingOrSizing() end)

    -- Apply theme backdrop
    self:ApplyThemeBackdrop(frame)

    -- Title bar
    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetSize(FRAME_WIDTH - 4, 28)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    self:ApplyThemeTitleBar(titleBar)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(self:GetThemeFont(), 12)
    titleText:SetText("LFG Finder")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleText:SetTextColor(1, 0.95, 0.85)

    -- Mode toggle buttons (Browser / Applicant)
    local browserBtn = CreateFrame("Button", nil, titleBar)
    browserBtn:SetSize(100, 20)
    browserBtn:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
    browserBtn:SetText("Applicant Mode")
    self:ApplyThemeButton(browserBtn)
    browserBtn:SetScript("OnClick", function()
        LFG:SwitchMode("applicant")
    end)

    local applicantBtn = CreateFrame("Button", nil, titleBar)
    applicantBtn:SetSize(100, 20)
    applicantBtn:SetPoint("RIGHT", browserBtn, "LEFT", -8, 0)
    applicantBtn:SetText("Browse Groups")
    self:ApplyThemeButton(applicantBtn)
    applicantBtn:SetScript("OnClick", function()
        LFG:SwitchMode("browser")
    end)

    -- Filter panel (collapsible)
    local filterPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    filterPanel:SetSize(FRAME_WIDTH - 4, 100)
    filterPanel:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -2)
    self:ApplyThemePanel(filterPanel)

    -- Create scroll area for results
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(FRAME_WIDTH - 4, FRAME_HEIGHT - 140)
    scrollFrame:SetPoint("TOPLEFT", filterPanel, "BOTTOMLEFT", 0, -2)

    -- Create content frame for scroll
    local contentFrame = CreateFrame("Frame")
    contentFrame:SetSize(FRAME_WIDTH - 20, FRAME_HEIGHT)
    scrollFrame:SetScrollChild(contentFrame)

    -- Create row pool
    local rowPool = {}
    for i = 1, ROWS_PER_PAGE do
        local row = self:CreateResultRow(contentFrame, i)
        table.insert(rowPool, row)
    end

    -- Store references
    self.mainFrame = frame
    self.filterPanel = filterPanel
    self.scrollFrame = scrollFrame
    self.contentFrame = contentFrame
    self.rowPool = rowPool
    self.titleBar = titleBar
    self.browserBtn = browserBtn
    self.applicantBtn = applicantBtn

    -- Render initial content
    self:RefreshBrowserUIImpl()
end

--- Creates a single result row frame
function LFG:CreateResultRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetSize(parent:GetWidth(), ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

    -- Background
    row:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })

    -- Columns
    local dungeon = row:CreateFontString(nil, "OVERLAY")
    dungeon:SetSize(150, ROW_HEIGHT)
    dungeon:SetPoint("LEFT", row, "LEFT", 4, 0)
    dungeon:SetJustifyH("LEFT")

    local leader = row:CreateFontString(nil, "OVERLAY")
    leader:SetSize(120, ROW_HEIGHT)
    leader:SetPoint("LEFT", dungeon, "RIGHT", 8, 0)
    leader:SetJustifyH("LEFT")

    local composition = row:CreateFontString(nil, "OVERLAY")
    composition:SetSize(100, ROW_HEIGHT)
    composition:SetPoint("LEFT", leader, "RIGHT", 8, 0)
    composition:SetJustifyH("CENTER")

    local rating = row:CreateFontString(nil, "OVERLAY")
    rating:SetSize(70, ROW_HEIGHT)
    rating:SetPoint("LEFT", composition, "RIGHT", 8, 0)
    rating:SetJustifyH("CENTER")

    local age = row:CreateFontString(nil, "OVERLAY")
    age:SetSize(70, ROW_HEIGHT)
    age:SetPoint("LEFT", rating, "RIGHT", 8, 0)
    age:SetJustifyH("CENTER")

    -- Apply signups button
    local applyBtn = CreateFrame("Button", nil, row)
    applyBtn:SetSize(70, ROW_HEIGHT - 4)
    applyBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    applyBtn:SetText("Apply")
    self:ApplyThemeButton(applyBtn)
    applyBtn:SetScript("OnClick", function()
        LFG:ApplyToGroup(row.result)
    end)

    return {
        frame = row,
        dungeon = dungeon,
        leader = leader,
        composition = composition,
        rating = rating,
        age = age,
        applyBtn = applyBtn,
        result = nil,
    }
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Browser UI Rendering
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:RefreshBrowserUIImpl()
    -- Frame not yet created or already destroyed
    if not self.rowPool then return end

    -- Filter results
    local filteredResults = {}
    for _, result in ipairs(self.searchResults or {}) do
        if self:ResultPassesFilters(result) then
            table.insert(filteredResults, result)
        end
    end

    -- Render rows
    for i, row in ipairs(self.rowPool) do
        if filteredResults[i] then
            local result = filteredResults[i]
            row.result = result

            -- Populate columns
            row.dungeon:SetText(result.activityName or "Unknown")
            row.leader:SetText(result.leaderName or "Unknown")
            row.composition:SetText(self:FormatComposition(result.roleCounts))
            row.rating:SetText(format("%d", result.rating or 0))
            row.age:SetText(self:FormatAge(result.age or 0))

            -- Color the row based on applied status
            if result.isApplied then
                row.frame:SetBackdropColor(0.10, 0.30, 0.10, 0.3)
                row.applyBtn:SetText("Applied")
                row.applyBtn:Disable()
            else
                row.frame:SetBackdropColor(0.1, 0.1, 0.1, 0.3)
                row.applyBtn:SetText("Apply")
                row.applyBtn:Enable()
            end

            row.frame:Show()
        else
            row.frame:Hide()
        end
    end

    -- Update footer with count
    if self.footerText then
        self.footerText:SetFormattedText("Showing %d of %d groups", #filteredResults, #self.searchResults)
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Theme Integration
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:GetThemeModule()
    if self._themeCache then return self._themeCache end
    self._themeCache = T:GetModule("Theme", true)
    return self._themeCache
end

function LFG:GetThemeColor(key, fallback)
    local theme = self:GetThemeModule()
    if theme and type(theme.GetColor) == "function" then
        local c = theme:GetColor(key)
        if type(c) == "table" then
            return c[1] or 0.1, c[2] or 0.72, c[3] or 0.74
        end
    end
    if fallback then
        return fallback[1], fallback[2], fallback[3]
    end
    return 0.1, 0.72, 0.74
end

function LFG:GetThemeFont()
    local theme = self:GetThemeModule()
    if theme and type(theme.Get) == "function" then
        local fontName = theme:Get("globalFont")
        if fontName and fontName ~= "__default" then
            local LSM = T.Libs and T.Libs.LSM
            if LSM then
                return LSM:Fetch("font", fontName) or _G.STANDARD_TEXT_FONT
            end
        end
    end
    return _G.STANDARD_TEXT_FONT
end

function LFG:ApplyThemeBackdrop(frame)
    local theme = self:GetThemeModule()
    if not theme then return end

    local bg = theme:GetColor("backgroundColor") or { 0.05, 0.06, 0.08 }
    local border = theme:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    local bgAlpha = theme:Get("backgroundAlpha") or 0.94
    local borderAlpha = theme:Get("borderAlpha") or 0.85

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 12,
    })
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bgAlpha)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], borderAlpha)
end

function LFG:ApplyThemeTitleBar(frame)
    local theme = self:GetThemeModule()
    if not theme then return end

    local primary = theme:GetColor("primaryColor") or { 0.10, 0.72, 0.74 }

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    })
    frame:SetBackdropColor(primary[1] * 0.3, primary[2] * 0.3, primary[3] * 0.3, 0.5)
end

function LFG:ApplyThemePanel(frame)
    local theme = self:GetThemeModule()
    if not theme then return end

    local bg = theme:GetColor("backgroundColor") or { 0.05, 0.06, 0.08 }

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    frame:SetBackdropColor(bg[1] * 1.2, bg[2] * 1.2, bg[3] * 1.2, 0.6)
end

function LFG:ApplyThemeButton(btn)
    local theme = self:GetThemeModule()
    if not theme then return end

    local accent = theme:GetColor("accentColor") or { 0.96, 0.76, 0.24 }

    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:GetFontString():SetTextColor(1, 0.95, 0.85)

    -- Create text if not exists
    if not btn:GetFontString() then
        local fs = btn:CreateFontString()
        fs:SetFont(self:GetThemeFont(), 10)
        fs:SetPoint("CENTER", btn, "CENTER")
    end
end

function LFG:RefreshFrameAppearanceImpl()
    if not self.mainFrame then return end

    self:ApplyThemeBackdrop(self.mainFrame)
    self:ApplyThemeTitleBar(self.titleBar)
    self:ApplyThemePanel(self.filterPanel)
    self:RefreshBrowserUIImpl()
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Helper Functions
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:FormatComposition(roleCounts)
    local t = roleCounts.TANK or 0
    local h = roleCounts.HEALER or 0
    local d = roleCounts.DAMAGER or 0
    return format("%dT %dH %dD", t, h, d)
end

function LFG:FormatAge(ageSeconds)
    if ageSeconds < 60 then
        return "now"
    elseif ageSeconds < 3600 then
        return format("%dm", math.floor(ageSeconds / 60))
    elseif ageSeconds < 86400 then
        return format("%dh", math.floor(ageSeconds / 3600))
    else
        return format("%dd", math.floor(ageSeconds / 86400))
    end
end

function LFG:ApplyToGroup(result)
    if not result then return end

    -- Use Blizzard's apply API
    local categoryID = C_LFGList.GetSelectedSearchCategory()
    if categoryID then
        C_LFGList.ApplyToGroup(result.id)
    end
end
