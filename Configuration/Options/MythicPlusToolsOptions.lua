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

local function GetGlobalBarTexture()
    local theme = T:GetModule("Theme", true)
    return (theme and theme:Get("statusBarTexture")) or DEFAULT_BAR_TEXTURE
end

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
    mythicPlusTimerEnabled = true,
    mythicPlusTimerLocked = true,
    mythicPlusTimerStyle = "framed",
    mythicPlusTimerScale = 1,
    mythicPlusTimerShowHeader = true,
    mythicPlusTimerLayout = "left",
    mythicPlusTimerFontColor = { r = 1, g = 0.95, b = 0.86 },
    mythicPlusTimerBarColorMode = "milestone",
    mythicPlusTimerBarColor = { r = 0.42, g = 0.82, b = 0.98 },
    mythicPlusTimerShowBossCheckpoints = true,
    mythicPlusTimerNotifyPlusThreeExpired = true,
    mythicPlusTimerNotifyPlusTwoExpired = true,
    mythicPlusTimerNotifyPlusOneExpired = true,
    mythicPlusTimerNotifyForcesComplete = true,
    mythicPlusTimerNotificationSound = DEFAULT_SOUND,
    mythicPlusTimerNotificationDisplayTime = DEFAULT_NOTIFICATION_DISPLAY_TIME,
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

local VALID_TIMER_FRAME_STYLES = {
    framed = true,
    transparent = true,
}

local VALID_TIMER_LAYOUTS = {
    left = true,
    right = true,
}

local VALID_TIMER_BAR_COLOR_MODES = {
    milestone = true,
    custom = true,
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
    return self:GetDB().trackerBarTexture or GetGlobalBarTexture()
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

function Options:GetMythicPlusTimerEnabled()
    local value = self:GetDB().mythicPlusTimerEnabled
    if value == nil then
        return DEFAULTS.mythicPlusTimerEnabled
    end

    return value == true
end

function Options:SetMythicPlusTimerEnabled(info, value)
    self:GetDB().mythicPlusTimerEnabled = NormalizeBoolean(value)
    local module = GetModule()
    if module and module.RefreshMythicPlusTimerFrame then
        module:RefreshMythicPlusTimerFrame()
    end
end

function Options:GetMythicPlusTimerLocked()
    local value = self:GetDB().mythicPlusTimerLocked
    if value == nil then
        return DEFAULTS.mythicPlusTimerLocked
    end

    return value == true
end

function Options:SetMythicPlusTimerLocked(info, value)
    self:GetDB().mythicPlusTimerLocked = NormalizeBoolean(value)
    local module = GetModule()
    if module and module.ApplyFrameLockStates then
        module:ApplyFrameLockStates()
    end
end

function Options:GetMythicPlusTimerStyle()
    local value = self:GetDB().mythicPlusTimerStyle
    if VALID_TIMER_FRAME_STYLES[value] then
        return value
    end

    return DEFAULTS.mythicPlusTimerStyle
end

function Options:SetMythicPlusTimerStyle(info, value)
    if not VALID_TIMER_FRAME_STYLES[value] then
        value = DEFAULTS.mythicPlusTimerStyle
    end

    self:GetDB().mythicPlusTimerStyle = value
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerScale()
    return ClampNumber(self:GetDB().mythicPlusTimerScale, 0.7, 1.5, DEFAULTS.mythicPlusTimerScale)
end

function Options:SetMythicPlusTimerScale(info, value)
    self:GetDB().mythicPlusTimerScale = ClampNumber(value, 0.7, 1.5, DEFAULTS.mythicPlusTimerScale)
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerShowHeader()
    local value = self:GetDB().mythicPlusTimerShowHeader
    if value == nil then
        return DEFAULTS.mythicPlusTimerShowHeader
    end

    return value == true
end

function Options:SetMythicPlusTimerShowHeader(info, value)
    self:GetDB().mythicPlusTimerShowHeader = NormalizeBoolean(value)
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerLayout()
    local value = self:GetDB().mythicPlusTimerLayout
    if VALID_TIMER_LAYOUTS[value] then
        return value
    end

    return DEFAULTS.mythicPlusTimerLayout
end

function Options:SetMythicPlusTimerLayout(info, value)
    if not VALID_TIMER_LAYOUTS[value] then
        value = DEFAULTS.mythicPlusTimerLayout
    end

    self:GetDB().mythicPlusTimerLayout = value
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerFont()
    return self:GetDB().mythicPlusTimerFont or self:GetTrackerFont()
end

function Options:SetMythicPlusTimerFont(info, value)
    self:GetDB().mythicPlusTimerFont = value or self:GetTrackerFont()
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerFontSize()
    return ClampNumber(self:GetDB().mythicPlusTimerFontSize, 8, 28, self:GetTrackerFontSize())
end

function Options:SetMythicPlusTimerFontSize(info, value)
    self:GetDB().mythicPlusTimerFontSize = math.floor(ClampNumber(value, 8, 28, self:GetTrackerFontSize()) + 0.5)
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerFontOutline()
    local value = self:GetDB().mythicPlusTimerFontOutline
    if value == "none" or value == "outline" or value == "thick" then
        return value
    end

    local shared = self:GetTrackerFontOutline()
    if shared == "none" or shared == "outline" or shared == "thick" then
        return shared
    end

    return DEFAULTS.trackerFontOutline
end

function Options:SetMythicPlusTimerFontOutline(info, value)
    self:GetDB().mythicPlusTimerFontOutline = value or self:GetTrackerFontOutline()
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerFontColor()
    local color = self:GetDB().mythicPlusTimerFontColor or self:GetDB().statusTextColor or DEFAULTS.mythicPlusTimerFontColor
    return color.r, color.g, color.b, color.a or 1
end

function Options:SetMythicPlusTimerFontColor(info, red, green, blue, alpha)
    self:GetDB().mythicPlusTimerFontColor = NormalizeColor(self:GetDB().mythicPlusTimerFontColor or DEFAULTS.mythicPlusTimerFontColor, red, green, blue, alpha)
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerBarTexture()
    return self:GetDB().mythicPlusTimerBarTexture or self:GetTrackerBarTexture()
end

function Options:SetMythicPlusTimerBarTexture(info, value)
    self:GetDB().mythicPlusTimerBarTexture = value or self:GetTrackerBarTexture()
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerBarColorMode()
    local value = self:GetDB().mythicPlusTimerBarColorMode
    if VALID_TIMER_BAR_COLOR_MODES[value] then
        return value
    end

    return DEFAULTS.mythicPlusTimerBarColorMode
end

function Options:SetMythicPlusTimerBarColorMode(info, value)
    if not VALID_TIMER_BAR_COLOR_MODES[value] then
        value = DEFAULTS.mythicPlusTimerBarColorMode
    end

    self:GetDB().mythicPlusTimerBarColorMode = value
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerBarColor()
    local color = self:GetDB().mythicPlusTimerBarColor or DEFAULTS.mythicPlusTimerBarColor
    return color.r, color.g, color.b, color.a or 1
end

function Options:SetMythicPlusTimerBarColor(info, red, green, blue, alpha)
    self:GetDB().mythicPlusTimerBarColor = NormalizeColor(self:GetDB().mythicPlusTimerBarColor or DEFAULTS.mythicPlusTimerBarColor, red, green, blue, alpha)
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerRowGap()
    return ClampNumber(self:GetDB().mythicPlusTimerRowGap, 0, 30, self:GetTrackerRowGap())
end

function Options:SetMythicPlusTimerRowGap(info, value)
    self:GetDB().mythicPlusTimerRowGap = math.floor(ClampNumber(value, 0, 30, self:GetTrackerRowGap()) + 0.5)
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerBarHeight()
    return ClampNumber(self:GetDB().mythicPlusTimerBarHeight, 10, 40, self:GetTrackerBarHeight())
end

function Options:SetMythicPlusTimerBarHeight(info, value)
    self:GetDB().mythicPlusTimerBarHeight = math.floor(ClampNumber(value, 10, 40, self:GetTrackerBarHeight()) + 0.5)
    self:RefreshModuleAppearance()
end

function Options:GetMythicPlusTimerShowBossCheckpoints()
    local value = self:GetDB().mythicPlusTimerShowBossCheckpoints
    if value == nil then
        return DEFAULTS.mythicPlusTimerShowBossCheckpoints
    end

    return value == true
end

function Options:SetMythicPlusTimerShowBossCheckpoints(info, value)
    self:GetDB().mythicPlusTimerShowBossCheckpoints = NormalizeBoolean(value)
    local module = GetModule()
    if module and module.RefreshMythicPlusTimerFrame then
        module:RefreshMythicPlusTimerFrame()
    end
end

function Options:GetMythicPlusTimerNotifyPlusThreeExpired()
    local value = self:GetDB().mythicPlusTimerNotifyPlusThreeExpired
    if value == nil then
        return DEFAULTS.mythicPlusTimerNotifyPlusThreeExpired
    end

    return value == true
end

function Options:SetMythicPlusTimerNotifyPlusThreeExpired(info, value)
    self:GetDB().mythicPlusTimerNotifyPlusThreeExpired = NormalizeBoolean(value)
end

function Options:GetMythicPlusTimerNotifyPlusTwoExpired()
    local value = self:GetDB().mythicPlusTimerNotifyPlusTwoExpired
    if value == nil then
        return DEFAULTS.mythicPlusTimerNotifyPlusTwoExpired
    end

    return value == true
end

function Options:SetMythicPlusTimerNotifyPlusTwoExpired(info, value)
    self:GetDB().mythicPlusTimerNotifyPlusTwoExpired = NormalizeBoolean(value)
end

function Options:GetMythicPlusTimerNotifyPlusOneExpired()
    local value = self:GetDB().mythicPlusTimerNotifyPlusOneExpired
    if value == nil then
        return DEFAULTS.mythicPlusTimerNotifyPlusOneExpired
    end

    return value == true
end

function Options:SetMythicPlusTimerNotifyPlusOneExpired(info, value)
    self:GetDB().mythicPlusTimerNotifyPlusOneExpired = NormalizeBoolean(value)
end

function Options:GetMythicPlusTimerNotifyForcesComplete()
    local value = self:GetDB().mythicPlusTimerNotifyForcesComplete
    if value == nil then
        return DEFAULTS.mythicPlusTimerNotifyForcesComplete
    end

    return value == true
end

function Options:SetMythicPlusTimerNotifyForcesComplete(info, value)
    self:GetDB().mythicPlusTimerNotifyForcesComplete = NormalizeBoolean(value)
end

function Options:GetMythicPlusTimerNotificationSound()
    local db = self:GetDB()
    if db.mythicPlusTimerNotificationSound == nil then
        return DEFAULTS.mythicPlusTimerNotificationSound
    end

    return db.mythicPlusTimerNotificationSound
end

function Options:SetMythicPlusTimerNotificationSound(info, value)
    self:GetDB().mythicPlusTimerNotificationSound = NormalizeSound(value)
end

function Options:GetMythicPlusTimerNotificationDisplayTime()
    return self:GetDB().mythicPlusTimerNotificationDisplayTime or DEFAULTS.mythicPlusTimerNotificationDisplayTime
end

function Options:SetMythicPlusTimerNotificationDisplayTime(info, value)
    self:GetDB().mythicPlusTimerNotificationDisplayTime = tonumber(value) or DEFAULTS.mythicPlusTimerNotificationDisplayTime
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

function Options:ResetMythicPlusTimerPosition()
    local module = GetModule()
    if module and module.ResetMythicPlusTimerPosition then
        module:ResetMythicPlusTimerPosition()
    end
end

function Options:ResetMythicPlusTimerAppearance()
    local db = self:GetDB()
    db.mythicPlusTimerFont = nil
    db.mythicPlusTimerFontSize = nil
    db.mythicPlusTimerFontOutline = nil
    db.mythicPlusTimerFontColor = nil
    db.mythicPlusTimerShowHeader = nil
    db.mythicPlusTimerBarTexture = nil
    db.mythicPlusTimerBarColorMode = nil
    db.mythicPlusTimerBarColor = nil
    db.mythicPlusTimerRowGap = nil
    db.mythicPlusTimerBarHeight = nil
    db.mythicPlusTimerLayout = nil
    self:RefreshModuleAppearance()
end

function Options:OpenMythicPlusTimerSettings()
    local ui = ConfigurationModule and ConfigurationModule.StandaloneUI
    if ui and ui.Show then
        ui:Show("Mythic+ Tools")
    end
end

function Options:TestDeathNotification()
    local module = GetModule()
    if module and module.TestDeathNotification then
        module:TestDeathNotification()
    end
end

function Options:TestMythicPlusTimerNotification(kind)
    local module = GetModule()
    if module and module.TestMythicPlusTimerNotification then
        module:TestMythicPlusTimerNotification(kind)
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

function Options:StartMythicPlusTimerPreview()
    local module = GetModule()
    if module and module.SetMythicPlusTimerPreviewEnabled then
        module:SetMythicPlusTimerPreviewEnabled(true)
    end
end

function Options:StopMythicPlusTimerPreview()
    local module = GetModule()
    if module and module.SetMythicPlusTimerPreviewEnabled then
        module:SetMythicPlusTimerPreviewEnabled(false)
    end
end

function Options:DebugMythicPlusTimerBossAnimation()
    local module = GetModule()
    if module and module.DebugMythicPlusTimerBossAnimation then
        module:DebugMythicPlusTimerBossAnimation()
    end
end

function Options:DebugMythicPlusTimerUpgradeAnimation()
    local module = GetModule()
    if module and module.DebugMythicPlusTimerUpgradeAnimation then
        module:DebugMythicPlusTimerUpgradeAnimation()
    end
end