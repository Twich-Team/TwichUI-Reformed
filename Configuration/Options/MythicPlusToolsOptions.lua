---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class MythicPlusToolsConfigurationOptions
local Options = ConfigurationModule.Options.MythicPlusTools or {}
ConfigurationModule.Options.MythicPlusTools = Options

local DEFAULT_SOUND = "TwichUI Alert 1"
local NONE_SOUND_VALUE = "__none"
local DEFAULT_NOTIFICATION_DISPLAY_TIME = 8
local DEFAULT_FONT = "__default"
local DEFAULT_BAR_TEXTURE = "Blizzard"

local DEFAULTS = {
    trackerFont = DEFAULT_FONT,
    trackerFontSize = 12,
    trackerFontOutline = "default",
    trackerBarTexture = DEFAULT_BAR_TEXTURE,
    trackerRowGap = 6,
    trackerIconSize = 18,
    trackerBarHeight = 18,
    statusTextFont = DEFAULT_FONT,
    statusTextColor = { r = 0.96, g = 0.93, b = 0.86 },
    readyTextFont = DEFAULT_FONT,
    readyTextColor = { r = 0.32, g = 0.86, b = 0.54 },
    showReadyText = true,
    frameVisibilityMode = "mythicplus",
    interruptUseClassBarColor = true,
    interruptBarColor = { r = 0.33, g = 0.65, b = 0.96 },
    interruptReadyBarColorMode = "default",
    interruptReadyBarColor = { r = 0.32, g = 0.86, b = 0.54 },
    interruptUseClassFontColor = true,
    interruptFontColor = { r = 0.96, g = 0.93, b = 0.86 },
    trackerStyle = "paneled",
}

local VALID_FRAME_VISIBILITY_MODES = {
    always = true,
    combat = true,
    group = true,
    dungeon = true,
    mythicplus = true,
}

local VALID_INTERRUPT_READY_BAR_COLOR_MODES = {
    default = true,
    class = true,
    static = true,
}

local VALID_TRACKER_STYLES = {
    paneled = true,
    bare = true,
}

local function NormalizeBoolean(value)
    return value == true
end

local function NormalizeSound(value)
    if value == NONE_SOUND_VALUE then
        return NONE_SOUND_VALUE
    end

    if type(value) ~= "string" or value == "" then
        return nil
    end

    return value
end

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function NormalizeColor(current, red, green, blue, alpha)
    return {
        r = ClampNumber(red, 0, 1, current and current.r or 1),
        g = ClampNumber(green, 0, 1, current and current.g or 1),
        b = ClampNumber(blue, 0, 1, current and current.b or 1),
        a = ClampNumber(alpha, 0, 1, current and current.a or 1),
    }
end

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().mythicPlusTools then
        ConfigurationModule:GetProfileDB().mythicPlusTools = {}
    end

    return ConfigurationModule:GetProfileDB().mythicPlusTools
end

local function GetModule()
    return _G.TwichUIMythicPlusToolsRuntime
end

function Options:RefreshModuleAppearance()
    local module = GetModule()
    if module and module.RefreshTrackerStyling then
        module:RefreshTrackerStyling()
    end
end

function Options:GetEnabled()
    return self:GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    local db = self:GetDB()
    db.enabled = NormalizeBoolean(value)

    local module = GetModule()
    if module and module.RefreshModuleState then
        module:RefreshModuleState()
    end
end

function Options:GetDebugEnabled()
    return self:GetDB().debugEnabled == true
end

function Options:SetDebugEnabled(info, value)
    self:GetDB().debugEnabled = NormalizeBoolean(value)

    if value ~= true and T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole then
        T.Tools.UI.DebugConsole:ClearLogs("mythicplustools")
    end
end

function Options:OpenDebugConsole()
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if console and console.Show then
        console:Show("mythicplustools")
    end
end

function Options:GetAutoSlotKeystoneEnabled()
    return self:GetDB().autoSlotKeystone ~= false
end

function Options:SetAutoSlotKeystoneEnabled(info, value)
    self:GetDB().autoSlotKeystone = NormalizeBoolean(value)
end

function Options:GetAutoStartDungeonEnabled()
    return self:GetDB().autoStartDungeon == true
end

function Options:SetAutoStartDungeonEnabled(info, value)
    self:GetDB().autoStartDungeon = NormalizeBoolean(value)
end

function Options:GetDeathNotificationEnabled()
    return self:GetDB().deathNotificationEnabled ~= false
end

function Options:SetDeathNotificationEnabled(info, value)
    self:GetDB().deathNotificationEnabled = NormalizeBoolean(value)
end

function Options:GetDeathNotificationSound()
    local db = self:GetDB()
    if db.deathNotificationSound == nil then
        return DEFAULT_SOUND
    end

    return db.deathNotificationSound
end

function Options:SetDeathNotificationSound(info, value)
    self:GetDB().deathNotificationSound = NormalizeSound(value)
end

function Options:GetDeathNotificationDisplayTime()
    return self:GetDB().deathNotificationDisplayTime or DEFAULT_NOTIFICATION_DISPLAY_TIME
end

function Options:SetDeathNotificationDisplayTime(info, value)
    self:GetDB().deathNotificationDisplayTime = tonumber(value) or DEFAULT_NOTIFICATION_DISPLAY_TIME
end

function Options:GetNotifyForTankDeaths()
    local db = self:GetDB()
    if db.notifyTankDeaths == nil then
        return true
    end

    return db.notifyTankDeaths == true
end

function Options:SetNotifyForTankDeaths(info, value)
    self:GetDB().notifyTankDeaths = NormalizeBoolean(value)
end

function Options:GetNotifyForHealerDeaths()
    local db = self:GetDB()
    if db.notifyHealerDeaths == nil then
        return true
    end

    return db.notifyHealerDeaths == true
end

function Options:SetNotifyForHealerDeaths(info, value)
    self:GetDB().notifyHealerDeaths = NormalizeBoolean(value)
end

function Options:GetNotifyForDPSDeaths()
    local db = self:GetDB()
    if db.notifyDPSDeaths == nil then
        return true
    end

    return db.notifyDPSDeaths == true
end

function Options:SetNotifyForDPSDeaths(info, value)
    self:GetDB().notifyDPSDeaths = NormalizeBoolean(value)
end

function Options:GetNotifyForSelfDeaths()
    return self:GetDB().notifySelfDeaths == true
end

function Options:SetNotifyForSelfDeaths(info, value)
    self:GetDB().notifySelfDeaths = NormalizeBoolean(value)
end

function Options:GetSuppressWipeSpam()
    local db = self:GetDB()
    if db.suppressWipeSpam == nil then
        return true
    end

    return db.suppressWipeSpam == true
end

function Options:SetSuppressWipeSpam(info, value)
    self:GetDB().suppressWipeSpam = NormalizeBoolean(value)
end

function Options:GetTrackerFont()
    return self:GetDB().trackerFont or DEFAULTS.trackerFont
end

function Options:SetTrackerFont(info, value)
    self:GetDB().trackerFont = value or DEFAULTS.trackerFont
    self:RefreshModuleAppearance()
end

function Options:GetTrackerFontSize()
    return ClampNumber(self:GetDB().trackerFontSize, 8, 24, DEFAULTS.trackerFontSize)
end

function Options:SetTrackerFontSize(info, value)
    self:GetDB().trackerFontSize = math.floor(ClampNumber(value, 8, 24, DEFAULTS.trackerFontSize) + 0.5)
    self:RefreshModuleAppearance()
end

function Options:GetTrackerFontOutline()
    local value = self:GetDB().trackerFontOutline
    if value == "none" or value == "outline" or value == "thick" then
        return value
    end

    return DEFAULTS.trackerFontOutline
end

function Options:SetTrackerFontOutline(info, value)
    self:GetDB().trackerFontOutline = value or DEFAULTS.trackerFontOutline
    self:RefreshModuleAppearance()
end

function Options:GetTrackerBarTexture()
    return self:GetDB().trackerBarTexture or DEFAULTS.trackerBarTexture
end

function Options:SetTrackerBarTexture(info, value)
    self:GetDB().trackerBarTexture = value or DEFAULTS.trackerBarTexture
    self:RefreshModuleAppearance()
end

function Options:GetTrackerRowGap()
    return ClampNumber(self:GetDB().trackerRowGap, 0, 30, DEFAULTS.trackerRowGap)
end

function Options:SetTrackerRowGap(info, value)
    self:GetDB().trackerRowGap = math.floor(ClampNumber(value, 0, 30, DEFAULTS.trackerRowGap) + 0.5)
    self:RefreshModuleAppearance()
end

function Options:GetTrackerIconSize()
    return ClampNumber(self:GetDB().trackerIconSize, 14, 48, DEFAULTS.trackerIconSize)
end

function Options:SetTrackerIconSize(info, value)
    self:GetDB().trackerIconSize = math.floor(ClampNumber(value, 14, 48, DEFAULTS.trackerIconSize) + 0.5)
    self:RefreshModuleAppearance()
end

function Options:GetTrackerBarHeight()
    return ClampNumber(self:GetDB().trackerBarHeight, 10, 40, DEFAULTS.trackerBarHeight)
end

function Options:SetTrackerBarHeight(info, value)
    self:GetDB().trackerBarHeight = math.floor(ClampNumber(value, 10, 40, DEFAULTS.trackerBarHeight) + 0.5)
    self:RefreshModuleAppearance()
end

function Options:GetStatusTextFont()
    return self:GetDB().statusTextFont or DEFAULTS.statusTextFont
end

function Options:SetStatusTextFont(info, value)
    self:GetDB().statusTextFont = value or DEFAULTS.statusTextFont
    self:RefreshModuleAppearance()
end

function Options:GetStatusTextColor()
    local color = self:GetDB().statusTextColor or DEFAULTS.statusTextColor
    return color.r, color.g, color.b, color.a or 1
end

function Options:SetStatusTextColor(info, red, green, blue, alpha)
    self:GetDB().statusTextColor = NormalizeColor(self:GetDB().statusTextColor or DEFAULTS.statusTextColor, red, green, blue, alpha)
    self:RefreshModuleAppearance()
end

function Options:GetReadyTextFont()
    return self:GetDB().readyTextFont or DEFAULTS.readyTextFont
end

function Options:SetReadyTextFont(info, value)
    self:GetDB().readyTextFont = value or DEFAULTS.readyTextFont
    self:RefreshModuleAppearance()
end

function Options:GetReadyTextColor()
    local color = self:GetDB().readyTextColor or DEFAULTS.readyTextColor
    return color.r, color.g, color.b, color.a or 1
end

function Options:SetReadyTextColor(info, red, green, blue, alpha)
    self:GetDB().readyTextColor = NormalizeColor(self:GetDB().readyTextColor or DEFAULTS.readyTextColor, red, green, blue, alpha)
    self:RefreshModuleAppearance()
end

function Options:GetShowReadyText()
    local value = self:GetDB().showReadyText
    if value == nil then
        return DEFAULTS.showReadyText
    end

    return value == true
end

function Options:SetShowReadyText(info, value)
    self:GetDB().showReadyText = value == true
    self:RefreshModuleAppearance()
end

function Options:GetFrameVisibilityMode()
    local value = self:GetDB().frameVisibilityMode
    if VALID_FRAME_VISIBILITY_MODES[value] then
        return value
    end

    return DEFAULTS.frameVisibilityMode
end

function Options:SetFrameVisibilityMode(info, value)
    if not VALID_FRAME_VISIBILITY_MODES[value] then
        value = DEFAULTS.frameVisibilityMode
    end

    self:GetDB().frameVisibilityMode = value

    local module = GetModule()
    if module and module.RefreshModuleState then
        module:RefreshModuleState()
    end
end

function Options:GetInterruptUseClassBarColor()
    local value = self:GetDB().interruptUseClassBarColor
    if value == nil then
        return DEFAULTS.interruptUseClassBarColor
    end

    return value == true
end

function Options:SetInterruptUseClassBarColor(info, value)
    self:GetDB().interruptUseClassBarColor = value == true
    self:RefreshModuleAppearance()
end

function Options:GetInterruptBarColor()
    local color = self:GetDB().interruptBarColor or DEFAULTS.interruptBarColor
    return color.r, color.g, color.b, color.a or 1
end

function Options:SetInterruptBarColor(info, red, green, blue, alpha)
    self:GetDB().interruptBarColor = NormalizeColor(self:GetDB().interruptBarColor or DEFAULTS.interruptBarColor, red, green, blue, alpha)
    self:RefreshModuleAppearance()
end

function Options:GetInterruptReadyBarColorMode()
    local value = self:GetDB().interruptReadyBarColorMode
    if VALID_INTERRUPT_READY_BAR_COLOR_MODES[value] then
        return value
    end

    return DEFAULTS.interruptReadyBarColorMode
end

function Options:SetInterruptReadyBarColorMode(info, value)
    if not VALID_INTERRUPT_READY_BAR_COLOR_MODES[value] then
        value = DEFAULTS.interruptReadyBarColorMode
    end

    self:GetDB().interruptReadyBarColorMode = value
    self:RefreshModuleAppearance()
end

function Options:GetInterruptReadyBarColor()
    local color = self:GetDB().interruptReadyBarColor or DEFAULTS.interruptReadyBarColor
    return color.r, color.g, color.b, color.a or 1
end

function Options:SetInterruptReadyBarColor(info, red, green, blue, alpha)
    self:GetDB().interruptReadyBarColor = NormalizeColor(self:GetDB().interruptReadyBarColor or DEFAULTS.interruptReadyBarColor, red, green, blue, alpha)
    self:RefreshModuleAppearance()
end

function Options:GetInterruptUseClassFontColor()
    local value = self:GetDB().interruptUseClassFontColor
    if value == nil then
        return DEFAULTS.interruptUseClassFontColor
    end

    return value == true
end

function Options:SetInterruptUseClassFontColor(info, value)
    self:GetDB().interruptUseClassFontColor = value == true
    self:RefreshModuleAppearance()
end

function Options:GetInterruptFontColor()
    local color = self:GetDB().interruptFontColor or DEFAULTS.interruptFontColor
    return color.r, color.g, color.b, color.a or 1
end

function Options:SetInterruptFontColor(info, red, green, blue, alpha)
    self:GetDB().interruptFontColor = NormalizeColor(self:GetDB().interruptFontColor or DEFAULTS.interruptFontColor, red, green, blue, alpha)
    self:RefreshModuleAppearance()
end

function Options:GetTrackerStyle()
    local value = self:GetDB().trackerStyle
    if VALID_TRACKER_STYLES[value] then
        return value
    end

    return DEFAULTS.trackerStyle
end

function Options:SetTrackerStyle(info, value)
    if not VALID_TRACKER_STYLES[value] then
        value = DEFAULTS.trackerStyle
    end

    self:GetDB().trackerStyle = value
    self:RefreshModuleAppearance()
end

function Options:GetInterruptTrackerEnabled()
    return self:GetDB().interruptTrackerEnabled ~= false
end

function Options:SetInterruptTrackerEnabled(info, value)
    self:GetDB().interruptTrackerEnabled = NormalizeBoolean(value)
    local module = GetModule()
    if module and module.RefreshInterruptFrame then
        module:RefreshInterruptFrame()
    end
end

function Options:GetInterruptTrackerLocked()
    local db = self:GetDB()
    if db.interruptTrackerLocked == nil then
        return true
    end

    return db.interruptTrackerLocked == true
end

function Options:SetInterruptTrackerLocked(info, value)
    self:GetDB().interruptTrackerLocked = NormalizeBoolean(value)
    local module = GetModule()
    if module and module.ApplyFrameLockStates then
        module:ApplyFrameLockStates()
    end
end

function Options:GetInterruptReadySound()
    return self:GetDB().interruptReadySound or NONE_SOUND_VALUE
end

function Options:SetInterruptReadySound(info, value)
    self:GetDB().interruptReadySound = NormalizeSound(value)
end

function Options:ResetInterruptTrackerPosition()
    local module = GetModule()
    if module and module.ResetInterruptTrackerPosition then
        module:ResetInterruptTrackerPosition()
    end
end

function Options:TestDeathNotification()
    local module = GetModule()
    if module and module.TestDeathNotification then
        module:TestDeathNotification()
    end
end

function Options:TestPullTimer()
    local module = GetModule()
    if module and module.TestPullTimer then
        module:TestPullTimer()
    end
end

function Options:StartInterruptPreview()
    local module = GetModule()
    if module and module.SetInterruptPreviewEnabled then
        module:SetInterruptPreviewEnabled(true)
    end
end

function Options:StopInterruptPreview()
    local module = GetModule()
    if module and module.SetInterruptPreviewEnabled then
        module:SetInterruptPreviewEnabled(false)
    end
end