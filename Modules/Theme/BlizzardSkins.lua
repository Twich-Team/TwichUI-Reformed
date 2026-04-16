---@diagnostic disable: undefined-field, need-check-nil
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ThemeModule
local Theme = T:GetModule("Theme")

---@class BlizzardSkinsModule : AceModule, AceEvent-3.0
local BlizzardSkins = Theme:NewModule("BlizzardSkins", "AceEvent-3.0")
BlizzardSkins:SetEnabledState(true)

local C_AddOns = _G.C_AddOns
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetInventoryItemLink = _G.GetInventoryItemLink
local GetInventoryItemTexture = _G.GetInventoryItemTexture
local GetItemInfo = _G.C_Item and _G.C_Item.GetItemInfo
local GetDetailedItemLevelInfo = _G.C_Item and _G.C_Item.GetDetailedItemLevelInfo
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS
local hooksecurefunc = _G.hooksecurefunc
local next = next
local pairs = pairs
local ipairs = ipairs
local max = math.max
local min = math.min
local unpackValues = table.unpack or unpack
local strmatch = string.match
local gsub = string.gsub
local format = string.format

local SLOT_NAMES = {
    "CharacterHeadSlot",
    "CharacterNeckSlot",
    "CharacterShoulderSlot",
    "CharacterBackSlot",
    "CharacterChestSlot",
    "CharacterShirtSlot",
    "CharacterTabardSlot",
    "CharacterWristSlot",
    "CharacterHandsSlot",
    "CharacterWaistSlot",
    "CharacterLegsSlot",
    "CharacterFeetSlot",
    "CharacterFinger0Slot",
    "CharacterFinger1Slot",
    "CharacterTrinket0Slot",
    "CharacterTrinket1Slot",
    "CharacterMainHandSlot",
    "CharacterSecondaryHandSlot",
}

local function HideTexture(texture)
    if not texture then
        return
    end

    if texture.SetTexture then
        texture:SetTexture(nil)
    end
    if texture.SetAtlas then
        texture:SetAtlas(nil)
    end
    if texture.SetAlpha then
        texture:SetAlpha(0)
    end
    if texture.Hide then
        texture:Hide()
    end
end

local function HideTextureRegions(frame)
    if not frame or not frame.GetRegions then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            HideTexture(region)
        end
    end
end

local function EnsureLayer(parent, key, frameLevelOffset)
    if not parent then
        return nil
    end

    if parent[key] then
        return parent[key]
    end

    local frameParent = parent
    if not frameParent.GetFrameLevel then
        frameParent = parent.GetParent and parent:GetParent() or _G.UIParent
    end

    if not frameParent or not frameParent.GetFrameLevel then
        frameParent = _G.UIParent
    end

    local layer = CreateFrame("Frame", nil, frameParent, "BackdropTemplate")
    layer:SetFrameLevel(max(0, frameParent:GetFrameLevel() + (frameLevelOffset or -1)))
    parent[key] = layer
    return layer
end

local function EnsureTexture(parent, key, drawLayer)
    if parent[key] then
        return parent[key]
    end

    local texture = parent:CreateTexture(nil, drawLayer or "ARTWORK")
    parent[key] = texture
    return texture
end

local function GetPalette()
    local primary = Theme:GetColor("primaryColor")
    local accent = Theme:GetColor("accentColor")
    local background = Theme:GetColor("backgroundColor")
    local border = Theme:GetColor("borderColor")
    local text = Theme:GetColor("textColor")
    local danger = Theme:GetColor("dangerColor")
    local backgroundAlpha = Theme:Get("backgroundAlpha") or 0.94
    local borderAlpha = Theme:Get("borderAlpha") or 0.85
    return primary, accent, background, border, text, danger, backgroundAlpha, borderAlpha
end

local function ApplySurfaceChrome(frame, accent, background, border, backgroundAlpha, borderAlpha, style)
    if not frame or not frame.SetBackdrop then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local bgMul = style and style.bgMul or 1
    frame:SetBackdropColor(
        min(1, (background[1] or 0.05) * bgMul),
        min(1, (background[2] or 0.06) * bgMul),
        min(1, (background[3] or 0.08) * bgMul),
        style and style.alpha or backgroundAlpha)
    frame:SetBackdropBorderColor(border[1] or 0.24, border[2] or 0.26, border[3] or 0.32, borderAlpha)

    local edge = EnsureTexture(frame, "__twichEdgeAccent", "BORDER")
    edge:ClearAllPoints()
    if style and style.edge == "top" then
        edge:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        edge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        edge:SetHeight(style.edgeSize or 3)
    else
        edge:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        edge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        edge:SetWidth(style and style.edgeSize or 3)
    end
    edge:SetColorTexture(accent[1] or 1, accent[2] or 1, accent[3] or 1, style and style.edgeAlpha or 0.95)

    local glow = EnsureTexture(frame, "__twichInnerGlow", "ARTWORK")
    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(accent[1] or 1, accent[2] or 1, accent[3] or 1, style and style.glowAlpha or 0.08)
end

local function SkinIconButton(button, accent, background, border, backgroundAlpha, borderAlpha, glyph, glyphColor)
    if not button then
        return
    end

    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    HideTextureRegions(button)

    local chrome = EnsureLayer(button, "__twichIconChrome", -1)
    chrome:SetAllPoints(button)
    button.__twichAccentColor = accent
    button.__twichBackgroundColor = background
    button.__twichBorderColor = border
    button.__twichBackgroundAlpha = backgroundAlpha
    button.__twichBorderAlpha = borderAlpha
    ApplySurfaceChrome(chrome, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 3,
        glowAlpha = 0.10,
    })

    if not button.__twichGlyphText then
        button.__twichGlyphText = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.__twichGlyphText:SetPoint("CENTER", button, "CENTER", 0, 0)
    end
    button.__twichGlyphText:SetText(glyph or "")
    local gc = glyphColor or accent
    button.__twichGlyphText:SetTextColor(gc[1] or 1, gc[2] or 1, gc[3] or 1)

    if not button.__twichHooksInstalled then
        button:HookScript("OnMouseDown", function(self)
            if self.__twichIconChrome then
                local bg = self.__twichBackgroundColor or { 0.05, 0.06, 0.08 }
                self.__twichIconChrome:SetBackdropColor((bg[1] or 0.05) * 1.7, (bg[2] or 0.06) * 1.7,
                    (bg[3] or 0.08) * 1.7, 1)
            end
        end)
        button:HookScript("OnMouseUp", function(self)
            if self.__twichIconChrome then
                ApplySurfaceChrome(self.__twichIconChrome, self.__twichAccentColor or accent,
                    self.__twichBackgroundColor or background, self.__twichBorderColor or border,
                    self.__twichBackgroundAlpha or backgroundAlpha, self.__twichBorderAlpha or borderAlpha, {
                        edge = "left",
                        edgeSize = 3,
                        glowAlpha = 0.10,
                    })
            end
        end)
        button.__twichHooksInstalled = true
    end
end

local function CropIcon(icon)
    if not icon then
        return
    end

    if icon.SetTexCoord then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function HideFontString(fontString)
    if not fontString then
        return
    end

    fontString:SetText("")
    fontString:Hide()
end

local function GetUI()
    return T and T.Tools and T.Tools.UI or nil
end

local function SetFontColor(fontString, color, alpha)
    if fontString and fontString.SetTextColor then
        fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, alpha or 1)
    end
end

local function StyleOuterBorder(frame, key, accent, background, border, backgroundAlpha, borderAlpha, offsets)
    if not frame then
        return nil
    end

    local borderFrame = EnsureLayer(frame, key, -3)
    local left = offsets and offsets.left or 0
    local right = offsets and offsets.right or 0
    local top = offsets and offsets.top or 0
    local bottom = offsets and offsets.bottom or 0

    borderFrame:ClearAllPoints()
    borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
    borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", right, bottom)
    ApplySurfaceChrome(borderFrame, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 2,
        alpha = 0.18,
        edgeAlpha = 0.9,
        glowAlpha = 0.02,
        bgMul = 0.9,
    })

    borderFrame:SetBackdropColor(background[1] or 0.05, background[2] or 0.06, background[3] or 0.08, 0.12)
    borderFrame:SetBackdropBorderColor(border[1] or 0.24, border[2] or 0.26, border[3] or 0.32,
        min(1, (borderAlpha or 0.85) + 0.08))
    return borderFrame
end

local function StyleTextButton(button, color)
    local UI = GetUI()
    if UI and UI.SkinTwichButton and button then
        UI.SkinTwichButton(button, color)
    end
end

local function StyleEditBox(editBox)
    if not editBox then
        return
    end

    local _, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(editBox)
    HideTexture(editBox.Left)
    HideTexture(editBox.Middle)
    HideTexture(editBox.Right)
    HideTexture(editBox.TopLeft)
    HideTexture(editBox.TopRight)
    HideTexture(editBox.TopMiddle)
    HideTexture(editBox.BottomLeft)
    HideTexture(editBox.BottomRight)
    HideTexture(editBox.BottomMiddle)
    HideTexture(editBox.BgLeft)
    HideTexture(editBox.BgMid)
    HideTexture(editBox.BgRight)

    local chrome = EnsureLayer(editBox, "__twichEditChrome", -1)
    chrome:SetPoint("TOPLEFT", editBox, "TOPLEFT", -2, 2)
    chrome:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 2, -2)
    ApplySurfaceChrome(chrome, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.96,
        glowAlpha = 0.04,
    })

    if editBox.SetTextInsets then
        editBox:SetTextInsets(8, 8, 0, 0)
    end

    SetFontColor(editBox.Instructions, { 0.74, 0.76, 0.82 }, 0.9)
    SetFontColor(editBox.Label, text)
    if editBox.SearchIcon then
        editBox.SearchIcon:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1, 0.9)
    end
end

local function StyleCheckButton(checkButton)
    if not checkButton then
        return
    end

    local primary, accent, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(checkButton)

    local chrome = EnsureLayer(checkButton, "__twichCheckChrome", -1)
    chrome:SetPoint("TOPLEFT", checkButton, "TOPLEFT", 4, -4)
    chrome:SetPoint("BOTTOMRIGHT", checkButton, "BOTTOMRIGHT", -4, 4)

    local checkedTexture = checkButton:GetCheckedTexture()
    if not checkedTexture then
        checkedTexture = EnsureTexture(checkButton, "__twichCheckedTexture", "OVERLAY")
        checkedTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
        checkButton:SetCheckedTexture(checkedTexture)
    end

    local function UpdateCheckVisual()
        local enabled = checkButton.IsEnabled == nil or checkButton:IsEnabled()
        local checked = checkButton.GetChecked and checkButton:GetChecked() == true
        local edgeColor = checked and accent or border
        ApplySurfaceChrome(chrome, edgeColor, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = enabled and 0.94 or 0.72,
            edgeAlpha = checked and 0.95 or 0.22,
            glowAlpha = checked and 0.08 or 0.01,
        })

        checkedTexture:ClearAllPoints()
        checkedTexture:SetPoint("TOPLEFT", chrome, "TOPLEFT", 4, -4)
        checkedTexture:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -4, 4)
        checkedTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
        if checked then
            checkedTexture:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1, enabled and 0.95 or 0.55)
            checkedTexture:Show()
        else
            checkedTexture:Hide()
        end
    end

    if not checkButton.__twichCheckHooked then
        checkButton:HookScript("OnClick", UpdateCheckVisual)
        checkButton:HookScript("OnShow", UpdateCheckVisual)
        checkButton:HookScript("OnEnable", UpdateCheckVisual)
        checkButton:HookScript("OnDisable", UpdateCheckVisual)
        checkButton.__twichCheckHooked = true
    end

    UpdateCheckVisual()
    SetFontColor(checkButton.Text, primary)
end

local function StyleSlider(slider)
    if not slider then
        return
    end

    local _, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(slider)
    local trackShell = EnsureLayer(slider, "__twichSliderTrackShell", -1)
    trackShell:SetPoint("LEFT", slider, "LEFT", 0, 0)
    trackShell:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    trackShell:SetPoint("CENTER", slider, "CENTER", 0, 0)
    trackShell:SetHeight(8)
    ApplySurfaceChrome(trackShell, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.96,
        glowAlpha = 0.03,
    })

    local fill = EnsureTexture(trackShell, "__twichSliderFill", "ARTWORK")
    fill:SetPoint("TOPLEFT", trackShell, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", trackShell, "BOTTOMLEFT", 1, 1)
    fill:SetColorTexture(accent[1] or 1, accent[2] or 1, accent[3] or 1, 0.92)

    if slider.SetThumbTexture then
        slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    end

    local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(10, 18)
        thumb:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1, 0.98)
    end

    local function UpdateSliderVisual(_, value)
        local minValue, maxValue = slider:GetMinMaxValues()
        local span = max(0.0001, (maxValue or 1) - (minValue or 0))
        local ratio = ((value or slider:GetValue()) - (minValue or 0)) / span
        ratio = min(1, max(0, ratio))

        local width = max(2, (trackShell:GetWidth() or 0) - 2)
        fill:SetWidth(max(2, width * ratio))

        if thumb then
            thumb:ClearAllPoints()
            thumb:SetPoint("CENTER", trackShell, "LEFT", 1 + (width * ratio), 0)
        end
    end

    if not slider.__twichSliderHooked then
        slider:HookScript("OnValueChanged", UpdateSliderVisual)
        slider:HookScript("OnShow", UpdateSliderVisual)
        slider:HookScript("OnSizeChanged", UpdateSliderVisual)
        slider.__twichSliderHooked = true
    end

    UpdateSliderVisual(slider, slider.GetValue and slider:GetValue() or 0)
    SetFontColor(slider.Text, text)
    SetFontColor(slider.Low, border)
    SetFontColor(slider.High, border)
end

local function StyleSliderWithSteppers(frame)
    if not frame then
        return
    end

    local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    StyleSlider(frame.Slider or frame)

    if frame.DecrementButton then
        SkinIconButton(frame.DecrementButton, primary, background, border, backgroundAlpha, borderAlpha, "<")
    end

    if frame.IncrementButton then
        SkinIconButton(frame.IncrementButton, primary, background, border, backgroundAlpha, borderAlpha, ">")
    end

    if frame.InputBox then
        StyleEditBox(frame.InputBox)
    end

    if frame.EditBox then
        StyleEditBox(frame.EditBox)
    end
end

local function StyleSteppedDropdown(option)
    if not option then
        return
    end

    local primary, accent, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    local targetButton = option.Button or option.Dropdown

    if targetButton then
        StyleTextButton(targetButton, accent)
    end

    if option.DecrementButton then
        SkinIconButton(option.DecrementButton, primary, background, border, backgroundAlpha, borderAlpha, "<")
    end

    if option.IncrementButton then
        SkinIconButton(option.IncrementButton, primary, background, border, backgroundAlpha, borderAlpha, ">")
    end
end

local function StyleSettingsSubTab(tab)
    if not tab then
        return
    end

    local primary, _, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(tab)
    local chrome = EnsureLayer(tab, "__twichSettingsTabChrome", -1)
    chrome:SetAllPoints(tab)
    ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 2,
        alpha = 0.92,
        glowAlpha = 0.04,
    })
    SetFontColor(tab.Text, text)
end

function BlizzardSkins:SuppressElvUICharacterInfo()
    local characterFrame = _G.CharacterFrame
    if characterFrame and characterFrame.ItemLevelText then
        HideFontString(characterFrame.ItemLevelText)
    end

    if _G.CharacterStatsPane and _G.CharacterStatsPane.ItemLevelFrame and _G.CharacterStatsPane.ItemLevelFrame.Value then
        _G.CharacterStatsPane.ItemLevelFrame.Value:Show()
    end

    for _, slotName in ipairs(SLOT_NAMES) do
        local slot = _G[slotName]
        if slot then
            HideFontString(slot.enchantText)
            HideFontString(slot.iLvlText)
        end
    end
end

function BlizzardSkins:StyleStatCategory(frame, noAccent)
    if not frame then
        return
    end

    local primary, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(frame)
    if frame.Background then
        HideTexture(frame.Background)
    end

    local edgeColor = noAccent and border or accent
    local chrome = EnsureLayer(frame, "__twichCategoryChrome", -1)
    chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 0)
    ApplySurfaceChrome(chrome, edgeColor, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = noAccent and 1 or 2,
        edgeAlpha = noAccent and 0.35 or 0.95,
        alpha = 0.84,
        glowAlpha = noAccent and 0.0 or 0.03,
    })

    if frame.Name and frame.Name.SetTextColor then
        frame.Name:SetTextColor(text[1] or 1, text[2] or 1, text[3] or 1)
    end

    if frame.Value and frame.Value.SetTextColor then
        local valueColor = noAccent and { text[1] or 1, text[2] or 1, text[3] or 1 } or
        { accent[1] or 1, accent[2] or 1, accent[3] or 1 }
        frame.Value:SetTextColor(unpackValues(valueColor))
    end

    if frame.Label and frame.Label.SetTextColor then
        frame.Label:SetTextColor(primary[1] or 1, primary[2] or 1, primary[3] or 1)
    end
end

function BlizzardSkins:StyleStatCategories()
    -- no accent on the item level display
    self:StyleStatCategory(_G.CharacterStatsPane and _G.CharacterStatsPane.ItemLevelFrame, true)

    local categoryNames = {
        "ItemLevelCategory",
        "AttributesCategory",
        "EnhancementsCategory",
    }

    for _, categoryName in ipairs(categoryNames) do
        self:StyleStatCategory(_G.CharacterStatsPane and _G.CharacterStatsPane[categoryName])
    end

    if _G.CharacterStatsPane and _G.CharacterStatsPane.statsFramePool then
        for statFrame in _G.CharacterStatsPane.statsFramePool:EnumerateActive() do
            if statFrame.Label then
                statFrame.Label:SetTextColor(0.96, 0.76, 0.24)
            end
            if statFrame.Value then
                statFrame.Value:SetTextColor(1, 0.95, 0.85)
            end
            if statFrame.Background then
                statFrame.Background:SetAlpha(0)
            end
        end
    end
end

local function SkinFilterDropdown(dd)
    if not dd then return end
    local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(dd)
    local chrome = EnsureLayer(dd, "__twichFilterDropChrome", -1)
    chrome:SetPoint("TOPLEFT", dd, "TOPLEFT", 0, 0)
    chrome:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", 0, 0)
    ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.96,
        glowAlpha = 0.04,
    })
    -- Reset-button chrome if present
    if dd.ResetButton and T.Tools and T.Tools.UI and T.Tools.UI.SkinCloseButton then
        T.Tools.UI.SkinCloseButton(dd.ResetButton)
    end
end

-- Apply our chrome to the global Blizzard DropDownList popup backdrops.
-- Hooked once globally; affects all legacy dropdown popups which is consistent.
local function HookDropDownListBackdrop()
    local maxLevels = max(2, _G.UIDROPDOWNMENU_MAXLEVELS or 2)
    for i = 1, maxLevels do
        local backdrop = _G["DropDownList" .. i .. "Backdrop"]
        if backdrop and not backdrop.__twichDropChromed then
            local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
            HideTextureRegions(backdrop)
            local chrome = EnsureLayer(backdrop, "__twichDropListChrome", -1)
            chrome:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
            chrome:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
            ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
                edge = "left", edgeSize = 2, alpha = 0.97, glowAlpha = 0.05,
            })
            backdrop:HookScript("OnShow", function(self)
                local _, _, bg, bo, _, _, bgA, bA = GetPalette()
                if self.__twichDropListChrome then
                    self.__twichDropListChrome:SetBackdropColor(
                        (bg[1] or 0.05), (bg[2] or 0.06), (bg[3] or 0.08), bgA)
                    self.__twichDropListChrome:SetBackdropBorderColor(
                        bo[1] or 0.24, bo[2] or 0.26, bo[3] or 0.32, bA)
                end
            end)
            backdrop.__twichDropChromed = true
        end
        local menuBackdrop = _G["DropDownList" .. i .. "MenuBackdrop"]
        if menuBackdrop and not menuBackdrop.__twichDropChromed then
            local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
            HideTextureRegions(menuBackdrop)
            local chrome = EnsureLayer(menuBackdrop, "__twichDropListMenuChrome", -1)
            chrome:SetPoint("TOPLEFT", menuBackdrop, "TOPLEFT", 0, 0)
            chrome:SetPoint("BOTTOMRIGHT", menuBackdrop, "BOTTOMRIGHT", 0, 0)
            ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
                edge = "left", edgeSize = 2, alpha = 0.97, glowAlpha = 0.05,
            })
            menuBackdrop.__twichDropChromed = true
        end
    end
end

local function StyleDropDownListButton(level, index)
    local listName = "DropDownList" .. level
    local button = _G[listName .. "Button" .. index]
    if not button then
        return
    end

    local primary, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()
    local buttonName = button:GetName()
    local normalText = buttonName and _G[buttonName .. "NormalText"] or nil
    local highlight = buttonName and _G[buttonName .. "Highlight"] or nil
    local check = buttonName and _G[buttonName .. "Check"] or nil
    local uncheck = buttonName and _G[buttonName .. "UnCheck"] or nil
    local icon = buttonName and _G[buttonName .. "Icon"] or nil
    local expandArrow = buttonName and _G[buttonName .. "ExpandArrow"] or nil

    if not button.__twichContextRow then
        local row = CreateFrame("Frame", nil, button, "BackdropTemplate")
        row:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -1)
        row:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 1)
        row:EnableMouse(false)
        button.__twichContextRow = row
    end

    local row = button.__twichContextRow
    row:SetFrameLevel(max(0, button:GetFrameLevel() - 1))

    local isTitle = button.isTitle == true
    local isDisabled = button:IsEnabled() == false or button.disabled == true
    local isSeparator = icon and icon.GetTexture and tostring(icon:GetTexture() or ""):find("Divider") ~= nil
    local isCheckable = button.notCheckable ~= true and not isTitle and not isSeparator

    if isSeparator then
        row:Hide()
        if icon then
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", button, "LEFT", 10, 0)
            icon:SetPoint("RIGHT", button, "RIGHT", -10, 0)
            icon:SetHeight(1)
            if icon.SetTexture then
                icon:SetTexture("Interface\\Buttons\\WHITE8X8")
            end
            if icon.SetVertexColor then
                icon:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1)
            end
            if icon.SetAlpha then
                icon:SetAlpha(0.35)
            end
            icon:Show()
        end
    else
        row:Show()
        ApplySurfaceChrome(row, isTitle and accent or primary, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = isDisabled and 0.72 or (isTitle and 0.90 or 0.84),
            edgeAlpha = isTitle and 0.90 or 0.22,
            glowAlpha = isTitle and 0.05 or 0.02,
        })
    end

    if highlight then
        highlight:ClearAllPoints()
        highlight:SetAllPoints(row)
        highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
        highlight:SetBlendMode("BLEND")
        highlight:SetVertexColor(primary[1] or 1, primary[2] or 1, primary[3] or 1, 0.16)
    end

    if normalText and normalText.SetTextColor then
        if isTitle then
            normalText:SetTextColor(accent[1] or 1, accent[2] or 1, accent[3] or 1)
        elseif isDisabled then
            normalText:SetTextColor(border[1] or 0.24, border[2] or 0.26, border[3] or 0.32)
        else
            normalText:SetTextColor(text[1] or 1, text[2] or 1, text[3] or 1)
        end
    end

    if uncheck then
        HideTexture(uncheck)
    end

    if check then
        if isCheckable then
            check:ClearAllPoints()
            check:SetPoint("LEFT", row, "LEFT", 6, 0)
            check:SetSize(8, 8)
            if check.SetTexture then
                check:SetTexture("Interface\\Buttons\\WHITE8X8")
            end
            if check.SetVertexColor then
                check:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1)
            end
            check:SetAlpha(button.checked and 1 or 0)
        else
            check:SetAlpha(0)
        end
    end

    if expandArrow and expandArrow.SetVertexColor then
        expandArrow:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1, isDisabled and 0.4 or 0.95)
        expandArrow:SetAlpha(1)
    end

    if icon and not isSeparator then
        icon:SetAlpha(isDisabled and 0.45 or 1)
    end
end

local function StyleDropDownListLevel(level)
    if not level then
        return
    end

    local listFrame = _G["DropDownList" .. level]
    if not listFrame then
        return
    end

    HookDropDownListBackdrop()

    local maxButtons = _G.UIDROPDOWNMENU_MAXBUTTONS or 32
    for index = 1, maxButtons do
        StyleDropDownListButton(level, index)
    end
end

local function HookDropDownListMenus()
    if BlizzardSkins.__twichDropDownMenuHooksInstalled then
        return
    end

    if hooksecurefunc then
        hooksecurefunc("ToggleDropDownMenu", function(level)
            local targetLevel = tonumber(level) or 1
            C_Timer.After(0, function()
                StyleDropDownListLevel(targetLevel)
                StyleDropDownListLevel(targetLevel + 1)
            end)
        end)

        if _G.UIDropDownMenu_CreateFrames then
            hooksecurefunc("UIDropDownMenu_CreateFrames", function(level)
                StyleDropDownListLevel(tonumber(level) or 1)
            end)
        end
    end

    BlizzardSkins.__twichDropDownMenuHooksInstalled = true
end

local function StyleModernMenuFrame(frame)
    if not frame then
        return
    end

    local primary, accent, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()

    HideTextureRegions(frame)
    if frame.NineSlice and frame.NineSlice.SetAlpha then
        frame.NineSlice:SetAlpha(0)
    end
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local chrome = EnsureLayer(frame, "__twichModernMenuChrome", -1)
    chrome:ClearAllPoints()
    chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    ApplySurfaceChrome(chrome, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.97,
        glowAlpha = 0.05,
    })

    if frame.ScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(frame.ScrollBar, primary, true)
    end
end

local function HookModernContextMenus()
    if BlizzardSkins.__twichModernContextHooksInstalled then
        return
    end

    local menuAPI = _G.Menu
    local manager = menuAPI and menuAPI.GetManager and menuAPI.GetManager()
    if not manager or not hooksecurefunc then
        return
    end

    local function SkinManagedMenu(self, ownerRegion, menuDescription, anchor)
        local menu = self.GetOpenMenu and self:GetOpenMenu() or nil
        if menu then
            StyleModernMenuFrame(menu)
        end

        if menuDescription and menuDescription.AddMenuAcquiredCallback and not menuDescription.__twichSkinCallbackAdded then
            menuDescription:AddMenuAcquiredCallback(function(acquiredMenu)
                StyleModernMenuFrame(acquiredMenu)
            end)
            menuDescription.__twichSkinCallbackAdded = true
        end

        C_Timer.After(0, function()
            local activeMenu = self.GetOpenMenu and self:GetOpenMenu() or nil
            if activeMenu then
                StyleModernMenuFrame(activeMenu)
            end
        end)
    end

    hooksecurefunc(manager, "OpenMenu", SkinManagedMenu)
    hooksecurefunc(manager, "OpenContextMenu", SkinManagedMenu)

    BlizzardSkins.__twichModernContextHooksInstalled = true
end

function BlizzardSkins:StyleCharacterFilters()
    local primary = Theme:GetColor("primaryColor")

    if _G.ReputationFrame and _G.ReputationFrame.filterDropdown then
        SkinFilterDropdown(_G.ReputationFrame.filterDropdown)
    end

    if _G.TokenFrame and _G.TokenFrame.filterDropdown then
        SkinFilterDropdown(_G.TokenFrame.filterDropdown)
    end

    HookDropDownListBackdrop()
    HookDropDownListMenus()

    if _G.PaperDollFrameEquipSet and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(_G.PaperDollFrameEquipSet, primary)
    end
end

-- ---------------------------------------------------------------------------
-- Slot overlay helpers (iLvl + enchant)
-- ---------------------------------------------------------------------------

-- Which column a slot belongs to determines which side the overlays hang off
local SLOT_COLUMN = {
    [1]  = "left",   -- Head
    [2]  = "left",   -- Neck
    [3]  = "left",   -- Shoulder
    [5]  = "left",   -- Chest
    [9]  = "left",   -- Wrist
    [15] = "left",   -- Back
    [18] = "left",   -- Shirt
    [19] = "left",   -- Tabard
    [6]  = "right",  -- Waist
    [7]  = "right",  -- Legs
    [8]  = "right",  -- Feet
    [10] = "right",  -- Hands
    [11] = "right",  -- Finger0
    [12] = "right",  -- Finger1
    [13] = "right",  -- Trinket0
    [14] = "right",  -- Trinket1
    [16] = "bottom", -- MainHand
    [17] = "bottom", -- SecondaryHand
}

local TWICH_SCAN_TT = "TwichCharacterScanTooltip"
local MATCH_ENCHANT -- lazy init from ENCHANTED_TOOLTIP_LINE

local function GetScanTooltip()
    local tt = _G[TWICH_SCAN_TT]
    if not tt then
        tt = CreateFrame("GameTooltip", TWICH_SCAN_TT, nil, "GameTooltipTemplate")
        tt:SetOwner(_G.WorldFrame or _G.UIParent, "ANCHOR_NONE")
    end
    return tt
end

local function GetSlotFont()
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    local fontKey = Theme and Theme.Get and Theme:Get("globalFont")
    if LSM and fontKey then
        local path = LSM:Fetch(LSM.MediaType and LSM.MediaType.FONT or "font", fontKey, true)
        if path then return path end
    end
    return "Fonts\\FRIZQT__.TTF"
end

function BlizzardSkins:UpdateSlotOverlays(slot, slotID, link)
    if not slot or not slotID or slotID == 0 then return end

    local fontPath = GetSlotFont()
    local col      = SLOT_COLUMN[slotID] or "left"
    local isRight  = col == "right"
    local isBottom = col == "bottom"
    local jH       = isRight and "RIGHT" or "LEFT"

    -- ---- iLvl font string ----
    if not slot.__twichILvlText then
        slot.__twichILvlText = slot:CreateFontString(nil, "OVERLAY")
    end
    slot.__twichILvlText:SetFont(fontPath, 11, "")
    slot.__twichILvlText:SetJustifyH(jH)
    slot.__twichILvlText:ClearAllPoints()
    if isBottom then
        slot.__twichILvlText:SetPoint("BOTTOM", slot, "TOP", 0, 3)
    elseif isRight then
        slot.__twichILvlText:SetPoint("BOTTOMRIGHT", slot, "BOTTOMLEFT", -3, 3)
    else
        slot.__twichILvlText:SetPoint("BOTTOMLEFT", slot, "BOTTOMRIGHT", 3, 3)
    end

    -- ---- enchant font string ----
    if not slot.__twichEnchantText then
        slot.__twichEnchantText = slot:CreateFontString(nil, "OVERLAY")
        slot.__twichEnchantText:SetWordWrap(false)
    end
    slot.__twichEnchantText:SetWidth(72) -- updated every call so cache-width is always current
    slot.__twichEnchantText:SetFont(fontPath, 9, "")
    slot.__twichEnchantText:SetJustifyH(jH)
    slot.__twichEnchantText:ClearAllPoints()
    if isBottom then
        slot.__twichEnchantText:SetPoint("BOTTOM", slot, "TOP", 0, 14)
    elseif isRight then
        slot.__twichEnchantText:SetPoint("TOPRIGHT", slot, "TOPLEFT", -3, -3)
    else
        slot.__twichEnchantText:SetPoint("TOPLEFT", slot, "TOPRIGHT", 3, -3)
    end

    if link then
        -- item level via C_Item API (no tooltip needed)
        local iLvl = GetDetailedItemLevelInfo and GetDetailedItemLevelInfo(link)
        if iLvl and iLvl > 0 then
            slot.__twichILvlText:SetText(iLvl)
            slot.__twichILvlText:SetTextColor(0.88, 0.88, 0.88)
        else
            slot.__twichILvlText:SetText("")
        end

        -- enchant via tooltip scan
        self:ScanSlotEnchant(slot, slotID)
    else
        slot.__twichILvlText:SetText("")
        slot.__twichEnchantText:SetText("")
    end
end

function BlizzardSkins:ScanSlotEnchant(slot, slotID)
    if not MATCH_ENCHANT then
        local pattern = _G.ENCHANTED_TOOLTIP_LINE
        if pattern then
            MATCH_ENCHANT = pattern:gsub("%%s", "(.+)")
        else
            return
        end
    end

    local tt = GetScanTooltip()
    tt:SetOwner(_G.WorldFrame or _G.UIParent, "ANCHOR_NONE")
    local hasItem = tt:SetInventoryItem("player", slotID)
    if not hasItem then
        tt:Hide()
        if slot.__twichEnchantText then slot.__twichEnchantText:SetText("") end
        return
    end

    -- If data isn't ready yet, retry shortly
    local firstLine = _G[TWICH_SCAN_TT .. "TextLeft1"]
    if firstLine and firstLine:GetText() == _G.RETRIEVING_ITEM_INFO then
        tt:Hide()
        C_Timer.After(0.4, function()
            if _G.CharacterFrame and _G.CharacterFrame:IsShown() then
                BlizzardSkins:ScanSlotEnchant(slot, slotID)
            end
        end)
        return
    end

    local enchant = nil
    local numLines = tt:NumLines()
    for i = 2, numLines do
        local leftText = _G[TWICH_SCAN_TT .. "TextLeft" .. i]
        if leftText then
            local text = leftText:GetText() or ""
            local enc = strmatch(text, MATCH_ENCHANT)
            if enc then
                -- Strip color codes and atlas tags
                enc = gsub(gsub(enc, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
                enc = gsub(enc, "|A.-|a", "")
                enc = enc:match("^%s*(.-)%s*$") -- trim
                -- Abbreviate long strings
                if #enc > 24 then enc = enc:sub(1, 23) .. "." end
                enchant = enc
                break
            end
        end
    end
    tt:Hide()

    if slot.__twichEnchantText then
        if enchant then
            slot.__twichEnchantText:SetText(enchant)
            slot.__twichEnchantText:SetTextColor(0.45, 1.0, 0.55)
        else
            slot.__twichEnchantText:SetText("")
        end
    end
end

function BlizzardSkins:StyleItemSlot(slot)
    if not slot then
        return
    end

    local _, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    local slotID = slot.GetID and slot:GetID() or 0
    local slotName = slot.GetName and slot:GetName()
    local icon = slot.icon or (slotName and _G[slotName .. "IconTexture"])
    local count = slot.Count or (slotName and _G[slotName .. "Count"])
    local cooldown = slotName and _G[slotName .. "Cooldown"]
    local popoutButton = slot.popoutButton

    -- Save the live icon texture before HideTextureRegions wipes it
    local iconTex = (slotID and slotID > 0) and GetInventoryItemTexture and GetInventoryItemTexture("player", slotID)

    HideTextureRegions(slot)
    HideTexture(slot.IconBorder)
    HideTexture(slot.ignoreTexture)

    local chrome = EnsureLayer(slot, "__twichSlotChrome", -1)
    chrome:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    chrome:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    ApplySurfaceChrome(chrome, border, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 1,
        alpha = 0.82,
        edgeAlpha = 0.18,
        glowAlpha = 0.015,
    })

    -- Restore icon after HideTextureRegions cleared it
    if icon then
        if iconTex then
            icon:SetTexture(iconTex)
        end
        CropIcon(icon)
        icon:Show()
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -4, 4)
    end

    if count then
        count:SetDrawLayer("OVERLAY", 7)
        count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
    end

    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetPoint("TOPLEFT", icon or slot, "TOPLEFT", 0, 0)
        cooldown:SetPoint("BOTTOMRIGHT", icon or slot, "BOTTOMRIGHT", 0, 0)
    end

    if popoutButton then
        popoutButton:SetAlpha(1)
    end

    if not slot.__twichHover then
        slot.__twichHover = EnsureTexture(slot, "__twichHover", "HIGHLIGHT")
        slot.__twichHover:SetPoint("TOPLEFT", slot, "TOPLEFT", 3, -3)
        slot.__twichHover:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -3, 3)
    end
    slot.__twichHover:SetColorTexture(border[1] or 1, border[2] or 1, border[3] or 1, 0.10)

    local link = GetInventoryItemLink("player", slotID)
    local quality = link and select(3, GetItemInfo(link)) or nil
    local qColor = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    chrome:SetBackdropBorderColor(border[1] or 0.24, border[2] or 0.26, border[3] or 0.32, 0.72)
    if chrome.__twichEdgeAccent then
        chrome.__twichEdgeAccent:SetColorTexture(border[1] or 0.24, border[2] or 0.26, border[3] or 0.32, 0.18)
    end
    if chrome.__twichInnerGlow then
        chrome.__twichInnerGlow:SetColorTexture(border[1] or 0.24, border[2] or 0.26, border[3] or 0.32, 0.015)
    end

    if qColor and slot.IconBorder and slot.IconBorder.SetVertexColor then
        slot.IconBorder:SetVertexColor(qColor.r or 1, qColor.g or 1, qColor.b or 1)
        slot.IconBorder:SetAlpha(0.85)
        slot.IconBorder:Show()
    elseif slot.IconBorder then
        slot.IconBorder:SetAlpha(0)
    end

    if icon and not link then
        icon:SetAlpha(0.16)
    elseif icon then
        icon:SetAlpha(1)
    end

    -- Update iLvl and enchant overlays
    self:UpdateSlotOverlays(slot, slotID, link)
end

local function HideLayerIfPresent(frame, key)
    if frame and frame[key] then
        frame[key]:Hide()
    end
end

function BlizzardSkins:StyleEquipmentManagerChild(child)
    if not child or not child.icon then
        return
    end

    local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTexture(child.BgTop)
    HideTexture(child.BgMiddle)
    HideTexture(child.BgBottom)
    CropIcon(child.icon)
    child.icon:Show()

    local chrome = EnsureLayer(child, "__twichRowChrome", -1)
    chrome:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -1)
    chrome:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -2, 1)
    ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.90,
        glowAlpha = 0.04,
    })

    child.icon:ClearAllPoints()
    child.icon:SetPoint("LEFT", child, "LEFT", 6, 0)
    child.icon:SetSize(28, 28)

    if child.HighlightBar then
        child.HighlightBar:SetColorTexture(primary[1] or 1, primary[2] or 1, primary[3] or 1, 0.18)
        child.HighlightBar:SetAllPoints(chrome)
    end

    if child.SelectedBar then
        child.SelectedBar:SetColorTexture(primary[1] or 1, primary[2] or 1, primary[3] or 1, 0.26)
        child.SelectedBar:SetAllPoints(chrome)
    end
end

function BlizzardSkins:StyleTitleManagerChild(child)
    if not child then
        return
    end

    HideTextureRegions(child)
    local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    local chrome = EnsureLayer(child, "__twichTitleChrome", -1)
    chrome:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -1)
    chrome:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -2, 1)
    ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.90,
        glowAlpha = 0.04,
    })
end

function BlizzardSkins:StyleSidebarTabs()
    local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
    local index = 1
    local tab = _G["PaperDollSidebarTab" .. index]

    while tab do
        -- Save icon info BEFORE wiping so we can restore the texture path
        local savedAtlas   = tab.Icon and tab.Icon.GetAtlas and tab.Icon:GetAtlas() or nil
        local savedTexture = tab.Icon and tab.Icon.GetTexture and tab.Icon:GetTexture() or nil

        HideTextureRegions(tab)

        -- Kill TabBg (background graphic we replace with our chrome)
        if tab.TabBg then
            HideTexture(tab.TabBg)
        end

        -- Re-apply the icon texture that HideTextureRegions wiped
        if tab.Icon then
            if savedAtlas and savedAtlas ~= "" then
                tab.Icon:SetAtlas(savedAtlas)
            elseif savedTexture and savedTexture ~= "" and not tostring(savedTexture):find("^%d+$") then
                tab.Icon:SetTexture(savedTexture)
            end
            CropIcon(tab.Icon)
            tab.Icon:SetAlpha(1)
            tab.Icon:Show()
            tab.Icon:ClearAllPoints()
            tab.Icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -2)
            tab.Icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
            tab.Icon:SetDrawLayer("OVERLAY", 3)
        end

        -- Style Hider as a dim overlay (Blizzard Show/Hide handles active/inactive)
        if tab.Hider then
            if tab.Hider.SetColorTexture then
                tab.Hider:SetColorTexture(0, 0, 0, 0.55)
            elseif tab.Hider.SetTexture then
                tab.Hider:SetTexture("Interface\\Buttons\\WHITE8X8")
                tab.Hider:SetVertexColor(0, 0, 0, 1)
                tab.Hider:SetAlpha(0.55)
            end
            tab.Hider:ClearAllPoints()
            tab.Hider:SetAllPoints(tab)
        end

        local chrome = EnsureLayer(tab, "__twichSidebarChrome", -1)
        chrome:SetAllPoints(tab)
        ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = 0.92,
            glowAlpha = 0.05,
        })

        tab:Show()
        if tab.Highlight then
            tab.Highlight:SetColorTexture(primary[1] or 1, primary[2] or 1, primary[3] or 1, 0.18)
            tab.Highlight:SetAllPoints(tab)
        end

        index = index + 1
        tab = _G["PaperDollSidebarTab" .. index]
    end
end

function BlizzardSkins:StyleCharacterTabs()
    local primary = Theme:GetColor("primaryColor")
    local index = 1
    local previousTab = nil
    local tab = _G["CharacterFrameTab" .. index]

    while tab do
        HideTextureRegions(tab)
        if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
            T.Tools.UI.SkinTwichButton(tab, primary)
        end

        tab:SetHeight(24)
        if tab.Text then
            tab.Text:SetTextColor(1, 0.95, 0.85)
        end

        tab:ClearAllPoints()
        if previousTab then
            tab:SetPoint("TOPLEFT", previousTab, "TOPRIGHT", -1, 0)
        else
            tab:SetPoint("TOPLEFT", _G.CharacterFrame, "BOTTOMLEFT", 8, 3)
        end

        previousTab = tab
        index = index + 1
        tab = _G["CharacterFrameTab" .. index]
    end
end

function BlizzardSkins:StyleEquipmentFlyout()
    local frame = _G.EquipmentFlyoutFrame
    if not frame or not frame.buttonFrame then
        return
    end

    local primary, accent, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()

    HideTexture(_G.EquipmentFlyoutFrameHighlight)
    if _G.EquipmentFlyoutFrameButtons and _G.EquipmentFlyoutFrameButtons.bg1 then
        HideTexture(_G.EquipmentFlyoutFrameButtons.bg1)
    end

    local shell = EnsureLayer(frame.buttonFrame, "__twichFlyoutChrome", -1)
    shell:SetAllPoints(frame.buttonFrame)
    ApplySurfaceChrome(shell, primary, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 2,
        alpha = 0.95,
        glowAlpha = 0.07,
    })

    for _, button in pairs(frame.buttons or {}) do
        if button.icon then
            HideTextureRegions(button)
            local buttonChrome = EnsureLayer(button, "__twichFlyoutButtonChrome", -1)
            buttonChrome:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            buttonChrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            ApplySurfaceChrome(buttonChrome, accent, background, border, backgroundAlpha, borderAlpha, {
                edge = "left",
                edgeSize = 2,
                alpha = 0.92,
                glowAlpha = 0.05,
            })
            CropIcon(button.icon)
            button.icon:Show()
            button.icon:SetAllPoints(buttonChrome)
        end
    end

    if frame.NavigationFrame then
        local nav = frame.NavigationFrame
        local navChrome = EnsureLayer(nav, "__twichNavChrome", -1)
        navChrome:SetAllPoints(nav)
        ApplySurfaceChrome(navChrome, primary, background, border, backgroundAlpha, borderAlpha, {
            edge = "top",
            edgeSize = 2,
            alpha = 0.94,
            glowAlpha = 0.05,
        })

        SkinIconButton(nav.PrevButton, primary, background, border, backgroundAlpha, borderAlpha, "<")
        SkinIconButton(nav.NextButton, primary, background, border, backgroundAlpha, borderAlpha, ">")
    end
end

-- Skins a ToggleCollapseButton (+ / - expand widget) by applying chrome
-- while using text +/- glyphs instead of the native Blizzard icon.
local function SkinToggleCollapseButton(button, accent, background, border, backgroundAlpha, borderAlpha)
    if not button then return end
    -- Clear native textures and apply backdrop chrome
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    HideTextureRegions(button)

    local chrome = EnsureLayer(button, "__twichIconChrome", -1)
    chrome:SetAllPoints(button)
    ApplySurfaceChrome(chrome, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "left", edgeSize = 2, glowAlpha = 0.06,
    })

    -- Glyph FontString: "+" for collapsed, "\xe2\x80\x93" (–) for expanded
    if not button.__twichCollapseGlyph then
        button.__twichCollapseGlyph = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        button.__twichCollapseGlyph:SetPoint("CENTER", button, "CENTER", 0, 0)
        button.__twichCollapseGlyph:SetFont(
            (GetSlotFont and GetSlotFont()) or "Fonts\\FRIZQT__.TTF", 12, "")
    end
    local glyph = button.__twichCollapseGlyph
    glyph:SetTextColor(accent[1] or 1, accent[2] or 1, accent[3] or 1)

    local function UpdateGlyph(btn)
        local header = btn.GetHeader and btn:GetHeader()
        local collapsed = header and header.IsCollapsed and header:IsCollapsed()
        if btn.__twichCollapseGlyph then
            btn.__twichCollapseGlyph:SetText(collapsed and "+" or "\226\128\147")
        end
        -- Keep native textures cleared
        if btn.SetNormalTexture then btn:SetNormalTexture("") end
        if btn.SetPushedTexture then btn:SetPushedTexture("") end
    end

    if not button.__twichCollapseIconHooked then
        if button.RefreshIcon then
            hooksecurefunc(button, "RefreshIcon", UpdateGlyph)
        end
        button:HookScript("OnMouseDown", function(btn) C_Timer.After(0, function() UpdateGlyph(btn) end) end)
        button.__twichCollapseIconHooked = true
    end
    UpdateGlyph(button)
end

local function GetStatusBarTexturePath()
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true)
    local name = Theme and Theme.Get and Theme:Get("statusBarTexture") or "TwichUI-Smooth"
    if LSM then
        local path = LSM:Fetch(LSM.MediaType and LSM.MediaType.STATUSBAR or "statusbar", name, true)
        if path then return path end
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

function BlizzardSkins:StyleReputationChild(child)
    if not child or child.__twichRepStyled then return end

    local primary, _, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()

    -- Header row chrome (child itself is the faction row header)
    if child.Right then
        HideTextureRegions(child)
    end

    local chrome = EnsureLayer(child, "__twichRepChrome", -1)
    chrome:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -1)
    chrome:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -4, 1)
    ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.82,
        glowAlpha = 0.03,
    })

    -- Faction name text
    if child.Name and child.Name.SetTextColor then
        child.Name:SetTextColor(text[1] or 1, text[2] or 1, text[3] or 1)
        child.Name:SetDrawLayer("OVERLAY", 3)
    end

    -- Expand/collapse button with native +/- icon preserved
    local toggle = child.ToggleCollapseButton
    if toggle then
        SkinToggleCollapseButton(toggle, primary, background, border, backgroundAlpha, borderAlpha)
    end

    -- Reputation bar inside child.Content
    local bar = child.Content and child.Content.ReputationBar
    if bar then
        HideTextureRegions(bar)
        bar:SetStatusBarTexture(GetStatusBarTexturePath())
        -- Restore fill texture visibility after HideTextureRegions nulled it
        local fill = bar:GetStatusBarTexture()
        if fill then
            fill:Show()
            fill:SetAlpha(1)
        end
        -- Background track
        if not bar.__twichTrack then
            bar.__twichTrack = bar:CreateTexture(nil, "BACKGROUND")
        end
        bar.__twichTrack:SetAllPoints(bar)
        bar.__twichTrack:SetColorTexture(background[1] or 0.05, background[2] or 0.06, background[3] or 0.08, 0.90)
        local barBorder = EnsureLayer(bar, "__twichBarBorder", -1)
        barBorder:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
        barBorder:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
        ApplySurfaceChrome(barBorder, border, background, border, backgroundAlpha, borderAlpha, {
            edge = "left", edgeSize = 1, edgeAlpha = 0.20, alpha = 0.0, glowAlpha = 0.0,
        })
    end

    child.__twichRepStyled = true
end

function BlizzardSkins:StyleCurrencyChild(child)
    if not child or child.__twichCurrStyled then return end

    local primary, _, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()

    HideTextureRegions(child)

    local chrome = EnsureLayer(child, "__twichCurrChrome", -1)
    chrome:SetPoint("TOPLEFT", child, "TOPLEFT", 2, -1)
    chrome:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -4, 1)
    ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
        edge = "left",
        edgeSize = 2,
        alpha = 0.82,
        glowAlpha = 0.03,
    })

    -- Crop and size currency icon to fit within the row
    local icon = child.Content and child.Content.CurrencyIcon
    if icon then
        CropIcon(icon)
        icon:SetSize(16, 16)
        icon:Show()
        icon:SetAlpha(1)
    end

    if child.Name and child.Name.SetTextColor then
        child.Name:SetTextColor(text[1] or 1, text[2] or 1, text[3] or 1)
        child.Name:SetDrawLayer("OVERLAY", 3)
    end

    local toggle = child.ToggleCollapseButton
    if toggle then
        SkinToggleCollapseButton(toggle, primary, background, border, backgroundAlpha, borderAlpha)
    end

    child.__twichCurrStyled = true
end

function BlizzardSkins:StyleGearManagerPopup()
    local frame = _G.GearManagerPopupFrame
    if not frame or not frame:IsShown() then
        return
    end

    local primary, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(frame)

    local shell = EnsureLayer(frame, "__twichPopupChrome", -1)
    shell:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -8)
    shell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 8)
    ApplySurfaceChrome(shell, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 3,
        alpha = 0.96,
        glowAlpha = 0.08,
    })

    if frame.Header then
        frame.Header:SetTextColor(text[1] or 1, text[2] or 1, text[3] or 1)
    end
    if frame.EditBox then
        if T.Tools and T.Tools.UI and T.Tools.UI.SkinEditBox then
            T.Tools.UI.SkinEditBox(frame.EditBox)
        end
    end
    if frame.ScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(frame.ScrollBar, primary, true)
    end
end

function BlizzardSkins:StyleCharacterFrame()
    local frame = _G.CharacterFrame
    if not frame then
        return
    end

    -- Slightly enlarge the whole panel
    frame:SetScale(1.10)

    local primary, accent, background, border, text, danger, backgroundAlpha, borderAlpha = GetPalette()

    if frame.NineSlice then
        HideTextureRegions(frame.NineSlice)
    end
    HideTextureRegions(frame)
    HideTexture(_G.CharacterPortrait)
    HideTexture(_G.CharacterFramePortrait)
    HideTexture(_G.CharacterFrameInset)
    HideTexture(_G.CharacterFrameInsetRight)
    HideTexture(_G.CharacterModelFrameBackgroundOverlay)

    if _G.PaperDollFrame then
        HideTextureRegions(_G.PaperDollFrame)
        _G.PaperDollFrame:Show()
    end

    if _G.CharacterStatsPane then
        HideTextureRegions(_G.CharacterStatsPane)
        if frame.Expanded then
            _G.CharacterStatsPane:Show()
        end
    end

    if _G.ReputationFrame then
        _G.ReputationFrame:Show()
    end

    if _G.TokenFrame then
        _G.TokenFrame:Show()
    end

    local shell = EnsureLayer(frame, "__twichCharacterShell", -2)
    shell:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -8)
    shell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    ApplySurfaceChrome(shell, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 3,
        alpha = 0.98,
        glowAlpha = 0.08,
    })

    -- titleBar at same frame level as CharacterFrame (offset 0) so Blizzard
    -- FontStrings in OVERLAY draw layer naturally render above its BACKGROUND
    -- backdrop — avoids the name/level text being hidden behind the header fill.
    local titleBar = EnsureLayer(frame, "__twichCharacterTitleBar", 0)
    titleBar:SetPoint("TOPLEFT", shell, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", shell, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(45)
    -- No accent stripe on the header — plain darkened background only
    ApplySurfaceChrome(titleBar, border, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 1,
        edgeAlpha = 0.40,
        alpha = 1,
        glowAlpha = 0.0,
        bgMul = 1.22,
    })

    local titleFont = GetSlotFont()
    if frame.TitleText then
        frame.TitleText:ClearAllPoints()
        frame.TitleText:SetPoint("CENTER", titleBar, "CENTER", -10, 8)
        frame.TitleText:SetFont(titleFont, 16, "")
        frame.TitleText:SetTextColor(text[1] or 1, text[2] or 1, text[3] or 1)
        frame.TitleText:SetDrawLayer("OVERLAY", 5)
    end
    if _G.CharacterLevelText then
        _G.CharacterLevelText:ClearAllPoints()
        _G.CharacterLevelText:SetPoint("CENTER", titleBar, "CENTER", -10, -10)
        _G.CharacterLevelText:SetFont(titleFont, 10, "")
        _G.CharacterLevelText:SetTextColor(0.55, 0.80, 0.70)
        _G.CharacterLevelText:SetDrawLayer("OVERLAY", 5)
    end

    self:SuppressElvUICharacterInfo()

    HideLayerIfPresent(_G.PaperDollFrame, "__twichPaperDollChrome")
    HideLayerIfPresent(_G.CharacterStatsPane, "__twichStatsChrome")
    HideLayerIfPresent(_G.ReputationFrame, "__twichReputationChrome")
    HideLayerIfPresent(_G.TokenFrame, "__twichTokenChrome")

    -- ItemLevelFrame is re-styled via StyleStatCategories with noAccent=true below

    SkinIconButton(_G.CharacterFrameCloseButton, danger, background, border, backgroundAlpha, borderAlpha, "x", danger)
    if _G.CharacterFrameCloseButton then
        _G.CharacterFrameCloseButton:ClearAllPoints()
        _G.CharacterFrameCloseButton:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -3, -3)
        _G.CharacterFrameCloseButton:SetSize(20, 20)
    end

    local modelScene = _G.CharacterModelScene
    if modelScene then
        HideTextureRegions(modelScene)
        local modelChrome = EnsureLayer(modelScene, "__twichModelChrome", -1)
        modelChrome:SetPoint("TOPLEFT", modelScene, "TOPLEFT", 1, -1)
        modelChrome:SetPoint("BOTTOMRIGHT", modelScene, "BOTTOMRIGHT", -1, 1)
        -- Use border-only chrome on the portrait — no accent edge
        ApplySurfaceChrome(modelChrome, border, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 1,
            edgeAlpha = 0.30,
            alpha = 0.92,
            glowAlpha = 0.02,
        })
    end

    if _G.CharacterStatsPane and _G.CharacterStatsPane.ScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(_G.CharacterStatsPane.ScrollBar, primary, true)
    end
    if _G.PaperDollFrame and _G.PaperDollFrame.EquipmentManagerPane and _G.PaperDollFrame.EquipmentManagerPane.ScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(_G.PaperDollFrame.EquipmentManagerPane.ScrollBar, primary, true)
    end
    if _G.PaperDollFrame and _G.PaperDollFrame.TitleManagerPane and _G.PaperDollFrame.TitleManagerPane.ScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(_G.PaperDollFrame.TitleManagerPane.ScrollBar, primary, true)
    end

    for _, slotName in ipairs(SLOT_NAMES) do
        self:StyleItemSlot(_G[slotName])
    end

    if _G.PaperDollFrameEquipSet and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(_G.PaperDollFrameEquipSet, primary)
    end
    if _G.PaperDollFrameSaveSet and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(_G.PaperDollFrameSaveSet, accent)
    end
    if _G.CharacterFrameExpandButton then
        SkinIconButton(_G.CharacterFrameExpandButton, accent, background, border, backgroundAlpha, borderAlpha, ">")
        _G.CharacterFrameExpandButton:SetSize(20, 20)
    end

    if _G.ReputationFrame then
        HideTextureRegions(_G.ReputationFrame)
        if _G.ReputationFrame.ScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
            T.Tools.UI.SkinTwichScrollBar(_G.ReputationFrame.ScrollBar, primary, true)
        end
        -- Hook scroll children for per-row styling
        if _G.ReputationFrame.ScrollBox and not self.__repScrollHooked then
            local function StyleRepChildren(scrollBox)
                if scrollBox.ForEachFrame then
                    scrollBox:ForEachFrame(function(child)
                        BlizzardSkins:StyleReputationChild(child)
                    end)
                end
            end
            hooksecurefunc(_G.ReputationFrame.ScrollBox, "Update", StyleRepChildren)
            StyleRepChildren(_G.ReputationFrame.ScrollBox)
            self.__repScrollHooked = true
        end
    end

    if _G.TokenFrame then
        HideTextureRegions(_G.TokenFrame)
        if _G.TokenFrame.ScrollBar and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
            T.Tools.UI.SkinTwichScrollBar(_G.TokenFrame.ScrollBar, primary, true)
        end
        -- Hook scroll children for per-row styling
        if _G.TokenFrame.ScrollBox and not self.__currScrollHooked then
            local function StyleCurrChildren(scrollBox)
                if scrollBox.ForEachFrame then
                    scrollBox:ForEachFrame(function(child)
                        BlizzardSkins:StyleCurrencyChild(child)
                    end)
                end
            end
            hooksecurefunc(_G.TokenFrame.ScrollBox, "Update", StyleCurrChildren)
            StyleCurrChildren(_G.TokenFrame.ScrollBox)
            self.__currScrollHooked = true
        end
    end

    if _G.CharacterStatsPane and _G.CharacterStatsPane.ItemLevelFrame then
        local ilf = _G.CharacterStatsPane.ItemLevelFrame
        if ilf.Value then
            local fp = GetSlotFont()
            ilf.Value:SetFont(fp, 22, "")
        end
    end

    self:StyleStatCategories()
    self:StyleCharacterFilters()

    self:StyleCharacterTabs()
    self:StyleSidebarTabs()
    self:StyleEquipmentFlyout()
    self:StyleGearManagerPopup()

    if _G.PaperDollFrame and _G.PaperDollFrame.EquipmentManagerPane and _G.PaperDollFrame.EquipmentManagerPane.ScrollBox and not self.__equipmentPaneHooked then
        hooksecurefunc(_G.PaperDollFrame.EquipmentManagerPane.ScrollBox, "Update", function(scrollBox)
            if scrollBox.ForEachFrame then
                scrollBox:ForEachFrame(function(child)
                    BlizzardSkins:StyleEquipmentManagerChild(child)
                end)
            end
        end)
        self.__equipmentPaneHooked = true
    end

    if _G.PaperDollFrame and _G.PaperDollFrame.TitleManagerPane and _G.PaperDollFrame.TitleManagerPane.ScrollBox and not self.__titlePaneHooked then
        hooksecurefunc(_G.PaperDollFrame.TitleManagerPane.ScrollBox, "Update", function(scrollBox)
            if scrollBox.ForEachFrame then
                scrollBox:ForEachFrame(function(child)
                    BlizzardSkins:StyleTitleManagerChild(child)
                end)
            end
        end)
        self.__titlePaneHooked = true
    end

    if not self.__charOnShowHooked then
        frame:HookScript("OnShow", function()
            if not frame.__twichCharacterSkinned then return end
            C_Timer.After(0.15, function()
                for _, slotName in ipairs(SLOT_NAMES) do
                    local s = _G[slotName]
                    if s then
                        local sid = s.GetID and s:GetID() or 0
                        if sid > 0 and GetInventoryItemLink("player", sid) then
                            BlizzardSkins:ScanSlotEnchant(s, sid)
                        end
                    end
                end
            end)
        end)
        self.__charOnShowHooked = true
    end

    if not self.__itemSlotHooked then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(slot)
            BlizzardSkins:StyleItemSlot(slot)
        end)
        self.__itemSlotHooked = true
    end

    if not self.__sidebarHooked then
        hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", function()
            BlizzardSkins:StyleSidebarTabs()
        end)
        self.__sidebarHooked = true
    end

    if not self.__statsHooked then
        hooksecurefunc("PaperDollFrame_UpdateStats", function()
            BlizzardSkins:SuppressElvUICharacterInfo()
            BlizzardSkins:StyleStatCategories()
        end)
        self.__statsHooked = true
    end

    if not self.__flyoutHooked then
        hooksecurefunc("EquipmentFlyout_UpdateItems", function()
            BlizzardSkins:StyleEquipmentFlyout()
        end)
        self.__flyoutHooked = true
    end

    if _G.GearManagerPopupFrame and not self.__gearPopupHooked then
        _G.GearManagerPopupFrame:HookScript("OnShow", function()
            BlizzardSkins:StyleGearManagerPopup()
        end)
        self.__gearPopupHooked = true
    end

    frame.__twichCharacterSkinned = true
end

function BlizzardSkins:StyleGameMenuFrame()
    local frame = _G.GameMenuFrame
    if not frame then
        return
    end

    local primary, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(frame)

    if frame.Border then
        HideTextureRegions(frame.Border)
    end

    StyleOuterBorder(frame, "__twichGameMenuBorder", accent, background, border, backgroundAlpha, borderAlpha, {
        left = 2,
        right = -2,
        top = -2,
        bottom = 2,
    })

    local shell = EnsureLayer(frame, "__twichGameMenuShell", -2)
    shell:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -8)
    shell:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 8)
    ApplySurfaceChrome(shell, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 3,
        alpha = 0.97,
        glowAlpha = 0.08,
    })

    if frame.Header then
        HideTextureRegions(frame.Header)
        frame.Header:ClearAllPoints()
        frame.Header:SetPoint("TOP", frame, "TOP", 0, 8)
        SetFontColor(frame.Header.Text, text)
    end

    local function SkinButtons()
        if frame.buttonPool and frame.buttonPool.EnumerateActive then
            for button in frame.buttonPool:EnumerateActive() do
                StyleTextButton(button, primary)
            end
        else
            for _, child in next, { frame:GetChildren() } do
                if child and child.GetObjectType and child:GetObjectType() == "Button" and child ~= frame.CloseButton then
                    StyleTextButton(child, primary)
                end
            end
        end
    end

    SkinButtons()
    if not frame.__twichGameMenuHooked then
        if hooksecurefunc and frame.InitButtons then
            hooksecurefunc(frame, "InitButtons", SkinButtons)
        end
        if frame.HookScript then
            frame:HookScript("OnShow", SkinButtons)
        end
        frame.__twichGameMenuHooked = true
    end
end

function BlizzardSkins:StyleSettingsCategoryChild(child)
    if not child then
        return
    end

    local primary, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()

    if child.Background then
        child.Background:SetAlpha(0)
        local chrome = EnsureLayer(child.Background, "__twichSettingsCategoryChrome", -1)
        chrome:SetPoint("TOPLEFT", child.Background, "TOPLEFT", 4, -4)
        chrome:SetPoint("BOTTOMRIGHT", child.Background, "BOTTOMRIGHT", -4, 1)
        ApplySurfaceChrome(chrome, accent, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = 0.86,
            glowAlpha = 0.03,
        })
    end

    SetFontColor(child.Name, text)
    SetFontColor(child.Label, text)
    SetFontColor(child.Title, text)

    if child.Toggle then
        SkinIconButton(child.Toggle, primary, background, border, backgroundAlpha, borderAlpha, "+")
    end
end

function BlizzardSkins:StyleSettingsControlGroup(group)
    if not group then
        return
    end

    for _, child in next, { group:GetChildren() } do
        if child.SliderWithSteppers then
            StyleSliderWithSteppers(child.SliderWithSteppers)
        end
        if child.Checkbox then
            StyleCheckButton(child.Checkbox)
        end
        if child.Control then
            StyleSteppedDropdown(child.Control)
        end
        if child.GetObjectType and child:GetObjectType() == "CheckButton" then
            StyleCheckButton(child)
        end
    end
end

function BlizzardSkins:StyleSettingsListChild(child)
    if not child then
        return
    end

    local primary, accent, background, border, text, _, backgroundAlpha, borderAlpha = GetPalette()

    if child.NineSlice then
        child.NineSlice:SetAlpha(0)
        local chrome = EnsureLayer(child, "__twichSettingsRowChrome", -1)
        chrome:SetPoint("TOPLEFT", child, "TOPLEFT", 15, -30)
        chrome:SetPoint("BOTTOMRIGHT", child, "BOTTOMRIGHT", -30, -5)
        ApplySurfaceChrome(chrome, accent, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = 0.86,
            glowAlpha = 0.03,
        })
    end

    SetFontColor(child.Title, text)
    SetFontColor(child.Label, text)
    SetFontColor(child.Description, border)

    if child.Checkbox then
        StyleCheckButton(child.Checkbox)
    end

    if child.Dropdown then
        StyleSteppedDropdown(child.Dropdown)
    end

    if child.Control then
        StyleSteppedDropdown(child.Control)
    end

    if child.ColorBlindFilterDropDown then
        StyleSteppedDropdown(child.ColorBlindFilterDropDown)
    end

    if child.SliderWithSteppers then
        StyleSliderWithSteppers(child.SliderWithSteppers)
    end

    if child.Button then
        StyleTextButton(child.Button, accent)
    end

    if child.ToggleTest then
        StyleTextButton(child.ToggleTest, primary)
        if child.VUMeter then
            HideTextureRegions(child.VUMeter)
            local meterChrome = EnsureLayer(child.VUMeter, "__twichMeterChrome", -1)
            meterChrome:SetPoint("TOPLEFT", child.VUMeter, "TOPLEFT", 4, -4)
            meterChrome:SetPoint("BOTTOMRIGHT", child.VUMeter, "BOTTOMRIGHT", -4, 4)
            ApplySurfaceChrome(meterChrome, accent, background, border, backgroundAlpha, borderAlpha, {
                edge = "left",
                edgeSize = 2,
                alpha = 0.94,
                glowAlpha = 0.03,
            })
            if child.VUMeter.Status then
                child.VUMeter.Status:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                child.VUMeter.Status:SetVertexColor(accent[1] or 1, accent[2] or 1, accent[3] or 1)
            end
        end
    end

    if child.PushToTalkKeybindButton then
        StyleTextButton(child.PushToTalkKeybindButton, primary)
    end

    if child.Button1 then
        StyleTextButton(child.Button1, primary)
    end

    if child.Button2 then
        StyleTextButton(child.Button2, primary)
    end

    if child.Controls then
        for index = 1, #child.Controls do
            local control = child.Controls[index]
            if control and control.SliderWithSteppers then
                StyleSliderWithSteppers(control.SliderWithSteppers)
            end
        end
    end

    if child.BaseTab then
        StyleSettingsSubTab(child.BaseTab)
    end

    if child.RaidTab then
        StyleSettingsSubTab(child.RaidTab)
    end

    if child.BaseQualityControls then
        self:StyleSettingsControlGroup(child.BaseQualityControls)
    end

    if child.RaidQualityControls then
        self:StyleSettingsControlGroup(child.RaidQualityControls)
    end
end

function BlizzardSkins:StyleCompactUnitFrameProfiles()
    for _, frame in next, { _G.CompactUnitFrameProfiles, _G.CompactUnitFrameProfilesGeneralOptionsFrame } do
        if frame then
            for _, child in next, { frame:GetChildren() } do
                if child and child.GetObjectType then
                    local objectType = child:GetObjectType()
                    if objectType == "CheckButton" then
                        StyleCheckButton(child)
                    elseif objectType == "Button" then
                        StyleTextButton(child)
                    elseif objectType == "Slider" then
                        StyleSlider(child)
                    elseif objectType == "EditBox" then
                        StyleEditBox(child)
                    end
                end

                if child and child.Left and child.Middle and child.Right then
                    StyleSteppedDropdown({ Dropdown = child })
                end
            end
        end
    end

    if _G.CompactUnitFrameProfilesSeparator then
        _G.CompactUnitFrameProfilesSeparator:SetAlpha(0.6)
    end

    if _G.CompactUnitFrameProfilesGeneralOptionsFrameAutoActivateBG then
        local primary, _, background, border, _, _, backgroundAlpha, borderAlpha = GetPalette()
        _G.CompactUnitFrameProfilesGeneralOptionsFrameAutoActivateBG:Hide()
        local chrome = EnsureLayer(_G.CompactUnitFrameProfilesGeneralOptionsFrameAutoActivateBG,
            "__twichCompactProfilesChrome", -1)
        chrome:SetAllPoints(_G.CompactUnitFrameProfilesGeneralOptionsFrameAutoActivateBG)
        ApplySurfaceChrome(chrome, primary, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = 0.82,
            glowAlpha = 0.02,
        })
    end
end

function BlizzardSkins:StyleSettingsPanel()
    local panel = _G.SettingsPanel
    if not panel then
        return
    end

    local primary, accent, background, border, text, danger, backgroundAlpha, borderAlpha = GetPalette()
    HideTextureRegions(panel)
    if panel.Bg then
        panel.Bg:Hide()
    end
    if panel.Border then
        HideTextureRegions(panel.Border)
    end

    StyleOuterBorder(panel, "__twichSettingsBorder", accent, background, border, backgroundAlpha, borderAlpha, {
        left = 2,
        right = -2,
        top = -2,
        bottom = 2,
    })

    local shell = EnsureLayer(panel, "__twichSettingsShell", -2)
    shell:SetPoint("TOPLEFT", panel, "TOPLEFT", 6, -8)
    shell:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -6, 8)
    ApplySurfaceChrome(shell, accent, background, border, backgroundAlpha, borderAlpha, {
        edge = "top",
        edgeSize = 3,
        alpha = 0.98,
        glowAlpha = 0.08,
    })

    if panel.ClosePanelButton then
        SkinIconButton(panel.ClosePanelButton, danger, background, border, backgroundAlpha, borderAlpha, "x", danger)
    end

    if panel.CloseButton then
        StyleTextButton(panel.CloseButton, primary)
    end

    if panel.ApplyButton then
        StyleTextButton(panel.ApplyButton, accent)
    end

    if panel.SearchBox then
        StyleEditBox(panel.SearchBox)
    end

    if panel.GameTab then
        StyleSettingsSubTab(panel.GameTab)
    end

    if panel.AddOnsTab then
        StyleSettingsSubTab(panel.AddOnsTab)
    end

    if panel.CategoryList then
        local categoryChrome = EnsureLayer(panel.CategoryList, "__twichSettingsCategoryListChrome", -1)
        categoryChrome:SetAllPoints(panel.CategoryList)
        ApplySurfaceChrome(categoryChrome, primary, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = 0.9,
            glowAlpha = 0.04,
        })
        local UI = GetUI()
        if UI and UI.SkinTwichScrollBar and panel.CategoryList.ScrollBar then
            UI.SkinTwichScrollBar(panel.CategoryList.ScrollBar, primary, true)
        end
        if panel.CategoryList.ScrollBox and not panel.CategoryList.__twichUpdateHooked and hooksecurefunc then
            hooksecurefunc(panel.CategoryList.ScrollBox, "Update", function(scrollBox)
                if scrollBox and scrollBox.ForEachFrame then
                    scrollBox:ForEachFrame(function(child)
                        BlizzardSkins:StyleSettingsCategoryChild(child)
                    end)
                end
            end)
            panel.CategoryList.__twichUpdateHooked = true
        end
        if panel.CategoryList.ScrollBox and panel.CategoryList.ScrollBox.ForEachFrame then
            panel.CategoryList.ScrollBox:ForEachFrame(function(child)
                BlizzardSkins:StyleSettingsCategoryChild(child)
            end)
        end
    end

    if panel.Container then
        local containerChrome = EnsureLayer(panel.Container, "__twichSettingsContainerChrome", -1)
        containerChrome:SetAllPoints(panel.Container)
        ApplySurfaceChrome(containerChrome, accent, background, border, backgroundAlpha, borderAlpha, {
            edge = "left",
            edgeSize = 2,
            alpha = 0.9,
            glowAlpha = 0.04,
        })

        local settingsList = panel.Container.SettingsList
        if settingsList then
            if settingsList.Header and settingsList.Header.DefaultsButton then
                StyleTextButton(settingsList.Header.DefaultsButton, primary)
            end
            local UI = GetUI()
            if UI and UI.SkinTwichScrollBar and settingsList.ScrollBar then
                UI.SkinTwichScrollBar(settingsList.ScrollBar, accent, true)
            end
            if settingsList.ScrollBox and not settingsList.__twichUpdateHooked and hooksecurefunc then
                hooksecurefunc(settingsList.ScrollBox, "Update", function(scrollBox)
                    if scrollBox and scrollBox.ForEachFrame then
                        scrollBox:ForEachFrame(function(child)
                            BlizzardSkins:StyleSettingsListChild(child)
                        end)
                    end
                end)
                settingsList.__twichUpdateHooked = true
            end
            if settingsList.ScrollBox and settingsList.ScrollBox.ForEachFrame then
                settingsList.ScrollBox:ForEachFrame(function(child)
                    BlizzardSkins:StyleSettingsListChild(child)
                end)
            end
        end
    end

    self:StyleCompactUnitFrameProfiles()

    if not panel.__twichSettingsHooksInstalled then
        if panel.HookScript then
            panel:HookScript("OnShow", function()
                BlizzardSkins:ApplySystemMenuSkinsLater()
            end)
        end
        if hooksecurefunc and panel.DisplayCategory then
            hooksecurefunc(panel, "DisplayCategory", function()
                BlizzardSkins:ApplySystemMenuSkinsLater()
            end)
        end
        panel.__twichSettingsHooksInstalled = true
    end
end

function BlizzardSkins:ApplySystemMenuSkinsLater()
    C_Timer.After(0, function()
        HookDropDownListBackdrop()
        HookDropDownListMenus()
        HookModernContextMenus()
        BlizzardSkins:StyleGameMenuFrame()
        BlizzardSkins:StyleSettingsPanel()
    end)
end

function BlizzardSkins:ApplyCharacterSkinLater()
    C_Timer.After(0, function()
        BlizzardSkins:StyleCharacterFrame()
    end)
end

function BlizzardSkins:OnEnable()
    HookDropDownListBackdrop()
    HookDropDownListMenus()
    HookModernContextMenus()

    self:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_UIPanels_Game" then
            self:ApplyCharacterSkinLater()
        elseif addonName and strmatch(addonName, "^Blizzard_Settings") then
            self:ApplySystemMenuSkinsLater()
        elseif addonName == "Blizzard_Menu" then
            HookModernContextMenus()
        end
    end)
    self:RegisterMessage("TWICH_THEME_CHANGED", function()
        if _G.CharacterFrame and _G.CharacterFrame.__twichCharacterSkinned then
            self:ApplyCharacterSkinLater()
        end
        self:ApplySystemMenuSkinsLater()
    end)

    -- Refresh overlays when gear changes (Blizzard already calls PaperDollItemSlotButton_Update
    -- via our hook, but a fresh enchant scan after a short delay ensures data is loaded)
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", function(_, slotID, hasItem)
        if not (_G.CharacterFrame and _G.CharacterFrame:IsShown()) then return end
        if not slotID or slotID == 0 then return end
        C_Timer.After(0.2, function()
            for _, slotName in ipairs(SLOT_NAMES) do
                local s = _G[slotName]
                if s and s.GetID and s:GetID() == slotID then
                    if hasItem then
                        BlizzardSkins:ScanSlotEnchant(s, slotID)
                    elseif s.__twichEnchantText then
                        s.__twichEnchantText:SetText("")
                    end
                    break
                end
            end
        end)
    end)

    if (_G.CharacterFrame and _G.CharacterFrame:IsObjectType("Frame")) or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_UIPanels_Game")) then
        self:ApplyCharacterSkinLater()
    end

    self:ApplySystemMenuSkinsLater()
end
