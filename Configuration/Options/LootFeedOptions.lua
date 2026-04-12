--[[
    Configuration options for the LootFeed module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class LootFeedConfigurationOptions
local Options = ConfigurationModule.Options.LootFeed or {}
ConfigurationModule.Options.LootFeed = Options

-- ---------------------------------------------------------------------------
-- DB helpers
-- ---------------------------------------------------------------------------
local function GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if not profile.lootFeed then
        profile.lootFeed = {
            enabled = true,
            chatDockMode = "right",
        }
    end
    return profile.lootFeed
end

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("LootFeed")
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

local function RefreshLayout()
    local m = GetModule()
    local refresh = m and m["RefreshLayout"] or nil
    if m and type(refresh) == "function" and m:IsEnabled() then
        refresh(m)
    end
end

-- ---------------------------------------------------------------------------
-- GetAll — used by the module for a snapshot of all settings
-- ---------------------------------------------------------------------------
function Options:GetAll()
    local db = GetDB()
    local bgR, bgG, bgB = GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
    local borderR, borderG, borderB = GetThemeColor("borderColor", { 0.24, 0.26, 0.32 })
    local primaryR, primaryG, primaryB = GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    return {
        enabled         = db.enabled ~= false,
        locked          = db.locked == true,
        chatDockMode    = db.chatDockMode or "none",
        x               = db.x or 100,
        y               = db.y or 200,
        growUp          = db.growUp ~= false,
        maxRows         = db.maxRows or 8,
        rowHeight       = db.rowHeight or 26,
        feedWidth       = db.feedWidth or 270,
        iconSize        = db.iconSize or 22,
        displayTime     = db.displayTime or 5,
        fontSize        = db.fontSize or 12,
        fontOutline     = db.fontOutline or "OUTLINE",
        font            = db.font or "__default",
        bgAlpha         = GetThemeValue("backgroundAlpha", 0.94),
        bgColorR        = bgR,
        bgColorG        = bgG,
        bgColorB        = bgB,
        borderAlpha     = GetThemeValue("borderAlpha", 0.85),
        borderColorR    = borderR,
        borderColorG    = borderG,
        borderColorB    = borderB,
        stripeColorR    = primaryR,
        stripeColorG    = primaryG,
        stripeColorB    = primaryB,
        scale           = db.scale or 1.0,
        masqueEnabled   = db.masqueEnabled == true,
        showItems       = db.showItems ~= false,
        showGold        = db.showGold ~= false,
        showCurrency    = db.showCurrency ~= false,
        stackDuplicates = db.stackDuplicates ~= false,
        showPoor        = db.showPoor == true,
        showCommon      = db.showCommon ~= false,
        showUncommon    = db.showUncommon ~= false,
        showRare        = db.showRare ~= false,
        showEpic        = db.showEpic ~= false,
        showLegendary   = db.showLegendary ~= false,
    }
end

-- ---------------------------------------------------------------------------
-- Enabled
-- ---------------------------------------------------------------------------
function Options:GetEnabled()
    return GetDB().enabled ~= false
end

function Options:SetEnabled(_, value)
    GetDB().enabled = value ~= false
    local m = GetModule()
    if value then
        m:Enable()
    else
        m:Disable()
    end
end

-- ---------------------------------------------------------------------------
-- Locked
-- ---------------------------------------------------------------------------
function Options:GetLocked()
    return GetDB().locked == true
end

function Options:SetLocked(_, value)
    GetDB().locked = value == true
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Chat dock mode
-- ---------------------------------------------------------------------------
function Options:GetChatDockMode()
    return GetDB().chatDockMode or "none"
end

function Options:SetChatDockMode(_, value)
    if value ~= "top" and value ~= "right" then
        value = "none"
    end

    GetDB().chatDockMode = value
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Position (set by drag or Interface Designer, exposed for reset)
-- ---------------------------------------------------------------------------
function Options:SetPosition(x, y)
    local db = GetDB()
    db.x = x
    db.y = y
end

function Options:ResetPosition()
    local db = GetDB()
    db.x = 100
    db.y = 200
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Grow direction
-- ---------------------------------------------------------------------------
function Options:GetGrowUp()
    return GetDB().growUp ~= false
end

function Options:SetGrowUp(_, value)
    GetDB().growUp = value ~= false
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Max rows
-- ---------------------------------------------------------------------------
function Options:GetMaxRows()
    return GetDB().maxRows or 8
end

function Options:SetMaxRows(_, value)
    GetDB().maxRows = value
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Row height
-- ---------------------------------------------------------------------------
function Options:GetRowHeight()
    return GetDB().rowHeight or 26
end

function Options:SetRowHeight(_, value)
    GetDB().rowHeight = value
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Feed width
-- ---------------------------------------------------------------------------
function Options:GetFeedWidth()
    return GetDB().feedWidth or 270
end

function Options:SetFeedWidth(_, value)
    GetDB().feedWidth = value
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Icon size
-- ---------------------------------------------------------------------------
function Options:GetIconSize()
    return GetDB().iconSize or 22
end

function Options:SetIconSize(_, value)
    GetDB().iconSize = value
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Masque support
-- ---------------------------------------------------------------------------
function Options:GetMasqueEnabled()
    return GetDB().masqueEnabled == true
end

function Options:SetMasqueEnabled(_, value)
    GetDB().masqueEnabled = value == true
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Display time
-- ---------------------------------------------------------------------------
function Options:GetDisplayTime()
    return GetDB().displayTime or 5
end

function Options:SetDisplayTime(_, value)
    GetDB().displayTime = value
end

-- ---------------------------------------------------------------------------
-- Font size
-- ---------------------------------------------------------------------------
function Options:GetFontSize()
    return GetDB().fontSize or 12
end

function Options:SetFontSize(_, value)
    GetDB().fontSize = value
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Font outline
-- ---------------------------------------------------------------------------
function Options:GetFontOutline()
    return GetDB().fontOutline or "OUTLINE"
end

function Options:SetFontOutline(_, value)
    GetDB().fontOutline = value or "OUTLINE"
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Background alpha
-- ---------------------------------------------------------------------------
function Options:GetBgAlpha()
    return GetThemeValue("backgroundAlpha", 0.94)
end

function Options:SetBgAlpha(_, value)
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Event types
-- ---------------------------------------------------------------------------
function Options:GetShowItems() return GetDB().showItems ~= false end

function Options:SetShowItems(_, v) GetDB().showItems = v ~= false end

function Options:GetShowGold() return GetDB().showGold ~= false end

function Options:SetShowGold(_, v) GetDB().showGold = v ~= false end

function Options:GetShowCurrency() return GetDB().showCurrency ~= false end

function Options:SetShowCurrency(_, v) GetDB().showCurrency = v ~= false end

function Options:GetStackDuplicates() return GetDB().stackDuplicates ~= false end

function Options:SetStackDuplicates(_, v) GetDB().stackDuplicates = v ~= false end

-- ---------------------------------------------------------------------------
-- Item quality filters
-- ---------------------------------------------------------------------------
function Options:GetShowPoor() return GetDB().showPoor == true end

function Options:SetShowPoor(_, v) GetDB().showPoor = v == true end

function Options:GetShowCommon() return GetDB().showCommon ~= false end

function Options:SetShowCommon(_, v) GetDB().showCommon = v ~= false end

function Options:GetShowUncommon() return GetDB().showUncommon ~= false end

function Options:SetShowUncommon(_, v) GetDB().showUncommon = v ~= false end

function Options:GetShowRare() return GetDB().showRare ~= false end

function Options:SetShowRare(_, v) GetDB().showRare = v ~= false end

function Options:GetShowEpic() return GetDB().showEpic ~= false end

function Options:SetShowEpic(_, v) GetDB().showEpic = v ~= false end

function Options:GetShowLegendary() return GetDB().showLegendary ~= false end

function Options:SetShowLegendary(_, v) GetDB().showLegendary = v ~= false end

-- ---------------------------------------------------------------------------
-- Font (LSM key)
-- ---------------------------------------------------------------------------
function Options:GetFont()
    return GetDB().font or "__default"
end

function Options:SetFont(_, value)
    GetDB().font = value
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Background color (RGB)
-- ---------------------------------------------------------------------------
function Options:GetBgColor()
    return GetThemeColor("backgroundColor", { 0.05, 0.06, 0.08 })
end

function Options:SetBgColor(_, r, g, b)
    RefreshLayout()
end

-- ---------------------------------------------------------------------------
-- Scale
-- ---------------------------------------------------------------------------
function Options:GetScale()
    return GetDB().scale or 1.0
end

function Options:SetScale(_, value)
    GetDB().scale = value
    RefreshLayout()
end
