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

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

--- @class BestInSlotItemScanner
local ItemScanner = BIS.ItemScanner or {}
BIS.ItemScanner = ItemScanner

-- locals for WoW API functions
local EJ_GetLootFilter = EJ_GetLootFilter
local EJ_GetCurrentTier = EJ_GetCurrentTier
local EJ_GetDifficulty = EJ_GetDifficulty
local EJ_GetNumTiers = EJ_GetNumTiers
local EJ_GetCurrentTier = EJ_GetCurrentTier
local EJ_SelectTier = EJ_SelectTier
local EJ_GetInstanceByIndex = EJ_GetInstanceByIndex
local EJ_SelectInstance = EJ_SelectInstance
local EJ_GetEncounterInfoByIndex = EJ_GetEncounterInfoByIndex
local EJ_SelectEncounter = EJ_SelectEncounter
local EJ_SetDifficulty = EJ_SetDifficulty
local EJ_GetNumLoot = EJ_GetNumLoot
local LoadAddon = C_AddOns.LoadAddOn
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local GetCurrentSeason = C_MythicPlus.GetCurrentSeason
local GetMapTable = C_ChallengeMode.GetMapTable
local GetMapUIInfo = C_ChallengeMode.GetMapUIInfo
local GetLootInfoByIndex = C_EncounterJournal.GetLootInfoByIndex
local GetItemSets = C_LootJournal.GetItemSets
local GetItemSetItems = C_LootJournal.GetItemSetItems


-- Armor Types: 1=Cloth, 2=Leather, 3=Mail, 4=Plate
local CLASS_ARMOR_TYPE = {
    [1] = 4,  -- Warrior: Plate
    [2] = 4,  -- Paladin: Plate
    [3] = 3,  -- Hunter: Mail
    [4] = 2,  -- Rogue: Leather
    [5] = 1,  -- Priest: Cloth
    [6] = 4,  -- DK: Plate
    [7] = 3,  -- Shaman: Mail
    [8] = 1,  -- Mage: Cloth
    [9] = 1,  -- Warlock: Cloth
    [10] = 2, -- Monk: Leather
    [11] = 2, -- Druid: Leather
    [12] = 2, -- DH: Leather
    [13] = 3, -- Evoker: Mail
}

local CLASS_WEAPON_TYPES = {
    [1] = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [18] = true }, -- Warrior
    [2] = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },                                                                             -- Paladin
    [3] = { [0] = true, [1] = true, [2] = true, [3] = true, [6] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true, [18] = true },                         -- Hunter
    [4] = { [0] = true, [4] = true, [7] = true, [13] = true, [15] = true, [2] = true, [3] = true, [18] = true },                                                              -- Rogue
    [5] = { [4] = true, [10] = true, [15] = true, [19] = true },                                                                                                              -- Priest
    [6] = { [0] = true, [1] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true },                                                                             -- DK
    [7] = { [0] = true, [1] = true, [4] = true, [5] = true, [10] = true, [13] = true, [15] = true },                                                                          -- Shaman
    [8] = { [7] = true, [10] = true, [15] = true, [19] = true },                                                                                                              -- Mage
    [9] = { [7] = true, [10] = true, [15] = true, [19] = true },                                                                                                              -- Warlock
    [10] = { [0] = true, [4] = true, [6] = true, [7] = true, [10] = true, [13] = true },                                                                                      -- Monk
    [11] = { [4] = true, [5] = true, [6] = true, [10] = true, [13] = true, [15] = true },                                                                                     -- Druid
    [12] = { [0] = true, [7] = true, [9] = true, [13] = true, [15] = true },                                                                                                  -- DH
    [13] = { [0] = true, [1] = true, [4] = true, [5] = true, [7] = true, [8] = true, [10] = true, [13] = true, [15] = true },                                                 -- Evoker
}

local _, _, PLAYER_CLASS_ID = UnitClass("player")


--- Ensures the encounter journal is setup for scanning. If the filters are not supplied, all items will be returned.
---@param classID_filter number|nil
---@param specID_filter number|nil
local function PrepareEncounterJournal(classID_filter, specID_filter)
    if not IsAddOnLoaded("Blizzard_EncounterJournal") then
        LoadAddon("Blizzard_EncounterJournal")
    end
    EJ_SetLootFilter(classID_filter or PLAYER_CLASS_ID, specID_filter or 0)
end

local function CleanString(str)
    return string.lower(string.gsub(str, "[^%w]", ""))
end

-- Tokenize a name into lowercase words, keeping only letters/numbers and spaces.
local function TokenizeName(name)
    if not name then return {} end
    name = string.lower(name)
    name = string.gsub(name, "[^%w%s]", " ")
    local tokens = {}
    for token in string.gmatch(name, "%S+") do
        tokens[token] = true
    end
    return tokens
end

-- Compute a simple similarity score between two names based on
-- shared word tokens and common prefix length of the cleaned strings.
local function ComputeNameSimilarity(a, b)
    if not a or not b then return 0 end

    local tokensA = TokenizeName(a)
    local tokensB = TokenizeName(b)
    local sharedTokens = 0
    for token in pairs(tokensA) do
        if tokensB[token] then
            sharedTokens = sharedTokens + 1
        end
    end

    local ca = CleanString(a)
    local cb = CleanString(b)
    local maxLen = math.min(#ca, #cb)
    local prefixLen = 0
    for i = 1, maxLen do
        if string.sub(ca, i, i) == string.sub(cb, i, i) then
            prefixLen = prefixLen + 1
        else
            break
        end
    end

    -- Weight shared tokens strongly, then break ties by prefix length.
    return sharedTokens * 10 + prefixLen
end

-- Find the "best match" EJ instance name for a given source name using
-- fuzzy comparison against a set of candidate names.
local function FindBestMatchingInstanceName(sourceName, candidateNames)
    local bestName
    local bestScore = 0
    for name in pairs(candidateNames) do
        local score = ComputeNameSimilarity(sourceName, name)
        if score > bestScore then
            bestScore = score
            bestName = name
        end
    end

    -- Require at least some similarity to avoid wildly incorrect matches.
    if bestScore > 0 then
        return bestName
    end
    return nil
end


local function IsItemUsableByPlayer(itemClassID, itemSubClassID, itemEquipLoc)
    if not itemClassID or not itemSubClassID then
        return true
    end

    if itemEquipLoc and itemEquipLoc ~= "" then
        return true
    end

    return false
end


---@param currentInstances table<string, boolean>
---@return BestInSlotLootCache
local function FindRewards(currentInstances)
    local numTiers = EJ_GetNumTiers()
    local processedInstances = {}

    local newInstanceLootCache = {}

    local function ProcessInstance(isRaid)
        local index = 1
        while true do
            local instanceID, instanceName = EJ_GetInstanceByIndex(index, isRaid)
            if not instanceID then
                break
            end

            if not currentInstances[instanceName] then
                -- Not in current rotation; skip but keep scanning.
                index = index + 1
            elseif processedInstances[instanceID] then
                -- Already processed this instance (e.g., seen via a different tier flag).
                index = index + 1
            else
                processedInstances[instanceID] = true

                if not newInstanceLootCache[instanceName] then
                    newInstanceLootCache[instanceName] = {}
                end
                local instanceItems = newInstanceLootCache[instanceName]
                local seenInInstance = {}

                -- Select the instance once before building encounters.
                EJ_SelectInstance(instanceID)

                -- 1) Build a stable list of encounters for this instance.
                local encounters = {}
                local encounterIndex = 1
                while true do
                    -- Ensure the correct instance is selected while iterating.
                    EJ_SelectInstance(instanceID)

                    local name, _, journalEncounterID =
                        EJ_GetEncounterInfoByIndex(encounterIndex)
                    if not name then
                        break
                    end

                    table.insert(encounters, {
                        name = name,
                        id = journalEncounterID,
                    })

                    encounterIndex = encounterIndex + 1
                end

                -- 2) Process loot for each encounter and difficulty.
                local difficulties = isRaid and { 16, 15, 14, 17 } or { 23, 8 }

                for _, enc in ipairs(encounters) do
                    for _, difficulty in ipairs(difficulties) do
                        EJ_SetDifficulty(difficulty)
                        EJ_SelectInstance(instanceID)
                        EJ_SelectEncounter(enc.id)

                        local numLoot = EJ_GetNumLoot()
                        for i = 1, numLoot do
                            local item = GetLootInfoByIndex(i)

                            if item and not seenInInstance[item.itemID] then
                                seenInInstance[item.itemID] = true

                                local _, _, _, itemEquipLoc, _, itemClassID, itemSubClassID =
                                    C_Item.GetItemInfoInstant(item.itemID)

                                if IsItemUsableByPlayer(itemClassID, itemSubClassID, itemEquipLoc) then
                                    table.insert(instanceItems, item.itemID)
                                end
                            end
                        end
                    end
                end

                index = index + 1
            end
        end
    end

    for t = numTiers, 1, -1 do
        EJ_SelectTier(t)
        ProcessInstance(false) -- dungeons
        ProcessInstance(true)  -- raids
    end

    -- Tier set handling remains the same.
    if not IsAddOnLoaded("Blizzard_LootJournal") then
        LoadAddon("Blizzard_LootJournal")
    end

    local _, _, classID = UnitClass("player")
    local specID = GetSpecializationInfo(GetSpecialization())
    if classID and specID then
        local itemSets = GetItemSets(classID, specID)
        if itemSets then
            for _, set in ipairs(itemSets) do
                local setItems = GetItemSetItems(set.setID)
                if setItems then
                    for _, item in ipairs(setItems) do
                        if not newInstanceLootCache["Tier Sets"] then
                            newInstanceLootCache["Tier Sets"] = {}
                        end

                        local alreadyInList = false
                        for _, id in ipairs(newInstanceLootCache["Tier Sets"]) do
                            if id == item.itemID then
                                alreadyInList = true
                                break
                            end
                        end

                        if not alreadyInList then
                            table.insert(newInstanceLootCache["Tier Sets"], item.itemID)
                        end
                    end
                end
            end
        end
    end

    ---@class BestInSlotLootCache
    local t = {
        InstanceLoot = newInstanceLootCache,
    }
    return t
end


local function FindCurrentInstances()
    local currentInstances = {}

    -- current raids
    EJ_SelectTier(EJ_GetCurrentTier())
    local index = 1
    while true do
        local instanceID, instanceName = EJ_GetInstanceByIndex(index, true)

        if not instanceID then break end
        currentInstances[instanceName] = true
        index = index + 1
    end

    -- current dungeons (all expansion dungeons, not just M+)
    index = 1
    while true do
        local instanceID, instanceName = EJ_GetInstanceByIndex(index, false)

        if not instanceID then break end
        currentInstances[instanceName] = true
        index = index + 1
    end

    -- Build a list of all EJ instance names across all tiers so we can
    -- best-match Mythic+ names (which may be split wings) back to their
    -- parent Encounter Journal instance, e.g. Tazavesh wings ->
    -- "Tazavesh, the Veiled Market".
    local allInstanceNames = {}
    local numTiers = EJ_GetNumTiers()
    for t = 1, numTiers do
        EJ_SelectTier(t)
        for _, isRaid in ipairs({ false, true }) do
            local idx = 1
            while true do
                local _, instanceName = EJ_GetInstanceByIndex(idx, isRaid)
                if not instanceName then break end
                allInstanceNames[instanceName] = true
                idx = idx + 1
            end
        end
    end

    -- current M+ dungeons (may include old dungeons)
    local mythicPlusMapIDs = GetMapTable()
    for _, mapID in ipairs(mythicPlusMapIDs) do
        local name = GetMapUIInfo(mapID)
        if name then
            local bestMatch = FindBestMatchingInstanceName(name, allInstanceNames)
            if bestMatch then
                -- Flag the best-matching EJ instance name as current so
                -- mega-dungeons are picked up correctly.
                currentInstances[bestMatch] = true
            else
                -- Fallback to the raw challenge mode name (original behavior).
                currentInstances[name] = true
            end
        end
    end

    return currentInstances
end

local function GetGameVersion()
    return select(1, GetBuildInfo())
end

function ItemScanner.Scan()
    T:Print("Scanning Encounter Journal for rewards. This may take a moment and can cause a brief performance loss.")
    PrepareEncounterJournal()
    local currentInstances = FindCurrentInstances()
    local rewards = FindRewards(currentInstances)
    BIS.GetCharacterBISDB().LootCache = rewards
    BIS.GetCharacterBISDB().CacheGameVersion = GetGameVersion()
    T:Print("Scan complete.")
end

--- @return boolean requiresRefresh
function ItemScanner.DoesCacheRequireRefresh()
    return not BIS.GetCharacterBISDB().LootCache or BIS.GetCharacterBISDB().CacheGameVersion ~= GetGameVersion()
end

---@return boolean isOwned
---@return boolean isEquipped
---@return number|nil itemLevel
---@return string|nil itemLink
---@return number|nil track
function ItemScanner.PlayerOwnsItem(itemID)
    -- first check currently equipped items
    for i = 1, 19 do
        local iItemID = GetInventoryItemID("player", i)
        if iItemID == itemID then
            -- grabbing the link so the addon displays the exact item the player has
            local link = GetInventoryItemLink("player", i)
            local itemLevel = C_Item.GetDetailedItemLevelInfo(link)
            local track, cur, max = ItemScanner.GetTrackFromEquippedItem(i)
            local trackRank = ItemScanner.GetGearTrackRank(track)
            return true, true, itemLevel, link, trackRank
        end
    end

    -- check all bag slots
    for bag = 0, 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local iItemID = C_Container.GetContainerItemID(bag, slot)
            if iItemID == itemID then
                local link = C_Container.GetContainerItemLink(bag, slot)
                local itemLevel = C_Item.GetDetailedItemLevelInfo(link)
                local track, curr, max = ItemScanner.GetTrackFromBagItem(bag, slot)
                local trackRank = ItemScanner.GetGearTrackRank(track)
                return true, false, itemLevel, link, trackRank
            end
        end
    end

    return false, false, nil, nil, nil
end

local function ParseTipData(tipData)
    if not tipData or not tipData.lines then return end

    for _, line in ipairs(tipData.lines) do
        local text = line.leftText or line.rightText
        if text then
            local track, cur, max = text:match(":%s*(%S+)%s+(%d+)%/(%d+)$")
            if not track then
                track, cur, max = text:match("(%S+)%s+(%d+)%/(%d+)$")
            end

            if track and cur and max then
                return track, tonumber(cur), tonumber(max)
            end
        end
    end
end

---@return string track
---@return number currentStage
---@return number maximumStage
function ItemScanner.GetTrackFromEquippedItem(slot)
    local tipData = C_TooltipInfo.GetInventoryItem("player", slot)
    return ParseTipData(tipData)
end

---@return string track
---@return number currentStage
---@return number maximumStage
function ItemScanner.GetTrackFromBagItem(bag, slot)
    local tipData = C_TooltipInfo.GetBagItem(bag, slot)
    return ParseTipData(tipData)
end

---@param link string
---@return string track
---@return number currentStage
---@return number maximumStage
function ItemScanner.GetTrackFromLink(link)
    if type(link) ~= "string" or link == "" then return end
    if not C_TooltipInfo or type(C_TooltipInfo.GetHyperlink) ~= "function" then return end

    local tipData = C_TooltipInfo.GetHyperlink(link)
    return ParseTipData(tipData)
end

ItemScanner.GearTracks = {
    EXPLORER = 1,
    ADVENTURER = 2,
    VETERAN = 3,
    CHAMPTION = 4,
    HERO = 5,
    MYTH = 6,
}

function ItemScanner.GetGearTrackByRank(rank)
    for trackName, trackRank in pairs(ItemScanner.GearTracks) do
        if trackRank == rank then
            return trackName
        end
    end
    return nil
end

function ItemScanner.GetGearTrackRank(trackName)
    if not trackName then return nil end
    if not ItemScanner.GearTracks[trackName:upper()] then return nil end
    return ItemScanner.GearTracks[trackName:upper()]
end
