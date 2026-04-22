--[[
    LootFeed — TwichUI Quality of Life

    Displays a scrolling loot feed: items (quality-colored, icon), money
    (gold/silver/copper), and currencies. Each row slides in and fades out after
    a configurable duration. Duplicate items within the window increment the
    quantity on the existing row instead of spawning a new one.

    Design goals:
    - Pure Lua — zero XML dependencies. One file, fully standalone.
    - Frame pool: up to MAX_POOL rows are created once, wiped, and reused.
    - Shift animation: existing rows slide to make room for new entries.
    - Per-row exit timers, cancelled cleanly on Disable.
    - Fully respects the global TwichUI theme font and accent colours.
    - When disabled everything is torn down; no orphan timers or frames.
]]

local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class LootFeedModule : AceModule, AceEvent-3.0
local LF = QOL:NewModule("LootFeed", "AceEvent-3.0")
LF:SetEnabledState(false)

-- ---------------------------------------------------------------------------
-- Localized globals
-- ---------------------------------------------------------------------------
local LSM                   = (T.Libs and T.Libs.LSM) or (LibStub and LibStub("LibSharedMedia-3.0", true))
local C_Timer               = _G.C_Timer
local C_Item                = _G.C_Item
local CreateFrame           = _G.CreateFrame
local UIParent              = _G.UIParent
local GetItemInfo           = _G.GetItemInfo
local GetItemInfoInstant    = _G.GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
local GetPlayerGuid         = _G.C_PlayerInfo and _G.C_PlayerInfo.GetGUIDForUnit or
    function(u) return _G.UnitGUID(u) end
local issecretvalue         = _G.issecretvalue or function() return false end
local math                  = math
local string                = string
local table                 = table
local ipairs                = ipairs
local pairs                 = pairs
local tonumber              = tonumber
local tostring              = tostring
local unpack                = table.unpack or _G.unpack

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local ADDON_NAME            = "TwichUI_Reformed"
local MAX_POOL              = 20   -- hard cap on live rows
local PADDING               = 3    -- vertical gap between rows (px)
local ENTER_DURATION        = 0.24 -- slide+fade in
local SHIFT_DURATION        = 0.18 -- row shift translate
local EXIT_DURATION         = 0.35 -- fade out
local ENTER_OFFSET_X        = -14  -- softer lateral travel for new rows
local SHIFT_FADE_FROM       = 0.82 -- subtle fade while rows reposition
local ROW_FADE_START        = 0.61 -- keep more solid area than the original fade, but less than the previous pass

-- Item quality names / display ordering (mirrors Enum.ItemQuality)
local QUALITY_NAMES         = {
    [0] = "Poor",
    [1] = "Common",
    [2] = "Uncommon",
    [3] = "Rare",
    [4] = "Epic",
    [5] = "Legendary",
    [6] = "Artifact",
    [7] = "Heirloom",
    [8] = "WoW Token",
}

-- Quality → config key (used for per-quality toggle lookup)
local QUALITY_DB_KEYS       = {
    [0] = "showPoor",
    [1] = "showCommon",
    [2] = "showUncommon",
    [3] = "showRare",
    [4] = "showEpic",
    [5] = "showLegendary",
}

local FALLBACK_ITEM_ICON    = 134400

local SELF_LOOT_GLOBAL_KEYS = {
    "LOOT_ITEM_SELF",
    "LOOT_ITEM_SELF_MULTIPLE",
    "LOOT_ITEM_CREATED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE",
    "YOU_RECEIVED",
    "YOU_RECEIVED_LABEL",
}

local function GetChatMessagePrefix(globalKey)
    local value = _G[globalKey]
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local prefix = string.match(value, "^(.-)%%") or value
    if type(prefix) ~= "string" or prefix == "" then
        return nil
    end

    return prefix
end

local function IsSelfLootMessage(text)
    if type(text) ~= "string" or text == "" then
        return false
    end

    for _, globalKey in ipairs(SELF_LOOT_GLOBAL_KEYS) do
        local prefix = GetChatMessagePrefix(globalKey)
        if prefix then
            local ok, found = pcall(string.find, text, prefix, 1, true)
            if ok and found == 1 then
                return true
            end
        end
    end

    return false
end

local function SafeChatText(value)
    if type(value) ~= "string" then
        return nil
    end

    if issecretvalue and issecretvalue(value) then
        return nil
    end

    local ok, text = pcall(string.format, "%s", value)
    if ok and type(text) == "string" then
        return text
    end

    return nil
end

local function SafeStringFind(text, pattern, init, plain)
    if type(text) ~= "string" or type(pattern) ~= "string" then
        return nil
    end

    local ok, found = pcall(string.find, text, pattern, init, plain)
    if ok then
        return found
    end

    return nil
end

local function SafeStringMatch(text, pattern, init)
    if type(text) ~= "string" or type(pattern) ~= "string" then
        return nil
    end

    local ok, first, second, third, fourth = pcall(string.match, text, pattern, init)
    if ok then
        return first, second, third, fourth
    end

    return nil
end

local function SafeCollectMatches(text, pattern)
    if type(text) ~= "string" or type(pattern) ~= "string" then
        return {}
    end

    local ok, iterator = pcall(string.gmatch, text, pattern)
    if not ok or type(iterator) ~= "function" then
        return {}
    end

    local matches = {}
    while true do
        local nextOk, value = pcall(iterator)
        if not nextOk or value == nil then
            break
        end

        matches[#matches + 1] = value
    end

    return matches
end

-- Coin icon sizes (pixels at font size 12)
local COIN_ATLAS = {
    gold   = "auctionhouse-icon-gold",
    silver = "auctionhouse-icon-silver",
    copper = "auctionhouse-icon-copper",
}

-- ---------------------------------------------------------------------------
-- Settings accessor
-- ---------------------------------------------------------------------------
local function GetSettings()
    local opts = T:GetModule("Configuration") and
        T:GetModule("Configuration").Options.LootFeed
    if opts then
        return opts:GetAll()
    end
    -- Fallback defaults used before configuration is loaded
    return {
        enabled         = true,
        locked          = false,
        chatDockMode    = "right",
        x               = 100,
        y               = 200,
        growUp          = true,
        maxRows         = 8,
        rowHeight       = 26,
        feedWidth       = 270,
        iconSize        = 22,
        displayTime     = 5,
        fontSize        = 12,
        fontOutline     = "OUTLINE",
        font            = "__default",
        bgAlpha         = 0.45,
        bgColorR        = 0,
        bgColorG        = 0,
        bgColorB        = 0,
        scale           = 1.0,
        showItems       = true,
        showGold        = true,
        showCurrency    = true,
        stackDuplicates = true,
        showPoor        = false,
        showCommon      = true,
        showUncommon    = true,
        showRare        = true,
        showEpic        = true,
        showLegendary   = true,
    }
end

local function GetOptions()
    local cfg = T:GetModule("Configuration")
    return cfg and cfg.Options and cfg.Options.LootFeed or nil
end

local function IsChatDocked(settings)
    return settings and settings.chatDockMode ~= nil and settings.chatDockMode ~= "none"
end

local function GetEffectiveGrowUp(settings)
    if IsChatDocked(settings) then
        return true
    end

    return settings.growUp ~= false
end

local function GetTopDockAnchorFrame()
    local chatFrame = _G.ChatFrame1
    local chrome = chatFrame and chatFrame.TwichUIChrome
    return chrome or chatFrame
end

local function GetEffectiveFeedWidth(settings)
    local dockMode = settings and settings.chatDockMode or "none"
    if dockMode == "top" then
        local anchor = GetTopDockAnchorFrame()
        local width = anchor and anchor.GetWidth and anchor:GetWidth() or nil
        if width and width > 0 then
            return width
        end
    end

    return settings.feedWidth or 270
end

local function GetFontValues()
    local values = { __default = "Default" }
    if LSM and type(LSM.HashTable) == "function" then
        local fonts = LSM:HashTable("font") or {}
        for key, value in pairs(fonts) do
            values[key] = value
        end
    end

    return values
end

-- ---------------------------------------------------------------------------
-- Helper: format copper amount as coloured coin string
-- ---------------------------------------------------------------------------
local function FormatMoney(copper)
    if not copper or copper == 0 then return "" end
    local neg    = copper < 0
    copper       = math.abs(copper)
    local gold   = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop    = copper % 100

    -- build coloured segments
    local parts  = {}
    if gold > 0 then
        parts[#parts + 1] = string.format("|cFFFFD700%dg|r", gold)
    end
    if silver > 0 or gold > 0 then
        parts[#parts + 1] = string.format("|cFFC0C0C0%ds|r", silver)
    end
    parts[#parts + 1] = string.format("|cFFB87333%dc|r", cop)

    local str = table.concat(parts, " ")
    return neg and ("(-%s)"):format(str) or str
end

local function NormalizeFontOutlineFlag(value)
    if type(value) ~= "string" then
        return "OUTLINE"
    end

    if value == "" or value == "NONE" then
        return ""
    end

    if value == "OUTLINE" or value == "THICKOUTLINE" or value == "MONOCHROME" then
        return value
    end

    return "OUTLINE"
end

-- ---------------------------------------------------------------------------
-- Row pool
-- ---------------------------------------------------------------------------
local container  = nil

local pool       = {} -- { row, ... } free rows
local activeRows = {} -- { {row, key, exitTimer, quantity, ...}, ... } FIFO newest

local ApplyRowTheme
local ApplyRowFont

-- Used row metatable / helpers --

---Create one reusable row frame parented to `container`.
-- NOTE: `container` must be non-nil before calling this function.
local function CreateRowFrame(settings)
    local rh   = settings.rowHeight or 26
    local fw   = GetEffectiveFeedWidth(settings)
    local isz  = settings.iconSize or 22
    local fs   = settings.fontSize or 12
    local fout = NormalizeFontOutlineFlag(settings.fontOutline)

    local function ShowTooltip(owner)
        if not owner.link then return end
        _G.GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        _G.GameTooltip:SetHyperlink(owner.link)
        _G.GameTooltip:Show()
    end

    local function HideTooltip()
        _G.GameTooltip:Hide()
    end

    local function HandleModifiedClick(owner)
        if owner.link and _G.IsModifiedClick("CHATLINK") then
            _G.ChatEdit_InsertLink(owner.link)
        end
    end

    local function ForwardDragStart()
        local s = GetSettings()
        if not s.locked and container and container:GetScript("OnDragStart") then
            container:GetScript("OnDragStart")(container)
        end
    end

    local function ForwardDragStop()
        if container and container:GetScript("OnDragStop") then
            container:GetScript("OnDragStop")(container)
        end
    end

    -- Parent to the container so SetPoint offsets are always in the same
    -- coordinate space as the container.  This eliminates the cross-parent
    -- anchor ambiguity that caused rows 2+ to snap to UIParent BOTTOM.
    local row = CreateFrame("Frame", nil, container, "BackdropTemplate")
    row:SetSize(fw, rh)
    row:SetFrameStrata("HIGH")
    row:SetAlpha(0)
    row:Hide()
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", HideTooltip)
    row:SetScript("OnMouseUp", function(self)
        HandleModifiedClick(self)
    end)
    row:SetScript("OnDragStart", ForwardDragStart)
    row:SetScript("OnDragStop", ForwardDragStop)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local bgSolid = row:CreateTexture(nil, "BACKGROUND")
    bgSolid:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    bgSolid:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)
    row.bgSolid = bgSolid

    local bgFade = row:CreateTexture(nil, "BACKGROUND")
    bgFade:SetPoint("TOPRIGHT", row, "TOPRIGHT", -1, -1)
    bgFade:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    row.bgFade = bgFade

    local borderLeft = row:CreateTexture(nil, "BORDER")
    borderLeft:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    borderLeft:SetWidth(1)
    row.borderLeft = borderLeft

    local borderTopSolid = row:CreateTexture(nil, "BORDER")
    borderTopSolid:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    borderTopSolid:SetHeight(1)
    row.borderTopSolid = borderTopSolid

    local borderTopFade = row:CreateTexture(nil, "BORDER")
    borderTopFade:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    borderTopFade:SetHeight(1)
    row.borderTopFade = borderTopFade

    local borderBottomSolid = row:CreateTexture(nil, "BORDER")
    borderBottomSolid:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    borderBottomSolid:SetHeight(1)
    row.borderBottomSolid = borderBottomSolid

    local borderBottomFade = row:CreateTexture(nil, "BORDER")
    borderBottomFade:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    borderBottomFade:SetHeight(1)
    row.borderBottomFade = borderBottomFade

    -- Left accent stripe follows the global primary theme color.
    local stripe = row:CreateTexture(nil, "BORDER")
    stripe:SetSize(2, rh)
    stripe:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.stripe = stripe

    -- Icon button (supports hyperlink clicks)
    local icon = CreateFrame("Button", nil, row)
    icon:SetSize(isz, isz)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:EnableMouse(true)
    icon:RegisterForDrag("LeftButton")
    icon:SetScript("OnEnter", ShowTooltip)
    icon:SetScript("OnLeave", HideTooltip)
    icon:SetScript("OnMouseUp", function(self)
        HandleModifiedClick(self)
    end)
    icon:SetScript("OnDragStart", ForwardDragStart)
    icon:SetScript("OnDragStop", ForwardDragStop)

    local iconTex = icon:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- slight inset crop
    icon.tex = iconTex

    -- Quality-coloured inner border
    local border = icon:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetAlpha(0)
    icon.border = border

    row.icon    = icon

    -- Primary text (item name / money / currency)
    local txt   = row:CreateFontString(nil, "OVERLAY")
    txt:SetPoint("LEFT", icon, "RIGHT", 5, 0)
    txt:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    txt:SetJustifyH("LEFT")
    local fontPath = nil
    if LSM and settings.font and settings.font ~= "__default" then
        fontPath = LSM:Fetch("font", settings.font, true)
    end
    if not fontPath then
        fontPath = (T.Tools and T.Tools.Media and T.Tools.Media:GetFont()) or nil
    end
    if fontPath then
        txt:SetFont(fontPath, fs, fout)
    else
        txt:SetFontObject("GameFontNormal")
    end
    txt:SetWordWrap(false)
    row.txt = txt

    ApplyRowTheme(row, settings)
    ApplyRowFont(row, settings)
    if LF and type(LF.RegisterRowWithMasque) == "function" then
        LF:RegisterRowWithMasque(row)
    end

    -- Slide-in enter animation
    local enterAG = row:CreateAnimationGroup()
    enterAG:SetToFinalAlpha(true)

    local enterFade = enterAG:CreateAnimation("Alpha")
    enterFade:SetFromAlpha(0)
    enterFade:SetToAlpha(1)
    enterFade:SetDuration(ENTER_DURATION)
    enterFade:SetSmoothing("OUT")

    local enterSlide = enterAG:CreateAnimation("Translation")
    enterSlide:SetOffset(ENTER_OFFSET_X, 0)
    enterSlide:SetDuration(ENTER_DURATION)
    enterSlide:SetSmoothing("OUT")
    row.enterAG = enterAG

    -- Fade-out exit animation
    local exitAG = row:CreateAnimationGroup()
    exitAG:SetToFinalAlpha(true)

    local exitFade = exitAG:CreateAnimation("Alpha")
    exitFade:SetFromAlpha(1)
    exitFade:SetToAlpha(0)
    exitFade:SetDuration(EXIT_DURATION)
    exitFade:SetSmoothing("IN")
    exitAG:SetScript("OnFinished", function()
        row:Hide()
    end)
    row.exitAG       = exitAG

    -- Shift animation
    local shiftAG    = row:CreateAnimationGroup()
    local shiftTrans = shiftAG:CreateAnimation("Translation")
    local shiftFade  = shiftAG:CreateAnimation("Alpha")
    shiftFade:SetFromAlpha(SHIFT_FADE_FROM)
    shiftFade:SetToAlpha(1)
    shiftFade:SetDuration(SHIFT_DURATION)
    shiftFade:SetSmoothing("IN_OUT")
    row.shiftAG    = shiftAG
    row.shiftTrans = shiftTrans
    row.shiftFade  = shiftFade

    return row
end

---Grab a row from the free pool, or return nil if maxRows is reached.
local function AcquireRow()
    if #pool > 0 then
        return table.remove(pool)
    end
    return nil
end

---Return a row to the free pool and reset its visual state.
local function ReleaseRow(row)
    row.enterAG:Stop()
    row.exitAG:Stop()
    row.shiftAG:Stop()
    row:SetAlpha(0)
    row:Hide()
    row:ClearAllPoints()
    row.link = nil
    row.icon.tex:SetTexture(nil)
    row.icon.border:SetAlpha(0)
    row.icon.link = nil
    row.txt:SetText("")
    pool[#pool + 1] = row
end

local function IterateAllRows(callback)
    for _, row in ipairs(pool) do
        callback(row)
    end

    for _, entry in ipairs(activeRows) do
        if entry and entry.row then
            callback(entry.row)
        end
    end
end

ApplyRowTheme = function(row, settings)
    if not row then
        return
    end

    local width = row.GetWidth and row:GetWidth() or 0
    local fadeStart = math.max(0, math.floor((width * ROW_FADE_START) + 0.5))
    local fadeWidth = math.max(1, width - fadeStart - 1)

    if row.bgSolid then
        row.bgSolid:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.bgSolid:SetPoint("RIGHT", row, "LEFT", fadeStart, 0)
        row.bgSolid:SetColorTexture(
            settings.bgColorR or 0.05,
            settings.bgColorG or 0.06,
            settings.bgColorB or 0.08,
            settings.bgAlpha or 0.94
        )
    end

    if row.bgFade then
        row.bgFade:SetWidth(fadeWidth)
        row.bgFade:SetTexture("Interface\\Buttons\\WHITE8X8")
        if row.bgFade.SetGradient and _G.CreateColor then
            row.bgFade:SetGradient("HORIZONTAL",
                _G.CreateColor(
                    settings.bgColorR or 0.05,
                    settings.bgColorG or 0.06,
                    settings.bgColorB or 0.08,
                    settings.bgAlpha or 0.94),
                _G.CreateColor(
                    settings.bgColorR or 0.05,
                    settings.bgColorG or 0.06,
                    settings.bgColorB or 0.08,
                    0))
        elseif row.bgFade.SetGradientAlpha then
            row.bgFade:SetGradientAlpha("HORIZONTAL",
                settings.bgColorR or 0.05,
                settings.bgColorG or 0.06,
                settings.bgColorB or 0.08,
                settings.bgAlpha or 0.94,
                settings.bgColorR or 0.05,
                settings.bgColorG or 0.06,
                settings.bgColorB or 0.08,
                0)
        else
            row.bgFade:SetColorTexture(
                settings.bgColorR or 0.05,
                settings.bgColorG or 0.06,
                settings.bgColorB or 0.08,
                settings.bgAlpha or 0.94
            )
        end
    end

    if row.SetBackdropBorderColor then
        row:SetBackdropColor(0, 0, 0, 0)
        row:SetBackdropBorderColor(0, 0, 0, 0)
    end

    local borderR = settings.borderColorR or 0.24
    local borderG = settings.borderColorG or 0.26
    local borderB = settings.borderColorB or 0.32
    local borderA = settings.borderAlpha or 0.85

    if row.borderLeft then
        row.borderLeft:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.borderLeft:SetColorTexture(borderR, borderG, borderB, borderA)
    end

    if row.borderTopSolid then
        row.borderTopSolid:SetPoint("RIGHT", row, "LEFT", fadeStart, 0)
        row.borderTopSolid:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.borderTopSolid:SetColorTexture(borderR, borderG, borderB, borderA)
    end

    if row.borderBottomSolid then
        row.borderBottomSolid:SetPoint("RIGHT", row, "LEFT", fadeStart, 0)
        row.borderBottomSolid:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.borderBottomSolid:SetColorTexture(borderR, borderG, borderB, borderA)
    end

    if row.borderTopFade then
        row.borderTopFade:SetWidth(fadeWidth)
        row.borderTopFade:SetTexture("Interface\\Buttons\\WHITE8X8")
        if row.borderTopFade.SetGradient and _G.CreateColor then
            row.borderTopFade:SetGradient("HORIZONTAL",
                _G.CreateColor(borderR, borderG, borderB, borderA),
                _G.CreateColor(borderR, borderG, borderB, 0))
        elseif row.borderTopFade.SetGradientAlpha then
            row.borderTopFade:SetGradientAlpha("HORIZONTAL", borderR, borderG, borderB, borderA, borderR, borderG,
                borderB, 0)
        else
            row.borderTopFade:SetColorTexture(borderR, borderG, borderB, borderA)
        end
    end

    if row.borderBottomFade then
        row.borderBottomFade:SetWidth(fadeWidth)
        row.borderBottomFade:SetTexture("Interface\\Buttons\\WHITE8X8")
        if row.borderBottomFade.SetGradient and _G.CreateColor then
            row.borderBottomFade:SetGradient("HORIZONTAL",
                _G.CreateColor(borderR, borderG, borderB, borderA),
                _G.CreateColor(borderR, borderG, borderB, 0))
        elseif row.borderBottomFade.SetGradientAlpha then
            row.borderBottomFade:SetGradientAlpha("HORIZONTAL", borderR, borderG, borderB, borderA, borderR,
                borderG, borderB, 0)
        else
            row.borderBottomFade:SetColorTexture(borderR, borderG, borderB, borderA)
        end
    end

    if row.stripe then
        row.stripe:SetColorTexture(
            settings.stripeColorR or 0.10,
            settings.stripeColorG or 0.72,
            settings.stripeColorB or 0.74,
            0.95)
    end
end

ApplyRowFont = function(row, settings)
    if not row or not row.txt then
        return
    end

    local fontPath = nil
    if LSM and settings.font and settings.font ~= "__default" then
        fontPath = LSM:Fetch("font", settings.font, true)
    end
    if not fontPath then
        fontPath = (T.Tools and T.Tools.Media and T.Tools.Media:GetFont()) or nil
    end
    if fontPath then
        row.txt:SetFont(fontPath, settings.fontSize or 12, NormalizeFontOutlineFlag(settings.fontOutline))
    else
        row.txt:SetFontObject("GameFontNormal")
    end
end

local function ApplyContainerPosition(settings)
    if not container then
        return
    end

    local dockMode = settings.chatDockMode or "none"
    container:ClearAllPoints()

    if dockMode == "top" then
        local chatFrame = _G.ChatFrame1
        local chrome = chatFrame and chatFrame.TwichUIChrome
        if chrome then
            container:SetPoint("BOTTOMLEFT", chrome, "TOPLEFT", 0, 0)
            container:SetPoint("BOTTOMRIGHT", chrome, "TOPRIGHT", 0, 0)
        elseif chatFrame then
            container:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -8, 8)
            container:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 8, 8)
        else
            container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.x or 100, settings.y or 200)
        end
    elseif dockMode == "right" then
        local chatFrame = _G.ChatFrame1
        if chatFrame then
            container:SetPoint("BOTTOMLEFT", chatFrame, "BOTTOMRIGHT", 8, -8)
        else
            container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.x or 100, settings.y or 200)
        end
    else
        container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", settings.x or 100, settings.y or 200)
    end
end

local function ApplyContainerInteractivity(settings)
    if not container then
        return
    end

    local locked = settings.locked == true or IsChatDocked(settings)
    container:EnableMouse(not locked)
end

local function BuildDesignerExtras()
    return {
        {
            label = "Theme Surface",
            type = "label",
            tab = "appearance",
            tabLabel = "Appearance",
            text = "Background and border styling follow the global Appearance settings.",
        },
        {
            label = "Position Mode",
            type = "select",
            tab = "layout",
            tabLabel = "Layout",
            values = {
                none = "Custom mover",
                top = "Top of chat frame",
                right = "Right of chat frame",
            },
            get = function()
                local opts = GetOptions()
                return opts and opts:GetChatDockMode() or "none"
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetChatDockMode(nil, value)
                end
            end,
        },
        {
            label = "Lock Custom Position",
            type = "toggle",
            tab = "layout",
            tabLabel = "Layout",
            desc = "Only applies while using the custom mover position.",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetLocked() or false
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetLocked(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or opts:GetChatDockMode() ~= "none"
            end,
        },
        {
            label = "Grow Upward",
            type = "toggle",
            tab = "layout",
            tabLabel = "Layout",
            desc = "Docked modes always grow upward.",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetGrowUp() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetGrowUp(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or opts:GetChatDockMode() ~= "none"
            end,
        },
        {
            label = "Feed Width",
            type = "range",
            tab = "layout",
            tabLabel = "Layout",
            min = 150,
            max = 500,
            step = 5,
            desc = "Ignored when docked above the chat frame.",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetFeedWidth() or 270
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetFeedWidth(nil, value)
                end
            end,
        },
        {
            label = "Row Height",
            type = "range",
            tab = "layout",
            tabLabel = "Layout",
            min = 18,
            max = 48,
            step = 1,
            get = function()
                local opts = GetOptions()
                return opts and opts:GetRowHeight() or 26
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetRowHeight(nil, value)
                end
            end,
        },
        {
            label = "Icon Size",
            type = "range",
            tab = "layout",
            tabLabel = "Layout",
            min = 14,
            max = 40,
            step = 1,
            get = function()
                local opts = GetOptions()
                return opts and opts:GetIconSize() or 22
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetIconSize(nil, value)
                end
            end,
        },
        {
            label = "Max Rows",
            type = "range",
            tab = "layout",
            tabLabel = "Layout",
            min = 1,
            max = 15,
            step = 1,
            get = function()
                local opts = GetOptions()
                return opts and opts:GetMaxRows() or 8
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetMaxRows(nil, value)
                end
            end,
        },
        {
            label = "Display Time",
            type = "range",
            tab = "layout",
            tabLabel = "Layout",
            min = 1,
            max = 30,
            step = 0.5,
            get = function()
                local opts = GetOptions()
                return opts and opts:GetDisplayTime() or 5
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetDisplayTime(nil, value)
                end
            end,
        },
        {
            label = "Scale",
            type = "range",
            tab = "appearance",
            tabLabel = "Appearance",
            min = 0.5,
            max = 2.0,
            step = 0.05,
            get = function()
                local opts = GetOptions()
                return opts and opts:GetScale() or 1
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetScale(nil, value)
                end
            end,
        },
        {
            label = "Font",
            type = "select",
            tab = "appearance",
            tabLabel = "Appearance",
            values = function()
                local list = { ["__default"] = "Default" }
                if LSM and type(LSM.HashTable) == "function" then
                    for name in pairs(LSM:HashTable("font") or {}) do
                        list[name] = name
                    end
                end
                return list
            end,
            get = function()
                local opts = GetOptions()
                return opts and opts:GetFont() or "__default"
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetFont(nil, value)
                end
            end,
        },
        {
            label = "Font Size",
            type = "range",
            tab = "appearance",
            tabLabel = "Appearance",
            min = 8,
            max = 20,
            step = 1,
            get = function()
                local opts = GetOptions()
                return opts and opts:GetFontSize() or 12
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetFontSize(nil, value)
                end
            end,
        },
        {
            label = "Font Outline",
            type = "select",
            tab = "appearance",
            tabLabel = "Appearance",
            values = {
                NONE = "None",
                OUTLINE = "Outline",
                THICKOUTLINE = "Thick Outline",
            },
            get = function()
                local opts = GetOptions()
                return opts and opts:GetFontOutline() or "OUTLINE"
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetFontOutline(nil, value)
                end
            end,
        },
        {
            label = "Masque Skinning",
            type = "toggle",
            tab = "appearance",
            tabLabel = "Appearance",
            desc = "Requires the Masque addon to be installed.",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetMasqueEnabled() or false
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetMasqueEnabled(nil, value)
                end
            end,
        },
        {
            label = "Show Items",
            type = "toggle",
            tab = "content",
            tabLabel = "Content",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowItems() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowItems(nil, value)
                end
            end,
        },
        {
            label = "Show Gold",
            type = "toggle",
            tab = "content",
            tabLabel = "Content",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowGold() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowGold(nil, value)
                end
            end,
        },
        {
            label = "Show Currency",
            type = "toggle",
            tab = "content",
            tabLabel = "Content",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowCurrency() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowCurrency(nil, value)
                end
            end,
        },
        {
            label = "Stack Duplicates",
            type = "toggle",
            tab = "content",
            tabLabel = "Content",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetStackDuplicates() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetStackDuplicates(nil, value)
                end
            end,
        },
        {
            label = "Show Poor",
            type = "toggle",
            tab = "filters",
            tabLabel = "Filters",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowPoor() or false
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowPoor(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or not opts:GetShowItems()
            end,
        },
        {
            label = "Show Common",
            type = "toggle",
            tab = "filters",
            tabLabel = "Filters",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowCommon() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowCommon(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or not opts:GetShowItems()
            end,
        },
        {
            label = "Show Uncommon",
            type = "toggle",
            tab = "filters",
            tabLabel = "Filters",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowUncommon() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowUncommon(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or not opts:GetShowItems()
            end,
        },
        {
            label = "Show Rare",
            type = "toggle",
            tab = "filters",
            tabLabel = "Filters",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowRare() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowRare(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or not opts:GetShowItems()
            end,
        },
        {
            label = "Show Epic",
            type = "toggle",
            tab = "filters",
            tabLabel = "Filters",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowEpic() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowEpic(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or not opts:GetShowItems()
            end,
        },
        {
            label = "Show Legendary",
            type = "toggle",
            tab = "filters",
            tabLabel = "Filters",
            get = function()
                local opts = GetOptions()
                return opts and opts:GetShowLegendary() or true
            end,
            set = function(value)
                local opts = GetOptions()
                if opts then
                    opts:SetShowLegendary(nil, value)
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or not opts:GetShowItems()
            end,
        },
        {
            label = "Reset Custom Position",
            type = "execute",
            tab = "layout",
            tabLabel = "Layout",
            desc = "Return the loot feed to its default custom mover location.",
            func = function()
                local opts = GetOptions()
                if opts then
                    opts:ResetPosition()
                end
            end,
            disabled = function()
                local opts = GetOptions()
                return not opts or opts:GetChatDockMode() ~= "none"
            end,
        },
        {
            label = "Show Preview",
            type = "execute",
            tab = "preview",
            tabLabel = "Preview",
            func = function()
                LF:ShowPreview()
            end,
        },
        {
            label = "Hide Preview",
            type = "execute",
            tab = "preview",
            tabLabel = "Preview",
            func = function()
                LF:HidePreview()
            end,
        },
    }
end

-- ---------------------------------------------------------------------------
-- Active row registry
-- ---------------------------------------------------------------------------

-- Evict (release) the oldest active row to make space.
local function EvictOldestRow()
    if #activeRows == 0 then return end
    local oldest = table.remove(activeRows, 1)
    if oldest.exitTimer then
        oldest.exitTimer:Cancel()
        oldest.exitTimer = nil
    end
    oldest.row.exitAG:Stop()
    ReleaseRow(oldest.row)
end

-- Shift all visible rows in the grow direction to make room for a new entry.
-- Strategy: commit the TRUE FINAL SetPoint immediately (before playing the
-- animation). The Translation animation is then used to offset the frame's
-- visual starting position back to where it was, so it appears to slide from
-- the old position to the new one.  Because SetPoint is already correct when
-- Stop() fires (or animation finishes), there is no race condition.
local function ShiftRows(settings)
    local dir      = GetEffectiveGrowUp(settings) and 1 or -1
    local amount   = (settings.rowHeight or 26) + PADDING
    local dockMode = settings.chatDockMode or "none"

    for _, entry in ipairs(activeRows) do
        local row       = entry.row
        local newOffset = (entry.yOffset or 0) + amount
        entry.yOffset   = newOffset

        row.shiftAG:Stop()

        -- 1. Apply the final target position NOW. The frame is correct even if
        --    the animation is interrupted mid-play.
        row:ClearAllPoints()
        if GetEffectiveGrowUp(settings) then
            if dockMode == "top" then
                row:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, newOffset)
            else
                row:SetPoint("BOTTOM", container, "BOTTOM", 0, newOffset)
            end
        else
            if dockMode == "top" then
                row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -newOffset)
            else
                row:SetPoint("TOP", container, "TOP", 0, -newOffset)
            end
        end

        -- 2. Animate from WHERE the frame visually was (old position) toward the
        --    new SetPoint.  Translation goes from (offsetX, offsetY) → (0, 0).
        --    We want to start at old_visual = new_setpoint − dir*amount, so the
        --    offset that puts us at the old position is: -dir * amount.
        row:SetAlpha(1)
        row.shiftTrans:SetOffset(0, -dir * amount)
        row.shiftTrans:SetDuration(SHIFT_DURATION)
        row.shiftTrans:SetSmoothing("IN_OUT")
        row.shiftFade:SetFromAlpha(SHIFT_FADE_FROM)
        row.shiftFade:SetToAlpha(1)
        row.shiftFade:SetDuration(SHIFT_DURATION)
        row.shiftAG:Play()
    end
end

-- Anchor a fresh row to the feed container base point (yOffset 0).
local function AnchorRow(row, container, settings)
    local dockMode = settings.chatDockMode or "none"
    row:ClearAllPoints()
    if GetEffectiveGrowUp(settings) then
        if dockMode == "top" then
            row:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", 0, 0)
        else
            row:SetPoint("BOTTOM", container, "BOTTOM", 0, 0)
        end
    else
        if dockMode == "top" then
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOP", container, "TOP", 0, 0)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Feed container frame
-- ---------------------------------------------------------------------------
local function EnsureContainer(settings)
    if container then return end

    container = CreateFrame("Frame", "TwichUI_LootFeedContainer", UIParent)
    container:SetSize(GetEffectiveFeedWidth(settings), settings.rowHeight or 26)
    container:SetFrameStrata("HIGH")
    container:SetClampedToScreen(true)
    container:SetScale(settings.scale or 1.0)

    ApplyContainerPosition(settings)

    -- Drag support
    ApplyContainerInteractivity(settings)
    container:SetMovable(true)
    container:RegisterForDrag("LeftButton")
    container:SetScript("OnDragStart", function(self)
        local s = GetSettings()
        if not s.locked and not IsChatDocked(s) then
            self:StartMoving()
        end
    end)
    container:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save absolute BOTTOMLEFT screen coordinates (independent of scale /
        -- anchor used by the drag system).
        local opts = T:GetModule("Configuration") and
            T:GetModule("Configuration").Options.LootFeed
        if opts and opts:GetChatDockMode() == "none" then
            local left   = math.floor((self:GetLeft() or 0) + 0.5)
            local bottom = math.floor((self:GetBottom() or 0) + 0.5)
            opts:SetPosition(left, bottom)
        end
    end)
end

local function DestroyContainer()
    if container then
        container:Hide()
        container = nil
    end
end

-- ---------------------------------------------------------------------------
-- Row population
-- ---------------------------------------------------------------------------

local function PopulateRow(entry, icon, text, link, quality, settings)
    local row  = entry.row
    local rh   = settings.rowHeight or 26
    local fw   = GetEffectiveFeedWidth(settings)
    local isz  = settings.iconSize or 22
    local fs   = settings.fontSize or 12
    local fout = settings.fontOutline or "OUTLINE"

    row:SetSize(fw, rh)
    row.icon:SetSize(isz, isz)
    ApplyRowTheme(row, settings)
    ApplyRowFont(row, settings)

    -- Icon texture
    if icon then
        row.icon.tex:SetTexture(icon)
        row.icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.icon:Show()
    else
        row.icon:Hide()
    end

    -- Quality border
    if quality and quality >= 0 then
        local r, g, b = 1, 1, 1
        if C_Item and C_Item.GetItemQualityColor then
            r, g, b = C_Item.GetItemQualityColor(quality)
        end
        if quality >= 2 then -- Uncommon and above get a coloured border
            row.icon.border:SetVertexColor(r, g, b, 1)
            row.icon.border:SetAlpha(0.85)
        else
            row.icon.border:SetAlpha(0)
        end
        row.txt:SetTextColor(r, g, b, 1)
    else
        row.icon.border:SetAlpha(0)
        row.txt:SetTextColor(1, 1, 1, 1)
    end

    row.txt:SetText(text)
    row.link = link
    row.icon.link = link
end

-- ---------------------------------------------------------------------------
-- Entry submission
-- ---------------------------------------------------------------------------
local function ScheduleExit(entry, displayTime)
    if entry.exitTimer then
        entry.exitTimer:Cancel()
    end
    entry.exitTimer = C_Timer.NewTimer(displayTime, function()
        entry.row.exitAG:Play()
        -- Remove from activeRows
        for i = #activeRows, 1, -1 do
            if activeRows[i] == entry then
                table.remove(activeRows, i)
                break
            end
        end
        -- Return to pool after fade finishes
        C_Timer.After(EXIT_DURATION + 0.05, function()
            if entry.row then
                ReleaseRow(entry.row)
                entry.row = nil
            end
        end)
    end)
end

---Push a new entry into the feed.
---@param icon      string|number|nil   Texture path or fileID
---@param text      string       Display text (may contain colour codes or links)
---@param link      string|nil   Item hyperlink for tooltip on hover
---@param quality   number|nil   Enum.ItemQuality value
---@param key       string       Dedup key (e.g. the item link, or "MONEY")
local function PushEntry(icon, text, link, quality, key)
    local settings = GetSettings()
    if not settings.enabled then return end
    if not container then EnsureContainer(settings) end

    local maxRows     = settings.maxRows or 8
    local displayTime = settings.displayTime or 5

    -- --- Stack duplicates ---
    if settings.stackDuplicates and key then
        for _, entry in ipairs(activeRows) do
            if entry.key == key then
                -- Refresh the display text (quantity already updated by caller)
                entry.row.txt:SetText(text)
                -- Reset fade timer
                ScheduleExit(entry, displayTime)
                return
            end
        end
    end

    -- --- Evict oldest if at capacity ---
    while #activeRows >= maxRows do
        EvictOldestRow()
    end
    while #pool == 0 and #activeRows < MAX_POOL do
        -- Lazily grow pool
        pool[#pool + 1] = CreateRowFrame(settings)
    end

    local row = AcquireRow()
    if not row then return end -- shouldn't happen but guard

    local entry = {
        row       = row,
        key       = key,
        quantity  = 1,
        yOffset   = 0, -- logical y offset from container base (px); updated on each shift
        exitTimer = nil,
    }

    -- Shift existing rows first
    ShiftRows(settings)

    -- Anchor this row at feed base
    AnchorRow(row, container, settings)
    row:Show()
    PopulateRow(entry, icon, text, link, quality, settings)

    row.exitAG:Stop()
    row:SetAlpha(0)
    row.enterAG:Play()

    activeRows[#activeRows + 1] = entry
    ScheduleExit(entry, displayTime)
end

-- ---------------------------------------------------------------------------
-- Money batching
-- ---------------------------------------------------------------------------
local pendingMoney      = 0
local moneyBatchTimer   = nil
local MONEY_BATCH_DELAY = 0.5

local function FlushMoney()
    moneyBatchTimer = nil
    if pendingMoney == 0 then return end
    local copper   = pendingMoney
    pendingMoney   = 0

    local text     = FormatMoney(copper)
    local key      = "MONEY"
    -- Update existing row if visible
    local settings = GetSettings()
    if settings.stackDuplicates then
        for _, entry in ipairs(activeRows) do
            if entry.key == key then
                entry.accCopper = (entry.accCopper or 0) + copper
                entry.row.txt:SetText(FormatMoney(entry.accCopper))
                ScheduleExit(entry, settings.displayTime or 5)
                return
            end
        end
    end

    -- Icon: use a coin bag atlas
    local icon = "Interface\\MoneyFrame\\UI-GoldIcon"

    -- Build new entry
    PushEntry(icon, text, nil, nil, key)
    -- Store accumulated copper on the new entry
    for _, entry in ipairs(activeRows) do
        if entry.key == key then
            entry.accCopper = copper
            break
        end
    end
end

-- ---------------------------------------------------------------------------
-- Pending item requests (GET_ITEM_INFO_RECEIVED retry)
-- ---------------------------------------------------------------------------
local pendingItems = {} -- [itemID] = { link, qty }

-- ---------------------------------------------------------------------------
-- Item quality filter helper
-- ---------------------------------------------------------------------------
local function IsQualityShown(quality, settings)
    if quality == nil then return true end
    local key = QUALITY_DB_KEYS[quality]
    if not key then return true end
    return settings[key] ~= false
end

local function ResolveItemIcon(itemLink, itemID, texture)
    if texture then
        return texture
    end

    if itemLink and GetItemInfoInstant then
        local _, _, _, _, instantTexture = GetItemInfoInstant(itemLink)
        if instantTexture then
            return instantTexture
        end
    end

    if itemID and GetItemInfoInstant then
        local _, _, _, _, instantTexture = GetItemInfoInstant(itemID)
        if instantTexture then
            return instantTexture
        end
    end

    if itemID and C_Item and type(C_Item.GetItemIconByID) == "function" then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then
            return icon
        end
    end

    return FALLBACK_ITEM_ICON
end

local function GetResolvedItemInfo(itemLink)
    if _G.C_Item and _G.C_Item.GetItemInfo then
        local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = _G.C_Item.GetItemInfo(itemLink)
        return itemName, itemQuality, itemTexture
    end

    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = GetItemInfo(itemLink)
    return itemName, itemQuality, itemTexture
end

-- ---------------------------------------------------------------------------
-- Event handlers
-- ---------------------------------------------------------------------------

function LF:CHAT_MSG_LOOT(_, msg, _, _, _, senderName2, _, _, _, _, _, _, guid)
    local settings = GetSettings()
    if not settings.showItems then return end

    local parsedMsg = SafeChatText(msg)
    if not parsedMsg then return end

    -- Only our own loot
    local myGuid = GetPlayerGuid and GetPlayerGuid("player") or _G.UnitGUID("player")
    if not myGuid then return end

    -- Raid loot history messages contain HlootHistory: — ignore them
    if SafeStringFind(parsedMsg, "HlootHistory:", 1, true) then return end

    -- Midnight can mark chat GUIDs as secret strings; never compare those directly.
    -- Use the GUID only when both sides are safe, otherwise fall back to sender/self-text.
    local guidIsSecret = issecretvalue and issecretvalue(guid)
    local myGuidIsSecret = issecretvalue and issecretvalue(myGuid)
    local parsedGuid = (not guidIsSecret) and SafeChatText(guid) or nil
    if parsedGuid and parsedGuid ~= "" and not myGuidIsSecret then
        if parsedGuid ~= myGuid then return end
    else
        local playerName = SafeChatText(_G.UnitName("player"))
        local parsedSenderName = SafeChatText(senderName2)
        local playerShortName = playerName and SafeStringMatch(playerName, "^[^-]+") or playerName
        local senderShortName = parsedSenderName and SafeStringMatch(parsedSenderName, "^[^-]+") or parsedSenderName
        if senderShortName and senderShortName ~= "" then
            if senderShortName ~= playerShortName then
                return
            end
        elseif not IsSelfLootMessage(parsedMsg) then
            return
        end
    end

    -- Extract item link(s) — upgrades produce two links
    local links = {}
    for _, link in ipairs(SafeCollectMatches(parsedMsg, "|c.-|Hitem:.-|h%[.-%]|h|r")) do
        links[#links + 1] = link
    end
    local itemLink = links[#links]
    if not itemLink then return end

    -- Extract quantity (e.g. "You receive loot: x3")
    local qty = tonumber(SafeStringMatch(parsedMsg, "r ?x(%d+)")) or 1

    -- Resolve item info
    local itemID = C_Item and C_Item.GetItemIDByGUID and C_Item.GetItemIDByGUID(itemLink) or
        tonumber(SafeStringMatch(itemLink, "item:(%d+)"))
    if not itemID then
        -- Fallback: parse id from link content
        itemID = tonumber(SafeStringMatch(itemLink, "|Hitem:(%d+)"))
    end

    if not itemID then return end

    local name, quality, texture = GetResolvedItemInfo(itemLink)

    if not name then
        -- Defer until item data arrives
        pendingItems[itemID] = { link = itemLink, qty = qty }
        return
    end

    if not IsQualityShown(quality, settings) then return end

    texture = ResolveItemIcon(itemLink, itemID, texture)
    local displayText = qty > 1 and ("|cFFFFFFFF" .. name .. "|r x" .. qty) or itemLink

    PushEntry(texture, displayText, itemLink, quality, itemLink)
end

function LF:GET_ITEM_INFO_RECEIVED(_, itemID, success)
    local pending = pendingItems[itemID]
    if not pending then return end
    pendingItems[itemID] = nil

    if not success then return end

    local settings = GetSettings()
    if not settings.showItems then return end

    local itemLink               = pending.link
    local qty                    = pending.qty

    local name, quality, texture = GetResolvedItemInfo(itemLink)

    if not name then return end
    if not IsQualityShown(quality, settings) then return end

    texture = ResolveItemIcon(itemLink, itemID, texture)
    local displayText = qty > 1 and ("|cFFFFFFFF" .. name .. "|r x" .. qty) or itemLink
    PushEntry(texture, displayText, itemLink, quality, itemLink)
end

function LF:CHAT_MSG_MONEY(_, msg)
    local settings = GetSettings()
    if not settings.showGold then return end

    local parsedMsg = SafeChatText(msg)
    if not parsedMsg then return end

    -- Parse copper from the system money message
    -- WoW formats: "You receive: <money>" with various gold/silver/copper sub-parts
    local gold   = tonumber(SafeStringMatch(parsedMsg, "(%d+) Gold")) or 0
    local silver = tonumber(SafeStringMatch(parsedMsg, "(%d+) Silver")) or 0
    local copper = tonumber(SafeStringMatch(parsedMsg, "(%d+) Copper")) or 0
    local total  = gold * 10000 + silver * 100 + copper

    if total == 0 then return end

    pendingMoney = pendingMoney + total

    if moneyBatchTimer then
        moneyBatchTimer:Cancel()
    end
    moneyBatchTimer = C_Timer.NewTimer(MONEY_BATCH_DELAY, FlushMoney)
end

function LF:CHAT_MSG_CURRENCY(_, msg)
    local settings = GetSettings()
    if not settings.showCurrency then return end

    local parsedMsg = SafeChatText(msg)
    if not parsedMsg then return end

    -- Extract currency link and quantity
    local link = SafeStringMatch(parsedMsg, "|c.-|Hcurrency:(%d+)|h%[(.-)%]|h|r")

    -- Try simpler pattern: get the display text
    local currencyLink, currencyName
    for _, cl in ipairs(SafeCollectMatches(parsedMsg, "|c.-|Hcurrency:.-|h%[.-%]|h|r")) do
        currencyLink = cl
        currencyName = SafeStringMatch(cl, "|h%[(.-)%]|h")
        break
    end

    if not currencyName then
        -- Fallback: show the raw message snippet
        currencyName = SafeStringMatch(parsedMsg, "receive (.+)$") or parsedMsg
    end

    local qty = tonumber(SafeStringMatch(parsedMsg, "r ?x(%d+)")) or 1
    local text = qty > 1 and (currencyName .. " x" .. qty) or currencyName

    -- Try to get a currency icon if we have the ID
    local currencyID = tonumber(
        SafeStringMatch(currencyLink or "", "|Hcurrency:(%d+)") or
        SafeStringMatch(parsedMsg, "|Hcurrency:(%d+)")
    )
    local icon = nil
    if currencyID and _G.C_CurrencyInfo and _G.C_CurrencyInfo.GetCurrencyInfo then
        local info = _G.C_CurrencyInfo.GetCurrencyInfo(currencyID)
        icon = info and info.iconFileID
    end

    local key = currencyLink or ("CURRENCY_" .. currencyName)
    PushEntry(icon, "|cFFFFD700" .. text .. "|r", nil, nil, key)
end

-- ---------------------------------------------------------------------------
-- Preview / test
-- ---------------------------------------------------------------------------
function LF:ShowPreview()
    local settings = GetSettings()
    EnsureContainer(settings)
    PushEntry(
        "Interface\\Icons\\INV_Misc_MarkofHonor_base",
        "|cFFA335EECrimson Relic of Midnight|r",
        nil, 4, "PREVIEW_EPIC"
    )
    C_Timer.After(0.15, function()
        PushEntry(
            "Interface\\Icons\\INV_Misc_Coin_01",
            FormatMoney(154823),
            nil, nil, "PREVIEW_GOLD"
        )
    end)
    C_Timer.After(0.30, function()
        PushEntry(
            "Interface\\Icons\\Achievement_guildperk_mobilebanking",
            "|cFF1EFF00Arcane Crystal|r",
            nil, 2, "PREVIEW_GREEN"
        )
    end)
end

function LF:HidePreview()
    for _, entry in ipairs(activeRows) do
        if entry.key and entry.key:find("PREVIEW_") then
            if entry.exitTimer then
                entry.exitTimer:Cancel()
                entry.exitTimer = nil
            end
            entry.row.exitAG:Play()
        end
    end
end

function LF:RegisterRowWithMasque(row)
    if not row or not row.icon or not self._masqueGroup or row._lootFeedMasqueRegistered then
        return
    end

    self._masqueGroup:AddButton(row.icon, {
        Icon         = row.icon.tex,
        Border       = row.icon.border,
        Highlight    = nil,
        Normal       = false,
        Pushed       = false,
        Disabled     = false,
        Checked      = false,
        Cooldown     = nil,
        AutoCast     = nil,
        AutoCastable = nil,
        HotKey       = nil,
        Count        = false,
        Name         = nil,
        Duration     = false,
        FloatingBG   = nil,
        Flash        = nil,
    })
    row._lootFeedMasqueRegistered = true
end

function LF:ApplyMasqueSettings()
    local settings = GetSettings()
    local wantMasque = settings.masqueEnabled == true

    if wantMasque then
        if not self._masqueGroup then
            local Masque = LibStub and LibStub("Masque", true)
            if Masque then
                self._masqueGroup = Masque:Group("TwichUI Reformed", "Loot Feed Icons")
                IterateAllRows(function(row)
                    row._lootFeedMasqueRegistered = nil
                end)
            end
        end

        if self._masqueGroup then
            IterateAllRows(function(row)
                self:RegisterRowWithMasque(row)
            end)
            if self._masqueGroup.ReSkin then
                self._masqueGroup:ReSkin()
            end
        end
    else
        if self._masqueGroup then
            if type(self._masqueGroup.Delete) == "function" then
                self._masqueGroup:Delete()
            end
            self._masqueGroup = nil
        end

        IterateAllRows(function(row)
            row._lootFeedMasqueRegistered = nil
        end)
    end
end

function LF:OnThemeChanged()
    local settings = GetSettings()
    IterateAllRows(function(row)
        ApplyRowTheme(row, settings)
        ApplyRowFont(row, settings)
    end)
end

-- ---------------------------------------------------------------------------
-- Public: refresh layout (called when settings change live)
-- ---------------------------------------------------------------------------
function LF:RefreshLayout()
    if self._masqueGroup then
        if type(self._masqueGroup.Delete) == "function" then
            self._masqueGroup:Delete()
        end
        self._masqueGroup = nil
    end

    -- Clear all current rows and recreate from nothing
    for _, entry in ipairs(activeRows) do
        if entry.exitTimer then
            entry.exitTimer:Cancel()
            entry.exitTimer = nil
        end
        ReleaseRow(entry.row)
    end
    activeRows = {}

    -- Flush pool — detach and hide each frame before dropping the reference
    -- (rows are now children of container, so a clean detach avoids stale
    -- child frames accumulating on the container across RefreshLayout calls).
    for _, row in ipairs(pool) do
        row:Hide()
        row:SetParent(nil)
    end
    pool = {}

    if container then
        local settings = GetSettings()
        container:SetSize(GetEffectiveFeedWidth(settings), settings.rowHeight or 26)
        container:SetScale(settings.scale or 1.0)
        ApplyContainerPosition(settings)
        ApplyContainerInteractivity(settings)
    end

    self:ApplyMasqueSettings()
end

function LF:OnEnteringWorld()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    C_Timer.After(0.5, function()
        if LF:IsEnabled() then
            LF:RefreshLayout()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- AceModule lifecycle
-- ---------------------------------------------------------------------------

function LF:OnEnable()
    local settings = GetSettings()
    EnsureContainer(settings)

    -- Pre-warm pool with initial rows
    local warmCount = math.min(settings.maxRows or 8, MAX_POOL)
    for i = 1, warmCount do
        pool[i] = CreateRowFrame(settings)
    end

    self:RegisterEvent("CHAT_MSG_LOOT", "CHAT_MSG_LOOT")
    self:RegisterEvent("GET_ITEM_INFO_RECEIVED", "GET_ITEM_INFO_RECEIVED")
    self:RegisterEvent("CHAT_MSG_MONEY", "CHAT_MSG_MONEY")
    self:RegisterEvent("CHAT_MSG_CURRENCY", "CHAT_MSG_CURRENCY")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnteringWorld")
    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")

    self:ApplyMasqueSettings()
    self:OnThemeChanged()

    -- Register with the Interface Designer (Mover module)
    local moversModule = _G.TwichMoverModule
    if moversModule and type(moversModule.RegisterMover) == "function" then
        moversModule:RegisterMover("LF_feed", {
            label        = "Loot Feed",
            category     = "Quality of Life",
            headerToggle = {
                label = "Enabled",
                get = function()
                    local opts = GetOptions()
                    return opts and opts:GetEnabled() or LF:IsEnabled()
                end,
                set = function(value)
                    local opts = GetOptions()
                    if opts then
                        opts:SetEnabled(nil, value)
                    end
                end,
            },
            headerAction = {
                label = "Show Preview",
                func = function()
                    LF:ShowPreview()
                end,
            },
            getFrame     = function()
                return GetSettings().chatDockMode == "none" and container or nil
            end,
            getX         = function()
                if container then
                    return math.floor((container:GetLeft() or 0) + 0.5)
                end
                return GetSettings().x or 100
            end,
            getY         = function()
                if container then
                    return math.floor((container:GetBottom() or 0) + 0.5)
                end
                return GetSettings().y or 200
            end,
            getW         = function()
                return GetEffectiveFeedWidth(GetSettings())
            end,
            getH         = function()
                return GetSettings().rowHeight or 26
            end,
            setPos       = function(x, y)
                local opts = T:GetModule("Configuration") and
                    T:GetModule("Configuration").Options.LootFeed
                local rx = math.floor(x + 0.5)
                local ry = math.floor(y + 0.5)
                if opts then opts:SetPosition(rx, ry) end
                if container and GetSettings().chatDockMode == "none" then
                    container:ClearAllPoints()
                    container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rx, ry)
                end
            end,
            setSize      = function(w, _h)
                local opts = T:GetModule("Configuration") and
                    T:GetModule("Configuration").Options.LootFeed
                if opts then
                    opts:SetFeedWidth(nil, math.max(150, math.floor(w + 0.5)))
                end
            end,
            isEnabled    = function()
                return LF:IsEnabled()
            end,
            extras       = BuildDesignerExtras(),
        })
    end
end

function LF:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterMessage("TWICH_THEME_CHANGED")
    if self._masqueGroup then
        if type(self._masqueGroup.Delete) == "function" then
            self._masqueGroup:Delete()
        end
        self._masqueGroup = nil
    end
    IterateAllRows(function(row)
        row._lootFeedMasqueRegistered = nil
    end)

    -- Cancel all pending timers
    if moneyBatchTimer then
        moneyBatchTimer:Cancel()
        moneyBatchTimer = nil
    end
    pendingMoney = 0
    pendingItems = {}

    -- Release all active rows
    for _, entry in ipairs(activeRows) do
        if entry.exitTimer then
            entry.exitTimer:Cancel()
            entry.exitTimer = nil
        end
        if entry.row then
            ReleaseRow(entry.row)
        end
    end
    activeRows = {}

    -- Clear pool
    for _, row in ipairs(pool) do
        row:SetParent(nil)
        row:Hide()
    end
    pool = {}

    DestroyContainer()

    -- Unregister from the Interface Designer
    local moversModule = _G.TwichMoverModule
    if moversModule and type(moversModule.UnregisterMover) == "function" then
        moversModule:UnregisterMover("LF_feed")
    end
end
