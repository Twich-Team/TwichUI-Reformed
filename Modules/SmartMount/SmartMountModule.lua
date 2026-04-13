--[[
    Module that adds smart mount features.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local C_Spell = _G.C_Spell
local IsFlyAbleArea = IsFlyableArea
local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local SummonByID = C_MountJournal.SummonByID
local IsMounted = IsMounted
local Dismount = Dismount
local CastSpellByID = rawget(_G, "CastSpellByID")
local GetSpellCooldown = rawget(_G, "GetSpellCooldown")
local IsUsableSpell = rawget(_G, "IsUsableSpell")
local UnitRace = UnitRace
local LegacyIsPlayerSpell = rawget(_G, "IsPlayerSpell")
local LegacyIsSpellKnown = rawget(_G, "IsSpellKnown")

local PLAYER_RACE = select(2, UnitRace("player"))
local SOAR_SPELL_ID = 369536

---@class MountUtilityModule
local MountUtilityModule = T:GetModule("MountUtility")

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

local function CanUseSoar(options)
    if PLAYER_RACE ~= "Dracthyr" or not options:GetUseDracthyrSoar() then
        return false
    end

    -- Soar can never be used inside instanced content (dungeons, raids, arenas).
    -- IsFlyableArea() can incorrectly return true for some Midnight instance lobbies
    -- and does not know about per-instance flying restrictions. IsInInstance() is the
    -- definitive check: if we are in any instance, Soar will fail at cast time.
    local inInstance = IsInInstance and IsInInstance() or false
    if inInstance then return false end

    -- Zone must actually support flying (outdoor flyable check).
    if not IsFlyAbleArea() then return false end

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

function SmartMountModule:GetSecureAction()
    local options = GetConfigurationOptions()

    if IsMounted() then
        if options:GetDismountIfMounted() then
            return "macro", "/dismount"
        end

        return nil, nil
    end

    local flyingMountID = options:GetSelectedFlyingMount() or 0
    local groundMountID = options:GetSelectedGroundMount() or 0
    local aquaticMountID = options:GetSelectedAquaticMount() or 0

    if IsSwimming("player") and options:GetUseAquaticMounts() then
        if MountUtilityModule:IsMountUsable(aquaticMountID) then
            local aquaticSpellID = GetMountSpellID(aquaticMountID)
            if aquaticSpellID then
                return "spell", aquaticSpellID
            end
        end
    end

    local flyable = IsFlyAbleArea() or false

    if flyable and CanUseSoar(options) then
        return "spell", SOAR_SPELL_ID
    end

    local primaryMountID = flyable and flyingMountID or groundMountID
    local fallbackMountID = flyable and groundMountID or flyingMountID

    if MountUtilityModule:IsMountUsable(primaryMountID) then
        local primarySpellID = GetMountSpellID(primaryMountID)
        if primarySpellID then
            return "spell", primarySpellID
        end
    end

    if MountUtilityModule:IsMountUsable(fallbackMountID) then
        local fallbackSpellID = GetMountSpellID(fallbackMountID)
        if fallbackSpellID then
            return "spell", fallbackSpellID
        end
    end

    -- Last resort: use the random favorite mount macro when no specific mount is
    -- configured or usable (e.g. Dracthyr with only Soar set but Soar is blocked).
    return "macro", "/run C_MountJournal.SummonByID(0)"
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

    -- if the player is mounted, dismount if enabled. otherwise, ignore the command.
    if IsMounted() then
        if Options:GetDismountIfMounted() then
            Dismount()
            return
        end
        return
    end

    local flyingMountID = Options:GetSelectedFlyingMount() or 0
    local groundMountID = Options:GetSelectedGroundMount() or 0
    local aquaticMountID = Options:GetSelectedAquaticMount() or 0

    -- if player is swimming
    if IsSwimming("player") and Options:GetUseAquaticMounts() then
        if MountUtilityModule:IsMountUsable(aquaticMountID) then
            SummonByID(aquaticMountID)
            return
        end
    end

    local flyable = IsFlyAbleArea() or false

    if flyable and CanUseSoar(Options) then
        CastSoar()
        return
    end

    local primaryMountID = flyable and flyingMountID or groundMountID
    local fallbackMountID = flyable and groundMountID or flyingMountID

    if MountUtilityModule:IsMountUsable(primaryMountID) then
        SummonByID(primaryMountID)
        return
    end

    if MountUtilityModule:IsMountUsable(fallbackMountID) then
        SummonByID(fallbackMountID)
        return
    end

    -- Last resort: summon a random favorite mount when no specific mount is configured
    -- or neither configured mount is currently usable.
    SummonRandomFavoriteMount()
end

--- This function is called by AceAddon when the module is enabled.
function SmartMountModule:OnEnable()
    self:RegisterChatCommand("smartMount", "MountUp")

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
