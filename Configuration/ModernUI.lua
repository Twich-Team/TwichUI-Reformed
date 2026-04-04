---@diagnostic disable: undefined-field, inject-field, invisible
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local UI = ConfigurationModule.StandaloneUI or {}
ConfigurationModule.StandaloneUI = UI

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local ColorPickerFrame = _G.ColorPickerFrame
local PlaySoundFile = _G.PlaySoundFile
local LibStub = _G.LibStub
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local Textures = T.Tools and T.Tools.Textures
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local unpackValues = table.unpack or _G.unpack

local FRAME_WIDTH = 1280
local FRAME_HEIGHT = 800
local SIDEBAR_WIDTH = 248
local PREVIEW_WIDTH = 368
local ROW_SPACING = 10

local NAV_ITEMS = {
    {
        id = "dashboard",
        title = "Overview",
        description = "Featured systems, previews, and shortcuts.",
        accent = { 0.97, 0.76, 0.24 },
    },
    {
        id = "theme",
        title = "Appearance",
        description = "Shared color palette, surface opacity, and config sound profile.",
        accent = { 0.10, 0.72, 0.74 },
        path = { "Theme" },
    },
    {
        id = "bestInSlot",
        title = "Best In Slot",
        description = "Loot tracking and item workflow preferences.",
        accent = { 0.45, 0.78, 1.0 },
        path = { "Best In Slot" },
    },
    {
        id = "actionBars",
        title = "Action Bars",
        description = "Primary bars, extra bars, pet bar, stance bar, movers, and button text controls.",
        accent = { 0.98, 0.68, 0.26 },
        path = { "Action Bars" },
    },
    {
        id = "chat",
        title = "Chat",
        description = "Messaging polish and interaction helpers.",
        accent = { 0.81, 0.58, 0.95 },
        path = { "Chat" },
    },
    {
        id = "datatexts",
        title = "Data Panels",
        description = "Panel layout, datatext customization, and related shortcuts.",
        accent = { 0.44, 0.82, 0.98 },
        path = { "DataTexts" },
    },
    {
        id = "mythicPlusTools",
        title = "Mythic+ Tools",
        description = "Timer, interrupts, keystone helpers, and dungeon-focused notifications.",
        accent = { 0.48, 0.82, 1.0 },
        path = { "Mythic+ Tools" },
    },
    {
        id = "notifications",
        title = "Notifications",
        description = "Visual delivery, sounds, and per-feature toasts.",
        accent = { 0.42, 0.89, 0.63 },
        path = { "Notification Panel" },
    },
    {
        id = "errorLog",
        title = "Error Log",
        description = "Captured TwichUI errors, notification behavior, and log retention settings.",
        accent = { 0.98, 0.56, 0.50 },
        path = { "Error Log" },
    },
    {
        id = "profiles",
        title = "Profiles",
        description = "Profile storage and switching.",
        accent = { 0.78, 0.82, 0.88 },
        path = { "profile" },
    },
    {
        id = "qualityOfLife",
        title = "Quality of Life",
        description = "Chores, smart mount, easy fish, teleports, and daily-use tools.",
        accent = { 0.98, 0.68, 0.26 },
        path = { "Quality of Life" },
    },
    {
        id = "unitFrames",
        title = "Unit Frames",
        description = "Configure your health bars, target frame, and party and raid frames.",
        accent = { 0.91, 0.45, 0.45 },
        path = { "unitFrames" },
    },
}

local FEATURE_CARDS = {
    {
        title = "Chores Tracker",
        subtitle = "Pinned tracker styling, weekly visibility, and quick access to the systems you check every reset.",
        accent = { 0.98, 0.76, 0.2 },
        pageId = "qualityOfLife",
        path = { "Quality of Life", "choresTab", "trackerFrame" },
        status = function()
            local options = ConfigurationModule.Options and ConfigurationModule.Options.Chores
            if not options then
                return "Unavailable"
            end

            local keybinding = options.GetTrackerFrameConfigKeybinding and options:GetTrackerFrameConfigKeybinding() or
                ""
            return ("Toggle: %s"):format(keybinding ~= "" and keybinding or "Not bound")
        end,
        actionLabel = "Preview",
        action = function()
            local datatextModule = T:GetModule("Datatexts")
            local choresDataText = datatextModule and datatextModule.GetModule and
                datatextModule:GetModule("ChoresDataText", true)
            if choresDataText and choresDataText.ShowTrackerFrame then
                choresDataText:ShowTrackerFrame()
            end
        end,
    },
    {
        title = "Smart Mount",
        subtitle = "Spotlight flight, ground, and travel-form routing without digging through the full tree.",
        accent = { 0.46, 0.83, 0.98 },
        pageId = "qualityOfLife",
        path = { "Quality of Life", "smartMountTab" },
        status = function()
            local options = ConfigurationModule.Options and ConfigurationModule.Options.SmartMount
            if not options then
                return "Unavailable"
            end

            local binding = options.GetSmartMountKeybinding and options:GetSmartMountKeybinding() or ""
            return ("%s%s"):format(
                options.GetEnabled and options:GetEnabled() and "Enabled" or "Disabled",
                binding ~= "" and ("  •  Toggle: " .. binding) or "")
        end,
    },
    {
        title = "Easy Fish",
        subtitle = "Surface the one-button fishing flow, keybind, and sound controls right from the overview.",
        accent = { 0.42, 0.89, 0.63 },
        pageId = "qualityOfLife",
        path = { "Quality of Life", "easyFishTab" },
        status = function()
            local options = ConfigurationModule.Options and ConfigurationModule.Options.EasyFish
            if not options then
                return "Unavailable"
            end

            local binding = options.GetEasyFishKeybinding and options:GetEasyFishKeybinding() or ""
            return ("%s%s"):format(
                options.GetEnabled and options:GetEnabled() and "Enabled" or "Disabled",
                binding ~= "" and ("  •  Cast: " .. binding) or "")
        end,
    },
    {
        title = "Setup Wizard",
        subtitle = "Re-run the onboarding flow whenever you want to re-apply a layout or theme preset.",
        accent = { 0.95, 0.77, 0.28 },
        status = function()
            local wizard = T:GetModule("SetupWizard", true)
            if not wizard then
                return "Unavailable"
            end

            return wizard:ShouldShow() and "Ready to run" or "Completed"
        end,
        actionLabel = "Toggle Wizard",
        action = function()
            local wizard = T:GetModule("SetupWizard", true)
            if wizard and wizard.Toggle then
                wizard:Toggle()
            end
        end,
    },
    {
        title = "Notification Panel",
        subtitle = "Tune toast styling and quickly jump into your notification categories.",
        accent = { 0.42, 0.89, 0.63 },
        pageId = "notifications",
        path = { "Notification Panel" },
        status = function()
            local options = ConfigurationModule.Options and ConfigurationModule.Options.NotificationPanel
            if not options then
                return "Unavailable"
            end

            local width = options.GetPanelWidth and options:GetPanelWidth() or 0
            local maxToasts = options.GetMaxToasts and options:GetMaxToasts() or 0
            return ("Width %d | Max %d toasts"):format(width, maxToasts)
        end,
    },
    {
        title = "Currency Panels",
        subtitle = "Control data panel currency display styles and tooltip behavior.",
        accent = { 0.44, 0.82, 0.98 },
        pageId = "datatexts",
        path = { "DataTexts", "currencies" },
        status = function()
            local options = ConfigurationModule.Options and ConfigurationModule.Options.Datatext
            if not options then
                return "Unavailable"
            end

            local displayed = options.GetDisplayedCurrency and options:GetDisplayedCurrency() or "GOLD"
            return ("Displayed: %s"):format(tostring(displayed))
        end,
    },
}

local PAGE_NAME_OVERRIDES = {
    ["Quality of Life"] = {
        choresTab = "Chores and Weeklies",
        dungeonTrackingTab = "Dungeon Wrap-Up",
        mythicPlusToolsTab = "Mythic+ Tools",
        gatheringTab = "Gathering",
        easyFishTab = "Easy Fishing",
        gossipHotkeysTab = "Gossip Hotkeys",
        preyTweaksTab = "Prey Tweaks",
        questAutomationTab = "Quest Automation",
        questLogCleanerTab = "Quest Log Cleaner",
        satchelWatchTab = "Satchel Watch",
        smartMountTab = "Smart Mount",
        teleportsTab = "Teleports",
        worldQuestsTab = "World Quests",
    },
    ["Notification Panel"] = {
        displayGroup = "Display",
        friends      = "Friends",
        mythicPlus   = "Mythic+",
        scheduled    = "Scheduled",
        content      = "Content",
        gathering    = "Gathering",
        bestInSlot   = "Best In Slot",
    },
    unitFrames = {
        singles = "Single Units",
        groups = "Group Units",
        castbar = "Castbar",
        generalGroup = "General",
        colors = "Colors",
    },
}

local TAB_SECTION_OVERRIDES = {
    ["Quality of Life"] = {
        {
            title = "Weeklies and Schedules",
            keys = { "choresTab", "satchelWatchTab", "dungeonTrackingTab" },
        },
        {
            title = "Combat and Encounters",
            keys = { "mythicPlusToolsTab", "preyTweaksTab" },
        },
        {
            title = "Professions and Gathering",
            keys = { "gatheringTab", "easyFishTab" },
        },
        {
            title = "Travel and Interaction",
            keys = { "gossipHotkeysTab", "smartMountTab", "teleportsTab", "worldQuestsTab" },
        },
        {
            title = "Automation and Cleanup",
            keys = { "questAutomationTab", "questLogCleanerTab" },
        },
    },
}

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, result = pcall(func, ...)
    if ok then
        return result
    end

    local errorLog = T.Tools and (T.Tools --[[@as any]]).ErrorLog
    if errorLog and type(errorLog.CaptureFailure) == "function" then
        errorLog:CaptureFailure("Configuration.ModernUI.SafeCall", result, 3)
    end

    return nil
end

local function ClonePath(path)
    local copy = {}
    for i, value in ipairs(path or {}) do
        copy[i] = value
    end
    return copy
end

local function JoinPath(path)
    return table.concat(path or {}, ".")
end

local function BuildInfoPath(path, key)
    local info = ClonePath(path)
    info[#info + 1] = key
    return info
end

local function MatchesFilter(text, filter)
    if not filter or filter == "" then
        return true
    end

    text = tostring(text or ""):lower()
    filter = tostring(filter or ""):lower()
    return text:find(filter, 1, true) ~= nil
end

local function CreatePanel(parent, r, g, b, a, borderA)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(r or 0.08, g or 0.08, b or 0.1, a or 0.96)
    frame:SetBackdropBorderColor(0.94, 0.77, 0.28, borderA or 0.22)
    return frame
end

local function SkinActionButton(button, color)
    local r, g, b = unpackValues(color or { 0.96, 0.76, 0.24 })
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(r * 0.22, g * 0.22, b * 0.22, 0.98)
    button:SetBackdropBorderColor(r, g, b, 0.42)
    button:SetNormalTexture("")
    button:SetPushedTexture("")
    button:SetHighlightTexture("")
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")
    button:SetScript("OnMouseDown", function(self)
        self:SetBackdropColor(r * 0.32, g * 0.32, b * 0.32, 1)
    end)
    button:SetScript("OnMouseUp", function(self)
        if self:IsMouseOver() then
            self:SetBackdropColor(r * 0.30, g * 0.30, b * 0.30, 0.98)
        else
            self:SetBackdropColor(r * 0.22, g * 0.22, b * 0.22, 0.98)
        end
    end)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(r * 0.30, g * 0.30, b * 0.30, 0.98)
        self:SetBackdropBorderColor(r, g, b, 0.78)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(r * 0.22, g * 0.22, b * 0.22, 0.98)
        self:SetBackdropBorderColor(r, g, b, 0.42)
    end)
end

local function SkinScrollArrowButton(button, color, glyph)
    if not button then
        return
    end

    local r, g, b = unpackValues(color or { 0.96, 0.76, 0.24 })
    button:Show()
    button:SetSize(16, 16)
    button:SetNormalTexture("")
    button:SetPushedTexture("")
    button:SetHighlightTexture("")
    button:SetDisabledTexture("")

    if not button.Chrome then
        local chromeParent = button
        if not button.SetBackdrop then
            chromeParent = CreateFrame("Frame", nil, button, "BackdropTemplate")
            chromeParent:SetAllPoints(button)
            chromeParent:EnableMouse(false)
            button.Chrome = chromeParent
        else
            button.Chrome = button
        end

        button.Chrome:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    button.Chrome:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 0.96)
    button.Chrome:SetBackdropBorderColor(r, g, b, 0.35)

    if not button.Glyph then
        local glyphParent = button.Chrome ~= button and button.Chrome or button
        button.Glyph = glyphParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.Glyph:SetPoint("CENTER", glyphParent, "CENTER", 0, 0)
    end

    button.Glyph:SetText(glyph or "")
    button.Glyph:SetTextColor(1, 0.95, 0.82)
    button:SetScript("OnMouseDown", function(self)
        if self.Chrome and self.Chrome.SetBackdropColor then
            self.Chrome:SetBackdropColor(r * 0.28, g * 0.28, b * 0.28, 1)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.Chrome and self.Chrome.SetBackdropColor then
            self.Chrome:SetBackdropColor(r * 0.18, g * 0.18, b * 0.18, 0.96)
        end
    end)
end

local function SetButtonText(button, text, wrap)
    if not button then
        return
    end

    button:SetText(text or "")

    local fontString = button:GetFontString()
    if not fontString then
        return
    end

    fontString:ClearAllPoints()
    fontString:SetPoint("TOPLEFT", button, "TOPLEFT", 8, -4)
    fontString:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -8, 4)
    fontString:SetJustifyH("CENTER")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetWordWrap(wrap == true)
    if fontString.SetMaxLines then
        fontString:SetMaxLines(wrap and 2 or 1)
    end
end

local function MeasureButtonWidth(label, minWidth, maxWidth)
    local text = tostring(label or "")
    return math.max(minWidth or 90, math.min(maxWidth or 260, 36 + (#text * 7)))
end

local function SkinScrollBar(scrollFrame, color, hideButtons)
    if not scrollFrame then
        return
    end

    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar then
        return
    end

    local r, g, b = unpackValues(color or { 0.98, 0.76, 0.22 })
    scrollBar:SetWidth(16)

    if scrollBar.ScrollUpButton then
        if hideButtons then
            scrollBar.ScrollUpButton:Hide()
            scrollBar.ScrollUpButton:EnableMouse(false)
        else
            SkinScrollArrowButton(scrollBar.ScrollUpButton, color, "^")
            scrollBar.ScrollUpButton:ClearAllPoints()
            scrollBar.ScrollUpButton:SetPoint("TOP", scrollBar, "TOP", 0, -1)
            scrollBar.ScrollUpButton:Show()
            scrollBar.ScrollUpButton:EnableMouse(true)
        end
    end
    if scrollBar.ScrollDownButton then
        if hideButtons then
            scrollBar.ScrollDownButton:Hide()
            scrollBar.ScrollDownButton:EnableMouse(false)
        else
            SkinScrollArrowButton(scrollBar.ScrollDownButton, color, "v")
            scrollBar.ScrollDownButton:ClearAllPoints()
            scrollBar.ScrollDownButton:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 1)
            scrollBar.ScrollDownButton:Show()
            scrollBar.ScrollDownButton:EnableMouse(true)
        end
    end

    if not scrollBar.Track then
        scrollBar.Track = scrollBar:CreateTexture(nil, "BACKGROUND")
        scrollBar.Track:SetColorTexture(0.08, 0.09, 0.12, 0.9)
    end
    scrollBar.Track:ClearAllPoints()
    if (not hideButtons) and scrollBar.ScrollUpButton and scrollBar.ScrollDownButton then
        scrollBar.Track:SetPoint("TOPLEFT", scrollBar.ScrollUpButton, "BOTTOMLEFT", 2, -4)
        scrollBar.Track:SetPoint("BOTTOMRIGHT", scrollBar.ScrollDownButton, "TOPRIGHT", -2, 4)
    else
        scrollBar.Track:SetPoint("TOPLEFT", scrollBar, "TOPLEFT", 2, -2)
        scrollBar.Track:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMRIGHT", -2, 2)
    end

    if not scrollBar.Glow then
        scrollBar.Glow = scrollBar:CreateTexture(nil, "ARTWORK")
        scrollBar.Glow:SetColorTexture(r, g, b, 0.08)
    end
    scrollBar.Glow:ClearAllPoints()
    scrollBar.Glow:SetPoint("TOPLEFT", scrollBar.Track, "TOPLEFT", 0, 0)
    scrollBar.Glow:SetPoint("BOTTOMRIGHT", scrollBar.Track, "BOTTOMRIGHT", 0, 0)

    local thumb = scrollBar.ThumbTexture or scrollBar:GetThumbTexture()
    if thumb then
        scrollBar.ThumbTexture = thumb
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetSize(10, 26)
        thumb:SetVertexColor(r, g, b, 0.95)
    end

    if scrollBar.SetBackdrop then
        scrollBar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        scrollBar:SetBackdropColor(0.05, 0.05, 0.07, 0.9)
        scrollBar:SetBackdropBorderColor(r, g, b, 0.2)
    end
end

local function SkinIconButton(button, color)
    SkinActionButton(button, color)
    button.Icon = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    button.Icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.Icon:SetTextColor(1, 0.92, 0.8)
end

local function AttachTooltip(button, title, text)
    if not button then
        return
    end

    button:SetScript("OnEnter", function(self)
        if not _G.GameTooltip or not _G.GameTooltip.SetOwner then
            return
        end

        _G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        if title and title ~= "" then
            _G.GameTooltip:AddLine(title, 1, 0.95, 0.82)
        end
        if text and text ~= "" then
            _G.GameTooltip:AddLine(text, 0.72, 0.74, 0.8, true)
        end
        _G.GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if _G.GameTooltip and _G.GameTooltip.Hide then
            _G.GameTooltip:Hide()
        end
    end)
end

-- Place a tool panel (DebugConsole, ErrorLogViewer) neatly beside the config frame.
-- Picks the side with the most available screen space, accounting for the preview host.
local function SmartPositionNextToConfig(toolPanel)
    local frame = UI:EnsureFrame()
    if not frame or not toolPanel then return end

    local rightAnchor = (frame.PreviewHost and frame.PreviewHost:IsShown())
        and frame.PreviewHost or frame

    local screenW     = UIParent:GetWidth()
    local screenH     = UIParent:GetHeight()
    local GAP         = 10
    local STACK_GAP   = 8

    local rx          = rightAnchor:GetRight() or (screenW * 0.5 + 100)
    local lx          = frame:GetLeft() or (screenW * 0.5 - 100)
    local configTop   = frame:GetTop() or screenH

    local spaceRight  = screenW - rx - GAP
    local spaceLeft   = lx - GAP

    -- Preferred side: whichever has more free horizontal space.
    local useRight    = spaceRight >= spaceLeft

    -- Top of the first panel on this side aligns with the config frame top.
    local topY        = math.min(configTop, screenH - 6)

    -- Collect sibling tool panels (DebugConsole / ErrorLogViewer) that are
    -- already visible so we can stack below them rather than overlap.
    local otherPanels = {}
    local dc          = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    local elv         = T.Tools and T.Tools.UI and T.Tools.UI.ErrorLogViewer
    for _, sibling in ipairs({ dc and dc.frame, elv and elv.frame }) do
        if sibling and sibling ~= toolPanel and sibling:IsShown() then
            otherPanels[#otherPanels + 1] = sibling
        end
    end

    -- Detect whether any sibling is already on the preferred side, and if so
    -- stack below the lowest of them.
    local lowestBottom = nil
    for _, other in ipairs(otherPanels) do
        local otherLeft = other:GetLeft() or 0
        local onRight   = otherLeft >= rx - 20
        local onLeft    = (other:GetRight() or screenW) <= lx + 20
        if (useRight and onRight) or (not useRight and onLeft) then
            local b = other:GetBottom() or topY
            if lowestBottom == nil or b < lowestBottom then
                lowestBottom = b
            end
        end
    end

    local placeTopY = lowestBottom and (lowestBottom - STACK_GAP) or topY

    toolPanel:ClearAllPoints()
    if useRight then
        toolPanel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", rx + GAP, placeTopY)
    else
        toolPanel:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", lx - GAP, placeTopY)
    end
end

local function BeginConfigFrameDrag(frame)
    if not frame or frame.isDragging then
        return
    end

    frame.isDragging = true
    frame:StartMoving()
end

local function EndConfigFrameDrag(frame)
    if not frame or not frame.isDragging then
        return
    end

    frame.isDragging = nil
    frame:StopMovingOrSizing()

    local centerX, centerY = frame:GetCenter()
    if not (centerX and centerY) then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", centerX, centerY)
end

local function GetOrderedEntries(section)
    local ordered = {}
    for key, option in pairs(section and section.args or {}) do
        ordered[#ordered + 1] = {
            key = key,
            option = option,
            order = type(option.order) == "number" and option.order or 1000,
        }
    end

    table.sort(ordered, function(left, right)
        if left.order == right.order then
            return tostring(left.key) < tostring(right.key)
        end
        return left.order < right.order
    end)

    return ordered
end

local function GetSectionByPath(root, path)
    local node = root
    for _, key in ipairs(path or {}) do
        if not node or not node.args then
            return nil
        end
        node = node.args[key]
    end
    return node
end

local function GetInheritedHandler(path, fallbackSection)
    local currentPath = ClonePath(path or {})
    local currentSection = fallbackSection or GetSectionByPath(ConfigurationModule.optionsTable, currentPath)

    while currentSection do
        if currentSection.handler ~= nil then
            return currentSection.handler
        end
        if #currentPath == 0 then
            break
        end
        table.remove(currentPath)
        currentSection = GetSectionByPath(ConfigurationModule.optionsTable, currentPath)
    end

    return nil
end

local function BuildOptionInfo(path, key, option, parentSection)
    local info = BuildInfoPath(path, key)
    local parent = parentSection or GetSectionByPath(ConfigurationModule.optionsTable, path)
    info.option = option
    info.arg = option and option.arg or nil
    info.handler = (option and option.handler) or GetInheritedHandler(path, parent)
    return info
end

local function BuildSectionInfo(path, section)
    local info = ClonePath(path)
    info.option = section
    info.arg = section and section.arg or nil
    info.handler = (section and section.handler) or GetInheritedHandler(path, section)
    return info
end

local function ResolveOptionMethod(option, info, ...)
    local handler = (option and option.handler) or (info and info.handler) or nil
    local method = option and option.get or nil
    if select("#", ...) > 0 then
        method = option and option.set or nil
    end

    if type(method) == "function" then
        return method(info, ...)
    end

    if type(method) == "string" and handler and type(handler[method]) == "function" then
        return handler[method](handler, info, ...)
    end

    return nil
end

local function IsOptionHidden(option, info)
    local hidden = option and option.hidden
    if type(hidden) == "function" then
        local resolved = SafeCall(hidden, info)
        if resolved ~= nil then
            return resolved == true
        end
        return false
    end
    if type(hidden) == "string" then
        local handler = (option and option.handler) or (info and info.handler) or nil
        if handler and type(handler[hidden]) == "function" then
            return handler[hidden](handler, info) == true
        end
    end
    return hidden == true
end

local function IsOptionDisabled(option, info)
    local disabled = option and option.disabled
    if type(disabled) == "function" then
        local resolved = SafeCall(disabled, info)
        if resolved ~= nil then
            return resolved == true
        end
        return false
    end
    if type(disabled) == "string" then
        local handler = (option and option.handler) or (info and info.handler) or nil
        if handler and type(handler[disabled]) == "function" then
            return handler[disabled](handler, info) == true
        end
    end
    return disabled == true
end

local function ResolveTextValue(value, info)
    if type(value) == "function" then
        local resolved = SafeCall(value, info)
        if resolved ~= nil then
            return tostring(resolved)
        end
        return ""
    end
    if type(value) == "string" and info and info.handler and type(info.handler[value]) == "function" then
        local resolved = SafeCall(info.handler[value], info.handler, info)
        if resolved ~= nil then
            return tostring(resolved)
        end
        return ""
    end
    if value == nil then
        return ""
    end
    return tostring(value)
end

local function ResolveOptionValues(option, info)
    local values = option and option.values
    if type(values) == "function" then
        local handler = (option and option.handler) or (info and info.handler) or nil
        local resolved = nil
        if handler then
            resolved = SafeCall(values, handler, info)
        end
        if resolved == nil then
            resolved = SafeCall(values, info)
        end
        if type(resolved) == "table" then
            return resolved
        end

        return {}
    end

    local handler = (option and option.handler) or (info and info.handler) or nil
    if type(values) == "string" and handler and type(handler[values]) == "function" then
        local resolved = SafeCall(handler[values], handler, info)
        if type(resolved) == "table" then
            return resolved
        end
        return {}
    end

    return values or {}
end

local function ResolveSelectedValueKey(option, current, values)
    if current ~= nil and values and values[current] ~= nil then
        return current
    end

    if option and (option.dialogControl == "LSM30_Font" or option.dialogControl == "LSM30_Sound") then
        for valueKey, display in pairs(values or {}) do
            if display == current then
                return valueKey
            end
        end
    end

    return current
end

local function GetSelectDisplayText(option, valueKey, display)
    if option and (option.dialogControl == "LSM30_Font" or option.dialogControl == "LSM30_Sound" or option.dialogControl == "LSM30_Statusbar") and valueKey ~= nil and valueKey ~= "" then
        return tostring(valueKey)
    end

    if display == nil or display == "" then
        return tostring(valueKey or "")
    end

    return tostring(display)
end

local function GetSortedSelectEntries(option, values)
    local entries = {}
    for valueKey, display in pairs(values or {}) do
        entries[#entries + 1] = {
            valueKey = valueKey,
            display = display,
            label = GetSelectDisplayText(option, valueKey, display),
        }
    end

    table.sort(entries, function(left, right)
        if left.valueKey == "__default" then
            return true
        end
        if right.valueKey == "__default" then
            return false
        end

        local leftLabel = left.label:lower()
        local rightLabel = right.label:lower()
        if leftLabel == rightLabel then
            return tostring(left.valueKey) < tostring(right.valueKey)
        end

        return leftLabel < rightLabel
    end)

    return entries
end

local function GetPreviewType(path)
    local key = JoinPath(path)
    local rootKey = path and path[1] or nil
    local secondaryKey = path and path[2] or nil
    if key:find("Quality of Life.choresTab", 1, true) == 1 then
        return "chores"
    end
    if (rootKey == "qualityOfLife" and secondaryKey == "mythicPlusToolsTab") or
        rootKey == "mythicPlusToolsTab" or
        key:find("Quality of Life.mythicPlusToolsTab", 1, true) == 1 or
        key:find("Quality of Life.Mythic+ Tools", 1, true) == 1 or
        key:find("Mythic+ Tools", 1, true) == 1 then
        return "mythic"
    end
    if key:find("Notification Panel", 1, true) == 1 then
        return "notifications"
    end
    if key:find("unitFrames", 1, true) == 1 then
        return "unitframes"
    end

    return nil
end

local function GetMythicPreviewVariant(path)
    local key = JoinPath(path)
    local rootKey = path and path[1] or nil
    local secondaryKey = path and path[2] or nil
    if not ((rootKey == "qualityOfLife" and secondaryKey == "mythicPlusToolsTab") or
            rootKey == "mythicPlusToolsTab" or
            key:find("Quality of Life.mythicPlusToolsTab", 1, true) == 1 or
            key:find("Quality of Life.Mythic+ Tools", 1, true) == 1 or
            key:find("Mythic+ Tools", 1, true) == 1) then
        return nil
    end

    if secondaryKey == "interruptTracker" or (path and path[3] == "interruptTracker") or
        key:find(".interruptTracker", 1, true) ~= nil then
        return "interrupt"
    end

    return "timer"
end

local function GetTabSections(path, groups)
    local overrides = (#path == 1) and TAB_SECTION_OVERRIDES[path[1]] or nil
    if not overrides then
        return {
            {
                title = nil,
                entries = groups,
            },
        }
    end

    local lookup = {}
    for _, entry in ipairs(groups or {}) do
        lookup[entry.key] = entry
    end

    local sections = {}
    local consumed = {}
    for _, section in ipairs(overrides) do
        local entries = {}
        for _, key in ipairs(section.keys or {}) do
            if lookup[key] then
                entries[#entries + 1] = lookup[key]
                consumed[key] = true
            end
        end
        if #entries > 0 then
            sections[#sections + 1] = {
                title = section.title,
                entries = entries,
            }
        end
    end

    local remaining = {}
    for _, entry in ipairs(groups or {}) do
        if not consumed[entry.key] then
            remaining[#remaining + 1] = entry
        end
    end

    if #remaining > 0 then
        sections[#sections + 1] = {
            title = #sections > 0 and "More" or nil,
            entries = remaining,
        }
    end

    return sections
end

local function GetDisplayName(path, key, option)
    local pageOverride = PAGE_NAME_OVERRIDES[path[1] or ""]
    if pageOverride and pageOverride[key] then
        return pageOverride[key]
    end

    local info = BuildOptionInfo(path, key, option)
    local resolved = ResolveTextValue(option and option.name, info)
    if resolved ~= "" then
        return resolved
    end

    return tostring(key)
end

local function ApplyLSMFont(fontString, fontKey, size, outline)
    if not fontString then
        return
    end

    local fontPath = STANDARD_TEXT_FONT
    if LSM and type(fontKey) == "string" and fontKey ~= "" and fontKey ~= "__default" and fontKey ~= "__tooltipHeader" then
        fontPath = LSM:Fetch("font", fontKey, true) or STANDARD_TEXT_FONT
    end
    fontString:SetFont(fontPath, size or 12, outline or "")
end

function UI:IsAvailable()
    return true
end

function UI:GetFrame()
    return self.frame
end

function UI:RequestRenderCurrentPage(resetScroll)
    if resetScroll then
        self.resetScrollOnNextRender = true
    end

    if self.isRenderingPage then
        self.pendingPageRender = true
        return
    end

    self:RenderCurrentPage()
end

function UI:GetRecycleBin()
    if self.recycleBin then
        return self.recycleBin
    end

    self.recycleBin = CreateFrame("Frame", nil, UIParent)
    self.recycleBin:Hide()
    return self.recycleBin
end

function UI:RecycleFrameTree(frame)
    if not frame then
        return
    end

    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        self:RecycleFrameTree(child)
    end

    frame:Hide()
    frame:ClearAllPoints()
    frame:SetParent(self:GetRecycleBin())
end

function UI:GetCurrentFilter()
    local frame = self:GetFrame()
    if not frame or not frame.SearchBox then
        return ""
    end

    local text = frame.SearchBox:GetText() or ""
    if text == frame.SearchBox.placeholderText then
        return ""
    end
    return text
end

function UI:FindNavItem(id)
    for _, item in ipairs(NAV_ITEMS) do
        if item.id == id then
            return item
        end
    end
    return NAV_ITEMS[1]
end

function UI:FindNavItemForPath(path)
    if type(path) ~= "table" or #path == 0 then
        return NAV_ITEMS[1]
    end

    for _, item in ipairs(NAV_ITEMS) do
        if item.path and item.path[1] == path[1] then
            return item
        end
    end

    return NAV_ITEMS[1]
end

function UI:EnsureSelectMenu()
    if self.selectMenu then
        return self.selectMenu
    end

    local menu = CreatePanel(UIParent, 0.04, 0.04, 0.06, 0.985, 0.24)
    menu:SetSize(320, 360)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(120)
    menu:Hide()

    menu.Header = CreatePanel(menu, 0.08, 0.08, 0.11, 0.98, 0.18)
    menu.Header:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6)
    menu.Header:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -6)
    menu.Header:SetHeight(38)

    menu.Title = menu.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    menu.Title:SetPoint("LEFT", menu.Header, "LEFT", 12, 0)
    menu.Title:SetPoint("RIGHT", menu.Header, "RIGHT", -36, 0)
    menu.Title:SetJustifyH("LEFT")
    menu.Title:SetTextColor(1, 0.95, 0.82)

    menu.CloseButton = CreateFrame("Button", nil, menu.Header, "BackdropTemplate")
    menu.CloseButton:SetSize(22, 22)
    menu.CloseButton:SetPoint("RIGHT", menu.Header, "RIGHT", -8, 0)
    SkinIconButton(menu.CloseButton, { 0.98, 0.56, 0.5 })
    menu.CloseButton.Icon:SetText("×")
    menu.CloseButton:SetScript("OnClick", function()
        self:HideSelectMenu()
    end)

    menu.ScrollFrame = CreateFrame("ScrollFrame", nil, menu, "UIPanelScrollFrameTemplate")
    menu.ScrollFrame:SetPoint("TOPLEFT", menu.Header, "BOTTOMLEFT", 2, -8)
    menu.ScrollFrame:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -24, 10)
    menu.ScrollChild = CreateFrame("Frame", nil, menu.ScrollFrame)
    menu.ScrollChild:SetSize(280, 1)
    menu.ScrollFrame:SetScrollChild(menu.ScrollChild)
    menu.Rows = {}
    SkinScrollBar(menu.ScrollFrame, { 0.45, 0.82, 1.0 })

    self.selectMenu = menu
    return menu
end

function UI:HideSelectMenu()
    if self.selectMenu then
        self.selectMenu:Hide()
    end
end

function UI:OpenSelectMenu(anchor, option, info, values, current, title)
    local menu = self:EnsureSelectMenu()
    local frame = self:EnsureFrame()
    local entries = GetSortedSelectEntries(option, values)
    local menuWidth = math.max(300, anchor:GetWidth() + 80)

    menu:ClearAllPoints()
    menu:SetWidth(menuWidth)
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel((frame:GetFrameLevel() or 40) + 80)
    menu.Title:SetText(title or "Select an option")

    local y = 0
    for index, entry in ipairs(entries) do
        local row = menu.Rows[index]
        if not row then
            row = CreatePanel(menu.ScrollChild, 0.08, 0.08, 0.11, 0.98, 0.12)
            row:SetHeight(34)
            row:SetPoint("TOPLEFT", menu.ScrollChild, "TOPLEFT", 0, 0)
            row:SetPoint("TOPRIGHT", menu.ScrollChild, "TOPRIGHT", 0, 0)
            row.LeftAccent = row:CreateTexture(nil, "BORDER")
            row.LeftAccent:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
            row.LeftAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)
            row.LeftAccent:SetWidth(3)
            row.Preview = row:CreateTexture(nil, "BACKGROUND")
            row.Preview:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
            row.Preview:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -4, 4)
            row.Preview:SetAlpha(0)
            row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.Label:SetPoint("LEFT", row, "LEFT", 12, 0)
            row.Label:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            row.Label:SetJustifyH("LEFT")
            row.PlayButton = CreateFrame("Button", nil, row, "BackdropTemplate")
            row.PlayButton:SetSize(44, 22)
            row.PlayButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            SkinActionButton(row.PlayButton, { 0.42, 0.89, 0.63 })
            SetButtonText(row.PlayButton, "Play")
            menu.Rows[index] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu.ScrollChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", menu.ScrollChild, "TOPRIGHT", 0, -y)

        local selected = entry.valueKey == current
        local accent = self.currentAccent or { 0.98, 0.76, 0.22 }
        row:SetBackdropColor(selected and 0.11 or 0.08, selected and 0.1 or 0.08, selected and 0.14 or 0.1,
            selected and 1 or 0.96)
        row:SetBackdropBorderColor(accent[1], accent[2], accent[3], selected and 0.5 or 0.12)
        row.LeftAccent:SetColorTexture(accent[1], accent[2], accent[3], selected and 1 or 0)
        row.Label:SetText(entry.label)
        row.Label:SetTextColor(selected and 1 or 0.92, selected and 0.95 or 0.92, selected and 0.84 or 0.92)
        row.Label:ClearAllPoints()
        row.Label:SetPoint("LEFT", row, "LEFT", 12, 0)
        row.Label:SetJustifyH("LEFT")

        if option and option.dialogControl == "LSM30_Font" then
            row.Label:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            ApplyLSMFont(row.Label, entry.valueKey, 12, "")
            row.Preview:SetAlpha(0)
            row.PlayButton:Hide()
        elseif option and option.dialogControl == "LSM30_Statusbar" and LSM then
            row.Label:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            local texturePath = LSM:Fetch("statusbar", entry.valueKey, true)
            if texturePath then
                row.Preview:SetTexture(texturePath)
                row.Preview:SetVertexColor(1, 1, 1, 0.24)
                row.Preview:SetAlpha(1)
            else
                row.Preview:SetAlpha(0)
            end
            row.Label:SetFont(STANDARD_TEXT_FONT, 12, "")
            row.PlayButton:Hide()
        elseif option and option.dialogControl == "LSM30_Sound" then
            row.Label:SetPoint("RIGHT", row.PlayButton, "LEFT", -8, 0)
            row.Preview:SetAlpha(0)
            row.Label:SetFont(STANDARD_TEXT_FONT, 12, "")
            row.PlayButton:SetScript("OnClick", function()
                self:PlayConfiguredSound(entry.valueKey)
            end)
            row.PlayButton:Show()
        else
            row.Preview:SetAlpha(0)
            row.Label:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            row.Label:SetFont(STANDARD_TEXT_FONT, 12, "")
            row.PlayButton:Hide()
        end

        row:SetScript("OnMouseUp", function()
            ResolveOptionMethod(option, info, entry.valueKey)
            self:HideSelectMenu()
            self:RequestRenderCurrentPage()
        end)
        row:Show()
        y = y + 40
    end

    for index = #entries + 1, #menu.Rows do
        menu.Rows[index]:Hide()
    end

    menu.ScrollChild:SetWidth(menuWidth - 38)
    menu.ScrollChild:SetHeight(math.max(1, y))
    menu:SetHeight(math.min(440, math.max(120, y + 60)))
    menu:Show()
end

function UI:StopBindingCapture()
    local frame = self:GetFrame()
    if not frame then
        return
    end

    if frame.bindingCaptureButton and frame.bindingCaptureButton.Label then
        frame.bindingCaptureButton.Label:SetText(frame.bindingCaptureButton.originalText or "Set Binding")
    end

    frame.bindingCaptureButton = nil
    frame:EnableKeyboard(false)
end

function UI:BeginBindingCapture(button, option, info)
    local frame = self:EnsureFrame()
    self:StopBindingCapture()
    frame.bindingCaptureButton = button
    button.originalText = button.Label and button.Label:GetText() or ""
    if button.Label then
        button.Label:SetText("Press a key...")
    end
    frame.bindingCaptureOption = option
    frame.bindingCaptureInfo = info
    frame:EnableKeyboard(true)
end

function UI:CommitBinding(key)
    local frame = self:GetFrame()
    if not frame or not frame.bindingCaptureButton then
        return
    end

    local option = frame.bindingCaptureOption
    local info = frame.bindingCaptureInfo
    local binding

    if key ~= "ESCAPE" then
        local parts = {}
        if IsControlKeyDown and IsControlKeyDown() then
            parts[#parts + 1] = "CTRL"
        end
        if IsAltKeyDown and IsAltKeyDown() then
            parts[#parts + 1] = "ALT"
        end
        if IsShiftKeyDown and IsShiftKeyDown() then
            parts[#parts + 1] = "SHIFT"
        end
        parts[#parts + 1] = key
        binding = table.concat(parts, "-")
    else
        binding = ""
    end

    SafeCall(ResolveOptionMethod, option, info, binding)
    self:StopBindingCapture()
    self:RequestRenderCurrentPage()
end

function UI:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreatePanel(UIParent, 0.03, 0.03, 0.05, 0.985, 0.3)
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(40)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", BeginConfigFrameDrag)
    frame:SetScript("OnDragStop", EndConfigFrameDrag)
    frame:EnableKeyboard(false)
    frame:SetScript("OnKeyDown", function(_, key)
        self:CommitBinding(key)
    end)
    frame:SetScript("OnHide", function()
        self:HideSelectMenu()
        self:StopBindingCapture()
    end)
    frame:Hide()

    frame.TitleBar = CreatePanel(frame, 0.08, 0.08, 0.11, 0.98, 0.24)
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    frame.TitleBar:SetHeight(54)
    frame.TitleBar:EnableMouse(true)
    frame.TitleBar:RegisterForDrag("LeftButton")
    frame.TitleBar:SetScript("OnDragStart", function()
        BeginConfigFrameDrag(frame)
    end)
    frame.TitleBar:SetScript("OnDragStop", function()
        EndConfigFrameDrag(frame)
    end)

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "BORDER")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 1, -1)
    frame.TitleAccent:SetPoint("BOTTOMLEFT", frame.TitleBar, "BOTTOMLEFT", 1, 1)
    frame.TitleAccent:SetWidth(5)
    frame.TitleAccent:SetColorTexture(0.98, 0.76, 0.22, 1)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 18, -10)
    frame.Title:SetText("TwichUI: Reloaded Configuration")
    frame.Title:SetTextColor(1, 0.95, 0.82)

    frame.Subtitle = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.Subtitle:SetPoint("TOPLEFT", frame.Title, "BOTTOMLEFT", 0, -6)
    frame.Subtitle:SetJustifyH("LEFT")
    frame.Subtitle:SetTextColor(0.72, 0.74, 0.8)
    frame.Subtitle:SetText("Your personal UI suite for raiding, M+, and completionism.")

    frame.CloseButton = CreateFrame("Button", nil, frame.TitleBar, "BackdropTemplate")
    frame.CloseButton:SetSize(26, 26)
    frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -10, 0)
    SkinIconButton(frame.CloseButton, { 0.98, 0.56, 0.5 })
    frame.CloseButton.Icon:SetText("×")
    frame.CloseButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    frame.ReloadButton = CreateFrame("Button", nil, frame.TitleBar, "BackdropTemplate")
    frame.ReloadButton:SetSize(96, 24)
    frame.ReloadButton:SetPoint("RIGHT", frame.CloseButton, "LEFT", -8, 0)
    SkinActionButton(frame.ReloadButton, { 0.42, 0.82, 0.98 })
    SetButtonText(frame.ReloadButton, "Reload UI")
    frame.ReloadButton:SetScript("OnClick", function()
        ConfigurationModule:PromptToReloadUI()
    end)
    AttachTooltip(frame.ReloadButton, "Reload UI", "Apply changes that require a full interface refresh.")

    frame.ErrorLogButton = CreateFrame("Button", nil, frame.TitleBar, "BackdropTemplate")
    frame.ErrorLogButton:SetSize(86, 24)
    frame.ErrorLogButton:SetPoint("RIGHT", frame.ReloadButton, "LEFT", -6, 0)
    SkinActionButton(frame.ErrorLogButton, { 0.98, 0.56, 0.5 })
    SetButtonText(frame.ErrorLogButton, "Error Log")
    frame.ErrorLogButton:SetScript("OnClick", function()
        local viewer = T.Tools and T.Tools.UI and T.Tools.UI.ErrorLogViewer
        if viewer then
            viewer:Toggle()
            if viewer.frame and viewer.frame:IsShown() then
                SmartPositionNextToConfig(viewer.frame)
            end
        end
    end)
    AttachTooltip(frame.ErrorLogButton, "Error Log", "View errors captured from TwichUI_Reformed.")

    -- Update error count badge on the button label dynamically
    frame.ErrorLogButton:SetScript("OnShow", function()
        local el = T.Tools and (T.Tools --[[@as any]]).ErrorLog
        local count = el and el:GetCount() or 0
        if count > 0 then
            SetButtonText(frame.ErrorLogButton, "Error Log (" .. count .. ")")
            frame.ErrorLogButton:SetBackdropBorderColor(0.98, 0.40, 0.35, 0.80)
        else
            SetButtonText(frame.ErrorLogButton, "Error Log")
            frame.ErrorLogButton:SetBackdropBorderColor(0.98, 0.56, 0.5, 0.40)
        end
    end)

    frame.DebuggerButton = CreateFrame("Button", nil, frame.TitleBar, "BackdropTemplate")
    frame.DebuggerButton:SetSize(96, 24)
    frame.DebuggerButton:SetPoint("RIGHT", frame.ErrorLogButton, "LEFT", -6, 0)
    SkinActionButton(frame.DebuggerButton, { 0.55, 0.82, 0.55 })
    SetButtonText(frame.DebuggerButton, "Debugger")
    frame.DebuggerButton:SetScript("OnClick", function()
        local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
        if console and console.Show then
            console:Show()
            if console.frame then
                SmartPositionNextToConfig(console.frame)
            end
        end
    end)
    AttachTooltip(frame.DebuggerButton, "Debugger",
        "Open the TwichUI Debug Console to inspect live module state and logs.")

    frame.MoverButton = CreateFrame("Button", nil, frame.TitleBar, "BackdropTemplate")
    frame.MoverButton:SetSize(96, 24)
    frame.MoverButton:SetPoint("RIGHT", frame.DebuggerButton, "LEFT", -6, 0)
    SkinActionButton(frame.MoverButton, { 0.10, 0.72, 0.74 })
    SetButtonText(frame.MoverButton, "Move Mode")
    frame.MoverButton:SetScript("OnClick", function()
        local movers = _G.TwichMoverModule
        if movers then
            movers:Toggle()
            frame:Hide()
        end
    end)
    AttachTooltip(frame.MoverButton, "Move Mode",
        "Open the central mover overlay to drag and reposition all UI elements at once.\nThe config panel closes so handles are accessible.")

    frame.Subtitle:SetPoint("RIGHT", frame.MoverButton, "LEFT", -12, 0)

    frame.Sidebar = CreatePanel(frame, 0.055, 0.055, 0.08, 0.985, 0.18)
    frame.Sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -68)
    frame.Sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 10, 10)
    frame.Sidebar:SetWidth(SIDEBAR_WIDTH)

    frame.SearchShell = CreatePanel(frame.Sidebar, 0.08, 0.08, 0.11, 0.98, 0.2)
    frame.SearchShell:SetPoint("TOPLEFT", frame.Sidebar, "TOPLEFT", 12, -14)
    frame.SearchShell:SetPoint("TOPRIGHT", frame.Sidebar, "TOPRIGHT", -12, -14)
    frame.SearchShell:SetHeight(34)

    frame.SearchAccent = frame.SearchShell:CreateTexture(nil, "BORDER")
    frame.SearchAccent:SetPoint("TOPLEFT", frame.SearchShell, "TOPLEFT", 1, -1)
    frame.SearchAccent:SetPoint("BOTTOMLEFT", frame.SearchShell, "BOTTOMLEFT", 1, 1)
    frame.SearchAccent:SetWidth(3)
    frame.SearchAccent:SetColorTexture(0.42, 0.82, 0.98, 0.7)

    frame.SearchFocus = frame.SearchShell:CreateTexture(nil, "ARTWORK")
    frame.SearchFocus:SetPoint("TOPLEFT", frame.SearchShell, "TOPLEFT", 1, -1)
    frame.SearchFocus:SetPoint("BOTTOMRIGHT", frame.SearchShell, "BOTTOMRIGHT", -1, 1)
    frame.SearchFocus:SetColorTexture(0.42, 0.82, 0.98, 0.03)

    frame.SearchLabel = frame.SearchShell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.SearchLabel:SetPoint("LEFT", frame.SearchShell, "LEFT", 10, 0)
    frame.SearchLabel:SetText("Search")
    frame.SearchLabel:SetTextColor(0.62, 0.82, 0.98)

    frame.SearchBox = CreateFrame("EditBox", nil, frame.SearchShell, "BackdropTemplate")
    frame.SearchBox:SetAutoFocus(false)
    frame.SearchBox:SetPoint("TOPLEFT", frame.SearchShell, "TOPLEFT", 62, -1)
    frame.SearchBox:SetPoint("BOTTOMRIGHT", frame.SearchShell, "BOTTOMRIGHT", -10, 1)
    frame.SearchBox:SetFontObject("ChatFontNormal")
    frame.SearchBox.placeholderText = "Search sections"
    frame.SearchBox:SetText(frame.SearchBox.placeholderText)
    frame.SearchBox:SetTextColor(0.48, 0.5, 0.56)
    frame.SearchBox:SetScript("OnEditFocusGained", function(box)
        frame.SearchAccent:SetColorTexture(0.98, 0.76, 0.22, 1)
        frame.SearchFocus:SetColorTexture(0.98, 0.76, 0.22, 0.06)
        if box:GetText() == box.placeholderText then
            box:SetText("")
            box:SetTextColor(0.96, 0.96, 0.98)
        end
    end)
    frame.SearchBox:SetScript("OnEditFocusLost", function(box)
        frame.SearchAccent:SetColorTexture(0.42, 0.82, 0.98, 0.7)
        frame.SearchFocus:SetColorTexture(0.42, 0.82, 0.98, 0.03)
        if box:GetText() == "" then
            box:SetText(box.placeholderText)
            box:SetTextColor(0.48, 0.5, 0.56)
        end
    end)
    frame.SearchBox:SetScript("OnTextChanged", function(_, userInput)
        if not userInput then
            return
        end
        self:RefreshSidebar()
        if self.currentPageId == "dashboard" then
            self:RefreshDashboard()
        end
    end)

    frame.SidebarScrollFrame = CreateFrame("ScrollFrame", nil, frame.Sidebar, "UIPanelScrollFrameTemplate")
    frame.SidebarScrollFrame:SetPoint("TOPLEFT", frame.SearchShell, "BOTTOMLEFT", 0, -14)
    frame.SidebarScrollFrame:SetPoint("BOTTOMRIGHT", frame.Sidebar, "BOTTOMRIGHT", -24, 12)
    frame.SidebarScrollChild = CreateFrame("Frame", nil, frame.SidebarScrollFrame)
    frame.SidebarScrollChild:SetSize(SIDEBAR_WIDTH - 42, 1)
    frame.SidebarScrollFrame:SetScrollChild(frame.SidebarScrollChild)
    SkinScrollBar(frame.SidebarScrollFrame, { 0.42, 0.82, 0.98 })
    frame.NavButtons = {}

    frame.Content = CreatePanel(frame, 0.045, 0.045, 0.065, 0.985, 0.18)
    frame.Content:SetPoint("TOPLEFT", frame.Sidebar, "TOPRIGHT", 10, 0)
    frame.Content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

    frame.ContentHeader = CreatePanel(frame.Content, 0.08, 0.08, 0.11, 0.98, 0.16)
    frame.ContentHeader:SetPoint("TOPLEFT", frame.Content, "TOPLEFT", 10, -10)
    frame.ContentHeader:SetPoint("TOPRIGHT", frame.Content, "TOPRIGHT", -10, -10)
    frame.ContentHeader:SetHeight(84)

    frame.ContentAccent = frame.ContentHeader:CreateTexture(nil, "BORDER")
    frame.ContentAccent:SetPoint("TOPLEFT", frame.ContentHeader, "TOPLEFT", 1, -1)
    frame.ContentAccent:SetPoint("BOTTOMLEFT", frame.ContentHeader, "BOTTOMLEFT", 1, 1)
    frame.ContentAccent:SetWidth(4)
    frame.ContentAccent:SetColorTexture(0.98, 0.76, 0.22, 1)

    frame.PageTitle = frame.ContentHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.PageTitle:SetPoint("TOPLEFT", frame.ContentHeader, "TOPLEFT", 18, -12)
    frame.PageTitle:SetTextColor(1, 0.95, 0.82)

    frame.PageDescription = frame.ContentHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.PageDescription:SetPoint("TOPLEFT", frame.PageTitle, "BOTTOMLEFT", 0, -6)
    frame.PageDescription:SetPoint("RIGHT", frame.ContentHeader, "RIGHT", -18, 0)
    frame.PageDescription:SetJustifyH("LEFT")
    frame.PageDescription:SetTextColor(0.72, 0.74, 0.8)

    frame.PageStatus = frame.ContentHeader:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.PageStatus:SetPoint("BOTTOMLEFT", frame.ContentHeader, "BOTTOMLEFT", 18, 12)
    frame.PageStatus:SetPoint("RIGHT", frame.ContentHeader, "RIGHT", -18, 12)
    frame.PageStatus:SetJustifyH("LEFT")
    frame.PageStatus:SetTextColor(0.95, 0.8, 0.38)

    frame.Body = CreateFrame("Frame", nil, frame.Content)
    frame.Body:SetPoint("TOPLEFT", frame.ContentHeader, "BOTTOMLEFT", 0, -10)
    frame.Body:SetPoint("BOTTOMRIGHT", frame.Content, "BOTTOMRIGHT", -10, 10)

    frame.Dashboard = CreateFrame("Frame", nil, frame.Body)
    frame.Dashboard:SetAllPoints(frame.Body)

    frame.DashboardScrollFrame = CreateFrame("ScrollFrame", nil, frame.Dashboard, "UIPanelScrollFrameTemplate")
    frame.DashboardScrollFrame:SetPoint("TOPLEFT", frame.Dashboard, "TOPLEFT", 0, 0)
    frame.DashboardScrollFrame:SetPoint("BOTTOMRIGHT", frame.Dashboard, "BOTTOMRIGHT", -24, 0)
    SkinScrollBar(frame.DashboardScrollFrame, { 0.98, 0.76, 0.22 })

    frame.DashboardScrollChild = CreateFrame("Frame", nil, frame.DashboardScrollFrame)
    frame.DashboardScrollChild:SetSize(1, 1)
    frame.DashboardScrollFrame:SetScrollChild(frame.DashboardScrollChild)
    frame.DashboardScrollFrame:HookScript("OnSizeChanged", function(scroll)
        local width = math.max(1, (scroll:GetWidth() or 1) - 8)
        if frame.DashboardScrollChild then
            frame.DashboardScrollChild:SetWidth(width)
        end
        if self.currentPageId == "dashboard" then
            self:RefreshDashboard()
        end
    end)

    frame.Hero = CreatePanel(frame.DashboardScrollChild, 0.08, 0.08, 0.12, 0.98, 0.16)
    frame.Hero:SetPoint("TOPLEFT", frame.DashboardScrollChild, "TOPLEFT", 0, 0)
    frame.Hero:SetPoint("TOPRIGHT", frame.DashboardScrollChild, "TOPRIGHT", 0, 0)
    frame.Hero:SetHeight(1)

    frame.HeroGlow = frame.Hero:CreateTexture(nil, "BACKGROUND")
    frame.HeroGlow:SetPoint("TOPLEFT", frame.Hero, "TOPLEFT", 1, -1)
    frame.HeroGlow:SetPoint("BOTTOMRIGHT", frame.Hero, "BOTTOMRIGHT", -1, 1)
    frame.HeroGlow:SetColorTexture(0.98, 0.76, 0.22, 0)

    frame.HeroMeta = frame.Hero:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.HeroMeta:SetPoint("BOTTOMLEFT", frame.Hero, "BOTTOMLEFT", 18, 16)
    frame.HeroMeta:SetTextColor(0.95, 0.8, 0.38)
    frame.HeroMeta:Hide()

    frame.CardContainer = CreateFrame("Frame", nil, frame.DashboardScrollChild)
    frame.CardContainer:SetPoint("TOPLEFT", frame.DashboardScrollChild, "TOPLEFT", 0, -8)
    frame.CardContainer:SetPoint("TOPRIGHT", frame.DashboardScrollChild, "TOPRIGHT", 0, -8)
    frame.CardContainer:SetHeight(470)
    frame.Cards = {}

    frame.OptionsHost = CreatePanel(frame.Body, 0.04, 0.04, 0.06, 0.98, 0.12)
    frame.OptionsHost:SetAllPoints(frame.Body)
    frame.OptionsHost:Hide()

    frame.PreviewHost = CreatePanel(frame, 0.055, 0.055, 0.08, 0.985, 0.16)
    frame.PreviewHost:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, -6)
    frame.PreviewHost:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 8, 6)
    frame.PreviewHost:SetWidth(PREVIEW_WIDTH)
    frame.PreviewHost:Hide()

    frame.PreviewAccent = frame.PreviewHost:CreateTexture(nil, "BORDER")
    frame.PreviewAccent:SetPoint("TOPLEFT", frame.PreviewHost, "TOPLEFT", 1, -1)
    frame.PreviewAccent:SetPoint("TOPRIGHT", frame.PreviewHost, "TOPRIGHT", -1, -1)
    frame.PreviewAccent:SetHeight(4)
    frame.PreviewAccent:SetColorTexture(0.98, 0.76, 0.22, 1)

    frame.PreviewTitle = frame.PreviewHost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.PreviewTitle:SetPoint("TOPLEFT", frame.PreviewHost, "TOPLEFT", 16, -16)
    frame.PreviewTitle:SetPoint("RIGHT", frame.PreviewHost, "RIGHT", -16, 0)
    frame.PreviewTitle:SetJustifyH("LEFT")
    frame.PreviewTitle:SetTextColor(1, 0.95, 0.82)

    frame.PreviewSubtitle = frame.PreviewHost:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.PreviewSubtitle:SetPoint("TOPLEFT", frame.PreviewTitle, "BOTTOMLEFT", 0, -6)
    frame.PreviewSubtitle:SetPoint("RIGHT", frame.PreviewHost, "RIGHT", -16, 0)
    frame.PreviewSubtitle:SetJustifyH("LEFT")
    frame.PreviewSubtitle:SetTextColor(0.72, 0.74, 0.8)

    frame.PreviewBody = CreateFrame("Frame", nil, frame.PreviewHost)
    frame.PreviewBody:SetPoint("TOPLEFT", frame.PreviewSubtitle, "BOTTOMLEFT", 0, -12)
    frame.PreviewBody:SetPoint("BOTTOMRIGHT", frame.PreviewHost, "BOTTOMRIGHT", -16, 16)

    frame.OptionsScrollFrame = CreateFrame("ScrollFrame", nil, frame.OptionsHost, "UIPanelScrollFrameTemplate")
    frame.OptionsScrollFrame:SetPoint("TOPLEFT", frame.OptionsHost, "TOPLEFT", 10, -10)
    frame.OptionsScrollFrame:SetPoint("BOTTOMRIGHT", frame.OptionsHost, "BOTTOMRIGHT", -26, 10)
    frame.OptionsScrollChild = CreateFrame("Frame", nil, frame.OptionsScrollFrame)
    frame.OptionsScrollChild:SetSize(1, 1)
    frame.OptionsScrollFrame:SetScrollChild(frame.OptionsScrollChild)
    SkinScrollBar(frame.OptionsScrollFrame, { 0.98, 0.76, 0.22 })
    frame.OptionsScrollFrame:HookScript("OnSizeChanged", function(scroll)
        local width = math.max(1, (scroll:GetWidth() or 1) - 8)
        if self.lastOptionsScrollWidth == width then
            return
        end

        self.lastOptionsScrollWidth = width
        frame.OptionsScrollChild:SetWidth(width)
        if self.currentPageId and self.currentPageId ~= "dashboard" then
            self:RequestRenderCurrentPage()
        end
    end)

    self.frame = frame
    self:RefreshSidebar()
    return frame
end

function UI:ConfigureHeader(item, path)
    local frame = self:EnsureFrame()
    local accent = item and item.accent or { 0.98, 0.76, 0.22 }
    frame.ContentAccent:SetColorTexture(accent[1], accent[2], accent[3], 1)
    frame.PageTitle:SetText(item and item.title or "Overview")
    frame.PageDescription:SetText(item and item.description or "")
    if path and #path > 0 then
        frame.PageStatus:SetText(table.concat(path, " / "))
    else
        frame.PageStatus:SetText("Quick access to active modules, status, and shortcuts.")
    end
end

function UI:RefreshSidebar()
    local frame = self:EnsureFrame()
    local filter = self:GetCurrentFilter()
    local shown = 0

    for index, item in ipairs(NAV_ITEMS) do
        local button = frame.NavButtons[index]
        if not button then
            button = CreatePanel(frame.SidebarScrollChild, 0.08, 0.08, 0.1, 0.96, 0.12)
            button:SetHeight(74)
            button:SetPoint("TOPLEFT", frame.SidebarScrollChild, "TOPLEFT", 0, 0)
            button:SetPoint("TOPRIGHT", frame.SidebarScrollChild, "TOPRIGHT", 0, 0)
            button.LeftAccent = button:CreateTexture(nil, "BORDER")
            button.LeftAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            button.LeftAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
            button.LeftAccent:SetWidth(3)
            button.LeftAccent:SetColorTexture(1, 1, 1, 0)
            button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
            button.Highlight:SetAllPoints(button)
            button.Highlight:SetColorTexture(1, 1, 1, 0.04)
            button.Title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            button.Title:SetPoint("TOPLEFT", button, "TOPLEFT", 12, -10)
            button.Title:SetPoint("RIGHT", button, "RIGHT", -12, 0)
            button.Title:SetJustifyH("LEFT")
            button.Title:SetMaxLines(2)
            button.Meta = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.Meta:SetPoint("TOPLEFT", button.Title, "BOTTOMLEFT", 0, -5)
            button.Meta:SetPoint("RIGHT", button, "RIGHT", -12, 0)
            button.Meta:SetJustifyH("LEFT")
            button.Meta:SetMaxLines(1)
            button.Meta:SetTextColor(0.68, 0.7, 0.76)
            button:SetScript("OnEnter", function(selfButton)
                local accent = selfButton.item and selfButton.item.accent or { 1, 1, 1 }
                selfButton:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.34)
                selfButton.LeftAccent:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
                selfButton:ClearAllPoints()
                selfButton:SetPoint("TOPLEFT", frame.SidebarScrollChild, "TOPLEFT", 4, -selfButton.offsetY)
                selfButton:SetPoint("TOPRIGHT", frame.SidebarScrollChild, "TOPRIGHT", 0, -selfButton.offsetY)
            end)
            button:SetScript("OnLeave", function(selfButton)
                local selected = self.currentPageId == selfButton.item.id
                local accent = selfButton.item and selfButton.item.accent or { 1, 1, 1 }
                selfButton:SetBackdropBorderColor(accent[1], accent[2], accent[3], selected and 0.52 or 0.12)
                selfButton.LeftAccent:SetColorTexture(accent[1], accent[2], accent[3], selected and 1 or 0)
                selfButton:ClearAllPoints()
                selfButton:SetPoint("TOPLEFT", frame.SidebarScrollChild, "TOPLEFT", 0, -selfButton.offsetY)
                selfButton:SetPoint("TOPRIGHT", frame.SidebarScrollChild, "TOPRIGHT", 0, -selfButton.offsetY)
            end)
            frame.NavButtons[index] = button
        end

        local matches = MatchesFilter(item.title, filter) or MatchesFilter(item.description, filter)
        if matches then
            button.item = item
            button.offsetY = shown * 82
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", frame.SidebarScrollChild, "TOPLEFT", 0, -button.offsetY)
            button:SetPoint("TOPRIGHT", frame.SidebarScrollChild, "TOPRIGHT", 0, -button.offsetY)
            button.Title:SetText(item.title)
            button.Meta:SetText(item.description)
            local selected = self.currentPageId == item.id
            local accent = item.accent or { 0.98, 0.76, 0.22 }
            button:SetBackdropBorderColor(accent[1], accent[2], accent[3], selected and 0.52 or 0.12)
            button:SetBackdropColor(selected and 0.11 or 0.08, selected and 0.1 or 0.08, selected and 0.14 or 0.1,
                selected and 1 or 0.96)
            button.LeftAccent:SetColorTexture(accent[1], accent[2], accent[3], selected and 1 or 0)
            button.Title:SetTextColor(selected and 1 or 0.92, selected and 0.95 or 0.92, selected and 0.84 or 0.92)
            button:SetScript("OnMouseUp", function()
                self:PlayThemeSound("navigate")
                self:OpenPage(item.id, item.path)
            end)
            button:Show()
            shown = shown + 1
        else
            button:Hide()
        end
    end

    frame.SidebarScrollChild:SetHeight(math.max(1, shown * 82))
end

function UI:RefreshDashboard()
    local frame = self:EnsureFrame()
    local filter = self:GetCurrentFilter()
    local shown = 0
    local cardHeight = 170
    local cardGapX = 18
    local cardGapY = 14
    local childWidth = math.max(1,
        (frame.DashboardScrollChild and frame.DashboardScrollChild:GetWidth()) or (frame.Dashboard:GetWidth() or 1))
    local innerWidth = math.max(640, childWidth - 4)
    local cardWidth = math.max(280, math.floor((innerWidth - cardGapX) / 2))

    for index, card in ipairs(FEATURE_CARDS) do
        local widget = frame.Cards[index]
        if not widget then
            widget = CreatePanel(frame.CardContainer, 0.08, 0.08, 0.11, 0.98, 0.14)
            widget:SetHeight(cardHeight)
            widget.Accent = widget:CreateTexture(nil, "BORDER")
            widget.Accent:SetPoint("TOPLEFT", widget, "TOPLEFT", 1, -1)
            widget.Accent:SetPoint("TOPRIGHT", widget, "TOPRIGHT", -1, -1)
            widget.Accent:SetHeight(4)
            widget.Title = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            widget.Title:SetPoint("TOPLEFT", widget, "TOPLEFT", 14, -16)
            widget.Title:SetPoint("RIGHT", widget, "RIGHT", -14, 0)
            widget.Title:SetJustifyH("LEFT")
            widget.Subtitle = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            widget.Subtitle:SetPoint("TOPLEFT", widget.Title, "BOTTOMLEFT", 0, -6)
            widget.Subtitle:SetPoint("RIGHT", widget, "RIGHT", -14, 0)
            widget.Subtitle:SetJustifyH("LEFT")
            widget.Subtitle:SetTextColor(0.72, 0.74, 0.8)
            widget.Status = widget:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            widget.Status:SetPoint("TOPLEFT", widget.Subtitle, "BOTTOMLEFT", 0, -16)
            widget.Status:SetPoint("RIGHT", widget, "RIGHT", -14, 0)
            widget.Status:SetJustifyH("LEFT")
            widget.Status:SetTextColor(0.95, 0.8, 0.38)
            widget.OpenButton = CreateFrame("Button", nil, widget, "BackdropTemplate")
            widget.OpenButton:SetSize(104, 24)
            widget.OpenButton:SetPoint("BOTTOMLEFT", widget, "BOTTOMLEFT", 14, 14)
            SkinActionButton(widget.OpenButton, { 0.98, 0.76, 0.22 })
            SetButtonText(widget.OpenButton, "Open")
            widget.ActionButton = CreateFrame("Button", nil, widget, "BackdropTemplate")
            widget.ActionButton:SetSize(126, 24)
            widget.ActionButton:SetPoint("LEFT", widget.OpenButton, "RIGHT", 8, 0)
            SkinActionButton(widget.ActionButton, { 0.48, 0.82, 1.0 })
            frame.Cards[index] = widget
        end

        local matches = MatchesFilter(card.title, filter) or MatchesFilter(card.subtitle, filter)
        if matches then
            local column = shown % 2
            local row = math.floor(shown / 2)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", frame.CardContainer, "TOPLEFT", column * (cardWidth + cardGapX),
                -(row * (cardHeight + cardGapY)))
            widget:SetWidth(cardWidth)
            widget.Accent:SetColorTexture(unpackValues(card.accent))
            widget.Title:SetText(card.title)
            widget.Subtitle:SetText(card.subtitle)
            widget.Status:SetText(type(card.status) == "function" and card.status() or "")
            if card.pageId then
                widget.OpenButton:SetScript("OnClick", function()
                    self:OpenPage(card.pageId, card.path)
                end)
                widget.OpenButton:ClearAllPoints()
                widget.OpenButton:SetPoint("BOTTOMLEFT", widget, "BOTTOMLEFT", 14, 14)
                widget.OpenButton:Show()
            else
                widget.OpenButton:SetScript("OnClick", nil)
                widget.OpenButton:Hide()
            end
            SetButtonText(widget.ActionButton, card.actionLabel or "Action")
            widget.ActionButton:SetScript("OnClick", card.action)
            widget.ActionButton:ClearAllPoints()
            if card.pageId then
                widget.ActionButton:SetPoint("LEFT", widget.OpenButton, "RIGHT", 8, 0)
            else
                widget.ActionButton:SetPoint("BOTTOMLEFT", widget, "BOTTOMLEFT", 14, 14)
            end
            widget.ActionButton:SetShown(type(card.action) == "function")
            widget:Show()
            shown = shown + 1
        else
            widget:Hide()
        end
    end

    local rows = math.max(1, math.ceil(shown / 2))
    local containerHeight = rows * (cardHeight + cardGapY) - cardGapY
    frame.CardContainer:SetWidth(innerWidth)
    frame.CardContainer:SetHeight(math.max(cardHeight, containerHeight))
    frame.DashboardScrollChild:SetHeight(math.max(frame.CardContainer:GetHeight() + 16, frame.Dashboard:GetHeight()))
    frame.HeroMeta:SetText("")
end

function UI:PlayConfiguredSound(soundKey)
    if type(soundKey) ~= "string" or soundKey == "" or soundKey == "None" then
        return
    end

    -- Respect the global TwichUI sound volume (0 = muted).
    local theme = T:GetModule("Theme", true)
    if theme then
        local vol = theme:Get("soundVolume")
        if type(vol) == "number" and vol <= 0 then
            return
        end
    end

    local soundPath = nil
    if LSM then
        soundPath = LSM:Fetch("sound", soundKey, true)
    end

    if not soundPath and soundKey:find("\\", 1, true) then
        soundPath = soundKey
    end

    if soundPath and type(PlaySoundFile) == "function" then
        PlaySoundFile(soundPath, "Master")
    end
end

--- Plays a themed UI interaction sound based on the current sound profile.
--- event: "toggle_on" | "toggle_off" | "click" | "navigate"
function UI:PlayThemeSound(event)
    local theme = T:GetModule("Theme", true)
    if not theme then return end
    local db = theme:GetDB()
    if db.uiSoundsEnabled == false then return end

    local profile = db.soundProfile or "Subtle"
    if profile == "None" then return end

    local PlaySound = _G.PlaySound
    local SOUNDKIT = _G.SOUNDKIT

    if profile == "Subtle" then
        -- Use built-in WoW UI sounds — perfectly calibrated for UI interactions.
        if not PlaySound or not SOUNDKIT then return end
        if event == "toggle_on" then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master", false)
        elseif event == "toggle_off" then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF, "Master", false)
        elseif event == "click" then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master", false)
        elseif event == "navigate" then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPEN, "Master", false)
        end
    elseif profile == "Standard" then
        -- Use TwichUI's own registered sounds for a distinct, cohesive feel.
        -- "TwichUI-Menu-Click"   → hover, open, navigate (subtle interactions)
        -- "TwichUI-Menu-Confirm" → select, toggle-on, execute (confirmed actions)
        local uiTools = T.Tools and T.Tools.UI or nil
        if not (uiTools and uiTools.PlayTwichSound) then return end
        if event == "navigate" or event == "toggle_off" then
            uiTools.PlayTwichSound("TwichUI-Menu-Click")
        elseif event == "toggle_on" or event == "click" then
            uiTools.PlayTwichSound("TwichUI-Menu-Confirm")
        end
    end
end

function UI:ConfigureOptionsLayout(path)
    local frame = self:EnsureFrame()
    local previewType = GetPreviewType(path or {})

    frame.OptionsScrollFrame:ClearAllPoints()
    frame.OptionsScrollFrame:SetPoint("TOPLEFT", frame.OptionsHost, "TOPLEFT", 10, -10)
    frame.OptionsScrollFrame:SetPoint("BOTTOMLEFT", frame.OptionsHost, "BOTTOMLEFT", 10, 10)
    frame.OptionsScrollFrame:SetPoint("RIGHT", frame.OptionsHost, "RIGHT", -26, 0)

    if previewType then
        local accent = self.currentAccent or { 0.98, 0.76, 0.22 }
        frame.PreviewAccent:SetColorTexture(accent[1], accent[2], accent[3], 1)
        frame.PreviewHost:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.2)
        frame.PreviewHost:Show()
    else
        frame.PreviewHost:Hide()
    end

    local scrollWidth = math.max(1, (frame.OptionsScrollFrame:GetWidth() or 1) - 8)
    frame.OptionsScrollChild:SetWidth(scrollWidth)
    self.lastOptionsScrollWidth = scrollWidth
end

local UNIT_FRAME_TAG_REFERENCE = {
    {
        title = "Core",
        items = {
            { tag = "[name]",    description = "Full unit name." },
            { tag = "[name(8)]", description = "Shortened name. The number is the max length." },
            { tag = "[class]",   description = "Localized class name for player units." },
            { tag = "[level]",   description = "Unit level." },
            { tag = "[status]",  description = "Status text such as Dead, Ghost, AFK, or Offline." },
        },
    },
    {
        title = "Health",
        items = {
            { tag = "[curhp]",         description = "Current health value." },
            { tag = "[perhp<$%]",      description = "Health percent with a suffix only when the tag has a value." },
            { tag = "[missinghp]",     description = "Missing health amount." },
            { tag = "[curhp]/[maxhp]", description = "Common combined current and max health display." },
        },
    },
    {
        title = "Power",
        items = {
            { tag = "[curpp]",     description = "Current power value." },
            { tag = "[perpp<$%]",  description = "Power percent with a conditional suffix." },
            { tag = "[missingpp]", description = "Missing power amount." },
            { tag = "[power]",     description = "Localized power type name such as Mana, Rage, or Energy." },
        },
    },
    {
        title = "Color And Syntax",
        items = {
            { tag = "[raidcolor][name<$|r]", description = "Wrap the unit name in raid/class color and close the color code only when the name exists." },
            { tag = "[difficulty][level]",   description = "Color the level text by target difficulty." },
            { tag = "[group]",               description = "Raid group number for raid members." },
            { tag = "[classification]",      description = "Rare, Elite, Boss, or Affix classification text when relevant." },
        },
    },
}

function UI:RenderUnitFrameTagReference(parent, width)
    local accent = self.currentAccent or { 0.98, 0.76, 0.22 }
    local y = 0

    local intro = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    intro:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    intro:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    intro:SetJustifyH("LEFT")
    intro:SetJustifyV("TOP")
    intro:SetTextColor(0.78, 0.8, 0.86)
    intro:SetText(
        "Custom text fields accept raw oUF tag strings. Combine tags freely and use affixes like [perhp<$%] when you want punctuation to disappear with empty values.")
    intro:SetWidth(width)
    y = y + intro:GetStringHeight() + 14

    for _, section in ipairs(UNIT_FRAME_TAG_REFERENCE) do
        local heading = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        heading:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
        heading:SetJustifyH("LEFT")
        heading:SetTextColor(accent[1], accent[2], accent[3])
        heading:SetText(section.title)
        y = y + 20

        for _, item in ipairs(section.items) do
            local row = CreatePanel(parent, 0.08, 0.08, 0.11, 0.94, 0.08)
            row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
            row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)

            local tagLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tagLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
            tagLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -8)
            tagLabel:SetJustifyH("LEFT")
            tagLabel:SetTextColor(1, 0.95, 0.82)
            tagLabel:SetText(item.tag)

            local descLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            descLabel:SetPoint("TOPLEFT", tagLabel, "BOTTOMLEFT", 0, -5)
            descLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, 0)
            descLabel:SetJustifyH("LEFT")
            descLabel:SetJustifyV("TOP")
            descLabel:SetTextColor(0.74, 0.76, 0.82)
            descLabel:SetText(item.description)
            descLabel:SetWidth(width - 20)

            local rowHeight = math.max(44, descLabel:GetStringHeight() + 28)
            row:SetHeight(rowHeight)
            y = y + rowHeight + 8
        end

        y = y + 6
    end

    return y
end

function UI:RenderUnitFramePanel(parent, width)
    local accent = self.currentAccent or { 0.91, 0.45, 0.45 }
    local y = 0

    local function GetUFModule()
        return T:GetModule("UnitFrames", true)
    end

    -- ── Controls ─────────────────────────────────────────────────────────────
    local ctrlHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ctrlHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    ctrlHeader:SetJustifyH("LEFT")
    ctrlHeader:SetTextColor(accent[1], accent[2], accent[3])
    ctrlHeader:SetText("Controls")
    y               = y + 22

    local BTN_H     = 28
    local BTN_GAP   = 6
    local BTN_W     = math.floor((width - BTN_GAP) / 2)

    -- Row 1: Enable/Disable | Test Mode
    local enableBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    enableBtn:SetSize(BTN_W, BTN_H)
    enableBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    SkinActionButton(enableBtn, { 0.55, 0.82, 0.55 })

    local testBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    testBtn:SetSize(BTN_W, BTN_H)
    testBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", BTN_W + BTN_GAP, -y)
    SkinActionButton(testBtn, { 0.98, 0.76, 0.22 })

    y = y + BTN_H + BTN_GAP

    -- Row 2: Unlock/Lock Movers | Refresh Frames
    local moversBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    moversBtn:SetSize(BTN_W, BTN_H)
    moversBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    SkinActionButton(moversBtn, { 0.78, 0.60, 0.96 })

    local refreshBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    refreshBtn:SetSize(BTN_W, BTN_H)
    refreshBtn:SetPoint("TOPLEFT", parent, "TOPLEFT", BTN_W + BTN_GAP, -y)
    SkinActionButton(refreshBtn, { 0.42, 0.82, 0.98 })
    SetButtonText(refreshBtn, "Refresh")
    refreshBtn:SetScript("OnClick", function()
        local m = GetUFModule()
        if m and m.RefreshAllFrames then m:RefreshAllFrames() end
    end)
    AttachTooltip(refreshBtn, "Refresh Frames", "Force a full re-apply of all unit frame settings and colors.")

    y = y + BTN_H + 16

    -- Dynamic button label refresh (called after all buttons are created)
    local function RefreshButtonStates()
        local m        = GetUFModule()
        local db       = m and m.GetDB and m:GetDB()
        local enabled  = db == nil or db.enabled ~= false
        local testMode = db and db.testMode == true
        local moversActive = _G.TwichMoverModule and _G.TwichMoverModule:IsActive() or false
        SetButtonText(enableBtn, enabled and "Disable UF" or "Enable UF")
        SetButtonText(testBtn, testMode and "Exit Test" or "Test Mode")
        SetButtonText(moversBtn, moversActive and "Exit Move Mode" or "Move Mode")
    end
    RefreshButtonStates()

    enableBtn:SetScript("OnClick", function()
        local m = GetUFModule()
        if not m then return end
        local db = m:GetDB()
        db.enabled = not (db.enabled ~= false)
        if db.enabled and not m:IsEnabled() then
            m:Enable()
        elseif not db.enabled and m:IsEnabled() then
            m:Disable()
        end
        RefreshButtonStates()
    end)
    AttachTooltip(enableBtn, "Toggle Unit Frames", "Enable or disable the TwichUI standalone unit frames module.")

    testBtn:SetScript("OnClick", function()
        local m = GetUFModule()
        if not m then return end
        m:SetTestMode(not (m:GetDB().testMode == true))
        RefreshButtonStates()
    end)
    AttachTooltip(testBtn, "Test Mode", "Show unit frame placeholders with sample health, power, and cast data.")

    moversBtn:SetScript("OnClick", function()
        local movers = _G.TwichMoverModule
        if movers then
            movers:Toggle()
            RefreshButtonStates()
        end
    end)
    AttachTooltip(moversBtn, "Move Mode", "Open the central mover overlay to reposition all UI elements simultaneously.")

    -- ── Divider ───────────────────────────────────────────────────────────────
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -y)
    divider:SetHeight(1)
    divider:SetColorTexture(accent[1], accent[2], accent[3], 0.25)
    y = y + 1 + 12

    -- ── oUF Tag Reference (scrollable) ────────────────────────────────────────
    local tagHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tagHeader:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    tagHeader:SetJustifyH("LEFT")
    tagHeader:SetTextColor(accent[1], accent[2], accent[3])
    tagHeader:SetText("oUF Tag Reference")
    y = y + 22

    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 0)
    SkinScrollBar(scrollFrame, accent)

    local tagContentWidth = math.max(160, width - 28)
    local tagScrollChild = CreateFrame("Frame", nil, scrollFrame)
    tagScrollChild:SetWidth(tagContentWidth)
    tagScrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(tagScrollChild)

    local tagHeight = self:RenderUnitFrameTagReference(tagScrollChild, tagContentWidth)
    tagScrollChild:SetHeight(tagHeight)
end

function UI:RenderStickyPreview(path)
    local frame = self:EnsureFrame()
    local previewType = GetPreviewType(path or {})
    local mythicVariant = previewType == "mythic" and GetMythicPreviewVariant(path or {}) or nil

    if self.previewRoot then
        self.previewRoot:Hide()
        self.previewRoot:SetParent(nil)
        self.previewRoot = nil
    end

    if not previewType then
        return
    end

    local titles = {
        chores = {
            title = "Tracker Preview",
            subtitle = "Pinned chores tracker styling stays visible while you tune the frame.",
        },
        mythic = {
            title = mythicVariant == "interrupt" and "Interrupt Preview" or "Timer Preview",
            subtitle = mythicVariant == "interrupt" and
                "Live-styled tracker mock stays pinned while you adjust bars, fonts, and sounds." or
                "Pinned Mythic+ timer styling stays visible while you tune timer, bars, and checkpoint rows.",
        },
        notifications = {
            title = "Notification Preview",
            subtitle = "A fixed mock of the toast stack that stays in view while you edit the panel.",
        },
        raid = {
            title = "Raid Preview",
            subtitle = "Glow and spark changes stay visible while you scroll through the frame settings.",
        },
        unitframes = {
            title = "Unit Frames",
            subtitle = "Quick controls and oUF tag reference — stays pinned while you configure unit frame settings.",
        },
    }
    local previewInfo = titles[previewType]
    frame.PreviewTitle:SetText(previewInfo and previewInfo.title or "Preview")
    frame.PreviewSubtitle:SetText(previewInfo and previewInfo.subtitle or "")

    local width = math.max(220, (frame.PreviewBody:GetWidth() or (PREVIEW_WIDTH - 32)))
    local root = CreateFrame("Frame", nil, frame.PreviewBody)
    root:SetPoint("TOPLEFT", frame.PreviewBody, "TOPLEFT", 0, 0)
    root:SetSize(width, 1)
    self.previewRoot = root

    if previewType == "unitframes" then
        -- Root stretches to fill PreviewBody so the inner scroll frame can anchor to its bottom.
        root:SetPoint("BOTTOMRIGHT", frame.PreviewBody, "BOTTOMRIGHT", 0, 0)
        self:RenderUnitFramePanel(root, width)
    else
        local height = self:RenderPreviewStrip(root, 0, path, width)
        root:SetHeight(height)
    end
end

local function GetMythicPreviewRows()
    return {
        {
            name = "Aegiswall",
            classToken = "WARRIOR",
            spellIcon = 132938,
            baseValue = 0.22,
            direction = 1,
            isReady = false,
            duration = 12,
        },
        {
            name = "Lightmend",
            classToken = "PRIEST",
            spellIcon = 132357,
            baseValue = 0.92,
            direction = -1,
            isReady = true,
            duration = 1,
        },
        {
            name = "Spellcut",
            classToken = "MAGE",
            spellIcon = 135856,
            baseValue = 0.48,
            direction = 1,
            isReady = false,
            duration = 8,
        },
    }
end

local function SetResolvedFont(fontString, fontPath, size, outline, r, g, b, a)
    if not fontString then
        return
    end

    fontString:SetFont(fontPath or STANDARD_TEXT_FONT, size or 12, outline or "")
    if r ~= nil then
        fontString:SetTextColor(r, g or 1, b or 1, a or 1)
    end
end

local function GetMythicPreviewRuntime()
    local runtime = _G.TwichUIMythicPlusToolsRuntime
    if type(runtime) ~= "table" then
        return nil
    end

    if runtime.EnsureRuntime then
        SafeCall(runtime.EnsureRuntime, runtime)
    end

    return runtime
end

local function ClampPreviewValue(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end
    if minValue ~= nil and value < minValue then
        return minValue
    end
    if maxValue ~= nil and value > maxValue then
        return maxValue
    end
    return value
end

local function SetPreviewBarColor(bar, color)
    if not (bar and color) then
        return
    end

    bar:SetStatusBarColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function CreateMythicPlusTimerPreviewShell(parent, width, height, runtime)
    local frame = CreatePanel(parent, 0.03, 0.03, 0.05, 0.98, 0.2)
    frame:SetSize(width, height)

    frame.TitleBar = CreatePanel(frame, 0.02, 0.02, 0.03, 0.98, 0.35)
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(32)

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "ARTWORK")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 0, 0)
    frame.TitleAccent:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", 0, 0)
    frame.TitleAccent:SetHeight(2)
    frame.TitleAccent:SetColorTexture(0.96, 0.78, 0.24, 0.95)

    frame.TitleIcon = frame.TitleBar:CreateTexture(nil, "OVERLAY")
    frame.TitleIcon:SetPoint("LEFT", frame.TitleBar, "LEFT", 10, 0)
    frame.TitleIcon:SetSize(16, 16)
    frame.TitleIcon:SetTexture(236686)
    frame.TitleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.TitleIcon, "RIGHT", 8, 0)
    frame.Title:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -10, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("Mythic+ Timer")

    frame.ContentInset = CreatePanel(frame, 0.02, 0.02, 0.03, 0.98, 0.45)
    frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)

    frame.ContentScroll = CreateFrame("ScrollFrame", nil, frame.ContentInset)
    frame.ContentScroll:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 3, -3)
    frame.ContentScroll:SetPoint("BOTTOMRIGHT", frame.ContentInset, "BOTTOMRIGHT", -3, 3)

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ContentScroll)
    frame.ScrollChild:SetPoint("TOPLEFT", frame.ContentScroll, "TOPLEFT", 0, 0)
    frame.ScrollChild:SetPoint("TOPRIGHT", frame.ContentScroll, "TOPRIGHT", 0, 0)
    frame.ScrollChild:SetHeight(1)
    frame.ContentScroll:SetScrollChild(frame.ScrollChild)

    frame.EmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("CENTER", frame.ContentInset, "CENTER", 0, 0)
    frame.EmptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.EmptyText:SetJustifyH("CENTER")
    frame.EmptyText:SetText("Mythic+ timer preview unavailable.")
    frame.EmptyText:Hide()

    frame.KeyText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.KeyText:SetJustifyH("LEFT")

    frame.AffixText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.AffixText:SetJustifyH("LEFT")

    frame.ElapsedText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.ElapsedText:SetJustifyH("LEFT")

    frame.DeathText = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.DeathText:SetJustifyH("LEFT")

    frame.BarsHeader = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.BarsHeader:SetJustifyH("LEFT")
    frame.BarsHeader:SetText("Milestones")

    frame.MilestoneRow = runtime and runtime.CreateMythicPlusTimerMilestoneRow and
        runtime:CreateMythicPlusTimerMilestoneRow(frame.ScrollChild) or CreateFrame("Frame", nil, frame.ScrollChild)
    frame.ForcesRow = runtime and runtime.CreateMythicPlusTimerBarRow and
        runtime:CreateMythicPlusTimerBarRow(frame.ScrollChild) or CreateFrame("Frame", nil, frame.ScrollChild)

    frame.CheckpointHeader = frame.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.CheckpointHeader:SetJustifyH("LEFT")
    frame.CheckpointHeader:SetText("Checkpoints")

    frame.CheckpointRows = {}
    for index = 1, 8 do
        local row = CreateFrame("Frame", nil, frame.ScrollChild)
        row:SetHeight(18)

        row.Name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Name:SetJustifyH("LEFT")
        row.Name:SetPoint("LEFT", row, "LEFT", 0, 0)

        row.Percent = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Percent:SetJustifyH("RIGHT")

        row.Time = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.Time:SetJustifyH("RIGHT")
        row.Time:SetPoint("RIGHT", row, "RIGHT", 0, 0)

        frame.CheckpointRows[index] = row
    end

    return frame
end

local function PopulateMythicPlusTimerPreviewShell(shell, runtime)
    if not shell then
        return
    end

    if not (runtime and runtime.GetMythicPlusTimerAppearance and runtime.BuildMythicPlusTimerPreviewState and
            runtime.ApplyMythicPlusTimerStyle and runtime.LayoutMythicPlusTimerFrame) then
        shell.EmptyText:SetShown(true)
        return
    end

    local appearance = runtime:GetMythicPlusTimerAppearance()
    local state = runtime:BuildMythicPlusTimerPreviewState()
    if not (appearance and state and shell.MilestoneRow and shell.ForcesRow and shell.CheckpointRows) then
        shell.EmptyText:SetShown(true)
        return
    end

    shell.EmptyText:Hide()
    runtime:ApplyMythicPlusTimerStyle(shell)

    shell.Title:SetText("Mythic+ Timer")
    shell.KeyText:SetText(state.keyText or state.mapName or "Mythic+")
    shell.AffixText:SetText(state.affixText or "")
    shell.ElapsedText:SetText(state.elapsedText or "")
    shell.DeathText:SetText(state.deathText or "")

    for _, key in ipairs({ "plusOne", "plusTwo", "plusThree" }) do
        local segment = shell.MilestoneRow.Segments and shell.MilestoneRow.Segments[key]
        if segment then
            segment.widthFraction = 0
            segment.Label:SetText("")
            segment.Value:SetText("")
            segment.bar:SetStatusBarTexture(appearance.timerBarTexture)
            segment.bar:SetMinMaxValues(0, 1)
            segment.bar:SetValue(0)
        end
    end

    for _, segmentState in ipairs((state.milestoneBar and state.milestoneBar.segments) or {}) do
        local segment = shell.MilestoneRow.Segments and shell.MilestoneRow.Segments[segmentState.key]
        if segment then
            segment.widthFraction = tonumber(segmentState.widthFraction) or 0
            segment.Label:SetText(segmentState.label or "")
            segment.Value:SetText(segmentState.value or "")
            segment.bar:SetValue(1 - ClampPreviewValue(segmentState.progress, 0, 1, 0))
            segment.barColor = appearance.timerBarColorMode == "custom" and appearance.timerBarColor or
                (segmentState.color or { 0.96, 0.78, 0.24, 1 })
            SetPreviewBarColor(segment.bar, segment.barColor)
        end
    end

    shell.ForcesRow:Show()
    shell.ForcesRow.label:SetText(state.forcesBar and state.forcesBar.label or "")
    shell.ForcesRow.value:SetText(state.forcesBar and state.forcesBar.value or "")
    shell.ForcesRow.detail:SetText(state.forcesBar and state.forcesBar.detail or "")
    shell.ForcesRow.bar:SetStatusBarTexture(appearance.timerBarTexture)
    shell.ForcesRow.bar:SetMinMaxValues(0, 1)
    shell.ForcesRow.bar:SetValue(ClampPreviewValue(state.forcesBar and state.forcesBar.progress or 0, 0, 1, 0))
    SetPreviewBarColor(shell.ForcesRow.bar,
        appearance.timerBarColorMode == "custom" and appearance.timerBarColor or
        ((state.forcesBar and state.forcesBar.color) or { 0.65, 0.42, 0.98, 1 }))
    shell.ForcesRow.MarkerData = state.forceMarkers or {}

    local showBossCheckpoints = runtime.GetDB and runtime:GetDB().mythicPlusTimerShowBossCheckpoints ~= false
    shell.CheckpointHeader:SetText("Checkpoints")
    shell.CheckpointHeader:SetShown(showBossCheckpoints)

    for _, row in ipairs(shell.CheckpointRows) do
        row.Name:SetText("")
        row.Percent:SetText("")
        row.Time:SetText("")
        row.IsCompleted = false
        row.FailedTarget = false
    end

    local visibleCheckpointCount = 0
    for index, rowState in ipairs(state.checkpoints or {}) do
        local row = shell.CheckpointRows[index]
        if row and showBossCheckpoints then
            row.Name:SetText(rowState.name or "")
            row.Percent:SetText(runtime.FormatCheckpointPercentText and
                runtime.FormatCheckpointPercentText(rowState.percent) or
                string.format("%s%%", tostring(rowState.percent or 0):gsub("%.0$", "")))
            row.Time:SetText(rowState.kind == "boss" and (rowState.time or "Pending") or "")
            row.IsCompleted = rowState.completed == true
            row.FailedTarget = rowState.failedTarget == true
            visibleCheckpointCount = visibleCheckpointCount + 1
        end
    end

    runtime:LayoutMythicPlusTimerFrame(shell, showBossCheckpoints and visibleCheckpointCount or 0)
    if runtime.UpdateMythicPlusTimerForceMarkers then
        runtime:UpdateMythicPlusTimerForceMarkers(shell.ForcesRow)
    end
end

local function CreateTrackerPreviewShell(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    frame:SetBackdropBorderColor(0.94, 0.77, 0.28, 0.2)

    frame.TitleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(32)
    frame.TitleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 1 },
    })

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "ARTWORK")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 0, 0)
    frame.TitleAccent:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", 0, 0)
    frame.TitleAccent:SetHeight(2)
    frame.TitleAccent:SetColorTexture(0.96, 0.78, 0.24, 0.95)

    frame.TitleIcon = frame.TitleBar:CreateTexture(nil, "OVERLAY")
    frame.TitleIcon:SetPoint("LEFT", frame.TitleBar, "LEFT", 10, 0)
    frame.TitleIcon:SetSize(16, 16)
    frame.TitleIcon:SetTexture(132337)
    frame.TitleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.TitleIcon, "RIGHT", 8, 0)
    frame.Title:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -10, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("Interrupt Tracker")

    frame.ContentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.ContentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ContentInset)
    frame.ScrollChild:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 3, -3)
    frame.ScrollChild:SetPoint("TOPRIGHT", frame.ContentInset, "TOPRIGHT", -3, -3)
    frame.ScrollChild:SetHeight(1)

    frame.EmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("CENTER", frame.ContentInset, "CENTER", 0, 0)
    frame.EmptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.EmptyText:Hide()

    return frame
end

local function ApplyPreviewBarColor(bar, color)
    if not (bar and color) then
        return
    end

    bar:SetStatusBarColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function GetPreviewRowState(runtime, rowData, elapsed)
    if rowData.isReady then
        return {
            isReady = true,
            priority = 1,
            progress = 1,
            valueText = "Ready",
        }
    end

    local wave = math.sin((elapsed * 1.35) + rowData.duration) * 0.08 * (rowData.direction or 1)
    local progress = math.max(0.08, math.min(0.96, rowData.baseValue + wave))
    local remaining = math.max(0.3, rowData.duration * (1 - progress))
    return {
        isReady = false,
        priority = remaining < 2 and 2 or 3,
        progress = progress,
        valueText = string.format("%.1fs", remaining),
    }
end

local function ApplyPreviewRowState(runtime, appearance, row, rowData, state)
    if not (appearance and row and rowData and state) then
        return
    end

    row.icon:SetTexture(rowData.spellIcon)
    row.icon:SetShown(rowData.spellIcon ~= nil)
    row.name:SetText(rowData.name)
    row.timer:SetText(state.valueText or "")
    row.detail:SetText("")
    row.detail:Hide()

    local nameColor = (runtime and runtime.GetInterruptFontColor and runtime:GetInterruptFontColor(rowData)) or
        appearance.interruptFontColor or { 0.96, 0.93, 0.86, 1 }
    local statusFontPath, statusColor, shouldShowText = appearance.statusTextFontPath, appearance.statusTextColor, true
    if runtime and runtime.GetStatusTextStyle then
        statusFontPath, statusColor, shouldShowText = runtime:GetStatusTextStyle(state)
    end

    SetResolvedFont(row.name, appearance.fontPath, appearance.fontSize, appearance.outline,
        nameColor[1], nameColor[2], nameColor[3], 1)
    SetResolvedFont(row.timer, statusFontPath, appearance.fontSize + 1, appearance.outline,
        statusColor[1], statusColor[2], statusColor[3], 1)
    row.timer:SetText(shouldShowText and (state.valueText or "") or "")
    SetResolvedFont(row.detail, appearance.fontPath, math.max(10, appearance.fontSize - 2), appearance.outline,
        0.78, 0.78, 0.8, 1)

    row.bar:SetStatusBarTexture(appearance.barTexture or "Interface\\TargetingFrame\\UI-StatusBar")
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(math.max(0, math.min(1, state.progress or 0)))

    local barColor = state.color
    if runtime and runtime.GetInterruptBarColor and runtime.GetInterruptReadyBarColor then
        if state.priority == 3 then
            barColor = runtime:GetInterruptBarColor(rowData)
        elseif state.isReady then
            barColor = runtime:GetInterruptReadyBarColor(rowData)
        end
    end

    if not barColor then
        barColor = state.isReady and appearance.interruptReadyBarColor or appearance.interruptBarColor
    end
    ApplyPreviewBarColor(row.bar, barColor)
end

local function GetChoresPreviewModule()
    local datatextModule = T:GetModule("Datatexts", true)
    if not (datatextModule and datatextModule.GetModule) then
        return nil
    end

    return datatextModule:GetModule("ChoresDataText", true)
end

local function GetChoresPreviewFontSettings()
    local datatextOptions = ConfigurationModule.Options and ConfigurationModule.Options.Datatext
    local choresOptions = ConfigurationModule.Options and ConfigurationModule.Options.Chores

    local headerFont = STANDARD_TEXT_FONT
    local entryFont = STANDARD_TEXT_FONT
    local headerFontSize = 12
    local entryFontSize = 11

    if datatextOptions then
        local headerFontKey = datatextOptions.GetChoresTooltipHeaderFont and datatextOptions:GetChoresTooltipHeaderFont() or
            nil
        local entryFontKey = datatextOptions.GetChoresTooltipEntryFont and datatextOptions:GetChoresTooltipEntryFont() or
            nil
        headerFontSize = datatextOptions.GetChoresTooltipHeaderFontSize and
            datatextOptions:GetChoresTooltipHeaderFontSize() or 12
        entryFontSize = datatextOptions.GetChoresTooltipEntryFontSize and datatextOptions:GetChoresTooltipEntryFontSize() or
            11

        if LSM and headerFontKey and headerFontKey ~= "" then
            headerFont = LSM:Fetch("font", headerFontKey, true) or headerFont
        end
        if LSM and entryFontKey and entryFontKey ~= "" then
            entryFont = LSM:Fetch("font", entryFontKey, true) or entryFont
        end
    end

    if choresOptions and choresOptions.GetTrackerHeaderFont then
        local trackerHeaderFont = choresOptions:GetTrackerHeaderFont()
        if trackerHeaderFont and trackerHeaderFont ~= "" and trackerHeaderFont ~= "__tooltipHeader" and LSM then
            headerFont = LSM:Fetch("font", trackerHeaderFont, true) or headerFont
        end
    end
    if choresOptions and choresOptions.GetTrackerHeaderFontSize then
        headerFontSize = choresOptions:GetTrackerHeaderFontSize() or headerFontSize
    end

    if choresOptions and choresOptions.GetTrackerEntryFont then
        local trackerEntryFont = choresOptions:GetTrackerEntryFont()
        if trackerEntryFont and trackerEntryFont ~= "" and trackerEntryFont ~= "__tooltipEntry" and LSM then
            entryFont = LSM:Fetch("font", trackerEntryFont, true) or entryFont
        end
    end
    if choresOptions and choresOptions.GetTrackerEntryFontSize then
        entryFontSize = choresOptions:GetTrackerEntryFontSize() or entryFontSize
    end

    return {
        headerFont = headerFont,
        headerFontSize = headerFontSize,
        entryFont = entryFont,
        entryFontSize = entryFontSize,
    }
end

local function GetChoresStatusColor(status)
    if status == 2 then
        return 0.32, 0.86, 0.54
    end
    if status == 1 then
        return 0.96, 0.82, 0.35
    end
    return 0.86, 0.38, 0.38
end

local function BuildChoresPreviewProgress(summary)
    if not summary then
        return "0/0"
    end

    if summary.status == 2 then
        return "Complete"
    end

    local total = tonumber(summary.total) or 0
    local remaining = tonumber(summary.remaining) or 0
    local current = summary.progressStyle == "remaining" and remaining or math.max(0, total - remaining)
    return string.format("%d/%d", current, total)
end

local function BuildChoresPreviewEntryTitle(summary, entry)
    local title = (entry and entry.state and entry.state.title) or (summary and summary.name) or "Chore"
    local timeRemainingText = entry and entry.state and entry.state.timeRemainingText or nil
    if timeRemainingText and timeRemainingText ~= "" then
        return string.format("%s (%s left)", title, timeRemainingText)
    end

    return title
end

local function BuildChoresPreviewObjectiveText(objective)
    local text = objective and objective.text or ""
    local need = objective and objective.need or nil
    if need and need > 0 then
        local have = objective.have or 0
        return string.format("%d/%d %s", have, need, text)
    end

    return text
end

local function GetChoresPreviewSections(state, showCompleted)
    local sections = {}
    if not (state and type(state.orderedCategories) == "table") then
        return sections
    end

    for _, summary in ipairs(state.orderedCategories) do
        local entries = showCompleted and summary.entries or summary.selectedEntries
        local shouldShowSummary = showCompleted or (summary.remaining or 0) > 0

        if shouldShowSummary and type(entries) == "table" then
            local displayEntries = {}
            for _, entry in ipairs(entries) do
                local entryStatus = entry and entry.state and entry.state.status or 0
                if (showCompleted or entryStatus ~= 2) and (((summary.showPendingEntries and entryStatus ~= 2) or entryStatus == 1) or showCompleted) then
                    displayEntries[#displayEntries + 1] = entry
                end
            end

            if showCompleted or #displayEntries > 0 then
                sections[#sections + 1] = {
                    summary = summary,
                    displayEntries = displayEntries,
                }
            end
        end
    end

    if #sections == 0 then
        sections[1] = {
            summary = {
                name = "Weekly chores",
                status = 1,
                total = 3,
                remaining = 2,
            },
            displayEntries = {
                { state = { status = 1, title = "Delver's Call" } },
                { state = { status = 0, title = "Prey: The Coil" } },
            },
        }
    end

    return sections
end

local function GetChoresPreviewEmptyText(state, sectionCount)
    if not state or state.enabled == false then
        return "Enable Quality of Life > Chores to start tracking."
    end

    if type(state.orderedCategories) ~= "table" or #state.orderedCategories == 0 then
        return "No tracked chores are active for this character right now."
    end

    if sectionCount == 0 then
        return "All tracked chores are complete."
    end

    return nil
end

local function CreateChoresPreviewSection(parent, index)
    local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    section.BackgroundFill = section:CreateTexture(nil, "BACKGROUND")
    section.BackgroundFill:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
    section.BackgroundFill:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -1, 1)

    section.HeaderGlow = section:CreateTexture(nil, "ARTWORK")
    section.HeaderGlow:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
    section.HeaderGlow:SetPoint("TOPRIGHT", section, "TOPRIGHT", -1, -1)
    section.HeaderGlow:SetHeight(20)

    section.HeaderButton = CreateFrame("Button", nil, section)
    section.HeaderButton:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
    section.HeaderButton:SetPoint("TOPRIGHT", section, "TOPRIGHT", -1, -1)
    section.HeaderButton:SetHeight(30)

    section.Arrow = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.Arrow:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -10)
    section.Arrow:SetTextColor(0.96, 0.82, 0.35)
    section.Arrow:SetText("v")

    section.Title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.Title:SetPoint("TOPLEFT", section, "TOPLEFT", 28, -10)
    section.Title:SetPoint("RIGHT", section, "RIGHT", -82, 0)
    section.Title:SetJustifyH("LEFT")
    section.Title:SetWordWrap(false)

    section.Progress = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.Progress:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -11)
    section.Progress:SetJustifyH("RIGHT")

    section.Divider = section:CreateTexture(nil, "ARTWORK")
    section.Divider:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -30)
    section.Divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", -10, -30)
    section.Divider:SetHeight(1)

    section.ActionButton = CreateFrame("Button", nil, section, "BackdropTemplate")
    section.ActionButton:SetSize(1, 1)
    section.ActionButton:Hide()
    section.lines = {}
    parent.Sections[index] = section
    return section
end

local function EnsureChoresPreviewSection(parent, index)
    parent.Sections = parent.Sections or {}
    return parent.Sections[index] or CreateChoresPreviewSection(parent, index)
end

local function EnsureChoresPreviewLine(section, index)
    section.lines = section.lines or {}
    local line = section.lines[index]
    if line then
        return line
    end

    line = CreateFrame("Frame", nil, section)
    line.Text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.Text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    line.Text:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)
    line.Text:SetJustifyH("LEFT")
    line.Text:SetJustifyV("TOP")
    line.Text:SetWordWrap(true)
    section.lines[index] = line
    return line
end

local function CreateChoresPreviewShell(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.03, 0.03, 0.05, 0.98)
    frame:SetBackdropBorderColor(0.94, 0.77, 0.28, 0.2)

    frame.TitleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(32)
    frame.TitleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 1 },
    })

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "ARTWORK")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 0, 0)
    frame.TitleAccent:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", 0, 0)
    frame.TitleAccent:SetHeight(2)
    frame.TitleAccent:SetColorTexture(0.96, 0.78, 0.24, 0.95)

    frame.TitleIcon = frame.TitleBar:CreateTexture(nil, "OVERLAY")
    frame.TitleIcon:SetPoint("LEFT", frame.TitleBar, "LEFT", 10, 0)
    frame.TitleIcon:SetSize(16, 16)
    frame.TitleIcon:SetTexture("Interface\\Icons\\inv_scroll_11")
    frame.TitleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.TitleIcon, "RIGHT", 8, 0)
    frame.Title:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -154, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("Weekly Chores")

    frame.TitleStatus = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.TitleStatus:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -98, 0)
    frame.TitleStatus:SetJustifyH("RIGHT")
    frame.TitleStatus:SetTextColor(0.96, 0.82, 0.35)

    frame.SettingsButton = CreateFrame("Button", nil, frame.TitleBar)
    frame.SettingsButton:SetSize(28, 28)
    frame.SettingsButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -58, -2)
    frame.SettingsButton.Highlight = frame.SettingsButton:CreateTexture(nil, "HIGHLIGHT")
    frame.SettingsButton.Highlight:SetAllPoints(frame.SettingsButton)
    frame.SettingsButton.Highlight:SetColorTexture(1, 1, 1, 0.06)
    frame.SettingsButton.Icon = frame.SettingsButton:CreateTexture(nil, "ARTWORK")
    frame.SettingsButton.Icon:SetPoint("CENTER", frame.SettingsButton, "CENTER", 0, 0)
    frame.SettingsButton.Icon:SetSize(14, 14)
    frame.SettingsButton.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    frame.SettingsButton.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    frame.LockButton = CreateFrame("Button", nil, frame)
    frame.LockButton:SetSize(28, 28)
    frame.LockButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -28, -2)
    frame.LockButton.Highlight = frame.LockButton:CreateTexture(nil, "HIGHLIGHT")
    frame.LockButton.Highlight:SetAllPoints(frame.LockButton)
    frame.LockButton.Highlight:SetColorTexture(1, 1, 1, 0.08)
    frame.LockButton.Icon = frame.LockButton:CreateTexture(nil, "ARTWORK")
    frame.LockButton.Icon:SetPoint("CENTER", frame.LockButton, "CENTER", 0, 0)
    frame.LockButton.Icon:SetSize(32, 32)

    frame.CloseButton = CreateFrame("Button", nil, frame.TitleBar)
    frame.CloseButton:SetSize(18, 18)
    frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -4, 0)

    frame.EmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("CENTER", frame, "CENTER", 0, -8)
    frame.EmptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.EmptyText:SetJustifyH("CENTER")
    frame.EmptyText:SetJustifyV("MIDDLE")
    frame.EmptyText:SetWidth(math.max(200, width - 60))
    frame.EmptyText:Hide()

    frame.ContentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.ContentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame.ContentInset, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 8, -8)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame.ContentInset, "BOTTOMRIGHT", -20, 8)
    SkinScrollBar(frame.ScrollFrame, { 0.98, 0.76, 0.22 }, true)

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ScrollFrame)
    frame.ScrollChild:SetSize(1, 1)
    frame.ScrollFrame:SetScrollChild(frame.ScrollChild)
    frame.ScrollFrame:HookScript("OnSizeChanged", function(scroll)
        local availableWidth = math.max(1, (scroll:GetWidth() or 1) - 8)
        frame.ScrollChild:SetWidth(availableWidth)
    end)

    frame.ResizeHandle = CreateFrame("Button", nil, frame)
    frame.ResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    frame.ResizeHandle:SetSize(18, 18)
    frame.ResizeGlyph = frame.ResizeHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.ResizeGlyph:SetPoint("CENTER", frame.ResizeHandle, "CENTER", 0, 0)
    frame.ResizeGlyph:SetText("//")
    frame.ResizeGlyph:SetTextColor(1, 0.88, 0.45)

    frame.ResizeHighlight = frame.ResizeHandle:CreateTexture(nil, "HIGHLIGHT")
    frame.ResizeHighlight:SetAllPoints(frame.ResizeHandle)
    frame.ResizeHighlight:SetColorTexture(1, 1, 1, 0.05)
    frame.Sections = {}
    return frame
end

local function PopulateChoresPreviewShell(shell)
    if not shell then
        return
    end

    local choresDataText = GetChoresPreviewModule()
    local choresModule = T:GetModule("Chores", true)
    local choresOptions = ConfigurationModule.Options and ConfigurationModule.Options.Chores
    local state = choresModule and choresModule.GetState and choresModule:GetState() or nil
    local showCompleted = choresOptions and choresOptions.GetShowCompleted and choresOptions:GetShowCompleted() or false
    local sections = GetChoresPreviewSections(state, showCompleted)
    local fonts = GetChoresPreviewFontSettings()
    local contentHeight = 0
    local scrollWidth = shell.ScrollFrame:GetWidth() or 0
    local contentWidth = math.max(1, ((scrollWidth > 1 and scrollWidth) or (shell:GetWidth() or 1)) - 8)
    local maxContentHeight = math.max(1, (shell.ScrollFrame:GetHeight() or 1) - 2)

    if choresDataText and choresDataText.ApplyTrackerAppearance then
        choresDataText:ApplyTrackerAppearance(shell)
    end

    shell.ScrollChild:SetWidth(contentWidth)
    shell.ScrollFrame:SetVerticalScroll(0)
    shell.Title:SetFont(fonts.headerFont, math.max(fonts.headerFontSize + 2, 12), "")
    shell.TitleStatus:SetFont(fonts.headerFont, math.max(fonts.headerFontSize - 1, 10), "")
    shell.TitleStatus:SetText(state and state.enabled and string.format("%d remaining", state.totalRemaining or 0) or
        "Paused")

    local emptyText = GetChoresPreviewEmptyText(state, #sections)
    shell.EmptyText:SetShown(emptyText ~= nil)
    shell.EmptyText:SetFont(fonts.entryFont, fonts.entryFontSize, "")
    shell.EmptyText:SetText(emptyText or "")

    local sectionLimit = 3
    local visibleSectionCount = 0
    for sectionIndex = 1, math.min(#sections, sectionLimit) do
        local sectionData = sections[sectionIndex]
        local summary = sectionData.summary
        local section = EnsureChoresPreviewSection(shell, sectionIndex)
        local hasEntries = #(sectionData.displayEntries or {}) > 0
        local yOffset = hasEntries and 38 or 0
        local lineIndex = 1
        local headerR, headerG, headerB = GetChoresStatusColor(summary and summary.status or 0)

        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", shell.ScrollChild, "TOPLEFT", 0, -contentHeight)
        section:SetPoint("RIGHT", shell.ScrollChild, "RIGHT", 0, 0)
        section.Arrow:SetShown(hasEntries)
        section.Arrow:SetText("v")
        section.Title:SetFont(fonts.headerFont, fonts.headerFontSize, "")
        section.Title:ClearAllPoints()
        section.Title:SetPoint("TOPLEFT", section, "TOPLEFT", hasEntries and 28 or 12, -10)
        section.Title:SetPoint("RIGHT", section, "RIGHT", -82, 0)
        section.Title:SetText(summary and summary.name or "Weekly chores")
        section.Title:SetTextColor(1, 0.95, 0.82)
        section.Progress:SetFont(fonts.headerFont, fonts.headerFontSize, "")
        section.Progress:SetText(BuildChoresPreviewProgress(summary))
        section.Progress:SetTextColor(headerR, headerG, headerB)
        section.Divider:SetShown(hasEntries)

        for _, entry in ipairs(sectionData.displayEntries or {}) do
            if lineIndex > 4 then
                break
            end

            local line = EnsureChoresPreviewLine(section, lineIndex)
            local entryR, entryG, entryB = GetChoresStatusColor(entry and entry.state and entry.state.status or 0)
            line:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -yOffset)
            line:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, 0)
            line.Text:SetFont(fonts.entryFont, fonts.entryFontSize, "")
            line.Text:SetText("• " .. BuildChoresPreviewEntryTitle(summary, entry))
            line.Text:SetTextColor(entryR, entryG, entryB)
            line:SetHeight(math.max(line.Text:GetStringHeight(), fonts.entryFontSize))
            line:Show()
            yOffset = yOffset + line:GetHeight() + 4
            lineIndex = lineIndex + 1

            if entry and entry.state and type(entry.state.objectives) == "table" then
                for _, objective in ipairs(entry.state.objectives) do
                    if lineIndex > 5 then
                        break
                    end
                    local objectiveLine = EnsureChoresPreviewLine(section, lineIndex)
                    objectiveLine:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -yOffset)
                    objectiveLine:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, 0)
                    objectiveLine.Text:SetFont(fonts.entryFont, fonts.entryFontSize, "")
                    objectiveLine.Text:SetText("    • " .. BuildChoresPreviewObjectiveText(objective))
                    objectiveLine.Text:SetTextColor(0.72, 0.74, 0.8)
                    objectiveLine:SetHeight(math.max(objectiveLine.Text:GetStringHeight(), fonts.entryFontSize))
                    objectiveLine:Show()
                    yOffset = yOffset + objectiveLine:GetHeight() + 3
                    lineIndex = lineIndex + 1
                end
            end
        end

        for hiddenIndex = lineIndex, #(section.lines or {}) do
            section.lines[hiddenIndex]:Hide()
            section.lines[hiddenIndex].Text:SetText("")
        end

        local sectionHeight = math.max(32, yOffset + 10)
        if visibleSectionCount > 0 and contentHeight + sectionHeight + 10 > maxContentHeight then
            section:Hide()
            break
        end

        section:SetHeight(sectionHeight)
        section:Show()
        contentHeight = contentHeight + section:GetHeight() + 10
        visibleSectionCount = visibleSectionCount + 1
    end

    for sectionIndex = visibleSectionCount + 1, #(shell.Sections or {}) do
        shell.Sections[sectionIndex]:Hide()
    end

    shell.ScrollChild:SetHeight(math.max(1, contentHeight + 8))
    if choresDataText and choresDataText.ApplyTrackerAppearance then
        choresDataText:ApplyTrackerAppearance(shell)
    end
end

function UI:RenderPreviewStrip(parent, y, path, width)
    local key = JoinPath(path)
    local preview = nil
    local mythicVariant = GetMythicPreviewVariant(path)

    if key:find("Quality of Life.choresTab", 1, true) == 1 then
        preview = CreateFrame("Frame", nil, parent)
        preview:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        preview:SetSize(width, 246)

        local shellWidth = math.min(width, 340)
        local shell = CreateChoresPreviewShell(preview, shellWidth, 238)
        shell:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, 0)
        PopulateChoresPreviewShell(shell)

        preview.elapsed = 0
        preview:SetScript("OnUpdate", function(selfPreview, elapsed)
            selfPreview.elapsed = (selfPreview.elapsed or 0) + elapsed
            if selfPreview.elapsed < 0.45 then
                return
            end

            selfPreview.elapsed = 0
            PopulateChoresPreviewShell(shell)
        end)
        return y + preview:GetHeight() + ROW_SPACING
    end

    if mythicVariant == "timer" then
        local runtime = GetMythicPreviewRuntime()
        local scale = runtime and runtime.GetMythicPlusTimerScale and runtime:GetMythicPlusTimerScale() or 1
        scale = ClampPreviewValue(scale, 0.7, 1.5, 1)

        preview = CreateFrame("Frame", nil, parent)
        preview:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)

        local shellWidth = math.min(math.max(220, width / scale), 360)
        local shellHeight = 324
        preview:SetSize(width, ceil(shellHeight * scale) + 12)

        local shell = CreateMythicPlusTimerPreviewShell(preview, shellWidth, shellHeight, runtime)
        shell:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, 0)
        PopulateMythicPlusTimerPreviewShell(shell, runtime)

        preview.elapsed = 0
        preview:SetScript("OnUpdate", function(selfPreview, elapsed)
            selfPreview.elapsed = (selfPreview.elapsed or 0) + elapsed
            if selfPreview.elapsed < 0.2 then
                return
            end

            selfPreview.elapsed = 0
            local previewRuntime = GetMythicPreviewRuntime() or runtime
            local previewScale = previewRuntime and previewRuntime.GetMythicPlusTimerScale and
                previewRuntime:GetMythicPlusTimerScale() or 1
            previewScale = ClampPreviewValue(previewScale, 0.7, 1.5, 1)
            local previewShellWidth = math.min(math.max(220, width / previewScale), 360)
            shell:SetSize(previewShellWidth, shellHeight)
            selfPreview:SetHeight(ceil(shellHeight * previewScale) + 12)
            PopulateMythicPlusTimerPreviewShell(shell, previewRuntime)
        end)
        return y + preview:GetHeight() + ROW_SPACING
    end

    if mythicVariant == "interrupt" then
        local runtime = GetMythicPreviewRuntime()
        local appearance = runtime and runtime.GetTrackerAppearance and runtime:GetTrackerAppearance() or nil
        local metrics = runtime and runtime.GetTrackerMetrics and runtime:GetTrackerMetrics() or nil
        preview = CreateFrame("Frame", nil, parent)
        preview:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        preview:SetSize(width, 232)

        local shellWidth = math.min(width, 340)
        local shell = CreateTrackerPreviewShell(preview, shellWidth, 224)
        shell:SetPoint("TOPLEFT", preview, "TOPLEFT", 0, 0)
        shell.rows = {}
        shell.rowOrder = {}

        if runtime and runtime.ApplyTrackerFrameStyle then
            runtime:ApplyTrackerFrameStyle(shell)
        end

        if appearance then
            SetResolvedFont(shell.Title, appearance.fontPath, appearance.fontSize + 2, appearance.outline,
                1, 0.94, 0.82, 1)
        end

        local rows = GetMythicPreviewRows()
        preview.AnimatedRows = {}
        for index, rowData in ipairs(rows) do
            local row = CreateFrame("Frame", nil, shell.ScrollChild)
            row:EnableMouse(true)

            if runtime and runtime.CreateTrackerBar then
                row.barBackdrop, row.bar = runtime:CreateTrackerBar(row)
            else
                row.barBackdrop = CreateFrame("Frame", nil, row, "BackdropTemplate")
                row.barBackdrop:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Buttons\\WHITE8X8",
                    edgeSize = 1,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 },
                })
                row.barBackdrop:SetBackdropColor(0.03, 0.03, 0.04, 0.85)
                row.barBackdrop:SetBackdropBorderColor(0.24, 0.24, 0.29, 0.8)
                row.bar = CreateFrame("StatusBar", nil, row.barBackdrop)
                row.bar:SetPoint("TOPLEFT", row.barBackdrop, "TOPLEFT", 1, -1)
                row.bar:SetPoint("BOTTOMRIGHT", row.barBackdrop, "BOTTOMRIGHT", -1, 1)
                row.bar:SetMinMaxValues(0, 1)
            end
            row.barBackdrop:SetAllPoints(row)

            row.content = CreateFrame("Frame", nil, row)
            row.content:SetAllPoints(row)
            row.content:SetFrameLevel((row.barBackdrop:GetFrameLevel() or row:GetFrameLevel()) + 5)

            if runtime and runtime.CreateRowIconButton then
                row.iconButton, row.icon, row.iconHighlight = runtime:CreateRowIconButton(row.content, "interrupt")
            else
                row.iconButton = CreateFrame("Button", nil, row.content)
                row.iconButton:SetSize(18, 18)
                row.icon = row.iconButton:CreateTexture(nil, "ARTWORK")
                row.icon:SetAllPoints(row.iconButton)
                row.iconHighlight = row.iconButton:CreateTexture(nil, "HIGHLIGHT")
                row.iconHighlight:SetAllPoints(row.iconButton)
                row.iconHighlight:SetColorTexture(1, 1, 1, 0.08)
            end

            row.name = row.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.name:SetJustifyH("LEFT")
            row.name:SetJustifyV("MIDDLE")
            row.timer = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.timer:SetJustifyH("RIGHT")
            row.timer:SetJustifyV("MIDDLE")
            row.detail = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.detail:SetJustifyH("LEFT")
            row.detail:Hide()
            row:Show()

            shell.rows[index] = row
            shell.rowOrder[index] = row
            preview.AnimatedRows[index] = {
                row = row,
                data = rowData,
            }
        end

        if runtime and runtime.ApplyRowLayout then
            runtime:ApplyRowLayout(shell)
        else
            local rowGap = metrics and metrics.rowGap or 6
            local rowHeight = metrics and metrics.rowHeight or 22
            for index, row in ipairs(shell.rowOrder) do
                local yOffset = -2 - ((index - 1) * (rowHeight + rowGap))
                row:SetPoint("TOPLEFT", shell.ScrollChild, "TOPLEFT", 4, yOffset)
                row:SetPoint("TOPRIGHT", shell.ScrollChild, "TOPRIGHT", -4, yOffset)
                row:SetHeight(rowHeight)
            end
            shell.ScrollChild:SetHeight((#shell.rowOrder * (rowHeight + rowGap)) + 4)
        end

        preview.elapsed = 0
        preview:SetScript("OnUpdate", function(selfPreview, elapsed)
            selfPreview.elapsed = (selfPreview.elapsed or 0) + elapsed
            local previewRuntime = GetMythicPreviewRuntime()
            local previewAppearance = previewRuntime and previewRuntime.GetTrackerAppearance and
                previewRuntime:GetTrackerAppearance() or appearance
            if previewRuntime and previewRuntime.ApplyTrackerFrameStyle then
                previewRuntime:ApplyTrackerFrameStyle(shell)
            end
            if previewAppearance then
                SetResolvedFont(shell.Title, previewAppearance.fontPath, previewAppearance.fontSize + 2,
                    previewAppearance.outline, 1, 0.94, 0.82, 1)
            end

            for _, entry in ipairs(selfPreview.AnimatedRows or {}) do
                local state = GetPreviewRowState(previewRuntime, entry.data, selfPreview.elapsed)
                ApplyPreviewRowState(previewRuntime, previewAppearance or {}, entry.row, entry.data, state)
            end

            if previewRuntime and previewRuntime.ApplyRowLayout then
                previewRuntime:ApplyRowLayout(shell)
            end
        end)
        return y + preview:GetHeight() + ROW_SPACING
    end

    if key:find("Notification Panel", 1, true) == 1 then
        local options = ConfigurationModule.Options and ConfigurationModule.Options.NotificationPanel
        local fontKey = options and options.GetNotificationFont and options:GetNotificationFont() or "__default"
        local fontSizeAdjust = options and options.GetNotificationFontSizeAdjustment and
            options:GetNotificationFontSizeAdjustment() or 0
        local previewWidth = math.min(width, 320)
        preview = CreatePanel(parent, 0.08, 0.08, 0.11, 0.98, 0.16)
        preview:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
        preview:SetWidth(width)
        preview:SetHeight(246)

        local toast = CreatePanel(preview, 0.06, 0.06, 0.08, 0.98, 0.14)
        toast:SetPoint("TOPLEFT", preview, "TOPLEFT", 16, -18)
        toast:SetSize(previewWidth, 88)
        local accent = toast:CreateTexture(nil, "BORDER")
        accent:SetPoint("TOPLEFT", toast, "TOPLEFT", 1, -1)
        accent:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 1, 1)
        accent:SetWidth(4)
        accent:SetColorTexture(0.33, 0.65, 0.96, 1)
        local iconBackdrop = CreatePanel(toast, 0.08, 0.08, 0.1, 0.98, 0.16)
        iconBackdrop:SetPoint("LEFT", toast, "LEFT", 12, 0)
        iconBackdrop:SetSize(40, 40)
        local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
        icon:SetSize(36, 36)
        icon:SetTexture("Interface\\Icons\\INV_Relics_Hourglass")
        local status = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        status:SetPoint("TOPLEFT", toast, "TOPLEFT", 58, -10)
        status:SetTextColor(0.33, 0.65, 0.96)
        status:SetText("MYTHIC+ KEY")
        local titleText = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleText:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
        titleText:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -12, 0)
        titleText:SetJustifyH("LEFT")
        ApplyLSMFont(titleText, fontKey, 14 + fontSizeAdjust, "")
        titleText:SetText("Mythic Keystone")
        local body = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        body:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -6)
        body:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -12, 0)
        body:SetJustifyH("LEFT")
        ApplyLSMFont(body, fontKey, 12 + fontSizeAdjust, "")
        body:SetTextColor(0.74, 0.76, 0.82)
        body:SetText("Theater of Pain +12")
        local affixes = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        affixes:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -6)
        affixes:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -12, 0)
        affixes:SetJustifyH("LEFT")
        ApplyLSMFont(affixes, fontKey, 11 + fontSizeAdjust, "")
        affixes:SetTextColor(0.82, 0.84, 0.9)
        affixes:SetText("Fortified  •  Sanguine  •  Storming")

        local friendToast = CreatePanel(preview, 0.06, 0.06, 0.08, 0.98, 0.14)
        friendToast:SetPoint("TOPLEFT", toast, "BOTTOMLEFT", 0, -12)
        friendToast:SetSize(previewWidth - 18, 72)
        local friendAccent = friendToast:CreateTexture(nil, "BORDER")
        friendAccent:SetPoint("TOPLEFT", friendToast, "TOPLEFT", 1, -1)
        friendAccent:SetPoint("BOTTOMLEFT", friendToast, "BOTTOMLEFT", 1, 1)
        friendAccent:SetWidth(4)
        friendAccent:SetColorTexture(0.36, 0.82, 0.47, 1)
        local friendIconBackdrop = CreatePanel(friendToast, 0.08, 0.08, 0.1, 0.98, 0.16)
        friendIconBackdrop:SetPoint("LEFT", friendToast, "LEFT", 12, 0)
        friendIconBackdrop:SetSize(36, 36)
        local friendIcon = friendIconBackdrop:CreateTexture(nil, "ARTWORK")
        friendIcon:SetPoint("CENTER", friendIconBackdrop, "CENTER", 0, 0)
        friendIcon:SetSize(32, 32)
        friendIcon:SetTexture("Interface\\FriendsFrame\\InformationIcon")
        local friendState = friendToast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        friendState:SetPoint("TOPRIGHT", friendToast, "TOPRIGHT", -10, -12)
        friendState:SetTextColor(0.36, 0.82, 0.47)
        friendState:SetText("ONLINE")
        local friendName = friendToast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        friendName:SetPoint("TOPLEFT", friendIconBackdrop, "TOPRIGHT", 10, -2)
        friendName:SetPoint("TOPRIGHT", friendState, "TOPLEFT", -8, 0)
        friendName:SetJustifyH("LEFT")
        ApplyLSMFont(friendName, fontKey, 14 + fontSizeAdjust, "")
        friendName:SetTextColor(0.42, 0.69, 1)
        friendName:SetText("Mythweaver")
        local friendBody = friendToast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        friendBody:SetPoint("TOPLEFT", friendName, "BOTTOMLEFT", 0, -6)
        friendBody:SetPoint("TOPRIGHT", friendToast, "TOPRIGHT", -10, 0)
        friendBody:SetJustifyH("LEFT")
        ApplyLSMFont(friendBody, fontKey, 11 + fontSizeAdjust, "")
        friendBody:SetTextColor(0.82, 0.84, 0.9)
        friendBody:SetText("Joined from Durotar")

        local test = CreateFrame("Button", nil, preview, "BackdropTemplate")
        test:SetSize(112, 24)
        test:SetPoint("TOPRIGHT", friendToast, "BOTTOMRIGHT", 0, -12)
        SkinActionButton(test, { 0.42, 0.89, 0.63 })
        SetButtonText(test, "Test Toast")
        test:SetFrameLevel(preview:GetFrameLevel() + 10)
        test:SetScript("OnClick", function()
            local options = ConfigurationModule.Options and ConfigurationModule.Options.NotificationPanel
            if options and options.TestKeystoneNotification then
                options:TestKeystoneNotification()
            end
        end)
        return y + preview:GetHeight() + ROW_SPACING
    end

    return y
end

function UI:CreateContentFrame(parent, y, height, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    frame:SetSize(width, height)
    return frame, y + height + ROW_SPACING
end

function UI:RenderDescription(parent, y, text, width)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    frame:SetSize(width, 1)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetTextColor(0.72, 0.74, 0.8)
    label:SetText(text)
    frame:SetHeight(label:GetStringHeight())
    return y + frame:GetHeight() + ROW_SPACING
end

function UI:CreateOptionCard(parent, y, width, title, desc)
    local card = CreatePanel(parent, 0.08, 0.08, 0.11, 0.98, 0.12)
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    card:SetSize(width, 56)
    card.Title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.Title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
    card.Title:SetPoint("RIGHT", card, "RIGHT", -250, 0)
    card.Title:SetJustifyH("LEFT")
    card.Title:SetText(title)
    card.Desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.Desc:SetPoint("TOPLEFT", card.Title, "BOTTOMLEFT", 0, -4)
    card.Desc:SetPoint("RIGHT", card, "RIGHT", -250, 0)
    card.Desc:SetJustifyH("LEFT")
    card.Desc:SetTextColor(0.72, 0.74, 0.8)
    card.Desc:SetText(desc or "")
    local computedHeight = math.max(56, 18 + card.Title:GetStringHeight() + card.Desc:GetStringHeight())
    card:SetHeight(computedHeight)
    return card, y + computedHeight + ROW_SPACING
end

function UI:SetOptionCardControlWidth(card, controlWidth)
    if not card then
        return
    end

    local inset = controlWidth or 250
    card.Title:ClearAllPoints()
    card.Title:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -10)
    card.Title:SetPoint("RIGHT", card, "RIGHT", -inset, 0)
    card.Title:SetJustifyH("LEFT")
    card.Desc:ClearAllPoints()
    card.Desc:SetPoint("TOPLEFT", card.Title, "BOTTOMLEFT", 0, -4)
    card.Desc:SetPoint("RIGHT", card, "RIGHT", -inset, 0)
    card.Desc:SetJustifyH("LEFT")
end

function UI:RenderToggle(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    local card
    card, y = self:CreateOptionCard(parent, y, width, GetDisplayName(path, key, option),
        ResolveTextValue(option.desc, info))
    self:SetOptionCardControlWidth(card, 112)
    local disabled = IsOptionDisabled(option, info)
    local value = ResolveOptionMethod(option, info) == true
    local button = CreateFrame("Button", nil, card, "BackdropTemplate")
    button:SetSize(84, 28)
    button:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    SkinActionButton(button, value and { 0.42, 0.89, 0.63 } or { 0.4, 0.44, 0.52 })
    SetButtonText(button, value and "Enabled" or "Disabled")
    if disabled then
        button:SetAlpha(0.5)
    end
    button:SetScript("OnClick", function()
        if disabled then
            return
        end
        self:PlayThemeSound(value and "toggle_off" or "toggle_on")
        ResolveOptionMethod(option, info, not value)
        self:RequestRenderCurrentPage()
    end)
    return y
end

function UI:RenderExecute(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    local card
    card, y = self:CreateOptionCard(parent, y, width, GetDisplayName(path, key, option),
        ResolveTextValue(option.desc, info))
    self:SetOptionCardControlWidth(card, 206)
    local disabled = IsOptionDisabled(option, info)
    local button = CreateFrame("Button", nil, card, "BackdropTemplate")
    button:SetSize(178, 34)
    button:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    SkinActionButton(button, { 0.98, 0.76, 0.22 })
    SetButtonText(button, GetDisplayName(path, key, option), true)
    button:SetAlpha(disabled and 0.5 or 1)
    button:SetScript("OnClick", function()
        if disabled then
            return
        end
        self:PlayThemeSound("click")
        local handler = option.handler
        local func = option.func
        if type(func) == "function" then
            func(info)
        elseif type(func) == "string" and handler and type(handler[func]) == "function" then
            handler[func](handler, info)
        end
    end)
    return y
end

function UI:RenderRange(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    local card
    card, y = self:CreateOptionCard(parent, y, width, GetDisplayName(path, key, option),
        ResolveTextValue(option.desc, info))
    self:SetOptionCardControlWidth(card, 266)
    local current = tonumber(ResolveOptionMethod(option, info)) or 0
    local minValue = option.min or option.softMin or 0
    local maxValue = option.max or option.softMax or 100
    local stepValue = option.step or 1
    local disabled = IsOptionDisabled(option, info)

    local function GetStepPrecision(step)
        local stepText = tostring(step or 1)
        local decimals = stepText:match("%.(%d+)")
        return decimals and #decimals or 0
    end

    local valuePrecision = GetStepPrecision(stepValue)

    local function ClampValue(value)
        return math.max(minValue, math.min(maxValue, value))
    end

    local function SnapValue(value)
        if not stepValue or stepValue <= 0 then
            return ClampValue(value)
        end

        local snapped = minValue + (math.floor(((value - minValue) / stepValue) + 0.5) * stepValue)
        return ClampValue(snapped)
    end

    local function ToDisplayValue(value)
        if option.isPercent then
            return value * 100
        end

        return value
    end

    local function FromDisplayValue(value)
        if option.isPercent then
            return value / 100
        end

        return value
    end

    local function FormatRangeValue(value, forInput)
        local displayValue = ToDisplayValue(value)
        if option.isPercent then
            if forInput then
                return string.format("%.0f", displayValue)
            end
            return string.format("%.0f%%", displayValue)
        end

        local precision = valuePrecision
        if precision <= 0 then
            return string.format("%.0f", displayValue)
        end

        return string.format("%." .. tostring(precision) .. "f", displayValue)
    end

    local accent = self.currentAccent or { 0.98, 0.76, 0.22 }
    local shell = CreatePanel(card, 0.06, 0.06, 0.09, 0.98, 0.18)
    shell:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    shell:SetSize(236, 48)
    shell:SetBackdropBorderColor(accent[1], accent[2], accent[3], disabled and 0.12 or 0.28)

    shell.ValueShell = CreatePanel(shell, 0.08, 0.08, 0.11, 0.98, 0.14)
    shell.ValueShell:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -6, -5)
    shell.ValueShell:SetSize(58, 20)
    shell.ValueShell:SetBackdropBorderColor(accent[1], accent[2], accent[3], disabled and 0.08 or 0.22)

    shell.ValueEdit = CreateFrame("EditBox", nil, shell.ValueShell)
    shell.ValueEdit:SetAutoFocus(false)
    shell.ValueEdit:SetPoint("TOPLEFT", shell.ValueShell, "TOPLEFT", 6, -1)
    shell.ValueEdit:SetPoint("BOTTOMRIGHT", shell.ValueShell, "BOTTOMRIGHT", -6, 1)
    shell.ValueEdit:SetFontObject("ChatFontNormal")
    shell.ValueEdit:SetJustifyH("CENTER")
    shell.ValueEdit:SetTextColor(disabled and 0.56 or 0.96, disabled and 0.58 or 0.94, disabled and 0.62 or 0.9)
    shell.ValueEdit:SetEnabled(not disabled)
    shell.ValueEdit:SetText(FormatRangeValue(current, true))

    if option.isPercent then
        shell.PercentLabel = shell.ValueShell:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        shell.PercentLabel:SetPoint("RIGHT", shell.ValueShell, "RIGHT", -6, 0)
        shell.PercentLabel:SetText("%")
        shell.PercentLabel:SetTextColor(0.72, 0.74, 0.8)
        shell.ValueEdit:ClearAllPoints()
        shell.ValueEdit:SetPoint("TOPLEFT", shell.ValueShell, "TOPLEFT", 6, -1)
        shell.ValueEdit:SetPoint("BOTTOMRIGHT", shell.PercentLabel, "LEFT", -4, 1)
    end

    local slider = CreateFrame("Slider", nil, shell)
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("LEFT", shell, "LEFT", 12, 0)
    slider:SetPoint("RIGHT", shell.ValueShell, "LEFT", -10, 0)
    slider:SetPoint("CENTER", shell, "CENTER", 0, 4)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(stepValue)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(current)
    slider:SetEnabled(not disabled)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    slider.Track = shell:CreateTexture(nil, "ARTWORK")
    slider.Track:SetPoint("LEFT", shell, "LEFT", 12, 0)
    slider.Track:SetPoint("RIGHT", shell.ValueShell, "LEFT", -10, 0)
    slider.Track:SetHeight(4)
    slider.Track:SetColorTexture(0.22, 0.24, 0.3, 0.95)
    slider.Fill = shell:CreateTexture(nil, "OVERLAY")
    slider.Fill:SetPoint("LEFT", slider.Track, "LEFT", 0, 0)
    slider.Fill:SetHeight(4)
    slider.Fill:SetColorTexture(accent[1], accent[2], accent[3], 0.95)
    slider.Knob = CreatePanel(shell, accent[1] * 0.2, accent[2] * 0.2, accent[3] * 0.2, 1, 0.6)
    slider.Knob:SetSize(12, 18)
    slider.Knob:SetBackdropBorderColor(accent[1], accent[2], accent[3], disabled and 0.45 or 1)
    slider.Knob:SetFrameLevel(shell:GetFrameLevel() + 5)
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(1, 1)
        thumb:SetVertexColor(0, 0, 0, 0)
    end
    slider.Low = slider:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slider.Low:SetPoint("BOTTOMLEFT", shell, "BOTTOMLEFT", 8, 3)
    slider.Low:SetText(FormatRangeValue(minValue, true))
    slider.High = slider:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    slider.High:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -8, 3)
    slider.High:SetText(FormatRangeValue(maxValue, true))
    slider.ValueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.ValueText:SetPoint("TOPLEFT", shell, "TOPLEFT", 10, -7)
    slider.ValueText:SetPoint("RIGHT", shell.ValueShell, "LEFT", -8, 0)
    slider.ValueText:SetJustifyH("LEFT")
    slider.ValueText:SetText("Drag or type")

    local function ApplyRangeValue(rawValue)
        if disabled then
            return
        end

        local normalized = SnapValue(rawValue)
        slider:SetValue(normalized)
        ResolveOptionMethod(option, info, normalized)
        self:RequestRenderCurrentPage()
    end

    local function UpdateSliderVisual(value)
        local minRange, maxRange = slider:GetMinMaxValues()
        local totalRange = maxRange - minRange
        local ratio = totalRange > 0 and ((value - minRange) / totalRange) or 0
        ratio = math.max(0, math.min(1, ratio))
        local trackWidth = math.max(1, slider.Track:GetWidth() or (shell:GetWidth() - 24))
        slider.Fill:SetWidth(trackWidth * ratio)
        slider.Knob:ClearAllPoints()
        slider.Knob:SetPoint("CENTER", slider.Track, "LEFT", trackWidth * ratio, 0)
    end

    slider:SetScript("OnValueChanged", function(selfSlider, value)
        UpdateSliderVisual(value)
        selfSlider.ValueText:SetText(FormatRangeValue(value, false))
        if shell.ValueEdit and not shell.ValueEdit:HasFocus() then
            shell.ValueEdit:SetText(FormatRangeValue(value, true))
        end
    end)
    slider:SetScript("OnMouseUp", function(selfSlider)
        if disabled then
            return
        end
        ApplyRangeValue(selfSlider:GetValue())
    end)
    slider:SetScript("OnMouseWheel", function(selfSlider, delta)
        if disabled then
            return
        end
        selfSlider:SetValue(selfSlider:GetValue() + (delta * stepValue))
    end)

    shell.ValueEdit:SetScript("OnEditFocusGained", function()
        shell.ValueShell:SetBackdropBorderColor(accent[1], accent[2], accent[3], disabled and 0.12 or 0.48)
    end)
    shell.ValueEdit:SetScript("OnEditFocusLost", function(selfEdit)
        shell.ValueShell:SetBackdropBorderColor(accent[1], accent[2], accent[3], disabled and 0.08 or 0.22)
        selfEdit:SetText(FormatRangeValue(slider:GetValue(), true))
    end)
    shell.ValueEdit:SetScript("OnEscapePressed", function(selfEdit)
        selfEdit:SetText(FormatRangeValue(slider:GetValue(), true))
        selfEdit:ClearFocus()
    end)
    shell.ValueEdit:SetScript("OnEnterPressed", function(selfEdit)
        local sanitizedText = ((selfEdit:GetText() or ""):gsub("%%", ""))
        local entered = tonumber(sanitizedText)
        if entered ~= nil then
            ApplyRangeValue(FromDisplayValue(entered))
        else
            selfEdit:SetText(FormatRangeValue(slider:GetValue(), true))
        end
        selfEdit:ClearFocus()
    end)

    UpdateSliderVisual(current)
    return y
end

function UI:RenderInput(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    local card
    card, y = self:CreateOptionCard(parent, y, width, GetDisplayName(path, key, option),
        ResolveTextValue(option.desc, info))
    self:SetOptionCardControlWidth(card, 250)
    local current = ResolveOptionMethod(option, info) or ""
    local disabled = IsOptionDisabled(option, info)
    local shell = CreatePanel(card, 0.07, 0.07, 0.1, 0.98, 0.12)
    shell:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    shell:SetSize(220, 28)
    local edit = CreateFrame("EditBox", nil, shell)
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", shell, "TOPLEFT", 8, -1)
    edit:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -8, 1)
    edit:SetFontObject("ChatFontNormal")
    edit:SetText(tostring(current))
    edit:SetEnabled(not disabled)
    edit:SetScript("OnEnterPressed", function(selfEdit)
        ResolveOptionMethod(option, info, selfEdit:GetText())
        selfEdit:ClearFocus()
        self:RequestRenderCurrentPage()
    end)
    return y
end

function UI:RenderSelect(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    local card
    card, y = self:CreateOptionCard(parent, y, width, GetDisplayName(path, key, option),
        ResolveTextValue(option.desc, info))
    local disabled = IsOptionDisabled(option, info)
    local values = ResolveOptionValues(option, info)
    local current = ResolveOptionMethod(option, info)
    local currentKey = ResolveSelectedValueKey(option, current, values)
    local label = GetSelectDisplayText(option, currentKey, values[currentKey])
    local hasSoundTest = option.dialogControl == "LSM30_Sound"
    local totalWidth = hasSoundTest and 274 or 250
    self:SetOptionCardControlWidth(card, totalWidth)
    local button = CreateFrame("Button", nil, card, "BackdropTemplate")
    button:SetSize(hasSoundTest and 182 or 220, 28)
    button:SetPoint("RIGHT", card, "RIGHT", hasSoundTest and -76 or -14, 0)
    SkinActionButton(button, { 0.45, 0.82, 1.0 })
    button:SetText("")
    button.Label = button.Label or button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.Label:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.Label:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    button.Label:SetJustifyH("LEFT")
    button.Label:SetText(label ~= "" and label or "Select")
    if option.dialogControl == "LSM30_Font" then
        ApplyLSMFont(button.Label, currentKey, 12, "")
    elseif option.dialogControl == "LSM30_Statusbar" and LSM then
        button.TexturePreview = button.TexturePreview or button:CreateTexture(nil, "BACKGROUND")
        button.TexturePreview:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        button.TexturePreview:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        local texturePath = LSM:Fetch("statusbar", currentKey, true)
        if texturePath then
            button.TexturePreview:SetTexture(texturePath)
            button.TexturePreview:SetVertexColor(1, 1, 1, 0.24)
            button.TexturePreview:SetAlpha(1)
        else
            button.TexturePreview:SetAlpha(0)
        end
        button.Label:SetFont(STANDARD_TEXT_FONT, 12, "")
    else
        if button.TexturePreview then
            button.TexturePreview:SetAlpha(0)
        end
        button.Label:SetFont(STANDARD_TEXT_FONT, 12, "")
    end
    button:SetAlpha(disabled and 0.5 or 1)
    button:SetScript("OnClick", function(selfButton)
        if disabled then
            return
        end

        self:OpenSelectMenu(selfButton, option, info, values, currentKey, GetDisplayName(path, key, option))
    end)

    if hasSoundTest then
        local testButton = CreateFrame("Button", nil, card, "BackdropTemplate")
        testButton:SetSize(54, 28)
        testButton:SetPoint("RIGHT", card, "RIGHT", -14, 0)
        SkinActionButton(testButton, { 0.42, 0.89, 0.63 })
        SetButtonText(testButton, "Play")
        testButton:SetAlpha((disabled or not currentKey or currentKey == "None") and 0.5 or 1)
        testButton:SetScript("OnClick", function()
            if disabled then
                return
            end
            self:PlayConfiguredSound(currentKey)
        end)
    end
    return y
end

function UI:RenderColor(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    local card
    card, y = self:CreateOptionCard(parent, y, width, GetDisplayName(path, key, option),
        ResolveTextValue(option.desc, info))
    local disabled = IsOptionDisabled(option, info)
    local red, green, blue, alpha = ResolveOptionMethod(option, info)
    red = tonumber(red) or 1
    green = tonumber(green) or 1
    blue = tonumber(blue) or 1
    alpha = tonumber(alpha) or 1
    local button = CreateFrame("Button", nil, card, "BackdropTemplate")
    button:SetSize(44, 28)
    button:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropBorderColor(1, 1, 1, 0.18)
    button:SetBackdropColor(red, green, blue, alpha)
    button:SetAlpha(disabled and 0.5 or 1)
    button:SetScript("OnClick", function()
        if disabled or not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
            return
        end

        local function applyColor()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = option.hasAlpha == true and ColorPickerFrame:GetColorAlpha() or 1
            ResolveOptionMethod(option, info, nr, ng, nb, na)
            self:RequestRenderCurrentPage()
        end

        local function cancelColor(previousValues)
            local prev = previousValues or { r = red, g = green, b = blue, a = alpha, opacity = alpha }
            local prevAlpha = prev.a
            if prevAlpha == nil then
                prevAlpha = prev.opacity
            end
            ResolveOptionMethod(option, info, prev.r, prev.g, prev.b, prevAlpha or alpha)
            self:RequestRenderCurrentPage()
        end

        ColorPickerFrame:SetupColorPickerAndShow({
            r = red,
            g = green,
            b = blue,
            opacity = alpha,
            hasOpacity = option.hasAlpha == true,
            swatchFunc = applyColor,
            func = applyColor,
            opacityFunc = applyColor,
            cancelFunc = cancelColor,
        })
    end)
    return y
end

function UI:RenderKeybinding(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    local card
    card, y = self:CreateOptionCard(parent, y, width, GetDisplayName(path, key, option),
        ResolveTextValue(option.desc, info))
    self:SetOptionCardControlWidth(card, 180)
    local disabled = IsOptionDisabled(option, info)
    local current = ResolveOptionMethod(option, info)
    local button = CreateFrame("Button", nil, card, "BackdropTemplate")
    button:SetSize(150, 28)
    button:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    SkinActionButton(button, { 0.78, 0.82, 0.88 })
    button.Label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.Label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.Label:SetTextColor(1, 0.95, 0.86)
    button.Label:SetText(current ~= "" and tostring(current) or "Set Binding")
    button:SetAlpha(disabled and 0.5 or 1)
    button:SetScript("OnClick", function()
        if disabled then
            return
        end
        self:BeginBindingCapture(button, option, info)
    end)
    return y
end

function UI:RenderOption(parent, y, width, option, path, key)
    local info = BuildOptionInfo(path, key, option)
    if IsOptionHidden(option, info) then
        return y
    end

    if key == "title" then
        return y
    end

    local optionType = option.type
    if optionType == "description" then
        local text = ResolveTextValue(option.name, info)
        if text ~= "" and text ~= " " then
            return self:RenderDescription(parent, y, text, width)
        end
        return y + 4
    end
    if optionType == "toggle" then
        return self:RenderToggle(parent, y, width, option, path, key)
    end
    if optionType == "execute" then
        return self:RenderExecute(parent, y, width, option, path, key)
    end
    if optionType == "range" then
        return self:RenderRange(parent, y, width, option, path, key)
    end
    if optionType == "select" then
        return self:RenderSelect(parent, y, width, option, path, key)
    end
    if optionType == "color" then
        return self:RenderColor(parent, y, width, option, path, key)
    end
    if optionType == "input" then
        return self:RenderInput(parent, y, width, option, path, key)
    end
    if optionType == "keybinding" then
        return self:RenderKeybinding(parent, y, width, option, path, key)
    end
    return y
end

function UI:InvalidateTabSelection(path)
    if not self.selectedTabs then
        return
    end

    local prefix = JoinPath(path or {})
    if prefix == "" then
        return
    end

    for stateKey in pairs(self.selectedTabs) do
        if stateKey == prefix or stateKey:find(prefix .. ".", 1, true) == 1 then
            self.selectedTabs[stateKey] = nil
        end
    end
end

function UI:RenderTabBar(parent, y, width, path, groups, desiredPath)
    local stateKey = JoinPath(path)
    self.selectedTabs = self.selectedTabs or {}
    local selectedKey = self.selectedTabs[stateKey]
    if desiredPath and desiredPath[1] then
        selectedKey = desiredPath[1]
    end

    local hasSelectedKey = false
    for _, entry in ipairs(groups) do
        if entry.key == selectedKey then
            hasSelectedKey = true
            break
        end
    end
    if not hasSelectedKey then
        selectedKey = groups[1] and groups[1].key or nil
    end

    if not selectedKey then
        selectedKey = groups[1] and groups[1].key or nil
    end
    self.selectedTabs[stateKey] = selectedKey

    local normalizedDesiredPath = desiredPath
    if desiredPath and desiredPath[1] ~= selectedKey then
        normalizedDesiredPath = nil
        self.currentPath = ClonePath(path)
        if selectedKey then
            self.currentPath[#self.currentPath + 1] = selectedKey
        end
    end

    local bar = CreatePanel(parent, 0.08, 0.08, 0.11, 0.98, 0.12)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    bar:SetSize(width, 1)
    local accent = self.currentAccent or { 0.98, 0.76, 0.22 }
    local sections = GetTabSections(path, groups)
    local cursorY = 8
    local useFeatureGrid = path[1] == "Quality of Life" and #path == 1

    for _, section in ipairs(sections) do
        if section.title then
            local heading = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            heading:SetPoint("TOPLEFT", bar, "TOPLEFT", 12, -cursorY)
            heading:SetTextColor(accent[1], accent[2], accent[3])
            heading:SetText(section.title)
            cursorY = cursorY + 18
        end

        local xOffset = 10
        local rowHeight = useFeatureGrid and 42 or 28
        local maxWidth = useFeatureGrid and math.floor((width - 28) / 2) or 240
        for _, entry in ipairs(section.entries) do
            local label = GetDisplayName(path, entry.key, entry.option)
            local button = CreateFrame("Button", nil, bar, "BackdropTemplate")
            local buttonWidth = useFeatureGrid and maxWidth or MeasureButtonWidth(label, 90, maxWidth)
            if xOffset + buttonWidth > (width - 10) then
                xOffset = 10
                cursorY = cursorY + rowHeight + 8
            end
            button:SetPoint("TOPLEFT", bar, "TOPLEFT", xOffset, -cursorY)
            button:SetHeight(rowHeight)
            button:SetWidth(buttonWidth)
            local active = entry.key == selectedKey
            SkinActionButton(button, active and accent or { 0.32, 0.36, 0.44 })
            SetButtonText(button, label, useFeatureGrid)
            button:SetScript("OnClick", function()
                self.selectedTabs[stateKey] = entry.key
                self.currentPath = ClonePath(path)
                self.currentPath[#self.currentPath + 1] = entry.key
                self:RequestRenderCurrentPage()
            end)
            xOffset = xOffset + buttonWidth + 8
        end

        cursorY = cursorY + rowHeight + 10
    end
    bar:SetHeight(cursorY)

    local selectedSection = nil
    for _, entry in ipairs(groups) do
        if entry.key == selectedKey then
            selectedSection = entry.option
            break
        end
    end

    y = y + bar:GetHeight() + ROW_SPACING
    if selectedSection then
        local childPath = ClonePath(path)
        childPath[#childPath + 1] = selectedKey
        local remainingPath = nil
        if normalizedDesiredPath and normalizedDesiredPath[1] == selectedKey and #normalizedDesiredPath > 1 then
            remainingPath = { unpackValues(normalizedDesiredPath, 2) }
        end
        y = self:RenderSection(parent, y, width, selectedSection, childPath, remainingPath, false)
    end
    return y
end

function UI:RenderGroupBlock(parent, y, width, option, path, key, desiredPath)
    local horizontalInset = 12
    local panel = CreatePanel(parent, 0.08, 0.08, 0.11, 0.98, 0.12)
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    panel:SetSize(width, 1)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)
    title:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    title:SetJustifyH("LEFT")
    title:SetText(GetDisplayName(path, key, option))

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", horizontalInset, -36)
    content:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -horizontalInset, -36)
    content:SetSize(math.max(1, width - (horizontalInset * 2)), 1)

    local bodyY = 0
    local childPath = ClonePath(path)
    childPath[#childPath + 1] = key
    local remainingPath = nil
    if desiredPath and desiredPath[1] == key and #desiredPath > 1 then
        remainingPath = { unpackValues(desiredPath, 2) }
    end
    bodyY = self:RenderSection(content, bodyY, width - (horizontalInset * 2), option, childPath, remainingPath, true)
    content:SetHeight(math.max(1, bodyY))
    panel:SetHeight(bodyY + 44)
    return y + panel:GetHeight() + ROW_SPACING
end

function UI:RenderSection(parent, y, width, section, path, desiredPath, skipTitle)
    local ordered = GetOrderedEntries(section)
    local grouped = {}
    local standardGroups = {}

    if not skipTitle and section.name and section.name ~= "" then
        y = self:RenderDescription(parent, y, ResolveTextValue(section.name, BuildSectionInfo(path, section)), width)
    end

    for _, entry in ipairs(ordered) do
        local option = entry.option
        local info = BuildOptionInfo(path, entry.key, option, section)
        if not IsOptionHidden(option, info) then
            if option.type == "group" then
                if section.childGroups then
                    grouped[#grouped + 1] = entry
                else
                    standardGroups[#standardGroups + 1] = entry
                end
            else
                y = self:RenderOption(parent, y, width, option, path, entry.key)
            end
        end
    end

    if #grouped > 0 then
        y = self:RenderTabBar(parent, y, width, path, grouped, desiredPath)
    else
        for _, entry in ipairs(standardGroups) do
            y = self:RenderGroupBlock(parent, y, width, entry.option, path, entry.key, desiredPath)
        end
    end

    return y
end

function UI:RenderCurrentPage()
    local frame = self:EnsureFrame()
    if self.currentPageId == "dashboard" then
        return
    end

    if self.isRenderingPage then
        self.pendingPageRender = true
        return
    end

    self.isRenderingPage = true

    self:HideSelectMenu()

    if self.pageRoot then
        self:RecycleFrameTree(self.pageRoot)
        self.pageRoot = nil
    end

    local path = self.currentPath or {}
    local item = self:FindNavItem(self.currentPageId)
    local rootPath = item and item.path or path
    local desiredPath = {}
    if #path > #rootPath then
        for index = #rootPath + 1, #path do
            desiredPath[#desiredPath + 1] = path[index]
        end
    end

    local section = GetSectionByPath(ConfigurationModule.optionsTable, rootPath)
    if not section then
        self.isRenderingPage = false
        return
    end

    self.currentAccent = item and item.accent or { 0.98, 0.76, 0.22 }
    self:ConfigureOptionsLayout(path)
    self:RenderStickyPreview(path)

    if self.resetScrollOnNextRender then
        frame.OptionsScrollFrame:SetVerticalScroll(0)
        self.resetScrollOnNextRender = nil
    end

    local scrollWidth = math.max(1, (frame.OptionsScrollFrame:GetWidth() or frame.OptionsScrollChild:GetWidth() or 1) - 8)
    frame.OptionsScrollChild:SetWidth(scrollWidth)
    local width = math.max(320, scrollWidth - 8)
    local root = CreateFrame("Frame", nil, frame.OptionsScrollChild)
    root:SetPoint("TOPLEFT", frame.OptionsScrollChild, "TOPLEFT", 0, 0)
    root:SetSize(width, 1)
    self.pageRoot = root
    local y = 0
    y = self:RenderSection(root, y, width, section, rootPath, desiredPath, true)
    root:SetHeight(y + 8)
    frame.OptionsScrollChild:SetHeight(math.max(1, y + 8))

    self.isRenderingPage = false
    if self.pendingPageRender then
        self.pendingPageRender = false
        self:RenderCurrentPage()
    end
end

function UI:ShowDashboard(item)
    local frame = self:EnsureFrame()
    self.currentPageId = item and item.id or "dashboard"
    self.currentPath = nil
    self:ConfigureHeader(item or NAV_ITEMS[1], nil)
    if self.pageRoot then
        self:RecycleFrameTree(self.pageRoot)
        self.pageRoot = nil
    end
    if self.previewRoot then
        self:RecycleFrameTree(self.previewRoot)
        self.previewRoot = nil
    end
    frame.OptionsHost:Hide()
    if frame.DashboardScrollFrame then
        frame.DashboardScrollFrame:SetVerticalScroll(0)
    end
    frame.OptionsScrollFrame:SetVerticalScroll(0)
    frame.PreviewHost:Hide()
    frame.Dashboard:Show()
    self:RefreshDashboard()
end

function UI:ShowOptions(item, path)
    local frame = self:EnsureFrame()
    self.currentPageId = item.id
    self.currentPath = ClonePath(path or item.path or {})
    self:ConfigureHeader(item, self.currentPath)
    frame.Dashboard:Hide()
    frame.OptionsHost:Show()
    self:RequestRenderCurrentPage(true)
end

function UI:OpenPage(pageId, path)
    local item = self:FindNavItem(pageId)
    if not item or item.id == "dashboard" then
        self:ShowDashboard(item)
        self:RefreshSidebar()
        return
    end
    self:ShowOptions(item, path or item.path)
    self:RefreshSidebar()
end

function UI:Show(...)
    local requestedPath = { ... }
    local frame = self:EnsureFrame()
    frame:Show()
    frame:Raise()
    local item = self:FindNavItemForPath(requestedPath)
    if #requestedPath == 0 then
        self:OpenPage("dashboard")
    else
        self:OpenPage(item.id, requestedPath)
    end
end

function UI:Hide()
    local frame = self:GetFrame()
    if frame then
        frame:Hide()
    end
    if self.pageRoot then
        self:RecycleFrameTree(self.pageRoot)
        self.pageRoot = nil
    end
    if self.previewRoot then
        self:RecycleFrameTree(self.previewRoot)
        self.previewRoot = nil
    end
end

function UI:Toggle(...)
    local frame = self:EnsureFrame()
    local requestedPath = { ... }
    if frame:IsShown() then
        if #requestedPath == 0 then
            frame:Hide()
            return
        end
        local item = self:FindNavItemForPath(requestedPath)
        self:OpenPage(item.id, requestedPath)
        return
    end
    self:Show(unpackValues(requestedPath))
end
