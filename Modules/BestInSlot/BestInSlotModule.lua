--[[
        Best in Slot module.

        Responsibilities:
        - Scans the dungeon journal to find rewards for the current season.
        - Tracks loot received to provide a notification when a best in slot item is received.
        - Listens to various events to provide a notification when a best in slot item is available.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class BestInSlotModule : AceModule, AceEvent-3.0, AceConsole-3.0
---@field ItemScanner BestInSlotItemScanner
---@field Frame BestInSlotFrame
local BIS = T:NewModule("BestInSlot", "AceEvent-3.0", "AceConsole-3.0")

local function CopySelectedItems(items)
    local copied = {}
    for slotID, bisItem in pairs(items or {}) do
        if type(slotID) == "number" and type(bisItem) == "table" then
            copied[slotID] = {
                itemID = bisItem.itemID,
                slotID = bisItem.slotID,
                sourceInstance = bisItem.sourceInstance,
            }
        end
    end

    return copied
end

function BIS.GetCurrentSpecializationID()
    if type(GetSpecialization) ~= "function" or type(GetSpecializationInfo) ~= "function" then
        return 0
    end

    local specIndex = GetSpecialization()
    if type(specIndex) ~= "number" then
        return 0
    end

    local specID = GetSpecializationInfo(specIndex)
    return type(specID) == "number" and specID or 0
end

--- The character-level best in slot database. This contains loot cache and other per-character data.
function BIS.GetCharacterBISDB()
    if not T.db.char.bis then
        ---@class BiSCharacterDB
        ---@field LootCache BestInSlotLootCache
        ---@field CacheGameVersion string
        T.db.char.bis = {}
    end
    return T.db.char.bis
end

---@alias BisItem { itemID: number, slotID: number, sourceInstance: string}

---@param specID number|nil
---@return table<number, BisItem> slotIDtItemID mapping of slotID to itemID for the selected best in slot items.
function BIS.GetBestInSlotItemDB(specID)
    local charDB = BIS.GetCharacterBISDB()

    if type(charDB.SelectedItemsBySpec) ~= "table" then
        charDB.SelectedItemsBySpec = {}
    end

    local resolvedSpecID = type(specID) == "number" and specID or BIS.GetCurrentSpecializationID()

    if charDB.LegacySelectedItemsMigrated ~= true and type(charDB.SelectedItems) == "table" and next(charDB.SelectedItems) ~= nil then
        if type(charDB.SelectedItemsBySpec[resolvedSpecID]) ~= "table" or next(charDB.SelectedItemsBySpec[resolvedSpecID]) == nil then
            charDB.SelectedItemsBySpec[resolvedSpecID] = CopySelectedItems(charDB.SelectedItems)
        end

        charDB.LegacySelectedItemsMigrated = true
        charDB.SelectedItems = nil
    end

    if type(charDB.SelectedItemsBySpec[resolvedSpecID]) ~= "table" then
        charDB.SelectedItemsBySpec[resolvedSpecID] = {}
    end

    return charDB.SelectedItemsBySpec[resolvedSpecID]
end

function BIS.GetConfigurationOptions()
    ---@type ConfigurationModule
    local ConfigurationModule = T:GetModule("Configuration")
    return ConfigurationModule.Options.BestInSlot
end

function BIS.ForceRefreshCache()
    BIS.ItemScanner.Scan()
end

function BIS:OnEnable()
    if BIS.ItemScanner.DoesCacheRequireRefresh() then
        BIS.ItemScanner.Scan()
    end

    local Options = BIS.GetConfigurationOptions()
    if Options:GetMonitorReceivedItems() then
        BIS:GetModule("MonitorLootedItems"):Enable()
    end

    if Options:GetMonitorGreatVaultItems() then
        BIS:GetModule("MonitorGreatVaultItems"):Enable()
    end

    if Options:IsGreatVaultHighlightEnabled() then
        BIS:GetModule("GreatVaultEnhancement"):Enable()
    end

    if Options:GetMonitorDroppedItems() then
        BIS:GetModule("MonitorDroppedItems"):Enable()
    end

    -- BIS.Frame:Create()
    BIS:RegisterChatCommand("bis", function() BIS.Frame:Show() end)
end

function BIS.GetItemCache()
    local charDB = BIS.GetCharacterBISDB()
    return charDB.LootCache
end
