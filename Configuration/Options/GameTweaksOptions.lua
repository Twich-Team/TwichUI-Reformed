---@diagnostic disable: inject-field, undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local ConfigurationOptions = ConfigurationModule.Options --[[@as any]]

---@class GameTweaksConfigurationOptions
local Options = ConfigurationOptions.GameTweaks or {}
ConfigurationOptions.GameTweaks = Options

local DEFAULT_DB = {
    enabled = false,
    automation = {
        autoAcceptSummon = false,
        summonDelay = 10,
        autoAcceptRes = false,
        resNoCombat = true,
        resNoAfterlife = false,
        autoReleasePvP = false,
        releaseDelayMs = 0,
        excludeAlterac = false,
        excludeWintergrasp = false,
        excludeTolBarad = false,
        excludeAshran = false,
        autoSellJunk = false,
        autoSellShowSummary = true,
        autoSellExcludeGreyGear = false,
        autoSellExcludeList = "",
        autoRepairGear = false,
        autoRepairGuildFunds = true,
        autoRepairShowSummary = true,
    },
    social = {
        noDuelRequests = false,
        noPetDuels = false,
        noPartyInvites = false,
        noRequestedInvites = false,
        noFriendRequests = false,
        noSharedQuests = false,
        acceptPartyFriends = false,
        syncFromFriends = false,
        autoConfirmRole = false,
        inviteFromWhisper = false,
        inviteKeyword = "inv",
        inviteFriendsOnly = true,
        friendlyGuild = false,
        friendlyCommunities = false,
    },
    frames = {
        manageWidgetTop = false,
        widgetTop = { point = "TOP", relativePoint = "TOP", x = 0, y = -15, scale = 1 },
        manageControl = false,
        control = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, scale = 1 },
        classColFrames = false,
        classColPlayer = true,
        classColTarget = true,
        noAlerts = false,
        hideBodyguard = false,
        hideTalkingFrame = false,
        hideCleanupBtns = false,
        hideBossBanner = false,
        hideEventToasts = false,
        noClassBar = false,
        noRestedSleep = false,
    },
    system = {
        noScreenGlow = false,
        noScreenEffects = false,
        setWeatherDensity = false,
        weatherLevel = 3,
        maxCameraZoom = false,
        noRestedEmotes = false,
        keepAudioSynced = false,
        mutePingSounds = false,
        muteGameSounds = false,
        muteGameSoundIDs = "",
        muteToySounds = false,
        muteToySoundIDs = "",
        muteMountSounds = false,
        muteMountSoundIDs = "",
        presetMounts = {
            bikes = false,
            brooms = false,
            calamitousCarrion = false,
            dragonriding = false,
            gyrocopters = false,
            rabbits = false,
            rockets = false,
            travelers = false,
        },
        presetToys = {
            anima = false,
            balls = false,
            harp = false,
            meerah = false,
        },
        muteCustomSounds = false,
        muteCustomSoundIDs = "",
        noBagAutomation = false,
        noPetAutomation = false,
        noRaidRestrictions = false,
        noConfirmLoot = false,
        fasterMovieSkip = false,
        easyItemDestroy = false,
        noTransforms = false,
        transformSpellIDs = "",
        addOptNoCombatBox = false,
        addOptNoMountBox = false,
    },
    text = {
        hideErrorMessages = false,
        showCriticalErrors = true,
    },
}

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

local function GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    profile.gameTweaks = profile.gameTweaks or {}
    MergeDefaults(profile.gameTweaks, DEFAULT_DB)
    return profile.gameTweaks
end

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("GameTweaks")
end

local function ResolvePath(path, create)
    local node = GetDB()
    for index = 1, #path - 1 do
        local key = path[index]
        if type(node[key]) ~= "table" then
            if not create then
                return nil, path[#path]
            end
            node[key] = {}
        end
        node = node[key]
    end
    return node, path[#path]
end

function Options:GetEnabled()
    return GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    local db = GetDB()
    db.enabled = value == true
    local module = GetModule()
    if db.enabled then
        module:Enable()
    else
        module:Disable()
    end
end

function Options:GetValue(path, defaultValue)
    local node, key = ResolvePath(path, false)
    if not node then
        return defaultValue
    end
    local value = node[key]
    if value == nil then
        return defaultValue
    end
    return value
end

function Options:SetValue(path, value)
    local node, key = ResolvePath(path, true)
    node[key] = value
    local module = GetModule()
    if module and module.RefreshSettings then
        module:RefreshSettings()
    end
end

function Options:ResetWidgetTopPosition()
    local db = GetDB()
    db.frames.widgetTop = { point = "TOP", relativePoint = "TOP", x = 0, y = -15, scale = 1 }
    local module = GetModule()
    if module and module.ApplyFrameTweaks then
        module:ApplyFrameTweaks()
    end
end

function Options:ResetControlPosition()
    local db = GetDB()
    db.frames.control = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, scale = 1 }
    local module = GetModule()
    if module and module.ApplyFrameTweaks then
        module:ApplyFrameTweaks()
    end
end
