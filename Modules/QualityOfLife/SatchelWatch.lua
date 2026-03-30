local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class SatchelWatchModule : AceModule, AceEvent-3.0, AceTimer-3.0
local SW = QOL:NewModule("SatchelWatch", "AceEvent-3.0", "AceTimer-3.0")

local AceGUI = LibStub("AceGUI-3.0")
---@type fun(self: table, widgetType: string): any
local CreateWidget = AceGUI.Create

local LFG_SUBTYPE_DUNGEON = 1
local LFG_SUBTYPE_HEROIC = 2
local PVEFrameLoadUI = _G.PVEFrame_LoadUI
local LegacyLoadAddOn = _G.LoadAddOn
local PVEFrameShowFrame = _G.PVEFrame_ShowFrame
local PVEFrameToggleFrame = _G.PVEFrame_ToggleFrame

local function EnsureGroupFinderLoaded()
    if type(PVEFrameLoadUI) == "function" then
        PVEFrameLoadUI()
    end

    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        if type(C_AddOns.IsAddOnLoaded) == "function" then
            if not C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
                C_AddOns.LoadAddOn("Blizzard_GroupFinder")
            end
            if not C_AddOns.IsAddOnLoaded("Blizzard_PVE") then
                C_AddOns.LoadAddOn("Blizzard_PVE")
            end
        else
            C_AddOns.LoadAddOn("Blizzard_GroupFinder")
            C_AddOns.LoadAddOn("Blizzard_PVE")
        end
    elseif type(LegacyLoadAddOn) == "function" then
        LegacyLoadAddOn("Blizzard_GroupFinder")
        LegacyLoadAddOn("Blizzard_PVE")
    end
end

local function OpenGroupFinder(groupType)
    EnsureGroupFinderLoaded()

    local targetFrameName = groupType == "raid" and "RaidFinderFrame" or "LFDParentFrame"
    local targetFrame = _G[targetFrameName]

    if _G.PVEFrame and _G.PVEFrame:IsShown() and type(PVEFrameShowFrame) == "function" then
        PVEFrameShowFrame("GroupFinderFrame", targetFrame or targetFrameName)
        return
    end

    if type(PVEFrameToggleFrame) == "function" then
        PVEFrameToggleFrame("GroupFinderFrame", targetFrame or targetFrameName)
    end
end

local function GetOptionsModule()
    return ConfigurationModule.Options.SatchelWatch
end

local function GetDB()
    return GetOptionsModule():GetSatchelWatchDB()
end

local function GetIgnoredDungeonIDs()
    return GetOptionsModule():GetIgnoredDungeonIDs()
end

local function GetRaidWingIDs()
    EnsureGroupFinderLoaded()

    local raidWingIDs = {}
    local currentExpansionLevel = type(GetAccountExpansionLevel) == "function" and GetAccountExpansionLevel() or nil

    if type(GetNumRFDungeons) ~= "function" or type(GetRFDungeonInfo) ~= "function" then
        return raidWingIDs
    end

    for index = 1, GetNumRFDungeons() do
        local dungeonID = GetRFDungeonInfo(index)
        local expansionLevel

        if type(dungeonID) == "number" then
            _, _, _, _, _, _, _, _, expansionLevel = GetLFGDungeonInfo(dungeonID)
        end

        if type(dungeonID) == "number" and dungeonID > 0 and (not currentExpansionLevel or expansionLevel == currentExpansionLevel) then
            raidWingIDs[dungeonID] = true
        end
    end

    return raidWingIDs
end

local function GetTestRaidWingID()
    local db = GetDB()

    if type(GetNumRFDungeons) ~= "function" or type(GetRFDungeonInfo) ~= "function" then
        return nil
    end

    local firstAvailableDungeonID = nil
    local currentRaidWingIDs = GetRaidWingIDs()

    for index = 1, GetNumRFDungeons() do
        local dungeonID = GetRFDungeonInfo(index)
        if currentRaidWingIDs[dungeonID] then
            firstAvailableDungeonID = firstAvailableDungeonID or dungeonID

            if db["raid_" .. dungeonID] then
                return dungeonID
            end
        end
    end

    return firstAvailableDungeonID
end

local function GetDungeonName(dungeonID)
    return GetLFGDungeonInfo(dungeonID)
end

local function GetDungeonSubtypeAndExpansion(dungeonID)
    local _, _, subtypeID, _, _, _, _, _, expansionLevel = GetLFGDungeonInfo(dungeonID)
    return subtypeID, expansionLevel
end

local function HasSatchelReward(dungeonID)
    for shortageIndex = 1, LFG_ROLE_NUM_SHORTAGE_TYPES do
        local eligible, forTank, forHealer, forDamage, itemCount, money, xp = GetLFGRoleShortageRewards(dungeonID,
            shortageIndex)

        if eligible and (itemCount > 0 or money > 0 or xp > 0) then
            return true, forTank, forHealer, forDamage
        end
    end

    return false, false, false, false
end

local function IsDungeonCompletedForLockout(dungeonID)
    if type(GetLFGDungeonNumEncounters) ~= "function" then
        return false
    end

    local numEncounters, numCompleted = GetLFGDungeonNumEncounters(dungeonID)
    if type(numEncounters) ~= "number" or numEncounters <= 0 then
        return false
    end

    return type(numCompleted) == "number" and numCompleted >= numEncounters
end

local function GetEncounterProgress(dungeonID)
    if type(dungeonID) ~= "number" or dungeonID <= 0 then
        return nil
    end

    if type(GetLFGDungeonNumEncounters) ~= "function" then
        return nil
    end

    local numEncounters, numCompleted = GetLFGDungeonNumEncounters(dungeonID)
    if type(numEncounters) ~= "number" or numEncounters <= 0 then
        return nil
    end

    local progress = {
        numEncounters = numEncounters,
        numCompleted = type(numCompleted) == "number" and numCompleted or 0,
        encounters = {},
    }

    if type(GetLFGDungeonEncounterInfo) == "function" then
        for encounterIndex = 1, numEncounters do
            local bossName, _, isKilled = GetLFGDungeonEncounterInfo(dungeonID, encounterIndex)
            if bossName then
                table.insert(progress.encounters, {
                    name = bossName,
                    isCompleted = isKilled == true,
                })
            end
        end
    end

    return progress
end

local function AddDungeonCandidate(candidates, seenIDs, dungeonID, groupType)
    if type(dungeonID) ~= "number" or dungeonID <= 0 or seenIDs[dungeonID] then
        return
    end

    if groupType ~= "raid" and GetIgnoredDungeonIDs()[dungeonID] then
        return
    end

    local name = GetDungeonName(dungeonID)
    if not name then
        return
    end

    seenIDs[dungeonID] = true
    table.insert(candidates, {
        dungeonID = dungeonID,
        dungeonName = name,
        groupType = groupType,
    })
end

local function GetDungeonCandidates(db)
    local candidates = {}
    local seenIDs = {}
    local raidWingIDs = GetRaidWingIDs()

    if db.notifyForRegularDungeon or db.notifyForHeroicDungeon then
        for dungeonID = 1, 10000 do
            if not raidWingIDs[dungeonID] and IsLFGDungeonJoinable(dungeonID) then
                local subtypeID = GetDungeonSubtypeAndExpansion(dungeonID)

                if db.notifyForRegularDungeon and subtypeID == LFG_SUBTYPE_DUNGEON then
                    AddDungeonCandidate(candidates, seenIDs, dungeonID, "dungeon")
                elseif db.notifyForHeroicDungeon and subtypeID == LFG_SUBTYPE_HEROIC then
                    AddDungeonCandidate(candidates, seenIDs, dungeonID, "heroic")
                end
            end
        end
    end

    if db.notifyOnlyForRaids then
        for dungeonID in pairs(raidWingIDs) do
            if db["raid_" .. dungeonID] then
                AddDungeonCandidate(candidates, seenIDs, dungeonID, "raid")
            end
        end
    end

    return candidates
end

local function GetWatchedRoleLabels(forTank, forHealer, forDamage, db)
    local roles = {}

    if forTank and db.notifyForTanks then
        table.insert(roles, "Tank")
    end

    if forHealer and db.notifyForHealers then
        table.insert(roles, "Healer")
    end

    if forDamage and db.notifyForDPS then
        table.insert(roles, "DPS")
    end

    return roles
end

local function QueueForDungeon(dungeonID, groupType)
    if type(dungeonID) ~= "number" or dungeonID <= 0 then
        return
    end

    EnsureGroupFinderLoaded()
    OpenGroupFinder(groupType)

    if groupType == "raid" then
        ClearAllLFGDungeons(LE_LFG_CATEGORY_RF)
        SetLFGDungeon(LE_LFG_CATEGORY_RF, dungeonID)
        JoinSingleLFG(LE_LFG_CATEGORY_RF, dungeonID)
        return
    end

    ClearAllLFGDungeons(LE_LFG_CATEGORY_LFD)
    SetLFGDungeon(LE_LFG_CATEGORY_LFD, dungeonID)
    JoinLFG(LE_LFG_CATEGORY_LFD)
end

local function IsPlayerInInstance()
    if type(IsInInstance) ~= "function" then
        return false
    end

    local inInstance = IsInInstance()
    return inInstance == true
end

local function HasWatchedRoles(db)
    return db.notifyForTanks == true or db.notifyForHealers == true or db.notifyForDPS == true
end

local function HasMonitoringTargets(db)
    return db.notifyForRegularDungeon == true or db.notifyForHeroicDungeon == true or db.notifyOnlyForRaids == true
end

local function HasScannableCandidates(db)
    local candidates = GetDungeonCandidates(db)
    if #candidates == 0 then
        return false
    end

    if not db.notifyOnlyWhenNotCompleted then
        return true
    end

    for _, candidate in ipairs(candidates) do
        if not IsDungeonCompletedForLockout(candidate.dungeonID) then
            return true
        end
    end

    return false
end

function SW:ShouldUsePeriodicRefresh()
    if not self:IsEnabled() then
        return false
    end

    local options = GetOptionsModule()
    if not options or not options:GetEnabled() or not options:GetPeriodicCheckEnabled() then
        return false
    end

    local db = options:GetSatchelWatchDB()
    if not db then
        return false
    end

    if db.notifyOnlyWhenNotInGroup and IsInGroup() then
        return false
    end

    if not HasWatchedRoles(db) then
        return false
    end

    if not HasMonitoringTargets(db) then
        return false
    end

    if not HasScannableCandidates(db) then
        return false
    end

    return true
end

function SW:StartPeriodicRefresh()
    self:StopPeriodicRefresh()

    if not self:ShouldUsePeriodicRefresh() then
        return
    end

    local options = GetOptionsModule()
    local intervalSeconds = options:GetPeriodicCheckInterval()
    self.periodicRefreshTimer = self:ScheduleRepeatingTimer("RefreshAvailability", intervalSeconds, false)
end

function SW:StopPeriodicRefresh()
    if self.periodicRefreshTimer then
        self:CancelTimer(self.periodicRefreshTimer)
        self.periodicRefreshTimer = nil
    end
end

function SW:RefreshAvailability(forceNotify)
    EnsureGroupFinderLoaded()
    self.notifyOnNextScan = forceNotify == true or self.notifyOnNextScan == true
    RequestLFDPlayerLockInfo()
end

function SW:OnEnable()
    EnsureGroupFinderLoaded()

    self.activeSatchels = self.activeSatchels or {}
    self.notifyOnNextScan = true
    self.wasInGroup = IsInGroup() == true
    self.wasInInstance = IsPlayerInInstance()

    self:RegisterEvent("LFG_UPDATE_RANDOM_INFO")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:StartPeriodicRefresh()
    RequestLFDPlayerLockInfo()
end

function SW:OnDisable()
    self.activeSatchels = {}
    self.notifyOnNextScan = false
    self:StopPeriodicRefresh()
    self:UnregisterAllEvents()
end

function SW:PLAYER_ENTERING_WORLD()
    local isInGroup = IsInGroup() == true
    local isInInstance = IsPlayerInInstance()

    self.wasInGroup = isInGroup
    self.wasInInstance = isInInstance

    self:StartPeriodicRefresh()
    self:RefreshAvailability(true)
end

function SW:GROUP_ROSTER_UPDATE()
    local isInGroup = IsInGroup() == true
    local leftGroup = self.wasInGroup == true and isInGroup == false

    self.wasInGroup = isInGroup
    self.wasInInstance = IsPlayerInInstance()

    self:StartPeriodicRefresh()

    if leftGroup then
        self:RefreshAvailability(true)
    end
end

function SW:LFG_UPDATE_RANDOM_INFO()
    self:ScanForSatchels(self.notifyOnNextScan)
    self.notifyOnNextScan = false
end

function SW:ScanForSatchels(forceNotify)
    EnsureGroupFinderLoaded()

    if not self:IsEnabled() then
        return
    end

    local options = GetOptionsModule()
    if not options:GetEnabled() then
        self.activeSatchels = {}
        self:StartPeriodicRefresh()
        return
    end

    local db = options:GetSatchelWatchDB()
    local activeSatchels = {}
    local foundSatchel = false

    if db.notifyOnlyWhenNotInGroup and IsInGroup() then
        self.activeSatchels = {}
        self.lastScanFoundSatchel = false
        self:StartPeriodicRefresh()
        return
    end

    for _, candidate in ipairs(GetDungeonCandidates(db)) do
        if not db.notifyOnlyWhenNotCompleted or not IsDungeonCompletedForLockout(candidate.dungeonID) then
            local hasReward, forTank, forHealer, forDamage = HasSatchelReward(candidate.dungeonID)
            if hasReward then
                local watchedRoles = GetWatchedRoleLabels(forTank, forHealer, forDamage, db)

                if #watchedRoles > 0 then
                    foundSatchel = true
                    activeSatchels[candidate.dungeonID] = true

                    if forceNotify or not self.activeSatchels[candidate.dungeonID] then
                        self:SendNotification(candidate.dungeonName, watchedRoles, candidate.groupType,
                            candidate.dungeonID)
                    end
                end
            end
        end
    end

    self.activeSatchels = activeSatchels
    self.lastScanFoundSatchel = foundSatchel
    self:StartPeriodicRefresh()
end

function SW:StopMonitoringDungeon(dungeonID, groupType)
    local db = GetDB()

    if groupType == "raid" then
        db["raid_" .. dungeonID] = false
    else
        local ignoredDungeonIDs = GetIgnoredDungeonIDs()
        ignoredDungeonIDs[dungeonID] = true
    end

    self.activeSatchels[dungeonID] = nil
    self:StartPeriodicRefresh()
    self:ScanForSatchels(false)
end

function SW:QueueForDungeon(dungeonID, groupType)
    QueueForDungeon(dungeonID, groupType)
end

function SW:SendNotification(dungeonName, roles, groupType, dungeonID)
    local groupLabels = {
        dungeon = "Dungeon Finder",
        heroic = "Heroic Dungeon Finder",
        raid = "Raid Finder",
    }
    local groupLabel = groupLabels[groupType] or "Group Finder"

    ---@type TwichUI_SatchelNotificationWidget
    ---@diagnostic disable-next-line: param-type-mismatch
    local message = CreateWidget(AceGUI, "TwichUI_SatchelNotification")
    ---@diagnostic disable-next-line: undefined-field
    message:SetRoleIconType(GetDB().roleIconType)
    ---@diagnostic disable-next-line: undefined-field
    message:SetNotification(dungeonName, roles, groupLabel)
    if groupType == "raid" then
        ---@diagnostic disable-next-line: undefined-field
        message:SetEncounterProgress(GetEncounterProgress(dungeonID))
    else
        ---@diagnostic disable-next-line: undefined-field
        message:SetEncounterProgress(nil)
    end
    if type(dungeonID) == "number" and dungeonID > 0 then
        ---@diagnostic disable-next-line: undefined-field
        message:SetQueueCallback(function()
            self:QueueForDungeon(dungeonID, groupType)
        end)
        ---@diagnostic disable-next-line: undefined-field
        message:SetIgnoreCallback(function()
            self:StopMonitoringDungeon(dungeonID, groupType)
        end)
    else
        ---@diagnostic disable-next-line: undefined-field
        message:SetQueueCallback(nil)
        ---@diagnostic disable-next-line: undefined-field
        message:SetIgnoreCallback(nil)
    end

    local options = GetOptionsModule()
    local db = options:GetSatchelWatchDB()
    local soundKey = db.sound or "TwichUI Alert 2"
    local displayDuration = db.notificationDisplayTime or 10

    self:SendMessage("TWICH_NOTIFICATION", message, { soundKey = soundKey, displayDuration = displayDuration })
end

function SW:TestNotification()
    local dungeonID = GetTestRaidWingID()
    if dungeonID then
        local dungeonName = GetDungeonName(dungeonID) or "Test Raid Wing"
        self:SendNotification(dungeonName, { "Tank", "Healer", "DPS" }, "raid", dungeonID)
        return
    end

    self:SendNotification("Test Raid Wing", { "Tank", "Healer", "DPS" }, "raid", nil)
end
