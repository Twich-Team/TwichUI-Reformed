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
local strsplit = _G.strsplit
local securecallfunction = _G.securecallfunction
local C_Timer = _G.C_Timer

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
    local categoryID = tonumber(activityInfo.categoryID or activityInfo.groupFinderCategoryID or activityInfo.category) or
    0

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

local function GetSearchResultActivityID(resultInfo, searchResultID)
    if not resultInfo then
        return nil
    end

    local activityID = tonumber(resultInfo.activityID)
    if not activityID and searchResultID and _G.securecallfunction and C_LFGList.GetSearchResultInfo then
        activityID = securecallfunction(function(resultID)
            local secureResultInfo = C_LFGList.GetSearchResultInfo(resultID)
            if not secureResultInfo then return nil end
            return tonumber(secureResultInfo.activityID)
        end, searchResultID)
    end

    if activityID == 0 then
        activityID = nil
    end

    return activityID
end

local function GetSafeStringField(source, key)
    if not source then
        return ""
    end

    if _G.securecallfunction then
        local value = securecallfunction(function(obj, field)
            return obj[field]
        end, source, key)
        if type(value) == "string" then
            return value
        end
        if value == nil then
            return ""
        end
        local converted = tonumber(value)
        if converted then
            return tostring(converted)
        end
        return ""
    end

    local value = source[key]
    if type(value) == "string" then
        return value
    end
    if value == nil then
        return ""
    end
    local converted = tonumber(value)
    if converted then
        return tostring(converted)
    end
    return ""
end

local function ParseResultKeyLevel(resultInfo, activityInfo)
    local combined = GetSafeStringField(activityInfo, "shortName") .. " "
        .. GetSafeStringField(activityInfo, "fullName")
    local lowerText = strlower(combined)

    local plusLevel = lowerText:match("%+(%d%d?)")
    if plusLevel then
        return tonumber(plusLevel) or 0
    end

    local leadingLevel = lowerText:match("^%s*%+?(%d%d?)%s")
    if leadingLevel then
        return tonumber(leadingLevel) or 0
    end

    return 0
end

local function BuildResultDisplayName(resultInfo, activityInfo, keyLevel)
    local rawName = ""
    rawName = rawName:gsub("^%s+", ""):gsub("%s+$", "")

    local activityLabel = GetSafeStringField(activityInfo, "fullName")
    if activityLabel == "" then
        activityLabel = GetSafeStringField(activityInfo, "shortName")
    end

    if rawName == "" then
        if keyLevel > 0 and activityLabel ~= "" then
            return string.format("+%d %s", keyLevel, activityLabel)
        end

        return activityLabel ~= "" and activityLabel or "--"
    end

    local digitsOnly = rawName:match("^%+?(%d%d?)$")
    if digitsOnly then
        if activityLabel ~= "" then
            return string.format("+%s %s", digitsOnly, activityLabel)
        end

        return "+" .. digitsOnly
    end

    return rawName
end

local function CleanActivityLabel(label)
    if type(label) ~= "string" then
        label = ""
    end
    label = label:gsub("%s*%b()", "")
    label = label:gsub("^%s+", ""):gsub("%s+$", "")
    return label
end

local function NormalizeRoleToken(rawRole)
    if _G.securecallfunction then
        return securecallfunction(function(v)
            if v == "TANK" then
                return "TANK"
            end
            if v == "HEALER" then
                return "HEALER"
            end
            return "DAMAGER"
        end, rawRole)
    end

    if rawRole == "TANK" then
        return "TANK"
    end
    if rawRole == "HEALER" then
        return "HEALER"
    end
    return "DAMAGER"
end

local function IsRoleToken(value)
    if _G.securecallfunction then
        return securecallfunction(function(v)
            return v == "TANK" or v == "HEALER" or v == "DAMAGER"
        end, value) == true
    end
    return value == "TANK" or value == "HEALER" or value == "DAMAGER"
end

local function GetSearchResultPlayers(searchResultID, numMembers)
    local players = {}
    if not C_LFGList.GetSearchResultPlayerInfo then
        return players
    end

    -- Do not iterate using numMembers because Blizzard can mark it as secret while tainted.
    local MAX_MEMBER_PROBE = 40
    for memberIndex = 1, MAX_MEMBER_PROBE do
            if IsRoleToken(info1) then
        if info1 == nil and info2 == nil and info3 == nil and info4 == nil and info5 == nil then
            break
        end

        local role
        local classFile
        local playerName
        local specID
        local specName

        local playerInfo = (type(info1) == "table") and info1 or nil
        if type(playerInfo) == "table" then
            playerName = playerInfo.name
            classFile = playerInfo.classFilename
            role = playerInfo.assignedRole
            specID = tonumber(playerInfo.specID)
            specName = playerInfo.specName
        else
            if IsRoleToken(info1) then
                role = info1
                playerName = info2
                classFile = info3
                specID = tonumber(info4)
                specName = info5
            else
                playerName = info1
                role = info2
                classFile = info3
                specID = tonumber(info4)
                specName = info5
            end
        end

        if classFile then
            role = NormalizeRoleToken(role)

            table.insert(players, {
                name = playerName,
                role = role,
                class = classFile or "UNKNOWN",
                specID = specID,
                specName = specName,
            })
        end
    end

    return players
end

local function GetSearchResultMemberCounts(searchResultID)
    if not C_LFGList.GetSearchResultMemberCounts then
        return {}
    end

    local success, memberCounts = pcall(C_LFGList.GetSearchResultMemberCounts, searchResultID)
    if success and type(memberCounts) == "table" then
        return memberCounts
    end

    return {}
end

local function GetSearchResultRoleCounts(searchResultID)
    local counts = { TANK = 0, HEALER = 0, DAMAGER = 0 }
    local memberCounts = GetSearchResultMemberCounts(searchResultID)
    counts.TANK = tonumber(memberCounts.TANK) or 0
    counts.HEALER = tonumber(memberCounts.HEALER) or 0
    counts.DAMAGER = tonumber(memberCounts.DAMAGER) or 0

    if counts.TANK == 0 and counts.HEALER == 0 and counts.DAMAGER == 0 then
        local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
        local numMembers = tonumber(resultInfo and resultInfo.numMembers) or 0
        local players = GetSearchResultPlayers(searchResultID, numMembers)
        for _, player in ipairs(players) do
            counts[player.role] = (counts[player.role] or 0) + 1
        end
    end

    return counts
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Data Fetching
-- ──────────────────────────────────────────────────────────────────────────────

function LFG:BuildSearchResultEntry(searchResultID)
    local resultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
    if not resultInfo then
        return nil
    end

    local rawListingTitle = resultInfo.name
    local activityID = GetSearchResultActivityID(resultInfo, searchResultID)
    local activityInfo = activityID and C_LFGList.GetActivityInfoTable(activityID) or nil
    local listingMode = GetListingMode(activityInfo)
    local isMythicPlus = (resultInfo.isMythicPlusActivity == true) or
        (activityInfo and activityInfo.isMythicPlusActivity == true)
    if listingMode == "generic" and isMythicPlus then
        listingMode = "mythic_plus"
    end

    local keyLevel = ParseResultKeyLevel(resultInfo, activityInfo)
    local displayName = BuildResultDisplayName(resultInfo, activityInfo, keyLevel)
    local activityLabelSource = GetSafeStringField(activityInfo, "fullName")
    if activityLabelSource == "" then
        activityLabelSource = GetSafeStringField(activityInfo, "shortName")
    end
    local activityLabel = CleanActivityLabel(activityLabelSource)
    if activityLabel == "" then
        activityLabel = "Unknown Activity"
    end

    local players = GetSearchResultPlayers(searchResultID, tonumber(resultInfo.numMembers) or 0)
    local roleCounts = GetSearchResultRoleCounts(searchResultID)
    local leaderClass = players[1] and players[1].class or self:GetLeaderClass(searchResultID)
    local leaderRole = players[1] and players[1].role or "DAMAGER"
    local rating = tonumber(resultInfo.leaderOverallDungeonScore) or 0
    local pvpRating = 0
    local pvpBracket

    if listingMode == "rated_pvp" or listingMode == "pvp" then
        local pvpInfo = resultInfo.leaderPvpRatingInfo
        if type(pvpInfo) == "table" then
            local entry = pvpInfo[1] or pvpInfo
            if type(entry) == "table" then
                pvpRating = tonumber(entry.rating or entry.pvpRating or entry.currentRating or entry
                    .seasonRating or entry.weeklyBest or entry.value) or 0
                pvpBracket = entry.bracket or entry.activityName or entry.name
            end
        elseif type(pvpInfo) == "number" then
            pvpRating = pvpInfo
        end
        rating = pvpRating
    end

    local result = {
        id = searchResultID,
        name = activityLabel,
        listingTitle = rawListingTitle,
        displayName = displayName,
        comment = "",
        note = "",
        activityID = activityID,
        activityInfo = activityInfo,
        activityName = (function()
            local full = GetSafeStringField(activityInfo, "fullName")
            if full ~= "" then return full end
            local short = GetSafeStringField(activityInfo, "shortName")
            if short ~= "" then return short end
            return activityLabel
        end)(),
        dungeonName = activityLabel,
        mode = listingMode,
        isMythicPlus = isMythicPlus,
        leaderName = (players[1] and players[1].name) or "",
        leaderClass = leaderClass,
        leaderRole = leaderRole,
        numMembers = tonumber(resultInfo.numMembers) or 0,
        maxPlayers = self:GetActivityMaxPlayers(activityID),
        age = tonumber(resultInfo.age) or 0,
        rating = rating,
        pvpRating = pvpRating,
        pvpBracket = pvpBracket,
        keyLevel = keyLevel,
        voiceChat = resultInfo.voiceChat,
        playStyle = resultInfo.playStyle,
        isCrossFaction = resultInfo.isCrossFaction,

        applicantStatus = self:GetApplicationStatus(searchResultID),
        applicationStatus = self:GetApplicationStatus(searchResultID),
        isApplied = false,
        isDeclined = false,

        roleCounts = roleCounts,
        players = players,
    }

    local appStatus = result.applicantStatus
    result.isApplied = appStatus and (appStatus == "applied" or appStatus == "invited")
    result.isDeclined = appStatus == "declined"

    return result
end

function LFG:CancelSearchBuild()
    if self._searchBuildTicker and type(self._searchBuildTicker.Cancel) == "function" then
        self._searchBuildTicker:Cancel()
    end
    self._searchBuildTicker = nil
    self._searchBuildState = nil
end

--- Fetches and rebuilds the search results array
function LFG:RefreshSearchResultsImpl(showLoading)
    self:CancelSearchBuild()
    self.searchResults = self.searchResults or {}

    -- Get result IDs from Blizzard's LFG API
    local firstReturn, secondReturn = C_LFGList.GetSearchResults()
    local resultIDs = (type(firstReturn) == "table" and firstReturn) or secondReturn

    if not resultIDs then
        if self.SetLoadingProgressImpl then
            self:SetLoadingProgressImpl(0, 0)
        end
        if self.displayMode == "browser" and self.RefreshBrowserUIImpl then
            self:RefreshBrowserUIImpl()
        end
        return
    end

    local total = #resultIDs
    if total <= 0 then
        if self.SetLoadingProgressImpl then
            self:SetLoadingProgressImpl(0, 0)
        end
        if self.displayMode == "browser" and self.RefreshBrowserUIImpl then
            self:RefreshBrowserUIImpl()
        end
        return
    end

    local state = {
        ids = resultIDs,
        index = 1,
        total = total,
        results = {},
    }
    self._searchBuildState = state

    if self.SetLoadingProgressImpl and showLoading then
        self:SetLoadingProgressImpl(0, total)
    elseif self.SetLoadingProgressImpl then
        self:SetLoadingProgressImpl(0, 0)
    end

    local chunkSize = 20
    local function processChunk()
        local active = self._searchBuildState
        if not active then
            return
        end

        local startIndex = active.index
        local endIndex = math.min(active.total, startIndex + chunkSize - 1)
        for idx = startIndex, endIndex do
            local built = self:BuildSearchResultEntry(active.ids[idx])
            if built then
                table.insert(active.results, built)
            end
        end

        active.index = endIndex + 1

        if self.SetLoadingProgressImpl and showLoading then
            self:SetLoadingProgressImpl(endIndex, active.total)
        end

        if active.index > active.total then
            self.searchResults = active.results
            self:SortResults()
            if self.displayMode == "browser" and self.RefreshBrowserUIImpl then
                self:RefreshBrowserUIImpl()
            end
            self:CancelSearchBuild()
            if self.SetLoadingProgressImpl and showLoading then
                self:SetLoadingProgressImpl(active.total, active.total)
            elseif self.SetLoadingProgressImpl then
                self:SetLoadingProgressImpl(0, 0)
            end
        end
    end

    processChunk()
    if self._searchBuildState then
        if C_Timer and C_Timer.NewTicker then
            self._searchBuildTicker = C_Timer.NewTicker(0.02, processChunk)
        else
            -- Fallback: complete synchronously if ticker API is unavailable.
            while self._searchBuildState do
                processChunk()
            end
        end
    end
end

--- Gets the leader's class from the first party member
function LFG:GetLeaderClass(searchResultID)
    local _, _, classToken = C_LFGList.GetSearchResultPlayerInfo(searchResultID, 1)
    return classToken or "UNKNOWN"
end

--- Gets the role counts for a search result
function LFG:GetSearchResultRoleCounts(searchResultID)
    return GetSearchResultRoleCounts(searchResultID)
end

--- Gets the max players for an activity
function LFG:GetActivityMaxPlayers(activityID)
    if not activityID or not C_LFGList or not C_LFGList.GetActivityInfoTable then
        return 5
    end
    local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
    if activityInfo then
        return tonumber(activityInfo.maxNumPlayers or activityInfo.maxPlayers) or 5
    end
    return 5
end

--- Gets the application status for a result
function LFG:GetApplicationStatus(searchResultID)
    if not C_LFGList.GetApplicationInfo then
        return "available"
    end

    local success, appA, appB = pcall(C_LFGList.GetApplicationInfo, searchResultID)
    if success then
        if type(appA) == "table" then
            appA = appA.applicationStatus or appA.status or appA.pendingStatus
        elseif type(appB) == "string" then
            appA = appB
        end

        if appA == 0 or appA == "none" then return "available" end
        if appA == 1 or appA == "applied" then return "applied" end
        if appA == 2 or appA == "invited" then return "invited" end
        if appA == 3 or appA == "declined" then return "declined" end
        if appA == 4 or appA == "cancelled" then return "cancelled" end
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
        local activityKey = result.activityName or ""
        -- If metadata is missing, do not hard-filter the row out.
        if activityKey ~= "" and activityKey ~= "Unknown Activity" and not filters.selectedActivities[activityKey] then
            return false
        end
    end

    -- Difficulty filter (M+ specific)
    if filters.difficulty and filters.difficulty ~= "ANY" then
        if filters.difficulty == "MYTHIC_PLUS" then
            local inferredKeystone = self:ExtractKeystoneLevel(result.name)
            local isMPlusResult = (result.mode == "mythic_plus") or (result.isMythicPlus == true) or
            (inferredKeystone ~= nil)
            -- Unknown mode/metadata should remain visible rather than disappear entirely.
            if not isMPlusResult and result.mode and result.mode ~= "generic" then
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
        difficulty         = type(options.GetSelectedDifficulty) == "function" and options:GetSelectedDifficulty() or
        "ANY",
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
    elseif sortBy == "title" then
        valA = a.displayName or a.name or ""
        valB = b.displayName or b.name or ""
    elseif sortBy == "leader" then
        valA = a.leaderName or ""
        valB = b.leaderName or ""
    elseif sortBy == "class" then
        valA = a.leaderClass or ""
        valB = b.leaderClass or ""
    elseif sortBy == "note" then
        valA = a.note or a.comment or ""
        valB = b.note or b.comment or ""
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
