---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local CreateFrame = CreateFrame
local GetTime = GetTime
local PlaySoundFile = PlaySoundFile
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local UIParent = UIParent

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class PreyTweaksModule : AceModule, AceEvent-3.0, AceTimer-3.0
local PT = QOL:NewModule("PreyTweaks", "AceEvent-3.0", "AceTimer-3.0")

local WIDGET_TYPE_PREY = (Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.PreyHuntProgress) or
31
local WIDGET_SHOWN = (Enum and Enum.WidgetShownState and Enum.WidgetShownState.Shown) or 1
local QUEST_WATCH_MANUAL = (Enum and Enum.QuestWatchType and Enum.QuestWatchType.Manual) or 1
local PREY_WORLD_QUEST_TYPE = Enum and Enum.QuestTagType and Enum.QuestTagType.Prey or nil
local ASTALOR_NPC_ID = 253513
local REMNANT_CURRENCY_ID = 3392
local DAWNCREST_CURRENCY_IDS = {
    [3391] = true,
    [3341] = true,
}
local VOIDLIGHT_MARL_CURRENCY_ID = 3316
local PREY_WORLD_QUESTS = {
    [91458] = true,
    [91523] = true,
    [91590] = true,
    [91591] = true,
    [91592] = true,
    [91594] = true,
    [91595] = true,
    [91596] = true,
    [91207] = true,
    [91601] = true,
    [91602] = true,
    [91604] = true,
}
local PREY_PROGRESS_BY_STATE = {
    [0] = 0,
    [1] = 0.34,
    [2] = 0.67,
    [3] = 1,
}
local PREY_COLOR_BY_STATE = {
    [0] = { 0.72, 0.72, 0.76 },
    [1] = { 0.95, 0.78, 0.25 },
    [2] = { 0.97, 0.50, 0.12 },
    [3] = { 0.93, 0.21, 0.18 },
}
local PREY_LABEL_BY_STATE = {
    [0] = "COLD",
    [1] = "WARM",
    [2] = "HOT",
    [3] = "FINAL",
}
local PREY_ATLAS_BY_STATE = {
    [0] = "ui-prey-targeticon-regular",
    [1] = "ui-prey-targeticon-inprogress",
    [2] = "ui-prey-targeticon-final",
    [3] = "ui-prey-targeticon-final",
}
local REWARD_PATTERNS = {
    dawncrest = { "dawncrest", "crest" },
    remnant = { "remnant", "anguish" },
    gold = { "gold", "coin" },
    marl = { "marl", "voidlight" },
}
local DIFFICULTY_PATTERNS = {
    normal = { "normal" },
    hard = { "hard" },
    nightmare = { "nightmare" },
}
local RANDOM_PATTERNS = { "random" }
local RADIAL_RING_TEXTURE =
"Interface\\AddOns\\TwichUI_Redux\\AddOnReferences\\Preybreaker\\Media\\Assets\\ProgressBar-Radial-WarWithin"
local RING_BORDER_TEX_COORD = { 0, 80 / 256, 80 / 256, 160 / 256 }
local RING_SWIPE_TEX_COORD = { 80 / 256, 160 / 256, 80 / 256, 160 / 256 }

local function ResolveOutlineStyle(style, fallback)
    if style == "none" then
        return ""
    end
    if style == "outline" then
        return "OUTLINE"
    end
    if style == "thick" then
        return "THICKOUTLINE"
    end

    return fallback or ""
end

local function GetOptions()
    return T:GetModule("Configuration").Options.PreyTweaks
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local ok, resultA, resultB, resultC, resultD, resultE = pcall(func, ...)
    if not ok then
        return nil
    end

    return resultA, resultB, resultC, resultD, resultE
end

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then
        return 0
    end
    if value > 1 then
        return 1
    end
    return value
end

local function RoundPercent(progress)
    return math.floor((Clamp01(progress) * 100) + 0.5)
end

local function NormalizeText(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = value:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil
    end

    return trimmed:lower()
end

local function TextContainsAny(text, patterns)
    local normalizedText = NormalizeText(text)
    if not normalizedText then
        return false
    end

    for _, pattern in ipairs(patterns or {}) do
        if normalizedText:find(pattern:lower(), 1, true) then
            return true
        end
    end

    return false
end

local function GetNpcIDFromGUID(guid)
    if type(guid) ~= "string" then
        return nil
    end

    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

local function GetQuestMapID(questID)
    if type(questID) ~= "number" then
        return nil
    end

    if type(GetQuestUiMapID) == "function" then
        local mapID = SafeCall(GetQuestUiMapID, questID, true)
        if mapID then
            return mapID
        end
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestZoneID) == "function" then
        return SafeCall(C_TaskQuest.GetQuestZoneID, questID)
    end

    return nil
end

local function GetQuestTitle(questID)
    if type(questID) ~= "number" then
        return nil
    end

    if type(C_QuestLog) == "table" and type(C_QuestLog.GetTitleForQuestID) == "function" then
        local title = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestInfoByQuestID) == "function" then
        local title = SafeCall(C_TaskQuest.GetQuestInfoByQuestID, questID)
        if type(title) == "string" and title ~= "" then
            return title
        end
    end

    return nil
end

local function GetQuestLocation(questID, mapID)
    if type(questID) ~= "number" or type(mapID) ~= "number" then
        return nil, nil
    end

    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestLocation) == "function" then
        local x, y = SafeCall(C_TaskQuest.GetQuestLocation, questID, mapID)
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
    end

    return nil, nil
end

local function IsQuestComplete(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.IsComplete) == "function"
        and SafeCall(C_QuestLog.IsComplete, questID) == true
end

local function IsWorldQuest(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.IsWorldQuest) == "function"
        and SafeCall(C_QuestLog.IsWorldQuest, questID) == true
end

local function IsQuestActive(questID)
    return type(C_QuestLog) == "table"
        and type(C_QuestLog.IsOnQuest) == "function"
        and SafeCall(C_QuestLog.IsOnQuest, questID) == true
end

local function IsTaskQuestActive(questID)
    return type(C_TaskQuest) == "table"
        and type(C_TaskQuest.IsActive) == "function"
        and SafeCall(C_TaskQuest.IsActive, questID) == true
end

local function IsPreyWorldQuest(questID)
    if not PREY_WORLD_QUEST_TYPE or not IsWorldQuest(questID) then
        return PREY_WORLD_QUESTS[questID] == true
    end

    local tagInfo = type(C_QuestLog) == "table"
        and type(C_QuestLog.GetQuestTagInfo) == "function"
        and SafeCall(C_QuestLog.GetQuestTagInfo, questID)
        or nil

    return PREY_WORLD_QUESTS[questID] == true
        or (type(tagInfo) == "table" and tagInfo.worldQuestType == PREY_WORLD_QUEST_TYPE)
end

local function AppendQuestIDs(questIDs, seen, entries)
    if type(entries) ~= "table" then
        return
    end

    for _, info in ipairs(entries) do
        local questID = type(info) == "table" and info.questID or nil
        if type(questID) == "number" and not seen[questID] then
            seen[questID] = true
            questIDs[#questIDs + 1] = questID
        end
    end
end

local function FindPreyWorldQuestOnMap(mapID)
    if type(mapID) ~= "number" then
        return nil
    end

    local questIDs = {}
    local seen = {}

    if type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestsOnMap) == "function" then
        AppendQuestIDs(questIDs, seen, SafeCall(C_QuestLog.GetQuestsOnMap, mapID))
    end
    if type(C_TaskQuest) == "table" and type(C_TaskQuest.GetQuestsOnMap) == "function" then
        AppendQuestIDs(questIDs, seen, SafeCall(C_TaskQuest.GetQuestsOnMap, mapID))
    end

    local fallbackQuestID
    for _, questID in ipairs(questIDs) do
        if IsPreyWorldQuest(questID) and not IsQuestComplete(questID) then
            if IsTaskQuestActive(questID) then
                return questID
            end

            fallbackQuestID = fallbackQuestID or questID
        end
    end

    return fallbackQuestID
end

local function BuildPreyQuestContext()
    local activeQuestID = type(C_QuestLog) == "table"
        and type(C_QuestLog.GetActivePreyQuest) == "function"
        and SafeCall(C_QuestLog.GetActivePreyQuest)
        or nil

    if not activeQuestID then
        return {
            activeQuestID = nil,
            worldQuestID = nil,
            trackedQuestID = nil,
            mapID = nil,
        }
    end

    local mapID = GetQuestMapID(activeQuestID)
    local worldQuestID = FindPreyWorldQuestOnMap(mapID)
    if worldQuestID then
        mapID = GetQuestMapID(worldQuestID) or mapID
    end

    local trackedQuestID = worldQuestID
    if not trackedQuestID and not IsQuestComplete(activeQuestID) then
        trackedQuestID = activeQuestID
    end

    return {
        activeQuestID = activeQuestID,
        worldQuestID = worldQuestID,
        trackedQuestID = trackedQuestID,
        mapID = mapID,
    }
end

local function IsRelevantPreyQuest(questID, context)
    if type(questID) ~= "number" then
        return false
    end

    context = context or BuildPreyQuestContext()
    return questID == context.activeQuestID
        or questID == context.worldQuestID
        or questID == context.trackedQuestID
        or PREY_WORLD_QUESTS[questID] == true
end

local function GetActivePreyWidgetInfo()
    if type(C_UIWidgetManager) ~= "table"
        or type(C_UIWidgetManager.GetPowerBarWidgetSetID) ~= "function"
        or type(C_UIWidgetManager.GetAllWidgetsBySetID) ~= "function"
        or type(C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo) ~= "function"
    then
        return nil, nil
    end

    local widgetSetID = SafeCall(C_UIWidgetManager.GetPowerBarWidgetSetID)
    if not widgetSetID then
        return nil, nil
    end

    local widgets = SafeCall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
    if type(widgets) ~= "table" then
        return nil, nil
    end

    for _, widget in ipairs(widgets) do
        if widget.widgetType == WIDGET_TYPE_PREY then
            local info = SafeCall(C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo, widget.widgetID)
            if type(info) == "table" and (info.shownState == nil or info.shownState == WIDGET_SHOWN) then
                return info, widget.widgetID
            end
        end
    end

    return nil, nil
end

local function GetWidgetUpdateID(widgetUpdate)
    if type(widgetUpdate) == "number" then
        return widgetUpdate
    end

    if type(widgetUpdate) ~= "table" then
        return nil
    end

    local widgetID = rawget(widgetUpdate, "widgetID")
    if type(widgetID) == "number" then
        return widgetID
    end

    local widgetInfo = rawget(widgetUpdate, "widgetInfo")
    if type(widgetInfo) == "table" and type(rawget(widgetInfo, "widgetID")) == "number" then
        return rawget(widgetInfo, "widgetID")
    end

    return nil
end

local function GetProgressState(widgetInfo)
    local state = widgetInfo and widgetInfo.progressState or nil
    if PREY_PROGRESS_BY_STATE[state] == nil and Enum and Enum.PreyHuntProgressState then
        local preyState = Enum.PreyHuntProgressState
        PREY_PROGRESS_BY_STATE[preyState.Cold] = 0
        PREY_PROGRESS_BY_STATE[preyState.Warm] = 0.34
        PREY_PROGRESS_BY_STATE[preyState.Hot] = 0.67
        PREY_PROGRESS_BY_STATE[preyState.Final] = 1
        PREY_COLOR_BY_STATE[preyState.Cold] = PREY_COLOR_BY_STATE[0]
        PREY_COLOR_BY_STATE[preyState.Warm] = PREY_COLOR_BY_STATE[1]
        PREY_COLOR_BY_STATE[preyState.Hot] = PREY_COLOR_BY_STATE[2]
        PREY_COLOR_BY_STATE[preyState.Final] = PREY_COLOR_BY_STATE[3]
        PREY_LABEL_BY_STATE[preyState.Cold] = PREY_LABEL_BY_STATE[0]
        PREY_LABEL_BY_STATE[preyState.Warm] = PREY_LABEL_BY_STATE[1]
        PREY_LABEL_BY_STATE[preyState.Hot] = PREY_LABEL_BY_STATE[2]
        PREY_LABEL_BY_STATE[preyState.Final] = PREY_LABEL_BY_STATE[3]
        PREY_ATLAS_BY_STATE[preyState.Cold] = PREY_ATLAS_BY_STATE[0]
        PREY_ATLAS_BY_STATE[preyState.Warm] = PREY_ATLAS_BY_STATE[1]
        PREY_ATLAS_BY_STATE[preyState.Hot] = PREY_ATLAS_BY_STATE[2]
        PREY_ATLAS_BY_STATE[preyState.Final] = PREY_ATLAS_BY_STATE[3]
    end

    if PREY_PROGRESS_BY_STATE[state] == nil then
        return nil
    end

    return state
end

local function GetAnchorTarget(widgetID)
    local container = _G.UIWidgetPowerBarContainerFrame
    if type(container) ~= "table" or type(container.GetObjectType) ~= "function" or container:GetObjectType() ~= "Frame" then
        return UIParent, nil
    end

    if type(container.widgetFrames) == "table" and container.widgetFrames[widgetID] then
        return container.widgetFrames[widgetID], container
    end

    if type(container.widgetIdToWidgetFrameMap) == "table" and container.widgetIdToWidgetFrameMap[widgetID] then
        return container.widgetIdToWidgetFrameMap[widgetID], container
    end

    if type(container.GetChildren) == "function" then
        local children = { container:GetChildren() }
        for _, child in ipairs(children) do
            if child and type(child.GetObjectType) == "function" and child:GetObjectType() == "Frame" then
                local childWidgetID = child.widgetID
                if childWidgetID == nil and type(child.GetWidgetID) == "function" then
                    childWidgetID = SafeCall(child.GetWidgetID, child)
                end
                if childWidgetID == widgetID then
                    return child, container
                end
            end
        end
    end

    return container, container
end

local function HideFrame(frame, hiddenStore)
    if not frame or type(frame.SetAlpha) ~= "function" then
        return
    end

    if not hiddenStore[frame] then
        hiddenStore[frame] = {
            alpha = type(frame.GetAlpha) == "function" and frame:GetAlpha() or 1,
            shown = type(frame.IsShown) == "function" and frame:IsShown() == true or false,
        }
    end

    if type(frame.Hide) == "function" then
        frame:Hide()
    end
    frame:SetAlpha(0)
end

local function RestoreHiddenFrames(hiddenStore)
    for frame, state in pairs(hiddenStore) do
        if type(frame.SetAlpha) == "function" then
            frame:SetAlpha(state.alpha or 1)
        end
        if state.shown and type(frame.Show) == "function" then
            frame:Show()
        end
        hiddenStore[frame] = nil
    end
end

local function SelectBestGossipOption(options, difficulty)
    if type(options) ~= "table" or #options == 0 then
        return nil
    end

    local difficultyPatterns = DIFFICULTY_PATTERNS[difficulty] or DIFFICULTY_PATTERNS.normal
    for _, option in ipairs(options) do
        if TextContainsAny(option.name, difficultyPatterns) and TextContainsAny(option.name, RANDOM_PATTERNS) then
            return option
        end
    end

    for _, option in ipairs(options) do
        if TextContainsAny(option.name, difficultyPatterns) then
            return option
        end
    end

    for _, option in ipairs(options) do
        if TextContainsAny(option.name, RANDOM_PATTERNS) then
            return option
        end
    end

    table.sort(options, function(left, right)
        local leftOrder = left.orderIndex or left.gossipOptionID or 0
        local rightOrder = right.orderIndex or right.gossipOptionID or 0
        return leftOrder < rightOrder
    end)

    if difficulty == "hard" then
        return options[math.min(2, #options)]
    end
    if difficulty == "nightmare" then
        return options[math.min(3, #options)]
    end

    return options[1]
end

local function SelectBestAvailableQuest(availableQuests, difficulty)
    if type(availableQuests) ~= "table" or #availableQuests == 0 then
        return nil
    end

    local difficultyPatterns = DIFFICULTY_PATTERNS[difficulty] or DIFFICULTY_PATTERNS.normal
    for _, info in ipairs(availableQuests) do
        local title = info.title or info.name or info.questName
        if TextContainsAny(title, difficultyPatterns) and TextContainsAny(title, RANDOM_PATTERNS) then
            return info
        end
    end

    if #availableQuests == 1 then
        return availableQuests[1]
    end

    return nil
end

local function BuildRewardChoice(index)
    local lootType = type(GetQuestItemInfoLootType) == "function" and SafeCall(GetQuestItemInfoLootType, "choice", index) or
    nil
    local itemInfo = type(GetQuestItemInfo) == "function" and { SafeCall(GetQuestItemInfo, "choice", index) } or nil
    local currencyInfo = type(C_QuestOffer) == "table" and type(C_QuestOffer.GetQuestRewardCurrencyInfo) == "function"
        and SafeCall(C_QuestOffer.GetQuestRewardCurrencyInfo, "choice", index)
        or nil
    local itemLink = type(GetQuestItemLink) == "function" and SafeCall(GetQuestItemLink, "choice", index) or nil

    return {
        index = index,
        lootType = lootType,
        itemName = itemInfo and itemInfo[1] or nil,
        itemID = itemInfo and itemInfo[6] or nil,
        itemLink = itemLink,
        currencyID = currencyInfo and currencyInfo.currencyID or nil,
        currencyName = currencyInfo and currencyInfo.name or nil,
    }
end

local function ClassifyRewardType(choice)
    if not choice then
        return nil
    end

    if DAWNCREST_CURRENCY_IDS[choice.currencyID] then
        return "dawncrest"
    end
    if choice.currencyID == REMNANT_CURRENCY_ID then
        return "remnant"
    end
    if choice.currencyID == VOIDLIGHT_MARL_CURRENCY_ID then
        return "marl"
    end
    if tonumber(choice.lootType) == 2 then
        return "gold"
    end

    local text = table.concat({
        choice.itemName or "",
        choice.itemLink or "",
        choice.currencyName or "",
    }, " ")

    for rewardType, patterns in pairs(REWARD_PATTERNS) do
        if TextContainsAny(text, patterns) then
            return rewardType
        end
    end

    return nil
end

local function ResolveRewardChoiceIndex(preferredReward, fallbackReward)
    local numChoices = type(GetNumQuestChoices) == "function" and SafeCall(GetNumQuestChoices) or 0
    if not numChoices or numChoices <= 0 then
        return 0
    end

    local fallbackIndex
    for index = 1, numChoices do
        local rewardType = ClassifyRewardType(BuildRewardChoice(index))
        if rewardType == preferredReward then
            return index
        end
        if rewardType == fallbackReward then
            fallbackIndex = fallbackIndex or index
        end
    end

    return fallbackIndex
end

local function RememberBaseFont(fontString)
    if not fontString or rawget(fontString, "__twichuiBaseFont") then
        return
    end

    local path, size, flags = fontString:GetFont()
    fontString.__twichuiBaseFont = {
        path = path,
        size = size,
        flags = flags or "",
    }
end

local function ApplyConfiguredFont(fontString, fontKey, fontSize, outlineStyle)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return
    end

    RememberBaseFont(fontString)
    local baseFont = rawget(fontString, "__twichuiBaseFont") or {}
    local fontPath = baseFont.path or STANDARD_TEXT_FONT
    local resolvedSize = tonumber(fontSize) or baseFont.size or 12
    local resolvedFlags = ResolveOutlineStyle(outlineStyle, baseFont.flags)
    local LSM = T.Libs and T.Libs.LSM

    if fontKey and fontKey ~= "__default" and LSM and type(LSM.Fetch) == "function" then
        local fetched = LSM:Fetch("font", fontKey, true)
        if fetched and fetched ~= "" then
            fontPath = fetched
        end
    end

    fontString:SetFont(fontPath, resolvedSize, resolvedFlags)
end

function PT:PlayConfiguredSound(soundKey)
    local LSM = T.Libs and T.Libs.LSM
    local soundPath = LSM and LSM.Fetch and LSM:Fetch("sound", soundKey)
    if type(soundPath) == "string" and soundPath ~= "" then
        PlaySoundFile(soundPath, "Master")
    end
end

function PT:CreateOverlay()
    if self.frame then
        return
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(220, 180)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(40)
    frame:Hide()
    self.frame = frame

    local ring = CreateFrame("Frame", nil, frame)
    ring:SetSize(130, 130)
    ring:SetPoint("CENTER", frame, "CENTER")
    ring.progress = CreateFrame("Cooldown", nil, ring, "TwichUIPreyRadialProgressBarTemplate")
    ring.progress:SetAllPoints()
    ring.progress.noCooldownCount = true
    ring.progress.visualOffset = 0.07
    if ring.progress.SetHideCountdownNumbers then
        ring.progress:SetHideCountdownNumbers(true)
    end
    if ring.progress.SetDrawBling then
        ring.progress:SetDrawBling(false)
    end
    if ring.progress.Border then
        ring.progress.Border:SetTexture(RADIAL_RING_TEXTURE)
        ring.progress.Border:SetTexCoord(unpack(RING_BORDER_TEX_COORD))
    end
    if ring.progress.BorderHighlight then
        ring.progress.BorderHighlight:SetTexture(RADIAL_RING_TEXTURE)
        ring.progress.BorderHighlight:SetTexCoord(unpack(RING_BORDER_TEX_COORD))
        ring.progress.BorderHighlight:SetVertexColor(1, 1, 1, 1)
        ring.progress.BorderHighlight:Hide()
    end
    if ring.progress.SetSwipeTexture then
        ring.progress:SetSwipeTexture(RADIAL_RING_TEXTURE)
    end
    if ring.progress.SetTexCoordRange then
        ring.progress:SetTexCoordRange(
            { x = RING_SWIPE_TEX_COORD[1], y = RING_SWIPE_TEX_COORD[3] },
            { x = RING_SWIPE_TEX_COORD[2], y = RING_SWIPE_TEX_COORD[4] }
        )
    end
    if ring.progress.SetDrawSwipe then
        ring.progress:SetDrawSwipe(true)
    end
    if ring.progress.SetDrawEdge then
        ring.progress:SetDrawEdge(false)
    end
    ring.icon = ring:CreateTexture(nil, "ARTWORK")
    ring.icon:SetSize(54, 54)
    ring.icon:SetPoint("CENTER")
    ring.glow = ring:CreateTexture(nil, "OVERLAY")
    ring.glow:SetTexture(RADIAL_RING_TEXTURE)
    ring.glow:SetTexCoord(unpack(RING_BORDER_TEX_COORD))
    ring.glow:SetBlendMode("ADD")
    ring.glow:SetAlpha(0.12)
    ring.glow:SetSize(136, 136)
    ring.glow:SetPoint("CENTER")
    ring.value = ring:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    ring.value:SetPoint("CENTER", ring, "BOTTOM", 0, 25)
    ring.stage = ring:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ring.stage:SetPoint("TOP", ring.value, "BOTTOM", 0, -4)
    self.ringFrame = ring

    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetSize(170, 24)
    bar:SetPoint("CENTER", frame, "CENTER")
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.05, 0.05, 0.05, 0.8)
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar:SetStatusBarTexture(bar.fill)
    bar.value = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bar.value:SetPoint("CENTER")
    bar.stage = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.stage:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4)
    self.barFrame = bar

    local text = CreateFrame("Frame", nil, frame)
    text:SetSize(180, 52)
    text:SetPoint("CENTER", frame, "CENTER")
    text.stage = text:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    text.stage:SetPoint("TOP", 0, 0)
    text.value = text:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text.value:SetPoint("TOP", text.stage, "BOTTOM", 0, -3)
    self.textFrame = text
    self:ApplyTextStyles()
end

function PT:ApplyTextStyles()
    local options = GetOptions()
    if not options then
        return
    end

    ApplyConfiguredFont(self.ringFrame and self.ringFrame.value, options:GetValueFont(), options:GetValueFontSize(),
        options:GetValueFontOutline())
    ApplyConfiguredFont(self.barFrame and self.barFrame.value, options:GetValueFont(), options:GetValueFontSize(),
        options:GetValueFontOutline())
    ApplyConfiguredFont(self.textFrame and self.textFrame.value, options:GetValueFont(), options:GetValueFontSize(),
        options:GetValueFontOutline())

    ApplyConfiguredFont(self.ringFrame and self.ringFrame.stage, options:GetStageFont(), options:GetStageFontSize(),
        options:GetStageFontOutline())
    ApplyConfiguredFont(self.barFrame and self.barFrame.stage, options:GetStageFont(), options:GetStageFontSize(),
        options:GetStageFontOutline())
    ApplyConfiguredFont(self.textFrame and self.textFrame.stage, options:GetStageFont(), options:GetStageFontSize(),
        options:GetStageFontOutline())
end

function PT:ApplyRingBackgroundStyle()
    local options = GetOptions()
    local ring = self.ringFrame
    if not options or not ring or not ring.progress then
        return
    end

    local style = options.GetRingBackgroundStyle and options:GetRingBackgroundStyle() or "full"
    local borderAlpha = 1
    local glowAlpha = 0.12

    if style == "none" then
        borderAlpha = 0
        glowAlpha = 0
    elseif style == "faint" then
        borderAlpha = 0.35
        glowAlpha = 0.05
    end

    if ring.progress.Border and ring.progress.Border.SetAlpha then
        ring.progress.Border:SetAlpha(borderAlpha)
    end
    if ring.glow and ring.glow.SetAlpha then
        ring.glow:SetAlpha(glowAlpha)
    end
end

function PT:ApplyRadialPercentage(percentage)
    local progress = self.ringFrame and self.ringFrame.progress
    if not progress or type(progress.SetCooldown) ~= "function" then
        return
    end

    percentage = Clamp01(percentage)
    if percentage > 0 and percentage < 1 then
        local visualOffset = progress.visualOffset or 0.07
        percentage = (visualOffset * (1 - percentage)) + ((1 - visualOffset) * percentage)
    end

    if type(progress.Pause) == "function" then
        progress:Pause()
    end

    progress:SetCooldown(GetTime() - (100 * percentage), 100)
    if progress.SetDrawEdge then
        progress:SetDrawEdge(false)
    end
end

function PT:ShowTestSnapshot(progressState, progress)
    progress = Clamp01(progress)
    local liveSnapshot = self:BuildSnapshot()
    self.testSnapshot = {
        active = true,
        widgetID = liveSnapshot and liveSnapshot.widgetID or self.lastLiveWidgetID,
        questID = nil,
        activeQuestID = nil,
        worldQuestID = nil,
        mapID = nil,
        progressState = progressState,
        progress = progress,
        percent = RoundPercent(progress),
    }

    self:RefreshNow("test")
end

function PT:ClearTestSnapshot()
    self.testSnapshot = nil
    self:RefreshNow("test-clear")
end

function PT:ApplyBarTexture()
    local bar = self.barFrame
    if not bar then
        return
    end

    local options = GetOptions()
    local LSM = T.Libs and T.Libs.LSM
    local texture = LSM and LSM.Fetch and LSM:Fetch("statusbar", options:GetBarTexture())
    if type(texture) ~= "string" or texture == "" then
        texture = "Interface\\TargetingFrame\\UI-StatusBar"
    end

    bar.fill:SetTexture(texture)
    bar:SetStatusBarTexture(bar.fill)
end

function PT:BuildSnapshot()
    local context = BuildPreyQuestContext()
    local widgetInfo, widgetID = GetActivePreyWidgetInfo()
    local progressState = GetProgressState(widgetInfo)

    if not context.trackedQuestID or progressState == nil then
        return {
            active = false,
            widgetID = widgetID,
            questID = context.trackedQuestID,
            activeQuestID = context.activeQuestID,
            worldQuestID = context.worldQuestID,
            mapID = context.mapID,
            progressState = nil,
            progress = 0,
            percent = 0,
        }
    end

    local progress = Clamp01(PREY_PROGRESS_BY_STATE[progressState] or 0)
    return {
        active = true,
        widgetID = widgetID,
        questID = context.trackedQuestID,
        activeQuestID = context.activeQuestID,
        worldQuestID = context.worldQuestID,
        mapID = context.mapID,
        progressState = progressState,
        progress = progress,
        percent = RoundPercent(progress),
    }
end

function PT:BuildPreyReadyNotificationInfo(snapshot)
    if type(snapshot) ~= "table" or snapshot.active ~= true or type(snapshot.questID) ~= "number" then
        return nil
    end

    local questTitle = GetQuestTitle(snapshot.questID) or "Prey Hunt"
    local progressState = snapshot.progressState
    local stageLabel = PREY_LABEL_BY_STATE[progressState] or "ACTIVE"
    local percent = type(snapshot.percent) == "number" and snapshot.percent or RoundPercent(snapshot.progress or 0)
    local atlasName = PREY_ATLAS_BY_STATE[progressState] or PREY_ATLAS_BY_STATE[0]
    local mapID = snapshot.mapID or GetQuestMapID(snapshot.questID)
    local x, y = GetQuestLocation(snapshot.questID, mapID)

    return {
        questID = snapshot.questID,
        mapID = mapID,
        x = x,
        y = y,
        titleText = questTitle,
        detailText = ("%s prey active at %d%%."):format(stageLabel, percent),
        statusText = "PREY READY",
        atlasName = atlasName,
        buttonText = "Set Waypoint",
    }
end

function PT:SendReadyNotification(snapshot)
    local toasts = T:GetModule("ToastsModule", true)
    if not toasts or type(toasts.SendPreyNotification) ~= "function" then
        return false
    end

    if type(toasts.IsPreyNotificationEnabled) == "function" and not toasts:IsPreyNotificationEnabled() then
        return false
    end

    local info = self:BuildPreyReadyNotificationInfo(snapshot)
    if info then
        toasts:SendPreyNotification(info)
        return true
    end

    return false
end

function PT:HandleReadyNotification(snapshot)
    if type(snapshot) ~= "table" or snapshot.active ~= true then
        self.lastNotifiedPreyQuestID = nil
        return
    end

    local questID = snapshot.questID
    if type(questID) ~= "number" then
        return
    end

    if self.lastNotifiedPreyQuestID ~= questID then
        if self:SendReadyNotification(snapshot) then
            self.lastNotifiedPreyQuestID = questID
        end
    end
end

function PT:ApplyWidgetVisibility(snapshot)
    local options = GetOptions()
    if not options:GetHideBlizzardWidget() or not snapshot.active or not snapshot.widgetID then
        RestoreHiddenFrames(self.hiddenFrames)
        return
    end

    local widgetFrame = select(1, GetAnchorTarget(snapshot.widgetID))
    if widgetFrame and widgetFrame ~= _G.UIWidgetPowerBarContainerFrame then
        HideFrame(widgetFrame, self.hiddenFrames)
    end
end

function PT:PositionOverlay(snapshot)
    local options = GetOptions()
    local mode = options:GetDisplayMode()
    local offsetX = 0
    local offsetY = 0

    if mode == "bar" then
        offsetX = options:GetBarOffsetX()
        offsetY = options:GetBarOffsetY()
    elseif mode == "text" then
        offsetX = options:GetTextOffsetX()
        offsetY = options:GetTextOffsetY()
    else
        offsetX = options:GetRingOffsetX()
        offsetY = options:GetRingOffsetY()
    end

    local target = UIParent
    local anchorWidgetID = snapshot.widgetID or self.lastLiveWidgetID
    if anchorWidgetID then
        target = (select(1, GetAnchorTarget(anchorWidgetID))) or UIParent
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", target, "CENTER", offsetX, offsetY)
    self.frame:SetScale(options:GetScale())
end

function PT:UpdateOverlay(snapshot)
    self:CreateOverlay()
    self:ApplyBarTexture()
    self:ApplyTextStyles()
    self:ApplyRingBackgroundStyle()

    local options = GetOptions()
    self.ringFrame:Hide()
    self.barFrame:Hide()
    self.textFrame:Hide()

    if not snapshot.active then
        self.frame:Hide()
        return
    end

    self:PositionOverlay(snapshot)
    self.frame:Show()

    local color = PREY_COLOR_BY_STATE[snapshot.progressState] or PREY_COLOR_BY_STATE[0]
    local stageLabel = PREY_LABEL_BY_STATE[snapshot.progressState] or "COLD"
    local valueText = ("%d%%"):format(snapshot.percent)
    local showValue = options:GetShowValueText()
    local showStage = options:GetShowStageBadge()
    local mode = options:GetDisplayMode()

    if mode == "bar" then
        self.barFrame:SetMinMaxValues(0, 1)
        self.barFrame:SetValue(snapshot.progress)
        self.barFrame.fill:SetVertexColor(color[1], color[2], color[3], 1)
        self.barFrame.value:SetText(showValue and valueText or "")
        self.barFrame.stage:SetText(showStage and stageLabel or "")
        self.barFrame.value:SetTextColor(color[1], color[2], color[3])
        self.barFrame.stage:SetTextColor(color[1], color[2], color[3])
        self.barFrame:Show()
        return
    end

    if mode == "text" then
        self.textFrame.stage:SetText(showStage and stageLabel or "Prey")
        self.textFrame.value:SetText(showValue and valueText or "")
        self.textFrame.stage:SetTextColor(color[1], color[2], color[3])
        self.textFrame.value:SetTextColor(color[1], color[2], color[3])
        self.textFrame:Show()
        return
    end

    local atlas = PREY_ATLAS_BY_STATE[snapshot.progressState] or PREY_ATLAS_BY_STATE[0]
    self:ApplyRadialPercentage(snapshot.progress)
    if self.ringFrame.icon.SetAtlas then
        self.ringFrame.icon:SetAtlas(atlas, true)
    else
        self.ringFrame.icon:SetTexture("Interface\\Prey\\UIPrey2x")
    end
    if self.ringFrame.progress and self.ringFrame.progress.SetSwipeColor then
        self.ringFrame.progress:SetSwipeColor(color[1], color[2], color[3], 0.97)
    end
    self.ringFrame.glow:SetVertexColor(color[1], color[2], color[3])
    self.ringFrame.value:SetText(showValue and valueText or "")
    self.ringFrame.stage:SetText(showStage and stageLabel or "")
    self.ringFrame.value:SetTextColor(color[1], color[2], color[3])
    self.ringFrame.stage:SetTextColor(color[1], color[2], color[3])
    self.ringFrame:Show()
end

function PT:HandlePhaseChangeSound(previousSnapshot, snapshot)
    local options = GetOptions()
    if not options:GetPlayPhaseChangeSound() then
        return
    end

    if not previousSnapshot or not previousSnapshot.active or not snapshot.active then
        return
    end

    local previousState = previousSnapshot.progressState
    local newState = snapshot.progressState
    if type(previousState) ~= "number" or type(newState) ~= "number" or newState <= previousState then
        return
    end

    local now = GetTime()
    if self.lastPhaseSoundAt and (now - self.lastPhaseSoundAt) < 0.5 then
        return
    end

    self.lastPhaseSoundAt = now
    self:PlayConfiguredSound(options:GetPhaseChangeSound())
end

function PT:CleanupOwnedWatch()
    if self.ownedWatchQuestID then
        if type(C_QuestLog) == "table" then
            if IsWorldQuest(self.ownedWatchQuestID) and type(C_QuestLog.RemoveWorldQuestWatch) == "function" then
                SafeCall(C_QuestLog.RemoveWorldQuestWatch, self.ownedWatchQuestID)
            elseif type(C_QuestLog.RemoveQuestWatch) == "function" then
                SafeCall(C_QuestLog.RemoveQuestWatch, self.ownedWatchQuestID)
            end
        end
        self.ownedWatchQuestID = nil
    end
end

function PT:CleanupOwnedSuperTrack()
    if self.ownedSuperTrackedQuestID and type(C_SuperTrack) == "table" and type(C_SuperTrack.GetSuperTrackedQuestID) == "function" then
        if SafeCall(C_SuperTrack.GetSuperTrackedQuestID) == self.ownedSuperTrackedQuestID and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
            SafeCall(C_SuperTrack.SetSuperTrackedQuestID, 0)
        end
        self.ownedSuperTrackedQuestID = nil
    end
end

function PT:CleanupQuestTracking()
    self:CleanupOwnedWatch()
    self:CleanupOwnedSuperTrack()
end

function PT:SyncQuestTracking(snapshot)
    local options = GetOptions()
    local questID = snapshot.questID

    if type(questID) ~= "number" or IsQuestComplete(questID) or (not IsQuestActive(questID) and not IsTaskQuestActive(questID) and not IsWorldQuest(questID)) then
        self:CleanupQuestTracking()
        return
    end

    if options:GetAutoWatchPreyQuest() then
        local watchType = type(C_QuestLog) == "table" and type(C_QuestLog.GetQuestWatchType) == "function"
            and SafeCall(C_QuestLog.GetQuestWatchType, questID)
            or nil
        if watchType == nil then
            if IsWorldQuest(questID) and type(C_QuestLog) == "table" and type(C_QuestLog.AddWorldQuestWatch) == "function" then
                if SafeCall(C_QuestLog.AddWorldQuestWatch, questID, QUEST_WATCH_MANUAL) == true then
                    self.ownedWatchQuestID = questID
                end
            elseif type(C_QuestLog) == "table" and type(C_QuestLog.AddQuestWatch) == "function" then
                if SafeCall(C_QuestLog.AddQuestWatch, questID) == true then
                    self.ownedWatchQuestID = questID
                end
            end
        end
    elseif self.ownedWatchQuestID == questID then
        self:CleanupOwnedWatch()
    end

    if options:GetAutoSuperTrackPreyQuest()
        and type(C_SuperTrack) == "table"
        and type(C_SuperTrack.GetSuperTrackedQuestID) == "function"
        and type(C_SuperTrack.SetSuperTrackedQuestID) == "function"
    then
        if SafeCall(C_SuperTrack.GetSuperTrackedQuestID) ~= questID then
            SafeCall(C_SuperTrack.SetSuperTrackedQuestID, questID)
            self.ownedSuperTrackedQuestID = questID
        end
    elseif self.ownedSuperTrackedQuestID == questID then
        self:CleanupOwnedSuperTrack()
    end
end

function PT:RefreshNow(reason)
    local liveSnapshot = self:BuildSnapshot()
    if liveSnapshot and liveSnapshot.widgetID then
        self.lastLiveWidgetID = liveSnapshot.widgetID
    end

    if not self.testSnapshot then
        self:HandleReadyNotification(liveSnapshot)
    end

    local snapshot = self.testSnapshot or liveSnapshot
    self:HandlePhaseChangeSound(self.lastSnapshot, snapshot)
    self:ApplyWidgetVisibility(snapshot)
    self:UpdateOverlay(snapshot)
    if not self.testSnapshot then
        self:SyncQuestTracking(snapshot)
    end
    self.lastSnapshot = snapshot
end

function PT:ShouldRefreshFromWidgetUpdate(widgetUpdate)
    local widgetID = GetWidgetUpdateID(widgetUpdate)
    if type(widgetID) ~= "number" then
        return true
    end

    if self.lastLiveWidgetID and widgetID == self.lastLiveWidgetID then
        return true
    end

    if self.lastSnapshot and self.lastSnapshot.widgetID and widgetID == self.lastSnapshot.widgetID then
        return true
    end

    return false
end

function PT:HandleRefreshEvent(event, ...)
    if event == "UPDATE_UI_WIDGET" and not self:ShouldRefreshFromWidgetUpdate(...) then
        return
    end

    self:RefreshNow(event)
end

function PT:CanAutoPurchaseHunt()
    local options = GetOptions()
    if not options:GetAutoPurchaseRandomHunt() then
        return false
    end

    if self.lastSnapshot and self.lastSnapshot.active then
        return false
    end

    local context = BuildPreyQuestContext()
    if context.activeQuestID or context.trackedQuestID then
        return false
    end

    if type(UnitGUID) ~= "function" or GetNpcIDFromGUID(UnitGUID("npc")) ~= ASTALOR_NPC_ID then
        return false
    end

    if type(C_CurrencyInfo) ~= "table" or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
        return false
    end

    local info = SafeCall(C_CurrencyInfo.GetCurrencyInfo, REMNANT_CURRENCY_ID)
    local quantity = info and info.quantity or 0
    return quantity >= (50 + options:GetRemnantThreshold())
end

function PT:TryPurchaseRandomHunt()
    if not self:CanAutoPurchaseHunt() then
        return
    end

    local options = GetOptions()
    local difficulty = options:GetRandomHuntDifficulty()

    if type(C_GossipInfo) == "table" and type(C_GossipInfo.GetAvailableQuests) == "function" then
        local availableQuests = SafeCall(C_GossipInfo.GetAvailableQuests)
        local questInfo = SelectBestAvailableQuest(availableQuests, difficulty)
        if questInfo and questInfo.questID and type(C_GossipInfo.SelectAvailableQuest) == "function" then
            C_GossipInfo.SelectAvailableQuest(questInfo.questID)
            self.pendingAutoAccept = true
            return
        end
    end

    if type(C_GossipInfo) == "table" and type(C_GossipInfo.GetOptions) == "function" then
        local optionsList = SafeCall(C_GossipInfo.GetOptions)
        if type(optionsList) == "table" then
            local option = SelectBestGossipOption(optionsList, difficulty)
            if option then
                if option.gossipOptionID and type(C_GossipInfo.SelectOption) == "function" then
                    C_GossipInfo.SelectOption(option.gossipOptionID, "", true)
                    self.pendingAutoAccept = true
                    return
                end
                if option.orderIndex and type(C_GossipInfo.SelectOptionByIndex) == "function" then
                    C_GossipInfo.SelectOptionByIndex(option.orderIndex, "", true)
                    self.pendingAutoAccept = true
                end
            end
        end
    end
end

function PT:QUEST_DETAIL()
    if not self.pendingAutoAccept then
        return
    end

    self.pendingAutoAccept = nil
    if type(QuestGetAutoAccept) == "function" and QuestGetAutoAccept() and type(AcknowledgeAutoAcceptQuest) == "function" then
        AcknowledgeAutoAcceptQuest()
        return
    end

    if type(AcceptQuest) == "function" then
        AcceptQuest()
    end
end

function PT:QUEST_AUTOCOMPLETE(event, questID)
    local options = GetOptions()
    if options:GetAutoTurnInPreyQuest() and IsRelevantPreyQuest(questID) and type(ShowQuestComplete) == "function" then
        ShowQuestComplete(questID)
    end
end

function PT:TryResolveRewardSelection()
    local options = GetOptions()
    local currentQuestID = type(GetQuestID) == "function" and SafeCall(GetQuestID) or nil
    local questID = currentQuestID or self.pendingRewardQuestID

    if not IsRelevantPreyQuest(questID) then
        self.pendingRewardQuestID = nil
        self.pendingRewardRetries = 0
        return true
    end

    local rewardIndex = 0
    if options:GetAutoSelectHuntReward() then
        rewardIndex = ResolveRewardChoiceIndex(options:GetPreferredHuntReward(), options:GetFallbackHuntReward())
        if rewardIndex == nil then
            return false
        end
    else
        local numChoices = type(GetNumQuestChoices) == "function" and SafeCall(GetNumQuestChoices) or 0
        if numChoices and numChoices > 1 then
            return true
        end
    end

    if type(GetQuestReward) == "function" then
        SafeCall(GetQuestReward, rewardIndex or 0)
    end
    self.pendingRewardQuestID = nil
    self.pendingRewardRetries = 0
    return true
end

function PT:ScheduleRewardRetry()
    if self.rewardRetryScheduled then
        return
    end

    self.rewardRetryScheduled = true
    C_Timer.After(0.2, function()
        self.rewardRetryScheduled = nil
        self.pendingRewardRetries = (self.pendingRewardRetries or 0) + 1
        if (self.pendingRewardRetries or 0) > 5 then
            self.pendingRewardQuestID = nil
            self.pendingRewardRetries = 0
            return
        end

        if not self:TryResolveRewardSelection() then
            self:ScheduleRewardRetry()
        end
    end)
end

function PT:QUEST_COMPLETE()
    local options = GetOptions()
    local questID = type(GetQuestID) == "function" and SafeCall(GetQuestID) or nil
    if not IsRelevantPreyQuest(questID) then
        return
    end

    if not options:GetAutoTurnInPreyQuest() and not options:GetAutoSelectHuntReward() then
        return
    end

    self.pendingRewardQuestID = questID
    self.pendingRewardRetries = 0
    if not self:TryResolveRewardSelection() then
        self:ScheduleRewardRetry()
    end
end

function PT:GOSSIP_SHOW()
    self:TryPurchaseRandomHunt()
end

function PT:OnEnable()
    self.hiddenFrames = self.hiddenFrames or setmetatable({}, { __mode = "k" })
    self:CreateOverlay()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleRefreshEvent")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_ACCEPTED", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_TURNED_IN", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_REMOVED", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_LOG_UPDATE", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_LOG_CRITERIA_UPDATE", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_POI_UPDATE", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_WATCH_LIST_CHANGED", "HandleRefreshEvent")
    self:RegisterEvent("SUPER_TRACKING_CHANGED", "HandleRefreshEvent")
    self:RegisterEvent("TASK_PROGRESS_UPDATE", "HandleRefreshEvent")
    self:RegisterEvent("UPDATE_ALL_UI_WIDGETS", "HandleRefreshEvent")
    self:RegisterEvent("UPDATE_UI_WIDGET", "HandleRefreshEvent")
    self:RegisterEvent("QUEST_ITEM_UPDATE", "HandleRefreshEvent")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("QUEST_AUTOCOMPLETE")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RefreshNow("enable")
end

function PT:OnDisable()
    self:UnregisterAllEvents()
    if self.refreshTimer then
        self:CancelTimer(self.refreshTimer)
        self.refreshTimer = nil
    end
    self:CleanupQuestTracking()
    RestoreHiddenFrames(self.hiddenFrames or {})
    if self.frame then
        self.frame:Hide()
    end
    self.lastSnapshot = nil
    self.pendingAutoAccept = nil
    self.pendingRewardQuestID = nil
    self.pendingRewardRetries = 0
    self.testSnapshot = nil
    self.lastNotifiedPreyQuestID = nil
end
