---@diagnostic disable: undefined-field
--[[
    Module that provides a single-key fishing flow.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class EasyFishModule : AceModule, AceEvent-3.0
---@field secureButton Button|nil
---@field currentBinding string|nil
---@field pendingClear boolean
---@field pendingBindingUpdate boolean
---@field activeSoundCVars table<string, string>|nil
---@field activeInteractCVars table<string, string>|nil
local EasyFishModule = T:NewModule("EasyFish", "AceEvent-3.0")
EasyFishModule:SetEnabledState(false)

local CreateFrame = CreateFrame
local ClearOverrideBindings = ClearOverrideBindings
local GetCVar = GetCVar
local GetCurrentBindingSet = GetCurrentBindingSet
local GetNumLootItems = GetNumLootItems
local HasFullControl = HasFullControl
local InCombatLockdown = InCombatLockdown
local IsFalling = IsFalling
local IsMounted = IsMounted
local IsPlayerMoving = IsPlayerMoving
local IsStealthed = IsStealthed
local IsSubmerged = IsSubmerged
local IsSwimming = IsSwimming
local SaveBindings = SaveBindings
local SetBinding = SetBinding
local SetBindingClick = SetBindingClick
local SetOverrideBinding = SetOverrideBinding
local SetCVar = SetCVar
local UnitHasVehicleUI = UnitHasVehicleUI
local UnitChannelInfo = UnitChannelInfo

local SOUND_CVARS = {
    "Sound_MasterVolume",
    "Sound_SFXVolume",
    "Sound_EnableAmbience",
    "Sound_MusicVolume",
    "Sound_EnableAllSound",
    "Sound_EnablePetSounds",
    "Sound_EnableSoundWhenGameIsInBG",
    "Sound_EnableSFX",
}

local INTERACT_CVARS = {
    SoftTargetInteract = "3",
    SoftTargetInteractArc = "2",
    SoftTargetInteractRange = "60",
}

local FISHING_SPELL_IDS = {
    [131474] = true,
    [131490] = true,
    [131476] = true,
    [7620] = true,
    [7731] = true,
    [7732] = true,
    [18248] = true,
    [33095] = true,
    [51294] = true,
    [88868] = true,
    [110410] = true,
    [158743] = true,
    [377895] = true,
    [1224771] = true,
}

local function GetOptions()
    ---@type EasyFishConfigurationOptions
    return T:GetModule("Configuration").Options.EasyFish
end

local function NormalizeBinding(value)
    if type(value) ~= "string" then
        return ""
    end

    value = value:match("^%s*(.-)%s*$") or ""
    return value
end

local function GetFishingSpellName()
    if C_Spell and type(C_Spell.GetSpellName) == "function" then
        return C_Spell.GetSpellName(131474) or C_Spell.GetSpellName(7620)
    end

    return nil
end

function EasyFishModule:IsFishing()
    local spellID = select(8, UnitChannelInfo("player"))
    return FISHING_SPELL_IDS[spellID] == true
end

function EasyFishModule:CanCastFishing()
    if not GetFishingSpellName() then
        return false
    end

    if IsPlayerMoving() or IsMounted() or IsFalling() or IsStealthed() or IsSwimming() or IsSubmerged() then
        return false
    end

    if UnitHasVehicleUI("player") or not HasFullControl() or GetNumLootItems() ~= 0 then
        return false
    end

    return true
end

function EasyFishModule:EnsureSecureButton()
    if self.secureButton then
        self.secureButton:SetAttribute("type", "spell")
        self.secureButton:SetAttribute("spell", GetFishingSpellName())
        return self.secureButton
    end

    local button = CreateFrame("Button", "TwichUIEasyFishButton", UIParent, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyUp", "AnyDown")
    button:SetAttribute("type", "spell")
    button:SetAttribute("spell", GetFishingSpellName())
    self.secureButton = button
    return button
end

function EasyFishModule:RestoreInteractCVars()
    if not self.activeInteractCVars then
        return
    end

    for cvar, value in pairs(self.activeInteractCVars) do
        SetCVar(cvar, value)
    end

    self.activeInteractCVars = nil
end

function EasyFishModule:ApplyInteractCVars()
    if self.activeInteractCVars then
        return
    end

    self.activeInteractCVars = {}
    for cvar, value in pairs(INTERACT_CVARS) do
        self.activeInteractCVars[cvar] = GetCVar(cvar)
        SetCVar(cvar, value)
    end
end

function EasyFishModule:RestoreSoundCVars()
    if not self.activeSoundCVars then
        return
    end

    for _, cvar in ipairs(SOUND_CVARS) do
        local value = self.activeSoundCVars[cvar]
        if value ~= nil then
            SetCVar(cvar, value)
        end
    end

    self.activeSoundCVars = nil
end

function EasyFishModule:ApplySoundEnhancement()
    local options = GetOptions()
    if not options:GetMuteOtherSounds() then
        self:RestoreSoundCVars()
        return
    end

    if not self.activeSoundCVars then
        self.activeSoundCVars = {}
        for _, cvar in ipairs(SOUND_CVARS) do
            self.activeSoundCVars[cvar] = GetCVar(cvar)
        end
    end

    local scale = options:GetEnhancedSoundsScale()
    SetCVar("Sound_EnableAmbience", 0)
    SetCVar("Sound_MusicVolume", 0)
    SetCVar("Sound_EnablePetSounds", 0)
    SetCVar("Sound_EnableSFX", 1)
    SetCVar("Sound_EnableSoundWhenGameIsInBG", 1)
    SetCVar("Sound_EnableAllSound", 1)
    SetCVar("Sound_SFXVolume", scale)
    SetCVar("Sound_MasterVolume", scale)
end

function EasyFishModule:RefreshFishingState()
    if self:IsFishing() then
        self:ApplySoundEnhancement()
    else
        self:RestoreSoundCVars()
    end
end

function EasyFishModule:ClearPersistentBinding(save)
    if self.currentBinding and self.currentBinding ~= "" then
        SetBinding(self.currentBinding)
        self.currentBinding = nil
        if save ~= false then
            SaveBindings(GetCurrentBindingSet())
        end
    end
end

function EasyFishModule:SetKeybinding()
    if InCombatLockdown() then
        self.pendingBindingUpdate = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    self.pendingBindingUpdate = false
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")

    self:ClearPersistentBinding(false)

    if not self:IsEnabled() then
        SaveBindings(GetCurrentBindingSet())
        return
    end

    local keybinding = NormalizeBinding(GetOptions():GetEasyFishKeybinding())
    if keybinding == "" then
        SaveBindings(GetCurrentBindingSet())
        return
    end

    local button = self:EnsureSecureButton()
    local buttonName = button and button:GetName()
    if not buttonName then
        SaveBindings(GetCurrentBindingSet())
        return
    end

    SetBindingClick(keybinding, buttonName, "LeftButton")
    self.currentBinding = keybinding
    SaveBindings(GetCurrentBindingSet())

    if self:IsFishing() then
        self:ApplyFishingOverrides()
    end
end

function EasyFishModule:ApplyFishingOverrides()
    if InCombatLockdown() then
        self.pendingClear = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local keybinding = NormalizeBinding(GetOptions():GetEasyFishKeybinding())
    if keybinding == "" then
        return
    end

    local button = self:EnsureSecureButton()
    ClearOverrideBindings(button)
    SetOverrideBinding(button, true, keybinding, "INTERACTTARGET")
    self:ApplyInteractCVars()
    self:ApplySoundEnhancement()
end

function EasyFishModule:ClearFishingOverrides()
    self:RestoreSoundCVars()
    self:RestoreInteractCVars()

    local button = self.secureButton
    if not button then
        return
    end

    if InCombatLockdown() then
        self.pendingClear = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    self.pendingClear = false
    ClearOverrideBindings(button)
end

function EasyFishModule:PLAYER_REGEN_ENABLED()
    if not InCombatLockdown() then
        if self.pendingClear then
            self.pendingClear = false
            self:ClearFishingOverrides()
        end
        if self.pendingBindingUpdate then
            self:SetKeybinding()
        elseif not self.pendingClear then
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
    end
end

function EasyFishModule:UNIT_SPELLCAST_CHANNEL_START(_, unitToken, _, spellID)
    if unitToken == "player" and FISHING_SPELL_IDS[spellID] then
        self:ApplyFishingOverrides()
    end
end

function EasyFishModule:UNIT_SPELLCAST_CHANNEL_STOP(_, unitToken, _, spellID)
    if unitToken == "player" and FISHING_SPELL_IDS[spellID] then
        self:ClearFishingOverrides()
    end
end

function EasyFishModule:SPELLS_CHANGED()
    if self.secureButton then
        self.secureButton:SetAttribute("spell", GetFishingSpellName())
    end
end

function EasyFishModule:PLAYER_LOGOUT()
    self:RestoreSoundCVars()
    self:RestoreInteractCVars()
end

function EasyFishModule:OnEnable()
    self:EnsureSecureButton()
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:SetKeybinding()
end

function EasyFishModule:OnDisable()
    self:ClearFishingOverrides()
    self:ClearPersistentBinding()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    self:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    self:UnregisterEvent("SPELLS_CHANGED")
    self:UnregisterEvent("PLAYER_LOGOUT")
end
