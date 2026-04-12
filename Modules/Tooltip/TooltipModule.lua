---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class TooltipModule : AceModule, AceEvent-3.0, AceHook-3.0
local TooltipModule = T:NewModule("Tooltip", "AceEvent-3.0", "AceHook-3.0")

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local GameTooltip = _G.GameTooltip
local GameTooltipStatusBar = _G.GameTooltipStatusBar
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local CUSTOM_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local ITEM_QUALITY_COLORS = _G.ITEM_QUALITY_COLORS
local GetGuildInfo = _G.GetGuildInfo
local UnitClass = _G.UnitClass
local UnitCanAttack = _G.UnitCanAttack
local UnitFactionGroup = _G.UnitFactionGroup
local UnitIsFriend = _G.UnitIsFriend
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsUnit = _G.UnitIsUnit
local InCombatLockdown = _G.InCombatLockdown
local GetInventoryItemAverageItemLevel = _G.GetInventoryItemAverageItemLevel
local GetAverageItemLevel = _G.GetAverageItemLevel
local GetInspectSpecialization = _G.GetInspectSpecialization
local GetSpecializationInfoByID = _G.GetSpecializationInfoByID
local BreakUpLargeNumbers = _G.BreakUpLargeNumbers
local C_PlayerInfo = _G.C_PlayerInfo
local C_PaperDollInfo = _G.C_PaperDollInfo
local C_Item = _G.C_Item
local C_TransmogCollection = _G.C_TransmogCollection
local LE_ITEM_CLASS_WEAPON = _G.LE_ITEM_CLASS_WEAPON or 2
local LE_ITEM_CLASS_ARMOR = _G.LE_ITEM_CLASS_ARMOR or 4
local math_max = math.max
local math_floor = math.floor

local FACTION_ICONS = {
    Horde = "|TInterface\\FriendsFrame\\PlusManz-Horde:14:14:0:0|t",
    Alliance = "|TInterface\\FriendsFrame\\PlusManz-Alliance:14:14:0:0|t",
}

local MANAGED_TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
    "EmbeddedItemTooltip",
    "ItemRefShoppingTooltip1",
    "ItemRefShoppingTooltip2",
    "WorldMapTooltip",
}

local ANCHORABLE_TOOLTIP_NAMES = {
    GameTooltip = true,
}

local THEME_KEYS = {
    primaryColor = true,
    backgroundColor = true,
    borderColor = true,
    textColor = true,
    backgroundAlpha = true,
    borderAlpha = true,
    statusBarTexture = true,
    globalFont = true,
    classIconStyle = true,
}

local function RoundPixel(value)
    return math_floor((tonumber(value) or 0) + 0.5)
end

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function GetThemeColor(key, fallback)
    local theme = GetThemeModule()
    local getColor = theme and theme["GetColor"] or nil
    if theme and type(getColor) == "function" then
        local color = getColor(theme, key)
        if type(color) == "table" then
            return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
        end
    end

    return fallback[1], fallback[2], fallback[3]
end

local function GetThemeValue(key, fallback)
    local theme = GetThemeModule()
    local getValue = theme and theme["Get"] or nil
    if theme and type(getValue) == "function" then
        local value = getValue(theme, key)
        if value ~= nil then
            return value
        end
    end

    return fallback
end

local function ResolveFontPath()
    local path = STANDARD_TEXT_FONT
    local theme = GetThemeModule()
    local LSM = T.Libs and T.Libs.LSM
    local getValue = theme and theme["Get"] or nil
    if theme and LSM and type(getValue) == "function" then
        local fontKey = getValue(theme, "globalFont")
        if fontKey and fontKey ~= "" and fontKey ~= "__default" then
            local ok, fetched = pcall(LSM.Fetch, LSM, "font", fontKey)
            if ok and type(fetched) == "string" and fetched ~= "" then
                path = fetched
            end
        end
    end
    return path
end

local function ResolveStatusBarTexture()
    local theme = GetThemeModule()
    local LSM = T.Libs and T.Libs.LSM
    local getValue = theme and theme["Get"] or nil
    if theme and LSM and type(getValue) == "function" then
        local textureKey = getValue(theme, "statusBarTexture")
        if textureKey and textureKey ~= "" then
            local ok, fetched = pcall(LSM.Fetch, LSM, "statusbar", textureKey)
            if ok and type(fetched) == "string" and fetched ~= "" then
                return fetched
            end
        end
    end
end

local function GetOptions()
    local configurationModule = T:GetModule("Configuration") --[[@as any]]
    return configurationModule and configurationModule.Options and configurationModule.Options.Tooltip or nil
end

local function GetTexturesTool()
    return T.Tools and T.Tools.Textures or nil
end

function TooltipModule:GetManagedFrames()
    if self.managedFrames then
        return self.managedFrames
    end

    self.managedFrames = {}
    for _, name in ipairs(MANAGED_TOOLTIP_NAMES) do
        local frame = _G[name]
        if frame then
            self.managedFrames[#self.managedFrames + 1] = frame
        end
    end

    return self.managedFrames
end

function TooltipModule:CreateAnchor()
    if self.anchor then
        return self.anchor
    end

    local anchor = CreateFrame("Frame", "TwichUITooltipAnchor", UIParent, "BackdropTemplate")
    anchor:SetSize(220, 26)
    anchor:SetFrameStrata("TOOLTIP")
    anchor:SetClampedToScreen(true)
    anchor:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    anchor.Accent = anchor:CreateTexture(nil, "BORDER")
    anchor.Accent:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
    anchor.Accent:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 1, 1)
    anchor.Accent:SetWidth(4)

    anchor.Glow = anchor:CreateTexture(nil, "BACKGROUND")
    anchor.Glow:SetPoint("TOPLEFT", anchor, "TOPLEFT", 1, -1)
    anchor.Glow:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -1, 1)

    anchor.Label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    anchor.Label:SetPoint("LEFT", anchor, "LEFT", 12, 0)
    anchor.Label:SetPoint("RIGHT", anchor, "RIGHT", -12, 0)
    anchor.Label:SetJustifyH("LEFT")
    anchor.Label:SetText("Tooltip Anchor")

    self.anchor = anchor
    self:ApplyAnchorTheme()
    self:ApplyAnchorPosition()
    self:UpdateAnchorVisibility()
    return anchor
end

function TooltipModule:ApplyAnchorTheme()
    if not self.anchor then
        return
    end

    local backgroundR, backgroundG, backgroundB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    local textR, textG, textB = GetThemeColor("textColor", { 1.00, 0.95, 0.85 })
    local backgroundAlpha = tonumber(GetThemeValue("backgroundAlpha", 0.94)) or 0.94
    local borderAlpha = tonumber(GetThemeValue("borderAlpha", 0.85)) or 0.85

    self.anchor:SetBackdropColor(backgroundR, backgroundG, backgroundB, math_max(0.60, backgroundAlpha))
    self.anchor:SetBackdropBorderColor(borderR, borderG, borderB, math_max(0.80, borderAlpha))
    self.anchor.Accent:SetColorTexture(accentR, accentG, accentB, 0.95)
    self.anchor.Glow:SetColorTexture(accentR, accentG, accentB, 0.10)
    self.anchor.Label:SetTextColor(textR, textG, textB, 0.96)
    self.anchor.Label:SetFont(ResolveFontPath(), 11, "")
end

function TooltipModule:ApplyAnchorPosition()
    local anchor = self:CreateAnchor()
    local options = GetOptions()
    local x = options and options.GetAnchorX and options:GetAnchorX() or 1050
    local y = options and options.GetAnchorY and options:GetAnchorY() or 260
    anchor:ClearAllPoints()
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

function TooltipModule:UpdateAnchorVisibility()
    if not self.anchor then
        return
    end

    local options = GetOptions()
    local showAnchor = false
    if options and options:GetEnabled() then
        local anchorMode = options:GetAnchorMode()
        local locked = options:GetAnchorLocked()
        local moversActive = _G.TwichMoverModule and _G.TwichMoverModule._active == true
        showAnchor = moversActive or (anchorMode == "fixed" and not locked)
    end

    if showAnchor then
        self.anchor:Show()
    else
        self.anchor:Hide()
    end
end

function TooltipModule:StoreOriginalFont(fontString)
    if not fontString or fontString.__tuiTooltipOriginalFont then
        return
    end

    local path, size, flags = fontString:GetFont()
    local shadowX, shadowY = fontString:GetShadowOffset()
    fontString.__tuiTooltipOriginalFont = {
        path = path,
        size = size,
        flags = flags,
        shadowX = shadowX,
        shadowY = shadowY,
    }
end

function TooltipModule:RestoreFont(fontString)
    if not fontString or not fontString.__tuiTooltipOriginalFont then
        return
    end

    local original = fontString.__tuiTooltipOriginalFont
    fontString:SetFont(original.path or STANDARD_TEXT_FONT, original.size or 12, original.flags or "")
    fontString:SetShadowOffset(original.shadowX or 0, original.shadowY or 0)
end

function TooltipModule:GetClassColor(classToken)
    local colorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local classColor = colorTable and colorTable[classToken or ""]
    if classColor then
        return classColor.r or 1, classColor.g or 1, classColor.b or 1
    end
end

function TooltipModule:IsFrameObject(frame)
    return frame and type(frame.GetObjectType) == "function" and type(frame.HookScript) == "function"
end

function TooltipModule:HasScript(frame, scriptName)
    if not self:IsFrameObject(frame) or type(frame.GetScript) ~= "function" then
        return false
    end

    local ok, script = pcall(frame.GetScript, frame, scriptName)
    return ok and script ~= nil
end

function TooltipModule:GetTooltipLine(frame, index, side)
    if not frame or type(frame.GetName) ~= "function" then
        return nil
    end

    local name = frame:GetName()
    if not name then
        return nil
    end

    return _G[string.format("%sText%s%d", name, side or "Left", index)]
end

function TooltipModule:TooltipHasLine(frame, text)
    if not frame or type(text) ~= "string" or text == "" then
        return false
    end

    local lines = frame.NumLines and frame:NumLines() or 0
    for index = 1, lines do
        local left = self:GetTooltipLine(frame, index, "Left")
        if left and left.GetText and left:GetText() == text then
            return true
        end

        local right = self:GetTooltipLine(frame, index, "Right")
        if right and right.GetText and right:GetText() == text then
            return true
        end
    end

    return false
end

function TooltipModule:FormatNumber(value)
    if type(value) ~= "number" then
        return tostring(value or "")
    end

    if type(BreakUpLargeNumbers) == "function" then
        return BreakUpLargeNumbers(math_floor(value + 0.5))
    end

    return tostring(math_floor(value + 0.5))
end

function TooltipModule:GetMythicScoreColor(score)
    if type(score) ~= "number" then
        return 0.65, 0.65, 0.65
    elseif score >= 3000 then
        return 1.00, 0.50, 0.00
    elseif score >= 2500 then
        return 0.85, 0.40, 1.00
    elseif score >= 2000 then
        return 0.20, 0.75, 1.00
    elseif score >= 1500 then
        return 0.40, 1.00, 0.40
    end

    return 0.65, 0.65, 0.65
end

function TooltipModule:GetResolvedClassIconStyle()
    local options = GetOptions()
    local style = options and options.GetClassIconStyle and options:GetClassIconStyle() or "global"
    if style and style ~= "global" then
        return style
    end

    local theme = GetThemeModule()
    if theme and type(theme.Get) == "function" then
        return theme:Get("classIconStyle") or "default"
    end

    return "default"
end

function TooltipModule:GetClassIconMarkup(classToken, size)
    local options = GetOptions()
    if not options or not options:GetShowClassIcon() then
        return nil
    end

    local textures = GetTexturesTool()
    if not textures or type(textures.GetClassTextureString) ~= "function" then
        return nil
    end

    return textures:GetClassTextureString(classToken, size or 14, self:GetResolvedClassIconStyle())
end

function TooltipModule:GetPlayerEquippedItemLevel(unit)
    if unit and UnitIsUnit and UnitIsUnit(unit, "player") then
        if type(GetInventoryItemAverageItemLevel) == "function" then
            local _, equipped = GetInventoryItemAverageItemLevel()
            if type(equipped) == "number" and equipped > 0 then
                return equipped
            end
        end

        if type(GetAverageItemLevel) == "function" then
            local _, equipped = GetAverageItemLevel()
            if type(equipped) == "number" and equipped > 0 then
                return equipped
            end
        end
    end

    if C_PaperDollInfo and type(C_PaperDollInfo.GetInspectItemLevel) == "function" and unit then
        local equipped = C_PaperDollInfo.GetInspectItemLevel(unit)
        if type(equipped) == "number" and equipped > 0 then
            return equipped
        end
    end

    return nil
end

function TooltipModule:PlayFadeIn(frame)
    local options = GetOptions()
    if not frame or not options or not options:GetEnableFadeIn() then
        return
    end

    if type(frame.CreateAnimationGroup) ~= "function" then
        return
    end

    local animation = frame.TwichUITooltipFadeIn
    if not animation then
        animation = frame:CreateAnimationGroup()
        local alpha = animation:CreateAnimation("Alpha")
        alpha:SetOrder(1)
        animation._alpha = alpha
        animation:SetScript("OnFinished", function(owner)
            owner:GetParent():SetAlpha(1)
        end)
        animation:SetScript("OnStop", function(owner)
            owner:GetParent():SetAlpha(1)
        end)
        frame.TwichUITooltipFadeIn = animation
    end

    animation:Stop()
    animation._alpha:SetDuration(0.12)
    animation._alpha:SetFromAlpha(0)
    animation._alpha:SetToAlpha(1)
    frame:SetAlpha(0)
    animation:Play()
end

function TooltipModule:ApplyItemBorder(frame)
    local options = GetOptions()
    if not options or not options:GetUseItemQualityBorder() or not frame or type(frame.GetItem) ~= "function" or not C_Item then
        return
    end

    local _, itemLink = frame:GetItem()
    if not itemLink then
        return
    end

    local _, _, quality = C_Item.GetItemInfo(itemLink)
    local qualityColor = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if not qualityColor then
        return
    end

    local chrome = self:EnsureFrameChrome(frame)
    chrome:SetBackdropBorderColor(qualityColor.r or 1, qualityColor.g or 1, qualityColor.b or 1, 0.72)
    chrome.Accent:SetColorTexture(qualityColor.r or 1, qualityColor.g or 1, qualityColor.b or 1,
        options:GetShowAccent() and 0.95 or 0)
    chrome.Glow:SetColorTexture(qualityColor.r or 1, qualityColor.g or 1, qualityColor.b or 1,
        options:GetShowAccent() and 0.10 or 0)
end

function TooltipModule:AppendItemAppearance(frame)
    local options = GetOptions()
    if not options or not options:GetShowTransmogStatus() or not frame or type(frame.GetItem) ~= "function" or not C_Item or not C_TransmogCollection or type(C_TransmogCollection.PlayerHasTransmogByItemInfo) ~= "function" then
        return
    end

    local _, itemLink = frame:GetItem()
    if not itemLink then
        return
    end

    local itemID, _, _, itemEquipLoc, _, itemClassID = C_Item.GetItemInfoInstant(itemLink)
    if not itemID or not itemClassID then
        return
    end

    if itemClassID ~= LE_ITEM_CLASS_WEAPON and itemClassID ~= LE_ITEM_CLASS_ARMOR then
        return
    end

    if itemEquipLoc == "INVTYPE_TRINKET" or itemEquipLoc == "INVTYPE_FINGER" or itemEquipLoc == "INVTYPE_NECK" then
        return
    end

    if self:TooltipHasLine(frame, "Appearance: Collected") or self:TooltipHasLine(frame, "Appearance: Not Collected") then
        return
    end

    local ok, collected = pcall(C_TransmogCollection.PlayerHasTransmogByItemInfo, itemID)
    if not ok or collected == nil then
        return
    end

    frame:AddLine(" ")
    if collected == true then
        frame:AddLine("Appearance: Collected", 0.42, 0.89, 0.63)
    else
        frame:AddLine("Appearance: Not Collected", 0.96, 0.74, 0.22)
    end
end

function TooltipModule:AppendPlayerDetails(frame, unit)
    local options = GetOptions()
    if not options or not options:GetShowPlayerDetails() or not unit or not UnitIsPlayer(unit) then
        return
    end

    local className, classToken = UnitClass(unit)
    local factionName = UnitFactionGroup(unit)
    local specName
    local roleName
    local guildRankName

    local ok, specID = pcall(GetInspectSpecialization, unit)
    if ok and specID and specID > 0 then
        local _, foundSpecName, _, _, foundRole = GetSpecializationInfoByID(specID)
        specName = foundSpecName
        roleName = foundRole
    end

    local guildOk, _, foundGuildRankName = pcall(GetGuildInfo, unit)
    if guildOk then
        guildRankName = foundGuildRankName
    end

    local detailParts = {}
    if factionName and factionName ~= "" then
        local factionIcon = options:GetShowFactionIcon() and FACTION_ICONS[factionName] or nil
        detailParts[#detailParts + 1] = factionIcon and (factionIcon .. " " .. factionName) or factionName
    end

    local classLabel
    if specName and specName ~= "" then
        classLabel = specName
    elseif className and className ~= "" then
        classLabel = className
    end

    if classLabel and classLabel ~= "" then
        local classIcon = self:GetClassIconMarkup(classToken, 14)
        detailParts[#detailParts + 1] = classIcon and (classIcon .. " " .. classLabel) or classLabel
    end

    if roleName and roleName ~= "" then
        detailParts[#detailParts + 1] = roleName
    end

    local detailLine = table.concat(detailParts, " • ")
    if detailLine ~= "" and not self:TooltipHasLine(frame, detailLine) then
        frame:AddLine(detailLine, 0.76, 0.78, 0.84)
    end

    if options:GetShowGuildRank() and guildRankName and guildRankName ~= "" then
        local guildRankLine = "Guild Rank: " .. guildRankName
        if not self:TooltipHasLine(frame, guildRankLine) then
            frame:AddLine(guildRankLine, 0.66, 0.70, 0.76)
        end
    end

    if options:GetShowMythicScore() and C_PlayerInfo and type(C_PlayerInfo.GetPlayerMythicPlusRatingSummary) == "function" then
        local summary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary(unit)
        local score = type(summary) == "table" and summary.currentSeasonScore or nil
        if type(score) == "number" and score > 0 then
            local mythicLine = "M+ Score: " .. self:FormatNumber(score)
            if not self:TooltipHasLine(frame, mythicLine) then
                local red, green, blue = self:GetMythicScoreColor(score)
                frame:AddLine(mythicLine, red, green, blue)
            end
        end
    end

    if options:GetShowItemLevel() and UnitIsUnit and UnitIsUnit(unit, "player") then
        local equipped = self:GetPlayerEquippedItemLevel(unit)
        if equipped and equipped > 0 then
            local levelLine = string.format("Item Level %.1f", equipped)
            if not self:TooltipHasLine(frame, levelLine) then
                frame:AddLine(levelLine, 0.96, 0.76, 0.24)
            end
        end
    end
end

function TooltipModule:ApplyUnitIdentity(frame)
    local options = GetOptions()
    if not options or frame ~= GameTooltip then
        return
    end

    local _, unit = GameTooltip:GetUnit()
    if not unit or not UnitIsPlayer(unit) then
        return
    end

    self:AppendPlayerDetails(frame, unit)

    if not options:GetUsePlayerClassColors() then
        return
    end

    local _, classToken = UnitClass(unit)
    local red, green, blue = self:GetClassColor(classToken)
    if not red then
        return
    end

    local title = self:GetTooltipLine(frame, 1, "Left")
    if title then
        title:SetTextColor(red, green, blue)
    end

    local chrome = self:EnsureFrameChrome(frame)
    chrome:SetBackdropBorderColor(red, green, blue, 0.72)
    chrome.Accent:SetColorTexture(red, green, blue, options:GetShowAccent() and 0.95 or 0)
    chrome.Glow:SetColorTexture(red, green, blue, options:GetShowAccent() and 0.10 or 0)
end

function TooltipModule:EnsureFrameChrome(frame)
    if frame.TwichUITooltipChrome then
        return frame.TwichUITooltipChrome
    end

    local chrome = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    chrome:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetFrameStrata(frame:GetFrameStrata())
    chrome:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))

    chrome.Accent = chrome:CreateTexture(nil, "BORDER")
    chrome.Accent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.Accent:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -1, -1)
    chrome.Accent:SetHeight(2)

    chrome.Glow = chrome:CreateTexture(nil, "BACKGROUND")
    chrome.Glow:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.Glow:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -1, 1)

    chrome.Shine = chrome:CreateTexture(nil, "ARTWORK")
    chrome.Shine:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.Shine:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -1, -1)
    chrome.Shine:SetHeight(20)
    chrome.Shine:SetColorTexture(1, 1, 1, 0)

    frame.TwichUITooltipChrome = chrome
    frame:HookScript("OnSizeChanged", function(owner)
        if owner.TwichUITooltipChrome then
            owner.TwichUITooltipChrome:SetFrameLevel(math_max(0, owner:GetFrameLevel() - 1))
            owner.TwichUITooltipChrome:ClearAllPoints()
            owner.TwichUITooltipChrome:SetPoint("TOPLEFT", owner, "TOPLEFT", -4, 4)
            owner.TwichUITooltipChrome:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 4, -4)
        end
    end)

    return chrome
end

function TooltipModule:ApplyChrome(frame)
    if not frame then
        return
    end

    local chrome = self:EnsureFrameChrome(frame)
    local backgroundR, backgroundG, backgroundB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    local backgroundAlpha = tonumber(GetThemeValue("backgroundAlpha", 0.94)) or 0.94
    local borderAlpha = tonumber(GetThemeValue("borderAlpha", 0.85)) or 0.85
    local options = GetOptions()

    chrome:ClearAllPoints()
    chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
    chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    chrome:SetBackdropColor(backgroundR, backgroundG, backgroundB, math_max(0.62, backgroundAlpha))
    chrome:SetBackdropBorderColor(borderR, borderG, borderB, math_max(0.78, borderAlpha))
    chrome.Accent:SetColorTexture(accentR, accentG, accentB, options and options:GetShowAccent() and 0.95 or 0)
    chrome.Glow:SetColorTexture(accentR, accentG, accentB, options and options:GetShowAccent() and 0.09 or 0)
    chrome.Shine:SetAlpha(0)
    chrome:SetShown(frame:IsShown())
end

function TooltipModule:SuppressDefaultBackdrop(frame)
    if not frame then
        return
    end

    if frame.GetBackdropColor and not frame.__tuiTooltipOriginalBackdropColor then
        local r, g, b, a = frame:GetBackdropColor()
        frame.__tuiTooltipOriginalBackdropColor = { r, g, b, a }
    end
    if frame.GetBackdropBorderColor and not frame.__tuiTooltipOriginalBorderColor then
        local r, g, b, a = frame:GetBackdropBorderColor()
        frame.__tuiTooltipOriginalBorderColor = { r, g, b, a }
    end
    if frame.SetBackdropColor then
        frame:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(0, 0, 0, 0)
    end

    if frame.NineSlice then
        if frame.__tuiTooltipOriginalNineSliceAlpha == nil and frame.NineSlice.GetAlpha then
            frame.__tuiTooltipOriginalNineSliceAlpha = frame.NineSlice:GetAlpha()
        end
        frame.NineSlice:SetAlpha(0)
    end
end

function TooltipModule:RestoreDefaultBackdrop(frame)
    if not frame then
        return
    end

    if frame.SetBackdropColor and frame.__tuiTooltipOriginalBackdropColor then
        local color = frame.__tuiTooltipOriginalBackdropColor
        frame:SetBackdropColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
    end
    if frame.SetBackdropBorderColor and frame.__tuiTooltipOriginalBorderColor then
        local color = frame.__tuiTooltipOriginalBorderColor
        frame:SetBackdropBorderColor(color[1] or 0, color[2] or 0, color[3] or 0, color[4] or 1)
    end
    if frame.NineSlice and frame.__tuiTooltipOriginalNineSliceAlpha ~= nil then
        frame.NineSlice:SetAlpha(frame.__tuiTooltipOriginalNineSliceAlpha)
    end
end

function TooltipModule:ApplyFonts(frame)
    local options = GetOptions()
    if not options or not frame or type(frame.GetName) ~= "function" then
        return
    end

    local name = frame:GetName()
    if not name then
        return
    end

    local fontPath = ResolveFontPath()
    local headerSize = options:GetHeaderFontSize()
    local bodySize = options:GetBodyFontSize()
    local lines = frame:NumLines() or 0
    for index = 1, lines do
        local left = _G[name .. "TextLeft" .. index]
        local right = _G[name .. "TextRight" .. index]

        if left then
            self:StoreOriginalFont(left)
            left:SetFont(fontPath, index == 1 and headerSize or bodySize, "")
            left:SetShadowOffset(1, -1)
        end

        if right then
            self:StoreOriginalFont(right)
            right:SetFont(fontPath, bodySize, "")
            right:SetShadowOffset(1, -1)
        end
    end
end

function TooltipModule:RestoreFonts(frame)
    if not frame or type(frame.GetName) ~= "function" then
        return
    end

    local name = frame:GetName()
    if not name then
        return
    end

    for index = 1, 40 do
        self:RestoreFont(_G[name .. "TextLeft" .. index])
        self:RestoreFont(_G[name .. "TextRight" .. index])
    end
end

function TooltipModule:StyleStatusBar()
    local options = GetOptions()
    if not options or not GameTooltipStatusBar then
        return
    end

    if not options:GetShowHealthBar() then
        GameTooltipStatusBar:Hide()
        GameTooltipStatusBar:SetAlpha(0)
        if GameTooltipStatusBar.TwichUIBackdrop then
            GameTooltipStatusBar.TwichUIBackdrop:Hide()
        end
        return
    end

    GameTooltipStatusBar:SetAlpha(1)

    if not GameTooltipStatusBar.TwichUIBackdrop then
        local backdrop = CreateFrame("Frame", nil, GameTooltipStatusBar, "BackdropTemplate")
        backdrop:SetFrameLevel(math_max(0, GameTooltipStatusBar:GetFrameLevel() - 1))
        backdrop:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        backdrop:SetPoint("TOPLEFT", GameTooltipStatusBar, "TOPLEFT", -1, 1)
        backdrop:SetPoint("BOTTOMRIGHT", GameTooltipStatusBar, "BOTTOMRIGHT", 1, -1)
        GameTooltipStatusBar.TwichUIBackdrop = backdrop
    end

    if not GameTooltipStatusBar.__tuiTooltipOriginalTexture and GameTooltipStatusBar.GetStatusBarTexture then
        GameTooltipStatusBar.__tuiTooltipOriginalTexture = GameTooltipStatusBar:GetStatusBarTexture()
    end
    if not GameTooltipStatusBar.__tuiTooltipOriginalHeight then
        GameTooltipStatusBar.__tuiTooltipOriginalHeight = GameTooltipStatusBar:GetHeight()
    end

    local texturePath = ResolveStatusBarTexture()
    if texturePath then
        GameTooltipStatusBar:SetStatusBarTexture(texturePath)
    end

    GameTooltipStatusBar:SetHeight(options:GetStatusBarHeight())

    local backgroundR, backgroundG, backgroundB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local accentR, accentG, accentB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    GameTooltipStatusBar.TwichUIBackdrop:SetBackdropColor(backgroundR, backgroundG, backgroundB, 0.90)
    GameTooltipStatusBar.TwichUIBackdrop:SetBackdropBorderColor(borderR, borderG, borderB, 0.85)
    if GameTooltipStatusBar:IsShown() then
        GameTooltipStatusBar.TwichUIBackdrop:Show()
    end

    local _, unit = GameTooltip:GetUnit()
    if unit and UnitIsPlayer and UnitIsPlayer(unit) then
        local _, classToken = UnitClass(unit)
        local colorTable = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
        local classColor = colorTable and colorTable[classToken or ""]
        if classColor then
            GameTooltipStatusBar:SetStatusBarColor(classColor.r or 1, classColor.g or 1, classColor.b or 1)
            return
        end
    end

    if unit and UnitCanAttack and UnitCanAttack("player", unit) then
        GameTooltipStatusBar:SetStatusBarColor(0.88, 0.26, 0.30)
    elseif unit and UnitIsFriend and UnitIsFriend(unit, "player") then
        GameTooltipStatusBar:SetStatusBarColor(0.24, 0.80, 0.54)
    else
        GameTooltipStatusBar:SetStatusBarColor(accentR, accentG, accentB)
    end
end

function TooltipModule:RestoreStatusBar()
    if not GameTooltipStatusBar then
        return
    end

    GameTooltipStatusBar:SetAlpha(1)
    if GameTooltipStatusBar.TwichUIBackdrop then
        GameTooltipStatusBar.TwichUIBackdrop:Hide()
    end
    if GameTooltipStatusBar.__tuiTooltipOriginalTexture then
        GameTooltipStatusBar:SetStatusBarTexture(GameTooltipStatusBar.__tuiTooltipOriginalTexture)
    end
    if GameTooltipStatusBar.__tuiTooltipOriginalHeight then
        GameTooltipStatusBar:SetHeight(GameTooltipStatusBar.__tuiTooltipOriginalHeight)
    end
end

function TooltipModule:ApplyAnchorMode(frame, owner)
    local options = GetOptions()
    if not options or not options:GetEnabled() or not frame or not ANCHORABLE_TOOLTIP_NAMES[frame:GetName() or ""] then
        return
    end

    local anchorMode = options:GetAnchorMode()
    if anchorMode == "default" then
        return
    end
    if self.anchorGuard then
        return
    end

    self.anchorGuard = true
    if anchorMode == "cursor" then
        frame:SetOwner(UIParent, "ANCHOR_CURSOR", options:GetCursorOffsetX(), options:GetCursorOffsetY())
    elseif anchorMode == "fixed" then
        local anchor = self:CreateAnchor()
        frame:SetOwner(UIParent, "ANCHOR_NONE")
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 12)
    end
    self.anchorGuard = nil
end

function TooltipModule:OnDefaultTooltipAnchor(frame, owner)
    if frame ~= GameTooltip then
        return
    end

    local options = GetOptions()
    if not options or not options:GetEnabled() then
        return
    end

    local anchorMode = options:GetAnchorMode()
    if anchorMode == "default" or self.anchorGuard then
        return
    end

    self.anchorGuard = true
    if anchorMode == "cursor" then
        frame:SetOwner(owner or UIParent, "ANCHOR_CURSOR", options:GetCursorOffsetX(), options:GetCursorOffsetY())
    elseif anchorMode == "fixed" then
        local anchor = self:CreateAnchor()
        frame:SetOwner(UIParent, "ANCHOR_NONE")
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 12)
    end
    self.anchorGuard = nil
end

function TooltipModule:ApplyScale(frame)
    local options = GetOptions()
    if not options or not frame then
        return
    end

    if frame.__tuiTooltipOriginalScale == nil and frame.GetScale then
        frame.__tuiTooltipOriginalScale = frame:GetScale()
    end
    frame:SetScale(options:GetScale())
end

function TooltipModule:StyleFrame(frame)
    local options = GetOptions()
    if not options or not options:GetEnabled() or not frame then
        return
    end

    if options:GetHideInCombat() and InCombatLockdown() then
        if frame.Hide then
            frame:Hide()
        end
        return
    end

    self:SuppressDefaultBackdrop(frame)
    self:ApplyChrome(frame)
    self:ApplyScale(frame)
    self:ApplyFonts(frame)
    self:ApplyItemBorder(frame)
    self:AppendItemAppearance(frame)
    self:ApplyUnitIdentity(frame)
    if frame == GameTooltip then
        self:StyleStatusBar()
    end
    self:PlayFadeIn(frame)
end

function TooltipModule:RestoreFrame(frame)
    if not frame then
        return
    end

    self:RestoreDefaultBackdrop(frame)
    self:RestoreFonts(frame)
    if frame.TwichUITooltipChrome then
        frame.TwichUITooltipChrome:Hide()
    end
    if frame.__tuiTooltipOriginalScale ~= nil then
        frame:SetScale(frame.__tuiTooltipOriginalScale)
    end
end

function TooltipModule:RegisterManagedFrame(frame)
    if not frame or self.registeredFrames[frame] then
        return
    end

    self.registeredFrames[frame] = true
    if frame ~= GameTooltip then
        self:SecureHook(frame, "SetOwner", "OnTooltipSetOwner")
    end
    if self:HasScript(frame, "OnShow") then
        self:SecureHookScript(frame, "OnShow", "OnTooltipShow")
    end
    if self:HasScript(frame, "OnHide") then
        self:SecureHookScript(frame, "OnHide", "OnTooltipHide")
    end
    if self:HasScript(frame, "OnTooltipSetUnit") then
        self:SecureHookScript(frame, "OnTooltipSetUnit", "OnTooltipSetUnit")
    end
end

function TooltipModule:RefreshAllTooltips()
    self:ApplyAnchorPosition()
    self:ApplyAnchorTheme()
    self:UpdateAnchorVisibility()

    for _, frame in ipairs(self:GetManagedFrames()) do
        if frame:IsShown() then
            self:StyleFrame(frame)
            if frame == GameTooltip then
                self:OnDefaultTooltipAnchor(frame, frame:GetOwner())
            else
                self:ApplyAnchorMode(frame, frame:GetOwner())
            end
        elseif frame.TwichUITooltipChrome then
            frame.TwichUITooltipChrome:Hide()
        end
    end
end

function TooltipModule:RefreshAnchor()
    self:ApplyAnchorPosition()
    self:ApplyAnchorTheme()
    self:UpdateAnchorVisibility()
    if GameTooltip and GameTooltip:IsShown() then
        self:OnDefaultTooltipAnchor(GameTooltip, GameTooltip:GetOwner())
    end
end

function TooltipModule:ShowPreview()
    local options = GetOptions()
    if not options or not options:GetEnabled() or not GameTooltip then
        return
    end

    local owner = UIParent
    local anchorMode = options:GetAnchorMode()
    if anchorMode == "cursor" then
        GameTooltip:SetOwner(owner, "ANCHOR_CURSOR", options:GetCursorOffsetX(), options:GetCursorOffsetY())
    elseif anchorMode == "fixed" then
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMLEFT", self:CreateAnchor(), "TOPLEFT", 0, 12)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("CENTER", UIParent, "CENTER", 220, 60)
    end

    GameTooltip:ClearLines()
    GameTooltip:AddLine("TwichUI Tooltip")
    GameTooltip:AddLine("Premium chrome, theme-aware surfaces, and controlled anchor behavior.", 0.82, 0.84, 0.90, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Anchor Mode", anchorMode:gsub("^%l", string.upper), 0.96, 0.76, 0.24, 1, 1, 1)
    GameTooltip:AddDoubleLine("Scale", string.format("%.2f", options:GetScale()), 0.72, 0.74, 0.80, 1, 1, 1)
    GameTooltip:AddDoubleLine("Health Bar", options:GetShowHealthBar() and "Enabled" or "Hidden", 0.72, 0.74, 0.80, 1, 1,
        1)
    GameTooltip:Show()
    self:StyleFrame(GameTooltip)
end

function TooltipModule:OnTooltipSetOwner(frame, owner)
    self:ApplyAnchorMode(frame, owner)
end

function TooltipModule:OnTooltipShow(frame)
    self:StyleFrame(frame)
    if frame ~= GameTooltip then
        self:ApplyAnchorMode(frame, frame:GetOwner())
    end
end

function TooltipModule:OnTooltipHide(frame)
    if frame and frame.TwichUITooltipFadeIn then
        frame.TwichUITooltipFadeIn:Stop()
        frame:SetAlpha(1)
    end
    if frame and frame.TwichUITooltipChrome then
        frame.TwichUITooltipChrome:Hide()
    end
    if frame == GameTooltip and GameTooltipStatusBar and GameTooltipStatusBar.TwichUIBackdrop then
        GameTooltipStatusBar.TwichUIBackdrop:Hide()
    end
end

function TooltipModule:OnTooltipSetUnit(frame)
    if frame == GameTooltip then
        self:StyleStatusBar()
        self:ApplyUnitIdentity(frame)
    end
end

function TooltipModule:OnCombatStarted()
    local options = GetOptions()
    if not options or not options:GetHideInCombat() then
        return
    end

    for _, frame in ipairs(self:GetManagedFrames()) do
        if frame and frame.Hide then
            frame:Hide()
        end
    end
end

function TooltipModule:OnCombatEnded()
    self:UpdateAnchorVisibility()
end

function TooltipModule:OnThemeChanged(key)
    if key ~= nil and not THEME_KEYS[key] then
        return
    end

    self:RefreshAllTooltips()
end

function TooltipModule:BuildDesignerExtras()
    local options = GetOptions()
    if not options then
        return {}
    end

    return {
        {
            type = "section",
            tab = "Layout",
            label = "Anchor Behavior",
        },
        {
            label = "Anchor Mode",
            type = "select",
            tab = "Layout",
            values = {
                default = "Default",
                cursor = "Cursor",
                fixed = "Fixed Anchor",
            },
            valuesOrder = { "default", "cursor", "fixed" },
            get = function()
                return options:GetAnchorMode()
            end,
            set = function(value)
                options:SetAnchorMode(nil, value)
            end,
        },
        {
            label = "Tooltip Scale",
            type = "range",
            tab = "Layout",
            min = 0.8,
            max = 1.4,
            step = 0.01,
            get = function()
                return options:GetScale()
            end,
            set = function(value)
                options:SetScale(nil, value)
            end,
        },
        {
            label = "Cursor Offset X",
            type = "range",
            tab = "Layout",
            min = -40,
            max = 120,
            step = 1,
            hidden = function()
                return options:GetAnchorMode() ~= "cursor"
            end,
            get = function()
                return options:GetCursorOffsetX()
            end,
            set = function(value)
                options:SetCursorOffsetX(nil, value)
            end,
        },
        {
            label = "Cursor Offset Y",
            type = "range",
            tab = "Layout",
            min = -60,
            max = 80,
            step = 1,
            hidden = function()
                return options:GetAnchorMode() ~= "cursor"
            end,
            get = function()
                return options:GetCursorOffsetY()
            end,
            set = function(value)
                options:SetCursorOffsetY(nil, value)
            end,
        },
        {
            type = "section",
            tab = "Style",
            label = "Chrome",
        },
        {
            label = "Accent Trim",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetShowAccent()
            end,
            set = function(value)
                options:SetShowAccent(nil, value)
            end,
        },
        {
            label = "Class Tint Players",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetUsePlayerClassColors()
            end,
            set = function(value)
                options:SetUsePlayerClassColors(nil, value)
            end,
        },
        {
            label = "Class Icons",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetShowClassIcon()
            end,
            set = function(value)
                options:SetShowClassIcon(nil, value)
            end,
        },
        {
            label = "Class Icon Style",
            type = "select",
            tab = "Style",
            values = {
                global = "Global Appearance",
                default = "Default",
                fabled = "Fabled",
                pixel = "Pixel",
            },
            valuesOrder = { "global", "default", "fabled", "pixel" },
            hidden = function()
                return not options:GetShowClassIcon()
            end,
            get = function()
                return options:GetClassIconStyle()
            end,
            set = function(value)
                options:SetClassIconStyle(nil, value)
            end,
        },
        {
            label = "Hide In Combat",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetHideInCombat()
            end,
            set = function(value)
                options:SetHideInCombat(nil, value)
            end,
        },
        {
            label = "Fade In",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetEnableFadeIn()
            end,
            set = function(value)
                options:SetEnableFadeIn(nil, value)
            end,
        },
        {
            label = "Health Bar",
            type = "toggle",
            tab = "Style",
            get = function()
                return options:GetShowHealthBar()
            end,
            set = function(value)
                options:SetShowHealthBar(nil, value)
            end,
        },
        {
            label = "Bar Height",
            type = "range",
            tab = "Style",
            min = 5,
            max = 16,
            step = 1,
            get = function()
                return options:GetStatusBarHeight()
            end,
            set = function(value)
                options:SetStatusBarHeight(nil, value)
            end,
        },
        {
            type = "section",
            tab = "Content",
            label = "Enrichment",
        },
        {
            label = "Player Details",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowPlayerDetails()
            end,
            set = function(value)
                options:SetShowPlayerDetails(nil, value)
            end,
        },
        {
            label = "Faction Icon",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowFactionIcon()
            end,
            set = function(value)
                options:SetShowFactionIcon(nil, value)
            end,
        },
        {
            label = "Guild Rank",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowGuildRank()
            end,
            set = function(value)
                options:SetShowGuildRank(nil, value)
            end,
        },
        {
            label = "Mythic+ Score",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowMythicScore()
            end,
            set = function(value)
                options:SetShowMythicScore(nil, value)
            end,
        },
        {
            label = "Show Item Level",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowItemLevel()
            end,
            set = function(value)
                options:SetShowItemLevel(nil, value)
            end,
        },
        {
            label = "Transmog Status",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowTransmogStatus()
            end,
            set = function(value)
                options:SetShowTransmogStatus(nil, value)
            end,
        },
        {
            label = "Item Quality Border",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetUseItemQualityBorder()
            end,
            set = function(value)
                options:SetUseItemQualityBorder(nil, value)
            end,
        },
    }
end

function TooltipModule:OnEnable()
    self.registeredFrames = self.registeredFrames or {}
    self:CreateAnchor()
    for _, frame in ipairs(self:GetManagedFrames()) do
        self:RegisterManagedFrame(frame)
    end

    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStarted")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnded")
    self:SecureHook("GameTooltip_SetDefaultAnchor", "OnDefaultTooltipAnchor")
    if GameTooltipStatusBar and self:HasScript(GameTooltipStatusBar, "OnShow") then
        self:SecureHookScript(GameTooltipStatusBar, "OnShow", "OnStatusBarShow")
    end
    local moversModule = _G.TwichMoverModule
    if moversModule and type(moversModule.RegisterMover) == "function" then
        moversModule:RegisterMover("UI_tooltip_anchor", {
            label = "Tooltip Anchor",
            category = "Interface",
            headerToggle = {
                label = "Enabled",
                get = function()
                    local options = GetOptions()
                    return options and options:GetEnabled() or false
                end,
                set = function(value)
                    local options = GetOptions()
                    if options then
                        options:SetEnabled(nil, value)
                    end
                end,
            },
            headerAction = {
                label = "Preview",
                accent = { 0.95, 0.77, 0.28 },
                func = function()
                    self:ShowPreview()
                end,
                disabled = function()
                    local options = GetOptions()
                    return not options or not options:GetEnabled()
                end,
            },
            getFrame = function()
                return self:CreateAnchor()
            end,
            getX = function()
                local options = GetOptions()
                return options and options:GetAnchorX() or 1050
            end,
            getY = function()
                local options = GetOptions()
                return options and options:GetAnchorY() or 260
            end,
            getW = function()
                return 220
            end,
            getH = function()
                return 26
            end,
            setPos = function(x, y)
                local options = GetOptions()
                if options then
                    options:SetAnchorPosition(RoundPixel(x), RoundPixel(y))
                end
            end,
            isEnabled = function()
                local options = GetOptions()
                return options and options:GetEnabled() or false
            end,
            extras = self:BuildDesignerExtras(),
        })
    end

    self:RefreshAllTooltips()
end

function TooltipModule:OnDisable()
    self:UnregisterMessage("TWICH_THEME_CHANGED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnhookAll()
    if _G.TwichMoverModule and type(_G.TwichMoverModule.UnregisterMover) == "function" then
        _G.TwichMoverModule:UnregisterMover("UI_tooltip_anchor")
    end
    for _, frame in ipairs(self:GetManagedFrames()) do
        self:RestoreFrame(frame)
    end
    self:RestoreStatusBar()
    if self.anchor then
        self.anchor:Hide()
    end
end

function TooltipModule:OnStatusBarShow()
    local options = GetOptions()
    if options and not options:GetShowHealthBar() and GameTooltipStatusBar then
        GameTooltipStatusBar:Hide()
        GameTooltipStatusBar:SetAlpha(0)
    end
end
