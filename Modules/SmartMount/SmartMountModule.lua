--[[
    Module that adds smart mount features.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local C_Spell = _G.C_Spell
local IsFlyAbleArea = IsFlyableArea
local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID
local SummonByID = C_MountJournal.SummonByID
local IsMounted = IsMounted
local Dismount = Dismount
local CastSpellByID = rawget(_G, "CastSpellByID")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local GetSpellInfo = rawget(_G, "GetSpellInfo")
local IsUsableSpell = rawget(_G, "IsUsableSpell")
local UnitRace = UnitRace
local LegacyIsPlayerSpell = rawget(_G, "IsPlayerSpell")
local LegacyIsSpellKnown = rawget(_G, "IsSpellKnown")
local date = _G.date
local format = string.format
local GetTime = _G.GetTime

local PLAYER_RACE = select(2, UnitRace("player"))
local SOAR_SPELL_ID = 369536
local DEBUG_SOURCE_KEY = "smartmount"
local GROUND_MOUNT_TYPES = {
    [230] = true,
}
local FLYING_MOUNT_TYPES = {
    [248] = true,
    [402] = true,
    [424] = true,
}

---@class MountUtilityModule
local MountUtilityModule = T:GetModule("MountUtility")
local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole

---@class SmartMountModule : AceModule, AceConsole-3.0
---@field buttonFrame Frame the frame that is keybound to toggle the mount behavior
---@field currentBinding string the current keybinding
local SmartMountModule = T:NewModule("SmartMount", "AceConsole-3.0")

---@return SmartMountConfigurationOptions options
local function GetConfigurationOptions()
    return T:GetModule("Configuration").Options.SmartMount
end

local function GetMountSpellID(mountID)
    local id = tonumber(mountID) or 0
    if id <= 0 then
        return nil
    end

    local _, spellID = GetMountInfoByID(id)
    if spellID and spellID > 0 then
        return spellID
    end

    return nil
end

local function GetMountSecureSpellValue(mountID)
    local id = tonumber(mountID) or 0
    if id <= 0 then
        return nil
    end

    local mountName, spellID = GetMountInfoByID(id)
    if spellID and type(GetSpellInfo) == "function" then
        local spellName = GetSpellInfo(spellID)
        if type(spellName) == "string" and spellName ~= "" then
            return spellName
        end
    end

    if type(mountName) == "string" and mountName ~= "" then
        return mountName
    end

    return nil
end

local function GetSoarSecureSpellValue()
    if type(GetSpellInfo) == "function" then
        local spellName = GetSpellInfo(SOAR_SPELL_ID)
        if type(spellName) == "string" and spellName ~= "" then
            return spellName
        end
    end

    return SOAR_SPELL_ID
end

local function BuildSecureCastMacro(spellValue)
    if spellValue == nil then
        return nil
    end

    return "/cast " .. tostring(spellValue)
end

local function SummonRandomFavoriteMount()
    if type(SummonByID) == "function" then
        SummonByID(0)
    end
end

local function IsSpellKnownSafe(spellID)
    if not spellID then
        return false
    end

    if C_Spell and type(C_Spell.IsSpellKnown) == "function" and C_Spell.IsSpellKnown(spellID) then
        return true
    end

    if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" and C_SpellBook.IsSpellKnown(spellID) then
        return true
    end

    if type(LegacyIsPlayerSpell) == "function" and LegacyIsPlayerSpell(spellID) then
        return true
    end

    if type(LegacyIsSpellKnown) == "function" and LegacyIsSpellKnown(spellID) then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        return C_SpellBook.IsSpellInSpellBook(spellID)
    end

    return false
end

local function CanUseFlyingMounts()
    local inInstance = IsInInstance and IsInInstance() or false
    if inInstance then
        return false
    end

    return IsFlyAbleArea() == true
end

local function CanUseSoar(options)
    if PLAYER_RACE ~= "Dracthyr" or not options:GetUseDracthyrSoar() then
        return false
    end

    -- Soar can never be used inside instanced content (dungeons, raids, arenas).
    -- IsFlyableArea() can incorrectly return true for some Midnight instance lobbies
    -- and does not know about per-instance flying restrictions. IsInInstance() is the
    -- definitive check: if we are in any instance, Soar will fail at cast time.
    if not CanUseFlyingMounts() then
        return false
    end

    -- Zone must actually support flying (outdoor flyable check).
    if not IsSpellKnownSafe(SOAR_SPELL_ID) then
        return false
    end

    local isUsable = nil
    if C_Spell and type(C_Spell.IsSpellUsable) == "function" then
        isUsable = C_Spell.IsSpellUsable(SOAR_SPELL_ID)
    elseif type(IsUsableSpell) == "function" then
        isUsable = IsUsableSpell(SOAR_SPELL_ID)
    end

    if isUsable == false then
        return false
    end

    local onCooldown = false
    local ok = pcall(function()
        if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
            local cooldownInfo = C_Spell.GetSpellCooldown(SOAR_SPELL_ID)
            if cooldownInfo and cooldownInfo.startTime and cooldownInfo.duration then
                local startTime = cooldownInfo.startTime
                local duration = cooldownInfo.duration
                local isEnabled = cooldownInfo.isEnabled
                if isEnabled ~= false and startTime > 0 and duration and duration > 1.5 then
                    onCooldown = (startTime + duration) > GetTime()
                end
            end
            return
        end

        if type(GetSpellCooldown) == "function" then
            local startTime, duration, isEnabled = GetSpellCooldown(SOAR_SPELL_ID)
            if isEnabled ~= false and startTime and startTime > 0 and duration and duration > 1.5 then
                onCooldown = (startTime + duration) > GetTime()
            end
        end
    end)

    if not ok or onCooldown then
        return false
    end

    return isUsable == true
end

local function CastSoar()
    if C_Spell and type(C_Spell.CastSpellByID) == "function" then
        C_Spell.CastSpellByID(SOAR_SPELL_ID)
        return
    end

    if type(CastSpellByID) == "function" then
        CastSpellByID(SOAR_SPELL_ID)
    end
end

local function GetMountType(mountID)
    if not mountID or type(GetMountInfoExtraByID) ~= "function" then
        return nil
    end

    local _, _, _, _, mountType = GetMountInfoExtraByID(mountID)
    return tonumber(mountType)
end

local function GetMountTypeLabel(mountID)
    local mountType = GetMountType(mountID)
    if GROUND_MOUNT_TYPES[mountType] then
        return "ground"
    end

    if FLYING_MOUNT_TYPES[mountType] then
        return "flying"
    end

    if mountType then
        return "type-" .. tostring(mountType)
    end

    return "unknown"
end

local function IsPreferredMountType(mountID, preferredMode)
    if preferredMode == nil or preferredMode == "any" then
        return true
    end

    local mountType = GetMountType(mountID)
    if preferredMode == "ground" then
        return GROUND_MOUNT_TYPES[mountType] == true
    end

    if preferredMode == "flying" then
        return FLYING_MOUNT_TYPES[mountType] == true
    end

    return false
end

local function FindFirstUsableMountID(mounts, preferredMode)
    if type(mounts) ~= "table" then
        return nil
    end

    for _, entry in ipairs(mounts) do
        local mountID = entry and tonumber(entry.mountID) or 0
        if mountID > 0 and MountUtilityModule:IsMountUsable(mountID) and IsPreferredMountType(mountID, preferredMode) then
            return mountID
        end
    end

    return nil
end

local function GetAdaptiveFallbackMountID(preferFlying)
    local preferredModes = preferFlying and { "flying", "ground", "any" } or { "ground", "any" }
    local mountLists = { "FAVORITE", "ALL" }

    for _, preferredMode in ipairs(preferredModes) do
        for _, mountList in ipairs(mountLists) do
            local mountID = FindFirstUsableMountID(MountUtilityModule:GetPlayerMounts(mountList), preferredMode)
            if mountID then
                return mountID, preferredMode, mountList
            end
        end
    end

    return nil, nil, nil
end

local function GetMountDebugName(mountID)
    local label = MountUtilityModule:GetMountLabelByID(mountID)
    return tostring(label or tostring(mountID or 0))
end

local function ResolveMountDecision(options, allowRandomFavorite)
    local decision = {
        timestamp = GetTime(),
        isMounted = IsMounted(),
        swimming = IsSwimming("player"),
        inInstance = IsInInstance and IsInInstance() or false,
        flyable = false,
        allowRandomFavorite = allowRandomFavorite == true,
        flyingMountID = options:GetSelectedFlyingMount() or 0,
        groundMountID = options:GetSelectedGroundMount() or 0,
        aquaticMountID = options:GetSelectedAquaticMount() or 0,
        useAquatic = options:GetUseAquaticMounts() == true,
        useSoar = options:GetUseDracthyrSoar() == true,
        action = "none",
        source = "none",
    }

    if decision.isMounted then
        if options:GetDismountIfMounted() then
            decision.action = "dismount"
            decision.source = "mounted-dismount"
        else
            decision.source = "mounted-ignore"
        end

        return decision
    end

    if decision.swimming and decision.useAquatic and MountUtilityModule:IsMountUsable(decision.aquaticMountID) then
        decision.action = "mount"
        decision.source = "aquatic-selected"
        decision.mountID = decision.aquaticMountID
        decision.spellID = GetMountSpellID(decision.mountID)
        return decision
    end

    decision.flyable = CanUseFlyingMounts()
    decision.canUseSoar = decision.flyable and CanUseSoar(options)

    if decision.canUseSoar then
        decision.action = "soar"
        decision.source = "soar"
        decision.spellID = SOAR_SPELL_ID
        decision.secureSpellValue = GetSoarSecureSpellValue()
        return decision
    end

    local primaryMountID = decision.flyable and decision.flyingMountID or decision.groundMountID
    local fallbackMountID = decision.flyable and decision.groundMountID or decision.flyingMountID
    decision.primaryMountID = primaryMountID
    decision.fallbackMountID = fallbackMountID

    if MountUtilityModule:IsMountUsable(primaryMountID) then
        decision.action = "mount"
        decision.source = "selected-primary"
        decision.mountID = primaryMountID
        decision.spellID = GetMountSpellID(primaryMountID)
        decision.secureSpellValue = GetMountSecureSpellValue(primaryMountID)
        return decision
    end

    if MountUtilityModule:IsMountUsable(fallbackMountID) then
        decision.action = "mount"
        decision.source = "selected-fallback"
        decision.mountID = fallbackMountID
        decision.spellID = GetMountSpellID(fallbackMountID)
        decision.secureSpellValue = GetMountSecureSpellValue(fallbackMountID)
        return decision
    end

    local adaptiveFallbackMountID, adaptiveMode, adaptiveList = GetAdaptiveFallbackMountID(decision.flyable)
    if adaptiveFallbackMountID then
        decision.action = "mount"
        decision.source = "adaptive-" .. tostring(adaptiveMode or "any")
        decision.mountID = adaptiveFallbackMountID
        decision.spellID = GetMountSpellID(adaptiveFallbackMountID)
        decision.secureSpellValue = GetMountSecureSpellValue(adaptiveFallbackMountID)
        decision.adaptiveMode = adaptiveMode
        decision.adaptiveList = adaptiveList
        return decision
    end

    if allowRandomFavorite then
        decision.action = "random-favorite"
        decision.source = "random-favorite"
        return decision
    end

    decision.source = "no-secure-fallback"
    return decision
end

function SmartMountModule:IsDebugEnabled()
    local options = GetConfigurationOptions()
    return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
end

function SmartMountModule:LogDebugf(shouldShow, messageFormat, ...)
    if not DebugConsole or type(DebugConsole.Logf) ~= "function" or not self:IsDebugEnabled() then
        return false
    end

    return DebugConsole:Logf(DEBUG_SOURCE_KEY, shouldShow, messageFormat, ...)
end

function SmartMountModule:BuildDebugReport()
    local options = GetConfigurationOptions()
    local decision = self.lastDecision or {}
    local lines = {
        "TwichUI Smart Mount Debug",
        format("Timestamp: %s",
            date and type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or format("%.3f", GetTime())),
        "",
        "Runtime",
        format("enabled=%s debugCapture=%s race=%s keybinding=%s",
            tostring(self:IsEnabled() == true),
            tostring(self:IsDebugEnabled()),
            tostring(PLAYER_RACE),
            tostring(options:GetSmartMountKeybinding() or "")),
        format("selectedGround=%s type=%s usable=%s",
            GetMountDebugName(options:GetSelectedGroundMount() or 0),
            GetMountTypeLabel(options:GetSelectedGroundMount() or 0),
            tostring(MountUtilityModule:IsMountUsable(options:GetSelectedGroundMount() or 0))),
        format("selectedFlying=%s type=%s usable=%s",
            GetMountDebugName(options:GetSelectedFlyingMount() or 0),
            GetMountTypeLabel(options:GetSelectedFlyingMount() or 0),
            tostring(MountUtilityModule:IsMountUsable(options:GetSelectedFlyingMount() or 0))),
        format("selectedAquatic=%s type=%s usable=%s",
            GetMountDebugName(options:GetSelectedAquaticMount() or 0),
            GetMountTypeLabel(options:GetSelectedAquaticMount() or 0),
            tostring(MountUtilityModule:IsMountUsable(options:GetSelectedAquaticMount() or 0))),
        "",
        "Last Decision",
        format("source=%s action=%s mountType=%s adaptive=%s/%s",
            tostring(decision.source or "none"),
            tostring(decision.action or "none"),
            GetMountTypeLabel(decision.mountID),
            tostring(decision.adaptiveMode or "n/a"),
            tostring(decision.adaptiveList or "n/a")),
        format("isMounted=%s swimming=%s inInstance=%s flyable=%s canUseSoar=%s",
            tostring(decision.isMounted),
            tostring(decision.swimming),
            tostring(decision.inInstance),
            tostring(decision.flyable),
            tostring(decision.canUseSoar)),
        format("mount=%s spellID=%s primary=%s fallback=%s",
            GetMountDebugName(decision.mountID or 0),
            tostring(decision.spellID or "nil"),
            GetMountDebugName(decision.primaryMountID or 0),
            GetMountDebugName(decision.fallbackMountID or 0)),
        format("secureSpell=%s",
            tostring(decision.secureSpellValue or "nil")),
    }

    return table.concat(lines, "\n")
end

function SmartMountModule:CaptureDebugSnapshot(shouldShow)
    if DebugConsole and type(DebugConsole.Log) == "function" then
        DebugConsole:Log(DEBUG_SOURCE_KEY, self:BuildDebugReport(), shouldShow == true)
        return
    end

    T:Print("[TwichUI] Smart Mount debug console is unavailable")
end

function SmartMountModule:GetDebugStatusLine()
    local decision = self.lastDecision or {}
    return format("SmartMount debug=%s last=%s action=%s flyable=%s inInstance=%s",
        tostring(self:IsDebugEnabled()),
        tostring(decision.source or "none"),
        tostring(decision.action or "none"),
        tostring(decision.flyable),
        tostring(decision.inInstance))
end

function SmartMountModule:RecordDecision(decision, shouldShow)
    self.lastDecision = decision

    self:LogDebugf(shouldShow == true,
        "decision source=%s action=%s mountID=%s spellID=%s secureSpell=%s flyable=%s inInstance=%s swimming=%s adaptive=%s/%s",
        tostring(decision.source or "none"),
        tostring(decision.action or "none"),
        tostring(decision.mountID or 0),
        tostring(decision.spellID or "nil"),
        tostring(decision.secureSpellValue or "nil"),
        tostring(decision.flyable),
        tostring(decision.inInstance),
        tostring(decision.swimming),
        tostring(decision.adaptiveMode or "n/a"),
        tostring(decision.adaptiveList or "n/a"))
end

function SmartMountModule:GetSecureAction()
    local options = GetConfigurationOptions()
    local decision = ResolveMountDecision(options, false)
    self:RecordDecision(decision, false)

    if decision.action == "dismount" then
        return "macro", "/dismount"
    end

    if decision.action == "soar" and decision.secureSpellValue then
        return "spell", decision.secureSpellValue
    end

    if decision.action == "mount" and decision.secureSpellValue then
        return "macro", BuildSecureCastMacro(decision.secureSpellValue)
    end

    return nil, nil
end

function SmartMountModule:RefreshSecureAction()
    if not self.buttonFrame or InCombatLockdown() then
        return
    end

    local actionType, actionValue = self:GetSecureAction()
    self.buttonFrame:SetAttribute("type", nil)
    self.buttonFrame:SetAttribute("spell", nil)
    self.buttonFrame:SetAttribute("macrotext", nil)

    if actionType == "spell" and actionValue then
        self.buttonFrame:SetAttribute("type", "spell")
        self.buttonFrame:SetAttribute("spell", actionValue)
    elseif actionType == "macro" and actionValue then
        self.buttonFrame:SetAttribute("type", "macro")
        self.buttonFrame:SetAttribute("macrotext", actionValue)
    end
end

--- Performs the mounting action based on flyable or noflyable and configured favorite mounts.
function SmartMountModule:MountUp()
    local Options = GetConfigurationOptions()
    local decision = ResolveMountDecision(Options, true)
    self:RecordDecision(decision, false)

    if decision.action == "dismount" then
        Dismount()
        return
    end

    if decision.action == "soar" then
        CastSoar()
        return
    end

    if decision.action == "mount" and decision.mountID then
        SummonByID(decision.mountID)
        return
    end

    if decision.action == "random-favorite" then
        SummonRandomFavoriteMount()
    end
end

--- This function is called by AceAddon when the module is enabled.
function SmartMountModule:OnEnable()
    self:RegisterChatCommand("smartMount", "MountUp")

    if DebugConsole and DebugConsole.RegisterSource then
        DebugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
            title = "Smart Mount",
            order = 38,
            aliases = { "smartmount", "mount" },
            maxLines = 120,
            isEnabled = function()
                return self:IsDebugEnabled()
            end,
            buildReport = function()
                return self:BuildDebugReport()
            end,
        })
    end

    -- create the button frame for keybinding
    if not self.buttonFrame then
        self.buttonFrame = CreateFrame("Button", "TwichUISmartMountButton", UIParent, "SecureActionButtonTemplate")
        self.buttonFrame:RegisterForClicks("AnyUp", "AnyDown")
        self.buttonFrame:SetScript("PreClick", function()
            SmartMountModule:RefreshSecureAction()
        end)
        self:SetKeybinding()
    else
        self:RefreshSecureAction()
    end
end

--- This function is called by AceAddon when the module is disabled.
function SmartMountModule:OnDisable()
end

--- This function is called by AceAddon when the module is initialized.
function SmartMountModule:OnInitialize()
end

--- Updates the keybinding for the smart mount logic to the current setting
function SmartMountModule:SetKeybinding()
    local Options    = GetConfigurationOptions()
    local keybinding = Options:GetSmartMountKeybinding()

    -- if there was a previous keybinding, clear it in the WoW binding table
    if self.currentBinding and self.currentBinding ~= "" then
        T:Print("Clearing previous keybinding for Smart Mount: " .. self.currentBinding)
        SetBinding(self.currentBinding) -- <‑‑ this actually unbinds the key
        self.currentBinding = nil
    end

    -- if no new key, just save the cleared bindings
    if not keybinding or keybinding == "" then
        SaveBindings(GetCurrentBindingSet())
        return
    end

    -- set / update the binding
    SetBindingClick(keybinding, self.buttonFrame:GetName(), "LeftButton")

    -- remember for next time
    self.currentBinding = keybinding

    SaveBindings(GetCurrentBindingSet())
end
