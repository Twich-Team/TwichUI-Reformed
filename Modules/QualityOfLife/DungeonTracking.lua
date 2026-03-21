---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class DungeonTrackingModule : AceModule, AceEvent-3.0
---@field activeRun table|nil
local DT = QOL:NewModule("DungeonTracking", "AceEvent-3.0")

local AceGUI = LibStub("AceGUI-3.0")
---@type fun(self: table, widgetType: string): any
local CreateWidget = AceGUI.Create

local C_Timer_After = C_Timer and C_Timer.After
local ChallengeModeActive = C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
local ChallengeModeGetOverallDungeonScore = C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore
local MythicPlusGetSeasonBestForMap = C_MythicPlus and C_MythicPlus.GetSeasonBestForMap
local PlayerMythicPlusRatingSummary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary
local GetInstanceInfo = GetInstanceInfo
local GetTime = GetTime
local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local IsInGroup = IsInGroup
local LegacyLeaveParty = rawget(_G, "LeaveParty")
local SendChat = rawget(_G, "SendChatMessage")
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGroupRolesAssigned = UnitGroupRolesAssigned

local function GetOptions()
    return ConfigurationModule.Options.DungeonTracking
end

local function TrimText(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

local function IsChallengeRunActive()
    return type(ChallengeModeActive) == "function" and ChallengeModeActive() == true
end

local function GetNotificationIconStyle()
    local options = GetOptions()
    return options and options.GetClassIconStyle and options:GetClassIconStyle() or "default"
end

local function GetRatingSummary()
    if type(PlayerMythicPlusRatingSummary) == "function" then
        local summary = PlayerMythicPlusRatingSummary("player")
        if type(summary) == "table" then
            return summary
        end
    end

    return nil
end

local function BuildRunLookup(summary)
    local lookup = {}
    if type(summary) ~= "table" or type(summary.runs) ~= "table" then
        return lookup
    end

    for _, runInfo in ipairs(summary.runs) do
        local mapID = type(runInfo) == "table" and runInfo.challengeModeID or nil
        if type(mapID) == "number" and mapID > 0 then
            lookup[mapID] = runInfo
        end
    end

    return lookup
end

local function GetOverallMythicScore(summary)
    if type(summary) == "table" and type(summary.currentSeasonScore) == "number" then
        return summary.currentSeasonScore
    end

    if type(ChallengeModeGetOverallDungeonScore) == "function" then
        local overallScore = ChallengeModeGetOverallDungeonScore()
        if type(overallScore) == "number" then
            return overallScore
        end
    end

    return nil
end

local function GetMythicPlusCompletionData(mapID)
    if type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end

    local summary = GetRatingSummary()
    local lookup = BuildRunLookup(summary)
    local runInfo = lookup[mapID]
    local mapScore = type(runInfo) == "table" and runInfo.mapScore or nil

    if type(mapScore) ~= "number" and type(MythicPlusGetSeasonBestForMap) == "function" then
        local intimeInfo, overtimeInfo = MythicPlusGetSeasonBestForMap(mapID)
        local bestRun = nil

        if type(intimeInfo) == "table" then
            bestRun = intimeInfo
        end

        if type(overtimeInfo) == "table" and (not bestRun or (overtimeInfo.dungeonScore or 0) > (bestRun.dungeonScore or 0)) then
            bestRun = overtimeInfo
        end

        if type(bestRun) == "table" then
            mapScore = bestRun.mapScore or bestRun.dungeonScore or mapScore
        end
    end

    return {
        mapScore = type(mapScore) == "number" and mapScore or nil,
        overallScore = GetOverallMythicScore(summary),
    }
end

local function BuildGroupMembers(run)
    if run and type(run.groupMembers) == "table" and #run.groupMembers > 0 then
        return run.groupMembers
    end

    if not run or run.instanceType ~= "party" or type(IsInRaid) == "function" and IsInRaid() then
        return nil
    end

    local groupMembers = {}
    local units = { "player", "party1", "party2", "party3", "party4" }

    for _, unit in ipairs(units) do
        if (not UnitExists or UnitExists(unit)) and type(UnitClass) == "function" then
            local _, classToken = UnitClass(unit)
            if classToken and classToken ~= "" then
                table.insert(groupMembers, {
                    classToken = classToken,
                    role = type(UnitGroupRolesAssigned) == "function" and UnitGroupRolesAssigned(unit) or nil,
                })
            end
        end
    end

    if #groupMembers == 0 then
        return nil
    end

    return groupMembers
end

local function GetCurrentDungeonInfo()
    if type(IsInInstance) ~= "function" or type(GetInstanceInfo) ~= "function" then
        return nil
    end

    local inInstance = IsInInstance()
    if not inInstance then
        return nil
    end

    local name, instanceType, difficultyID, difficultyName, _, _, _, mapID, _, lfgDungeonID = GetInstanceInfo()
    if instanceType ~= "party" and instanceType ~= "raid" then
        return nil
    end

    if type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end

    return {
        name = TrimText(name) ~= "" and TrimText(name) or "Dungeon",
        mapID = mapID,
        difficultyID = difficultyID,
        difficultyName = TrimText(difficultyName),
        lfgDungeonID = lfgDungeonID,
        instanceType = instanceType,
        isKeystone = IsChallengeRunActive(),
    }
end

local function FormatElapsed(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))

    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60

    if hours > 0 then
        return ("%d:%02d:%02d"):format(hours, minutes, remainingSeconds)
    end

    return ("%02d:%02d"):format(minutes, remainingSeconds)
end

local function GetLeaveChatType()
    if type(IsInGroup) ~= "function" then
        return nil
    end

    if LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInGroup() then
        return "PARTY"
    end

    return nil
end

local function LeaveCurrentGroup()
    if C_PartyInfo and type(C_PartyInfo.LeaveParty) == "function" then
        C_PartyInfo.LeaveParty()
        return
    end

    if type(LegacyLeaveParty) == "function" then
        LegacyLeaveParty()
    end
end

local function GetRunIconKind(run)
    if run and run.isKeystone then
        return "keystone"
    end

    if run and run.instanceType == "raid" then
        return "raid"
    end

    return "dungeon"
end

local function GetDifficultyLabel(run)
    if not run then
        return nil
    end

    if run.isKeystone and type(run.keystoneLevel) == "number" and run.keystoneLevel > 0 then
        return ("Mythic+ %d"):format(run.keystoneLevel)
    end

    local difficultyText = type(run.difficultyName) == "string" and TrimText(run.difficultyName) or ""
    if run.instanceType == "party" and difficultyText ~= "" and difficultyText:lower():find("mythic", 1, true) then
        return "Mythic"
    end

    if difficultyText ~= "" then
        return difficultyText
    end

    return nil
end

local function BuildNotificationWidget(run, completed, canLeaveGroup, leavePhrase)
    ---@type TwichUI_DungeonTrackingNotificationWidget
    local widget = CreateWidget(AceGUI, "TwichUI_DungeonTrackingNotification")
    local durationText = FormatElapsed((run.endedAt or GetTime()) - (run.startedAt or GetTime()))
    local difficultyText = GetDifficultyLabel(run)
    local titleText = run.name or "Unknown Dungeon"
    local detailText

    if difficultyText then
        titleText = ("%s |cff7f8c8d(%s)|r"):format(titleText, difficultyText)
    end

    if completed then
        detailText = ("Completed in %s."):format(durationText)
    else
        detailText = ("Ended early after %s."):format(durationText)
    end

    if completed and run and run.isKeystone then
        local mythicLines = {}

        if type(run.mythicPlusScore) == "number" then
            table.insert(mythicLines, ("Score: %.1f"):format(run.mythicPlusScore))
        end

        if type(run.keystoneUpgradeLevels) == "number" and run.keystoneUpgradeLevels > 0 then
            table.insert(mythicLines, ("Upgrade: +%d"):format(run.keystoneUpgradeLevels))
        end

        if #mythicLines > 0 then
            detailText = detailText .. "\n" .. table.concat(mythicLines, "  |cff7f8c8d-|r  ")
        end
    end

    widget:SetNotification(completed and "completed" or "ended", titleText, detailText,
        GetRunIconKind(run), canLeaveGroup, BuildGroupMembers(run), GetNotificationIconStyle())
    if widget.SetLeavePhraseConfigured then
        widget:SetLeavePhraseConfigured(TrimText(leavePhrase) ~= "")
    end

    if canLeaveGroup then
        widget:SetActionCallback(function(notificationWidget)
            local silent = IsShiftKeyDown and IsShiftKeyDown() and TrimText(leavePhrase) ~= ""
            DT:HandleLeaveGroupButtonClick(leavePhrase, silent)
            if notificationWidget and notificationWidget.Dismiss then
                notificationWidget:Dismiss()
            end
        end)
    else
        widget:SetActionCallback(nil)
    end

    return widget
end

function DT:SendRunNotification(run, completed)
    local options = GetOptions()
    if not options then
        return
    end

    self:SendMessage("TWICH_NOTIFICATION",
        BuildNotificationWidget(run, completed == true, completed == true and options:GetShowLeaveGroupButton(),
            options:GetLeavePhrase()), {
            soundKey = options:GetSound(),
            displayDuration = options:GetNotificationDisplayTime(),
        })
end

function DT:HandleLeaveGroupButtonClick(leavePhrase, silent)
    local phrase = TrimText(leavePhrase)
    local chatType = GetLeaveChatType()
    local silentLeave = silent == true and phrase ~= ""

    if not chatType then
        return
    end

    if not silentLeave and phrase ~= "" and type(SendChat) == "function" then
        SendChat(phrase, chatType)
    end

    if type(C_Timer_After) == "function" then
        C_Timer_After((not silentLeave and phrase ~= "") and 2 or 0, LeaveCurrentGroup)
    else
        LeaveCurrentGroup()
    end
end

function DT:StartRun(dungeonInfo)
    if not dungeonInfo then
        return
    end

    self.activeRun = {
        name = dungeonInfo.name,
        mapID = dungeonInfo.mapID,
        difficultyID = dungeonInfo.difficultyID,
        difficultyName = dungeonInfo.difficultyName,
        lfgDungeonID = dungeonInfo.lfgDungeonID,
        instanceType = dungeonInfo.instanceType,
        isKeystone = dungeonInfo.isKeystone,
        startedAt = GetTime(),
        endedAt = nil,
        completed = false,
        notified = false,
    }
end

function DT:FinishRun(completed)
    local run = self.activeRun
    if not run or run.notified then
        return
    end

    run.completed = completed == true
    run.endedAt = GetTime()
    run.notified = true
    self:SendRunNotification(run, run.completed)
end

function DT:ClearRun()
    self.activeRun = nil
end

function DT:RefreshTrackingState()
    local currentDungeon = GetCurrentDungeonInfo()
    local activeRun = self.activeRun

    if not currentDungeon then
        if activeRun then
            if activeRun.pendingCompletion and not activeRun.notified then
                return
            end
            if not activeRun.notified then
                self:FinishRun(false)
            end
            self:ClearRun()
        end
        return
    end

    if not activeRun then
        self:StartRun(currentDungeon)
        return
    end

    if activeRun.mapID ~= currentDungeon.mapID then
        if not activeRun.notified then
            self:FinishRun(false)
        end
        self:StartRun(currentDungeon)
        return
    end

    activeRun.name = currentDungeon.name
    activeRun.difficultyID = currentDungeon.difficultyID
    activeRun.difficultyName = currentDungeon.difficultyName
    activeRun.lfgDungeonID = currentDungeon.lfgDungeonID
    activeRun.instanceType = currentDungeon.instanceType
    activeRun.isKeystone = currentDungeon.isKeystone
end

function DT:MarkCompleted()
    local activeRun = self.activeRun
    if not activeRun or activeRun.notified then
        return
    end

    self:FinishRun(true)
end

function DT:FinalizeMythicCompletion()
    local activeRun = self.activeRun
    if not activeRun or activeRun.notified then
        return
    end

    activeRun.pendingCompletion = nil

    local completionData = GetMythicPlusCompletionData(activeRun.challengeMapID or activeRun.mapID)
    if completionData then
        activeRun.mythicPlusScore = completionData.mapScore
        activeRun.overallMythicScore = completionData.overallScore
    end

    self:FinishRun(true)
end

function DT:PLAYER_ENTERING_WORLD()
    self:RefreshTrackingState()
end

function DT:SCENARIO_COMPLETED()
    self:MarkCompleted()
end

function DT:CHALLENGE_MODE_COMPLETED(...)
    local activeRun = self.activeRun
    if not activeRun or activeRun.notified then
        return
    end

    local mapID, level, timeMS, onTime, keystoneUpgradeLevels = ...

    if type(mapID) == "number" and mapID > 0 then
        activeRun.challengeMapID = mapID
    end

    if type(level) == "number" and level > 0 then
        activeRun.keystoneLevel = level
    end

    if type(timeMS) == "number" and timeMS > 0 then
        activeRun.endedAt = GetTime()
        activeRun.startedAt = activeRun.endedAt - (timeMS / 1000)
    end

    if type(keystoneUpgradeLevels) == "number" then
        activeRun.keystoneUpgradeLevels = keystoneUpgradeLevels
    end

    activeRun.pendingCompletion = true
    activeRun.completed = true

    if type(C_Timer_After) == "function" then
        C_Timer_After(1, function()
            DT:FinalizeMythicCompletion()
        end)
    else
        self:FinalizeMythicCompletion()
    end
end

function DT:LFG_COMPLETION_REWARD()
    self:MarkCompleted()
end

function DT:CHALLENGE_MODE_START()
    local activeRun = self.activeRun
    if activeRun then
        activeRun.startedAt = GetTime()
        activeRun.notified = false
        activeRun.completed = false
        activeRun.endedAt = nil
        activeRun.isKeystone = true
        activeRun.pendingCompletion = nil
        activeRun.challengeMapID = nil
        activeRun.keystoneUpgradeLevels = nil
        activeRun.mythicPlusScore = nil
    end
end

function DT:TestNotification()
    self:SendRunNotification({
        name = "The Rookery",
        difficultyName = "Heroic",
        instanceType = "party",
        isKeystone = false,
        groupMembers = {
            { classToken = "WARRIOR", role = "TANK" },
            { classToken = "PRIEST",  role = "HEALER" },
            { classToken = "MAGE",    role = "DAMAGER" },
            { classToken = "ROGUE",   role = "DAMAGER" },
            { classToken = "DRUID",   role = "DAMAGER" },
        },
        startedAt = GetTime() - 1127,
        endedAt = GetTime(),
    }, true)
end

function DT:TestMythicNotification()
    self:SendRunNotification({
        name = "The Dawnbreaker",
        difficultyName = "Mythic+",
        instanceType = "party",
        isKeystone = true,
        keystoneLevel = 12,
        keystoneUpgradeLevels = 2,
        mythicPlusScore = 278.4,
        groupMembers = {
            { classToken = "PALADIN", role = "TANK" },
            { classToken = "SHAMAN",  role = "HEALER" },
            { classToken = "MAGE",    role = "DAMAGER" },
            { classToken = "HUNTER",  role = "DAMAGER" },
            { classToken = "WARLOCK", role = "DAMAGER" },
        },
        startedAt = GetTime() - 1942,
        endedAt = GetTime(),
    }, true)
end

function DT:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("SCENARIO_COMPLETED")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("LFG_COMPLETION_REWARD")
    self:RefreshTrackingState()
end

function DT:OnDisable()
    self:UnregisterAllEvents()
    self.activeRun = nil
end
