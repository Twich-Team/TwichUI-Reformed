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
local GetInstanceInfo = GetInstanceInfo
local GetTime = GetTime
local IsInInstance = IsInInstance
local IsInGroup = IsInGroup
local LegacyLeaveParty = rawget(_G, "LeaveParty")
local SendChat = rawget(_G, "SendChatMessage")

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

local function BuildNotificationWidget(run, completed, canLeaveGroup, leavePhrase)
    ---@type TwichUI_DungeonTrackingNotificationWidget
    local widget = CreateWidget(AceGUI, "TwichUI_DungeonTrackingNotification")
    local durationText = FormatElapsed((run.endedAt or GetTime()) - (run.startedAt or GetTime()))
    local difficultyText = run.difficultyName ~= "" and run.difficultyName or nil
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

    widget:SetNotification(completed and "completed" or "ended", titleText, detailText,
        GetRunIconKind(run), canLeaveGroup)

    if canLeaveGroup then
        widget:SetActionCallback(function(notificationWidget)
            DT:HandleLeaveGroupButtonClick(leavePhrase)
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

function DT:HandleLeaveGroupButtonClick(leavePhrase)
    local phrase = TrimText(leavePhrase)
    local chatType = GetLeaveChatType()

    if phrase ~= "" and chatType and type(SendChat) == "function" then
        SendChat(phrase, chatType)
    end

    local canLeave = chatType ~= nil
    if not canLeave then
        return
    end

    if type(C_Timer_After) == "function" then
        C_Timer_After(0.25, LeaveCurrentGroup)
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

function DT:PLAYER_ENTERING_WORLD()
    self:RefreshTrackingState()
end

function DT:SCENARIO_COMPLETED()
    self:MarkCompleted()
end

function DT:CHALLENGE_MODE_COMPLETED()
    self:MarkCompleted()
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
    end
end

function DT:TestNotification()
    self:SendRunNotification({
        name = "The Rookery",
        difficultyName = "Heroic",
        startedAt = GetTime() - 1127,
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
