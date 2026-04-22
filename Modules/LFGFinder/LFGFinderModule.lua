--[[
    LFG Finder Module
    Native reimplementation of OakLFGSorter with TwichUI styling and theme integration.

    Features:
    - Dual-mode operation: Browser (searching) & Applicant (reviewing applications)
    - Advanced filtering: By dungeon, difficulty, key range, rating, utilities, party composition
    - Smart sorting: 6 sortable columns with ascending/descending toggle
    - Live data tracking: Application status, RaiderIO scores, party composition
    - Quick signup bar: Apply to groups with optional persistent note
    - Region filtering: Cross-realm support
    - Sticky applied panel: Groups you've applied to stay visible
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class LFGFinderModule : AceModule, AceEvent-3.0
local LFG = T:NewModule("LFGFinder", "AceEvent-3.0")

local C_LFGList = _G.C_LFGList
local CreateFrame = _G.CreateFrame
local C_AddOns = _G.C_AddOns

-- Module state
LFG.searchResults = {}
LFG.displayMode = "browser" -- "browser" or "applicant"
LFG.selectedActivity = nil
LFG.selectedDifficulty = "ANY"
LFG.selectedKeyMin = 2
LFG.selectedKeyMax = 99
LFG.isOpen = false

-- ──────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:OnInitialize()
    local ConfigurationModule = T:GetModule("Configuration")
    self.Options = ConfigurationModule and ConfigurationModule.Options.LFGFinder
end

function LFG:OnEnable()
    self:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED", "OnSearchResultsUpdated")
    self:RegisterEvent("LFG_LIST_APPLICANT_UPDATED", "OnApplicantUpdated")
    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", "OnApplicationStatusUpdated")
    self:RegisterEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")

    -- If Blizzard_LookingForGroupUI is already loaded, hook immediately
    if _G.LFGListFrame and _G.LFGListFrame.SearchPanel then
        self:HookLFGPanel()
    end
end

function LFG:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    if self.CancelSearchBuild then
        self:CancelSearchBuild()
    end
    if self.mainFrame then
        self.mainFrame:Hide()
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- LFG Panel Hook
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:OnAddonLoaded(_, addonName)
    if addonName == "Blizzard_LookingForGroupUI" then
        self:HookLFGPanel()
    end
end

function LFG:HookLFGPanel()
    local searchPanel = _G.LFGListFrame and _G.LFGListFrame.SearchPanel
    if not searchPanel or self._lfgPanelHooked then return end
    self._lfgPanelHooked = true

    -- Build the frame now so it's ready when the panel first opens
    self:EnsureMainFrame()

    -- Show/hide our frame whenever the Blizzard search panel shows/hides
    searchPanel:HookScript("OnShow", function()
        local opts = self:GetOptions()
        local autoOpen = type(opts.GetAutoOpen) == "function" and opts:GetAutoOpen()
        if autoOpen ~= false then
            self:Show()
            self:RefreshSearchResults(true)
        end
    end)

    searchPanel:HookScript("OnHide", function()
        if self.mainFrame then
            self.mainFrame:Hide()
        end
    end)
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Core Events
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:OnSearchResultsUpdated()
    self:RefreshSearchResults(false)
end

function LFG:OnApplicantUpdated()
    if self.displayMode == "applicant" then
        self:RefreshApplicantList()
    end
end

function LFG:OnApplicationStatusUpdated()
    -- Triggered when your application status changes (invited, declined, etc)
    self:RefreshSearchResults(false)
end

function LFG:OnThemeChanged()
    -- Triggered when global appearance settings change
    if self.mainFrame then
        self:RefreshFrameAppearance()
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Public API
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:GetOptions()
    return self.Options or {}
end

function LFG:RefreshSearchResults(showLoading)
    -- Fetch and rebuild search results; implemented in Core.lua
    if self.RefreshSearchResultsImpl then
        self:RefreshSearchResultsImpl(showLoading == true)
    end
end

function LFG:RefreshApplicantList()
    -- Refresh applicant list; implemented in Core.lua
    if self.RefreshApplicantListImpl then
        self:RefreshApplicantListImpl()
    end
end

function LFG:RefreshFrameAppearance()
    -- Re-apply theme colors and fonts
    if self.RefreshFrameAppearanceImpl then
        self:RefreshFrameAppearanceImpl()
    end
end

function LFG:EnsureMainFrame()
    if not self.mainFrame and self.CreateMainFrameImpl then
        self:CreateMainFrameImpl()
    end
end

function LFG:Show()
    self:EnsureMainFrame()
    if self.mainFrame then
        self.mainFrame:Show()
    end
    self.isOpen = true
end

function LFG:Hide()
    if self.mainFrame then
        self.mainFrame:Hide()
    end
    self.isOpen = false
end

function LFG:SwitchMode(mode)
    self.displayMode = mode
    self:RefreshSearchResults(false)
end
