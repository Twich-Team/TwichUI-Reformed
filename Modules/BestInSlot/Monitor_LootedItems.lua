--[[
        Best in Slot -- Monitor Looted Items module.

        Responsibilities:
        - Listens for loot events, and checks if the looted item is in the players list of best in slot items
]]
local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

---@class MonitorLootedItemsModule: AceEvent-3.0
local Monitor = BIS:NewModule("MonitorLootedItems", "AceEvent-3.0")

local AceGUI = LibStub("AceGUI-3.0")


---@return table<number, BisItem> items table of itemIDs that are best in slot
local function GetBISItemIDs()
	local db = BIS.GetBestInSlotItemDB()

	local itemIDs = {}
	for _, bisItem in pairs(db) do
		itemIDs[bisItem.itemID] = bisItem
	end

	return itemIDs
end

local function ItemHathBeenReceived(itemInfo, previousState, currentState)
	-- T:Print("You have received a Best in Slot item!", itemInfo.link)

	local function CreateMessage(text)
		---@type TwichUI_ItemWidget
		---@diagnostic disable-next-line: param-type-mismatch
		local widget = AceGUI:Create("TwichUI_Item")
		---@type NotificationOptions
		local notifOptions = {}

		---@type ConfigurationModule
		local ConfigurationModule = T:GetModule("Configuration")
		local options = ConfigurationModule.Options.BestInSlot

		if options:IsSoundEnabled() then
			notifOptions.soundKey = options:GetAquiredSound()
		end

		notifOptions.displayDuration = options:GetNotificationDisplayTime()
		notifOptions.wrap = true
		notifOptions.wrapMessage = T.Tools.Text.Color(T.Tools.Colors.GREEN, text)
		notifOptions.wrapMessageOptions = {
			fontSize = 12,
		}

		---@diagnostic disable-next-line: undefined-field
		widget:SetItem(itemInfo.link)
		Monitor:SendMessage("TWICH_NOTIFICATION", widget, notifOptions)
	end

	local previousTrackRank = previousState and previousState.bestTrackRank or nil
	local newTrackRank = currentState and currentState.bestTrackRank or nil

	if previousState and previousState.count > 0 and newTrackRank and previousTrackRank and newTrackRank > previousTrackRank then
		local ownedTrackStr = BIS.ItemScanner.GetGearTrackByRank(previousTrackRank)
		local newTrackStr = BIS.ItemScanner.GetGearTrackByRank(newTrackRank)

		CreateMessage("You have received an upgraded Best in Slot item! " ..
			T.Tools.Text.ToTitleCase(ownedTrackStr) .. " → " .. T.Tools.Text.ToTitleCase(newTrackStr))
		return
	end

	CreateMessage("You have received a Best in Slot item!")
end

function Monitor:CreateTest()
	local itemInfo = {
		itemID = 19019,
		link = "|cffa335ee|Hitem:19019::::::::60:::::::|h[Thunderfury, Blessed Blade of the Windseeker]|h|r",
		iLevel = 60,
	}
	ItemHathBeenReceived(itemInfo)
end

-- Keys for mapping GetItemInfo() returns into a table
local ITEMINFO_KEYS = {
	"name", "link", "quality", "iLevel", "minLevel", "type", "subType",
	"maxStack", "equipLoc", "icon", "sellPrice", "classID", "subClassID",
	"bindType", "expansionID", "setID", "isCraftingReagent"
}

local function GetItemInfoAsync(item, callback)
	if type(callback) ~= "function" then return end

	-- Normalize to itemID
	local itemID = item
	if type(item) == "string" then
		local idFromLink = string.match(item, "item:(%d+)")
		if idFromLink then
			itemID = tonumber(idFromLink)
		end
	end
	if not itemID then
		callback(nil)
		return
	end

	local name = C_Item.GetItemInfo(itemID)
	if name then
		local results = { C_Item.GetItemInfo(itemID) }
		local info = {}
		for i = 1, #results do
			info[ITEMINFO_KEYS[i] or ("field" .. i)] = results[i]
		end
		info["itemID"] = itemID
		callback(info)
		return
	end

	if not Item or not Item.CreateFromItemID then
		callback(nil)
		return
	end

	local itemObj = Item:CreateFromItemID(itemID)
	itemObj:ContinueOnItemLoad(function()
		local results = { C_Item.GetItemInfo(itemID) }
		if not results[1] then
			callback(nil)
			return
		end
		local info = {}
		for i = 1, #results do
			info[ITEMINFO_KEYS[i] or ("field" .. i)] = results[i]
		end
		info["itemID"] = itemID
		callback(info)
	end)
end

local function GetBagMaxIndex()
	if type(NUM_TOTAL_EQUIPPED_BAG_SLOTS) == "number" then
		return NUM_TOTAL_EQUIPPED_BAG_SLOTS
	end

	if type(NUM_BAG_SLOTS) == "number" then
		return NUM_BAG_SLOTS
	end

	return 4
end

local function BuildOwnedItemState(itemID)
	local state = {
		count = 0,
		bestTrackRank = nil,
		bestLink = nil,
		bestItemLevel = nil,
		bagLinks = {},
	}

	local function ConsiderItem(link, trackRank, itemLevel, isBagItem)
		state.count = state.count + 1

		local currentBestTrack = state.bestTrackRank or -1
		local candidateTrack = trackRank or -1
		local currentBestLevel = state.bestItemLevel or -1
		local candidateLevel = itemLevel or -1

		if isBagItem and type(link) == "string" and link ~= "" then
			local bagEntry = state.bagLinks[link]
			if bagEntry then
				bagEntry.count = bagEntry.count + 1
				if candidateTrack > (bagEntry.trackRank or -1) or
					(candidateTrack == (bagEntry.trackRank or -1) and candidateLevel > (bagEntry.itemLevel or -1)) then
					bagEntry.trackRank = trackRank
					bagEntry.itemLevel = itemLevel
				end
			else
				state.bagLinks[link] = {
					count = 1,
					trackRank = trackRank,
					itemLevel = itemLevel,
				}
			end
		end

		if not state.bestLink or candidateTrack > currentBestTrack or (candidateTrack == currentBestTrack and candidateLevel > currentBestLevel) then
			state.bestTrackRank = trackRank
			state.bestLink = link
			state.bestItemLevel = itemLevel
		end
	end

	for slotIndex = 1, 19 do
		if GetInventoryItemID("player", slotIndex) == itemID then
			local link = GetInventoryItemLink("player", slotIndex)
			local itemLevel = link and C_Item.GetDetailedItemLevelInfo(link) or nil
			local track = BIS.ItemScanner.GetTrackFromEquippedItem(slotIndex)
			local trackRank = BIS.ItemScanner.GetGearTrackRank(track)
			ConsiderItem(link, trackRank, itemLevel, false)
		end
	end

	for bagIndex = 0, GetBagMaxIndex() do
		local numSlots = C_Container.GetContainerNumSlots(bagIndex)
		for slotIndex = 1, numSlots do
			if C_Container.GetContainerItemID(bagIndex, slotIndex) == itemID then
				local link = C_Container.GetContainerItemLink(bagIndex, slotIndex)
				local itemLevel = link and C_Item.GetDetailedItemLevelInfo(link) or nil
				local track = BIS.ItemScanner.GetTrackFromBagItem(bagIndex, slotIndex)
				local trackRank = BIS.ItemScanner.GetGearTrackRank(track)
				ConsiderItem(link, trackRank, itemLevel, true)
			end
		end
	end

	return state
end

local function ConsiderOwnedItem(state, link, trackRank, itemLevel, isBagItem)
	state.count = state.count + 1

	local currentBestTrack = state.bestTrackRank or -1
	local candidateTrack = trackRank or -1
	local currentBestLevel = state.bestItemLevel or -1
	local candidateLevel = itemLevel or -1

	if isBagItem and type(link) == "string" and link ~= "" then
		local bagEntry = state.bagLinks[link]
		if bagEntry then
			bagEntry.count = bagEntry.count + 1
			if candidateTrack > (bagEntry.trackRank or -1) or
				(candidateTrack == (bagEntry.trackRank or -1) and candidateLevel > (bagEntry.itemLevel or -1)) then
				bagEntry.trackRank = trackRank
				bagEntry.itemLevel = itemLevel
			end
		else
			state.bagLinks[link] = {
				count = 1,
				trackRank = trackRank,
				itemLevel = itemLevel,
			}
		end
	end

	if not state.bestLink or candidateTrack > currentBestTrack or (candidateTrack == currentBestTrack and candidateLevel > currentBestLevel) then
		state.bestTrackRank = trackRank
		state.bestLink = link
		state.bestItemLevel = itemLevel
	end
end

local function SelectPreferredBagLink(candidates)
	local bestCandidate

	for _, candidate in ipairs(candidates) do
		if not bestCandidate then
			bestCandidate = candidate
		else
			local bestTrack = bestCandidate.trackRank or -1
			local candidateTrack = candidate.trackRank or -1
			local bestLevel = bestCandidate.itemLevel or -1
			local candidateLevel = candidate.itemLevel or -1

			if candidateTrack > bestTrack or (candidateTrack == bestTrack and candidateLevel > bestLevel) then
				bestCandidate = candidate
			end
		end
	end

	return bestCandidate and bestCandidate.link or nil
end

local function GetReceivedBagLink(previousState, currentState)
	local previousBagLinks = previousState and previousState.bagLinks or {}
	local currentBagLinks = currentState and currentState.bagLinks or {}
	local addedLinks = {}

	for link, currentEntry in pairs(currentBagLinks) do
		local previousCount = previousBagLinks[link] and previousBagLinks[link].count or 0
		if currentEntry.count > previousCount then
			table.insert(addedLinks, {
				link = link,
				trackRank = currentEntry.trackRank,
				itemLevel = currentEntry.itemLevel,
			})
		end
	end

	return SelectPreferredBagLink(addedLinks)
end

local function BuildInventorySnapshot()
	local snapshot = {}
	local bisItems = GetBISItemIDs()

	for itemID in pairs(bisItems) do
		snapshot[itemID] = {
			count = 0,
			bestTrackRank = nil,
			bestLink = nil,
			bestItemLevel = nil,
			bagLinks = {},
		}
	end

	for slotIndex = 1, 19 do
		local itemID = GetInventoryItemID("player", slotIndex)
		local state = itemID and snapshot[itemID] or nil
		if state then
			local link = GetInventoryItemLink("player", slotIndex)
			local itemLevel = link and C_Item.GetDetailedItemLevelInfo(link) or nil
			local track = BIS.ItemScanner.GetTrackFromEquippedItem(slotIndex)
			local trackRank = BIS.ItemScanner.GetGearTrackRank(track)
			ConsiderOwnedItem(state, link, trackRank, itemLevel, false)
		end
	end

	for bagIndex = 0, GetBagMaxIndex() do
		local numSlots = C_Container.GetContainerNumSlots(bagIndex)
		for slotIndex = 1, numSlots do
			local itemID = C_Container.GetContainerItemID(bagIndex, slotIndex)
			local state = itemID and snapshot[itemID] or nil
			if state then
				local link = C_Container.GetContainerItemLink(bagIndex, slotIndex)
				local itemLevel = link and C_Item.GetDetailedItemLevelInfo(link) or nil
				local track = BIS.ItemScanner.GetTrackFromBagItem(bagIndex, slotIndex)
				local trackRank = BIS.ItemScanner.GetGearTrackRank(track)
				ConsiderOwnedItem(state, link, trackRank, itemLevel, true)
			end
		end
	end

	return snapshot
end

function Monitor:RefreshInventorySnapshot()
	self.inventorySnapshot = BuildInventorySnapshot()
end

function Monitor:HandleReceivedBestInSlotItem(itemID, previousState, currentState)
	local itemLink = GetReceivedBagLink(previousState, currentState) or (currentState and currentState.bestLink) or nil
	if type(itemLink) == "string" and itemLink ~= "" then
		local linkedItemID = C_Item.GetItemInfoInstant(itemLink) or itemID
		if Monitor.IsItemBestInSlot(linkedItemID) then
			ItemHathBeenReceived({ itemID = linkedItemID, link = itemLink }, previousState, currentState)
		end
		return
	end

	GetItemInfoAsync(itemID, function(itemInfo)
		if not itemInfo or not itemInfo.link then
			T:Print("Failed to retrieve item info for looted item:", tostring(itemID))
			return
		end

		if Monitor.IsItemBestInSlot(itemInfo.itemID) then
			ItemHathBeenReceived(itemInfo, previousState, currentState)
		end
	end)
end

function Monitor.IsItemBestInSlot(itemID)
	local bisItems = GetBISItemIDs()
	return bisItems[itemID] ~= nil
	-- return true
end

function Monitor:OnEnable()
	self:RefreshInventorySnapshot()
	self:RegisterEvent("BAG_UPDATE_DELAYED")
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
end

function Monitor:PLAYER_SPECIALIZATION_CHANGED()
	self:RefreshInventorySnapshot()
end

function Monitor:BAG_UPDATE_DELAYED()
	local previousSnapshot = self.inventorySnapshot or {}
	local currentSnapshot = BuildInventorySnapshot()

	for itemID, currentState in pairs(currentSnapshot) do
		local previousState = previousSnapshot[itemID]
		if previousState and currentState.count > previousState.count then
			self:HandleReceivedBestInSlotItem(itemID, previousState, currentState)
		end
	end

	self.inventorySnapshot = currentSnapshot
end
