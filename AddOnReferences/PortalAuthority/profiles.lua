-- Profiles v1 storage, bootstrap, and profile operations.

PortalAuthority = PortalAuthority or {}

local PA_PROFILES = {
    DEFAULT_ID = "default",
    DEFAULT_NAME = "Default",
    SCHEMA_VERSION = 2,
    MAX_RELOAD_SAFE_NAME_LEN = 80,
    PAYLOAD_STRIP_KEYS = {
        dockEnableDefaultsVersion = true,
        dockEnableDefaultsMigrated = true,
        dockV200NoticePending = true,
        settingsResetEpochApplied = true,
        onboardingExperienceSeen = true,
        firstRunLandingConsumed = true,
        onboardingD4Session = true,
        _migrations = true,
    },
}

local PA_ONBOARDING_RESET_EPOCH = "PA_2_0_0_BASELINE"
local PA_ONBOARDING_EXPERIENCE_VERSION = "PA_2_0_0_PREMIUM_V1"
local PA_ONBOARDING_BACKUP_BASE_NAME = "Pre-2.0 Backup"

local function PA_ProfileTrim(text)
    if type(text) ~= "string" then
        return ""
    end
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function PA_ProfileSafeTable(value)
    if type(value) == "table" then
        return value
    end
    return nil
end

local function PA_ProfileShallowCount(value)
    if type(value) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(value) do
        count = count + 1
        if count > 0 then
            return count
        end
    end
    return count
end

local function PA_ProfileDeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do
        copy[PA_ProfileDeepCopy(key, seen)] = PA_ProfileDeepCopy(entry, seen)
    end
    return copy
end

local function PA_ProfileClearTable(target)
    if type(target) ~= "table" then
        return
    end
    for key in pairs(target) do
        target[key] = nil
    end
end

local function PA_ProfileReplaceTable(target, source)
    if type(target) ~= "table" then
        return nil
    end
    PA_ProfileClearTable(target)
    if type(source) ~= "table" then
        return target
    end
    local clone = PA_ProfileDeepCopy(source)
    for key, entry in pairs(clone) do
        target[key] = entry
    end
    return target
end

local function PA_ProfileStripOperationalKeys(payload)
    if type(payload) ~= "table" then
        return payload
    end
    for key in pairs(PA_PROFILES.PAYLOAD_STRIP_KEYS) do
        payload[key] = nil
    end
    return payload
end

local function PA_ProfileSnapshotPayload(source)
    return PA_ProfileStripOperationalKeys(PA_ProfileDeepCopy(type(source) == "table" and source or {}))
end

local function PA_ProfileFreshDefaultsSnapshot()
    return PA_ProfileSnapshotPayload((PortalAuthority and PortalAuthority.defaults) or {})
end

local function PA_ProfilePeekRoot()
    return PA_ProfileSafeTable(PortalAuthorityProfilesDB)
end

local function PA_ProfilePeekGlobalMeta()
    local root = PA_ProfilePeekRoot()
    return root and PA_ProfileSafeTable(root.globalMeta) or nil
end

local function PA_ProfilePeekPayloadMeta(payload)
    return type(payload) == "table" and PA_ProfileSafeTable(payload._paProfileMeta) or nil
end

local function PA_ProfileEnsurePayloadMeta(payload)
    if type(payload) ~= "table" then
        return nil
    end
    local meta = PA_ProfileSafeTable(payload._paProfileMeta)
    if not meta then
        meta = {}
        payload._paProfileMeta = meta
    end
    return meta
end

local function PA_ProfileGetPayloadResetEpoch(payload)
    local meta = PA_ProfilePeekPayloadMeta(payload)
    local value = meta and meta.resetEpochApplied or nil
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function PA_ProfilePayloadIsHandled(payload)
    return PA_ProfileGetPayloadResetEpoch(payload) == PA_ONBOARDING_RESET_EPOCH
end

local function PA_ProfileStampPayloadResetEpoch(payload, epoch)
    local meta = PA_ProfileEnsurePayloadMeta(payload)
    if meta then
        meta.resetEpochApplied = epoch
    end
    return payload
end

local function PA_ProfilePreservePayloadMeta(candidate, sourcePayload)
    if type(candidate) ~= "table" or type(sourcePayload) ~= "table" then
        return candidate
    end
    local sourceEpoch = PA_ProfileGetPayloadResetEpoch(sourcePayload)
    if sourceEpoch ~= nil and PA_ProfileGetPayloadResetEpoch(candidate) == nil then
        PA_ProfileStampPayloadResetEpoch(candidate, sourceEpoch)
    end
    return candidate
end

local function PA_ProfilePreserveIntroState(candidate, sourcePayload)
    if type(candidate) ~= "table" or type(sourcePayload) ~= "table" then
        return candidate
    end

    candidate.onboardingExperienceSeen = sourcePayload.onboardingExperienceSeen
    candidate.firstRunLandingConsumed = sourcePayload.firstRunLandingConsumed
    return candidate
end

local function PA_ProfileClonePayloadPreservingMeta(sourcePayload)
    local candidate = PA_ProfileSnapshotPayload(sourcePayload)
    candidate = PA_ProfilePreservePayloadMeta(candidate, sourcePayload)
    candidate = PA_ProfilePreserveIntroState(candidate, sourcePayload)
    return candidate
end

local function PA_ProfileEnsureTable(parent, key)
    if type(parent) ~= "table" then
        return nil
    end
    local value = PA_ProfileSafeTable(parent[key])
    if not value then
        value = {}
        parent[key] = value
    end
    return value
end

local function PA_ProfileNormalizePrimaryModuleToggleDefaults(payload)
    if type(payload) ~= "table" then
        return false
    end

    local didChange = false

    local function normalizeBooleanDefault(parent, key, defaultValue)
        if type(parent) ~= "table" then
            return
        end
        local current = parent[key]
        if current == nil then
            parent[key] = defaultValue and true or false
            didChange = true
            return
        end
        local normalized = current and true or false
        if current ~= normalized then
            parent[key] = normalized
            didChange = true
        end
    end

    normalizeBooleanDefault(payload, "dockEnabled", true)
    normalizeBooleanDefault(payload, "combatAlertsEnabled", true)

    local modules = PA_ProfileEnsureTable(payload, "modules")
    local timers = PA_ProfileEnsureTable(modules, "timers")
    local interrupt = PA_ProfileEnsureTable(modules, "interruptTracker")
    normalizeBooleanDefault(timers, "enabled", true)
    normalizeBooleanDefault(interrupt, "enabled", true)

    return didChange
end

local function PA_ProfileResolveSpellLabel(spellID, fallback)
    local authority = PortalAuthority
    local entry = authority and authority.SpellMap and authority.SpellMap[spellID] or nil
    if entry and type(entry.dest) == "string" and entry.dest ~= "" then
        return entry.dest
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, spellName = pcall(C_Spell.GetSpellName, spellID)
        if ok and type(spellName) == "string" and spellName ~= "" then
            return spellName
        end
    end
    return tostring(fallback or "")
end

local function PA_ProfileBuildCanonicalDockSlots()
    local slots = {}
    local authority = PortalAuthority
    local dungeons = {}
    if authority and authority.GetDefaultMPlusDockPresetDungeons then
        local ok, resolved = pcall(authority.GetDefaultMPlusDockPresetDungeons, authority)
        if ok and type(resolved) == "table" then
            dungeons = resolved
        end
    end

    for i = 1, 8 do
        local dungeon = dungeons[i]
        local spellID = dungeon and math.floor(tonumber(dungeon.spellID) or 0) or 0
        if spellID > 0 then
            slots[i] = {
                enabled = true,
                selection = tostring(spellID),
                spellID = spellID,
                name = PA_ProfileResolveSpellLabel(spellID, dungeon and dungeon.dest or ""),
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

    local extras = {
        { spellID = 6948, fallback = "Hearthstone" },
        { spellID = 3563, fallback = "Undercity" },
    }
    for offset, extra in ipairs(extras) do
        local index = 8 + offset
        local spellID = math.floor(tonumber(extra.spellID) or 0)
        slots[index] = {
            enabled = false,
            selection = spellID > 0 and tostring(spellID) or "CUSTOM",
            spellID = spellID,
            name = spellID > 0 and PA_ProfileResolveSpellLabel(spellID, extra.fallback) or "",
        }
    end

    return slots
end

local function PA_ProfileBuildCanonicalBaselineSnapshot()
    local payload = PA_ProfileSnapshotPayload((PortalAuthority and PortalAuthority.defaults) or {})
    payload = PA_ProfileSafeTable(payload) or {}

    payload.mplusEnabled = true
    payload.keystoneHelperEnabled = true
    payload.keystoneAutoSlotEnabled = true
    payload.keystoneAutoStartEnabled = true
    payload.releaseGateEnabled = false

    payload.dockEnabled = true
    payload.dockLocked = true
    payload.dockX = 0
    payload.dockY = -170
    payload.dockSimpleLayoutMode = "GRID"
    payload.dockSimpleLayoutModePersist = "GRID"
    payload.dockWrapAfter = 4
    payload.dockIconsPerLine = 4
    payload.dockIconSize = 64
    payload.dockIconSizeUI = 64
    payload.dockLabelMode = "OUTSIDE"
    payload.dockLabelModePersist = "OUTSIDE"
    payload.dockLabelSide = "BOTTOM"
    payload.dockLabelSidePersist = "BOTTOM"
    payload.dockLabelSideOutsidePersist = "BOTTOM"
    payload.dockFontPath = ""
    payload.dockFontSize = 12
    payload.dockFontSizeUI = 12
    payload.dockTextOutline = "OUTLINE"
    payload.dockHoverGlow = true
    payload.dockHideInCombat = true
    payload.dockHideInMajorCity = false
    payload.dockHideInDungeon = false
    payload.dockGizmoMode = false
    payload.dockLoadoutPreset = "SEASON_01"
    payload.dockSlots = PA_ProfileBuildCanonicalDockSlots()

    payload.deathAlertX = 0
    payload.deathAlertY = 150
    payload.deathAlertLocked = true
    payload.deathAlertTankEnabled = true
    payload.deathAlertTankOnScreen = true
    payload.deathAlertHealerEnabled = false
    payload.deathAlertHealerOnScreen = false
    payload.deathAlertDpsEnabled = false
    payload.deathAlertDpsOnScreen = false
    payload.deathAlertSelfEnabled = false
    payload.deathAlertSelfOnScreen = false
    payload.deathAlertShowRoleIcon = true
    payload.deathAlertAntiSpamWipeEnabled = true
    payload.deathAlertFontSize = 32

    local modules = PA_ProfileEnsureTable(payload, "modules")
    local timers = PA_ProfileEnsureTable(modules, "timers")
    timers.x = -320
    timers.y = -40
    timers.locked = true
    timers.brezEnabled = true
    timers.lustEnabled = true
    timers.healerEnabled = true
    timers.cooldownSweepEnabled = true
    timers.iconSize = 35
    timers.iconOffsetX = -8
    timers.iconOffsetY = 2
    timers.iconAspect = "1:1"
    timers.iconEdgeStyle = "Sharp (Zoomed)"
    timers.enabled = true

    local interrupt = PA_ProfileEnsureTable(modules, "interruptTracker")
    interrupt.x = 320
    interrupt.y = -40
    interrupt.locked = true
    interrupt.useClassColors = true
    interrupt.showClassIcon = false
    interrupt.showSpellIcon = true
    interrupt.rightDisplay = "timer"
    interrupt.alertSound = ""
    interrupt.enabled = true

    payload.combatAlertsEnabled = true
    PA_ProfileNormalizePrimaryModuleToggleDefaults(payload)
    PA_ProfileStampPayloadResetEpoch(payload, PA_ONBOARDING_RESET_EPOCH)
    return payload
end

local function PA_ProfileBuildActivationCandidate(sourcePayload)
    if PA_ProfilePayloadIsHandled(sourcePayload) then
        local candidate = PA_ProfileClonePayloadPreservingMeta(sourcePayload)
        local didNormalize = PA_ProfileNormalizePrimaryModuleToggleDefaults(candidate)
        return candidate, didNormalize, "handled"
    end
    return PA_ProfileBuildCanonicalBaselineSnapshot(), true, "normalized"
end

local function PA_ProfileNormalizeDestinationForActivation(destination)
    if type(destination) ~= "table" then
        return nil, false, "missing"
    end
    if PA_ProfilePayloadIsHandled(destination) then
        local didNormalize = PA_ProfileNormalizePrimaryModuleToggleDefaults(destination)
        return destination, didNormalize, "handled"
    end
    PA_ProfileReplaceTable(destination, PA_ProfileBuildCanonicalBaselineSnapshot())
    return destination, true, "normalized"
end

local function PA_ProfileNormalizeDisplayName(rawName)
    local trimmed = PA_ProfileTrim(tostring(rawName or ""))
    if trimmed == "" then
        return nil
    end
    if #trimmed > PA_PROFILES.MAX_RELOAD_SAFE_NAME_LEN then
        trimmed = trimmed:sub(1, PA_PROFILES.MAX_RELOAD_SAFE_NAME_LEN)
        trimmed = PA_ProfileTrim(trimmed)
        if trimmed == "" then
            return nil
        end
    end
    return trimmed
end

local function PA_ProfileNameKey(rawName)
    local normalized = PA_ProfileNormalizeDisplayName(rawName)
    if not normalized then
        return nil
    end
    return normalized:lower()
end

local function PA_ProfileGetPlayerIdentity()
    local name = nil
    local realm = nil
    if UnitFullName then
        local ok, fullName, fullRealm = pcall(UnitFullName, "player")
        if ok then
            name = PA_ProfileTrim(fullName)
            realm = PA_ProfileTrim(fullRealm)
        end
    end
    if name == "" then
        local ok, shortName = pcall(UnitName, "player")
        name = PA_ProfileTrim(ok and shortName or nil)
    end
    if realm == "" then
        local ok, homeRealm = pcall(GetRealmName)
        realm = PA_ProfileTrim(ok and homeRealm or nil)
    end
    if name == "" then
        name = "Player"
    end
    if realm == "" then
        realm = "Realm"
    end
    return name, realm
end

local function PA_ProfileMakeCharacterLabel()
    local name, realm = PA_ProfileGetPlayerIdentity()
    return string.format("%s - %s", name, realm)
end

local function PA_ProfileGetProfileRoot()
    PortalAuthorityProfilesDB = PA_ProfileSafeTable(PortalAuthorityProfilesDB) or {}
    local root = PortalAuthorityProfilesDB
    root.sharedProfiles = PA_ProfileSafeTable(root.sharedProfiles) or {}
    root.sharedProfileMeta = PA_ProfileSafeTable(root.sharedProfileMeta) or {}
    root.globalMeta = PA_ProfileSafeTable(root.globalMeta) or {}
    return root
end

local function PA_ProfileGetCharacterStore()
    PortalAuthorityCharacterDB = PA_ProfileSafeTable(PortalAuthorityCharacterDB) or {}
    return PortalAuthorityCharacterDB
end

local function PA_ProfileGetGlobalMeta()
    return PA_ProfileGetProfileRoot().globalMeta
end

local function PA_ProfileGetGlobalResetEpochApplied(root)
    local meta = (root and root.globalMeta) or PA_ProfilePeekGlobalMeta()
    local value = meta and meta.settingsResetEpochApplied or nil
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function PA_ProfileSetGlobalResetEpochApplied(root, epoch)
    root = root or PA_ProfileGetProfileRoot()
    root.globalMeta = PA_ProfileSafeTable(root.globalMeta) or {}
    root.globalMeta.settingsResetEpochApplied = epoch
    return root.globalMeta.settingsResetEpochApplied
end

local function PA_ProfileClearGlobalResetEpochApplied(root)
    root = root or PA_ProfileGetProfileRoot()
    root.globalMeta = PA_ProfileSafeTable(root.globalMeta) or {}
    root.globalMeta.settingsResetEpochApplied = nil
end

local function PA_ProfileGetGlobalVersionField(root, fieldKey)
    local meta = (root and root.globalMeta) or PA_ProfilePeekGlobalMeta()
    local value = meta and meta[fieldKey] or nil
    if type(value) ~= "string" or value == "" then
        return nil
    end
    return value
end

local function PA_ProfileSetGlobalVersionField(root, fieldKey, value)
    root = root or PA_ProfileGetProfileRoot()
    root.globalMeta = PA_ProfileSafeTable(root.globalMeta) or {}

    local normalized = PA_ProfileTrim(tostring(value or ""))
    if normalized == "" then
        root.globalMeta[fieldKey] = nil
        return nil
    end

    root.globalMeta[fieldKey] = normalized
    return root.globalMeta[fieldKey]
end

local function PA_ProfileClearPayloadResetEpoch(payload)
    local meta = PA_ProfilePeekPayloadMeta(payload)
    if meta then
        meta.resetEpochApplied = nil
        if next(meta) == nil then
            payload._paProfileMeta = nil
        end
    end
    return payload
end

local PA_ProfileResolveBoundSource

local function PA_ProfileResolveActivePayload()
    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local activePayload = PA_ProfileResolveBoundSource(root, charStore)
    return activePayload, root, charStore
end

local function PA_ProfileGetActiveIntroField(fieldKey)
    local payload = PA_ProfileResolveActivePayload()
    local value = type(payload) == "table" and payload[fieldKey] or nil
    local runtime = PA_ProfileSafeTable(PortalAuthorityDB)
    if value == nil and type(runtime) == "table" then
        value = runtime[fieldKey]
    end
    return value, payload, runtime
end

local function PA_ProfileSetActiveIntroField(fieldKey, value)
    local payload = PA_ProfileResolveActivePayload()
    PortalAuthorityDB = PA_ProfileSafeTable(PortalAuthorityDB) or {}
    local runtime = PortalAuthorityDB

    if type(payload) == "table" then
        payload[fieldKey] = value
    end
    runtime[fieldKey] = value

    return value, payload, runtime
end

local function PA_ProfileNormalizeOnboardingExperienceSeen(value)
    local text = PA_ProfileTrim(tostring(value or ""))
    if text == "" then
        return nil
    end
    return text
end

local function PA_ProfileNormalizeLandingConsumed(value)
    if value == nil then
        return nil
    end
    return value and true or false
end

local function PA_ProfileEnsureDefaultMeta(root)
    root = root or PA_ProfileGetProfileRoot()
    local meta = PA_ProfileSafeTable(root.sharedProfileMeta[PA_PROFILES.DEFAULT_ID]) or {}
    meta.name = PA_PROFILES.DEFAULT_NAME
    meta.protected = true
    root.sharedProfileMeta[PA_PROFILES.DEFAULT_ID] = meta
    return meta
end

local function PA_ProfileBuildRecoveredName(root, usedKeys)
    root = root or PA_ProfileGetProfileRoot()
    usedKeys = usedKeys or {}
    local ordinal = 1
    while true do
        local label = ordinal == 1 and "Shared Profile" or string.format("Shared Profile %d", ordinal)
        local key = PA_ProfileNameKey(label)
        if key and not usedKeys[key] then
            usedKeys[key] = true
            return label
        end
        ordinal = ordinal + 1
    end
end

local function PA_ProfileEnsureSharedMetaIntegrity(root)
    root = root or PA_ProfileGetProfileRoot()
    local usedKeys = {}
    PA_ProfileEnsureDefaultMeta(root)
    usedKeys[PA_ProfileNameKey(PA_PROFILES.DEFAULT_NAME)] = true

    local profileIDs = {}
    for profileID in pairs(root.sharedProfiles) do
        if profileID ~= PA_PROFILES.DEFAULT_ID then
            profileIDs[#profileIDs + 1] = profileID
        end
    end
    table.sort(profileIDs)

    for _, profileID in ipairs(profileIDs) do
        local meta = PA_ProfileSafeTable(root.sharedProfileMeta[profileID]) or {}
        local normalizedName = PA_ProfileNormalizeDisplayName(meta.name)
        local nameKey = PA_ProfileNameKey(normalizedName)
        if not normalizedName or not nameKey or usedKeys[nameKey] then
            normalizedName = PA_ProfileBuildRecoveredName(root, usedKeys)
            nameKey = PA_ProfileNameKey(normalizedName)
        end
        usedKeys[nameKey] = true
        meta.name = normalizedName
        meta.protected = false
        root.sharedProfileMeta[profileID] = meta
    end

    for profileID in pairs(root.sharedProfileMeta) do
        if profileID ~= PA_PROFILES.DEFAULT_ID and not root.sharedProfiles[profileID] then
            root.sharedProfileMeta[profileID] = nil
        end
    end
end

local function PA_ProfileEnsureCanonicalDefault(root)
    root = root or PA_ProfileGetProfileRoot()
    if type(root.sharedProfiles[PA_PROFILES.DEFAULT_ID]) ~= "table" then
        root.sharedProfiles[PA_PROFILES.DEFAULT_ID] = PA_ProfileBuildCanonicalBaselineSnapshot()
    else
        root.sharedProfiles[PA_PROFILES.DEFAULT_ID] = PA_ProfileClonePayloadPreservingMeta(root.sharedProfiles[PA_PROFILES.DEFAULT_ID])
    end
    PA_ProfileEnsureDefaultMeta(root)
end

local function PA_ProfileBuildBackupDisplayName(root)
    root = root or PA_ProfileGetProfileRoot()
    local baseName = PA_ONBOARDING_BACKUP_BASE_NAME
    local suffix = 1
    while true do
        local candidate = suffix == 1 and baseName or string.format("%s (%d)", baseName, suffix)
        local candidateKey = PA_ProfileNameKey(candidate)
        local inUse = false
        for _, meta in pairs(root.sharedProfileMeta or {}) do
            local metaName = PA_ProfileNormalizeDisplayName(meta and meta.name)
            if metaName and PA_ProfileNameKey(metaName) == candidateKey then
                inUse = true
                break
            end
        end
        if not inUse then
            return candidate
        end
        suffix = suffix + 1
    end
end

local function PA_ProfileLegacyPayloadLooksUsable(payload)
    if type(payload) ~= "table" then
        return false
    end
    if PA_ProfileShallowCount(payload) <= 0 then
        return false
    end
    return true
end

PA_ProfileResolveBoundSource = function(root, charStore)
    root = root or PA_ProfileGetProfileRoot()
    charStore = charStore or PA_ProfileGetCharacterStore()

    local kind = charStore.activeProfileKind
    if kind ~= "character" and kind ~= "shared" then
        kind = "shared"
        charStore.activeProfileKind = kind
    end

    if kind == "character" then
        if type(charStore.characterProfile) ~= "table" then
            charStore.activeProfileKind = "shared"
            charStore.activeProfileKey = PA_PROFILES.DEFAULT_ID
            kind = "shared"
        else
            return charStore.characterProfile, "character", nil
        end
    end

    local activeSharedID = PA_ProfileTrim(tostring(charStore.activeProfileKey or ""))
    if activeSharedID == "" or type(root.sharedProfiles[activeSharedID]) ~= "table" then
        activeSharedID = PA_PROFILES.DEFAULT_ID
        charStore.activeProfileKey = activeSharedID
    end

    return root.sharedProfiles[activeSharedID], "shared", activeSharedID
end

local function PA_ProfileResolveAndNormalizeBoundSource(root, charStore)
    local activePayload, activeKind, activeSharedID = PA_ProfileResolveBoundSource(root, charStore)
    local normalizedPayload, didNormalize, reason = PA_ProfileNormalizeDestinationForActivation(activePayload)
    return normalizedPayload or activePayload, activeKind, activeSharedID, didNormalize, reason
end

local function PA_ProfileResolveDestination(root, charStore, kind, key, createCharacterPayload)
    root = root or PA_ProfileGetProfileRoot()
    charStore = charStore or PA_ProfileGetCharacterStore()
    if kind == "character" then
        if createCharacterPayload and type(charStore.characterProfile) ~= "table" then
            charStore.characterProfile = {}
        end
        return type(charStore.characterProfile) == "table" and charStore.characterProfile or nil
    end

    local resolvedKey = PA_ProfileTrim(tostring(key or charStore.activeProfileKey or PA_PROFILES.DEFAULT_ID))
    if resolvedKey == "" then
        resolvedKey = PA_PROFILES.DEFAULT_ID
    end
    if type(root.sharedProfiles[resolvedKey]) ~= "table" then
        resolvedKey = PA_PROFILES.DEFAULT_ID
    end
    return root.sharedProfiles[resolvedKey], resolvedKey
end

local function PA_ProfileEnsureMetaSchema(root)
    root = root or PA_ProfileGetProfileRoot()
    local meta = root.globalMeta
    if meta.profileSystemInitialized ~= true then
        meta.profileSystemInitialized = true
    end
    meta.profileSystemState = "profiled"
    meta.profileSchemaVersion = PA_PROFILES.SCHEMA_VERSION
    if type(meta.nextSharedProfileOrdinal) ~= "number" or meta.nextSharedProfileOrdinal < 1 then
        meta.nextSharedProfileOrdinal = 1
    end
    meta.nextSharedProfileOrdinal = math.max(1, math.floor(meta.nextSharedProfileOrdinal))
    meta.migrations = PA_ProfileSafeTable(meta.migrations) or {}
end

local function PA_ProfileHasHistory(meta, charStore)
    meta = meta or PA_ProfileGetGlobalMeta()
    charStore = charStore or PA_ProfileGetCharacterStore()
    return meta.profileSystemInitialized == true
        or meta.profileSystemState == "profiled"
        or charStore.profileSystemSeen == true
end

local function PA_ProfileAllocateSharedID(root)
    root = root or PA_ProfileGetProfileRoot()
    local meta = root.globalMeta
    PA_ProfileEnsureMetaSchema(root)
    local ordinal = math.max(1, math.floor(tonumber(meta.nextSharedProfileOrdinal) or 1))
    local profileID = nil
    repeat
        profileID = string.format("shared_%04d", ordinal)
        ordinal = ordinal + 1
    until profileID ~= PA_PROFILES.DEFAULT_ID and type(root.sharedProfiles[profileID]) ~= "table"
    meta.nextSharedProfileOrdinal = ordinal
    return profileID
end

local function PA_ProfileCreateSharedSnapshot(root, displayName, sourcePayload)
    root = root or PA_ProfileGetProfileRoot()
    local normalizedName = PA_ProfileNormalizeDisplayName(displayName)
    if not normalizedName or type(sourcePayload) ~= "table" then
        return nil, "Shared profile backup could not be created."
    end

    local profileID = PA_ProfileAllocateSharedID(root)
    root.sharedProfiles[profileID] = PA_ProfileClonePayloadPreservingMeta(sourcePayload)
    root.sharedProfileMeta[profileID] = {
        name = normalizedName,
        protected = false,
    }
    return profileID, normalizedName
end

local function PA_ProfileTryCreateQualifyingUpgradeBackup(root, sourcePayload)
    root = root or PA_ProfileGetProfileRoot()
    if PA_ProfileGetGlobalResetEpochApplied(root) == PA_ONBOARDING_RESET_EPOCH then
        return false, "already-handled"
    end
    if type(sourcePayload) ~= "table" then
        return false, "Active profile payload is unavailable."
    end

    local displayName = PA_ProfileBuildBackupDisplayName(root)
    local profileID, normalizedName = PA_ProfileCreateSharedSnapshot(root, displayName, sourcePayload)
    if not profileID then
        return false, normalizedName or "Shared profile backup could not be created."
    end
    return true, normalizedName, profileID
end

local function PA_ProfileValidateSourceProfile(root, sourceKind, sourceID)
    root = root or PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    if sourceKind == "character" then
        if type(charStore.characterProfile) ~= "table" then
            return nil, "Character profile is unavailable."
        end
        return charStore.characterProfile, nil, PA_ProfileMakeCharacterLabel()
    end
    local profileID = PA_ProfileTrim(tostring(sourceID or ""))
    if profileID == "" then
        return nil, "Shared profile is unavailable."
    end
    local payload = root.sharedProfiles[profileID]
    if type(payload) ~= "table" then
        return nil, "Shared profile is unavailable."
    end
    local meta = root.sharedProfileMeta[profileID]
    return payload, profileID, PA_ProfileNormalizeDisplayName(meta and meta.name) or PA_PROFILES.DEFAULT_NAME
end

function PortalAuthority:GetProfilesRoot()
    return PA_ProfileGetProfileRoot()
end

function PortalAuthority:GetProfilesCharacterStore()
    return PA_ProfileGetCharacterStore()
end

function PortalAuthority:GetProfilesGlobalMeta()
    return PA_ProfileGetGlobalMeta()
end

function PortalAuthority:GetOperationalMeta()
    local root = PA_ProfileSafeTable(PortalAuthorityProfilesDB)
    if root and type(root.globalMeta) == "table" then
        return root.globalMeta
    end
    PortalAuthorityDB = PA_ProfileSafeTable(PortalAuthorityDB) or {}
    return PortalAuthorityDB
end

function PortalAuthority:GetOperationalMigrations()
    local meta = self:GetOperationalMeta() or {}
    meta.migrations = PA_ProfileSafeTable(meta.migrations) or {}
    return meta.migrations
end

function PortalAuthority:Profiles_GetSettingsResetEpochApplied()
    return PA_ProfileGetGlobalResetEpochApplied()
end

function PortalAuthority:Profiles_SetSettingsResetEpochApplied(epoch)
    local normalized = PA_ProfileTrim(tostring(epoch or ""))
    if normalized == "" then
        return PA_ProfileClearGlobalResetEpochApplied()
    end
    return PA_ProfileSetGlobalResetEpochApplied(nil, normalized)
end

function PortalAuthority:Profiles_ClearSettingsResetEpochApplied()
    PA_ProfileClearGlobalResetEpochApplied()
    return true
end

function PortalAuthority:Profiles_GetQualifyingUpgradeOnboardingAppliedVersion()
    return PA_ProfileGetGlobalVersionField(nil, "qualifyingUpgradeOnboardingAppliedVersion")
end

function PortalAuthority:Profiles_SetQualifyingUpgradeOnboardingAppliedVersion(value)
    return PA_ProfileSetGlobalVersionField(nil, "qualifyingUpgradeOnboardingAppliedVersion", value)
end

function PortalAuthority:Profiles_GetQualifyingUpgradeOnboardingSeenVersion()
    return PA_ProfileGetGlobalVersionField(nil, "qualifyingUpgradeOnboardingSeenVersion")
end

function PortalAuthority:Profiles_SetQualifyingUpgradeOnboardingSeenVersion(value)
    return PA_ProfileSetGlobalVersionField(nil, "qualifyingUpgradeOnboardingSeenVersion", value)
end

function PortalAuthority:Profiles_ClearQualifyingUpgradeOnboardingState()
    self:Profiles_SetQualifyingUpgradeOnboardingAppliedVersion(nil)
    self:Profiles_SetQualifyingUpgradeOnboardingSeenVersion(nil)
    return true
end

function PortalAuthority:Profiles_GetSettingsWindowSearchIntroSeenVersion()
    return PA_ProfileGetGlobalVersionField(nil, "settingsWindowSearchIntroSeenVersion")
end

function PortalAuthority:Profiles_SetSettingsWindowSearchIntroSeenVersion(value)
    return PA_ProfileSetGlobalVersionField(nil, "settingsWindowSearchIntroSeenVersion", value)
end

function PortalAuthority:Profiles_ClearSettingsWindowSearchIntroSeenVersion()
    self:Profiles_SetSettingsWindowSearchIntroSeenVersion(nil)
    return true
end

function PortalAuthority:Profiles_GetOnboardingExperienceSeen()
    local value = select(1, PA_ProfileGetActiveIntroField("onboardingExperienceSeen"))
    return PA_ProfileNormalizeOnboardingExperienceSeen(value)
end

function PortalAuthority:Profiles_SetOnboardingExperienceSeen(value)
    return PA_ProfileSetActiveIntroField(
        "onboardingExperienceSeen",
        PA_ProfileNormalizeOnboardingExperienceSeen(value)
    )
end

function PortalAuthority:Profiles_GetFirstRunLandingConsumed()
    local value = select(1, PA_ProfileGetActiveIntroField("firstRunLandingConsumed"))
    return PA_ProfileNormalizeLandingConsumed(value)
end

function PortalAuthority:Profiles_SetFirstRunLandingConsumed(value)
    return PA_ProfileSetActiveIntroField(
        "firstRunLandingConsumed",
        PA_ProfileNormalizeLandingConsumed(value)
    )
end

function PortalAuthority:Profiles_ClearIntroState()
    self:Profiles_SetOnboardingExperienceSeen(nil)
    self:Profiles_SetFirstRunLandingConsumed(nil)
    return true
end

function PortalAuthority:Profiles_GetOnboardingD4Session()
    local value = select(1, PA_ProfileGetActiveIntroField("onboardingD4Session"))
    if type(value) ~= "table" then
        return nil
    end
    return PA_ProfileDeepCopy(value)
end

function PortalAuthority:Profiles_SetOnboardingD4Session(session)
    local normalized = nil
    if type(session) == "table" then
        normalized = PA_ProfileDeepCopy(session)
    end
    return PA_ProfileSetActiveIntroField("onboardingD4Session", normalized)
end

function PortalAuthority:Profiles_ClearOnboardingD4Session()
    return PA_ProfileSetActiveIntroField("onboardingD4Session", nil)
end

function PortalAuthority:GetProfilesCanonicalDefaultID()
    return PA_PROFILES.DEFAULT_ID
end

function PortalAuthority:Profiles_GetCharacterDisplayName()
    return PA_ProfileMakeCharacterLabel()
end

function PortalAuthority:Profiles_NormalizeSharedDisplayName(rawName)
    return PA_ProfileNormalizeDisplayName(rawName)
end

function PortalAuthority:Profiles_IsProtectedSharedID(profileID)
    return PA_ProfileTrim(tostring(profileID or "")) == PA_PROFILES.DEFAULT_ID
end

function PortalAuthority:Profiles_GetSharedDisplayName(profileID)
    local root = PA_ProfileGetProfileRoot()
    local resolvedID = PA_ProfileTrim(tostring(profileID or ""))
    if resolvedID == "" then
        return nil
    end
    local meta = root.sharedProfileMeta[resolvedID]
    if resolvedID == PA_PROFILES.DEFAULT_ID then
        return PA_PROFILES.DEFAULT_NAME
    end
    return PA_ProfileNormalizeDisplayName(meta and meta.name) or nil
end

function PortalAuthority:Profiles_IsSharedDisplayNameUnique(rawName, excludeProfileID)
    local normalized = PA_ProfileNormalizeDisplayName(rawName)
    if not normalized then
        return false
    end
    local normalizedKey = normalized:lower()
    local root = PA_ProfileGetProfileRoot()
    for profileID, meta in pairs(root.sharedProfileMeta) do
        if profileID ~= excludeProfileID then
            local otherName = PA_ProfileNormalizeDisplayName(meta and meta.name)
            if otherName and otherName:lower() == normalizedKey then
                return false
            end
        end
    end
    return true
end

function PortalAuthority:Profiles_GetSharedChoices()
    local root = PA_ProfileGetProfileRoot()
    local choices = {}
    for profileID, payload in pairs(root.sharedProfiles) do
        if type(payload) == "table" then
            local label = self:Profiles_GetSharedDisplayName(profileID)
            if label then
                choices[#choices + 1] = {
                    id = profileID,
                    label = label,
                    protected = self:Profiles_IsProtectedSharedID(profileID),
                }
            end
        end
    end
    table.sort(choices, function(left, right)
        if left.id == PA_PROFILES.DEFAULT_ID then
            return true
        end
        if right.id == PA_PROFILES.DEFAULT_ID then
            return false
        end
        return tostring(left.label or ""):lower() < tostring(right.label or ""):lower()
    end)
    return choices
end

function PortalAuthority:Profiles_GetActiveInfo()
    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local activePayload, activeKind, activeSharedID = PA_ProfileResolveBoundSource(root, charStore)
    local info = {
        kind = activeKind,
        sharedID = activeSharedID,
        isCharacter = activeKind == "character",
        isShared = activeKind == "shared",
        isDefaultShared = activeKind == "shared" and activeSharedID == PA_PROFILES.DEFAULT_ID,
        displayName = activeKind == "character" and PA_ProfileMakeCharacterLabel() or self:Profiles_GetSharedDisplayName(activeSharedID),
        payload = activePayload,
    }
    info.canRenameShared = info.isShared and not info.isDefaultShared
    info.canDeleteShared = info.isShared and not info.isDefaultShared
    return info
end

function PortalAuthority:Profiles_GetCopySourceChoices()
    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local activeInfo = self:Profiles_GetActiveInfo()
    local choices = {}

    if activeInfo.kind ~= "character" and type(charStore.characterProfile) == "table" then
        choices[#choices + 1] = {
            kind = "character",
            id = nil,
            label = PA_ProfileMakeCharacterLabel(),
        }
    end

    for _, choice in ipairs(self:Profiles_GetSharedChoices()) do
        if not (activeInfo.kind == "shared" and activeInfo.sharedID == choice.id) then
            choices[#choices + 1] = {
                kind = "shared",
                id = choice.id,
                label = choice.label,
            }
        end
    end

    table.sort(choices, function(left, right)
        if left.kind ~= right.kind then
            if left.kind == "character" then
                return true
            end
            if right.kind == "character" then
                return false
            end
        end
        return tostring(left.label or ""):lower() < tostring(right.label or ""):lower()
    end)
    return choices
end

function PortalAuthority:InitializeProfiles()
    local legacyPayload = PA_ProfileSafeTable(PortalAuthorityDB)
    local legacySnapshot = PA_ProfileLegacyPayloadLooksUsable(legacyPayload) and PA_ProfileSnapshotPayload(legacyPayload) or nil

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local meta = root.globalMeta
    local hasHistory = PA_ProfileHasHistory(meta, charStore)

    self._profilesFreshInstallThisLoad = false
    self._profilesLegacyMigratedThisLoad = false

    if not hasHistory then
        if type(root.sharedProfiles[PA_PROFILES.DEFAULT_ID]) ~= "table" then
            if legacySnapshot then
                root.sharedProfiles[PA_PROFILES.DEFAULT_ID] = legacySnapshot
                self._profilesLegacyMigratedThisLoad = true
            else
                root.sharedProfiles[PA_PROFILES.DEFAULT_ID] = PA_ProfileBuildCanonicalBaselineSnapshot()
                self._profilesFreshInstallThisLoad = true
            end
        end
    end

    PA_ProfileEnsureCanonicalDefault(root)
    PA_ProfileEnsureMetaSchema(root)
    PA_ProfileEnsureSharedMetaIntegrity(root)

    charStore.profileSystemSeen = true
    if charStore.activeProfileKind ~= "shared" and charStore.activeProfileKind ~= "character" then
        charStore.activeProfileKind = "shared"
    end
    if charStore.activeProfileKind ~= "character" then
        charStore.activeProfileKind = "shared"
        if type(root.sharedProfiles[charStore.activeProfileKey]) ~= "table" then
            charStore.activeProfileKey = PA_PROFILES.DEFAULT_ID
        end
    elseif type(charStore.characterProfile) ~= "table" then
        charStore.activeProfileKind = "shared"
        charStore.activeProfileKey = PA_PROFILES.DEFAULT_ID
    end

    local activePayload, activeKind, activeSharedID, activeWasNormalized = PA_ProfileResolveAndNormalizeBoundSource(root, charStore)
    PortalAuthorityDB = PA_ProfileSafeTable(PortalAuthorityDB) or {}
    PA_ProfileReplaceTable(PortalAuthorityDB, PA_ProfileClonePayloadPreservingMeta(activePayload))

    self._profilesInitialized = true
    self._profilesActivePayloadNormalizedThisLoad = activeWasNormalized and true or false
    self._profileSessionBoundKind = activeKind
    self._profileSessionBoundKey = activeSharedID
    self._profileSkipLogoutSync = false
    return PortalAuthorityDB
end

function PortalAuthority:Profiles_FlushRuntimeToBoundDestination(kind, key)
    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local resolvedKind = (kind == "character") and "character" or "shared"
    local destination, resolvedKey = PA_ProfileResolveDestination(root, charStore, resolvedKind, key, resolvedKind == "character")
    if type(destination) ~= "table" then
        return false, "Profile destination is unavailable."
    end
    PA_ProfileReplaceTable(destination, PA_ProfileClonePayloadPreservingMeta(PortalAuthorityDB or {}))
    if resolvedKind == "shared" and resolvedKey then
        charStore.activeProfileKey = PA_ProfileTrim(tostring(charStore.activeProfileKey or resolvedKey or ""))
    end
    return true
end

function PortalAuthority:Profiles_HandlePlayerLogout()
    if not self._profilesInitialized then
        return
    end
    if self._profileSkipLogoutSync then
        return
    end
    self:Profiles_FlushRuntimeToBoundDestination(self._profileSessionBoundKind, self._profileSessionBoundKey)
end

function PortalAuthority:Profiles_ApplyPublicQualifyingUpgradeReset(rolloutVersion)
    local normalizedVersion = PA_ProfileTrim(tostring(rolloutVersion or ""))
    if normalizedVersion == "" then
        return false, "Qualifying-upgrade rollout version is unavailable.", false, nil
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local activeInfo = self:Profiles_GetActiveInfo()
    local destination, resolvedKey = PA_ProfileResolveDestination(root, charStore, activeInfo.kind, activeInfo.sharedID, activeInfo.kind == "character")
    if type(destination) ~= "table" then
        return false, "Active profile destination is unavailable.", false, nil
    end

    if PA_ProfileGetGlobalResetEpochApplied(root) == PA_ONBOARDING_RESET_EPOCH then
        return false, "Qualifying-upgrade reset is already marked applied for this active experience.", false, "already-handled"
    end

    local sourcePayload = PA_ProfileSafeTable(PortalAuthorityDB) or destination
    local backupOk, backupMessage = PA_ProfileTryCreateQualifyingUpgradeBackup(root, sourcePayload)
    if not backupOk and backupMessage ~= "already-handled" then
        backupMessage = tostring(backupMessage or "backup skipped")
    end

    PA_ProfileReplaceTable(destination, PA_ProfileBuildCanonicalBaselineSnapshot())
    PortalAuthorityDB = PA_ProfileSafeTable(PortalAuthorityDB) or {}
    PA_ProfileReplaceTable(PortalAuthorityDB, PA_ProfileClonePayloadPreservingMeta(destination))
    if activeInfo.kind == "shared" then
        charStore.activeProfileKey = resolvedKey or activeInfo.sharedID
    end

    PA_ProfileSetGlobalResetEpochApplied(root, PA_ONBOARDING_RESET_EPOCH)
    self:Profiles_SetQualifyingUpgradeOnboardingAppliedVersion(normalizedVersion)
    self:Profiles_SetQualifyingUpgradeOnboardingSeenVersion(nil)
    self:Profiles_ClearIntroState()
    self:Profiles_ClearOnboardingD4Session()

    return true, "Qualifying-upgrade baseline reset applied to the active experience.", backupOk, backupMessage
end

local function PA_ProfileValidationError(message)
    return false, tostring(message or "Profile operation failed.")
end

local function PA_ProfileAbortOnboardingD4IfActive(authority, reason)
    if not authority or type(authority.AbortOnboardingD4ForProfileMutation) ~= "function" then
        return true
    end
    return authority:AbortOnboardingD4ForProfileMutation(reason)
end

function PortalAuthority:Profiles_SwitchToCharacterAndReload()
    local okAbort, abortErr = PA_ProfileAbortOnboardingD4IfActive(self, "profile-switch-character")
    if not okAbort then
        return PA_ProfileValidationError(abortErr or "Guided setup cleanup failed before switching profiles.")
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    if charStore.activeProfileKind == "character" and type(charStore.characterProfile) == "table" then
        PA_ProfileNormalizeDestinationForActivation(charStore.characterProfile)
        return true
    end
    if type(charStore.characterProfile) ~= "table" then
        charStore.characterProfile = PA_ProfileClonePayloadPreservingMeta(PortalAuthorityDB or {})
    else
        PA_ProfileNormalizeDestinationForActivation(charStore.characterProfile)
    end
    charStore.activeProfileKind = "character"
    charStore.activeProfileKey = nil
    self._profileSkipLogoutSync = true
    ReloadUI()
    return true
end

function PortalAuthority:Profiles_SwitchToSharedAndReload(profileID)
    local okAbort, abortErr = PA_ProfileAbortOnboardingD4IfActive(self, "profile-switch-shared")
    if not okAbort then
        return PA_ProfileValidationError(abortErr or "Guided setup cleanup failed before switching profiles.")
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local targetID = PA_ProfileTrim(tostring(profileID or ""))
    if targetID == "" or type(root.sharedProfiles[targetID]) ~= "table" then
        return PA_ProfileValidationError("Shared profile is unavailable.")
    end
    if charStore.activeProfileKind == "shared" and charStore.activeProfileKey == targetID then
        return true
    end
    local ok, err = self:Profiles_FlushRuntimeToBoundDestination(self._profileSessionBoundKind, self._profileSessionBoundKey)
    if not ok then
        return PA_ProfileValidationError(err)
    end
    PA_ProfileNormalizeDestinationForActivation(root.sharedProfiles[targetID])
    charStore.activeProfileKind = "shared"
    charStore.activeProfileKey = targetID
    self._profileSkipLogoutSync = true
    ReloadUI()
    return true
end

function PortalAuthority:Profiles_CreateSharedAndSwitch(rawName)
    local okAbort, abortErr = PA_ProfileAbortOnboardingD4IfActive(self, "profile-create-shared")
    if not okAbort then
        return PA_ProfileValidationError(abortErr or "Guided setup cleanup failed before creating a shared profile.")
    end

    local normalizedName = PA_ProfileNormalizeDisplayName(rawName)
    if not normalizedName then
        return PA_ProfileValidationError("Profile name cannot be empty.")
    end
    if not self:Profiles_IsSharedDisplayNameUnique(normalizedName) then
        return PA_ProfileValidationError("Shared profile name already exists.")
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local profileID = PA_ProfileAllocateSharedID(root)
    root.sharedProfiles[profileID] = PA_ProfileClonePayloadPreservingMeta(PortalAuthorityDB or {})
    root.sharedProfileMeta[profileID] = {
        name = normalizedName,
        protected = false,
    }
    charStore.activeProfileKind = "shared"
    charStore.activeProfileKey = profileID
    self._profileSkipLogoutSync = true
    ReloadUI()
    return true
end

function PortalAuthority:Profiles_CopyIntoActiveAndReload(sourceKind, sourceID)
    local okAbort, abortErr = PA_ProfileAbortOnboardingD4IfActive(self, "profile-copy-into-active")
    if not okAbort then
        return PA_ProfileValidationError(abortErr or "Guided setup cleanup failed before copying profile data.")
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local sourcePayload = nil
    local sourceErr = nil
    sourcePayload, sourceErr = PA_ProfileValidateSourceProfile(root, sourceKind, sourceID)
    if not sourcePayload then
        return PA_ProfileValidationError(sourceErr)
    end

    local activeInfo = self:Profiles_GetActiveInfo()
    local destination, resolvedKey = PA_ProfileResolveDestination(root, charStore, activeInfo.kind, activeInfo.sharedID, activeInfo.kind == "character")
    if type(destination) ~= "table" then
        return PA_ProfileValidationError("Active profile destination is unavailable.")
    end

    local candidatePayload = nil
    candidatePayload = select(1, PA_ProfileBuildActivationCandidate(sourcePayload))
    PA_ProfileReplaceTable(destination, candidatePayload)
    if activeInfo.kind == "shared" then
        charStore.activeProfileKey = resolvedKey or activeInfo.sharedID
    end
    self._profileSkipLogoutSync = true
    ReloadUI()
    return true
end

function PortalAuthority:Profiles_ResetActiveAndReload()
    local okAbort, abortErr = PA_ProfileAbortOnboardingD4IfActive(self, "profile-reset-active")
    if not okAbort then
        return PA_ProfileValidationError(abortErr or "Guided setup cleanup failed before resetting the active profile.")
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local activeInfo = self:Profiles_GetActiveInfo()
    local destination, resolvedKey = PA_ProfileResolveDestination(root, charStore, activeInfo.kind, activeInfo.sharedID, activeInfo.kind == "character")
    if type(destination) ~= "table" then
        return PA_ProfileValidationError("Active profile destination is unavailable.")
    end
    PA_ProfileReplaceTable(destination, PA_ProfileBuildCanonicalBaselineSnapshot())
    if activeInfo.kind == "shared" then
        charStore.activeProfileKey = resolvedKey or activeInfo.sharedID
    end
    self._profileSkipLogoutSync = true
    ReloadUI()
    return true
end

function PortalAuthority:Profiles_RenameShared(profileID, rawName)
    local targetID = PA_ProfileTrim(tostring(profileID or ""))
    if targetID == "" or self:Profiles_IsProtectedSharedID(targetID) then
        return PA_ProfileValidationError("Protected shared profile cannot be renamed.")
    end

    local root = PA_ProfileGetProfileRoot()
    if type(root.sharedProfiles[targetID]) ~= "table" then
        return PA_ProfileValidationError("Shared profile is unavailable.")
    end

    local normalizedName = PA_ProfileNormalizeDisplayName(rawName)
    if not normalizedName then
        return PA_ProfileValidationError("Profile name cannot be empty.")
    end
    if not self:Profiles_IsSharedDisplayNameUnique(normalizedName, targetID) then
        return PA_ProfileValidationError("Shared profile name already exists.")
    end

    root.sharedProfileMeta[targetID] = PA_ProfileSafeTable(root.sharedProfileMeta[targetID]) or {}
    root.sharedProfileMeta[targetID].name = normalizedName
    root.sharedProfileMeta[targetID].protected = false
    return true
end

function PortalAuthority:Profiles_DeleteShared(profileID)
    local okAbort, abortErr = PA_ProfileAbortOnboardingD4IfActive(self, "profile-delete-shared")
    if not okAbort then
        return PA_ProfileValidationError(abortErr or "Guided setup cleanup failed before deleting the shared profile.")
    end

    local targetID = PA_ProfileTrim(tostring(profileID or ""))
    if targetID == "" or self:Profiles_IsProtectedSharedID(targetID) then
        return PA_ProfileValidationError("Protected shared profile cannot be deleted.")
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    if type(root.sharedProfiles[targetID]) ~= "table" then
        return PA_ProfileValidationError("Shared profile is unavailable.")
    end

    local isActiveShared = (charStore.activeProfileKind == "shared" and charStore.activeProfileKey == targetID)
    root.sharedProfiles[targetID] = nil
    root.sharedProfileMeta[targetID] = nil

    if isActiveShared then
        PA_ProfileNormalizeDestinationForActivation(root.sharedProfiles[PA_PROFILES.DEFAULT_ID])
        charStore.activeProfileKind = "shared"
        charStore.activeProfileKey = PA_PROFILES.DEFAULT_ID
        self._profileSkipLogoutSync = true
        ReloadUI()
    end
    return true
end

function PortalAuthority:Profiles_RunOnboardingD1Exercise(rawAction)
    local action = string.lower(PA_ProfileTrim(tostring(rawAction or "")))
    if action == "" then
        return false, "Usage: /pa dev onboarding-d1 first-install|qualifying-upgrade|normalize-active|clear-reset-state", false
    end

    local root = PA_ProfileGetProfileRoot()
    local charStore = PA_ProfileGetCharacterStore()
    local activeInfo = self:Profiles_GetActiveInfo()
    local destination, resolvedKey = PA_ProfileResolveDestination(root, charStore, activeInfo.kind, activeInfo.sharedID, activeInfo.kind == "character")
    if type(destination) ~= "table" then
        return false, "Active profile destination is unavailable.", false
    end

    if action == "first-install" then
        PA_ProfileReplaceTable(destination, PA_ProfileBuildCanonicalBaselineSnapshot())
        if activeInfo.kind == "shared" then
            charStore.activeProfileKey = resolvedKey or activeInfo.sharedID
        end
        PA_ProfileSetGlobalResetEpochApplied(root, PA_ONBOARDING_RESET_EPOCH)
        self._profileSkipLogoutSync = true
        return true, "D1 first-install baseline applied to the active profile. Reloading UI.", true
    end

    if action == "qualifying-upgrade" then
        local existingEpoch = PA_ProfileGetGlobalResetEpochApplied(root)
        if existingEpoch == PA_ONBOARDING_RESET_EPOCH then
            return true, "D1 qualifying-upgrade reset is already marked applied for this active experience.", false
        end

        local backupOk, backupMessage = PA_ProfileTryCreateQualifyingUpgradeBackup(root, PA_ProfileSafeTable(PortalAuthorityDB) or destination)
        if not backupOk and backupMessage ~= "already-handled" then
            -- Best-effort only: continue with the reset even if backup creation fails.
            backupMessage = tostring(backupMessage or "backup skipped")
        end

        PA_ProfileReplaceTable(destination, PA_ProfileBuildCanonicalBaselineSnapshot())
        if activeInfo.kind == "shared" then
            charStore.activeProfileKey = resolvedKey or activeInfo.sharedID
        end
        PA_ProfileSetGlobalResetEpochApplied(root, PA_ONBOARDING_RESET_EPOCH)
        self._profileSkipLogoutSync = true

        if backupOk then
            return true, string.format("D1 qualifying-upgrade baseline reset applied. Backup created: %s. Reloading UI.", tostring(backupMessage)), true
        end
        return true, string.format("D1 qualifying-upgrade baseline reset applied. Backup skipped: %s. Reloading UI.", tostring(backupMessage)), true
    end

    if action == "normalize-active" then
        local _, didNormalize = PA_ProfileNormalizeDestinationForActivation(destination)
        if activeInfo.kind == "shared" then
            charStore.activeProfileKey = resolvedKey or activeInfo.sharedID
        end
        if didNormalize then
            self._profileSkipLogoutSync = true
            return true, "D1 normalized the active profile to the canonical 2.0 baseline. Reloading UI.", true
        end
        return true, "D1 active profile is already handled; no changes were needed.", false
    end

    if action == "clear-reset-state" then
        PA_ProfileClearGlobalResetEpochApplied(root)
        PA_ProfileClearPayloadResetEpoch(destination)
        PA_ProfileClearPayloadResetEpoch(PortalAuthorityDB)
        self:Profiles_ClearQualifyingUpgradeOnboardingState()
        if activeInfo.kind == "shared" then
            charStore.activeProfileKey = resolvedKey or activeInfo.sharedID
        end
        return true, "D1 cleared the active reset markers. You can now run qualifying-upgrade to test backup creation.", false
    end

    return false, "Usage: /pa dev onboarding-d1 first-install|qualifying-upgrade|normalize-active|clear-reset-state", false
end
