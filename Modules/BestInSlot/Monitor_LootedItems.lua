--[[
        Best in Slot -- Monitor Looted Items module.

        Responsibilities:
        - Listens for loot events, and checks if the looted item is in the players list of best in slot items
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

---@class MonitorLootedItemsModule: AceEvent-3.0
local Monitor = BIS:NewModule("MonitorLootedItems", "AceEvent-3.0")

local AceGUI = LibStub("AceGUI-3.0")

--- pattern to match to find items the player looted
local LOOT_SELF_PATTERN = string.gsub(LOOT_ITEM_SELF, "%%s", "(.+)")


---@return table<number, BisItem> items table of itemIDs that are best in slot
local function GetBISItemIDs()
	local db = BIS.GetBestInSlotItemDB()

	local itemIDs = {}
	for _, bisItem in pairs(db) do
		itemIDs[bisItem.itemID] = bisItem
	end

	return itemIDs
end

local function ItemHathBeenReceived(itemInfo)
	-- T:Print("You have received a Best in Slot item!", itemInfo.link)

	local function CreateMessage(text)
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

		widget:SetItem(itemInfo.link)
		Monitor:SendMessage("TWICH_NOTIFICATION", widget, notifOptions)
	end

	-- check if player already has the item
	local owned, equpped, ilvl, link, previousTrackRank = BIS.ItemScanner.PlayerOwnsItem(itemInfo.itemID)
	if owned then
		-- check if the newitem has a higher item track than the owned item
		local newOwned, newEquipped, newItemLevel, newExactLink, newTrackRank =
			BIS.ItemScanner.PlayerOwnsItem(itemInfo.itemID)

		if not newOwned then
			-- dont think this will happen but log it incase so i can find it
			T:Print("Error checking owned item for track comparison.")
		end

		if newTrackRank and previousTrackRank and newTrackRank > previousTrackRank then
			local ownedTrackStr = BIS.ItemScanner.GetGearTrackByRank(previousTrackRank)
			local newTrackStr = BIS.ItemScanner.GetGearTrackByRank(newTrackRank)

			CreateMessage("You have received an upgraded Best in Slot item! " ..
			T.Tools.Text.ToTitleCase(ownedTrackStr) .. " → " .. T.Tools.Text.ToTitleCase(newTrackStr))
		end
	else
		CreateMessage("You have received a Best in Slot item!")
	end
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
		local idFromLink = item:match("item:(%d+)")
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

function Monitor.IsItemBestInSlot(itemID)
	local bisItems = GetBISItemIDs()
	return bisItems[itemID] ~= nil
	-- return true
end

function Monitor:OnEnable()
	self:RegisterEvent("CHAT_MSG_LOOT")
end

function Monitor:CHAT_MSG_LOOT(_, message)
	local raw = type(message) == "string" and message:match(LOOT_SELF_PATTERN)
	if not raw then return end

	local itemLink = raw:match("(|c%x+|Hitem:[^|]+|h%[[^]]+%]|h|r)") or raw
	if not itemLink then return end

	GetItemInfoAsync(itemLink, function(itemInfo)
		if not itemInfo or not itemInfo.link then
			-- temp debug line to ensure functionality
			T:Print("Failed to retrieve item info for looted item:", itemLink)
			return
		end
		if Monitor.IsItemBestInSlot(itemInfo.link) then
			ItemHathBeenReceived(itemInfo)
		end
	end)
end
