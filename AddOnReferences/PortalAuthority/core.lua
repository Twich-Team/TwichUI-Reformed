-- Portal Authority
-- Core event handling, settings migration, and chat announcement logic.

local ADDON_NAME = ...

PortalAuthority = PortalAuthority or {}
PortalAuthorityDiagDump = nil

local PA_SETTINGS_WINDOW_DEV_GATE_ENABLED = false
local PA_SETTINGS_WINDOW_PUBLIC_GATE_ENABLED = true
local PA_DIAG_GATE_ENABLED = false

local PA_IsSecretValue
local PA_NormalizeSafeString
local PA_SafeStringsEqual
local PA_SafeUnitGUID

PortalAuthority.defaults = {
    announceEnabled = true,
    announcementText = "Porting to [destination] - click my portal!",
    portalsEnabled = true,
    portalsText = "Porting to [destination] - click my portal!",
    teleportsEnabled = true,
    teleportsText = "Teleporting to [destination].",
    mplusEnabled = true,
    mplusText = "Taking M+ teleport to [destination].",
    warlockSummoningEnabled = true,
    warlockSummoningText = "Summoning stone is up - please click.",
    summonRequestsEnabled = true,
    summonRequestSoundChannel = "Master",
    summonRequestSound = "Overclock: Pause",
    summonStoneRequestsEnabled = true,
    summonStoneRequestSoundChannel = "Master",
    summonStoneRequestSound = "Overclock: OOT Press Start",
    keystoneHelperEnabled = true,
    keystoneAutoSlotEnabled = false,
    keystoneAutoStartEnabled = false,
    pullCommandEnabled = true,
    pullTimerMethod = 1,
    pullShortSeconds = 5,
    pullLongSeconds = 10,
    releaseGateEnabled = false,
    releaseGateModifier = "SHIFT",
    releaseGateHoldSeconds = 1.0,
    keystoneTooltipDungeonNameMode = "NO_CHANGES",
    keystoneTooltipRemoveKeystonePrefix = false,
    keystoneTooltipLevelMode = "NO_CHANGES",
    keystoneTooltipLevelAddToName = false,
    keystoneTooltipResilientMode = "NO_CHANGES",
    keystoneTooltipSoulboundMode = "NO_CHANGES",
    keystoneTooltipUniqueMode = "NO_CHANGES",
    keystoneTooltipAffixesMode = "NO_CHANGES",
    keystoneTooltipAffixesColor = { r = 1, g = 0.82, b = 0, a = 1 },
    keystoneTooltipDurationMode = "NO_CHANGES",
    keystoneTooltipRPQuoteMode = "NO_CHANGES",
    deathAlertTankEnabled = true,
    deathAlertTankSound = "Overclock: MGS",
    deathAlertTankOnScreen = true,
    deathAlertHealerEnabled = false,
    deathAlertHealerSound = "",
    deathAlertHealerOnScreen = false,
    deathAlertDpsEnabled = false,
    deathAlertDpsSound = "",
    deathAlertDpsOnScreen = false,
    deathAlertSelfEnabled = false,
    deathAlertSelfSound = "",
    deathAlertSelfOnScreen = false,
    deathAlertMessageTemplate = "[role] Died: [name]",
    deathAlertLocked = true,
    deathAlertX = 0,
    deathAlertY = 0,
    deathAlertFontPath = "",
    deathAlertFontSize = 36,
    deathAlertSoundChannel = "Master",
    deathAlertShowRoleIcon = true,
    deathAlertAntiSpamWipeEnabled = true,
    combatAlertsEnabled = true,

    dockEnabled = true,
    dockOrientation = "VERTICAL",
    dockX = 0,
    dockY = 0,
    dockLocked = true,
    dockHideInMajorCity = false,
    dockHideInDungeon = false,
    dockHideInCombat = false,
    dockGizmoMode = false,
    dockIconWidth = 32,
    dockIconHeight = 32,
    dockHideDungeonName = false,
    dockUseShortNames = true,
    dockVerticalTextSide = "LEFT",
    dockHorizontalTextPosition = "ABOVE",
    dockTextIconSpacing = 8,
    dockFontSize = 12,
    dockFontPath = "",
    dockFontColor = { r = 1, g = 0.82, b = 0, a = 1 },
    dockTextOutline = "OUTLINE",
    dockTextShadow = true,
    dockShadowOffsetX = 1,
    dockShadowOffsetY = -1,
    dockRowSpacing = 3,
    dockLayoutMode = "ADAPTIVE_GRID",
    dockWrapAfter = 4,
    dockIconSize = 36,
    dockSpacingX = 6,
    dockSpacingY = 6,
    dockPadding = 6,
    dockGrowthX = "RIGHT",
    dockGrowthY = "DOWN",
    dockAnchorPoint = "CENTER",
    dockCenterAlignment = true,
    dockPreferAxis = "AUTO",
    dockCompactMode = false,
    dockTestMode = false,
    dockSortMode = "ROW_ORDER",
    dockAnimateReflow = false,
    dockAnimateDuration = 0.15,
    dockBackdropEnabled = false,
    dockInactiveAlpha = 0.5,
    dockHoverGlow = true,
    dockSimpleLayoutMode = "GRID",
    dockIconsPerLine = 4,
    dockIconSpacing = 6,
    dockDensity = 50,
    dockTextDirection = "BOTTOM",
    dockTextAlign = "CENTER",
    dockLabelAlignMode = "CENTER",
    dockLabelMode = "OUTSIDE",
    dockLabelModePersist = "OUTSIDE",
    dockLabelSide = "BOTTOM",
    dockLabelSidePersist = "BOTTOM",
    dockLabelSideOutsidePersist = "BOTTOM",
    dockTextOffset = 2,
    dockHoverGlowAlpha = 0.2,
    dockHoverGlowSize = 0,

    modules = {
        brezTimer = {
            enabled = true,
            x = 0,
            y = 0,
            textFormat = "{mm}:{ss}",
            timeFormatMode = "mmss",
            font = "",
            fontSize = 14,
            color = { r = 1, g = 1, b = 1, a = 1 },
            label1Text = "Battle Rez",
            label2Text = "Next In",
            label1Font = "",
            label2Font = "",
            valueFont = "",
            label1FontSize = 14,
            label2FontSize = 14,
            valueFontSize = 14,
            label1Color = { r = 1, g = 1, b = 1, a = 1 },
            label2Color = { r = 1, g = 1, b = 1, a = 1 },
            valueColor = { r = 1, g = 1, b = 1, a = 1 },
            value1Color = { r = 1, g = 1, b = 1, a = 1 },
            value2Color = { r = 1, g = 1, b = 1, a = 1 },
        },
    },
}

PortalAuthority._buildConfig = {
    gates = {
        uiSurface = false,
        staticBaseline = false,
        settingsBaseline = false,
        settingsEagerBuild = false,
        settingsDirectBuild = false,
        settingsWindowDev = PA_SETTINGS_WINDOW_DEV_GATE_ENABLED,
        settingsWindowPublic = PA_SETTINGS_WINDOW_PUBLIC_GATE_ENABLED,
        diag = PA_DIAG_GATE_ENABLED,
        onboardingD1Dev = false, -- Internal onboarding branch only; keep false in public builds.
        onboardingD3Dev = false, -- Internal onboarding branch only; keep false in public builds.
        onboardingD4Dev = false, -- Internal onboarding branch only; keep false in public builds.
        onboardingD3Public = true,
        onboardingD4Public = true,
        onboardingQualifyingUpgradePublic = true,
    },
    release = {
        premiumOnboardingResetEpoch = "PA_2_0_0_BASELINE",
        premiumOnboardingVersion = "PA_2_0_0_PREMIUM_V1",
        qualifyingUpgradeOnboardingVersion = "PA_2_1_1_QUALIFYING_UPGRADE_V1",
        settingsWindowAnnouncementVersion = "2.1.2",
        premiumAuthoredFontPath = "Fonts\\FRIZQT__.TTF",
        premiumAuthoredFontName = "Overclock: Friz",
        overclockWarcraftLogsUrl = "https://classic.warcraftlogs.com/guild/us/faerlina/overclock",
    },
    settings = {
        keystoneBootstrapStates = {
            scheduled = true,
            ran = true,
            suppressed = true,
            unknown = true,
        },
        bootstrapActiveStates = {
            none = true,
            root = true,
            announcements = true,
            dock = true,
            timers = true,
            interrupt = true,
            combat = true,
            profiles = true,
        },
    },
}

function PA_IsUiSurfaceGateEnabled()
    return PortalAuthority._buildConfig.gates.uiSurface == true
end

function PortalAuthority:IsUiSurfaceGateEnabled()
    return PA_IsUiSurfaceGateEnabled()
end

function PA_IsStaticBaselineGateEnabled()
    return PortalAuthority._buildConfig.gates.staticBaseline == true
end

function PortalAuthority:IsStaticBaselineGateEnabled()
    return PA_IsStaticBaselineGateEnabled()
end

function PA_IsSettingsBaselineGateEnabled()
    return PortalAuthority._buildConfig.gates.settingsBaseline == true
end

function PortalAuthority:IsSettingsBaselineGateEnabled()
    return PA_IsSettingsBaselineGateEnabled()
end

function PA_IsSettingsEagerBuildGateEnabled()
    if PortalAuthority._buildConfig.gates.settingsEagerBuild == true then
        return true
    end
    return PortalAuthority
        and PortalAuthority.IsSettingsWindowHostEnabled
        and PortalAuthority:IsSettingsWindowHostEnabled()
        or false
end

function PortalAuthority:IsSettingsEagerBuildGateEnabled()
    return PA_IsSettingsEagerBuildGateEnabled()
end

function PA_IsSettingsDirectBuildGateEnabled()
    return PortalAuthority._buildConfig.gates.settingsDirectBuild == true
end

function PortalAuthority:IsSettingsDirectBuildGateEnabled()
    return PA_IsSettingsDirectBuildGateEnabled()
end

function PA_IsSettingsWindowDevGateEnabled()
    return PortalAuthority._buildConfig.gates.settingsWindowDev == true
end

function PortalAuthority:IsSettingsWindowDevGateEnabled()
    return PA_IsSettingsWindowDevGateEnabled()
end

function PA_IsSettingsWindowPublicGateEnabled()
    return PortalAuthority._buildConfig.gates.settingsWindowPublic == true
end

function PortalAuthority:IsSettingsWindowPublicGateEnabled()
    return PA_IsSettingsWindowPublicGateEnabled()
end

function PA_IsSettingsWindowHostEnabled()
    return PA_IsSettingsWindowDevGateEnabled() or PA_IsSettingsWindowPublicGateEnabled()
end

function PortalAuthority:IsSettingsWindowHostEnabled()
    return PA_IsSettingsWindowHostEnabled()
end

BINDING_HEADER_PORTAL_AUTHORITY = "Portal Authority"
BINDING_NAME_PORTAL_AUTHORITY_OPEN_SETTINGS = "Open Settings"

function PA_Binding_ToggleSettingsWindow()
    if not PortalAuthority then
        return
    end

    if PortalAuthority.IsSettingsWindowOpen and PortalAuthority:IsSettingsWindowOpen() then
        if PortalAuthority.CloseSettingsWindow then
            PortalAuthority:CloseSettingsWindow()
        end
        return
    end

    if PortalAuthority.HandleSlashRootEntry then
        PortalAuthority:HandleSlashRootEntry()
    end
end

function PA_IsDiagGateEnabled()
    return PortalAuthority._buildConfig.gates.diag == true
end

function PortalAuthority:IsDiagDumpEnabled()
    return PA_IsDiagGateEnabled()
end

function PA_IsOnboardingD1DevGateEnabled()
    return PortalAuthority._buildConfig.gates.onboardingD1Dev == true
end

function PortalAuthority:IsOnboardingD1DevGateEnabled()
    return PA_IsOnboardingD1DevGateEnabled()
end

function PA_IsOnboardingD3DevGateEnabled()
    return PortalAuthority._buildConfig.gates.onboardingD3Dev == true
end

function PortalAuthority:IsOnboardingD3DevGateEnabled()
    return PA_IsOnboardingD3DevGateEnabled()
end

function PA_IsOnboardingD4DevGateEnabled()
    return PA_IsOnboardingD3DevGateEnabled() and PortalAuthority._buildConfig.gates.onboardingD4Dev == true
end

function PortalAuthority:IsOnboardingD4DevGateEnabled()
    return PA_IsOnboardingD4DevGateEnabled()
end

function PA_IsOnboardingD3PublicGateEnabled()
    return PortalAuthority._buildConfig.gates.onboardingD3Public == true
end

function PortalAuthority:IsOnboardingD3PublicGateEnabled()
    return PA_IsOnboardingD3PublicGateEnabled()
end

function PA_IsOnboardingD4PublicGateEnabled()
    return PA_IsOnboardingD3PublicGateEnabled() and PortalAuthority._buildConfig.gates.onboardingD4Public == true
end

function PortalAuthority:IsOnboardingD4PublicGateEnabled()
    return PA_IsOnboardingD4PublicGateEnabled()
end

function PA_IsOnboardingQualifyingUpgradePublicGateEnabled()
    return PortalAuthority._buildConfig.gates.onboardingQualifyingUpgradePublic == true
end

function PortalAuthority:IsOnboardingQualifyingUpgradePublicGateEnabled()
    return PA_IsOnboardingQualifyingUpgradePublicGateEnabled()
end

function PA_IsOnboardingD3Enabled()
    return PA_IsOnboardingD3DevGateEnabled() or PA_IsOnboardingD3PublicGateEnabled()
end

function PortalAuthority:IsOnboardingD3Enabled()
    return PA_IsOnboardingD3Enabled()
end

function PA_IsOnboardingD4Enabled()
    return PA_IsOnboardingD4DevGateEnabled() or PA_IsOnboardingD4PublicGateEnabled()
end

function PortalAuthority:IsOnboardingD4Enabled()
    return PA_IsOnboardingD4Enabled()
end

function PortalAuthority:IsCombatAlertsEnabled()
    local db = PortalAuthorityDB or self.defaults or {}
    return db.combatAlertsEnabled ~= false
end

function PortalAuthority:SetSettingsKeystoneBootstrapState(state)
    local states = PortalAuthority._buildConfig.settings.keystoneBootstrapStates
    local normalized = type(state) == "string" and states[state] and state or "unknown"
    local currentState = self and self._settingsKeystoneBootstrapState or nil
    local current = type(currentState) == "string" and states[currentState] and currentState or "unknown"

    if current == "ran" then
        return current
    end
    if current == "scheduled" and (normalized == "unknown" or normalized == "scheduled" or normalized == "suppressed") then
        return current
    end
    if current == "suppressed" and normalized ~= "ran" then
        return current
    end
    if normalized == "unknown" and self and self._settingsKeystoneBootstrapState ~= nil then
        return current
    end

    self._settingsKeystoneBootstrapState = normalized
    return normalized
end

function PortalAuthority:GetSettingsKeystoneBootstrapState()
    local state = self and self._settingsKeystoneBootstrapState or nil
    local states = PortalAuthority._buildConfig.settings.keystoneBootstrapStates
    if type(state) == "string" and states[state] then
        return state
    end
    return "unknown"
end

function PortalAuthority:SetSettingsBootstrapActive(state)
    local states = PortalAuthority._buildConfig.settings.bootstrapActiveStates
    local normalized = type(state) == "string" and states[state] and state or "none"
    self._settingsBootstrapActive = normalized
    return normalized
end

function PortalAuthority:GetSettingsBootstrapActive()
    local state = self and self._settingsBootstrapActive or nil
    local states = PortalAuthority._buildConfig.settings.bootstrapActiveStates
    if type(state) == "string" and states[state] then
        return state
    end
    return "none"
end

local SUMMON_SENDER_COOLDOWN_SECONDS = 15
local SUMMON_SOUND_GLOBAL_COOLDOWN_SECONDS = 5
local SUMMON_BURST_WINDOW_SECONDS = 10
local SUMMON_BURST_WINDOW_MAX = 3
local WARLOCK_SUMMON_ANNOUNCEMENT_SUPPRESSION_SECONDS = 2
local DEATH_ALERT_SELF_DUPLICATE_WINDOW_SECONDS = 0.5

local SUMMON_REQUEST_KEYWORD_TOKENS = {
    ["sum"] = true,
    ["summ"] = true,
    ["summon"] = true,
    ["summons"] = true,
    ["summoning"] = true,
}

local SUMMON_STONE_REQUEST_KEYWORD_TOKENS = {
    ["closet"] = true,
    ["stone"] = true,
}

local RITUAL_OF_SUMMONING_SPELL_ID = 698
local RITUAL_OF_SUMMONING_ICON_FALLBACK = 7439232

local BUILTIN_SUMMON_ALERT_SOUNDS = {
    { label = "None", value = "" },
    { label = "Alarm Clock", value = 567478 },
    { label = "Raid Warning", value = 567463 },
    { label = "Ready Check", value = 567482 },
    { label = "Tell Message", value = 3081 },
}

PortalAuthority.SpellMap = {
    -- Portals
    [446534] = { category = "portals", dest = "Dornogal" },
    [10059] = { category = "portals", dest = "Stormwind" },
    [11416] = { category = "portals", dest = "Ironforge" },
    [11419] = { category = "portals", dest = "Darnassus" },
    [32266] = { category = "portals", dest = "Exodar" },
    [49360] = { category = "portals", dest = "Theramore" },
    [53142] = { category = "portals", dest = "Dalaran (Northrend)" },
    [88346] = { category = "portals", dest = "Tol Barad" },
    [132620] = { category = "portals", dest = "Vale of Eternal Blossoms" },
    [224871] = { category = "portals", dest = "Dalaran (Broken Isles)" },
    [344597] = { category = "portals", dest = "Oribos" },
    [395289] = { category = "portals", dest = "Valdrakken" },

    -- Teleports
    [3561] = { category = "teleports", dest = "Stormwind" },
    [3562] = { category = "teleports", dest = "Ironforge" },
    [3565] = { category = "teleports", dest = "Darnassus" },
    [32271] = { category = "teleports", dest = "Exodar" },
    [49359] = { category = "teleports", dest = "Theramore" },
    [53140] = { category = "teleports", dest = "Dalaran (Northrend)" },
    [88344] = { category = "teleports", dest = "Tol Barad" },
    [132621] = { category = "teleports", dest = "Vale of Eternal Blossoms" },
    [224869] = { category = "teleports", dest = "Dalaran (Broken Isles)" },
    [344587] = { category = "teleports", dest = "Oribos" },
    [395277] = { category = "teleports", dest = "Valdrakken" },
    [446540] = { category = "teleports", dest = "Dornogal" },

    -- Warlock utility
    [698] = { category = "warlockSummoning", dest = "Summoning Stone" },
}

local function PA_AddSpellIfExists(spellID, category, destinationLabel)
    if C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) then
        PortalAuthority.SpellMap[spellID] = { category = category, dest = destinationLabel }
    end
end

local function PA_AddSpellMapping(spellID, category, destinationLabel, shortLabel, classFile, useItemID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return
    end
    local entry = {
        category = category,
        dest = destinationLabel,
    }
    if type(shortLabel) == "string" and shortLabel ~= "" then
        entry.short = shortLabel
    end
    if type(classFile) == "string" and classFile ~= "" then
        entry.class = classFile
    end
    if type(useItemID) == "number" and useItemID > 0 then
        entry.useItemID = math.floor(useItemID)
    end
    PortalAuthority.SpellMap[spellID] = entry
end

PA_AddSpellIfExists(33691, "portals", "Shattrath")
PA_AddSpellIfExists(176246, "portals", "Stormshield")
PA_AddSpellIfExists(281400, "portals", "Boralus")

PA_AddSpellIfExists(33690, "teleports", "Shattrath")
PA_AddSpellIfExists(176248, "teleports", "Stormshield")
PA_AddSpellIfExists(281403, "teleports", "Boralus")

-- Additional city portal/teleport mappings used by Announcements and Dock v2 slot picker.
PA_AddSpellMapping(120146, "portals", "Ancient Dalaran")
PA_AddSpellMapping(120145, "teleports", "Ancient Dalaran")
PA_AddSpellMapping(11417, "portals", "Orgrimmar")
PA_AddSpellMapping(3567, "teleports", "Orgrimmar")
PA_AddSpellMapping(11418, "portals", "Undercity")
PA_AddSpellMapping(3563, "teleports", "Undercity")
PA_AddSpellMapping(11420, "portals", "Thunder Bluff")
PA_AddSpellMapping(3566, "teleports", "Thunder Bluff")
PA_AddSpellMapping(32267, "portals", "Silvermoon (TBC)")
PA_AddSpellMapping(32272, "teleports", "Silvermoon")
PA_AddSpellMapping(49361, "portals", "Stonard")
PA_AddSpellMapping(49358, "teleports", "Stonard")
PA_AddSpellMapping(281402, "portals", "Dazar'alor")
PA_AddSpellMapping(281404, "teleports", "Dazar'alor")
PA_AddSpellMapping(176244, "portals", "Warspear")
PA_AddSpellMapping(176242, "teleports", "Warspear")

-- Additional non-mage travel spells that should be selectable for Dock/Announcements.
PA_AddSpellMapping(556, "teleports", "Astral Recall", nil, "SHAMAN")                       -- Astral Recall
PA_AddSpellMapping(50977, "teleports", "Acherus: The Ebon Hold", nil, "DEATHKNIGHT")      -- Death Gate
PA_AddSpellMapping(193753, "teleports", "Emerald Dreamway", nil, "DRUID")                  -- Dreamwalk
PA_AddSpellMapping(18960, "teleports", "Moonglade", nil, "DRUID")                          -- Teleport: Moonglade
PA_AddSpellMapping(126892, "teleports", "Peak of Serenity", nil, "MONK")                   -- Zen Pilgrimage
PA_AddSpellMapping(8690, "teleports", "Hearthstone", nil, "ANY", 6948)                     -- Hearthstone item-use routing

-- Extended Mythic+ / Path spell mappings used by the Destination table and dock labels.
local PA_MPLUS_PATH_MAPPINGS = {
    { 1254572, "Magister's Terrace", "MGT" },
    { 1254559, "Maisara Caverns", "MAIS" },
    { 1254563, "Nexus-Point Xenas", "NPX" },
    { 1254400, "Windrunner Spire", "WS" },
    { 445440, "Cinderbrew Meadery", "CBM" },
    { 445417, "Ara-Kara", "ARAK" },
    { 445416, "City of Threads", "COT" },
    { 445441, "Darkflame Cleft", "DFC" },
    { 1237215, "Eco-Dome", "ED" },
    { 1239155, "Manaforge Omega", "MFO" },
    { 1216786, "Floodgate", "FLOOD" },
    { 445444, "Priory of the Sacred Flame", "PSF" },
    { 445414, "Dawnbreaker", "DAWN" },
    { 445443, "Rookery", "ROOK" },
    { 445269, "Stonevault", "SV" },
    { 1226482, "Undermine", "UNDR" },
    { 432257, "Aberrus", "ABER" },
    { 393273, "Algeth'ar Academy", "AA" },
    { 432258, "Amirdrassil", "AMIR" },
    { 393267, "Brackenhide Hollow", "BH" },
    { 393283, "Halls of Infusion", "HOI" },
    { 393276, "Neltharus", "NELT" },
    { 393256, "Ruby Life Pools", "RLP" },
    { 424197, "Dawn of the Infinite", "DOTI" },
    { 393279, "Azure Vault", "AV" },
    { 393262, "Nokhud Offensive", "NO" },
    { 393222, "Uldaman: Legacy of Tyr", "ULD" },
    { 432254, "Vault of the Incarnates", "VOTI" },
    { 373190, "Castle Nathria", "CN" },
    { 354468, "De Other Side", "DOS" },
    { 354465, "Halls of Atonement", "HOA" },
    { 354463, "Plaguefall", "PF" },
    { 373191, "Sanctum of Domination", "SOD" },
    { 354469, "Sanguine Depths", "SD" },
    { 373192, "Sepulcher of the First Ones", "SOFO" },
    { 354466, "Spires of Ascension", "SOA" },
    { 367416, "Tazavesh", "TAZA" },
    { 354462, "Necrotic Wake", "NW" },
    { 354467, "Theater of Pain", "TOP" },
    { 424187, "Atal'Dazar", "AD" },
    { 410071, "Freehold", "FH" },
    { 464256, "Siege of Boralus", "SOB" },
    { 467555, "The MOTHERLODE!!", "ML" },
    { 410074, "Underrot", "UR" },
    { 424167, "Waycrest Manor", "WM" },
    { 424153, "Blackrook Hold", "BRH" },
    { 393766, "Court of Stars", "COS" },
    { 424163, "Darkheart Thicket", "DHT" },
    { 393764, "Halls of Valor", "HOV" },
    { 373262, "Karazhan (Legion)", "KARA" },
    { 410078, "Neltharion's Lair", "NL" },
    { 1254551, "Seat of the Triumvirate", "SEAT" },
    { 159897, "Auchindoun", "AUCH" },
    { 159895, "Bloodmaul Slag Mines", "BSM" },
    { 159900, "Grimrail Depot", "GD" },
    { 159896, "Iron Docks", "ID" },
    { 159899, "Shadowmoon Burial Grounds", "SBG" },
    { 159898, "Skyreach", "SR" },
    { 159901, "Everbloom", "EB" },
    { 159902, "UBRS (WOD)", "UBRS" },
    { 131225, "Gate of the Setting Sun", "GSS" },
    { 131222, "Mogu'shan Palace", "MSP" },
    { 131231, "Scarlet Halls", "SH" },
    { 131229, "Scarlet Monastery (MOP)", "SM" },
    { 131232, "Scholo (MOP)", "SCHO" },
    { 131206, "Shadow-Pan Monastery", "SPM" },
    { 131228, "Siege of Niuzao", "SNT" },
    { 131205, "Stormstout Brewery", "SB" },
    { 131204, "Temple of the Jade Serpent", "TJS" },
    { 445424, "Grim Batol", "GB" },
    { 410080, "Vortex Pinnacle", "VP" },
    { 424142, "Throne of Tides", "TOT" },
    { 1254555, "Pit of Saron", "POS" },
}
for _, entry in ipairs(PA_MPLUS_PATH_MAPPINGS) do
    PA_AddSpellMapping(entry[1], "mplus", entry[2], entry[3])
end

-- These entries remain category "mplus" for announcement/template routing,
-- but are displayed as "Raid" in Dock v2 destination selection.
local PA_MPLUS_RAID_DISPLAY_IDS = {
    [1226482] = true, -- Undermine
    [1239155] = true, -- Manaforge Omega
    [373192] = true,  -- Sepulcher of the First Ones
    [373191] = true,  -- Sanctum of Domination
    [373190] = true,  -- Castle Nathria
}
for spellID in pairs(PA_MPLUS_RAID_DISPLAY_IDS) do
    if PortalAuthority.SpellMap[spellID] then
        PortalAuthority.SpellMap[spellID].displayCategory = "raid"
    end
end

local VALID_OUTLINES = {
    [""] = true,
    ["OUTLINE"] = true,
    ["THICKOUTLINE"] = true,
}

local VALID_SOUND_CHANNELS = {
    Master = true,
    SFX = true,
    Music = true,
    Ambience = true,
    Dialog = true,
}

local BUILTIN_FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"
local PLAYER_LOGIN_MESSAGE = "— type /pa to open settings."
local DOCK_ENABLE_DEFAULTS_VERSION = "2.0.0"

local function PA_GetAddonVersionString()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local v = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
        if type(v) == "string" and v ~= "" then return v end
    end
    if GetAddOnMetadata then
        local v = GetAddOnMetadata(ADDON_NAME, "Version")
        if type(v) == "string" and v ~= "" then return v end
    end
    return "0.0.0"
end

function PortalAuthority:GetAnnouncementReleaseVersionString()
    return PortalAuthority._buildConfig.release.settingsWindowAnnouncementVersion
end

local function PA_ParseSemver(v)
    if type(v) ~= "string" then
        return 0, 0, 0
    end
    local major, minor, patch = v:match("^%s*v?(%d+)%.(%d+)%.(%d+)")
    if not major then
        major, minor = v:match("^%s*v?(%d+)%.(%d+)")
        patch = "0"
    end
    if not major then
        major = v:match("^%s*v?(%d+)")
        minor = "0"
        patch = "0"
    end
    return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
end

local function PA_CompareSemver(leftVersion, rightVersion)
    local lMaj, lMin, lPatch = PA_ParseSemver(leftVersion)
    local rMaj, rMin, rPatch = PA_ParseSemver(rightVersion)
    if lMaj ~= rMaj then
        return lMaj < rMaj and -1 or 1
    end
    if lMin ~= rMin then
        return lMin < rMin and -1 or 1
    end
    if lPatch ~= rPatch then
        return lPatch < rPatch and -1 or 1
    end
    return 0
end

local function trim(text)
    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, text)
        if ok and hasSecret then
            return ""
        end
    end
    if type(text) ~= "string" then
        return ""
    end
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function clampNumber(value, fallback, min, max)
    value = tonumber(value) or fallback
    if min and value < min then
        value = min
    end
    if max and value > max then
        value = max
    end
    return value
end

local function PA_Clamp(value, fallback, min, max)
    local n = tonumber(value)
    if n == nil then
        local ok, s = pcall(tostring, value)
        if ok then
            n = tonumber(s)
        end
    end
    value = n or fallback
    if min and value < min then value = min end
    if max and value > max then value = max end
    return value
end

local function PA_ToNumber(v, fallback)
    if type(v) == "number" then
        return v
    end
    local ok, s = pcall(tostring, v)
    if ok and s ~= nil then
        local n = tonumber(s)
        if n ~= nil then
            return n
        end
    end
    return fallback
end

local function PA_SafeBool(v)
    local ok, s = pcall(tostring, v)
    if not ok or s == nil then return false end
    local okb, b = pcall(string.byte, s, 1)
    if not okb or b == nil then return false end
    local nb = tonumber(tostring(b)) or 0
    return nb == 116
end

local PA_PERF_SCOPE_ORDER = {
    dock_onupdate = 1,
    dock_drag_motion = 2,
    dock_save_position = 3,
    timers_evaluate_visibility = 4,
    timers_tick = 5,
    interrupt_evaluate_visibility = 6,
    interrupt_update_display = 7,
    deathalerts_apply_settings = 8,
    deathalerts_unlocked_preview = 9,
    options_refresh_all = 10,
    profiles_refresh = 11,
    profiles_layout = 12,
    interrupt_periodic_inspect = 13,
    movehint_ticker = 14,
    modules_event_dispatch = 15,
    modules_event_unit_aura = 16,
    modules_event_unit_power_update = 17,
    modules_event_chat_msg_addon = 18,
    modules_event_other = 19,
    modules_event_init = 20,
    modules_event_evaluate_visibility = 21,
    modules_event_on_event = 22,
    core_event_dispatch = 23,
    core_event_chat = 24,
    core_event_group_roster_update = 25,
    core_event_unit_spellcast = 26,
    core_event_other = 27,
    onboarding_ticker = 28,
    keystone_buttons_poll = 29,
    release_gate_popup_onupdate = 30,
    dock_button_cooldown_onupdate = 31,
    dock_event_dispatch = 32,
    dock_event_spell_update_cooldown = 33,
    dock_event_spells_changed = 34,
    dock_event_zone = 35,
    dock_event_player_entering_world = 36,
    dock_event_other = 37,
    callback_class_unit_event = 38,
    callback_class_delayed_timer = 39,
    callback_class_ui_hook = 40,
    dock_rebuild = 41,
    dock_update_button_states = 42,
    dock_update_button_state = 43,
    dock_refresh_cooldown_ordering = 44,
    dock_label_settle_rebuild = 45,
    dock_refresh_visibility = 46,
    dock_frame_onshow = 47,
    dock_frame_onhide = 48,
    keystone_event_dispatch = 49,
    death_alerts_preview_tick = 50,
    death_alerts_drag_tick = 51,
}

local PA_PERF_STATE_ORDER = {
    closed = 1,
    settings = 2,
    unlock_global = 3,
    settings_unlock_global = 4,
    ["unlock_surface:dock"] = 5,
    ["settings_unlock_surface:dock"] = 6,
    ["unlock_surface:timers"] = 7,
    ["settings_unlock_surface:timers"] = 8,
    ["unlock_surface:interrupt"] = 9,
    ["settings_unlock_surface:interrupt"] = 10,
    ["unlock_surface:deathalerts"] = 11,
    ["settings_unlock_surface:deathalerts"] = 12,
}

local function PA_PerfGetRecordBucket(stats, stateLabel, scopeName)
    local stateStats = stats[stateLabel]
    if not stateStats then
        stateStats = {}
        stats[stateLabel] = stateStats
    end

    local bucket = stateStats[scopeName]
    if not bucket then
        bucket = {
            calls = 0,
            totalMs = 0,
            maxMs = 0,
        }
        stateStats[scopeName] = bucket
    end

    return bucket
end

local function PA_PerfStateRank(label)
    local direct = PA_PERF_STATE_ORDER[label]
    if direct then
        return direct
    end
    if type(label) ~= "string" then
        return 5000
    end
    if string.find(label, "^unlock_surface:") then
        return 1000
    end
    if string.find(label, "^settings_unlock_surface:") then
        return 1100
    end
    return 5000
end

local function PA_PerfScopeRank(scopeName)
    return PA_PERF_SCOPE_ORDER[scopeName] or 5000
end

function PortalAuthority:PerfIsEnabled()
    return self and self._perf and self._perf.enabled == true
end

function PortalAuthority:PerfReset()
    self._perf = self._perf or {}
    self._perf.stats = {}
    if debugprofilestart then
        pcall(debugprofilestart)
    end
end

function PortalAuthority:PerfGetUnlockedSurfaceNames()
    local db = PortalAuthorityDB or self.defaults or {}
    local surfaces = {}

    if db.dockLocked == false then
        surfaces[#surfaces + 1] = "dock"
    end
    if db.deathAlertLocked == false then
        surfaces[#surfaces + 1] = "deathalerts"
    end

    local modulesDb = db.modules or {}
    local timersDb = modulesDb.timers or {}
    if timersDb.locked == false then
        surfaces[#surfaces + 1] = "timers"
    end

    local interruptDb = modulesDb.interruptTracker or {}
    if interruptDb.locked == false then
        surfaces[#surfaces + 1] = "interrupt"
    end

    table.sort(surfaces)
    return surfaces
end

function PortalAuthority:PerfIsSettingsVisible()
    return self:IsAnySettingsHostVisible()
end

function PortalAuthority:PerfGetStateLabel(explicitState)
    if type(explicitState) == "string" and explicitState ~= "" then
        return explicitState
    end

    local prefix = self:PerfIsSettingsVisible() and "settings_" or ""
    local surfaces = self:PerfGetUnlockedSurfaceNames()
    local count = #surfaces

    if count <= 0 then
        if prefix ~= "" then
            return "settings"
        end
        return "closed"
    end

    if count >= 4 then
        return prefix .. "unlock_global"
    end

    return prefix .. "unlock_surface:" .. table.concat(surfaces, "+")
end

function PortalAuthority:PerfBegin(scopeName, explicitState)
    if not self:PerfIsEnabled() or type(scopeName) ~= "string" or scopeName == "" or not debugprofilestop then
        return nil, nil
    end
    return debugprofilestop(), self:PerfGetStateLabel(explicitState)
end

function PortalAuthority:PerfEnd(scopeName, startedAt, stateLabel)
    if not self:PerfIsEnabled() or startedAt == nil or type(scopeName) ~= "string" or scopeName == "" or not debugprofilestop then
        return
    end

    local elapsedMs = debugprofilestop() - startedAt
    if elapsedMs < 0 then
        elapsedMs = 0
    end

    local perf = self._perf or {}
    perf.stats = perf.stats or {}
    self._perf = perf

    stateLabel = self:PerfGetStateLabel(stateLabel)
    local bucket = PA_PerfGetRecordBucket(perf.stats, stateLabel, scopeName)
    bucket.calls = bucket.calls + 1
    bucket.totalMs = bucket.totalMs + elapsedMs
    if elapsedMs > bucket.maxMs then
        bucket.maxMs = elapsedMs
    end
end

local function PA_CpuDiagNormalizeVisibilityMode(mode)
    local normalized = tostring(mode or "NORMAL"):upper()
    if normalized == "HIDE" then
        return "HIDE"
    end
    return "NORMAL"
end

local function PA_CpuDiagBoolText(value)
    return value and "true" or "false"
end

local PA_CPUDIAG_CORE_DISPATCH_EVENTS = {
    "ADDON_LOADED",
    "PLAYER_LOGIN",
    "PLAYER_LOGOUT",
    "PLAYER_DEAD",
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_SUCCEEDED",
    "CHALLENGE_MODE_START",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "UNIT_DIED",
    "GROUP_ROSTER_UPDATE",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
}

local PA_CPUDIAG_MODULES_DISPATCH_EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED_NEW_AREA",
    "GROUP_ROSTER_UPDATE",
    "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "UNIT_SPELLCAST_SUCCEEDED",
    "CHAT_MSG_ADDON",
    "CHAT_MSG_ADDON_LOGGED",
    "UNIT_AURA",
    "UNIT_POWER_UPDATE",
    "PLAYER_DEAD",
    "PLAYER_ALIVE",
    "PLAYER_UNGHOST",
    "PLAYER_ROLES_ASSIGNED",
    "PLAYER_SPECIALIZATION_CHANGED",
    "UNIT_PET",
    "INSPECT_READY",
    "SPELLS_CHANGED",
    "ROLE_CHANGED_INFORM",
    "UNIT_DIED",
}

local PA_CPUDIAG_DOCK_DISPATCH_EVENTS = {
    "PLAYER_UPDATE_RESTING",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_REGEN_ENABLED",
    "PLAYER_REGEN_DISABLED",
    "SPELL_UPDATE_COOLDOWN",
    "SPELLS_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "ADDON_LOADED",
}

local PA_CPUDIAG_KEYSTONE_DISPATCH_EVENTS = {
    "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN",
    "START_TIMER",
}

local PA_CPUDIAG_UNIT_CALLBACK_EVENTS = {
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
}

local PA_CPUDIAG_DELAYED_TIMER_KEYS = {
    "interrupt_inspect_delay",
    "interrupt_inspect_step",
    "interrupt_init_hello",
    "interrupt_pew_queue",
    "interrupt_pew_hello",
    "interrupt_unitpet_retry_1",
    "interrupt_unitpet_retry_2",
    "interrupt_unitpet_retry_3",
    "interrupt_warlock_retry_1",
    "interrupt_warlock_retry_2",
    "onboarding_postshow_layout",
    "onboarding_retry",
    "keystone_buttons_refresh",
    "keystone_slot_retry",
    "keystone_autostart_arm_clear",
    "keystone_autostart_fallback",
    "keystone_autostart_startkey",
}

local PA_CPUDIAG_UI_HOOK_KEYS = {
    "dock_gizmo_frame_onshow",
    "dock_gizmo_frame_onhide",
    "dock_showuipanel",
    "dock_hideuipanel",
    "keystone_frame_onshow",
    "keystone_frame_onhide",
    "keystone_slot_onclick",
    "keystone_slot_onreceivedrag",
    "keystone_slot_onmouseup",
    "keystone_tooltip_postcall",
    "keystone_tooltip_gametooltip",
    "keystone_tooltip_itemref",
    "keystone_setitemref_after",
}

local PA_CPUDIAG_TRIGGER_KEYS = {
    "enter_world",
    "zone_new_area",
    "zone_local",
    "group_roster",
    "combat_enter",
    "combat_leave",
    "resting_update",
    "addon_chat",
    "spec_change",
    "challenge_start",
    "challenge_complete",
    "settings_open",
    "settings_closed",
}

local PA_CPUDIAG_TRIGGER_RECENT_CAPACITY = 12
local PA_CPUDIAG_LARGE_HEAP_DELTA_KB = 64
local PA_CPUDIAG_IDLE_WITNESS_CAPACITY = 256
local PA_CPUDIAG_IDLE_WITNESS_INTERVAL_SECONDS = 2.0
local PA_CPUDIAG_IDLE_WITNESS_HEARTBEAT_SECONDS = 60

local PA_CPUDIAG_IDLE_WITNESS_ENV_FIELDS = {
    "settings",
    "resting",
    "instance",
    "combat",
}

local PA_CPUDIAG_IDLE_WITNESS_UNLOCK_FIELDS = {
    "dockUnlocked",
    "timersUnlocked",
    "interruptUnlocked",
    "deathUnlocked",
}

local PA_CPUDIAG_IDLE_WITNESS_RUNTIME_FIELDS = {
    "dockShown",
    "dockOnUpdateArmed",
    "moveHintTicker",
    "onboardingTicker",
    "deathShown",
    "deathPreviewTicker",
    "deathDragTicker",
    "timersShown",
    "timersTicker",
    "interruptShown",
    "interruptTicker",
    "interruptInspectTicker",
    "keystoneHelperShown",
    "keystonePollArmed",
}

local PA_CPUDIAG_IDLE_WITNESS_DOCK_SURFACE_FIELDS = {
    "cooldownActive",
    "cooldownOnUpdate",
    "cooldownTextShown",
    "iconMove",
    "labelMove",
    "labelSettle",
    "labelAnimActive",
    "settleRunning",
}

local PA_CPUDIAG_IDLE_WITNESS_DELTA_SPECS = {
    { entryKey = "coreDispatchDelta", snapshotKey = "coreDispatchTotal" },
    { entryKey = "modulesDispatchDelta", snapshotKey = "modulesDispatchTotal" },
    { entryKey = "dockDispatchDelta", snapshotKey = "dockDispatchTotal" },
    { entryKey = "keystoneDispatchDelta", snapshotKey = "keystoneDispatchTotal" },
    { entryKey = "unitCallbacksDelta", snapshotKey = "unitCallbacksTotal" },
    { entryKey = "uiHooksDelta", snapshotKey = "uiHooksTotal" },
    { entryKey = "delayedTimersDelta", snapshotKey = "delayedTimersTotal" },
    { entryKey = "dockOnUpdateDelta", snapshotKey = "dockOnUpdateTotal" },
    { entryKey = "dockButtonCooldownDelta", snapshotKey = "dockButtonCooldownTotal" },
    { entryKey = "moveHintTickDelta", snapshotKey = "moveHintTickTotal" },
    { entryKey = "onboardingTickDelta", snapshotKey = "onboardingTickTotal" },
    { entryKey = "deathPreviewTickDelta", snapshotKey = "deathPreviewTickTotal" },
    { entryKey = "deathDragTickDelta", snapshotKey = "deathDragTickTotal" },
    { entryKey = "timersEvaluateDelta", snapshotKey = "timersEvaluateTotal" },
    { entryKey = "interruptEvaluateDelta", snapshotKey = "interruptEvaluateTotal" },
    { entryKey = "interruptUpdateDelta", snapshotKey = "interruptUpdateTotal" },
    { entryKey = "interruptInspectDelta", snapshotKey = "interruptInspectTotal" },
    { entryKey = "moduleChatDelta", snapshotKey = "moduleChatTotal" },
    { entryKey = "coreGroupRosterDelta", snapshotKey = "coreGroupRosterTotal" },
    { entryKey = "coreChatDelta", snapshotKey = "coreChatTotal" },
    { entryKey = "coreSpellcastDelta", snapshotKey = "coreSpellcastTotal" },
}

local function PA_CpuDiagNewFixedCounter(keys)
    local counter = { total = 0 }
    for i = 1, #keys do
        counter[keys[i]] = 0
    end
    return counter
end

local function PA_CpuDiagResetFixedCounter(counter, keys)
    counter.total = 0
    for i = 1, #keys do
        counter[keys[i]] = 0
    end
end

local function PA_CpuDiagNewRingBuffer(capacity)
    return {
        entries = {},
        size = 0,
        nextIndex = 1,
        capacity = tonumber(capacity) or PA_CPUDIAG_TRIGGER_RECENT_CAPACITY,
    }
end

local function PA_CpuDiagResetRingBuffer(buffer)
    if type(buffer) ~= "table" then
        return
    end
    buffer.entries = {}
    buffer.size = 0
    buffer.nextIndex = 1
    buffer.capacity = tonumber(buffer.capacity) or PA_CPUDIAG_TRIGGER_RECENT_CAPACITY
end

local function PA_CpuDiagPushRingBuffer(buffer, entry)
    if type(buffer) ~= "table" then
        return
    end

    local capacity = tonumber(buffer.capacity) or PA_CPUDIAG_TRIGGER_RECENT_CAPACITY
    buffer.capacity = capacity
    local nextIndex = tonumber(buffer.nextIndex) or 1
    if nextIndex < 1 or nextIndex > capacity then
        nextIndex = 1
    end

    buffer.entries[nextIndex] = entry
    nextIndex = nextIndex + 1
    if nextIndex > capacity then
        nextIndex = 1
    end
    buffer.nextIndex = nextIndex
    buffer.size = math.min(capacity, (tonumber(buffer.size) or 0) + 1)
end

local function PA_CpuDiagGetRingBufferEntriesNewestFirst(buffer)
    local entries = {}
    if type(buffer) ~= "table" then
        return entries
    end

    local size = tonumber(buffer.size) or 0
    local capacity = tonumber(buffer.capacity) or PA_CPUDIAG_TRIGGER_RECENT_CAPACITY
    if size <= 0 or type(buffer.entries) ~= "table" then
        return entries
    end

    local index = (tonumber(buffer.nextIndex) or 1) - 1
    if index < 1 then
        index = capacity
    end

    for _ = 1, math.min(size, capacity) do
        local entry = buffer.entries[index]
        if entry ~= nil then
            entries[#entries + 1] = entry
        end
        index = index - 1
        if index < 1 then
            index = capacity
        end
    end

    return entries
end

local function PA_CpuDiagGetRingBufferNewestEntry(buffer)
    if type(buffer) ~= "table" then
        return nil
    end
    if (tonumber(buffer.size) or 0) <= 0 or type(buffer.entries) ~= "table" then
        return nil
    end

    local capacity = tonumber(buffer.capacity) or PA_CPUDIAG_TRIGGER_RECENT_CAPACITY
    local index = (tonumber(buffer.nextIndex) or 1) - 1
    if index < 1 then
        index = capacity
    end
    return buffer.entries[index]
end

local function PA_CpuDiagSafeTime()
    if type(time) == "function" then
        local ok, value = pcall(time)
        if ok then
            return tonumber(value) or 0
        end
    end
    return 0
end

local function PA_CpuDiagGetCharacterStore()
    if type(PortalAuthorityCharacterDB) ~= "table" then
        PortalAuthorityCharacterDB = {}
    end
    return PortalAuthorityCharacterDB
end

local function PA_CpuDiagGetIdleWitnessStoreReadOnly()
    if PA_IsStaticBaselineGateEnabled() then
        return nil
    end
    local charStore = type(PortalAuthorityCharacterDB) == "table" and PortalAuthorityCharacterDB or nil
    local store = charStore and charStore.diagWitnessV1 or nil
    if type(store) ~= "table" or type(store.entries) ~= "table" then
        return nil
    end
    return store
end

local function PA_CpuDiagEnsureIdleWitnessStore()
    if PA_IsStaticBaselineGateEnabled() then
        return nil
    end
    local charStore = PA_CpuDiagGetCharacterStore()
    local store = type(charStore.diagWitnessV1) == "table" and charStore.diagWitnessV1 or nil
    if type(store) ~= "table" then
        store = {}
        charStore.diagWitnessV1 = store
    end

    store.version = 1
    store.capacity = tonumber(store.capacity) or PA_CPUDIAG_IDLE_WITNESS_CAPACITY
    if store.capacity < 1 then
        store.capacity = PA_CPUDIAG_IDLE_WITNESS_CAPACITY
    end
    store.size = math.max(0, math.min(store.capacity, tonumber(store.size) or 0))
    store.head = math.max(0, tonumber(store.head) or 0)
    if store.head > store.capacity then
        store.head = 0
    end
    store.sessionId = math.max(0, tonumber(store.sessionId) or 0)
    store.sessionStartedAt = tonumber(store.sessionStartedAt) or 0
    store.sessionStartedUptime = tonumber(store.sessionStartedUptime) or 0
    store.lastHeartbeatAt = tonumber(store.lastHeartbeatAt) or 0
    if type(store.entries) ~= "table" then
        store.entries = {}
    end
    if type(store.sessionMeta) ~= "table" then
        store.sessionMeta = {}
    end
    return store
end

local function PA_CpuDiagGetIdleWitnessSessionMeta(store, sessionId)
    if type(store) ~= "table" or type(store.sessionMeta) ~= "table" then
        return nil
    end
    sessionId = tonumber(sessionId) or 0
    if sessionId <= 0 then
        return nil
    end
    local meta = store.sessionMeta[sessionId]
    if type(meta) ~= "table" then
        return nil
    end
    return meta
end

local function PA_CpuDiagSetIdleWitnessSessionMeta(store, sessionId, meta)
    if type(store) ~= "table" or type(meta) ~= "table" then
        return
    end
    sessionId = tonumber(sessionId) or 0
    if sessionId <= 0 then
        return
    end
    if type(store.sessionMeta) ~= "table" then
        store.sessionMeta = {}
    end
    local existing = type(store.sessionMeta[sessionId]) == "table" and store.sessionMeta[sessionId] or {}
    if meta.uiSurfaceGate ~= nil then
        existing.uiSurfaceGate = meta.uiSurfaceGate == true
    end
    if meta.settingsBaselineGate ~= nil then
        existing.settingsBaselineGate = meta.settingsBaselineGate == true
    end
    if meta.settingsEagerBuildGate ~= nil then
        existing.settingsEagerBuildGate = meta.settingsEagerBuildGate == true
    end
    if meta.settingsDirectBuildGate ~= nil then
        existing.settingsDirectBuildGate = meta.settingsDirectBuildGate == true
    end
    store.sessionMeta[sessionId] = existing
end

local function PA_CpuDiagIdleWitnessPushEntry(store, entry)
    if type(store) ~= "table" or type(entry) ~= "table" then
        return
    end

    local capacity = tonumber(store.capacity) or PA_CPUDIAG_IDLE_WITNESS_CAPACITY
    if capacity < 1 then
        capacity = PA_CPUDIAG_IDLE_WITNESS_CAPACITY
        store.capacity = capacity
    end

    local head = tonumber(store.head) or 0
    head = head + 1
    if head > capacity or head < 1 then
        head = 1
    end

    store.entries[head] = entry
    store.head = head
    store.size = math.min(capacity, math.max(0, tonumber(store.size) or 0) + 1)
end

local function PA_CpuDiagIdleWitnessGetEntriesNewestFirst(store)
    local entries = {}
    if type(store) ~= "table" or type(store.entries) ~= "table" then
        return entries
    end

    local size = tonumber(store.size) or 0
    local capacity = tonumber(store.capacity) or PA_CPUDIAG_IDLE_WITNESS_CAPACITY
    local head = tonumber(store.head) or 0
    if head > capacity then
        head = 0
    end
    if size <= 0 or head <= 0 then
        return entries
    end

    local index = head
    for _ = 1, math.min(size, capacity) do
        local entry = store.entries[index]
        if entry ~= nil then
            entries[#entries + 1] = entry
        end
        index = index - 1
        if index < 1 then
            index = capacity
        end
    end

    return entries
end

local function PA_CpuDiagIdleWitnessGetLatestEntryForSession(store, sessionId)
    if type(sessionId) ~= "number" or sessionId <= 0 then
        return nil
    end

    local entries = PA_CpuDiagIdleWitnessGetEntriesNewestFirst(store)
    for i = 1, #entries do
        local entry = entries[i]
        if tonumber(entry and entry.sessionId) == sessionId then
            return entry
        end
    end
    return nil
end

local function PA_CpuDiagAddUniqueReason(reasons, token)
    if type(reasons) ~= "table" or type(token) ~= "string" or token == "" then
        return
    end
    for i = 1, #reasons do
        if reasons[i] == token then
            return
        end
    end
    reasons[#reasons + 1] = token
end

local function PA_CpuDiagSnapshotFieldChanged(previous, current, fields)
    for i = 1, #fields do
        local key = fields[i]
        if previous[key] ~= current[key] then
            return true
        end
    end
    return false
end

local function PA_CpuDiagPositiveDelta(currentValue, previousValue)
    local currentNumber = tonumber(currentValue) or 0
    local previousNumber = tonumber(previousValue) or 0
    if currentNumber <= previousNumber then
        return 0
    end
    return currentNumber - previousNumber
end

local function PA_CpuDiagReadLuaHeapKB()
    if type(collectgarbage) == "function" then
        local ok, value = pcall(collectgarbage, "count")
        if ok then
            return tonumber(value)
        end
    end
    if type(gcinfo) == "function" then
        local ok, value = pcall(gcinfo)
        if ok then
            return tonumber(value)
        end
    end
    return nil
end

local function PA_CpuDiagFormatKB(value)
    if type(value) ~= "number" then
        return "unknown"
    end
    return string.format("%.1f", value)
end

local function PA_CpuDiagFormatSignedKB(value)
    if type(value) ~= "number" then
        return "unknown"
    end
    return string.format("%+.1f", value)
end

local function PA_CpuDiagFormatPct(value)
    if type(value) ~= "number" then
        return "unknown"
    end
    return string.format("%.1f", value)
end

local function PA_CpuDiagGetAddOnCount()
    if type(GetNumAddOns) == "function" then
        local ok, value = pcall(GetNumAddOns)
        if ok then
            return tonumber(value)
        end
    end
    if C_AddOns and type(C_AddOns.GetNumAddOns) == "function" then
        local ok, value = pcall(C_AddOns.GetNumAddOns)
        if ok then
            return tonumber(value)
        end
    end
    return nil
end

local function PA_CpuDiagGetAddOnIdentity(index)
    if type(GetAddOnInfo) == "function" then
        local ok, name, title = pcall(GetAddOnInfo, index)
        if ok and type(name) == "string" and name ~= "" then
            if type(title) ~= "string" or title == "" then
                title = name
            end
            return name, title
        end
    end
    if C_AddOns and type(C_AddOns.GetAddOnInfo) == "function" then
        local ok, info = pcall(C_AddOns.GetAddOnInfo, index)
        if ok and type(info) == "table" then
            local name = info.name or info.Name
            local title = info.title or info.Title or info.displayName or info.DisplayName
            if type(name) == "string" and name ~= "" then
                if type(title) ~= "string" or title == "" then
                    title = name
                end
                return name, title
            end
        end
    end
    return nil, nil
end

local function PA_CpuDiagGetAddOnMemoryUsage(index, key)
    if type(GetAddOnMemoryUsage) == "function" then
        local ok, value = pcall(GetAddOnMemoryUsage, index)
        if ok and tonumber(value) ~= nil then
            return tonumber(value)
        end
        if type(key) == "string" and key ~= "" then
            ok, value = pcall(GetAddOnMemoryUsage, key)
            if ok and tonumber(value) ~= nil then
                return tonumber(value)
            end
        end
    end
    if C_AddOns and type(C_AddOns.GetAddOnMemoryUsage) == "function" then
        local ok, value = pcall(C_AddOns.GetAddOnMemoryUsage, index)
        if ok and tonumber(value) ~= nil then
            return tonumber(value)
        end
        if type(key) == "string" and key ~= "" then
            ok, value = pcall(C_AddOns.GetAddOnMemoryUsage, key)
            if ok and tonumber(value) ~= nil then
                return tonumber(value)
            end
        end
    end
    return nil
end

local function PA_CpuDiagReadAddonMemorySnapshot()
    if type(UpdateAddOnMemoryUsage) ~= "function" then
        return nil
    end

    local addOnCount = PA_CpuDiagGetAddOnCount()
    if type(addOnCount) ~= "number" or addOnCount < 0 then
        return nil
    end

    local okUpdate = pcall(UpdateAddOnMemoryUsage)
    if not okUpdate then
        return nil
    end

    local entries = {}
    local entriesByKey = {}
    local totalKB = 0

    for index = 1, addOnCount do
        local key, displayName = PA_CpuDiagGetAddOnIdentity(index)
        if type(key) ~= "string" or key == "" then
            return nil
        end

        local currentKB = PA_CpuDiagGetAddOnMemoryUsage(index, key)
        if type(currentKB) ~= "number" then
            return nil
        end

        local entry = {
            key = key,
            displayName = displayName or key,
            currentKB = currentKB,
        }
        entries[#entries + 1] = entry
        entriesByKey[key] = entry
        totalKB = totalKB + currentKB
    end

    return {
        entries = entries,
        entriesByKey = entriesByKey,
        totalKB = totalKB,
    }
end

local function PA_CpuDiagSeedAddonMemoryBaseline(state, snapshot)
    local baseline = state.addonMemory or {}
    baseline.seeded = false
    baseline.byKey = {}
    baseline.totalKB = nil
    baseline.paKB = nil

    if type(snapshot) ~= "table" or type(snapshot.entries) ~= "table" then
        state.addonMemory = baseline
        return false
    end

    baseline.seeded = true
    baseline.totalKB = tonumber(snapshot.totalKB)
    for i = 1, #snapshot.entries do
        local entry = snapshot.entries[i]
        if entry and type(entry.key) == "string" and entry.key ~= "" then
            baseline.byKey[entry.key] = tonumber(entry.currentKB) or 0
        end
    end
    baseline.paKB = baseline.byKey[ADDON_NAME]
    state.addonMemory = baseline
    return true
end

function PortalAuthority:CpuDiagEnsureState()
    if self._cpuDiag then
        return self._cpuDiag
    end

    local baselineLuaKB = PA_CpuDiagReadLuaHeapKB()
    self._cpuDiag = {
        startedAt = GetTime() or 0,
        suspendCounting = false,
        timers = {
            visibilityMode = "NORMAL",
            naturalVisible = nil,
            effectiveVisible = nil,
            frameShown = nil,
            evaluateVisibilityCalls = 0,
            tickCalls = 0,
        },
        interrupt = {
            visibilityMode = "NORMAL",
            naturalVisible = nil,
            effectiveVisible = nil,
            frameShown = nil,
            evaluateVisibilityCalls = 0,
            updateDisplayCalls = 0,
            periodicInspectCalls = 0,
        },
        moduleEvents = {
            unitAura = 0,
            unitPowerUpdate = 0,
            chatMsgAddon = 0,
            other = 0,
        },
        coreEvents = {
            chat = 0,
            groupRoster = 0,
            spellcast = 0,
            other = 0,
        },
        coreDispatch = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_CORE_DISPATCH_EVENTS),
        modulesDispatch = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_MODULES_DISPATCH_EVENTS),
        dockDispatch = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_DOCK_DISPATCH_EVENTS),
        keystoneDispatch = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_KEYSTONE_DISPATCH_EVENTS),
        unitCallbacks = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_UNIT_CALLBACK_EVENTS),
        delayedTimers = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_DELAYED_TIMER_KEYS),
        uiHooks = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_UI_HOOK_KEYS),
        triggerCounts = PA_CpuDiagNewFixedCounter(PA_CPUDIAG_TRIGGER_KEYS),
        triggerRecent = PA_CpuDiagNewRingBuffer(PA_CPUDIAG_TRIGGER_RECENT_CAPACITY),
        memory = {
            startLuaKB = baselineLuaKB,
            lastTrackedLuaKB = baselineLuaKB,
            trackedMinKB = baselineLuaKB,
            trackedMaxKB = baselineLuaKB,
            trackedSamples = 0,
            largeRiseEvents = 0,
            gcSuspectDrops = 0,
            largestRiseKB = 0,
            largestDropKB = 0,
        },
        addonMemory = {
            seeded = false,
            byKey = {},
            totalKB = nil,
            paKB = nil,
        },
        dockRuntime = {
            onUpdateTickCalls = 0,
            buttonCooldownTickCalls = 0,
        },
        keystone = {
            pollCalls = 0,
        },
        moveHint = {
            tickCalls = 0,
        },
        onboarding = {
            tickCalls = 0,
        },
        deathAlerts = {
            previewTickCalls = 0,
            dragTickCalls = 0,
        },
        releaseGate = {
            onUpdateCalls = 0,
        },
    }
    return self._cpuDiag
end

function PortalAuthority:CpuDiagRecordDispatcherEvent(dispatcherName, eventName)
    local state = self:CpuDiagEnsureState()
    if state.suspendCounting then
        return
    end

    local counter = nil
    if dispatcherName == "core" then
        counter = state.coreDispatch
    elseif dispatcherName == "modules" then
        counter = state.modulesDispatch
    elseif dispatcherName == "dock" then
        counter = state.dockDispatch
    elseif dispatcherName == "keystone" then
        counter = state.keystoneDispatch
    end

    if not counter then
        return
    end

    counter.total = (tonumber(counter.total) or 0) + 1
    if type(eventName) == "string" and counter[eventName] ~= nil then
        counter[eventName] = (tonumber(counter[eventName]) or 0) + 1
    end
end

function PortalAuthority:CpuDiagRecordUnitCallback(eventName)
    local state = self:CpuDiagEnsureState()
    if state.suspendCounting then
        return
    end

    local counter = state.unitCallbacks
    counter.total = (tonumber(counter.total) or 0) + 1
    if type(eventName) == "string" and counter[eventName] ~= nil then
        counter[eventName] = (tonumber(counter[eventName]) or 0) + 1
    end
end

function PortalAuthority:CpuDiagSuspendCounting(callback)
    local state = self:CpuDiagEnsureState()
    local prior = state.suspendCounting and true or false
    state.suspendCounting = true
    local ok, resultA, resultB, resultC = pcall(callback)
    state.suspendCounting = prior
    if not ok then
        error(resultA)
    end
    return resultA, resultB, resultC
end

function PortalAuthority:CpuDiagGetEntry(target)
    local state = self:CpuDiagEnsureState()
    if target == "timers" then
        return state.timers
    end
    if target == "interrupt" then
        return state.interrupt
    end
    return nil
end

function PortalAuthority:GetCpuDiagVisibilityMode(target)
    local entry = self:CpuDiagGetEntry(target)
    if not entry then
        return "NORMAL"
    end
    entry.visibilityMode = PA_CpuDiagNormalizeVisibilityMode(entry.visibilityMode)
    return entry.visibilityMode
end

function PortalAuthority:CpuDiagResolveVisibility(target, naturalVisible)
    local effectiveVisible = not not naturalVisible
    if effectiveVisible and self:GetCpuDiagVisibilityMode(target) == "HIDE" then
        effectiveVisible = false
    end
    return effectiveVisible
end

function PortalAuthority:CpuDiagRecordLiveVisibility(target, frame, naturalVisible, effectiveVisible)
    local entry = self:CpuDiagGetEntry(target)
    if not entry then
        return
    end

    entry.naturalVisible = not not naturalVisible
    entry.effectiveVisible = not not effectiveVisible
    if frame and frame.IsShown then
        entry.frameShown = frame:IsShown() and true or false
    else
        entry.frameShown = false
    end
end

function PortalAuthority:CpuDiagIsNaturallyVisible(target)
    local entry = self:CpuDiagGetEntry(target)
    return entry and entry.naturalVisible == true or false
end

function PortalAuthority:CpuDiagApplyVisibility(target, frame, naturalVisible)
    local effectiveVisible = self:CpuDiagResolveVisibility(target, naturalVisible)
    if frame then
        if effectiveVisible then
            frame:Show()
        else
            frame:Hide()
        end
    end
    self:CpuDiagRecordLiveVisibility(target, frame, naturalVisible, effectiveVisible)
    return effectiveVisible
end

function PortalAuthority:CpuDiagCount(scopeName, detailKey)
    local state = self:CpuDiagEnsureState()
    if state.suspendCounting then
        return
    end

    if scopeName == "timers_evaluate_visibility" then
        state.timers.evaluateVisibilityCalls = state.timers.evaluateVisibilityCalls + 1
        return
    end
    if scopeName == "timers_tick" then
        state.timers.tickCalls = state.timers.tickCalls + 1
        return
    end
    if scopeName == "interrupt_evaluate_visibility" then
        state.interrupt.evaluateVisibilityCalls = state.interrupt.evaluateVisibilityCalls + 1
        return
    end
    if scopeName == "interrupt_update_display" then
        state.interrupt.updateDisplayCalls = state.interrupt.updateDisplayCalls + 1
        return
    end
    if scopeName == "interrupt_periodic_inspect" then
        state.interrupt.periodicInspectCalls = state.interrupt.periodicInspectCalls + 1
        return
    end
    if scopeName == "movehint_ticker" then
        state.moveHint.tickCalls = state.moveHint.tickCalls + 1
        return
    end
    if scopeName == "onboarding_ticker" then
        state.onboarding.tickCalls = state.onboarding.tickCalls + 1
        return
    end
    if scopeName == "keystone_buttons_poll" then
        state.keystone.pollCalls = state.keystone.pollCalls + 1
        return
    end
    if scopeName == "dock_onupdate" then
        state.dockRuntime.onUpdateTickCalls = (tonumber(state.dockRuntime.onUpdateTickCalls) or 0) + 1
        return
    end
    if scopeName == "dock_button_cooldown_onupdate" then
        state.dockRuntime.buttonCooldownTickCalls = (tonumber(state.dockRuntime.buttonCooldownTickCalls) or 0) + 1
        return
    end
    if scopeName == "callback_class_ui_hook" then
        if type(detailKey) == "string" and state.uiHooks[detailKey] ~= nil then
            state.uiHooks.total = (tonumber(state.uiHooks.total) or 0) + 1
            state.uiHooks[detailKey] = (tonumber(state.uiHooks[detailKey]) or 0) + 1
        end
        return
    end
    if scopeName == "callback_class_delayed_timer" then
        state.delayedTimers.total = (tonumber(state.delayedTimers.total) or 0) + 1
        if type(detailKey) == "string" and state.delayedTimers[detailKey] ~= nil then
            state.delayedTimers[detailKey] = (tonumber(state.delayedTimers[detailKey]) or 0) + 1
        end
        return
    end
    if scopeName == "release_gate_popup_onupdate" then
        state.releaseGate.onUpdateCalls = state.releaseGate.onUpdateCalls + 1
        return
    end
    if scopeName == "death_alerts_preview_tick" then
        state.deathAlerts.previewTickCalls = state.deathAlerts.previewTickCalls + 1
        return
    end
    if scopeName == "death_alerts_drag_tick" then
        state.deathAlerts.dragTickCalls = state.deathAlerts.dragTickCalls + 1
    end
end

function PortalAuthority:CpuDiagRecordModuleEvent(eventScope)
    local state = self:CpuDiagEnsureState()
    if state.suspendCounting then
        return
    end

    if eventScope == "modules_event_unit_aura" then
        state.moduleEvents.unitAura = state.moduleEvents.unitAura + 1
        return
    end
    if eventScope == "modules_event_unit_power_update" then
        state.moduleEvents.unitPowerUpdate = state.moduleEvents.unitPowerUpdate + 1
        return
    end
    if eventScope == "modules_event_chat_msg_addon" then
        state.moduleEvents.chatMsgAddon = state.moduleEvents.chatMsgAddon + 1
        return
    end
    state.moduleEvents.other = state.moduleEvents.other + 1
end

function PortalAuthority:CpuDiagRecordCoreEvent(eventScope)
    local state = self:CpuDiagEnsureState()
    if state.suspendCounting then
        return
    end

    if eventScope == "core_event_chat" then
        state.coreEvents.chat = state.coreEvents.chat + 1
        return
    end
    if eventScope == "core_event_group_roster_update" then
        state.coreEvents.groupRoster = state.coreEvents.groupRoster + 1
        return
    end
    if eventScope == "core_event_unit_spellcast" then
        state.coreEvents.spellcast = state.coreEvents.spellcast + 1
        return
    end
    state.coreEvents.other = state.coreEvents.other + 1
end

function PortalAuthority:CpuDiagGetSettingsPanelFrame()
    return _G and (_G.SettingsPanel or _G.InterfaceOptionsFrame) or nil
end

function PortalAuthority:GetExistingSettingsWindowFrame()
    local frame = self and (self.settingsWindow or self._settingsWindow or self.SettingsWindow) or nil
    if frame and frame.IsObjectType and frame:IsObjectType("Frame") then
        return frame
    end

    frame = _G and _G.PortalAuthoritySettingsWindow or nil
    if frame and frame.IsObjectType and frame:IsObjectType("Frame") then
        return frame
    end

    return nil
end

function PortalAuthority:GetSettingsHostVisibilityState()
    local sawHost = false

    local customFrame = self:GetExistingSettingsWindowFrame()
    if customFrame and customFrame.IsShown then
        sawHost = true
        if customFrame:IsShown() then
            return true
        end
    end

    local settingsPanel = self:CpuDiagGetSettingsPanelFrame()
    if settingsPanel and settingsPanel.IsShown then
        sawHost = true
        if settingsPanel:IsShown() then
            return true
        end
    end

    if sawHost then
        return false
    end
    return nil
end

function PortalAuthority:IsAnySettingsHostVisible()
    return self:GetSettingsHostVisibilityState() == true
end

function PortalAuthority:BuildCpuDiagEnvSnapshot()
    local settingsVisible = self:GetSettingsHostVisibilityState()

    local lockState = "unknown"
    local db = PortalAuthorityDB
    if type(db) == "table"
        and db.dockLocked ~= nil
        and db.deathAlertLocked ~= nil
        and type(db.modules) == "table"
        and type(db.modules.timers) == "table"
        and db.modules.timers.locked ~= nil
        and type(db.modules.interruptTracker) == "table"
        and db.modules.interruptTracker.locked ~= nil
    then
        local unlockedSurfaces = self:PerfGetUnlockedSurfaceNames()
        if #unlockedSurfaces <= 0 then
            lockState = "closed"
        elseif #unlockedSurfaces >= 4 then
            lockState = "unlock_global"
        else
            lockState = "unlock_surface:" .. table.concat(unlockedSurfaces, "+")
        end
    end

    local resting = nil
    if type(IsResting) == "function" then
        resting = IsResting() and true or false
    end

    local inInstance = nil
    if type(IsInInstance) == "function" then
        local ok, value = pcall(IsInInstance)
        if ok then
            inInstance = value and true or false
        end
    end

    local inCombat = nil
    if type(InCombatLockdown) == "function" then
        inCombat = InCombatLockdown() and true or false
    end

    return {
        settingsVisible = settingsVisible,
        lockState = lockState,
        resting = resting,
        inInstance = inInstance,
        inCombat = inCombat,
    }
end

function PortalAuthority:BuildCpuDiagMemorySnapshot()
    local state = self:CpuDiagEnsureState()
    local memory = state.memory or {}
    local currentLuaKB = PA_CpuDiagReadLuaHeapKB()
    local deltaFromStartKB = nil
    if type(currentLuaKB) == "number" and type(memory.startLuaKB) == "number" then
        deltaFromStartKB = currentLuaKB - memory.startLuaKB
    end

    return {
        currentLuaKB = currentLuaKB,
        startLuaKB = memory.startLuaKB,
        deltaFromStartKB = deltaFromStartKB,
        trackedMinKB = memory.trackedMinKB,
        trackedMaxKB = memory.trackedMaxKB,
        trackedSamples = tonumber(memory.trackedSamples) or 0,
        largeRiseEvents = tonumber(memory.largeRiseEvents) or 0,
        gcSuspectDrops = tonumber(memory.gcSuspectDrops) or 0,
        largestRiseKB = tonumber(memory.largestRiseKB) or 0,
        largestDropKB = tonumber(memory.largestDropKB) or 0,
    }
end

function PortalAuthority:BuildCpuDiagAddonMemorySnapshot()
    local state = self:CpuDiagEnsureState()
    local baseline = state.addonMemory or {}
    if baseline.seeded ~= true then
        return {
            available = false,
            entries = {},
        }
    end

    local current = PA_CpuDiagReadAddonMemorySnapshot()
    if type(current) ~= "table"
        or type(current.entries) ~= "table"
        or type(current.entriesByKey) ~= "table"
        or type(current.totalKB) ~= "number"
    then
        return {
            available = false,
            entries = {},
        }
    end

    local baselineByKey = type(baseline.byKey) == "table" and baseline.byKey or {}
    local entries = {}
    local paEntry = nil

    for i = 1, #current.entries do
        local entry = current.entries[i]
        local key = entry and entry.key or nil
        local currentKB = entry and tonumber(entry.currentKB) or nil
        if type(key) ~= "string" or key == "" or type(currentKB) ~= "number" then
            return {
                available = false,
                entries = {},
            }
        end

        local baselineKB = tonumber(baselineByKey[key])
        local isNew = baselineKB == nil
        if baselineKB == nil then
            baselineKB = 0
        end

        local displayName = entry.displayName
        if type(displayName) ~= "string" or displayName == "" then
            displayName = key
        end

        local summaryEntry = {
            key = key,
            displayName = displayName,
            currentKB = currentKB,
            deltaKB = currentKB - baselineKB,
            newSinceReset = isNew,
        }
        entries[#entries + 1] = summaryEntry
        if key == ADDON_NAME then
            paEntry = summaryEntry
        end
    end

    table.sort(entries, function(left, right)
        local leftAbs = math.abs(tonumber(left.deltaKB) or 0)
        local rightAbs = math.abs(tonumber(right.deltaKB) or 0)
        if leftAbs ~= rightAbs then
            return leftAbs > rightAbs
        end

        local leftCurrent = tonumber(left.currentKB) or 0
        local rightCurrent = tonumber(right.currentKB) or 0
        if leftCurrent ~= rightCurrent then
            return leftCurrent > rightCurrent
        end

        local leftName = tostring(left.displayName or left.key or "")
        local rightName = tostring(right.displayName or right.key or "")
        return leftName < rightName
    end)

    local paRankByDelta = nil
    if paEntry then
        for i = 1, #entries do
            if entries[i].key == paEntry.key then
                paRankByDelta = i
                break
            end
        end
    end

    local totalAddonKB = tonumber(current.totalKB)
    local totalAddonDeltaKB = nil
    if type(totalAddonKB) == "number" and type(baseline.totalKB) == "number" then
        totalAddonDeltaKB = totalAddonKB - baseline.totalKB
    end

    local paKB = paEntry and tonumber(paEntry.currentKB) or nil
    local paDeltaKB = paEntry and tonumber(paEntry.deltaKB) or nil
    local paSharePct = nil
    if type(paKB) == "number" and type(totalAddonKB) == "number" and totalAddonKB > 0 then
        paSharePct = (paKB / totalAddonKB) * 100
    end

    return {
        available = true,
        entries = entries,
        paKB = paKB,
        paDeltaKB = paDeltaKB,
        totalAddonKB = totalAddonKB,
        totalAddonDeltaKB = totalAddonDeltaKB,
        paSharePct = paSharePct,
        paRankByDelta = paRankByDelta,
        newSinceReset = paEntry and paEntry.newSinceReset or nil,
    }
end

function PortalAuthority:CpuDiagCaptureTriggerSnapshot(triggerKey)
    local state = self:CpuDiagEnsureState()
    local now = GetTime() or 0
    local env = self:BuildCpuDiagEnvSnapshot()
    local luaKB = PA_CpuDiagReadLuaHeapKB()
    local lastTrackedLuaKB = state.memory and state.memory.lastTrackedLuaKB or nil
    local deltaKB = nil
    if type(luaKB) == "number" and type(lastTrackedLuaKB) == "number" then
        deltaKB = luaKB - lastTrackedLuaKB
    end

    return {
        elapsed = math.max(0, now - (state.startedAt or 0)),
        key = triggerKey,
        luaKB = luaKB,
        deltaKB = deltaKB,
        settings = env.settingsVisible,
        resting = env.resting,
        instance = env.inInstance,
        combat = env.inCombat,
    }
end

function PortalAuthority:CpuDiagRecordTrigger(triggerKey)
    local state = self:CpuDiagEnsureState()
    if state.suspendCounting then
        return
    end
    if type(triggerKey) ~= "string" or state.triggerCounts[triggerKey] == nil then
        return
    end

    local memory = state.memory or {}
    local snapshot = self:CpuDiagCaptureTriggerSnapshot(triggerKey)
    local luaKB = snapshot.luaKB
    local deltaKB = snapshot.deltaKB

    state.triggerCounts.total = (tonumber(state.triggerCounts.total) or 0) + 1
    state.triggerCounts[triggerKey] = (tonumber(state.triggerCounts[triggerKey]) or 0) + 1

    if type(luaKB) == "number" then
        memory.trackedSamples = (tonumber(memory.trackedSamples) or 0) + 1
        if memory.trackedMinKB == nil or luaKB < memory.trackedMinKB then
            memory.trackedMinKB = luaKB
        end
        if memory.trackedMaxKB == nil or luaKB > memory.trackedMaxKB then
            memory.trackedMaxKB = luaKB
        end
        if type(deltaKB) == "number" then
            if deltaKB >= PA_CPUDIAG_LARGE_HEAP_DELTA_KB then
                memory.largeRiseEvents = (tonumber(memory.largeRiseEvents) or 0) + 1
            end
            if deltaKB <= -PA_CPUDIAG_LARGE_HEAP_DELTA_KB then
                memory.gcSuspectDrops = (tonumber(memory.gcSuspectDrops) or 0) + 1
            end
            if deltaKB > (tonumber(memory.largestRiseKB) or 0) then
                memory.largestRiseKB = deltaKB
            end
            if deltaKB < (tonumber(memory.largestDropKB) or 0) then
                memory.largestDropKB = deltaKB
            end
        end
        memory.lastTrackedLuaKB = luaKB
    end

    PA_CpuDiagPushRingBuffer(state.triggerRecent, snapshot)
end

function PortalAuthority:CpuDiagEnsureSettingsHooks()
    if PA_IsSettingsBaselineGateEnabled() then
        return false
    end
    if self._cpuDiagSettingsHooksInstalled then
        return true
    end

    local settingsPanel = self:CpuDiagGetSettingsPanelFrame()
    if not settingsPanel or not settingsPanel.HookScript then
        return false
    end

    settingsPanel:HookScript("OnShow", function()
        if PortalAuthority and PortalAuthority.CpuDiagRecordTrigger then
            PortalAuthority:CpuDiagRecordTrigger("settings_open")
        end
    end)
    settingsPanel:HookScript("OnHide", function()
        if PortalAuthority and PortalAuthority.CpuDiagRecordTrigger then
            PortalAuthority:CpuDiagRecordTrigger("settings_closed")
        end
    end)
    self._cpuDiagSettingsHooksInstalled = true
    return true
end

function PortalAuthority:CloseCustomSettingsWindowForBlizzardOpen()
    if not PortalAuthority
        or not PortalAuthority.IsSettingsWindowHostEnabled
        or not PortalAuthority:IsSettingsWindowHostEnabled()
        or not PortalAuthority.GetExistingSettingsWindowFrame
    then
        return
    end

    local frame = PortalAuthority:GetExistingSettingsWindowFrame()
    if not frame or not frame.IsShown or not frame:IsShown() then
        return
    end

    if PortalAuthority.CloseSettingsWindow then
        PortalAuthority:CloseSettingsWindow()
    end

    frame = PortalAuthority:GetExistingSettingsWindowFrame()
    if frame and frame.IsShown and frame:IsShown() and frame.Hide then
        frame:Hide()
    end
end

function PortalAuthority:TryHookSettingsPanelCoexistence()
    local self = self or PortalAuthority
    if self._settingsWindowCoexistencePanelHooked then
        return true
    end

    local settingsPanel = self:CpuDiagGetSettingsPanelFrame()
    if not settingsPanel or not settingsPanel.HookScript then
        return false
    end
    if settingsPanel._paSettingsWindowCoexistenceHooked then
        self._settingsWindowCoexistencePanelHooked = true
        return true
    end

    settingsPanel:HookScript("OnShow", function()
        if PortalAuthority and PortalAuthority.CloseCustomSettingsWindowForBlizzardOpen then
            PortalAuthority:CloseCustomSettingsWindowForBlizzardOpen()
        end
    end)
    settingsPanel._paSettingsWindowCoexistenceHooked = true
    self._settingsWindowCoexistencePanelHooked = true
    return true
end

function PortalAuthority:EnsureSettingsHostCoexistenceHooks()
    local installed = false

    if not self._settingsWindowCoexistenceMethodsHooked
        and type(hooksecurefunc) == "function"
        and Settings
    then
        local hookedAnyMethod = false
        local openHookMethods = {
            "Open",
            "OpenToCategory",
            "OpenToCategoryID",
        }
        for i = 1, #openHookMethods do
            local methodName = openHookMethods[i]
            if type(Settings[methodName]) == "function" then
                hooksecurefunc(Settings, methodName, function()
                    if PortalAuthority and PortalAuthority.CloseCustomSettingsWindowForBlizzardOpen then
                        PortalAuthority:CloseCustomSettingsWindowForBlizzardOpen()
                    end
                end)
                hookedAnyMethod = true
            end
        end
        if hookedAnyMethod then
            self._settingsWindowCoexistenceMethodsHooked = true
            installed = true
        end
    elseif self._settingsWindowCoexistenceMethodsHooked then
        installed = true
    end

    if self:TryHookSettingsPanelCoexistence() then
        installed = true
    end

    self._settingsWindowCoexistenceHooksInstalled = installed
    return installed
end

function PortalAuthority:ResolveSettingsSectionKeyFromCategoryID(categoryID)
    if categoryID == nil then
        return "announcements"
    end
    if type(categoryID) ~= "number" then
        return nil
    end

    if type(self.rootCategoryID) == "number" and categoryID == self.rootCategoryID then
        return "root"
    end

    return nil
end

function PortalAuthority:ReadSettingsWindowOpenError(fallback)
    local runtime = self and self._settingsWindowRuntime or nil
    local message = runtime and runtime.lastError or nil
    if type(message) == "string" and message ~= "" then
        return message
    end
    return fallback or "Settings host is unavailable."
end

function PortalAuthority:OpenCustomSettingsSection(sectionKey, source, opts)
    if type(self.OpenSettingsWindow) ~= "function" then
        return false, "Settings host is unavailable."
    end

    local openOpts = type(opts) == "table" and opts or {}
    openOpts.source = source or openOpts.source or "open-settings"
    openOpts.targeted = true

    local ok, result = pcall(self.OpenSettingsWindow, self, sectionKey, openOpts)
    if ok and result ~= false then
        return true
    end
    if not ok then
        return false, tostring(result or "Settings host is unavailable.")
    end
    return false, self:ReadSettingsWindowOpenError("Settings host is unavailable.")
end

function PortalAuthority:OpenCustomSettingsSectionOrRoot(sectionKey, source, opts)
    if self.IsSettingsWindowHostEnabled and self:IsSettingsWindowHostEnabled() then
        return self:OpenCustomSettingsSection(sectionKey, source, opts)
    end
    return self:OpenSettings(self.rootCategoryID)
end

function PortalAuthority:CpuDiagRefreshSubsystem(target)
    local modulesApi = self.Modules
    local registry = modulesApi and modulesApi.registry or nil
    if not registry then
        return
    end

    local module = nil
    if target == "timers" then
        module = registry.timers
    elseif target == "interrupt" then
        module = registry.interruptTracker
    end

    if module and module.EvaluateVisibility then
        pcall(module.EvaluateVisibility, module, "cpudiag-visibility-change")
    end
end

function PortalAuthority:CpuDiagRefreshAllSubsystems()
    self:CpuDiagRefreshSubsystem("timers")
    self:CpuDiagRefreshSubsystem("interrupt")
end

function PortalAuthority:SetCpuDiagVisibilityMode(target, mode)
    local entry = self:CpuDiagGetEntry(target)
    if not entry then
        return false
    end

    local normalized = PA_CpuDiagNormalizeVisibilityMode(mode)
    if entry.visibilityMode == normalized then
        return true
    end

    entry.visibilityMode = normalized
    self:CpuDiagSuspendCounting(function()
        self:CpuDiagRefreshSubsystem(target)
    end)
    return true
end

function PortalAuthority:ResetCpuDiag()
    if PA_IsStaticBaselineGateEnabled() then
        return false
    end
    local state = self:CpuDiagEnsureState()
    state.startedAt = GetTime() or 0
    state.timers.naturalVisible = nil
    state.timers.effectiveVisible = nil
    state.timers.frameShown = nil
    state.timers.evaluateVisibilityCalls = 0
    state.timers.tickCalls = 0
    state.interrupt.naturalVisible = nil
    state.interrupt.effectiveVisible = nil
    state.interrupt.frameShown = nil
    state.interrupt.evaluateVisibilityCalls = 0
    state.interrupt.updateDisplayCalls = 0
    state.interrupt.periodicInspectCalls = 0
    state.moduleEvents.unitAura = 0
    state.moduleEvents.unitPowerUpdate = 0
    state.moduleEvents.chatMsgAddon = 0
    state.moduleEvents.other = 0
    state.coreEvents.chat = 0
    state.coreEvents.groupRoster = 0
    state.coreEvents.spellcast = 0
    state.coreEvents.other = 0
    PA_CpuDiagResetFixedCounter(state.coreDispatch, PA_CPUDIAG_CORE_DISPATCH_EVENTS)
    PA_CpuDiagResetFixedCounter(state.modulesDispatch, PA_CPUDIAG_MODULES_DISPATCH_EVENTS)
    PA_CpuDiagResetFixedCounter(state.dockDispatch, PA_CPUDIAG_DOCK_DISPATCH_EVENTS)
    PA_CpuDiagResetFixedCounter(state.keystoneDispatch, PA_CPUDIAG_KEYSTONE_DISPATCH_EVENTS)
    PA_CpuDiagResetFixedCounter(state.unitCallbacks, PA_CPUDIAG_UNIT_CALLBACK_EVENTS)
    PA_CpuDiagResetFixedCounter(state.delayedTimers, PA_CPUDIAG_DELAYED_TIMER_KEYS)
    PA_CpuDiagResetFixedCounter(state.uiHooks, PA_CPUDIAG_UI_HOOK_KEYS)
    PA_CpuDiagResetFixedCounter(state.triggerCounts, PA_CPUDIAG_TRIGGER_KEYS)
    PA_CpuDiagResetRingBuffer(state.triggerRecent)
    local baselineLuaKB = PA_CpuDiagReadLuaHeapKB()
    state.memory.startLuaKB = baselineLuaKB
    state.memory.lastTrackedLuaKB = baselineLuaKB
    state.memory.trackedMinKB = baselineLuaKB
    state.memory.trackedMaxKB = baselineLuaKB
    state.memory.trackedSamples = 0
    state.memory.largeRiseEvents = 0
    state.memory.gcSuspectDrops = 0
    state.memory.largestRiseKB = 0
    state.memory.largestDropKB = 0
    PA_CpuDiagSeedAddonMemoryBaseline(state, PA_CpuDiagReadAddonMemorySnapshot())
    state.dockRuntime.onUpdateTickCalls = 0
    state.dockRuntime.buttonCooldownTickCalls = 0
    state.keystone.pollCalls = 0
    state.moveHint.tickCalls = 0
    state.onboarding.tickCalls = 0
    state.deathAlerts.previewTickCalls = 0
    state.deathAlerts.dragTickCalls = 0
    state.releaseGate.onUpdateCalls = 0

    self:CpuDiagAppendIdleWitnessEntry({ "cpudiag_reset" }, nil)
    self:CpuDiagScheduleIdleWitnessStart()
    return true
end

function PortalAuthority:BuildCpuDiagTimersSnapshot()
    local state = self:CpuDiagEnsureState()
    local entry = state.timers
    local modulesApi = self.Modules
    local module = modulesApi and modulesApi.registry and modulesApi.registry.timers or nil
    local frame = module and (module.frame or module.mainFrame) or nil
    local testMode = modulesApi and modulesApi.timersTestMode == true or false
    local unlocked = module and module.unlocked == true or false

    if not unlocked and module and module.GetDB then
        local okDb, db = pcall(module.GetDB, module)
        if okDb and type(db) == "table" then
            unlocked = db.locked == false
        end
    end

    local naturalVisible = entry.naturalVisible
    if naturalVisible == nil then
        local liveVisible = false
        if module and module.ShouldShowLive then
            local okLive, live = pcall(module.ShouldShowLive, module)
            liveVisible = okLive and live and true or false
        end
        naturalVisible = liveVisible or testMode or unlocked
    end

    local effectiveVisible = entry.effectiveVisible
    if effectiveVisible == nil then
        effectiveVisible = self:CpuDiagResolveVisibility("timers", naturalVisible)
    end

    local frameShown = frame and frame.IsShown and frame:IsShown() and true or false

    return {
        overrideMode = self:GetCpuDiagVisibilityMode("timers"),
        naturalVisible = naturalVisible and true or false,
        effectiveVisible = effectiveVisible and true or false,
        frameShown = frameShown,
        unlocked = unlocked,
        testMode = testMode,
        tickerActive = module and module.ticker ~= nil or false,
        evaluateVisibilityCalls = entry.evaluateVisibilityCalls or 0,
        tickCalls = entry.tickCalls or 0,
    }
end

function PortalAuthority:BuildCpuDiagInterruptSnapshot()
    local state = self:CpuDiagEnsureState()
    local entry = state.interrupt
    local modulesApi = self.Modules
    local module = modulesApi and modulesApi.registry and modulesApi.registry.interruptTracker or nil
    local frame = module and module.frame or nil
    local unlocked = module and module.unlocked == true or false

    if not unlocked and module and module.GetDB then
        local okDb, db = pcall(module.GetDB, module)
        if okDb and type(db) == "table" then
            unlocked = db.locked == false
        end
    end

    local isPreview = unlocked
    if module and module.IsPreviewMode then
        local okPreview, preview = pcall(module.IsPreviewMode, module)
        if okPreview then
            isPreview = preview and true or false
        end
    end

    local naturalVisible = entry.naturalVisible
    if naturalVisible == nil then
        local liveVisible = false
        if module and module.IsSupportedLiveContext then
            local okLive, live = pcall(module.IsSupportedLiveContext, module)
            liveVisible = okLive and live and true or false
        end
        naturalVisible = liveVisible or isPreview
    end

    local effectiveVisible = entry.effectiveVisible
    if effectiveVisible == nil then
        effectiveVisible = self:CpuDiagResolveVisibility("interrupt", naturalVisible)
    end

    local frameShown = frame and frame.IsShown and frame:IsShown() and true or false

    return {
        overrideMode = self:GetCpuDiagVisibilityMode("interrupt"),
        naturalVisible = naturalVisible and true or false,
        effectiveVisible = effectiveVisible and true or false,
        frameShown = frameShown,
        unlocked = unlocked,
        previewMode = isPreview and true or false,
        tickerActive = module and module.ticker ~= nil or false,
        periodicInspectActive = module and module.inspectTicker ~= nil or false,
        evaluateVisibilityCalls = entry.evaluateVisibilityCalls or 0,
        updateDisplayCalls = entry.updateDisplayCalls or 0,
        periodicInspectCalls = entry.periodicInspectCalls or 0,
    }
end

function PortalAuthority:BuildCpuDiagKeystoneSnapshot()
    local state = self:CpuDiagEnsureState()
    local keystone = self.KeystoneUtility or nil
    local container = keystone and keystone.container or nil
    local keystoneFrame = _G.ChallengesKeystoneFrame
    local pollArmed = false
    if container and container.GetScript then
        pollArmed = container:GetScript("OnUpdate") ~= nil
    end

    return {
        enabled = PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.keystoneHelperEnabled),
        frameShown = keystoneFrame and keystoneFrame.IsShown and keystoneFrame:IsShown() and true or false,
        helperShown = container and container.IsShown and container:IsShown() and true or false,
        pollArmed = pollArmed,
        pollCalls = state.keystone.pollCalls or 0,
    }
end

function PortalAuthority:BuildCpuDiagMoveHintSnapshot()
    local state = self:CpuDiagEnsureState()
    return {
        tickerActive = self._moveHintTicker ~= nil,
        tickCalls = state.moveHint.tickCalls or 0,
    }
end

function PortalAuthority:BuildCpuDiagOnboardingSnapshot()
    local runtime = self._onboardingD4
    return {
        active = runtime and runtime.active == true or false,
        tickerActive = false,
        tickCalls = 0,
    }
end

function PortalAuthority:BuildCpuDiagDeathAlertsSnapshot()
    local state = self:CpuDiagEnsureState()
    local deathAlerts = self.DeathAlerts or nil
    local deathFrame = deathAlerts and deathAlerts.frame or nil
    return {
        frameShown = deathFrame and deathFrame.IsShown and deathFrame:IsShown() and true or false,
        testMode = deathAlerts and deathAlerts._testMode == true or false,
        previewTickerActive = deathAlerts and deathAlerts.previewTicker ~= nil or false,
        previewTickCalls = state.deathAlerts.previewTickCalls or 0,
        dragTickerActive = deathAlerts and deathAlerts.dragTicker ~= nil or false,
        dragTickCalls = state.deathAlerts.dragTickCalls or 0,
    }
end

function PortalAuthority:BuildCpuDiagReleaseGateSnapshot()
    local state = self:CpuDiagEnsureState()
    local popupShown = false
    for i = 1, 4 do
        local popup = _G["StaticPopup" .. i]
        if popup and popup.IsShown and popup:IsShown() and popup.which == "DEATH" then
            popupShown = true
            break
        end
    end

    return {
        enabled = PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.releaseGateEnabled),
        popupShown = popupShown,
        onUpdateCalls = state.releaseGate.onUpdateCalls or 0,
    }
end

function PortalAuthority:BuildCpuDiagSettingsFirstOpenSnapshot()
    local host = self._settingsFirstOpenHostDebug
    local panelEntries = self._settingsFirstOpenDebugPanels
    local snapshot = {
        host = {
            selectedKey = host and tostring(host.selectedKey or "none") or "none",
            selectedGeneration = tonumber(host and host.selectedGeneration) or 0,
            selectionToken = tonumber(host and host.selectionToken) or 0,
        },
        panels = {},
    }

    if type(panelEntries) ~= "table" then
        return snapshot
    end

    for i = 1, #panelEntries do
        local entry = panelEntries[i]
        local panel = entry and entry.panel or nil
        local sizeTarget = panel and (panel._settingsFirstOpenSizeTarget or panel._sizingFrame or panel) or nil
        local readyValue = nil
        if panel and type(panel._settingsFirstOpenIsReady) == "function" then
            local ok, value = pcall(panel._settingsFirstOpenIsReady, panel)
            if ok then
                readyValue = value == true
            else
                readyValue = "error"
            end
        end

        snapshot.panels[#snapshot.panels + 1] = {
            key = tostring(entry and entry.key or "?"),
            name = tostring(entry and entry.name or "?"),
            initialized = panel and panel._initialized == true or false,
            shown = panel and panel.IsShown and panel:IsShown() and true or false,
            state = panel and tostring(panel._paFirstOpenState or "idle") or "missing",
            generation = tonumber(panel and panel._paFirstOpenGeneration) or 0,
            sizeReady = sizeTarget and sizeTarget.GetWidth and sizeTarget.GetHeight
                and ((tonumber(sizeTarget:GetWidth()) or 0) > 1 and (tonumber(sizeTarget:GetHeight()) or 0) > 1)
                or false,
            sizeW = tonumber(sizeTarget and sizeTarget.GetWidth and sizeTarget:GetWidth()) or 0,
            sizeH = tonumber(sizeTarget and sizeTarget.GetHeight and sizeTarget:GetHeight()) or 0,
            ready = readyValue,
            selected = host and host.selectedPanel == panel or false,
        }
    end

    return snapshot
end

function PortalAuthority:BuildCpuDiagCoreEventSnapshot()
    local state = self:CpuDiagEnsureState()
    return {
        chat = state.coreEvents.chat or 0,
        groupRoster = state.coreEvents.groupRoster or 0,
        spellcast = state.coreEvents.spellcast or 0,
        other = state.coreEvents.other or 0,
    }
end

function PortalAuthority:BuildCpuDiagDockSurfaceSnapshot()
    local snapshot = {
        shown = false,
        visibilityDriver = false,
        entries = 0,
        activeButtons = 0,
        cooldownActive = 0,
        cooldownOnUpdate = 0,
        cooldownTextShown = 0,
        labelShown = 0,
        iconMove = 0,
        labelMove = 0,
        labelSettle = 0,
        labelAnimActive = 0,
        settleRunning = false,
    }

    local dockFrame = self and self.dockFrame or nil
    if not dockFrame then
        return snapshot
    end

    snapshot.shown = dockFrame.IsShown and dockFrame:IsShown() and true or false
    snapshot.visibilityDriver = self.dockVisibilityDriverActive == true
    snapshot.entries = tonumber(self.dockEntriesCount) or 0
    snapshot.labelAnimActive = tonumber(self._paDockLabelAnimActiveCount) or 0
    snapshot.settleRunning = self._paDockLabelSettleRunning == true

    local buttons = nil
    if type(self.dockActiveButtons) == "table" and #self.dockActiveButtons > 0 then
        buttons = self.dockActiveButtons
    elseif type(self.dockButtons) == "table" and #self.dockButtons > 0 then
        buttons = self.dockButtons
    end
    if type(buttons) ~= "table" or #buttons <= 0 then
        return snapshot
    end

    local now = GetTime() or 0
    for i = 1, #buttons do
        local btn = buttons[i]
        if btn then
            local liveButton = btn.entry ~= nil or btn.slotIndex ~= nil
            if (not liveButton) and btn.IsShown and btn:IsShown() then
                liveButton = true
            end
            if liveButton then
                snapshot.activeButtons = snapshot.activeButtons + 1

                if (tonumber(btn.cooldownEndTime) or 0) > now then
                    snapshot.cooldownActive = snapshot.cooldownActive + 1
                end
                if btn.GetScript and btn:GetScript("OnUpdate") ~= nil then
                    snapshot.cooldownOnUpdate = snapshot.cooldownOnUpdate + 1
                end

                local cooldownText = btn.cooldownText
                if cooldownText and cooldownText.IsShown and cooldownText:IsShown() then
                    snapshot.cooldownTextShown = snapshot.cooldownTextShown + 1
                end

                local labelArea = btn.labelArea
                if labelArea and labelArea.IsShown and labelArea:IsShown() then
                    snapshot.labelShown = snapshot.labelShown + 1
                end

                local moveAG = btn._moveAG
                if moveAG and moveAG.IsPlaying and moveAG:IsPlaying() then
                    snapshot.iconMove = snapshot.iconMove + 1
                end

                local labelMoveAG = labelArea and labelArea._paLabelMoveAG or nil
                if labelMoveAG and labelMoveAG.IsPlaying and labelMoveAG:IsPlaying() then
                    snapshot.labelMove = snapshot.labelMove + 1
                end

                local labelSettleAG = labelArea and labelArea._paLabelSettleAG or nil
                if labelSettleAG and labelSettleAG.IsPlaying and labelSettleAG:IsPlaying() then
                    snapshot.labelSettle = snapshot.labelSettle + 1
                end
            end
        end
    end

    return snapshot
end

function PortalAuthority:CpuDiagEnsureIdleWitnessSession()
    if PA_IsStaticBaselineGateEnabled() then
        self._idleWitnessRuntime = nil
        return nil
    end
    local runtime = self._idleWitnessRuntime
    if type(runtime) == "table" and runtime.started == true and type(runtime.sessionId) == "number" and runtime.sessionId > 0 then
        return runtime
    end

    if self.InitializeProfiles and not self._profilesInitialized then
        self:InitializeProfiles()
    end

    local store = PA_CpuDiagEnsureIdleWitnessStore()
    if type(store) ~= "table" then
        return nil
    end
    local sessionId = math.max(0, tonumber(store.sessionId) or 0) + 1
    local sessionStartedAt = PA_CpuDiagSafeTime()
    local sessionStartedUptime = GetTime() or 0

    store.sessionId = sessionId
    store.sessionStartedAt = sessionStartedAt
    store.sessionStartedUptime = sessionStartedUptime
    store.lastHeartbeatAt = 0
    local sessionMeta = {}
    if PA_IsUiSurfaceGateEnabled() then
        sessionMeta.uiSurfaceGate = true
    end
    if PA_IsSettingsBaselineGateEnabled() then
        sessionMeta.settingsBaselineGate = true
    end
    if PA_IsSettingsEagerBuildGateEnabled() then
        sessionMeta.settingsEagerBuildGate = true
    end
    if PA_IsSettingsDirectBuildGateEnabled() then
        sessionMeta.settingsDirectBuildGate = true
    end
    if next(sessionMeta) ~= nil then
        PA_CpuDiagSetIdleWitnessSessionMeta(store, sessionId, sessionMeta)
    end

    runtime = {
        started = true,
        sessionId = sessionId,
        sessionStartedAt = sessionStartedAt,
        sessionStartedUptime = sessionStartedUptime,
        previousSnapshot = nil,
    }
    self._idleWitnessRuntime = runtime

    local snapshot = self:BuildIdleWitnessSnapshot()
    if type(snapshot) == "table" then
        runtime.previousSnapshot = snapshot
    end
    return runtime
end

function PortalAuthority:CpuDiagStopIdleWitnessTicker()
    if self._idleWitnessTicker and self._idleWitnessTicker.Cancel then
        self._idleWitnessTicker:Cancel()
    end
    self._idleWitnessTicker = nil
    self._idleWitnessStartScheduled = false
end

function PortalAuthority:BuildIdleWitnessSnapshot()
    local runtime = self._idleWitnessRuntime
    if type(runtime) ~= "table" or runtime.started ~= true or type(runtime.sessionId) ~= "number" or runtime.sessionId <= 0 then
        return nil
    end

    local state = self:CpuDiagEnsureState()
    local nowUptime = GetTime() or 0
    local sessionUptime = math.max(0, nowUptime - (tonumber(runtime.sessionStartedUptime) or nowUptime))
    local db = PortalAuthorityDB
    local modulesApi = self.Modules
    local timersModule = modulesApi and modulesApi.registry and modulesApi.registry.timers or nil
    local interruptModule = modulesApi and modulesApi.registry and modulesApi.registry.interruptTracker or nil
    local latestTrigger = PA_CpuDiagGetRingBufferNewestEntry(state.triggerRecent)
    local currentDiagElapsed = math.max(0, (GetTime() or 0) - (state.startedAt or 0))

    local settingsVisible = self:GetSettingsHostVisibilityState()

    local resting = false
    if type(IsResting) == "function" then
        resting = IsResting() and true or false
    end

    local inInstance = false
    if type(IsInInstance) == "function" then
        local ok, value = pcall(IsInInstance)
        if ok then
            inInstance = value and true or false
        end
    end

    local inCombat = false
    if type(InCombatLockdown) == "function" then
        inCombat = InCombatLockdown() and true or false
    end

    local dockUnlocked = db and db.dockLocked == false or false
    local timersUnlocked = false
    if type(db) == "table" and type(db.modules) == "table" and type(db.modules.timers) == "table" then
        timersUnlocked = db.modules.timers.locked == false
    elseif timersModule and timersModule.unlocked == true then
        timersUnlocked = true
    end

    local interruptUnlocked = false
    if type(db) == "table" and type(db.modules) == "table" and type(db.modules.interruptTracker) == "table" then
        interruptUnlocked = db.modules.interruptTracker.locked == false
    elseif interruptModule and interruptModule.unlocked == true then
        interruptUnlocked = true
    end

    local deathUnlocked = db and db.deathAlertLocked == false or false

    local dockShown = self.dockFrame and self.dockFrame.IsShown and self.dockFrame:IsShown() and true or false
    local dockOnUpdateArmed = self.dockFrame and self.dockFrame.GetScript and self.dockFrame:GetScript("OnUpdate") ~= nil or false
    local moveHintTicker = self._moveHintTicker ~= nil
    local onboardingTicker = false
    local deathAlerts = self.DeathAlerts or nil
    local deathShown = deathAlerts and deathAlerts.frame and deathAlerts.frame.IsShown and deathAlerts.frame:IsShown() and true or false
    local deathPreviewTicker = deathAlerts and deathAlerts.previewTicker ~= nil or false
    local deathDragTicker = deathAlerts and deathAlerts.dragTicker ~= nil or false
    local timersFrame = timersModule and (timersModule.frame or timersModule.mainFrame) or nil
    local timersShown = timersFrame and timersFrame.IsShown and timersFrame:IsShown() and true or false
    local timersTicker = timersModule and timersModule.ticker ~= nil or false
    local interruptFrame = interruptModule and interruptModule.frame or nil
    local interruptShown = interruptFrame and interruptFrame.IsShown and interruptFrame:IsShown() and true or false
    local interruptTicker = interruptModule and interruptModule.ticker ~= nil or false
    local interruptInspectTicker = interruptModule and interruptModule.inspectTicker ~= nil or false
    local keystoneContainer = self.KeystoneUtility and self.KeystoneUtility.container or nil
    local keystoneHelperShown = keystoneContainer and keystoneContainer.IsShown and keystoneContainer:IsShown() and true or false
    local keystonePollArmed = keystoneContainer and keystoneContainer.GetScript and keystoneContainer:GetScript("OnUpdate") ~= nil or false
    local dockSurface = self:BuildCpuDiagDockSurfaceSnapshot()

    local idleGate = settingsVisible == false
        and inCombat == false
        and dockUnlocked == false
        and timersUnlocked == false
        and interruptUnlocked == false
        and deathUnlocked == false

    local unexpectedRuntime = idleGate and (
        moveHintTicker
        or onboardingTicker
        or deathShown
        or deathPreviewTicker
        or deathDragTicker
        or dockOnUpdateArmed
        or timersTicker
        or interruptTicker
        or interruptInspectTicker
    ) or false

    local triggerKey = nil
    local triggerAge = nil
    local triggerSignature = nil
    if type(latestTrigger) == "table" then
        triggerKey = type(latestTrigger.key) == "string" and latestTrigger.key or nil
        if type(triggerKey) == "string" and triggerKey ~= "" then
            local triggerElapsed = tonumber(latestTrigger.elapsed) or 0
            triggerAge = math.max(0, currentDiagElapsed - triggerElapsed)
            triggerSignature = string.format("%s@%.3f", triggerKey, triggerElapsed)
        end
    end

    return {
        sessionId = runtime.sessionId,
        t = PA_CpuDiagSafeTime(),
        u = sessionUptime,
        settings = settingsVisible,
        resting = resting,
        instance = inInstance,
        combat = inCombat,
        dockUnlocked = dockUnlocked,
        timersUnlocked = timersUnlocked,
        interruptUnlocked = interruptUnlocked,
        deathUnlocked = deathUnlocked,
        dockShown = dockShown,
        dockOnUpdateArmed = dockOnUpdateArmed,
        moveHintTicker = moveHintTicker,
        onboardingTicker = onboardingTicker,
        deathShown = deathShown,
        deathPreviewTicker = deathPreviewTicker,
        deathDragTicker = deathDragTicker,
        timersShown = timersShown,
        timersTicker = timersTicker,
        interruptShown = interruptShown,
        interruptTicker = interruptTicker,
        interruptInspectTicker = interruptInspectTicker,
        keystoneHelperShown = keystoneHelperShown,
        keystonePollArmed = keystonePollArmed,
        cooldownActive = tonumber(dockSurface.cooldownActive) or 0,
        cooldownOnUpdate = tonumber(dockSurface.cooldownOnUpdate) or 0,
        cooldownTextShown = tonumber(dockSurface.cooldownTextShown) or 0,
        iconMove = tonumber(dockSurface.iconMove) or 0,
        labelMove = tonumber(dockSurface.labelMove) or 0,
        labelSettle = tonumber(dockSurface.labelSettle) or 0,
        labelAnimActive = tonumber(dockSurface.labelAnimActive) or 0,
        settleRunning = dockSurface.settleRunning == true,
        idleGate = idleGate,
        unexpectedRuntime = unexpectedRuntime,
        triggerKey = triggerKey,
        triggerAge = triggerAge,
        triggerSignature = triggerSignature,
        coreDispatchTotal = tonumber(state.coreDispatch.total) or 0,
        modulesDispatchTotal = tonumber(state.modulesDispatch.total) or 0,
        dockDispatchTotal = tonumber(state.dockDispatch.total) or 0,
        keystoneDispatchTotal = tonumber(state.keystoneDispatch.total) or 0,
        unitCallbacksTotal = tonumber(state.unitCallbacks.total) or 0,
        uiHooksTotal = tonumber(state.uiHooks.total) or 0,
        delayedTimersTotal = tonumber(state.delayedTimers.total) or 0,
        dockOnUpdateTotal = tonumber(state.dockRuntime.onUpdateTickCalls) or 0,
        dockButtonCooldownTotal = tonumber(state.dockRuntime.buttonCooldownTickCalls) or 0,
        moveHintTickTotal = tonumber(state.moveHint.tickCalls) or 0,
        onboardingTickTotal = 0,
        deathPreviewTickTotal = tonumber(state.deathAlerts.previewTickCalls) or 0,
        deathDragTickTotal = tonumber(state.deathAlerts.dragTickCalls) or 0,
        timersEvaluateTotal = tonumber(state.timers.evaluateVisibilityCalls) or 0,
        interruptEvaluateTotal = tonumber(state.interrupt.evaluateVisibilityCalls) or 0,
        interruptUpdateTotal = tonumber(state.interrupt.updateDisplayCalls) or 0,
        interruptInspectTotal = tonumber(state.interrupt.periodicInspectCalls) or 0,
        moduleChatTotal = tonumber(state.moduleEvents.chatMsgAddon) or 0,
        coreGroupRosterTotal = tonumber(state.coreEvents.groupRoster) or 0,
        coreChatTotal = tonumber(state.coreEvents.chat) or 0,
        coreSpellcastTotal = tonumber(state.coreEvents.spellcast) or 0,
    }
end

function PortalAuthority:BuildIdleWitnessDeltaFields(previousSnapshot, currentSnapshot)
    local deltas = {}
    local hasDelta = false
    if type(previousSnapshot) ~= "table" or type(currentSnapshot) ~= "table" then
        return deltas, hasDelta
    end

    for i = 1, #PA_CPUDIAG_IDLE_WITNESS_DELTA_SPECS do
        local spec = PA_CPUDIAG_IDLE_WITNESS_DELTA_SPECS[i]
        local delta = PA_CpuDiagPositiveDelta(currentSnapshot[spec.snapshotKey], previousSnapshot[spec.snapshotKey])
        if delta > 0 then
            deltas[spec.entryKey] = delta
            hasDelta = true
        end
    end

    return deltas, hasDelta
end

function PortalAuthority:BuildIdleWitnessEntry(currentSnapshot, previousSnapshot, reasonTokens, manualLabel)
    if type(currentSnapshot) ~= "table" then
        return nil
    end

    local entry = {
        sessionId = tonumber(currentSnapshot.sessionId) or 0,
        t = tonumber(currentSnapshot.t) or 0,
        u = tonumber(currentSnapshot.u) or 0,
        idleGate = currentSnapshot.idleGate == true,
        unexpectedRuntime = currentSnapshot.unexpectedRuntime == true,
        reason = {},
        settings = currentSnapshot.settings == true,
        resting = currentSnapshot.resting == true,
        instance = currentSnapshot.instance == true,
        combat = currentSnapshot.combat == true,
        dockUnlocked = currentSnapshot.dockUnlocked == true,
        timersUnlocked = currentSnapshot.timersUnlocked == true,
        interruptUnlocked = currentSnapshot.interruptUnlocked == true,
        deathUnlocked = currentSnapshot.deathUnlocked == true,
        dockShown = currentSnapshot.dockShown == true,
        dockOnUpdateArmed = currentSnapshot.dockOnUpdateArmed == true,
        moveHintTicker = currentSnapshot.moveHintTicker == true,
        onboardingTicker = currentSnapshot.onboardingTicker == true,
        deathShown = currentSnapshot.deathShown == true,
        deathPreviewTicker = currentSnapshot.deathPreviewTicker == true,
        deathDragTicker = currentSnapshot.deathDragTicker == true,
        timersShown = currentSnapshot.timersShown == true,
        timersTicker = currentSnapshot.timersTicker == true,
        interruptShown = currentSnapshot.interruptShown == true,
        interruptTicker = currentSnapshot.interruptTicker == true,
        interruptInspectTicker = currentSnapshot.interruptInspectTicker == true,
        keystoneHelperShown = currentSnapshot.keystoneHelperShown == true,
        keystonePollArmed = currentSnapshot.keystonePollArmed == true,
        cooldownActive = tonumber(currentSnapshot.cooldownActive) or 0,
        cooldownOnUpdate = tonumber(currentSnapshot.cooldownOnUpdate) or 0,
        cooldownTextShown = tonumber(currentSnapshot.cooldownTextShown) or 0,
        iconMove = tonumber(currentSnapshot.iconMove) or 0,
        labelMove = tonumber(currentSnapshot.labelMove) or 0,
        labelSettle = tonumber(currentSnapshot.labelSettle) or 0,
        labelAnimActive = tonumber(currentSnapshot.labelAnimActive) or 0,
        settleRunning = currentSnapshot.settleRunning == true,
    }

    if type(manualLabel) == "string" and manualLabel ~= "" then
        entry.manualLabel = manualLabel
    end

    if type(reasonTokens) == "table" then
        for i = 1, #reasonTokens do
            local token = reasonTokens[i]
            if type(token) == "string" and token ~= "" then
                entry.reason[#entry.reason + 1] = token
            end
        end
    end

    local deltaFields = {}
    local hasDelta = false
    if type(previousSnapshot) == "table" then
        deltaFields, hasDelta = self:BuildIdleWitnessDeltaFields(previousSnapshot, currentSnapshot)
    end
    if hasDelta then
        for key, value in pairs(deltaFields) do
            entry[key] = value
        end
    end

    if type(previousSnapshot) == "table" and currentSnapshot.triggerSignature ~= previousSnapshot.triggerSignature and type(currentSnapshot.triggerKey) == "string" and currentSnapshot.triggerKey ~= "" then
        entry.triggerKey = currentSnapshot.triggerKey
        entry.triggerAge = tonumber(currentSnapshot.triggerAge) or 0
    end

    return entry
end

function PortalAuthority:CpuDiagAppendIdleWitnessEntry(reasonTokens, manualLabel)
    if PA_IsStaticBaselineGateEnabled() then
        return false
    end
    local runtime = self:CpuDiagEnsureIdleWitnessSession()
    if type(runtime) ~= "table" or runtime.started ~= true then
        return false
    end

    local currentSnapshot = self:BuildIdleWitnessSnapshot()
    if type(currentSnapshot) ~= "table" then
        return false
    end

    local entry = self:BuildIdleWitnessEntry(currentSnapshot, runtime.previousSnapshot, reasonTokens, manualLabel)
    if type(entry) ~= "table" or (tonumber(entry.sessionId) or 0) <= 0 then
        return false
    end

    local store = PA_CpuDiagEnsureIdleWitnessStore()
    if type(store) ~= "table" then
        return false
    end
    PA_CpuDiagIdleWitnessPushEntry(store, entry)
    for i = 1, #(entry.reason or {}) do
        if entry.reason[i] == "heartbeat" then
            store.lastHeartbeatAt = tonumber(entry.t) or 0
            break
        end
    end
    runtime.previousSnapshot = currentSnapshot
    return true
end

function PortalAuthority:CpuDiagTickIdleWitness()
    if PA_IsStaticBaselineGateEnabled() then
        return false
    end
    local runtime = self._idleWitnessRuntime
    if type(runtime) ~= "table" or runtime.started ~= true then
        return false
    end

    local currentSnapshot = self:BuildIdleWitnessSnapshot()
    if type(currentSnapshot) ~= "table" then
        return false
    end

    local previousSnapshot = runtime.previousSnapshot
    if type(previousSnapshot) ~= "table" then
        runtime.previousSnapshot = currentSnapshot
        return false
    end

    local reasons = {}
    if PA_CpuDiagSnapshotFieldChanged(previousSnapshot, currentSnapshot, PA_CPUDIAG_IDLE_WITNESS_ENV_FIELDS) then
        PA_CpuDiagAddUniqueReason(reasons, "env")
    end
    if PA_CpuDiagSnapshotFieldChanged(previousSnapshot, currentSnapshot, PA_CPUDIAG_IDLE_WITNESS_UNLOCK_FIELDS) then
        PA_CpuDiagAddUniqueReason(reasons, "unlock")
    end
    if PA_CpuDiagSnapshotFieldChanged(previousSnapshot, currentSnapshot, PA_CPUDIAG_IDLE_WITNESS_RUNTIME_FIELDS) then
        PA_CpuDiagAddUniqueReason(reasons, "runtime")
    end
    if PA_CpuDiagSnapshotFieldChanged(previousSnapshot, currentSnapshot, PA_CPUDIAG_IDLE_WITNESS_DOCK_SURFACE_FIELDS) then
        PA_CpuDiagAddUniqueReason(reasons, "dock_surface")
    end
    if previousSnapshot.idleGate ~= currentSnapshot.idleGate then
        PA_CpuDiagAddUniqueReason(reasons, "idle_gate")
    end
    if previousSnapshot.unexpectedRuntime ~= currentSnapshot.unexpectedRuntime then
        PA_CpuDiagAddUniqueReason(reasons, "unexpected_runtime")
    end
    if currentSnapshot.triggerSignature ~= previousSnapshot.triggerSignature and type(currentSnapshot.triggerKey) == "string" and currentSnapshot.triggerKey ~= "" then
        PA_CpuDiagAddUniqueReason(reasons, "trigger")
    end

    local _, hasDelta = self:BuildIdleWitnessDeltaFields(previousSnapshot, currentSnapshot)
    if hasDelta then
        PA_CpuDiagAddUniqueReason(reasons, "delta")
    end

    local store = PA_CpuDiagEnsureIdleWitnessStore()
    if type(store) ~= "table" then
        runtime.previousSnapshot = currentSnapshot
        return false
    end
    local lastEntry = PA_CpuDiagIdleWitnessGetLatestEntryForSession(store, runtime.sessionId)
    local lastAppendedAt = lastEntry and tonumber(lastEntry.t) or nil
    if lastAppendedAt == nil then
        lastAppendedAt = tonumber(runtime.sessionStartedAt) or 0
    end
    if ((tonumber(currentSnapshot.t) or 0) - (tonumber(lastAppendedAt) or 0)) >= PA_CPUDIAG_IDLE_WITNESS_HEARTBEAT_SECONDS then
        PA_CpuDiagAddUniqueReason(reasons, "heartbeat")
    end

    if #reasons <= 0 then
        runtime.previousSnapshot = currentSnapshot
        return false
    end

    local entry = self:BuildIdleWitnessEntry(currentSnapshot, previousSnapshot, reasons, nil)
    if type(entry) ~= "table" or (tonumber(entry.sessionId) or 0) <= 0 then
        runtime.previousSnapshot = currentSnapshot
        return false
    end

    PA_CpuDiagIdleWitnessPushEntry(store, entry)
    for i = 1, #reasons do
        if reasons[i] == "heartbeat" then
            store.lastHeartbeatAt = tonumber(entry.t) or 0
            break
        end
    end
    runtime.previousSnapshot = currentSnapshot
    return true
end

function PortalAuthority:CpuDiagRunIdleWitnessTick()
    if PA_IsStaticBaselineGateEnabled() then
        return false
    end
    local perfStart, perfState = self:PerfBegin("idle_witness_tick")
    local ok, result = pcall(function()
        return self:CpuDiagTickIdleWitness()
    end)
    self:PerfEnd("idle_witness_tick", perfStart, perfState)
    if not ok then
        return false
    end
    return result and true or false
end

function PortalAuthority:CpuDiagEnsureIdleWitnessStarted()
    if PA_IsStaticBaselineGateEnabled() then
        self:CpuDiagStopIdleWitnessTicker()
        return false
    end
    local runtime = self:CpuDiagEnsureIdleWitnessSession()
    if type(runtime) ~= "table" or runtime.started ~= true then
        return false
    end
    if self._idleWitnessTicker ~= nil then
        return true
    end
    if not (C_Timer and C_Timer.NewTicker) then
        return false
    end

    self._idleWitnessTicker = C_Timer.NewTicker(PA_CPUDIAG_IDLE_WITNESS_INTERVAL_SECONDS, function()
        if PortalAuthority and PortalAuthority.CpuDiagRunIdleWitnessTick then
            PortalAuthority:CpuDiagRunIdleWitnessTick()
        end
    end)
    return true
end

function PortalAuthority:CpuDiagScheduleIdleWitnessStart()
    if PA_IsStaticBaselineGateEnabled() then
        self:CpuDiagStopIdleWitnessTicker()
        self._idleWitnessRuntime = nil
        return false
    end
    self:CpuDiagEnsureIdleWitnessSession()
    if self._idleWitnessTicker ~= nil or self._idleWitnessStartScheduled == true then
        return true
    end

    if not (C_Timer and C_Timer.After) then
        return self:CpuDiagEnsureIdleWitnessStarted()
    end

    self._idleWitnessStartScheduled = true
    C_Timer.After(0, function()
        if PortalAuthority and PortalAuthority.CpuDiagEnsureIdleWitnessStarted then
            PortalAuthority._idleWitnessStartScheduled = false
            PortalAuthority:CpuDiagEnsureIdleWitnessStarted()
        end
    end)
    return true
end

function PortalAuthority:BuildCpuDiagIdleWitnessSummary()
    if PA_IsStaticBaselineGateEnabled() then
        return {
            enabled = false,
            disabled = true,
            sessionId = "disabled",
            size = 0,
            capacity = PA_CPUDIAG_IDLE_WITNESS_CAPACITY,
            lastT = "disabled",
            lastU = "disabled",
            uiSurfaceGate = false,
        }
    end

    local store = PA_CpuDiagGetIdleWitnessStoreReadOnly()
    if type(store) ~= "table" then
        return {
            enabled = false,
            disabled = false,
            sessionId = "unknown",
            size = 0,
            capacity = PA_CPUDIAG_IDLE_WITNESS_CAPACITY,
            lastT = "none",
            lastU = "none",
            uiSurfaceGate = false,
            settingsBaselineGate = false,
            settingsEagerBuildGate = false,
            settingsDirectBuildGate = false,
        }
    end

    local sessionId = tonumber(store.sessionId)
    local sessionMeta = PA_CpuDiagGetIdleWitnessSessionMeta(store, sessionId)
    local lastEntry = PA_CpuDiagIdleWitnessGetLatestEntryForSession(store, sessionId)
    local lastT = "none"
    local lastU = "none"
    if type(lastEntry) == "table" then
        lastT = tostring(tonumber(lastEntry.t) or 0)
        lastU = string.format("%.1f", tonumber(lastEntry.u) or 0)
    end

    return {
        enabled = sessionId ~= nil and sessionId > 0,
        disabled = false,
        sessionId = sessionId and tostring(sessionId) or "unknown",
        size = math.max(0, tonumber(store.size) or 0),
        capacity = math.max(1, tonumber(store.capacity) or PA_CPUDIAG_IDLE_WITNESS_CAPACITY),
        lastT = lastT,
        lastU = lastU,
        uiSurfaceGate = sessionMeta and sessionMeta.uiSurfaceGate == true or false,
        settingsBaselineGate = sessionMeta and sessionMeta.settingsBaselineGate == true or false,
        settingsEagerBuildGate = sessionMeta and sessionMeta.settingsEagerBuildGate == true or false,
        settingsDirectBuildGate = sessionMeta and sessionMeta.settingsDirectBuildGate == true or false,
    }
end

local function PA_CpuDiagSnapshotFixedCounter(counter, order)
    local snapshot = {
        total = tonumber(counter and counter.total) or 0,
    }
    for i = 1, #order do
        local key = order[i]
        snapshot[key] = tonumber(counter and counter[key]) or 0
    end
    return snapshot
end

local function PA_CpuDiagSnapshotRecentEntries(entries)
    local snapshot = {}
    for i = 1, #entries do
        local entry = entries[i]
        snapshot[#snapshot + 1] = {
            elapsed = tonumber(entry and entry.elapsed) or 0,
            key = tostring(entry and entry.key or "?"),
            luaKB = entry and entry.luaKB or nil,
            deltaKB = entry and entry.deltaKB or nil,
            settings = entry and entry.settings or nil,
            resting = entry and entry.resting or nil,
            instance = entry and entry.instance or nil,
            combat = entry and entry.combat or nil,
        }
    end
    return snapshot
end

function PortalAuthority:BuildCpuDiagStatusSnapshot()
    local state = self:CpuDiagEnsureState()
    local env = self:BuildCpuDiagEnvSnapshot()
    local memory = self:BuildCpuDiagMemorySnapshot()
    local addonMemory = self:BuildCpuDiagAddonMemorySnapshot()
    local timers = self:BuildCpuDiagTimersSnapshot()
    local interrupt = self:BuildCpuDiagInterruptSnapshot()
    local coreEvents = self:BuildCpuDiagCoreEventSnapshot()
    local keystone = self:BuildCpuDiagKeystoneSnapshot()
    local moveHint = self:BuildCpuDiagMoveHintSnapshot()
    local onboarding = self:BuildCpuDiagOnboardingSnapshot()
    local deathAlerts = self:BuildCpuDiagDeathAlertsSnapshot()
    local releaseGate = self:BuildCpuDiagReleaseGateSnapshot()
    local settingsFirstOpen = self:BuildCpuDiagSettingsFirstOpenSnapshot()
    local dockSurface = self:BuildCpuDiagDockSurfaceSnapshot()
    local idleWitness = self:BuildCpuDiagIdleWitnessSummary()
    local settingsBaselineGate = PA_IsSettingsBaselineGateEnabled()
    local settingsEagerBuildGate = PA_IsSettingsEagerBuildGateEnabled()
    local settingsDirectBuildGate = PA_IsSettingsDirectBuildGateEnabled()
    local keystoneBootstrapState = self:GetSettingsKeystoneBootstrapState()
    local settingsBootstrapActive = self:GetSettingsBootstrapActive()
    local elapsed = math.max(0, (GetTime() or 0) - (state.startedAt or 0))
    local dockOnUpdateArmed = "unknown"
    if self.dockFrame and self.dockFrame.GetScript then
        dockOnUpdateArmed = self.dockFrame:GetScript("OnUpdate") ~= nil
    end
    return {
        elapsed = elapsed,
        env = env,
        memory = memory,
        addonMemory = addonMemory,
        timers = timers,
        interrupt = interrupt,
        coreEvents = coreEvents,
        keystone = keystone,
        moveHint = moveHint,
        onboarding = onboarding,
        deathAlerts = deathAlerts,
        releaseGate = releaseGate,
        settingsFirstOpen = settingsFirstOpen,
        dockSurface = dockSurface,
        idleWitness = idleWitness,
        staticBaselineGate = PA_IsStaticBaselineGateEnabled(),
        settingsBaselineGate = settingsBaselineGate,
        settingsEagerBuildGate = settingsEagerBuildGate,
        settingsDirectBuildGate = settingsDirectBuildGate,
        keystoneBootstrapState = keystoneBootstrapState,
        settingsBootstrapActive = settingsBootstrapActive,
        moduleEvents = {
            unitAura = tonumber(state.moduleEvents.unitAura) or 0,
            unitPowerUpdate = tonumber(state.moduleEvents.unitPowerUpdate) or 0,
            chatMsgAddon = tonumber(state.moduleEvents.chatMsgAddon) or 0,
            other = tonumber(state.moduleEvents.other) or 0,
        },
        coreDispatch = PA_CpuDiagSnapshotFixedCounter(state.coreDispatch, PA_CPUDIAG_CORE_DISPATCH_EVENTS),
        modulesDispatch = PA_CpuDiagSnapshotFixedCounter(state.modulesDispatch, PA_CPUDIAG_MODULES_DISPATCH_EVENTS),
        dockDispatch = PA_CpuDiagSnapshotFixedCounter(state.dockDispatch, PA_CPUDIAG_DOCK_DISPATCH_EVENTS),
        keystoneDispatch = PA_CpuDiagSnapshotFixedCounter(state.keystoneDispatch, PA_CPUDIAG_KEYSTONE_DISPATCH_EVENTS),
        unitCallbacks = PA_CpuDiagSnapshotFixedCounter(state.unitCallbacks, PA_CPUDIAG_UNIT_CALLBACK_EVENTS),
        delayedTimers = PA_CpuDiagSnapshotFixedCounter(state.delayedTimers, PA_CPUDIAG_DELAYED_TIMER_KEYS),
        uiHooks = PA_CpuDiagSnapshotFixedCounter(state.uiHooks, PA_CPUDIAG_UI_HOOK_KEYS),
        triggerCounts = PA_CpuDiagSnapshotFixedCounter(state.triggerCounts, PA_CPUDIAG_TRIGGER_KEYS),
        triggerRecent = PA_CpuDiagSnapshotRecentEntries(PA_CpuDiagGetRingBufferEntriesNewestFirst(state.triggerRecent)),
        dockOnUpdateArmed = dockOnUpdateArmed,
        dockRuntime = {
            onUpdateTickCalls = tonumber(state.dockRuntime and state.dockRuntime.onUpdateTickCalls) or 0,
            buttonCooldownTickCalls = tonumber(state.dockRuntime and state.dockRuntime.buttonCooldownTickCalls) or 0,
        },
        uiSurfaceGate = PA_IsUiSurfaceGateEnabled() or idleWitness.uiSurfaceGate == true,
    }
end

function PortalAuthority:RenderCpuDiagStatusLines(snapshot)
    local env = snapshot and snapshot.env or {}
    local memory = snapshot and snapshot.memory or {}
    local addonMemory = snapshot and snapshot.addonMemory or {}
    local timers = snapshot and snapshot.timers or {}
    local interrupt = snapshot and snapshot.interrupt or {}
    local coreEvents = snapshot and snapshot.coreEvents or {}
    local keystone = snapshot and snapshot.keystone or {}
    local moveHint = snapshot and snapshot.moveHint or {}
    local onboarding = snapshot and snapshot.onboarding or {}
    local deathAlerts = snapshot and snapshot.deathAlerts or {}
    local releaseGate = snapshot and snapshot.releaseGate or {}
    local settingsFirstOpen = snapshot and snapshot.settingsFirstOpen or {}
    local dockSurface = snapshot and snapshot.dockSurface or {}
    local idleWitness = snapshot and snapshot.idleWitness or {}
    local staticBaselineGate = snapshot and snapshot.staticBaselineGate == true or false
    local settingsBaselineGate = snapshot and snapshot.settingsBaselineGate == true or false
    local settingsEagerBuildGate = snapshot and snapshot.settingsEagerBuildGate == true or false
    local settingsDirectBuildGate = snapshot and snapshot.settingsDirectBuildGate == true or false
    local keystoneBootstrapState = snapshot and snapshot.keystoneBootstrapState or "unknown"
    local settingsBootstrapActive = snapshot and snapshot.settingsBootstrapActive or "unknown"
    local elapsed = tonumber(snapshot and snapshot.elapsed) or 0
    local moduleEvents = snapshot and snapshot.moduleEvents or {}
    local coreDispatch = snapshot and snapshot.coreDispatch or {}
    local modulesDispatch = snapshot and snapshot.modulesDispatch or {}
    local dockDispatch = snapshot and snapshot.dockDispatch or {}
    local keystoneDispatch = snapshot and snapshot.keystoneDispatch or {}
    local unitCallbacks = snapshot and snapshot.unitCallbacks or {}
    local delayedTimers = snapshot and snapshot.delayedTimers or {}
    local uiHooks = snapshot and snapshot.uiHooks or {}
    local triggerCounts = snapshot and snapshot.triggerCounts or {}
    local triggerRecent = snapshot and snapshot.triggerRecent or {}
    local dockOnUpdateArmed = snapshot and snapshot.dockOnUpdateArmed or "unknown"
    local dockRuntime = snapshot and snapshot.dockRuntime or {}
    local function boolOrUnknownText(value)
        if value == nil or value == "unknown" then
            return "unknown"
        end
        return PA_CpuDiagBoolText(value)
    end
    local function settingsFirstOpenFlagText(value)
        if value == nil then
            return "n/a"
        end
        if value == "error" then
            return "error"
        end
        return PA_CpuDiagBoolText(value)
    end
    local function summarizeFixedCounter(counter, order)
        local total = tonumber(counter.total) or 0
        if total <= 0 then
            return "none"
        end
        local entries = {}
        for i = 1, #order do
            local key = order[i]
            local count = tonumber(counter[key]) or 0
            if count > 0 then
                entries[#entries + 1] = {
                    key = key,
                    count = count,
                    index = i,
                }
            end
        end
        table.sort(entries, function(left, right)
            if left.count ~= right.count then
                return left.count > right.count
            end
            return left.index < right.index
        end)
        local limit = math.min(6, #entries)
        local parts = {}
        for i = 1, limit do
            parts[#parts + 1] = string.format("%s=%d", tostring(entries[i].key), tonumber(entries[i].count) or 0)
        end
        if #entries > limit then
            parts[#parts + 1] = string.format("+%d more", #entries - limit)
        end
        return table.concat(parts, " ")
    end
    local function triggerFlagText(value)
        if value == nil then
            return "?"
        end
        return PA_CpuDiagBoolText(value)
    end
    local function summarizeRecentTriggers(entries)
        if #entries <= 0 then
            return "none"
        end
        local limit = math.min(6, #entries)
        local parts = {}
        for i = 1, limit do
            local entry = entries[i]
            parts[#parts + 1] = string.format(
                "%.1fs:%s[k=%s d=%s s=%s r=%s i=%s c=%s]",
                tonumber(entry.elapsed) or 0,
                tostring(entry.key or "?"),
                PA_CpuDiagFormatKB(entry.luaKB),
                PA_CpuDiagFormatKB(entry.deltaKB),
                triggerFlagText(entry.settings),
                triggerFlagText(entry.resting),
                triggerFlagText(entry.instance),
                triggerFlagText(entry.combat)
            )
        end
        if #entries > limit then
            parts[#parts + 1] = string.format("+%d more", #entries - limit)
        end
        return table.concat(parts, " ")
    end
    local function summarizeAddonMemoryTopDelta(snapshot)
        if type(snapshot) ~= "table" or snapshot.available ~= true then
            return "unknown"
        end
        if type(snapshot.entries) ~= "table" or #snapshot.entries <= 0 then
            return "none"
        end

        local limit = math.min(4, #snapshot.entries)
        local parts = {}
        for i = 1, limit do
            local entry = snapshot.entries[i]
            local label = tostring(entry.displayName or entry.key or "?")
            local suffix = entry.newSinceReset and "(new)" or ""
            parts[#parts + 1] = string.format(
                "%s=%sKB%s",
                label,
                PA_CpuDiagFormatSignedKB(entry.deltaKB),
                suffix
            )
        end
        if #snapshot.entries > limit then
            parts[#parts + 1] = string.format("+%d more", #snapshot.entries - limit)
        end
        return table.concat(parts, " ")
    end
    local addonMemoryRankText = "unknown"
    if type(addonMemory) == "table" and addonMemory.available == true and type(addonMemory.paRankByDelta) == "number" then
        addonMemoryRankText = tostring(addonMemory.paRankByDelta)
    end
    local lines = {
        string.format("|cffffd100Portal Authority CpuDiag:|r elapsed=%.1fs", elapsed),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r env settings=%s lock=%s resting=%s instance=%s combat=%s",
            boolOrUnknownText(env.settingsVisible),
            tostring(env.lockState or "unknown"),
            boolOrUnknownText(env.resting),
            boolOrUnknownText(env.inInstance),
            boolOrUnknownText(env.inCombat)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r timers override=%s natural=%s effective=%s shown=%s unlocked=%s test=%s ticker=%s eval=%d tick=%d",
            tostring(timers.overrideMode or "NORMAL"),
            PA_CpuDiagBoolText(timers.naturalVisible),
            PA_CpuDiagBoolText(timers.effectiveVisible),
            PA_CpuDiagBoolText(timers.frameShown),
            PA_CpuDiagBoolText(timers.unlocked),
            PA_CpuDiagBoolText(timers.testMode),
            PA_CpuDiagBoolText(timers.tickerActive),
            tonumber(timers.evaluateVisibilityCalls) or 0,
            tonumber(timers.tickCalls) or 0
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r interrupt override=%s natural=%s effective=%s shown=%s unlocked=%s preview=%s ticker=%s inspect=%s eval=%d update=%d periodicInspect=%d",
            tostring(interrupt.overrideMode or "NORMAL"),
            PA_CpuDiagBoolText(interrupt.naturalVisible),
            PA_CpuDiagBoolText(interrupt.effectiveVisible),
            PA_CpuDiagBoolText(interrupt.frameShown),
            PA_CpuDiagBoolText(interrupt.unlocked),
            PA_CpuDiagBoolText(interrupt.previewMode),
            PA_CpuDiagBoolText(interrupt.tickerActive),
            PA_CpuDiagBoolText(interrupt.periodicInspectActive),
            tonumber(interrupt.evaluateVisibilityCalls) or 0,
            tonumber(interrupt.updateDisplayCalls) or 0,
            tonumber(interrupt.periodicInspectCalls) or 0
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r coreDispatch total=%d %s",
            tonumber(coreDispatch.total) or 0,
            summarizeFixedCounter(coreDispatch, PA_CPUDIAG_CORE_DISPATCH_EVENTS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r modulesDispatch total=%d %s",
            tonumber(modulesDispatch.total) or 0,
            summarizeFixedCounter(modulesDispatch, PA_CPUDIAG_MODULES_DISPATCH_EVENTS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r dockDispatch total=%d %s",
            tonumber(dockDispatch.total) or 0,
            summarizeFixedCounter(dockDispatch, PA_CPUDIAG_DOCK_DISPATCH_EVENTS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r keystoneDispatch total=%d %s",
            tonumber(keystoneDispatch.total) or 0,
            summarizeFixedCounter(keystoneDispatch, PA_CPUDIAG_KEYSTONE_DISPATCH_EVENTS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r unitCallbacks total=%d %s",
            tonumber(unitCallbacks.total) or 0,
            summarizeFixedCounter(unitCallbacks, PA_CPUDIAG_UNIT_CALLBACK_EVENTS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r uiHooks total=%d %s",
            tonumber(uiHooks.total) or 0,
            summarizeFixedCounter(uiHooks, PA_CPUDIAG_UI_HOOK_KEYS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r dockRuntime onUpdateArmed=%s onUpdateTick=%d buttonCooldownTick=%d",
            boolOrUnknownText(dockOnUpdateArmed),
            tonumber(dockRuntime.onUpdateTickCalls) or 0,
            tonumber(dockRuntime.buttonCooldownTickCalls) or 0
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r dockSurface shown=%s visibilityDriver=%s entries=%d activeButtons=%d cooldownActive=%d cooldownOnUpdate=%d cooldownTextShown=%d labelShown=%d iconMove=%d labelMove=%d labelSettle=%d labelAnimActive=%d settleRunning=%s",
            PA_CpuDiagBoolText(dockSurface.shown),
            PA_CpuDiagBoolText(dockSurface.visibilityDriver),
            tonumber(dockSurface.entries) or 0,
            tonumber(dockSurface.activeButtons) or 0,
            tonumber(dockSurface.cooldownActive) or 0,
            tonumber(dockSurface.cooldownOnUpdate) or 0,
            tonumber(dockSurface.cooldownTextShown) or 0,
            tonumber(dockSurface.labelShown) or 0,
            tonumber(dockSurface.iconMove) or 0,
            tonumber(dockSurface.labelMove) or 0,
            tonumber(dockSurface.labelSettle) or 0,
            tonumber(dockSurface.labelAnimActive) or 0,
            PA_CpuDiagBoolText(dockSurface.settleRunning)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r delayedTimers total=%d %s",
            tonumber(delayedTimers.total) or 0,
            summarizeFixedCounter(delayedTimers, PA_CPUDIAG_DELAYED_TIMER_KEYS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r memory currentLuaKB=%s startLuaKB=%s deltaFromStartKB=%s trackedMinKB=%s trackedMaxKB=%s trackedSamples=%d largeRiseEvents=%d gcSuspectDrops=%d largestRiseKB=%s largestDropKB=%s",
            PA_CpuDiagFormatKB(memory.currentLuaKB),
            PA_CpuDiagFormatKB(memory.startLuaKB),
            PA_CpuDiagFormatKB(memory.deltaFromStartKB),
            PA_CpuDiagFormatKB(memory.trackedMinKB),
            PA_CpuDiagFormatKB(memory.trackedMaxKB),
            tonumber(memory.trackedSamples) or 0,
            tonumber(memory.largeRiseEvents) or 0,
            tonumber(memory.gcSuspectDrops) or 0,
            PA_CpuDiagFormatKB(memory.largestRiseKB),
            PA_CpuDiagFormatKB(memory.largestDropKB)
        ),
        addonMemory.available == true and string.format(
            "|cffffd100Portal Authority CpuDiag:|r addonMemory paKB=%s paDeltaKB=%s totalAddonKB=%s totalAddonDeltaKB=%s paSharePct=%s paRankByDelta=%s newSinceReset=%s",
            PA_CpuDiagFormatKB(addonMemory.paKB),
            PA_CpuDiagFormatSignedKB(addonMemory.paDeltaKB),
            PA_CpuDiagFormatKB(addonMemory.totalAddonKB),
            PA_CpuDiagFormatSignedKB(addonMemory.totalAddonDeltaKB),
            PA_CpuDiagFormatPct(addonMemory.paSharePct),
            addonMemoryRankText,
            boolOrUnknownText(addonMemory.newSinceReset)
        ) or "|cffffd100Portal Authority CpuDiag:|r addonMemory unknown",
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r addonMemoryTopDelta %s",
            summarizeAddonMemoryTopDelta(addonMemory)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r triggerCounts total=%d %s",
            tonumber(triggerCounts.total) or 0,
            summarizeFixedCounter(triggerCounts, PA_CPUDIAG_TRIGGER_KEYS)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r triggerRecent %s",
            summarizeRecentTriggers(triggerRecent)
        ),
        staticBaselineGate and string.format(
            "|cffffd100Portal Authority CpuDiag:|r idleWitness enabled=%s disabled=true sessionId=%s size=%d capacity=%d lastT=%s lastU=%s",
            PA_CpuDiagBoolText(false),
            tostring(idleWitness.sessionId or "disabled"),
            tonumber(idleWitness.size) or 0,
            tonumber(idleWitness.capacity) or PA_CPUDIAG_IDLE_WITNESS_CAPACITY,
            tostring(idleWitness.lastT or "disabled"),
            tostring(idleWitness.lastU or "disabled")
        ) or string.format(
            "|cffffd100Portal Authority CpuDiag:|r idleWitness enabled=%s sessionId=%s size=%d capacity=%d lastT=%s lastU=%s",
            PA_CpuDiagBoolText(idleWitness.enabled),
            tostring(idleWitness.sessionId or "unknown"),
            tonumber(idleWitness.size) or 0,
            tonumber(idleWitness.capacity) or PA_CPUDIAG_IDLE_WITNESS_CAPACITY,
            tostring(idleWitness.lastT or "none"),
            tostring(idleWitness.lastU or "none")
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r moduleEvents unitAura=%d unitPower=%d chat=%d other=%d",
            tonumber(moduleEvents.unitAura) or 0,
            tonumber(moduleEvents.unitPowerUpdate) or 0,
            tonumber(moduleEvents.chatMsgAddon) or 0,
            tonumber(moduleEvents.other) or 0
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r coreEvents chat=%d groupRoster=%d spellcast=%d other=%d",
            tonumber(coreEvents.chat) or 0,
            tonumber(coreEvents.groupRoster) or 0,
            tonumber(coreEvents.spellcast) or 0,
            tonumber(coreEvents.other) or 0
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r keystone enabled=%s frameShown=%s helperShown=%s pollArmed=%s poll=%d",
            PA_CpuDiagBoolText(keystone.enabled),
            PA_CpuDiagBoolText(keystone.frameShown),
            PA_CpuDiagBoolText(keystone.helperShown),
            PA_CpuDiagBoolText(keystone.pollArmed),
            tonumber(keystone.pollCalls) or 0
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r settingsBootstrap active=%s",
            tostring(settingsBootstrapActive)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r moveHint ticker=%s tick=%d guidedSetupActive=%s",
            PA_CpuDiagBoolText(moveHint.tickerActive),
            tonumber(moveHint.tickCalls) or 0,
            PA_CpuDiagBoolText(onboarding.active)
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r deathAlerts shown=%s test=%s previewTicker=%s previewTick=%d dragTicker=%s dragTick=%d",
            PA_CpuDiagBoolText(deathAlerts.frameShown),
            PA_CpuDiagBoolText(deathAlerts.testMode),
            PA_CpuDiagBoolText(deathAlerts.previewTickerActive),
            tonumber(deathAlerts.previewTickCalls) or 0,
            PA_CpuDiagBoolText(deathAlerts.dragTickerActive),
            tonumber(deathAlerts.dragTickCalls) or 0
        ),
        string.format(
            "|cffffd100Portal Authority CpuDiag:|r releaseGate enabled=%s popupShown=%s onUpdate=%d",
            PA_CpuDiagBoolText(releaseGate.enabled),
            PA_CpuDiagBoolText(releaseGate.popupShown),
            tonumber(releaseGate.onUpdateCalls) or 0
        ),
    }

    local firstOpenHost = settingsFirstOpen and settingsFirstOpen.host or {}
    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority CpuDiag:|r settingsFirstOpenHost selected=%s gen=%d token=%d",
        tostring(firstOpenHost.selectedKey or "none"),
        tonumber(firstOpenHost.selectedGeneration) or 0,
        tonumber(firstOpenHost.selectionToken) or 0
    )
    for i = 1, math.min(type(settingsFirstOpen and settingsFirstOpen.panels) == "table" and #settingsFirstOpen.panels or 0, 8) do
        local panelInfo = settingsFirstOpen.panels[i]
        lines[#lines + 1] = string.format(
            "|cffffd100Portal Authority CpuDiag:|r settingsPanel key=%s init=%s shown=%s selected=%s state=%s gen=%d ready=%s size=%s %dx%d",
            tostring(panelInfo.key or "?"),
            PA_CpuDiagBoolText(panelInfo.initialized),
            PA_CpuDiagBoolText(panelInfo.shown),
            PA_CpuDiagBoolText(panelInfo.selected),
            tostring(panelInfo.state or "missing"),
            tonumber(panelInfo.generation) or 0,
            settingsFirstOpenFlagText(panelInfo.ready),
            PA_CpuDiagBoolText(panelInfo.sizeReady),
            tonumber(panelInfo.sizeW) or 0,
            tonumber(panelInfo.sizeH) or 0
        )
    end

    if settingsBaselineGate then
        table.insert(lines, 2, "|cffffd100Portal Authority CpuDiag:|r settingsBaselineGate=true")
        table.insert(lines, 3, string.format(
            "|cffffd100Portal Authority CpuDiag:|r idleWitness=%s",
            idleWitness.enabled and "enabled" or "disabled"
        ))
    end

    if settingsEagerBuildGate then
        table.insert(lines, 2, "|cffffd100Portal Authority CpuDiag:|r settingsEagerBuildGate=true")
        table.insert(lines, 3, string.format(
            "|cffffd100Portal Authority CpuDiag:|r idleWitness=%s",
            idleWitness.enabled and "enabled" or "disabled"
        ))
    end

    if settingsDirectBuildGate then
        table.insert(lines, 2, "|cffffd100Portal Authority CpuDiag:|r settingsDirectBuildGate=true")
        table.insert(lines, 3, string.format(
            "|cffffd100Portal Authority CpuDiag:|r idleWitness=%s",
            idleWitness.enabled and "enabled" or "disabled"
        ))
        table.insert(lines, 4, string.format(
            "|cffffd100Portal Authority CpuDiag:|r keystoneBootstrap=%s",
            tostring(keystoneBootstrapState)
        ))
    end

    if snapshot and snapshot.uiSurfaceGate == true then
        table.insert(lines, 2, "|cffffd100Portal Authority CpuDiag:|r uiSurfaceGate=true")
    end

    return lines
end

function PortalAuthority:GetCpuDiagStatusLines()
    return self:RenderCpuDiagStatusLines(self:BuildCpuDiagStatusSnapshot())
end

function PortalAuthority:BuildPerfSnapshot()
    local perf = self._perf or {}
    local stats = perf.stats or {}
    local snapshot = {
        enabled = self:PerfIsEnabled(),
        states = {},
    }
    local stateLabels = {}

    for stateLabel, stateStats in pairs(stats) do
        if type(stateStats) == "table" then
            local hasEntries = false
            for _, entry in pairs(stateStats) do
                if type(entry) == "table" and (tonumber(entry.calls) or 0) > 0 then
                    hasEntries = true
                    break
                end
            end
            if hasEntries then
                stateLabels[#stateLabels + 1] = stateLabel
            end
        end
    end

    table.sort(stateLabels, function(left, right)
        local leftRank = PA_PerfStateRank(left)
        local rightRank = PA_PerfStateRank(right)
        if leftRank ~= rightRank then
            return leftRank < rightRank
        end
        return tostring(left) < tostring(right)
    end)

    for _, stateLabel in ipairs(stateLabels) do
        local stateStats = stats[stateLabel]
        local scopes = {}
        local stateTotalMs = 0

        for scopeName, entry in pairs(stateStats) do
            if type(entry) == "table" and (tonumber(entry.calls) or 0) > 0 then
                scopes[#scopes + 1] = scopeName
                stateTotalMs = stateTotalMs + (tonumber(entry.totalMs) or 0)
            end
        end

        table.sort(scopes, function(left, right)
            local leftEntry = stateStats[left] or {}
            local rightEntry = stateStats[right] or {}
            local leftTotal = tonumber(leftEntry.totalMs) or 0
            local rightTotal = tonumber(rightEntry.totalMs) or 0
            if leftTotal ~= rightTotal then
                return leftTotal > rightTotal
            end
            local leftRank = PA_PerfScopeRank(left)
            local rightRank = PA_PerfScopeRank(right)
            if leftRank ~= rightRank then
                return leftRank < rightRank
            end
            return tostring(left) < tostring(right)
        end)

        local stateSnapshot = {
            label = stateLabel,
            totalMs = stateTotalMs,
            scopes = {},
        }
        for _, scopeName in ipairs(scopes) do
            local entry = stateStats[scopeName] or {}
            local calls = tonumber(entry.calls) or 0
            local totalMs = tonumber(entry.totalMs) or 0
            local maxMs = tonumber(entry.maxMs) or 0
            local avgMs = 0
            if calls > 0 then
                avgMs = totalMs / calls
            end
            stateSnapshot.scopes[#stateSnapshot.scopes + 1] = {
                name = scopeName,
                calls = calls,
                totalMs = totalMs,
                avgMs = avgMs,
                maxMs = maxMs,
            }
        end
        snapshot.states[#snapshot.states + 1] = stateSnapshot
    end

    return snapshot
end

function PortalAuthority:RenderPerfSnapshotLines(snapshot)
    local lines = {}
    local states = snapshot and snapshot.states or nil
    if type(states) ~= "table" or #states <= 0 then
        lines[#lines + 1] = "|cffffd100Portal Authority Perf:|r no recorded samples."
        return lines
    end

    lines[#lines + 1] = string.format(
        "|cffffd100Portal Authority Perf:|r dump (%s).",
        snapshot and snapshot.enabled and "enabled" or "disabled"
    )

    for i = 1, #states do
        local stateSnapshot = states[i]
        lines[#lines + 1] = string.format(
            "|cffffd100Portal Authority Perf:|r state=%s total=%.3fms",
            tostring(stateSnapshot and stateSnapshot.label or "?"),
            tonumber(stateSnapshot and stateSnapshot.totalMs) or 0
        )
        local scopes = stateSnapshot and stateSnapshot.scopes or nil
        for j = 1, math.max(0, type(scopes) == "table" and #scopes or 0) do
            local scopeSnapshot = scopes[j]
            lines[#lines + 1] = string.format(
                "|cffffd100Portal Authority Perf:|r   %s calls=%d total=%.3fms avg=%.3fms max=%.3fms",
                tostring(scopeSnapshot and scopeSnapshot.name or "?"),
                tonumber(scopeSnapshot and scopeSnapshot.calls) or 0,
                tonumber(scopeSnapshot and scopeSnapshot.totalMs) or 0,
                tonumber(scopeSnapshot and scopeSnapshot.avgMs) or 0,
                tonumber(scopeSnapshot and scopeSnapshot.maxMs) or 0
            )
        end
    end

    return lines
end

function PortalAuthority:PerfDump()
    for _, line in ipairs(self:RenderPerfSnapshotLines(self:BuildPerfSnapshot()) or {}) do
        print(line)
    end
end

local function sanitizeColor(color, fallback)
    if type(color) ~= "table" then
        return { r = fallback.r, g = fallback.g, b = fallback.b, a = fallback.a }
    end

    return {
        r = clampNumber(color.r, fallback.r, 0, 1),
        g = clampNumber(color.g, fallback.g, 0, 1),
        b = clampNumber(color.b, fallback.b, 0, 1),
        a = clampNumber(color.a, fallback.a, 0, 1),
    }
end

local function migrateTemplateTokens(text)
    if type(text) ~= "string" then
        return text
    end
    return text:gsub("{dest}", "[destination]")
end

function PortalAuthority:NormalizePersistedDockSortMode(db)
    if type(db) ~= "table" then
        self._dockUnexpectedPersistedSortMode = nil
        self._dockUnexpectedPersistedSortModeSource = nil
        return false, nil
    end

    local raw = db.dockSortMode
    local changed = false
    local auditValue = nil
    if raw == nil or raw == "TYPE_ID" then
        db.dockSortMode = "ROW_ORDER"
        changed = true
    elseif raw ~= "ROW_ORDER" then
        auditValue = tostring(raw)
    end

    self._dockUnexpectedPersistedSortMode = auditValue
    self._dockUnexpectedPersistedSortModeSource = auditValue and "PortalAuthorityDB.dockSortMode" or nil

    return changed, auditValue
end

function PortalAuthority:EnsureDB()
    if self.InitializeProfiles and not self._profilesInitialized then
        self:InitializeProfiles()
    end

    local dbWasNil = (PortalAuthorityDB == nil)
    PortalAuthorityDB = PortalAuthorityDB or {}

    local db = PortalAuthorityDB
    local defaults = self.defaults
    local dockV200MigrationTriggered = false
    local dockSortModeChanged = false
    local meta = (self.GetOperationalMeta and self:GetOperationalMeta()) or db

    if meta.dockEnableDefaultsVersion == nil then
        meta.dockEnableDefaultsVersion = DOCK_ENABLE_DEFAULTS_VERSION
        meta.dockEnableDefaultsMigrated = true
        if self._profilesLegacyMigratedThisLoad then
            meta.dockV200NoticePending = true
            dockV200MigrationTriggered = true
        else
            meta.dockV200NoticePending = false
        end
    else
        local storedDockVersion = trim(tostring(meta.dockEnableDefaultsVersion or ""))
        if storedDockVersion == "" or PA_CompareSemver(storedDockVersion, DOCK_ENABLE_DEFAULTS_VERSION) < 0 then
            meta.dockEnableDefaultsVersion = DOCK_ENABLE_DEFAULTS_VERSION
            meta.dockEnableDefaultsMigrated = true
            meta.dockV200NoticePending = true
            dockV200MigrationTriggered = true
        else
            if meta.dockEnableDefaultsMigrated == nil then
                meta.dockEnableDefaultsMigrated = true
            end
            if meta.dockV200NoticePending == nil then
                meta.dockV200NoticePending = false
            end
        end
    end

    if db.announceEnabled == nil then
        db.announceEnabled = defaults.announceEnabled
    end
    if trim(db.announcementText) == "" then
        db.announcementText = defaults.announcementText
    end
    db.announcementText = migrateTemplateTokens(db.announcementText)

    if db.portalsEnabled == nil then
        db.portalsEnabled = db.announceEnabled
    end
    if trim(db.portalsText) == "" then
        db.portalsText = trim(db.announcementText) ~= "" and db.announcementText or defaults.portalsText
    end
    db.portalsText = migrateTemplateTokens(db.portalsText)

    if db.teleportsEnabled == nil then
        db.teleportsEnabled = defaults.teleportsEnabled
    end
    if trim(db.teleportsText) == "" then
        db.teleportsText = defaults.teleportsText
    end
    db.teleportsText = migrateTemplateTokens(db.teleportsText)

    if db.mplusEnabled == nil then
        db.mplusEnabled = defaults.mplusEnabled
    end
    if trim(db.mplusText) == "" then
        db.mplusText = defaults.mplusText
    end
    db.mplusText = migrateTemplateTokens(db.mplusText)

    if db.warlockSummoningEnabled == nil then
        db.warlockSummoningEnabled = defaults.warlockSummoningEnabled
    end
    if trim(db.warlockSummoningText) == "" then
        db.warlockSummoningText = defaults.warlockSummoningText
    end
    db.warlockSummoningText = migrateTemplateTokens(db.warlockSummoningText)

    db.sayWhenSoloEnabled = nil

    if db.summonRequestsEnabled == nil then
        db.summonRequestsEnabled = defaults.summonRequestsEnabled
    end
    if trim(db.summonRequestSoundChannel) == "" then
        db.summonRequestSoundChannel = defaults.summonRequestSoundChannel
    end
    if db.summonRequestSound == nil or trim(db.summonRequestSound) == "" then
        db.summonRequestSound = defaults.summonRequestSound
    end

    if db.summonStoneRequestsEnabled == nil then
        db.summonStoneRequestsEnabled = defaults.summonStoneRequestsEnabled
    end
    if trim(db.summonStoneRequestSoundChannel) == "" then
        db.summonStoneRequestSoundChannel = defaults.summonStoneRequestSoundChannel
    end
    if db.summonStoneRequestSound == nil or trim(db.summonStoneRequestSound) == "" then
        db.summonStoneRequestSound = defaults.summonStoneRequestSound
    end

    if db.keystoneHelperEnabled == nil then
        db.keystoneHelperEnabled = defaults.keystoneHelperEnabled
    end
    if db.keystoneAutoSlotEnabled == nil then
        db.keystoneAutoSlotEnabled = defaults.keystoneAutoSlotEnabled
    end
    if db.keystoneAutoStartEnabled == nil then
        db.keystoneAutoStartEnabled = defaults.keystoneAutoStartEnabled
    end
    if db.pullCommandEnabled == nil then
        db.pullCommandEnabled = defaults.pullCommandEnabled
    end
    if db.pullTimerMethod == nil then
        db.pullTimerMethod = defaults.pullTimerMethod
    end
    if db.pullShortSeconds == nil then
        db.pullShortSeconds = defaults.pullShortSeconds
    end
    if db.pullLongSeconds == nil then
        db.pullLongSeconds = defaults.pullLongSeconds
    end
    if db.releaseGateEnabled == nil then
        db.releaseGateEnabled = defaults.releaseGateEnabled
    end
    if trim(db.releaseGateModifier) == "" then
        db.releaseGateModifier = defaults.releaseGateModifier
    end
    if db.releaseGateHoldSeconds == nil then
        db.releaseGateHoldSeconds = defaults.releaseGateHoldSeconds
    end
    if db.keystoneTooltipDungeonNameMode == nil then
        db.keystoneTooltipDungeonNameMode = defaults.keystoneTooltipDungeonNameMode
    end
    if db.keystoneTooltipRemoveKeystonePrefix == nil then
        db.keystoneTooltipRemoveKeystonePrefix = defaults.keystoneTooltipRemoveKeystonePrefix
    end
    if db.keystoneTooltipLevelMode == nil then
        db.keystoneTooltipLevelMode = defaults.keystoneTooltipLevelMode
    end
    if db.keystoneTooltipLevelAddToName == nil then
        db.keystoneTooltipLevelAddToName = defaults.keystoneTooltipLevelAddToName
    end
    if db.keystoneTooltipResilientMode == nil then
        db.keystoneTooltipResilientMode = defaults.keystoneTooltipResilientMode
    end
    if db.keystoneTooltipSoulboundMode == nil then
        db.keystoneTooltipSoulboundMode = defaults.keystoneTooltipSoulboundMode
    end
    if db.keystoneTooltipUniqueMode == nil then
        db.keystoneTooltipUniqueMode = defaults.keystoneTooltipUniqueMode
    end
    if db.keystoneTooltipAffixesMode == nil then
        db.keystoneTooltipAffixesMode = defaults.keystoneTooltipAffixesMode
    end
    if db.keystoneTooltipAffixesColor == nil then
        db.keystoneTooltipAffixesColor = defaults.keystoneTooltipAffixesColor
    end
    if db.keystoneTooltipDurationMode == nil then
        db.keystoneTooltipDurationMode = defaults.keystoneTooltipDurationMode
    end
    if db.keystoneTooltipRPQuoteMode == nil then
        db.keystoneTooltipRPQuoteMode = defaults.keystoneTooltipRPQuoteMode
    end
    if db.deathAlertTankEnabled == nil then
        db.deathAlertTankEnabled = defaults.deathAlertTankEnabled
    end
    if db.deathAlertTankSound == nil then
        db.deathAlertTankSound = defaults.deathAlertTankSound
    end
    if db.deathAlertTankOnScreen == nil then
        db.deathAlertTankOnScreen = defaults.deathAlertTankOnScreen
    end
    if db.deathAlertHealerEnabled == nil then
        db.deathAlertHealerEnabled = defaults.deathAlertHealerEnabled
    end
    if db.deathAlertHealerSound == nil then
        db.deathAlertHealerSound = defaults.deathAlertHealerSound
    end
    if db.deathAlertHealerOnScreen == nil then
        db.deathAlertHealerOnScreen = defaults.deathAlertHealerOnScreen
    end
    if db.deathAlertDpsEnabled == nil then
        db.deathAlertDpsEnabled = defaults.deathAlertDpsEnabled
    end
    if db.deathAlertDpsSound == nil then
        db.deathAlertDpsSound = defaults.deathAlertDpsSound
    end
    if db.deathAlertDpsOnScreen == nil then
        db.deathAlertDpsOnScreen = defaults.deathAlertDpsOnScreen
    end
    if db.deathAlertSelfEnabled == nil then
        db.deathAlertSelfEnabled = defaults.deathAlertSelfEnabled
    end
    if db.deathAlertSelfSound == nil then
        db.deathAlertSelfSound = defaults.deathAlertSelfSound
    end
    if db.deathAlertSelfOnScreen == nil then
        db.deathAlertSelfOnScreen = defaults.deathAlertSelfOnScreen
    end
    if db.deathAlertMessageTemplate == nil then
        db.deathAlertMessageTemplate = defaults.deathAlertMessageTemplate
    end
    if db.deathAlertLocked == nil then
        db.deathAlertLocked = defaults.deathAlertLocked
    end
    if db.deathAlertX == nil then
        db.deathAlertX = defaults.deathAlertX
    end
    if db.deathAlertY == nil then
        db.deathAlertY = defaults.deathAlertY
    end
    if db.deathAlertFontPath == nil then
        db.deathAlertFontPath = defaults.deathAlertFontPath
    end
    if db.deathAlertFontSize == nil then
        db.deathAlertFontSize = defaults.deathAlertFontSize
    end
    if db.deathAlertSoundChannel == nil then
        db.deathAlertSoundChannel = defaults.deathAlertSoundChannel
    end
    if db.deathAlertShowRoleIcon == nil then
        db.deathAlertShowRoleIcon = defaults.deathAlertShowRoleIcon
    end
    if db.deathAlertAntiSpamWipeEnabled == nil then
        db.deathAlertAntiSpamWipeEnabled = defaults.deathAlertAntiSpamWipeEnabled
    end

    db.keystoneHelperEnabled = PA_SafeBool(db.keystoneHelperEnabled)
    db.keystoneAutoSlotEnabled = PA_SafeBool(db.keystoneAutoSlotEnabled)
    db.keystoneAutoStartEnabled = PA_SafeBool(db.keystoneAutoStartEnabled)
    db.pullCommandEnabled = not not db.pullCommandEnabled
    db.pullTimerMethod = math.floor(PA_Clamp(db.pullTimerMethod, defaults.pullTimerMethod, 1, 3))
    db.pullShortSeconds = math.floor(PA_Clamp(db.pullShortSeconds, defaults.pullShortSeconds, 1, 60))
    db.pullLongSeconds = math.floor(PA_Clamp(db.pullLongSeconds, defaults.pullLongSeconds, 1, 60))
    db.releaseGateEnabled = PA_SafeBool(db.releaseGateEnabled)
    if db.releaseGateModifier ~= "SHIFT" and db.releaseGateModifier ~= "CTRL" then
        db.releaseGateModifier = defaults.releaseGateModifier
    end
    local hold = PA_ToNumber(db.releaseGateHoldSeconds, defaults.releaseGateHoldSeconds)
    db.releaseGateHoldSeconds = PA_Clamp(hold, defaults.releaseGateHoldSeconds, 0.0, 5.0)
    db.keystoneTooltipRemoveKeystonePrefix = PA_SafeBool(db.keystoneTooltipRemoveKeystonePrefix)
    db.keystoneTooltipLevelAddToName = PA_SafeBool(db.keystoneTooltipLevelAddToName)
    if db.keystoneTooltipDungeonNameMode ~= "FULL"
        and db.keystoneTooltipDungeonNameMode ~= "SHORT"
        and db.keystoneTooltipDungeonNameMode ~= "NICKNAME"
        and db.keystoneTooltipDungeonNameMode ~= "NICKNAME_FULL"
        and db.keystoneTooltipDungeonNameMode ~= "NO_CHANGES"
    then
        db.keystoneTooltipDungeonNameMode = defaults.keystoneTooltipDungeonNameMode
    end
    if db.keystoneTooltipLevelMode ~= "PLUS_N"
        and db.keystoneTooltipLevelMode ~= "N"
        and db.keystoneTooltipLevelMode ~= "M_N_PLUS"
        and db.keystoneTooltipLevelMode ~= "HIDE"
        and db.keystoneTooltipLevelMode ~= "NO_CHANGES"
    then
        db.keystoneTooltipLevelMode = defaults.keystoneTooltipLevelMode
    end
    if db.keystoneTooltipResilientMode ~= "HIDE" and db.keystoneTooltipResilientMode ~= "NO_CHANGES" then
        db.keystoneTooltipResilientMode = defaults.keystoneTooltipResilientMode
    end
    if db.keystoneTooltipSoulboundMode ~= "HIDE" and db.keystoneTooltipSoulboundMode ~= "NO_CHANGES" then
        db.keystoneTooltipSoulboundMode = defaults.keystoneTooltipSoulboundMode
    end
    if db.keystoneTooltipUniqueMode ~= "HIDE" and db.keystoneTooltipUniqueMode ~= "NO_CHANGES" then
        db.keystoneTooltipUniqueMode = defaults.keystoneTooltipUniqueMode
    end
    if db.keystoneTooltipAffixesMode ~= "RENAME_AFFIXES"
        and db.keystoneTooltipAffixesMode ~= "HIDE"
        and db.keystoneTooltipAffixesMode ~= "NO_CHANGES"
    then
        db.keystoneTooltipAffixesMode = defaults.keystoneTooltipAffixesMode
    end
    if db.keystoneTooltipDurationMode ~= "HIDE" and db.keystoneTooltipDurationMode ~= "NO_CHANGES" then
        db.keystoneTooltipDurationMode = defaults.keystoneTooltipDurationMode
    end
    if db.keystoneTooltipRPQuoteMode ~= "HIDE" and db.keystoneTooltipRPQuoteMode ~= "NO_CHANGES" then
        db.keystoneTooltipRPQuoteMode = defaults.keystoneTooltipRPQuoteMode
    end
    db.keystoneTooltipAffixesColor = sanitizeColor(db.keystoneTooltipAffixesColor, defaults.keystoneTooltipAffixesColor)
    db.deathAlertTankEnabled = PA_SafeBool(db.deathAlertTankEnabled)
    db.deathAlertTankOnScreen = PA_SafeBool(db.deathAlertTankOnScreen)
    db.deathAlertHealerEnabled = PA_SafeBool(db.deathAlertHealerEnabled)
    db.deathAlertHealerOnScreen = PA_SafeBool(db.deathAlertHealerOnScreen)
    db.deathAlertDpsEnabled = PA_SafeBool(db.deathAlertDpsEnabled)
    db.deathAlertDpsOnScreen = PA_SafeBool(db.deathAlertDpsOnScreen)
    db.deathAlertSelfEnabled = PA_SafeBool(db.deathAlertSelfEnabled)
    db.deathAlertSelfOnScreen = PA_SafeBool(db.deathAlertSelfOnScreen)
    db.deathAlertLocked = PA_SafeBool(db.deathAlertLocked)
    db.deathAlertShowRoleIcon = PA_SafeBool(db.deathAlertShowRoleIcon)
    db.deathAlertAntiSpamWipeEnabled = PA_SafeBool(db.deathAlertAntiSpamWipeEnabled)
    if type(db.deathAlertTankSound) ~= "string" then
        db.deathAlertTankSound = tostring(db.deathAlertTankSound or defaults.deathAlertTankSound)
    end
    if type(db.deathAlertHealerSound) ~= "string" then
        db.deathAlertHealerSound = tostring(db.deathAlertHealerSound or defaults.deathAlertHealerSound)
    end
    if type(db.deathAlertDpsSound) ~= "string" then
        db.deathAlertDpsSound = tostring(db.deathAlertDpsSound or defaults.deathAlertDpsSound)
    end
    if type(db.deathAlertSelfSound) ~= "string" then
        db.deathAlertSelfSound = tostring(db.deathAlertSelfSound or defaults.deathAlertSelfSound)
    end
    db.deathAlertX = math.floor(PA_Clamp(db.deathAlertX, defaults.deathAlertX, -10000, 10000))
    db.deathAlertY = math.floor(PA_Clamp(db.deathAlertY, defaults.deathAlertY, -10000, 10000))
    db.deathAlertFontSize = math.floor(PA_Clamp(db.deathAlertFontSize, defaults.deathAlertFontSize, 8, 72))
    if trim(db.deathAlertFontPath) == "" then
        db.deathAlertFontPath = defaults.deathAlertFontPath
    end
    if not VALID_SOUND_CHANNELS[db.deathAlertSoundChannel] then
        db.deathAlertSoundChannel = defaults.deathAlertSoundChannel
    end
    if trim(db.deathAlertMessageTemplate) == "" then
        db.deathAlertMessageTemplate = defaults.deathAlertMessageTemplate
    end

    if db.dockEnabled == nil then
        db.dockEnabled = defaults.dockEnabled
    end
    if dbWasNil or dockV200MigrationTriggered then
        db.dockEnabled = true
    end

    if db.dockOrientation ~= "VERTICAL" and db.dockOrientation ~= "HORIZONTAL" then
        db.dockOrientation = defaults.dockOrientation
    end
    db.dockX = clampNumber(db.dockX, defaults.dockX)
    db.dockY = clampNumber(db.dockY, defaults.dockY)

    if db.dockLocked == nil then
        db.dockLocked = defaults.dockLocked
    end
    if db.dockHideInMajorCity == nil then
        if db.dockShowInMajorCity ~= nil then
            db.dockHideInMajorCity = not db.dockShowInMajorCity
        else
            db.dockHideInMajorCity = defaults.dockHideInMajorCity
        end
    end
    db.dockShowInMajorCity = nil

    if db.dockHideInDungeon == nil then
        db.dockHideInDungeon = defaults.dockHideInDungeon
    end

    if db.dockHideInCombat == nil then
        db.dockHideInCombat = defaults.dockHideInCombat
    end


    if db.dockGizmoMode == nil then
        db.dockGizmoMode = defaults.dockGizmoMode
    end
    db.dockIconWidth = math.floor(clampNumber(db.dockIconWidth, defaults.dockIconWidth, 16, 128))
    db.dockIconHeight = math.floor(clampNumber(db.dockIconHeight, defaults.dockIconHeight, 16, 128))
    db.dockTextIconSpacing = math.floor(clampNumber(db.dockTextIconSpacing, defaults.dockTextIconSpacing, 0, 40))
    db.dockRowSpacing = math.floor(clampNumber(db.dockRowSpacing, defaults.dockRowSpacing, 0, 40))

    if db.dockHideDungeonName == nil then
        if db.dockShowAcronyms ~= nil then
            db.dockHideDungeonName = not db.dockShowAcronyms
        else
            db.dockHideDungeonName = defaults.dockHideDungeonName
        end
    end
    db.dockShowAcronyms = nil

    if db.dockUseShortNames == nil then
        db.dockUseShortNames = defaults.dockUseShortNames
    end

    if db.dockVerticalTextSide == nil then
        if db.dockTextPosition == "LEFT" or db.dockTextPosition == "RIGHT" then
            db.dockVerticalTextSide = db.dockTextPosition
        else
            db.dockVerticalTextSide = defaults.dockVerticalTextSide
        end
    end
    db.dockTextPosition = nil

    if db.dockVerticalTextSide ~= "LEFT" and db.dockVerticalTextSide ~= "RIGHT" then
        db.dockVerticalTextSide = defaults.dockVerticalTextSide
    end

    if db.dockHorizontalTextPosition ~= "ABOVE" and db.dockHorizontalTextPosition ~= "BELOW" then
        db.dockHorizontalTextPosition = defaults.dockHorizontalTextPosition
    end

    if db.dockOrientation == "HORIZONTAL" then
        db.dockUseShortNames = true
        if db.dockHorizontalTextPosition ~= "ABOVE" and db.dockHorizontalTextPosition ~= "BELOW" then
            db.dockHorizontalTextPosition = defaults.dockHorizontalTextPosition
        end
    else
        if db.dockVerticalTextSide ~= "LEFT" and db.dockVerticalTextSide ~= "RIGHT" then
            db.dockVerticalTextSide = defaults.dockVerticalTextSide
        end
    end

    db.dockFontSize = math.floor(clampNumber(db.dockFontSize, defaults.dockFontSize, 8, 48))
    if db.dockFontPath == nil then
        db.dockFontPath = defaults.dockFontPath
    end
    db.dockFontColor = sanitizeColor(db.dockFontColor, defaults.dockFontColor)

    if not VALID_OUTLINES[db.dockTextOutline] then
        db.dockTextOutline = defaults.dockTextOutline
    end

    if db.dockTextShadow == nil then
        db.dockTextShadow = defaults.dockTextShadow
    end

    db.dockShadowOffsetX = clampNumber(db.dockShadowOffsetX, defaults.dockShadowOffsetX, -10, 10)
    db.dockShadowOffsetY = clampNumber(db.dockShadowOffsetY, defaults.dockShadowOffsetY, -10, 10)

    if db.dockLayoutMode == nil then
        db.dockLayoutMode = defaults.dockLayoutMode
    end
    if db.dockWrapAfter == nil then
        db.dockWrapAfter = defaults.dockWrapAfter
    end
    if db.dockIconSize == nil then
        db.dockIconSize = defaults.dockIconSize
    end
    if db.dockSpacingX == nil then
        db.dockSpacingX = defaults.dockSpacingX
    end
    if db.dockSpacingY == nil then
        db.dockSpacingY = defaults.dockSpacingY
    end
    if db.dockPadding == nil then
        db.dockPadding = defaults.dockPadding
    end
    if db.dockGrowthX == nil then
        db.dockGrowthX = defaults.dockGrowthX
    end
    if db.dockGrowthY == nil then
        db.dockGrowthY = defaults.dockGrowthY
    end
    if db.dockAnchorPoint == nil then
        db.dockAnchorPoint = defaults.dockAnchorPoint
    end
    if db.dockCenterAlignment == nil then
        db.dockCenterAlignment = defaults.dockCenterAlignment
    end
    if db.dockPreferAxis == nil then
        db.dockPreferAxis = defaults.dockPreferAxis
    end
    if db.dockCompactMode == nil then
        db.dockCompactMode = defaults.dockCompactMode
    end
    if db.dockTestMode == nil then
        db.dockTestMode = defaults.dockTestMode
    end
    dockSortModeChanged = select(1, self:NormalizePersistedDockSortMode(db)) or false
    if db.dockAnimateReflow == nil then
        db.dockAnimateReflow = defaults.dockAnimateReflow
    end
    if db.dockAnimateDuration == nil then
        db.dockAnimateDuration = defaults.dockAnimateDuration
    end
    if db.dockBackdropEnabled == nil then
        db.dockBackdropEnabled = defaults.dockBackdropEnabled
    end
    if db.dockInactiveAlpha == nil then
        db.dockInactiveAlpha = defaults.dockInactiveAlpha
    end
    if db.dockHoverGlow == nil then
        db.dockHoverGlow = defaults.dockHoverGlow
    end
    if db.dockSimpleLayoutMode == nil then
        db.dockSimpleLayoutMode = defaults.dockSimpleLayoutMode
    end
    if db.dockIconsPerLine == nil then
        db.dockIconsPerLine = defaults.dockIconsPerLine
    end
    if db.dockIconSpacing == nil then
        db.dockIconSpacing = defaults.dockIconSpacing
    end
    if db.dockDensity == nil then
        db.dockDensity = defaults.dockDensity
    end
    if db.dockTextDirection == nil then
        db.dockTextDirection = defaults.dockTextDirection
    end
    if db.dockTextAlign == nil then
        db.dockTextAlign = defaults.dockTextAlign
    end
    if db.dockLabelAlignMode == nil then
        local direction = string.upper(tostring(db.dockTextDirection or defaults.dockTextDirection or "BOTTOM"))
        if direction ~= "LEFT"
            and direction ~= "TOP"
            and direction ~= "RIGHT"
            and direction ~= "BOTTOM"
            and direction ~= "INNER_TOP"
            and direction ~= "INNER_BOTTOM"
            and direction ~= "CENTER"
        then
            direction = "BOTTOM"
        end
        local align = string.upper(tostring(db.dockTextAlign or defaults.dockTextAlign or "CENTER"))
        if align ~= "LEFT" and align ~= "CENTER" and align ~= "RIGHT" then
            align = "CENTER"
        end
        local alignMode = "CENTER"
        if direction == "LEFT" then
            if align == "RIGHT" then
                alignMode = "HUG"
            elseif align == "LEFT" then
                alignMode = "FLUSH"
            end
        elseif direction == "RIGHT" then
            if align == "LEFT" then
                alignMode = "HUG"
            elseif align == "RIGHT" then
                alignMode = "FLUSH"
            end
        end
        db.dockLabelAlignMode = alignMode
    end
    if db.dockLabelMode == nil then
        if PA_SafeBool(db.dockHideDungeonName) then
            db.dockLabelMode = "OFF"
        else
            db.dockLabelMode = defaults.dockLabelMode or "OUTSIDE"
        end
    end
    if db.dockLabelSide == nil then
        local legacyDirection = string.upper(tostring(db.dockTextDirection or defaults.dockTextDirection or "BOTTOM"))
        if legacyDirection == "TOP" or legacyDirection == "INNER_TOP" then
            db.dockLabelSide = "TOP"
        elseif legacyDirection == "LEFT" then
            db.dockLabelSide = "LEFT"
        elseif legacyDirection == "RIGHT" then
            db.dockLabelSide = "RIGHT"
        else
            db.dockLabelSide = defaults.dockLabelSide or "BOTTOM"
        end
    end
    if db.dockLabelModePersist == nil then
        db.dockLabelModePersist = db.dockLabelMode or defaults.dockLabelMode or "OUTSIDE"
    end
    if db.dockLabelSidePersist == nil then
        db.dockLabelSidePersist = db.dockLabelSide or defaults.dockLabelSide or "BOTTOM"
    end
    if db.dockLabelSideOutsidePersist == nil then
        if db.dockLabelSide == "BOTTOM" or db.dockLabelSide == "TOP" or db.dockLabelSide == "LEFT" or db.dockLabelSide == "RIGHT" then
            db.dockLabelSideOutsidePersist = db.dockLabelSide
        elseif db.dockLabelSidePersist == "BOTTOM" or db.dockLabelSidePersist == "TOP" or db.dockLabelSidePersist == "LEFT" or db.dockLabelSidePersist == "RIGHT" then
            db.dockLabelSideOutsidePersist = db.dockLabelSidePersist
        else
            db.dockLabelSideOutsidePersist = defaults.dockLabelSideOutsidePersist or defaults.dockLabelSide or "BOTTOM"
        end
    end
    if db.dockTextOffset == nil then
        db.dockTextOffset = defaults.dockTextOffset
    end
    if db.dockHoverGlowAlpha == nil then
        db.dockHoverGlowAlpha = defaults.dockHoverGlowAlpha
    end
    if db.dockHoverGlowSize == nil then
        db.dockHoverGlowSize = defaults.dockHoverGlowSize
    end

    if db.dockLayoutMode ~= "MANUAL_GRID" and db.dockLayoutMode ~= "ADAPTIVE_GRID" then
        db.dockLayoutMode = defaults.dockLayoutMode
    end
    if db.dockPreferAxis ~= "AUTO" and db.dockPreferAxis ~= "HORIZONTAL" and db.dockPreferAxis ~= "VERTICAL" then
        db.dockPreferAxis = defaults.dockPreferAxis
    end
    if db.dockSimpleLayoutMode ~= "HORIZONTAL_ROW"
        and db.dockSimpleLayoutMode ~= "VERTICAL_COLUMN"
        and db.dockSimpleLayoutMode ~= "GRID"
    then
        db.dockSimpleLayoutMode = defaults.dockSimpleLayoutMode
    end
    if db.dockTextDirection ~= "LEFT"
        and db.dockTextDirection ~= "TOP"
        and db.dockTextDirection ~= "RIGHT"
        and db.dockTextDirection ~= "BOTTOM"
        and db.dockTextDirection ~= "INNER_TOP"
        and db.dockTextDirection ~= "INNER_BOTTOM"
        and db.dockTextDirection ~= "CENTER"
    then
        db.dockTextDirection = defaults.dockTextDirection
    end
    if db.dockTextAlign ~= "LEFT" and db.dockTextAlign ~= "CENTER" and db.dockTextAlign ~= "RIGHT" then
        db.dockTextAlign = defaults.dockTextAlign
    end
    if db.dockLabelAlignMode ~= "HUG" and db.dockLabelAlignMode ~= "CENTER" and db.dockLabelAlignMode ~= "FLUSH" then
        db.dockLabelAlignMode = defaults.dockLabelAlignMode or "CENTER"
    end
    if db.dockLabelMode == false then
        db.dockLabelMode = "OFF"
    elseif db.dockLabelMode == true then
        db.dockLabelMode = "OUTSIDE"
    end
    if db.dockLabelModePersist == false then
        db.dockLabelModePersist = "OFF"
    elseif db.dockLabelModePersist == true then
        db.dockLabelModePersist = "OUTSIDE"
    end
    if db.dockLabelMode ~= "OFF" and db.dockLabelMode ~= "OUTSIDE" and db.dockLabelMode ~= "INSIDE" then
        db.dockLabelMode = defaults.dockLabelMode or "OUTSIDE"
    end
    -- If either label mode key is OFF, treat portal names as hidden to avoid reload drift.
    if db.dockLabelMode == "OFF" or db.dockLabelModePersist == "OFF" then
        db.dockHideDungeonName = true
    end
    if db.dockLabelModePersist ~= "OFF" and db.dockLabelModePersist ~= "OUTSIDE" and db.dockLabelModePersist ~= "INSIDE" then
        db.dockLabelModePersist = db.dockLabelMode or defaults.dockLabelMode or "OUTSIDE"
    end
    if db.dockLabelSide ~= "BOTTOM" and db.dockLabelSide ~= "TOP" and db.dockLabelSide ~= "LEFT" and db.dockLabelSide ~= "RIGHT" and db.dockLabelSide ~= "CENTER" then
        db.dockLabelSide = defaults.dockLabelSide or "BOTTOM"
    end
    -- Label mode OFF is equivalent to hiding portal names; keep these in sync for deterministic reload behavior.
    if PA_SafeBool(db.dockHideDungeonName) then
        db.dockLabelMode = "OFF"
        db.dockLabelModePersist = "OFF"
    end
    if db.dockLabelSidePersist ~= "BOTTOM" and db.dockLabelSidePersist ~= "TOP" and db.dockLabelSidePersist ~= "LEFT" and db.dockLabelSidePersist ~= "RIGHT" and db.dockLabelSidePersist ~= "CENTER" then
        db.dockLabelSidePersist = db.dockLabelSide or defaults.dockLabelSide or "BOTTOM"
    end
    if db.dockLabelSideOutsidePersist ~= "BOTTOM"
        and db.dockLabelSideOutsidePersist ~= "TOP"
        and db.dockLabelSideOutsidePersist ~= "LEFT"
        and db.dockLabelSideOutsidePersist ~= "RIGHT"
    then
        if db.dockLabelSide == "BOTTOM" or db.dockLabelSide == "TOP" or db.dockLabelSide == "LEFT" or db.dockLabelSide == "RIGHT" then
            db.dockLabelSideOutsidePersist = db.dockLabelSide
        elseif db.dockLabelSidePersist == "BOTTOM" or db.dockLabelSidePersist == "TOP" or db.dockLabelSidePersist == "LEFT" or db.dockLabelSidePersist == "RIGHT" then
            db.dockLabelSideOutsidePersist = db.dockLabelSidePersist
        else
            db.dockLabelSideOutsidePersist = defaults.dockLabelSideOutsidePersist or defaults.dockLabelSide or "BOTTOM"
        end
    end
    -- Keep live and persisted label controls in lockstep so settings visuals cannot drift on reload.
    -- If either key is OFF, OFF wins so user intent cannot be lost by stale mismatch.
    if db.dockLabelMode == "OFF" or db.dockLabelModePersist == "OFF" then
        db.dockLabelMode = "OFF"
        db.dockLabelModePersist = "OFF"
    else
        db.dockLabelModePersist = db.dockLabelMode
    end
    db.dockLabelSidePersist = db.dockLabelSide
    if db.dockGrowthX ~= "RIGHT" and db.dockGrowthX ~= "LEFT" then
        db.dockGrowthX = defaults.dockGrowthX
    end
    if db.dockGrowthY ~= "DOWN" and db.dockGrowthY ~= "UP" then
        db.dockGrowthY = defaults.dockGrowthY
    end
    if db.dockAnchorPoint ~= "TOPLEFT"
        and db.dockAnchorPoint ~= "TOP"
        and db.dockAnchorPoint ~= "TOPRIGHT"
        and db.dockAnchorPoint ~= "LEFT"
        and db.dockAnchorPoint ~= "CENTER"
        and db.dockAnchorPoint ~= "RIGHT"
        and db.dockAnchorPoint ~= "BOTTOMLEFT"
        and db.dockAnchorPoint ~= "BOTTOM"
        and db.dockAnchorPoint ~= "BOTTOMRIGHT"
    then
        db.dockAnchorPoint = defaults.dockAnchorPoint
    end

    db.dockWrapAfter = math.floor(PA_Clamp(db.dockWrapAfter, defaults.dockWrapAfter, 1, 10))
    db.dockIconSize = math.floor(PA_Clamp(db.dockIconSize, defaults.dockIconSize, 16, 64))
    db.dockSpacingX = math.floor(PA_Clamp(db.dockSpacingX, defaults.dockSpacingX, -600, 160))
    db.dockSpacingY = math.floor(PA_Clamp(db.dockSpacingY, defaults.dockSpacingY, -200, 200))
    db.dockPadding = math.floor(PA_Clamp(db.dockPadding, defaults.dockPadding, 0, 40))
    db.dockIconsPerLine = math.floor(PA_Clamp(db.dockIconsPerLine, defaults.dockIconsPerLine, 1, 10))
    db.dockIconSpacing = math.floor(PA_Clamp(db.dockIconSpacing, defaults.dockIconSpacing, 0, 40))
    db.dockDensity = math.floor(PA_Clamp(db.dockDensity, defaults.dockDensity, 0, 100))
    db.dockTextOffset = math.floor(PA_Clamp(db.dockTextOffset, defaults.dockTextOffset, -30, 30))
    db.dockInactiveAlpha = PA_Clamp(db.dockInactiveAlpha, defaults.dockInactiveAlpha, 0.1, 1.0)
    db.dockAnimateDuration = PA_Clamp(db.dockAnimateDuration, defaults.dockAnimateDuration, 0.05, 0.5)
    db.dockHoverGlowAlpha = PA_Clamp(db.dockHoverGlowAlpha, defaults.dockHoverGlowAlpha, 0.0, 1.0)
    db.dockHoverGlowSize = math.floor(PA_Clamp(db.dockHoverGlowSize, defaults.dockHoverGlowSize, 0, 20))
    db.dockCenterAlignment = PA_SafeBool(db.dockCenterAlignment)
    db.dockCompactMode = PA_SafeBool(db.dockCompactMode)
    db.dockTestMode = PA_SafeBool(db.dockTestMode)
    db.dockAnimateReflow = PA_SafeBool(db.dockAnimateReflow)
    db.dockBackdropEnabled = PA_SafeBool(db.dockBackdropEnabled)
    db.dockHoverGlow = PA_SafeBool(db.dockHoverGlow)
    db.dockGizmoMode = PA_SafeBool(db.dockGizmoMode)

    -- Keep legacy fields initialized, but preserve explicit X/Y spacing when set.
    db.dockWrapAfter = db.dockIconsPerLine
    if db.dockSpacingX == nil then
        db.dockSpacingX = db.dockIconSpacing
    end
    if db.dockSpacingY == nil then
        db.dockSpacingY = db.dockIconSpacing
    end

    local function buildDockSeedSlots()
        local slots = {}
        local dungeons = (self.GetDefaultMPlusDockPresetDungeons and self:GetDefaultMPlusDockPresetDungeons()) or {}
        for i = 1, 10 do
            local dungeon = dungeons[i]
            local spellID = dungeon and math.floor(tonumber(dungeon.spellID) or 0) or 0
            if spellID > 0 then
                slots[i] = {
                    enabled = true,
                    selection = tostring(spellID),
                    spellID = spellID,
                    name = tostring(dungeon.dest or ""),
                }
            else
                slots[i] = {
                    enabled = false,
                    selection = "CUSTOM",
                    spellID = 0,
                    name = "",
                }
            end
        end
        return slots
    end

    if type(db.dockSlots) ~= "table" or #db.dockSlots == 0 then
        db.dockSlots = buildDockSeedSlots()
    end
    for i = 1, 10 do
        local slot = db.dockSlots[i]
        if type(slot) ~= "table" then
            slot = {}
            db.dockSlots[i] = slot
        end
        if slot.enabled == nil then
            slot.enabled = false
        end
        if slot.selection == nil or slot.selection == "" then
            if tonumber(slot.spellID) and tonumber(slot.spellID) > 0 then
                slot.selection = tostring(math.floor(tonumber(slot.spellID) or 0))
            else
                slot.selection = "CUSTOM"
            end
        end
        if slot.spellID == nil then
            slot.spellID = 0
        end
        if slot.name == nil then
            slot.name = ""
        end

        slot.enabled = PA_SafeBool(slot.enabled)
        slot.selection = tostring(slot.selection or "CUSTOM")
        slot.spellID = math.floor(tonumber(slot.spellID) or 0)
        if slot.spellID < 0 then
            slot.spellID = 0
        end
        slot.name = tostring(slot.name or "")
    end
    for i = #db.dockSlots, 11, -1 do
        db.dockSlots[i] = nil
    end

    db.modules = db.modules or {}
    db.modules.brezTimer = db.modules.brezTimer or {}

    local brezDefaults = defaults.modules and defaults.modules.brezTimer or {}
    local brezDB = db.modules.brezTimer
    if brezDB.enabled == nil then
        brezDB.enabled = brezDefaults.enabled ~= false
    end
    brezDB.x = math.floor(clampNumber(brezDB.x, brezDefaults.x or 0))
    brezDB.y = math.floor(clampNumber(brezDB.y, brezDefaults.y or 0))

    if trim(brezDB.textFormat) == "" then
        brezDB.textFormat = brezDefaults.textFormat or "{mm}:{ss}"
    end

    if brezDB.timeFormatMode ~= "mmss" and brezDB.timeFormatMode ~= "mmsscc" then
        brezDB.timeFormatMode = brezDefaults.timeFormatMode or "mmss"
    end

    if brezDB.font == nil then
        brezDB.font = brezDefaults.font or ""
    end

    brezDB.fontSize = math.floor(clampNumber(brezDB.fontSize, brezDefaults.fontSize or 14, 8, 48))
    brezDB.color = sanitizeColor(brezDB.color, brezDefaults.color or { r = 1, g = 1, b = 1, a = 1 })

    if trim(brezDB.label1Text) == "" then
        brezDB.label1Text = brezDefaults.label1Text or "Battle Rez"
    end
    if trim(brezDB.label2Text) == "" then
        brezDB.label2Text = brezDefaults.label2Text or "Next In"
    end

    brezDB.label1Font = trim(brezDB.label1Font)
    brezDB.label2Font = trim(brezDB.label2Font)
    brezDB.valueFont = trim(brezDB.valueFont)
    if brezDB.valueFont == "" then
        brezDB.valueFont = brezDB.font or brezDefaults.valueFont or brezDefaults.font or ""
    end

    local fallbackFontSize = brezDB.fontSize or brezDefaults.fontSize or 14
    brezDB.label1FontSize = math.floor(clampNumber(brezDB.label1FontSize, fallbackFontSize, 8, 48))
    brezDB.label2FontSize = math.floor(clampNumber(brezDB.label2FontSize, fallbackFontSize, 8, 48))
    brezDB.valueFontSize = math.floor(clampNumber(brezDB.valueFontSize, fallbackFontSize, 8, 48))

    local legacyValue1 = sanitizeColor(brezDB.value1Color, brezDefaults.value1Color or brezDB.color or { r = 1, g = 1, b = 1, a = 1 })
    local legacyValue2 = sanitizeColor(brezDB.value2Color, brezDefaults.value2Color or brezDB.color or { r = 1, g = 1, b = 1, a = 1 })

    brezDB.label1Color = sanitizeColor(brezDB.label1Color, brezDB.color or brezDefaults.label1Color or { r = 1, g = 1, b = 1, a = 1 })
    brezDB.label2Color = sanitizeColor(brezDB.label2Color, brezDB.color or brezDefaults.label2Color or { r = 1, g = 1, b = 1, a = 1 })
    brezDB.valueColor = sanitizeColor(brezDB.valueColor, legacyValue1 or legacyValue2 or brezDB.color or brezDefaults.valueColor or { r = 1, g = 1, b = 1, a = 1 })

    brezDB.value1Color = sanitizeColor(legacyValue1, brezDB.valueColor)
    brezDB.value2Color = sanitizeColor(legacyValue2, brezDB.valueColor)

    if dockSortModeChanged and self.dockFrame and self.RebuildDock then
        if InCombatLockdown and InCombatLockdown() then
            if self.QueueDockUpdate then
                self:QueueDockUpdate()
            end
        else
            self:RebuildDock(false)
        end
    end

end

function PortalAuthority:GetGlobalFontPath()
    local _, _, fontFlags = GameFontNormal:GetFont()
    local fontPath = trim(STANDARD_TEXT_FONT or "")
    if fontPath == "" then
        fontPath = select(1, GameFontNormal:GetFont())
    end
    if trim(fontPath) == "" then
        fontPath = BUILTIN_FONT_FALLBACK
    end
    return fontPath, fontFlags or ""
end

function PortalAuthority:GetPremiumAuthoredFontPath()
    return PortalAuthority._buildConfig.release.premiumAuthoredFontPath
end

function PortalAuthority:GetPremiumAuthoredFontName()
    return PortalAuthority._buildConfig.release.premiumAuthoredFontName
end

function PortalAuthority:ApplyPremiumAuthoredFont(object, size, flags)
    if not object or not object.SetFont then
        return
    end

    local fontPath = self:GetPremiumAuthoredFontPath()
    local currentSize = select(2, object:GetFont())
    object:SetFont(fontPath, size or currentSize or 12, flags or "")
end

function PortalAuthority:GetMageClassColorCode()
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS.MAGE
    if color and color.colorStr then
        return "|c" .. color.colorStr
    end
    return "|cff3fc7eb"
end

function PortalAuthority:ShowLoginMessage()
    local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
    if not chatFrame or not chatFrame.AddMessage then
        return
    end

    local addonName = "|cffE88BC7Portal Authority|r"
    chatFrame:AddMessage(string.format("%s %s", addonName, PLAYER_LOGIN_MESSAGE))
end

function PortalAuthority:ShowDockV200MigrationNotice()
    local meta = (self.GetOperationalMeta and self:GetOperationalMeta()) or PortalAuthorityDB
    if not meta or not PA_SafeBool(meta.dockV200NoticePending) then
        return
    end

    meta.dockV200NoticePending = false

    local chatFrame = DEFAULT_CHAT_FRAME or ChatFrame1
    local msg = "|cffE88BC7Portal Authority:|r Mythic+ Dock has been enabled by default in v2.0.0."
    if chatFrame and chatFrame.AddMessage then
        chatFrame:AddMessage(msg)
    else
        print(msg)
    end
end

local function PA_PrintPortalAuthorityMessage(message)
    print("|cffE88BC7Portal Authority:|r " .. tostring(message or ""))
end

local function PA_IsPremiumWelcomeVisible(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function PA_EnsureSpecialFrame(name)
    if type(name) ~= "string" or name == "" or type(UISpecialFrames) ~= "table" then
        return
    end
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == name then
            return
        end
    end
    table.insert(UISpecialFrames, name)
end

local function PA_StopFrameAnimation(owner)
    if owner and owner.SetScript then
        owner:SetScript("OnUpdate", nil)
    end
end

local function PA_EaseInOut(progress)
    progress = math.max(0, math.min(1, progress or 0))
    return progress * progress * (3 - (2 * progress))
end

local function PA_StartAlphaTween(owner, tokenHolder, tokenField, fromAlpha, toAlpha, duration, onFinished)
    if not owner or not tokenHolder then
        return
    end

    tokenHolder[tokenField] = (tonumber(tokenHolder[tokenField]) or 0) + 1
    local token = tokenHolder[tokenField]
    local elapsed = 0

    owner:SetAlpha(fromAlpha)
    owner:SetScript("OnUpdate", function(self, delta)
        if tokenHolder[tokenField] ~= token then
            self:SetScript("OnUpdate", nil)
            return
        end

        elapsed = elapsed + (delta or 0)
        local progress = duration > 0 and PA_EaseInOut(elapsed / duration) or 1
        self:SetAlpha(fromAlpha + ((toAlpha - fromAlpha) * progress))
        if progress >= 1 then
            self:SetAlpha(toAlpha)
            self:SetScript("OnUpdate", nil)
            if onFinished then
                onFinished(self)
            end
        end
    end)
end

local function PA_FocusOverclockLinkPopup(popup)
    if not popup or not popup.editBox then
        return
    end
    popup.editBox:SetText(PortalAuthority._buildConfig.release.overclockWarcraftLogsUrl)
    popup.editBox:SetCursorPosition(0)
    popup.editBox:SetFocus()
    popup.editBox:HighlightText()
end

function PortalAuthority:EnsureOverclockLinkPopupFrame()
    local popup = self._overclockLinkPopupFrame
    if popup then
        return popup
    end

    local function applyPopupPremiumFont(object, fallbackSize)
        if not object or not object.GetFont or type(self.ApplyPremiumAuthoredFont) ~= "function" then
            return
        end
        local _, fontSize, fontFlags = object:GetFont()
        self:ApplyPremiumAuthoredFont(object, fontSize or fallbackSize or 12, fontFlags or "")
    end

    popup = CreateFrame("Frame", "PortalAuthorityOverclockLinkFrame", UIParent, "BackdropTemplate")
    self._overclockLinkPopupFrame = popup
    popup:SetSize(420, 152)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 12)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(140)
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetMovable(false)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.06, 0.07, 0.09, 0.97)
    popup:SetBackdropBorderColor(0.26, 0.29, 0.34, 1.0)
    popup:Hide()
    if popup.GetName and popup:GetName() then
        table.insert(UISpecialFrames, popup:GetName())
    end
    popup:SetScript("OnMouseDown", function() end)

    local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOP", popup, "TOP", 0, -14)
    title:SetTextColor(1.0, 0.82, 0.0, 1.0)
    title:SetText("Overclock - Warcraft Logs")
    applyPopupPremiumFont(title, 13)
    popup._title = title

    local helper = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    helper:SetPoint("TOP", title, "BOTTOM", 0, -6)
    helper:SetTextColor(0.74, 0.74, 0.78, 1.0)
    helper:SetText("Ctrl+C to copy")
    applyPopupPremiumFont(helper, 11)
    popup._helper = helper

    local editBackdrop = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    editBackdrop:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -52)
    editBackdrop:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -20, -52)
    editBackdrop:SetHeight(30)
    editBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    editBackdrop:SetBackdropColor(0.10, 0.11, 0.14, 0.96)
    editBackdrop:SetBackdropBorderColor(0.24, 0.27, 0.32, 1.0)
    popup._editBackdrop = editBackdrop

    local editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    editBox:SetAutoFocus(false)
    editBox:SetMultiLine(false)
    editBox:SetMaxLetters(255)
    editBox:SetPoint("TOPLEFT", editBackdrop, "TOPLEFT", 6, -5)
    editBox:SetPoint("BOTTOMRIGHT", editBackdrop, "BOTTOMRIGHT", -6, 5)
    editBox:SetTextInsets(0, 0, 0, 0)
    editBox:SetTextColor(0.95, 0.95, 0.97, 1.0)
    applyPopupPremiumFont(editBox, 12)
    editBox:SetScript("OnEscapePressed", function(selfEdit)
        local owner = selfEdit and selfEdit._ownerPopup or nil
        if owner and owner.Hide then
            owner:Hide()
        end
    end)
    editBox:SetScript("OnEnterPressed", function(selfEdit)
        selfEdit:HighlightText()
    end)
    editBox:SetScript("OnEditFocusGained", function(selfEdit)
        selfEdit:HighlightText()
    end)
    editBox._ownerPopup = popup
    popup.editBox = editBox

    local closeButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    closeButton:SetSize(96, 22)
    closeButton:SetPoint("BOTTOM", popup, "BOTTOM", 0, 14)
    closeButton:SetText(CLOSE or "Close")
    closeButton:SetScript("OnClick", function()
        popup:Hide()
    end)
    applyPopupPremiumFont(closeButton.Text or (closeButton.GetFontString and closeButton:GetFontString()) or nil, 11)
    popup._closeButton = closeButton

    popup:SetScript("OnShow", function(frame)
        PA_FocusOverclockLinkPopup(frame)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if frame and frame:IsShown() then
                    PA_FocusOverclockLinkPopup(frame)
                end
            end)
        end
    end)

    popup:SetScript("OnHide", function(frame)
        if frame and frame.editBox then
            frame.editBox:ClearFocus()
        end
    end)

    return popup
end

function PortalAuthority:ShowOverclockLinkPopup()
    local popup = self:EnsureOverclockLinkPopupFrame()
    if not popup then
        return false
    end
    popup:Show()
    if popup.Raise then
        popup:Raise()
    end
    PA_FocusOverclockLinkPopup(popup)
    return true
end

function PortalAuthority:HideQualifyingUpgradeAnnouncementPopup()
    return self:_HideQualifyingUpgradeAnnouncementPopupNonConsuming("manual-hide")
end

function PortalAuthority:_IsQualifyingUpgradeAnnouncementPopupTeardownSuppressed()
    return self._qualifyingUpgradeAnnouncementTeardownSuppressed == true
end

function PortalAuthority:_IsQualifyingUpgradeAnnouncementPopupNonConsumingHideSuppressed()
    return (tonumber(self._qualifyingUpgradeAnnouncementNonConsumingHideDepth) or 0) > 0
end

function PortalAuthority:_WithSuppressedQualifyingUpgradeAnnouncementPopupFinalize(callback)
    if type(callback) ~= "function" then
        return false, "Popup suppression callback is unavailable."
    end

    self._qualifyingUpgradeAnnouncementNonConsumingHideDepth =
        (tonumber(self._qualifyingUpgradeAnnouncementNonConsumingHideDepth) or 0) + 1

    local results = { pcall(callback) }

    self._qualifyingUpgradeAnnouncementNonConsumingHideDepth =
        math.max((tonumber(self._qualifyingUpgradeAnnouncementNonConsumingHideDepth) or 1) - 1, 0)

    local ok = table.remove(results, 1)
    if not ok then
        error(results[1])
    end
    return unpack(results)
end

function PortalAuthority:_HideQualifyingUpgradeAnnouncementPopupNonConsuming(reason)
    local popup = self._qualifyingUpgradeAnnouncementPopupFrame
    if not PA_IsPremiumWelcomeVisible(popup) then
        return false
    end

    local ok, err = self:_WithSuppressedQualifyingUpgradeAnnouncementPopupFinalize(function()
        popup._paAllowOnHideFinalize = false
        popup:Hide()
    end)

    if popup then
        popup._paLiveVisibleSession = nil
        popup._paAllowOnHideFinalize = nil
    end

    if ok == false then
        return false, err or reason or "non-consuming-hide-failed"
    end
    return true, reason or "non-consuming-hide"
end

function PortalAuthority:_HideQualifyingUpgradeAnnouncementPopupForSetup()
    return self:_HideQualifyingUpgradeAnnouncementPopupNonConsuming("setup-hide")
end

function PortalAuthority:_FinalizeQualifyingUpgradeAnnouncementPopup(reason, opts)
    opts = type(opts) == "table" and opts or {}
    local popup = self._qualifyingUpgradeAnnouncementPopupFrame
    local openSettings = opts.openSettings == true
    local alreadyHidden = opts.alreadyHidden == true

    if popup and popup._paDismissFinalized ~= true then
        popup._paDismissFinalized = true
        popup._paAllowOnHideFinalize = false
        popup._paLiveVisibleSession = nil
        self:MarkQualifyingUpgradeWelcomeSatisfiedIfPending()
    end

    if not alreadyHidden and PA_IsPremiumWelcomeVisible(popup) then
        popup:Hide()
    end

    if openSettings then
        return self:OpenPrimarySettingsEntry("qualifying-upgrade-popup-open")
    end
    return true, reason or "dismissed"
end

function PortalAuthority:DismissQualifyingUpgradeAnnouncementPopup(reason)
    return self:_FinalizeQualifyingUpgradeAnnouncementPopup(reason or "dismissed", {
        openSettings = false,
        alreadyHidden = false,
    })
end

function PortalAuthority:OpenSettingsFromQualifyingUpgradeAnnouncement()
    return self:_FinalizeQualifyingUpgradeAnnouncementPopup("open-settings", {
        openSettings = true,
        alreadyHidden = false,
    })
end

function PortalAuthority:EnsureQualifyingUpgradeAnnouncementPopupFrame()
    local popup = self._qualifyingUpgradeAnnouncementPopupFrame
    if popup then
        return popup
    end

    popup = CreateFrame("Frame", "PortalAuthorityQualifyingUpgradePopupFrame", UIParent, "BackdropTemplate")
    self._qualifyingUpgradeAnnouncementPopupFrame = popup
    popup:SetSize(360, 342)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 18)
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(138)
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:SetMovable(false)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.039216, 0.039216, 0.062745, 1.0)
    popup:SetBackdropBorderColor(0.101961, 0.101961, 0.156863, 1.0)
    popup:Hide()
    if popup.GetName and popup:GetName() then
        PA_EnsureSpecialFrame(popup:GetName())
    end

    local stripe = CreateFrame("Frame", nil, popup)
    stripe:SetPoint("TOPLEFT", popup, "TOPLEFT", 0, 0)
    stripe:SetPoint("TOPRIGHT", popup, "TOPRIGHT", 0, 0)
    stripe:SetHeight(3)
    stripe:SetFrameLevel((popup:GetFrameLevel() or 138) + 6)
    popup._stripe = stripe

    local function setHorizontalGradient(texture, leftColor, rightColor)
        local leftR, leftG, leftB, leftA = unpack(leftColor)
        local rightR, rightG, rightB, rightA = unpack(rightColor)
        if texture.SetGradientAlpha then
            texture:SetGradientAlpha("HORIZONTAL", leftR, leftG, leftB, leftA, rightR, rightG, rightB, rightA)
        elseif texture.SetGradient and CreateColor then
            texture:SetGradient("HORIZONTAL", CreateColor(leftR, leftG, leftB, leftA), CreateColor(rightR, rightG, rightB, rightA))
        else
            texture:SetColorTexture(
                (leftR + rightR) * 0.5,
                (leftG + rightG) * 0.5,
                (leftB + rightB) * 0.5,
                (leftA + rightA) * 0.5
            )
        end
    end

    local stripeLeft = stripe:CreateTexture(nil, "ARTWORK")
    stripeLeft:SetPoint("TOPLEFT", stripe, "TOPLEFT", 0, 0)
    stripeLeft:SetPoint("BOTTOMLEFT", stripe, "BOTTOMLEFT", 0, 0)
    stripeLeft:SetWidth(180)
    stripeLeft:SetTexture("Interface\\Buttons\\WHITE8x8")
    setHorizontalGradient(stripeLeft, { 0.42, 0.37, 0.81, 1.0 }, { 0.61, 0.19, 1.0, 1.0 })

    local stripeRight = stripe:CreateTexture(nil, "ARTWORK")
    stripeRight:SetPoint("TOPLEFT", stripeLeft, "TOPRIGHT", 0, 0)
    stripeRight:SetPoint("BOTTOMLEFT", stripeLeft, "BOTTOMRIGHT", 0, 0)
    stripeRight:SetWidth(180)
    stripeRight:SetTexture("Interface\\Buttons\\WHITE8x8")
    setHorizontalGradient(stripeRight, { 0.61, 0.19, 1.0, 1.0 }, { 0.88, 0.25, 0.63, 1.0 })

    local content = CreateFrame("Frame", nil, popup)
    content:SetPoint("TOPLEFT", popup, "TOPLEFT", 26, -22)
    content:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -26, 22)
    popup._content = content

    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetSize(88, 88)
    logo:SetPoint("TOP", content, "TOP", 0, -16)
    logo:SetTexture("Interface\\AddOns\\PortalAuthority\\Media\\Images\\PA-Large-Transparent.png")
    popup._logo = logo

    local logoGlowOuter = content:CreateTexture(nil, "BACKGROUND")
    logoGlowOuter:SetSize(172, 172)
    logoGlowOuter:SetPoint("CENTER", logo, "CENTER", 0, -2)
    logoGlowOuter:SetTexture("Interface\\AddOns\\PortalAuthority\\Media\\Images\\PA_Welcome_Aura.png")
    logoGlowOuter:SetBlendMode("ADD")
    logoGlowOuter:SetVertexColor(0.53, 0.18, 0.86, 0.05)

    local logoGlowMid = content:CreateTexture(nil, "BACKGROUND")
    logoGlowMid:SetSize(142, 142)
    logoGlowMid:SetPoint("CENTER", logo, "CENTER", 0, -2)
    logoGlowMid:SetTexture("Interface\\AddOns\\PortalAuthority\\Media\\Images\\PA_Welcome_Aura.png")
    logoGlowMid:SetBlendMode("ADD")
    logoGlowMid:SetVertexColor(0.63, 0.23, 0.92, 0.07)

    local logoGlowInner = content:CreateTexture(nil, "BACKGROUND")
    logoGlowInner:SetSize(112, 112)
    logoGlowInner:SetPoint("CENTER", logo, "CENTER", 0, -2)
    logoGlowInner:SetTexture("Interface\\AddOns\\PortalAuthority\\Media\\Images\\PA_Welcome_Aura.png")
    logoGlowInner:SetBlendMode("ADD")
    logoGlowInner:SetVertexColor(0.74, 0.29, 0.98, 0.08)
    popup._logoGlow = logoGlowInner

    local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self:ApplyPremiumAuthoredFont(title, 20, "")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -8)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    title:SetTextColor(0.88, 0.88, 0.91, 1.0)
    title:SetText("PORTAL AUTHORITY")
    popup._title = title

    local versionLine = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self:ApplyPremiumAuthoredFont(versionLine, 11, "")
    versionLine:SetPoint("TOP", title, "BOTTOM", 0, -8)
    versionLine:SetJustifyH("CENTER")
    versionLine:SetWordWrap(false)
    versionLine:SetTextColor(0.36, 0.75, 0.71, 1.0)
    popup._versionLine = versionLine

    local divider = CreateFrame("Frame", nil, content)
    divider:SetSize(40, 1)
    divider:SetPoint("TOP", versionLine, "BOTTOM", 0, -16)
    popup._divider = divider

    local dividerLeft = divider:CreateTexture(nil, "ARTWORK")
    dividerLeft:SetPoint("TOPLEFT", divider, "TOPLEFT", 0, 0)
    dividerLeft:SetPoint("BOTTOMLEFT", divider, "BOTTOMLEFT", 0, 0)
    dividerLeft:SetWidth(13)
    dividerLeft:SetColorTexture(0.16, 0.16, 0.23, 0.25)

    local dividerMid = divider:CreateTexture(nil, "ARTWORK")
    dividerMid:SetPoint("TOPLEFT", dividerLeft, "TOPRIGHT", 0, 0)
    dividerMid:SetPoint("BOTTOMLEFT", dividerLeft, "BOTTOMRIGHT", 0, 0)
    dividerMid:SetWidth(14)
    dividerMid:SetColorTexture(0.16, 0.16, 0.23, 0.75)

    local dividerRight = divider:CreateTexture(nil, "ARTWORK")
    dividerRight:SetPoint("TOPLEFT", dividerMid, "TOPRIGHT", 0, 0)
    dividerRight:SetPoint("TOPRIGHT", divider, "TOPRIGHT", 0, 0)
    dividerRight:SetPoint("BOTTOMLEFT", dividerMid, "BOTTOMRIGHT", 0, 0)
    dividerRight:SetPoint("BOTTOMRIGHT", divider, "BOTTOMRIGHT", 0, 0)
    dividerRight:SetColorTexture(0.16, 0.16, 0.23, 0.25)

    local message = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self:ApplyPremiumAuthoredFont(message, 13, "")
    message:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", -98, -16)
    message:SetPoint("TOPRIGHT", divider, "BOTTOMRIGHT", 98, -16)
    message:SetJustifyH("CENTER")
    message:SetJustifyV("MIDDLE")
    if message.SetSpacing then
        message:SetSpacing(6)
    end
    message:SetTextColor(0.47, 0.47, 0.47, 1.0)
    message:SetText("Your settings have a |cffc4bef0new home|r.\nRedesigned from the ground up.")
    popup._message = message

    local function createActionButton(parent, width, height, textValue)
        local PRESS_TEXT_OFFSET_X = 1
        local PRESS_TEXT_OFFSET_Y = -1

        local function setActionButtonTextOffset(btn, offsetX, offsetY)
            if not btn or not btn._text then
                return
            end
            btn._text:ClearAllPoints()
            btn._text:SetPoint("CENTER", btn, "CENTER", offsetX or 0, offsetY or 0)
        end

        local function clearActionButtonPressState(btn)
            if not btn then
                return
            end
            btn._paPressed = false
            setActionButtonTextOffset(btn, 0, 0)
        end

        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(width, height)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.42, 0.37, 0.81, 0.12)
        button:SetBackdropBorderColor(0.42, 0.37, 0.81, 0.30)

        local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        PortalAuthority:ApplyPremiumAuthoredFont(text, 13, "")
        text:SetPoint("CENTER")
        text:SetJustifyH("CENTER")
        text:SetWordWrap(false)
        text:SetTextColor(0.77, 0.75, 0.94, 1.0)
        if text.SetShadowOffset then
            text:SetShadowOffset(0, 0)
        end
        if text.SetShadowColor then
            text:SetShadowColor(0, 0, 0, 0)
        end
        text:SetText(textValue)
        button._text = text

        button:SetScript("OnEnter", function(selfButton)
            selfButton:SetBackdropBorderColor(0.42, 0.37, 0.81, 0.50)
        end)
        button:SetScript("OnLeave", function(selfButton)
            clearActionButtonPressState(selfButton)
            selfButton:SetBackdropColor(0.42, 0.37, 0.81, 0.12)
            selfButton:SetBackdropBorderColor(0.42, 0.37, 0.81, 0.30)
        end)
        button:SetScript("OnMouseDown", function(selfButton)
            selfButton._paPressed = true
            setActionButtonTextOffset(selfButton, PRESS_TEXT_OFFSET_X, PRESS_TEXT_OFFSET_Y)
        end)
        button:SetScript("OnMouseUp", function(selfButton)
            clearActionButtonPressState(selfButton)
        end)
        button:HookScript("OnHide", function(selfButton)
            clearActionButtonPressState(selfButton)
        end)
        return button
    end

    local openSettingsButton = createActionButton(content, 308, 34, "OPEN SETTINGS")
    openSettingsButton:SetPoint("BOTTOM", content, "BOTTOM", 0, 28)
    popup._openSettingsButton = openSettingsButton

    local laterButton = CreateFrame("Button", nil, content)
    laterButton:SetSize(64, 18)
    laterButton:SetPoint("TOP", openSettingsButton, "BOTTOM", 0, -10)
    laterButton:SetHitRectInsets(-6, -6, -4, -4)
    popup._laterButton = laterButton

    local laterText = laterButton:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self:ApplyPremiumAuthoredFont(laterText, 11, "")
    laterText:SetPoint("CENTER")
    laterText:SetText("Later")
    laterText:SetTextColor(0.34, 0.35, 0.41, 1.0)
    if laterText.SetShadowOffset then
        laterText:SetShadowOffset(0, 0)
    end
    if laterText.SetShadowColor then
        laterText:SetShadowColor(0, 0, 0, 0)
    end
    laterButton._text = laterText

    laterButton:SetScript("OnEnter", function(selfButton)
        selfButton._text:SetTextColor(0.43, 0.44, 0.50, 1.0)
    end)
    laterButton:SetScript("OnLeave", function(selfButton)
        selfButton._text:SetTextColor(0.34, 0.35, 0.41, 1.0)
    end)

    openSettingsButton:SetScript("OnClick", function()
        local ok, err = PortalAuthority:OpenSettingsFromQualifyingUpgradeAnnouncement()
        if not ok and err then
            PA_PrintPortalAuthorityMessage(err)
        end
    end)

    laterButton:SetScript("OnClick", function()
        PortalAuthority:DismissQualifyingUpgradeAnnouncementPopup("later")
    end)

    popup:SetScript("OnShow", function(frame)
        frame._paDismissFinalized = nil
        frame._paAllowOnHideFinalize = true
        frame._paLiveVisibleSession = true
        if PortalAuthority then
            PortalAuthority._qualifyingUpgradeAnnouncementTeardownSuppressed = nil
        end
        if frame.Raise then
            frame:Raise()
        end
    end)

    popup:SetScript("OnHide", function(frame)
        PA_StopFrameAnimation(frame)
        if frame
            and frame._paLiveVisibleSession == true
            and frame._paAllowOnHideFinalize == true
            and frame._paDismissFinalized ~= true
            and PortalAuthority
            and not PortalAuthority:_IsQualifyingUpgradeAnnouncementPopupTeardownSuppressed()
            and not PortalAuthority:_IsQualifyingUpgradeAnnouncementPopupNonConsumingHideSuppressed()
        then
            PortalAuthority:_FinalizeQualifyingUpgradeAnnouncementPopup("special-frame-close", {
                openSettings = false,
                alreadyHidden = true,
            })
        end
        frame._paDismissFinalized = nil
        frame._paAllowOnHideFinalize = nil
        frame._paLiveVisibleSession = nil
        frame:SetAlpha(1)
    end)

    return popup
end

function PortalAuthority:ShowQualifyingUpgradeAnnouncementPopup(reason)
    if not self:IsQualifyingUpgradeWelcomePending() then
        return false, "No qualifying-upgrade welcome is pending."
    end

    local popup = self:EnsureQualifyingUpgradeAnnouncementPopupFrame()
    if not popup then
        return false, "Qualifying-upgrade popup is unavailable."
    end

    if popup._versionLine then
        popup._versionLine:SetText(string.format("VERSION %s", tostring(self:GetAnnouncementReleaseVersionString() or "")))
    end

    if PA_IsPremiumWelcomeVisible(popup) then
        if popup.Raise then
            popup:Raise()
        end
        return true, string.format("Qualifying-upgrade popup already visible (%s).", tostring(reason or "manual"))
    end

    popup._paDismissFinalized = nil
    popup._paAllowOnHideFinalize = true
    popup._paLiveVisibleSession = nil
    popup:SetAlpha(0)
    popup:Show()
    if popup.Raise then
        popup:Raise()
    end
    PA_StartAlphaTween(popup, popup, "fadeToken", 0, 1, 0.15)
    return true, string.format("Qualifying-upgrade popup shown (%s).", tostring(reason or "manual"))
end

function PortalAuthority:ApplyPublicOnboardingD5b1FreshInstallState()
    if not PA_IsOnboardingD3PublicGateEnabled() then
        return false, "Public onboarding is disabled."
    end
    if self._profilesFreshInstallThisLoad ~= true or self._profilesLegacyMigratedThisLoad == true then
        return false, "No fresh-install onboarding state changes are needed."
    end

    if self.Profiles_SetSettingsResetEpochApplied then
        self:Profiles_SetSettingsResetEpochApplied(PortalAuthority._buildConfig.release.premiumOnboardingResetEpoch)
    end
    if self.Profiles_SetOnboardingExperienceSeen then
        self:Profiles_SetOnboardingExperienceSeen(nil)
    end
    if self.Profiles_SetFirstRunLandingConsumed then
        self:Profiles_SetFirstRunLandingConsumed(nil)
    end
    if self.Profiles_ClearOnboardingD4Session then
        self:Profiles_ClearOnboardingD4Session()
    end
    if self.Profiles_ClearQualifyingUpgradeOnboardingState then
        self:Profiles_ClearQualifyingUpgradeOnboardingState()
    end

    return true, "Fresh-install onboarding state prepared."
end

function PortalAuthority:ApplyPublicOnboardingD5b2QualifyingUpgradeState()
    if not PA_IsOnboardingQualifyingUpgradePublicGateEnabled() then
        return false, "Public qualifying-upgrade onboarding is disabled."
    end
    if not PA_IsOnboardingD3PublicGateEnabled() then
        return false, "Public onboarding is disabled."
    end
    if self._profilesFreshInstallThisLoad == true or self._profilesLegacyMigratedThisLoad == true then
        return false, "No qualifying-upgrade onboarding state changes are needed."
    end

    local rolloutVersion = trim(tostring(PortalAuthority._buildConfig.release.qualifyingUpgradeOnboardingVersion or ""))
    if rolloutVersion == "" then
        return false, "Qualifying-upgrade rollout version is unavailable."
    end

    local appliedVersion = self.Profiles_GetQualifyingUpgradeOnboardingAppliedVersion and self:Profiles_GetQualifyingUpgradeOnboardingAppliedVersion() or nil
    if appliedVersion == rolloutVersion then
        return false, "Qualifying-upgrade onboarding is already applied."
    end

    if not self.Profiles_SetQualifyingUpgradeOnboardingAppliedVersion
        or not self.Profiles_SetQualifyingUpgradeOnboardingSeenVersion
    then
        return false, "Qualifying-upgrade onboarding state storage is unavailable."
    end

    -- The 2.1.1 popup is tracked by its own rollout-version state. Existing 2.0.x
    -- installs may already carry the 2.0 baseline epoch, so do not reuse that
    -- marker as a blocker here.
    self:Profiles_SetQualifyingUpgradeOnboardingAppliedVersion(rolloutVersion)
    self:Profiles_SetQualifyingUpgradeOnboardingSeenVersion(nil)
    return true, "Qualifying-upgrade onboarding state prepared."
end

function PortalAuthority:IsPremiumWelcomePending()
    local resetEpoch = self.Profiles_GetSettingsResetEpochApplied and self:Profiles_GetSettingsResetEpochApplied() or nil
    local experienceSeen = self.Profiles_GetOnboardingExperienceSeen and self:Profiles_GetOnboardingExperienceSeen() or nil
    return resetEpoch == PortalAuthority._buildConfig.release.premiumOnboardingResetEpoch
        and experienceSeen ~= PortalAuthority._buildConfig.release.premiumOnboardingVersion
end

function PortalAuthority:IsQualifyingUpgradeWelcomePending()
    if not PA_IsOnboardingQualifyingUpgradePublicGateEnabled() then
        return false
    end

    local appliedVersion = self.Profiles_GetQualifyingUpgradeOnboardingAppliedVersion and self:Profiles_GetQualifyingUpgradeOnboardingAppliedVersion() or nil
    local seenVersion = self.Profiles_GetQualifyingUpgradeOnboardingSeenVersion and self:Profiles_GetQualifyingUpgradeOnboardingSeenVersion() or nil
    return appliedVersion == PortalAuthority._buildConfig.release.qualifyingUpgradeOnboardingVersion
        and seenVersion ~= PortalAuthority._buildConfig.release.qualifyingUpgradeOnboardingVersion
end

function PortalAuthority:HasPendingPremiumWelcome()
    return self:IsPremiumWelcomePending() or self:IsQualifyingUpgradeWelcomePending()
end

function PortalAuthority:MarkPremiumOnboardingEntrySatisfied()
    if self.Profiles_SetOnboardingExperienceSeen then
        self:Profiles_SetOnboardingExperienceSeen(PortalAuthority._buildConfig.release.premiumOnboardingVersion)
    end
    if self.Profiles_SetFirstRunLandingConsumed then
        self:Profiles_SetFirstRunLandingConsumed(true)
    end
    return true
end

function PortalAuthority:MarkQualifyingUpgradeWelcomeSatisfiedIfPending()
    if not self:IsQualifyingUpgradeWelcomePending() then
        return false
    end
    if self.Profiles_SetQualifyingUpgradeOnboardingSeenVersion then
        self:Profiles_SetQualifyingUpgradeOnboardingSeenVersion(
            PortalAuthority._buildConfig.release.qualifyingUpgradeOnboardingVersion
        )
    end
    return true
end

function PortalAuthority:ScheduleAutomaticPremiumWelcome(reason)
    if not PA_IsOnboardingD3Enabled() then
        return false, "Premium welcome is unavailable in this build."
    end
    if not self:IsPremiumWelcomePending() then
        return false, "No premium welcome is pending."
    end

    self._premiumWelcomeReadyAt = (GetTime and (GetTime() + 1.0)) or 0
    self:EnsurePremiumWelcomeFrame()

    if not (C_Timer and C_Timer.After) then
        return false, "Premium welcome timer is unavailable."
    end

    local token = math.floor((tonumber(self._premiumWelcomeAutoToken) or 0) + 1)
    self._premiumWelcomeAutoToken = token
    C_Timer.After(1.05, function()
        if not PortalAuthority or PortalAuthority._premiumWelcomeAutoToken ~= token then
            return
        end
        PortalAuthority:EvaluatePendingWelcome(reason or "login-auto")
    end)
    return true, "Premium welcome scheduled."
end

function PortalAuthority:CanShowQualifyingUpgradeAnnouncementNow()
    if not PA_IsOnboardingQualifyingUpgradePublicGateEnabled() then
        return false, "Qualifying-upgrade popup is unavailable in this build."
    end
    if (InCombatLockdown and InCombatLockdown()) or self:IsPlayerInCombat() then
        return false, "Qualifying-upgrade popup is unavailable during combat."
    end
    if PA_IsChallengeActive and PA_IsChallengeActive() then
        return false, "Qualifying-upgrade popup is unavailable during active Mythic+ runs."
    end

    local readyAt = tonumber(self._qualifyingUpgradeAnnouncementReadyAt or 0) or 0
    if readyAt > 0 and GetTime and GetTime() < readyAt then
        return false, "Qualifying-upgrade popup is waiting for login state to settle."
    end

    return true, "Ready."
end

function PortalAuthority:ScheduleAutomaticQualifyingUpgradeAnnouncement(reason)
    if not self:IsQualifyingUpgradeWelcomePending() then
        return false, "No qualifying-upgrade welcome is pending."
    end

    self._qualifyingUpgradeAnnouncementReadyAt = (GetTime and (GetTime() + 1.0)) or 0
    self:EnsureQualifyingUpgradeAnnouncementPopupFrame()

    if not (C_Timer and C_Timer.After) then
        return false, "Qualifying-upgrade popup timer is unavailable."
    end

    local token = math.floor((tonumber(self._qualifyingUpgradeAnnouncementAutoToken) or 0) + 1)
    self._qualifyingUpgradeAnnouncementAutoToken = token
    C_Timer.After(1.05, function()
        if not PortalAuthority or PortalAuthority._qualifyingUpgradeAnnouncementAutoToken ~= token then
            return
        end
        if not PortalAuthority:IsQualifyingUpgradeWelcomePending() then
            return
        end

        local canShow = PortalAuthority:CanShowQualifyingUpgradeAnnouncementNow()
        if not canShow then
            return
        end

        PortalAuthority:ShowQualifyingUpgradeAnnouncementPopup(reason or "login-auto")
    end)
    return true, "Qualifying-upgrade popup scheduled."
end

function PortalAuthority:CanShowPremiumWelcomeNow()
    if not PA_IsOnboardingD3Enabled() then
        return false, "Premium welcome is unavailable in this build."
    end
    if (InCombatLockdown and InCombatLockdown()) or self:IsPlayerInCombat() then
        return false, "Premium welcome is unavailable during combat."
    end
    if PA_IsChallengeActive and PA_IsChallengeActive() then
        return false, "Premium welcome is unavailable during active Mythic+ runs."
    end

    local readyAt = tonumber(self._premiumWelcomeReadyAt or 0) or 0
    if readyAt > 0 and GetTime and GetTime() < readyAt then
        return false, "Premium welcome is waiting for login state to settle."
    end

    return true, "Ready."
end

function PortalAuthority:HidePremiumWelcome()
    if PA_IsPremiumWelcomeVisible(self._premiumWelcomeFrame) then
        self._premiumWelcomeFrame:Hide()
    end
end

function PortalAuthority:EnsurePremiumWelcomeFrame()
    local overlay = self._premiumWelcomeFrame
    if overlay then
        return overlay
    end

    overlay = CreateFrame("Frame", "PortalAuthorityPremiumWelcomeFrame", UIParent, "BackdropTemplate")
    self._premiumWelcomeFrame = overlay
    overlay:SetSize(544, 448)
    overlay:SetPoint("CENTER", UIParent, "CENTER", 0, 18)
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel(120)
    overlay:SetToplevel(true)
    overlay:SetClampedToScreen(true)
    overlay:EnableMouse(true)
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    overlay:SetBackdropColor(0.04, 0.05, 0.07, 0.97)
    overlay:Hide()
    overlay:SetScript("OnMouseDown", function() end)
    overlay:SetScript("OnMouseUp", function() end)

    local content = CreateFrame("Frame", nil, overlay, "BackdropTemplate")
    content:SetSize(480, 392)
    content:SetPoint("CENTER", overlay, "CENTER", 0, 10)
    content:SetFrameLevel((overlay:GetFrameLevel() or 120) + 3)
    content:EnableMouse(false)
    overlay._content = content

    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\PortalAuthority\\Media\\Images\\PA-Large-Transparent.png")
    logo:SetPoint("TOP", content, "TOP", 0, -30)
    logo:SetSize(140, 140)
    overlay._logo = logo

    overlay._aura = nil

    local wordmark = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self:ApplyPremiumAuthoredFont(wordmark, 32, "")
    wordmark:SetPoint("TOP", logo, "BOTTOM", 0, -22)
    wordmark:SetJustifyH("CENTER")
    wordmark:SetWordWrap(false)
    wordmark:SetTextColor(0.97, 0.97, 0.98, 1.0)
    wordmark:SetShadowOffset(0, -1)
    wordmark:SetShadowColor(0, 0, 0, 0.55)
    wordmark:SetText("Portal Authority")
    overlay._wordmark = wordmark

    local valueLine = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self:ApplyPremiumAuthoredFont(valueLine, 16, "")
    valueLine:SetPoint("TOP", wordmark, "BOTTOM", 0, -10)
    valueLine:SetJustifyH("CENTER")
    valueLine:SetWordWrap(false)
    valueLine:SetTextColor(0.89, 0.88, 0.90, 1.0)
    valueLine:SetText("Your Mythic+ toolkit. Ready when you are.")
    overlay._valueLine = valueLine

    local helperLine = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self:ApplyPremiumAuthoredFont(helperLine, 13, "")
    helperLine:SetPoint("TOP", valueLine, "BOTTOM", 0, -8)
    helperLine:SetJustifyH("CENTER")
    helperLine:SetWordWrap(false)
    helperLine:SetTextColor(0.68, 0.68, 0.72, 1.0)
    helperLine:SetText("Open anytime with /pa.")
    overlay._helperLine = helperLine

    local function createPrimaryButton(parent, label)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(220, 36)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.16, 0.11, 0.23, 0.96)
        button:SetBackdropBorderColor(0.40, 0.28, 0.51, 0.74)

        local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        PortalAuthority:ApplyPremiumAuthoredFont(text, 14, "")
        text:SetPoint("CENTER")
        text:SetTextColor(0.98, 0.97, 0.98, 1.0)
        text:SetText(label)
        button._text = text

        button:SetScript("OnEnter", function(selfBtn)
            selfBtn:SetBackdropColor(0.20, 0.13, 0.28, 0.98)
            selfBtn:SetBackdropBorderColor(0.50, 0.35, 0.64, 0.86)
        end)
        button:SetScript("OnLeave", function(selfBtn)
            selfBtn:SetBackdropColor(0.16, 0.11, 0.23, 0.96)
            selfBtn:SetBackdropBorderColor(0.40, 0.28, 0.51, 0.74)
        end)
        return button
    end

    local function createTextButton(parent, label, quietest)
        local button = CreateFrame("Button", nil, parent)
        local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        PortalAuthority:ApplyPremiumAuthoredFont(text, 12, "")
        text:SetPoint("CENTER")
        text:SetText(label)
        text:SetTextColor(quietest and 0.58 or 0.72, quietest and 0.58 or 0.72, quietest and 0.62 or 0.76, 1.0)
        text:SetShadowOffset(0, -1)
        text:SetShadowColor(0, 0, 0, 0.35)
        button._text = text
        button:SetSize(math.max(64, math.ceil((text:GetStringWidth() or 0) + 12)), 18)
        button:SetHitRectInsets(-6, -6, -4, -4)
        button:SetScript("OnEnter", function(selfBtn)
            if quietest then
                selfBtn._text:SetTextColor(0.76, 0.76, 0.80, 1.0)
            else
                selfBtn._text:SetTextColor(0.87, 0.87, 0.90, 1.0)
            end
        end)
        button:SetScript("OnLeave", function(selfBtn)
            selfBtn._text:SetTextColor(quietest and 0.58 or 0.72, quietest and 0.58 or 0.72, quietest and 0.62 or 0.76, 1.0)
        end)
        return button
    end

    local primaryButton = createPrimaryButton(content, "Show Me Around")
    primaryButton:SetPoint("TOP", helperLine, "BOTTOM", 0, -34)
    overlay._primaryButton = primaryButton

    local secondaryRow = CreateFrame("Frame", nil, content)
    secondaryRow:SetSize(260, 20)
    secondaryRow:SetPoint("TOP", primaryButton, "BOTTOM", 0, -14)
    overlay._secondaryRow = secondaryRow

    local openSettingsButton = createTextButton(secondaryRow, "Open Settings", false)
    openSettingsButton:SetPoint("CENTER", secondaryRow, "CENTER", -56, 0)
    overlay._openSettingsButton = openSettingsButton

    local skipButton = createTextButton(secondaryRow, "Skip", true)
    skipButton:SetPoint("CENTER", secondaryRow, "CENTER", 56, 0)
    overlay._skipButton = skipButton

    primaryButton:SetScript("OnClick", function()
        if not PortalAuthority then
            return
        end
        local ok, response = PortalAuthority:StartPremiumOnboardingExperience("welcome-primary")
        if not ok and not PA_IsOnboardingD4Enabled() then
            local openErr
            ok, openErr = PortalAuthority:OpenSettings(PortalAuthority.rootCategoryID)
            if ok then
                response = "Premium root/home opened (welcome-primary-fallback)."
            else
                response = openErr or response
            end
        end
        if ok then
            PortalAuthority:HidePremiumWelcome()
        else
            PA_PrintPortalAuthorityMessage(response or "Premium onboarding failed.")
        end
    end)

    openSettingsButton:SetScript("OnClick", function()
        if not PortalAuthority then
            return
        end
        local ok, err = PortalAuthority:OpenPrimarySettingsEntry("welcome-open-settings")
        if ok then
            PortalAuthority:HidePremiumWelcome()
        elseif err then
            PA_PrintPortalAuthorityMessage(err)
        end
    end)

    skipButton:SetScript("OnClick", function()
        if PortalAuthority then
            PortalAuthority:HidePremiumWelcome()
        end
    end)

    overlay:SetScript("OnShow", function(frame)
        frame:SetAlpha(1)
        if frame.Raise then
            frame:Raise()
        end
    end)

    overlay:SetScript("OnHide", function(frame)
        frame:SetAlpha(1)
    end)

    return overlay
end

function PortalAuthority:TryShowPremiumWelcome(reason, explicitEntry)
    if not PA_IsOnboardingD3Enabled() then
        return false, "Premium welcome is unavailable in this build."
    end
    if not explicitEntry and not self:IsPremiumWelcomePending() then
        return false, "No premium welcome is pending."
    end

    local canShow, blockMessage = self:CanShowPremiumWelcomeNow()
    if not canShow then
        return false, blockMessage
    end

    local frame = self:EnsurePremiumWelcomeFrame()
    if not frame then
        return false, "Premium welcome frame is unavailable."
    end

    if PA_IsPremiumWelcomeVisible(frame) then
        if frame.Raise then
            frame:Raise()
        end
        return true, "Premium welcome is already visible."
    end

    frame:Show()
    self:MarkPremiumOnboardingEntrySatisfied()

    return true, string.format("Premium welcome shown (%s).", tostring(reason or "manual"))
end

function PortalAuthority:EvaluatePendingWelcome(reason)
    if not self:IsPremiumWelcomePending() then
        return false, "No premium welcome is pending."
    end
    return self:TryShowPremiumWelcome(reason, false)
end

function PortalAuthority:StartExplicitQualifyingUpgradeWelcome(reason)
    if not self:IsQualifyingUpgradeWelcomePending() then
        return false, "No qualifying-upgrade welcome is pending."
    end
    return self:ShowQualifyingUpgradeAnnouncementPopup(reason or "qualifying-upgrade-explicit")
end

function PortalAuthority:ShowPremiumRootHome(reason, consumeLanding)
    if not PA_IsOnboardingD3Enabled() then
        return false, "Premium root/home is unavailable in this build."
    end

    local rootAlreadyVisible = false
    if self.IsSettingsWindowHostEnabled
        and self:IsSettingsWindowHostEnabled()
        and self.IsSettingsWindowOpen
        and self:IsSettingsWindowOpen()
    then
        local runtime = self._settingsWindowRuntime
        rootAlreadyVisible = runtime and runtime.currentSectionKey == "root"
    end

    if not rootAlreadyVisible then
        local rootPanel = self.rootPanel
        rootAlreadyVisible = rootPanel and rootPanel.IsShown and rootPanel:IsShown() and true or false
    end

    if rootAlreadyVisible then
        if consumeLanding and self.Profiles_SetFirstRunLandingConsumed and not self:Profiles_GetFirstRunLandingConsumed() then
            self:Profiles_SetFirstRunLandingConsumed(true)
        end
        return true, string.format("Premium root/home already visible (%s).", tostring(reason or "manual"))
    end

    local opened, openErr = self:OpenSettings(self.rootCategoryID)
    if not opened then
        return false, openErr or "Root/home settings page is unavailable."
    end

    if consumeLanding and self.Profiles_SetFirstRunLandingConsumed then
        self:Profiles_SetFirstRunLandingConsumed(true)
    end
    return true, string.format("Premium root/home opened (%s).", tostring(reason or "manual"))
end

function PortalAuthority:StartPremiumOnboardingExperience(reason)
    if not PA_IsOnboardingD3Enabled() then
        return false, "Premium onboarding is unavailable in this build."
    end
    if PA_IsOnboardingD4Enabled() then
        return self:StartOnboardingD4Tour(reason or "premium-onboarding")
    end
    return self:ShowPremiumRootHome(reason or "premium-onboarding", false)
end

function PortalAuthority:StartExplicitPremiumOnboarding(reason)
    if not PA_IsOnboardingD3Enabled() then
        return false, "Premium onboarding is unavailable in this build."
    end
    if not PA_IsOnboardingD4Enabled() then
        return false, "Guided setup is unavailable in this build."
    end

    local shouldStampOnSuccess = not (self.IsOnboardingD4Active and self:IsOnboardingD4Active())
    local ok, response = self:StartOnboardingD4Tour(reason or "premium-onboarding")
    if ok and shouldStampOnSuccess then
        self:MarkPremiumOnboardingEntrySatisfied()
    end
    return ok, response
end

function PortalAuthority:OpenPrimarySettingsEntry(reason)
    if PA_IsOnboardingD3Enabled() then
        local landingConsumed = self.Profiles_GetFirstRunLandingConsumed and self:Profiles_GetFirstRunLandingConsumed() or nil
        if not landingConsumed then
            return self:ShowPremiumRootHome(reason or "primary-settings-entry", true)
        end
    end

    local opened, openErr = self:OpenSettings(nil)
    if not opened then
        return false, openErr or "Settings are unavailable."
    end
    return true, nil
end

function PortalAuthority:HandleSlashRootEntry()
    if self:IsQualifyingUpgradeWelcomePending() then
        return self:StartExplicitQualifyingUpgradeWelcome("slash-pa")
    end
    return self:OpenPrimarySettingsEntry("slash-pa")
end

function PortalAuthority:HandleSlashUpdatesEntry()
    if self:IsQualifyingUpgradeWelcomePending() then
        return self:StartExplicitQualifyingUpgradeWelcome("slash-updates")
    end
    return self:OpenPrimarySettingsEntry("slash-updates")
end

function PortalAuthority:GetOnboardingD3StatusLines()
    local lines = {}
    local resetEpoch = self.Profiles_GetSettingsResetEpochApplied and self:Profiles_GetSettingsResetEpochApplied() or nil
    local seen = self.Profiles_GetOnboardingExperienceSeen and self:Profiles_GetOnboardingExperienceSeen() or nil
    local landingConsumed = self.Profiles_GetFirstRunLandingConsumed and self:Profiles_GetFirstRunLandingConsumed() or nil
    local upgradeApplied = self.Profiles_GetQualifyingUpgradeOnboardingAppliedVersion and self:Profiles_GetQualifyingUpgradeOnboardingAppliedVersion() or nil
    local upgradeSeen = self.Profiles_GetQualifyingUpgradeOnboardingSeenVersion and self:Profiles_GetQualifyingUpgradeOnboardingSeenVersion() or nil
    local pending = self:IsPremiumWelcomePending()
    local upgradePending = self:IsQualifyingUpgradeWelcomePending()
    local canShow, reason = self:CanShowPremiumWelcomeNow()

    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r D3 gate=%s", PA_IsOnboardingD3DevGateEnabled() and "ON" or "OFF")
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r D3 public gate=%s", PA_IsOnboardingD3PublicGateEnabled() and "ON" or "OFF")
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r qualifyingUpgradePublicGate=%s", PA_IsOnboardingQualifyingUpgradePublicGateEnabled() and "ON" or "OFF")
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r settingsResetEpochApplied=%s", tostring(resetEpoch))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r onboardingExperienceSeen=%s", tostring(seen))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r firstRunLandingConsumed=%s", tostring(landingConsumed))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r qualifyingUpgradeAppliedVersion=%s", tostring(upgradeApplied))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r qualifyingUpgradeSeenVersion=%s", tostring(upgradeSeen))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r pendingWelcome=%s", tostring(pending))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r qualifyingUpgradePending=%s", tostring(upgradePending))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r anyPendingWelcome=%s", tostring(self:HasPendingPremiumWelcome()))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r safeShow=%s (%s)", tostring(canShow), tostring(reason or "unknown"))
    return lines
end

function PortalAuthority:GetS8AnnouncementStatusLines()
    local lines = {}
    local releaseVersion = self:GetAnnouncementReleaseVersionString() or PortalAuthority._buildConfig.release.settingsWindowAnnouncementVersion
    local popupVersion = PortalAuthority._buildConfig.release.qualifyingUpgradeOnboardingVersion
    local popupApplied = self.Profiles_GetQualifyingUpgradeOnboardingAppliedVersion
            and self:Profiles_GetQualifyingUpgradeOnboardingAppliedVersion()
        or nil
    local popupSeen = self.Profiles_GetQualifyingUpgradeOnboardingSeenVersion
            and self:Profiles_GetQualifyingUpgradeOnboardingSeenVersion()
        or nil
    local glowSeen = self.Profiles_GetSettingsWindowSearchIntroSeenVersion
            and self:Profiles_GetSettingsWindowSearchIntroSeenVersion()
        or nil
    local d3Pending = self:IsPremiumWelcomePending()
    local popupPending = self:IsQualifyingUpgradeWelcomePending()
    local landingConsumed = self.Profiles_GetFirstRunLandingConsumed
            and self:Profiles_GetFirstRunLandingConsumed()
        or nil
    local glowPending = glowSeen ~= releaseVersion
    local popupVisible = self._qualifyingUpgradeAnnouncementPopupFrame
            and self._qualifyingUpgradeAnnouncementPopupFrame.IsShown
            and self._qualifyingUpgradeAnnouncementPopupFrame:IsShown()
        or false
    local windowOpen = self.IsSettingsWindowOpen and self:IsSettingsWindowOpen() or false
    local routingState = "consumed-or-none"
    local routingNote = nil
    if popupPending and d3Pending then
        routingState = "qualifying-upgrade-pending"
        routingNote = "popup takes precedence over d3"
    elseif popupPending then
        routingState = "qualifying-upgrade-pending"
    elseif d3Pending and landingConsumed ~= true then
        routingState = "fresh-install-d3-pending"
    elseif d3Pending then
        routingState = "premium-pending-other"
    end

    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 releaseVersion=%s", tostring(releaseVersion))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 popupVersion=%s", tostring(popupVersion))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 popupApplied=%s", tostring(popupApplied))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 popupSeen=%s", tostring(popupSeen))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 popupPending=%s", tostring(popupPending))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 popupVisible=%s", tostring(popupVisible))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 d3Pending=%s", tostring(d3Pending))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 landingConsumed=%s", tostring(landingConsumed))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 routingState=%s", tostring(routingState))
    if routingNote then
        lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 routingNote=%s", tostring(routingNote))
    end
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 glowSeen=%s", tostring(glowSeen))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 glowPending=%s", tostring(glowPending))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r S8 windowOpen=%s", tostring(windowOpen))
    return lines
end

function PortalAuthority:_SuppressPremiumWelcomeStateForS8TestSetup()
    if self.Profiles_SetOnboardingExperienceSeen then
        self:Profiles_SetOnboardingExperienceSeen(PortalAuthority._buildConfig.release.premiumOnboardingVersion)
    end
    if self.Profiles_SetFirstRunLandingConsumed then
        self:Profiles_SetFirstRunLandingConsumed(true)
    end
    if self.Profiles_ClearOnboardingD4Session then
        self:Profiles_ClearOnboardingD4Session()
    end
    if self.HidePremiumWelcome then
        self:HidePremiumWelcome()
    end

    self._premiumWelcomeReadyAt = 0
    self._premiumWelcomeAutoToken = math.floor((tonumber(self._premiumWelcomeAutoToken) or 0) + 1)
    return true
end

function PortalAuthority:PrepareS8AnnouncementTestState(mode)
    mode = trim(tostring(mode or "")):lower()
    local releaseVersion = self:GetAnnouncementReleaseVersionString() or PortalAuthority._buildConfig.release.settingsWindowAnnouncementVersion
    local popupVersion = PortalAuthority._buildConfig.release.qualifyingUpgradeOnboardingVersion

    if mode == "upgrade" or mode == "test-upgrade" or mode == "all" or mode == "test-all" or mode == "reset" then
        if self.Profiles_SetQualifyingUpgradeOnboardingAppliedVersion then
            self:Profiles_SetQualifyingUpgradeOnboardingAppliedVersion(popupVersion)
        end
        if self.Profiles_SetQualifyingUpgradeOnboardingSeenVersion then
            self:Profiles_SetQualifyingUpgradeOnboardingSeenVersion(nil)
        end
    end

    if mode == "upgrade" or mode == "test-upgrade" or mode == "all" or mode == "test-all" or mode == "reset" then
        if self._SuppressPremiumWelcomeStateForS8TestSetup then
            self:_SuppressPremiumWelcomeStateForS8TestSetup()
        end
    end

    if mode == "glow" or mode == "test-glow" or mode == "all" or mode == "test-all" or mode == "reset" then
        if self.Profiles_ClearSettingsWindowSearchIntroSeenVersion then
            self:Profiles_ClearSettingsWindowSearchIntroSeenVersion()
        elseif self.Profiles_SetSettingsWindowSearchIntroSeenVersion then
            self:Profiles_SetSettingsWindowSearchIntroSeenVersion(nil)
        end
    end

    if mode == "fresh-install" or mode == "test-fresh-install" then
        if self.Profiles_ClearQualifyingUpgradeOnboardingState then
            self:Profiles_ClearQualifyingUpgradeOnboardingState()
        else
            if self.Profiles_SetQualifyingUpgradeOnboardingAppliedVersion then
                self:Profiles_SetQualifyingUpgradeOnboardingAppliedVersion(nil)
            end
            if self.Profiles_SetQualifyingUpgradeOnboardingSeenVersion then
                self:Profiles_SetQualifyingUpgradeOnboardingSeenVersion(nil)
            end
        end
        if self.Profiles_SetSettingsResetEpochApplied then
            self:Profiles_SetSettingsResetEpochApplied(PortalAuthority._buildConfig.release.premiumOnboardingResetEpoch)
        end
        if self.Profiles_SetOnboardingExperienceSeen then
            self:Profiles_SetOnboardingExperienceSeen(nil)
        end
        if self.Profiles_SetFirstRunLandingConsumed then
            self:Profiles_SetFirstRunLandingConsumed(nil)
        end
        if self.Profiles_ClearOnboardingD4Session then
            self:Profiles_ClearOnboardingD4Session()
        end
    end

    if self._HideQualifyingUpgradeAnnouncementPopupForSetup then
        self:_HideQualifyingUpgradeAnnouncementPopupForSetup()
    elseif self.HideQualifyingUpgradeAnnouncementPopup then
        self:HideQualifyingUpgradeAnnouncementPopup()
    end
    if self.CloseSettingsWindow and self.IsSettingsWindowOpen and self:IsSettingsWindowOpen() then
        self:CloseSettingsWindow()
    end

    if mode == "upgrade" or mode == "test-upgrade" then
        return true, string.format(
            "S8 popup re-armed and D3 welcome suppressed. Next: type /pa or /pa updates. Glow seen stays %s.",
            tostring(self.Profiles_GetSettingsWindowSearchIntroSeenVersion and self:Profiles_GetSettingsWindowSearchIntroSeenVersion() or nil)
        )
    end
    if mode == "glow" or mode == "test-glow" then
        return true, string.format(
            "S8 search glow re-armed for version %s. Next: open the custom settings window from hidden.",
            tostring(releaseVersion)
        )
    end
    if mode == "fresh-install" or mode == "test-fresh-install" then
        return true, "S8 fresh-install routing re-armed. Next: type /pa or /pa updates; the 2.1.1 popup should not appear."
    end
    if mode == "all" or mode == "test-all" or mode == "reset" then
        return true, "S8 popup + glow re-armed with D3 welcome suppressed. Next: type /pa, then use Open Settings in the popup."
    end

    return false, "Usage: /pa dev s8 status|test-upgrade|test-glow|test-fresh-install|test-all"
end

function PortalAuthority:HandleS8AnnouncementSlash(rawAction)
    local action = trim(tostring(rawAction or "")):lower()
    if action == "" or action == "help" then
        PA_PrintPortalAuthorityMessage("usage: /pa dev s8 status|test-upgrade|test-glow|test-fresh-install|test-all")
        return true
    end

    if action == "status" then
        for _, line in ipairs(self:GetS8AnnouncementStatusLines()) do
            print(line)
        end
        return true
    end

    local ok, message = self:PrepareS8AnnouncementTestState(action)
    PA_PrintPortalAuthorityMessage(message or (ok and "S8 test state prepared." or "S8 test state failed."))
    return true
end

function PortalAuthority:HandleOnboardingD3Slash(rawAction)
    local action = trim(tostring(rawAction or "")):lower()
    if action == "" or action == "help" then
        PA_PrintPortalAuthorityMessage("usage: /pa dev onboarding-d3 status|clear-intro-state|show-welcome|show-root")
        return true
    end

    if action == "status" then
        for _, line in ipairs(self:GetOnboardingD3StatusLines()) do
            print(line)
        end
        return true
    end

    if action == "clear-intro-state" then
        if not self.Profiles_ClearIntroState then
            PA_PrintPortalAuthorityMessage("D3 intro-state helpers are unavailable.")
            return true
        end
        self:Profiles_ClearIntroState()
        PA_PrintPortalAuthorityMessage("D3 intro-state cleared for the active profile.")
        return true
    end

    if action == "show-welcome" then
        local ok, response = self:TryShowPremiumWelcome("dev-show-welcome", true)
        PA_PrintPortalAuthorityMessage(response or (ok and "Premium welcome shown." or "Premium welcome failed."))
        return true
    end

    if action == "show-root" then
        local ok, response = self:ShowPremiumRootHome("dev-show-root", false)
        PA_PrintPortalAuthorityMessage(response or (ok and "Premium root/home opened." or "Premium root/home failed."))
        return true
    end

    PA_PrintPortalAuthorityMessage("usage: /pa dev onboarding-d3 status|clear-intro-state|show-welcome|show-root")
    return true
end

local PA_ONBOARDING_D4_CARD_WIDTH = 344
local PA_ONBOARDING_D4_CARD_FINAL_WIDTH = PA_ONBOARDING_D4_CARD_WIDTH
local PA_ONBOARDING_D4_CARD_HEIGHT = 228
local PA_ONBOARDING_D4_CARD_OFFSET_X = -260
local PA_ONBOARDING_D4_CARD_OFFSET_Y = 60
local PA_ONBOARDING_D4_MODULE_OFFSET_X = 260
local PA_ONBOARDING_D4_MODULE_OFFSET_Y = 60
local PA_ONBOARDING_D4_SETTINGS_NOTE = "More options live in Settings."

local PA_ONBOARDING_D4_STEPS = {
    {
        key = "timers",
        title = "Timers",
        helper = "Keeps key timing in view.",
        subhelper = "Move it to your favorite spot.",
    },
    {
        key = "interruptTracker",
        title = "Interrupt Tracker",
        helper = "Shows interrupt readiness where it matters.",
        subhelper = "Place it where quick decisions feel effortless.",
    },
    {
        key = "combatAlerts",
        title = "Combat Alerts",
        helper = "Surfaces urgent moments.",
        subhelper = "Place it near the upper middle of your screen.",
    },
    {
        key = "dock",
        title = "Mythic+ Dock",
        helper = "Your run hub.",
        subhelper = "Place it where quick access feels natural.",
    },
}

local PA_ONBOARDING_D4_STEP_BY_KEY = {}
for stepIndex, descriptor in ipairs(PA_ONBOARDING_D4_STEPS) do
    descriptor.index = stepIndex
    PA_ONBOARDING_D4_STEP_BY_KEY[descriptor.key] = descriptor
end

local function PA_OnboardingD4DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, entry in pairs(value) do
        copy[PA_OnboardingD4DeepCopy(key)] = PA_OnboardingD4DeepCopy(entry)
    end
    return copy
end

local function PA_OnboardingD4Round(value)
    return math.floor(tonumber(value) or 0)
end

local function PA_OnboardingD4GetRuntime(authority)
    authority._onboardingD4 = type(authority._onboardingD4) == "table" and authority._onboardingD4 or {}
    local runtime = authority._onboardingD4
    runtime.active = runtime.active == true
    runtime.stepIndex = tonumber(runtime.stepIndex) or nil
    runtime.currentStepKey = type(runtime.currentStepKey) == "string" and runtime.currentStepKey or nil
    runtime.movedPositions = type(runtime.movedPositions) == "table" and runtime.movedPositions or {}
    runtime.stepEntryPositions = type(runtime.stepEntryPositions) == "table" and runtime.stepEntryPositions or {}
    runtime.recoverySession = type(runtime.recoverySession) == "table" and runtime.recoverySession or nil
    return runtime
end

local function PA_OnboardingD4GetMovedKeys(runtime)
    local keys = {}
    for key, value in pairs(runtime and runtime.movedPositions or {}) do
        if type(value) == "table" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    return keys
end

local function PA_OnboardingD4SetMouseDisabled(frame)
    if not frame then
        return
    end
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.SetMouseClickEnabled then
        frame:SetMouseClickEnabled(false)
    end
    if frame.SetMouseMotionEnabled then
        frame:SetMouseMotionEnabled(false)
    end
end

local function PA_OnboardingD4BuildModuleLanePosition(moduleKey)
    local y = PA_ONBOARDING_D4_MODULE_OFFSET_Y
    if moduleKey == "combatAlerts" then
        y = PA_ONBOARDING_D4_MODULE_OFFSET_Y
    end
    return {
        x = PA_ONBOARDING_D4_MODULE_OFFSET_X,
        y = y,
    }
end

local function PA_OnboardingD4GetCardWidthForStep(step)
    if step and step.index == #PA_ONBOARDING_D4_STEPS then
        return PA_ONBOARDING_D4_CARD_FINAL_WIDTH
    end
    return PA_ONBOARDING_D4_CARD_WIDTH
end

local function PA_OnboardingD4ApplyCardGeometry(card, width)
    if not card then
        return
    end
    local resolvedWidth = math.floor(tonumber(width) or PA_ONBOARDING_D4_CARD_WIDTH)
    local centerOffsetX = PA_ONBOARDING_D4_CARD_OFFSET_X + math.floor((resolvedWidth - PA_ONBOARDING_D4_CARD_WIDTH) / 2)
    card:SetSize(resolvedWidth, PA_ONBOARDING_D4_CARD_HEIGHT)
    card:ClearAllPoints()
    card:SetPoint("CENTER", UIParent, "CENTER", centerOffsetX, PA_ONBOARDING_D4_CARD_OFFSET_Y)
end

function PortalAuthority:IsOnboardingD4Active()
    return PA_OnboardingD4GetRuntime(self).active == true
end

function PortalAuthority:CanStartOnboardingD4()
    if not PA_IsOnboardingD4Enabled() then
        return false, "Guided setup is unavailable in this build."
    end
    if (InCombatLockdown and InCombatLockdown()) or self:IsPlayerInCombat() then
        return false, "Guided setup is unavailable during combat."
    end
    if PA_IsChallengeActive and PA_IsChallengeActive() then
        return false, "Guided setup is unavailable during active Mythic+ runs."
    end
    return true, "Ready."
end

function PortalAuthority:GetOnboardingD4Step(stepRef)
    if type(stepRef) == "string" then
        return PA_ONBOARDING_D4_STEP_BY_KEY[stepRef]
    end
    local index = math.floor(tonumber(stepRef) or 0)
    if index < 1 or index > #PA_ONBOARDING_D4_STEPS then
        return nil
    end
    return PA_ONBOARDING_D4_STEPS[index]
end

function PortalAuthority:HideSettingsPanelForOnboardingD4()
    local panel = SettingsPanel
    if not panel or not panel.IsShown or not panel:IsShown() then
        return
    end
    if HideUIPanel then
        HideUIPanel(panel)
        return
    end
    panel:Hide()
end

function PortalAuthority:EnsureOnboardingD4HighlightFrame()
    local runtime = PA_OnboardingD4GetRuntime(self)
    if runtime.highlight and runtime.highlight.SetBackdrop then
        return runtime.highlight
    end

    local highlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    runtime.highlight = highlight
    highlight:SetFrameStrata("TOOLTIP")
    highlight:SetFrameLevel(8)
    highlight:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    highlight:SetBackdropColor(0.52, 0.40, 0.74, 0.04)
    highlight:SetBackdropBorderColor(0.60, 0.46, 0.82, 0.55)
    highlight:Hide()
    PA_OnboardingD4SetMouseDisabled(highlight)
    return highlight
end

function PortalAuthority:HideOnboardingD4Highlight()
    local runtime = PA_OnboardingD4GetRuntime(self)
    if runtime.highlight and runtime.highlight.Hide then
        runtime.highlight:Hide()
    end
    runtime.highlightTarget = nil
end

function PortalAuthority:BindOnboardingD4HighlightToFrame(targetFrame)
    local highlight = self:EnsureOnboardingD4HighlightFrame()
    local runtime = PA_OnboardingD4GetRuntime(self)
    if not highlight or not targetFrame then
        self:HideOnboardingD4Highlight()
        return
    end

    runtime.highlightTarget = targetFrame
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", targetFrame, "TOPLEFT", -8, 8)
    highlight:SetPoint("BOTTOMRIGHT", targetFrame, "BOTTOMRIGHT", 8, -8)
    highlight:Show()
    if highlight.Raise then
        highlight:Raise()
    end
end

function PortalAuthority:EnsureOnboardingD4Card()
    local runtime = PA_OnboardingD4GetRuntime(self)
    if runtime.card then
        return runtime.card
    end

    local card = CreateFrame("Frame", "PortalAuthorityOnboardingD4Card", UIParent, "BackdropTemplate")
    runtime.card = card
    PA_OnboardingD4ApplyCardGeometry(card, PA_ONBOARDING_D4_CARD_WIDTH)
    card:SetFrameStrata("DIALOG")
    card:SetFrameLevel(128)
    card:SetToplevel(true)
    card:SetClampedToScreen(true)
    card:EnableMouse(true)
    card:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    card:SetBackdropColor(0.04, 0.05, 0.07, 0.975)
    card:SetBackdropBorderColor(0.19, 0.21, 0.27, 0.94)
    card:SetScript("OnMouseDown", function() end)
    card:SetScript("OnMouseUp", function() end)
    card:Hide()

    local shadow = CreateFrame("Frame", nil, card, "BackdropTemplate")
    shadow:SetPoint("TOPLEFT", card, "TOPLEFT", -10, 10)
    shadow:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 10, -10)
    shadow:SetFrameStrata(card:GetFrameStrata())
    shadow:SetFrameLevel(math.max(card:GetFrameLevel() - 2, 1))
    shadow:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    shadow:SetBackdropColor(0, 0, 0, 0.20)
    PA_OnboardingD4SetMouseDisabled(shadow)
    card._shadow = shadow

    local surfaceDepth = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    surfaceDepth:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    surfaceDepth:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
    surfaceDepth:SetHeight(88)
    -- Some WoW clients do not expose gradient helpers on textures, so keep this
    -- as a simple top wash instead of relying on SetGradientAlpha.
    surfaceDepth:SetTexture("Interface\\Buttons\\WHITE8x8")
    surfaceDepth:SetVertexColor(0.12, 0.13, 0.18, 0.08)
    card._surfaceDepth = surfaceDepth

    local badge = card:CreateTexture(nil, "ARTWORK")
    badge:SetTexture("Interface\\AddOns\\PortalAuthority\\Media\\Images\\PA-Large-Transparent.png")
    badge:SetSize(18, 18)
    badge:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -16)
    card._badge = badge

    local header = card:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    self:ApplyPremiumAuthoredFont(header, 11, "")
    header:SetPoint("LEFT", badge, "RIGHT", 8, 0)
    header:SetTextColor(0.75, 0.75, 0.79, 1.0)
    header:SetText("Guided Setup")
    card._header = header

    local stepCounter = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self:ApplyPremiumAuthoredFont(stepCounter, 11, "")
    stepCounter:SetPoint("TOPRIGHT", card, "TOPRIGHT", -18, -16)
    stepCounter:SetJustifyH("RIGHT")
    stepCounter:SetTextColor(0.60, 0.61, 0.66, 1.0)
    card._stepCounter = stepCounter

    local title = card:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    self:ApplyPremiumAuthoredFont(title, 23, "")
    title:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -52)
    title:SetPoint("TOPRIGHT", card, "TOPRIGHT", -18, -52)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetTextColor(0.97, 0.97, 0.98, 1.0)
    card._title = title

    local helper = card:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    self:ApplyPremiumAuthoredFont(helper, 14, "")
    helper:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    helper:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -12)
    helper:SetJustifyH("LEFT")
    helper:SetWordWrap(true)
    helper:SetSpacing(1)
    helper:SetTextColor(0.90, 0.89, 0.91, 1.0)
    card._helper = helper

    local subhelper = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self:ApplyPremiumAuthoredFont(subhelper, 13, "")
    subhelper:SetPoint("TOPLEFT", helper, "BOTTOMLEFT", 0, -5)
    subhelper:SetPoint("TOPRIGHT", helper, "BOTTOMRIGHT", 0, -5)
    subhelper:SetJustifyH("LEFT")
    subhelper:SetWordWrap(true)
    subhelper:SetSpacing(1)
    subhelper:SetTextColor(0.70, 0.71, 0.76, 1.0)
    card._subhelper = subhelper

    local settingsNote = card:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    self:ApplyPremiumAuthoredFont(settingsNote, 11, "")
    settingsNote:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 90)
    settingsNote:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -18, 90)
    settingsNote:SetJustifyH("LEFT")
    settingsNote:SetWordWrap(true)
    settingsNote:SetSpacing(1)
    settingsNote:SetTextColor(0.51, 0.52, 0.57, 1.0)
    settingsNote:SetText(PA_ONBOARDING_D4_SETTINGS_NOTE)
    settingsNote:Hide()
    card._settingsNote = settingsNote

    local function createButton(width, label, style)
        local button = CreateFrame("Button", nil, card, "BackdropTemplate")
        button:SetSize(width, 30)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        button._style = tostring(style or "secondary")

        local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        PortalAuthority:ApplyPremiumAuthoredFont(text, 12, "")
        text:SetPoint("CENTER")
        text:SetText(label)
        button._label = text

        local function refreshVisual(selfBtn, pressed)
            if not selfBtn:IsEnabled() then
                if selfBtn._style == "ghost" then
                    selfBtn:SetBackdropColor(0.05, 0.06, 0.08, 0.12)
                    selfBtn:SetBackdropBorderColor(0.18, 0.20, 0.25, 0.26)
                    selfBtn._label:SetTextColor(0.41, 0.42, 0.46, 1.0)
                elseif selfBtn._style == "primary" then
                    selfBtn:SetBackdropColor(0.10, 0.09, 0.15, 0.52)
                    selfBtn:SetBackdropBorderColor(0.26, 0.22, 0.36, 0.40)
                    selfBtn._label:SetTextColor(0.53, 0.52, 0.58, 1.0)
                else
                    selfBtn:SetBackdropColor(0.08, 0.09, 0.12, 0.46)
                    selfBtn:SetBackdropBorderColor(0.18, 0.20, 0.25, 0.36)
                    selfBtn._label:SetTextColor(0.49, 0.49, 0.53, 1.0)
                end
                return
            end

            if selfBtn._style == "primary" then
                if pressed then
                    selfBtn:SetBackdropColor(0.18, 0.14, 0.27, 0.98)
                    selfBtn:SetBackdropBorderColor(0.54, 0.40, 0.74, 0.92)
                elseif selfBtn._hover then
                    selfBtn:SetBackdropColor(0.17, 0.13, 0.25, 0.98)
                    selfBtn:SetBackdropBorderColor(0.49, 0.37, 0.68, 0.88)
                else
                    selfBtn:SetBackdropColor(0.14, 0.11, 0.21, 0.97)
                    selfBtn:SetBackdropBorderColor(0.42, 0.31, 0.58, 0.82)
                end
                selfBtn._label:SetTextColor(0.98, 0.97, 0.98, 1.0)
                return
            end

            if selfBtn._style == "ghost" then
                if pressed then
                    selfBtn:SetBackdropColor(0.08, 0.09, 0.12, 0.30)
                    selfBtn:SetBackdropBorderColor(0.24, 0.26, 0.34, 0.70)
                elseif selfBtn._hover then
                    selfBtn:SetBackdropColor(0.06, 0.07, 0.10, 0.24)
                    selfBtn:SetBackdropBorderColor(0.22, 0.25, 0.32, 0.64)
                else
                    selfBtn:SetBackdropColor(0.05, 0.06, 0.08, 0.16)
                    selfBtn:SetBackdropBorderColor(0.19, 0.21, 0.27, 0.52)
                end
                selfBtn._label:SetTextColor(0.80, 0.80, 0.84, 1.0)
                return
            end

            if pressed then
                selfBtn:SetBackdropColor(0.10, 0.11, 0.15, 0.96)
                selfBtn:SetBackdropBorderColor(0.27, 0.30, 0.38, 0.84)
            elseif selfBtn._hover then
                selfBtn:SetBackdropColor(0.09, 0.10, 0.14, 0.96)
                selfBtn:SetBackdropBorderColor(0.24, 0.27, 0.34, 0.82)
            else
                selfBtn:SetBackdropColor(0.07, 0.08, 0.11, 0.94)
                selfBtn:SetBackdropBorderColor(0.21, 0.23, 0.30, 0.76)
            end
            selfBtn._label:SetTextColor(0.87, 0.87, 0.90, 1.0)
        end

        button._refreshVisual = refreshVisual
        button:SetScript("OnEnter", function(selfBtn)
            selfBtn._hover = true
            selfBtn:_refreshVisual(false)
        end)
        button:SetScript("OnLeave", function(selfBtn)
            selfBtn._hover = nil
            selfBtn:_refreshVisual(false)
        end)
        button:SetScript("OnMouseDown", function(selfBtn)
            selfBtn:_refreshVisual(true)
        end)
        button:SetScript("OnMouseUp", function(selfBtn)
            selfBtn:_refreshVisual(false)
        end)
        button:SetScript("OnShow", function(selfBtn)
            selfBtn:_refreshVisual(false)
        end)
        button:SetScript("OnEnable", function(selfBtn)
            selfBtn:_refreshVisual(false)
        end)
        button:SetScript("OnDisable", function(selfBtn)
            selfBtn:_refreshVisual(false)
        end)
        button:Enable()
        button:_refreshVisual(false)
        return button
    end

    local function createQuietAction(label, width, fontSize, justifyH)
        local button = CreateFrame("Button", nil, card)
        button:SetSize(width or 84, 18)
        local text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        PortalAuthority:ApplyPremiumAuthoredFont(text, fontSize or 12, "")
        local justification = tostring(justifyH or "CENTER"):upper()
        if justification == "RIGHT" then
            text:SetPoint("RIGHT", button, "RIGHT", 0, 0)
            text:SetJustifyH("RIGHT")
        elseif justification == "LEFT" then
            text:SetPoint("LEFT", button, "LEFT", 0, 0)
            text:SetJustifyH("LEFT")
        else
            text:SetPoint("CENTER")
            text:SetJustifyH("CENTER")
        end
        text:SetText(label)
        text:SetTextColor(0.63, 0.63, 0.67, 1.0)
        button._label = text
        button:SetHitRectInsets(-8, -8, -5, -5)
        button:SetScript("OnEnter", function(selfBtn)
            selfBtn._label:SetTextColor(0.82, 0.82, 0.86, 1.0)
        end)
        button:SetScript("OnLeave", function(selfBtn)
            selfBtn._label:SetTextColor(0.63, 0.63, 0.67, 1.0)
        end)
        return button
    end

    local backButton = createButton(82, "Back", "ghost")
    backButton:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 50)
    card._backButton = backButton

    local nextButton = createButton(118, "Next", "primary")
    nextButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -18, 50)
    card._nextButton = nextButton

    local finishButton = createButton(118, "Finish", "primary")
    finishButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -18, 50)
    finishButton:Hide()
    card._finishButton = finishButton

    local skipButton = createQuietAction("Skip")
    skipButton:SetPoint("BOTTOM", card, "BOTTOM", 0, 18)
    card._skipButton = skipButton

    local dockSettingsButton = createQuietAction("Open Dock Settings", 138, 11, "RIGHT")
    dockSettingsButton:SetPoint("RIGHT", card, "RIGHT", -18, 0)
    dockSettingsButton:SetPoint("CENTER", skipButton, "CENTER", 105, 0)
    dockSettingsButton:Hide()
    card._dockSettingsButton = dockSettingsButton

    backButton:SetScript("OnClick", function()
        if PortalAuthority then
            PortalAuthority:ShowOnboardingD4Step((PA_OnboardingD4GetRuntime(PortalAuthority).stepIndex or 1) - 1)
        end
    end)
    nextButton:SetScript("OnClick", function()
        if PortalAuthority then
            PortalAuthority:ShowOnboardingD4Step((PA_OnboardingD4GetRuntime(PortalAuthority).stepIndex or 1) + 1)
        end
    end)
    finishButton:SetScript("OnClick", function()
        if PortalAuthority then
            local ok, response = PortalAuthority:CompleteOnboardingD4Session({
                preserveMovedPositions = true,
                exitReason = "finish",
            })
            if not ok then
                PA_PrintPortalAuthorityMessage(response or "Guided setup cleanup failed.")
            end
        end
    end)
    dockSettingsButton:SetScript("OnClick", function()
        if PortalAuthority then
            local ok, response = PortalAuthority:CompleteOnboardingD4Session({
                preserveMovedPositions = true,
                openDockSettings = true,
                exitReason = "open-dock-settings",
            })
            if not ok then
                PA_PrintPortalAuthorityMessage(response or "Guided setup cleanup failed.")
            end
        end
    end)
    skipButton:SetScript("OnClick", function()
        if PortalAuthority then
            local ok, response = PortalAuthority:CompleteOnboardingD4Session({
                preserveMovedPositions = false,
                exitReason = "skip",
            })
            if not ok then
                PA_PrintPortalAuthorityMessage(response or "Guided setup cleanup failed.")
            end
        end
    end)

    card:SetScript("OnShow", function(frame)
        frame:SetAlpha(1)
        if frame.Raise then
            frame:Raise()
        end
    end)

    return card
end

function PortalAuthority:HideOnboardingD4Card()
    local runtime = PA_OnboardingD4GetRuntime(self)
    if runtime.card and runtime.card.Hide then
        runtime.card:Hide()
    end
end

function PortalAuthority:FocusOnboardingD4Card()
    local card = self:EnsureOnboardingD4Card()
    if not card then
        return
    end
    card:Show()
    if card.Raise then
        card:Raise()
    end
end

function PortalAuthority:GetOnboardingD4ModulePosition(moduleKey)
    local db = PortalAuthorityDB or self.defaults or {}
    db.modules = db.modules or {}
    db.modules.timers = db.modules.timers or {}
    db.modules.interruptTracker = db.modules.interruptTracker or {}

    if moduleKey == "dock" then
        return {
            x = PA_OnboardingD4Round(db.dockX),
            y = PA_OnboardingD4Round(db.dockY),
        }
    end
    if moduleKey == "timers" then
        return {
            x = PA_OnboardingD4Round(db.modules.timers.x),
            y = PA_OnboardingD4Round(db.modules.timers.y),
        }
    end
    if moduleKey == "interruptTracker" then
        return {
            x = PA_OnboardingD4Round(db.modules.interruptTracker.x),
            y = PA_OnboardingD4Round(db.modules.interruptTracker.y),
        }
    end
    if moduleKey == "combatAlerts" then
        return {
            x = PA_OnboardingD4Round(db.deathAlertX),
            y = PA_OnboardingD4Round(db.deathAlertY),
        }
    end
    return nil
end

function PortalAuthority:GetOnboardingD4LiveModulePosition(moduleKey)
    local frame = self:GetOnboardingD4ActiveModuleFrame(moduleKey)
    if not frame or not frame.GetCenter then
        return nil
    end

    local cx, cy = frame:GetCenter()
    local ux, uy = nil, nil
    if UIParent and UIParent.GetCenter then
        ux, uy = UIParent:GetCenter()
    end
    if not cx or not cy or not ux or not uy then
        return nil
    end

    return {
        x = PA_OnboardingD4Round((cx - ux) + 0.5),
        y = PA_OnboardingD4Round((cy - uy) + 0.5),
    }
end

function PortalAuthority:GetOnboardingD4ActiveModuleFrame(moduleKey)
    if moduleKey == "dock" then
        return self.dockFrame
    end

    local modulesApi = self.Modules
    if moduleKey == "timers" then
        local module = modulesApi and modulesApi.registry and modulesApi.registry.timers or nil
        return module and (module.frame or module.mainFrame) or nil
    end
    if moduleKey == "interruptTracker" then
        local module = modulesApi and modulesApi.registry and modulesApi.registry.interruptTracker or nil
        return module and module.frame or nil
    end
    if moduleKey == "combatAlerts" then
        return self.DeathAlerts and self.DeathAlerts.frame or nil
    end
    return nil
end

function PortalAuthority:CaptureOnboardingD4RecoverySession()
    self:EnsureDB()
    local db = PortalAuthorityDB or self.defaults or {}
    db.modules = db.modules or {}
    db.modules.timers = db.modules.timers or {}
    db.modules.interruptTracker = db.modules.interruptTracker or {}

    return {
        version = 1,
        currentStepKey = nil,
        modules = {
            timers = {
                enabled = db.modules.timers.enabled ~= false,
                locked = db.modules.timers.locked ~= false,
                x = PA_OnboardingD4Round(db.modules.timers.x),
                y = PA_OnboardingD4Round(db.modules.timers.y),
                testMode = self.Modules and self.Modules.timersTestMode == true or false,
            },
            interruptTracker = {
                enabled = db.modules.interruptTracker.enabled ~= false,
                locked = db.modules.interruptTracker.locked ~= false,
                x = PA_OnboardingD4Round(db.modules.interruptTracker.x),
                y = PA_OnboardingD4Round(db.modules.interruptTracker.y),
            },
            combatAlerts = {
                enabled = self:IsCombatAlertsEnabled(),
                locked = db.deathAlertLocked ~= false,
                x = PA_OnboardingD4Round(db.deathAlertX),
                y = PA_OnboardingD4Round(db.deathAlertY),
                testMode = self.DeathAlerts_IsTestModeActive and self:DeathAlerts_IsTestModeActive() or false,
            },
            dock = {
                enabled = db.dockEnabled ~= false,
                locked = db.dockLocked ~= false,
                x = PA_OnboardingD4Round(db.dockX),
                y = PA_OnboardingD4Round(db.dockY),
            },
        },
    }
end

function PortalAuthority:PersistOnboardingD4RecoverySession(stepKey)
    local runtime = PA_OnboardingD4GetRuntime(self)
    if type(runtime.recoverySession) ~= "table" then
        return nil
    end
    if type(stepKey) == "string" and stepKey ~= "" then
        runtime.recoverySession.currentStepKey = stepKey
    end
    if self.Profiles_SetOnboardingD4Session then
        self:Profiles_SetOnboardingD4Session(runtime.recoverySession)
    end
    return runtime.recoverySession
end

function PortalAuthority:RefreshOnboardingD4Card()
    local runtime = PA_OnboardingD4GetRuntime(self)
    local card = self:EnsureOnboardingD4Card()
    local step = self:GetOnboardingD4Step(runtime.stepIndex)
    if not card or not step then
        return
    end

    PA_OnboardingD4ApplyCardGeometry(card, PA_OnboardingD4GetCardWidthForStep(step))

    card._stepCounter:SetText(string.format("Step %d of %d", step.index, #PA_ONBOARDING_D4_STEPS))
    card._title:SetText(step.title)
    card._helper:SetText(step.helper)
    card._subhelper:SetText(step.subhelper)

    local isFinalStep = step.index == #PA_ONBOARDING_D4_STEPS
    local isFirstStep = step.index == 1

    card._settingsNote:Hide()

    card._backButton:Show()
    card._backButton:ClearAllPoints()
    card._backButton:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 18, 50)
    if isFirstStep then
        card._backButton:Disable()
    else
        card._backButton:Enable()
    end

    if isFinalStep then
        card._nextButton:Hide()

        card._finishButton:ClearAllPoints()
        card._finishButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -18, 50)
        card._finishButton:Show()

        card._dockSettingsButton:ClearAllPoints()
        card._dockSettingsButton:SetPoint("RIGHT", card, "RIGHT", -18, 0)
        card._dockSettingsButton:SetPoint("CENTER", card._skipButton, "CENTER", 105, 0)
        card._dockSettingsButton:Show()
    else
        card._nextButton:ClearAllPoints()
        card._nextButton:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -18, 50)
        card._nextButton:Show()

        card._finishButton:Hide()
        card._dockSettingsButton:Hide()
    end

    card._skipButton:Show()
end

function PortalAuthority:SyncOnboardingD4ActiveStepPosition()
    local runtime = PA_OnboardingD4GetRuntime(self)
    if not runtime.active or not runtime.currentStepKey then
        return nil
    end

    local currentPosition = self:GetOnboardingD4LiveModulePosition(runtime.currentStepKey)
    if not currentPosition then
        currentPosition = self:GetOnboardingD4ModulePosition(runtime.currentStepKey)
    end
    local entryPosition = runtime.stepEntryPositions[runtime.currentStepKey]
    if not currentPosition or type(entryPosition) ~= "table" then
        return currentPosition
    end

    if currentPosition.x ~= PA_OnboardingD4Round(entryPosition.x) or currentPosition.y ~= PA_OnboardingD4Round(entryPosition.y) then
        runtime.movedPositions[runtime.currentStepKey] = {
            x = currentPosition.x,
            y = currentPosition.y,
        }
    end
    return currentPosition
end

function PortalAuthority:ApplyOnboardingD4DockState(stateSnapshot, positionOverride)
    self:EnsureDB()
    local db = PortalAuthorityDB or self.defaults or {}
    local pos = positionOverride or stateSnapshot or {}

    if self.InitializeDock and not self.dockFrame then
        self:InitializeDock()
    end

    db.dockEnabled = stateSnapshot.enabled ~= false
    db.dockLocked = stateSnapshot.locked ~= false
    db.dockX = PA_OnboardingD4Round(pos.x)
    db.dockY = PA_OnboardingD4Round(pos.y)

    if self.ApplyDockPosition then
        self:ApplyDockPosition()
    end
    if self.UpdateDockVisibility then
        self:UpdateDockVisibility(true)
    elseif self.RefreshDockVisibility then
        self:RefreshDockVisibility(true)
    end
    if self.UpdateDockMovableState then
        self:UpdateDockMovableState()
    end
    if self.ApplyDockCombatVisibilityDriver then
        self:ApplyDockCombatVisibilityDriver()
    end
end

function PortalAuthority:ApplyOnboardingD4TimersState(stateSnapshot, positionOverride)
    self:EnsureDB()
    local db = PortalAuthorityDB or self.defaults or {}
    db.modules = db.modules or {}
    db.modules.timers = db.modules.timers or {}
    local timersDb = db.modules.timers
    local pos = positionOverride or stateSnapshot or {}

    timersDb.enabled = stateSnapshot.enabled ~= false
    timersDb.locked = stateSnapshot.locked ~= false
    timersDb.x = PA_OnboardingD4Round(pos.x)
    timersDb.y = PA_OnboardingD4Round(pos.y)

    local modulesApi = self.Modules
    local module = modulesApi and modulesApi.registry and modulesApi.registry.timers or nil
    if module and timersDb.enabled and module.Initialize and not (module.frame or module.mainFrame) then
        module:Initialize()
    end
    if module and module.ApplyPosition then
        module:ApplyPosition()
    end
    if modulesApi and modulesApi.NotifyPositionChanged then
        modulesApi:NotifyPositionChanged("timers", timersDb.x, timersDb.y)
    end
    if module and module.SetUnlocked then
        module:SetUnlocked(not timersDb.locked)
    end
    if modulesApi and modulesApi.SetTimersTestMode then
        modulesApi:SetTimersTestMode(stateSnapshot.testMode == true)
    end
    if module and module.EvaluateVisibility then
        module:EvaluateVisibility("onboarding-d4")
    end
    if stateSnapshot.testMode == true and module and module.Tick then
        module:Tick()
    end
end

function PortalAuthority:ApplyOnboardingD4InterruptTrackerState(stateSnapshot, positionOverride)
    self:EnsureDB()
    local db = PortalAuthorityDB or self.defaults or {}
    db.modules = db.modules or {}
    db.modules.interruptTracker = db.modules.interruptTracker or {}
    local interruptDb = db.modules.interruptTracker
    local pos = positionOverride or stateSnapshot or {}

    interruptDb.enabled = stateSnapshot.enabled ~= false
    interruptDb.locked = stateSnapshot.locked ~= false
    interruptDb.x = PA_OnboardingD4Round(pos.x)
    interruptDb.y = PA_OnboardingD4Round(pos.y)

    local modulesApi = self.Modules
    local module = modulesApi and modulesApi.registry and modulesApi.registry.interruptTracker or nil
    if module and interruptDb.enabled and module.Initialize and not module.frame then
        module:Initialize()
    end
    if module and module.ApplyPosition then
        module:ApplyPosition()
    end
    if modulesApi and modulesApi.NotifyPositionChanged then
        modulesApi:NotifyPositionChanged("interruptTracker", interruptDb.x, interruptDb.y)
    end
    if module and module.SetUnlocked then
        module:SetUnlocked(not interruptDb.locked)
    end
    if module and module.EvaluateVisibility then
        module:EvaluateVisibility("onboarding-d4")
    end
end

function PortalAuthority:ApplyOnboardingD4CombatAlertsState(stateSnapshot, positionOverride)
    self:EnsureDB()
    local db = PortalAuthorityDB or self.defaults or {}
    local pos = positionOverride or stateSnapshot or {}

    if self.InitializeDeathAlerts and not (self.DeathAlerts and self.DeathAlerts.frame) then
        self:InitializeDeathAlerts()
    end

    db.combatAlertsEnabled = stateSnapshot.enabled ~= false
    db.deathAlertLocked = stateSnapshot.locked ~= false
    db.deathAlertX = PA_OnboardingD4Round(pos.x)
    db.deathAlertY = PA_OnboardingD4Round(pos.y)

    if self.ApplyCombatAlertsSettings then
        self:ApplyCombatAlertsSettings()
    end

    local shouldEnableTestMode = stateSnapshot.testMode == true
    local currentTestMode = self.DeathAlerts_IsTestModeActive and self:DeathAlerts_IsTestModeActive() or false
    if shouldEnableTestMode ~= currentTestMode and self.DeathAlerts_ToggleTestMode then
        self:DeathAlerts_ToggleTestMode()
    elseif shouldEnableTestMode and self.DeathAlerts_RefreshTestMode then
        self:DeathAlerts_RefreshTestMode()
    end
end

function PortalAuthority:ApplyOnboardingD4ModuleState(moduleKey, stateSnapshot, positionOverride)
    if moduleKey == "dock" then
        self:ApplyOnboardingD4DockState(stateSnapshot, positionOverride)
        return
    end
    if moduleKey == "timers" then
        self:ApplyOnboardingD4TimersState(stateSnapshot, positionOverride)
        return
    end
    if moduleKey == "interruptTracker" then
        self:ApplyOnboardingD4InterruptTrackerState(stateSnapshot, positionOverride)
        return
    end
    if moduleKey == "combatAlerts" then
        self:ApplyOnboardingD4CombatAlertsState(stateSnapshot, positionOverride)
    end
end

function PortalAuthority:ApplyOnboardingD4StepState(moduleKey, positionOverride)
    if moduleKey == "dock" then
        self:ApplyOnboardingD4DockState({
            enabled = true,
            locked = false,
        }, positionOverride)
        return
    end
    if moduleKey == "timers" then
        self:ApplyOnboardingD4TimersState({
            enabled = true,
            locked = false,
            testMode = true,
        }, positionOverride)
        return
    end
    if moduleKey == "interruptTracker" then
        self:ApplyOnboardingD4InterruptTrackerState({
            enabled = true,
            locked = false,
        }, positionOverride)
        return
    end
    if moduleKey == "combatAlerts" then
        self:ApplyOnboardingD4CombatAlertsState({
            enabled = true,
            locked = false,
            testMode = true,
        }, positionOverride)
    end
end

function PortalAuthority:RestoreOnboardingD4Session(session, movedPositions)
    local snapshots = session and session.modules or nil
    if type(snapshots) ~= "table" then
        return false, "Guided setup recovery session is unavailable."
    end

    self:ApplyOnboardingD4ModuleState("timers", snapshots.timers or {}, movedPositions and movedPositions.timers or nil)
    self:ApplyOnboardingD4ModuleState("interruptTracker", snapshots.interruptTracker or {}, movedPositions and movedPositions.interruptTracker or nil)
    self:ApplyOnboardingD4ModuleState("combatAlerts", snapshots.combatAlerts or {}, movedPositions and movedPositions.combatAlerts or nil)
    self:ApplyOnboardingD4ModuleState("dock", snapshots.dock or {}, movedPositions and movedPositions.dock or nil)

    if self.RefreshOptionsPanels then
        self:RefreshOptionsPanels()
    end
    if self.UpdateMoveHintTickerState then
        self:UpdateMoveHintTickerState()
    end

    return true
end

function PortalAuthority:ResetOnboardingD4RuntimeState()
    local runtime = PA_OnboardingD4GetRuntime(self)
    local previousDeferState = runtime.previousDeferSharedMarkerTickerRefresh == true

    runtime.active = false
    runtime.stepIndex = nil
    runtime.currentStepKey = nil
    runtime.movedPositions = {}
    runtime.stepEntryPositions = {}
    runtime.recoverySession = nil
    runtime.previousDeferSharedMarkerTickerRefresh = nil

    self:HideOnboardingD4Highlight()
    self:HideOnboardingD4Card()

    self._deferSharedMarkerTickerRefresh = previousDeferState and true or nil
    if self.UpdateMoveHintTickerState then
        self:UpdateMoveHintTickerState()
    end
end

function PortalAuthority:CompleteOnboardingD4Session(config)
    config = type(config) == "table" and config or {}

    local runtime = PA_OnboardingD4GetRuntime(self)
    if runtime.active then
        self:SyncOnboardingD4ActiveStepPosition()
    end

    local session = config.session
    if type(session) ~= "table" then
        session = runtime.recoverySession
    end
    if type(session) ~= "table" and self.Profiles_GetOnboardingD4Session then
        session = self:Profiles_GetOnboardingD4Session()
    end

    local movedPositions = nil
    if config.preserveMovedPositions == true then
        movedPositions = PA_OnboardingD4DeepCopy(runtime.movedPositions)
    end

    if config.strictRestore == true and type(session) ~= "table" then
        return false, "Guided setup recovery session is unavailable."
    end

    if type(session) == "table" then
        local ok, err = self:RestoreOnboardingD4Session(session, movedPositions)
        if not ok and config.strictRestore == true then
            return false, err or "Guided setup cleanup failed."
        end
    end

    if self.Profiles_ClearOnboardingD4Session then
        self:Profiles_ClearOnboardingD4Session()
    end

    self:ResetOnboardingD4RuntimeState()

    if config.openDockSettings == true then
        local opened, openErr = self:OpenCustomSettingsSectionOrRoot("dock", "onboarding-d4-open-dock-settings")
        if not opened then
            return false, openErr or "Guided setup cleaned up, but Mythic+ Dock settings are unavailable."
        end
    end

    if config.exitReason == "finish" then
        return true, "Guided setup finished."
    end
    if config.exitReason == "skip" then
        return true, "Guided setup skipped."
    end
    if config.exitReason == "open-dock-settings" then
        return true, "Guided setup finished and Mythic+ Dock settings opened."
    end
    return true, "Guided setup cleaned up."
end

function PortalAuthority:AbortOnboardingD4ForProfileMutation(reason)
    local runtime = PA_OnboardingD4GetRuntime(self)
    local persistedSession = self.Profiles_GetOnboardingD4Session and self:Profiles_GetOnboardingD4Session() or nil
    if not runtime.active and type(persistedSession) ~= "table" then
        return true
    end
    return self:CompleteOnboardingD4Session({
        preserveMovedPositions = false,
        exitReason = reason or "profile-operation",
        strictRestore = true,
        session = persistedSession,
    })
end

function PortalAuthority:ResolveAbandonedOnboardingD4Session(reason)
    local persistedSession = self.Profiles_GetOnboardingD4Session and self:Profiles_GetOnboardingD4Session() or nil
    if type(persistedSession) ~= "table" then
        return false, "No guided setup recovery session is present."
    end
    return self:CompleteOnboardingD4Session({
        preserveMovedPositions = false,
        exitReason = reason or "reload-recovery",
        session = persistedSession,
    })
end

function PortalAuthority:ShowOnboardingD4Step(stepRef)
    local runtime = PA_OnboardingD4GetRuntime(self)
    if not runtime.active then
        return false, "Guided setup is not active."
    end

    local step = self:GetOnboardingD4Step(stepRef)
    if not step then
        return false, "Requested guided setup step is unavailable."
    end

    if runtime.currentStepKey == step.key then
        self:RefreshOnboardingD4Card()
        self:FocusOnboardingD4Card()
        self:BindOnboardingD4HighlightToFrame(self:GetOnboardingD4ActiveModuleFrame(step.key))
        return true, string.format("Guided setup refocused (%s).", step.title)
    end

    self:SyncOnboardingD4ActiveStepPosition()

    if runtime.currentStepKey and runtime.recoverySession and runtime.recoverySession.modules then
        local previousSnapshot = runtime.recoverySession.modules[runtime.currentStepKey]
        local previousMovedPosition = runtime.movedPositions[runtime.currentStepKey]
        if previousSnapshot then
            self:ApplyOnboardingD4ModuleState(runtime.currentStepKey, previousSnapshot, previousMovedPosition)
        end
    end

    runtime.stepIndex = step.index
    runtime.currentStepKey = step.key
    self:PersistOnboardingD4RecoverySession(step.key)

    local position = runtime.movedPositions[step.key]
    if type(position) ~= "table" then
        position = PA_OnboardingD4BuildModuleLanePosition(step.key)
    end
    self:ApplyOnboardingD4StepState(step.key, position)
    runtime.stepEntryPositions[step.key] = {
        x = PA_OnboardingD4Round(position.x),
        y = PA_OnboardingD4Round(position.y),
    }

    self:RefreshOnboardingD4Card()
    self:FocusOnboardingD4Card()

    local targetFrame = self:GetOnboardingD4ActiveModuleFrame(step.key)
    self:BindOnboardingD4HighlightToFrame(targetFrame)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            local currentRuntime = PA_OnboardingD4GetRuntime(PortalAuthority)
            if currentRuntime.active and currentRuntime.currentStepKey == step.key then
                PortalAuthority:BindOnboardingD4HighlightToFrame(PortalAuthority:GetOnboardingD4ActiveModuleFrame(step.key))
            end
        end)
    end

    if self.RefreshOptionsPanels then
        self:RefreshOptionsPanels()
    end

    return true, string.format("Guided setup step ready (%s).", step.title)
end

function PortalAuthority:StartOnboardingD4Tour(reason)
    local canStart, blockMessage = self:CanStartOnboardingD4()
    if not canStart then
        return false, blockMessage
    end

    local runtime = PA_OnboardingD4GetRuntime(self)
    if runtime.active then
        self:RefreshOnboardingD4Card()
        self:FocusOnboardingD4Card()
        self:BindOnboardingD4HighlightToFrame(self:GetOnboardingD4ActiveModuleFrame(runtime.currentStepKey))
        return true, string.format("Guided setup already active (%s).", tostring(reason or "manual"))
    end

    local staleSession = self.Profiles_GetOnboardingD4Session and self:Profiles_GetOnboardingD4Session() or nil
    if type(staleSession) == "table" then
        local okStale = self:ResolveAbandonedOnboardingD4Session("stale-session")
        if not okStale then
            return false, "Guided setup could not recover the previous session."
        end
        runtime = PA_OnboardingD4GetRuntime(self)
    end

    self:HidePremiumWelcome()
    self:HideSettingsPanelForOnboardingD4()

    runtime.active = true
    runtime.stepIndex = nil
    runtime.currentStepKey = nil
    runtime.movedPositions = {}
    runtime.stepEntryPositions = {}
    runtime.recoverySession = self:CaptureOnboardingD4RecoverySession()
    runtime.previousDeferSharedMarkerTickerRefresh = self._deferSharedMarkerTickerRefresh == true

    self._deferSharedMarkerTickerRefresh = true
    if self.UpdateMoveHintTickerState then
        self:UpdateMoveHintTickerState()
    end

    if self.Profiles_SetOnboardingD4Session then
        self:Profiles_SetOnboardingD4Session(runtime.recoverySession)
    end

    self:EnsureOnboardingD4Card()
    return self:ShowOnboardingD4Step(1)
end

function PortalAuthority:GetOnboardingD4StatusLines()
    local runtime = PA_OnboardingD4GetRuntime(self)
    local session = runtime.recoverySession
    if type(session) ~= "table" and self.Profiles_GetOnboardingD4Session then
        session = self:Profiles_GetOnboardingD4Session()
    end

    if runtime.active then
        self:SyncOnboardingD4ActiveStepPosition()
    end

    local step = self:GetOnboardingD4Step(runtime.currentStepKey or runtime.stepIndex or (session and session.currentStepKey))
    local movedKeys = PA_OnboardingD4GetMovedKeys(runtime)
    local movedLabels = {}
    for _, key in ipairs(movedKeys) do
        local descriptor = self:GetOnboardingD4Step(key)
        movedLabels[#movedLabels + 1] = descriptor and descriptor.title or key
    end

    local lines = {}
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r D3 gate=%s", PA_IsOnboardingD3DevGateEnabled() and "ON" or "OFF")
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r D4 gate=%s", PA_IsOnboardingD4DevGateEnabled() and "ON" or "OFF")
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r D4 active=%s", tostring(runtime.active))
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r currentStep=%s", step and string.format("%d/%d (%s)", step.index, #PA_ONBOARDING_D4_STEPS, step.title) or "nil")
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r recoverySession=%s", type(session) == "table" and "present" or "missing")
    lines[#lines + 1] = string.format("|cffffd100Portal Authority:|r moved=%s", #movedLabels > 0 and table.concat(movedLabels, ", ") or "none")
    return lines
end

function PortalAuthority:HandleOnboardingD4Slash(rawAction)
    local action = trim(tostring(rawAction or "")):lower()
    if action == "" or action == "help" then
        PA_PrintPortalAuthorityMessage("usage: /pa dev onboarding-d4 status|start|stop")
        return true
    end

    if action == "status" then
        for _, line in ipairs(self:GetOnboardingD4StatusLines()) do
            print(line)
        end
        return true
    end

    if action == "start" then
        local ok, response = self:StartOnboardingD4Tour("dev-start")
        PA_PrintPortalAuthorityMessage(response or (ok and "Guided setup started." or "Guided setup failed."))
        return true
    end

    if action == "stop" then
        local ok, response = self:CompleteOnboardingD4Session({
            preserveMovedPositions = false,
            exitReason = "dev-stop",
        })
        PA_PrintPortalAuthorityMessage(response or (ok and "Guided setup stopped." or "Guided setup cleanup failed."))
        return true
    end

    PA_PrintPortalAuthorityMessage("usage: /pa dev onboarding-d4 status|start|stop")
    return true
end

function PortalAuthority:_OnboardingEnsureMarkers(timersFrameOrHandle, dockFrame, deathHandle)
    self._onboardingMarkers = self._onboardingMarkers or {}
    self._onboardingMarkerActive = self._onboardingMarkerActive or {}

    local markers = self._onboardingMarkers
    local active = self._onboardingMarkerActive
    local fontPath = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    local timersModule = self.Modules and self.Modules.registry and self.Modules.registry.timers
    local timersAnchor = timersFrameOrHandle or (timersModule and (timersModule.dragHandle or timersModule.frame or timersModule.mainFrame)) or nil
    local dockAnchor = dockFrame or self.dockFrame or nil
    local deathAnchor = deathHandle or (self.DeathAlerts and self.DeathAlerts.handle) or nil

    local function ensureMarker(key, labelText)
        local fs = markers[key]
        if not fs then
            fs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            fs:SetFont(fontPath, 32, "OUTLINE")
            fs:SetTextColor(1, 0, 0, 1)
            fs:SetJustifyH("CENTER")
            fs:SetJustifyV("MIDDLE")
            markers[key] = fs
        end
        fs:SetText(labelText)
        return fs
    end

    local timersLabel = ensureMarker("timers", "Timers")
    timersLabel:ClearAllPoints()
    if timersAnchor then
        local timersOffsetY = 10
        if timersModule and timersModule.dragHandle and timersAnchor == timersModule.dragHandle then
            timersOffsetY = 6
        end
        timersLabel:SetPoint("BOTTOM", timersAnchor, "TOP", 0, timersOffsetY)
        timersLabel:Show()
        active.timers = true
    else
        timersLabel:Hide()
        active.timers = false
    end

    local dockLabel = ensureMarker("dock", "M+ Dock")
    dockLabel:ClearAllPoints()
    if dockAnchor then
        dockLabel:SetPoint("BOTTOM", dockAnchor, "TOP", 0, 54)
        dockLabel:Show()
        active.dock = true
    else
        dockLabel:Hide()
        active.dock = false
    end

    local deathLabel = ensureMarker("death", "Combat Alerts")
    deathLabel:ClearAllPoints()
    if deathAnchor then
        deathLabel:SetPoint("BOTTOM", deathAnchor, "TOP", 0, 6)
        deathLabel:Show()
        active.death = true
    else
        deathLabel:Hide()
        active.death = false
    end
end

function PortalAuthority:_OnboardingUpdateMarkers(blinkOn)
    if not self._onboardingMarkers then
        return
    end

    local markers = self._onboardingMarkers
    local active = self._onboardingMarkerActive or {}
    local db = PortalAuthorityDB

    local function updateMarker(key, shouldShow)
        local fs = markers[key]
        if not fs then return end
        if not shouldShow or active[key] == false then
            fs:Hide()
            return
        end
        fs:SetAlpha(blinkOn and 1 or 0.15)
        fs:Show()
    end

    local function getMoveHintSurfaceUnlockState()
        local dockUnlocked = db and (PA_SafeBool(db.dockEnabled) and not PA_SafeBool(db.dockLocked)) or false
        local timersDb = db and db.modules and db.modules.timers or nil
        local timersEnabled = timersDb and timersDb.enabled ~= false or false
        local timersUnlocked = timersEnabled and timersDb and timersDb.locked == false or false
        local combatAlertsEnabled = (self.IsCombatAlertsEnabled and self:IsCombatAlertsEnabled())
        if combatAlertsEnabled == nil then
            combatAlertsEnabled = db and db.combatAlertsEnabled ~= false or false
        end
        local deathUnlocked = combatAlertsEnabled and db and (not PA_SafeBool(db.deathAlertLocked)) or false
        return dockUnlocked, timersUnlocked, deathUnlocked
    end

    local dockUnlocked, timersUnlocked, deathUnlocked = getMoveHintSurfaceUnlockState()

    updateMarker("dock", dockUnlocked)
    updateMarker("timers", timersUnlocked)
    updateMarker("death", deathUnlocked)
end

function PortalAuthority:ShouldRunMoveHintTicker()
    local db = PortalAuthorityDB

    if self.IsOnboardingD4Active and self:IsOnboardingD4Active() then
        return false
    end

    local dockUnlocked = db and (PA_SafeBool(db.dockEnabled) and not PA_SafeBool(db.dockLocked)) or false
    local timersDb = db and db.modules and db.modules.timers or nil
    local timersEnabled = timersDb and timersDb.enabled ~= false or false
    local timersUnlocked = timersEnabled and timersDb and timersDb.locked == false or false
    local combatAlertsEnabled = (self.IsCombatAlertsEnabled and self:IsCombatAlertsEnabled())
    if combatAlertsEnabled == nil then
        combatAlertsEnabled = db and db.combatAlertsEnabled ~= false or false
    end
    local deathUnlocked = combatAlertsEnabled and db and (not PA_SafeBool(db.deathAlertLocked)) or false
    return dockUnlocked or timersUnlocked or deathUnlocked
end

function PortalAuthority:RefreshMoveHintMarkersImmediate(forceEnsure)
    if self._deferSharedMarkerTickerRefresh then
        return
    end
    if not (self._OnboardingEnsureMarkers and self._OnboardingUpdateMarkers) then
        return
    end

    local shouldEnsure = forceEnsure or self._onboardingMarkers or self:ShouldRunMoveHintTicker()
    if shouldEnsure then
        self:_OnboardingEnsureMarkers()
    end
    if self._onboardingMarkers then
        self:_OnboardingUpdateMarkers(self._moveHintBlink == true)
    end
end

function PortalAuthority:StopMoveHintTicker()
    if self._moveHintTicker and self._moveHintTicker.Cancel then
        self._moveHintTicker:Cancel()
    end
    self._moveHintTicker = nil
end

function PortalAuthority:EnsureMoveHintTicker()
    if PA_IsUiSurfaceGateEnabled() then
        self:StopMoveHintTicker()
        return
    end
    if self._moveHintTicker or not self:ShouldRunMoveHintTicker() then
        return
    end
    if not (C_Timer and C_Timer.NewTicker) then
        return
    end

    if self._moveHintBlink == nil then
        self._moveHintBlink = false
    end
    self:RefreshMoveHintMarkersImmediate(true)
    self._moveHintTicker = C_Timer.NewTicker(0.5, function()
        local perfStart, perfState = self:PerfBegin("movehint_ticker")
        self:CpuDiagCount("movehint_ticker")
        local ok = pcall(function()
            if not self:ShouldRunMoveHintTicker() then
                self:StopMoveHintTicker()
                self._moveHintBlink = false
                if self._onboardingMarkers then
                    self:_OnboardingUpdateMarkers(false)
                end
                return
            end

            self._moveHintBlink = not self._moveHintBlink
            self:RefreshMoveHintMarkersImmediate(true)
        end)
        self:PerfEnd("movehint_ticker", perfStart, perfState)
        if not ok then
            -- Keep ticker alive; retry on next tick.
        end
    end)
end

function PortalAuthority:UpdateMoveHintTickerState()
    if PA_IsUiSurfaceGateEnabled() then
        self:StopMoveHintTicker()
        self._moveHintBlink = false
        if self._onboardingMarkers then
            for _, fs in pairs(self._onboardingMarkers) do
                if fs and fs.Hide then
                    fs:Hide()
                end
            end
        end
        return
    end
    if self._deferSharedMarkerTickerRefresh then
        return
    end
    local shouldRun = self:ShouldRunMoveHintTicker()
    if shouldRun then
        if self._moveHintBlink == nil then
            self._moveHintBlink = false
        end
        self:RefreshMoveHintMarkersImmediate(true)
        self:EnsureMoveHintTicker()
        return
    end

    self:StopMoveHintTicker()
    self._moveHintBlink = false
    if self._onboardingMarkers then
        self:_OnboardingUpdateMarkers(false)
    end
end

function PortalAuthority:ApplyGlobalFont(object, size, flags)
    if not object or not object.SetFont then
        return
    end

    local fontPath, defaultFlags = self:GetGlobalFontPath()
    object:SetFont(fontPath, size or select(2, object:GetFont()) or 12, flags or defaultFlags)
end

function PortalAuthority:GetSpellData(spellID)
    return spellID and self.SpellMap[spellID] or nil
end

function PortalAuthority:GetCategoryForSpell(spellID)
    local data = self:GetSpellData(spellID)
    return data and data.category or nil
end

function PortalAuthority:IsWatchedSpell(spellID)
    return self:GetSpellData(spellID) ~= nil
end

function PortalAuthority:GetDestinationForSpell(spellID)
    if spellID == 8690 or spellID == 556 then
        local bindLocation = GetBindLocation and trim(GetBindLocation() or "") or ""
        if bindLocation ~= "" then
            return bindLocation
        end
    end

    local data = self:GetSpellData(spellID)
    return data and data.dest or nil
end

function PortalAuthority:GetTemplateForCategory(category)
    local db = PortalAuthorityDB or self.defaults

    if category == "portals" then
        return trim(db.portalsText) ~= "" and db.portalsText or self.defaults.portalsText
    elseif category == "teleports" then
        return trim(db.teleportsText) ~= "" and db.teleportsText or self.defaults.teleportsText
    elseif category == "mplus" then
        return trim(db.mplusText) ~= "" and db.mplusText or self.defaults.mplusText
    elseif category == "warlockSummoning" then
        return trim(db.warlockSummoningText) ~= "" and db.warlockSummoningText or self.defaults.warlockSummoningText
    end

    return nil
end

function PortalAuthority:IsCategoryEnabled(category)
    local db = PortalAuthorityDB or self.defaults

    if category == "portals" then
        return db.portalsEnabled
    elseif category == "teleports" then
        return db.teleportsEnabled
    elseif category == "mplus" then
        return db.mplusEnabled
    elseif category == "warlockSummoning" then
        return db.warlockSummoningEnabled
    end

    return false
end

function PortalAuthority:BuildMessage(template, spellID)
    local spellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if trim(spellName) == "" then
        spellName = "Unknown Spell"
    end

    local destName = self:GetDestinationForSpell(spellID)
    if trim(destName) == "" then
        destName = spellName
    end

    local finalTemplate = trim(template) ~= "" and template or self.defaults.portalsText
    return finalTemplate
        :gsub("{spell}", spellName)
        :gsub("%[spell%]", spellName)
        :gsub("%[destination%]", destName)
        :gsub("{dest}", destName)
end

function PortalAuthority:GetChatType(category)
    if IsInRaid and IsInRaid() then
        return "RAID"
    end
    if IsInGroup and IsInGroup() then
        return "PARTY"
    end

    return nil
end

PortalAuthority.lastAnnouncedCastKey = nil

function PortalAuthority:BuildCastKey(castGUID, spellID)
    if castGUID and castGUID ~= "" then
        return castGUID
    end
    return string.format("%s:%d", tostring(spellID), math.floor(GetTime() * 10))
end

local function PA_IsChallengeActive()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
end

local PA_MPLUS_NOTICE_SHOWN = false

local function PA_MaybeShowMPlusNotice()
    if PA_MPLUS_NOTICE_SHOWN then return end
    PA_MPLUS_NOTICE_SHOWN = true
    local msg = "|cffE88BC7Portal Authority:|r Announcements are disabled during active Mythic+ runs due to current 12.0.1 protected chat restrictions. Announcements will work normally outside active keys."
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    else
        print(msg)
    end
end

function PortalAuthority:TryAnnounce(spellID, castGUID)
    if not self:IsWatchedSpell(spellID) then return end

    local category = self:GetCategoryForSpell(spellID)
    if not category or not self:IsCategoryEnabled(category) then return end

    if PA_IsChallengeActive() then
        PA_MaybeShowMPlusNotice()
        return
    end

    local castKey = self:BuildCastKey(castGUID, spellID)
    if castKey == self.lastAnnouncedCastKey then return end

    local chatType = self:GetChatType(category)
    if not chatType then return end

    if PA_IsChallengeActive and PA_IsChallengeActive() and category == "warlockSummoning" then
        return
    end

    if category == "warlockSummoning" then
        chatType = "SAY"
    end

    local message = self:BuildMessage(self:GetTemplateForCategory(category), spellID)
    if trim(message) == "" then return end

    if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
        C_ChatInfo.SendChatMessage(message, chatType)
    elseif type(SendChatMessage) == "function" then
        SendChatMessage(message, chatType)
    end

    self.lastAnnouncedCastKey = castKey
end

PortalAuthority.lastSummonPopupBySender = PortalAuthority.lastSummonPopupBySender or {}
PortalAuthority.lastSummonRequestSoundAt = PortalAuthority.lastSummonRequestSoundAt or 0
PortalAuthority.summonRequestTimestamps = PortalAuthority.summonRequestTimestamps or {}
PortalAuthority.lastSummonStonePopupBySender = PortalAuthority.lastSummonStonePopupBySender or {}
PortalAuthority.lastSummonStoneRequestSoundAt = PortalAuthority.lastSummonStoneRequestSoundAt or 0
PortalAuthority.summonStoneRequestTimestamps = PortalAuthority.summonStoneRequestTimestamps or {}
PortalAuthority.lastWarlockSummoningAnnouncement = PortalAuthority.lastWarlockSummoningAnnouncement or nil
PortalAuthority.summonDebugEnabled = PortalAuthority.summonDebugEnabled or false

local function PA_SummonDebugValue(value)
    if value == nil then
        return "nil"
    end
    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" then
        return text
    end
    return "<unprintable>"
end

function PortalAuthority:SummonDebugTrace(kind, stage, event, sender, senderGUID, message)
    if not self.summonDebugEnabled then
        return
    end

    local normalizedMessage = self.NormalizeChatMessage and self:NormalizeChatMessage(message) or ""
    local normalizedSender = self.NormalizeSenderName and self:NormalizeSenderName(sender) or PA_SummonDebugValue(sender)
    local guidState = PA_NormalizeSafeString(senderGUID) and "guid" or "noguid"
    print(string.format(
        "|cffffd100Portal Authority SummonDebug:|r %s %s event=%s sender=%s %s msg=%s",
        tostring(kind or "?"),
        tostring(stage or "?"),
        tostring(event or "?"),
        tostring(normalizedSender or "?"),
        guidState,
        tostring(normalizedMessage or "")
    ))
end

function PortalAuthority:RememberWarlockSummoningAnnouncement(message, chatType)
    if trim(message) == "" or trim(chatType) == "" then
        self.lastWarlockSummoningAnnouncement = nil
        return
    end

    self.lastWarlockSummoningAnnouncement = {
        message = message,
        chatType = chatType,
        sentAt = GetTime(),
    }
end

function PortalAuthority:GetSummonChatTypeForEvent(event)
    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" then
        return "RAID"
    end

    if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        return "PARTY"
    end

    return nil
end

function PortalAuthority:IsSenderPlayer(sender, senderGUID)
    local normalizedSenderGUID = PA_NormalizeSafeString(senderGUID)
    if normalizedSenderGUID and PA_SafeStringsEqual(PA_SafeUnitGUID("player"), normalizedSenderGUID) then
        return true
    end

    local playerName = UnitName("player")
    if trim(playerName) == "" then
        return false
    end

    return self:NormalizeSenderName(sender):lower() == self:NormalizeSenderName(playerName):lower()
end

function PortalAuthority:ShouldSuppressOwnWarlockSummoningAnnouncement(event, message, sender, senderGUID)
    local outgoing = self.lastWarlockSummoningAnnouncement
    if not outgoing then
        return false
    end

    local eventChatType = self:GetSummonChatTypeForEvent(event)
    if not eventChatType or eventChatType ~= outgoing.chatType then
        return false
    end

    if message ~= outgoing.message then
        return false
    end

    if not self:IsSenderPlayer(sender, senderGUID) then
        return false
    end

    if (GetTime() - (outgoing.sentAt or 0)) > WARLOCK_SUMMON_ANNOUNCEMENT_SUPPRESSION_SECONDS then
        return false
    end

    return true
end

function PortalAuthority:NormalizeChatMessage(message)
    if type(message) ~= "string" then
        return ""
    end

    local ok, normalized = pcall(function()
        local text = message:lower()
        text = text:gsub("[%p%c]", " ")
        text = text:gsub("%s+", " ")
        text = text:gsub("^%s+", ""):gsub("%s+$", "")
        return text
    end)
    if ok and type(normalized) == "string" then
        return normalized
    end
    return ""
end

function PortalAuthority:IsSummonKeywordMessage(message)
    local normalized = self:NormalizeChatMessage(message)
    if normalized == "" then
        return false
    end

    for token in normalized:gmatch("%S+") do
        if token == "123" or token == "1" or SUMMON_REQUEST_KEYWORD_TOKENS[token] then
            return true
        end
    end

    return false
end

function PortalAuthority:IsSummonStoneKeywordMessage(message)
    local normalized = self:NormalizeChatMessage(message)
    if normalized == "" then
        return false
    end

    for token in normalized:gmatch("%S+") do
        if SUMMON_STONE_REQUEST_KEYWORD_TOKENS[token] then
            return true
        end
    end

    return false
end

function PortalAuthority:NormalizeSenderName(sender)
    if type(sender) ~= "string" then
        return "Unknown"
    end

    local ok, normalized = pcall(function()
        if Ambiguate then
            return Ambiguate(sender, "short")
        end
        return sender:match("^[^-]+") or sender
    end)
    if ok and type(normalized) == "string" and normalized ~= "" then
        return normalized
    end
    return "Unknown"
end

function PortalAuthority:GetClassHexColor(classFile)
    if trim(classFile) == "" then
        return nil
    end

    local classColor = nil
    if C_ClassColor and C_ClassColor.GetClassColor then
        classColor = C_ClassColor.GetClassColor(classFile)
    elseif RAID_CLASS_COLORS then
        classColor = RAID_CLASS_COLORS[classFile]
    end

    if not classColor then
        return nil
    end

    if classColor.GenerateHexColor then
        return classColor:GenerateHexColor()
    end

    if classColor.colorStr then
        return classColor.colorStr
    end

    if classColor.r and classColor.g and classColor.b then
        return string.format("ff%02x%02x%02x", math.floor(classColor.r * 255), math.floor(classColor.g * 255), math.floor(classColor.b * 255))
    end

    return nil
end

function PortalAuthority:GetGroupUnitClassBySender(sender, senderGUID)
    local normalizedSender = self:NormalizeSenderName(sender):lower()
    local normalizedSenderGUID = PA_NormalizeSafeString(senderGUID)

    local function matchesUnit(unit)
        if not UnitExists(unit) then
            return false
        end

        if normalizedSenderGUID and PA_SafeStringsEqual(PA_SafeUnitGUID(unit), normalizedSenderGUID) then
            return true
        end

        local unitName = UnitName(unit)
        if trim(unitName) == "" then
            return false
        end

        return self:NormalizeSenderName(unitName):lower() == normalizedSender
    end

    local function getClassFromUnit(unit)
        if not matchesUnit(unit) then
            return nil
        end

        local _, classFile = UnitClass(unit)
        return classFile
    end

    if IsInRaid and IsInRaid() then
        local raidCount = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, raidCount do
            local classFile = getClassFromUnit("raid" .. index)
            if classFile then
                return classFile
            end

            if GetRaidRosterInfo then
                local name, _, _, _, _, classFilename = GetRaidRosterInfo(index)
                if trim(name) ~= "" and self:NormalizeSenderName(name):lower() == normalizedSender and trim(classFilename) ~= "" then
                    return classFilename
                end
            end
        end
    elseif IsInGroup and IsInGroup() then
        local partyCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for index = 1, partyCount do
            local classFile = getClassFromUnit("party" .. index)
            if classFile then
                return classFile
            end
        end

        local classFile = getClassFromUnit("player")
        if classFile then
            return classFile
        end
    end

    return nil
end

function PortalAuthority:GetSenderClassForSummon(event, sender, senderGUID)
    if event == "CHAT_MSG_WHISPER" then
        if not self:IsUnitInCurrentGroup(sender, senderGUID) then
            return nil
        end
    end

    return self:GetGroupUnitClassBySender(sender, senderGUID)
end

function PortalAuthority:GetClassColoredSenderName(event, sender, senderGUID)
    local playerName = self:NormalizeSenderName(sender)
    local classFile = self:GetSenderClassForSummon(event, sender, senderGUID)
    if not classFile then
        return playerName
    end

    local hexColor = self:GetClassHexColor(classFile)
    if trim(hexColor) == "" then
        return playerName
    end

    return string.format("|c%s%s|r", hexColor, playerName)
end

function PortalAuthority:ShowSummonPopup(event, sender, senderGUID)
    local playerName = self:GetClassColoredSenderName(event, sender, senderGUID)
    local icon = 136223
    local message = string.format("|T%s:0|t Summon for %s", tostring(icon), playerName)

    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo.RAID_WARNING)
        return
    end

    UIErrorsFrame:AddMessage(message, 1, 0.82, 0, 1, 3)
end

function PortalAuthority:IsWarlockPlayer()
    local _, classFile = UnitClass("player")
    return classFile == "WARLOCK"
end

function PortalAuthority:IsPlayerInCombat()
    return UnitAffectingCombat and UnitAffectingCombat("player")
end

function PortalAuthority:ShouldThrottleSummonPopup(sender)
    local playerName = self:NormalizeSenderName(sender)
    local now = GetTime()
    local lastShown = self.lastSummonPopupBySender[playerName]

    if lastShown and (now - lastShown) < SUMMON_SENDER_COOLDOWN_SECONDS then
        return true
    end

    self.lastSummonPopupBySender[playerName] = now
    return false
end

function PortalAuthority:IsSummonBurstLimited()
    local now = GetTime()
    local windowStart = now - SUMMON_BURST_WINDOW_SECONDS

    local kept = {}
    for _, ts in ipairs(self.summonRequestTimestamps) do
        if ts >= windowStart then
            table.insert(kept, ts)
        end
    end
    self.summonRequestTimestamps = kept

    if #self.summonRequestTimestamps >= SUMMON_BURST_WINDOW_MAX then
        return true
    end

    table.insert(self.summonRequestTimestamps, now)
    return false
end

local function PA_ResolveConfiguredSound(selected)
    if selected == nil or selected == "" then
        return nil
    end

    if PortalAuthority and PortalAuthority.Media and PortalAuthority.Media.ResolveSoundFile then
        local resolved = PortalAuthority.Media.ResolveSoundFile(selected)
        if resolved ~= nil and resolved ~= "" then
            return resolved
        end
    end

    if type(selected) == "number" then
        return selected
    end

    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    if lsm and lsm.Fetch then
        local media = lsm:Fetch("sound", selected, true)
        if media and media ~= "" then
            return media
        end
    end

    return selected
end

function PortalAuthority:GetSummonRequestSoundFile()
    local selected = PortalAuthorityDB and PortalAuthorityDB.summonRequestSound
    return PA_ResolveConfiguredSound(selected)
end

function PortalAuthority:GetBuiltinSummonAlertSounds()
    return BUILTIN_SUMMON_ALERT_SOUNDS
end

function PortalAuthority:PlaySummonRequestSound()
    local soundFile = self:GetSummonRequestSoundFile()
    if not soundFile then
        return
    end

    local now = GetTime()
    if (now - (self.lastSummonRequestSoundAt or 0)) < SUMMON_SOUND_GLOBAL_COOLDOWN_SECONDS then
        return
    end

    local channel = "Master"

    self.lastSummonRequestSoundAt = now
    if type(soundFile) == "number" and PlaySound then
        PlaySound(soundFile, channel)
    elseif PlaySoundFile then
        PlaySoundFile(soundFile, channel)
    end
end

function PortalAuthority:GetSummonStoneRequestSoundFile()
    local selected = PortalAuthorityDB and PortalAuthorityDB.summonStoneRequestSound
    return PA_ResolveConfiguredSound(selected)
end

function PortalAuthority:PlaySummonStoneRequestSound()
    local soundFile = self:GetSummonStoneRequestSoundFile()
    if not soundFile then
        return
    end

    local now = GetTime()
    if (now - (self.lastSummonStoneRequestSoundAt or 0)) < SUMMON_SOUND_GLOBAL_COOLDOWN_SECONDS then
        return
    end

    local channel = "Master"

    self.lastSummonStoneRequestSoundAt = now
    if type(soundFile) == "number" and PlaySound then
        PlaySound(soundFile, channel)
    elseif PlaySoundFile then
        PlaySoundFile(soundFile, channel)
    end
end

function PortalAuthority:GetDeathAlertSoundFile(selected)
    return PA_ResolveConfiguredSound(selected)
end

PA_IsSecretValue = function(value)
    if hasanysecretvalues then
        local ok, secret = pcall(hasanysecretvalues, value)
        if ok and secret then
            return true
        end
    end
    return false
end

PA_NormalizeSafeString = function(value)
    if type(value) ~= "string" or PA_IsSecretValue(value) then
        return nil
    end
    return value
end

PA_SafeStringsEqual = function(left, right)
    local normalizedLeft = PA_NormalizeSafeString(left)
    local normalizedRight = PA_NormalizeSafeString(right)
    return normalizedLeft ~= nil and normalizedRight ~= nil and normalizedLeft == normalizedRight
end

PA_SafeUnitGUID = function(unit)
    if type(unit) ~= "string" or unit == "" or not UnitGUID then
        return nil
    end
    local ok, guid = pcall(UnitGUID, unit)
    if ok then
        return PA_NormalizeSafeString(guid)
    end
    return nil
end

local function PA_BitBand(a, b)
    if bit and bit.band then
        return bit.band(a, b)
    end
    if bit32 and bit32.band then
        return bit32.band(a, b)
    end
    return 0
end

local function PA_GetRoleIconTag(role)
    if role == "TANK" then
        return "|A:groupfinder-icon-role-large-tank:15:15|a"
    elseif role == "HEALER" then
        return "|A:groupfinder-icon-role-large-healer:15:15|a"
    end
    return "|A:groupfinder-icon-role-large-dps:15:15|a"
end

local function PA_GetDeathAlertPreviewSample(roleKey)
    if roleKey == "HEALER" then
        return "HEALER", "SHAMAN", "Shiftus"
    elseif roleKey == "DPS" then
        return "DAMAGER", "WARRIOR", "Streetw"
    end
    return "TANK", "PALADIN", "Streetxo"
end

function PortalAuthority:DeathAlerts_StopPreviewTicker()
    self.DeathAlerts = self.DeathAlerts or {}
    if self.DeathAlerts.previewTicker and self.DeathAlerts.previewTicker.Cancel then
        self.DeathAlerts.previewTicker:Cancel()
    end
    self.DeathAlerts.previewTicker = nil
    self.DeathAlerts.previewIndex = nil
    self.DeathAlerts.previewPool = nil
end

function PortalAuthority:DeathAlerts_BuildPreviewRolePool(db)
    local pool = {}
    if PA_SafeBool(db and db.deathAlertTankEnabled) then
        pool[#pool + 1] = "TANK"
    end
    if PA_SafeBool(db and db.deathAlertHealerEnabled) then
        pool[#pool + 1] = "HEALER"
    end
    if PA_SafeBool(db and db.deathAlertDpsEnabled) then
        pool[#pool + 1] = "DPS"
    end
    if #pool == 0 then
        pool[1] = "TANK"
    end
    return pool
end

function PortalAuthority:DeathAlerts_RenderPreviewRole(roleKey)
    local db = PortalAuthorityDB or self.defaults
    local roleToken, classFile, sampleName = PA_GetDeathAlertPreviewSample(roleKey)
    local template = trim(db and db.deathAlertMessageTemplate or "")
    if template == "" then
        template = "[role] Died: [name]"
    end
    local message = self:DeathAlerts_FormatMessage(template, roleToken, classFile, sampleName)
    if PA_SafeBool(db and db.deathAlertShowRoleIcon) then
        message = (PA_GetRoleIconTag and PA_GetRoleIconTag(roleToken) or "") .. " " .. message
    end
    self:DeathAlerts_Show(message, 0)
end

function PortalAuthority:DeathAlerts_ApplyUnlockedPreview()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    local perfStart, perfState = self:PerfBegin("deathalerts_unlocked_preview")
    local function finish(...)
        if perfStart ~= nil then
            self:PerfEnd("deathalerts_unlocked_preview", perfStart, perfState)
        end
        return ...
    end

    if not PortalAuthorityDB then
        return finish()
    end

    self:DeathAlerts_EnsureFrame()
    self.DeathAlerts = self.DeathAlerts or {}

    if InCombatLockdown and InCombatLockdown() then
        self:DeathAlerts_StopPreviewTicker()
        if self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        return finish()
    end

    local pool = self:DeathAlerts_BuildPreviewRolePool(PortalAuthorityDB)
    self.DeathAlerts.previewPool = pool
    local index = tonumber(self.DeathAlerts.previewIndex) or 1
    if index < 1 or index > #pool then
        index = 1
    end
    self.DeathAlerts.previewIndex = index
    self:DeathAlerts_RenderPreviewRole(pool[index])

    if #pool <= 1 then
        self:DeathAlerts_StopPreviewTicker()
        self.DeathAlerts.previewPool = pool
        self.DeathAlerts.previewIndex = 1
        self:DeathAlerts_RenderPreviewRole(pool[1])
        return finish()
    end

    if self.DeathAlerts.previewTicker and self.DeathAlerts.previewTicker.Cancel then
        return finish()
    end

    if C_Timer and C_Timer.NewTicker then
        self.DeathAlerts.previewTicker = C_Timer.NewTicker(2.0, function()
            local perfStart, perfState = PortalAuthority:PerfBegin("death_alerts_preview_tick")
            PortalAuthority:CpuDiagCount("death_alerts_preview_tick")
            if not PortalAuthorityDB or PA_SafeBool(PortalAuthorityDB.deathAlertLocked) then
                PortalAuthority:DeathAlerts_StopPreviewTicker()
                PortalAuthority:PerfEnd("death_alerts_preview_tick", perfStart, perfState)
                return
            end
            if InCombatLockdown and InCombatLockdown() then
                if PortalAuthority.DeathAlerts and PortalAuthority.DeathAlerts.frame then
                    PortalAuthority.DeathAlerts.frame:Hide()
                end
                PortalAuthority:PerfEnd("death_alerts_preview_tick", perfStart, perfState)
                return
            end

            local activePool = PortalAuthority.DeathAlerts and PortalAuthority.DeathAlerts.previewPool or nil
            if type(activePool) ~= "table" or #activePool == 0 then
                activePool = { "TANK" }
                PortalAuthority.DeathAlerts.previewPool = activePool
            end

            local nextIndex = (tonumber(PortalAuthority.DeathAlerts.previewIndex) or 1) + 1
            if nextIndex > #activePool then
                nextIndex = 1
            end
            PortalAuthority.DeathAlerts.previewIndex = nextIndex
            PortalAuthority:DeathAlerts_RenderPreviewRole(activePool[nextIndex])
            PortalAuthority:PerfEnd("death_alerts_preview_tick", perfStart, perfState)
        end)
    end

    return finish()
end
function PortalAuthority:DeathAlerts_EnsureFrame()
    if PA_IsUiSurfaceGateEnabled() then
        return nil
    end
    if self.DeathAlerts and self.DeathAlerts.frame then
        return self.DeathAlerts.frame
    end

    local db = PortalAuthorityDB or self.defaults
    self.DeathAlerts = self.DeathAlerts or {}

    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(false)
    frame:SetMovable(true)
    frame:EnableMouse(false)
    frame:SetSize(800, 90)
    frame:SetPoint("CENTER", UIParent, "CENTER", math.floor(tonumber(db.deathAlertX) or 0), math.floor(tonumber(db.deathAlertY) or 0))
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetWordWrap(true)
    if text.SetNonSpaceWrap then
        text:SetNonSpaceWrap(true)
    end
    text:SetWidth(780)
    text:SetTextColor(1, 1, 1, 1)

    local handle = CreateFrame("Button", nil, frame, "BackdropTemplate")
    handle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 3)
    handle:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 3)
    handle:SetHeight(16)
    handle:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    handle:SetBackdropColor(0.0, 1.0, 0.0, 0.85)
    handle:SetBackdropBorderColor(0.0, 0.25, 0.0, 1.0)
    local handleText = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    handleText:SetPoint("CENTER", handle, "CENTER", 0, 0)
    handleText:SetText("GRAB")
    handleText:SetTextColor(0, 0, 0, 1)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        if not PortalAuthorityDB or PA_SafeBool(PortalAuthorityDB.deathAlertLocked) then return end
        frame:StartMoving()
        if not self.DeathAlerts.dragTicker and C_Timer and C_Timer.NewTicker then
            self.DeathAlerts.dragTicker = C_Timer.NewTicker(0.1, function()
                local perfStart, perfState = PortalAuthority:PerfBegin("death_alerts_drag_tick")
                PortalAuthority:CpuDiagCount("death_alerts_drag_tick")
                local cx, cy = frame:GetCenter()
                local ux, uy = UIParent:GetCenter()
                if cx and cy and ux and uy and PortalAuthority.DeathAlerts_OnPositionChanged then
                    PortalAuthority.DeathAlerts_OnPositionChanged(math.floor((cx - ux) + 0.5), math.floor((cy - uy) + 0.5))
                end
                PortalAuthority:PerfEnd("death_alerts_drag_tick", perfStart, perfState)
            end)
        end
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if self.DeathAlerts.dragTicker then
            self.DeathAlerts.dragTicker:Cancel()
            self.DeathAlerts.dragTicker = nil
        end
        local cx, cy = frame:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if cx and cy and ux and uy and PortalAuthorityDB then
            local x = math.floor((cx - ux) + 0.5)
            local y = math.floor((cy - uy) + 0.5)
            PortalAuthorityDB.deathAlertX = x
            PortalAuthorityDB.deathAlertY = y
            if PortalAuthority.DeathAlerts_OnPositionChanged then
                PortalAuthority.DeathAlerts_OnPositionChanged(x, y)
            end
        end
    end)

    self.DeathAlerts.frame = frame
    self.DeathAlerts.text = text
    self.DeathAlerts.handle = handle
    return frame
end

function PortalAuthority:DeathAlerts_FormatMessage(template, role, classFile, name)
    local text = trim(template)
    if text == "" then
        text = self.defaults.deathAlertMessageTemplate
    end

    local roleForIcon = role
    if roleForIcon == "SELF" then
        roleForIcon = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "DAMAGER"
        if roleForIcon ~= "TANK" and roleForIcon ~= "HEALER" and roleForIcon ~= "DAMAGER" then
            roleForIcon = "DAMAGER"
        end
    end

    local classIcon = ""
    if classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] then
        local coords = CLASS_ICON_TCOORDS[classFile]
        classIcon = string.format(
            "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:16:16:0:0:256:256:%d:%d:%d:%d|t",
            math.floor(coords[1] * 256 + 0.5),
            math.floor(coords[2] * 256 + 0.5),
            math.floor(coords[3] * 256 + 0.5),
            math.floor(coords[4] * 256 + 0.5)
        )
    end

    local playerName = name or "Unknown"
    local hex = self:GetClassHexColor(classFile) or "ffffffff"
    local coloredName = string.format("|c%s%s|r", hex, playerName)
    local roleText = "DPS"
    if roleForIcon == "TANK" then
        roleText = "Tank"
    elseif roleForIcon == "HEALER" then
        roleText = "Healer"
    else
        roleText = "DPS"
    end

    text = text:gsub("%[role%]", roleText)
    text = text:gsub("%[class%]", classIcon)
    text = text:gsub("%[name%]", coloredName)
    return text
end

function PortalAuthority:DeathAlerts_Show(message, durationSeconds)
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if not self:IsCombatAlertsEnabled() then
        if self.DeathAlerts and self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        return
    end
    self:DeathAlerts_EnsureFrame()
    if not (self.DeathAlerts and self.DeathAlerts.frame and self.DeathAlerts.text) then
        return
    end

    local dur = durationSeconds
    if dur == nil then
        dur = 5
    end
    self.DeathAlerts.runtimeAlertVisible = dur > 0

    self.DeathAlerts.text:SetText(message or "")
    self.DeathAlerts.frame:Show()

    if self.DeathAlerts.hideTimer and self.DeathAlerts.hideTimer.Cancel then
        self.DeathAlerts.hideTimer:Cancel()
    end
    self.DeathAlerts.hideTimer = nil
    self.DeathAlerts.hideToken = (self.DeathAlerts.hideToken or 0) + 1
    local token = self.DeathAlerts.hideToken

    if dur and dur > 0 then
        if C_Timer and C_Timer.NewTimer then
            self.DeathAlerts.hideTimer = C_Timer.NewTimer(dur, function()
                if not self.DeathAlerts or self.DeathAlerts.hideToken ~= token then return end
                self.DeathAlerts.runtimeAlertVisible = false
                if self.DeathAlerts.frame then
                    self.DeathAlerts.frame:Hide()
                end
            end)
        elseif C_Timer and C_Timer.After then
            C_Timer.After(dur, function()
                if not self.DeathAlerts or self.DeathAlerts.hideToken ~= token then return end
                self.DeathAlerts.runtimeAlertVisible = false
                if self.DeathAlerts.frame then
                    self.DeathAlerts.frame:Hide()
                end
            end)
        end
    end
end

function PortalAuthority:DeathAlerts_TestOnScreen()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if not self:IsCombatAlertsEnabled() then
        return
    end
    local db = PortalAuthorityDB or self.defaults
    local msg = self:DeathAlerts_FormatMessage(db.deathAlertMessageTemplate, "TANK", "PALADIN", "Streetxo")
    if PortalAuthorityDB and PA_SafeBool(PortalAuthorityDB.deathAlertShowRoleIcon) then
        msg = (PA_GetRoleIconTag and PA_GetRoleIconTag("TANK") or "") .. " " .. msg
    end
    self:DeathAlerts_Show(msg)
end

function PortalAuthority:DeathAlerts_RefreshTestMode()
    if PA_IsUiSurfaceGateEnabled() then
        return false
    end
    if not self:IsCombatAlertsEnabled() then
        self.DeathAlerts = self.DeathAlerts or {}
        self.DeathAlerts._testMode = false
        if self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        return false
    end
    if not (self.DeathAlerts and self.DeathAlerts._testMode) then
        return false
    end
    local db = PortalAuthorityDB or self.defaults
    local msg = self:DeathAlerts_FormatMessage(db.deathAlertMessageTemplate, "TANK", "PALADIN", "Streetxo")
    if PortalAuthorityDB and PA_SafeBool(PortalAuthorityDB.deathAlertShowRoleIcon) then
        msg = (PA_GetRoleIconTag and PA_GetRoleIconTag("TANK") or "") .. " " .. msg
    end
    -- Keep test mode infinite (no auto-hide)
    self:DeathAlerts_Show(msg, 0)
    return true
end

function PortalAuthority:DeathAlerts_IsTestModeActive()
    return self.DeathAlerts and self.DeathAlerts._testMode == true
end

function PortalAuthority:DeathAlerts_ToggleTestMode()
    if PA_IsUiSurfaceGateEnabled() then
        self.DeathAlerts = self.DeathAlerts or {}
        self.DeathAlerts._testMode = false
        if self.DeathAlerts.hideTimer and self.DeathAlerts.hideTimer.Cancel then
            self.DeathAlerts.hideTimer:Cancel()
        end
        self.DeathAlerts.hideTimer = nil
        if self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        return false
    end
    if not self:IsCombatAlertsEnabled() then
        self.DeathAlerts = self.DeathAlerts or {}
        self.DeathAlerts._testMode = false
        if self.DeathAlerts.hideTimer and self.DeathAlerts.hideTimer.Cancel then
            self.DeathAlerts.hideTimer:Cancel()
        end
        self.DeathAlerts.hideTimer = nil
        if self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        return false
    end
    self.DeathAlerts = self.DeathAlerts or {}
    local active = self.DeathAlerts._testMode == true

    if active then
        self.DeathAlerts._testMode = false
        if self.DeathAlerts.hideTimer and self.DeathAlerts.hideTimer.Cancel then
            self.DeathAlerts.hideTimer:Cancel()
        end
        self.DeathAlerts.hideTimer = nil
        self.DeathAlerts.hideToken = (self.DeathAlerts.hideToken or 0) + 1
        if self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        return false
    end

    self.DeathAlerts._testMode = true
    local db = PortalAuthorityDB or self.defaults
    local msg = self:DeathAlerts_FormatMessage(db.deathAlertMessageTemplate, "TANK", "PALADIN", "Streetxo")
    if PortalAuthorityDB and PA_SafeBool(PortalAuthorityDB.deathAlertShowRoleIcon) then
        msg = (PA_GetRoleIconTag and PA_GetRoleIconTag("TANK") or "") .. " " .. msg
    end
    self:DeathAlerts_Show(msg, 0)
    return true
end

function PortalAuthority:ApplyCombatAlertsSettings()
    if PA_IsUiSurfaceGateEnabled() then
        self.DeathAlerts = self.DeathAlerts or {}
        self:DeathAlerts_StopPreviewTicker()
        if self.DeathAlerts.dragTicker and self.DeathAlerts.dragTicker.Cancel then
            self.DeathAlerts.dragTicker:Cancel()
        end
        self.DeathAlerts.dragTicker = nil
        self.DeathAlerts._testMode = false
        if self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        return
    end
    if not self:IsCombatAlertsEnabled() then
        self.DeathAlerts = self.DeathAlerts or {}
        self:DeathAlerts_StopPreviewTicker()
        if self.DeathAlerts.dragTicker and self.DeathAlerts.dragTicker.Cancel then
            self.DeathAlerts.dragTicker:Cancel()
        end
        self.DeathAlerts.dragTicker = nil
        self.DeathAlerts._testMode = false
        if self.DeathAlerts.handle then
            self.DeathAlerts.handle:Hide()
        end
        if self.DeathAlerts.frame then
            self.DeathAlerts.frame:Hide()
        end
        if not (self.IsOnboardingD4Active and self:IsOnboardingD4Active())
            and self._OnboardingEnsureMarkers and self._OnboardingUpdateMarkers
        then
            self:_OnboardingEnsureMarkers()
            self:_OnboardingUpdateMarkers(self._moveHintBlink == true)
        end
        self:UpdateMoveHintTickerState()
        return
    end
    local perfStart, perfState = self:PerfBegin("deathalerts_apply_settings")
    local function finish(...)
        if perfStart ~= nil then
            self:PerfEnd("deathalerts_apply_settings", perfStart, perfState)
        end
        return ...
    end

    self:DeathAlerts_EnsureFrame()
    if not (self.DeathAlerts and self.DeathAlerts.frame and self.DeathAlerts.text and PortalAuthorityDB) then
        return finish()
    end

    local db = PortalAuthorityDB
    local fontPath = trim(db.deathAlertFontPath)
    if fontPath == "" then
        fontPath = self:GetGlobalFontPath()
    end
    local fontSize = math.floor(PA_Clamp(db.deathAlertFontSize, self.defaults.deathAlertFontSize, 8, 72))
    self.DeathAlerts.text:SetFont(fontPath, fontSize, "OUTLINE")
    self.DeathAlerts.text:SetTextColor(1, 1, 1, 1)
    self.DeathAlerts.frame:ClearAllPoints()
    self.DeathAlerts.frame:SetPoint("CENTER", UIParent, "CENTER", math.floor(tonumber(db.deathAlertX) or 0), math.floor(tonumber(db.deathAlertY) or 0))
    local unlocked = not PA_SafeBool(db.deathAlertLocked)
    local inCombat = InCombatLockdown and InCombatLockdown() or false
    self.DeathAlerts.handle:SetShown(unlocked)

    if unlocked then
        if not self.DeathAlerts._previewForcedVisible then
            self:DeathAlerts_StopPreviewTicker()
        end
        self.DeathAlerts._previewForcedVisible = true
        if inCombat then
            self:DeathAlerts_StopPreviewTicker()
            self.DeathAlerts.runtimeAlertVisible = false
            if self.DeathAlerts.frame then
                self.DeathAlerts.frame:Hide()
            end
        else
            self:DeathAlerts_ApplyUnlockedPreview()
        end
    else
        self.DeathAlerts._previewForcedVisible = false
        self:DeathAlerts_StopPreviewTicker()
        if self.DeathAlerts_IsTestModeActive and self:DeathAlerts_IsTestModeActive() and self.DeathAlerts_RefreshTestMode then
            self:DeathAlerts_RefreshTestMode()
        elseif self.DeathAlerts.frame and not (self.DeathAlerts.runtimeAlertVisible and self.DeathAlerts.frame:IsShown()) then
            self.DeathAlerts.runtimeAlertVisible = false
            self.DeathAlerts.frame:Hide()
        end
    end

    -- Apply lock/unlock marker visibility immediately instead of waiting for ticker cadence.
    if not (self.IsOnboardingD4Active and self:IsOnboardingD4Active())
        and self._OnboardingEnsureMarkers and self._OnboardingUpdateMarkers
    then
        self:_OnboardingEnsureMarkers()
        self:_OnboardingUpdateMarkers(self._moveHintBlink == true)
    end
    self:UpdateMoveHintTickerState()

    return finish()
end

function PortalAuthority:DeathAlerts_HandleDeath(deadGUID, destNameOptional, destFlags)
    local normalizedDeadGUID = PA_NormalizeSafeString(deadGUID)
    if not normalizedDeadGUID or normalizedDeadGUID == "" then
        return
    end
    if not PortalAuthorityDB then
        return
    end
    if not self:IsCombatAlertsEnabled() then
        return
    end

    local playerGUID = PA_SafeUnitGUID("player")
    if PA_SafeStringsEqual(normalizedDeadGUID, playerGUID) then
        self:DeathAlerts_HandlePlayerDeath()
        return
    end

    local inRaid = IsInRaid and IsInRaid() or false
    local inGroup = IsInGroup and IsInGroup() or false
    if not inRaid and not inGroup then
        return
    end

    if not self:IsGUIDInCurrentGroup(normalizedDeadGUID) then
        return
    end

    -- UnitTokenFromGUID is enrichment-only. Group relevance is established by GUID membership first,
    -- and role fallback only applies after that relevance check passes.
    local unitToken = self:GetCurrentGroupUnitTokenByGUID(normalizedDeadGUID)
    if not unitToken and UnitTokenFromGUID then
        local ok, token = pcall(UnitTokenFromGUID, normalizedDeadGUID)
        if ok and token and not PA_IsSecretValue(token) then
            local tokenGUID = PA_SafeUnitGUID(token)
            if PA_SafeStringsEqual(tokenGUID, normalizedDeadGUID) then
                unitToken = token
            end
        end
    end

    if unitToken and not PA_SafeStringsEqual(PA_SafeUnitGUID(unitToken), normalizedDeadGUID) then
        unitToken = nil
    end

    if unitToken == "player" then
        self:DeathAlerts_HandlePlayerDeath()
        return
    end

    local role = "DAMAGER"
    if unitToken and UnitGroupRolesAssigned then
        local ok, r = pcall(UnitGroupRolesAssigned, unitToken)
        if ok and not PA_IsSecretValue(r) and type(r) == "string" and r ~= "" and r ~= "NONE" then
            role = r
        end
    end
    if role ~= "TANK" and role ~= "HEALER" and role ~= "DAMAGER" then
        role = "DAMAGER"
    end

    local name = nil
    if unitToken and UnitName then
        local ok, n = pcall(UnitName, unitToken)
        if ok and not PA_IsSecretValue(n) and type(n) == "string" and n ~= "" then
            name = Ambiguate and Ambiguate(n, "short") or n
        end
    end
    local normalizedDestName = PA_NormalizeSafeString(destNameOptional)
    if trim(name) == "" and normalizedDestName then
        name = Ambiguate and Ambiguate(normalizedDestName, "short") or normalizedDestName
    end
    if trim(name) == "" then
        name = "Unknown"
    end

    local classFile = nil
    if GetPlayerInfoByGUID then
        local ok, _, class = pcall(GetPlayerInfoByGUID, normalizedDeadGUID)
        if ok and not PA_IsSecretValue(class) then
            classFile = class
        end
    end
    if trim(classFile) == "" and unitToken and UnitClass then
        local ok, _, class = pcall(UnitClass, unitToken)
        if ok and not PA_IsSecretValue(class) then
            classFile = class
        end
    end

    local keyPrefix = "deathAlertDps"
    if role == "SELF" then
        keyPrefix = "deathAlertSelf"
    elseif role == "TANK" then
        keyPrefix = "deathAlertTank"
    elseif role == "HEALER" then
        keyPrefix = "deathAlertHealer"
    end

    self:DeathAlerts_TriggerResolvedAlert(keyPrefix, role, classFile, name)
end

function PortalAuthority:DeathAlerts_TriggerResolvedAlert(keyPrefix, role, classFile, name)
    local rowEnabled = PA_SafeBool(PortalAuthorityDB[keyPrefix .. "Enabled"])
    if not rowEnabled then
        return
    end

    if self.DeathAlerts and self.DeathAlerts._testMode then
        self.DeathAlerts._testMode = false
    end

    if keyPrefix == "deathAlertSelf" then
        self.DeathAlerts = self.DeathAlerts or {}
        local now = GetTime and GetTime() or 0
        local lastAt = tonumber(self.DeathAlerts.lastSelfResolvedAlertAt) or 0
        if lastAt > 0 and (now - lastAt) <= DEATH_ALERT_SELF_DUPLICATE_WINDOW_SECONDS then
            return
        end
        self.DeathAlerts.lastSelfResolvedAlertAt = now
    end

    local suppressAudio = false
    if PA_SafeBool(PortalAuthorityDB.deathAlertAntiSpamWipeEnabled) then
        local tracker = self.DeathAlerts and self.DeathAlerts.wipeTracker or {}
        self.DeathAlerts = self.DeathAlerts or {}
        self.DeathAlerts.wipeTracker = tracker
        local now = GetTime and GetTime() or 0
        local keep = {}
        for _, ts in ipairs(tracker) do
            if (now - ts) <= 5 then
                keep[#keep + 1] = ts
            end
        end
        keep[#keep + 1] = now
        self.DeathAlerts.wipeTracker = keep
        if #keep > 5 then
            self.DeathAlerts.wipeInProgressUntil = now + 15
            self.DeathAlerts.wipeTracker = {}
        end
        if self.DeathAlerts.wipeInProgressUntil and now < self.DeathAlerts.wipeInProgressUntil then
            suppressAudio = true
        end
    end

    local message
    if keyPrefix == "deathAlertSelf" and PA_SafeBool(PortalAuthorityDB[keyPrefix .. "OnScreen"]) then
        message = "You have died! :("
    else
        message = self:DeathAlerts_FormatMessage(PortalAuthorityDB.deathAlertMessageTemplate, role, classFile, name)
    end
    if PA_SafeBool(PortalAuthorityDB.deathAlertShowRoleIcon) and role ~= "SELF" then
        message = (PA_GetRoleIconTag and PA_GetRoleIconTag(role) or "") .. " " .. message
    end
    if PA_SafeBool(PortalAuthorityDB[keyPrefix .. "OnScreen"]) then
        self:DeathAlerts_Show(message)
    end

    if not suppressAudio then
        local selectedSound = PortalAuthorityDB[keyPrefix .. "Sound"]
        local soundFile = self:GetDeathAlertSoundFile(selectedSound)
        if soundFile then
            local channel = PortalAuthorityDB.deathAlertSoundChannel
            if not VALID_SOUND_CHANNELS[channel] then
                channel = self.defaults.deathAlertSoundChannel
            end
            if type(soundFile) == "number" and PlaySound then
                PlaySound(soundFile, channel)
            elseif PlaySoundFile then
                PlaySoundFile(soundFile, channel)
            end
        end
    end
end

function PortalAuthority:DeathAlerts_HandlePlayerDeath()
    if not PortalAuthorityDB then
        return
    end
    if not self:IsCombatAlertsEnabled() then
        return
    end

    local classFile = nil
    if UnitClass then
        local ok, _, class = pcall(UnitClass, "player")
        if ok and not PA_IsSecretValue(class) and type(class) == "string" and class ~= "" then
            classFile = class
        end
    end

    local name = nil
    if UnitName then
        local ok, playerName = pcall(UnitName, "player")
        if ok and not PA_IsSecretValue(playerName) and type(playerName) == "string" and playerName ~= "" then
            name = Ambiguate and Ambiguate(playerName, "short") or playerName
        end
    end
    if trim(name) == "" then
        name = "Player"
    end

    self:DeathAlerts_TriggerResolvedAlert("deathAlertSelf", "SELF", classFile, name)
end

function PortalAuthority:InitializeDeathAlerts()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if self._deathAlertsHooked then return end
    self._deathAlertsHooked = true

    self.DeathAlerts = self.DeathAlerts or {}
    self.DeathAlerts.wipeTracker = self.DeathAlerts.wipeTracker or {}

    -- Do not create/register an event frame here; main addon frame handles events.
    self.DeathAlerts.eventFrame = nil

    self:ApplyCombatAlertsSettings()
end

function PortalAuthority:GetRitualOfSummoningIconTexture()
    if C_Spell and C_Spell.GetSpellTexture then
        local textureID = C_Spell.GetSpellTexture(RITUAL_OF_SUMMONING_SPELL_ID)
        if textureID then
            return textureID
        end
    end

    if GetSpellTexture then
        local textureID = GetSpellTexture(RITUAL_OF_SUMMONING_SPELL_ID)
        if textureID then
            return textureID
        end
    end

    return RITUAL_OF_SUMMONING_ICON_FALLBACK
end

function PortalAuthority:GetSummonStoneRequestPopupMessage()
    local textureID = self:GetRitualOfSummoningIconTexture()
    return string.format("|T%s:0|t Summoning Stone has been requested", tostring(textureID))
end

function PortalAuthority:ShowSummonStoneRequestPopup()
    local message = self:GetSummonStoneRequestPopupMessage()

    if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo and ChatTypeInfo.RAID_WARNING then
        RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo.RAID_WARNING)
        return
    end

    UIErrorsFrame:AddMessage(message, 1, 0.82, 0, 1, 3)
end

function PortalAuthority:ShouldThrottleSummonStonePopup(sender)
    local playerName = self:NormalizeSenderName(sender)
    local now = GetTime()
    local lastShown = self.lastSummonStonePopupBySender[playerName]

    if lastShown and (now - lastShown) < SUMMON_SENDER_COOLDOWN_SECONDS then
        return true
    end

    self.lastSummonStonePopupBySender[playerName] = now
    return false
end

function PortalAuthority:IsSummonStoneBurstLimited()
    local now = GetTime()
    local windowStart = now - SUMMON_BURST_WINDOW_SECONDS

    local kept = {}
    for _, ts in ipairs(self.summonStoneRequestTimestamps) do
        if ts >= windowStart then
            table.insert(kept, ts)
        end
    end
    self.summonStoneRequestTimestamps = kept

    if #self.summonStoneRequestTimestamps >= SUMMON_BURST_WINDOW_MAX then
        return true
    end

    table.insert(self.summonStoneRequestTimestamps, now)
    return false
end

function PortalAuthority:GetSenderForEvent(event, sender, bnSenderID)
    if event == "CHAT_MSG_BN_WHISPER" then
        if bnSenderID and C_BattleNet and C_BattleNet.GetAccountInfoByID then
            local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
            if accountInfo then
                local btag = accountInfo.battleTag
                if trim(btag) ~= "" then
                    return btag
                end
                if accountInfo.accountName and trim(accountInfo.accountName) ~= "" then
                    return accountInfo.accountName
                end
            end
        end
        return trim(sender) ~= "" and sender or "Battle.net"
    end

    return sender
end

function PortalAuthority:ResolveSummonChatPayload(message, sender, senderGUID, lineID)
    local resolvedMessage = message
    local resolvedSender = sender
    local resolvedSenderGUID = senderGUID
    local chatLineID = tonumber(lineID)

    if chatLineID and chatLineID > 0 and C_ChatInfo then
        if C_ChatInfo.GetChatLineText then
            local ok, fetchedMessage = pcall(C_ChatInfo.GetChatLineText, chatLineID)
            if ok and type(fetchedMessage) == "string" and fetchedMessage ~= "" then
                resolvedMessage = fetchedMessage
            end
        end

        if C_ChatInfo.GetChatLineSenderName then
            local ok, fetchedSender = pcall(C_ChatInfo.GetChatLineSenderName, chatLineID)
            if ok and type(fetchedSender) == "string" and fetchedSender ~= "" then
                resolvedSender = fetchedSender
            end
        end

        if C_ChatInfo.GetChatLineSenderGUID then
            local ok, fetchedGUID = pcall(C_ChatInfo.GetChatLineSenderGUID, chatLineID)
            if ok and type(fetchedGUID) == "string" and fetchedGUID ~= "" then
                resolvedSenderGUID = fetchedGUID
            end
        end
    end

    return resolvedMessage, resolvedSender, resolvedSenderGUID
end

function PortalAuthority:IsUnitInCurrentGroup(sender, senderGUID)
    local normalizedSenderGUID = PA_NormalizeSafeString(senderGUID)
    if normalizedSenderGUID then
        if UnitExists and UnitExists("player") and PA_SafeStringsEqual(PA_SafeUnitGUID("player"), normalizedSenderGUID) then
            return true
        end

        local raidCount = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, raidCount do
            if PA_SafeStringsEqual(PA_SafeUnitGUID("raid" .. index), normalizedSenderGUID) then
                return true
            end
        end

        local partyCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for index = 1, partyCount do
            if PA_SafeStringsEqual(PA_SafeUnitGUID("party" .. index), normalizedSenderGUID) then
                return true
            end
        end
    end

    if type(sender) ~= "string" or sender == "" then
        return false
    end

    local normalizedSender = self:NormalizeSenderName(sender):lower()
    local function matchesUnitByName(unit)
        if not UnitExists(unit) then
            return false
        end

        local unitName = UnitName(unit)
        if type(unitName) ~= "string" or unitName == "" then
            return false
        end

        return self:NormalizeSenderName(unitName):lower() == normalizedSender
    end

    if IsInRaid and IsInRaid() then
        local raidCount = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, raidCount do
            if matchesUnitByName("raid" .. index) then
                return true
            end
        end
    elseif IsInGroup and IsInGroup() then
        local partyCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for index = 1, partyCount do
            if matchesUnitByName("party" .. index) then
                return true
            end
        end

        if matchesUnitByName("player") then
            return true
        end
    end

    return false
end

function PortalAuthority:GetCurrentGroupUnitTokenByGUID(unitGUID)
    local normalizedUnitGUID = PA_NormalizeSafeString(unitGUID)
    if not normalizedUnitGUID then
        return nil
    end

    if PA_SafeStringsEqual(PA_SafeUnitGUID("player"), normalizedUnitGUID) then
        return "player"
    end

    if IsInRaid and IsInRaid() then
        local raidCount = GetNumGroupMembers and GetNumGroupMembers() or 0
        for index = 1, raidCount do
            local unit = "raid" .. index
            if PA_SafeStringsEqual(PA_SafeUnitGUID(unit), normalizedUnitGUID) then
                return unit
            end
        end
    elseif IsInGroup and IsInGroup() then
        local partyCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
        for index = 1, partyCount do
            local unit = "party" .. index
            if PA_SafeStringsEqual(PA_SafeUnitGUID(unit), normalizedUnitGUID) then
                return unit
            end
        end
    end

    return nil
end

function PortalAuthority:IsGUIDInCurrentGroup(unitGUID)
    local normalizedUnitGUID = PA_NormalizeSafeString(unitGUID)
    if not normalizedUnitGUID then
        return false
    end

    if PA_SafeStringsEqual(PA_SafeUnitGUID("player"), normalizedUnitGUID) then
        return true
    end

    local inRaid = IsInRaid and IsInRaid() or false
    local inGroup = IsInGroup and IsInGroup() or false
    if not inRaid and not inGroup then
        return false
    end

    if IsGUIDInGroup then
        local ok, inCurrentGroup = pcall(IsGUIDInGroup, normalizedUnitGUID)
        if ok and inCurrentGroup then
            return true
        end
    end

    return self:GetCurrentGroupUnitTokenByGUID(normalizedUnitGUID) ~= nil
end

function PortalAuthority:GetBNetWhisperCharacter(bnSenderID)
    if not bnSenderID or not C_BattleNet or not C_BattleNet.GetAccountInfoByID then
        return nil, nil
    end

    local accountInfo = C_BattleNet.GetAccountInfoByID(bnSenderID)
    if not accountInfo then
        return nil, nil
    end

    local gameAccountInfo = accountInfo.gameAccountInfo
    if not gameAccountInfo then
        return nil, nil
    end

    local characterName = trim(gameAccountInfo.characterName)
    local realmName = trim(gameAccountInfo.realmName)
    local playerGuid = trim(gameAccountInfo.playerGuid)

    if characterName == "" then
        characterName = nil
    elseif realmName ~= "" then
        characterName = string.format("%s-%s", characterName, realmName)
    end

    if playerGuid == "" then
        playerGuid = nil
    end

    return characterName, playerGuid
end

function PortalAuthority:IsSummonSenderInGroup(event, sender, bnSenderID, senderGUID)
    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER" or event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
        return true
    end

    if event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
        return self:IsUnitInCurrentGroup(sender, senderGUID)
    end

    if event == "CHAT_MSG_WHISPER" then
        return self:IsUnitInCurrentGroup(sender, senderGUID)
    end

    if event == "CHAT_MSG_BN_WHISPER" then
        local characterName, characterGUID = self:GetBNetWhisperCharacter(bnSenderID)

        if self:IsUnitInCurrentGroup(characterName, characterGUID) then
            return true
        end

        if senderGUID and self:IsUnitInCurrentGroup(nil, senderGUID) then
            return true
        end

        return false
    end

    return false
end

function PortalAuthority:HandleSummonChatEvent(event, message, sender, bnSenderID, senderGUID, lineID)
    self:SummonDebugTrace("summon", "entered", event, sender, senderGUID, message)
    if not PortalAuthorityDB or not PortalAuthorityDB.summonRequestsEnabled then
        self:SummonDebugTrace("summon", "disabled", event, sender, senderGUID, message)
        return
    end

    if PA_IsChallengeActive and PA_IsChallengeActive() then
        self:SummonDebugTrace("summon", "challenge_blocked", event, sender, senderGUID, message)
        return
    end

    if not self:IsWarlockPlayer() then
        self:SummonDebugTrace("summon", "not_warlock", event, sender, senderGUID, message)
        return
    end

    if self:IsPlayerInCombat() then
        self:SummonDebugTrace("summon", "in_combat", event, sender, senderGUID, message)
        return
    end

    message, sender, senderGUID = self:ResolveSummonChatPayload(message, sender, senderGUID, lineID)

    if self:IsSenderPlayer(sender, senderGUID) then
        self:SummonDebugTrace("summon", "self_sender", event, sender, senderGUID, message)
        return
    end

    if self:ShouldSuppressOwnWarlockSummoningAnnouncement(event, message, sender, senderGUID) then
        self:SummonDebugTrace("summon", "suppressed_own_announcement", event, sender, senderGUID, message)
        return
    end

    if not self:IsSummonKeywordMessage(message) then
        self:SummonDebugTrace("summon", "no_keyword", event, sender, senderGUID, message)
        return
    end

    if not self:IsSummonSenderInGroup(event, sender, bnSenderID, senderGUID) then
        self:SummonDebugTrace("summon", "sender_not_in_group", event, sender, senderGUID, message)
        return
    end

    if self:IsSummonBurstLimited() then
        self:SummonDebugTrace("summon", "burst_limited", event, sender, senderGUID, message)
        return
    end

    local triggerSender = self:GetSenderForEvent(event, sender, bnSenderID)
    if self:ShouldThrottleSummonPopup(triggerSender) then
        self:SummonDebugTrace("summon", "sender_throttled", event, sender, senderGUID, message)
        return
    end

    self:SummonDebugTrace("summon", "triggered", event, sender, senderGUID, message)
    self:ShowSummonPopup(event, triggerSender, senderGUID)
    self:PlaySummonRequestSound()
end

function PortalAuthority:HandleSummonStoneChatEvent(event, message, sender, bnSenderID, senderGUID, lineID)
    self:SummonDebugTrace("stone", "entered", event, sender, senderGUID, message)
    if not PortalAuthorityDB or not PortalAuthorityDB.summonStoneRequestsEnabled then
        self:SummonDebugTrace("stone", "disabled", event, sender, senderGUID, message)
        return
    end

    if PA_IsChallengeActive and PA_IsChallengeActive() then
        self:SummonDebugTrace("stone", "challenge_blocked", event, sender, senderGUID, message)
        return
    end

    if not self:IsWarlockPlayer() then
        self:SummonDebugTrace("stone", "not_warlock", event, sender, senderGUID, message)
        return
    end

    if self:IsPlayerInCombat() then
        self:SummonDebugTrace("stone", "in_combat", event, sender, senderGUID, message)
        return
    end

    message, sender, senderGUID = self:ResolveSummonChatPayload(message, sender, senderGUID, lineID)

    if self:IsSenderPlayer(sender, senderGUID) then
        self:SummonDebugTrace("stone", "self_sender", event, sender, senderGUID, message)
        return
    end

    if not self:IsSummonStoneKeywordMessage(message) then
        self:SummonDebugTrace("stone", "no_keyword", event, sender, senderGUID, message)
        return
    end

    if not self:IsSummonSenderInGroup(event, sender, bnSenderID, senderGUID) then
        self:SummonDebugTrace("stone", "sender_not_in_group", event, sender, senderGUID, message)
        return
    end

    if self:IsSummonStoneBurstLimited() then
        self:SummonDebugTrace("stone", "burst_limited", event, sender, senderGUID, message)
        return
    end

    local triggerSender = self:GetSenderForEvent(event, sender, bnSenderID)
    if self:ShouldThrottleSummonStonePopup(triggerSender) then
        self:SummonDebugTrace("stone", "sender_throttled", event, sender, senderGUID, message)
        return
    end

    self:SummonDebugTrace("stone", "triggered", event, sender, senderGUID, message)
    self:ShowSummonStoneRequestPopup()
    self:PlaySummonStoneRequestSound()
end

function PortalAuthority:OpenSettings(categoryID)
    if PA_IsSettingsBaselineGateEnabled() then
        print("|cffE88BC7Portal Authority:|r Settings are disabled in the settings-baseline build.")
        return false, "Settings are unavailable in this build."
    end
    self:CpuDiagEnsureSettingsHooks()
    if self.EnsureSettingsHostCoexistenceHooks then
        self:EnsureSettingsHostCoexistenceHooks()
    end

    local function canOpenSettingsNow()
        local inCombat = (InCombatLockdown and InCombatLockdown()) or false
        if inCombat or (self.IsPlayerInCombat and self:IsPlayerInCombat()) then
            return false, "Settings are unavailable during combat."
        end
        return true, nil
    end

    local safeToOpen, safeErr = canOpenSettingsNow()
    if not safeToOpen then
        return false, safeErr
    end

    local sectionKey = self:ResolveSettingsSectionKeyFromCategoryID(categoryID)
    if self.IsSettingsWindowHostEnabled and self:IsSettingsWindowHostEnabled() then
        if sectionKey then
            return self:OpenCustomSettingsSection(sectionKey, "open-settings")
        end

        local customFrame = self.GetExistingSettingsWindowFrame and self:GetExistingSettingsWindowFrame() or nil
        if customFrame and customFrame.IsShown and customFrame:IsShown() then
            if self.CloseSettingsWindow then
                self:CloseSettingsWindow()
            end
            customFrame = self.GetExistingSettingsWindowFrame and self:GetExistingSettingsWindowFrame() or customFrame
            if customFrame and customFrame.IsShown and customFrame:IsShown() and customFrame.Hide then
                customFrame:Hide()
            end
        end
    end

    if type(categoryID) == "number" and not sectionKey then
        categoryID = self.rootCategoryID
    end

    if not Settings then
        return false, "Settings are unavailable."
    end

    local id = categoryID or self.defaultCategoryID or self.rootCategoryID
    if type(id) ~= "number" then
        local category = self.settingsCategory
        if category and category.GetID then
            id = category:GetID()
        end
    end

    if type(id) == "number" then
        local function openCategoryOnce()
            local okToOpen = canOpenSettingsNow()
            if not okToOpen then
                return false
            end
            if Settings.OpenToCategoryID then
                Settings.OpenToCategoryID(id)
                return true
            end
            if Settings.OpenToCategory then
                Settings.OpenToCategory(id)
                return true
            end
            return false
        end

        if openCategoryOnce() then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    openCategoryOnce()
                    if PortalAuthority and PortalAuthority.CpuDiagEnsureSettingsHooks then
                        PortalAuthority:CpuDiagEnsureSettingsHooks()
                    end
                end)
            end
            self:CpuDiagEnsureSettingsHooks()
            return true
        end
    end

    print("|cffE88BC7PortalAuthority:|r could not open settings (category ID missing)")
    return false, "Settings are unavailable."
end

local PA_DIAG_WALK_ORDER = {
    "root",
    "announcements",
    "dock",
    "timers",
    "interrupt",
    "combat",
    "keystone",
    "profiles",
}

local PA_DIAG_PANEL_SETTLE_DELAY = 0.08
local PA_DIAG_PANEL_RETRY_DELAY = 0.08
local PA_DIAG_PANEL_MAX_ATTEMPTS = 2

local function PA_PrintDiagnosticMessage(message)
    print("|cffffd100PA Diagnostic:|r " .. tostring(message or ""))
end

local function PA_DiagJoinNotes(notes)
    if type(notes) ~= "table" or #notes <= 0 then
        return ""
    end
    return table.concat(notes, "; ")
end

local function PA_DiagRecursiveFrameCount(rootFrame)
    if not rootFrame then
        return nil
    end
    local seen = {}
    local function count(frame)
        if not frame or seen[frame] then
            return 0
        end
        seen[frame] = true
        local total = 1
        for i = 1, select("#", frame:GetChildren()) do
            total = total + count(select(i, frame:GetChildren()))
        end
        return total
    end
    return count(rootFrame)
end

local function PA_DiagFindSettingsPanelInfo(snapshot, panelKey)
    local panels = snapshot and snapshot.panels or nil
    if type(panels) ~= "table" then
        return nil
    end
    for i = 1, #panels do
        local entry = panels[i]
        if entry and entry.key == panelKey then
            return entry
        end
    end
    return nil
end

local function PA_DiagNormalizePanelKey(panelKey)
    if type(panelKey) ~= "string" then
        return nil
    end
    panelKey = trim(panelKey):lower()
    for i = 1, #PA_DIAG_WALK_ORDER do
        if PA_DIAG_WALK_ORDER[i] == panelKey then
            return panelKey
        end
    end
    return nil
end

local function PA_DiagBuildCharacterLabel()
    local name = UnitName and UnitName("player") or nil
    local realm = GetRealmName and GetRealmName() or nil
    name = trim(tostring(name or "Unknown"))
    realm = trim(tostring(realm or "Unknown"))
    if realm == "" then
        return name
    end
    return string.format("%s-%s", name, realm)
end

local function PA_DiagBuildWowBuildSnapshot()
    local version, build, buildDate, tocVersion = GetBuildInfo()
    return {
        version = version,
        build = build,
        buildDate = buildDate,
        tocVersion = tocVersion,
    }
end

local function PA_DiagBuildSpecSnapshot()
    local specIndex = GetSpecialization and GetSpecialization() or nil
    local specID, specName = nil, nil
    if type(specIndex) == "number" and GetSpecializationInfo then
        specID, specName = GetSpecializationInfo(specIndex)
    end
    return {
        index = specIndex,
        id = specID,
        name = specName,
    }
end

local function PA_DiagBuildClassSnapshot()
    local localized, english = nil, nil
    if UnitClass then
        localized, english = UnitClass("player")
    end
    return {
        localized = localized,
        english = english,
    }
end

function PortalAuthority:GetSettingsPanelWalkOrder()
    if type(self.settingsPanelWalkOrder) == "table" and #self.settingsPanelWalkOrder > 0 then
        local copy = {}
        for i = 1, #self.settingsPanelWalkOrder do
            copy[#copy + 1] = tostring(self.settingsPanelWalkOrder[i])
        end
        return copy
    end
    local copy = {}
    for i = 1, #PA_DIAG_WALK_ORDER do
        copy[#copy + 1] = PA_DIAG_WALK_ORDER[i]
    end
    return copy
end

function PortalAuthority:GetSettingsPanelRegistry()
    if type(self.settingsPanelRegistry) == "table" then
        return self.settingsPanelRegistry
    end

    local registry = {}
    local panels = self._settingsFirstOpenDebugPanels
    if type(panels) == "table" then
        for i = 1, #panels do
            local entry = panels[i]
            local key = entry and entry.key or nil
            if type(key) == "string" and key ~= "" then
                registry[key] = {
                    key = key,
                    name = entry.name,
                    panel = entry.panel,
                }
            end
        end
    end

    if registry.root then
        registry.root.categoryID = self.rootCategoryID
    end
    local rootFallbackCategoryID = self.defaultCategoryID or self.rootCategoryID
    if registry.announcements then
        registry.announcements.categoryID = rootFallbackCategoryID
    end
    if registry.dock then
        registry.dock.categoryID = rootFallbackCategoryID
    end
    if registry.timers then
        registry.timers.categoryID = rootFallbackCategoryID
    end
    if registry.interrupt then
        registry.interrupt.categoryID = rootFallbackCategoryID
    end
    if registry.combat then
        registry.combat.categoryID = rootFallbackCategoryID
    end
    if registry.keystone then
        registry.keystone.categoryID = rootFallbackCategoryID
    end
    if registry.profiles then
        registry.profiles.categoryID = rootFallbackCategoryID
    end

    return registry
end

function PortalAuthority:GetDiagHostSurfaceName()
    if self:IsSettingsWindowHostEnabled() then
        return "custom-settings-window"
    end
    return "blizzard-settings"
end

function PortalAuthority:IsDiagDumpCombatBlocked()
    local inCombatLockdown = (InCombatLockdown and InCombatLockdown()) or false
    local isPlayerInCombat = self.IsPlayerInCombat and self:IsPlayerInCombat() or false
    return inCombatLockdown or isPlayerInCombat
end

function PortalAuthority:GetDiagCombatState()
    return {
        inCombatLockdown = (InCombatLockdown and InCombatLockdown()) or false,
        isPlayerInCombat = self.IsPlayerInCombat and self:IsPlayerInCombat() or false,
    }
end

function PortalAuthority:GetDiagCodeRevision()
    if type(self.GetCodeRevision) == "function" then
        local ok, value = pcall(self.GetCodeRevision, self)
        if ok and value ~= nil then
            return value
        end
    end
    if self.codeRevision ~= nil then
        return self.codeRevision
    end
    return nil
end

function PortalAuthority:GetDiagCustomSettingsWindowFrame()
    return self:GetExistingSettingsWindowFrame()
end

function PortalAuthority:IsDiagRelevantSettingsHostVisible()
    return self:IsAnySettingsHostVisible()
end

function PortalAuthority:CloseDiagRelevantSettingsHost()
    local closed = false
    if type(self.CloseSettingsWindow) == "function" then
        local ok, didClose = pcall(self.CloseSettingsWindow, self)
        if ok and didClose then
            closed = true
        end
    end
    local customFrame = self:GetDiagCustomSettingsWindowFrame()
    if customFrame and customFrame.IsShown and customFrame:IsShown() and customFrame.Hide then
        customFrame:Hide()
        closed = true
    end

    if Settings and type(Settings.CloseSettings) == "function" then
        local ok = pcall(Settings.CloseSettings)
        if ok then
            closed = true
        end
    end
    if Settings and type(Settings.Close) == "function" then
        local ok = pcall(Settings.Close)
        if ok then
            closed = true
        end
    end
    if self.HideSettingsPanelForOnboardingD4 then
        self:HideSettingsPanelForOnboardingD4()
        closed = true
    end
    local settingsPanel = self:CpuDiagGetSettingsPanelFrame()
    if settingsPanel and settingsPanel.Hide then
        settingsPanel:Hide()
        closed = true
    end
    return closed
end

function PortalAuthority:OpenDiagHostedSettingsPanel(panelKey)
    panelKey = PA_DiagNormalizePanelKey(panelKey)
    if not panelKey then
        return false, "Diagnostic settings target is unavailable."
    end

    if self:IsSettingsWindowHostEnabled() then
        if panelKey == "root" then
            if type(self.OpenSettingsWindow) == "function" then
                local ok, result = pcall(self.OpenSettingsWindow, self, "root", { source = "diagdump" })
                if ok and result ~= false then
                    return true
                end
                local runtime = self._settingsWindowRuntime
                return false, tostring((runtime and runtime.lastError) or "Settings host is unavailable.")
            end
            return false, "Settings host is unavailable."
        end
        if type(self.OpenSettingsWindowToSection) == "function" then
            local ok, result = pcall(self.OpenSettingsWindowToSection, self, panelKey)
            if ok and result ~= false then
                return true
            end
            local runtime = self._settingsWindowRuntime
            return false, tostring((runtime and runtime.lastError) or "Settings host is unavailable.")
        end
        return false, "Settings host is unavailable."
    end

    local registry = self:GetSettingsPanelRegistry()
    local entry = registry and registry[panelKey] or nil
    local categoryID = entry and entry.categoryID or nil
    if panelKey == "announcements" and type(categoryID) ~= "number" then
        categoryID = self.defaultCategoryID
    elseif panelKey == "root" and type(categoryID) ~= "number" then
        categoryID = self.rootCategoryID
    end
    return self:OpenSettings(categoryID)
end

function PortalAuthority:GetDiagActiveHostRootFrame()
    if self:IsSettingsWindowHostEnabled() then
        return self:GetDiagCustomSettingsWindowFrame()
    end
    return self:CpuDiagGetSettingsPanelFrame()
end

function PortalAuthority:MeasureHostedSettingsPanel(panelKey)
    panelKey = PA_DiagNormalizePanelKey(panelKey)
    local registry = self:GetSettingsPanelRegistry()
    local entry = registry and registry[panelKey] or nil
    local panel = entry and entry.panel or nil
    local measurement = {
        key = panelKey,
        hasScrollChild = false,
        scrollWidth = nil,
        scrollChildTop = nil,
        firstElement = nil,
        notes = "",
    }
    if not panel then
        measurement.notes = "panel missing"
        return measurement
    end
    if not panel.IsShown or not panel:IsShown() then
        measurement.notes = "panel hidden"
        return measurement
    end

    local sizeTarget = panel._settingsFirstOpenSizeTarget or panel._sizingFrame or panel
    local scrollChild = sizeTarget and sizeTarget.GetScrollChild and sizeTarget:GetScrollChild() or nil
    if not scrollChild then
        measurement.notes = "no scrollChild"
        return measurement
    end

    measurement.hasScrollChild = true
    measurement.scrollWidth = tonumber(sizeTarget and sizeTarget.GetWidth and sizeTarget:GetWidth()) or nil
    measurement.scrollChildTop = tonumber(scrollChild.GetTop and scrollChild:GetTop()) or nil

    local scrollChildTop = measurement.scrollChildTop
    if type(scrollChildTop) ~= "number" then
        measurement.notes = "scrollChild top unavailable"
        return measurement
    end

    local viewportTop = tonumber(sizeTarget and sizeTarget.GetTop and sizeTarget:GetTop()) or scrollChildTop
    local viewportBottom = tonumber(sizeTarget and sizeTarget.GetBottom and sizeTarget:GetBottom()) or nil
    if type(viewportBottom) ~= "number" then
        local viewportHeight = tonumber(sizeTarget and sizeTarget.GetHeight and sizeTarget:GetHeight()) or 0
        viewportBottom = viewportTop - viewportHeight
    end
    if viewportTop < viewportBottom then
        viewportTop, viewportBottom = viewportBottom, viewportTop
    end

    local function stripColorCodes(text)
        if type(text) ~= "string" then
            return nil
        end
        local cleaned = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        cleaned = cleaned:match("^%s*(.-)%s*$") or ""
        if cleaned == "" then
            return nil
        end
        return cleaned
    end

    local function getObjectIdentity(obj)
        local objectType = obj and obj.GetObjectType and obj:GetObjectType() or "?"
        local text = stripColorCodes(obj and obj.GetText and obj:GetText() or nil)
        local name = obj and obj.GetName and obj:GetName() or nil
        if type(name) == "string" then
            name = name:match("^%s*(.-)%s*$") or ""
            if name == "" then
                name = nil
            end
        else
            name = nil
        end
        local label = text or name or "<unnamed>"
        return objectType, label, (text ~= nil or name ~= nil)
    end

    local function intersectsClip(obj, clipTop, clipBottom)
        if not obj or (obj.IsShown and not obj:IsShown()) or not obj.GetTop or not obj.GetBottom then
            return nil
        end
        local top = obj:GetTop()
        local bottom = obj:GetBottom()
        if not top or not bottom then
            return nil
        end
        if bottom > clipTop or top < clipBottom then
            return nil
        end
        local visibleTop = math.min(top, clipTop)
        local visibleBottom = math.max(bottom, clipBottom)
        if (visibleTop - visibleBottom) < 2 then
            return nil
        end
        return top, bottom, visibleTop, visibleBottom
    end

    local function betterDirectCandidate(candidate, incumbent)
        if not incumbent then
            return true
        end
        if candidate.visibleTop > incumbent.visibleTop + 0.5 then
            return true
        end
        if math.abs(candidate.visibleTop - incumbent.visibleTop) > 0.5 then
            return false
        end
        if candidate.priority ~= incumbent.priority then
            return candidate.priority > incumbent.priority
        end
        if math.abs(candidate.left - incumbent.left) > 0.5 then
            return candidate.left < incumbent.left
        end
        return candidate.order < incumbent.order
    end

    local directBest = nil
    local directOrder = 0
    local function considerDirect(obj)
        local top, bottom, visibleTop = intersectsClip(obj, viewportTop, viewportBottom)
        if not top then
            return
        end
        directOrder = directOrder + 1
        local objectType = obj.GetObjectType and obj:GetObjectType() or ""
        local priority = (objectType == "FontString" and 5)
            or ((objectType == "Button" or objectType == "CheckButton" or objectType == "EditBox" or objectType == "Slider" or objectType == "Frame") and 4)
            or (objectType == "Texture" and 1)
            or 0
        if priority <= 0 then
            return
        end
        local candidate = {
            obj = obj,
            top = top,
            bottom = bottom,
            visibleTop = visibleTop,
            left = tonumber(obj.GetLeft and obj:GetLeft()) or 0,
            priority = priority,
            order = directOrder,
        }
        if betterDirectCandidate(candidate, directBest) then
            directBest = candidate
        end
    end

    for i = 1, select("#", scrollChild:GetRegions()) do
        considerDirect(select(i, scrollChild:GetRegions()))
    end
    for i = 1, select("#", scrollChild:GetChildren()) do
        considerDirect(select(i, scrollChild:GetChildren()))
    end

    if not directBest then
        measurement.notes = "no candidate element"
        return measurement
    end

    local clipTop = math.min(viewportTop, directBest.top)
    local clipBottom = math.max(viewportBottom, directBest.bottom)
    local visitOrder = 0
    local meaningfulBest = nil
    local fallbackBest = nil

    local function candidatePriority(objectType, meaningful)
        if meaningful then
            if objectType == "FontString" then
                return 6
            end
            if objectType == "Button" or objectType == "CheckButton" or objectType == "EditBox" or objectType == "Slider" then
                return 5
            end
            if objectType == "Frame" then
                return 4
            end
            if objectType == "Texture" then
                return 1
            end
            return 0
        end
        if objectType == "Frame" or objectType == "Button" or objectType == "CheckButton" or objectType == "EditBox" or objectType == "Slider" then
            return 3
        end
        if objectType == "Texture" then
            return 1
        end
        return 0
    end

    local function betterRecursiveCandidate(candidate, incumbent)
        if not incumbent then
            return true
        end
        if candidate.visibleTop > incumbent.visibleTop + 0.5 then
            return true
        end
        if math.abs(candidate.visibleTop - incumbent.visibleTop) > 0.5 then
            return false
        end
        if candidate.priority ~= incumbent.priority then
            return candidate.priority > incumbent.priority
        end
        if candidate.depth ~= incumbent.depth then
            return candidate.depth < incumbent.depth
        end
        if math.abs(candidate.left - incumbent.left) > 0.5 then
            return candidate.left < incumbent.left
        end
        local candidateKey = tostring(candidate.label or "") .. ":" .. tostring(candidate.type or "")
        local incumbentKey = tostring(incumbent.label or "") .. ":" .. tostring(incumbent.type or "")
        if candidateKey ~= incumbentKey then
            return candidateKey < incumbentKey
        end
        return candidate.order < incumbent.order
    end

    local function considerRecursive(obj, depth)
        local top, bottom, visibleTop = intersectsClip(obj, clipTop, clipBottom)
        if not top then
            return
        end
        visitOrder = visitOrder + 1
        local objectType, label, meaningful = getObjectIdentity(obj)
        local priority = candidatePriority(objectType, meaningful)
        if priority <= 0 then
            return
        end
        local candidate = {
            obj = obj,
            type = objectType,
            label = label,
            meaningful = meaningful,
            top = top,
            bottom = bottom,
            visibleTop = visibleTop,
            left = tonumber(obj.GetLeft and obj:GetLeft()) or 0,
            priority = priority,
            depth = depth or 0,
            order = visitOrder,
        }
        if meaningful then
            if betterRecursiveCandidate(candidate, meaningfulBest) then
                meaningfulBest = candidate
            end
            return
        end
        if betterRecursiveCandidate(candidate, fallbackBest) then
            fallbackBest = candidate
        end
    end

    local function visitVisibleTree(obj, depth)
        considerRecursive(obj, depth)
        if not obj or not obj.GetObjectType then
            return
        end
        local objectType = obj:GetObjectType()
        if objectType == "FontString" or objectType == "Texture" then
            return
        end
        if obj.GetRegions then
            for i = 1, select("#", obj:GetRegions()) do
                visitVisibleTree(select(i, obj:GetRegions()), (depth or 0) + 1)
            end
        end
        if obj.GetChildren then
            for i = 1, select("#", obj:GetChildren()) do
                visitVisibleTree(select(i, obj:GetChildren()), (depth or 0) + 1)
            end
        end
    end

    visitVisibleTree(directBest.obj, 0)

    local best = meaningfulBest or fallbackBest
    if not best then
        measurement.notes = "no candidate element"
        return measurement
    end

    measurement.firstElement = {
        type = best.type,
        label = best.label,
        offsetY = scrollChildTop - (best.top or scrollChildTop),
    }
    if not best.meaningful and best.label == "<unnamed>" then
        measurement.notes = "unnamed fallback candidate"
    end
    return measurement
end

function PortalAuthority:IsDiagPanelMeasurementReady(panelKey)
    panelKey = PA_DiagNormalizePanelKey(panelKey)
    local snapshot = self:BuildCpuDiagSettingsFirstOpenSnapshot()
    local panelInfo = PA_DiagFindSettingsPanelInfo(snapshot, panelKey)
    if not panelInfo then
        return false, "panel untracked"
    end
    if panelInfo.shown ~= true then
        return false, "panel hidden"
    end
    if panelInfo.ready == true then
        return true, nil
    end
    if panelInfo.sizeReady == true then
        return true, nil
    end
    return false, "panel not ready"
end

function PortalAuthority:BuildDiagPreWalkInitStates(cpuDiagSnapshot)
    local allowedKeys = {
        root = true,
        announcements = true,
        dock = true,
        timers = true,
        interrupt = true,
        combat = true,
        keystone = true,
        profiles = true,
    }
    local states = {
        root = nil,
        announcements = nil,
        dock = nil,
        timers = nil,
        interrupt = nil,
        combat = nil,
        keystone = nil,
        profiles = nil,
    }
    local settingsFirstOpen = cpuDiagSnapshot and cpuDiagSnapshot.settingsFirstOpen or nil
    local panels = settingsFirstOpen and settingsFirstOpen.panels or nil
    if type(panels) ~= "table" then
        return states
    end
    for i = 1, #panels do
        local panelInfo = panels[i]
        if panelInfo and type(panelInfo.key) == "string" and allowedKeys[panelInfo.key] then
            states[panelInfo.key] = panelInfo.initialized == true
        end
    end
    return states
end

function PortalAuthority:BuildDiagDumpPayload(phase)
    local nowTimestamp = nil
    if type(date) == "function" then
        local ok, value = pcall(date, "%Y-%m-%dT%H:%M:%S")
        if ok then
            nowTimestamp = value
        end
    end
    local cpuDiagSnapshot = self:BuildCpuDiagStatusSnapshot()
    local perfSnapshot = self:BuildPerfSnapshot()
    return {
        phase = tostring(phase or ""),
        timestamp = nowTimestamp,
        addonVersion = PA_GetAddonVersionString(),
        wowBuild = PA_DiagBuildWowBuildSnapshot(),
        character = PA_DiagBuildCharacterLabel(),
        class = PA_DiagBuildClassSnapshot(),
        spec = PA_DiagBuildSpecSnapshot(),
        diagGate = self:IsDiagDumpEnabled(),
        settingsWindowDevGate = self:IsSettingsWindowDevGateEnabled(),
        settingsWindowPublicGate = self:IsSettingsWindowPublicGateEnabled(),
        hostSurface = self:GetDiagHostSurfaceName(),
        walkDriver = self:GetDiagHostSurfaceName(),
        walkStartTarget = "root",
        walkOrder = self:GetSettingsPanelWalkOrder(),
        codeRevision = self:GetDiagCodeRevision(),
        interrupted = false,
        interruptReason = nil,
        completedPanels = {},
        skippedPanels = {},
        perfSnapshot = perfSnapshot,
        perfSnapshotRendered = table.concat(self:RenderPerfSnapshotLines(perfSnapshot) or {}, "\n"),
        preWalkCpuDiagSnapshot = cpuDiagSnapshot,
        preWalkInitStates = self:BuildDiagPreWalkInitStates(cpuDiagSnapshot),
        combatState = self:GetDiagCombatState(),
        hostFrameCount = nil,
        settingsPanelFrameCount = nil,
        panels = {},
    }
end

function PortalAuthority:FinalizeDiagDump(runtime, interrupted, interruptReason)
    if type(runtime) ~= "table" or runtime.finalized == true then
        return
    end
    runtime.finalized = true
    if type(runtime.token) == "number" then
        self._diagDumpToken = runtime.token
    end

    local payload = runtime.payload or {}
    payload.interrupted = interrupted == true
    payload.interruptReason = interruptReason
    payload.completedPanels = runtime.completedPanels or {}

    local skippedPanels = {}
    local completedLookup = {}
    for i = 1, #(payload.completedPanels or {}) do
        completedLookup[payload.completedPanels[i]] = true
    end
    for i = 1, #(runtime.walkOrder or {}) do
        local key = runtime.walkOrder[i]
        if not completedLookup[key] then
            skippedPanels[#skippedPanels + 1] = key
        end
    end
    payload.skippedPanels = skippedPanels

    local hostRoot = self:GetDiagActiveHostRootFrame()
    payload.hostFrameCount = PA_DiagRecursiveFrameCount(hostRoot)
    if payload.hostSurface == "blizzard-settings" then
        payload.settingsPanelFrameCount = PA_DiagRecursiveFrameCount(self:CpuDiagGetSettingsPanelFrame())
    else
        payload.settingsPanelFrameCount = nil
    end
    payload.combatState = self:GetDiagCombatState()

    PortalAuthorityDiagDump = payload
    self:CloseDiagRelevantSettingsHost()
    self._diagDumpRuntime = nil

    if interrupted == true and interruptReason == "combat-started" then
        PA_PrintDiagnosticMessage("capture interrupted by combat. Partial data saved.")
        return
    end
    if interrupted == true then
        PA_PrintDiagnosticMessage("capture interrupted. Partial data saved.")
        return
    end
    PA_PrintDiagnosticMessage("capture complete. Reload to flush SavedVariables.")
end

function PortalAuthority:AdvanceDiagDump(runtime, panelIndex, attempt)
    if type(runtime) ~= "table" or runtime.finalized == true then
        return
    end
    if runtime.token ~= self._diagDumpToken then
        return
    end
    if self:IsDiagDumpCombatBlocked() then
        self:FinalizeDiagDump(runtime, true, "combat-started")
        return
    end

    local walkOrder = runtime.walkOrder or PA_DIAG_WALK_ORDER
    local key = walkOrder[panelIndex]
    if key == nil then
        self:FinalizeDiagDump(runtime, false, nil)
        return
    end

    local normalizedAttempt = math.max(1, tonumber(attempt) or 1)
    if normalizedAttempt == 1 then
        local preSnapshot = self:BuildCpuDiagSettingsFirstOpenSnapshot()
        local preInfo = PA_DiagFindSettingsPanelInfo(preSnapshot, key)
        runtime.payload.panels[key] = runtime.payload.panels[key] or {
            preShowInit = preInfo and preInfo.initialized or nil,
            postShowInit = nil,
            hasScrollChild = nil,
            scrollWidth = nil,
            scrollChildTop = nil,
            firstElement = nil,
            notes = "",
        }
        local opened, openErr = self:OpenDiagHostedSettingsPanel(key)
        if not opened then
            runtime.payload.panels[key].notes = tostring(openErr or "open failed")
            runtime.completedPanels[#runtime.completedPanels + 1] = key
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if runtime.token == self._diagDumpToken and runtime.finalized ~= true then
                        self:AdvanceDiagDump(runtime, panelIndex + 1, 1)
                    end
                end)
            else
                self:AdvanceDiagDump(runtime, panelIndex + 1, 1)
            end
            return
        end
    end

    local ready, readyReason = self:IsDiagPanelMeasurementReady(key)
    if not ready and normalizedAttempt < PA_DIAG_PANEL_MAX_ATTEMPTS then
        if C_Timer and C_Timer.After then
            C_Timer.After(PA_DIAG_PANEL_RETRY_DELAY, function()
                if runtime.token == self._diagDumpToken and runtime.finalized ~= true then
                    self:AdvanceDiagDump(runtime, panelIndex, normalizedAttempt + 1)
                end
            end)
        else
            self:AdvanceDiagDump(runtime, panelIndex, normalizedAttempt + 1)
        end
        return
    end

    local measurement = self:MeasureHostedSettingsPanel(key)
    local postSnapshot = self:BuildCpuDiagSettingsFirstOpenSnapshot()
    local postInfo = PA_DiagFindSettingsPanelInfo(postSnapshot, key)
    local panelPayload = runtime.payload.panels[key] or {}
    panelPayload.postShowInit = postInfo and postInfo.initialized or nil
    panelPayload.hasScrollChild = measurement.hasScrollChild
    panelPayload.scrollWidth = measurement.scrollWidth
    panelPayload.scrollChildTop = measurement.scrollChildTop
    panelPayload.firstElement = measurement.firstElement

    local notes = {}
    if not ready and readyReason then
        notes[#notes + 1] = tostring(readyReason)
    end
    if measurement.notes and measurement.notes ~= "" then
        notes[#notes + 1] = tostring(measurement.notes)
    end
    panelPayload.notes = PA_DiagJoinNotes(notes)
    runtime.payload.panels[key] = panelPayload
    runtime.completedPanels[#runtime.completedPanels + 1] = key

    if C_Timer and C_Timer.After then
        C_Timer.After(PA_DIAG_PANEL_SETTLE_DELAY, function()
            if runtime.token == self._diagDumpToken and runtime.finalized ~= true then
                self:AdvanceDiagDump(runtime, panelIndex + 1, 1)
            end
        end)
    else
        self:AdvanceDiagDump(runtime, panelIndex + 1, 1)
    end
end

function PortalAuthority:StartDiagDump(phase)
    local normalizedPhase = trim(tostring(phase or ""))
    if normalizedPhase == "" then
        PA_PrintDiagnosticMessage("usage: /pa diagdump <phase>")
        return false
    end
    if not self:IsDiagDumpEnabled() then
        PA_PrintDiagnosticMessage("unavailable in this build.")
        return false
    end
    if self._diagDumpRuntime and self._diagDumpRuntime.finalized ~= true then
        PA_PrintDiagnosticMessage("capture already in progress.")
        return false
    end
    if self:IsDiagDumpCombatBlocked() then
        PA_PrintDiagnosticMessage("capture unavailable during combat.")
        return false
    end
    if self:IsDiagRelevantSettingsHostVisible() then
        self:CloseDiagRelevantSettingsHost()
        if self:IsDiagRelevantSettingsHostVisible() then
            PA_PrintDiagnosticMessage("close settings before running diagdump.")
            return false
        end
    end

    self._diagDumpToken = (tonumber(self._diagDumpToken) or 0) + 1
    local runtime = {
        token = self._diagDumpToken,
        finalized = false,
        walkOrder = self:GetSettingsPanelWalkOrder(),
        completedPanels = {},
        payload = self:BuildDiagDumpPayload(normalizedPhase),
    }
    self._diagDumpRuntime = runtime

    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if runtime.token == self._diagDumpToken and runtime.finalized ~= true then
                self:AdvanceDiagDump(runtime, 1, 1)
            end
        end)
    else
        self:AdvanceDiagDump(runtime, 1, 1)
    end
    return true
end

PortalAuthority.KeystoneUtility = PortalAuthority.KeystoneUtility or {}
local PA_KeystoneIsSlotted
local PA_SafeNumber

local function PA_LeaderOrAssist()
    return PA_SafeBool(UnitIsGroupLeader and UnitIsGroupLeader("player"))
        or PA_SafeBool(UnitIsGroupAssistant and UnitIsGroupAssistant("player"))
end

local function PA_ApplyExternalButtonSkin(btn)
    if not btn then
        return
    end
    local elv = _G.ElvUI
    local E = nil
    if type(elv) == "table" then
        E = elv[1] or elv
    end
    if E and E.GetModule then
        local okS, S = pcall(E.GetModule, E, "Skins")
        if okS and S and S.HandleButton then
            pcall(S.HandleButton, S, btn)
        end
    end
end
function PortalAuthority:KeystoneUtility_GetPullSeconds(short)
    local defaults = self.defaults or {}
    local fallback = short and (defaults.pullShortSeconds or 5) or (defaults.pullLongSeconds or 10)
    if not PortalAuthorityDB then
        return fallback
    end
    local value = short and PortalAuthorityDB.pullShortSeconds or PortalAuthorityDB.pullLongSeconds
    return math.floor(PA_Clamp(value, fallback, 1, 60))
end

function PortalAuthority:KeystoneUtility_UpdateButtons()
    local util = self.KeystoneUtility
    if not util then return end
    local kf = _G.ChallengesKeystoneFrame
    local container = util.container or (kf and kf.PA_KeystoneUtilContainer)
    if not container then return end

    local enabled = PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.keystoneHelperEnabled)
    local shown = kf and kf.IsShown and kf:IsShown()
    container:SetShown(enabled and shown)
    if not (enabled and shown) then
        return
    end

    if util.pullButton and util.pullButton.SetText then
        util.pullButton:SetText("Countdown")
    end

    local hasKeystone = PA_KeystoneIsSlotted and PA_KeystoneIsSlotted() or false
    local leaderOk = PA_LeaderOrAssist()
    local inCombat = PA_SafeBool(InCombatLockdown and InCombatLockdown())

    if util.readyButton then
        PA_ApplyExternalButtonSkin(util.readyButton)
        if (not inCombat) and hasKeystone and leaderOk then
            util.readyButton:Enable()
        else
            util.readyButton:Disable()
        end
    end

    if util.pullButton then
        PA_ApplyExternalButtonSkin(util.pullButton)
        if (not inCombat) and hasKeystone then
            util.pullButton:Enable()
        else
            util.pullButton:Disable()
        end
    end
end

function PortalAuthority:KeystoneUtility_EnsureKeystoneButtons()
    local kf = _G.ChallengesKeystoneFrame
    if not kf then return end

    local util = self.KeystoneUtility
    if not util.container then
        local container = CreateFrame("Frame", nil, kf)
        container:SetPoint("BOTTOMLEFT", kf, "BOTTOMLEFT", 0, 0)
        container:SetSize(110, 50)
        kf.PA_KeystoneUtilContainer = container
        util.container = container

        local function makeButton(parent, text)
            local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
            btn:SetSize(100, 22)
            btn:SetText(text)
            PA_ApplyExternalButtonSkin(btn)
            return btn
        end

        util.readyButton = makeButton(container, "Readycheck")
        util.readyButton:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        util.readyButton:SetScript("OnClick", function()
            if PA_SafeBool(InCombatLockdown and InCombatLockdown()) then return end
            if not (PA_KeystoneIsSlotted and PA_KeystoneIsSlotted()) then return end
            if not PA_LeaderOrAssist() then return end
            if type(DoReadyCheck) == "function" then
                pcall(DoReadyCheck)
            end
        end)

        util.pullButton = makeButton(container, "Countdown")
        util.pullButton:SetPoint("TOPLEFT", util.readyButton, "BOTTOMLEFT", 0, -4)
        util.pullButton:SetScript("OnClick", function()
            if PA_SafeBool(InCombatLockdown and InCombatLockdown()) then return end
            if not (PA_KeystoneIsSlotted and PA_KeystoneIsSlotted()) then return end
            self:KeystoneUtility_DoPull10()
        end)

        local function startPolling()
            if PortalAuthority.KeystoneUtility and PortalAuthority.KeystoneUtility.container then
                local utilNow = PortalAuthority.KeystoneUtility
                utilNow._pollElapsed = 0
                PortalAuthority.KeystoneUtility.container:SetScript("OnUpdate", function(_, elapsed)
                    local perfStart, perfState = PortalAuthority:PerfBegin("keystone_buttons_poll")
                    PortalAuthority:CpuDiagCount("keystone_buttons_poll")
                    utilNow._pollElapsed = (utilNow._pollElapsed or 0) + (tonumber(elapsed) or 0)
                    if utilNow._pollElapsed >= 0.25 then
                        utilNow._pollElapsed = 0
                        PortalAuthority:KeystoneUtility_UpdateButtons()
                    end
                    PortalAuthority:PerfEnd("keystone_buttons_poll", perfStart, perfState)
                end)
            end
        end

        if not util.frameHooksSet then
            util.frameHooksSet = true
            kf:HookScript("OnShow", function()
                local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_frame_onshow")
                startPolling()
                PortalAuthority:KeystoneUtility_UpdateButtons()
                PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
            end)
            kf:HookScript("OnHide", function()
                local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_frame_onhide")
                if PortalAuthority.KeystoneUtility and PortalAuthority.KeystoneUtility.container then
                    PortalAuthority.KeystoneUtility.container:SetScript("OnUpdate", nil)
                    PortalAuthority.KeystoneUtility.container:Hide()
                end
                PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
            end)
        end

        if not util.keystoneSlotHooksSet and kf.KeystoneSlot then
            util.keystoneSlotHooksSet = true
            local function queueRefresh()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        PortalAuthority:CpuDiagCount("callback_class_delayed_timer", "keystone_buttons_refresh")
                        PortalAuthority:KeystoneUtility_UpdateButtons()
                    end)
                else
                    PortalAuthority:KeystoneUtility_UpdateButtons()
                end
            end
            kf.KeystoneSlot:HookScript("OnClick", function()
                local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_slot_onclick")
                queueRefresh()
                PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
            end)
            kf.KeystoneSlot:HookScript("OnReceiveDrag", function()
                local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_slot_onreceivedrag")
                queueRefresh()
                PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
            end)
            kf.KeystoneSlot:HookScript("OnMouseUp", function()
                local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_slot_onmouseup")
                queueRefresh()
                PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
            end)
        end

        if kf.IsShown and kf:IsShown() then
            startPolling()
            PortalAuthority:KeystoneUtility_UpdateButtons()
        end
    end

    self:KeystoneUtility_UpdateButtons()
end

PA_SafeNumber = function(v)
    if v == nil then return 0 end
    local ok, s = pcall(tostring, v)
    if not ok or s == nil then return 0 end
    local n = tonumber(s)
    return n or 0
end

local function PA_GetOwnedKeystoneMapID()
    if C_MythicPlus and type(C_MythicPlus.GetOwnedKeystoneMapID) == "function" then
        local ok, mapID = pcall(C_MythicPlus.GetOwnedKeystoneMapID)
        if ok then
            local n = PA_SafeNumber(mapID)
            if n > 0 then return n end
        end
    end
    if C_MythicPlus and type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) == "function" then
        local ok, mapID = pcall(C_MythicPlus.GetOwnedKeystoneChallengeMapID)
        if ok then
            local n = PA_SafeNumber(mapID)
            if n > 0 then return n end
        end
    end
    return 0
end

local function PA_GetCurrentChallengeMapID()
    if C_ChallengeMode and type(C_ChallengeMode.GetActiveChallengeMapID) == "function" then
        local ok, mapID = pcall(C_ChallengeMode.GetActiveChallengeMapID)
        if ok then
            return PA_SafeNumber(mapID)
        end
    end
    return 0
end

local function PA_GetCurrentInstanceID()
    local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    return PA_SafeNumber(instanceID)
end

local function PA_HasSlottedKeystone()
    if C_ChallengeMode and type(C_ChallengeMode.GetSlottedKeystoneInfo) == "function" then
        local ok, mapID = pcall(C_ChallengeMode.GetSlottedKeystoneInfo)
        if ok and PA_SafeNumber(mapID) > 0 then
            return true
        end
    end
    return false
end
PA_KeystoneIsSlotted = function()
    if C_ChallengeMode and type(C_ChallengeMode.GetSlottedKeystoneInfo) == "function" then
        local ok, mapID = pcall(C_ChallengeMode.GetSlottedKeystoneInfo)
        if ok and PA_SafeNumber(mapID) > 0 then
            return true
        end
    end
    return false
end

local function PA_IsAddOnLoaded(name)
    if trim(name) == "" then return false end
    if C_AddOns and type(C_AddOns.IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    if type(IsAddOnLoaded) == "function" then
        local ok, loaded = pcall(IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    return false
end

local PA_KEYSTONE_ITEM_IDS = {
    [180653] = true,
    [151086] = true,
    [158923] = true,
    [138019] = true,
}

function PortalAuthority:KeystoneUtility_TryAutoSlot()
    if not PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.keystoneAutoSlotEnabled) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local kf = _G.ChallengesKeystoneFrame
    if not (kf and kf.IsShown and kf:IsShown()) then return end
    self.KeystoneUtility = self.KeystoneUtility or {}
    local util = self.KeystoneUtility
    local now = GetTime()
    if (now - PA_SafeNumber(util.autoSlotLastAttempt)) < 0.5 then return end
    util.autoSlotLastAttempt = now
    local owned = PA_GetOwnedKeystoneMapID()
    if owned <= 0 then return end
    local _, _, _, _, _, _, _, inst = GetInstanceInfo()
    inst = PA_SafeNumber(inst)
    if owned > 0 and inst > 0 and owned ~= inst then return end

    if PA_KeystoneIsSlotted() then return end

    if C_ChallengeMode and type(C_ChallengeMode.SlotKeystone) == "function" then
        pcall(C_ChallengeMode.SlotKeystone)
        if PA_KeystoneIsSlotted() then
            if C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    PortalAuthority:CpuDiagCount("callback_class_delayed_timer", "keystone_buttons_refresh")
                    PortalAuthority:KeystoneUtility_UpdateButtons()
                end)
            else
                self:KeystoneUtility_UpdateButtons()
            end
            return
        end
    end

    if C_Container and type(C_Container.GetContainerNumSlots) == "function" and type(C_Container.GetContainerItemID) == "function" and type(C_Container.UseContainerItem) == "function" then
        local maxBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
        for bag = BACKPACK_CONTAINER or 0, maxBag do
            local okSlots, slots = pcall(C_Container.GetContainerNumSlots, bag)
            slots = okSlots and tonumber(slots) or 0
            if slots and slots > 0 then
                for slot = 1, slots do
                    local okItem, itemID = pcall(C_Container.GetContainerItemID, bag, slot)
                    local isKeystone = false
                    if okItem and PA_KEYSTONE_ITEM_IDS[PA_SafeNumber(itemID)] then
                        isKeystone = true
                    elseif C_Container.GetContainerItemLink then
                        local okLink, link = pcall(C_Container.GetContainerItemLink, bag, slot)
                        if okLink and link ~= nil then
                            local okFind, found = pcall(string.find, tostring(link), "|Hkeystone:", 1, true)
                            if okFind and found ~= nil then
                                isKeystone = true
                            end
                        end
                    end
                    if isKeystone then
                        pcall(C_Container.UseContainerItem, bag, slot)
                        if C_Timer and C_Timer.After then
                            C_Timer.After(0, function()
                                PortalAuthority:CpuDiagCount("callback_class_delayed_timer", "keystone_buttons_refresh")
                                PortalAuthority:KeystoneUtility_UpdateButtons()
                            end)
                        else
                            self:KeystoneUtility_UpdateButtons()
                        end
                        if C_Timer and C_Timer.After then
                            local function retrySlot()
                                PortalAuthority:CpuDiagCount("callback_class_delayed_timer", "keystone_slot_retry")
                                if PA_KeystoneIsSlotted() then return end
                                if C_ChallengeMode and type(C_ChallengeMode.SlotKeystone) == "function" then
                                    pcall(C_ChallengeMode.SlotKeystone)
                                end
                            end
                            C_Timer.After(0, retrySlot)
                            C_Timer.After(0.1, retrySlot)
                        end
                        return
                    end
                end
            end
        end
    end
end

function PortalAuthority:KeystoneUtility_TryStartKey(fromFallback)
    if not PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.keystoneAutoStartEnabled) then return end
    if PA_SafeBool(InCombatLockdown and InCombatLockdown()) then return end
    if not (C_ChallengeMode and type(C_ChallengeMode.StartChallengeMode) == "function") then return end
    if not PA_LeaderOrAssist() then return end

    if not PA_KeystoneIsSlotted() then return end

    local okStart = pcall(C_ChallengeMode.StartChallengeMode)
    if okStart then
        if _G.ChallengesKeystoneFrame and _G.ChallengesKeystoneFrame.Hide then
            _G.ChallengesKeystoneFrame:Hide()
        end
        self:KeystoneUtility_UpdateButtons()
    end

    self.KeystoneUtility = self.KeystoneUtility or {}
    self.KeystoneUtility.pendingAutoStartWaiting = false
    self.KeystoneUtility.pendingAutoStartConsumed = true
end

function PortalAuthority:KeystoneUtility_StartPull(seconds)
    if PA_SafeBool(InCombatLockdown and InCombatLockdown()) then return end
    if not (PA_KeystoneIsSlotted and PA_KeystoneIsSlotted()) then return end

    local sec = math.floor(PA_Clamp(seconds, 10, 1, 60))
    local leaderOk = PA_LeaderOrAssist()
    local autoStartEnabled = PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.keystoneAutoStartEnabled)
    self.KeystoneUtility = self.KeystoneUtility or {}
    local util = self.KeystoneUtility
    util.pendingAutoStartAt = GetTime()
    util.pendingAutoStartSec = sec
    util.pendingAutoStartSawStartTimer = false
    util.pendingAutoStartWaiting = false
    util.pendingAutoStartConsumed = false

    if RunMacroText then
        pcall(RunMacroText, string.format("/cd %d", sec))
    end

    if C_PartyInfo and type(C_PartyInfo.DoCountdown) == "function" then
        pcall(C_PartyInfo.DoCountdown, sec)
    end

    if autoStartEnabled and leaderOk then
        util.pendingAutoStartWaiting = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                PortalAuthority:CpuDiagCount("callback_class_delayed_timer", "keystone_autostart_arm_clear")
                local utilNow = PortalAuthority.KeystoneUtility
                if not utilNow then return end
                if utilNow.pendingAutoStartWaiting and not utilNow.pendingAutoStartSawStartTimer then
                    utilNow.pendingAutoStartWaiting = false
                end
            end)
        end
    else
        util.pendingAutoStartWaiting = false
    end
end

function PortalAuthority:KeystoneUtility_DoPull10()
    if PA_SafeBool(InCombatLockdown and InCombatLockdown()) then return end
    if not (PA_KeystoneIsSlotted and PA_KeystoneIsSlotted()) then return end
    self.KeystoneUtility = self.KeystoneUtility or {}
    local util = self.KeystoneUtility
    local autoStartEnabled = PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.keystoneAutoStartEnabled)
    local leaderOk = PA_LeaderOrAssist()

    util.pendingAutoStartAt = GetTime()
    util.pendingAutoStartSec = 10
    util.pendingAutoStartSawStartTimer = false
    util.pendingAutoStartWaiting = false
    util.pendingAutoStartConsumed = false

    local macroOk = false
    if RunMacroText then
        macroOk = pcall(RunMacroText, "/cd 10") and true or false
    end

    local blizzOk = false
    if (not macroOk) and C_PartyInfo and type(C_PartyInfo.DoCountdown) == "function" then
        blizzOk = pcall(C_PartyInfo.DoCountdown, 10) and true or false
    end

    local countdownStarted = macroOk or blizzOk

    if countdownStarted and autoStartEnabled and leaderOk then
        util.pendingAutoStartWaiting = true
        if C_Timer and C_Timer.After then
            C_Timer.After(10, function()
                PortalAuthority:CpuDiagCount("callback_class_delayed_timer", "keystone_autostart_fallback")
                local utilNow = PortalAuthority.KeystoneUtility
                if not utilNow then return end
                if utilNow.pendingAutoStartWaiting and (not utilNow.pendingAutoStartConsumed) and (not utilNow.pendingAutoStartSawStartTimer) then
                    PortalAuthority:KeystoneUtility_TryStartKey(true)
                end
            end)
        end
    else
        util.pendingAutoStartWaiting = false
    end
end

function PortalAuthority:KeystoneUtility_OnEvent(event, ...)
    if event == "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN" then
        if PortalAuthorityDB and PortalAuthorityDB.keystoneHelperEnabled then
            self:KeystoneUtility_EnsureKeystoneButtons()
        end
        if InCombatLockdown and InCombatLockdown() then return end
        self:KeystoneUtility_TryAutoSlot()
        return
    end

    if event == "START_TIMER" then
        if not PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.keystoneAutoStartEnabled) then return end
        if PA_SafeBool(InCombatLockdown and InCombatLockdown()) then return end
        self.KeystoneUtility = self.KeystoneUtility or {}
        local util = self.KeystoneUtility
        if not util.pendingAutoStartWaiting then return end
        local timerType, timeSeconds, totalTime = ...
        local dur = tonumber(totalTime) or tonumber(timeSeconds)
        if not dur or dur < 1 or dur > 60 then return end
        if util.pendingAutoStartSec and math.abs(dur - util.pendingAutoStartSec) > 0.5 then return end
        if not PA_LeaderOrAssist() then return end
        if not (PA_KeystoneIsSlotted and PA_KeystoneIsSlotted()) then return end
        if not (C_Timer and C_Timer.After) then return end
        util.pendingAutoStartSawStartTimer = true
        util.pendingAutoStartConsumed = true
        util.pendingAutoStartWaiting = false
        C_Timer.After(dur, function()
            PortalAuthority:CpuDiagCount("callback_class_delayed_timer", "keystone_autostart_startkey")
            PortalAuthority:KeystoneUtility_TryStartKey()
        end)
        return
    end
end

function PortalAuthority:KeystoneUtility_SetupReleaseGate()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    local util = self.KeystoneUtility
    if util.releaseGateSetup then return end
    util.releaseGateSetup = true

    local function getModifierDown(modifier)
        if modifier == "CTRL" then
            return IsControlKeyDown and IsControlKeyDown()
        end
        return IsShiftKeyDown and IsShiftKeyDown()
    end

    local function ensureHint(popup)
        if popup.PAReleaseGateHint then
            local hint = popup.PAReleaseGateHint
            hint:ClearAllPoints()
            hint:SetPoint("TOP", popup, "BOTTOM", 0, 20)
            hint:SetTextColor(1, 0.2, 0.2, 1)
            return hint
        end
        local hint = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        hint:ClearAllPoints()
        hint:SetPoint("TOP", popup, "BOTTOM", 0, 10)
        hint:SetTextColor(1, 0.2, 0.2, 1)
        popup.PAReleaseGateHint = hint
        return hint
    end

    local function ensureBlocker(popup, releaseButton)
        if popup.PAReleaseGateBlocker then
            return popup.PAReleaseGateBlocker
        end
        local blocker = CreateFrame("Button", nil, popup)
        blocker:SetAllPoints(releaseButton)
        blocker:SetFrameLevel((releaseButton:GetFrameLevel() or 1) + 5)
        blocker:EnableMouse(true)
        blocker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        blocker:SetScript("OnClick", function() end)
        blocker:Hide()
        popup.PAReleaseGateBlocker = blocker
        return blocker
    end

    local function updatePopup(popup, elapsed)
        if not popup or not popup:IsShown() then return end
        local okW, which = pcall(tostring, popup.which)
        if not okW then return end
        local releaseButton = popup.GetButton and popup:GetButton(1) or nil
        if not releaseButton then return end
        local blocker = ensureBlocker(popup, releaseButton)

        if which == "RECOVER_CORPSE" then
            blocker:Hide()
            releaseButton:Show()
            releaseButton:Enable()
            releaseButton:SetAlpha(1)
            if popup.PAReleaseGateHint then popup.PAReleaseGateHint:Hide() end
            popup.PAReleaseGateHeld = 0
            popup.PAReleaseGateClicked = false
            return
        end
        if which ~= "DEATH" then
            blocker:Hide()
            releaseButton:SetAlpha(1)
            return
        end

        if not PA_SafeBool(PortalAuthorityDB and PortalAuthorityDB.releaseGateEnabled) then
            blocker:Hide()
            releaseButton:Show()
            releaseButton:Enable()
            releaseButton:SetAlpha(1)
            if popup.PAReleaseGateHint then popup.PAReleaseGateHint:Hide() end
            popup.PAReleaseGateHeld = 0
            popup.PAReleaseGateClicked = false
            return
        end

        local modifier = PortalAuthorityDB.releaseGateModifier == "CTRL" and "CTRL" or "SHIFT"
        local holdSeconds = PA_Clamp(PortalAuthorityDB.releaseGateHoldSeconds, 1.0, 0.0, 5.0)
        local hint = ensureHint(popup)
        hint:SetText(string.format("Hold %s to Release", modifier))
        hint:Show()

        local down = getModifierDown(modifier)
        if not down then
            popup.PAReleaseGateHeld = 0
            popup.PAReleaseGateClicked = false
            blocker:Show()
            releaseButton:Show()
            releaseButton:Enable()
            releaseButton:SetAlpha(0.35)
            return
        end

        blocker:Hide()
        releaseButton:Show()
        releaseButton:Enable()
        releaseButton:SetAlpha(1)
        if popup.PAReleaseGateClicked then
            return
        end

        popup.PAReleaseGateHeld = (popup.PAReleaseGateHeld or 0) + (tonumber(elapsed) or 0)
        if popup.PAReleaseGateHeld >= holdSeconds then
            popup.PAReleaseGateClicked = true
            pcall(function() releaseButton:Click() end)
        end
    end

    local function hookPopup(popup)
        if not popup then return end
        if not popup.PAReleaseGateHooked then
            popup.PAReleaseGateHooked = true
            popup:HookScript("OnUpdate", function(selfPopup, elapsed)
                local perfStart, perfState = PortalAuthority:PerfBegin("release_gate_popup_onupdate")
                PortalAuthority:CpuDiagCount("release_gate_popup_onupdate")
                updatePopup(selfPopup, elapsed)
                PortalAuthority:PerfEnd("release_gate_popup_onupdate", perfStart, perfState)
            end)
            popup:HookScript("OnHide", function(selfPopup)
                selfPopup.PAReleaseGateHeld = 0
                selfPopup.PAReleaseGateClicked = false
                local releaseButton = selfPopup.GetButton and selfPopup:GetButton(1) or nil
                local blocker = selfPopup.PAReleaseGateBlocker
                if blocker then
                    blocker:Hide()
                end
                if releaseButton then
                    releaseButton:Show()
                    releaseButton:Enable()
                    releaseButton:SetAlpha(1)
                end
                if selfPopup.PAReleaseGateHint then
                    selfPopup.PAReleaseGateHint:Hide()
                end
            end)
        end
        hooksecurefunc(popup, "Show", function(selfPopup)
            local okW, which = pcall(tostring, selfPopup.which)
            if not okW then return end
            if which == "RECOVER_CORPSE" then
                local releaseButton = selfPopup.GetButton and selfPopup:GetButton(1) or nil
                local blocker = selfPopup.PAReleaseGateBlocker
                if blocker then
                    blocker:Hide()
                end
                if releaseButton then
                    releaseButton:Show()
                    releaseButton:Enable()
                    releaseButton:SetAlpha(1)
                end
                if selfPopup.PAReleaseGateHint then
                    selfPopup.PAReleaseGateHint:Hide()
                end
                return
            end
            if which ~= "DEATH" then return end
            selfPopup.PAReleaseGateHeld = 0
            selfPopup.PAReleaseGateClicked = false
            updatePopup(selfPopup, 0)
        end)
    end

    hookPopup(_G.StaticPopup1)
    hookPopup(_G.StaticPopup2)
    hookPopup(_G.StaticPopup3)
    hookPopup(_G.StaticPopup4)
end

function PortalAuthority:InitializeKeystoneUtility()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    self.KeystoneUtility = self.KeystoneUtility or {}
    if self.KeystoneUtility.initialized then return end
    self.KeystoneUtility.initialized = true

    local frame = CreateFrame("Frame")
    self.KeystoneUtility.frame = frame
    frame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN")
    frame:RegisterEvent("START_TIMER")
    frame:SetScript("OnEvent", function(_, event, ...)
        PortalAuthority:CpuDiagRecordDispatcherEvent("keystone", event)
        local perfStart, perfState = PortalAuthority:PerfBegin("keystone_event_dispatch")
        PortalAuthority:KeystoneUtility_OnEvent(event, ...)
        PortalAuthority:PerfEnd("keystone_event_dispatch", perfStart, perfState)
    end)

    self:KeystoneUtility_SetupReleaseGate()
end

local PA_KEYSTONE_TOOLTIP_STOPWORDS = {
    ["the"] = true,
    ["of"] = true,
    ["and"] = true,
}

local function PA_ContainsNoCase(haystack, needle)
    local h = trim(haystack)
    local n = trim(needle)
    if h == "" or n == "" then
        return false
    end
    return string.find(string.lower(h), string.lower(n), 1, true) ~= nil
end

local function PA_BuildAcronym(text, maxLen)
    local out = {}
    for word in string.gmatch(trim(text), "%S+") do
        local lowerWord = string.lower(word)
        if not PA_KEYSTONE_TOOLTIP_STOPWORDS[lowerWord] then
            local first = string.sub(word, 1, 1)
            if first ~= "" then
                table.insert(out, string.upper(first))
                if #out >= (maxLen or 4) then
                    break
                end
            end
        end
    end
    if #out == 0 then
        return ""
    end
    return table.concat(out, "")
end

local function PA_GetKeystoneLink(tooltip, tooltipData)
    if tooltipData and type(tooltipData.hyperlink) == "string" then
        return tooltipData.hyperlink
    end
    if tooltip and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if type(link) == "string" then
            return link
        end
    end
    return nil
end

local function PA_ParseKeystoneLink(link)
    if type(link) ~= "string" then
        return nil
    end
    if not string.find(link, "|Hkeystone:", 1, true) then
        return nil
    end
    local itemString = link:match("|H(keystone:[^|]+)|")
    if not itemString then
        return nil
    end
    local fields = { strsplit(":", itemString) }
    local mapID = PA_ToNumber(fields[3], 0)
    local level = PA_ToNumber(fields[4], 0)
    local affixes = {}
    for i = 5, #fields do
        local id = PA_ToNumber(fields[i], 0)
        if id > 0 then
            table.insert(affixes, id)
        end
    end
    return {
        mapID = mapID,
        level = level,
        affixes = affixes,
    }
end

local function PA_GetKeystoneNameVariants(mapID)
    local fullName = nil
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and mapID and mapID > 0 then
        local ok, name = pcall(C_ChallengeMode.GetMapUIInfo, mapID)
        if ok and type(name) == "string" then
            fullName = trim(name)
        end
    end

    local nickname = nil
    local short = nil
    if fullName and fullName ~= "" then
        nickname = trim((fullName:match("^([^,]+),") or ""))
        if nickname == "" then
            nickname = nil
        end
    end

    if PortalAuthority and PortalAuthority.SpellMap then
        for _, dungeon in pairs(PortalAuthority.SpellMap) do
            if dungeon and dungeon.category == "mplus" then
                local dest = type(dungeon.dest) == "string" and trim(dungeon.dest) or ""
                local shortName = type(dungeon.short) == "string" and trim(dungeon.short) or ""
                if dest ~= "" and fullName and PA_ContainsNoCase(fullName, dest) then
                    nickname = dest
                    if shortName ~= "" then
                        short = shortName
                    end
                    break
                end
            end
        end
    end

    if (not short or short == "") and fullName and fullName ~= "" then
        short = PA_BuildAcronym(fullName, 4)
    end

    return fullName, nickname, short
end

local function PA_ReadTooltipLines(tooltip)
    local lines = {}
    if not tooltip or not tooltip.GetName or not tooltip.NumLines then
        return lines
    end
    local baseName = tooltip:GetName()
    if type(baseName) ~= "string" or baseName == "" then
        return lines
    end
    local numLines = tooltip:NumLines() or 0
    for i = 1, numLines do
        local leftFS = _G[baseName .. "TextLeft" .. i]
        local rightFS = _G[baseName .. "TextRight" .. i]
        local leftText = leftFS and leftFS.GetText and leftFS:GetText() or nil
        local rightText = rightFS and rightFS.GetText and rightFS:GetText() or nil
        local lr, lg, lb = 1, 1, 1
        local rr, rg, rb = 1, 1, 1
        if leftFS and leftFS.GetTextColor then
            lr, lg, lb = leftFS:GetTextColor()
        end
        if rightFS and rightFS.GetTextColor then
            rr, rg, rb = rightFS:GetTextColor()
        end
        table.insert(lines, {
            leftText = leftText or "",
            rightText = rightText or "",
            lr = lr or 1,
            lg = lg or 1,
            lb = lb or 1,
            rr = rr or 1,
            rg = rg or 1,
            rb = rb or 1,
        })
    end
    return lines
end

local function PA_WriteTooltipLines(tooltip, lines)
    if not tooltip then
        return
    end
    tooltip:ClearLines()
    for _, line in ipairs(lines) do
        local left = line.leftText or ""
        local right = line.rightText or ""
        if right ~= "" then
            tooltip:AddDoubleLine(left, right, line.lr or 1, line.lg or 1, line.lb or 1, line.rr or 1, line.rg or 1, line.rb or 1)
        else
            tooltip:AddLine(left, line.lr or 1, line.lg or 1, line.lb or 1)
        end
    end
    tooltip:Show()
end

function PortalAuthority:KeystoneTooltip_OnItemTooltip(tooltip, tooltipData)
    if not PortalAuthorityDB or not tooltip then
        return false
    end
    local link = PA_GetKeystoneLink(tooltip, tooltipData)
    if type(link) ~= "string" then
        return false
    end
    if not string.find(link, "|Hkeystone:", 1, true) then
        return false
    end
    if tooltip.__PAKeystoneBusy then
        return false
    end

    tooltip.__PAKeystoneBusy = true
    local ok = pcall(function()
        local parsed = PA_ParseKeystoneLink(link)
        if not parsed then
            return
        end

        local mapID = parsed.mapID or 0
        local level = parsed.level or 0
        local affixIDs = parsed.affixes or {}
        local fullName, nickname, short = PA_GetKeystoneNameVariants(mapID)
        local lines = PA_ReadTooltipLines(tooltip)
        if #lines == 0 then
            return
        end

        local changed = false
        local db = PortalAuthorityDB

        local dungeonLineIndex = nil
        local dungeonExisting = nil
        local mythicLineIndex = nil
        for i, line in ipairs(lines) do
            local lt = line.leftText or ""
            if not dungeonLineIndex and PA_ContainsNoCase(lt, "Keystone:") then
                dungeonLineIndex = i
                dungeonExisting = trim((lt:gsub("^[%s]*Keystone:%s*", "")))
            end
            if not mythicLineIndex and PA_ContainsNoCase(lt, "Mythic Level") then
                mythicLineIndex = i
            end
        end

        if dungeonLineIndex then
            local mode = db.keystoneTooltipDungeonNameMode
            local removePrefix = PA_SafeBool(db.keystoneTooltipRemoveKeystonePrefix)
            local displayName = nil
            if mode == "FULL" then
                displayName = fullName or dungeonExisting
            elseif mode == "SHORT" then
                displayName = nickname or fullName or dungeonExisting
            elseif mode == "NICKNAME" then
                displayName = short or fullName or dungeonExisting
            elseif mode == "NICKNAME_FULL" then
                local correctedNickname = short or nickname
                if correctedNickname and fullName and correctedNickname ~= fullName then
                    displayName = correctedNickname .. " - " .. fullName
                else
                    displayName = correctedNickname or fullName or dungeonExisting
                end
            end
            if displayName and trim(displayName) ~= "" then
                local newText = removePrefix and trim(displayName) or ("Keystone: " .. trim(displayName))
                if lines[dungeonLineIndex].leftText ~= newText then
                    lines[dungeonLineIndex].leftText = newText
                    changed = true
                end
            elseif removePrefix then
                local newText = trim((lines[dungeonLineIndex].leftText or ""):gsub("^[%s]*Keystone:%s*", ""))
                if lines[dungeonLineIndex].leftText ~= newText then
                    lines[dungeonLineIndex].leftText = newText
                    changed = true
                end
            end
        end

        local tooltipLevel = level
        if tooltipLevel <= 0 then
            for _, line in ipairs(lines) do
                local n = tonumber((line.leftText or ""):match("(%d+)"))
                if n and PA_ContainsNoCase(line.leftText or "", "Mythic Level") then
                    tooltipLevel = n
                    break
                end
            end
        end
        local removeMythicLevelLine = false
        if db.keystoneTooltipLevelMode == "HIDE" then
            removeMythicLevelLine = true
        elseif tooltipLevel > 0 and db.keystoneTooltipLevelMode ~= "NO_CHANGES" then
            local formatted = nil
            if db.keystoneTooltipLevelMode == "PLUS_N" then
                formatted = "+" .. tostring(math.floor(tooltipLevel))
            elseif db.keystoneTooltipLevelMode == "N" then
                formatted = tostring(math.floor(tooltipLevel))
            elseif db.keystoneTooltipLevelMode == "M_N_PLUS" then
                formatted = "m" .. tostring(math.floor(tooltipLevel)) .. "+"
            end
            if formatted then
                if PA_SafeBool(db.keystoneTooltipLevelAddToName) and dungeonLineIndex then
                    local dungeonText = trim(lines[dungeonLineIndex].leftText or "")
                    dungeonText = trim((dungeonText:gsub("%(Level%s*[%+mM]?%d+%+?%)", "")))
                    local newDungeonText = trim(dungeonText .. " " .. formatted)
                    if newDungeonText ~= dungeonText then
                        lines[dungeonLineIndex].leftText = newDungeonText
                        changed = true
                    end
                    removeMythicLevelLine = true
                elseif mythicLineIndex then
                    if lines[mythicLineIndex].leftText ~= formatted then
                        lines[mythicLineIndex].leftText = formatted
                        changed = true
                    end
                elseif dungeonLineIndex then
                    local old = lines[dungeonLineIndex].leftText or ""
                    local new = old:gsub("%(Level%s*%d+%)", formatted)
                    if new ~= old then
                        lines[dungeonLineIndex].leftText = new
                        changed = true
                    end
                end
            end
        end

        local affixNames = {}
        if #affixIDs > 0 and C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
            for _, affixID in ipairs(affixIDs) do
                local okAffix, affixName = pcall(C_ChallengeMode.GetAffixInfo, affixID)
                if okAffix and type(affixName) == "string" and trim(affixName) ~= "" then
                    affixNames[string.lower(trim(affixName))] = true
                end
            end
        end

        local filtered = {}
        for i, line in ipairs(lines) do
            local left = line.leftText or ""
            local lowerLeft = string.lower(left)
            local drop = false

            if (not drop) and removeMythicLevelLine and mythicLineIndex and i == mythicLineIndex then
                drop = true
            end
            if db.keystoneTooltipResilientMode == "HIDE" and string.find(lowerLeft, "resilient", 1, true) then
                drop = true
            end
            if (not drop) and db.keystoneTooltipSoulboundMode == "HIDE" and (
                string.find(lowerLeft, "soulbound", 1, true)
                or string.find(lowerLeft, "binds when picked up", 1, true)
                or string.find(lowerLeft, "binds when equipped", 1, true)
            ) then
                drop = true
            end
            if (not drop) and db.keystoneTooltipUniqueMode == "HIDE" and string.find(lowerLeft, "unique", 1, true) == 1 then
                drop = true
            end
            if (not drop) and db.keystoneTooltipDurationMode == "HIDE" and string.find(lowerLeft, "duration", 1, true) then
                drop = true
            end

            local isAffixHeader = string.find(lowerLeft, "dungeon modifiers", 1, true) or string.find(lowerLeft, "affixes", 1, true)
            if (not drop) and db.keystoneTooltipAffixesMode == "HIDE" then
                if isAffixHeader then
                    drop = true
                else
                    for affixNameLower in pairs(affixNames) do
                        if string.find(lowerLeft, affixNameLower, 1, true) then
                            drop = true
                            break
                        end
                    end
                end
            end

            if not drop then
                if db.keystoneTooltipAffixesMode == "RENAME_AFFIXES" and isAffixHeader then
                    local newText = left:gsub("[Dd]ungeon [Mm]odifiers", "Affixes")
                    if newText ~= left then
                        line.leftText = newText
                        changed = true
                    end
                    local c = db.keystoneTooltipAffixesColor or { r = 1, g = 0.82, b = 0 }
                    line.lr = c.r or 1
                    line.lg = c.g or 0.82
                    line.lb = c.b or 0
                    changed = true
                end
                table.insert(filtered, line)
            else
                changed = true
            end

            if i == #lines then
                -- no-op
            end
        end

        if db.keystoneTooltipRPQuoteMode == "HIDE" and #filtered > 1 then
            for i = #filtered, 2, -1 do
                local line = filtered[i]
                local txt = trim(line.leftText or "")
                if txt ~= "" then
                    local r, g, b = line.lr or 1, line.lg or 1, line.lb or 1
                    if r > 0.9 and g > 0.7 and b < 0.3 then
                        table.remove(filtered, i)
                        changed = true
                    end
                    break
                end
            end
        end

        if changed then
            PA_WriteTooltipLines(tooltip, filtered)
        end
    end)
    tooltip.__PAKeystoneBusy = nil
    if not ok then
        return true
    end
    return true
end

function PortalAuthority:InitializeKeystoneTooltip()
    if PA_IsStaticBaselineGateEnabled() then
        return false
    end
    if self._keystoneTooltipHooked then
        return true
    end
    self._keystoneTooltipHooked = true

    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, tooltipData)
            local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
            local handled = PortalAuthority:KeystoneTooltip_OnItemTooltip(tooltip, tooltipData)
            if handled then
                PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_tooltip_postcall")
            end
            PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
        end)
    else
        if GameTooltip and GameTooltip.HookScript then
            GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
                local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                local handled = PortalAuthority:KeystoneTooltip_OnItemTooltip(tooltip, nil)
                if handled then
                    PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_tooltip_gametooltip")
                end
                PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
            end)
        end
        if ItemRefTooltip and ItemRefTooltip.HookScript then
            ItemRefTooltip:HookScript("OnTooltipSetItem", function(tooltip)
                local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                local handled = PortalAuthority:KeystoneTooltip_OnItemTooltip(tooltip, nil)
                if handled then
                    PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_tooltip_itemref")
                end
                PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
            end)
        end
    end

    if SetItemRef and C_Timer and C_Timer.After then
        hooksecurefunc("SetItemRef", function()
            C_Timer.After(0, function()
                if ItemRefTooltip and ItemRefTooltip:IsShown() then
                    local perfStart, perfState = PortalAuthority:PerfBegin("callback_class_ui_hook")
                    local handled = PortalAuthority:KeystoneTooltip_OnItemTooltip(ItemRefTooltip, nil)
                    if handled then
                        PortalAuthority:CpuDiagCount("callback_class_ui_hook", "keystone_setitemref_after")
                    end
                    PortalAuthority:PerfEnd("callback_class_ui_hook", perfStart, perfState)
                end
            end)
        end)
    end
    return true
end

function PortalAuthority:ApplyKeystoneUtilitySettings()
    if not PortalAuthorityDB then return end
    if PA_SafeBool(PortalAuthorityDB.keystoneHelperEnabled) then
        self:KeystoneUtility_EnsureKeystoneButtons()
    elseif self.KeystoneUtility and self.KeystoneUtility.container then
        self.KeystoneUtility.container:Hide()
    end
    self:KeystoneUtility_UpdateButtons()
end

function PortalAuthority:SetGlobalLockState(locked)
    self:EnsureDB()
    local db = PortalAuthorityDB
    if not db then
        return false
    end

    locked = not not locked
    local desiredUnlocked = not locked
    local priorDeferredSharedRefresh = self._deferSharedMarkerTickerRefresh and true or false

    -- 1) Mythic+ Dock
    db.dockLocked = locked

    -- 2) Combat Alerts (On-screen Alerts anchor)
    db.deathAlertLocked = locked

    -- 3) Timers
    db.modules = db.modules or {}
    db.modules.timers = db.modules.timers or {}
    db.modules.timers.locked = locked

    -- 4) Interrupt Tracker
    db.modules.interruptTracker = db.modules.interruptTracker or {}
    db.modules.interruptTracker.locked = locked

    self._deferSharedMarkerTickerRefresh = true

    local modulesApi = self.Modules
    if modulesApi and modulesApi.SetUnlocked then
        modulesApi:SetUnlocked(desiredUnlocked)
    end

    local timersModule = modulesApi and modulesApi.registry and modulesApi.registry.timers or nil
    if timersModule then
        local timersEnabled = timersModule.IsEnabled and timersModule:IsEnabled()
        if desiredUnlocked and timersEnabled and timersModule.Initialize and not (timersModule.frame or timersModule.mainFrame) then
            timersModule:Initialize()
        end
        if timersModule.ApplyPosition then
            timersModule:ApplyPosition()
        end
        if timersModule.EvaluateVisibility and (timersModule.frame or timersModule.mainFrame) then
            timersModule:EvaluateVisibility("slash-global-lock-toggle")
        end
        if desiredUnlocked and timersModule.Tick then
            timersModule:Tick()
        end
    end

    if modulesApi and modulesApi.NotifyPositionChanged then
        local tdb = db.modules and db.modules.timers or nil
        if tdb then
            modulesApi:NotifyPositionChanged(
                "timers",
                math.floor(tonumber(tdb.x) or 0),
                math.floor(tonumber(tdb.y) or 0)
            )
        end
        local idb = db.modules and db.modules.interruptTracker or nil
        if idb then
            modulesApi:NotifyPositionChanged(
                "interruptTracker",
                math.floor(tonumber(idb.x) or 0),
                math.floor(tonumber(idb.y) or 0)
            )
        end
    end

    local interruptModule = modulesApi and modulesApi.registry and modulesApi.registry.interruptTracker or nil
    if interruptModule then
        local interruptEnabled = interruptModule.IsEnabled and interruptModule:IsEnabled()
        if desiredUnlocked and interruptEnabled and interruptModule.Initialize and not interruptModule.frame then
            interruptModule:Initialize()
        end
        if interruptModule.ApplyPosition then
            interruptModule:ApplyPosition()
        end
        if interruptModule.EvaluateVisibility then
            interruptModule:EvaluateVisibility("slash-global-lock-toggle")
        end
    end

    if self.UpdateDockMovableState then
        self:UpdateDockMovableState()
    else
        if self.ApplyDockPosition then
            self:ApplyDockPosition()
        end
        if self.UpdateDockVisibility then
            self:UpdateDockVisibility(true)
        elseif self.RefreshDockVisibility then
            self:RefreshDockVisibility(true)
        end
    end
    if self.ApplyDockCombatVisibilityDriver then
        self:ApplyDockCombatVisibilityDriver()
    end

    if self.ApplyCombatAlertsSettings then
        self:ApplyCombatAlertsSettings()
    end

    if self.RefreshOptionsPanels then
        self:RefreshOptionsPanels()
    end

    self._deferSharedMarkerTickerRefresh = priorDeferredSharedRefresh and true or nil
    if not priorDeferredSharedRefresh then
        self:UpdateMoveHintTickerState()
    end

    return locked
end

SLASH_PORTALAUTHORITY1 = "/pa"
local function PA_HandlePullSlash(msg)
    local seconds = PortalAuthority:KeystoneUtility_GetPullSeconds(false)
    local raw = trim(msg)
    if raw ~= "" then
        local maybe = tonumber(raw)
        if maybe then
            seconds = math.floor(PA_Clamp(maybe, seconds, 1, 60))
        end
    end
    PortalAuthority:KeystoneUtility_StartPull(seconds)
end

SlashCmdList.PORTALAUTHORITY = function(msg)
    local command = trim(msg):lower()
    local pullArg = command:match("^pull%s*(.*)$")
    if pullArg ~= nil then
        PA_HandlePullSlash(pullArg)
        return
    end

    local diagDumpArg = command:match("^diagdump%s*(.*)$")
    if diagDumpArg ~= nil then
        PortalAuthority:StartDiagDump(trim(diagDumpArg))
        return
    end

    local devSettingsArg = command:match("^devsettings%s*(.*)$")
    if devSettingsArg ~= nil then
        if not (PortalAuthority.IsSettingsWindowDevGateEnabled and PortalAuthority:IsSettingsWindowDevGateEnabled()) then
            PA_PrintPortalAuthorityMessage("Settings window dev commands are unavailable in this build.")
            return
        end

        devSettingsArg = trim(devSettingsArg)
        if devSettingsArg == "" then
            local ok = PortalAuthority.OpenSettingsWindow and PortalAuthority:OpenSettingsWindow(nil, { source = "slash-devsettings" }) or false
            if not ok then
                local runtime = PortalAuthority._settingsWindowRuntime
                PA_PrintPortalAuthorityMessage((runtime and runtime.lastError) or "Settings window is unavailable.")
            end
            return
        end

        local sectionKey = PortalAuthority.NormalizeSettingsWindowSectionKey and PortalAuthority:NormalizeSettingsWindowSectionKey(devSettingsArg) or nil
        if not sectionKey then
            PA_PrintPortalAuthorityMessage("usage: /pa devsettings [root|home|announcements|dock|timers|interrupt|combat|keystone|profiles]")
            return
        end

        local ok = PortalAuthority.OpenSettingsWindowToSection and PortalAuthority:OpenSettingsWindowToSection(sectionKey) or false
        if not ok then
            local runtime = PortalAuthority._settingsWindowRuntime
            PA_PrintPortalAuthorityMessage((runtime and runtime.lastError) or "Settings window is unavailable.")
        end
        return
    end

    local perfArg = command:match("^perf%s*(.*)$")
    if perfArg ~= nil then
        perfArg = trim(perfArg)
        if perfArg == "on" then
            PortalAuthority._perf = PortalAuthority._perf or {}
            PortalAuthority._perf.enabled = true
            PortalAuthority:PerfReset()
            print("|cffffd100Portal Authority Perf:|r enabled and reset.")
            return
        end
        if perfArg == "off" then
            PortalAuthority._perf = PortalAuthority._perf or {}
            PortalAuthority._perf.enabled = false
            print("|cffffd100Portal Authority Perf:|r disabled.")
            return
        end
        if perfArg == "reset" then
            PortalAuthority:PerfReset()
            print("|cffffd100Portal Authority Perf:|r stats reset.")
            return
        end
        if perfArg == "dump" or perfArg == "" then
            PortalAuthority:PerfDump()
            return
        end

        print("|cffffd100Portal Authority Perf:|r usage: /pa perf on|off|dump|reset")
        return
    end

    local summonDebugArg = command:match("^summondebug%s*(.*)$")
    if summonDebugArg ~= nil then
        summonDebugArg = trim(summonDebugArg)
        if summonDebugArg == "" or summonDebugArg == "on" then
            PortalAuthority.summonDebugEnabled = true
            print("|cffffd100Portal Authority:|r Summon debug enabled.")
            return
        end
        if summonDebugArg == "off" then
            PortalAuthority.summonDebugEnabled = false
            print("|cffffd100Portal Authority:|r Summon debug disabled.")
            return
        end
        print("|cffffd100Portal Authority:|r usage: /pa summondebug on|off")
        return
    end

    local dockDiagArg = command:match("^dockdiag%s*(.*)$")
    if dockDiagArg ~= nil then
        dockDiagArg = trim(dockDiagArg)
        if dockDiagArg == "" or dockDiagArg == "status" then
            if PortalAuthority.GetDockDiagStatusLines then
                for _, line in ipairs(PortalAuthority:GetDockDiagStatusLines() or {}) do
                    print(line)
                end
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "reset" then
            if PortalAuthority.ResetDockDiagOverrides then
                PortalAuthority:ResetDockDiagOverrides()
                print("|cffffd100Portal Authority:|r Dock diagnostics reset.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "labels off" then
            if PortalAuthority.SetDockDiagLabelMode then
                PortalAuthority:SetDockDiagLabelMode("OFF")
                print("|cffffd100Portal Authority:|r DockDiag labels override set to OFF.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "labels on" then
            if PortalAuthority.SetDockDiagLabelMode then
                PortalAuthority:SetDockDiagLabelMode("OUTSIDE")
                print("|cffffd100Portal Authority:|r DockDiag labels override set to OUTSIDE.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "labelrender normal" then
            if PortalAuthority.SetDockDiagLabelRenderMode then
                PortalAuthority:SetDockDiagLabelRenderMode("NORMAL")
                print("|cffffd100Portal Authority:|r DockDiag labelrender override set to NORMAL.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "labelrender blank" then
            if PortalAuthority.SetDockDiagLabelRenderMode then
                PortalAuthority:SetDockDiagLabelRenderMode("BLANK")
                print("|cffffd100Portal Authority:|r DockDiag labelrender override set to BLANK.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "labelrender plain" then
            if PortalAuthority.SetDockDiagLabelRenderMode then
                PortalAuthority:SetDockDiagLabelRenderMode("PLAIN")
                print("|cffffd100Portal Authority:|r DockDiag labelrender override set to PLAIN.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "visibility normal" then
            if PortalAuthority.SetDockDiagVisibilityMode then
                PortalAuthority:SetDockDiagVisibilityMode("NORMAL")
                print("|cffffd100Portal Authority:|r DockDiag visibility override set to NORMAL.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "visibility hide" then
            if PortalAuthority.SetDockDiagVisibilityMode then
                PortalAuthority:SetDockDiagVisibilityMode("HIDE")
                print("|cffffd100Portal Authority:|r DockDiag visibility override set to HIDE.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "sort type" then
            if PortalAuthority.SetDockDiagSortMode then
                PortalAuthority:SetDockDiagSortMode("TYPE_ID")
                print("|cffffd100Portal Authority:|r DockDiag sort override set to TYPE_ID.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "sort cooldown" then
            if PortalAuthority.SetDockDiagSortMode then
                PortalAuthority:SetDockDiagSortMode("COOLDOWN")
                print("|cffffd100Portal Authority:|r DockDiag sort override set to COOLDOWN.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end
        if dockDiagArg == "sort restore" then
            if PortalAuthority.SetDockDiagSortMode then
                PortalAuthority:SetDockDiagSortMode(nil)
                print("|cffffd100Portal Authority:|r DockDiag sort override cleared.")
            else
                print("|cffffd100Portal Authority:|r Dock diagnostics are unavailable.")
            end
            return
        end

        print("|cffffd100Portal Authority:|r usage: /pa dockdiag status|labels off|labels on|labelrender normal|labelrender blank|labelrender plain|visibility normal|visibility hide|sort type|sort cooldown|sort restore|reset")
        return
    end

    local cpuDiagArg = command:match("^cpudiag%s*(.*)$")
    if cpuDiagArg ~= nil then
        cpuDiagArg = trim(cpuDiagArg)
        if cpuDiagArg == "" or cpuDiagArg == "status" then
            if PortalAuthority.GetCpuDiagStatusLines then
                for _, line in ipairs(PortalAuthority:GetCpuDiagStatusLines() or {}) do
                    print(line)
                end
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end
        if cpuDiagArg == "reset" then
            if PA_IsStaticBaselineGateEnabled() then
                print("|cffffd100Portal Authority:|r CpuDiag witness is disabled in this build.")
                return
            end
            if PortalAuthority.ResetCpuDiag then
                PortalAuthority:ResetCpuDiag()
                print("|cffffd100Portal Authority:|r CPU diagnostics reset.")
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end
        if cpuDiagArg == "mark good" then
            if PA_IsStaticBaselineGateEnabled() then
                print("|cffffd100Portal Authority:|r CpuDiag witness is disabled in this build.")
                return
            end
            if PortalAuthority.CpuDiagAppendIdleWitnessEntry then
                PortalAuthority:CpuDiagScheduleIdleWitnessStart()
                if PortalAuthority:CpuDiagAppendIdleWitnessEntry({ "user_good" }, "good") then
                    print("|cffffd100Portal Authority:|r CpuDiag witness marked GOOD.")
                else
                    print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
                end
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end
        if cpuDiagArg == "mark bad" then
            if PA_IsStaticBaselineGateEnabled() then
                print("|cffffd100Portal Authority:|r CpuDiag witness is disabled in this build.")
                return
            end
            if PortalAuthority.CpuDiagAppendIdleWitnessEntry then
                PortalAuthority:CpuDiagScheduleIdleWitnessStart()
                if PortalAuthority:CpuDiagAppendIdleWitnessEntry({ "user_bad" }, "bad") then
                    print("|cffffd100Portal Authority:|r CpuDiag witness marked BAD.")
                else
                    print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
                end
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end
        if cpuDiagArg == "timers visibility normal" then
            if PortalAuthority.SetCpuDiagVisibilityMode and PortalAuthority:SetCpuDiagVisibilityMode("timers", "NORMAL") then
                print("|cffffd100Portal Authority:|r CpuDiag Timers visibility override set to NORMAL.")
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end
        if cpuDiagArg == "timers visibility hide" then
            if PortalAuthority.SetCpuDiagVisibilityMode and PortalAuthority:SetCpuDiagVisibilityMode("timers", "HIDE") then
                print("|cffffd100Portal Authority:|r CpuDiag Timers visibility override set to HIDE.")
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end
        if cpuDiagArg == "interrupt visibility normal" then
            if PortalAuthority.SetCpuDiagVisibilityMode and PortalAuthority:SetCpuDiagVisibilityMode("interrupt", "NORMAL") then
                print("|cffffd100Portal Authority:|r CpuDiag Interrupt visibility override set to NORMAL.")
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end
        if cpuDiagArg == "interrupt visibility hide" then
            if PortalAuthority.SetCpuDiagVisibilityMode and PortalAuthority:SetCpuDiagVisibilityMode("interrupt", "HIDE") then
                print("|cffffd100Portal Authority:|r CpuDiag Interrupt visibility override set to HIDE.")
            else
                print("|cffffd100Portal Authority:|r CPU diagnostics are unavailable.")
            end
            return
        end

        print("|cffffd100Portal Authority:|r usage: /pa cpudiag status|reset|mark good|mark bad|timers visibility normal|timers visibility hide|interrupt visibility normal|interrupt visibility hide")
        return
    end

    local onboardingD1Arg = command:match("^dev%s+onboarding%-d1%s*(.*)$")
    if onboardingD1Arg ~= nil then
        if not PA_IsOnboardingD1DevGateEnabled() then
            print("|cffffd100Portal Authority:|r Onboarding D1 dev commands are unavailable in this build.")
            return
        end

        onboardingD1Arg = trim(onboardingD1Arg)
        if onboardingD1Arg == "" or onboardingD1Arg == "help" then
            print("|cffffd100Portal Authority:|r usage: /pa dev onboarding-d1 first-install|qualifying-upgrade|normalize-active|clear-reset-state")
            return
        end

        if not PortalAuthority.Profiles_RunOnboardingD1Exercise then
            print("|cffffd100Portal Authority:|r Onboarding D1 exercise path is unavailable.")
            return
        end

        local ok, response, shouldReload = PortalAuthority:Profiles_RunOnboardingD1Exercise(onboardingD1Arg)
        print("|cffffd100Portal Authority:|r " .. tostring(response or (ok and "Completed." or "Failed.")))
        if ok and shouldReload then
            ReloadUI()
        end
        return
    end

    local onboardingD3Arg = command:match("^dev%s+onboarding%-d3%s*(.*)$")
    if onboardingD3Arg ~= nil then
        if not PA_IsOnboardingD3DevGateEnabled() then
            print("|cffffd100Portal Authority:|r Onboarding D3 dev commands are unavailable in this build.")
            return
        end
        PortalAuthority:HandleOnboardingD3Slash(onboardingD3Arg)
        return
    end

    local onboardingD4Arg = command:match("^dev%s+onboarding%-d4%s*(.*)$")
    if onboardingD4Arg ~= nil then
        if not PA_IsOnboardingD4DevGateEnabled() then
            print("|cffffd100Portal Authority:|r Onboarding D4 dev commands are unavailable in this build.")
            return
        end
        PortalAuthority:HandleOnboardingD4Slash(onboardingD4Arg)
        return
    end

    local s8DevArg = command:match("^dev%s+s8%s*(.*)$")
    if s8DevArg ~= nil then
        if not (PortalAuthority.IsSettingsWindowDevGateEnabled and PortalAuthority:IsSettingsWindowDevGateEnabled()) then
            print("|cffffd100Portal Authority:|r S8 announcement dev commands are unavailable in this build.")
            return
        end
        PortalAuthority:HandleS8AnnouncementSlash(s8DevArg)
        return
    end

    if command == "onboarding" then
        if not PA_IsOnboardingD3Enabled() then
            print("|cffffd100Portal Authority:|r Premium onboarding is unavailable in this build.")
            return
        end
        local ok, response = PortalAuthority:StartExplicitPremiumOnboarding("slash-onboarding")
        PA_PrintPortalAuthorityMessage(response or (ok and "Premium onboarding opened." or "Premium onboarding failed."))
        return
    end

    if command == "updates" then
        local ok, err = PortalAuthority:HandleSlashUpdatesEntry()
        if not ok and err then
            print("|cffE88BC7Portal Authority:|r " .. tostring(err))
        end
        return
    end

    if command == "lock" then
        PortalAuthority:SetGlobalLockState(true)
        print("|cffE88BC7Portal Authority:|r Locked Mythic+ Dock, Timers, Interrupt Tracker, and On-screen Alerts.")
        return
    end

    if command == "unlock" then
        PortalAuthority:SetGlobalLockState(false)
        print("|cffE88BC7Portal Authority:|r Unlocked Mythic+ Dock, Timers, Interrupt Tracker, and On-screen Alerts.")
        return
    end

    if command == "who" then
        local modulesApi = PortalAuthority.Modules
        local interruptModule = modulesApi and modulesApi.registry and modulesApi.registry.interruptTracker or nil
        if not interruptModule or not interruptModule.GetWhoReportLines then
            print("|cffE88BC7Portal Authority:|r Interrupt Tracker is unavailable.")
            return
        end
        if interruptModule.Initialize then
            interruptModule:Initialize()
        end
        local lines, message = interruptModule:GetWhoReportLines()
        if message then
            print((tostring(message or "")):gsub("^Portal Authority:", "|cffE88BC7Portal Authority:|r", 1))
            return
        end
        for _, line in ipairs(lines or {}) do
            print("|cffE88BC7Portal Authority:|r " .. tostring(line))
        end
        return
    end

    if command == "dock" then
        PortalAuthorityDB.dockEnabled = not PortalAuthorityDB.dockEnabled
        if PortalAuthority.UpdateDockVisibility then
            PortalAuthority:UpdateDockVisibility(true)
        elseif PortalAuthority.RefreshDockVisibility then
            PortalAuthority:RefreshDockVisibility(true)
        end
        if PortalAuthority.RefreshOptionsPanels then
            PortalAuthority:RefreshOptionsPanels()
        end
        print(string.format("|cffE88BC7Portal Authority:|r Mythic+ dock %s.", PortalAuthorityDB.dockEnabled and "enabled" or "disabled"))
        return
    end

    if command == "debugdock" then
        if PortalAuthority.DebugDockBindingState then
            PortalAuthority:DebugDockBindingState()
        else
            print("|cffE88BC7Portal Authority:|r Dock debug is unavailable.")
        end
        return
    end

    local ok, err = PortalAuthority:HandleSlashRootEntry()
    if ok == false and err then
        PA_PrintPortalAuthorityMessage(err)
    end
end

if SlashCmdList.PULL == nil then
    SLASH_PORTALAUTHORITYPULL1 = "/pull"
    SlashCmdList.PORTALAUTHORITYPULL = function(msg)
        PA_HandlePullSlash(msg)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("CHALLENGE_MODE_START")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_BN_WHISPER")
frame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
frame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
frame:RegisterEvent("UNIT_DIED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

local function PA_PerfCoreEventScope(event)
    if event == "CHAT_MSG_WHISPER"
        or event == "CHAT_MSG_BN_WHISPER"
        or event == "CHAT_MSG_INSTANCE_CHAT"
        or event == "CHAT_MSG_INSTANCE_CHAT_LEADER"
        or event == "CHAT_MSG_RAID"
        or event == "CHAT_MSG_RAID_LEADER"
        or event == "CHAT_MSG_PARTY"
        or event == "CHAT_MSG_PARTY_LEADER"
    then
        return "core_event_chat"
    end
    if event == "GROUP_ROSTER_UPDATE" then
        return "core_event_group_roster_update"
    end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        return "core_event_unit_spellcast"
    end
    return "core_event_other"
end

local function PA_CpuDiagCoreTriggerKey(event)
    if event == "GROUP_ROSTER_UPDATE" then
        return "group_roster"
    end
    if event == "PLAYER_REGEN_DISABLED" then
        return "combat_enter"
    end
    if event == "PLAYER_REGEN_ENABLED" then
        return "combat_leave"
    end
    if event == "CHALLENGE_MODE_START" then
        return "challenge_start"
    end
    return nil
end

frame:SetScript("OnEvent", function(_, event, ...)
    if PortalAuthority.summonDebugEnabled
        and (
            event == "CHAT_MSG_WHISPER"
            or event == "CHAT_MSG_BN_WHISPER"
            or event == "CHAT_MSG_INSTANCE_CHAT"
            or event == "CHAT_MSG_INSTANCE_CHAT_LEADER"
            or event == "CHAT_MSG_RAID"
            or event == "CHAT_MSG_RAID_LEADER"
            or event == "CHAT_MSG_PARTY"
            or event == "CHAT_MSG_PARTY_LEADER"
        )
    then
        print("|cffffd100Portal Authority SummonDebug:|r raw event=" .. tostring(event))
    end

    PortalAuthority:CpuDiagRecordDispatcherEvent("core", event)
    local triggerKey = PA_CpuDiagCoreTriggerKey(event)
    if triggerKey then
        PortalAuthority:CpuDiagRecordTrigger(triggerKey)
    end
    local dispatchStart, dispatchState = PortalAuthority:PerfBegin("core_event_dispatch")
    local eventScope = PA_PerfCoreEventScope(event)
    PortalAuthority:CpuDiagRecordCoreEvent(eventScope)
    local eventStart, eventState = PortalAuthority:PerfBegin(eventScope, dispatchState)
    local function finish(...)
        PortalAuthority:PerfEnd(eventScope, eventStart, eventState)
        PortalAuthority:PerfEnd("core_event_dispatch", dispatchStart, dispatchState)
        return ...
    end

    if event == "ADDON_LOADED" then
        local loadedAddonName = ...
        if loadedAddonName ~= ADDON_NAME then
            return finish()
        end

        if PortalAuthority.InitializeProfiles then
            PortalAuthority:InitializeProfiles()
        end
        PortalAuthority:EnsureDB()
        if PortalAuthority.ApplyPublicOnboardingD5b1FreshInstallState then
            PortalAuthority:ApplyPublicOnboardingD5b1FreshInstallState()
        end
        if PortalAuthority.ApplyPublicOnboardingD5b2QualifyingUpgradeState then
            PortalAuthority:ApplyPublicOnboardingD5b2QualifyingUpgradeState()
        end
        if not PA_IsUiSurfaceGateEnabled() then
            PortalAuthority:InitializeKeystoneUtility()
        end
        if not PA_IsStaticBaselineGateEnabled() then
            PortalAuthority:InitializeKeystoneTooltip()
        end
        if not PA_IsUiSurfaceGateEnabled() then
            PortalAuthority:InitializeDeathAlerts()
        end
        if not PA_IsUiSurfaceGateEnabled() and PortalAuthority.InitializeDock then
            PortalAuthority:InitializeDock()
        end
        return finish()
    end

    if event == "PLAYER_LOGOUT" then
        PortalAuthority._qualifyingUpgradeAnnouncementTeardownSuppressed = true
        if PortalAuthority.CpuDiagStopIdleWitnessTicker then
            PortalAuthority:CpuDiagStopIdleWitnessTicker()
        end
        if PortalAuthority.Profiles_HandlePlayerLogout then
            PortalAuthority:Profiles_HandlePlayerLogout()
        end
        return finish()
    end

    if event == "PLAYER_LOGIN" then
        PortalAuthority._qualifyingUpgradeAnnouncementTeardownSuppressed = nil
        if not PA_IsSettingsBaselineGateEnabled() then
            PortalAuthority:CpuDiagEnsureSettingsHooks()
        end
        PortalAuthority:ShowLoginMessage()
        PortalAuthority:ShowDockV200MigrationNotice()
        if PA_IsOnboardingD3Enabled() then
            if PA_IsOnboardingD4Enabled() and PortalAuthority.Profiles_GetOnboardingD4Session then
                local session = PortalAuthority:Profiles_GetOnboardingD4Session()
                if type(session) == "table" then
                    PortalAuthority:ResolveAbandonedOnboardingD4Session("reload-recovery")
                end
            end
            if PortalAuthority:IsPremiumWelcomePending() then
                PortalAuthority:ScheduleAutomaticPremiumWelcome("login-auto")
                PortalAuthority._qualifyingUpgradeAnnouncementReadyAt = 0
            elseif PortalAuthority:IsQualifyingUpgradeWelcomePending() then
                PortalAuthority._premiumWelcomeReadyAt = 0
                PortalAuthority:ScheduleAutomaticQualifyingUpgradeAnnouncement("login-auto")
            else
                PortalAuthority._premiumWelcomeReadyAt = 0
                PortalAuthority._qualifyingUpgradeAnnouncementReadyAt = 0
                PortalAuthority:EnsurePremiumWelcomeFrame()
            end
        else
            PortalAuthority._premiumWelcomeReadyAt = 0
            PortalAuthority._qualifyingUpgradeAnnouncementReadyAt = 0
            if PortalAuthority.Profiles_GetOnboardingD4Session and PortalAuthority.Profiles_ClearOnboardingD4Session then
                local staleSession = PortalAuthority:Profiles_GetOnboardingD4Session()
                if type(staleSession) == "table" then
                    PortalAuthority:Profiles_ClearOnboardingD4Session()
                end
            end
        end
        if not PA_IsUiSurfaceGateEnabled() and not PA_IsOnboardingD3Enabled() then
            PortalAuthority:UpdateMoveHintTickerState()
        end
        if not PA_IsStaticBaselineGateEnabled() then
            PortalAuthority:CpuDiagEnsureIdleWitnessSession()
            PortalAuthority:CpuDiagScheduleIdleWitnessStart()
        end
        return finish()
    end

    if event == "CHALLENGE_MODE_START" then
        PA_MPLUS_NOTICE_SHOWN = false
        PA_MaybeShowMPlusNotice()
        return finish()
    end

    if event == "CHAT_MSG_WHISPER"
        or event == "CHAT_MSG_BN_WHISPER"
        or event == "CHAT_MSG_INSTANCE_CHAT"
        or event == "CHAT_MSG_INSTANCE_CHAT_LEADER"
        or event == "CHAT_MSG_RAID"
        or event == "CHAT_MSG_RAID_LEADER"
        or event == "CHAT_MSG_PARTY"
        or event == "CHAT_MSG_PARTY_LEADER"
    then
        local message, sender, _, _, _, _, _, _, _, _, lineID, senderGUID, bnSenderID = ...
        if PortalAuthority.summonDebugEnabled then
            print("|cffffd100Portal Authority SummonDebug:|r dispatch event=" .. tostring(event))
        end
        local okSummon, errSummon = pcall(PortalAuthority.HandleSummonChatEvent, PortalAuthority, event, message, sender, bnSenderID, senderGUID, lineID)
        if PortalAuthority.summonDebugEnabled and not okSummon then
            print("|cffffd100Portal Authority SummonDebug:|r summon error=" .. tostring(errSummon))
        end
        local okStone, errStone = pcall(PortalAuthority.HandleSummonStoneChatEvent, PortalAuthority, event, message, sender, bnSenderID, senderGUID, lineID)
        if PortalAuthority.summonDebugEnabled and not okStone then
            print("|cffffd100Portal Authority SummonDebug:|r stone error=" .. tostring(errStone))
        end
        return finish()
    end

    if event == "GROUP_ROSTER_UPDATE" then
        if PortalAuthority.DeathAlerts and PortalAuthority.DeathAlerts.wipeTracker then
            PortalAuthority.DeathAlerts.wipeTracker = {}
        end
        return finish()
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if PortalAuthority.ApplyCombatAlertsSettings then
            PortalAuthority:ApplyCombatAlertsSettings()
        end
        return finish()
    end

    if event == "PLAYER_DEAD" then
        if not PortalAuthorityDB or not PortalAuthority or not PortalAuthority.DeathAlerts_HandlePlayerDeath then
            return finish()
        end
        PortalAuthority:DeathAlerts_HandlePlayerDeath()
        return finish()
    end

    if event == "UNIT_DIED" then
        if not PortalAuthorityDB or not PortalAuthority or not PortalAuthority.DeathAlerts_HandleDeath then
            return finish()
        end
        local deadGUID, deadName = ...
        PortalAuthority:DeathAlerts_HandleDeath(deadGUID, deadName)
        return finish()
    end

    local unitTarget, castGUID, spellID = ...
    if unitTarget ~= "player" then
        return finish()
    end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        PortalAuthority:TryAnnounce(spellID, castGUID)
    end
    return finish()
end)
