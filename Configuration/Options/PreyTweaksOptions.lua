---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class PreyTweaksConfigurationOptions
local Options = ConfigurationModule.Options.PreyTweaks or {}
ConfigurationModule.Options.PreyTweaks = Options

local DEFAULTS = {
    enabled = false,
    displayMode = "ring",
    ringBackgroundStyle = "full",
    hideBlizzardWidget = false,
    showValueText = true,
    showStageBadge = true,
    valueFont = "__default",
    stageFont = "__default",
    valueFontSize = 20,
    stageFontSize = 12,
    valueFontOutline = "default",
    stageFontOutline = "default",
    scale = 1,
    ringOffsetX = 0,
    ringOffsetY = 0,
    barOffsetX = 0,
    barOffsetY = -10,
    textOffsetX = 0,
    textOffsetY = -6,
    playPhaseChangeSound = false,
    phaseChangeSound = "TwichUI Prey",
    barTexture = "Blizzard",
    autoWatchPreyQuest = false,
    autoSuperTrackPreyQuest = false,
    autoTurnInPreyQuest = false,
    autoPurchaseRandomHunt = false,
    randomHuntDifficulty = "normal",
    remnantThreshold = 0,
    autoSelectHuntReward = false,
    preferredHuntReward = "remnant",
    fallbackHuntReward = "gold",
}

local function GetGlobalBarTexture()
    local theme = T:GetModule("Theme", true)
    return (theme and theme:Get("statusBarTexture")) or DEFAULTS.barTexture
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

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("PreyTweaks")
end

function Options:GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if not profile.preyTweaks then
        profile.preyTweaks = {}
    end

    return profile.preyTweaks
end

function Options:RefreshModule()
    local module = GetModule()
    if module and module:IsEnabled() and module.RefreshNow then
        module:RefreshNow("options")
    end
end

function Options:GetEnabled()
    return self:GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    local db = self:GetDB()
    db.enabled = value == true

    if value then
        GetModule():Enable()
    else
        GetModule():Disable()
    end
end

function Options:GetDisplayMode()
    local value = self:GetDB().displayMode
    if value == "bar" or value == "text" then
        return value
    end

    return DEFAULTS.displayMode
end

function Options:SetDisplayMode(info, value)
    local db = self:GetDB()
    if value ~= "bar" and value ~= "text" then
        value = "ring"
    end

    db.displayMode = value
    self:RefreshModule()
end

function Options:GetRingBackgroundStyle()
    local value = self:GetDB().ringBackgroundStyle
    if value == "none" or value == "faint" then
        return value
    end

    return DEFAULTS.ringBackgroundStyle
end

function Options:SetRingBackgroundStyle(info, value)
    local db = self:GetDB()
    if value ~= "none" and value ~= "faint" then
        value = "full"
    end

    db.ringBackgroundStyle = value
    self:RefreshModule()
end

function Options:GetHideBlizzardWidget()
    local value = self:GetDB().hideBlizzardWidget
    if value == nil then
        return DEFAULTS.hideBlizzardWidget
    end

    return value == true
end

function Options:SetHideBlizzardWidget(info, value)
    self:GetDB().hideBlizzardWidget = value == true
    self:RefreshModule()
end

function Options:GetShowValueText()
    local value = self:GetDB().showValueText
    if value == nil then
        return DEFAULTS.showValueText
    end

    return value == true
end

function Options:SetShowValueText(info, value)
    self:GetDB().showValueText = value == true
    self:RefreshModule()
end

function Options:GetShowStageBadge()
    local value = self:GetDB().showStageBadge
    if value == nil then
        return DEFAULTS.showStageBadge
    end

    return value == true
end

function Options:SetShowStageBadge(info, value)
    self:GetDB().showStageBadge = value == true
    self:RefreshModule()
end

function Options:GetValueFont()
    return self:GetDB().valueFont or DEFAULTS.valueFont
end

function Options:SetValueFont(info, value)
    self:GetDB().valueFont = value or DEFAULTS.valueFont
    self:RefreshModule()
end

function Options:GetStageFont()
    return self:GetDB().stageFont or DEFAULTS.stageFont
end

function Options:SetStageFont(info, value)
    self:GetDB().stageFont = value or DEFAULTS.stageFont
    self:RefreshModule()
end

function Options:GetValueFontSize()
    return ClampNumber(self:GetDB().valueFontSize, 8, 32, DEFAULTS.valueFontSize)
end

function Options:SetValueFontSize(info, value)
    self:GetDB().valueFontSize = math.floor(ClampNumber(value, 8, 32, DEFAULTS.valueFontSize) + 0.5)
    self:RefreshModule()
end

function Options:GetStageFontSize()
    return ClampNumber(self:GetDB().stageFontSize, 8, 32, DEFAULTS.stageFontSize)
end

function Options:SetStageFontSize(info, value)
    self:GetDB().stageFontSize = math.floor(ClampNumber(value, 8, 32, DEFAULTS.stageFontSize) + 0.5)
    self:RefreshModule()
end

function Options:GetValueFontOutline()
    local value = self:GetDB().valueFontOutline
    if value == "none" or value == "outline" or value == "thick" then
        return value
    end

    return DEFAULTS.valueFontOutline
end

function Options:SetValueFontOutline(info, value)
    self:GetDB().valueFontOutline = value or DEFAULTS.valueFontOutline
    self:RefreshModule()
end

function Options:GetStageFontOutline()
    local value = self:GetDB().stageFontOutline
    if value == "none" or value == "outline" or value == "thick" then
        return value
    end

    return DEFAULTS.stageFontOutline
end

function Options:SetStageFontOutline(info, value)
    self:GetDB().stageFontOutline = value or DEFAULTS.stageFontOutline
    self:RefreshModule()
end

function Options:GetScale()
    local value = self:GetDB().scale
    return ClampNumber(value, 0.5, 2, DEFAULTS.scale)
end

function Options:SetScale(info, value)
    self:GetDB().scale = ClampNumber(value, 0.5, 2, DEFAULTS.scale)
    self:RefreshModule()
end

function Options:GetOffset(axis, mode)
    local key = (mode or "ring") .. "Offset" .. axis
    return ClampNumber(self:GetDB()[key], -200, 200, DEFAULTS[key] or 0)
end

function Options:SetOffset(axis, mode, value)
    local key = (mode or "ring") .. "Offset" .. axis
    self:GetDB()[key] = math.floor(ClampNumber(value, -200, 200, DEFAULTS[key] or 0) + 0.5)
    self:RefreshModule()
end

function Options:GetRingOffsetX()
    return self:GetOffset("X", "ring")
end

function Options:SetRingOffsetX(info, value)
    self:SetOffset("X", "ring", value)
end

function Options:GetRingOffsetY()
    return self:GetOffset("Y", "ring")
end

function Options:SetRingOffsetY(info, value)
    self:SetOffset("Y", "ring", value)
end

function Options:GetBarOffsetX()
    return self:GetOffset("X", "bar")
end

function Options:SetBarOffsetX(info, value)
    self:SetOffset("X", "bar", value)
end

function Options:GetBarOffsetY()
    return self:GetOffset("Y", "bar")
end

function Options:SetBarOffsetY(info, value)
    self:SetOffset("Y", "bar", value)
end

function Options:GetTextOffsetX()
    return self:GetOffset("X", "text")
end

function Options:SetTextOffsetX(info, value)
    self:SetOffset("X", "text", value)
end

function Options:GetTextOffsetY()
    return self:GetOffset("Y", "text")
end

function Options:SetTextOffsetY(info, value)
    self:SetOffset("Y", "text", value)
end

function Options:GetPlayPhaseChangeSound()
    return self:GetDB().playPhaseChangeSound == true
end

function Options:SetPlayPhaseChangeSound(info, value)
    self:GetDB().playPhaseChangeSound = value == true
end

function Options:GetPhaseChangeSound()
    return self:GetDB().phaseChangeSound or DEFAULTS.phaseChangeSound
end

function Options:SetPhaseChangeSound(info, value)
    self:GetDB().phaseChangeSound = value or DEFAULTS.phaseChangeSound
end

function Options:GetBarTexture()
    return self:GetDB().barTexture or GetGlobalBarTexture()
end

function Options:SetBarTexture(info, value)
    self:GetDB().barTexture = value or DEFAULTS.barTexture
    self:RefreshModule()
end

function Options:GetAutoWatchPreyQuest()
    return self:GetDB().autoWatchPreyQuest == true
end

function Options:SetAutoWatchPreyQuest(info, value)
    self:GetDB().autoWatchPreyQuest = value == true
end

function Options:GetAutoSuperTrackPreyQuest()
    return self:GetDB().autoSuperTrackPreyQuest == true
end

function Options:SetAutoSuperTrackPreyQuest(info, value)
    self:GetDB().autoSuperTrackPreyQuest = value == true
end

function Options:GetAutoTurnInPreyQuest()
    return self:GetDB().autoTurnInPreyQuest == true
end

function Options:SetAutoTurnInPreyQuest(info, value)
    self:GetDB().autoTurnInPreyQuest = value == true
end

function Options:GetAutoPurchaseRandomHunt()
    return self:GetDB().autoPurchaseRandomHunt == true
end

function Options:SetAutoPurchaseRandomHunt(info, value)
    self:GetDB().autoPurchaseRandomHunt = value == true
end

function Options:GetRandomHuntDifficulty()
    local value = self:GetDB().randomHuntDifficulty
    if value == "hard" or value == "nightmare" then
        return value
    end

    return DEFAULTS.randomHuntDifficulty
end

function Options:SetRandomHuntDifficulty(info, value)
    if value ~= "hard" and value ~= "nightmare" then
        value = "normal"
    end

    self:GetDB().randomHuntDifficulty = value
end

function Options:GetRemnantThreshold()
    return ClampNumber(self:GetDB().remnantThreshold, 0, 2500, DEFAULTS.remnantThreshold)
end

function Options:SetRemnantThreshold(info, value)
    self:GetDB().remnantThreshold = math.floor(ClampNumber(value, 0, 2500, DEFAULTS.remnantThreshold) + 0.5)
end

function Options:GetAutoSelectHuntReward()
    return self:GetDB().autoSelectHuntReward == true
end

function Options:SetAutoSelectHuntReward(info, value)
    self:GetDB().autoSelectHuntReward = value == true
end

function Options:GetPreferredHuntReward()
    local value = self:GetDB().preferredHuntReward
    if value == "dawncrest" or value == "gold" or value == "marl" then
        return value
    end

    return DEFAULTS.preferredHuntReward
end

function Options:SetPreferredHuntReward(info, value)
    self:GetDB().preferredHuntReward = value or DEFAULTS.preferredHuntReward
end

function Options:GetFallbackHuntReward()
    local value = self:GetDB().fallbackHuntReward
    if value == "dawncrest" or value == "remnant" or value == "marl" then
        return value
    end

    return DEFAULTS.fallbackHuntReward
end

function Options:SetFallbackHuntReward(info, value)
    self:GetDB().fallbackHuntReward = value or DEFAULTS.fallbackHuntReward
end

function Options:TestPhaseChangeSound()
    local module = GetModule()
    if module and module.PlayConfiguredSound then
        module:PlayConfiguredSound(self:GetPhaseChangeSound())
    end
end

function Options:TestRingCold()
    local module = GetModule()
    if module and module.ShowTestSnapshot then
        module:ShowTestSnapshot(0, 0)
    end
end

function Options:TestRingWarm()
    local module = GetModule()
    if module and module.ShowTestSnapshot then
        module:ShowTestSnapshot(1, 0.34)
    end
end

function Options:TestRingHot()
    local module = GetModule()
    if module and module.ShowTestSnapshot then
        module:ShowTestSnapshot(2, 0.67)
    end
end

function Options:TestRingFinal()
    local module = GetModule()
    if module and module.ShowTestSnapshot then
        module:ShowTestSnapshot(3, 1)
    end
end

function Options:ClearRingTest()
    local module = GetModule()
    if module and module.ClearTestSnapshot then
        module:ClearTestSnapshot()
    end
end
