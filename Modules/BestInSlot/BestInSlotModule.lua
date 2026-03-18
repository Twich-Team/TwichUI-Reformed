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

---@return table<number, BisItem> slotIDtItemID mapping of slotID to itemID for the selected best in slot items.
function BIS.GetBestInSlotItemDB()
    local charDB = BIS.GetCharacterBISDB()
    if not charDB.SelectedItems then
        charDB.SelectedItems = {}
    end
    return charDB.SelectedItems
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
