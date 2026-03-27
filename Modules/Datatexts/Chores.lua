---@diagnostic disable: undefined-field
--[[
    Datatext showing remaining weekly chores.
]]
local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")
local LSM = T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)

local GetAccountExpansionLevel = _G.GetAccountExpansionLevel
local GetLFGDungeonInfo = _G.GetLFGDungeonInfo
local GetNumRFDungeons = _G.GetNumRFDungeons
local GetRFDungeonInfo = _G.GetRFDungeonInfo
local LegacyLoadAddOn = _G.LoadAddOn
local PVEFrameLoadUI = _G.PVEFrame_LoadUI
local PlaySoundFile = _G.PlaySoundFile
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local C_Item = _G.C_Item
local C_Map = _G.C_Map
local C_SuperTrack = _G.C_SuperTrack
local GameTooltip = _G.GameTooltip
local IsShiftKeyDown = _G.IsShiftKeyDown
local UIParent = _G.UIParent
local CreateVector2D = _G.CreateVector2D
local PREY_ICON =
"Interface\\AddOns\\TwichUI_Reformed\\Modules\\Chores\\Plumber\\Art\\ExpansionLandingPage\\Icons\\InProgressPrey.png"

---@class ChoresDataText : AceModule, AceEvent-3.0
---@field definition DatatextDefinition
---@field panel ElvUI_DT_Panel|nil
---@field tooltipFontRestore table<number, {left: table|nil, right: table|nil}>|nil
---@field trackerFrame Frame|nil
local CDT = DataTextModule:NewModule("ChoresDataText", "AceEvent-3.0")

local TRACKER_FRAME_WIDTH = 430
local TRACKER_FRAME_HEIGHT = 420
local TRACKER_MIN_WIDTH = 320
local TRACKER_MIN_HEIGHT = 260
local TRACKER_MAX_WIDTH = 900
local TRACKER_MAX_HEIGHT = 900
local ASTALOR_PREY_MAP_ID = 2393
local ASTALOR_PREY_X = 0.55
local ASTALOR_PREY_Y = 0.634
local plumberSuperTrackFrame = nil

local MENU_CATEGORY_ITEMS = {
    { key = "delves",            name = "Delver's Call",          iconAtlas = "delves-regular" },
    { key = "abundance",         name = "Abundance",              iconAtlas = "UI-EventPoi-abundancebountiful" },
    { key = "unity",             name = "Unity Against the Void", icon = "Interface\\Icons\\Inv_nullstone_void" },
    { key = "hope",              name = "Legends of the Haranir", icon = "Interface\\Icons\\Inv_achievement_zone_harandar" },
    { key = "soiree",            name = "Saltheril's Soiree",     iconAtlas = "UI-EventPoi-saltherilssoiree" },
    { key = "stormarion",        name = "Stormarion Assault",     iconAtlas = "UI-EventPoi-stormarionassault" },
    { key = "specialAssignment", name = "Special Assignment",     iconAtlas = "worldquest-Capstone-questmarker-epic-locked" },
    { key = "dungeon",           name = "Dungeon",                iconAtlas = "Dungeon" },
}

local function GetProfessionMenuItems()
    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if not choresModule or not choresModule.GetProfessionCategoryDefinitions then
        return {}
    end

    return choresModule:GetProfessionCategoryDefinitions() or {}
end

local function GetPreyDifficultyMenuItems()
    ---@type ChoresModule
    local choresModule = T:GetModule("Chores")
    if not choresModule or not choresModule.GetPreyDifficultyDefinitions then
        return {}
    end

    return choresModule:GetPreyDifficultyDefinitions() or {}
end

local function GetDatatextOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.Datatext
end

local function GetChoresOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.Chores
end

local function GetSatchelWatchOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.SatchelWatch
end

local function GetChoresDatatextDB()
    local options = GetDatatextOptions()
    return options and options.GetDatatextDB and options:GetDatatextDB("chores") or {}
end

local function GetChoresModule()
    ---@type ChoresModule
    return T:GetModule("Chores")
end

local function BuildEntryDisplayTitle(summary, entry)
    local title = (entry and entry.state and entry.state.title) or (summary and summary.name) or "Chore"
    local timeRemainingText = entry and entry.state and entry.state.timeRemainingText or nil
    if timeRemainingText then
        return ("%s |cff7f8c8d(%s left)|r"):format(title, timeRemainingText)
    end

    return title
end

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

local function GetCurrentExpansionRaidWings()
    EnsureGroupFinderLoaded()

    local raidWings = {}
    local currentExpansionLevel = type(GetAccountExpansionLevel) == "function" and GetAccountExpansionLevel() or nil

    if type(GetNumRFDungeons) ~= "function" or type(GetRFDungeonInfo) ~= "function" then
        return raidWings
    end

    for index = 1, GetNumRFDungeons() do
        local dungeonID = GetRFDungeonInfo(index)
        local name
        local expansionLevel

        if type(dungeonID) == "number" then
            name, _, _, _, _, _, _, _, expansionLevel = GetLFGDungeonInfo(dungeonID)
        end

        if type(dungeonID) == "number" and dungeonID > 0 and name and (not currentExpansionLevel or expansionLevel == currentExpansionLevel) then
            table.insert(raidWings, {
                dungeonID = dungeonID,
                name = name,
            })
        end
    end

    table.sort(raidWings, function(left, right)
        return left.name < right.name
    end)

    return raidWings
end

local function GetValueColor()
    local options = GetDatatextOptions()
    if options:GetChoresUseCustomColor() then
        return options:GetChoresTextColor()
    end
    return DataTextModule:GetElvUIValueColor()
end

local function GetDoneValueColor()
    local options = GetDatatextOptions()
    if options and options.GetChoresUseCustomDoneColor and options:GetChoresUseCustomDoneColor() then
        return options:GetChoresDoneTextColor()
    end

    return 0.2, 0.82, 0.32, 1
end

local function GetTooltipFontSettings()
    local options = GetDatatextOptions()
    local headerFontName = options:GetChoresTooltipHeaderFont()
    local entryFontName = options:GetChoresTooltipEntryFont()

    local headerFont = LSM and headerFontName and LSM:Fetch("font", headerFontName, true) or nil
    local entryFont = LSM and entryFontName and LSM:Fetch("font", entryFontName, true) or nil

    if not headerFont or headerFont == "" then
        headerFont = STANDARD_TEXT_FONT
    end

    if not entryFont or entryFont == "" then
        entryFont = STANDARD_TEXT_FONT
    end

    return {
        headerFont = headerFont,
        headerFontSize = options:GetChoresTooltipHeaderFontSize(),
        entryFont = entryFont,
        entryFontSize = options:GetChoresTooltipEntryFontSize(),
    }
end

local function GetTrackerHeaderFontSettings()
    local tooltipFontSettings = GetTooltipFontSettings()
    local choresOptions = GetChoresOptions()
    local trackerHeaderFont = choresOptions and choresOptions.GetTrackerHeaderFont and
        choresOptions:GetTrackerHeaderFont() or
        "__tooltipHeader"

    if trackerHeaderFont == "__tooltipHeader" then
        return {
            font = tooltipFontSettings.headerFont,
            fontSize = tooltipFontSettings.headerFontSize,
        }
    end

    local resolvedFont = LSM and trackerHeaderFont and LSM:Fetch("font", trackerHeaderFont, true) or nil
    if not resolvedFont or resolvedFont == "" then
        resolvedFont = tooltipFontSettings.headerFont or STANDARD_TEXT_FONT
    end

    return {
        font = resolvedFont,
        fontSize = tooltipFontSettings.headerFontSize,
    }
end

local function GetTrackerDB()
    local db = GetChoresDatatextDB()
    db.tracker = db.tracker or {}
    return db.tracker
end

local function GetTrackerPositionDB()
    local db = GetTrackerDB()
    db.position = db.position or {}
    return db.position
end

local function GetTrackerSizeDB()
    local db = GetTrackerDB()
    db.size = db.size or {}
    return db.size
end

local function GetTrackerCollapsedSectionsDB()
    local db = GetTrackerDB()
    db.collapsedSections = db.collapsedSections or {}
    return db.collapsedSections
end

local function IsTrackerLockedDB()
    return GetTrackerDB().locked == true
end

local function GetBackdropColors()
    local bgR, bgG, bgB, bgA = 0.06, 0.06, 0.08, 0.98
    local borderR, borderG, borderB = 0.25, 0.25, 0.3
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.media then
        if E.media.backdropcolor then
            bgR, bgG, bgB = unpack(E.media.backdropcolor)
        elseif E.media.backdropfadecolor then
            bgR, bgG, bgB = unpack(E.media.backdropfadecolor)
        end

        if E.media.bordercolor then
            borderR, borderG, borderB = unpack(E.media.bordercolor)
        end
    end

    return bgR, bgG, bgB, bgA, borderR, borderG, borderB
end

local function GetTrackerAppearanceSettings()
    local options = GetChoresOptions()
    local mode = options and options.GetTrackerFrameMode and options:GetTrackerFrameMode() or "framed"
    local frameAlpha = options and options.GetTrackerFrameTransparency and options:GetTrackerFrameTransparency() or 1
    local backgroundAlpha = options and options.GetTrackerBackgroundTransparency and
        options:GetTrackerBackgroundTransparency() or 0.95

    frameAlpha = math.min(1, math.max(0.2, frameAlpha or 1))
    backgroundAlpha = math.min(1, math.max(0, backgroundAlpha or 0.95))

    return {
        mode = mode,
        frameAlpha = frameAlpha,
        backgroundAlpha = backgroundAlpha,
    }
end

local function GetTrackedRaidWingIDs()
    local choresOptions = GetChoresOptions()
    local raidWingIDs = {}

    if not choresOptions or not choresOptions.IsRaidWingEnabled then
        return raidWingIDs
    end

    for _, raidWing in ipairs(GetCurrentExpansionRaidWings()) do
        if choresOptions:IsRaidWingEnabled(raidWing.dungeonID) then
            raidWingIDs[raidWing.dungeonID] = true
        end
    end

    return raidWingIDs
end

local function ConfigureSatchelWatchForTrackedRaidWings()
    local satchelOptions = GetSatchelWatchOptions()
    if not satchelOptions or not satchelOptions.GetSatchelWatchDB then
        return false
    end

    local db = satchelOptions:GetSatchelWatchDB()
    local trackedRaidWingIDs = GetTrackedRaidWingIDs()
    local hasTrackedRaidWing = false

    for _, raidWing in ipairs(GetCurrentExpansionRaidWings()) do
        local isTracked = trackedRaidWingIDs[raidWing.dungeonID] == true
        db["raid_" .. raidWing.dungeonID] = isTracked
        hasTrackedRaidWing = hasTrackedRaidWing or isTracked
    end

    if not hasTrackedRaidWing then
        return false
    end

    db.enabled = true
    db.notifyOnlyForRaids = true
    db.notifyForRegularDungeon = false
    db.notifyForHeroicDungeon = false
    db.periodicCheckEnabled = true

    if not db.notifyForTanks and not db.notifyForHealers and not db.notifyForDPS then
        db.notifyForTanks = true
        db.notifyForHealers = true
        db.notifyForDPS = true
    end

    ---@type SatchelWatchModule|nil
    local satchelWatchModule = T:GetModule("QualityOfLife"):GetModule("SatchelWatch", true)
    if satchelWatchModule then
        if not satchelWatchModule:IsEnabled() then
            satchelWatchModule:Enable()
        else
            satchelWatchModule:StartPeriodicRefresh()
        end

        if satchelWatchModule.RefreshAvailability then
            satchelWatchModule:RefreshAvailability(true)
        end
    end

    return true
end

local function IsSatchelWatchConfiguredForTrackedRaidWings()
    local satchelOptions = GetSatchelWatchOptions()
    if not satchelOptions or not satchelOptions.GetSatchelWatchDB then
        return false
    end

    local db = satchelOptions:GetSatchelWatchDB()
    local trackedRaidWingIDs = GetTrackedRaidWingIDs()
    local hasTrackedRaidWing = false

    if db.enabled ~= true or db.notifyOnlyForRaids ~= true or db.notifyForRegularDungeon == true or db.notifyForHeroicDungeon == true then
        return false
    end

    for _, raidWing in ipairs(GetCurrentExpansionRaidWings()) do
        local isTracked = trackedRaidWingIDs[raidWing.dungeonID] == true
        if isTracked then
            hasTrackedRaidWing = true
            if db["raid_" .. raidWing.dungeonID] ~= true then
                return false
            end
        end
    end

    return hasTrackedRaidWing
end

local function PlayTrackerFeedbackSound(soundKey)
    local soundPath = LSM and LSM.Fetch and LSM:Fetch("sound", soundKey)
    if soundPath and type(PlaySoundFile) == "function" then
        PlaySoundFile(soundPath, "Master")
    end
end

local function PrintTrackerFeedbackMessage(message)
    if type(message) ~= "string" or message == "" then
        return
    end

    print(T.Tools.Text.ColorRGB(0.45, 0.78, 1, "TwichUI") .. " " .. message)
end

local function RequestChoresRefresh()
    local choresModule = GetChoresModule()
    if choresModule and choresModule.RequestRefresh then
        choresModule:RequestRefresh(true)
    end

    if DataTextModule and DataTextModule.RefreshDataText then
        DataTextModule:RefreshDataText("TwichUI: Chores")
    end
end

local function IsTrackedSummaryKey(summaryKey)
    if type(summaryKey) ~= "string" or summaryKey == "" then
        return false
    end

    for _, item in ipairs(MENU_CATEGORY_ITEMS) do
        if item.key == summaryKey then
            return true
        end
    end

    for _, item in ipairs(GetProfessionMenuItems()) do
        if item.key == summaryKey then
            return true
        end
    end

    return false
end

local function CanDisableTrackerSummary(summary)
    if type(summary) ~= "table" then
        return false
    end

    if summary.key == "bountifulDelves" or summary.key == "prey" or summary.key == "raidFinder" then
        return true
    end

    return IsTrackedSummaryKey(summary.key)
end

local function DisableTrackerSummary(summary)
    local options = GetChoresOptions()
    if type(summary) ~= "table" or not options then
        return false
    end

    if summary.key == "bountifulDelves" then
        if options.GetTrackBountifulDelves and options:GetTrackBountifulDelves() then
            options:SetTrackBountifulDelves(nil, false)
            return true
        end
        return false
    end

    if summary.key == "prey" then
        if options.GetTrackPrey and options:GetTrackPrey() then
            options:SetTrackPrey(nil, false)
            return true
        end
        return false
    end

    if summary.key == "raidFinder" then
        local raidWingDB = options.GetRaidWingDB and options:GetRaidWingDB() or nil
        local changed = false

        if type(raidWingDB) ~= "table" then
            return false
        end

        for _, raidWing in ipairs(GetCurrentExpansionRaidWings()) do
            if options.IsRaidWingEnabled and options:IsRaidWingEnabled(raidWing.dungeonID) then
                raidWingDB[tostring(raidWing.dungeonID)] = false
                changed = true
            end
        end

        if changed then
            RequestChoresRefresh()
        end

        return changed
    end

    if IsTrackedSummaryKey(summary.key) and options.IsCategoryEnabled and options:IsCategoryEnabled(summary.key) then
        options:SetCategoryEnabled(summary.key, false)
        return true
    end

    return false
end

local function HideTrackerTooltip()
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

local function ShowTrackerHeaderTooltip(button)
    local summary = button and button.summaryData or nil
    if not GameTooltip or not button or not GameTooltip.SetOwner or type(summary) ~= "table" then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(summary.name or "Category")
    GameTooltip:AddLine("Click to collapse or expand this section.", 0.8, 0.8, 0.8, true)
    if CanDisableTrackerSummary(summary) then
        GameTooltip:AddLine("Shift-click to stop tracking this category.", 1, 0.82, 0.2, true)
    end
    GameTooltip:Show()
end

local function ShowTrackerSettingsTooltip(button)
    if not GameTooltip or not button or not GameTooltip.SetOwner then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Chores Settings")
    GameTooltip:AddLine("Open the same quick configuration menu as the Chores datatext.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end

local function ShowRaidSatchelTooltip(button)
    if not GameTooltip or not button or not GameTooltip.SetOwner then
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Watch Satchels")
    GameTooltip:AddLine("Configure Satchel Watch to scan the currently tracked Raid Finder chore wings.", 0.8, 0.8,
        0.8, true)
    GameTooltip:Show()
end

local function ShowQuestTooltip(owner, questID)
    if not GameTooltip or not owner or not GameTooltip.SetOwner or type(questID) ~= "number" or questID <= 0 then
        return false
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if GameTooltip.SetHyperlink then
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, ("quest:%d"):format(questID))
        if ok then
            GameTooltip:Show()
            return true
        end
    end

    GameTooltip:AddLine(C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID) or
        ("Quest #%d"):format(questID))
    GameTooltip:AddLine(("Quest ID: %d"):format(questID), 0.6, 0.6, 0.6)
    GameTooltip:Show()
    return true
end

local function ShowItemTooltip(owner, itemID)
    if not GameTooltip or not owner or not GameTooltip.SetOwner or type(itemID) ~= "number" or itemID <= 0 then
        return false
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
        return true
    end

    if GameTooltip.SetHyperlink then
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, ("item:%d"):format(itemID))
        if ok then
            GameTooltip:Show()
            return true
        end
    end

    return false
end

local function ShowEncounterTooltip(owner, encounters)
    if not GameTooltip or not owner or not GameTooltip.SetOwner or type(encounters) ~= "table" or #encounters == 0 then
        return false
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Bosses", 1, 1, 1)
    GameTooltip:AddLine(" ")
    for _, encounter in ipairs(encounters) do
        if encounter.isCompleted then
            GameTooltip:AddLine(encounter.name, 0.9, 0.2, 0.2)
        else
            GameTooltip:AddLine(encounter.name, 0.9, 0.9, 0.9)
        end
    end
    GameTooltip:Show()
    return true
end

local function ShowPreyWaypointTooltip(owner, tooltipData)
    if not GameTooltip or not owner or not GameTooltip.SetOwner or type(tooltipData) ~= "table" then
        return false
    end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(tooltipData.title or "Prey")
    GameTooltip:AddLine("Click to place a waypoint to Astalor Bloodsworn in Astalor's Sanctum.", 0.8, 0.8, 0.8,
        true)
    GameTooltip:AddLine("Silvermoon City 55.0, 63.4", 1, 0.82, 0.2)
    GameTooltip:Show()
    return true
end

local function FormatWaypointCoordinates(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end

    return ("%.1f, %.1f"):format(x * 100, y * 100)
end

local function AppendWaypointActionTooltip(actionData)
    if not GameTooltip or type(actionData) ~= "table" or actionData.kind ~= "waypoint" then
        return
    end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(actionData.waypointTooltipText or "Click to set a waypoint.", 1, 0.82, 0.2, true)

    if actionData.waypointZone and actionData.waypointName then
        GameTooltip:AddLine(("%s: %s"):format(actionData.waypointZone, actionData.waypointName), 0.8, 0.8, 0.8,
            true)
    elseif actionData.waypointZone then
        GameTooltip:AddLine(actionData.waypointZone, 0.8, 0.8, 0.8, true)
    elseif actionData.waypointName then
        GameTooltip:AddLine(actionData.waypointName, 0.8, 0.8, 0.8, true)
    end

    local coordinateText = FormatWaypointCoordinates(actionData.x, actionData.y)
    if coordinateText then
        GameTooltip:AddLine(coordinateText, 0.8, 0.8, 0.8, true)
    end

    GameTooltip:Show()
end

local function ShowWaypointActionTooltip(owner, actionData)
    if not GameTooltip or not owner or not GameTooltip.SetOwner or type(actionData) ~= "table" then
        return false
    end

    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(actionData.waypointName or "Waypoint")
    AppendWaypointActionTooltip(actionData)
    return true
end

local function GetPlumberSuperTrackFrame()
    if plumberSuperTrackFrame and plumberSuperTrackFrame.SetTarget then
        return plumberSuperTrackFrame
    end

    if not _G.PlumberSuperTrackingMixin or type(_G.CreateFrame) ~= "function" then
        return nil
    end

    plumberSuperTrackFrame = _G.CreateFrame("Frame", nil, UIParent, "PlumberSuperTrackingTemplate")
    if plumberSuperTrackFrame.TryEnableByModule then
        plumberSuperTrackFrame:TryEnableByModule()
    end
    if plumberSuperTrackFrame.CheckInitializeNavigationFrame then
        plumberSuperTrackFrame:CheckInitializeNavigationFrame()
    end

    if plumberSuperTrackFrame.enabled and plumberSuperTrackFrame.frameReady and plumberSuperTrackFrame.SetTarget then
        return plumberSuperTrackFrame
    end

    return nil
end

local function TrySetMapPinEnhancedWaypoint(mapID, x, y, waypointName)
    local mapPinEnhanced = _G.MapPinEnhanced
    if not mapPinEnhanced or type(mapPinEnhanced.GetModule) ~= "function" then
        return false
    end

    local ok, pinManager = pcall(mapPinEnhanced.GetModule, mapPinEnhanced, "PinManager")
    if not ok or type(pinManager) ~= "table" or type(pinManager.AddPin) ~= "function" then
        return false
    end

    if type(pinManager.UntrackTrackedPin) == "function" then
        pcall(pinManager.UntrackTrackedPin, pinManager)
    end

    local title = type(waypointName) == "string" and waypointName ~= "" and waypointName or "Waypoint"
    local success = pcall(pinManager.AddPin, pinManager, {
        mapID = mapID,
        x = x,
        y = y,
        title = title,
        setTracked = true,
        lock = true,
    })

    return success
end

local function SetWaypoint(mapID, x, y, questID, waypointName)
    if type(mapID) == "number" and type(x) == "number" and type(y) == "number" then
        if TrySetMapPinEnhancedWaypoint(mapID, x, y, waypointName) then
            return true
        end
    end

    local namedFrame = type(waypointName) == "string" and waypointName ~= "" and GetPlumberSuperTrackFrame() or nil
    if namedFrame then
        namedFrame:SetTarget(waypointName, mapID, x, y)
        return true
    end

    if type(mapID) == "number" and type(x) == "number" and type(y) == "number"
        and type(CreateVector2D) == "function"
        and C_Map and type(C_Map.SetUserWaypoint) == "function"
    then
        C_Map.SetUserWaypoint({
            uiMapID = mapID,
            position = CreateVector2D(x, y),
        })

        if C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint) == "function" then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end

        return true
    end

    if type(questID) == "number" and C_SuperTrack and type(C_SuperTrack.SetSuperTrackedQuestID) == "function" then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
        return true
    end

    return false
end

local function GetTrackerEntryTooltipData(entry)
    local state = entry and entry.state or nil
    local data = entry and entry.data or nil

    if type(state) == "table" and type(state.encounters) == "table" and #state.encounters > 0 then
        return {
            kind = "encounters",
            encounters = state.encounters,
        }
    end

    if type(data) == "table" and type(data.key) == "string" and data.key:match("^prey%-") then
        return {
            kind = "preyWaypoint",
            title = state and state.title or "Prey",
        }
    end

    if type(state) == "table" then
        for _, key in ipairs({ "questID", "sourceQuestID" }) do
            local questID = state[key]
            if type(questID) == "number" and questID > 0 then
                return {
                    kind = "quest",
                    questID = questID,
                }
            end
        end
    end

    if type(data) == "table" then
        for _, key in ipairs({ "quest", "actualQuest", "unlockQuest" }) do
            local questID = data[key]
            if type(questID) == "number" and questID > 0 then
                return {
                    kind = "quest",
                    questID = questID,
                }
            end
        end
    end

    return nil
end

local function GetTrackerObjectiveTooltipData(entry, objective)
    if type(objective) == "table" and type(objective.itemID) == "number" and objective.itemID > 0 then
        return {
            kind = "item",
            itemID = objective.itemID,
        }
    end

    return GetTrackerEntryTooltipData(entry)
end

local function GetTrackerEntryActionData(entry)
    local state = entry and entry.state or nil
    local data = entry and entry.data or nil

    if type(data) == "table"
        and type(data.key) == "string"
        and data.key:match("^prey%-")
        and type(state) == "table"
        and state.status ~= 2
    then
        return {
            kind = "waypoint",
            mapID = data.mapID or ASTALOR_PREY_MAP_ID,
            x = data.x or ASTALOR_PREY_X,
            y = data.y or ASTALOR_PREY_Y,
            questID = data.questID,
            waypointName = data.waypointName,
            waypointZone = data.waypointZone,
            waypointTooltipText = data.waypointTooltipText,
        }
    end

    if type(data) == "table"
        and type(data.mapID) == "number"
        and type(data.x) == "number"
        and type(data.y) == "number"
        and type(state) == "table"
        and state.status ~= 2
    then
        return {
            kind = "waypoint",
            mapID = data.mapID,
            x = data.x,
            y = data.y,
            questID = data.questID or state.questID or state.sourceQuestID,
            waypointName = data.waypointName or state.title,
            waypointZone = data.waypointZone,
            waypointTooltipText = data.waypointTooltipText,
        }
    end

    return nil
end

local function ApplyTrackerLineInteraction(line, tooltipData, actionData)
    if not line then
        return
    end

    line.tooltipData = tooltipData
    line.actionData = actionData
    line:EnableMouse(tooltipData ~= nil or actionData ~= nil)
end

local function ShowTrackerLineTooltip(line)
    local tooltipData = line and line.tooltipData or nil
    local actionData = line and line.actionData or nil
    if type(tooltipData) ~= "table" then
        if type(actionData) == "table" and actionData.kind == "waypoint" then
            ShowWaypointActionTooltip(line, actionData)
        end
        return
    end

    if type(actionData) == "table" and actionData.kind == "waypoint" and tooltipData.kind ~= "preyWaypoint" then
        if ShowWaypointActionTooltip(line, actionData) then
            return
        end
    end

    if tooltipData.kind == "item" and tooltipData.itemID then
        if ShowItemTooltip(line, tooltipData.itemID) then
            return
        end
    end

    if tooltipData.kind == "encounters" and tooltipData.encounters then
        if ShowEncounterTooltip(line, tooltipData.encounters) then
            return
        end
    end

    if tooltipData.kind == "preyWaypoint" then
        if ShowPreyWaypointTooltip(line, tooltipData) then
            return
        end
    end

    if tooltipData.kind == "quest" and tooltipData.questID then
        if ShowQuestTooltip(line, tooltipData.questID) then
            AppendWaypointActionTooltip(actionData)
            return
        end
    end

    if type(actionData) == "table" and actionData.kind == "waypoint" then
        if ShowWaypointActionTooltip(line, actionData) then
            return
        end
    end

    HideTrackerTooltip()
end

local function HandleTrackerLineClick(line)
    local actionData = line and line.actionData or nil
    if type(actionData) ~= "table" then
        return
    end

    if actionData.kind == "waypoint" then
        SetWaypoint(actionData.mapID, actionData.x, actionData.y, actionData.questID, actionData.waypointName)
    end
end

local function CreateBackdrop(frame)
    if frame.backdropApplied then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local bgR, bgG, bgB, bgA, borderR, borderG, borderB = GetBackdropColors()

    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)

    frame.BackgroundFill = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.BackgroundFill:SetAllPoints(frame)
    frame.BackgroundFill:SetColorTexture(bgR, bgG, bgB, math.min(1, math.max(bgA, 0.96)))

    frame.InnerGlow = frame:CreateTexture(nil, "BORDER")
    frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.InnerGlow:SetColorTexture(borderR, borderG, borderB, 0.08)
    frame.backdropApplied = true
end

local function SkinCloseButton(button)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinCloseButton then
        UI.SkinCloseButton(button)
    end
end

local function SetLockButtonTextures(button, isLocked)
    if not button then
        return
    end

    local textureState = isLocked and "Locked" or "Unlocked"
    if button.Icon then
        button.Icon:SetTexture("Interface\\Buttons\\LockButton-" .. textureState .. "-Up")
    end
end

local function SkinScrollBar(scrollFrame)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinScrollBar then
        UI.SkinScrollBar(scrollFrame)
    end
end

local function SkinButton(button)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinButton then
        UI.SkinButton(button)
    end
end

local function SetFrameAlphaIfPresent(frame, alpha)
    if frame and frame.SetAlpha then
        frame:SetAlpha(alpha)
    end
end

local function SetTextureAlphaIfPresent(texture, alpha)
    if texture and texture.SetAlpha then
        texture:SetAlpha(alpha)
    end
end

local function SetScrollBarTrackTransparency(scrollFrame, isMinimal)
    local scrollBar = scrollFrame and scrollFrame.ScrollBar
    if not scrollBar then
        return
    end

    local targetAlpha = isMinimal and 0 or 1
    local thumbTexture = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture() or nil
    if scrollBar.SetBackdropColor then
        scrollBar:SetBackdropColor(0, 0, 0, targetAlpha)
    end
    if scrollBar.SetBackdropBorderColor then
        scrollBar:SetBackdropBorderColor(0, 0, 0, targetAlpha)
    end

    for _, key in ipairs({ "Background", "Backdrop", "Back", "BG", "Track", "TrackBG", "Top", "Middle", "Bottom" }) do
        local region = scrollBar[key]
        if region then
            SetTextureAlphaIfPresent(region, targetAlpha)
            SetFrameAlphaIfPresent(region, targetAlpha)
        end
    end

    if scrollBar.GetRegions then
        for _, region in ipairs({ scrollBar:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local atlas = region.GetAtlas and region:GetAtlas() or nil
                local texture = region.GetTexture and region:GetTexture() or nil
                local shouldHide = atlas == "UI-ScrollBar-Track" or atlas == "UI-ScrollBar-Border" or
                    texture == "Interface\\Buttons\\UI-ScrollBar-Track" or
                    texture == "Interface\\Buttons\\UI-ScrollBar-Border"
                if shouldHide then
                    region:SetAlpha(targetAlpha)
                end
            end
        end
    end

    if scrollBar.GetChildren then
        for _, child in ipairs({ scrollBar:GetChildren() }) do
            if child ~= thumbTexture then
                SetFrameAlphaIfPresent(child, targetAlpha)
                if child.GetRegions then
                    for _, region in ipairs({ child:GetRegions() }) do
                        if region ~= thumbTexture then
                            SetTextureAlphaIfPresent(region, targetAlpha)
                        end
                    end
                end
            end
        end
    end

    if thumbTexture then
        thumbTexture:SetAlpha(1)
    end
end

local function GetStatusColorHex(status)
    if status == 2 then
        return T.Tools.Colors.GREEN
    end
    if status == 1 then
        return T.Tools.Colors.WARNING
    end
    return T.Tools.Colors.RED
end

local function BuildProgressText(summary)
    local progressColor = summary.countTowardsTotal == false and T.Tools.Colors.GRAY or GetStatusColorHex(summary.status)

    if summary.status == 2 then
        return T.Tools.Text.Color(progressColor, "Complete")
    end

    local current = summary.progressStyle == "remaining" and summary.remaining or (summary.total - summary.remaining)
    local progress = current .. "/" .. summary.total
    return T.Tools.Text.Color(progressColor, progress)
end

local function GetTooltipLineFontStrings(tooltip, lineIndex)
    local tooltipName = tooltip and tooltip.GetName and tooltip:GetName()
    if not tooltipName then
        return nil, nil
    end

    return _G[tooltipName .. "TextLeft" .. lineIndex], _G[tooltipName .. "TextRight" .. lineIndex]
end

local function SnapshotFontString(fontString)
    if not fontString or not fontString.GetFont then
        return nil
    end

    local fontPath, fontSize, fontFlags = fontString:GetFont()
    return {
        path = fontPath,
        size = fontSize,
        flags = fontFlags or "",
    }
end

local function RestoreFontString(fontString, snapshot)
    if not fontString or not fontString.SetFont or not snapshot then
        return
    end

    fontString:SetFont(snapshot.path or STANDARD_TEXT_FONT, snapshot.size or 12, snapshot.flags or "")
end

function CDT:RestoreTooltipFonts(tooltip)
    if not self.tooltipFontRestore then
        return
    end

    for lineIndex, snapshot in pairs(self.tooltipFontRestore) do
        local left, right = GetTooltipLineFontStrings(tooltip, lineIndex)
        RestoreFontString(left, snapshot.left)
        RestoreFontString(right, snapshot.right)
    end

    self.tooltipFontRestore = nil
end

local function ApplyTooltipLineFont(tooltip, lineIndex, fontPath, fontSize)
    local left, right = GetTooltipLineFontStrings(tooltip, lineIndex)
    if not left and not right then
        return
    end
    local currentFontPath, _, currentFlags

    if not CDT.tooltipFontRestore then
        CDT.tooltipFontRestore = {}
    end

    if not CDT.tooltipFontRestore[lineIndex] then
        CDT.tooltipFontRestore[lineIndex] = {
            left = SnapshotFontString(left),
            right = SnapshotFontString(right),
        }
    end

    if left and left.GetFont then
        currentFontPath, _, currentFlags = left:GetFont()
    end

    local resolvedFontPath = fontPath or currentFontPath or STANDARD_TEXT_FONT
    local resolvedFontSize = fontSize or 12
    local resolvedFlags = currentFlags or ""

    if left and left.SetFont then
        left:SetFont(resolvedFontPath, resolvedFontSize, resolvedFlags)
    end

    if right and right.SetFont then
        right:SetFont(resolvedFontPath, resolvedFontSize, resolvedFlags)
    end
end

local function BuildSummaryIcon(summary)
    if summary.iconAtlas then
        return ("|A:%s:16:16|a"):format(summary.iconAtlas)
    end

    return T.Tools.Text.Icon(summary.icon)
end

local function BuildSummaryLabel(summary)
    local label = BuildSummaryIcon(summary) .. " " .. T.Tools.Text.Color(GetStatusColorHex(summary.status), summary.name)
    if summary.infoText then
        label = label .. summary.infoText
    end
    return label
end

local function BuildTrackerSections(state, showCompleted)
    local sections = {}

    if not state or type(state.orderedCategories) ~= "table" then
        return sections
    end

    for _, summary in ipairs(state.orderedCategories) do
        local entries = showCompleted and summary.entries or summary.selectedEntries
        local shouldShowSummary = showCompleted or summary.remaining > 0

        if shouldShowSummary then
            local visibleEntries = {}
            for _, entry in ipairs(entries) do
                if showCompleted or entry.state.status ~= 2 then
                    table.insert(visibleEntries, entry)
                end
            end

            if showCompleted or #visibleEntries > 0 then
                local displayEntries = {}

                if not (showCompleted and summary.status == 2) then
                    for _, entry in ipairs(visibleEntries) do
                        local shouldShowEntry = (summary.showPendingEntries and entry.state.status ~= 2) or
                            entry.state.status == 1
                        if shouldShowEntry then
                            table.insert(displayEntries, entry)
                        end
                    end
                end

                table.insert(sections, {
                    summary = summary,
                    displayEntries = displayEntries,
                })
            end
        end
    end

    return sections
end

local function BuildObjectiveText(objective)
    local text = objective.text or ""
    local prefix = ""

    if objective.itemID and C_Item and type(C_Item.GetItemIconByID) == "function" then
        local itemIcon = C_Item.GetItemIconByID(objective.itemID)
        if itemIcon then
            prefix = ("|T%d:14:14:0:0|t "):format(itemIcon)
        end
    end

    if objective.need and objective.need > 0 then
        local progress = (objective.have or 0) .. "/" .. objective.need
        if string.match(text, "^" .. progress:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") .. "%s+") then
            return prefix .. text
        end

        return prefix .. progress .. " " .. text
    end

    return prefix .. text
end

local function GetTrackerEmptyText(state, sectionCount)
    if not state or not state.enabled then
        return T.Tools.Text.Color(T.Tools.Colors.GRAY, "Enable Quality of Life > Chores to start tracking.")
    end

    if type(state.orderedCategories) ~= "table" or #state.orderedCategories == 0 then
        return T.Tools.Text.Color(T.Tools.Colors.GRAY, "No tracked chores are active for this character right now.")
    end

    if sectionCount == 0 then
        return T.Tools.Text.Color(T.Tools.Colors.GRAY, "All tracked chores are complete.")
    end

    return nil
end

local function AddObjectiveLines(tooltip, entry, fontSettings)
    if not entry or not entry.state or type(entry.state.objectives) ~= "table" then
        return
    end

    for _, objective in ipairs(entry.state.objectives) do
        local prefix = T.Tools.Text.Color(T.Tools.Colors.GRAY, "    • ")
        tooltip:AddLine(prefix .. T.Tools.Text.Color(T.Tools.Colors.GRAY, BuildObjectiveText(objective)))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
    end
end

local function GetEntryColorHex(summary, status)
    if summary.showPendingEntries and status == 0 then
        return T.Tools.Colors.WARNING
    end

    return GetStatusColorHex(status)
end

local function CreateTrackerFrame(name)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(TRACKER_FRAME_WIDTH, TRACKER_FRAME_HEIGHT)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(TRACKER_MIN_WIDTH, TRACKER_MIN_HEIGHT, TRACKER_MAX_WIDTH, TRACKER_MAX_HEIGHT)
    else
        if frame.SetMinResize then
            frame:SetMinResize(TRACKER_MIN_WIDTH, TRACKER_MIN_HEIGHT)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(TRACKER_MAX_WIDTH, TRACKER_MAX_HEIGHT)
        end
    end
    frame:Hide()
    CreateBackdrop(frame)

    local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()

    frame.TitleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(32)
    frame.TitleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 1 },
    })
    frame.TitleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.98)
    frame.TitleBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.35)

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "ARTWORK")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 0, 0)
    frame.TitleAccent:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", 0, 0)
    frame.TitleAccent:SetHeight(2)
    frame.TitleAccent:SetColorTexture(0.96, 0.78, 0.24, 0.95)

    frame.TitleIcon = frame.TitleBar:CreateTexture(nil, "OVERLAY")
    frame.TitleIcon:SetPoint("LEFT", frame.TitleBar, "LEFT", 10, 0)
    frame.TitleIcon:SetSize(16, 16)
    frame.TitleIcon:SetTexture("Interface\\Icons\\inv_scroll_11")
    frame.TitleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.TitleIcon, "RIGHT", 8, 0)
    frame.Title:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -154, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("Weekly Chores")
    if frame.Title.SetTextColor then
        frame.Title:SetTextColor(1, 0.94, 0.82)
    end

    frame.TitleStatus = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.TitleStatus:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -98, 0)
    frame.TitleStatus:SetJustifyH("RIGHT")
    frame.TitleStatus:SetTextColor(0.96, 0.82, 0.35)

    frame.SettingsButton = CreateFrame("Button", nil, frame.TitleBar)
    frame.SettingsButton:SetSize(28, 28)
    frame.SettingsButton:SetHitRectInsets(-6, -6, -6, -6)
    frame.SettingsButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -58, -2)
    frame.SettingsButton:SetFrameStrata(frame:GetFrameStrata())
    frame.SettingsButton:SetFrameLevel((frame:GetFrameLevel() or 1) + 40)
    frame.SettingsButton:SetScript("OnEnter", ShowTrackerSettingsTooltip)
    frame.SettingsButton:SetScript("OnLeave", HideTrackerTooltip)

    frame.SettingsButton.Highlight = frame.SettingsButton:CreateTexture(nil, "HIGHLIGHT")
    frame.SettingsButton.Highlight:SetAllPoints(frame.SettingsButton)
    frame.SettingsButton.Highlight:SetColorTexture(1, 1, 1, 0.06)

    frame.SettingsButton.Icon = frame.SettingsButton:CreateTexture(nil, "ARTWORK")
    frame.SettingsButton.Icon:SetPoint("CENTER", frame.SettingsButton, "CENTER", 0, 0)
    frame.SettingsButton.Icon:SetSize(14, 14)
    frame.SettingsButton.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    frame.SettingsButton.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    frame.SettingsButton:Hide()

    frame.LockButton = CreateFrame("Button", nil, frame)
    frame.LockButton:SetSize(28, 28)
    frame.LockButton:SetHitRectInsets(-6, -6, -6, -6)
    frame.LockButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -28, -2)
    frame.LockButton:SetFrameStrata(frame:GetFrameStrata())
    frame.LockButton:SetFrameLevel((frame:GetFrameLevel() or 1) + 40)

    frame.LockButton.Highlight = frame.LockButton:CreateTexture(nil, "HIGHLIGHT")
    frame.LockButton.Highlight:SetAllPoints(frame.LockButton)
    frame.LockButton.Highlight:SetColorTexture(1, 1, 1, 0.08)

    frame.LockButton.Icon = frame.LockButton:CreateTexture(nil, "ARTWORK")
    frame.LockButton.Icon:SetPoint("CENTER", frame.LockButton, "CENTER", 0, 0)
    frame.LockButton.Icon:SetSize(32, 32)

    SetLockButtonTextures(frame.LockButton, false)
    frame.LockButton:Hide()

    frame.CloseButton = CreateFrame("Button", nil, frame.TitleBar, "UIPanelCloseButton")
    frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -2, 0)
    SkinCloseButton(frame.CloseButton)

    frame.EmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("CENTER", frame, "CENTER", 0, -8)
    frame.EmptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.EmptyText:SetJustifyH("CENTER")
    frame.EmptyText:SetJustifyV("MIDDLE")
    frame.EmptyText:SetWidth(TRACKER_FRAME_WIDTH - 60)
    frame.EmptyText:Hide()

    frame.ContentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.ContentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.ContentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, 0.98)
    frame.ContentInset:SetBackdropBorderColor(borderR, borderG, borderB, 0.45)

    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame.ContentInset, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 8, -8)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame.ContentInset, "BOTTOMRIGHT", -20, 8)
    SkinScrollBar(frame.ScrollFrame)

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ScrollFrame)
    frame.ScrollChild:SetSize(1, 1)
    frame.ScrollFrame:SetScrollChild(frame.ScrollChild)
    frame.ScrollFrame:HookScript("OnSizeChanged", function(scroll)
        local availableWidth = math.max(1, (scroll:GetWidth() or 1) - 8)
        frame.ScrollChild:SetWidth(availableWidth)
    end)

    frame.ResizeHandle = CreateFrame("Button", nil, frame)
    frame.ResizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 3)
    frame.ResizeHandle:SetSize(18, 18)

    frame.ResizeGlyph = frame.ResizeHandle:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.ResizeGlyph:SetPoint("CENTER", frame.ResizeHandle, "CENTER", 0, 0)
    frame.ResizeGlyph:SetText("//")
    frame.ResizeGlyph:SetTextColor(1, 0.88, 0.45)

    frame.ResizeHighlight = frame.ResizeHandle:CreateTexture(nil, "HIGHLIGHT")
    frame.ResizeHighlight:SetAllPoints(frame.ResizeHandle)
    frame.ResizeHighlight:SetColorTexture(1, 1, 1, 0.05)

    frame.Sections = {}

    return frame
end

local function EnsureTrackerSection(frame, index)
    local section = frame.Sections[index]
    if section then
        return section
    end

    section = CreateFrame("Frame", nil, frame.ScrollChild, "BackdropTemplate")
    section:SetPoint("LEFT", frame.ScrollChild, "LEFT", 0, 0)
    section:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)
    section:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    section:SetBackdropColor(0.92, 0.74, 0.18, 0.06)
    section:SetBackdropBorderColor(0.92, 0.74, 0.18, 0.16)

    section.BackgroundFill = section:CreateTexture(nil, "BACKGROUND")
    section.BackgroundFill:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
    section.BackgroundFill:SetPoint("BOTTOMRIGHT", section, "BOTTOMRIGHT", -1, 1)
    section.BackgroundFill:SetColorTexture(0.06, 0.06, 0.08, 0)

    section.HeaderGlow = section:CreateTexture(nil, "BORDER")
    section.HeaderGlow:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
    section.HeaderGlow:SetPoint("TOPRIGHT", section, "TOPRIGHT", -1, -1)
    section.HeaderGlow:SetHeight(26)
    section.HeaderGlow:SetColorTexture(1, 0.82, 0.2, 0.06)

    section.HeaderButton = CreateFrame("Button", nil, section)
    section.HeaderButton:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
    section.HeaderButton:SetPoint("TOPRIGHT", section, "TOPRIGHT", -1, -1)
    section.HeaderButton:SetHeight(28)
    section.HeaderButton:RegisterForClicks("LeftButtonUp")
    section.HeaderButton:SetFrameLevel((section:GetFrameLevel() or 1) + 1)
    section.HeaderButton:SetScript("OnEnter", ShowTrackerHeaderTooltip)
    section.HeaderButton:SetScript("OnLeave", HideTrackerTooltip)

    section.HeaderHighlight = section.HeaderButton:CreateTexture(nil, "HIGHLIGHT")
    section.HeaderHighlight:SetAllPoints(section.HeaderButton)
    section.HeaderHighlight:SetColorTexture(1, 1, 1, 0.04)

    section.Arrow = section.HeaderButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.Arrow:SetPoint("LEFT", section.HeaderButton, "LEFT", 10, 0)
    section.Arrow:SetTextColor(1, 0.88, 0.45)

    section.Title = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.Title:SetPoint("TOPLEFT", section, "TOPLEFT", 28, -10)
    section.Title:SetPoint("RIGHT", section, "RIGHT", -82, 0)
    section.Title:SetJustifyH("LEFT")
    section.Title:SetWordWrap(false)

    section.Progress = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.Progress:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -11)
    section.Progress:SetJustifyH("RIGHT")

    section.ActionButton = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
    section.ActionButton:SetSize(110, 20)
    section.ActionButton:SetPoint("TOPRIGHT", section, "TOPRIGHT", -10, -5)
    section.ActionButton:SetText("Watch Satchels")
    section.ActionButton:SetFrameLevel((section:GetFrameLevel() or 1) + 5)
    section.ActionButton:Hide()
    section.ActionButton:SetScript("OnEnter", ShowRaidSatchelTooltip)
    section.ActionButton:SetScript("OnLeave", HideTrackerTooltip)
    SkinButton(section.ActionButton)

    section.Divider = section:CreateTexture(nil, "BORDER")
    section.Divider:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -30)
    section.Divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -30)
    section.Divider:SetHeight(1)
    section.Divider:SetColorTexture(1, 1, 1, 0.05)

    section.lines = {}
    frame.Sections[index] = section
    return section
end

local function EnsureTrackerLine(section, index)
    local line = section.lines[index]
    if line then
        return line
    end

    line = CreateFrame("Button", nil, section)
    line:SetHeight(16)
    line:EnableMouse(false)
    line:RegisterForClicks("LeftButtonUp")
    line:SetScript("OnEnter", ShowTrackerLineTooltip)
    line:SetScript("OnLeave", HideTrackerTooltip)
    line:SetScript("OnClick", HandleTrackerLineClick)

    line.Highlight = line:CreateTexture(nil, "HIGHLIGHT")
    line.Highlight:SetAllPoints(line)
    line.Highlight:SetColorTexture(1, 1, 1, 0.03)

    line.Text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line.Text:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    line.Text:SetPoint("TOPRIGHT", line, "TOPRIGHT", 0, 0)
    line.Text:SetJustifyH("LEFT")
    line.Text:SetJustifyV("TOP")
    line.Text:SetWordWrap(true)

    section.lines[index] = line
    return line
end

function CDT:SaveTrackerSize(frame)
    if not frame or not frame.GetSize then
        return
    end

    local width, height = frame:GetSize()
    local db = GetTrackerSizeDB()
    db.width = math.min(TRACKER_MAX_WIDTH, math.max(TRACKER_MIN_WIDTH, width or TRACKER_FRAME_WIDTH))
    db.height = math.min(TRACKER_MAX_HEIGHT, math.max(TRACKER_MIN_HEIGHT, height or TRACKER_FRAME_HEIGHT))
end

function CDT:ApplyTrackerSize(frame)
    if not frame then
        return
    end

    local db = GetTrackerSizeDB()
    local width = math.min(TRACKER_MAX_WIDTH, math.max(TRACKER_MIN_WIDTH, db.width or TRACKER_FRAME_WIDTH))
    local height = math.min(TRACKER_MAX_HEIGHT, math.max(TRACKER_MIN_HEIGHT, db.height or TRACKER_FRAME_HEIGHT))
    frame:SetSize(width, height)
    if frame.EmptyText then
        frame.EmptyText:SetWidth(math.max(200, width - 60))
    end
end

function CDT:ApplyTrackerAppearance(frame)
    if not frame then
        return
    end

    local appearance = GetTrackerAppearanceSettings()
    local bgR, bgG, bgB, baseBgA, borderR, borderG, borderB = GetBackdropColors()
    local isMinimal = appearance.mode == "minimal"
    local outerAlpha = isMinimal and 0 or (baseBgA * appearance.backgroundAlpha)
    local titleAlpha = isMinimal and 0 or (0.98 * appearance.backgroundAlpha)
    local insetAlpha = isMinimal and 0 or (0.98 * appearance.backgroundAlpha)
    local sectionBackdropAlpha = isMinimal and 0.18 or 0.06
    local sectionBorderAlpha = isMinimal and 0.28 or 0.16
    local sectionGlowAlpha = isMinimal and 0.12 or 0.06
    local sectionDividerAlpha = isMinimal and 0.08 or 0.05
    local sectionFillAlpha = isMinimal and 0.96 or 0
    local sectionFillR = isMinimal and math.max(0, bgR * 0.45) or bgR
    local sectionFillG = isMinimal and math.max(0, bgG * 0.45) or bgG
    local sectionFillB = isMinimal and math.max(0, bgB * 0.45) or bgB

    frame:SetAlpha(isMinimal and 1 or appearance.frameAlpha)
    frame:SetBackdropColor(bgR, bgG, bgB, outerAlpha)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, isMinimal and 0 or 1)

    if frame.BackgroundFill then
        frame.BackgroundFill:SetColorTexture(bgR, bgG, bgB, outerAlpha)
    end
    if frame.InnerGlow then
        frame.InnerGlow:SetColorTexture(borderR, borderG, borderB, isMinimal and 0 or (0.08 * appearance.backgroundAlpha))
    end

    frame.TitleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, titleAlpha)
    frame.TitleBar:SetBackdropBorderColor(borderR, borderG, borderB,
        isMinimal and 0 or (0.35 * math.max(appearance.backgroundAlpha, 0.15)))
    frame.TitleAccent:SetAlpha(isMinimal and 0 or appearance.backgroundAlpha)

    frame.ContentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, insetAlpha)
    frame.ContentInset:SetBackdropBorderColor(borderR, borderG, borderB,
        isMinimal and 0 or (0.45 * math.max(appearance.backgroundAlpha, 0.15)))

    if isMinimal then
        frame.TitleIcon:Hide()
        frame.Title:Hide()
        frame.TitleStatus:Hide()
        frame.ContentInset:ClearAllPoints()
        frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -32)
        frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
        if frame.CloseButton:GetParent() ~= frame then
            frame.CloseButton:SetParent(frame)
        end
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, 2)
        frame.SettingsButton:ClearAllPoints()
        frame.SettingsButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -92, -2)
        frame.LockButton:ClearAllPoints()
        frame.LockButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -62, -2)
    else
        frame.TitleIcon:Show()
        frame.Title:Show()
        frame.TitleStatus:Show()
        frame.ContentInset:ClearAllPoints()
        frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
        frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        if frame.CloseButton:GetParent() ~= frame.TitleBar then
            frame.CloseButton:SetParent(frame.TitleBar)
        end
        frame.CloseButton:ClearAllPoints()
        frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -2, 0)
        frame.SettingsButton:ClearAllPoints()
        frame.SettingsButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -58, -2)
        frame.LockButton:ClearAllPoints()
        frame.LockButton:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", -28, -2)
    end

    if frame.ResizeHandle then
        frame.ResizeHandle:SetAlpha(isMinimal and math.max(0.65, appearance.frameAlpha) or 1)
    end

    SetScrollBarTrackTransparency(frame.ScrollFrame, isMinimal)

    for _, section in ipairs(frame.Sections or {}) do
        if section.BackgroundFill then
            section.BackgroundFill:SetColorTexture(sectionFillR, sectionFillG, sectionFillB, sectionFillAlpha)
        end
        section:SetBackdropColor(0.92, 0.74, 0.18, sectionBackdropAlpha)
        section:SetBackdropBorderColor(0.92, 0.74, 0.18, sectionBorderAlpha)
        section.HeaderGlow:SetColorTexture(1, 0.82, 0.2, sectionGlowAlpha)
        section.Divider:SetColorTexture(1, 1, 1, sectionDividerAlpha)
    end

    self:RefreshTrackerControls(frame)
end

function CDT:IsTrackerVisible()
    return GetTrackerDB().visible == true
end

function CDT:IsTrackerLocked()
    return IsTrackerLockedDB()
end

function CDT:SetTrackerLocked(isLocked)
    GetTrackerDB().locked = isLocked == true
end

function CDT:SetTrackerHovered(frame, isHovered)
    if not frame then
        return
    end

    frame.controlsHovered = isHovered == true
    self:RefreshTrackerControls(frame)
end

function CDT:UpdateTrackerHoverState(frame)
    if not frame then
        return
    end

    local isHovered = MouseIsOver(frame) or
        (frame.SettingsButton and frame.SettingsButton:IsShown() and MouseIsOver(frame.SettingsButton)) or
        (frame.LockButton and frame.LockButton:IsShown() and MouseIsOver(frame.LockButton)) or
        (frame.CloseButton and frame.CloseButton:IsShown() and MouseIsOver(frame.CloseButton)) or false

    if frame.controlsHovered ~= isHovered then
        frame.controlsHovered = isHovered
        self:RefreshTrackerControls(frame)
    end
end

function CDT:RefreshTrackerControls(frame)
    if not frame then
        return
    end

    local isLocked = self:IsTrackerLocked()
    local isHovered = frame.controlsHovered == true

    SetLockButtonTextures(frame.LockButton, isLocked)

    frame:SetMovable(not isLocked)
    frame:SetResizable(not isLocked)

    if isLocked then
        frame:StopMovingOrSizing()
    end

    if frame.dragHandle then
        frame.dragHandle:EnableMouse(not isLocked)
    end

    if frame.ResizeHandle then
        frame.ResizeHandle:EnableMouse(not isLocked)
        frame.ResizeHandle:SetShown(not isLocked)
    end

    if frame.CloseButton then
        frame.CloseButton:SetShown((not isLocked) or isHovered)
    end

    if frame.SettingsButton then
        frame.SettingsButton:SetShown(isHovered)
    end

    if frame.LockButton then
        frame.LockButton:SetShown(isHovered)
    end
end

function CDT:IsTrackerSectionCollapsed(summaryKey)
    if type(summaryKey) ~= "string" or summaryKey == "" then
        return false
    end

    return GetTrackerCollapsedSectionsDB()[summaryKey] == true
end

function CDT:SetTrackerSectionCollapsed(summaryKey, isCollapsed)
    if type(summaryKey) ~= "string" or summaryKey == "" then
        return
    end

    GetTrackerCollapsedSectionsDB()[summaryKey] = isCollapsed == true
end

function CDT:ToggleTrackerSection(summaryKey)
    self:SetTrackerSectionCollapsed(summaryKey, not self:IsTrackerSectionCollapsed(summaryKey))
    self:RenderTrackerFrame()
end

function CDT:SetTrackerVisible(isVisible)
    GetTrackerDB().visible = isVisible == true
end

function CDT:SaveTrackerPosition(frame)
    if not frame or not frame.GetPoint then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    local db = GetTrackerPositionDB()
    db.point = point or "CENTER"
    db.relativePoint = relativePoint or point or "CENTER"
    db.x = xOfs or 0
    db.y = yOfs or 0
end

function CDT:ApplyTrackerPosition(frame, anchorFrame)
    if not frame then
        return
    end

    local db = GetTrackerPositionDB()
    frame:ClearAllPoints()

    if db.point and db.relativePoint then
        frame:SetPoint(db.point, UIParent, db.relativePoint, db.x or 0, db.y or 0)
        return
    end

    if anchorFrame and anchorFrame.GetCenter then
        frame:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -6)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function CDT:MakeTrackerDraggable(frame)
    if not frame or frame.dragInitialized then
        return
    end

    frame:SetMovable(true)

    local dragHandle = CreateFrame("Button", nil, frame)
    dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -92, -6)
    dragHandle:SetHeight(20)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)

    dragHandle:SetScript("OnDragStart", function()
        if self:IsTrackerLocked() then
            return
        end
        frame:StartMoving()
    end)

    dragHandle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SaveTrackerPosition(frame)
    end)

    frame:SetScript("OnHide", function(hiddenFrame)
        hiddenFrame:StopMovingOrSizing()
    end)

    frame.dragHandle = dragHandle
    frame.dragInitialized = true
end

function CDT:MakeTrackerResizable(frame)
    if not frame or frame.resizeInitialized then
        return
    end

    frame.ResizeHandle:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not self:IsTrackerLocked() then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)

    frame.ResizeHandle:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        self:SaveTrackerSize(frame)
        self:RenderTrackerFrame()
    end)

    frame:HookScript("OnSizeChanged", function(sizedFrame)
        if sizedFrame.EmptyText then
            sizedFrame.EmptyText:SetWidth(math.max(200, (sizedFrame:GetWidth() or TRACKER_FRAME_WIDTH) - 60))
        end
        if sizedFrame:IsShown() then
            self:RenderTrackerFrame()
        end
    end)

    frame.resizeInitialized = true
end

function CDT:GetTrackerFrame()
    if not self.trackerFrame then
        self.trackerFrame = CreateTrackerFrame("TwichUI_ChoresTrackerFrame")
        self.trackerFrame:SetFrameStrata("MEDIUM")
        self.trackerFrame:SetFrameLevel(5)
        self:MakeTrackerDraggable(self.trackerFrame)
        self:MakeTrackerResizable(self.trackerFrame)
        self:ApplyTrackerSize(self.trackerFrame)
        self:ApplyTrackerAppearance(self.trackerFrame)
        self.trackerFrame.SettingsButton:SetScript("OnClick", function(button)
            HideTrackerTooltip()
            DataTextModule:ShowMenu(button, self:GetMenuList())
        end)
        self.trackerFrame.LockButton:SetScript("OnClick", function()
            self:SetTrackerLocked(not self:IsTrackerLocked())
            self:RefreshTrackerControls(self.trackerFrame)
        end)
        self.trackerFrame.CloseButton:SetScript("OnClick", function()
            self:HideTrackerFrame()
        end)
        self.trackerFrame:HookScript("OnEnter", function(frame)
            self:SetTrackerHovered(frame, true)
        end)
        self.trackerFrame:HookScript("OnLeave", function(frame)
            self:SetTrackerHovered(frame, MouseIsOver(frame))
        end)
        self.trackerFrame:HookScript("OnUpdate", function(frame)
            self:UpdateTrackerHoverState(frame)
        end)
        self.trackerFrame.SettingsButton:HookScript("OnEnter", function()
            self:SetTrackerHovered(self.trackerFrame, true)
        end)
        self.trackerFrame.SettingsButton:HookScript("OnLeave", function()
            self:SetTrackerHovered(self.trackerFrame, MouseIsOver(self.trackerFrame))
        end)
        self.trackerFrame.LockButton:HookScript("OnEnter", function()
            self:SetTrackerHovered(self.trackerFrame, true)
        end)
        self.trackerFrame.LockButton:HookScript("OnLeave", function()
            self:SetTrackerHovered(self.trackerFrame, MouseIsOver(self.trackerFrame))
        end)
        self:RefreshTrackerControls(self.trackerFrame)
    end

    return self.trackerFrame
end

function CDT:RenderTrackerFrame()
    local frame = self.trackerFrame
    if not frame then
        return
    end

    local choresModule = GetChoresModule()
    local choresOptions = GetChoresOptions()
    local state = choresModule and choresModule:GetState() or nil
    local showCompleted = choresOptions and choresOptions.GetShowCompleted and choresOptions:GetShowCompleted() or false
    local sections = BuildTrackerSections(state, showCompleted)
    local emptyText = GetTrackerEmptyText(state, #sections)
    local fontSettings = GetTooltipFontSettings()
    local trackerHeaderFontSettings = GetTrackerHeaderFontSettings()
    local contentHeight = 0
    local contentWidth = math.max(1, (frame.ScrollFrame:GetWidth() or 1) - 8)

    self:ApplyTrackerAppearance(frame)
    frame.ScrollChild:SetWidth(contentWidth)
    frame.ScrollFrame:SetVerticalScroll(0)
    frame.Title:SetFont(trackerHeaderFontSettings.font, math.max(trackerHeaderFontSettings.fontSize + 2, 12), "")
    frame.TitleStatus:SetFont(trackerHeaderFontSettings.font, math.max(trackerHeaderFontSettings.fontSize - 1, 10), "")
    frame.TitleStatus:SetText(state and state.enabled and ("%d remaining"):format(state.totalRemaining or 0) or "Paused")
    frame.EmptyText:SetShown(emptyText ~= nil)
    frame.EmptyText:SetText(emptyText or "")

    for sectionIndex, sectionData in ipairs(sections) do
        local section = EnsureTrackerSection(frame, sectionIndex)
        local summary = sectionData.summary
        local lineIndex = 1
        local isCollapsed = self:IsTrackerSectionCollapsed(summary.key)
        local yOffset = isCollapsed and 0 or 38
        local sectionHeight = 32

        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -contentHeight)
        section:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)

        section.summaryKey = summary.key
        section.HeaderButton.summaryData = summary
        section.HeaderButton:SetScript("OnClick", function()
            if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() and CanDisableTrackerSummary(summary) then
                if DisableTrackerSummary(summary) then
                    HideTrackerTooltip()
                    return
                end
            end

            self:ToggleTrackerSection(section.summaryKey)
        end)
        section.Title:SetFont(trackerHeaderFontSettings.font, trackerHeaderFontSettings.fontSize, "")
        section.Progress:SetFont(trackerHeaderFontSettings.font, trackerHeaderFontSettings.fontSize, "")
        section.Arrow:SetText(isCollapsed and ">" or "v")
        section.Title:SetText(BuildSummaryLabel(summary))
        section.Progress:SetText(BuildProgressText(summary))
        section.Divider:SetShown(not isCollapsed)
        section.ActionButton:SetShown(summary.key == "raidFinder")
        if summary.key == "raidFinder" then
            local satchelsConfigured = IsSatchelWatchConfiguredForTrackedRaidWings()
            section.ActionButton:SetSize(satchelsConfigured and 126 or 110, 20)
            section.HeaderButton:ClearAllPoints()
            section.HeaderButton:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
            section.HeaderButton:SetPoint("TOPRIGHT", section.Progress, "TOPLEFT", -130, 0)
            section.ActionButton:SetScript("OnClick", function()
                if ConfigureSatchelWatchForTrackedRaidWings() then
                    PlayTrackerFeedbackSound("TwichUI Alert 3")
                    PrintTrackerFeedbackMessage(
                        "Watching for satchels for your tracked Raid Finder wings. A notification will appear when one is found.")
                    self:RenderTrackerFrame()
                end
                HideTrackerTooltip()
            end)
            section.ActionButton:SetText(satchelsConfigured and "Watch Satchels |cff00ff00✓|r" or "Watch Satchels")
            section.Progress:ClearAllPoints()
            section.Progress:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -11)
            section.ActionButton:ClearAllPoints()
            section.ActionButton:SetPoint("RIGHT", section.Progress, "LEFT", -8, 0)
            section.Title:ClearAllPoints()
            section.Title:SetPoint("TOPLEFT", section, "TOPLEFT", 28, -10)
            section.Title:SetPoint("RIGHT", section.ActionButton, "LEFT", -8, 0)
        else
            section.HeaderButton:ClearAllPoints()
            section.HeaderButton:SetPoint("TOPLEFT", section, "TOPLEFT", 1, -1)
            section.HeaderButton:SetPoint("TOPRIGHT", section, "TOPRIGHT", -1, -1)
            section.Progress:ClearAllPoints()
            section.Progress:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -11)
            section.Title:ClearAllPoints()
            section.Title:SetPoint("TOPLEFT", section, "TOPLEFT", 28, -10)
            section.Title:SetPoint("RIGHT", section, "RIGHT", -82, 0)
        end

        if not isCollapsed then
            for _, entry in ipairs(sectionData.displayEntries) do
                local line = EnsureTrackerLine(section, lineIndex)
                local entryColor = GetEntryColorHex(summary, entry.state.status)
                line:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -yOffset)
                line:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, 0)
                line.Text:SetFont(fontSettings.entryFont, fontSettings.entryFontSize, "")
                line.Text:SetText(T.Tools.Text.Color(entryColor, "• " .. BuildEntryDisplayTitle(summary, entry)))
                line:SetHeight(math.max(line.Text:GetStringHeight(), fontSettings.entryFontSize))
                ApplyTrackerLineInteraction(line, GetTrackerEntryTooltipData(entry), GetTrackerEntryActionData(entry))
                line:Show()
                yOffset = yOffset + line:GetHeight() + 4
                lineIndex = lineIndex + 1

                if entry.state and type(entry.state.objectives) == "table" then
                    for _, objective in ipairs(entry.state.objectives) do
                        local objectiveLine = EnsureTrackerLine(section, lineIndex)
                        objectiveLine:SetPoint("TOPLEFT", section, "TOPLEFT", 14, -yOffset)
                        objectiveLine:SetPoint("TOPRIGHT", section, "TOPRIGHT", -14, 0)
                        objectiveLine.Text:SetFont(fontSettings.entryFont, fontSettings.entryFontSize, "")
                        objectiveLine.Text:SetText(T.Tools.Text.Color(T.Tools.Colors.GRAY,
                            "    • " .. BuildObjectiveText(objective)))
                        objectiveLine:SetHeight(math.max(objectiveLine.Text:GetStringHeight(), fontSettings
                            .entryFontSize))
                        ApplyTrackerLineInteraction(objectiveLine, GetTrackerObjectiveTooltipData(entry, objective),
                            nil)
                        objectiveLine:Show()
                        yOffset = yOffset + objectiveLine:GetHeight() + 3
                        lineIndex = lineIndex + 1
                    end
                end
            end

            sectionHeight = math.max(42, yOffset + 10)
        end

        for hiddenIndex = lineIndex, #section.lines do
            section.lines[hiddenIndex]:Hide()
            section.lines[hiddenIndex].Text:SetText("")
            ApplyTrackerLineInteraction(section.lines[hiddenIndex], nil, nil)
        end

        section:SetHeight(sectionHeight)
        section:Show()
        contentHeight = contentHeight + section:GetHeight() + 10
    end

    for sectionIndex = #sections + 1, #frame.Sections do
        frame.Sections[sectionIndex]:Hide()
    end

    self:ApplyTrackerAppearance(frame)
    frame.ScrollChild:SetHeight(math.max(1, contentHeight + 8))
end

function CDT:ShowTrackerFrame(anchorFrame)
    local frame = self:GetTrackerFrame()
    if not frame then
        return
    end

    self:ApplyTrackerPosition(frame, anchorFrame)
    self:SetTrackerVisible(true)
    self:RenderTrackerFrame()
    frame:Show()
end

function CDT:HideTrackerFrame()
    self:SetTrackerVisible(false)
    if self.trackerFrame then
        self.trackerFrame:Hide()
    end
end

function CDT:ToggleTrackerFrame(anchorFrame)
    if self.trackerFrame and self.trackerFrame:IsShown() then
        self:HideTrackerFrame()
    else
        self:ShowTrackerFrame(anchorFrame)
    end
end

function CDT:Refresh()
    if not self.panel then
        if self.trackerFrame and self.trackerFrame:IsShown() then
            self:RenderTrackerFrame()
        end
        return
    end

    local choresModule = GetChoresModule()
    local state = choresModule and choresModule:GetState() or nil
    if not state or not state.enabled then
        local nextText = T.Tools.Text.Color(T.Tools.Colors.GRAY, "Chores: Off")
        local previousText = self.panel.text:GetText()
        self.panel.text:SetText(nextText)
        DataTextModule:MaybeFlashPanel(self.panel, "chores", previousText, nextText)
        if self.trackerFrame and self.trackerFrame:IsShown() then
            self:RenderTrackerFrame()
        end
        return
    end

    local count = state.totalRemaining or 0
    if count == 0 then
        local doneR, doneG, doneB = GetDoneValueColor()
        local nextText = "Chores " .. T.Tools.Text.ColorRGB(doneR, doneG, doneB, "Done")
        local previousText = self.panel.text:GetText()
        self.panel.text:SetText(nextText)
        DataTextModule:MaybeFlashPanel(self.panel, "chores", previousText, nextText)
        if self.trackerFrame and self.trackerFrame:IsShown() then
            self:RenderTrackerFrame()
        end
        return
    end

    local r, g, b = GetValueColor()
    if r and g and b then
        local nextText = "Chores: " .. T.Tools.Text.ColorRGB(r, g, b, tostring(count))
        local previousText = self.panel.text:GetText()
        self.panel.text:SetText(nextText)
        DataTextModule:MaybeFlashPanel(self.panel, "chores", previousText, nextText)
        if self.trackerFrame and self.trackerFrame:IsShown() then
            self:RenderTrackerFrame()
        end
        return
    end

    local nextText = "Chores: " .. tostring(count)
    local previousText = self.panel.text:GetText()
    self.panel.text:SetText(nextText)
    DataTextModule:MaybeFlashPanel(self.panel, "chores", previousText, nextText)

    if self.trackerFrame and self.trackerFrame:IsShown() then
        self:RenderTrackerFrame()
    end
end

function CDT:OnEvent(panel)
    if not self.panel then
        self.panel = panel
    end

    self:Refresh()
end

function CDT:HandleChoresUpdated()
    self:Refresh()
    DataTextModule:RefreshDataText("TwichUI: Chores")
end

local function BuildMenuSectionTitle(text)
    return T.Tools.Text.ColorRGB(0.45, 0.78, 1, text)
end

function CDT:GetMenuList()
    local choresOptions = GetChoresOptions()
    local menuList = {
        {
            text = "Chores",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Enable Tracking",
            checked = function()
                return choresOptions:GetEnabled()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetEnabled(nil, not choresOptions:GetEnabled())
            end,
        },
        {
            text = "Show Completed Chores",
            checked = function()
                return choresOptions:GetShowCompleted()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetShowCompleted(nil, not choresOptions:GetShowCompleted())
            end,
        },
        {
            text = "",
            disabled = true,
            notCheckable = true,
        },
        {
            text = "Count Toward Total",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = T.Tools.Text.Icon("Interface\\Icons\\Inv_12_profession_enchanting_enchantedvellum_blue") ..
                " Profession Chores",
            checked = function()
                return choresOptions:GetCountProfessionsTowardTotal()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCountProfessionsTowardTotal(nil, not choresOptions:GetCountProfessionsTowardTotal())
            end,
        },
        {
            text = "|A:delves-bountiful:16:16|a Bountiful Delves",
            checked = function()
                return choresOptions:GetCountBountifulDelvesTowardTotal()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCountBountifulDelvesTowardTotal(nil,
                    not choresOptions:GetCountBountifulDelvesTowardTotal())
            end,
        },
        {
            text = T.Tools.Text.Icon(PREY_ICON) .. " Prey",
            checked = function()
                return choresOptions:GetCountPreyTowardTotal()
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCountPreyTowardTotal(nil, not choresOptions:GetCountPreyTowardTotal())
            end,
        },
        {
            text = "",
            disabled = true,
            notCheckable = true,
        },
        {
            text = BuildMenuSectionTitle("Weekly Chores"),
            isTitle = true,
            notCheckable = true,
        },
    }

    for _, item in ipairs(MENU_CATEGORY_ITEMS) do
        local iconMarkup = item.iconAtlas and ("|A:%s:16:16|a "):format(item.iconAtlas) or
            (T.Tools.Text.Icon(item.icon) .. " ")
        table.insert(menuList, {
            text = iconMarkup .. item.name,
            checked = function()
                return choresOptions:IsCategoryEnabled(item.key)
            end,
            isNotRadio = true,
            keepShownOnClick = true,
            func = function()
                choresOptions:SetCategoryEnabled(item.key, not choresOptions:IsCategoryEnabled(item.key))
            end,
        })
    end

    local professionMenuItems = GetProfessionMenuItems()
    if #professionMenuItems > 0 then
        table.insert(menuList, {
            text = "",
            disabled = true,
            notCheckable = true,
        })
        table.insert(menuList, {
            text = BuildMenuSectionTitle("Profession Chores"),
            isTitle = true,
            notCheckable = true,
        })

        for _, item in ipairs(professionMenuItems) do
            table.insert(menuList, {
                text = T.Tools.Text.Icon(item.icon) .. " " .. item.name,
                checked = function()
                    return choresOptions:IsCategoryEnabled(item.key)
                end,
                isNotRadio = true,
                keepShownOnClick = true,
                func = function()
                    choresOptions:SetCategoryEnabled(item.key, not choresOptions:IsCategoryEnabled(item.key))
                end,
            })
        end
    end

    table.insert(menuList, {
        text = "",
        disabled = true,
        notCheckable = true,
    })
    table.insert(menuList, {
        text = BuildMenuSectionTitle("Additional Tracking"),
        isTitle = true,
        notCheckable = true,
    })
    table.insert(menuList, {
        text = "|A:delves-bountiful:16:16|a Bountiful Delves",
        checked = function()
            return choresOptions:GetTrackBountifulDelves()
        end,
        isNotRadio = true,
        keepShownOnClick = true,
        func = function()
            choresOptions:SetTrackBountifulDelves(nil, not choresOptions:GetTrackBountifulDelves())
        end,
    })
    table.insert(menuList, {
        text = "Only Track Bountiful Delves With Key",
        checked = function()
            return choresOptions:GetOnlyTrackBountifulDelvesWithKey()
        end,
        disabled = function()
            return not choresOptions:GetTrackBountifulDelves()
        end,
        isNotRadio = true,
        keepShownOnClick = true,
        func = function()
            choresOptions:SetOnlyTrackBountifulDelvesWithKey(nil,
                not choresOptions:GetOnlyTrackBountifulDelvesWithKey())
        end,
    })
    table.insert(menuList, {
        text = T.Tools.Text.Icon(PREY_ICON) .. " Prey",
        checked = function()
            return choresOptions:GetTrackPrey()
        end,
        isNotRadio = true,
        keepShownOnClick = true,
        func = function()
            choresOptions:SetTrackPrey(nil, not choresOptions:GetTrackPrey())
        end,
    })

    local preyDifficulties = GetPreyDifficultyMenuItems()
    if #preyDifficulties > 0 then
        table.insert(menuList, {
            text = "",
            disabled = true,
            notCheckable = true,
        })
        table.insert(menuList, {
            text = BuildMenuSectionTitle("Prey Difficulties"),
            isTitle = true,
            notCheckable = true,
        })

        for _, difficulty in ipairs(preyDifficulties) do
            table.insert(menuList, {
                text = difficulty.name,
                checked = function()
                    return choresOptions:IsPreyDifficultyEnabled(difficulty.key)
                end,
                isNotRadio = true,
                keepShownOnClick = true,
                func = function()
                    choresOptions:SetPreyDifficultyEnabled(difficulty.key,
                        not choresOptions:IsPreyDifficultyEnabled(difficulty.key))
                end,
            })
        end
    end

    local raidWings = GetCurrentExpansionRaidWings()
    if #raidWings > 0 then
        table.insert(menuList, {
            text = "",
            disabled = true,
            notCheckable = true,
        })
        table.insert(menuList, {
            text = BuildMenuSectionTitle("Raid Finder Wings"),
            isTitle = true,
            notCheckable = true,
        })

        for _, raidWing in ipairs(raidWings) do
            table.insert(menuList, {
                text = ("|A:%s:16:16|a "):format("Raid") .. raidWing.name,
                checked = function()
                    return choresOptions:IsRaidWingEnabled(raidWing.dungeonID)
                end,
                isNotRadio = true,
                keepShownOnClick = true,
                func = function()
                    choresOptions:SetRaidWingEnabled(raidWing.dungeonID,
                        not choresOptions:IsRaidWingEnabled(raidWing.dungeonID))
                end,
            })
        end
    end

    return menuList
end

function CDT:OnClick(panel, button)
    if button == "LeftButton" then
        self:ToggleTrackerFrame(panel)
    elseif button == "RightButton" then
        DataTextModule:ShowMenu(panel, self:GetMenuList())
    end
end

function CDT:OnEnter(panel)
    if not self.panel then
        self.panel = panel
    end

    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    self:RestoreTooltipFonts(tooltip)

    local choresModule = GetChoresModule()
    local choresOptions = GetChoresOptions()
    local state = choresModule and choresModule:GetState() or nil
    local showCompleted = choresOptions and choresOptions.GetShowCompleted and choresOptions:GetShowCompleted() or false
    local fontSettings = GetTooltipFontSettings()
    local sections = BuildTrackerSections(state, showCompleted)

    tooltip:ClearLines()
    tooltip:AddLine("Weekly Chores")
    ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.headerFont, fontSettings.headerFontSize)

    if not state or not state.enabled then
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Enable Quality of Life > Chores to start tracking."))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
        DataTextModule:ShowDatatextTooltip(tooltip)
        return
    end

    if #state.orderedCategories == 0 then
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY,
            "No tracked chores are active for this character right now."))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
        DataTextModule:ShowDatatextTooltip(tooltip)
        return
    end

    tooltip:AddDoubleLine("Remaining", T.Tools.Text.Color(T.Tools.Colors.WARNING, tostring(state.totalRemaining)), 1, 1,
        1, 1, 1, 1)
    ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.headerFont, fontSettings.headerFontSize)
    tooltip:AddLine(" ")

    for _, section in ipairs(sections) do
        local summary = section.summary
        local label = BuildSummaryLabel(summary)
        tooltip:AddDoubleLine(label, BuildProgressText(summary), 1, 1, 1, 1, 1, 1)
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.headerFont, fontSettings.headerFontSize)

        if not (showCompleted and summary.status == 2) then
            for _, entry in ipairs(section.displayEntries) do
                local entryColor = GetEntryColorHex(summary, entry.state.status)
                tooltip:AddLine(T.Tools.Text.Color(entryColor, "  • " .. BuildEntryDisplayTitle(summary, entry)))
                ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont,
                    fontSettings.entryFontSize)
                AddObjectiveLines(tooltip, entry, fontSettings)
            end
        end

        tooltip:AddLine(" ")
    end

    if #sections == 0 then
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "All tracked chores are complete."))
        ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
        tooltip:AddLine(" ")
    end

    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY,
        "Left-click for tracking options. Right-click to pin or close the tracker."))
    ApplyTooltipLineFont(tooltip, tooltip:NumLines(), fontSettings.entryFont, fontSettings.entryFontSize)
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function CDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        if DataTextModule.tooltipOwner == self.panel then
            self:RestoreTooltipFonts(tooltip)
        end
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function CDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Chores",
        prettyName = "Chores",
        events = {
            DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE,
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end

function CDT:OnEnable()
    self:RegisterMessage("TWICHUI_CHORES_UPDATED", "HandleChoresUpdated")

    if self:IsTrackerVisible() then
        self:ShowTrackerFrame(nil)
    end
end

function CDT:OnDisable()
    if self.trackerFrame then
        self.trackerFrame:Hide()
    end
end
