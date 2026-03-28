---@diagnostic disable: undefined-field, undefined-global
--[[
    TwichUI Unit Frames (oUF)

    Provides standalone unit frames for player/target/focus/pet/ToT,
    castbar, party/raid/tank headers, and boss frames.

    This module is intentionally independent from ElvUI unitframe internals.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class UnitFramesModule : AceModule, AceEvent-3.0
local UnitFrames = T:NewModule("UnitFrames", "AceEvent-3.0")

local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UIParent = _G.UIParent
local UnitExists = _G.UnitExists
local UnitClass = _G.UnitClass
local UnitIsPlayer = _G.UnitIsPlayer
local StatusBarInterpolation = _G.StatusBarInterpolation
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local math_min = math.min
local math_max = math.max
local math_abs = math.abs

local STYLE_NAME = "TwichUI_Reformed_UnitFrames"

UnitFrames.styleRegistered = false
UnitFrames.frames = {}
UnitFrames.headers = {}
UnitFrames.previewFrames = {}
UnitFrames.movers = {}
UnitFrames._castbarState = nil

local PREVIEW_SINGLE_UNITS = {
    { key = "player", label = "Player" },
    { key = "target", label = "Target" },
    { key = "targettarget", label = "Target of Target" },
    { key = "focus", label = "Focus" },
    { key = "pet", label = "Pet" },
}

local function GetOUF()
    -- Embedded oUF in this addon lives on the addon namespace table (Engine),
    -- while some external layouts expose a global oUF. Support both.
    if TwichRx and type(TwichRx) == "table" and type(TwichRx.oUF) == "table" then
        return TwichRx.oUF
    end

    if type(_G.oUF) == "table" then
        return _G.oUF
    end

    -- Compatibility fallback for ElvUI environments.
    if type(_G.ElvUF) == "table" then
        return _G.ElvUF
    end

    return nil
end

local function Clamp(value, minimum, maximum)
    local numeric = tonumber(value)
    if numeric == nil then
        return minimum
    end

    local oUF = GetOUF()
    if oUF and type(oUF.CanAccessValue) == "function" then
        local ok, canAccess = pcall(oUF.CanAccessValue, oUF, numeric)
        if ok and canAccess == false then
            return minimum
        end
    end

    local okLess, isLess = pcall(function()
        return numeric < minimum
    end)
    if not okLess then
        return minimum
    end

    if isLess then
        return minimum
    end

    local okGreater, isGreater = pcall(function()
        return numeric > maximum
    end)
    if not okGreater then
        return maximum
    end

    if isGreater then
        return maximum
    end

    return numeric
end

local function CopyColor(color, fallback)
    local source = type(color) == "table" and color or fallback or { 1, 1, 1, 1 }
    return {
        source[1] or 1,
        source[2] or 1,
        source[3] or 1,
        source[4] or 1,
    }
end

local function GetLSMTexture(name)
    local LSM = T.Libs and T.Libs.LSM
    if not LSM or type(LSM.Fetch) ~= "function" then
        return "Interface\\TARGETINGFRAME\\UI-StatusBar"
    end

    local ok, texture = pcall(LSM.Fetch, LSM, "statusbar", name)
    if ok and type(texture) == "string" and texture ~= "" then
        return texture
    end

    return "Interface\\TARGETINGFRAME\\UI-StatusBar"
end

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function GetThemeColor(key, fallback)
    local theme = GetThemeModule()
    if not theme or type(theme.GetColor) ~= "function" then
        return CopyColor(fallback)
    end

    local color = theme:GetColor(key)
    if type(color) ~= "table" then
        return CopyColor(fallback)
    end

    return CopyColor(color)
end

local function GetThemeTexture()
    local theme = GetThemeModule()
    if not theme or type(theme.Get) ~= "function" then
        return GetLSMTexture("TwichUI-Smooth")
    end

    local textureName = theme:Get("statusBarTexture") or "TwichUI-Smooth"
    return GetLSMTexture(textureName)
end

local function EnsureBackdrop(frame)
    if frame.TwichBackdrop then
        return frame.TwichBackdrop
    end

    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    backdrop:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    backdrop:SetBackdropColor(0.06, 0.07, 0.09, 0.92)
    backdrop:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)

    frame.TwichBackdrop = backdrop
    return backdrop
end

local function BuildFrameName(unit)
    if unit == "targettarget" then
        return "Target of Target"
    end

    if unit == "pettarget" then
        return "Pet Target"
    end

    return unit and (unit:gsub("^%l", string.upper)) or "Unit"
end

local function ResolveScopeByUnitKey(unitKey)
    if unitKey == "partyMember" then
        return "party"
    end
    if unitKey == "raidMember" then
        return "raid"
    end
    if unitKey == "tankMember" then
        return "tank"
    end
    if unitKey == "boss" or (type(unitKey) == "string" and unitKey:match("^boss")) then
        return "boss"
    end
    return "singles"
end

function UnitFrames:GetOptions()
    local configuration = T:GetModule("Configuration")
    return configuration and configuration.Options and configuration.Options.UnitFrames or nil
end

function UnitFrames:GetDB()
    local options = self:GetOptions()
    if options and type(options.GetDB) == "function" then
        return options:GetDB()
    end

    return {}
end

function UnitFrames:GetUnitSettings(unit)
    local db = self:GetDB()
    db.units = db.units or {}
    db.units[unit] = db.units[unit] or {}
    return db.units[unit]
end

function UnitFrames:GetGroupSettings(group)
    local db = self:GetDB()
    db.groups = db.groups or {}
    db.groups[group] = db.groups[group] or {}
    return db.groups[group]
end

function UnitFrames:GetLayoutSettings(key)
    local db = self:GetDB()
    db.layout = db.layout or {}
    db.layout[key] = db.layout[key] or {}
    return db.layout[key]
end

function UnitFrames:GetPalette(scope, unit)
    local db = self:GetDB()
    db.colors = db.colors or {}

    local resolvedScope = scope or "singles"
    db.healthColorByScope = db.healthColorByScope or {}
    local healthScope = db.healthColorByScope[resolvedScope] or {}
    local mode = healthScope.mode or (db.useClassColor == true and "class" or "theme")

    local health = db.colors.health
    if mode == "custom" and type(healthScope.color) == "table" then
        health = healthScope.color
    elseif mode == "class" then
        local classToken = nil
        if unit and UnitIsPlayer and UnitIsPlayer(unit) then
            _, classToken = UnitClass(unit)
        end

        if not classToken then
            _, classToken = UnitClass("player")
        end

        local classColor = (_G.CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[classToken or ""]
        if classColor then
            health = { classColor.r, classColor.g, classColor.b, 1 }
        end
    end

    return {
        health = CopyColor(health or GetThemeColor("successColor", { 0.34, 0.84, 0.54, 1 })),
        power = CopyColor(db.colors.power or GetThemeColor("primaryColor", { 0.10, 0.72, 0.74, 1 })),
        cast = CopyColor(db.colors.cast or GetThemeColor("accentColor", { 0.96, 0.76, 0.24, 1 })),
        background = CopyColor(db.colors.background or GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08, 1 })),
        border = CopyColor(db.colors.border or GetThemeColor("borderColor", { 0.24, 0.26, 0.32, 1 })),
    }
end

function UnitFrames:ApplyStatusBarTexture(frame)
    local texture = GetThemeTexture()

    if frame.Health and frame.Health.SetStatusBarTexture then
        frame.Health:SetStatusBarTexture(texture)
    end

    if frame.Power and frame.Power.SetStatusBarTexture then
        frame.Power:SetStatusBarTexture(texture)
    end

    if frame.Castbar and frame.Castbar.SetStatusBarTexture then
        frame.Castbar:SetStatusBarTexture(texture)
    end
end

function UnitFrames:ApplyFrameColors(frame, unitKey)
    local palette = self:GetPalette(ResolveScopeByUnitKey(unitKey), frame and frame.unit)

    local backdrop = EnsureBackdrop(frame)
    backdrop:SetBackdropColor(palette.background[1], palette.background[2], palette.background[3], 0.9)
    backdrop:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 0.9)

    if frame.Health and frame.Health.SetStatusBarColor then
        frame.Health:SetStatusBarColor(palette.health[1], palette.health[2], palette.health[3], 1)
    end

    if frame.Power and frame.Power.SetStatusBarColor then
        frame.Power:SetStatusBarColor(palette.power[1], palette.power[2], palette.power[3], 1)
    end

    if frame.Castbar and frame.Castbar.SetStatusBarColor then
        frame.Castbar:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
    end
end

function UnitFrames:ApplyFontObject(fontString, size)
    if not fontString then
        return
    end

    local LSM = T.Libs and T.Libs.LSM
    local theme = GetThemeModule()
    local fontName = theme and theme.Get and theme:Get("globalFont") or "__default"
    local path = nil

    if LSM and type(LSM.Fetch) == "function" and fontName and fontName ~= "__default" then
        local ok, fetched = pcall(LSM.Fetch, LSM, "font", fontName)
        if ok and type(fetched) == "string" and fetched ~= "" then
            path = fetched
        end
    end

    if not path then
        path = _G.STANDARD_TEXT_FONT
    end

    fontString:SetFont(path, size or 11, "OUTLINE")
    fontString:SetShadowOffset(0, 0)
end

function UnitFrames:GetTextConfig()
    local db = self:GetDB()
    db.text = db.text or {}

    if db.text.nameFormat == nil then db.text.nameFormat = "full" end
    if db.text.healthFormat == nil then db.text.healthFormat = "percent" end
    if db.text.powerFormat == nil then db.text.powerFormat = "percent" end
    if db.text.nameFontSize == nil then db.text.nameFontSize = 11 end
    if db.text.healthFontSize == nil then db.text.healthFontSize = 10 end
    if db.text.powerFontSize == nil then db.text.powerFontSize = 9 end

    return db.text
end

function UnitFrames:GetTextConfigFor(unitKey)
    local root = self:GetTextConfig()
    local scope = ResolveScopeByUnitKey(unitKey)

    root.scopes = root.scopes or {}
    root.scopes[scope] = root.scopes[scope] or {}
    local scoped = root.scopes[scope]

    if scoped.nameFormat == nil then scoped.nameFormat = root.nameFormat or "full" end
    if scoped.healthFormat == nil then scoped.healthFormat = root.healthFormat or "percent" end
    if scoped.powerFormat == nil then scoped.powerFormat = root.powerFormat or "percent" end
    if scoped.nameFontSize == nil then scoped.nameFontSize = root.nameFontSize or 11 end
    if scoped.healthFontSize == nil then scoped.healthFontSize = root.healthFontSize or 10 end
    if scoped.powerFontSize == nil then scoped.powerFontSize = root.powerFontSize or 9 end

    return scoped
end

function UnitFrames:GetAuraConfigFor(unitKey)
    local db = self:GetDB()
    db.auras = db.auras or {}
    db.auras.scopes = db.auras.scopes or {}

    local scope = ResolveScopeByUnitKey(unitKey)
    db.auras.scopes[scope] = db.auras.scopes[scope] or {}
    local scoped = db.auras.scopes[scope]

    if scoped.enabled == nil then scoped.enabled = true end
    if scoped.maxIcons == nil then scoped.maxIcons = 8 end
    if scoped.iconSize == nil then scoped.iconSize = 18 end
    if scoped.spacing == nil then scoped.spacing = 2 end
    if scoped.yOffset == nil then scoped.yOffset = 6 end

    return scoped
end

local function BuildHealthTag(format)
    if format == "current" then
        return "[curhp]"
    end
    if format == "currentPercent" then
        return "[curhp] [perhp<$%]"
    end
    if format == "missing" then
        return "[missinghp]"
    end
    return "[perhp<$%]"
end

local function BuildPowerTag(format)
    if format == "current" then
        return "[curpp]"
    end
    if format == "currentPercent" then
        return "[curpp] [perpp<$%]"
    end
    if format == "missing" then
        return "[missingpp]"
    end
    return "[perpp<$%]"
end

local function BuildNameTag(format)
    if format == "short" then
        return "[name(8)]"
    end
    return "[name]"
end

function UnitFrames:ApplyTextTags(frame, unitKey)
    if not frame or type(frame.Tag) ~= "function" or type(frame.Untag) ~= "function" then
        return
    end

    local text = self:GetTextConfigFor(unitKey)
    local nameTag = BuildNameTag(text.nameFormat)
    local healthTag = BuildHealthTag(text.healthFormat)
    local powerTag = BuildPowerTag(text.powerFormat)

    if frame.Name then
        frame:Untag(frame.Name)
        frame:Tag(frame.Name, nameTag)
    end

    if frame.HealthValue then
        frame:Untag(frame.HealthValue)
        frame:Tag(frame.HealthValue, healthTag)
    end

    if frame.PowerValue then
        frame:Untag(frame.PowerValue)
        frame:Tag(frame.PowerValue, powerTag)
    end
end

function UnitFrames:ApplyFrameFonts(frame, unitKey)
    local text = self:GetTextConfigFor(unitKey)
    if frame.Name then
        self:ApplyFontObject(frame.Name, Clamp(text.nameFontSize or 11, 6, 28))
    end
    if frame.HealthValue then
        self:ApplyFontObject(frame.HealthValue, Clamp(text.healthFontSize or 10, 6, 28))
    end
    if frame.PowerValue then
        self:ApplyFontObject(frame.PowerValue, Clamp(text.powerFontSize or 9, 6, 28))
    end
end

function UnitFrames:ApplyAuraSettings(frame, unitKey)
    if not frame or not frame.Auras then
        return
    end

    local aura = self:GetAuraConfigFor(unitKey)
    frame.Auras:SetShown(aura.enabled ~= false)
    frame.Auras.size = Clamp(aura.iconSize or 18, 10, 40)
    frame.Auras.spacing = Clamp(aura.spacing or 2, 0, 8)
    frame.Auras.num = math_max(1, math.floor(tonumber(aura.maxIcons) or 8))

    frame.Auras:ClearAllPoints()
    frame.Auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, Clamp(aura.yOffset or 6, -20, 30))
    frame.Auras:SetHeight(frame.Auras.size)
    frame.Auras:SetWidth((frame.Auras.size * frame.Auras.num) + (frame.Auras.spacing * math_max(0, frame.Auras.num - 1)))

    if frame.Auras.ForceUpdate then
        frame.Auras:ForceUpdate()
    end
end

function UnitFrames:ApplyTagVisibility(frame)
    local db = self:GetDB()
    local showHealth = db.showHealthText ~= false
    local showPower = db.showPowerText ~= false

    if frame.HealthValue then
        frame.HealthValue:SetShown(showHealth)
    end

    if frame.PowerValue then
        frame.PowerValue:SetShown(showPower)
    end
end

function UnitFrames:ApplySmoothBarValue(bar, value, maxValue)
    if not bar or not bar.SetMinMaxValues or not bar.SetValue then
        return
    end

    local hasInterpolation = StatusBarInterpolation and StatusBarInterpolation.ExponentialEaseOut
    local smoothEnabled = self:GetDB().smoothBars ~= false and hasInterpolation
    local smoothingMethod = smoothEnabled and StatusBarInterpolation.ExponentialEaseOut or (StatusBarInterpolation and StatusBarInterpolation.Immediate or nil)

    bar.smoothing = smoothingMethod

    local okMinMax = pcall(bar.SetMinMaxValues, bar, 0, maxValue)
    if not okMinMax then
        pcall(bar.SetMinMaxValues, bar, 0, 1)
    end

    if smoothingMethod then
        local okSmoothed = pcall(bar.SetValue, bar, value, smoothingMethod)
        if okSmoothed then
            return
        end
    end

    pcall(bar.SetValue, bar, value)
end

function UnitFrames:StopSmoothBar(bar)
    if not bar then
        return
    end

    bar.smoothing = nil
end

function UnitFrames:ApplyUnitFrameSize(frame, settings)
    local width = Clamp(settings.width or 220, 80, 600)
    local height = Clamp(settings.height or 42, 16, 180)

    frame:SetSize(width, height)

    if frame.Health and frame.Power then
        local powerHeight = settings.showPower == false and 0 or Clamp(settings.powerHeight or 10, 4, 32)
        frame.Health:ClearAllPoints()
        frame.Power:ClearAllPoints()

        if powerHeight > 0 then
            frame.Power:Show()
            frame.Power:SetHeight(powerHeight)

            frame.Power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            frame.Power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

            frame.Health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.Health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            frame.Health:SetPoint("BOTTOM", frame.Power, "TOP", 0, 1)
        else
            frame.Power:Hide()
            frame.Power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
            frame.Power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            frame.Health:SetAllPoints(frame)
        end
    end
end

function UnitFrames:ApplySingleFrameSettings(frame, unitKey)
    local settings = nil
    if unitKey and unitKey:match("^boss%d+$") then
        settings = self:GetUnitSettings("boss")
    elseif unitKey == "partyMember" then
        local group = self:GetGroupSettings("party")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = true,
            powerHeight = 8,
        }
    elseif unitKey == "raidMember" then
        local group = self:GetGroupSettings("raid")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = true,
            powerHeight = 7,
        }
    elseif unitKey == "tankMember" then
        local group = self:GetGroupSettings("tank")
        settings = {
            enabled = group.enabled,
            width = group.width,
            height = group.height,
            showPower = true,
            powerHeight = 8,
        }
    else
        settings = self:GetUnitSettings(unitKey)
    end

    local layout = self:GetLayoutSettings(unitKey)

    self:ApplyUnitFrameSize(frame, settings)

    if not frame.isHeaderChild then
        frame:ClearAllPoints()
        frame:SetPoint(
            layout.point or "BOTTOM",
            UIParent,
            layout.relativePoint or "BOTTOM",
            tonumber(layout.x) or 0,
            tonumber(layout.y) or 0
        )
    end

    local db = self:GetDB()
    frame:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
    frame:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))

    -- In test mode all live frames are hidden; dedicated preview frames handle visuals.
    local shouldShow = settings.enabled ~= false
    if db.testMode == true then
        shouldShow = false
    end

    frame:SetShown(shouldShow)

    self:ApplyStatusBarTexture(frame)
    self:ApplyFrameColors(frame, unitKey)
    self:ApplyFrameFonts(frame, unitKey)
    self:ApplyTextTags(frame, unitKey)
    self:ApplyAuraSettings(frame, unitKey)
    self:ApplyTagVisibility(frame)
end

function UnitFrames:ApplyHeaderSettings(header, groupKey)
    local settings = self:GetGroupSettings(groupKey)
    local layout = self:GetLayoutSettings(groupKey)

    header:ClearAllPoints()
    header:SetPoint(
        layout.point or "CENTER",
        UIParent,
        layout.relativePoint or "CENTER",
        tonumber(layout.x) or 0,
        tonumber(layout.y) or 0
    )

    header:SetAttribute("point", settings.point or "TOP")
    header:SetAttribute("xOffset", tonumber(settings.xOffset) or 0)
    header:SetAttribute("yOffset", tonumber(settings.yOffset) or -6)
    header:SetAttribute("unitsPerColumn", math_max(1, tonumber(settings.unitsPerColumn) or 5))
    header:SetAttribute("maxColumns", math_max(1, tonumber(settings.maxColumns) or 1))
    header:SetAttribute("columnSpacing", tonumber(settings.columnSpacing) or 8)
    header:SetAttribute("columnAnchorPoint", settings.columnAnchorPoint or "LEFT")

    if groupKey == "party" then
        header:SetAttribute("showParty", settings.enabled ~= false)
        header:SetAttribute("showPlayer", settings.showPlayer == true)
        header:SetAttribute("showSolo", settings.showSolo == true)
    elseif groupKey == "raid" then
        header:SetAttribute("showRaid", settings.enabled ~= false)
        header:SetAttribute("showParty", false)
        header:SetAttribute("showSolo", settings.showSolo == true)
        header:SetAttribute("groupBy", settings.groupBy or "GROUP")
        header:SetAttribute("groupingOrder", settings.groupingOrder or "1,2,3,4,5,6,7,8")
    elseif groupKey == "tank" then
        header:SetAttribute("showRaid", settings.enabled ~= false)
        header:SetAttribute("showParty", false)
        header:SetAttribute("showSolo", settings.showSolo == true)
        header:SetAttribute("groupFilter", settings.groupFilter or "MAINTANK,MAINASSIST")
    end

    header:SetScale(Clamp(self:GetDB().scale or 1, 0.6, 1.6))
    header:SetAlpha(Clamp(self:GetDB().frameAlpha or 1, 0.15, 1))
end

function UnitFrames:ApplyBossLayout()
    if not self.bossAnchor then
        return
    end

    local layout = self:GetLayoutSettings("boss")
    local settings = self:GetGroupSettings("boss")

    self.bossAnchor:ClearAllPoints()
    self.bossAnchor:SetPoint(
        layout.point or "RIGHT",
        UIParent,
        layout.relativePoint or "RIGHT",
        tonumber(layout.x) or -300,
        tonumber(layout.y) or 0
    )

    self.bossAnchor:SetScale(Clamp(self:GetDB().scale or 1, 0.6, 1.6))
    self.bossAnchor:SetAlpha(Clamp(self:GetDB().frameAlpha or 1, 0.15, 1))
    self.bossAnchor:SetShown(settings.enabled ~= false)

    local yOffset = tonumber(settings.yOffset) or -8
    for index = 1, 5 do
        local frame = self.frames["boss" .. index]
        if frame then
            frame:ClearAllPoints()
            if index == 1 then
                frame:SetPoint("TOP", self.bossAnchor, "TOP", 0, 0)
            else
                frame:SetPoint("TOP", self.frames["boss" .. (index - 1)], "BOTTOM", 0, yOffset)
            end
            frame:SetShown(settings.enabled ~= false)
        end
    end
end

function UnitFrames:PersistLayoutFromFrame(layoutKey, frame, absX, absY)
    local layout = self:GetLayoutSettings(layoutKey)
    layout.point = "BOTTOMLEFT"
    layout.relativePoint = "BOTTOMLEFT"
    layout.x = math.floor((absX or 0) + 0.5)
    layout.y = math.floor((absY or 0) + 0.5)

    if frame and frame.GetWidth and frame.GetHeight then
        local width = frame:GetWidth()
        local height = frame:GetHeight()
        if width and width > 0 then
            local unitSettings = self:GetUnitSettings(layoutKey)
            if unitSettings and unitSettings.width ~= nil then
                unitSettings.width = math.floor(width + 0.5)
            end
        end
        if height and height > 0 then
            local unitSettings = self:GetUnitSettings(layoutKey)
            if unitSettings and unitSettings.height ~= nil then
                unitSettings.height = math.floor(height + 0.5)
            end
        end
    end
end

function UnitFrames:AttachMover(frame, layoutKey)
    if not frame or self.movers[layoutKey] then
        return
    end

    local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetFrameStrata("HIGH")
    mover:SetFrameLevel(250)
    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    mover:SetBackdropColor(0.10, 0.72, 0.74, 0.12)
    mover:SetBackdropBorderColor(0.10, 0.72, 0.74, 0.85)

    mover.label = mover:CreateFontString(nil, "OVERLAY")
    mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
    self:ApplyFontObject(mover.label, 11)
    mover.label:SetText(BuildFrameName(layoutKey))

    mover:SetScript("OnMouseDown", function(selfFrame)
        if InCombatLockdown() then
            return
        end

        selfFrame:StartMoving()
        selfFrame.isMoving = true
    end)

    mover:SetScript("OnMouseUp", function(selfFrame)
        if not selfFrame.isMoving then
            return
        end

        selfFrame:StopMovingOrSizing()
        selfFrame.isMoving = false

        local x = selfFrame:GetLeft() or 0
        local y = selfFrame:GetBottom() or 0

        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)

        UnitFrames:PersistLayoutFromFrame(layoutKey, frame, x, y)
    end)

    mover:EnableMouse(true)
    mover:SetMovable(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", mover:GetScript("OnMouseDown"))
    mover:SetScript("OnDragStop", mover:GetScript("OnMouseUp"))

    self.movers[layoutKey] = mover
end

function UnitFrames:UpdateMovers()
    local db = self:GetDB()
    local showMovers = db.lockFrames ~= true

    for layoutKey, frame in pairs(self.frames) do
        if not self.movers[layoutKey] then
            self:AttachMover(frame, layoutKey)
        end

        local mover = self.movers[layoutKey]
        if mover and frame then
            mover:ClearAllPoints()
            mover:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            mover:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            mover:SetShown(showMovers and frame:IsShown())
        end
    end

    for _, mover in pairs(self.movers) do
        if mover and not showMovers then
            mover:Hide()
        end
    end
end

function UnitFrames:RegisterLayoutFrame(layoutKey, frame)
    local setupWizard = T:GetModule("SetupWizard", true)
    if not setupWizard or not frame then
        return
    end

    setupWizard:RegisterLayoutFrame("UF_" .. layoutKey, frame, function(absX, absY, absW, absH)
        local layout = UnitFrames:GetLayoutSettings(layoutKey)
        layout.point = "BOTTOMLEFT"
        layout.relativePoint = "BOTTOMLEFT"
        layout.x = math.floor((absX or 0) + 0.5)
        layout.y = math.floor((absY or 0) + 0.5)

        if layoutKey == "party" or layoutKey == "raid" or layoutKey == "tank" or layoutKey == "boss" then
            return
        end

        local unitSettings = UnitFrames:GetUnitSettings(layoutKey)
        if absW and absW > 20 then
            unitSettings.width = math.floor(absW + 0.5)
        end
        if absH and absH > 12 then
            unitSettings.height = math.floor(absH + 0.5)
        end
    end)
end

function UnitFrames:CreatePreviewFrame(parent, width, height, label)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(0.05, 0.06, 0.08, 0.9)
    frame:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.9)

    local hp = CreateFrame("StatusBar", nil, frame)
    hp:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    hp:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    hp:SetHeight(math_max(8, height - 12))
    hp:SetStatusBarTexture(GetThemeTexture())
    hp:SetStatusBarColor(0.34, 0.84, 0.54, 1)
    hp:SetMinMaxValues(0, 100)
    hp:SetValue(70)

    local pw = CreateFrame("StatusBar", nil, frame)
    pw:SetPoint("TOPLEFT", hp, "BOTTOMLEFT", 0, -1)
    pw:SetPoint("TOPRIGHT", hp, "BOTTOMRIGHT", 0, -1)
    pw:SetHeight(8)
    pw:SetStatusBarTexture(GetThemeTexture())
    pw:SetStatusBarColor(0.10, 0.72, 0.74, 1)
    pw:SetMinMaxValues(0, 100)
    pw:SetValue(45)

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", frame, "LEFT", 6, 0)
    self:ApplyFontObject(text, 10)
    text:SetText(label)

    frame.HealthBar = hp
    frame.PowerBar = pw
    frame.Label = text

    return frame
end

function UnitFrames:UpdatePreviewFrame(frame, width, height, label)
    if not frame then
        return
    end

    frame:SetSize(width, height)

    if frame.HealthBar then
        frame.HealthBar:SetHeight(math_max(8, height - 12))
        frame.HealthBar:SetStatusBarTexture(GetThemeTexture())
    end

    if frame.PowerBar then
        frame.PowerBar:SetStatusBarTexture(GetThemeTexture())
    end

    if frame.Label then
        frame.Label:SetText(label or "Preview")
    end
end

function UnitFrames:BuildOrRefreshSinglePreviews()
    local preview = self.previewFrames
    local db = self:GetDB()

    for _, entry in ipairs(PREVIEW_SINGLE_UNITS) do
        local settings = self:GetUnitSettings(entry.key)
        local layout = self:GetLayoutSettings(entry.key)
        local width = Clamp(settings.width or 220, 80, 600)
        local height = Clamp(settings.height or 42, 16, 180)

        if not preview[entry.key] then
            preview[entry.key] = self:CreatePreviewFrame(UIParent, width, height, entry.label)
        else
            self:UpdatePreviewFrame(preview[entry.key], width, height, entry.label)
        end

        local frame = preview[entry.key]
        frame:ClearAllPoints()
        frame:SetPoint(
            layout.point or "BOTTOM",
            UIParent,
            layout.relativePoint or "BOTTOM",
            tonumber(layout.x) or 0,
            tonumber(layout.y) or 0
        )
        frame:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
        frame:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))
    end

    if not preview.castbar then
        preview.castbar = CreateFrame("StatusBar", nil, UIParent, "BackdropTemplate")
        preview.castbar:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        preview.castbar.bg = preview.castbar:CreateTexture(nil, "BACKGROUND")
        preview.castbar.bg:SetAllPoints(preview.castbar)
        preview.castbar.bg:SetColorTexture(0.05, 0.06, 0.08, 0.9)

        preview.castbar.icon = preview.castbar:CreateTexture(nil, "ARTWORK")
        preview.castbar.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        preview.castbar.icon:SetPoint("RIGHT", preview.castbar, "LEFT", -6, 0)
        preview.castbar.icon:SetSize(20, 20)
        preview.castbar.icon:SetTexture(136243)

        preview.castbar.spellText = preview.castbar:CreateFontString(nil, "OVERLAY")
        preview.castbar.spellText:SetPoint("LEFT", preview.castbar, "LEFT", 6, 0)
        self:ApplyFontObject(preview.castbar.spellText, 11)

        preview.castbar.timeText = preview.castbar:CreateFontString(nil, "OVERLAY")
        preview.castbar.timeText:SetPoint("RIGHT", preview.castbar, "RIGHT", -6, 0)
        self:ApplyFontObject(preview.castbar.timeText, 10)
    end

    do
        local castSettings = db.castbar or {}
        local layout = self:GetLayoutSettings("castbar")
        local palette = self:GetPalette("singles")
        local castPreview = preview.castbar
        castPreview:ClearAllPoints()
        castPreview:SetPoint(
            layout.point or "BOTTOM",
            UIParent,
            layout.relativePoint or "BOTTOM",
            tonumber(layout.x) or -260,
            tonumber(layout.y) or 220
        )
        castPreview:SetSize(Clamp(castSettings.width or 260, 120, 600), Clamp(castSettings.height or 20, 10, 60))
        castPreview:SetStatusBarTexture(GetThemeTexture())
        if castSettings.useCustomColor == true and type(castSettings.color) == "table" then
            castPreview:SetStatusBarColor(castSettings.color[1] or 1, castSettings.color[2] or 1, castSettings.color[3] or 1, castSettings.color[4] or 1)
        else
            castPreview:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
        end
        castPreview:SetMinMaxValues(0, 100)
        castPreview:SetValue(64)
        castPreview.spellText:SetText("Shadow Bolt")
        castPreview.timeText:SetText("1.4")
        castPreview.spellText:SetShown(castSettings.showSpellText ~= false)
        castPreview.timeText:SetShown(castSettings.showTimeText ~= false)
        self:ApplyFontObject(castPreview.spellText, Clamp(castSettings.spellFontSize or 11, 6, 24))
        self:ApplyFontObject(castPreview.timeText, Clamp(castSettings.timeFontSize or 10, 6, 24))
        if castPreview.icon then
            local iconSize = Clamp(castSettings.iconSize or castSettings.height or 20, 12, 50)
            castPreview.icon:SetSize(iconSize, iconSize)
            castPreview.icon:SetShown(castSettings.showIcon ~= false)
        end
        castPreview:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
        castPreview:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))
    end

    if not preview.bossAnchor then
        preview.bossAnchor = CreateFrame("Frame", nil, UIParent)
    end

    do
        local bossLayout = self:GetLayoutSettings("boss")
        local bossGroup = self:GetGroupSettings("boss")
        local bossUnit = self:GetUnitSettings("boss")
        local width = Clamp(bossUnit.width or 220, 120, 500)
        local height = Clamp(bossUnit.height or 36, 16, 120)
        local yOffset = tonumber(bossGroup.yOffset) or -8

        preview.bossAnchor:ClearAllPoints()
        preview.bossAnchor:SetPoint(
            bossLayout.point or "RIGHT",
            UIParent,
            bossLayout.relativePoint or "RIGHT",
            tonumber(bossLayout.x) or -60,
            tonumber(bossLayout.y) or 520
        )
        preview.bossAnchor:SetSize(width, (height + math.abs(yOffset)) * 5)

        for index = 1, 5 do
            local key = "bossPreview" .. index
            if not preview[key] then
                preview[key] = self:CreatePreviewFrame(preview.bossAnchor, width, height, "Boss " .. index)
            else
                self:UpdatePreviewFrame(preview[key], width, height, "Boss " .. index)
            end

            preview[key]:ClearAllPoints()
            if index == 1 then
                preview[key]:SetPoint("TOP", preview.bossAnchor, "TOP", 0, 0)
            else
                preview[key]:SetPoint("TOP", preview["bossPreview" .. (index - 1)], "BOTTOM", 0, yOffset)
            end
            preview[key]:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
            preview[key]:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))
        end
    end
end

function UnitFrames:BuildPreviewGroups()
    local preview = self.previewFrames

    local function EnsureContainer(key)
        if not preview[key] then
            preview[key] = CreateFrame("Frame", nil, UIParent)
            preview[key].rows = {}
        end
        return preview[key]
    end

    local function PositionContainer(container, layout)
        container:ClearAllPoints()
        container:SetPoint(
            layout.point or "CENTER",
            UIParent,
            layout.relativePoint or "CENTER",
            tonumber(layout.x) or 0,
            tonumber(layout.y) or 0
        )
    end

    local party = EnsureContainer("party")
    do
        local settings = self:GetGroupSettings("party")
        local layout = self:GetLayoutSettings("party")
        local width = Clamp(settings.width or 180, 80, 500)
        local height = Clamp(settings.height or 36, 14, 120)
        local yOffset = tonumber(settings.yOffset) or -6
        PositionContainer(party, layout)
        party:SetSize(width, (height + math_abs(yOffset)) * 5)
        for index = 1, 5 do
            if not party.rows[index] then
                party.rows[index] = self:CreatePreviewFrame(party, width, height, "Party " .. index)
            else
                self:UpdatePreviewFrame(party.rows[index], width, height, "Party " .. index)
            end
            local row = party.rows[index]
            row:ClearAllPoints()
            if index == 1 then
                row:SetPoint("TOP", party, "TOP", 0, 0)
            else
                row:SetPoint("TOP", party.rows[index - 1], "BOTTOM", 0, yOffset)
            end
            row:SetShown(true)
        end
    end

    local raid = EnsureContainer("raid")
    do
        local settings = self:GetGroupSettings("raid")
        local layout = self:GetLayoutSettings("raid")
        local width = Clamp(settings.width or 120, 70, 300)
        local height = Clamp(settings.height or 30, 14, 80)
        local yOffset = tonumber(settings.yOffset) or -6
        local colSpacing = tonumber(settings.columnSpacing) or 6
        local unitsPerColumn = math_max(1, tonumber(settings.unitsPerColumn) or 5)
        local maxColumns = math_max(1, tonumber(settings.maxColumns) or 4)
        PositionContainer(raid, layout)
        raid:SetSize((width + colSpacing) * maxColumns, (height + math_abs(yOffset)) * unitsPerColumn)
        for index = 1, 20 do
            if not raid.rows[index] then
                raid.rows[index] = self:CreatePreviewFrame(raid, width, height, "Raid " .. index)
            else
                self:UpdatePreviewFrame(raid.rows[index], width, height, "Raid " .. index)
            end
            local row = raid.rows[index]
            local column = math.floor((index - 1) / unitsPerColumn)
            local rowIndex = (index - 1) % unitsPerColumn
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", raid, "TOPLEFT", column * (width + colSpacing), -(rowIndex * (height + math_abs(yOffset))))
            row:SetShown(column < maxColumns)
        end
    end

    local tank = EnsureContainer("tank")
    do
        local settings = self:GetGroupSettings("tank")
        local layout = self:GetLayoutSettings("tank")
        local width = Clamp(settings.width or 180, 80, 400)
        local height = Clamp(settings.height or 32, 14, 80)
        local yOffset = tonumber(settings.yOffset) or -6
        PositionContainer(tank, layout)
        tank:SetSize(width, (height + math_abs(yOffset)) * 2)
        for index = 1, 2 do
            if not tank.rows[index] then
                tank.rows[index] = self:CreatePreviewFrame(tank, width, height, "Tank " .. index)
            else
                self:UpdatePreviewFrame(tank.rows[index], width, height, "Tank " .. index)
            end
            local row = tank.rows[index]
            row:ClearAllPoints()
            if index == 1 then
                row:SetPoint("TOP", tank, "TOP", 0, 0)
            else
                row:SetPoint("TOP", tank.rows[index - 1], "BOTTOM", 0, yOffset)
            end
            row:SetShown(true)
        end
    end
end

function UnitFrames:RefreshPreviewVisibility()
    self:BuildPreviewGroups()
    self:BuildOrRefreshSinglePreviews()

    local db = self:GetDB()
    local showPreview = db.testMode == true

    for key, container in pairs(self.previewFrames) do
        if container then
            local shouldShow = showPreview
            if key == "castbar" then
                shouldShow = shouldShow and ((db.castbar and db.castbar.enabled ~= false) ~= false)
            elseif key:match("^bossPreview") then
                shouldShow = shouldShow and (self:GetGroupSettings("boss").enabled ~= false)
            elseif key == "bossAnchor" then
                shouldShow = shouldShow and (self:GetGroupSettings("boss").enabled ~= false)
            elseif key == "player" or key == "target" or key == "targettarget" or key == "focus" or key == "pet" then
                shouldShow = shouldShow and (self:GetUnitSettings(key).enabled ~= false)
            elseif key == "party" or key == "raid" or key == "tank" then
                shouldShow = shouldShow and (self:GetGroupSettings(key).enabled ~= false)
            end
            container:SetShown(shouldShow)
        end
    end
end

function UnitFrames:ApplyTestModeToSingles()
    -- Test mode visuals are handled via dedicated preview frames so live oUF
    -- visibility logic cannot hide or taint inactive units.
end

function UnitFrames:RefreshAllFrames()
    if InCombatLockdown() then
        self._queuedRefresh = true
        return
    end

    for unitKey, frame in pairs(self.frames) do
        if unitKey ~= "castbar" then
            self:ApplySingleFrameSettings(frame, unitKey)
        end
    end

    for groupKey, header in pairs(self.headers) do
        self:ApplyHeaderSettings(header, groupKey)
    end

    self:ApplyBossLayout()
    self:RefreshCastbarLayout()
    self:RefreshCastbarStyle()
    self:RefreshPreviewVisibility()
    self:ApplyTestModeToSingles()
    self:UpdateMovers()
end

function UnitFrames:OnThemeChanged()
    self:RefreshAllFrames()
end

function UnitFrames:OnConfigRestored()
    self:RefreshAllFrames()
end

function UnitFrames:StyleFrame(frame)
    local unit = frame.unit or "unit"
    local unitKey = unit
    local parent = frame:GetParent()

    if parent and self.headers.party and parent == self.headers.party then
        unitKey = "partyMember"
        frame.isHeaderChild = true
    elseif parent and self.headers.raid and parent == self.headers.raid then
        unitKey = "raidMember"
        frame.isHeaderChild = true
    elseif parent and self.headers.tank and parent == self.headers.tank then
        unitKey = "tankMember"
        frame.isHeaderChild = true
    elseif unit:match("^boss") then
        unitKey = "boss"
    end

    frame:SetAttribute("useparent-unit", true)
    frame:RegisterForClicks("AnyUp")

    local health = CreateFrame("StatusBar", nil, frame)
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    health:SetHeight(30)
    health.frequentUpdates = true
    health.PostUpdate = function(healthBar, unit, cur, max)
        UnitFrames:ApplySmoothBarValue(healthBar, cur, max)
    end
    frame.Health = health

    local power = CreateFrame("StatusBar", nil, frame)
    power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -1)
    power:SetPoint("TOPRIGHT", health, "BOTTOMRIGHT", 0, -1)
    power:SetHeight(10)
    power.frequentUpdates = true
    power.PostUpdate = function(powerBar, unit, cur, max)
        UnitFrames:ApplySmoothBarValue(powerBar, cur, max)
    end
    frame.Power = power

    local name = health:CreateFontString(nil, "OVERLAY")
    name:SetPoint("LEFT", health, "LEFT", 4, 0)
    name:SetPoint("RIGHT", health, "RIGHT", -56, 0)
    name:SetJustifyH("LEFT")
    frame.Name = name

    local healthValue = health:CreateFontString(nil, "OVERLAY")
    healthValue:SetPoint("RIGHT", health, "RIGHT", -4, 0)
    healthValue:SetJustifyH("RIGHT")
    frame.HealthValue = healthValue

    local powerValue = power:CreateFontString(nil, "OVERLAY")
    powerValue:SetPoint("RIGHT", power, "RIGHT", -4, 0)
    powerValue:SetJustifyH("RIGHT")
    frame.PowerValue = powerValue

    local auras = CreateFrame("Frame", nil, frame)
    auras:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 6)
    auras:SetHeight(18)
    auras:SetWidth(160)
    auras.initialAnchor = "BOTTOMLEFT"
    auras["growth-x"] = "RIGHT"
    auras["growth-y"] = "UP"
    auras.size = 18
    auras.spacing = 2
    auras.num = 8
    frame.Auras = auras

    EnsureBackdrop(frame)
    self:ApplyFrameFonts(frame, unitKey)
    self:ApplyTextTags(frame, unitKey)
    self:ApplySingleFrameSettings(frame, unitKey)
end

function UnitFrames:CreateCastbarFrame()
    if self.frames.castbar then
        return self.frames.castbar
    end

    local frame = CreateFrame("StatusBar", "TwichUIUnitFramesPlayerCastbar", UIParent, "BackdropTemplate")
    frame:SetMinMaxValues(0, 1)
    frame:SetValue(0)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints(frame)
    frame.bg:SetColorTexture(0.05, 0.06, 0.08, 0.9)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("RIGHT", frame, "LEFT", -6, 0)
    frame.icon:SetSize(20, 20)
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.spellText = frame:CreateFontString(nil, "OVERLAY")
    frame.spellText:SetPoint("LEFT", frame, "LEFT", 6, 0)

    frame.timeText = frame:CreateFontString(nil, "OVERLAY")
    frame.timeText:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

    self:ApplyFontObject(frame.spellText, 11)
    self:ApplyFontObject(frame.timeText, 10)

    self.frames.castbar = frame
    self:RegisterLayoutFrame("castbar", frame)
    return frame
end

function UnitFrames:RefreshCastbarLayout()
    local castbar = self:CreateCastbarFrame()
    local db = self:GetDB()
    local settings = db.castbar or {}
    local layout = self:GetLayoutSettings("castbar")

    castbar:ClearAllPoints()
    castbar:SetPoint(
        layout.point or "BOTTOM",
        UIParent,
        layout.relativePoint or "BOTTOM",
        tonumber(layout.x) or -260,
        tonumber(layout.y) or 220
    )

    castbar:SetSize(Clamp(settings.width or 260, 120, 600), Clamp(settings.height or 20, 10, 60))
    castbar:SetShown(settings.enabled ~= false)
    castbar:SetScale(Clamp(db.scale or 1, 0.6, 1.6))
    castbar:SetAlpha(Clamp(db.frameAlpha or 1, 0.15, 1))

    local iconSize = Clamp(settings.iconSize or settings.height or 20, 12, 50)
    if castbar.icon then
        castbar.icon:SetSize(iconSize, iconSize)
        castbar.icon:SetShown(settings.showIcon ~= false)
    end

    castbar.spellText:ClearAllPoints()
    if settings.showIcon ~= false then
        castbar.spellText:SetPoint("LEFT", castbar, "LEFT", 6, 0)
    else
        castbar.spellText:SetPoint("LEFT", castbar, "LEFT", 6, 0)
    end

    castbar.timeText:ClearAllPoints()
    castbar.timeText:SetPoint("RIGHT", castbar, "RIGHT", -6, 0)
end

function UnitFrames:RefreshCastbarStyle()
    local castbar = self:CreateCastbarFrame()
    local settings = self:GetDB().castbar or {}
    local palette = self:GetPalette()

    castbar:SetStatusBarTexture(GetThemeTexture())
    if settings.useCustomColor == true and type(settings.color) == "table" then
        castbar:SetStatusBarColor(settings.color[1] or 1, settings.color[2] or 1, settings.color[3] or 1, settings.color[4] or 1)
    else
        castbar:SetStatusBarColor(palette.cast[1], palette.cast[2], palette.cast[3], 1)
    end
    castbar:SetBackdropColor(palette.background[1], palette.background[2], palette.background[3], 0.9)
    castbar:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 0.9)

    castbar.spellText:SetShown(settings.showSpellText ~= false)
    castbar.timeText:SetShown(settings.showTimeText ~= false)

    self:ApplyFontObject(castbar.spellText, Clamp(settings.spellFontSize or 11, 6, 24))
    self:ApplyFontObject(castbar.timeText, Clamp(settings.timeFontSize or 10, 6, 24))
end

function UnitFrames:UpdateCastbarElapsed()
    local state = self._castbarState
    local castbar = self.frames.castbar
    if not state or not castbar then
        return
    end

    local duration = math_max(0.001, state.endTime - state.startTime)
    local now = GetTimePreciseSec()

    if now >= state.endTime then
        castbar:SetValue(1)
        castbar.timeText:SetText("0.0")
        castbar:Hide()
        self._castbarState = nil
        return
    end

    local value = (now - state.startTime) / duration
    castbar:SetValue(math_max(0, math_min(1, value)))
    castbar.timeText:SetText(string.format("%.1f", state.endTime - now))
end

function UnitFrames:BeginCastbar(name, icon, startMS, endMS, reverse)
    local castbar = self.frames.castbar
    if not castbar then
        return
    end

    local startSec = (tonumber(startMS) or 0) / 1000
    local endSec = (tonumber(endMS) or 0) / 1000

    if startSec <= 0 or endSec <= startSec then
        return
    end

    castbar.spellText:SetText(name or "Casting")
    if castbar.icon then
        castbar.icon:SetTexture(icon or 136243)
    end
    castbar:SetMinMaxValues(0, 1)
    castbar:SetValue(reverse and 1 or 0)
    castbar:Show()

    self._castbarState = {
        startTime = startSec,
        endTime = endSec,
        reverse = reverse == true,
    }
end

function UnitFrames:StopCastbar()
    local castbar = self.frames.castbar
    if castbar then
        castbar:Hide()
    end
    self._castbarState = nil
end

function UnitFrames:HandlePlayerCastEvent(event, unit, castGUID, spellID)
    if unit and unit ~= "player" then
        return
    end

    if event == "UNIT_SPELLCAST_START" then
        local name, _, texture, startMS, endMS = UnitCastingInfo("player")
        if name then
            self:BeginCastbar(name, texture, startMS, endMS, false)
        end
        return
    end

    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        local name, _, texture, startMS, endMS = UnitChannelInfo("player")
        if name then
            self:BeginCastbar(name, texture, startMS, endMS, true)
        end
        return
    end

    if event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    then
        self:StopCastbar()
        return
    end
end

function UnitFrames:SpawnSingleFrame(oUF, unit, key)
    local frame = oUF:Spawn(unit, "TwichUIUF_" .. key)
    frame.key = key
    self.frames[key] = frame
    self:RegisterLayoutFrame(key, frame)
    return frame
end

function UnitFrames:SpawnBossFrames(oUF)
    if self.bossAnchor then
        return
    end

    self.bossAnchor = CreateFrame("Frame", "TwichUIUF_BossAnchor", UIParent)
    self.bossAnchor:SetSize(260, 220)
    self:RegisterLayoutFrame("boss", self.bossAnchor)

    for index = 1, 5 do
        local key = "boss" .. index
        local frame = self:SpawnSingleFrame(oUF, key, key)
        if index == 1 then
            frame:SetPoint("TOP", self.bossAnchor, "TOP", 0, 0)
        else
            frame:SetPoint("TOP", self.frames["boss" .. (index - 1)], "BOTTOM", 0, -8)
        end
    end
end

function UnitFrames:SpawnHeaders(oUF)
    if self.headers.party then
        return
    end

    self.headers.party = oUF:SpawnHeader(
        "TwichUIUF_PartyHeader",
        nil,
        "showParty", true,
        "showPlayer", true,
        "showSolo", false,
        "yOffset", -8,
        "point", "TOP"
    )

    self.headers.raid = oUF:SpawnHeader(
        "TwichUIUF_RaidHeader",
        nil,
        "showRaid", true,
        "showParty", false,
        "showSolo", false,
        "groupBy", "GROUP",
        "groupingOrder", "1,2,3,4,5,6,7,8",
        "yOffset", -6,
        "point", "TOP",
        "maxColumns", 8,
        "unitsPerColumn", 5
    )

    self.headers.tank = oUF:SpawnHeader(
        "TwichUIUF_TankHeader",
        nil,
        "showRaid", true,
        "showParty", false,
        "showSolo", false,
        "groupFilter", "MAINTANK,MAINASSIST",
        "yOffset", -6,
        "point", "TOP",
        "maxColumns", 1,
        "unitsPerColumn", 8
    )

    self:RegisterLayoutFrame("party", self.headers.party)
    self:RegisterLayoutFrame("raid", self.headers.raid)
    self:RegisterLayoutFrame("tank", self.headers.tank)
end

function UnitFrames:EnsureStyle()
    local oUF = GetOUF()
    if not oUF then
        return false
    end

    if self.styleRegistered then
        return true
    end

    oUF:RegisterStyle(STYLE_NAME, function(frame)
        UnitFrames:StyleFrame(frame)
    end)

    self.styleRegistered = true
    return true
end

function UnitFrames:SpawnFrames()
    local oUF = GetOUF()
    if not oUF then
        return false
    end

    if not self:EnsureStyle() then
        return false
    end

    oUF:SetActiveStyle(STYLE_NAME)

    oUF:Factory(function(factory)
        if UnitFrames.frames.player then
            UnitFrames:RefreshAllFrames()
            return
        end

        UnitFrames:SpawnSingleFrame(factory, "player", "player")
        UnitFrames:SpawnSingleFrame(factory, "target", "target")
        UnitFrames:SpawnSingleFrame(factory, "targettarget", "targettarget")
        UnitFrames:SpawnSingleFrame(factory, "focus", "focus")
        UnitFrames:SpawnSingleFrame(factory, "pet", "pet")

        UnitFrames:SpawnBossFrames(factory)
        UnitFrames:SpawnHeaders(factory)

        UnitFrames:CreateCastbarFrame()
        UnitFrames:RefreshAllFrames()
    end)

    return true
end

function UnitFrames:OnInitialize()
    local db = self:GetDB()
    db.enabled = db.enabled ~= false
end

function UnitFrames:OnEnable()
    if not self:SpawnFrames() then
        T:Print("UnitFrames: oUF is unavailable. Ensure Libraries/oUF/oUF.xml is loaded.")
        return
    end

    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")
    self:RegisterMessage("TWICH_CONFIG_RESTORED", "OnConfigRestored")

    self:RegisterEvent("UNIT_SPELLCAST_START", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_STOP", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_FAILED", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "HandlePlayerCastEvent")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", "HandlePlayerCastEvent")

    self.ticker = C_Timer.NewTicker(0.05, function()
        if UnitFrames._castbarState then
            UnitFrames:UpdateCastbarElapsed()
        end

        if UnitFrames._queuedRefresh and not InCombatLockdown() then
            UnitFrames._queuedRefresh = false
            UnitFrames:RefreshAllFrames()
        end
    end)

    self:RefreshAllFrames()
end

function UnitFrames:OnDisable()
    self:UnregisterMessage("TWICH_THEME_CHANGED")
    self:UnregisterMessage("TWICH_CONFIG_RESTORED")
    self:UnregisterAllEvents()

    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end

    for _, frame in pairs(self.frames) do
        if frame then
            self:StopSmoothBar(frame.Health)
            self:StopSmoothBar(frame.Power)
            frame:Hide()
        end
    end

    for _, header in pairs(self.headers) do
        if header then
            header:Hide()
        end
    end

    for _, preview in pairs(self.previewFrames) do
        if preview then
            preview:Hide()
        end
    end

    for _, mover in pairs(self.movers) do
        if mover then
            mover:Hide()
        end
    end

    self:StopCastbar()
end

function UnitFrames:SetTestMode(enabled)
    local db = self:GetDB()
    db.testMode = enabled == true
    self:RefreshAllFrames()
end

function UnitFrames:SetFrameLock(locked)
    local db = self:GetDB()
    db.lockFrames = locked == true
    self:UpdateMovers()
end

function UnitFrames:RefreshFromOptions()
    if self:IsEnabled() then
        self:RefreshAllFrames()
    end
end
