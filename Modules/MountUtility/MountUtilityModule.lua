--[[
    Module that provides utilities for working with mounts
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local GetMountInfoByID = C_MountJournal.GetMountInfoByID
local GetIsFavorite = C_MountJournal.GetIsFavorite
local GetDisplayedMountInfo = C_MountJournal.GetDisplayedMountInfo
local GetNumMounts = C_MountJournal.GetNumMounts
local GetMountFromSpell = C_MountJournal.GetMountFromSpell

---@class MountUtilityModule : AceModule, AceEvent-3.0
---@field flaggedForRefresh boolean indicates if the mount cache needs refreshing
local MUM = T:NewModule("MountUtility", "AceEvent-3.0")
MUM:SetEnabledState(true)

--- Sorts a table of mounts alphabetically by name
--- @param t table
local function SortTableAlphabetically(t)
    table.sort(t, function(a, b)
        return tostring(a.name or "") < tostring(b.name or "")
    end)
end

--- Retrieves all mounts from the mount journal. This is the intensive from-scratch version, and should only be called when required.
--- @return table<number, {name: string, spellID: number, icon: string, mountID: number, isFavorite: boolean}>
local function GetMountsFromMountJournal()
    -- start by looping through all the mounts to gather information
    local entries = {}
    local numMounts = GetNumMounts() or 0
    for displayIndex = 1, numMounts do
        local creatureName, spellID, icon, _, _, _, _, _, _, _, isCollected, mountID =
            GetDisplayedMountInfo(displayIndex)

        local isFavorite = mountID and GetIsFavorite(mountID) or false

        if isCollected and mountID and creatureName and spellID then
            tinsert(entries, {
                name = creatureName,
                spellID = spellID,
                icon = icon,
                mountID = mountID,
                isFavorite = isFavorite
            })
        end
    end
    return entries
end

local function ClearCachedMounts()
    T.db.faction.mountsCache = nil
end

local function SaveMountsToCache(mounts)
    T.db.faction.mountsCache = mounts
end

local function GetCachedMounts()
    -- storing cached mounts in the faction db, as mounts are account wide but faction specific
    if not T.db.faction.mountsCache or #T.db.faction.mountsCache == 0 then
        return nil
    end

    return T.db.faction.mountsCache
end

function MUM:RefreshMountCache()
    ClearCachedMounts()
    local mounts = GetMountsFromMountJournal()
    SaveMountsToCache(mounts)
    self:SendMessage("PLAYER_MOUNT_CACHE_UPDATED")
end

function MUM:SetCacheDirty()
    self.flaggedForRefresh = true
end

function MUM:OnEnable()
    -- listen to mount events in order to keep the mount cache updated, but only when required
    self:RegisterEvent("NEW_MOUNT_ADDED", "RefreshMountCache")

    self:RegisterEvent("ADDON_LOADED", function(_, addonName)
        if addonName == "Blizzard_Collections" then
            MountJournal:HookScript("OnHide", function()
                if self.flaggedForRefresh then
                    self:RefreshMountCache()
                    self.flaggedForRefresh = false
                end
                self:UnregisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
            end)
            MountJournal:HookScript("OnShow", function()
                -- when the mount journal is shown, we can clear the dirty flag, as any changes will be captured when it is hidden again
                self:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED", function()
                    self:SetCacheDirty()
                end)
            end)
        end
    end)

    -- refresh the cache if it does not exist
    if not GetCachedMounts() then
        self:RefreshMountCache()
    end

    -- T.Tools.Text.DumpTable(GetCachedMounts())
end

function MUM:GetPlayerUtilityMountsByCapability(capability)
    ---@type DataModule
    local DataModule = T:GetModule("Data")
    local allUtilities = self:GetPlayerMounts("UTILITY")
    local filtered = {}

    local utilityDefs = DataModule.Mounts and DataModule.Mounts.Utility or nil
    if not utilityDefs then
        return filtered
    end

    for _, entry in ipairs(allUtilities) do
        local def = utilityDefs[entry.spellID]
        local caps = def and def.capabilities
        if caps then
            for _, cap in ipairs(caps) do
                if cap == capability then
                    tinsert(filtered, entry)
                    break
                end
            end
        end
    end

    SortTableAlphabetically(filtered)
    return filtered
end

--- Gets a list of player mounts filtered by type
---@param type "ALL"|"AQUATIC"|"UTILITY"|"FAVORITE"
---@return table<number, {name: string, spellID: number, icon: string, mountID: number, isFavorite: boolean}>
function MUM:GetPlayerMounts(type)
    local entries = GetCachedMounts()
    -- ensure we have mounts, in some rare race-case where this gets called before the module is enbabled.
    if not entries then
        entries = GetMountsFromMountJournal()
        SaveMountsToCache(entries)
    end

    -- return all mounts collected by user
    if type == "ALL" or not type then
        SortTableAlphabetically(entries)
        return entries
    end

    -- return only favorite mounts
    if type == "FAVORITE" then
        local favorites = {}
        for _, entry in ipairs(entries) do
            if entry.isFavorite then
                tinsert(favorites, entry)
            end
        end
        SortTableAlphabetically(favorites)
        return favorites
    end

    ---@type DataModule
    local DataModule = T:GetModule("Data")

    -- return only utility mounts
    if type == "UTILITY" then
        local utilitySet = {}
        -- DataModule.Mounts.Utility is a map of spellID -> { capabilities = {...} }
        for spellID, _ in pairs(DataModule.Mounts.Utility or {}) do
            local mountID = GetMountFromSpell(spellID)
            if mountID then
                utilitySet[mountID] = true
            end
        end

        local utilities = {}
        for _, entry in ipairs(entries) do
            if utilitySet[entry.mountID] then
                tinsert(utilities, entry)
            end
        end
        SortTableAlphabetically(utilities)
        return utilities
    end

    -- return only aquatic mounts
    if type == "AQUATIC" then
        -- Helper function to collect mount IDs from a list of spell IDs
        local aquaticSet = {}
        for _, spellID in ipairs(DataModule.Mounts.Swimming or {}) do
            local mountID = GetMountFromSpell(spellID)
            if mountID then
                aquaticSet[mountID] = true
            end
        end
        local aquatics = {}
        for _, entry in ipairs(entries) do
            if aquaticSet[entry.mountID] then
                tinsert(aquatics, entry)
            end
        end
        SortTableAlphabetically(aquatics)
        return aquatics
    end

    --fallbak; all
    SortTableAlphabetically(entries)
    return entries
end

function MUM:GetMountLabelByID(mountID)
    local id = tonumber(mountID) or 0
    if id <= 0 then
        return "None"
    end
    local name, _, icon = GetMountInfoByID(id)
    if name and icon then
        return ("|T%s:14:14|t %s"):format(icon, name)
    end
    if name then
        return name
    end

    return tostring(id)
end

---@param mountID number|nil
---@return boolean
function MUM:IsMountUsable(mountID)
    if not mountID or mountID == 0 then return false end

    local _, _, _, _, isUsable = GetMountInfoByID(mountID)
    return isUsable and true or false
end
