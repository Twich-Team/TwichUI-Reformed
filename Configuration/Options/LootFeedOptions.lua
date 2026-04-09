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
        profile.lootFeed = {}
    end
    return profile.lootFeed
end

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("LootFeed")
end

-- ---------------------------------------------------------------------------
-- GetAll — used by the module for a snapshot of all settings
-- ---------------------------------------------------------------------------
function Options:GetAll()
    local db = GetDB()
    return {
        enabled         = db.enabled ~= false,
        locked          = db.locked == true,
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
        bgAlpha         = db.bgAlpha ~= nil and db.bgAlpha or 0.45,
        bgColorR        = db.bgColorR ~= nil and db.bgColorR or 0,
        bgColorG        = db.bgColorG ~= nil and db.bgColorG or 0,
        bgColorB        = db.bgColorB ~= nil and db.bgColorB or 0,
        scale           = db.scale or 1.0,
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
    local m = GetModule()
    if m:IsEnabled() then
        m:RefreshLayout()
    end
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
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Grow direction
-- ---------------------------------------------------------------------------
function Options:GetGrowUp()
    return GetDB().growUp ~= false
end

function Options:SetGrowUp(_, value)
    GetDB().growUp = value ~= false
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Max rows
-- ---------------------------------------------------------------------------
function Options:GetMaxRows()
    return GetDB().maxRows or 8
end

function Options:SetMaxRows(_, value)
    GetDB().maxRows = value
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Row height
-- ---------------------------------------------------------------------------
function Options:GetRowHeight()
    return GetDB().rowHeight or 26
end

function Options:SetRowHeight(_, value)
    GetDB().rowHeight = value
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Feed width
-- ---------------------------------------------------------------------------
function Options:GetFeedWidth()
    return GetDB().feedWidth or 270
end

function Options:SetFeedWidth(_, value)
    GetDB().feedWidth = value
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Icon size
-- ---------------------------------------------------------------------------
function Options:GetIconSize()
    return GetDB().iconSize or 22
end

function Options:SetIconSize(_, value)
    GetDB().iconSize = value
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
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
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Font outline
-- ---------------------------------------------------------------------------
function Options:GetFontOutline()
    return GetDB().fontOutline or "OUTLINE"
end

function Options:SetFontOutline(_, value)
    GetDB().fontOutline = value or "OUTLINE"
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Background alpha
-- ---------------------------------------------------------------------------
function Options:GetBgAlpha()
    local v = GetDB().bgAlpha
    return v ~= nil and v or 0.45
end

function Options:SetBgAlpha(_, value)
    GetDB().bgAlpha = value
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
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
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Background color (RGB)
-- ---------------------------------------------------------------------------
function Options:GetBgColor()
    local db = GetDB()
    local r = db.bgColorR ~= nil and db.bgColorR or 0
    local g = db.bgColorG ~= nil and db.bgColorG or 0
    local b = db.bgColorB ~= nil and db.bgColorB or 0
    return r, g, b
end

function Options:SetBgColor(_, r, g, b)
    local db = GetDB()
    db.bgColorR = r
    db.bgColorG = g
    db.bgColorB = b
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end

-- ---------------------------------------------------------------------------
-- Scale
-- ---------------------------------------------------------------------------
function Options:GetScale()
    return GetDB().scale or 1.0
end

function Options:SetScale(_, value)
    GetDB().scale = value
    local m = GetModule()
    if m:IsEnabled() then m:RefreshLayout() end
end
