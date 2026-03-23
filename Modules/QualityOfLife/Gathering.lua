if not rawget(_G, 'TwichRx') then
	-- Delay module initialization until TwichRx is available
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:SetScript("OnEvent", function(self, event, addon)
		local rx = rawget(_G, 'TwichRx')
		if rx then
			local T = unpack(rx)
			-- re-run the module initialization
			if T and T.NewModule then
				T.Modules = T.Modules or {}
				local Module = T:NewModule("Gathering", "AceEvent-3.0")
				-- ...existing code...
			end
			self:UnregisterEvent("ADDON_LOADED")
			self:SetScript("OnEvent", nil)
		end
	end)
	return
end
local T = unpack(_G.TwichRx)
T.Modules = T.Modules or {}
local Module = T:NewModule("Gathering", "AceEvent-3.0")
local Options = T:GetModule("Configuration").Options.Gathering
local Notification = T:GetModule("Notification")
local Datatexts = T:GetModule("Datatexts")
local TSM = T:GetModule("ThirdPartyAPI").TSM

local sessionActive = false
local sessionStart = 0
local sessionLoot = {} -- [itemID] = {count, value, name, link}
local sessionTotal = 0
local sessionValue = 0
local sessionGPH = 0

local function ResetSession()
	sessionActive = true
	sessionStart = time()
	sessionLoot = {}
	sessionTotal = 0
	sessionValue = 0
	sessionGPH = 0
end

local function EndSession()
	sessionActive = false
end

local function GetSessionStats()
	if not sessionActive then return 0, 0, 0, {} end
	local elapsed = math.max(1, time() - sessionStart)
	sessionGPH = math.floor((sessionValue / elapsed) * 3600)
	return sessionTotal, sessionValue, sessionGPH, sessionLoot
end

local function AddLoot(itemID, count, value, name, link)
	if not sessionActive then return end
	if not sessionLoot[itemID] then
		sessionLoot[itemID] = { count = 0, value = 0, name = name, link = link }
	end
	sessionLoot[itemID].count = sessionLoot[itemID].count + count
	sessionLoot[itemID].value = sessionLoot[itemID].value + value
	sessionTotal = sessionTotal + count
	sessionValue = sessionValue + value
end

function Module:StartSession()
	ResetSession()
end

function Module:EndSession()
	EndSession()
end

function Module:GetSessionStats()
	return GetSessionStats()
end

function Module:OnEnable()
	self:RegisterEvent("LOOT_READY")
	self:RegisterEvent("PLAYER_LOGOUT")
	ResetSession()
end

function Module:PLAYER_LOGOUT()
	EndSession()
end

function Module:LOOT_READY()
	if not Options:GetEnabled() or not sessionActive then return end
	for i = 1, GetNumLootItems() do
		local itemLink = GetLootSlotLink(i)
		if itemLink then
			local itemName, itemLink2, _, _, _, _, _, _, _, itemIcon, itemSellPrice, itemID = C_Item.GetItemInfoInstant(
			itemLink)
			local count = select(3, GetLootSlotInfo(i)) or 1
			local value = 0
			if Options:GetPricingEnabled() and TSM and TSM.GetItemValue then
				value = TSM:GetItemValue(itemLink, Options:GetPriceSource()) * count
			else
				value = (itemSellPrice or 0) * count
			end
			AddLoot(itemID, count, value, itemName, itemLink)
			if Options:GetNotificationsEnabled() then
				local isHighValue = value >= Options:GetValueGate()
				Notification:ShowGatherNotification(itemLink, count, value, isHighValue)
			end
		end
	end
end

T.Modules.QualityOfLifeGathering = Module
