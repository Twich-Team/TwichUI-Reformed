-- Portal Authority
-- Mythic+ modules (session-level unlock/test state + Battle Rez Timer).

PortalAuthority = PortalAuthority or {}
PortalAuthority.Modules = PortalAuthority.Modules or {}

local Modules = PortalAuthority.Modules
Modules.registry = Modules.registry or {}
Modules.optionsHooks = Modules.optionsHooks or {}
Modules.unlock = false
Modules.testMode = false
Modules.modules2TestMode = false
Modules.timersTestMode = false

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
    local cleaned = text:gsub("^%s+", ""):gsub("%s+$", "")
    return cleaned
end

local function clampNumber(value, fallback, min, max)
    value = tonumber(value) or fallback
    if min and value < min then value = min end
    if max and value > max then value = max end
    return value
end

local function PA_Num(v)
    if v == nil then return 0 end
    -- stringify first to strip secret-number wrapper, then tonumber
    local n = tonumber(tostring(v))
    if n == nil then return 0 end
    return n
end

local function IT_HasSecretValues(...)
    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, ...)
        if ok and hasSecret then
            return true
        end
    end
    return false
end

local function IT_IsUsablePlainString(value)
    if type(value) ~= "string" then
        return false
    end
    if IT_HasSecretValues(value) then
        return false
    end
    return value ~= ""
end

local function IT_IsUsablePlainBoolean(value)
    return type(value) == "boolean" and not IT_HasSecretValues(value)
end

local function IT_IsUsablePlainNumber(value)
    if type(value) ~= "number" then
        return false
    end
    if IT_HasSecretValues(value) then
        return false
    end
    return value == value and value > -math.huge and value < math.huge
end

local function IT_NormalizeSafeString(value)
    if not IT_IsUsablePlainString(value) then
        return nil
    end
    return value
end

local function IT_NormalizeSpellID(value)
    if IT_IsUsablePlainNumber(value) then
        local numeric = math.floor(value)
        return numeric > 0 and numeric or 0
    end
    if IT_IsUsablePlainString(value) then
        local numeric = tonumber(value)
        if type(numeric) == "number" and numeric == numeric and numeric > 0 and numeric < math.huge then
            return math.floor(numeric)
        end
    end
    return 0
end

local function IT_SafeStringsEqual(left, right)
    local normalizedLeft = IT_NormalizeSafeString(left)
    local normalizedRight = IT_NormalizeSafeString(right)
    return normalizedLeft ~= nil and normalizedRight ~= nil and normalizedLeft == normalizedRight
end

local IT_SafeUnitGUID

local PA_SEND_ADDON_MESSAGE_RESULT_NAMES = {
    [0] = "Success",
    [1] = "InvalidPrefix",
    [2] = "InvalidMessage",
    [3] = "AddonMessageThrottle",
    [4] = "InvalidChatType",
    [5] = "NotInGroup",
    [6] = "TargetRequired",
    [7] = "InvalidChannel",
    [8] = "ChannelThrottle",
    [9] = "GeneralError",
    [10] = "NotInGuild",
    [11] = "AddOnMessageLockdown",
    [12] = "TargetOffline",
}

local function PA_NormalizeAddonSendResult(result)
    local numeric = tonumber(result)
    if numeric ~= nil then
        return math.floor(numeric)
    end
    if IT_IsUsablePlainString(result) then
        for enumValue, enumName in pairs(PA_SEND_ADDON_MESSAGE_RESULT_NAMES) do
            if enumName == result then
                return enumValue
            end
        end
    end
    return nil
end

local function PA_ClassifyAddonSendResult(result)
    local code = PA_NormalizeAddonSendResult(result)
    local name = code ~= nil and PA_SEND_ADDON_MESSAGE_RESULT_NAMES[code] or nil
    if code == 0 then
        return true, code, "success", name
    end
    if code == 11 then
        return false, code, "lockdown", name
    end
    if code == 3 or code == 8 then
        return false, code, "throttle", name
    end
    if code == 5 then
        return false, code, "not_in_group", name
    end
    if code == 4 or code == 7 then
        return false, code, "channel_unavailable", name
    end
    if code == 6 then
        return false, code, "target_required", name
    end
    if code == 12 then
        return false, code, "target_offline", name
    end
    if code == 1 or code == 2 then
        return false, code, "invalid_payload", name
    end
    if code == 9 or code == 10 then
        return false, code, "general_error", name
    end
    return false, code or result, "unknown", name
end

local function PA_ShouldFallbackAddonChannel(channel, classification)
    return channel == "INSTANCE_CHAT" and (classification == "not_in_group" or classification == "channel_unavailable")
end

local function PA_SafeSendAddonMessage(prefix, message, channel, target)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false, "SendAddonMessage unavailable", "unavailable", nil, channel
    end

    local ok, result
    if target ~= nil then
        ok, result = pcall(C_ChatInfo.SendAddonMessage, prefix, message, channel, target)
    else
        ok, result = pcall(C_ChatInfo.SendAddonMessage, prefix, message, channel)
    end
    if not ok then
        return false, "SendAddonMessage runtime error", "runtime_error", nil, channel
    end

    local sent, normalizedResult, classification, resultName = PA_ClassifyAddonSendResult(result)
    if sent then
        return true, normalizedResult, classification, resultName, channel
    end
    if target == nil and PA_ShouldFallbackAddonChannel(channel, classification) then
        return PA_SafeSendAddonMessage(prefix, message, "PARTY")
    end
    return false, normalizedResult, classification, resultName, channel
end

local function PA_CanSafelyInspectUnit(unit)
    if type(unit) ~= "string" or unit == "" or not UnitExists(unit) then
        return false
    end
    if UnitIsConnected and not UnitIsConnected(unit) then
        return false
    end
    if type(CanInspect) ~= "function" then
        return true
    end
    local ok, canInspect = pcall(CanInspect, unit, true)
    if not ok then
        ok, canInspect = pcall(CanInspect, unit)
    end
    return ok and canInspect and true or false
end

local function PA_ServerNow()
    if type(GetServerTime) == "function" then
        return PA_Num(GetServerTime())
    end
    if type(time) == "function" then
        return PA_Num(time())
    end
    return PA_Num(GetTime())
end

local function PA_PerfBegin(scopeName, explicitState)
    if PortalAuthority and PortalAuthority.PerfBegin then
        return PortalAuthority:PerfBegin(scopeName, explicitState)
    end
    return nil, nil
end

local function PA_PerfEnd(scopeName, startedAt, stateLabel)
    if startedAt ~= nil and PortalAuthority and PortalAuthority.PerfEnd then
        PortalAuthority:PerfEnd(scopeName, startedAt, stateLabel)
    end
end

local function PA_CpuDiagCount(scopeName, detailKey)
    if PortalAuthority and PortalAuthority.CpuDiagCount then
        PortalAuthority:CpuDiagCount(scopeName, detailKey)
    end
end

local function PA_CpuDiagRecordModuleEvent(eventScope)
    if PortalAuthority and PortalAuthority.CpuDiagRecordModuleEvent then
        PortalAuthority:CpuDiagRecordModuleEvent(eventScope)
    end
end

local function PA_CpuDiagRecordDispatcherEvent(dispatcherName, eventName)
    if PortalAuthority and PortalAuthority.CpuDiagRecordDispatcherEvent then
        PortalAuthority:CpuDiagRecordDispatcherEvent(dispatcherName, eventName)
    end
end

local function PA_CpuDiagRecordUnitCallback(eventName)
    if PortalAuthority and PortalAuthority.CpuDiagRecordUnitCallback then
        PortalAuthority:CpuDiagRecordUnitCallback(eventName)
    end
end

local function PA_CpuDiagRecordTrigger(triggerKey)
    if PortalAuthority and PortalAuthority.CpuDiagRecordTrigger then
        PortalAuthority:CpuDiagRecordTrigger(triggerKey)
    end
end

local function PA_CpuDiagApplyVisibility(target, frame, naturalVisible)
    if not frame then
        return false
    end
    if PortalAuthority and PortalAuthority.CpuDiagApplyVisibility then
        return PortalAuthority:CpuDiagApplyVisibility(target, frame, naturalVisible)
    end
    if naturalVisible then
        frame:Show()
    else
        frame:Hide()
    end
    return naturalVisible and true or false
end

local function PA_CpuDiagIsFrameConsideredShown(target, frame)
    if frame and frame.IsShown and frame:IsShown() then
        return true
    end
    if PortalAuthority and PortalAuthority.CpuDiagIsNaturallyVisible then
        return PortalAuthority:CpuDiagIsNaturallyVisible(target)
    end
    return false
end

local function PA_IsUiSurfaceGateEnabled()
    return PortalAuthority and PortalAuthority.IsUiSurfaceGateEnabled and PortalAuthority:IsUiSurfaceGateEnabled() or false
end

local function PA_IsSuppressedUiSurfaceModule(moduleOrKey)
    if not PA_IsUiSurfaceGateEnabled() then
        return false
    end
    local key = type(moduleOrKey) == "table" and moduleOrKey.key or moduleOrKey
    return key == "timers" or key == "interruptTracker"
end

local function PA_HideTooltipIfOwnedBy(owner)
    if not GameTooltip then
        return
    end
    local currentOwner = GameTooltip.GetOwner and GameTooltip:GetOwner() or nil
    if owner == nil or currentOwner == owner then
        GameTooltip:Hide()
    end
end

function Modules:Register(module)
    if not module or not module.key then
        return
    end
    self.registry[module.key] = module
end

function Modules:ForEach(callback)
    for _, module in pairs(self.registry) do
        callback(module)
    end
end

function Modules:RegisterOptionsHooks(hooks)
    self.optionsHooks = self.optionsHooks or {}
    if type(hooks) ~= "table" then
        return
    end
    for key, value in pairs(hooks) do
        self.optionsHooks[key] = value
    end
end

function Modules:NotifyPositionChanged(moduleKey, x, y)
    local hooks = self.optionsHooks
    if not hooks then
        return
    end

    if moduleKey == "timers" and type(hooks.onTimersPositionChanged) == "function" then
        hooks.onTimersPositionChanged(x, y)
        return
    end

    if moduleKey == "interruptTracker" and type(hooks.onInterruptTrackerPositionChanged) == "function" then
        hooks.onInterruptTrackerPositionChanged(x, y)
    end
end

function Modules:SetUnlocked(unlocked)
    self.unlock = not not unlocked

    if type(PortalAuthorityDB) == "table" then
        PortalAuthorityDB.modules = PortalAuthorityDB.modules or {}
        PortalAuthorityDB.modules.timers = PortalAuthorityDB.modules.timers or {}
        PortalAuthorityDB.modules.timers.locked = not self.unlock
        PortalAuthorityDB.modules.interruptTracker = PortalAuthorityDB.modules.interruptTracker or {}
        PortalAuthorityDB.modules.interruptTracker.locked = not self.unlock
    end

    local applied = {}
    local orderedKeys = { "timers", "interruptTracker" }
    for i = 1, #orderedKeys do
        local key = orderedKeys[i]
        local module = self.registry and self.registry[key] or nil
        if module and module.SetUnlocked then
            module:SetUnlocked(self.unlock)
            applied[key] = true
        end
    end

    for key, module in pairs(self.registry or {}) do
        if not applied[key] and module and module.SetUnlocked then
            module:SetUnlocked(self.unlock)
        end
    end
end

function Modules:SetTestMode(enabled)
    self.testMode = not not enabled
    self:ForEach(function(module)
        if module.SetTestModeEnabled then
            module:SetTestModeEnabled(self.testMode)
        end
        if module.EvaluateVisibility then
            module:EvaluateVisibility("test-toggle")
        end
    end)
end

function Modules:SetTimersTestMode(enabled)
    enabled = not not enabled
    if enabled and InCombatLockdown and InCombatLockdown() then
        return
    end

    self.timersTestMode = enabled
    self.modules2TestMode = enabled
    local module = self.registry and self.registry.timers
    if not module then
        return
    end

    local moduleFrame = module.frame or module.mainFrame
    if enabled and module.IsEnabled and module:IsEnabled() and module.Initialize and not moduleFrame then
        module:Initialize()
    end

    if module.SetUnlocked then
        local desiredUnlocked = module.GetDB and (not not (module:GetDB().locked == false)) or (module.unlocked and true or false)
        module:SetUnlocked(desiredUnlocked)
    end

    if module.EvaluateVisibility then
        module:EvaluateVisibility("timers-test-toggle")
    end
end

function Modules:SetModules2TestMode(enabled)
    self:SetTimersTestMode(enabled)
end

do

local BrezTimer = {
    key = "brezTimer",
    fallbackSpellCandidates = { 20484, 61999, 20707 },
}

function BrezTimer:GetAuthoritativeState()
    if C_PartyInfo and C_PartyInfo.GetAvailableBattleResurrectionCharges and C_PartyInfo.GetBattleResurrectionChargeCooldown then
        local available = PA_Num(C_PartyInfo.GetAvailableBattleResurrectionCharges())
        available = math.max(0, math.floor(available))
        local start, cdDur = C_PartyInfo.GetBattleResurrectionChargeCooldown()
        start = PA_Num(start)
        cdDur = PA_Num(cdDur)
        local remaining = 0
        if cdDur > 0 then
            remaining = math.max(0, (start + cdDur) - GetTime())
        end
        return {
            charges = available,
            remaining = remaining,
            source = "partyinfo",
        }
    end

    return self:GetFallbackState()
end

function BrezTimer:PickFallbackSpellID()
    local selected = nil

    local function getCharges(spellID)
        if C_Spell and C_Spell.GetSpellCharges then
            local charges = C_Spell.GetSpellCharges(spellID)
            if type(charges) == "number" then
                return charges
            end
        end
        if GetSpellCharges then
            local charges = GetSpellCharges(spellID)
            if type(charges) == "number" then
                return charges
            end
        end
        return nil
    end

    local function isKnownSpell(spellID)
        if C_Spell and C_Spell.GetSpellName then
            return C_Spell.GetSpellName(spellID) ~= nil
        end
        if IsSpellKnownOrOverridesKnown then
            return IsSpellKnownOrOverridesKnown(spellID)
        end
        return false
    end

    for _, spellID in ipairs(self.fallbackSpellCandidates) do
        local charges = getCharges(spellID)
        if charges ~= nil then
            selected = spellID
            break
        end
        if isKnownSpell(spellID) then
            selected = spellID
            break
        end
    end

    self.fallbackSpellID = selected
end

function BrezTimer:GetFallbackState()
    if not self.fallbackSpellID then
        self:PickFallbackSpellID()
    end

    local spellID = self.fallbackSpellID or 20484

    local charges = nil
    local start, duration = nil, nil

    if C_Spell and C_Spell.GetSpellCharges then
        local chargesInfo = C_Spell.GetSpellCharges(spellID)
        if type(chargesInfo) == "table" then
            if chargesInfo.currentCharges ~= nil then
                charges = PA_Num(chargesInfo.currentCharges)
                start = PA_Num(chargesInfo.cooldownStartTime)
                duration = PA_Num(chargesInfo.cooldownDuration)
            end
        else
            local currentCharges, maxCharges, chargeStart, chargeDuration = C_Spell.GetSpellCharges(spellID)
            if currentCharges ~= nil then
                charges = PA_Num(currentCharges)
                start = PA_Num(chargeStart)
                duration = PA_Num(chargeDuration)
            end
        end
    elseif GetSpellCharges then
        local currentCharges, maxCharges, chargeStart, chargeDuration = GetSpellCharges(spellID)
        if currentCharges ~= nil then
            charges = PA_Num(currentCharges)
            start = PA_Num(chargeStart)
            duration = PA_Num(chargeDuration)
        end
    end

    if charges == nil then
        charges = 0
    end

    if start == nil then
        if C_Spell and C_Spell.GetSpellCooldown then
            local info = C_Spell.GetSpellCooldown(spellID)
            if type(info) == "table" then
                start, duration = info.startTime, info.duration
            end
        elseif GetSpellCooldown then
            start, duration = GetSpellCooldown(spellID)
        end
    end

    local remaining = 0
    start = PA_Num(start)
    duration = PA_Num(duration)
    if duration > 0 then
        remaining = math.max(0, (start + duration) - GetTime())
    end

    return {
        charges = math.max(0, PA_Num(charges)),
        remaining = remaining,
        source = "fallback",
    }
end

function BrezTimer:ShouldShowLive()
    local _, instanceType, difficultyID = GetInstanceInfo()
    local inPartyDungeon = (instanceType == "party")
    local inMythicKeystone = (difficultyID == 8)
    local inChallenge = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
    local inEncounter = C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress and C_InstanceEncounter.IsEncounterInProgress()
    return not not (inPartyDungeon or inMythicKeystone or inChallenge or inEncounter)
end

function BrezTimer:IsMythicKeystoneActive()
    if C_PartyInfo and C_PartyInfo.IsChallengeModeActive then
        return not not C_PartyInfo.IsChallengeModeActive()
    end
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
        return not not C_ChallengeMode.IsChallengeModeActive()
    end
    return false
end


local function copyMissingRecursive(source, target)
    for key, value in pairs(source) do
        local existing = target[key]
        if type(value) == "table" then
            if existing == nil then
                target[key] = {}
                copyMissingRecursive(value, target[key])
            elseif type(existing) == "table" then
                copyMissingRecursive(value, existing)
            end
        elseif existing == nil then
            target[key] = value
        end
    end
end

local function MigrateModules2StackToTimers()
    PortalAuthorityDB = PortalAuthorityDB or {}
    PortalAuthorityDB.modules = PortalAuthorityDB.modules or {}
    PortalAuthorityDB.modules.timers = type(PortalAuthorityDB.modules.timers) == "table" and PortalAuthorityDB.modules.timers or {}
    local migrations = (PortalAuthority and PortalAuthority.GetOperationalMigrations and PortalAuthority:GetOperationalMigrations())
        or {}

    if migrations.modules2Stack_to_timers then
        return
    end

    local oldRef = PortalAuthorityDB.modules.modules2Stack
    local newRef = PortalAuthorityDB.modules.timers

    if type(oldRef) == "table" then
        copyMissingRecursive(oldRef, newRef)
    end

    migrations.modules2Stack_to_timers = true
end

local Timers = {
    key = "timers",
}

local ICON_EDGE_STYLE_SHARP = "Sharp (Zoomed)"
local ICON_EDGE_STYLE_FULL = "Square (Full)"
local ICON_EDGE_STYLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local PA_LUST = {
    EXHAUST_DEBUFFS = { 57723, 390435, 57724, 80354, 264689 },
    BUFFS = { 2825, 32182, 80353, 264667, 390386, 466904 },
    ACTIVE_SECONDS = 40,
    SATED_SECONDS = 600,
    PREFIX = "PortalAuthority",
    COMM_REQ = "REQ",
    COMM_STATE = "STATE",
    COMM_CAST = "CAST",
    COMM_MAX_SECONDS = 420,
    AUDIO_PATH = "Interface\\AddOns\\PortalAuthority\\Media\\Audio\\bloodlust.ogg",
    SPEC_BEAST_MASTERY = 253,
    SPEC_MARKSMANSHIP = 254,
    SPEC_SURVIVAL = 255,
    FALLBACK_COOLDOWNS = {
        [2825] = 300,
        [32182] = 300,
        [80353] = 300,
        [264667] = 360,
        [390386] = 300,
        [466904] = 360,
    },
    SUPPORTED_SPELLS = {},
    EXHAUST_LOOKUP = {},
}
for spellID in pairs(PA_LUST.FALLBACK_COOLDOWNS) do
    PA_LUST.SUPPORTED_SPELLS[spellID] = true
end
for _, spellID in ipairs(PA_LUST.EXHAUST_DEBUFFS) do
    PA_LUST.EXHAUST_LOOKUP[spellID] = true
end

local function PA_LustIsFiniteNumber(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function PA_LustNormalizeNameText(value)
    if not IT_IsUsablePlainString(value) then
        return nil
    end
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function PA_LustNormalizeShortName(value)
    local normalized = PA_LustNormalizeNameText(value)
    if not normalized then
        return nil
    end
    local ok, shortName = pcall(Ambiguate, normalized, "short")
    return PA_LustNormalizeNameText(ok and shortName or normalized)
end

local function PA_LustSafeUnitClass(unit)
    local ok, _, classFile = pcall(UnitClass, unit)
    if ok and IT_IsUsablePlainString(classFile) then
        return classFile
    end
    return nil
end

local function PA_LustSafeUnitName(unit)
    if not unit then
        return nil
    end
    if UnitFullName then
        local ok, name, realm = pcall(UnitFullName, unit)
        if ok and not IT_HasSecretValues(name, realm) then
            local normalizedName = PA_LustNormalizeNameText(name)
            local normalizedRealm = PA_LustNormalizeNameText(realm)
            if normalizedName then
                if normalizedRealm then
                    return normalizedName .. "-" .. normalizedRealm
                end
                return normalizedName
            end
        end
    end
    local ok, name = pcall(UnitName, unit)
    if ok and not IT_HasSecretValues(name) then
        return PA_LustNormalizeNameText(name)
    end
    return nil
end

local function PA_LustGetGroupChannel()
    local inInstance = IsInInstance and IsInInstance() or false
    return inInstance and "INSTANCE_CHAT" or "PARTY"
end

local function PA_LustSafeSendAddon(message)
    return PA_SafeSendAddonMessage(PA_LUST.PREFIX, message, PA_LustGetGroupChannel())
end

local function PA_LustResolveCooldownSeconds(spellID)
    local id = PA_Num(spellID)
    if id <= 0 then
        return nil
    end
    if GetSpellBaseCooldown then
        local ok, cooldownMs = pcall(GetSpellBaseCooldown, id)
        local cooldownSeconds = ok and (PA_Num(cooldownMs) / 1000) or 0
        if cooldownSeconds > 0 then
            return cooldownSeconds
        end
    end
    return PA_Num(PA_LUST.FALLBACK_COOLDOWNS[id])
end

local function PA_LustClampCommSeconds(value)
    local num = tonumber(value)
    if not PA_LustIsFiniteNumber(num) then
        return nil
    end
    if num < 0 or num > PA_LUST.COMM_MAX_SECONDS then
        return nil
    end
    return num
end

local function PA_LustFormatCommSeconds(value)
    local clamped = PA_LustClampCommSeconds(value)
    if clamped == nil then
        return nil
    end
    return string.format("%.3f", clamped)
end

local function PA_LustGetSelfDirectSpellID(classFile)
    if classFile == "MAGE" then
        return 80353
    end
    if classFile == "SHAMAN" then
        local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
        if faction == "Alliance" then
            return 32182
        end
        return 2825
    end
    if classFile == "EVOKER" then
        return 390386
    end
    return 0
end

function Timers:UpdateLustIcon()
    if not (self.lustRow and self.lustRow.icon) then return end
    local _, class = UnitClass("player")
    local tex = 136012
    if class == "SHAMAN" then
        local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
        if faction == "Alliance" then
            tex = 132313
        else
            tex = 136012
        end
    elseif class == "MAGE" then
        tex = 458224
    elseif class == "HUNTER" then
        tex = 136224
    elseif class == "EVOKER" then
        tex = 4723908
    end
    self.lustRow.icon:SetTexture(tex)
end

function Timers:EnsureLustRuntime()
    self.lustSources = self.lustSources or {}
    self.lustRosterList = self.lustRosterList or {}
    self.lustRosterByName = self.lustRosterByName or {}
    self.lustRosterAliases = self.lustRosterAliases or {}
    self.lustHunterSpecs = self.lustHunterSpecs or {}
    self.lustInspectQueue = self.lustInspectQueue or {}
    self.lustInspectBusy = self.lustInspectBusy or false
    self.lustInspectUnit = self.lustInspectUnit or nil
    self.lustInspectTargetGUID = self.lustInspectTargetGUID or nil
    self.lustInspectTimeoutTimer = self.lustInspectTimeoutTimer or nil
end

local PA_LUST_INSPECT_TIMEOUT = 4.0

function Timers:CancelLustInspectTimeout()
    if self.lustInspectTimeoutTimer then
        self.lustInspectTimeoutTimer:Cancel()
        self.lustInspectTimeoutTimer = nil
    end
end

function Timers:ClearLustInspectState()
    self:CancelLustInspectTimeout()
    if self.lustInspectBusy or self.lustInspectUnit or self.lustInspectTargetGUID then
        pcall(ClearInspectPlayer)
    end
    self.lustInspectBusy = false
    self.lustInspectUnit = nil
    self.lustInspectTargetGUID = nil
end

function Timers:ScheduleLustInspectResume()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    self:ProcessLustInspectQueue()
end

function Timers:ArmLustInspectTimeout(expectedGUID)
    self:CancelLustInspectTimeout()
    self.lustInspectTimeoutTimer = C_Timer.NewTimer(PA_LUST_INSPECT_TIMEOUT, function()
        local activeGUID = IT_NormalizeSafeString(self.lustInspectTargetGUID)
        local targetGUID = IT_NormalizeSafeString(expectedGUID)
        if targetGUID and activeGUID and not IT_SafeStringsEqual(activeGUID, targetGUID) then
            return
        end
        self:ClearLustInspectState()
        self:ScheduleLustInspectResume()
    end)
end

function Timers:EnsureDB()
    MigrateModules2StackToTimers()
    PortalAuthorityDB = PortalAuthorityDB or {}
    PortalAuthorityDB.modules = PortalAuthorityDB.modules or {}
    PortalAuthorityDB.modules.timers = PortalAuthorityDB.modules.timers or {}
    local db = PortalAuthorityDB.modules.timers

    -- Seed Timers DB keys (missing-only; no overwrite of valid stored values).
    if db.x == nil then db.x = 0 end
    if db.y == nil then db.y = 0 end
    if db.locked == nil then db.locked = true end
    if db.brezEnabled == nil then db.brezEnabled = true end
    if db.lustEnabled == nil then db.lustEnabled = true end
    if db.lustSatedEndSound == nil then db.lustSatedEndSound = false end
    if db.healerEnabled == nil then db.healerEnabled = true end
    if db.cooldownSweepEnabled == nil then db.cooldownSweepEnabled = true end
    if db.fontPath == nil then db.fontPath = "" end
    if db.fontSize == nil then db.fontSize = 12 end
    if db.fontFlags == nil then db.fontFlags = "" end
    if db.iconSize == nil then db.iconSize = 18 end
    if db.iconTextSpacing == nil then db.iconTextSpacing = 8 end
    if db.iconOffsetX == nil then db.iconOffsetX = 0 end
    if db.iconOffsetY == nil then db.iconOffsetY = 0 end
    if db.iconAspect == nil then db.iconAspect = "1:1" end
    if db.iconEdgeStyle == nil then db.iconEdgeStyle = ICON_EDGE_STYLE_SHARP end

    db.x = math.floor(tonumber(db.x) or 0)
    db.y = math.floor(tonumber(db.y) or 0)
    db.locked = not not db.locked
    db.fontSize = math.floor(clampNumber(db.fontSize, 12, 8, 48))
    db.iconSize = math.floor(clampNumber(db.iconSize, 18, 12, 64))
    db.iconTextSpacing = math.floor(clampNumber(db.iconTextSpacing, 8, 0, 64))
    db.iconOffsetX = math.floor(clampNumber(db.iconOffsetX, 0, -50, 50))
    db.iconOffsetY = math.floor(clampNumber(db.iconOffsetY, 0, -50, 50))
    db.fontPath = trim(db.fontPath)
    db.fontFlags = trim(db.fontFlags)
    db.iconAspect = trim(db.iconAspect)
    if db.iconAspect == "" then db.iconAspect = "1:1" end
    if db.iconEdgeStyle == "Rounded Corners" then
        db.iconEdgeStyle = ICON_EDGE_STYLE_SHARP
    end
    if db.iconEdgeStyle ~= ICON_EDGE_STYLE_SHARP and db.iconEdgeStyle ~= ICON_EDGE_STYLE_FULL then
        db.iconEdgeStyle = ICON_EDGE_STYLE_SHARP
    end
    db.cooldownSweepEnabled = not not db.cooldownSweepEnabled
    db.lustSatedEndSound = not not db.lustSatedEndSound
    if db.lustActiveEndsAt == nil then db.lustActiveEndsAt = 0 end
    if db.lustSatedEndsAt == nil then db.lustSatedEndsAt = 0 end
    if db.lustNotSatedEndsAt == nil then db.lustNotSatedEndsAt = 0 end
    if db.lustLastCastAt == nil then db.lustLastCastAt = 0 end
    db.lustActiveEndsAt = tonumber(db.lustActiveEndsAt) or 0
    db.lustSatedEndsAt = tonumber(db.lustSatedEndsAt) or 0
    db.lustNotSatedEndsAt = tonumber(db.lustNotSatedEndsAt) or 0
    db.lustLastCastAt = tonumber(db.lustLastCastAt) or 0

    return db
end

function Timers:GetDB()
    return self:EnsureDB()
end

function Timers:IsEnabled()
    local db = self:GetDB()
    return db.enabled ~= false
end

function Timers:ApplyPosition()
    if not self.frame then return end
    local db = self:GetDB()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(db.x) or 0, tonumber(db.y) or 0)
end

function Timers:ResetPositionToCenter()
    local db = self:GetDB()
    db.x = 0
    db.y = 0
    self:ApplyPosition()
    Modules:NotifyPositionChanged(self.key, db.x, db.y)
    if self.EvaluateVisibility then
        self:EvaluateVisibility("reset-anchor")
    elseif self.Tick then
        self:Tick()
    end
end

function Timers:PersistPosition()
    local db = self:GetDB()
    local cx, cy = self.frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then return end
    db.x = math.floor((cx - ux) + 0.5)
    db.y = math.floor((cy - uy) + 0.5)
    Modules:NotifyPositionChanged(self.key, db.x, db.y)
end

function Timers:NotifyDragPosition()
    local cx, cy = self.frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then return end
    Modules:NotifyPositionChanged(self.key, math.floor((cx - ux) + 0.5), math.floor((cy - uy) + 0.5))
end

function Timers:ShouldShowLive()
    -- Match Brez gating behavior/context.
    return BrezTimer:ShouldShowLive()
end

function Timers:GetFont()
    local db = self:GetDB()
    local path = trim(db.fontPath)
    local size = db.fontSize or 12
    local flags = db.fontFlags or ""
    if path == "" and PortalAuthority.GetGlobalFontPath then
        local globalPath, globalFlags = PortalAuthority:GetGlobalFontPath()
        path = globalPath or ""
        if flags == "" then flags = globalFlags or "" end
    end
    if path == "" then
        path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    return path, size, flags
end

function Timers:GetIconDimensions()
    local db = self:GetDB()
    local base = db.iconSize or 18
    local ratio = trim(db.iconAspect)
    local w, h = ratio:match("^(%d+)%s*:%s*(%d+)$")
    w, h = tonumber(w), tonumber(h)
    if not w or not h or h == 0 then
        w, h = 1, 1
    end
    return math.max(1, base * (w / h)), math.max(1, base), db.iconTextSpacing or 8
end

function Timers:ApplyIconStyle()
    local db = self:GetDB()
    local style = db.iconEdgeStyle or ICON_EDGE_STYLE_SHARP

    local function applyToRow(row)
        if not row or not row.icon then return end
        local baseLeft, baseRight, baseTop, baseBottom = 0, 1, 0, 1
        if row.baseTexCoord then
            baseLeft = row.baseTexCoord[1] or 0
            baseRight = row.baseTexCoord[2] or 1
            baseTop = row.baseTexCoord[3] or 0
            baseBottom = row.baseTexCoord[4] or 1
        end

        if style == ICON_EDGE_STYLE_SHARP then
            local insetH = (baseRight - baseLeft) * 0.08
            local insetV = (baseBottom - baseTop) * 0.08
            row.icon:SetTexCoord(baseLeft + insetH, baseRight - insetH, baseTop + insetV, baseBottom - insetV)
        else
            row.icon:SetTexCoord(baseLeft, baseRight, baseTop, baseBottom)
        end

        local usedMask = false
        pcall(row.icon.SetMaskTexture, row.icon, nil)
        if style == ICON_EDGE_STYLE_ROUNDED and row.icon.SetMaskTexture then
            local ok = pcall(row.icon.SetMaskTexture, row.icon, ICON_EDGE_STYLE_MASK)
            usedMask = ok and (not row.icon.GetMaskTexture or row.icon:GetMaskTexture() ~= nil)
        end

        if not row.iconFallbackBG then
            local fallback = CreateFrame("Frame", nil, row, "BackdropTemplate")
            fallback:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -1, 1)
            fallback:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
            fallback:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 8,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            fallback:SetBackdropColor(0, 0, 0, 0.25)
            fallback:SetBackdropBorderColor(0.15, 0.15, 0.15, 0.55)
            fallback:SetFrameLevel(math.max(0, row:GetFrameLevel() - 1))
            row.iconFallbackBG = fallback
        end

        local showFallback = (style == ICON_EDGE_STYLE_ROUNDED and not usedMask)
        row.iconFallbackBG:SetShown(showFallback)
    end

    applyToRow(self.rezRow)
    applyToRow(self.lustRow)
    applyToRow(self.healerRow)
end

function Timers:FindHealerUnit()
    if IsInRaid and IsInRaid() then
        local members = GetNumGroupMembers() or 0
        for i = 1, members do
            local unit = "raid" .. i
            if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "HEALER" then
                return unit
            end
        end
    elseif IsInGroup and IsInGroup() then
        local members = GetNumSubgroupMembers() or 0
        for i = 1, members do
            local unit = "party" .. i
            if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "HEALER" then
                return unit
            end
        end
    end
    if UnitGroupRolesAssigned("player") == "HEALER" then
        return "player"
    end
    return nil
end

local function PA_FindAuraExpirationBySpellID(unit, filter, spellID)
    if AuraUtil and AuraUtil.FindAuraBySpellId then
        local a1, a2, a3, a4, a5, a6 = AuraUtil.FindAuraBySpellId(spellID, unit, filter)
        if type(a1) == "table" then
            return PA_Num(a1.expirationTime)
        end
        if type(a1) == "string" and a1 ~= "" then
            return PA_Num(a6)
        end
        return 0
    end

    if UnitAura then
        for i = 1, 255 do
            local name, _, _, _, _, expirationTime, _, _, _, auraSpellID = UnitAura(unit, i, filter)
            if not name then break end
            if auraSpellID == spellID then
                return PA_Num(expirationTime)
            end
        end
    end

    return 0
end

local function PA_HasAuraBySpellID(unit, filter, spellID)
    if not unit or not spellID then return false end

    if unit == "player" and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        if ok and aura ~= nil then return true end
    end

    if AuraUtil and AuraUtil.FindAuraBySpellId then
        local ok, aura = pcall(AuraUtil.FindAuraBySpellId, spellID, unit, filter)
        if ok and aura ~= nil then return true end
    end

    return false
end

function Timers:BuildLustRoster()
    self:EnsureLustRuntime()
    local rosterList = {}
    local rosterByName = {}
    local rosterAliases = {}

    local function addAlias(fullName)
        local shortName = PA_LustNormalizeShortName(fullName)
        if not shortName or shortName == fullName then
            return
        end
        if rosterAliases[shortName] == nil then
            rosterAliases[shortName] = fullName
        else
            rosterAliases[shortName] = false
        end
    end

    local function addUnit(unit, isSelf)
        if not (unit and UnitExists(unit)) then
            return
        end
        local name = PA_LustSafeUnitName(unit)
        local classFile = PA_LustSafeUnitClass(unit)
        if not name or not classFile or rosterByName[name] then
            return
        end
        local petUnit = nil
        if isSelf then
            petUnit = "pet"
        else
            local partyIndex = tostring(unit):match("^party(%d+)$")
            if partyIndex then
                petUnit = "partypet" .. partyIndex
            end
        end
        local entry = {
            name = name,
            unit = unit,
            petUnit = petUnit,
            class = classFile,
            isSelf = isSelf and true or false,
        }
        rosterList[#rosterList + 1] = entry
        rosterByName[name] = entry
        addAlias(name)
    end

    addUnit("player", true)
    for i = 1, 4 do
        addUnit("party" .. i, false)
    end

    self.lustRosterList = rosterList
    self.lustRosterByName = rosterByName
    self.lustRosterAliases = rosterAliases
    return rosterList, rosterByName, rosterAliases
end

function Timers:ResolveLustRosterName(rawName)
    local normalized = PA_LustNormalizeNameText(rawName)
    if not normalized then
        return nil
    end
    self:BuildLustRoster()
    if self.lustRosterByName[normalized] then
        return normalized
    end
    local shortName = PA_LustNormalizeShortName(normalized)
    local resolved = shortName and self.lustRosterAliases[shortName] or nil
    if resolved and self.lustRosterByName[resolved] then
        return resolved
    end
    return nil
end

function Timers:GetLustSource(name, classFile)
    if not name then
        return nil
    end
    self:EnsureLustRuntime()
    local source = self.lustSources[name]
    if not source then
        source = {
            name = name,
            class = classFile,
            spellID = 0,
            readyAt = 0,
            castAt = 0,
            hasAddon = false,
            specID = 0,
            lastSeenAt = 0,
        }
        self.lustSources[name] = source
    elseif classFile and classFile ~= "" then
        source.class = classFile
    end
    return source
end

function Timers:ClearLustSourceReadiness(name, clearAddonFlag)
    if not name then
        return
    end
    local source = self.lustSources and self.lustSources[name] or nil
    if not source then
        return
    end
    source.spellID = 0
    source.readyAt = 0
    source.castAt = 0
    source.lastSeenAt = PA_ServerNow()
    if clearAddonFlag then
        source.hasAddon = false
    end
end

function Timers:RefreshHunterSpecState(name, specID, clearUnknown)
    if not name then
        return
    end
    local normalizedSpecID = PA_Num(specID)
    if normalizedSpecID > 0 then
        self.lustHunterSpecs[name] = normalizedSpecID
    else
        self.lustHunterSpecs[name] = nil
    end

    local source = self.lustSources and self.lustSources[name] or nil
    if not source or source.class ~= "HUNTER" then
        return
    end
    source.specID = normalizedSpecID

    local spellID = PA_Num(source.spellID)
    if spellID <= 0 then
        return
    end
    if spellID == 466904 and normalizedSpecID ~= PA_LUST.SPEC_MARKSMANSHIP then
        self:ClearLustSourceReadiness(name, false)
    elseif spellID == 264667 and normalizedSpecID == PA_LUST.SPEC_MARKSMANSHIP then
        self:ClearLustSourceReadiness(name, false)
    elseif clearUnknown and normalizedSpecID <= 0 and (spellID == 466904 or spellID == 264667) then
        self:ClearLustSourceReadiness(name, false)
    end
end

function Timers:HandleLustHunterPetChanged(ownerUnit)
    if not ownerUnit then
        return
    end
    self:BuildLustRoster()
    local ownerName = PA_LustSafeUnitName(ownerUnit)
    local entry = ownerName and self.lustRosterByName and self.lustRosterByName[ownerName] or nil
    if not entry or entry.class ~= "HUNTER" then
        return
    end

    local source = self.lustSources and self.lustSources[ownerName] or nil
    if source and PA_Num(source.spellID) == 264667 then
        self:ClearLustSourceReadiness(ownerName, true)
        if entry.isSelf then
            self:BroadcastSelfLustState(PA_LUST.COMM_STATE)
        end
    end
end

function Timers:CleanupLustRosterState()
    self:EnsureLustRuntime()
    self:BuildLustRoster()
    local current = self.lustRosterByName or {}

    for name in pairs(self.lustSources or {}) do
        if not current[name] then
            self.lustSources[name] = nil
        end
    end
    for name in pairs(self.lustHunterSpecs or {}) do
        if not current[name] then
            self.lustHunterSpecs[name] = nil
        end
    end

    if self.lustInspectQueue and #self.lustInspectQueue > 0 then
        local nextQueue = {}
        for _, unit in ipairs(self.lustInspectQueue) do
            local queuedName = UnitExists(unit) and PA_LustSafeUnitName(unit) or nil
            local rosterEntry = queuedName and current[queuedName] or nil
            if rosterEntry and rosterEntry.class == "HUNTER" and rosterEntry.unit == unit then
                nextQueue[#nextQueue + 1] = unit
            end
        end
        self.lustInspectQueue = nextQueue
    end

    if self.lustInspectUnit then
        local inspectName = UnitExists(self.lustInspectUnit) and PA_LustSafeUnitName(self.lustInspectUnit) or nil
        local rosterEntry = inspectName and current[inspectName] or nil
        if not rosterEntry or rosterEntry.unit ~= self.lustInspectUnit then
            self:ClearLustInspectState()
        end
    end
end

function Timers:ProcessLustInspectQueue()
    self:EnsureLustRuntime()
    self:BuildLustRoster()
    if self.lustInspectBusy then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    while #self.lustInspectQueue > 0 do
        local unit = table.remove(self.lustInspectQueue, 1)
        if UnitExists(unit) and UnitIsConnected(unit) then
            local name = PA_LustSafeUnitName(unit)
            local guid = IT_SafeUnitGUID(unit)
            local rosterEntry = name and self.lustRosterByName and self.lustRosterByName[name] or nil
            if rosterEntry and rosterEntry.class == "HUNTER" and not rosterEntry.isSelf and PA_Num(self.lustHunterSpecs[name]) <= 0 and PA_CanSafelyInspectUnit(unit) then
                self.lustInspectBusy = true
                self.lustInspectUnit = unit
                self.lustInspectTargetGUID = guid
                local ok = pcall(NotifyInspect, unit)
                if ok then
                    self:ArmLustInspectTimeout(guid)
                    return
                end
                self:ClearLustInspectState()
            end
        end
    end
end

function Timers:QueueLustHunterInspect(targetUnit)
    self:EnsureLustRuntime()
    self:BuildLustRoster()

    local function queueUnit(unit)
        if not (unit and unit ~= "player" and UnitExists(unit)) then
            return
        end
        local name = PA_LustSafeUnitName(unit)
        local rosterEntry = name and self.lustRosterByName and self.lustRosterByName[name] or nil
        if not rosterEntry or rosterEntry.class ~= "HUNTER" or rosterEntry.isSelf or PA_Num(self.lustHunterSpecs[name]) > 0 then
            return
        end
        if self.lustInspectUnit == unit then
            return
        end
        for _, queuedUnit in ipairs(self.lustInspectQueue or {}) do
            if queuedUnit == unit then
                return
            end
        end
        self.lustInspectQueue[#self.lustInspectQueue + 1] = unit
    end

    if targetUnit then
        queueUnit(targetUnit)
    else
        for _, entry in ipairs(self.lustRosterList or {}) do
            if entry.class == "HUNTER" and not entry.isSelf then
                queueUnit(entry.unit)
            end
        end
    end

    self:ProcessLustInspectQueue()
end

function Timers:HandleLustInspectReady(inspectedGUID)
    if not self.lustInspectBusy or not self.lustInspectUnit then
        return
    end
    local activeGUID = IT_NormalizeSafeString(self.lustInspectTargetGUID)
    local readyGUID = IT_NormalizeSafeString(inspectedGUID)
    if activeGUID and (not readyGUID or not IT_SafeStringsEqual(activeGUID, readyGUID)) then
        return
    end
    self:BuildLustRoster()
    local unit = self.lustInspectUnit
    local name = UnitExists(unit) and PA_LustSafeUnitName(unit) or nil
    local rosterEntry = name and self.lustRosterByName and self.lustRosterByName[name] or nil
    if rosterEntry and rosterEntry.class == "HUNTER" and not rosterEntry.isSelf then
        local specID = GetInspectSpecialization and GetInspectSpecialization(unit) or 0
        specID = PA_Num(specID)
        self:GetLustSource(name, rosterEntry.class)
        self:RefreshHunterSpecState(name, specID, false)
    end
    self:ClearLustInspectState()
    self:ScheduleLustInspectResume()
end

function Timers:GetHunterSpecIDForEntry(entry)
    if not entry or entry.class ~= "HUNTER" then
        return 0
    end
    if entry.isSelf then
        local specIndex = GetSpecialization and GetSpecialization() or nil
        return PA_Num(specIndex and GetSpecializationInfo(specIndex) or 0)
    end
    local source = self.lustSources and self.lustSources[entry.name] or nil
    local specID = PA_Num(source and source.specID)
    if specID > 0 then
        return specID
    end
    return PA_Num(self.lustHunterSpecs and self.lustHunterSpecs[entry.name] or 0)
end

function Timers:GetPlayerAuraBySpellIDs(spellIDs, filter, lookup)
    for _, spellID in ipairs(type(spellIDs) == "table" and spellIDs or {}) do
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
            if ok and type(aura) == "table" then
                return aura, spellID
            end
        end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 255 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
            if not ok or aura == nil then
                break
            end
            local auraSpellID = PA_Num(aura.spellId or aura.spellID)
            if auraSpellID > 0 and lookup and lookup[auraSpellID] then
                return aura, auraSpellID
            end
        end
    end
    return nil, 0
end

function Timers:GetLocalLustAuraState()
    local activeAura = self:GetPlayerAuraBySpellIDs(PA_LUST.BUFFS, "HELPFUL", PA_LUST.SUPPORTED_SPELLS)
    local satedAura = self:GetPlayerAuraBySpellIDs(PA_LUST.EXHAUST_DEBUFFS, "HARMFUL", PA_LUST.EXHAUST_LOOKUP)
    local activeExpiration = PA_Num(activeAura and activeAura.expirationTime)
    local satedExpiration = PA_Num(satedAura and satedAura.expirationTime)
    local now = PA_Num(GetTime())
    local activeRemaining = activeExpiration > 0 and math.max(0, activeExpiration - now) or 0
    local satedRemaining = satedExpiration > 0 and math.max(0, satedExpiration - now) or 0
    return activeRemaining, satedRemaining
end

function Timers:ClearLustAudioState()
    self.lustWasSated = false
    self.lustSatedEndArmed = false
    self.lustSoundMonitoringActive = false
end

function Timers:SeedLustSatedEndAudioState()
    local _, satedRemaining = self:GetLocalLustAuraState()
    self.lustWasSated = satedRemaining > 0
    self.lustSatedEndArmed = true
    self.lustSoundMonitoringActive = true
end

function Timers:RefreshLustSoundArming()
    local db = self:GetDB()
    local monitoringEnabled = self:IsEnabled() and (not not db.lustEnabled) and (not not db.lustSatedEndSound) and (not Modules.timersTestMode)
    if monitoringEnabled then
        if not self.lustSoundMonitoringActive then
            self:SeedLustSatedEndAudioState()
        end
    else
        self:ClearLustAudioState()
    end
end

function Timers:RefreshLocalLustAuraState(skipAudio)
    local activeRemaining, satedRemaining = self:GetLocalLustAuraState()
    self.lustLocalActiveRemaining = activeRemaining
    self.lustLocalSatedRemaining = satedRemaining

    self:RefreshLustSoundArming()

    if not skipAudio and self.lustSoundMonitoringActive and self.lustSatedEndArmed and self.lustWasSated and satedRemaining <= 0 then
        local isConnected = UnitIsConnected and UnitIsConnected("player")
        local isDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
        if isConnected and not isDead and PlaySoundFile then
            pcall(PlaySoundFile, PA_LUST.AUDIO_PATH, "Master")
        end
    end

    if self.lustSoundMonitoringActive then
        self.lustWasSated = satedRemaining > 0
    end

    return activeRemaining, satedRemaining
end

function Timers:GetSelfLustCommState()
    self:BuildLustRoster()
    local playerName = PA_LustSafeUnitName("player")
    local rosterEntry = playerName and self.lustRosterByName and self.lustRosterByName[playerName] or nil
    local classFile = rosterEntry and rosterEntry.class or PA_LustSafeUnitClass("player")
    if not playerName or not classFile then
        return nil, nil
    end

    local source = self:GetLustSource(playerName, classFile)
    local spellID = PA_Num(source and source.spellID)
    local remaining = math.max(0, PA_Num(source and source.readyAt) - PA_ServerNow())

    if classFile == "MAGE" or classFile == "SHAMAN" or classFile == "EVOKER" then
        if spellID <= 0 then
            spellID = PA_LustGetSelfDirectSpellID(classFile)
        end
        if spellID > 0 then
            return spellID, remaining
        end
    elseif classFile == "HUNTER" then
        if spellID > 0 then
            return spellID, remaining
        end
        local specID = self:GetHunterSpecIDForEntry(rosterEntry)
        if specID == PA_LUST.SPEC_MARKSMANSHIP then
            return 466904, 0
        end
    end

    return nil, nil
end

function Timers:BroadcastSelfLustState(command, spellID, seconds)
    local db = self:GetDB()
    if not db.lustEnabled or not (IsInGroup and IsInGroup()) then
        return
    end

    local message = nil
    if command == PA_LUST.COMM_CAST then
        local sendSpellID = PA_Num(spellID)
        local cooldownSeconds = PA_LustFormatCommSeconds(seconds)
        if sendSpellID <= 0 or not cooldownSeconds then
            return
        end
        message = string.format("%s:%d:%s", PA_LUST.COMM_CAST, sendSpellID, cooldownSeconds)
    else
        local stateSpellID, remainingSeconds = self:GetSelfLustCommState()
        local formatted = PA_LustFormatCommSeconds(remainingSeconds or 0)
        if not stateSpellID or not formatted then
            return
        end
        message = string.format("%s:%d:%s", PA_LUST.COMM_STATE, stateSpellID, formatted)
    end

    PA_LustSafeSendAddon(message)
end

function Timers:RequestLustStateSync()
    local db = self:GetDB()
    if not db.lustEnabled or not (IsInGroup and IsInGroup()) then
        return
    end
    PA_LustSafeSendAddon(PA_LUST.COMM_REQ)
end

function Timers:UpdateLustSourceFromObservedCast(entry, spellID)
    if not entry or not entry.name then
        return
    end
    local cooldownSeconds = PA_LustResolveCooldownSeconds(spellID)
    if not cooldownSeconds or cooldownSeconds <= 0 then
        return
    end
    local source = self:GetLustSource(entry.name, entry.class)
    if not source then
        return
    end
    if source.hasAddon and not entry.isSelf then
        return
    end

    local now = PA_ServerNow()
    source.class = entry.class
    source.spellID = PA_Num(spellID)
    source.castAt = now
    source.readyAt = now + cooldownSeconds
    source.lastSeenAt = now
    if entry.class == "HUNTER" and PA_Num(spellID) == 466904 then
        source.specID = PA_LUST.SPEC_MARKSMANSHIP
        self.lustHunterSpecs[entry.name] = PA_LUST.SPEC_MARKSMANSHIP
    end
end

function Timers:ApplyRemoteLustState(senderName, spellID, remainingSeconds, isCast)
    self:BuildLustRoster()
    local resolvedName = self:ResolveLustRosterName(senderName)
    local rosterEntry = resolvedName and self.lustRosterByName and self.lustRosterByName[resolvedName] or nil
    if not rosterEntry then
        return
    end

    local source = self:GetLustSource(resolvedName, rosterEntry.class)
    local seconds = PA_LustClampCommSeconds(remainingSeconds)
    local resolvedSpellID = PA_Num(spellID)
    if not source or seconds == nil or resolvedSpellID <= 0 or not PA_LUST.SUPPORTED_SPELLS[resolvedSpellID] then
        return
    end

    local now = PA_ServerNow()
    source.class = rosterEntry.class
    source.spellID = resolvedSpellID
    source.readyAt = now + seconds
    source.lastSeenAt = now
    source.hasAddon = true
    if isCast then
        source.castAt = now
    elseif source.castAt <= 0 and seconds > 0 then
        local fullCooldown = PA_LustResolveCooldownSeconds(resolvedSpellID)
        if fullCooldown and fullCooldown >= seconds then
            source.castAt = now - (fullCooldown - seconds)
        end
    end
    if rosterEntry.class == "HUNTER" and resolvedSpellID == 466904 then
        source.specID = PA_LUST.SPEC_MARKSMANSHIP
        self.lustHunterSpecs[resolvedName] = PA_LUST.SPEC_MARKSMANSHIP
    end
end

function Timers:GetLustSourceState(entry, now)
    if not entry or not entry.name or not entry.class then
        return false, false, nil, 0
    end

    local source = self:GetLustSource(entry.name, entry.class)
    local spellID = PA_Num(source and source.spellID)
    local readyAt = PA_Num(source and source.readyAt)

    if entry.class == "MAGE" or entry.class == "SHAMAN" or entry.class == "EVOKER" then
        if readyAt > now then
            return true, false, readyAt - now, spellID
        end
        if spellID <= 0 and entry.isSelf then
            spellID = PA_LustGetSelfDirectSpellID(entry.class)
        end
        return true, true, 0, spellID
    end

    if entry.class == "HUNTER" then
        local specID = self:GetHunterSpecIDForEntry(entry)
        if spellID > 0 then
            if readyAt > now then
                return true, false, readyAt - now, spellID
            end
            return true, true, 0, spellID
        end
        if specID == PA_LUST.SPEC_MARKSMANSHIP then
            return true, true, 0, 466904
        end
    end

    return false, false, nil, 0
end

function Timers:GetLustState()
    local activeRemaining, satedRemaining = self:RefreshLocalLustAuraState()
    if activeRemaining > 0 then
        return "active", activeRemaining, PA_LUST.ACTIVE_SECONDS
    end
    if satedRemaining > 0 then
        return "sated", satedRemaining, PA_LUST.SATED_SECONDS
    end

    self:BuildLustRoster()
    local now = PA_ServerNow()
    local anySupported = false
    local anyReady = false
    local nextRemaining = nil
    local nextDuration = 0

    for _, entry in ipairs(self.lustRosterList or {}) do
        local supported, ready, remaining, spellID = self:GetLustSourceState(entry, now)
        if supported then
            anySupported = true
        end
        if supported and ready then
            anyReady = true
        elseif supported and remaining and remaining > 0 then
            if not nextRemaining or remaining < nextRemaining then
                nextRemaining = remaining
                nextDuration = PA_LustResolveCooldownSeconds(spellID) or remaining
            end
        end
    end

    if anyReady then
        return "ready", 0, 0
    end
    if nextRemaining and nextRemaining > 0 then
        return "next", nextRemaining, nextDuration
    end
    if anySupported then
        return "ready", 0, 0
    end
    return "hidden", 0, 0
end

function Timers:GetLustEntryForObservedUnit(unit)
    if not unit then
        return nil
    end
    self:BuildLustRoster()
    if unit == "player" or unit == "pet" then
        local playerName = PA_LustSafeUnitName("player")
        return playerName and self.lustRosterByName and self.lustRosterByName[playerName] or nil
    end
    local partyIndex = tostring(unit):match("^party(%d+)$") or tostring(unit):match("^partypet(%d+)$")
    if partyIndex then
        local ownerUnit = "party" .. partyIndex
        local ownerName = PA_LustSafeUnitName(ownerUnit)
        return ownerName and self.lustRosterByName and self.lustRosterByName[ownerName] or nil
    end
    return nil
end

function Timers:HandleObservedLustCast(unit, spellID)
    local resolvedSpellID = PA_Num(spellID)
    if resolvedSpellID <= 0 or not PA_LUST.SUPPORTED_SPELLS[resolvedSpellID] then
        return false
    end

    local entry = self:GetLustEntryForObservedUnit(unit)
    if not entry then
        return false
    end

    self:UpdateLustSourceFromObservedCast(entry, resolvedSpellID)
    if entry.isSelf then
        local cooldownSeconds = PA_LustResolveCooldownSeconds(resolvedSpellID)
        if cooldownSeconds and cooldownSeconds > 0 then
            self:BroadcastSelfLustState(PA_LUST.COMM_CAST, resolvedSpellID, cooldownSeconds)
        end
    end
    return true
end

function Timers:HandleLustAddonMessage(message, sender)
    local prefix = PA_LustNormalizeNameText(message)
    if not prefix then
        return false
    end
    if prefix == PA_LUST.COMM_REQ then
        self:BroadcastSelfLustState(PA_LUST.COMM_STATE)
        return true
    end

    local command, spellText, valueText = prefix:match("^([^:]+):([^:]+):([^:]+)$")
    if command ~= PA_LUST.COMM_STATE and command ~= PA_LUST.COMM_CAST then
        return false
    end
    local spellID = PA_Num(spellText)
    local value = PA_LustClampCommSeconds(valueText)
    if spellID <= 0 or not PA_LUST.SUPPORTED_SPELLS[spellID] or value == nil then
        return false
    end

    local senderName = self:ResolveLustRosterName(sender)
    if not senderName then
        return false
    end
    self:ApplyRemoteLustState(senderName, spellID, value, command == PA_LUST.COMM_CAST)
    return true
end

function Timers:RefreshLustContextState(sendSync)
    self:CleanupLustRosterState()
    self:QueueLustHunterInspect()
    if sendSync then
        self:BroadcastSelfLustState(PA_LUST.COMM_STATE)
        self:RequestLustStateSync()
    end
end

function Timers:FormatMMSS(remaining)
    remaining = math.max(0, tonumber(remaining) or 0)
    local mm = math.floor(remaining / 60)
    local ss = math.floor(remaining % 60)
    return string.format("%02d:%02d", mm, ss)
end

function Timers:ShouldKeepTickerActive(testing, brezRemaining, lustMode, lustRemaining)
    if testing or self.unlocked then
        return true
    end
    if PA_Num(brezRemaining) > 0 then
        return true
    end
    if PA_Num(lustRemaining) > 0 and (lustMode == "active" or lustMode == "sated" or lustMode == "next") then
        return true
    end
    return false
end

function Timers:Tick()
    PA_CpuDiagCount("timers_tick")
    local perfStart, perfState = PA_PerfBegin("timers_tick")
    local function finish(...)
        PA_PerfEnd("timers_tick", perfStart, perfState)
        return ...
    end

    if PA_IsUiSurfaceGateEnabled() then
        if self.frame then
            PA_CpuDiagApplyVisibility("timers", self.frame, false)
        end
        self:StopTicker()
        return finish(false)
    end

    local db = self:GetDB()
    if not self:IsEnabled() then
        if self.rezRow then self.rezRow:Hide() end
        if self.lustRow then self.lustRow:Hide() end
        if self.healerRow then self.healerRow:Hide() end
        PA_CpuDiagApplyVisibility("timers", self.frame, false)
        self:StopTicker()
        self:ClearLustAudioState()
        return finish(false)
    end
    local testing = Modules.timersTestMode
    local brezLiveEnabled = BrezTimer:IsMythicKeystoneActive()
    local brezRowShown = not not db.brezEnabled and (testing or self.unlocked or brezLiveEnabled)
    local lustRowShown = not not db.lustEnabled
    local healerRowShown = not not db.healerEnabled
    local lustRowVisible = false
    local brezRemainingForTicker = 0
    local lustModeForTicker = nil
    local lustRemainingForTicker = 0

    if not brezRowShown then self.rezRow:Hide() end
    if not lustRowShown then self.lustRow:Hide() end
    if not healerRowShown then
        self.healerRow:Hide()
        self.healerRow.baseTexCoord = { 0, 1, 0, 1 }
        self.healerUnit = nil
    end

    local shouldShow = self:ShouldShowLive() or testing or self.unlocked
    if not shouldShow then
        PA_CpuDiagApplyVisibility("timers", self.frame, false)
        return finish(false)
    end

    self:ApplyFonts()
    local iconWidth, iconHeight, spacing = self:GetIconDimensions()
    local db = self:GetDB()
    local iconOffsetX = db.iconOffsetX or 0
    local iconOffsetY = db.iconOffsetY or 0

    local rowPad = 2
    local y = -rowPad
    local maxW = 180
    local totalH = 0

    local showAny = false
    local sweepEnabled = not not db.cooldownSweepEnabled

    if self.rezRow and self.rezRow.cooldown and not sweepEnabled then
        self.rezRow.cooldown:Hide()
        self.rezRow._cdEndAt = nil
        self.rezRow._cdActive = false
        self.rezRow._cdMode = nil
    end
    if self.lustRow and self.lustRow.cooldown and not sweepEnabled then
        self.lustRow.cooldown:Hide()
        self.lustRow._cdEndAt = nil
        self.lustRow._cdActive = false
        self.lustRow._cdMode = nil
    end
    if self.healerRow and self.healerRow.cooldown then
        self.healerRow.cooldown:Hide()
        self.healerRow._cdActive = false
        self.healerRow._cdMode = nil
    end

    if brezRowShown then
        local charges = 1
        local remaining = 10
        if testing then
            if not self._testBrezEndAt or self._testBrezEndAt <= GetTime() then
                self._testBrezEndAt = GetTime() + 10
            end
            remaining = math.max(0, PA_Num(self._testBrezEndAt - GetTime()))
        else
            local state = BrezTimer:GetAuthoritativeState()
            charges = math.max(0, math.floor(PA_Num(state.charges)))
            remaining = PA_Num(state.remaining)
        end
        brezRemainingForTicker = PA_Num(remaining)
        self.rezLabel:SetText("Res: |cff33ff33" .. tostring(charges) .. "|r")
        self.rezLabel:SetTextColor(1, 1, 1, 1)
        if PA_Num(remaining) > 0 then
            self.rezCharges:SetText(self:FormatMMSS(remaining))
        else
            self.rezCharges:SetText("")
        end
        local rem = PA_Num(remaining)
        if self.rezRow and self.rezRow.cooldown then
            if sweepEnabled and rem > 0 then
                local endAt = GetTime() + rem
                if (self.rezRow._cdEndAt == nil) or math.abs(endAt - self.rezRow._cdEndAt) > 0.25 then
                    self.rezRow.cooldown:SetCooldown(GetTime(), rem)
                    self.rezRow.cooldown:Show()
                    self.rezRow._cdEndAt = endAt
                    self.rezRow._cdActive = true
                    self.rezRow._cdMode = "brez"
                end
            else
                self.rezRow.cooldown:Hide()
                self.rezRow._cdEndAt = nil
                self.rezRow._cdActive = false
                self.rezRow._cdMode = nil
            end
        end
        self.rezRow.baseTexCoord = { 0, 1, 0, 1 }
        self.rezRow:Show()
        showAny = true
    end

    if lustRowShown then
        local mode, remaining, sweepDuration = "next", 180, 300
        if not testing then
            mode, remaining, sweepDuration = self:GetLustState()
        end
        lustModeForTicker = mode
        lustRemainingForTicker = PA_Num(remaining)

        if mode == "hidden" then
            if self.lustRow.cooldown then
                self.lustRow.cooldown:Hide()
            end
            self.lustRow._cdEndAt = nil
            self.lustRow._cdActive = false
            self.lustRow._cdMode = nil
            self.lustRow:Hide()
        else
            if mode == "active" then
                self.lustLabel:SetText("")
                self.lustValue:SetText(self:FormatMMSS(remaining))
                self.lustValue:SetTextColor(1, 0.2, 0.2, 1)
            elseif mode == "sated" then
                self.lustLabel:SetText("Sated")
                self.lustLabel:SetTextColor(1, 1, 1, 1)
                self.lustValue:SetText(self:FormatMMSS(remaining))
                self.lustValue:SetTextColor(1, 0.2, 0.2, 1)
            elseif mode == "next" then
                self.lustLabel:SetText("Next Lust")
                self.lustLabel:SetTextColor(1, 0.82, 0, 1)
                self.lustValue:SetText(self:FormatMMSS(remaining))
                self.lustValue:SetTextColor(1, 0.82, 0, 1)
            else
                self.lustLabel:SetText("")
                self.lustValue:SetText("Ready")
                self.lustValue:SetTextColor(0.2, 1.0, 0.2, 1)
            end

            local rem = PA_Num(remaining)
            local shouldShowSweep = sweepEnabled and self.lustRow.cooldown and rem > 0 and (mode == "active" or mode == "sated" or mode == "next")
            if shouldShowSweep then
                local dur = PA_Num(sweepDuration)
                if mode == "active" then
                    dur = PA_LUST.ACTIVE_SECONDS
                elseif mode == "sated" then
                    dur = PA_LUST.SATED_SECONDS
                end
                if dur <= 0 then
                    dur = rem
                end
                local endAt = GetTime() + rem
                if (not self.lustRow._cdActive) or (self.lustRow._cdMode ~= mode) or (self.lustRow._cdEndAt == nil) or math.abs(endAt - self.lustRow._cdEndAt) > 0.25 then
                    local start = GetTime() - math.max(0, dur - rem)
                    self.lustRow.cooldown:SetCooldown(start, dur)
                    self.lustRow.cooldown:Show()
                    self.lustRow._cdEndAt = endAt
                    self.lustRow._cdActive = true
                    self.lustRow._cdMode = mode
                end
            else
                if self.lustRow.cooldown then
                    self.lustRow.cooldown:Hide()
                end
                self.lustRow._cdEndAt = nil
                self.lustRow._cdActive = false
                self.lustRow._cdMode = nil
            end
            self.lustRow.baseTexCoord = { 0, 1, 0, 1 }
            self.lustRow:Show()
            lustRowVisible = true
            showAny = true
        end
    end

    if healerRowShown then
        if testing then
            local shamanColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS.SHAMAN
            if shamanColor then
                self.healerName:SetTextColor(shamanColor.r, shamanColor.g, shamanColor.b, 1)
            else
                self.healerName:SetTextColor(0.0, 0.44, 0.87, 1)
            end
            self.healerName:SetText("Shiftus")
            self.healerMana:SetText("OK")
            self.healerMana:SetTextColor(0.2, 1.0, 0.2, 1)
            self.healerIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            if CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.SHAMAN then
                local coords = CLASS_ICON_TCOORDS.SHAMAN
                self.healerIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                self.healerRow.baseTexCoord = { coords[1], coords[2], coords[3], coords[4] }
            else
                self.healerRow.baseTexCoord = { 0, 1, 0, 1 }
            end
            self.healerRow:Show()
            showAny = true
            self.healerUnit = nil
        else
            local unit = self:FindHealerUnit()
            if unit and UnitExists(unit) then
            local name = UnitName(unit)
            local _, class = UnitClass(unit)
            local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if color then
                self.healerName:SetTextColor(color.r, color.g, color.b, 1)
            else
                self.healerName:SetTextColor(1, 1, 1, 1)
            end
            self.healerName:SetText(name or "Healer")
            local statusText = "OK"
            local r, g, b = 0.2, 1.0, 0.2
            local isOffline = UnitIsConnected and not UnitIsConnected(unit)
            local isDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
            if isOffline then
                statusText = "OFFLINE"
                r, g, b = 1, 0.2, 0.2
            elseif isDead then
                statusText = "DEAD"
                r, g, b = 1, 0.2, 0.2
            else
                local inInst = false
                if IsInInstance then
                    inInst = select(1, IsInInstance())
                end
                if inInst and UnitIsVisible then
                    local okV, vis = pcall(UnitIsVisible, unit)
                    if okV and vis == false then
                        statusText = "OUTSIDE"
                        r, g, b = 1.0, 0.82, 0.0
                    end
                end
            end
            self.healerMana:SetText(statusText)
            self.healerMana:SetTextColor(r, g, b, 1)
            local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
            if coords then
                self.healerIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                self.healerIcon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
                self.healerRow.baseTexCoord = { coords[1], coords[2], coords[3], coords[4] }
            else
                self.healerRow.baseTexCoord = { 0, 1, 0, 1 }
            end
            self.healerRow:Show()
            showAny = true
            self.healerUnit = unit
            else
                self.healerUnit = nil
                local unlockedPreview = self.unlocked
                if unlockedPreview then
                    local shamanColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS.SHAMAN
                    if shamanColor then
                        self.healerName:SetTextColor(shamanColor.r, shamanColor.g, shamanColor.b, 1)
                    else
                        self.healerName:SetTextColor(0.0, 0.44, 0.87, 1)
                    end
                    self.healerName:SetText("Shiftus")
                    self.healerMana:SetText("OK")
                    self.healerMana:SetTextColor(0.2, 1.0, 0.2, 1)

                    local shamanCoords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS.SHAMAN
                    if shamanCoords then
                        self.healerIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
                        self.healerIcon:SetTexCoord(shamanCoords[1], shamanCoords[2], shamanCoords[3], shamanCoords[4])
                        self.healerRow.baseTexCoord = { shamanCoords[1], shamanCoords[2], shamanCoords[3], shamanCoords[4] }
                    else
                        self.healerIcon:SetTexture("Interface\\ICONS\\INV_Misc_QuestionMark")
                        self.healerIcon:SetTexCoord(0, 1, 0, 1)
                        self.healerRow.baseTexCoord = { 0, 1, 0, 1 }
                    end

                    self.healerRow:Show()
                    showAny = true
                else
                    self.healerRow:Hide()
                end
            end
        end
    end

    self:ApplyIconStyle()

    local function layoutRow(row, primary, secondary)
        row.icon:SetSize(iconWidth, iconHeight)
        row.primary:ClearAllPoints()
        row.primary:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", spacing + iconOffsetX, iconOffsetY)
        row.secondary:ClearAllPoints()
        row.secondary:SetPoint("TOPLEFT", row.primary, "BOTTOMLEFT", 0, -2)

        row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, y)
        local rowH = math.max(iconHeight, (primary:GetStringHeight() or 14) + (secondary:GetStringHeight() or 14) + 2)
        local rowW = iconWidth + math.max(0, spacing + iconOffsetX) + math.max(primary:GetStringWidth() or 0, secondary:GetStringWidth() or 0)
        if rowW > maxW then maxW = rowW end
        row:SetSize(rowW, rowH)
        y = y - rowH - rowPad
        totalH = totalH + rowH + rowPad
    end

    if brezRowShown then layoutRow(self.rezRow, self.rezLabel, self.rezCharges) end
    if lustRowVisible then layoutRow(self.lustRow, self.lustLabel, self.lustValue) end
    if healerRowShown then layoutRow(self.healerRow, self.healerName, self.healerMana) end

    self.frame:SetSize(math.max(120, maxW + 4), math.max(20, totalH + 2))
    self:SetUnlocked(not self:GetDB().locked)
    PA_CpuDiagApplyVisibility("timers", self.frame, showAny or self.unlocked)
    return finish(self:ShouldKeepTickerActive(testing, brezRemainingForTicker, lustModeForTicker, lustRemainingForTicker))
end

function Timers:ApplyFonts()
    local path, size, flags = self:GetFont()
    local size1 = tonumber(size) or 12
    local size2 = size1 + 2
    self.rezLabel:SetFont(path, size1, flags)
    self.rezCharges:SetFont(path, size2, flags)
    self.lustLabel:SetFont(path, size1, flags)
    self.lustValue:SetFont(path, size2, flags)
    self.healerName:SetFont(path, size1, flags)
    self.healerMana:SetFont(path, size2, flags)

    local iconWidth, iconHeight = self:GetIconDimensions()
    self.rezRow.icon:SetSize(iconWidth, iconHeight)
    self.lustRow.icon:SetSize(iconWidth, iconHeight)
    self.healerRow.icon:SetSize(iconWidth, iconHeight)
    self:ApplyIconStyle()
end

function Timers:StartTicker()
    if self.ticker then return end
    self.ticker = C_Timer.NewTicker(0.25, function()
        if self:Tick() == false then
            self:StopTicker()
        end
    end)
end

function Timers:StopTicker()
    if self.ticker then self.ticker:Cancel() self.ticker = nil end
end

function Timers:EvaluateVisibility()
    PA_CpuDiagCount("timers_evaluate_visibility")
    local perfStart, perfState = PA_PerfBegin("timers_evaluate_visibility")
    if PA_IsUiSurfaceGateEnabled() then
        if self.frame then
            PA_CpuDiagApplyVisibility("timers", self.frame, false)
        end
        self:StopTicker()
        PA_PerfEnd("timers_evaluate_visibility", perfStart, perfState)
        return
    end
    if not self.frame then
        PA_PerfEnd("timers_evaluate_visibility", perfStart, perfState)
        return
    end
    if not self:IsEnabled() then
        PA_CpuDiagApplyVisibility("timers", self.frame, false)
        self:StopTicker()
        self:ClearLustAudioState()
        PA_PerfEnd("timers_evaluate_visibility", perfStart, perfState)
        return
    end
    local shouldShow = self:ShouldShowLive() or Modules.timersTestMode or self.unlocked
    if shouldShow then
        PA_CpuDiagApplyVisibility("timers", self.frame, true)
        self:ApplyFonts()
        local keepTicker = self:Tick()
        if keepTicker then
            self:StartTicker()
        else
            self:StopTicker()
        end
    else
        PA_CpuDiagApplyVisibility("timers", self.frame, false)
        self:StopTicker()
    end
    PA_PerfEnd("timers_evaluate_visibility", perfStart, perfState)
end

function Timers:SetUnlocked(unlocked)
    local wasUnlocked = self.unlocked and true or false
    self.unlocked = not not unlocked
    local db = self:GetDB()
    db.locked = not self.unlocked
    local effectiveUnlocked = self.unlocked and self:IsEnabled()
    local wasEffectiveUnlocked = wasUnlocked and self:IsEnabled()
    if self.dragHandle then
        self.dragHandle:SetShown(effectiveUnlocked)
        self.dragHandle:EnableMouse(effectiveUnlocked)
    end
    if wasEffectiveUnlocked ~= effectiveUnlocked and PortalAuthority and PortalAuthority.UpdateMoveHintTickerState then
        PortalAuthority:UpdateMoveHintTickerState()
    end
end

function Timers:ApplySettings()
    if not self.frame then return end
    self:RefreshLustSoundArming()
    self:ApplyPosition()
    self:ApplyFonts()
    self:EvaluateVisibility()
    if Modules.timersTestMode and PA_CpuDiagIsFrameConsideredShown("timers", self.frame) then
        self:Tick()
    end
end

function Timers:Initialize()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if self.frame then return end
    self:EnsureDB()
    self:EnsureLustRuntime()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(180, 70)
    frame:SetMovable(true)
    frame:SetClampedToScreen(false)
    frame:SetUserPlaced(false)
    frame:EnableMouse(false)

    local function buildRow(texture)
        local row = CreateFrame("Frame", nil, frame)
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        icon:SetSize(18, 18)
        icon:SetTexture(texture)
        local primary = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        primary:SetJustifyH("LEFT")
        local secondary = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        secondary:SetJustifyH("LEFT")
        primary:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 0)
        secondary:SetPoint("TOPLEFT", primary, "BOTTOMLEFT", 0, -2)
        local cd = CreateFrame("Cooldown", nil, row, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        cd:Hide()
        row.icon, row.primary, row.secondary = icon, primary, secondary
        row.cooldown = cd
        row._cdEndAt = nil
        row._cdActive = false
        row._cdMode = nil
        return row
    end

    self.rezRow = buildRow(136080)
    self.rezLabel = self.rezRow.primary
    self.rezCharges = self.rezRow.secondary
    self.rezLabel:SetTextColor(1, 1, 1, 1)
    self.rezLabel:SetShadowOffset(1, -1)
    self.rezCharges:SetTextColor(1, 1, 1, 1)

    self.lustRow = buildRow(136012)
    self.lustLabel = self.lustRow.primary
    self.lustValue = self.lustRow.secondary
    self.lustLabel:SetTextColor(1, 1, 1, 1)
    self.lustLabel:SetShadowOffset(1, -1)
    self:UpdateLustIcon()

    self.healerRow = buildRow(136243)
    self.healerIcon = self.healerRow.icon
    self.healerName = self.healerRow.primary
    self.healerMana = self.healerRow.secondary

    local handle = CreateFrame("Button", nil, frame, "BackdropTemplate")
    handle:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 3)
    handle:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 3)
    handle:SetHeight(16)
    handle:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    handle:SetBackdropColor(0.0, 1.0, 0.0, 0.85)
    handle:SetBackdropBorderColor(0.0, 0.25, 0.0, 1.0)
    local glyph = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    glyph:SetPoint("CENTER", handle, "CENTER", 0, 0)
    glyph:SetText("GRAB")
    glyph:SetTextColor(0, 0, 0, 1)
    handle:EnableMouse(false)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not self.unlocked or InCombatLockdown() then return end
        frame:StartMoving()
        if not self._dragTicker then
            self._dragTicker = C_Timer.NewTicker(0.1, function() self:NotifyDragPosition() end)
        end
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        if self._dragTicker then self._dragTicker:Cancel() self._dragTicker = nil end
        self:PersistPosition()
    end)

    self.frame = frame
    self.dragHandle = handle
    self:SetUnlocked(not self:GetDB().locked)
    self:RefreshLustContextState(false)
    self:RefreshLocalLustAuraState(true)
    self:ApplyPosition()
    self:ApplySettings()

end

function Timers:OnEvent(event, arg1, arg2, arg3, arg4)
    if event == "CHALLENGE_MODE_START" then
        self.lustSources = {}
        self:RefreshLustContextState(true)
        self:EvaluateVisibility()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
        self:RefreshLustContextState(true)
        self:RefreshLocalLustAuraState(true)
        self:EvaluateVisibility()
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = arg1
        if unit == "player" then
            local playerName = PA_LustSafeUnitName("player")
            local playerClass = PA_LustSafeUnitClass("player")
            if playerName and playerClass then
                self:GetLustSource(playerName, playerClass)
                local specID = (playerClass == "HUNTER") and self:GetHunterSpecIDForEntry({
                    name = playerName,
                    class = playerClass,
                    isSelf = true,
                }) or 0
                self:RefreshHunterSpecState(playerName, specID, false)
            end
            self:BroadcastSelfLustState(PA_LUST.COMM_STATE)
        elseif unit and tostring(unit):match("^party%d+$") then
            local partyName = PA_LustSafeUnitName(unit)
            if partyName then
                self:RefreshHunterSpecState(partyName, 0, true)
                self:QueueLustHunterInspect(unit)
            end
        end
        self:EvaluateVisibility()
        return
    end

    if event == "INSPECT_READY" then
        self:HandleLustInspectReady(arg1)
        self:EvaluateVisibility()
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        self:CleanupLustRosterState()
        self:ProcessLustInspectQueue()
        self:EvaluateVisibility()
        return
    end

    if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        local prefix, msg, _, sender = arg1, arg2, arg3, arg4
        if prefix == PA_LUST.PREFIX and self:HandleLustAddonMessage(msg, sender) then
            self:EvaluateVisibility()
        end
        return
    end

    if event == "UNIT_AURA" and arg1 == "player" then
        self:RefreshLocalLustAuraState()
        self:EvaluateVisibility()
        return
    end

    if event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        self:RefreshLocalLustAuraState(true)
        self:EvaluateVisibility()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if self:HandleObservedLustCast(arg1, arg3) then
            self:EvaluateVisibility()
            return
        end
    end

    if event == "UNIT_PET" and (arg1 == "player" or tostring(arg1 or ""):match("^party%d+$")) then
        self:HandleLustHunterPetChanged(arg1)
        self:RefreshLustContextState(false)
        self:EvaluateVisibility()
        return
    end

    if event == "UNIT_POWER_UPDATE" and self.healerUnit and arg1 ~= self.healerUnit then return end
    self:EvaluateVisibility()
end

Modules:Register(Timers)

end

do

local PA_INTERRUPT_PREFIX = "PAInterrupt"
local IT_DISPLAY_TICK = 0.033
local IT_READY_THRESHOLD = 0.5
local IT_SORT_SNAP = 0.1
local IT_PREVIEW_MODEB_SORT_SNAP = 0.5
local IT_PREVIEW_MODEB_REORDER_THRESHOLD = 0.0
local IT_PREVIEW_MODEB_MIN_COOLDOWN_GAP = 1.5
local IT_PREVIEW_MODEB_PHASE_SPACING_MIN = 2.5
local IT_PREVIEW_MODEB_PHASE_SPACING_MAX = 4.5
local IT_ACTIVITY_CONFIRM_WINDOW = 30.0
local IT_OFFLINE_GRACE_WINDOW = 5.0
local IT_HELLO_THROTTLE = 3.0
local IT_INSPECT_STEP_DELAY = 0.5
local IT_QUEUE_INSPECT_DELAY = 1.0
local IT_INSPECT_TIMEOUT = 4.0
local IT_PERIODIC_INSPECT = 30.0
local IT_OWN_PET_RETRY_1 = 0.5
local IT_OWN_PET_RETRY_2 = 1.5
local IT_OWN_PET_RETRY_3 = 3.0
local IT_WARLOCK_SPELLS_RETRY_1 = 1.5
local IT_WARLOCK_SPELLS_RETRY_2 = 3.0
local IT_RECENT_CAST_KEEP = 1.0
local IT_OBSERVED_CAST_COALESCE_WINDOW = 1.0
local IT_FALLBACK_CONFIRM_MAX_DELTA = 1.5
local IT_PRIMARY_TARGET_CONFIRM_MAX_DELTA = 0.5
local IT_INTERRUPT_COUNT_DEDUPE_WINDOW = 1.5
local IT_MOB_INTERRUPT_DUPLICATE_WINDOW = 0.05
local IT_FULL_WIPE_WINDOW = 8.0
local IT_FULL_WIPE_RECOVERY_GRACE = 15.0
local IT_FULL_WIPE_COMBAT_RECENCY = 12.0
local IT_ICON_GLOW_DURATION = 0.45
local IT_ICON_GLOW_ALPHA = 1.00
local IT_ICON_GLOW_PAD = 28
local IT_PREVIEW_READY_HOLD = 0.6
local IT_PREVIEW_MODEB_READY_HOLD = 3.25
local IT_BAR_ACCENT_WIDTH = 6
local IT_BAR_ACCENT_ALPHA = 0.24
local IT_BAR_ACCENT_PULSE_ALPHA = 0.38
local IT_CLASS_ICON_TEXCOORD_INSET_X = 4 / 256
local IT_CLASS_ICON_TEXCOORD_INSET_TOP = 6 / 256
local IT_CLASS_ICON_TEXCOORD_INSET_BOTTOM = 4 / 256
local IT_ICON_SEPARATOR_THICKNESS = 2
local IT_ICON_SEPARATOR_VERTICAL_INSET = 1
local IT_ADDON_SEPARATOR = { 111 / 255, 174 / 255, 107 / 255, 1.0 }
local IT_FALLBACK_SEPARATOR = { 242 / 255, 201 / 255, 76 / 255, 1.0 }
local IT_ROW_GAP_DEFAULT = 4
local IT_ROW_GAP_MIN = 0
local IT_ROW_GAP_MAX = 32
local IT_SPACING_ARM = {
    ARM_LENGTH = 110,
    ARM_THICKNESS = 2,
    ARM_HIT_THICKNESS = 16,
    CENTER_SIZE = 8,
    DRAG_PIXELS_PER_STEP = 8,
    SHIFT_DRAG_MULT = 1.8,
    ALT_DRAG_MULT = 0.5,
    WHEEL_BASE_STEP = 2,
    WHEEL_SHIFT_STEP = 1,
    WHEEL_ALT_STEP = 4,
    CURSOR_Y = "Interface\\CURSOR\\UI-Cursor-SizeRight",
    CURSOR_GENERIC = "Interface\\CURSOR\\UI-Cursor-Move",
    TOOLTIP_DEBOUNCE = 0.10,
    UNLOCK_HINT_HOLD = 2.7,
    UNLOCK_HINT_FADE = 0.3,
    UNLOCK_HINT_FAST_FADE = 0.2,
    BOUNDARY_PULSE_AMPLITUDE = 3,
    BOUNDARY_PULSE_OUT_DURATION = 0.08,
    BOUNDARY_PULSE_IN_DURATION = 0.08,
    OFFSET_X = 18,
}
local IT_DEBUG_SOLAR_BEAM_CONFIRM = false
local IT_DEBUG_SOLAR_BEAM_REMOTE = false
local IT_DEBUG_SOLAR_BEAM_SEND = false
local IT_PREVIEW_MODEB_WINDOW_SIZE = 5
local IT_PREVIEW_MODEB_ROTATION_CYCLES = 2

local IT_PREVIEW_MODEB_POOL = {
    { name = "Yetw", class = "WARRIOR", specID = 72, specName = "Fury" },
    { name = "Artyrka", class = "MAGE", specID = 63, specName = "Fire" },
    { name = "Camp", class = "DRUID", specID = 104, specName = "Bear" },
    { name = "Shiftus", class = "SHAMAN", specID = 264, specName = "Restoration" },
    { name = "Goof", class = "WARRIOR", specID = 72, specName = "Fury" },
    { name = "Slynkz", class = "WARLOCK", specID = 267, specName = "Destruction" },
    { name = "Sittinbull", class = "SHAMAN", specID = 263, specName = "Enhancement" },
    { name = "Itzjay", class = "HUNTER", specID = 255, specName = "Survival" },
    { name = "Oleg", class = "PALADIN", specID = 65, specName = "Holy", previewUseClassIcon = true },
    { name = "Smz", class = "WARLOCK", specID = 267, specName = "Destruction" },
    { name = "Lucuris", class = "PRIEST", specID = 256, specName = "Discipline" },
    { name = "Gendisarray", class = "PALADIN", specID = 66, specName = "Protection" },
    { name = "Adaenp", class = "PALADIN", specID = 66, specName = "Protection" },
    { name = "Babyhoof", class = "DRUID", specID = 104, specName = "Bear" },
    { name = "Morrey", class = "MAGE", specID = 62, specName = "Arcane" },
    { name = "Toughclassf", class = "MAGE", specID = 63, specName = "Fire" },
    { name = "Deneroc", class = "DEATHKNIGHT", specID = 251, specName = "Frost" },
    { name = "Mainmise", class = "WARLOCK", specID = 265, specName = "Affliction" },
    { name = "Deva", class = "WARLOCK", specID = 266, specName = "Demonology" },
}

local IT_NEUTRAL_BAR = { 0.23, 0.56, 0.88, 0.92 }
local IT_BG_BAR = { 0.09, 0.10, 0.13, 0.88 }
local IT_ROW_BORDER = { 0.18, 0.21, 0.25, 0.70 }
local IT_MUTED_TEXT = { 0.72, 0.74, 0.78, 0.96 }
local IT_UNAVAILABLE_BAR = { 0.28, 0.29, 0.31, 0.94 }
local IT_UNAVAILABLE_BG = { 0.11, 0.12, 0.14, 0.92 }
local IT_UNAVAILABLE_TEXT = { 0.60, 0.62, 0.66, 0.98 }
local IT_AVAILABILITY_VISUALS = {
    staleBg = { 0.10, 0.11, 0.14, 0.90 },
    staleText = { 0.76, 0.78, 0.83, 0.98 },
    deadBar = { 0.46, 0.28, 0.28, 0.92 },
    deadBg = { 0.15, 0.09, 0.10, 0.92 },
    deadText = { 0.82, 0.70, 0.70, 0.98 },
    staleIconAlpha = 0.86,
    deadIconAlpha = 0.78,
    unavailableIconAlpha = 0.62,
    staleBarBlend = 0.42,
}

local IT_CLASS_COLORS = {
    WARRIOR     = { 0.78, 0.61, 0.43 },
    ROGUE       = { 1.00, 0.96, 0.41 },
    MAGE        = { 0.41, 0.80, 0.94 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    DRUID       = { 1.00, 0.49, 0.04 },
    DEATHKNIGHT = { 0.77, 0.12, 0.23 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    DEMONHUNTER = { 0.64, 0.19, 0.79 },
    MONK        = { 0.00, 1.00, 0.59 },
    PRIEST      = { 1.00, 1.00, 1.00 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    WARLOCK     = { 0.58, 0.51, 0.79 },
    EVOKER      = { 0.20, 0.58, 0.50 },
}

local function IT_GetConfiguredRowBackgroundOpacity(db)
    return clampNumber(db and db.backgroundOpacity, IT_BG_BAR[4], 0, 1)
end

local function IT_GetConfiguredRowGap(db)
    return math.floor(clampNumber(db and db.rowGap, IT_ROW_GAP_DEFAULT, IT_ROW_GAP_MIN, IT_ROW_GAP_MAX))
end

local function IT_ApplyClassIconTexture(texture, classFile)
    if not texture or not classFile or not CLASS_ICON_TCOORDS or not CLASS_ICON_TCOORDS[classFile] then
        return false
    end
    local coords = CLASS_ICON_TCOORDS[classFile]
    texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
    texture:SetTexCoord(
        coords[1] + IT_CLASS_ICON_TEXCOORD_INSET_X,
        coords[2] - IT_CLASS_ICON_TEXCOORD_INSET_X,
        coords[3] + IT_CLASS_ICON_TEXCOORD_INSET_TOP,
        coords[4] - IT_CLASS_ICON_TEXCOORD_INSET_BOTTOM
    )
    return true
end

local function IT_GetPreviewHash(text, salt)
    text = tostring(text or "")
    salt = tostring(salt or "")
    text = text .. "|" .. salt
    if text == "" then
        return 0
    end
    local hash = 5381
    for i = 1, #text do
        hash = ((hash * 33) + string.byte(text, i)) % 2147483647
    end
    return hash
end

local function IT_GetPreviewWindowAuthorityMap(rows, windowKey)
    local ranked = {}
    for index, row in ipairs(rows or {}) do
        local nameKey = tostring((row and row.name) or ("preview" .. index))
        ranked[#ranked + 1] = {
            nameKey = nameKey,
            score = IT_GetPreviewHash(nameKey, windowKey),
        }
    end
    table.sort(ranked, function(a, b)
        if a.score ~= b.score then
            return a.score < b.score
        end
        return a.nameKey < b.nameKey
    end)

    local count = #ranked
    local map = {}
    if count == 0 then
        return map
    end
    if count == 1 then
        map[ranked[1].nameKey] = true
        return map
    end

    local addonCount = math.floor(count / 2)
    if (IT_GetPreviewHash(windowKey, count) % 2) == 0 then
        addonCount = math.min(count - 1, addonCount + 1)
    end
    addonCount = math.max(1, math.min(count - 1, addonCount))

    for index, entry in ipairs(ranked) do
        map[entry.nameKey] = index <= addonCount
    end
    return map
end

local IT_INTERRUPTS = {
    [6552]    = { name = "Pummel", cd = 15, icon = 132938 },
    [1766]    = { name = "Kick", cd = 15, icon = 132219 },
    [2139]    = { name = "Counterspell", cd = 25, icon = 135856 },
    [57994]   = { name = "Wind Shear", cd = 12, icon = 136018 },
    [106839]  = { name = "Skull Bash", cd = 15, icon = 236946 },
    [78675]   = { name = "Solar Beam", cd = 60, icon = 252188 },
    [47528]   = { name = "Mind Freeze", cd = 15, icon = 237527 },
    [96231]   = { name = "Rebuke", cd = 15, icon = 523893 },
    [183752]  = { name = "Disrupt", cd = 15, icon = 1305153 },
    [116705]  = { name = "Spear Hand Strike", cd = 15, icon = 608940 },
    [15487]   = { name = "Silence", cd = 30, icon = 458230 },
    [147362]  = { name = "Counter Shot", cd = 24, icon = 249170 },
    [187707]  = { name = "Muzzle", cd = 15, icon = 1376045 },
    [19647]   = { name = "Spell Lock", cd = 24, icon = 136174 },
    [132409]  = { name = "Spell Lock", cd = 24, icon = 136174 },
    [119914]  = { name = "Axe Toss", cd = 30, iconSpellID = 89766, icon = 236316 },
    [1276467] = { name = "Fel Ravager", cd = 25, iconSpellID = 132409, icon = 136217 },
    [351338]  = { name = "Quell", cd = 20, icon = 4622469 },
}

local IT_INTERRUPTS_STR = {}
for spellID, data in pairs(IT_INTERRUPTS) do
    IT_INTERRUPTS_STR[tostring(spellID)] = data
end

local IT_CLASS_INTERRUPT_LIST = {
    WARRIOR     = { 6552 },
    ROGUE       = { 1766 },
    MAGE        = { 2139 },
    SHAMAN      = { 57994 },
    DRUID       = { 106839, 78675 },
    DEATHKNIGHT = { 47528 },
    PALADIN     = { 96231 },
    DEMONHUNTER = { 183752 },
    MONK        = { 116705 },
    PRIEST      = { 15487 },
    HUNTER      = { 147362, 187707 },
    WARLOCK     = { 19647, 132409, 119914 },
    EVOKER      = { 351338 },
}

local IT_CLASS_PRIMARY = {
    WARRIOR     = { id = 6552, cd = 15, name = "Pummel" },
    ROGUE       = { id = 1766, cd = 15, name = "Kick" },
    MAGE        = { id = 2139, cd = 25, name = "Counterspell" },
    SHAMAN      = { id = 57994, cd = 12, name = "Wind Shear" },
    DRUID       = { id = 106839, cd = 15, name = "Skull Bash" },
    DEATHKNIGHT = { id = 47528, cd = 15, name = "Mind Freeze" },
    PALADIN     = { id = 96231, cd = 15, name = "Rebuke" },
    DEMONHUNTER = { id = 183752, cd = 15, name = "Disrupt" },
    MONK        = { id = 116705, cd = 15, name = "Spear Hand Strike" },
    PRIEST      = { id = 15487, cd = 30, name = "Silence" },
    HUNTER      = { id = 147362, cd = 24, name = "Counter Shot" },
    WARLOCK     = { id = 19647, cd = 24, name = "Spell Lock" },
    EVOKER      = { id = 351338, cd = 20, name = "Quell" },
}

local IT_SPEC_OVERRIDE = {
    [102] = { id = 78675, cd = 60, name = "Solar Beam" },
    [255] = { id = 187707, cd = 15, name = "Muzzle" },
    [264] = { id = 57994, cd = 12, name = "Wind Shear" },
    [266] = { id = 119914, cd = 30, name = "Axe Toss", isPet = true, petSpellID = 89766, requiredFamily = "Felguard" },
}

local IT_SPEC_NO_INTERRUPT = {
    [65]  = true,
    [105] = true,
    [256] = true,
    [257] = true,
    [270] = true,
    [1468] = true,
}

local IT_PERMANENT_CD_TALENTS = {
    [391271] = { affects = 6552, pctReduction = 10, name = "Honed Reflexes" },
    [382297] = { affects = 2139, reduction = 5, name = "Quick Witted" },
}

local IT_ON_SUCCESS_TALENTS = {
    [378848] = { reduction = 3, name = "Coldthirst" },
}

local IT_OWNER_CONFIRMED_TALENTS = {
    [202918] = { affects = 78675, reduction = 15, kind = "light_of_the_sun", name = "Light of the Sun" },
    [378848] = { affects = 47528, reduction = 3, kind = "coldthirst", name = "Coldthirst" },
}

local IT_PERMANENT_CD_TALENTS_STR = {}
local IT_ON_SUCCESS_TALENTS_STR = {}
local IT_OWNER_CONFIRMED_TALENTS_STR = {}
for talentID, data in pairs(IT_PERMANENT_CD_TALENTS) do
    IT_PERMANENT_CD_TALENTS_STR[tostring(talentID)] = data
end
for talentID, data in pairs(IT_ON_SUCCESS_TALENTS) do
    IT_ON_SUCCESS_TALENTS_STR[tostring(talentID)] = data
end
for talentID, data in pairs(IT_OWNER_CONFIRMED_TALENTS) do
    IT_OWNER_CONFIRMED_TALENTS_STR[tostring(talentID)] = data
end

local IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS = {
    [47528] = true,
    [78675] = true,
}

local IT_SPEC_EXTRA_KICKS = {
    [266] = {
        { id = 132409, cd = 24, name = "Spell Lock", iconSpellID = 132409, icon = "Interface\\Icons\\spell_shadow_summonfelhunter", talentCheck = 1276467 },
    },
}

local IT_SPEC_EXTRA_KICKS_STR = {}
local IT_SPEC_EXTRA_KICKS_BY_TALENT = {}
local IT_SPEC_EXTRA_KICKS_BY_TALENT_STR = {}
for specID, extraList in pairs(IT_SPEC_EXTRA_KICKS) do
    IT_SPEC_EXTRA_KICKS_STR[tostring(specID)] = extraList
    for _, extra in ipairs(extraList) do
        if extra.talentCheck ~= nil then
            IT_SPEC_EXTRA_KICKS_BY_TALENT[extra.talentCheck] = IT_SPEC_EXTRA_KICKS_BY_TALENT[extra.talentCheck] or {}
            IT_SPEC_EXTRA_KICKS_BY_TALENT[extra.talentCheck][#IT_SPEC_EXTRA_KICKS_BY_TALENT[extra.talentCheck] + 1] = {
                specID = specID,
                extra = extra,
            }
        end
    end
end
for talentID, extraList in pairs(IT_SPEC_EXTRA_KICKS_BY_TALENT) do
    IT_SPEC_EXTRA_KICKS_BY_TALENT_STR[tostring(talentID)] = extraList
end

local IT_SPELL_ALIASES = {
    [1276467] = 132409,
    [132409] = 19647,
}

local IT_HEALER_KEEPS_KICK = {
    SHAMAN = true,
}

local interruptPartyFrames = {}
local interruptPartyPetFrames = {}
local interruptPartyFallbackFrame = CreateFrame("Frame")
for i = 1, 4 do
    interruptPartyFrames[i] = CreateFrame("Frame")
    interruptPartyPetFrames[i] = CreateFrame("Frame")
end

local function IT_SafeToString(value)
    local ok, result = pcall(tostring, value)
    if ok and type(result) == "string" then
        return result
    end
    return nil
end

local function IT_TrySecretLookup(tbl, mirror, key)
    if type(tbl) ~= "table" then
        return nil
    end
    local ok, value = pcall(function()
        return tbl[key]
    end)
    if ok and value ~= nil then
        return value
    end
    local keyStr = IT_SafeToString(key)
    if keyStr and type(mirror) == "table" then
        return mirror[keyStr]
    end
    return nil
end

local function IT_GetSpecExtraKicks(specID)
    local extraList = IT_TrySecretLookup(IT_SPEC_EXTRA_KICKS, IT_SPEC_EXTRA_KICKS_STR, specID)
    if type(extraList) == "table" then
        return extraList
    end
    return nil
end

local function IT_GetExtraKicksForTalent(talentID)
    local extraList = IT_TrySecretLookup(IT_SPEC_EXTRA_KICKS_BY_TALENT, IT_SPEC_EXTRA_KICKS_BY_TALENT_STR, talentID)
    if type(extraList) == "table" then
        return extraList
    end
    return nil
end

local function IT_NormalizeName(name)
    if not IT_IsUsablePlainString(name) then
        return nil
    end
    local ok, shortName = pcall(Ambiguate, name, "short")
    local text = ok and shortName or name
    if not IT_IsUsablePlainString(text) then
        return nil
    end
    text = trim(text)
    if text == "" then
        return nil
    end
    return text
end

local function IT_NormalizeNameList(names)
    local normalized = {}
    local seen = {}
    for _, rawName in ipairs(type(names) == "table" and names or {}) do
        local name = IT_NormalizeName(rawName)
        if name and not seen[name] then
            normalized[#normalized + 1] = name
            seen[name] = true
        end
    end
    return normalized
end

local function IT_SerializeNameList(names)
    return table.concat(IT_NormalizeNameList(names), ",")
end

local function IT_SafeUnitClass(unit)
    local ok, _, classFile = pcall(UnitClass, unit)
    if ok then
        return classFile
    end
    return nil
end

local function IT_SafeUnitName(unit)
    local ok, name = pcall(UnitName, unit)
    if ok and not IT_HasSecretValues(name) then
        return IT_NormalizeName(name)
    end
    return nil
end

IT_SafeUnitGUID = function(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and IT_IsUsablePlainString(guid) then
        return guid
    end
    return nil
end

local function IT_IsHostileAttackableUnit(unit)
    if not unit or not UnitExists(unit) or not UnitCanAttack then
        return false
    end
    local ok, canAttack = pcall(UnitCanAttack, "player", unit)
    return ok and canAttack and true or false
end

local function IT_SafeSpellTexture(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellTexture then
        return nil
    end
    local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
    if ok and texture then
        return texture
    end
    return nil
end

local function IT_SafeBaseCooldown(spellID)
    if not spellID then
        return nil
    end
    local ok, ms = pcall(GetSpellBaseCooldown, spellID)
    if ok and ms and tonumber(ms) and tonumber(ms) > 0 then
        return tonumber(ms) / 1000
    end
    return nil
end

local function IT_SafeRegisterPrefix(prefix)
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        pcall(C_ChatInfo.RegisterAddonMessagePrefix, prefix)
    end
end

local function IT_SafeSendAddon(prefix, message, channel)
    return PA_SafeSendAddonMessage(prefix, message, channel)
end

local function IT_GetMediaTexturePath(value)
    local media = PortalAuthority and PortalAuthority.Media
    if media and media.GetChoices then
        local choices = media.GetChoices("statusbar", { includeCurrent = value })
        for _, choice in ipairs(choices or {}) do
            if tostring(choice.value or "") == tostring(value or "") and trim(tostring(choice.path or "")) ~= "" then
                return choice.path
            end
        end
    end
    return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function IT_GetAlertSoundChoice(value)
    local media = PortalAuthority and PortalAuthority.Media
    if media and media.ResolveSoundFile then
        local resolved = media.ResolveSoundFile(value)
        if resolved then
            return "file", resolved
        end
    end
    if type(value) == "number" then
        return "kit", value
    end
    local asNum = tonumber(value)
    if asNum then
        return "kit", asNum
    end
    return nil, nil
end

local function IT_GetSpecName(specID)
    if not specID or specID <= 0 or not GetSpecializationInfoByID then
        return nil
    end
    local ok, _, specName = pcall(GetSpecializationInfoByID, specID)
    if ok and type(specName) == "string" and specName ~= "" then
        return specName
    end
    return nil
end

local function IT_GetClassColor(classFile)
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if color then
        return color.r, color.g, color.b
    end
    local fallback = IT_CLASS_COLORS[classFile]
    if fallback then
        return fallback[1], fallback[2], fallback[3]
    end
    return IT_NEUTRAL_BAR[1], IT_NEUTRAL_BAR[2], IT_NEUTRAL_BAR[3]
end

local function IT_GetLocalizedClassName(classFile)
    if type(classFile) ~= "string" or classFile == "" then
        return nil
    end
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile])
        or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classFile])
        or classFile
end

local function IT_CopyColor(color)
    return {
        r = clampNumber(color and color.r, 1, 0, 1),
        g = clampNumber(color and color.g, 1, 0, 1),
        b = clampNumber(color and color.b, 1, 0, 1),
        a = clampNumber(color and color.a, 1, 0, 1),
    }
end

local function IT_GetGroupChannel()
    local inInstance = IsInInstance and IsInInstance() or false
    return inInstance and "INSTANCE_CHAT" or "PARTY"
end

local function IT_IsSupportedDungeon()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" then
        return false
    end
    local _, _, _, _, maxPlayers = GetInstanceInfo()
    if maxPlayers and tonumber(maxPlayers) and tonumber(maxPlayers) > 5 then
        return false
    end
    return true
end

local function IT_GetContextKey()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or instanceType ~= "party" then
        return nil
    end
    local instanceName, _, difficultyID, _, maxPlayers, _, _, mapID = GetInstanceInfo()
    return table.concat({
        tostring(mapID or 0),
        tostring(difficultyID or 0),
        tostring(maxPlayers or 0),
        tostring(instanceName or ""),
    }, ":")
end

local function IT_FormatCooldown(remaining)
    remaining = math.max(0, tonumber(remaining) or 0)
    if remaining < 10 then
        return string.format("%.1f", remaining)
    end
    if remaining < 60 then
        return string.format("%.0f", remaining)
    end
    local minutes = math.floor(remaining / 60)
    local seconds = math.floor(remaining % 60)
    return string.format("%d:%02d", minutes, seconds)
end

local function IT_IsReady(cdEnd, now)
    return ((tonumber(cdEnd) or 0) - now) <= IT_READY_THRESHOLD
end

local function IT_IsUnitRealDeadOrGhost(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    local isDead = (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) and true or false
    if not isDead then
        return false
    end

    -- Hunters using Feign Death should not be treated like a real unavailable death state.
    if UnitIsFeignDeath and UnitIsFeignDeath(unit) then
        return false
    end

    return true
end

local function IT_SnapRemaining(value)
    local remaining = math.max(0, tonumber(value) or 0)
    return math.floor((remaining / IT_SORT_SNAP) + 0.5) * IT_SORT_SNAP
end

local function IT_SnapPreviewModeBRemaining(value)
    local remaining = math.max(0, tonumber(value) or 0)
    return math.floor((remaining / IT_PREVIEW_MODEB_SORT_SNAP) + 0.5) * IT_PREVIEW_MODEB_SORT_SNAP
end

local function IT_ApplyPreviewModeBCooldownGap(rows, now)
    if type(rows) ~= "table" or #rows < 2 then
        return rows
    end

    local coolingRows = {}
    for _, row in ipairs(rows) do
        if row and not row.previewReady then
            coolingRows[#coolingRows + 1] = row
        end
    end

    if #coolingRows < 2 then
        return rows
    end

    table.sort(coolingRows, function(a, b)
        local aRemaining = math.max(0, tonumber(a.previewRemaining) or 0)
        local bRemaining = math.max(0, tonumber(b.previewRemaining) or 0)
        if aRemaining ~= bRemaining then
            return aRemaining < bRemaining
        end
        return (tonumber(a.previewModeBSortIndex) or 999) < (tonumber(b.previewModeBSortIndex) or 999)
    end)

    local previousRemaining = nil
    for _, row in ipairs(coolingRows) do
        local remaining = math.max(0, tonumber(row.previewRemaining) or 0)
        local baseCd = math.max(1, tonumber(row.baseCd) or 15)
        if previousRemaining ~= nil then
            remaining = math.max(remaining, previousRemaining + IT_PREVIEW_MODEB_MIN_COOLDOWN_GAP)
        end
        remaining = math.min(baseCd, remaining)

        row.previewRemaining = remaining
        row.previewModeBSortRemaining = IT_SnapPreviewModeBRemaining(remaining)
        row.cdEnd = now + remaining
        previousRemaining = remaining
    end

    return rows
end

local function IT_GetPrimaryIcon(spellID)
    local data = spellID and IT_INTERRUPTS[spellID]
    if not data then
        return 134400
    end
    if data.iconSpellID then
        return IT_SafeSpellTexture(data.iconSpellID) or data.icon or 134400
    end
    return data.icon or 134400
end

local function IT_GetExtraKickIcon(extra)
    if not extra then
        return 134400
    end
    if extra.iconSpellID then
        return IT_SafeSpellTexture(extra.iconSpellID) or extra.icon or IT_GetPrimaryIcon(extra.id)
    end
    return extra.icon or IT_GetPrimaryIcon(extra.id)
end

local function IT_GetRowUseGlowTarget(row, member, db)
    if not row or not member or not db then
        return nil
    end
    if db.showSpellIcon and member.spellID and row.spellIcon and row.spellIcon:IsShown() then
        return row.spellIcon
    end
    if db.showClassIcon and member.class and row.classIcon and row.classIcon:IsShown() then
        return row.classIcon
    end
    return nil
end

local function IT_PositionRowUseGlow(row, target)
    local glow = row and row.spellIconGlow
    if not glow then
        return
    end
    if not target or not target.IsShown or not target:IsShown() then
        if glow.anim and glow.anim:IsPlaying() then
            glow.anim:Stop()
        end
        glow:SetAlpha(0)
        glow:Hide()
        return
    end

    local width = math.max(16, tonumber(target:GetWidth()) or 0)
    local height = math.max(16, tonumber(target:GetHeight()) or 0)
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", target, "CENTER", 0, 0)
    glow:SetSize(width + IT_ICON_GLOW_PAD, height + IT_ICON_GLOW_PAD)
    glow:Show()
end

local IT_DYNAMIC_RENDER = {
    EPSILON = 0.001,
}

function IT_DYNAMIC_RENDER.NearlyEqual(left, right)
    return math.abs((tonumber(left) or 0) - (tonumber(right) or 0)) <= IT_DYNAMIC_RENDER.EPSILON
end

function IT_DYNAMIC_RENDER.SetTextIfChanged(fontString, state, key, value)
    local nextValue = tostring(value or "")
    if state[key] ~= nextValue then
        fontString:SetText(nextValue)
        state[key] = nextValue
    end
end

function IT_DYNAMIC_RENDER.SetShownIfChanged(region, state, key, shown)
    local nextValue = shown and true or false
    if state[key] ~= nextValue then
        if nextValue then
            region:Show()
        else
            region:Hide()
        end
        state[key] = nextValue
    end
end

function IT_DYNAMIC_RENDER.SetAlphaIfChanged(region, state, key, value)
    if not IT_DYNAMIC_RENDER.NearlyEqual(state[key], value) then
        region:SetAlpha(value)
        state[key] = value
    end
end

function IT_DYNAMIC_RENDER.SetDesaturatedIfChanged(texture, state, key, value)
    local nextValue = value and true or false
    if state[key] ~= nextValue then
        texture:SetDesaturated(nextValue)
        state[key] = nextValue
    end
end

function IT_DYNAMIC_RENDER.SetColorCache(state, key, r, g, b, a)
    state[key .. "R"] = r
    state[key .. "G"] = g
    state[key .. "B"] = b
    state[key .. "A"] = a
end

function IT_DYNAMIC_RENDER.IsCachedColorEqual(state, key, r, g, b, a)
    return IT_DYNAMIC_RENDER.NearlyEqual(state[key .. "R"], r)
        and IT_DYNAMIC_RENDER.NearlyEqual(state[key .. "G"], g)
        and IT_DYNAMIC_RENDER.NearlyEqual(state[key .. "B"], b)
        and IT_DYNAMIC_RENDER.NearlyEqual(state[key .. "A"], a)
end

function IT_DYNAMIC_RENDER.SetTextColorIfChanged(fontString, state, key, r, g, b, a)
    if not IT_DYNAMIC_RENDER.IsCachedColorEqual(state, key, r, g, b, a) then
        fontString:SetTextColor(r, g, b, a)
        IT_DYNAMIC_RENDER.SetColorCache(state, key, r, g, b, a)
    end
end

function IT_DYNAMIC_RENDER.SetVertexColorIfChanged(texture, state, key, r, g, b, a)
    if not IT_DYNAMIC_RENDER.IsCachedColorEqual(state, key, r, g, b, a) then
        texture:SetVertexColor(r, g, b, a)
        IT_DYNAMIC_RENDER.SetColorCache(state, key, r, g, b, a)
    end
end

function IT_DYNAMIC_RENDER.SetStatusBarColorIfChanged(bar, state, key, r, g, b, a)
    if not IT_DYNAMIC_RENDER.IsCachedColorEqual(state, key, r, g, b, a) then
        bar:SetStatusBarColor(r, g, b, a)
        IT_DYNAMIC_RENDER.SetColorCache(state, key, r, g, b, a)
    end
end

function IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(bar, state, key, minValue, maxValue, value)
    if not IT_DYNAMIC_RENDER.NearlyEqual(state[key .. "Min"], minValue)
        or not IT_DYNAMIC_RENDER.NearlyEqual(state[key .. "Max"], maxValue) then
        bar:SetMinMaxValues(minValue, maxValue)
        state[key .. "Min"] = minValue
        state[key .. "Max"] = maxValue
    end
    if not IT_DYNAMIC_RENDER.NearlyEqual(state[key .. "Value"], value) then
        bar:SetValue(value)
        state[key .. "Value"] = value
    end
end

function IT_DYNAMIC_RENDER.PositionRowUseGlowIfChanged(row, state, target)
    if (not state.useGlowTargetInitialized) or state.useGlowTarget ~= target then
        IT_PositionRowUseGlow(row, target)
        state.useGlowTarget = target
        state.useGlowTargetInitialized = true
    end
end

local function IT_GetClassDefaultInterrupt(classFile)
    if not classFile then
        return nil
    end
    local kick = IT_CLASS_PRIMARY[classFile]
    if kick and kick.id then
        local spellData = IT_INTERRUPTS[kick.id] or IT_INTERRUPTS_STR[tostring(kick.id)]
        return {
            spellID = kick.id,
            baseCd = tonumber(kick.cd) or tonumber(spellData and spellData.cd) or 15,
            name = kick.name or (spellData and spellData.name) or "",
            icon = spellData and IT_GetPrimaryIcon(kick.id) or 134400,
        }
    end

    local fallbackList = IT_CLASS_INTERRUPT_LIST[classFile]
    local fallbackSpellID = type(fallbackList) == "table" and fallbackList[1] or nil
    local fallbackData = fallbackSpellID and (IT_INTERRUPTS[fallbackSpellID] or IT_INTERRUPTS_STR[tostring(fallbackSpellID)]) or nil
    if fallbackSpellID and fallbackData then
        return {
            spellID = fallbackSpellID,
            baseCd = tonumber(fallbackData.cd) or 15,
            name = fallbackData.name or "",
            icon = IT_GetPrimaryIcon(fallbackSpellID),
        }
    end

    return nil
end

local function IT_DebugTrace(enabled, ...)
    if not enabled then
        return
    end
    local parts = { ... }
    for index = 1, #parts do
        if IT_HasSecretValues(parts[index]) then
            parts[index] = "<secret>"
        else
            parts[index] = tostring(parts[index])
        end
    end
    print("PA IT DEBUG: " .. table.concat(parts, " "))
end

local IT_ResolveTrackedInterruptSpellID
local IT_ClassSupportsInterruptSpell

local function IT_SafeSpellName(spellID)
    local resolvedSpellID = IT_NormalizeSpellID(spellID)
    if resolvedSpellID <= 0 then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local okName, name = pcall(C_Spell.GetSpellName, resolvedSpellID)
        if okName and type(name) == "string" and name ~= "" then
            return name
        end
    end
    if GetSpellInfo then
        local okInfo, name = pcall(GetSpellInfo, resolvedSpellID)
        if okInfo and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

local IT_INTERRUPT_NAME_LOOKUP = nil

local function IT_NormalizeInterruptNameKey(name)
    local safeName = IT_NormalizeSafeString(name)
    if not safeName then
        return nil
    end
    safeName = trim(safeName)
    if safeName == "" then
        return nil
    end
    return string.lower(safeName)
end

local function IT_AddUniqueSpellID(list, spellID)
    local normalizedSpellID = IT_NormalizeSpellID(spellID)
    if normalizedSpellID <= 0 then
        return
    end
    for _, existingSpellID in ipairs(list) do
        if existingSpellID == normalizedSpellID then
            return
        end
    end
    list[#list + 1] = normalizedSpellID
end

local function IT_GetInterruptNameLookup()
    if IT_INTERRUPT_NAME_LOOKUP then
        return IT_INTERRUPT_NAME_LOOKUP
    end

    local lookup = {}
    local function addSpellName(name, spellID)
        local normalizedName = IT_NormalizeInterruptNameKey(name)
        local normalizedSpellID = IT_NormalizeSpellID(spellID)
        if not normalizedName or normalizedSpellID <= 0 then
            return
        end
        lookup[normalizedName] = lookup[normalizedName] or {}
        IT_AddUniqueSpellID(lookup[normalizedName], normalizedSpellID)
    end

    for spellID, data in pairs(IT_INTERRUPTS or {}) do
        local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(spellID)
        local canonicalSpellID = (rawSpellID > 0 and IT_INTERRUPTS[rawSpellID]) and rawSpellID or resolvedSpellID
        addSpellName(data and data.name, canonicalSpellID)
        addSpellName(IT_SafeSpellName(spellID), canonicalSpellID)
    end

    IT_INTERRUPT_NAME_LOOKUP = lookup
    return IT_INTERRUPT_NAME_LOOKUP
end

local function IT_ResolveObservedInterruptSpellIDFromName(name, member, ownerUnit)
    local normalizedName = IT_NormalizeInterruptNameKey(name)
    if not normalizedName then
        return nil
    end

    local candidates = IT_GetInterruptNameLookup()[normalizedName]
    if type(candidates) ~= "table" or #candidates == 0 then
        return nil
    end
    if #candidates == 1 then
        return candidates[1]
    end

    local filtered = {}
    local seen = {}
    local function addCandidate(candidateSpellID)
        local normalizedSpellID = IT_NormalizeSpellID(candidateSpellID)
        if normalizedSpellID <= 0 or seen[normalizedSpellID] then
            return
        end
        filtered[#filtered + 1] = normalizedSpellID
        seen[normalizedSpellID] = true
    end
    local function matchCandidate(value)
        local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(value)
        for _, candidateSpellID in ipairs(candidates) do
            if candidateSpellID == rawSpellID or candidateSpellID == resolvedSpellID then
                addCandidate(candidateSpellID)
            end
        end
    end

    if member then
        matchCandidate(member.spellID)
        for _, extraKick in ipairs(member.extraKicks or {}) do
            matchCandidate(extraKick.spellID)
        end
        local override = IT_SPEC_OVERRIDE[tonumber(member.specID) or 0]
        if override then
            matchCandidate(override.id)
        end
    end

    local classFile = (member and member.class) or (ownerUnit and IT_SafeUnitClass(ownerUnit)) or nil
    if classFile then
        local classMatches = {}
        local classSeen = {}
        for _, candidateSpellID in ipairs(candidates) do
            if IT_ClassSupportsInterruptSpell(classFile, candidateSpellID) and not classSeen[candidateSpellID] then
                classMatches[#classMatches + 1] = candidateSpellID
                classSeen[candidateSpellID] = true
            end
        end
        if #classMatches == 1 then
            return classMatches[1]
        end
        for _, candidateSpellID in ipairs(classMatches) do
            addCandidate(candidateSpellID)
        end
    end

    if #filtered == 1 then
        return filtered[1]
    end

    return nil
end

local function IT_ResolveObservedInterruptSpellIDFromPayload(payload, member, ownerUnit)
    local rawSpellID, resolvedSpellID, tracked = IT_ResolveTrackedInterruptSpellID(payload)
    if tracked then
        return (rawSpellID > 0 and IT_INTERRUPTS[rawSpellID]) and rawSpellID or resolvedSpellID, "spell_id"
    end

    local observedSpellID = IT_ResolveObservedInterruptSpellIDFromName(payload, member, ownerUnit)
    if observedSpellID then
        return observedSpellID, "spell_name"
    end

    return nil, nil
end

local function IT_ResolveObservedInterruptSpellIDFromEventArgs(source, ownerUnit, member, ...)
    local argCount = select("#", ...)
    if argCount <= 0 then
        return nil, nil
    end

    local startIndex = 1
    if source == "sent" and argCount >= 2 then
        startIndex = 2
    end

    for index = argCount, startIndex, -1 do
        local payload = select(index, ...)
        local observedSpellID, observedKind = IT_ResolveObservedInterruptSpellIDFromPayload(payload, member, ownerUnit)
        if observedSpellID then
            return observedSpellID, observedKind
        end
    end

    if source == "sent" and startIndex > 1 then
        local leadingSpellID = IT_ResolveObservedInterruptSpellIDFromName(select(1, ...), member, ownerUnit)
        if leadingSpellID then
            return leadingSpellID, "spell_name"
        end
    end

    return nil, nil
end

local function IT_FindMatchingExtraKick(member, spellID)
    if not member or type(member.extraKicks) ~= "table" then
        return nil
    end

    local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(spellID)
    for _, extraKick in ipairs(member.extraKicks) do
        local extraRawSpellID, extraResolvedSpellID = IT_ResolveTrackedInterruptSpellID(extraKick.spellID)
        if extraKick.spellID == spellID
            or extraKick.spellID == rawSpellID
            or extraKick.spellID == resolvedSpellID
            or extraRawSpellID == rawSpellID
            or extraRawSpellID == resolvedSpellID
            or extraResolvedSpellID == rawSpellID
            or extraResolvedSpellID == resolvedSpellID
        then
            return extraKick
        end
    end

    return nil
end

local function IT_GetCanonicalInterruptBaseCd(spellID, fallbackCd)
    local spellData = spellID and (IT_INTERRUPTS[spellID] or IT_INTERRUPTS_STR[tostring(spellID)]) or nil
    local canonical = tonumber(spellData and spellData.cd)
    if canonical and canonical > 0 then
        return canonical
    end
    canonical = tonumber(fallbackCd)
    if canonical and canonical > 0 then
        return canonical
    end
    canonical = IT_SafeBaseCooldown(spellID)
    if canonical and canonical > 0 then
        return canonical
    end
    return nil
end

local function IT_GetPreviewModeBPrimary(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local override = entry.specID and IT_SPEC_OVERRIDE[tonumber(entry.specID) or 0] or nil
    local primary = override and {
        spellID = tonumber(override.id) or 0,
        baseCd = IT_GetCanonicalInterruptBaseCd(override.id, override.cd) or tonumber(override.cd) or 15,
        name = override.name or "",
        icon = IT_GetPrimaryIcon(override.id),
        isPetSpell = override.isPet and true or false,
        petSpellID = override.petSpellID or nil,
    } or IT_GetClassDefaultInterrupt(entry.class)
    if not primary or not primary.spellID then
        return nil
    end
    return primary
end

IT_ResolveTrackedInterruptSpellID = function(spellID)
    local rawSpellID = IT_NormalizeSpellID(spellID)
    if rawSpellID <= 0 then
        return rawSpellID, rawSpellID, false
    end
    local resolvedSpellID = IT_NormalizeSpellID(IT_SPELL_ALIASES[rawSpellID] or rawSpellID)
    if resolvedSpellID <= 0 then
        resolvedSpellID = rawSpellID
    end
    local tracked = IT_INTERRUPTS[rawSpellID]
        or IT_INTERRUPTS[resolvedSpellID]
        or IT_INTERRUPTS_STR[tostring(rawSpellID)]
        or IT_INTERRUPTS_STR[tostring(resolvedSpellID)]
    return rawSpellID, resolvedSpellID, tracked ~= nil
end

local function IT_GetObservedSpecOverride(spellID)
    local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(spellID)
    for specID, override in pairs(IT_SPEC_OVERRIDE or {}) do
        local overrideSpellID = tonumber(override and override.id) or 0
        if overrideSpellID > 0 and (overrideSpellID == rawSpellID or overrideSpellID == resolvedSpellID) then
            return specID, override
        end
    end
    return nil, nil
end

IT_ClassSupportsInterruptSpell = function(classFile, spellID)
    if not classFile then
        return false
    end
    local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(spellID)
    for _, candidateSpellID in ipairs(IT_CLASS_INTERRUPT_LIST[classFile] or {}) do
        local candidateRaw, candidateResolved = IT_ResolveTrackedInterruptSpellID(candidateSpellID)
        if candidateRaw == rawSpellID
            or candidateRaw == resolvedSpellID
            or candidateResolved == rawSpellID
            or candidateResolved == resolvedSpellID
        then
            return true
        end
    end
    return false
end

local function IT_IsSolarBeamDebugSpell(spellID)
    local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(spellID)
    return rawSpellID == 78675
        or resolvedSpellID == 78675
        or rawSpellID == 47528
        or resolvedSpellID == 47528
end

local function IT_ShouldDebugSolarBeamRemote(member, spellID, specID)
    if not IT_DEBUG_SOLAR_BEAM_REMOTE then
        return false
    end
    return IT_IsSolarBeamDebugSpell(spellID)
end

local function IT_ShouldDebugSolarBeamSend(member, spellID, specID)
    if not IT_DEBUG_SOLAR_BEAM_SEND then
        return false
    end
    return IT_IsSolarBeamDebugSpell(spellID)
end

local function IT_DebugSolarBeamRemoteVerdict(enabled, verdict)
    IT_DebugTrace(enabled,
        "remote solar_beam CAST verdict",
        "memberResolved=", verdict and (verdict.memberResolved and "true" or "false") or "false",
        "fromAddonBefore=", verdict and (verdict.fromAddonBefore and "true" or "false") or "false",
        "fromAddonAfter=", verdict and (verdict.fromAddonAfter and "true" or "false") or "false",
        "specID=", verdict and (verdict.specID or "nil") or "nil",
        "trackedPrimary=", verdict and (verdict.trackedPrimary or "nil") or "nil",
        "addonPrimarySpellID=", verdict and (verdict.addonPrimarySpellID or "nil") or "nil",
        "addonPrimaryBaseCd=", verdict and (verdict.addonPrimaryBaseCd or "nil") or "nil",
        "exactPrimaryMatched=", verdict and (verdict.exactPrimaryMatched and "true" or "false") or "false",
        "extraKickMatched=", verdict and (verdict.extraKickMatched and "true" or "false") or "false",
        "selfHealAttempted=", verdict and (verdict.selfHealAttempted and "true" or "false") or "false",
        "selfHealResult=", verdict and (verdict.selfHealResult or "nil") or "nil",
        "promotionReason=", verdict and (verdict.promotionReason or "nil") or "nil",
        "ignoredStaleAfterAdj=", verdict and (verdict.ignoredStaleAfterAdj and "true" or "false") or "false",
        "handleConfirmedReached=", verdict and (verdict.handleConfirmedReached and "true" or "false") or "false",
        "finalVerdict=", verdict and (verdict.finalVerdict or "nil") or "nil")
end

local InterruptTrackerShared = {}

function InterruptTrackerShared.GetDBRoot()
    PortalAuthorityDB = PortalAuthorityDB or {}
    PortalAuthorityDB.modules = PortalAuthorityDB.modules or {}
    PortalAuthorityDB.modules.interruptTracker = PortalAuthorityDB.modules.interruptTracker or {}
    return PortalAuthorityDB.modules.interruptTracker
end

function InterruptTrackerShared.ApplyDefaultValues(db)
    db = type(db) == "table" and db or {}

    if db.locked == nil then db.locked = false end
    if db.x == nil then db.x = 0 end
    if db.y == nil then db.y = 0 end
    if db.width == nil then db.width = 220 end
    if db.rowHeight == nil then db.rowHeight = 22 end
    if db.rowGap == nil then db.rowGap = IT_ROW_GAP_DEFAULT end
    if db.fontPath == nil then db.fontPath = "" end
    if db.fontSize == nil then db.fontSize = 12 end
    if db.fontColor == nil then db.fontColor = { r = 1, g = 1, b = 1, a = 1 } end
    if db.backgroundOpacity == nil then db.backgroundOpacity = IT_BG_BAR[4] end
    if db.barTexture == nil then db.barTexture = "Overclock: Stormy Clean" end
    if db.useClassColors == nil then db.useClassColors = true end
    if db.showClassIcon == nil then db.showClassIcon = true end
    if db.showSpellIcon == nil then db.showSpellIcon = true end
    if db.alertSound == nil then db.alertSound = "" end
    if db.selfOnlyAlert == nil then db.selfOnlyAlert = false end
    if db.rotationEnabled == nil then db.rotationEnabled = true end
    if db.rightDisplay == nil then db.rightDisplay = "count" end
    if type(db.rotationOrder) ~= "table" then db.rotationOrder = {} end
    if db.rotationIndex == nil then db.rotationIndex = 1 end

    return db
end

function InterruptTrackerShared.NormalizeDB(db)
    db = InterruptTrackerShared.ApplyDefaultValues(db)

    db.locked = not not db.locked
    db.x = math.floor(tonumber(db.x) or 0)
    db.y = math.floor(tonumber(db.y) or 0)
    db.width = math.floor(clampNumber(db.width, 220, 160, 420))
    db.rowHeight = math.floor(clampNumber(db.rowHeight, 22, 18, 42))
    db.rowGap = IT_GetConfiguredRowGap(db)
    db.fontPath = trim(db.fontPath)
    db.fontSize = math.floor(clampNumber(db.fontSize, 12, 8, 24))
    db.fontColor = IT_CopyColor(db.fontColor)
    db.backgroundOpacity = IT_GetConfiguredRowBackgroundOpacity(db)
    db.barTexture = trim(tostring(db.barTexture or "Overclock: Stormy Clean"))
    if db.barTexture == "" then
        db.barTexture = "Overclock: Stormy Clean"
    end
    db.useClassColors = not not db.useClassColors
    db.showClassIcon = not not db.showClassIcon
    db.showSpellIcon = not not db.showSpellIcon
    db.alertSound = db.alertSound or ""
    db.selfOnlyAlert = not not db.selfOnlyAlert
    db.rotationEnabled = true
    db.rightDisplay = db.rightDisplay == "timer" and "timer" or "count"
    db.rotationOrder = IT_NormalizeNameList(db.rotationOrder)
    if db.rotationIndex < 1 then
        db.rotationIndex = 1
    end

    return db
end

function InterruptTrackerShared.EnsureDB()
    return InterruptTrackerShared.NormalizeDB(InterruptTrackerShared.GetDBRoot())
end

function InterruptTrackerShared.ResolveFont(db, globalFontPath, globalFontFlags)
    db = InterruptTrackerShared.ApplyDefaultValues(db)

    local path = trim(db.fontPath)
    local flags = "OUTLINE"
    if path == "" then
        path = trim(globalFontPath)
        if trim(globalFontFlags) ~= "" then
            flags = trim(globalFontFlags)
        end
    end
    if path == "" then
        path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    return path, db.fontSize or 12, flags
end

local InterruptTracker = {
    key = "interruptTracker",
    _shared = InterruptTrackerShared,
}

-- DB / value helpers
function InterruptTracker:EnsureDB()
    return InterruptTrackerShared.EnsureDB()
end

function InterruptTracker:GetDB()
    return self:EnsureDB()
end

function InterruptTracker:IsEnabled()
    local db = self:GetDB()
    return db.enabled ~= false
end

function InterruptTracker:GetFont()
    local db = self:GetDB()
    local globalPath, globalFlags = nil, nil
    if trim(db.fontPath) == "" and PortalAuthority.GetGlobalFontPath then
        globalPath, globalFlags = PortalAuthority:GetGlobalFontPath()
    end
    return InterruptTrackerShared.ResolveFont(db, globalPath, globalFlags)
end

function InterruptTracker:GetBarTexture()
    return IT_GetMediaTexturePath(self:GetDB().barTexture)
end

function InterruptTracker:IsTrackedPartyContext()
    if IsInRaid and IsInRaid() then
        return false
    end
    return (GetNumSubgroupMembers and (GetNumSubgroupMembers() or 0) > 0) and true or false
end

function InterruptTracker:IsSupportedLiveContext()
    return IT_IsSupportedDungeon() and self:IsTrackedPartyContext()
end

function InterruptTracker:ShouldRunPeriodicInspect()
    return self:IsEnabled() and self:IsSupportedLiveContext() and self:IsTrackedPartyContext()
end

function InterruptTracker:IsPreviewMode()
    return self:IsEnabled() and self.unlocked and true or false
end

function InterruptTracker:GetCurrentContextKey()
    return IT_GetContextKey()
end

function InterruptTracker:ResetPreviewState()
    self.previewStartedAt = 0
    self.previewCycleOffsetByKey = {}
    if type(self.rowReadyState) == "table" then
        for key in pairs(self.rowReadyState) do
            if type(key) == "string" and string.find(key, "^preview:") then
                self.rowReadyState[key] = nil
            end
        end
    end
end

function InterruptTracker:EnsurePreviewState(now)
    if (tonumber(self.previewStartedAt) or 0) <= 0 then
        self.previewStartedAt = now or GetTime()
    end
    self.previewCycleOffsetByKey = self.previewCycleOffsetByKey or {}
end

function InterruptTracker:ResetDisplayStructureState()
    self._displayStructureDirty = true
    self._displayStructureDirtyReason = "reset"
    self._displayStructureSignature = nil
    self._displayAssignments = nil
    self._displayTickMemberState = nil
    self._displayRowCount = 0
    self._displayModeB = nil
    self._displayPreviewMode = nil
    self._visibleRowPulseTargets = {}
end

function InterruptTracker:MarkDisplayStructureDirty(reason)
    self._displayStructureDirty = true
    if reason ~= nil then
        self._displayStructureDirtyReason = tostring(reason)
    end
end

function InterruptTracker:BuildDisplayStructureSignature(db, rowsData, modeB, previewMode)
    local parts = {
        previewMode and "preview" or "live",
        modeB and "modeB" or "modeA",
        tostring(math.floor(tonumber(db and db.width) or 0)),
        tostring(math.floor(tonumber(db and db.rowHeight) or 0)),
        tostring(math.floor(tonumber(self:GetRowGap()) or 0)),
        tostring((db and db.rightDisplay) == "timer" and "timer" or "count"),
        tostring(db and db.showClassIcon and 1 or 0),
        tostring(db and db.showSpellIcon and 1 or 0),
        tostring(#(rowsData or {})),
    }

    for index, member in ipairs(rowsData or {}) do
        parts[#parts + 1] = table.concat({
            tostring(index),
            member and member.isSelf and "self" or "party",
            tostring(IT_NormalizeName(member and member.name) or (member and member.name) or ""),
            tostring(member and member.class or ""),
            tostring(math.floor(tonumber(member and member.spellID) or 0)),
            tostring(member and member.previewUseClassIcon and 1 or 0),
        }, ":")
    end

    return table.concat(parts, "|")
end

function InterruptTracker:RefreshDisplayAssignmentMembers(rowsData, modeB)
    local assignments = self._displayAssignments
    local tickMemberState = self._displayTickMemberState
    if type(assignments) ~= "table" or #assignments ~= #(rowsData or {}) then
        return false
    end

    for index, assignment in ipairs(assignments) do
        local member = rowsData[index]
        if not assignment or not assignment.row or not member then
            return false
        end
        assignment.member = member
        assignment.modeB = modeB and true or false
        assignment.tickState = tickMemberState and tickMemberState[member] or nil
        assignment.row._displayMember = member
        assignment.row._displayModeB = modeB and true or false
    end

    return true
end

function InterruptTracker:ResetCounts()
    self.interruptCounts = {}
    self.recentCountedInterruptsByMember = {}
    self:ClearOwnerInterruptPending()
    if PA_CpuDiagIsFrameConsideredShown("interrupt", self.frame) then
        self:UpdateDisplay()
    end
end

function InterruptTracker:UpdateRunContext()
    local newKey = self:GetCurrentContextKey()
    if self.contextKey ~= newKey then
        self.contextKey = newKey
        self:ResetAvailabilityGate(newKey)
        self:ResetFullWipeRecoveryState()
        self:ResetCounts()
    end
end

function InterruptTracker:ResetAvailabilityGate(newContextKey)
    self.availabilityArmed = false
    self.availabilityContextKey = newContextKey
end

function InterruptTracker:IsAnyTrackedPartyUnitInCombat()
    if UnitAffectingCombat and UnitExists("player") and UnitAffectingCombat("player") then
        return true
    end
    if not UnitAffectingCombat then
        return false
    end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and UnitAffectingCombat(unit) then
            return true
        end
    end
    return false
end

function InterruptTracker:RefreshAvailabilityGate()
    local currentKey = self:GetCurrentContextKey()
    if not self:IsSupportedLiveContext() then
        self.availabilityArmed = false
        self.availabilityContextKey = nil
        return
    end
    if self.availabilityContextKey ~= currentKey then
        self:ResetAvailabilityGate(currentKey)
    end
    if self.availabilityArmed then
        return
    end
    if self:IsAnyTrackedPartyUnitInCombat() then
        self.availabilityArmed = true
    end
end

function InterruptTracker:ResetFullWipeRecoveryState()
    self.pendingFullWipeRecovery = false
    self.fullWipeRecoveryActive = false
    self.fullWipeRecoveryStartedAt = 0
    self.lastPartyCombatSeenAt = 0
    self.lastPlayerDeadOrGhost = IT_IsUnitRealDeadOrGhost("player")
    if self.selfState then
        self.selfState.lastDeathAt = 0
        self.selfState.lastDeadOrGhost = false
        self.selfState.fullWipeRecoverySeenAt = 0
    end
    for _, member in pairs(self.trackedMembers or {}) do
        member.lastDeathAt = 0
        member.lastDeadOrGhost = false
        member.fullWipeRecoverySeenAt = 0
    end
end

function InterruptTracker:GetTrackedAvailabilityMembers()
    local tracked = {}
    if self:MemberQualifiesForSeed(self.selfState) then
        tracked[#tracked + 1] = self.selfState
    end
    for _, member in pairs(self.trackedMembers or {}) do
        if self:MemberQualifiesForSeed(member) then
            tracked[#tracked + 1] = member
        end
    end
    return tracked
end

function InterruptTracker:GetResolvedTrackedWipeMembers()
    local tracked = self:GetTrackedAvailabilityMembers()

    if #tracked == 0 then
        return {}, false
    end

    local resolved = {}
    local seenUnits = {}
    local complete = true
    for _, member in ipairs(tracked) do
        local unit = self:GetMemberUnitToken(member)
        if unit and UnitExists(unit) and not seenUnits[unit] then
            resolved[#resolved + 1] = {
                member = member,
                unit = unit,
            }
            seenUnits[unit] = true
        else
            complete = false
        end
    end

    if #resolved ~= #tracked then
        complete = false
    end
    return resolved, complete
end

function InterruptTracker:MarkFullWipeRecoveryEvidence(member, now)
    if not self.fullWipeRecoveryActive or not member then
        return
    end
    member.fullWipeRecoverySeenAt = tonumber(now) or GetTime()
end

function InterruptTracker:ClearInterruptCountRecordsForMember(name, guid)
    self.recentCountedInterruptsByMember = self.recentCountedInterruptsByMember or {}
    local normalized = IT_NormalizeName(type(name) == "table" and name.name or name)
    local resolvedGUID = IT_NormalizeSafeString(guid)
    if not resolvedGUID and type(name) == "table" then
        resolvedGUID = self:GetMemberResolvedGUID(name)
    end
    if normalized then
        self.recentCountedInterruptsByMember["name:" .. normalized] = nil
    end
    if resolvedGUID then
        self.recentCountedInterruptsByMember["guid:" .. resolvedGUID] = nil
    end
end

function InterruptTracker:ClearFullWipeRecordsForMember(member)
    if not member then
        return
    end
    member.lastDeathAt = 0
    member.lastDeadOrGhost = false
    member.fullWipeRecoverySeenAt = 0
end

function InterruptTracker:MergeInterruptCountRecords(target, source)
    target = target or {}
    if type(source) ~= "table" then
        return target
    end
    for spellID, record in pairs(source) do
        local existing = target[spellID]
        if existing then
            existing.countedAt = math.max(tonumber(existing.countedAt) or 0, tonumber(record.countedAt) or 0)
            existing.lastSeenAt = math.max(tonumber(existing.lastSeenAt) or 0, tonumber(record.lastSeenAt) or tonumber(record.countedAt) or 0)
            if (tonumber(record.lastSeenAt) or tonumber(record.countedAt) or 0) >= (tonumber(existing.lastSeenAt) or 0) then
                existing.source = record.source or existing.source
            end
        else
            target[spellID] = {
                countedAt = tonumber(record.countedAt) or 0,
                lastSeenAt = tonumber(record.lastSeenAt) or tonumber(record.countedAt) or 0,
                source = record.source,
            }
        end
    end
    return target
end

function InterruptTracker:GetInterruptCountIdentityKey(member)
    if not member then
        return nil
    end
    local guid = self:GetMemberResolvedGUID(member)
    if guid then
        return "guid:" .. guid
    end
    local normalized = IT_NormalizeName(member.name)
    if normalized then
        return "name:" .. normalized
    end
    return nil
end

function InterruptTracker:TryCountInterrupt(member, resolvedSpellID, source, now)
    if not member or not member.name or not resolvedSpellID then
        return false
    end

    now = tonumber(now) or GetTime()
    self.recentCountedInterruptsByMember = self.recentCountedInterruptsByMember or {}

    local normalizedName = IT_NormalizeName(member.name)
    local guid = self:GetMemberResolvedGUID(member)
    local identityKey = self:GetInterruptCountIdentityKey(member)
    if not identityKey then
        return false
    end

    if guid and normalizedName then
        local guidKey = "guid:" .. guid
        local nameKey = "name:" .. normalizedName
        local nameRecords = self.recentCountedInterruptsByMember[nameKey]
        if nameRecords then
            self.recentCountedInterruptsByMember[guidKey] = self:MergeInterruptCountRecords(self.recentCountedInterruptsByMember[guidKey], nameRecords)
            self.recentCountedInterruptsByMember[nameKey] = nil
            identityKey = guidKey
        end
    end

    local spellKey = tonumber(resolvedSpellID) or resolvedSpellID
    local records = self.recentCountedInterruptsByMember[identityKey]
    if type(records) ~= "table" then
        records = {}
        self.recentCountedInterruptsByMember[identityKey] = records
    end

    local record = records[spellKey]

    if record and (now - (tonumber(record.countedAt) or 0)) <= IT_INTERRUPT_COUNT_DEDUPE_WINDOW then
        record.lastSeenAt = now
        if source then
            record.source = source
        end
        return false
    end

    records[spellKey] = {
        countedAt = now,
        lastSeenAt = now,
        source = source,
    }
    self:IncrementCount(member.name)
    return true
end

function InterruptTracker:RefreshFullWipeRecoveryState(now)
    now = tonumber(now) or GetTime()
    if not self:IsSupportedLiveContext() then
        self:ResetFullWipeRecoveryState()
        return
    end

    local playerDead = IT_IsUnitRealDeadOrGhost("player")
    local partyInCombat = self:IsAnyTrackedPartyUnitInCombat()
    if partyInCombat then
        self.lastPartyCombatSeenAt = now
    end
    if partyInCombat and (self.fullWipeRecoveryActive or self.pendingFullWipeRecovery) then
        self.fullWipeRecoveryActive = false
        self.pendingFullWipeRecovery = false
        self.fullWipeRecoveryStartedAt = 0
        for _, member in ipairs(self:GetTrackedAvailabilityMembers()) do
            member.fullWipeRecoverySeenAt = 0
        end
    end

    local resolvedMembers, complete = self:GetResolvedTrackedWipeMembers()
    local allDead = complete and #resolvedMembers > 0
    local earliestDeathAt, latestDeathAt = nil, nil
    local everyMemberHasDeath = complete and #resolvedMembers > 0

    for _, entry in ipairs(resolvedMembers) do
        local member = entry.member
        local isDead = IT_IsUnitRealDeadOrGhost(entry.unit)
        local previousDead = member.lastDeadOrGhost and true or false
        if isDead then
            if not previousDead then
                member.lastDeadOrGhost = true
                member.lastDeathAt = now
            elseif (tonumber(member.lastDeathAt) or 0) <= 0 then
                member.lastDeathAt = now
            end
        elseif previousDead then
            member.lastDeadOrGhost = false
        else
            member.lastDeadOrGhost = false
        end

        if not isDead then
            allDead = false
        end

        local deathAt = tonumber(member.lastDeathAt) or 0
        if deathAt <= 0 then
            everyMemberHasDeath = false
        else
            earliestDeathAt = earliestDeathAt and math.min(earliestDeathAt, deathAt) or deathAt
            latestDeathAt = latestDeathAt and math.max(latestDeathAt, deathAt) or deathAt
        end
    end

    if (not self.fullWipeRecoveryActive) and (not self.pendingFullWipeRecovery) and self.availabilityArmed and complete and allDead and everyMemberHasDeath and earliestDeathAt and latestDeathAt then
        local deathSpread = latestDeathAt - earliestDeathAt
        local combatAge = now - (tonumber(self.lastPartyCombatSeenAt) or 0)
        if deathSpread <= IT_FULL_WIPE_WINDOW and combatAge <= IT_FULL_WIPE_COMBAT_RECENCY then
            self.pendingFullWipeRecovery = true
        end
    end

    if self.pendingFullWipeRecovery and (not playerDead) and self.lastPlayerDeadOrGhost then
        self.pendingFullWipeRecovery = false
        self.fullWipeRecoveryActive = true
        self.fullWipeRecoveryStartedAt = now
        for _, member in ipairs(self:GetTrackedAvailabilityMembers()) do
            member.fullWipeRecoverySeenAt = 0
        end
        self.lastPlayerDeadOrGhost = false
    else
        self.lastPlayerDeadOrGhost = playerDead
    end
end

function InterruptTracker:GetCurrentRoster(includeSelf)
    local roster = {}
    if IsInRaid and IsInRaid() then
        return roster
    end
    if includeSelf and self:IsTrackedPartyContext() then
        roster[#roster + 1] = {
            name = IT_NormalizeName(UnitName("player")),
            unit = "player",
            guid = IT_SafeUnitGUID("player"),
            isSelf = true,
        }
    end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) then
            roster[#roster + 1] = {
                name = IT_SafeUnitName(unit),
                unit = unit,
                petUnit = "partypet" .. i,
                guid = IT_SafeUnitGUID(unit),
                connected = (not UnitIsConnected) or UnitIsConnected(unit),
                isSelf = false,
            }
        end
    end
    return roster
end

function InterruptTracker:BuildUnitMap()
    self.memberUnits = {}
    for _, entry in ipairs(self:GetCurrentRoster(true)) do
        if entry.name then
            self.memberUnits[entry.name] = entry
        end
    end
end

function InterruptTracker:GetUnitForMember(name)
    name = IT_NormalizeName(name)
    if not self.memberUnits then
        self:BuildUnitMap()
    end
    return self.memberUnits and self.memberUnits[name] or nil
end

function InterruptTracker:FindMemberByName(name)
    name = IT_NormalizeName(name)
    if not name then
        return nil
    end
    if self.selfState and self.selfState.name == name then
        return self.selfState
    end
    return self.trackedMembers and self.trackedMembers[name] or nil
end

function InterruptTracker:GetMemberRecord(name, createIfMissing)
    name = IT_NormalizeName(name)
    if not name then
        return nil
    end
    if self.selfState and self.selfState.name == name then
        return self.selfState
    end
    self.trackedMembers = self.trackedMembers or {}
    if createIfMissing and not self.trackedMembers[name] then
        self.trackedMembers[name] = {
            name = name,
            isSelf = false,
            fromAddon = false,
            addonPrimarySpellID = nil,
            addonPrimaryBaseCd = nil,
            addonPrimarySeenAt = nil,
            extraKicks = {},
            cdEnd = 0,
            onKickReduction = nil,
            hasLightOfTheSun = false,
            requiresPrimaryTargetConfirm = false,
            primaryTargetOnKickReduction = nil,
            hasColdthirst = false,
            requiresOwnerInterruptConfirm = false,
            ownerInterruptReduction = nil,
            lastAdjSpellID = nil,
            lastAdjIgnoreCastUntil = nil,
            lastActivityAt = 0,
            offlineSinceAt = nil,
            unitGUID = nil,
            lastDeathAt = 0,
            lastDeadOrGhost = false,
            fullWipeRecoverySeenAt = 0,
        }
    end
    return self.trackedMembers[name]
end

function InterruptTracker:EnsureMemberRecordFromUnit(unit, name)
    if not unit or not UnitExists(unit) then
        return nil
    end
    local normalizedName = IT_NormalizeName(name or IT_SafeUnitName(unit))
    if not normalizedName then
        return nil
    end
    local classFile = IT_SafeUnitClass(unit)
    if not classFile then
        return nil
    end
    local kick = IT_CLASS_PRIMARY[classFile]
    if (not kick) and type(IT_CLASS_INTERRUPT_LIST[classFile]) == "table" then
        local fallbackSpellID = IT_CLASS_INTERRUPT_LIST[classFile][1]
        local fallbackData = fallbackSpellID and IT_INTERRUPTS[fallbackSpellID] or nil
        if fallbackData then
            kick = {
                id = fallbackSpellID,
                cd = fallbackData.cd,
                name = fallbackData.name,
            }
        end
    end
    if not kick then
        return nil
    end
    local member = self:GetMemberRecord(normalizedName, true)
    member.class = classFile
    member.extraKicks = member.extraKicks or {}
    local unitGUID = IT_SafeUnitGUID(unit)
    if unitGUID then
        member.unitGUID = unitGUID
    end
    return member
end

function InterruptTracker:GetSpecNameForMember(member)
    return member and (member.specName or IT_GetSpecName(member.specID)) or nil
end

function InterruptTracker:GetPrimarySpellData(member)
    if not member or not member.spellID then
        return nil
    end
    return IT_INTERRUPTS[member.spellID] or IT_INTERRUPTS_STR[IT_SafeToString(member.spellID) or ""]
end

function InterruptTracker:GetMemberRemaining(member, now)
    if not member then
        return 0
    end
    return math.max(0, (tonumber(member.cdEnd) or 0) - (now or GetTime()))
end

function InterruptTracker:IsMemberReady(member, now)
    return IT_IsReady(member and member.cdEnd or 0, now or GetTime())
end

function InterruptTracker:GetDisplayColor(member)
    local db = self:GetDB()
    if db.useClassColors and member and member.class then
        local r, g, b = IT_GetClassColor(member.class)
        return r, g, b
    end
    return IT_NEUTRAL_BAR[1], IT_NEUTRAL_BAR[2], IT_NEUTRAL_BAR[3]
end

function InterruptTracker:PlayAlertSoundFor(name)
    local db = self:GetDB()
    if trim(tostring(db.alertSound or "")) == "" then
        return
    end
    local normalized = IT_NormalizeName(name)
    if db.selfOnlyAlert and normalized ~= self.playerName then
        return
    end
    local kind, value = IT_GetAlertSoundChoice(db.alertSound)
    if kind == "file" and value then
        PlaySoundFile(value, "Master")
    elseif kind == "kit" and value then
        PlaySound(value, "Master")
    end
end

function InterruptTracker:IncrementCount(name)
    name = IT_NormalizeName(name)
    if not name then
        return
    end
    self.interruptCounts = self.interruptCounts or {}
    self.interruptCounts[name] = (tonumber(self.interruptCounts[name]) or 0) + 1
    self:BroadcastState()
end

function InterruptTracker:GetCount(name)
    name = IT_NormalizeName(name)
    return math.floor(tonumber(self.interruptCounts and self.interruptCounts[name]) or 0)
end

function InterruptTracker:GetMemberUnitToken(member)
    if not member then
        return nil
    end
    if member.isSelf then
        return "player"
    end
    local rosterEntry = self:GetUnitForMember(member.name)
    return rosterEntry and rosterEntry.unit or nil
end

function InterruptTracker:GetMemberResolvedGUID(member)
    if not member then
        return nil
    end
    local guid = IT_NormalizeSafeString(member.unitGUID)
    if guid then
        member.unitGUID = guid
        return guid
    end
    local unit = self:GetMemberUnitToken(member)
    guid = unit and IT_SafeUnitGUID(unit) or nil
    if guid then
        member.unitGUID = guid
    end
    return guid
end

function InterruptTracker:GetTrackedMemberByUnitToken(unitToken)
    if not IT_IsUsablePlainString(unitToken) then
        return nil
    end
    for _, member in ipairs(self:GetTrackedAvailabilityMembers()) do
        if self:GetMemberUnitToken(member) == unitToken then
            return member
        end
    end
    return nil
end

function InterruptTracker:FindTrackedMemberBySafeName(name)
    if not IT_IsUsablePlainString(name) then
        return nil
    end
    local normalized = IT_NormalizeName(name)
    if not normalized then
        return nil
    end
    local member = self:FindMemberByName(normalized)
    if member and self:MemberQualifiesForSeed(member) then
        return member
    end
    return nil
end

function InterruptTracker:HandleTrackedMemberDeath(deadGUID, deadName, now)
    local member = nil
    if UnitTokenFromGUID and type(deadGUID) == "string" and not IT_HasSecretValues(deadGUID) then
        local ok, unitToken = pcall(UnitTokenFromGUID, deadGUID)
        if ok and IT_IsUsablePlainString(unitToken) then
            member = self:GetTrackedMemberByUnitToken(unitToken)
        end
    end
    if not member then
        member = self:FindTrackedMemberBySafeName(deadName)
    end
    if not member then
        return false
    end

    local deathAt = tonumber(member.lastDeathAt) or 0
    local alreadyDead = member.lastDeadOrGhost and true or false
    if not alreadyDead then
        member.lastDeathAt = tonumber(now) or GetTime()
    elseif deathAt <= 0 then
        member.lastDeathAt = tonumber(now) or GetTime()
    end
    member.lastDeadOrGhost = true
    return true
end

function InterruptTracker:ClearOwnerInterruptPending()
    self.pendingOwnerInterruptConfirm = nil
    self.lastHandledInterruptedGUID = nil
    self.lastHandledInterruptedAt = 0
end

function InterruptTracker:ExpireOwnerInterruptPending(now)
    local pending = self.pendingOwnerInterruptConfirm
    local currentTime = tonumber(now) or GetTime()
    if pending and (tonumber(pending.expiresAt) or 0) < currentTime then
        self.pendingOwnerInterruptConfirm = nil
    end
end

function InterruptTracker:ClearAdjGuard(member)
    if not member then
        return
    end
    member.lastAdjSpellID = nil
    member.lastAdjIgnoreCastUntil = nil
end

function InterruptTracker:ExpireAdjGuard(member, now)
    if not member then
        return
    end
    if member.lastAdjIgnoreCastUntil and (tonumber(member.lastAdjIgnoreCastUntil) or 0) <= (tonumber(now) or GetTime()) then
        self:ClearAdjGuard(member)
    end
end

function InterruptTracker:GetOwnerConfirmedReduction(member)
    if not member or not member.spellID then
        return nil
    end
    if member.spellID == 78675 and member.requiresPrimaryTargetConfirm and member.hasLightOfTheSun then
        return tonumber(member.primaryTargetOnKickReduction) or nil
    end
    if member.spellID == 47528 and member.requiresOwnerInterruptConfirm and member.hasColdthirst then
        return tonumber(member.ownerInterruptReduction) or nil
    end
    return nil
end

function InterruptTracker:ResolveStrictHostileCandidateGUID()
    return nil
end

function InterruptTracker:ArmOwnerInterruptPending(member, now)
    self:ClearOwnerInterruptPending()
end

function InterruptTracker:ApplyOwnerConfirmedReduction(member, reduction)
    if not member or not reduction then
        return
    end
    local now = GetTime()
    member.cdEnd = math.max(now, (tonumber(member.cdEnd) or now) - tonumber(reduction or 0))
end

function InterruptTracker:MaybeConfirmOwnerInterrupt(member, interruptedUnit, interruptedGUID, now)
    return false
end

function InterruptTracker:MarkMemberActivity(name, timestamp, allowCreate)
    local normalized = IT_NormalizeName(name)
    if not normalized or normalized == self.playerName then
        return
    end
    local member = self:GetMemberRecord(normalized, false)
    if not member then
        if allowCreate == false then
            return
        end
        local rosterEntry = self:GetUnitForMember(normalized)
        if not rosterEntry then
            return
        end
        member = self:GetMemberRecord(normalized, true)
        member.unitGUID = IT_NormalizeSafeString(rosterEntry.guid) or IT_NormalizeSafeString(member.unitGUID)
    end
    member.lastActivityAt = tonumber(timestamp) or GetTime()
    self:MarkFullWipeRecoveryEvidence(member, member.lastActivityAt)
end

function InterruptTracker:MemberQualifiesForSeed(member)
    return member and member.name and self:GetPrimarySpellData(member) and true or false
end

function InterruptTracker:CaptureSeedState(member)
    return {
        qualifies = self:MemberQualifiesForSeed(member),
        name = IT_NormalizeName(member and member.name),
        spellID = tonumber(member and member.spellID) or 0,
        baseCd = tonumber(member and member.baseCd) or 0,
    }
end

function InterruptTracker:DidSeedStateChange(beforeState, member)
    local afterState = self:CaptureSeedState(member)
    return beforeState.qualifies ~= afterState.qualifies
        or beforeState.name ~= afterState.name
        or beforeState.spellID ~= afterState.spellID
        or beforeState.baseCd ~= afterState.baseCd
end

function InterruptTracker:GetMemberAvailability(member, now)
    now = now or GetTime()
    if not member then
        return {
            bucket = "offline",
            visible = false,
            connected = false,
            isDead = false,
        }
    end

    if self:IsPreviewMode() then
        local previewBucket = member.previewAvailability or (member.isSelf and "confirmed" or "confirmed")
        local offlineSinceAt = tonumber(member.offlineSinceAt) or now
        return {
            bucket = previewBucket,
            visible = previewBucket ~= "offline" or (now - offlineSinceAt) <= IT_OFFLINE_GRACE_WINDOW,
            connected = previewBucket ~= "offline",
            isDead = previewBucket == "dead",
        }
    end

    local unit = self:GetMemberUnitToken(member)
    if member.isSelf and (not unit or not UnitExists(unit)) then
        return {
            bucket = "confirmed",
            visible = true,
            connected = true,
            isDead = false,
        }
    end
    if not unit or not UnitExists(unit) then
        return {
            bucket = "offline",
            visible = false,
            connected = false,
            isDead = false,
        }
    end

    local connected = (not UnitIsConnected) or UnitIsConnected(unit)
    if not connected then
        member.offlineSinceAt = tonumber(member.offlineSinceAt) or now
        return {
            bucket = "offline",
            visible = (now - member.offlineSinceAt) <= IT_OFFLINE_GRACE_WINDOW,
            connected = false,
            isDead = false,
        }
    end

    member.offlineSinceAt = nil
    local isDead = IT_IsUnitRealDeadOrGhost(unit)
    if isDead then
        return {
            bucket = "dead",
            visible = true,
            connected = true,
            isDead = true,
        }
    end

    local classFile = member.class or IT_SafeUnitClass(unit)
    local isFeignDeath = classFile == "HUNTER" and UnitIsFeignDeath and UnitIsFeignDeath(unit) and true or false
    if isFeignDeath then
        return {
            bucket = "confirmed",
            visible = true,
            connected = true,
            isDead = false,
        }
    end

    if member.isSelf then
        return {
            bucket = "confirmed",
            visible = true,
            connected = true,
            isDead = false,
        }
    end

    if self.fullWipeRecoveryActive then
        local recoveryStartedAt = tonumber(self.fullWipeRecoveryStartedAt) or 0
        if recoveryStartedAt > 0 and (now - recoveryStartedAt) <= IT_FULL_WIPE_RECOVERY_GRACE then
            return {
                bucket = "confirmed",
                visible = true,
                connected = true,
                isDead = false,
            }
        end
        if (tonumber(member.fullWipeRecoverySeenAt) or 0) >= recoveryStartedAt then
            return {
                bucket = "confirmed",
                visible = true,
                connected = true,
                isDead = false,
            }
        end
        return {
            bucket = "stale",
            visible = true,
            connected = true,
            isDead = false,
        }
    end

    if member.lastDeadOrGhost and not isDead then
        member.lastDeadOrGhost = false
    end

    if not self.availabilityArmed then
        return {
            bucket = "confirmed",
            visible = true,
            connected = true,
            isDead = false,
        }
    end

    local lastActivityAt = tonumber(member.lastActivityAt) or 0
    local lastDeathAt = tonumber(member.lastDeathAt) or 0
    if lastDeathAt > lastActivityAt then
        return {
            bucket = "stale",
            visible = true,
            connected = true,
            isDead = false,
        }
    end
    local bucket = (lastActivityAt > 0 and (now - lastActivityAt) <= IT_ACTIVITY_CONFIRM_WINDOW) and "confirmed" or "stale"
    return {
        bucket = bucket,
        visible = true,
        connected = true,
        isDead = false,
    }
end

function InterruptTracker:GetCurrentPrimaryOrder()
    local now = GetTime()
    local rows = {}
    if self:MemberQualifiesForSeed(self.selfState) then
        rows[#rows + 1] = self.selfState
    end
    for _, member in pairs(self.trackedMembers or {}) do
        if self:MemberQualifiesForSeed(member) then
            rows[#rows + 1] = member
        end
    end
    table.sort(rows, function(a, b)
        if a.isSelf ~= b.isSelf then
            return a.isSelf and true or false
        end
        if a.isSelf and b.isSelf then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        local aReady = self:IsMemberReady(a, now)
        local bReady = self:IsMemberReady(b, now)
        if aReady ~= bReady then
            return aReady and true or false
        end
        if aReady and bReady then
            if (a.baseCd or 999) ~= (b.baseCd or 999) then
                return (a.baseCd or 999) < (b.baseCd or 999)
            end
        else
            local aRem = IT_SnapRemaining(self:GetMemberRemaining(a, now))
            local bRem = IT_SnapRemaining(self:GetMemberRemaining(b, now))
            if aRem ~= bRem then
                return aRem < bRem
            end
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    return rows
end

-- Mode B seed order is local-only authority: finalized primary cooldown ascending, then normalized name.
function InterruptTracker:GetModeBSeedOrder()
    local members = {}
    if self:MemberQualifiesForSeed(self.selfState) then
        members[#members + 1] = self.selfState
    end
    for _, member in pairs(self.trackedMembers or {}) do
        if self:MemberQualifiesForSeed(member) then
            members[#members + 1] = member
        end
    end
    table.sort(members, function(a, b)
        local aCd = tonumber(a.baseCd) or 999
        local bCd = tonumber(b.baseCd) or 999
        if aCd ~= bCd then
            return aCd < bCd
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    local names = {}
    for _, member in ipairs(members) do
        names[#names + 1] = member.name
    end
    return IT_NormalizeNameList(names)
end

function InterruptTracker:ReseedModeBOrder(emitCompatibility)
    local db = self:GetDB()
    if not db.rotationEnabled then
        return false
    end

    local previousPayload = IT_SerializeNameList(db.rotationOrder)
    db.rotationOrder = self:GetModeBSeedOrder()
    db.rotationIndex = 1

    local payloadChanged = IT_SerializeNameList(db.rotationOrder) ~= previousPayload
    if emitCompatibility and self:IsTrackedPartyContext() then
        if payloadChanged then
            self:BroadcastRotation()
        end
        self:BroadcastRotationIndex()
    end
    if payloadChanged then
        self:MarkDisplayStructureDirty("reseed")
    end
    return payloadChanged
end

function InterruptTracker:BroadcastRotation()
    local db = self:GetDB()
    if not db.rotationEnabled or not self:IsTrackedPartyContext() then
        return
    end
    local payload = IT_SerializeNameList(db.rotationOrder)
    local msg = "ROT"
        .. ":" .. tostring(payload)
        .. ":" .. "1"
    IT_SafeSendAddon(PA_INTERRUPT_PREFIX, msg, IT_GetGroupChannel())
end

-- ROTIDX remains a fixed compatibility heartbeat for legacy consumers.
function InterruptTracker:BroadcastRotationIndex()
    local db = self:GetDB()
    if not db.rotationEnabled or not self:IsTrackedPartyContext() then
        return
    end
    db.rotationIndex = 1
    local msg = "ROTIDX"
        .. ":" .. "1"
    IT_SafeSendAddon(PA_INTERRUPT_PREFIX, msg, IT_GetGroupChannel())
end

function InterruptTracker:BroadcastState()
    if not self:IsTrackedPartyContext() then
        return
    end
    local pieces = {}
    for name, count in pairs(self.interruptCounts or {}) do
        local normalized = IT_NormalizeName(name)
        if normalized then
            pieces[#pieces + 1] = normalized .. "=" .. tostring(math.floor(tonumber(count) or 0))
        end
    end
    table.sort(pieces)
    local payload = table.concat(pieces, ",")
    local msg = "STATE"
        .. ":" .. tostring(payload)
    IT_SafeSendAddon(PA_INTERRUPT_PREFIX, msg, IT_GetGroupChannel())
end

function InterruptTracker:AnnounceHello(force)
    if not self:IsTrackedPartyContext() or not self.playerClass or not self.selfState or not self.selfState.spellID then
        return
    end
    local now = GetTime()
    if not force and self.lastHelloAt and (now - self.lastHelloAt) < IT_HELLO_THROTTLE then
        return
    end
    self.lastHelloAt = now
    local version = ""
    if PA_GetAddonVersionString then
        version = tostring(PA_GetAddonVersionString() or "")
    end
    local classFile = tostring(self.playerClass or "")
    local spellID = tonumber(self.selfState.spellID) or 0
    local baseCd = tonumber(self.selfState.baseCd)
    if not baseCd or baseCd <= 0 then
        baseCd = tonumber((IT_INTERRUPTS[spellID] or {}).cd) or 15
    end
    local specID = tonumber(self.selfState.specID) or 0
    local msg = "HELLO"
        .. ":" .. tostring(classFile)
        .. ":" .. tostring(spellID)
        .. ":" .. tostring(baseCd)
        .. ":" .. tostring(specID)
        .. ":" .. tostring(version or "")
    IT_SafeSendAddon(PA_INTERRUPT_PREFIX, msg, IT_GetGroupChannel())
    local debugSendSolarBeam = IT_ShouldDebugSolarBeamSend(self.selfState, spellID, specID)
    if debugSendSolarBeam then
        IT_DebugTrace(true,
            "solar_beam SEND HELLO",
            "specID=", specID or "nil",
            "helloPrimary=", spellID or "nil",
            "fromAddon=", self.selfState.fromAddon and "true" or "false",
            "advertises78675=", ((tonumber(spellID) or 0) == 78675) and "true" or "false")
    end
end

function InterruptTracker:BroadcastCast(spellID, cooldownSeconds, marker)
    if not self:IsTrackedPartyContext() then
        return
    end
    local msg = "CAST"
        .. ":" .. tostring(spellID or 0)
        .. ":" .. tostring(tonumber(cooldownSeconds) or 0)
    if trim(tostring(marker or "")) ~= "" then
        msg = msg .. ":" .. tostring(marker)
    end
    local sendOk = IT_SafeSendAddon(PA_INTERRUPT_PREFIX, msg, IT_GetGroupChannel())
    local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(spellID)
    local localMember = self.selfState
    if trim(tostring(marker or "")) == "" and (rawSpellID == 78675 or resolvedSpellID == 78675) and IT_ShouldDebugSolarBeamSend(localMember, spellID, localMember and localMember.specID or nil) then
        IT_DebugTrace(true,
            "solar_beam SEND CAST",
            "spellID=", resolvedSpellID or rawSpellID or "nil",
            "localPrimary=", localMember and (localMember.spellID or "nil") or "nil",
            "specID=", localMember and (localMember.specID or "nil") or "nil",
            "fromAddon=", localMember and (localMember.fromAddon and "true" or "false") or "false",
            "fired=", sendOk and "true" or "false")
    end
end

function InterruptTracker:CopyInterruptEntry(member, source)
    if not member or not source then
        return
    end
    member.class = source.class or member.class
    member.specID = source.specID or member.specID
    member.specName = source.specName or member.specName
    member.spellID = source.spellID or member.spellID
    member.baseCd = source.baseCd or member.baseCd
    member.fromAddon = source.fromAddon and true or false
    member.addonPrimarySpellID = source.addonPrimarySpellID
    member.addonPrimaryBaseCd = source.addonPrimaryBaseCd
    member.addonPrimarySeenAt = source.addonPrimarySeenAt
    member.isPetSpell = source.isPetSpell and true or false
    member.petSpellID = source.petSpellID or member.petSpellID
    member.unitGUID = IT_NormalizeSafeString(source.unitGUID) or IT_NormalizeSafeString(member.unitGUID)
    member.icon = source.icon or member.icon
    member.onKickReduction = source.onKickReduction
    member.hasLightOfTheSun = source.hasLightOfTheSun and true or false
    member.requiresPrimaryTargetConfirm = source.requiresPrimaryTargetConfirm and true or false
    member.primaryTargetOnKickReduction = source.primaryTargetOnKickReduction
    member.hasColdthirst = source.hasColdthirst and true or false
    member.requiresOwnerInterruptConfirm = source.requiresOwnerInterruptConfirm and true or false
    member.ownerInterruptReduction = source.ownerInterruptReduction
    member.lastActivityAt = tonumber(source.lastActivityAt) or tonumber(member.lastActivityAt) or 0
    member.offlineSinceAt = source.offlineSinceAt or member.offlineSinceAt
    member.lastDeathAt = tonumber(source.lastDeathAt) or tonumber(member.lastDeathAt) or 0
    member.lastDeadOrGhost = source.lastDeadOrGhost and true or false
    member.fullWipeRecoverySeenAt = tonumber(source.fullWipeRecoverySeenAt) or tonumber(member.fullWipeRecoverySeenAt) or 0
    if type(source.extraKicks) == "table" then
        member.extraKicks = {}
        for _, extra in ipairs(source.extraKicks) do
            member.extraKicks[#member.extraKicks + 1] = {
                spellID = extra.spellID,
                baseCd = extra.baseCd,
                cdEnd = extra.cdEnd or 0,
                name = extra.name,
                icon = extra.icon or IT_GetPrimaryIcon(extra.spellID),
            }
        end
    end
end

function InterruptTracker:GetStoredAddonPrimaryState(member)
    local spellID = tonumber(member and member.addonPrimarySpellID) or 0
    if spellID <= 0 then
        return nil, nil
    end
    local _, resolvedSpellID, tracked = IT_ResolveTrackedInterruptSpellID(spellID)
    if not tracked then
        return nil, "stored_primary_invalid"
    end
    local baseCd = IT_GetCanonicalInterruptBaseCd(resolvedSpellID, member and member.addonPrimaryBaseCd)
    if not baseCd or baseCd <= 0 then
        return nil, "stored_primary_invalid"
    end
    return {
        spellID = resolvedSpellID,
        baseCd = baseCd,
        icon = IT_GetPrimaryIcon(resolvedSpellID),
        seenAt = tonumber(member and member.addonPrimarySeenAt) or 0,
    }, nil
end

function InterruptTracker:ClearStoredAddonPrimary(member)
    if not member then
        return
    end
    member.addonPrimarySpellID = nil
    member.addonPrimaryBaseCd = nil
    member.addonPrimarySeenAt = nil
end

function InterruptTracker:ResolveSpecBasedCanonicalPrimary(member, specID, unit)
    local resolvedSpecID = tonumber(specID) or 0
    if resolvedSpecID <= 0 then
        return nil, "spec_missing"
    end
    local override = IT_SPEC_OVERRIDE[resolvedSpecID]
    if not override then
        return nil, "no_authoritative_primary"
    end

    local probe = {
        name = member and member.name,
        class = member and member.class,
    }
    if not self:ApplySpecOverride(probe, resolvedSpecID, unit) then
        return nil, "no_authoritative_primary"
    end

    local spellID = tonumber(probe.spellID) or 0
    if spellID <= 0 then
        return nil, "no_authoritative_primary"
    end

    local baseCd = IT_GetCanonicalInterruptBaseCd(spellID, probe.baseCd)
    if not baseCd or baseCd <= 0 then
        return nil, "no_authoritative_primary"
    end

    return {
        spellID = spellID,
        baseCd = baseCd,
        icon = probe.icon or IT_GetPrimaryIcon(spellID),
        specID = resolvedSpecID,
    }, nil
end

function InterruptTracker:ResolveAuthoritativeSpecBasedCanonicalPrimary(member, unit)
    local liveSpecID = tonumber(unit and GetInspectSpecialization and GetInspectSpecialization(unit) or 0) or 0
    if liveSpecID > 0 then
        local specPrimaryState, specReason = self:ResolveSpecBasedCanonicalPrimary(member, liveSpecID, unit)
        return specPrimaryState, specReason, liveSpecID, "live_unit"
    end

    local storedSpecID = tonumber(member and member.specID) or 0
    if storedSpecID > 0 then
        local specPrimaryState, specReason = self:ResolveSpecBasedCanonicalPrimary(member, storedSpecID, unit)
        return specPrimaryState, specReason, storedSpecID, "member_record"
    end

    return nil, "spec_missing", 0, "missing"
end

function InterruptTracker:InvalidateStoredAddonPrimaryIfSpecConflicts(member, specPrimaryState, debugEnabled, context)
    local storedState = self:GetStoredAddonPrimaryState(member)
    if not storedState or not specPrimaryState then
        return false
    end
    if (tonumber(storedState.spellID) or 0) == (tonumber(specPrimaryState.spellID) or 0) then
        return false
    end
    IT_DebugTrace(debugEnabled,
        "remote solar_beam stored addon primary invalidated",
        "context=", context or "unknown",
        "storedSpellID=", storedState.spellID,
        "canonicalSpellID=", specPrimaryState.spellID)
    self:ClearStoredAddonPrimary(member)
    return true
end

function InterruptTracker:TryPromoteMemberFromAddonCast(member, senderName, spellID, debugEnabled)
    if not member then
        IT_DebugTrace(debugEnabled,
            "remote solar_beam fromAddon promotion blocked",
            "reason=member_unknown")
        return false, "member_unknown"
    end
    if member.fromAddon then
        return true, "already_addon_backed"
    end

    self:BuildUnitMap()
    local rosterEntry = self:GetUnitForMember(senderName)
    if not rosterEntry or IT_NormalizeName(rosterEntry.name) ~= IT_NormalizeName(member.name) then
        IT_DebugTrace(debugEnabled,
            "remote solar_beam fromAddon promotion blocked",
            "reason=member_resolution_missing")
        return false, "member_resolution_missing"
    end

    local _, _, tracked = IT_ResolveTrackedInterruptSpellID(spellID)
    if not tracked then
        IT_DebugTrace(debugEnabled,
            "remote solar_beam fromAddon promotion blocked",
            "reason=invalid_interrupt_spell",
            "spellID=", spellID or "nil")
        return false, "invalid_interrupt_spell"
    end

    member.fromAddon = true
    IT_DebugTrace(debugEnabled,
        "remote solar_beam fromAddon promotion succeeded",
        "spellID=", spellID or "nil")
    return true, "promoted"
end

function InterruptTracker:ResetTalentDerivedInterruptFields(member)
    if not member then
        return
    end
    member.onKickReduction = nil
    member.hasLightOfTheSun = false
    member.requiresPrimaryTargetConfirm = false
    member.primaryTargetOnKickReduction = nil
    member.hasColdthirst = false
    member.requiresOwnerInterruptConfirm = false
    member.ownerInterruptReduction = nil
end

function InterruptTracker:RebuildCanonicalPrimaryState(member, specID, unit)
    if not member then
        return false
    end

    local preferredSpellID = (unit == "player") and tonumber(member.spellID) or nil
    member.spellID = nil
    member.baseCd = nil
    member.isPetSpell = false
    member.petSpellID = nil
    member.icon = nil

    if specID and IT_SPEC_NO_INTERRUPT[specID] then
        return false
    end

    if preferredSpellID and (IT_INTERRUPTS[preferredSpellID] or IT_INTERRUPTS_STR[tostring(preferredSpellID)]) then
        member.spellID = preferredSpellID
        member.baseCd = IT_GetCanonicalInterruptBaseCd(preferredSpellID)
        member.icon = IT_GetPrimaryIcon(preferredSpellID)
        local override = specID and IT_SPEC_OVERRIDE[specID] or nil
        if override and override.id == preferredSpellID then
            if not self:ApplySpecOverride(member, specID, unit) then
                return false
            end
        end
    else
        local classDefault = IT_GetClassDefaultInterrupt(member.class)
        if classDefault then
            member.spellID = classDefault.spellID
            member.baseCd = IT_GetCanonicalInterruptBaseCd(classDefault.spellID, classDefault.baseCd)
            member.icon = classDefault.icon or IT_GetPrimaryIcon(classDefault.spellID)
        end

        if specID and not self:ApplySpecOverride(member, specID, unit) then
            return false
        end
    end

    if not member.spellID then
        return false
    end

    member.baseCd = IT_GetCanonicalInterruptBaseCd(member.spellID, member.baseCd) or 15
    member.icon = member.icon or IT_GetPrimaryIcon(member.spellID)
    return true
end

function InterruptTracker:ApplyMemberTalent(defSpellID, member, specID)
    local permanent = IT_TrySecretLookup(IT_PERMANENT_CD_TALENTS, IT_PERMANENT_CD_TALENTS_STR, defSpellID)
    if permanent and member.spellID == permanent.affects then
        if permanent.pctReduction then
            member.baseCd = math.max(1, math.floor(((member.baseCd or 15) * (1 - permanent.pctReduction / 100)) + 0.5))
        elseif permanent.reduction then
            member.baseCd = math.max(1, (member.baseCd or 15) - permanent.reduction)
        end
    end

    local ownerConfirmed = IT_TrySecretLookup(IT_OWNER_CONFIRMED_TALENTS, IT_OWNER_CONFIRMED_TALENTS_STR, defSpellID)
    if ownerConfirmed then
        if member.spellID == ownerConfirmed.affects then
            if ownerConfirmed.kind == "light_of_the_sun" then
                member.hasLightOfTheSun = true
                member.requiresPrimaryTargetConfirm = true
                member.primaryTargetOnKickReduction = ownerConfirmed.reduction
            elseif ownerConfirmed.kind == "coldthirst" then
                member.hasColdthirst = true
                member.requiresOwnerInterruptConfirm = true
                member.ownerInterruptReduction = ownerConfirmed.reduction
            end
        end
    else
        local onKick = IT_TrySecretLookup(IT_ON_SUCCESS_TALENTS, IT_ON_SUCCESS_TALENTS_STR, defSpellID)
        if onKick then
            member.onKickReduction = onKick.reduction
        end
    end

    local specExtraKicks = specID and IT_GetSpecExtraKicks(specID) or nil
    if specExtraKicks then
        member.extraKicks = member.extraKicks or {}
        local matchingExtras = IT_GetExtraKicksForTalent(defSpellID)
        if matchingExtras then
            for _, match in ipairs(matchingExtras) do
                if match.specID == specID then
                    local extra = match.extra
                    local found = false
                    for _, existing in ipairs(member.extraKicks) do
                        if existing.spellID == extra.id then
                            found = true
                            break
                        end
                    end
                    if not found then
                        member.extraKicks[#member.extraKicks + 1] = {
                            spellID = extra.id,
                            baseCd = extra.cd,
                            cdEnd = 0,
                            name = extra.name,
                            icon = IT_GetExtraKickIcon(extra),
                        }
                    end
                end
            end
        end
    end
end

function InterruptTracker:ApplySpecOverride(member, specID, unit)
    if specID and IT_SPEC_NO_INTERRUPT[specID] then
        return false
    end
    local override = specID and IT_SPEC_OVERRIDE[specID] or nil
    if not override then
        return true
    end
    local applyOverride = true
    if override.isPet then
        local petUnit = nil
        if unit == "player" then
            petUnit = "pet"
        else
            local roster = self:GetUnitForMember(member.name)
            petUnit = roster and roster.petUnit or nil
        end
        local family = petUnit and UnitExists(petUnit) and UnitCreatureFamily and UnitCreatureFamily(petUnit) or nil
        if override.requiredFamily and family ~= override.requiredFamily then
            applyOverride = false
        end
        if petUnit and not UnitExists(petUnit) then
            applyOverride = false
        end
    end
    if applyOverride then
        member.spellID = override.id
        member.baseCd = override.cd
        member.isPetSpell = override.isPet and true or false
        member.petSpellID = override.petSpellID
        member.icon = override.petSpellID and IT_SafeSpellTexture(override.petSpellID) or IT_GetPrimaryIcon(override.id)
    else
        member.spellID = 19647
        member.baseCd = (IT_INTERRUPTS[19647] and IT_INTERRUPTS[19647].cd) or 24
        member.isPetSpell = false
        member.petSpellID = nil
        member.icon = IT_GetPrimaryIcon(19647)
    end
    return true
end

function InterruptTracker:ScanInspectTalentsInternal(unit)
    local name = IT_SafeUnitName(unit)
    if not name then
        return
    end
    local member = self:GetMemberRecord(name, false)
    if not member then
        member = self:EnsureMemberRecordFromUnit(unit, name)
    end
    if not member then
        return
    end
    local beforeSeedState = self:CaptureSeedState(member)

    local working = {
        name = member.name,
        class = member.class,
        spellID = nil,
        baseCd = nil,
        cdEnd = member.cdEnd,
        fromAddon = member.fromAddon,
        addonPrimarySpellID = member.addonPrimarySpellID,
        addonPrimaryBaseCd = member.addonPrimaryBaseCd,
        addonPrimarySeenAt = member.addonPrimarySeenAt,
        extraKicks = member.extraKicks,
        onKickReduction = nil,
        hasLightOfTheSun = false,
        requiresPrimaryTargetConfirm = false,
        primaryTargetOnKickReduction = nil,
        hasColdthirst = false,
        requiresOwnerInterruptConfirm = false,
        ownerInterruptReduction = nil,
        isPetSpell = false,
        petSpellID = nil,
        unitGUID = IT_NormalizeSafeString(member.unitGUID) or IT_SafeUnitGUID(unit),
        icon = nil,
        lastActivityAt = member.lastActivityAt,
        offlineSinceAt = member.offlineSinceAt,
        lastDeathAt = member.lastDeathAt,
        lastDeadOrGhost = member.lastDeadOrGhost,
        fullWipeRecoverySeenAt = member.fullWipeRecoverySeenAt,
    }
    self:ResetTalentDerivedInterruptFields(working)

    local specID = GetInspectSpecialization and GetInspectSpecialization(unit) or 0
    local resolvedSpecID = (specID and specID > 0) and specID or member.specID
    if resolvedSpecID and resolvedSpecID > 0 then
        working.specID = resolvedSpecID
        working.specName = IT_GetSpecName(resolvedSpecID)
    end
    local debugRemoteSolarBeam = IT_ShouldDebugSolarBeamRemote(member, member and (member.addonPrimarySpellID or member.spellID) or nil, resolvedSpecID)
    local specPrimaryState = nil
    if resolvedSpecID and resolvedSpecID > 0 then
        specPrimaryState = self:ResolveSpecBasedCanonicalPrimary(working, resolvedSpecID, unit)
    end
    self:InvalidateStoredAddonPrimaryIfSpecConflicts(working, specPrimaryState, debugRemoteSolarBeam, "inspect_rebuild")

    local storedAddonState = self:GetStoredAddonPrimaryState(working)
    if working.fromAddon and storedAddonState and not specPrimaryState then
        working.spellID = storedAddonState.spellID
        working.baseCd = storedAddonState.baseCd
        working.icon = storedAddonState.icon
    elseif not self:RebuildCanonicalPrimaryState(working, resolvedSpecID, unit) then
        if resolvedSpecID and IT_SPEC_NO_INTERRUPT[resolvedSpecID] then
            self.noInterruptPlayers[name] = working.unitGUID or true
            self:ClearInterruptCountRecordsForMember(name, working.unitGUID)
            self:ClearFullWipeRecordsForMember(member)
            self.trackedMembers[name] = nil
            self.inspectedPlayers[name] = working.unitGUID or true
            if self:DidSeedStateChange(beforeSeedState, nil) then
                self:ReseedModeBOrder(true)
            end
            return
        end
        return
    end

    local okConfig, configInfo = pcall(C_Traits.GetConfigInfo, -1)
    if okConfig and configInfo and configInfo.treeIDs and configInfo.treeIDs[1] then
        local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, configInfo.treeIDs[1])
        if okNodes and type(nodeIDs) == "table" then
            for _, nodeID in ipairs(nodeIDs) do
                local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, -1, nodeID)
                if okNode and nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
                    local entryID = nodeInfo.activeEntry.entryID
                    local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, -1, entryID)
                    if okEntry and entryInfo and entryInfo.definitionID then
                        local okDef, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                        if okDef and defInfo and defInfo.spellID then
                            self:ApplyMemberTalent(defInfo.spellID, working, resolvedSpecID)
                        end
                    end
                end
            end
        end
    end

    self:CopyInterruptEntry(member, working)
    self.inspectedPlayers[name] = working.unitGUID or true
    if self:DidSeedStateChange(beforeSeedState, member) then
        self:ReseedModeBOrder(true)
    end
end

function InterruptTracker:CancelInspectTimeout()
    if self.inspectTimeoutTimer then
        self.inspectTimeoutTimer:Cancel()
        self.inspectTimeoutTimer = nil
    end
end

function InterruptTracker:CancelInspectStepTimer()
    if self.inspectStepTimer then
        self.inspectStepTimer:Cancel()
        self.inspectStepTimer = nil
    end
end

function InterruptTracker:IsInspectContextSafe()
    return not (InCombatLockdown and InCombatLockdown())
end

function InterruptTracker:ClearInspectSessionState()
    self:CancelInspectTimeout()
    if self.inspectBusy or self.inspectUnit or self.inspectTargetGUID or self.inspectTargetName then
        pcall(ClearInspectPlayer)
    end
    self.inspectBusy = false
    self.inspectUnit = nil
    self.inspectTargetGUID = nil
    self.inspectTargetName = nil
end

function InterruptTracker:DoesInspectReadyMatchActiveTarget(inspectedGUID)
    if not self.inspectBusy or not self.inspectUnit then
        return false
    end

    local activeGUID = IT_NormalizeSafeString(self.inspectTargetGUID)
    local readyGUID = IT_NormalizeSafeString(inspectedGUID)
    if activeGUID and readyGUID then
        return IT_SafeStringsEqual(activeGUID, readyGUID)
    end
    if activeGUID and readyGUID == nil then
        local liveGUID = IT_SafeUnitGUID(self.inspectUnit)
        if liveGUID and IT_SafeStringsEqual(activeGUID, liveGUID) then
            return true
        end
    end

    local activeName = IT_NormalizeName(self.inspectTargetName)
    local liveName = IT_SafeUnitName(self.inspectUnit)
    if activeName and liveName then
        return IT_SafeStringsEqual(activeName, liveName)
    end

    return activeGUID == nil and activeName == nil
end

function InterruptTracker:ScheduleInspectQueueStep(delaySeconds)
    self:CancelInspectStepTimer()
    if not self:ShouldRunPeriodicInspect() then
        return
    end
    local delay = tonumber(delaySeconds) or IT_INSPECT_STEP_DELAY
    if not (C_Timer and C_Timer.NewTimer) then
        self:ProcessInspectQueue()
        return
    end
    self.inspectStepTimer = C_Timer.NewTimer(delay, function()
        PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_inspect_step")
        local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
        self.inspectStepTimer = nil
        self:ProcessInspectQueue()
        PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
    end)
end

function InterruptTracker:AbortInspectSession(scheduleResume)
    self:ClearInspectSessionState()
    if scheduleResume then
        self:ScheduleInspectQueueStep()
    end
end

function InterruptTracker:ArmInspectTimeout(expectedGUID, expectedName)
    self:CancelInspectTimeout()
    self.inspectTimeoutTimer = C_Timer.NewTimer(IT_INSPECT_TIMEOUT, function()
        local activeGUID = IT_NormalizeSafeString(self.inspectTargetGUID)
        local targetGUID = IT_NormalizeSafeString(expectedGUID)
        if targetGUID and activeGUID and not IT_SafeStringsEqual(activeGUID, targetGUID) then
            return
        end
        local activeName = IT_NormalizeName(self.inspectTargetName)
        local targetName = IT_NormalizeName(expectedName)
        if targetName and activeName and not IT_SafeStringsEqual(activeName, targetName) then
            return
        end
        self:AbortInspectSession(true)
    end)
end

function InterruptTracker:GetQueuedInspectIdentity(unit)
    if not (unit and UnitExists(unit)) then
        return nil, nil
    end
    if UnitIsConnected and not UnitIsConnected(unit) then
        return nil, nil
    end
    local name = IT_SafeUnitName(unit)
    if not name or self.inspectedPlayers[name] then
        return nil, nil
    end
    return name, IT_SafeUnitGUID(unit)
end

function InterruptTracker:ProcessInspectQueue()
    if not self:ShouldRunPeriodicInspect() then
        self.inspectQueue = {}
        self:AbortInspectSession(false)
        return
    end
    if self.inspectBusy then
        return
    end
    if not self:IsInspectContextSafe() then
        return
    end
    while #self.inspectQueue > 0 do
        local unit = table.remove(self.inspectQueue, 1)
        local name, guid = self:GetQueuedInspectIdentity(unit)
        if name and PA_CanSafelyInspectUnit(unit) then
            self.inspectBusy = true
            self.inspectUnit = unit
            self.inspectTargetName = name
            self.inspectTargetGUID = guid
            local ok = pcall(NotifyInspect, unit)
            if ok then
                self:ArmInspectTimeout(guid, name)
                return
            end
            self:AbortInspectSession(false)
        end
    end
end

function InterruptTracker:QueuePartyInspect(targetUnit)
    if not self:ShouldRunPeriodicInspect() then
        self.inspectQueue = {}
        return
    end
    self:BuildUnitMap()
    local nextQueue = {}
    local seenNames = {}
    local seenGUIDs = {}

    local function queueUnit(unit)
        local name, guid = self:GetQueuedInspectIdentity(unit)
        if not name then
            return
        end
        if self.inspectTargetName and IT_SafeStringsEqual(self.inspectTargetName, name) then
            return
        end
        if guid and self.inspectTargetGUID and IT_SafeStringsEqual(self.inspectTargetGUID, guid) then
            return
        end
        if seenNames[name] or (guid and seenGUIDs[guid]) then
            return
        end
        nextQueue[#nextQueue + 1] = unit
        seenNames[name] = true
        if guid then
            seenGUIDs[guid] = true
        end
    end

    if targetUnit then
        queueUnit(targetUnit)
    else
        for i = 1, 4 do
            queueUnit("party" .. i)
        end
    end
    self.inspectQueue = nextQueue
    self:ProcessInspectQueue()
end

function InterruptTracker:QueuePartyInspectDelayed(targetUnit)
    self:CancelInspectStepTimer()
    if self.inspectDelayTimer then
        self.inspectDelayTimer:Cancel()
        self.inspectDelayTimer = nil
    end
    if not self:ShouldRunPeriodicInspect() then
        return
    end
    self.inspectDelayTimer = C_Timer.NewTimer(IT_QUEUE_INSPECT_DELAY, function()
        PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_inspect_delay")
        local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
        self.inspectDelayTimer = nil
        self:QueuePartyInspect(targetUnit)
        PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
    end)
end

function InterruptTracker:ResetInspectStateFor(name)
    if name then
        name = IT_NormalizeName(name)
        if name then
            self.inspectedPlayers[name] = nil
        end
    else
        wipe(self.inspectedPlayers)
    end
end

function InterruptTracker:CleanupRosterState()
    self:BuildUnitMap()
    local current = {}
    for _, entry in ipairs(self:GetCurrentRoster(true)) do
        if entry.name then
            current[entry.name] = entry
        end
    end
    if not self:IsTrackedPartyContext() then
        wipe(self.trackedMembers or {})
        wipe(self.noInterruptPlayers or {})
        wipe(self.inspectedPlayers or {})
        wipe(self.recentPartyCasts or {})
        self:ClearPendingOwnerPrimaryCast()
        if self.interruptCounts then
            wipe(self.interruptCounts)
        end
        if self.recentCountedInterruptsByMember then
            wipe(self.recentCountedInterruptsByMember)
        end
        self:ResetFullWipeRecoveryState()
        self:ClearOwnerInterruptPending()
        if self.rowReadyState then
            for name in pairs(self.rowReadyState) do
                if not self.selfState or self.selfState.name ~= name then
                    self.rowReadyState[name] = nil
                end
            end
        end
        if self.inspectDelayTimer then
            self.inspectDelayTimer:Cancel()
            self.inspectDelayTimer = nil
        end
        self.inspectQueue = {}
        self:CancelInspectStepTimer()
        self:AbortInspectSession(false)
        return
    end

    local rosterChanged = false
    for name in pairs(self.trackedMembers or {}) do
        local liveEntry = current[name]
        local member = self.trackedMembers[name]
        local guidMismatch = member and member.unitGUID and liveEntry and liveEntry.guid and not IT_SafeStringsEqual(member.unitGUID, liveEntry.guid)
        if (not liveEntry) or guidMismatch then
            if self:MemberQualifiesForSeed(member) then
                rosterChanged = true
            end
            self:ClearInterruptCountRecordsForMember(name, member and member.unitGUID or nil)
            self:ClearFullWipeRecordsForMember(member)
            self.trackedMembers[name] = nil
            self.recentPartyCasts[name] = nil
            self.noInterruptPlayers[name] = nil
            self.inspectedPlayers[name] = nil
            if self.interruptCounts then
                self.interruptCounts[name] = nil
            end
        elseif liveEntry.guid and member and not IT_NormalizeSafeString(member.unitGUID) then
            member.unitGUID = IT_NormalizeSafeString(liveEntry.guid)
        end
    end
    for name, blockedValue in pairs(self.noInterruptPlayers or {}) do
        local liveEntry = current[name]
        if (not liveEntry) or (IT_NormalizeSafeString(blockedValue) and liveEntry.guid and not IT_SafeStringsEqual(blockedValue, liveEntry.guid)) then
            self.noInterruptPlayers[name] = nil
        end
    end
    for name, inspectedValue in pairs(self.inspectedPlayers or {}) do
        local liveEntry = current[name]
        if (not liveEntry) or (IT_NormalizeSafeString(inspectedValue) and liveEntry.guid and not IT_SafeStringsEqual(inspectedValue, liveEntry.guid)) then
            self.inspectedPlayers[name] = nil
        end
    end
    for name in pairs(self.recentPartyCasts or {}) do
        if not current[name] then
            self.recentPartyCasts[name] = nil
        end
    end
    for name in pairs(self.rowReadyState or {}) do
        if not current[name] and (not self.selfState or self.selfState.name ~= name) then
            self.rowReadyState[name] = nil
        end
    end
    if self.inspectQueue and #self.inspectQueue > 0 then
        local nextQueue = {}
        for _, unit in ipairs(self.inspectQueue) do
            local queuedName = UnitExists(unit) and IT_SafeUnitName(unit) or nil
            local queuedGuid = UnitExists(unit) and IT_SafeUnitGUID(unit) or nil
            if queuedName and current[queuedName] and ((not queuedGuid) or (not current[queuedName].guid) or IT_SafeStringsEqual(current[queuedName].guid, queuedGuid)) then
                nextQueue[#nextQueue + 1] = unit
            end
        end
        self.inspectQueue = nextQueue
    end
    if self.inspectUnit then
        local inspectName = UnitExists(self.inspectUnit) and IT_SafeUnitName(self.inspectUnit) or nil
        local activeGuid = IT_NormalizeSafeString(self.inspectTargetGUID)
        local liveEntry = inspectName and current[inspectName] or nil
        if (not inspectName) or (not liveEntry) or (activeGuid and liveEntry.guid and not IT_SafeStringsEqual(activeGuid, liveEntry.guid)) then
            self:AbortInspectSession(true)
        end
    end
    if rosterChanged then
        self:ReseedModeBOrder(true)
    end
end

function InterruptTracker:AutoRegisterUnitByClass(unit, ignoreRoleFilter)
    if not unit or not UnitExists(unit) then
        return false
    end
    if unit ~= "player" and UnitIsConnected and not UnitIsConnected(unit) then
        return false
    end
    local name = IT_SafeUnitName(unit)
    local classFile = IT_SafeUnitClass(unit)
    if not name or not classFile then
        return false
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
    local kick = classFile and IT_CLASS_PRIMARY[classFile] or nil
    if (not kick) and classFile and type(IT_CLASS_INTERRUPT_LIST[classFile]) == "table" then
        local fallbackSpellID = IT_CLASS_INTERRUPT_LIST[classFile][1]
        local fallbackData = fallbackSpellID and IT_INTERRUPTS[fallbackSpellID] or nil
        if fallbackData then
            kick = {
                id = fallbackSpellID,
                cd = fallbackData.cd,
                name = fallbackData.name,
            }
        end
    end
    if not kick then
        return false
    end
    if (not ignoreRoleFilter) and role == "HEALER" and not IT_HEALER_KEEPS_KICK[classFile] then
        local previousMember = self.trackedMembers[name]
        if self:MemberQualifiesForSeed(previousMember) then
            self:ClearInterruptCountRecordsForMember(name, previousMember and previousMember.unitGUID or nil)
            self:ClearFullWipeRecordsForMember(previousMember)
            self.trackedMembers[name] = nil
            self.noInterruptPlayers[name] = IT_SafeUnitGUID(unit) or true
            return true
        end
        self:ClearInterruptCountRecordsForMember(name, previousMember and previousMember.unitGUID or nil)
        self:ClearFullWipeRecordsForMember(previousMember)
        self.trackedMembers[name] = nil
        self.noInterruptPlayers[name] = IT_SafeUnitGUID(unit) or true
        return false
    end
    if (not ignoreRoleFilter) and self.noInterruptPlayers[name] then
        return false
    end
    local member = self:GetMemberRecord(name, true)
    local beforeSeedState = self:CaptureSeedState(member)
    local unitGUID = IT_SafeUnitGUID(unit)
    if unitGUID then
        member.unitGUID = unitGUID
    end
    member.class = classFile
    if not member.fromAddon then
        member.spellID = kick.id
        member.baseCd = IT_GetCanonicalInterruptBaseCd(kick.id, kick.cd) or 15
        member.icon = IT_GetPrimaryIcon(kick.id)
        self:ResetTalentDerivedInterruptFields(member)
        member.extraKicks = member.extraKicks or {}
        member.fromAddon = false
    end
    return self:DidSeedStateChange(beforeSeedState, member)
end

function InterruptTracker:AutoRegisterPartyByClass()
    self:BuildUnitMap()
    local seedChanged = false
    for i = 1, 4 do
        if self:AutoRegisterUnitByClass("party" .. i) then
            seedChanged = true
        end
    end
    self:CleanupRosterState()
    if seedChanged then
        self:ReseedModeBOrder(true)
    end
end

function InterruptTracker:ReadSelfTalentData(member, configID)
    if not configID then
        return
    end
    local okConfig, configInfo = pcall(C_Traits.GetConfigInfo, configID)
    if not okConfig or not configInfo or not configInfo.treeIDs or not configInfo.treeIDs[1] then
        return
    end
    local okNodes, nodeIDs = pcall(C_Traits.GetTreeNodes, configInfo.treeIDs[1])
    if not okNodes or type(nodeIDs) ~= "table" then
        return
    end
    for _, nodeID in ipairs(nodeIDs) do
        local okNode, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
        if okNode and nodeInfo and nodeInfo.activeEntry and nodeInfo.activeRank and nodeInfo.activeRank > 0 then
            local entryID = nodeInfo.activeEntry.entryID
            local okEntry, entryInfo = pcall(C_Traits.GetEntryInfo, configID, entryID)
            if okEntry and entryInfo and entryInfo.definitionID then
                local okDef, defInfo = pcall(C_Traits.GetDefinitionInfo, entryInfo.definitionID)
                if okDef and defInfo and defInfo.spellID then
                    self:ApplyMemberTalent(defInfo.spellID, member, member.specID)
                end
            end
        end
    end
end

function InterruptTracker:DetectPetSpellAvailable(spellID, petSpellID)
    if not spellID then
        return false
    end
    if IsSpellKnown and IsSpellKnown(spellID, true) then
        return true
    end
    if petSpellID and IsSpellKnown and IsSpellKnown(petSpellID, true) then
        return true
    end
    if IsSpellKnown and IsSpellKnown(spellID) then
        return true
    end
    local okPlayerSpell, isKnown = pcall(IsPlayerSpell, spellID)
    if okPlayerSpell and isKnown then
        return true
    end
    if petSpellID and UnitExists("pet") then
        local okPetPlayer, petKnown = pcall(IsPlayerSpell, petSpellID)
        if okPetPlayer and petKnown then
            return true
        end
    end
    return false
end

function InterruptTracker:FindMyInterrupt()
    self.playerName = IT_NormalizeName(UnitName("player"))
    self.playerClass = select(2, UnitClass("player"))
    self:ClearOwnerInterruptPending()
    self:ClearPendingOwnerPrimaryCast()

    local oldState = self.selfState or {}
    local beforeSeedState = self:CaptureSeedState(oldState)
    local member = {
        name = self.playerName,
        class = self.playerClass,
        fromAddon = true,
        isSelf = true,
        extraKicks = {},
        cdEnd = oldState.cdEnd or 0,
        baseCd = nil,
        onKickReduction = nil,
        hasLightOfTheSun = false,
        requiresPrimaryTargetConfirm = false,
        primaryTargetOnKickReduction = nil,
        hasColdthirst = false,
        requiresOwnerInterruptConfirm = false,
        ownerInterruptReduction = nil,
        lastActivityAt = oldState.lastActivityAt or 0,
        offlineSinceAt = nil,
        unitGUID = IT_NormalizeSafeString(oldState.unitGUID) or IT_SafeUnitGUID("player"),
        lastDeathAt = tonumber(oldState.lastDeathAt) or 0,
        lastDeadOrGhost = oldState.lastDeadOrGhost and true or false,
        fullWipeRecoverySeenAt = tonumber(oldState.fullWipeRecoverySeenAt) or 0,
    }

    local specIndex = GetSpecialization and GetSpecialization() or nil
    local specID = specIndex and GetSpecializationInfo(specIndex) or nil
    member.specID = specID
    member.specName = IT_GetSpecName(specID)

    local override = specID and IT_SPEC_OVERRIDE[specID] or nil
    if override and override.isPet then
        local family = UnitExists("pet") and UnitCreatureFamily and UnitCreatureFamily("pet") or nil
        local available = self:DetectPetSpellAvailable(override.id, override.petSpellID)
        if available and (not override.requiredFamily or family == override.requiredFamily) then
            member.spellID = override.id
        end
    elseif override then
        member.spellID = override.id
    end

    local specExtraKicks = specID and IT_GetSpecExtraKicks(specID) or nil
    if specExtraKicks then
        for _, extra in ipairs(specExtraKicks) do
            local checkID = extra.talentCheck or extra.id
            local known = false
            if IsSpellKnown and IsSpellKnown(checkID, true) then
                known = true
            elseif extra.petSpellID and IsSpellKnown and IsSpellKnown(extra.petSpellID, true) then
                known = true
            elseif IsSpellKnown and IsSpellKnown(checkID) then
                known = true
            else
                local okKnown, playerKnown = pcall(IsPlayerSpell, checkID)
                known = okKnown and playerKnown or false
                if not known and extra.petSpellID and UnitExists("pet") then
                    local okPetKnown, petKnown = pcall(IsPlayerSpell, extra.petSpellID)
                    known = okPetKnown and petKnown or false
                end
            end
            if known then
                local oldCd = 0
                for _, oldExtra in ipairs(oldState.extraKicks or {}) do
                    if oldExtra.spellID == extra.id then
                        oldCd = oldExtra.cdEnd or 0
                        break
                    end
                end
                member.extraKicks[#member.extraKicks + 1] = {
                    spellID = extra.id,
                    baseCd = extra.cd,
                    cdEnd = oldCd,
                    name = extra.name,
                    icon = IT_GetExtraKickIcon(extra),
                }
            end
        end
    end

    local managedExtras = {}
    if specExtraKicks then
        for _, extra in ipairs(specExtraKicks) do
            managedExtras[extra.id] = true
        end
    end
    for _, spellID in ipairs(IT_CLASS_INTERRUPT_LIST[self.playerClass] or {}) do
        local known = (IsSpellKnown and (IsSpellKnown(spellID) or IsSpellKnown(spellID, true))) and true or false
        if not known then
            local okKnown, playerKnown = pcall(IsPlayerSpell, spellID)
            known = okKnown and playerKnown or false
        end
        if known then
            if not member.spellID then
                member.spellID = spellID
            elseif spellID ~= member.spellID and not managedExtras[spellID] then
                local existing = false
                for _, extra in ipairs(member.extraKicks) do
                    if extra.spellID == spellID then
                        existing = true
                        break
                    end
                end
                if not existing then
                    local data = IT_INTERRUPTS[spellID]
                    local oldCd = 0
                    for _, oldExtra in ipairs(oldState.extraKicks or {}) do
                        if oldExtra.spellID == spellID then
                            oldCd = oldExtra.cdEnd or 0
                            break
                        end
                    end
                    member.extraKicks[#member.extraKicks + 1] = {
                        spellID = spellID,
                        baseCd = data and data.cd or 15,
                        cdEnd = oldCd,
                        name = data and data.name or "Interrupt",
                        icon = IT_GetPrimaryIcon(spellID),
                    }
                end
            end
        end
    end

    if self:RebuildCanonicalPrimaryState(member, specID, "player") then
        if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
            local okConfig, configID = pcall(C_ClassTalents.GetActiveConfigID)
            if okConfig and configID then
                self:ReadSelfTalentData(member, configID)
            end
        end
    else
        member.spellID = nil
        member.baseCd = nil
        member.isPetSpell = false
        member.petSpellID = nil
        member.icon = nil
    end

    self.selfState = member
    self:CleanupRosterState()
    if self:DidSeedStateChange(beforeSeedState, member) then
        self:ReseedModeBOrder(true)
    end
end

function InterruptTracker:ApplyOnKickReduction(member)
    if not member or not member.onKickReduction then
        return
    end
    local now = GetTime()
    member.cdEnd = math.max(now, (tonumber(member.cdEnd) or now) - tonumber(member.onKickReduction or 0))
end

function InterruptTracker:ShouldIgnoreStaleNormalCastAfterAdj(member, spellID, cooldownSeconds, now)
    local resolvedSpellID = tonumber(spellID) or 0
    if not member or not IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS[resolvedSpellID] then
        return false
    end
    self:ExpireAdjGuard(member, now)
    if member.lastAdjSpellID ~= resolvedSpellID then
        return false
    end
    if (tonumber(member.lastAdjIgnoreCastUntil) or 0) < (tonumber(now) or GetTime()) then
        return false
    end
    local proposedCdEnd = (tonumber(now) or GetTime()) + math.max(0, tonumber(cooldownSeconds) or 0)
    return proposedCdEnd > math.max(0, tonumber(member.cdEnd) or 0)
end

function InterruptTracker:HandleConfirmedExtraKick(member, spellID, source)
    if not member or not member.extraKicks then
        return false
    end
    local resolvedSpellID = IT_SPELL_ALIASES[spellID] or spellID
    for _, extra in ipairs(member.extraKicks) do
        if extra.spellID == spellID or extra.spellID == resolvedSpellID then
            local now = GetTime()
            extra.cdEnd = now + (tonumber(extra.baseCd) or 0)
            self:TryCountInterrupt(member, extra.spellID, source or "local_detect", now)
            self:MarkFullWipeRecoveryEvidence(member, now)
            if PA_CpuDiagIsFrameConsideredShown("interrupt", self.frame) then
                self:UpdateDisplay()
            end
            return extra
        end
    end
    return false
end

function InterruptTracker:NormalizeLocalSelfSpellcastEvent(event, ...)
    return nil
end

function InterruptTracker:DebugSolarBeamSelfEvent(member, eventInfo)
    return
end

function InterruptTracker:EmitSolarBeamSelfCastVerdict(member, spellID, validInterrupt, broadcastCalled, localHandleCalled, verdict, castGUID)
    return
end

function InterruptTracker:CancelPendingOwnerPrimaryCastExpiry()
    if self.pendingOwnerPrimaryCastExpiryTimer then
        self.pendingOwnerPrimaryCastExpiryTimer:Cancel()
        self.pendingOwnerPrimaryCastExpiryTimer = nil
    end
end

function InterruptTracker:ClearPendingOwnerPrimaryCast()
    self:CancelPendingOwnerPrimaryCastExpiry()
    self.pendingOwnerPrimaryCast = nil
    self.lastHandledOwnerPrimaryCastGUID = nil
    self.lastHandledOwnerPrimaryCastAt = 0
    self.lastOwnerPrimaryCastVerdictGUID = nil
    self.lastOwnerPrimaryCastVerdictAt = 0
end

function InterruptTracker:ExpirePendingOwnerPrimaryCast(now)
    self:ClearPendingOwnerPrimaryCast()
end

function InterruptTracker:HasHandledOwnerPrimaryCast(castGUID)
    return false
end

function InterruptTracker:MarkHandledOwnerPrimaryCast(castGUID)
    return
end

function InterruptTracker:ArmPendingOwnerPrimaryCast(member, eventInfo, now)
    return false
end

function InterruptTracker:InvalidatePendingOwnerPrimaryCast(member, castGUID, reason)
    return false
end

function InterruptTracker:HandleLocalPrimaryUseFromEvent(member, eventInfo)
    return false
end

function InterruptTracker:TryHealPrimaryFromAuthoritativeCast(member, spellID)
    if not member then
        return false, "member_unknown"
    end

    local incomingSpellID, resolvedSpellID, tracked = IT_ResolveTrackedInterruptSpellID(spellID)
    if not tracked then
        return false, "invalid_interrupt_spell"
    end
    if not member.fromAddon then
        return false, "not_addon_backed"
    end
    if member.class == "WARLOCK" then
        return false, "warlock_excluded"
    end

    local unit = self:GetMemberUnitToken(member)
    local specPrimaryState, specReason = self:ResolveAuthoritativeSpecBasedCanonicalPrimary(member, unit)
    local storedPrimaryState, storedReason = self:GetStoredAddonPrimaryState(member)

    if storedPrimaryState and specPrimaryState and (tonumber(storedPrimaryState.spellID) or 0) ~= (tonumber(specPrimaryState.spellID) or 0) then
        storedPrimaryState = nil
        storedReason = "stored_primary_invalid"
    end

    if storedPrimaryState then
        if storedPrimaryState.spellID == incomingSpellID or storedPrimaryState.spellID == resolvedSpellID then
            member.spellID = storedPrimaryState.spellID
            member.baseCd = storedPrimaryState.baseCd
            member.icon = storedPrimaryState.icon or IT_GetPrimaryIcon(storedPrimaryState.spellID)
            return true, "accepted_stored_addon_primary"
        end
        storedReason = "stored_primary_mismatch"
    end

    if specPrimaryState then
        if specPrimaryState.spellID == incomingSpellID or specPrimaryState.spellID == resolvedSpellID then
            member.spellID = specPrimaryState.spellID
            member.baseCd = specPrimaryState.baseCd
            member.icon = specPrimaryState.icon or IT_GetPrimaryIcon(specPrimaryState.spellID)
            return true, "accepted_canonical_resolution"
        end
        return false, "canonical_mismatch"
    end

    if storedReason then
        return false, storedReason
    end
    if specReason == "spec_missing" then
        return false, "spec_missing"
    end
    return false, "no_authoritative_primary"
end

function InterruptTracker:HandleConfirmedPrimaryUse(member, cooldownSeconds, source)
    if not member or not member.spellID then
        return
    end
    local now = GetTime()
    local cd = tonumber(cooldownSeconds) or member.baseCd or tonumber((IT_INTERRUPTS[member.spellID] or {}).cd) or 15
    member.cdEnd = now + cd
    member.pendingOnKickReduction = (not IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS[tonumber(member.spellID) or 0] and member.onKickReduction) and true or false
    member.lastConfirmedAt = now
    if member.isSelf then
        self.selfLastPrimaryCastAt = now
        self:ClearOwnerInterruptPending()
    end
    self:TryCountInterrupt(member, member.spellID, source or "local_detect", now)
    self:MarkFullWipeRecoveryEvidence(member, now)
    if PA_CpuDiagIsFrameConsideredShown("interrupt", self.frame) then
        self:UpdateDisplay()
    end
end

function InterruptTracker:GetRecentPartyCastRecord(name)
    local normalizedName = IT_NormalizeName(name)
    if not normalizedName then
        return nil
    end

    local rawRecord = self.recentPartyCasts and self.recentPartyCasts[normalizedName] or nil
    if type(rawRecord) == "number" then
        return {
            at = tonumber(rawRecord) or 0,
            spellID = 0,
            source = "legacy",
            started = false,
        }
    end
    if type(rawRecord) ~= "table" then
        return nil
    end

    return {
        at = tonumber(rawRecord.at) or 0,
        spellID = IT_NormalizeSpellID(rawRecord.spellID),
        source = IT_NormalizeSafeString(rawRecord.source) or "fallback",
        started = rawRecord.started and true or false,
    }
end

function InterruptTracker:RecordRecentPartyCast(name, spellID, source, started, timestamp)
    local normalizedName = IT_NormalizeName(name)
    if not normalizedName then
        return nil
    end

    self.recentPartyCasts = self.recentPartyCasts or {}
    local existing = self:GetRecentPartyCastRecord(normalizedName) or {}
    local normalizedSpellID = IT_NormalizeSpellID(spellID)
    local record = {
        at = tonumber(timestamp) or GetTime(),
        spellID = normalizedSpellID > 0 and normalizedSpellID or (tonumber(existing.spellID) or 0),
        source = IT_NormalizeSafeString(source) or existing.source or "fallback",
        started = (started and true) or (existing.started and true) or false,
    }
    self.recentPartyCasts[normalizedName] = record
    return record
end

function InterruptTracker:RecentPartyCastMatchesSpell(record, spellID)
    if type(record) ~= "table" then
        return false
    end

    local incomingRawSpellID, incomingResolvedSpellID, incomingTracked = IT_ResolveTrackedInterruptSpellID(spellID)
    local recordRawSpellID, recordResolvedSpellID, recordTracked = IT_ResolveTrackedInterruptSpellID(record.spellID)
    if not incomingTracked or not recordTracked then
        return false
    end

    return incomingRawSpellID == recordRawSpellID
        or incomingRawSpellID == recordResolvedSpellID
        or incomingResolvedSpellID == recordRawSpellID
        or incomingResolvedSpellID == recordResolvedSpellID
end

function InterruptTracker:ShouldCoalesceObservedPartyCast(name, spellID, source, now)
    local record = self:GetRecentPartyCastRecord(name)
    if not record or not record.started then
        return false
    end
    if ((tonumber(now) or GetTime()) - (tonumber(record.at) or 0)) > IT_OBSERVED_CAST_COALESCE_WINDOW then
        return false
    end
    return self:RecentPartyCastMatchesSpell(record, spellID)
end

function InterruptTracker:ShouldSuppressObservedCastRestart(member, spellID, now)
    local normalizedName = IT_NormalizeName(member and member.name)
    if not normalizedName then
        return false
    end

    local record = self:GetRecentPartyCastRecord(normalizedName)
    if not record or not record.started then
        return false
    end
    if ((tonumber(now) or GetTime()) - (tonumber(record.at) or 0)) > IT_OBSERVED_CAST_COALESCE_WINDOW then
        return false
    end
    return self:RecentPartyCastMatchesSpell(record, spellID)
end

function InterruptTracker:ShouldStoreFallbackPartyCast(ownerUnit, ownerName, now)
    if not ownerUnit or not UnitExists(ownerUnit) then
        return false
    end

    local normalizedName = IT_NormalizeName(ownerName or IT_SafeUnitName(ownerUnit))
    if not normalizedName or normalizedName == self.playerName then
        return false
    end

    if self.noInterruptPlayers and self.noInterruptPlayers[normalizedName] then
        return false
    end

    local member = self:GetMemberRecord(normalizedName, false)
    if not member then
        member = self:EnsureMemberRecordFromUnit(ownerUnit, normalizedName)
    end
    if not member or member.fromAddon then
        return false
    end

    local classFile = member.class or IT_SafeUnitClass(ownerUnit)
    if not classFile or type(IT_CLASS_INTERRUPT_LIST[classFile]) ~= "table" then
        return false
    end

    if member.spellID and not self:IsMemberReady(member, now) then
        for _, extraKick in ipairs(member.extraKicks or {}) do
            if IT_IsReady(extraKick.cdEnd or 0, now) then
                return true
            end
        end
        return false
    end

    return true
end

function InterruptTracker:HandleObservedPartyCastEvent(ownerUnit, castUnit, source, ...)
    if not ownerUnit or not UnitExists(ownerUnit) then
        return false
    end

    local ownerName = IT_SafeUnitName(ownerUnit)
    if not ownerName then
        return false
    end

    local member = self:GetMemberRecord(ownerName, false)
    if not member then
        member = self:EnsureMemberRecordFromUnit(ownerUnit, ownerName)
    end

    local now = GetTime()
    if source == "sent" and self:ShouldStoreFallbackPartyCast(ownerUnit, ownerName, now) then
        -- Pre-arm timing correlation on the first observed cast event so
        -- fallback confirmation does not have to wait for UNIT_SPELLCAST_SUCCEEDED.
        self:RecordRecentPartyCast(ownerName, nil, source, false, now)
        self:MarkMemberActivity(ownerName, now)
    end

    local observedSpellID = IT_ResolveObservedInterruptSpellIDFromEventArgs(source, ownerUnit, member, ...)
    if observedSpellID then
        if source == "sent" then
            self.partySentUsableIdentitySeen = true
        end
        return self:HandleObservedPartyInterruptCast(ownerUnit, castUnit, observedSpellID, source)
    end

    if source == "succeeded" then
        if self:ShouldStoreFallbackPartyCast(ownerUnit, ownerName, now) then
            self:RecordRecentPartyCast(ownerName, nil, source, false, now)
            self:MarkMemberActivity(ownerName, now)
        end
    end

    return false
end

function InterruptTracker:HandleObservedPartyInterruptCast(ownerUnit, castUnit, spellID, source)
    if not ownerUnit or not UnitExists(ownerUnit) then
        return false
    end

    local ownerName = IT_SafeUnitName(ownerUnit)
    if not ownerName then
        return false
    end

    local rawSpellID, resolvedSpellID, trackedInterrupt = IT_ResolveTrackedInterruptSpellID(spellID)
    if not trackedInterrupt then
        return false
    end

    local now = GetTime()
    source = IT_NormalizeSafeString(source) or "succeeded"
    self:MarkMemberActivity(ownerName, now)

    local member = self:GetMemberRecord(ownerName, false)
    if not member then
        member = self:EnsureMemberRecordFromUnit(ownerUnit, ownerName)
    end
    if not member then
        return false
    end

    local beforeSeedState = self:CaptureSeedState(member)
    local classFile = IT_SafeUnitClass(ownerUnit)
    if classFile then
        member.class = classFile
    end
    local ownerGUID = IT_SafeUnitGUID(ownerUnit)
    if ownerGUID then
        member.unitGUID = ownerGUID
    end

    local directSpellID = IT_INTERRUPTS[rawSpellID] and rawSpellID or resolvedSpellID
    local observedCooldown = IT_GetCanonicalInterruptBaseCd(directSpellID, tonumber((IT_INTERRUPTS[directSpellID] or {}).cd)) or 15

    if member.fromAddon then
        self:RecordRecentPartyCast(ownerName, directSpellID, source, false, now)
        if self:DidSeedStateChange(beforeSeedState, member) then
            self:ReseedModeBOrder(true)
        end
        return false
    end

    if self:ShouldCoalesceObservedPartyCast(ownerName, directSpellID, source, now) then
        self:RecordRecentPartyCast(ownerName, directSpellID, source, true, now)
        if self:DidSeedStateChange(beforeSeedState, member) then
            self:ReseedModeBOrder(true)
        end
        return true
    end

    if member.spellID and (member.spellID == rawSpellID or member.spellID == resolvedSpellID) then
        self:HandleConfirmedPrimaryUse(member, observedCooldown, "party_unit_cast")
        self:RecordRecentPartyCast(ownerName, member.spellID, source, true, now)
        if self:DidSeedStateChange(beforeSeedState, member) then
            self:ReseedModeBOrder(true)
        end
        return true
    end

    local matchedExtra = IT_FindMatchingExtraKick(member, directSpellID)
    if matchedExtra and self:HandleConfirmedExtraKick(member, directSpellID, "party_unit_cast") then
        self:RecordRecentPartyCast(ownerName, matchedExtra.spellID, source, true, now)
        if self:DidSeedStateChange(beforeSeedState, member) then
            self:ReseedModeBOrder(true)
        end
        return true
    end

    local observedSpecID, observedOverride = IT_GetObservedSpecOverride(directSpellID)
    if observedOverride then
        member.specID = observedSpecID
        member.specName = IT_GetSpecName(observedSpecID)
        member.spellID = tonumber(observedOverride.id) or directSpellID
        member.baseCd = IT_GetCanonicalInterruptBaseCd(member.spellID, observedOverride.cd) or observedCooldown
        member.icon = observedOverride.petSpellID and IT_SafeSpellTexture(observedOverride.petSpellID) or IT_GetPrimaryIcon(member.spellID)
        member.isPetSpell = observedOverride.isPet and true or false
        member.petSpellID = observedOverride.petSpellID or nil
        self:ResetTalentDerivedInterruptFields(member)
    elseif IT_ClassSupportsInterruptSpell(member.class, directSpellID) then
        member.spellID = directSpellID
        member.baseCd = IT_GetCanonicalInterruptBaseCd(directSpellID, observedCooldown) or observedCooldown
        member.icon = IT_GetPrimaryIcon(directSpellID)
        if not (castUnit and castUnit ~= ownerUnit) then
            member.isPetSpell = false
            member.petSpellID = nil
        end
        self:ResetTalentDerivedInterruptFields(member)
    end

    if member.spellID and (member.spellID == rawSpellID or member.spellID == resolvedSpellID) then
        local cooldown = IT_GetCanonicalInterruptBaseCd(member.spellID, member.baseCd or observedCooldown) or observedCooldown
        self:HandleConfirmedPrimaryUse(member, cooldown, "party_unit_cast")
        self:RecordRecentPartyCast(ownerName, member.spellID, source, true, now)
        if observedOverride then
            self:QueuePartyInspectDelayed(ownerUnit)
        end
        if self:DidSeedStateChange(beforeSeedState, member) then
            self:ReseedModeBOrder(true)
        end
        return true
    end

    self:RecordRecentPartyCast(ownerName, directSpellID, source, false, now)

    if self:DidSeedStateChange(beforeSeedState, member) then
        self:ReseedModeBOrder(true)
    end
    return false
end

function InterruptTracker:HandleMobInterrupted(interruptedUnit)
    local now = GetTime()
    self:ExpireOwnerInterruptPending(now)
    self:ClearOwnerInterruptPending()
    if self.selfState and self.selfState.pendingOnKickReduction and self.selfLastPrimaryCastAt and (now - self.selfLastPrimaryCastAt) < IT_FALLBACK_CONFIRM_MAX_DELTA then
        self:ApplyOnKickReduction(self.selfState)
        self.selfState.pendingOnKickReduction = false
    end

    local bestName, bestDelta, bestRecord = nil, 999, nil
    for name in pairs(self.recentPartyCasts or {}) do
        local record = self:GetRecentPartyCastRecord(name)
        local delta = now - (tonumber(record and record.at) or 0)
        if delta > IT_RECENT_CAST_KEEP then
            self.recentPartyCasts[name] = nil
        elseif delta < bestDelta then
            bestDelta = delta
            bestName = name
            bestRecord = record
        end
    end

    if bestName and bestDelta < IT_FALLBACK_CONFIRM_MAX_DELTA then
        self.recentPartyCasts[bestName] = nil
        local member = self:GetMemberRecord(bestName, false)
        local roster = self:GetUnitForMember(bestName)
        if not member then
            if roster and roster.unit then
                local classFile = IT_SafeUnitClass(roster.unit)
                local kick = classFile and IT_CLASS_PRIMARY[classFile] or nil
                if kick then
                    member = self:GetMemberRecord(bestName, true)
                    member.class = classFile
                    member.spellID = kick.id
                    member.baseCd = IT_GetCanonicalInterruptBaseCd(kick.id, kick.cd) or 15
                    member.icon = IT_GetPrimaryIcon(kick.id)
                end
            end
        end

        if member and (not member.fromAddon) and (not member.specID) and roster and roster.unit then
            self:QueuePartyInspectDelayed(roster.unit)
        end

        local recentSpellID = IT_NormalizeSpellID(bestRecord and bestRecord.spellID)
        local recentStarted = bestRecord and bestRecord.started and true or false
        local handledFallback = false

        if member and member.pendingOnKickReduction and not IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS[tonumber(member.spellID) or 0] then
            self:ApplyOnKickReduction(member)
            member.pendingOnKickReduction = false
        end

        if member and member.fromAddon then
            handledFallback = recentStarted
        elseif member and (not recentStarted) and recentSpellID > 0 and self:HandleConfirmedExtraKick(member, recentSpellID, "fallback_inferred") then
            handledFallback = true
        elseif member and (not recentStarted) and member.spellID then
            member.cdEnd = now + (member.baseCd or 15)
            if member.onKickReduction and not IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS[tonumber(member.spellID) or 0] then
                self:ApplyOnKickReduction(member)
            end
            self:TryCountInterrupt(member, member.spellID, "fallback_inferred", now)
            self:MarkFullWipeRecoveryEvidence(member, now)
            handledFallback = true
        elseif member and member.spellID then
            handledFallback = recentStarted
        end

        if handledFallback and PA_CpuDiagIsFrameConsideredShown("interrupt", self.frame) then
            self:UpdateDisplay()
        end
    end
end

function InterruptTracker:RegisterPartyWatchers()
    self:BuildUnitMap()
    self.partyWatcherUnitActive = {}
    interruptPartyFallbackFrame:UnregisterAllEvents()
    interruptPartyFallbackFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if type(unit) ~= "string" or not unit:match("^party%d$") then
            return
        end
        if self.partyWatcherUnitActive and self.partyWatcherUnitActive[unit] then
            return
        end
        PA_CpuDiagRecordUnitCallback(event)
        local perfStart, perfState = PA_PerfBegin("callback_class_unit_event")
        local source = event == "UNIT_SPELLCAST_SENT" and "sent" or "succeeded"
        self:HandleObservedPartyCastEvent(unit, unit, source, ...)
        PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
    end)
    interruptPartyFallbackFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
    interruptPartyFallbackFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    for i = 1, 4 do
        local ownerUnit = "party" .. i
        local petUnit = "partypet" .. i
        local observedOwnerUnit = ownerUnit
        local observedPetUnit = petUnit

        interruptPartyFrames[i]:UnregisterAllEvents()
        interruptPartyPetFrames[i]:UnregisterAllEvents()

        if UnitExists(observedOwnerUnit) then
            self.partyWatcherUnitActive[observedOwnerUnit] = true
            interruptPartyFrames[i]:RegisterUnitEvent("UNIT_SPELLCAST_SENT", observedOwnerUnit)
            interruptPartyFrames[i]:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", observedOwnerUnit)
            interruptPartyFrames[i]:SetScript("OnEvent", function(_, event, unit, ...)
                PA_CpuDiagRecordUnitCallback(event)
                local perfStart, perfState = PA_PerfBegin("callback_class_unit_event")
                local source = event == "UNIT_SPELLCAST_SENT" and "sent" or "succeeded"
                self:HandleObservedPartyCastEvent(observedOwnerUnit, unit or observedOwnerUnit, source, ...)
                PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            end)
        else
            self.partyWatcherUnitActive[observedOwnerUnit] = nil
            interruptPartyFrames[i]:SetScript("OnEvent", nil)
        end

        if UnitExists(observedPetUnit) then
            interruptPartyPetFrames[i]:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", observedPetUnit)
            interruptPartyPetFrames[i]:SetScript("OnEvent", function(_, event, unit, ...)
                PA_CpuDiagRecordUnitCallback(event)
                local perfStart, perfState = PA_PerfBegin("callback_class_unit_event")
                self:HandleObservedPartyCastEvent(observedOwnerUnit, unit or observedPetUnit, "succeeded", ...)
                PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            end)
        else
            interruptPartyPetFrames[i]:SetScript("OnEvent", nil)
        end
    end
end

function InterruptTracker:RegisterMobInterruptWatchers()
    if self.mobInterruptFrame then
        return
    end
    self.mobInterruptFrame = CreateFrame("Frame")
    self.mobInterruptFrame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target", "mouseover", "focus", "boss1", "boss2", "boss3", "boss4", "boss5")
    self.mobInterruptFrame:SetScript("OnEvent", function(_, _, unit)
        PA_CpuDiagRecordUnitCallback("UNIT_SPELLCAST_INTERRUPTED")
        local perfStart, perfState = PA_PerfBegin("callback_class_unit_event")
        self:HandleMobInterrupted(unit)
        PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
    end)

    self.nameplateFrames = {}
    self.nameplateFrame = CreateFrame("Frame")
    self.nameplateFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.nameplateFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    self.nameplateFrame:SetScript("OnEvent", function(_, event, unit)
        PA_CpuDiagRecordUnitCallback(event)
        local perfStart, perfState = PA_PerfBegin("callback_class_unit_event")
        if event == "NAME_PLATE_UNIT_ADDED" then
            if not self.nameplateFrames[unit] then
                self.nameplateFrames[unit] = CreateFrame("Frame")
            end
            local frame = self.nameplateFrames[unit]
            frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", unit)
            frame:SetScript("OnEvent", function(_, _, interruptedUnit)
                PA_CpuDiagRecordUnitCallback("UNIT_SPELLCAST_INTERRUPTED")
                local childPerfStart, childPerfState = PA_PerfBegin("callback_class_unit_event")
                self:HandleMobInterrupted(interruptedUnit or unit)
                PA_PerfEnd("callback_class_unit_event", childPerfStart, childPerfState)
            end)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            if self.nameplateFrames[unit] then
                self.nameplateFrames[unit]:UnregisterAllEvents()
            end
        end
        PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
    end)
end

function InterruptTracker:RegisterSelfWatchers()
    if not self.selfCastFrame then
        self.selfCastFrame = CreateFrame("Frame")
    end
    self:ClearPendingOwnerPrimaryCast()
    self:ClearOwnerInterruptPending()
    self.selfCastFrame:UnregisterAllEvents()
    self.selfCastFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
    self.selfCastFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
        PA_CpuDiagRecordUnitCallback(event)
        local perfStart, perfState = PA_PerfBegin("callback_class_unit_event")
        if event ~= "UNIT_SPELLCAST_SUCCEEDED" then
            PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            return
        end
        local member = self.selfState
        if not member or not member.spellID then
            PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            return
        end

        local rawSpellID = IT_NormalizeSpellID(spellID)
        if rawSpellID <= 0 then
            PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            return
        end

        local _, resolvedSpellID, tracked = IT_ResolveTrackedInterruptSpellID(rawSpellID)
        if not tracked then
            PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            return
        end

        local now = GetTime()
        if resolvedSpellID == member.spellID or rawSpellID == member.spellID then
            local cooldown = member.baseCd or tonumber((IT_INTERRUPTS[member.spellID] or {}).cd) or 15
            self:HandleConfirmedPrimaryUse(member, cooldown, "local_detect")
            self:BroadcastCast(member.spellID, cooldown)
            PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            return
        end

        local matchedExtra = self:HandleConfirmedExtraKick(member, resolvedSpellID, "local_detect")
        if matchedExtra then
            self:BroadcastCast(matchedExtra.spellID, matchedExtra.baseCd or 0)
            PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            return
        end

        if unit ~= "player" and unit ~= "pet" then
            PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
            return
        end

        local extraData = IT_INTERRUPTS[resolvedSpellID]
        if extraData and resolvedSpellID ~= member.spellID then
            member.extraKicks = member.extraKicks or {}
            member.extraKicks[#member.extraKicks + 1] = {
                spellID = resolvedSpellID,
                baseCd = extraData.cd,
                cdEnd = now + extraData.cd,
                name = extraData.name,
                icon = IT_GetPrimaryIcon(resolvedSpellID),
            }
            self:TryCountInterrupt(member, resolvedSpellID, "local_detect", now)
            self:MarkFullWipeRecoveryEvidence(member, now)
            self:BroadcastCast(resolvedSpellID, extraData.cd or 0)
        end
        PA_PerfEnd("callback_class_unit_event", perfStart, perfState)
    end)
end

-- Addon message dispatch
local function IT_DebugInterruptTrackerIncomingRemoteCast(self, shortSender, payload1)
    local incomingSpellID = tonumber(payload1)
    local preResolvedMember = self:GetMemberRecord(shortSender, false)
    local debugRemoteSolarBeam = IT_ShouldDebugSolarBeamRemote(preResolvedMember, incomingSpellID, preResolvedMember and preResolvedMember.specID or nil)
    local rawSpellID, resolvedSpellID = IT_ResolveTrackedInterruptSpellID(incomingSpellID)
    if debugRemoteSolarBeam and (rawSpellID == 78675 or resolvedSpellID == 78675) then
        IT_DebugTrace(true,
            "solar_beam RECV CAST",
            "spellID=", resolvedSpellID or rawSpellID or "nil",
            "memberResolved=", preResolvedMember and "true" or "false",
            "fromAddon=", preResolvedMember and (preResolvedMember.fromAddon and "true" or "false") or "false")
    end
end

local function IT_HandleInterruptTrackerHelloMessage(self, shortSender, payload1, payload2, payload3, payload4)
    local classFile = payload1
    local spellID = tonumber(payload2)
    local baseCd = tonumber(payload3)
    local specID = tonumber(payload4)
    if not (classFile and IT_CLASS_COLORS[classFile] and spellID and IT_INTERRUPTS[spellID]) then
        return
    end

    local member = self:GetMemberRecord(shortSender, false)
    local created = member == nil
    member = member or self:GetMemberRecord(shortSender, true)
    local beforeSeedState = self:CaptureSeedState(member)
    self:BuildUnitMap()
    local rosterEntry = self:GetUnitForMember(shortSender)
    local debugRemoteSolarBeam = IT_ShouldDebugSolarBeamRemote(member, spellID, specID)
    local authoritativeBaseCd = tonumber(baseCd) or tonumber((IT_INTERRUPTS[spellID] or {}).cd) or 15
    local previousFromAddon = member.fromAddon and true or false
    local previousSpecID = member.specID
    local previousAddonPrimarySpellID = member.addonPrimarySpellID
    local previousAddonPrimaryBaseCd = member.addonPrimaryBaseCd
    self.noInterruptPlayers[shortSender] = nil
    member.class = classFile
    member.spellID = spellID
    member.baseCd = authoritativeBaseCd
    if specID and specID > 0 then
        member.specID = specID
        member.specName = IT_GetSpecName(specID)
    end
    member.unitGUID = IT_NormalizeSafeString(rosterEntry and rosterEntry.guid or nil) or IT_NormalizeSafeString(member.unitGUID)
    member.icon = IT_GetPrimaryIcon(spellID)
    self:ResetTalentDerivedInterruptFields(member)
    member.fromAddon = true
    member.addonPrimarySpellID = spellID
    member.addonPrimaryBaseCd = authoritativeBaseCd
    member.addonPrimarySeenAt = GetTime()
    member.extraKicks = member.extraKicks or {}
    member.lastActivityAt = GetTime()
    IT_DebugTrace(debugRemoteSolarBeam,
        "remote solar_beam HELLO storage",
        "previousAddonPrimarySpellID=", previousAddonPrimarySpellID or "nil",
        "previousAddonPrimaryBaseCd=", previousAddonPrimaryBaseCd or "nil",
        "newAddonPrimarySpellID=", member.addonPrimarySpellID or "nil",
        "newAddonPrimaryBaseCd=", member.addonPrimaryBaseCd or "nil",
        "specID=", member.specID or previousSpecID or "nil",
        "trackedPrimary=", member.spellID or "nil",
        "fromAddonBefore=", previousFromAddon and "true" or "false",
        "fromAddonAfter=", member.fromAddon and "true" or "false",
        "created=", created and "true" or "false")
    self:QueuePartyInspectDelayed()
    if self:DidSeedStateChange(beforeSeedState, member) then
        self:ReseedModeBOrder(true)
    end
    self:BroadcastState()
    self:AnnounceHello(false)
end

local function IT_HandleInterruptTrackerCastMessage(self, shortSender, payload1, payload2, payload3)
    local spellID = tonumber(payload1)
    local cooldown = tonumber(payload2)
    local marker = trim(tostring(payload3 or ""))
    local member = self:GetMemberRecord(shortSender, false)
    local _, resolvedSpellID, trackedInterrupt = IT_ResolveTrackedInterruptSpellID(spellID)
    local now = GetTime()
    local debugRemoteSolarBeam = IT_ShouldDebugSolarBeamRemote(member, spellID, member and member.specID or nil)
    local verdict = {
        sender = shortSender,
        memberResolved = member ~= nil,
        resolvedMemberName = member and member.name or nil,
        fromAddonBefore = member and member.fromAddon and true or false,
        fromAddonAfter = member and member.fromAddon and true or false,
        class = member and member.class or nil,
        specID = member and member.specID or nil,
        trackedPrimary = member and member.spellID or nil,
        addonPrimarySpellID = member and member.addonPrimarySpellID or nil,
        addonPrimaryBaseCd = member and member.addonPrimaryBaseCd or nil,
        addonPrimarySeenAt = member and member.addonPrimarySeenAt or nil,
        exactPrimaryMatched = false,
        extraKickMatched = false,
        selfHealAttempted = false,
        selfHealResult = "not_attempted",
        promotionReason = "not_attempted",
        ignoredStaleAfterAdj = false,
        handleConfirmedReached = false,
        finalVerdict = nil,
    }
    local function finalizeRemoteVerdict(reason)
        verdict.memberResolved = member ~= nil
        verdict.resolvedMemberName = member and member.name or nil
        verdict.fromAddonAfter = member and member.fromAddon and true or false
        verdict.class = member and member.class or nil
        verdict.specID = member and member.specID or nil
        verdict.trackedPrimary = member and member.spellID or nil
        verdict.addonPrimarySpellID = member and member.addonPrimarySpellID or nil
        verdict.addonPrimaryBaseCd = member and member.addonPrimaryBaseCd or nil
        verdict.addonPrimarySeenAt = member and member.addonPrimarySeenAt or nil
        verdict.finalVerdict = reason
        IT_DebugSolarBeamRemoteVerdict(debugRemoteSolarBeam, verdict)
    end
    if member then
        self:MarkMemberActivity(shortSender)
        self:ExpireAdjGuard(member, now)
    end
    if marker == "ADJ" then
        if member
            and member.fromAddon
            and spellID
            and IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS[spellID]
            and member.spellID == spellID then
            member.cdEnd = now + math.max(0, cooldown or 0)
            member.lastAdjSpellID = spellID
            member.lastAdjIgnoreCastUntil = now + 1.0
            if PA_CpuDiagIsFrameConsideredShown("interrupt", self.frame) then
                self:UpdateDisplay()
            end
        end
        return
    end
    IT_DebugTrace(debugRemoteSolarBeam,
        "remote solar_beam CAST received",
        "memberFound=", member and "true" or "false",
        "fromAddon=", member and (member.fromAddon and "true" or "false") or "nil",
        "specID=", member and (member.specID or "nil") or "nil",
        "trackedPrimary=", member and (member.spellID or "nil") or "nil",
        "addonPrimarySpellID=", member and (member.addonPrimarySpellID or "nil") or "nil",
        "addonPrimaryBaseCd=", member and (member.addonPrimaryBaseCd or "nil") or "nil",
        "spellID=", spellID or "nil",
        "trackedInterrupt=", trackedInterrupt and "true" or "false",
        "resolvedSpellID=", resolvedSpellID or "nil")
    if not member then
        local _, promotionReason = self:TryPromoteMemberFromAddonCast(nil, shortSender, spellID, debugRemoteSolarBeam)
        verdict.promotionReason = promotionReason or "member_unknown"
        finalizeRemoteVerdict("member_unknown")
        return
    end
    local debugStoredState, debugStoredReason = self:GetStoredAddonPrimaryState(member)
    local unit = self:GetMemberUnitToken(member)
    local debugCanonicalState, debugCanonicalReason, debugCanonicalSpecID, debugCanonicalSource = self:ResolveAuthoritativeSpecBasedCanonicalPrimary(member, unit)
    IT_DebugTrace(debugRemoteSolarBeam,
        "remote solar_beam authority state",
        "storedPrimarySpellID=", debugStoredState and debugStoredState.spellID or "nil",
        "storedPrimaryValidity=", debugStoredState and "valid" or (debugStoredReason or "nil"),
        "canonicalPrimarySpellID=", debugCanonicalState and debugCanonicalState.spellID or "nil",
        "canonicalSpecID=", debugCanonicalSpecID or "nil",
        "canonicalSource=", debugCanonicalSource or "nil",
        "canonicalReason=", debugCanonicalState and "available" or (debugCanonicalReason or "nil"))
    if not member.fromAddon then
        local promoted, promotionReason = self:TryPromoteMemberFromAddonCast(member, shortSender, spellID, debugRemoteSolarBeam)
        verdict.promotionReason = promotionReason or "promotion_blocked"
        if not promoted then
            finalizeRemoteVerdict("promotion_blocked")
            return
        end
    else
        verdict.promotionReason = "already_addon_backed"
    end
    if not member.fromAddon then
        finalizeRemoteVerdict("not_addon_backed")
        return
    end

    local exactPrimaryMatch = member.fromAddon and member.spellID and spellID and member.spellID == spellID
    verdict.exactPrimaryMatched = exactPrimaryMatch and true or false
    IT_DebugTrace(debugRemoteSolarBeam,
        "remote solar_beam exact-primary",
        exactPrimaryMatch and "success" or "fail",
        "trackedPrimary=", member.spellID or "nil",
        "spellID=", spellID or "nil")
    if exactPrimaryMatch then
        if self:ShouldSuppressObservedCastRestart(member, spellID, now) then
            finalizeRemoteVerdict("coalesced_recent_local_start")
            return
        end
        if self:ShouldIgnoreStaleNormalCastAfterAdj(member, spellID, cooldown, now) then
            verdict.ignoredStaleAfterAdj = true
            finalizeRemoteVerdict("ignored_stale_normal_cast_after_adj")
            return
        end
        self:HandleConfirmedPrimaryUse(member, cooldown, "addon_comm")
        verdict.handleConfirmedReached = true
        if IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS[spellID] then
            self:ClearAdjGuard(member)
        end
        finalizeRemoteVerdict("exact_primary_match")
        return
    end

    local matchedExtra = false
    if member.fromAddon and spellID then
        if self:ShouldSuppressObservedCastRestart(member, spellID, now) then
            finalizeRemoteVerdict("coalesced_recent_local_extra")
            return
        end
        matchedExtra = self:HandleConfirmedExtraKick(member, spellID, "addon_comm")
    end
    verdict.extraKickMatched = matchedExtra and true or false
    IT_DebugTrace(debugRemoteSolarBeam,
        "remote solar_beam extra-kick",
        matchedExtra and "success" or "fail",
        "spellID=", spellID or "nil")
    if matchedExtra then
        finalizeRemoteVerdict("extra_kick_match")
        return
    end

    verdict.selfHealAttempted = true
    local accepted, reason = self:TryHealPrimaryFromAuthoritativeCast(member, spellID)
    verdict.selfHealResult = reason or "nil"
    IT_DebugTrace(debugRemoteSolarBeam,
        "remote solar_beam stale-primary repair",
        accepted and "accepted" or "rejected",
        "reason=", reason or "nil",
        "fromAddon=", member.fromAddon and "true" or "false",
        "specID=", member.specID or "nil",
        "trackedPrimary=", member.spellID or "nil",
        "addonPrimarySpellID=", member.addonPrimarySpellID or "nil")
    if accepted then
        if self:ShouldIgnoreStaleNormalCastAfterAdj(member, spellID, cooldown, now) then
            verdict.ignoredStaleAfterAdj = true
            finalizeRemoteVerdict("ignored_stale_normal_cast_after_adj")
            return
        end
        self:HandleConfirmedPrimaryUse(member, cooldown, "addon_comm")
        verdict.handleConfirmedReached = true
        if IT_OWNER_CONFIRMED_CONDITIONAL_SPELLS[spellID] then
            self:ClearAdjGuard(member)
        end
        finalizeRemoteVerdict(reason or "accepted_canonical_resolution")
        return
    end
    local finalVerdict = ({
        spec_missing = "heal_rejected_spec_missing",
        stored_primary_invalid = "heal_rejected_stored_primary_invalid",
        stored_primary_mismatch = "heal_rejected_stored_primary_mismatch",
        canonical_mismatch = "heal_rejected_canonical_mismatch",
        no_authoritative_primary = "heal_rejected_no_authoritative_primary",
    })[reason] or reason or "heal_rejected_no_authoritative_primary"
    finalizeRemoteVerdict(finalVerdict)
end

local function IT_HandleInterruptTrackerRotationMessage(self, shortSender, payload1)
    local order = {}
    for name in tostring(payload1 or ""):gmatch("[^,]+") do
        local normalized = IT_NormalizeName(name)
        if normalized then
            order[#order + 1] = normalized
        end
    end
    self.remoteRotationState = self.remoteRotationState or {}
    self.remoteRotationState[shortSender] = {
        order = order,
        rotationIndex = 1,
        updatedAt = GetTime(),
    }
end

local function IT_HandleInterruptTrackerRotationIndexMessage(self, shortSender)
    -- Incoming ROTIDX is compatibility-only and never drives local Mode B ordering.
    self.remoteRotationState = self.remoteRotationState or {}
    self.remoteRotationState[shortSender] = self.remoteRotationState[shortSender] or {}
    self.remoteRotationState[shortSender].rotationIndex = 1
    self.remoteRotationState[shortSender].updatedAt = GetTime()
end

local function IT_HandleInterruptTrackerStateMessage()
    -- STATE is non-authoritative for live interrupt counts.
    -- Live counts are owned only by TryCountInterrupt(...) -> IncrementCount(...).
    -- Parse STATE for diagnostics / compatibility / sender activity only.
    return
end

local IT_INTERRUPT_ADDON_MESSAGE_HANDLERS = {
    PING = function()
        return
    end,
    HELLO = IT_HandleInterruptTrackerHelloMessage,
    CAST = IT_HandleInterruptTrackerCastMessage,
    ROT = IT_HandleInterruptTrackerRotationMessage,
    ROTIDX = IT_HandleInterruptTrackerRotationIndexMessage,
    STATE = IT_HandleInterruptTrackerStateMessage,
}

function InterruptTracker:HandleAddonMessage(prefix, message, channel, sender)
    if prefix ~= PA_INTERRUPT_PREFIX then
        return
    end

    local shortSender = IT_NormalizeName(sender)
    if not shortSender then
        return
    end

    local command, payload1, payload2, payload3, payload4 = strsplit(":", tostring(message or ""))
    if shortSender == self.playerName then
        return
    end

    if command == "CAST" then
        IT_DebugInterruptTrackerIncomingRemoteCast(self, shortSender, payload1)
    end

    self:MarkMemberActivity(shortSender, nil, command ~= "CAST")

    local handler = IT_INTERRUPT_ADDON_MESSAGE_HANDLERS[command]
    if handler then
        handler(self, shortSender, payload1, payload2, payload3, payload4)
    end
end

function InterruptTracker:HandleInspectReady(inspectedGUID)
    if not self.inspectBusy or not self.inspectUnit then
        return
    end
    if not self:DoesInspectReadyMatchActiveTarget(inspectedGUID) then
        return
    end
    local unit = self.inspectUnit
    pcall(function()
        self:ScanInspectTalentsInternal(unit)
    end)
    self:AbortInspectSession(true)
end

function InterruptTracker:ApplyPosition()
    if not self.frame then
        return
    end
    local db = self:GetDB()
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(db.x) or 0, tonumber(db.y) or 0)
end

function InterruptTracker:ResetPositionToCenter()
    local db = self:GetDB()
    db.x = 0
    db.y = 0
    self:ApplyPosition()
    Modules:NotifyPositionChanged(self.key, db.x, db.y)
    self:EvaluateVisibility()
end

function InterruptTracker:PersistPosition()
    if not self.frame then
        return
    end
    local db = self:GetDB()
    local cx, cy = self.frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then
        return
    end
    db.x = math.floor((cx - ux) + 0.5)
    db.y = math.floor((cy - uy) + 0.5)
    Modules:NotifyPositionChanged(self.key, db.x, db.y)
end

function InterruptTracker:NotifyDragPosition()
    if not self.frame then
        return
    end
    local cx, cy = self.frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not cx or not cy or not ux or not uy then
        return
    end
    Modules:NotifyPositionChanged(self.key, math.floor((cx - ux) + 0.5), math.floor((cy - uy) + 0.5))
end

local function IT_SetSpacingArmCursor(cursorPath)
    if cursorPath and SetCursor then
        pcall(SetCursor, cursorPath)
        return
    end
    if ResetCursor then
        ResetCursor()
    end
end

local function IT_RowGapDragUnits(deltaPixels, pixelsPerStep)
    local px = tonumber(deltaPixels) or 0
    local perStep = math.max(1, tonumber(pixelsPerStep) or 1)
    local sign = px < 0 and -1 or 1
    local raw = math.abs(px) / perStep
    local units
    if raw <= 8 then
        units = raw
    elseif raw <= 20 then
        units = 8 + ((raw - 8) * 1.45)
    else
        units = 25.4 + ((raw - 20) * 1.95)
    end
    return sign * math.floor(units + 0.5)
end

function InterruptTracker:GetRowGap()
    return IT_GetConfiguredRowGap(self:GetDB())
end

function InterruptTracker:CreateSpacingHandle(parent)
    local host = parent or self.frame
    if not host then
        return nil
    end

    if self.spacingHandle and self.spacingHandle:GetParent() ~= host then
        self.spacingHandle:SetParent(host)
    end

    if self.spacingHandle then
        self.spacingHandle:ClearAllPoints()
        self.spacingHandle:SetPoint("RIGHT", host, "LEFT", -IT_SPACING_ARM.OFFSET_X, 0)
        self.spacingHandle:SetFrameStrata("HIGH")
        self.spacingHandle:SetFrameLevel((host:GetFrameLevel() or 1) + 30)
        return self.spacingHandle
    end

    local handle = CreateFrame("Frame", nil, host)
    handle:SetPoint("RIGHT", host, "LEFT", -IT_SPACING_ARM.OFFSET_X, 0)
    handle:SetSize(IT_SPACING_ARM.ARM_HIT_THICKNESS + 12, IT_SPACING_ARM.ARM_LENGTH + 12)
    handle:SetFrameStrata("HIGH")
    handle:SetFrameLevel((host:GetFrameLevel() or 1) + 30)
    handle:EnableMouse(true)
    handle:EnableMouseWheel(true)
    handle:Hide()

    local backing = handle:CreateTexture(nil, "BACKGROUND")
    backing:SetTexture("Interface\\Buttons\\WHITE8x8")
    backing:SetPoint("CENTER", handle, "CENTER", 0, 0)
    backing:SetSize(IT_SPACING_ARM.ARM_HIT_THICKNESS + 18, IT_SPACING_ARM.ARM_LENGTH + 18)
    backing:SetVertexColor(0, 0, 0, 0.28)
    if backing.SetMask then
        backing:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    handle.backing = backing

    local arm = CreateFrame("Button", nil, handle)
    arm.axis = "y"
    arm:SetSize(IT_SPACING_ARM.ARM_HIT_THICKNESS, IT_SPACING_ARM.ARM_LENGTH)
    arm:SetPoint("CENTER", handle, "CENTER", 0, 0)
    arm:EnableMouse(true)

    arm.line = arm:CreateTexture(nil, "ARTWORK")
    arm.line:SetTexture("Interface\\Buttons\\WHITE8x8")
    arm.line:SetPoint("CENTER", arm, "CENTER", 0, 0)
    arm.line:SetSize(IT_SPACING_ARM.ARM_THICKNESS, IT_SPACING_ARM.ARM_LENGTH)

    arm.glow = arm:CreateTexture(nil, "OVERLAY")
    arm.glow:SetTexture("Interface\\Buttons\\WHITE8x8")
    arm.glow:SetPoint("CENTER", arm.line, "CENTER", 0, 0)
    arm.glow:SetSize(IT_SPACING_ARM.ARM_THICKNESS + 4, IT_SPACING_ARM.ARM_LENGTH + 4)
    arm.glow:SetBlendMode("ADD")
    arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0)
    handle.yArm = arm

    local center = handle:CreateTexture(nil, "OVERLAY")
    center:SetTexture("Interface\\Buttons\\WHITE8x8")
    center:SetSize(IT_SPACING_ARM.CENTER_SIZE, IT_SPACING_ARM.CENTER_SIZE)
    center:SetPoint("CENTER", handle, "CENTER", 0, 0)
    center:SetVertexColor(1.0, 0.82, 0.0, 0.9)
    if center.SetMask then
        center:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    end
    handle.centerNode = center

    local unlockHint = CreateFrame("Frame", nil, handle, "BackdropTemplate")
    unlockHint:SetPoint("TOP", handle, "BOTTOM", 0, -8)
    unlockHint:SetSize(360, 18)
    if unlockHint.SetBackdrop then
        unlockHint:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        unlockHint:SetBackdropColor(0, 0, 0, 0.62)
        unlockHint:SetBackdropBorderColor(1, 1, 1, 0.06)
    end
    unlockHint.text = unlockHint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    unlockHint.text:SetPoint("CENTER", unlockHint, "CENTER", 0, 0)
    unlockHint.text:SetText("")
    unlockHint.text:SetTextColor(0.76, 0.76, 0.76, 0.92)
    unlockHint:Hide()
    handle.unlockHint = unlockHint

    local function refreshVisual()
        local hot = handle._active or handle._hover
        if hot then
            arm.line:SetVertexColor(1.0, 0.84, 0.1, 0.95)
            arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0.35)
        else
            arm.line:SetVertexColor(0.72, 0.72, 0.72, 0.35)
            arm.glow:SetVertexColor(1.0, 0.84, 0.1, 0)
        end
    end
    handle._refreshVisual = refreshVisual
    refreshVisual()

    local function showTip(anchor, line1, line2)
        if not GameTooltip then
            return
        end
        GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
        GameTooltip:SetText(line1, 1, 0.82, 0, 1, true)
        if line2 and line2 ~= "" then
            GameTooltip:AddLine(line2, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end

    local function applyTooltip(showing)
        if not showing then
            PA_HideTooltipIfOwnedBy(handle)
            return
        end
        showTip(handle, "Drag vertical to adjust Y spacing", "Scroll to adjust Y spacing (Shift fine / Alt coarse)")
    end

    local function requestTooltip(showing)
        handle._tooltipWanted = showing and true or false
        handle._tooltipDebounceToken = (handle._tooltipDebounceToken or 0) + 1
        local token = handle._tooltipDebounceToken
        if not (C_Timer and C_Timer.After) then
            applyTooltip(showing)
            return
        end
        C_Timer.After(IT_SPACING_ARM.TOOLTIP_DEBOUNCE, function()
            if self.spacingHandle ~= handle then
                return
            end
            if token ~= handle._tooltipDebounceToken then
                return
            end
            if handle._tooltipWanted ~= (showing and true or false) then
                return
            end
            applyTooltip(showing)
        end)
    end

    local function armEnter()
        handle._hover = true
        refreshVisual()
        IT_SetSpacingArmCursor(IT_SPACING_ARM.CURSOR_Y)
        requestTooltip(true)
    end

    local function armLeave()
        if not handle._active then
            handle._hover = false
            refreshVisual()
            IT_SetSpacingArmCursor(nil)
        end
        requestTooltip(false)
    end

    arm:SetScript("OnEnter", armEnter)
    arm:SetScript("OnLeave", armLeave)
    arm:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then
            self:BeginRowGapDrag()
        end
    end)
    arm:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then
            self:EndRowGapDrag()
        end
    end)

    handle:SetScript("OnMouseWheel", function(_, delta)
        if InCombatLockdown() then
            return
        end
        local step = IT_SPACING_ARM.WHEEL_BASE_STEP
        if IsAltKeyDown and IsAltKeyDown() then
            step = IT_SPACING_ARM.WHEEL_ALT_STEP
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            step = IT_SPACING_ARM.WHEEL_SHIFT_STEP
        end
        if delta and delta ~= 0 then
            self:ApplyRowGapDelta(delta * step, "wheel")
        end
    end)
    handle:SetScript("OnEnter", function()
        if not handle._active then
            handle._hover = true
            refreshVisual()
            IT_SetSpacingArmCursor(IT_SPACING_ARM.CURSOR_GENERIC)
            requestTooltip(true)
        end
    end)
    handle:SetScript("OnLeave", function()
        if not handle._active then
            handle._hover = false
            refreshVisual()
            IT_SetSpacingArmCursor(nil)
            requestTooltip(false)
        end
    end)

    self.spacingHandle = handle
    return handle
end

function InterruptTracker:ShowSpacingUnlockHint()
    local handle = self.spacingHandle
    if not handle or not handle.unlockHint or not handle:IsShown() then
        return
    end
    self._spacingUnlockHintVisible = true
    handle.unlockHint:Hide()
end

function InterruptTracker:DismissSpacingUnlockHint(fadeDuration)
    local handle = self.spacingHandle
    if not handle or not handle.unlockHint then
        return
    end
    local hint = handle.unlockHint
    if not hint:IsShown() then
        self._spacingUnlockHintVisible = false
        return
    end

    self._spacingUnlockHintToken = (self._spacingUnlockHintToken or 0) + 1
    local token = self._spacingUnlockHintToken
    local fade = tonumber(fadeDuration) or IT_SPACING_ARM.UNLOCK_HINT_FAST_FADE
    if fade < 0 then
        fade = 0
    end
    if UIFrameFadeOut and fade > 0 then
        UIFrameFadeOut(hint, fade, hint:GetAlpha() or 1, 0)
        if C_Timer and C_Timer.After then
            C_Timer.After(fade, function()
                if self.spacingHandle ~= handle or not handle.unlockHint then
                    return
                end
                if token ~= self._spacingUnlockHintToken then
                    return
                end
                handle.unlockHint:Hide()
                self._spacingUnlockHintVisible = false
            end)
        else
            hint:Hide()
            self._spacingUnlockHintVisible = false
        end
    else
        hint:Hide()
        self._spacingUnlockHintVisible = false
    end
end

function InterruptTracker:PlayRowGapBoundaryPulse()
    local db = self:GetDB()
    if db.locked then
        return
    end

    local handle = self.spacingHandle
    if not handle or not handle:IsShown() then
        return
    end

    local targets = self._visibleRowPulseTargets
    if type(targets) ~= "table" or #targets == 0 then
        return
    end

    local centerY = 0
    local samples = 0
    for _, target in ipairs(targets) do
        if target and target:IsShown() and target._paSpacingPulseY ~= nil then
            centerY = centerY + (tonumber(target._paSpacingPulseY) or 0)
            samples = samples + 1
        end
    end
    if samples <= 0 then
        return
    end
    centerY = centerY / samples

    local function directionSign(value)
        if value > 0 then
            return 1
        elseif value < 0 then
            return -1
        end
        return 1
    end

    local token = (self._rowGapBoundaryPulseToken or 0) + 1
    self._rowGapBoundaryPulseToken = token

    for _, target in ipairs(targets) do
        if token ~= self._rowGapBoundaryPulseToken then
            return
        end
        if target and target:IsShown() then
            local lastY = tonumber(target._paSpacingPulseY)
            if lastY ~= nil then
                local dy = directionSign(lastY - centerY) * IT_SPACING_ARM.BOUNDARY_PULSE_AMPLITUDE
                if not target._paBoundaryPulseAG then
                    local ag = target:CreateAnimationGroup()
                    local out = ag:CreateAnimation("Translation")
                    out:SetOrder(1)
                    out:SetDuration(IT_SPACING_ARM.BOUNDARY_PULSE_OUT_DURATION)
                    if out.SetSmoothing then
                        out:SetSmoothing("OUT")
                    end

                    local back = ag:CreateAnimation("Translation")
                    back:SetOrder(2)
                    back:SetDuration(IT_SPACING_ARM.BOUNDARY_PULSE_IN_DURATION)
                    if back.SetSmoothing then
                        back:SetSmoothing("IN")
                    end

                    target._paBoundaryPulseAG = ag
                    target._paBoundaryPulseOut = out
                    target._paBoundaryPulseBack = back
                end

                local ag = target._paBoundaryPulseAG
                local out = target._paBoundaryPulseOut
                local back = target._paBoundaryPulseBack
                if ag and out and back then
                    if ag.IsPlaying and ag:IsPlaying() then
                        ag:Stop()
                    end
                    out:SetOffset(0, dy)
                    back:SetOffset(0, -dy)
                    ag:Play()
                end
            end
        end
    end
end

function InterruptTracker:ApplyRowGapDelta(delta, source)
    if InCombatLockdown() then
        return false
    end

    local db = self:GetDB()
    local currentGap = self:GetRowGap()
    local nextGap = math.floor(clampNumber(currentGap + (tonumber(delta) or 0), currentGap, IT_ROW_GAP_MIN, IT_ROW_GAP_MAX))
    local previousBoundary = self._rowGapBoundaryReached and true or false

    if nextGap == currentGap then
        local atBoundary = currentGap <= IT_ROW_GAP_MIN
        self._rowGapBoundaryReached = atBoundary
        if atBoundary and not previousBoundary then
            self:PlayRowGapBoundaryPulse()
        end
        return false
    end

    db.rowGap = nextGap
    self._rowGapLastSource = source or "unknown"
    self:MarkDisplayStructureDirty("row-gap")
    self:UpdateDisplay()

    local effectiveGap = self:GetRowGap()
    local atBoundary = effectiveGap <= IT_ROW_GAP_MIN
    self._rowGapBoundaryReached = atBoundary
    if atBoundary and not previousBoundary then
        self:PlayRowGapBoundaryPulse()
    end
    return true
end

function InterruptTracker:BeginRowGapDrag()
    if InCombatLockdown() then
        return
    end

    local db = self:GetDB()
    if db.locked then
        return
    end

    local handle = self:CreateSpacingHandle(self.frame)
    if not handle then
        return
    end

    self:DismissSpacingUnlockHint(IT_SPACING_ARM.UNLOCK_HINT_FAST_FADE)
    self:EndRowGapDrag()

    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    if not scale or scale <= 0 then
        scale = 1
    end
    local _, cy = GetCursorPosition()
    if not cy then
        return
    end

    self._rowGapDrag = {
        startCursorY = cy / scale,
        startGap = self:GetRowGap(),
    }

    handle._active = true
    handle._hover = true
    if handle._refreshVisual then
        handle._refreshVisual()
    end
    IT_SetSpacingArmCursor(IT_SPACING_ARM.CURSOR_Y)
    PA_HideTooltipIfOwnedBy(handle)

    handle:SetScript("OnUpdate", function()
        local drag = self._rowGapDrag
        if not drag then
            handle:SetScript("OnUpdate", nil)
            return
        end
        if InCombatLockdown() then
            self:EndRowGapDrag()
            return
        end

        local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if not uiScale or uiScale <= 0 then
            uiScale = 1
        end
        local _, py = GetCursorPosition()
        if not py then
            return
        end
        py = py / uiScale

        local pixelsPerStep = IT_SPACING_ARM.DRAG_PIXELS_PER_STEP
        if IsShiftKeyDown and IsShiftKeyDown() then
            pixelsPerStep = pixelsPerStep * IT_SPACING_ARM.SHIFT_DRAG_MULT
        end
        if IsAltKeyDown and IsAltKeyDown() then
            pixelsPerStep = pixelsPerStep * IT_SPACING_ARM.ALT_DRAG_MULT
        end
        if pixelsPerStep < 1 then
            pixelsPerStep = 1
        end

        local units = IT_RowGapDragUnits(py - drag.startCursorY, pixelsPerStep)
        local targetGap = math.floor(clampNumber(drag.startGap + units, drag.startGap, IT_ROW_GAP_MIN, IT_ROW_GAP_MAX))
        local currentGap = self:GetRowGap()
        if targetGap ~= currentGap then
            self:ApplyRowGapDelta(targetGap - currentGap, "drag-y")
        end
    end)
end

function InterruptTracker:EndRowGapDrag()
    local handle = self.spacingHandle
    if handle then
        handle:SetScript("OnUpdate", nil)
        handle._active = nil
        if not handle:IsMouseOver() then
            handle._hover = nil
        end
        if handle._refreshVisual then
            handle._refreshVisual()
        end
    end

    self._rowGapDrag = nil
    IT_SetSpacingArmCursor(nil)
    PA_HideTooltipIfOwnedBy(handle)
end

function InterruptTracker:SetSpacingHandleEnabled(enable)
    local handle = self:CreateSpacingHandle(self.frame)
    if not handle then
        return
    end

    local shouldEnable = enable and true or false
    if shouldEnable and self.frame and self.frame.IsShown and not self.frame:IsShown() then
        shouldEnable = false
    end

    if shouldEnable then
        handle:Show()
        handle:EnableMouse(true)
        handle:EnableMouseWheel(true)
        if handle._refreshVisual then
            handle._refreshVisual()
        end
        if not self._spacingHintShownForUnlock then
            self._spacingHintShownForUnlock = true
            self:ShowSpacingUnlockHint()
        end
    else
        self:EndRowGapDrag()
        handle:EnableMouse(false)
        handle:EnableMouseWheel(false)
        handle:Hide()
        if handle.unlockHint then
            handle.unlockHint:Hide()
        end
        self._spacingUnlockHintVisible = false
        self._rowGapBoundaryReached = false
        if self:GetDB().locked then
            self._spacingHintShownForUnlock = false
        end
    end
end

function InterruptTracker:SetUnlocked(unlocked)
    local wasUnlocked = self.unlocked and true or false
    self.unlocked = not not unlocked
    if wasUnlocked ~= self.unlocked then
        self:MarkDisplayStructureDirty("unlock")
    end
    local db = self:GetDB()
    db.locked = not self.unlocked
    local effectiveUnlocked = self.unlocked and self:IsEnabled()
    local wasEffectiveUnlocked = wasUnlocked and self:IsEnabled()
    if self.dragHandle then
        self.dragHandle:SetShown(effectiveUnlocked)
        self.dragHandle:EnableMouse(effectiveUnlocked)
    end
    if self.topDragHandle then
        self.topDragHandle:SetShown(effectiveUnlocked)
        self.topDragHandle:EnableMouse(effectiveUnlocked)
    end
    if self.spacingHandle then
        self:SetSpacingHandleEnabled(effectiveUnlocked and self.frame and self.frame:IsShown())
    end
    if self.unlockLabel then
        self.unlockLabel:SetShown(effectiveUnlocked)
        if self.unlockLabel._blink then
            if effectiveUnlocked then
                self.unlockLabel._blink:Play()
            else
                self.unlockLabel._blink:Stop()
            end
        end
    end
    if effectiveUnlocked then
        if not wasUnlocked then
            self.previewStartedAt = GetTime()
            self.previewCycleOffsetByKey = {}
        end
    elseif wasEffectiveUnlocked then
        self:DismissSpacingUnlockHint(0)
        self:EndRowGapDrag()
        self:ResetPreviewState()
    end
    if wasEffectiveUnlocked ~= effectiveUnlocked and PortalAuthority and PortalAuthority.UpdateMoveHintTickerState then
        PortalAuthority:UpdateMoveHintTickerState()
    end
end

function InterruptTracker:CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    local bgOpacity = IT_GetConfiguredRowBackgroundOpacity(self:GetDB())
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    row:SetBackdropColor(IT_BG_BAR[1], IT_BG_BAR[2], IT_BG_BAR[3], bgOpacity)
    row:SetBackdropBorderColor(IT_ROW_BORDER[1], IT_ROW_BORDER[2], IT_ROW_BORDER[3], IT_ROW_BORDER[4])

    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetAllPoints(row)
    row.bar:SetFrameLevel(row:GetFrameLevel() + 1)
    row.bar:SetMinMaxValues(0, 1)
    row.bar:SetValue(1)
    row.bar:SetStatusBarTexture(self:GetBarTexture())
    if row.bar.SetReverseFill then
        row.bar:SetReverseFill(false)
    end
    row.barBg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.barBg:SetAllPoints(row.bar)
    row.barBg:SetTexture(self:GetBarTexture())
    row.barBg:SetVertexColor(0.11, 0.12, 0.15, bgOpacity)
    row.barAccent = row.bar:CreateTexture(nil, "ARTWORK", nil, 1)
    row.barAccent:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.barAccent:SetBlendMode("ADD")
    if row.barAccent.SetGradientAlpha then
        row.barAccent:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.00, 1, 1, 1, IT_BAR_ACCENT_ALPHA)
    else
        row.barAccent:SetVertexColor(1, 1, 1, IT_BAR_ACCENT_ALPHA)
    end
    row.barAccent:Hide()
    row.barAccent.anim = row.barAccent:CreateAnimationGroup()
    local accentFade = row.barAccent.anim:CreateAnimation("Alpha")
    accentFade:SetOrder(1)
    accentFade:SetDuration(0.30)
    accentFade:SetFromAlpha(IT_BAR_ACCENT_PULSE_ALPHA)
    accentFade:SetToAlpha(0.0)
    row.barAccent.anim:SetScript("OnFinished", function(anim)
        local target = anim:GetParent()
        if target then
            target:Hide()
            target:SetAlpha(0)
        end
    end)

    row.content = CreateFrame("Frame", nil, row)
    row.content:SetAllPoints(row)
    row.content:SetFrameLevel(row.bar:GetFrameLevel() + 1)

    row.classIcon = row.content:CreateTexture(nil, "ARTWORK")
    row.spellIcon = row.content:CreateTexture(nil, "ARTWORK")
    row.iconSeparator = row.content:CreateTexture(nil, "ARTWORK")
    row.iconSeparator:SetTexture("Interface\\Buttons\\WHITE8x8")
    row.iconSeparator:Hide()
    row.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.spellIconGlow = row.content:CreateTexture(nil, "OVERLAY")
    row.spellIconGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    row.spellIconGlow:SetBlendMode("ADD")
    row.spellIconGlow:SetVertexColor(1, 1, 1, 0)
    row.spellIconGlow:Hide()
    row.spellIconGlow.anim = row.spellIconGlow:CreateAnimationGroup()
    local glow = row.spellIconGlow.anim:CreateAnimation("Alpha")
    glow:SetOrder(1)
    glow:SetDuration(IT_ICON_GLOW_DURATION)
    glow:SetFromAlpha(IT_ICON_GLOW_ALPHA)
    glow:SetToAlpha(0.0)

    row.nameText = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)
    row.cooldownText = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.cooldownText:SetJustifyH("RIGHT")
    row.badgeText = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.badgeText:SetJustifyH("RIGHT")
    row.countText = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.countText:SetJustifyH("RIGHT")

    row.extraIcons = {}
    for slot = 1, 3 do
        local texture = row.content:CreateTexture(nil, "ARTWORK")
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        texture:Hide()
        row.extraIcons[slot] = texture
    end
    row.extraMoreText = row.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.extraMoreText:SetJustifyH("RIGHT")
    row.extraMoreText:Hide()

    row.index = index
    row:Hide()
    return row
end

function InterruptTracker:BuildFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetSize(220, 100)
    frame:SetMovable(true)
    frame:SetUserPlaced(false)
    frame:SetClampedToScreen(false)
    frame:EnableMouse(false)
    frame:SetFrameStrata("MEDIUM")

    local function createHandle(anchorPoint, relativePoint, yOffset)
        local handle = CreateFrame("Button", nil, frame, "BackdropTemplate")
        handle:SetPoint(anchorPoint, frame, relativePoint, 0, yOffset)
        handle:SetWidth(140)
        handle:SetHeight(16)
        handle:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        handle:SetBackdropColor(0.0, 1.0, 0.0, 0.85)
        handle:SetBackdropBorderColor(0.0, 0.25, 0.0, 1.0)
        local glyph = handle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        glyph:SetPoint("CENTER", handle, "CENTER", 0, 0)
        glyph:SetText("GRAB")
        glyph:SetTextColor(0, 0, 0, 1)
        handle:EnableMouse(false)
        handle:RegisterForDrag("LeftButton")
        handle:SetScript("OnDragStart", function()
            if not self.unlocked or InCombatLockdown() then
                return
            end
            frame:StartMoving()
            if not self._dragTicker then
                self._dragTicker = C_Timer.NewTicker(0.1, function()
                    self:NotifyDragPosition()
                end)
            end
        end)
        handle:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            if self._dragTicker then
                self._dragTicker:Cancel()
                self._dragTicker = nil
            end
            self:PersistPosition()
        end)
        return handle
    end

    self.topDragHandle = createHandle("BOTTOM", "TOP", 3)
    self.dragHandle = createHandle("TOP", "BOTTOM", -3)

    self.unlockLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    self.unlockLabel:SetPoint("BOTTOM", frame, "TOP", 0, 22)
    self.unlockLabel:SetText("Interrupts")
    self.unlockLabel:SetTextColor(1.0, 0.20, 0.20, 1.0)
    self.unlockLabel._blink = self.unlockLabel:CreateAnimationGroup()
    local fadeOut = self.unlockLabel._blink:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetDuration(0.55)
    fadeOut:SetFromAlpha(1.0)
    fadeOut:SetToAlpha(0.30)
    local fadeIn = self.unlockLabel._blink:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetDuration(0.55)
    fadeIn:SetFromAlpha(0.30)
    fadeIn:SetToAlpha(1.0)
    self.unlockLabel._blink:SetLooping("REPEAT")

    self.frame = frame
    self:CreateSpacingHandle(frame)
    self.selfRowHost = CreateFrame("Frame", nil, frame)
    self.selfRowHost:Hide()
    self.selfRow = self:CreateRow(self.selfRowHost, 0)
    self.selfRow:SetAllPoints(self.selfRowHost)
    self.rows = {}
    for index = 1, 5 do
        self.rows[index] = self:CreateRow(frame, index)
    end
end

function InterruptTracker:ApplyFonts()
    if not self.frame then
        return
    end
    local db = self:GetDB()
    local fontPath, fontSize, fontFlags = self:GetFont()
    local color = db.fontColor or { r = 1, g = 1, b = 1, a = 1 }
    local allRows = {}
    if self.selfRow then
        allRows[#allRows + 1] = self.selfRow
    end
    for _, row in ipairs(self.rows or {}) do
        allRows[#allRows + 1] = row
    end
    for _, row in ipairs(allRows) do
        row.nameText:SetFont(fontPath, fontSize, "OUTLINE")
        row.nameText:SetTextColor(color.r, color.g, color.b, color.a)
        row.nameText:SetShadowOffset(1, -1)
        row.nameText:SetShadowColor(0, 0, 0, 1)
        row.cooldownText:SetFont(fontPath, fontSize, fontFlags)
        row.cooldownText:SetTextColor(color.r, color.g, color.b, color.a)
        row.cooldownText:SetShadowOffset(1, -1)
        row.cooldownText:SetShadowColor(0, 0, 0, 1)
        row.badgeText:SetFont(fontPath, math.max(9, fontSize - 2), fontFlags)
        row.badgeText:SetTextColor(IT_MUTED_TEXT[1], IT_MUTED_TEXT[2], IT_MUTED_TEXT[3], IT_MUTED_TEXT[4])
        row.countText:SetFont(fontPath, fontSize, fontFlags)
        row.countText:SetTextColor(color.r, color.g, color.b, color.a)
        row.extraMoreText:SetFont(fontPath, math.max(8, fontSize - 3), fontFlags)
    end
end

function InterruptTracker:ApplyRowLayout(row, modeB)
    local db = self:GetDB()
    local width = db.width
    local rowHeight = db.rowHeight
    local iconSize = math.max(12, rowHeight - 4)
    local laneX = 0
    local barInset = 6

    row:SetSize(width, rowHeight)
    row.bar:ClearAllPoints()
    row.content:ClearAllPoints()
    row.classIcon:ClearAllPoints()
    row.spellIcon:ClearAllPoints()
    row.iconSeparator:ClearAllPoints()
    row.nameText:ClearAllPoints()
    row.cooldownText:ClearAllPoints()
    row.badgeText:ClearAllPoints()
    row.countText:ClearAllPoints()
    row.extraMoreText:ClearAllPoints()
    for _, extra in ipairs(row.extraIcons) do
        extra:ClearAllPoints()
    end

    local showClassIcon = db.showClassIcon
    local showSpellIcon = db.showSpellIcon
    local classIconGap = showSpellIcon and 0 or 6
    local spellIconGap = 6
    local separatorStartX, separatorWidth = nil, 0
    if showClassIcon then
        row.classIcon:SetPoint("LEFT", row, "LEFT", laneX, 0)
        row.classIcon:SetSize(iconSize, iconSize)
        laneX = laneX + iconSize + classIconGap
        if classIconGap > 0 then
            separatorStartX = laneX - classIconGap
            separatorWidth = classIconGap
        end
    end
    if showSpellIcon then
        row.spellIcon:SetPoint("LEFT", row, "LEFT", laneX, 0)
        row.spellIcon:SetSize(iconSize, iconSize)
        laneX = laneX + iconSize + spellIconGap
        if spellIconGap > 0 then
            separatorStartX = laneX - spellIconGap
            separatorWidth = spellIconGap
        end
    end
    local separatorThickness = math.min(IT_ICON_SEPARATOR_THICKNESS, separatorWidth or 0)
    row._iconSeparatorWidth = separatorThickness or 0
    if separatorStartX and separatorWidth > 0 then
        local separatorX = separatorStartX + math.floor(((separatorWidth - separatorThickness) * 0.5) + 0.5)
        row.iconSeparator:SetPoint("TOPLEFT", row, "TOPLEFT", separatorX, -IT_ICON_SEPARATOR_VERTICAL_INSET)
        row.iconSeparator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", separatorX, IT_ICON_SEPARATOR_VERTICAL_INSET)
        row.iconSeparator:SetWidth(separatorThickness)
    else
        row.iconSeparator:SetWidth(0)
    end
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", laneX, 0)
    row.bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.content:SetAllPoints(row.bar)

    if modeB then
        if db.rightDisplay == "timer" then
            row.countText:SetPoint("LEFT", row.content, "RIGHT", -48, 0)
            row.countText:SetPoint("RIGHT", row.content, "RIGHT", -barInset, 0)
        else
            row.countText:SetPoint("RIGHT", row.content, "RIGHT", -barInset, 0)
        end
        row.nameText:SetPoint("LEFT", row.content, "LEFT", barInset, 0)
        row.nameText:SetPoint("RIGHT", row.countText, "LEFT", -8, 0)
    else
        local iconEdge = -barInset
        for slot = #row.extraIcons, 1, -1 do
            local extra = row.extraIcons[slot]
            extra:SetPoint("RIGHT", row.content, "RIGHT", iconEdge, 0)
            extra:SetSize(math.max(10, iconSize - 6), math.max(10, iconSize - 6))
            iconEdge = iconEdge - (math.max(10, iconSize - 6) + 2)
        end
        row.extraMoreText:SetPoint("RIGHT", row.content, "RIGHT", -barInset, 0)
        row.cooldownText:SetPoint("RIGHT", row.content, "RIGHT", iconEdge, 0)
        row.nameText:SetPoint("LEFT", row.content, "LEFT", barInset, 0)
        row.nameText:SetPoint("RIGHT", row.cooldownText, "LEFT", -8, 0)
    end
end

function InterruptTracker:GetPreviewRows()
    local now = GetTime()
    self:EnsurePreviewState(now)

    local rows = {}
    local seenNames = {}
    local hasSelfRow = false
    local roster = self:GetCurrentRoster(true)
    local syntheticPool = {
        { name = IT_NormalizeName(UnitName("player")) or "You", class = self.playerClass or IT_SafeUnitClass("player") or "MAGE", isSelf = true, fromAddon = true },
        { name = "Shifta", class = "SHAMAN", fromAddon = true },
        { name = "Hunterx", class = "HUNTER", fromAddon = false },
        { name = "Spellpet", class = "WARLOCK", fromAddon = true },
        { name = "Shieldbro", class = "WARRIOR", fromAddon = false },
    }

    local function addPreviewRow(name, classFile, isSelf, fromAddon)
        local normalized = IT_NormalizeName(name)
        if not normalized or seenNames[normalized] then
            return false
        end
        local primary = IT_GetClassDefaultInterrupt(classFile)
        rows[#rows + 1] = {
            name = normalized,
            class = classFile,
            spellID = primary and primary.spellID or nil,
            baseCd = tonumber(primary and primary.baseCd) or 15,
            icon = primary and primary.icon or 134400,
            fromAddon = fromAddon and true or false,
            isSelf = isSelf and true or false,
            isPreview = true,
            previewAvailability = "confirmed",
            extraKicks = {},
        }
        seenNames[normalized] = true
        if isSelf then
            hasSelfRow = true
        end
        return true
    end

    for _, entry in ipairs(roster) do
        if #rows >= 5 then
            break
        end
        local classFile = entry.unit and IT_SafeUnitClass(entry.unit) or nil
        if entry.isSelf and not classFile then
            classFile = self.playerClass or IT_SafeUnitClass("player")
        end
        addPreviewRow(entry.name, classFile, entry.isSelf, true)
    end

    if not hasSelfRow and #rows < 5 then
        local syntheticSelf = syntheticPool[1]
        addPreviewRow(syntheticSelf.name, syntheticSelf.class, true, syntheticSelf.fromAddon)
    end

    for _, sample in ipairs(syntheticPool) do
        if #rows >= 5 then
            break
        end
        addPreviewRow(sample.name, sample.class, sample.isSelf and not hasSelfRow, sample.fromAddon)
    end

    local fillerIndex = 1
    while #rows < 5 do
        local sample = syntheticPool[((fillerIndex - 1) % #syntheticPool) + 1]
        addPreviewRow(string.format("%s%d", tostring(sample.name or "Preview"), fillerIndex), sample.class, sample.isSelf and not hasSelfRow, sample.fromAddon)
        fillerIndex = fillerIndex + 1
    end

    table.sort(rows, function(a, b)
        local aCd = tonumber(a.baseCd) or 999
        local bCd = tonumber(b.baseCd) or 999
        if aCd ~= bCd then
            return aCd < bCd
        end
        return tostring(IT_NormalizeName(a.name) or a.name or "") < tostring(IT_NormalizeName(b.name) or b.name or "")
    end)

    self.previewCycleOffsetByKey = self.previewCycleOffsetByKey or {}
    for index, row in ipairs(rows) do
        local baseCd = math.max(1, tonumber(row.baseCd) or 15)
        local previewKey = string.format("%s:%d", tostring(IT_NormalizeName(row.name) or row.name or ("preview" .. index)), index)
        local cycleLength = baseCd + IT_PREVIEW_READY_HOLD
        local offset = self.previewCycleOffsetByKey[previewKey]
        if offset == nil then
            offset = ((index - 1) * 0.85) + ((baseCd % 5) * 0.17)
            self.previewCycleOffsetByKey[previewKey] = offset
        end
        local phase = ((now - (tonumber(self.previewStartedAt) or now)) + offset) % cycleLength
        local previewReady = phase < IT_PREVIEW_READY_HOLD
        local previewRemaining = previewReady and 0 or math.max(0, baseCd - (phase - IT_PREVIEW_READY_HOLD))

        row.previewKey = previewKey
        row.previewReady = previewReady
        row.previewRemaining = previewRemaining
        row.previewModeBSortRemaining = IT_SnapPreviewModeBRemaining(previewRemaining)
        row.previewModeBSortIndex = index
        row.previewCountValue = index - 1
        row.cdEnd = previewReady and 0 or (now + previewRemaining)
    end

    return rows
end

function InterruptTracker:GetPreviewModeBRows()
    local now = GetTime()
    self:EnsurePreviewState(now)

    local pool = {}
    for _, entry in ipairs(IT_PREVIEW_MODEB_POOL) do
        local primary = IT_GetPreviewModeBPrimary(entry)
        if primary then
            pool[#pool + 1] = {
                name = entry.name,
                class = entry.class,
                specID = entry.specID,
                specName = entry.specName,
                spellID = primary.spellID,
                baseCd = tonumber(primary.baseCd) or 15,
                icon = primary.icon or IT_GetPrimaryIcon(primary.spellID),
                fromAddon = true,
                isSelf = false,
                isPreview = true,
                previewAvailability = "confirmed",
                previewUseClassIcon = entry.previewUseClassIcon and true or false,
                isPetSpell = primary.isPetSpell and true or false,
                petSpellID = primary.petSpellID,
                extraKicks = {},
            }
        end
    end

    if #pool == 0 then
        return {}
    end

    local windowGroups = {}
    local startIndex = 1
    while startIndex <= #pool do
        local group = { rows = {}, duration = 0, phaseSpacing = 3.0 }
        local maxBaseCd = 1
        for offset = 0, IT_PREVIEW_MODEB_WINDOW_SIZE - 1 do
            local index = ((startIndex + offset - 1) % #pool) + 1
            local row = pool[index]
            group.rows[#group.rows + 1] = row
            maxBaseCd = math.max(maxBaseCd, tonumber(row.baseCd) or 15)
        end
        group.phaseSpacing = math.max(
            IT_PREVIEW_MODEB_PHASE_SPACING_MIN,
            math.min(
                IT_PREVIEW_MODEB_PHASE_SPACING_MAX,
                (maxBaseCd + IT_PREVIEW_MODEB_READY_HOLD) / (IT_PREVIEW_MODEB_WINDOW_SIZE + 1)
            )
        )
        group.duration = math.max(1, (maxBaseCd + IT_PREVIEW_MODEB_READY_HOLD) * IT_PREVIEW_MODEB_ROTATION_CYCLES)
        windowGroups[#windowGroups + 1] = group
        startIndex = startIndex + IT_PREVIEW_MODEB_WINDOW_SIZE
    end

    local totalDuration = 0
    for _, group in ipairs(windowGroups) do
        totalDuration = totalDuration + (tonumber(group.duration) or 0)
    end
    local elapsed = math.max(0, now - (tonumber(self.previewStartedAt) or now))
    local windowElapsed = (totalDuration > 0) and (elapsed % totalDuration) or 0
    local activeGroup = windowGroups[1]
    local activeGroupIndex = 1
    for groupIndex, group in ipairs(windowGroups) do
        local duration = tonumber(group.duration) or 0
        if windowElapsed < duration then
            activeGroup = group
            activeGroupIndex = groupIndex
            break
        end
        windowElapsed = windowElapsed - duration
    end

    local previewWindowRound = (totalDuration > 0) and math.floor(elapsed / totalDuration) or 0
    local previewWindowKey = string.format("%d:%d", activeGroupIndex, previewWindowRound)
    local previewAuthorityMap = IT_GetPreviewWindowAuthorityMap(activeGroup.rows or {}, previewWindowKey)
    self.previewCycleOffsetByKey = self.previewCycleOffsetByKey or {}
    local rows = {}
    for index, row in ipairs(activeGroup.rows or {}) do
        local previewKey = string.format("preview_modeb:%s:%d", tostring(IT_NormalizeName(row.name) or row.name or ("preview" .. index)), index)
        local baseCd = math.max(1, tonumber(row.baseCd) or 15)
        local cycleLength = math.max(1, baseCd + IT_PREVIEW_MODEB_READY_HOLD)
        local offset = self.previewCycleOffsetByKey[previewKey]
        if offset == nil then
            offset = ((index - 1) * (tonumber(activeGroup.phaseSpacing) or 3.0)) + ((baseCd % 5) * 0.11)
            self.previewCycleOffsetByKey[previewKey] = offset
        end
        local phase = (windowElapsed + offset) % cycleLength
        local previewReady = phase < IT_PREVIEW_MODEB_READY_HOLD
        local previewRemaining = previewReady and 0 or math.max(0, baseCd - (phase - IT_PREVIEW_MODEB_READY_HOLD))
        local nameKey = tostring(IT_NormalizeName(row.name) or row.name or ("preview" .. index))

        row.previewKey = previewKey
        row.previewReady = previewReady
        row.previewRemaining = previewRemaining
        row.previewModeBSortRemaining = IT_SnapPreviewModeBRemaining(previewRemaining)
        row.previewModeBSortIndex = index
        row.previewWindowKey = previewWindowKey
        row.previewCountValue = index - 1
        row.fromAddon = previewAuthorityMap[nameKey] and true or false
        row.cdEnd = previewReady and 0 or (now + previewRemaining)
        rows[#rows + 1] = row
    end

    IT_ApplyPreviewModeBCooldownGap(rows, now)

    return rows
end

function InterruptTracker:ApplyPreviewModeBSwapHysteresis(sortedRows, now)
    return sortedRows
end

function InterruptTracker:BuildModeARows()
    local rows = self:IsPreviewMode() and self:GetPreviewRows() or self:GetCurrentPrimaryOrder()
    local now = GetTime()
    local confirmed = {}
    local stale = {}
    local dead = {}
    local unavailable = {}
    for _, member in ipairs(rows) do
        local availability = self:GetMemberAvailability(member, now)
        if member.isSelf then
            confirmed[#confirmed + 1] = member
        elseif availability.visible then
            if availability.bucket == "confirmed" then
                confirmed[#confirmed + 1] = member
            elseif availability.bucket == "stale" then
                stale[#stale + 1] = member
            elseif availability.bucket == "dead" then
                dead[#dead + 1] = member
            else
                unavailable[#unavailable + 1] = member
            end
        end
    end
    for _, member in ipairs(stale) do
        confirmed[#confirmed + 1] = member
    end
    for _, member in ipairs(dead) do
        confirmed[#confirmed + 1] = member
    end
    for _, member in ipairs(unavailable) do
        confirmed[#confirmed + 1] = member
    end
    return confirmed
end

function InterruptTracker:BuildModeBMemberTickState(member, previewMode, now)
    local isPreview = member and member.isPreview
    local availability = isPreview and {
        bucket = member.previewAvailability or "confirmed",
        visible = true,
        connected = true,
        isDead = false,
    } or self:GetMemberAvailability(member, now)
    local confirmed = availability.bucket == "confirmed"
    local trackable = confirmed or availability.bucket == "stale" or availability.bucket == "dead"
    local remaining = isPreview and math.max(0, tonumber(member.previewRemaining) or 0) or self:GetMemberRemaining(member, now)
    local ready = isPreview and (member.previewReady and true or false) or self:IsMemberReady(member, now)
    local displayGroup = availability.bucket == "confirmed" and (ready and 1 or 2)
        or (availability.bucket == "stale" and 3)
        or (availability.bucket == "dead" and 4)
        or 5

    return {
        availability = availability,
        available = confirmed,
        confirmed = confirmed,
        trackable = trackable,
        visible = availability.visible and true or false,
        ready = ready,
        remaining = remaining,
        displayGroup = displayGroup,
        sortRemaining = previewMode
            and (tonumber(member.previewModeBSortRemaining) or IT_SnapPreviewModeBRemaining(member.previewRemaining))
            or IT_SnapRemaining(remaining),
    }
end

function InterruptTracker:BuildModeBRows(perfState, now)
    local rows = {}
    local previewMode = self:IsPreviewMode()
    local collectStart, collectState = PA_PerfBegin("interrupt_ud_collect", perfState)
    if previewMode then
        rows = self:GetPreviewModeBRows()
    else
        local db = self:GetDB()
        for _, name in ipairs(db.rotationOrder or {}) do
            local member = self:FindMemberByName(name)
            if self:MemberQualifiesForSeed(member) then
                rows[#rows + 1] = member
            end
        end
    end

    now = now or GetTime()
    local visibleRows = {}
    local tickMemberState = {}
    for _, member in ipairs(rows) do
        local tickState = self:BuildModeBMemberTickState(member, previewMode, now)
        tickMemberState[member] = tickState
        if tickState.visible then
            if previewMode then
                member.previewModeBDisplayGroup = tickState.displayGroup
            end
            visibleRows[#visibleRows + 1] = member
        end
    end
    self._displayTickMemberState = tickMemberState
    PA_PerfEnd("interrupt_ud_collect", collectStart, collectState)

    -- Mode B display order is recomputed locally every tick; compatibility ROT/ROTIDX never render.
    local sortStart, sortState = PA_PerfBegin("interrupt_ud_sort", perfState)
    table.sort(visibleRows, function(a, b)
        local aState = tickMemberState[a]
        local bState = tickMemberState[b]
        local aGroup = aState and aState.displayGroup or 5
        local bGroup = bState and bState.displayGroup or 5
        if aGroup ~= bGroup then
            return aGroup < bGroup
        end

        if aGroup == 2 then
            local aRemaining = aState and aState.sortRemaining or 0
            local bRemaining = bState and bState.sortRemaining or 0
            if aRemaining ~= bRemaining and ((not previewMode) or math.abs(aRemaining - bRemaining) > IT_PREVIEW_MODEB_REORDER_THRESHOLD) then
                return aRemaining < bRemaining
            end
            if previewMode then
                local aIndex = tonumber(a.previewModeBSortIndex) or 999
                local bIndex = tonumber(b.previewModeBSortIndex) or 999
                if aIndex ~= bIndex then
                    return aIndex < bIndex
                end
            end
        end

        local aCd = tonumber(a.baseCd) or 999
        local bCd = tonumber(b.baseCd) or 999
        if aCd ~= bCd then
            return aCd < bCd
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)
    if previewMode then
        visibleRows = self:ApplyPreviewModeBSwapHysteresis(visibleRows, now)
    end
    PA_PerfEnd("interrupt_ud_sort", sortStart, sortState)
    return visibleRows
end

function InterruptTracker:UpdateRowDynamicVisual(row, member, modeB, now, tickState)
    if not row or not member then
        return
    end

    local db = self:GetDB()
    local isPreview = member and member.isPreview
    local availability = tickState and tickState.availability or (isPreview and {
        bucket = member.previewAvailability or "confirmed",
        visible = true,
        connected = true,
        isDead = false,
    } or self:GetMemberAvailability(member, now))
    local bucket = availability and availability.bucket or "offline"
    local confirmed = tickState and tickState.confirmed
    if confirmed == nil then
        confirmed = bucket == "confirmed"
    end
    local trackable = tickState and tickState.trackable
    if trackable == nil then
        trackable = confirmed or bucket == "stale" or bucket == "dead"
    end
    local remaining = tickState and tickState.remaining
    if remaining == nil then
        remaining = isPreview and math.max(0, tonumber(member.previewRemaining) or 0) or self:GetMemberRemaining(member, now)
    end
    local ready = tickState and tickState.ready
    if ready == nil then
        ready = isPreview and (member.previewReady and true or false) or self:IsMemberReady(member, now)
    end
    local fillR, fillG, fillB = self:GetDisplayColor(member)
    local primaryCd = tonumber(member.baseCd) or 15
    local fontColor = db.fontColor or { r = 1, g = 1, b = 1, a = 1 }
    local bgOpacity = IT_GetConfiguredRowBackgroundOpacity(db)
    local rightDisplay = db.rightDisplay == "timer" and "timer" or "count"
    local renderState = row._dynamicRenderState
    if type(renderState) ~= "table" then
        renderState = {}
        row._dynamicRenderState = renderState
    end
    local textColorR, textColorG, textColorB, textColorA = fontColor.r, fontColor.g, fontColor.b, fontColor.a
    local iconAlpha = 1.0
    local iconDesaturated = (modeB and not ready) and true or false

    if not trackable then
        IT_DYNAMIC_RENDER.SetStatusBarColorIfChanged(row.bar, renderState, "barColor", IT_UNAVAILABLE_BAR[1], IT_UNAVAILABLE_BAR[2], IT_UNAVAILABLE_BAR[3], IT_UNAVAILABLE_BAR[4])
        IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(row.bar, renderState, "barRange", 0, 1, 1)
        IT_DYNAMIC_RENDER.SetVertexColorIfChanged(row.barBg, renderState, "barBgColor", IT_UNAVAILABLE_BG[1], IT_UNAVAILABLE_BG[2], IT_UNAVAILABLE_BG[3], bgOpacity)
        textColorR, textColorG, textColorB, textColorA = IT_UNAVAILABLE_TEXT[1], IT_UNAVAILABLE_TEXT[2], IT_UNAVAILABLE_TEXT[3], IT_UNAVAILABLE_TEXT[4]
        iconAlpha = IT_AVAILABILITY_VISUALS.unavailableIconAlpha
        iconDesaturated = true
    elseif bucket == "dead" then
        IT_DYNAMIC_RENDER.SetStatusBarColorIfChanged(row.bar, renderState, "barColor", IT_AVAILABILITY_VISUALS.deadBar[1], IT_AVAILABILITY_VISUALS.deadBar[2], IT_AVAILABILITY_VISUALS.deadBar[3], IT_AVAILABILITY_VISUALS.deadBar[4])
        if ready or primaryCd <= 0 then
            IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(row.bar, renderState, "barRange", 0, 1, 1)
        else
            IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(row.bar, renderState, "barRange", 0, primaryCd, remaining)
        end
        IT_DYNAMIC_RENDER.SetVertexColorIfChanged(row.barBg, renderState, "barBgColor", IT_AVAILABILITY_VISUALS.deadBg[1], IT_AVAILABILITY_VISUALS.deadBg[2], IT_AVAILABILITY_VISUALS.deadBg[3], bgOpacity)
        textColorR, textColorG, textColorB, textColorA = IT_AVAILABILITY_VISUALS.deadText[1], IT_AVAILABILITY_VISUALS.deadText[2], IT_AVAILABILITY_VISUALS.deadText[3], IT_AVAILABILITY_VISUALS.deadText[4]
        iconAlpha = IT_AVAILABILITY_VISUALS.deadIconAlpha
        iconDesaturated = true
    elseif bucket == "stale" then
        local staleBlend = math.max(0, math.min(1, tonumber(IT_AVAILABILITY_VISUALS.staleBarBlend) or 0))
        local staleKeep = 1 - staleBlend
        local staleR = (fillR * staleKeep) + (IT_UNAVAILABLE_BAR[1] * staleBlend)
        local staleG = (fillG * staleKeep) + (IT_UNAVAILABLE_BAR[2] * staleBlend)
        local staleB = (fillB * staleKeep) + (IT_UNAVAILABLE_BAR[3] * staleBlend)
        IT_DYNAMIC_RENDER.SetStatusBarColorIfChanged(row.bar, renderState, "barColor", staleR, staleG, staleB, modeB and 0.84 or 0.70)
        if ready or primaryCd <= 0 then
            IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(row.bar, renderState, "barRange", 0, 1, 1)
        else
            IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(row.bar, renderState, "barRange", 0, primaryCd, remaining)
        end
        IT_DYNAMIC_RENDER.SetVertexColorIfChanged(row.barBg, renderState, "barBgColor", IT_AVAILABILITY_VISUALS.staleBg[1], IT_AVAILABILITY_VISUALS.staleBg[2], IT_AVAILABILITY_VISUALS.staleBg[3], bgOpacity)
        textColorR, textColorG, textColorB, textColorA = IT_AVAILABILITY_VISUALS.staleText[1], IT_AVAILABILITY_VISUALS.staleText[2], IT_AVAILABILITY_VISUALS.staleText[3], IT_AVAILABILITY_VISUALS.staleText[4]
        iconAlpha = IT_AVAILABILITY_VISUALS.staleIconAlpha
    else
        IT_DYNAMIC_RENDER.SetStatusBarColorIfChanged(row.bar, renderState, "barColor", fillR, fillG, fillB, modeB and 0.92 or 0.76)
        if ready or primaryCd <= 0 then
            IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(row.bar, renderState, "barRange", 0, 1, 1)
        else
            IT_DYNAMIC_RENDER.SetStatusBarRangeAndValueIfChanged(row.bar, renderState, "barRange", 0, primaryCd, remaining)
        end
        IT_DYNAMIC_RENDER.SetVertexColorIfChanged(row.barBg, renderState, "barBgColor", IT_BG_BAR[1], IT_BG_BAR[2], IT_BG_BAR[3], bgOpacity)
    end

    if row.barAccent then
        if row.barAccent.anim and row.barAccent.anim:IsPlaying() then
            row.barAccent.anim:Stop()
        end
        local accentShown = confirmed and not ready and primaryCd > 0
        IT_DYNAMIC_RENDER.SetShownIfChanged(row.barAccent, renderState, "barAccentShown", accentShown)
        IT_DYNAMIC_RENDER.SetAlphaIfChanged(row.barAccent, renderState, "barAccentAlpha", accentShown and IT_BAR_ACCENT_ALPHA or 0)
    end

    IT_DYNAMIC_RENDER.SetTextColorIfChanged(row.nameText, renderState, "nameColor",
        textColorR,
        textColorG,
        textColorB,
        textColorA
    )
    if member.fromAddon then
        IT_DYNAMIC_RENDER.SetVertexColorIfChanged(row.iconSeparator, renderState, "separatorColor", IT_ADDON_SEPARATOR[1], IT_ADDON_SEPARATOR[2], IT_ADDON_SEPARATOR[3], IT_ADDON_SEPARATOR[4])
    else
        IT_DYNAMIC_RENDER.SetVertexColorIfChanged(row.iconSeparator, renderState, "separatorColor", IT_FALLBACK_SEPARATOR[1], IT_FALLBACK_SEPARATOR[2], IT_FALLBACK_SEPARATOR[3], IT_FALLBACK_SEPARATOR[4])
    end
    if modeB then
        if rightDisplay == "timer" then
            if not trackable then
                IT_DYNAMIC_RENDER.SetTextIfChanged(row.countText, renderState, "countText", "-")
                IT_DYNAMIC_RENDER.SetTextColorIfChanged(row.countText, renderState, "countColor", IT_UNAVAILABLE_TEXT[1], IT_UNAVAILABLE_TEXT[2], IT_UNAVAILABLE_TEXT[3], IT_UNAVAILABLE_TEXT[4])
            elseif ready or remaining <= IT_READY_THRESHOLD then
                IT_DYNAMIC_RENDER.SetTextIfChanged(row.countText, renderState, "countText", "")
                IT_DYNAMIC_RENDER.SetTextColorIfChanged(row.countText, renderState, "countColor", textColorR, textColorG, textColorB, textColorA)
            else
                IT_DYNAMIC_RENDER.SetTextIfChanged(row.countText, renderState, "countText", string.format("%.1f", remaining))
                IT_DYNAMIC_RENDER.SetTextColorIfChanged(row.countText, renderState, "countColor", textColorR, textColorG, textColorB, textColorA)
            end
        else
            IT_DYNAMIC_RENDER.SetTextIfChanged(row.countText, renderState, "countText", tostring(isPreview and (member.previewCountValue or 0) or self:GetCount(member.name)))
            IT_DYNAMIC_RENDER.SetTextColorIfChanged(row.countText, renderState, "countColor", textColorR, textColorG, textColorB, textColorA)
        end
    else
        IT_DYNAMIC_RENDER.SetTextIfChanged(row.countText, renderState, "countText", "")
    end
    IT_DYNAMIC_RENDER.SetTextIfChanged(row.cooldownText, renderState, "cooldownText", ready and "READY" or IT_FormatCooldown(remaining))
    if confirmed and ready then
        IT_DYNAMIC_RENDER.SetTextColorIfChanged(row.cooldownText, renderState, "cooldownColor", 0.30, 1.00, 0.30, 1.00)
    else
        IT_DYNAMIC_RENDER.SetTextColorIfChanged(row.cooldownText, renderState, "cooldownColor", textColorR, textColorG, textColorB, textColorA)
    end

    IT_DYNAMIC_RENDER.SetDesaturatedIfChanged(row.spellIcon, renderState, "spellIconDesaturated", iconDesaturated)
    IT_DYNAMIC_RENDER.SetAlphaIfChanged(row.spellIcon, renderState, "spellIconAlpha", iconAlpha)
    IT_DYNAMIC_RENDER.SetAlphaIfChanged(row.classIcon, renderState, "classIconAlpha", iconAlpha)
    local useGlowTarget = IT_GetRowUseGlowTarget(row, member, db)
    IT_DYNAMIC_RENDER.PositionRowUseGlowIfChanged(row, renderState, useGlowTarget)

    self.rowReadyState = self.rowReadyState or {}
    local readyKey = isPreview and member.previewKey and ("preview:" .. member.previewKey) or IT_NormalizeName(member.name)
    local previous = self.rowReadyState[readyKey]
    if previous == nil then
        self.rowReadyState[readyKey] = ready
    else
        if confirmed and ready and not previous then
            if not isPreview then
                self:PlayAlertSoundFor(member.name)
            end
        elseif confirmed and previous and not ready then
            if useGlowTarget and row.spellIconGlow and row.spellIconGlow.anim then
                IT_PositionRowUseGlow(row, useGlowTarget)
                if row.spellIconGlow.anim:IsPlaying() then
                    row.spellIconGlow.anim:Stop()
                end
                row.spellIconGlow:SetAlpha(0)
                row.spellIconGlow.anim:Play()
            end
        end
        self.rowReadyState[readyKey] = ready
    end
end

function InterruptTracker:ApplyRowStaticVisual(row, member, modeB, now)
    local db = self:GetDB()
    row._dynamicRenderState = nil

    IT_ApplyClassIconTexture(row.classIcon, member.class)
    if modeB and member.previewUseClassIcon and member.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[member.class] then
        IT_ApplyClassIconTexture(row.spellIcon, member.class)
    else
        row.spellIcon:SetTexture(member.icon or IT_GetPrimaryIcon(member.spellID))
        row.spellIcon:SetTexCoord(0, 1, 0, 1)
    end

    self:ApplyRowLayout(row, modeB)

    row.countText:SetShown(modeB)
    row.cooldownText:SetShown(not modeB)
    row.classIcon:SetShown(db.showClassIcon and member.class ~= nil)
    row.spellIcon:SetShown(db.showSpellIcon and member.spellID ~= nil)
    row.iconSeparator:SetShown((db.showClassIcon or db.showSpellIcon) and (tonumber(row._iconSeparatorWidth) or 0) > 0)
    row.badgeText:SetShown(false)
    row.badgeText:SetText("")
    row.nameText:SetText(member.name or "")

    row.bar:SetStatusBarTexture(self:GetBarTexture())
    row.barBg:SetTexture(self:GetBarTexture())
    row:SetBackdropColor(IT_BG_BAR[1], IT_BG_BAR[2], IT_BG_BAR[3], IT_GetConfiguredRowBackgroundOpacity(db))
    if row.bar.SetReverseFill then
        row.bar:SetReverseFill(false)
    end
    if row.barAccent then
        local statusTexture = row.bar.GetStatusBarTexture and row.bar:GetStatusBarTexture() or nil
        if statusTexture then
            row.barAccent:ClearAllPoints()
            row.barAccent:SetPoint("TOPRIGHT", statusTexture, "TOPRIGHT", 0, 0)
            row.barAccent:SetPoint("BOTTOMRIGHT", statusTexture, "BOTTOMRIGHT", 0, 0)
            row.barAccent:SetWidth(IT_BAR_ACCENT_WIDTH)
        end
    end

    for _, extra in ipairs(row.extraIcons) do
        extra:Hide()
    end
    row.extraMoreText:Hide()
    if not modeB then
        local currentTime = now or GetTime()
        local shown = 0
        for _, extra in ipairs(member.extraKicks or {}) do
            if shown < #row.extraIcons then
                shown = shown + 1
                local slot = row.extraIcons[shown]
                slot:SetTexture(extra.icon or IT_GetPrimaryIcon(extra.spellID))
                slot:SetDesaturated(not IT_IsReady(extra.cdEnd or 0, currentTime))
                slot:Show()
            end
        end
        if #(member.extraKicks or {}) > #row.extraIcons then
            row.extraMoreText:SetText("+" .. tostring(#(member.extraKicks or {}) - #row.extraIcons))
            row.extraMoreText:Show()
        end
    end

    row._displayMember = member
    row._displayModeB = modeB and true or false
end

function InterruptTracker:UpdateDisplayStructure(db, rowsData, modeB, previewMode, now, perfState, structureSignature)
    local rowHeight = db.rowHeight
    local rowGap = self:GetRowGap()
    local rowStride = rowHeight + rowGap
    local visible = 0
    local poolIndex = 0
    local assignments = {}
    local pulseTargets = {}
    local tickMemberState = self._displayTickMemberState

    local hideStart, hideState = PA_PerfBegin("interrupt_ud_hide_sweep", perfState)
    if self.selfRowHost then
        self.selfRowHost:Hide()
        self.selfRowHost._paSpacingPulseY = nil
    end
    if self.selfRow then
        self.selfRow:Hide()
        self.selfRow._displayMember = nil
    end
    for _, row in ipairs(self.rows or {}) do
        row:Hide()
        row._displayMember = nil
        row._paSpacingPulseY = nil
    end
    PA_PerfEnd("interrupt_ud_hide_sweep", hideStart, hideState)

    local anchorStart, anchorState = PA_PerfBegin("interrupt_ud_anchor", perfState)
    for _, member in ipairs(rowsData or {}) do
        local row = nil
        local pulseTarget = nil
        local rowOffsetY = -((visible) * rowStride)
        if member and member.isSelf and self.selfRow then
            row = self.selfRow
            if self.selfRowHost then
                self.selfRowHost:ClearAllPoints()
                self.selfRowHost:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, rowOffsetY)
                self.selfRowHost:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, rowOffsetY)
                self.selfRowHost:SetSize(db.width, rowHeight)
                self.selfRowHost._paSpacingPulseY = rowOffsetY
                self.selfRowHost:Show()
                pulseTarget = self.selfRowHost
            else
                pulseTarget = row
            end
        else
            poolIndex = poolIndex + 1
            row = self.rows and self.rows[poolIndex] or nil
            if row then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, rowOffsetY)
                row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, rowOffsetY)
                row._paSpacingPulseY = rowOffsetY
                pulseTarget = row
            end
        end
        if row and member then
            visible = visible + 1
            row:Show()
            assignments[#assignments + 1] = {
                row = row,
                member = member,
                modeB = modeB and true or false,
                tickState = tickMemberState and tickMemberState[member] or nil,
            }
            pulseTargets[#pulseTargets + 1] = pulseTarget
        end
    end
    PA_PerfEnd("interrupt_ud_anchor", anchorStart, anchorState)

    local staticStart, staticState = PA_PerfBegin("interrupt_ud_row_static", perfState)
    for _, assignment in ipairs(assignments) do
        self:ApplyRowStaticVisual(assignment.row, assignment.member, assignment.modeB, now)
    end
    PA_PerfEnd("interrupt_ud_row_static", staticStart, staticState)

    local frameStart, frameState = PA_PerfBegin("interrupt_ud_frame", perfState)
    self._displayAssignments = assignments
    self._displayRowCount = visible
    self._displayModeB = modeB and true or false
    self._displayPreviewMode = previewMode and true or false
    self._displayStructureSignature = structureSignature
    self._displayStructureDirty = false
    self._visibleRowPulseTargets = pulseTargets

    if visible <= 0 then
        self.frame:SetSize(db.width, 1)
        PA_CpuDiagApplyVisibility("interrupt", self.frame, self.unlocked)
    else
        self.frame:SetSize(db.width, math.max(1, (visible * rowHeight) + math.max(0, visible - 1) * rowGap))
        PA_CpuDiagApplyVisibility("interrupt", self.frame, true)
    end
    self:SetUnlocked(not self:GetDB().locked)
    PA_PerfEnd("interrupt_ud_frame", frameStart, frameState)
end

function InterruptTracker:UpdateDisplayDynamic(now, perfState)
    local dynamicStart, dynamicState = PA_PerfBegin("interrupt_ud_dynamic", perfState)
    for _, assignment in ipairs(self._displayAssignments or {}) do
        if assignment and assignment.row and assignment.member then
            self:UpdateRowDynamicVisual(assignment.row, assignment.member, assignment.modeB and true or false, now, assignment.tickState)
        end
    end
    PA_PerfEnd("interrupt_ud_dynamic", dynamicStart, dynamicState)
end

function InterruptTracker:ApplyRowVisual(row, member, modeB, now)
    self:ApplyRowStaticVisual(row, member, modeB, now)
    self:UpdateRowDynamicVisual(row, member, modeB, now, nil)
end

function InterruptTracker:UpdateDisplay()
    PA_CpuDiagCount("interrupt_update_display")
    local perfStart, perfState = PA_PerfBegin("interrupt_update_display")
    local function finish(...)
        PA_PerfEnd("interrupt_update_display", perfStart, perfState)
        return ...
    end

    if PA_IsUiSurfaceGateEnabled() then
        if self.frame then
            self:StopTicker()
            self:StopPeriodicInspect()
            self:SetSpacingHandleEnabled(false)
            PA_CpuDiagApplyVisibility("interrupt", self.frame, false)
        end
        return finish()
    end

    if not self.frame then
        return finish()
    end
    if not self:IsEnabled() then
        self:MarkDisplayStructureDirty("module-disabled")
        self:StopTicker()
        self:StopPeriodicInspect()
        self:SetSpacingHandleEnabled(false)
        PA_CpuDiagApplyVisibility("interrupt", self.frame, false)
        return finish()
    end
    local previewMode = self:IsPreviewMode()
    local shouldShow = self:IsSupportedLiveContext() or previewMode
    if not shouldShow then
        self:MarkDisplayStructureDirty("visibility-hidden")
        PA_CpuDiagApplyVisibility("interrupt", self.frame, false)
        return finish()
    end

    local now = GetTime()
    local prepareStart, prepareState = PA_PerfBegin("interrupt_ud_prepare", perfState)
    self:ExpireOwnerInterruptPending(now)
    if previewMode then
        self:EnsurePreviewState(now)
    else
        self:RefreshAvailabilityGate()
        self:RefreshFullWipeRecoveryState(now)
    end
    PA_PerfEnd("interrupt_ud_prepare", prepareStart, prepareState)

    local db = self:GetDB()
    local rowsData = self:BuildModeBRows(perfState, now)

    local signatureStart, signatureState = PA_PerfBegin("interrupt_ud_signature", perfState)
    local structureSignature = self:BuildDisplayStructureSignature(db, rowsData, true, previewMode)
    PA_PerfEnd("interrupt_ud_signature", signatureStart, signatureState)

    local structureDirty = self._displayStructureDirty
        or self._displayStructureSignature ~= structureSignature
        or type(self._displayAssignments) ~= "table"

    if not structureDirty and not self:RefreshDisplayAssignmentMembers(rowsData, true) then
        structureDirty = true
    end

    if structureDirty then
        self:UpdateDisplayStructure(db, rowsData, true, previewMode, now, perfState, structureSignature)
    end

    self:UpdateDisplayDynamic(now, perfState)
    return finish()
end

function InterruptTracker:StartTicker()
    if self.ticker or not self.frame then
        return
    end
    self.frame:SetScript("OnUpdate", nil)
    self.ticker = C_Timer.NewTicker(IT_DISPLAY_TICK, function()
        pcall(function()
            self:UpdateDisplay()
        end)
    end)
end

function InterruptTracker:StopTicker()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
    end
end

function InterruptTracker:StartPeriodicInspect()
    if self.inspectTicker then
        return false
    end
    self.inspectTicker = C_Timer.NewTicker(IT_PERIODIC_INSPECT, function()
        PA_CpuDiagCount("interrupt_periodic_inspect")
        local perfStart, perfState = PA_PerfBegin("interrupt_periodic_inspect")
        self:ResetInspectStateFor()
        self:QueuePartyInspect()
        PA_PerfEnd("interrupt_periodic_inspect", perfStart, perfState)
    end)
    return true
end

function InterruptTracker:StopPeriodicInspect()
    if self.inspectTicker then
        self.inspectTicker:Cancel()
        self.inspectTicker = nil
    end
    if self.inspectDelayTimer then
        self.inspectDelayTimer:Cancel()
        self.inspectDelayTimer = nil
    end
    self:CancelInspectStepTimer()
    self.inspectQueue = {}
    self:AbortInspectSession(false)
end

function InterruptTracker:UpdatePeriodicInspectState()
    if not self:ShouldRunPeriodicInspect() then
        self:StopPeriodicInspect()
        return false
    end
    local started = self:StartPeriodicInspect()
    if started and not self.inspectBusy and not self.inspectDelayTimer then
        self:QueuePartyInspectDelayed()
    end
    return true
end

function InterruptTracker:EvaluateVisibility()
    PA_CpuDiagCount("interrupt_evaluate_visibility")
    local perfStart, perfState = PA_PerfBegin("interrupt_evaluate_visibility")
    if PA_IsUiSurfaceGateEnabled() then
        if self.frame then
            self:StopTicker()
            self:StopPeriodicInspect()
            self:SetSpacingHandleEnabled(false)
            PA_CpuDiagApplyVisibility("interrupt", self.frame, false)
        end
        PA_PerfEnd("interrupt_evaluate_visibility", perfStart, perfState)
        return
    end
    if not self.frame then
        PA_PerfEnd("interrupt_evaluate_visibility", perfStart, perfState)
        return
    end
    if not self:IsEnabled() then
        self:MarkDisplayStructureDirty("module-disabled")
        self:StopTicker()
        self:StopPeriodicInspect()
        self:SetSpacingHandleEnabled(false)
        PA_CpuDiagApplyVisibility("interrupt", self.frame, false)
        PA_PerfEnd("interrupt_evaluate_visibility", perfStart, perfState)
        return
    end
    local shouldShow = self:IsSupportedLiveContext() or self:IsPreviewMode()
    local wasShown = PA_CpuDiagIsFrameConsideredShown("interrupt", self.frame)
    if shouldShow then
        if not wasShown then
            self:MarkDisplayStructureDirty("visibility")
        end
        PA_CpuDiagApplyVisibility("interrupt", self.frame, true)
        self:ApplyFonts()
        self:StartTicker()
        self:UpdateDisplay()
    else
        if wasShown or self.ticker then
            self:MarkDisplayStructureDirty("visibility-hidden")
        end
        self:StopTicker()
        self:SetSpacingHandleEnabled(false)
        PA_CpuDiagApplyVisibility("interrupt", self.frame, false)
    end
    self:UpdatePeriodicInspectState()
    PA_PerfEnd("interrupt_evaluate_visibility", perfStart, perfState)
end

function InterruptTracker:ApplySettings()
    if not self.frame then
        return
    end
    self:MarkDisplayStructureDirty("settings")
    self:ApplyPosition()
    self:ReseedModeBOrder(false)
    if self.selfRow then
        self.selfRow.bar:SetStatusBarTexture(self:GetBarTexture())
        self.selfRow.barBg:SetTexture(self:GetBarTexture())
    end
    for _, row in ipairs(self.rows or {}) do
        row.bar:SetStatusBarTexture(self:GetBarTexture())
        row.barBg:SetTexture(self:GetBarTexture())
    end
    self:ApplyFonts()
    self:EvaluateVisibility()
end

function InterruptTracker:GetWhoReportLines()
    if not self:IsTrackedPartyContext() then
        return nil, "Portal Authority: no current party to report."
    end
    self:BuildUnitMap()
    local roster = self:GetCurrentRoster(true)
    if #roster == 0 then
        return nil, "Portal Authority: no current party to report."
    end
    local now = GetTime()
    local lines = {}
    for _, entry in ipairs(roster) do
        local member = self:FindMemberByName(entry.name)
        local classText = "class unknown"
        local specText = "spec unknown"
        local interruptText = "interrupt unknown"
        local sourceText = "Untracked"
        local stateText = nil

        if entry.isSelf then
            classText = IT_GetLocalizedClassName(select(2, UnitClass("player"))) or classText
            local specIndex = GetSpecialization and GetSpecialization() or nil
            if specIndex and GetSpecializationInfo then
                local _, selfSpecName = GetSpecializationInfo(specIndex)
                if type(selfSpecName) == "string" and selfSpecName ~= "" then
                    specText = selfSpecName
                end
            end
        elseif entry.unit then
            classText = IT_GetLocalizedClassName(IT_SafeUnitClass(entry.unit)) or classText
        end

        if member then
            classText = IT_GetLocalizedClassName(member.class) or classText
            specText = self:GetSpecNameForMember(member) or "spec unknown"
            local spellData = self:GetPrimarySpellData(member)
            if spellData and spellData.name then
                interruptText = spellData.name
            end
            sourceText = member.fromAddon and "Portal Authority user" or "Fallback tracked"
            if member.spellID then
                if self:IsMemberReady(member, now) then
                    stateText = "READY"
                else
                    stateText = IT_FormatCooldown(self:GetMemberRemaining(member, now))
                end
            end
        end

        local line = string.format("%s - %s / %s - %s - %s", entry.name or "?", classText, specText, interruptText, sourceText)
        if stateText then
            line = line .. " - " .. stateText
        end
        lines[#lines + 1] = line
    end
    return lines, nil
end

function InterruptTracker:Initialize()
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    if self.frame then
        return
    end
    self:EnsureDB()
    self.trackedMembers = {}
    self.noInterruptPlayers = {}
    self.inspectedPlayers = {}
    self.inspectQueue = {}
    self.recentPartyCasts = {}
    self.interruptCounts = {}
    self.recentCountedInterruptsByMember = {}
    self.rowReadyState = {}
    self.memberUnits = {}
    self.remoteRotationState = {}
    self.inspectBusy = false
    self.inspectUnit = nil
    self.inspectTargetGUID = nil
    self.inspectTargetName = nil
    self.inspectTimeoutTimer = nil
    self.inspectStepTimer = nil
    self.lastHelloAt = 0
    self.availabilityArmed = false
    self.availabilityContextKey = nil
    self.pendingFullWipeRecovery = false
    self.fullWipeRecoveryActive = false
    self.fullWipeRecoveryStartedAt = 0
    self.lastPartyCombatSeenAt = 0
    self.lastPlayerDeadOrGhost = IT_IsUnitRealDeadOrGhost("player")
    self.pendingOwnerInterruptConfirm = nil
    self.pendingOwnerPrimaryCast = nil
    self.pendingOwnerPrimaryCastExpiryTimer = nil
    self.lastHandledOwnerPrimaryCastGUID = nil
    self.lastHandledOwnerPrimaryCastAt = 0
    self.lastOwnerPrimaryCastVerdictGUID = nil
    self.lastOwnerPrimaryCastVerdictAt = 0
    self.lastHandledInterruptedGUID = nil
    self.lastHandledInterruptedAt = 0
    self.partySentUsableIdentitySeen = false
    self.partyWatcherUnitActive = {}
    self.previewStartedAt = 0
    self.previewCycleOffsetByKey = {}
    self._visibleRowPulseTargets = {}
    self._rowGapBoundaryReached = false
    self._rowGapDrag = nil
    self._spacingUnlockHintVisible = false
    self._spacingHintShownForUnlock = false
    self:ResetDisplayStructureState()

    IT_SafeRegisterPrefix(PA_INTERRUPT_PREFIX)
    self:BuildFrame()
    self:RegisterSelfWatchers()
    self:RegisterPartyWatchers()
    self:RegisterMobInterruptWatchers()
    self:FindMyInterrupt()
    if not self.initialHelloScheduled and C_Timer and C_Timer.After then
        self.initialHelloScheduled = true
        C_Timer.After(2.0, function()
            PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_init_hello")
            local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
            self:FindMyInterrupt()
            self:AnnounceHello(false)
            PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
        end)
    end
    self:ApplyPosition()
    self:ApplySettings()
    self:UpdatePeriodicInspectState()
    self:SetUnlocked(not self:GetDB().locked)
end

-- Lifecycle / event dispatch
local function IT_HandleInterruptTrackerAddonChat(self, prefix, message, channel, sender)
    self:HandleAddonMessage(prefix, message, channel, sender)
end

local function IT_HandleInterruptTrackerPlayerEnteringWorld(self)
    self:UpdateRunContext()
    IT_SafeRegisterPrefix(PA_INTERRUPT_PREFIX)
    self:CleanupRosterState()
    self:RegisterPartyWatchers()
    self:AutoRegisterPartyByClass()
    C_Timer.After(2.0, function()
        PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_pew_queue")
        local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
        self:CleanupRosterState()
        self:QueuePartyInspect()
        PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
    end)
    C_Timer.After(3.0, function()
        PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_pew_hello")
        local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
        self:CleanupRosterState()
        self:FindMyInterrupt()
        self:AnnounceHello(true)
        self:AutoRegisterPartyByClass()
        PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
    end)
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerRosterUpdate(self)
    self:CleanupRosterState()
    self:RegisterPartyWatchers()
    self:AutoRegisterPartyByClass()
    self:QueuePartyInspectDelayed()
    if self:IsTrackedPartyContext() then
        self:AnnounceHello(false)
    end
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerSpecChanged(self, unit)
    if unit == "player" then
        self:FindMyInterrupt()
        self:AnnounceHello(false)
    else
        local changedName = IT_SafeUnitName(unit)
        if changedName then
            local seedChanged = false
            self:ResetInspectStateFor(changedName)
            self.noInterruptPlayers[changedName] = nil
            seedChanged = self:AutoRegisterUnitByClass(unit, true) and true or false
            if seedChanged then
                self:ReseedModeBOrder(true)
            end
            self:QueuePartyInspectDelayed(unit)
        else
            self:ResetInspectStateFor()
            self:AutoRegisterPartyByClass()
            self:QueuePartyInspectDelayed()
        end
    end
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerUnitPet(self, unit)
    if unit == "player" then
        self:FindMyInterrupt()
        self:AnnounceHello(false)
        C_Timer.After(IT_OWN_PET_RETRY_1, function()
            PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_unitpet_retry_1")
            local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
            self:FindMyInterrupt()
            self:AnnounceHello(false)
            PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
        end)
        C_Timer.After(IT_OWN_PET_RETRY_2, function()
            PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_unitpet_retry_2")
            local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
            self:FindMyInterrupt()
            self:AnnounceHello(false)
            PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
        end)
        C_Timer.After(IT_OWN_PET_RETRY_3, function()
            PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_unitpet_retry_3")
            local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
            self:FindMyInterrupt()
            self:AnnounceHello(false)
            PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
        end)
    else
        local changedName = IT_SafeUnitName(unit)
        if changedName then
            self:ResetInspectStateFor(changedName)
            self.noInterruptPlayers[changedName] = nil
        end
        self:RegisterPartyWatchers()
        self:AutoRegisterPartyByClass()
        self:QueuePartyInspectDelayed()
    end
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerSpellsChanged(self)
    self:FindMyInterrupt()
    self:AnnounceHello(false)
    if self.playerClass == "WARLOCK" then
        C_Timer.After(IT_WARLOCK_SPELLS_RETRY_1, function()
            PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_warlock_retry_1")
            local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
            self:FindMyInterrupt()
            self:AnnounceHello(false)
            PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
        end)
        C_Timer.After(IT_WARLOCK_SPELLS_RETRY_2, function()
            PA_CpuDiagCount("callback_class_delayed_timer", "interrupt_warlock_retry_2")
            local perfStart, perfState = PA_PerfBegin("callback_class_delayed_timer")
            self:FindMyInterrupt()
            self:AnnounceHello(false)
            PA_PerfEnd("callback_class_delayed_timer", perfStart, perfState)
        end)
    end
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerInspectReady(self, inspectedGUID)
    self:HandleInspectReady(inspectedGUID)
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerCombatSafeResume(self)
    self:CleanupRosterState()
    if self.inspectQueue and #self.inspectQueue > 0 then
        self:ProcessInspectQueue()
    else
        self:QueuePartyInspectDelayed()
    end
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerRoleChanged(self)
    self:AutoRegisterPartyByClass()
    self:ResetInspectStateFor()
    self:QueuePartyInspectDelayed()
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerUnitDied(self, guid, name)
    if self:HandleTrackedMemberDeath(guid, name, GetTime()) then
        self:EvaluateVisibility()
    end
end

local function IT_HandleInterruptTrackerChallengeModeStart(self)
    self:UpdateRunContext()
    self:ResetCounts()
    self:EvaluateVisibility()
end

local function IT_HandleInterruptTrackerContextRefresh(self)
    self:UpdateRunContext()
    self:EvaluateVisibility()
end

local IT_INTERRUPT_EVENT_HANDLERS = {
    CHAT_MSG_ADDON = IT_HandleInterruptTrackerAddonChat,
    CHAT_MSG_ADDON_LOGGED = IT_HandleInterruptTrackerAddonChat,
    PLAYER_ENTERING_WORLD = IT_HandleInterruptTrackerPlayerEnteringWorld,
    GROUP_ROSTER_UPDATE = IT_HandleInterruptTrackerRosterUpdate,
    PLAYER_SPECIALIZATION_CHANGED = IT_HandleInterruptTrackerSpecChanged,
    UNIT_PET = IT_HandleInterruptTrackerUnitPet,
    SPELLS_CHANGED = IT_HandleInterruptTrackerSpellsChanged,
    INSPECT_READY = IT_HandleInterruptTrackerInspectReady,
    PLAYER_REGEN_ENABLED = IT_HandleInterruptTrackerCombatSafeResume,
    ROLE_CHANGED_INFORM = IT_HandleInterruptTrackerRoleChanged,
    PLAYER_ROLES_ASSIGNED = IT_HandleInterruptTrackerRoleChanged,
    UNIT_DIED = IT_HandleInterruptTrackerUnitDied,
    CHALLENGE_MODE_START = IT_HandleInterruptTrackerChallengeModeStart,
    ZONE_CHANGED_NEW_AREA = IT_HandleInterruptTrackerContextRefresh,
    CHALLENGE_MODE_COMPLETED = IT_HandleInterruptTrackerContextRefresh,
    ENCOUNTER_START = IT_HandleInterruptTrackerContextRefresh,
    ENCOUNTER_END = IT_HandleInterruptTrackerContextRefresh,
}

function InterruptTracker:OnEvent(event, arg1, arg2, arg3, arg4)
    if PA_IsUiSurfaceGateEnabled() then
        return
    end
    local handler = IT_INTERRUPT_EVENT_HANDLERS[event]
    if handler then
        handler(self, arg1, arg2, arg3, arg4)
    end
end

Modules:Register(InterruptTracker)

end

local eventFrame = CreateFrame("Frame")
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix("PortalAuthority")
end
for _, event in ipairs({
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
    "PLAYER_REGEN_ENABLED",
    "UNIT_PET",
    "INSPECT_READY",
    "SPELLS_CHANGED",
    "ROLE_CHANGED_INFORM",
    "UNIT_DIED",
}) do
    eventFrame:RegisterEvent(event)
end

local function PA_PerfModulesEventScope(event)
    if event == "UNIT_AURA" then
        return "modules_event_unit_aura"
    end
    if event == "UNIT_POWER_UPDATE" then
        return "modules_event_unit_power_update"
    end
    if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        return "modules_event_chat_msg_addon"
    end
    return "modules_event_other"
end

local function PA_CpuDiagModulesTriggerKey(event)
    if event == "PLAYER_ENTERING_WORLD" then
        return "enter_world"
    end
    if event == "ZONE_CHANGED_NEW_AREA" then
        return "zone_new_area"
    end
    if event == "CHAT_MSG_ADDON" or event == "CHAT_MSG_ADDON_LOGGED" then
        return "addon_chat"
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        return "spec_change"
    end
    if event == "CHALLENGE_MODE_COMPLETED" then
        return "challenge_complete"
    end
    return nil
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    PA_CpuDiagRecordDispatcherEvent("modules", event)
    local triggerKey = PA_CpuDiagModulesTriggerKey(event)
    if triggerKey then
        PA_CpuDiagRecordTrigger(triggerKey)
    end
    local dispatchStart, dispatchState = PA_PerfBegin("modules_event_dispatch")
    local eventScope = PA_PerfModulesEventScope(event)
    PA_CpuDiagRecordModuleEvent(eventScope)
    local eventStart, eventState = PA_PerfBegin(eventScope, dispatchState)
    local function finish(...)
        PA_PerfEnd(eventScope, eventStart, eventState)
        PA_PerfEnd("modules_event_dispatch", dispatchStart, dispatchState)
        return ...
    end

    local eventArgs = { ... }
    if Modules.timersTestMode and (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "CHALLENGE_MODE_START") then
        if type(Modules.SetTimersTestMode) == "function" then
            Modules:SetTimersTestMode(false)
        else
            Modules.timersTestMode = false
        end
    end
    Modules:ForEach(function(module)
        if PA_IsSuppressedUiSurfaceModule(module) then
            return
        end
        if module.Initialize then
            local initStart, initState = PA_PerfBegin("modules_event_init", dispatchState)
            local okInit, errInit = pcall(module.Initialize, module)
            PA_PerfEnd("modules_event_init", initStart, initState)
            if not okInit then
                print("[PA] Module initialize error (" .. tostring(module.key or "?") .. "): " .. tostring(errInit))
                return
            end
        end
        if (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "GROUP_ROSTER_UPDATE") and module.PickFallbackSpellID then
            local okPick, errPick = pcall(module.PickFallbackSpellID, module)
            if not okPick then
                print("[PA] Module fallback error (" .. tostring(module.key or "?") .. "): " .. tostring(errPick))
            end
        end
        local isRapidAuraPower = (event == "UNIT_AURA" or event == "UNIT_POWER_UPDATE")
        if module.EvaluateVisibility and not isRapidAuraPower then
            local visStart, visState = PA_PerfBegin("modules_event_evaluate_visibility", dispatchState)
            local okVis, errVis = pcall(module.EvaluateVisibility, module, event)
            PA_PerfEnd("modules_event_evaluate_visibility", visStart, visState)
            if not okVis then
                print("[PA] Module visibility error (" .. tostring(module.key or "?") .. "): " .. tostring(errVis))
            end
        end
        if module.OnEvent then
            local onEventStart, onEventState = PA_PerfBegin("modules_event_on_event", dispatchState)
            local okEvent, errEvent = pcall(module.OnEvent, module, event, unpack(eventArgs))
            PA_PerfEnd("modules_event_on_event", onEventStart, onEventState)
            if not okEvent then
                print("[PA] Module event error (" .. tostring(module.key or "?") .. "): " .. tostring(errEvent))
            end
        end
    end)
    return finish()
end)
