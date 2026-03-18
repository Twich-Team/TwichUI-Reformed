--[[
        Best in Slot -- Monitor Dropped Items module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

---@class MonitorDroppedItemsModule: AceEvent-3.0
local Monitor = BIS:NewModule("MonitorDroppedItems", "AceEvent-3.0")

function Monitor:OnEnable()
    self:RegisterEvent("START_LOOT_ROLL")
end

function Monitor:START_LOOT_ROLL(event, rollID)
    if not rollID then return end

    local link = GetLootRollItemLink(rollID)
    if type(link) ~= "string" or link == "" then
        return
    end

    local itemID = C_Item.GetItemInfoInstant(link)
    if not itemID then return end

    ---@type MonitorGreatVaultItemsModule
    local GVMonitor = BIS:GetModule("MonitorGreatVaultItems")

    if not GVMonitor.IsItemBestInSlot(itemID) then return end

    local function CreateMessage(text, itemLink)
        local AceGUI = LibStub("AceGUI-3.0")

        local widget = AceGUI:Create("TwichUI_Item")
        ---@type NotificationOptions
        local notifOptions = {}

        ---@type ConfigurationModule
        local ConfigurationModule = T:GetModule("Configuration")
        local options = ConfigurationModule.Options.BestInSlot

        if options:IsSoundEnabled() then
            notifOptions.soundKey = options:GetAvailableSound()
        end

        notifOptions.displayDuration = options:GetNotificationDisplayTime()
        notifOptions.wrap = true
        notifOptions.wrapMessage = T.Tools.Text.Color(T.Tools.Colors.GREEN,
            text)
        notifOptions.wrapMessageOptions = {
            fontSize = 12,
        }

        widget:SetItem(link)
        Monitor:SendMessage("TWICH_NOTIFICATION", widget, notifOptions)
    end


    --- is it an upgrade?
    local alreadyOwned, alreadyEquipped, ownedIlvl, ownedLink, ownedTrackRank = BIS.ItemScanner.PlayerOwnsItem(itemID)
    local isUpgrade = not alreadyOwned or (ownedIlvl and ownedIlvl < C_Item.GetItemInfoInstant(link))

    if alreadyOwned and link then
        local track, currentStage, maxStage = BIS.ItemScanner.GetTrackFromLink(link)
        local newTrackRank = BIS.ItemScanner.GetGearTrackRank(track)

        if newTrackRank and ownedTrackRank and newTrackRank > ownedTrackRank then
            -- upgraded track available
            local ownedTrackStr = BIS.ItemScanner.GetGearTrackByRank(ownedTrackRank)
            CreateMessage(
                "An upgraded Best In Slot item is available to roll for! " ..
                T.Tools.Text.ToTitleCase(ownedTrackStr) .. " → " .. track,
                link)
        else
            -- same or lower track
        end
    elseif not alreadyOwned then
        -- not owned at all, so upgrade by default
        CreateMessage("A new Best In Slot item is available to roll for!", link)
    end
end
