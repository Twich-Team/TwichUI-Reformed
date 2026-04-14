--[[
        Best in Slot -- Frame

        Responsibilities:
        - Provides the main Best in Slot user interface frame.
]]
---@diagnostic disable: undefined-field, undefined-global
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

local CreateFrame = CreateFrame
local UIParent = UIParent
local wipe = wipe

local SLOT_DEFINITIONS = {
    { name = "Head",        slotID = 1,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head" },
    { name = "Neck",        slotID = 2,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck" },
    { name = "Shoulder",    slotID = 3,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder" },
    { name = "Back",        slotID = 15, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" },
    { name = "Chest",       slotID = 5,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" },
    { name = "Wrist",       slotID = 9,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists" },
    { name = "Hands",       slotID = 10, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands" },
    { name = "Waist",       slotID = 6,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist" },
    { name = "Legs",        slotID = 7,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs" },
    { name = "Feet",        slotID = 8,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet" },
    { name = "Ring One",    slotID = 11, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
    { name = "Ring Two",    slotID = 12, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
    { name = "Trinket One", slotID = 13, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
    { name = "Trinket Two", slotID = 14, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
    { name = "Main Hand",   slotID = 16, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand" },
    { name = "Off Hand",    slotID = 17, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand" },
}

local EQUIP_TO_SLOTS = {
    INVTYPE_HEAD = { [1] = true },
    INVTYPE_NECK = { [2] = true },
    INVTYPE_SHOULDER = { [3] = true },
    INVTYPE_CLOAK = { [15] = true },
    INVTYPE_CHEST = { [5] = true },
    INVTYPE_ROBE = { [5] = true },
    INVTYPE_WRIST = { [9] = true },
    INVTYPE_HAND = { [10] = true },
    INVTYPE_WAIST = { [6] = true },
    INVTYPE_LEGS = { [7] = true },
    INVTYPE_FEET = { [8] = true },
    INVTYPE_FINGER = { [11] = true, [12] = true },
    INVTYPE_TRINKET = { [13] = true, [14] = true },
    INVTYPE_WEAPON = { [16] = true, [17] = true },
    INVTYPE_WEAPONMAINHAND = { [16] = true },
    INVTYPE_WEAPONOFFHAND = { [17] = true },
    INVTYPE_2HWEAPON = { [16] = true },
    INVTYPE_RANGED = { [16] = true },
    INVTYPE_RANGEDRIGHT = { [16] = true },
    INVTYPE_THROWN = { [16] = true },
    INVTYPE_SHIELD = { [17] = true },
    INVTYPE_HOLDABLE = { [17] = true },
}

local SECTION_TINTS = {
    hero = { 0.18, 0.36, 0.42 },
    slots = { 0.14, 0.42, 0.42 },
    sources = { 0.46, 0.34, 0.12 },
    detail = { 0.18, 0.30, 0.44 },
    items = { 0.14, 0.20, 0.34 },
}

local EMPTY_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local TEX_COORDS = { 0.08, 0.92, 0.08, 0.92 }

local function GetThemeColors()
    local ThemeModule = T:GetModule("Theme", true)
    local primary = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("primaryColor") or { 0.16, 0.78, 0.78 }
    local accent = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("accentColor") or { 0.95, 0.76, 0.26 }
    local surface = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("backgroundColor") or
        { 0.06, 0.06, 0.08 }
    local border = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    return primary, accent, surface, border
end

local function GetFallbackFont()
    local font = T.Tools and T.Tools.Text and T.Tools.Text.GetElvUIFont and T.Tools.Text.GetElvUIFont()
    if font then
        return font
    end

    return _G.STANDARD_TEXT_FONT
end

local function SetFont(fs, size, flags)
    if not fs or not fs.SetFont then
        return
    end

    local resolvedFlags = flags == "OUTLINE" and "" or (flags or "")
    fs:SetFont(GetFallbackFont(), size, resolvedFlags)
end

local function ConfigureSingleLine(fs)
    if not fs then
        return
    end

    if fs.SetWordWrap then
        fs:SetWordWrap(false)
    end
    if fs.SetMaxLines then
        fs:SetMaxLines(1)
    end
end

local function ApplyBackdrop(frame, bg, bd, bgAlpha, bdAlpha)
    if not frame then
        return
    end

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    elseif frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    if frame.SetBackdropColor then
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bgAlpha or 0.82)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bdAlpha or 0.34)
    end
end

local function MixColor(base, tint, weight)
    local t = weight or 0.5
    return {
        (base[1] * (1 - t)) + (tint[1] * t),
        (base[2] * (1 - t)) + (tint[2] * t),
        (base[3] * (1 - t)) + (tint[3] * t),
    }
end

local function FormatTrack(rank)
    if not rank then
        return nil
    end

    local trackName = BIS.ItemScanner and BIS.ItemScanner.GetGearTrackByRank and BIS.ItemScanner.GetGearTrackByRank(rank)
    if not trackName then
        return nil
    end

    if T.Tools and T.Tools.Text and T.Tools.Text.ToTitleCase then
        return T.Tools.Text.ToTitleCase(trackName)
    end

    return trackName
end

local function CreateText(parent, layer, size, flags, color)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    SetFont(fs, size or 12, flags)
    if color then
        fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
    return fs
end

local function CreateChip(parent, width)
    local chip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    chip:SetSize(width or 84, 20)
    ApplyBackdrop(chip, { 0.1, 0.1, 0.1 }, { 0.3, 0.3, 0.3 }, 0.96, 0.28)

    chip.Text = CreateText(chip, "OVERLAY", 9, "OUTLINE", { 1, 0.95, 0.84 })
    chip.Text:SetPoint("CENTER", chip, "CENTER", 0, 0)

    return chip
end

local function AttachTooltip(frame, text, anchor)
    if not frame or type(text) ~= "string" or text == "" then
        return
    end

    frame:HookScript("OnEnter", function(owner)
        GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 0.95, 0.84, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreateMetricBar(parent, width, tint, labelText)
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    holder:SetSize(width or 180, 28)
    ApplyBackdrop(holder, { 0.05, 0.07, 0.09 }, { tint[1], tint[2], tint[3] }, 0.48, 0.18)

    holder.Fill = CreateFrame("StatusBar", nil, holder)
    holder.Fill:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    holder.Fill:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    holder.Fill:SetWidth(1)
    holder.Fill:SetMinMaxValues(0, 1)
    holder.Fill:SetValue(0)
    holder.Fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    holder.Fill:SetStatusBarColor(tint[1], tint[2], tint[3], 0.85)
    holder.Fill:SetFrameLevel(math.max(0, holder:GetFrameLevel() - 1))

    holder.FillGlow = holder.Fill:CreateTexture(nil, "ARTWORK")
    holder.FillGlow:SetAllPoints(holder.Fill)
    holder.FillGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    holder.FillGlow:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.14), CreateColor(1, 1, 1, 0.02))

    holder.TextLayer = CreateFrame("Frame", nil, holder)
    holder.TextLayer:SetAllPoints(holder)
    holder.TextLayer:SetFrameLevel(holder:GetFrameLevel() + 5)

    holder.Label = CreateText(holder.TextLayer, "OVERLAY", 9, "", { 0.72, 0.76, 0.84 })
    holder.Label:SetPoint("LEFT", holder.TextLayer, "LEFT", 10, 0)
    holder.Label:SetText(labelText or "")

    holder.StatePip = holder.TextLayer:CreateTexture(nil, "OVERLAY")
    holder.StatePip:SetPoint("LEFT", holder.Label, "RIGHT", 8, 0)
    holder.StatePip:SetSize(7, 7)
    holder.StatePip:SetTexture("Interface\\Buttons\\WHITE8X8")
    holder.StatePip:Hide()

    holder.StateText = CreateText(holder.TextLayer, "OVERLAY", 9, "OUTLINE", { 0.82, 0.88, 0.94 })
    holder.StateText:SetPoint("LEFT", holder.StatePip, "RIGHT", 5, 0)
    holder.StateText:SetJustifyH("LEFT")

    holder.Value = CreateText(holder.TextLayer, "OVERLAY", 10, "", { 1, 0.96, 0.9 })
    holder.Value:SetPoint("RIGHT", holder.TextLayer, "RIGHT", -10, 0)
    holder.Value:SetJustifyH("RIGHT")

    return holder
end

local function CreateInlineBar(parent, width, height, tint)
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    holder:SetSize(width or 120, height or 8)
    ApplyBackdrop(holder, { 0.05, 0.06, 0.08 }, { tint[1], tint[2], tint[3] }, 0.38, 0.1)

    holder.Fill = CreateFrame("StatusBar", nil, holder)
    holder.Fill:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    holder.Fill:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
    holder.Fill:SetWidth(1)
    holder.Fill:SetMinMaxValues(0, 1)
    holder.Fill:SetValue(0)
    holder.Fill:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    holder.Fill:SetStatusBarColor(tint[1], tint[2], tint[3], 0.9)

    return holder
end

local function SetInlineBar(holder, progress)
    if not holder or not holder.Fill then
        return
    end

    local value = math.max(0, math.min(1, tonumber(progress) or 0))
    holder.Fill:SetValue(value)
    holder.Fill:SetWidth(math.max(1, ((holder:GetWidth() or 1) - 2) * value))
end

local function SetMetricBar(holder, progress, text)
    if not holder or not holder.Fill then
        return
    end

    local value = math.max(0, math.min(1, tonumber(progress) or 0))
    holder.Fill:SetValue(value)
    local width = math.max(1, ((holder:GetWidth() or 1) - 2) * value)
    holder.Fill:SetWidth(width)
    holder.Value:SetText(text or "")
end

local function SetMetricBarStatus(holder, color, text)
    if not holder or not holder.StatePip or not holder.StateText then
        return
    end

    if type(color) == "table" then
        holder.StatePip:SetColorTexture(color[1], color[2], color[3], 0.92)
        holder.StatePip:Show()
    else
        holder.StatePip:Hide()
    end

    holder.StateText:SetText(text or "")
end

local function SetChip(chip, text, color)
    if not chip then
        return
    end

    local baseColor = color or { 0.45, 0.45, 0.45 }
    chip.Text:SetText(text or "")
    chip.Text:SetTextColor(1, 0.95, 0.84)
    if chip.SetBackdropColor then
        chip:SetBackdropColor(baseColor[1] * 0.24, baseColor[2] * 0.24, baseColor[3] * 0.24, 0.98)
    end
    if chip.SetBackdropBorderColor then
        chip:SetBackdropBorderColor(baseColor[1], baseColor[2], baseColor[3], 0.48)
    end
end

local function TooltipSetItem(itemID, itemLink)
    if type(itemLink) == "string" and itemLink ~= "" then
        GameTooltip:SetHyperlink(itemLink)
        return true
    end

    if type(itemID) == "number" then
        GameTooltip:SetItemByID(itemID)
        return true
    end

    return false
end

local function IsTierSlot(slotID)
    return slotID == 1 or slotID == 3 or slotID == 5 or slotID == 7 or slotID == 10
end

local function ApplySectionChrome(frame, tint)
    local primary, accent, surface, border = GetThemeColors()
    local panelColor = MixColor(surface, tint or primary, 0.34)
    ApplyBackdrop(frame, { panelColor[1] * 0.96, panelColor[2] * 0.96, panelColor[3] * 1.02 }, border, 0.74, 0.24)

    if not frame.TopAccent then
        frame.TopAccent = frame:CreateTexture(nil, "ARTWORK")
        frame.TopAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TopAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.TopAccent:SetHeight(3)
    end
    frame.TopAccent:SetColorTexture(tint[1], tint[2], tint[3], 0.9)

    if not frame.InnerGlow then
        frame.InnerGlow = frame:CreateTexture(nil, "BACKGROUND")
        frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    frame.InnerGlow:SetColorTexture(primary[1], primary[2], primary[3], 0.05)

    if not frame.TopShade then
        frame.TopShade = frame:CreateTexture(nil, "BACKGROUND")
        frame.TopShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TopShade:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.TopShade:SetHeight(52)
        frame.TopShade:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.TopShade:SetGradient("VERTICAL", CreateColor(accent[1], accent[2], accent[3], 0.14),
            CreateColor(0, 0, 0, 0))
    end

    if not frame.BottomShade then
        frame.BottomShade = frame:CreateTexture(nil, "BACKGROUND")
        frame.BottomShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
        frame.BottomShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame.BottomShade:SetHeight(64)
        frame.BottomShade:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.BottomShade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.22))
    end

    if not frame.HeaderShade then
        frame.HeaderShade = frame:CreateTexture(nil, "BORDER")
        frame.HeaderShade:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.HeaderShade:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.HeaderShade:SetHeight(52)
    end
    frame.HeaderShade:SetColorTexture(tint[1], tint[2], tint[3], 0.08)

    if frame.CornerGlow then
        frame.CornerGlow:Hide()
    end
end

local function CreateTwichButton(parent, text, width, height, color, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, height or 28)

    local tint = color or { 0.98, 0.76, 0.24 }
    ApplyBackdrop(button, { 0.06, 0.07, 0.09 }, tint, 0.64, 0.18)

    button.LeftAccent = button:CreateTexture(nil, "BORDER")
    button.LeftAccent:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.LeftAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    button.LeftAccent:SetWidth(3)
    button.LeftAccent:SetColorTexture(tint[1], tint[2], tint[3], 0.92)

    button.InnerGlow = button:CreateTexture(nil, "BACKGROUND")
    button.InnerGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.InnerGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.InnerGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.InnerGlow:SetGradient("HORIZONTAL", CreateColor(tint[1], tint[2], tint[3], 0.14),
        CreateColor(tint[1], tint[2], tint[3], 0.02))

    button.HoverGlow = button:CreateTexture(nil, "ARTWORK")
    button.HoverGlow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.HoverGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.HoverGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.HoverGlow:SetColorTexture(1, 1, 1, 0)

    local label = button:CreateFontString(nil, "OVERLAY")
    SetFont(label, 10, "")
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
    label:SetTextColor(1, 0.95, 0.84)
    button:SetFontString(label)
    button:SetText(text or "")

    if type(onClick) == "function" then
        button:SetScript("OnClick", onClick)
    end

    if not button.__bisHoverIn then
        button.__bisHoverIn = button:CreateAnimationGroup()
        local inAlpha = button.__bisHoverIn:CreateAnimation("Alpha")
        inAlpha:SetChildKey("HoverGlow")
        inAlpha:SetFromAlpha(0)
        inAlpha:SetToAlpha(0.14)
        inAlpha:SetDuration(0.14)
        local inScale = button.__bisHoverIn:CreateAnimation("Scale")
        inScale:SetScale(1.02, 1.02)
        inScale:SetDuration(0.14)

        button.__bisHoverOut = button:CreateAnimationGroup()
        local outAlpha = button.__bisHoverOut:CreateAnimation("Alpha")
        outAlpha:SetChildKey("HoverGlow")
        outAlpha:SetFromAlpha(0.14)
        outAlpha:SetToAlpha(0)
        outAlpha:SetDuration(0.14)
        local outScale = button.__bisHoverOut:CreateAnimation("Scale")
        outScale:SetScale(0.980392, 0.980392)
        outScale:SetDuration(0.14)

        button:HookScript("OnEnter", function(self)
            if self.__bisHoverOut:IsPlaying() then
                self.__bisHoverOut:Stop()
            end
            self:SetBackdropBorderColor(tint[1], tint[2], tint[3], 0.42)
            self.__bisHoverIn:Play()
        end)
        button:HookScript("OnLeave", function(self)
            if self.__bisHoverIn:IsPlaying() then
                self.__bisHoverIn:Stop()
            end
            self:SetBackdropBorderColor(tint[1], tint[2], tint[3], 0.18)
            self.__bisHoverOut:Play()
        end)
    end

    return button
end

local function CreateMiniActionButton(parent, text, width, height, color, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 50, height or 20)

    local tint = color or { 0.82, 0.34, 0.3 }
    ApplyBackdrop(button, { 0.08, 0.08, 0.1 }, tint, 0.82, 0.16)

    button.Fill = button:CreateTexture(nil, "BACKGROUND")
    button.Fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.Fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.Fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.Fill:SetColorTexture(tint[1], tint[2], tint[3], 0.12)

    button.Label = CreateText(button, "OVERLAY", 9, "OUTLINE", { 1, 0.95, 0.84 })
    button.Label:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.Label:SetText(text or "Clear")

    if type(onClick) == "function" then
        button:SetScript("OnClick", onClick)
    end

    button:HookScript("OnEnter", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(tint[1], tint[2], tint[3], 0.48)
        end
        if self.Fill then
            self.Fill:SetColorTexture(tint[1], tint[2], tint[3], 0.22)
        end
    end)

    button:HookScript("OnLeave", function(self)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(tint[1], tint[2], tint[3], 0.16)
        end
        if self.Fill then
            self.Fill:SetColorTexture(tint[1], tint[2], tint[3], 0.12)
        end
    end)

    return button
end

local function CreateSection(parent, title, subtitle, tint)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    ApplySectionChrome(panel, tint)

    panel.Title = CreateText(panel, "OVERLAY", 15, "OUTLINE", { 1, 0.96, 0.9 })
    panel.Title:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -12)
    panel.Title:SetText(title)

    panel.Subtitle = CreateText(panel, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    panel.Subtitle:SetPoint("TOPLEFT", panel.Title, "BOTTOMLEFT", 0, -2)
    panel.Subtitle:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    panel.Subtitle:SetJustifyH("LEFT")
    panel.Subtitle:SetText(subtitle)

    panel.Body = CreateFrame("Frame", nil, panel)
    panel.Body:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -58)
    panel.Body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)

    return panel
end

local function CreateScrollShell(parent, accentColor)
    local shell = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local _, _, surface, border = GetThemeColors()
    ApplyBackdrop(shell, { surface[1] * 0.84, surface[2] * 0.86, surface[3] * 0.94 }, border, 0.46, 0.18)

    local scroll = CreateFrame("ScrollFrame", nil, shell, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", shell, "TOPLEFT", 2, -2)
    scroll:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -28, 2)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)

    local function ResizeContent()
        local width = math.max(1, (shell:GetWidth() or 0) - 34)
        content:SetWidth(width)
    end

    shell:SetScript("OnSizeChanged", ResizeContent)
    scroll:HookScript("OnShow", ResizeContent)

    if T.Tools and T.Tools.UI and T.Tools.UI.SkinScrollBar then
        T.Tools.UI.SkinScrollBar(scroll, accentColor, true, false)
    end

    return shell, scroll, content
end

local function CreateHoverTextures(frame)
    if frame.HoverGlow then
        return
    end

    frame.HoverFill = frame:CreateTexture(nil, "ARTWORK")
    frame.HoverFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.HoverFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.HoverFill:SetColorTexture(1, 1, 1, 0)

    frame.HoverGlow = frame:CreateTexture(nil, "ARTWORK")
    frame.HoverGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.HoverGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.HoverGlow:SetColorTexture(1, 1, 1, 0)

    frame.HoverOutline = frame:CreateTexture(nil, "OVERLAY")
    frame.HoverOutline:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.HoverOutline:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.HoverOutline:SetHeight(1)
    frame.HoverOutline:SetColorTexture(1, 1, 1, 0)

    frame.HoverOutlineBottom = frame:CreateTexture(nil, "OVERLAY")
    frame.HoverOutlineBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.HoverOutlineBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.HoverOutlineBottom:SetHeight(1)
    frame.HoverOutlineBottom:SetColorTexture(1, 1, 1, 0)

    frame.LeftAccent = frame:CreateTexture(nil, "ARTWORK")
    frame.LeftAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.LeftAccent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.LeftAccent:SetWidth(3)
    frame.LeftAccent:SetColorTexture(1, 1, 1, 0.4)
end

local function ApplyInteractiveChrome(frame, tint)
    local _, _, surface, border = GetThemeColors()
    local mixed = MixColor(surface, tint or { 0.4, 0.4, 0.4 }, 0.28)
    ApplyBackdrop(frame, { mixed[1] * 0.92, mixed[2] * 0.92, mixed[3] * 0.98 }, border, 0.54, 0.16)
    CreateHoverTextures(frame)
end

local function SetInteractiveState(frame, tint, active)
    local _, _, surface, border = GetThemeColors()
    local mixed = MixColor(surface, tint, active and 0.42 or 0.22)
    frame.__tint = tint
    frame.__active = active == true
    if frame.SetBackdropColor then
        frame:SetBackdropColor(mixed[1] * (active and 1.04 or 0.92), mixed[2] * (active and 1.04 or 0.92),
            mixed[3] * (active and 1.08 or 0.98), active and 0.92 or 0.78)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(tint[1], tint[2], tint[3], active and 0.52 or 0.2)
    else
        frame:SetBackdropBorderColor(border[1], border[2], border[3], 0.22)
    end
    if frame.LeftAccent then
        frame.LeftAccent:SetColorTexture(tint[1], tint[2], tint[3], active and 1 or 0.58)
    end
    if frame.HoverGlow then
        frame.HoverGlow:SetColorTexture(tint[1], tint[2], tint[3], active and 0.12 or 0.03)
    end
    if frame.HoverFill then
        frame.HoverFill:SetColorTexture(tint[1], tint[2], tint[3], 0)
    end
    if frame.HoverOutline then
        frame.HoverOutline:SetColorTexture(tint[1], tint[2], tint[3], active and 0.22 or 0)
    end
    if frame.HoverOutlineBottom then
        frame.HoverOutlineBottom:SetColorTexture(tint[1], tint[2], tint[3], active and 0.18 or 0)
    end
end

local function HookInteractiveHover(frame)
    if frame.__hoverHooksApplied then
        return
    end

    frame:HookScript("OnEnter", function(self)
        local tint = self.__tint or { 0.4, 0.4, 0.4 }
        local _, _, surface = GetThemeColors()
        local hovered = MixColor(surface, tint, self.__active and 0.58 or 0.42)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(tint[1], tint[2], tint[3], 0.9)
        end
        if self.SetBackdropColor then
            self:SetBackdropColor(hovered[1], hovered[2], hovered[3], self.__active and 0.98 or 0.94)
        end
        if self.LeftAccent then
            self.LeftAccent:SetColorTexture(tint[1], tint[2], tint[3], 1)
            self.LeftAccent:SetWidth(5)
        end
        if self.HoverFill then
            self.HoverFill:SetColorTexture(tint[1], tint[2], tint[3], self.__active and 0.12 or 0.18)
        end
        if self.HoverGlow then
            self.HoverGlow:SetColorTexture(tint[1], tint[2], tint[3], self.__active and 0.24 or 0.2)
        end
        if self.HoverOutline then
            self.HoverOutline:SetColorTexture(tint[1], tint[2], tint[3], 0.95)
        end
        if self.HoverOutlineBottom then
            self.HoverOutlineBottom:SetColorTexture(tint[1], tint[2], tint[3], 0.72)
        end
    end)

    frame:HookScript("OnLeave", function(self)
        SetInteractiveState(self, self.__tint or { 0.4, 0.4, 0.4 }, self.__active)
    end)

    frame.__hoverHooksApplied = true
end

local function SortSources(a, b)
    if a == "All" then
        return true
    end
    if b == "All" then
        return false
    end
    if a == "Tier Sets" then
        return true
    end
    if b == "Tier Sets" then
        return false
    end
    return a < b
end

local function ItemFitsSlot(itemID, slotID)
    if not itemID or not slotID then
        return false
    end

    local _, _, _, itemEquipLoc = C_Item.GetItemInfoInstant(itemID)
    if not itemEquipLoc or itemEquipLoc == "" then
        return false
    end

    local allowedSlots = EQUIP_TO_SLOTS[itemEquipLoc]
    return allowedSlots and allowedSlots[slotID] == true or false
end

local function ResolveItemID(text)
    local trimmed = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return nil
    end

    local directLink = trimmed:match("item:(%d+)")
    if directLink then
        return tonumber(directLink)
    end

    local fromWowhead = trimmed:match("item=(%d+)") or trimmed:match("/item/(%d+)") or trimmed:match("/item=(%d+)")
    if fromWowhead then
        return tonumber(fromWowhead)
    end

    local numeric = tonumber(trimmed)
    if numeric then
        return numeric
    end

    local _, itemLink = C_Item.GetItemInfo(trimmed)
    if type(itemLink) == "string" then
        local fromLink = itemLink:match("item:(%d+)")
        if fromLink then
            return tonumber(fromLink)
        end
    end

    return nil
end

local function GetSpecLabel()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" or type(GetSpecializationInfoByID) ~= "function" then
        return "Unknown Specialization"
    end

    local specIndex = GetSpecialization()
    if not specIndex then
        return "Unknown Specialization"
    end

    local specID = GetSpecializationInfo(specIndex)
    local name
    if specID then
        _, name = GetSpecializationInfoByID(specID)
    end
    return type(name) == "string" and name ~= "" and name or "Unknown Specialization"
end

---@class BestInSlotFrame
---@field frame Frame|nil
---@field Tabs any
local BISFrame = BIS.Frame or {}
BIS.Frame = BISFrame
BISFrame.Tabs = BISFrame.Tabs or {}

function BISFrame:GetSelectedDB()
    return BIS.GetBestInSlotItemDB()
end

function BISFrame:GetSelectedItem(slotID)
    return self:GetSelectedDB()[slotID]
end

function BISFrame:GetTooltipItemReference(itemID)
    if not itemID then
        return nil, nil
    end

    local owned, _, _, ownedLink = BIS.ItemScanner.PlayerOwnsItem(itemID)
    if owned and ownedLink then
        return itemID, ownedLink
    end

    local _, itemLink = C_Item.GetItemInfo(itemID)
    return itemID, itemLink
end

function BISFrame:GetSlotDefinition(slotID)
    for _, slotData in ipairs(SLOT_DEFINITIONS) do
        if slotData.slotID == slotID then
            return slotData
        end
    end
    return SLOT_DEFINITIONS[1]
end

function BISFrame:GetCacheVersionLabel()
    local charDB = BIS.GetCharacterBISDB()
    return charDB.CacheGameVersion or "Unknown Cache"
end

function BISFrame:GetSelectedSlotCount()
    local count = 0
    for _, item in pairs(self:GetSelectedDB()) do
        if item and item.itemID then
            count = count + 1
        end
    end
    return count
end

function BISFrame:GetCollectedSelectedCount()
    local count = 0

    for _, item in pairs(self:GetSelectedDB()) do
        if item and item.itemID then
            local owned = BIS.ItemScanner and BIS.ItemScanner.PlayerOwnsItem and
                BIS.ItemScanner.PlayerOwnsItem(item.itemID)
            if owned then
                count = count + 1
            end
        end
    end

    return count
end

function BISFrame:RequestItemInfo(itemID, callback)
    if type(callback) ~= "function" or type(itemID) ~= "number" then
        return
    end

    local itemName, itemLink, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
    if itemName then
        callback(itemName, itemLink, itemQuality, itemTexture)
        return
    end

    if not _G.Item or type(_G.Item.CreateFromItemID) ~= "function" then
        callback(nil, nil, nil, nil)
        return
    end

    local item = _G.Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        local loadedName, loadedLink, loadedQuality, _, _, _, _, _, _, loadedTexture = C_Item.GetItemInfo(itemID)
        callback(loadedName, loadedLink, loadedQuality, loadedTexture)
    end)
end

function BISFrame:BuildSlotCatalog(slotID)
    if type(slotID) ~= "number" then
        return { sources = {}, itemsBySource = {}, total = 0 }
    end

    self.FilteredCatalogBySlot = self.FilteredCatalogBySlot or {}
    if self.FilteredCatalogBySlot[slotID] then
        return self.FilteredCatalogBySlot[slotID]
    end

    local cache = BIS.GetItemCache() or {}
    local instanceLoot = cache.InstanceLoot or {}
    local itemsBySource = {}
    local primarySourceByItemID = {}
    local sources = {}
    local total = 0

    for sourceName, itemList in pairs(instanceLoot) do
        local filtered = {}
        for _, itemID in ipairs(itemList) do
            if ItemFitsSlot(itemID, slotID) then
                filtered[#filtered + 1] = itemID
            end
        end

        if #filtered > 0 then
            itemsBySource[sourceName] = filtered
            sources[#sources + 1] = { name = sourceName, count = #filtered }
            total = total + #filtered
        end
    end

    local selected = self:GetSelectedItem(slotID)
    if selected and selected.itemID then
        local sourceName = selected.sourceInstance or "Custom"
        if not itemsBySource[sourceName] then
            itemsBySource[sourceName] = { selected.itemID }
            sources[#sources + 1] = { name = sourceName, count = 1, isManual = true }
            total = total + 1
        else
            local alreadyPresent = false
            for _, existingItemID in ipairs(itemsBySource[sourceName]) do
                if existingItemID == selected.itemID then
                    alreadyPresent = true
                    break
                end
            end

            if not alreadyPresent then
                table.insert(itemsBySource[sourceName], 1, selected.itemID)
                for _, sourceData in ipairs(sources) do
                    if sourceData.name == sourceName then
                        sourceData.count = sourceData.count + 1
                        break
                    end
                end
                total = total + 1
            end
        end
    end

    table.sort(sources, function(left, right)
        return SortSources(left.name, right.name)
    end)

    for _, sourceData in ipairs(sources) do
        local sourceName = sourceData.name
        for _, itemID in ipairs(itemsBySource[sourceName] or {}) do
            if not primarySourceByItemID[itemID] then
                primarySourceByItemID[itemID] = sourceName
            end
        end
    end

    if total > 0 then
        local allItems = {}
        local seen = {}

        for _, sourceData in ipairs(sources) do
            if sourceData.name ~= "All" then
                for _, itemID in ipairs(itemsBySource[sourceData.name] or {}) do
                    if not seen[itemID] then
                        seen[itemID] = true
                        allItems[#allItems + 1] = itemID
                    end
                end
            end
        end

        if #allItems > 0 then
            itemsBySource.All = allItems
            table.insert(sources, 1, { name = "All", count = #allItems, isAggregate = true })
        end
    end

    local catalog = {
        sources = sources,
        itemsBySource = itemsBySource,
        primarySourceByItemID = primarySourceByItemID,
        total = total,
    }

    self.FilteredCatalogBySlot[slotID] = catalog
    return catalog
end

function BISFrame:GetResolvedSourceForItem(slotID, itemID, browseSource)
    if not itemID then
        return browseSource
    end

    if browseSource and browseSource ~= "All" then
        return browseSource
    end

    local catalog = self:BuildSlotCatalog(slotID)
    return (catalog.primarySourceByItemID and catalog.primarySourceByItemID[itemID]) or browseSource or "Custom"
end

function BISFrame:GetSourceCoverageStats()
    local coverage = {}

    for _, slotData in ipairs(SLOT_DEFINITIONS) do
        local catalog = self:BuildSlotCatalog(slotData.slotID)
        for sourceName, itemList in pairs(catalog.itemsBySource or {}) do
            if type(itemList) == "table" and #itemList > 0 then
                local bucket = coverage[sourceName]
                if not bucket then
                    bucket = { slotCount = 0, itemCount = 0, selectedCount = 0 }
                    coverage[sourceName] = bucket
                end

                bucket.slotCount = bucket.slotCount + 1
                bucket.itemCount = bucket.itemCount + #itemList
            end
        end
    end

    for _, selected in pairs(self:GetSelectedDB()) do
        if selected and selected.itemID and selected.sourceInstance then
            local bucket = coverage[selected.sourceInstance]
            if not bucket then
                bucket = { slotCount = 0, itemCount = 0, selectedCount = 0 }
                coverage[selected.sourceInstance] = bucket
            end
            bucket.selectedCount = bucket.selectedCount + 1
        end
    end

    return coverage
end

function BISFrame:GetSelectedSourcePriorityEntries()
    local entries = {}
    local selectedDB = self:GetSelectedDB()
    local curatedTotal = self:GetSelectedSlotCount()
    local grouped = {}

    for slotID, selected in pairs(selectedDB) do
        if selected and selected.itemID and selected.sourceInstance and selected.sourceInstance ~= "Custom" then
            local sourceName = selected.sourceInstance
            local entry = grouped[sourceName]
            if not entry then
                entry = {
                    name = sourceName,
                    itemCount = 0,
                    slotNames = {},
                }
                grouped[sourceName] = entry
            end

            entry.itemCount = entry.itemCount + 1
            entry.slotNames[#entry.slotNames + 1] = self:GetSlotDefinition(slotID).name
        end
    end

    for _, entry in pairs(grouped) do
        table.sort(entry.slotNames)
        entry.slotCount = #entry.slotNames
        entry.totalSelected = curatedTotal
        entry.coverageRatio = curatedTotal > 0 and (entry.slotCount / curatedTotal) or 0
        entry.score = (entry.slotCount * 100) + entry.itemCount
        entries[#entries + 1] = entry
    end

    for _, entry in ipairs(entries) do
        entry.detailText = table.concat(entry.slotNames, ", ")
    end

    table.sort(entries, function(left, right)
        if left.score == right.score then
            return left.name < right.name
        end
        return left.score > right.score
    end)

    return entries
end

function BISFrame:InvalidateCatalog()
    self.FilteredCatalogBySlot = {}
end

function BISFrame:SelectSlot(slotID)
    self.SelectedSlotID = slotID or SLOT_DEFINITIONS[1].slotID
    local selected = self:GetSelectedItem(self.SelectedSlotID)
    local catalog = self:BuildSlotCatalog(self.SelectedSlotID)

    self.BrowseSource = nil
    if selected and selected.sourceInstance and catalog.itemsBySource[selected.sourceInstance] then
        self.BrowseSource = selected.sourceInstance
    elseif catalog.sources[1] then
        self.BrowseSource = catalog.sources[1].name
    end

    self:RefreshAllVisuals()
end

function BISFrame:SelectSource(sourceName)
    self.BrowseSource = sourceName
    self:RefreshSources()
    self:RefreshItems()
end

function BISFrame:EnsureBrowseSource()
    local catalog = self:BuildSlotCatalog(self.SelectedSlotID)
    if self.BrowseSource and catalog.itemsBySource[self.BrowseSource] then
        return
    end

    self.BrowseSource = catalog.sources[1] and catalog.sources[1].name or nil
end

function BISFrame:SaveSelection(itemID, sourceName)
    if not self.SelectedSlotID or not itemID then
        return
    end

    local resolvedSourceName = self:GetResolvedSourceForItem(self.SelectedSlotID, itemID, sourceName)

    self:GetSelectedDB()[self.SelectedSlotID] = {
        slotID = self.SelectedSlotID,
        itemID = itemID,
        sourceInstance = resolvedSourceName,
    }

    self:RefreshAllVisuals()
end

function BISFrame:ClearSelection()
    if not self.SelectedSlotID then
        return
    end

    self:GetSelectedDB()[self.SelectedSlotID] = nil
    self:RefreshAllVisuals()
end

function BISFrame:UpdateHeader()
    if not self.frame then
        return
    end

    local slotData = self:GetSlotDefinition(self.SelectedSlotID or SLOT_DEFINITIONS[1].slotID)
    local catalog = self:BuildSlotCatalog(slotData.slotID)
    local curatedCount = self:GetSelectedSlotCount()
    local collectedCount = self:GetCollectedSelectedCount()
    local cacheNeedsRefresh = BIS.ItemScanner and BIS.ItemScanner.DoesCacheRequireRefresh and
        BIS.ItemScanner.DoesCacheRequireRefresh()
    self.frame.SpecValue:SetText(GetSpecLabel())
    SetMetricBar(self.frame.CacheBar, cacheNeedsRefresh and 0.18 or 1, cacheNeedsRefresh and "Rebuild" or "Ready")
    SetMetricBarStatus(self.frame.CacheBar, cacheNeedsRefresh and SECTION_TINTS.sources or SECTION_TINTS.slots,
        cacheNeedsRefresh and "Stale" or "OK")
    SetMetricBar(self.frame.SelectionBar, curatedCount > 0 and (collectedCount / curatedCount) or 0,
        string.format("%d / %d collected", collectedCount, curatedCount))
    if self.frame.ActionHint then
        self.frame.ActionHint:SetText(string.format(
            "Current slot: %s. Custom Item accepts an item ID, item name, in-game item link, or Wowhead link.", slotData
            .name))
    end
    if self.frame.TierHint then
        local hasTierSets = catalog.itemsBySource["Tier Sets"] ~= nil and #catalog.itemsBySource["Tier Sets"] > 0
        if IsTierSlot(slotData.slotID) and not hasTierSets then
            self.frame.TierHint:SetText(
                "Tier pieces are missing for this slot. Use Rebuild Cache to rescan Loot Journal sets.")
            self.frame.TierHint:Show()
        else
            self.frame.TierHint:Hide()
        end
    end
end

function BISFrame:UpdateStatusBar()
    if not self.frame or not self.frame.StatusText then
        return
    end

    local slotData = self:GetSlotDefinition(self.SelectedSlotID or SLOT_DEFINITIONS[1].slotID)
    local selected = self:GetSelectedItem(slotData.slotID)
    local sourceText = self.BrowseSource or "No source selected"
    if selected and selected.sourceInstance then
        self.frame.StatusText:SetText(string.format("Browsing %s for %s. Curated source: %s.", sourceText, slotData.name,
            selected.sourceInstance))
    else
        self.frame.StatusText:SetText(string.format("Browsing %s for %s. No item curated for this slot yet.", sourceText,
            slotData.name))
    end
end

function BISFrame:CreateSlotCard(index)
    local card = CreateFrame("Button", nil, self.frame.SlotContent, "BackdropTemplate")
    card:SetSize(220, 58)
    ApplyInteractiveChrome(card, SECTION_TINTS.slots)
    HookInteractiveHover(card)

    card.IconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
    card.IconFrame:SetPoint("LEFT", card, "LEFT", 10, 0)
    card.IconFrame:SetSize(40, 40)
    ApplyBackdrop(card.IconFrame, { 0.08, 0.09, 0.12 }, { 0.24, 0.26, 0.32 }, 0.96, 0.2)

    card.Icon = card.IconFrame:CreateTexture(nil, "ARTWORK")
    card.Icon:SetPoint("CENTER", card.IconFrame, "CENTER", 0, 0)
    card.Icon:SetSize(34, 34)
    card.Icon:SetTexCoord(unpack(TEX_COORDS))

    card.Name = CreateText(card, "OVERLAY", 12, "OUTLINE", { 1, 0.96, 0.9 })
    card.Name:SetPoint("TOPLEFT", card.IconFrame, "TOPRIGHT", 10, -10)
    card.Name:SetPoint("RIGHT", card, "RIGHT", -56, 0)
    card.Name:SetJustifyH("LEFT")
    ConfigureSingleLine(card.Name)

    card.Detail = CreateText(card, "OVERLAY", 10, "", { 0.68, 0.72, 0.8 })
    card.Detail:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -3)
    card.Detail:SetPoint("RIGHT", card, "RIGHT", -56, 0)
    card.Detail:SetJustifyH("LEFT")
    ConfigureSingleLine(card.Detail)

    card.Badge = CreateChip(card, 46)
    card.Badge:SetPoint("RIGHT", card, "RIGHT", -10, 0)

    card.HoverHint = CreateText(card, "OVERLAY", 9, "OUTLINE", { 0.86, 0.92, 0.98 })
    card.HoverHint:SetPoint("RIGHT", card.Badge, "LEFT", -8, 0)
    card.HoverHint:SetText("BROWSE")
    card.HoverHint:SetAlpha(0)

    card.IconHoverGlow = card.IconFrame:CreateTexture(nil, "ARTWORK")
    card.IconHoverGlow:SetPoint("TOPLEFT", card.IconFrame, "TOPLEFT", 1, -1)
    card.IconHoverGlow:SetPoint("BOTTOMRIGHT", card.IconFrame, "BOTTOMRIGHT", -1, 1)
    card.IconHoverGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    card.IconHoverGlow:SetColorTexture(SECTION_TINTS.slots[1], SECTION_TINTS.slots[2], SECTION_TINTS.slots[3], 0)

    card.SlotHoverIn = card:CreateAnimationGroup()
    local slotHintIn = card.SlotHoverIn:CreateAnimation("Alpha")
    slotHintIn:SetChildKey("HoverHint")
    slotHintIn:SetFromAlpha(0)
    slotHintIn:SetToAlpha(1)
    slotHintIn:SetDuration(0.12)
    local slotGlowIn = card.SlotHoverIn:CreateAnimation("Alpha")
    slotGlowIn:SetChildKey("IconHoverGlow")
    slotGlowIn:SetFromAlpha(0)
    slotGlowIn:SetToAlpha(0.22)
    slotGlowIn:SetDuration(0.12)

    card.SlotHoverOut = card:CreateAnimationGroup()
    local slotHintOut = card.SlotHoverOut:CreateAnimation("Alpha")
    slotHintOut:SetChildKey("HoverHint")
    slotHintOut:SetFromAlpha(1)
    slotHintOut:SetToAlpha(0)
    slotHintOut:SetDuration(0.12)
    local slotGlowOut = card.SlotHoverOut:CreateAnimation("Alpha")
    slotGlowOut:SetChildKey("IconHoverGlow")
    slotGlowOut:SetFromAlpha(0.22)
    slotGlowOut:SetToAlpha(0)
    slotGlowOut:SetDuration(0.12)

    card.CollectedGlow = card.IconFrame:CreateTexture(nil, "BORDER")
    card.CollectedGlow:SetPoint("TOPLEFT", card.IconFrame, "TOPLEFT", 1, -1)
    card.CollectedGlow:SetPoint("BOTTOMRIGHT", card.IconFrame, "BOTTOMRIGHT", -1, 1)
    card.CollectedGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    card.CollectedGlow:SetColorTexture(0.28, 0.82, 0.58, 0)

    card.CollectedBadge = CreateText(card.IconFrame, "OVERLAY", 11, "", { 0.92, 1, 0.94 })
    card.CollectedBadge:SetPoint("BOTTOMRIGHT", card.IconFrame, "BOTTOMRIGHT", -2, 2)
    card.CollectedBadge:SetText("")

    card:SetScript("OnClick", function(button)
        self:SelectSlot(button.slotID)
    end)
    card:SetScript("OnEnter", function(button)
        local selected = self:GetSelectedItem(button.slotID)
        if not selected or not selected.itemID then
            return
        end

        local tooltipItemID, tooltipLink = self:GetTooltipItemReference(selected.itemID)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if TooltipSetItem(tooltipItemID, tooltipLink) then
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    card:HookScript("OnEnter", function(button)
        if button.SlotHoverOut and button.SlotHoverOut:IsPlaying() then
            button.SlotHoverOut:Stop()
        end
        if button.SlotHoverIn then
            button.SlotHoverIn:Play()
        end
    end)
    card:HookScript("OnLeave", function(button)
        if button.SlotHoverIn and button.SlotHoverIn:IsPlaying() then
            button.SlotHoverIn:Stop()
        end
        if button.SlotHoverOut then
            button.SlotHoverOut:Play()
        end
    end)

    self.frame.SlotCards[index] = card
    return card
end

function BISFrame:CreateSourceCard(index)
    local card = CreateFrame("Button", nil, self.frame.SourceContent, "BackdropTemplate")
    card:SetSize(280, 60)
    ApplyInteractiveChrome(card, SECTION_TINTS.sources)
    HookInteractiveHover(card)

    card.Name = CreateText(card, "OVERLAY", 13, "OUTLINE", { 1, 0.96, 0.9 })
    card.Name:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -11)
    card.Name:SetPoint("RIGHT", card, "RIGHT", -70, 0)
    card.Name:SetJustifyH("LEFT")
    ConfigureSingleLine(card.Name)

    card.Detail = CreateText(card, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    card.Detail:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -4)
    card.Detail:SetPoint("RIGHT", card, "RIGHT", -70, 0)
    card.Detail:SetJustifyH("LEFT")
    ConfigureSingleLine(card.Detail)

    card.Badge = CreateChip(card, 52)
    card.Badge:SetPoint("RIGHT", card, "RIGHT", -12, 0)

    card:SetScript("OnClick", function(button)
        self:SelectSource(button.sourceName)
    end)
    card:SetScript("OnEnter", function(button)
        if not button.tooltipText then
            return
        end

        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(button.tooltipText, 1, 0.95, 0.84, 1, true)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.frame.SourceCards[index] = card
    return card
end

function BISFrame:CreatePriorityCard(index)
    local card = CreateFrame("Button", nil, self.frame.PriorityContent, "BackdropTemplate")
    card:SetSize(280, 64)
    ApplyInteractiveChrome(card, SECTION_TINTS.sources)
    HookInteractiveHover(card)

    card.Rank = CreateText(card, "OVERLAY", 18, "", { 0.96, 0.86, 0.62 })
    card.Rank:SetPoint("LEFT", card, "LEFT", 12, 0)

    card.Name = CreateText(card, "OVERLAY", 13, "OUTLINE", { 1, 0.96, 0.9 })
    card.Name:SetPoint("TOPLEFT", card.Rank, "TOPRIGHT", 12, 11)
    card.Name:SetPoint("RIGHT", card, "RIGHT", -70, 0)
    ConfigureSingleLine(card.Name)

    card.Detail = CreateText(card, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    card.Detail:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -4)
    card.Detail:SetPoint("RIGHT", card, "RIGHT", -70, 0)
    ConfigureSingleLine(card.Detail)

    card.CoverageLabel = CreateText(card, "OVERLAY", 9, "", { 0.72, 0.76, 0.84 })
    card.CoverageLabel:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 11)

    card.CoverageBar = CreateInlineBar(card, 154, 7, SECTION_TINTS.sources)
    card.CoverageBar:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 44, 12)

    card.Badge = CreateChip(card, 48)
    card.Badge:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -10)

    card:SetScript("OnEnter", function(button)
        if not button.tooltipText then
            return
        end

        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(button.tooltipText, 1, 0.95, 0.84, 1, true)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.frame.PriorityCards[index] = card
    return card
end

function BISFrame:CreateItemCard(index)
    local card = CreateFrame("Button", nil, self.frame.ItemContent, "BackdropTemplate")
    card:SetSize(1, 74)
    ApplyInteractiveChrome(card, SECTION_TINTS.items)
    HookInteractiveHover(card)

    card.IconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
    card.IconFrame:SetPoint("LEFT", card, "LEFT", 12, 0)
    card.IconFrame:SetSize(50, 50)
    ApplyBackdrop(card.IconFrame, { 0.08, 0.09, 0.12 }, { 0.24, 0.26, 0.32 }, 0.96, 0.22)

    card.Icon = card.IconFrame:CreateTexture(nil, "ARTWORK")
    card.Icon:SetPoint("CENTER", card.IconFrame, "CENTER", 0, 0)
    card.Icon:SetSize(42, 42)
    card.Icon:SetTexCoord(unpack(TEX_COORDS))

    card.Name = CreateText(card, "OVERLAY", 13, "OUTLINE", { 1, 0.96, 0.9 })
    card.Name:SetPoint("TOPLEFT", card.IconFrame, "TOPRIGHT", 12, -12)
    card.Name:SetPoint("RIGHT", card, "RIGHT", -140, 0)
    card.Name:SetJustifyH("LEFT")
    ConfigureSingleLine(card.Name)

    card.Detail = CreateText(card, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    card.Detail:SetPoint("TOPLEFT", card.Name, "BOTTOMLEFT", 0, -4)
    card.Detail:SetPoint("RIGHT", card, "RIGHT", -140, 0)
    card.Detail:SetJustifyH("LEFT")
    ConfigureSingleLine(card.Detail)

    card.Meta = CreateText(card, "OVERLAY", 10, "OUTLINE", { 0.64, 0.82, 0.82 })
    card.Meta:SetPoint("TOPLEFT", card.Detail, "BOTTOMLEFT", 0, -4)
    card.Meta:SetPoint("RIGHT", card, "RIGHT", -140, 0)
    card.Meta:SetJustifyH("LEFT")
    ConfigureSingleLine(card.Meta)

    card.SelectChip = CreateChip(card, 66)
    card.SelectChip:SetPoint("RIGHT", card, "RIGHT", -12, 12)

    card.ClearButton = CreateMiniActionButton(card, "Clear", 50, 20, SECTION_TINTS.sources, function()
        self:ClearSelection()
    end)
    card.ClearButton:SetPoint("RIGHT", card, "RIGHT", -12, 12)
    card.ClearButton:Hide()

    card.StateChip = CreateChip(card, 92)
    card.StateChip:SetPoint("RIGHT", card, "RIGHT", -12, -12)

    card:SetScript("OnClick", function(button)
        self:SaveSelection(button.itemID, self.BrowseSource)
    end)
    card:SetScript("OnEnter", function(button)
        if not button.itemID then
            return
        end

        local tooltipItemID, tooltipLink = self:GetTooltipItemReference(button.itemID)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        if TooltipSetItem(tooltipItemID, tooltipLink) then
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    card:HookScript("OnEnter", function(button)
        if button.isSelected then
            button.SelectChip:Hide()
            button.ClearButton:Show()
        end
    end)
    card:HookScript("OnLeave", function(button)
        button.ClearButton:Hide()
        button.SelectChip:Show()
    end)

    self.frame.ItemCards[index] = card
    return card
end

function BISFrame:RefreshSlots()
    local selectedSlotID = self.SelectedSlotID or SLOT_DEFINITIONS[1].slotID
    self.frame.SlotHeaderValue:SetText(string.format("%d curated", self:GetSelectedSlotCount()))

    for index, slotData in ipairs(SLOT_DEFINITIONS) do
        local card = self.frame.SlotCards[index] or self:CreateSlotCard(index)
        local selected = self:GetSelectedItem(slotData.slotID)
        local isActive = slotData.slotID == selectedSlotID

        card.slotID = slotData.slotID
        card:SetPoint("TOPLEFT", self.frame.SlotContent, "TOPLEFT", 0, -((index - 1) * 66))
        card:SetPoint("RIGHT", self.frame.SlotContent, "RIGHT", -6, 0)
        card:Show()

        card.Icon:SetTexture(slotData.texture)
        card.Name:SetText(slotData.name)
        card.HoverHint:SetText(isActive and "ACTIVE" or "BROWSE")

        if selected and selected.itemID then
            card.Detail:SetText(selected.sourceInstance or "Curated")
            local owned, equipped = BIS.ItemScanner.PlayerOwnsItem(selected.itemID)
            if equipped then
                SetChip(card.Badge, "EQUIP", { 0.28, 0.82, 0.58 })
                card.CollectedGlow:SetAlpha(0.34)
                card.CollectedBadge:SetText("+")
                card.IconFrame:SetBackdropBorderColor(0.28, 0.82, 0.58, 0.84)
                card.Detail:SetText(string.format("Owned now | %s", selected.sourceInstance or "Curated"))
            elseif owned then
                SetChip(card.Badge, "OWNED", { 0.28, 0.82, 0.58 })
                card.CollectedGlow:SetAlpha(0.28)
                card.CollectedBadge:SetText("+")
                card.IconFrame:SetBackdropBorderColor(0.28, 0.82, 0.58, 0.72)
                card.Detail:SetText(string.format("Collected | %s", selected.sourceInstance or "Curated"))
            else
                SetChip(card.Badge, "SET", SECTION_TINTS.slots)
                card.CollectedGlow:SetAlpha(0)
                card.CollectedBadge:SetText("")
                card.IconFrame:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.2)
            end
            self:RequestItemInfo(selected.itemID, function(itemName, _, itemQuality, itemTexture)
                if card.slotID ~= slotData.slotID then
                    return
                end
                if itemTexture then
                    card.Icon:SetTexture(itemTexture)
                end
                if itemName then
                    card.Name:SetText(itemName)
                end
                if itemQuality then
                    local r, g, b = C_Item.GetItemQualityColor(itemQuality)
                    card.Name:SetTextColor(r, g, b)
                else
                    card.Name:SetTextColor(1, 0.96, 0.9)
                end
            end)
        else
            card.Detail:SetText("No curated target")
            card.Name:SetTextColor(1, 0.96, 0.9)
            SetChip(card.Badge, "OPEN", { 0.42, 0.54, 0.64 })
            card.CollectedGlow:SetAlpha(0)
            card.CollectedBadge:SetText("")
            card.IconFrame:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.2)
        end

        if card.LeftAccent then
            card.LeftAccent:SetColorTexture(SECTION_TINTS.slots[1], SECTION_TINTS.slots[2], SECTION_TINTS.slots[3],
                isActive and 1 or 0.58)
        end

        SetInteractiveState(card, SECTION_TINTS.slots, isActive)
    end

    self.frame.SlotContent:SetHeight(#SLOT_DEFINITIONS * 66)
end

function BISFrame:RefreshSources()
    local catalog = self:BuildSlotCatalog(self.SelectedSlotID)
    local coverage = self:GetSourceCoverageStats()
    self.frame.SourceHeaderValue:SetText(string.format("%d sources", #catalog.sources))

    if self.frame.SourcePanel and self.frame.SourcePanel.Subtitle then
        local bestSourceName, bestSlotCount = nil, 0
        for _, sourceData in ipairs(catalog.sources) do
            local bucket = coverage[sourceData.name]
            local slotCount = bucket and bucket.slotCount or 0
            if slotCount > bestSlotCount then
                bestSlotCount = slotCount
                bestSourceName = sourceData.name
            end
        end
        if bestSourceName then
            self.frame.SourcePanel.Subtitle:SetText(string.format("For %s, %s has the broadest pool of candidate drops.",
                self:GetSlotDefinition(self.SelectedSlotID).name, bestSourceName))
        else
            self.frame.SourcePanel.Subtitle:SetText("Browse every source that can drop upgrades for the selected slot.")
        end
    end

    if self.frame.SourceEmpty then
        self.frame.SourceEmpty:SetShown(#catalog.sources == 0)
    end

    for index, sourceData in ipairs(catalog.sources) do
        local card = self.frame.SourceCards[index] or self:CreateSourceCard(index)
        card.sourceName = sourceData.name
        card:SetPoint("TOPLEFT", self.frame.SourceContent, "TOPLEFT", 0, -((index - 1) * 68))
        card:SetPoint("RIGHT", self.frame.SourceContent, "RIGHT", -6, 0)
        card.Name:SetText(sourceData.name)
        local bucket = coverage[sourceData.name]
        local slotCoverage = bucket and bucket.slotCount or 0
        local selectedCount = bucket and bucket.selectedCount or 0
        if sourceData.isAggregate then
            card.Detail:SetText(string.format("Every candidate for %s in one list",
                self:GetSlotDefinition(self.SelectedSlotID).name))
        elseif sourceData.isManual then
            card.Detail:SetText("Manual or custom curated item source")
        else
            if sourceData.name == "Tier Sets" then
                card.Detail:SetText(string.format("Class set source | %d slots covered", slotCoverage))
            else
                card.Detail:SetText(string.format("%d slots covered | %d curated picks", slotCoverage, selectedCount))
            end
        end
        SetChip(card.Badge, tostring(sourceData.count), SECTION_TINTS.sources)
        SetInteractiveState(card, SECTION_TINTS.sources, self.BrowseSource == sourceData.name)
        if sourceData.isAggregate then
            card.tooltipText = string.format(
                "All\nShows every candidate item available for %s without filtering by source.",
                self:GetSlotDefinition(self.SelectedSlotID).name)
        else
            card.tooltipText = string.format("%s\nThis source can drop %d candidate items for %s.", sourceData.name,
                sourceData.count, self:GetSlotDefinition(self.SelectedSlotID).name)
        end
        card:Show()
    end

    for index = #catalog.sources + 1, #self.frame.SourceCards do
        self.frame.SourceCards[index]:Hide()
    end

    self.frame.SourceContent:SetHeight(math.max(1, #catalog.sources * 68))
end

function BISFrame:RefreshPriorities()
    if not self.frame or not self.frame.PriorityPanel then
        return
    end

    local entries = self:GetSelectedSourcePriorityEntries()
    self.frame.PriorityHeaderValue:SetText(string.format("%d routes", #entries))
    self.frame.PriorityEmpty:SetShown(#entries == 0)

    if self.frame.PriorityPanel.Subtitle then
        if entries[1] then
            self.frame.PriorityPanel.Subtitle:SetText(string.format(
                "Most worth doing now: %s covers %d of your curated slots.", entries[1].name, entries[1].slotCount))
        else
            self.frame.PriorityPanel.Subtitle:SetText(
                "Your current curated plan grouped by source so you can see what is worth doing next.")
        end
    end

    for index, entry in ipairs(entries) do
        local card = self.frame.PriorityCards[index] or self:CreatePriorityCard(index)
        card:SetPoint("TOPLEFT", self.frame.PriorityContent, "TOPLEFT", 0, -((index - 1) * 72))
        card:SetPoint("RIGHT", self.frame.PriorityContent, "RIGHT", -6, 0)
        card.Rank:SetText(index < 10 and ("0" .. index) or tostring(index))
        card.Name:SetText(entry.name)
        card.Detail:SetText(entry.detailText)
        card.CoverageLabel:SetText(string.format("%d/%d", entry.slotCount, entry.totalSelected))
        SetInlineBar(card.CoverageBar, entry.coverageRatio)
        SetChip(card.Badge, tostring(entry.slotCount), SECTION_TINTS.sources)
        SetInteractiveState(card, SECTION_TINTS.sources, false)
        card.tooltipText = string.format("%s\nCurrently worth doing for %d curated slots: %s.", entry.name,
            entry.itemCount, entry.detailText)
        card:Show()
    end

    for index = #entries + 1, #self.frame.PriorityCards do
        self.frame.PriorityCards[index]:Hide()
    end

    self.frame.PriorityContent:SetHeight(math.max(1, #entries * 72))
end

function BISFrame:RefreshDetail()
    if not self.frame or not self.frame.DetailName or not self.frame.DetailIcon then
        return
    end

    local slotData = self:GetSlotDefinition(self.SelectedSlotID)
    local selected = self:GetSelectedItem(slotData.slotID)

    self.frame.DetailTitle:SetText(slotData.name)
    if self.frame.DetailSubtitle then
        self.frame.DetailSubtitle:SetText("Curated target")
    end
    self.frame.DetailSlotText:SetText(slotData.name)
    self.frame.DetailSourceText:SetText(selected and selected.sourceInstance or "No source saved")

    if not selected or not selected.itemID then
        self.frame.DetailIcon:SetTexture(slotData.texture)
        self.frame.DetailName:SetText("No item curated")
        self.frame.DetailName:SetTextColor(1, 0.96, 0.9)
        self.frame.DetailMeta:SetText("Select a source and click a candidate to lock in your chase piece.")
        self.frame.DetailStatus:SetText("This slot is still open.")
        SetChip(self.frame.DetailChipOne, "OPEN", { 0.42, 0.54, 0.64 })
        SetChip(self.frame.DetailChipTwo, "UNSET", { 0.36, 0.36, 0.36 })
        return
    end

    self.frame.DetailIcon:SetTexture(EMPTY_ICON)
    self.frame.DetailName:SetText("Loading item...")
    self.frame.DetailName:SetTextColor(1, 0.96, 0.9)

    local owned, equipped, itemLevel, ownedLink, trackRank = BIS.ItemScanner.PlayerOwnsItem(selected.itemID)
    local trackText = FormatTrack(trackRank)

    if owned then
        if equipped then
            self.frame.DetailStatus:SetText(string.format("Owned and equipped%s.",
                itemLevel and (" at item level " .. itemLevel) or ""))
            SetChip(self.frame.DetailChipOne, "EQUIPPED", SECTION_TINTS.slots)
        else
            self.frame.DetailStatus:SetText(string.format("Owned in bags%s.",
                itemLevel and (" at item level " .. itemLevel) or ""))
            SetChip(self.frame.DetailChipOne, "OWNED", SECTION_TINTS.slots)
        end
        SetChip(self.frame.DetailChipTwo, trackText or "TRACKED", SECTION_TINTS.detail)
    else
        self.frame.DetailStatus:SetText("Not currently owned on this character.")
        SetChip(self.frame.DetailChipOne, "CHASE", SECTION_TINTS.sources)
        SetChip(self.frame.DetailChipTwo, selected.sourceInstance or "SOURCE", SECTION_TINTS.detail)
    end

    self:RequestItemInfo(selected.itemID, function(itemName, _, itemQuality, itemTexture)
        if not self.frame then
            return
        end
        local current = self:GetSelectedItem(slotData.slotID)
        if not current or current.itemID ~= selected.itemID then
            return
        end

        self.frame.DetailIcon:SetTexture(itemTexture or slotData.texture)
        self.frame.DetailName:SetText(itemName or "Unknown Item")
        if itemQuality then
            local r, g, b = C_Item.GetItemQualityColor(itemQuality)
            self.frame.DetailName:SetTextColor(r, g, b)
        else
            self.frame.DetailName:SetTextColor(1, 0.96, 0.9)
        end

        local itemTypeName, itemSubTypeName, _, _, equipLoc = C_Item.GetItemInfoInstant(selected.itemID)
        local equipText = equipLoc and equipLoc ~= "" and (_G[equipLoc] or itemSubTypeName or itemTypeName) or
            itemSubTypeName or itemTypeName or "Best in Slot item"
        local sourceText = selected.sourceInstance and ("Source: " .. selected.sourceInstance) or "Custom selection"
        self.frame.DetailMeta:SetText(string.format("%s | %s", equipText, sourceText))
    end)
end

function BISFrame:RefreshItems()
    local catalog = self:BuildSlotCatalog(self.SelectedSlotID)
    local items = self.BrowseSource and catalog.itemsBySource[self.BrowseSource] or nil
    items = items or {}

    self.frame.ItemHeaderValue:SetText(string.format("%d candidates", #items))
    self.frame.ItemEmpty:SetShown(#items == 0)

    local selected = self:GetSelectedItem(self.SelectedSlotID)

    for index, itemID in ipairs(items) do
        local card = self.frame.ItemCards[index] or self:CreateItemCard(index)
        local resolvedSourceName = self:GetResolvedSourceForItem(self.SelectedSlotID, itemID, self.BrowseSource)
        card.itemID = itemID
        card.sourceName = resolvedSourceName
        card.isSelected = false
        card:SetPoint("TOPLEFT", self.frame.ItemContent, "TOPLEFT", 0, -((index - 1) * 82))
        card:SetPoint("RIGHT", self.frame.ItemContent, "RIGHT", -6, 0)
        card.Name:SetText("Loading item...")
        card.Detail:SetText(resolvedSourceName or "Unknown source")
        card.Meta:SetText("Collecting item data...")
        card.Icon:SetTexture(EMPTY_ICON)
        card.SelectChip:Show()
        card.ClearButton:Hide()

        local owned, equipped, itemLevel, _, trackRank = BIS.ItemScanner.PlayerOwnsItem(itemID)
        local isSelected = selected and selected.itemID == itemID
        card.isSelected = isSelected

        if isSelected then
            SetChip(card.SelectChip, "SELECTED", SECTION_TINTS.detail)
        else
            SetChip(card.SelectChip, "CURATE", SECTION_TINTS.items)
        end

        if owned then
            local stateText = equipped and "Equipped" or "Owned"
            if itemLevel then
                stateText = string.format("%s %d", stateText, itemLevel)
            end
            if trackRank then
                stateText = string.format("%s %s", stateText, FormatTrack(trackRank) or "")
            end
            SetChip(card.StateChip, stateText, SECTION_TINTS.slots)
        else
            SetChip(card.StateChip, "Not owned", SECTION_TINTS.sources)
        end

        SetInteractiveState(card, SECTION_TINTS.items, isSelected)
        card:Show()

        self:RequestItemInfo(itemID, function(itemName, _, itemQuality, itemTexture)
            if card.itemID ~= itemID then
                return
            end

            card.Icon:SetTexture(itemTexture or EMPTY_ICON)
            card.Name:SetText(itemName or "Unknown Item")
            if itemQuality then
                local r, g, b = C_Item.GetItemQualityColor(itemQuality)
                card.Name:SetTextColor(r, g, b)
                if card.LeftAccent then
                    card.LeftAccent:SetColorTexture(r, g, b, isSelected and 1 or 0.8)
                end
            else
                card.Name:SetTextColor(1, 0.96, 0.9)
            end

            local itemTypeName, itemSubTypeName, _, _, equipLoc = C_Item.GetItemInfoInstant(itemID)
            local equipText = equipLoc and equipLoc ~= "" and (_G[equipLoc] or itemSubTypeName or itemTypeName) or
                itemSubTypeName or itemTypeName or "Loot"
            card.Detail:SetText(string.format("%s | %s", card.sourceName or "Source", equipText))

            if owned then
                local meta = equipped and "Already equipped" or "Already in bags"
                if trackRank then
                    meta = string.format("%s | %s track", meta, FormatTrack(trackRank) or "")
                end
                card.Meta:SetText(meta)
            else
                card.Meta:SetText("Click to save this as the curated target for the slot.")
            end
        end)
    end

    for index = #items + 1, #self.frame.ItemCards do
        self.frame.ItemCards[index]:Hide()
    end

    self.frame.ItemContent:SetHeight(math.max(1, #items * 82))
end

function BISFrame:RefreshAllVisuals()
    if not self.frame then
        return
    end

    self:EnsureBrowseSource()

    self:UpdateHeader()
    self:RefreshSlots()
    self:RefreshSources()
    self:RefreshPriorities()
    self:RefreshDetail()
    self:RefreshItems()
    self:UpdateStatusBar()
end

function BISFrame:ShowCustomItemOverlay()
    if not self.frame then
        return
    end

    local slotData = self:GetSlotDefinition(self.SelectedSlotID or SLOT_DEFINITIONS[1].slotID)
    local selected = self:GetSelectedItem(self.SelectedSlotID)
    self.frame.CustomItemInput:SetText("")
    self.frame.CustomSourceInput:SetText(selected and selected.sourceInstance or "Custom")
    if self.frame.CustomTitle then
        self.frame.CustomTitle:SetText(string.format("Set Custom Item: %s", slotData.name))
    end
    if self.frame.CustomSubtitle then
        self.frame.CustomSubtitle:SetText("Paste an item ID, item name, in-game item link, or Wowhead link.")
    end
    self.frame.CustomFeedback:SetText("Paste a Wowhead link, item link, item ID, or exact item name.")
    self.frame.CustomOverlay:Show()
    self.frame.CustomOverlay:SetAlpha(1)
    if self.frame.CustomModalIn then
        if self.frame.CustomModalIn:IsPlaying() then
            self.frame.CustomModalIn:Stop()
        end
        self.frame.CustomModal:SetAlpha(0)
        self.frame.CustomModalIn:Play()
    else
        self.frame.CustomModal:SetAlpha(1)
    end
    self.frame.CustomItemInput:SetFocus()
end

function BISFrame:HideCustomItemOverlay()
    if self.frame and self.frame.CustomOverlay then
        self.frame.CustomOverlay:Hide()
    end
end

function BISFrame:ApplyCustomItem()
    if not self.frame or not self.SelectedSlotID then
        return
    end

    local itemID = ResolveItemID(self.frame.CustomItemInput:GetText())
    local slotData = self:GetSlotDefinition(self.SelectedSlotID)
    local sourceText = tostring(self.frame.CustomSourceInput:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if not itemID then
        self.frame.CustomFeedback:SetText("Could not resolve an item from that input.")
        return
    end

    if not ItemFitsSlot(itemID, self.SelectedSlotID) then
        self.frame.CustomFeedback:SetText(string.format("That item does not fit the %s slot.", slotData.name))
        return
    end

    self:GetSelectedDB()[self.SelectedSlotID] = {
        slotID = self.SelectedSlotID,
        itemID = itemID,
        sourceInstance = sourceText ~= "" and sourceText or "Custom",
    }

    self:HideCustomItemOverlay()
    self:RefreshAllVisuals()
end

function BISFrame:RefreshCache()
    BIS:ForceRefreshCache()
    self:InvalidateCatalog()
    self:RefreshAllVisuals()
end

function BISFrame:HookDetailTooltip()
    if not self.frame or self.frame.DetailIconFrame.__twichuiTooltipHooked then
        return
    end

    self.frame.DetailIconFrame:EnableMouse(true)
    self.frame.DetailIconFrame:SetScript("OnEnter", function(owner)
        local selected = self.SelectedSlotID and self:GetSelectedItem(self.SelectedSlotID) or nil
        if not selected or not selected.itemID then
            return
        end

        local tooltipItemID, tooltipLink = self:GetTooltipItemReference(selected.itemID)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        if TooltipSetItem(tooltipItemID, tooltipLink) then
            GameTooltip:Show()
        end
    end)
    self.frame.DetailIconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.frame.DetailIconFrame.__twichuiTooltipHooked = true
end

function BISFrame:Show()
    if not self.frame then
        self:Create()
    end

    self:InvalidateCatalog()
    if not self.SelectedSlotID then
        self.SelectedSlotID = SLOT_DEFINITIONS[1].slotID
    end

    if not self.BrowseSource then
        local catalog = self:BuildSlotCatalog(self.SelectedSlotID)
        self.BrowseSource = catalog.sources[1] and catalog.sources[1].name or nil
    end

    self.frame:Show()
    self.frame:Raise()
    if self.frame.IntroAnimation then
        if self.frame.IntroAnimation:IsPlaying() then
            self.frame.IntroAnimation:Stop()
        end
        self.frame:SetAlpha(0)
        self.frame.IntroAnimation:Play()
    else
        self.frame:SetAlpha(1)
    end

    if BIS.ItemScanner and BIS.ItemScanner.DoesCacheRequireRefresh and BIS.ItemScanner.DoesCacheRequireRefresh() then
        self:RefreshCache()
    end

    self:RefreshAllVisuals()
end

function BISFrame:Create()
    if self.frame then
        return
    end

    local primary, accent, surface, border = GetThemeColors()

    local frame = CreateFrame("Frame", "TwichUIBestInSlotStudio", UIParent, "BackdropTemplate")
    frame:SetSize(1680, 860)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(180)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    ApplyBackdrop(frame, { surface[1] * 0.72, surface[2] * 0.74, surface[3] * 0.82 }, border, 0.86, 0.26)

    frame.TopAccent = frame:CreateTexture(nil, "ARTWORK")
    frame.TopAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TopAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TopAccent:SetHeight(4)
    frame.TopAccent:SetColorTexture(accent[1], accent[2], accent[3], 0.95)

    frame.InnerGlow = frame:CreateTexture(nil, "BACKGROUND")
    frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.InnerGlow:SetColorTexture(primary[1], primary[2], primary[3], 0.035)

    frame.Header = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.Header:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    frame.Header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    frame.Header:SetHeight(70)
    ApplySectionChrome(frame.Header, SECTION_TINTS.hero)

    frame.HeroTitle = CreateText(frame.Header, "OVERLAY", 22, "", { 1, 0.96, 0.9 })
    frame.HeroTitle:SetPoint("TOPLEFT", frame.Header, "TOPLEFT", 18, -12)
    frame.HeroTitle:SetText("Best in Slot")

    frame.HeroSubtitle = CreateText(frame.Header, "OVERLAY", 11, "", { 0.74, 0.78, 0.84 })
    frame.HeroSubtitle:SetPoint("TOPLEFT", frame.HeroTitle, "BOTTOMLEFT", 0, -4)
    frame.HeroSubtitle:SetPoint("RIGHT", frame.Header, "RIGHT", -440, 0)
    frame.HeroSubtitle:SetJustifyH("LEFT")
    frame.HeroSubtitle:Hide()

    frame.TierHint = CreateText(frame.Header, "OVERLAY", 10, "OUTLINE", { 1, 0.86, 0.58 })
    frame.TierHint:SetJustifyH("LEFT")
    ConfigureSingleLine(frame.TierHint)
    frame.TierHint:Hide()

    frame.SpecValue = CreateText(frame.Header, "OVERLAY", 11, "", { 1, 0.96, 0.9 })
    frame.SpecValue:SetPoint("BOTTOMLEFT", frame.Header, "BOTTOMLEFT", 18, 8)

    frame.CacheBar = CreateMetricBar(frame.Header, 214, primary, "CACHE")
    frame.CacheBar:SetPoint("BOTTOMLEFT", frame.SpecValue, "BOTTOMRIGHT", 18, -2)
    AttachTooltip(frame.CacheBar, "Shows whether your Best in Slot loot cache is current or needs a rebuild.")

    frame.SelectionBar = CreateMetricBar(frame.Header, 214, accent, "PROGRESS")
    frame.SelectionBar:SetPoint("LEFT", frame.CacheBar, "RIGHT", 12, 0)
    AttachTooltip(frame.SelectionBar, "Shows how many slots already have a curated Best in Slot target.")

    frame.TierHint:SetPoint("LEFT", frame.SelectionBar, "RIGHT", 16, 0)
    frame.TierHint:SetPoint("RIGHT", frame.Header, "RIGHT", -48, 0)

    frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinCloseButton then
        T.Tools.UI.SkinCloseButton(frame.CloseButton)
    end

    frame.ActionBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ActionBar:SetPoint("TOPLEFT", frame.Header, "BOTTOMLEFT", 0, -6)
    frame.ActionBar:SetPoint("TOPRIGHT", frame.Header, "BOTTOMRIGHT", 0, -6)
    frame.ActionBar:SetHeight(52)
    ApplyBackdrop(frame.ActionBar, { surface[1] * 0.7, surface[2] * 0.72, surface[3] * 0.82 }, border, 0.38, 0.12)

    frame.ActionBarGlow = frame.ActionBar:CreateTexture(nil, "BACKGROUND")
    frame.ActionBarGlow:SetPoint("TOPLEFT", frame.ActionBar, "TOPLEFT", 1, -1)
    frame.ActionBarGlow:SetPoint("BOTTOMRIGHT", frame.ActionBar, "BOTTOMRIGHT", -1, 1)
    frame.ActionBarGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.ActionBarGlow:SetGradient("HORIZONTAL", CreateColor(accent[1], accent[2], accent[3], 0.08),
        CreateColor(primary[1], primary[2], primary[3], 0.03))

    frame.ActionLabel = CreateText(frame.ActionBar, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    frame.ActionLabel:SetPoint("LEFT", frame.ActionBar, "LEFT", 14, 0)
    frame.ActionLabel:SetText("Actions")

    frame.ActionCustomButton = CreateTwichButton(frame.ActionBar, "Custom Item", 122, 30, accent, function()
        self:ShowCustomItemOverlay()
    end)
    frame.ActionCustomButton:SetPoint("LEFT", frame.ActionLabel, "RIGHT", 16, 0)
    AttachTooltip(frame.ActionCustomButton,
        "Add or replace the current slot with an item ID, item name, item link, or Wowhead URL.")

    frame.ActionUnsetButton = CreateTwichButton(frame.ActionBar, "Unset Slot", 106, 30, SECTION_TINTS.sources, function()
        self:ClearSelection()
    end)
    frame.ActionUnsetButton:SetPoint("LEFT", frame.ActionCustomButton, "RIGHT", 10, 0)
    AttachTooltip(frame.ActionUnsetButton, "Clear the curated item for the currently selected slot.")

    frame.ActionRebuildButton = CreateTwichButton(frame.ActionBar, "Rebuild Cache", 126, 30, primary, function()
        self:RefreshCache()
    end)
    frame.ActionRebuildButton:SetPoint("LEFT", frame.ActionUnsetButton, "RIGHT", 10, 0)
    AttachTooltip(frame.ActionRebuildButton, "Rescan the seasonal loot cache, including tier set data.")

    frame.ActionHint = CreateText(frame.ActionBar, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    frame.ActionHint:SetPoint("LEFT", frame.ActionRebuildButton, "RIGHT", 16, 0)
    frame.ActionHint:SetPoint("RIGHT", frame.ActionBar, "RIGHT", -14, 0)
    frame.ActionHint:SetJustifyH("LEFT")
    frame.ActionHint:SetText("Select a slot, browse its sources, then click an item to save it as your target.")

    frame.Body = CreateFrame("Frame", nil, frame)
    frame.Body:SetPoint("TOPLEFT", frame.ActionBar, "BOTTOMLEFT", 0, -14)
    frame.Body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 44)

    frame.SlotPanel = CreateSection(frame.Body, "Gear Matrix",
        "Pick a slot to review your target and see what is still missing.", SECTION_TINTS.slots)
    frame.SlotPanel:SetPoint("TOPLEFT", frame.Body, "TOPLEFT", 0, 0)
    frame.SlotPanel:SetPoint("BOTTOMLEFT", frame.Body, "BOTTOMLEFT", 0, 0)
    frame.SlotPanel:SetWidth(312)

    frame.SlotHeaderValue = CreateText(frame.SlotPanel, "OVERLAY", 10, "OUTLINE", { 0.72, 0.9, 0.9 })
    frame.SlotHeaderValue:SetPoint("TOPRIGHT", frame.SlotPanel, "TOPRIGHT", -16, -16)

    frame.SlotScrollShell, frame.SlotScroll, frame.SlotContent = CreateScrollShell(frame.SlotPanel.Body,
        SECTION_TINTS.slots)
    frame.SlotScrollShell:SetAllPoints(frame.SlotPanel.Body)
    frame.SlotCards = {}

    frame.MiddleColumn = CreateFrame("Frame", nil, frame.Body)
    frame.MiddleColumn:SetPoint("TOPLEFT", frame.SlotPanel, "TOPRIGHT", 14, 0)
    frame.MiddleColumn:SetPoint("BOTTOMLEFT", frame.Body, "BOTTOMLEFT", 326, 0)
    frame.MiddleColumn:SetWidth(402)

    frame.SourcePanel = CreateSection(frame.MiddleColumn, "Content Sources",
        "Browse every source that can drop upgrades for the selected slot.", SECTION_TINTS.sources)
    frame.SourcePanel:SetPoint("TOPLEFT", frame.MiddleColumn, "TOPLEFT", 0, 0)
    frame.SourcePanel:SetPoint("TOPRIGHT", frame.MiddleColumn, "TOPRIGHT", 0, 0)
    frame.SourcePanel:SetPoint("BOTTOMLEFT", frame.MiddleColumn, "BOTTOMLEFT", 0, 0)
    frame.SourcePanel:SetPoint("BOTTOMRIGHT", frame.MiddleColumn, "BOTTOMRIGHT", 0, 0)

    frame.SourceHeaderValue = CreateText(frame.SourcePanel, "OVERLAY", 10, "OUTLINE", { 0.96, 0.86, 0.62 })
    frame.SourceHeaderValue:SetPoint("TOPRIGHT", frame.SourcePanel, "TOPRIGHT", -16, -16)

    frame.SourceScrollShell, frame.SourceScroll, frame.SourceContent = CreateScrollShell(frame.SourcePanel.Body,
        SECTION_TINTS.sources)
    frame.SourceScrollShell:SetAllPoints(frame.SourcePanel.Body)
    frame.SourceCards = {}
    frame.SourceEmpty = CreateText(frame.SourcePanel.Body, "OVERLAY", 11, "", { 0.72, 0.76, 0.84 })
    frame.SourceEmpty:SetPoint("CENTER", frame.SourcePanel.Body, "CENTER", 0, 0)
    frame.SourceEmpty:SetText("No sources currently match this slot.")
    frame.SourceEmpty:Hide()

    frame.PlannerColumn = CreateFrame("Frame", nil, frame.Body)
    frame.PlannerColumn:SetPoint("TOPRIGHT", frame.Body, "TOPRIGHT", 0, 0)
    frame.PlannerColumn:SetPoint("BOTTOMRIGHT", frame.Body, "BOTTOMRIGHT", 0, 0)
    frame.PlannerColumn:SetWidth(320)

    frame.PriorityPanel = CreateSection(frame.PlannerColumn, "Worth Running",
        "Your current curated plan grouped by source so you can see what is worth doing next.", SECTION_TINTS.sources)
    frame.PriorityPanel:SetPoint("TOPLEFT", frame.PlannerColumn, "TOPLEFT", 0, 0)
    frame.PriorityPanel:SetPoint("TOPRIGHT", frame.PlannerColumn, "TOPRIGHT", 0, 0)
    frame.PriorityPanel:SetPoint("BOTTOMLEFT", frame.PlannerColumn, "BOTTOMLEFT", 0, 0)
    frame.PriorityPanel:SetPoint("BOTTOMRIGHT", frame.PlannerColumn, "BOTTOMRIGHT", 0, 0)

    frame.PriorityHeaderValue = CreateText(frame.PriorityPanel, "OVERLAY", 10, "OUTLINE", { 0.96, 0.86, 0.62 })
    frame.PriorityHeaderValue:SetPoint("TOPRIGHT", frame.PriorityPanel, "TOPRIGHT", -16, -16)

    frame.PriorityScrollShell, frame.PriorityScroll, frame.PriorityContent = CreateScrollShell(frame.PriorityPanel.Body,
        SECTION_TINTS.sources)
    frame.PriorityScrollShell:SetAllPoints(frame.PriorityPanel.Body)
    frame.PriorityCards = {}
    frame.PriorityEmpty = CreateText(frame.PriorityPanel.Body, "OVERLAY", 11, "", { 0.72, 0.76, 0.84 })
    frame.PriorityEmpty:SetPoint("CENTER", frame.PriorityPanel.Body, "CENTER", 0, 0)
    frame.PriorityEmpty:SetText("Curate items first, then this panel will rank the best sources to run.")
    frame.PriorityEmpty:Hide()

    frame.RightColumn = CreateFrame("Frame", nil, frame.Body)
    frame.RightColumn:SetPoint("TOPLEFT", frame.MiddleColumn, "TOPRIGHT", 14, 0)
    frame.RightColumn:SetPoint("BOTTOMLEFT", frame.MiddleColumn, "BOTTOMRIGHT", 14, 0)
    frame.RightColumn:SetPoint("TOPRIGHT", frame.PlannerColumn, "TOPLEFT", -14, 0)
    frame.RightColumn:SetPoint("BOTTOMRIGHT", frame.PlannerColumn, "BOTTOMLEFT", -14, 0)

    frame.DetailPanel = CreateSection(frame.RightColumn, "Selection",
        "Your current pick for this slot, with ownership and source details.", SECTION_TINTS.detail)
    frame.DetailPanel:SetPoint("TOPLEFT", frame.RightColumn, "TOPLEFT", 0, 0)
    frame.DetailPanel:SetPoint("TOPRIGHT", frame.RightColumn, "TOPRIGHT", 0, 0)
    frame.DetailPanel:SetHeight(244)

    frame.DetailTitle = CreateText(frame.DetailPanel, "OVERLAY", 10, "OUTLINE", { 0.66, 0.84, 0.96 })
    frame.DetailTitle:SetPoint("TOPRIGHT", frame.DetailPanel, "TOPRIGHT", -16, -16)
    frame.DetailSubtitle = frame.DetailPanel.Subtitle

    frame.DetailIconFrame = CreateFrame("Frame", nil, frame.DetailPanel.Body, "BackdropTemplate")
    frame.DetailIconFrame:SetPoint("TOPLEFT", frame.DetailPanel.Body, "TOPLEFT", 2, -2)
    frame.DetailIconFrame:SetSize(78, 78)
    ApplyBackdrop(frame.DetailIconFrame, { 0.08, 0.09, 0.12 }, border, 0.96, 0.22)

    frame.DetailIcon = frame.DetailIconFrame:CreateTexture(nil, "ARTWORK")
    frame.DetailIcon:SetPoint("CENTER", frame.DetailIconFrame, "CENTER", 0, 0)
    frame.DetailIcon:SetSize(68, 68)
    frame.DetailIcon:SetTexCoord(unpack(TEX_COORDS))

    frame.DetailName = CreateText(frame.DetailPanel.Body, "OVERLAY", 18, "OUTLINE", { 1, 0.96, 0.9 })
    frame.DetailName:SetPoint("TOPLEFT", frame.DetailIconFrame, "TOPRIGHT", 16, -2)
    frame.DetailName:SetPoint("RIGHT", frame.DetailPanel.Body, "RIGHT", -250, 0)
    frame.DetailName:SetJustifyH("LEFT")
    ConfigureSingleLine(frame.DetailName)

    frame.DetailMeta = CreateText(frame.DetailPanel.Body, "OVERLAY", 11, "", { 0.72, 0.76, 0.84 })
    frame.DetailMeta:SetPoint("TOPLEFT", frame.DetailName, "BOTTOMLEFT", 0, -6)
    frame.DetailMeta:SetPoint("RIGHT", frame.DetailPanel.Body, "RIGHT", -250, 0)
    frame.DetailMeta:SetJustifyH("LEFT")
    ConfigureSingleLine(frame.DetailMeta)

    frame.DetailStatus = CreateText(frame.DetailPanel.Body, "OVERLAY", 11, "", { 0.84, 0.88, 0.96 })
    frame.DetailStatus:SetPoint("TOPLEFT", frame.DetailMeta, "BOTTOMLEFT", 0, -10)
    frame.DetailStatus:SetPoint("RIGHT", frame.DetailPanel.Body, "RIGHT", -250, 0)
    frame.DetailStatus:SetJustifyH("LEFT")
    ConfigureSingleLine(frame.DetailStatus)

    frame.DetailChipOne = CreateChip(frame.DetailPanel.Body, 108)
    frame.DetailChipOne:SetPoint("TOPLEFT", frame.DetailStatus, "BOTTOMLEFT", 0, -12)
    frame.DetailChipTwo = CreateChip(frame.DetailPanel.Body, 118)
    frame.DetailChipTwo:SetPoint("LEFT", frame.DetailChipOne, "RIGHT", 10, 0)

    frame.DetailFacts = CreateFrame("Frame", nil, frame.DetailPanel.Body, "BackdropTemplate")
    frame.DetailFacts:SetPoint("TOPRIGHT", frame.DetailPanel.Body, "TOPRIGHT", -2, -6)
    frame.DetailFacts:SetSize(210, 96)
    ApplyBackdrop(frame.DetailFacts, { surface[1] * 0.9, surface[2] * 0.92, surface[3] * 0.98 }, border, 0.42, 0.12)

    frame.DetailSlotLabel = CreateText(frame.DetailFacts, "OVERLAY", 9, "OUTLINE", { 0.72, 0.76, 0.84 })
    frame.DetailSlotLabel:SetPoint("TOPLEFT", frame.DetailFacts, "TOPLEFT", 12, -12)
    frame.DetailSlotLabel:SetText("SLOT")
    frame.DetailSlotText = CreateText(frame.DetailFacts, "OVERLAY", 12, "OUTLINE", { 1, 0.96, 0.9 })
    frame.DetailSlotText:SetPoint("TOPLEFT", frame.DetailSlotLabel, "BOTTOMLEFT", 0, -2)

    frame.DetailSourceLabel = CreateText(frame.DetailFacts, "OVERLAY", 9, "OUTLINE", { 0.72, 0.76, 0.84 })
    frame.DetailSourceLabel:SetPoint("TOPLEFT", frame.DetailSlotText, "BOTTOMLEFT", 0, -10)
    frame.DetailSourceLabel:SetText("CURATED SOURCE")
    frame.DetailSourceText = CreateText(frame.DetailFacts, "OVERLAY", 11, "OUTLINE", { 1, 0.96, 0.9 })
    frame.DetailSourceText:SetPoint("TOPLEFT", frame.DetailSourceLabel, "BOTTOMLEFT", 0, -2)
    frame.DetailSourceText:SetPoint("RIGHT", frame.DetailFacts, "RIGHT", -10, 0)
    frame.DetailSourceText:SetJustifyH("LEFT")
    ConfigureSingleLine(frame.DetailSourceText)

    frame.ItemPanel = CreateSection(frame.RightColumn, "Candidate Items",
        "Compare the items from the selected source and save the one you want to chase.", SECTION_TINTS.items)
    frame.ItemPanel:SetPoint("TOPLEFT", frame.DetailPanel, "BOTTOMLEFT", 0, -14)
    frame.ItemPanel:SetPoint("BOTTOMRIGHT", frame.RightColumn, "BOTTOMRIGHT", 0, 0)

    frame.ItemHeaderValue = CreateText(frame.ItemPanel, "OVERLAY", 10, "OUTLINE", { 0.7, 0.8, 0.98 })
    frame.ItemHeaderValue:SetPoint("TOPRIGHT", frame.ItemPanel, "TOPRIGHT", -16, -16)

    frame.ItemScrollShell, frame.ItemScroll, frame.ItemContent = CreateScrollShell(frame.ItemPanel.Body,
        SECTION_TINTS.items)
    frame.ItemScrollShell:SetAllPoints(frame.ItemPanel.Body)
    frame.ItemCards = {}
    frame.ItemEmpty = CreateText(frame.ItemPanel.Body, "OVERLAY", 12, "", { 0.72, 0.76, 0.84 })
    frame.ItemEmpty:SetPoint("CENTER", frame.ItemPanel.Body, "CENTER", 0, 0)
    frame.ItemEmpty:SetText("Select a source to browse candidates for the slot.")
    frame.ItemEmpty:Hide()

    frame.StatusBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.StatusBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
    frame.StatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame.StatusBar:SetHeight(24)
    ApplyBackdrop(frame.StatusBar, { surface[1] * 0.82, surface[2] * 0.84, surface[3] * 0.92 }, border, 0.88, 0.22)
    frame.StatusText = CreateText(frame.StatusBar, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    frame.StatusText:SetPoint("LEFT", frame.StatusBar, "LEFT", 12, 0)
    frame.StatusText:SetPoint("RIGHT", frame.StatusBar, "RIGHT", -12, 0)
    frame.StatusText:SetJustifyH("LEFT")

    frame.CustomOverlay = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.CustomOverlay:SetAllPoints(frame)
    frame.CustomOverlay:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.CustomOverlay:EnableMouse(true)
    frame.CustomOverlay:Hide()
    frame.CustomOverlay:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:HideCustomItemOverlay()
        end
    end)

    frame.CustomDim = frame.CustomOverlay:CreateTexture(nil, "BACKGROUND")
    frame.CustomDim:SetAllPoints(frame.CustomOverlay)
    frame.CustomDim:SetColorTexture(0.02, 0.02, 0.03, 0.78)

    frame.CustomModal = CreateFrame("Frame", nil, frame.CustomOverlay, "BackdropTemplate")
    frame.CustomModal:SetSize(460, 250)
    frame.CustomModal:SetPoint("CENTER", frame.CustomOverlay, "CENTER", 0, 0)
    frame.CustomModal:EnableMouse(true)
    ApplySectionChrome(frame.CustomModal, SECTION_TINTS.detail)
    frame.CustomModal:SetScript("OnMouseDown", function() end)

    frame.CustomTitle = CreateText(frame.CustomModal, "OVERLAY", 18, "OUTLINE", { 1, 0.96, 0.9 })
    frame.CustomTitle:SetPoint("TOPLEFT", frame.CustomModal, "TOPLEFT", 18, -14)
    frame.CustomTitle:SetText("Add a Custom Item")

    frame.CustomClose = CreateFrame("Button", nil, frame.CustomModal, "UIPanelCloseButton")
    frame.CustomClose:SetPoint("TOPRIGHT", frame.CustomModal, "TOPRIGHT", -4, -4)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinCloseButton then
        T.Tools.UI.SkinCloseButton(frame.CustomClose)
    end
    frame.CustomClose:SetScript("OnClick", function()
        self:HideCustomItemOverlay()
    end)
    AttachTooltip(frame.CustomClose, "Close this dialog.", "ANCHOR_LEFT")

    frame.CustomSubtitle = CreateText(frame.CustomModal, "OVERLAY", 10, "", { 0.72, 0.76, 0.84 })
    frame.CustomSubtitle:SetPoint("TOPLEFT", frame.CustomTitle, "BOTTOMLEFT", 0, -4)
    frame.CustomSubtitle:SetText(
        "Use this when the seasonal scan misses an item or you want to pin a manual chase target.")

    frame.CustomItemInput = CreateFrame("EditBox", nil, frame.CustomModal, "InputBoxTemplate")
    frame.CustomItemInput:SetPoint("TOPLEFT", frame.CustomSubtitle, "BOTTOMLEFT", 0, -24)
    frame.CustomItemInput:SetPoint("TOPRIGHT", frame.CustomModal, "TOPRIGHT", -18, 0)
    frame.CustomItemInput:SetHeight(24)
    frame.CustomItemInput:SetAutoFocus(false)
    frame.CustomItemInput:SetTextInsets(8, 8, 0, 0)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinEditBox then
        T.Tools.UI.SkinEditBox(frame.CustomItemInput)
    end

    frame.CustomItemLabel = CreateText(frame.CustomModal, "OVERLAY", 10, "OUTLINE", { 0.66, 0.84, 0.96 })
    frame.CustomItemLabel:SetPoint("BOTTOMLEFT", frame.CustomItemInput, "TOPLEFT", 0, 6)
    frame.CustomItemLabel:SetText("Item link, Wowhead URL, ID, or exact name")

    frame.CustomSourceInput = CreateFrame("EditBox", nil, frame.CustomModal, "InputBoxTemplate")
    frame.CustomSourceInput:SetPoint("TOPLEFT", frame.CustomItemInput, "BOTTOMLEFT", 0, -28)
    frame.CustomSourceInput:SetPoint("TOPRIGHT", frame.CustomItemInput, "BOTTOMRIGHT", 0, -28)
    frame.CustomSourceInput:SetHeight(24)
    frame.CustomSourceInput:SetAutoFocus(false)
    frame.CustomSourceInput:SetTextInsets(8, 8, 0, 0)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinEditBox then
        T.Tools.UI.SkinEditBox(frame.CustomSourceInput)
    end

    frame.CustomSourceLabel = CreateText(frame.CustomModal, "OVERLAY", 10, "OUTLINE", { 0.66, 0.84, 0.96 })
    frame.CustomSourceLabel:SetPoint("BOTTOMLEFT", frame.CustomSourceInput, "TOPLEFT", 0, 6)
    frame.CustomSourceLabel:SetText("Display source label")

    frame.CustomFeedback = CreateText(frame.CustomModal, "OVERLAY", 10, "", { 0.8, 0.84, 0.9 })
    frame.CustomFeedback:SetPoint("TOPLEFT", frame.CustomSourceInput, "BOTTOMLEFT", 0, -18)
    frame.CustomFeedback:SetPoint("RIGHT", frame.CustomModal, "RIGHT", -18, 0)
    frame.CustomFeedback:SetJustifyH("LEFT")

    frame.CustomApply = CreateTwichButton(frame.CustomModal, "Save Item", 110, 28, accent, function()
        self:ApplyCustomItem()
    end)
    frame.CustomApply:SetPoint("BOTTOMRIGHT", frame.CustomModal, "BOTTOMRIGHT", -18, 18)
    AttachTooltip(frame.CustomApply, "Save this item for the selected slot.")

    frame.CustomCancel = CreateTwichButton(frame.CustomModal, "Cancel", 90, 28, primary, function()
        self:HideCustomItemOverlay()
    end)
    frame.CustomCancel:SetPoint("RIGHT", frame.CustomApply, "LEFT", -10, 0)
    AttachTooltip(frame.CustomCancel, "Close the dialog without saving.")

    frame.CustomItemInput:SetScript("OnEnterPressed", function()
        self:ApplyCustomItem()
    end)
    frame.CustomSourceInput:SetScript("OnEnterPressed", function()
        self:ApplyCustomItem()
    end)
    frame.CustomItemInput:SetScript("OnEscapePressed", function()
        self:HideCustomItemOverlay()
    end)
    frame.CustomSourceInput:SetScript("OnEscapePressed", function()
        self:HideCustomItemOverlay()
    end)

    frame.IntroAnimation = frame:CreateAnimationGroup()
    local frameFade = frame.IntroAnimation:CreateAnimation("Alpha")
    frameFade:SetFromAlpha(0)
    frameFade:SetToAlpha(1)
    frameFade:SetDuration(0.2)
    frame.IntroAnimation:SetScript("OnFinished", function()
        frame:SetAlpha(1)
    end)
    frame.IntroAnimation:SetScript("OnStop", function()
        frame:SetAlpha(1)
    end)

    frame.CustomModalIn = frame.CustomModal:CreateAnimationGroup()
    local modalFade = frame.CustomModalIn:CreateAnimation("Alpha")
    modalFade:SetFromAlpha(0)
    modalFade:SetToAlpha(1)
    modalFade:SetDuration(0.14)
    local modalSlide = frame.CustomModalIn:CreateAnimation("Translation")
    modalSlide:SetOffset(0, -18)
    modalSlide:SetDuration(0.14)
    frame.CustomModalIn:SetScript("OnFinished", function()
        frame.CustomModal:SetAlpha(1)
    end)
    frame.CustomModalIn:SetScript("OnStop", function()
        frame.CustomModal:SetAlpha(1)
    end)

    self.frame = frame
    self.SelectedSlotID = SLOT_DEFINITIONS[1].slotID
    self.BrowseSource = nil
    self.FilteredCatalogBySlot = {}
    self:HookDetailTooltip()
end
