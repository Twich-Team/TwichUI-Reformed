---@diagnostic disable: undefined-field, undefined-global, deprecated
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class UISecure
local UI = Tools.UI or {}
Tools.UI = UI
local DebugConsole = UI.DebugConsole or nil

local _G = _G
local tinsert = tinsert
local pairs = pairs
local type = type
local tonumber = tonumber
local InCombatLockdown = InCombatLockdown
local PlaySound = _G.PlaySound
local PlaySoundFile = _G.PlaySoundFile
local SOUNDKIT = _G.SOUNDKIT
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local LibStub = _G.LibStub
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)

-- Store pending macro executions
local pendingMacros = {}
local MENU_MIN_WIDTH = 180
local MENU_MAX_WIDTH = 560
local MENU_EDGE_PADDING = 24
local MENU_FADE_IN_DURATION = 0.08
local MENU_FADE_OUT_DURATION = 0.07
local TOOLTIP_OFFSET = 8
local TOOLTIP_EDGE_PADDING = 16

local function LogSecureMenuDebug(message, ...)
    if not (DebugConsole and DebugConsole.Logf) then
        return
    end

    pcall(DebugConsole.Logf, DebugConsole, "datatexts", false, "SecureMenu: " .. message, ...)
end

local function ProcessPendingMacros()
    if #pendingMacros == 0 then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingMacros = {}
        return
    end

    local callback = table.remove(pendingMacros, 1)
    if callback and type(callback) == "function" then
        callback()
    end

    if #pendingMacros > 0 then
        _G.C_Timer.After(0.01, ProcessPendingMacros)
    end
end

---@class TwichUISecureMenuEntry
---@field text string           -- Display text (already includes any icon formatting)
---@field width number|nil      -- Optional fixed width for this row
---@field tooltip string|nil    -- Optional tooltip text
---@field func function|nil     -- Optional non-secure callback for this row
---@field macrotext string|nil  -- If set, runs as a secure macro: type="macro", macrotext
---@field item string|number|nil -- If set, secure type="item", attribute "item"
---@field spell string|number|nil -- If set, secure type="spell", attribute "spell"
---@field checked boolean|nil   -- If true, show as checked/toggled on
---@field disabled boolean|nil  -- If true, row is visible but not clickable
---@field isTitle boolean|nil   -- If true, show as a non-clickable title row
---@field keepShownOnClick boolean|nil -- If true, keep the menu visible after the row is clicked
---@field notCheckable boolean|nil -- If true, suppress toggle state indicator

---@class TwichUISecureMenu
---@field frame Frame
---@field buttons Button[]
---@field entries TwichUISecureMenuEntry[]
---@field Toggle fun(self:TwichUISecureMenu, anchor:Frame, point:string|nil, relativePoint:string|nil, x:number|nil, y:number|nil)
---@field Hide fun(self:TwichUISecureMenu)
---@field SetEntries fun(self:TwichUISecureMenu, entries:TwichUISecureMenuEntry[])

local function GetBorderAndBackdrop()
    ---@diagnostic disable-next-line: undefined-field
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.media and E.media.bordercolor and E.media.backdropfadecolor then
        local br, bg, bb = unpack(E.media.bordercolor)
        local fr, fg, fb, fa = unpack(E.media.backdropfadecolor)
        return br or 0, bg or 0, bb or 0, fr or 0.06, fg or 0.06, fb or 0.06, fa or 0.9
    end
    return 0, 0, 0, 0.06, 0.06, 0.06, 0.9
end

local function SkinBackdrop(frame)
    local br, bg, bb, fr, fg, fb, fa = GetBorderAndBackdrop()
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(fr, fg, fb, fa)
    frame:SetBackdropBorderColor(br, bg, bb, 1)
end

local function PlayMenuClickSound()
    -- MediaLoader registers sounds with hyphens converted to spaces.
    local path = LSM and LSM:Fetch("sound", "TwichUI Menu Click")
    if path and type(PlaySoundFile) == "function" then
        PlaySoundFile(path, "Master")
        return
    end
    if type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

local function PlayMenuConfirmSound()
    -- MediaLoader registers sounds with hyphens converted to spaces.
    local path = LSM and LSM:Fetch("sound", "TwichUI Menu Confirm")
    if path and type(PlaySoundFile) == "function" then
        PlaySoundFile(path, "Master")
        return
    end
    if type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

--- Public helper so other modules can play TwichUI UI sounds by name.
--- Normalizes hyphens to spaces to match how MediaLoader registers sounds with LSM.
--- Falls back gracefully if the sound file is not yet registered.
function UI.PlayTwichSound(name)
    -- MediaLoader converts hyphens to spaces when registering; mirror that here.
    local lsmName = name and name:gsub("-", " ") or name
    local path = LSM and LSM:Fetch("sound", lsmName)
    if path and type(PlaySoundFile) == "function" then
        PlaySoundFile(path, "Master")
    end
end

local function EnsureFrameFadeAnimations(frame, fadeInDuration, fadeOutDuration, onHideFinished)
    if not frame or frame.__twichuiFadeAnimationsReady then
        return
    end

    local fadeIn = frame:CreateAnimationGroup()
    local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetOrder(1)
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(fadeInDuration or MENU_FADE_IN_DURATION)
    fadeIn:SetToFinalAlpha(true)

    local fadeOut = frame:CreateAnimationGroup()
    local fadeOutAlpha = fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetOrder(1)
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(fadeOutDuration or MENU_FADE_OUT_DURATION)
    fadeOut:SetToFinalAlpha(true)
    fadeOut:SetScript("OnFinished", function()
        frame:SetAlpha(1)
        if type(onHideFinished) == "function" then
            onHideFinished(frame)
        else
            frame:Hide()
        end
    end)

    frame.__twichuiFadeIn = fadeIn
    frame.__twichuiFadeOut = fadeOut
    frame.__twichuiFadeAnimationsReady = true
end

local function FadeInFrame(frame)
    if not frame then
        return
    end

    EnsureFrameFadeAnimations(frame)
    if frame.__twichuiFadeOut and frame.__twichuiFadeOut:IsPlaying() then
        frame.__twichuiFadeOut:Stop()
    end

    frame:SetAlpha(0)
    frame:Show()

    if frame.__twichuiFadeIn then
        frame.__twichuiFadeIn:Stop()
        frame.__twichuiFadeIn:Play()
    else
        frame:SetAlpha(1)
    end
end

local function FadeOutFrame(frame)
    if not frame or not frame:IsShown() then
        if frame then
            frame:Hide()
        end
        return
    end

    EnsureFrameFadeAnimations(frame)
    if frame.__twichuiFadeIn and frame.__twichuiFadeIn:IsPlaying() then
        frame.__twichuiFadeIn:Stop()
    end

    if frame.__twichuiFadeOut and not frame.__twichuiFadeOut:IsPlaying() then
        frame.__twichuiFadeOut:Play()
        return
    end

    frame:Hide()
end

local function GetSmartTooltipAnchor(owner, tooltip)
    if not owner or not owner.GetLeft or not owner.GetRight or not owner.GetTop or not owner.GetBottom then
        return "TOPLEFT", "BOTTOMLEFT", 0, -TOOLTIP_OFFSET
    end

    local parentWidth = _G.UIParent and _G.UIParent.GetWidth and _G.UIParent:GetWidth() or 1920
    local parentHeight = _G.UIParent and _G.UIParent.GetHeight and _G.UIParent:GetHeight() or 1080
    local left = owner:GetLeft() or 0
    local right = owner:GetRight() or left
    local top = owner:GetTop() or parentHeight
    local bottom = owner:GetBottom() or 0
    local tooltipWidth = tooltip and tooltip.GetWidth and math.max(tooltip:GetWidth() or 0, 240) or 240
    local tooltipHeight = tooltip and tooltip.GetHeight and math.max(tooltip:GetHeight() or 0, 80) or 80
    local leftSpace = left
    local rightSpace = parentWidth - right
    local topSpace = parentHeight - top
    local bottomSpace = bottom
    local openUp = bottomSpace < (tooltipHeight + TOOLTIP_EDGE_PADDING) and topSpace > bottomSpace
    local openLeft = rightSpace < (tooltipWidth + TOOLTIP_EDGE_PADDING) and leftSpace > rightSpace

    if openUp and openLeft then
        return "BOTTOMRIGHT", "TOPRIGHT", 0, TOOLTIP_OFFSET
    end

    if openUp then
        return "BOTTOMLEFT", "TOPLEFT", 0, TOOLTIP_OFFSET
    end

    if openLeft then
        return "TOPRIGHT", "BOTTOMRIGHT", 0, -TOOLTIP_OFFSET
    end

    return "TOPLEFT", "BOTTOMLEFT", 0, -TOOLTIP_OFFSET
end

local function ShowAnchoredTooltip(tooltip, owner)
    if not (tooltip and owner and tooltip.SetOwner and tooltip.SetPoint and tooltip.ClearAllPoints) then
        return
    end

    EnsureFrameFadeAnimations(tooltip, MENU_FADE_IN_DURATION, MENU_FADE_OUT_DURATION)
    if tooltip.__twichuiFadeOut and tooltip.__twichuiFadeOut:IsPlaying() then
        tooltip.__twichuiFadeOut:Stop()
    end

    local point, relativePoint, x, y = GetSmartTooltipAnchor(owner, tooltip)
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint(point, owner, relativePoint, x, y)
    tooltip:SetAlpha(0)
    tooltip:Show()
    if tooltip.__twichuiFadeIn then
        tooltip.__twichuiFadeIn:Stop()
        tooltip.__twichuiFadeIn:Play()
    else
        tooltip:SetAlpha(1)
    end
end

local function HideAnchoredTooltip(tooltip)
    FadeOutFrame(tooltip)
end

local function GetMenuTypography(menu)
    ---@type ConfigurationModule|nil
    local configurationModule = T:GetModule("Configuration", true)
    local options = configurationModule and configurationModule.Options and configurationModule.Options.Datatext or nil
    local style = menu and menu.styleOverride or nil
    if type(style) ~= "table" then
        local db = options and options.GetStandaloneDB and options:GetStandaloneDB() or nil
        style = db and db.style or nil
    end
    local fontName = style and (style.menuFont or style.font) or nil
    local fontPath = STANDARD_TEXT_FONT

    if LSM and type(fontName) == "string" and fontName ~= "" then
        fontPath = LSM:Fetch("font", fontName, true) or STANDARD_TEXT_FONT
    end

    return fontPath,
        math.max(8, math.min(20, tonumber(style and style.menuFontSize) or tonumber(style and style.fontSize) or 12)),
        style and style.fontOutline == true and "OUTLINE" or ""
end

local function CreateRow(menu, index)
    local parent = menu.frame
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    button:SetHeight(20)
    button:SetFrameStrata(parent:GetFrameStrata())
    button:SetFrameLevel(parent:GetFrameLevel() + 1)
    button:SetPoint("LEFT", parent, "LEFT", 4, 0)
    button:SetPoint("RIGHT", parent, "RIGHT", -4, 0)

    if index == 1 then
        button:SetPoint("TOP", parent, "TOP", 0, -4)
    else
        local prev = menu.buttons[index - 1]
        button:SetPoint("TOP", prev, "BOTTOM", 0, -1)
    end

    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
    button:SetAttribute("pressAndHoldAction", true)
    SkinBackdrop(button)

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", button, "LEFT", 6, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)

    local indicator = button:CreateFontString(nil, "OVERLAY")
    indicator:SetPoint("LEFT", button, "LEFT", 6, 0)
    indicator:SetWidth(22)
    indicator:SetJustifyH("CENTER")

    button.__twichuiGlow = button:CreateTexture(nil, "ARTWORK")
    button.__twichuiGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.__twichuiGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.__twichuiGlow:SetColorTexture(0.44, 0.82, 0.98, 0.04)
    button.__twichuiGlow:SetAlpha(0)

    button.__twichuiAccent = button:CreateTexture(nil, "ARTWORK")
    button.__twichuiAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.__twichuiAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    button.__twichuiAccent:SetWidth(2)
    button.__twichuiAccent:SetColorTexture(0.98, 0.76, 0.22, 0.9)
    button.__twichuiAccent:SetAlpha(0)

    button.__twichuiUnderline = button:CreateTexture(nil, "ARTWORK")
    button.__twichuiUnderline:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 6, 0)
    button.__twichuiUnderline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 0)
    button.__twichuiUnderline:SetHeight(1)
    button.__twichuiUnderline:SetColorTexture(0.44, 0.82, 0.98, 0.85)
    button.__twichuiUnderline:SetAlpha(0)

    local fontObj = _G.GameFontHighlightSmall or _G.GameFontNormalSmall or _G.GameFontHighlight
    if fontObj and label.SetFontObject then
        label:SetFontObject(fontObj)
        indicator:SetFontObject(fontObj)
    end

    button.__twichuiLabel = label
    button.__twichuiIndicator = indicator

    button:SetScript("OnEnter", function(self)
        local entry = self.__twichuiEntry
        if entry and not entry.disabled and not entry.isTitle then
            self:SetBackdropBorderColor(0.44, 0.82, 0.98, 1)
            self.__twichuiGlow:SetAlpha(1)
            self.__twichuiAccent:SetAlpha(1)
            self.__twichuiUnderline:SetAlpha(1)
        else
            self:SetBackdropBorderColor(1, 1, 1, 1)
        end
        if entry and entry.tooltip and _G.GameTooltip then
            _G.GameTooltip:ClearLines()
            _G.GameTooltip:AddLine(entry.tooltip, 1, 1, 1, true)
            ShowAnchoredTooltip(_G.GameTooltip, self)
        end
    end)

    button:SetScript("OnLeave", function(self)
        local br, bg, bb = GetBorderAndBackdrop()
        local _, _, _, fr, fg, fb, fa = GetBorderAndBackdrop()
        self:SetBackdropColor(fr, fg, fb, fa)
        self:SetBackdropBorderColor(br, bg, bb, 1)
        self.__twichuiGlow:SetAlpha(0)
        self.__twichuiAccent:SetAlpha(0)
        self.__twichuiUnderline:SetAlpha(0)
        if _G.GameTooltip then
            HideAnchoredTooltip(_G.GameTooltip)
        end
    end)

    button:SetScript("PostClick", function(self)
        local entry = self.__twichuiEntry
        LogSecureMenuDebug("PostClick text=%s type=%s type1=%s macro=%s macro1=%s item=%s item1=%s spell=%s spell1=%s",
            entry and entry.text or "<nil>",
            tostring(self:GetAttribute("type")),
            tostring(self:GetAttribute("type1")),
            tostring(self:GetAttribute("macrotext")),
            tostring(self:GetAttribute("macrotext1")),
            tostring(self:GetAttribute("item")),
            tostring(self:GetAttribute("item1")),
            tostring(self:GetAttribute("spell")),
            tostring(self:GetAttribute("spell1")))

        if entry and type(entry.func) == "function" and not entry.disabled and not entry.isTitle then
            entry.func(self)
        end

        if entry and not entry.disabled and not entry.isTitle then
            PlayMenuClickSound()
        end

        local menuRef = self.__twichuiMenu
        if menuRef and entry and entry.keepShownOnClick and menuRef.RefreshEntries then
            menuRef:RefreshEntries()
            return
        end

        if menuRef and menuRef.Hide then
            menuRef:Hide()
        end
    end)



    menu.buttons[index] = button
    return button
end

---@param key string
---@return TwichUISecureMenu
function UI.CreateSecureMenu(key)
    local frame = CreateFrame("Frame", key, _G.UIParent, "SecureFrameTemplate,BackdropTemplate")
    frame:SetSize(200, 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(300)
    frame:SetClampedToScreen(true)
    frame:Hide()

    SkinBackdrop(frame)
    EnsureFrameFadeAnimations(frame, MENU_FADE_IN_DURATION, MENU_FADE_OUT_DURATION, function(menuFrame)
        menuFrame:Hide()
    end)

    local menu = {
        frame = frame,
        buttons = {},
        entries = {},
    }

    local dismiss = CreateFrame("Button", nil, _G.UIParent, "BackdropTemplate")
    dismiss:SetAllPoints(_G.UIParent)
    dismiss:SetFrameStrata("DIALOG")
    dismiss:SetFrameLevel(299)
    dismiss:RegisterForClicks("AnyUp")
    dismiss:Hide()

    menu.dismiss = dismiss
    dismiss:SetScript("OnClick", function()
        menu:Hide()
    end)

    function menu:ApplyTypography(row)
        if not row then
            return
        end

        local fontPath, fontSize, fontFlags = GetMenuTypography(self)
        local rowHeight = math.max(20, fontSize + 10)
        row:SetHeight(rowHeight)
        if row.__twichuiLabel and row.__twichuiLabel.SetFont then
            row.__twichuiLabel:SetFont(fontPath, fontSize, fontFlags)
        end
        if row.__twichuiIndicator and row.__twichuiIndicator.SetFont then
            row.__twichuiIndicator:SetFont(fontPath, fontSize, fontFlags)
        end
    end

    function menu:GetContentWidth()
        local screenWidth = (_G.UIParent and _G.UIParent.GetWidth and _G.UIParent:GetWidth()) or MENU_MAX_WIDTH
        local maxWidth = MENU_MIN_WIDTH

        for _, row in ipairs(self.buttons) do
            if row:IsShown() and row.__twichuiEntry then
                local entry = row.__twichuiEntry
                local rowWidth = tonumber(entry.width) or 0
                if rowWidth <= 0 then
                    local indicatorWidth = (row.__twichuiIndicator and row.__twichuiIndicator:IsShown()) and 28 or 0
                    local labelWidth = row.__twichuiLabel and row.__twichuiLabel.GetStringWidth and
                        row.__twichuiLabel:GetStringWidth() or 0
                    rowWidth = labelWidth + indicatorWidth + 28
                end

                if rowWidth > maxWidth then
                    maxWidth = rowWidth
                end
            end
        end

        return math.max(MENU_MIN_WIDTH, math.min(MENU_MAX_WIDTH, screenWidth - (MENU_EDGE_PADDING * 2), maxWidth))
    end

    ---@param entries TwichUISecureMenuEntry[]
    function menu:SetEntries(entries)
        self.entries = entries or {}

        local visible = 0
        for i = 1, #self.entries do
            local entry = self.entries[i]
            if entry and type(entry.text) == "string" and entry.text ~= "" then
                visible = visible + 1
                local row = self.buttons[visible] or CreateRow(self, visible)
                row.__twichuiEntry = entry
                row.__twichuiMenu = self
                self:ApplyTypography(row)

                row.__twichuiLabel:SetText(entry.text)
                row.__twichuiIndicator:SetShown(not entry.isTitle and not entry.notCheckable)
                row.__twichuiIndicator:SetText(entry.checked and "[x]" or "[ ]")
                row.__twichuiIndicator:SetTextColor(entry.checked and 0.42 or 0.7, entry.checked and 0.9 or 0.72,
                    entry.checked and 0.62 or 0.74)

                row.__twichuiLabel:ClearAllPoints()
                if entry.isTitle then
                    row.__twichuiLabel:SetPoint("LEFT", row, "LEFT", 6, 0)
                    row.__twichuiLabel:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    row.__twichuiLabel:SetJustifyH("CENTER")
                elseif entry.notCheckable then
                    row.__twichuiLabel:SetPoint("LEFT", row, "LEFT", 6, 0)
                    row.__twichuiLabel:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    row.__twichuiLabel:SetJustifyH("LEFT")
                else
                    row.__twichuiLabel:SetPoint("LEFT", row.__twichuiIndicator, "RIGHT", 4, 0)
                    row.__twichuiLabel:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                    row.__twichuiLabel:SetJustifyH("LEFT")
                end

                -- Clear previous attributes
                row:SetAttribute("type", nil)
                row:SetAttribute("type1", nil)
                row:SetAttribute("item", nil)
                row:SetAttribute("item1", nil)
                row:SetAttribute("spell", nil)
                row:SetAttribute("spell1", nil)
                row:SetAttribute("macrotext", nil)
                row:SetAttribute("macrotext1", nil)

                -- Set secure attributes based on entry type
                if entry.item then
                    row:SetAttribute("type", "item")
                    row:SetAttribute("type1", "item")
                    row:SetAttribute("item", entry.item)
                    row:SetAttribute("item1", entry.item)
                elseif entry.spell then
                    row:SetAttribute("type", "spell")
                    row:SetAttribute("type1", "spell")
                    row:SetAttribute("spell", entry.spell)
                    row:SetAttribute("spell1", entry.spell)
                elseif entry.macrotext then
                    row:SetAttribute("type", "macro")
                    row:SetAttribute("type1", "macro")
                    row:SetAttribute("macrotext", entry.macrotext)
                    row:SetAttribute("macrotext1", entry.macrotext)
                end

                LogSecureMenuDebug("Bind entry text=%s type=%s macro=%s item=%s spell=%s disabled=%s",
                    tostring(entry.text),
                    tostring(row:GetAttribute("type1") or row:GetAttribute("type")),
                    tostring(row:GetAttribute("macrotext1") or row:GetAttribute("macrotext")),
                    tostring(row:GetAttribute("item1") or row:GetAttribute("item")),
                    tostring(row:GetAttribute("spell1") or row:GetAttribute("spell")),
                    tostring(entry.disabled == true))

                if entry.isTitle then
                    local br, bg, bb, fr, fg, fb, fa = GetBorderAndBackdrop()
                    row:SetBackdropColor(fr, fg, fb, fa)
                    row:SetBackdropBorderColor(br, bg, bb, 1)
                    row:EnableMouse(false)
                    row:SetAlpha(0.95)
                    row.__twichuiGlow:SetAlpha(0)
                    row.__twichuiAccent:SetAlpha(0)
                    row.__twichuiUnderline:SetAlpha(0)
                    row.__twichuiLabel:SetTextColor(0.98, 0.82, 0.42)
                elseif entry.disabled then
                    local br, bg, bb, fr, fg, fb, fa = GetBorderAndBackdrop()
                    row:SetBackdropColor(fr, fg, fb, fa)
                    row:SetBackdropBorderColor(br, bg, bb, 1)
                    row:EnableMouse(false)
                    row:SetAlpha(0.5)
                    row.__twichuiLabel:SetTextColor(0.6, 0.64, 0.7)
                else
                    local br, bg, bb, fr, fg, fb, fa = GetBorderAndBackdrop()
                    row:SetBackdropColor(fr, fg, fb, fa)
                    row:SetBackdropBorderColor(br, bg, bb, 1)
                    row:EnableMouse(true)
                    row:SetAlpha(1.0)
                    row.__twichuiLabel:SetTextColor(0.96, 0.96, 0.98)
                end

                row:Show()
            end
        end

        for i = visible + 1, #self.buttons do
            self.buttons[i]:Hide()
            self.buttons[i].__twichuiEntry = nil
        end

        if visible == 0 then
            frame:SetHeight(10)
            return
        end

        -- Use a formula-based calculation for now; height will be recalculated in Toggle()
        -- after the frame is positioned and button layouts are finalized
        frame:SetHeight(10 + visible * 22)
    end

    function menu:Hide()
        if self.dismiss and self.dismiss.Hide then
            self.dismiss:Hide()
        end

        FadeOutFrame(self.frame)
    end

    local function RecalculateFrameLayout(self)
        local visible = 0
        for i = 1, #self.buttons do
            if self.buttons[i]:IsVisible() then
                visible = visible + 1
            end
        end

        if visible == 0 then
            self.frame:SetWidth(MENU_MIN_WIDTH)
            self.frame:SetHeight(10)
            return
        end

        self.frame:SetWidth(self:GetContentWidth())

        local first = self.buttons[1]
        local last = self.buttons[visible]
        if first and last and first:IsVisible() and last:IsVisible() and first.GetTop and last.GetBottom then
            local top = first:GetTop()
            local bottom = last:GetBottom()
            if top and bottom then
                local h = (top - bottom) + 8
                if h < 10 then h = 10 end
                self.frame:SetHeight(h)
                return
            end
        end

        -- Fallback to formula if GetTop/GetBottom are not available
        self.frame:SetHeight(10 + visible * 22)
    end

    local function GetSmartAnchor(anchor, menuWidth, menuHeight)
        if not anchor or not anchor.GetLeft or not anchor.GetRight or not anchor.GetTop or not anchor.GetBottom then
            return "TOPLEFT", "BOTTOMLEFT", 0, -4
        end

        local parent = _G.UIParent
        local parentWidth = parent and parent.GetWidth and parent:GetWidth() or 1920
        local parentHeight = parent and parent.GetHeight and parent:GetHeight() or 1080
        local left = anchor:GetLeft() or 0
        local right = anchor:GetRight() or left
        local top = anchor:GetTop() or parentHeight
        local bottom = anchor:GetBottom() or 0
        local leftSpace = left
        local rightSpace = parentWidth - right
        local topSpace = parentHeight - top
        local bottomSpace = bottom

        local openUp = bottomSpace < (menuHeight + MENU_EDGE_PADDING) and topSpace > bottomSpace
        local openLeft = rightSpace < (menuWidth + MENU_EDGE_PADDING) and leftSpace > rightSpace

        if openUp and openLeft then
            return "BOTTOMRIGHT", "TOPRIGHT", 0, 4
        end

        if openUp then
            return "BOTTOMLEFT", "TOPLEFT", 0, 4
        end

        if openLeft then
            return "TOPRIGHT", "BOTTOMRIGHT", 0, -4
        end

        return "TOPLEFT", "BOTTOMLEFT", 0, -4
    end

    ---@param anchor Frame
    ---@param point string|nil
    ---@param relativePoint string|nil
    ---@param x number|nil
    ---@param y number|nil
    function menu:Toggle(anchor, point, relativePoint, x, y)
        if self.frame:IsShown() then
            self:Hide()
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            return
        end

        RecalculateFrameLayout(self)

        point = point or "TOPLEFT"
        relativePoint = relativePoint or "BOTTOMLEFT"
        x = tonumber(x) or 0
        y = tonumber(y) or -4

        if anchor then
            point, relativePoint, x, y = GetSmartAnchor(anchor, self.frame:GetWidth() or MENU_MIN_WIDTH,
                self.frame:GetHeight() or 10)
        end

        if anchor and anchor.GetCenter then
            self.frame:ClearAllPoints()
            self.frame:SetPoint(point, anchor, relativePoint, x, y)
        else
            self.frame:ClearAllPoints()
            self.frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
        end

        if self.dismiss and self.dismiss.Show then
            self.dismiss:Show()
        end

        FadeInFrame(self.frame)

        RecalculateFrameLayout(self)
    end

    return menu
end

-- Blizzard UIDropDownMenu-based secure menu for datatexts
local function ShowSecureDropdown(entries, anchor)
    if not entries or #entries == 0 then return end
    if not TwichUI_SecureDropdown then
        CreateFrame("Frame", "TwichUI_SecureDropdown", UIParent, "UIDropDownMenuTemplate")
    end
    local dropdown = TwichUI_SecureDropdown
    local function OnClick(self, arg1, arg2, checked)
        if arg1 and arg1.type == "item" and arg1.item then
            UseItemByName(arg1.item)
        elseif arg1 and arg1.type == "spell" and arg1.spell then
            CastSpellByID(arg1.spell)
        elseif arg1 and arg1.type == "macro" and arg1.macrotext then
            RunMacroText(arg1.macrotext)
        elseif arg1 and type(arg1.func) == "function" then
            arg1.func(self)
        end

        PlayMenuClickSound()
    end
    local menu = {}
    for _, entry in ipairs(entries) do
        local info = {}
        info.text = entry.text
        info.notCheckable = entry.notCheckable == true or entry.isTitle == true
        info.checked = entry.checked == true
        info.isNotRadio = entry.isNotRadio == true
        info.keepShownOnClick = entry.keepShownOnClick == true
        info.disabled = entry.disabled == true
        info.func = OnClick
        info.arg1 = entry
        table.insert(menu, info)
    end
    -- Ensure Blizzard's UIDropDownMenu is loaded (modern WoW API)
    if not _G.EasyMenu then
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_UIDropDownMenu")
        if not loaded and C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_UIDropDownMenu")
        end
    end
    if _G.EasyMenu then
        _G.EasyMenu(menu, dropdown, anchor or UIParent, 0, 0, "MENU")
    elseif _G.MenuUtil and _G.MenuUtil.CreateContextMenu then
        -- Dragonflight+ / WoW 10.0+ fallback: use the new context-menu API.
        _G.MenuUtil.CreateContextMenu(anchor or UIParent, function(_, rootDescription)
            for _, entry in ipairs(entries) do
                local e = entry
                if e.isTitle then
                    rootDescription:CreateTitle(e.text or "")
                elseif e.disabled then
                    local btn = rootDescription:CreateButton(e.text or "")
                    if btn and btn.SetEnabled then btn:SetEnabled(false) end
                else
                    rootDescription:CreateButton(e.text or "", function()
                        if type(e.func) == "function" then
                            e.func()
                        end
                        PlayMenuClickSound()
                    end)
                end
            end
        end)
    end
end
UI.ShowSecureDropdown = ShowSecureDropdown
