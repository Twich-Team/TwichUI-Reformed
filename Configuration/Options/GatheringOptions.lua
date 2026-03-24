---@diagnostic disable: undefined-field
--[[
    Configuration options for the Gathering module.
]]
local TwichRx                                  = _G.TwichRx
---@type TwichUI
local T                                        = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule                      = T:GetModule("Configuration")

---@class GatheringConfigurationOptions
local Options                                  = ConfigurationModule.Options.Gathering or {}
ConfigurationModule.Options.Gathering          = Options

local DEFAULT_PRICE_SOURCE                     = "DBMarket"
local DEFAULT_NOTIFICATION_DURATION            = 6
local DEFAULT_NOTIFICATION_SOUND               = "__none"
local DEFAULT_HIGH_VALUE_SOUND                 = "__none"
local DEFAULT_HIGH_VALUE_THRESHOLD             = 0
local DEFAULT_HUD_SIZE                         = 400
local DEFAULT_HUD_TERRAIN_ALPHA                = 0.50
local DEFAULT_RING_COLOR                       = { r = 0.0, g = 0.85, b = 1.0, a = 1.0 }
local DEFAULT_RING_WIDTH                       = 15
local DEFAULT_TRACKER_FONT                     = "Friz Quadrata TT"
local DEFAULT_TRACKER_FONT_SIZE                = 12
local DEFAULT_TRACKER_FONT_OUTLINE             = ""
local DEFAULT_TRACKER_BACKGROUND_ALPHA         = 0.96
local DEFAULT_TRACKER_ACCENT_COLOR             = { r = 0.2, g = 0.75, b = 0.3, a = 0.95 }
local DEFAULT_TRACKER_ITEM_COLUMN_WIDTH        = 170
local DEFAULT_TRACKER_QTY_COLUMN_WIDTH         = 50
local DEFAULT_TRACKER_ITEM_VALUE_COLUMN_WIDTH  = 80
local DEFAULT_TRACKER_TOTAL_VALUE_COLUMN_WIDTH = 90
local DEFAULT_GPH_UPDATE_INTERVAL              = 5
local floor                                    = math.floor
local tonumber                                 = tonumber

-- ============================================================
-- DB accessor
-- ============================================================
function Options:GetDB()
    local cfg = ConfigurationModule:GetProfileDB()
    if not cfg.gathering then
        cfg.gathering = {}
    end
    return cfg.gathering
end

-- ============================================================
-- Module enable / disable
-- ============================================================
function Options:GetEnabled(info)
    return self:GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    self:GetDB().enabled = value == true
    local mod = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if mod then
        if value then
            mod:Enable()
        else
            mod:Disable()
        end
    end
end

function Options:GetDebugEnabled(info)
    return self:GetDB().debugEnabled == true
end

function Options:SetDebugEnabled(info, value)
    self:GetDB().debugEnabled = value == true

    if value ~= true and T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole then
        T.Tools.UI.DebugConsole:ClearLogs("gathering")
    end
end

function Options:OpenDebugConsole()
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if console and console.Show then
        console:Show("gathering")
    end
end

-- ============================================================
-- HUD settings
-- ============================================================
function Options:GetHudSize(info)
    return self:GetDB().hudSize or DEFAULT_HUD_SIZE
end

function Options:SetHudSize(info, value)
    self:GetDB().hudSize = value
end

function Options:GetHudTerrainTransparent(info)
    local v = self:GetDB().hudTerrainTransparent
    return v == nil and false or v
end

function Options:SetHudTerrainTransparent(info, value)
    self:GetDB().hudTerrainTransparent = value == true
end

function Options:GetHudTerrainAlpha(info)
    return self:GetDB().hudTerrainAlpha or DEFAULT_HUD_TERRAIN_ALPHA
end

function Options:SetHudTerrainAlpha(info, value)
    self:GetDB().hudTerrainAlpha = value
end

-- Ring color
function Options:GetHudRingColor(info)
    local c = self:GetDB().hudRingColor or DEFAULT_RING_COLOR
    return c.r, c.g, c.b, c.a
end

function Options:SetHudRingColor(info, r, g, b, a)
    self:GetDB().hudRingColor = { r = r, g = g, b = b, a = a }
    -- Live-update ring if HUD active
    local mod = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if mod and mod.hud and mod.hud.active then
        mod:RefreshHUDRing()
    end
end

function Options:GetHudRingWidth(info)
    return self:GetDB().hudRingWidth or DEFAULT_RING_WIDTH
end

function Options:SetHudRingWidth(info, value)
    self:GetDB().hudRingWidth = value
end

function Options:GetTrackerLocked(info)
    return self:GetDB().trackerLocked == true
end

function Options:SetTrackerLocked(info, value)
    self:GetDB().trackerLocked = value == true
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.UpdateTrackerInteractivity then
        module:UpdateTrackerInteractivity()
    end
end

function Options:ResetTrackerPosition()
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.ResetTrackerPosition then
        module:ResetTrackerPosition()
    end
end

function Options:GetTrackerFont(info)
    return self:GetDB().trackerFont or DEFAULT_TRACKER_FONT
end

function Options:SetTrackerFont(info, value)
    self:GetDB().trackerFont = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.RefreshTrackerFrame then
        module:RefreshTrackerFrame()
    end
end

function Options:GetTrackerFontSize(info)
    return self:GetDB().trackerFontSize or DEFAULT_TRACKER_FONT_SIZE
end

function Options:SetTrackerFontSize(info, value)
    self:GetDB().trackerFontSize = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.RefreshTrackerFrame then
        module:RefreshTrackerFrame()
    end
end

function Options:GetTrackerFontOutline(info)
    return self:GetDB().trackerFontOutline or DEFAULT_TRACKER_FONT_OUTLINE
end

function Options:SetTrackerFontOutline(info, value)
    self:GetDB().trackerFontOutline = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.RefreshTrackerFrame then
        module:RefreshTrackerFrame()
    end
end

function Options:GetTrackerBackgroundAlpha(info)
    return self:GetDB().trackerBackgroundAlpha or DEFAULT_TRACKER_BACKGROUND_ALPHA
end

function Options:SetTrackerBackgroundAlpha(info, value)
    self:GetDB().trackerBackgroundAlpha = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.ApplyTrackerFrameStyle then
        module:ApplyTrackerFrameStyle()
    end
end

function Options:GetTrackerAccentColor(info)
    local c = self:GetDB().trackerAccentColor or DEFAULT_TRACKER_ACCENT_COLOR
    return c.r, c.g, c.b, c.a
end

function Options:SetTrackerAccentColor(info, r, g, b, a)
    self:GetDB().trackerAccentColor = { r = r, g = g, b = b, a = a }
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.ApplyTrackerFrameStyle then
        module:ApplyTrackerFrameStyle()
    end
end

function Options:GetTrackerItemColumnWidth(info)
    return self:GetDB().trackerItemColumnWidth or DEFAULT_TRACKER_ITEM_COLUMN_WIDTH
end

function Options:SetTrackerItemColumnWidth(info, value)
    self:GetDB().trackerItemColumnWidth = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.RefreshTrackerFrame then
        module:RefreshTrackerFrame()
    end
end

function Options:GetTrackerQtyColumnWidth(info)
    return self:GetDB().trackerQtyColumnWidth or DEFAULT_TRACKER_QTY_COLUMN_WIDTH
end

function Options:SetTrackerQtyColumnWidth(info, value)
    self:GetDB().trackerQtyColumnWidth = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.RefreshTrackerFrame then
        module:RefreshTrackerFrame()
    end
end

function Options:GetTrackerItemValueColumnWidth(info)
    return self:GetDB().trackerItemValueColumnWidth or DEFAULT_TRACKER_ITEM_VALUE_COLUMN_WIDTH
end

function Options:SetTrackerItemValueColumnWidth(info, value)
    self:GetDB().trackerItemValueColumnWidth = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.RefreshTrackerFrame then
        module:RefreshTrackerFrame()
    end
end

function Options:GetTrackerTotalValueColumnWidth(info)
    return self:GetDB().trackerTotalValueColumnWidth or DEFAULT_TRACKER_TOTAL_VALUE_COLUMN_WIDTH
end

function Options:SetTrackerTotalValueColumnWidth(info, value)
    self:GetDB().trackerTotalValueColumnWidth = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.RefreshTrackerFrame then
        module:RefreshTrackerFrame()
    end
end

function Options:GetGPHUpdateInterval(info)
    return self:GetDB().gphUpdateInterval or DEFAULT_GPH_UPDATE_INTERVAL
end

function Options:SetGPHUpdateInterval(info, value)
    self:GetDB().gphUpdateInterval = value
    local module = T:GetModule("QualityOfLife"):GetModule("Gathering", true)
    if module and module.StartGPHTicker then
        module:StartGPHTicker()
    end
end

-- ============================================================
-- Notification settings
-- ============================================================
function Options:GetNotificationDuration(info)
    return self:GetDB().notificationDuration or DEFAULT_NOTIFICATION_DURATION
end

function Options:SetNotificationDuration(info, value)
    self:GetDB().notificationDuration = value
end

function Options:GetNotificationSound(info)
    return self:GetDB().notificationSound or DEFAULT_NOTIFICATION_SOUND
end

function Options:SetNotificationSound(info, value)
    self:GetDB().notificationSound = value
end

function Options:GetHighValueThresholdGold(info)
    local threshold = self:GetDB().highValueThreshold or DEFAULT_HIGH_VALUE_THRESHOLD
    if threshold <= 0 then
        return "0"
    end
    return string.format("%g", threshold / 10000)
end

function Options:SetHighValueThresholdGold(info, value)
    local numeric = tonumber((tostring(value or "0"):gsub(",", ""))) or 0
    if numeric < 0 then
        numeric = 0
    end
    self:GetDB().highValueThreshold = floor((numeric * 10000) + 0.5)
end

function Options:GetHighValueSound(info)
    return self:GetDB().highValueSound or DEFAULT_HIGH_VALUE_SOUND
end

function Options:SetHighValueSound(info, value)
    self:GetDB().highValueSound = value
end

-- ============================================================
-- TSM price source
-- ============================================================
function Options:GetPriceSource(info)
    return self:GetDB().priceSource or DEFAULT_PRICE_SOURCE
end

function Options:SetPriceSource(info, value)
    self:GetDB().priceSource = value
end

function Options:GetPriceSources()
    local sources = {}
    if _G.TSM_API and _G.TSM_API.GetPriceSourceKeys then
        local keys = {}
        pcall(_G.TSM_API.GetPriceSourceKeys, keys)
        for _, k in ipairs(keys) do
            local desc = ""
            if _G.TSM_API.GetPriceSourceDescription then
                pcall(function() desc = _G.TSM_API.GetPriceSourceDescription(k) end)
            end
            sources[k] = desc ~= "" and (k .. " — " .. desc) or k
        end
    end
    if not next(sources) then
        -- TSM not loaded; provide sensible defaults
        sources = {
            DBMarket    = "DBMarket — AuctionDB Market Value",
            DBMinBuyout = "DBMinBuyout — AuctionDB Min Buyout",
            VendorSell  = "VendorSell — Vendor Sell Price",
        }
    end
    return sources
end

-- ============================================================
-- Datatext options
-- ============================================================
function Options:GetDatatextEnabled(info)
    local v = self:GetDB().datatextEnabled
    return v == nil and true or v
end

function Options:SetDatatextEnabled(info, value)
    self:GetDB().datatextEnabled = value == true
end

function Options:GetShowGPH(info)
    local v = self:GetDB().showGPH
    return v == nil and true or v
end

function Options:SetShowGPH(info, value)
    self:GetDB().showGPH = value == true
end

function Options:GetShowSessionStatus(info)
    local v = self:GetDB().showSessionStatus
    return v == nil and true or v
end

function Options:SetShowSessionStatus(info, value)
    self:GetDB().showSessionStatus = value == true
end
