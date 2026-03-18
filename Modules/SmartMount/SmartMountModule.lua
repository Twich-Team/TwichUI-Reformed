--[[
    Module that adds smart mount features.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local IsFlyAbleArea = IsFlyableArea
local SummonByID = C_MountJournal.SummonByID
local IsMounted = IsMounted
local Dismount = Dismount

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
end

--- This function is called by AceAddon when the module is enabled.
function SmartMountModule:OnEnable()
    self:RegisterChatCommand("smartMount", "MountUp")

    -- create the button frame for keybinding
    if not self.buttonFrame then
        self.buttonFrame = CreateFrame("BUTTON", "TwichUISmartMountButton")
        self.buttonFrame:SetScript("OnClick", function(self, button, down)
            SmartMountModule:MountUp()
        end)
        self:SetKeybinding()
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
    SetBindingClick(keybinding, self.buttonFrame:GetName(), keybinding)

    -- remember for next time
    self.currentBinding = keybinding

    SaveBindings(GetCurrentBindingSet())
end
