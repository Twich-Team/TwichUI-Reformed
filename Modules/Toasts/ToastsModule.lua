--[[
    Provides additional notification toasts.
]]
---@type TwichUI
local TwichRx = _G["TwichRx"]
local T, W, I, C = unpack(TwichRx)
local BNGetNumFriends = _G["BNGetNumFriends"]
local GetClassInfo = _G["GetClassInfo"]
local GetFriendInfo = _G["GetFriendInfo"]
local GetNumFriends = _G["GetNumFriends"]
local GetPlayerInfoByGUID = _G["GetPlayerInfoByGUID"]
local ShowFriends = _G["ShowFriends"]
local UnitClass = _G["UnitClass"]
local UnitLevel = _G["UnitLevel"]

local MYTHIC_KEYSTONE_ITEM_ID = 180653

---@class ToastsModule : AceModule, AceEvent-3.0, AceTimer-3.0
local TM = T:NewModule("ToastsModule", "AceEvent-3.0", "AceTimer-3.0")
TM:SetEnabledState(true)

local AceGUI = LibStub("AceGUI-3.0")

local DEFAULT_SOUND = "TwichUI Alert 1"
local DEFAULT_DURATION = 10
local DEFAULT_KEYSTONE_DURATION = 15
local DEFAULT_GREAT_VAULT_DURATION = 10
local DEFAULT_DAILY_RESET_DURATION = 10
local DEFAULT_GROUP_FINDER_DURATION = 10
local DEFAULT_CHORES_DURATION = 15
local BNET_CLIENT_WOW = _G["BNET_CLIENT_WOW"] or "WoW"
local DAILY_RESET_GRACE_WINDOW_SECONDS = 300
local BLIZZARD_FRIEND_TOAST_CVARS = {
    "showToastOnline",
    "showToastOffline",
}

local GROUP_FINDER_INVITE_STATUS_KEYWORDS = {
    invite = true,
    invited = true,
    inviteaccepted = true,
    accepted = true,
}

local GROUP_FINDER_CLEAR_STATUS_KEYWORDS = {
    applied = true,
    cancelled = true,
    canceled = true,
    declined = true,
    failed = true,
    timedout = true,
    timeout = true,
}

local function GetSecondsUntilDailyReset()
    if C_DateAndTime and type(C_DateAndTime.GetSecondsUntilDailyReset) == "function" then
        local secondsUntilReset = C_DateAndTime.GetSecondsUntilDailyReset()
        if type(secondsUntilReset) == "number" and secondsUntilReset >= 0 then
            return secondsUntilReset
        end
    end

    if type(GetQuestResetTime) == "function" then
        local secondsUntilReset = GetQuestResetTime()
        if type(secondsUntilReset) == "number" and secondsUntilReset >= 0 then
            return secondsUntilReset
        end
    end

    return nil
end

local function GetNotificationOptions()
    return T:GetModule("Configuration").Options.NotificationPanel
end

local function IsTruthy(value)
    return value ~= nil and value ~= false and value ~= 0
end

local function TrimText(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

local function BuildInlineTextureIcon(texture, size)
    if not texture then
        return ""
    end

    return ("|T%s:%d:%d:0:0|t "):format(tostring(texture), size or 14, size or 14)
end

local function BuildInlineAtlasIcon(atlas, size)
    if type(atlas) ~= "string" or atlas == "" then
        return ""
    end

    return ("|A:%s:%d:%d|a "):format(atlas, size or 14, size or 14)
end

local function BuildColoredChoreCategory(label)
    return ("|cff72c7ff%s|r"):format(label or "Chores")
end

local function NormalizeFriendName(name)
    name = TrimText(name)
    if name == "" then
        return nil
    end

    return name
end

local function IsPlayerGrouped()
    return IsInGroup() == true or IsInRaid() == true
end

local function NormalizeGroupFinderStatus(status)
    if type(status) ~= "string" then
        return nil
    end

    status = status:lower():gsub("[^a-z]", "")
    if status == "" then
        return nil
    end

    return status
end

local function GetGroupFinderActivityName(activityID)
    if type(activityID) ~= "number" or activityID <= 0 or not C_LFGList then
        return nil
    end

    if type(C_LFGList.GetActivityInfoTable) == "function" then
        local activityInfo = C_LFGList.GetActivityInfoTable(activityID)
        if type(activityInfo) == "table" then
            local candidates = {
                rawget(activityInfo, "fullName"),
                rawget(activityInfo, "shortName"),
                rawget(activityInfo, "groupFinderActivityGroupName"),
                rawget(activityInfo, "categoryName"),
                rawget(activityInfo, "name"),
            }

            for _, candidate in ipairs(candidates) do
                candidate = TrimText(candidate)
                if candidate ~= "" then
                    return candidate
                end
            end
        end
    end

    if type(C_LFGList.GetActivityInfo) == "function" then
        local fullName, shortName = C_LFGList.GetActivityInfo(activityID)
        fullName = TrimText(fullName)
        shortName = TrimText(shortName)
        if fullName ~= "" then
            return fullName
        end
        if shortName ~= "" then
            return shortName
        end
    end

    return nil
end

local function GetGroupFinderStatusFromArgs(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local normalizedStatus = NormalizeGroupFinderStatus(value)
        if normalizedStatus then
            return normalizedStatus
        end
    end

    return nil
end

local function GetGroupFinderSearchResultIDFromArgs(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "number" and value > 0 then
            return value
        end
    end

    return nil
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

local function FindOwnedKeystoneLink()
    if not C_Container then
        return nil
    end

    for bagIndex = 0, GetBagMaxIndex() do
        local numSlots = C_Container.GetContainerNumSlots(bagIndex)
        for slotIndex = 1, numSlots do
            if C_Container.GetContainerItemID(bagIndex, slotIndex) == MYTHIC_KEYSTONE_ITEM_ID then
                return C_Container.GetContainerItemLink(bagIndex, slotIndex)
            end
        end
    end

    return nil
end

local function GetKeystoneAffixText(level)
    if not C_MythicPlus or type(C_MythicPlus.GetCurrentAffixes) ~= "function" then
        return "Affixes unavailable"
    end

    local affixNames = {}
    local affixes = C_MythicPlus.GetCurrentAffixes()
    if type(affixes) ~= "table" then
        return "Affixes unavailable"
    end

    for _, affix in ipairs(affixes) do
        local affixName = type(affix) == "table" and rawget(affix, "name") or nil
        if not affixName and affix and affix.id and C_ChallengeMode and type(C_ChallengeMode.GetAffixInfo) == "function" then
            affixName = C_ChallengeMode.GetAffixInfo(affix.id)
        end

        if type(affixName) == "string" and affixName ~= "" then
            table.insert(affixNames, affixName)
        end
    end

    if #affixNames == 0 then
        return "Affixes unavailable"
    end

    return table.concat(affixNames, ", ")
end

local function GetKeystoneDungeonName(mapID)
    if type(mapID) ~= "number" or not C_ChallengeMode or type(C_ChallengeMode.GetMapUIInfo) ~= "function" then
        return "Unknown Dungeon"
    end

    local name = C_ChallengeMode.GetMapUIInfo(mapID)
    if type(name) == "string" and name ~= "" then
        return name
    end

    return "Unknown Dungeon"
end

local function GetFriendClassToken(classID)
    if type(classID) ~= "number" or type(GetClassInfo) ~= "function" then
        return nil
    end

    local _, classToken = GetClassInfo(classID)
    return classToken
end

local function GetClassTokenFromGUID(guid)
    if type(guid) ~= "string" or type(GetPlayerInfoByGUID) ~= "function" then
        return nil
    end

    local _, classToken = GetPlayerInfoByGUID(guid)
    return classToken
end

local function GetBattleNetClassToken(gameAccountInfo)
    if not gameAccountInfo then
        return nil
    end

    if type(gameAccountInfo.classID) == "number" then
        return GetFriendClassToken(gameAccountInfo.classID)
    end

    return GetClassTokenFromGUID(gameAccountInfo.playerGuid)
end

local function GetFriendInfoByIndex(index)
    if C_FriendList and type(C_FriendList.GetFriendInfoByIndex) == "function" then
        local info = C_FriendList.GetFriendInfoByIndex(index)
        if not info or type(info.name) ~= "string" then
            return nil
        end

        local normalizedName = NormalizeFriendName(info.name)
        if not normalizedName then
            return nil
        end

        return {
            key = info.guid or normalizedName,
            characterName = normalizedName,
            area = TrimText(info.area),
            isOnline = info.connected == true,
            level = type(info.level) == "number" and info.level or 0,
            note = TrimText(info.notes),
            className = info.className,
            classToken = GetClassTokenFromGUID(info.guid),
        }
    end

    local name, level, className, area, connected, status, note, RAFLinkType, mobile, sex, classID = GetFriendInfo(index)
    local normalizedName = NormalizeFriendName(name)
    if not normalizedName then
        return nil
    end

    return {
        key = normalizedName,
        characterName = normalizedName,
        area = TrimText(area),
        isOnline = IsTruthy(connected),
        level = type(level) == "number" and level or 0,
        note = TrimText(note),
        className = className,
        classToken = GetFriendClassToken(classID),
    }
end

local function GetBattleNetFriendsSnapshot()
    local snapshot = {}
    local numFriends = type(BNGetNumFriends) == "function" and BNGetNumFriends() or 0

    if not C_BattleNet or type(C_BattleNet.GetFriendAccountInfo) ~= "function" then
        return snapshot
    end

    for friendIndex = 1, numFriends do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(friendIndex)
        if accountInfo then
            local note = TrimText(accountInfo.note)
            local numGameAccounts = C_BattleNet.GetFriendNumGameAccounts and
                C_BattleNet.GetFriendNumGameAccounts(friendIndex) or 0

            for accountIndex = 1, numGameAccounts do
                local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo and
                    C_BattleNet.GetFriendGameAccountInfo(friendIndex, accountIndex)
                if gameAccountInfo and gameAccountInfo.isOnline == true and gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
                    local characterName = NormalizeFriendName(gameAccountInfo.characterName)
                    if characterName then
                        local key = gameAccountInfo.playerGuid or
                            ("bnet:" .. tostring(accountInfo.bnetAccountID or friendIndex) .. ":" .. tostring(gameAccountInfo.gameAccountID or accountIndex))
                        snapshot[key] = {
                            key = key,
                            characterName = characterName,
                            area = TrimText(gameAccountInfo.areaName or gameAccountInfo.richPresence),
                            isOnline = true,
                            level = type(gameAccountInfo.characterLevel) == "number" and gameAccountInfo.characterLevel or
                                0,
                            note = note,
                            className = gameAccountInfo.className,
                            classToken = GetBattleNetClassToken(gameAccountInfo),
                        }
                    end
                end
            end
        end
    end

    return snapshot
end

function TM:OnEnable()
    self.friendStates = self.friendStates or {}
    self.blizzardFriendToastCVarState = self.blizzardFriendToastCVarState or {}
    self.hasFriendSnapshot = false
    self.keystoneState = self.keystoneState or nil
    self.hasKeystoneSnapshot = false
    self.greatVaultState = self.greatVaultState or nil
    self.hasGreatVaultSnapshot = false
    self.dailyResetTimer = self.dailyResetTimer or nil
    self.lastDailyResetNotificationAt = self.lastDailyResetNotificationAt or nil
    self.pendingGroupFinderInvite = self.pendingGroupFinderInvite or nil
    self.lastGroupFinderNotificationSearchResultID = self.lastGroupFinderNotificationSearchResultID or nil
    self.wasGrouped = IsPlayerGrouped()

    self:RegisterEvent("FRIENDLIST_UPDATE", "HandleFriendListUpdate")
    self:RegisterEvent("BN_CONNECTED", "HandleFriendListUpdate")
    self:RegisterEvent("BN_FRIEND_INFO_CHANGED", "HandleFriendListUpdate")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE", "HandleFriendListUpdate")
    self:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE", "HandleFriendListUpdate")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "HandleKeystoneBagUpdate")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "HandleGroupRosterUpdate")
    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED", "HandleGroupFinderApplicationStatusUpdated")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandlePlayerEnteringWorld")
    self:RegisterEvent("WEEKLY_REWARDS_UPDATE", "HandleGreatVaultUpdate")
    self:SyncBlizzardFriendToasts()
    self:RequestFriendListRefresh()
end

function TM:OnDisable()
    self:RestoreBlizzardFriendToasts()

    if self.dailyResetTimer then
        self:CancelTimer(self.dailyResetTimer)
        self.dailyResetTimer = nil
    end

    self:UnregisterAllEvents()
    self.friendStates = {}
    self.hasFriendSnapshot = false
    self.keystoneState = nil
    self.hasKeystoneSnapshot = false
    self.greatVaultState = nil
    self.hasGreatVaultSnapshot = false
    self.lastDailyResetNotificationAt = nil
    self.pendingGroupFinderInvite = nil
    self.lastGroupFinderNotificationSearchResultID = nil
    self.wasGrouped = false
end

function TM:RestoreBlizzardFriendToasts()
    if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
        return
    end

    self.blizzardFriendToastCVarState = self.blizzardFriendToastCVarState or {}
    for _, cvarName in ipairs(BLIZZARD_FRIEND_TOAST_CVARS) do
        local originalValue = self.blizzardFriendToastCVarState[cvarName]
        if originalValue ~= nil and GetCVar(cvarName) ~= originalValue then
            SetCVar(cvarName, originalValue)
        end
        self.blizzardFriendToastCVarState[cvarName] = nil
    end
end

function TM:SyncBlizzardFriendToasts()
    if type(GetCVar) ~= "function" or type(SetCVar) ~= "function" then
        return
    end

    self.blizzardFriendToastCVarState = self.blizzardFriendToastCVarState or {}

    if not self:IsFriendsNotificationEnabled() then
        self:RestoreBlizzardFriendToasts()
        return
    end

    for _, cvarName in ipairs(BLIZZARD_FRIEND_TOAST_CVARS) do
        if self.blizzardFriendToastCVarState[cvarName] == nil then
            self.blizzardFriendToastCVarState[cvarName] = GetCVar(cvarName)
        end

        if GetCVar(cvarName) ~= "0" then
            SetCVar(cvarName, "0")
        end
    end
end

function TM:RequestFriendListRefresh()
    if C_FriendList and type(C_FriendList.ShowFriends) == "function" then
        C_FriendList.ShowFriends()
        return
    end

    if type(ShowFriends) == "function" then
        ShowFriends()
    end
end

function TM:BuildFriendSnapshot()
    local snapshot = {}
    local numFriends = 0

    if C_FriendList and type(C_FriendList.GetNumFriends) == "function" then
        numFriends = C_FriendList.GetNumFriends() or 0
    elseif type(GetNumFriends) == "function" then
        numFriends = GetNumFriends() or 0
    end

    for index = 1, numFriends do
        local friendInfo = GetFriendInfoByIndex(index)
        if friendInfo then
            snapshot[friendInfo.key] = friendInfo
        end
    end

    for key, friendInfo in pairs(GetBattleNetFriendsSnapshot()) do
        snapshot[key] = friendInfo
    end

    return snapshot
end

function TM:IsFriendsNotificationEnabled()
    local options = GetNotificationOptions()
    return options and options:GetEnableFriendsNotifications() or false
end

function TM:GetFriendsNotificationSound()
    local options = GetNotificationOptions()
    return options and options.GetFriendsNotificationSound and options:GetFriendsNotificationSound() or DEFAULT_SOUND
end

function TM:GetFriendsNotificationDisplayTime()
    local options = GetNotificationOptions()
    return options and options.GetFriendsNotificationDisplayTime and options:GetFriendsNotificationDisplayTime() or
        DEFAULT_DURATION
end

function TM:GetFriendsNotificationIconStyle()
    local options = GetNotificationOptions()
    return options and options.GetFriendsNotificationIconStyle and options:GetFriendsNotificationIconStyle() or "default"
end

function TM:IsKeystoneNotificationEnabled()
    local options = GetNotificationOptions()
    return options and options.GetEnableKeystoneNotifications and options:GetEnableKeystoneNotifications() or false
end

function TM:GetKeystoneNotificationSound()
    local options = GetNotificationOptions()
    return options and options.GetKeystoneNotificationSound and options:GetKeystoneNotificationSound() or DEFAULT_SOUND
end

function TM:GetKeystoneNotificationDisplayTime()
    local options = GetNotificationOptions()
    return options and options.GetKeystoneNotificationDisplayTime and options:GetKeystoneNotificationDisplayTime() or
        DEFAULT_KEYSTONE_DURATION
end

function TM:IsGreatVaultNotificationEnabled()
    local options = GetNotificationOptions()
    return options and options.GetEnableGreatVaultNotifications and options:GetEnableGreatVaultNotifications() or false
end

function TM:GetGreatVaultNotificationSound()
    local options = GetNotificationOptions()
    return options and options.GetGreatVaultNotificationSound and options:GetGreatVaultNotificationSound() or
        DEFAULT_SOUND
end

function TM:GetGreatVaultNotificationDisplayTime()
    local options = GetNotificationOptions()
    return options and options.GetGreatVaultNotificationDisplayTime and options:GetGreatVaultNotificationDisplayTime() or
        DEFAULT_GREAT_VAULT_DURATION
end

function TM:IsDailyResetNotificationEnabled()
    local options = GetNotificationOptions()
    return options and options.GetEnableDailyResetNotifications and options:GetEnableDailyResetNotifications() or false
end

function TM:GetDailyResetNotificationSound()
    local options = GetNotificationOptions()
    return options and options.GetDailyResetNotificationSound and options:GetDailyResetNotificationSound() or
        DEFAULT_SOUND
end

function TM:GetDailyResetNotificationDisplayTime()
    local options = GetNotificationOptions()
    return options and options.GetDailyResetNotificationDisplayTime and options:GetDailyResetNotificationDisplayTime() or
        DEFAULT_DAILY_RESET_DURATION
end

function TM:IsGroupFinderNotificationEnabled()
    local options = GetNotificationOptions()
    return options and options.GetEnableGroupFinderNotifications and options:GetEnableGroupFinderNotifications() or false
end

function TM:IsChoresNotificationEnabled()
    local options = GetNotificationOptions()
    return options and options.GetEnableChoresNotifications and options:GetEnableChoresNotifications() or false
end

function TM:GetGroupFinderNotificationSound()
    local options = GetNotificationOptions()
    return options and options.GetGroupFinderNotificationSound and options:GetGroupFinderNotificationSound() or
        DEFAULT_SOUND
end

function TM:GetGroupFinderNotificationDisplayTime()
    local options = GetNotificationOptions()
    return options and options.GetGroupFinderNotificationDisplayTime and options:GetGroupFinderNotificationDisplayTime() or
        DEFAULT_GROUP_FINDER_DURATION
end

function TM:GetChoresNotificationSound()
    local options = GetNotificationOptions()
    return options and options.GetChoresNotificationSound and options:GetChoresNotificationSound() or DEFAULT_SOUND
end

function TM:GetChoresNotificationDisplayTime()
    local options = GetNotificationOptions()
    return options and options.GetChoresNotificationDisplayTime and options:GetChoresNotificationDisplayTime() or
        DEFAULT_CHORES_DURATION
end

function TM:GetFriendDisplayName(friendInfo)
    local options = GetNotificationOptions()
    if options and options:GetUseFriendNoteAsName() and friendInfo.note ~= "" then
        return friendInfo.note, true
    end

    return friendInfo.characterName, false
end

function TM:BuildFriendDetailText(friendInfo, usedNote)
    local details = {}
    local levelText = type(friendInfo.level) == "number" and friendInfo.level > 0 and
        ("Level %d"):format(friendInfo.level) or nil

    if usedNote and friendInfo.characterName ~= "" then
        local characterLine = friendInfo.characterName
        if levelText then
            characterLine = ("%s (%s)"):format(characterLine, levelText)
        end
        table.insert(details, characterLine)
    elseif levelText then
        table.insert(details, levelText)
    end

    if friendInfo.isOnline then
        if friendInfo.area ~= "" then
            table.insert(details, friendInfo.area)
        else
            table.insert(details, "Came online")
        end
    else
        table.insert(details, "Went offline")
    end

    return table.concat(details, " - ")
end

function TM:CreateFriendNotificationWidget(friendInfo)
    local displayName, usedNote = self:GetFriendDisplayName(friendInfo)
    local detailText = self:BuildFriendDetailText(friendInfo, usedNote)
    local iconStyle = self:GetFriendsNotificationIconStyle()

    ---@type TwichUI_FriendNotificationWidget
    ---@diagnostic disable-next-line: param-type-mismatch
    local widget = AceGUI:Create("TwichUI_FriendNotification")
    ---@diagnostic disable-next-line: undefined-field
    widget:SetFriendNotification(displayName, detailText, friendInfo.classToken, friendInfo.isOnline, iconStyle)
    return widget
end

function TM:SendFriendNotification(friendInfo)
    if not friendInfo then
        return
    end

    local widget = self:CreateFriendNotificationWidget(friendInfo)
    self:SendMessage("TWICH_NOTIFICATION", widget, {
        displayDuration = self:GetFriendsNotificationDisplayTime(),
        soundKey = self:GetFriendsNotificationSound(),
    })
end

function TM:BuildKeystoneState()
    if not C_MythicPlus or type(C_MythicPlus.GetOwnedKeystoneLevel) ~= "function" or type(C_MythicPlus.GetOwnedKeystoneChallengeMapID) ~= "function" then
        return nil
    end

    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    if type(level) ~= "number" or level <= 0 or type(mapID) ~= "number" or mapID <= 0 then
        return nil
    end

    local affixText = GetKeystoneAffixText(level)

    return {
        itemID = MYTHIC_KEYSTONE_ITEM_ID,
        itemLink = FindOwnedKeystoneLink(),
        dungeonName = GetKeystoneDungeonName(mapID),
        level = level,
        affixText = affixText,
        mapID = mapID,
    }
end

function TM:DidKeystoneChange(previousState, currentState)
    if not currentState then
        return false
    end

    if not previousState then
        return true
    end

    return previousState.mapID ~= currentState.mapID or
        previousState.level ~= currentState.level or
        previousState.affixText ~= currentState.affixText
end

function TM:CreateKeystoneNotificationWidget(keystoneInfo)
    ---@type TwichUI_KeystoneNotificationWidget
    ---@diagnostic disable-next-line: param-type-mismatch
    local widget = AceGUI:Create("TwichUI_KeystoneNotification")
    ---@diagnostic disable-next-line: undefined-field
    widget:SetKeystoneNotification(keystoneInfo.itemLink or keystoneInfo.itemID, keystoneInfo.dungeonName,
        keystoneInfo.level,
        keystoneInfo.affixText)
    return widget
end

function TM:SendKeystoneNotification(keystoneInfo)
    if not keystoneInfo then
        return
    end

    local widget = self:CreateKeystoneNotificationWidget(keystoneInfo)
    self:SendMessage("TWICH_NOTIFICATION", widget, {
        displayDuration = self:GetKeystoneNotificationDisplayTime(),
        soundKey = self:GetKeystoneNotificationSound(),
    })
end

function TM:BuildGreatVaultState()
    if not C_WeeklyRewards or type(C_WeeklyRewards.HasAvailableRewards) ~= "function" then
        return nil
    end

    local hasAvailableRewards = C_WeeklyRewards.HasAvailableRewards() == true
    local rewardCount = 0

    if type(C_WeeklyRewards.GetNumRewards) == "function" then
        rewardCount = C_WeeklyRewards.GetNumRewards() or 0
    end

    if hasAvailableRewards and rewardCount <= 0 then
        rewardCount = 1
    end

    return {
        hasAvailableRewards = hasAvailableRewards,
        rewardCount = rewardCount,
    }
end

function TM:DidGreatVaultBecomeAvailable(previousState, currentState)
    if not currentState or currentState.hasAvailableRewards ~= true then
        return false
    end

    if not previousState then
        return true
    end

    return previousState.hasAvailableRewards ~= true
end

function TM:CreateGreatVaultNotificationWidget(greatVaultInfo)
    ---@type TwichUI_GreatVaultNotificationWidget
    ---@diagnostic disable-next-line: param-type-mismatch
    local widget = AceGUI:Create("TwichUI_GreatVaultNotification")
    ---@diagnostic disable-next-line: undefined-field
    widget:SetGreatVaultNotification(greatVaultInfo.rewardCount)
    return widget
end

function TM:SendGreatVaultNotification(greatVaultInfo)
    if not greatVaultInfo or greatVaultInfo.hasAvailableRewards ~= true then
        return
    end

    local widget = self:CreateGreatVaultNotificationWidget(greatVaultInfo)
    self:SendMessage("TWICH_NOTIFICATION", widget, {
        displayDuration = self:GetGreatVaultNotificationDisplayTime(),
        soundKey = self:GetGreatVaultNotificationSound(),
    })
end

function TM:CreateDailyResetNotificationWidget()
    ---@type TwichUI_DailyResetNotificationWidget
    ---@diagnostic disable-next-line: param-type-mismatch
    local widget = AceGUI:Create("TwichUI_DailyResetNotification")
    ---@diagnostic disable-next-line: undefined-field
    widget:SetDailyResetNotification()
    return widget
end

function TM:SendDailyResetNotification()
    local widget = self:CreateDailyResetNotificationWidget()
    self:SendMessage("TWICH_NOTIFICATION", widget, {
        displayDuration = self:GetDailyResetNotificationDisplayTime(),
        soundKey = self:GetDailyResetNotificationSound(),
    })
end

function TM:BuildGroupFinderNotificationInfo(searchResultID)
    if type(searchResultID) ~= "number" or searchResultID <= 0 or not C_LFGList or type(C_LFGList.GetSearchResultInfo) ~= "function" then
        return nil
    end

    local searchResultInfo = C_LFGList.GetSearchResultInfo(searchResultID)
    if type(searchResultInfo) ~= "table" then
        return nil
    end

    local activityName = nil
    local activityIDs = searchResultInfo.activityIDs
    if type(activityIDs) == "table" then
        for _, activityID in ipairs(activityIDs) do
            activityName = GetGroupFinderActivityName(activityID)
            if activityName then
                break
            end
        end
    end

    local legacyActivityID = rawget(searchResultInfo, "activityID")
    if not activityName and type(legacyActivityID) == "number" then
        activityName = GetGroupFinderActivityName(legacyActivityID)
    end

    local listingName = TrimText(searchResultInfo.name)
    if not activityName or activityName == "" then
        activityName = listingName ~= "" and listingName or "Unknown Activity"
    end

    return {
        searchResultID = searchResultID,
        activityName = activityName,
        listingName = listingName,
    }
end

function TM:CreateGroupFinderNotificationWidget(groupFinderInfo)
    ---@type TwichUI_GroupFinderNotificationWidget
    ---@diagnostic disable-next-line: param-type-mismatch
    local widget = AceGUI:Create("TwichUI_GroupFinderNotification")
    ---@diagnostic disable-next-line: undefined-field
    widget:SetGroupFinderNotification(groupFinderInfo.activityName, groupFinderInfo.listingName)
    return widget
end

function TM:SendGroupFinderNotification(groupFinderInfo)
    if not groupFinderInfo then
        return
    end

    local widget = self:CreateGroupFinderNotificationWidget(groupFinderInfo)
    self:SendMessage("TWICH_NOTIFICATION", widget, {
        displayDuration = self:GetGroupFinderNotificationDisplayTime(),
        soundKey = self:GetGroupFinderNotificationSound(),
    })
end

function TM:CreateChoresNotificationWidget(kind, entries)
    ---@type TwichUI_ChoresNotificationWidget
    ---@diagnostic disable-next-line: param-type-mismatch
    local widget = AceGUI:Create("TwichUI_ChoresNotification")
    ---@diagnostic disable-next-line: undefined-field
    widget:SetChoresNotification(kind, entries)
    return widget
end

function TM:SendChoresNotification(kind, entries)
    if not self:IsChoresNotificationEnabled() or type(entries) ~= "table" or #entries == 0 then
        return
    end

    local widget = self:CreateChoresNotificationWidget(kind, entries)
    self:SendMessage("TWICH_NOTIFICATION", widget, {
        displayDuration = self:GetChoresNotificationDisplayTime(),
        soundKey = self:GetChoresNotificationSound(),
    })
end

function TM:GetCurrentDailyResetTimestamp()
    local secondsUntilReset = GetSecondsUntilDailyReset()
    local serverTime = type(GetServerTime) == "function" and GetServerTime() or time()
    if type(secondsUntilReset) ~= "number" or type(serverTime) ~= "number" then
        return nil
    end

    return serverTime + secondsUntilReset
end

function TM:ScheduleDailyResetNotification()
    if self.dailyResetTimer then
        self:CancelTimer(self.dailyResetTimer)
        self.dailyResetTimer = nil
    end

    local secondsUntilReset = GetSecondsUntilDailyReset()
    if type(secondsUntilReset) ~= "number" then
        return
    end

    local delay = math.max(secondsUntilReset + 1, 1)
    self.dailyResetTimer = self:ScheduleTimer("HandleDailyResetTimer", delay)
end

function TM:TrySendDailyResetLoginCatchup()
    local secondsUntilReset = GetSecondsUntilDailyReset()
    local resetTimestamp = self:GetCurrentDailyResetTimestamp()
    if type(secondsUntilReset) ~= "number" or type(resetTimestamp) ~= "number" then
        return
    end

    local currentResetTimestamp = resetTimestamp - 86400
    if secondsUntilReset > DAILY_RESET_GRACE_WINDOW_SECONDS then
        return
    end

    if self.lastDailyResetNotificationAt == currentResetTimestamp then
        return
    end

    if self:IsDailyResetNotificationEnabled() then
        self:SendDailyResetNotification()
    end

    self.lastDailyResetNotificationAt = currentResetTimestamp
end

function TM:HandleDailyResetTimer()
    local resetTimestamp = self:GetCurrentDailyResetTimestamp()
    if type(resetTimestamp) == "number" then
        self.lastDailyResetNotificationAt = resetTimestamp - 86400
    end

    if self:IsDailyResetNotificationEnabled() then
        self:SendDailyResetNotification()
    end

    self:ScheduleDailyResetNotification()
end

function TM:HandlePlayerEnteringWorld()
    self:HandleGreatVaultUpdate()
    self:ScheduleDailyResetNotification()
    self:TrySendDailyResetLoginCatchup()
    self.wasGrouped = IsPlayerGrouped()
    if not self.wasGrouped then
        self.pendingGroupFinderInvite = nil
    end
end

function TM:HandleGroupFinderApplicationStatusUpdated(event, ...)
    local searchResultID = GetGroupFinderSearchResultIDFromArgs(...)
    local groupFinderStatus = GetGroupFinderStatusFromArgs(...)
    if not searchResultID or not groupFinderStatus then
        return
    end

    if GROUP_FINDER_INVITE_STATUS_KEYWORDS[groupFinderStatus] then
        self.pendingGroupFinderInvite = self:BuildGroupFinderNotificationInfo(searchResultID)
        return
    end

    if GROUP_FINDER_CLEAR_STATUS_KEYWORDS[groupFinderStatus] and self.pendingGroupFinderInvite and self.pendingGroupFinderInvite.searchResultID == searchResultID then
        self.pendingGroupFinderInvite = nil
    end
end

function TM:HandleGroupRosterUpdate()
    local isGrouped = IsPlayerGrouped()

    if isGrouped and not self.wasGrouped and self.pendingGroupFinderInvite then
        local groupFinderInfo = self.pendingGroupFinderInvite
        local searchResultID = groupFinderInfo and groupFinderInfo.searchResultID or nil
        if self:IsGroupFinderNotificationEnabled() and searchResultID and self.lastGroupFinderNotificationSearchResultID ~= searchResultID then
            self:SendGroupFinderNotification(groupFinderInfo)
            self.lastGroupFinderNotificationSearchResultID = searchResultID
        end

        self.pendingGroupFinderInvite = nil
    elseif not isGrouped then
        self.pendingGroupFinderInvite = nil
    end

    self.wasGrouped = isGrouped
end

function TM:HandleGreatVaultUpdate()
    local latestState = self:BuildGreatVaultState()

    if not self.hasGreatVaultSnapshot then
        self.greatVaultState = latestState
        self.hasGreatVaultSnapshot = true

        if self:IsGreatVaultNotificationEnabled() and latestState and latestState.hasAvailableRewards then
            self:SendGreatVaultNotification(latestState)
        end
        return
    end

    if self:IsGreatVaultNotificationEnabled() and self:DidGreatVaultBecomeAvailable(self.greatVaultState, latestState) then
        self:SendGreatVaultNotification(latestState)
    end

    self.greatVaultState = latestState
end

function TM:HandleKeystoneBagUpdate()
    local latestState = self:BuildKeystoneState()

    if not self.hasKeystoneSnapshot then
        self.keystoneState = latestState
        self.hasKeystoneSnapshot = true
        return
    end

    if self:IsKeystoneNotificationEnabled() and self:DidKeystoneChange(self.keystoneState, latestState) then
        self:SendKeystoneNotification(latestState)
    end

    self.keystoneState = latestState
end

function TM:HandleFriendListUpdate()
    local latestSnapshot = self:BuildFriendSnapshot()
    local previousSnapshot = self.friendStates or {}

    if not self.hasFriendSnapshot then
        self.friendStates = latestSnapshot
        self.hasFriendSnapshot = true
        return
    end

    local notificationsEnabled = self:IsFriendsNotificationEnabled()
    for key, latestFriendInfo in pairs(latestSnapshot) do
        local previousFriendInfo = previousSnapshot[key]
        if notificationsEnabled and not previousFriendInfo and latestFriendInfo.isOnline then
            self:SendFriendNotification(latestFriendInfo)
        elseif previousFriendInfo and previousFriendInfo.isOnline ~= latestFriendInfo.isOnline and notificationsEnabled then
            self:SendFriendNotification(latestFriendInfo)
        end
    end

    for key, previousFriendInfo in pairs(previousSnapshot) do
        if previousFriendInfo.isOnline and not latestSnapshot[key] and notificationsEnabled then
            local offlineFriendInfo = {}
            for field, value in pairs(previousFriendInfo) do
                offlineFriendInfo[field] = value
            end
            offlineFriendInfo.isOnline = false
            self:SendFriendNotification(offlineFriendInfo)
        end
    end

    self.friendStates = latestSnapshot
end

function TM:GetFirstOnlineFriend()
    local snapshot = self:BuildFriendSnapshot()
    for _, friendInfo in pairs(snapshot) do
        if friendInfo.isOnline then
            return friendInfo
        end
    end

    return nil
end

function TM:CreateFakeFriendInfo()
    local classToken = nil
    if type(UnitClass) == "function" then
        local _, playerClassToken = UnitClass("player")
        classToken = playerClassToken
    end

    return {
        key = "test:friend",
        characterName = "Test Friend",
        area = "Testing notification preview",
        isOnline = true,
        level = UnitLevel and UnitLevel("player") or 0,
        note = "Best Friend",
        className = nil,
        classToken = classToken,
    }
end

function TM:CreateFakeKeystoneInfo()
    local dungeonName = "Ara-Kara, City of Echoes"
    local mapID = nil

    if C_ChallengeMode and type(C_ChallengeMode.GetMapTable) == "function" then
        local mapTable = C_ChallengeMode.GetMapTable()
        if type(mapTable) == "table" and #mapTable > 0 then
            mapID = mapTable[1]
            dungeonName = GetKeystoneDungeonName(mapID)
        end
    end

    return {
        itemID = MYTHIC_KEYSTONE_ITEM_ID,
        itemLink = nil,
        dungeonName = dungeonName,
        level = 10,
        affixText = GetKeystoneAffixText(10),
        mapID = mapID,
    }
end

function TM:CreateFakeGreatVaultInfo()
    return {
        hasAvailableRewards = true,
        rewardCount = 1,
    }
end

function TM:CreateFakeDailyResetInfo()
    return true
end

function TM:CreateFakeGroupFinderInfo()
    return {
        searchResultID = -1,
        activityName = "Mythic+ Ara-Kara, City of Echoes",
        listingName = "Weekly Key Push",
    }
end

function TM:TestFriendNotification()
    local friendInfo = self:GetFirstOnlineFriend()
    if not friendInfo then
        friendInfo = self:CreateFakeFriendInfo()
    end

    self:SendFriendNotification(friendInfo)
    return true
end

function TM:TestKeystoneNotification()
    local keystoneInfo = self:BuildKeystoneState()
    if not keystoneInfo then
        keystoneInfo = self:CreateFakeKeystoneInfo()
    end

    self:SendKeystoneNotification(keystoneInfo)
    return true
end

function TM:TestGreatVaultNotification()
    local greatVaultInfo = self:BuildGreatVaultState()
    if not greatVaultInfo or greatVaultInfo.hasAvailableRewards ~= true then
        greatVaultInfo = self:CreateFakeGreatVaultInfo()
    end

    self:SendGreatVaultNotification(greatVaultInfo)
    return true
end

function TM:TestDailyResetNotification()
    self:CreateFakeDailyResetInfo()
    self:SendDailyResetNotification()
    return true
end

function TM:TestGroupFinderNotification()
    self:SendGroupFinderNotification(self:CreateFakeGroupFinderInfo())
    return true
end

function TM:TestChoresNotification()
    local enchantingIcon = C_Spell and type(C_Spell.GetSpellTexture) == "function" and C_Spell.GetSpellTexture(7411) or
        "Interface\\Icons\\trade_engraving"

    self:SendChoresNotification("available", {
        BuildInlineAtlasIcon("delves-regular") ..
        BuildColoredChoreCategory("Delver's Call") .. " |cff7f8c8d-|r Azj-Kahet: Spiral Weave",
        BuildInlineTextureIcon(enchantingIcon) ..
        BuildColoredChoreCategory("Enchanting") .. " |cff7f8c8d-|r Mobs/Treasures (1/2)",
        BuildInlineAtlasIcon("Raid") .. BuildColoredChoreCategory("Raid Finder") .. " |cff7f8c8d-|r Wing 2",
    })
    return true
end
