--[[
    LFG Finder Core - Data Fetching, Filtering, and Sorting
    Handles all backend logic for group finder functionality
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
local LFG = T:GetModule("LFGFinder")

local C_LFGList = _G.C_LFGList or {}
local table = _G.table
local wipe = _G.wipe
local type = _G.type
local tonumber = _G.tonumber
local ipairs = _G.ipairs
local pairs = _G.pairs
local next = _G.next
local math = _G.math
local format = _G.format
local strlower = _G.strlower

local LISTING_CATEGORY_ID = {
    QUESTING = 1,
    DUNGEON = 2,
    RAID = 3,
    ARENA = 4,
    CUSTOM = 6,
    RATED_BATTLEGROUND = 9,
    CLASSIC_RAID = 114,
    DELVES = 121,
}

local function GetListingMode(activityInfo)
    if not activityInfo then
        return "generic"
    end

    local fullName = strlower(activityInfo.fullName or "")
    local shortName = strlower(activityInfo.shortName or "")
    local activityText = fullName .. " " .. shortName
    local maxPlayers = tonumber(activityInfo.maxNumPlayers or activityInfo.maxPlayers) or 0
    local categoryID = tonumber(activityInfo.categoryID or activityInfo.groupFinderCategoryID or activityInfo.category) or 0

    if activityInfo.isMythicPlusActivity then
        return "mythic_plus"
    elseif activityInfo.isRatedPvpActivity then
        return "rated_pvp"
    elseif activityInfo.isPvpActivity then
        return "pvp"
    elseif activityInfo.isCurrentRaidActivity then
        return "raid"
    elseif categoryID == LISTING_CATEGORY_ID.CLASSIC_RAID then
        return "legacy_raid"
    elseif categoryID == LISTING_CATEGORY_ID.DELVES then
        return "delve"
    elseif categoryID == LISTING_CATEGORY_ID.QUESTING then
        return "open_world"
    elseif activityText:find("legacy", 1, true) and activityText:find("raid", 1, true) then
        return "legacy_raid"
    elseif activityText:find("delve", 1, true) then
        return "delve"
    elseif activityText:find("world", 1, true) or activityText:find("outdoor", 1, true) then
        return "open_world"
    elseif maxPlayers > 0 and maxPlayers <= 5 then
        if activityText:find("mythic", 1, true) or activityText:find("heroic", 1, true) or activityText:find("normal", 1, true) then
            return "dungeon"
        end
    end

    return "generic"
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Data Fetching
-- ──────────────────────────────────────────────────────────────────────────────

--- Fetches and rebuilds the search results array
function LFG:RefreshSearchResultsImpl()
    self.searchResults = self.searchResults or {}
    wipe(self.searchResults)
    
    -- Get result IDs from Blizzard's LFG API
    local firstReturn, secondReturn = C_LFGList.GetSearchResults()
    local resultIDs = (type(firstReturn) == "table" and firstReturn) or secondReturn
    
    if not resultIDs then
        return
    end
    
    for _, searchResultID in ipairs(resultIDs) do
        local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
        if resultInfo then
            local activityInfo = resultInfo.activityID and C_LFGList.GetActivityInfoTable(resultInfo.activityID) or nil
            local listingMode = GetListingMode(activityInfo)
            local isMythicPlus = (resultInfo.isMythicPlusActivity == true) or (activityInfo and activityInfo.isMythicPlusActivity == true)
            if listingMode == "generic" and isMythicPlus then
                listingMode = "mythic_plus"
            end
            
            -- Build comprehensive result entry
            local result = {
                id = searchResultID,
                name = resultInfo.name or "Unknown Group",
                activityID = resultInfo.activityID,
                activityName = activityInfo and activityInfo.fullName or "Unknown Activity",
                mode = listingMode,
                isMythicPlus = isMythicPlus,
                leaderName = resultInfo.leaderName or "Unknown",
                leaderClass = self:GetLeaderClass(searchResultID),
                numMembers = tonumber(resultInfo.numMembers) or 0,
                maxPlayers = self:GetActivityMaxPlayers(resultInfo.activityID),
                age = tonumber(resultInfo.age) or 0,
                rating = tonumber(resultInfo.leaderOverallDungeonScore) or 0,
                voiceChat = resultInfo.voiceChat,
                playStyle = resultInfo.playStyle,
                isCrossFaction = resultInfo.isCrossFaction,
                note = resultInfo.comment or "",
                
                -- Application status
                applicantStatus = self:GetApplicationStatus(searchResultID),
                isApplied = false,
                
                -- Party composition (will be fetched on demand)
                roleCounts = self:GetSearchResultRoleCounts(searchResultID),
                players = {},
            }
            
            -- Check if already applied
            local appStatus = result.applicantStatus
            result.isApplied = appStatus and (appStatus == "applied" or appStatus == "invited")
            
            table.insert(self.searchResults, result)
        end
    end
    
    -- Sort results
    self:SortResults()
    
    -- Render if browser mode is active
    if self.displayMode == "browser" and self.RefreshBrowserUIImpl then
        self:RefreshBrowserUIImpl()
    end
end

--- Gets the leader's class from the first party member
function LFG:GetLeaderClass(searchResultID)
    local _, _, classToken = C_LFGList.GetSearchResultPlayerInfo(searchResultID, 1)
    return classToken or "UNKNOWN"
end

--- Gets the role counts for a search result
function LFG:GetSearchResultRoleCounts(searchResultID)
    local counts = {
        TANK = 0,
        HEALER = 0,
        DAMAGER = 0,
    }
    
    local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
    if not resultInfo then return counts end
    
    -- Count members by role from party members
    local numMembers = tonumber(resultInfo.numMembers) or 0
    for i = 1, math.min(numMembers, 5) do
        local role = C_LFGList.GetSearchResultPlayerInfo(searchResultID, i)
        if role == "TANK" or role == "HEALER" or role == "DAMAGER" then
            counts[role] = counts[role] + 1
        end
    end
    
    return counts
end

--- Gets the max players for an activity
function LFG:GetActivityMaxPlayers(activityID)
    if not activityID or not C_LFGList or not C_LFGList.GetActivityInfoTable then
        return 5
    end
    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if activityInfo then
        return tonumber(activityInfo.maxNumPlayers) or 5
    end
    return 5
end

--- Gets the application status for a result
function LFG:GetApplicationStatus(searchResultID)
    local appStatus = C_LFGList.GetApplicationInfo(searchResultID)
    if appStatus == 0 then return "available"
    elseif appStatus == 1 then return "applied"
    elseif appStatus == 2 then return "invited"
    elseif appStatus == 3 then return "declined"
    elseif appStatus == 4 then return "cancelled"
    end
    return "available"
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Filtering
-- ──────────────────────────────────────────────────────────────────────────────

--- Checks if a result passes all active filters
function LFG:ResultPassesFilters(result)
    -- Hide completely full groups
    if result.maxPlayers and result.maxPlayers > 0 and result.numMembers >= result.maxPlayers then
        return false
    end
    
    local filters = self:GetActiveFilters()
    
    -- Activity filter
    if filters.selectedActivities and next(filters.selectedActivities) then
        if not filters.selectedActivities[result.activityName or ""] then
            return false
        end
    end
    
    -- Difficulty filter (M+ specific)
    if filters.difficulty and filters.difficulty ~= "ANY" then
        if filters.difficulty == "MYTHIC_PLUS" then
            local inferredKeystone = self:ExtractKeystoneLevel(result.name)
            local isMPlusResult = (result.mode == "mythic_plus") or (result.isMythicPlus == true) or (inferredKeystone ~= nil)
            if not isMPlusResult then
                return false
            end
        end
        if filters.difficulty ~= "MYTHIC_PLUS" and result.mode == "mythic_plus" then
            return false
        end
    end
    
    -- M+ key range filter
    if result.mode == "mythic_plus" and filters.keyMin and filters.keyMax then
        local keystoneLevel = self:ExtractKeystoneLevel(result.name)
        if keystoneLevel then
            if keystoneLevel < filters.keyMin or keystoneLevel > filters.keyMax then
                return false
            end
        end
    end
    
    -- Hide declined applications
    if filters.hideDeclined and result.applicantStatus == "declined" then
        return false
    end
    
    -- Minimum rating filter
    if filters.minimumRating and result.rating < filters.minimumRating then
        return false
    end
    
    -- Role needs filter
    if filters.needsTank and result.roleCounts.TANK >= 1 then return false end
    if filters.needsHealer and result.roleCounts.HEALER >= 1 then return false end
    if filters.needsDPS and result.roleCounts.DAMAGER >= 5 then return false end
    
    return true
end

--- Gets active filter state
function LFG:GetActiveFilters()
    local options = self:GetOptions()
    if not options then return {} end
    
    return {
        selectedActivities = type(options.GetSelectedActivities) == "function" and options:GetSelectedActivities() or {},
        difficulty         = type(options.GetSelectedDifficulty) == "function" and options:GetSelectedDifficulty() or "ANY",
        keyMin             = type(options.GetMinKeystone) == "function" and options:GetMinKeystone() or 2,
        keyMax             = type(options.GetMaxKeystone) == "function" and options:GetMaxKeystone() or 99,
        hideDeclined       = type(options.GetHideDeclined) == "function" and options:GetHideDeclined() or false,
        minimumRating      = type(options.GetMinimumRating) == "function" and options:GetMinimumRating() or 0,
        needsTank          = type(options.GetNeedsTank) == "function" and options:GetNeedsTank() or false,
        needsHealer        = type(options.GetNeedsHealer) == "function" and options:GetNeedsHealer() or false,
        needsDPS           = type(options.GetNeedsDPS) == "function" and options:GetNeedsDPS() or false,
    }
end

--- Extracts keystones level from group name (e.g. "10 Halls of Infusion")
function LFG:ExtractKeystoneLevel(name)
    if not name then return nil end
    local level = tonumber(name:match("^(%d+)%s"))
    return level
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Sorting
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:SortResults()
    local sortBy = self:GetSortColumn() or "age"
    local isAscending = self:GetSortAscending() ~= false
    
    table.sort(self.searchResults, function(a, b)
        return self:CompareResults(a, b, sortBy, isAscending)
    end)
end

function LFG:GetSortColumn()
    local options = self:GetOptions()
    if options and options.GetSortColumn then
        return options:GetSortColumn()
    end
    return "age"
end

function LFG:GetSortAscending()
    local options = self:GetOptions()
    if options and options.GetSortAscending then
        return options:GetSortAscending()
    end
    return false
end

--- Comparator for sorting results
function LFG:CompareResults(a, b, sortBy, isAscending)
    local valA, valB
    
    if sortBy == "dungeon" then
        valA = a.activityName or ""
        valB = b.activityName or ""
    elseif sortBy == "leader" then
        valA = a.leaderName or ""
        valB = b.leaderName or ""
    elseif sortBy == "class" then
        valA = a.leaderClass or ""
        valB = b.leaderClass or ""
    elseif sortBy == "rating" then
        valA = tonumber(a.rating) or 0
        valB = tonumber(b.rating) or 0
    elseif sortBy == "composition" then
        -- Sort by tank count, healer count, dps count
        local aComp = (a.roleCounts.TANK or 0) * 100 + (a.roleCounts.HEALER or 0) * 10 + (a.roleCounts.DAMAGER or 0)
        local bComp = (b.roleCounts.TANK or 0) * 100 + (b.roleCounts.HEALER or 0) * 10 + (b.roleCounts.DAMAGER or 0)
        valA = aComp
        valB = bComp
    else -- default: age
        valA = tonumber(a.age) or 0
        valB = tonumber(b.age) or 0
    end
    
    if valA ~= valB then
        if isAscending then
            return valA < valB
        else
            return valA > valB
        end
    end
    
    -- Tiebreaker: applied groups first
    local aPriority = a.isApplied and 2 or 1
    local bPriority = b.isApplied and 2 or 1
    if aPriority ~= bPriority then
        return aPriority > bPriority
    end
    
    -- Secondary tiebreaker by rating
    if a.rating ~= b.rating then
        return a.rating > b.rating
    end
    
    return a.id < b.id
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Applicant List Functions
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:RefreshApplicantListImpl()
    wipe(self.searchResults)
    
    -- Get all applicants to your current listing
    local numApplicants = C_LFGList.GetNumApplications()
    
    for i = 1, numApplicants do
        local result = C_LFGList.GetApplicationInfo(i)
        if result then
            table.insert(self.searchResults, result)
        end
    end
    
    self:SortResults()
    
    if self.RefreshApplicantUIImpl then
        self:RefreshApplicantUIImpl()
    end
end
