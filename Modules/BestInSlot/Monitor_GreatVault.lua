--[[
        Best in Slot -- Monitor Great Vault Items module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

---@class MonitorGreatVaultItemsModule: AceEvent-3.0
local Monitor = BIS:NewModule("MonitorGreatVaultItems", "AceEvent-3.0")

local VaultHighlight = {
    hooked = false,
    glowByTarget = setmetatable({}, { __mode = "k" }),
    active = setmetatable({}, { __mode = "k" }),
    listener = nil,
}

---@return Frame|nil frame, string|nil frameName
function Monitor.FindVaultFrame()
    local f = rawget(_G, "WeeklyRewardsFrame")
    if f and type(f.IsShown) == "function" and f:IsShown() then
        return f, "WeeklyRewardsFrame"
    end
    return nil, nil
end

---@param frame table|Frame|nil
---@return string|nil link
function Monitor.FindItemLink(frame)
    if not frame then return nil end

    local link = frame.itemLink or frame.hyperlink or frame.link
    if type(link) == "string" and link ~= "" then
        return link
    end

    if type(frame.GetHyperlink) == "function" then
        local ok, h = pcall(frame.GetHyperlink, frame)
        if ok and type(h) == "string" and h ~= "" then
            return h
        end
    end

    if type(frame.GetItemLocation) == "function" and _G.C_Item and type(_G.C_Item.GetItemLink) == "function" then
        local ok, loc = pcall(frame.GetItemLocation, frame)
        if ok and loc then
            local ok2, l = pcall(_G.C_Item.GetItemLink, loc)
            if ok2 and type(l) == "string" and l ~= "" then
                return l
            end
        end
    end

    local itemDBID = tonumber(frame.itemDBID or frame.itemDbID or frame.itemDBId)
    if not itemDBID and type(frame.rewardInfo) == "table" then
        itemDBID = tonumber(frame.rewardInfo.itemDBID or frame.rewardInfo.itemDbID or frame.rewardInfo.itemDBId)
    end
    if itemDBID and _G.C_WeeklyRewards then
        local fn = _G.C_WeeklyRewards.GetItemHyperlink or _G.C_WeeklyRewards.GetItemLink
        if type(fn) == "function" then
            local ok, l = pcall(fn, itemDBID)
            if ok and type(l) == "string" and l ~= "" then
                return l
            end
        end
    end

    -- Some vault reward buttons expose a displayedItemDBID (often a large/opaque value).
    -- Try resolving it through C_WeeklyRewards without converting it.
    local displayed = frame.displayedItemDBID or frame.displayedItemDbID or frame.displayedItemDBId
    if displayed ~= nil and _G.C_WeeklyRewards then
        local fn = C_WeeklyRewards.GetItemHyperlink or C_WeeklyRewards.GetItemLink
        if type(fn) == "function" then
            local ok, l = pcall(fn, displayed)
            if ok and type(l) == "string" and l ~= "" then
                return l
            end
        end
    end

    do
        local sub = frame.Item or frame.item or frame.ItemFrame or frame.itemFrame or frame.ItemButton or
            frame.itemButton or frame.Reward or frame.reward
        if type(sub) == "table" and sub ~= frame then
            local l = Monitor.FindItemLink(sub)
            if l then return l end
        end
    end

    return nil
end

---@param link string|nil
---@return integer|nil itemID
function Monitor.GetItemIDFromLink(link)
    if type(link) ~= "string" or link == "" then
        return nil
    end

    if _G.C_Item and type(C_Item.GetItemInfoInstant) == "function" then
        local id = C_Item.GetItemInfoInstant(link)
        if type(id) == "number" then
            return id
        end
        id = tonumber(id)
        if id then return id end
    end

    if type(C_Item.GetItemInfoInstant) == "function" then
        local id = C_Item.GetItemInfoInstant(link)
        if type(id) == "number" then
            return id
        end
        id = tonumber(id)
        if id then return id end
    end

    return nil
end

---@param itemDBID integer|nil
---@return string|nil link
local function GetWeeklyRewardLinkFromDBID(itemDBID)
    if not itemDBID or not _G.C_WeeklyRewards then
        return nil
    end

    local fn = _G.C_WeeklyRewards.GetItemHyperlink or _G.C_WeeklyRewards.GetItemLink
    if type(fn) ~= "function" then
        return nil
    end

    local ok, l = pcall(fn, itemDBID)
    if ok and type(l) == "string" and l ~= "" then
        return l
    end

    return nil
end

-- mess of a function trying to find the itemid for a weekly reward widget
---@param frame table|Frame|nil
---@return integer|nil itemID
function Monitor.FindItemID(frame)
    if not frame then return nil end
    if frame.itemID and tonumber(frame.itemID) then
        return tonumber(frame.itemID)
    end

    if frame.itemId and tonumber(frame.itemId) then
        return tonumber(frame.itemId)
    end

    if type(frame.itemInfo) == "table" and frame.itemInfo.itemID and tonumber(frame.itemInfo.itemID) then
        return tonumber(frame.itemInfo.itemID)
    end

    if type(frame.rewardInfo) == "table" and frame.rewardInfo.itemID and tonumber(frame.rewardInfo.itemID) then
        return tonumber(frame.rewardInfo.itemID)
    end

    if type(frame.data) == "table" and frame.data.itemID and tonumber(frame.data.itemID) then
        return tonumber(frame.data.itemID)
    end

    -- Some WeeklyRewards widgets expose an itemDBID (not an itemID).
    local itemDBID = tonumber(frame.itemDBID or frame.itemDbID or frame.itemDBId)
    if not itemDBID and type(frame.rewardInfo) == "table" then
        itemDBID = tonumber(frame.rewardInfo.itemDBID or frame.rewardInfo.itemDbID or frame.rewardInfo.itemDBId)
    end
    do
        local link = GetWeeklyRewardLinkFromDBID(itemDBID)
        if link then
            local itemID = Monitor.GetItemIDFromLink(link)
            if itemID then
                return itemID
            end
        end
    end

    do
        -- Many reward widgets store item data on a nested item/button/frame.
        local sub = frame.Item or frame.item or frame.ItemFrame or frame.itemFrame or frame.ItemButton or
            frame.itemButton or frame.Reward or frame.reward
        if type(sub) == "table" and sub ~= frame then
            local id = Monitor.FindItemID(sub)
            if id then return id end
        end
    end

    local link = frame.itemLink or frame.hyperlink or frame.link
    do
        local id = Monitor.GetItemIDFromLink(link)
        if id then
            return id
        end
    end

    if type(frame.GetHyperlink) == "function" then
        local ok, h = pcall(frame.GetHyperlink, frame)
        if ok then
            local id = GetItemIDFromLink(h)
            if id then
                return id
            end
        end
    end

    if type(frame.GetItemLocation) == "function" and _G.C_Item and type(_G.C_Item.GetItemLink) == "function" then
        local ok, loc = pcall(frame.GetItemLocation, frame)
        if ok and loc then
            local ok2, l = pcall(_G.C_Item.GetItemLink, loc)
            if ok2 and type(l) == "string" and l ~= "" then
                local id = Monitor.GetItemIDFromLink(l)
                if id then
                    return id
                end
            end
        end
    end

    do
        local l = Monitor.FindItemLink(frame)
        if type(l) == "string" and l ~= "" then
            local id = Monitor.GetItemIDFromLink(l)
            if id then
                return id
            end
        end
    end

    return nil
end

---@param frame Frame
---@param frameName string|nil
---@return table<{itemID: integer, link: string, node: table|Frame|nil}> rewards
function Monitor.ScanVault(frame, frameName)
    local seen = {}
    ---@type {itemID: integer, link: string}[]
    local rewards = {}

    local function VisitNode(node)
        if not node or seen[node] then return end
        seen[node] = true

        local hasIcon = node.Icon or node.icon or node.IconTexture
        if not hasIcon and type(node.Item) == "table" then
            hasIcon = node.Item.Icon or node.Item.icon or node.Item.IconTexture
        end

        local itemID = Monitor.FindItemID(node)

        if itemID then
            if #rewards < 12 and hasIcon then
                local link = Monitor.FindItemLink(node)
                rewards[#rewards + 1] = {
                    itemID = itemID,
                    link = link,
                    node = node,
                }
            end
        end

        -- recurse
        if type(node.GetChildren) == "function" then
            local children = { node:GetChildren() }
            for i = 1, #children do
                VisitNode(children[i])
            end
        end
    end

    VisitNode(frame)

    return rewards
end

---@return BestInSlotConfigurationOptions
local function GetOptions()
    return T:GetModule("Configuration").Options.BestInSlot
end

function Monitor:OnEnable()
    Monitor:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
end

---@return table<number, BisItem> items table of itemIDs that are best in slot
local function GetBISItemIDs()
    local db = BIS.GetBestInSlotItemDB()

    local itemIDs = {}
    for _, bisItem in pairs(db) do
        itemIDs[bisItem.itemID] = bisItem
    end

    return itemIDs
end

function Monitor.IsItemBestInSlot(itemID)
    local bisItems = GetBISItemIDs()
    return bisItems[itemID] ~= nil
    -- return true
end

local function ItemIsethAvailable(itemID, link)
    local function CreateMessage(detailText, itemLink)
        local AceGUI = LibStub("AceGUI-3.0")

        local widget = AceGUI:Create("TwichUI_BISNotification")
        ---@type NotificationOptions
        local notifOptions = {}

        ---@type ConfigurationModule
        local ConfigurationModule = T:GetModule("Configuration")
        local options = ConfigurationModule.Options.BestInSlot

        if options:IsSoundEnabled() then
            notifOptions.soundKey = options:GetAvailableSound()
        end

        notifOptions.displayDuration = options:GetNotificationDisplayTime()

        widget:SetBISNotification(link, detailText, "available_vault")
        Monitor:SendMessage("TWICH_NOTIFICATION", widget, notifOptions)
    end

    local alreadyOwned, alreadyEquipped, ownedIlvl, ownedLink, ownedTrackRank = BIS.ItemScanner.PlayerOwnsItem(itemID)

    alreadyOwned = true
    ownedTrackRank = 1

    -- If the player already owns the item, check if the vault reward is a higher track rank.
    if alreadyOwned and link then
        local track, currentStage, maxStage = BIS.ItemScanner.GetTrackFromLink(link)
        local newTrackRank = BIS.ItemScanner.GetGearTrackRank(track)

        if newTrackRank and ownedTrackRank and newTrackRank > ownedTrackRank then
            -- upgraded track available
            local ownedTrackStr = BIS.ItemScanner.GetGearTrackByRank(ownedTrackRank)
            CreateMessage(T.Tools.Text.ToTitleCase(ownedTrackStr) .. " → " .. track, link)
        else
            -- same or lower track
        end
    elseif not alreadyOwned then
        -- Great Vault BIS item not owned yet
        CreateMessage(nil, link)
    end
end

---@param _ any
---@param frameType Enum.PlayerInteractionType|number
function Monitor:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(_, frameType)
    if frameType ~= Enum.PlayerInteractionType.WeeklyRewards then
        return
    end

    -- find the vault frame to hook
    local vaultFrame, frameName = Monitor.FindVaultFrame()
    if not vaultFrame then
        T:Print("Could not find vault frame")
        return
    end
    local rewards = self.ScanVault(vaultFrame, frameName)

    -- check if any of the found rewards are best in slot
    if rewards and #rewards > 0 then
        for _, reward in ipairs(rewards) do
            if Monitor.IsItemBestInSlot(reward.itemID) then
                ItemIsethAvailable(reward.itemID, reward.link)
            end
        end
    end
end
