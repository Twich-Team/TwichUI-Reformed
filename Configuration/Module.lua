--[[
    Primary entrypoint into the configuration for the addon.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local AceConfig = LibStub("AceConfig-3.0", true)
local AceDBOptions = LibStub("AceDBOptions-3.0")
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs
local ReloadUI = ReloadUI
local C_Timer = _G.C_Timer
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local SetBindingClick = _G.SetBindingClick
local ACCOUNT_BINDINGS = 1
local CHARACTER_BINDINGS = 2

--- @class ConfigurationOptions
--- @field ChatEnhancement ChatEnhancementConfigurationOptions
--- @field ActionBars ActionBarsConfigurationOptions
--- @field Media MediaConfigurationOptions
--- @field SmartMount SmartMountConfigurationOptions
--- @field EasyFish EasyFishConfigurationOptions
--- @field Datatext DatatextConfigurationOptions
--- @field Chores ChoresConfigurationOptions
--- @field QuestAutomation QuestAutomationConfigurationOptions
--- @field QuestLogCleaner QuestLogCleanerConfigurationOptions
--- @field DungeonTracking DungeonTrackingConfigurationOptions
--- @field GossipHotkeys GossipHotkeysConfigurationOptions
--- @field BestInSlot BestInSlotConfigurationOptions
--- @field NotificationPanel NotificationPanelConfigurationOptions
--- @field UnitFrames UnitFramesConfigurationOptions
--- @field MythicPlusTools MythicPlusToolsConfigurationOptions
--- @field About AboutConfigurationOptions
--- @field SatchelWatch SatchelWatchConfigurationOptions
--- @field Gathering GatheringConfigurationOptions
local Options = {}


---@class ConfigurationModule : AceModule
---@field Widgets ConfigurationWidgets
---@field optionsTable table
---@field registeredConfigurationFunctions table<string, fun():table>
---@field DeveloperConfiguration DeveloperConfiguration
---@field Options ConfigurationOptions
---@field StandaloneUI table|nil
local ConfigurationModule = T:NewModule("Configuration")
ConfigurationModule:SetEnabledState(true)
ConfigurationModule.registeredConfigurationFunctions = {}
ConfigurationModule.Options = Options
ConfigurationModule.standaloneOptionsAppName = "TwichUIReduxStandalone"

local function GetAceConfigRegistry()
    return (T.Libs and T.Libs.AceConfigRegistry)
        or _G.LibStub("AceConfigRegistry-3.0", true)
end

--- Called when the module is initialized. Creates the configuration.
function ConfigurationModule:OnInitialize()
    self.optionsTable = {
        type = "group",
        name = T.Tools.Text.Color(T.Tools.Colors.WHITE,
            "Twich" .. T.Tools.Text.Color(T.Tools.Colors.PRIMARY, "UI") .. ": Reloaded Configuration"),
        childGroups = "tab",
        order = 99,
        args = {
            profile = AceDBOptions:GetOptionsTable(T.db),
        },
    }
    self.optionsTable.args.profile.order = -1

    self:RebuildOptionsTableSections()

    self:RegisterStandaloneOptionsTable()
    self:SetChoresTrackerConfigKeybinding()
end

function ConfigurationModule:GetStandaloneOptionsAppName()
    return self.standaloneOptionsAppName or "TwichUIReduxStandalone"
end

function ConfigurationModule:RegisterStandaloneOptionsTable()
    if not AceConfig or type(AceConfig.RegisterOptionsTable) ~= "function" or not self.optionsTable then
        return
    end

    AceConfig:RegisterOptionsTable(self:GetStandaloneOptionsAppName(), self.optionsTable)
end

function ConfigurationModule:RegisterConfigurationFunction(name, func)
    self.registeredConfigurationFunctions[name] = func
end

function ConfigurationModule:RebuildOptionsTableSections()
    if not self.optionsTable then
        return
    end

    self.optionsTable.args = self.optionsTable.args or {}
    if not self.optionsTable.args.profile then
        self.optionsTable.args.profile = AceDBOptions:GetOptionsTable(T.db)
        self.optionsTable.args.profile.order = -1
    end

    for name in pairs(self.optionsTable.args) do
        if name ~= "profile" and not self.registeredConfigurationFunctions[name] then
            self.optionsTable.args[name] = nil
        end
    end

    for name, func in pairs(self.registeredConfigurationFunctions) do
        local section = func()
        self.optionsTable.args[name] = section
    end
end

function ConfigurationModule:GetProfileDB()
    if not T.db.profile.configuration then
        T.db.profile.configuration = {}
    end
    return T.db.profile.configuration
end

function ConfigurationModule:PromptToReloadUI()
    if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
        if not StaticPopupDialogs["TWICHUI_RELOAD_UI"] then
            StaticPopupDialogs["TWICHUI_RELOAD_UI"] = {
                text = "TwichUI: Some changes require a UI reload to fully apply. Reload now?",
                button1 = OKAY,
                button2 = CANCEL,
                OnAccept = function() ReloadUI() end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
                preferredIndex = 3,
            }
        end
        StaticPopup_Show("TWICHUI_RELOAD_UI")
    end
end

function ConfigurationModule:ShowGenericConfirmationDialog(content, onAcceptFunc)
    if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
        StaticPopupDialogs["TWICH_CONFIRM_DIALOG"] = {
            text = content,
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function() if onAcceptFunc then onAcceptFunc() end end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
            preferredIndex = 3,
        }
        StaticPopup_Show("TWICH_CONFIRM_DIALOG")
    end
end

function ConfigurationModule:Refresh()
    self:RebuildOptionsTableSections()

    local ACR = GetAceConfigRegistry()
    if ACR and ACR.NotifyChange then
        pcall(ACR.NotifyChange, ACR, self:GetStandaloneOptionsAppName())
    end

    if self.StandaloneUI and type(self.StandaloneUI.GetFrame) == "function" then
        local frame = self.StandaloneUI:GetFrame()
        if frame and frame.IsShown and frame:IsShown() then
            if type(self.StandaloneUI.RefreshSidebar) == "function" then
                self.StandaloneUI:RefreshSidebar()
            end

            if self.StandaloneUI.currentPageId == "dashboard" and type(self.StandaloneUI.RefreshDashboard) == "function" then
                self.StandaloneUI:RefreshDashboard()
            elseif type(self.StandaloneUI.RequestRenderCurrentPage) == "function" then
                self.StandaloneUI:RequestRenderCurrentPage()
            end
        end
    end
end

function ConfigurationModule:OpenChoresTrackerOptions()
    self:ToggleOptionsUI("Quality of Life", "choresTab", "trackerFrame")
end

function ConfigurationModule:ToggleOptionsUI(...)
    if self.StandaloneUI and type(self.StandaloneUI.IsAvailable) == "function" and self.StandaloneUI:IsAvailable()
        and type(self.StandaloneUI.Toggle) == "function" then
        self.StandaloneUI:Toggle(...)
    end
end

function ConfigurationModule:OpenOptionsUI(...)
    if self.StandaloneUI and type(self.StandaloneUI.IsAvailable) == "function" and self.StandaloneUI:IsAvailable()
        and type(self.StandaloneUI.Show) == "function" then
        self.StandaloneUI:Show(...)
    end
end

function ConfigurationModule:EnsureChoresTrackerConfigButton()
    if self.choresTrackerConfigButton then
        return self.choresTrackerConfigButton
    end

    local button = CreateFrame("BUTTON", "TwichUIChoresTrackerConfigButton", UIParent)
    button:SetScript("OnClick", function()
        ---@type DataTextModule
        local datatextModule = T:GetModule("Datatexts")
        ---@type ChoresDataText|nil
        ---@diagnostic disable-next-line: undefined-field
        local choresDataText = datatextModule and datatextModule.GetModule and
            datatextModule:GetModule("ChoresDataText", true)
        if choresDataText and choresDataText.ToggleTrackerFrame then
            choresDataText:ToggleTrackerFrame()
        end
    end)
    self.choresTrackerConfigButton = button
    return button
end

local function GetActiveBindingSet()
    local bindingSet = type(GetCurrentBindingSet) == "function" and GetCurrentBindingSet() or nil
    if bindingSet == ACCOUNT_BINDINGS or bindingSet == CHARACTER_BINDINGS then
        return bindingSet
    end

    return nil
end

function ConfigurationModule:ApplyPendingBindingUpdates()
    if not self.pendingChoresTrackerBindingUpdate then
        return
    end

    if not GetActiveBindingSet() then
        if self.bindingRetryQueued or not (C_Timer and C_Timer.After) then
            return
        end

        self.bindingRetryQueued = true
        C_Timer.After(0.5, function()
            self.bindingRetryQueued = nil
            self:ApplyPendingBindingUpdates()
        end)
        return
    end

    self.pendingChoresTrackerBindingUpdate = nil
    self:SetChoresTrackerConfigKeybinding()
end

function ConfigurationModule:SetChoresTrackerConfigKeybinding()
    local options = self.Options and self.Options.Chores
    local keybinding = options and options.GetTrackerFrameConfigKeybinding and options:GetTrackerFrameConfigKeybinding() or
        ""
    local button = self:EnsureChoresTrackerConfigButton()
    local bindingSet = GetActiveBindingSet()

    if not bindingSet then
        self.pendingChoresTrackerBindingUpdate = true
        self:ApplyPendingBindingUpdates()
        return
    end

    if self.currentChoresTrackerConfigBinding and self.currentChoresTrackerConfigBinding ~= "" then
        SetBinding(self.currentChoresTrackerConfigBinding)
        self.currentChoresTrackerConfigBinding = nil
    end

    if not keybinding or keybinding == "" then
        SaveBindings(bindingSet)
        return
    end

    SetBindingClick(keybinding, button:GetName(), "LeftButton")
    self.currentChoresTrackerConfigBinding = keybinding
    SaveBindings(bindingSet)
end

--- add the toggle options function to the globals so it can be set as the addon compartment function
do
    _G.TwichUIRx_AddonCompartmentFunc = function()
        ConfigurationModule:ToggleOptionsUI()
    end
end
